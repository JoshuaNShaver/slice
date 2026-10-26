class_name Projectiles
extends Node2D
## Thrown shots (design log 0242): rangers' spinning metal triangles, and
## later the Revolt's (log 0247). One node in the world holds them all.
##
## The server decides everything that matters: where a shot starts, what it
## seeks, what it hits and for how much. Each shot's start goes to every
## client once (_spawned) and each client flies it itself by the same rules,
## so nothing streams per frame; the server says when it ends (_ended).
##
## A shot is data, so gear can throw any number in any fan (throw_fan):
## - from, dir: where it starts and which way it goes (normalized).
## - speed (px/s), life (s), gravity (px/s², 0 for a straight shot).
## - target: a Node2D it seeks, or null. seek_after: s before it starts to
##   seek (a volley's arc, log 0244). turn: rad/s it can turn while seeking.
## - side: "players" (hurts hostile enemies) or "hostile" (hurts players and
##   the army's soldiers). owner: the throwing player's peer id (0 for none).
## - damage, crit (server only), lethal (false: stops players at 1 health).
## - source: the Enemy that threw it (its landed hits count, as a corner's
##   do: a bout's, log 0245). only: a peer id it alone can hurt (a bout's
##   enemy fights only its owner), or 0.

const GROUP := "projectiles"
const SPEED := 640.0  # px/s
const LIFE := 1.5  # s
const TURN := 9.0  # rad/s a seeking shot can turn
const RADIUS := 5.0  # px: how close a shot must pass to hit
const SIZE := 6.0  # px, drawn
const SPIN := 24.0  # rad/s, drawn
const SEEK_RANGE := 650.0  # px: the nearest enemy within this is sought
## A shot deals this share of your melee corner damage (log 0242, *proposed*).
const DAMAGE_SHARE := 0.4
const KNOCKBACK := 40.0  # px/s given to what it hits
const TINT := Color("a3a6a8")  # bright metal

var _shots := {}  # id -> shot (see the header)
var _next_id := 1


## The world's Projectiles node, or null (tests without one).
static func find(tree: SceneTree) -> Projectiles:
	return tree.get_first_node_in_group(GROUP) as Projectiles


func _ready() -> void:
	add_to_group(GROUP)
	z_index = 5  # over terrain and shapes


## Server only. Throws `count` copies of `shot`, fanned evenly over `spread`
## degrees around its dir.
func throw_fan(shot: Dictionary, count: int, spread: float) -> void:
	var dir: Vector2 = shot.dir
	for i in maxi(count, 1):
		var copy := shot.duplicate()
		var t := 0.0 if count <= 1 else float(i) / (count - 1) - 0.5
		copy.dir = dir.rotated(deg_to_rad(spread) * t)
		throw(copy)


## Server only. Starts one shot (see the header for its keys).
func throw(shot: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var s := {
		"pos": shot.from, "vel": (shot.dir as Vector2).normalized() * shot.get("speed", SPEED),
		"life": shot.get("life", LIFE), "gravity": shot.get("gravity", 0.0),
		"target": shot.get("target"), "seek_after": shot.get("seek_after", 0.0),
		"turn": shot.get("turn", TURN), "side": shot.get("side", "players"),
		"owner": shot.get("owner", 0), "damage": shot.get("damage", 0.0),
		"crit": shot.get("crit", false), "lethal": shot.get("lethal", true),
		"size": shot.get("size", SIZE), "angle": 0.0,
		"source": shot.get("source"), "only": shot.get("only", 0),
	}
	var id := _next_id
	_next_id += 1
	_shots[id] = s
	var target: Node = s.target
	var path := target.get_path() if target != null and is_instance_valid(target) else NodePath()
	_spawned.rpc(id, s.pos, s.vel, path, s.life, s.gravity, s.seek_after, s.turn, s.size,
			s.side == "hostile")


## Server -> clients: a shot starts. Clients fly it themselves.
@rpc("authority", "call_remote", "reliable")
func _spawned(id: int, pos: Vector2, vel: Vector2, target: NodePath, life: float, gravity: float,
		seek_after: float, turn: float, size: float, hostile: bool) -> void:
	_shots[id] = {"pos": pos, "vel": vel, "life": life, "gravity": gravity,
			"target": get_node_or_null(target) if not target.is_empty() else null,
			"seek_after": seek_after, "turn": turn, "size": size, "angle": 0.0,
			"side": "hostile" if hostile else "players"}


## Server -> clients: a shot is spent (hit something, or flew out).
@rpc("authority", "call_remote", "reliable")
func _ended(id: int) -> void:
	_shots.erase(id)


## How many shots are in flight (tests).
func count() -> int:
	return _shots.size()


func _physics_process(delta: float) -> void:
	if _shots.is_empty():
		return
	var server := multiplayer.is_server()
	var space := get_world_2d().direct_space_state
	for id: int in _shots.keys():
		var s: Dictionary = _shots[id]
		var from: Vector2 = s.pos
		_fly(s, delta)
		s.life -= delta
		if not server:
			if s.life <= 0.0:
				_shots.erase(id)
			continue
		if _strike(s, from, space) or s.life <= 0.0:
			_shots.erase(id)
			_ended.rpc(id)
	queue_redraw()


## Moves a shot one step: falls, and turns toward its target once seeking.
func _fly(s: Dictionary, delta: float) -> void:
	s.angle += SPIN * delta
	s.seek_after -= delta
	var target: Node2D = s.target if s.target != null and is_instance_valid(s.target) else null
	if target is Enemy and (target as Enemy).hp <= 0:
		target = null
	if target is PlayerShape and (target as PlayerShape).dead:
		target = null
	var vel: Vector2 = s.vel
	if target != null and s.seek_after <= 0.0:
		var want := (target.global_position - (s.pos as Vector2)).angle()
		var speed := maxf(vel.length(), SPEED * 0.5)
		var angle := rotate_toward(vel.angle(), want, s.turn * delta)
		vel = Vector2.from_angle(angle) * speed
	else:
		vel.y += s.gravity * delta
	s.vel = vel
	s.pos = (s.pos as Vector2) + vel * delta


## Server only. Whether the shot hit something between `from` and where it
## is now: terrain stops it; the first foe on the way takes the hit.
func _strike(s: Dictionary, from: Vector2, space: PhysicsDirectSpaceState2D) -> bool:
	var to: Vector2 = s.pos
	var wall := 1.0  # share of the way to the first terrain
	var query := PhysicsRayQueryParameters2D.create(from, to, PlayerShape.LAYER_TERRAIN)
	var ray := space.intersect_ray(query)
	if not ray.is_empty() and from != to:
		wall = from.distance_to(ray.position) / from.distance_to(to)
	var best: Node2D = null
	var best_t := wall
	for foe in _foes(s):
		var reach: float = _radius_of(foe) + RADIUS
		var t := _pass_at(from, to, foe.global_position, reach)
		if t >= 0.0 and t <= best_t:
			best_t = t
			best = foe
	if best != null:
		_hurt(s, best)
		return true
	return wall < 1.0


## What this shot can hurt.
func _foes(s: Dictionary) -> Array[Node2D]:
	var out: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var e := node as Enemy
		if e.hp <= 0:
			continue
		if s.side == "players" and e.players_can_hit(s.owner):
			out.append(e)
		elif s.side == "hostile" and e.is_army():
			out.append(e)
	if s.side == "hostile":
		for node in get_tree().get_nodes_in_group(PlayerShape.GROUP):
			var p := node as PlayerShape
			if not p.dead and (s.only == 0 or p.peer_id == s.only):
				out.append(p)
	return out


static func _radius_of(body: Node2D) -> float:
	if body is Enemy:
		return float((body as Enemy).info().get("radius", 26.0)) * 0.9
	return PlayerShape.RADIUS * 0.9


## The share of the way from `a` to `b` where it first comes within `reach`
## of `point`, or -1 if it never does.
static func _pass_at(a: Vector2, b: Vector2, point: Vector2, reach: float) -> float:
	var d := b - a
	var len2 := d.length_squared()
	if len2 < 0.0001:
		return 0.0 if a.distance_to(point) <= reach else -1.0
	var t := clampf((point - a).dot(d) / len2, 0.0, 1.0)
	if (a + d * t).distance_to(point) > reach:
		return -1.0
	return t


func _hurt(s: Dictionary, foe: Node2D) -> void:
	var push := (s.vel as Vector2).normalized()
	if foe is Enemy:
		var e := foe as Enemy
		e.apply_central_impulse(push * KNOCKBACK * e.mass)
		e.take_hit(s.damage, s.owner, s.crit)
		var thrower := _player(s.owner)
		if thrower != null:
			thrower.combat.note_combat()
	elif foe is PlayerShape:
		var p := foe as PlayerShape
		var source: Enemy = s.source if s.source != null and is_instance_valid(s.source) else null
		var leave_at: int = source.info().get("opening_hp", -1) if source != null and source.hits_landed == 0 else -1
		if p.combat.take_hit(s.damage, push, s.lethal, leave_at) and source != null:
			source.hits_landed += 1
			source.struck.emit(source, p)


func _player(peer: int) -> PlayerShape:
	if peer == 0:
		return null
	for node in get_tree().get_nodes_in_group(PlayerShape.GROUP):
		if (node as PlayerShape).peer_id == peer:
			return node
	return null


## Server only. The nearest enemy `peer` can hurt within SEEK_RANGE of
## `from` that a shot could reach (no terrain in the way), or null.
func nearest_foe(from: Vector2, peer: int, reach := SEEK_RANGE) -> Enemy:
	var space := get_world_2d().direct_space_state
	var best: Enemy = null
	var best_d := reach
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var e := node as Enemy
		if e.hp <= 0 or not e.players_can_hit(peer):
			continue
		var d := from.distance_to(e.global_position)
		if d >= best_d:
			continue
		var query := PhysicsRayQueryParameters2D.create(from, e.global_position, PlayerShape.LAYER_TERRAIN)
		if not space.intersect_ray(query).is_empty():
			continue
		best_d = d
		best = e
	return best


## Server only. A player's shot as data, aimed at the nearest enemy (or the
## way they're rolling): their tips' damage, a crit rolled on their luck.
## Callers may change it before throwing (an ability's arc or charge).
func player_shot(player: PlayerShape) -> Dictionary:
	var target := nearest_foe(player.global_position, player.peer_id)
	var dir: Vector2
	if target != null:
		dir = (target.global_position - player.global_position).normalized()
	else:
		var facing := signf(player.motion.move)
		if facing == 0.0:
			facing = signf(player.linear_velocity.x) if absf(player.linear_velocity.x) > 20.0 else 1.0
		dir = Vector2(facing, -0.12).normalized()
	var crit := randf() < Stats.lucky_chance(Stats.CRIT_CHANCE, player.stats.luck)
	return {"from": player.global_position, "dir": dir, "target": target, "side": "players",
			"owner": player.peer_id, "damage": shot_damage(player) * (Stats.CRIT_MULT if crit else 1.0),
			"crit": crit}


## A player's damage per shot: DAMAGE_SHARE of their sharpest corner's.
static func shot_damage(player: PlayerShape) -> float:
	var sharpest := 180.0
	for angle in player.corner_angles:
		sharpest = minf(sharpest, angle)
	return maxf(Stats.corner_damage(sharpest, player.stats.force), 0.0) * DAMAGE_SHARE


func _draw() -> void:
	for s: Dictionary in _shots.values():
		var at: Vector2 = s.pos
		var size: float = s.size
		var tint := Palette.REVOLT if s.side == "hostile" else TINT
		var tri := PackedVector2Array()
		for k in 3:
			tri.append(at + Vector2.from_angle(s.angle + TAU * k / 3.0) * size)
		draw_colored_polygon(tri, tint)
		tri.append(tri[0])
		draw_polyline(tri, Palette.INK, 1.2, true)

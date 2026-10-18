class_name Enemy
extends RigidBody2D
## A fighting shape that isn't a player: cave enemies (design log 0027), the
## drill yard's dummies and sparring partners (log 0072), and on missions the
## Colour Revolt and the army's own soldiers (logs 0068, 0070). The server
## simulates it and clients draw it, like PlayerShape. Its corners hurt the
## other side the way yours hurt it (Combat).
##
## Two sides: "hostile" (everything that fights players) and "army" (allied
## soldiers on missions). Hostiles chase the nearest player or soldier in
## their room; soldiers chase hostiles, or keep near their squad. Players
## pass through soldiers and can't hurt them.
##
## The world (or a mission) spawns them and gives out XP and loot when they die.

signal died(enemy: Enemy)

## tier: gear tier this enemy drops. level: about where it's comfortable.
## Optional: "team" ("hostile" or "army"), "kind" (outline: "irregular",
## "isosceles", "regular"), "apex" (isosceles), "drop" and "potion" (drop
## chances, before luck), "lethal" (false: can't bring a player below 1
## health), "still" (never moves), "paint" (the Revolt's colour), "gear" (a
## boss fights as if wearing a full set of this tier, log 0068), "boss".
const TYPES := {
	"bandit": {
		"name": "Bandit", "sides": 4, "radius": 22.0, "hp": 140, "damage": 22,
		"xp": 10, "spin": 5.0, "hop": 160.0, "tier": 1, "level": "1-7",
		"drop": 0.15, "potion": 0.1,
	},
	"brute": {
		"name": "Brute", "sides": 5, "radius": 28.0, "hp": 480, "damage": 40,
		"xp": 40, "spin": 6.0, "hop": 180.0, "tier": 2, "level": "7-14",
		"drop": 0.15, "potion": 0.1,
	},
	"zealot": {
		"name": "Zealot", "sides": 6, "radius": 32.0, "hp": 1100, "damage": 65,
		"xp": 80, "spin": 7.0, "hop": 200.0, "tier": 3, "level": "14-20",
		"drop": 0.15, "potion": 0.1,
	},
	"pretender": {
		"name": "The Pretender", "sides": 12, "radius": 72.0, "hp": 6000, "damage": 110,
		"xp": 400, "spin": 3.5, "hop": 320.0, "tier": 4, "level": "20",
		"drop": 1.0, "potion": 1.0, "boss": true,
	},
	# The drill yard (design log 0072). *Proposed* numbers.
	"dummy": {
		"name": "Straw dummy", "sides": 4, "kind": "regular", "radius": 24.0, "hp": 90, "damage": 0,
		"xp": 4, "spin": 0.0, "hop": 0.0, "tier": Gear.LEATHER, "level": "1-3",
		"drop": 0.05, "still": true,
	},
	"sparring": {
		"name": "Sparring partner", "sides": 3, "kind": "isosceles", "apex": 40.0, "radius": 26.0,
		"hp": 170, "damage": 14, "xp": 10, "spin": 4.5, "hop": 150.0, "tier": Gear.LEATHER,
		"level": "1-5", "drop": 0.15, "lethal": false,
	},
	# The Colour Revolt (design log 0068). *Proposed* numbers.
	"rebel": {
		"name": "Painted rebel", "sides": 3, "kind": "isosceles", "apex": 35.0, "radius": 26.0,
		"hp": 240, "damage": 26, "xp": 16, "spin": 5.0, "hop": 170.0, "tier": 0, "level": "5-10",
		"paint": true,
	},
	"agitator": {
		"name": "Agitator", "sides": 4, "radius": 28.0, "hp": 620, "damage": 42, "xp": 38,
		"spin": 6.0, "hop": 190.0, "tier": 0, "level": "10-20", "paint": true,
	},
	"bodyguard": {
		"name": "Bodyguard", "sides": 5, "radius": 32.0, "hp": 1300, "damage": 60, "xp": 80,
		"spin": 6.5, "hop": 210.0, "tier": 0, "level": "20", "paint": true,
	},
	"captain": {
		"name": "A Captain of the Revolt", "sides": 6, "radius": 50.0, "hp": 2600, "damage": 50,
		"xp": 260, "spin": 4.5, "hop": 260.0, "tier": 0, "level": "10-20", "paint": true,
		"gear": 3, "boss": true,
	},
	"chromatistes": {
		"name": "Chromatistes, the Painter", "sides": 8, "radius": 62.0, "hp": 4200, "damage": 60,
		"xp": 420, "spin": 4.0, "hop": 300.0, "tier": 0, "level": "20", "paint": true,
		"gear": 4, "boss": true,
	},
	# The army's own soldiers (design log 0070): they fight beside you.
	"soldier": {
		"name": "Soldier", "sides": 3, "kind": "isosceles", "apex": 45.0, "radius": 26.0,
		"hp": 420, "damage": 30, "xp": 0, "spin": 5.0, "hop": 170.0, "tier": 0, "level": "",
		"team": "army",
	},
}

const AGGRO_RANGE := 520.0
const HOP_RANGE := 180.0  # hops when a target is this close
const HOP_EVERY := Vector2(1.2, 2.6)  # seconds between hops, random in this range
const SPIN_ACCEL := 6.0
const TIP_ASSIST := 0.75  # as PlayerShape.TIP_ASSIST
const HOME_SLACK := 40.0  # px from home that counts as home
const STAKE := 46.0  # px a straw dummy's stake reaches below its center
const GROUP := "enemies"

const LAYER := 4  # hostiles
const ARMY_LAYER := 8  # soldiers: players don't touch them
const FOLLOW_DISTANCE := 160.0  # soldiers with nothing to fight keep this near the squad
## Soldiers wear bronze plating, so they read as the army's (design log 0069).
const SOLDIER_WEAR := ["", "plating_6", "", "", ""]

var type := "bandit"
var room := Rect2()  # the area it guards; it only chases players inside this
var home := Vector2.ZERO
var hp := 100
var max_hp := 100
var damage := 0.0  # per corner hit, after any gear buff
var rigidity := 0  # bosses' gear (design log 0068)
## Server only: peer ids that hit it this life (they share XP and loot).
var contributors: Dictionary = {}

var _points: PackedVector2Array
var _corners: PackedVector2Array  # collision outline
var _color := Color.WHITE
var _hop_timer := 1.0
var _prev_linear := Vector2.ZERO
var _prev_angular := 0.0
var _cooldowns: Dictionary = {}
var _rng := RandomNumberGenerator.new()


static func create(data: Dictionary) -> Enemy:
	var e := Enemy.new()
	e.name = data.name
	e.type = data.type
	e.room = data.room
	e.home = data.pos
	e.position = data.pos
	e._color = Palette.REVOLT if TYPES[e.type].get("paint", false) else data.get("color", Palette.PLAIN)
	var info: Dictionary = TYPES[e.type]
	e.max_hp = info.hp
	e.damage = info.damage
	_apply_gear(e, info.get("gear", 0))
	e.hp = e.max_hp
	var outline_kind: String = info.get("kind", "irregular")
	var apex: float = info.get("apex", 45.0)
	e._points = ShapeGeometry.points(info.sides, outline_kind, info.radius, apex)
	e._corners = ShapeGeometry.points(info.sides, outline_kind, info.radius + PlayerShape.COLLISION_PAD, apex)

	var shape := CollisionPolygon2D.new()
	shape.polygon = e._corners
	e.add_child(shape)
	if e.is_army():
		e.collision_layer = ARMY_LAYER
		e.collision_mask = PlayerShape.LAYER_TERRAIN | LAYER
	else:
		e.collision_layer = LAYER
		e.collision_mask = PlayerShape.LAYER_TERRAIN | PlayerShape.LAYER_PLAYERS | LAYER | ARMY_LAYER
	e.mass = 1.0 + info.radius * info.radius / 784.0  # a player-sized enemy weighs 1
	e.physics_material_override = PhysicsMaterial.new()
	e.physics_material_override.friction = 0.9
	e.physics_material_override.bounce = 0.15
	e.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	e.angular_damp = 0.5
	e.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	e.contact_monitor = true
	e.max_contacts_reported = 8
	e.can_sleep = false

	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var config := SceneReplicationConfig.new()
	for prop: String in [".:position", ".:rotation"]:
		config.add_property(prop)
		config.property_set_spawn(prop, true)
		config.property_set_replication_mode(prop, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	for prop: String in [".:hp", ".:max_hp"]:
		config.add_property(prop)
		config.property_set_spawn(prop, true)
		config.property_set_replication_mode(prop, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	sync.replication_config = config
	sync.add_visibility_filter(func(id: int) -> bool: return Net.players.has(id))
	e.add_child(sync)
	return e


## A boss fights as if wearing a full set of `tier` (design log 0068): its
## vigor adds health, its force adds damage, its plating blunts your hits.
static func _apply_gear(e: Enemy, tier: int) -> void:
	if tier <= 0:
		return
	var worn := PackedStringArray()
	for slot in Gear.SLOTS:
		worn.append(Gear.item(slot, tier))
	var gains := Gear.total_bonus(worn)
	e.max_hp += gains.get("vigor", 0) * Stats.HP_PER_VIGOR
	e.damage *= 1.0 + Stats.DAMAGE_PER_FORCE * gains.get("force", 0)
	e.rigidity = gains.get("rigidity", 0)


func _ready() -> void:
	add_to_group(GROUP)
	_rng.randomize()
	if not multiplayer.is_server():
		freeze = true
		freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	elif info().get("still", false):
		freeze = true
		freeze_mode = RigidBody2D.FREEZE_MODE_STATIC


func info() -> Dictionary:
	return TYPES[type]


func is_boss() -> bool:
	return info().get("boss", false)


func is_army() -> bool:
	return info().get("team", "hostile") == "army"


## Players' corners hurt hostiles only.
func players_can_hit() -> bool:
	return not is_army()


## Server only. `from_peer` is the player who hit it, or 0 for a soldier.
func take_hit(raw: float, from_peer: int, crit := false) -> void:
	if hp <= 0:
		return
	if from_peer != 0:
		contributors[from_peer] = true
	var dealt := roundi(Stats.damage_taken(raw, rigidity))
	hp = maxi(hp - dealt, 0)
	get_tree().call_group(World.GROUP, "show_damage", position + Vector2(0, -24), dealt,
			"crit" if crit else ("player" if is_army() else "enemy"))
	if hp == 0:
		died.emit(self)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not multiplayer.is_server() or hp <= 0 or freeze:
		return
	var step := state.step
	var stats := info()

	var grounded := false
	for i in state.get_contact_count():
		if state.get_contact_local_normal(i).y < -0.5:
			grounded = true
			break

	var target := _nearest_target()
	var dir := 0.0
	if target != null:
		dir = signf(target.position.x - position.x)
	elif is_army():
		var squad := _nearest_player()
		if squad != null and absf(squad.position.x - position.x) > FOLLOW_DISTANCE:
			dir = signf(squad.position.x - position.x)
	elif absf(home.x - position.x) > HOME_SLACK:
		dir = signf(home.x - position.x)

	if grounded and dir != 0.0 and state.angular_velocity * dir < stats.spin:
		var tip: float = TIP_ASSIST * state.total_gravity.length() * stats.radius * state.inverse_inertia / state.inverse_mass
		state.angular_velocity += dir * (SPIN_ACCEL + tip) * step

	_hop_timer -= step
	if grounded and target != null and _hop_timer <= 0.0 and position.distance_to(target.position) < HOP_RANGE:
		state.linear_velocity += Vector2(dir * stats.hop * 0.4, -stats.hop)
		_hop_timer = _rng.randf_range(HOP_EVERY.x, HOP_EVERY.y)

	if damage > 0.0:
		for hit in Combat.find_hits(state, _corners, _prev_linear, _prev_angular, _is_foe, _cooldowns):
			if hit.target is PlayerShape:
				(hit.target as PlayerShape).take_hit(damage, hit.push, info().get("lethal", true))
			else:
				var foe: Enemy = hit.target
				foe.apply_central_impulse(hit.push * Combat.KNOCKBACK * foe.mass)
				foe.take_hit(damage, 0)
	_prev_linear = state.linear_velocity
	_prev_angular = state.angular_velocity


## Hostiles fight players and soldiers; soldiers fight hostiles.
func _is_foe(o: Object) -> bool:
	if o is PlayerShape:
		return not is_army()
	return o is Enemy and (o as Enemy).is_army() != is_army() and (o as Enemy).hp > 0


## The closest foe inside this enemy's room and within range, or null.
func _nearest_target() -> Node2D:
	var best: Node2D = null
	var best_d := AGGRO_RANGE
	var group := Enemy.GROUP if is_army() else PlayerShape.GROUP
	var candidates := get_tree().get_nodes_in_group(group)
	if not is_army():
		candidates += get_tree().get_nodes_in_group(Enemy.GROUP)
	for node in candidates:
		var foe := node as Node2D
		if foe == null or foe == self or not _is_foe(foe) or not room.has_point(foe.position):
			continue
		var d := position.distance_to(foe.position)
		if d < best_d:
			best_d = d
			best = foe
	return best


## Soldiers: the nearest player in their room, to keep up with.
func _nearest_player() -> PlayerShape:
	var best: PlayerShape = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group(PlayerShape.GROUP):
		var p := node as PlayerShape
		if p == null or not room.has_point(p.position):
			continue
		var d := position.distance_to(p.position)
		if d < best_d:
			best_d = d
			best = p
	return best


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var stats := info()
	if stats.get("still", false):
		# A straw dummy on a stake.
		draw_set_transform(Vector2.ZERO, -rotation)
		draw_line(Vector2(0, stats.radius * 0.7), Vector2(0, stats.radius + STAKE), Palette.INK, 4.0)
		draw_set_transform(Vector2.ZERO, 0.0)
	if is_army():
		Gear.draw_shape(self, _points, stats.sides, PackedStringArray(SOLDIER_WEAR))
	else:
		draw_colored_polygon(_points, _color)
		if stats.get("still", false):
			Gear.draw_hatch(self, _points, [[80.0, 100.0], 7.0], 1.0, Color(Palette.INK, 0.3))
		var outline := _points.duplicate()
		outline.append(_points[0])
		draw_polyline(outline, Palette.INK, 3.0 if is_boss() else 2.5, true)

	draw_set_transform(Vector2.ZERO, -rotation)
	var radius: float = info().radius
	var font := ThemeDB.fallback_font
	if is_boss() or hp < max_hp:
		var width := 120.0 if is_boss() else 44.0
		var bar := Rect2(-width / 2.0, -radius - 14, width, 5 if not is_boss() else 8)
		draw_rect(bar, Palette.PARCHMENT)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * hp / maxf(max_hp, 1), bar.size.y)), Palette.HEALTH)
		draw_rect(bar, Palette.INK, false, 1.0)
	if is_boss():
		draw_string(font, Vector2(-150, -radius - 22), info().name, HORIZONTAL_ALIGNMENT_CENTER, 300, 18,
				Palette.ink_at(position))

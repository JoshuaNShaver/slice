class_name Enemy
extends RigidBody2D
## A cave enemy (design log 0027). The server simulates it and clients draw it,
## like PlayerShape. Enemies are irregular polygons, the book's criminals.
## They roll at the nearest player in their room and hop now and then. Their
## corners hurt you the way yours hurt them (Combat).
##
## The world spawns them, gives out XP and loot when they die, and respawns them.

signal died(enemy: Enemy)

## tier: armor tier this enemy drops. level: about where it's comfortable.
const TYPES := {
	"bandit": {
		"name": "Bandit", "sides": 4, "radius": 22.0, "hp": 140, "damage": 22,
		"xp": 10, "spin": 5.0, "hop": 160.0, "tier": 1, "level": "1-7",
	},
	"brute": {
		"name": "Brute", "sides": 5, "radius": 28.0, "hp": 480, "damage": 40,
		"xp": 40, "spin": 6.0, "hop": 180.0, "tier": 2, "level": "7-14",
	},
	"zealot": {
		"name": "Zealot", "sides": 6, "radius": 32.0, "hp": 1100, "damage": 65,
		"xp": 80, "spin": 7.0, "hop": 200.0, "tier": 3, "level": "14-20",
	},
	"pretender": {
		"name": "The Pretender", "sides": 12, "radius": 72.0, "hp": 6000, "damage": 110,
		"xp": 400, "spin": 3.5, "hop": 320.0, "tier": 4, "level": "20",
		"boss": true,
	},
}

const AGGRO_RANGE := 520.0
const HOP_RANGE := 180.0  # hops when a target is this close
const HOP_EVERY := Vector2(1.2, 2.6)  # seconds between hops, random in this range
const SPIN_ACCEL := 6.0
const TIP_ASSIST := 0.75  # as PlayerShape.TIP_ASSIST
const HOME_SLACK := 40.0  # px from home that counts as home

const LAYER := 4

var type := "bandit"
var room := Rect2()  # the area it guards; it only chases players inside this
var home := Vector2.ZERO
var hp := 100
var max_hp := 100
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
	e._color = data.color
	var info: Dictionary = TYPES[e.type]
	e.max_hp = info.hp
	e.hp = info.hp
	e._points = ShapeGeometry.points(info.sides, "irregular", info.radius)
	e._corners = ShapeGeometry.points(info.sides, "irregular", info.radius + PlayerShape.COLLISION_PAD)

	var shape := CollisionPolygon2D.new()
	shape.polygon = e._corners
	e.add_child(shape)
	e.collision_layer = LAYER
	e.collision_mask = PlayerShape.LAYER_TERRAIN | PlayerShape.LAYER_PLAYERS | LAYER
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


func _ready() -> void:
	_rng.randomize()
	if not multiplayer.is_server():
		freeze = true
		freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC


func info() -> Dictionary:
	return TYPES[type]


func is_boss() -> bool:
	return info().get("boss", false)


## Server only.
func take_hit(damage: float, from_peer: int, crit := false) -> void:
	if hp <= 0:
		return
	contributors[from_peer] = true
	hp = maxi(hp - roundi(damage), 0)
	get_tree().call_group(World.GROUP, "show_damage", position + Vector2(0, -24), roundi(damage),
			"crit" if crit else "enemy")
	if hp == 0:
		died.emit(self)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not multiplayer.is_server() or hp <= 0:
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
	elif absf(home.x - position.x) > HOME_SLACK:
		dir = signf(home.x - position.x)

	if grounded and dir != 0.0 and state.angular_velocity * dir < stats.spin:
		var tip: float = TIP_ASSIST * state.total_gravity.length() * stats.radius * state.inverse_inertia / state.inverse_mass
		state.angular_velocity += dir * (SPIN_ACCEL + tip) * step

	_hop_timer -= step
	if grounded and target != null and _hop_timer <= 0.0 and position.distance_to(target.position) < HOP_RANGE:
		state.linear_velocity += Vector2(dir * stats.hop * 0.4, -stats.hop)
		_hop_timer = _rng.randf_range(HOP_EVERY.x, HOP_EVERY.y)

	for hit in Combat.find_hits(state, _corners, _prev_linear, _prev_angular,
			func(o: Object) -> bool: return o is PlayerShape, _cooldowns):
		var player: PlayerShape = hit.target
		player.take_hit(stats.damage, hit.push)
	_prev_linear = state.linear_velocity
	_prev_angular = state.angular_velocity


## The closest player inside this enemy's room and within range, or null.
func _nearest_target() -> PlayerShape:
	var best: PlayerShape = null
	var best_d := AGGRO_RANGE
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
	draw_colored_polygon(_points, _color)
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
		draw_string(font, Vector2(-150, -radius - 22), info().name, HORIZONTAL_ALIGNMENT_CENTER, 300, 18, Palette.INK)

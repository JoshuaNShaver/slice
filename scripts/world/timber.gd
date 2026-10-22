class_name Timber
extends StaticBody2D
## One of the Logging Isle's great trees (design log 0202), taller than the
## screen. Jump (or roll) a corner into its trunk to hurt it, as you would
## an enemy (PlayerCombat). It has HEALTH, never shown; every LOG_EVERY
## damage drops a log for one of the players who hit it, picked at random
## weighted by how much each did. At 0 it falls, leaving a stump, and grows
## back after REGROW.
##
## The server spawns the trees (World) and copies them to clients; `felled`
## and `struck` (to shake it) are synced.

const GROUP := "timber"
const HEALTH := 10000
const LOG_EVERY := 1000
const REGROW := 180.0  # s, *proposed*
const HEIGHT := 1500.0  # px from the foot up: well past the top of the screen
const TRUNK := 70.0  # px wide at the foot
const SHAKE_TIME := 0.25

var felled := false:
	set(value):
		felled = value
		if _trunk != null:
			_trunk.set_deferred("disabled", value)
var struck := 0:  # hits so far, so clients can shake it
	set(value):
		struck = value
		_shake = SHAKE_TIME

var _trunk: CollisionPolygon2D
var _damage := 0  # server: dealt so far this growth
var _dropped := 0  # logs dropped so far this growth
var _by_peer := {}  # server: peer id -> damage dealt
var _regrow_left := 0.0
var _shake := 0.0
var _seed := 0


## data: {"name", "pos" (the foot of the trunk, on the ground)}.
static func create(data: Dictionary) -> Timber:
	var t := Timber.new()
	t.name = data.name
	t.position = data.pos
	t._seed = hash(data.name)
	t.collision_layer = PlayerShape.LAYER_TERRAIN
	t.collision_mask = 0
	t._trunk = CollisionPolygon2D.new()
	t._trunk.polygon = PackedVector2Array([Vector2(-TRUNK / 2.0, 0), Vector2(-TRUNK * 0.4, -HEIGHT),
			Vector2(TRUNK * 0.4, -HEIGHT), Vector2(TRUNK / 2.0, 0)])
	t.add_child(t._trunk)

	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var config := SceneReplicationConfig.new()
	config.add_property(".:position")
	config.property_set_spawn(".:position", true)
	config.property_set_replication_mode(".:position", SceneReplicationConfig.REPLICATION_MODE_NEVER)
	for prop: String in [".:felled", ".:struck"]:
		config.add_property(prop)
		config.property_set_spawn(prop, true)
		config.property_set_replication_mode(prop, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	sync.replication_config = config
	sync.add_visibility_filter(func(id: int) -> bool: return Net.players.has(id))
	t.add_child(sync)
	return t


func _ready() -> void:
	add_to_group(GROUP)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or not felled:
		return
	_regrow_left -= delta
	if _regrow_left <= 0.0:
		_damage = 0
		_dropped = 0
		_by_peer.clear()
		felled = false


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake -= delta
		queue_redraw()


## Server only. A player's corner hit (PlayerCombat).
func take_hit(raw: float, from_peer: int, crit := false) -> void:
	if felled:
		return
	var dealt := roundi(raw)
	if dealt <= 0:
		return
	_damage += dealt
	_by_peer[from_peer] = int(_by_peer.get(from_peer, 0)) + dealt
	struck += 1
	get_tree().call_group(World.GROUP, "show_damage", position + Vector2(0, -80 - randf() * 60), dealt,
			"crit" if crit else "enemy")
	while _dropped < HEALTH / LOG_EVERY and _damage >= (_dropped + 1) * LOG_EVERY:
		_dropped += 1
		_drop_log()
	if _damage >= HEALTH:
		felled = true
		_regrow_left = REGROW


## A log for one of the players who hit it, weighted by damage dealt.
func _drop_log() -> void:
	var world := get_tree().get_first_node_in_group(World.GROUP)  # World, or a test's stand-in
	if world == null:
		return
	var total := 0
	var hitters := {}
	for id: int in _by_peer:
		if world.call("player", id) != null:
			hitters[id] = _by_peer[id]
			total += _by_peer[id]
	if total <= 0:
		return
	var roll := randi_range(1, total)
	for id: int in hitters:
		roll -= hitters[id]
		if roll <= 0:
			var who: PlayerShape = world.call("player", id)
			var side := signf(who.position.x - position.x)
			if side == 0.0:
				side = 1.0
			world.call_deferred("drop_item", Gear.LOG, id, position + Vector2(side * (TRUNK + 30.0), -30.0))
			who.quests.notify("log", "")
			return


func _draw() -> void:
	var ink := Palette.INK
	if felled:
		var stump := PackedVector2Array([Vector2(-TRUNK / 2.0, 0), Vector2(-TRUNK * 0.48, -40),
				Vector2(TRUNK * 0.48, -46), Vector2(TRUNK / 2.0, 0)])
		draw_colored_polygon(stump, Palette.PARCHMENT_LIGHT)
		stump.append(stump[0])
		draw_polyline(stump, ink, 2.5, true)
		draw_arc(Vector2(0, -43), TRUNK * 0.3, PI, TAU, 12, Palette.INK_FADED, 1.5, true)
		return
	var sway := 0.0
	if _shake > 0.0:
		sway = sin(_shake * 80.0) * 4.0 * (_shake / SHAKE_TIME)
	var trunk := PackedVector2Array([Vector2(-TRUNK / 2.0, 0), Vector2(-TRUNK * 0.4 + sway, -HEIGHT),
			Vector2(TRUNK * 0.4 + sway, -HEIGHT), Vector2(TRUNK / 2.0, 0)])
	draw_colored_polygon(trunk, Palette.PARCHMENT_LIGHT)
	# Bark: short strokes up the trunk, the same for this tree every time.
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var y := -30.0
	while y > -HEIGHT + 20.0:
		var k := -y / HEIGHT
		var half := lerpf(TRUNK / 2.0, TRUNK * 0.4, k) - 8.0
		var x := rng.randf_range(-half, half) + sway * k
		draw_line(Vector2(x, y), Vector2(x + rng.randf_range(-3, 3), y - rng.randf_range(18, 40)),
				Palette.INK_FADED, 1.5)
		y -= rng.randf_range(14, 30)
	draw_line(trunk[0], trunk[1], ink, 3.0, true)
	draw_line(trunk[3], trunk[2], ink, 3.0, true)
	# Branches, high up, reaching out of the top of the screen.
	for i in 5:
		var from := Vector2(sway * 0.8, -HEIGHT * (0.55 + 0.09 * i))
		var side := -1.0 if i % 2 == 0 else 1.0
		draw_line(from + Vector2(side * TRUNK * 0.3, 0), from + Vector2(side * rng.randf_range(90, 160), -rng.randf_range(60, 120)),
				ink, 2.5, true)
	# Roots.
	for side in [-1.0, 1.0]:
		draw_line(Vector2(side * TRUNK / 2.0, 0), Vector2(side * (TRUNK / 2.0 + 26), 6), ink, 2.5, true)

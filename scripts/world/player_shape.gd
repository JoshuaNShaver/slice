class_name PlayerShape
extends RigidBody2D
## One player's polygon in the world.
##
## The server simulates it; clients only draw it (design log 0013). The owner
## sends its input to the server. Left/right spin the shape so it tumbles over
## its corners, and Space jumps (design log 0004). Because it is a real
## polygon, slope grip comes from the shape itself: sharp shapes rest on steep
## ground while many-sided shapes roll off.
##
## Movement is momentum-based. Holding a roll key raises your top spin over a
## few seconds, and nothing caps the speed you gain rolling downhill. Jumping
## again right as you land is a bounce: off a face it goes higher, and off a
## corner it goes higher still and flips you.
##
## Stats (design logs 0021-0022) live here too. The server owns them and they
## sync to every client for the bars. A jump costs energy; with too little
## energy you still jump, just weakly.

const RADIUS := 28.0
const COLLISION_PAD := 2.0

# Rolling
const SPIN_ACCEL := 5.0  # rad/s² you add while holding a roll key
## Extra push, as a multiple of gravity's pull at one radius. Above 1, any
## shape can tip over its corner from rest.
const TIP_ASSIST := .75
const BASE_SPIN := 5.0  # top spin (rad/s) you can push to right away
const TOP_SPIN := 12.0  # top spin after holding the key for RAMP_TIME
const RAMP_TIME := 1.5
const AIR_SPEED := 120.0  # top sideways speed you can steer to in the air
const AIR_ACCEL := 150.0

# Jumping
const JUMP_SPEED := 150.0
const FACE_BOUNCE := 1.3  # jump multiplier when bouncing off a face
const CORNER_BOUNCE := 1.55  # ... and off a corner
const FLIP_SPIN := 16.0  # rad/s spin a corner bounce gives you
const FLIP_PUSH := 160.0  # sideways speed a corner bounce adds
const BOUNCE_WINDOW := 0.18  # jump this soon after landing to bounce
const MIN_AIR_TIME := 0.12  # shorter hops don't count as a landing
const COYOTE_TIME := 0.1  # can still jump this long after leaving the ground
const JUMP_BUFFER := 0.15  # a jump pressed this long before landing still counts
## Landing counts as on a face if the two lowest corners are this level
## (sine of the tilt between the bottom edge and the ground).
const FACE_TILT := 0.14

const JUMP_COST := 25.0
const WEAK_JUMP := 0.55  # jump speed multiplier when you can't pay the cost

const FALL_LIMIT := 2000.0  # fall below this and you go back to the spawn point

const LAYER_TERRAIN := 1
const LAYER_PLAYERS := 2

var peer_id := 0
var family_name := ""
var sides := 3
var kind := "regular"
var spawn_point := Vector2.ZERO
var sync: MultiplayerSynchronizer

# Stats: set by the server, synced to clients.
var level := 1
var vigor := 0
var mettle := 0
var force := 0
var torque := 0
var rigidity := 0  # from armor only (design log 0021)
var luck := 0
var hp := Stats.BASE_HP
var max_hp := Stats.BASE_HP
var energy := Stats.MAX_ENERGY

var _points: PackedVector2Array
# Server-side state.
var _move := 0.0
var _jump_timer := 0.0
var _since_ground := INF
var _air_time := 0.0
var _landed_timer := 0.0
var _landed_on_corner := false
var _ground_normal := Vector2.UP
var _hold_time := 0.0
var _hold_dir := 0.0
# Owner-side: last move value sent, so we only send changes.
var _sent_move := 0.0


## Used by the world's MultiplayerSpawner on the server and on every client.
static func create(data: Dictionary) -> PlayerShape:
	var p := PlayerShape.new()
	p.peer_id = data.id
	p.name = str(data.id)
	p.family_name = data.family
	p.sides = data.sides
	p.kind = data.kind
	p.luck = data.get("luck", 0)
	p.spawn_point = data.pos
	p.position = data.pos
	p._points = ShapeGeometry.points(p.sides, p.kind, RADIUS)

	# The collision outline is a little bigger than the drawing, so the solver's
	# small overlap on impact doesn't look like corners sinking into the ground.
	var shape := CollisionPolygon2D.new()
	shape.polygon = ShapeGeometry.points(p.sides, p.kind, RADIUS + COLLISION_PAD)
	p.add_child(shape)

	# Players pass through each other for now; they only collide with terrain.
	p.collision_layer = LAYER_PLAYERS
	p.collision_mask = LAYER_TERRAIN
	p.physics_material_override = PhysicsMaterial.new()
	p.physics_material_override.friction = 0.9
	p.physics_material_override.bounce = 0.2
	p.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	p.angular_damp = 0.1  # keep spin: momentum is the point
	p.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE  # stops fast corners sinking into the ground
	p.contact_monitor = true
	p.max_contacts_reported = 6
	p.custom_integrator = false
	p.can_sleep = false

	p.sync = MultiplayerSynchronizer.new()
	p.sync.name = "Sync"
	var config := SceneReplicationConfig.new()
	for prop: String in [".:position", ".:rotation", ".:energy"]:
		config.add_property(prop)
		config.property_set_spawn(prop, true)
		config.property_set_replication_mode(prop, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	for stat: String in ["level", "vigor", "mettle", "force", "torque", "rigidity", "luck", "hp", "max_hp"]:
		var prop := ".:" + stat
		config.add_property(prop)
		config.property_set_spawn(prop, true)
		config.property_set_replication_mode(prop, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	p.sync.replication_config = config
	# Only peers whose world has loaded (registered players) get this shape.
	p.sync.add_visibility_filter(func(id: int) -> bool: return Net.players.has(id))
	p.add_child(p.sync)
	return p


static func ensure_input_actions() -> void:
	var actions := {
		"roll_left": [KEY_LEFT, KEY_A],
		"roll_right": [KEY_RIGHT, KEY_D],
		"jump": [KEY_SPACE],
		"debug_level_up": [KEY_L],
	}
	for action: String in actions:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in actions[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)


func _ready() -> void:
	# Clients never simulate: the server's position and rotation are copied in.
	if not multiplayer.is_server():
		freeze = true
		freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC


func is_local() -> bool:
	return peer_id == multiplayer.get_unique_id()


func _physics_process(_delta: float) -> void:
	if not is_local():
		return
	var move := Input.get_axis("roll_left", "roll_right")
	if move != _sent_move:
		_sent_move = move
		_submit_move.rpc_id(1, move)
	if Input.is_action_just_pressed("jump"):
		_submit_jump.rpc_id(1)
	# There's no XP yet, so debug builds can level up by hand to test scaling.
	if OS.is_debug_build() and Input.is_action_just_pressed("debug_level_up"):
		_submit_debug_level_up.rpc_id(1)


func _process(_delta: float) -> void:
	queue_redraw()  # keeps the name tag upright as the shape turns


## Owner -> server.
@rpc("any_peer", "call_local", "reliable")
func _submit_move(move: float) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() in [peer_id, 0]:
		_move = clampf(move, -1.0, 1.0)


## Owner -> server.
@rpc("any_peer", "call_local", "reliable")
func _submit_jump() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() in [peer_id, 0]:
		_jump_timer = JUMP_BUFFER


## Owner -> server. Debug builds only.
@rpc("any_peer", "call_local", "reliable")
func _submit_debug_level_up() -> void:
	if OS.is_debug_build() and multiplayer.is_server() and multiplayer.get_remote_sender_id() in [peer_id, 0]:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		level_up(rng)


## Server only.
func level_up(rng: RandomNumberGenerator) -> void:
	if level >= Stats.MAX_LEVEL:
		return
	level += 1
	var gains := Stats.roll_level_gains(rng)
	vigor += gains.vigor
	mettle += gains.mettle
	force += gains.force
	torque += gains.torque
	var new_max := Stats.max_hp(vigor)
	hp += new_max - max_hp  # the new health arrives full
	max_hp = new_max


## Server only.
func take_damage(raw: float) -> void:
	hp = maxi(hp - roundi(Stats.damage_taken(raw, rigidity)), 0)


## Damage one of your corners deals, by its angle in degrees.
func corner_damage(corner_deg: float) -> float:
	return Stats.corner_damage(corner_deg, force)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not multiplayer.is_server():
		return
	energy = minf(energy + Stats.energy_regen(mettle) * state.step, Stats.MAX_ENERGY)
	if state.transform.origin.y > FALL_LIMIT:
		state.transform = Transform2D(0.0, spawn_point)
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0
		return

	# The ground contact farthest in the rolling direction is the corner we
	# tip over next.
	var step := state.step
	var normal := Vector2.ZERO
	for i in state.get_contact_count():
		var n := state.get_contact_local_normal(i)
		if n.y < -0.5:
			normal += n
	var touching_ground := normal != Vector2.ZERO
	if touching_ground:
		_ground_normal = normal.normalized()
		if _air_time > MIN_AIR_TIME:
			_landed_timer = BOUNCE_WINDOW
			_landed_on_corner = _resting_on_corner(state.transform)
		_air_time = 0.0
		_since_ground = 0.0
	else:
		_air_time += step
		_since_ground += step
	_landed_timer -= step
	var grounded := _since_ground <= COYOTE_TIME

	# Holding the same direction raises your top spin.
	if _move != 0.0 and _move == _hold_dir:
		_hold_time += step
	else:
		_hold_dir = _move
		_hold_time = 0.0

	var spin_scale := Stats.spin_scale(torque)
	if grounded and _move != 0.0:
		var top := spin_scale * lerpf(BASE_SPIN, TOP_SPIN, clampf(_hold_time / RAMP_TIME, 0.0, 1.0))
		# Push only up to the top spin. Gravity can take you past it downhill.
		if state.angular_velocity * _move < top:
			var tip := TIP_ASSIST * state.total_gravity.length() * RADIUS * state.inverse_inertia / state.inverse_mass
			state.angular_velocity += _move * (SPIN_ACCEL * spin_scale + tip) * step
	elif not grounded and _move != 0.0:
		# Mid-air you can drift sideways but not turn (DESIGN §9 question 7 is open).
		var vx := state.linear_velocity.x
		if absf(vx) < AIR_SPEED or signf(vx) != signf(_move):
			state.linear_velocity.x = move_toward(vx, _move * AIR_SPEED, AIR_ACCEL * step)

	if _jump_timer > 0.0:
		_jump_timer -= step
		if grounded:
			_jump(state)


func _jump(state: PhysicsDirectBodyState2D) -> void:
	var bounce := _landed_timer > 0.0
	var power := 1.0
	if bounce:
		power = CORNER_BOUNCE if _landed_on_corner else FACE_BOUNCE
	if energy >= JUMP_COST:
		energy -= JUMP_COST
	else:
		power *= WEAK_JUMP
	# Jump away from the ground, leaning with the slope.
	var dir := (Vector2.UP + _ground_normal).normalized()
	var v := state.linear_velocity
	v += dir * (JUMP_SPEED * power - v.dot(dir))
	if bounce and _landed_on_corner:
		var flip_dir := signf(_move)
		if flip_dir == 0.0:
			flip_dir = signf(v.x) if absf(v.x) > 20.0 else signf(state.angular_velocity)
		if flip_dir == 0.0:
			flip_dir = 1.0
		state.angular_velocity = flip_dir * maxf(FLIP_SPIN, absf(state.angular_velocity))
		v.x += flip_dir * FLIP_PUSH
	state.linear_velocity = v
	_jump_timer = 0.0
	_landed_timer = 0.0
	_since_ground = INF


## True if a corner, not a flat face, is what's touching the ground.
func _resting_on_corner(xform: Transform2D) -> bool:
	var lowest := Vector2.ZERO
	var second := Vector2.ZERO
	var low_h := INF
	var second_h := INF
	for p in _points:
		var w := xform * p
		var h := w.dot(_ground_normal)  # higher points have bigger h
		if h < low_h:
			second = lowest
			second_h = low_h
			lowest = w
			low_h = h
		elif h < second_h:
			second = w
			second_h = h
	return (second_h - low_h) / maxf(lowest.distance_to(second), 0.001) > FACE_TILT


func _draw() -> void:
	draw_colored_polygon(_points, Palette.chalk_for_sides(sides))
	var outline := _points.duplicate()
	outline.append(_points[0])
	draw_polyline(outline, Palette.INK, 2.5, true)

	draw_set_transform(Vector2.ZERO, -rotation)
	var font := ThemeDB.fallback_font
	var tag := family_name + (" (you)" if is_local() else "")
	draw_string(font, Vector2(-150, -RADIUS - 12), tag, HORIZONTAL_ALIGNMENT_CENTER, 300, 15, Palette.INK_FADED)
	# Other players get a small health bar under their name. Yours is in the HUD.
	if not is_local():
		var bar := Rect2(-24, -RADIUS - 9, 48, 5)
		draw_rect(bar, Palette.PARCHMENT)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * hp / maxf(max_hp, 1), bar.size.y)), Palette.HEALTH)
		draw_rect(bar, Palette.INK, false, 1.0)

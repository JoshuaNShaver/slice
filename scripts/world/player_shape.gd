class_name PlayerShape
extends RigidBody2D
## One player's polygon in the world.
##
## The server simulates it; clients only draw it (design log 0013). The owner
## sends its input to the server. Left/right spin the shape so it rolls over
## its corners, and Space jumps (design log 0004). Because it is a real
## polygon, slope grip comes from the shape itself: sharp shapes rest on steep
## ground while many-sided shapes roll off.

const RADIUS := 28.0
const MAX_SPIN := 9.0  # rad/s while rolling on the ground
const SPIN_ACCEL := 45.0  # rad/s²
const JUMP_SPEED := 560.0
const AIR_SPEED := 240.0  # top sideways speed you can steer to in the air
const AIR_ACCEL := 600.0
const COYOTE_TIME := 0.1  # can still jump this long after leaving the ground
const JUMP_BUFFER := 0.15  # a jump pressed this long before landing still counts
const FALL_LIMIT := 2000.0  # fall below this and you go back to the spawn point

const LAYER_TERRAIN := 1
const LAYER_PLAYERS := 2

var peer_id := 0
var family_name := ""
var sides := 3
var kind := "regular"
var spawn_point := Vector2.ZERO
var sync: MultiplayerSynchronizer

var _points: PackedVector2Array
# Server-side input state.
var _move := 0.0
var _jump_timer := 0.0
var _since_ground := INF
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
	p.spawn_point = data.pos
	p.position = data.pos
	p._points = ShapeGeometry.points(p.sides, p.kind, RADIUS)

	var shape := CollisionPolygon2D.new()
	shape.polygon = p._points
	p.add_child(shape)

	# Players pass through each other for now; they only collide with terrain.
	p.collision_layer = LAYER_PLAYERS
	p.collision_mask = LAYER_TERRAIN
	p.physics_material_override = PhysicsMaterial.new()
	p.physics_material_override.friction = 1.0
	p.physics_material_override.bounce = 0.0
	p.contact_monitor = true
	p.max_contacts_reported = 6
	p.custom_integrator = false
	p.can_sleep = false

	p.sync = MultiplayerSynchronizer.new()
	p.sync.name = "Sync"
	var config := SceneReplicationConfig.new()
	for prop: String in [".:position", ".:rotation"]:
		config.add_property(prop)
		config.property_set_spawn(prop, true)
		config.property_set_replication_mode(prop, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
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


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not multiplayer.is_server():
		return
	if state.transform.origin.y > FALL_LIMIT:
		state.transform = Transform2D(0.0, spawn_point)
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0
		return

	# The ground contact farthest in the rolling direction is the corner we
	# tip over next.
	var touching_ground := false
	var pivot := Vector2.ZERO
	var best := -INF
	for i in state.get_contact_count():
		if state.get_contact_local_normal(i).y >= -0.5:
			continue
		touching_ground = true
		var point := state.get_contact_local_position(i)  # global coordinates in Godot 4
		if point.x * _move > best:
			best = point.x * _move
			pivot = point
	_since_ground = 0.0 if touching_ground else _since_ground + state.step
	var grounded := _since_ground <= COYOTE_TIME

	if touching_ground and _move != 0.0:
		# Turn about the pivot corner. Spinning alone can't lift a triangle
		# over its corner, so the body also moves as if hinged there.
		# Only steer while a key is held, so an idle shape settles (or rolls
		# downhill) on its own.
		var spin := move_toward(state.angular_velocity, _move * MAX_SPIN, SPIN_ACCEL * state.step)
		var arm := state.transform.origin - pivot
		state.angular_velocity = spin
		state.linear_velocity = spin * Vector2(-arm.y, arm.x)
	elif not grounded and _move != 0.0:
		# Mid-air you can drift sideways but not turn (DESIGN §9 question 7 is open).
		var vx := state.linear_velocity.x
		if absf(vx) < AIR_SPEED or signf(vx) != signf(_move):
			state.linear_velocity.x = move_toward(vx, _move * AIR_SPEED, AIR_ACCEL * state.step)

	if _jump_timer > 0.0:
		_jump_timer -= state.step
		if grounded:
			_jump_timer = 0.0
			_since_ground = INF
			state.linear_velocity.y = -JUMP_SPEED


func _draw() -> void:
	draw_colored_polygon(_points, Palette.chalk_for_sides(sides))
	var outline := _points.duplicate()
	outline.append(_points[0])
	draw_polyline(outline, Palette.INK, 2.5, true)

	draw_set_transform(Vector2.ZERO, -rotation)
	var font := ThemeDB.fallback_font
	var tag := family_name + (" (you)" if is_local() else "")
	draw_string(font, Vector2(-150, -RADIUS - 12), tag, HORIZONTAL_ALIGNMENT_CENTER, 300, 15, Palette.INK_FADED)

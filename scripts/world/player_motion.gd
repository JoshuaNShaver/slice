class_name PlayerMotion
extends Node
## A player's movement (PlayerShape's "Motion"). Server only, but for the
## owner's input RPCs, and an online owner's own shape runs integrate() while
## it plays on through a gap in the server's updates (log 0173).
##
## Left/right spin the shape so it tumbles over its corners, and Space jumps
## (design log 0004). Movement is momentum-based. Holding a roll key raises
## your top spin over a few seconds, and nothing caps the speed you gain
## rolling downhill. Jumping again right as you land is a bounce: off a face
## it goes higher, and off a corner it goes higher still and flips you.
##
## Also here: the home key and teleports (logs 0034, 0059), elevator rides
## (logs 0054, 0058) and being thrown by a boss's spike up (log 0089).

# Rolling
const SPIN_ACCEL := 5.0  # rad/s² you add while holding a roll key
## Extra push, as a multiple of gravity's pull at one radius. Above 1, any
## shape can tip over its corner from rest, so holding a roll key is enough
## to tumble along, even for a flat-sided triangle or square (log 0228).
const TIP_ASSIST := 1.4
const BASE_SPIN := 5.0  # top spin (rad/s) you can push to right away
const TOP_SPIN := 12.0  # top spin after holding the key for RAMP_TIME
const RAMP_TIME := 1.5
const AIR_SPEED := 120.0  # top sideways speed you can steer to in the air
const AIR_ACCEL := 150.0

# Jumping
## Rises about 112 px under the default 980 px/s² gravity: twice the height
## of a full-size shape, 2 * RADIUS (log 0228).
const JUMP_SPEED := 470.0
## How much more a jump points straight up than away from the slope.
const JUMP_UPRIGHT := 4.0
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

const TELEPORT_GHOST_STEPS := 3
const FALL_LIMIT := 4500.0  # fall below this and you go back to the spawn point
const RIDE_SPEED := 650.0  # px/s, elevators
## On a boat's deck you lean rather than roll (log 0201): top spin is capped.
const DECK_SPIN := 2.5

## What integrate() did: HALT ends the step (a ride or a teleport), THROWN
## means you're helpless in the air, JUMPED that you jumped this step.
enum { HALT, THROWN, FREE, JUMPED }

var player: PlayerShape
var move := 0.0  # the owner's roll input, -1 to 1
var ground_normal := Vector2.UP
var touching_ground := false  # this step
var on_boat: Boat = null  # this step, standing on one
var grounded := false  # this step, counting coyote time
var _jump_timer := 0.0
var _since_ground := INF
var _air_time := 0.0
var _landed_timer := 0.0
var _landed_on_corner := false
var _hold_time := 0.0
var _hold_dir := 0.0
var _teleport_to: Variant = null  # Vector2 to move to on the next physics step
var _ghost_steps := 0  # physics steps left with collisions off after a teleport
var _ride := {}  # an elevator ride, {"from", "to", "time", "length"}
var _launch: Variant = null  # Vector2 velocity to take next step (a boss's spike up)
var _thrown := 0.0  # s left helpless in the air after a launch
var _thrown_onto: Node2D = null


## Owner -> server.
@rpc("any_peer", "call_local", "reliable")
func _submit_move(value: float) -> void:
	if player.from_owner():
		move = clampf(value, -1.0, 1.0)


## Owner -> server.
@rpc("any_peer", "call_local", "reliable")
func _submit_jump() -> void:
	if player.from_owner():
		press_jump()


## A jump pressed: on the server, and on your own shape while it plays on
## through a gap in the server's updates (log 0173).
func press_jump() -> void:
	_jump_timer = JUMP_BUFFER


## Owner -> server: teleport home, from anywhere, any time (logs 0034, 0059).
@rpc("any_peer", "call_local", "reliable")
func _submit_home() -> void:
	if player.from_owner() and not player.dead:
		teleport(player.spawn_point)


func riding() -> bool:
	return not _ride.is_empty()


## Server only. Moves the shape to `pos` on the next physics step.
## Collisions stay off for a few steps around the jump, as on an elevator:
## with them on, continuous collision treats a long jump (the Undercroft to
## the Center) as one fast move and drives the shape into the ground.
func teleport(pos: Vector2) -> void:
	_ride = {}
	player.moves.cancel()
	_thrown = 0.0
	_teleport_to = pos
	_ghost_steps = TELEPORT_GHOST_STEPS
	player.collision_mask = 0


## Server only. An elevator carries you from `from` to `to`. Collisions are
## off for the ride, so the shaft can pass through rock.
func start_ride(from: Vector2, to: Vector2) -> void:
	if player.dead or not _ride.is_empty():
		return
	_ride = {"from": from, "to": to, "time": 0.0, "length": 0.6 + from.distance_to(to) / RIDE_SPEED}
	player.collision_mask = 0


func _end_ride() -> void:
	if _ride.is_empty():
		return
	_ride = {}
	if _ghost_steps == 0:
		player.set_deferred("collision_mask", PlayerShape.MASK)


## Server only. Thrown into the air by a boss's spike up (design log 0089):
## you take this velocity and can't steer, jump or use abilities until you
## land, drifting to come down on `onto`.
func launch(velocity: Vector2, onto: Node2D) -> void:
	if player.dead or not _ride.is_empty():
		return
	_launch = velocity
	_thrown = 1.5
	_thrown_onto = onto


## Server only. Ends the ground state a jump ends (also a nose dive's leap).
func left_ground() -> void:
	_jump_timer = 0.0
	_landed_timer = 0.0
	_since_ground = INF


## Server only. This step's movement: a ride or a teleport, else rolling,
## steering in the air and jumping. Returns HALT, THROWN, FREE or JUMPED.
func integrate(state: PhysicsDirectBodyState2D) -> int:
	if not _ride.is_empty():
		_ride.time += state.step
		var k := clampf(_ride.time / _ride.length, 0.0, 1.0)
		state.transform = Transform2D(0.0, (_ride.from as Vector2).lerp(_ride.to, smoothstep(0.0, 1.0, k)))
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0
		if k >= 1.0:
			_end_ride()
		return HALT
	if _ghost_steps > 0 and _teleport_to == null:
		_ghost_steps -= 1
		if _ghost_steps == 0:
			player.set_deferred("collision_mask", PlayerShape.MASK)
	if _teleport_to == null and state.transform.origin.y > FALL_LIMIT and multiplayer.is_server():
		teleport(player.spawn_point)
	if _teleport_to == null and multiplayer.is_server():
		Coast.hold_back(player, state)  # workmen only (log 0200)
		if Ocean.drowns(state.transform.origin, Ocean.now()):
			player.actions.drown()  # log 0201
	if _teleport_to != null:
		state.transform = Transform2D(0.0, _teleport_to)
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0
		_teleport_to = null
		return HALT

	# The ground contact farthest in the rolling direction is the corner we
	# tip over next.
	var step := state.step
	var normal := Vector2.ZERO
	on_boat = null
	for i in state.get_contact_count():
		var n := state.get_contact_local_normal(i)
		if n.y < -0.5:
			normal += n
			var boat := state.get_contact_collider_object(i) as Boat
			if boat != null:
				on_boat = boat
	touching_ground = normal != Vector2.ZERO
	if touching_ground:
		ground_normal = normal.normalized()
		if _air_time > MIN_AIR_TIME:
			_landed_timer = BOUNCE_WINDOW
			_landed_on_corner = _resting_on_corner(state.transform)
		_air_time = 0.0
		_since_ground = 0.0
	else:
		_air_time += step
		_since_ground += step
	_landed_timer -= step
	grounded = _since_ground <= COYOTE_TIME

	if _apply_thrown(state, touching_ground):
		_jump_timer = 0.0
		return THROWN

	# Holding the same direction raises your top spin.
	if move != 0.0 and move == _hold_dir:
		_hold_time += step
	else:
		_hold_dir = move
		_hold_time = 0.0

	var spin_scale := Stats.spin_scale(player.stats.torque)
	if grounded and move != 0.0:
		var top := spin_scale * lerpf(BASE_SPIN, TOP_SPIN, clampf(_hold_time / RAMP_TIME, 0.0, 1.0))
		if on_boat != null:
			top = minf(top, DECK_SPIN)
		# Push only up to the top spin. Gravity can take you past it downhill.
		if state.angular_velocity * move < top:
			var tip := TIP_ASSIST * state.total_gravity.length() * PlayerShape.RADIUS * state.inverse_inertia / state.inverse_mass
			state.angular_velocity += move * (SPIN_ACCEL * spin_scale + tip) * step
	elif not grounded and move != 0.0:
		# Mid-air you can drift sideways but not turn (DESIGN §9 question 5 is open).
		var vx := state.linear_velocity.x
		if absf(vx) < AIR_SPEED or signf(vx) != signf(move):
			state.linear_velocity.x = move_toward(vx, move * AIR_SPEED, AIR_ACCEL * step)

	if _jump_timer > 0.0:
		_jump_timer -= step
		if grounded:
			_jump(state)
			return JUMPED
	return FREE


func _jump(state: PhysicsDirectBodyState2D) -> void:
	var bounce := _landed_timer > 0.0
	var power := 1.0
	if bounce:
		power = CORNER_BOUNCE if _landed_on_corner else FACE_BOUNCE
	# Jump up, leaning only a little with the slope: at full jump speed a
	# bigger lean throws you downhill whichever way you're heading (log 0228).
	var dir := (Vector2.UP * JUMP_UPRIGHT + ground_normal).normalized()
	var v := state.linear_velocity
	v += dir * (JUMP_SPEED * power - v.dot(dir))
	if bounce and _landed_on_corner:
		var flip_dir := signf(move)
		if flip_dir == 0.0:
			flip_dir = signf(v.x) if absf(v.x) > 20.0 else signf(state.angular_velocity)
		if flip_dir == 0.0:
			flip_dir = 1.0
		state.angular_velocity = flip_dir * maxf(FLIP_SPIN, absf(state.angular_velocity))
		v.x += flip_dir * FLIP_PUSH
	state.linear_velocity = v
	left_ground()


## Applies a launch, then steers the fall. True while you're helpless.
func _apply_thrown(state: PhysicsDirectBodyState2D, touching: bool) -> bool:
	if _launch != null:
		state.linear_velocity = _launch
		_launch = null
		player.moves.cancel()
		return true
	if _thrown <= 0.0:
		return false
	_thrown -= state.step
	if touching and state.linear_velocity.y >= 0.0 and _thrown < 1.2:
		_thrown = 0.0
	elif state.get_contact_count() == 0 and is_instance_valid(_thrown_onto):
		var gap := _thrown_onto.global_position.x - state.transform.origin.x
		state.linear_velocity.x = clampf(gap * 4.0, -400.0, 400.0)
	return _thrown > 0.0


## True if a corner, not a flat face, is what's touching the ground.
func _resting_on_corner(xform: Transform2D) -> bool:
	var lowest := Vector2.ZERO
	var second := Vector2.ZERO
	var low_h := INF
	var second_h := INF
	for p in player.points:
		var w := xform * p
		var h := w.dot(ground_normal)  # higher points have bigger h
		if h < low_h:
			second = lowest
			second_h = low_h
			lowest = w
			low_h = h
		elif h < second_h:
			second = w
			second_h = h
	return (second_h - low_h) / maxf(lowest.distance_to(second), 0.001) > FACE_TILT

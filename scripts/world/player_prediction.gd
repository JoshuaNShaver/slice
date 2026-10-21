class_name PlayerPrediction
extends RefCounted
## Your own shape, moved on your machine the moment you press a key (design
## log 0161). Online clients only; the server still decides everything.
##
## Your shape runs the same rolling and jumping (PlayerMotion.integrate) on
## your machine as on the server. Each input goes up stamped with this
## machine's physics clock, so the server can say which moment of yours each
## update matches (net_state's client time). That update is compared with
## where your shape was at that moment here, and the difference is pulled
## out a little at a time; a big one (a teleport, a respawn) jumps straight
## to the server.
##
## Abilities are predicted too (Spike Up throws enemies only on the
## server). While the server alone moves you (rides, teleports, being
## thrown, dead), you `follow`: the shape is drawn from the server's
## updates (NetSmoother), as other shapes are.

const KEEP := 1.0  # seconds of your own steps kept to compare with
const SNAP := 160.0  # px off: jump to the server's state
const PULL := 0.25  # share of a position or turn error the body takes per update
## Errors this small are left alone: they're timing noise, and chasing them
## drags the shape back after every key.
const DEADBAND := 3.0  # px
const TURN_DEADBAND := 0.05  # rad
const VEL_DEADBAND := 25.0  # px/s
const SETTLE := 0.1  # seconds: how fast the drawing catches up a correction
const VEL_PULL := 0.25  # share of a velocity error taken per update
## Off by this much (a hit, a rush the server refused), take the server's
## velocity or spin outright. Rolling over corners alone changes them by
## less, so timing noise doesn't set it off.
const VEL_SNAP := 600.0  # px/s
const SPIN_SNAP := 20.0  # rad/s
const STATS_WINDOW := 10.0  # seconds stats() looks back over
## net_state's extras for players, after NetSmoother's seven numbers.
const CLIENT_TIME := 7  # the moment of yours this state matches, or -1
const DRIVEN := 8  # 1 while the server alone moves you

## \predict on/off (log 0165): off, your shape follows the server's updates
## as other shapes do. For this game, not one shape.
static var enabled := false

var following := false
var player: PlayerShape
var _query := PhysicsShapeQueryParameters2D.new()
var _query_shape := ConvexPolygonShape2D.new()

## This machine's physics clock: seconds of physics steps your shape has
## taken. Inputs are stamped with it.
var clock := 0.0
var _times := PackedFloat64Array()  # clock at each recorded step
var _poses: Array[Vector3] = []  # x, y, rotation after the step
var _vels: Array[Vector3] = []  # vx, vy, spin
var _latest := PackedFloat32Array()
var _fix := Vector3.ZERO  # pose change to make next step
var _shown := Vector3.ZERO  # drawn pose minus the body's, fading out
# The body's transform at the last two physics ticks, to draw between them:
# ticks don't line up with frames, and drawn raw the shape stutters.
var _prev := Transform2D.IDENTITY
var _curr := Transform2D.IDENTITY
var _ticked := false
var _applied := Vector3.ZERO  # corrections made since the last tick
var _fix_vel := Vector3.ZERO
var _snap := PackedFloat32Array()  # a server state to jump to next step
var _errors: Array[Vector2] = []  # [time, px off] per compared update, for stats()
var _snaps: Array[float] = []  # when each snap happened



## Server only: the extras a player's net_state carries.
static func extras(client_time: float, driven: bool) -> PackedFloat32Array:
	var t := fmod(client_time, NetSmoother.CLOCK_WRAP) if client_time >= 0.0 else -1.0
	return PackedFloat32Array([t, 1.0 if driven else 0.0])


## True while the server alone moves you, by its latest update.
func server_driven() -> bool:
	return _latest.size() > DRIVEN and _latest[DRIVEN] > 0.5


## The server's latest state, for taking over its velocity.
func latest() -> PackedFloat32Array:
	return _latest


## Forgets your recorded steps (after following, or a jump to the server).
func reset() -> void:
	_times.clear()
	_poses.clear()
	_vels.clear()
	_fix = Vector3.ZERO
	_fix_vel = Vector3.ZERO
	_snap = PackedFloat32Array()
	_shown = Vector3.ZERO
	_ticked = false
	_applied = Vector3.ZERO


## Each physics tick, before the step: the body's transform after the last
## one. A correction made since moves the tick before along with it, so
## drawing between them doesn't show it (the fade does).
func tick(xform: Transform2D) -> void:
	if _ticked:
		_prev = Transform2D(_curr.get_rotation() + _applied.z, _curr.origin + Vector2(_applied.x, _applied.y))
	else:
		_prev = xform
	_curr = xform
	_applied = Vector3.ZERO
	_ticked = true


## Each frame: the drawing catches up with the body.
func fade(delta: float) -> void:
	_shown *= exp(-delta / SETTLE)


## Where to draw your shape, relative to the body: x, y, rotation. Between
## the last two ticks by how far this frame is into the next, plus any
## correction still fading.
func drawn_offset() -> Vector3:
	if not _ticked:
		return _shown
	var f := Engine.get_physics_interpolation_fraction()
	var at := _prev.origin.lerp(_curr.origin, f)
	var turn := angle_difference(_curr.get_rotation(), lerp_angle(_prev.get_rotation(), _curr.get_rotation(), f))
	return Vector3(at.x - _curr.origin.x, at.y - _curr.origin.y, turn) + _shown


## Each server update of your shape.
func push(state: PackedFloat32Array) -> void:
	if state.size() <= DRIVEN:
		return
	_latest = state
	if following or server_driven() or _times.is_empty() or state[CLIENT_TIME] < 0.0:
		return
	var c := float(state[CLIENT_TIME])
	c += roundf((clock - c) / NetSmoother.CLOCK_WRAP) * NetSmoother.CLOCK_WRAP
	if c < _times[0]:
		return  # from before these records
	var i := _times.bsearch(c)  # first step at or after c
	var pose: Vector3
	var vel: Vector3
	if i >= _times.size():
		pose = _poses[-1]
		vel = _vels[-1]
	elif i == 0 or _times[i] - _times[i - 1] <= 0.0:
		pose = _poses[i]
		vel = _vels[i]
	else:
		var k := inverse_lerp(_times[i - 1], _times[i], c)
		pose = Vector3(lerpf(_poses[i - 1].x, _poses[i].x, k), lerpf(_poses[i - 1].y, _poses[i].y, k),
				lerp_angle(_poses[i - 1].z, _poses[i].z, k))
		vel = _vels[i - 1].lerp(_vels[i], k)
	var off := Vector2(state[0] - pose.x, state[1] - pose.y)
	_note_error(off.length())
	if off.length() > SNAP:
		_snap = state
		_snaps.append(_now())
		return
	var turn := angle_difference(pose.z, state[2])
	if off.length() > DEADBAND:
		_fix += Vector3(off.x, off.y, 0.0) * PULL
	if absf(turn) > TURN_DEADBAND:
		_fix.z += turn * PULL
	var off_vel := Vector2(state[3] - vel.x, state[4] - vel.y)
	if off_vel.length() > VEL_DEADBAND:
		var take := 1.0 if off_vel.length() > VEL_SNAP else VEL_PULL
		_fix_vel.x += off_vel.x * take
		_fix_vel.y += off_vel.y * take
	var off_spin := state[5] - vel.z
	if absf(off_spin) > TURN_DEADBAND * 20.0:
		_fix_vel.z += off_spin * (1.0 if absf(off_spin) > SPIN_SNAP else VEL_PULL)


## Before each physics step: makes the corrections the updates asked for.
## Your recorded steps move with them, so the next update isn't counted
## twice.
func correct(state: PhysicsDirectBodyState2D) -> void:
	if not _snap.is_empty():
		_shown = Vector3.ZERO
		_ticked = false
		state.transform = Transform2D(_snap[2], Vector2(_snap[0], _snap[1]))
		state.linear_velocity = Vector2(_snap[3], _snap[4])
		state.angular_velocity = _snap[5]
		reset()
		return
	if _fix != Vector3.ZERO:
		# Moved only as far as it fits: pushed into the ground, the body would
		# pop back out. Turned only in the air: on the ground, which corner
		# is down follows from rolling (the spin is still corrected).
		var moved := _fits(state, Vector2(_fix.x, _fix.y))
		var turn := _fix.z if state.get_contact_count() == 0 else 0.0
		var applied := Vector3(moved.x, moved.y, turn)
		state.transform = Transform2D(state.transform.get_rotation() + turn, state.transform.origin + moved)
		for j in _poses.size():
			_poses[j] += applied
		_shown -= applied  # the drawing stays put, then catches up (fade)
		_applied += applied
		_fix = Vector3.ZERO
	if _fix_vel != Vector3.ZERO:
		state.linear_velocity += Vector2(_fix_vel.x, _fix_vel.y)
		state.angular_velocity += _fix_vel.z
		for j in _vels.size():
			_vels[j] += _fix_vel
		_fix_vel = Vector3.ZERO


## How much of `move` the body can make before it touches what it collides
## with, judged by the drawn outline (a little inside the collision one, so
## resting on the ground doesn't count as touching).
func _fits(state: PhysicsDirectBodyState2D, move: Vector2) -> Vector2:
	if player == null or move.length_squared() < 0.0001:
		return move
	_query_shape.points = player.points
	_query.shape = _query_shape
	_query.transform = state.transform
	_query.motion = move
	_query.collision_mask = player.collision_mask
	_query.exclude = [player.get_rid()]
	var fraction := state.get_space_state().cast_motion(_query)
	return move * (fraction[0] if fraction.size() > 0 else 1.0)


## After each physics step: where your shape got to.
func record(state: PhysicsDirectBodyState2D) -> void:
	clock += state.step
	var origin := state.transform.origin
	_times.append(clock)
	_poses.append(Vector3(origin.x, origin.y, state.transform.get_rotation()))
	_vels.append(Vector3(state.linear_velocity.x, state.linear_velocity.y, state.angular_velocity))
	while _times.size() > 2 and clock - _times[0] > KEEP:
		_times.remove_at(0)
		_poses.remove_at(0)
		_vels.remove_at(0)


## How far off your shape has been from the server, over STATS_WINDOW
## (\diagnostics): {"off": average px, "off_max": px, "snaps": count}.
func stats() -> Dictionary:
	_prune()
	if _errors.is_empty():
		return {"snaps": _snaps.size()}
	var total := 0.0
	var worst := 0.0
	for e in _errors:
		total += e.y
		worst = maxf(worst, e.y)
	return {"off": total / _errors.size(), "off_max": worst, "snaps": _snaps.size()}


func _note_error(px: float) -> void:
	_errors.append(Vector2(_now(), px))
	_prune()


func _prune() -> void:
	var now := _now()
	while not _errors.is_empty() and now - _errors[0].x > STATS_WINDOW:
		_errors.pop_front()
	while not _snaps.is_empty() and now - _snaps[0] > STATS_WINDOW:
		_snaps.pop_front()


static func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0

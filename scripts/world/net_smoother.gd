class_name NetSmoother
extends RefCounted
## Client-side smoothing for a body the server simulates (design logs 0093,
## 0095). Each update from the server is [x, y, rotation, vx, vy, spin,
## server time] (see `state_of`). Server time keeps the timeline right when
## updates held up by the network land all at once.
##
## - Other players' shapes and enemies (`live` false) are drawn DELAY behind,
##   blended between the two updates around that moment.
## - Your own shape (`live` true) shows the newest update, so steering stays
##   as quick as the round trip allows.
## - When updates run late, the body keeps moving at its last velocity for up
##   to MAX_GUESS, instead of freezing.
## - When an update disagrees with what's on screen, the difference fades out
##   over about SETTLE instead of snapping.

const DELAY := 0.06  # seconds: a few server updates' worth
const MAX_GUESS := 0.1  # seconds to keep moving with no news
const SETTLE := 0.08  # seconds: how fast a correction fades (time constant)
const KEEP := 0.5  # seconds of updates to hold on to
const TELEPORT := 300.0  # px moved in one update that means a jump cut, not motion
const CLOCK_WRAP := 4096.0  # server time is sent as seconds mod this, to fit a float32
const CLOCK_DRIFT := 0.01  # how fast the clock estimate gives in to slower packets

var live := false

var _times := PackedFloat64Array()  # server time, unwrapped
var _last_sent := -INF  # newest server time seen, unwrapped; kept through snaps
var _clock := INF  # local time minus server time, on the quickest recent packets
var _poses: Array[Vector3] = []  # x, y, rotation
var _vels: Array[Vector3] = []  # vx, vy, spin
var _offset := Vector3.ZERO  # what's on screen minus where the updates say


## Server side: what to send for a body this frame.
static func state_of(body: RigidBody2D) -> PackedFloat32Array:
	return PackedFloat32Array([body.position.x, body.position.y, body.rotation,
			body.linear_velocity.x, body.linear_velocity.y, body.angular_velocity,
			fmod(_now(), CLOCK_WRAP)])


func push(state: PackedFloat32Array) -> void:
	if state.size() < 7:
		return
	var sent := float(state[6])
	if _last_sent > -INF:  # unwrap: keep server time counting up
		sent += roundf((_last_sent - sent) / CLOCK_WRAP) * CLOCK_WRAP
		if sent <= _last_sent:
			return  # out of order or repeated: already have newer
	_last_sent = sent
	var lag := _now() - sent
	_clock = lag if lag < _clock else _clock + (lag - _clock) * CLOCK_DRIFT
	var now := _server_now()
	var pose := Vector3(state[0], state[1], state[2])
	var before := Vector3.ZERO
	var had := not _poses.is_empty()
	if had:
		before = _target(now)
		# Elevators, going home and respawns move a body far at once: snap there.
		if _xy(pose).distance_to(_xy(_poses[-1])) > TELEPORT:
			_times.clear()
			_poses.clear()
			_vels.clear()
			_offset = Vector3.ZERO
			had = false
	_times.append(sent)
	_poses.append(pose)
	_vels.append(Vector3(state[3], state[4], state[5]))
	while _times.size() > 2 and now - _times[1] > KEEP:
		_times.remove_at(0)
		_poses.remove_at(0)
		_vels.remove_at(0)
	if had:
		# Keep the screen where it was; the difference fades in current().
		var after := _target(now)
		_offset += Vector3(before.x - after.x, before.y - after.y, angle_difference(after.z, before.z))


func is_empty() -> bool:
	return _poses.is_empty()


## Where to draw the body this frame: x, y, rotation.
func current(delta: float) -> Vector3:
	_offset *= exp(-delta / SETTLE)
	return _target(_server_now()) + _offset


## Roughly the server's clock right now, judged by the quickest packets.
func _server_now() -> float:
	return _now() - _clock


## Where the updates put the body at server time `now`, before any fading
## correction.
func _target(now: float) -> Vector3:
	var last := _poses.size() - 1
	if live:
		return _guess(last, now)
	var t := now - DELAY
	if t <= _times[0]:
		return _poses[0]
	if t >= _times[last]:
		return _guess(last, t)
	for i in range(last, 0, -1):
		if _times[i - 1] <= t:
			var k := inverse_lerp(_times[i - 1], _times[i], t)
			var a := _poses[i - 1]
			var b := _poses[i]
			return Vector3(lerpf(a.x, b.x, k), lerpf(a.y, b.y, k), lerp_angle(a.z, b.z, k))
	return _poses[last]


## Update i carried forward to time t at its velocity, for at most MAX_GUESS.
func _guess(i: int, t: float) -> Vector3:
	var ahead := clampf(t - _times[i], 0.0, MAX_GUESS)
	return _poses[i] + _vels[i] * ahead


static func _xy(v: Vector3) -> Vector2:
	return Vector2(v.x, v.y)


static func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0

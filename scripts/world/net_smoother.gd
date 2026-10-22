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
## - When updates run late, the body coasts on instead of freezing, for up
##   to MAX_GUESS (log 0169): its recent velocity, slowing gently (COAST), and
##   falling under gravity, stopped by terrain and sliding along it (logs
##   0154, 0158), so a landing shape isn't drawn sunk into the floor.
## - When an update disagrees with what's on screen, the difference fades out
##   over about SETTLE instead of snapping; a big one, as after a long stall,
##   over up to SETTLE_BIG.

## Seconds between the server's updates of each body (logs 0154, 0158):
## half the server's frames, so fewer TCP packets, without the bigger
## corrections that 30 a second gave.
const SEND_INTERVAL := 1.0 / 60.0
const DELAY := 0.06  # seconds: a few server updates' worth
## Seconds to keep coasting with no news (log 0169): through a Wi-Fi stall
## or a TCP resend, rather than freezing.
const MAX_GUESS := 1.5
## Seconds: how fast a coasting body's speed and spin die away (time
## constant). Barely at first, so short gaps look as before.
const COAST := 1.0
const SETTLE := 0.08  # seconds: how fast a correction fades (time constant)
const SETTLE_BIG := 0.25  # ... for a correction of BIG_OFF or more
const BIG_OFF := 150.0  # px
const AVERAGE := 0.2  # seconds of updates a coasting body's velocity is taken over
## Seconds ahead: a guess this short uses the update's own velocity and
## spin, which keep a tumbling shape's corner on the ground; it blends into
## the AVERAGE by the time it's this long ahead again (log 0178).
const OWN_VELOCITY := 0.05
const KEEP := 0.5  # seconds of updates to hold on to
const TELEPORT := 300.0  # px moved in one update that means a jump cut, not motion
const CLOCK_WRAP := 4096.0  # server time is sent as seconds mod this, to fit a float32
const TERRAIN_MASK := 1  # PlayerShape.LAYER_TERRAIN: what a guess stops at
const STATS_WINDOW := 10.0  # seconds of arrivals that stats() looks back over
## Seconds: how fast the clock estimate gives in to slower packets (time
## constant), by time, not by packet, so a stall's burst of late packets
## can't drag it back (log 0169).
const CLOCK_DRIFT := 2.0

## Clients: local time minus server time, from your own shape's updates,
## for anything drawn from the server's clock (Ocean's waves).
static var clock_offset := 0.0

var live := false
## The body being drawn, if any: guesses are stopped by what it collides with.
var body: PhysicsBody2D

var _times := PackedFloat64Array()  # server time, unwrapped
var _last_sent := -INF  # newest server time seen, unwrapped; kept through snaps
var _clock := INF  # local time minus server time, on the quickest recent packets
var _last_arrival := 0.0  # local time the last update came in
var _poses: Array[Vector3] = []  # x, y, rotation
var _vels: Array[Vector3] = []  # vx, vy, spin
var _offset := Vector3.ZERO  # what's on screen minus where the updates say
var _arrived := PackedFloat64Array()  # local time each update landed, for stats()
var _late := PackedFloat64Array()  # how much later than the quickest packets each was
var _test := PhysicsTestMotionParameters2D.new()
var _hit := PhysicsTestMotionResult2D.new()


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
	# At most a few updates' worth: the wait before a stall's burst doesn't count.
	var since := minf(_now() - _last_arrival, 0.05) if _last_arrival > 0.0 else 0.0
	_last_arrival = _now()
	_clock = lag if lag < _clock else _clock + (lag - _clock) * (1.0 - exp(-since / CLOCK_DRIFT))
	if live:
		clock_offset = _clock
	_arrived.append(_now())
	_late.append(lag - _clock)
	while _arrived.size() > 1 and _now() - _arrived[0] > STATS_WINDOW:
		_arrived.remove_at(0)
		_late.remove_at(0)
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


## How updates have been arriving over the last STATS_WINDOW (\diagnostics,
## log 0155): {"rate": per second, "gap": longest wait, "late": average and
## "late_max" most late, compared with the quickest packets}, in seconds.
func stats() -> Dictionary:
	var now := _now()
	var count := _arrived.size()
	if count < 2:
		return {}
	var gap := now - _arrived[-1]
	var late := 0.0
	for i in count:
		late += _late[i]
		if i > 0:
			gap = maxf(gap, _arrived[i] - _arrived[i - 1])
	var span := _arrived[-1] - _arrived[0]
	return {"rate": (count - 1) / maxf(span, 0.001), "gap": gap,
			"late": late / count, "late_max": Array(_late).max()}


## Seconds since the last update came in (INF before the first).
func since_update() -> float:
	return _now() - _last_arrival if _last_arrival > 0.0 else INF


## False when the newest update says the body is moved by script (an
## elevator ride: zero velocity), so it shouldn't carry on by itself.
func can_play_on() -> bool:
	return not _vels.is_empty() and _vels[-1] != Vector3.ZERO


## The newest update's recent velocity and spin (see _recent_velocity).
func recent_velocity() -> Vector3:
	return Vector3.ZERO if _vels.is_empty() else _recent_velocity(_vels.size() - 1)


## Draws from `at` (x, y, rotation) and fades into the updates from there:
## your own shape handing back after playing on through a gap (log 0173).
## Too far off (it was teleported meanwhile), it jumps instead.
func hold(at: Vector3) -> void:
	if _poses.is_empty():
		return
	var target := _target(_server_now())
	var off := Vector3(at.x - target.x, at.y - target.y, angle_difference(target.z, at.z))
	_offset = off if _xy(off).length() < TELEPORT else Vector3.ZERO


func is_empty() -> bool:
	return _poses.is_empty()


## Where to draw the body this frame: x, y, rotation.
func current(delta: float) -> Vector3:
	var settle := lerpf(SETTLE, SETTLE_BIG, clampf(_xy(_offset).length() / BIG_OFF, 0.0, 1.0))
	_offset *= exp(-delta / settle)
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


## Update i carried forward to time t, for at most MAX_GUESS: at its own
## velocity and spin at first, then its recent ones (log 0178), dying away
## over COAST, and falling under gravity.
func _guess(i: int, t: float) -> Vector3:
	if _vels[i] == Vector3.ZERO:
		return _poses[i]  # moved by script (an elevator ride), not physics: wait for news
	var ahead := clampf(t - _times[i], 0.0, MAX_GUESS)
	var coasted := COAST * (1.0 - exp(-ahead / COAST))  # distance per unit speed
	# The averaged velocity moves the center sideways while the spin turns
	# it, so a shape tipping over a corner would be drawn with that corner
	# in the ground. Between ordinary updates, use the update's own.
	var vel := _vels[i].lerp(_recent_velocity(i), smoothstep(OWN_VELOCITY, OWN_VELOCITY + AVERAGE, ahead))
	var motion := _xy(vel) * coasted
	var fall := _gravity() * (0.5 * ahead * ahead)
	var turned := _poses[i].z + vel.z * coasted
	if body != null and ahead > 0.0:
		# Along its way first, then down: in one move, the fall would meet
		# the ground and take the sideways motion with it.
		motion = _clip(_poses[i], motion)
		motion += _clip(_poses[i] + Vector3(motion.x, motion.y, 0.0), fall)
	else:
		motion += fall
	return Vector3(_poses[i].x + motion.x, _poses[i].y + motion.y, turned)


## Velocity and spin at update i, averaged over the AVERAGE before it from
## where the body went: a tumbling shape's speed at any one moment swings
## (down into the ground as it tips over a corner, near zero at the top),
## though it rolls on steadily (log 0169). The update's own if too few.
func _recent_velocity(i: int) -> Vector3:
	var k := i
	while k > 0 and _times[i] - _times[k - 1] <= AVERAGE:
		k -= 1
	var span := _times[i] - _times[k]
	if span < AVERAGE / 2.0:
		return _vels[i]
	var a := _poses[k]
	var b := _poses[i]
	var turn := 0.0
	for j in range(k + 1, i + 1):  # summed step by step, so a full turn isn't lost
		turn += angle_difference(_poses[j - 1].z, _poses[j].z)
	return Vector3((b.x - a.x) / span, (b.y - a.y) / span, turn / span)


static func _gravity() -> Vector2:
	return ProjectSettings.get_setting("physics/2d/default_gravity_vector", Vector2.DOWN) \
			* float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))


## How far the body can move by `motion` from `pose` before it hits
## terrain, sliding along what it hits. Only terrain: other bodies are drawn
## at other moments (enemies DELAY behind), so they'd block in the wrong
## place. The push out of a slight overlap isn't counted, so it can't pop.
func _clip(pose: Vector3, motion: Vector2) -> Vector2:
	if not body.is_inside_tree():
		return motion
	var rid := body.get_rid()
	PhysicsServer2D.body_set_collision_mask(rid, TERRAIN_MASK)
	var done := Vector2.ZERO
	for _slide in 2:
		if motion.length_squared() < 0.01:
			break
		_test.from = Transform2D(pose.z, _xy(pose) + done)
		_test.motion = motion
		if not PhysicsServer2D.body_test_motion(rid, _test, _hit):
			done += motion
			break
		var safe := _hit.get_collision_safe_fraction()
		done += motion * safe
		motion = (motion * (1.0 - safe)).slide(_hit.get_collision_normal())
	PhysicsServer2D.body_set_collision_mask(rid, body.collision_mask)
	return done


static func _xy(v: Vector3) -> Vector2:
	return Vector2(v.x, v.y)


## Seconds on this machine's clock, as the server stamps its updates.
static func now() -> float:
	return _now()


static func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0

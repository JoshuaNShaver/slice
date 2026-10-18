class_name Abilities
## Abilities (design log 0086): moves bought once from the Quartermaster for
## combatant pay. Each costs COST energy to use. Jumps are free (log 0087),
## so energy is only for these.
##
## - Rush: your sideways speed and spin, times RUSH_MULT.
## - Nose dive: a jump at NOSE_DIVE_JUMP times the usual speed. Coming down,
##   your sharpest corner turns to point down and you fall faster.
## - Spike up: your sharpest corner flips up with a face flat on the ground,
##   and nearby enemies are thrown up to fall onto it.
##
## Moves (below) does the moves for players and Revolt bosses (design log
## 0089); this is the data. *Proposed* numbers.

const COST := 50.0

## In shop order. `action`: its Controls input action.
const ALL := {
	"rush": {
		"name": "Rush", "action": "rush", "price": 40,
		"text": "Your speed and spin, times five. Works in the air.",
	},
	"nose_dive": {
		"name": "Nose dive", "action": "nose_dive", "price": 60,
		"text": "Leap high, over enemies. Coming down, your sharpest corner points down and you fall faster.",
	},
	"spike_up": {
		"name": "Spike up", "action": "spike_up", "price": 80,
		"text": "Plant a face on the ground, sharpest corner up. Nearby enemies are thrown up onto it.",
	},
}

# Rush
const RUSH_MULT := 5.0
const RUSH_MIN_SPEED := 140.0  # px/s: a rush from standing starts from this
const RUSH_MAX_SPEED := 1600.0
const RUSH_MAX_SPIN := 40.0  # rad/s
const RUSH_TIME := 0.6  # s a rush counts as a move under way

# Nose dive
# Times PlayerShape.JUMP_SPEED. 3.5 rises ~140 px, over 3 triangle heights
# (42 px), to clear enemies (log 0090).
const NOSE_DIVE_JUMP := 3.5
const DIVE_GRAVITY := 2.0  # times gravity, coming down
const DIVE_STEER := 20.0  # turn rate (rad/s) per radian off target
const DIVE_TURN_ACCEL := 250.0  # rad/s²
const DIVE_MIN_TIME := 0.24  # s before touching ground ends the dive (lift-off)
const DIVE_LANDING_KEEP := 0.2  # share of sideways speed kept on landing

# Spike up
const SPIKE_RANGE := 260.0  # px: enemies this close are thrown
const SPIKE_HEIGHT := 140.0  # ... and no more than this far above or below
const SPIKE_LAUNCH := 420.0  # px/s straight up
const SPIKE_HOLD := 1.0  # s you hold the spike unless you roll or jump
const SPIKE_STEER := 25.0  # turn rate (rad/s) per radian off target
const SPIKE_MAX_SPIN := 30.0


static func is_ability(id: String) -> bool:
	return ALL.has(id)


static func ability_name(id: String) -> String:
	return ALL[id].name if ALL.has(id) else id


static func price(id: String) -> int:
	return ALL[id].price if ALL.has(id) else 0


## The index of the sharpest corner of an outline (smallest interior angle).
## Ties (within a degree) go to the corner pointing most toward `prefer`,
## given the outline's current `xform`.
static func sharpest_corner(corners: PackedVector2Array, angles: PackedFloat32Array,
		xform: Transform2D, prefer: Vector2) -> int:
	var best := -1
	var best_angle := INF
	var best_lean := -INF
	for i in corners.size():
		var lean := xform.basis_xform(corners[i]).normalized().dot(prefer)
		if angles[i] < best_angle - 1.0 or (absf(angles[i] - best_angle) <= 1.0 and lean > best_lean):
			best = i
			best_angle = minf(angles[i], best_angle)
			best_lean = lean
	return best


## Spike up's pose: the rotation that puts a face flat on the ground with the
## sharpest corner as high as it goes. Among equals, the nearest to `now`.
static func spike_rotation_for(corners: PackedVector2Array, angles: PackedFloat32Array, now: float) -> float:
	var tip := sharpest_corner(corners, angles, Transform2D(now, Vector2.ZERO), Vector2.UP)
	var area := 0.0
	for i in corners.size():
		area += corners[i].cross(corners[(i + 1) % corners.size()])
	var best := now
	var best_height := -INF
	var best_turn := INF
	for i in corners.size():
		var edge := corners[(i + 1) % corners.size()] - corners[i]
		# The face's outward normal, whichever way the outline winds.
		var out := Vector2(edge.y, -edge.x) if area > 0.0 else Vector2(-edge.y, edge.x)
		var rot := Vector2.DOWN.angle() - out.angle()  # turns that face to the floor
		var height := -Vector2(corners[tip] - corners[i]).rotated(rot).y
		var turn := absf(wrapf(rot - now, -PI, PI))
		if height > best_height + 0.5 or (absf(height - best_height) <= 0.5 and turn < best_turn):
			best = rot
			best_height = height
			best_turn = turn
	return best


## One body's moves in progress: a player's (bought, design log 0086) or a
## Revolt boss's (periodic, design log 0089). The body calls the move, then
## step() every physics step to steer it. Server only.
class Moves:
	extends RefCounted

	var diving := false  # in a nose dive
	var dive_time := 0.0
	var dive_corner := -1  # the corner turning to point down
	var spike_time := 0.0  # s left holding spike up
	var spike_rotation := 0.0
	var rush_time := 0.0  # s left of a rush's charge

	## In the middle of a move (bosses hit harder then).
	func active() -> bool:
		return diving or spike_time > 0.0 or rush_time > 0.0

	func cancel() -> void:
		diving = false
		spike_time = 0.0
		rush_time = 0.0

	## Sideways speed and spin, times RUSH_MULT, toward `dir` (-1 or 1).
	## Rolling right is clockwise, which is positive.
	func rush(state: PhysicsDirectBodyState2D, dir: float, radius: float) -> void:
		var v := state.linear_velocity
		var speed := absf(v.x) if signf(v.x) == dir else 0.0
		v.x = dir * minf(maxf(speed, RUSH_MIN_SPEED) * RUSH_MULT, RUSH_MAX_SPEED)
		state.linear_velocity = v
		var spin := absf(state.angular_velocity) if signf(state.angular_velocity) == dir else 0.0
		spin = maxf(spin, RUSH_MIN_SPEED / radius) * RUSH_MULT
		state.angular_velocity = dir * minf(spin, RUSH_MAX_SPIN)
		spike_time = 0.0
		rush_time = RUSH_TIME

	## A jump at `speed`, away from the ground, plus `push_x` sideways.
	func nose_dive(state: PhysicsDirectBodyState2D, ground_normal: Vector2, speed: float, push_x := 0.0) -> void:
		var dir := (Vector2.UP + ground_normal).normalized()
		var v := state.linear_velocity
		v += dir * (speed - v.dot(dir))
		v.x += push_x
		state.linear_velocity = v
		diving = true
		dive_time = 0.0
		dive_corner = -1
		spike_time = 0.0

	## Plants a face, sharpest corner up, and throws every one of `targets`
	## within reach (SPIKE_RANGE past the body's own size) up to land on it.
	## Targets need launch(velocity, onto).
	func spike_up(body: Node2D, state: PhysicsDirectBodyState2D, corners: PackedVector2Array,
			angles: PackedFloat32Array, radius: float, targets: Array) -> void:
		spike_rotation = Abilities.spike_rotation_for(corners, angles, state.transform.get_rotation())
		spike_time = SPIKE_HOLD
		diving = false
		var reach := SPIKE_RANGE + radius - 28.0
		var flight := 2.0 * SPIKE_LAUNCH / maxf(state.total_gravity.y, 1.0)
		for node: Variant in targets:
			var t := node as Node2D
			if t == null or t == body:
				continue
			var d := t.global_position - body.global_position
			if absf(d.x) <= reach and absf(d.y) <= SPIKE_HEIGHT + radius - 28.0:
				t.call("launch", Vector2(-d.x / flight, -SPIKE_LAUNCH), body)

	## Steers whatever move is under way. Call every physics step, after
	## your own movement, so the move wins.
	func step(state: PhysicsDirectBodyState2D, corners: PackedVector2Array, angles: PackedFloat32Array,
			touching_ground: bool) -> void:
		rush_time -= state.step
		_steer_dive(state, corners, angles, touching_ground)
		_hold_spike(state)

	# Coming down from a nose dive: the sharpest corner turns to point down, and
	# gravity pulls harder, as if the nose were heavy. Ends on landing.
	func _steer_dive(state: PhysicsDirectBodyState2D, corners: PackedVector2Array, angles: PackedFloat32Array,
			touching_ground: bool) -> void:
		if not diving:
			return
		dive_time += state.step
		if touching_ground and dive_time > DIVE_MIN_TIME:
			diving = false
			state.linear_velocity.x *= DIVE_LANDING_KEEP  # a stomp, not a slide
			return
		if state.linear_velocity.y <= 0.0:
			return  # still going up
		if dive_corner < 0:
			dive_corner = Abilities.sharpest_corner(corners, angles, state.transform, Vector2.DOWN)
		var pointing := state.transform.basis_xform(corners[dive_corner]).angle()
		var off := wrapf(Vector2.DOWN.angle() - pointing, -PI, PI)
		state.angular_velocity = move_toward(state.angular_velocity, off * DIVE_STEER, DIVE_TURN_ACCEL * state.step)
		state.linear_velocity += state.total_gravity * (DIVE_GRAVITY - 1.0) * state.step

	# Holds spike up's pose for SPIKE_HOLD, pressed flat to the ground.
	func _hold_spike(state: PhysicsDirectBodyState2D) -> void:
		if spike_time <= 0.0:
			return
		spike_time -= state.step
		var off := wrapf(spike_rotation - state.transform.get_rotation(), -PI, PI)
		state.angular_velocity = clampf(off * SPIKE_STEER, -SPIKE_MAX_SPIN, SPIKE_MAX_SPIN)
		var v := state.linear_velocity
		v.x = move_toward(v.x, 0.0, 2000.0 * state.step)
		v.y = maxf(v.y, 0.0)
		state.linear_velocity = v

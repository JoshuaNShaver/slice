class_name NoseDiveAbility
extends Ability
## Nose dive (design logs 0086, 0090): a jump at JUMP times the usual speed.
## Coming down, your sharpest corner turns to point down and you fall
## faster, as if the nose were heavy. Ends on landing. *Proposed* numbers.

# Times PlayerMotion.JUMP_SPEED. 3.5 rises ~140 px, over 3 triangle heights
# (42 px), to clear enemies (log 0090).
const JUMP := 3.5
const GRAVITY := 2.0  # times gravity, coming down
const STEER := 20.0  # turn rate (rad/s) per radian off target
const TURN_ACCEL := 250.0  # rad/s²
const MIN_TIME := 0.24  # s before touching ground ends the dive (lift-off)
const LANDING_KEEP := 0.2  # share of sideways speed kept on landing

var _diving := false
var _time := 0.0
var _corner := -1  # the corner turning to point down


func _init() -> void:
	id = "nose_dive"
	name = "Nose dive"
	action = "nose_dive"
	price = 1000  # chits (design log 0206)
	text = "Leap high, over enemies. Coming down, your sharpest corner points down and you fall faster."


func use_by_player(player: PlayerShape, state: PhysicsDirectBodyState2D) -> void:
	start(state, player.motion.ground_normal, PlayerMotion.JUMP_SPEED * JUMP)
	player.motion.left_ground()


## A jump at `speed`, away from the ground, plus `push_x` sideways.
func start(state: PhysicsDirectBodyState2D, ground_normal: Vector2, speed: float, push_x := 0.0) -> void:
	var dir := (Vector2.UP + ground_normal).normalized()
	var v := state.linear_velocity
	v += dir * (speed - v.dot(dir))
	v.x += push_x
	state.linear_velocity = v
	_diving = true
	_time = 0.0
	_corner = -1
	_began()


func step(state: PhysicsDirectBodyState2D, corners: PackedVector2Array, angles: PackedFloat32Array,
		touching_ground: bool) -> void:
	if not _diving:
		return
	_time += state.step
	if touching_ground and _time > MIN_TIME:
		_diving = false
		state.linear_velocity.x *= LANDING_KEEP  # a stomp, not a slide
		return
	if state.linear_velocity.y <= 0.0:
		return  # still going up
	if _corner < 0:
		_corner = Abilities.sharpest_corner(corners, angles, state.transform, Vector2.DOWN)
	var pointing := state.transform.basis_xform(corners[_corner]).angle()
	var off := wrapf(Vector2.DOWN.angle() - pointing, -PI, PI)
	state.angular_velocity = move_toward(state.angular_velocity, off * STEER, TURN_ACCEL * state.step)
	state.linear_velocity += state.total_gravity * (GRAVITY - 1.0) * state.step


func active() -> bool:
	return _diving


func cancel() -> void:
	_diving = false


## Planting a spike up ends the dive.
func on_other_start(other: Ability) -> void:
	if other is SpikeUpAbility:
		_diving = false

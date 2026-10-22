class_name RushAbility
extends Ability
## Rush (design log 0086): your sideways speed and spin, times MULT. Works in
## the air. *Proposed* numbers.

const MULT := 5.0
const MIN_SPEED := 140.0  # px/s: a rush from standing starts from this
const MAX_SPEED := 1600.0
const MAX_SPIN := 40.0  # rad/s
const TIME := 0.6  # s a rush counts as a move under way

var _time := 0.0  # s left of the charge


func _init() -> void:
	id = "rush"
	name = "Rush"
	action = "rush"
	price = 2500  # chits (design log 0206)
	text = "Your speed and spin, times five. Works in the air."


func works_in_air() -> bool:
	return true


## Where you're rolling, else where you're moving.
func use_by_player(player: PlayerShape, state: PhysicsDirectBodyState2D) -> void:
	var dir := signf(player.motion.move)
	if dir == 0.0:
		var v := state.linear_velocity
		dir = signf(v.x) if absf(v.x) > 20.0 else signf(state.angular_velocity)
	start(state, dir if dir != 0.0 else 1.0, PlayerShape.RADIUS)


## Sideways speed and spin, times MULT, toward `dir` (-1 or 1).
## Rolling right is clockwise, which is positive.
func start(state: PhysicsDirectBodyState2D, dir: float, radius: float) -> void:
	var v := state.linear_velocity
	var speed := absf(v.x) if signf(v.x) == dir else 0.0
	v.x = dir * minf(maxf(speed, MIN_SPEED) * MULT, MAX_SPEED)
	state.linear_velocity = v
	var spin := absf(state.angular_velocity) if signf(state.angular_velocity) == dir else 0.0
	spin = maxf(spin, MIN_SPEED / radius) * MULT
	state.angular_velocity = dir * minf(spin, MAX_SPIN)
	_began()
	_time = TIME


func step(state: PhysicsDirectBodyState2D, _corners: PackedVector2Array, _angles: PackedFloat32Array,
		_touching_ground: bool) -> void:
	_time -= state.step


func active() -> bool:
	return _time > 0.0


func cancel() -> void:
	_time = 0.0

class_name DoubleJumpAbility
extends Ability
## Double jump (design log 0244): a second jump in mid-air, once until you
## land. Free. In the Side slot, in place of rush. *Proposed* numbers.

const JUMP := 0.9  # times PlayerMotion.JUMP_SPEED

var _spent := false


func _init() -> void:
	id = "double_jump"
	name = "Double jump"
	slot = Abilities.SIDE
	short = "Jump 2"
	shop = "ranger"
	currency = "coins"
	price = 400  # *proposed*
	cost = 0.0
	text = "A second jump in mid-air, once before you land. Free."


func works_in_air() -> bool:
	return true


func usable_by(player: PlayerShape) -> bool:
	return not _spent and not player.motion.touching_ground and not player.motion.grounded


func use_by_player(player: PlayerShape, state: PhysicsDirectBodyState2D) -> void:
	# A fresh jump, whether you were still rising or already falling.
	state.linear_velocity.y = minf(state.linear_velocity.y, -PlayerMotion.JUMP_SPEED * JUMP)
	player.motion.left_ground()
	_spent = true
	_began()


func step(_state: PhysicsDirectBodyState2D, _corners: PackedVector2Array, _angles: PackedFloat32Array,
		touching_ground: bool) -> void:
	if touching_ground:
		_spent = false


func cancel() -> void:
	_spent = false

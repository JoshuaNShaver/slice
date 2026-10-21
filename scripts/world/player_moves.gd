class_name PlayerMoves
extends Node
## A player's abilities in use (PlayerShape's "Moves", design log 0086).
## Server only, but for the owner's RPC, and your own predicted shape online
## (log 0161). Which abilities you know is
## PlayerStats.abilities; each ability's script does the move (MoveSet).

var player: PlayerShape
var _queued := ""  # pressed, waiting for the ground (like a buffered jump)
var _timer := 0.0
var _moves := MoveSet.new()


## Owner -> server: use an ability you know (design log 0086). Held briefly,
## like a jump, so pressing it just before landing still works.
@rpc("any_peer", "call_local", "reliable")
func _submit_ability(id: String) -> void:
	if player.from_owner():
		press(id)


## An ability's key pressed: on the server, and on your own predicted shape
## (log 0161).
func press(id: String) -> void:
	if id in player.stats.abilities and not player.dead and not player.motion.riding():
		_queued = id
		_timer = PlayerMotion.JUMP_BUFFER


## Server only. Ends any move under way.
func cancel() -> void:
	_moves.cancel()


## Server only. Forgets a pressed ability (thrown, you can't use one).
func drop_queued() -> void:
	_timer = 0.0


## Server only. A jump lets go of a held move (spike up).
func on_jump() -> void:
	_moves.on_jump()


## Every physics step after movement (the server, and your own predicted
## shape): uses a queued ability if it can go, then steers the move under
## way.
func tick(state: PhysicsDirectBodyState2D) -> void:
	if _timer > 0.0:
		_timer -= state.step
		if _try_ability(state, player.motion.grounded):
			_timer = 0.0
	_moves.step(state, player.corners, player.corner_angles, player.motion.touching_ground)


## Uses the queued ability if it can go now. True when it's done with (used,
## or dropped for want of energy); false to keep waiting for the ground.
func _try_ability(state: PhysicsDirectBodyState2D, grounded: bool) -> bool:
	var ability := _moves.get_ability(_queued)
	if ability == null or player.stats.energy < ability.cost:
		return true
	if not grounded and not ability.works_in_air():
		return false
	ability.use_by_player(player, state)
	player.stats.energy -= ability.cost
	return true

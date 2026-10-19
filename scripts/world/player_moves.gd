class_name PlayerMoves
extends Node
## A player's abilities in use (PlayerShape's "Moves", design log 0086).
## Server only, but for the owner's RPC. Which abilities you know is
## PlayerStats.abilities; Abilities.Moves does the moves.

var player: PlayerShape
var _queued := ""  # pressed, waiting for the ground (like a buffered jump)
var _timer := 0.0
var _moves := Abilities.Moves.new()


## Owner -> server: use an ability you know (design log 0086). Held briefly,
## like a jump, so pressing it just before landing still works.
@rpc("any_peer", "call_local", "reliable")
func _submit_ability(id: String) -> void:
	if not player.from_owner():
		return
	if id in player.stats.abilities and not player.dead and not player.motion.riding():
		_queued = id
		_timer = PlayerMotion.JUMP_BUFFER


## Server only. Ends any move under way.
func cancel() -> void:
	_moves.cancel()


## Server only. Forgets a pressed ability (thrown, you can't use one).
func drop_queued() -> void:
	_timer = 0.0


## Server only. A jump ends a held spike up.
func on_jump() -> void:
	_moves.spike_time = 0.0


## Server only, every physics step after movement: uses a queued ability if
## it can go, then steers the move under way.
func tick(state: PhysicsDirectBodyState2D) -> void:
	var motion := player.motion
	if _timer > 0.0:
		_timer -= state.step
		if _try_ability(state, motion.grounded):
			_timer = 0.0
	_moves.step(state, player.corners, player.corner_angles, motion.touching_ground)


## Uses the queued ability if it can go now. True when it's done with (used,
## or dropped for want of energy); false to keep waiting for the ground.
func _try_ability(state: PhysicsDirectBodyState2D, grounded: bool) -> bool:
	var stats := player.stats
	if stats.energy < Abilities.COST:
		return true
	match _queued:
		"rush":
			_moves.rush(state, _rush_dir(state), PlayerShape.RADIUS)
		"nose_dive":
			if not grounded:
				return false
			_moves.nose_dive(state, player.motion.ground_normal, PlayerMotion.JUMP_SPEED * Abilities.NOSE_DIVE_JUMP)
			player.motion.left_ground()
		"spike_up":
			if not grounded:
				return false
			var foes: Array = get_tree().get_nodes_in_group(Enemy.GROUP).filter(func(e: Node) -> bool:
				var enemy := e as Enemy
				# Bosses are too heavy to throw (design log 0089).
				return enemy != null and enemy.players_can_hit() and not enemy.freeze and enemy.hp > 0 \
						and not enemy.is_boss())
			_moves.spike_up(player, state, player.corners, player.corner_angles, PlayerShape.RADIUS, foes)
		_:
			return true
	stats.energy -= Abilities.COST
	return true


## Which way a rush goes: where you're rolling, else where you're moving.
func _rush_dir(state: PhysicsDirectBodyState2D) -> float:
	var dir := signf(player.motion.move)
	if dir == 0.0:
		var v := state.linear_velocity
		dir = signf(v.x) if absf(v.x) > 20.0 else signf(state.angular_velocity)
	return dir if dir != 0.0 else 1.0

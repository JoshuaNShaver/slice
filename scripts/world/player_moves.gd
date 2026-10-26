class_name PlayerMoves
extends Node
## A player's abilities in use (PlayerShape's "Moves", design log 0086).
## Server only, but for the owner's RPC. Which abilities you know is
## PlayerStats.abilities, and which are equipped to keys PlayerStats.ability_slots
## (log 0243); each ability's script does the move (MoveSet).
##
## Throwing (log 0242) is here too: worn throwing tips throw shots at the
## nearest enemy (Projectiles), THROW_EVERY apart.

const THROW_EVERY := 0.4  # s between throws (*proposed*)

var player: PlayerShape
var _queued := ""  # pressed, waiting for the ground (like a buffered jump)
var _timer := 0.0
var _moves := MoveSet.new()
var _throw_wait := 0.0  # s until you can throw again
var _released := false  # a held move's key came up before it started (a tap)
var _holding := ""  # a held move under way (volley, charged shot; log 0244)
var _let_go := false  # its key came up: it goes off this step
var _held := 0.0  # s it's been held
## Synced, for drawing: the held move and how long it's been held (s, in
## steps of CHARGE_STEP), so everyone sees the charge build and flash.
var charging := ""
var charge := 0.0
const CHARGE_STEP := 0.05


## Owner -> server: use an ability you know (design log 0086). Held briefly,
## like a jump, so pressing it just before landing still works.
@rpc("any_peer", "call_local", "reliable")
func _submit_ability(id: String) -> void:
	if player.from_owner():
		press(id)


## An ability's key pressed: on the server, and on your own shape while it
## plays on through a gap (log 0173).
func press(id: String) -> void:
	if id != "" and id in player.stats.ability_slots and id in player.stats.abilities \
			and not player.dead and not player.motion.riding() and _holding == "":
		_queued = id
		_timer = PlayerMotion.JUMP_BUFFER
		_released = false


## Owner -> server: a held move's key came up (log 0244).
@rpc("any_peer", "call_local", "reliable")
func _submit_release(id: String) -> void:
	if player.from_owner():
		release(id)


func release(id: String) -> void:
	if _holding == id:
		_let_go = true
	elif _queued == id and _timer > 0.0:
		_released = true  # let go before it started: it goes off at once


## Owner side: put an owned ability in its key slot, or empty a slot ("").
func request_equip(slot: int, id: String) -> void:
	_submit_equip.rpc_id(1, slot, id)


@rpc("any_peer", "call_local", "reliable")
func _submit_equip(slot: int, id: String) -> void:
	if not player.from_owner() or slot < 0 or slot >= Abilities.SLOT_ACTIONS.size():
		return
	if id != "" and (id not in player.stats.abilities or Abilities.slot_of(id) != slot):
		return
	var slots := player.stats.ability_slots
	slots[slot] = id
	player.stats.ability_slots = slots


## Owner -> server: throw with your tips (left click, log 0242).
@rpc("any_peer", "call_local", "reliable")
func _submit_throw() -> void:
	if player.from_owner():
		throw()


## Server only. Throws your tips' shots at the nearest enemy, if you wear
## tips and they're ready. True if it threw.
func throw() -> bool:
	if player.dead or player.motion.riding() or _throw_wait > 0.0:
		return false
	var shots := Gear.shots_of(player.inventory.equipped[Gear.SLOTS.find("points")])
	var projectiles := Projectiles.find(get_tree())
	if shots.is_empty() or projectiles == null:
		return false
	_throw_wait = THROW_EVERY
	projectiles.throw_fan(projectiles.player_shot(player), int(shots.count), float(shots.spread))
	return true


## Server only. Ends any move under way.
func cancel() -> void:
	_moves.cancel()
	_stop_holding()


## Server only. Forgets a pressed ability (thrown, you can't use one).
func drop_queued() -> void:
	_timer = 0.0


## Server only. A jump lets go of a held move (spike up).
func on_jump() -> void:
	_moves.on_jump()


## Every physics step after movement (the server, and your own shape
## playing on through a gap): uses a queued ability if it can go, then
## steers the move under way.
func tick(state: PhysicsDirectBodyState2D) -> void:
	_throw_wait -= state.step
	if _timer > 0.0:
		_timer -= state.step
		if _try_ability(state, player.motion.grounded):
			_timer = 0.0
	if _holding != "":
		_hold(state)
	_moves.step(state, player.corners, player.corner_angles, player.motion.touching_ground)


## A held move: builds until let go (or held to its limit), then goes off,
## paid for then if there's still the energy.
func _hold(state: PhysicsDirectBodyState2D) -> void:
	var ability := _moves.get_ability(_holding)
	if player.dead or player.motion.riding() or ability == null:
		_stop_holding()
		return
	_held += state.step
	if _let_go or _held >= ability.max_hold():
		if player.stats.energy >= ability.cost and ability.usable_by(player):
			ability.release_by_player(player, state, _held)
			player.stats.energy -= ability.cost
		_stop_holding()
	else:
		charge = snappedf(_held, CHARGE_STEP)  # synced only when it changes


func _stop_holding() -> void:
	_holding = ""
	_let_go = false
	_held = 0.0
	charging = ""
	charge = 0.0


## Uses the queued ability if it can go now. True when it's done with (used,
## or dropped for want of energy); false to keep waiting for the ground.
func _try_ability(state: PhysicsDirectBodyState2D, grounded: bool) -> bool:
	var ability := _moves.get_ability(_queued)
	if ability == null or player.stats.energy < ability.cost or not ability.usable_by(player):
		return true
	if not grounded and not ability.works_in_air():
		return false
	if ability.holds():
		_holding = _queued
		_let_go = _released
		_held = 0.0
		charging = _holding
		charge = 0.0
		return true
	ability.use_by_player(player, state)
	player.stats.energy -= ability.cost
	return true

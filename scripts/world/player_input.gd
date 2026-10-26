class_name PlayerInput
extends Node
## The owner's keys (PlayerShape's "Input"), sent to the server as RPCs on
## the other parts. Only runs on the machine that owns the shape. Online,
## your shape also takes them itself while it plays on through a gap in the
## server's updates (log 0173).

var player: PlayerShape
var _sent_move := 0.0  # last move value sent, so we only send changes


func _physics_process(_delta: float) -> void:
	if not player.is_local():
		return
	# The controls screen is waiting for a key, or you're typing in chat.
	if Controls.capturing or Controls.watching or Controls.typing():
		if _sent_move != 0.0:
			_send_move(0.0)
		return
	var move := Input.get_axis("roll_left", "roll_right")
	if move != _sent_move:
		_send_move(move)
	if Input.is_action_just_pressed("jump"):
		if player.playing_on:
			player.motion.press_jump()
		player.motion._submit_jump.rpc_id(1)
	if Input.is_action_just_pressed("interact"):
		# Pressed again with the chests, orders or shop open: just close it.
		var hud := get_tree().get_first_node_in_group(Hud.GROUP) as Hud
		if hud == null or not hud.close_on_interact():
			player.actions._submit_interact.rpc_id(1)
	if Input.is_action_just_pressed("pickup"):
		player.inventory._submit_pickup.rpc_id(1)
	if Input.is_action_just_pressed("drink"):
		player.inventory._submit_drink.rpc_id(1, -1)
	if Input.is_action_just_pressed("home"):
		player.motion._submit_home.rpc_id(1)
	# Each key slot uses what's equipped in it (design log 0243).
	for slot in Abilities.SLOT_ACTIONS.size():
		var id := player.stats.ability_slots[slot]
		if id != "" and Input.is_action_just_pressed(Abilities.SLOT_ACTIONS[slot]):
			if player.playing_on:
				player.moves.press(id)
			player.moves._submit_ability.rpc_id(1, id)
		if id != "" and Abilities.ALL[id].holds and Input.is_action_just_released(Abilities.SLOT_ACTIONS[slot]):
			if player.playing_on:
				player.moves.release(id)
			player.moves._submit_release.rpc_id(1, id)
	if Input.is_action_just_pressed("throw"):
		player.moves._submit_throw.rpc_id(1)
	for n in PlayerInventory.QUICK_SLOTS:
		if Input.is_action_just_pressed("quick_%d" % (n + 1)):
			player.inventory.request_use(PlayerInventory.BAG_SLOTS + n)


## Left click in the world throws (log 0242); clicks on the HUD never get
## here. Touch has its own Throw button, so taps that pose as clicks don't.
func _unhandled_input(event: InputEvent) -> void:
	if not player.is_local() or Touch.active or Controls.watching:
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT \
			and click.device != InputEvent.DEVICE_ID_EMULATION:
		player.moves._submit_throw.rpc_id(1)


func _send_move(move: float) -> void:
	_sent_move = move
	if not multiplayer.is_server():
		player.motion.move = move  # for playing on through a gap
	player.motion._submit_move.rpc_id(1, move)

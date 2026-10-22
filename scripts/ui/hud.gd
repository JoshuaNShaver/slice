class_name Hud
extends CanvasLayer
## The in-world HUD (design log 0026).
##
## - Top left: your shape, level, health and XP.
## - Bottom right: the 1-5 quick-use slots over your bag; both are bag slots
##   (design logs 0036, 0043). Drag items to move them, double-click to wear
##   or drink, right-click to drop. Hover for what it does.
## - Top center: banners (place names, controls notices).
## - Speech and thoughts (design log 0082): an NPC's line in a bubble over
##   them (say), your own news in a thought cloud beside you (think).
## - Tab: character sheet: your five gear slots (drag gear on or off, or
##   double-click to take off) and stats; its Purse page holds your chits
##   and coins (design log 0204). Esc: menu (players, leave,
##   controls). Keys are rebindable (Controls, design log 0035).
## - Your house's chests (design log 0064): opened at your house's door
##   (HouseDoor), closed by Esc or by walking away. Drag between them and
##   the bag; double-click a chest item to take it.
## - The General's orders and the Quartermaster's shop (design logs 0070,
##   0071): opened by talking to them, closed by Esc or walking away.
## - The dock's market and your booth on Merchants' Row (design log 0205):
##   opened by the Harbourmaster and the Market Clerk, refreshed from the
##   server after each trade (show_market).
## - Every panel has an ✕ in its top right corner; the use key that opened
##   the chests, orders or shop closes them again (design log 0129).
## - Top right: a countdown popup while a squad musters or heads
##   home, with a Ready button to skip the wait (design log 0081).
## - On a touch screen (Touch, design log 0122): TouchControls instead of
##   the key hints, the quick slots at the bottom center, and the bag only
##   while a panel is open. Drag a bag item onto the drop zone beside the
##   bag to drop it (design log 0131).
## - Top right: the quest you're on and its goals (design
##   log 0179, PlayerQuests.tracker).
## - Chat (ChatBox, design log 0124): Enter, or Chat on a touch screen.
##   What players nearby say also shows in a bubble over them.
## Energy is drawn by PlayerShape, as pips over your own shape.

signal leave_requested

const GROUP := "hud"  # PlayerShape finds the HUD to show the priest's words

const MARGIN := 24
const BAG_COLUMNS := 5
const STAT_ROWS: Array[String] = ["vigor", "mettle", "force", "torque", "rigidity", "luck"]
const MESSAGE_TIME := 3.5  # s
const SPEAKER_RANGE := 1200.0  # px; farther speakers are heard as thoughts
const CLOSE_SIZE := 32  # px; each panel's ✕ button
const DIAG_EVERY := 0.25  # s between rewrites of \diag live's panel
const WAKE_FIRST := 1.0  # s after a cutscene before its first wake line
const WAKE_EVERY := 4.0  # s between wake lines

var _root: Control
var _portrait: ShapeIcon
var _level_label: Label
var _health_bar: StatBar
var _xp_bar: StatBar
var _character: Control
var _menu: Control
var _controls: Control
var _hint: Label
var _close_hint: Label
var _control_buttons: Dictionary = {}  # action -> its slot Buttons
var _capture_action := ""  # waiting for a key for this action...
var _capture_slot := 0  # ...in this slot
var _character_title: Label
var _player_list: VBoxContainer
var _stat_values: Dictionary = {}  # stat name -> its value Label
var _bag_slots: Array[ItemSlot] = []  # indexed like PlayerInventory.bag, quick slots last
var _quick_keys: Array[Label] = []
var _slots_column: VBoxContainer
var _bag_row: HBoxContainer  # the drop zone and the bag
var _drop_zone: DropZone
var _touch: TouchControls
var _chat: ChatBox
var _touch_layout := false  # the slots are placed for touch
var _gear_slots: Array[ItemSlot] = []  # indexed like Gear.SLOTS
var _chest_slots: Array[ItemSlot] = []  # indexed like PlayerInventory.chest
var _storage: Control
var _orders: Control
var _shop: Control
var _market: Control  # the dock's logs (log 0205)
var _market_body: VBoxContainer
var _booth: Control  # your booth's orders
var _booth_body: VBoxContainer
var _work_amount := 5  # logs a work order will ask for
var _market_data := {}
var _shop_pay: Label
var _ability_buttons := {}  # ability id -> its buy button in the shop
var _abilities_label: Label  # character sheet
var _character_page: Control  # equipment and stats
var _purse_page: Control
var _page_buttons: Array[Button] = []
var _chits_label: Label
var _coins_label: Label
var _me: PlayerShape
var _set_label: Label
var _message: Label
var _diag: PanelContainer  # \diag live's panel (log 0159)
var _diag_label: Label
var _diag_wait := 0.0  # s until it's rewritten
var _message_time := 0.0
var _countdown: Control
var _bubble_layer: Control
var _bubbles := {}  # target instance id -> its SpeechBubble
var _countdown_title: Label
var _countdown_time: Label
var _countdown_squad: Label
var _countdown_ready: Button
var _countdown_left := 0.0
var _underground := false  # chalk text, over the underworld's slate
var _cutscene: CutscenePlayer
var _after_cutscene: Array[Callable] = []  # lines and thoughts held back while one plays
var _tracker: PanelContainer  # the quest you're on (log 0179)
var _tracker_quest: Label
var _tracker_text: Label
var _tracker_goals: Label
var _tracker_shown: Variant = null  # the tracker last drawn
# Last values seen, to announce changes.
var _seen := {}


func _ready() -> void:
	add_to_group(GROUP)
	Controls.changed.connect(_on_controls_changed)
	Net.cutscene_started.connect(play_cutscene)
	_build()


## Dev hot reload (HotReload autoload): rebuild from the new code.
func _hot_reload() -> void:
	for child in get_children():
		child.queue_free()
	_stat_values.clear()
	_bag_slots.clear()
	_quick_keys.clear()
	_bubbles.clear()
	_ability_buttons.clear()
	_gear_slots.clear()
	_chest_slots.clear()
	_control_buttons.clear()
	_end_capture()
	_underground = false
	_build()
	refresh_players()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("chat"):
		_chat.toggle()
	elif event.is_action_pressed("character_sheet"):
		_character.visible = not _character.visible
		_menu.visible = false
		_controls.visible = false
		if _character.visible and _me != null and is_instance_valid(_me):
			_me.quests.report("open", "character")  # a quest may wait for it (log 0179)
	elif event.is_action_pressed("menu"):
		if _storage.visible or open_panel_name() != "":
			_storage.visible = false
			close_panel()
		elif _controls.visible:
			_controls.visible = false
			_menu.visible = true
		elif _character.visible:
			_character.visible = false
		else:
			_menu.visible = not _menu.visible
	else:
		return
	get_viewport().set_input_as_handled()


## While rebinding, the next key goes to the controls screen, not the game.
## Esc cancels; Backspace or Delete clears the slot.
func _input(event: InputEvent) -> void:
	if _capture_action == "":
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	match key.physical_keycode:
		KEY_ESCAPE:
			pass
		KEY_BACKSPACE, KEY_DELETE:
			Controls.bind(_capture_action, _capture_slot, KEY_NONE)
		_:
			var taken_from := Controls.bind(_capture_action, _capture_slot, key.physical_keycode)
			if taken_from != "":
				show_message("%s moved from %s." % [Controls.key_name(key.physical_keycode), taken_from])
	_end_capture()


func _start_capture(action: String, slot: int) -> void:
	_capture_action = action
	_capture_slot = slot
	Controls.capturing = true
	_on_controls_changed()


func _end_capture() -> void:
	_capture_action = ""
	# Deferred so this frame's physics doesn't act on the key just bound.
	Controls.set_deferred("capturing", false)
	_on_controls_changed()


func _on_controls_changed() -> void:
	if _hint != null:
		_hint.text = _hint_text()
	for n in _quick_keys.size():
		_quick_keys[n].text = Controls.key_name(Controls.keys("quick_%d" % (n + 1))[0])
	if _close_hint != null:
		_close_hint.text = "%s or %s to close" % [Controls.describe("character_sheet"), Controls.describe("menu")]
	for action: String in _control_buttons:
		var keys := Controls.keys(action)
		var buttons: Array = _control_buttons[action]
		for slot in buttons.size():
			var waiting := action == _capture_action and slot == _capture_slot
			(buttons[slot] as Button).text = "press a key…" if waiting else Controls.key_name(keys[slot])


func _hint_text() -> String:
	# Two short lines, so the hint stays clear of the bag at 1280 wide.
	var actions: Array[String] = [
		Controls.describe("roll_left") + " " + Controls.describe("roll_right") + " roll",
		Controls.describe("jump") + " jump",
		Controls.describe("interact") + " talk / use",
		Controls.describe("pickup") + " pick up",
		Controls.describe("drink") + " drink",
	]
	var menus: Array[String] = [
		Controls.describe("home") + " home",
		Controls.describe("character_sheet") + " character",
		Controls.describe("chat") + " chat",
		Controls.describe("menu") + " menu",
	]
	return "  ·  ".join(actions) + "\n" + "  ·  ".join(menus)


func update(me: PlayerShape) -> void:
	_me = me
	_set_underground(Regions.is_underworld(me.position))
	_layout_for_touch()
	_touch.update(me)
	_portrait.sides = me.sides
	_portrait.kind = me.kind
	_portrait.apex = me.apex
	_portrait.equipped = me.inventory.equipped
	_set_text(_level_label, "Level %d" % me.stats.level)
	_set_text(_chits_label, _money(me.stats.chits))
	_set_text(_coins_label, _money(me.stats.coins))
	_set_text(_shop_pay, "Your chits: %s" % _money(me.stats.chits))
	_update_abilities(me)
	_update_tracker(me.quests.tracker)
	_health_bar.set_values(me.stats.hp, me.stats.max_hp)
	if me.stats.level >= Stats.MAX_LEVEL:
		_xp_bar.set_values(1.0, 1.0)
	else:
		_xp_bar.set_values(me.stats.xp, Stats.xp_to_next(me.stats.level))
	for i in _bag_slots.size():
		_bag_slots[i].hint = _bag_hint(me.inventory.bag[i])
		_bag_slots[i].item = me.inventory.bag[i]
	for i in _gear_slots.size():
		_gear_slots[i].item = me.inventory.equipped[i]
	for i in _chest_slots.size():
		_chest_slots[i].item = me.inventory.chest[i]
	var full_set := Gear.set_tier(me.inventory.equipped)
	_set_text(_set_label, "Full set: none" if full_set == 0 else "Full %s set: %s" % [
			Gear.TIERS[full_set].name.to_lower(), Gear.describe_bonus(Gear.TIERS[full_set].set)])
	_announce_changes(me)
	_set_text(_character_title, "The %s family: %s" % [me.family_name, Family.describe_shape(me.sides, me.kind, me.apex)])
	_set_text(_stat_values["level"], str(me.stats.level))
	# Totals, with what gear (and a full set) adds: "36 (+15)".
	var from_gear := Gear.total_bonus(me.inventory.equipped)
	for stat: String in STAT_ROWS:
		var text := str(me.stats.get(stat))
		if from_gear.get(stat, 0) > 0:
			text += "  (+%d)" % from_gear[stat]
		_set_text(_stat_values[stat], text)


## Your house's chests (PlayerScreen asks, from the server).
func open_storage() -> void:
	_character.visible = false
	_menu.visible = false
	_controls.visible = false
	_storage.visible = true


func close_storage() -> void:
	_storage.visible = false


func storage_open() -> bool:
	return _storage != null and _storage.visible


## The General's or the Quartermaster's panel (PlayerScreen asks, from the
## server): "orders" or "shop".
func open_panel(panel: String) -> void:
	_character.visible = false
	_menu.visible = false
	_controls.visible = false
	_storage.visible = false
	_orders.visible = panel == "orders"
	_shop.visible = panel == "shop"
	_market.visible = panel == "market"
	_booth.visible = panel == "booth"


## "orders", "shop" or "" (neither is open).
func open_panel_name() -> String:
	if _orders != null and _orders.visible:
		return "orders"
	if _shop != null and _shop.visible:
		return "shop"
	if _market != null and _market.visible:
		return "market"
	if _booth != null and _booth.visible:
		return "booth"
	return ""


func close_panel() -> void:
	_orders.visible = false
	_shop.visible = false
	_market.visible = false
	_booth.visible = false


## The use key pressed again: closes the chests, orders or shop it opened.
## True if one was open, so the key isn't also sent as a use.
func close_on_interact() -> bool:
	if not storage_open() and open_panel_name() == "":
		return false
	close_storage()
	close_panel()
	return true


## Text drawn straight over the world turns to chalk underground (design
## log 0056); panels keep their parchment.
func _set_underground(on: bool) -> void:
	if on == _underground or _message == null:
		return
	_underground = on
	var ink := Palette.CHALK_LINE if on else Palette.INK
	var faded := Palette.CHALK_FADED if on else Palette.INK_FADED
	_level_label.add_theme_color_override("font_color", ink)
	_message.add_theme_color_override("font_color", ink)
	_hint.add_theme_color_override("font_color", faded)
	_chat.set_underground(on)


func show_message(text: String) -> void:
	if _message == null:
		return
	_message.text = text
	_message_time = MESSAGE_TIME


## Someone speaks to you (PlayerScreen.tell). A nearby speaker gets a bubble
## over them; a far one (the General, from the front) or no one ("") is
## heard as a thought.
func say(speaker: String, text: String) -> void:
	if cutscene_playing():
		_after_cutscene.append(say.bind(speaker, text))
		return
	if speaker == "":
		think(text)
		return
	var found := _find_speaker(speaker)
	if found.is_empty():
		think("%s: “%s”" % [speaker, text])
		return
	_bubble(found.node, false, found.offset).add_line(text)


## A line shouted by something in the world, e.g. a Revolt fighter's taunt
## before a move (design log 0091): a bubble over it, wherever it is.
func speak_from(target: Node2D, offset: Vector2, text: String) -> void:
	if is_instance_valid(target):
		_bubble(target, false, offset).add_line(text)


## Someone nearby said something in chat (PlayerChat): in the log, and in
## a bubble over them if they're in this world.
func hear(speaker_id: int, speaker: String, text: String) -> void:
	_chat.add_said(speaker, text)
	for node in get_tree().get_nodes_in_group(PlayerShape.GROUP):
		var p := node as PlayerShape
		if p.peer_id == speaker_id:
			speak_from(p, Vector2(0, -PlayerShape.RADIUS - 10), text)


## The server answered you (an admin command, or "too fast").
func chat_notice(text: String) -> void:
	_chat.add_notice(text)


## Plays a birth or wedding cutscene (Net.cutscene_started, design log 0168).
func play_cutscene(scene: Dictionary) -> void:
	_cutscene.play(scene)


func cutscene_playing() -> bool:
	return _cutscene != null and _cutscene.playing()


## The overlay closed: tell the server, then the wake lines (the Gleaner,
## log 0171; a quest's intro, log 0179), one every few seconds, then what
## waited for it. A wake line is a string (said by wake_speaker) or
## [speaker, line].
func _on_cutscene_finished(scene: Dictionary) -> void:
	Net.cutscene_done()
	var speaker := str(scene.get("wake_speaker", ""))
	var wake: Array = scene.get("wake", [])
	for i in wake.size():
		var line: Variant = wake[i]
		var by := str(line[0]) if line is Array else speaker
		var text := str(line[1]) if line is Array else str(line)
		get_tree().create_timer(WAKE_FIRST + i * WAKE_EVERY).timeout.connect(say.bind(by, text))
	var waiting := _after_cutscene.duplicate()
	_after_cutscene.clear()
	var after := WAKE_FIRST + wake.size() * WAKE_EVERY if not wake.is_empty() else WAKE_FIRST
	for i in waiting.size():
		get_tree().create_timer(after + i * 0.3).timeout.connect(waiting[i])


## Your own news, in a thought cloud beside you (after any cutscene).
func think(text: String) -> void:
	if cutscene_playing():
		_after_cutscene.append(think.bind(text))
		return
	if _me == null or not is_instance_valid(_me):
		show_message(text)
		return
	_bubble(_me, true, Vector2(0, -PlayerShape.RADIUS - 24)).add_line(text)


func _bubble(target: Node2D, thought: bool, offset: Vector2) -> SpeechBubble:
	var key := target.get_instance_id()
	# Bubbles free themselves when they fade, so the stored one may be gone.
	# Check it untyped: assigning a freed instance to a typed variable errors.
	var stored: Variant = _bubbles.get(key)
	var bubble: SpeechBubble = null
	if is_instance_valid(stored) and not (stored as SpeechBubble).is_queued_for_deletion():
		bubble = stored
	if bubble == null:
		bubble = SpeechBubble.new(target, thought, offset)
		_bubble_layer.add_child(bubble)
		_bubbles[key] = bubble
	return bubble


## {"node", "offset"} for the named NPC or elevator guard near you, or {}.
func _find_speaker(speaker: String) -> Dictionary:
	if _me == null or not is_instance_valid(_me):
		return {}
	for node in get_tree().get_nodes_in_group(Npc.GROUP):
		var npc := node as Npc
		if npc != null and npc.display_name == speaker:
			if npc.global_position.distance_to(_me.global_position) <= SPEAKER_RANGE:
				# Above the name (and the prompt, when it shows).
				return {"node": npc, "offset": Vector2(0, -npc.radius - 60)}
			return {}
		var lift := node as Elevator
		if lift != null and lift.guard_name == speaker:
			var stop: Vector2 = lift.stops[0]
			if _me.global_position.distance_to(lift.stops[1]) < _me.global_position.distance_to(stop):
				stop = lift.stops[1]
			if stop.distance_to(_me.global_position) <= SPEAKER_RANGE:
				return {"node": lift, "offset": stop - lift.global_position + Vector2(0, -110)}
			return {}
	# A soldier fighting beside you (mission hints, design log 0088): the nearest.
	var best: Enemy = null
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var soldier := node as Enemy
		if soldier == null or not soldier.is_army() or soldier.info().name != speaker:
			continue
		var d := soldier.global_position.distance_to(_me.global_position)
		if d <= SPEAKER_RANGE and (best == null or d < best.global_position.distance_to(_me.global_position)):
			best = soldier
	if best != null:
		return {"node": best, "offset": Vector2(0, -best.info().radius - 40)}
	return {}


## The server's countdown (PlayerScreen.show_countdown). An empty title hides it.
func show_countdown(title: String, seconds: float, ready_count: int, total: int, you_ready: bool,
		button := "") -> void:
	if _countdown == null:
		return
	_countdown.visible = title != ""
	_countdown_left = seconds
	_set_text(_countdown_title, title)
	_countdown_squad.visible = total > 1
	_set_text(_countdown_squad, "%d of %d ready" % [ready_count, total])
	_countdown_ready.disabled = you_ready
	_countdown_ready.text = "Waiting for the squad" if you_ready else (button if button != "" else "Ready")
	_update_countdown_time()


func _update_countdown_time() -> void:
	_set_text(_countdown_time, "%d s" % ceili(maxf(_countdown_left, 0.0)))


func _process(delta: float) -> void:
	if _message == null:
		return
	if _countdown.visible:
		_countdown_left -= delta
		_update_countdown_time()
	_message_time -= delta
	_message.modulate.a = clampf(_message_time, 0.0, 1.0)
	_update_diagnostics(delta)


## \diag live (log 0159): the panel, rewritten a few times a second.
func _update_diagnostics(delta: float) -> void:
	var on := PlayerChat.live and _me != null and is_instance_valid(_me)
	_diag.visible = on
	if not on:
		return
	_diag_wait -= delta
	if _diag_wait > 0.0:
		return
	_diag_wait = DIAG_EVERY
	_diag_label.text = Diagnostics.live_text(_me.chat.live_rtts, _me.chat.live_server, _me)


func _announce_changes(me: PlayerShape) -> void:
	# Count items carried or worn, so swapping gear doesn't count as finding it.
	var items := {}
	for item in me.inventory.bag + me.inventory.equipped:
		if item != "":
			items[item] = items.get(item, 0) + 1
	var now := {"level": me.stats.level, "items": items, "sides": me.sides, "set": Gear.set_tier(me.inventory.equipped)}
	if _seen.get("sides") == now.sides:  # not when an heir takes over
		if now.level > _seen.level:
			think("Level %d!" % now.level)
		for item: String in items:
			if items[item] > _seen.items.get(item, 0):
				think("Picked up: " + Gear.item_name(item))
		if now["set"] > 0 and now["set"] != _seen.get("set", 0):
			var tier: Dictionary = Gear.TIERS[now["set"]]
			think("Full %s set! %s" % [tier.name.to_lower(), Gear.describe_bonus(tier.set)])
	_seen = now


func refresh_players() -> void:
	if _player_list == null:
		return
	for child in _player_list.get_children():
		child.queue_free()
	for id: int in Net.players:
		var info: Dictionary = Net.players[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(ShapeIcon.new(info.sides, info.kind, 24, info.get("apex", 0)))
		var label := Label.new()
		label.text = "The %s family: %s" % [info.family, Family.describe_shape(info.sides, info.kind, info.get("apex", 0))]
		if id == multiplayer.get_unique_id():
			label.text += "  (you)"
		row.add_child(label)
		_player_list.add_child(row)


# --- Layout ---------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.build_menu()  # the main menu's look (log 0189)
	add_child(_root)

	_bubble_layer = Control.new()
	_bubble_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bubble_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bubble_layer)  # first, so panels cover it

	_root.add_child(_build_vitals())
	_root.add_child(_build_slots())
	_touch = TouchControls.new()
	_root.add_child(_touch)  # under the panels

	var hint := _faded(_hint_text())
	_hint = hint
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, MARGIN)
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(hint)

	_chat = ChatBox.new()
	_chat.line_entered.connect(func(text: String) -> void:
		if _me != null and is_instance_valid(_me):
			_me.chat.send_line(text))
	_root.add_child(_chat)  # under the panels

	_character = _build_character()
	_root.add_child(_character)
	_menu = _build_menu()
	_root.add_child(_menu)
	_controls = _build_controls()
	_root.add_child(_controls)
	_storage = _build_storage()
	_root.add_child(_storage)
	_orders = _build_orders()
	_root.add_child(_orders)
	_shop = _build_shop()
	_root.add_child(_shop)
	_market = _build_trade_panel(true)
	_root.add_child(_market)
	_booth = _build_trade_panel(false)
	_root.add_child(_booth)

	_on_controls_changed()

	_message = Label.new()
	_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, MARGIN)
	_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 22)
	_message.modulate.a = 0.0
	_root.add_child(_message)
	_root.add_child(_build_countdown())
	# Top right: the quest tracker, then \diag live.
	var right := VBoxContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, MARGIN)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_theme_constant_override("separation", 8)
	_root.add_child(right)
	right.add_child(_build_tracker())
	right.add_child(_build_diagnostics())
	_cutscene = CutscenePlayer.new()
	_cutscene.finished.connect(_on_cutscene_finished)
	_root.add_child(_cutscene)  # last: over everything


## The quest you're on (log 0179): its name, the objective, and each goal
## with how far along it is. See-through parchment, like tooltips.
func _build_tracker() -> Control:
	_tracker = PanelContainer.new()
	_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := SketchBox.make(Color(Palette.PARCHMENT_LIGHT, 0.82), Color(Palette.INK, 0.5), 10.0)
	box.line_width = 1.2
	box.shaded = false
	_tracker.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	_tracker.add_child(column)
	_tracker_quest = Label.new()
	_tracker_quest.add_theme_font_size_override("font_size", 13)
	_tracker_quest.add_theme_color_override("font_color", Palette.INK_FADED)
	column.add_child(_tracker_quest)
	_tracker_text = Label.new()
	_tracker_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tracker_text.custom_minimum_size.x = 280
	_tracker_text.add_theme_font_size_override("font_size", 16)
	_tracker_text.add_theme_color_override("font_color", Palette.INK)
	column.add_child(_tracker_text)
	_tracker_goals = Label.new()
	_tracker_goals.add_theme_font_size_override("font_size", 15)
	_tracker_goals.add_theme_color_override("font_color", Palette.INK)
	column.add_child(_tracker_goals)
	_tracker.visible = false
	return _tracker


func _update_tracker(shown: Dictionary) -> void:
	if _tracker == null or shown == _tracker_shown:
		return
	_tracker_shown = shown.duplicate(true)
	_tracker.visible = not shown.is_empty()
	if shown.is_empty():
		return
	_tracker_quest.text = str(shown.get("quest", "")).to_upper()
	_tracker_text.text = str(shown.get("text", ""))
	var lines: Array[String] = []
	for goal: Array in shown.get("goals", []):
		var label := _with_keys(str(goal[0]))
		var have := int(goal[1])
		var need := int(goal[2])
		var count := " %d/%d" % [have, need] if need > 1 else ""
		lines.append(("✓ " if have >= need else "· ") + label + count)
	_tracker_goals.text = "\n".join(lines)


## "{character_sheet}" in a quest's text becomes that control's key.
static func _with_keys(text: String) -> String:
	for entry: Dictionary in Controls.ACTIONS:
		var action := str(entry.action)
		text = text.replace("{%s}" % action, Controls.describe(action))
	return text


## Under the quest tracker: \diag live's numbers, light on dark so they
## read over any ground.
func _build_diagnostics() -> Control:
	_diag = PanelContainer.new()
	_diag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.55)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(8)
	_diag.add_theme_stylebox_override("panel", box)
	_diag_label = Label.new()
	_diag_label.add_theme_font_override("font", ChatBox.MONO)
	_diag_label.add_theme_font_size_override("font_size", 13)
	_diag_label.add_theme_color_override("font_color", Color(0.86, 0.93, 0.88))
	_diag.add_child(_diag_label)
	_diag.visible = false
	return _diag


## Top left: portrait, level, health, XP.
func _build_vitals() -> Control:
	var row := HBoxContainer.new()
	row.position = Vector2(MARGIN, MARGIN)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)

	_portrait = ShapeIcon.new(3, "regular", 56)
	row.add_child(_portrait)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	row.add_child(column)
	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 16)
	column.add_child(_level_label)
	_health_bar = StatBar.new("Health", Palette.HEALTH)
	_health_bar.custom_minimum_size.x = 260
	column.add_child(_health_bar)
	_xp_bar = StatBar.new("", Palette.XP)
	_xp_bar.compact = true
	column.add_child(_xp_bar)
	return row


## Bottom right: the quick-use slots (keys 1-5) over the bag. Both are
## slots of PlayerInventory.bag; the quick ones are its last five.
func _build_slots() -> Control:
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, MARGIN)
	column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)

	var hotbar := _slot_grid(BAG_COLUMNS)
	var bag := _slot_grid(BAG_COLUMNS)
	for i in PlayerInventory.BAG_SIZE:
		var slot := _bag_slot(i)
		_bag_slots.append(slot)
		if i < PlayerInventory.BAG_SLOTS:
			bag.add_child(slot)
			continue
		var key_label := _faded("")
		key_label.add_theme_font_size_override("font_size", 13)
		key_label.position = Vector2(5, 1)
		slot.add_child(key_label)
		_quick_keys.append(key_label)
		hotbar.add_child(slot)
	hotbar.size_flags_horizontal = Control.SIZE_SHRINK_END  # over the bag, not the drop zone
	column.add_child(hotbar)
	var bag_row := HBoxContainer.new()
	bag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bag_row.add_theme_constant_override("separation", 10)
	_drop_zone = DropZone.new()
	_drop_zone.size_flags_vertical = Control.SIZE_SHRINK_END
	_drop_zone.dropped.connect(func(i: int) -> void:
		if _me != null:
			_me.inventory.request_drop(i))
	bag_row.add_child(_drop_zone)
	bag_row.add_child(bag)
	column.add_child(bag_row)
	_slots_column = column
	_bag_row = bag_row
	_touch_layout = false
	return column


## Touch (design log 0122): Jump and the abilities take the bottom right,
## so the quick slots move to the bottom center and the bag shows only
## while a panel is open, with a drop zone beside it (no right-click;
## design log 0131).
func _layout_for_touch() -> void:
	var touch := Touch.active
	var panel := _character.visible or _menu.visible or _controls.visible \
			or _storage.visible or open_panel_name() != ""
	_touch.visible = touch
	_touch.playing = not panel and not _chat.is_open
	_chat.set_touch(touch)
	_hint.visible = not touch
	_bag_row.visible = not touch or panel
	_drop_zone.visible = touch
	var centered := touch and not panel
	if centered == _touch_layout:
		return
	_touch_layout = centered
	var preset := Control.PRESET_CENTER_BOTTOM if centered else Control.PRESET_BOTTOM_RIGHT
	_slots_column.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, MARGIN)
	_slots_column.grow_horizontal = Control.GROW_DIRECTION_BOTH if centered else Control.GROW_DIRECTION_BEGIN


## Bag slot i: drag to move, drop worn gear here to take it off.
func _bag_slot(i: int) -> ItemSlot:
	var slot := ItemSlot.new()
	slot.drag_source = {"bag": i}
	slot.accepts = func(data: Dictionary) -> bool:
		if data.has("chest"):
			return true
		if not data.has("worn") or _me == null:
			return true
		# Taking gear off: into an empty slot, or swapping with gear for the same slot.
		var here := _me.inventory.bag[i]
		return here == "" or Gear.slot_of(here) == Gear.SLOTS[data.worn]
	slot.dropped.connect(func(data: Dictionary) -> void:
		if _me == null:
			return
		if data.has("bag"):
			_me.inventory.request_swap(data.bag, i)
		elif data.has("chest"):
			_me.inventory.request_swap(PlayerInventory.CHEST_BASE + data.chest, i)
		elif data.has("worn"):
			_me.inventory.request_unequip(data.worn, i))
	slot.double_clicked.connect(func() -> void:
		if _me != null:
			_me.inventory.request_use(i))
	slot.right_clicked.connect(func() -> void:
		if _me != null:
			_me.inventory.request_drop(i))
	return slot


func _bag_hint(item: String) -> String:
	if item == Gear.POTION:
		return "Double-click or %s: drink  ·  Drag: move  ·  Right-click: drop" % Controls.describe("drink")
	if Gear.is_provision(item):
		return "Double-click: eat  ·  Drag: move  ·  Right-click: drop"
	if Gear.is_gear(item):
		return "Double-click: wear  ·  Drag: move  ·  Right-click: drop"
	return "Drag: move  ·  Right-click: drop"


## Tab: who you are, what you wear, your stats.
func _build_character() -> Control:
	var panel := _centered_panel()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	var title_row := HBoxContainer.new()
	column.add_child(title_row)
	_character_title = Label.new()
	_character_title.add_theme_font_size_override("font_size", 28)
	title_row.add_child(_character_title)
	var clear_of_close := Control.new()
	clear_of_close.custom_minimum_size.x = CLOSE_SIZE + 8
	title_row.add_child(clear_of_close)

	# Pages: the character (equipment, stats) and the purse (log 0204).
	var pages := HBoxContainer.new()
	pages.add_theme_constant_override("separation", 8)
	column.add_child(pages)
	for page_name: String in ["Character", "Purse"]:
		var button := Button.new()
		button.text = page_name
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE  # keep Space for jumping
		button.pressed.connect(_show_page.bind(page_name == "Purse"))
		_page_buttons.append(button)
		pages.add_child(button)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 32)
	column.add_child(columns)
	_character_page = columns
	_purse_page = _build_purse()
	column.add_child(_purse_page)

	var equipment := VBoxContainer.new()
	equipment.custom_minimum_size.x = 200
	equipment.add_child(_heading("Equipment"))
	for i in Gear.SLOTS.size():
		var info: Dictionary = Gear.SLOT_INFO[Gear.SLOTS[i]]
		var slot := ItemSlot.new(info.label, "Double-click or drag to the bag: take off")
		slot.drag_source = {"worn": i}
		slot.accepts = func(data: Dictionary) -> bool:
			return data.has("bag") and Gear.slot_of(data.item) == Gear.SLOTS[i]
		slot.dropped.connect(func(data: Dictionary) -> void:
			if _me != null:
				_me.inventory.request_equip(data.bag))
		slot.double_clicked.connect(func() -> void:
			if _me != null:
				_me.inventory.request_unequip(i))
		_gear_slots.append(slot)
		var row := _row("%s (+%s)" % [info.label, info.stat], slot)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		equipment.add_child(row)
	_set_label = Label.new()
	equipment.add_child(_set_label)
	equipment.add_child(_row("Trinkets", _faded("none")))
	columns.add_child(equipment)

	var stats := VBoxContainer.new()
	stats.custom_minimum_size.x = 200
	stats.add_child(_heading("Stats"))
	for stat: String in ["level"] + STAT_ROWS:
		var value := Label.new()
		_stat_values[stat] = value
		stats.add_child(_row(stat.capitalize(), value))
	_abilities_label = _faded("")
	stats.add_child(_abilities_label)
	columns.add_child(stats)

	_close_hint = _faded("")
	column.add_child(_close_hint)
	_add_close_button(panel, func() -> void: _character.visible = false)
	_show_page(false)
	return panel


## The character sheet's pages: equipment and stats, or the purse.
func _show_page(purse: bool) -> void:
	_character_page.visible = not purse
	_purse_page.visible = purse
	for i in _page_buttons.size():
		_page_buttons[i].button_pressed = (i == 1) == purse


## The purse (design log 0204): chits, the army's pay, and coins, trade money.
func _build_purse() -> Control:
	var purse := VBoxContainer.new()
	purse.add_theme_constant_override("separation", 14)
	purse.custom_minimum_size.x = 432
	_chits_label = Label.new()
	_coins_label = Label.new()
	for entry: Array in [["chits", _chits_label, "Chits: army pay. Earned on missions and by work, spent at the Quartermaster."],
			["coins", _coins_label, "Coins: trade money. Merchants buy and sell with them."]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(MoneyIcon.new(entry[0], 36))
		var label: Label = entry[1]
		label.add_theme_font_size_override("font_size", 26)
		label.custom_minimum_size.x = 120
		row.add_child(label)
		var about := _faded(entry[2])
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		about.custom_minimum_size.x = 240
		about.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(about)
		purse.add_child(row)
	return purse


## "12,500": thousands set apart, for money.
static func _money(amount: int) -> String:
	var digits := str(absi(amount))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if amount < 0 else "") + digits + out


## Your house's chests: a grid of slots that trade with the bag.
func _build_storage() -> Control:
	var panel := _centered_panel()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(_heading("Your chests"))
	column.add_child(_faded("Kept for every heir from square up, whatever the family."))
	var grid := _slot_grid(BAG_COLUMNS)
	for i in PlayerInventory.CHEST_SLOTS:
		var slot := ItemSlot.new("", "Drag to the bag, or double-click: take")
		slot.drag_source = {"chest": i}
		slot.accepts = func(data: Dictionary) -> bool:
			return data.has("bag") or data.has("chest")
		slot.dropped.connect(func(data: Dictionary) -> void:
			if _me == null:
				return
			var from: int = data.bag if data.has("bag") else PlayerInventory.CHEST_BASE + data.chest
			_me.inventory.request_swap(from, PlayerInventory.CHEST_BASE + i))
		slot.double_clicked.connect(func() -> void:
			if _me == null:
				return
			var free := _me.inventory.bag.find("")
			if free != -1:
				_me.inventory.request_swap(PlayerInventory.CHEST_BASE + i, free))
		_chest_slots.append(slot)
		grid.add_child(slot)
	column.add_child(grid)
	column.add_child(_faded("%s or %s to close" % [Controls.describe("interact"), Controls.describe("menu")]))
	_add_close_button(panel, close_storage)
	return panel


## The General's orders (design log 0070): one row per mission.
func _build_orders() -> Control:
	var panel := _centered_panel()
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 520
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	column.add_child(_heading("The General's orders"))
	column.add_child(_faded("Levels are a guide. Missions pay XP and chits, nothing else."))
	for mission_type in Mission.ORDER:
		var info: Dictionary = Mission.TYPES[mission_type]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := Label.new()
		var squad := "alone" if info.squad <= 1 else "squad of up to %d" % info.squad
		title.text = "%s · levels %s · %s · +%d chits" % [info.name, info.levels, squad, info.pay]
		text.add_child(title)
		var about := _faded(info.about)
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		about.custom_minimum_size.x = 380
		text.add_child(about)
		row.add_child(text)
		var go := Button.new()
		go.text = "Take orders"
		go.focus_mode = Control.FOCUS_NONE  # keep Space for jumping
		go.pressed.connect(func() -> void:
			if _me != null:
				_me.actions.request_mission(mission_type)
			close_panel())
		row.add_child(go)
		column.add_child(row)
	column.add_child(_faded("Bring down a Revolt boss to be discharged with a marriage certificate."))
	column.add_child(_faded("%s or %s to close" % [Controls.describe("interact"), Controls.describe("menu")]))
	_add_close_button(panel, close_panel)
	return panel


## Top right: a muster's or the trip home's countdown.
func _build_countdown() -> Control:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, MARGIN)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.visible = false
	panel.add_theme_stylebox_override("panel", _solid_panel_box())
	_countdown = panel
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 240
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	_countdown_title = Label.new()
	_countdown_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_countdown_title)
	_countdown_time = Label.new()
	_countdown_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_time.add_theme_font_size_override("font_size", 30)
	column.add_child(_countdown_time)
	_countdown_squad = _faded("")
	_countdown_squad.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_countdown_squad)
	_countdown_ready = Button.new()
	_countdown_ready.text = "Ready"
	_countdown_ready.focus_mode = Control.FOCUS_NONE  # keep Space for jumping
	_countdown_ready.pressed.connect(func() -> void:
		if _me != null:
			_countdown_ready.disabled = true
			_me.actions.request_mission_ready())
	column.add_child(_countdown_ready)
	return panel


## The Quartermaster's stock (design logs 0071, 0084): provisions, then a
## row per tier. One grid, so every row's boxes line up, right-aligned, each
## with its price underneath.
func _build_shop() -> Control:
	var panel := _centered_panel()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var header := HBoxContainer.new()
	var title := _heading("The Quartermaster")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_shop_pay = Label.new()
	header.add_child(_shop_pay)
	var clear_of_close := Control.new()
	clear_of_close.custom_minimum_size.x = CLOSE_SIZE + 8
	header.add_child(clear_of_close)
	column.add_child(header)

	var rows: Array = [["Provisions", Gear.PROVISIONS.keys()]]
	var by_tier := {}  # tier -> its items
	for item in Gear.shop_stock():
		var tier := Gear.tier_of(item)
		if not by_tier.has(tier):
			by_tier[tier] = []
			rows.append([Gear.TIERS[tier].name, by_tier[tier]])
		by_tier[tier].append(item)
	var width := 0
	for row: Array in rows:
		width = maxi(width, row[1].size())
	var grid := GridContainer.new()
	grid.columns = width + 1
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 10)
	for row: Array in rows:
		var label := Label.new()
		label.text = row[0]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		label.custom_minimum_size.x = 120
		label.custom_minimum_size.y = ItemSlot.SIZE
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		grid.add_child(label)
		for i in width - row[1].size():  # short rows pad on the left
			grid.add_child(Control.new())
		for item: String in row[1]:
			grid.add_child(_shop_cell(item))
	column.add_child(grid)

	# Abilities (design log 0086): bought once, used with their keys.
	var drills := HBoxContainer.new()
	drills.add_theme_constant_override("separation", 8)
	var drills_label := Label.new()
	drills_label.text = "Drills"
	drills_label.custom_minimum_size.x = 120
	drills.add_child(drills_label)
	for id: String in Abilities.ALL:
		var button := Button.new()
		button.tooltip_text = "%s\n%d energy a use." % [Abilities.ALL[id].text, roundi(Abilities.ALL[id].cost)]
		button.pressed.connect(func() -> void:
			if _me != null:
				_me.actions.request_learn(id))
		_ability_buttons[id] = button
		drills.add_child(button)
	column.add_child(drills)

	var note := _faded("Food heals over %d s. Leather comes from the drill yard. No pigment: colour is contraband." % roundi(Stats.MEAL_TIME))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 120 + (width + 1) * 8 + width * ItemSlot.SIZE
	column.add_child(note)
	column.add_child(_faded("%s or %s to close" % [Controls.describe("interact"), Controls.describe("menu")]))
	_add_close_button(panel, close_panel)
	return panel


## Shop buttons say what's learned; the character sheet lists it with keys.
func _update_abilities(me: PlayerShape) -> void:
	var known: Array[String] = []
	for id: String in Abilities.ALL:
		var info: Dictionary = Abilities.ALL[id]
		var learned := id in me.stats.abilities
		if learned:
			known.append("%s (%s)" % [info.name, Controls.describe(info.action)])
		var button: Button = _ability_buttons.get(id)
		if button != null:
			var text := "%s · %s" % [info.name, "learned" if learned else "%s chits" % _money(info.price)]
			if button.text != text:
				button.text = text
			button.disabled = learned
	_set_text(_abilities_label, "Abilities: " + (", ".join(known) if not known.is_empty() else "none"))


## An item box with its price centred underneath.
func _shop_cell(item: String) -> Control:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)
	cell.add_child(_shop_slot(item))
	var price := _faded(_money(Gear.price(item)))
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(price)
	return cell


func _shop_slot(item: String) -> ItemSlot:
	var slot := ItemSlot.new("", "Double-click: buy for %s chits" % _money(Gear.price(item)))
	slot.item = item
	slot.double_clicked.connect(func() -> void:
		if _me != null:
			_me.actions.request_buy(item))
	return slot


## The dock's market (`dock`) or your booth: a panel whose body
## show_market fills from the server's snapshot.
func _build_trade_panel(dock: bool) -> Control:
	var panel := _centered_panel()
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 520
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var header := HBoxContainer.new()
	var title := _heading(Market.HARBOURMASTER if dock else "Your booth on Merchants' Row")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var clear_of_close := Control.new()
	clear_of_close.custom_minimum_size.x = CLOSE_SIZE + 8
	header.add_child(clear_of_close)
	column.add_child(header)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	column.add_child(body)
	if dock:
		_market_body = body
	else:
		_booth_body = body
	column.add_child(_faded("%s or %s to close" % [Controls.describe("interact"), Controls.describe("menu")]))
	_add_close_button(panel, close_panel)
	return panel


## The server's market snapshot (PlayerScreen.show_market, Market.snapshot):
## opens the dock's market or your booth, or refreshes it.
func show_market(panel: String, data: Dictionary) -> void:
	_market_data = data
	_fill_market()
	_fill_booth()
	if open_panel_name() != panel:
		open_panel(panel)


func _fill_market() -> void:
	if _market_body == null or _market_data.is_empty():
		return
	for child in _market_body.get_children():
		child.queue_free()
	var d := _market_data
	var mood := "Short, and dear." if d.stock < Market.STOCK_START else (
			"A glut: cheap." if d.stock >= Market.STOCK_FULL else "Steady.")
	_market_body.add_child(_money_row())
	_market_body.add_child(_faded("In stock: %d logs. %s" % [d.stock, mood]))
	for with_coins: bool in [false, true]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var each: int = d.coin_price if with_coins else d.chit_price
		var label := Label.new()
		label.text = "%s %s a log" % [_money(each), "coins" if with_coins else "chits"]
		label.custom_minimum_size.x = 180
		row.add_child(label)
		for count in [1, 5, 10]:
			row.add_child(_trade_button("Buy %d" % count, "buy_coins" if with_coins else "buy_chits", count))
		_market_body.add_child(row)

	var work_left := int(d.work_left)
	if work_left > 0:
		_market_body.add_child(_faded("Your work order: %d logs still to come." % work_left))
	else:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.text = "Work order: %d logs, %s coins" % [_work_amount, _money(_work_amount * int(d.work_price))]
		label.custom_minimum_size.x = 260
		row.add_child(label)
		for step: int in [-1, 1]:
			var button := Button.new()
			button.text = "−" if step < 0 else "+"
			button.focus_mode = Control.FOCUS_NONE
			button.pressed.connect(func() -> void:
				_work_amount = clampi(_work_amount + step, 1, Market.WORK_MAX)
				_fill_market())
			row.add_child(button)
		row.add_child(_trade_button("Post", "work", _work_amount))
		_market_body.add_child(row)
	var note := _faded("Work orders cost %s coins a log, paid now; workmen's logs fill them first." % _money(int(d.work_price)))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 500
	_market_body.add_child(note)
	if int(d.held) > 0:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.text = "Waiting for you: %d logs" % int(d.held)
		label.custom_minimum_size.x = 260
		row.add_child(label)
		row.add_child(_trade_button("Collect", "collect", 0))
		_market_body.add_child(row)


func _fill_booth() -> void:
	if _booth_body == null or _market_data.is_empty():
		return
	for child in _booth_body.get_children():
		child.queue_free()
	var d := _market_data
	_booth_body.add_child(_money_row())
	var logs := _me.inventory.count_of(Gear.LOG) if _me != null and is_instance_valid(_me) else 0
	_booth_body.add_child(_faded("In your bag: %d logs. The dock sells at %s coins a log." % [logs, _money(int(d.coin_price))]))
	var orders: Array = d.orders
	if orders.is_empty():
		_booth_body.add_child(_faded("No orders yet. Buyers come by every minute or two."))
	for order: Array in orders:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var label := Label.new()
		var minutes := maxi(ceili(int(order[4]) / 60.0), 1)
		label.text = "%s · %d logs at %d coins (%s) · %d min" % [order[1], order[2], order[3],
				_money(int(order[2]) * int(order[3])), minutes]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button := _trade_button("Deliver", "deliver", int(order[0]))
		button.disabled = logs < int(order[2])
		row.add_child(button)
		_booth_body.add_child(row)


func _money_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var chits := _me.stats.chits if _me != null and is_instance_valid(_me) else 0
	var coins := _me.stats.coins if _me != null and is_instance_valid(_me) else 0
	for entry: Array in [["chits", chits], ["coins", coins]]:
		row.add_child(MoneyIcon.new(entry[0], 22))
		var label := Label.new()
		label.text = _money(entry[1])
		label.custom_minimum_size.x = 90
		row.add_child(label)
	return row


func _trade_button(text: String, action: String, amount: int) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE  # keep Space for jumping
	button.pressed.connect(func() -> void:
		if _me != null and is_instance_valid(_me):
			_me.actions.request_market(action, amount))
	return button


## Esc: who's here, and the way out.
func _build_menu() -> Control:
	var panel := _centered_panel()
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 360
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	column.add_child(_heading("Menu"))
	column.add_child(_faded(Net.describe_session()))
	_player_list = VBoxContainer.new()
	column.add_child(_player_list)
	column.add_child(_graphics_settings())

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 8)
	column.add_child(buttons)
	var back := Button.new()
	back.text = "Back"
	back.focus_mode = Control.FOCUS_NONE  # keep Space for jumping
	back.pressed.connect(func() -> void: _menu.visible = false)
	buttons.add_child(back)
	var controls := Button.new()
	controls.text = "Controls"
	controls.focus_mode = Control.FOCUS_NONE
	controls.pressed.connect(func() -> void:
		_menu.visible = false
		_controls.visible = true)
	buttons.add_child(controls)
	var leave := Button.new()
	leave.text = "Leave"
	leave.focus_mode = Control.FOCUS_NONE
	leave.pressed.connect(leave_requested.emit)
	buttons.add_child(leave)
	_add_close_button(panel, func() -> void: _menu.visible = false)
	return panel


## Menu: framerate cap and graphics quality (design log 0094), saved per machine.
func _graphics_settings() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)

	var fps := OptionButton.new()
	fps.focus_mode = Control.FOCUS_NONE  # keep Space for jumping
	for value in Graphics.FPS_CHOICES:
		fps.add_item(Graphics.fps_label(value), value)
	fps.select(fps.get_item_index(Graphics.max_fps))
	fps.item_selected.connect(func(index: int) -> void: Graphics.set_max_fps(fps.get_item_id(index)))
	_add_setting_row(grid, "Max framerate", fps)

	var quality := OptionButton.new()
	quality.focus_mode = Control.FOCUS_NONE
	quality.add_item("High", 0)
	quality.add_item("Low (faster)", 1)
	quality.select(1 if Graphics.low else 0)
	quality.item_selected.connect(func(index: int) -> void: Graphics.set_low(index == 1))
	_add_setting_row(grid, "Graphics", quality)
	return grid


func _add_setting_row(grid: GridContainer, text: String, control: Control) -> void:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(label)
	control.custom_minimum_size.x = 160
	grid.add_child(control)


## Menu > Controls: every action and its two keys. Click a key to rebind it.
func _build_controls() -> Control:
	var panel := _centered_panel()
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 420
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	column.add_child(_heading("Controls"))
	column.add_child(_faded("Click a key, then press the new one. Esc cancels, Backspace clears."))
	# Scrolls, so the list fits the screen as actions are added.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 440
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8)
	scroll.add_child(rows)
	for entry in Controls.actions():
		var action: String = entry.action
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.text = entry.label
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var buttons: Array[Button] = []
		for slot in Controls.SLOTS:
			var button := Button.new()
			button.custom_minimum_size.x = 110
			button.focus_mode = Control.FOCUS_NONE  # keep Space for jumping
			button.pressed.connect(_start_capture.bind(action, slot))
			row.add_child(button)
			buttons.append(button)
		_control_buttons[action] = buttons
		rows.add_child(row)

	var buttons_row := HBoxContainer.new()
	buttons_row.alignment = BoxContainer.ALIGNMENT_END
	buttons_row.add_theme_constant_override("separation", 8)
	column.add_child(buttons_row)
	var reset := Button.new()
	reset.text = "Reset to defaults"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(Controls.reset_to_defaults)
	buttons_row.add_child(reset)
	var back := Button.new()
	back.text = "Back"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func() -> void:
		_end_capture()
		_controls.visible = false
		_menu.visible = true)
	buttons_row.add_child(back)
	_add_close_button(panel, func() -> void:
		_end_capture()
		_controls.visible = false)
	return panel


func _centered_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.visible = false
	panel.add_theme_stylebox_override("panel", _solid_panel_box())
	return panel


## The theme's torn parchment panel, made opaque: see-through is too busy
## over the world.
func _solid_panel_box() -> StyleBox:
	var box := _root.theme.get_stylebox("panel", "PanelContainer").duplicate() as StyleBox
	if box is SketchBox:
		(box as SketchBox).fill_color.a = 1.0
	elif box is StyleBoxFlat:
		(box as StyleBoxFlat).bg_color.a = 1.0
	return box


## An ✕ in the panel's top right corner that runs `on_close`.
func _add_close_button(panel: PanelContainer, on_close: Callable) -> void:
	var close := Button.new()
	close.text = "✕"
	close.flat = true
	close.add_theme_font_override("font", Graphics.SYMBOLS_FONT)
	close.add_theme_font_size_override("font_size", 22)
	close.tooltip_text = "Close"
	close.focus_mode = Control.FOCUS_NONE  # keep Space for jumping
	close.custom_minimum_size = Vector2(CLOSE_SIZE, CLOSE_SIZE)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(on_close)
	panel.add_child(close)


func _slot_grid(columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	return grid


func _row(label_text: String, value: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(value)
	return row


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 26)
	return label


func _faded(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Palette.INK_FADED)
	return label


func _set_text(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text

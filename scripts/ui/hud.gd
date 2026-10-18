class_name Hud
extends CanvasLayer
## The in-world HUD (design log 0026).
##
## - Top left: your shape, level, health and XP.
## - Bottom right: the 1-5 quick-use slots over your bag; both are bag slots
##   (design logs 0036, 0043). Drag items to move them, double-click to wear
##   or drink, right-click to drop. Hover for what it does.
## - Top center: short messages (level up, loot, marriage).
## - Tab: character sheet: your five gear slots (drag gear on or off, or
##   double-click to take off) and stats. Esc: menu (players, leave,
##   controls). Keys are rebindable (Controls, design log 0035).
## Energy is drawn by PlayerShape, as pips over your own shape.

signal leave_requested

const GROUP := "hud"  # PlayerShape finds the HUD to show the priest's words

const MARGIN := 24
const BAG_COLUMNS := 5
const STAT_ROWS: Array[String] = ["vigor", "mettle", "force", "torque", "rigidity", "luck"]
const MESSAGE_TIME := 3.5  # s

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
var _bag_slots: Array[ItemSlot] = []  # indexed like PlayerShape.bag, quick slots last
var _quick_keys: Array[Label] = []
var _gear_slots: Array[ItemSlot] = []  # indexed like Gear.SLOTS
var _me: PlayerShape
var _set_label: Label
var _message: Label
var _message_time := 0.0
# Last values seen, to announce changes.
var _seen := {}


func _ready() -> void:
	add_to_group(GROUP)
	Controls.changed.connect(_on_controls_changed)
	_build()


## Dev hot reload (HotReload autoload): rebuild from the new code.
func _hot_reload() -> void:
	for child in get_children():
		child.queue_free()
	_stat_values.clear()
	_bag_slots.clear()
	_quick_keys.clear()
	_gear_slots.clear()
	_control_buttons.clear()
	_end_capture()
	_build()
	refresh_players()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("character_sheet"):
		_character.visible = not _character.visible
		_menu.visible = false
		_controls.visible = false
	elif event.is_action_pressed("menu"):
		if _controls.visible:
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
		Controls.describe("interact") + " talk",
		Controls.describe("pickup") + " pick up",
		Controls.describe("drink") + " drink",
	]
	var menus: Array[String] = [
		Controls.describe("home") + " home",
		Controls.describe("character_sheet") + " character",
		Controls.describe("menu") + " menu",
	]
	if OS.is_debug_build():
		menus.append(Controls.describe("debug_level_up") + " level up (debug)")
	return "  ·  ".join(actions) + "\n" + "  ·  ".join(menus)


func update(me: PlayerShape) -> void:
	_me = me
	_portrait.sides = me.sides
	_portrait.kind = me.kind
	_portrait.apex = me.apex
	_portrait.equipped = me.equipped
	_set_text(_level_label, "Level %d" % me.level)
	_health_bar.set_values(me.hp, me.max_hp)
	if me.level >= Stats.MAX_LEVEL:
		_xp_bar.set_values(1.0, 1.0)
	else:
		_xp_bar.set_values(me.xp, Stats.xp_to_next(me.level))
	for i in _bag_slots.size():
		_bag_slots[i].hint = _bag_hint(me.bag[i])
		_bag_slots[i].item = me.bag[i]
	for i in _gear_slots.size():
		_gear_slots[i].item = me.equipped[i]
	var full_set := Gear.set_tier(me.equipped)
	_set_text(_set_label, "Full set: none" if full_set == 0 else "Full %s set: %s" % [
			Gear.TIERS[full_set].name.to_lower(), Gear.describe_bonus(Gear.TIERS[full_set].set)])
	_announce_changes(me)
	_set_text(_character_title, "The %s family: %s" % [me.family_name, Family.describe_shape(me.sides, me.kind, me.apex)])
	_set_text(_stat_values["level"], str(me.level))
	# Totals, with what gear (and a full set) adds: "36 (+15)".
	var from_gear := Gear.total_bonus(me.equipped)
	for stat: String in STAT_ROWS:
		var text := str(me.get(stat))
		if from_gear.get(stat, 0) > 0:
			text += "  (+%d)" % from_gear[stat]
		_set_text(_stat_values[stat], text)


func show_message(text: String) -> void:
	if _message == null:
		return
	_message.text = text
	_message_time = MESSAGE_TIME


func _process(delta: float) -> void:
	if _message == null:
		return
	_message_time -= delta
	_message.modulate.a = clampf(_message_time, 0.0, 1.0)


func _announce_changes(me: PlayerShape) -> void:
	# Count items carried or worn, so swapping gear doesn't count as finding it.
	var items := {}
	for item in me.bag + me.equipped:
		if item != "":
			items[item] = items.get(item, 0) + 1
	var now := {"level": me.level, "items": items, "sides": me.sides, "set": Gear.set_tier(me.equipped)}
	if _seen.get("sides") == now.sides:  # not when an heir takes over
		if now.level > _seen.level:
			show_message("Level %d!" % now.level)
		for item: String in items:
			if items[item] > _seen.items.get(item, 0):
				show_message("Picked up: " + Gear.describe(item))
		if now["set"] > 0 and now["set"] != _seen.get("set", 0):
			var tier: Dictionary = Gear.TIERS[now["set"]]
			show_message("Full %s set! %s" % [tier.name.to_lower(), Gear.describe_bonus(tier.set)])
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
	_root.theme = UiTheme.build()
	add_child(_root)

	_root.add_child(_build_vitals())
	_root.add_child(_build_slots())

	var hint := _faded(_hint_text())
	_hint = hint
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, MARGIN)
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(hint)

	_character = _build_character()
	_root.add_child(_character)
	_menu = _build_menu()
	_root.add_child(_menu)
	_controls = _build_controls()
	_root.add_child(_controls)
	_on_controls_changed()

	_message = Label.new()
	_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, MARGIN)
	_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 22)
	_message.modulate.a = 0.0
	_root.add_child(_message)


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
## slots of PlayerShape.bag; the quick ones are its last five.
func _build_slots() -> Control:
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, MARGIN)
	column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)

	var hotbar := _slot_grid(BAG_COLUMNS)
	var bag := _slot_grid(BAG_COLUMNS)
	for i in PlayerShape.BAG_SIZE:
		var slot := _bag_slot(i)
		_bag_slots.append(slot)
		if i < PlayerShape.BAG_SLOTS:
			bag.add_child(slot)
			continue
		var key_label := _faded("")
		key_label.add_theme_font_size_override("font_size", 13)
		key_label.position = Vector2(5, 1)
		slot.add_child(key_label)
		_quick_keys.append(key_label)
		hotbar.add_child(slot)
	column.add_child(hotbar)
	column.add_child(bag)
	return column


## Bag slot i: drag to move, drop worn gear here to take it off.
func _bag_slot(i: int) -> ItemSlot:
	var slot := ItemSlot.new()
	slot.drag_source = {"bag": i}
	slot.accepts = func(data: Dictionary) -> bool:
		if not data.has("worn") or _me == null:
			return true
		# Taking gear off: into an empty slot, or swapping with gear for the same slot.
		var here := _me.bag[i]
		return here == "" or Gear.slot_of(here) == Gear.SLOTS[data.worn]
	slot.dropped.connect(func(data: Dictionary) -> void:
		if _me == null:
			return
		if data.has("bag"):
			_me.request_swap(data.bag, i)
		elif data.has("worn"):
			_me.request_unequip(data.worn, i))
	slot.double_clicked.connect(func() -> void:
		if _me != null:
			_me.request_use(i))
	slot.right_clicked.connect(func() -> void:
		if _me != null:
			_me.request_drop(i))
	return slot


func _bag_hint(item: String) -> String:
	if item == Gear.POTION:
		return "Double-click or %s: drink  ·  Drag: move  ·  Right-click: drop" % Controls.describe("drink")
	if Gear.is_gear(item):
		return "Double-click: wear  ·  Drag: move  ·  Right-click: drop"
	return "Drag: move  ·  Right-click: drop"


## Tab: who you are, what you wear, your stats.
func _build_character() -> Control:
	var panel := _centered_panel()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	_character_title = Label.new()
	_character_title.add_theme_font_size_override("font_size", 22)
	column.add_child(_character_title)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 32)
	column.add_child(columns)

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
				_me.request_equip(data.bag))
		slot.double_clicked.connect(func() -> void:
			if _me != null:
				_me.request_unequip(i))
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
	columns.add_child(stats)

	_close_hint = _faded("")
	column.add_child(_close_hint)
	return panel


## Esc: who's here, and the way out.
func _build_menu() -> Control:
	var panel := _centered_panel()
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 360
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	column.add_child(_heading("The Center"))
	column.add_child(_faded(Net.describe_session()))
	_player_list = VBoxContainer.new()
	column.add_child(_player_list)

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
	return panel


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
	return panel


func _centered_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.visible = false
	var box: StyleBoxFlat = _root.theme.get_stylebox("panel", "PanelContainer").duplicate()
	box.bg_color.a = 1.0  # the HUD's usual see-through panel is too busy over the world
	panel.add_theme_stylebox_override("panel", box)
	return panel


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
	label.add_theme_font_size_override("font_size", 20)
	return label


func _faded(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Palette.INK_FADED)
	return label


func _set_text(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text

extends Control
## Main menu: pick a server and one of 3 family slots (design log 0018).
##
## Run as a dedicated server with: godot --headless -- --server [--port=24680]

const WORLD_SCENE := "res://scenes/world.tscn"
const SETTINGS_PATH := "user://settings.cfg"
const ROMAN: Array[String] = ["I", "II", "III"]

var _mode_select: OptionButton
var _address_row: Control
var _address_edit: LineEdit
var _port_row: Control
var _port_spin: SpinBox
var _slots_box: HBoxContainer
var _status: Label
var _cancel_button: Button
var _busy := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Net.session_started.connect(_on_session_started)
	if _start_dedicated_server_if_requested():
		return
	theme = UiTheme.build()
	_build()
	_load_settings()
	Net.session_failed.connect(_on_session_failed)
	FamilyStore.slots_changed.connect(_refresh_slots)
	_refresh_slots()
	if Net.last_message != "":
		_set_status(Net.last_message)
		Net.last_message = ""


func _start_dedicated_server_if_requested() -> bool:
	var args := OS.get_cmdline_user_args()
	if not args.has("--server"):
		return false
	var on_port := Net.DEFAULT_PORT
	for arg in args:
		if arg.begins_with("--port="):
			on_port = arg.trim_prefix("--port=").to_int()
	Net.session_failed.connect(func(reason: String) -> void:
		push_error(reason)
		get_tree().quit(1))
	# Deferred: the scene can't be swapped while it's still being added to the tree.
	Net.host.call_deferred(on_port, {})
	return true


# --- Layout ---------------------------------------------------------------

func _build() -> void:
	add_child(ParchmentBackground.new())

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	center.add_child(column)

	var title := Label.new()
	title.text = "FLATLAND"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "A Romance of Many Dimensions"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Palette.INK_FADED)
	column.add_child(subtitle)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	column.add_child(row)
	row.add_child(_build_server_panel())
	_slots_box = HBoxContainer.new()
	_slots_box.add_theme_constant_override("separation", 16)
	row.add_child(_slots_box)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 12)
	column.add_child(footer)
	_status = Label.new()
	footer.add_child(_status)
	_cancel_button = Button.new()
	_cancel_button.text = "Cancel"
	_cancel_button.visible = false
	_cancel_button.pressed.connect(_on_cancel_pressed)
	footer.add_child(_cancel_button)


func _build_server_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(_heading("Server"))

	_mode_select = OptionButton.new()
	_mode_select.add_item("Offline", Net.Mode.OFFLINE)
	_mode_select.add_item("Host a server", Net.Mode.HOST)
	_mode_select.add_item("Join a server", Net.Mode.JOIN)
	_mode_select.item_selected.connect(func(_index: int) -> void: _update_server_fields())
	box.add_child(_mode_select)

	_address_edit = LineEdit.new()
	_address_edit.placeholder_text = "127.0.0.1"
	_address_row = _labeled("Address", _address_edit)
	box.add_child(_address_row)

	_port_spin = SpinBox.new()
	_port_spin.min_value = 1024
	_port_spin.max_value = 65535
	_port_spin.value = Net.DEFAULT_PORT
	_port_row = _labeled("Port", _port_spin)
	box.add_child(_port_row)
	return panel


func _refresh_slots() -> void:
	for child in _slots_box.get_children():
		child.queue_free()
	for slot in FamilyStore.SLOT_COUNT:
		_slots_box.add_child(_build_slot_card(slot))


func _build_slot_card(slot: int) -> Control:
	var family := FamilyStore.get_family(slot)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(210, 320)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(_heading("Family %s" % ROMAN[slot]))

	if family == null:
		box.add_child(_note("An empty plot of parchment."))
		box.add_child(_spacer())
		var name_edit := LineEdit.new()
		name_edit.placeholder_text = "Family name"
		name_edit.max_length = Family.MAX_NAME_LENGTH
		name_edit.editable = not _busy
		name_edit.text_submitted.connect(func(_text: String) -> void: _found_family(slot, name_edit))
		box.add_child(name_edit)
		var found := Button.new()
		found.text = "Found family"
		found.disabled = _busy
		found.pressed.connect(_found_family.bind(slot, name_edit))
		box.add_child(found)
		return panel

	box.add_child(ShapeIcon.new(family.sides, family.kind, 96))
	var name_label := Label.new()
	name_label.text = "The %s family" % family.family_name
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name_label)
	var rank := family.shape_name().capitalize()
	if family.is_priest():
		rank += " (priest)"
	box.add_child(_note("%s\nGeneration %d" % [rank, family.generation]))
	if family.extinct:
		box.add_child(_note("Extinct: died without an heir."))
	elif family.is_confined_to_underworld():
		box.add_child(_note("Irregular: confined to the underworld."))
	box.add_child(_spacer())

	var play := Button.new()
	play.text = "Play"
	play.disabled = _busy or family.extinct
	play.pressed.connect(_play.bind(slot))
	box.add_child(play)
	var delete := Button.new()
	delete.text = "Delete"
	delete.disabled = _busy
	delete.pressed.connect(_confirm_delete.bind(slot))
	box.add_child(delete)
	return panel


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	return label


func _note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Palette.INK_FADED)
	return label


func _labeled(text: String, field: Control) -> Control:
	var box := VBoxContainer.new()
	box.add_child(_note(text))
	box.add_child(field)
	return box


func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return spacer


# --- Actions --------------------------------------------------------------

func _found_family(slot: int, name_edit: LineEdit) -> void:
	if _busy:
		return
	var family := FamilyStore.found_family(slot, name_edit.text)
	var shape := Family.with_article(family.shape_name())
	var message := "The %s family begins as %s." % [family.family_name, shape]
	if family.is_confined_to_underworld():
		message += " Irregulars are confined to the underworld."
	_set_status(message)


func _confirm_delete(slot: int) -> void:
	var family := FamilyStore.get_family(slot)
	var dialog := ConfirmationDialog.new()
	dialog.title = "Delete family"
	dialog.dialog_text = "Delete the %s family? This can't be undone." % family.family_name
	dialog.ok_button_text = "Delete"
	dialog.confirmed.connect(func() -> void: FamilyStore.delete_family(slot))
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible:
			dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


func _play(slot: int) -> void:
	var family := FamilyStore.get_family(slot)
	if family == null or family.extinct or _busy:
		return
	var address := _address_edit.text.strip_edges()
	if address == "":
		address = _address_edit.placeholder_text
	var on_port := int(_port_spin.value)
	FamilyStore.active_slot = slot
	_save_settings()
	var info := family.to_public_info()
	match _mode_select.get_selected_id():
		Net.Mode.OFFLINE:
			Net.start_offline(info)
		Net.Mode.HOST:
			Net.host(on_port, info)
		Net.Mode.JOIN:
			_set_busy(true)
			_set_status("Connecting to %s:%d…" % [address, on_port])
			Net.join(address, on_port, info)


func _on_cancel_pressed() -> void:
	Net.leave()
	_set_busy(false)
	_set_status("Cancelled.")


func _on_session_started() -> void:
	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_session_failed(reason: String) -> void:
	_set_busy(false)
	_set_status(reason)


func _set_busy(busy: bool) -> void:
	_busy = busy
	_cancel_button.visible = busy
	_mode_select.disabled = busy
	_address_edit.editable = not busy
	_port_spin.editable = not busy
	_refresh_slots()


func _set_status(text: String) -> void:
	_status.text = text


func _update_server_fields() -> void:
	var mode := _mode_select.get_selected_id()
	_address_row.visible = mode == Net.Mode.JOIN
	_port_row.visible = mode != Net.Mode.OFFLINE


# --- Settings -------------------------------------------------------------

func _load_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)  # missing file just leaves the defaults
	var mode: int = config.get_value("server", "mode", Net.Mode.OFFLINE)
	var index := _mode_select.get_item_index(mode)
	_mode_select.select(index if index >= 0 else 0)
	_address_edit.text = config.get_value("server", "address", "")
	_port_spin.value = config.get_value("server", "port", Net.DEFAULT_PORT)
	_update_server_fields()


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("server", "mode", _mode_select.get_selected_id())
	config.set_value("server", "address", _address_edit.text.strip_edges())
	config.set_value("server", "port", int(_port_spin.value))
	config.save(SETTINGS_PATH)

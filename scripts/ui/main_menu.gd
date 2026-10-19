extends Control
## Main menu: pick a server and one of 3 family slots (design log 0018).
##
## Offline and hosting list this machine's own families (FamilyStore).
## Joining connects first; the server asks for a login (OnlineLogin) and
## sends the account's families, which live on the server (design log 0116).
##
## Run as a dedicated server with:
## godot --headless -- --server [--port=24680] [--save-dir=user://server/]

const WORLD_SCENE := "res://scenes/world.tscn"
const SETTINGS_PATH := "user://settings.cfg"
const ROMAN: Array[String] = ["I", "II", "III"]

## Joining: not connected, connecting, logging in, picking a family, starting.
enum Online { OFF, CONNECTING, LOGIN, SLOTS, STARTING }

var _mode_select: OptionButton
var _address_row: Control
var _address_edit: LineEdit
var _port_row: Control
var _port_spin: SpinBox
var _slots_box: HBoxContainer
var _status: Label
var _cancel_button: Button
var _busy := false
## Each empty slot's chosen starting triangle (design log 0050).
var _start_kinds := {}
var _online := Online.OFF
## Joining: the account's families from the server (Family or null).
var _server_families: Array = []
var _login: OnlineLogin
var _needs_login_button := false
var _account_box: Control
var _account_note: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Net.session_started.connect(_on_session_started)
	if _start_dedicated_server_if_requested():
		return
	theme = UiTheme.build()
	_build()
	_load_settings()
	Net.session_failed.connect(_on_session_failed)
	Net.accounts.login_needed.connect(_on_login_needed)
	Net.accounts.slots_received.connect(_on_slots_received)
	Net.accounts.account_error.connect(_set_status)
	_login = OnlineLogin.new()
	add_child(_login)
	_login.message.connect(_set_status)
	_login.needs_button.connect(func() -> void:
		_needs_login_button = true
		_refresh_slots())
	FamilyStore.slots_changed.connect(_refresh_slots)
	FamilyStore.reload()  # a local server may have saved since
	if Net.last_message != "":
		_set_status(Net.last_message)
		Net.last_message = ""
	if OS.has_feature("web") and await _login.finish_web_login() and _joining():
		_connect()  # back from the login page


func _start_dedicated_server_if_requested() -> bool:
	var args := OS.get_cmdline_user_args()
	if not args.has("--server"):
		return false
	var on_port := Net.DEFAULT_PORT
	var save_dir := ""
	for arg in args:
		if arg.begins_with("--port="):
			on_port = arg.trim_prefix("--port=").to_int()
		elif arg.begins_with("--save-dir="):
			save_dir = arg.trim_prefix("--save-dir=")
	Net.session_failed.connect(func(reason: String) -> void:
		push_error(reason)
		get_tree().quit(1))
	# Deferred: the scene can't be swapped while it's still being added to the tree.
	Net.host.call_deferred(on_port, -1, save_dir)
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

	# Players compare this with a server's "please update" message (log 0109).
	var version := Label.new()
	version.text = "Version %s" % Net.version
	version.add_theme_font_size_override("font_size", 13)
	version.add_theme_color_override("font_color", Palette.INK_FADED)
	add_child(version)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 12)


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
	if not OS.has_feature("web"):  # a browser can't listen for connections
		_mode_select.add_item("Host a server", Net.Mode.HOST)
	_mode_select.add_item("Join a server", Net.Mode.JOIN)
	_mode_select.item_selected.connect(func(_index: int) -> void:
		_update_server_fields()
		_refresh_slots())
	box.add_child(_mode_select)

	_address_edit = LineEdit.new()
	_address_edit.placeholder_text = "127.0.0.1"
	_address_edit.tooltip_text = "An IP or host name, or a full ws:// or wss:// address."
	_address_row = _labeled("Address", _address_edit)
	box.add_child(_address_row)

	_port_spin = SpinBox.new()
	_port_spin.min_value = 1024
	_port_spin.max_value = 65535
	_port_spin.value = Net.DEFAULT_PORT
	_port_row = _labeled("Port", _port_spin)
	box.add_child(_port_row)

	_account_box = VBoxContainer.new()
	_account_note = _note("")
	_account_box.add_child(_account_note)
	var log_out := Button.new()
	log_out.text = "Log out"
	log_out.pressed.connect(func() -> void:
		_login.log_out()
		_on_cancel_pressed())
	_account_box.add_child(log_out)
	box.add_child(_account_box)
	_account_box.visible = false
	return panel


func _refresh_slots() -> void:
	if _slots_box == null:
		return
	for child in _slots_box.get_children():
		child.queue_free()
	if not _joining():
		for slot in FamilyStore.SLOT_COUNT:
			_slots_box.add_child(_build_slot_card(slot, FamilyStore.get_family(slot)))
		return
	match _online:
		Online.OFF:
			_slots_box.add_child(_build_connect_card())
		Online.SLOTS:
			for slot in _server_families.size():
				_slots_box.add_child(_build_slot_card(slot, _server_families[slot]))
		_:
			_slots_box.add_child(_build_wait_card())


func _joining() -> bool:
	return _mode_select.get_selected_id() == Net.Mode.JOIN


func _family(slot: int) -> Family:
	return _server_families[slot] if _joining() else FamilyStore.get_family(slot)


## Joining, before connecting: the families are on the server.
func _build_connect_card() -> Control:
	var box := _card("Your families")
	box.add_child(_note("Online, your families are kept by the server. Connect to see them."))
	box.add_child(_spacer())
	var connect_button := Button.new()
	connect_button.text = "Connect"
	connect_button.pressed.connect(_connect)
	box.add_child(connect_button)
	return box.get_parent() as Control


func _build_wait_card() -> Control:
	var box := _card("Your families")
	if _online == Online.LOGIN and _needs_login_button:
		box.add_child(_note("Log in to play online. Your families are kept with your account."))
		box.add_child(_spacer())
		var google := Button.new()
		google.text = "Log in with Google"
		google.pressed.connect(func() -> void:
			_needs_login_button = false
			_refresh_slots()
			_login.log_in_with_google())
		box.add_child(google)
		return box.get_parent() as Control
	var text := "Connecting…"
	if _online == Online.LOGIN:
		text = "Logging in…"
	elif _online == Online.STARTING:
		text = "Entering the world…"
	box.add_child(_note(text))
	return box.get_parent() as Control


## A slot-sized panel with a heading; returns the column to fill.
func _card(title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(210, 320)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(_heading(title))
	return box


func _build_slot_card(slot: int, family: Family) -> Control:
	var box := _card("Family %s" % ROMAN[slot])
	var panel := box.get_parent() as Control

	if family == null:
		box.add_child(_note("An empty plot of parchment."))
		box.add_child(_spacer())
		var name_edit := LineEdit.new()
		name_edit.placeholder_text = "Family name"
		name_edit.max_length = Family.MAX_NAME_LENGTH
		name_edit.editable = not _busy
		name_edit.text_submitted.connect(func(_text: String) -> void: _found_family(slot, name_edit))
		box.add_child(name_edit)
		box.add_child(_build_start_picker(slot))
		var found := Button.new()
		found.text = "Found family"
		found.disabled = _busy
		found.pressed.connect(_found_family.bind(slot, name_edit))
		box.add_child(found)
		return panel

	box.add_child(ShapeIcon.new(family.sides, family.kind, 96, family.apex, family.worn_gear()))
	var name_label := Label.new()
	name_label.text = "The %s family" % family.family_name
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name_label)
	var rank := family.shape_name().capitalize()
	if family.is_priest():
		rank += " (priest)"
	var level := int(family.progress.get("level", 1))
	box.add_child(_note("%s\nGeneration %d  ·  Level %d" % [rank, family.generation, level]))
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


## Three toggle buttons, one per starting triangle, with the choice named below.
func _build_start_picker(slot: int) -> Control:
	var chosen: String = _start_kinds.get(slot, "isosceles")
	var box := VBoxContainer.new()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var caption := _note("")
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(caption)
	var group := ButtonGroup.new()
	for kind in Family.STARTING_KINDS:
		var apex := Family.START_APEX
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(60, 60)
		button.disabled = _busy
		button.tooltip_text = Family.describe_shape(3, kind, apex).capitalize()
		var icon := ShapeIcon.new(3, kind, 48, apex)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.add_child(icon)
		button.toggled.connect(func(on: bool) -> void:
			if on:
				_start_kinds[slot] = kind
				caption.text = button.tooltip_text)
		row.add_child(button)
		if kind == chosen:
			button.button_pressed = true
	return box


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
	if _joining():
		_set_busy(true)
		Net.accounts.found(slot, name_edit.text, _start_kinds.get(slot, "isosceles"))
		return
	var family := FamilyStore.found_family(slot, name_edit.text, _start_kinds.get(slot, "isosceles"))
	var shape := Family.with_article(family.shape_name())
	var message := "The %s family begins as %s." % [family.family_name, shape]
	if family.is_confined_to_underworld():
		message += " Irregulars are confined to the underworld."
	_set_status(message)


func _confirm_delete(slot: int) -> void:
	var family := _family(slot)
	var dialog := ConfirmationDialog.new()
	dialog.title = "Delete family"
	dialog.dialog_text = "Delete the %s family? This can't be undone." % family.family_name
	dialog.ok_button_text = "Delete"
	dialog.confirmed.connect(func() -> void:
		if _joining():
			_set_busy(true)
			Net.accounts.delete(slot)
		else:
			FamilyStore.delete_family(slot))
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible:
			dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


func _play(slot: int) -> void:
	var family := _family(slot)
	if family == null or family.extinct or _busy:
		return
	_save_settings()
	match _mode_select.get_selected_id():
		Net.Mode.OFFLINE:
			Net.start_offline(slot)
		Net.Mode.HOST:
			Net.host(int(_port_spin.value), slot)
		Net.Mode.JOIN:
			_online = Online.STARTING
			_set_busy(true)
			Net.accounts.play(slot)


func _connect() -> void:
	var address := _address_edit.text.strip_edges()
	if address == "":
		address = _address_edit.placeholder_text
	var on_port := int(_port_spin.value)
	_save_settings()
	_online = Online.CONNECTING
	_login.reset()
	_set_busy(true)
	_set_status("Connecting to %s…" % Net.server_url(address, on_port))
	Net.join(address, on_port)


func _on_login_needed(info: Dictionary) -> void:
	_online = Online.LOGIN
	_needs_login_button = false
	_set_busy(false)
	_login.answer(info)


func _on_slots_received(families: Array) -> void:
	_server_families = families
	_online = Online.SLOTS
	_set_busy(false)


func _on_cancel_pressed() -> void:
	Net.leave()
	_login.reset()
	_online = Online.OFF
	_set_busy(false)
	_set_status("Disconnected.")


func _on_session_started() -> void:
	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_session_failed(reason: String) -> void:
	_online = Online.OFF
	_set_busy(false)
	_set_status(reason)


func _set_busy(busy: bool) -> void:
	_busy = busy
	var connected := _online != Online.OFF
	_cancel_button.visible = busy or connected
	_cancel_button.text = "Disconnect" if _online == Online.SLOTS else "Cancel"
	_mode_select.disabled = busy or connected
	_address_edit.editable = not (busy or connected)
	_port_spin.editable = not (busy or connected)
	_account_note.text = "Logged in as %s" % _login.email
	_account_box.visible = _joining() and _online == Online.SLOTS and _login.email != ""
	_refresh_slots()


func _set_status(text: String) -> void:
	_status.text = text
	if _busy and _online == Online.SLOTS:
		_set_busy(false)  # a refused request


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

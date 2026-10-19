extends Control
## Main menu: Offline or Online, then one of 3 family slots (design logs
## 0018, 0119).
##
## Offline lists this machine's own families (FamilyStore). Online connects
## to the game's server (Net.online_address), which asks for a login
## (OnlineLogin) and sends the account's families, kept on the server
## (design log 0116).
##
## Run as a dedicated server with:
## godot --headless -- --server [--port=24680] [--save-dir=user://server/]

const WORLD_SCENE := "res://scenes/world.tscn"
const SETTINGS_PATH := "user://settings.cfg"
const ROMAN: Array[String] = ["I", "II", "III"]
const CARD_WIDTH := 420

## Online: not connected, connecting, logging in, choosing a username,
## picking a family, starting.
enum Online { OFF, CONNECTING, LOGIN, USERNAME, SLOTS, STARTING }

var _offline_tab: Button
var _online_tab: Button
var _body: VBoxContainer
var _status: Label
var _busy := false
## Each empty slot's chosen starting triangle (design log 0050).
var _start_kinds := {}
var _online_mode := false
var _online := Online.OFF
## Online: the account's families from the server (Family or null).
var _server_families: Array = []
var _login: OnlineLogin
var _needs_login_button := false
## Online: the Google page is open in the browser.
var _in_browser := false
## Online: the latest word from connecting or logging in, shown on the card.
var _online_note := ""
## Online: why the last connection failed, or "".
var _online_error := ""
## Online: why the last Google login didn't finish, or "".
var _sign_in_problem := ""
## Online: who we're signed in as; players see this, never an email (log 0123).
var _username := ""
## Online: why the last username was refused, or "".
var _username_problem := ""
## Online: the username being typed, kept across refreshes.
var _username_draft := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Net.session_started.connect(_on_session_started)
	if _start_dedicated_server_if_requested():
		return
	theme = UiTheme.build()
	_build()
	Net.session_failed.connect(_on_session_failed)
	Net.accounts.login_needed.connect(_on_login_needed)
	Net.accounts.slots_received.connect(_on_slots_received)
	Net.accounts.account_error.connect(_on_account_error)
	Net.accounts.username_needed.connect(_on_username_needed)
	Net.accounts.signed_in.connect(func(username: String) -> void:
		_username = username)
	_login = OnlineLogin.new()
	add_child(_login)
	_login.message.connect(_set_status)
	_login.needs_button.connect(func() -> void:
		_needs_login_button = true
		_in_browser = false
		_refresh())
	_login.login_failed.connect(func(reason: String) -> void:
		_sign_in_problem = reason)
	_login.signing_in.connect(func() -> void:
		_in_browser = false
		_online_note = "Signing in…"
		_refresh())
	FamilyStore.slots_changed.connect(_refresh)
	FamilyStore.reload()  # a local server may have saved since
	_load_settings()
	if Net.last_message != "":
		_set_status(Net.last_message)
		Net.last_message = ""
	if OS.has_feature("web"):
		await _login.finish_web_login()  # back from the login page
	if _online_mode:
		_connect()
	else:
		_refresh()


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

	column.add_child(_build_mode_tabs())

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 14)
	_body.custom_minimum_size = Vector2(0, 440)  # the tallest slot card; keeps the title still
	column.add_child(_body)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_status)

	# Players compare this with a server's "please update" message (log 0109).
	var version := Label.new()
	version.text = "Version %s" % Net.version
	version.add_theme_font_size_override("font_size", 13)
	version.add_theme_color_override("font_color", Palette.INK_FADED)
	add_child(version)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 12)


## Offline | Online, side by side.
func _build_mode_tabs() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)
	var group := ButtonGroup.new()
	_offline_tab = _mode_tab("Offline", group)
	_offline_tab.tooltip_text = "Play families kept on this computer."
	_offline_tab.pressed.connect(_set_online_mode.bind(false))
	row.add_child(_offline_tab)
	_online_tab = _mode_tab("Online", group)
	_online_tab.tooltip_text = "Play with others. Your families are kept with your account."
	_online_tab.pressed.connect(_set_online_mode.bind(true))
	row.add_child(_online_tab)
	return row


func _mode_tab(text: String, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = group
	button.custom_minimum_size = Vector2(150, 40)
	return button


func _refresh() -> void:
	if _body == null:
		return
	for child in _body.get_children():
		child.queue_free()
	_offline_tab.disabled = _busy and _online_mode
	_online_tab.disabled = _offline_tab.disabled
	if not _online_mode:
		_body.add_child(_slots_row(FamilyStore.SLOT_COUNT, FamilyStore.get_family))
		return
	match _online:
		Online.SLOTS:
			_body.add_child(_build_account_bar())
			_body.add_child(_slots_row(_server_families.size(), func(slot: int) -> Family:
				return _server_families[slot]))
		Online.OFF:
			_body.add_child(_centered(_build_retry_card()))
		Online.LOGIN when _needs_login_button:
			_body.add_child(_centered(_build_sign_in_card()))
		Online.LOGIN when _in_browser:
			_body.add_child(_centered(_build_browser_card()))
		Online.USERNAME:
			_body.add_child(_centered(_build_username_card()))
		Online.STARTING:
			_body.add_child(_centered(_build_wait_card("Entering the world…", false)))
		_:
			_body.add_child(_centered(_build_wait_card(_online_note, true)))


func _slots_row(count: int, family_at: Callable) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	for slot in count:
		row.add_child(_build_slot_card(slot, family_at.call(slot)))
	return row


func _centered(control: Control) -> Control:
	var box := CenterContainer.new()
	box.add_child(control)
	return box


func _family(slot: int) -> Family:
	return _server_families[slot] if _online_mode else FamilyStore.get_family(slot)


## Online, signed in: who, and a way out.
func _build_account_bar() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var who := _note("")
	who.autowrap_mode = TextServer.AUTOWRAP_OFF  # a wrapping label in a row has no width
	if _username != "":
		who.text = "Signed in as %s" % _username
		row.add_child(who)
		var sign_out := _small_button("Sign out")
		sign_out.disabled = _busy
		sign_out.pressed.connect(_sign_out)
		row.add_child(sign_out)
	else:
		who.text = "Connected to %s" % _server_name()
		row.add_child(who)
	return row


## Online, waiting on the server or the login.
func _build_wait_card(text: String, can_cancel: bool) -> Control:
	var box := _online_card("Online")
	box.add_child(_note(text if text != "" else "Reaching the server…", true))
	if can_cancel:
		var cancel := _small_button("Cancel")
		cancel.pressed.connect(_cancel)
		box.add_child(_centered(cancel))
	return box.get_parent() as Control


## Online, not connected: why, and try again.
func _build_retry_card() -> Control:
	var box := _online_card("Can't reach the server" if _online_error != "" else "Not connected")
	var text := _online_error
	if text == "":
		text = "Connect to see your families."
	elif text == "Couldn't reach the server.":  # the heading says it already
		text = "It may be restarting. Check your connection, or play offline."
	box.add_child(_note(text, true))
	var again := Button.new()
	again.text = "Try again" if _online_error != "" else "Connect"
	again.custom_minimum_size = Vector2(180, 0)
	again.pressed.connect(_connect)
	box.add_child(_centered(again))
	box.add_child(_server_line())
	return box.get_parent() as Control


func _build_sign_in_card() -> Control:
	var box := _online_card("Sign in to play online")
	box.add_child(_note("Your families are kept with your account, so you can play them from any computer or browser.", true))
	if _sign_in_problem != "":
		var problem := _note(_sign_in_problem, true)
		problem.add_theme_color_override("font_color", Palette.INK)
		box.add_child(problem)
	var google := GoogleButton.new()
	google.pressed.connect(func() -> void:
		_needs_login_button = false
		_in_browser = true
		_sign_in_problem = ""
		_refresh()
		_login.log_in_with_google())
	box.add_child(_centered(google))
	box.add_child(_server_line())
	return box.get_parent() as Control


## Online, first sign-in: the name other players will see.
func _build_username_card() -> Control:
	var box := _online_card("Choose a username")
	box.add_child(_note("This is the name others see. Your email stays private.", true))
	var edit := LineEdit.new()
	edit.placeholder_text = "Username"
	edit.max_length = Accounts.USERNAME_MAX
	edit.text = _username_draft
	edit.editable = not _busy
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.text_changed.connect(func(text: String) -> void:
		_username_draft = text)
	edit.text_submitted.connect(func(_text: String) -> void: _submit_username())
	box.add_child(edit)
	var problem := _note(_username_problem if _username_problem != "" else
			"%d to %d letters, numbers or _." % [Accounts.USERNAME_MIN, Accounts.USERNAME_MAX], true)
	if _username_problem != "":
		problem.add_theme_color_override("font_color", Palette.INK)
	box.add_child(problem)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var go := Button.new()
	go.text = "Continue"
	go.custom_minimum_size = Vector2(180, 0)
	go.disabled = _busy
	go.pressed.connect(_submit_username)
	row.add_child(go)
	var sign_out := _small_button("Sign out")
	sign_out.disabled = _busy
	sign_out.pressed.connect(_sign_out)
	row.add_child(sign_out)
	box.add_child(row)
	if not _busy:
		edit.grab_focus.call_deferred()
	return box.get_parent() as Control


func _build_browser_card() -> Control:
	var box := _online_card("Finish in your browser")
	box.add_child(_note("A Google sign-in page opened in your browser. Come back here once you've signed in.", true))
	var cancel := _small_button("Cancel")
	cancel.pressed.connect(func() -> void:
		_login.cancel_google())
	box.add_child(_centered(cancel))
	return box.get_parent() as Control


func _server_line() -> Label:
	var line := _note("Server: %s" % _server_name(), true)
	line.add_theme_font_size_override("font_size", 13)
	return line


## The online card: one centred panel; returns the column to fill.
func _online_card(title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var heading := _heading(title)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	return box


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


func _note(text: String, centered := false) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Palette.INK_FADED)
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _small_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 15)
	button.custom_minimum_size = Vector2(110, 0)
	return button


func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return spacer


## The server's host name, for players to read.
func _server_name() -> String:
	var url := Net.server_url(Net.online_address(), Net.DEFAULT_PORT)
	return url.trim_prefix("wss://").trim_prefix("ws://").trim_suffix("/")


# --- Actions --------------------------------------------------------------

func _set_online_mode(online: bool) -> void:
	if online == _online_mode:
		return
	_online_mode = online
	_save_settings()
	_set_status("")
	if online:
		_connect()
	else:
		_disconnect()


func _found_family(slot: int, name_edit: LineEdit) -> void:
	if _busy:
		return
	if _online_mode:
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
		if _online_mode:
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
	if _online_mode:
		_online = Online.STARTING
		_set_busy(true)
		Net.accounts.play(slot)
	else:
		Net.start_offline(slot)


func _connect() -> void:
	_login.reset()
	_online = Online.CONNECTING
	_online_note = "Reaching the server…"
	_online_error = ""
	_needs_login_button = false
	_in_browser = false
	_sign_in_problem = ""
	_username = ""
	_username_problem = ""
	_set_busy(true)
	Net.join(Net.online_address(), Net.DEFAULT_PORT)


func _submit_username() -> void:
	if _busy:
		return
	var username := _username_draft.strip_edges()
	_username_problem = Accounts.username_problem(username)
	if _username_problem != "":
		_refresh()
		return
	_set_busy(true)
	Net.accounts.choose_username(username)


func _on_username_needed(problem: String) -> void:
	_online = Online.USERNAME
	_username_problem = problem
	_in_browser = false
	_set_busy(false)


func _disconnect() -> void:
	if _online != Online.OFF:
		Net.leave()
		_login.reset()
	_online = Online.OFF
	_set_busy(false)


func _cancel() -> void:
	_disconnect()
	_online_error = ""


## Forget the saved session and reconnect, so the server asks again.
func _sign_out() -> void:
	_login.log_out()
	Net.leave()
	_connect()


func _on_login_needed(info: Dictionary) -> void:
	_online = Online.LOGIN
	_online_note = "Signing in…"
	_needs_login_button = false
	_set_busy(false)
	_login.answer(info)


## A refused request. While signing in it's why the login was refused: the
## server asks for a login again right after, so keep it for the sign-in card.
func _on_account_error(message: String) -> void:
	if _online_mode and _online == Online.LOGIN:
		_sign_in_problem = message
	_set_status(message)


func _on_slots_received(families: Array) -> void:
	_server_families = families
	_online = Online.SLOTS
	_in_browser = false
	_set_status("")
	_set_busy(false)


func _on_session_started() -> void:
	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_session_failed(reason: String) -> void:
	_online = Online.OFF
	_online_error = reason
	_set_busy(false)


func _set_busy(busy: bool) -> void:
	_busy = busy
	_refresh()


## Messages while connecting or logging in go on the online card; others
## (a refused request, a founded family) go under the slots.
func _set_status(text: String) -> void:
	if _online_mode and _online in [Online.CONNECTING, Online.LOGIN]:
		_online_note = text
		_refresh()
		return
	_status.text = text
	if _busy and _online == Online.SLOTS:
		_set_busy(false)  # a refused request


# --- Settings -------------------------------------------------------------

func _load_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)  # missing file just leaves the defaults
	# Older menus saved Net.Mode (2 was joining a server).
	var mode: Variant = config.get_value("server", "mode", "offline")
	_online_mode = (mode is String and mode == "online") or (mode is int and mode == Net.Mode.JOIN)
	(_online_tab if _online_mode else _offline_tab).button_pressed = true


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("server", "mode", "online" if _online_mode else "offline")
	config.save(SETTINGS_PATH)

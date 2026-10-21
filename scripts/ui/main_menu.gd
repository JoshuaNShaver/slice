extends Control
## Main menu: Offline or Online, then one of 3 family slots (design logs
## 0018, 0119). A sidebar beside a drawn picture; Play opens the families
## (log 0185).
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
## Family cards (log 0133): fixed, so the column fits a 720-high view.
const CARD_WIDTH_SLOT := 210
const CARD_HEIGHT := 400

## Online: not connected, connecting, logging in, choosing a username,
## picking a family, starting.
enum Online { OFF, CONNECTING, LOGIN, USERNAME, SLOTS, STARTING }

## The sidebar (log 0185).
const SIDEBAR_WIDTH := 250
const MARGIN := 24

var _offline_tab: Button
var _online_tab: Button
var _mode_note: Label
var _play_button: Button
var _account_box: VBoxContainer
var _scene: MenuScene
var _banner: Control
## The family panel Play opens; online steps show in it too.
var _panel: PanelContainer
var _panel_title: Label
var _panel_note: Label
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
## Online: the username field while it's shown. Its text is read directly:
## a phone browser's keyboard sets it without text_changed.
var _username_edit: LineEdit
## Web: the whole menu, lifted above the phone keyboard while typing
## (log 0132), and how far it's lifted.
var _page: Control
var _lift := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Net.session_started.connect(_on_session_started)
	if _start_dedicated_server_if_requested():
		return
	theme = UiTheme.build_menu()
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
		_refresh()
		_show_panel(true))  # signing in happens in the panel
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
	var login_problem := ""
	if OS.has_feature("web"):
		WebApp.check_build()  # a newer build on the host: switch now (log 0166)
		login_problem = await _login.finish_web_login()  # back from the login page
	if _online_mode:
		_connect()
		_sign_in_problem = login_problem  # shown on the sign-in card
	else:
		_set_status(login_problem)
		_refresh()


func _process(delta: float) -> void:
	if _page == null or not OS.has_feature("web"):
		return
	var target := _keyboard_lift()
	if is_equal_approx(target, _lift):
		return
	_lift = move_toward(_lift, target, maxf(absf(target - _lift) * 12.0 * delta, 4.0))
	_page.position.y = -_lift


## Web: how far to lift the menu so the field being typed in sits just
## above the phone keyboard, which covers the bottom of the game.
func _keyboard_lift() -> float:
	var field := get_viewport().gui_get_focus_owner()
	if not (field is LineEdit or field is TextEdit):
		return 0.0
	var cover := float(JavaScriptBridge.eval("window.sliceKeyboardCover ? window.sliceKeyboardCover() : 0", true))
	if cover <= 0.0:
		return 0.0
	var height := get_viewport_rect().size.y
	var keyboard_top := height * (1.0 - cover)
	var rect := field.get_global_rect()
	var top := rect.position.y + _lift  # where it sits unlifted
	var lift := top + rect.size.y + 16.0 - keyboard_top
	return clampf(lift, 0.0, maxf(top - 8.0, 0.0))


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

## The sidebar on the left with the modes and Play, the picture filling the
## rest under the title banner; Play opens the family panel over the
## picture (log 0185).
func _build() -> void:
	add_child(ParchmentBackground.new())

	_scene = MenuScene.new()
	add_child(_scene)
	_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scene.offset_left = SIDEBAR_WIDTH + MARGIN
	var ink := InkPass.new()  # the picture in ink on paper; the menu over it stays crisp (log 0191)
	ink.fog = 0.0  # the picture has its own fog
	add_child(ink)

	_page = Control.new()
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page)
	_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page.add_child(_build_sidebar())

	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(stage)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.offset_left = SIDEBAR_WIDTH + MARGIN * 2
	stage.offset_right = -MARGIN
	stage.offset_top = MARGIN
	stage.offset_bottom = -MARGIN

	_banner = _build_banner()
	stage.add_child(_banner)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)

	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(_build_panel())
	_panel.visible = false


func _build_sidebar() -> Control:
	var sidebar := PanelContainer.new()
	sidebar.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	sidebar.offset_left = MARGIN
	sidebar.offset_right = MARGIN + SIDEBAR_WIDTH
	sidebar.offset_top = MARGIN
	sidebar.offset_bottom = -MARGIN
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	sidebar.add_child(column)

	var group := ButtonGroup.new()
	_offline_tab = _mode_tab("Offline", group)
	_offline_tab.pressed.connect(_set_online_mode.bind(false))
	column.add_child(_offline_tab)
	_online_tab = _mode_tab("Online", group)
	_online_tab.pressed.connect(_set_online_mode.bind(true))
	column.add_child(_online_tab)
	_mode_note = _note("")
	column.add_child(_mode_note)

	column.add_child(_rule())
	_play_button = Button.new()
	_play_button.text = "Play"
	_play_button.theme_type_variation = "PrimaryButton"
	_play_button.custom_minimum_size = Vector2(0, 56)
	_play_button.pressed.connect(_show_panel.bind(true))
	column.add_child(_play_button)
	if not OS.has_feature("web"):  # a browser tab is closed, not quit
		var quit := Button.new()
		quit.text = "Quit"
		quit.pressed.connect(get_tree().quit)
		column.add_child(quit)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	_status = _note("")
	column.add_child(_status)
	_account_box = VBoxContainer.new()
	_account_box.add_theme_constant_override("separation", 6)
	column.add_child(_account_box)
	column.add_child(_rule())
	# Players compare this with a server's "please update" message (log 0109).
	var version := _note("Version %s\n%s" % [Net.version, BuildInfo.describe(BuildInfo.id())])  # build under it (log 0166)
	version.add_theme_font_size_override("font_size", 14)
	column.add_child(version)
	return sidebar


func _mode_tab(text: String, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = group
	button.custom_minimum_size = Vector2(0, 44)
	return button


## The title on a torn strip of parchment, tilted a little.
func _build_banner() -> Control:
	var banner := PanelContainer.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", -6)
	banner.add_child(column)
	var title := Label.new()
	title.text = "FLATLAND"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 76)
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "A Romance of Many Dimensions"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", UiTheme.menu_font(true))
	subtitle.add_theme_font_size_override("font_size", 26)
	column.add_child(subtitle)
	banner.rotation = deg_to_rad(-1.5)
	banner.resized.connect(func() -> void: banner.pivot_offset = banner.size / 2.0)
	return banner


## The panel Play opens: its title and a close mark, then the family
## cards, or the online step that comes before them.
func _build_panel() -> Control:
	_panel = PanelContainer.new()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	column.add_child(header)
	_panel_title = Label.new()
	_panel_title.add_theme_font_size_override("font_size", 36)
	header.add_child(_panel_title)
	_panel_note = _note("")
	_panel_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_panel_note.add_theme_font_override("font", UiTheme.menu_font(true))
	header.add_child(_panel_note)
	var close := Button.new()
	close.text = "✕"
	close.flat = true
	close.tooltip_text = "Back"
	close.add_theme_font_override("font", Graphics.SYMBOLS_FONT)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(_show_panel.bind(false))
	header.add_child(close)
	column.add_child(_rule())
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 14)
	column.add_child(_body)
	return _panel


## A pencil line across, between groups.
func _rule() -> Control:
	var rule := Control.new()
	rule.custom_minimum_size = Vector2(0, 10)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.draw.connect(func() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = roundi(rule.size.x)
		var y := rule.size.y / 2.0
		Sketch.line(rule.get_canvas_item(), Vector2(4, y), Vector2(rule.size.x - 4, y),
				Color(Palette.INK, 0.6), 1.3, rng, 2, 6.0, 0.8))
	return rule


## Opens or closes the family panel; the title banner gives it the room.
func _show_panel(open: bool) -> void:
	if _panel.visible == open:
		return
	_panel.visible = open
	_banner.visible = not open
	if open:
		_panel.modulate.a = 0.0
		create_tween().tween_property(_panel, "modulate:a", 1.0, 0.18)


func _unhandled_input(event: InputEvent) -> void:
	if _panel != null and _panel.visible and event.is_action_pressed("ui_cancel"):
		_show_panel(false)
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	if _body == null:
		return
	_keep_username_draft()
	for child in _body.get_children():
		child.queue_free()
	_offline_tab.disabled = _busy and _online_mode
	_online_tab.disabled = _offline_tab.disabled
	_mode_note.text = ("Play with others. Your families are kept with your account." if _online_mode
			else "Families kept on this computer.")
	_refresh_account()
	_scene.family = _first_family()
	_panel_title.text = "Select a Family"
	_panel_note.text = "Each family is a line of heirs, one shape after another."
	if not _online_mode:
		_body.add_child(_slots_row(FamilyStore.SLOT_COUNT, FamilyStore.get_family))
		return
	match _online:
		Online.SLOTS:
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


## The first family in the slots shown, for the picture; null if none.
func _first_family() -> Family:
	var count := _server_families.size() if _online_mode else FamilyStore.SLOT_COUNT
	for slot in count:
		var family := _family(slot)
		if family != null and not family.extinct:
			return family
	return null


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


## Online, in the sidebar: who's signed in, and a way out.
func _refresh_account() -> void:
	for child in _account_box.get_children():
		child.queue_free()
	if not _online_mode or _online != Online.SLOTS:
		return
	var who := _note("Signed in as %s" % _username if _username != "" else "Connected to %s" % _server_name())
	_account_box.add_child(who)
	if _username != "":
		var sign_out := _small_button("Sign out")
		sign_out.disabled = _busy
		sign_out.pressed.connect(_sign_out)
		_account_box.add_child(sign_out)


## Online, waiting on the server or the login.
func _build_wait_card(text: String, can_cancel: bool) -> Control:
	var box := _online_card("Online")
	box.add_child(_note(text if text != "" else "Reaching the server…", true))
	if can_cancel:
		var cancel := _small_button("Cancel")
		cancel.pressed.connect(_cancel)
		box.add_child(_centered(cancel))
	return box


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
	return box


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
	return box


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
	_username_edit = edit
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
	return box


func _build_browser_card() -> Control:
	var box := _online_card("Finish in your browser")
	box.add_child(_note("A Google sign-in page opened in your browser. Come back here once you've signed in.", true))
	var cancel := _small_button("Cancel")
	cancel.pressed.connect(func() -> void:
		_login.cancel_google())
	box.add_child(_centered(cancel))
	return box


func _server_line() -> Label:
	var line := _note("Server: %s" % _server_name(), true)
	line.add_theme_font_size_override("font_size", 13)
	return line


## An online step: its title heads the panel; returns the column to fill.
func _online_card(title: String) -> VBoxContainer:
	_panel_title.text = title
	_panel_note.text = ""
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	box.add_theme_constant_override("separation", 16)
	return box


## A family card (log 0133): a fixed height, so long details scroll and the
## buttons stay in reach on a short screen. Fill `details` and `buttons`.
class SlotCard:
	var panel := PanelContainer.new()
	var details := VBoxContainer.new()
	var buttons := VBoxContainer.new()

	func _init(heading: Label) -> void:
		panel.custom_minimum_size = Vector2(CARD_WIDTH_SLOT, CARD_HEIGHT)
		panel.theme_type_variation = "Card"
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 8)
		panel.add_child(column)
		column.add_child(heading)
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		column.add_child(scroll)
		var gutter := MarginContainer.new()  # clear of the scroll bar
		gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gutter.add_theme_constant_override("margin_right", 6)
		scroll.add_child(gutter)
		details.add_theme_constant_override("separation", 8)
		gutter.add_child(details)
		buttons.add_theme_constant_override("separation", 8)
		column.add_child(buttons)


func _build_slot_card(slot: int, family: Family) -> Control:
	var card := SlotCard.new(_heading("Family %s" % ROMAN[slot]))
	var box := card.details

	if family == null:
		box.add_child(_note("An empty plot of parchment."))
		var name_edit := LineEdit.new()
		name_edit.placeholder_text = "Family name"
		name_edit.max_length = Family.MAX_NAME_LENGTH
		name_edit.editable = not _busy
		name_edit.text_submitted.connect(func(_text: String) -> void: _found_family(slot, name_edit))
		box.add_child(name_edit)
		box.add_child(_build_start_picker(slot))
		var found := Button.new()
		found.text = "Found family"
		found.theme_type_variation = "PrimaryButton"
		found.disabled = _busy
		found.pressed.connect(_found_family.bind(slot, name_edit))
		card.buttons.add_child(found)
		return card.panel

	var icon := ShapeIcon.new(family.sides, family.kind, 76, family.apex, family.worn_gear())
	box.add_child(icon)
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

	var play := Button.new()
	play.text = "Play"
	play.theme_type_variation = "PrimaryButton"
	play.disabled = _busy or family.extinct
	play.pressed.connect(_play.bind(slot))
	card.buttons.add_child(play)
	var delete := Button.new()
	delete.text = "Delete"
	delete.disabled = _busy
	delete.pressed.connect(_confirm_delete.bind(slot))
	card.buttons.add_child(delete)
	return card.panel


## One toggle button per starting triangle the player may pick, with the
## choice named below. Irregular is hidden until unlocked (design log 0175).
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
	# Irregular appears once an heir is born irregular (design logs 0174, 0175).
	var unlocks: Array = Net.accounts.unlocks if _online_mode else FamilyStore.unlocks
	if not Family.can_start(chosen, unlocks):
		chosen = "isosceles"
		_start_kinds[slot] = chosen
	for kind in Family.STARTING_KINDS:
		if not Family.can_start(kind, unlocks):
			continue
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
	_keep_username_draft()
	var username := _username_draft.strip_edges()
	_username_problem = Accounts.username_problem(username)
	if _username_problem != "":
		_refresh()
		return
	_set_busy(true)
	Net.accounts.choose_username(username)


## On the web, a phone's keyboard fills the field with set_text, which
## doesn't emit text_changed, so read the field itself.
func _keep_username_draft() -> void:
	if is_instance_valid(_username_edit) and not _username_edit.is_queued_for_deletion():
		_username_draft = _username_edit.text


func _on_username_needed(problem: String) -> void:
	_online = Online.USERNAME
	_username_problem = problem
	_in_browser = false
	_set_busy(false)
	_show_panel(true)


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

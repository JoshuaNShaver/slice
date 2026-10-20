class_name ChatBox
extends Control
## The chat (design log 0124), part of the HUD.
##
## A log of what's been said nearby, in the corner. New lines show for a
## while and then fade out; while the chat is open, the whole log shows and
## scrolls. Enter (or the Chat button on a touch screen) opens a line to
## type in: Enter sends, Esc or Enter on an empty line closes it, Up and
## Down step through what you've sent. A line starting with "\" is an admin
## command (log 0125); the box stays open after one, for the next.
##
## With keys, the log sits bottom left over the key hints. On a touch screen
## it sits top left under your health, with the typing line on top, so
## the phone's keyboard (which covers the bottom half) never hides it; the
## Send and close buttons are big enough for a thumb.
##
## A line starting with "\" turns the chat into the admin terminal (log
## 0138) until it closes: the whole screen, dark and see-through, in a
## fixed-width font, with imsdow, the companion. In the terminal Enter never
## leaves; Esc (or ✕) does, and \bye says goodbye to her first (log 0148).

signal line_entered(text: String)
signal closed

const MAX_LINES := 100
const SHOW_TIME := 10.0  # s a new line stays while the chat is closed
const VISIBLE_LINES := 7
const WIDTH := 480.0
const KEYS_BOTTOM := 76.0  # px from the bottom edge: clear of the key hints
const TOUCH_TOP := 112.0  # px from the top edge: under the health bars
const MAX_HISTORY := 30
const MONO := preload("res://assets/fonts/mono.ttf")
const TERM_MARGIN := 24.0
const TERM_BACK := Color(0.02, 0.05, 0.03, 0.75)  # 25% see-through (log 0142)
const TERM_GREEN := Color(0.49, 1.0, 0.63)
const TERM_TEXT := Color(0.86, 0.93, 0.88)
const TERM_PINK := Color(1.0, 0.72, 0.86)
const TERM_PROMPT := "admin@slice:~$"
const BYE := "\\bye"  # says goodbye to imsdow and closes the terminal; never sent
const HELLO := "\\hello"  # imsdow waves and says hi; never sent (log 0153)
const BYE_TIME := 1.8  # s her goodbye shows before the terminal closes
## Narrower than this, the companion draws smaller.
const TERM_WIDE := 1000.0

var is_open := false
var terminal := false  # the admin terminal look, while a "\" line is open

var _touch := false
var _underground := false
var _column: VBoxContainer
var _panel: PanelContainer
var _panel_box: StyleBoxFlat
var _scroll: ScrollContainer
var _log: VBoxContainer
var _bar: HBoxContainer
var _field: LineEdit
var _send: Button
var _close: Button
var _focus_box: StyleBox
var _backdrop: ColorRect
var _header: Label
var _prompt: Label
var _companion: ConsoleCompanion
var _asked := ""  # the last command sent from the terminal, awaiting its answer
var _goodbye := ""  # her goodbye, once said, so closing doesn't say another
var _ages: Array[float] = []  # s since each log line arrived, like _log's children
var _history: Array[String] = []
var _history_at := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_place()
	_refresh()
	resized.connect(func() -> void:
		if terminal:
			_place())


## Opens the typing line. `text` starts it, e.g. "\" for a command.
func open(text := "") -> void:
	is_open = true
	_field.text = text
	_field.caret_column = text.length()
	_history_at = _history.size()
	if text.begins_with(AdminConsole.ESCAPE):
		_set_terminal(true)
	_refresh()
	_focus_field.call_deferred()
	_scroll_to_end()


func close() -> void:
	if not is_open:
		return
	var leaving_terminal := terminal
	is_open = false
	_field.release_focus()
	_field.text = ""
	_set_terminal(false)
	_refresh()
	if leaving_terminal:
		# Her goodbye stays in the chat log a while after the terminal's gone.
		var line := _goodbye if _goodbye != "" else _companion.goodbye()
		add_said(_companion.display_name(), line)
	_goodbye = ""
	_asked = ""
	closed.emit()


func toggle() -> void:
	if is_open and terminal:
		_focus_field()  # only Esc leaves the terminal
	elif is_open:
		close()
	else:
		open()


## A line someone said, "Name: words".
func add_said(speaker: String, text: String) -> void:
	_add_line("%s: %s" % [speaker, text], "said")


## The server's answer to you (an admin command, "too fast"). May be
## several lines.
func add_notice(text: String) -> void:
	if terminal and _asked != "":
		_companion.reply(_asked, text)
		_asked = ""
	for line in text.split("\n"):
		_add_line(line, "notice")


func set_touch(on: bool) -> void:
	if on == _touch:
		return
	_touch = on
	_place()


## Chalk on the underworld's slate (log 0056), ink elsewhere.
func set_underground(on: bool) -> void:
	if on == _underground:
		return
	_underground = on
	for label in _log.get_children():
		_style_line(label as Label)


func _process(delta: float) -> void:
	for i in _ages.size():
		_ages[i] += delta
	if not is_open:
		var labels := _log.get_children()
		for i in labels.size():
			(labels[i] as Label).modulate.a = clampf(SHOW_TIME - _ages[i], 0.0, 1.0)


## `kind`: "said", "notice" (the server to you) or "echo" (a command you
## typed, in the terminal).
func _add_line(text: String, kind: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta("kind", kind)
	_style_line(label)
	_log.add_child(label)
	_ages.append(0.0)
	while _log.get_child_count() > MAX_LINES:
		var oldest := _log.get_child(0)
		_log.remove_child(oldest)
		oldest.queue_free()
		_ages.pop_front()
	_scroll_to_end()


func _style_line(label: Label) -> void:
	var kind: String = label.get_meta("kind", "said")
	if terminal:
		label.add_theme_font_override("font", MONO)
		label.add_theme_color_override("font_color",
				{"notice": TERM_GREEN, "echo": TERM_PINK}.get(kind, TERM_TEXT))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		label.add_theme_constant_override("outline_size", 3)
		label.add_theme_font_size_override("font_size", 16 if _touch else 14)
		return
	label.remove_theme_font_override("font")
	var notice := kind != "said"
	# Over the world, lines need an outline to read; in the open panel they don't.
	var on_slate := _underground and not is_open
	var ink := Palette.CHALK_LINE if on_slate else Palette.INK
	label.add_theme_color_override("font_color", Color(ink, 0.75) if notice else ink)
	label.add_theme_color_override("font_outline_color", Palette.SLATE_DARK if on_slate else Palette.PARCHMENT_LIGHT)
	label.add_theme_constant_override("outline_size", 0 if is_open else 5)
	label.add_theme_font_size_override("font_size", 18 if _touch else 15)


func _scroll_to_end() -> void:
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = TERM_BACK
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)
	_companion = ConsoleCompanion.new()
	_companion.font = MONO
	_companion.color = TERM_PINK
	add_child(_companion)

	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", 6)
	add_child(_column)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_box = StyleBoxFlat.new()
	_panel_box.set_corner_radius_all(4)
	_panel_box.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", _panel_box)
	_header = Label.new()
	_header.text = "SLICE admin console v%s   \\help for commands   Esc to close" \
			% ProjectSettings.get_setting("application/config/version", "?")
	_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header.add_theme_font_override("font", MONO)
	_header.add_theme_color_override("font_color", TERM_GREEN)
	_header.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_header.add_theme_constant_override("outline_size", 3)
	_column.add_child(_header)
	_column.add_child(_panel)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_panel.add_child(_scroll)
	_log = VBoxContainer.new()
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.size_flags_vertical = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.add_theme_constant_override("separation", 2)
	_scroll.add_child(_log)

	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 6)
	_column.add_child(_bar)
	_prompt = Label.new()
	_prompt.text = TERM_PROMPT
	_prompt.add_theme_font_override("font", MONO)
	_prompt.add_theme_color_override("font_color", TERM_GREEN)
	_bar.add_child(_prompt)
	_field = LineEdit.new()
	_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field.max_length = PlayerChat.MAX_LENGTH
	_field.placeholder_text = "Say something"
	_field.context_menu_enabled = false
	_field.keep_editing_on_text_submit = true
	var focus_box: StyleBoxFlat = (get_theme_stylebox("normal", "LineEdit") as StyleBoxFlat).duplicate() \
			if get_theme_stylebox("normal", "LineEdit") is StyleBoxFlat else StyleBoxFlat.new()
	focus_box.bg_color = Palette.PARCHMENT_LIGHT  # the theme's see-through focus is unreadable over the world
	_field.add_theme_stylebox_override("focus", focus_box)
	_focus_box = focus_box
	_field.text_submitted.connect(_on_submitted)
	_field.text_changed.connect(func(text: String) -> void:
		_companion.poke()  # someone's here: she won't doze off
		if text.begins_with(AdminConsole.ESCAPE):
			_set_terminal(true))
	_field.gui_input.connect(_on_field_input)
	_field.focus_exited.connect(_on_focus_lost)
	_bar.add_child(_field)
	_send = Button.new()
	_send.text = "Send"
	_send.focus_mode = Control.FOCUS_NONE  # keeps the keyboard up
	_send.pressed.connect(func() -> void: _on_submitted(_field.text))
	_bar.add_child(_send)
	_close = Button.new()
	_close.text = "✕"
	_close.focus_mode = Control.FOCUS_NONE
	_close.pressed.connect(close)
	_bar.add_child(_close)


## Where the chat sits, for keys or touch.
func _place() -> void:
	var lines_height := VISIBLE_LINES * (24.0 if _touch else 20.0) + 16.0
	_scroll.custom_minimum_size = Vector2(0, lines_height)
	_column.custom_minimum_size.x = WIDTH
	var row_height := 52.0 if _touch else 36.0
	_field.custom_minimum_size.y = row_height
	_send.custom_minimum_size = Vector2(80, row_height)
	_close.custom_minimum_size = Vector2(row_height, row_height)
	_field.add_theme_font_size_override("font_size", 20 if _touch else 16)
	_send.visible = _touch
	_close.visible = _touch
	# Touch: the typing line on top, out of the keyboard's way.
	_column.move_child(_bar, 1 if _touch else -1)  # after the terminal header
	_header.add_theme_font_size_override("font_size", 16 if _touch else 14)
	_prompt.add_theme_font_size_override("font_size", 20 if _touch else 16)
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL if terminal else Control.SIZE_FILL
	var height := lines_height + 16.0 + row_height + 6.0
	if terminal:
		var wide := size.x >= TERM_WIDE
		# Wide: up to 40% of the width beside the log. Narrow: over the log's empty top.
		_companion.fit(Vector2(size.x * 0.4, size.y * 0.8) if wide else Vector2(size.x * 0.62, size.y * 0.42))
		# Room on the right for her, unless the screen's too narrow to share.
		var right := TERM_MARGIN + (_companion.get_combined_minimum_size().x + TERM_MARGIN if wide else 0.0)
		var fig := _companion.get_combined_minimum_size()
		_companion.set_anchors_preset(Control.PRESET_TOP_LEFT)
		# Wide: bottom right, beside the log. Narrow: top right inside the
		# log, which fills from the bottom up.
		_companion.position = size - fig - Vector2(TERM_MARGIN, TERM_MARGIN) if wide \
				else Vector2(size.x - fig.x - TERM_MARGIN - 8.0, TERM_MARGIN + _header.get_combined_minimum_size().y
						+ (row_height + 6.0 if _touch else 0.0) + 14.0)
		_companion.size = fig
		_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_column.offset_left = TERM_MARGIN
		_column.offset_top = TERM_MARGIN
		_column.offset_right = -right
		_column.offset_bottom = -TERM_MARGIN
	elif _touch:
		_column.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_column.position = Vector2(Hud.MARGIN, TOUCH_TOP)
	else:
		_column.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		_column.offset_left = Hud.MARGIN
		_column.offset_top = -KEYS_BOTTOM - height
		_column.offset_bottom = -KEYS_BOTTOM
	if not terminal:
		_column.size = Vector2(WIDTH, height)
	for label in _log.get_children():
		_style_line(label as Label)


func _refresh() -> void:
	_bar.visible = is_open
	_backdrop.visible = terminal
	_companion.visible = terminal
	_header.visible = terminal
	_prompt.visible = terminal
	_panel_box.bg_color = Color(Palette.PARCHMENT, 0.92) if is_open and not terminal else Color.TRANSPARENT
	_panel_box.border_color = Color(TERM_GREEN, 0.35) if terminal else Palette.INK_FADED
	_panel_box.set_border_width_all(1 if is_open else 0)
	# Open, the log takes the mouse so it can scroll; closed, clicks pass through.
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP if is_open else Control.MOUSE_FILTER_IGNORE
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS if is_open else Control.MOUSE_FILTER_IGNORE
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if is_open else ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var labels := _log.get_children()
	for i in labels.size():
		_style_line(labels[i] as Label)
		if is_open:
			(labels[i] as Label).modulate.a = 1.0


func _on_submitted(text: String) -> void:
	var line := text.strip_edges()
	if line == "":
		if terminal:
			_focus_field.call_deferred()  # Enter never leaves the terminal
		else:
			close()
		return
	if terminal:
		_add_line("%s %s" % [TERM_PROMPT, line], "echo")
		if line.to_lower() == BYE:
			_say_bye()
			return
		if line.to_lower() == HELLO:
			_field.text = ""
			_companion.greet()
			_focus_field.call_deferred()
			return
		_companion.command(line)
		# A command gets an answer (a notice) for her to react to; chat doesn't.
		_asked = line if line.begins_with(AdminConsole.ESCAPE) else ""
	line_entered.emit(line)
	if _history.is_empty() or _history[-1] != line:
		_history.append(line)
		if _history.size() > MAX_HISTORY:
			_history.pop_front()
	_history_at = _history.size()
	if line.begins_with(AdminConsole.ESCAPE) or terminal:
		_field.text = ""  # stay open for the next command
		_focus_field.call_deferred()
	else:
		close()


func _on_field_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	match key.keycode:
		KEY_ESCAPE:
			close()
		KEY_TAB:
			pass  # keep focus here
		KEY_UP:
			_step_history(-1)
		KEY_DOWN:
			_step_history(1)
		_:
			return
	_field.accept_event()


## Focused and editing (Godot 4.4+ needs both to type), which also brings
## up a phone's keyboard.
func _focus_field() -> void:
	if is_open:
		_field.grab_focus()
		_field.edit()


func _step_history(step: int) -> void:
	if _history.is_empty():
		return
	_history_at = clampi(_history_at + step, 0, _history.size())
	_field.text = _history[_history_at] if _history_at < _history.size() else ""
	_field.caret_column = _field.text.length()


## With keys, clicking away from the line closes the chat. On a touch
## screen it stays open (a tap to scroll the log can take focus away); the
## close button or Chat closes it. The terminal takes focus back: only Esc
## (or ✕) leaves it.
func _on_focus_lost() -> void:
	if is_open and terminal:
		_focus_field.call_deferred()  # only Esc leaves the terminal
	elif is_open and not _touch:
		close()


## The admin terminal look on or off (log 0138).
func _set_terminal(on: bool) -> void:
	if on == terminal:
		return
	terminal = on
	if on:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0, 0, 0, 0.35)
		box.border_color = Color(TERM_GREEN, 0.5)
		box.border_width_bottom = 1
		box.set_content_margin_all(6)
		for state in ["normal", "focus"]:
			_field.add_theme_stylebox_override(state, box)
		_field.add_theme_font_override("font", MONO)
		_field.add_theme_color_override("font_color", TERM_TEXT)
		_field.add_theme_color_override("caret_color", TERM_GREEN)
		_field.add_theme_color_override("font_placeholder_color", Color(TERM_TEXT, 0.4))
		_field.placeholder_text = "\\help"
	else:
		_field.remove_theme_stylebox_override("normal")
		_field.add_theme_stylebox_override("focus", _focus_box)
		for color in ["font_color", "caret_color", "font_placeholder_color"]:
			_field.remove_theme_color_override(color)
		_field.remove_theme_font_override("font")
		_field.placeholder_text = "Say something"
	_refresh()
	if on:
		_companion.hello()
	# Next frame: her new size is known by then, and it's safe while the
	# HUD is being torn down (closing on lost focus).
	_place.call_deferred()


## \bye: imsdow says goodbye and waves, then the terminal closes.
func _say_bye() -> void:
	_field.text = ""
	_goodbye = _companion.goodbye()
	_field.editable = false
	await get_tree().create_timer(BYE_TIME).timeout
	_field.editable = true
	if is_open and terminal:
		close()
	_goodbye = ""

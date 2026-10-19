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

signal line_entered(text: String)
signal closed

const MAX_LINES := 100
const SHOW_TIME := 10.0  # s a new line stays while the chat is closed
const VISIBLE_LINES := 7
const WIDTH := 480.0
const KEYS_BOTTOM := 76.0  # px from the bottom edge: clear of the key hints
const TOUCH_TOP := 112.0  # px from the top edge: under the health bars
const MAX_HISTORY := 30

var is_open := false

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
var _ages: Array[float] = []  # s since each log line arrived, like _log's children
var _history: Array[String] = []
var _history_at := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_place()
	_refresh()


## Opens the typing line. `text` starts it, e.g. "\" for a command.
func open(text := "") -> void:
	is_open = true
	_field.text = text
	_field.caret_column = text.length()
	_history_at = _history.size()
	_refresh()
	_focus_field.call_deferred()
	_scroll_to_end()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_field.release_focus()
	_field.text = ""
	_refresh()
	closed.emit()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


## A line someone said, "Name: words".
func add_said(speaker: String, text: String) -> void:
	_add_line("%s: %s" % [speaker, text], false)


## The server's answer to you (an admin command, "too fast"). May be
## several lines.
func add_notice(text: String) -> void:
	for line in text.split("\n"):
		_add_line(line, true)


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


func _add_line(text: String, notice: bool) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta("notice", notice)
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
	var notice: bool = label.get_meta("notice", false)
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
	_field.text_submitted.connect(_on_submitted)
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
	_column.move_child(_bar, 0 if _touch else 1)
	var height := lines_height + 16.0 + row_height + 6.0
	if _touch:
		_column.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_column.position = Vector2(Hud.MARGIN, TOUCH_TOP)
	else:
		_column.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		_column.offset_left = Hud.MARGIN
		_column.offset_top = -KEYS_BOTTOM - height
		_column.offset_bottom = -KEYS_BOTTOM
	_column.size = Vector2(WIDTH, height)
	for label in _log.get_children():
		_style_line(label as Label)


func _refresh() -> void:
	_bar.visible = is_open
	_panel_box.bg_color = Color(Palette.PARCHMENT, 0.92) if is_open else Color.TRANSPARENT
	_panel_box.border_color = Palette.INK_FADED
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
		close()
		return
	line_entered.emit(line)
	if _history.is_empty() or _history[-1] != line:
		_history.append(line)
		if _history.size() > MAX_HISTORY:
			_history.pop_front()
	_history_at = _history.size()
	if line.begins_with(AdminConsole.ESCAPE):
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
## close button or Chat closes it.
func _on_focus_lost() -> void:
	if is_open and not _touch:
		close()

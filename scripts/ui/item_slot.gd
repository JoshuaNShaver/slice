class_name ItemSlot
extends Panel
## One inventory square: draws its item's icon and shows its description on
## hover (design log 0036). Items drag and drop between slots, and a
## double-click (or double tap) uses one (design logs 0043, 0131).

signal double_clicked
signal right_clicked
## Another slot's drag data was dropped here.
signal dropped(data: Dictionary)

const SIZE := 48.0
## Two presses this close together are a double-click. Timed here because
## touch (mouse emulated from taps, the web build) doesn't reliably mark
## the second tap as a double-click.
const DOUBLE_TAP_TIME := 400  # ms

## Shown faded when the slot is empty, e.g. "Eye" in the equipment panel.
var placeholder := ""
## Added to the tooltip under the item's description.
var hint := "":
	set(value):
		if value != hint:
			hint = value
			_update_tooltip()
var item := "":
	set(value):
		if value == item:
			return
		item = value
		_update_tooltip()
		queue_redraw()
## Where this slot's item comes from when dragged, e.g. {"bag": 3}. Empty
## means the slot can't be dragged from.
var drag_source := {}
## Optional check for a drop: takes the drag data, returns whether it fits.
var accepts := Callable()
var _last_press := -DOUBLE_TAP_TIME  # ms, Time.get_ticks_msec()


func _init(placeholder_text := "", hint_text := "") -> void:
	placeholder = placeholder_text
	hint = hint_text
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _update_tooltip() -> void:
	tooltip_text = "" if item == "" else Gear.describe(item) + ("\n" + hint if hint != "" else "")


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or item == "":
		return
	if click.button_index == MOUSE_BUTTON_LEFT:
		var now := Time.get_ticks_msec()
		if click.double_click or now - _last_press <= DOUBLE_TAP_TIME:
			_last_press = -DOUBLE_TAP_TIME  # a third press starts over
			double_clicked.emit()
			accept_event()
		else:
			_last_press = now
	elif click.button_index == MOUSE_BUTTON_RIGHT:
		right_clicked.emit()
		accept_event()


func _get_drag_data(_at: Vector2) -> Variant:
	if item == "" or drag_source.is_empty():
		return null
	var dragged := item
	var preview := Control.new()
	preview.draw.connect(func() -> void: Gear.draw_icon(preview, dragged, Vector2.ZERO, 0.85))
	set_drag_preview(preview)
	modulate.a = 0.4  # the item is "lifted" out of this slot
	var data := drag_source.duplicate()
	data["item"] = item
	return data


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.has("item")):
		return false
	var source := (data as Dictionary).duplicate()
	source.erase("item")
	if source == drag_source:
		return false
	return accepts.is_null() or accepts.call(data)


func _drop_data(_at: Vector2, data: Variant) -> void:
	dropped.emit(data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate.a = 1.0
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT:
		queue_redraw()  # the drop outline


func _draw() -> void:
	if item != "":
		Gear.draw_icon(self, item, size / 2.0)
	elif placeholder != "":
		var font := get_theme_default_font()
		draw_string(font, Vector2(0, size.y / 2.0 + 5), placeholder, HORIZONTAL_ALIGNMENT_CENTER,
				size.x, 12, Palette.INK_FADED)
	if get_viewport().gui_is_dragging() and _can_drop_data(Vector2.ZERO, get_viewport().gui_get_drag_data()) \
			and get_global_rect().has_point(get_global_mouse_position()):
		draw_rect(Rect2(Vector2.ZERO, size).grow(-2), Palette.INK_FADED, false, 2.0)

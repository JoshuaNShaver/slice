class_name DropZone
extends Panel
## Beside the bag on a touch screen (design log 0131): drag a bag item
## here to drop it on the ground, where right-click would on a desktop.

## A bag slot's item was dropped here.
signal dropped(bag_index: int)


func _init() -> void:
	custom_minimum_size = Vector2(ItemSlot.SIZE, ItemSlot.SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Drag an item here: drop it on the ground"


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).has("bag")


func _drop_data(_at: Vector2, data: Variant) -> void:
	dropped.emit(int(data.bag))


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT \
			or what == NOTIFICATION_DRAG_BEGIN or what == NOTIFICATION_DRAG_END:
		queue_redraw()


## A down arrow onto a ground line; outlined while a drag hovers over it.
func _draw() -> void:
	var c := size / 2.0
	var ink := Palette.INK
	draw_line(c + Vector2(0, -14), c + Vector2(0, 6), ink, 2.0)
	draw_polyline(PackedVector2Array([c + Vector2(-7, -1), c + Vector2(0, 6), c + Vector2(7, -1)]), ink, 2.0)
	draw_line(c + Vector2(-13, 13), c + Vector2(13, 13), ink, 2.0)
	var viewport := get_viewport()
	if viewport.gui_is_dragging() and _can_drop_data(Vector2.ZERO, viewport.gui_get_drag_data()) \
			and get_global_rect().has_point(get_global_mouse_position()):
		draw_rect(Rect2(Vector2.ZERO, size).grow(-2), Palette.INK_FADED, false, 2.0)

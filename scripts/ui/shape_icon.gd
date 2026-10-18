class_name ShapeIcon
extends Control
## Draws a family's shape in chalk with an ink outline, wearing its gear
## (Gear.draw_shape), the same as in the world.

var sides := 3:
	set(value):
		sides = value
		queue_redraw()
var kind := "regular":
	set(value):
		kind = value
		queue_redraw()
var apex := 0:
	set(value):
		apex = value
		queue_redraw()
var equipped := PackedStringArray():  # indexed like Gear.SLOTS
	set(value):
		if value == equipped:
			return
		equipped = value
		queue_redraw()


func _init(n_sides := 3, shape_kind := "regular", min_size := 64.0, apex_deg := 0,
		worn := PackedStringArray()) -> void:
	sides = n_sides
	kind = shape_kind
	apex = apex_deg
	equipped = worn
	custom_minimum_size = Vector2(min_size, min_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.42
	var pts := ShapeGeometry.points(sides, kind, radius, apex)
	Gear.draw_shape(self, pts, sides, equipped, size / 2.0)

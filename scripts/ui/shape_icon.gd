class_name ShapeIcon
extends Control
## Draws a family's shape in chalk with an ink outline.

var sides := 3:
	set(value):
		sides = value
		queue_redraw()
var kind := "regular":
	set(value):
		kind = value
		queue_redraw()


func _init(n_sides := 3, shape_kind := "regular", min_size := 64.0) -> void:
	sides = n_sides
	kind = shape_kind
	custom_minimum_size = Vector2(min_size, min_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.42
	var pts := ShapeGeometry.points(sides, kind, radius)
	var center := size / 2.0
	for i in pts.size():
		pts[i] += center
	draw_colored_polygon(pts, Palette.chalk_for_sides(sides))
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Palette.INK, 2.5, true)

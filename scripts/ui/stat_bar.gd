class_name StatBar
extends Control
## A labeled meter in ink and chalk: "Health  150 / 200".

var label := ""
var value := 0.0
var max_value := 1.0
var fill := Palette.HEALTH
## A thin bar with no text, like the XP bar.
var compact := false:
	set(value):
		compact = value
		custom_minimum_size.y = 8.0 if compact else 24.0
		queue_redraw()


func _init(bar_label: String, fill_color: Color) -> void:
	label = bar_label
	fill = fill_color
	custom_minimum_size = Vector2(120, 24)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_values(new_value: float, new_max: float) -> void:
	if new_value == value and new_max == max_value:
		return
	value = new_value
	max_value = new_max
	queue_redraw()


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	draw_rect(box, Palette.PARCHMENT_LIGHT)
	var ratio := clampf(value / maxf(max_value, 0.001), 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * ratio, size.y)), fill)
	draw_rect(box, Palette.INK, false, 1.5 if compact else 2.0)
	if compact:
		return
	var font := get_theme_default_font()
	var font_size := 15
	var y := (size.y + font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
	draw_string(font, Vector2(8, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.INK)
	var amount := "%d / %d" % [floori(value), roundi(max_value)]
	draw_string(font, Vector2(0, y), amount, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 8, font_size, Palette.INK)

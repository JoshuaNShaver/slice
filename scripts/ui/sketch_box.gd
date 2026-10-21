class_name SketchBox
extends StyleBox
## A box drawn by hand in pencil and ink (log 0185): the main menu's
## buttons, fields and panels. Its lines are seeded by its size, so a box
## looks the same every frame, and two boxes of different sizes differ.

## The paper inside.
@export var fill_color := Palette.PARCHMENT_LIGHT
@export var ink := Palette.INK
@export var line_width := 1.6
## How far a line runs past a corner.
@export var overshoot := 4.0
## Torn paper edges, for panels; buttons are cut straight.
@export var torn := false
## Pencil shading inside the bottom and right edges.
@export var shaded := true
## Draws the fill a little in from the edges, so a pressed button looks
## pushed in.
@export var inset := 0.0
@export var seed := 0


static func make(fill: Color, ink_color: Color, padding := 8.0) -> SketchBox:
	var box := SketchBox.new()
	box.fill_color = fill
	box.ink = ink_color
	box.content_margin_left = padding + 4.0
	box.content_margin_right = padding + 4.0
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box


func _draw(ci: RID, rect: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, roundi(rect.size.x), roundi(rect.size.y)])
	var inner := rect.grow(-inset)
	var pts := Sketch.torn_rect(inner, rng) if torn else Sketch.rough_rect(inner, rng, 1.0)
	if fill_color.a > 0.0:
		Sketch.fill(ci, pts, fill_color)
	if shaded and fill_color.a > 0.0:
		var shade := Color(ink, ink.a * 0.18)
		var depth := 14.0 if torn else 7.0
		Sketch.shade_edge(ci, Vector2(inner.position.x + 6, inner.end.y - 3), inner.end - Vector2(6, 3),
				Vector2.UP, shade, rng, 5.0, depth)
		Sketch.shade_edge(ci, Vector2(inner.end.x - 3, inner.position.y + 6), inner.end - Vector2(3, 6),
				Vector2.LEFT, shade, rng, 5.0, depth)
	if ink.a <= 0.0:
		return
	if torn:
		Sketch.ragged_outline(ci, pts, ink, line_width + 0.4, rng)
	else:
		Sketch.outline(ci, pts, ink, line_width, rng, 2, overshoot, 0.8)

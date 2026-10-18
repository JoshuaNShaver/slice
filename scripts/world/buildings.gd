class_name Buildings
## Drawing helpers for houses and halls. Buildings are scenery: shapes pass
## in front of them.
##
## Overworld houses follow the book's law (design log 0060): a regular
## pentagon, roof to the north, the men's door on the east, the women's
## smaller door on the west, and no windows. Underworld houses break it
## (design log 0059): crooked outlines, even triangles and squares.

## Corners of a regular pentagon standing on its base, apex up, unit
## circumradius, centered on the circumcenter.
const _PENTAGON: Array[Vector2] = [
	Vector2(0.0, -1.0),  # roof peak
	Vector2(0.951, -0.309),  # east eave
	Vector2(0.588, 0.809),  # east foot
	Vector2(-0.588, 0.809),  # west foot
	Vector2(-0.951, -0.309),  # west eave
]


## A lawful pentagon house standing on `base` (the middle of its floor),
## `width` across at the eaves.
static func draw_house(c: CanvasItem, base: Vector2, width: float, fill: Color, ink: Color,
		label := "", label_color := Color.TRANSPARENT) -> void:
	var r := width / 1.902
	var center := base - Vector2(0, 0.809 * r)
	var pts := PackedVector2Array()
	for p in _PENTAGON:
		pts.append(center + p * r)
	c.draw_colored_polygon(pts, fill)
	# The roof: the two northern sides, shaded with short strokes.
	var shade := Color(ink, 0.22)
	for side in [[pts[4], pts[0]], [pts[0], pts[1]]]:
		var a: Vector2 = side[0]
		var b: Vector2 = side[1]
		var count := int(a.distance_to(b) / 12.0)
		for k in count:
			var p := a.lerp(b, (k + 0.5) / count)
			c.draw_line(p, p + Vector2(0, 14), shade, 1.5)
	_outline(c, pts, ink, 2.5)
	# Men's door on the east wall, women's narrower one on the west.
	_door(c, pts[1], pts[2], center, 0.5, 0.95, ink, fill)
	_door(c, pts[4], pts[3], center, 0.7, 0.95, ink, fill)
	if label != "":
		var font := ThemeDB.fallback_font
		var color := label_color if label_color.a > 0.0 else ink
		c.draw_string(font, Vector2(center.x - 150, center.y - r - 14), label,
				HORIZONTAL_ALIGNMENT_CENTER, 300, 17, color)


## The east door's middle, where you stand to go in.
static func east_door(base: Vector2, width: float) -> Vector2:
	var r := width / 1.902
	var center := base - Vector2(0, 0.809 * r)
	return center + (_PENTAGON[1] * r).lerp(_PENTAGON[2] * r, 0.75)


## An unlawful house: any outline, given as offsets from `base` (its floor
## middle, y up is negative). Gets a door at a random-looking spot.
static func draw_crooked(c: CanvasItem, base: Vector2, outline: Array, fill: Color, ink: Color) -> void:
	var pts := PackedVector2Array()
	for p: Vector2 in outline:
		pts.append(base + p)
	c.draw_colored_polygon(pts, fill)
	var shade := Color(ink, 0.18)
	# Cross-hatching: these walls are patched.
	var top := INF
	var left := INF
	var right := -INF
	for p in pts:
		top = minf(top, p.y)
		left = minf(left, p.x)
		right = maxf(right, p.x)
	var x := left + 10.0
	while x < right - 10.0:
		var y := top + fposmod(x * 1.7, 40.0) + 16.0
		if Geometry2D.is_point_in_polygon(Vector2(x, y), pts) \
				and Geometry2D.is_point_in_polygon(Vector2(x + 10, y + 10), pts):
			c.draw_line(Vector2(x, y), Vector2(x + 10, y + 10), shade, 1.5)
			c.draw_line(Vector2(x + 10, y), Vector2(x, y + 10), shade, 1.5)
		x += 23.0
	_outline(c, pts, ink, 2.5)
	# Door: a lopsided gap at the foot.
	var door := PackedVector2Array([
		base + Vector2(-14, 0), base + Vector2(-12, -44), base + Vector2(12, -40), base + Vector2(15, 0)])
	c.draw_colored_polygon(door, Color(ink, 0.55))
	c.draw_polyline(door, ink, 2.0, true)


## A great hall for the Circles: a dome on a colonnade (design log 0063).
static func draw_temple(c: CanvasItem, base: Vector2, width: float, fill: Color, ink: Color) -> void:
	var height := width * 0.32
	var body := Rect2(base.x - width / 2.0, base.y - height, width, height)
	c.draw_rect(body, fill)
	# Columns.
	var columns := 9
	for i in columns:
		var x := body.position.x + width * (i + 0.5) / columns
		c.draw_line(Vector2(x, body.position.y + 10), Vector2(x, base.y), Color(ink, 0.5), 3.0)
	c.draw_rect(body, ink, false, 3.0)
	# The dome, a half 40-gon: as near a circle as a polygon gets.
	var dome := PackedVector2Array()
	var r := width * 0.38
	var top := Vector2(base.x, body.position.y)
	for i in 21:
		dome.append(top + Vector2.from_angle(PI + PI * i / 20.0) * r)
	c.draw_colored_polygon(dome, fill.lightened(0.15))
	c.draw_polyline(dome, ink, 3.0, true)
	c.draw_arc(top + Vector2(0, -r - 26), 18, 0, TAU, 32, ink, 3.0, true)
	# The sealed sanctum door.
	var door := Rect2(base.x - 34, base.y - 110, 68, 110)
	c.draw_rect(door, Color(ink, 0.3))
	c.draw_rect(door, ink, false, 2.5)
	c.draw_line(door.position + Vector2(34, 0), door.end - Vector2(34, 0), ink, 2.0)


static func _outline(c: CanvasItem, pts: PackedVector2Array, ink: Color, width: float) -> void:
	var line := pts.duplicate()
	line.append(pts[0])
	c.draw_polyline(line, ink, width, true)


## A door cut into the wall from a to b, between fractions t0 and t1 of it.
static func _door(c: CanvasItem, a: Vector2, b: Vector2, center: Vector2, t0: float, t1: float,
		ink: Color, fill: Color) -> void:
	var p0 := a.lerp(b, t0)
	var inward := (b - a).orthogonal().normalized()
	if inward.dot(center - p0) < 0.0:
		inward = -inward
	var p1 := a.lerp(b, t1)
	var door := PackedVector2Array([p0, p1, p1 + inward * 12.0, p0 + inward * 12.0])
	c.draw_colored_polygon(door, fill.darkened(0.35))
	c.draw_polyline(PackedVector2Array([p0, p0 + inward * 12.0, p1 + inward * 12.0, p1]), ink, 2.0, true)

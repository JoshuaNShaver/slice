class_name Buildings
## Drawing helpers for houses and halls. Buildings are scenery: shapes pass
## in front of them.
##
## Overworld houses follow the book's law (design logs 0060, 0187): a
## regular pentagon, roof to the north, the men's large door on the west,
## the women's small door on the east, and no windows. Underworld houses break it
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
## `width` across at the eaves, its walls open to show the rooms, after
## the book's plan of the narrator's house (logs 0187, 0188), with level
## floors for a side view: the Hall behind the men's (west) door, the
## Sons' cells climbing under the west roof, a wall down from the peak,
## the Bedroom under the east roof, the Grandsons and the Wife's apartment
## on a middle floor, the Cellar and the Servants' room on the ground,
## behind the women's (east) door. Both doors reach the ground and are
## big enough to roll through. Residents stand on ROOMS' floors.
static func draw_house(c: CanvasItem, base: Vector2, width: float, fill: Color, ink: Color,
		label := "", label_color := Color.TRANSPARENT) -> void:
	var at := func(unit: Vector2) -> Vector2: return house_point(base, width, unit)
	var pts := PackedVector2Array()
	for p in _PENTAGON:
		pts.append(at.call(p))
	c.draw_colored_polygon(pts, fill)
	var cellar := PackedVector2Array([at.call(Vector2(0.0, 0.12)), at.call(Vector2(0.2, 0.12)),
			at.call(Vector2(0.2, 0.809)), at.call(Vector2(0.0, 0.809))])
	Gear.draw_hatch(c, cellar, [[45.0], 9.0], 1.0, Color(ink, 0.12))
	# The roof: the two northern sides, shaded with short strokes.
	var shade := Color(ink, 0.22)
	for side in [[pts[4], pts[0]], [pts[0], pts[1]]]:
		var a: Vector2 = side[0]
		var b: Vector2 = side[1]
		var count := int(a.distance_to(b) / 12.0)
		for k in count:
			var p := a.lerp(b, (k + 0.5) / count)
			c.draw_line(p, p + Vector2(0, 14), shade, 1.5)
	var inner := maxf(width / 170.0, 1.5)
	var wall := Color(ink, 0.75)
	for seg: Array in INNER_WALLS:
		c.draw_line(at.call(seg[0]), at.call(seg[1]), wall, inner, true)
	# The outer walls: the roof and floor whole, the side walls open at
	# their doors, from partway down to the ground.
	c.draw_polyline(PackedVector2Array([pts[4], pts[0], pts[1]]), ink, 2.5, true)
	c.draw_line(pts[4], pts[4].lerp(pts[3], MEN_DOOR), ink, 2.5, true)
	c.draw_line(pts[1], pts[1].lerp(pts[2], WOMEN_DOOR), ink, 2.5, true)
	c.draw_line(pts[2], pts[3], ink, 2.5, true)
	if label != "":
		var font := ThemeDB.fallback_font
		var color := label_color if label_color.a > 0.0 else ink
		var top: Vector2 = at.call(Vector2(0.0, -1.0))
		c.draw_string(font, top + Vector2(-150, -14), label, HORIZONTAL_ALIGNMENT_CENTER, 300, 17, color)


## Where the rooms' residents stand (draw_house), on the unit pentagon:
## room -> spots on its floor, each x and the floor's y.
const ROOMS := {
	"hall": [Vector2(-0.06, 0.809)],
	"sons": [Vector2(-0.78, -0.08), Vector2(-0.575, -0.24), Vector2(-0.345, -0.4), Vector2(-0.115, -0.56)],
	"bedroom": [Vector2(0.3, -0.18)],
	"grandsons": [Vector2(0.095, 0.12), Vector2(0.285, 0.12)],
	"wife": [Vector2(0.6, 0.12)],
	"servants": [Vector2(0.3, 0.809), Vector2(0.4, 0.809), Vector2(0.5, 0.809)],
}

## The house's inner walls on the unit pentagon, as [from, to].
const INNER_WALLS: Array = [
	# The Sons' cells, each floor a step up under the west roof, walled to it.
	[Vector2(-0.877, -0.08), Vector2(-0.69, -0.08)],
	[Vector2(-0.69, -0.08), Vector2(-0.69, -0.499)],
	[Vector2(-0.69, -0.24), Vector2(-0.46, -0.24)],
	[Vector2(-0.46, -0.24), Vector2(-0.46, -0.666)],
	[Vector2(-0.46, -0.4), Vector2(-0.23, -0.4)],
	[Vector2(-0.23, -0.4), Vector2(-0.23, -0.833)],
	[Vector2(-0.23, -0.56), Vector2(0.0, -0.56)],
	# Down from the peak: the Hall's east wall, with doorways to the
	# Grandsons and the Cellar.
	[Vector2(0.0, -1.0), Vector2(0.0, -0.12)],
	[Vector2(0.0, 0.05), Vector2(0.0, 0.45)],
	[Vector2(0.0, 0.62), Vector2(0.0, 0.809)],
	# The Bedroom's floor, then the middle floor.
	[Vector2(0.0, -0.18), Vector2(0.909, -0.18)],
	[Vector2(0.0, 0.12), Vector2(0.812, 0.12)],
	# Grandsons | Grandsons | the Wife's apartment (a doorway at the bottom).
	[Vector2(0.19, 0.12), Vector2(0.19, -0.18)],
	[Vector2(0.38, -0.18), Vector2(0.38, 0.0)],
	# Cellar | Servants.
	[Vector2(0.2, 0.12), Vector2(0.2, 0.809)],
]

## Where each door starts down its wall, from the eave; it runs to the
## ground.
const MEN_DOOR := 0.5
const WOMEN_DOOR := 0.55


## The men's (west) door's middle, where you stand to go in.
static func men_door(base: Vector2, width: float) -> Vector2:
	return house_point(base, width, _PENTAGON[4].lerp(_PENTAGON[3], 0.75))


## A point given on the unit pentagon (_PENTAGON's frame: circumradius 1,
## centered) placed on a house standing on `base`, `width` across.
static func house_point(base: Vector2, width: float, unit: Vector2) -> Vector2:
	var r := width / 1.902
	return base - Vector2(0, 0.809 * r) + unit * r


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

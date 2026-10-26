class_name Buildings
## Drawing helpers for houses and halls. Houses are solid (House, design
## log 0222); this draws them, for House and the menu's picture.
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
## floors for a side view (log 0222): the Hall behind the men's (west)
## door, tall, with treads climbing it; the Cellar and the Servants' room
## on the ground; the Grandsons and the Wife's apartment on the middle
## floor; the Bedroom under the east roof and the Sons' cells climbing
## under the west roof. The women's (east) door is a slit at the foot of
## the wall, too low for any polygon (a woman is a line).
## `solid` draws every wall and floor at its true thickness (wall_thickness),
## as a House's body has them; otherwise in fine lines (the menu's picture).
static func draw_house(c: CanvasItem, base: Vector2, width: float, fill: Color, ink: Color,
		label := "", label_color := Color.TRANSPARENT, solid := false) -> void:
	var at := func(unit: Vector2) -> Vector2: return house_point(base, width, unit)
	var r := width / 1.902
	var pts := PackedVector2Array()
	for p in _PENTAGON:
		pts.append(at.call(p))
	c.draw_colored_polygon(pts, fill)
	var cellar := PackedVector2Array([at.call(Vector2(0.0, MIDDLE)), at.call(Vector2(0.2, MIDDLE)),
			at.call(Vector2(0.2, GROUND)), at.call(Vector2(0.0, GROUND))])
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
	var inner := wall_thickness(r, false) if solid else maxf(width / 170.0, 1.5)
	var outer := wall_thickness(r, true) if solid else 2.5
	var wall := ink if solid else Color(ink, 0.75)
	for seg: Array in INNER_WALLS:
		c.draw_line(at.call(seg[0]), at.call(seg[1]), wall, inner, not solid)
	for seg: Array in outer_walls(r):
		c.draw_line(at.call(seg[0]), at.call(seg[1]), ink, outer, not solid)
	if label != "":
		var font := ThemeDB.fallback_font
		var color := label_color if label_color.a > 0.0 else ink
		var top: Vector2 = at.call(Vector2(0.0, -1.0))
		c.draw_string(font, top + Vector2(-150, -14), label, HORIZONTAL_ALIGNMENT_CENTER, 300, 17, color)


## A House's walls and floors, px thick, for a house of circumradius `r`.
static func wall_thickness(r: float, outer: bool) -> float:
	return r * (0.04 if outer else 0.03)


## The house's outer walls on the unit pentagon, as [from, to]: the roof
## and floor whole, the west wall open below the men's door, the east wall
## open only by the women's slit (WOMEN_SLIT px, so it depends on `r`).
static func outer_walls(r: float) -> Array:
	var slit := WOMEN_SLIT / r
	var east_door := (GROUND - slit - _PENTAGON[1].y) / (_PENTAGON[2].y - _PENTAGON[1].y)
	return [
		[_PENTAGON[4], _PENTAGON[0]],
		[_PENTAGON[0], _PENTAGON[1]],
		[_PENTAGON[4], _PENTAGON[4].lerp(_PENTAGON[3], MEN_DOOR)],
		[_PENTAGON[1], _PENTAGON[1].lerp(_PENTAGON[2], east_door)],
		[_PENTAGON[2], _PENTAGON[3]],
	]


## Floor heights on the unit pentagon (y grows down): the ground, the
## middle floor, the Bedroom's.
const GROUND := 0.809
const MIDDLE := 0.2
const UPPER := -0.24

## Where the rooms' residents stand (draw_house), on the unit pentagon:
## room -> spots on its floor, each x and the floor's y.
const ROOMS := {
	"hall": [Vector2(-0.06, GROUND), Vector2(-0.22, GROUND)],  # the menu's wife; a resident clear of the cellar door
	"sons": [Vector2(-0.11, -0.24), Vector2(-0.33, -0.44), Vector2(-0.13, -0.64)],
	"bedroom": [Vector2(0.6, UPPER)],
	"grandsons": [Vector2(0.15, MIDDLE), Vector2(0.42, MIDDLE)],
	"wife": [Vector2(0.68, MIDDLE)],
	"cellar": [Vector2(0.1, GROUND)],
	"servants": [Vector2(0.3, GROUND), Vector2(0.4, GROUND), Vector2(0.5, GROUND)],
}

## The house's inner walls and floors on the unit pentagon, as [from, to].
## Every gap is big enough for a shape (rooms about three shapes tall at
## the game's size, log 0222); floors climb in steps of about 0.2.
const INNER_WALLS: Array = [
	# Treads up the Hall, from over the men's door to the middle floor.
	[Vector2(-0.5, 0.6), Vector2(-0.32, 0.6)],
	[Vector2(-0.3, 0.4), Vector2(-0.12, 0.4)],
	# The middle floor, the Grandsons' and the Wife's, from the Hall's top tread east.
	[Vector2(-0.1, MIDDLE), Vector2(0.786, MIDDLE)],
	# Down from the middle floor: the Hall | the Cellar | the Servants, each
	# open at the foot.
	[Vector2(0.0, MIDDLE), Vector2(0.0, 0.56)],
	[Vector2(0.2, MIDDLE), Vector2(0.2, 0.56)],
	# Up from the middle floor: a tread, then the Bedroom's floor.
	[Vector2(0.03, -0.02), Vector2(0.21, -0.02)],
	[Vector2(0.25, UPPER), Vector2(0.929, UPPER)],
	# Grandsons | Grandsons | the Wife's apartment, hanging from the Bedroom's floor.
	[Vector2(0.3, UPPER), Vector2(0.3, -0.02)],
	[Vector2(0.55, UPPER), Vector2(0.55, -0.02)],
	# The Sons' cells, climbing under the west roof.
	[Vector2(-0.2, -0.24), Vector2(-0.02, -0.24)],
	[Vector2(-0.42, -0.44), Vector2(-0.24, -0.44)],
	[Vector2(-0.22, -0.64), Vector2(-0.04, -0.64)],
	# Down from the peak, between the Sons and the Bedroom.
	[Vector2(0.0, -1.0), Vector2(0.0, -0.44)],
]

## How far down the west wall, from the eave, the men's door starts; it
## runs to the ground. The women's door is a slit this many px tall.
const MEN_DOOR := 0.5
const WOMEN_SLIT := 22.0


## The men's (west) door's middle, where you stand to go in.
static func men_door(base: Vector2, width: float) -> Vector2:
	return house_point(base, width, _PENTAGON[4].lerp(_PENTAGON[3], 0.75))


## A house's px width for its rooms to be about three shapes tall (log 0222).
const HOUSE_WIDTH := 760.0


## A point given on the unit pentagon (_PENTAGON's frame: circumradius 1,
## centered) placed on a house standing on `base`, `width` across.
static func house_point(base: Vector2, width: float, unit: Vector2) -> Vector2:
	var r := width / 1.902
	return base - Vector2(0, 0.809 * r) + unit * r


## A great hall for the Circles: a dome on a solid hall (design logs 0063,
## 0221; its collision is temple_outline).
static func draw_temple(c: CanvasItem, base: Vector2, width: float, fill: Color, ink: Color) -> void:
	var height := width * 0.32
	var body := Rect2(base.x - width / 2.0, base.y - height, width, height)
	c.draw_rect(body, fill)
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


## A raised house's ground (log 0222): its island, `rise` over the road at
## `floor_at` (the house stands on its top middle). Mound data, for
## Mound.create. The road dips into a valley under it (each terrain's
## ground curve), so the way on runs round beneath.
static func raised(floor_at: Vector2, rise: float, width: float, chalk := false) -> Array[Dictionary]:
	return [{"at": floor_at - Vector2(0, rise), "width": width, "depth": ISLAND_DEPTH, "chalk": chalk}]


## A raised house's island's belly, px thick at the middle: thin, so the
## road beneath keeps its headroom (log 0231).
const ISLAND_DEPTH := 75.0


## Control points (for smooth) of a road dipping `depth` px into a valley
## under an island at `x`, from `half` px either side: a cosine, so its
## steepest stretch is gentle (atan(PI * depth / (2 * half))), with
## flat lips (log 0231).
static func valley(x: float, half: float, depth: float, road_y: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var steps := 8
	for i in range(-steps, steps + 1):
		var u := float(i) / steps  # -1 .. 1
		out.append(Vector2(x + u * half, road_y + depth * (1.0 + cos(u * PI)) / 2.0))
	return out


## A smooth line through `control` (centripetal Catmull-Rom), a point about every
## `spacing` px. Four points in a row on one line keep the middle stretch
## straight (for a flat floor).
static func smooth(control: Array, spacing := 24.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := control.size()
	for i in n - 1:
		var p0: Vector2 = control[maxi(i - 1, 0)]
		var p1: Vector2 = control[i]
		var p2: Vector2 = control[i + 1]
		var p3: Vector2 = control[mini(i + 2, n - 1)]
		var steps := maxi(1, ceili(p1.distance_to(p2) / spacing))
		for k in steps:
			out.append(_centripetal(p0, p1, p2, p3, float(k) / steps))
	out.append(control[n - 1])
	# Drop points on a straight run: collision can't split polygons with them.
	var kept := PackedVector2Array([out[0]])
	for i in range(1, out.size() - 1):
		var a := kept[-1]
		var b := out[i]
		var c := out[i + 1]
		if absf((b - a).cross(c - b)) > 0.5:
			kept.append(b)
	kept.append(out[-1])
	return kept


## A point `u` (0..1) of the way from p1 to p2 on a centripetal Catmull-Rom
## curve: it never loops back on itself, however unevenly the points lie.
static func _centripetal(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, u: float) -> Vector2:
	var knot := func(t: float, a: Vector2, b: Vector2) -> float:
		return t + maxf(sqrt(a.distance_to(b)), 0.01)
	var t0 := 0.0
	var t1: float = knot.call(t0, p0, p1)
	var t2: float = knot.call(t1, p1, p2)
	var t3: float = knot.call(t2, p2, p3)
	var t := lerpf(t1, t2, u)
	var a1 := p0.lerp(p1, (t - t0) / (t1 - t0))
	var a2 := p1.lerp(p2, (t - t1) / (t2 - t1))
	var a3 := p2.lerp(p3, (t - t2) / (t3 - t2))
	var b1 := a1.lerp(a2, (t - t0) / (t2 - t0))
	var b2 := a2.lerp(a3, (t - t1) / (t3 - t1))
	return b1.lerp(b2, (t - t1) / (t2 - t1))


## The y of `line` (west to east) at `x`, clamped to its ends.
static func y_at(line: PackedVector2Array, x: float) -> float:
	if x <= line[0].x:
		return line[0].y
	for i in range(1, line.size()):
		if x <= line[i].x:
			var a := line[i - 1]
			var b := line[i]
			return lerpf(a.y, b.y, inverse_lerp(a.x, b.x, x)) if b.x > a.x else b.y
	return line[-1].y


## The temple's solid outline (draw_temple): its body and dome.
static func temple_outline(base: Vector2, width: float) -> PackedVector2Array:
	var height := width * 0.32
	var top := Vector2(base.x, base.y - height)
	var r := width * 0.38
	var pts := PackedVector2Array([base + Vector2(-width / 2.0, 0), base + Vector2(width / 2.0, 0),
			base + Vector2(width / 2.0, -height)])
	for i in 21:
		pts.append(top + Vector2.from_angle(-PI * i / 20.0) * r)
	pts.append(base + Vector2(-width / 2.0, -height))
	return pts


## Place names (log 0221): handwriting in the margin, with no posts.
## signs: [{"pos", "text"}], drawn a little above pos.
static func draw_signs(c: CanvasItem, signs: Array, ink: Color, size := 20) -> void:
	var font := ThemeDB.fallback_font
	for s: Dictionary in signs:
		var pos: Vector2 = s.pos
		c.draw_string(font, pos + Vector2(-200, -38), s.text, HORIZONTAL_ALIGNMENT_CENTER, 400, size, Color(ink, 0.8))


static func _outline(c: CanvasItem, pts: PackedVector2Array, ink: Color, width: float) -> void:
	var line := pts.duplicate()
	line.append(pts[0])
	c.draw_polyline(line, ink, width, true)

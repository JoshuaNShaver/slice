class_name Underworld
extends StaticBody2D
## The Undercroft: the underworld's hub, far below the Center (design logs
## 0051, 0052, 0058, 0059). Drawn in chalk on slate (log 0056).
##
## Irregulars are born here and can never leave: the only way up is the
## Center's elevator, and its guards take regulars only. So the Undercroft
## has its own respawn point, healer and priest. Most of its people won't
## deal with regulars. Its houses break the book's pentagon law.
##
## The training cave (Cave) opens off its west end. East is sealed for now.
## Also draws the band of earth between the Center and the underworld. The
## Center's lift shaft (CenterTerrain.SHAFT, log 0227) runs open through
## both, into the Undercroft's roof.

const FLOOR_Y := 3000.0
const WEST_X := -2400.0  # the cave mouth
const EAST_X := 2600.0
const TOP := 1700.0
const BOTTOM := 3600.0
const WALL_THICKNESS := 200.0
## The earth band drawn between the overworld's ground and the underworld.
const EARTH := Rect2(-7000, CenterTerrain.BOTTOM, 22500, TOP + 120 - CenterTerrain.BOTTOM)

## The walkable floor, west to east. A little crooked, like everything here.
const FLOOR: Array[Vector2] = [
	Vector2(WEST_X, FLOOR_Y),
	Vector2(-1760, FLOOR_Y),
	Vector2(-1690, FLOOR_Y - 26),
	Vector2(-1610, FLOOR_Y - 14),
	Vector2(-1550, FLOOR_Y),
	Vector2(1760, FLOOR_Y),
	Vector2(1850, FLOOR_Y - 32),
	Vector2(1960, FLOOR_Y),
	Vector2(EAST_X, FLOOR_Y),
]

## Crooked houses (design log 0059), solid and big (logs 0222, 0236):
## floor middle x and outline (offsets from the floor middle, drawn small
## and scaled up by HOUSE_SCALE). Each has a door at the foot of both side
## walls: down here you roll right through people's houses. Some have an
## inner floor ("floor": from and to x, small, like the outline) a jump
## up, FLOOR_RISE px, where a resident stands off the road (log 0236).
const HOUSE_SCALE := 2.6
const FLOOR_RISE := 100.0
const CROOKED: Array[Dictionary] = [
	{"x": -2060, "outline": [Vector2(-90, 0), Vector2(10, -190), Vector2(95, 0)]},  # a triangle: unlawful
	{"x": -1500, "outline": [Vector2(-80, 0), Vector2(-60, -150), Vector2(70, -175), Vector2(85, 0)],
			"floor": Vector2(-60, 10)},
	{"x": -660, "outline": [Vector2(-85, 0), Vector2(-95, -110), Vector2(-20, -200), Vector2(60, -140),
			Vector2(80, 0)]},
	{"x": 820, "outline": [Vector2(-100, 0), Vector2(-110, -90), Vector2(-40, -160), Vector2(50, -170),
			Vector2(105, -70), Vector2(90, 0)], "floor": Vector2(10, 70)},
	{"x": 1560, "outline": [Vector2(-80, 0), Vector2(-80, -160), Vector2(80, -160), Vector2(80, 0)]},  # a square: unlawful
	{"x": 2220, "outline": [Vector2(-70, 0), Vector2(-120, -150), Vector2(40, -210), Vector2(90, 0)],
			"floor": Vector2(-40, 40)},
]
static func houses() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for house: Dictionary in CROOKED:
		var outline: Array = []
		for p: Vector2 in house.outline:
			outline.append(p * HOUSE_SCALE)
		var floors: Array = []
		if house.has("floor"):
			var f: Vector2 = house.floor * HOUSE_SCALE
			floors.append([Vector2(f.x, -FLOOR_RISE), Vector2(f.y, -FLOOR_RISE)])
		out.append({"at": Vector2(house.x, FLOOR_Y), "outline": outline, "floors": floors,
				"fill": Palette.SLATE_LIGHT, "ink": Palette.CHALK_LINE})
	return out


## Where a resident stands on house `i`'s inner floor, `u` along it (0 west, 1 east).
static func upstairs(i: int, u := 0.5) -> Vector2:
	var house: Dictionary = CROOKED[i]
	var f: Vector2 = house.floor * HOUSE_SCALE
	return Vector2(house.x + lerpf(f.x, f.y, u), FLOOR_Y - FLOOR_RISE - House.CROOKED_WALL / 2.0)


const SIGNS: Array[Dictionary] = [
	{"pos": Vector2(-2230, FLOOR_Y - 50), "text": "← The cave (levels 1–20)"},
	{"pos": Vector2(-260, FLOOR_Y - 50), "text": "The Undercroft"},
	{"pos": Vector2(2470, FLOOR_Y - 50), "text": "Deeper → (sealed)"},
]

## Most of the Undercroft refuses regulars (design log 0052). The Fence
## deals with anyone.
static func npcs() -> Array[Dictionary]:
	return [
		{
			"name": "A Lodger", "at": upstairs(1), "sides": 5, "kind": "irregular",
			"radius": 28.0, "color": Palette.CHALK[1], "serves": "irregulars",
			"lines": [
				"Born a degree off true, and here I'll die. Still, the rent's cheap.",
				"Up top they'd have had us 'cured'. Or worse.",
				"Regulars come down for the cave. They never stay.",
			],
			"refusals": [
				"Go back up your lift, Regular.",
				"Not talking to your kind.",
				"Look at you, all equal angles. Move along.",
			],
		},
		{
			# Takes the Board's "destroyed" infants from the bottom of its chute,
			# and greets them as they wake (design logs 0171, 0172; Cutscenes).
			"name": "The Gleaner", "at": Vector2(-400, FLOOR_Y), "sides": 5, "kind": "irregular",
			"radius": 26.0, "color": Palette.CHALK[4], "serves": "irregulars",
			"lines": [
				"The Board's chute ends just there. I wait at the bottom of it.",
				"Up top they wrote you down as destroyed. Paperwork is all the Board finishes.",
				"Not all of them come down whole. You did. Don't waste it.",
				"The Bonesetter mends us. The cave makes fighters of us. I just catch.",
			],
			"refusals": [
				"You never saw me, Regular. Nobody up there ever has.",
				"Nothing down here concerns your Board.",
			],
		},
		{
			"name": "The Bonesetter", "at": Vector2(60, FLOOR_Y), "sides": 7, "kind": "irregular",
			"radius": 32.0, "color": Palette.CHALK[3], "role": "healer", "serves": "irregulars",
			"heal_area": Rect2(WEST_X, TOP, EAST_X - WEST_X, BOTTOM - TOP),
			"lines": [
				"Nothing broken that wasn't broken when you were born.",
				"I set angles. Not straight, mind. Just back where they were.",
			],
			"heal_lines": [
				"There. Crooked as ever, and whole.",
				"Mended. Mind the cave; the bandits there aren't one of us any more.",
				"No charge for family. And down here, we're all family.",
			],
			"refusals": [
				"Your priests can mend you. Go up and ask them.",
				"I don't touch Regulars. They don't touch us.",
				"Bleed on someone else's floor.",
			],
		},
		{
			"name": "The Hedge Priest", "at": Vector2(470, FLOOR_Y), "sides": 11, "kind": "irregular",
			"radius": 40.0, "color": Palette.CHALK[5], "role": "priest", "serves": "irregulars",
			"refusals": [
				"I was a Circle once, until they measured me. Go wed under your own dome.",
				"I marry the ones they won't. You're not one of them.",
			],
		},
		{
			"name": "The Fence", "at": upstairs(3), "sides": 4, "kind": "irregular",
			"radius": 26.0, "color": Palette.CHALK[2], "serves": "anyone",
			"lines": [
				"I deal with anyone. Regulars pay double. No stock yet, mind.",
				"Colour, books, lenses. Come back when the shelves are full.",
				"Whatever the law upstairs says, my door is open.",
			],
		},
		{
			"name": "A Squatter", "at": upstairs(5), "sides": 3, "kind": "irregular",
			"radius": 24.0, "color": Palette.CHALK[0], "serves": "irregulars",
			"lines": [
				"A triangle house. Illegal up top. Who's going to stop me down here?",
				"East is sealed. Something's down there. Something big.",
			],
			"refusals": [
				"This is my corner. Find your own.",
				"Hmph. Tourist.",
			],
		},
	]


func _ready() -> void:
	collision_layer = PlayerShape.LAYER_TERRAIN
	collision_mask = 0
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 1.0
	_build_collision()


## Dev hot reload (HotReload autoload).
func _hot_reload() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_build_collision()


## The jagged ceiling, west to east: stalactites, but none over the shaft
## or a house.
static func ceiling() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var x := WEST_X
	var i := 0
	while x < EAST_X:
		var y := 2300.0 + (40.0 if i % 2 == 1 else 0.0)
		if i % 5 == 3 and absf(x - CenterTerrain.LIFT_DOWN.bottom.x) > 200.0 and not _over_house(x):
			y = 2440.0
		pts.append(Vector2(x, y))
		x += 125.0
		i += 1
	pts.append(Vector2(EAST_X, 2300.0))
	return pts


## True if `x` is over a house (or near one): no stalactite reaches down there.
static func _over_house(x: float) -> bool:
	for house: Dictionary in CROOKED:
		for p: Vector2 in house.outline:
			if absf(house.x + p.x * HOUSE_SCALE - x) < 140.0:
				return true
	return false


func _rock_polygon() -> PackedVector2Array:
	var poly := PackedVector2Array([Vector2(WEST_X, TOP), Vector2(EAST_X + WALL_THICKNESS, TOP),
			Vector2(EAST_X + WALL_THICKNESS, FLOOR_Y), Vector2(EAST_X, FLOOR_Y)])
	var roof := ceiling()
	roof.reverse()
	poly.append_array(roof)
	return poly


func _floor_polygon() -> PackedVector2Array:
	var poly := PackedVector2Array(FLOOR)
	poly.append(Vector2(EAST_X + WALL_THICKNESS, FLOOR_Y))
	poly.append(Vector2(EAST_X + WALL_THICKNESS, BOTTOM))
	poly.append(Vector2(WEST_X, BOTTOM))
	return poly


## The rock over the Undercroft, the shaft cut out of it.
func _rock_pieces() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	out.assign(Geometry2D.clip_polygons(_rock_polygon(), CenterTerrain.shaft_polygon()))
	return out


func _build_collision() -> void:
	var polys: Array[PackedVector2Array] = _rock_pieces()
	polys.append(_floor_polygon())
	for poly in polys:
		var shape := CollisionPolygon2D.new()
		shape.polygon = poly
		add_child(shape)


func _draw() -> void:
	_draw_earth()
	for piece in _rock_pieces():
		draw_colored_polygon(piece, Palette.SLATE_DARK)
	draw_colored_polygon(_floor_polygon(), Palette.SLATE_DARK)
	# The roof, broken by the shaft, whose walls run up to the Center's ground.
	var shaft := CenterTerrain.SHAFT
	var west := PackedVector2Array()
	var east := PackedVector2Array()
	for p in ceiling():
		if p.x <= shaft.position.x:
			west.append(p)
		elif p.x >= shaft.end.x:
			east.append(p)
	var roof := ceiling()
	west.append(Vector2(shaft.position.x, Buildings.y_at(roof, shaft.position.x)))
	east.insert(0, Vector2(shaft.end.x, Buildings.y_at(roof, shaft.end.x)))
	east.append(Vector2(EAST_X, FLOOR_Y))
	draw_polyline(west, Palette.CHALK_LINE, 3.0, true)
	draw_polyline(east, Palette.CHALK_LINE, 3.0, true)
	for x in [shaft.position.x, shaft.end.x]:
		_draw_shaft_wall(x, Buildings.y_at(roof, x))
	var ground := PackedVector2Array()
	for p in FLOOR:
		ground.append(p + Vector2(0, -1.5))
	draw_polyline(ground, Palette.CHALK_LINE, 3.0, true)
	_draw_chalk_hatching(ground, Vector2(4, 6), Vector2(-8, 18))
	_draw_chalk_hatching(west, Vector2(-4, -6), Vector2(8, -18))
	east.remove_at(east.size() - 1)
	_draw_chalk_hatching(east, Vector2(-4, -6), Vector2(8, -18))

	Buildings.draw_signs(self, SIGNS, Palette.CHALK_LINE)


## The ground between the worlds: parchment-dark near the surface, slate
## deep down, with strata lines.
func _draw_earth() -> void:
	var shaft := CenterTerrain.SHAFT
	_draw_earth_piece(Rect2(EARTH.position, Vector2(shaft.position.x - EARTH.position.x, EARTH.size.y)))
	_draw_earth_piece(Rect2(shaft.end.x, EARTH.position.y, EARTH.end.x - shaft.end.x, EARTH.size.y))


## A wall of the shaft, from the Center's ground down to the roof at `bottom`:
## ink while it's in the overworld, chalk once it's underground.
func _draw_shaft_wall(x: float, bottom: float) -> void:
	draw_line(Vector2(x, CenterTerrain.BOTTOM), Vector2(x, Regions.UNDERWORLD_TOP), Palette.INK, 3.0, true)
	draw_line(Vector2(x, Regions.UNDERWORLD_TOP), Vector2(x, bottom), Palette.CHALK_LINE, 3.0, true)


## One stretch of the earth band, `r` (EARTH's full height, part of its width).
func _draw_earth_piece(r: Rect2) -> void:
	var top := Palette.PARCHMENT_DARK
	var bottom := Palette.SLATE_DARK
	# Reaches full slate halfway down, so it meets the underworld's rock seamlessly.
	var mid := r.position.y + r.size.y * 0.5
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y),
			Vector2(r.end.x, mid), Vector2(r.position.x, mid)]), PackedColorArray([top, top, bottom, bottom]))
	draw_rect(Rect2(r.position.x, mid, r.size.x, r.end.y - mid), bottom)
	var y := r.position.y + 90.0
	var band := 0
	while y < r.end.y:
		var shade := Color(Palette.INK, 0.12).lerp(Color(Palette.CHALK_LINE, 0.1), (y - r.position.y) / r.size.y)
		var pts := PackedVector2Array()
		var x := r.position.x
		while x < r.end.x:
			pts.append(Vector2(x, y + sin(x * 0.004 + band) * 18.0))
			x += 200.0
		x = r.end.x
		pts.append(Vector2(x, y + sin(x * 0.004 + band) * 18.0))
		draw_polyline(pts, shade, 2.0)
		y += 130.0
		band += 1


func _draw_chalk_hatching(line: PackedVector2Array, from: Vector2, to: Vector2) -> void:
	var color := Color(Palette.CHALK_FADED, 0.25)
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		var count := int(a.distance_to(b) / 16.0)
		for k in count:
			var p := a.lerp(b, (k + 0.5) / count)
			draw_line(p + from, p + to, color, 1.5)

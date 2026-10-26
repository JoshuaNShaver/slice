class_name UpperEast
extends StaticBody2D
## East of the Center and far above it: the Noble Quarter and the Priests'
## Hill (design logs 0054, 0055, 0063).
##
## The Noble Quarter is a plateau at y = -1500, its west face a sheer cliff
## over the Center's east end, too tall for any jump: the only way up is the
## guarded elevator (CenterTerrain.LIFT_UP), which stops on a shelf jutting
## from the cliff, and reaches west over the Center's sunken house (log
## 0222). The Quarter's houses stand on mounds over its street, each
## the street dipping into a valley under each. Your house is one of them
## (HouseDoor).
##
## East of the quarter the Priests' Hill climbs in 15° terraces (gentle
## enough for decagons to stand on) to the Temple of the Circle at
## y = -2700. The temple's sanctum is sealed for now.

const FLOOR_Y := -1500.0
const WEST_X := 1150.0  # the shelf's west lip, over the lift and the Center's sunken house
const CLIFF_X := CenterTerrain.RIGHT_EDGE
const HILL_X := 7000.0
const TEMPLE_Y := -2700.0
const TEMPLE_X := 12000.0
const EAST_X := 15000.0
const SHELF_DEPTH := 40.0
const WALL_THICKNESS := 200.0
const TOP := -4300.0

## How high a house's island stands over the street, and how wide it is.
const MOUND_RISE := 190.0
const MOUND_WIDTH := 1050.0
const NOBLE_WIDTH := 820.0  # gentry build a little bigger
## Your house: floor middle and width (design log 0064).
const HOME := Vector2(4600, FLOOR_Y - MOUND_RISE)
const HOME_WIDTH := NOBLE_WIDTH

## The Quarter's houses' x, west to east (yours is HOME).
const HOUSE_XS: Array[float] = [3100.0, 6100.0]
const TEMPLE := Vector3(13500, TEMPLE_Y, 1000)

## Solid houses (House) and the islands under them.
static func houses() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for x in HOUSE_XS:
		out.append({"at": Vector2(x, FLOOR_Y - MOUND_RISE), "width": NOBLE_WIDTH,
				"fill": Palette.CHALK[4].lightened(0.35)})
	out.append({"at": HOME, "width": HOME_WIDTH, "fill": Palette.CHALK[2].lightened(0.25), "label": "Your house"})
	return out


## The Quarter's street, the shelf's lip to the hill's foot: one smooth
## curve dipping into a broad, gentle valley under each island (logs 0222,
## 0231), about 15° at its steepest. Nobody stands in them.
const VALLEY_HALF := 650.0
const VALLEY_DEPTH := 110.0
static var _floor := PackedVector2Array()


static func quarter_floor() -> PackedVector2Array:
	if not _floor.is_empty():
		return _floor
	var control: Array[Vector2] = [Vector2(WEST_X, FLOOR_Y), Vector2(WEST_X + 100, FLOOR_Y)]
	for x: float in [HOUSE_XS[0], HOME.x, HOUSE_XS[1]]:
		control.append_array(Buildings.valley(x, VALLEY_HALF, VALLEY_DEPTH, FLOOR_Y))
	control.append_array([Vector2(HILL_X - 100, FLOOR_Y), Vector2(HILL_X, FLOOR_Y)])
	_floor = Buildings.smooth(control)
	return _floor


## The ground's y at `x` on the Quarter's street.
static func ground_y(x: float) -> float:
	return Buildings.y_at(quarter_floor(), x)


static func mounds() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for x: float in HOUSE_XS + [HOME.x]:
		out.append_array(Buildings.raised(Vector2(x, FLOOR_Y), MOUND_RISE, MOUND_WIDTH))
	return out

const SIGNS: Array[Dictionary] = [
	{"pos": Vector2(2640, FLOOR_Y - 50), "text": "The Noble Quarter"},
	{"pos": Vector2(7080, FLOOR_Y - 50), "text": "↗ The Priests' Hill"},
	{"pos": Vector2(12100, TEMPLE_Y - 50), "text": "The Temple of the Circle"},
	{"pos": Vector2(13500, TEMPLE_Y - 160), "text": "The Sanctum: Circles only (sealed)"},
]

## The Quarter's and the hill's people (World builds them as Npc).
static func npcs() -> Array[Dictionary]:
	return [
		{
			"name": "A Lawyer", "at": Vector2(3850, ground_y(3850)), "sides": 4, "radius": 28.0,
			"serves": "regulars",
			"lines": [
				"Four sides, four equal angles. A Square's word is as good as his outline.",
				"Your house is just along: the one with your name on the door. Your chests are inside.",
				"Whatever you leave in your chests outlives you. Wise Squares plan for their heirs.",
			],
		},
		{
			"name": "The Physician", "at": Vector2(5350, ground_y(5350)), "sides": 5, "radius": 30.0,
			"role": "healer", "serves": "regulars",
			"heal_area": Rect2(1100, -2700, 5900, 1260),  # Regions: noble
			"lines": [
				"You're perfectly well. Annoyingly so.",
				"A Pentagon, a doctor. My father was a lawyer. My son will be a Hexagon.",
			],
			"heal_lines": [
				"There. Your angles are as good as new.",
				"Healed, at no charge. The Quarter looks after its own.",
				"Keep your corners out of trouble.",
			],
		},
		{
			"name": "A Hexagon of Rank", "at": Vector2(6870, ground_y(6870)), "sides": 6, "radius": 32.0,
			"serves": "regulars",
			"lines": [
				"Six sides. One might almost call me gentry.",
				"The hill is a stiff climb. The Circles never seem to roll back down it.",
				"I hear Regulars go below for sport. How very modern.",
			],
		},
		{
			"name": "The High Priest", "at": Vector2(12700, TEMPLE_Y), "sides": 40, "radius": 54.0,
			"color": Palette.PARCHMENT_LIGHT, "role": "priest", "serves": "regulars",
			"heal_area": Rect2(12000, -4200, 3200, 1560),  # Regions: temple
			"heal_lines": [
				"Rise, and be whole. The Circle is the measure of all things.",
				"The higher you climb, the nearer the Circle. Be healed.",
				"Your sides will multiply, and your sins with them. Go in peace.",
			],
		},
		{
			"name": "An Acolyte", "at": Vector2(12480, TEMPLE_Y), "sides": 12, "radius": 34.0,
			"serves": "regulars",
			"lines": [
				"Twelve sides. Not yet a Circle, but nearer every heir.",
				"The Sanctum is for Circles alone. Even I may not enter.",
				"The High Priest marries and heals, as the priest below does. Only grander.",
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


## The walkable surface, west lip of the shelf to the east wall's top.
static func surface() -> PackedVector2Array:
	var pts := quarter_floor().duplicate()
	# Six 15° climbs of 200 px, with short flat landings between them.
	var x := HILL_X
	var y := FLOOR_Y
	var climbs := 6
	var rise := (FLOOR_Y - TEMPLE_Y) / climbs
	var run := rise / tan(deg_to_rad(15.0))
	var landing := (TEMPLE_X - HILL_X - climbs * run) / (climbs - 1)
	for i in climbs:
		x += run
		y -= rise
		pts.append(Vector2(x, y))
		if i < climbs - 1:
			x += landing
			pts.append(Vector2(x, y))
	pts.append(Vector2(EAST_X, TEMPLE_Y))
	pts.append(Vector2(EAST_X, TOP))
	return pts


func _ground_polygon() -> PackedVector2Array:
	var poly := surface()
	poly.append(Vector2(EAST_X + WALL_THICKNESS, TOP))
	poly.append(Vector2(EAST_X + WALL_THICKNESS, CenterTerrain.BOTTOM))
	poly.append(Vector2(CLIFF_X, CenterTerrain.BOTTOM))
	poly.append_array(shelf_underside())
	return poly


## The shelf's underside, the cliff to its west lip: thick at the cliff,
## thinning to the lip, like the overhang of the user's sketch (log 0222).
static func shelf_underside() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 9:
		var u := i / 8.0  # 0 at the cliff, 1 at the lip
		var x := lerpf(CLIFF_X, WEST_X, u)
		pts.append(Vector2(x, FLOOR_Y + SHELF_DEPTH + 330.0 * pow(1.0 - u, 1.6)))
	return pts


func _build_collision() -> void:
	var ground := CollisionPolygon2D.new()
	ground.polygon = _ground_polygon()
	add_child(ground)
	var temple := CollisionPolygon2D.new()
	temple.polygon = Buildings.temple_outline(Vector2(TEMPLE.x, TEMPLE.y), TEMPLE.z)
	add_child(temple)


func _draw() -> void:
	var poly := _ground_polygon()
	draw_colored_polygon(poly, Palette.PARCHMENT_DARK)
	var line := surface()
	for i in line.size():
		line[i] += Vector2(0, -1.5)
	draw_polyline(line, Palette.INK, 3.0, true)
	# The shelf's underside and the cliff face.
	var under := PackedVector2Array([Vector2(WEST_X, FLOOR_Y)])
	var shelf := shelf_underside()
	shelf.reverse()
	under.append_array(shelf)
	under.append(Vector2(CLIFF_X, -285))
	draw_polyline(under, Palette.INK, 3.0, true)
	_draw_cliff_hatching()

	Buildings.draw_temple(self, Vector2(TEMPLE.x, TEMPLE.y), TEMPLE.z, Palette.CHALK[5].lightened(0.45), Palette.INK)
	Buildings.draw_signs(self, SIGNS, Palette.INK)


## Vertical strokes down the cliff, so it reads as a sheer face.
func _draw_cliff_hatching() -> void:
	var color := Color(Palette.INK_FADED, 0.25)
	var y := FLOOR_Y + SHELF_DEPTH + 10.0
	while y < -300.0:
		var x := CLIFF_X + 8.0 + fposmod(y * 0.37, 14.0)
		draw_line(Vector2(x, y), Vector2(x + 3, y + 22), color, 1.5)
		y += 18.0

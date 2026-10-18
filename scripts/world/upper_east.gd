class_name UpperEast
extends StaticBody2D
## East of the Center and far above it: the Noble Quarter and the Priests'
## Hill (design logs 0054, 0055, 0063).
##
## The Noble Quarter is a plateau at y = -1500, its west face a sheer cliff
## over the Center's east end, too tall for any jump: the only way up is the
## guarded elevator (CenterTerrain.LIFT_UP), which stops on a shelf jutting
## from the cliff. Your house is here (HouseDoor).
##
## East of the quarter the Priests' Hill climbs in 15° terraces (gentle
## enough for decagons to stand on) to the Temple of the Circle at
## y = -2700. The temple's sanctum is sealed for now.

const FLOOR_Y := -1500.0
const WEST_X := 2130.0  # the shelf's west lip
const CLIFF_X := CenterTerrain.RIGHT_EDGE
const HILL_X := 7000.0
const TEMPLE_Y := -2700.0
const TEMPLE_X := 12000.0
const EAST_X := 15000.0
const SHELF_DEPTH := 40.0
const WALL_THICKNESS := 200.0
const TOP := -4300.0

## Your house: floor middle and width (design log 0064).
const HOME := Vector2(4200, FLOOR_Y)
const HOME_WIDTH := 260.0

## Noble houses: x, floor y, width.
const HOUSES: Array[Vector3] = [
	Vector3(2900, FLOOR_Y, 240),
	Vector3(3500, FLOOR_Y, 220),
	Vector3(5000, FLOOR_Y, 250),
	Vector3(5650, FLOOR_Y, 230),
	Vector3(6400, FLOOR_Y, 260),
]
const TEMPLE := Vector3(13500, TEMPLE_Y, 1000)

const SIGNS: Array[Dictionary] = [
	{"pos": Vector2(2640, FLOOR_Y - 50), "text": "The Noble Quarter"},
	{"pos": Vector2(7080, FLOOR_Y - 50), "text": "↗ The Priests' Hill"},
	{"pos": Vector2(12100, TEMPLE_Y - 50), "text": "The Temple of the Circle"},
	{"pos": Vector2(13500, TEMPLE_Y - 160), "text": "The Sanctum: Circles only (sealed)"},
]

const NPCS: Array[Dictionary] = [
	{
		"name": "A Lawyer", "at": Vector2(3200, FLOOR_Y), "sides": 4, "radius": 28.0,
		"serves": "regulars",
		"lines": [
			"Four sides, four equal angles. A Square's word is as good as his outline.",
			"Your house is just along: the one with your name on the door. Your chests are inside.",
			"Whatever you leave in your chests outlives you. Wise Squares plan for their heirs.",
		],
	},
	{
		"name": "The Physician", "at": Vector2(4700, FLOOR_Y), "sides": 5, "radius": 30.0,
		"role": "healer", "serves": "regulars",
		"heal_area": Rect2(2100, -2700, 4900, 1260),  # Regions: noble
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
		"name": "A Hexagon of Rank", "at": Vector2(6000, FLOOR_Y), "sides": 6, "radius": 32.0,
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
	var pts := PackedVector2Array([Vector2(WEST_X, FLOOR_Y), Vector2(HILL_X, FLOOR_Y)])
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
	poly.append(Vector2(CLIFF_X, FLOOR_Y + SHELF_DEPTH))
	poly.append(Vector2(WEST_X, FLOOR_Y + SHELF_DEPTH))
	return poly


func _build_collision() -> void:
	var ground := CollisionPolygon2D.new()
	ground.polygon = _ground_polygon()
	add_child(ground)


func _draw() -> void:
	var poly := _ground_polygon()
	draw_colored_polygon(poly, Palette.PARCHMENT_DARK)
	var line := surface()
	for i in line.size():
		line[i] += Vector2(0, -1.5)
	draw_polyline(line, Palette.INK, 3.0, true)
	# The shelf's underside and the cliff face.
	draw_polyline(PackedVector2Array([
		Vector2(WEST_X, FLOOR_Y), Vector2(WEST_X, FLOOR_Y + SHELF_DEPTH),
		Vector2(CLIFF_X, FLOOR_Y + SHELF_DEPTH), Vector2(CLIFF_X, -285),
	]), Palette.INK, 3.0, true)
	_draw_cliff_hatching()

	for house in HOUSES:
		Buildings.draw_house(self, Vector2(house.x, house.y), house.z, Palette.CHALK[4].lightened(0.35), Palette.INK)
	Buildings.draw_house(self, HOME, HOME_WIDTH, Palette.CHALK[2].lightened(0.25), Palette.INK, "Your house")
	Buildings.draw_temple(self, Vector2(TEMPLE.x, TEMPLE.y), TEMPLE.z, Palette.CHALK[5].lightened(0.45), Palette.INK)

	var font := ThemeDB.fallback_font
	for s in SIGNS:
		var pos: Vector2 = s.pos
		draw_line(pos + Vector2(0, -30), pos + Vector2(0, 50), Palette.INK_FADED, 2.0)
		draw_string(font, pos + Vector2(-200, -38), s.text, HORIZONTAL_ALIGNMENT_CENTER, 400, 20, Palette.INK)


## Vertical strokes down the cliff, so it reads as a sheer face.
func _draw_cliff_hatching() -> void:
	var color := Color(Palette.INK_FADED, 0.25)
	var y := FLOOR_Y + SHELF_DEPTH + 10.0
	while y < -300.0:
		var x := CLIFF_X + 8.0 + fposmod(y * 0.37, 14.0)
		draw_line(Vector2(x, y), Vector2(x + 3, y + 22), color, 1.5)
		y += 18.0

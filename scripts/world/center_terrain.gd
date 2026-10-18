class_name CenterTerrain
extends StaticBody2D
## The Center, the respawn hub (DESIGN §1), drawn in ink on parchment.
##
## Ground level at the plaza is y = 0 and screen-down is south. The land rises
## east to the elevator up to the Noble Quarter (design log 0054) and sinks
## west to the open gate of the barracks (logs 0061, 0067). Ledges climb north
## (log 0062), and the old south hatch is now the elevator down to the
## underworld, for 5+ sides (log 0066). Pentagon houses for the Center's triangles line the low
## ground and the east rise (logs 0053, 0060).

const SPAWN_POINT := Regions.CENTER_SPAWN
const LEFT_EDGE := -2400.0
const RIGHT_EDGE := 2400.0

## The walkable surface, the barracks gate to the foot of the Noble Quarter's
## cliff (UpperEast). The solid ground is below it; the barracks (Barracks)
## carry on west at the same height.
const SURFACE: Array[Vector2] = [
	Vector2(LEFT_EDGE, 120),
	Vector2(-1850, 120),
	Vector2(-1750, 80),  # shell craters near the war front
	Vector2(-1650, 120),
	Vector2(-1450, 120),
	Vector2(-1380, 95),
	Vector2(-1310, 120),
	Vector2(-700, 120),
	Vector2(-300, 0),  # ~17° slope down to the west
	Vector2(300, 0),  # the plaza
	Vector2(700, -110),  # ~15° slope up to the east
	Vector2(1000, -110),
	Vector2(1250, -285),  # ~35°: too steep for pentagons and up to rest on
	Vector2(RIGHT_EDGE, -285),
]
const BOTTOM := 700.0
const WALL_THICKNESS := 200.0

## Ledges you can jump up through from below (x, y of the top-left, width).
const LEDGES: Array[Vector3] = [
	Vector3(-200, -120, 140),
	Vector3(20, -230, 140),
	Vector3(-180, -340, 140),
	Vector3(40, -450, 160),
]

const SIGNS: Array[Dictionary] = [
	{"pos": Vector2(820, -160), "text": "East: the Noble Quarter →"},
	{"pos": Vector2(120, -500), "text": "↑ North: uncharted"},
	{"pos": Vector2(0, -20), "text": "The Center"},
]

## The two elevators that start here (World builds them).
const LIFT_DOWN := {
	"name": "The underworld lift", "rule": "regulars", "upper_rule": "five_sides", "guard": "Constable",
	"stop_names": ["Lift up to the Center (regulars only)", "Lift down to the underworld (5+ sides)"],
	"bottom": Vector2(-1040, 3000), "top": Vector2(-1040, 120),
	"refusals": [
		"Irregulars stay below. That's the law, and I'm the law.",
		"Up? With those angles? Back to the Undercroft with you.",
		"The inspectors would have my badge. Down you stay.",
	],
	# Turned away at the top: triangles and squares (design log 0066).
	"upper_refusals": [
		"Pentagons and up only. Triangles serve in the barracks, west.",
		"The underworld's no place for the lower orders. The army will have you.",
		"Five sides, friend. Count them. Then go and see the General.",
	],
}
const LIFT_UP := {
	"name": "The noble lift", "rule": "four_sides", "guard": "Gatekeeper",
	"stop_names": ["Lift up to the Noble Quarter (4+ sides)", "Lift down to the Center"],
	"bottom": Vector2(2275, -285), "top": Vector2(2275, -1500),
	"refusals": [
		"Four sides or more, friend. Come back as a Square.",
		"Triangles keep to the Center. Marry well, and your grandson may ride.",
		"The Quarter is for the professions and the gentry. Not for you.",
		"Count your sides. Now count again. Still three? Off you go.",
	],
}

## Pentagon houses: x of the floor middle, floor y, width at the eaves.
const HOUSES: Array[Vector3] = [
	Vector3(-2120, 120, 190),
	Vector3(-1550, 120, 150),
	Vector3(-830, 120, 170),
	Vector3(1125, -110, 190),
	Vector3(1520, -285, 210),
	Vector3(1820, -285, 170),
]

## The Center's people (World builds them as Npc).
const NPCS: Array[Dictionary] = [
	{
		"name": "The Priest", "at": Vector2(200, 0), "sides": 40, "radius": 44.0,
		"color": Palette.PARCHMENT_LIGHT, "role": "priest", "serves": "regulars",
		"heal_area": Rect2(LEFT_EDGE, -1400, RIGHT_EDGE - LEFT_EDGE, 2100),
		"heal_lines": [
			"Be whole again. Regularity is the first of the virtues.",
			"Configuration makes the man. Go, and keep your angles true.",
			"The Circle mends what the corners break. Give thanks.",
			"Rest, child. May your heir stand one side nearer perfection.",
			"Your wounds are forgiven. Irregularity never is.",
			"Every side in its place, and every place in its order. Be healed.",
		],
	},
	{
		"name": "A Merchant", "at": Vector2(-1230, 120), "sides": 3, "kind": "equilateral",
		"radius": 26.0,
		"lines": [
			"Equilateral, and proud of it. My son will be a Square.",
			"The lift east is for Squares and up. Mind your angles and your heirs will ride it.",
			"Down the south lift live the Irregulars. Only pentagons and up may visit.",
			"Our houses are pentagons by law. A square house? You'd be impaled on the corners.",
		],
	},
	{
		"name": "A Workman", "at": Vector2(-1960, 120), "sides": 3, "kind": "isosceles",
		"radius": 26.0,
		"lines": [
			"Two sides equal, one not. Soldiers and workmen, that's us.",
			"Every heir, my family's apex widens a little. Patience.",
			"The barracks are west. The drill yard takes anyone with corners.",
		],
	},
	{
		"name": "A Shopkeeper", "at": Vector2(1660, -285), "sides": 3, "kind": "equilateral",
		"radius": 26.0,
		"lines": [
			"Women's door on the west, men's on the east. Every house, by law.",
			"I sell to the Quarter's servants. Squares never come down themselves.",
			"No windows? Why would we want windows? The light is the same indoors and out.",
		],
	},
]


func _ready() -> void:
	collision_layer = PlayerShape.LAYER_TERRAIN
	collision_mask = 0
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 1.0
	_build_collision()


## Dev hot reload (HotReload autoload): pick up edited ground and ledges.
func _hot_reload() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_build_collision()


func _build_collision() -> void:
	var ground := CollisionPolygon2D.new()
	ground.polygon = _ground_polygon()
	add_child(ground)

	for ledge in LEDGES:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(ledge.z, 16)
		shape.shape = rect
		shape.position = Vector2(ledge.x + ledge.z / 2.0, ledge.y + 8)
		shape.one_way_collision = true
		add_child(shape)


func _ground_polygon() -> PackedVector2Array:
	var poly := PackedVector2Array([Vector2(LEFT_EDGE - WALL_THICKNESS, SURFACE[0].y)])
	poly.append_array(PackedVector2Array(SURFACE))
	poly.append(Vector2(RIGHT_EDGE + WALL_THICKNESS, SURFACE[-1].y))
	poly.append(Vector2(RIGHT_EDGE + WALL_THICKNESS, BOTTOM))
	poly.append(Vector2(LEFT_EDGE - WALL_THICKNESS, BOTTOM))
	return poly


func _draw() -> void:
	draw_colored_polygon(_ground_polygon(), Palette.PARCHMENT_DARK)
	_draw_hatching()
	# Sit the ink line just above the true surface so shapes rest on it, not in it.
	var line := PackedVector2Array()
	for point in SURFACE:
		line.append(point + Vector2(0, -1.5))
	draw_polyline(line, Palette.INK, 3.0, true)

	for ledge in LEDGES:
		var rect := Rect2(ledge.x, ledge.y, ledge.z, 16)
		draw_rect(rect, Palette.PARCHMENT_LIGHT)
		draw_rect(rect, Palette.INK, false, 2.5)

	_draw_barracks_gate()
	for house in HOUSES:
		Buildings.draw_house(self, Vector2(house.x, house.y), house.z, Palette.PARCHMENT_LIGHT, Palette.INK)

	var font := ThemeDB.fallback_font
	for s in SIGNS:
		var pos: Vector2 = s.pos
		draw_line(pos + Vector2(0, -30), pos + Vector2(0, 50), Palette.INK_FADED, 2.0)
		draw_string(font, pos + Vector2(-200, -38), s.text, HORIZONTAL_ALIGNMENT_CENTER, 400, 20, Palette.INK)


## The open gate to the barracks (design logs 0061, 0067): two posts and a
## lintel you roll under.
func _draw_barracks_gate() -> void:
	var left := LEFT_EDGE - 10.0
	var right := LEFT_EDGE + 70.0
	for x in [left, right]:
		draw_rect(Rect2(x - 6, -100, 12, 220), Palette.PARCHMENT_LIGHT)
		draw_rect(Rect2(x - 6, -100, 12, 220), Palette.INK, false, 2.5)
	var lintel := Rect2(left - 14, -122, right - left + 28, 22)
	draw_rect(lintel, Palette.PARCHMENT_LIGHT)
	Gear.draw_hatch(self, PackedVector2Array([lintel.position, Vector2(lintel.end.x, lintel.position.y),
			lintel.end, Vector2(lintel.position.x, lintel.end.y)]), [[45.0], 8.0], 1.0, Color(Palette.INK, 0.35))
	draw_rect(lintel, Palette.INK, false, 2.5)


## Short pen strokes just under the surface, like an ink drawing's shading.
func _draw_hatching() -> void:
	var color := Palette.INK_FADED
	color.a = 0.25
	for i in SURFACE.size() - 1:
		var a := SURFACE[i]
		var b := SURFACE[i + 1]
		var length := a.distance_to(b)
		var step := 16.0
		var count := int(length / step)
		for k in count:
			var p := a.lerp(b, (k + 0.5) / count)
			draw_line(p + Vector2(4, 6), p + Vector2(-8, 18), color, 1.5)

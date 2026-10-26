class_name CenterTerrain
extends StaticBody2D
## The Center, the respawn hub (DESIGN §1), drawn in ink on parchment.
##
## Ground level at the plaza is y = 0 and screen-down is south. The land rises
## east to the elevator up to the Noble Quarter (design log 0054) and sinks
## west to the open gate of the barracks (logs 0061, 0067). Ledges climb north
## (log 0062), and the old south hatch is now the elevator down to the
## underworld, for 5+ sides (log 0066). Its lift runs down a real shaft
## through the ground (SHAFT, log 0227), capped by a hatch (Elevator).
##
## Nothing here is scenery (log 0221): its two houses are solid, and the
## road goes under one and past the other (log 0222). Over the low road
## west, a raised house on an island, the road dipping under it; at the east end, a sunken house under the overhang of the
## Noble Quarter's shelf, the women's yard behind it, and west of it the
## lift up to the Quarter. Its people stand in
## the way (log 0223).

const SPAWN_POINT := Regions.CENTER_SPAWN
const LEFT_EDGE := -2400.0
const RIGHT_EDGE := 2400.0

## The walkable surface, the barracks to the foot of the Noble Quarter's
## cliff (UpperEast), through these points as one smooth curve (log 0222):
## a broad valley under the raised house, so the road runs round beneath
## it, then up to the plaza, the Row and the upper flat. Four points in a
## row keep a floor flat where something stands on it. The barracks carry
## on west at the same height.
## Under the raised house, a broad, gentle valley (Buildings.valley, log
## 0231): about 14° at its steepest, so a triangle rolls up it.
const VALLEY := Vector3(-1770, 610, 100)  # middle x, half width, depth
static func surface_points() -> Array[Vector2]:
	var out: Array[Vector2] = [Vector2(LEFT_EDGE, 120)]
	out.append_array(Buildings.valley(VALLEY.x, VALLEY.y, VALLEY.z, 120))
	out.append_array(SURFACE_EAST)
	return out


const SURFACE_EAST: Array[Vector2] = [
	Vector2(-1100, 120),  # the lift down
	Vector2(-980, 120),
	Vector2(-850, 116),
	Vector2(-560, 60),
	Vector2(-330, 0),
	Vector2(-250, 0),  # the plaza
	Vector2(250, 0),
	Vector2(330, 0),
	Vector2(540, -70),
	Vector2(700, -110),
	Vector2(740, -110),  # Merchants' Row
	Vector2(960, -110),
	Vector2(1010, -112),
	Vector2(1180, -250),
	Vector2(1290, -285),
	Vector2(1340, -285),  # the lift up and the sunken house
	Vector2(2350, -285),
	Vector2(RIGHT_EDGE, -285),
]
static var _surface := PackedVector2Array()


static func surface() -> PackedVector2Array:
	if _surface.is_empty():
		_surface = Buildings.smooth(surface_points())
	return _surface


## The ground's y at `x`.
static func ground_y(x: float) -> float:
	return Buildings.y_at(surface(), x)


const BOTTOM := 700.0
const WALL_THICKNESS := 200.0

## Ledges, solid (x, y of the top-left, width). Get onto one from beside it.
const LEDGES: Array[Vector3] = [
	Vector3(-200, -120, 140),
	Vector3(20, -230, 140),
	Vector3(-180, -340, 140),
	Vector3(40, -450, 160),
]

const SIGNS: Array[Dictionary] = [
	{"pos": Vector2(620, -138), "text": "East: the Noble Quarter →"},
	{"pos": Vector2(120, -500), "text": "↑ North: uncharted"},
	{"pos": Vector2(0, -20), "text": "The Center"},
]

## The raised house's mound over the low road, and the sunken house under
## the Quarter's shelf (UpperEast extends it west over them).
const RAISED := Vector2(-1800, -60)  # the island's top middle, where the house stands
const SUNKEN := Vector2(1850, -285)

## Floating ground (Mound): the raised house's island, and the Priest's dais.
const PRIEST_AT := Vector2(200, 0)
static func mounds() -> Array[Dictionary]:
	var out := Buildings.raised(Vector2(RAISED.x, 120), 120 - RAISED.y, 1050.0)
	out.append(Mound.dais(PRIEST_AT))
	return out

## Solid houses (House).
const HOUSES: Array[Dictionary] = [
	{"at": RAISED},
	{"at": SUNKEN},
]

## The underworld lift's shaft (log 0227): open from the Center's road down
## through the earth and the Undercroft's rock into its cave. The terrains
## leave it out of their ground; the Elevator caps the top with a hatch.
const SHAFT := Rect2(-1100, 0, 120, 2500)

## The two elevators that start here (World builds them).
const LIFT_DOWN := {
	"name": "The underworld lift", "rule": "regulars", "upper_rule": "five_sides", "guard": "Constable",
	"stop_names": ["Lift up to the Center (regulars only)", "Lift down to the underworld (5+ sides)"],
	"bottom": Vector2(-1040, 3000), "top": Vector2(-1040, 120), "shaft": SHAFT,
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
	"bottom": Vector2(1380, -285), "top": Vector2(1380, -1500),  # west of the sunken house, as in the sketch
	"refusals": [
		"Four sides or more, friend. Come back as a Square.",
		"Triangles keep to the Center. Marry well, and your grandson may ride.",
		"The Quarter is for the professions and the gentry. Not for you.",
		"Count your sides. Now count again. Still three? Off you go.",
	],
}

## The Center's people (World builds them as Npc).
static func npcs() -> Array[Dictionary]:
	return [
		{
			# Too tall to jump (log 0223): he preaches from a dais over the plaza.
			"name": "The Priest", "at": Mound.on_dais(PRIEST_AT), "sides": 40, "radius": 44.0,
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
			"name": "A Merchant", "at": Vector2(760, -110), "sides": 3, "kind": "equilateral",
			"radius": 26.0,
			"lines": [
				"Equilateral, and proud of it. My son will be a Square.",
				"The lift east is for Squares and up. Mind your angles and your heirs will ride it.",
				"Down the south lift live the Irregulars. Only pentagons and up may visit.",
				"Our houses are pentagons by law. A square house? You'd be impaled on the corners.",
			],
		},
		{
			"name": "A Workman", "at": House.room_spot(RAISED, "hall", 1), "sides": 3, "kind": "isosceles",
			"radius": 26.0,
			"lines": [
				"Two sides equal, one not. Soldiers and workmen, that's us.",
				"Every heir, my family's apex widens a little. Patience.",
				"The barracks are west. The drill yard takes anyone with corners.",
			],
		},
		{
			# The family strongroom (log 0212): chests bought for coins, kept for
			# every heir. It's the sunken house's cellar.
			"name": "The Strongroom Keeper", "at": House.room_spot(SUNKEN, "cellar"), "sides": 4, "radius": 26.0,
			"role": "vault", "serves": "regulars",
			"lines": [
				"Your family's goods, under lock and key. Every heir gets the key.",
				"A chest is a thousand coins, and it's yours for as long as your line lasts.",
				"Die without an heir and I clear the chests. Those are the rules.",
			],
		},
		{
			# Up the hill past Merchants' Row (log 0211): upgrades gear, +1 to
			# +5. Outside the sunken house, in your way.
			"name": "The Blacksmith", "at": Vector2(1545, -285), "sides": 4, "radius": 28.0,
			"role": "smith", "serves": "regulars",
			"lines": [
				"Coin for the first three. Past that, I need rare ore: the Quarry Isle's, out west.",
				"Bring me ore and I'll keep it. Nobody carries twenty-five lumps in one bag.",
				"Steel's steel until it's been through my fire five times. Then it's something else.",
				"Hand it here. Mind the anvil.",
			],
		},
		{
			"name": "A Shopkeeper", "at": House.room_spot(SUNKEN, "hall", 1), "sides": 3, "kind": "equilateral",
			"radius": 26.0,
			"lines": [
				"Men's door on the west, the women's little one on the east. Every house, by law.",
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
	for piece in ground_pieces():
		var ground := CollisionPolygon2D.new()
		ground.polygon = piece
		add_child(ground)

	for ledge in LEDGES:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(ledge.z, 16)
		shape.shape = rect
		shape.position = Vector2(ledge.x + ledge.z / 2.0, ledge.y + 8)
		add_child(shape)


static func _ground_polygon() -> PackedVector2Array:
	var line := surface()
	var poly := PackedVector2Array([Vector2(LEFT_EDGE - WALL_THICKNESS, line[0].y)])
	poly.append_array(line)
	poly.append(Vector2(RIGHT_EDGE + WALL_THICKNESS, line[-1].y))
	poly.append(Vector2(RIGHT_EDGE + WALL_THICKNESS, BOTTOM))
	poly.append(Vector2(LEFT_EDGE - WALL_THICKNESS, BOTTOM))
	return poly


## The ground with the lift's shaft cut out of it: one piece either side.
static func ground_pieces() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	out.assign(Geometry2D.clip_polygons(_ground_polygon(), shaft_polygon()))
	return out


static func shaft_polygon() -> PackedVector2Array:
	var r := SHAFT
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


static func in_shaft(x: float) -> bool:
	return x > SHAFT.position.x and x < SHAFT.end.x


func _draw() -> void:
	for piece in ground_pieces():
		draw_colored_polygon(piece, Palette.PARCHMENT_DARK)
	_draw_hatching()
	# Sit the ink line just above the true surface so shapes rest on it, not
	# in it. It turns down the shaft's walls, either side.
	var west := PackedVector2Array()
	var east := PackedVector2Array()
	for point in surface():
		if point.x <= SHAFT.position.x:
			west.append(point + Vector2(0, -1.5))
		elif point.x >= SHAFT.end.x:
			east.append(point + Vector2(0, -1.5))
	var lip := ground_y(SHAFT.position.x)
	west.append(Vector2(SHAFT.position.x, lip - 1.5))
	west.append(Vector2(SHAFT.position.x, BOTTOM))
	east.insert(0, Vector2(SHAFT.end.x, ground_y(SHAFT.end.x) - 1.5))
	east.insert(0, Vector2(SHAFT.end.x, BOTTOM))
	draw_polyline(west, Palette.INK, 3.0, true)
	draw_polyline(east, Palette.INK, 3.0, true)

	for ledge in LEDGES:
		var rect := Rect2(ledge.x, ledge.y, ledge.z, 16)
		draw_rect(rect, Palette.PARCHMENT_LIGHT)
		draw_rect(rect, Palette.INK, false, 2.5)

	Buildings.draw_signs(self, SIGNS, Palette.INK)


## Short pen strokes just under the surface, like an ink drawing's shading.
func _draw_hatching() -> void:
	var color := Palette.INK_FADED
	color.a = 0.25
	var x := LEFT_EDGE + 8.0
	while x < RIGHT_EDGE:
		var p := Vector2(x, ground_y(x))
		if not in_shaft(p.x - 8.0) and not in_shaft(p.x + 4.0):
			draw_line(p + Vector2(4, 6), p + Vector2(-8, 18), color, 1.5)
		x += 16.0

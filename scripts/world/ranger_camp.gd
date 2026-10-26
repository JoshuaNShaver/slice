class_name RangerCamp
extends StaticBody2D
## The rangers' secret island (design logs 0245, 0246), far from the rest of
## the world, reached only through the Drill Sergeant and left by the
## Ferryman. Ink on parchment like the barracks. Sheer cliffs at each end,
## and the sea below the west one (drawn, as water is; log 0221). Only the
## west: east of the island are ranger school's exam courses.
##
## West to east: the Ferryman by the west cliff, the ranger quartermaster
## (starting gear for chits, the rest for coins), the Camp Medic, the Ranger
## Instructor (ranger school's training), then the camp's yard: wild shapes
## to throw at, ranger recruits who throw back, and room for a bout.
## Layout in the camp's own coordinates, its floor at y = 0; the node sits at
## ORIGIN.

const ORIGIN := Vector2(25000, 0)
const WEST_X := -1700.0
const EAST_X := 1700.0
const CLIFF := 1400.0  # how high the cliffs rise above the floor
const WALL := 200.0
const DEPTH := 600.0
const SEA := 240.0  # the sea's surface beyond the west cliff, below the floor
const SEA_WIDTH := 2400.0  # how far west of the cliff it's drawn (Regions.CAMP_RECT shows 900 px of it)

const INSTRUCTOR := "The Ranger Instructor"
const QUARTERMASTER := "The Ranger Quartermaster"
const FERRYMAN := "The Ferryman"
## Where you land on the island: by the Ferryman.
const SPAWN := ORIGIN + Vector2(-1300, -40)
## The camp's yard (world coordinates): its recruits keep to it.
const YARD := Rect2(ORIGIN + Vector2(-150, -650), Vector2(1800, 680))
## Where a Heroldt waits for your bout (ranger school).
const BOUT_AT := ORIGIN + Vector2(1350, 0)

## The yard: [type, local x, respawn seconds].
const DRILL: Array = [
	["dummy", 150.0, 4.0],
	["dummy", 300.0, 4.0],
	["dummy", 450.0, 4.0],
	["ranger_recruit", 850.0, 8.0],
	["ranger_recruit", 1100.0, 8.0],
]

const SIGNS: Array[Dictionary] = [
	{"pos": ORIGIN + Vector2(-1300, -40), "text": "The Ferryman · back to the barracks"},
	{"pos": ORIGIN + Vector2(-750, -40), "text": "Ranger stores · chits for the first, coins for the rest"},
	{"pos": ORIGIN + Vector2(500, -40), "text": "The yard · throw, don't charge"},
]

## Who can find their own way here: graduates of ranger school, and
## anyone in its training (RangerSchoolQuest.TRAINING_FROM on).
static func admits(p: PlayerShape) -> bool:
	return RangerSchoolQuest.trained_or_training(p)


static func npcs() -> Array[Dictionary]:
	return [
		{
			"name": FERRYMAN, "at": ORIGIN + Vector2(-1450, 0), "sides": 4, "radius": 26.0,
			"role": "travel", "to": "barracks", "serves": "regulars",
			"lines": ["Back to the barracks? Sit still and don't look over the side."],
		},
		{
			"name": QUARTERMASTER, "at": ORIGIN + Vector2(-1050, 0), "sides": 3, "kind": "isosceles", "apex": 55,
			"radius": 28.0, "role": "ranger_quartermaster", "serves": "regulars",
			"wear": ["points_12", "plating_12", "", "eye_12", "voice_12"],
			"lines": [
				"Scout kit for chits, since you're new. Everything past that is coin.",
				"Rations keep. Thirty to a pouch. They won't fill you like the army's pork.",
				"Volley, charged shot, the double jump. Coin, not chits. Rangers aren't the army's.",
			],
		},
		{
			"name": "The Camp Medic", "at": ORIGIN + Vector2(-850, 0), "sides": 4, "radius": 26.0,
			"role": "healer", "serves": "regulars",
			"heal_area": Rect2(ORIGIN + Vector2(-1000, -300), Vector2(350, 320)),
			"lines": ["Took one in the corner? Next.", "Keep your distance and you won't need me."],
			"heal_lines": ["Patched. Stay out of reach this time.", "There. Mind their tips."],
		},
		{
			"name": INSTRUCTOR, "at": ORIGIN + Vector2(-400, 0), "sides": 3, "kind": "isosceles", "apex": 55,
			"radius": 28.0, "serves": "regulars",
			"wear": ["points_14", "plating_14", "", "eye_14", "voice_14"],
			"lines": [
				"A ranger never arrives where the enemy is. Only where he can see him.",
				"Throw, step back, throw. Let them come to you.",
				"Hold your charge till you flash. Not before. Not after.",
			],
		},
	]


## The yard's enemies, in world coordinates, as Cave.spawn_points.
static func spawn_points() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Array in DRILL:
		var info: Dictionary = Enemy.TYPES[entry[0]]
		out.append({
			"type": entry[0],
			"pos": ORIGIN + Vector2(entry[1], -float(info.radius) - 10.0),
			"room": YARD,
			"color": Palette.PARCHMENT_DARK if info.get("wild", false) else Palette.PLAIN,
			"respawn": entry[2],
		})
	return out


func _ready() -> void:
	position = ORIGIN
	collision_layer = PlayerShape.LAYER_TERRAIN
	collision_mask = 0
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 1.0
	_build_collision()


func _hot_reload() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_build_collision()
	queue_redraw()


func _build_collision() -> void:
	var ground := CollisionPolygon2D.new()
	ground.polygon = _ground_polygon()
	add_child(ground)


## The floor between two cliffs, as one solid piece.
func _ground_polygon() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(WEST_X - WALL, -CLIFF), Vector2(WEST_X, -CLIFF), Vector2(WEST_X, 0),
		Vector2(EAST_X, 0), Vector2(EAST_X, -CLIFF), Vector2(EAST_X + WALL, -CLIFF),
		Vector2(EAST_X + WALL, DEPTH), Vector2(WEST_X - WALL, DEPTH),
	])


func _draw() -> void:
	# The sea below the west cliff, in the Ocean's ink: a faint wash, a
	# wavy surface line and hatching below it.
	var edge := WEST_X - WALL
	var far := edge - SEA_WIDTH
	var surface := PackedVector2Array()
	var sx := far
	while sx <= edge:
		surface.append(Vector2(sx, SEA + sin(sx / 70.0) * 5.0))
		sx += 12.0
	var body := surface.duplicate()
	body.append(Vector2(edge, DEPTH + 800.0))
	body.append(Vector2(far, DEPTH + 800.0))
	draw_colored_polygon(body, Ocean.WATER)
	draw_polyline(surface, Palette.INK, 2.0, true)
	var wx := far + 20.0
	while wx < edge - 20.0:
		for depth in [40.0, 90.0, 150.0]:
			draw_line(Vector2(wx, SEA + depth), Vector2(wx + 26.0, SEA + depth), Ocean.HATCH, 1.5)
		wx += 64.0
	draw_colored_polygon(_ground_polygon(), Palette.PARCHMENT_DARK)
	var hatch := Color(Palette.INK_FADED, 0.25)
	var x := WEST_X + 8.0
	while x < EAST_X:
		draw_line(Vector2(x + 4, 6), Vector2(x - 8, 18), hatch, 1.5)
		x += 16.0
	for side: float in [WEST_X, EAST_X]:
		var y := -CLIFF + 20.0
		while y < -10.0:
			draw_line(Vector2(side, y), Vector2(side - signf(side) * 14.0, y + 12.0), hatch, 1.5)
			y += 22.0
	var line := PackedVector2Array([Vector2(WEST_X - WALL, -CLIFF), Vector2(WEST_X, -CLIFF), Vector2(WEST_X, -1.5),
			Vector2(EAST_X, -1.5), Vector2(EAST_X, -CLIFF), Vector2(EAST_X + WALL, -CLIFF)])
	draw_polyline(line, Palette.INK, 3.0, true)
	var font := ThemeDB.fallback_font
	for s: Dictionary in SIGNS:
		draw_string(font, (s.pos as Vector2) - ORIGIN + Vector2(-200, -60), s.text, HORIZONTAL_ALIGNMENT_CENTER, 400,
				18, Color(Palette.INK, 0.8))

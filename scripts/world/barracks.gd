class_name Barracks
extends StaticBody2D
## The barracks, west of the Center (design logs 0061, 0067-0072), drawn in
## ink on parchment like the Center. Triangles serve here, though any rank
## may (log 0073).
##
## The whole barracks stands up on one great island over the road (log
## 0232), bigger than any house's: two floating steps climb to its east tip
## from the road, which runs on beneath it, down a gentle valley and up
## again, to the coast. On the island, east to west: the Drill Sergeant at
## the top of the steps, the drill yard (wild shapes and sparring partners,
## for levels 1-5; it drops leather, log 0224), the Quartermaster (gear for
## pay), the Surgeon, and the General, who gives missions. Squads muster by
## the General and go to the front from there (Missions). Nobody stands on
## the road beneath.

const FLOOR_Y := 120.0
const EAST_X := CenterTerrain.LEFT_EDGE  # -2400, the gate
const WEST_X := -5400.0
const TOP := -1400.0
const BOTTOM := CenterTerrain.BOTTOM
const WALL_THICKNESS := 200.0

## The island: its top middle, width and belly (Mound data).
const ISLAND := {"at": Vector2(-4150, -165), "width": 2200.0, "depth": 110.0}
## The steps up from the road, east tip first downward: top middles. Each
## is a jump above the last (PlayerMotion: about 112 px), and the road
## dips beneath them, so a shape rolls under.
const STEPS: Array[Vector2] = [Vector2(-2900, -47), Vector2(-2750, 43)]
const STEP_WIDTH := 150.0
const STEP_DEPTH := 30.0

## The road beneath: a broad valley under the island, gentle both ways.
const VALLEY_EAST := Vector2(-2400, -3200)  # where it starts dipping, and where it's down
const VALLEY_WEST := Vector2(-4400, -5400)
const VALLEY_DEPTH := 120.0  # about 13° at the steepest

## The drill yard: the area its sparring partners keep to, on the island.
const YARD := Rect2(-4250, -600, 850, 480)
## Where squads come back to after a mission.
const MUSTER := Vector2(-4950, -220)

## The drill yard (design log 0072): [type, x, respawn seconds].
const DRILL: Array = [
	["dummy", -3500, 4.0],
	["dummy", -3650, 4.0],
	["dummy", -3800, 4.0],
	["sparring", -4000, 8.0],
	["sparring", -4150, 8.0],
]


## The island's top at `x`: where people stand on it.
static func island_y(x: float) -> float:
	return Mound.top_y(ISLAND, x)


static func mounds() -> Array[Dictionary]:
	var out: Array[Dictionary] = [ISLAND]
	for step in STEPS:
		out.append({"at": step, "width": STEP_WIDTH, "depth": STEP_DEPTH})
	return out


## The road, west (the coast) to east (the Center), as one smooth curve
## (Buildings.smooth): flat, down the valley under the island, up, flat.
static func surface_points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var steps := 6
	for i in steps + 1:  # down from the west
		var u := float(i) / steps
		out.append(Vector2(lerpf(VALLEY_WEST.y, VALLEY_WEST.x, u), FLOOR_Y + VALLEY_DEPTH * (1.0 - cos(u * PI)) / 2.0))
	for i in steps + 1:  # up to the east
		var u := float(i) / steps
		out.append(Vector2(lerpf(VALLEY_EAST.y, VALLEY_EAST.x, u), FLOOR_Y + VALLEY_DEPTH * (1.0 + cos(u * PI)) / 2.0))
	return out


static var _surface := PackedVector2Array()


static func surface() -> PackedVector2Array:
	if _surface.is_empty():
		_surface = Buildings.smooth(surface_points())
	return _surface


## The ground's y at `x`.
static func ground_y(x: float) -> float:
	return Buildings.y_at(surface(), x)

const SIGNS: Array[Dictionary] = [
	{"pos": Vector2(-2950, -260), "text": "The barracks ↑"},
	{"pos": Vector2(-3650, -330), "text": "The drill yard · spar until level 3–5"},
	{"pos": Vector2(-4700, -330), "text": "The General · missions"},
	{"pos": Vector2(-4960, -300), "text": "Squads muster here for the front"},
	{"pos": Vector2(-4000, 40), "text": "← The coast"},
]

## The barracks' people (World builds them as Npc), up on the island.
static func npcs() -> Array[Dictionary]:
	return [
		{
			# Gives the bootcamp quest's orders (BootcampQuest, design log 0181).
			# Dressed as on stage: full steel (BootcampQuest.SERGEANT_LOOK).
			"name": BootcampQuest.SERGEANT, "at": Vector2(-3250, island_y(-3250)), "sides": 3, "kind": "isosceles",
			"apex": BootcampQuest.SERGEANT_LOOK.apex, "wear": BootcampQuest.SERGEANT_LOOK.wear,
			# Sends ranger school's graduates to the rangers' island (log 0246).
			"radius": 28.0, "serves": "regulars", "role": "travel", "to": "camp",
			"send_line": "The island? Blindfold on, then. You know the drill.",
			"lines": [
				"Corners first, recruit! A face never hurt anybody.",
				"Hit the wild shapes till you're level three or so. Then go see the General.",
				"The recruits pull their punches. The Revolt won't.",
				"Jump again as you land. Off a corner you'll fly. Use it.",
			],
		},
		{
			"name": "The Quartermaster", "at": Vector2(-4400, island_y(-4400)), "sides": 3, "kind": "equilateral",
			"radius": 28.0, "role": "quartermaster", "serves": "regulars",
			"lines": [
				"Bronze, iron, steel, regimental. Pay first, wear after.",
				"Hardtack, cheese, salt pork. Eat before the march, not during.",
				"I teach drills too. Rush, nose dive, spike up. Pay for the lesson.",
				"No pigment here. Colour is the Revolt's business, not the army's.",
				"Leather? The drill yard's full of it. I sell metal.",
				"Regimental steel, with the regiment's red on every point. The one colour the law allows a soldier.",
			],
		},
		{
			"name": "The Surgeon", "at": Vector2(-4550, island_y(-4550)), "sides": 4, "radius": 26.0,
			"role": "healer", "serves": "regulars",
			"lines": ["Fit for duty. Next!", "Back in one piece. Keep it that way."],
			"heal_lines": ["Hold still. There. Fit for duty.", "Stitched and straightened. Off you go."],
		},
		{
			"name": "The General", "at": Vector2(-4750, island_y(-4750)), "sides": 5, "radius": 34.0,
			"role": "general", "serves": "regulars",
			"lines": [
				"The Revolt paints itself to hide its angles. Find them, and break them.",
				"Bring down one of their painted gentry and I'll sign your discharge. A certificate, soldier.",
				"Recon, invasion or a quiet knife in the dark. Choose.",
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
	queue_redraw()


## The drill yard's enemies, in world coordinates, as Cave.spawn_points.
static func spawn_points() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Array in DRILL:
		var info: Dictionary = Enemy.TYPES[entry[0]]
		var lift: float = info.radius + 10.0
		out.append({
			"type": entry[0],
			"pos": Vector2(entry[1], island_y(entry[1]) - lift),
			"room": YARD,
			"color": Palette.PARCHMENT_DARK if info.get("wild", false) else Palette.PLAIN,
			"respawn": entry[2],
		})
	return out


func _build_collision() -> void:
	var ground := CollisionPolygon2D.new()
	ground.polygon = _ground_polygon()
	add_child(ground)


func _ground_polygon() -> PackedVector2Array:
	# Open to the west: the coast carries on from WEST_X (log 0200).
	var poly := surface().duplicate()
	poly.append(Vector2(EAST_X, BOTTOM))
	poly.append(Vector2(WEST_X, BOTTOM))
	return poly


func _draw() -> void:
	draw_colored_polygon(_ground_polygon(), Palette.PARCHMENT_DARK)
	var hatch := Color(Palette.INK_FADED, 0.25)
	var x := WEST_X + 8.0
	while x < EAST_X:
		var y := ground_y(x)
		draw_line(Vector2(x + 4, y + 6), Vector2(x - 8, y + 18), hatch, 1.5)
		x += 16.0
	var line := surface().duplicate()
	for i in line.size():
		line[i].y -= 1.5
	draw_polyline(line, Palette.INK, 3.0, true)

	Buildings.draw_signs(self, SIGNS, Palette.INK)

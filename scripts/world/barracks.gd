class_name Barracks
extends StaticBody2D
## The barracks, west of the Center (design logs 0061, 0067-0072), drawn in
## ink on parchment like the Center. Triangles serve here, though any rank
## may (log 0073).
##
## East to west: the gate from the Center, the drill yard (straw dummies and
## sparring partners, for levels 1-5; it drops leather), the barracks halls,
## the Quartermaster (gear for pay), the Surgeon, and the General, who gives
## missions. Squads muster by the General and go to the front from there
## (Missions).

const FLOOR_Y := 120.0
const EAST_X := CenterTerrain.LEFT_EDGE  # -2400, the gate
const WEST_X := -5400.0
const TOP := -1400.0
const BOTTOM := CenterTerrain.BOTTOM
const WALL_THICKNESS := 200.0

## The drill yard's fence and the area its sparring partners keep to.
const YARD := Rect2(-3700, -400, 1100, FLOOR_Y + 400)
## Where squads come back to after a mission.
const MUSTER := Vector2(-4800, FLOOR_Y - 40)

## The drill yard (design log 0072): [type, x, respawn seconds].
const DRILL: Array = [
	["dummy", -2780, 4.0],
	["dummy", -2930, 4.0],
	["dummy", -3080, 4.0],
	["sparring", -3330, 8.0],
	["sparring", -3530, 8.0],
]

## Pentagon halls (overworld law, log 0060): x of the floor middle, width.
const HALLS: Array[Vector2] = [
	Vector2(-3850, 200),
	Vector2(-5150, 210),
]

const SIGNS: Array[Dictionary] = [
	{"pos": Vector2(-2600, -110), "text": "The barracks"},
	{"pos": Vector2(-3150, -110), "text": "The drill yard · spar until level 3–5"},
	{"pos": Vector2(-4600, -70), "text": "The General · missions"},
	{"pos": Vector2(-4960, 70), "text": "Squads muster here for the front"},
]

## The barracks' people (World builds them as Npc).
const NPCS: Array[Dictionary] = [
	{
		# Gives the bootcamp quest's orders (BootcampQuest, design log 0181).
		# Dressed as on stage: full steel (BootcampQuest.SERGEANT_LOOK).
		"name": BootcampQuest.SERGEANT, "at": Vector2(-2490, FLOOR_Y), "sides": 3, "kind": "isosceles",
		"apex": BootcampQuest.SERGEANT_LOOK.apex, "wear": BootcampQuest.SERGEANT_LOOK.wear,
		"radius": 28.0, "serves": "regulars",
		"lines": [
			"Corners first, recruit! A face never hurt anybody.",
			"Hit the straw till you're level three or so. Then go see the General.",
			"The recruits pull their punches. The Revolt won't.",
			"Jump again as you land. Off a corner you'll fly. Use it.",
		],
	},
	{
		"name": "The Quartermaster", "at": Vector2(-4180, FLOOR_Y), "sides": 3, "kind": "equilateral",
		"radius": 28.0, "role": "quartermaster", "serves": "regulars",
		"lines": [
			"Bronze, iron, steel. Pay first, wear after.",
			"Hardtack, cheese, salt pork. Eat before the march, not during.",
			"I teach drills too. Rush, nose dive, spike up. Pay for the lesson.",
			"No pigment here. Colour is the Revolt's business, not the army's.",
			"Leather? The drill yard's full of it. I sell metal.",
		],
	},
	{
		"name": "The Surgeon", "at": Vector2(-4380, FLOOR_Y), "sides": 4, "radius": 26.0,
		"role": "healer", "serves": "regulars",
		"lines": ["Fit for duty. Next!", "Back in one piece. Keep it that way."],
		"heal_lines": ["Hold still. There. Fit for duty.", "Stitched and straightened. Off you go."],
	},
	{
		"name": "The General", "at": Vector2(-4600, FLOOR_Y), "sides": 5, "radius": 34.0,
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
		var lift: float = info.radius + (Enemy.STAKE if info.get("still", false) else 10.0)
		out.append({
			"type": entry[0],
			"pos": Vector2(entry[1], FLOOR_Y - lift),
			"room": YARD,
			"color": Palette.PARCHMENT_DARK if info.get("still", false) else Palette.PLAIN,
			"respawn": entry[2],
		})
	return out


func _build_collision() -> void:
	var ground := CollisionPolygon2D.new()
	ground.polygon = _ground_polygon()
	add_child(ground)


func _ground_polygon() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(WEST_X - WALL_THICKNESS, TOP),
		Vector2(WEST_X, TOP),
		Vector2(WEST_X, FLOOR_Y),
		Vector2(EAST_X, FLOOR_Y),
		Vector2(EAST_X, BOTTOM),
		Vector2(WEST_X - WALL_THICKNESS, BOTTOM),
	])


func _draw() -> void:
	draw_colored_polygon(_ground_polygon(), Palette.PARCHMENT_DARK)
	var hatch := Color(Palette.INK_FADED, 0.25)
	var x := WEST_X + 8.0
	while x < EAST_X:
		draw_line(Vector2(x + 4, FLOOR_Y + 6), Vector2(x - 8, FLOOR_Y + 18), hatch, 1.5)
		x += 16.0
	draw_line(Vector2(WEST_X, FLOOR_Y - 1.5), Vector2(EAST_X, FLOOR_Y - 1.5), Palette.INK, 3.0, true)
	draw_line(Vector2(WEST_X, TOP), Vector2(WEST_X, FLOOR_Y), Palette.INK, 3.0, true)

	_draw_fence()
	for hall in HALLS:
		Buildings.draw_house(self, Vector2(hall.x, FLOOR_Y), hall.y, Palette.PARCHMENT_LIGHT, Palette.INK)
	_draw_tent(Vector2(-4600, FLOOR_Y), 260.0, 190.0)
	_draw_crates(Vector2(-4090, FLOOR_Y))
	_draw_flag(Vector2(-4800, FLOOR_Y))

	var font := ThemeDB.fallback_font
	for s in SIGNS:
		var pos: Vector2 = s.pos
		draw_line(pos + Vector2(0, -30), pos + Vector2(0, 50), Palette.INK_FADED, 2.0)
		draw_string(font, pos + Vector2(-200, -38), s.text, HORIZONTAL_ALIGNMENT_CENTER, 400, 20, Palette.INK)


## The drill yard's rail fence, one post every 100 px along each end.
func _draw_fence() -> void:
	for end_x in [YARD.position.x, YARD.end.x]:
		for k in 3:
			var post_x: float = end_x + (k - 1) * 40.0
			draw_line(Vector2(post_x, FLOOR_Y), Vector2(post_x, FLOOR_Y - 60), Palette.INK, 3.0)
		draw_line(Vector2(end_x - 50, FLOOR_Y - 45), Vector2(end_x + 50, FLOOR_Y - 45), Palette.INK, 2.5)
		draw_line(Vector2(end_x - 50, FLOOR_Y - 20), Vector2(end_x + 50, FLOOR_Y - 20), Palette.INK, 2.5)


## The General's command tent: a canvas triangle with an open flap.
func _draw_tent(base: Vector2, width: float, height: float) -> void:
	var tent := PackedVector2Array([base + Vector2(-width / 2.0, 0), base + Vector2(width / 2.0, 0),
			base + Vector2(0, -height)])
	draw_colored_polygon(tent, Palette.PARCHMENT_LIGHT)
	Gear.draw_hatch(self, tent, [[20.0], 14.0], 1.0, Color(Palette.INK, 0.12))
	var outline := tent.duplicate()
	outline.append(tent[0])
	draw_polyline(outline, Palette.INK, 3.0, true)
	draw_line(base + Vector2(0, -height), base + Vector2(0, -height - 30), Palette.INK, 2.5)


## The Quartermaster's stacked supply crates.
func _draw_crates(base: Vector2) -> void:
	for box: Rect2 in [Rect2(base + Vector2(0, -50), Vector2(60, 50)), Rect2(base + Vector2(64, -40), Vector2(46, 40)),
			Rect2(base + Vector2(18, -92), Vector2(44, 42))]:
		draw_rect(box, Palette.PARCHMENT_LIGHT)
		draw_line(box.position, box.end, Color(Palette.INK, 0.4), 1.5)
		draw_line(Vector2(box.position.x, box.end.y), Vector2(box.end.x, box.position.y), Color(Palette.INK, 0.4), 1.5)
		draw_rect(box, Palette.INK, false, 2.5)


## The muster flag. Plain cloth: the army has no colours.
func _draw_flag(base: Vector2) -> void:
	draw_line(base, base + Vector2(0, -200), Palette.INK, 3.0)
	var cloth := PackedVector2Array([base + Vector2(0, -200), base + Vector2(70, -185), base + Vector2(0, -160)])
	draw_colored_polygon(cloth, Palette.PARCHMENT_LIGHT)
	Gear.draw_hatch(self, cloth, [[45.0, -45.0], 8.0], 1.0, Color(Palette.INK, 0.4))
	cloth.append(cloth[0])
	draw_polyline(cloth, Palette.INK, 2.0, true)

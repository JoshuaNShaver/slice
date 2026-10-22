class_name Coast
extends StaticBody2D
## The west coast, past the barracks (design logs 0200-0202), in ink on
## parchment like the barracks. Workmen only: a triangle with a 45°+ apex,
## or any higher rank (Regions "workmen"); the Harbour Watch turns sharper
## ones back at the gate (hold_back).
##
## East to west: the gate, a slope down to the shore, the dock (the Dock
## Tradesman buys logs for chits, log 0204; the Boatwright launches boats,
## log 0201), a pier, the open sea (Ocean), and the Logging Isle, with its
## own pier and boatwright and a row of great trees (Timber, log 0202).
## Past the isle the sea runs on to the world's west edge.
##
## Everyone builds the same coast from data (World); the trees and boats
## are spawned by the server.

const EAST_X := Barracks.WEST_X  # -5400, where the barracks end
const WEST_X := -16000.0  # the world's west edge, out at sea
const FLOOR_Y := Barracks.FLOOR_Y  # 120, the barracks' ground
const SHORE_Y := 380.0  # the dock and the isle, a little above the sea
const SEA_LEVEL := 420.0  # the calm sea (Ocean.LEVEL)
const SEABED_Y := 1000.0
const BOTTOM := 1150.0
const TOP := -2400.0
const WALL_THICKNESS := 200.0

const GATE_X := -5700.0  # the Harbour Watch's post
## Where the shore drops into the sea, and where the isle's top ends east and west.
const SHORE_EDGE := -7500.0
const ISLAND_EAST_TOP := -12150.0
const ISLAND_WEST_TOP := -13900.0
## Piers (x from, x to), their planks' top at SHORE_Y.
const PIERS: Array[Vector2] = [Vector2(-7760, SHORE_EDGE), Vector2(ISLAND_EAST_TOP, -11900)]
const PLANK := 14.0  # px thick
## Where you wake after drowning (log 0201).
const SHORE_SPAWN := Vector2(-7000, SHORE_Y - 40)

## The ground's surface, west to east.
const SURFACE: Array[Vector2] = [
	Vector2(WEST_X, SEABED_Y),
	Vector2(-14200, SEABED_Y),
	Vector2(ISLAND_WEST_TOP, SHORE_Y),
	Vector2(ISLAND_EAST_TOP, SHORE_Y),
	Vector2(-11850, SEABED_Y),
	Vector2(-7800, SEABED_Y),
	Vector2(SHORE_EDGE, SHORE_Y),
	Vector2(-6900, SHORE_Y),
	Vector2(-5900, FLOOR_Y),  # ~15° down from the gate
	Vector2(EAST_X, FLOOR_Y),
]

## The isle's trees (Timber): the x of each trunk's foot.
const TREES: Array[float] = [-12500.0, -12730.0, -12960.0, -13190.0, -13420.0, -13650.0]

const SIGNS: Array[Dictionary] = [
	{"pos": Vector2(-5560, FLOOR_Y - 110), "text": "The coast · workmen only"},
	{"pos": Vector2(-7330, SHORE_Y - 110), "text": "The dock · logs bought here"},
	{"pos": Vector2(-12380, SHORE_Y - 110), "text": "The Logging Isle"},
]

const WATCH := "The Harbour Watch"

## The coast's people (World builds them as Npc).
const NPCS: Array[Dictionary] = [
	{
		"name": WATCH, "at": Vector2(GATE_X + 70, FLOOR_Y), "sides": 4, "radius": 26.0,
		"serves": "workmen",
		"lines": [
			"Down to the dock, workman. Mind the water: it doesn't give back what it takes.",
			"Logs come in from the isle. The Dock Tradesman pays in chits.",
			"Fall in out there and you'll wake on the shore with empty pockets. Every time.",
		],
		"refusals": [
			"Workmen only past this post. Soldiers, back to the yard.",
			"A point that sharp is for the front, not the woodpile. Off you go.",
			"No. Widen that apex a few generations and come back.",
		],
	},
	{
		"name": "The Dock Tradesman", "at": Vector2(-7250, SHORE_Y), "sides": 3, "kind": "equilateral",
		"radius": 28.0, "role": "dock", "serves": "workmen",
		"lines": [
			"Logs! Bring me logs. Two hundred chits apiece, army scrip, good at the Quartermaster.",
			"The isle's trees are older than the Circle. Jump at them till they give.",
		],
	},
	{
		"name": "The Boatwright", "at": Vector2(-7420, SHORE_Y), "sides": 3, "kind": "isosceles", "apex": 50.0,
		"radius": 27.0, "role": "boats", "serves": "workmen",
		"launch": Vector2(-7880, SEA_LEVEL - 25), "facing": -1,
		"lines": [
			"Lean into the sail and she'll run. Lean too long and she'll roll you under.",
			"Turn her about to come alongside. The sail's in your way otherwise.",
		],
	},
	{
		"name": "The Boatwright's Mate", "at": Vector2(-12290, SHORE_Y), "sides": 3, "kind": "isosceles",
		"apex": 45.0, "radius": 26.0, "role": "boats", "serves": "workmen",
		"launch": Vector2(-11780, SEA_LEVEL - 25), "facing": 1,
		"lines": ["Need a boat home? Fill your bag first. Logs don't fetch themselves."],
	},
]

## Seconds between the Watch's warnings to the same player.
const WARN_EVERY := 3.0
static var _warned := {}  # peer id -> ms of the last warning


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


## The ground's surface y at `x`; -INF outside the coast (no sea there).
static func ground_y(x: float) -> float:
	if x < WEST_X or x > EAST_X:
		return -INF
	for i in range(1, SURFACE.size()):
		var a := SURFACE[i - 1]
		var b := SURFACE[i]
		if x <= b.x:
			return lerpf(a.y, b.y, inverse_lerp(a.x, b.x, x))
	return SURFACE[-1].y


## Server only, each physics step of a player's (PlayerMotion): the Watch
## turns back anyone the coast isn't for (log 0200).
static func hold_back(p: PlayerShape, state: PhysicsDirectBodyState2D) -> void:
	var pos := state.transform.origin
	if pos.x >= GATE_X or pos.x < GATE_X - 600.0 or pos.y > SHORE_Y + 200.0:
		return
	if Regions.admits("workmen", p.sides, p.kind, p.apex):
		return
	state.transform.origin.x = GATE_X + 2.0
	state.linear_velocity.x = maxf(absf(state.linear_velocity.x) * 0.5, 120.0)
	var now := Time.get_ticks_msec()
	if now - int(_warned.get(p.peer_id, -100000)) > WARN_EVERY * 1000.0:
		_warned[p.peer_id] = now
		p.screen.tell(WATCH, (NPCS[0].refusals as Array).pick_random())


func _build_collision() -> void:
	var ground := CollisionPolygon2D.new()
	ground.polygon = _ground_polygon()
	add_child(ground)
	for pier in PIERS:
		var plank := CollisionPolygon2D.new()
		plank.polygon = _plank(pier)
		add_child(plank)


func _ground_polygon() -> PackedVector2Array:
	var poly := PackedVector2Array([Vector2(WEST_X - WALL_THICKNESS, TOP), Vector2(WEST_X, TOP)])
	for p in SURFACE:
		poly.append(p)
	poly.append(Vector2(EAST_X, BOTTOM))
	poly.append(Vector2(WEST_X - WALL_THICKNESS, BOTTOM))
	return poly


static func _plank(pier: Vector2) -> PackedVector2Array:
	return PackedVector2Array([Vector2(pier.x, SHORE_Y), Vector2(pier.y, SHORE_Y),
			Vector2(pier.y, SHORE_Y + PLANK), Vector2(pier.x, SHORE_Y + PLANK)])


func _draw() -> void:
	draw_colored_polygon(_ground_polygon(), Palette.PARCHMENT_DARK)
	var hatch := Color(Palette.INK_FADED, 0.25)
	for i in range(1, SURFACE.size()):
		var a := SURFACE[i - 1]
		var b := SURFACE[i]
		var x := a.x + 8.0
		while x < b.x:
			var y := lerpf(a.y, b.y, inverse_lerp(a.x, b.x, x))
			draw_line(Vector2(x + 4, y + 6), Vector2(x - 8, y + 18), hatch, 1.5)
			x += 16.0
	var line := PackedVector2Array(SURFACE)
	draw_polyline(line, Palette.INK, 3.0, true)
	draw_line(Vector2(WEST_X, TOP), Vector2(WEST_X, SEABED_Y), Palette.INK, 3.0, true)

	_draw_gate()
	for pier in PIERS:
		_draw_pier(pier)
	Buildings.draw_house(self, Vector2(-6700, SHORE_Y), 200.0, Palette.PARCHMENT_LIGHT, Palette.INK)
	_draw_log_pile(Vector2(-7190, SHORE_Y))

	var font := ThemeDB.fallback_font
	for s in SIGNS:
		var pos: Vector2 = s.pos
		draw_line(pos + Vector2(0, -30), pos + Vector2(0, 110), Palette.INK_FADED, 2.0)
		draw_string(font, pos + Vector2(-200, -38), s.text, HORIZONTAL_ALIGNMENT_CENTER, 400, 20, Palette.INK)


## The Watch's post: two posts and a raised bar.
func _draw_gate() -> void:
	for x in [GATE_X - 30.0, GATE_X + 30.0]:
		draw_line(Vector2(x, FLOOR_Y), Vector2(x, FLOOR_Y - 120), Palette.INK, 4.0)
	draw_line(Vector2(GATE_X + 30, FLOOR_Y - 110), Vector2(GATE_X - 60, FLOOR_Y - 190), Palette.INK, 3.0)


## A pier: planks on posts that run down into the sea.
func _draw_pier(pier: Vector2) -> void:
	var plank := _plank(pier)
	draw_colored_polygon(plank, Palette.PARCHMENT_LIGHT)
	var x := pier.x + 20.0
	while x < pier.y:
		draw_line(Vector2(x, SHORE_Y + PLANK), Vector2(x, maxf(ground_y(x), SHORE_Y + PLANK)), Palette.INK, 3.0)
		x += 80.0
	plank.append(plank[0])
	draw_polyline(plank, Palette.INK, 2.5, true)
	var seam := pier.x + 26.0
	while seam < pier.y:
		draw_line(Vector2(seam, SHORE_Y + 2), Vector2(seam, SHORE_Y + PLANK - 2), Palette.INK_FADED, 1.0)
		seam += 26.0


## Logs stacked by the Dock Tradesman: circles of cut ends.
func _draw_log_pile(base: Vector2) -> void:
	var r := 14.0
	for row in 3:
		for k in 4 - row:
			var c := base + Vector2(k * r * 2.0 + row * r, -r - row * r * 1.7)
			draw_circle(c, r, Palette.PARCHMENT_LIGHT)
			draw_arc(c, r, 0.0, TAU, 20, Palette.INK, 2.0, true)
			draw_arc(c, r * 0.5, 0.0, TAU, 14, Palette.INK_FADED, 1.0, true)

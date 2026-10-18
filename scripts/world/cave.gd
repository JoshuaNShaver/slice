class_name Cave
extends StaticBody2D
## The training cave (design log 0027), in the underworld (log 0051). Its
## mouth opens off the west end of the Undercroft. Inside are three rooms,
## each a different chalk color, and each harder than the last: rose, then
## mint, then lilac. The Pretender, the boss, waits at the back of the lilac
## room. Drawn in chalk on slate, like the rest of the underworld (log 0056).
##
## The layout below is in the cave's own coordinates, with its floor at
## y = 120; the node sits at OFFSET, which puts that floor on the
## Undercroft's. Rock pillars hang between rooms, leaving a gap to roll under.

const FLOOR_Y := 120.0
const OFFSET := Vector2(0, Underworld.FLOOR_Y - FLOOR_Y)
const MOUTH_X := Underworld.WEST_X  # -2400
const WEST_X := -6400.0
const TOP := -1100.0
const WALL_THICKNESS := 200.0

## The cave's ceiling, east (the mouth) to west. The rock above it is solid.
const CEILING: Array[Vector2] = [
	Vector2(MOUTH_X, -60),
	Vector2(-2700, -60),  # the mouth tunnel
	Vector2(-2760, -260),
	Vector2(-3700, -260),  # rose room
	Vector2(-3700, -40),
	Vector2(-3780, -40),  # pillar
	Vector2(-3780, -280),
	Vector2(-4780, -280),  # mint room
	Vector2(-4780, -40),
	Vector2(-4860, -40),  # pillar
	Vector2(-4900, -440),
	Vector2(WEST_X, -440),  # lilac room and the boss's hall
]

## Each room: its area (enemies only chase players inside it), color, and
## spawns. The boss gets its own area at the back, so you can train on the
## lilac zealots without waking it.
const ROOMS: Array[Dictionary] = [
	{
		"name": "The Rose Hollow", "area": Rect2(-3700, -260, 940, 380), "color": 0,
		"spawns": [["bandit", -2950], ["bandit", -3200], ["bandit", -3420], ["bandit", -3620]],
	},
	{
		"name": "The Mint Gallery", "area": Rect2(-4780, -280, 1000, 400), "color": 3,
		"spawns": [["brute", -4000], ["brute", -4250], ["brute", -4500], ["brute", -4700]],
	},
	{
		"name": "The Lilac Deep", "area": Rect2(-5500, -440, 640, 560), "color": 5,
		"spawns": [["zealot", -5050], ["zealot", -5250], ["zealot", -5440]],
	},
	{
		"name": "", "area": Rect2(WEST_X, -440, 900, 560), "color": 5,
		"spawns": [["pretender", -6000]],
	},
]

const SIGNS: Array[Dictionary] = [
	{"pos": Vector2(-2560, 70), "text": "The cave (levels 1–20)"},
	{"pos": Vector2(-2860, 70), "text": "The Rose Hollow · bandits, levels 1–7"},
	{"pos": Vector2(-3900, 70), "text": "The Mint Gallery · brutes, levels 7–14"},
	{"pos": Vector2(-4990, 70), "text": "The Lilac Deep · zealots, levels 14–20"},
	{"pos": Vector2(-5560, 70), "text": "Beyond: the Pretender (level 20)"},
]


func _ready() -> void:
	position = OFFSET
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


## Where enemies stand, in world coordinates:
## [{"type", "pos", "room": Rect2, "color": Color}].
static func spawn_points() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for room: Dictionary in ROOMS:
		for spawn: Array in room.spawns:
			var radius: float = Enemy.TYPES[spawn[0]].radius
			out.append({
				"type": spawn[0],
				"pos": Vector2(spawn[1], FLOOR_Y - radius - 10) + OFFSET,
				"room": Rect2(room.area.position + OFFSET, room.area.size),
				"color": room_color(room),
			})
	return out


static func room_color(room: Dictionary) -> Color:
	return Palette.CHALK[room.color].darkened(0.12)


func _build_collision() -> void:
	var rock := CollisionPolygon2D.new()
	rock.polygon = _rock_polygon()
	add_child(rock)
	var ground := CollisionPolygon2D.new()
	ground.polygon = _floor_polygon()
	add_child(ground)


## The hill and the west wall, down to the ceiling.
func _rock_polygon() -> PackedVector2Array:
	var poly := PackedVector2Array([Vector2(MOUTH_X, TOP)])
	poly.append_array(PackedVector2Array(CEILING))
	poly.append(Vector2(WEST_X, FLOOR_Y))
	poly.append(Vector2(WEST_X - WALL_THICKNESS, FLOOR_Y))
	poly.append(Vector2(WEST_X - WALL_THICKNESS, TOP))
	return poly


func _floor_polygon() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(WEST_X - WALL_THICKNESS, FLOOR_Y),
		Vector2(MOUTH_X, FLOOR_Y),
		Vector2(MOUTH_X, Underworld.BOTTOM - OFFSET.y),
		Vector2(WEST_X - WALL_THICKNESS, Underworld.BOTTOM - OFFSET.y),
	])


func _draw() -> void:
	# Each room's air is tinted its color.
	var tunnel := Rect2(-2760, -60, 360, FLOOR_Y + 60)
	draw_rect(tunnel, Color(Palette.CHALK_LINE, 0.04))
	for room: Dictionary in ROOMS:
		var color := Palette.CHALK[room.color]
		color.a = 0.45
		draw_rect(Rect2(room.area.position, Vector2(room.area.size.x, FLOOR_Y - room.area.position.y)), color)

	draw_colored_polygon(_rock_polygon(), Palette.SLATE_DARK)
	draw_colored_polygon(_floor_polygon(), Palette.SLATE_DARK)
	_draw_hatching(PackedVector2Array(CEILING), Vector2(-4, -6), Vector2(8, -18))
	_draw_hatching(PackedVector2Array([Vector2(WEST_X, FLOOR_Y), Vector2(MOUTH_X, FLOOR_Y)]),
			Vector2(4, 6), Vector2(-8, 18))

	var ceiling := PackedVector2Array(CEILING)
	ceiling.append(Vector2(WEST_X, FLOOR_Y))
	draw_polyline(ceiling, Palette.CHALK_LINE, 3.0, true)
	draw_line(Vector2(WEST_X, FLOOR_Y - 1.5), Vector2(MOUTH_X, FLOOR_Y - 1.5), Palette.CHALK_LINE, 3.0, true)
	# The rock face above the mouth.
	draw_line(Vector2(MOUTH_X, Underworld.ceiling()[0].y - OFFSET.y), Vector2(MOUTH_X, CEILING[0].y),
			Palette.CHALK_LINE, 3.0, true)

	var font := ThemeDB.fallback_font
	for s in SIGNS:
		var pos: Vector2 = s.pos
		draw_line(pos + Vector2(0, -20), pos + Vector2(0, 50), Palette.CHALK_FADED, 2.0)
		draw_string(font, pos + Vector2(-200, -28), s.text, HORIZONTAL_ALIGNMENT_CENTER, 400, 18, Palette.CHALK_LINE)


func _draw_hatching(line: PackedVector2Array, from: Vector2, to: Vector2) -> void:
	var color := Color(Palette.CHALK_FADED, 0.25)
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		var count := int(a.distance_to(b) / 16.0)
		for k in count:
			var p := a.lerp(b, (k + 0.5) / count)
			draw_line(p + from, p + to, color, 1.5)

class_name CenterTerrain
extends StaticBody2D
## The Center, the respawn hub (DESIGN §1), drawn in ink on parchment.
##
## Ground level at the plaza is y = 0 and screen-down is south. The land rises
## to the east (upper class) and sinks to the west (the war front). Ledges
## climb north toward the priests, and a sealed hatch marks the way south.
## Region exits are walls until those regions exist.

const SPAWN_POINT := Vector2(0, -80)
const LEFT_EDGE := -2400.0
const RIGHT_EDGE := 2400.0

## The walkable surface, west wall to east wall. The solid ground is below it.
const SURFACE: Array[Vector2] = [
	Vector2(LEFT_EDGE, -900),
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
	Vector2(RIGHT_EDGE, -900),
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
	{"pos": Vector2(-560, 70), "text": "← West: the war front"},
	{"pos": Vector2(820, -160), "text": "East: the upper districts →"},
	{"pos": Vector2(120, -500), "text": "↑ North: the priests"},
	{"pos": Vector2(-1040, 70), "text": "↓ South: the underworld (sealed)"},
	{"pos": Vector2(0, -20), "text": "The Center"},
]
const HATCH := Rect2(-1100, 112, 120, 8)


func _ready() -> void:
	collision_layer = PlayerShape.LAYER_TERRAIN
	collision_mask = 0
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 1.0

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
	draw_polyline(PackedVector2Array(SURFACE), Palette.INK, 3.0, true)

	for ledge in LEDGES:
		var rect := Rect2(ledge.x, ledge.y, ledge.z, 16)
		draw_rect(rect, Palette.PARCHMENT_LIGHT)
		draw_rect(rect, Palette.INK, false, 2.5)

	draw_rect(HATCH, Palette.CHALK[5])
	draw_rect(HATCH, Palette.INK, false, 2.0)

	var font := ThemeDB.fallback_font
	for s in SIGNS:
		var pos: Vector2 = s.pos
		draw_line(pos + Vector2(0, -30), pos + Vector2(0, 50), Palette.INK_FADED, 2.0)
		draw_string(font, pos + Vector2(-200, -38), s.text, HORIZONTAL_ALIGNMENT_CENTER, 400, 20, Palette.INK)


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

class_name FlatMap
extends Node2D
## What a Flatlander's eyes look through (FlatView, design log 0249): the
## plane's solid things and nothing else, no lettering, scenery or ink.
## Every collision shape near the eye is filled flat in its kind's colour:
## ground, walls, houses and boats ink (chalk underground); people (players,
## NPCs, guards, enemies) white, or their paint where they're coloured (a
## Revolt's red, the Undercroft's chalk-coloured folk); and the sea, which
## isn't solid, in WATER. Drawn in world coordinates; FlatView moves the
## picture to the eye.

const MAX_SHAPES := 512  # convex pieces near the eye
const PERSON := Color.WHITE
const WATER := Color("5b8fb9")

var space: RID  # the world's physics space
var eye := Vector2.ZERO
var reach := 450.0
var under := 0.0  # 0 above ground, 1 underground
var exclude: Array[RID] = []  # the eye's own body

var _query := PhysicsShapeQueryParameters2D.new()
var _box := RectangleShape2D.new()


func _draw() -> void:
	if not space.is_valid():
		return
	_draw_sea()
	_box.size = Vector2.ONE * reach * 2.0
	_query.shape = _box
	_query.transform = Transform2D(0.0, eye)
	_query.collide_with_areas = false
	_query.collision_mask = 0xFFFFFFFF
	_query.exclude = exclude
	var state := PhysicsServer2D.space_get_direct_state(space)
	if state == null:
		return
	var ink := Palette.INK.lerp(Palette.CHALK_LINE, under)
	for hit: Dictionary in state.intersect_shape(_query, MAX_SHAPES):
		var body := hit.collider as CollisionObject2D
		if body == null:
			continue
		var rid: RID = hit.rid
		var index: int = hit.shape
		var shape := PhysicsServer2D.body_get_shape(rid, index)
		var xf := body.global_transform * PhysicsServer2D.body_get_shape_transform(rid, index)
		_draw_shape(shape, xf, _color_of(body, PhysicsServer2D.shape_get_type(shape), ink))


func _draw_shape(shape: RID, xf: Transform2D, color: Color) -> void:
	var data: Variant = PhysicsServer2D.shape_get_data(shape)
	match PhysicsServer2D.shape_get_type(shape):
		PhysicsServer2D.SHAPE_CONVEX_POLYGON:
			var pts: PackedVector2Array = data
			if pts.size() >= 3:
				draw_colored_polygon(xf * pts, color)
		PhysicsServer2D.SHAPE_RECTANGLE:
			var half: Vector2 = data
			draw_colored_polygon(xf * PackedVector2Array([-half, Vector2(half.x, -half.y), half,
					Vector2(-half.x, half.y)]), color)
		PhysicsServer2D.SHAPE_CIRCLE:
			draw_circle(xf.origin, float(data) * xf.get_scale().x, color)
		PhysicsServer2D.SHAPE_SEGMENT:
			var seg: Rect2 = data  # a in position, b in size
			draw_line(xf * seg.position, xf * seg.size, color, 6.0)
		PhysicsServer2D.SHAPE_CONCAVE_POLYGON:
			var segs: PackedVector2Array = data
			for i in range(0, segs.size() - 1, 2):
				draw_line(xf * segs[i], xf * segs[i + 1], color, 6.0)


## People are white, or their paint; everything else solid is ground.
func _color_of(body: CollisionObject2D, type: int, ink: Color) -> Color:
	var paint := Color(0, 0, 0, 0)
	if body is PlayerShape:
		return PERSON
	if body is Enemy:
		paint = body.get("_color")
	elif body.get_parent() is Npc:
		paint = (body.get_parent() as Npc).color
	elif body.get_parent() is Elevator:
		# Its guards are polygons; its hatch and platform, rectangles.
		return PERSON if type == PhysicsServer2D.SHAPE_CONVEX_POLYGON else ink
	else:
		return ink
	return paint if _colourful(paint) else PERSON


static func _colourful(c: Color) -> bool:
	return c.a > 0.0 and c.s > 0.35


## Open water near the eye, as Ocean draws it (log 0201).
func _draw_sea() -> void:
	for span in Ocean.spans():  # the western sea and any other (log 0250)
		var left := maxf(eye.x - reach, span.x)
		var right := minf(eye.x + reach, span.y)
		if left < right:
			_draw_water(left, right)


func _draw_water(left: float, right: float) -> void:
	for stretch: Array in Ocean.stretches(left, right, Ocean.now()):
		var top: PackedVector2Array = stretch[0]
		var bottom: PackedVector2Array = stretch[1]
		var poly := top.duplicate()
		for i in range(bottom.size() - 1, -1, -1):
			poly.append(bottom[i])
		if top.size() >= 2 and not Geometry2D.triangulate_polygon(poly).is_empty():
			draw_colored_polygon(poly, WATER)

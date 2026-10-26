class_name House
extends StaticBody2D
## A house you can go into (design log 0222). Nothing in the plane is
## scenery (log 0221): its walls, floors and roof are solid, drawn at the
## thickness they have, and its doors are gaps in the walls.
##
## Lawful houses (overworld) are Buildings.draw_house's pentagon: the men's
## door on the west, the women's slit on the east (no polygon fits), the
## rooms climbing inside. Crooked houses (underworld, log 0059) are any
## outline, with a door at the foot of each side wall: below, you roll
## right through.
##
## Every peer builds the same houses from data (each terrain's HOUSES).

const DOOR_HEIGHT := 130.0  # a crooked house's doors, px
const CROOKED_WALL := 16.0

var base := Vector2.ZERO  # the middle of its floor
var width := Buildings.HOUSE_WIDTH
var fill := Palette.PARCHMENT_LIGHT
var ink := Palette.INK
var label := ""
## Crooked houses: the outline, offsets from `base` (y up is negative),
## running from the west foot round to the east foot.
var outline: Array = []
## Crooked houses: inner floors, each [from, to] (offsets from `base`),
## where residents stand off the road (log 0236).
var floors: Array = []


## data: {"at" (floor middle), "width", "fill", "ink", "label", "outline",
## "floors"}. Only "at" is required; an "outline" makes it crooked.
static func create(data: Dictionary) -> House:
	var h := House.new()
	h.base = data.at
	h.width = data.get("width", Buildings.HOUSE_WIDTH)
	h.fill = data.get("fill", Palette.PARCHMENT_LIGHT)
	h.ink = data.get("ink", Palette.INK)
	h.label = data.get("label", "")
	h.outline = data.get("outline", [])
	h.floors = data.get("floors", [])
	return h


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


## Where a resident of `room` stands (Buildings.ROOMS), spot `i`: the floor
## point under them, for an NPC's "at".
static func room_spot(at: Vector2, room: String, i := 0, w := Buildings.HOUSE_WIDTH) -> Vector2:
	var r := w / 1.902
	var floor_point := Buildings.house_point(at, w, Buildings.ROOMS[room][i])
	return floor_point - Vector2(0, Buildings.wall_thickness(r, false) / 2.0)


## Every solid piece, as [from, to, thickness] in world px.
func solids() -> Array:
	var out := []
	if outline.is_empty():
		var r := width / 1.902
		for seg: Array in Buildings.outer_walls(r):
			out.append([_unit(seg[0]), _unit(seg[1]), Buildings.wall_thickness(r, true)])
		for seg: Array in Buildings.INNER_WALLS:
			out.append([_unit(seg[0]), _unit(seg[1]), Buildings.wall_thickness(r, false)])
		return out
	var pts: Array[Vector2] = []
	for p: Vector2 in outline:
		pts.append(base + p)
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		# The first and last walls stand on the ground: cut a door out of their feet.
		if i == 1:
			a = _above_door(a, b)
		elif i == pts.size() - 1:
			b = _above_door(b, a)
		if a != b:
			out.append([a, b, CROOKED_WALL])
	for f: Array in floors:
		out.append([base + (f[0] as Vector2), base + (f[1] as Vector2), CROOKED_WALL])
	return out


## The point on a wall from its `foot` toward `top` that is DOOR_HEIGHT
## above the ground (or `top` itself, if the wall is lower than a door).
func _above_door(foot: Vector2, top: Vector2) -> Vector2:
	var rise := foot.y - top.y
	if rise <= DOOR_HEIGHT:
		return top
	return foot.lerp(top, DOOR_HEIGHT / rise)


func _unit(p: Vector2) -> Vector2:
	return Buildings.house_point(base, width, p)


func _build_collision() -> void:
	for piece: Array in solids():
		var shape := CollisionPolygon2D.new()
		shape.polygon = _slab(piece[0], piece[1], piece[2])
		add_child(shape)


## A segment from `a` to `b`, `t` thick, as a box (its ends squared off
## half a thickness past them, so joints close).
static func _slab(a: Vector2, b: Vector2, t: float) -> PackedVector2Array:
	var along := (b - a).normalized() * t / 2.0
	var side := along.orthogonal()
	return PackedVector2Array([a - along - side, b + along - side, b + along + side, a - along + side])


func _draw() -> void:
	if outline.is_empty():
		Buildings.draw_house(self, base, width, fill, ink, label, Color.TRANSPARENT, true)
		return
	var pts := PackedVector2Array()
	for p: Vector2 in outline:
		pts.append(base + p)
	draw_colored_polygon(pts, fill)
	_draw_patches(pts)
	for piece: Array in solids():
		draw_line(piece[0], piece[1], ink, piece[2])
	if label != "":
		var top := INF
		for p in pts:
			top = minf(top, p.y)
		draw_string(ThemeDB.fallback_font, Vector2(base.x - 150, top - 16), label, HORIZONTAL_ALIGNMENT_CENTER,
				300, 17, ink)


## Cross-hatching on a crooked house's walls: they're patched.
func _draw_patches(pts: PackedVector2Array) -> void:
	var shade := Color(ink, 0.18)
	var top := INF
	var left := INF
	var right := -INF
	for p in pts:
		top = minf(top, p.y)
		left = minf(left, p.x)
		right = maxf(right, p.x)
	var x := left + 10.0
	while x < right - 10.0:
		var y := top + fposmod(x * 1.7, 40.0) + 16.0
		while y < base.y - 20.0:
			if Geometry2D.is_point_in_polygon(Vector2(x, y), pts) \
					and Geometry2D.is_point_in_polygon(Vector2(x + 10, y + 10), pts):
				draw_line(Vector2(x, y), Vector2(x + 10, y + 10), shade, 1.5)
				draw_line(Vector2(x + 10, y), Vector2(x, y + 10), shade, 1.5)
			y += 97.0
		x += 23.0

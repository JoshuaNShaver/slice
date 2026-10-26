class_name Mound
extends StaticBody2D
## A floating shelf of ground (design log 0222): a raised house stands on
## one with the road dipping beneath it, and those who serve stand on
## small ones (daises) over the road, so you pass under them and talk from below.
## In the plane, anything you pass under has to float, as the Center's
## ledges do.
##
## Flat where something stands, curling down at the ends, a lumpy belly
## with a drip or two underneath: a clod of earth, seeded by where it is.
## Every peer builds the same mounds from data (each terrain's MOUNDS).

const DAIS_WIDTH := 170.0
const DAIS_DEPTH := 34.0
## How high a dais's top stands over the road: a shape passes under it, and
## can talk to whoever is on it (Npc.REACH).
const DAIS_HEIGHT := 96.0

var top := Vector2.ZERO  # the middle of its top surface
var width := 600.0
var depth := 90.0  # at the middle
var chalk := false  # underworld: chalk on slate
## A gangway or any other piece: its own outline, in place of the lens.
var shape_points := PackedVector2Array()


## data: {"at" (top middle), "width", "depth", "chalk"}, or {"outline",
## "chalk"} for any other shape.
static func create(data: Dictionary) -> Mound:
	var m := Mound.new()
	m.top = data.get("at", Vector2.ZERO)
	m.width = data.get("width", 600.0)
	m.depth = data.get("depth", 90.0)
	m.chalk = data.get("chalk", false)
	m.shape_points = data.get("outline", PackedVector2Array())
	if not m.shape_points.is_empty():
		m.top = m.shape_points[0]
	m.position = Vector2.ZERO
	return m


## A dais for one NPC, its top DAIS_HEIGHT over the road at `floor_at`.
static func dais(floor_at: Vector2, chalk_line := false) -> Dictionary:
	return {"at": floor_at - Vector2(0, DAIS_HEIGHT), "width": DAIS_WIDTH, "depth": DAIS_DEPTH, "chalk": chalk_line}


## Where an NPC stands on a dais over `floor_at` (its "at").
static func on_dais(floor_at: Vector2) -> Vector2:
	return floor_at - Vector2(0, DAIS_HEIGHT)


func _ready() -> void:
	collision_layer = PlayerShape.LAYER_TERRAIN
	collision_mask = 0
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 1.0
	var shape := CollisionPolygon2D.new()
	shape.polygon = outline()
	add_child(shape)


func outline() -> PackedVector2Array:
	if not shape_points.is_empty():
		return shape_points
	return outline_of(top, width, depth)


## The y of the top of the island `data` describes (Mound data, a lens) at
## `x`: where someone standing on it at x rests.
static func top_y(data: Dictionary, x: float) -> float:
	var pts := outline_of(data.at, data.get("width", 600.0), data.get("depth", 90.0))
	return Buildings.y_at(pts.slice(0, TOP_POINTS + 1), x)


const TOP_POINTS := 28


## A lens island's outline, top middle `top`: the top west to east, then
## the belly back. Seeded by where it is, so every peer grows the same
## clod of earth.
static func outline_of(top: Vector2, width: float, depth: float) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(top.round()))
	var half := width / 2.0
	var tip := depth * 0.3  # how far the ends curl down
	var flat := rng.randf_range(0.5, 0.6)  # the flat middle, a house's floor
	var pts := PackedVector2Array()
	var n := TOP_POINTS
	# The top, west to east: flat in the middle, curling down to each tip,
	# a little unevenly.
	var curl := [rng.randf_range(0.8, 1.25), rng.randf_range(0.8, 1.25)]
	for i in n + 1:
		var u := float(i) / n
		var edge := absf(u * 2.0 - 1.0)
		var past := maxf(edge - flat, 0.0) / (1.0 - flat)
		var side: float = curl[0] if u < 0.5 else curl[1]
		pts.append(top + Vector2(lerpf(-half, half, u), tip * side * pow(past, 2.0)))
	# The belly, east to west: a lopsided bulge with lumps and a drip or two.
	var lean := rng.randf_range(-0.12, 0.12)
	var phase := [rng.randf() * TAU, rng.randf() * TAU]
	var drips := [rng.randf_range(0.25, 0.45), rng.randf_range(0.55, 0.75)]
	var m := 36
	for i in range(1, m):
		var u := 1.0 - float(i) / m  # 1 east .. 0 west
		var w := clampf(u + lean * sin(u * PI), 0.0, 1.0)
		var bulge := pow(sin(w * PI), 0.5)  # blunt, rounded ends
		var lumps := 1.0 + 0.1 * sin(u * 9.0 + phase[0]) + 0.06 * sin(u * 17.0 + phase[1])
		var drip := 0.0
		for d: float in drips:
			drip += 0.16 * exp(-pow((u - d) / 0.07, 2.0))
		var end_y: float = tip * (curl[1] if u > 0.5 else curl[0])
		pts.append(top + Vector2(lerpf(-half, half, u), lerpf(end_y, depth * lumps, bulge) + depth * drip * bulge))
	return pts


func _draw() -> void:
	var pts := outline()
	var ground := Palette.SLATE_DARK if chalk else Palette.PARCHMENT_DARK
	var line := Palette.CHALK_LINE if chalk else Palette.INK
	draw_colored_polygon(pts, ground)
	# Short strokes under the top, as the ground's hatching, following the
	# top's contour as it curls down to each tip.
	var hatch := Color(Palette.CHALK_FADED if chalk else Palette.INK_FADED, 0.25)
	if shape_points.is_empty():
		var surface := pts.slice(0, TOP_POINTS + 1)
		var x := top.x - width / 2.0 + 24.0
		while x < top.x + width / 2.0 - 24.0:
			var p := Vector2(x, Buildings.y_at(surface, x))
			var a := p + Vector2(4, 6)
			var b := p + Vector2(-8, 18)
			if Geometry2D.is_point_in_polygon(a, pts) and Geometry2D.is_point_in_polygon(b, pts):
				draw_line(a, b, hatch, 1.5)
			x += 16.0
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, line, 3.0, true)

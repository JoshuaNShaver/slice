class_name Ocean
extends Node2D
## The western sea (design logs 0200, 0201): its waves, and drawing the
## water. The waves are there to make boats hard to sail.
##
## The sea is still at the shores and rough out in open water. Its height is
## a sum of travelling sines of the server's clock, so every peer works out
## the same waves: the server for boats and drowning, clients to draw them.
## A client draws them NetSmoother.DELAY behind, as it draws boats.
##
## Water lies wherever the ground (Coast.ground_y) is below the surface.
## Falling into it drowns you (PlayerActions.drown).

const LEVEL := Coast.SEA_LEVEL  # the calm sea's surface (y)
## Each wave: [height px, wavelength px, cycles per CLOCK_WRAP, phase].
## Cycles are whole numbers so a wave comes out the same on a client, whose
## clock is the server's modulo NetSmoother.CLOCK_WRAP.
const WAVES: Array = [
	[18.0, 900.0, 585, 0.0],  # about 7 s a wave
	[10.0, 420.0, -819, 1.3],  # 5 s, running the other way
	[6.0, 230.0, 1241, 2.1],  # 3.3 s
]
const CALM_REACH := 700.0  # px from a shore to full waves
## Where the sea meets land (x), for calming the waves near it.
const SHORES: Array[float] = [Coast.SHORE_EDGE, Coast.ISLAND_EAST_TOP, Coast.ISLAND_WEST_TOP, Coast.WEST_X]
const STEP := 12.0  # px between drawn surface points

const WATER := Color(0.23, 0.16, 0.12, 0.10)
const HATCH := Color(0.23, 0.16, 0.12, 0.16)


func _ready() -> void:
	z_index = 2  # in front of boats' hulls and anyone in the water


func _process(_delta: float) -> void:
	queue_redraw()


## Seconds on the server's clock: the server's own, or a client's guess of
## it (NetSmoother.clock_offset), drawn DELAY behind like boats.
static func now() -> float:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root.multiplayer.is_server():
		return NetSmoother.now()
	return NetSmoother.now() - NetSmoother.clock_offset - NetSmoother.DELAY


## The surface's y at `x` and time `t` (Ocean.now()).
static func surface_y(x: float, t: float) -> float:
	return LEVEL + _height(x, t) * calm(x)


## The surface's slope (dy/dx) at `x`, `t`.
static func slope(x: float, t: float) -> float:
	return (surface_y(x + 4.0, t) - surface_y(x - 4.0, t)) / 8.0


## 0 at a shore, rising to 1 out at sea.
static func calm(x: float) -> float:
	var nearest := INF
	for edge in SHORES:
		nearest = minf(nearest, absf(x - edge))
	return smoothstep(0.0, CALM_REACH, nearest)


static func _height(x: float, t: float) -> float:
	var h := 0.0
	for wave: Array in WAVES:
		var omega: float = TAU * float(wave[2]) / NetSmoother.CLOCK_WRAP
		h += float(wave[0]) * sin(TAU * x / float(wave[1]) - omega * t + float(wave[3]))
	return h


## Is there water at `x` (the ground is below the surface)?
static func is_sea(x: float, t: float) -> bool:
	return Coast.ground_y(x) > surface_y(x, t) + 2.0


## A body centred at `pos` is under water: drowned (log 0201).
static func drowns(pos: Vector2, t: float) -> bool:
	return is_sea(pos.x, t) and pos.y > surface_y(pos.x, t) + 4.0


func _draw() -> void:
	var view := get_viewport_rect()
	var inverse := get_viewport().get_canvas_transform().affine_inverse()
	var left := (inverse * view.position).x - STEP
	var right := (inverse * view.end).x + STEP
	left = maxf(left, Coast.WEST_X)
	right = minf(right, Coast.SHORE_EDGE + 400.0)
	if left >= right:
		return
	var t := now()
	# One polygon for each stretch of open water: the surface along the top,
	# the ground along the bottom.
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var x := floorf(left / STEP) * STEP
	while x <= right:
		var s := surface_y(x, t)
		var g := Coast.ground_y(x)
		if g > s + 0.5:
			top.append(Vector2(x, s))
			bottom.append(Vector2(x, g))
		elif top.size() > 0:
			_draw_water(top, bottom)
			top = PackedVector2Array()
			bottom = PackedVector2Array()
		x += STEP
	if top.size() > 0:
		_draw_water(top, bottom)


func _draw_water(top: PackedVector2Array, bottom: PackedVector2Array) -> void:
	if top.size() < 2:
		return
	var poly := top.duplicate()
	for i in range(bottom.size() - 1, -1, -1):
		poly.append(bottom[i])
	if Geometry2D.triangulate_polygon(poly).is_empty():
		return
	draw_colored_polygon(poly, WATER)
	# Ink lines under the surface, for depth: shorter and fainter as they go down.
	for k in 4:
		var line := PackedVector2Array()
		var depth := 22.0 + k * 34.0
		for i in top.size():
			if bottom[i].y > top[i].y + depth + 6.0:
				line.append(top[i] + Vector2(0, depth))
			elif line.size() > 1:
				draw_polyline(line, Color(HATCH, HATCH.a * (1.0 - k * 0.22)), 1.2)
				line = PackedVector2Array()
			else:
				line = PackedVector2Array()
		if line.size() > 1:
			draw_polyline(line, Color(HATCH, HATCH.a * (1.0 - k * 0.22)), 1.2)
	draw_polyline(top, Palette.INK, 2.5, true)

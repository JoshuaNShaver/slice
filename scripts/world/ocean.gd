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
## Water lies wherever the ground (ground_y: the coast's, or another sea's) is below the surface.
## Falling into it drowns you (PlayerActions.drown).
##
## Each stretch of open sea between landfalls has its own weather, rougher
## the further west (log 0215). The clock is cut into spells of weather;
## each spell, a stretch rains with its chance, and while it rains its
## waves swell. Weather comes from the clock too, so it needs no syncing.
##
## Other seas (log 0250): an instance with water of its own (a fortress
## raid's crossing, Fortress) adds a sea with add_sea while it exists, on
## every peer alike. Each has its own level, seabed, shores and weather;
## the same waves run on it. Anywhere else, it's the western sea.

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
const SHORES: Array[float] = [Coast.SHORE_EDGE, Coast.ISLAND_EAST_TOP, Coast.ISLAND_WEST_TOP,
		Coast.QUARRY_EAST_TOP, Coast.QUARRY_WEST_TOP, Coast.WEST_X]
const STEP := 12.0  # px between drawn surface points

## The stretches of open sea, east to west (log 0215), *proposed* numbers:
## "rain" is the chance a spell of weather is wet there, "swell" the waves'
## height while it rains (the Narrows doubles, log 0218). Past the last stretch the sea is as in the first.
const STRETCHES: Array[Dictionary] = [
	{"name": "The Sound", "east": Coast.SHORE_EDGE, "west": Coast.ISLAND_EAST_TOP, "rain": 0.0, "swell": 1.0},
	{"name": "The Narrows", "east": Coast.ISLAND_WEST_TOP, "west": Coast.QUARRY_EAST_TOP, "rain": 0.5, "swell": 2.0},
]
const SPELL := 128.0  # s of one spell of weather; divides CLOCK_WRAP
const RAIN_TURN := 15.0  # s the rain takes to come on or clear
const RAIN_FADE := 500.0  # px past a stretch's ends that rain still falls (drawn only)
## Tests only (server): force the rain everywhere it can fall, 0-1; < 0 is
## the clock's weather. Clients don't see it.
static var rain_override := -1.0
## Tests only (server): the sea's clock in s, stepped by the test with the
## physics (a test runs faster than real time); NAN is the real clock.
static var test_clock := NAN

## Seas other than the western one (log 0250), each: {"x0", "x1" (its
## span), "level" (the calm surface's y), "ground" (a Callable: the
## seabed's y at x, or -INF where there's no sea), "shores" (x where it
## meets land, calm there), "rain" (0-1, steady), "swell" (the waves'
## height in full rain), optionally "piers" (Array of Vector3(x from, x to,
## the planks' underside y): water is never drawn above them, log 0253)}.
static var seas: Array[Dictionary] = []

const WATER := Color(0.23, 0.16, 0.12, 0.10)
const HATCH := Color(0.23, 0.16, 0.12, 0.16)


func _ready() -> void:
	z_index = 2  # in front of boats' hulls and anyone in the water


func _process(_delta: float) -> void:
	queue_redraw()


## Seconds on the server's clock: the server's own, or a client's guess of
## it (NetSmoother.clock_offset), drawn DELAY behind like boats.
static func now() -> float:
	if not is_nan(test_clock):
		return test_clock
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root.multiplayer.is_server():
		return NetSmoother.now()
	return NetSmoother.now() - NetSmoother.clock_offset - NetSmoother.DELAY


## Adds a sea of its own (see `seas`); remove_sea takes it away again.
static func add_sea(sea: Dictionary) -> void:
	seas.append(sea)


static func remove_sea(sea: Dictionary) -> void:
	seas.erase(sea)


## The other sea at `x` (see `seas`), or {} for the western sea.
static func sea_at(x: float) -> Dictionary:
	for sea: Dictionary in seas:
		if x >= float(sea.x0) and x <= float(sea.x1):
			return sea
	return {}


## The ground (or seabed) under the water at `x`; -INF where there's no sea.
static func ground_y(x: float) -> float:
	var sea := sea_at(x)
	if sea.is_empty():
		return Coast.ground_y(x)
	return (sea.ground as Callable).call(x)


## The surface's y at `x` and time `t` (Ocean.now()).
static func surface_y(x: float, t: float) -> float:
	var sea := sea_at(x)
	if not sea.is_empty():
		var waves := _height(x, t) * _calm(x, sea.shores)
		return float(sea.level) + waves * lerpf(1.0, float(sea.swell), float(sea.rain))
	var h := _height(x, t) * calm(x)
	var i := stretch_at(x)
	if i >= 0 and h != 0.0:
		h *= lerpf(1.0, float(STRETCHES[i].swell), rain(i, t))
	return LEVEL + h


## How fast the surface at `x` is rising or falling (dy/dt, px/s).
static func surface_speed(x: float, t: float) -> float:
	return (surface_y(x, t + 0.02) - surface_y(x, t - 0.02)) / 0.04


## The stretch of sea (index into STRETCHES) at `x`, or -1.
static func stretch_at(x: float) -> int:
	for i in STRETCHES.size():
		if x <= float(STRETCHES[i].east) and x >= float(STRETCHES[i].west):
			return i
	return -1


## How hard it's raining on stretch `i` at `t`: 0 dry, 1 full rain.
static func rain(i: int, t: float) -> float:
	if float(STRETCHES[i].rain) <= 0.0:
		return 0.0
	if rain_override >= 0.0:
		return rain_override
	var clock := fposmod(t, NetSmoother.CLOCK_WRAP)
	var spell := int(clock / SPELL)
	var spells := int(NetSmoother.CLOCK_WRAP / SPELL)
	var now_wet := _wet(i, spell)
	var next_wet := _wet(i, (spell + 1) % spells)
	return lerpf(now_wet, next_wet, smoothstep(SPELL - RAIN_TURN, SPELL, clock - spell * SPELL))


## Is spell `spell` wet on stretch `i`? The same answer on every peer.
static func _wet(i: int, spell: int) -> float:
	var h := (spell + 1) * 73856093 ^ (i + 1) * 19349663
	h = (h ^ (h >> 13)) * 1274126177
	h = (h ^ (h >> 16)) & 0xffff
	return 1.0 if h / 65536.0 < float(STRETCHES[i].rain) else 0.0


## Rain falling at `x`, 0-1, fading out past a stretch's ends (for drawing).
static func rain_at(x: float, t: float) -> float:
	var most := 0.0
	for sea: Dictionary in seas:
		var beyond := maxf(x - float(sea.x1), float(sea.x0) - x)
		if beyond < RAIN_FADE:
			most = maxf(most, float(sea.rain) * (1.0 - smoothstep(0.0, RAIN_FADE, beyond)))
	for i in STRETCHES.size():
		var s: Dictionary = STRETCHES[i]
		var past := maxf(x - float(s.east), float(s.west) - x)
		if past < RAIN_FADE:
			most = maxf(most, rain(i, t) * (1.0 - smoothstep(0.0, RAIN_FADE, past)))
	return most


## The surface's slope (dy/dx) at `x`, `t`.
static func slope(x: float, t: float) -> float:
	return (surface_y(x + 4.0, t) - surface_y(x - 4.0, t)) / 8.0


## 0 at a shore, rising to 1 out at sea.
static func calm(x: float) -> float:
	return _calm(x, SHORES)


static func _calm(x: float, shores: Array) -> float:
	var nearest := INF
	for edge: float in shores:
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
	return _between_shores(x) and ground_y(x) > surface_y(x, t) + 2.0


## Another sea holds water only between its outermost shores: past them
## (a fortress's courtyard, log 0253) its waves never flood the ground.
static func _between_shores(x: float) -> bool:
	var sea := sea_at(x)
	if sea.is_empty():
		return true
	var shores: Array = sea.shores
	return x >= float(shores.min()) and x <= float(shores.max())


## A body centred at `pos` is under water: drowned (log 0201).
static func drowns(pos: Vector2, t: float) -> bool:
	return is_sea(pos.x, t) and pos.y > surface_y(pos.x, t) + 4.0


func _draw() -> void:
	var view := get_viewport_rect()
	var inverse := get_viewport().get_canvas_transform().affine_inverse()
	var view_left := (inverse * view.position).x - STEP
	var view_right := (inverse * view.end).x + STEP
	var t := now()
	for span in spans(RAIN_FADE):
		var left := maxf(view_left, span.x)
		var right := minf(view_right, span.y)
		if left >= right:
			continue
		for stretch: Array in stretches(left, right, t):
			_draw_water(stretch[0], stretch[1])
		_draw_rain(left, right, (inverse * view.position).y, (inverse * view.end).y, t)


## Where there's sea to draw: the western sea's span, then each other
## sea's, `margin` wider either side (for its rain).
static func spans(margin := 0.0) -> Array[Vector2]:
	var out: Array[Vector2] = [Vector2(Coast.WEST_X, Coast.SHORE_EDGE + 400.0)]
	for sea: Dictionary in seas:
		out.append(Vector2(float(sea.x0) - margin, float(sea.x1) + margin))
	return out


## The underside of a pier over the water at `x`, or INF where there's none.
## Waves are drawn no higher (they'd show through its planks, log 0253).
static func pier_under(x: float) -> float:
	var sea := sea_at(x)
	if sea.is_empty():
		for pier in Coast.PIERS:
			if x >= pier.x and x <= pier.y:
				return Coast.SHORE_Y + Coast.PLANK
		return INF
	for pier: Vector3 in sea.get("piers", []):
		if x >= pier.x and x <= pier.y:
			return pier.z
	return INF


## Each stretch of open water between `left` and `right` at time `t`:
## [the surface's points, the ground's under them]. Ocean and a
## Flatlander's eyes (FlatMap, log 0249) both draw them.
static func stretches(left: float, right: float, t: float) -> Array:
	var out := []
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var x := floorf(left / STEP) * STEP
	while x <= right:
		var s := surface_y(x, t)
		var g := ground_y(x)
		if g > s + 0.5 and _between_shores(x):
			var under := pier_under(x)
			top.append(Vector2(x, maxf(s, under) if under < INF else s))
			bottom.append(Vector2(x, g))
		elif top.size() > 0:
			out.append([top, bottom])
			top = PackedVector2Array()
			bottom = PackedVector2Array()
		x += STEP
	if top.size() > 0:
		out.append([top, bottom])
	return out


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


## Rain: slanting ink streaks falling to the sea, and a grey wash over the
## sky, where a stretch is wet. Columns are pinned to the world, so the rain
## doesn't slide with the camera.
func _draw_rain(left: float, right: float, top: float, bottom: float, t: float) -> void:
	const COLUMN := 36.0
	const DROP := Vector2(-7.0, 26.0)  # a streak, blown a little westward
	const FALL := 900.0  # px/s
	var span := bottom - top + DROP.y
	var c := floori(left / COLUMN)
	while c * COLUMN <= right:
		var x := c * COLUMN
		c += 1
		var wet := rain_at(x, t)
		if wet <= 0.01:
			continue
		draw_rect(Rect2(x, top, COLUMN, bottom - top), Color(Palette.INK, 0.06 * wet))
		var ground := surface_y(x, t) if is_sea(x, t) else ground_y(x)
		for k in 3:
			var r := fposmod(sin(c * 12.9898 + k * 78.233) * 43758.5453, 1.0)
			if r > wet:
				continue  # lighter rain, fewer streaks
			var fallen := fposmod(r * span + t * FALL * (0.85 + 0.3 * r), span)
			var at := Vector2(x + r * COLUMN + fallen * DROP.x / DROP.y, top + fallen - DROP.y)
			if at.y >= ground:
				continue
			var end := at + DROP
			if end.y > ground:
				end = at.lerp(end, (ground - at.y) / DROP.y)
			draw_line(at, end, Color(Palette.INK, 0.28 * wet), 1.3)

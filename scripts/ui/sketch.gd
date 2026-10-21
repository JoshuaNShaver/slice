class_name Sketch
## Pencil-and-ink drawing helpers for the main menu (log 0185): lines drawn
## twice, a little off each other and past their ends, and torn paper
## edges. Everything draws onto a canvas item RID, so a StyleBox (SketchBox)
## and a Control (MenuScene) can share them. Pass a seeded
## RandomNumberGenerator so the same thing is drawn the same way each frame.


## A hand-drawn line from a to b: `passes` strokes, each wobbling a little
## and overshooting the ends by up to `overshoot`.
static func line(ci: RID, a: Vector2, b: Vector2, ink: Color, width: float,
		rng: RandomNumberGenerator, passes := 2, overshoot := 4.0, wobble := 1.2) -> void:
	var along := (b - a).normalized()
	var across := along.orthogonal()
	for i in passes:
		var start := a - along * rng.randf_range(0.0, overshoot) + across * rng.randf_range(-wobble, wobble)
		var end := b + along * rng.randf_range(0.0, overshoot) + across * rng.randf_range(-wobble, wobble)
		var mid := start.lerp(end, rng.randf_range(0.35, 0.65)) + across * rng.randf_range(-wobble, wobble)
		var color := ink if i == 0 else Color(ink, ink.a * 0.55)
		var w := width if i == 0 else width * 0.6
		RenderingServer.canvas_item_add_polyline(ci, PackedVector2Array([start, mid, end]),
				PackedColorArray([color]), w, true)


## A closed outline drawn by hand, side by side.
static func outline(ci: RID, pts: PackedVector2Array, ink: Color, width: float,
		rng: RandomNumberGenerator, passes := 2, overshoot := 4.0, wobble := 1.2) -> void:
	for i in pts.size():
		line(ci, pts[i], pts[(i + 1) % pts.size()], ink, width, rng, passes, overshoot, wobble)


## A closed outline that follows many points (a torn edge): one wobbly
## stroke along it, then a fainter second one a little off.
static func ragged_outline(ci: RID, pts: PackedVector2Array, ink: Color, width: float,
		rng: RandomNumberGenerator) -> void:
	for pass_i in 2:
		var shift := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * pass_i
		var line_pts := PackedVector2Array()
		for p in pts:
			line_pts.append(p + shift + Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6)))
		line_pts.append(line_pts[0])
		var color := ink if pass_i == 0 else Color(ink, ink.a * 0.45)
		RenderingServer.canvas_item_add_polyline(ci, line_pts, PackedColorArray([color]),
				width if pass_i == 0 else width * 0.6, true)


## The corners of `rect`, each nudged up to `jitter`.
static func rough_rect(rect: Rect2, rng: RandomNumberGenerator, jitter := 1.5) -> PackedVector2Array:
	var pts := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y),
			rect.end, Vector2(rect.position.x, rect.end.y)])
	for i in pts.size():
		pts[i] += Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter))
	return pts


## `rect`'s edge torn like old paper: points every `step` px, bitten in by
## up to `tear`, now and then a deeper notch.
static func torn_rect(rect: Rect2, rng: RandomNumberGenerator, tear := 5.0, step := 12.0) -> PackedVector2Array:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)]
	var center := rect.get_center()
	var pts := PackedVector2Array()
	for side in 4:
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		var count := maxi(int(a.distance_to(b) / step), 1)
		for k in count:
			var p := a.lerp(b, float(k) / count)
			var bite := rng.randf_range(0.0, tear)
			if rng.randf() < 0.08:
				bite += tear * 1.4  # a notch
			pts.append(p + (center - p).normalized() * bite)
	return pts


## Short slanted pencil strokes along the inside of an edge from a to b,
## shading toward `inward`.
static func shade_edge(ci: RID, a: Vector2, b: Vector2, inward: Vector2, ink: Color,
		rng: RandomNumberGenerator, gap := 6.0, depth := 10.0) -> void:
	var count := int(a.distance_to(b) / gap)
	for k in count:
		var p := a.lerp(b, (k + rng.randf()) / maxf(count, 1)) + inward * 2.0
		var d := depth * rng.randf_range(0.4, 1.0)
		var tip := p + inward * d + (b - a).normalized() * d * 0.5
		RenderingServer.canvas_item_add_line(ci, p, tip, ink, 1.0, true)


## A polygon filled with `fill`, for drawing onto an RID.
static func fill(ci: RID, pts: PackedVector2Array, color: Color) -> void:
	if Geometry2D.triangulate_polygon(pts).is_empty():
		return  # a self-crossing outline can't be filled
	RenderingServer.canvas_item_add_polygon(ci, pts, PackedColorArray([color]))

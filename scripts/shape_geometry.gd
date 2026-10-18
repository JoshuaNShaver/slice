class_name ShapeGeometry
## Outline points for player shapes, centered on (0, 0) with a flat face down.
##
## Triangle angles are placeholders until design decides them (DESIGN.md open
## question 1): right = 45-45-90, acute = isosceles with a 30° tip.


static func points(sides: int, kind: String, radius: float) -> PackedVector2Array:
	var pts: PackedVector2Array
	if sides == 3 and kind == "right":
		pts = PackedVector2Array([Vector2(-1, 1), Vector2(1, 1), Vector2(-1, -1)])
	elif sides == 3 and kind == "acute":
		var half_base := 2.0 * tan(deg_to_rad(15.0))
		pts = PackedVector2Array([Vector2(-half_base, 1), Vector2(half_base, 1), Vector2(0, -1)])
	elif kind == "irregular":
		pts = _irregular(sides)
	else:
		pts = _regular(sides)
	return _fit(pts, radius)


static func _regular(sides: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	# Screen y points down, so PI/2 is straight down; offsetting by PI/n puts a face on the floor.
	var start := PI / 2.0 + PI / sides
	for i in sides:
		pts.append(Vector2.from_angle(start + i * TAU / sides))
	return pts


## Lopsided but stable (same shape every time for a given side count).
static func _irregular(sides: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = sides * 7919
	var pts := _regular(sides)
	for i in pts.size():
		pts[i] *= rng.randf_range(0.55, 1.25)
	return pts


## Center on the centroid and scale so the farthest corner sits at `radius`.
static func _fit(pts: PackedVector2Array, radius: float) -> PackedVector2Array:
	var center := Vector2.ZERO
	for p in pts:
		center += p
	center /= pts.size()
	var far := 0.0
	for p in pts:
		far = maxf(far, (p - center).length())
	var out := PackedVector2Array()
	for p in pts:
		out.append((p - center) / far * radius)
	return out

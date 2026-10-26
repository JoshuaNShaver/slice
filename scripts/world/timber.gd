class_name Timber
extends WorldResource
## One of the Logging Isle's great trees (design log 0202), taller than the
## screen. Every 1,000 of its 10,000 health drops a log; felled, it leaves a
## stump and grows back in 3 minutes (WorldResource does the work).

const HEALTH := 10000
const LOG_EVERY := 1000
const REGROW := 180.0  # s, *proposed*
const HEIGHT := 1500.0  # px from the foot up: well past the top of the screen
const TRUNK := 70.0  # px wide at the foot


func _init() -> void:
	health = HEALTH
	drop_every = LOG_EVERY
	item = Gear.LOG
	regrow = REGROW
	hit_lift = 80.0


func _outline() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-TRUNK / 2.0, 0), Vector2(-TRUNK * 0.4, -HEIGHT),
			Vector2(TRUNK * 0.4, -HEIGHT), Vector2(TRUNK / 2.0, 0)])


func _drop_reach() -> float:
	return TRUNK + 30.0


func _draw() -> void:
	var ink := Palette.INK
	if felled:
		var stump := PackedVector2Array([Vector2(-TRUNK / 2.0, 0), Vector2(-TRUNK * 0.48, -40),
				Vector2(TRUNK * 0.48, -46), Vector2(TRUNK / 2.0, 0)])
		draw_colored_polygon(stump, Palette.PARCHMENT_LIGHT)
		stump.append(stump[0])
		draw_polyline(stump, ink, 2.5, true)
		draw_arc(Vector2(0, -43), TRUNK * 0.3, PI, TAU, 12, Palette.INK_FADED, 1.5, true)
		return
	var sway := 0.0
	if _shake > 0.0:
		sway = sin(_shake * 80.0) * 4.0 * (_shake / SHAKE_TIME)
	var trunk := PackedVector2Array([Vector2(-TRUNK / 2.0, 0), Vector2(-TRUNK * 0.4 + sway, -HEIGHT),
			Vector2(TRUNK * 0.4 + sway, -HEIGHT), Vector2(TRUNK / 2.0, 0)])
	draw_colored_polygon(trunk, Palette.PARCHMENT_LIGHT)
	# Bark: short strokes up the trunk, the same for this tree every time.
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var y := -30.0
	while y > -HEIGHT + 20.0:
		var k := -y / HEIGHT
		var half := lerpf(TRUNK / 2.0, TRUNK * 0.4, k) - 8.0
		var x := rng.randf_range(-half, half) + sway * k
		draw_line(Vector2(x, y), Vector2(x + rng.randf_range(-3, 3), y - rng.randf_range(18, 40)),
				Palette.INK_FADED, 1.5)
		y -= rng.randf_range(14, 30)
	draw_line(trunk[0], trunk[1], ink, 3.0, true)
	draw_line(trunk[3], trunk[2], ink, 3.0, true)
	# Branches, high up, reaching out of the top of the screen.
	for i in 5:
		var from := Vector2(sway * 0.8, -HEIGHT * (0.55 + 0.09 * i))
		var side := -1.0 if i % 2 == 0 else 1.0
		draw_line(from + Vector2(side * TRUNK * 0.3, 0), from + Vector2(side * rng.randf_range(90, 160), -rng.randf_range(60, 120)),
				ink, 2.5, true)
	# Roots.
	for side in [-1.0, 1.0]:
		draw_line(Vector2(side * TRUNK / 2.0, 0), Vector2(side * (TRUNK / 2.0 + 26), 6), ink, 2.5, true)

class_name OreRock
extends WorldResource
## A rock on the Quarry Isle (design log 0211): a low outcrop veined with
## rare ore. Tougher than a tree: every 2,000 of its 8,000 health drops one
## ore (4 a rock); quarried out, it leaves rubble and grows back in 5
## minutes. *Proposed* numbers.

const HEALTH := 8000
const ORE_EVERY := 2000
const REGROW := 300.0  # s
const ROCK := Vector2(150, 95)  # width and height


func _init() -> void:
	health = HEALTH
	drop_every = ORE_EVERY
	item = Gear.ORE
	regrow = REGROW
	hit_lift = ROCK.y + 30.0


func _drop_reach() -> float:
	return ROCK.x / 2.0 + 30.0


## An ore rock's outline: a low, lumpy outcrop, the same for this rock every time.
func _outline() -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var w := ROCK.x / 2.0
	var h := ROCK.y
	return PackedVector2Array([Vector2(-w, 0), Vector2(-w * 0.85, -h * rng.randf_range(0.45, 0.6)),
			Vector2(-w * 0.45, -h * rng.randf_range(0.85, 1.0)), Vector2(w * 0.05, -h),
			Vector2(w * 0.5, -h * rng.randf_range(0.75, 0.9)), Vector2(w * 0.9, -h * rng.randf_range(0.35, 0.5)),
			Vector2(w, 0)])


func _draw() -> void:
	var ink := Palette.INK
	if felled:
		# Rubble: a few chips where the rock was.
		for k in 4:
			var c := Vector2(-45 + k * 30, -8)
			var chip := PackedVector2Array([c + Vector2(-9, 8), c + Vector2(-4, -6), c + Vector2(8, -3), c + Vector2(10, 8)])
			draw_colored_polygon(chip, Palette.PARCHMENT_LIGHT)
			chip.append(chip[0])
			draw_polyline(chip, Palette.INK_FADED, 1.5, true)
		return
	var shake := Vector2.ZERO
	if _shake > 0.0:
		shake.x = sin(_shake * 90.0) * 3.0 * (_shake / SHAKE_TIME)
	var rock := _outline()
	for i in rock.size():
		if rock[i].y < 0.0:
			rock[i] += shake
	draw_colored_polygon(rock, Gear.ORE_ROCK.lerp(Palette.PARCHMENT_LIGHT, 0.55))
	Gear.draw_hatch(self, rock, [[35.0], 9.0], 1.0, Color(ink, 0.25))
	# Veins of ore: pale flecks, and a crack or two.
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + 7
	for k in 9:
		var at := Vector2(rng.randf_range(-ROCK.x * 0.35, ROCK.x * 0.35), -rng.randf_range(12, ROCK.y * 0.7)) + shake * 0.6
		draw_circle(at, rng.randf_range(2.5, 4.5), Gear.ORE_FLECK)
		draw_arc(at, 4.5, 0, TAU, 8, Color(ink, 0.5), 1.0, true)
	draw_line(Vector2(-20, -ROCK.y * 0.8) + shake, Vector2(-5, -ROCK.y * 0.4), Color(ink, 0.6), 1.5, true)
	draw_line(Vector2(-5, -ROCK.y * 0.4), Vector2(12, -ROCK.y * 0.25), Color(ink, 0.6), 1.5, true)
	rock.append(rock[0])
	draw_polyline(rock, ink, 3.0, true)

extends Node2D
## A damage number that floats up from a hit and fades (design log 0046).
## Ink for damage to enemies, red for damage to players, and larger gold
## with a "!" for critical hits (design log 0047).

const RISE := 42.0  # px over its life
const LIFETIME := 0.9  # s

var amount := 0
var kind := "enemy"  # "enemy", "crit" or "player"
var _age := 0.0


func _ready() -> void:
	z_index = 10  # over the shapes
	position.x += randf_range(-10.0, 10.0)  # so quick multi-hits don't stack


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	position.y -= RISE / LIFETIME * delta
	modulate.a = 1.0 - maxf(_age / LIFETIME - 0.5, 0.0) * 2.0  # fades over the second half
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var under := Regions.is_underworld(global_position)
	var color := Palette.ink_at(global_position)
	var size := 18
	var text := str(amount)
	if kind == "player":
		color = Palette.HEALTH.darkened(0.15)
	elif kind == "crit":
		color = Palette.XP.darkened(0.25)
		size = 26
		text += "!"
	# A rim the color of the ground keeps it readable over ink and shapes.
	draw_string_outline(font, Vector2(-60, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 120, size, 4,
			Palette.SLATE if under else Palette.PARCHMENT)
	draw_string(font, Vector2(-60, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 120, size, color)

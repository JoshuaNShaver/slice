class_name Atmosphere
extends Control
## A light foreground layer over the world (design log 0057): dust specks,
## slanting light and low fog, kept faint. It moves faster than the camera,
## so it reads as nearer than the shapes. Each region has its own mood, and
## moving between regions blends them. Drawn on each client only, under the
## HUD.

const SPECKS := 56
const SHAFTS := 3
const FOG_BANKS := 5
const BLEND_RATE := 0.8  # how fast moods change, per second

## Per place (Regions ids; "" is between places, e.g. a shaft):
## motes: how many specks show (0-1). shafts: light beams. fog: low fog.
## rise: specks drift up (ash, incense) instead of settling.
const MOODS := {
	"center": {"motes": 0.55, "shafts": 1.0, "fog": 0.0, "rise": 0.0},
	"barracks": {"motes": 0.7, "shafts": 0.6, "fog": 0.0, "rise": 0.0},
	"mission": {"motes": 0.6, "shafts": 0.3, "fog": 0.5, "rise": 0.4},
	"noble": {"motes": 0.15, "shafts": 0.35, "fog": 0.0, "rise": 0.0},
	"hill": {"motes": 0.4, "shafts": 1.0, "fog": 0.0, "rise": 0.3},
	"temple": {"motes": 0.7, "shafts": 1.5, "fog": 0.0, "rise": 1.0},
	"undercroft": {"motes": 0.7, "shafts": 0.0, "fog": 1.0, "rise": 1.0},
	"cave": {"motes": 0.5, "shafts": 0.0, "fog": 0.7, "rise": 0.6},
	"": {"motes": 0.3, "shafts": 0.0, "fog": 0.3, "rise": 0.5},
}

## The camera's view center, set by the world each frame.
var view := Vector2.ZERO

var _specks: Array[Dictionary] = []
var _mood := {"motes": 0.0, "shafts": 0.0, "fog": 0.0, "rise": 0.0}
var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 1884
	for i in SPECKS:
		_specks.append({
			"x": rng.randf(), "y": rng.randf(),
			"near": rng.randf_range(1.15, 1.6),  # parallax: >1 is in front of the world
			"size": rng.randf_range(1.0, 2.6),
			"phase": rng.randf() * TAU,
			"speed": rng.randf_range(6.0, 18.0),
			"dark": i % 4 == 0,  # paper fibers among the dust
		})


func _process(delta: float) -> void:
	_time += delta
	var target: Dictionary = MOODS.get(Regions.at(view).get("id", ""), MOODS[""])
	var k := clampf(delta * BLEND_RATE, 0.0, 1.0)
	for key: String in _mood:
		_mood[key] = lerpf(_mood[key], target[key], k)
	queue_redraw()


func _draw() -> void:
	var under := Regions.underworld_blend(view.y)
	if _mood.shafts > 0.01:
		_draw_shafts(_mood.shafts * (1.0 - under))
	if _mood.fog > 0.01:
		_draw_fog(_mood.fog)
	_draw_specks(under)


## Wide pale beams slanting down from the upper left.
func _draw_shafts(strength: float) -> void:
	var color := Color(Palette.PARCHMENT_LIGHT, 0.07 * strength)
	var wrap := size.x + 600.0
	for i in SHAFTS:
		var x := fposmod(i * wrap / SHAFTS - view.x * 0.25 + sin(_time * 0.1 + i) * 30.0, wrap) - 300.0
		var w := 90.0 + 50.0 * i
		var slant := size.y * 0.45
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, 0), Vector2(x + w, 0), Vector2(x + w + slant, size.y), Vector2(x + slant, size.y),
		]), color)


## Soft banks of fog low on the screen, drifting sideways.
func _draw_fog(strength: float) -> void:
	var color := Color(Palette.CHALK_LINE, 0.016 * strength)
	var wrap := size.x + 800.0
	for i in FOG_BANKS:
		var x := fposmod(i * wrap / FOG_BANKS - view.x * 1.3 + _time * (8.0 + i * 3.0), wrap) - 400.0
		var y := size.y + 10.0 - (i % 3) * 30.0
		for layer in 3:
			var r := Vector2(260.0 + layer * 70.0, 50.0 + layer * 18.0)
			draw_colored_polygon(_ellipse(Vector2(x, y), r), color)


func _draw_specks(under: float) -> void:
	var count := int(SPECKS * _mood.motes)
	var wrap := size + Vector2(100, 100)
	var light := Palette.PARCHMENT_LIGHT.lerp(Palette.CHALK_LINE, under)
	for i in count:
		var s: Dictionary = _specks[i]
		var drift := Vector2(sin(_time * 0.4 + s.phase) * 14.0,
				_time * s.speed * lerpf(0.4, -1.0, _mood.rise))
		var near: float = s.near
		var pos: Vector2 = Vector2(s.x, s.y) * wrap - view * near + drift
		pos = Vector2(fposmod(pos.x, wrap.x), fposmod(pos.y, wrap.y)) - Vector2(50, 50)
		var twinkle := 0.6 + 0.4 * sin(_time * 1.3 + s.phase * 3.0)
		var color: Color = Color(Palette.INK, 0.16) if s.dark and under < 0.5 else Color(light, 0.5 * twinkle)
		draw_circle(pos, s.size * (near - 0.6), color)


static func _ellipse(center: Vector2, radii: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return pts

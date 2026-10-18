class_name ParchmentBackground
extends Control
## Parchment with ink stains drifting in parallax layers (design log 0014).
## Farther layers (lower index) move slower and look fainter.
## In menus the stains drift on their own; in the world they follow the camera.

const LAYER_SPEEDS: Array[float] = [6.0, 14.0, 26.0]
const STAINS_PER_LAYER := 7

const PARALLAX_PER_SPEED := 1.0 / 40.0  # world: layer moves speed/40 of the camera's motion

## Drift over time (menus). Turn off and set view_offset to follow a camera.
var auto_drift := true
var view_offset := Vector2.ZERO

var _stains: Array[Dictionary] = []
var _scroll := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 1884  # Flatland's publication year
	for layer in LAYER_SPEEDS.size():
		for i in STAINS_PER_LAYER:
			var blobs: Array[Vector3] = []  # x, y offset and radius of each blot
			for b in rng.randi_range(2, 5):
				blobs.append(Vector3(rng.randf_range(-30, 30), rng.randf_range(-20, 20), rng.randf_range(8, 30)))
			_stains.append({
				"layer": layer,
				"x": rng.randf(),
				"y": rng.randf(),
				"scale": 0.6 + 0.5 * layer,
				"blobs": blobs,
			})


func _process(delta: float) -> void:
	if auto_drift:
		_scroll += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.PARCHMENT)
	var wrap := size + Vector2(200.0, 200.0)
	for s in _stains:
		var layer: int = s.layer
		var travel := Vector2(_scroll * LAYER_SPEEDS[layer], 0.0)
		if not auto_drift:
			travel = view_offset * LAYER_SPEEDS[layer] * PARALLAX_PER_SPEED
		var x := fposmod(s.x * wrap.x - travel.x, wrap.x) - 100.0
		var y := fposmod(s.y * wrap.y - travel.y, wrap.y) - 100.0
		var color := Palette.INK_STAIN
		color.a *= 0.6 + 0.4 * layer
		for blob: Vector3 in s.blobs:
			draw_circle(Vector2(x + blob.x * s.scale, y + blob.y * s.scale), blob.z * s.scale, color)

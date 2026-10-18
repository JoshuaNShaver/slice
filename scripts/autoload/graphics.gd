extends Node
## Graphics settings, saved per machine in `user://graphics.cfg`
## (design log 0094): a framerate cap and High / Low quality.
## Low skips the foreground atmosphere and the background's ink stains, and
## renders at the base 1280x720, then scales that up to the window.

signal changed

const SAVE_PATH := "user://graphics.cfg"
## Framerate caps on offer. 0 is no cap (vsync still limits it to the display).
const FPS_CHOICES: Array[int] = [30, 60, 120, 144, 0]
## A dedicated server has no screen to sync to, so it would spin as fast as
## the CPU allows, sending updates every frame. Hold it near the physics rate.
const SERVER_FPS := 120

var max_fps := 0
var low := false


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		Engine.max_fps = SERVER_FPS
		return
	var config := ConfigFile.new()
	config.load(SAVE_PATH)  # missing file just leaves the defaults
	max_fps = config.get_value("graphics", "max_fps", 0)
	if max_fps not in FPS_CHOICES:
		max_fps = 0
	low = config.get_value("graphics", "low", false)
	_apply()


func set_max_fps(value: int) -> void:
	max_fps = value
	_apply()
	_save()


func set_low(value: bool) -> void:
	low = value
	_apply()
	_save()


static func fps_label(value: int) -> String:
	return "No cap" if value == 0 else "%d fps" % value


func _apply() -> void:
	Engine.max_fps = max_fps
	# Low draws the world at the base size and scales the image up: far fewer
	# pixels on a big or Retina window, at the cost of softer edges and text.
	get_tree().root.content_scale_mode = (Window.CONTENT_SCALE_MODE_VIEWPORT if low
			else Window.CONTENT_SCALE_MODE_CANVAS_ITEMS)
	changed.emit()


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("graphics", "max_fps", max_fps)
	config.set_value("graphics", "low", low)
	config.save(SAVE_PATH)

class_name InkPass
extends ColorRect
## A full-screen pass that makes what's under it look drawn in ink on paper
## (logs 0191, 0194; ink_pass.gdshader): ink bleeding into the paper, paper
## grain, and Flatland's fog: the world paler and hatched over the farther
## it is from your eye. Put it in a CanvasLayer above what it should touch
## and below the UI, which stays crisp. Hidden on Low graphics (design log
## 0094).

const SHADER := preload("res://scripts/ui/ink_pass.gdshader")

## The world point at the view's top-left, so grain and hatching scroll
## with the world. Left at zero for a still picture (the main menu).
var origin := Vector2.ZERO
## Your eye on screen, in px: the fog grows away from it. Unset (NAN), the
## middle of the screen.
var focus := Vector2(NAN, NAN)
## How much fog: 0 for none (the main menu's picture has its own), 1 in the world.
var fog := 1.0
## 0 above ground, 1 underground (Regions.underworld_blend).
var under := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	material = mat


func _process(_delta: float) -> void:
	visible = not Graphics.low
	if not visible:
		return
	var view := get_viewport_rect().size
	var mat := material as ShaderMaterial
	mat.set_shader_parameter("origin", origin)
	mat.set_shader_parameter("view_size", view)
	mat.set_shader_parameter("focus", view / 2.0 if is_nan(focus.x) else focus)
	mat.set_shader_parameter("fog", fog)
	mat.set_shader_parameter("under", under)

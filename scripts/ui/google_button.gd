class_name GoogleButton
extends Button
## "Sign in with Google", styled as Google's branding asks (white button,
## grey outline, the four-colour G), not in the parchment theme (log 0120).

const SVG := """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>"""
const ICON_SIZE := 20.0
const TEXT := Color("1f1f1f")
const OUTLINE := Color("747775")


func _init() -> void:
	text = "Sign in with Google"
	icon = _icon()
	custom_minimum_size = Vector2(260, 44)
	add_theme_constant_override("h_separation", 12)
	add_theme_font_size_override("font_size", 17)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		add_theme_color_override(state, TEXT)
	add_theme_color_override("font_disabled_color", Color(TEXT, 0.4))
	add_theme_stylebox_override("normal", _box(Color.WHITE))
	add_theme_stylebox_override("hover", _box(Color("f2f2f2")))
	add_theme_stylebox_override("pressed", _box(Color("e6e6e6")))
	add_theme_stylebox_override("disabled", _box(Color(1, 1, 1, 0.6)))
	var focus := _box(Color.TRANSPARENT)
	focus.border_color = Color("4285f4")
	focus.set_border_width_all(2)
	add_theme_stylebox_override("focus", focus)


static func _icon() -> Texture2D:
	var image := Image.new()
	if image.load_svg_from_string(SVG, ICON_SIZE / 48.0) != OK:
		return null
	return ImageTexture.create_from_image(image)


static func _box(bg: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = OUTLINE
	box.set_border_width_all(1)
	box.set_corner_radius_all(22)
	box.content_margin_left = 16
	box.content_margin_right = 20
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	box.anti_aliasing = true
	return box

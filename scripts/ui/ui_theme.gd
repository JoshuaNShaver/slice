class_name UiTheme
## Builds the shared parchment-and-ink UI theme.


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18

	t.set_color("font_color", "Label", Palette.INK)

	for type: String in ["Button", "OptionButton"]:
		t.set_color("font_color", type, Palette.INK)
		t.set_color("font_hover_color", type, Palette.INK)
		t.set_color("font_pressed_color", type, Palette.INK)
		t.set_color("font_focus_color", type, Palette.INK)
		t.set_color("font_hover_pressed_color", type, Palette.INK)
		t.set_color("font_disabled_color", type, Palette.INK_FADED)
		t.set_stylebox("normal", type, _box(Palette.PARCHMENT_LIGHT, Palette.INK))
		t.set_stylebox("hover", type, _box(Palette.CHALK[1], Palette.INK))
		t.set_stylebox("pressed", type, _box(Palette.CHALK[0], Palette.INK))
		t.set_stylebox("disabled", type, _box(Palette.PARCHMENT_DARK, Palette.INK_FADED))
		t.set_stylebox("focus", type, _box(Color.TRANSPARENT, Palette.INK, 1))

	t.set_color("font_color", "LineEdit", Palette.INK)
	t.set_color("font_placeholder_color", "LineEdit", Palette.INK_FADED)
	t.set_color("caret_color", "LineEdit", Palette.INK)
	t.set_color("selection_color", "LineEdit", Palette.CHALK[4])
	t.set_color("font_uneditable_color", "LineEdit", Palette.INK_FADED)
	t.set_stylebox("normal", "LineEdit", _box(Palette.PARCHMENT_LIGHT, Palette.INK))
	t.set_stylebox("focus", "LineEdit", _box(Color.TRANSPARENT, Palette.INK, 2))
	t.set_stylebox("read_only", "LineEdit", _box(Palette.PARCHMENT_DARK, Palette.INK_FADED))

	t.set_stylebox("panel", "PanelContainer", _box(Color(Palette.PARCHMENT_LIGHT, 0.85), Palette.INK, 2, 16))

	t.set_stylebox("panel", "PopupMenu", _box(Palette.PARCHMENT_LIGHT, Palette.INK))
	t.set_stylebox("hover", "PopupMenu", _box(Palette.CHALK[1], Color.TRANSPARENT, 0))
	t.set_color("font_color", "PopupMenu", Palette.INK)
	t.set_color("font_hover_color", "PopupMenu", Palette.INK)
	return t


static func _box(bg: Color, border: Color, border_width := 2, padding := 8) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(padding)
	return box

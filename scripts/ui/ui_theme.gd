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

	# Tabs: the open tab joins the panel below it; closed tabs sit back in shade.
	t.set_stylebox("panel", "TabContainer", _box(Color(Palette.PARCHMENT_LIGHT, 0.85), Palette.INK, 2, 12))
	t.set_stylebox("tab_selected", "TabContainer", _tab(Palette.PARCHMENT_LIGHT, Palette.INK))
	t.set_stylebox("tab_unselected", "TabContainer", _tab(Palette.PARCHMENT_DARK, Palette.INK_FADED))
	t.set_stylebox("tab_hovered", "TabContainer", _tab(Palette.CHALK[1], Palette.INK))
	t.set_stylebox("tab_focus", "TabContainer", StyleBoxEmpty.new())
	t.set_color("font_selected_color", "TabContainer", Palette.INK)
	t.set_color("font_unselected_color", "TabContainer", Palette.INK_FADED)
	t.set_color("font_hovered_color", "TabContainer", Palette.INK)
	t.set_constant("side_margin", "TabContainer", 0)
	t.set_font_size("font_size", "TabContainer", 16)

	# Empty item slots, like the bag's.
	t.set_stylebox("panel", "Panel", _box(Palette.PARCHMENT, Palette.INK_FADED, 2))

	# Tooltips: see-through parchment, a little rounder (design log 0082).
	var tip := _box(Color(Palette.PARCHMENT_LIGHT, 0.88), Color(Palette.INK, 0.8), 2, 10)
	tip.set_corner_radius_all(8)
	tip.shadow_color = Color(Palette.INK, 0.15)
	tip.shadow_size = 4
	tip.shadow_offset = Vector2(2, 2)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", Palette.INK)
	t.set_font_size("font_size", "TooltipLabel", 16)

	t.set_stylebox("panel", "PopupMenu", _box(Palette.PARCHMENT_LIGHT, Palette.INK))
	t.set_stylebox("hover", "PopupMenu", _box(Palette.CHALK[1], Color.TRANSPARENT, 0))
	t.set_color("font_color", "PopupMenu", Palette.INK)
	t.set_color("font_hover_color", "PopupMenu", Palette.INK)
	return t


static func _tab(bg: Color, border: Color) -> StyleBoxFlat:
	var box := _box(bg, border)
	box.border_width_bottom = 0
	box.corner_radius_bottom_left = 0
	box.corner_radius_bottom_right = 0
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box


static func _box(bg: Color, border: Color, border_width := 2, padding := 8) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(padding)
	return box

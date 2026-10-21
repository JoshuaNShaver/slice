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


## The main menu's theme (log 0185), also the HUD's (log 0189): the shared
## one with hand-drawn buttons, fields, panels, item slots and tooltips,
## lettered in IM Fell English. The type variations "PrimaryButton" (a
## darker paper, for Play) and "Card" (a family card inside the panel) go
## with it.
static func build_menu() -> Theme:
	var t := build()
	t.default_font = menu_font()
	t.default_font_size = 20
	var faded_ink := Color(Palette.INK, 0.4)
	for type: String in ["Button", "PrimaryButton", "OptionButton"]:
		var base := Color("e3d2b0") if type == "PrimaryButton" else Palette.PARCHMENT_LIGHT
		t.set_stylebox("normal", type, SketchBox.make(base, Palette.INK))
		t.set_stylebox("hover", type, SketchBox.make(base.darkened(0.05), Palette.INK))
		var pressed := SketchBox.make(Color("cdb894"), Palette.INK)
		pressed.inset = 1.0
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		var disabled := SketchBox.make(Color(Palette.PARCHMENT_DARK, 0.5), faded_ink)
		disabled.shaded = false
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
	t.set_type_variation("PrimaryButton", "Button")
	t.set_font_size("font_size", "PrimaryButton", 22)

	t.set_stylebox("normal", "LineEdit", SketchBox.make(Palette.PARCHMENT_LIGHT, Palette.INK))
	var focus := SketchBox.make(Color.TRANSPARENT, Palette.INK)
	focus.line_width = 2.2
	focus.shaded = false
	t.set_stylebox("focus", "LineEdit", focus)
	t.set_stylebox("read_only", "LineEdit", SketchBox.make(Color(Palette.PARCHMENT_DARK, 0.5), faded_ink))

	var panel := SketchBox.make(Color(Palette.PARCHMENT_LIGHT, 0.94), Palette.INK, 22.0)
	panel.torn = true
	panel.line_width = 2.0
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_type_variation("Card", "PanelContainer")
	var card := SketchBox.make(Color(Palette.PARCHMENT, 0.7), Color(Palette.INK, 0.85), 12.0)
	card.seed = 7
	t.set_stylebox("panel", "Card", card)

	# Item slots: a pencilled square on plain paper.
	var slot := SketchBox.make(Palette.PARCHMENT, Color(Palette.INK, 0.55), 0.0)
	slot.line_width = 1.3
	slot.overshoot = 2.5
	slot.shaded = false
	t.set_stylebox("panel", "Panel", slot)

	# Tooltips and dropdowns: a scrap of paper.
	var tip := SketchBox.make(Color(Palette.PARCHMENT_LIGHT, 0.95), Color(Palette.INK, 0.8), 8.0)
	tip.shaded = false
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_stylebox("panel", "PopupMenu", tip)
	var hover := SketchBox.make(Color(Palette.PARCHMENT_DARK, 0.6), Color.TRANSPARENT, 0.0)
	hover.shaded = false
	t.set_stylebox("hover", "PopupMenu", hover)

	# A card's scroll bar: a thin pencil stroke.
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(Palette.INK, 0.35)
	grabber.set_corner_radius_all(2)
	grabber.content_margin_left = 2
	grabber.content_margin_right = 2
	t.set_stylebox("grabber", "VScrollBar", grabber)
	var held := grabber.duplicate() as StyleBoxFlat
	held.bg_color = Color(Palette.INK, 0.6)
	t.set_stylebox("grabber_highlight", "VScrollBar", held)
	t.set_stylebox("grabber_pressed", "VScrollBar", held)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	return t


## IM Fell English (log 0185), falling back to the symbols font and
## Godot's own for anything it lacks. Italic with `italic`.
static func menu_font(italic := false) -> Font:
	var font: FontFile = load("res://assets/fonts/fell_italic.ttf" if italic else "res://assets/fonts/fell.ttf")
	if font.fallbacks.is_empty():
		font.fallbacks = [Graphics.SYMBOLS_FONT, ThemeDB.fallback_font]
	return font


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

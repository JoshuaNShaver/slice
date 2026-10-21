class_name CutscenePlayer
extends Control
## Plays a birth or wedding cutscene (Cutscenes, design logs 0168, 0172)
## full-screen over the game, which runs on behind it. One beat at a time,
## typed out; a click, tap or key shows the rest of a beat, then the next.
## An act seen before on this machine can be skipped (Skip, or Esc).
##
## The stage is drawn here, in the game's style: ink on parchment above,
## chalk on slate below. Women are lines with an eye, swaying a little
## (their peace-cry, book Part I §4).

signal finished(scene: Dictionary)

const SEEN_FILE := "user://cutscenes.cfg"
const CHARS_PER_SECOND := 45.0
const ACT_FADE := 0.6  # s, fading each act in from its background
const END_FADE := 0.5  # s, fading out over the world
const DARK_FADE := 1.0  # s, the "dark" cue's fade to black
const CUE_TIME := 1.0  # s for a cue's movement (wed, away) to finish
const MEASURE_TIME := 4.0  # s the calipers stay before fading
const FLOOR := 0.62  # the stage floor, as a share of the height
const TEXT_SIZE := 22

var _scene: Dictionary = {}
var _act: Dictionary = {}
var _act_index := 0
var _beat_index := -1
var _cues: Dictionary = {}  # cue -> time it began (_time)
var _time := 0.0
var _act_started := 0.0
var _reveal := 0.0  # characters of the beat shown so far
var _ending := -1.0  # _time the fade out began, or -1
var _skippable := false

var _box: PanelContainer
var _box_style: StyleBoxFlat
var _name_label: Label
var _text_label: Label
var _hint_label: Label
var _place_label: Label
var _skip_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func playing() -> bool:
	return visible


## Plays `scene` (Cutscenes' format), replacing any already playing.
func play(scene: Dictionary) -> void:
	var acts: Array = scene.get("acts", [])
	if acts.is_empty():
		finished.emit(scene)
		return
	_scene = scene
	var seen := _load_seen()
	_skippable = true
	for act: Dictionary in acts:
		if not seen.has(str(act.get("id", ""))):
			_skippable = false
	_skip_button.visible = _skippable
	visible = true
	modulate.a = 1.0
	_ending = -1.0
	Controls.watching = true
	_start_act(0)


func _start_act(index: int) -> void:
	_act_index = index
	_act = _scene.acts[index]
	_cues.clear()
	_act_started = _time
	_beat_index = -1
	var below: bool = _act.get("setting", "") == "below"
	_box_style.bg_color = Color(Palette.SLATE_DARK, 0.92) if below else Color(Palette.PARCHMENT_LIGHT, 0.95)
	_box_style.border_color = Palette.CHALK_LINE if below else Palette.INK
	_place_label.text = str(_act.get("place", ""))
	_next_beat()


func _next_beat() -> void:
	var beats: Array = _act.get("beats", [])
	_beat_index += 1
	if _beat_index >= beats.size():
		_mark_seen(str(_act.get("id", "")))
		if _act_index + 1 < (_scene.acts as Array).size():
			_start_act(_act_index + 1)
		else:
			_finish()
		return
	var beat: Dictionary = beats[_beat_index]
	var cue := str(beat.get("cue", ""))
	if cue != "" and not _cues.has(cue):
		_cues[cue] = _time
	var who := str(beat.get("who", ""))
	var narration := who == "" or not (_act.cast as Dictionary).has(who)
	_name_label.visible = not narration
	_name_label.text = "" if narration else str(_act.cast[who].get("name", ""))
	_text_label.text = str(beat.get("text", ""))
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if narration else HORIZONTAL_ALIGNMENT_LEFT
	_reveal = 0.0
	_text_label.visible_characters = 0
	_style_text()


func _advance() -> void:
	if _ending >= 0.0:
		return
	if _reveal < _text_label.text.length():
		_reveal = _text_label.text.length()  # show the rest of this beat first
	else:
		_next_beat()


func _finish() -> void:
	if _ending >= 0.0:
		return
	_ending = _time
	Controls.watching = false
	finished.emit(_scene)


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	if _ending >= 0.0:
		modulate.a = 1.0 - clampf((_time - _ending) / END_FADE, 0.0, 1.0)
		if modulate.a <= 0.0:
			visible = false
		return
	var length := _text_label.text.length()
	if _reveal < length:
		_reveal += CHARS_PER_SECOND * delta
	_text_label.visible_characters = -1 if _reveal >= length else int(_reveal)
	_hint_label.visible = _reveal >= _text_label.text.length()
	_style_text()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible or _ending >= 0.0:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	if key.physical_keycode == KEY_ESCAPE:
		if _skippable:
			_finish()
		return
	_advance()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_advance()


# --- Building ------------------------------------------------------------------

func _build() -> void:
	_box = PanelContainer.new()
	_box_style = StyleBoxFlat.new()
	_box_style.set_border_width_all(2)
	_box_style.set_corner_radius_all(6)
	_box_style.set_content_margin_all(18)
	_box.add_theme_stylebox_override("panel", _box_style)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.anchor_left = 0.08
	_box.anchor_right = 0.92
	_box.anchor_top = 0.7
	_box.anchor_bottom = 0.95
	add_child(_box)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	_box.add_child(column)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 18)
	column.add_child(_name_label)
	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_font_size_override("font_size", TEXT_SIZE)
	column.add_child(_text_label)
	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.add_theme_font_size_override("font_size", 14)
	column.add_child(_hint_label)

	_place_label = Label.new()
	_place_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 24)
	_place_label.add_theme_font_size_override("font_size", 18)
	add_child(_place_label)

	_skip_button = Button.new()
	_skip_button.text = "Skip"
	_skip_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	_skip_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skip_button.focus_mode = Control.FOCUS_NONE
	_skip_button.pressed.connect(_finish)
	add_child(_skip_button)


## Text colors for the act's ground, and for the dark once it falls.
func _style_text() -> void:
	var on_dark: bool = _act.get("setting", "") == "below" or _dark() > 0.5
	var ink := Palette.CHALK_LINE if on_dark else Palette.INK
	var faded := Palette.CHALK_FADED if on_dark else Palette.INK_FADED
	if _dark() > 0.5:
		_box_style.bg_color = Color(Palette.SLATE_DARK, 0.6)
		_box_style.border_color = Palette.CHALK_FADED
	_text_label.add_theme_color_override("font_color", ink if _name_label.visible else faded.lerp(ink, 0.6))
	_name_label.add_theme_color_override("font_color", faded)
	_hint_label.add_theme_color_override("font_color", faded)
	_place_label.add_theme_color_override("font_color", faded)
	_hint_label.text = ("Tap" if Touch.active else "Click or press a key") + " to continue"


# --- Drawing -------------------------------------------------------------------

func _draw() -> void:
	if _act.is_empty():
		return
	var below: bool = _act.get("setting", "") == "below"
	var ground := Palette.SLATE if below else Palette.PARCHMENT
	var ink := Palette.CHALK_LINE if below else Palette.INK
	draw_rect(Rect2(Vector2.ZERO, size), ground)
	var floor_y := size.y * FLOOR
	draw_line(Vector2(size.x * 0.04, floor_y), Vector2(size.x * 0.96, floor_y), ink, 2.0, true)
	_draw_setting(below, floor_y, ink)

	var cast: Dictionary = _act.get("cast", {})
	var speaker := _speaker()
	var scale_r := clampf(size.y / 720.0, 0.6, 1.6)
	if cast.has("groom"):
		var wed := _cue_share("wed")
		_figure("priest", cast, Vector2(size.x * 0.5, floor_y), 70 * scale_r, speaker, below)
		_figure("groom", cast, Vector2(size.x * lerpf(0.32, 0.4, wed), floor_y), 44 * scale_r, speaker, below)
		_figure("bride", cast, Vector2(size.x * lerpf(0.68, 0.6, wed), floor_y), 44 * scale_r, speaker, below)
		if wed > 0.0:
			var c := Vector2(size.x * 0.5, floor_y - 40 * scale_r)
			draw_arc(c, size.x * 0.12, PI * 1.1, PI * 1.9, 32, Color(ink, 0.5 * wed), 2.0, true)
	else:
		var has_inspector := cast.has("inspector")
		var away := _cue_share("away")
		var family_x := 0.8 if has_inspector else 0.72
		_figure("priest", cast, Vector2(size.x * (0.2 if has_inspector else 0.28), floor_y), 70 * scale_r, speaker, below)
		if has_inspector:
			_figure("inspector", cast, Vector2(size.x * 0.64, floor_y), 40 * scale_r, speaker, below)
		var fade := 1.0 - 0.65 * away
		_figure("father", cast, Vector2(size.x * (family_x + 0.06 * away), floor_y), 40 * scale_r, speaker, below, fade)
		_figure("mother", cast, Vector2(size.x * (family_x + 0.08 + 0.06 * away), floor_y), 40 * scale_r, speaker, below, fade)
		# The newborn, on a cushion.
		var cushion := Rect2(size.x * 0.46, floor_y - 18 * scale_r, size.x * 0.08, 18 * scale_r)
		draw_rect(cushion, Palette.SLATE_LIGHT if below else Palette.PARCHMENT_DARK)
		draw_rect(cushion, ink, false, 1.5)
		var baby_at := Vector2(size.x * 0.5, cushion.position.y)
		_figure("newborn", cast, baby_at, 20 * scale_r, speaker, below)
		_draw_cues(baby_at + Vector2(0, -20 * scale_r), 20 * scale_r, ink)

	# Each act fades in; "dark" fades to black and stays.
	var fade_in := 1.0 - clampf((_time - _act_started) / ACT_FADE, 0.0, 1.0)
	if fade_in > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(ground, fade_in))
	if _dark() > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.SLATE_DARK.darkened(0.6), _dark()))


## A little scenery behind the cast, for where the act is.
func _draw_setting(below: bool, floor_y: float, ink: Color) -> void:
	var faint := Color(ink, 0.18)
	match str(_act.get("setting", "")):
		"temple":  # the dome of the Circle
			draw_arc(Vector2(size.x * 0.5, floor_y), size.y * 0.5, PI, TAU, 64, faint, 3.0, true)
			draw_arc(Vector2(size.x * 0.5, floor_y), size.y * 0.46, PI, TAU, 64, faint, 1.5, true)
		"board":  # the examining room: a long bench, and the Board's rule
			draw_line(Vector2(size.x * 0.1, floor_y - size.y * 0.42), Vector2(size.x * 0.9, floor_y - size.y * 0.42), faint, 2.0)
			for i in 9:
				var x := size.x * (0.14 + i * 0.09)
				draw_line(Vector2(x, floor_y - size.y * 0.42), Vector2(x, floor_y - size.y * 0.4), faint, 2.0)
		_:  # below: a crooked ceiling
			if below:
				var pts := PackedVector2Array()
				for i in 13:
					var x := size.x * i / 12.0
					pts.append(Vector2(x, size.y * (0.08 + 0.05 * float((i * 7) % 3))))
				draw_polyline(pts, faint, 2.0, true)


## One of the cast standing on the floor at `at` (or the newborn on its cushion).
func _figure(role: String, cast: Dictionary, at: Vector2, radius: float, speaker: String,
		below: bool, alpha := 1.0) -> void:
	if not cast.has(role):
		return
	var data: Dictionary = cast[role]
	var ink := Color(Palette.CHALK_LINE if below else Palette.INK, alpha)
	var speaking := role == speaker
	var lift := absf(sin(_time * 7.0)) * 3.0 if speaking else 0.0
	var width := 3.5 if speaking else 2.5
	if str(data.get("kind", "")) == "line":
		# A woman: a straight line with one bright eye, swaying (her peace-cry).
		var sway := sin(_time * 2.2 + at.x) * 0.12
		var top := at + Vector2(0, -radius * 2.0 - lift).rotated(sway)
		draw_line(at, top, ink, width + 1.0, true)
		draw_circle(top, 5.0, Color(Palette.XP if not below else Palette.CHALK[2], alpha))
		return
	var sides := int(data.get("sides", 4))
	var kind := str(data.get("kind", "regular"))
	var pts := ShapeGeometry.points(sides, kind, radius, float(data.get("apex", 45)))
	var lowest := 0.0
	for p in pts:
		lowest = maxf(lowest, p.y)
	var shifted := PackedVector2Array()
	for p in pts:
		shifted.append(p + at - Vector2(0, lowest + lift))
	var fill := Palette.chalk_for_sides(sides) if below else Palette.PLAIN  # colour only below (log 0069)
	draw_colored_polygon(shifted, Color(fill, alpha))
	shifted.append(shifted[0])
	draw_polyline(shifted, ink, width, true)
	if role == "priest" and kind != "irregular":
		var center := at - Vector2(0, lowest + lift)
		draw_arc(center, radius + 8, 0, TAU, 48, Color(Palette.CHALK[5], 0.9 * alpha), 3.0, true)


## The newborn's cues: calipers, bells, a halo.
func _draw_cues(center: Vector2, radius: float, ink: Color) -> void:
	var measuring := 1.0 - clampf((_time - float(_cues.get("measure", 0.0)) - MEASURE_TIME) / CUE_TIME, 0.0, 1.0)
	if _cues.has("measure") and measuring > 0.0:
		ink = Color(ink, ink.a * measuring)
		var open := _cue_share("measure")
		var half := radius * (1.1 + 0.5 * (1.0 - open))
		var y := center.y - radius * 2.0
		for side in [-1.0, 1.0]:
			var x: float = center.x + side * half
			draw_line(Vector2(x, y - 8), Vector2(x, center.y + radius), Color(ink, 0.7), 1.5, true)
		draw_dashed_line(Vector2(center.x - half, y), Vector2(center.x + half, y), Color(ink, 0.7), 1.5, 5.0)
	if _cues.has("bells"):
		for corner in [Vector2(size.x * 0.1, size.y * 0.32), Vector2(size.x * 0.9, size.y * 0.32)]:
			for ring in 3:
				var t := fmod(_time - _cues.bells + ring * 0.4, 1.2) / 1.2
				draw_arc(corner, 20 + t * 90, 0, TAU, 40, Color(Palette.XP, 0.8 * (1.0 - t)), 3.0, true)
	if _cues.has("light"):
		var pulse := 0.6 + 0.4 * sin(_time * 3.0)
		draw_arc(center, radius * 1.8, 0, TAU, 48, Color(Palette.CHALK[5], pulse * _cue_share("light")), 4.0, true)


func _speaker() -> String:
	var beats: Array = _act.get("beats", [])
	if _beat_index < 0 or _beat_index >= beats.size():
		return ""
	return str(beats[_beat_index].get("who", ""))


## 0 -> 1 over CUE_TIME once `cue` began this act; 0 if it hasn't.
func _cue_share(cue: String) -> float:
	if not _cues.has(cue):
		return 0.0
	return clampf((_time - float(_cues[cue])) / CUE_TIME, 0.0, 1.0)


func _dark() -> float:
	if not _cues.has("dark"):
		return 0.0
	return clampf((_time - float(_cues.dark)) / DARK_FADE, 0.0, 1.0)


# --- Seen before (this machine) ----------------------------------------------

func _load_seen() -> Dictionary:
	var cfg := ConfigFile.new()
	var seen := {}
	if cfg.load(SEEN_FILE) == OK:
		for id in cfg.get_section_keys("seen") if cfg.has_section("seen") else PackedStringArray():
			seen[id] = true
	return seen


func _mark_seen(id: String) -> void:
	if id == "":
		return
	var cfg := ConfigFile.new()
	cfg.load(SEEN_FILE)  # missing is fine: a new file
	cfg.set_value("seen", id, true)
	cfg.save(SEEN_FILE)

class_name CutscenePlayer
extends Control
## Plays a cutscene full-screen over the game, which runs on behind it
## (design logs 0168, 0172, 0179). One beat at a time, typed out; a click,
## tap or key shows the rest of a beat, then the next. An act seen before
## on this machine can be skipped (Skip, or Esc).
##
## The server writes cutscenes as data (Cutscenes, and each quest's
## scenes); this draws any of them, in the game's style: ink on parchment
## above, chalk on slate below. The format:
##
## scene: {"acts": [act, ...], "wake": [line, ...], "wake_speaker": name}.
##   `wake` is said in the world once the overlay closes, by `wake_speaker`
##   (an NPC's name, or "" for your own thoughts).
## act: {"id", "setting", "place", "cast": [actor, ...], "beats": [beat, ...]}
##   - id: names the act for "seen before" (skippable after the first time).
##   - setting: a key of SETTINGS (scenery and ground); unknown is a bare stage.
##   - place: a caption, top left.
## actor: {"id", "name", "sides", "kind", "apex", "x", "size", "look",
##   "halo", "cushion", "wear"}. Only "id" is required.
##   - x: where it stands, 0 (left) to 1 (right). size: its radius, in px
##     on a 720 px tall screen.
##   - look: "shape" (a polygon, the default), "line" (a woman: a line with
##     an eye, swaying a little; her peace-cry, book Part I §4) or "dummy"
##     (a drill-yard wild shape: lumpy, flat on the ground, log 0224).
##   - halo: a priest's ring. cushion: it lies on a cushion (a newborn).
##   - wear: gear item strings, as PlayerInventory.equipped (crosshatch).
## beat: {"who": an actor id, or "" for narration, "text", "cues": [cue, ...]}
## cue: {"do", "who", ...}, starting when its beat does:
##   - move {to: x}: walks there. fade {alpha}: fades to that.
##   - hop: bobs with excitement. fall: topples over and fades (a wild shape bolts).
##   - jump {onto: actor id, height: share of the screen, hit: text}: leaps
##     up, flips, and comes down point first on `onto`, which shakes and
##     shows `hit`, then flips back upright and bounces back to where it
##     stood.
##   - measure (calipers), bells (rejoicing), light (a halo): around `who`.
##   - join {with: actor id}: an arc over the two (a wedding).
##   - dark: everything fades to black from here on (no `who`).

signal finished(scene: Dictionary)

const SEEN_FILE := "user://cutscenes.cfg"
const CHARS_PER_SECOND := 45.0
const START_FADE := 0.8  # s, fading in over the world as a cutscene opens
const ACT_FADE := 0.6  # s, fading each act in from its background
const END_FADE := 0.5  # s, fading out over the world
const DARK_FADE := 1.0  # s, the "dark" cue's fade to black
const CUE_TIME := 1.0  # s for a move, fade or fall to finish
const JUMP_UP := 0.6  # s from the jump to landing on its target
const JUMP_BACK := 0.6  # s bouncing back off it
const STRUCK_TIME := 0.9  # s a struck actor shakes and shows its hit
const MEASURE_TIME := 4.0  # s the calipers stay before fading
const FLOOR := 0.62  # the stage floor, as a share of the height
const TEXT_SIZE := 22
const CARD_TEXT_SIZE := 26

## Where an act can take place. dark: chalk on slate. card: no stage, just
## words on the ground (a chronicle's page between scenes).
const SETTINGS := {
	"board": {},  # the Sanitary and Social Board's examining room
	"temple": {},  # under the dome of the Circle
	"yard": {},  # the barracks' drill yard
	"camp": {},  # the rangers' island (log 0245)
	"below": {"dark": true},  # the Undercroft
	"card": {"card": true},
	"card_below": {"card": true, "dark": true},
}

var _scene: Dictionary = {}
var _act: Dictionary = {}
var _act_index := 0
var _beat_index := -1
var _cast: Dictionary = {}  # actor id -> actor data
var _state: Dictionary = {}  # actor id -> what its cues have done to it
var _joins: Array = []  # [a, b, start time]
var _dark_at := -1.0  # _time the "dark" cue began, or -1
var _time := 0.0
var _act_started := 0.0
var _reveal := 0.0  # characters of the beat shown so far
var _ending := -1.0  # _time the fade out began, or -1
var _opening := -1.0  # _time the fade in over the world began, or -1
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


## Plays `scene`, replacing any already playing.
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
	if not visible or _ending >= 0.0:
		_opening = _time  # fade in over the world (not when replacing one on screen)
		modulate.a = 0.0
	visible = true
	_ending = -1.0
	Controls.watching = true
	_start_act(0)


func _start_act(index: int) -> void:
	_act_index = index
	_act = _scene.acts[index]
	_cast.clear()
	_state.clear()
	for actor: Dictionary in _act.get("cast", []):
		var id := str(actor.get("id", ""))
		_cast[id] = actor
		_state[id] = {"x": float(actor.get("x", 0.5)), "alpha": 1.0, "fx": {}}
	_joins.clear()
	_dark_at = -1.0
	_act_started = _time
	_beat_index = -1
	var card := _is_card()
	_box_style.bg_color = Color(0, 0, 0, 0) if card else (Color(Palette.SLATE_DARK, 0.92) if _is_dark()
			else Color(Palette.PARCHMENT_LIGHT, 0.95))
	_box_style.border_color = Color(0, 0, 0, 0) if card else (Palette.CHALK_LINE if _is_dark() else Palette.INK)
	_box.anchor_top = 0.3 if card else 0.7
	_box.anchor_bottom = 0.75 if card else 0.95
	_box.anchor_left = 0.16 if card else 0.08
	_box.anchor_right = 0.84 if card else 0.92
	_text_label.add_theme_font_size_override("font_size", CARD_TEXT_SIZE if card else TEXT_SIZE)
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
	for cue: Dictionary in beat.get("cues", []):
		_start_cue(cue)
	var who := str(beat.get("who", ""))
	var narration := who == "" or not _cast.has(who)
	_name_label.visible = not narration
	_name_label.text = "" if narration else str(_cast[who].get("name", ""))
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
	if _opening >= 0.0:
		modulate.a = clampf((_time - _opening) / START_FADE, 0.0, 1.0)
		if modulate.a >= 1.0:
			_opening = -1.0
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


# --- Cues ----------------------------------------------------------------------

func _start_cue(cue: Dictionary) -> void:
	var what := str(cue.get("do", ""))
	if what == "dark":
		if _dark_at < 0.0:
			_dark_at = _time
		return
	var who := str(cue.get("who", ""))
	if not _state.has(who):
		return
	var s: Dictionary = _state[who]
	match what:
		"move":
			s.x = _x_of(who)
			s.move = [s.x, float(cue.get("to", s.x)), _time]
		"fade":
			s.alpha = _alpha_of(who)
			s.fade = [s.alpha, float(cue.get("alpha", 0.0)), _time]
		"jump":
			var onto := str(cue.get("onto", ""))
			if _state.has(onto):
				s.jump = {"onto": onto, "start": _time, "height": float(cue.get("height", 0.3))}
				(_state[onto].fx as Dictionary)["struck"] = _time + JUMP_UP
				_state[onto].hit = str(cue.get("hit", ""))
		"join":
			_joins.append([who, str(cue.get("with", "")), _time])
		_:  # hop, fall, measure, bells, light
			(s.fx as Dictionary)[what] = _time


## 0 -> 1 over `length` from `start`, eased; 0 before it.
func _share(start: float, length := CUE_TIME) -> float:
	var t := clampf((_time - start) / length, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Seconds since actor `who`'s effect `fx` began, or -1 if it hasn't.
func _since(who: String, fx: String) -> float:
	var started: Variant = (_state[who].fx as Dictionary).get(fx)
	if started == null or _time < float(started):
		return -1.0
	return _time - float(started)


func _x_of(who: String) -> float:
	var s: Dictionary = _state[who]
	if not s.has("move"):
		return s.x
	var m: Array = s.move
	return lerpf(m[0], m[1], _share(m[2]))


func _alpha_of(who: String) -> float:
	var s: Dictionary = _state[who]
	var a: float = s.alpha
	if s.has("fade"):
		var f: Array = s.fade
		a = lerpf(f[0], f[1], _share(f[2]))
	return a


func _dark() -> float:
	return 0.0 if _dark_at < 0.0 else clampf((_time - _dark_at) / DARK_FADE, 0.0, 1.0)


func _is_dark() -> bool:
	return bool((SETTINGS.get(str(_act.get("setting", "")), {}) as Dictionary).get("dark", false))


func _is_card() -> bool:
	return bool((SETTINGS.get(str(_act.get("setting", "")), {}) as Dictionary).get("card", false))


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
	var on_dark: bool = _is_dark() or _dark() > 0.5
	var ink := Palette.CHALK_LINE if on_dark else Palette.INK
	var faded := Palette.CHALK_FADED if on_dark else Palette.INK_FADED
	if _dark() > 0.5 and not _is_card():
		_box_style.bg_color = Color(Palette.SLATE_DARK, 0.6)
		_box_style.border_color = Palette.CHALK_FADED
	var narration := not _name_label.visible
	_text_label.add_theme_color_override("font_color", faded.lerp(ink, 0.85 if _is_card() else 0.6) if narration else ink)
	_name_label.add_theme_color_override("font_color", faded)
	_hint_label.add_theme_color_override("font_color", faded)
	_place_label.add_theme_color_override("font_color", faded)
	_hint_label.text = ("Tap" if Touch.active else "Click or press a key") + " to continue"


# --- Drawing -------------------------------------------------------------------

func _draw() -> void:
	if _act.is_empty():
		return
	var dark := _is_dark()
	var ground := Palette.SLATE if dark else Palette.PARCHMENT
	var ink := Palette.CHALK_LINE if dark else Palette.INK
	draw_rect(Rect2(Vector2.ZERO, size), ground)
	var floor_y := size.y * FLOOR
	if _is_card():
		_draw_card_rule(ink)
	else:
		draw_line(Vector2(size.x * 0.04, floor_y), Vector2(size.x * 0.96, floor_y), ink, 2.0, true)
		_draw_setting(floor_y, ink)
		var scale_r := clampf(size.y / 720.0, 0.6, 1.6)
		for join: Array in _joins:
			_draw_join(join, floor_y, scale_r, ink)
		for actor: Dictionary in _act.get("cast", []):
			_draw_actor(str(actor.get("id", "")), floor_y, scale_r, ink)

	# Each act fades in; "dark" fades to black and stays.
	var fade_in := 1.0 - clampf((_time - _act_started) / ACT_FADE, 0.0, 1.0)
	if fade_in > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(ground, fade_in))
	if _dark() > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.SLATE_DARK.darkened(0.6), _dark()))


## A chronicle's page: a rule above and below the words.
func _draw_card_rule(ink: Color) -> void:
	var faint := Color(ink, 0.3)
	for y: float in [size.y * 0.26, size.y * 0.79]:
		draw_line(Vector2(size.x * 0.3, y), Vector2(size.x * 0.7, y), faint, 1.5, true)
		draw_circle(Vector2(size.x * 0.5, y), 3.0, faint)


## A little scenery behind the cast, for where the act is.
func _draw_setting(floor_y: float, ink: Color) -> void:
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
		"yard":  # the barracks' hall overhead, on its mound (log 0222)
			var mound := PackedVector2Array()
			for i in 17:
				var u := i / 16.0
				mound.append(Vector2(size.x * (0.62 + 0.34 * u), size.y * 0.2 + sin(u * PI) * size.y * 0.05))
			draw_polyline(mound, faint, 2.5, true)
			draw_line(mound[0], mound[-1], faint, 2.5, true)
		"camp":  # the island's cliff edge, and the sea far below
			draw_line(Vector2(size.x * 0.88, floor_y), Vector2(size.x * 0.88, floor_y + size.y * 0.2), faint, 2.5, true)
			for i in 6:
				var x := size.x * (0.9 + i * 0.02)
				draw_arc(Vector2(x, floor_y + size.y * 0.3), 8.0, PI * 1.15, PI * 1.85, 6, faint, 1.5, true)
		"below":  # a crooked ceiling
			var pts := PackedVector2Array()
			for i in 13:
				var x := size.x * i / 12.0
				pts.append(Vector2(x, size.y * (0.08 + 0.05 * float((i * 7) % 3))))
			draw_polyline(pts, faint, 2.0, true)


## An arc over two actors (a wedding's "join").
func _draw_join(join: Array, floor_y: float, scale_r: float, ink: Color) -> void:
	if not _state.has(join[0]) or not _state.has(join[1]):
		return
	var share := _share(join[2])
	var a := size.x * _x_of(join[0])
	var b := size.x * _x_of(join[1])
	var c := Vector2((a + b) / 2.0, floor_y - 40 * scale_r)
	var reach := maxf(absf(b - a) / 2.0 + 30 * scale_r, size.x * 0.06)
	draw_arc(c, reach, PI * 1.1, PI * 1.9, 32, Color(ink, 0.5 * share), 2.0, true)


func _speaker() -> String:
	var beats: Array = _act.get("beats", [])
	if _beat_index < 0 or _beat_index >= beats.size():
		return ""
	return str(beats[_beat_index].get("who", ""))


## Where actor `who` stands right now (its floor point) and how it's
## turned, after its cues: {"at", "turn", "alpha", "radius", "top"}.
func _pose(who: String, floor_y: float, scale_r: float) -> Dictionary:
	var actor: Dictionary = _cast[who]
	var radius := float(actor.get("size", 40.0)) * scale_r
	var at := Vector2(size.x * _x_of(who), floor_y)
	if actor.get("cushion", false):
		at.y -= 18 * scale_r
	var turn := 0.0
	var s: Dictionary = _state[who]
	if s.has("jump") and _state.has(str(s.jump.onto)):
		var j: Dictionary = s.jump
		var t := _time - float(j.start)
		var target: Dictionary = _pose(str(j.onto), floor_y, scale_r)
		var top: Vector2 = target.top
		var peak := size.y * float(j.height)
		if t < JUMP_UP:
			var u := t / JUMP_UP
			# Flips over on the way up, so it lands point first.
			turn = PI * minf(u / 0.7, 1.0) * (1.0 if top.x >= at.x else -1.0)
			at = Vector2(lerpf(at.x, top.x, u), lerpf(at.y, top.y, u) - peak * 4.0 * u * (1.0 - u))
		elif t < JUMP_UP + JUMP_BACK:
			var u := (t - JUMP_UP) / JUMP_BACK
			var hop := size.y * 0.12
			turn = PI * (1.0 + u) * (1.0 if top.x >= at.x else -1.0)  # and back upright
			at = Vector2(lerpf(top.x, at.x, u), lerpf(top.y, at.y, u) - hop * 4.0 * u * (1.0 - u))
	var hopped := _since(who, "hop")
	if hopped >= 0.0 and hopped < 1.2:
		at.y -= absf(sin(hopped * TAU * 1.5)) * 14 * scale_r
	var struck := _since(who, "struck")
	if struck >= 0.0 and struck < STRUCK_TIME * 0.5:
		at.x += sin(struck * 70.0) * 5 * scale_r * (1.0 - struck / (STRUCK_TIME * 0.5))
	var fell := _since(who, "fall")
	if fell >= 0.0:
		turn += PI * 0.5 * _share(_time - fell, CUE_TIME * 0.6)  # rolls over (a wild shape bolts, _draw_actor)
	var alpha := _alpha_of(who)
	if fell >= 0.0:  # topples, then fades
		alpha *= 1.0 - clampf((fell - CUE_TIME * 0.6) / CUE_TIME, 0.0, 1.0)
	var tall := radius * 2.0
	return {"at": at, "turn": turn, "alpha": alpha, "radius": radius, "top": at - Vector2(0, tall)}


func _draw_actor(who: String, floor_y: float, scale_r: float, ink_base: Color) -> void:
	var actor: Dictionary = _cast[who]
	var pose := _pose(who, floor_y, scale_r)
	var alpha: float = pose.alpha
	if alpha <= 0.01:
		return
	var at: Vector2 = pose.at
	var radius: float = pose.radius
	var dark := _is_dark()
	var ink := Color(ink_base, alpha)
	var speaking := who == _speaker()
	var lift := absf(sin(_time * 7.0)) * 3.0 if speaking else 0.0
	var width := 3.5 if speaking else 2.5
	if actor.get("cushion", false):
		var cushion := Rect2(at.x - radius * 1.9, at.y, radius * 3.8, 18 * scale_r)
		draw_rect(cushion, Palette.SLATE_LIGHT if dark else Palette.PARCHMENT_DARK)
		draw_rect(cushion, ink_base, false, 1.5)
	var look := str(actor.get("look", "shape"))
	if look == "line":
		# A woman: a straight line with one bright eye, swaying (her peace-cry).
		var sway := sin(_time * 2.2 + at.x) * 0.12
		var tip := at + Vector2(0, -radius * 2.0 - lift).rotated(sway)
		draw_line(at, tip, ink, width + 1.0, true)
		draw_circle(tip, 5.0, Color(Palette.XP if not dark else Palette.CHALK[2], alpha))
		_draw_effects(who, at - Vector2(0, radius), radius, ink_base)
		return
	var sides := int(actor.get("sides", 4))
	var kind := str(actor.get("kind", "regular"))
	var pts := ShapeGeometry.points(sides, kind, radius, float(actor.get("apex", 45)))
	var lowest := 0.0
	for p in pts:
		lowest = maxf(lowest, p.y)
	var placed := PackedVector2Array()
	var lowest_turned := 0.0  # stands on whichever corner is lowest now (a jump's flip)
	for p in pts:
		placed.append(p.rotated(float(pose.turn)))
		lowest_turned = maxf(lowest_turned, placed[-1].y)
	var center := at - Vector2(0, lowest_turned + lift)
	if look == "dummy":
		# A wild shape, flat to the ground. Knocked down, it bolts.
		var fell := _since(who, "fall")
		if fell >= 0.0:
			center.x += radius * 3.0 * _share(_time - fell, CUE_TIME * 1.2)
	var wear: Array = actor.get("wear", [])
	if not wear.is_empty() and not dark and alpha > 0.99:
		Gear.draw_shape(self, placed, sides, PackedStringArray(wear), center)
	else:
		var fill := Palette.chalk_for_sides(sides) if dark else Palette.PLAIN  # colour only below (log 0069)
		var world := PackedVector2Array()
		for p in placed:
			world.append(p + center)
		draw_colored_polygon(world, Color(fill, alpha))
		if look == "dummy":
			Gear.draw_hatch(self, world, [[80.0, 100.0], 7.0], scale_r, Color(Palette.INK, 0.3 * alpha))
		world.append(world[0])
		draw_polyline(world, ink, width, true)
	if actor.get("halo", false):
		draw_arc(center, radius + 8, 0, TAU, 48, Color(Palette.CHALK[5], 0.9 * alpha), 3.0, true)
	_draw_effects(who, center, radius, ink_base)


## A cue's marks around actor `who`: calipers, bells, a halo, a hit.
func _draw_effects(who: String, center: Vector2, radius: float, ink: Color) -> void:
	var measured := _since(who, "measure")
	if measured >= 0.0:
		var fade := 1.0 - clampf((measured - MEASURE_TIME) / CUE_TIME, 0.0, 1.0)
		if fade > 0.0:
			var open := _share(_time - measured)
			var span := radius * (1.3 + 0.5 * open)
			for side: float in [-1.0, 1.0]:
				draw_line(center + Vector2(side * span, -radius * 1.6), center + Vector2(side * span * 0.85, radius * 0.6), Color(ink, fade), 2.0, true)
			draw_line(center + Vector2(-span, -radius * 1.6), center + Vector2(span, -radius * 1.6), Color(ink, fade), 2.0, true)
	var rang := _since(who, "bells")
	if rang >= 0.0:
		for ring in 3:
			var t := fmod(rang + ring * 0.4, 1.2) / 1.2
			draw_arc(center, radius * (1.4 + t * 2.5), 0, TAU, 40, Color(ink, 0.5 * (1.0 - t)), 2.0, true)
	var lit := _since(who, "light")
	if lit >= 0.0:
		var pulse := 0.6 + 0.4 * sin(_time * 3.0)
		draw_arc(center, radius * 1.8, 0, TAU, 48, Color(Palette.CHALK[5], pulse * _share(_time - lit)), 4.0, true)
	var struck := _since(who, "struck")
	if struck >= 0.0 and struck < STRUCK_TIME:
		var t := struck / STRUCK_TIME
		for i in 6:
			var dir := Vector2.from_angle(TAU * i / 6.0 + 0.4)
			draw_line(center + dir * radius * (1.0 + t * 0.6), center + dir * radius * (1.3 + t * 0.9), Color(ink, 1.0 - t), 2.5, true)
		var hit := str(_state[who].get("hit", ""))
		if hit != "":
			var font := ThemeDB.fallback_font
			var at := center + Vector2(radius * 1.2, -radius * 0.6 - t * 30)
			draw_string(font, at, hit, HORIZONTAL_ALIGNMENT_LEFT, 120, 26, Color(Palette.INK, 1.0 - t))


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

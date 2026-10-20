class_name ConsoleCompanion
extends VBoxContainer
## imsdow, the admin terminal's companion (design logs 0141, 0143, 0146):
## waves hello when the terminal opens (or is found asleep, now and then),
## dozes off when left alone, and talks: puns, and bits of the game's design
## history. Asleep, commands get mumbled answers until the third wakes her,
## blushing. Her lines and settings: assets/companion/imsdow.cfg.
##
## Each folder in assets/companion/ is one animation, each file in it one
## frame, in name order: text (.txt, ASCII art drawn in the terminal font)
## or a picture (.png, black ink on clear, colored by companion_pop.gdshader).
## An optional anim.cfg, section [anim], sets:
##   frame_time  s per frame (0.25)
##   repeat      times through the frames (1)
##   sequence    frame numbers to play, from 1, e.g. [1, 2, 3, 2, 1]
##   offsets     a Vector2 per picture frame, in image px, to line them up
##   every       Vector2(min, max) s: plays by itself while she rests
##   after_quiet s with nothing typed before it plays by itself (sleeping)
##   loop        true: she's asleep; plays until commands wake her
##   blush       per picture frame, a list of Rect2 (its own px, up to 4)
##               whose ink is drawn blush pink
## "idle" shows between animations (else the first frame of "wave"); "wave"
## plays on hello, "blink" every few seconds (unless its every says
## otherwise). Pictures can be cleaned into ink with tools/companion_ink.py.

const ROOT := "res://assets/companion/"
const PICTURES: Array[String] = ["png", "webp", "jpg"]
const BLINK_EVERY := Vector2(2.5, 5.0)  # s between blinks, unless blink/anim.cfg says
const MAX_BLUSH_AREAS := 4  # as in companion_pop.gdshader
## A fixed-width font's character, in font sizes: width and line height.
const CHAR_SIZE := Vector2(0.6, 1.18)
const POP := preload("res://scripts/ui/companion_pop.gdshader")
const SETTINGS := ROOT + "imsdow.cfg"
## Her settings and lines if imsdow.cfg is missing or leaves one out.
const DEFAULTS := {
	"name": "imsdow", "asleep_on_open": 0.3, "commands_to_wake": 3,
	"quip_after_command": 0.35, "quip_every": Vector2(25, 45), "line_time": 6.0,
}
const DEFAULT_LINES := {
	"hello": ["hi, admin! ~"], "asleep": ["zzz..."], "mumbles": ["mmm, a few more minutes..."],
	"waking": ["w-wasn't sleeping!"], "puns": [], "lore": [],
}

var font: Font
var font_size := 10:
	set(value):
		font_size = value
		if is_node_ready():
			_style()
var color := Color.WHITE:
	set(value):
		color = value
		if is_node_ready():
			_style()

## Name -> {"frames": Array (String or Texture2D), "offsets": Array[Vector2],
## "blush": Array (per frame, an Array of Rect2), "frame_time": float,
## "sequence": Array[int] (indexes into frames), "every": Vector2 (0: no)}.
var _anims := {}
var _cols := 1  # the widest text frame, in characters
var _rows := 1
var _speech: Label
var _text: Label
var _picture: _Picture
var _playing := ""  # the animation under way, or "" when resting
var _time := 0.0  # s into the animation
var _due := {}  # animation -> s until it plays by itself (those with an every)
var _quiet := 0.0  # s since anything was typed
var _settings := DEFAULTS.duplicate()
var _lines := DEFAULT_LINES.duplicate(true)  # list name -> lines
var _sleepy_commands := 0  # commands typed since she fell asleep
var _speech_left := 0.0  # s until her line clears
var _quip_in := 30.0  # s until she says something by herself
var _name_tag: Label
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_END
	_rng.randomize()
	_load_settings()
	_speech = Label.new()
	_speech.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_speech)
	_text = Label.new()
	add_child(_text)
	_picture = _Picture.new()
	_picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var pop := ShaderMaterial.new()
	pop.shader = POP
	_picture.material = pop
	add_child(_picture)
	_name_tag = Label.new()
	_name_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_tag.text = "~ %s ~" % _settings.name
	add_child(_name_tag)
	_load()
	_quip_in = _next_quip_wait()
	_style()
	_rest()


## The terminal opened: waves and says hello, or, now and then, she's
## found asleep.
func hello() -> void:
	_quiet = 0.0
	if _anims.has("sleeping") and _rng.randf() < float(_settings.asleep_on_open):
		_fall_asleep()
		return
	play("wave")
	say(_pick("hello"))


## Says something (or nothing, with ""), for a while.
func say(line: String) -> void:
	_speech.text = "< %s >" % line if line != "" else ""
	_speech_left = maxf(float(_settings.line_time), line.length() * 0.07)


## A key was pressed: she's not alone, so she won't doze off yet.
func poke() -> void:
	_quiet = 0.0


## A command was run. Asleep, she mumbles, and the third wakes her; awake,
## she sometimes has something to say.
func command() -> void:
	_quiet = 0.0
	if is_asleep():
		_sleepy_commands += 1
		if _sleepy_commands >= int(_settings.commands_to_wake):
			_wake()
		else:
			say(_pick("mumbles"))
	elif _rng.randf() < float(_settings.quip_after_command):
		say(_quip())


## Asleep: playing a looping animation.
func is_asleep() -> bool:
	return _playing != "" and _anims[_playing].loop


func _fall_asleep() -> void:
	_sleepy_commands = 0
	play("sleeping")
	say(_pick("asleep"))


## Woken up: caught napping, she blushes.
func _wake() -> void:
	_sleepy_commands = 0
	_playing = ""
	say(_pick("waking"))
	if _anims.has("blush"):
		play("blush")
	else:
		_rest()


## Starts an animation (a folder's name) from its first frame.
func play(anim: String) -> void:
	if not _anims.has(anim):
		return
	_playing = anim
	_time = 0.0
	_show(anim, _anims[anim].sequence[0])


## Sizes her to fit in `box` px: text by font size (4 to 12), pictures by
## scale (never above their own size).
func fit(box: Vector2) -> void:
	font_size = clampi(int(minf(box.x / (_cols * CHAR_SIZE.x), box.y / (_rows * CHAR_SIZE.y))), 4, 12)
	var canvas := _picture.canvas.size
	if canvas.x > 0.0 and canvas.y > 0.0:
		_picture.scale_by = minf(minf(box.x / canvas.x, box.y / canvas.y), 1.0)
		_picture.update_minimum_size()
		_picture.queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_quiet += delta
	if _speech_left > 0.0:
		_speech_left -= delta
		if _speech_left <= 0.0:
			_speech.text = ""
	if _playing == "":
		_quip_in -= delta
		if _quip_in <= 0.0:
			_quip_in = _next_quip_wait()
			say(_quip())
		for anim: String in _anims:
			var after: float = _anims[anim].after_quiet
			if after > 0.0 and _quiet >= after:
				if anim == "sleeping":
					_fall_asleep()
				else:
					play(anim)
				return
		for anim: String in _due:
			_due[anim] -= delta
		for anim: String in _due:
			if _due[anim] <= 0.0:
				var every: Vector2 = _anims[anim].every
				_due[anim] = _rng.randf_range(every.x, every.y)
				play(anim)
				break
		return
	_time += delta
	var anim: Dictionary = _anims[_playing]
	var step := int(_time / anim.frame_time)
	if anim.loop:
		step %= anim.sequence.size()
	if step >= anim.sequence.size():
		_playing = ""
		_rest()
	else:
		_show(_playing, anim.sequence[step])


## A random line from one of imsdow.cfg's lists.
func _pick(list: String) -> String:
	var lines: Array = _lines.get(list, [])
	return str(lines[_rng.randi() % lines.size()]) if not lines.is_empty() else ""


## A pun or a bit of design history.
func _quip() -> String:
	var all: Array = _lines.get("puns", []) + _lines.get("lore", [])
	return str(all[_rng.randi() % all.size()]) if not all.is_empty() else ""


func _next_quip_wait() -> float:
	var every: Vector2 = _settings.quip_every
	return _rng.randf_range(every.x, maxf(every.y, every.x))


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS) != OK:
		return
	for key: String in DEFAULTS:
		var value: Variant = config.get_value("imsdow", key, DEFAULTS[key])
		if typeof(value) == typeof(DEFAULTS[key]) or (value is int and DEFAULTS[key] is float):
			_settings[key] = value
	for list: String in DEFAULT_LINES:
		var lines: Variant = config.get_value("lines", list, [])
		if lines is Array and not (lines as Array).is_empty():
			_lines[list] = lines


## Between animations: idle, or else the wave's first frame.
func _rest() -> void:
	if _anims.has("idle"):
		_show("idle", _anims.idle.sequence[0])
	elif _anims.has("wave"):
		_show("wave", _anims.wave.sequence[0])


func _show(anim: String, index: int) -> void:
	var data: Dictionary = _anims.get(anim, {})
	var frames: Array = data.get("frames", [])
	if index < 0 or index >= frames.size():
		return
	var frame: Variant = frames[index]
	_text.visible = frame is String
	_picture.visible = frame is Texture2D
	if frame is String:
		if _text.text != frame:
			_text.text = frame
	elif _picture.texture != frame:
		_picture.texture = frame
		_picture.offset = data.offsets[index]
		_set_blush(data.blush[index], (frame as Texture2D).get_size())
		_picture.queue_redraw()


## Hands the shader this frame's blush areas, in UV.
func _set_blush(areas: Array, image_size: Vector2) -> void:
	var uv: Array[Vector4] = []
	for rect: Rect2 in areas:
		uv.append(Vector4(rect.position.x / image_size.x, rect.position.y / image_size.y,
				rect.end.x / image_size.x, rect.end.y / image_size.y))
	var count := uv.size()
	while uv.size() < MAX_BLUSH_AREAS:
		uv.append(Vector4.ZERO)
	var pop := _picture.material as ShaderMaterial
	pop.set_shader_parameter("blush_areas", uv)
	pop.set_shader_parameter("blush_count", count)


## Reads every animation folder. Text frames are padded to one size and
## pictures share one canvas, so she doesn't shift as frames change.
func _load() -> void:
	var canvas := Rect2()
	for anim in DirAccess.get_directories_at(ROOT):
		var frames: Array = []
		for file in _frame_files(ROOT + anim):
			var path := ROOT + anim + "/" + file
			if file.get_extension() == "txt":
				var lines := FileAccess.get_file_as_string(path).replace("\r", "") \
						.replace("\t", "    ").trim_suffix("\n").split("\n")
				_rows = maxi(_rows, lines.size())
				for line in lines:
					_cols = maxi(_cols, line.length())
				frames.append(lines)
			else:
				var texture := load(path) as Texture2D
				if texture:
					frames.append(texture)
		if frames.is_empty():
			continue
		var config := ConfigFile.new()
		config.load(ROOT + anim + "/anim.cfg")  # missing just leaves the defaults
		var offsets: Array[Vector2] = []
		var given: Array = config.get_value("anim", "offsets", [])
		var blush: Array = []
		var given_blush: Array = config.get_value("anim", "blush", [])
		for i in frames.size():
			offsets.append(given[i] if i < given.size() and given[i] is Vector2 else Vector2.ZERO)
			var areas: Array[Rect2] = []
			if i < given_blush.size() and given_blush[i] is Array:
				for rect: Variant in given_blush[i]:
					if rect is Rect2 and areas.size() < MAX_BLUSH_AREAS:
						areas.append(rect)
			blush.append(areas)
			if frames[i] is Texture2D:
				var rect := Rect2(offsets[i], (frames[i] as Texture2D).get_size())
				canvas = rect if canvas.size == Vector2.ZERO else canvas.merge(rect)
		var sequence: Array[int] = []
		for n: Variant in config.get_value("anim", "sequence", []):
			if (n is int or n is float) and int(n) >= 1 and int(n) <= frames.size():
				sequence.append(int(n) - 1)
		if sequence.is_empty():
			for _round in maxi(int(config.get_value("anim", "repeat", 1)), 1):
				for i in frames.size():
					sequence.append(i)
		var every: Variant = config.get_value("anim", "every",
				BLINK_EVERY if anim == "blink" else Vector2.ZERO)
		if every is Vector2 and (every as Vector2).y > 0.0:
			_due[anim] = _rng.randf_range((every as Vector2).x, (every as Vector2).y)
		_anims[anim] = {
			"frames": frames,
			"offsets": offsets,
			"blush": blush,
			"every": every if every is Vector2 else Vector2.ZERO,
			"after_quiet": float(config.get_value("anim", "after_quiet", 0.0)),
			"loop": bool(config.get_value("anim", "loop", false)),
			"frame_time": maxf(float(config.get_value("anim", "frame_time", 0.25)), 0.02),
			"sequence": sequence,
		}
	for anim: String in _anims:
		var frames: Array = _anims[anim].frames
		for i in frames.size():
			if frames[i] is PackedStringArray:
				var rows: Array[String] = []
				for r in _rows:
					rows.append((frames[i][r] if r < frames[i].size() else "").rpad(_cols))
				frames[i] = "\n".join(rows)
	_picture.canvas = canvas
	if _anims.is_empty():
		push_warning("ConsoleCompanion: no frames in %s" % ROOT)


## A folder's frame files in natural order (frame_2 before frame_10). An
## exported build lists pictures by their .import files, so those count too.
static func _frame_files(dir: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		var name := file.trim_suffix(".import").trim_suffix(".remap")
		var ext := name.get_extension().to_lower()
		if (ext == "txt" and name == file or ext in PICTURES) and name not in found:
			found.append(name)
	found.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	return found


func _style() -> void:
	for label: Label in [_speech, _text, _name_tag]:
		if font:
			label.add_theme_font_override("font", font)
		# Her speech stays readable however small she's drawn.
		label.add_theme_font_size_override("font_size", maxi(font_size + 4, 13) if label != _text else font_size)
		label.add_theme_color_override("font_color", color)
		label.add_theme_constant_override("line_spacing", 0)
	# Room for three lines of speech, always, so a long line doesn't move her.
	var speech_size := maxi(font_size + 4, 13)
	_speech.max_lines_visible = 3
	_speech.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_speech.custom_minimum_size.y = ceilf(speech_size * 1.25 * 3.0)


## A picture frame, drawn at its offset on a canvas all frames share.
class _Picture extends Control:
	var texture: Texture2D
	var offset := Vector2.ZERO  # image px
	var canvas := Rect2()  # every frame's rect together, image px
	var scale_by := 1.0

	func _get_minimum_size() -> Vector2:
		return canvas.size * scale_by

	func _draw() -> void:
		if texture:
			draw_texture_rect(texture, Rect2((offset - canvas.position) * scale_by,
					texture.get_size() * scale_by), false)

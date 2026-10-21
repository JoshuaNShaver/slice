class_name SpeechBubble
extends Control
## A line of speech or a thought, pinned to someone in the world (design
## log 0082). Speech is a parchment box above the speaker, with a dashed line
## down to them. A thought is a cloud beside you, trailing dots back to you.
##
## Lives in the HUD, over the whole screen; it follows its target through
## the world camera each frame, and stays on screen.

const MAX_WIDTH := 320.0
const MAX_LINES := 3
const PADDING := Vector2(14, 10)
const SPEECH_GAP := 46.0  # px from the anchor up to the box
const THOUGHT_OFFSET := Vector2(40, -70)  # from the anchor to the cloud's bottom-left
const SCREEN_MARGIN := 16.0
const TOP_MARGIN := 150.0  # keep clear of the vitals and the pay counter
const BASE_TIME := 3.0  # s on screen, plus a little per character
const TIME_PER_CHAR := 0.04

static var _speech_style: SketchBox
var thought := false
## Where the tail points, relative to the target's position.
var anchor_offset := Vector2.ZERO

var _target_id := 0
var _label: Label
var _lines: Array[String] = []
var _life := 0.0
var _box := Rect2()
var _anchor := Vector2.ZERO
var _tail_color := Palette.INK


func _init(target: Node2D, is_thought: bool, offset: Vector2) -> void:
	_target_id = target.get_instance_id()
	thought = is_thought
	anchor_offset = offset
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	# Set here, not left to the theme: lines are measured before the
	# bubble is in the tree.
	_label.add_theme_font_override("font", UiTheme.menu_font())
	_label.add_theme_font_size_override("font_size", 17)
	_label.add_theme_color_override("font_color", Palette.INK)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


## Adds a line; the oldest goes once there are more than MAX_LINES.
func add_line(text: String) -> void:
	_lines.append(text)
	while _lines.size() > MAX_LINES:
		_lines.pop_front()
	_label.text = "\n".join(_lines)
	_life = BASE_TIME + TIME_PER_CHAR * _label.text.length()
	# Measure: one line per text line, or wrapped at MAX_WIDTH if too wide.
	var font := _label.get_theme_font("font")
	var font_size := _label.get_theme_font_size("font_size")
	var width := 0.0
	for line in _lines:
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if width > MAX_WIDTH else TextServer.AUTOWRAP_OFF
	width = minf(width, MAX_WIDTH) + 2.0
	_label.size = Vector2(width, 0)
	_label.size = Vector2(width, _label.get_line_count() * _label.get_line_height()
			+ maxi(0, _label.get_line_count() - 1) * _label.get_theme_constant("line_spacing"))
	_place()


## The box on screen (for keeping thoughts clear of speech).
func box() -> Rect2:
	return _box


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0 or not is_instance_valid(instance_from_id(_target_id)):
		queue_free()
		return
	modulate.a = clampf(_life * 2.0, 0.0, 1.0)
	_place()


func _place() -> void:
	var target := instance_from_id(_target_id) as Node2D
	if target == null:
		return
	var world_point := target.global_position + anchor_offset
	_tail_color = Palette.ink_at(world_point)
	_anchor = get_viewport().get_canvas_transform() * world_point
	var box_size := _label.size + PADDING * 2.0
	var pos: Vector2
	if thought:
		pos = _anchor + THOUGHT_OFFSET - Vector2(0, box_size.y)
	else:
		pos = _anchor - Vector2(box_size.x / 2.0, SPEECH_GAP + box_size.y)
	var screen := get_viewport_rect().size
	pos.x = clampf(pos.x, SCREEN_MARGIN, maxf(SCREEN_MARGIN, screen.x - box_size.x - SCREEN_MARGIN))
	pos.y = clampf(pos.y, TOP_MARGIN, maxf(TOP_MARGIN, screen.y - box_size.y - SCREEN_MARGIN))
	_box = Rect2(pos, box_size)
	if thought:
		_dodge_speech(screen)
	_label.position = _box.position + PADDING
	queue_redraw()


## A thought moves to your other side, then above, to stay out of speech.
func _dodge_speech(screen: Vector2) -> void:
	for sibling in get_parent().get_children():
		var other := sibling as SpeechBubble
		if other == null or other == self or other.thought or not other.box().intersects(_box.grow(6)):
			continue
		var flipped := _box
		flipped.position.x = clampf(_anchor.x - THOUGHT_OFFSET.x - _box.size.x, SCREEN_MARGIN,
				maxf(SCREEN_MARGIN, screen.x - _box.size.x - SCREEN_MARGIN))
		if not other.box().intersects(flipped.grow(6)):
			_box = flipped
		else:
			_box.position.y = maxf(TOP_MARGIN, other.box().position.y - _box.size.y - 16)


func _draw() -> void:
	if thought:
		_draw_cloud()
	else:
		_draw_speech()


func _draw_speech() -> void:
	# The tail leaves the box's bottom edge at the point nearest the speaker.
	var from := Vector2(clampf(_anchor.x, _box.position.x + 12, _box.end.x - 12), _box.end.y)
	if _anchor.y < _box.end.y:  # the speaker is above (the box was pushed down)
		from.y = _box.position.y
	draw_dashed_line(from, _anchor, _tail_color, 2.0, 6.0)
	if _speech_style == null:  # drawn in pencil, like the menus (log 0189)
		_speech_style = SketchBox.make(Color(Palette.PARCHMENT_LIGHT, 0.94), Palette.INK)
		_speech_style.shaded = false
	draw_style_box(_speech_style, _box)


## Bumps around the edge, then the body over their inner halves, so only
## the scalloped outline shows. Shrinking dots lead back to you.
func _draw_cloud() -> void:
	var start := Vector2(_box.position.x + 18, _box.end.y + 4)
	var dots := 4
	for i in dots:
		var t := float(i + 1) / float(dots + 1)
		var r := lerpf(6.0, 2.5, t)
		var p := start.lerp(_anchor, t)
		draw_circle(p, r, Color(Palette.PARCHMENT_LIGHT, 0.94))
		draw_arc(p, r, 0, TAU, 16, _tail_color, 1.5, true)

	var bumps := _bump_centers()
	var radius := 13.0
	for c in bumps:
		draw_arc(c, radius, 0, TAU, 20, Palette.INK, 2.0, true)
	var fill := Palette.PARCHMENT_LIGHT
	for c in bumps:
		draw_circle(c, radius - 1.0, fill)
	draw_rect(_box, fill)


func _bump_centers() -> PackedVector2Array:
	var out := PackedVector2Array()
	var step := 22.0
	var r := _box
	var nx := maxi(1, roundi(r.size.x / step))
	var ny := maxi(1, roundi(r.size.y / step))
	for i in nx + 1:
		var x := r.position.x + r.size.x * i / nx
		out.append(Vector2(x, r.position.y))
		out.append(Vector2(x, r.end.y))
	for j in range(1, ny):
		var y := r.position.y + r.size.y * j / ny
		out.append(Vector2(r.position.x, y))
		out.append(Vector2(r.end.x, y))
	return out

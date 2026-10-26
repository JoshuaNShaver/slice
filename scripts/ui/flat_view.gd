class_name FlatView
extends CanvasLayer
## A Flatlander's view of the world (design logs 0238-0240, 0249), an
## experiment: what your shape itself would see, a vertical bar of the
## solid things around it (ground ink, people white or their paint, the sea
## blue), lightening with distance until fog hides them. Up the bar is up
## the world. Chosen with \view (client
## only, never sent):
##
##   \view 2d          the side view alone (the default)
##   \view eyes        two eyes, looking west and east; the side view hidden
##   \view eye         one eye, turned by moving the mouse (which way from
##                     the screen's middle); facing west it sees the world
##                     upside down, as a Flatlander turning in the plane would
##   \view 2d eyes     either, drawn over the side view, for debugging
##   \view 2d eye
##   \view fov 90      how wide each eye sees, in degrees (120 at first)
##   \view range 500   how far, in px, before fog hides everything (450 at first)
##
## How: a second picture, centred on your shape, holds only what's solid
## near it and the sea, in flat colours (FlatMap, from the physics shapes;
## no lettering or scenery; your own shape left out). Each eye's shader
## (flat_eye.gdshader) walks rays out through it, one per row of a strip
## one pixel wide, which is then stretched into its bar. The HUD stays on top.

const SHADER := preload("res://scripts/ui/flat_eye.gdshader")
const COMMAND := "\\view"
const HELP := "2d | eyes | eye | 2d eyes | 2d eye | fov <degrees> | range <px>: see as a Flatlander, with two eyes or one (the mouse turns it), over the side view or alone"
const RANGE := 450.0  # world px an eye sees until \view range; fog hides all past it
const RANGE_MIN := 100.0
const RANGE_MAX := 1400.0  # the world picture is drawn this far around the eye
const RESOLUTION := 0.5  # px of the world picture per world px
const BAR_WIDTH := 40.0
const BAR_GAP := 120.0  # between the two eyes' bars, around your shape
const BAR_HEIGHT := 0.8  # of the screen's height
const FOV := 120.0  # degrees each eye sees, until \view fov
const FOV_MIN := 20.0
const FOV_MAX := 180.0

## The view, for this game rather than one shape (a new heir keeps it).
static var show_2d := true
static var eyes := 0  # 0 (side view only), 1 or 2
static var _range := 0.0  # \view range's; 0 until set
static var _fov := 0.0  # \view fov's; 0 until set (not FOV here: tools' -s runs can skip static initializers)

## Set by World each frame: whose eyes, and how far underground (0..1).
var player: PlayerShape
var under := 0.0

var _world_view: SubViewport
var _map: FlatMap
var _strips: Array[Dictionary] = []  # per eye: {"viewport", "rect" (shader), "bar" (on screen)}
var _backdrop: ColorRect
var _marks: Control
var _facing := 0.0  # the single eye's direction, radians
var _bars: Array[Rect2] = []  # this frame's bars on screen


## {} if `line` isn't \view; else {"do": "status"}, {"do": "view",
## "show_2d", "eyes"} or {"error"}.
static func parse(line: String) -> Dictionary:
	var words := line.strip_edges().to_lower().split(" ", false)
	if words.is_empty() or words[0] != COMMAND:
		return {}
	if words.size() == 1:
		return {"do": "status"}
	var usage := {"error": "Try %s 2d, eyes, eye, 2d eyes, 2d eye, fov 90 or range 500." % COMMAND}
	if words[1] in ["fov", "range"]:
		if words.size() != 3 or not words[2].is_valid_float():
			return usage
		var n := words[2].to_float()
		if words[1] == "fov":
			return {"do": "fov", "fov": clampf(n, FOV_MIN, FOV_MAX)}
		return {"do": "range", "range": clampf(n, RANGE_MIN, RANGE_MAX)}
	var want_2d := false
	var count := 0
	for w in words.slice(1):
		if w == "2d" and not want_2d:
			want_2d = true
		elif w in ["eye", "eyes"] and count == 0:
			count = 1 if w == "eye" else 2
		else:
			return usage
	return {"do": "view", "show_2d": want_2d or count == 0, "eyes": count}


## Sets the view from parse's answer; returns what to tell the player.
static func apply(asked: Dictionary) -> String:
	if asked.has("error"):
		return asked.error
	if asked.get("do") == "view":
		show_2d = asked.show_2d
		eyes = asked.eyes
	if asked.get("do") == "fov":
		_fov = asked.fov
	if asked.get("do") == "range":
		_range = asked.range
	return "View: %s." % describe()


static func describe() -> String:
	var seen: String = ["the side view", "one eye, turned by the mouse", "two eyes, west and east"][eyes]
	if eyes > 0:
		seen += " over the side view" if show_2d else ", the side view hidden"
		seen += ", each seeing %d° and %d px" % [roundi(fov()), roundi(view_range())]
	return seen


## How wide each eye sees, in degrees.
static func fov() -> float:
	return _fov if _fov > 0.0 else FOV


## How far each eye sees, in world px.
static func view_range() -> float:
	return _range if _range > 0.0 else RANGE


func _ready() -> void:
	layer = 1  # with the ink pass and dust, added after them; under the HUD
	var side := int(2.0 * RANGE_MAX * RESOLUTION) + 8
	_world_view = SubViewport.new()
	_world_view.transparent_bg = true
	_world_view.size = Vector2i(side, side)
	_world_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_world_view)
	_map = FlatMap.new()
	_world_view.add_child(_map)

	_backdrop = ColorRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	for i in 2:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(2, 2)
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(viewport)
		var rect := ColorRect.new()
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("world", _world_view.get_texture())
		mat.set_shader_parameter("uv_per_px", Vector2.ONE * RESOLUTION / float(side))
		rect.material = mat
		viewport.add_child(rect)
		var bar := TextureRect.new()
		bar.texture = viewport.get_texture()
		bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bar.stretch_mode = TextureRect.STRETCH_SCALE
		bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)
		_strips.append({"viewport": viewport, "rect": rect, "bar": bar})

	_marks = Control.new()
	_marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.draw.connect(_draw_marks)
	add_child(_marks)
	visible = false


func _process(_delta: float) -> void:
	var on := eyes > 0 and is_instance_valid(player)
	visible = on
	var update := SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	_world_view.render_target_update_mode = update
	for i in _strips.size():
		var strip: Dictionary = _strips[i]
		(strip.viewport as SubViewport).render_target_update_mode = update if i < eyes else SubViewport.UPDATE_DISABLED
		(strip.bar as Control).visible = i < eyes
	if not on:
		return
	_map.space = get_viewport().world_2d.space
	_map.eye = player.global_position
	_map.reach = view_range()
	_map.under = under
	_map.exclude = [player.get_rid()]  # the eye is inside it
	_map.queue_redraw()

	# The world picture, centred on the eye.
	var side := Vector2(_world_view.size)
	_world_view.canvas_transform = Transform2D(0.0, Vector2.ONE * RESOLUTION, 0.0,
			side / 2.0 - player.global_position * RESOLUTION)

	_backdrop.visible = not show_2d
	_backdrop.color = Palette.PARCHMENT.lerp(Palette.SLATE, under)

	var view := get_viewport().get_visible_rect().size
	var rows := maxi(int(view.y * BAR_HEIGHT), 2)
	var top := (view.y - rows) / 2.0
	var middle := view.x / 2.0
	_bars.clear()
	if eyes == 2:
		_bars.append(Rect2(middle - BAR_GAP / 2.0 - BAR_WIDTH, top, BAR_WIDTH, rows))  # west
		_bars.append(Rect2(middle + BAR_GAP / 2.0, top, BAR_WIDTH, rows))  # east
	else:
		_bars.append(Rect2(middle - BAR_WIDTH / 2.0, top, BAR_WIDTH, rows))

	for i in eyes:
		var strip: Dictionary = _strips[i]
		var viewport: SubViewport = strip.viewport
		if viewport.size.y != rows:
			viewport.size = Vector2i(2, rows)
			(strip.rect as ColorRect).size = Vector2(2, rows)
		var bar: TextureRect = strip.bar
		bar.position = _bars[i].position
		bar.size = _bars[i].size
		var mat: ShaderMaterial = (strip.rect as ColorRect).material
		var arc := _arc(i)
		mat.set_shader_parameter("top_angle", arc.x)
		mat.set_shader_parameter("sweep", arc.y)
		mat.set_shader_parameter("range_px", view_range())
		mat.set_shader_parameter("far_color", Palette.PARCHMENT.lerp(Palette.SLATE, under))
	_marks.queue_redraw()


## Eye `i`'s rays: (the top row's angle, the sweep to the bottom row).
## Facing east or west, the top row looks upward; the west eye sweeps the
## other way round, through west.
func _arc(i: int) -> Vector2:
	var width := deg_to_rad(fov())
	if eyes == 1:
		return Vector2(_facing - width / 2.0, width)
	if i == 0:
		return Vector2(PI + width / 2.0, -width)
	return Vector2(-width / 2.0, width)


## The single eye turns only when the mouse moves (its direction from the
## screen's middle), so a jump moves the world in the bar, not the eye.
func _input(event: InputEvent) -> void:
	if eyes != 1 or not visible or not event is InputEventMouseMotion:
		return
	var to_mouse := (event as InputEventMouseMotion).position - get_viewport().get_visible_rect().size / 2.0
	if to_mouse.length() > 4.0:
		_facing = to_mouse.angle()


func _eye_on_screen() -> Vector2:
	return get_viewport().get_canvas_transform() * player.global_position


## Frames, labels and the "straight ahead" ticks on the bars; over the side
## view, where the eyes look from your shape.
func _draw_marks() -> void:
	var ink := Palette.INK.lerp(Palette.CHALK_LINE, under)
	var faded := Color(ink, 0.35)
	var font := _marks.get_theme_default_font()
	for i in _bars.size():
		var bar := _bars[i]
		_marks.draw_rect(bar.grow(2.0), ink, false, 2.0)
		var mid := bar.position.y + bar.size.y / 2.0
		for y: float in [mid, bar.position.y + bar.size.y * 0.25, bar.position.y + bar.size.y * 0.75]:
			var tick := 8.0 if y == mid else 4.0
			_marks.draw_line(Vector2(bar.position.x - 2.0 - tick, y), Vector2(bar.position.x - 2.0, y), ink, 2.0)
			_marks.draw_line(Vector2(bar.end.x + 2.0, y), Vector2(bar.end.x + 2.0 + tick, y), ink, 2.0)
		var label := ("W" if i == 0 else "E") if eyes == 2 else "%d°" % wrapi(roundi(rad_to_deg(-_facing)), 0, 360)
		_marks.draw_string(font, Vector2(bar.position.x - 20.0, bar.position.y - 10.0), label,
				HORIZONTAL_ALIGNMENT_CENTER, bar.size.x + 40.0, 16, ink)
	if eyes == 1 and not _bars.is_empty():
		# A little dial under the bar: which way the eye looks.
		var dial := Vector2(_bars[0].get_center().x, _bars[0].end.y + 26.0)
		_marks.draw_arc(dial, 14.0, 0.0, TAU, 32, ink, 2.0)
		_marks.draw_line(dial, dial + Vector2.from_angle(_facing) * 14.0, ink, 2.0)
	if not show_2d:
		return
	var eye := _eye_on_screen()
	var reach := view_range() * get_viewport().get_canvas_transform().get_scale().x
	for i in eyes:
		var arc := _arc(i)
		_marks.draw_arc(eye, reach, arc.x, arc.x + arc.y, 64, faded, 1.0)
		for edge: float in [arc.x, arc.x + arc.y]:
			_marks.draw_line(eye, eye + Vector2.from_angle(edge) * reach, faded, 1.0)
		_marks.draw_line(eye, eye + Vector2.from_angle(arc.x + arc.y / 2.0) * reach, Color(ink, 0.6), 1.0)

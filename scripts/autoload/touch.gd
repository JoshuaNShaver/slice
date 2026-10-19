extends Node
## Touch screens (design log 0122). Autoloaded as Touch.
##
## `active` while the player plays by touch: true from the start on phones
## and tablets, and switched by whatever was used last (a touch turns it
## on, a key turns it off, except keys typed into a text field, which the
## phone's own keyboard sends). The HUD shows TouchControls while it's on.
## Also asks to turn a phone sideways while it's held upright.

signal changed

var active := false

var _rotate_notice: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	active = OS.has_feature("web_android") or OS.has_feature("web_ios") \
			or OS.has_feature("android") or OS.has_feature("ios")
	_build_rotate_notice()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and not active:
		_set_active(true)
	elif event is InputEventKey and event.pressed and active and not _typing():
		_set_active(false)


func _process(_delta: float) -> void:
	var size := DisplayServer.window_get_size()
	_rotate_notice.visible = active and size.y > size.x


func _set_active(on: bool) -> void:
	active = on
	changed.emit()


func _typing() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit


func _build_rotate_notice() -> void:
	_rotate_notice = CanvasLayer.new()
	_rotate_notice.layer = 128
	_rotate_notice.visible = false
	add_child(_rotate_notice)
	var cover := ColorRect.new()
	cover.color = Palette.PARCHMENT
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rotate_notice.add_child(cover)
	var label := Label.new()
	label.text = "Turn your phone sideways to play."
	label.add_theme_color_override("font_color", Palette.INK)
	label.add_theme_font_size_override("font_size", 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.add_child(label)

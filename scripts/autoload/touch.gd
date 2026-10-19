extends Node
## Touch screens (design log 0122). Autoloaded as Touch.
##
## `active` while the player plays by touch: true from the start on phones
## and tablets, and switched by whatever was used last (a touch turns it
## on, a key turns it off, except keys typed into a text field, which the
## phone's own keyboard sends). The HUD shows TouchControls while it's on.
## Phones can be held either way (log 0134); Graphics fits the view.

signal changed

var active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	active = OS.has_feature("web_android") or OS.has_feature("web_ios") \
			or OS.has_feature("android") or OS.has_feature("ios")


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and not active:
		_set_active(true)
	elif event is InputEventKey and event.pressed and active and not _typing():
		_set_active(false)


func _set_active(on: bool) -> void:
	active = on
	changed.emit()


func _typing() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit


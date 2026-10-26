extends Node
## Every control is a named input action with default keys, and any of them
## can be rebound (design log 0035). Custom bindings are saved per machine in
## `user://controls.cfg`; actions not listed there keep their defaults.
##
## Each action has up to SLOTS keys (a primary and a secondary).

signal changed

const SAVE_PATH := "user://controls.cfg"
const SLOTS := 2

## In display order. `debug` actions only exist in debug builds.
const ACTIONS: Array[Dictionary] = [
	{"action": "roll_left", "label": "Roll left", "keys": [KEY_LEFT, KEY_A]},
	{"action": "roll_right", "label": "Roll right", "keys": [KEY_RIGHT, KEY_D]},
	{"action": "jump", "label": "Jump", "keys": [KEY_SPACE]},
	# Ability key slots (design log 0243): whatever's equipped in each.
	{"action": "ability_up", "label": "Up ability", "keys": [KEY_UP, KEY_W]},
	{"action": "ability_down", "label": "Down ability", "keys": [KEY_DOWN, KEY_S]},
	{"action": "ability_side", "label": "Side ability", "keys": [KEY_SHIFT]},
	# Throwing tips (log 0242): left click throws too, always.
	{"action": "throw", "label": "Throw (or left click)", "keys": [KEY_Q]},
	{"action": "interact", "label": "Talk / marry", "keys": [KEY_E]},
	{"action": "pickup", "label": "Pick up", "keys": [KEY_G]},
	{"action": "drink", "label": "Drink potion", "keys": [KEY_F]},
	{"action": "home", "label": "Teleport home", "keys": [KEY_C]},
	{"action": "quick_1", "label": "Quick slot 1", "keys": [KEY_1]},
	{"action": "quick_2", "label": "Quick slot 2", "keys": [KEY_2]},
	{"action": "quick_3", "label": "Quick slot 3", "keys": [KEY_3]},
	{"action": "quick_4", "label": "Quick slot 4", "keys": [KEY_4]},
	{"action": "quick_5", "label": "Quick slot 5", "keys": [KEY_5]},
	{"action": "character_sheet", "label": "Character sheet", "keys": [KEY_TAB]},
	{"action": "chat", "label": "Chat", "keys": [KEY_ENTER]},
	{"action": "menu", "label": "Menu", "keys": [KEY_ESCAPE]},
]

## On a touch screen (Touch, design log 0122), hints name these on-screen
## buttons instead of keys. TouchControls labels its buttons with them.
const TOUCH_NAMES := {
	"roll_left": "Stick", "roll_right": "Stick", "jump": "Jump",
	"ability_up": "Up", "ability_down": "Down", "ability_side": "Side", "throw": "Throw",
	"interact": "Use", "pickup": "Take", "drink": "Drink", "home": "Home",
	"character_sheet": "Bag", "chat": "Chat", "menu": "Menu",
}

## Actions saved under older names: the ability slots were the moves'
## own keys before abilities were equipped (design log 0243).
const RENAMED := {"ability_up": "nose_dive", "ability_down": "spike_up", "ability_side": "rush"}

## True while the controls screen waits for a key, so gameplay ignores it.
var capturing := false
## True while a cutscene plays (CutscenePlayer), so gameplay ignores keys.
var watching := false


## True while keys go to a text field (chat), so gameplay ignores them.
func typing() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit


func _ready() -> void:
	_apply_defaults()
	_load()
	Touch.changed.connect(changed.emit)  # hints switch between keys and buttons


func actions() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for entry in ACTIONS:
		if not entry.get("debug", false) or OS.is_debug_build():
			list.append(entry)
	return list


## The keys bound to an action, SLOTS long; KEY_NONE marks an empty slot.
func keys(action: String) -> Array[Key]:
	var result: Array[Key] = []
	if InputMap.has_action(action):
		for event in InputMap.action_get_events(action):
			if event is InputEventKey and result.size() < SLOTS:
				result.append((event as InputEventKey).physical_keycode)
	while result.size() < SLOTS:
		result.append(KEY_NONE)
	return result


## "C", or "← / A" for an action with two keys. For hints in the HUD.
## While playing by touch, the on-screen button's name ("Use").
func describe(action: String) -> String:
	if Touch.active and TOUCH_NAMES.has(action):
		return TOUCH_NAMES[action]
	var names: Array[String] = []
	for key in keys(action):
		if key != KEY_NONE:
			names.append(key_name(key))
	return " / ".join(names) if not names.is_empty() else "unbound"


static func key_name(key: Key) -> String:
	match key:
		KEY_NONE:
			return "—"
		KEY_LEFT:
			return "←"
		KEY_RIGHT:
			return "→"
		KEY_UP:
			return "↑"
		KEY_DOWN:
			return "↓"
		KEY_ESCAPE:
			return "Esc"
	return OS.get_keycode_string(key)


## Puts `key` in one slot of `action` (KEY_NONE clears it). A key does one
## thing only, so it is taken off any other action first. Returns the label
## of the action it was taken from, or "".
func bind(action: String, slot: int, key: Key) -> String:
	var taken_from := ""
	if key != KEY_NONE:
		for entry in ACTIONS:
			var other: String = entry.action
			var other_keys := keys(other)
			var i := other_keys.find(key)
			if i != -1 and not (other == action and i == slot):
				other_keys[i] = KEY_NONE
				_set_keys(other, other_keys)
				if other != action:
					taken_from = entry.label
	var current := keys(action)
	current[slot] = key
	_set_keys(action, current)
	_save()
	changed.emit()
	return taken_from


func reset_to_defaults() -> void:
	_apply_defaults()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	changed.emit()


func _apply_defaults() -> void:
	for entry in ACTIONS:
		var defaults: Array[Key] = []
		for key: Key in entry.keys:
			defaults.append(key)
		_set_keys(entry.action, defaults)


func _set_keys(action: String, new_keys: Array[Key]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	for key in new_keys:
		if key == KEY_NONE:
			continue
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


func _save() -> void:
	var file := ConfigFile.new()
	for entry in ACTIONS:
		file.set_value("keys", entry.action, keys(entry.action))
	file.save(SAVE_PATH)


func _load() -> void:
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) != OK:
		return
	for entry in ACTIONS:
		var saved: Variant = file.get_value("keys", entry.action, null)
		if saved == null and RENAMED.has(entry.action):  # bound before the slots (log 0243)
			saved = file.get_value("keys", RENAMED[entry.action], null)
		if not saved is Array:
			continue
		var loaded: Array[Key] = []
		for key: Variant in saved:
			if key is int and loaded.size() < SLOTS:
				loaded.append(key as Key)
		_set_keys(entry.action, loaded)

class_name TouchControls
extends Control
## On-screen controls for touch screens (design log 0122), in the HUD while
## Touch.active. They press the same input actions as the keys, so the rest
## of the game can't tell them apart.
##
## - Left: a stick that appears under your thumb; left/right rolls, and
##   pushing partway rolls slower.
## - Right: a big Jump button, the abilities you have equipped in an arc
##   around it (Side, Up, Down; log 0243), Throw above it while you wear
##   throwing tips (log 0242), and Use / Take just outside the arc only while
##   there's something to use or take.
## - Right edge, a column rising from just above the arc: Drink (nearest the
##   thumb), Chat, Bag (character sheet), Menu.
## - Left, above the stick: Home.
##
## Each finger is tracked on its own, so you can roll and jump at once.
## While a panel or the chat is open only the right column stays, so Menu
## or Chat can close it.

const STICK_ZONE := Vector2(0.36, 0.3)  # the stick's area: left 36% (clear of the quick slots), below the top 30%
const STICK_RADIUS := 90.0
const STICK_DEAD := 0.15  # of the radius
const JUMP_RADIUS := 72.0
const JUMP_INSET := 140.0  # from the bottom right corner to Jump's center
const ARC_DISTANCE := 155.0  # Jump's center to an ability's
const ABILITY_RADIUS := 46.0
const CONTEXT_RADIUS := 42.0
const SIDE_RADIUS := 30.0
const SIDE_SPACING := 74.0
const SIDE_TOP := 92.0  # the column never rises above this (the quest tracker is over it)
const SIDE_ACTIONS: Array[String] = ["drink", "chat", "character_sheet", "menu"]  # bottom to top
## Buttons the HUD hears as events (its panels listen for them).
const EVENT_ACTIONS: Array[String] = ["drink", "chat", "character_sheet", "menu", "home"]
const FILL := Color(0.97, 0.94, 0.86, 0.5)
const FILL_PRESSED := Color(0.23, 0.16, 0.12, 0.35)
const LINE := Color(0.23, 0.16, 0.12, 0.7)

## False while a panel is open: then only the right column shows.
var playing := true

var _abilities: Array[String] = []  # equipped ability ids by slot: side, up, down
var _can_throw := false
var _can_use := false
var _can_take := false
var _held := {}  # touch index -> the action it holds down ("" for the stick)
var _stick_base := Vector2.ZERO
var _stick_knob := Vector2.ZERO  # offset from the base
var _stick_index := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Each frame, from the HUD.
func update(me: PlayerShape) -> void:
	_abilities.clear()
	for slot in [Abilities.SIDE, Abilities.UP, Abilities.DOWN]:
		if me.stats.ability_slots[slot] != "":
			_abilities.append(me.stats.ability_slots[slot])
	_can_throw = not Gear.shots_of(me.inventory.equipped[Gear.SLOTS.find("points")]).is_empty()
	_can_use = false
	for node in get_tree().get_nodes_in_group(Npc.GROUP):
		if node.prompt != "":
			_can_use = true
	_can_take = false
	for node in get_tree().get_nodes_in_group(Pickup.GROUP):
		var p := node as Pickup
		if p.owner_id == me.peer_id and p.position.distance_to(me.position) <= Pickup.REACH:
			_can_take = true
	if not visible or not playing:
		release_all()
	queue_redraw()


## Lets go of everything held (hidden, a panel opened, the HUD rebuilt).
func release_all() -> void:
	for index: int in _held.keys():
		_release(index)


func _exit_tree() -> void:
	release_all()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		var at := (make_input_local(touch) as InputEventScreenTouch).position
		if touch.pressed:
			_press(touch.index, at)
		elif _held.has(touch.index):
			_release(touch.index)
		return
	var drag := event as InputEventScreenDrag
	if drag != null and drag.index == _stick_index:
		_move_stick((make_input_local(drag) as InputEventScreenDrag).position)


func _press(index: int, at: Vector2) -> void:
	for button in _buttons():
		if at.distance_to(button.center) <= button.radius:
			_held[index] = button.action
			if button.action in EVENT_ACTIONS:
				_send(button.action, true)  # the HUD's panels listen for events
			else:
				Input.action_press(button.action)
			get_viewport().set_input_as_handled()
			queue_redraw()
			return
	if playing and _stick_index < 0 and at.x < size.x * STICK_ZONE.x and at.y > size.y * STICK_ZONE.y:
		_held[index] = ""
		_stick_index = index
		_stick_base = at.clamp(Vector2(STICK_RADIUS, STICK_RADIUS), size - Vector2(STICK_RADIUS, STICK_RADIUS))
		_move_stick(at)
		get_viewport().set_input_as_handled()


func _release(index: int) -> void:
	var action: String = _held[index]
	_held.erase(index)
	if index == _stick_index:
		_stick_index = -1
		_stick_knob = Vector2.ZERO
		Input.action_release("roll_left")
		Input.action_release("roll_right")
	elif action in EVENT_ACTIONS:
		_send(action, false)
	else:
		Input.action_release(action)
	queue_redraw()


func _move_stick(at: Vector2) -> void:
	_stick_knob = (at - _stick_base).limit_length(STICK_RADIUS)
	var x := _stick_knob.x / STICK_RADIUS
	var strength := clampf((absf(x) - STICK_DEAD) / (1.0 - STICK_DEAD), 0.0, 1.0)
	if strength == 0.0:
		Input.action_release("roll_left")
		Input.action_release("roll_right")
	else:
		Input.action_press("roll_right" if x > 0 else "roll_left", strength)
		Input.action_release("roll_left" if x > 0 else "roll_right")
	queue_redraw()


func _send(action: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


## What's on screen now: [{action, center, radius}].
func _buttons() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var jump := size - Vector2(JUMP_INSET, JUMP_INSET)
	# The column starts just above Jump and squeezes up on short screens.
	var bottom := jump.y - JUMP_RADIUS - SIDE_RADIUS - 18.0
	var spacing := minf(SIDE_SPACING, (bottom - SIDE_TOP) / (SIDE_ACTIONS.size() - 1))
	for i in SIDE_ACTIONS.size():
		list.append({"action": SIDE_ACTIONS[i], "radius": SIDE_RADIUS,
				"center": Vector2(size.x - Hud.MARGIN - SIDE_RADIUS, bottom - i * spacing)})
	if not playing:
		return list
	list.append({"action": "home", "radius": SIDE_RADIUS,
			"center": _stick_rest() - Vector2(0, STICK_RADIUS + SIDE_RADIUS + 40.0)})
	list.append({"action": "jump", "center": jump, "radius": JUMP_RADIUS})
	# Equipped abilities from left round to straight up: side, up, down.
	for i in _abilities.size():
		var angle := PI + i * (PI / 2.0) / maxf(1.0, _abilities.size() - 1)
		var info: Dictionary = Abilities.ALL[_abilities[i]]
		list.append({"action": info.action, "label": info.short, "radius": ABILITY_RADIUS,
				"center": jump + Vector2.from_angle(angle) * ARC_DISTANCE})
	if _can_throw:  # above the arc (log 0242)
		list.append({"action": "throw", "radius": ABILITY_RADIUS,
				"center": jump + Vector2(-20, -ARC_DISTANCE - 105)})
	# Use and Take just outside the arc, left of Rush and Nose dive.
	if _can_use:
		list.append({"action": "interact", "center": jump + Vector2(-210, -180), "radius": CONTEXT_RADIUS})
	if _can_take:
		list.append({"action": "pickup", "center": jump + Vector2(-235, -75), "radius": CONTEXT_RADIUS})
	return list


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var held_actions := _held.values()
	for button in _buttons():
		var pressed: bool = button.action in held_actions
		draw_circle(button.center, button.radius, FILL_PRESSED if pressed else FILL)
		draw_arc(button.center, button.radius, 0.0, TAU, 48, LINE, 2.0, true)
		var font_size := 22 if button.action == "jump" else 15
		var text: String = button.get("label", Controls.TOUCH_NAMES.get(button.action, button.action))
		draw_string(font, button.center + Vector2(-button.radius, font_size * 0.35), text,
				HORIZONTAL_ALIGNMENT_CENTER, button.radius * 2.0, font_size, Palette.INK)
	if not playing:
		return
	# The stick: faint where it waits, solid under your thumb.
	var base := _stick_base if _stick_index >= 0 else _stick_rest()
	var alpha := 1.0 if _stick_index >= 0 else 0.5
	draw_circle(base, STICK_RADIUS, Color(FILL, FILL.a * alpha))
	draw_arc(base, STICK_RADIUS, 0.0, TAU, 64, Color(LINE, LINE.a * alpha), 2.0, true)
	draw_circle(base + _stick_knob, STICK_RADIUS * 0.42, Color(LINE, 0.45 * alpha))


## Where the stick waits when no thumb is on it.
func _stick_rest() -> Vector2:
	return Vector2(STICK_RADIUS + 70.0, size.y - STICK_RADIUS - 70.0)

class_name Elevator
extends Node2D
## A guarded elevator between two floors (design logs 0054, 0066).
##
## Stand by either stop and press interact. The guards check your shape
## (Regions.admits) and either send you up or down or turn you away. The ride
## itself is PlayerMotion.start_ride: the server carries the shape between
## the stops with collisions off.
##
## A lift through the ground runs down an open shaft (data "shaft", log
## 0227): the terrains leave it out, and a solid hatch caps it at the upper
## stop, so nobody falls down it past the guards. Going down, the guards
## open it and you fall straight down the shaft (log 0237); going up, the
## platform carries you. The hatch swings open only while someone passes.
##
## Nothing here is scenery (log 0221): no cage, no shaft. A plate set flush
## in the ground marks each stop, and a plain platform carries the rider,
## solid under them all the way (the server moves its body).
##
## Every peer builds the same elevators from data (World).

const REACH := 130.0
const PLATFORM := Vector2(104, 12)
const LEAF := 5.0  # an open hatch leaf's thickness, clear of the platform
const GUARD_GAP := 30.0  # between the platform's edge and each guard
## A shape stands this far above the floor when the ride ends.
const STAND := PlayerShape.RADIUS + 6.0

var display_name := ""
## What each stop's sign says, lower stop first.
var stop_names: Array = []
var rule := "anyone"  # who may ride from the lower stop
var upper_rule := "anyone"  # ... and from the upper stop
## Floor points: index 0 is the lower stop, 1 the upper.
var stops: Array[Vector2] = []
var guard_name := "Guard"
var refusals: Array = []
## What the guards at the upper stop say, if different (design log 0066).
var upper_refusals: Array = []
## Set by the world each frame, for the local player.
var prompt := ""
var prompt_stop := 0

var shaft := Rect2()  # empty for a lift through open air
var _last_y := {}  # each shape's y at the last draw, to tell falling from riding
var _guards: Array[PackedVector2Array] = []
var _platform: AnimatableBody2D  # under a rider; parked out of the way between rides
var _platform_shape: CollisionShape2D


## data: {"name", "stop_names" ([lower, upper]), "rule", "upper_rule",
## "bottom", "top", "guard", "refusals", "upper_refusals", "shaft" (a
## Rect2, optional)}. The upper_ keys default to the plain ones.
static func create(data: Dictionary) -> Elevator:
	var e := Elevator.new()
	e.name = String(data.name).validate_node_name()
	e.display_name = data.name
	e.stop_names = data.get("stop_names", [data.name, data.name])
	e.rule = data.get("rule", "anyone")
	e.upper_rule = data.get("upper_rule", e.rule)
	e.stops = [data.bottom, data.top]
	e.guard_name = data.get("guard", "Guard")
	e.refusals = data.get("refusals", ["Not you."])
	e.upper_refusals = data.get("upper_refusals", e.refusals)
	e.shaft = data.get("shaft", Rect2())
	return e


func _ready() -> void:
	add_to_group(Npc.GROUP)
	# Two guards per stop, one either side of the cage: squares, the book's
	# respectable professional class.
	for stop in stops:
		for side in [-1, 1]:
			var pts := ShapeGeometry.points(4, "regular", 24.0)
			var offset := stop + Vector2(side * (PLATFORM.x / 2.0 + GUARD_GAP), -17.0)
			for i in pts.size():
				pts[i] += offset
			_guards.append(pts)
	# The guards are solid, as every NPC is (design log 0223).
	var body := StaticBody2D.new()
	body.name = "Guards"
	body.collision_layer = PlayerShape.LAYER_TERRAIN
	body.collision_mask = 0
	for pts in _guards:
		var shape := CollisionPolygon2D.new()
		shape.polygon = pts
		body.add_child(shape)
	# The hatch over the shaft: the riders and their platform pass through it
	# (their collisions are off), everyone else stands on it.
	if has_shaft():
		var hatch := CollisionShape2D.new()
		hatch.name = "Hatch"
		var lid := RectangleShape2D.new()
		lid.size = Vector2(shaft.size.x, PLATFORM.y)
		hatch.shape = lid
		hatch.position = stops[1] + Vector2(0, PLATFORM.y / 2.0)
		body.add_child(hatch)
	add_child(body)
	# The moving platform: solid under the rider, for anyone else too.
	_platform = AnimatableBody2D.new()
	_platform.name = "Platform"
	_platform.sync_to_physics = false
	_platform.collision_layer = PlayerShape.LAYER_TERRAIN
	_platform.collision_mask = 0
	_platform_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = PLATFORM
	_platform_shape.shape = rect
	_platform_shape.position = Vector2(0, PLATFORM.y / 2.0)
	_platform_shape.disabled = true
	_platform.add_child(_platform_shape)
	add_child(_platform)


## Server: keep the platform under whoever is riding.
func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	var rider := _rider()
	_platform_shape.disabled = rider == null
	if rider != null:
		_platform.position = rider.position + Vector2(0, STAND - 2.0)


## A shape riding this elevator now, or null.
func _rider() -> PlayerShape:
	for node in get_tree().get_nodes_in_group(PlayerShape.GROUP):
		var p := node as PlayerShape
		if p != null and p.motion.riding() and absf(p.position.x - stops[0].x) < 4.0:
			return p
	return null


func _process(_delta: float) -> void:
	queue_redraw()


func has_shaft() -> bool:
	return shaft.size.x > 0.0


## True while someone is passing the upper stop's hatch: someone just
## dropped through (below it), or a rider coming up (centred on the shaft
## and rising, the platform still in it). Not someone standing on it, whose
## shape sinks into the lid a little (log 0249). Uses the last draw's
## heights (_last_y), as clients don't know who's riding.
func _hatch_open() -> bool:
	var top := stops[1].y
	for node in get_tree().get_nodes_in_group(PlayerShape.GROUP):
		var p := node as PlayerShape
		if p == null or absf(p.position.x - stops[0].x) >= shaft.size.x / 2.0:
			continue
		var under := p.position.y + STAND
		if under >= top + 220.0:
			continue
		var rising := absf(p.position.x - stops[0].x) < 1.0 and p.position.y < float(_last_y.get(p, -INF))
		if p.position.y > top or (rising and under > top + 2.0):
			return true
	return false


func _nearest_stop(pos: Vector2) -> int:
	return 0 if pos.distance_to(stops[0]) <= pos.distance_to(stops[1]) else 1


# --- Interaction (World finds the nearest interactable) --------------------

func reach_distance(pos: Vector2) -> float:
	var d := pos.distance_to(stops[_nearest_stop(pos)] + Vector2(0, -STAND))
	return d if d <= REACH else INF


func _admits(stop: int, p: PlayerShape) -> bool:
	return Regions.admits(upper_rule if stop == 1 else rule, p.sides, p.kind)


func prompt_for(p: PlayerShape) -> String:
	prompt_stop = _nearest_stop(p.position)
	if not _admits(prompt_stop, p):
		return "%s: speak to the guards" % Controls.describe("interact")
	if prompt_stop == 1 and has_shaft():
		return "%s: drop down" % Controls.describe("interact")
	return "%s: ride %s" % [Controls.describe("interact"), "up" if prompt_stop == 0 else "down"]


## Server only.
func interact(p: PlayerShape) -> void:
	var from := _nearest_stop(p.position)
	if not _admits(from, p):
		p.screen.tell(guard_name, (upper_refusals if from == 1 else refusals).pick_random())
		return
	if from == 1 and has_shaft():
		# Through the hatch: just under it, centered, and let them fall.
		p.motion.teleport(stops[1] + Vector2(0, PLATFORM.y + STAND))
		return
	p.motion.start_ride(stops[from] + Vector2(0, -STAND), stops[1 - from] + Vector2(0, -STAND))


# --- Drawing ---------------------------------------------------------------

func _draw() -> void:
	# A plate flush in the ground at each stop. Over a shaft, the upper one
	# is a hatch of two leaves, hanging open while the platform passes.
	for i in stops.size():
		var stop := stops[i]
		var ink := Palette.ink_at(stop)
		var fill := Palette.SLATE_LIGHT if stop.y > Regions.UNDERWORLD_TOP else Palette.PARCHMENT_LIGHT
		if i == 1 and has_shaft():
			_draw_hatch(stop, fill, ink)
			continue
		var plate := Rect2(stop + Vector2(-PLATFORM.x / 2.0, 0), PLATFORM)
		draw_rect(plate, fill)
		draw_rect(plate, ink, false, 2.0)
	# The platform under each rider (clients see riders, not the server's body).
	# Down a shaft nobody rides, they fall: no platform under anyone going down.
	var top := stops[1]
	var bottom := stops[0]
	var last := _last_y
	_last_y = {}
	for node in get_tree().get_nodes_in_group(PlayerShape.GROUP):
		var p := node as PlayerShape
		if p == null:
			continue
		_last_y[p] = p.position.y
		if has_shaft() and p.position.y > float(last.get(p, INF)):
			continue
		# Standing still on the hatch isn't riding up through it (log 0249).
		if has_shaft() and p.position.y <= top.y and p.position.y >= float(last.get(p, -INF)):
			continue
		if absf(p.position.x - top.x) < 4.0 \
				and p.position.y > top.y + 4.0 - STAND and p.position.y < bottom.y - STAND - 4.0:
			var under := Rect2(p.position + Vector2(-PLATFORM.x / 2.0, STAND - 2.0), PLATFORM)
			draw_rect(under, Palette.PARCHMENT_LIGHT)
			draw_rect(under, Palette.ink_at(p.position), false, 2.5)

	for pts in _guards:
		draw_colored_polygon(pts, Palette.PLAIN)
		var line := pts.duplicate()
		line.append(pts[0])
		draw_polyline(line, Palette.INK, 2.5, true)

	var font := ThemeDB.fallback_font
	for i in stops.size():
		var ink := Palette.ink_at(stops[i])
		var at := stops[i] + Vector2(-200, -70)
		draw_string(font, at, stop_names[i], HORIZONTAL_ALIGNMENT_CENTER, 400, 16, ink)
		if prompt != "" and prompt_stop == i:
			draw_string(font, at + Vector2(0, -22), prompt, HORIZONTAL_ALIGNMENT_CENTER, 400, 16, ink)


func _draw_hatch(stop: Vector2, fill: Color, ink: Color) -> void:
	var half := shaft.size.x / 2.0
	if not _hatch_open():
		var lid := Rect2(stop + Vector2(-half, 0), Vector2(shaft.size.x, PLATFORM.y))
		draw_rect(lid, fill)
		draw_rect(lid, ink, false, 2.0)
		draw_line(stop, stop + Vector2(0, PLATFORM.y), ink, 1.5)
		return
	# Each leaf hangs from its hinge against the wall.
	for side in [-1.0, 1.0]:
		var hinge := stop + Vector2(side * half, 0)
		var leaf := Rect2(hinge + Vector2(-LEAF if side > 0 else 0.0, 0), Vector2(LEAF, half))
		draw_rect(leaf, fill)
		draw_rect(leaf, ink, false, 2.0)

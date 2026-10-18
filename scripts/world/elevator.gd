class_name Elevator
extends Node2D
## A guarded elevator between two floors (design logs 0054, 0066).
##
## Stand by either stop and press interact. The guards check your shape
## (Regions.admits) and either send you up or down or turn you away. The ride
## itself is PlayerShape.start_ride: the server carries the shape along the
## shaft with collisions off, so the shaft can cut through solid rock.
##
## Every peer builds the same elevators from data (World). The cage is drawn
## at each stop, and around any shape riding between them.

const REACH := 130.0
const CAR_SIZE := Vector2(96, 104)
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

var _guards: Array[PackedVector2Array] = []


## data: {"name", "stop_names" ([lower, upper]), "rule", "upper_rule",
## "bottom", "top", "guard", "refusals", "upper_refusals"}. The upper_ keys
## default to the plain ones.
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
	return e


func _ready() -> void:
	add_to_group(Npc.GROUP)
	# Two guards per stop, one either side of the cage: squares, the book's
	# respectable professional class.
	for stop in stops:
		for side in [-1, 1]:
			var pts := ShapeGeometry.points(4, "regular", 24.0)
			var offset := stop + Vector2(side * (CAR_SIZE.x / 2.0 + 30.0), -17.0)
			for i in pts.size():
				pts[i] += offset
			_guards.append(pts)


func _process(_delta: float) -> void:
	queue_redraw()


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
	return "%s: ride %s" % [Controls.describe("interact"), "up" if prompt_stop == 0 else "down"]


## Server only.
func interact(p: PlayerShape) -> void:
	var from := _nearest_stop(p.position)
	if not _admits(from, p):
		p.tell(guard_name, (upper_refusals if from == 1 else refusals).pick_random())
		return
	p.start_ride(stops[from] + Vector2(0, -STAND), stops[1 - from] + Vector2(0, -STAND))


# --- Drawing ---------------------------------------------------------------

func _draw() -> void:
	var top := stops[1]
	var bottom := stops[0]
	var shaft := Rect2(top.x - CAR_SIZE.x / 2.0 - 6, top.y - CAR_SIZE.y, CAR_SIZE.x + 12,
			bottom.y - top.y + CAR_SIZE.y)
	# The shaft: a pale column with two rails, drawn over any rock it crosses.
	var air := Palette.PARCHMENT.lerp(Palette.SLATE, 0.5)
	air.a = 0.9
	draw_rect(shaft, air)
	for x in [shaft.position.x, shaft.end.x]:
		draw_line(Vector2(x, shaft.position.y), Vector2(x, shaft.end.y), Palette.INK_FADED, 3.0)
	# Rungs, so the ride reads as movement.
	var y := shaft.position.y + 40.0
	while y < shaft.end.y:
		draw_line(Vector2(shaft.position.x, y), Vector2(shaft.end.x, y), Color(Palette.INK_FADED, 0.25), 1.5)
		y += 80.0

	for stop in stops:
		_draw_car(stop + Vector2(0, -CAR_SIZE.y / 2.0), Palette.ink_at(stop))
	for node in get_tree().get_nodes_in_group(PlayerShape.GROUP):
		var p := node as PlayerShape
		if p != null and absf(p.position.x - top.x) < 4.0 \
				and p.position.y > top.y + 4.0 - STAND and p.position.y < bottom.y - STAND - 4.0:
			_draw_car(p.position + Vector2(0, STAND - CAR_SIZE.y / 2.0), Palette.ink_at(p.position))

	for pts in _guards:
		draw_colored_polygon(pts, Palette.PLAIN)
		var line := pts.duplicate()
		line.append(pts[0])
		draw_polyline(line, Palette.INK, 2.5, true)

	var font := ThemeDB.fallback_font
	for i in stops.size():
		var ink := Palette.ink_at(stops[i])
		var at := stops[i] + Vector2(-200, -CAR_SIZE.y - 18)
		draw_string(font, at, stop_names[i], HORIZONTAL_ALIGNMENT_CENTER, 400, 16, ink)
		if prompt != "" and prompt_stop == i:
			draw_string(font, at + Vector2(0, -22), prompt, HORIZONTAL_ALIGNMENT_CENTER, 400, 16, ink)


## An open cage: frame, roof bar and floor, with bars down the sides.
func _draw_car(center: Vector2, ink: Color) -> void:
	var box := Rect2(center - CAR_SIZE / 2.0, CAR_SIZE)
	draw_rect(Rect2(box.position, Vector2(box.size.x, 8)), ink)
	draw_rect(Rect2(Vector2(box.position.x, box.end.y - 6), Vector2(box.size.x, 6)), ink)
	for x in [box.position.x, box.position.x + 8, box.end.x - 8, box.end.x]:
		draw_line(Vector2(x, box.position.y), Vector2(x, box.end.y), ink, 2.0)
	draw_line(Vector2(center.x, box.position.y - 30), Vector2(center.x, box.position.y), ink, 2.0)

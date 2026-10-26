class_name RangerExam
extends StaticBody2D
## Ranger school's entrance exam (design logs 0245, 0251): a platform course
## over water, one copy per player in its own slot far from everything
## (Regions.exam_rect), like missions. Every peer builds the same course and
## registers the same calm sea with Ocean while it exists.
##
## The course climbs east. Fall in the water and you're back at the start.
## Twice it forks: rolling on, you drop into a walled pocket, a dead end; the
## way on is the higher jump. The climb ends at a ledge that goes nowhere:
## the way on is a leap of faith off its end, down past what you can see, to
## where a Heroldt waits in a rowboat (log 0184: he got here first). Miss
## the boat and he hauls you aboard. Speak to it and he rows you both out
## under the east wall, through the pass: that passes the exam.
## Layout in the course's own coordinates, the start ledge's top at y = 0.

const GROUP := "exams"
## s its owner may be away (not yet arrived, gone home) before it goes.
const AWAY_LIMIT := 4.0
const WIDTH := 5900.0  # the course, to the east wall's inner face
const PASS_END := WIDTH + 600.0  # the passage beyond the wall, to its end cap
const CEILING := -1300.0
const WATER_Y := 260.0  # the water's surface, the length of the course
const SEABED := 500.0
const WALL := 200.0
## The east wall stops short of the water here, leaving the pass under it.
const PASS_TOP := 60.0
const LEDGE := 220.0  # most ledges' width
const THICK := 24.0
## Every ledge: [left x, top y] (LEDGE wide) or [left x, top y, width].
const LEDGES: Array = [
	[0.0, 0.0, 450.0],  # the start
	[530.0, -60.0], [830.0, -120.0], [1130.0, -60.0], [1430.0, -120.0],
	[1730.0, -180.0, 400.0],  # the first fork
	[2210.0, -110.0], [2510.0, -40.0],  # its pocket
	[2210.0, -270.0], [2510.0, -330.0], [2810.0, -390.0], [3110.0, -330.0], [3410.0, -420.0],
	[3710.0, -480.0, 400.0],  # the second fork
	[4190.0, -410.0], [4490.0, -340.0],  # its pocket
	[4190.0, -570.0], [4490.0, -630.0], [4790.0, -690.0],
	[5090.0, -750.0, 360.0],  # the top: it goes nowhere
]
## The pockets' far walls: [left x, top y], up from the seabed, 40 wide.
## Each rises flush with the next ledge on the true path, ~350 px over its
## pocket's floor: past a rolling jump (~250), so only a corner bounce gets
## out that way.
const WALLS: Array = [[2760.0, -390.0], [4740.0, -690.0]]
const START := Vector2(150.0, -40.0)  # where you stand at the start
## Past the top ledge's end (x), a fall into the water is the leap: you're
## hauled aboard the boat instead of sent back.
const LEAP_X := 5300.0
## The Heroldt's rowboat: waiting under the leap, rowing out to the landing
## beyond the pass.
const BOAT_AT := Vector2(5650.0, WATER_Y - 30.0)
const LANDING_X := WIDTH + 420.0
## Past this x you're through the pass: the exam's passed.
const PASSED_X := WIDTH + WALL + 60.0
const GREETING := "Most of them never jump. Took your time, though. Speak up when you're ready, and I'll row."

var slot := 0
var owner_peer := 0
var boat: Boat  # server: the Heroldt's rowboat
var _away := 0.0  # server: s its owner hasn't been on it
var _greeted := false  # server: the Heroldt has said his piece
var _passed := false  # server
var _sea := {}


static func create(data: Dictionary) -> RangerExam:
	var e := RangerExam.new()
	e.name = data.name
	e.slot = data.slot
	e.owner_peer = data.owner
	e.position = Regions.exam_origin(e.slot)
	return e


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = PlayerShape.LAYER_TERRAIN
	collision_mask = 0
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 1.0
	for poly in _solids():
		var shape := CollisionPolygon2D.new()
		shape.polygon = poly
		add_child(shape)
	_sea = {"x0": position.x, "x1": position.x + PASS_END, "level": position.y + WATER_Y,
			"ground": _seabed_y, "shores": [position.x, position.x + PASS_END], "rain": 0.0, "swell": 0.0}
	Ocean.add_sea(_sea)
	if multiplayer.is_server():
		_launch_boat.call_deferred()


func _exit_tree() -> void:
	Ocean.remove_sea(_sea)
	if is_instance_valid(boat):
		boat.queue_free()


## Server only. The Heroldt's rowboat (Boat `rowed`), on every peer.
func _launch_boat() -> void:
	var world := get_tree().get_first_node_in_group(World.GROUP)
	if world == null or not world.has_method("spawn_boat"):
		return
	boat = world.spawn_boat({"pos": position + BOAT_AT, "facing": 1, "rowed": true,
			"route": Vector2(position.x + BOAT_AT.x, position.x + LANDING_X),
			"boatman": RangerSchoolQuest.HEROLDT, "boatman_look": RangerSchoolQuest.HEROLDT_LOOK})


## Is `p` on the Heroldt's boat (over its deck, not far above)? By where
## they are, not by contact: a shape rolling about the deck still counts.
func aboard(p: PlayerShape) -> bool:
	if not is_instance_valid(boat):
		return false
	var d := p.position - boat.position
	return absf(d.x) < boat.radius and d.y < 0.0 and d.y > -120.0


func _seabed_y(_x: float) -> float:
	return position.y + SEABED


## World coordinates of the start, for the slot `at_slot`.
static func start_of(at_slot: int) -> Vector2:
	return Regions.exam_origin(at_slot) + START


## Server only. `p` went into the water (PlayerActions.drown asks first): in
## their own exam that's no drowning. Off the course they're sent back to
## the start; from the leap, hauled aboard the boat. False if they're not in
## their exam.
static func catch(p: PlayerShape) -> bool:
	var at := Regions.exam_slot_at(p.position)
	if at < 0:
		return false
	for node in p.get_tree().get_nodes_in_group(GROUP):
		var exam := node as RangerExam
		if exam.slot == at and exam.owner_peer == p.peer_id:
			exam._fell_in(p)
			return true
	return false


func _fell_in(p: PlayerShape) -> void:
	var x := p.position.x - position.x
	if x >= LEAP_X and is_instance_valid(boat) and not boat.sinking:
		p.motion.teleport(boat.position + Vector2(-40.0, -PlayerShape.RADIUS - 16.0))
		p.screen.tell(RangerSchoolQuest.HEROLDT, "Got you. Up you come.")
		return
	p.motion.teleport(start_of(slot))
	p.screen.tell("", "You fall into the water. Back to the start.")


## Every solid piece, in local coordinates: walls, ceiling, seabed, ledges.
static func _solids() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	out.append(_box(Rect2(-WALL, CEILING - WALL, PASS_END + 2.0 * WALL, WALL)))  # ceiling
	out.append(_box(Rect2(-WALL, CEILING, WALL, SEABED - CEILING + WALL)))  # west wall
	out.append(_box(Rect2(WIDTH, CEILING, WALL, PASS_TOP - CEILING)))  # east wall, over the pass
	out.append(_box(Rect2(PASS_END, CEILING, WALL, SEABED - CEILING + WALL)))  # the passage's end
	out.append(_box(Rect2(0, SEABED, PASS_END, WALL)))  # the seabed
	for ledge: Array in LEDGES:
		var w: float = ledge[2] if ledge.size() > 2 else LEDGE
		out.append(_box(Rect2(ledge[0], ledge[1], w, THICK)))
	for wall: Array in WALLS:
		out.append(_box(Rect2(wall[0], wall[1], 40.0, SEABED - float(wall[1]))))
	return out


static func _box(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


## Server: the Heroldt greets you once you're aboard; through the pass, the
## exam's passed. Once its owner's been gone a while (passed, gone home,
## left the game), it goes.
func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	var here := false
	for node in get_tree().get_nodes_in_group(PlayerShape.GROUP):
		var p := node as PlayerShape
		if p.peer_id != owner_peer or Regions.exam_slot_at(p.position) != slot:
			continue
		here = true
		var x := p.position.x - position.x
		if not _greeted and aboard(p):
			_greeted = true
			p.screen.tell(RangerSchoolQuest.HEROLDT, GREETING)
		if not _passed and x > PASSED_X:
			_passed = true
			p.quests.notify("reach", "exam_pass")
		if p.position.y - position.y > SEABED - 40.0:
			_fell_in(p)  # somehow under the water: never stuck down there
	_away = 0.0 if here else _away + delta
	if _away > AWAY_LIMIT:
		queue_free()


func _draw() -> void:
	for poly in _solids():
		draw_colored_polygon(poly, Palette.PARCHMENT_DARK)
		var line := poly.duplicate()
		line.append(poly[0])
		draw_polyline(line, Palette.INK, 2.0, true)
	var font := ThemeDB.fallback_font
	var ink := Color(Palette.INK, 0.8)
	draw_string(font, Vector2(-100, -120), "The entrance exam · find the way across", HORIZONTAL_ALIGNMENT_CENTER,
			700, 18, ink)
	draw_string(font, Vector2(5090.0, -860.0), "The far ledge?", HORIZONTAL_ALIGNMENT_CENTER, 360, 18, ink)
	draw_string(font, Vector2(WIDTH + WALL, PASS_TOP + 60.0), "The pass", HORIZONTAL_ALIGNMENT_CENTER,
			PASS_END - WIDTH - WALL, 18, ink)

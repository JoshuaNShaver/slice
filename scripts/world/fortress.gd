class_name Fortress
extends StaticBody2D
## The rangers' mission (design logs 0248, 0250): a fortress raid by sea,
## one copy per squad in a mission slot (Regions.mission_rect), like
## Mission. Every peer builds the same layout and registers the same stormy
## sea with Ocean while it exists.
##
## West to east, in its own coordinates (the dock's top at y = 0): the
## dock, where the Boatman launches rowboats (Boat `rowed`); the crossing,
## a storm all the way; a pier under the fortress, and crags stepping up
## to the sea wall's top; the wall-walk over the
## courtyard; the gatehouse, whose winch lets the drawbridge down; and the
## field outside, where the army's troop waits to charge in.
##
## The enemy's boat is moored at the landing's pier (log 0253), with two
## lookouts and three archers aboard; you land just behind it. The lookouts
## run for the back door, in the crags' foot: a door hung from the ceiling
## of a tunnel under the crags, raised to let them in (out of the way, no
## obstruction) and lowered again behind them (a wall). If one gets in, the
## alarm sounds (Missions).
##
## Missions fills it: the crew, the wall-walk's few skirmishers, and the
## Castellan in his courtyard; once the drawbridge is down, the troop.

signal gate_lowered(by: PlayerShape)

const GROUP := "fortresses"
const WEST := -200.0  # the west wall's inner face
const EAST := 7500.0  # the east wall's inner face
const TOP := -2200.0
const BOTTOM := 560.0
const WALL := 200.0
const SEA_LEVEL := 40.0
const SEABED := 450.0
const PLANK := 14.0
const THICK := 24.0  # a ledge's or the wall-walk's depth
## The storm (logs 0250, 0253), *proposed*: full rain, and the waves this much
## higher. A passenger who keeps still rides it out; one rolling about may not.
const STORM_SWELL := 2.6

## The ground, west to east (dock, the sea's bed, beach, courtyard, field).
const SURFACE: Array[Vector2] = [
	Vector2(WEST, 0), Vector2(600, 0), Vector2(900, SEABED), Vector2(3700, SEABED), Vector2(4000, 0),
	Vector2(EAST, 0),
]
const SHORES: Array[float] = [600.0, 4000.0]
## Piers (x from, x to), planks' top at y = 0: the dock's, and the landing's.
const PIERS: Array[Vector2] = [Vector2(600, 860), Vector2(3740, 4000)]
## The enemy's boat (log 0253), moored against the landing's pier.
const ENEMY_BOAT_X := 3570.0
const ENEMY_BOAT_RADIUS := 160.0
## Where its crew stand on its deck (x from its middle): two lookouts at
## the bow, by the pier, and three archers.
const LOOKOUTS: Array[float] = [70.0, 120.0]
const ARCHERS: Array[float] = [-110.0, -50.0, 10.0]
## The rowboats: where they're launched and moor (the dock), and where they
## hold to land you (the landing). Their hull's half-width is Boat.ROWED_RADIUS.
const DOCK_X := 1000.0
const LANDING_X := 3260.0  # just behind the enemy's boat
const BOATMAN_AT := Vector2(420, 0)

## The climb: crags stepping up east from the beach to the sea wall's top,
## each step's [left x, top y]. Each rises 120: more than a plain jump
## lifts you (~112 px), so it takes a bounce (jump again as you land).
## Checked with triangles and squares in test_missions.gd.
const WALL_TOP := -720.0
const CRAGS: Array[Vector2] = [
	Vector2(4050, -120), Vector2(4230, -240), Vector2(4410, -360), Vector2(4590, -480), Vector2(4770, -600),
	Vector2(4950, WALL_TOP),
]
## The sea wall, solid from the beach to its top; the wall-walk runs on
## from it over the courtyard to the gatehouse.
const SEA_WALL := Rect2(5000, WALL_TOP, 250, -WALL_TOP)
## The tunnel under the crags and the sea wall, from the back door into
## the courtyard, and its door, hung from the ceiling by its top edge.
const TUNNEL_TOP := -100.0
const BACK_DOOR := Rect2(CRAGS[0].x, TUNNEL_TOP, 18, -TUNNEL_TOP)
const LOOKOUT_TO := Vector2(4250, -30)  # in the tunnel: a lookout's made it
const DOOR_SENSE := 240.0  # a fleeing lookout this near raises the door
const DOOR_LINGER := 1.0  # s it stays up after the last one's through
const DOOR_SWING := 4.0  # rad/s it swings, drawn
const WALK := Rect2(5250, WALL_TOP, 1250, THICK)
const GATEHOUSE := Rect2(6500, WALL_TOP, 200, -320.0 - WALL_TOP)  # over the gate's passage
const WINCH_AT := Vector2(6620, WALL_TOP)
const WINCH_REACH := 110.0
## The drawbridge: up, it closes the passage; let down, it lies on the field.
const GATE := Rect2(6700, -320, 30, 320)
const BRIDGE_LENGTH := 320.0

## Where things start (local): the squad on the dock, the wall-walk's
## guards, the keep's door (the Castellan comes out of it), and the troop.
const SQUAD_AT := Vector2(160, 0)
## A few skirmishers hold the wall-walk (log 0253).
const WALK_GUARDS: Array[Vector2] = [Vector2(5500, WALL_TOP), Vector2(5950, WALL_TOP), Vector2(6350, WALL_TOP)]
const KEEP_DOOR := Vector2(5500, 0)
## The Castellan goes after anyone inside the fortress: from the sea wall east.
const INSIDE := Rect2(SEA_WALL.position.x, TOP, EAST - SEA_WALL.position.x, BOTTOM - TOP)
## The alarm (log 0253): archers come down the crags from the sea wall's
## top, and sentries and wardens stand round the winch.
const ALARM_ARCHERS_AT := Vector2(5150, WALL_TOP)
const WINCH_GUARDS: Array[Vector2] = [Vector2(6000, WALL_TOP), Vector2(6120, WALL_TOP), Vector2(6240, WALL_TOP),
		Vector2(6360, WALL_TOP), Vector2(6460, WALL_TOP), Vector2(6560, WALL_TOP), Vector2(6660, WALL_TOP)]
const TROOP_FROM := 7000.0
const TROOP_TO := 7400.0

var slot := 0
## Synced: the drawbridge is down (log 0250).
var gate_down := false:
	set(value):
		gate_down = value
		if _gate_shape != null:
			_gate_shape.set_deferred("disabled", value)
		queue_redraw()
## Set by the world each frame, for the local player (the winch's prompt).
var prompt := ""
## Synced: the back door is raised (log 0253).
var back_door_open := false:
	set(value):
		back_door_open = value
		if _door_shape != null:
			_door_shape.set_deferred("disabled", value)

var _gate_shape: CollisionPolygon2D
var _door_shape: CollisionPolygon2D
var _door_angle := 0.0  # drawn: 0 down, PI/2 raised
var _door_linger := 0.0  # server
var _sea := {}


static func create(data: Dictionary) -> Fortress:
	var f := Fortress.new()
	f.name = data.name
	f.slot = data.slot
	f.position = Mission.origin(f.slot)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var config := SceneReplicationConfig.new()
	for prop: String in [".:gate_down", ".:back_door_open"]:
		config.add_property(prop)
		config.property_set_spawn(prop, true)
		config.property_set_replication_mode(prop, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	sync.replication_config = config
	sync.add_visibility_filter(func(id: int) -> bool: return Net.players.has(id))
	f.add_child(sync)
	return f


## A world point `lift` px above local point `at`.
func point(at: Vector2, lift := 0.0) -> Vector2:
	return position + at - Vector2(0, lift)


## The ground's y (local) at local x.
static func floor_at(local_x: float) -> float:
	if local_x <= SURFACE[0].x:
		return SURFACE[0].y
	for i in range(1, SURFACE.size()):
		var a := SURFACE[i - 1]
		var b := SURFACE[i]
		if local_x <= b.x:
			return lerpf(a.y, b.y, inverse_lerp(a.x, b.x, local_x))
	return SURFACE[-1].y


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(Npc.GROUP)  # the winch: the use key lets the drawbridge down
	z_index = -1  # behind boats and shapes
	collision_layer = PlayerShape.LAYER_TERRAIN
	collision_mask = 0
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 1.0
	for poly in _solids():
		var shape := CollisionPolygon2D.new()
		shape.polygon = poly
		add_child(shape)
	_gate_shape = CollisionPolygon2D.new()
	_gate_shape.polygon = _box(GATE)
	_gate_shape.disabled = gate_down
	add_child(_gate_shape)
	_door_shape = CollisionPolygon2D.new()
	_door_shape.polygon = _box(BACK_DOOR)
	_door_shape.disabled = back_door_open
	add_child(_door_shape)
	var boatman := Npc.create({"name": Boat.BOATMAN, "at": point(BOATMAN_AT), "sides": 3, "kind": "isosceles",
			"apex": 40, "radius": 24.0, "role": "rowboats", "serves": "anyone",
			"launch": point(Vector2(DOCK_X, SEA_LEVEL - 30.0)), "facing": 1,
			"route": Vector2(position.x + DOCK_X, position.x + LANDING_X),
			"lines": [
				"Want one of your own? She's yours. Speak to her and I'll row.",
				"The fortress is east, through the worst of it. Mind the swell.",
			]})
	boatman.top_level = true  # it stands at world coordinates
	add_child(boatman)
	_sea = {"x0": position.x + WEST, "x1": position.x + EAST, "level": position.y + SEA_LEVEL,
			"ground": _ground_y, "shores": SHORES.map(func(x: float) -> float: return position.x + x),
			"rain": 1.0, "swell": STORM_SWELL,
			"piers": PIERS.map(func(pier: Vector2) -> Vector3:
				return Vector3(position.x + pier.x, position.x + pier.y, position.y + PLANK))}
	Ocean.add_sea(_sea)


func _exit_tree() -> void:
	Ocean.remove_sea(_sea)


## The ground's world y at world x, for Ocean.
func _ground_y(x: float) -> float:
	return position.y + floor_at(x - position.x)


## Every fixed solid (local): the ground, the end walls, the piers, the
## climb, the sea wall, the wall-walk and the gatehouse.
static func _solids() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var ground := PackedVector2Array(SURFACE)
	ground.append(Vector2(EAST, BOTTOM))
	ground.append(Vector2(WEST, BOTTOM))
	out.append(ground)
	out.append(_box(Rect2(WEST - WALL, TOP, WALL, BOTTOM - TOP)))
	out.append(_box(Rect2(EAST, TOP, WALL, BOTTOM - TOP)))
	for pier in PIERS:
		out.append(_box(Rect2(pier.x, 0, pier.y - pier.x, PLANK)))
	# The crags and the sea wall in one, over the tunnel to the courtyard.
	var crags := PackedVector2Array([Vector2(CRAGS[0].x, TUNNEL_TOP)])
	for i in CRAGS.size():
		crags.append(CRAGS[i])
		crags.append(Vector2(CRAGS[i + 1].x if i + 1 < CRAGS.size() else SEA_WALL.end.x, CRAGS[i].y))
	crags.append(Vector2(SEA_WALL.end.x, TUNNEL_TOP))
	out.append(crags)
	out.append(_box(WALK))
	out.append(_box(GATEHOUSE))
	return out


static func _box(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


# --- The winch (World finds the nearest interactable) ----------------------

func reach_distance(pos: Vector2) -> float:
	if gate_down:
		return INF
	var d := point(WINCH_AT, 20.0).distance_to(pos)
	return d if d <= WINCH_REACH else INF


func prompt_for(_p: PlayerShape) -> String:
	return "%s: let the drawbridge down" % Controls.describe("interact")


## Server only.
func interact(p: PlayerShape) -> void:
	lower_gate(p)


## Server only. Lets the drawbridge down, once.
func lower_gate(by: PlayerShape) -> void:
	if gate_down:
		return
	gate_down = true
	gate_lowered.emit(by)


# --- Drawing ---------------------------------------------------------------

## Server: the back door rises for a fleeing lookout and drops behind it.
func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	var door := point(BACK_DOOR.get_center())
	var near := false
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var e := node as Enemy
		if e.fleeing and e.hp > 0 and e.position.distance_to(door) < DOOR_SENSE:
			near = true
			break
	_door_linger = DOOR_LINGER if near else _door_linger - delta
	var want := _door_linger > 0.0
	if want != back_door_open:
		back_door_open = want


func _process(delta: float) -> void:
	_door_angle = move_toward(_door_angle, PI / 2.0 if back_door_open else 0.0, DOOR_SWING * delta)
	queue_redraw()  # the winch's prompt comes and goes; the door swings


func _draw() -> void:
	var stone := Palette.PARCHMENT_DARK
	var faint := Color(Palette.INK, 0.25)
	# The keep, behind the courtyard (not solid): a dark door the Castellan comes out of.
	var keep := Rect2(5300, -560, 520, 560)
	draw_rect(keep, Color(Palette.INK, 0.06))
	draw_rect(keep, faint, false, 1.5)
	draw_rect(Rect2(KEEP_DOOR.x - 50, -150, 100, 150), Color(Palette.INK, 0.35))
	# Arches under the wall-walk.
	var arch := WALK.size.x / 8.0 - 10.0
	for k in 4:
		var x0 := WALK.position.x + k * WALK.size.x / 4.0
		draw_arc(Vector2(x0 + WALK.size.x / 8.0, WALK.end.y + arch), arch, PI, TAU, 16, faint, 1.5, true)
	for poly in _solids():
		draw_colored_polygon(poly, stone)
		var line := poly.duplicate()
		line.append(poly[0])
		draw_polyline(line, Palette.INK, 2.0, true)
	# Merlons along the sea wall, the wall-walk and the gatehouse (drawn only).
	var x := SEA_WALL.position.x
	while x < GATEHOUSE.end.x - 20.0:
		draw_rect(Rect2(x, WALL_TOP - 30.0, 28, 30), stone)
		draw_rect(Rect2(x, WALL_TOP - 30.0, 28, 30), Palette.INK, false, 1.5)
		x += 60.0
	# The tunnel, dim; and its back door, hung from its top edge: down it's
	# a wall, raised it swings up outward against the crag face.
	draw_rect(Rect2(BACK_DOOR.position.x, TUNNEL_TOP, SEA_WALL.end.x - BACK_DOOR.position.x, -TUNNEL_TOP),
			Color(Palette.INK, 0.12))
	var hinge := BACK_DOOR.position
	var door := PackedVector2Array()
	for corner in _box(Rect2(Vector2.ZERO, BACK_DOOR.size)):
		door.append(hinge + corner.rotated(_door_angle))
	draw_colored_polygon(door, Palette.PARCHMENT_LIGHT)
	var door_line := door.duplicate()
	door_line.append(door[0])
	draw_polyline(door_line, Palette.INK, 2.0, true)
	# The drawbridge: up across the passage, or down on the field.
	var bridge := _box(GATE) if not gate_down else _box(Rect2(GATE.position.x, -10, BRIDGE_LENGTH, 10))
	draw_colored_polygon(bridge, Palette.PARCHMENT_LIGHT)
	var bridge_line := bridge.duplicate()
	bridge_line.append(bridge[0])
	draw_polyline(bridge_line, Palette.INK, 2.5, true)
	var top := GATEHOUSE.position + Vector2(GATEHOUSE.size.x, GATEHOUSE.size.y)
	var bridge_end := Vector2(GATE.end.x, GATE.position.y) if not gate_down else Vector2(GATE.position.x + BRIDGE_LENGTH, -10)
	draw_line(top + Vector2(-10, -20), bridge_end, Palette.INK, 1.5, true)  # its chain
	# The winch on the gatehouse.
	draw_circle(WINCH_AT + Vector2(0, -22), 18.0, Palette.PARCHMENT_LIGHT)
	draw_arc(WINCH_AT + Vector2(0, -22), 18.0, 0.0, TAU, 20, Palette.INK, 2.0, true)
	draw_line(WINCH_AT + Vector2(0, -22), WINCH_AT + Vector2(14, -48), Palette.INK, 3.0, true)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-100, -160), "The fortress raid · east across the water", HORIZONTAL_ALIGNMENT_CENTER,
			700, 18, Color(Palette.INK, 0.8))
	if prompt != "":
		draw_string(font, WINCH_AT + Vector2(-220, -80), prompt, HORIZONTAL_ALIGNMENT_CENTER, 440, 16, Palette.INK)

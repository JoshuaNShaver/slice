class_name Boat
extends RigidBody2D
## A sailing boat (design log 0201): a half-disc hull with one triangular
## sail, floating on the western sea's waves (Ocean). The server simulates
## it and clients draw it, like an Enemy.
##
## You stand on the deck behind the mast. Rolling into the sail (toward the
## bow, `facing`) leans the boat forward, and the lean drives it ahead; the
## longer you lean, the harder it tips. Let go and it slows and rights
## itself. Waves tip it too. Roll it past CAPSIZE and it goes under: anyone
## aboard falls in and drowns (PlayerActions.drown).
##
## The use key by the boat turns it about (mirrors it), which you need to
## come alongside a pier: the sail is otherwise between you and the land.
##
## A Boatwright launches one for you (World.launch_boat); you have one at a
## time, and it goes when you leave or launch another.

const LAYER := 16
const GROUP := "boats"
const RADIUS := 80.0  # the hull: a half-disc this wide either side
const MAST_HEIGHT := 150.0
const MAST_AT := 0.2  # the mast stands this share of RADIUS toward the bow
const HULL_POINTS := 16
const MASS := 5.0
## Buoyancy: upward force per px² of hull under water.
const BUOYANCY := 1.15
const COLUMNS := 12  # the hull is weighed in this many upright strips
## Water drag, per px/s, times the share of the hull under water.
const DRAG_ALONG := 9.0
const DRAG_UP := 90.0
const DRAG_TURN := 9000.0  # per rad/s
## Rolling into the sail (log 0201), *proposed* tuning: a lean torque that
## builds over LEAN_RAMP to LEAN, then keeps growing to LEAN * LEAN_MAX by
## LEAN_LONG; and drive along the deck, more the further forward it leans.
const LEAN := 110000.0
const LEAN_RAMP := 1.0
const LEAN_MAX := 3.0
const LEAN_LONG := 5.0
const LEAN_GRACE := 0.3  # s off the deck (a bounce) that still counts as leaning
const DRIVE := 2400.0
const DRIVE_TILT := 0.45  # rad of forward lean that gives full drive
const RIGHTING := 30000.0  # extra torque back toward the waves' slope
const TOP_SPEED := 320.0
const CAPSIZE := deg_to_rad(105.0)  # past this lean for CAPSIZE_TIME, it goes under
const CAPSIZE_TIME := 0.4
const SINK_TIME := 3.0  # s it takes to go under before it's gone
const TURN_SPEED := 90.0  # px/s: faster than this, it won't turn about
const REACH := 130.0

## -1: the bow (and the sail) to the west; 1: east.
var facing := -1:
	set(value):
		facing = value
		_shapes_dirty = true
var owner_peer := 0
var sinking := false
## Server -> clients each frame, as an Enemy's.
var net_state := PackedFloat32Array():
	set(value):
		net_state = value
		if _smoother != null:
			_smoother.push(value)
## Set by the world each frame, for the local player.
var prompt := ""

var _hull: CollisionPolygon2D
var _sail: CollisionPolygon2D
var _shapes_dirty := true
var _smoother: NetSmoother
var _lean_time := 0.0  # s someone has been rolling into the sail
var _lean_gap := 0.0  # s since someone last did (a bounce on the deck isn't letting go)
var _capsized := 0.0  # s past CAPSIZE
var _sink_left := 0.0


## data: {"name", "pos", "facing", "owner"}.
static func create(data: Dictionary) -> Boat:
	var b := Boat.new()
	b.name = data.name
	b.position = data.pos
	b.facing = data.get("facing", -1)
	b.owner_peer = data.get("owner", 0)
	b.mass = MASS
	b.center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	b.center_of_mass = Vector2(0, RADIUS * 0.6)  # ballast, low in the hull
	b.collision_layer = LAYER
	b.collision_mask = PlayerShape.LAYER_TERRAIN | PlayerShape.LAYER_PLAYERS | LAYER
	b.physics_material_override = PhysicsMaterial.new()
	b.physics_material_override.friction = 1.0
	b.physics_material_override.bounce = 0.05
	b.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	b.angular_damp = 0.0
	b.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	b.linear_damp = 0.0
	b.contact_monitor = true
	b.max_contacts_reported = 8
	b.can_sleep = false
	b._hull = CollisionPolygon2D.new()
	b.add_child(b._hull)
	b._sail = CollisionPolygon2D.new()
	b.add_child(b._sail)
	b._rebuild_shapes()

	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var config := SceneReplicationConfig.new()
	for prop: String in [".:position", ".:rotation"]:
		config.add_property(prop)
		config.property_set_spawn(prop, true)
		config.property_set_replication_mode(prop, SceneReplicationConfig.REPLICATION_MODE_NEVER)
	config.add_property(".:net_state")
	config.property_set_spawn(".:net_state", false)
	config.property_set_replication_mode(".:net_state", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	for prop: String in [".:facing", ".:sinking"]:
		config.add_property(prop)
		config.property_set_spawn(prop, true)
		config.property_set_replication_mode(prop, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	sync.replication_config = config
	sync.replication_interval = NetSmoother.SEND_INTERVAL
	sync.add_visibility_filter(func(id: int) -> bool: return Net.players.has(id))
	b.add_child(sync)
	return b


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(Npc.GROUP)  # the use key turns it about
	if not multiplayer.is_server():
		freeze = true
		freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		_smoother = NetSmoother.new()
		_smoother.body = self


## The hull, deck along y = 0 from -RADIUS to RADIUS, bowl below.
static func hull_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in HULL_POINTS + 1:
		var a := PI * i / HULL_POINTS
		pts.append(Vector2(cos(a), sin(a)) * RADIUS)
	return pts


## The sail: from the mast's foot and top down to the bow.
func sail_points() -> PackedVector2Array:
	var mast := facing * RADIUS * MAST_AT
	return PackedVector2Array([Vector2(mast, 0), Vector2(mast, -MAST_HEIGHT), Vector2(facing * RADIUS, 0)])


func _rebuild_shapes() -> void:
	_shapes_dirty = false
	_hull.polygon = hull_points()
	_sail.polygon = sail_points()


func _process(_delta: float) -> void:
	if multiplayer.is_server():
		net_state = NetSmoother.state_of(self)
	elif not _smoother.is_empty():
		var s := _smoother.current(_delta)
		position = Vector2(s.x, s.y)
		rotation = s.z
	if _shapes_dirty:
		_rebuild_shapes()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or not sinking:
		return
	_sink_left -= delta
	if _sink_left <= 0.0:
		queue_free()


# --- Simulation (server) -------------------------------------------------------

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not multiplayer.is_server():
		return
	var step := state.step
	if sinking:
		state.linear_velocity = state.linear_velocity.lerp(Vector2(0, 60), 1.0 - exp(-step * 2.0))
		state.angular_velocity *= exp(-step)
		return
	var t := Ocean.now()
	var xform := state.transform
	var origin := xform.origin
	var width := RADIUS * 2.0 / COLUMNS
	var under := 0.0  # px² of hull under water
	for i in COLUMNS:
		var x := -RADIUS + (i + 0.5) * width
		var top := xform * Vector2(x, 0)
		var bottom := xform * Vector2(x, sqrt(RADIUS * RADIUS - x * x))
		var length := top.distance_to(bottom)
		var surface := Ocean.surface_y((top.x + bottom.x) / 2.0, t)
		var wet := _wet_share(top.y, bottom.y, surface)
		if wet <= 0.0:
			continue
		# The middle of the wet part of the strip.
		var lo := top if top.y > bottom.y else bottom
		var hi := bottom if lo == top else top
		var at := lo.lerp(hi, wet / 2.0)
		var area := wet * length * width
		under += area
		var r := at - origin
		var v := state.linear_velocity + Vector2(-state.angular_velocity * r.y, state.angular_velocity * r.x)
		var share := area / (PI * RADIUS * RADIUS / 2.0)
		var drag := Vector2(-v.x * DRAG_ALONG, -v.y * DRAG_UP) * share
		state.apply_force(Vector2(0, -BUOYANCY * area) + drag, r)
	var wet_share := clampf(under / (PI * RADIUS * RADIUS / 2.0), 0.0, 1.0)
	state.apply_torque(-state.angular_velocity * DRAG_TURN * wet_share)

	# Back toward the lie of the waves, while it floats.
	if wet_share > 0.05:
		var lie := atan(Ocean.slope(origin.x, t))
		state.apply_torque(RIGHTING * sin(lie - xform.get_rotation()))

	_sail_step(state, xform, wet_share)
	_capsize_step(state, xform.get_rotation(), step)


## How much of an upright strip from y `a` to y `b` is below `surface`, 0-1.
static func _wet_share(a: float, b: float, surface: float) -> float:
	var lo := maxf(a, b)
	var hi := minf(a, b)
	if hi >= surface:
		return 1.0
	if lo <= surface:
		return 0.0
	return (lo - surface) / maxf(lo - hi, 0.001)


## Someone rolling into the sail leans it forward, and the lean drives it.
func _sail_step(state: PhysicsDirectBodyState2D, xform: Transform2D, wet_share: float) -> void:
	var leaning := false
	for p in riders():
		if signf(p.motion.move) == facing:
			leaning = true
			break
	if leaning:
		_lean_gap = 0.0
	else:
		_lean_gap += state.step
		if _lean_gap > LEAN_GRACE:
			_lean_time = 0.0
		return
	_lean_time += state.step
	var build := clampf(_lean_time / LEAN_RAMP, 0.0, 1.0)
	var longer := lerpf(1.0, LEAN_MAX, clampf((_lean_time - LEAN_RAMP) / (LEAN_LONG - LEAN_RAMP), 0.0, 1.0))
	state.apply_torque(facing * LEAN * build * longer)
	if wet_share < 0.05:
		return
	var forward_lean := facing * xform.get_rotation()  # > 0: bow down
	var drive := DRIVE * (0.6 + 0.4 * clampf(forward_lean / DRIVE_TILT, 0.0, 1.5))
	var along := xform.x.normalized() * facing
	if state.linear_velocity.dot(along) < TOP_SPEED:
		state.apply_central_force(along * drive)


func _capsize_step(state: PhysicsDirectBodyState2D, angle: float, step: float) -> void:
	if absf(wrapf(angle, -PI, PI)) > CAPSIZE:
		_capsized += step
		if _capsized >= CAPSIZE_TIME:
			sink()
	else:
		_capsized = 0.0


## Server only. Goes under: nothing can stand on it, and it's gone soon.
func sink() -> void:
	if sinking:
		return
	sinking = true
	_sink_left = SINK_TIME
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)


## Server only. Players standing on it.
func riders() -> Array[PlayerShape]:
	var out: Array[PlayerShape] = []
	for body in get_colliding_bodies():
		var p := body as PlayerShape
		if p != null and not p.dead:
			out.append(p)
	return out


# --- Interaction (World finds the nearest interactable) --------------------

func reach_distance(pos: Vector2) -> float:
	if sinking:
		return INF
	var d := position.distance_to(pos)
	return d if d <= REACH else INF


func prompt_for(_p: PlayerShape) -> String:
	return "%s: turn about" % Controls.describe("interact")


## Server only. Turns about: the sail swings to the other end, and anyone
## aboard is mirrored with it, so they don't end up inside it.
func interact(p: PlayerShape) -> void:
	if linear_velocity.length() > TURN_SPEED:
		p.screen.tell("", "Too fast to turn about. Let her slow first.")
		return
	var aboard := riders()
	facing = -facing
	for rider in aboard:
		var local := to_local(rider.position)
		rider.teleport(to_global(Vector2(-local.x, local.y - 4.0)))


# --- Drawing ---------------------------------------------------------------

func _draw() -> void:
	var fade := 1.0
	if sinking:
		fade = 0.6
	var ink := Color(Palette.INK, fade)
	var hull := hull_points()
	draw_colored_polygon(hull, Color(Palette.PARCHMENT_LIGHT, fade))
	# Planking: arcs inside the hull.
	for k in [0.45, 0.72]:
		draw_arc(Vector2.ZERO, RADIUS * k, 0.15, PI - 0.15, 16, Color(Palette.INK, 0.3 * fade), 1.5, true)
	var outline := hull.duplicate()
	outline.append(hull[0])
	draw_polyline(outline, ink, 3.0, true)
	var sail := sail_points()
	draw_colored_polygon(sail, Color(Palette.PARCHMENT_LIGHT, fade))
	Gear.draw_hatch(self, sail, [[90.0], 16.0], 1.0, Color(Palette.INK, 0.15 * fade))
	draw_polyline(PackedVector2Array([sail[2], sail[1]]), ink, 2.0, true)
	draw_line(sail[0], sail[1] + Vector2(0, -8), ink, 3.5, true)  # the mast
	if prompt != "":
		draw_set_transform(Vector2.ZERO, -rotation)
		draw_string(ThemeDB.fallback_font, Vector2(-200, -MAST_HEIGHT - 30), prompt,
				HORIZONTAL_ALIGNMENT_CENTER, 400, 16, Palette.INK)

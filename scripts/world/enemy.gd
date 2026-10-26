class_name Enemy
extends RigidBody2D
## A fighting shape that isn't a player: cave enemies (design log 0027), the
## drill yard's dummies and sparring partners (log 0072), and on missions the
## Colour Revolt and the army's own soldiers (logs 0068, 0070). The server
## simulates it and clients draw it, like PlayerShape. Its corners hurt the
## other side the way yours hurt it (Combat).
##
## Two sides: "hostile" (everything that fights players) and "army" (allied
## soldiers on missions). Hostiles chase the nearest player or soldier in
## their room; soldiers chase hostiles, or keep near their squad. Players
## pass through soldiers and can't hurt them.
##
## The world (or a mission) spawns them and gives out XP and loot when they die.

signal died(enemy: Enemy)
## A hit of its corner landed on `player` (Darren's bout counts these).
signal struck(enemy: Enemy, player: PlayerShape)
## A fleeing enemy (a fortress lookout, log 0253) got where it was running.
signal escaped(enemy: Enemy)

## tier: gear tier this enemy drops. level: about where it's comfortable.
## Optional: "team" ("hostile" or "army"), "kind" (outline: "irregular",
## "isosceles", "regular"), "apex" (isosceles), "drop" and "potion" (drop
## chances, before luck), "lethal" (false: can't bring a player below 1
## health), "wild" (a drill-yard wild shape: harmless, roams, rolls away
## when hit, log 0224), "paint" (the Revolt's colour), "gear" (a
## boss fights as if wearing a full set of this tier, log 0068), "boss",
## "moves" (uses rush, nose dive and spike up every few seconds, log 0089;
## or a list of the ones it uses: "spike", "dive", "rush"), "taunts" (its
## own lines for TAUNTS), "wear" (drawn wearing a full set of this tier),
## "named" (its name shows over it), "opening_hp" (its first hit on a
## player leaves them at this much health, if they had more; log 0181).
## "ranged" (it throws spinning tips, logs 0245, 0247): {"every": Vector2
## seconds between throws, "range" px it throws from, "keep" px it backs off
## to, "damage" a shot}; optionally "volley" and "charged" (Vector2 seconds
## between each: the Revolt's archers lob a fan of seeking arcs, and stand
## to charge one hard, straight shot, logs 0244, 0253) and "chase" (true:
## it closes in as it throws, like the Castellan). "bout_hits": a bout with
## it is lost after this many landed hits (default 2). "aggro": "room"
## (it notices anyone in its room, however far). "move_every": Vector2
## seconds between a Revolt fighter's moves (default BOSS_MOVE_EVERY).
## Spawn data may give "owner", a peer id: it then fights only that player,
## and only they can hurt it (a quest's bout, log 0181).
const TYPES := {
	"bandit": {
		"name": "Bandit", "sides": 4, "radius": 22.0, "hp": 140, "damage": 22,
		"xp": 10, "spin": 5.0, "hop": 160.0, "tier": 1, "level": "1-7",
		"drop": 0.15, "potion": 0.1,
	},
	"brute": {
		"name": "Brute", "sides": 5, "radius": 28.0, "hp": 480, "damage": 40,
		"xp": 40, "spin": 6.0, "hop": 180.0, "tier": 2, "level": "7-14",
		"drop": 0.15, "potion": 0.1,
	},
	"zealot": {
		"name": "Zealot", "sides": 6, "radius": 32.0, "hp": 1100, "damage": 65,
		"xp": 80, "spin": 7.0, "hop": 200.0, "tier": 3, "level": "14-20",
		"drop": 0.15, "potion": 0.1,
	},
	"pretender": {
		"name": "The Pretender", "sides": 12, "radius": 72.0, "hp": 6000, "damage": 110,
		"xp": 400, "spin": 3.5, "hop": 320.0, "tier": 4, "level": "20",
		"drop": 1.0, "potion": 1.0, "boss": true,
	},
	# The drill yard (design log 0072). *Proposed* numbers.
	# Wild shapes (log 0224), still "dummy" to the bootcamp quest: no post,
	# all one slanted rhombus with rounded corners (log 0234).
	"dummy": {
		"name": "Wild shape", "sides": 4, "radius": 25.0, "hp": 90, "damage": 0,
		"xp": 4, "spin": 2.0, "hop": 0.0, "tier": Gear.LEATHER, "level": "1-3",
		"drop": 0.05, "wild": true, "flee_spin": 7.0,
	},
	"sparring": {
		"name": "Recruit", "sides": 3, "kind": "isosceles", "apex": 40.0, "radius": 26.0,
		"hp": 170, "damage": 14, "xp": 10, "spin": 4.5, "hop": 150.0, "tier": Gear.LEATHER,
		"level": "1-5", "drop": 0.15, "lethal": false,
	},
	# Your senior at the drill yard (the bootcamp quest, design log 0181):
	# a recruit a year ahead, with spike up and a full set of leather.
	"darren": {
		"name": "Darren Heroldt", "sides": 3, "kind": "isosceles", "apex": 35.0, "radius": 27.0,
		"hp": 1000, "damage": 18, "xp": 30, "spin": 5.5, "hop": 175.0, "tier": 0, "level": "3-5",
		"lethal": false, "moves": ["spike"], "gear": Gear.LEATHER, "wear": Gear.LEATHER, "named": true,
		"opening_hp": 2,
		"taunts": {"spike": [
			"Spike up! Mind your landing!",
			"Here it comes, recruit. Get clear!",
			"Plant, point, and... up you go!",
		]},
	},
	# The Colour Revolt (design log 0068). *Proposed* numbers.
	"rebel": {
		"name": "Painted rebel", "sides": 3, "kind": "isosceles", "apex": 35.0, "radius": 26.0,
		"hp": 240, "damage": 26, "xp": 16, "spin": 5.0, "hop": 170.0, "tier": 0, "level": "5-10",
		"paint": true,
	},
	# Recon's secret finds (design logs 0088, 0089): the Revolt's gentry. In
	# the book, pentagons are gentlemen and hexagons the lowest nobility.
	"gentleman": {
		"name": "A Painted Gentleman", "sides": 5, "kind": "regular", "radius": 30.0, "hp": 650,
		"damage": 30, "xp": 45, "spin": 5.0, "hop": 180.0, "tier": 0, "level": "5-10", "paint": true,
	},
	"noble": {
		"name": "A Painted Noble", "sides": 6, "kind": "regular", "radius": 32.0, "hp": 900,
		"damage": 34, "xp": 60, "spin": 5.0, "hop": 190.0, "tier": 0, "level": "5-10", "paint": true,
	},
	"agitator": {
		"name": "Agitator", "sides": 4, "radius": 28.0, "hp": 620, "damage": 42, "xp": 38,
		"spin": 6.0, "hop": 190.0, "tier": 0, "level": "10-20", "paint": true,
	},
	# Painted skirmishers (log 0247): the Revolt's rangers. They keep their
	# distance and throw a dodgeable tip every 2-3 s. Missions scale them
	# by strength (Missions._revolt_for).
	"skirmisher": {
		"name": "Painted skirmisher", "sides": 3, "kind": "isosceles", "apex": 50.0, "radius": 25.0,
		"hp": 300, "damage": 18, "xp": 22, "spin": 4.5, "hop": 160.0, "tier": 0, "level": "5-20",
		"paint": true,
		"ranged": {"every": Vector2(2.0, 3.0), "range": 600.0, "keep": 300.0, "damage": 22.0},
	},
	"bodyguard": {
		"name": "Bodyguard", "sides": 5, "radius": 32.0, "hp": 1300, "damage": 60, "xp": 80,
		"spin": 6.5, "hop": 210.0, "tier": 0, "level": "20", "paint": true,
	},
	"captain": {
		"name": "A Captain of the Revolt", "sides": 6, "radius": 50.0, "hp": 2600, "damage": 50,
		"xp": 260, "spin": 4.5, "hop": 260.0, "tier": 0, "level": "10-20", "paint": true,
		"gear": 3, "boss": true, "moves": true,
	},
	"chromatistes": {
		"name": "Chromatistes, the Painter", "sides": 8, "radius": 62.0, "hp": 4200, "damage": 60,
		"xp": 420, "spin": 4.0, "hop": 300.0, "tier": 0, "level": "20", "paint": true,
		"gear": 4, "boss": true, "moves": true,
	},
	# The fortress raid's commander (logs 0248, 0250, 0253), *proposed*: in
	# his courtyard from the start, he goes after anyone in the fortress,
	# moves often, and throws as he comes.
	"castellan": {
		"name": "Carminus, the Castellan", "sides": 7, "radius": 58.0, "hp": 3800, "damage": 55,
		"xp": 380, "spin": 6.0, "hop": 320.0, "tier": 0, "level": "20", "paint": true,
		"gear": 4, "boss": true, "moves": true, "aggro": "room", "move_every": Vector2(1.4, 2.4),
		"ranged": {"every": Vector2(1.2, 2.0), "range": 800.0, "keep": 0.0, "damage": 40.0, "chase": true,
			"volley": Vector2(4.0, 6.0), "charged": Vector2(5.0, 7.0)},
		"taunts": {
			"spike": ["My walls, my rules, wedge. Up you go!", "Kneel in my courtyard!"],
			"dive": ["You climbed my wall for this?", "From the battlements, as is proper!"],
			"rush": ["Out of my fortress, splinter!", "Grey as the sea you crawled out of!"],
		},
	},
	# The fortress raid (log 0253), *proposed* numbers. Lookouts run for
	# the back door to raise the alarm; archers lob volleys and charge
	# shots; sentries rush and wardens nose dive, guarding the winch.
	"lookout": {
		"name": "Painted lookout", "sides": 3, "kind": "regular", "radius": 25.0,
		"hp": 380, "damage": 18, "xp": 30, "spin": 5.0, "hop": 170.0, "tier": 0, "level": "20",
		"paint": true, "flee_spin": 8.0,
	},
	"archer": {
		"name": "Painted archer", "sides": 3, "kind": "isosceles", "apex": 55.0, "radius": 26.0,
		"hp": 520, "damage": 20, "xp": 40, "spin": 4.5, "hop": 160.0, "tier": 0, "level": "20",
		"paint": true,
		"ranged": {"every": Vector2(1.8, 2.6), "range": 650.0, "keep": 320.0, "damage": 30.0,
			"volley": Vector2(5.0, 7.0), "charged": Vector2(6.0, 8.0)},
	},
	"sentry": {
		"name": "Painted sentry", "sides": 5, "kind": "regular", "radius": 32.0, "hp": 1100,
		"damage": 50, "xp": 70, "spin": 6.0, "hop": 200.0, "tier": 0, "level": "20", "paint": true,
		"moves": ["rush"],
	},
	"warden": {
		"name": "Painted warden", "sides": 6, "kind": "regular", "radius": 34.0, "hp": 1500,
		"damage": 55, "xp": 90, "spin": 5.5, "hop": 210.0, "tier": 0, "level": "20", "paint": true,
		"moves": ["dive"],
	},
	# The ranger camp (design log 0245). *Proposed* numbers. Ranger recruits
	# keep their distance and throw; like the drill yard's, they pull their
	# punches.
	"ranger_recruit": {
		"name": "Ranger recruit", "sides": 3, "kind": "isosceles", "apex": 50.0, "radius": 26.0,
		"hp": 600, "damage": 10, "xp": 30, "spin": 4.5, "hop": 150.0, "tier": Gear.SCOUT,
		"level": "18-20", "drop": 0.1, "lethal": false,
		"ranged": {"every": Vector2(1.8, 2.8), "range": 620.0, "keep": 320.0, "damage": 30.0},
	},
	# Your rival's line (log 0184) at ranger school: a Heroldt, of course
	# already through the exam. Throws fast; the bout takes four hits to lose.
	"edric": {
		"name": RangerSchoolQuest.HEROLDT, "sides": 3, "kind": "isosceles", "apex": 55.0, "radius": 27.0,
		"hp": 2400, "damage": 16, "xp": 120, "spin": 5.5, "hop": 180.0, "tier": 0, "level": "20",
		"lethal": false, "named": true, "gear": Gear.SCOUT, "wear": Gear.SCOUT, "bout_hits": 4,
		"ranged": {"every": Vector2(1.1, 1.9), "range": 700.0, "keep": 380.0, "damage": 45.0},
	},
	# The army's own soldiers (design log 0070): they fight beside you.
	"soldier": {
		"name": "Soldier", "sides": 3, "kind": "isosceles", "apex": 45.0, "radius": 26.0,
		"hp": 420, "damage": 30, "xp": 0, "spin": 5.0, "hop": 170.0, "tier": 0, "level": "",
		"team": "army",
	},
}

const AGGRO_RANGE := 520.0
const HOP_RANGE := 180.0  # hops when a target is this close
const HOP_EVERY := Vector2(1.2, 2.6)  # seconds between hops, random in this range
const SPIN_ACCEL := 6.0
const TIP_ASSIST := 0.75  # as PlayerMotion.TIP_ASSIST
const HOME_SLACK := 40.0  # px from home that counts as home
const WANDER := 160.0  # px a wild shape roams from home
const FLEE_TIME := 2.2  # s a wild shape rolls away after a hit
const GROUP := "enemies"
## Revolt bosses' moves (design log 0089), *proposed*: one every few
## seconds, and corner hits do MOVE_DAMAGE times as much during one.
const BOSS_MOVE_EVERY := Vector2(3.0, 5.0)
const MOVE_DAMAGE := 2.0
const BOSS_DIVE_JUMP := 1.6  # times its hop
const BOSS_RUSH_RANGE := 900.0
## Archers' volleys and charged shots (log 0253), *proposed*: a fan of
## VOLLEY_SHOTS arcs that turn slower than a player's (dodgeable), and a
## charge it stands still for, glowing, before one hard straight shot.
const VOLLEY_SHOTS := 5
const VOLLEY_SHARE := 0.6  # of a plain shot's damage, each
const VOLLEY_TURN := 3.0  # rad/s
const CHARGE_WINDUP := 1.0  # s
const CHARGE_MULT := 2.2
const FLEE_STUCK := 0.4  # s held up before a fleeing enemy hops
## A move is telegraphed (design log 0091): the fighter shouts an insult,
## then makes the move this many seconds later.
const MOVE_WINDUP := 0.8
const TAUNTS := {
	"spike": [
		"Come closer, wedge. Sit on my point!",
		"Mind your step, chip. It's a long way up.",
		"Kneel, Isosceles! On the spike, where you belong.",
	],
	"dive": [
		"Look up, you colourless sliver!",
		"From on high, as your betters always are!",
		"Duck, wedge-face! Oh. You can't. You're flat.",
	],
	"rush": [
		"Run, little grey wedge!",
		"Out of my way, you drab splinter!",
		"Two sides equal and not a brain between them!",
	],
}
## A huddle (recon's Captain, log 0089): guards hold a spot by the boss and
## only fight foes within GUARD_REACH of it; the boss within BOSS_LEASH of home.
const GUARD_REACH := 220.0
const BOSS_LEASH := 450.0

const LAYER := 4  # hostiles
const ARMY_LAYER := 8  # soldiers: players don't touch them
const FOLLOW_DISTANCE := 160.0  # soldiers with nothing to fight keep this near the squad
## Orbiting soldiers (recon, design log 0078): with nothing to fight they roll
## past you to a spot this far on your other side, wait there, and when you've
## moved ORBIT_TRIGGER from where they settled, roll past you the other way.
const ORBIT_REACH := 130.0
const ORBIT_TRIGGER := 70.0
const ORBIT_BRAKE := 10.0  # spin shed per second while waiting
## Soldiers left behind hurry: past FOLLOW_DISTANCE their top spin climbs
## toward CATCHUP_SPIN (faster than a player at full roll) and they push up
## to 3x harder, reaching the full rush CATCHUP_RANGE further out (log 0079).
const CATCHUP_SPIN := 14.0
const CATCHUP_RANGE := 350.0
## Soldiers on the move jump like a player pressing Space (log 0080): a
## jump that throws them forward with a spin, then steering in the air.
## Jumps come sooner and go further the more they're hurrying.
const TRAVEL_JUMP := 150.0  # as PlayerMotion.JUMP_SPEED
const TRAVEL_PUSH := 110.0  # forward speed a jump adds, x2 when hurrying
const TRAVEL_FLIP := 12.0  # spin a jump gives
const TRAVEL_EVERY := Vector2(0.5, 1.1)  # seconds between jumps, halved when hurrying
const AIR_SPEED := 120.0  # as PlayerMotion.AIR_SPEED; x2 when hurrying
const AIR_ACCEL := 150.0
## Soldiers wear bronze plating, so they read as the army's (design log 0069).
const SOLDIER_WEAR := ["", "plating_6", "", "", ""]

var type := "bandit"
## 0, or the one player it fights (a quest's bout, log 0181).
var owner_peer := 0
## Server -> clients each frame: x, y, rotation, vx, vy, spin, time, smoothed
## on clients (logs 0093, 0095).
var net_state := PackedFloat32Array():
	set(value):
		net_state = value
		if _smoother != null:
			_smoother.push(value)
var _smoother: NetSmoother  # clients only
var room := Rect2()  # the area it guards; it only chases players inside this
var home := Vector2.ZERO
var hp := 100
var max_hp := 100
var damage := 0.0  # per corner hit, after any gear buff
var rigidity := 0  # bosses' gear (design log 0068)
## Soldiers only, set by the mission: "follow" (keep near the squad),
## "orbit" (recon: swing back and forth past you, log 0078) or "seek"
## (invasion: hunt hostiles anywhere on the field, log 0079), or "charge"
## (the fortress raid's troop, log 0250: hunt them, hurrying as if left behind).
var role := "follow"
## Huddling (design log 0089): `guard` is the boss it keeps by, at
## `guard_offset` px; `leash` > 0 means it won't chase past that from its spot.
## If the boss falls, the huddle breaks and they chase.
var guard: Enemy = null
var guard_offset := 0.0
var leash := 0.0
## Server only: peer ids that hit it this life (they share XP and loot).
var contributors: Dictionary = {}

var _points: PackedVector2Array
var _corners: PackedVector2Array  # collision outline
var _color := Color.WHITE
var _hop_timer := 1.0
var _prev_linear := Vector2.ZERO
var _prev_angular := 0.0
var _cooldowns: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _orbit_side := 1.0  # which side of the player an orbiting soldier is heading for
var _orbit_anchor := NAN  # player x when it settled; NAN while it's on the move
var _launch: Variant = null  # Vector2 velocity to take on the next step (spike up)
var _stunned := 0.0  # s left tumbling helplessly after a launch
var _drop_on: Node2D = null  # the spike it's thrown onto
var _moves := MoveSet.new()  # bosses' moves (design log 0089)
var _move_timer := 2.0
var _windup := 0.0  # s until the taunted move goes off (log 0091)
var _pending_move := ""  # "spike", "dive" or "rush" while winding up
## Uses the Revolt's moves (log 0089): bosses, and invasion's gentry (log 0091).
var uses_moves := false
var _corner_angles := PackedFloat32Array()
var _ground_normal := Vector2.UP
var _flee := 0.0  # wild shapes: s left rolling away, along _flee_dir
var _flee_dir := 1.0
var _wander_dir := 0.0
var _wander_timer := 0.0
var hits_landed := 0  # server: corner hits that landed on a player this life
var _throw_timer := 1.5  # ranged enemies: s until the next throw
var _volley_timer := 3.0  # archers: s until the next volley
var _charge_timer := 4.0  # ... and charged shot
var _charge_left := 0.0  # s of the charge still to stand
var _charge_at: Node2D = null
## Synced: standing to charge a shot (drawn as a glow, log 0253).
var charging := false
## Fleeing (a fortress lookout, log 0253): with flee_to set, it runs there,
## fighting no one, once a player comes within flee_range; `escaped` fires
## when it arrives.
var flee_to := Vector2.INF
var flee_range := 0.0
var fleeing := false
var _escaped := false
var _flee_stuck := 0.0


static func create(data: Dictionary) -> Enemy:
	var e := Enemy.new()
	e.name = data.name
	e.type = data.type
	e.room = data.room
	e.owner_peer = data.get("owner", 0)
	e.home = data.pos
	e.position = data.pos
	e._color = Palette.REVOLT if TYPES[e.type].get("paint", false) else data.get("color", Palette.PLAIN)
	var info: Dictionary = TYPES[e.type]
	e.max_hp = info.hp
	e.damage = info.damage
	var moves: Variant = info.get("moves", false)
	e.uses_moves = bool(data.get("moves", false)) or (moves is Array and not (moves as Array).is_empty()) \
			or (moves is bool and moves)
	_apply_gear(e, info.get("gear", 0))
	# A weakened boss (recon's Captain, design log 0088): health, damage and armor scaled.
	var strength: float = data.get("strength", 1.0)
	if strength != 1.0:
		e.max_hp = roundi(e.max_hp * strength)
		e.damage *= strength
		e.rigidity = roundi(e.rigidity * strength)
	e.hp = e.max_hp
	var outline_kind: String = info.get("kind", "irregular")
	var apex: float = info.get("apex", 45.0)
	e._points = ShapeGeometry.points(info.sides, outline_kind, info.radius, apex)
	e._corners = ShapeGeometry.points(info.sides, outline_kind, info.radius + PlayerShape.COLLISION_PAD, apex)
	if info.get("wild", false):
		_rhombus(e, info.radius)
	e._corner_angles = ShapeGeometry.corner_angles(e._corners)

	var shape := CollisionPolygon2D.new()
	shape.polygon = e._corners
	e.add_child(shape)
	if e.is_army():
		e.collision_layer = ARMY_LAYER
		e.collision_mask = PlayerShape.LAYER_TERRAIN | LAYER
	else:
		e.collision_layer = LAYER
		# Boats too: the fortress raid's crew stand on theirs (log 0253).
		e.collision_mask = PlayerShape.LAYER_TERRAIN | PlayerShape.LAYER_PLAYERS | LAYER | ARMY_LAYER | Boat.LAYER
	e.mass = 1.0 + info.radius * info.radius / 784.0  # a player-sized enemy weighs 1
	e.physics_material_override = PhysicsMaterial.new()
	e.physics_material_override.friction = 0.9
	e.physics_material_override.bounce = 0.15
	e.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	e.angular_damp = 0.5
	e.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	e.contact_monitor = true
	e.max_contacts_reported = 8
	e.can_sleep = false

	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var config := SceneReplicationConfig.new()
	# Position and rotation arrive once at spawn, then as net_state.
	for prop: String in [".:position", ".:rotation"]:
		config.add_property(prop)
		config.property_set_spawn(prop, true)
		config.property_set_replication_mode(prop, SceneReplicationConfig.REPLICATION_MODE_NEVER)
	config.add_property(".:net_state")
	config.property_set_spawn(".:net_state", false)  # the first update is a live one
	config.property_set_replication_mode(".:net_state", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	for prop: String in [".:hp", ".:max_hp", ".:charging"]:
		config.add_property(prop)
		config.property_set_spawn(prop, true)
		config.property_set_replication_mode(prop, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	sync.replication_config = config
	sync.replication_interval = NetSmoother.SEND_INTERVAL
	sync.add_visibility_filter(func(id: int) -> bool: return Net.players.has(id))
	e.add_child(sync)
	return e


## A wild shape's outline (log 0234): a rhombus leaning east, its sides
## about two radii long. It collides as the sharp rhombus and is drawn
## with its corners rounded off.
const RHOMBUS_ANGLE := 65.0  # degrees, at its sharp corners
const RHOMBUS_ROUND := 0.22  # of a side, cut off each corner and rounded


static func _rhombus(e: Enemy, radius: float) -> void:
	e._corners = rhombus_points(2.0 * (radius + PlayerShape.COLLISION_PAD) * 0.95)
	var sharp := rhombus_points(2.0 * radius * 0.95)
	e._points = PackedVector2Array()
	var n := sharp.size()
	for i in n:
		var prev := sharp[(i + n - 1) % n]
		var corner := sharp[i]
		var next := sharp[(i + 1) % n]
		var a := corner.lerp(prev, RHOMBUS_ROUND / 2.0)
		var b := corner.lerp(next, RHOMBUS_ROUND / 2.0)
		for k in 6:
			var t := k / 5.0
			e._points.append(a.lerp(corner, t).lerp(corner.lerp(b, t), t))  # a quadratic curve


## A rhombus with `side` px sides, lying on a side and leaning east,
## centred on its middle.
static func rhombus_points(side: float) -> PackedVector2Array:
	var lean := Vector2.from_angle(deg_to_rad(-RHOMBUS_ANGLE)) * side
	var pts := PackedVector2Array([Vector2.ZERO, Vector2(side, 0), Vector2(side, 0) + lean, lean])
	var middle := (pts[0] + pts[2]) / 2.0
	for i in pts.size():
		pts[i] -= middle
	return pts


## A boss fights as if wearing a full set of `tier` (design log 0068): its
## vigor adds health, its force adds damage, its plating blunts your hits.
static func _apply_gear(e: Enemy, tier: int) -> void:
	if tier <= 0:
		return
	var worn := PackedStringArray()
	for slot in Gear.SLOTS:
		var military := Gear.is_military_tier(tier)
		worn.append(Gear.item(slot, tier) if not military or slot in Gear.slots_for(tier) else "")
	var gains := Gear.total_bonus(worn)
	e.max_hp += gains.get("vigor", 0) * Stats.HP_PER_VIGOR
	e.damage *= 1.0 + Stats.DAMAGE_PER_FORCE * gains.get("force", 0)
	e.rigidity = gains.get("rigidity", 0)


func _ready() -> void:
	add_to_group(GROUP)
	_rng.randomize()
	if not multiplayer.is_server():
		freeze = true
		freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		_smoother = NetSmoother.new()
		_smoother.body = self


func info() -> Dictionary:
	return TYPES[type]


func is_boss() -> bool:
	return info().get("boss", false)


func is_army() -> bool:
	return info().get("team", "hostile") == "army"


## Players' corners hurt hostiles only; one fighting a bout, only its owner.
func players_can_hit(peer := 0) -> bool:
	return not is_army() and (owner_peer == 0 or peer == owner_peer)


## Server only. `from_peer` is the player who hit it, or 0 for a soldier.
func take_hit(raw: float, from_peer: int, crit := false) -> void:
	if hp <= 0:
		return
	if from_peer != 0:
		contributors[from_peer] = true
		if info().get("wild", false):
			_startle(from_peer)
	var dealt := roundi(Stats.damage_taken(raw, rigidity))
	hp = maxi(hp - dealt, 0)
	get_tree().call_group(World.GROUP, "show_damage", position + Vector2(0, -24), dealt,
			"crit" if crit else ("player" if is_army() else "enemy"))
	if hp == 0:
		died.emit(self)


## Server only. Thrown into the air by a player's spike up (design log
## 0086): it takes this velocity and can't move or hurt anyone until it
## lands, drifting to come down right over `onto`.
func launch(velocity: Vector2, onto: Node2D) -> void:
	if is_boss():
		return  # too heavy to throw
	_moves.cancel()
	_pending_move = ""
	_launch = velocity
	_stunned = 1.5
	_drop_on = onto


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not multiplayer.is_server() or hp <= 0 or freeze:
		return
	var step := state.step
	var stats := info()
	if _launch != null:
		state.linear_velocity = _launch
		_launch = null
		_prev_linear = state.linear_velocity
		return
	if _stunned > 0.0:
		_stunned -= step
		var landed := state.linear_velocity.y >= 0.0 and state.get_contact_count() > 0
		if landed and _stunned < 1.2:
			_stunned = 0.0
		elif state.get_contact_count() == 0 and is_instance_valid(_drop_on):
			var gap := _drop_on.global_position.x - position.x
			state.linear_velocity.x = clampf(gap * 4.0, -400.0, 400.0)
		_prev_linear = state.linear_velocity
		_prev_angular = state.angular_velocity
		return

	var grounded := false
	for i in state.get_contact_count():
		if state.get_contact_local_normal(i).y < -0.5:
			grounded = true
			_ground_normal = state.get_contact_local_normal(i)
			break

	# Into the sea (the fortress raid's crew, log 0253): gone.
	if Ocean.drowns(state.transform.origin, Ocean.now()):
		hp = 0
		died.emit(self)
		return
	if flee_to != Vector2.INF:
		_run_off(state, grounded)
		_prev_linear = state.linear_velocity
		_prev_angular = state.angular_velocity
		return

	if stats.get("wild", false):
		_roam(state, grounded)
		_prev_linear = state.linear_velocity
		_prev_angular = state.angular_velocity
		return

	if guard != null and (not is_instance_valid(guard) or guard.hp <= 0):
		guard = null  # the boss is down: the huddle breaks
		leash = 0.0
	var anchor := _anchor()
	var target := _nearest_target()
	var throw_at: Node2D = null  # a leashed thrower still throws from its spot (log 0247)
	if leash > 0.0 and target != null and target.position.distance_to(anchor) > leash:
		if stats.has("ranged"):
			throw_at = target
		target = null  # won't leave the huddle to chase
	var dir := 0.0
	var brake := false
	var top: float = stats.spin
	var accel := SPIN_ACCEL
	var hurry := 0.0
	if target != null:
		# Engaged: just fight.
		dir = signf(target.position.x - position.x)
		_orbit_anchor = NAN
		if role == "charge":
			hurry = clampf((position.distance_to(target.position) - HOP_RANGE) / CATCHUP_RANGE, 0.0, 1.0)
			top = lerpf(stats.spin, CATCHUP_SPIN, hurry)
			accel *= 1.0 + 2.0 * hurry
		if stats.has("ranged"):
			dir = _ranged(step, target, stats.ranged)
	elif is_army():
		var squad := _nearest_player()
		if squad != null:
			var gap := absf(squad.position.x - position.x)
			hurry = clampf((gap - FOLLOW_DISTANCE) / CATCHUP_RANGE, 0.0, 1.0)
			top = lerpf(stats.spin, CATCHUP_SPIN, hurry)
			accel *= 1.0 + 2.0 * hurry
			if role == "orbit":
				dir = _orbit_dir(squad.position.x)
				brake = dir == 0.0
			elif gap > FOLLOW_DISTANCE:
				dir = signf(squad.position.x - position.x)
	elif absf(anchor.x - position.x) > HOME_SLACK:
		dir = signf(anchor.x - position.x)
	if throw_at != null:
		_ranged(step, throw_at, stats.ranged)  # throws, but keeps its spot

	if grounded and dir != 0.0 and state.angular_velocity * dir < top:
		var tip: float = TIP_ASSIST * state.total_gravity.length() * stats.radius * state.inverse_inertia / state.inverse_mass
		state.angular_velocity += dir * (accel + tip) * step
	elif grounded and brake:
		state.angular_velocity = move_toward(state.angular_velocity, 0.0, ORBIT_BRAKE * step)
	elif not grounded and dir != 0.0 and is_army():
		var vx := state.linear_velocity.x
		var air_top := AIR_SPEED * (1.0 + hurry)
		if absf(vx) < air_top or signf(vx) != signf(dir):
			state.linear_velocity.x = move_toward(vx, dir * air_top, AIR_ACCEL * (1.0 + hurry) * step)

	_hop_timer -= step
	var close := target != null and position.distance_to(target.position) < HOP_RANGE
	if _moves.active():
		pass  # mid-move: no hops
	elif grounded and close and _hop_timer <= 0.0:
		state.linear_velocity += Vector2(dir * stats.hop * 0.4, -stats.hop)
		_hop_timer = _rng.randf_range(HOP_EVERY.x, HOP_EVERY.y)
	elif grounded and is_army() and dir != 0.0 and not close and _hop_timer <= 0.0:
		_travel_jump(state, dir, hurry)

	if uses_moves:
		_boss_move(state, target, grounded)
	_moves.step(state, _corners, _corner_angles, grounded)

	if damage > 0.0:
		var dealt := damage * (MOVE_DAMAGE if _moves.active() else 1.0)
		for hit in Combat.find_hits(state, _corners, _prev_linear, _prev_angular, _is_foe, _cooldowns):
			if hit.target is PlayerShape:
				var p: PlayerShape = hit.target
				var leave_at: int = info().get("opening_hp", -1) if hits_landed == 0 else -1
				if p.combat.take_hit(dealt, hit.push, info().get("lethal", true), leave_at):
					hits_landed += 1
					struck.emit(self, p)
			else:
				var foe: Enemy = hit.target
				foe.apply_central_impulse(hit.push * Combat.KNOCKBACK * foe.mass)
				foe.take_hit(dealt, 0)
	_prev_linear = state.linear_velocity
	_prev_angular = state.angular_velocity


## A thrower (logs 0245, 0247): backs off when you're close, holds in
## range, closes in from further, and throws a spinning tip at you every
## few seconds when it can see you. Archers (log 0253) also lob volleys and
## stand to charge a hard shot; a chaser keeps coming as it throws.
## Returns which way to roll.
func _ranged(step: float, target: Node2D, ranged: Dictionary) -> float:
	var gap := target.position - position
	var dist := gap.length()
	_throw_timer -= step
	_volley_timer -= step
	_charge_timer -= step
	var projectiles := Projectiles.find(get_tree())
	if _charge_left > 0.0:
		_charge_left -= step
		if _charge_left <= 0.0:
			charging = false
			if projectiles != null and is_instance_valid(_charge_at):
				_charged_shot(projectiles, _charge_at, ranged)
		return 0.0  # it stands to charge
	if dist <= float(ranged.range) and projectiles != null and _can_see(target):
		if ranged.has("charged") and _charge_timer <= 0.0:
			_charge_timer = _between(ranged.charged)
			_charge_left = CHARGE_WINDUP
			_charge_at = target
			charging = true
			return 0.0
		if ranged.has("volley") and _volley_timer <= 0.0:
			_volley_timer = _between(ranged.volley)
			_volley(projectiles, target, ranged)
		elif _throw_timer <= 0.0:
			_throw_timer = _between(ranged.every)
			projectiles.throw(_shot(gap.normalized(), float(ranged.damage), Projectiles.SPEED * 0.8))
	var dir := signf(gap.x)
	if ranged.get("chase", false):
		pass
	elif dist < float(ranged.keep) * 0.75:
		dir = -signf(gap.x)
	elif dist < float(ranged.range) * 0.85:
		dir = 0.0
	# A leashed thrower (a boat's crew, a huddle) won't back off past its leash.
	if leash > 0.0 and dir != 0.0 and (position.x - _anchor().x) * dir > leash * 0.6:
		dir = 0.0
	return dir


func _can_see(target: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(position, target.position, PlayerShape.LAYER_TERRAIN)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _between(range_s: Vector2) -> float:
	return _rng.randf_range(range_s.x, range_s.y)


## One of its shots, `damage` scaled as its corners are (strength, gear).
func _shot(dir: Vector2, raw_damage: float, speed: float) -> Dictionary:
	var scale := damage / maxf(float(info().damage), 1.0)
	return {"from": position, "dir": dir, "side": "hostile", "damage": raw_damage * scale,
			"lethal": info().get("lethal", true), "source": self, "only": owner_peer, "speed": speed}


## A fan of VOLLEY_SHOTS arcs toward `target`, fast enough to land near it,
## seeking it on the way down (as VolleyAbility, but slower to turn).
func _volley(projectiles: Projectiles, target: Node2D, ranged: Dictionary) -> void:
	var gap := target.position - position
	var facing := signf(gap.x) if gap.x != 0.0 else 1.0
	var reach := maxf(absf(gap.x), 120.0)
	var launch := deg_to_rad(VolleyAbility.LAUNCH)
	var speed := clampf(sqrt(reach * VolleyAbility.GRAVITY / sin(2.0 * launch)), VolleyAbility.MIN_SPEED,
			VolleyAbility.MAX_SPEED)
	for i in VOLLEY_SHOTS:
		var t := float(i) / (VOLLEY_SHOTS - 1) - 0.5
		var up := launch + deg_to_rad(VolleyAbility.FAN) * t
		var shot := _shot(Vector2(cos(up) * facing, -sin(up)), float(ranged.damage) * VOLLEY_SHARE, speed)
		shot.gravity = VolleyAbility.GRAVITY
		shot.target = target
		shot.seek_after = VolleyAbility.SEEK_AFTER
		shot.turn = VOLLEY_TURN
		shot.life = VolleyAbility.LIFE
		projectiles.throw(shot)


## The charge's shot: straight at where `target` is now, fast and hard.
func _charged_shot(projectiles: Projectiles, target: Node2D, ranged: Dictionary) -> void:
	var shot := _shot((target.position - position).normalized(), float(ranged.damage) * CHARGE_MULT,
			ChargedShotAbility.SPEED)
	shot.life = ChargedShotAbility.LIFE
	shot.size = ChargedShotAbility.SIZE
	projectiles.throw(shot)


## A lookout (log 0253): still until a player comes within flee_range,
## then it rolls hard for flee_to, hopping when something holds it up.
func _run_off(state: PhysicsDirectBodyState2D, grounded: bool) -> void:
	if _escaped:
		return
	if not fleeing:
		var p := _nearest_player()
		if p == null or p.position.distance_to(position) > flee_range:
			return
		fleeing = true
		_taunt("They're here! Raise the alarm!")
	var gap := flee_to - position
	if absf(gap.x) < 40.0 and absf(gap.y) < 120.0:
		_escaped = true
		escaped.emit(self)
		return
	var dir := signf(gap.x)
	var stats := info()
	var top: float = stats.get("flee_spin", stats.spin)
	if grounded and state.angular_velocity * dir < top:
		# Running flat out: tips over its corners as a player does.
		var tip: float = PlayerMotion.TIP_ASSIST * state.total_gravity.length() * stats.radius * state.inverse_inertia / state.inverse_mass
		state.angular_velocity += dir * (SPIN_ACCEL + tip) * state.step
	_flee_stuck = _flee_stuck + state.step if grounded and absf(state.linear_velocity.x) < 25.0 else 0.0
	if _flee_stuck > FLEE_STUCK:
		_flee_stuck = 0.0
		state.linear_velocity += Vector2(dir * 90.0, -float(stats.hop))


## A wild shape (log 0224): shuffles about near home, now and then, and
## rolls away hard from whoever just hit it.
func _roam(state: PhysicsDirectBodyState2D, grounded: bool) -> void:
	var stats := info()
	var step := state.step
	_flee -= step
	_wander_timer -= step
	var dir := 0.0
	var top: float = stats.spin
	if _flee > 0.0:
		dir = _flee_dir
		top = stats.get("flee_spin", stats.spin * 3.0)
	else:
		if _wander_timer <= 0.0:
			_wander_timer = _rng.randf_range(1.5, 4.0)
			_wander_dir = [-1.0, 0.0, 0.0, 1.0][_rng.randi_range(0, 3)]
		dir = _wander_dir
		if absf(position.x - home.x) > WANDER and signf(home.x - position.x) != dir:
			dir = signf(home.x - position.x)
	if dir != 0.0 and room.has_area() and not room.has_point(position + Vector2(dir * 60.0, 0)):
		dir = -dir  # the yard's edge: turn
		_flee_dir = dir
		_wander_dir = dir
	if grounded and dir != 0.0 and state.angular_velocity * dir < top:
		var tip: float = TIP_ASSIST * state.total_gravity.length() * stats.radius * state.inverse_inertia / state.inverse_mass
		state.angular_velocity += dir * (SPIN_ACCEL + tip) * step


## Server: a wild shape hit by `peer` bolts away from them.
func _startle(peer: int) -> void:
	for node in get_tree().get_nodes_in_group(PlayerShape.GROUP):
		var p := node as PlayerShape
		if p != null and p.peer_id == peer:
			_flee = FLEE_TIME
			_flee_dir = 1.0 if position.x >= p.position.x else -1.0
			return


## Where it keeps when there's nothing to fight: home, or its spot by the
## boss it guards.
func _anchor() -> Vector2:
	if guard != null:
		return guard.position + Vector2(guard_offset, 0)
	return home


## A Revolt boss's moves (design log 0089), one every BOSS_MOVE_EVERY: spike
## up when you're close (throwing you onto it), a nose dive onto you from
## middle distance, a rush from further out.
## Each is telegraphed (log 0091): it picks the move, shouts an insult, and
## makes it MOVE_WINDUP later, aimed at wherever its target is by then.
func _boss_move(state: PhysicsDirectBodyState2D, target: Node2D, grounded: bool) -> void:
	if _pending_move != "":
		_windup -= state.step
		if _windup > 0.0:
			return
		if target == null:
			_pending_move = ""
			_move_timer = _next_move()
		elif _pending_move == "rush" or grounded:
			_do_move(state, target, _pending_move)
		return  # spike and dive wait to touch ground
	_move_timer -= state.step
	if target == null or _move_timer > 0.0 or _moves.active():
		return
	var d := target.position - position
	var move := ""
	var known: Array = info().moves if info().get("moves") is Array else ["spike", "dive", "rush"]
	if grounded and d.length() < SpikeUpAbility.RANGE + info().radius - 40.0:
		move = "spike"
	elif grounded and d.length() < 520.0:
		move = "dive"
	elif d.length() < BOSS_RUSH_RANGE:
		move = "rush"
	if move not in known:
		return
	_pending_move = move
	_windup = MOVE_WINDUP
	var taunts: Dictionary = info().get("taunts", TAUNTS)
	_taunt((taunts.get(move, TAUNTS[move]) as Array).pick_random())


func _next_move() -> float:
	var every: Vector2 = info().get("move_every", BOSS_MOVE_EVERY)
	return _rng.randf_range(every.x, every.y)


func _do_move(state: PhysicsDirectBodyState2D, target: Node2D, move: String) -> void:
	_pending_move = ""
	_move_timer = _next_move()
	var radius: float = info().radius
	var d := target.position - position
	if move == "spike":
		var foes: Array = get_tree().get_nodes_in_group(PlayerShape.GROUP).filter(_is_foe)
		foes += get_tree().get_nodes_in_group(GROUP).filter(func(e: Node) -> bool:
			return e != self and _is_foe(e) and not (e as Enemy).freeze)
		(_moves.get_ability("spike_up") as SpikeUpAbility).start(self, state, _corners, _corner_angles, radius, foes)
	elif move == "dive":
		var speed: float = info().hop * BOSS_DIVE_JUMP
		var g := maxf(state.total_gravity.y, 1.0)
		# Up at speed, down at double gravity: about this long in the air.
		var flight := speed / g * (1.0 + 1.0 / sqrt(NoseDiveAbility.GRAVITY))
		(_moves.get_ability("nose_dive") as NoseDiveAbility).start(state, _ground_normal, speed, d.x / flight)
	else:
		(_moves.get_ability("rush") as RushAbility).start(state, signf(d.x) if d.x != 0.0 else 1.0, radius)


## Server only. Says `line` in a bubble over it, to the players in its room
## (a quest's bout, log 0181).
func shout(line: String) -> void:
	_taunt(line)


## Server: shout `line` in a speech bubble over this fighter, to the players
## on its field.
func _taunt(line: String) -> void:
	for node in get_tree().get_nodes_in_group(PlayerShape.GROUP):
		var p := node as PlayerShape
		if p == null or not room.has_point(p.position):
			continue
		if p.peer_id == multiplayer.get_unique_id():
			_taunted(line)
		else:
			_taunted.rpc_id(p.peer_id, line)


@rpc("authority", "call_remote", "reliable")
func _taunted(line: String) -> void:
	get_tree().call_group(Hud.GROUP, "speak_from", self, Vector2(0, -info().radius - 40), line)


## A soldier's travel jump (log 0080): up, forward, and tumbling the way it's going.
func _travel_jump(state: PhysicsDirectBodyState2D, dir: float, hurry: float) -> void:
	var v := state.linear_velocity
	v.y = minf(v.y, 0.0) - TRAVEL_JUMP * (1.0 + 0.4 * hurry)
	if v.x * dir < TRAVEL_PUSH * (1.0 + hurry):
		v.x = dir * TRAVEL_PUSH * (1.0 + hurry)
	state.linear_velocity = v
	state.angular_velocity = dir * maxf(TRAVEL_FLIP, absf(state.angular_velocity))
	_hop_timer = _rng.randf_range(TRAVEL_EVERY.x, TRAVEL_EVERY.y) / (1.0 + hurry)


## Orbit steering: which way to roll (0 = wait). Heads for the spot
## ORBIT_REACH past the player on `_orbit_side`; once there it waits until the
## player has moved, then picks the far side from where it now is and goes.
func _orbit_dir(player_x: float) -> float:
	if not is_nan(_orbit_anchor):
		if absf(player_x - _orbit_anchor) < ORBIT_TRIGGER:
			return 0.0
		_orbit_anchor = NAN
		_orbit_side = -signf(position.x - player_x) if position.x != player_x else -_orbit_side
	var goal := player_x + _orbit_side * ORBIT_REACH
	if (goal - position.x) * _orbit_side <= HOME_SLACK:
		_orbit_anchor = player_x  # there (or past it): settle and wait
		return 0.0
	return signf(goal - position.x)


## Hostiles fight players and soldiers; soldiers fight hostiles. One
## fighting a bout fights only its owner.
func _is_foe(o: Object) -> bool:
	if owner_peer != 0:
		return o is PlayerShape and (o as PlayerShape).peer_id == owner_peer
	if o is PlayerShape:
		return not is_army()
	return o is Enemy and (o as Enemy).is_army() != is_army() and (o as Enemy).hp > 0


## The closest foe inside this enemy's room and within range, or null.
## Seeking soldiers have no range limit: anywhere in the room will do.
func _nearest_target() -> Node2D:
	var best: Node2D = null
	var best_d := INF if role in ["seek", "charge"] or info().get("aggro", "") == "room" else AGGRO_RANGE
	if info().has("ranged"):
		best_d = maxf(best_d, float(info().ranged.range))  # a thrower sees as far as it throws
	# A ranger's camouflage (log 0254): it sees them only from closer, even
	# one that otherwise sees its whole room.
	var sight := minf(best_d, maxf(AGGRO_RANGE, float(info().get("ranged", {}).get("range", 0.0))))
	var group := Enemy.GROUP if is_army() else PlayerShape.GROUP
	var candidates := get_tree().get_nodes_in_group(group)
	if not is_army():
		candidates += get_tree().get_nodes_in_group(Enemy.GROUP)
	for node in candidates:
		var foe := node as Node2D
		if foe == null or foe == self or not _is_foe(foe) or not room.has_point(foe.position):
			continue
		var d := position.distance_to(foe.position)
		if foe is PlayerShape:
			var hidden := (foe as PlayerShape).stealth()
			if hidden > 0.0 and d > sight * (1.0 - hidden):
				continue
		if d < best_d:
			best_d = d
			best = foe
	return best


## Soldiers: the nearest player in their room, to keep up with.
func _nearest_player() -> PlayerShape:
	var best: PlayerShape = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group(PlayerShape.GROUP):
		var p := node as PlayerShape
		if p == null or not room.has_point(p.position):
			continue
		var d := position.distance_to(p.position)
		if d < best_d:
			best_d = d
			best = p
	return best


func _process(delta: float) -> void:
	if multiplayer.is_server():
		net_state = NetSmoother.state_of(self)
	elif not _smoother.is_empty():
		var s := _smoother.current(delta)
		position = Vector2(s.x, s.y)
		rotation = s.z
	queue_redraw()


func _draw() -> void:
	var stats := info()
	if is_army():
		Gear.draw_shape(self, _points, stats.sides, PackedStringArray(SOLDIER_WEAR))
	elif stats.has("wear"):
		var tier: int = stats.wear
		var worn := PackedStringArray()
		for slot in Gear.SLOTS:
			worn.append(Gear.item(slot, tier) if slot in Gear.slots_for(tier) else "")
		Gear.draw_shape(self, _points, stats.sides, worn)
	else:
		draw_colored_polygon(_points, _color)
		if stats.get("wild", false):
			Gear.draw_hatch(self, _points, [[80.0, 100.0], 7.0], 1.0, Color(Palette.INK, 0.3))
		var outline := _points.duplicate()
		outline.append(_points[0])
		draw_polyline(outline, Palette.INK, 3.0 if is_boss() else 2.5, true)

	draw_set_transform(Vector2.ZERO, -rotation)
	var radius: float = info().radius
	if charging:  # an archer's charge (log 0253): a pulsing gold ring
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 60.0)
		draw_arc(Vector2.ZERO, radius + 10.0 + 6.0 * pulse, 0.0, TAU, 32, Color(Palette.XP, 0.5 + 0.5 * pulse), 3.0, true)
	var font := ThemeDB.fallback_font
	if is_boss() or hp < max_hp:
		var width := 120.0 if is_boss() else 44.0
		var bar := Rect2(-width / 2.0, -radius - 14, width, 5 if not is_boss() else 8)
		draw_rect(bar, Palette.PARCHMENT)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * hp / maxf(max_hp, 1), bar.size.y)), Palette.HEALTH)
		draw_rect(bar, Palette.INK, false, 1.0)
	if is_boss() or stats.get("named", false):
		draw_string(font, Vector2(-150, -radius - 22), info().name, HORIZONTAL_ALIGNMENT_CENTER, 300, 18,
				Palette.ink_at(position))

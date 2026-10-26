class_name Mission
extends StaticBody2D
## One squad's battlefield at the front (design log 0070): rolling ground
## between the army's flag in the west and the Colour Revolt's painted camp
## in the east. Each squad gets its own copy, in its own slot far from the
## rest of the world (Regions.mission_rect), so missions are instanced.
##
## The server spawns it with a seed and every peer builds the same ground
## from that seed. Missions (the server's manager) fills it with soldiers and
## the Revolt.

## *Proposed* numbers. levels: a guide only (log 0072). squad: most players.
## pay: combatant pay each on success. allies: friendly soldiers.
## boss: chance (before luck) that a Revolt boss is here; boss_type and
## boss_strength (share of its full health, damage and armor) say which.
## Recon's secret rolls (design logs 0088, 0089), never in the orders:
## "noble", the chance of a Painted Noble (pay x noble_pay); and the boss
## chance, a half-strength Captain (pay x boss_pay) with twice the rebels, a
## Painted Gentleman and a Noble, all huddled round him. "report_pay": what
## reporting him to the General instead pays (times `pay`).
## Invasion's gentry (design log 0091): `gentry` is how many (min, max) of
## the Revolt's Gentlemen and Nobles, at gentry_strength, using its moves.
## Painted skirmishers (log 0247): `skirmishers` (min, max) throwers, at
## skirmisher_strength; special ops swaps that many bodyguards for them.
## The fortress raid (logs 0248, 0250) is a Fortress, not this ground:
## "rangers" (only those through ranger school), "wall_strength" (the
## wall-walk's guards), "troop" (soldiers who charge in once the drawbridge
## is down), "boss_type" (the Castellan), "lookout_sight" (how near you
## come before the lookouts run, log 0253), "alarm_archers" (how many come
## down if one gets in).
const TYPES := {
	"recon": {
		"name": "Recon", "levels": "5–10", "width": 2800.0, "squad": 4, "pay": 25, "allies": 1,
		"boss": 0.1, "boss_type": "captain", "boss_strength": 0.5, "boss_pay": 5,
		"noble": 0.2, "noble_pay": 2, "report_pay": 2, "skirmishers": Vector2i(1, 2),
		"brief": "Recon: find the Revolt's scouts and rout them.",
		"about": "3–5 painted rebels and a skirmisher or two, who throw. One soldier goes with you.",
	},
	"invasion": {
		"name": "Invasion", "levels": "10–20", "width": 5600.0, "squad": 8, "pay": 80, "allies": 10,
		"boss": 0.0, "gentry": Vector2i(1, 3), "gentry_strength": 2.0,
		"skirmishers": Vector2i(4, 6), "skirmisher_strength": 1.6,
		"brief": "Invasion: take the Revolt's camp. Ten soldiers march with you.",
		"about": "20+ rebels and agitators, 4–6 skirmishers and 1–3 of their painted gentry. Ten soldiers on your side.",
	},
	"special_ops": {
		"name": "Special ops", "levels": "20", "width": 3200.0, "squad": 2, "pay": 200, "allies": 0,
		"boss": 1.0, "boss_type": "chromatistes", "skirmishers": Vector2i(2, 2), "skirmisher_strength": 2.5,
		"brief": "Special ops: get past the bodyguards and his Captain. Chromatistes must not leave.",
		"about": "One or two of you. Three bodyguards, two skirmishers, a Captain of the Revolt and Chromatistes, the Painter.",
	},
	"fortress": {
		"name": "Fortress raid", "levels": "20", "width": 7500.0, "squad": 4, "pay": 250, "allies": 0,
		"boss": 1.0, "boss_type": "castellan", "rangers": true, "wall_strength": 2.5, "troop": 8,
		"lookout_sight": 700.0, "alarm_archers": 10,
		"brief": "Fortress raid: cross by boat, climb the wall, let the drawbridge down. The troop does the rest.",
		"about": "Rangers only. A rowboat through a storm, an enemy boat at their pier, a wall to climb, and the Castellan of the Revolt. Stop the lookouts. Fall in and you're out.",
	},
}
const ORDER: Array[String] = ["recon", "invasion", "special_ops", "fortress"]

const STEP := 200.0  # px between ground points
const FLAT_START := 700.0  # the army's end is flat, for mustering
const FLAT_END := 600.0  # so is the Revolt's camp
const WALL_HEIGHT := 1600.0
const DEPTH := 500.0  # solid ground below the surface

var mission_type := "recon"
var slot := 0
var width := 2800.0
## Local surface points, west to east.
var surface := PackedVector2Array()


static func create(data: Dictionary) -> Mission:
	var m := Mission.new()
	m.name = data.name
	m.mission_type = data.type
	m.slot = data.slot
	m.width = TYPES[m.mission_type].width
	m.position = origin(m.slot)
	m.surface = _make_surface(m.width, data.seed)
	return m


static func origin(at_slot: int) -> Vector2:
	return Regions.MISSION_ORIGIN + Vector2(at_slot * Regions.MISSION_SPACING, 0)


## Gentle hills, never steeper than about 14° so any shape can climb them.
static func _make_surface(field_width: float, seed_value: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pts := PackedVector2Array()
	var y := 0.0
	var x := 0.0
	while x <= field_width + 0.1:
		if x > FLAT_START and x < field_width - FLAT_END:
			y = clampf(y + rng.randf_range(-48.0, 48.0), -180.0, 60.0)
		pts.append(Vector2(x, y))
		x += STEP
	return pts


func _ready() -> void:
	collision_layer = PlayerShape.LAYER_TERRAIN
	collision_mask = 0
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 1.0
	var ground := CollisionPolygon2D.new()
	ground.polygon = _ground_polygon()
	add_child(ground)


## The ground's height at local x.
func floor_at(local_x: float) -> float:
	var i := clampi(floori(local_x / STEP), 0, surface.size() - 2)
	var a := surface[i]
	var b := surface[i + 1]
	return lerpf(a.y, b.y, clampf((local_x - a.x) / (b.x - a.x), 0.0, 1.0))


## A world point standing `lift` px above the ground at local x.
func ground_point(local_x: float, lift: float) -> Vector2:
	return position + Vector2(local_x, floor_at(local_x) - lift)


func _ground_polygon() -> PackedVector2Array:
	var poly := PackedVector2Array([Vector2(-200, -WALL_HEIGHT), Vector2(0, -WALL_HEIGHT)])
	poly.append_array(surface)
	poly.append(Vector2(width, -WALL_HEIGHT))
	poly.append(Vector2(width + 200, -WALL_HEIGHT))
	poly.append(Vector2(width + 200, DEPTH))
	poly.append(Vector2(-200, DEPTH))
	return poly


func _draw() -> void:
	draw_colored_polygon(_ground_polygon(), Palette.PARCHMENT_DARK)
	var hatch := Color(Palette.INK_FADED, 0.25)
	for i in surface.size() - 1:
		var a := surface[i]
		var b := surface[i + 1]
		var count := int(a.distance_to(b) / 16.0)
		for k in count:
			var p := a.lerp(b, (k + 0.5) / count)
			draw_line(p + Vector2(4, 6), p + Vector2(-8, 18), hatch, 1.5)
	var line := PackedVector2Array([Vector2(0, -WALL_HEIGHT)])
	for p in surface:
		line.append(p + Vector2(0, -1.5))
	line.append(Vector2(width, -WALL_HEIGHT))
	draw_polyline(line, Palette.INK, 3.0, true)

	var font := ThemeDB.fallback_font
	var sign_at := Vector2(560, floor_at(560))
	draw_string(font, sign_at + Vector2(-400, -160), TYPES[mission_type].brief, HORIZONTAL_ALIGNMENT_CENTER,
			800, 18, Palette.INK)

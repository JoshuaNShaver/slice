class_name Gear
## Items and gear slots (design logs 0029, 0036).
##
## The book has no equipment (Flatlanders have no hands), so the five slots
## come from what it does have: sharp points, colour, the eye and the voice.
## Each gives one stat, so it never changes your outline (log 0006):
##
## | Slot    | What it is                          | Gives    |
## |---------|-------------------------------------|----------|
## | Points  | caps on your corners                | force    |
## | Plating | armor                               | rigidity |
## | Pigment | contraband colour (Colour Revolt)   | vigor    |
## | Eye     | a lens for sight recognition        | luck     |
## | Voice   | a pipe for your cry                 | mettle   |
##
## Items are strings, so they sync and save simply: "plating_2" is tier 2
## plating, "certificate" a marriage certificate, "blessed_certificate" the
## rare one that makes a triangle's heir equilateral (design log 0032), and
## "potion" a healing potion (design log 0037). Each cave room drops
## the next tier (rose 1, mint 2, lilac 3, the Pretender's gilded 4).
##
## Wearing all five slots in one tier completes its set, which adds that
## tier's own bonus (design log 0040).

const CERTIFICATE := "certificate"
const BLESSED_CERTIFICATE := "blessed_certificate"
const POTION := "potion"
const CONSUMABLES: Array[String] = [CERTIFICATE, BLESSED_CERTIFICATE, POTION]

## In order: the HUD lists them this way, and `equipped` is indexed by it.
const SLOTS: Array[String] = ["points", "plating", "pigment", "eye", "voice"]
const SLOT_INFO := {
	"points": {"label": "Points", "noun": "caps", "stat": "force", "bonus": [0, 3, 6, 10, 15]},
	"plating": {"label": "Plating", "noun": "plating", "stat": "rigidity", "bonus": [0, 4, 9, 15, 22]},
	"pigment": {"label": "Pigment", "noun": "pigment", "stat": "vigor", "bonus": [0, 3, 6, 10, 15]},
	"eye": {"label": "Eye", "noun": "lens", "stat": "luck", "bonus": [0, 3, 6, 10, 15]},
	"voice": {"label": "Voice", "noun": "pipe", "stat": "mettle", "bonus": [0, 3, 6, 10, 15]},
}

## Index = tier. Tier 0 is nothing. `set`: the full-set bonus (log 0040).
## Torque is speed, rigidity is defense, and vigor is health (10 each).
const TIERS: Array[Dictionary] = [
	{"name": "", "color": Color.TRANSPARENT, "set": {}},
	{"name": "Rose", "color": Color("e38f8f"), "set": {"force": 15}},
	{"name": "Mint", "color": Color("8cc78a"), "set": {"torque": 15}},
	{"name": "Lilac", "color": Color("a58fd6"), "set": {"rigidity": 15}},
	{"name": "Gilded", "color": Color("d9b44a"), "set": {"vigor": 15, "luck": 15}},
]


static func item(slot: String, tier: int) -> String:
	return "%s_%d" % [slot, tier]


static func random_item(tier: int, rng: RandomNumberGenerator) -> String:
	return item(SLOTS[rng.randi_range(0, SLOTS.size() - 1)], tier)


## The slot an item goes in, or "" if it isn't gear.
static func slot_of(it: String) -> String:
	var slot := it.get_slice("_", 0)
	return slot if slot in SLOTS and it.contains("_") else ""


static func tier_of(it: String) -> int:
	if slot_of(it) == "":
		return 0
	return clampi(it.get_slice("_", 1).to_int(), 0, TIERS.size() - 1)


static func is_gear(it: String) -> bool:
	return slot_of(it) != "" and tier_of(it) > 0


## Any real item: gear or a consumable. For checking saves.
static func is_item(it: String) -> bool:
	return it in CONSUMABLES or (is_gear(it) and it == item(slot_of(it), tier_of(it)))


## {"force": 6} for "points_2"; {} for anything that isn't gear.
static func bonuses(it: String) -> Dictionary:
	if not is_gear(it):
		return {}
	var info: Dictionary = SLOT_INFO[slot_of(it)]
	return {info.stat: info.bonus[tier_of(it)]}


## The tier whose full set is worn, or 0. `worn` is indexed like SLOTS.
static func set_tier(worn: PackedStringArray) -> int:
	var tier := tier_of(worn[0]) if worn.size() == SLOTS.size() else 0
	for it in worn:
		if not is_gear(it) or tier_of(it) != tier:
			return 0
	return tier


## The full-set bonus for what's worn, e.g. {"force": 15}, or {}.
static func set_bonus(worn: PackedStringArray) -> Dictionary:
	return TIERS[set_tier(worn)].set


## Everything worn adds, set bonus included: {"force": 21, "luck": 15}.
static func total_bonus(worn: PackedStringArray) -> Dictionary:
	var total := set_bonus(worn).duplicate()
	for it in worn:
		var gains := bonuses(it)
		for stat: String in gains:
			total[stat] = total.get(stat, 0) + gains[stat]
	return total


## "+15 force", "+15 vigor, +15 luck".
static func describe_bonus(gains: Dictionary) -> String:
	var parts: Array[String] = []
	for stat: String in gains:
		parts.append("+%d %s" % [gains[stat], stat])
	return ", ".join(parts)


static func color(it: String) -> Color:
	return TIERS[tier_of(it)].color


## "Mint lens", "a marriage certificate".
static func item_name(it: String) -> String:
	if it == CERTIFICATE:
		return "Marriage certificate"
	if it == BLESSED_CERTIFICATE:
		return "Blessed certificate"
	if it == POTION:
		return "Healing potion"
	if not is_gear(it):
		return it
	return "%s %s" % [TIERS[tier_of(it)].name, SLOT_INFO[slot_of(it)].noun]


## "Mint lens (eye, tier 2): +6 luck". For tooltips and messages.
static func describe(it: String) -> String:
	if it == CERTIFICATE:
		return "Marriage certificate: bring it to the priest in the Center."
	if it == BLESSED_CERTIFICATE:
		return "Blessed certificate: a triangle who marries with it has an equilateral heir."
	if it == POTION:
		return "Healing potion: restores %d%% of your health." % roundi(Stats.POTION_HEAL * 100)
	if not is_gear(it):
		return it
	var slot := slot_of(it)
	var info: Dictionary = SLOT_INFO[slot]
	# Set bonuses stay secret until you wear the full set (design log 0045).
	return "%s (%s, tier %d): +%d %s" % [item_name(it), info.label.to_lower(), tier_of(it),
			info.bonus[tier_of(it)], info.stat]


## Draws a shape wearing its gear, centered on `at`: pigment tints the fill,
## plating is a hatched inner band, points are dots on the corners. The
## outline (and so the corner angles) never changes (design log 0006).
## Shared by the shape in the world and its icons (HUD, main menu), so gear
## looks the same everywhere. `equipped` is indexed like SLOTS.
static func draw_shape(canvas: CanvasItem, pts: PackedVector2Array, sides: int,
		equipped: PackedStringArray, at := Vector2.ZERO) -> void:
	var worn := func(slot: String) -> String:
		var i := SLOTS.find(slot)
		return equipped[i] if i < equipped.size() else ""
	var radius := 0.0
	for p in pts:
		radius = maxf(radius, p.length())
	var scale := radius / 28.0  # the world shape's radius; icons scale the details
	var placed := PackedVector2Array()
	for p in pts:
		placed.append(p + at)

	var full_set := set_tier(equipped)
	if full_set > 0:
		# A full set (log 0040): a halo in its color, lifted a little off the
		# outline at an even distance, with rounded corners and a soft glow.
		var halo := _rounded_outline(pts, 7.0 * scale)
		for i in halo.size():
			halo[i] += at
		var tint: Color = TIERS[full_set].color
		canvas.draw_polyline(halo, Color(tint, 0.25), 7.0 * scale, true)
		canvas.draw_polyline(halo, Color(tint, 0.85), 2.5 * scale, true)

	var fill := Palette.chalk_for_sides(sides)
	var pigment: String = worn.call("pigment")
	if pigment != "":
		fill = fill.lerp(color(pigment), 0.45)  # contraband colour
	canvas.draw_colored_polygon(placed, fill)

	var plating: String = worn.call("plating")
	if plating != "":
		var band := PackedVector2Array()
		for p in pts:
			band.append(p * 0.78 + at)
		band.append(band[0])
		canvas.draw_polyline(band, color(plating), 3.0 * scale, true)
		var hatch := Color(Palette.INK, 0.35)
		for i in pts.size():
			var mid := (pts[i] + pts[(i + 1) % pts.size()]) * 0.5
			canvas.draw_line(mid * 0.72 + at, mid * 0.9 + at, hatch, 1.5 * scale)

	var outline := placed.duplicate()
	outline.append(placed[0])
	canvas.draw_polyline(outline, Palette.INK, 2.5, true)

	var caps: String = worn.call("points")
	if caps != "":
		for p in pts:
			canvas.draw_circle(p * 0.93 + at, 3.5 * scale, color(caps))
			canvas.draw_arc(p * 0.93 + at, 3.5 * scale, 0, TAU, 10, Palette.INK, 1.0, true)


## The outline pushed out by `gap` on every side, with each corner rounded
## into an arc around it. A closed polyline (first point repeated at the end).
static func _rounded_outline(pts: PackedVector2Array, gap: float) -> PackedVector2Array:
	var n := pts.size()
	var center := Vector2.ZERO
	for p in pts:
		center += p
	center /= n
	# Which perpendicular points outward depends on the winding.
	var e0 := (pts[1] - pts[0]).normalized()
	var flip := 1.0 if Vector2(e0.y, -e0.x).dot((pts[0] + pts[1]) / 2.0 - center) > 0.0 else -1.0
	var normals := PackedVector2Array()  # outward normal of the edge from corner i to i+1
	for i in n:
		var e := (pts[(i + 1) % n] - pts[i]).normalized()
		normals.append(Vector2(e.y, -e.x) * flip)
	var turns := PackedFloat32Array()
	var total := 0.0
	for i in n:
		var turn := wrapf(normals[i].angle() - normals[i - 1].angle(), -PI, PI)
		turns.append(turn)
		total += turn
	var out := PackedVector2Array()
	for i in n:
		var from := normals[i - 1].angle()
		if signf(turns[i]) == signf(total):  # outer corner: sweep an arc
			var steps := maxi(1, ceili(absf(turns[i]) / (PI / 18.0)))
			for k in steps + 1:
				out.append(pts[i] + Vector2.from_angle(from + turns[i] * k / steps) * gap)
		else:  # a dent: the two offset edges just meet
			out.append(pts[i] + normals[i - 1] * gap)
			out.append(pts[i] + normals[i] * gap)
	out.append(out[0])
	return out


## Draws an item's icon centered on `at`, about 28 px across. Shared by the
## ground pickup and the HUD slots.
static func draw_icon(canvas: CanvasItem, it: String, at: Vector2, alpha := 1.0) -> void:
	var ink := Color(Palette.INK, alpha)
	if it == CERTIFICATE or it == BLESSED_CERTIFICATE:
		# A scroll with a seal: red, or gold with a halo when blessed.
		var blessed := it == BLESSED_CERTIFICATE
		if blessed:
			canvas.draw_arc(at, 17.0, 0, TAU, 24, Color(TIERS[4].color, alpha), 2.0, true)
		var rect := Rect2(at + Vector2(-14, -10), Vector2(28, 20))
		canvas.draw_rect(rect, Color(Palette.PARCHMENT_LIGHT, alpha))
		canvas.draw_rect(rect, ink, false, 2.0)
		canvas.draw_line(at + Vector2(-8, -3), at + Vector2(8, -3), ink, 1.5)
		canvas.draw_line(at + Vector2(-8, 2), at + Vector2(4, 2), ink, 1.5)
		var seal := TIERS[4].color if blessed else Palette.HEALTH
		canvas.draw_circle(at + Vector2(9, 7), 5.0, Color(seal, alpha))
		return
	if it == POTION:
		# A round flask of red draught.
		var flask := Color(Palette.HEALTH, alpha)
		canvas.draw_circle(at + Vector2(0, 4), 10.0, flask)
		canvas.draw_arc(at + Vector2(0, 4), 10.0, 0, TAU, 20, ink, 2.0, true)
		var neck := Rect2(at + Vector2(-4, -12), Vector2(8, 8))
		canvas.draw_rect(neck, Color(Palette.PARCHMENT_LIGHT, alpha))
		canvas.draw_rect(neck, ink, false, 2.0)
		return
	var fill := Color(color(it), alpha)
	var pts: PackedVector2Array
	match slot_of(it):
		"points":  # a sharp cap
			pts = PackedVector2Array([Vector2(0, -14), Vector2(10, 10), Vector2(-10, 10)])
		"plating":  # a shield
			pts = PackedVector2Array([Vector2(-12, -12), Vector2(12, -12), Vector2(12, 2), Vector2(0, 14), Vector2(-12, 2)])
		"pigment":  # a drop of paint
			pts = PackedVector2Array()
			for i in 12:
				var a := TAU * i / 12.0
				var r := 10.0 if i != 9 else 16.0  # the tip points up
				pts.append(Vector2(cos(a), sin(a)) * r + Vector2(0, 3))
		"eye":  # a lens
			pts = PackedVector2Array()
			for i in 16:
				var a := TAU * i / 16.0
				pts.append(Vector2(cos(a) * 14, sin(a) * 8))
		_:  # voice: a pipe flaring out
			pts = PackedVector2Array([Vector2(-14, -3), Vector2(4, -3), Vector2(13, -11),
					Vector2(13, 11), Vector2(4, 3), Vector2(-14, 3)])
	for i in pts.size():
		pts[i] += at
	canvas.draw_colored_polygon(pts, fill)
	var outline := pts.duplicate()
	outline.append(pts[0])
	canvas.draw_polyline(outline, ink, 2.0, true)
	if slot_of(it) == "eye":
		canvas.draw_circle(at, 3.5, ink)

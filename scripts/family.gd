class_name Family
extends RefCounted
## One family (one save slot) and its current heir.

const SAVE_VERSION := 1
const MAX_NAME_LENGTH := 24
const PRIEST_SIDES := 10  # design log 0010
const KINDS: Array[String] = ["regular", "equilateral", "isosceles", "irregular"]
const IRREGULAR_HEIR_CHANCE := 0.1  # design log 0009

## Isosceles triangles (design log 0031): a new family's apex is 45°, and each
## heir's is 5° wider, so the 3rd heir reaches 60°: equilateral.
const START_APEX := 45
const APEX_STEP := 5
const EQUILATERAL_APEX := 60

## The triangles a new family can start as, picked by the player (design logs 0050, 0065).
const STARTING_KINDS: Array[String] = ["isosceles", "irregular"]

const POLYGON_NAMES := {
	3: "triangle", 4: "square", 5: "pentagon", 6: "hexagon", 7: "heptagon",
	8: "octagon", 9: "nonagon", 10: "decagon", 11: "hendecagon", 12: "dodecagon",
}

var family_name := ""
var founded_unix := 0
var generation := 1
var sides := 3
## Triangle type ("equilateral", "isosceles", "irregular"), or "regular" / "irregular" for 4+ sides.
var kind := "regular"
## Apex angle in degrees, for isosceles triangles only (0 otherwise).
var apex := 0
var renown := 0
var extinct := false
## Rolled when the current heir is born; irregulars get double (design log 0023).
var luck := 0
## The current heir's level, XP, stats and items (design log 0038), as
## PlayerShape.progress() makes them. Empty for a fresh heir.
var progress: Dictionary = {}


static func found(new_name: String, start_kind: String, rng: RandomNumberGenerator) -> Family:
	var f := Family.new()
	f.family_name = clean_name(new_name)
	f.founded_unix = int(Time.get_unix_time_from_system())
	f.sides = 3
	f.kind = start_kind if start_kind in STARTING_KINDS else "isosceles"
	f.apex = START_APEX if f.kind == "isosceles" else 0
	f.luck = Stats.roll_birth_luck(f.kind, rng)
	return f


## The heir a marriage produces (design log 0030):
## {"sides": int, "kind": String, "apex": int, "luck": int, "gained_side": bool, "blessed": bool}.
## Only equilateral triangles can have a square heir (log 0009). An isosceles
## parent's heir has a 5° wider apex, equilateral at 60° (log 0031); an
## irregular triangle's heir stays irregular. 4+ sides always gain one
## (high-rank fertility is open question 2). Any heir can roll irregular.
##
## `blessed` (a blessed certificate, log 0032): a triangle's heir is born
## equilateral, with no irregular roll. For anyone else it's an ordinary
## certificate.
static func roll_heir(parent_sides: int, parent_kind: String, parent_apex: int,
		rng: RandomNumberGenerator, blessed := false) -> Dictionary:
	var heir := {"sides": parent_sides, "kind": "regular", "apex": 0, "gained_side": false, "blessed": false}
	if blessed and parent_sides == 3 and parent_kind != "equilateral":
		heir.kind = "equilateral"
		heir.blessed = true
	else:
		heir.gained_side = parent_sides > 3 or parent_kind == "equilateral"
		if heir.gained_side:
			heir.sides += 1
		if rng.randf() < IRREGULAR_HEIR_CHANCE:
			heir.kind = "irregular"
		elif heir.sides == 3 and parent_kind == "isosceles":
			heir.apex = parent_apex + APEX_STEP
			heir.kind = "isosceles"
			if heir.apex >= EQUILATERAL_APEX:
				heir.kind = "equilateral"
				heir.apex = 0
		elif heir.sides == 3:
			heir.kind = parent_kind
	heir.luck = Stats.roll_birth_luck(heir.kind, rng)
	return heir


static func clean_name(raw: String) -> String:
	var n := raw.strip_edges().left(MAX_NAME_LENGTH)
	return n if n != "" else "Nameless"


## "isosceles triangle (50°)", "square", "irregular pentagon", "14-gon"
static func describe_shape(n_sides: int, shape_kind: String, apex_deg := 0) -> String:
	var base: String = POLYGON_NAMES.get(n_sides, "%d-gon" % n_sides)
	if n_sides == 3 and shape_kind == "isosceles" and apex_deg > 0:
		return "isosceles %s (%d°)" % [base, apex_deg]
	if n_sides == 3 or shape_kind == "irregular":
		return "%s %s" % [shape_kind, base]
	return base


static func with_article(phrase: String) -> String:
	return ("an " if phrase.left(1) in ["a", "e", "i", "o", "u"] else "a ") + phrase


func shape_name() -> String:
	return describe_shape(sides, kind, apex)


## The current heir's worn gear, from saved progress (indexed like Gear.SLOTS).
func worn_gear() -> PackedStringArray:
	var raw: Variant = progress.get("equipped", [])
	var out := PackedStringArray()
	out.resize(Gear.SLOTS.size())
	if raw is Array:
		for i in mini(raw.size(), out.size()):
			if raw[i] is String and Gear.slot_of(raw[i]) == Gear.SLOTS[i]:
				out[i] = raw[i]
	return out


func is_priest() -> bool:
	return sides >= PRIEST_SIDES


## Irregulars can't enter the overworld (design log 0009).
func is_confined_to_underworld() -> bool:
	return kind == "irregular"


## What other players are allowed to see.
func to_public_info() -> Dictionary:
	return {"family": family_name, "sides": sides, "kind": kind, "apex": apex, "luck": luck,
			"generation": generation}


## What a server needs to put this heir in the world: public info plus progress.
func to_session_info() -> Dictionary:
	var info := to_public_info()
	info.progress = progress
	return info


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"family_name": family_name,
		"founded_unix": founded_unix,
		"generation": generation,
		"sides": sides,
		"kind": kind,
		"apex": apex,
		"renown": renown,
		"extinct": extinct,
		"luck": luck,
		"progress": progress,
	}


## Returns null if the data isn't a valid save.
static func from_dict(d: Dictionary) -> Family:
	if int(d.get("version", 0)) != SAVE_VERSION:
		return null
	var f := Family.new()
	f.family_name = clean_name(str(d.get("family_name", "")))
	f.founded_unix = int(d.get("founded_unix", 0))
	f.generation = maxi(1, int(d.get("generation", 1)))
	f.sides = maxi(3, int(d.get("sides", 3)))
	f.kind = str(d.get("kind", "regular"))
	f.apex = int(d.get("apex", 0))
	if f.kind in ["right", "acute"]:  # saves from before log 0031
		f.kind = "isosceles"
		f.apex = START_APEX
	if f.kind not in KINDS:
		return null
	if f.kind == "isosceles":
		f.apex = clampi(f.apex, START_APEX, EQUILATERAL_APEX - APEX_STEP)
	else:
		f.apex = 0
	var saved_progress: Variant = d.get("progress", {})
	f.progress = saved_progress if saved_progress is Dictionary else {}
	f.renown = maxi(0, int(d.get("renown", 0)))
	f.extinct = bool(d.get("extinct", false))
	if d.has("luck"):
		f.luck = clampi(int(d.luck), 0, Stats.MAX_LUCK)
		if f.kind == "irregular" and f.luck < Stats.IRREGULAR_LUCK_BONUS:
			@warning_ignore("integer_division")
			f.luck = f.luck / 2 + Stats.IRREGULAR_LUCK_BONUS  # saved when irregulars got 2x the roll
	else:  # saves from before luck existed
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		f.luck = Stats.roll_birth_luck(f.kind, rng)
	return f

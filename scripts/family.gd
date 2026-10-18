class_name Family
extends RefCounted
## One family (one save slot) and its current heir.

const SAVE_VERSION := 1
const MAX_NAME_LENGTH := 24
const PRIEST_SIDES := 10  # design log 0010
const KINDS: Array[String] = ["regular", "equilateral", "right", "acute", "irregular"]

## Starting-triangle weights for a new family (design log 0016).
## They add up to 90, not 100, so the roll rescales them until the last 10% is decided.
const STARTING_TRIANGLE_WEIGHTS := {
	"equilateral": 0.0,
	"right": 40.0,
	"acute": 40.0,
	"irregular": 10.0,
}

const POLYGON_NAMES := {
	3: "triangle", 4: "square", 5: "pentagon", 6: "hexagon", 7: "heptagon",
	8: "octagon", 9: "nonagon", 10: "decagon", 11: "hendecagon", 12: "dodecagon",
}

var family_name := ""
var founded_unix := 0
var generation := 1
var sides := 3
## Triangle type ("equilateral", "right", "acute", "irregular"), or "regular" / "irregular" for 4+ sides.
var kind := "regular"
var renown := 0
var extinct := false
## Rolled when the current heir is born; irregulars get double (design log 0023).
var luck := 0


static func found(new_name: String, rng: RandomNumberGenerator) -> Family:
	var f := Family.new()
	f.family_name = clean_name(new_name)
	f.founded_unix = int(Time.get_unix_time_from_system())
	f.sides = 3
	f.kind = roll_starting_triangle(rng)
	f.luck = Stats.roll_birth_luck(f.kind, rng)
	return f


static func roll_starting_triangle(rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for weight: float in STARTING_TRIANGLE_WEIGHTS.values():
		total += weight
	var r := rng.randf() * total
	var last := ""
	for k: String in STARTING_TRIANGLE_WEIGHTS:
		var weight: float = STARTING_TRIANGLE_WEIGHTS[k]
		if weight <= 0.0:
			continue
		last = k
		r -= weight
		if r < 0.0:
			return k
	return last  # only when randf() returned exactly 1.0


static func clean_name(raw: String) -> String:
	var n := raw.strip_edges().left(MAX_NAME_LENGTH)
	return n if n != "" else "Nameless"


## "acute triangle", "square", "irregular pentagon", "14-gon"
static func describe_shape(n_sides: int, shape_kind: String) -> String:
	var base: String = POLYGON_NAMES.get(n_sides, "%d-gon" % n_sides)
	if n_sides == 3 or shape_kind == "irregular":
		return "%s %s" % [shape_kind, base]
	return base


static func with_article(phrase: String) -> String:
	return ("an " if phrase.left(1) in ["a", "e", "i", "o", "u"] else "a ") + phrase


func shape_name() -> String:
	return describe_shape(sides, kind)


func is_priest() -> bool:
	return sides >= PRIEST_SIDES


## Irregulars can't enter the overworld (design log 0009).
func is_confined_to_underworld() -> bool:
	return kind == "irregular"


## What other players are allowed to see.
func to_public_info() -> Dictionary:
	return {"family": family_name, "sides": sides, "kind": kind, "luck": luck}


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"family_name": family_name,
		"founded_unix": founded_unix,
		"generation": generation,
		"sides": sides,
		"kind": kind,
		"renown": renown,
		"extinct": extinct,
		"luck": luck,
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
	if f.kind not in KINDS:
		return null
	f.renown = maxi(0, int(d.get("renown", 0)))
	f.extinct = bool(d.get("extinct", false))
	if d.has("luck"):
		f.luck = clampi(int(d.luck), 0, Stats.MAX_LUCK)
	else:  # saves from before luck existed
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		f.luck = Stats.roll_birth_luck(f.kind, rng)
	return f

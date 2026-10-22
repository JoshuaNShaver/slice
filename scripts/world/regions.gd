class_name Regions
## Where each part of the world is (DESIGN §1). The world is one plane; y
## grows south. The Center's plaza is at y = 0.
##
## - The Center: x -2400..2400. Its west edge is the barracks gate (log 0061).
## - The barracks (logs 0061, 0072): x -5400..-2400, the drill yard, the
##   General and the Quartermaster.
## - The coast (logs 0200-0202): x -16000..-5400, the dock, the western sea
##   and the Logging Isle (Coast, Ocean).
## - Missions (log 0070): each squad gets its own copy of a battlefield, far
##   out east of everything at MISSION_ORIGIN, one slot apart.
## - The Noble Quarter (log 0054): a plateau at y = -1500 east of the Center,
##   reached by an elevator for 4+ sides.
## - The Priests' Hill (logs 0055, 0063): terraces climbing east and north
##   from the Noble Quarter to the temple at y = -2700.
## - The underworld (logs 0051, 0059, 0066): far below, floor at y = 3000.
##   The Undercroft hub sits under the Center; the training cave runs west.

const CENTER_SPAWN := Vector2(0, -80)
const UNDERCROFT_SPAWN := Vector2(-300, 2920)

## Mission instances (design log 0070). Slot n's battlefield starts at
## MISSION_ORIGIN + n * MISSION_SPACING along x, with its ground near y = 0.
const MISSION_ORIGIN := Vector2(60000, 0)
const MISSION_SPACING := 12000.0
const MISSION_SLOTS := 32
const MISSION_HEIGHT := 3000.0  # the instance's rect spans y -2400..600

## Below this line is the underworld (chalk on slate).
const UNDERWORLD_TOP := 1500.0
## The background fades from parchment to slate between these depths, so the
## change happens during the elevator ride (design log 0056).
const FADE_FROM := 700.0
const FADE_TO := 1900.0

## Checked in order; the first match names the place.
const PLACES: Array[Dictionary] = [
	{"id": "noble", "name": "The Noble Quarter", "rect": Rect2(2100, -2700, 4900, 1260)},
	{"id": "hill", "name": "The Priests' Hill", "rect": Rect2(7000, -3300, 5000, 1860)},
	{"id": "temple", "name": "The Temple of the Circle", "rect": Rect2(12000, -4200, 3200, 1560)},
	{"id": "barracks", "name": "The Barracks", "rect": Rect2(-5400, -2400, 3000, 3100)},
	{"id": "coast", "name": "The Coast", "rect": Rect2(-7900, -2400, 2500, 3550)},
	{"id": "sea", "name": "The Western Sea", "rect": Rect2(-11850, -2400, 3950, 3550)},
	{"id": "island", "name": "The Logging Isle", "rect": Rect2(-14300, -2400, 2450, 3550)},
	{"id": "sea", "name": "The Western Sea", "rect": Rect2(-16000, -2400, 1700, 3550)},
	{"id": "center", "name": "The Center", "rect": Rect2(-2400, -2400, 4800, 3100)},
	{"id": "cave", "name": "The Training Cave", "rect": Rect2(-6800, 1700, 4400, 2000)},
	{"id": "undercroft", "name": "The Undercroft", "rect": Rect2(-2400, 1700, 5200, 2000)},
]


## The place at `pos`: {"id", "name", "rect"}, or {} between places (the
## elevator shafts).
static func at(pos: Vector2) -> Dictionary:
	var slot := mission_slot_at(pos)
	if slot >= 0:
		return {"id": "mission", "name": "The front", "rect": mission_rect(slot)}
	for place: Dictionary in PLACES:
		if (place.rect as Rect2).has_point(pos):
			return place
	return {}


static func rect_of(id: String) -> Rect2:
	for place: Dictionary in PLACES:
		if place.id == id:
			return place.rect
	return Rect2()


## The mission slot `pos` is in, or -1.
static func mission_slot_at(pos: Vector2) -> int:
	var slot := floori((pos.x - MISSION_ORIGIN.x + MISSION_SPACING / 4.0) / MISSION_SPACING)
	if slot < 0 or slot >= MISSION_SLOTS or not mission_rect(slot).has_point(pos):
		return -1
	return slot


## Slot n's whole area: the battlefield plus a margin on each side.
static func mission_rect(slot: int) -> Rect2:
	var x := MISSION_ORIGIN.x + slot * MISSION_SPACING - MISSION_SPACING / 4.0
	return Rect2(x, MISSION_ORIGIN.y - 2400.0, MISSION_SPACING * 0.9, MISSION_HEIGHT)


static func is_underworld(pos: Vector2) -> bool:
	return pos.y > UNDERWORLD_TOP


## 0 above ground, 1 in the underworld, in between down the shaft.
static func underworld_blend(y: float) -> float:
	return smoothstep(FADE_FROM, FADE_TO, y)


## Where a shape of this kind is born and goes home to (design log 0059):
## irregulars below, everyone else in the Center.
static func spawn_for(kind: String) -> Vector2:
	return UNDERCROFT_SPAWN if kind == "irregular" else CENTER_SPAWN


## Who a gate or NPC serves (design logs 0052, 0054, 0066).
## "anyone", "regulars", "irregulars", "four_sides" (4+ sides, regular),
## "five_sides" (5+ sides, regular), "circles" (10+ sides, regular),
## "workmen" (a regular triangle with a 45°+ apex, or any higher rank; log
## 0200) or "merchants" (the same from 55°, log 0205). `apex` matters only
## for those two.
static func admits(rule: String, sides: int, kind: String, apex := 0) -> bool:
	match rule:
		"workmen":
			return _job_rank(sides, kind, apex, 45)
		"merchants":
			return _job_rank(sides, kind, apex, 55)
		"regulars":
			return kind != "irregular"
		"irregulars":
			return kind == "irregular"
		"four_sides":
			return kind != "irregular" and sides >= 4
		"five_sides":
			return kind != "irregular" and sides >= 5
		"circles":
			return kind != "irregular" and sides >= Family.PRIEST_SIDES
	return true


## A triangle's job follows its apex (design log 0177); every higher rank
## keeps it (log 0073).
static func _job_rank(sides: int, kind: String, apex: int, least: int) -> bool:
	if kind == "irregular":
		return false
	if sides > 3 or kind == "equilateral":
		return true
	return apex >= least

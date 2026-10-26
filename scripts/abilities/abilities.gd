class_name Abilities
## Abilities (design log 0086): moves bought once from the Quartermaster for
## chits (log 0206). Each costs COST energy to use. Jumps are free (log 0087),
## so energy is only for these.
##
## Each ability is its own script extending Ability (design log 0107): its
## data, how a player starts it and how it steers. To add one, write the
## script and list it in SCRIPTS; its `slot` says which key uses it.
##
## Abilities are equipped (design log 0243): each player has SLOT_ACTIONS.size()
## key slots, W, S and Shift by default, each holding one owned ability made
## for that slot (PlayerStats.ability_slots).
## MoveSet holds one body's instances, for players and Revolt bosses (log
## 0089).

const COST := 50.0

## Key slots (design log 0243), indexing PlayerStats.ability_slots.
const UP := 0
const DOWN := 1
const SIDE := 2
## Each slot's Controls input action.
const SLOT_ACTIONS: Array[String] = ["ability_up", "ability_down", "ability_side"]
const SLOT_NAMES: Array[String] = ["Up", "Down", "Side"]

## In shop order.
const SCRIPTS: Array[GDScript] = [
	preload("res://scripts/abilities/rush.gd"),
	preload("res://scripts/abilities/nose_dive.gd"),
	preload("res://scripts/abilities/spike_up.gd"),
	# The ranger quartermaster's (log 0244).
	preload("res://scripts/abilities/volley.gd"),
	preload("res://scripts/abilities/charged_shot.gd"),
	preload("res://scripts/abilities/double_jump.gd"),
]

## id -> {"name", "action", "price", "text", "cost"}, in shop order.
static var ALL := _info_of_all()


static func _info_of_all() -> Dictionary:
	var out := {}
	for script in SCRIPTS:
		var ability: Ability = script.new()
		out[ability.id] = ability.info()
	return out


static func is_ability(id: String) -> bool:
	return ALL.has(id)


static func ability_name(id: String) -> String:
	return ALL[id].name if ALL.has(id) else id


static func price(id: String) -> int:
	return ALL[id].price if ALL.has(id) else 0


## The key slot an ability goes in (-1 if there's no such ability).
static func slot_of(id: String) -> int:
	return ALL[id].slot if ALL.has(id) else -1


## The ability ids a shop sells, in shop order.
static func sold_by(shop: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in ALL:
		if ALL[id].shop == shop:
			out.append(id)
	return out


## Slots filled from owned abilities (design log 0243): each keeps what it
## holds if that's still owned and fits, else the first owned ability for it,
## in shop order. For old saves and new purchases.
static func fill_slots(owned: PackedStringArray, slots: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	out.resize(SLOT_ACTIONS.size())
	for i in out.size():
		var held := slots[i] if i < slots.size() else ""
		if held in owned and slot_of(held) == i:
			out[i] = held
			continue
		for id: String in ALL:
			if id in owned and ALL[id].slot == i:
				out[i] = id
				break
	return out


## The index of the sharpest corner of an outline (smallest interior angle).
## Ties (within a degree) go to the corner pointing most toward `prefer`,
## given the outline's current `xform`.
static func sharpest_corner(corners: PackedVector2Array, angles: PackedFloat32Array,
		xform: Transform2D, prefer: Vector2) -> int:
	var best := -1
	var best_angle := INF
	var best_lean := -INF
	for i in corners.size():
		var lean := xform.basis_xform(corners[i]).normalized().dot(prefer)
		if angles[i] < best_angle - 1.0 or (absf(angles[i] - best_angle) <= 1.0 and lean > best_lean):
			best = i
			best_angle = minf(angles[i], best_angle)
			best_lean = lean
	return best

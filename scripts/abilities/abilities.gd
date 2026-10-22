class_name Abilities
## Abilities (design log 0086): moves bought once from the Quartermaster for
## chits (log 0206). Each costs COST energy to use. Jumps are free (log 0087),
## so energy is only for these.
##
## Each ability is its own script extending Ability (design log 0107): its
## data, how a player starts it and how it steers. To add one, write the
## script, list it in SCRIPTS and give its action a key in Controls.
## MoveSet holds one body's instances, for players and Revolt bosses (log
## 0089).

const COST := 50.0

## In shop order.
const SCRIPTS: Array[GDScript] = [
	preload("res://scripts/abilities/rush.gd"),
	preload("res://scripts/abilities/nose_dive.gd"),
	preload("res://scripts/abilities/spike_up.gd"),
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

class_name PlayerSave
extends RefCounted
## A player's saved progress (design log 0038) and house chests (log 0064):
## what to save, putting it back on a fresh shape, and checking a save that
## came from outside. The one place that knows the save format.
##
## progress(): {"level", "xp", "pay", "abilities", "stats" (without gear),
## "bag", "equipped"}. The chest is saved apart, as a plain item list.


## What the family save keeps of this heir. Stats are stored without gear,
## which adds its bonuses back when the progress is restored.
static func progress(p: PlayerShape) -> Dictionary:
	var stats := p.stats
	var equipped := p.inventory.equipped
	var base := {}
	for stat: String in Stats.LEVELED:
		base[stat] = stats.get(stat)
	var worn_gains: Array[Dictionary] = [Gear.set_bonus(equipped)]
	for item in equipped:
		worn_gains.append(Gear.bonuses(item))
	for gains in worn_gains:
		for stat: String in gains:
			if base.has(stat):
				base[stat] -= gains[stat]
	return {
		"level": stats.level,
		"xp": stats.xp,
		"pay": stats.pay,
		"abilities": Array(stats.abilities),
		"stats": base,
		"bag": Array(p.inventory.bag),
		"equipped": Array(equipped),
	}


## Puts saved progress and chests (already checked) on a fresh shape.
static func apply(p: PlayerShape, saved: Dictionary, saved_chest: Variant) -> void:
	var stats := p.stats
	var inventory := p.inventory
	if not saved.is_empty():
		stats.level = saved.level
		stats.xp = saved.xp
		stats.pay = saved.get("pay", 0)
		stats.abilities = PackedStringArray(saved.get("abilities", []))
		for stat: String in Stats.LEVELED:
			stats.set(stat, saved.stats[stat])
		inventory.bag = PackedStringArray(saved.bag)
		inventory.equipped = PackedStringArray(saved.equipped)
		stats.max_hp = Stats.max_hp(stats.vigor)
		for item in inventory.equipped:
			stats.apply_bonuses(item, 1)
		stats.apply_gains(Gear.set_bonus(inventory.equipped), 1)
		stats.hp = stats.max_hp
	if saved_chest is Array or saved_chest is PackedStringArray:
		inventory.chest = clean_items(Array(saved_chest), PlayerInventory.CHEST_SLOTS)


## Server only. A save comes from the player's own machine, so keep every
## value in what play could produce. Returns {} for a fresh heir.
static func sanitize(raw: Dictionary) -> Dictionary:
	if raw.is_empty():
		return {}
	var clean_level := clampi(_as_int(raw.get("level"), 1), 1, Stats.MAX_LEVEL)
	var top_xp := 0 if clean_level >= Stats.MAX_LEVEL else Stats.xp_to_next(clean_level) - 1
	var raw_stats: Variant = raw.get("stats", {})
	var stats := {}
	for stat: String in Stats.LEVELED:
		var value: Variant = raw_stats.get(stat) if raw_stats is Dictionary else null
		stats[stat] = clampi(_as_int(value, 0), 0, Stats.GAIN_MAX * (clean_level - 1))
	var clean_bag := clean_items(raw.get("bag", []), PlayerInventory.BAG_SIZE)
	var raw_equipped := clean_items(raw.get("equipped", []), Gear.SLOTS.size())
	var clean_equipped := PlayerInventory.blank(Gear.SLOTS.size())
	for i in raw_equipped.size():
		if Gear.slot_of(raw_equipped[i]) == Gear.SLOTS[i]:
			clean_equipped[i] = raw_equipped[i]
	return {
		"level": clean_level,
		"xp": clampi(_as_int(raw.get("xp"), 0), 0, top_xp),
		"pay": clampi(_as_int(raw.get("pay"), 0), 0, PlayerStats.MAX_PAY),
		"abilities": _clean_abilities(raw.get("abilities", [])),
		"stats": stats,
		"bag": clean_bag,
		"equipped": clean_equipped,
	}


## Known item strings, in a list of `size` slots ("" for anything else).
static func clean_items(raw: Variant, size: int) -> PackedStringArray:
	var out := PlayerInventory.blank(size)
	if raw is Array:
		for i in mini(raw.size(), size):
			var it: Variant = raw[i]
			if it is String and Gear.is_item(it):
				out[i] = it
	return out


static func _as_int(value: Variant, fallback: int) -> int:
	return int(value) if value is int or value is float else fallback  # JSON numbers are floats


static func _clean_abilities(raw: Variant) -> Array:
	var out := []
	if raw is Array:
		for id: Variant in raw:
			if id is String and Abilities.is_ability(id) and id not in out:
				out.append(id)
	return out

class_name PlayerSave
extends RefCounted
## A player's saved progress (design log 0038) and house chests (log 0064):
## what to save, putting it back on a fresh shape, and checking a save that
## came from outside. The one place that knows the save format.
##
## progress(): {"level", "xp", "chits", "coins", "dock_held", "smith_ore", "abilities",
## "ability_slots" (equipped to keys, log 0243), "stats" (without gear),
## "bag", "equipped", "vault" (the family's strongroom, log 0212),
## "heirlooms" and "heirloom_pending" (log 0216)}. The chest is saved apart, as a plain item list, and
## quests with the account (PlayerQuests, log 0183).


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
		"chits": stats.chits,
		"coins": stats.coins,
		"dock_held": stats.dock_held,
		"smith_ore": stats.smith_ore,
		"abilities": Array(stats.abilities),
		"ability_slots": Array(stats.ability_slots),
		"stats": base,
		"bag": Array(p.inventory.bag),
		"equipped": Array(equipped),
		"vault": Array(p.inventory.vault),
		"heirlooms": Array(p.inventory.heirlooms),
		"heirloom_pending": Array(p.inventory.heirloom_pending),
	}


## Puts saved progress and chests (already checked) on a fresh shape.
static func apply(p: PlayerShape, saved: Dictionary, saved_chest: Variant) -> void:
	var stats := p.stats
	var inventory := p.inventory
	if not saved.is_empty():
		stats.level = saved.level
		stats.xp = saved.xp
		stats.chits = saved.get("chits", 0)
		stats.coins = saved.get("coins", 0)
		stats.dock_held = saved.get("dock_held", 0)
		stats.smith_ore = saved.get("smith_ore", 0)
		stats.abilities = PackedStringArray(saved.get("abilities", []))
		# Saves from before the slots fill them from what's owned (log 0243).
		stats.ability_slots = Abilities.fill_slots(stats.abilities, PackedStringArray(saved.get("ability_slots", [])))
		for stat: String in Stats.LEVELED:
			stats.set(stat, saved.stats[stat])
		inventory.bag = PackedStringArray(saved.bag)
		inventory.equipped = PackedStringArray(saved.equipped)
		inventory.vault = PackedStringArray(saved.get("vault", []))
		inventory.heirlooms = PackedStringArray(saved.get("heirlooms", PlayerInventory.blank(Gear.SLOTS.size())))
		inventory.heirloom_pending = PackedStringArray(saved.get("heirloom_pending",
				PlayerInventory.blank(Gear.SLOTS.size())))
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
	var clean_equipped := _clean_worn(raw.get("equipped", []))
	# The strongroom: whole chests only, as many as can be bought.
	var raw_vault: Variant = raw.get("vault", [])
	if raw_vault is PackedStringArray:
		raw_vault = Array(raw_vault)
	var chests := clampi(raw_vault.size() / PlayerInventory.VAULT_CHEST_SLOTS if raw_vault is Array else 0,
			0, PlayerInventory.VAULT_PRICES.size())
	return {
		"level": clean_level,
		"xp": clampi(_as_int(raw.get("xp"), 0), 0, top_xp),
		# Saves from before log 0204 call chits "pay".
		"chits": clampi(_as_int(raw.get("chits", raw.get("pay")), 0), 0, PlayerStats.MAX_CHITS),
		"coins": clampi(_as_int(raw.get("coins"), 0), 0, PlayerStats.MAX_CHITS),
		"dock_held": clampi(_as_int(raw.get("dock_held"), 0), 0, Market.HELD_MAX),
		"smith_ore": clampi(_as_int(raw.get("smith_ore"), 0), 0, PlayerStats.SMITH_ORE_MAX),
		"abilities": _clean_abilities(raw.get("abilities", [])),
		"ability_slots": _clean_slots(raw.get("ability_slots", [])),
		"stats": stats,
		"bag": clean_bag,
		"equipped": clean_equipped,
		"vault": clean_items(raw_vault, chests * PlayerInventory.VAULT_CHEST_SLOTS),
		"heirlooms": _clean_worn(raw.get("heirlooms", []) if chests > 0 else []),
		"heirloom_pending": _clean_worn(raw.get("heirloom_pending", []) if chests > 0 else []),
	}


## Gear indexed like Gear.SLOTS, each in its own slot ("" otherwise).
static func _clean_worn(raw: Variant) -> PackedStringArray:
	if raw is PackedStringArray:
		raw = Array(raw)
	var items := clean_items(raw, Gear.SLOTS.size())
	var out := PlayerInventory.blank(Gear.SLOTS.size())
	for i in items.size():
		if Gear.slot_of(items[i]) == Gear.SLOTS[i]:
			out[i] = items[i]
	return out


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


## Ability ids or "", one per key slot (log 0243); apply() checks they're owned.
static func _clean_slots(raw: Variant) -> Array:
	var out := []
	for i in Abilities.SLOT_ACTIONS.size():
		var id: Variant = raw[i] if raw is Array and i < raw.size() else ""
		out.append(id if id is String and Abilities.slot_of(id) == i else "")
	return out


static func _clean_abilities(raw: Variant) -> Array:
	var out := []
	if raw is Array:
		for id: Variant in raw:
			if id is String and Abilities.is_ability(id) and id not in out:
				out.append(id)
	return out

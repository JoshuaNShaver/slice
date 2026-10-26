class_name PlayerInventory
extends Node
## A player's items (PlayerShape's "Inventory", design log 0036): the bag,
## the five gear slots (Gear) and the house's chests (log 0064). Set by the
## server, synced to clients. "" is an empty slot.
##
## You grab items off the ground with the pickup key; the HUD asks to move,
## use, equip, unequip or drop them (the request_ methods, owner side). Gear
## adds to your stats while worn. The bag's last QUICK_SLOTS slots are the
## quick-use slots, used with keys 1-5 (design log 0043). Chest slots are
## reached at your house's door, as swaps from CHEST_BASE on.
##
## The family's strongroom (log 0212) is bought a chest at a time from the
## Strongroom Keeper, VAULT_CHEST_SLOTS slots each, reached as swaps from
## VAULT_BASE on. It is the family's: saved with its progress, kept by every
## heir, gone if the family ends.
##
## A family with a strongroom also has HEIRLOOM slots, free, one per gear
## slot (log 0216): when an heir takes over, what the last one wore is
## passed down into them. Where a slot already holds an heirloom, the new
## piece waits in `heirloom_pending` until the player picks which of the
## two to keep (choose_heirloom); the other is lost. Heirloom slots take
## only gear for their own slot, and are reached as swaps from
## HEIRLOOM_BASE on.
##
## Promissory notes stack in one slot (Gear.notes); dropping one stack on
## another merges them.
##
## Packed arrays are copied, changed, then assigned whole, so the sync sees
## each change.

const BAG_SLOTS := 10  # the bag proper
const QUICK_SLOTS := 5  # quick-use slots (keys 1-5), the bag's last five
const BAG_SIZE := BAG_SLOTS + QUICK_SLOTS
const CHEST_SLOTS := 20  # your house's chests (design log 0064)
const CHEST_BASE := 100  # swap indices from here on are chest slots
const VAULT_BASE := 200  # and from here on, the family strongroom's
const VAULT_CHEST_SLOTS := 10  # slots in each strongroom chest
const HEIRLOOM_BASE := 300  # swap indices from here on: heirloom slots, indexed like Gear.SLOTS
## Coins for the family's first, second and third chest (log 0212, *proposed* past the first).
const VAULT_PRICES: Array[int] = [1000, 3000, 8000]

var player: PlayerShape
var bag := blank(BAG_SIZE)
var equipped := blank(Gear.SLOTS.size())  # indexed like Gear.SLOTS
var chest := blank(CHEST_SLOTS)  # kept by the player, not the family (log 0042)
var vault := PackedStringArray()  # the family's strongroom; grows a chest at a time (log 0212)
var heirlooms := blank(Gear.SLOTS.size())  # the last generations' armor, kept (log 0216)
var heirloom_pending := blank(Gear.SLOTS.size())  # newly passed down, waiting for a choice


static func blank(size: int) -> PackedStringArray:
	var a := PackedStringArray()
	a.resize(size)
	return a


func count_of(item: String) -> int:
	return bag.count(item)


## Promissory notes in the bag, every stack counted.
func count_notes() -> int:
	var total := 0
	for it in bag:
		total += Gear.note_count(it)
	return total


## How many more notes the bag could take: room on its stacks, and empty slots.
func room_for_notes() -> int:
	var room := 0
	for it in bag:
		if it == "":
			room += Gear.NOTE_STACK
		elif Gear.note_count(it) > 0:
			room += Gear.NOTE_STACK - Gear.note_count(it)
	return room


## Strongroom chests the family owns.
func vault_chests() -> int:
	return vault.size() / VAULT_CHEST_SLOTS


## At the Strongroom Keeper (log 0212)?
func can_use_vault() -> bool:
	return Npc.near_role(player, "vault")


func worn(slot: String) -> String:
	return equipped[Gear.SLOTS.find(slot)]


## Your chests can be used only at your house's door, as a square or better
## (design logs 0041, 0064).
func can_use_chest() -> bool:
	return Regions.admits(HouseDoor.RULE, player.sides, player.kind) and HouseDoor.in_reach(player)


# --- Owner side, for the HUD and the quick-use keys ------------------------

func request_equip(bag_index: int) -> void:
	_submit_equip.rpc_id(1, bag_index)


## Takes gear off into a chosen bag slot, or the first free one (-1).
func request_unequip(slot_index: int, bag_index := -1) -> void:
	_submit_unequip.rpc_id(1, slot_index, bag_index)


func request_drop(bag_index: int) -> void:
	_submit_drop.rpc_id(1, bag_index)


func request_drink(bag_index: int) -> void:
	_submit_drink.rpc_id(1, bag_index)


## Double-click or a quick-use key: drink a potion, eat, wear gear.
func request_use(bag_index: int) -> void:
	if bag_index < 0 or bag_index >= BAG_SIZE:
		return
	if bag[bag_index] == Gear.POTION:
		request_drink(bag_index)
	elif Gear.is_provision(bag[bag_index]) or Gear.ration_count(bag[bag_index]) > 0:
		_submit_eat.rpc_id(1, bag_index)
	elif Gear.is_gear(bag[bag_index]):
		request_equip(bag_index)


## Drag and drop between bag and chest slots: move, or swap with what's
## there. Chest slots are CHEST_BASE + i.
func request_swap(from: int, to: int) -> void:
	_submit_swap.rpc_id(1, from, to)


# --- Owner -> server --------------------------------------------------------

func _allowed() -> bool:
	return player.from_owner() and not player.dead


func _is_slot(i: int) -> bool:
	return (i >= 0 and i < BAG_SIZE) or (i >= CHEST_BASE and i < CHEST_BASE + CHEST_SLOTS) \
			or (i >= VAULT_BASE and i < VAULT_BASE + vault.size()) \
			or (i >= HEIRLOOM_BASE and i < HEIRLOOM_BASE + Gear.SLOTS.size() and vault_chests() > 0)


@rpc("any_peer", "call_local", "reliable")
func _submit_swap(from: int, to: int) -> void:
	if not _allowed():
		return
	if from == to or not _is_slot(from) or not _is_slot(to):
		return
	for i in [from, to]:
		if i >= VAULT_BASE and not can_use_vault():
			return
		if i >= CHEST_BASE and i < VAULT_BASE and not can_use_chest():
			return
	# An heirloom slot takes only gear for its own slot.
	for pair in [[to, _slot(from)], [from, _slot(to)]]:
		if pair[0] >= HEIRLOOM_BASE and pair[1] != "" and Gear.slot_of(pair[1]) != Gear.SLOTS[pair[0] - HEIRLOOM_BASE]:
			return
	var moving := _slot(from)
	var other := _slot(to)
	# Notes onto notes: one stack, up to NOTE_STACK; the rest stays behind.
	if Gear.note_count(moving) > 0 and Gear.note_count(other) > 0:
		var total := Gear.note_count(moving) + Gear.note_count(other)
		var kept := mini(total, Gear.NOTE_STACK)
		other = Gear.notes(total - kept) if total > kept else ""
		moving = Gear.notes(kept)
	elif Gear.ration_count(moving) > 0 and Gear.ration_count(other) > 0:  # rations too (log 0246)
		var total := Gear.ration_count(moving) + Gear.ration_count(other)
		var kept := mini(total, Gear.RATION_STACK)
		other = Gear.rations(total - kept) if total > kept else ""
		moving = Gear.rations(kept)
	var lists := {"bag": bag, "chest": chest, "vault": vault, "heirlooms": heirlooms}
	for pair in [[from, other], [to, moving]]:
		var where := _where(pair[0])
		lists[where[0]][where[1]] = pair[1]
	bag = lists.bag
	chest = lists.chest
	vault = lists.vault
	heirlooms = lists.heirlooms


## A swap index as [list name, index in it].
func _where(i: int) -> Array:
	if i >= HEIRLOOM_BASE:
		return ["heirlooms", i - HEIRLOOM_BASE]
	if i >= VAULT_BASE:
		return ["vault", i - VAULT_BASE]
	if i >= CHEST_BASE:
		return ["chest", i - CHEST_BASE]
	return ["bag", i]


func _slot(i: int) -> String:
	var where := _where(i)
	match where[0]:
		"heirlooms":
			return heirlooms[where[1]]
		"vault":
			return vault[where[1]]
		"chest":
			return chest[where[1]]
	return bag[where[1]]


## Grab the nearest of your items on the ground.
@rpc("any_peer", "call_local", "reliable")
func _submit_pickup() -> void:
	if not _allowed():
		return
	var best: Pickup = null
	var best_d := Pickup.REACH
	for node in get_tree().get_nodes_in_group(Pickup.GROUP):
		var p := node as Pickup
		if p.owner_id != player.peer_id or p.is_queued_for_deletion():
			continue
		var d := p.position.distance_to(player.position)
		if d <= best_d:
			best_d = d
			best = p
	if best != null and add_to_bag(best.item):
		best.queue_free()


## Wear a bag item. What was in that slot goes back to its place.
@rpc("any_peer", "call_local", "reliable")
func _submit_equip(bag_index: int) -> void:
	if not _allowed():
		return
	if bag_index < 0 or bag_index >= BAG_SIZE or not Gear.is_gear(bag[bag_index]):
		return
	var stats := player.stats
	var item := bag[bag_index]
	if Gear.is_ranger_tier(Gear.tier_of(item)) and not RangerSchoolQuest.trained_or_training(player):
		player.screen.tell("", "Ranger gear. Only those trained at ranger school can use it.")
		return
	var slot_index := Gear.SLOTS.find(Gear.slot_of(item))
	var old := equipped[slot_index]
	stats.apply_gains(Gear.set_bonus(equipped), -1)
	stats.apply_bonuses(old, -1)
	stats.apply_bonuses(item, 1)
	var new_bag := bag
	new_bag[bag_index] = old
	var new_equipped := equipped
	new_equipped[slot_index] = item
	bag = new_bag
	equipped = new_equipped
	stats.apply_gains(Gear.set_bonus(equipped), 1)
	player.quests.notify("equip", item)


## Take gear off, into a bag slot (-1: the first free one). Dropped on gear
## for the same slot, the two swap.
@rpc("any_peer", "call_local", "reliable")
func _submit_unequip(slot_index: int, bag_index: int) -> void:
	if not _allowed():
		return
	if slot_index < 0 or slot_index >= equipped.size() or equipped[slot_index] == "":
		return
	if bag_index >= 0 and bag_index < BAG_SIZE and bag[bag_index] != "":
		if Gear.slot_of(bag[bag_index]) == Gear.SLOTS[slot_index]:
			_submit_equip(bag_index)
		return
	var item := equipped[slot_index]
	if bag_index >= 0 and bag_index < BAG_SIZE:
		var new_bag := bag
		new_bag[bag_index] = item
		bag = new_bag
	elif not add_to_bag(item):
		return
	player.stats.apply_gains(Gear.set_bonus(equipped), -1)  # a set can't survive losing a piece
	player.stats.apply_bonuses(item, -1)
	var new_equipped := equipped
	new_equipped[slot_index] = ""
	equipped = new_equipped


## Put a bag item on the ground. It stays yours until it vanishes
## (Pickup.LIFETIME), so a misclick can be undone.
@rpc("any_peer", "call_local", "reliable")
func _submit_drop(bag_index: int) -> void:
	if not _allowed():
		return
	if bag_index < 0 or bag_index >= BAG_SIZE or bag[bag_index] == "":
		return
	var item := bag[bag_index]
	var new_bag := bag
	new_bag[bag_index] = ""
	bag = new_bag
	get_tree().call_group(World.GROUP, "drop_item", item, player.peer_id, player.position)


## Drink a potion (design log 0037), from a bag slot or, with -1, the first
## one in the bag. Not at full health.
@rpc("any_peer", "call_local", "reliable")
func _submit_drink(bag_index: int) -> void:
	if not _allowed():
		return
	var stats := player.stats
	if bag_index == -1:
		bag_index = bag.find(Gear.POTION)
	if bag_index < 0 or bag_index >= BAG_SIZE or bag[bag_index] != Gear.POTION or stats.hp >= stats.max_hp:
		return
	var new_bag := bag
	new_bag[bag_index] = ""
	bag = new_bag
	player.combat.heal(Stats.potion_heal(stats.max_hp))


## Eat a provision (design log 0084). It heals over Stats.MEAL_TIME; eating
## more adds to what's left. Not at full health.
@rpc("any_peer", "call_local", "reliable")
func _submit_eat(bag_index: int) -> void:
	if not _allowed():
		return
	var stats := player.stats
	if bag_index < 0 or bag_index >= BAG_SIZE or stats.hp >= stats.max_hp:
		return
	var food := bag[bag_index]
	var rations := Gear.ration_count(food)
	if not Gear.is_provision(food) and rations == 0:
		return
	var new_bag := bag
	if rations > 0:  # one off the stack (log 0246)
		new_bag[bag_index] = Gear.rations(rations - 1) if rations > 1 else ""
	else:
		new_bag[bag_index] = ""
	bag = new_bag
	player.combat.eat(Gear.RATION_HEAL if rations > 0 else float(Gear.PROVISIONS[food].heal))


# --- Server only ------------------------------------------------------------

## Puts an item in the first empty slot, the bag proper before the quick-use
## slots; false if all are full.
func add_to_bag(item: String) -> bool:
	var i := bag.find("")  # the bag proper comes first
	if i == -1:
		return false
	var new_bag := bag
	new_bag[i] = item
	bag = new_bag
	return true


## Puts `count` rations in the bag (log 0246): onto its stacks first, then
## empty slots. Returns how many fit.
func add_rations(count: int) -> int:
	var new_bag := bag
	var left := count
	for pass_empty in [false, true]:
		for i in new_bag.size():
			if left <= 0:
				break
			var have := Gear.ration_count(new_bag[i])
			if (pass_empty and new_bag[i] != "") or (not pass_empty and have == 0):
				continue
			var put := mini(left, Gear.RATION_STACK - have)
			if put > 0:
				new_bag[i] = Gear.rations(have + put)
				left -= put
	bag = new_bag
	return count - left


## Puts `count` notes in the bag: onto its stacks first, then empty slots.
## Returns how many fit.
func add_notes(count: int) -> int:
	var new_bag := bag
	var left := count
	for pass_empty in [false, true]:
		for i in new_bag.size():
			if left <= 0:
				break
			var have := Gear.note_count(new_bag[i])
			if (pass_empty and new_bag[i] != "") or (not pass_empty and have == 0):
				continue
			var put := mini(left, Gear.NOTE_STACK - have)
			if put > 0:
				new_bag[i] = Gear.notes(have + put)
				left -= put
	bag = new_bag
	return count - left


## Takes `count` notes from the bag, smallest stacks first; false (and
## nothing taken) if there aren't that many.
func take_notes(count: int) -> bool:
	if count_notes() < count:
		return false
	var new_bag := bag
	var left := count
	while left > 0:
		var smallest := -1
		for i in new_bag.size():
			var n := Gear.note_count(new_bag[i])
			if n > 0 and (smallest == -1 or n < Gear.note_count(new_bag[smallest])):
				smallest = i
		var n := Gear.note_count(new_bag[smallest])
		var take := mini(n, left)
		new_bag[smallest] = Gear.notes(n - take) if n > take else ""
		left -= take
	bag = new_bag
	return true


## Removes one of an item from the bag; false if there was none.
func take_from_bag(item: String) -> bool:
	var i := bag.find(item)
	if i == -1:
		return false
	var new_bag := bag
	new_bag[i] = ""
	bag = new_bag
	return true


## A new heir (design log 0030) keeps consumables where they were, e.g.
## potions on the hotbar, and no gear, except what's passed down into the
## strongroom's heirloom slots (log 0216).
func reset_for_heir() -> void:
	pass_down()
	var kept := bag
	for i in kept.size():
		if not Gear.is_consumable(kept[i]):
			kept[i] = ""
	bag = kept
	equipped = blank(Gear.SLOTS.size())


## Server only. The worn armor goes to the heirloom slots, if the family
## has a strongroom: into an empty slot, or to wait beside a full one for
## the player's choice. A choice still waiting from the generation before
## is settled first, keeping the older heirloom.
func pass_down() -> void:
	if vault_chests() == 0:
		return
	var kept := heirlooms
	var waiting := blank(Gear.SLOTS.size())
	for i in Gear.SLOTS.size():
		var worn_item := equipped[i]
		if not Gear.is_gear(worn_item):
			continue
		if kept[i] == "":
			kept[i] = worn_item
		else:
			waiting[i] = worn_item
	heirlooms = kept
	heirloom_pending = waiting


## Server only. Settles the choice for gear slot `slot`: keep the new piece
## (it replaces the old heirloom) or the old one (the new is lost).
func choose_heirloom(slot: int, keep_new: bool) -> void:
	if slot < 0 or slot >= Gear.SLOTS.size() or heirloom_pending[slot] == "":
		return
	if keep_new:
		var kept := heirlooms
		kept[slot] = heirloom_pending[slot]
		heirlooms = kept
	var waiting := heirloom_pending
	waiting[slot] = ""
	heirloom_pending = waiting


## Owner side: the heirloom choice panel's click.
func request_choose_heirloom(slot: int, keep_new: bool) -> void:
	_submit_choose_heirloom.rpc_id(1, slot, keep_new)


@rpc("any_peer", "call_local", "reliable")
func _submit_choose_heirloom(slot: int, keep_new: bool) -> void:
	if player.from_owner():
		choose_heirloom(slot, keep_new)

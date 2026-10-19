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
## Packed arrays are copied, changed, then assigned whole, so the sync sees
## each change.

const BAG_SLOTS := 10  # the bag proper
const QUICK_SLOTS := 5  # quick-use slots (keys 1-5), the bag's last five
const BAG_SIZE := BAG_SLOTS + QUICK_SLOTS
const CHEST_SLOTS := 20  # your house's chests (design log 0064)
const CHEST_BASE := 100  # swap indices from here on are chest slots

var player: PlayerShape
var bag := blank(BAG_SIZE)
var equipped := blank(Gear.SLOTS.size())  # indexed like Gear.SLOTS
var chest := blank(CHEST_SLOTS)  # kept by the player, not the family (log 0042)


static func blank(size: int) -> PackedStringArray:
	var a := PackedStringArray()
	a.resize(size)
	return a


func count_of(item: String) -> int:
	return bag.count(item)


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
	elif Gear.is_provision(bag[bag_index]):
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


static func _is_slot(i: int) -> bool:
	return (i >= 0 and i < BAG_SIZE) or (i >= CHEST_BASE and i < CHEST_BASE + CHEST_SLOTS)


@rpc("any_peer", "call_local", "reliable")
func _submit_swap(from: int, to: int) -> void:
	if not _allowed():
		return
	if from == to or not _is_slot(from) or not _is_slot(to):
		return
	if (from >= CHEST_BASE or to >= CHEST_BASE) and not can_use_chest():
		return
	var new_bag := bag
	var new_chest := chest
	var moving := _slot(from)
	var other := _slot(to)
	for pair in [[from, other], [to, moving]]:
		var i: int = pair[0]
		if i >= CHEST_BASE:
			new_chest[i - CHEST_BASE] = pair[1]
		else:
			new_bag[i] = pair[1]
	bag = new_bag
	chest = new_chest


func _slot(i: int) -> String:
	return chest[i - CHEST_BASE] if i >= CHEST_BASE else bag[i]


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
	if bag_index < 0 or bag_index >= BAG_SIZE or not Gear.is_provision(bag[bag_index]) or stats.hp >= stats.max_hp:
		return
	var food := bag[bag_index]
	var new_bag := bag
	new_bag[bag_index] = ""
	bag = new_bag
	player.combat.eat(float(Gear.PROVISIONS[food].heal))


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
## potions on the hotbar, and no gear.
func reset_for_heir() -> void:
	var kept := bag
	for i in kept.size():
		if kept[i] not in Gear.CONSUMABLES:
			kept[i] = ""
	bag = kept
	equipped = blank(Gear.SLOTS.size())

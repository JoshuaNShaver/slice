class_name PlayerActions
extends Node
## What a player asks of the world (PlayerShape's "Actions"): interact (E)
## with the nearest NPC, elevator or door (World.interact), take the
## General's orders, Ready up, buy and learn from the Quartermaster, marry.
## The owner asks (request_ methods); the server decides.

## Seconds after drowning before you wake on the shore, if the cutscene
## never reports back (a client that can't show it).
const WAKE_LATEST := 30.0

var player: PlayerShape
var drowning := false  # server: in the sea, waiting to wake on the shore


## Owner -> server: use whatever is nearest (an NPC, elevator or door).
@rpc("any_peer", "call_local", "reliable")
func _submit_interact() -> void:
	if not player.from_owner():
		return
	if not player.dead and not player.motion.riding():
		get_tree().call_group(World.GROUP, "interact", player)


## Server only. A priest (named `priest`) marries you (design log 0030),
## using a certificate, and the wedding and the birth play as a cutscene
## (Cutscenes, log 0168). False if you have none.
func marry(priest := "The Priest") -> bool:
	var certificate := marriage_certificate()
	if player.dead or certificate == "":
		return false
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	player.inventory.take_from_bag(certificate)
	var heir := Family.roll_heir(player.sides, player.kind, player.apex, rng,
			certificate == Gear.BLESSED_CERTIFICATE)
	var parent := {"sides": player.sides, "kind": player.kind, "apex": player.apex}
	var scene := Cutscenes.marriage(player.family_name, parent, heir, priest)
	player.become_heir(heir)
	# A quest that starts at a birth begins, if this family hasn't had it (log 0179).
	Net.play_cutscene(player.peer_id, player.quests.after_birth(scene, heir))
	Net.heir_born_on_server(player.peer_id, heir)
	return true


## The certificate marrying would use, or "". A triangle short of
## equilateral uses a blessed one first (design log 0032); anyone else keeps
## it and uses an ordinary one, if they have one.
func marriage_certificate() -> String:
	var inventory := player.inventory
	var blessed := inventory.count_of(Gear.BLESSED_CERTIFICATE) > 0
	if blessed and player.sides == 3 and player.kind != "equilateral":
		return Gear.BLESSED_CERTIFICATE
	if inventory.count_of(Gear.CERTIFICATE) > 0:
		return Gear.CERTIFICATE
	return Gear.BLESSED_CERTIFICATE if blessed else ""


## Owner side: take the General's orders for a mission (design log 0070).
func request_mission(mission_type: String) -> void:
	_submit_mission.rpc_id(1, mission_type)


@rpc("any_peer", "call_local", "reliable")
func _submit_mission(mission_type: String) -> void:
	if not player.from_owner() or player.dead:
		return
	if Npc.near_role(player, "general"):
		get_tree().call_group(World.GROUP, "request_mission", player, mission_type)


## Owner side: Ready in the countdown popup (design log 0081).
func request_mission_ready() -> void:
	_submit_ready.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _submit_ready() -> void:
	if not player.from_owner() or player.dead:
		return
	get_tree().call_group(World.GROUP, "mission_ready", player)


## Owner side: buy an item from the Quartermaster (design log 0071).
func request_buy(item: String) -> void:
	_submit_buy.rpc_id(1, item)


@rpc("any_peer", "call_local", "reliable")
func _submit_buy(item: String) -> void:
	if not player.from_owner() or player.dead:
		return
	var stats := player.stats
	var cost := Gear.price(item)
	if cost <= 0 or not Npc.near_role(player, "quartermaster"):
		return
	if stats.chits < cost:
		player.screen.tell("The Quartermaster", "That's %d chits. You have %d. Earn them first." % [cost, stats.chits])
		return
	if not player.inventory.add_to_bag(item):
		player.screen.tell("The Quartermaster", "Your bag's full, soldier.")
		return
	stats.chits -= cost


## Owner side: buy from the ranger quartermaster (log 0246): the starting
## ranger gear for chits, the rest and rations for coins.
func request_ranger_buy(item: String) -> void:
	_submit_ranger_buy.rpc_id(1, item)


@rpc("any_peer", "call_local", "reliable")
func _submit_ranger_buy(item: String) -> void:
	if not player.from_owner() or player.dead or not Npc.near_role(player, "ranger_quartermaster"):
		return
	var price := Gear.ranger_price(item)
	if price.is_empty():
		return
	var stats := player.stats
	var currency: String = price.keys()[0]
	var cost: int = price[currency]
	var have := stats.coins if currency == "coins" else stats.chits
	if have < cost:
		player.screen.tell(RangerCamp.QUARTERMASTER, "That's %d %s. You have %d." % [cost, currency, have])
		return
	var fits := player.inventory.add_rations(1) == 1 if item == Gear.RATION else player.inventory.add_to_bag(item)
	if not fits:
		player.screen.tell(RangerCamp.QUARTERMASTER, "No room in your bag.")
		return
	if currency == "coins":
		stats.coins -= cost
	else:
		stats.chits -= cost


## Owner side: learn an ability from the Quartermaster (design log 0086).
func request_learn(id: String) -> void:
	_submit_learn.rpc_id(1, id)


@rpc("any_peer", "call_local", "reliable")
func _submit_learn(id: String) -> void:
	if not player.from_owner() or player.dead:
		return
	var stats := player.stats
	if not Abilities.is_ability(id) or id in stats.abilities:
		return
	var info: Dictionary = Abilities.ALL[id]
	var ranger: bool = info.shop == "ranger"  # the ranger quartermaster's, for coins (log 0244)
	if not Npc.near_role(player, "ranger_quartermaster" if ranger else "quartermaster"):
		return
	var cost := Abilities.price(id)
	var have := stats.coins if info.currency == "coins" else stats.chits
	if have < cost:
		player.screen.tell(RangerCamp.QUARTERMASTER if ranger else "The Quartermaster",
				"That drill's %d %s. You have %d." % [cost, info.currency, have])
		return
	if info.currency == "coins":
		stats.coins -= cost
	else:
		stats.chits -= cost
	var learned := stats.abilities
	learned.append(id)
	stats.abilities = learned
	stats.ability_slots = Abilities.fill_slots(learned, stats.ability_slots)  # into an empty slot (log 0243)
	player.screen.tell("", "Learned %s: %s (%d energy)." % [Abilities.ability_name(id),
			Abilities.ALL[id].text, roundi(Abilities.ALL[id].cost)])


## Server only. Fell into the sea (design log 0201): the screen goes dark,
## everything in the bag is lost, and you wake on the shore. In the
## fortress raid's sea (log 0250) the army fishes you out: you're taken
## straight back to the barracks, and out of the raid (Missions).
func drown() -> void:
	if drowning or player.dead:
		return
	if RangerExam.catch(player):
		return  # the exam's water only sends you back (log 0251)
	drowning = true
	var lost := 0
	for item in player.inventory.bag:
		if item != "":
			lost += 1
	player.inventory.bag = PlayerInventory.blank(PlayerInventory.BAG_SIZE)
	var raid := Regions.mission_slot_at(player.position) >= 0
	if raid:
		player.teleport(Barracks.MUSTER)
	Net.play_cutscene(player.peer_id, Cutscenes.drowned(lost, raid), wake_on_shore)
	get_tree().create_timer(WAKE_LATEST).timeout.connect(wake_on_shore)


## Server only. After drowning: on the shore, dry, with nothing (or, after
## the raid's sea, already at the barracks).
func wake_on_shore() -> void:
	if not drowning or not is_inside_tree():
		return
	drowning = false
	if Regions.at(player.position).get("id", "") != "barracks":
		player.teleport(Coast.SHORE_SPAWN)


## Server only. The Dock Tradesman buys every log and lump of ore in your
## bag (design logs 0204, 0211). Returns how many items.
func sell_logs(trader: String) -> int:
	var logs := player.inventory.count_of(Gear.LOG)
	var ore := player.inventory.count_of(Gear.ORE)
	if logs + ore == 0:
		player.screen.tell(trader, "No logs? The isle's out west. Bring me some.")
		return 0
	var paid := 0
	var parts: Array[String] = []
	for entry: Array in [[Gear.LOG, logs, "log", "logs"], [Gear.ORE, ore, "ore", "ore"]]:
		var count: int = entry[1]
		if count == 0:
			continue
		for i in count:
			player.inventory.take_from_bag(entry[0])
		paid += count * int(Gear.GOODS[entry[0]].chits)
		parts.append("%d %s" % [count, entry[2] if count == 1 else entry[3]])
	player.stats.add_chits(paid)
	var market := get_tree().get_first_node_in_group(Market.GROUP) as Market
	if market != null:
		market.add_supply(logs)  # the dock's stock, for merchants (log 0205)
		market.add_ore_supply(ore)
	player.screen.tell(trader, "%s. That's %d chits. Spend them at the barracks." % [" and ".join(parts), paid])
	if logs > 0:
		player.quests.notify("sell", Gear.LOG)
	if ore > 0:
		player.quests.notify("sell", Gear.ORE)
	return logs + ore


## Owner side: a trade at the dock's market or your booth (design log
## 0205): "buy_chits", "buy_coins", "work", "collect" or "deliver" (see
## Market.trade).
func request_market(action: String, amount: int) -> void:
	_submit_market.rpc_id(1, action, amount)


@rpc("any_peer", "call_local", "reliable")
func _submit_market(action: String, amount: int) -> void:
	if not player.from_owner() or player.dead:
		return
	var panel := "booth" if action == "deliver" else "market"
	var market := get_tree().get_first_node_in_group(Market.GROUP) as Market
	if market == null or not Npc.near_role(player, panel):
		return
	var said := market.trade(player, action, amount)
	if said != "":
		player.screen.tell(Market.CLERK if panel == "booth" else Market.HARBOURMASTER, said)
	player.screen.show_market(panel, market.snapshot(player))


## Server only. The Blacksmith (log 0211) takes every lump of ore in your
## bag onto your account with him, since a bag can't hold the 25 the last
## upgrade needs. Returns how many.
func hand_over_ore(smith: String) -> int:
	var count := player.inventory.count_of(Gear.ORE)
	var room := PlayerStats.SMITH_ORE_MAX - player.stats.smith_ore
	count = mini(count, room)
	if count <= 0:
		return 0
	for i in count:
		player.inventory.take_from_bag(Gear.ORE)
	player.stats.smith_ore += count
	player.screen.tell(smith, "%d ore. I'll keep it for you: %d on account." % [count, player.stats.smith_ore])
	return count


## Owner side: the Blacksmith upgrades one piece of gear (log 0211): a bag
## slot, or a worn one at UPGRADE_WORN + its Gear.SLOTS index.
const UPGRADE_WORN := 100


func request_upgrade(where: int) -> void:
	_submit_upgrade.rpc_id(1, where)


@rpc("any_peer", "call_local", "reliable")
func _submit_upgrade(where: int) -> void:
	if not player.from_owner() or player.dead or not Npc.near_role(player, "smith"):
		return
	upgrade(where)


## Server only. Upgrades the piece at `where` one level, paying coins and
## ore. Returns the new item, or "" (and says why).
func upgrade(where: int) -> String:
	const SMITH := "The Blacksmith"
	var inventory := player.inventory
	var worn := where >= UPGRADE_WORN
	var index := where - UPGRADE_WORN if worn else where
	var list := inventory.equipped if worn else inventory.bag
	if index < 0 or index >= list.size() or not Gear.is_gear(list[index]):
		return ""
	var old := list[index]
	var better := Gear.upgraded(old)
	if better == "":
		player.screen.tell(SMITH, "That's +5. Nothing I could add would make it better.")
		return ""
	hand_over_ore(SMITH)  # any ore in the bag counts
	var cost: Dictionary = Gear.UPGRADE_COST[Gear.plus_of(better)]
	var stats := player.stats
	if stats.coins < int(cost.coins) or stats.smith_ore < int(cost.ore):
		var need := "%d coins" % cost.coins + (" and %d rare ore" % cost.ore if int(cost.ore) > 0 else "")
		player.screen.tell(SMITH, "+%d is %s. You've %d coins and %d ore with me." % [Gear.plus_of(better), need,
				stats.coins, stats.smith_ore])
		return ""
	stats.coins -= int(cost.coins)
	stats.smith_ore -= int(cost.ore)
	if worn:
		# Take the old piece's stats (and any set's) off, then put the new on.
		stats.apply_gains(Gear.set_bonus(inventory.equipped), -1)
		stats.apply_bonuses(old, -1)
		var new_equipped := inventory.equipped
		new_equipped[index] = better
		inventory.equipped = new_equipped
		stats.apply_bonuses(better, 1)
		stats.apply_gains(Gear.set_bonus(inventory.equipped), 1)
	else:
		var new_bag := inventory.bag
		new_bag[index] = better
		inventory.bag = new_bag
	var line := "There. %s." % Gear.item_name(better)
	if Gear.plus_of(better) >= Gear.MAX_UPGRADE:
		line = "There. %s: the finest work I've done. Wear it well." % Gear.item_name(better)
	player.screen.tell(SMITH, line)
	return better


## Owner side: buy the family's next strongroom chest (log 0212).
func request_buy_chest() -> void:
	_submit_buy_chest.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _submit_buy_chest() -> void:
	if not player.from_owner() or player.dead or not player.inventory.can_use_vault():
		return
	buy_chest()


## Server only. Adds a chest to the family's strongroom for coins; false
## (and says why) if it can't.
func buy_chest() -> bool:
	const KEEPER := "The Strongroom Keeper"
	var inventory := player.inventory
	var owned := inventory.vault_chests()
	if owned >= PlayerInventory.VAULT_PRICES.size():
		player.screen.tell(KEEPER, "That's every chest I have room for.")
		return false
	var price := PlayerInventory.VAULT_PRICES[owned]
	if player.stats.coins < price:
		player.screen.tell(KEEPER, "A chest is %d coins. You have %d." % [price, player.stats.coins])
		return false
	player.stats.coins -= price
	var grown := inventory.vault
	grown.resize(grown.size() + PlayerInventory.VAULT_CHEST_SLOTS)
	inventory.vault = grown
	player.screen.tell(KEEPER, "There. Chest %s is yours, and your heirs' after you." % ["one", "two", "three"][owned])
	return true


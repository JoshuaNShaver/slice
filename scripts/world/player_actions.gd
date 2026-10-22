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


## Owner side: learn an ability from the Quartermaster (design log 0086).
func request_learn(id: String) -> void:
	_submit_learn.rpc_id(1, id)


@rpc("any_peer", "call_local", "reliable")
func _submit_learn(id: String) -> void:
	if not player.from_owner() or player.dead:
		return
	var stats := player.stats
	if not Abilities.is_ability(id) or id in stats.abilities or not Npc.near_role(player, "quartermaster"):
		return
	var cost := Abilities.price(id)
	if stats.chits < cost:
		player.screen.tell("The Quartermaster", "That drill's %d chits. You have %d." % [cost, stats.chits])
		return
	stats.chits -= cost
	var learned := stats.abilities
	learned.append(id)
	stats.abilities = learned
	player.screen.tell("", "Learned %s: %s (%d energy)." % [Abilities.ability_name(id),
			Abilities.ALL[id].text, roundi(Abilities.ALL[id].cost)])


## Server only. Fell into the sea (design log 0201): the screen goes dark,
## everything in the bag is lost, and you wake on the shore.
func drown() -> void:
	if drowning or player.dead:
		return
	drowning = true
	var lost := 0
	for item in player.inventory.bag:
		if item != "":
			lost += 1
	player.inventory.bag = PlayerInventory.blank(PlayerInventory.BAG_SIZE)
	Net.play_cutscene(player.peer_id, Cutscenes.drowned(lost), wake_on_shore)
	get_tree().create_timer(WAKE_LATEST).timeout.connect(wake_on_shore)


## Server only. After drowning: on the shore, dry, with nothing.
func wake_on_shore() -> void:
	if not drowning or not is_inside_tree():
		return
	drowning = false
	player.teleport(Coast.SHORE_SPAWN)


## Server only. The Dock Tradesman buys every log in your bag (design log
## 0204). Returns how many.
func sell_logs(trader: String) -> int:
	var count := player.inventory.count_of(Gear.LOG)
	if count == 0:
		player.screen.tell(trader, "No logs? The isle's out west. Bring me some.")
		return 0
	for i in count:
		player.inventory.take_from_bag(Gear.LOG)
	var paid: int = count * int(Gear.GOODS[Gear.LOG].chits)
	player.stats.add_chits(paid)
	var market := get_tree().get_first_node_in_group(Market.GROUP) as Market
	if market != null:
		market.add_supply(count)  # the dock's stock, for merchants (log 0205)
	player.screen.tell(trader, "%d %s. That's %d chits. Spend them at the barracks." % [
			count, "log" if count == 1 else "logs", paid])
	player.quests.notify("sell", Gear.LOG)
	return count


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

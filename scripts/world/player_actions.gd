class_name PlayerActions
extends Node
## What a player asks of the world (PlayerShape's "Actions"): interact (E)
## with the nearest NPC, elevator or door (World.interact), take the
## General's orders, Ready up, buy and learn from the Quartermaster, marry.
## The owner asks (request_ methods); the server decides.

var player: PlayerShape


## Owner -> server: use whatever is nearest (an NPC, elevator or door).
@rpc("any_peer", "call_local", "reliable")
func _submit_interact() -> void:
	if not player.from_owner():
		return
	if not player.dead and not player.motion.riding():
		get_tree().call_group(World.GROUP, "interact", player)


## Server only. A priest marries you (design log 0030), using a certificate.
## False if you have none.
func marry() -> bool:
	var certificate := marriage_certificate()
	if player.dead or certificate == "":
		return false
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	player.inventory.take_from_bag(certificate)
	var heir := Family.roll_heir(player.sides, player.kind, player.apex, rng,
			certificate == Gear.BLESSED_CERTIFICATE)
	player.become_heir(heir)
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
	if stats.pay < cost:
		player.screen.tell("The Quartermaster", "That's %d pay. You have %d. Earn it first." % [cost, stats.pay])
		return
	if not player.inventory.add_to_bag(item):
		player.screen.tell("The Quartermaster", "Your bag's full, soldier.")
		return
	stats.pay -= cost


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
	if stats.pay < cost:
		player.screen.tell("The Quartermaster", "That drill's %d pay. You have %d." % [cost, stats.pay])
		return
	stats.pay -= cost
	var learned := stats.abilities
	learned.append(id)
	stats.abilities = learned
	player.screen.tell("", "Learned %s: %s (%d energy)." % [Abilities.ability_name(id),
			Abilities.ALL[id].text, roundi(Abilities.COST)])

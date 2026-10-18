class_name Missions
extends Node
## The General's missions (design logs 0067, 0070), run by the server.
##
## Taking orders for recon or an invasion starts a muster by the General:
## anyone else who takes the same orders within MUSTER_TIME joins the squad,
## and then everyone still in the barracks goes to the front. Special ops go
## alone, at once. Mission levels are a guide: anyone may go (log 0072).
##
## Each squad gets its own Mission (instanced), with soldiers on its side
## and the Colour Revolt to beat. Missions pay only XP (per kill) and, when
## every rebel is down, combatant pay. Leaving early, by the home key or
## otherwise, forfeits the pay. If the squad brought down a Revolt boss, the
## campaign is complete: each member is discharged with a marriage
## certificate (log 0067).

const MUSTER_TIME := 10.0  # s for others to join a squad
const RETURN_DELAY := 6.0  # s after victory before the squad goes back
const GRACE := 1.0  # s after deploying before leaving the field counts

var world: World

## mission type -> {"members": Array[int], "time": float}
var _musters := {}
## slot -> {"type", "node": Mission, "members": {peer id: true}, "foes": int,
## "boss": bool, "boss_down": bool, "done": bool, "grace": float,
## "spawned": Array[Enemy]}
var _active := {}
var _count := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## Server only. `player` took the General's orders.
func request(player: PlayerShape, mission_type: String) -> void:
	if not Mission.TYPES.has(mission_type) or _in_mission(player.peer_id):
		return
	var info: Dictionary = Mission.TYPES[mission_type]
	for other: String in _musters:
		_musters[other].members.erase(player.peer_id)
	if info.squad <= 1:
		_deploy(mission_type, [player.peer_id])
		return
	if not _musters.has(mission_type):
		_musters[mission_type] = {"members": [player.peer_id], "time": MUSTER_TIME}
		for p in _players_in_barracks():
			p.tell("The General", "A %s squad musters here. %d seconds to join." % [
					info.name.to_lower(), roundi(MUSTER_TIME)])
		return
	var muster: Dictionary = _musters[mission_type]
	if player.peer_id not in muster.members:
		muster.members.append(player.peer_id)
	player.tell("The General", "You're in the %s squad. Moving out in %d seconds." % [
			info.name.to_lower(), ceili(muster.time)])
	if muster.members.size() >= info.squad:
		_musters.erase(mission_type)
		_deploy(mission_type, muster.members)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	for mission_type: String in _musters.keys():
		var muster: Dictionary = _musters[mission_type]
		muster.time -= delta
		if muster.time <= 0.0:
			_musters.erase(mission_type)
			_deploy(mission_type, muster.members)
	for slot: int in _active.keys():
		_watch(slot, delta)


func _in_mission(peer_id: int) -> bool:
	for slot: int in _active:
		if _active[slot].members.has(peer_id):
			return true
	return false


func _players_in_barracks() -> Array[PlayerShape]:
	var out: Array[PlayerShape] = []
	for node in get_tree().get_nodes_in_group(PlayerShape.GROUP):
		var p := node as PlayerShape
		if p != null and Regions.at(p.position).get("id", "") == "barracks":
			out.append(p)
	return out


# --- Deploying ---------------------------------------------------------------

func _deploy(mission_type: String, member_ids: Array) -> void:
	var squad: Array[PlayerShape] = []
	for id: int in member_ids:
		var p := world.player(id)
		if p != null and Regions.at(p.position).get("id", "") == "barracks" and not _in_mission(id):
			squad.append(p)
	if squad.is_empty():
		return
	var slot := _free_slot()
	if slot < 0:
		for p in squad:
			p.tell("The General", "The front's crowded. Wait a little.")
		return
	var info: Dictionary = Mission.TYPES[mission_type]
	_count += 1
	var node: Mission = world.spawn_mission({
		"name": "Mission%d" % _count, "type": mission_type, "slot": slot, "seed": _rng.randi(),
	})
	var inst := {
		"type": mission_type, "node": node, "members": {}, "foes": 0, "boss": false,
		"boss_down": false, "done": false, "grace": GRACE, "spawned": [],
	}
	_active[slot] = inst
	for i in squad.size():
		var p := squad[i]
		inst.members[p.peer_id] = true
		p.teleport(node.ground_point(220.0 + i * 60.0, PlayerShape.RADIUS + 20.0))
		p.heal_full()
		p.tell("", info.brief)

	var best_luck := 0
	for p in squad:
		best_luck = maxi(best_luck, p.luck)
	for type: String in _revolt_for(mission_type, best_luck):
		var at := _rng.randf_range(0.42, 0.9) * node.width
		if Enemy.TYPES[type].get("boss", false):
			at = node.width - 260.0
			inst.boss = true
		_spawn(slot, type, at)
		inst.foes += 1
	for i in info.allies:
		_spawn(slot, "soldier", 320.0 + i * 70.0)


## Which Revolt fighters face this mission. A boss turns up by chance,
## which luck raises (design log 0049): the squad's luckiest member counts.
func _revolt_for(mission_type: String, luck: int) -> Array[String]:
	var out: Array[String] = []
	match mission_type:
		"recon":
			for i in _rng.randi_range(3, 5):
				out.append("rebel")
		"invasion":
			for i in _rng.randi_range(20, 24):
				out.append("agitator" if i % 3 == 2 else "rebel")
		"special_ops":
			for i in 5:
				out.append("bodyguard")
	var chance: float = Mission.TYPES[mission_type].boss
	if chance > 0.0 and _rng.randf() < Stats.lucky_chance(chance, luck):
		out.append("captain" if mission_type == "invasion" else "chromatistes")
	return out


func _spawn(slot: int, type: String, local_x: float) -> void:
	var inst: Dictionary = _active[slot]
	var node: Mission = inst.node
	var lift: float = Enemy.TYPES[type].radius + 12.0
	var enemy := world.spawn_enemy({
		"name": "%s_%d" % [node.name, inst.spawned.size()],
		"type": type,
		"pos": node.ground_point(local_x, lift),
		"room": Regions.mission_rect(slot),
	})
	inst.spawned.append(enemy)
	enemy.died.connect(_on_died.bind(slot), CONNECT_ONE_SHOT)


func _free_slot() -> int:
	for slot in Regions.MISSION_SLOTS:
		if not _active.has(slot):
			return slot
	return -1


# --- During a mission ----------------------------------------------------------

func _on_died(enemy: Enemy, slot: int) -> void:
	enemy.queue_free()  # deferred: this runs inside a physics callback
	if not _active.has(slot) or enemy.is_army():
		return
	world.reward_kill(enemy, false)  # missions pay XP, not loot (log 0067)
	var inst: Dictionary = _active[slot]
	if enemy.is_boss():
		inst.boss_down = true
	inst.foes -= 1
	if inst.foes <= 0 and not inst.done:
		_win.call_deferred(slot)


## Members who leave the field (home key, death, disconnecting) are out,
## with no pay. A mission with no one left is over.
func _watch(slot: int, delta: float) -> void:
	var inst: Dictionary = _active[slot]
	inst.grace -= delta
	if inst.done or inst.grace > 0.0:
		return
	var field := Regions.mission_rect(slot)
	for id: int in inst.members.keys():
		var p := world.player(id)
		if p == null or not field.has_point(p.position):
			inst.members.erase(id)
			if p != null:
				p.tell("The General", "You left the front. No pay for deserters.")
	if inst.members.is_empty():
		_close(slot)


func _win(slot: int) -> void:
	if not _active.has(slot):
		return
	var inst: Dictionary = _active[slot]
	inst.done = true
	var info: Dictionary = Mission.TYPES[inst.type]
	for id: int in inst.members:
		var p := world.player(id)
		if p == null:
			continue
		p.add_pay(info.pay)
		if inst.boss_down:
			# The campaign is won: an honourable discharge (design log 0067).
			if not p.add_to_bag(Gear.CERTIFICATE):
				world.drop_item(Gear.CERTIFICATE, id, p.position)
			p.tell("The General", "The Revolt's gentry is broken. Your discharge, soldier: a marriage certificate. +%d pay." % info.pay)
		else:
			p.tell("The General", "Mission complete. +%d pay. Back to the barracks." % info.pay)
	get_tree().create_timer(RETURN_DELAY).timeout.connect(_return_squad.bind(slot))


func _return_squad(slot: int) -> void:
	if not _active.has(slot):
		return
	var field := Regions.mission_rect(slot)
	var i := 0
	for id: int in _active[slot].members:
		var p := world.player(id)
		if p != null and field.has_point(p.position):
			p.teleport(Barracks.MUSTER + Vector2(i * 50.0, 0))
			i += 1
	_close(slot)


func _close(slot: int) -> void:
	var inst: Dictionary = _active[slot]
	for enemy: Variant in inst.spawned:  # untyped: some are already freed
		if is_instance_valid(enemy) and not (enemy as Node).is_queued_for_deletion():
			(enemy as Node).queue_free()
	if is_instance_valid(inst.node):
		inst.node.queue_free()
	_active.erase(slot)

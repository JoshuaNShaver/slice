class_name Missions
extends Node
## The General's missions (design logs 0067, 0070), run by the server.
##
## Taking orders for recon or an invasion starts a muster by the General:
## anyone else who takes the same orders within MUSTER_TIME joins the squad,
## and then everyone still in the barracks goes to the front. Special ops
## take two (log 0083). Mission levels are a guide: anyone may go (log 0072).
##
## Each squad gets its own Mission (instanced), with soldiers on its side
## and the Colour Revolt to beat. Missions pay only XP (per kill) and, when
## every rebel is down, chits (log 0204). Leaving early, by the home key or
## otherwise, forfeits the pay. If the squad brought down a Revolt boss, each
## member has a DISCHARGE_CHANCE (luck helps) that the General discharges
## them with a marriage certificate when they're back (logs 0067, 0092).
##
## Recon hides two chances (design logs 0088, 0089): a Painted Noble (double
## pay), or a half-strength Captain (five times the pay, and the discharge)
## with twice the rebels, a Gentleman and a Noble huddled round him. Neither
## is announced; the squad's soldier hints at it once you're there. For the
## Captain, a popup offers REPORT_TIME to report back instead, for double pay.
##
## While a muster or the return is counting down, each player in it sees the
## timer in a popup with a Ready button (design log 0081). A muster leaves
## once everyone in it is ready; after a victory, Ready sends you back at once.

const MUSTER_TIME := 10.0  # s for others to join a squad
const RETURN_DELAY := 6.0  # s after victory before the squad goes back
const GRACE := 1.0  # s after deploying before leaving the field counts
const HINT_DELAY := 3.0  # s after landing, and between, for the soldier's hints
const REPORT_TIME := 20.0  # s to report the Captain back instead (design log 0089)
const HUDDLE_SPREAD := 320.0  # px the huddle spreads round the Captain
## A boss win earns each member this chance (before luck) of a discharge with
## a marriage certificate, which the General gives back at the barracks (log 0092).
const DISCHARGE_CHANCE := 0.2
const GENERAL_DELAY := 0.6  # s after the return before the General speaks

## The recon soldier's hints that the stakes are higher (design log 0088).
const NOBLE_HINTS: Array[String] = [
	"See the six-sided one by the banners? That's no scout. That's gentry.",
	"A noble, out here in paint? The General will want to hear of this.",
	"Mind the many-sided one. The General pays well for his sort.",
]
const HUDDLE_HINTS: Array[String] = [
	"They're bunched up round him, gentry and all. They won't come out. We'd have to go in.",
	"Look at them close ranks. Nobody's chasing us today. Question is whether we go in.",
	"That's a guard, not a patrol. A pentagon, a hexagon, and twice the paint we were told.",
]
const BOSS_HINTS: Array[String] = [
	"That's a Captain's banner. He's hurt, but he's here. Bring him down and we all go home for good.",
	"A Captain of the Revolt, on a scouting run? Wounded, by the look of him. This is our chance.",
	"That's no scout at the back. A Captain. Half the man he was, but a Captain.",
]

var world: World

## mission type -> {"members": Array[int], "time": float, "ready": {peer id: true}}
var _musters := {}
## slot -> {"type", "node": Mission, "members": {peer id: true}, "foes": int,
## "boss": bool, "boss_down": bool, "done": bool, "grace": float,
## "spawned": Array[Enemy], "return_time": float, "pay_mult": int,
## "hints": Array[String] (the soldier's lines still to say), "hint_time": float,
## "offer_report": bool (the Captain's here: offer after the first hint),
## "report_time": float (s left to report back)}
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
	for other: String in _musters.keys():
		var old: Dictionary = _musters[other]
		if old.members.has(player.peer_id):
			old.members.erase(player.peer_id)
			old.ready.erase(player.peer_id)
			if old.members.is_empty():
				_musters.erase(other)
			else:
				_show_muster(other)
	player.screen.show_countdown("", 0.0, 0, 0, false)
	if info.squad <= 1:
		_deploy(mission_type, [player.peer_id])
		return
	if not _musters.has(mission_type):
		_musters[mission_type] = {"members": [player.peer_id], "time": MUSTER_TIME, "ready": {}}
		for p in _players_in_barracks():
			p.screen.tell("The General", "A %s squad musters here. %d seconds to join." % [
					info.name.to_lower(), roundi(MUSTER_TIME)])
		_show_muster(mission_type)
		return
	var muster: Dictionary = _musters[mission_type]
	if player.peer_id not in muster.members:
		muster.members.append(player.peer_id)
	player.screen.tell("The General", "You're in the %s squad. Moving out in %d seconds." % [
			info.name.to_lower(), ceili(muster.time)])
	if muster.members.size() >= info.squad:
		_musters.erase(mission_type)
		_deploy(mission_type, muster.members)
	else:
		_show_muster(mission_type)


## Server only. `player` pressed Ready in the countdown popup.
func mark_ready(player: PlayerShape) -> void:
	var id := player.peer_id
	for mission_type: String in _musters.keys():
		var muster: Dictionary = _musters[mission_type]
		if muster.members.has(id):
			muster.ready[id] = true
			if muster.ready.size() >= muster.members.size():
				_musters.erase(mission_type)
				_deploy(mission_type, muster.members)
			else:
				_show_muster(mission_type)
			return
	for slot: int in _active:
		var inst: Dictionary = _active[slot]
		if not inst.done and inst.report_time > 0.0 and inst.members.has(id):
			# Reporting the Captain back (design log 0089).
			var info: Dictionary = Mission.TYPES[inst.type]
			var pay: int = info.pay * info.report_pay
			player.stats.add_chits(pay)
			player.screen.show_countdown("", 0.0, 0, 0, false)
			player.screen.tell("The General", "A Captain, out on recon? Good eyes, soldier. +%d chits." % pay)
			player.teleport(Barracks.MUSTER)
			inst.members.erase(id)
			if inst.members.is_empty():
				_close(slot)
			return
		if inst.done and inst.members.has(id):
			# Going back early still gets the General's debrief.
			player.screen.show_countdown("", 0.0, 0, 0, false)
			player.teleport(Barracks.MUSTER)
			if inst.boss_down:
				_schedule_debrief(id)
			inst.members.erase(id)
			if inst.members.is_empty():
				_close(slot)
			return


## Sends the muster's countdown to everyone in it (or hides it, once it's gone).
func _show_muster(mission_type: String) -> void:
	var muster: Dictionary = _musters[mission_type]
	var title := "%s squad musters" % Mission.TYPES[mission_type].name
	for id: int in muster.members:
		var p := world.player(id)
		if p != null:
			p.screen.show_countdown(title, muster.time, muster.ready.size(), muster.members.size(),
					muster.ready.has(id))

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
		if p != null:
			p.screen.show_countdown("", 0.0, 0, 0, false)
		if p != null and Regions.at(p.position).get("id", "") == "barracks" and not _in_mission(id):
			squad.append(p)
	if squad.is_empty():
		return
	var slot := _free_slot()
	if slot < 0:
		for p in squad:
			p.screen.tell("The General", "The front's crowded. Wait a little.")
		return
	var info: Dictionary = Mission.TYPES[mission_type]
	_count += 1
	var node: Mission = world.spawn_mission({
		"name": "Mission%d" % _count, "type": mission_type, "slot": slot, "seed": _rng.randi(),
	})
	var inst := {
		"type": mission_type, "node": node, "members": {}, "foes": 0, "boss": false,
		"boss_down": false, "done": false, "grace": GRACE, "spawned": [], "return_time": 0.0,
		"pay_mult": 1, "hints": [], "hint_time": HINT_DELAY, "offer_report": false, "report_time": 0.0,
	}
	_active[slot] = inst
	for i in squad.size():
		var p := squad[i]
		inst.members[p.peer_id] = true
		p.teleport(node.ground_point(220.0 + i * 60.0, PlayerShape.RADIUS + 20.0))
		p.combat.heal_full()
		p.screen.tell("", info.brief)

	var best_luck := 0
	for p in squad:
		best_luck = maxi(best_luck, p.stats.luck)
	var revolt := _revolt_for(mission_type, best_luck)
	# Bosses first, so a huddle has someone to huddle round.
	var is_boss := func(type: String) -> bool: return Enemy.TYPES[type].get("boss", false)
	var ordered: Array[String] = []
	var others: Array[String] = []
	for type in revolt:
		(ordered if is_boss.call(type) else others).append(type)
	ordered.append_array(others)
	# Recon's Captain (log 0089): everyone huddles round him and won't chase.
	var huddle: bool = info.has("boss_pay") and not ordered.is_empty() and is_boss.call(ordered[0])
	var bosses := 0
	var huddled_round: Enemy = null
	for type: String in ordered:
		var at := _rng.randf_range(0.42, 0.9) * node.width
		var offset := 0.0
		var strength := 1.0
		# Invasion's gentry (log 0091): buffed, and they use the Revolt's moves.
		var gentry: bool = info.has("gentry") and type in ["gentleman", "noble"]
		if is_boss.call(type):
			at = node.width - 260.0 - bosses * 240.0  # a second boss stands guard in front
			bosses += 1
			inst.boss = true
			strength = info.get("boss_strength", 1.0)
		elif huddle:
			offset = _rng.randf_range(-HUDDLE_SPREAD, HUDDLE_SPREAD * 0.5)
			at = node.width - 260.0 + offset
		elif gentry:
			at = _rng.randf_range(0.7, 0.95) * node.width  # about the camp
			strength = info.gentry_strength
		elif type == "noble":
			at = node.width - 420.0  # among the camp's banners
		var enemy := _spawn(slot, type, at, strength, gentry)
		inst.foes += 1
		if huddle and is_boss.call(type):
			huddled_round = enemy
			enemy.leash = Enemy.BOSS_LEASH
		elif huddle:
			enemy.guard = huddled_round
			enemy.guard_offset = offset
			enemy.leash = Enemy.GUARD_REACH
	if huddle:
		inst.pay_mult = info.boss_pay
		inst.hints.append(BOSS_HINTS.pick_random())
		inst.hints.append(HUDDLE_HINTS.pick_random())
		inst.offer_report = true
	elif "noble" in ordered and info.has("noble_pay"):
		inst.pay_mult = info.noble_pay
		inst.hints.append(NOBLE_HINTS.pick_random())
	for i in info.allies:
		var soldier := _spawn(slot, "soldier", 320.0 + i * 70.0)
		# Recon: stays close, swinging past you (log 0078). Invasion: hunts the Revolt (log 0079).
		soldier.role = {"recon": "orbit", "invasion": "seek"}.get(mission_type, "follow")


## Which Revolt fighters face this mission. A boss turns up by chance,
## which luck raises (design log 0049): the squad's luckiest member counts.
func _revolt_for(mission_type: String, luck: int) -> Array[String]:
	var out: Array[String] = []
	var info: Dictionary = Mission.TYPES[mission_type]
	match mission_type:
		"recon":
			# The Captain (log 0089): twice the rebels, and his gentry with him.
			var captain := _rng.randf() < Stats.lucky_chance(info.boss, luck)
			for i in _rng.randi_range(3, 5) * (2 if captain else 1):
				out.append("rebel")
			if captain:
				out.append_array(["gentleman", "noble", info.boss_type])
			elif _rng.randf() < Stats.lucky_chance(info.noble, luck):
				out.append("noble")
			return out
		"invasion":
			for i in _rng.randi_range(20, 24):
				out.append("agitator" if i % 3 == 2 else "rebel")
			for i in _rng.randi_range(info.gentry.x, info.gentry.y):
				out.append(["gentleman", "noble"].pick_random())
		"special_ops":
			for i in 5:
				out.append("bodyguard")
	var chance: float = info.boss
	if chance > 0.0 and _rng.randf() < Stats.lucky_chance(chance, luck):
		out.append(info.boss_type)
	if mission_type == "special_ops":
		out.append("captain")  # Chromatistes' guard: two bosses (log 0083)
	return out


func _spawn(slot: int, type: String, local_x: float, strength := 1.0, moves := false) -> Enemy:
	var inst: Dictionary = _active[slot]
	var node: Mission = inst.node
	var lift: float = Enemy.TYPES[type].radius + 12.0
	var enemy := world.spawn_enemy({
		"name": "%s_%d" % [node.name, inst.spawned.size()],
		"type": type,
		"pos": node.ground_point(local_x, lift),
		"room": Regions.mission_rect(slot),
		"strength": strength,
		"moves": moves,
	})
	inst.spawned.append(enemy)
	enemy.died.connect(_on_died.bind(slot), CONNECT_ONE_SHOT)
	return enemy


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
	if inst.done:
		inst.return_time -= delta
		if inst.return_time <= 0.0:
			_return_squad(slot)
		return
	_hint(inst, delta)
	if inst.report_time > 0.0:
		inst.report_time -= delta
		if inst.report_time <= 0.0:
			_offer_report(inst, false)
	if inst.grace > 0.0:
		return
	var field := Regions.mission_rect(slot)
	for id: int in inst.members.keys():
		var p := world.player(id)
		if p == null or not field.has_point(p.position):
			inst.members.erase(id)
			if p != null:
				p.screen.tell("The General", "You left the front. No chits for deserters.")
	if inst.members.is_empty():
		_close(slot)


## The soldier's hints, one every HINT_DELAY, to everyone still on the field.
func _hint(inst: Dictionary, delta: float) -> void:
	if inst.hints.is_empty():
		return
	inst.hint_time -= delta
	if inst.hint_time > 0.0:
		return
	inst.hint_time = HINT_DELAY
	var line: String = inst.hints.pop_front()
	for id: int in inst.members:
		var p := world.player(id)
		if p != null:
			p.screen.tell(Enemy.TYPES.soldier.name, line)
	if inst.offer_report:
		inst.offer_report = false
		inst.report_time = REPORT_TIME
		_offer_report(inst, true)


## Shows (or hides) the popup offering to report the Captain back instead
## of fighting him (design log 0089).
func _offer_report(inst: Dictionary, show: bool) -> void:
	var info: Dictionary = Mission.TYPES[inst.type]
	for id: int in inst.members:
		var p := world.player(id)
		if p == null:
			continue
		if show:
			p.screen.show_countdown("A Captain! Report back?", REPORT_TIME, 0, 0, false,
					"Report back (+%d chits)" % (info.pay * info.report_pay))
		else:
			p.screen.show_countdown("", 0.0, 0, 0, false)


func _win(slot: int) -> void:
	if not _active.has(slot):
		return
	var inst: Dictionary = _active[slot]
	inst.done = true
	var info: Dictionary = Mission.TYPES[inst.type]
	var pay: int = info.pay * inst.pay_mult
	for id: int in inst.members:
		var p := world.player(id)
		if p == null:
			continue
		p.stats.add_chits(pay)
		if inst.boss_down:
			p.screen.tell("The General", "Their gentry is down. +%d chits. Report to me at the barracks." % pay)
		elif inst.pay_mult > 1:
			p.screen.tell("The General", "More than scouts out there, I hear. Well done. +%d chits." % pay)
		else:
			p.screen.tell("The General", "Mission complete. +%d chits. Back to the barracks." % pay)
		p.screen.show_countdown("Back to the barracks", RETURN_DELAY, 0, 0, false)
	inst.return_time = RETURN_DELAY


func _return_squad(slot: int) -> void:
	if not _active.has(slot):
		return
	var field := Regions.mission_rect(slot)
	var boss_down: bool = _active[slot].boss_down
	var i := 0
	for id: int in _active[slot].members:
		var p := world.player(id)
		if p == null:
			continue
		if field.has_point(p.position):
			p.screen.show_countdown("", 0.0, 0, 0, false)
			p.teleport(Barracks.MUSTER + Vector2(i * 50.0, 0))
			i += 1
		if boss_down:
			_schedule_debrief(id)
	_close(slot)


## After the teleport, so the General is near enough to be seen speaking.
func _schedule_debrief(id: int) -> void:
	get_tree().create_timer(GENERAL_DELAY).timeout.connect(_debrief.bind(id))


## A boss win (design log 0092): the General rolls each member's discharge,
## like a promotion, once they're back. Rolled now, with today's luck.
func _debrief(id: int) -> void:
	var p := world.player(id)
	if p == null:
		return
	if _rng.randf() < Stats.lucky_chance(DISCHARGE_CHANCE, p.stats.luck):
		# The campaign is won: an honourable discharge (design log 0067).
		if not p.inventory.add_to_bag(Gear.CERTIFICATE):
			world.drop_item(Gear.CERTIFICATE, id, p.position)
		p.screen.tell("The General", "You've earned this, soldier. An honourable discharge: a marriage certificate.")
	else:
		p.screen.tell("The General", "Good work out there. Not your discharge yet. The Revolt has more gentry; I'll call on you.")


func _close(slot: int) -> void:
	var inst: Dictionary = _active[slot]
	for enemy: Variant in inst.spawned:  # untyped: some are already freed
		if is_instance_valid(enemy) and not (enemy as Node).is_queued_for_deletion():
			(enemy as Node).queue_free()
	if is_instance_valid(inst.node):
		inst.node.queue_free()
	_active.erase(slot)

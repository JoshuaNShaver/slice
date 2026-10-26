extends RefCounted
## Run by test_ranger.gd: ranger school (design log 0245) step by step, the
## exam's pit, the camp's throwing recruits, the ranger quartermaster and
## rations (log 0246), and who may wear ranger gear (log 0241). A bare world
## (terrain, the camp, a stand-in for World), so nothing is saved to user://.

const SERGEANT := BootcampQuest.SERGEANT
const INSTRUCTOR := RangerCamp.INSTRUCTOR
const HEROLDT := RangerSchoolQuest.HEROLDT

var tree: SceneTree
var _fails := 0
var _root: Node2D
var _scenes: Array[Dictionary] = []


func run() -> int:
	_root = Node2D.new()
	_root.name = "TestWorld"
	_root.set_script(_stand_in_world())
	_root.add_to_group(World.GROUP)
	tree.root.add_child(_root)
	_root.add_child(CenterTerrain.new())
	_root.add_child(Barracks.new())
	_root.add_child(RangerCamp.new())
	for data: Dictionary in RangerCamp.npcs():
		_root.add_child(Npc.create(data))
	var projectiles := Projectiles.new()
	_root.add_child(projectiles)
	Net.cutscene_started.connect(func(scene: Dictionary) -> void: _scenes.append(scene))
	var bootcamp_done := Quests.sanitize({"bootcamp": {"step": 99}})

	# Who's called: a 50° triangle at 20, through bootcamp. Not a 45°.
	var blunt := _spawn(2, 45, 19, bootcamp_done)
	var p := _spawn(1, 50, 19, bootcamp_done)
	Net.accounts.find_player = func(id: int) -> PlayerShape: return p if id == p.peer_id else null
	await _steps(2)
	_check(not p.quests.has_started(RangerSchoolQuest.ID), "not before 20")
	p.inventory.add_to_bag(Gear.item("points", Gear.SCOUT))
	p.inventory._submit_equip(p.inventory.bag.find(Gear.item("points", Gear.SCOUT)))
	_check(p.inventory.worn("points") == "", "untrained can't wear ranger gear")
	for who in [p, blunt]:
		who.stats.add_xp(Stats.xp_to_next(19))
	await _steps(2)
	_check(p.stats.level == 20 and p.quests.has_started(RangerSchoolQuest.ID), "called at 20")
	_check(not blunt.quests.has_started(RangerSchoolQuest.ID), "not a 45° triangle")
	_check(p.quests.tracker.get("talk_to") == SERGEANT, "sent to the Sergeant")
	_check(not RangerCamp.admits(p), "the island's closed before training")
	blunt.free()

	# Selected, hooded, and put in the exam.
	_check(p.quests.talk(SERGEANT) and _last_act() == "ranger_selected", "selected")
	Net._cutscene_done()
	await _steps(3)
	_check(_step(p) == 1 and Regions.exam_slot_at(p.position) == 0, "taken to the exam")
	var exam := tree.get_first_node_in_group(RangerExam.GROUP) as RangerExam
	_check(exam != null and exam.owner_peer == p.peer_id, "your own course")
	var origin := Regions.exam_origin(0)
	await _steps(3)
	_check(exam != null and is_instance_valid(exam.boat), "the Heroldt's boat waits")
	p.motion.teleport(origin + Vector2(1000, RangerExam.WATER_Y + 40.0))
	await _steps(4)
	_check(p.position.distance_to(RangerExam.start_of(0)) < 60.0, "the water sends you back")
	_check(not p.actions.drowning, "the exam's water doesn't drown you")
	_check(Regions.at(p.position).get("id") == "exam", "the exam is a place")

	# Gone home mid-exam (the home key): the course goes, and the Sergeant
	# sends you back to a fresh one.
	p.motion._submit_home()
	await _steps(int(RangerExam.AWAY_LIMIT * Engine.physics_ticks_per_second) + 10)
	_check(tree.get_first_node_in_group(RangerExam.GROUP) == null and Regions.exam_slot_at(p.position) < 0,
			"home from the exam")
	_check(p.quests.talk(SERGEANT), "the Sergeant takes you back")
	await _steps(3)
	_check(_step(p) == 1 and Regions.exam_slot_at(p.position) == 0, "back in the exam")

	# The leap of faith: roll off the top ledge's end, down past the screen,
	# and land in the Heroldt's boat (or get hauled into it).
	exam = tree.get_first_node_in_group(RangerExam.GROUP) as RangerExam
	await _steps(3)
	var boat := exam.boat
	_check(is_instance_valid(boat) and boat.boatman == HEROLDT, "a fresh course, with his boat")
	p.motion.teleport(origin + Vector2(5380, -790))
	await _steps(3)
	p.motion._submit_move(1.0)
	var aboard := false
	for i in 300:
		await tree.physics_frame
		if exam.aboard(p):
			aboard = true
			break
	p.motion._submit_move(0.0)
	_check(aboard, "the leap lands in his boat")
	print("RESULT leap boat=%s you=%s" % [boat.position - origin, p.position - origin])
	await _steps(30)
	_check(boat.prompt_for(p) != "", "he'll row when spoken to")
	boat.interact(p)
	var through := false
	for i in 900:
		await tree.physics_frame
		if _step(p) == 2:
			through = true
			break
	_check(through, "rowed out through the pass")
	print("RESULT pass boat=%s" % [boat.position - origin if is_instance_valid(boat) else Vector2.ZERO])
	await _steps(3)
	_check(_step(p) == 2 and Regions.at(p.position).get("id") == "camp", "on to the island")
	_check(RangerCamp.admits(p), "the island lets you in once training")
	await _steps(int(RangerExam.AWAY_LIMIT * Engine.physics_ticks_per_second) + 10)
	_check(tree.get_first_node_in_group(RangerExam.GROUP) == null, "the course goes once you've left")

	# Tips, worn; the wild shapes; the recruits.
	p.quests.talk(INSTRUCTOR)
	_check(_last_act() == "ranger_tips", "the tips cutscene")
	Net._cutscene_done()
	_check(p.inventory.count_of(RangerSchoolQuest.TIPS) >= 1, "tips given")
	p.inventory._submit_equip(p.inventory.bag.find(RangerSchoolQuest.TIPS))
	p.quests._submit_report("open", "character")
	_check(p.inventory.worn("points") == RangerSchoolQuest.TIPS and _step(p) == 4, "tips worn")
	p.quests.talk(INSTRUCTOR)
	for i in 5:
		p.quests.notify("kill", "dummy")
	_check(_step(p) == 6, "five wild shapes")
	p.quests.talk(INSTRUCTOR)
	for i in 5:
		p.quests.notify("kill", "ranger_recruit")
	_check(_step(p) == 8, "five recruits")

	# The bout: four hits lose it.
	p.quests.talk(INSTRUCTOR)
	_check(_last_act() == "ranger_heroldt", "the Heroldt's bout is set")
	Net._cutscene_done()
	await _steps(2)
	var edric := _enemy("edric")
	_check(edric != null and edric.owner_peer == p.peer_id, "he waits in the yard")
	for i in 3:
		edric.hits_landed = i + 1
		edric.struck.emit(edric, p)
	await _steps(2)
	_check(_enemy("edric") != null, "three hits aren't enough")
	edric.hits_landed = 4
	edric.struck.emit(edric, p)
	await _steps(2)
	_check(_last_act() == "ranger_bout_lost" and _enemy("edric") == null, "the fourth loses")
	Net._cutscene_done()
	await _steps(2)
	_check(p.quests.is_done(RangerSchoolQuest.ID) and RangerCamp.admits(p), "a ranger")

	# A recruit keeps its distance and throws; its tips stop at 1 health.
	p.motion.teleport(RangerCamp.ORIGIN + Vector2(300, -40))
	await _steps(3)
	p.stats.hp = p.stats.max_hp
	var recruit := _root.spawn_enemy({"name": "R", "type": "ranger_recruit", "room": RangerCamp.YARD,
			"pos": RangerCamp.ORIGIN + Vector2(800, -40)}) as Enemy
	var thrown := false
	for i in 400:
		await tree.physics_frame
		thrown = thrown or projectiles.count() > 0
	_check(thrown, "recruits throw")
	_check(p.stats.hp < p.stats.max_hp and p.stats.hp >= 1, "their tips hurt, not kill")
	print("RESULT recruit hp=%d/%d gap=%.0f" % [p.stats.hp, p.stats.max_hp, recruit.position.distance_to(p.position)])
	recruit.queue_free()

	# Every panel an NPC opens stays open while you're by that NPC: the
	# world closes a panel only when no NPC with its role is near
	# (World.panel_role). The ranger stores once closed at once.
	for role: String in {"general": "orders", "quartermaster": "shop", "ranger_quartermaster": "ranger_shop",
			"vault": "vault", "smith": "smith", "market": "market", "booth": "booth"}:
		var panel: String = {"general": "orders", "quartermaster": "shop", "ranger_quartermaster": "ranger_shop"}.get(role, role)
		_check(World.panel_role(panel) == role, "the %s panel belongs to the %s" % [panel, role])

	# The ranger quartermaster: Scout for chits, the rest and rations for coins.
	p.motion.teleport(RangerCamp.ORIGIN + Vector2(-1000, -40))
	await _steps(3)
	p.stats.chits = 150
	p.stats.coins = 700
	p.actions._submit_ranger_buy(Gear.item("plating", Gear.SCOUT))
	_check(p.stats.chits == 50 and p.inventory.count_of(Gear.item("plating", Gear.SCOUT)) == 1, "Scout for chits")
	p.actions._submit_ranger_buy(Gear.item("plating", Gear.SCOUT + 1))
	_check(p.stats.coins == 550, "Tracker for coins")
	p.actions._submit_ranger_buy(Gear.item("plating", Gear.SCOUT + 4))
	_check(p.stats.coins == 550, "can't afford Ranger plating")
	p.actions._submit_buy(Gear.item("plating", Gear.SCOUT))
	_check(p.stats.chits == 50, "the army's Quartermaster doesn't sell it")
	for i in 3:
		p.actions._submit_ranger_buy(Gear.RATION)
	_check(p.inventory.count_of(Gear.rations(3)) == 1 and p.stats.coins == 550 - 3 * Gear.RATION_COINS,
			"rations stack in one slot")
	p.stats.hp = p.stats.max_hp / 2
	p.inventory._submit_eat(p.inventory.bag.find(Gear.rations(3)))
	_check(p.inventory.count_of(Gear.rations(2)) == 1, "eating takes one off the stack")
	p.stats.coins = 600
	p.actions._submit_learn("volley")
	_check("volley" in p.stats.abilities and p.stats.coins == 0, "volley for coins")
	_check(p.stats.ability_slots[Abilities.UP] == "volley" or p.stats.ability_slots[Abilities.UP] != "",
			"equipped once learned")
	p.actions._submit_learn("nose_dive")
	_check("nose_dive" not in p.stats.abilities, "melee drills only at the Quartermaster")

	# Camouflage (log 0254): ranger pigment, in the stores; a ranger set needs
	# it, an army set still doesn't.
	p.stats.chits = 100
	p.actions._submit_ranger_buy(Gear.item("pigment", Gear.SCOUT))
	_check(p.inventory.count_of(Gear.item("pigment", Gear.SCOUT)) == 1 and p.stats.chits == 0, "Scout camouflage for chits")
	_check(Gear.item_name(Gear.item("pigment", Gear.SCOUT)) == "Scout camouflage", "it's called camouflage")
	_check(Gear.item("pigment", Gear.SCOUT) in Gear.shop_stock("ranger"), "the stores sell it")
	_check(not Gear.item("pigment", Gear.SCOUT) in Gear.shop_stock(), "the Quartermaster doesn't")
	var four := PackedStringArray()
	var five := PackedStringArray()
	var army := PackedStringArray()
	for slot in Gear.SLOTS:
		five.append(Gear.item(slot, Gear.SCOUT))
		four.append("" if slot == "pigment" else Gear.item(slot, Gear.SCOUT))
		army.append("" if slot == "pigment" else Gear.item(slot, Gear.REGIMENTAL))
	_check(Gear.set_tier(four) == 0 and Gear.set_tier(five) == Gear.SCOUT, "a ranger set needs its camouflage")
	_check(Gear.set_tier(army) == Gear.REGIMENTAL, "an army set still doesn't")
	_check(not Gear.is_item(Gear.item("pigment", Gear.REGIMENTAL)), "still no army pigment")

	# Camouflage hides you: enemies see you only from closer, until you strike.
	p.motion.teleport(RangerCamp.ORIGIN + Vector2(300, -40))
	await _steps(3)
	var watcher := _root.spawn_enemy({"name": "W", "type": "ranger_recruit", "room": RangerCamp.YARD,
			"pos": p.position + Vector2(500, -20)}) as Enemy
	p.combat._since_combat = INF
	await _steps(2)
	_check(watcher._nearest_target() == p, "seen at 500 px without camouflage")
	p.inventory.add_to_bag(Gear.item("pigment", Gear.RANGER))
	p.inventory._submit_equip(p.inventory.bag.find(Gear.item("pigment", Gear.RANGER)))
	_check(p.stealth() > 0.3, "Ranger camouflage hides you")
	_check(watcher._nearest_target() == null, "unseen at 500 px with it")
	p.combat.note_combat()
	_check(p.stealth() == 0.0 and watcher._nearest_target() == p, "striking gives you away")
	watcher.queue_free()

	# Saves: rations survive the round trip.
	var saved := p.progress()
	var clean := PlayerShape.sanitize_progress(JSON.parse_string(JSON.stringify(saved)))
	_check(Gear.rations(2) in clean.bag, "rations saved")

	Net.accounts.find_player = Callable()
	print("RANGER TEST: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	return _fails


func _step(p: PlayerShape) -> int:
	return int(p.quests.state_of(RangerSchoolQuest.ID).get("step", -1))


func _last_act() -> String:
	return "" if _scenes.is_empty() else str(_scenes[-1].acts[0].id)


func _enemy(type: String) -> Enemy:
	for node in tree.get_nodes_in_group(Enemy.GROUP):
		var e := node as Enemy
		if e.type == type and not e.is_queued_for_deletion():
			return e
	return null


## Just enough of World for quests, with World's travel and exams.
func _stand_in_world() -> GDScript:
	var script := GDScript.new()
	script.source_code = """extends Node2D
func spawn_enemy(data: Dictionary) -> Enemy:
	var e := Enemy.create(data)
	add_child(e)
	return e
func drop_item(_item: String, _owner_id: int, _pos: Vector2) -> void:
	pass
func reward_kill(_enemy: Enemy, _drops := true) -> void:
	pass
func show_damage(_pos: Vector2, _amount: int, _kind: String) -> void:
	pass
func spawn_boat(data: Dictionary) -> Boat:
	var named := data.duplicate()
	named.name = "B%d" % get_child_count()
	var b := Boat.create(named)
	add_child(b)
	return b
func travel(who: PlayerShape, where: String) -> bool:
	match where:
		"exam":
			if get_tree().get_first_node_in_group(RangerExam.GROUP) == null:
				add_child(RangerExam.create({"name": "X0", "slot": 0, "owner": who.peer_id}))
			who.motion.teleport(RangerExam.start_of(0))
		"camp":
			who.motion.teleport(RangerCamp.SPAWN)
	return true
"""
	script.reload()
	return script


func _spawn(id: int, apex: int, level: int, quests: Dictionary) -> PlayerShape:
	var p := PlayerShape.create({"id": id, "family": "Test%d" % id, "sides": 3, "kind": "isosceles",
			"apex": apex, "luck": 0, "generation": 1, "chest": [], "quests": quests,
			"progress": PlayerShape.sanitize_progress({"level": level, "chits": 0,
				"stats": {"vigor": 20, "mettle": 20, "force": 20, "torque": 20}}),
			"pos": CenterTerrain.SPAWN_POINT})
	_root.add_child(p)
	p.quests.lead_pace = 0.0
	return p


func _steps(n: int) -> void:
	for i in n:
		await tree.physics_frame


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL " + what)

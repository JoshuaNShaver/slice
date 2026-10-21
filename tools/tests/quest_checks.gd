extends RefCounted
## Run by test_quests.gd. A bare world (terrain and a stand-in for World
## that spawns bouts), so nothing is saved to user://.

const SERGEANT := "The Drill Sergeant"

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
	Net.cutscene_started.connect(func(scene: Dictionary) -> void: _scenes.append(scene))

	var p := _spawn(1, {})
	Net.accounts.find_player = func(id: int) -> PlayerShape: return p if id == p.peer_id else null
	await _steps(2)

	# A birth starts it, and the Priest's words follow the cutscene.
	var scene := p.quests.after_birth(Cutscenes.founding({"family": "Test1", "sides": 3, "kind": "isosceles", "apex": 40}),
			{"kind": "isosceles"})
	_check(p.quests.has_started("bootcamp"), "a birth starts bootcamp")
	_check((scene.wake as Array).any(func(l: Variant) -> bool: return l is Array and l[0] == "The Priest"), "the Priest sends you on")
	_check(p.quests.tracker.get("talk_to") == SERGEANT, "the tracker points at the Sergeant")
	var irregular := _spawn(2, {})
	irregular.quests.after_birth({"acts": []}, {"kind": "irregular"})
	_check(not irregular.quests.has_started("bootcamp"), "not for an irregular")

	# The rundown cutscene, then the dummies (talking early just nags).
	_check(p.quests.talk(SERGEANT), "reporting is a quest's")
	_check(_last_act() == "bootcamp_rundown", "the rundown plays")
	Net._cutscene_done()
	_check(p.quests.talk(SERGEANT) and _step(p) == 1, "the Sergeant nags until it's done")
	_check(not p.quests.talk("The Quartermaster"), "others talk as usual")
	for i in 5:
		p.quests.notify("kill", "dummy")
	p.quests.notify("kill", "sparring")  # not counted yet
	_check(_step(p) == 2, "five dummies")
	p.quests.talk(SERGEANT)
	for i in 5:
		p.quests.notify("kill", "sparring")
	_check(_step(p) == 4, "five recruits")

	# Armor: given once its cutscene ends, then opened and worn.
	p.quests.talk(SERGEANT)
	_check(_last_act() == "bootcamp_leather" and p.inventory.count_of("plating_5") == 0, "leather cutscene first")
	Net._cutscene_done()
	_check(p.inventory.count_of("plating_5") == 1, "leather plating given after")
	p.inventory._submit_equip(p.inventory.bag.find("plating_5"))
	_check(_step(p) == 5, "wearing it isn't enough yet")
	p.quests._submit_report("open", "character")
	_check(_step(p) == 6, "open the sheet and wear it")
	p.quests._submit_report("open", "bag")  # not something a client may report
	_check(_step(p) == 6, "unknown reports ignored")

	# Darren: introduced, then a bout only you fight.
	p.quests.talk(SERGEANT)
	_check(_last_act() == "bootcamp_darren" and _darren() == null, "Darren's cutscene before the bout")
	Net._cutscene_done()
	var darren := _darren()
	_check(darren != null and darren.owner_peer == p.peer_id, "Darren waits for you")
	_check(darren != null and not darren.players_can_hit(irregular.peer_id) and darren.players_can_hit(p.peer_id),
			"only you can hit him")
	_check(darren != null and not darren._is_foe(irregular), "he fights only you")
	p.stats.hp = p.stats.max_hp
	_check(p.combat.take_hit(50.0, Vector2.ZERO, false, 2) and p.stats.hp == 2, "his opening leaves you at 2")
	darren.hits_landed = 1
	darren.struck.emit(darren, p)
	darren.hits_landed = 2
	darren.struck.emit(darren, p)
	await _steps(2)
	_check(_last_act() == "bootcamp_bout_lost" and _darren() == null, "a second hit loses the bout")
	Net._cutscene_done()
	_check(p.quests.is_done("bootcamp") and p.stats.hp == p.stats.max_hp, "done, and healed")
	_check(p.quests.tracker.is_empty(), "nothing left to track")
	_check(not p.quests.talk(SERGEANT), "the Sergeant talks as usual after")

	# Saved mid-bout: the bout comes back, and winning it ends the quest.
	_check(not PlayerSave.progress(p).has("quests") and p.quests.save_data().bootcamp.step == 8,
			"kept with the account, not the family")
	p.free()  # offline, only peer 1 can be sent a cutscene
	await _steps(1)
	var winner := _spawn(1, PlayerShape.sanitize_progress({"level": 3, "stats": {}}),
			Quests.sanitize({"bootcamp": {"step": 7, "counts": [0]}}))
	Net.accounts.find_player = func(id: int) -> PlayerShape: return winner if id == winner.peer_id else null
	await _steps(2)
	darren = _darren()
	_check(darren != null and darren.owner_peer == winner.peer_id, "a loaded bout brings Darren back")
	darren.contributors[winner.peer_id] = true
	darren.died.emit(darren)
	await _steps(2)
	_check(_last_act() == "bootcamp_bout_won", "bringing him down wins")
	Net._cutscene_done()
	_check(winner.quests.is_done("bootcamp"), "won, and done")

	# An irregular heir can't reach the barracks: the quest waits for a
	# regular one (it's the player's, log 0183).
	winner.free()
	await _steps(1)
	var waiting := _spawn(1, {}, Quests.sanitize({"bootcamp": {"step": 7, "counts": [0]}}))
	await _steps(2)
	waiting.become_heir({"sides": 3, "kind": "irregular", "apex": 45, "luck": 20})
	await _steps(2)
	_check(waiting.quests.tracker.is_empty() and _darren() == null, "waits while irregular")
	waiting.become_heir({"sides": 3, "kind": "isosceles", "apex": 50, "luck": 0})
	await _steps(2)
	_check(not waiting.quests.tracker.is_empty() and _darren() != null, "back for a regular heir")

	# A save from outside is kept to what play could produce.
	var clean := Quests.sanitize({"bootcamp": {"step": 99, "counts": [7]}, "nope": {"step": 1},
			"x": "y"})
	_check(clean.keys() == ["bootcamp"] and clean.bootcamp.step == Quests.steps("bootcamp").size(), "sanitized")
	clean = Quests.sanitize({"bootcamp": {"step": 1.0, "counts": [99.0]}})
	_check(clean.bootcamp.counts == [5], "counts capped")

	Net.accounts.find_player = Callable()
	print("QUEST TEST: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	return _fails


func _step(p: PlayerShape) -> int:
	return int(p.quests.save_data().bootcamp.step)


func _last_act() -> String:
	return "" if _scenes.is_empty() else str(_scenes[-1].acts[0].id)


func _darren() -> Enemy:
	for node in tree.get_nodes_in_group(Enemy.GROUP):
		var e := node as Enemy
		if e.type == "darren" and not e.is_queued_for_deletion():
			return e
	return null


## Just enough of World for quests.
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
"""
	script.reload()
	return script


func _spawn(id: int, progress: Dictionary, quests := {}) -> PlayerShape:
	var p := PlayerShape.create({"id": id, "family": "Test%d" % id, "sides": 3, "kind": "isosceles",
			"apex": 40, "luck": 0, "generation": 1, "progress": progress, "chest": [], "quests": quests,
			"pos": CenterTerrain.SPAWN_POINT})
	_root.add_child(p)
	p.quests.lead_pace = 0.0  # cutscenes start at once, not after their lead lines
	return p


func _steps(n: int) -> void:
	for i in n:
		await tree.physics_frame


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL " + what)
	else:
		print("ok " + what)

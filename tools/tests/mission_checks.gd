extends RefCounted
## Run by test_missions.gd: the Revolt's painted skirmishers in the three
## missions (design log 0247), and the rangers' fortress raid (logs 0248,
## 0250): rangers only, the rowboat, the storm's sea, the climb, the
## drawbridge, the Castellan's pay, and drowning out of the raid. A bare
## world (the barracks, Missions and a stand-in for World), so nothing is
## saved to user://. Prints BOAT and ROUTE lines for tuning.

const RANGER := {"bootcamp": {"step": 99}, "ranger_school": {"step": 99}}

var tree: SceneTree
var _fails := 0
var _root: Node2D
var _missions: Missions
var _scenes: Array[Dictionary] = []


func run() -> int:
	_root = Node2D.new()
	_root.name = "TestWorld"
	_root.set_script(_stand_in_world())
	_root.add_to_group(World.GROUP)
	tree.root.add_child(_root)
	_root.add_child(Barracks.new())
	var projectiles := Projectiles.new()
	_root.add_child(projectiles)
	_missions = Missions.new()
	_missions.world = _root
	_root.add_child(_missions)
	Net.cutscene_started.connect(func(scene: Dictionary) -> void: _scenes.append(scene))
	# The sea keeps time with the physics, as it does in play.
	Ocean.test_clock = 0.0
	tree.physics_frame.connect(func() -> void: Ocean.test_clock += 1.0 / Engine.physics_ticks_per_second)

	_skirmisher_lists()
	await _skirmishers_throw(projectiles)
	await _archers(projectiles)
	await _storm()
	await _raid()
	await _quiet_raid()
	await _climb()

	Ocean.test_clock = NAN
	print("MISSION TEST: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	_root.queue_free()
	return _fails


# --- Stage 4: painted skirmishers (log 0247) -----------------------------------

func _skirmisher_lists() -> void:
	var counts := {"recon": [], "invasion": [], "special_ops": []}
	for i in 40:
		for type: String in counts:
			var list := _missions._revolt_for(type, 0)
			(counts[type] as Array).append(list.count("skirmisher"))
			if type == "special_ops":
				_check(list.count("bodyguard") == 3, "special ops keeps three bodyguards")
	_check((counts.recon as Array).min() >= 1 and (counts.recon as Array).max() <= 2, "recon: 1-2 skirmishers %s" % [counts.recon])
	_check((counts.invasion as Array).min() >= 4 and (counts.invasion as Array).max() <= 6, "invasion: 4-6")
	_check((counts.special_ops as Array).min() == 2 and (counts.special_ops as Array).max() == 2, "special ops: 2")


func _skirmishers_throw(projectiles: Projectiles) -> void:
	var field := Mission.create({"name": "M", "type": "recon", "slot": 30, "seed": 7})
	_root.add_child(field)
	var room := Regions.mission_rect(30)
	var p := _spawn(1, {})
	p.teleport(field.ground_point(900, 40))
	await _steps(30)
	p.stats.hp = p.stats.max_hp
	var thrower := _enemy("skirmisher", field.ground_point(1400, 40), room)
	var thrown := false
	for i in 360:
		await tree.physics_frame
		thrown = thrown or projectiles.count() > 0
	_check(thrown, "a skirmisher throws at a player in range")
	_check(p.stats.hp < p.stats.max_hp, "and its tips hurt (%d/%d)" % [p.stats.hp, p.stats.max_hp])
	print("RESULT skirmisher gap=%.0f hp=%d/%d" % [thrower.position.distance_to(p.position), p.stats.hp, p.stats.max_hp])

	# Leashed (recon's huddle): it keeps its spot but still throws.
	thrower.queue_free()
	p.teleport(field.ground_point(100, 40))  # both on the flat start, in sight
	var huddled := _enemy("skirmisher", field.ground_point(600, 40), room)
	huddled.leash = Enemy.GUARD_REACH
	var home_x := huddled.position.x
	while projectiles.count() > 0:  # the last one's tips land first
		await tree.physics_frame
	var threw_leashed := false
	for i in 360:
		await tree.physics_frame
		threw_leashed = threw_leashed or projectiles.count() > 0
	_check(threw_leashed, "a huddled skirmisher throws past its leash")
	_check(absf(huddled.position.x - home_x) < 200.0, "but keeps its spot (moved %.0f)" % (huddled.position.x - home_x))
	huddled.queue_free()

	# Its tips hurt the army's soldiers too.
	p.teleport(Barracks.MUSTER)
	var soldier := _enemy("soldier", field.ground_point(1100, 40), room)
	soldier.freeze = true
	var at_soldier := _enemy("skirmisher", field.ground_point(1500, 40), room)
	for i in 480:
		await tree.physics_frame
	_check(soldier.hp < soldier.max_hp, "its tips hurt soldiers (%d/%d)" % [soldier.hp, soldier.max_hp])
	for e: Node in [soldier, at_soldier, field]:
		e.queue_free()
	_free(p)
	await _steps(2)


# --- Stage 5: the fortress raid (logs 0248, 0250) ------------------------------

func _raid() -> void:
	var outsider := _spawn(3, {})
	_missions.request(outsider, "fortress")
	_missions.mark_ready(outsider)
	await _steps(2)
	_check(_fortress() == null, "only rangers can take the raid's orders")
	_free(outsider)

	var a := _spawn(2, RANGER)
	var b := _spawn(1, RANGER)  # peer 1, the local one: its cutscene shows here
	_missions.request(a, "fortress")
	_missions.request(b, "fortress")
	_missions.mark_ready(a)
	_missions.mark_ready(b)
	await _steps(5)
	var fort := _fortress()
	_check(fort != null, "rangers are sent on the raid")
	if fort == null:
		return
	var inst: Dictionary = _missions._active[fort.slot]
	_check(Regions.mission_slot_at(a.position) == fort.slot, "the squad's at the dock")
	_check(Ocean.seas.size() == 1, "the fortress has its own sea")
	var x_mid := fort.position.x + 2300.0
	_check(Ocean.is_sea(x_mid, 1.0) and not Ocean.is_sea(fort.position.x + 300.0, 1.0), "water out there, not on the dock")
	_check(Ocean.rain_at(x_mid, 1.0) > 0.99, "a storm")
	_check(Ocean.pier_under(fort.position.x + 700.0) == fort.position.y + Fortress.PLANK, "waves stay under the piers")
	_check(_count_type("skirmisher") == 5, "a few skirmishers on the wall-walk, two with the Castellan")
	_check(_count_type("lookout") == 2 and _count_type("archer") == 3, "two lookouts and three archers")
	var enemy_boat := _boat(0, "")
	_check(enemy_boat != null, "on the enemy's boat at the landing")
	var castellan := _first("castellan")
	_check(castellan != null and inst.boss, "the Castellan waits in his courtyard")
	var boat := _boat(0)
	_check(boat != null and boat.rowed and boat.moored(), "the boatman's rowboat waits at the dock")

	# The Castellan goes after anyone inside the fortress, however far.
	b.teleport(fort.point(Vector2(6300, Fortress.WALL_TOP), PlayerShape.RADIUS + 10.0))
	await _steps(5)
	_check(castellan._nearest_target() == b, "the Castellan sees you on the wall-walk (%.0f px off)" %
			castellan.position.distance_to(b.position))
	b.teleport(fort.point(Fortress.SQUAD_AT, PlayerShape.RADIUS + 10.0))
	await _steps(5)
	_check(castellan._nearest_target() == null, "but not out on the dock")

	# The Boatman points you to his boat while it waits at the dock.
	var boatman := fort.get_node(String(Boat.BOATMAN).validate_node_name()) as Npc
	boatman.interact(b)
	_check(_boat(b.peer_id) == null, "no rowboat of your own while his waits at the dock")

	# Across, keeping to the middle of the deck. The lookouts run, the back
	# door rises for them, and once one's in, the alarm.
	a.teleport(boat.position + Vector2(-20, -PlayerShape.RADIUS - 20.0))
	await _steps(90)
	_check(a in boat.riders(), "aboard")
	boat.interact(a)
	_check(boat.row_dir == 1, "speaking to it, he rows")
	await _steps(300)
	boatman.interact(b)
	await _steps(5)
	var own := _boat(b.peer_id)
	_check(own != null and own.rowed, "with his boat out, the Boatman gives you a rowboat of your own")
	var landed := false
	var fled := false
	var door_rose := false
	var t := 0
	while t < 60 * 45 and not boat.sinking:
		for i in 60:
			await tree.physics_frame
			door_rose = door_rose or fort.back_door_open
			for node in tree.get_nodes_in_group(Enemy.GROUP):
				fled = fled or ((node as Enemy).type == "lookout" and (node as Enemy).fleeing)
		t += 60
		a.stats.hp = a.stats.max_hp  # the archers are at it; this is about the boat
		print("BOAT t=%.0f x=%.0f tilt=%.0f° row=%d aboard=%s door=%s alarm=%s" % [t / 60.0,
				boat.position.x - fort.position.x, rad_to_deg(boat.rotation), boat.row_dir, a in boat.riders(),
				fort.back_door_open, inst.get("alarm", false)])
		if boat.row_dir == 0:
			landed = true
			break
	_check(landed and absf(boat.position.x - fort.position.x - Fortress.LANDING_X) < 250.0,
			"it lands behind the enemy's boat (%.0f s, x=%.0f)" % [t / 60.0, boat.position.x - fort.position.x])
	_check(not a.actions.drowning and a in boat.riders(), "a passenger who keeps still stays aboard")
	_check(fled, "the lookouts run when you come near")
	a.teleport(fort.point(Fortress.SQUAD_AT, PlayerShape.RADIUS + 10.0))  # out of the archers' way
	var waited := 0
	while not inst.get("alarm", false) and waited < 1200:
		await _steps(10)
		waited += 10
		door_rose = door_rose or fort.back_door_open
	_check(door_rose, "the back door rises for them")
	_check(inst.get("alarm", false), "one gets in: the alarm")
	await _steps(int((Mission.TYPES.fortress.alarm_archers * Missions.ALARM_EVERY + 2.0) * 60))
	_check(not fort.back_door_open, "and the door drops behind them")
	_check(_count_type("archer") >= 10, "archers come down from the wall (%d)" % _count_type("archer"))
	_check(_count_type("sentry") == 5 and _count_type("warden") == 2, "pentagons and hexagons guard the winch")

	# Overboard: drowned, the bag's gone, and out of the raid.
	b.inventory.add_to_bag(Gear.POTION)
	b.teleport(fort.point(Vector2(2000, Fortress.SEA_LEVEL + 120.0)))
	await _steps(10)
	_check(b.actions.drowning, "falling in drowns you")
	_check(b.inventory.count_of(Gear.POTION) == 0, "the bag is lost")
	_check(Regions.at(b.position).get("id") == "barracks", "the army fishes you out to the barracks")
	_check(_last_act() == "drowned", "the drowning cutscene")
	_check(not inst.members.has(b.peer_id) and inst.members.has(a.peer_id), "out of the raid; the rest go on")
	b.actions.wake_on_shore()
	_check(Regions.at(b.position).get("id") == "barracks", "and wakes there, not on the coast")

	# The winch: the drawbridge drops, and the troop charges in. (The alarm's
	# defenders are cleared first: a guard knocked off the gatehouse would
	# fight the troop out on the field.)
	for type: String in ["archer", "sentry", "warden"]:
		for node in tree.get_nodes_in_group(Enemy.GROUP):
			if (node as Enemy).type == type:
				(node as Enemy).take_hit(1e7, a.peer_id)
	await _steps(5)
	a.teleport(fort.point(Fortress.WINCH_AT + Vector2(-60, 0), PlayerShape.RADIUS + 10.0))
	await _steps(30)
	_check(fort.reach_distance(a.position) < INF, "the winch is in reach on the gatehouse")
	fort.interact(a)
	await _steps(5)
	_check(fort.gate_down, "the drawbridge is let down")
	_check(_count_type("soldier") == int(Mission.TYPES.fortress.troop), "the troop charges in")
	var soldier := _first("soldier")
	var through := false  # once in, the Castellan may well cut it down
	for i in 600:
		await tree.physics_frame
		through = through or (is_instance_valid(soldier) and soldier.position.x < fort.position.x + Fortress.GATEHOUSE.position.x)
	_check(through, "the troop charges through the gate into the courtyard")

	# His fall wins it: 250 chits each.
	var chits := a.stats.chits
	castellan.take_hit(1e7, a.peer_id)
	await _steps(5)
	_check(a.stats.chits == chits + int(Mission.TYPES.fortress.pay), "the Castellan's fall pays %d" % Mission.TYPES.fortress.pay)
	_check(b.stats.chits == 0, "nothing for the drowned")
	_missions.mark_ready(a)  # back to the barracks
	await _steps(5)
	_check(_fortress() == null and Ocean.seas.is_empty(), "the fortress and its sea go")
	_check(_boat(0) == null and _boat(0, "") == null and _boat(b.peer_id) == null, "and so do its boats")
	_free(a)
	_free(b)
	await _steps(2)


## Lookouts brought down before they reach the door: no alarm (log 0253).
func _quiet_raid() -> void:
	var c := _spawn(4, RANGER)
	_missions.request(c, "fortress")
	_missions.mark_ready(c)
	await _steps(5)
	var fort := _fortress()
	if fort == null:
		_check(false, "a second raid")
		return
	var inst: Dictionary = _missions._active[fort.slot]
	for node in tree.get_nodes_in_group(Enemy.GROUP):
		var e := node as Enemy
		if e.type == "lookout":
			e.take_hit(1e7, c.peer_id)
	await _steps(5)
	c.teleport(fort.point(Vector2(3900, 0), PlayerShape.RADIUS + 10.0))
	var door_rose := false
	for i in 300:
		await tree.physics_frame
		door_rose = door_rose or fort.back_door_open
	_check(not inst.get("alarm", false) and not door_rose, "lookouts brought down: no alarm, the door stays shut")
	_check(_count_type("sentry") == 0 and _count_type("archer") <= 3, "only the few up top")
	_free(c)
	await _steps(int(Missions.GRACE * 60) + 10)
	_check(_fortress() == null, "an empty raid closes")


## The storm (log 0253): the rowboat rides it, and a passenger who keeps
## still stays aboard. The sea's clock is stepped with the physics, so each
## start (`at`, s) is the same storm every run.
func _storm() -> void:
	for at: float in [0.0, 60.0, 120.0]:
		Ocean.test_clock = at
		var fort := Fortress.create({"name": "Storm", "slot": 29})
		_root.add_child(fort)
		var boat := _root.spawn_boat({"pos": fort.point(Vector2(Fortress.DOCK_X, Fortress.SEA_LEVEL - 30.0)),
				"facing": 1, "rowed": true,
				"route": Vector2(fort.position.x + Fortress.DOCK_X, fort.position.x + Fortress.LANDING_X)}) as Boat
		var still := _spawn(5, RANGER)
		still.teleport(boat.position + Vector2(20, -PlayerShape.RADIUS - 20.0))
		await _steps(90)
		boat.row(1)
		var most := 0.0
		var t := 0
		while t < 60 * 30 and boat.row_dir != 0:
			await tree.physics_frame
			t += 1
			most = maxf(most, absf(rad_to_deg(wrapf(boat.rotation, -PI, PI))))
		print("STORM from %.0f s: across in %.1f s, rolled to %.0f°" % [at, t / 60.0, most])
		_check(not boat.sinking, "the rowboat rides the storm without going over (from %.0f s)" % at)
		_check(not still.actions.drowning and still in boat.riders(), "keeping still, you stay aboard (from %.0f s)" % at)
		_free(still)
		boat.queue_free()
		fort.queue_free()
		await _steps(2)


## A Painted archer (log 0253): lobs volleys and stands to charge a shot.
func _archers(projectiles: Projectiles) -> void:
	var field := Mission.create({"name": "MA", "type": "recon", "slot": 28, "seed": 7})
	_root.add_child(field)
	var p := _spawn(1, {})
	p.teleport(field.ground_point(900, 40))
	await _steps(30)
	var archer := _enemy("archer", field.ground_point(1400, 40), Regions.mission_rect(28))
	var charged := false
	var most := 0
	for i in 60 * 10:
		await tree.physics_frame
		p.stats.hp = p.stats.max_hp
		charged = charged or archer.charging
		most = maxi(most, projectiles.count())
	_check(charged, "an archer stands to charge a shot")
	_check(most >= Enemy.VOLLEY_SHOTS, "and lobs volleys (%d shots in the air at once)" % most)
	archer.queue_free()
	field.queue_free()
	_free(p)
	await _steps(2)


## The climb (log 0250): a 50° triangle rolling east from the beach,
## jumping as a player would, gets up the ledges onto the wall-walk.
func _climb() -> void:
	for shape: Array in [[3, "isosceles", 50.0], [4, "regular", 0.0]]:
		var fort := Fortress.create({"name": "Climb", "slot": 31})
		_root.add_child(fort)
		var p := _spawn(1, RANGER, shape)
		p.teleport(fort.point(Vector2(4010, 0), PlayerShape.RADIUS + 10.0))
		await _steps(30)
		p.motion._submit_move(1.0)
		var ok := false
		var i := 0
		while i < 60 * 90:
			if i % 3 == 0:  # jumping again as it lands: bouncing up each step
				p.motion._submit_jump()
			await tree.physics_frame
			i += 1
			var local := p.position - fort.position
			if local.y < Fortress.WALK.position.y and local.x > Fortress.SEA_WALL.position.x:
				ok = true
				break
		print("ROUTE %-30s %s (%.1f s, at %s)" % ["climb: %d sides" % shape[0], "ok" if ok else "STUCK",
				i / 60.0, (p.position - fort.position).round()])
		_check(ok, "a %d-sided ranger climbs onto the wall" % shape[0])
		_free(p)
		fort.queue_free()
		await _steps(2)


# --- Helpers -------------------------------------------------------------------

## Just enough of World for Missions: players, enemies, battlefields, boats.
func _stand_in_world() -> GDScript:
	var script := GDScript.new()
	script.source_code = """extends Node2D
func player(id: int) -> PlayerShape:
	for node in get_tree().get_nodes_in_group(PlayerShape.GROUP):
		if (node as PlayerShape).peer_id == id:
			return node
	return null
func spawn_enemy(data: Dictionary) -> Enemy:
	var e := Enemy.create(data)
	add_child(e)
	return e
func spawn_mission(data: Dictionary) -> Mission:
	var m := Mission.create(data)
	add_child(m)
	return m
func spawn_fortress(data: Dictionary) -> Fortress:
	var f := Fortress.create(data)
	add_child(f)
	return f
var _boats := 0
func spawn_boat(data: Dictionary) -> Boat:
	_boats += 1
	var named := data.duplicate()
	named.name = "B%d" % _boats
	var b := Boat.create(named)
	add_child(b)
	return b
func launch_boat(who: PlayerShape, at: Vector2, facing: int, route: Variant = null) -> void:
	for node in get_tree().get_nodes_in_group(Boat.GROUP):
		if (node as Boat).owner_peer == who.peer_id:
			node.queue_free()
	var data := {"pos": at, "facing": facing, "owner": who.peer_id}
	if route != null:
		data.merge({"rowed": true, "route": route})
	spawn_boat(data)
func remove_boats_in(rect: Rect2) -> void:
	for node in get_tree().get_nodes_in_group(Boat.GROUP):
		if rect.has_point((node as Boat).position):
			node.queue_free()
func drop_item(_item: String, _owner_id: int, _pos: Vector2) -> void:
	pass
func reward_kill(_enemy: Enemy, _drops := true) -> void:
	pass
func show_damage(_pos: Vector2, _amount: int, _kind: String) -> void:
	pass
"""
	script.reload()
	return script


func _spawn(id: int, quests: Dictionary, shape := [3, "isosceles", 50.0]) -> PlayerShape:
	var p := PlayerShape.create({"id": id, "family": "Test%d" % id, "sides": shape[0], "kind": shape[1],
			"apex": shape[2], "luck": 0, "generation": 1, "chest": [], "quests": Quests.sanitize(quests),
			"progress": PlayerShape.sanitize_progress({"level": 20, "chits": 0,
				"stats": {"vigor": 30, "mettle": 30, "force": 30, "torque": 30}}),
			"pos": Barracks.MUSTER})
	_root.add_child(p)
	p.quests.lead_pace = 0.0
	return p


func _enemy(type: String, pos: Vector2, room: Rect2) -> Enemy:
	return _root.spawn_enemy({"name": "%s%d" % [type, randi()], "type": type, "pos": pos, "room": room})


func _fortress() -> Fortress:
	for node in tree.get_nodes_in_group(Fortress.GROUP):
		if not node.is_queued_for_deletion() and node.name not in ["Climb", "Storm"]:
			return node
	return null


## A boat of `owner_peer`'s; with `rower` "", the enemy's (no one rows it).
func _boat(owner_peer: int, rower := Boat.BOATMAN) -> Boat:
	for node in tree.get_nodes_in_group(Boat.GROUP):
		var b := node as Boat
		if b.owner_peer == owner_peer and not b.is_queued_for_deletion() and (b.boatman == "") == (rower == ""):
			return b
	return null


func _first(type: String) -> Enemy:
	for node in tree.get_nodes_in_group(Enemy.GROUP):
		var e := node as Enemy
		if e.type == type and not e.is_queued_for_deletion():
			return e
	return null


func _count_type(type: String) -> int:
	var n := 0
	for node in tree.get_nodes_in_group(Enemy.GROUP):
		var e := node as Enemy
		if e.type == type and not e.is_queued_for_deletion():
			n += 1
	return n


func _last_act() -> String:
	return "" if _scenes.is_empty() else str(_scenes[-1].acts[0].id)


func _free(p: PlayerShape) -> void:
	_root.remove_child(p)
	p.queue_free()


func _steps(n: int) -> void:
	for i in n:
		await tree.physics_frame


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL " + what)

extends RefCounted
## PlayerShape smoke test, run by test_player.gd: movement, inventory, gear,
## abilities, saved progress, marriage and a Revolt boss's moves. Builds a
## bare world (terrain, a door, a Quartermaster) instead of World, so
## nothing is saved to user://. Prints RESULT lines to compare across a
## refactor, and FAIL lines.

var tree: SceneTree
var _fails := 0
var _results: Array[String] = []
var _root: Node2D


## Returns the number of failed checks.
func run() -> int:
	seed(12345)
	_root = Node2D.new()
	_root.name = "TestWorld"
	tree.root.add_child(_root)
	_root.add_child(CenterTerrain.new())

	var p := _spawn(1, {})
	await _steps(120)
	_record("settled", p)

	# Rolling, then a jump and a bounce, then the other way.
	p.motion._submit_move(1.0)
	await _steps(180)
	_record("rolled_right", p)
	p.motion._submit_jump()
	await _steps(40)
	p.motion._submit_jump()
	await _steps(80)
	_record("jumped", p)
	p.motion._submit_move(-1.0)
	await _steps(240)
	p.motion._submit_move(0.0)
	await _steps(120)
	_record("rolled_left", p)

	# Inventory: a swap inside the bag, then gear on and off.
	var bag: PackedStringArray = p.inventory.bag
	_check(bag[0] == Gear.POTION and bag[2] == "points_6", "starting bag")
	p.inventory._submit_swap(0, 3)
	bag = p.inventory.bag
	_check(bag[0] == "" and bag[3] == Gear.POTION, "bag swap")
	var force_before: int = p.stats.force
	p.inventory._submit_equip(2)
	var worn: PackedStringArray = p.inventory.equipped
	_check(worn[0] == "points_6", "equip points")
	_check(p.stats.force == force_before + Gear.bonuses("points_6").force, "equip adds force")
	p.inventory._submit_unequip(0, -1)
	_check(p.stats.force == force_before, "unequip removes force")
	p.inventory.request_use(p.inventory.bag.find("points_6"))  # an RPC to ourselves
	await _steps(2)
	_check((p.inventory.equipped as PackedStringArray)[0] == "points_6", "use equips")
	p.inventory._submit_equip(p.inventory.bag.find("plating_6"))
	_results.append("RESULT gear %s rigidity=%d force=%d" % [str(p.inventory.equipped),
			p.stats.rigidity, p.stats.force])

	# Chests: only at the door.
	p.inventory._submit_swap(3, PlayerInventory.CHEST_BASE + 1)
	_check((p.inventory.chest as PackedStringArray)[1] == "", "no chest away from the door")
	var door := HouseDoor.new()
	door.position = p.position
	_root.add_child(door)
	p.inventory._submit_swap(3, PlayerInventory.CHEST_BASE + 1)
	_check((p.inventory.chest as PackedStringArray)[1] == Gear.POTION, "swap into chest")
	p.inventory._submit_swap(PlayerInventory.CHEST_BASE + 0, 3)
	_check((p.inventory.bag as PackedStringArray)[3] == "voice_7", "swap out of chest")
	door.queue_free()
	await _steps(1)

	# Health: a hit, then a potion.
	p.combat.take_hit(50.0, Vector2.ZERO)
	var hurt: int = p.stats.hp
	_check(hurt < p.stats.max_hp, "hit hurts")
	p.inventory._submit_swap(PlayerInventory.CHEST_BASE + 1, 4)
	_check((p.inventory.bag as PackedStringArray)[4] == "", "chest needs the door")
	p.inventory.add_to_bag(Gear.POTION)
	p.inventory._submit_drink(-1)
	_check(p.stats.hp > hurt, "potion heals")
	_results.append("RESULT health hp=%d max=%d" % [p.stats.hp, p.stats.max_hp])

	# Abilities: learn from the Quartermaster, then use each.
	var qm_data: Dictionary = Barracks.NPCS[1].duplicate()
	qm_data.at = p.position + Vector2(0, 20)
	var qm := Npc.create(qm_data)
	_root.add_child(qm)
	var pay_before: int = p.stats.pay
	for id: String in ["rush", "nose_dive", "spike_up"]:
		p.actions._submit_learn(id)
	_check(Array(p.stats.abilities) == ["rush", "nose_dive", "spike_up"], "learned three")
	_check(p.stats.pay == pay_before - 180, "paid 180")
	p.actions._submit_learn("rush")
	_check(p.stats.pay == pay_before - 180, "no paying twice")
	qm.queue_free()
	await _steps(240)  # energy back to full
	_record("before_moves", p)
	p.moves._submit_ability("rush")
	await _steps(2)
	_check(p.stats.energy < Stats.MAX_ENERGY - 40.0, "rush costs energy")
	await _steps(120)
	_record("rush", p)
	await _steps(1400)
	p.moves._submit_ability("nose_dive")
	await _steps(30)
	_record("nose_dive_up", p)
	await _steps(200)
	_record("nose_dive", p)
	await _steps(1400)
	p.moves._submit_ability("spike_up")
	await _steps(30)
	_record("spike_up", p)
	await _steps(200)

	# Saved progress round trip, through JSON like a family save.
	var saved: Dictionary = p.progress()
	var raw: Variant = JSON.parse_string(JSON.stringify(saved))
	var clean := PlayerShape.sanitize_progress(raw)
	var p2 := _spawn(2, clean, Array(p.inventory.chest))
	await _steps(1)
	_check(p2.progress() == saved, "progress round trip")
	for stat: String in ["level", "xp", "pay", "vigor", "mettle", "force", "torque", "rigidity", "max_hp"]:
		_check(p2.stats.get(stat) == p.stats.get(stat), "restored " + stat)
	_check(p2.inventory.chest == p.inventory.chest, "restored chest")
	_check(PlayerShape._clean_items(["potion", 5, "bogus"], 3) == PackedStringArray(["potion", "", ""]),
			"clean items")
	_results.append("RESULT progress %s" % JSON.stringify(saved, "", true))
	p2.queue_free()

	# A Revolt boss uses its moves on you (design log 0089).
	var boss := Enemy.create({"name": "Boss", "type": "captain", "room": Rect2(-3000, -3000, 6000, 6000),
			"pos": p.position + Vector2(300, -60)})
	_root.add_child(boss)
	boss._rng.seed = 7
	var boss_moved := false
	for i in 600:
		await tree.physics_frame
		boss_moved = boss_moved or boss._moves.active()
	_check(boss_moved, "boss used a move")
	_results.append("RESULT boss pos=%s hp=%d" % [_v(boss.position), boss.hp])
	_record("after_boss", p)

	# Marriage: a new heir takes over the shape (design log 0030).
	p.inventory.add_to_bag(Gear.CERTIFICATE)
	_check(p.actions.marry(), "marry")
	_check(p.generation == 2 and p.stats.level == 1 and p.stats.abilities.is_empty(), "heir starts fresh")
	_check(p.inventory.equipped == PlayerInventory.blank(Gear.SLOTS.size()), "heir wears nothing")
	await _steps(10)

	for line in _results:
		print(line)
	print("DONE fails=%d" % _fails)
	return _fails


func _spawn(id: int, progress: Dictionary, chest: Array = ["voice_7"]) -> PlayerShape:
	if progress.is_empty():
		progress = PlayerShape.sanitize_progress({
			"level": 3, "xp": 10, "pay": 500,
			"stats": {"vigor": 3, "mettle": 2, "force": 4, "torque": 3},
			"bag": [Gear.POTION, "", "points_6", "", "", "plating_6"],
			"equipped": ["", "", "", "", ""],
		})
	var p := PlayerShape.create({"id": id, "family": "Test%d" % id, "sides": 4, "kind": "regular",
			"apex": 0, "luck": 5, "generation": 1, "progress": progress, "chest": chest,
			"pos": CenterTerrain.SPAWN_POINT})
	_root.add_child(p)
	return p


func _steps(n: int) -> void:
	for i in n:
		await tree.physics_frame


func _record(label: String, p: PlayerShape) -> void:
	_results.append("RESULT %s pos=%s rot=%.3f vel=%s spin=%.3f energy=%.2f hp=%d" % [label,
			_v(p.position), p.rotation, _v(p.linear_velocity), p.angular_velocity, p.stats.energy, p.stats.hp])


func _v(v: Vector2) -> String:
	return "(%.2f, %.2f)" % [v.x, v.y]


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL ", what)

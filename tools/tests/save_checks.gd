extends RefCounted
## Offline saving checks, run by test_saves.gd (design logs 0112, 0113).

const WORLD := "res://scenes/world.tscn"

var _fails := 0
var _base := ""


var tree: SceneTree


## Returns the number of failed checks.
func run() -> int:
	var root := tree.root
	_base = "user://test-saves-%d/" % Time.get_ticks_usec()
	var fam_store: Node = root.get_node("FamilyStore")
	var net: Node = root.get_node("Net")
	fam_store.use_base(_base)
	_check(fam_store.get_family(0) == null, "temp store starts empty")
	fam_store.found_family(0, "Testers", "isosceles")
	_check(FileAccess.file_exists(_base + "families/slot_1.json"), "founded family saved in temp folder")
	# Irregular is locked until an heir is born irregular (design log 0174).
	var locked: Family = fam_store.found_family(1, "Crooked", "irregular")
	_check(locked.kind == "isosceles" and fam_store.unlocks.is_empty(), "irregular start locked at first")
	fam_store.delete_family(1)

	# Play: gain levels, loot and a chest item, then leave (saves).
	net.start_offline(0)
	var world := await _open_world()
	var p: PlayerShape = world.player(1)
	_check(p != null and p.stats.level == 1, "fresh heir spawned")
	p.stats.add_xp(2000)
	p.inventory.add_to_bag("points_6")
	var chest := p.inventory.chest
	chest[3] = "voice_7"
	p.inventory.chest = chest
	var level: int = p.stats.level
	_check(level > 1, "gained levels")
	var bag := p.inventory.bag
	net.leave()
	world.free()

	# Restart: what the menu sees, and what the next session loads.
	fam_store.reload()
	var family: Family = fam_store.get_family(0)
	_check(family != null and int(family.progress.get("level", 0)) == level, "menu sees saved level")
	net.start_offline(0)
	world = await _open_world()
	p = world.player(1)
	_check(p.stats.level == level, "level restored")
	_check(p.inventory.bag == bag, "bag restored")
	_check(p.inventory.chest[3] == "voice_7", "chest restored")
	# An heir born irregular unlocks it, for good, even once that family is gone.
	net.accounts.on_heir(1, {"sides": 3, "kind": "irregular", "apex": 50, "luck": 20})
	net.leave()
	world.free()
	fam_store.delete_family(0)
	fam_store.reload()
	_check(Family.UNLOCK_IRREGULAR in fam_store.unlocks, "irregular birth unlocks irregular starts")
	var crooked: Family = fam_store.found_family(1, "Crooked", "irregular")
	_check(crooked.kind == "irregular", "irregular family founded once unlocked")

	_check_cadence()
	_remove_dir(ProjectSettings.globalize_path(_base))
	print("DONE fails=%d" % _fails)
	return _fails


func _open_world() -> World:
	var world: World = load(WORLD).instantiate()
	tree.root.add_child(world)
	for i in 10:
		await tree.physics_frame
	return world


## SaveKeeper: XP alone waits; a meaningful change saves after MIN_GAP;
## force saves at once.
func _check_cadence() -> void:
	var store := CountingStore.new()
	var keeper := SaveKeeper.new()
	keeper.store = store
	var family := Family.found("Cadence", "isosceles", RandomNumberGenerator.new())
	var p := PlayerShape.create({"id": 9, "family": "Cadence", "sides": 3, "kind": "isosceles",
			"apex": 45, "luck": 0, "generation": 1, "progress": {}, "chest": [], "pos": Vector2.ZERO})
	family.progress = p.progress()
	var session := {"account": "a", "families": [family, null, null], "chest": Array(p.inventory.chest),
			"slot": 0, "saved_at": SaveKeeper._now()}
	p.stats.xp += 1
	keeper.checkpoint(session, p)
	_check(store.writes == 0, "xp alone waits")
	session.saved_at = SaveKeeper._now() - SaveKeeper.MIN_GAP
	keeper.checkpoint(session, p)
	_check(store.writes == 0, "xp alone waits past MIN_GAP")
	p.inventory.add_to_bag(Gear.POTION)
	keeper.checkpoint(session, p)
	_check(store.writes == 1, "loot saves after MIN_GAP")
	p.stats.xp += 1
	keeper.checkpoint(session, p, true)
	_check(store.writes == 2, "forced save")
	keeper.checkpoint(session, p, true)
	_check(store.writes == 2, "nothing changed, nothing written")
	p.free()
	store.free()


class CountingStore extends SaveStore:
	var writes := 0

	func save_family(_account: String, _slot: int, _data: Dictionary) -> void:
		writes += 1

	func save_chest(_account: String, _items: Array) -> void:
		writes += 1


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL %s" % what)
	else:
		print("ok %s" % what)


func _remove_dir(path: String) -> void:
	for sub in DirAccess.get_directories_at(path):
		_remove_dir(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)

extends SceneTree
## Screenshots of regimental armor, the Blacksmith and the Quarry Isle (design
## logs 0210, 0211), offline with a made-up player, nothing saved. Needs a
## window (not --headless).
##
##   Godot --path . --resolution 1280x720 -s tools/record/smith_shots.gd -- --no-hot-reload --out=/some/folder
##
## Takes: the forge, the Blacksmith's panel, the Quarry Isle, the family
## strongroom and its panel, the heirloom choice (log 0216), the dock's market with promissory notes (log
## 0212), and close-ups of a full regimental set at +0, +3 and +5 (still
## and rolling).

const WORLD_SCENE := "res://scenes/world.tscn"

var _world: World
var _out := "user://shots"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	var net: Node = root.get_node("Net")  # autoloads aren't names in a -s script
	net.leave()
	net.players[1] = {"family": "Shaw", "sides": 3, "kind": "isosceles", "apex": 55, "luck": 5, "generation": 1}
	net.progress[1] = PlayerSave.sanitize({"level": 12, "chits": 2400, "coins": 2600, "smith_ore": 12,
			"stats": {"vigor": 12, "mettle": 12, "force": 12, "torque": 12},
			"equipped": ["points_9", "plating_9", "", "eye_9", "voice_9+2"],
			"bag": ["points_7", Gear.ORE, Gear.ORE, Gear.POTION, "note_37", Gear.LOG],
			"vault": ["plating_9+4", "note_50", "", "", "", "", "", "", "", ""],
			"heirlooms": ["points_8", "plating_9+1", "", "eye_7", ""],
			"heirloom_pending": ["points_9+5", "plating_6", "", "", ""]})
	net.in_session = true
	change_scene_to_file(WORLD_SCENE)
	for i in 300:
		await process_frame
		_world = current_scene as World
		if _world != null and _world.player(1) != null:
			break
	var p := _world.player(1)
	await _wait(30)

	await _shot(p, Vector2(1380, -285 - 40), "forge")
	p.teleport(Vector2(1350, -285 - 40))
	await _wait(30)
	p.actions._submit_interact()  # the Blacksmith
	await _wait(30)
	_save("smith_panel")
	_world._hud.close_panel()
	await _shot(p, Vector2(-18450, Coast.SHORE_Y - 40), "quarry")
	await _shot(p, Vector2(-180, -40), "strongroom")
	p.actions._submit_interact()  # the Strongroom Keeper
	await _wait(30)
	_save("strongroom_panel")
	_world._hud.open_panel("heirlooms")  # log 0216
	await _wait(10)
	_save("heirloom_choice")
	_world._hud.close_panel()
	p.teleport(Vector2(-6990, Coast.SHORE_Y - 40))
	await _wait(60)
	p.actions._submit_interact()  # the Harbourmaster
	await _wait(30)
	_save("market_notes")
	_world._hud.close_panel()

	# Close-ups of the armor on flat ground by the plaza.
	_world._camera.zoom = Vector2(4, 4)
	for level in [0, 3, 5]:
		var worn := PackedStringArray()
		for slot in Gear.SLOTS:
			worn.append(Gear.item(slot, Gear.REGIMENTAL, level) if slot in Gear.MILITARY_SLOTS else "")
		p.inventory.equipped = worn
		await _shot(p, Vector2(150, -40), "armor_plus%d" % level)
	# The ribbons (log 0220): a few frames rolling, then settling after a stop.
	p.motion._submit_move(1.0)
	for k in 4:
		await _wait(8)
		_save("ribbons_rolling_%d" % k)
	p.motion._submit_move(0.0)
	await _wait(25)
	_save("ribbons_stopping")
	await _wait(150)
	_save("ribbons_settled")
	await _wait(40)
	_save("ribbons_settled_later")
	quit()


func _shot(p: PlayerShape, at: Vector2, label: String) -> void:
	p.teleport(at)
	await _wait(5)
	_world._camera.reset_smoothing()
	await _wait(60)
	_save(label)


func _save(label: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [_out, label])
	print("SHOT ", label)


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame

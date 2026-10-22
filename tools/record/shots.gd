extends SceneTree
## Screenshots of places in the real game (offline, made-up player, nothing
## saved), for checking how they look. Needs a window (not --headless).
##
##   Godot --path . --resolution 1280x720 -s tools/record/shots.gd -- --no-hot-reload --out=/some/folder
##
## Takes: the coast's gate, the dock, a boat at sea, the Logging Isle,
## Merchants' Row and your booth, the dock's market, and the purse page.

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
	net.progress[1] = PlayerSave.sanitize({"level": 6, "chits": 2400, "coins": 135,
			"stats": {"vigor": 6, "mettle": 6, "force": 6, "torque": 6},
			"bag": [Gear.LOG, Gear.LOG, Gear.LOG, Gear.POTION]})
	net.in_session = true
	change_scene_to_file(WORLD_SCENE)
	for i in 300:
		await process_frame
		_world = current_scene as World
		if _world != null and _world.player(1) != null:
			break
	var p := _world.player(1)
	await _wait(30)

	await _shot(p, Vector2(Coast.GATE_X + 150, Coast.FLOOR_Y - 40), "gate")
	await _shot(p, Vector2(-7250, Coast.SHORE_Y - 40), "dock")
	# Take a boat and sail out a little.
	p.teleport(Vector2(-7420, Coast.SHORE_Y - 40))
	await _wait(30)
	p.actions._submit_interact()
	await _wait(120)
	for burst in 3:
		p.motion._submit_move(-1.0)
		await _wait(90)
		p.motion._submit_move(0.0)
		await _wait(40)
	_save("sea")
	await _shot(p, Vector2(-12300, Coast.SHORE_Y - 40), "isle")
	await _shot(p, Vector2(-12960 + 140, Coast.SHORE_Y - 40), "trees")
	await _shot(p, Vector2(850, Market.ROW_FLOOR - 40), "row")
	p.actions._submit_interact()  # the Market Clerk: your booth
	await _wait(30)
	_save("booth")
	_world._hud.close_panel()
	p.teleport(Vector2(-6990, Coast.SHORE_Y - 40))
	await _wait(60)
	p.actions._submit_interact()  # the Harbourmaster: the dock's market
	await _wait(30)
	_save("market")
	_world._hud.close_panel()
	_world._hud._character.visible = true
	_world._hud._show_page(true)
	await _wait(10)
	_save("purse")
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

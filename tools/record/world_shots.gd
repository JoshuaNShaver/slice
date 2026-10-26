extends SceneTree
## Screenshots of the solid world (design logs 0221-0224): the houses, the
## mounds, the NPCs in the way. Offline, made-up player, nothing saved.
## Needs a window (not --headless).
##
##   Godot --path . --resolution 1280x720 -s tools/record/world_shots.gd -- --no-hot-reload --out=/some/folder
##
## Wide shots are zoomed out to see a whole house; close ones are the
## game's own view.

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
	net.players[1] = {"family": "Shaw", "sides": 4, "kind": "regular", "apex": 0, "luck": 5, "generation": 1}
	net.progress[1] = PlayerSave.sanitize({"level": 6})
	net.in_session = true
	change_scene_to_file(WORLD_SCENE)
	for i in 300:
		await process_frame
		_world = current_scene as World
		if _world != null and _world.player(1) != null:
			break
	var p := _world.player(1)
	await _wait(30)

	await _shot(p, Vector2(-1800, 80), "center_raised", 0.5, Vector2(0, -350))
	await _shot(p, Vector2(-1800, -230), "center_raised_inside")
	await _shot(p, Vector2(150, -60), "center_plaza")
	await _shot(p, Vector2(1500, -330), "center_sunken", 0.5, Vector2(150, -400))
	await _shot(p, Vector2(1600, -330), "center_sunken_inside")
	await _shot(p, Vector2(-3000, 80), "barracks_yard")
	await _shot(p, Vector2(-4300, 80), "barracks_hall", 0.5, Vector2(0, -350))
	await _shot(p, Vector2(-7100, 340), "coast_dock", 0.5, Vector2(0, -300))
	await _shot(p, Vector2(4900, -1540), "noble_home", 0.5, Vector2(0, -350))
	await _shot(p, Vector2(1300, -330), "noble_lift", 0.5, Vector2(300, -500))
	await _shot(p, Vector2(13000, -2740), "temple", 0.4, Vector2(300, -300))
	await _shot(p, Vector2(-300, 2960), "undercroft", 0.5, Vector2(0, -250))
	quit()


func _shot(p: PlayerShape, at: Vector2, label: String, zoom := 1.0, look := Vector2.ZERO) -> void:
	p.teleport(at)
	await _wait(5)
	_world._camera.zoom = Vector2(zoom, zoom)
	_world._camera.offset = look
	_world._camera.reset_smoothing()
	await _wait(60)
	_save(label)
	_world._camera.zoom = Vector2.ONE
	_world._camera.offset = Vector2.ZERO


func _save(label: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [_out, label])
	print("SHOT ", label)


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame

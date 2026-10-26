extends SceneTree
## Screenshots of the Flatlander's view (FlatView, design log 0238) in each
## \view mode, at a few places (offline, made-up player, nothing saved).
## Needs a window (not --headless).
##
##   Godot --path . --resolution 1280x720 -s tools/record/flat_view_shots.gd -- --no-hot-reload --out=/some/folder

const WORLD_SCENE := "res://scenes/world.tscn"
const MODES := [["2d", true, 0], ["2d_eyes", true, 2], ["eyes", false, 2], ["2d_eye", true, 1], ["eye", false, 1]]

var _world: World
var _out := "user://flat_shots"


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
	# A painted Revolt rebel by the Center's spawn, to check colours show.
	_world.spawn_enemy({"name": "Rebel", "type": "rebel", "room": Rect2(),
			"pos": CenterTerrain.SPAWN_POINT + Vector2(-220, -30)})
	var places := {
		"center": CenterTerrain.SPAWN_POINT,
		"dock": Vector2(-7250, Coast.SHORE_Y - 40),
		"undercroft": Regions.spawn_for("irregular"),
		"hatch": CenterTerrain.LIFT_DOWN.top + Vector2(0, -40),  # standing on it: it stays shut
		"barracks": Vector2(-3900, Barracks.island_y(-3900) - 40),
	}
	for place: String in places:
		p.teleport(places[place])
		await _wait(5)
		_world._camera.reset_smoothing()
		await _wait(60)
		for mode: Array in MODES:
			FlatView.show_2d = mode[1]
			FlatView.eyes = mode[2]
			_world._flat._facing = -0.3  # the single eye: a little north of east
			await _wait(8)
			_save("%s_%s" % [place, mode[0]])
			if mode[0] == "eyes" and "--world" in OS.get_cmdline_user_args():  # what the rays walk through
				_world._flat._world_view.get_texture().get_image().save_png("%s/%s_world.png" % [_out, place])
	FlatView.show_2d = true
	FlatView.eyes = 0
	quit()


func _save(label: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [_out, label])
	print("SHOT ", label)


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame

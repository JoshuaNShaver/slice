extends SceneTree
## Screenshots of the rangers' fortress raid (design logs 0248, 0250): the
## dock and the Boatman's rowboat, the crossing in the storm, the crags up
## the sea wall, the wall-walk's guards, the winch, and the drawbridge down
## with the troop and the Castellan; and (log 0253) the enemy's boat, the
## lookouts running for the back door, and the alarm. Offline, made-up player, nothing saved.
## Needs a window (not --headless).
##
##   Godot --path . --resolution 1280x720 -s tools/record/fortress_shots.gd -- --no-hot-reload --out=/some/folder

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
	Abilities.ALL = Abilities._info_of_all()  # a -s script compiles before the autoloads exist
	var net: Node = root.get_node("Net")
	net.leave()
	net.players[1] = {"family": "Shaw", "sides": 3, "kind": "isosceles", "apex": 55, "luck": 5, "generation": 1}
	net.progress[1] = PlayerSave.sanitize({"level": 20, "stats": {"vigor": 40, "mettle": 40, "force": 25, "torque": 25},
			"equipped": ["points_10", "plating_10", "", "eye_10", "voice_10"],
			"abilities": ["volley", "charged_shot", "double_jump"]})
	net.in_session = true
	change_scene_to_file(WORLD_SCENE)
	for i in 300:
		await process_frame
		_world = current_scene as World
		if _world != null and _world.player(1) != null:
			break
	var p := _world.player(1)
	p.quests.load_data(Quests.sanitize({"bootcamp": {"step": 99}, "ranger_school": {"step": 99}}))
	p.motion.teleport(Barracks.MUSTER)
	await _wait(10)
	_world._missions.request(p, "fortress")
	_world._missions.mark_ready(p)
	await _wait(20)
	var fort := get_first_node_in_group(Fortress.GROUP) as Fortress
	var boat: Boat = null
	for node in get_nodes_in_group(Boat.GROUP):
		if (node as Boat).boatman != "":
			boat = node  # the Boatman's, not the enemy's
	await _shot_here("fortress_dock", 0.6, Vector2(500, -150))

	# Aboard, and across.
	p.motion.teleport(boat.position + Vector2(-40, -PlayerShape.RADIUS - 20.0))
	await _wait(60)
	boat.interact(p)
	await _wait(480)
	await _shot_here("fortress_crossing", 0.7, Vector2(150, -120))
	while boat.row_dir != 0:
		await _wait(30)
		p.stats.hp = p.stats.max_hp  # the archers are at it
	await _shot_here("fortress_landing", 0.45, Vector2(500, -300))
	# The lookouts run for the back door, and it rises for them.
	var slot := fort.slot
	p.motion.teleport(fort.point(Vector2(3850, 0), 40.0))  # on the landing's pier
	for i in 600:
		await process_frame
		p.stats.hp = p.stats.max_hp
		if fort.back_door_open:
			break
	await _shot_here("fortress_back_door", 0.6, Vector2(100, 0))
	for i in 1200:
		await process_frame
		p.stats.hp = p.stats.max_hp
		if _world._missions._active.has(slot) and _world._missions._active[slot].get("alarm", false):
			break
	# The alarm: archers come down the crags.
	for i in 6:
		await _wait(60)
		p.stats.hp = p.stats.max_hp
	await _shot_here("fortress_alarm", 0.4, Vector2(700, -350))

	# Up on the wall.
	p.motion.teleport(fort.point(Vector2(5100, Fortress.WALL_TOP), 40.0))
	await _wait(60)
	await _shot_here("fortress_wall_walk", 0.55, Vector2(500, 0))
	p.motion.teleport(fort.point(Fortress.WINCH_AT + Vector2(-60, 0), 40.0))
	await _wait(30)
	await _shot_here("fortress_winch", 0.8)
	fort.interact(p)
	await _wait(150)
	await _shot_here("fortress_gate_down", 0.45, Vector2(-300, 250))
	p.motion.teleport(fort.point(Fortress.KEEP_DOOR + Vector2(500, 0), 40.0))
	await _wait(20)
	await _shot_here("fortress_castellan", 0.6, Vector2(-200, -100))
	quit()


func _shot_here(label: String, zoom := 1.0, look := Vector2.ZERO) -> void:
	_world._camera.zoom = Vector2(zoom, zoom)
	_world._camera.offset = look
	_world._camera.reset_smoothing()
	await _wait(60)
	var image := root.get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [_out, label])
	print("SHOT ", label)
	_world._camera.zoom = Vector2.ONE
	_world._camera.offset = Vector2.ZERO


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame

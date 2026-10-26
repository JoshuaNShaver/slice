extends SceneTree
## Screenshots of the rangers (design logs 0241-0246): the rangers' island,
## the exam course, a ranger's tips and shots, a recruit throwing back.
## Offline, made-up player, nothing saved. Needs a window (not --headless).
##
##   Godot --path . --resolution 1280x720 -s tools/record/ranger_shots.gd -- --no-hot-reload --out=/some/folder

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
	# A -s script compiles before the autoloads exist, which leaves the
	# ability registry empty; build it again now they're here.
	Abilities.ALL = Abilities._info_of_all()
	var net: Node = root.get_node("Net")
	net.leave()
	net.players[1] = {"family": "Shaw", "sides": 3, "kind": "isosceles", "apex": 55, "luck": 5, "generation": 1}
	net.progress[1] = PlayerSave.sanitize({"level": 20, "stats": {"vigor": 25, "mettle": 25, "force": 25, "torque": 25},
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
	await _wait(30)

	await _shot(p, RangerCamp.ORIGIN + Vector2(-1000, -40), "camp_stores", 0.6, Vector2(0, -200))
	await _shot(p, RangerCamp.ORIGIN + Vector2(-1500, -40), "camp_west_sea", 0.6, Vector2(-500, 0))
	await _shot(p, RangerCamp.ORIGIN + Vector2(500, -40), "camp_yard", 0.6, Vector2(150, -200))
	# Throwing at the yard: a few shots in the air, then a volley and a charge.
	p.motion.teleport(RangerCamp.ORIGIN + Vector2(-50, -40))
	await _wait(20)
	_world._camera.zoom = Vector2.ONE
	for i in 3:
		p.moves.throw()
		await _wait(12)
	_save("camp_throw")
	p.stats.energy = Stats.MAX_ENERGY
	p.moves._submit_ability("volley")
	await _wait(40)
	p.moves._submit_release("volley")
	await _wait(14)
	_save("camp_volley")
	p.stats.energy = Stats.MAX_ENERGY
	p.moves._submit_ability("charged_shot")
	await _wait(78)
	_save("camp_charge_flash")
	p.moves._submit_release("charged_shot")
	await _wait(6)
	_save("camp_charged_shot")
	await _wait(200)
	_save("camp_recruits_throw")
	_world.open_exam(p)
	await _wait(10)
	await _shot_here("exam_start", 1.0)
	await _shot(p, Regions.exam_origin(0) + Vector2(1900, -230), "exam_fork", 0.5, Vector2(300, -100))
	await _shot(p, Regions.exam_origin(0) + Vector2(5350, -790), "exam_top")  # what you see before the leap
	await _shot(p, Regions.exam_origin(0) + Vector2(5600, 150), "exam_boat", 0.6, Vector2(250, -150))
	quit()


func _shot(p: PlayerShape, at: Vector2, label: String, zoom := 1.0, look := Vector2.ZERO) -> void:
	p.motion.teleport(at)
	await _wait(5)
	await _shot_here(label, zoom, look)


func _shot_here(label: String, zoom := 1.0, look := Vector2.ZERO) -> void:
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

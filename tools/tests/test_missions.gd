extends SceneTree
## The missions' painted skirmishers (design log 0247) and the rangers'
## fortress raid (logs 0248, 0250). Exits 1 on any failed check.
##
##   Godot --headless --fixed-fps 60 --path . -s tools/tests/test_missions.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	Abilities.ALL = Abilities._info_of_all()  # a -s script compiles before the autoloads exist
	var checks: RefCounted = load("res://tools/tests/mission_checks.gd").new()
	checks.tree = self
	var fails: int = await checks.run()
	quit(1 if fails > 0 else 0)

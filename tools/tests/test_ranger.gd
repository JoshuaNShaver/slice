extends SceneTree
## Ranger school (design log 0245), the rangers' island, its stores and
## throwing recruits (logs 0241-0246). Exits 1 on any failed check.
##
##   Godot --headless --path . -s tools/tests/test_ranger.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var checks: RefCounted = load("res://tools/tests/ranger_checks.gd").new()
	checks.tree = self
	var fails: int = await checks.run()
	quit(1 if fails > 0 else 0)

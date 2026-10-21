extends SceneTree
## Quests (design log 0179): the bootcamp quest step by step, both ends of
## Darren's bout, and saving. Exits 1 on any failed check.
##
##   Godot --headless --path . -s tools/tests/test_quests.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var checks: RefCounted = load("res://tools/tests/quest_checks.gd").new()
	checks.tree = self
	var fails: int = await checks.run()
	quit(1 if fails > 0 else 0)

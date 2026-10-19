extends SceneTree
## Headless smoke test for PlayerShape (player_checks.gd). Exits 1 on any
## failed check.
##
##   Godot --headless --path . -s tools/tests/test_player.gd
##
## The checks load after the first frame, once autoloads are ready.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var checks: RefCounted = load("res://tools/tests/player_checks.gd").new()
	checks.tree = self
	var fails: int = await checks.run()
	quit(1 if fails > 0 else 0)

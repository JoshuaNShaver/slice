extends SceneTree
## Offline saving (design logs 0112, 0113): found a family, play it, save,
## "restart" and load it back, in a temporary save folder (never the real
## user://families). Checks are in save_checks.gd. Exits 1 on any failure.
##
##   Godot --headless --path . -s tools/tests/test_saves.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var checks: RefCounted = load("res://tools/tests/save_checks.gd").new()
	checks.tree = self
	var fails: int = await checks.run()
	quit(1 if fails > 0 else 0)

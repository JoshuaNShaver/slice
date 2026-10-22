extends SceneTree
## Headless test for the west coast (coast_checks.gd): the Watch's gate,
## sailing, capsizing, drowning, the trees and selling logs. Exits 1 on any
## failed check. Prints BOAT lines (speed and lean over time) for tuning.
##
##   Godot --headless --path . -s tools/tests/test_coast.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var checks: Node = load("res://tools/tests/coast_checks.gd").new()
	checks.tree = self
	var fails: int = await checks.run()
	quit(1 if fails > 0 else 0)

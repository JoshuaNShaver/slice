extends SceneTree
## The admin terminal and imsdow (design logs 0146-0148): Enter never
## leaves, \bye says goodbye, and she reacts to what happens. Checks are in
## imsdow_checks.gd. Exits 1 on any failure.
##
##   Godot --headless --path . -s tools/tests/test_imsdow.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var checks: RefCounted = load("res://tools/tests/imsdow_checks.gd").new()
	checks.tree = self
	var fails: int = await checks.run()
	quit(1 if fails > 0 else 0)

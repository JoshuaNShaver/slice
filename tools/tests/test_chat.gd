extends SceneTree
## Headless test for chat and admin commands (chat_checks.gd). Exits 1 on
## any failed check.
##
##   Godot --headless --path . -s tools/tests/test_chat.gd
##
## The checks load after the first frame, once autoloads are ready.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var checks: RefCounted = load("res://tools/tests/chat_checks.gd").new()
	checks.tree = self
	var fails: int = await checks.run()
	quit(1 if fails > 0 else 0)

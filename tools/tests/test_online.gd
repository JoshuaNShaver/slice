extends SceneTree
## Online join test against a running dedicated server (online_checks.gd).
## Exits 1 on any failure. Start the server with --dev-admins (the test
## levels up with an admin command, log 0125).
##
##   Godot --headless --path . -s tools/tests/test_online.gd -- --port=24690 [--token=T] [--bad-token=T]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var checks: RefCounted = load("res://tools/tests/online_checks.gd").new()
	checks.tree = self
	var fails: int = await checks.run()
	quit(1 if fails > 0 else 0)

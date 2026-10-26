extends SceneTree
## Can shapes still get where they need to go in the solid world (design
## logs 0221-0224)? Rolls bots along the main routes with today's movement,
## holding a direction and jumping every few steps (route_checks.gd).
## Exits 1 on any failed route.
##
##   Godot --headless --path . -s tools/tests/test_routes.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var checks: RefCounted = load("res://tools/tests/route_checks.gd").new()
	checks.tree = self
	var fails: int = await checks.run()
	quit(1 if fails > 0 else 0)

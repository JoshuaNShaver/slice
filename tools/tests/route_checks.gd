extends RefCounted
## Routes through the solid world, run by test_routes.gd. Each bot holds a
## roll direction and jumps every JUMP_EVERY steps, the way a player would
## barge along, until it reaches the goal or runs out of time. Prints ROUTE
## lines (with the time taken) and FAIL lines.

const JUMP_EVERY := 10
const STARTER := [3, "isosceles", 40.0]  # a new family's triangle (log 0176)
const SQUARE := [4, "regular", 0.0]

var tree: SceneTree
var _fails := 0
var _root: Node2D
var _id := 1


func run() -> int:
	_root = Node2D.new()
	_root.name = "RouteWorld"
	tree.root.add_child(_root)
	World.add_places(_root)
	await _steps(5)
	var spawn := Regions.CENTER_SPAWN
	# The barracks are up on their island, two steps up from the road (log 0232).
	var on_island := func(p: PlayerShape) -> bool:
		return p.position.y < Barracks.island_y(p.position.x) + 10.0 and p.position.x < -3060.0
	await _route("starter: spawn up onto the barracks' island", STARTER, spawn, -1, on_island, 30.0)
	await _route("starter: the Sergeant to the General", STARTER, Vector2(-3200, -220), -1, func(p: PlayerShape) -> bool:
		return p.position.x < -4700.0, 30.0)
	await _route("starter: under the barracks to the coast gate", STARTER, Vector2(-2500, 60), -1,
			func(p: PlayerShape) -> bool: return p.position.x < -5500.0, 30.0)
	await _route("starter: spawn to Merchants' Row", STARTER, spawn, 1, func(p: PlayerShape) -> bool:
		return p.position.x > 900.0 and p.position.y < -120.0, 20.0)
	await _route("starter: the Row to the Blacksmith", STARTER, Vector2(900, -150), 1, func(p: PlayerShape) -> bool:
		return p.position.x > 1480.0 and p.position.y < -250.0, 25.0)
	await _route("square: the Row to the noble lift", SQUARE, Vector2(900, -150), 1, func(p: PlayerShape) -> bool:
		return absf(p.position.x - CenterTerrain.LIFT_UP.bottom.x) < 40.0, 25.0, true)
	await _route("square: into the sunken house's hall", SQUARE, Vector2(1470, -330), 1, func(p: PlayerShape) -> bool:
		return p.position.x > CenterTerrain.SUNKEN.x - 200.0 and p.position.y < -250.0, 25.0)
	# Under the raised house the road's valley is rolled through, not jumped (log 0231):
	# jumping lands on its island instead.
	await _route("starter: past the raised house", STARTER, Vector2(-2950, 60), 1, func(p: PlayerShape) -> bool:
		return p.position.x > -1200.0, 25.0, false, true, false)
	_root.queue_free()
	print("ROUTES: %s" % ("all ok" if _fails == 0 else "%d failed" % _fails))
	return _fails


## Rolls a fresh `shape` from `from` toward `dir` until `arrived`, for up to
## `seconds`. `stop_at_goal` lets go of the keys once there (a lift stop).
## `required` false reports a route the movement rework should open, without
## failing the run. `jump` false rolls without jumping.
func _route(label: String, shape: Array, from: Vector2, dir: float, arrived: Callable, seconds: float,
		stop_at_goal := false, required := true, jump := true) -> void:
	var p := PlayerShape.create({"id": _id, "family": "R%d" % _id, "sides": shape[0], "kind": shape[1],
			"apex": shape[2], "luck": 5, "generation": 1, "progress": PlayerShape.sanitize_progress({}),
			"chest": [], "pos": from})
	_id += 1
	_root.add_child(p)
	await _steps(30)
	p.motion._submit_move(dir)
	var ok := false
	var steps := int(seconds * Engine.physics_ticks_per_second)
	var i := 0
	while i < steps:
		if jump and i % JUMP_EVERY == 0:
			p.motion._submit_jump()
		await tree.physics_frame
		i += 1
		if arrived.call(p):
			ok = true
			break
	if stop_at_goal:
		p.motion._submit_move(0.0)
	var took := float(i) / Engine.physics_ticks_per_second
	var verdict := "ok" if ok else ("STUCK" if required else "not yet")
	print("ROUTE %-42s %s (%.1f s, at %s)" % [label, verdict, took, p.position.round()])
	if not ok and required:
		_fails += 1
		print("FAIL route: ", label)
	p.queue_free()
	await _steps(2)


func _steps(n: int) -> void:
	for k in n:
		await tree.physics_frame

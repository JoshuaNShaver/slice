extends RefCounted
## The README clips, run by record.gd once autoloads are ready. Each one
## builds an offline world with made-up players and no account (nothing is
## saved), then plays its script. A clip calls _start() where the GIF should
## begin; that prints "TRIM <frames>" for the GIF maker to cut what's before.

const WORLD_SCENE := "res://scenes/world.tscn"
const SETTLE_FRAMES := 60
const ZOOM := 1.4  # closer in than play: the shapes read better at GIF size
const CLIPS := ["invasion", "lift", "crowd"]
const MARCH := 0.5  # the squad's pace to the front, so the soldiers keep up

var tree: SceneTree
## The tree's process frames so far (record.gd counts them).
var frame := 0
var _world: World


func run() -> void:
	var clip := "invasion"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--clip="):
			clip = arg.trim_prefix("--clip=")
	if clip not in CLIPS:
		push_error("Unknown clip %s; pick one of %s." % [clip, CLIPS])
		return
	seed(7)

	Net.leave()
	var players := _cast(clip)
	for id: int in players:
		Net.players[id] = players[id].info
		Net.progress[id] = PlayerSave.sanitize(players[id].progress)
	Net.in_session = true
	tree.change_scene_to_file(WORLD_SCENE)
	var last: int = players.keys()[-1]
	for i in 300:
		await tree.process_frame
		_world = tree.current_scene as World
		if _world != null and _world.player(last) != null:
			break
	if _world == null or _world.player(last) == null:
		push_error("The world or its players didn't load (scene: %s)." % tree.current_scene)
		return
	_world._hud.visible = false
	_world._camera.zoom = Vector2(ZOOM, ZOOM)
	for id: int in players:
		if players[id].has("pos"):
			_world.player(id).teleport(players[id].pos)
	await _wait(SETTLE_FRAMES)
	await call("_" + clip)


## Who's in each clip: id -> {"info", "progress", "pos" (optional)}.
func _cast(clip: String) -> Dictionary:
	var all_moves := ["rush", "nose_dive", "spike_up"]
	match clip:
		"invasion":  # a squad of three in the barracks, ready to deploy
			return {
				1: {"info": _info("Ashworth", 6, "regular"), "progress": _progress(16, all_moves),
						"pos": Vector2(-2700, Barracks.FLOOR_Y - 60)},
				2: {"info": _info("Copperfield", 4, "regular"), "progress": _progress(13, all_moves),
						"pos": Vector2(-2800, Barracks.FLOOR_Y - 60)},
				3: {"info": _info("Dunmore", 5, "regular"), "progress": _progress(14, all_moves),
						"pos": Vector2(-2900, Barracks.FLOOR_Y - 60)},
			}
		"lift":
			return {1: {"info": _info("Ashworth", 6, "regular"), "progress": _progress(8, []),
					"pos": Vector2(-450, -80)}}
		"crowd":
			return {
				1: {"info": _info("Ashworth", 6, "regular"), "progress": _progress(8, [])},
				2: {"info": _info("Brindle", 3, "regular"), "progress": _progress(2, [])},
				3: {"info": _info("Copperfield", 4, "regular"), "progress": _progress(4, [])},
				4: {"info": _info("Dunmore", 5, "regular"), "progress": _progress(6, [])},
				5: {"info": _info("Ellery", 3, "isosceles", 40), "progress": _progress(1, [])},
			}
	return {}


func _info(family: String, sides: int, kind: String, apex := 0) -> Dictionary:
	return {"family": family, "sides": sides, "kind": kind, "apex": apex, "luck": 5, "generation": 1}


func _progress(level: int, abilities: Array) -> Dictionary:
	return {"level": level, "pay": 200, "abilities": abilities,
			"stats": {"vigor": level, "mettle": level, "force": level, "torque": level},
			"bag": [Gear.POTION, Gear.POTION]}


# --- Clips ----------------------------------------------------------------

## The squad deploys to an invasion and marches east with the soldiers;
## the clip starts as the Revolt comes into view. Then the fight: spike ups
## throw rebels into the air, with rushes and nose dives between.
func _invasion() -> void:
	var squad: Array[PlayerShape] = [_world.player(1), _world.player(2), _world.player(3)]
	_world._missions._deploy("invasion", [1, 2, 3])
	await _wait(20)
	for p in squad:
		p.motion._submit_move(MARCH)
	var hero := squad[0]
	for i in 4000:  # up to a minute of marching
		await _wait(1)
		if _nearest_foe(hero) < 1300.0:
			break
	_start()
	await _wait(60)
	for p in squad:
		p.motion._submit_move(1.0)
	var plan := ["rush", "spike_up", "nose_dive", "spike_up", "rush", "spike_up"]
	for step in plan.size():
		for p in squad:
			p.combat.heal_full()  # nobody dies on camera
		var near := _nearest_foe(hero) < SpikeUpAbility.RANGE
		var move: String = plan[step]
		if move == "spike_up" and not near:
			move = "rush"
		hero.moves._submit_ability(move)
		# The others keep pushing in, hopping now and then.
		squad[1 + step % 2].motion._submit_jump()
		if step % 3 == 2:
			squad[2 - step % 2].moves._submit_ability("spike_up")
		await _wait(70)
		hero.motion._submit_move(1.0 if _foe_side(hero) >= 0.0 else -1.0)
	await _wait(40)


## Roll onto the underworld lift and ride it down to the Undercroft.
func _lift() -> void:
	var p := _world.player(1)
	var stop: Vector2 = CenterTerrain.LIFT_DOWN.top
	_start()
	p.motion._submit_move(-1.0)
	for i in 600:
		if p.position.x <= stop.x + 10.0:
			break
		await _wait(1)
	p.motion._submit_move(0.0)
	await _wait(30)
	p.actions._submit_interact()
	for i in 1200:
		await _wait(1)
		if i > 10 and not p.motion.riding():
			break
	await _wait(20)
	p.motion._submit_move(1.0)
	await _wait(80)
	p.motion._submit_move(0.0)
	await _wait(30)


## Five families in the Center: rolling, hopping, saying hello.
func _crowd() -> void:
	var lines := {1: "Morning!", 2: "Off to the barracks?", 3: "Mind the Constable.",
			4: "Lovely angles today.", 5: "Wait for me!"}
	var moves := {1: 0.6, 2: 1.0, 3: -0.5, 4: 0.8, 5: 1.0}
	_start()
	for id: int in moves:
		_world.player(id).motion._submit_move(moves[id])
	for step in 6:
		for id: int in lines:
			var p := _world.player(id)
			if (step + id) % 3 == 0:
				p.motion._submit_jump()
			if step == id - 1:
				p.chat._submit_line(lines[id])
		await _wait(30)
	for id: int in moves:
		_world.player(id).motion._submit_move(-moves[id] * 0.7)
	await _wait(60)
	for id: int in moves:
		_world.player(id).motion._submit_move(0.0)
	await _wait(40)


# --- Helpers --------------------------------------------------------------

func _start() -> void:
	print("TRIM %d" % frame)


## The Revolt's fighters still standing (not the army's soldiers).
func _foes() -> Array:
	return tree.get_nodes_in_group(Enemy.GROUP).filter(func(e: Node) -> bool:
		var enemy := e as Enemy
		return enemy != null and enemy.players_can_hit() and enemy.hp > 0)


func _nearest_foe(p: PlayerShape) -> float:
	var best := INF
	for e: Enemy in _foes():
		best = minf(best, p.position.distance_to(e.position))
	return best


## Which way the nearest foe is: -1 west, 1 east, 0 if none.
func _foe_side(p: PlayerShape) -> float:
	var best := INF
	var side := 0.0
	for e: Enemy in _foes():
		var d := p.position.distance_to(e.position)
		if d < best:
			best = d
			side = signf(e.position.x - p.position.x)
	return side


## Waits `frames` sixtieths of a second (physics runs faster, at 120).
func _wait(frames: int) -> void:
	for i in frames * Engine.physics_ticks_per_second / 60:
		await tree.physics_frame

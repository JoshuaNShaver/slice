extends RefCounted
## Online join checks, run by test_online.gd against a running dedicated
## server: log in, pick a family, try to send a cheated save, level up,
## leave, rejoin and get it back (design logs 0112-0116).
##
## Options (after --): --port=N, --token=T (else a guest login),
## --bad-token=T (first check that it's refused).

const WORLD := "res://scenes/world.tscn"
const LEVEL_UPS := 3

var tree: SceneTree
var _fails := 0
var _port := Net.DEFAULT_PORT
var _token := ""
var _bad_token := ""
var _world: World


func run() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			_port = arg.trim_prefix("--port=").to_int()
		elif arg.begins_with("--token="):
			_token = arg.trim_prefix("--token=")
		elif arg.begins_with("--bad-token="):
			_bad_token = arg.trim_prefix("--bad-token=")
	Net.accounts.guest_id_path = "user://test-online-%d/guest_id.txt" % Time.get_ticks_usec()

	if _bad_token != "":
		Net.join("127.0.0.1", _port)
		await Net.accounts.login_needed
		Net.accounts.log_in_with_token(_bad_token)
		var message: String = await _next_error()
		_check("log in" in message.to_lower(), "bad token refused: %s" % message)
		Net.leave()

	var families := await _connect_and_log_in()
	_check(families.size() == 3, "got 3 slots")
	if families.is_empty():
		return _done()
	if families[0] == null or families[0].extinct:
		if families[0] != null:
			Net.accounts.delete(0)
			await Net.accounts.slots_received
		Net.accounts.found(0, "Onliners", "isosceles")
		families = await Net.accounts.slots_received
	_check(families[0] != null, "family founded on the server")
	var start_level := int(families[0].progress.get("level", 1))

	# Cheat: register with our own progress. The server must ignore it.
	Net.accounts.play(0)
	await Net.session_started
	Net._register.rpc_id(1, {"progress": {"level": 20, "stats": {"vigor": 38}}, "chest": ["points_6"]})
	var me := await _enter_world()
	_check(me != null and me.stats.level == start_level,
			"cheated progress ignored (level %d)" % (me.stats.level if me else -1))
	if me == null:
		return _done()
	for i in LEVEL_UPS:
		me.stats._submit_debug_level_up.rpc_id(1)
	for i in 30:
		await tree.process_frame
	var level := me.stats.level
	_check(level == start_level + LEVEL_UPS, "leveled up to %d" % level)
	_leave_world()
	await tree.create_timer(1.0).timeout

	# Rejoin: the server loads what it saved when we left.
	families = await _connect_and_log_in()
	_check(families.size() == 3 and families[0] != null
			and int(families[0].progress.get("level", 0)) == level, "slots show the saved level")
	Net.accounts.play(0)
	await Net.session_started
	me = await _enter_world()
	_check(me != null and me.stats.level == level, "level back after rejoining")
	_leave_world()
	return _done()


## [Family or null] x 3, or [] on failure.
func _connect_and_log_in() -> Array:
	Net.join("127.0.0.1", _port)
	var info: Dictionary = await Net.accounts.login_needed
	if _token != "":
		_check(info.get("auth") == "supabase", "server asks for a Supabase login")
		Net.accounts.log_in_with_token(_token)
	else:
		Net.accounts.log_in_as_guest()
	return await Net.accounts.slots_received


func _next_error() -> String:
	return await Net.accounts.account_error


func _enter_world() -> PlayerShape:
	_world = load(WORLD).instantiate()
	tree.root.add_child(_world)
	for i in 300:
		await tree.process_frame
		var me := _world.player(tree.root.multiplayer.get_unique_id())
		if me != null:
			for j in 10:
				await tree.process_frame
			return me
	return null


func _leave_world() -> void:
	Net.leave()
	_world.free()
	_world = null


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("%s %s" % ["ok" if ok else "FAIL", what])


func _done() -> int:
	var dir := Net.accounts.guest_id_path.get_base_dir()
	DirAccess.remove_absolute(Net.accounts.guest_id_path)
	DirAccess.remove_absolute(dir)
	print("DONE fails=%d" % _fails)
	return _fails

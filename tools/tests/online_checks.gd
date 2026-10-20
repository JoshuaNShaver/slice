extends RefCounted
## Online join checks, run by test_online.gd against a running dedicated
## server: log in, pick a family, try to send a cheated save, level up
## with an admin command, leave, rejoin and get it back (design logs
## 0112-0116, 0125). Start the server with --dev-admins, so the level-up
## command is allowed.
##
## Options (after --): --port=N, --token=T (else a guest login),
## --bad-token=T (first check that it's refused), --username=NAME (the
## name to pick if the account has none; default Onliner<random>).

const WORLD := "res://scenes/world.tscn"
const LEVEL_UPS := 3

var tree: SceneTree
var _fails := 0
var _port := Net.DEFAULT_PORT
var _token := ""
var _bad_token := ""
var _username := ""
var _world: World


## Stands in for the HUD to catch the server's answers to chat commands.
const _NoticeCatcher := preload("res://tools/tests/notice_catcher.gd")


func run() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			_port = arg.trim_prefix("--port=").to_int()
		elif arg.begins_with("--token="):
			_token = arg.trim_prefix("--token=")
		elif arg.begins_with("--bad-token="):
			_bad_token = arg.trim_prefix("--bad-token=")
		elif arg.begins_with("--username="):
			_username = arg.trim_prefix("--username=")
	if _username == "":
		_username = "Onliner%d" % (randi() % 100000)
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
	# An admin command in chat (log 0125): the server needs --dev-admins.
	var hud: Node = _NoticeCatcher.new()
	tree.root.add_child(hud)
	me.chat.send_line("\\player levelup %d" % LEVEL_UPS)
	for i in 30:
		await tree.process_frame
	var level := me.stats.level
	_check(level == start_level + LEVEL_UPS, "leveled up to %d by \\player levelup (server answered: %s)"
			% [level, " / ".join(hud.notices)])
	# \diagnostics (log 0155): pings over the real connection.
	hud.notices.clear()
	me.chat.send_line("\\diagnostics")
	await tree.create_timer(PlayerChat.PINGS * PlayerChat.PING_GAP + 0.5).timeout
	var report: String = hud.notices[-1] if not hud.notices.is_empty() else ""
	print(report)
	_check("Ping: " in report and not "no answer" in report and "a second" in report
			and not "didn't answer" in report, "diagnostics over the network")
	hud.queue_free()
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
	var slots := []
	var catch_slots := func(families: Array) -> void:
		slots.append(families)
	Net.accounts.slots_received.connect(catch_slots)
	Net.join("127.0.0.1", _port)
	var info: Dictionary = await Net.accounts.login_needed
	if _token != "":
		_check(info.get("auth") == "supabase", "server asks for a Supabase login")
		Net.accounts.log_in_with_token(_token)
		var first: Array = await _first_of([Net.accounts.username_needed, Net.accounts.signed_in])
		if first[0] == 0:
			await _pick_username()
		else:
			_check(first[1] != "", "signed in as %s" % first[1])
	else:
		Net.accounts.log_in_as_guest()
	var deadline := Time.get_ticks_msec() + 20000
	while slots.is_empty() and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	Net.accounts.slots_received.disconnect(catch_slots)
	return slots[0] if not slots.is_empty() else []


## A new account names itself: bad names are refused, then ours is taken.
func _pick_username() -> void:
	Net.accounts.choose_username("no")
	var problem: String = await Net.accounts.username_needed
	_check(problem != "", "short name refused: %s" % problem)
	Net.accounts.choose_username("bad name!")
	problem = await Net.accounts.username_needed
	_check(problem != "", "bad characters refused: %s" % problem)
	Net.accounts.choose_username(_username)
	var first: Array = await _first_of([Net.accounts.username_needed, Net.accounts.signed_in])
	if first[0] == 0 and "taken" in str(first[1]):
		print("ok %s" % first[1])  # another account has it (any case)
		_username = "Onliner%d" % (randi() % 100000)
		Net.accounts.choose_username(_username)
		first = await _first_of([Net.accounts.username_needed, Net.accounts.signed_in])
	_check(first[0] == 1 and first[1] == _username, "named %s (%s)" % [_username, first[1]])


## Waits for whichever signal (each with one argument) fires first:
## [its index, its argument].
func _first_of(signals: Array) -> Array:
	var got := []
	var handlers := []
	for i in signals.size():
		var handler := func(arg: Variant) -> void:
			if got.is_empty():
				got.append_array([i, arg])
		handlers.append(handler)
		(signals[i] as Signal).connect(handler)
	while got.is_empty():
		await tree.process_frame
	for i in signals.size():
		(signals[i] as Signal).disconnect(handlers[i])
	return got


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

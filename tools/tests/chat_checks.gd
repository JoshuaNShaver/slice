extends RefCounted
## Chat and admin command checks (PlayerChat, AdminConsole; design logs
## 0124, 0125), run by test_chat.gd. Builds a bare world with two players
## and made-up sessions, so nothing is saved.

var tree: SceneTree
var _fails := 0
var _heard: Array = []  # [speaker_id, speaker, text]
var _notices: Array[String] = []


## Returns the number of failed checks.
func run() -> int:
	var root := tree.root
	add_to_group_catcher()
	var world := Node2D.new()
	root.add_child(world)
	world.add_child(CenterTerrain.new())
	var me := _spawn(world, 1, "Testers", CenterTerrain.SPAWN_POINT)
	var other := _spawn(world, 2, "Others", Regions.mission_rect(0).get_center())
	other.freeze = true  # no ground out there
	Net.accounts.sessions[1] = {"account": "local", "username": "Admin_Al", "role": "admin"}
	Net.accounts.sessions[2] = {"account": "guest-abc", "username": "", "role": "player"}
	await tree.physics_frame

	# Parsing.
	var parsed := AdminConsole.parse("Players SET level 11 --id \"The Others\"")
	_check(parsed.words == ["Players", "SET", "level", "11"] and parsed.flags == {"id": "The Others"},
			"parse words, quotes and flags: %s" % parsed)
	_check(AdminConsole.parse("players list --online").flags == {"online": true}, "bare flag is true")
	_check(AdminConsole.parse("a --x=1 b").has("error"), "words after flags refused")
	_check(AdminConsole.parse("say \"open").has("error"), "unclosed quote refused")

	# Who may run commands.
	_check("Only admins" in AdminConsole.run(other, "\\players"), "a player can't run commands")
	var their_help := AdminConsole.run(other, "\\help")
	_check("hello" in their_help and "bye" in their_help and not "players" in their_help,
			"a player's help lists hello and bye: %s" % their_help)
	_check(AdminConsole.run(other, "\\") == their_help, "so does a lone \\")
	var all_help := _run_cmd(me, "\\help")
	_check("players" in all_help and "enemies" in all_help and "quests" in all_help, "help lists nouns")
	_check("levelup" in _run_cmd(me, "\\players help"), "noun help lists verbs")
	_check("players quests ..." in _run_cmd(me, "\\players help"), "noun help lists sub-nouns")
	_check("delete" in _run_cmd(me, "\\players quests help"), "sub-noun help lists its verbs")
	_check("Usage" in _run_cmd(me, "\\players set"), "set without words shows usage")
	_check("no --bogus" in _run_cmd(me, "\\players list --bogus"), "unknown flag refused")
	_check("no --bogus" in _run_cmd(me, "\\players --bogus"), "flags on a noun alone go to its list")
	_check("no command" in _run_cmd(me, "\\nope"), "unknown noun refused")
	_check("no command" in _run_cmd(me, "\\player list"), "nouns are plural only")
	_check("has no \"nope\"" in _run_cmd(me, "\\players nope"), "unknown verb refused")
	_check("2 online" in _run_cmd(me, "\\PLAYERS LIST"), "words are any case")

	# Tab completion (log 0163) and \players.
	var done := AdminConsole.complete("\\pl", true)
	_check(done.line == "\\players " and done.options.is_empty(), "\\pl -> \\players: %s" % done)
	_check(AdminConsole.complete("\\enemies", true).line == "\\enemies ", "a whole word gets its space")
	_check(AdminConsole.complete("\\players le", true).line == "\\players levelup ", "verb completes")
	_check(AdminConsole.complete("\\players set l", true).line == "\\players set level ", "set field completes")
	_check(AdminConsole.complete("\\players set level 3 --i", true).line == "\\players set level 3 --id ", "flag completes")
	_check(AdminConsole.complete("\\players qu", true).line == "\\players quests ", "sub-noun completes")
	_check(AdminConsole.complete("\\players quests st", true).line == "\\players quests start ", "its verb completes")
	_check(AdminConsole.complete("\\players quests start bo", true).line == "\\players quests start bootcamp ",
			"quest id completes")
	_check(AdminConsole.complete("\\quests get b", true).line == "\\quests get bootcamp ", "quests get completes")
	_check(AdminConsole.complete("\\diag l", false).line == "\\diag live ", "diag live for players")
	_check(AdminConsole.complete("\\pl", false).line == "\\pl", "players don't get admin nouns")
	_check(AdminConsole.complete("\\h", false).line == "\\hel", "h -> hel, the shared start")
	_check(str(AdminConsole.complete("\\hel", false).options) == str(["hello", "help"]),
			"hel lists hello, help: %s" % AdminConsole.complete("\\hel", false))
	_check(AdminConsole.complete("hi there", true).line == "hi there", "chat lines left alone")
	_check("2 online" in _run_cmd(me, "\\players"), "players alone lists players")

	# Short ids and finding players.
	var my_id := AdminConsole.short_id(1)
	var their_id := AdminConsole.short_id(2)
	var listing := _run_cmd(me, "\\players list")
	_check("2 online" in listing and "Admin_Al  (the Testers family" in listing
			and "The Others family  (level" in listing,
			"list shows both: %s" % listing)
	_check(my_id != their_id and my_id < 100 and their_id < 100, "short ids are small")
	_check("Others" in _run_cmd(me, "\\players get %d" % their_id), "get by short id")
	_check("generation" in _run_cmd(me, "\\players get oth"), "get by the start of a family name")
	_check("No one online" in _run_cmd(me, "\\players get 99"), "unknown id")

	# Changing players.
	other.inventory.equipped = PackedStringArray(["points_6", "", "", "", ""])
	other.stats.apply_bonuses("points_6", 1)
	var answer := _run_cmd(me, "\\players set level 7 --id %d" % their_id)
	_check(other.stats.level == 7 and "now 7" in answer, "set level up: %s" % answer)
	_check(me.stats.level == 3, "only the target changed")
	var gear_force: int = Gear.bonuses("points_6").force
	_run_cmd(me, "\\players set level 1 --id %d" % their_id)
	_check(other.stats.level == 1 and other.stats.force == gear_force and other.stats.vigor == 0,
			"set level down re-rolls from 1, keeps gear (force %d)" % other.stats.force)
	_check(other.stats.max_hp == Stats.max_hp(other.stats.vigor), "max hp matches vigor")
	answer = _run_cmd(me, "\\players levelup 3")
	_check(me.stats.level == 6 and "3 -> 6" in answer, "levelup yourself: %s" % answer)
	_run_cmd(me, "\\players levelup 99")
	_check(me.stats.level == Stats.MAX_LEVEL, "levelup stops at the top")
	_check("already at the top" in _run_cmd(me, "\\players levelup"), "levelup at the top says so")
	_run_cmd(me, "\\players set chits 1234 --id oth")
	_check(other.stats.chits == 1234, "set chits by name")
	_run_cmd(me, "\\players set hp 99999 --id oth")
	_check(other.stats.hp == other.stats.max_hp, "hp clamped to max")
	_check("Can't set" in _run_cmd(me, "\\players set luck 50"), "unlisted field refused")
	_check("whole number" in _run_cmd(me, "\\players set chits lots"), "non-number refused")

	# Enemies.
	var spawn := Barracks.spawn_points()[3]  # a sparring partner
	var e := Enemy.create(spawn.merged({"name": "E3"}))
	world.add_child(e)
	e.freeze = true
	await tree.physics_frame
	var enemies := _run_cmd(me, "\\enemies")
	_check("1 of 1" in enemies and "E3" in enemies and "sparring" in enemies and not "AWAY" in enemies,
			"\\enemies lists it at home: %s" % enemies)
	_check("No enemies match" in _run_cmd(me, "\\enemies list --away"), "none away")
	e.position = spawn.pos + Vector2(3000, 0)
	_check("AWAY" in _run_cmd(me, "\\enemies --away"), "one knocked far off is away")
	_check("home (" in _run_cmd(me, "\\enemies get e3"), "get by name")
	_check("No enemy" in _run_cmd(me, "\\enemies get E99"), "unknown enemy")
	e.queue_free()

	# Quests (log 0196): the quests themselves, and a player's place in them.
	var steps := Quests.steps("bootcamp").size()
	_check("bootcamp" in _run_cmd(me, "\\quests") and "for regulars" in _run_cmd(me, "\\quests"),
			"quests lists them: %s" % _run_cmd(me, "\\quests"))
	_check("%d. " % steps in _run_cmd(me, "\\quests get Bootcamp"), "quests get shows every step")
	_check("no quest" in _run_cmd(me, "\\quests get nope"), "unknown quest refused")
	_check("not started" in _run_cmd(me, "\\players quests"), "players quests lists yours: not started")
	answer = _run_cmd(me, "\\players quests start bootcamp")
	_check(me.quests.has_started("bootcamp") and "step 1 of %d" % steps in answer, "start: %s" % answer)
	_check(me.quests.tracker.get("quest", "") == "Bootcamp", "the HUD's tracker shows it")
	_check("already started" in _run_cmd(me, "\\players quests start bootcamp"), "start twice refused")
	answer = _run_cmd(me, "\\players quests set bootcamp 3 --id %d" % their_id)
	_check(other.quests.state_of("bootcamp") == {"step": 2, "counts": [0]} and "step 3 of" in answer,
			"set someone else's, begun or not: %s" % answer)
	_check(me.quests.state_of("bootcamp").step == 0, "only the target's changed")
	other.quests.notify("talk", BootcampQuest.SERGEANT)
	_check("> 4." in _run_cmd(me, "\\players quests get bootcamp --id oth"), "get marks the current step")
	_check("+ 1." in _run_cmd(me, "\\players quests get bootcamp --id oth"), "and the done ones")
	_check("1 to %d, or done" % steps in _run_cmd(me, "\\players quests set bootcamp 0"), "step out of range")
	_check("1 to" in _run_cmd(me, "\\players quests set bootcamp two"), "step not a number")
	answer = _run_cmd(me, "\\players quests set bootcamp done")
	_check(me.quests.is_done("bootcamp") and "now done" in answer and me.quests.tracker.is_empty(),
			"set done: %s" % answer)
	answer = _run_cmd(me, "\\players quests delete bootcamp")
	_check(not me.quests.has_started("bootcamp") and "forgot" in answer, "delete: %s" % answer)
	_check("hasn't started" in _run_cmd(me, "\\players quests delete bootcamp"), "delete twice says so")
	_check("Usage" in _run_cmd(me, "\\players quests start"), "start without a quest shows usage")
	_run_cmd(me, "\\players quests delete bootcamp --id oth")

	# Chat: heard in the same room only, cleaned, and rate limited.
	_notices.clear()
	me.chat._submit_line("  hello\nthere  ")
	await tree.process_frame
	_check(_heard.size() == 1 and _heard[0] == [1, "Admin_Al", "hello there"],
			"said line heard, cleaned: %s" % str(_heard))
	_check(PlayerChat.room_of(me.position) != PlayerChat.room_of(other.position),
			"a mission is its own room")
	_check(PlayerChat.clean("x".repeat(500)).length() == PlayerChat.MAX_LENGTH, "long lines cut")
	for i in PlayerChat.BURST:
		me.chat._submit_line("spam %d" % i)
	await tree.process_frame
	_check(_notices.has("You're talking too fast."), "rate limited")

	# \diagnostics (log 0155): anyone, never sent as a line.
	_heard.clear()
	_notices.clear()
	_check("diagnostics" in their_help, "a player's help lists diagnostics")
	me.chat.send_line("\\Diag ")  # peer 1: the only one an offline test can answer
	await tree.create_timer(PlayerChat.PINGS * PlayerChat.PING_GAP + 0.5).timeout
	var report: String = _notices[-1] if not _notices.is_empty() else ""
	_check(report.begins_with("Diagnostics") and "fps" in report and "Server: " in report
			and "enemies" in report and not "didn't answer" in report and _heard.is_empty(),
			"diagnostics report: %s" % report)

	# \diag live and \simulate lag (log 0159): parsed here, never sent.
	_check(Diagnostics.parse("\\diag live").get("do") == "live", "\\diag live parses")
	var lag := Diagnostics.parse("\\simulate lag 150 30")
	_check(lag.get("do") == "simulate" and lag.lag == 150.0 and lag.jitter == 30.0, "\\simulate lag 150 30: %s" % lag)
	_check(Diagnostics.parse("\\simulate lag 100 90").get("jitter") == 50.0, "jitter at most half the lag")
	_check(Diagnostics.parse("\\simulate lag off").get("lag") == 0.0, "\\simulate lag off")
	_check(Diagnostics.parse("\\simulate lag fast").has("error"), "\\simulate lag needs a number")
	# Stalls and the prod profile (log 0167).
	var stalls := Diagnostics.parse("\\simulate stalls 160 every 3")
	_check(stalls.get("stall") == 160.0 and stalls.get("every") == 3.0 and not stalls.has("lag"),
			"\\simulate stalls 160 every 3: %s" % stalls)
	_check(Diagnostics.parse("\\simulate stalls 200").get("every") == Diagnostics.STALL_EVERY, "stalls default every")
	_check(Diagnostics.parse("\\simulate stalls off").get("stall") == 0.0, "\\simulate stalls off")
	var prod := Diagnostics.parse("\\simulate prod")
	_check(prod.get("lag") == Diagnostics.PROD.lag and prod.get("stall") == Diagnostics.PROD.stall, "\\simulate prod: %s" % prod)
	var all_off := Diagnostics.parse("\\simulate off")
	_check(all_off.get("lag") == 0.0 and all_off.get("stall") == 0.0, "\\simulate off stops both")
	_check(Diagnostics.parse("\\simulate stalls lots").has("error"), "stalls need a number")
	var peer := LagPeer.new(OfflineMultiplayerPeer.new())
	peer.simulate_stalls(80.0, 0.5)
	var held := false  # a stall starts within 0.75 s (0.5 s, give or take half)
	var t_end := Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < t_end and not held:
		peer._get_available_packet_count()  # starts a stall when one is due
		held = Time.get_ticks_usec() < peer._stall_until
		await tree.process_frame
	_check(held, "stalls come when due")
	_check(Diagnostics.parse("\\players").is_empty() and Diagnostics.parse("hi").is_empty(), "others aren't parsed")
	_check("simulate" in their_help, "a player's help lists simulate")
	_notices.clear()
	me.chat.send_line("\\simulate lag 200")
	await tree.process_frame
	_check(_heard.is_empty() and not _notices.is_empty() and "offline" in _notices[-1],
			"simulated lag offline: %s" % ("" if _notices.is_empty() else _notices[-1]))
	me.chat.send_line("\\diag live")
	_check(PlayerChat.live and "on" in _notices[-1], "\\diag live turns on")
	_check("no network" in Diagnostics.live_text([], {}, me), "live panel offline: %s" % Diagnostics.live_text([], {}, me))
	me.chat.send_line("\\diag live")
	_check(not PlayerChat.live, "\\diag live again turns off")
	var smoother := NetSmoother.new()
	for i in 4:
		smoother.push(PackedFloat32Array([0, 0, 0, 0, 0, 0, fmod(Time.get_ticks_usec() / 1e6, 4096.0)]))
		await tree.create_timer(0.05).timeout
	var stats := smoother.stats()
	_check(stats.get("rate", 0.0) > 10.0 and stats.get("gap", 1.0) < 0.2, "update stats: %s" % stats)

	Net.accounts.sessions.clear()
	print("CHAT TEST: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	return _fails


func add_to_group_catcher() -> void:
	var catcher := _Catcher.new()
	catcher.checks = self
	tree.root.add_child(catcher)


func _run_cmd(caller: PlayerShape, line: String) -> String:
	return AdminConsole.run(caller, line)


func _spawn(world: Node, id: int, family: String, at: Vector2) -> PlayerShape:
	var progress := PlayerShape.sanitize_progress({
		"level": 3, "stats": {"vigor": 3, "mettle": 2, "force": 4, "torque": 3},
	})
	var p := PlayerShape.create({"id": id, "family": family, "sides": 4, "kind": "regular",
			"apex": 0, "luck": 0, "generation": 1, "progress": progress, "chest": [], "pos": at})
	world.add_child(p)
	return p


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: " + what)


## Stands in for the HUD, keeping what PlayerChat sends it.
class _Catcher extends Node:
	var checks: RefCounted

	func _ready() -> void:
		add_to_group(Hud.GROUP)

	func hear(speaker_id: int, speaker: String, text: String) -> void:
		checks._heard.append([speaker_id, speaker, text])

	func chat_notice(text: String) -> void:
		checks._notices.append(text)

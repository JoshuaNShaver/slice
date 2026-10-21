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
	var parsed := AdminConsole.parse("Player SET level 11 --id \"The Others\"")
	_check(parsed.words == ["player", "set", "level", "11"] and parsed.flags == {"id": "The Others"},
			"parse words, quotes and flags: %s" % parsed)
	_check(AdminConsole.parse("player list --online").flags == {"online": true}, "bare flag is true")
	_check(AdminConsole.parse("a --x=1 b").has("error"), "words after flags refused")
	_check(AdminConsole.parse("say \"open").has("error"), "unclosed quote refused")

	# Who may run commands.
	_check("Only admins" in AdminConsole.run(other, "\\player list"), "a player can't run commands")
	var their_help := AdminConsole.run(other, "\\help")
	_check("\\hello" in their_help and "\\bye" in their_help and not "\\player" in their_help,
			"a player's help lists hello and bye: %s" % their_help)
	_check(AdminConsole.run(other, "\\") == their_help, "so does a lone \\")
	_check("\\player" in _run_cmd(me, "\\help"), "help lists nouns")
	_check("levelup" in _run_cmd(me, "\\player help"), "noun help lists verbs")
	_check("Usage" in _run_cmd(me, "\\player set"), "set without words shows usage")
	_check("no --bogus" in _run_cmd(me, "\\player list --bogus"), "unknown flag refused")
	_check("no command" in _run_cmd(me, "\\nope"), "unknown noun refused")

	# Tab completion (log 0163) and \players.
	var done := AdminConsole.complete("\\pl", true)
	_check(done.line == "\\player" and done.options.is_empty(), "\\pl -> \\player (players too): %s" % done)
	_check(str(AdminConsole.complete("\\enem", true).options) == str(["enemies", "enemy"]),
			"enem lists enemies, enemy: %s" % AdminConsole.complete("\\enem", true))
	_check(AdminConsole.complete("\\enemy", true).line == "\\enemy ", "a whole word gets its space")
	_check(AdminConsole.complete("\\player le", true).line == "\\player levelup ", "verb completes")
	_check(AdminConsole.complete("\\player set l", true).line == "\\player set level ", "set field completes")
	_check(AdminConsole.complete("\\player set level 3 --i", true).line == "\\player set level 3 --id ", "flag completes")
	_check(AdminConsole.complete("\\diag l", false).line == "\\diag live ", "diag live for players")
	_check(AdminConsole.complete("\\pl", false).line == "\\pl", "players don't get admin nouns")
	_check(AdminConsole.complete("\\h", false).line == "\\hel", "h -> hel, the shared start")
	_check(str(AdminConsole.complete("\\hel", false).options) == str(["hello", "help"]),
			"hel lists hello, help: %s" % AdminConsole.complete("\\hel", false))
	_check(AdminConsole.complete("hi there", true).line == "hi there", "chat lines left alone")
	_check("2 online" in _run_cmd(me, "\\players"), "\\players lists players")

	# Short ids and finding players.
	var my_id := AdminConsole.short_id(1)
	var their_id := AdminConsole.short_id(2)
	var listing := _run_cmd(me, "\\player list")
	_check("2 online" in listing and "Admin_Al  (the Testers family" in listing
			and "The Others family  (level" in listing,
			"list shows both: %s" % listing)
	_check(my_id != their_id and my_id < 100 and their_id < 100, "short ids are small")
	_check("Others" in _run_cmd(me, "\\player get %d" % their_id), "get by short id")
	_check("generation" in _run_cmd(me, "\\player get oth"), "get by the start of a family name")
	_check("No one online" in _run_cmd(me, "\\player get 99"), "unknown id")

	# Changing players.
	other.inventory.equipped = PackedStringArray(["points_6", "", "", "", ""])
	other.stats.apply_bonuses("points_6", 1)
	var answer := _run_cmd(me, "\\player set level 7 --id %d" % their_id)
	_check(other.stats.level == 7 and "now 7" in answer, "set level up: %s" % answer)
	_check(me.stats.level == 3, "only the target changed")
	var gear_force: int = Gear.bonuses("points_6").force
	_run_cmd(me, "\\player set level 1 --id %d" % their_id)
	_check(other.stats.level == 1 and other.stats.force == gear_force and other.stats.vigor == 0,
			"set level down re-rolls from 1, keeps gear (force %d)" % other.stats.force)
	_check(other.stats.max_hp == Stats.max_hp(other.stats.vigor), "max hp matches vigor")
	answer = _run_cmd(me, "\\player levelup 3")
	_check(me.stats.level == 6 and "3 -> 6" in answer, "levelup yourself: %s" % answer)
	_run_cmd(me, "\\player levelup 99")
	_check(me.stats.level == Stats.MAX_LEVEL, "levelup stops at the top")
	_check("already at the top" in _run_cmd(me, "\\player levelup"), "levelup at the top says so")
	_run_cmd(me, "\\player set pay 1234 --id oth")
	_check(other.stats.pay == 1234, "set pay by name")
	_run_cmd(me, "\\player set hp 99999 --id oth")
	_check(other.stats.hp == other.stats.max_hp, "hp clamped to max")
	_check("Can't set" in _run_cmd(me, "\\player set luck 50"), "unlisted field refused")
	_check("whole number" in _run_cmd(me, "\\player set pay lots"), "non-number refused")

	# Enemies.
	var spawn := Barracks.spawn_points()[3]  # a sparring partner
	var e := Enemy.create(spawn.merged({"name": "E3"}))
	world.add_child(e)
	e.freeze = true
	await tree.physics_frame
	var enemies := _run_cmd(me, "\\enemies")
	_check("1 of 1" in enemies and "E3" in enemies and "sparring" in enemies and not "AWAY" in enemies,
			"\\enemies lists it at home: %s" % enemies)
	_check("\\enemies" in _run_cmd(me, "\\help"), "help lists the alias")
	_check("No enemies match" in _run_cmd(me, "\\enemy list --away"), "none away")
	e.position = spawn.pos + Vector2(3000, 0)
	_check("AWAY" in _run_cmd(me, "\\enemy list --away"), "one knocked far off is away")
	_check("home (" in _run_cmd(me, "\\enemy get e3"), "get by name")
	_check("No enemy" in _run_cmd(me, "\\enemy get E99"), "unknown enemy")
	e.queue_free()

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
	_check("\\diagnostics" in their_help, "a player's help lists diagnostics")
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
	_check(Diagnostics.parse("\\player list").is_empty() and Diagnostics.parse("hi").is_empty(), "others aren't parsed")
	_check("\\simulate" in their_help, "a player's help lists simulate")
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

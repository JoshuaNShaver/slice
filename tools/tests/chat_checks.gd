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

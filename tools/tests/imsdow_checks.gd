extends RefCounted
## Checks for test_imsdow.gd. Her lines are random, so each check asks
## whether what she said is in the list it should come from.

var tree: SceneTree
var _fails := 0
var _chat: ChatBox
var _her: ConsoleCompanion


func run() -> int:
	_chat = ChatBox.new()
	tree.root.add_child(_chat)
	await tree.process_frame
	_her = _chat.get("_companion")
	_her.set("_settings", (_her.get("_settings") as Dictionary).merged({"asleep_on_open": 0.0}, true))

	# Admins get imsdow.cfg's lines (log 0156).
	var role_before: String = Net.accounts.my_role
	Net.accounts.my_role = "admin"

	# Opening on a command makes the terminal; Enter on nothing doesn't leave.
	_chat.open("\\")
	await tree.process_frame
	_check(_chat.terminal, "a \\ line opens the terminal")
	_enter("")
	await tree.process_frame
	_check(_chat.is_open and _chat.terminal, "Enter on an empty line stays in the terminal")
	_chat.toggle()
	_check(_chat.is_open, "the chat key doesn't close the terminal")
	# In the terminal a line needs no \ (log 0196): it's sent with one.
	var sent: Array[String] = []
	_chat.line_entered.connect(func(line: String) -> void: sent.append(line))
	_enter("players quests")
	_enter("\\enemies")
	_check(str(sent) == str(["\\players quests", "\\enemies"]), "terminal lines are sent as commands: %s" % str(sent))
	_check(_chat.is_open and _chat.terminal, "a bare command stays in the terminal")
	var field: LineEdit = _chat.get("_field")
	field.text = "players qu"
	_chat.call("_complete")
	_check(field.text == "players quests ", "Tab completes without a \\: %s" % field.text)
	field.text = ""

	# Reactions to answers.
	_command("\\nope", "There's no command \"nope\". Try \\help.")
	_check(_said_from("unknown"), "unknown command: %s" % _speech())
	_command("\\nope", "There's no command \"nope\". Try \\help.")
	_check(_said_from("repeat"), "the same command twice: %s" % _speech())
	_command("\\enemies", "1 of 1 enemies:\n  E3  sparring  hp 170/170  at (0, 0)  4000 px from home  AWAY")
	_check(_said_from("stuck"), "a lost enemy: %s" % _speech())
	_command("players set level 3", "Admin_Al: level is now 3.")
	_check(_said_from("power"), "a player changed: %s" % _speech())

	# Asleep: commands get mumbles, the third wakes her.
	_her.call("_fall_asleep", "asleep")
	_check(_her.is_asleep(), "asleep")
	_command("\\help", "Commands...")
	_check(_said_from("mumbles") and _her.is_asleep(), "first command mumbled: %s" % _speech())
	_command("players", "1 online:")
	_check(_her.is_asleep(), "still asleep after two")
	_command("\\enemies", "0 of 0 enemies")
	_check(not _her.is_asleep() and _said_from("waking"), "the third wakes her: %s" % _speech())

	# Her title, and clicking her for something new (log 0149).
	_check((_her.get("_name_tag") as Label).text == "imsdow — the second architect",
			"name tag: %s" % (_her.get("_name_tag") as Label).text)
	var picture: Control = _her.get("_picture")
	_check(picture.mouse_filter == Control.MOUSE_FILTER_STOP, "her picture takes clicks")
	var all: Array = []
	for list in ["puns", "lore", "reflections", "blushing"]:
		all += (_her.get("_lines") as Dictionary).get(list, [])
	var changed := 0
	for i in 12:
		var before := _speech()
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		picture.gui_input.emit(click)
		if _speech() != before and _speech() in all:
			changed += 1
	_check(changed == 12, "every click rolls a new line (%d of 12)" % changed)

	# Blushing: most stop at the hearts (frame 3) with no line; about 1 in 10
	# goes on to frame 4 and says a blushing line (log 0151).
	var rare := 0
	var quiet_ok := true
	for i in 1000:
		_her.say("")
		var full: bool = _her.play("blush")
		var frames: Array = _her.get("_seq")
		if full:
			rare += 1
			quiet_ok = quiet_ok and 3 in frames and _said_from("blushing")
		else:
			quiet_ok = quiet_ok and not 3 in frames and _speech() == ""
	_check(rare > 60 and rare < 140, "about 1 in 10 blushes go to frame 4 (%d of 1000)" % rare)
	_check(quiet_ok, "only the frame-4 blushes say a line")
	var due: float = _her.get("_anims").blush.every.x
	_check(due >= 90.0, "she blushes by herself every 90 s or more (%d)" % due)

	# Every list in her lines file is read, not just the first few.
	var lines: Dictionary = _her.get("_lines")
	for list in ["reflections", "dozing", "unknown", "repeat", "stuck", "power", "late_night", "blushing", "goodbye"]:
		_check(lines.has(list), "lines has %s" % list)

	# \hello: she waves and says hi, and the terminal stays.
	_enter("\\hello")
	_check(_said_from("hello"), "\\hello says hello: %s" % _speech())
	_check(_chat.is_open and _chat.terminal, "\\hello stays in the terminal")

	# \bye: goodbye, a wave, then the terminal closes, leaving her line in chat.
	_enter("\\bye")
	_check(_said_from("goodbye"), "\\bye says goodbye: %s" % _speech())
	_check(_chat.is_open, "she gets a moment to say it")
	await tree.create_timer(ChatBox.BYE_TIME + 0.2).timeout
	_check(not _chat.is_open and not _chat.terminal, "then the terminal closes")
	_check(_last_log().begins_with(_her.display_name() + ": "), "her goodbye stays in chat: %s" % _last_log())

	# Esc closes the terminal at once, with a goodbye in chat.
	_chat.open("\\")
	await tree.process_frame
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	_chat.call("_on_field_input", esc)
	_check(not _chat.is_open, "Esc leaves the terminal")
	_check(_last_log().begins_with(_her.display_name() + ": "), "goodbye in chat after Esc too")

	# A phone's keyboard can set the text without text_changed.
	_chat.open()
	_chat.get("_field").text = "\\"
	await tree.process_frame
	_check(_chat.terminal, "a \\ typed without text_changed still opens the terminal")
	_chat.close()
	_chat.open()
	_enter("\\help")
	_check(_chat.terminal, "sending a \\ line opens the terminal")
	_chat.close()

	# Players who aren't admins get imsdow_non_admin.cfg's lines (log 0156).
	Net.accounts.my_role = "player"
	_chat.open("\\")
	await tree.process_frame
	_check(_her.get("_lines_from") == ConsoleCompanion.NON_ADMIN, "a player gets the non-admin lines")
	_check(_said_from("hello") or _said_from("asleep"), "she greets a player: %s" % _speech())
	_command("players", "Only admins can use these commands. Try help.")
	_check(_said_from("not_admin"), "an admin command from a player: %s" % _speech())
	_chat.close()
	Net.accounts.my_role = role_before

	_chat.queue_free()
	print("IMSDOW TEST: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	return _fails


func _enter(text: String) -> void:
	_chat.call("_on_submitted", text)


## A command and the server's answer to it.
func _command(line: String, answer: String) -> void:
	_enter(line)
	_chat.add_notice(answer)


func _speech() -> String:
	return (_her.get("_speech") as Label).text.trim_prefix("< ").trim_suffix(" >")


func _said_from(list: String) -> bool:
	return _speech() in (_her.get("_lines") as Dictionary).get(list, [])


func _last_log() -> String:
	var log: VBoxContainer = _chat.get("_log")
	return (log.get_child(log.get_child_count() - 1) as Label).text


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", what)

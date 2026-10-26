class_name AdminConsole
extends RefCounted
## Admin commands, typed into the admin terminal (design logs 0125, 0196).
## Server only.
##
##   <noun> [<verb> | <sub-noun> <verb>] [words...] [--flag value | --flag]
##
## like a command line. Nouns are plural, and each is the root of the
## commands acting on that kind of thing: `players`, `players get 3`,
## `players set level 11 --id 3`, `players quests start bootcamp`. A noun
## alone runs its DEFAULT verb (list). `help` lists the nouns, `players
## help` a noun's verbs, `--help` on a verb its usage. Flags go after the
## words; a flag with no value is true. Quote words with spaces: "two words".
##
## A `\` opens the terminal; in it, a line needs no `\` (ChatBox adds it),
## so lines reach the server as "\players".
##
## Only admins may run them (Accounts.role_of): the player at an offline or
## hosting machine, or an account whose role is "admin" or "first_architect"
## in the database,
## which only a database update can set. Every command is logged.
##
## Each noun is a script in NOUNS with HELP, VERBS ({verb: {"usage",
## "help", "flags"}}), optionally DEFAULT (the verb run when none is given;
## "list" if left out) and words_for(verb) -> Array[String] (what Tab offers
## for a verb's first word), and a run_<verb>(caller, words, flags) ->
## String per verb. A VERBS entry {"noun": script, "help"} is a sub-noun
## instead, with the same parts (`players quests`).

const ESCAPE := "\\"
const NOUNS := {
	"players": preload("res://scripts/admin/player_commands.gd"),
	"enemies": preload("res://scripts/admin/enemy_commands.gd"),
	"quests": preload("res://scripts/admin/quest_commands.gd"),
	"items": preload("res://scripts/admin/item_commands.gd"),
	"resources": preload("res://scripts/admin/resource_commands.gd"),
}
## Roles that may run admin commands (Accounts.role_of).
const ADMIN_ROLES: Array[String] = ["admin", "first_architect"]
## The terminal's own commands (ChatBox) and Diagnostics', which anyone may
## type; for Tab to complete (log 0163).
const PLAYER_WORDS: Array[String] = ["help", "hello", "bye", "diagnostics", "diag", "simulate", "view"]
## What can follow these first words: {word: [next words]}, then for
## deeper words "word1 word2": [...].
const FOLLOWERS := {
	"diagnostics": ["live"], "diag": ["live"], "simulate": ["lag", "stalls", "prod", "off"], "simulate lag": ["off"], "simulate stalls": ["off"],
	"view": ["2d", "eyes", "eye", "fov", "range"], "view 2d": ["eyes", "eye"], "view eyes": ["2d"], "view eye": ["2d"],
}

## Peer id -> short id, the small number `players` shows. Handed out
## in join order while the server runs.
static var _short_ids := {}
static var _next_short_id := 1


static func is_admin(peer_id: int) -> bool:
	return Net.accounts.role_of(peer_id) in ADMIN_ROLES


## A small number for this peer, the same for as long as the server runs.
static func short_id(peer_id: int) -> int:
	if not _short_ids.has(peer_id):
		_short_ids[peer_id] = _next_short_id
		_next_short_id += 1
	return _short_ids[peer_id]


## Runs one line ("\players") for `caller`; returns the answer.
static func run(caller: PlayerShape, line: String) -> String:
	if not is_admin(caller.peer_id):
		var asked := line.trim_prefix(ESCAPE).strip_edges().to_lower()
		if asked == "" or asked == "help":
			return player_help()
		return "Only admins can use these commands. Try help."
	var account: String = Net.accounts.sessions.get(caller.peer_id, {}).get("account", "?")
	print("[admin] %s (%s): %s" % [PlayerChat.name_of(caller), account, line])
	var parsed := parse(line.trim_prefix(ESCAPE))
	if parsed.has("error"):
		return parsed.error
	var words: Array[String] = parsed.words
	var flags: Dictionary = parsed.flags
	if words.is_empty() or words[0].to_lower() == "help":
		return help()
	var noun := words[0].to_lower()
	if not NOUNS.has(noun):
		return "There's no command \"%s\". Try help." % words[0]
	var rest: Array[String] = []
	rest.assign(words.slice(1))
	return _run_noun(caller, noun, NOUNS[noun], rest, flags)


## Runs the rest of a line on `script`, the noun (or sub-noun) at `path`
## ("players quests").
static func _run_noun(caller: PlayerShape, path: String, script: GDScript, words: Array[String],
		flags: Dictionary) -> String:
	var verbs: Dictionary = script.VERBS
	var name := words[0].to_lower() if not words.is_empty() else default_verb(script)
	if name == "help" or (words.is_empty() and flags.has("help")):
		return noun_help(path, script)
	if not verbs.has(name):
		return "%s has no \"%s\". Try %s help." % [path, name, path]
	var verb: Dictionary = verbs[name]
	var rest: Array[String] = []
	rest.assign(words.slice(1))
	if verb.has("noun"):
		return _run_noun(caller, "%s %s" % [path, name], verb.noun, rest, flags)
	if flags.has("help"):
		return "%s\n%s" % [verb.usage, verb.help]
	for flag: String in flags:
		if flag not in verb.flags:
			return "%s %s has no --%s.\nUsage: %s" % [path, name, flag, verb.usage]
	return script.new().call("run_" + name, caller, rest, flags)


## The verb a noun runs alone: its DEFAULT, or list.
static func default_verb(script: GDScript) -> String:
	var verb: Variant = script.get("DEFAULT")
	return str(verb) if verb != null else "list"


## Tab in the terminal (log 0163): completes the last word of `line`
## ("\\pl" -> "\\players "). Returns {"line": the new line, "options": the
## words it could be, when there's more than one}. `admin`: whether the
## nouns are offered, as only admins may use them.
static func complete(line: String, admin: bool) -> Dictionary:
	if not line.begins_with(ESCAPE):
		return {"line": line, "options": []}
	var body := line.substr(ESCAPE.length())
	var words := body.split(" ")  # the last one is what's being typed, maybe ""
	var typed := words[-1]
	var before: Array[String] = []
	for w in words.slice(0, words.size() - 1):
		if w != "":
			before.append(w.to_lower())
	var choices := _choices(before, admin)
	var matches: Array[String] = []
	for c in choices:
		if c.begins_with(typed.to_lower()):
			matches.append(c)
	if matches.is_empty():
		return {"line": line, "options": []}
	var head := line.substr(0, line.length() - typed.length())
	if matches.size() == 1:
		return {"line": head + matches[0] + " ", "options": []}
	var common := matches[0]
	for m in matches:
		while not m.begins_with(common):
			common = common.left(common.length() - 1)
	if common.length() > typed.length():
		return {"line": head + common, "options": []}
	return {"line": line, "options": matches}


## The words that can come after `before` (already typed, lowercase).
static func _choices(before: Array[String], admin: bool) -> Array[String]:
	var out: Array[String] = []
	if before.is_empty():
		out.assign(PLAYER_WORDS)
		if admin:
			for noun: String in NOUNS:
				out.append(noun)
		out.sort()
		return out
	var key := " ".join(before)
	if FOLLOWERS.has(key):
		out.assign(FOLLOWERS[key])
		return out
	if not admin or not NOUNS.has(before[0]):
		return out
	var script: GDScript = NOUNS[before[0]]
	var i := 1
	while i < before.size():
		var verbs: Dictionary = script.VERBS
		if not verbs.has(before[i]):
			return out
		var verb: Dictionary = verbs[before[i]]
		if verb.has("noun"):
			script = verb.noun
			i += 1
			continue
		for flag: String in verb.flags:
			out.append("--" + flag)
		out.append("--help")
		var commands: Object = script.new()
		if before.size() == i + 1 and commands.has_method("words_for"):
			out.append_array(commands.call("words_for", before[i]))
		return out
	out.assign((script.VERBS as Dictionary).keys())
	out.append("help")
	return out


## Splits "set level 11 --id 3" (case kept) into {"words": ["set", "level", "11"],
## "flags": {"id": "3"}}, or {"error": String}.
static func parse(text: String) -> Dictionary:
	var tokens: Array[String] = []
	var token := ""
	var quoted := false
	var started := false
	for c in text:
		if c == "\"":
			quoted = not quoted
			started = true
		elif c == " " and not quoted:
			if started:
				tokens.append(token)
			token = ""
			started = false
		else:
			token += c
			started = true
	if quoted:
		return {"error": "A quote is missing its end."}
	if started:
		tokens.append(token)
	var words: Array[String] = []
	var flags := {}
	var i := 0
	while i < tokens.size():
		var t := tokens[i]
		if t.begins_with("--") and t.length() > 2:
			var flag := t.substr(2)
			if "=" in flag:
				flags[flag.get_slice("=", 0)] = flag.substr(flag.find("=") + 1)
			elif i + 1 < tokens.size() and not tokens[i + 1].begins_with("--"):
				flags[flag] = tokens[i + 1]
				i += 1
			else:
				flags[flag] = true
		elif not flags.is_empty():
			return {"error": "Put flags (--%s) after the other words." % flags.keys()[0]}
		else:
			words.append(t)
		i += 1
	return {"words": words, "flags": flags}


static func help() -> String:
	var lines: Array[String] = ["Commands (<command> help for more):"]
	for noun: String in NOUNS:
		lines.append("  %s: %s" % [noun, NOUNS[noun].HELP])
	lines.append("  %s: %s" % [Diagnostics.COMMANDS[0].trim_prefix(ESCAPE), Diagnostics.HELP])
	lines.append("  %s %s" % [Diagnostics.SIMULATE.trim_prefix(ESCAPE), Diagnostics.SIMULATE_HELP])
	lines.append("  %s %s" % [FlatView.COMMAND.trim_prefix(ESCAPE), FlatView.HELP])
	return "\n".join(lines)


## help for players who aren't admins (log 0153): the terminal's own
## commands, which ChatBox handles and never sends.
static func player_help() -> String:
	return "\n".join([
		"Commands:",
		"  hello: imsdow says hi",
		"  bye: say goodbye and close the terminal",
		"  %s: %s" % [Diagnostics.COMMANDS[0].trim_prefix(ESCAPE), Diagnostics.HELP],
		"  %s %s" % [Diagnostics.SIMULATE.trim_prefix(ESCAPE), Diagnostics.SIMULATE_HELP],
		"  %s %s" % [FlatView.COMMAND.trim_prefix(ESCAPE), FlatView.HELP],
	])


## A noun's verbs (and its sub-nouns'), `path` being how it's typed.
static func noun_help(path: String, script: GDScript) -> String:
	var lines: Array[String] = ["%s: %s (alone: %s %s)" % [path, script.HELP, path, default_verb(script)]]
	var verbs: Dictionary = script.VERBS
	for name: String in verbs:
		var verb: Dictionary = verbs[name]
		if verb.has("noun"):
			lines.append("  %s %s ...\n      %s (%s %s help)" % [path, name, verb.help, path, name])
		else:
			lines.append("  %s\n      %s" % [verb.usage, verb.help])
	return "\n".join(lines)
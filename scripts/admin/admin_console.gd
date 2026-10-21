class_name AdminConsole
extends RefCounted
## Admin commands, typed into chat (design log 0125). Server only.
##
##   \<noun> <verb> [words...] [--flag value | --flag]
##
## like a command line: `\player list`, `\player get 3`,
## `\player set level 11 --id 3`. `\help` lists the nouns, `\player help`
## a noun's verbs, `--help` on a verb its usage. Flags go after the words;
## a flag with no value is true. Quote words with spaces: "two words".
##
## Only admins may run them (Accounts.role_of): the player at an offline or
## hosting machine, or an account whose role is "admin" or "first_architect"
## in the database,
## which only a database update can set. Every command is logged.
##
## Each noun is a script in NOUNS with HELP, VERBS ({verb: {"usage",
## "help", "flags"}}) and a run_<verb>(caller, words, flags) -> String.

const ESCAPE := "\\"
const NOUNS := {
	"player": preload("res://scripts/admin/player_commands.gd"),
	"enemy": preload("res://scripts/admin/enemy_commands.gd"),
}
## Short forms: the first word becomes these words.
const ALIASES := {
	"enemies": ["enemy", "list"],
	"players": ["player", "list"],
}
## Roles that may run admin commands (Accounts.role_of).
const ADMIN_ROLES: Array[String] = ["admin", "first_architect"]
## The terminal's own commands (ChatBox) and Diagnostics', which anyone may
## type; for Tab to complete (log 0163).
const PLAYER_WORDS: Array[String] = ["help", "hello", "bye", "diagnostics", "diag", "simulate"]
## What can follow these first words: {word: [next words]}, then for
## deeper words "word1 word2": [...].
const FOLLOWERS := {
	"diagnostics": ["live"], "diag": ["live"], "simulate": ["lag", "stalls", "prod", "off"], "simulate lag": ["off"], "simulate stalls": ["off"],
}

## Peer id -> short id, the small number `\player list` shows. Handed out
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


## Runs one line ("\player list") for `caller`; returns the answer.
static func run(caller: PlayerShape, line: String) -> String:
	if not is_admin(caller.peer_id):
		var asked := line.trim_prefix(ESCAPE).strip_edges().to_lower()
		if asked == "" or asked == "help":
			return player_help()
		return "Only admins can use %s commands. Try %shelp." % [ESCAPE, ESCAPE]
	var account: String = Net.accounts.sessions.get(caller.peer_id, {}).get("account", "?")
	print("[admin] %s (%s): %s" % [PlayerChat.name_of(caller), account, line])
	var parsed := parse(line.trim_prefix(ESCAPE))
	if parsed.has("error"):
		return parsed.error
	var words: Array[String] = parsed.words
	var flags: Dictionary = parsed.flags
	if not words.is_empty() and ALIASES.has(words[0]):
		var full: Array[String] = []
		full.assign(ALIASES[words[0]])
		full.append_array(words.slice(1))
		words = full
	if words.is_empty() or words[0] == "help":
		return help()
	if not NOUNS.has(words[0]):
		return "There's no command \"%s\". Try %shelp." % [words[0], ESCAPE]
	var noun: GDScript = NOUNS[words[0]]
	if words.size() < 2 or words[1] == "help":
		return noun_help(words[0])
	var verbs: Dictionary = noun.VERBS
	if not verbs.has(words[1]):
		return "%s has no \"%s\". Try %s%s help." % [words[0], words[1], ESCAPE, words[0]]
	var verb: Dictionary = verbs[words[1]]
	if flags.has("help"):
		return "%s%s\n%s" % [ESCAPE, verb.usage, verb.help]
	for flag: String in flags:
		if flag not in verb.flags:
			return "%s%s %s has no --%s.\nUsage: %s%s" % [ESCAPE, words[0], words[1], flag, ESCAPE, verb.usage]
	var rest: Array[String] = []
	rest.assign(words.slice(2))
	return noun.new().call("run_" + words[1], caller, rest, flags)


## Tab in the terminal (log 0163): completes the last word of `line`
## ("\\pl" -> "\\player "). Returns {"line": the new line, "options": the
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
			for alias: String in ALIASES:
				out.append(alias)
		out.sort()
		return out
	var key := " ".join(before)
	if FOLLOWERS.has(key):
		out.assign(FOLLOWERS[key])
		return out
	if not admin or not NOUNS.has(before[0]):
		return out
	var verbs: Dictionary = NOUNS[before[0]].VERBS
	if before.size() == 1:
		out.assign(verbs.keys())
		out.append("help")
		return out
	if not verbs.has(before[1]):
		return out
	for flag: String in verbs[before[1]].flags:
		out.append("--" + flag)
	out.append("--help")
	if before.size() == 2 and before[0] == "player" and before[1] == "set":
		for field in PlayerCommands.FIELDS:
			out.append(field)
	return out


## Splits "set level 11 --id 3" into {"words": ["set", "level", "11"],
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
			words.append(t.to_lower() if words.size() < 2 else t)
		i += 1
	return {"words": words, "flags": flags}


static func help() -> String:
	var lines: Array[String] = ["Commands (%s<command> help for more):" % ESCAPE]
	for noun: String in NOUNS:
		lines.append("  %s%s: %s" % [ESCAPE, noun, NOUNS[noun].HELP])
	for alias: String in ALIASES:
		lines.append("  %s%s: short for %s%s" % [ESCAPE, alias, ESCAPE, " ".join(ALIASES[alias])])
	lines.append("  %s: %s" % [Diagnostics.COMMANDS[0], Diagnostics.HELP])
	lines.append("  %s %s" % [Diagnostics.SIMULATE, Diagnostics.SIMULATE_HELP])
	return "\n".join(lines)


## \help for players who aren't admins (log 0153): the terminal's own
## commands, which ChatBox handles and never sends.
static func player_help() -> String:
	return "\n".join([
		"Commands:",
		"  %shello: imsdow says hi" % ESCAPE,
		"  %sbye: say goodbye and close the terminal" % ESCAPE,
		"  %s: %s" % [Diagnostics.COMMANDS[0], Diagnostics.HELP],
		"  %s %s" % [Diagnostics.SIMULATE, Diagnostics.SIMULATE_HELP],
	])


static func noun_help(noun: String) -> String:
	var script: GDScript = NOUNS[noun]
	var lines: Array[String] = ["%s%s: %s" % [ESCAPE, noun, script.HELP]]
	var verbs: Dictionary = script.VERBS
	for verb: String in verbs:
		lines.append("  %s%s\n      %s" % [ESCAPE, verbs[verb].usage, verbs[verb].help])
	return "\n".join(lines)

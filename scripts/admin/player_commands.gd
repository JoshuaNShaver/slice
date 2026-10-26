class_name PlayerCommands
extends RefCounted
## `players ...` admin commands (design logs 0125, 0196); see AdminConsole.
## `players` alone lists them.
##
## `who` is a short id (from `players`), a name (a username or a
## family's name, or the start of one), or `me`. Left out, it's you.

const HELP := "find and change players"
const VERBS := {
	"list": {"usage": "players list", "flags": ["online"],
			"help": "Players online now: short id, name, family and level."},
	"get": {"usage": "players get [who]", "flags": ["id"],
			"help": "One player's details."},
	"set": {"usage": "players set <field> <value> [--id who]", "flags": ["id"],
			"help": "Sets level, xp, chits, coins, hp or sides. A new level rolls its stat gains, as leveling does; new sides keep the heir's level and gear."},
	"levelup": {"usage": "players levelup [count] [--id who]", "flags": ["id"],
			"help": "Levels up count times (default 1), rolling stat gains."},
	"quests": {"noun": preload("res://scripts/admin/player_quest_commands.gd"),
			"help": "a player's quests: list, get, start, set, delete"},
}
const FIELDS: Array[String] = ["level", "xp", "chits", "coins", "hp", "sides"]


func words_for(verb: String) -> Array[String]:
	return FIELDS if verb == "set" else ([] as Array[String])


func run_list(caller: PlayerShape, words: Array[String], _flags: Dictionary) -> String:
	if not words.is_empty():
		return "Usage: " + VERBS.list.usage
	var shapes := _players(caller)
	if shapes.is_empty():
		return "No one is playing."
	var lines: Array[String] = ["%d online:" % shapes.size()]
	for p in shapes:
		var name := PlayerChat.name_of(p)
		var family := "" if name.ends_with(" family") else "the %s family, " % p.family_name
		lines.append("  %d  %s  (%slevel %d)" % [AdminConsole.short_id(p.peer_id), name, family, p.stats.level])
	return "\n".join(lines)


func run_get(caller: PlayerShape, words: Array[String], flags: Dictionary) -> String:
	if words.size() > 1 or (words.size() == 1 and flags.has("id")):
		return "Usage: " + VERBS.get.usage
	var found := find(caller, words[0] if words.size() == 1 else str(flags.get("id", "")))
	if found.has("error"):
		return found.error
	var p: PlayerShape = found.player
	var s := p.stats
	var place: Dictionary = Regions.at(p.position)
	var session: Dictionary = Net.accounts.sessions.get(p.peer_id, {})
	var xp_line := "max" if s.level >= Stats.MAX_LEVEL else "%d/%d" % [s.xp, Stats.xp_to_next(s.level)]
	return "\n".join([
		"%d  %s  (%s)" % [AdminConsole.short_id(p.peer_id), PlayerChat.name_of(p),
				Net.accounts.role_of(p.peer_id)],
		"  the %s family, generation %d: %s" % [p.family_name, p.generation,
				Family.describe_shape(p.sides, p.kind, p.apex)],
		"  level %d, xp %s, hp %d/%d, chits %d, coins %d" % [s.level, xp_line, s.hp, s.max_hp, s.chits, s.coins],
		"  vigor %d, mettle %d, force %d, torque %d, rigidity %d, luck %d" % [s.vigor, s.mettle,
				s.force, s.torque, s.rigidity, s.luck],
		"  at %s (%d, %d)" % [place.get("name", "between places"), int(p.position.x), int(p.position.y)],
		"  account %s" % session.get("account", "?"),
	])


func run_set(caller: PlayerShape, words: Array[String], flags: Dictionary) -> String:
	if words.size() != 2:
		return "Usage: %s\nFields: %s" % [VERBS.set.usage, ", ".join(FIELDS)]
	var field := words[0].to_lower()
	if field not in FIELDS:
		return "Can't set \"%s\". Fields: %s" % [field, ", ".join(FIELDS)]
	if not words[1].is_valid_int():
		return "\"%s\" isn't a whole number." % words[1]
	var found := find(caller, str(flags.get("id", "")))
	if found.has("error"):
		return found.error
	var p: PlayerShape = found.player
	var s := p.stats
	var value := words[1].to_int()
	match field:
		"level":
			s.set_level(value, _rng())
			value = s.level
		"xp":
			if s.level >= Stats.MAX_LEVEL:
				return "%s is at the top level; there's no xp to set." % PlayerChat.name_of(p)
			s.xp = 0
			s.add_xp(maxi(value, 0))  # levels up if it's enough
			value = s.xp
		"chits":
			s.chits = clampi(value, 0, PlayerStats.MAX_CHITS)
			value = s.chits
		"coins":
			s.coins = clampi(value, 0, PlayerStats.MAX_CHITS)
			value = s.coins
		"hp":
			s.hp = clampi(value, 1, s.max_hp)
			value = s.hp
		"sides":
			if value < 3 or value > Net.MAX_SIDES:
				return "Sides must be 3 to %d." % Net.MAX_SIDES
			p.reshape(value)
			return "%s is now %s." % [PlayerChat.name_of(p),
					Family.with_article(Family.describe_shape(p.sides, p.kind, p.apex))]
	return "%s: %s is now %d%s." % [PlayerChat.name_of(p), field, value,
			" (level %d)" % s.level if field == "xp" else ""]


func run_levelup(caller: PlayerShape, words: Array[String], flags: Dictionary) -> String:
	if words.size() > 1 or (words.size() == 1 and not words[0].is_valid_int()):
		return "Usage: " + VERBS.levelup.usage
	var found := find(caller, str(flags.get("id", "")))
	if found.has("error"):
		return found.error
	var p: PlayerShape = found.player
	var count := clampi(words[0].to_int() if words.size() == 1 else 1, 1, Stats.MAX_LEVEL)
	var before := p.stats.level
	p.stats.set_level(before + count, _rng())
	if p.stats.level == before:
		return "%s is already at the top level (%d)." % [PlayerChat.name_of(p), before]
	return "%s: level %d -> %d." % [PlayerChat.name_of(p), before, p.stats.level]


## Everyone in the world, by short id.
static func _players(caller: PlayerShape) -> Array[PlayerShape]:
	var list: Array[PlayerShape] = []
	for node in caller.get_tree().get_nodes_in_group(PlayerShape.GROUP):
		list.append(node as PlayerShape)
	list.sort_custom(func(a: PlayerShape, b: PlayerShape) -> bool:
		return AdminConsole.short_id(a.peer_id) < AdminConsole.short_id(b.peer_id))
	return list


## {"player": PlayerShape} or {"error": String}. "" or "me" is the caller.
## `who` as `players` explains.
static func find(caller: PlayerShape, who: String) -> Dictionary:
	who = who.strip_edges()
	if who == "" or who.to_lower() in ["me", "self"]:
		return {"player": caller}
	var shapes := _players(caller)
	if who.is_valid_int():
		for p in shapes:
			if AdminConsole.short_id(p.peer_id) == who.to_int():
				return {"player": p}
		return {"error": "No one online has id %s. Try players." % who}
	var wanted := who.to_lower()
	var starts: Array[PlayerShape] = []
	for p in shapes:
		var names := [PlayerChat.name_of(p).to_lower(), p.family_name.to_lower()]
		if wanted in names:
			return {"player": p}
		for n: String in names:
			if n.begins_with(wanted) or n.trim_prefix("the ").begins_with(wanted):
				starts.append(p)
				break
	if starts.size() == 1:
		return {"player": starts[0]}
	if starts.is_empty():
		return {"error": "No one online is called \"%s\". Try players." % who}
	return {"error": "\"%s\" could be %d players; use a short id." % [who, starts.size()]}


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng

class_name EnemyCommands
extends RefCounted
## `\enemy ...` admin commands (design log 0137); see AdminConsole.
## `\enemies` is short for `\enemy list`.
##
## For finding enemies that went missing: each one's place, health, and how
## far it is from home. "AWAY" marks one outside the area it guards and far
## from home, which shouldn't last unless it's stuck.

const HELP := "find enemies (and ones that are stuck)"
const VERBS := {
	"list": {"usage": "enemy list [--away] [--type name]", "flags": ["away", "type"],
			"help": "Every enemy: name, type, hp, where it is, how far from home. --away: only ones away from home."},
	"get": {"usage": "enemy get <name>", "flags": [],
			"help": "One enemy's details, by the name \\enemy list shows (E3, Mission1_4)."},
}
## px from home that counts as away, if it's outside its area too.
const AWAY := 300.0


func run_list(caller: PlayerShape, words: Array[String], flags: Dictionary) -> String:
	if not words.is_empty():
		return "Usage: \\" + VERBS.list.usage
	var all := _enemies(caller)
	var shown: Array[Enemy] = []
	for e in all:
		if flags.has("away") and not is_away(e):
			continue
		if flags.has("type") and e.type != str(flags.type):
			continue
		shown.append(e)
	if shown.is_empty():
		return "No enemies%s (of %d)." % [" match" if not flags.is_empty() else "", all.size()]
	var lines: Array[String] = ["%d of %d enemies:" % [shown.size(), all.size()]]
	for e in shown:
		lines.append("  %s" % _summary(e))
	return "\n".join(lines)


func run_get(caller: PlayerShape, words: Array[String], _flags: Dictionary) -> String:
	if words.size() != 1:
		return "Usage: \\" + VERBS.get.usage
	for e in _enemies(caller):
		if String(e.name).to_lower() == words[0].to_lower():
			var place: Dictionary = Regions.at(e.position)
			return "\n".join([
				_summary(e),
				"  %s, at %s" % [e.info().get("name", e.type), place.get("name", "between places")],
				"  home (%d, %d), area %s" % [int(e.home.x), int(e.home.y), _rect(e.room)],
				"  moving (%d, %d) px/s, spinning %.1f" % [int(e.linear_velocity.x),
						int(e.linear_velocity.y), e.angular_velocity],
				"  %s" % ("frozen" if e.freeze else ("asleep" if e.sleeping else "awake")),
			])
	return "No enemy is called \"%s\". Try \\enemy list." % words[0]


## Outside the area it guards and far from home.
static func is_away(e: Enemy) -> bool:
	var in_room := e.room.has_area() and e.room.has_point(e.position)
	return not in_room and e.position.distance_to(e.home) > AWAY


func _summary(e: Enemy) -> String:
	return "%-12s %-10s hp %d/%d  at (%d, %d)  %d px from home%s" % [e.name, e.type, e.hp,
			e.max_hp, int(e.position.x), int(e.position.y), int(e.position.distance_to(e.home)),
			"  AWAY" if is_away(e) else ""]


func _rect(r: Rect2) -> String:
	if not r.has_area():
		return "none"
	return "(%d, %d) to (%d, %d)" % [int(r.position.x), int(r.position.y), int(r.end.x), int(r.end.y)]


## Every enemy in the world, by name.
func _enemies(caller: PlayerShape) -> Array[Enemy]:
	var list: Array[Enemy] = []
	for node in caller.get_tree().get_nodes_in_group(Enemy.GROUP):
		list.append(node as Enemy)
	list.sort_custom(func(a: Enemy, b: Enemy) -> bool: return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)
	return list

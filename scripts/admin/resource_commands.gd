class_name ResourceCommands
extends RefCounted
## `resources ...` admin commands (log 0217); see AdminConsole.
## `resources` alone lists them.
##
## World resources (WorldResource): the Logging Isle's trees (T0, T1...)
## and the Quarry Isle's ore rocks (O0...). `which` is a name, a pattern
## with * (T*, O1*), or `all`.

const HELP := "trees and ore rocks: list, deplete, regrow"
const VERBS := {
	"list": {"usage": "resources list [which] [--kind tree|ore] [--felled] [--standing]",
			"flags": ["kind", "felled", "standing"],
			"help": "Every tree and ore rock: name, kind, health left or when it grows back, where, how far from you."},
	"deplete": {"usage": "resources deplete <which> [--kind tree|ore] [--id who] [--bag]",
			"flags": ["kind", "id", "bag"],
			"help": "Fells trees and quarries rocks at once. Their drops go to who (you if left out): on the ground beside each, or with --bag in the bag (the rest on the ground)."},
	"regrow": {"usage": "resources regrow <which> [--kind tree|ore]", "flags": ["kind"],
			"help": "Grows spent trees and rocks back now."},
}
const KINDS: Array[String] = ["tree", "ore"]


func words_for(_verb: String) -> Array[String]:
	return ["all"] as Array[String]


func run_list(caller: PlayerShape, words: Array[String], flags: Dictionary) -> String:
	if words.size() > 1:
		return "Usage: " + VERBS.list.usage
	var picked := _pick(caller, words[0] if words.size() == 1 else "all", flags)
	if picked.has("error"):
		return picked.error
	var shown: Array[WorldResource] = []
	for r: WorldResource in picked.list:
		if flags.has("felled") and not r.felled:
			continue
		if flags.has("standing") and r.felled:
			continue
		shown.append(r)
	if shown.is_empty():
		return "None match (of %d)." % picked.all
	var lines: Array[String] = ["%d of %d resources:" % [shown.size(), picked.all]]
	for r in shown:
		var state := ("spent, back in %s" % _time(r.regrow_left())) if r.felled \
				else "%d/%d health" % [r.health_left(), r.health]
		var place: Dictionary = Regions.at(r.position)
		lines.append("  %s  %s  %s  at %s (%d, %d), %d px away" % [r.name, r.kind(), state,
				place.get("name", "between places"), int(r.position.x), int(r.position.y),
				int(r.position.distance_to(caller.position))])
	return "\n".join(lines)


func run_deplete(caller: PlayerShape, words: Array[String], flags: Dictionary) -> String:
	if words.size() != 1:
		return "Usage: " + VERBS.deplete.usage
	var picked := _pick(caller, words[0], flags)
	if picked.has("error"):
		return picked.error
	var found := PlayerCommands.find(caller, str(flags.get("id", "")))
	if found.has("error"):
		return found.error
	var who: PlayerShape = found.player
	var spent := {"tree": 0, "ore": 0}
	var items := {}
	var dropped := 0
	var bagged := 0
	for r: WorldResource in picked.list:
		if r.felled:
			continue
		var got := r.deplete(who, flags.has("bag"))
		spent[r.kind()] += 1
		dropped += got.dropped
		bagged += got.bagged
		items[r.item] = int(items.get(r.item, 0)) + got.dropped + got.bagged
	if spent.tree + spent.ore == 0:
		return "Nothing to deplete: all %d were already spent." % picked.list.size()
	return _report(who, spent, items, dropped, bagged)


func run_regrow(caller: PlayerShape, words: Array[String], flags: Dictionary) -> String:
	if words.size() != 1:
		return "Usage: " + VERBS.regrow.usage
	var picked := _pick(caller, words[0], flags)
	if picked.has("error"):
		return picked.error
	var grown := 0
	for r: WorldResource in picked.list:
		if r.regrow_now():
			grown += 1
	if grown == 0:
		return "Nothing to regrow: all %d are standing." % picked.list.size()
	return "Grew back %d of %d." % [grown, picked.list.size()]


static func _report(who: PlayerShape, spent: Dictionary, items: Dictionary,
		dropped: int, bagged: int) -> String:
	var done: Array[String] = []
	if spent.tree > 0:
		done.append("felled %d tree%s" % [spent.tree, "" if spent.tree == 1 else "s"])
	if spent.ore > 0:
		done.append("quarried %d rock%s" % [spent.ore, "" if spent.ore == 1 else "s"])
	var made: Array[String] = []
	for it: String in items:
		if items[it] > 0:
			made.append("%d × %s" % [items[it], Gear.item_name(it)])
	var where: Array[String] = []
	if bagged > 0:
		where.append("%d in the bag" % bagged)
	if dropped > 0:
		where.append("%d on the ground" % dropped)
	var line := " and ".join(done)
	line = line[0].to_upper() + line.substr(1)
	if made.is_empty():
		return "%s." % line
	return "%s: %s gets %s (%s)." % [line, PlayerChat.name_of(who), ", ".join(made), ", ".join(where)]


## {"list": [WorldResource], "all": how many there are} or {"error"}.
static func _pick(caller: PlayerShape, which: String, flags: Dictionary) -> Dictionary:
	var kind := str(flags.get("kind", ""))
	if flags.has("kind") and kind not in KINDS:
		return {"error": "--kind is tree or ore."}
	var all: Array[WorldResource] = []
	for node in caller.get_tree().get_nodes_in_group(WorldResource.GROUP):
		all.append(node as WorldResource)
	all.sort_custom(func(a: WorldResource, b: WorldResource) -> bool:
		return a.name.naturalnocasecmp_to(b.name) < 0)
	var list: Array[WorldResource] = []
	for r in all:
		if kind != "" and r.kind() != kind:
			continue
		if which.to_lower() == "all" or String(r.name).matchn(which):
			list.append(r)
	if list.is_empty():
		return {"error": "No %s called \"%s\" (of %d). Try resources." % [
				kind if kind != "" else "resource", which, all.size()]}
	return {"list": list, "all": all.size()}


static func _time(seconds: float) -> String:
	var s := ceili(seconds)
	return "%d:%02d" % [s / 60, s % 60]

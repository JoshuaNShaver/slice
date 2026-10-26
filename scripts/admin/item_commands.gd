class_name ItemCommands
extends RefCounted
## `items ...` admin commands (log 0214); see AdminConsole. `items` alone
## lists every kind of item.
##
## Items are the strings bags hold (Gear): "points_9", "points_9+3",
## "potion", "note" (notes stack: `items create note 30`).

const HELP := "find items and make them"
const VERBS := {
	"list": {"usage": "items list [search]", "flags": [],
			"help": "Every kind of item: id and name. search matches either, any case; * matches anything (*steel*, points_*, *cert*)."},
	"create": {"usage": "items create <item> [count] [--id who]", "flags": ["id"],
			"help": "Puts count (default 1) of an item in a player's bag. Gear may name an upgrade: points_9+3."},
}
const MAX_COUNT := 99


func words_for(verb: String) -> Array[String]:
	return catalog() if verb == "create" else ([] as Array[String])


func run_list(_caller: PlayerShape, words: Array[String], _flags: Dictionary) -> String:
	if words.size() > 1:
		return "Usage: %s (quote a search with spaces)" % VERBS.list.usage
	var search := words[0] if words.size() == 1 else ""
	var all := catalog()
	var shown: Array[String] = []
	for it in all:
		if matches(it, search):
			shown.append(it)
	if shown.is_empty():
		return "No items match \"%s\" (of %d)." % [search, all.size()]
	var lines: Array[String] = ["%d of %d items:" % [shown.size(), all.size()]]
	for it in shown:
		lines.append("  %s  %s" % [it, Gear.item_name(it)])
	return "\n".join(lines)


func run_create(caller: PlayerShape, words: Array[String], flags: Dictionary) -> String:
	if words.is_empty() or words.size() > 2 or (words.size() == 2 and not words[1].is_valid_int()):
		return "Usage: " + VERBS.create.usage
	var it := words[0].to_lower()
	if it != Gear.NOTE and not Gear.is_item(it):
		return "There's no item \"%s\". Try items list." % words[0]
	var count := words[1].to_int() if words.size() == 2 else 1
	if count < 1 or count > MAX_COUNT:
		return "Count must be 1 to %d." % MAX_COUNT
	var found := PlayerCommands.find(caller, str(flags.get("id", "")))
	if found.has("error"):
		return found.error
	var p: PlayerShape = found.player
	var made := 0
	if it == Gear.NOTE or Gear.note_count(it) > 0:
		var each := maxi(Gear.note_count(it), 1)
		made = p.inventory.add_notes(each * count)
		it = Gear.NOTE
		count *= each
	else:
		while made < count and p.inventory.add_to_bag(it):
			made += 1
	var what := "%d × %s" % [made, Gear.item_name(it if it != Gear.NOTE else Gear.notes(1))]
	if made == 0:
		return "%s's bag is full." % PlayerChat.name_of(p)
	if made < count:
		return "%s: made %s; the bag is full (%d didn't fit)." % [PlayerChat.name_of(p), what, count - made]
	return "%s: made %s." % [PlayerChat.name_of(p), what]


## Every kind of item, unupgraded: consumables, notes, then gear by tier.
static func catalog() -> Array[String]:
	var out: Array[String] = []
	out.append_array(Gear.CONSUMABLES)
	out.append(Gear.NOTE)
	for tier in range(1, Gear.TIERS.size()):
		for slot in Gear.SLOTS:
			var it := Gear.item(slot, tier)
			if Gear.is_item(it):
				out.append(it)
	return out


## `search` against an item's id or name, any case. With a *, a pattern
## (*steel*); without, anywhere in either. "" matches everything.
static func matches(it: String, search: String) -> bool:
	if search == "":
		return true
	var name := Gear.item_name(it if it != Gear.NOTE else Gear.notes(1))
	if search.contains("*") or search.contains("?"):
		return it.matchn(search) or name.matchn(search)
	var wanted := search.to_lower()
	return wanted in it or wanted in name.to_lower()

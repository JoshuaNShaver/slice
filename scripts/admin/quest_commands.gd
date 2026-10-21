class_name QuestCommands
extends RefCounted
## `quests ...` admin commands (design log 0196); see AdminConsole. The
## quests themselves (Quests), which are code, so only to read. A player's
## place in them is `players quests` (PlayerQuestCommands).
## `quests` alone lists them. Steps count from 1, as shown.

const HELP := "the quests themselves (a player's place in them: players quests)"
const VERBS := {
	"list": {"usage": "quests list", "flags": [],
			"help": "Every quest: id, name, steps, who can take part, and whether a birth starts it."},
	"get": {"usage": "quests get <quest>", "flags": [],
			"help": "One quest's steps and their goals."},
}


func words_for(verb: String) -> Array[String]:
	return ids() if verb == "get" else ([] as Array[String])


func run_list(_caller: PlayerShape, words: Array[String], _flags: Dictionary) -> String:
	if not words.is_empty():
		return "Usage: " + VERBS.list.usage
	var lines: Array[String] = ["%d quests:" % Quests.ALL.size()]
	for id: String in Quests.ALL:
		lines.append("  %-10s %s" % [id, _about(id)])
	return "\n".join(lines)


func run_get(_caller: PlayerShape, words: Array[String], _flags: Dictionary) -> String:
	if words.size() != 1:
		return "Usage: " + VERBS.get.usage
	var found := find(words[0])
	if found.has("error"):
		return found.error
	var id: String = found.id
	var lines: Array[String] = ["%s (%s): %s" % [Quests.quest_name(id), id, _about(id)]]
	var steps := Quests.steps(id)
	for i in steps.size():
		lines.append("  %d. %s" % [i + 1, steps[i].get("text", "")])
		for goal: Dictionary in steps[i].get("goals", []):
			lines.append("       - %s" % goal_text(goal))
	return "\n".join(lines)


## Every quest's id, for Tab.
static func ids() -> Array[String]:
	var out: Array[String] = []
	out.assign(Quests.ALL.keys())
	return out


## {"id": a quest id} or {"error": String}, from what was typed.
static func find(word: String) -> Dictionary:
	var id := word.to_lower()
	if Quests.ALL.has(id):
		return {"id": id}
	return {"error": "There's no quest \"%s\". Quests: %s" % [word, ", ".join(ids())]}


## "Talk to the Drill Sergeant (talk The Drill Sergeant)", or with a count.
static func goal_text(goal: Dictionary) -> String:
	var event := Quests.goal_event(goal)
	var need := Quests.need(goal)
	return "%s (%s %s%s)" % [goal.get("label", ""), event[0], event[1], " x%d" % need if need > 1 else ""]


## "Bootcamp, 7 steps, for regulars, starts at birth".
func _about(id: String) -> String:
	var quest: Script = Quests.ALL[id]
	var serves: Variant = quest.get("SERVES")
	return "%s, %d steps, for %s%s" % [Quests.quest_name(id), Quests.steps(id).size(),
			serves if serves != null else "anyone", ", starts at birth" if quest.get("AT_BIRTH") else ""]

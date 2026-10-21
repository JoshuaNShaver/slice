class_name PlayerQuestCommands
extends RefCounted
## `players quests ...` admin commands (design log 0196); see AdminConsole.
## A player's place in each quest (PlayerQuests): list, get, start, set,
## delete. `quests` (QuestCommands) shows the quests themselves.
## `players quests` alone lists them. `--id who` picks the player, as in
## PlayerCommands; left out, it's you. Steps count from 1, as shown.

const HELP := "a player's quests"
const VERBS := {
	"list": {"usage": "players quests list [--id who]", "flags": ["id"],
			"help": "Every quest and where the player is in it."},
	"get": {"usage": "players quests get <quest> [--id who]", "flags": ["id"],
			"help": "One quest: the step they're on, its goals so far, and every step."},
	"start": {"usage": "players quests start <quest> [--id who]", "flags": ["id"],
			"help": "Starts a quest at step 1, as play would: its first step's actions run."},
	"set": {"usage": "players quests set <quest> <step|done> [--id who]", "flags": ["id"],
			"help": "Puts a quest on a step, begun or not, its goals at 0. Only a bout the step needs comes back; its other actions don't run."},
	"delete": {"usage": "players quests delete <quest> [--id who]", "flags": ["id"],
			"help": "Forgets a quest, as if it never began, so it can start again."},
}


func words_for(verb: String) -> Array[String]:
	return QuestCommands.ids() if verb != "list" else ([] as Array[String])


func run_list(caller: PlayerShape, words: Array[String], flags: Dictionary) -> String:
	if not words.is_empty():
		return "Usage: " + VERBS.list.usage
	var found := PlayerCommands.find(caller, str(flags.get("id", "")))
	if found.has("error"):
		return found.error
	var p: PlayerShape = found.player
	var lines: Array[String] = ["%s's quests:" % PlayerChat.name_of(p)]
	for id: String in Quests.ALL:
		lines.append("  %-10s %s" % [id, status(p, id)])
	return "\n".join(lines)


func run_get(caller: PlayerShape, words: Array[String], flags: Dictionary) -> String:
	var target := _target(caller, words, 1, flags, VERBS.get.usage)
	if target.has("error"):
		return target.error
	var p: PlayerShape = target.player
	var id: String = target.id
	var state := p.quests.state_of(id)
	var at := int(state.get("step", -1))
	var steps := Quests.steps(id)
	var lines: Array[String] = ["%s, %s: %s" % [PlayerChat.name_of(p), Quests.quest_name(id), status(p, id)]]
	if at >= 0 and at < steps.size():
		var goals: Array = steps[at].get("goals", [])
		for i in goals.size():
			lines.append("  %d/%d  %s" % [state.counts[i], Quests.need(goals[i]), QuestCommands.goal_text(goals[i])])
	lines.append("Steps:")
	for i in steps.size():
		var mark := "+" if i < at else (">" if i == at else " ")
		lines.append("  %s %d. %s" % [mark, i + 1, steps[i].get("text", "")])
	return "\n".join(lines)


func run_start(caller: PlayerShape, words: Array[String], flags: Dictionary) -> String:
	var target := _target(caller, words, 1, flags, VERBS.start.usage)
	if target.has("error"):
		return target.error
	var p: PlayerShape = target.player
	var id: String = target.id
	if p.quests.has_started(id):
		return "%s has already started %s (%s). Use players quests set, or delete it first." % [
				PlayerChat.name_of(p), id, status(p, id)]
	p.quests.start(id)
	return "%s: started %s, %s." % [PlayerChat.name_of(p), id, status(p, id)]


func run_set(caller: PlayerShape, words: Array[String], flags: Dictionary) -> String:
	var target := _target(caller, words, 2, flags, VERBS.set.usage)
	if target.has("error"):
		return target.error
	var p: PlayerShape = target.player
	var id: String = target.id
	var total := Quests.steps(id).size()
	var step := words[1].to_lower()
	var at := total if step == "done" else step.to_int() - 1
	if step != "done" and (not step.is_valid_int() or at < 0 or at >= total):
		return "The step is 1 to %d, or done." % total
	p.quests.jump_to(id, at)
	return "%s: %s is now %s." % [PlayerChat.name_of(p), id, status(p, id)]


func run_delete(caller: PlayerShape, words: Array[String], flags: Dictionary) -> String:
	var target := _target(caller, words, 1, flags, VERBS.delete.usage)
	if target.has("error"):
		return target.error
	var p: PlayerShape = target.player
	var id: String = target.id
	if not p.quests.has_started(id):
		return "%s hasn't started %s." % [PlayerChat.name_of(p), id]
	p.quests.forget(id)
	return "%s: forgot %s; it can start again." % [PlayerChat.name_of(p), id]


## "not started", "done", or "step 2 of 7: <its text>", and whether it waits
## for a shape that can take part (Quests.serves).
static func status(p: PlayerShape, id: String) -> String:
	var state := p.quests.state_of(id)
	var steps := Quests.steps(id)
	var waits := "" if Quests.serves(id, p.sides, p.kind) else " (waiting: this shape can't take part)"
	if state.is_empty():
		return "not started" + waits
	var at := int(state.step)
	if at >= steps.size():
		return "done"
	return "step %d of %d: %s%s" % [at + 1, steps.size(), steps[at].get("text", ""), waits]


## {"player", "id"} for a verb taking `count` words, the first a quest, or
## {"error"}.
func _target(caller: PlayerShape, words: Array[String], count: int, flags: Dictionary,
		usage: String) -> Dictionary:
	if words.size() != count:
		return {"error": "Usage: " + usage}
	var quest := QuestCommands.find(words[0])
	if quest.has("error"):
		return quest
	var found := PlayerCommands.find(caller, str(flags.get("id", "")))
	if found.has("error"):
		return found
	return {"player": found.player, "id": quest.id}

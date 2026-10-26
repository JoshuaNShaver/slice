class_name Quests
## Every quest (design log 0179). A quest is an ordered list of steps,
## written as data in its own script (e.g. BootcampQuest), with its
## cutscenes beside it. PlayerQuests keeps each player's place in them.
##
## A quest script has:
## - ID, NAME, STEPS (below), SCENES (its cutscene ids) and
##   scene(id, you) -> a cutscene (CutscenePlayer's format). `you` is
##   {family, sides, kind, apex, equipped}: the player, to cast them.
## - SERVES (optional, as Npc "serves"): who can take part. For anyone else
##   it waits: nothing counts and the HUD doesn't show it.
## - AT_BIRTH: offered(newborn) -> bool, and INTRO_SPEAKER and INTRO: it
##   starts at a birth, and those lines are said once the birth's cutscene
##   ends (PlayerQuests.after_birth).
## - Otherwise offered(you) -> bool, with you {sides, kind, apex, level,
##   done: finished quest ids}: it starts once that's true (a level up, a
##   quest finished, a save loaded; PlayerQuests.check_offers). Ranger
##   school (log 0245).
##
## A step: {"text", "goals", "start", "then", "nag"}.
## - text: the objective, as the HUD shows it.
## - goals: all of them finish the step. Each is {event: what, "count"
##   (default 1), "label"} for one of EVENTS. A label may name a control
##   in braces, e.g. "{character_sheet}", shown as its key.
## - start: actions as the step begins (and again when a save is loaded
##   on it, for "spawn" only). then: actions once it's done.
## - nag: [speaker, [lines]]: what that NPC says if you talk to them before
##   the step is done.
## - back: [speaker, line, actions]: talking to that NPC while the step is
##   under way says the line and runs the actions: the way back to a step's
##   place if you left it (the home key out of ranger school's exam).
## Actions run in order; a cutscene waits until it has ended:
## {"cutscene": a SCENES id, "lead": [speaker, line]}, {"say": [speaker,
## line]}, {"give": item},
## {"spawn": enemy type, "at": floor point, "room": Rect2} (a bout, only you
## fight it; it ends the "spar" goal won or lost), {"heal": true},
## {"travel": "exam" | "camp" | "barracks"} (World.travel; like "spawn",
## it runs again when a save loads on its step).
## Any action with "if": "won" or "lost" runs only after that outcome.
## A cutscene's "lead" is said in the world first, and the cutscene starts
## once it's had time to be read: talking to someone shouldn't cut
## straight to a cutscene (log 0192).

## Events a goal can wait for:
## - talk: an NPC's name (you pressed interact by them).
## - kill: an Enemy type (you hit it, and it died).
## - equip: an item string (you put it on).
## - open: a HUD panel, "character" (your character sheet).
## - spar: a bout's enemy type; ends "won" or "lost".
## - reach: a place the server sees you get to ("exam_pass": through ranger
##   school's exam, RangerExam).
const EVENTS: Array[String] = ["talk", "kill", "equip", "open", "spar", "reach"]
## What a player's own machine may report (the rest the server sees itself).
const CLIENT_EVENTS := {"open": ["character"]}

const ALL := {
	"bootcamp": preload("res://scripts/quests/bootcamp_quest.gd"),
	"ranger_school": preload("res://scripts/quests/ranger_school_quest.gd"),
}


## Can a player of this shape take part in quest `id` (its SERVES)?
static func serves(id: String, sides: int, kind: String) -> bool:
	if not ALL.has(id):
		return false
	var who: Variant = (ALL[id] as Script).get("SERVES")
	return who == null or Regions.admits(str(who), sides, kind)


static func steps(id: String) -> Array:
	return (ALL[id] as Script).get("STEPS") if ALL.has(id) else []


static func quest_name(id: String) -> String:
	return (ALL[id] as Script).get("NAME") if ALL.has(id) else id


## How many `goal` needs.
static func need(goal: Dictionary) -> int:
	return maxi(int(goal.get("count", 1)), 1)


## The event and its object a goal waits for: ["kill", "dummy"].
static func goal_event(goal: Dictionary) -> Array:
	for event in EVENTS:
		if goal.has(event):
			return [event, str(goal[event])]
	return ["", ""]


## Server only. A save's quest state, kept to what play could produce:
## known quests, a step in range, counts within their goals.
static func sanitize(raw: Variant) -> Dictionary:
	var out := {}
	if not raw is Dictionary:
		return out
	for id: Variant in raw:
		if not id is String or not ALL.has(id) or not raw[id] is Dictionary:
			continue
		var quest_steps := steps(id)
		var entry: Dictionary = raw[id]
		var step := clampi(_as_int(entry.get("step"), 0), 0, quest_steps.size())
		var counts: Array = []
		if step < quest_steps.size():
			var goals: Array = quest_steps[step].get("goals", [])
			var raw_counts: Variant = entry.get("counts", [])
			for i in goals.size():
				var have: Variant = raw_counts[i] if raw_counts is Array and i < raw_counts.size() else 0
				counts.append(clampi(_as_int(have, 0), 0, need(goals[i])))
		out[id] = {"step": step, "counts": counts}
	return out


static func _as_int(value: Variant, fallback: int) -> int:
	return int(value) if value is int or value is float else fallback  # JSON numbers are floats

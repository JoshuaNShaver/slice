extends SceneTree
## Prints every cutscene's text (Cutscenes, and each quest's scenes), to
## read them.
## Godot --headless --path . -s tools/tests/dump_cutscenes.gd


func _initialize() -> void:
	await process_frame  # autoloads (quests reach the world's scripts)
	_print("Founding, isosceles", Cutscenes.founding({"family": "Smith", "sides": 3, "kind": "isosceles", "apex": 40}))
	_print("Founding, irregular", Cutscenes.founding({"family": "Smith", "sides": 3, "kind": "irregular", "apex": 40}))
	var cases := [
		["Isosceles 50 -> 55", {"sides": 3, "kind": "isosceles", "apex": 50}, {"sides": 3, "kind": "isosceles", "apex": 55}, "The Priest"],
		["Isosceles 55 -> equilateral, blessed", {"sides": 3, "kind": "isosceles", "apex": 55}, {"sides": 3, "kind": "equilateral", "apex": 0, "blessed": true}, "The Priest"],
		["Equilateral -> square", {"sides": 3, "kind": "equilateral", "apex": 0}, {"sides": 4, "kind": "regular", "apex": 0}, "The High Priest"],
		["Square -> pentagon", {"sides": 4, "kind": "regular", "apex": 0}, {"sides": 5, "kind": "regular", "apex": 0}, "The High Priest"],
		["Hexagon -> heptagon", {"sides": 6, "kind": "regular", "apex": 0}, {"sides": 7, "kind": "regular", "apex": 0}, "The High Priest"],
		["Nonagon -> decagon", {"sides": 9, "kind": "regular", "apex": 0}, {"sides": 10, "kind": "regular", "apex": 0}, "The High Priest"],
		["Square -> irregular pentagon", {"sides": 4, "kind": "regular", "apex": 0}, {"sides": 5, "kind": "irregular", "apex": 0}, "The Priest"],
		["Below: irregular -> irregular", {"sides": 3, "kind": "irregular", "apex": 50}, {"sides": 3, "kind": "irregular", "apex": 55}, "The Hedge Priest"],
		["Below: irregular -> regular", {"sides": 4, "kind": "irregular", "apex": 0}, {"sides": 5, "kind": "regular", "apex": 0}, "The Hedge Priest"],
	]
	for c: Array in cases:
		_print(c[0], Cutscenes.marriage("Smith", c[1], c[2], c[3]))
	var you := {"family": "Smith", "sides": 3, "kind": "isosceles", "apex": 40, "equipped": []}
	# Loaded now, not compiled with this script: quests reach the world's
	# scripts, which need the autoloads.
	var all: Dictionary = load("res://scripts/quests/quests.gd").get("ALL")
	for quest_id: String in all:
		var quest: Script = all[quest_id]
		for scene_id: String in quest.SCENES:
			_print("Quest %s: %s" % [quest_id, scene_id], quest.scene(scene_id, you))
	quit()


func _print(title: String, scene: Dictionary) -> void:
	print("\n=== %s ===" % title)
	for act: Dictionary in scene.acts:
		print("-- %s (%s, %s)" % [act.id, act.setting, act.place])
		var names := {}
		for a: Dictionary in act.cast:
			names[a.id] = a.get("name", a.id)
		for b: Dictionary in act.beats:
			var who: String = names.get(b.who, "")
			var cues := []
			for c: Dictionary in b.get("cues", []):
				cues.append("%s %s" % [c.do, c.get("who", "")])
			print("  %s%s%s" % [(who + ": ") if who != "" else "", b.text, "  [%s]" % ", ".join(cues) if not cues.is_empty() else ""])
	if scene.has("wake"):
		print("-- wake (%s)" % scene.wake_speaker)
		for line: String in scene.wake:
			print("  " + line)

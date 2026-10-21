extends SceneTree
## Prints every birth and wedding cutscene's text (Cutscenes), to read them.
## Godot --headless --path . -s tools/tests/dump_cutscenes.gd


func _init() -> void:
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
	quit()


func _print(title: String, scene: Dictionary) -> void:
	print("\n=== %s ===" % title)
	for act: Dictionary in scene.acts:
		print("-- %s (%s, %s)" % [act.id, act.setting, act.place])
		for beat: Dictionary in act.beats:
			var who: String = act.cast[beat.who].name if act.cast.has(beat.who) else ""
			print("  %s%s%s" % [(who + ": ") if who != "" else "", beat.text, "  [%s]" % beat.cue if beat.cue != "" else ""])
	if scene.has("wake"):
		print("-- wake (%s)" % scene.wake_speaker)
		for line: String in scene.wake:
			print("  " + line)

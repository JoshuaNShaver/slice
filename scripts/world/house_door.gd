class_name HouseDoor
extends Node2D
## The door of your house in the Noble Quarter (design logs 0041, 0064).
## Everyone uses the same door, but each player's chests are their own:
## interact here to open them (Hud storage panel). Squares and up only.

const REACH := 120.0
const RULE := "four_sides"

## Set by the world each frame, for the local player.
var prompt := ""


func _ready() -> void:
	add_to_group(Npc.GROUP)


func _process(_delta: float) -> void:
	queue_redraw()


## Server and owner: is this shape close enough to use its chests?
static func in_reach(p: PlayerShape) -> bool:
	for node in p.get_tree().get_nodes_in_group(Npc.GROUP):
		var door := node as HouseDoor
		if door != null and door.position.distance_to(p.position) <= REACH * 1.5:
			return true
	return false


func reach_distance(pos: Vector2) -> float:
	var d := position.distance_to(pos)
	return d if d <= REACH else INF


func prompt_for(p: PlayerShape) -> String:
	if not Regions.admits(RULE, p.sides, p.kind):
		return "Locked."
	return "%s: open your chests" % Controls.describe("interact")


## Server only.
func interact(p: PlayerShape) -> void:
	if Regions.admits(RULE, p.sides, p.kind):
		p.open_storage()


func _draw() -> void:
	if prompt != "":
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-200, -70), prompt, HORIZONTAL_ALIGNMENT_CENTER, 400, 16, Palette.INK)

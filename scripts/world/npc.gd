class_name Npc
extends Node2D
## Someone standing in the world. Walk up and press interact to talk.
##
## Every NPC serves some shapes and refuses others (Regions.admits): the
## overworld serves regulars, and most of the underworld refuses them
## (design log 0052). Refusal is fixed per NPC, never a dice roll.
##
## Roles:
## - "talk": says one of its lines.
## - "priest": marries you, using a marriage certificate (design log 0030).
## - "healer": heals you in full when you ask.
## - "general": gives missions (design log 0070), in a HUD panel.
## - "quartermaster": sells military gear and provisions for pay (design
##   logs 0071, 0080).
## Any NPC with a heal_area also heals everyone it serves inside that area,
## for free, as the Center's priest always has (design log 0033).
##
## Every peer builds the same NPCs from data (World); only the server acts
## on what they do. No body: shapes pass in front of them.

const GROUP := "interactables"
const HEALERS := "healers"
const REACH := 140.0

var display_name := ""
var sides := 4
var kind := "regular"
var radius := 30.0
var color := Color.WHITE
var role := "talk"
var serves := "anyone"
var lines: Array = []
var refusals: Array = []
## Healers: where they heal passively, and what they say when they do.
var heal_area := Rect2()
var heal_lines: Array = []
## Set by the world each frame, for the local player.
var prompt := ""

var _points: PackedVector2Array


## data: {"name", "at" (the floor point it stands on), "sides", "kind",
## "radius", "color", "role", "serves", "lines", "refusals", "heal_area",
## "heal_lines"}. Only "name" and "at" are required.
static func create(data: Dictionary) -> Npc:
	var n := Npc.new()
	n.display_name = data.name
	n.name = String(data.name).validate_node_name()
	n.sides = data.get("sides", 4)
	n.kind = data.get("kind", "regular")
	n.radius = data.get("radius", 30.0)
	# Plain above ground (design log 0069); colour creeps back below.
	var plain := Palette.chalk_for_sides(n.sides) if Regions.is_underworld(data.at) else Palette.PLAIN
	n.color = data.get("color", plain)
	n.role = data.get("role", "talk")
	n.serves = data.get("serves", "anyone")
	n.lines = data.get("lines", [])
	n.refusals = data.get("refusals", [])
	n.heal_area = data.get("heal_area", Rect2())
	n.heal_lines = data.get("heal_lines", n.lines)
	n._points = _outline(n.sides, n.kind, n.radius, n.display_name)
	var lowest := 0.0
	for p in n._points:
		lowest = maxf(lowest, p.y)
	n.position = (data.at as Vector2) - Vector2(0, lowest)
	return n


## Irregular NPCs each get their own lopsided outline, seeded by name.
static func _outline(n_sides: int, n_kind: String, r: float, seed_name: String) -> PackedVector2Array:
	if n_kind != "irregular":
		return ShapeGeometry.points(n_sides, n_kind, r)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_name)
	var pts := ShapeGeometry.points(n_sides, "regular", r)
	for i in pts.size():
		pts[i] *= rng.randf_range(0.6, 1.2)
	return _refit(pts, r)


static func _refit(pts: PackedVector2Array, r: float) -> PackedVector2Array:
	var far := 0.0
	for p in pts:
		far = maxf(far, p.length())
	var out := PackedVector2Array()
	for p in pts:
		out.append(p / far * r)
	return out


func _ready() -> void:
	add_to_group(GROUP)
	if heal_area.has_area():
		add_to_group(HEALERS)


func serves_player(p: PlayerShape) -> bool:
	return Regions.admits(serves, p.sides, p.kind)


## Is `p` within reach of an NPC with this role who serves them?
static func near_role(p: PlayerShape, wanted: String) -> bool:
	for node in p.get_tree().get_nodes_in_group(GROUP):
		var npc := node as Npc
		if npc != null and npc.role == wanted and npc.serves_player(p) \
				and npc.position.distance_to(p.position) <= REACH * 1.5:
			return true
	return false


# --- Interaction (World finds the nearest interactable) --------------------

func reach_distance(pos: Vector2) -> float:
	var d := position.distance_to(pos)
	return d if d <= REACH else INF


func prompt_for(p: PlayerShape) -> String:
	var key := Controls.describe("interact")
	if role == "priest" and serves_player(p):
		var certificate := p.actions.marriage_certificate()
		if certificate == "":
			return "Bring me a marriage certificate."
		if certificate == Gear.BLESSED_CERTIFICATE and p.sides == 3 and p.kind != "equilateral":
			return "%s: marry (uses your blessed certificate)" % key
		return "%s: marry (uses a certificate)" % key
	if role == "healer" and serves_player(p):
		return "%s: be healed" % key
	if role == "general" and serves_player(p):
		return "%s: take orders" % key
	if role == "quartermaster" and serves_player(p):
		return "%s: trade (%d pay)" % [key, p.stats.pay]
	return "%s: talk" % key


## Server only.
func interact(p: PlayerShape) -> void:
	if not serves_player(p):
		_say(p, refusals)
		return
	match role:
		"priest":
			if not p.actions.marry():
				p.screen.tell(display_name, "Bring me a marriage certificate, and I will marry you.")
		"general", "quartermaster":
			_say(p, lines)
			p.screen.open_panel("orders" if role == "general" else "shop")
		"healer":
			if p.stats.hp < p.stats.max_hp:
				p.combat.heal_full()
				_say(p, heal_lines)
			else:
				_say(p, lines)
		_:
			_say(p, lines)


func _say(p: PlayerShape, from: Array) -> void:
	if not from.is_empty():
		p.screen.tell(display_name, from.pick_random())


# --- Drawing ---------------------------------------------------------------

func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_colored_polygon(_points, color)
	var outline := _points.duplicate()
	outline.append(_points[0])
	draw_polyline(outline, Palette.INK, 2.5, true)
	if role == "priest" and kind != "irregular":
		draw_arc(Vector2.ZERO, radius + 8, 0, TAU, 48, Color(Palette.CHALK[5], 0.9), 3.0, true)
	var font := ThemeDB.fallback_font
	var ink := Palette.ink_at(global_position)
	draw_string(font, Vector2(-150, -radius - 18), display_name, HORIZONTAL_ALIGNMENT_CENTER, 300, 16, ink)
	if prompt != "":
		draw_string(font, Vector2(-220, -radius - 40), prompt, HORIZONTAL_ALIGNMENT_CENTER, 440, 16, ink)

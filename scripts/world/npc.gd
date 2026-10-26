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
## - "quartermaster": sells military gear and provisions for chits (design
##   logs 0071, 0080).
## - "dock": the Dock Tradesman, buys every log and ore in your bag for
##   chits (design logs 0204, 0211).
## - "vault": the Strongroom Keeper, your family's chests, bought for coins
##   (log 0212). Opens a HUD panel.
## - "smith": the Blacksmith, upgrades gear for coins and rare ore (log
##   0211); keeps the ore you hand him on account. Opens a HUD panel.
## - "boats": a boatwright, launches a boat for you at data "launch",
##   bow toward data "facing" (World.launch_boat, design log 0201).
## - "rowboats": the fortress raid's Boatman (log 0250), the same but a
##   rowboat, which rows between data "route" (its dock's x, its landing's);
##   only while no rowboat is waiting at the dock (get aboard that one).
## - "market": the Harbourmaster, the dock's log market for merchants;
##   "booth": the Market Clerk, your booth's orders on Merchants' Row
##   (Market, design log 0205). Both open a HUD panel.
## - "ranger_quartermaster": the rangers' stores on their island (log 0246):
##   ranger gear, drills and rations, in a HUD panel.
## - "travel": sends you to data "to" (World.travel): the rangers' island
##   ("camp") only for those it admits (RangerCamp.admits), else it just
##   talks; "barracks" for anyone (logs 0245, 0246).
## Any NPC with a heal_area also heals everyone it serves inside that area,
## for free, as the Center's priest always has (design log 0033).
##
## Every peer builds the same NPCs from data (World); only the server acts
## on what they do. Each has a solid, immovable body (design log 0223): you
## bump into it, and can stand on it.

const GROUP := "interactables"
const HEALERS := "healers"
const REACH := 140.0

var display_name := ""
var sides := 4
var kind := "regular"
var apex := 45.0  # an isosceles one's apex angle
var radius := 30.0
## Gear worn, indexed like Gear.SLOTS, drawn as a player's is (Gear.draw_shape).
var wear := PackedStringArray()
var color := Color.WHITE
var role := "talk"
var serves := "anyone"
var lines: Array = []
var refusals: Array = []
## Everything it was made from, for roles that need more (a boatwright's "launch").
var data := {}
## Healers: where they heal passively, and what they say when they do.
var heal_area := Rect2()
var heal_lines: Array = []
## Set by the world each frame, for the local player.
var prompt := ""
## Set by the world: a quest of the local player's sends them to talk to
## this NPC (PlayerQuests.tracker), so it shows a mark.
var quest_mark := false

var _points: PackedVector2Array


## data: {"name", "at" (the floor point it stands on), "sides", "kind",
## "apex", "radius", "color", "role", "serves", "lines", "refusals",
## "heal_area", "heal_lines", "wear"}. Only "name" and "at" are required.
static func create(data: Dictionary) -> Npc:
	var n := Npc.new()
	n.display_name = data.name
	n.name = String(data.name).validate_node_name()
	n.sides = data.get("sides", 4)
	n.kind = data.get("kind", "regular")
	n.apex = data.get("apex", 45.0)
	n.radius = data.get("radius", 30.0)
	n.wear = PackedStringArray(data.get("wear", []))
	# Plain above ground (design log 0069); colour creeps back below.
	var plain := Palette.chalk_for_sides(n.sides) if Regions.is_underworld(data.at) else Palette.PLAIN
	n.color = data.get("color", plain)
	n.role = data.get("role", "talk")
	n.serves = data.get("serves", "anyone")
	n.lines = data.get("lines", [])
	n.refusals = data.get("refusals", [])
	n.data = data
	n.heal_area = data.get("heal_area", Rect2())
	n.heal_lines = data.get("heal_lines", n.lines)
	n._points = _outline(n.sides, n.kind, n.radius, n.display_name, n.apex)
	var lowest := 0.0
	for p in n._points:
		lowest = maxf(lowest, p.y)
	n.position = (data.at as Vector2) - Vector2(0, lowest)
	n._add_body()
	return n


## The NPC's body: terrain to everyone, so shapes bump into it and can
## stand on it (design log 0223).
func _add_body() -> void:
	var body := StaticBody2D.new()
	body.name = "Body"
	body.collision_layer = PlayerShape.LAYER_TERRAIN
	body.collision_mask = 0
	body.physics_material_override = PhysicsMaterial.new()
	body.physics_material_override.friction = 1.0
	var shape := CollisionPolygon2D.new()
	shape.polygon = _points
	body.add_child(shape)
	add_child(body)


## Irregular NPCs each get their own lopsided outline, seeded by name.
static func _outline(n_sides: int, n_kind: String, r: float, seed_name: String,
		n_apex := 45.0) -> PackedVector2Array:
	if n_kind != "irregular":
		return ShapeGeometry.points(n_sides, n_kind, r, n_apex)
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
	return Regions.admits(serves, p.sides, p.kind, p.apex)


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
	if str(p.quests.tracker.get("talk_to", "")) == display_name and serves_player(p):
		return "%s: report" % key
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
	if role == "dock" and serves_player(p):
		var logs := p.inventory.count_of(Gear.LOG)
		var ore := p.inventory.count_of(Gear.ORE)
		if logs + ore == 0:
			return "%s: talk" % key
		var chits := logs * int(Gear.GOODS[Gear.LOG].chits) + ore * int(Gear.GOODS[Gear.ORE].chits)
		var what := "%d %s" % [logs, "log" if logs == 1 else "logs"] if ore == 0 else (
				"%d ore" % ore if logs == 0 else "%d logs and %d ore" % [logs, ore])
		return "%s: sell %s (%d chits)" % [key, what, chits]
	if role == "smith" and serves_player(p):
		return "%s: upgrade gear" % key
	if role == "vault" and serves_player(p):
		return "%s: your family's chests" % key
	if role == "market" and serves_player(p):
		return "%s: trade" % key
	if role == "booth" and serves_player(p):
		return "%s: your booth" % key
	if role == "boats" and serves_player(p):
		return "%s: take a boat" % key
	if role == "rowboats" and serves_player(p):
		return "%s: a rowboat of your own" % key
	if role == "quartermaster" and serves_player(p):
		return "%s: trade (%d chits)" % [key, p.stats.chits]
	return "%s: talk" % key


## Server only.
func interact(p: PlayerShape) -> void:
	if not serves_player(p):
		_say(p, refusals)
		return
	if p.quests.talk(display_name):
		return  # a quest had something to say (log 0179)
	match role:
		"priest":
			if not p.actions.marry(display_name):
				p.screen.tell(display_name, "Bring me a marriage certificate, and I will marry you.")
		"general", "quartermaster":
			_say(p, lines)
			p.screen.open_panel("orders" if role == "general" else "shop")
		"ranger_quartermaster":
			_say(p, lines)
			p.screen.open_panel("ranger_shop")
		"travel":
			var to := str(data.get("to", ""))
			if to == "camp" and not RangerCamp.admits(p):
				_say(p, lines)
				return
			p.screen.tell(display_name, str(data.get("send_line", (lines as Array).pick_random() if not lines.is_empty() else "")))
			p.get_tree().call_group(World.GROUP, "travel", p, to)
		"vault":
			_say(p, lines)
			p.screen.open_panel("vault")
		"smith":
			p.actions.hand_over_ore(display_name)
			_say(p, lines)
			p.screen.open_panel("smith")
		"dock":
			if p.inventory.count_of(Gear.LOG) + p.inventory.count_of(Gear.ORE) > 0:
				p.actions.sell_logs(display_name)
			else:
				_say(p, lines)
		"market", "booth":
			var market := p.get_tree().get_first_node_in_group(Market.GROUP) as Market
			if market != null:
				_say(p, lines)
				p.screen.show_market(role, market.snapshot(p))
		"boats":
			_say(p, lines)
			p.get_tree().call_group(World.GROUP, "launch_boat", p, data.launch, int(data.get("facing", -1)))
		"rowboats":
			for node in p.get_tree().get_nodes_in_group(Boat.GROUP):
				var boat := node as Boat
				if boat.rowed and boat.moored() and boat.position.distance_to(data.launch) < Boat.ROWED_RADIUS * 2.0:
					p.screen.tell(display_name, "She's waiting at the end of the dock. Get aboard and speak to her.")
					return
			_say(p, lines)
			p.get_tree().call_group(World.GROUP, "launch_boat", p, data.launch, int(data.get("facing", 1)),
					data.route)
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
	if not wear.is_empty():
		Gear.draw_shape(self, _points, sides, wear)  # armored, as on stage
	else:
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
	elif quest_mark:
		var bob := sin(Time.get_ticks_msec() / 250.0) * 3.0
		draw_string(font, Vector2(-20, -radius - 40 + bob), "!", HORIZONTAL_ALIGNMENT_CENTER, 40, 30, Palette.XP.darkened(0.3))

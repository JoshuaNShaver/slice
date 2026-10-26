class_name Gear
## Items and gear slots (design logs 0029, 0036).
##
## The book has no equipment (Flatlanders have no hands), so the five slots
## come from what it does have: sharp points, colour, the eye and the voice.
## Each gives one stat, so it never changes your outline (log 0006):
##
## | Slot    | What it is                          | Gives    |
## |---------|-------------------------------------|----------|
## | Points  | caps on your corners                | force    |
## | Plating | armor                               | rigidity |
## | Pigment | contraband colour (Colour Revolt)   | vigor    |
## | Eye     | a lens for sight recognition        | luck     |
## | Voice   | a pipe for your cry                 | mettle   |
##
## Items are strings, so they sync and save simply: "plating_2" is tier 2
## plating, "certificate" a marriage certificate, "blessed_certificate" the
## rare one that makes a triangle's heir equilateral (design log 0032), and
## "potion" a healing potion (design log 0037). Each cave room drops
## the next tier (rose 1, mint 2, lilac 3, the Pretender's gilded 4).
##
## Wearing all five slots in one tier completes its set, which adds that
## tier's own bonus (design log 0040). A military set is its four slots;
## pigment doesn't count (log 0085).
##
## Military gear (design logs 0071, 0072) is tiers 5-8: leather from the
## drill yard, then bronze, iron and steel, bought from the Quartermaster
## with chits (log 0206). It is plain, told apart by crosshatching (log 0069),
## and has no pigment: colour is contraband, and the army doesn't sell it.
##
## Provisions (design log 0084) are food the Quartermaster sells for chits.
## Unlike a potion, a meal heals over a few seconds (Stats.MEAL_TIME).
##
## Regimental (tier 9, log 0210) is the army's best, with a short red ribbon
## on each corner cap. The Blacksmith upgrades any piece of gear up to +5
## (log 0211): "points_9+3" is regimental caps at +3. Each level adds a
## share of the piece's own bonus (UPGRADE_SHARE); a full set grows with its
## lowest piece, and so does its halo, which turns into a circle at +5.
##
## Ranger gear (tiers 10-14, log 0241) is sold by the ranger quartermaster
## on the secret island (log 0246): the same stat curve as leather to
## regimental, with its own set bonuses. Its points are throwing tips: worn,
## they throw shots (`shots_of`, log 0242), a count and a spread per tier.

const CERTIFICATE := "certificate"
const BLESSED_CERTIFICATE := "blessed_certificate"
const POTION := "potion"
## Goods (design logs 0202, 0204): a log from the Logging Isle, one per bag
## slot, which the Dock Tradesman buys for chits.
const LOG := "log"
## Rare ore from the Quarry Isle (log 0211), for the Blacksmith's last two
## upgrades. One per bag slot, like a log, and dearer.
const ORE := "ore"
const GOODS := {
	"log": {"name": "Log", "chits": 200},
	"ore": {"name": "Rare ore", "chits": 600},
}
## Food, cheapest first. `heal`: share of max health, over Stats.MEAL_TIME.
## `price`: chits at the Quartermaster. *Proposed* numbers.
const PROVISIONS := {
	"hardtack": {"name": "Hardtack", "heal": 0.2, "price": 3},
	"cheese": {"name": "Cheese", "heal": 0.35, "price": 6},
	"salt_pork": {"name": "Salt pork", "heal": 0.5, "price": 10},
}
## Promissory notes (log 0212): the Harbourmaster's paper, each good for one
## log at a booth order on Merchants' Row. They stack: "note_12" is twelve
## in one bag slot, up to NOTE_STACK.
const NOTE := "note"
const NOTE_STACK := 50
## Rations (log 0246): the ranger quartermaster's food. They stack, "ration_7"
## is seven in one slot, up to RATION_STACK, and heal less than salt pork.
## *Proposed:* RATION_HEAL of max health over Stats.MEAL_TIME, RATION_COINS each.
const RATION := "ration"
const RATION_STACK := 30
const RATION_HEAL := 0.15
const RATION_COINS := 2
## Kept in the bag when an heir takes over (PlayerInventory.reset_for_heir).
const CONSUMABLES: Array[String] = [CERTIFICATE, BLESSED_CERTIFICATE, POTION,
		"hardtack", "cheese", "salt_pork", LOG, ORE]

## In order: the HUD lists them this way, and `equipped` is indexed by it.
const SLOTS: Array[String] = ["points", "plating", "pigment", "eye", "voice"]
## `bonus` is indexed by tier: the cave's chalk tiers 1-4, then military 5-8.
## *Proposed:* leather to steel give +2 / 4 / 7 / 10 (plating +3 / 6 / 10 / 15),
## so steel matches lilac: the army is not the best reward (design log 0073).
## Regimental gives 13 (plating 19), short of gilded (log 0210, *proposed*).
const SLOT_INFO := {
	"points": {"label": "Points", "noun": "caps", "stat": "force", "bonus": [0, 3, 6, 10, 15, 2, 4, 7, 10, 13, 2, 4, 7, 10, 13]},
	"plating": {"label": "Plating", "noun": "plating", "stat": "rigidity", "bonus": [0, 4, 9, 15, 22, 3, 6, 10, 15, 19, 3, 6, 10, 15, 19]},
	"pigment": {"label": "Pigment", "noun": "pigment", "stat": "vigor", "bonus": [0, 3, 6, 10, 15, 2, 4, 7, 10, 13, 2, 4, 7, 10, 13]},
	"eye": {"label": "Eye", "noun": "lens", "stat": "luck", "bonus": [0, 3, 6, 10, 15, 2, 4, 7, 10, 13, 2, 4, 7, 10, 13]},
	"voice": {"label": "Voice", "noun": "pipe", "stat": "mettle", "bonus": [0, 3, 6, 10, 15, 2, 4, 7, 10, 13, 2, 4, 7, 10, 13]},
}
## Slots military gear comes in: everything but pigment.
const MILITARY_SLOTS: Array[String] = ["points", "plating", "eye", "voice"]
const LEATHER := 5
const BRONZE := 6
const STEEL := 8
const REGIMENTAL := 9
## Ranger tiers (log 0241): Scout (the starting set, for chits) to Ranger.
const SCOUT := 10
const RANGER := 14
## A ranger's points are throwing tips (log 0242).
const TIPS_NOUN := "tips"
## A ranger's pigment is camouflage (log 0254).
const CAMO_NOUN := "camouflage"

## Upgrades (log 0211, *proposed* numbers). Index = the level reached.
const MAX_UPGRADE := 5
## How much a piece's bonus grows at each level: +80% at +5. The ore levels
## (+4, +5) jump the most.
const UPGRADE_SHARE: Array[float] = [0.0, 0.1, 0.2, 0.3, 0.5, 0.8]
## What the Blacksmith asks for each level: coins, and rare ore for the last two.
const UPGRADE_COST: Array[Dictionary] = [
	{},
	{"coins": 100, "ore": 0},
	{"coins": 200, "ore": 0},
	{"coins": 300, "ore": 0},
	{"coins": 500, "ore": 10},
	{"coins": 1000, "ore": 25},
]
## A full set's bonus grows by this share per level of its lowest piece.
const SET_UPGRADE_SHARE := 0.1
## The regimental ribbons' red: the regiment's colours, the one colour the
## law allows a soldier (log 0210).
const RIBBON := Color("b3262a")
## The ribbons' simulation (log 0220): length (px at world size) and links,
## gravity, a breeze's push and air drag (/s). *Proposed* feel.
const RIBBON_LENGTH := 20.0
const RIBBON_LINKS := 6
const RIBBON_GRAVITY := 420.0
const RIBBON_BREEZE := 70.0
const RIBBON_DRAG := 3.0
const RIBBON_STIFF := 0.35  # how much each link straightens toward the one before it
static var _ribbons := {}  # canvas instance id -> {"t", "chains"}
static var _ribbons_swept := 0.0
## Rare ore: dark rock with pale blue-white flecks (Timber's ore rocks too).
const ORE_ROCK := Color("8d877c")
const ORE_FLECK := Color("cfe3f0")

## Index = tier. Tier 0 is nothing. `set`: the full-set bonus (log 0040).
## Torque is speed, rigidity is defense, and vigor is health (10 each).
## Military tiers are muted, not coloured; `hatch` is their crosshatch:
## line angles (degrees) and spacing (px at world size). `price`: chits a
## piece at the Quartermaster (log 0206); 0 means it isn't sold.
const TIERS: Array[Dictionary] = [
	{"name": "", "color": Color.TRANSPARENT, "set": {}},
	{"name": "Rose", "color": Color("e38f8f"), "set": {"force": 15}},
	{"name": "Mint", "color": Color("8cc78a"), "set": {"torque": 15}},
	{"name": "Lilac", "color": Color("a58fd6"), "set": {"rigidity": 15}},
	{"name": "Gilded", "color": Color("d9b44a"), "set": {"vigor": 15, "luck": 15}},
	# Military sets are modest, +10 (log 0085, *proposed* past leather).
	{"name": "Leather", "color": Color("d8c7a4"), "set": {"force": 10}, "hatch": [[45.0], 9.0], "price": 0},
	{"name": "Bronze", "color": Color("cdb78e"), "set": {"vigor": 10}, "hatch": [[45.0, -45.0], 9.0], "price": 100},
	{"name": "Iron", "color": Color("b9b3a6"), "set": {"rigidity": 10}, "hatch": [[0.0, 90.0], 6.0], "price": 200},
	{"name": "Steel", "color": Color("a3a6a8"), "set": {"torque": 10}, "hatch": [[0.0, 60.0, -60.0], 6.0], "price": 500},
	# Regimental (log 0210): steel's hatch, finer, and a red ribbon on each corner.
	{"name": "Regimental", "color": Color("b4b8bb"), "set": {"vigor": 15, "force": 20}, "hatch": [[0.0, 60.0, -60.0], 4.0], "price": 2500},
	# Ranger gear (logs 0241, 0246), *proposed* names, sets and prices: the
	# ranger quartermaster's, not the Quartermaster's. Scout for chits
	# ("price"), the rest for coins only ("coins"). Diagonal hatches lean the
	# other way from the army's. `shots`: what its throwing tips throw (log
	# 0242): how many at once, fanned over `spread` degrees.
	{"name": "Scout", "color": Color("cfc6a2"), "set": {"luck": 10}, "hatch": [[-30.0], 9.0], "price": 100,
			"shop": "ranger", "shots": {"count": 1, "spread": 0.0},
			"camo": {"stealth": 0.10, "ground": Color("c9bd96"), "blotch": Color("a8996b"), "dapple": 5}},
	{"name": "Tracker", "color": Color("bfc0a0"), "set": {"mettle": 10}, "hatch": [[-30.0, 60.0], 9.0], "coins": 150,
			"shop": "ranger", "shots": {"count": 1, "spread": 0.0},
			"camo": {"stealth": 0.18, "ground": Color("a9b08a"), "blotch": Color("7d8a5e"), "dapple": 6}},
	{"name": "Outrider", "color": Color("b2b6a4"), "set": {"torque": 10}, "hatch": [[-30.0, 30.0], 6.0], "coins": 300,
			"shop": "ranger", "shots": {"count": 1, "spread": 0.0},
			"camo": {"stealth": 0.25, "ground": Color("a3a89f"), "blotch": Color("7f857a"), "dapple": 7}},
	{"name": "Pathfinder", "color": Color("a6aca6"), "set": {"luck": 15}, "hatch": [[-30.0, 30.0, 90.0], 6.0], "coins": 750,
			"shop": "ranger", "shots": {"count": 1, "spread": 0.0},
			"camo": {"stealth": 0.32, "ground": Color("a49ca8"), "blotch": Color("7a7184"), "dapple": 8}},
	{"name": "Ranger", "color": Color("9da5a3"), "set": {"luck": 15, "force": 20}, "hatch": [[-30.0, 30.0, 90.0], 4.0], "coins": 2000,
			"shop": "ranger", "shots": {"count": 1, "spread": 0.0},
			"camo": {"stealth": 0.40, "ground": Color("9fa59a"), "blotch": Color("6f7468"), "dapple": 10}},
]


## "points_9", or "points_9+3" upgraded to +3.
static func item(slot: String, tier: int, plus := 0) -> String:
	return "%s_%d" % [slot, tier] + ("+%d" % plus if plus > 0 else "")


## How many times the Blacksmith has upgraded it: 0 to MAX_UPGRADE.
static func plus_of(it: String) -> int:
	if slot_of(it) == "" or not it.contains("+"):
		return 0
	return clampi(it.get_slice("+", 1).to_int(), 0, MAX_UPGRADE)


## The same piece one level up ("" past MAX_UPGRADE).
static func upgraded(it: String) -> String:
	if not is_gear(it) or plus_of(it) >= MAX_UPGRADE:
		return ""
	return item(slot_of(it), tier_of(it), plus_of(it) + 1)


## The piece as the shop sells it: no upgrades. Any stack of notes is NOTE.
static func base_item(it: String) -> String:
	if note_count(it) > 0:
		return NOTE
	return item(slot_of(it), tier_of(it)) if is_gear(it) else it


static func random_item(tier: int, rng: RandomNumberGenerator) -> String:
	var slots := slots_for(tier)
	return item(slots[rng.randi_range(0, slots.size() - 1)], tier)


static func is_military_tier(tier: int) -> bool:
	return tier >= LEATHER


## Ranger gear (log 0241), worn only after ranger school.
static func is_ranger_tier(tier: int) -> bool:
	return tier >= SCOUT and tier <= RANGER


## The slots a tier comes in, and a full set of it needs: the army's have
## no pigment (colour is contraband, log 0085); the cave's and the rangers'
## have all five (rangers wear camouflage, log 0254).
static func slots_for(tier: int) -> Array[String]:
	return MILITARY_SLOTS if is_military_tier(tier) and not is_ranger_tier(tier) else SLOTS


## A ranger's camouflage (log 0254): {"stealth": the share it takes off how
## far enemies see you, "ground", "blotch": its two muted colours, "dapple":
## how many blotches}, or {} for anything else.
static func camo_of(it: String) -> Dictionary:
	if not is_gear(it) or slot_of(it) != "pigment":
		return {}
	return TIERS[tier_of(it)].get("camo", {})


## What a shop sells: every military slot in each tier it stocks. The
## Quartermaster's, or the ranger quartermaster's ("ranger", log 0246).
static func shop_stock(shop := "quartermaster") -> Array[String]:
	var out: Array[String] = []
	for tier in range(LEATHER, TIERS.size()):
		if TIERS[tier].get("shop", "quartermaster") != shop:
			continue
		if TIERS[tier].get("price", 0) > 0 or TIERS[tier].get("coins", 0) > 0:
			for slot in slots_for(tier):
				out.append(item(slot, tier))
	return out


## What throwing tips throw (log 0242): {"count", "spread"} (degrees), or {}
## for anything that isn't tips. Later gear may throw several in a fan.
static func shots_of(it: String) -> Dictionary:
	if not is_gear(it) or slot_of(it) != "points":
		return {}
	return TIERS[tier_of(it)].get("shots", {})


## "note_12": a stack of `count` promissory notes (clamped to 1..NOTE_STACK).
static func notes(count: int) -> String:
	return "%s_%d" % [NOTE, clampi(count, 1, NOTE_STACK)]


## How many notes a stack holds; 0 if it isn't one.
static func note_count(it: String) -> int:
	if not it.begins_with(NOTE + "_"):
		return 0
	var n := it.trim_prefix(NOTE + "_").to_int()
	return n if n >= 1 and n <= NOTE_STACK and it == notes(n) else 0


## "ration_7": a stack of `count` rations (clamped to 1..RATION_STACK).
static func rations(count: int) -> String:
	return "%s_%d" % [RATION, clampi(count, 1, RATION_STACK)]


## How many rations a stack holds; 0 if it isn't one.
static func ration_count(it: String) -> int:
	if not it.begins_with(RATION + "_"):
		return 0
	var n := it.trim_prefix(RATION + "_").to_int()
	return n if n >= 1 and n <= RATION_STACK and it == rations(n) else 0


## Kept by a new heir: certificates, potions, food, goods, notes.
static func is_consumable(it: String) -> bool:
	return it in CONSUMABLES or note_count(it) > 0 or ration_count(it) > 0


static func is_provision(it: String) -> bool:
	return PROVISIONS.has(it)


## What the ranger quartermaster asks for an item (log 0246): {"chits": n}
## for the starting gear, {"coins": n} for the rest and for a ration, or {}
## if he doesn't sell it.
static func ranger_price(it: String) -> Dictionary:
	if it == RATION:
		return {"coins": RATION_COINS}
	if not is_gear(it) or plus_of(it) > 0 or not is_ranger_tier(tier_of(it)):
		return {}
	var tier: Dictionary = TIERS[tier_of(it)]
	if tier.get("price", 0) > 0:
		return {"chits": tier.price}
	return {"coins": tier.get("coins", 0)} if tier.get("coins", 0) > 0 else {}


## Chits the Quartermaster asks for an item, or 0 if he doesn't sell it.
static func price(it: String) -> int:
	if is_provision(it):
		return PROVISIONS[it].price
	if not is_gear(it) or slot_of(it) not in MILITARY_SLOTS or plus_of(it) > 0:
		return 0
	if TIERS[tier_of(it)].get("shop", "quartermaster") != "quartermaster":
		return 0
	return TIERS[tier_of(it)].get("price", 0)


## The slot an item goes in, or "" if it isn't gear.
static func slot_of(it: String) -> String:
	var slot := it.get_slice("_", 0)
	return slot if slot in SLOTS and it.contains("_") else ""


static func tier_of(it: String) -> int:
	if slot_of(it) == "":
		return 0
	return clampi(it.get_slice("_", 1).get_slice("+", 0).to_int(), 0, TIERS.size() - 1)


static func is_gear(it: String) -> bool:
	return slot_of(it) != "" and tier_of(it) > 0


## Any real item: gear or a consumable. For checking saves.
static func is_item(it: String) -> bool:
	if it in CONSUMABLES or note_count(it) > 0 or ration_count(it) > 0:
		return true
	if not is_gear(it) or it != item(slot_of(it), tier_of(it), plus_of(it)):
		return false
	return slot_of(it) in slots_for(tier_of(it))


## {"force": 6} for "points_2"; {} for anything that isn't gear.
static func bonuses(it: String) -> Dictionary:
	if not is_gear(it):
		return {}
	var info: Dictionary = SLOT_INFO[slot_of(it)]
	return {info.stat: bonus_at(info.bonus[tier_of(it)], plus_of(it))}


## A piece's bonus `base` at upgrade level `plus` (log 0211).
static func bonus_at(base: int, plus: int) -> int:
	return roundi(base * (1.0 + UPGRADE_SHARE[clampi(plus, 0, MAX_UPGRADE)]))


## The lowest upgrade level among a full set's pieces (0 without a set).
## It decides how much the set bonus grows and how bright the halo is.
static func set_level(worn: PackedStringArray) -> int:
	var tier := set_tier(worn)
	if tier == 0:
		return 0
	var lowest := MAX_UPGRADE
	for i in SLOTS.size():
		if SLOTS[i] not in slots_for(tier):
			continue
		lowest = mini(lowest, plus_of(worn[i]))
	return lowest


## The tier whose full set is worn, or 0. `worn` is indexed like SLOTS.
## An army set needs only MILITARY_SLOTS; pigment is ignored (log 0085). A
## ranger set needs its camouflage too (log 0254).
static func set_tier(worn: PackedStringArray) -> int:
	if worn.size() != SLOTS.size():
		return 0
	var tier := tier_of(worn[0])
	for i in SLOTS.size():
		if SLOTS[i] not in slots_for(tier):
			continue
		if not is_gear(worn[i]) or tier_of(worn[i]) != tier:
			return 0
	return tier if not TIERS[tier].set.is_empty() else 0


## The full-set bonus for what's worn, e.g. {"force": 15}, or {}. It grows
## by SET_UPGRADE_SHARE for each level of the set's lowest piece.
static func set_bonus(worn: PackedStringArray) -> Dictionary:
	var base: Dictionary = TIERS[set_tier(worn)].set
	var grow := 1.0 + SET_UPGRADE_SHARE * set_level(worn)
	var out := {}
	for stat: String in base:
		out[stat] = roundi(base[stat] * grow)
	return out


## Everything worn adds, set bonus included: {"force": 21, "luck": 15}.
static func total_bonus(worn: PackedStringArray) -> Dictionary:
	var total := set_bonus(worn).duplicate()
	for it in worn:
		var gains := bonuses(it)
		for stat: String in gains:
			total[stat] = total.get(stat, 0) + gains[stat]
	return total


## "+15 force", "+15 vigor, +15 luck".
static func describe_bonus(gains: Dictionary) -> String:
	var parts: Array[String] = []
	for stat: String in gains:
		parts.append("+%d %s" % [gains[stat], stat])
	return ", ".join(parts)


static func color(it: String) -> Color:
	return TIERS[tier_of(it)].color


## "Mint lens", "a marriage certificate".
static func item_name(it: String) -> String:
	if it == CERTIFICATE:
		return "Marriage certificate"
	if it == BLESSED_CERTIFICATE:
		return "Blessed certificate"
	if it == POTION:
		return "Healing potion"
	if is_provision(it):
		return PROVISIONS[it].name
	if GOODS.has(it):
		return GOODS[it].name
	if it == RATION or ration_count(it) == 1:
		return "Ration"
	if ration_count(it) > 1:
		return "Rations ×%d" % ration_count(it)
	if note_count(it) == 1:
		return "Promissory note"
	if note_count(it) > 1:
		return "Promissory notes ×%d" % note_count(it)
	if not is_gear(it):
		return it
	var plus := plus_of(it)
	var noun: String = TIPS_NOUN if shots_of(it).size() > 0 else SLOT_INFO[slot_of(it)].noun
	if not camo_of(it).is_empty():
		noun = CAMO_NOUN
	return "%s %s" % [TIERS[tier_of(it)].name, noun] + (" +%d" % plus if plus > 0 else "")


## "Mint lens (eye, tier 2): +6 luck". For tooltips and messages.
static func describe(it: String) -> String:
	if it == CERTIFICATE:
		return "Marriage certificate: bring it to the priest in the Center."
	if it == BLESSED_CERTIFICATE:
		return "Blessed certificate: a triangle who marries with it has an equilateral heir."
	if it == POTION:
		return "Healing potion: restores %d%% of your health." % roundi(Stats.POTION_HEAL * 100)
	if is_provision(it):
		return "%s: restores %d%% of your health over %d s." % [
				item_name(it), roundi(PROVISIONS[it].heal * 100), roundi(Stats.MEAL_TIME)]
	if it == LOG:
		return "Log: the Dock Tradesman pays %d chits for it." % GOODS[LOG].chits
	if ration_count(it) > 0 or it == RATION:
		return "%s: restores %d%% of your health over %d s. Up to %d to a slot." % [
				item_name(it), roundi(RATION_HEAL * 100), roundi(Stats.MEAL_TIME), RATION_STACK]
	if note_count(it) > 0:
		return "%s: the Harbourmaster's paper, each good for one log at a booth order. Up to %d to a slot." % [
				item_name(it), NOTE_STACK]
	if it == ORE:
		return "Rare ore: the Blacksmith needs it for the finest work. The Dock Tradesman pays %d chits." % GOODS[ORE].chits
	if not is_gear(it):
		return it
	var slot := slot_of(it)
	var info: Dictionary = SLOT_INFO[slot]
	var tier := tier_of(it)
	var gain: int = bonuses(it)[info.stat]
	# Set bonuses stay secret until you wear the full set (design log 0045).
	if not shots_of(it).is_empty():
		var shots: Dictionary = shots_of(it)
		var thrown := "one shot" if int(shots.count) == 1 else "%d shots" % int(shots.count)
		return "%s (points, ranger): +%d %s. Throws %s at the nearest enemy (%s)." % [
				item_name(it), gain, info.stat, thrown, "left click"]
	if not camo_of(it).is_empty():
		return "%s (pigment, ranger): +%d %s. Enemies see you %d%% less far, until you strike or are struck." % [
				item_name(it), gain, info.stat, roundi(float(camo_of(it).stealth) * 100)]
	if is_ranger_tier(tier):
		return "%s (%s, ranger): +%d %s" % [item_name(it), info.label.to_lower(), gain, info.stat]
	if is_military_tier(tier):
		return "%s (%s, military): +%d %s" % [item_name(it), info.label.to_lower(), gain, info.stat]
	return "%s (%s, tier %d): +%d %s" % [item_name(it), info.label.to_lower(), tier, gain, info.stat]


## Draws a shape wearing its gear, centered on `at`. The fill is plain (log
## 0069); pigment tints it, plating is an inner band (crosshatched for
## military gear, chalk-coloured for the cave's), points are dots on the corners. The
## outline (and so the corner angles) never changes (design log 0006).
## Shared by the shape in the world and its icons (HUD, main menu), so gear
## looks the same everywhere. `equipped` is indexed like SLOTS.
static func draw_shape(canvas: CanvasItem, pts: PackedVector2Array, _sides: int,
		equipped: PackedStringArray, at := Vector2.ZERO) -> void:
	var worn := func(slot: String) -> String:
		var i := SLOTS.find(slot)
		return equipped[i] if i < equipped.size() else ""
	var radius := 0.0
	for p in pts:
		radius = maxf(radius, p.length())
	var scale := radius / 28.0  # the world shape's radius; icons scale the details
	var placed := PackedVector2Array()
	for p in pts:
		placed.append(p + at)

	var full_set := set_tier(equipped)
	if full_set > 0:
		_draw_halo(canvas, pts, at, scale, radius, TIERS[full_set].color, set_level(equipped))

	var fill := Palette.PLAIN  # shapes are plain (design log 0069)
	var pigment: String = worn.call("pigment")
	var camo := camo_of(pigment)
	if pigment != "" and camo.is_empty():
		fill = fill.lerp(color(pigment), 0.45)  # contraband colour
	if not camo.is_empty():
		_draw_camo(canvas, placed, camo, radius, at)
	else:
		canvas.draw_colored_polygon(placed, fill)

	var plating: String = worn.call("plating")
	if plating != "":
		var band := PackedVector2Array()
		for p in pts:
			band.append(p * 0.78 + at)
		if is_military_tier(tier_of(plating)):
			# Plain armor: the tier's crosshatch inside the band (design log 0069).
			canvas.draw_colored_polygon(band, color(plating))
			draw_hatch(canvas, band, TIERS[tier_of(plating)].hatch, scale, Color(Palette.INK, 0.45))
			band.append(band[0])
			canvas.draw_polyline(band, Color(Palette.INK, 0.6), 1.5 * scale, true)
		else:
			# Underworld gear keeps its contraband chalk colour.
			band.append(band[0])
			canvas.draw_polyline(band, color(plating), 3.0 * scale, true)
			var hatch := Color(Palette.INK, 0.35)
			for i in pts.size():
				var mid := (pts[i] + pts[(i + 1) % pts.size()]) * 0.5
				canvas.draw_line(mid * 0.72 + at, mid * 0.9 + at, hatch, 1.5 * scale)

	var outline := placed.duplicate()
	outline.append(placed[0])
	canvas.draw_polyline(outline, Palette.INK, 2.5, true)

	var caps: String = worn.call("points")
	if caps != "":
		if tier_of(caps) == REGIMENTAL:
			_draw_ribbons(canvas, pts, at, scale)
		if not shots_of(caps).is_empty():
			# Throwing tips: a small metal triangle sheathed on each corner.
			for p in pts:
				_draw_tip(canvas, p * 0.9 + at, p.normalized(), 4.0 * scale, color(caps))
			return
		for p in pts:
			canvas.draw_circle(p * 0.93 + at, 3.5 * scale, color(caps))
			canvas.draw_arc(p * 0.93 + at, 3.5 * scale, 0, TAU, 10, Palette.INK, 1.0, true)


## A ranger's camouflage (log 0254): the shape filled with its muted ground
## colour, dappled with blotches of the other, the same pattern every frame
## (seeded by the tier), clipped to the outline.
static func _draw_camo(canvas: CanvasItem, placed: PackedVector2Array, camo: Dictionary, radius: float,
		at: Vector2) -> void:
	canvas.draw_colored_polygon(placed, camo.ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(camo.dapple) * 7919
	for k in int(camo.dapple):
		var center := at + Vector2.from_angle(rng.randf() * TAU) * radius * rng.randf_range(0.0, 0.75)
		var r := radius * rng.randf_range(0.18, 0.32)
		var blob := PackedVector2Array()
		for i in 9:
			var a := TAU * i / 9.0
			blob.append(center + Vector2(cos(a), sin(a) * 0.7) * r * rng.randf_range(0.75, 1.15))
		for piece in Geometry2D.intersect_polygons(blob, placed):
			canvas.draw_colored_polygon(piece, camo.blotch)


## A throwing tip (log 0242): a small triangle at `at` pointing along `dir`.
## The thrown ones are drawn the same way (Projectiles).
static func _draw_tip(canvas: CanvasItem, at: Vector2, dir: Vector2, size: float, tint: Color) -> void:
	var side := dir.orthogonal()
	var tri := PackedVector2Array([at + dir * size * 1.3, at - dir * size * 0.6 + side * size * 0.8,
			at - dir * size * 0.6 - side * size * 0.8])
	canvas.draw_colored_polygon(tri, tint)
	tri.append(tri[0])
	canvas.draw_polyline(tri, Palette.INK, 1.0, true)


## A full set's halo (log 0040), lifted a little off the outline at an even
## distance, with rounded corners and a soft glow. Faint at +0, brighter with
## each upgrade of the set's lowest piece; at +5 it rounds into a circle, the
## Circle's own shape, breathing slowly, with motes drifting round it (log
## 0211, *proposed*).
static func _draw_halo(canvas: CanvasItem, pts: PackedVector2Array, at: Vector2, scale: float,
		radius: float, tint: Color, level: int) -> void:
	if level >= MAX_UPGRADE:
		var t := Time.get_ticks_msec() / 1000.0
		var breath := 0.5 + 0.5 * sin(t * 2.2)
		var ring := radius + 10.0 * scale
		tint = tint.lerp(TIERS[4].color, 0.5)  # gilded: the finest work, whatever the set
		canvas.draw_arc(at, ring, 0, TAU, 64, Color(tint, 0.2 + 0.15 * breath), (9.0 + 4.0 * breath) * scale, true)
		canvas.draw_arc(at, ring, 0, TAU, 64, Color(Palette.INK, 0.55), 4.2 * scale, true)
		canvas.draw_arc(at, ring, 0, TAU, 64, Color(tint, 1.0), 2.8 * scale, true)
		canvas.draw_arc(at, ring + 6.0 * scale, 0, TAU, 64, Color(tint, 0.3 + 0.4 * breath), 1.0 * scale, true)
		# Motes: they turn with the world, not with the rolling shape.
		var spin := canvas.get_global_transform().get_rotation()
		for k in 3:
			var a := t * 0.9 + TAU * k / 3.0 - spin
			var mote := at + Vector2.from_angle(a) * (ring + 6.0 * scale)
			canvas.draw_circle(mote, 2.6 * scale, Color(tint, 0.95))
			canvas.draw_circle(mote, 5.0 * scale, Color(tint, 0.2))
		return
	var k := float(level) / (MAX_UPGRADE - 1)  # 0 at +0, 1 at +4
	var halo := _rounded_outline(pts, lerpf(6.0, 8.0, k) * scale)
	for i in halo.size():
		halo[i] += at
	canvas.draw_polyline(halo, Color(tint, lerpf(0.10, 0.45, k)), lerpf(5.0, 11.0, k) * scale, true)
	canvas.draw_polyline(halo, Color(tint, lerpf(0.45, 1.0, k)), lerpf(1.5, 3.5, k) * scale, true)


## Regimental caps (log 0220): a short red ribbon tied to each corner. Each
## is its own little chain of points, pinned at its corner and simulated in
## world space: gravity hangs it straight down, a gentle breeze of its own
## sways it, and air drag makes it trail behind wherever its corner moves.
## So at rest they hang and stir, each in its own time; rolling, each one
## streams back behind its own corner and catches up a moment late.
## State lives per canvas (a shape, an NPC, an icon), keyed by its id.
static func _draw_ribbons(canvas: CanvasItem, pts: PackedVector2Array, at: Vector2, scale: float) -> void:
	var to_world := canvas.get_global_transform()
	var to_local := to_world.affine_inverse()
	var now := Time.get_ticks_msec() / 1000.0
	var id := canvas.get_instance_id()
	var state: Dictionary = _ribbons.get(id, {})
	var dt := clampf(now - float(state.get("t", now)), 0.0, 1.0 / 30.0)
	var chains: Array = state.get("chains", [])
	var seg := RIBBON_LENGTH * scale / RIBBON_LINKS
	if chains.size() != pts.size():
		chains = []
		for i in pts.size():
			chains.append(_hanging_chain(to_world * (pts[i] * 0.97 + at), seg))
	for i in pts.size():
		var root := to_world * (pts[i] * 0.97 + at)
		var chain: Array = chains[i]
		if (chain[0][0] as Vector2).distance_to(root) > RIBBON_LENGTH * scale * 4.0:
			chain = _hanging_chain(root, seg)  # a teleport, not movement
			chains[i] = chain
		_step_chain(chain, root, seg, dt, now, i)
		var mid := PackedVector2Array()
		for node: Array in chain:
			mid.append(to_local * (node[0] as Vector2))
		_draw_ribbon_band(canvas, mid, scale)
	_ribbons[id] = {"t": now, "chains": chains}
	# Forget canvases that stopped drawing (freed shapes, closed icons).
	if now - _ribbons_swept > 5.0:
		_ribbons_swept = now
		for key: int in _ribbons.keys():
			if now - float(_ribbons[key].t) > 5.0:
				_ribbons.erase(key)


## A ribbon hanging straight down from `root`: [[position, previous position], ...].
static func _hanging_chain(root: Vector2, seg: float) -> Array:
	var chain := []
	for j in RIBBON_LINKS + 1:
		var p := root + Vector2.DOWN * seg * j
		chain.append([p, p])
	return chain


## One step of a ribbon (Verlet): pin the root, let the rest fall and blow,
## damped by the air, then keep each link its length.
static func _step_chain(chain: Array, root: Vector2, seg: float, dt: float, now: float, i: int) -> void:
	chain[0][0] = root
	chain[0][1] = root
	if dt <= 0.0:
		return
	# This ribbon's own breeze: two slow, unrelated sways, phased by corner.
	var phase := i * 2.39
	var breeze := Vector2(sin(now * 1.1 + phase) * 0.7 + sin(now * 2.7 + phase * 1.9) * 0.3, 0.0) * RIBBON_BREEZE
	var keep := exp(-RIBBON_DRAG * dt)  # what's left of each point's speed after air drag
	for j in range(1, chain.size()):
		var p: Vector2 = chain[j][0]
		var was: Vector2 = chain[j][1]
		var flutter := breeze.orthogonal() * 0.12 * sin(now * 5.0 + phase + j * 0.9)
		var next := p + (p - was) * keep + (Vector2.DOWN * RIBBON_GRAVITY + breeze + flutter) * dt * dt
		chain[j][1] = p
		chain[j][0] = next
	for _pass in 3:
		for j in range(1, chain.size()):
			var a: Vector2 = chain[j - 1][0]
			var b: Vector2 = chain[j][0]
			if j >= 2:
				# Cloth resists folding: lean toward carrying on from the last link.
				var before: Vector2 = chain[j - 2][0]
				b = b.lerp(a + (a - before).normalized() * seg, RIBBON_STIFF)
			var gap := b - a
			var length := gap.length()
			chain[j][0] = a + gap / length * seg if length > 0.0001 else a + Vector2.DOWN * seg


## The ribbon's cloth along its middle line `mid`: widening a little toward
## a forked tail, like a regimental streamer.
static func _draw_ribbon_band(canvas: CanvasItem, mid: PackedVector2Array, scale: float) -> void:
	var last := mid.size() - 1
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for j in mid.size():
		var along := (mid[mini(j + 1, last)] - mid[maxi(j - 1, 0)]).normalized()
		var half := lerpf(2.0, 3.2, float(j) / last) * scale
		left.append(mid[j] + along.orthogonal() * half)
		right.append(mid[j] - along.orthogonal() * half)
	var back := (mid[last] - mid[last - 1]).normalized()
	var band := left.duplicate()
	band.append(mid[last] - back * 3.0 * scale)
	for j in range(last, -1, -1):
		band.append(right[j])
	canvas.draw_colored_polygon(band, RIBBON)
	band.append(band[0])
	canvas.draw_polyline(band, RIBBON.darkened(0.45), maxf(0.8 * scale, 0.75), true)


## Fills `poly` with parallel ink lines, one set per angle in `hatch[0]`,
## `hatch[1]` px apart (times `scale`). Works for any simple polygon.
static func draw_hatch(canvas: CanvasItem, poly: PackedVector2Array, hatch: Array, scale: float,
		ink: Color) -> void:
	var box := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	var center := box.get_center()
	var reach := box.size.length() / 2.0 + 1.0
	var gap: float = maxf(hatch[1] * scale, 2.0)
	for angle: float in hatch[0]:
		var along := Vector2.from_angle(deg_to_rad(angle))
		var across := along.orthogonal()
		var offset := -reach
		while offset <= reach:
			var a := center + across * offset - along * reach
			var b := center + across * offset + along * reach
			for piece: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), poly):
				canvas.draw_polyline(piece, ink, maxf(1.0 * scale, 0.75), true)
			offset += gap


## The outline pushed out by `gap` on every side, with each corner rounded
## into an arc around it. A closed polyline (first point repeated at the end).
static func _rounded_outline(pts: PackedVector2Array, gap: float) -> PackedVector2Array:
	var n := pts.size()
	var center := Vector2.ZERO
	for p in pts:
		center += p
	center /= n
	# Which perpendicular points outward depends on the winding.
	var e0 := (pts[1] - pts[0]).normalized()
	var flip := 1.0 if Vector2(e0.y, -e0.x).dot((pts[0] + pts[1]) / 2.0 - center) > 0.0 else -1.0
	var normals := PackedVector2Array()  # outward normal of the edge from corner i to i+1
	for i in n:
		var e := (pts[(i + 1) % n] - pts[i]).normalized()
		normals.append(Vector2(e.y, -e.x) * flip)
	var turns := PackedFloat32Array()
	var total := 0.0
	for i in n:
		var turn := wrapf(normals[i].angle() - normals[i - 1].angle(), -PI, PI)
		turns.append(turn)
		total += turn
	var out := PackedVector2Array()
	for i in n:
		var from := normals[i - 1].angle()
		if signf(turns[i]) == signf(total):  # outer corner: sweep an arc
			var steps := maxi(1, ceili(absf(turns[i]) / (PI / 18.0)))
			for k in steps + 1:
				out.append(pts[i] + Vector2.from_angle(from + turns[i] * k / steps) * gap)
		else:  # a dent: the two offset edges just meet
			out.append(pts[i] + normals[i - 1] * gap)
			out.append(pts[i] + normals[i] * gap)
	out.append(out[0])
	return out


## Draws an item's icon centered on `at`, about 28 px across. Shared by the
## ground pickup and the HUD slots.
static func draw_icon(canvas: CanvasItem, it: String, at: Vector2, alpha := 1.0) -> void:
	var ink := Color(Palette.INK, alpha)
	if it == CERTIFICATE or it == BLESSED_CERTIFICATE:
		# A scroll with a seal: red, or gold with a halo when blessed.
		var blessed := it == BLESSED_CERTIFICATE
		if blessed:
			canvas.draw_arc(at, 17.0, 0, TAU, 24, Color(TIERS[4].color, alpha), 2.0, true)
		var rect := Rect2(at + Vector2(-14, -10), Vector2(28, 20))
		canvas.draw_rect(rect, Color(Palette.PARCHMENT_LIGHT, alpha))
		canvas.draw_rect(rect, ink, false, 2.0)
		canvas.draw_line(at + Vector2(-8, -3), at + Vector2(8, -3), ink, 1.5)
		canvas.draw_line(at + Vector2(-8, 2), at + Vector2(4, 2), ink, 1.5)
		var seal := TIERS[4].color if blessed else Palette.HEALTH
		canvas.draw_circle(at + Vector2(9, 7), 5.0, Color(seal, alpha))
		return
	if it == POTION:
		# A round flask of red draught.
		var flask := Color(Palette.HEALTH, alpha)
		canvas.draw_circle(at + Vector2(0, 4), 10.0, flask)
		canvas.draw_arc(at + Vector2(0, 4), 10.0, 0, TAU, 20, ink, 2.0, true)
		var neck := Rect2(at + Vector2(-4, -12), Vector2(8, 8))
		canvas.draw_rect(neck, Color(Palette.PARCHMENT_LIGHT, alpha))
		canvas.draw_rect(neck, ink, false, 2.0)
		return
	if is_provision(it):
		_draw_provision(canvas, it, at, alpha)
		return
	if ration_count(it) > 0 or it == RATION:
		# A cloth-wrapped bundle tied with twine, and how many in the stack.
		var bundle := Rect2(at + Vector2(-13, -9), Vector2(26, 18))
		canvas.draw_rect(bundle, Color("cdbb8f", alpha))
		canvas.draw_rect(bundle, ink, false, 2.0)
		canvas.draw_line(at + Vector2(-2, -9), at + Vector2(-2, 9), ink, 1.5)
		canvas.draw_line(at + Vector2(-13, 0), at + Vector2(13, 0), Color(Palette.INK, 0.5 * alpha), 1.2)
		var font := ThemeDB.fallback_font
		var count := str(ration_count(it)) if ration_count(it) > 0 else ""
		canvas.draw_string_outline(font, at + Vector2(-15, 19), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3,
				Color(Palette.PARCHMENT_LIGHT, alpha))
		canvas.draw_string(font, at + Vector2(-15, 19), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
		return
	if note_count(it) > 0:
		# A folded note with a wax seal, and how many in the stack.
		if note_count(it) > 1:
			canvas.draw_rect(Rect2(at + Vector2(-11, -12), Vector2(26, 18)), Color(Palette.PARCHMENT_DARK, alpha))
			canvas.draw_rect(Rect2(at + Vector2(-11, -12), Vector2(26, 18)), ink, false, 1.5)
		var paper := Rect2(at + Vector2(-14, -8), Vector2(26, 18))
		canvas.draw_rect(paper, Color(Palette.PARCHMENT_LIGHT, alpha))
		canvas.draw_rect(paper, ink, false, 2.0)
		canvas.draw_line(at + Vector2(-10, -2), at + Vector2(6, -2), Color(Palette.INK, 0.6 * alpha), 1.2)
		canvas.draw_line(at + Vector2(-10, 3), at + Vector2(2, 3), Color(Palette.INK, 0.6 * alpha), 1.2)
		canvas.draw_circle(at + Vector2(8, 6), 4.0, Color(Palette.HEALTH, alpha))
		var font := ThemeDB.fallback_font
		var count := str(note_count(it))
		canvas.draw_string_outline(font, at + Vector2(-15, 19), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3,
				Color(Palette.PARCHMENT_LIGHT, alpha))
		canvas.draw_string(font, at + Vector2(-15, 19), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
		return
	if it == ORE:
		# A jagged lump of rock with bright flecks of ore in it.
		var lump := PackedVector2Array([Vector2(-13, 6), Vector2(-9, -7), Vector2(-1, -12), Vector2(9, -8),
				Vector2(14, 2), Vector2(8, 11), Vector2(-6, 11)])
		for i in lump.size():
			lump[i] += at
		canvas.draw_colored_polygon(lump, Color(ORE_ROCK, alpha))
		for fleck: Vector2 in [Vector2(-4, -3), Vector2(4, 2), Vector2(-1, 6), Vector2(7, -4)]:
			canvas.draw_circle(at + fleck, 2.2, Color(ORE_FLECK, alpha))
		lump.append(lump[0])
		canvas.draw_polyline(lump, ink, 2.0, true)
		return
	if it == LOG:
		# A short log on its side: bark lines, and a cut end with rings.
		var body := Rect2(at + Vector2(-14, -8), Vector2(24, 16))
		canvas.draw_rect(body, Color(Palette.PARCHMENT_DARK, alpha))
		canvas.draw_line(body.position, Vector2(body.end.x, body.position.y), ink, 2.0)
		canvas.draw_line(Vector2(body.position.x, body.end.y), body.end, ink, 2.0)
		canvas.draw_line(at + Vector2(-10, -2), at + Vector2(2, -2), Color(Palette.INK, 0.4 * alpha), 1.2)
		canvas.draw_line(at + Vector2(-6, 3), at + Vector2(6, 3), Color(Palette.INK, 0.4 * alpha), 1.2)
		var end := at + Vector2(10, 0)
		canvas.draw_circle(end, 8.0, Color(Palette.PARCHMENT_LIGHT, alpha))
		canvas.draw_arc(end, 8.0, 0, TAU, 16, ink, 2.0, true)
		canvas.draw_arc(end, 4.0, 0, TAU, 12, Color(Palette.INK, 0.5 * alpha), 1.2, true)
		canvas.draw_arc(body.position + Vector2(0, 8), 8.0, PI / 2.0, PI * 1.5, 8, ink, 2.0, true)
		return
	var fill := Color(color(it), alpha)
	if not shots_of(it).is_empty():
		# Throwing tips (log 0242): three small spinning triangles, fanned.
		for k in 3:
			var c := at + Vector2((k - 1) * 9.0, 6.0 if k != 1 else -2.0)
			var dir := Vector2.from_angle(-PI / 2.0 + (k - 1) * 0.5)
			_draw_tip(canvas, c, dir, 6.0, fill)
		_draw_plus(canvas, it, at, alpha)
		return
	var pts: PackedVector2Array
	match slot_of(it):
		"points":  # a sharp cap
			pts = PackedVector2Array([Vector2(0, -14), Vector2(10, 10), Vector2(-10, 10)])
		"plating":  # a shield
			pts = PackedVector2Array([Vector2(-12, -12), Vector2(12, -12), Vector2(12, 2), Vector2(0, 14), Vector2(-12, 2)])
		"pigment":  # a drop of paint
			pts = PackedVector2Array()
			for i in 12:
				var a := TAU * i / 12.0
				var r := 10.0 if i != 9 else 16.0  # the tip points up
				pts.append(Vector2(cos(a), sin(a)) * r + Vector2(0, 3))
		"eye":  # a lens
			pts = PackedVector2Array()
			for i in 16:
				var a := TAU * i / 16.0
				pts.append(Vector2(cos(a) * 14, sin(a) * 8))
		_:  # voice: a pipe flaring out
			pts = PackedVector2Array([Vector2(-14, -3), Vector2(4, -3), Vector2(13, -11),
					Vector2(13, 11), Vector2(4, 3), Vector2(-14, 3)])
	for i in pts.size():
		pts[i] += at
	var camo := camo_of(it)
	if not camo.is_empty():  # camouflage (log 0254): dappled, no hatching
		_draw_camo(canvas, pts, camo, 13.0, at + Vector2(0, 3))
	else:
		canvas.draw_colored_polygon(pts, fill)
	if is_military_tier(tier_of(it)) and camo.is_empty():
		draw_hatch(canvas, pts, TIERS[tier_of(it)].hatch, 0.6, Color(Palette.INK, 0.45 * alpha))
	var outline := pts.duplicate()
	outline.append(pts[0])
	canvas.draw_polyline(outline, ink, 2.0, true)
	if slot_of(it) == "eye":
		canvas.draw_circle(at, 3.5, ink)
	if tier_of(it) == REGIMENTAL:
		# A short red ribbon tied at the top left (log 0210).
		var knot := pts[0]
		canvas.draw_line(knot, knot + Vector2(-7, -3), Color(RIBBON, alpha), 3.0, true)
		canvas.draw_line(knot + Vector2(-7, -3), knot + Vector2(-12, 1), Color(RIBBON, alpha), 2.0, true)
	_draw_plus(canvas, it, at, alpha)


## "+3" in an icon's corner for an upgraded piece; gold ink at +5.
static func _draw_plus(canvas: CanvasItem, it: String, at: Vector2, alpha: float) -> void:
	var plus := plus_of(it)
	if plus > 0:
		var font := ThemeDB.fallback_font
		var mark := Color(TIERS[4].color.darkened(0.25), alpha) if plus >= MAX_UPGRADE else Color(Palette.INK, alpha)
		canvas.draw_string_outline(font, at + Vector2(1, 17), "+%d" % plus, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3,
				Color(Palette.PARCHMENT_LIGHT, alpha))
		canvas.draw_string(font, at + Vector2(1, 17), "+%d" % plus, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, mark)


## Food icons: a docked biscuit, a wedge of cheese, a slab of pork.
static func _draw_provision(canvas: CanvasItem, it: String, at: Vector2, alpha: float) -> void:
	var ink := Color(Palette.INK, alpha)
	match it:
		"hardtack":
			var rect := Rect2(at + Vector2(-12, -12), Vector2(24, 24))
			canvas.draw_rect(rect, Color("dcc08a", alpha))
			canvas.draw_rect(rect, ink, false, 2.0)
			for x in [-6, 0, 6]:
				for y in [-6, 0, 6]:
					canvas.draw_circle(at + Vector2(x, y), 1.4, ink)
		"cheese":
			var pts := PackedVector2Array([Vector2(-14, 9), Vector2(14, 9), Vector2(14, -2), Vector2(-14, -10)])
			for i in pts.size():
				pts[i] += at
			canvas.draw_colored_polygon(pts, Color("ead27a", alpha))
			canvas.draw_circle(at + Vector2(4, 3), 2.5, Color("c9ad55", alpha))
			canvas.draw_circle(at + Vector2(-5, 4), 1.8, Color("c9ad55", alpha))
			pts.append(pts[0])
			canvas.draw_polyline(pts, ink, 2.0, true)
		_:  # salt pork: lean with a band of fat along the top
			var rect := Rect2(at + Vector2(-14, -8), Vector2(28, 17))
			canvas.draw_rect(rect, Color("d99a8f", alpha))
			canvas.draw_rect(Rect2(rect.position, Vector2(28, 5)), Color(Palette.PARCHMENT_LIGHT, alpha))
			canvas.draw_rect(rect, ink, false, 2.0)
			canvas.draw_line(at + Vector2(-14, -3), at + Vector2(14, -3), ink, 1.0)

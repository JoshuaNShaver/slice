extends Node
## The west coast's checks, run by test_coast.gd. Builds a bare world (the
## coast, its sea, and this node standing in for World: it finds players
## and takes dropped items) instead of World, so nothing is saved.

var tree: SceneTree
var _fails := 0
var _root: Node2D
var _players := {}  # peer id -> PlayerShape
var dropped: Array = []  # [item, owner, pos]


func run() -> int:
	seed(4242)
	_root = Node2D.new()
	_root.name = "TestWorld"
	tree.root.add_child(_root)
	name = "WorldStandIn"
	add_to_group(World.GROUP)
	_root.add_child(self)
	_root.add_child(Coast.new())

	await _gate()
	await _sailing()
	await _drowning()
	_weather()
	await _trees()
	_selling()
	_market()
	await _ore()
	_upgrades()
	await _smith()
	_notes()
	await _vault()

	print("DONE fails=%d" % _fails)
	return _fails


## Stand-in for World.player.
func player(id: int) -> PlayerShape:
	return _players.get(id)


## Stand-in for World.drop_item.
func drop_item(item: String, owner_id: int, pos: Vector2) -> void:
	dropped.append([item, owner_id, pos])


func _gate() -> void:
	var sharp := _spawn(1, 40, Vector2(Coast.GATE_X + 60, Coast.FLOOR_Y - 40))
	var wide := _spawn(2, 50, Vector2(Coast.GATE_X + 60, Coast.FLOOR_Y - 40))
	await _steps(60)
	sharp.motion._submit_move(-1.0)
	wide.motion._submit_move(-1.0)
	await _steps(360)
	_check(sharp.position.x >= Coast.GATE_X - 40, "a 40° triangle is turned back (x=%d)" % sharp.position.x)
	_check(wide.position.x < Coast.GATE_X - 60, "a 50° triangle goes on (x=%d)" % wide.position.x)
	_check(Regions.admits("workmen", 4, "regular"), "squares are workmen")
	_check(not Regions.admits("workmen", 3, "isosceles", 44), "44° isn't")
	_check(Regions.admits("merchants", 3, "isosceles", 55) and not Regions.admits("merchants", 3, "isosceles", 50),
			"merchants from 55°")
	_free(sharp)
	_free(wide)


func _sailing() -> void:
	var launch: Vector2 = Coast.NPCS[2].launch
	var boat := Boat.create({"name": "B1", "pos": launch, "facing": -1, "owner": 3})
	_root.add_child(boat)
	var p := _spawn(3, 50, launch + Vector2(Boat.RADIUS * 0.5, -PlayerShape.RADIUS - 12.0))
	await _steps(360)
	_check(absf(boat.position.y - Ocean.LEVEL) < 40.0, "the boat floats (y=%d)" % boat.position.y)
	_check(absf(boat.rotation) < 0.35, "and sits upright (%.0f°)" % rad_to_deg(boat.rotation))
	_check(p in boat.riders(), "the player stands on the deck")
	_check(not p.actions.drowning, "and is dry")

	# Lean in bursts, as a sailor would: 1.5 s on, 0.7 s off.
	var start_x := boat.position.x
	for burst in 8:
		p.motion._submit_move(-1.0)
		await _report(boat, p, 180, "lean %d" % burst)
		p.motion._submit_move(0.0)
		await _report(boat, p, 84, "rest %d" % burst)
	var sailed := start_x - boat.position.x
	_check(sailed > 1500.0, "sailing west in bursts goes far (%d px)" % sailed)
	_check(not boat.sinking, "without capsizing")

	# Let go: it slows and rights itself.
	p.motion._submit_move(0.0)
	await _report(boat, p, 600, "coast")
	_check(boat.linear_velocity.length() < 60.0, "it slows (%.0f px/s)" % boat.linear_velocity.length())
	_check(absf(boat.rotation) < 0.5, "and rights itself (%.0f°)" % rad_to_deg(boat.rotation))

	# Turn about: the sail swings east and the player is mirrored with it.
	var local_before := boat.to_local(p.position).x
	boat.interact(p)
	await _steps(30)
	_check(boat.facing == 1, "turned about")
	_check(signf(boat.to_local(p.position).x) != signf(local_before), "the player moved to the other end")

	# Lean east without letting up: sooner or later it goes over.
	p.motion._submit_move(1.0)
	var t := 0
	while not boat.sinking and t < 120 * 30:
		await _steps(60)
		t += 60
		_print_boat(boat, p, "hold")
	_check(boat.sinking, "leaning without letting up capsizes it (%.1f s)" % (t / 120.0))
	await _steps(240)
	_check(p.actions.drowning, "and its sailor drowns")
	p.motion._submit_move(0.0)
	p.actions.wake_on_shore()
	await _steps(10)
	_free(p)
	boat.queue_free()
	await _steps(2)


## Each stretch's weather (log 0215): the Sound never rains, the Narrows
## about half its spells, and rain swells the Narrows' waves.
func _weather() -> void:
	var spells := int(NetSmoother.CLOCK_WRAP / Ocean.SPELL)
	var wet := 0
	var sound_wet := 0
	for k in spells:
		var mid := (k + 0.5) * Ocean.SPELL
		sound_wet += int(Ocean.rain(0, mid) > 0.0)
		wet += int(Ocean.rain(1, mid) == 1.0)
	_check(sound_wet == 0, "the Sound never rains")
	_check(wet >= spells * 0.3 and wet <= spells * 0.7, "the Narrows rain about half the time (%d of %d)" % [wet, spells])
	var x := (Coast.ISLAND_WEST_TOP + Coast.QUARRY_EAST_TOP) / 2.0
	Ocean.rain_override = 0.0
	var dry := Ocean.surface_y(x, 3.0) - Ocean.LEVEL
	Ocean.rain_override = 1.0
	var rainy := Ocean.surface_y(x, 3.0) - Ocean.LEVEL
	var sound := Ocean.surface_y(-9700.0, 3.0)
	Ocean.rain_override = 0.0
	var swell := float(Ocean.STRETCHES[1].swell)
	_check(is_equal_approx(rainy, dry * swell), "rain swells the Narrows' waves ×%.2f (%.2f -> %.2f)" % [swell, dry, rainy])
	_check(is_equal_approx(sound, Ocean.surface_y(-9700.0, 3.0)), "but not the Sound's")
	Ocean.rain_override = -1.0


func _drowning() -> void:
	var p := _spawn(4, 50, Vector2(-9000, Ocean.LEVEL - 200))
	p.inventory.add_to_bag(Gear.LOG)
	p.inventory.add_to_bag(Gear.POTION)
	await _steps(240)
	_check(p.actions.drowning, "falling into the sea drowns you")
	_check(p.inventory.count_of(Gear.LOG) == 0 and p.inventory.count_of(Gear.POTION) == 0, "and loses the bag")
	p.actions.wake_on_shore()
	await _steps(10)
	_check(p.position.distance_to(Coast.SHORE_SPAWN) < 80.0, "you wake on the shore")
	await _steps(120)
	_check(not p.actions.drowning, "dry on the shore")
	_free(p)


func _trees() -> void:
	var x := Coast.TREES[0]
	var tree_node := WorldResource.create({"name": "T0", "pos": Vector2(x, Coast.ground_y(x))})
	_check(tree_node is Timber, "trees are Timber, a kind of WorldResource")
	_root.add_child(tree_node)
	var a := _spawn(5, 50, Vector2(x + 280, Coast.SHORE_Y - 40))
	var b := _spawn(6, 50, Vector2(x - 200, Coast.SHORE_Y - 40))
	await _steps(60)
	# A real corner hit: roll into the trunk.
	a.motion._submit_move(-1.0)
	for i in 6:
		await _steps(60)
		a.motion._submit_jump()
	a.motion._submit_move(0.0)
	_check(tree_node.struck > 0, "rolling into a tree hits it (%d hits)" % tree_node.struck)
	# The rest by hand: a does three times what b does.
	dropped.clear()
	while not tree_node.felled:
		tree_node.take_hit(90.0, 5)
		tree_node.take_hit(30.0, 6)
	await _steps(2)
	var logs := dropped.filter(func(d: Array) -> bool: return d[0] == Gear.LOG)
	var to_a := logs.filter(func(d: Array) -> bool: return d[1] == 5).size()
	_check(logs.size() == 10 or logs.size() == 9, "a tree drops a log per 1,000 damage (%d)" % logs.size())
	_check(to_a >= 5, "more logs to whoever did more (%d of %d)" % [to_a, logs.size()])
	_check(tree_node.felled, "it falls at 10,000")
	tree_node.take_hit(500.0, 5)
	_check(dropped.size() == logs.size(), "a stump drops nothing")
	_free(a)
	_free(b)


func _selling() -> void:
	var p := _spawn(7, 50, Coast.SHORE_SPAWN)
	for i in 3:
		p.inventory.add_to_bag(Gear.LOG)
	var before: int = p.stats.chits
	_check(p.actions.sell_logs("The Dock Tradesman") == 3, "the tradesman buys every log")
	_check(p.stats.chits == before + 600, "for 200 chits each")
	_check(p.inventory.count_of(Gear.LOG) == 0, "and takes them")
	_free(p)


func _market() -> void:
	var market := Market.new()
	_root.add_child(market)
	var m := _spawn(8, 55, Coast.SHORE_SPAWN)
	var workman := _spawn(9, 50, Coast.SHORE_SPAWN)
	m.stats.chits = 5000
	m.stats.coins = 0
	_check(market.trade(workman, "buy_chits", 1) == "Merchants only.", "only merchants trade")
	var price := market.chit_price()
	_check(price == Market.BASE_CHITS, "normal stock, normal price (%d)" % price)
	market.trade(m, "buy_chits", 5)
	_check(m.inventory.count_of(Gear.LOG) == 5 and m.stats.chits == 5000 - 5 * price, "bought 5 logs with chits")
	_check(market.stock == Market.STOCK_START - 5 and market.chit_price() > price, "scarcer, dearer (%d)" % market.chit_price())
	market.stock = Market.STOCK_MAX
	_check(market.chit_price() == Market.CHITS_RANGE.x, "a glut is cheap, never under the Tradesman's 200")

	var orders := market.orders_for(m.peer_id)
	_check(orders.size() == 2, "a first visit brings two orders")
	var order: Dictionary = orders[0]
	while m.inventory.count_of(Gear.LOG) < order.qty:
		m.inventory.add_to_bag(Gear.LOG)
	var had := m.inventory.count_of(Gear.LOG)
	print("  ", market.trade(m, "deliver", order.id))
	_check(m.stats.coins == order.qty * order.price, "filling an order pays coins (%d)" % m.stats.coins)
	_check(m.inventory.count_of(Gear.LOG) == had - order.qty, "and takes the logs")

	m.stats.coins = 1000
	market.stock = 30
	var each := market.work_price()
	print("  ", market.trade(m, "work", 4))
	_check(m.stats.coins == 1000 - 4 * each, "a work order is paid up front, at a premium (%d each)" % each)
	var stock_before := market.stock
	market.add_supply(3)
	_check(m.stats.dock_held == 3 and market.stock == stock_before, "workmen's logs fill work orders first")
	market.add_supply(3)
	_check(m.stats.dock_held == 4 and market.stock == stock_before + 2, "then the stock")
	m.inventory.bag = PlayerInventory.blank(PlayerInventory.BAG_SIZE)
	print("  ", market.trade(m, "collect", 0))
	_check(m.inventory.count_of(Gear.LOG) == 4 and m.stats.dock_held == 0, "held logs collected")
	_check(PlayerSave.sanitize({"level": 1, "dock_held": 999}).dock_held == Market.HELD_MAX, "held logs are capped in saves")
	_free(m)
	_free(workman)
	market.queue_free()


## The Quarry Isle's ore (log 0211): rocks drop ore, the dock buys and sells it.
func _ore() -> void:
	var x := Coast.ORE_ROCKS[0]
	var rock := WorldResource.create({"name": "O0", "pos": Vector2(x, Coast.ground_y(x)), "kind": "ore"})
	_check(rock is OreRock, "ore rocks are OreRocks, a kind of WorldResource")
	_root.add_child(rock)
	var a := _spawn(10, 50, Vector2(x + 200, Coast.SHORE_Y - 40))
	await _steps(5)
	dropped.clear()
	while not rock.felled:
		rock.take_hit(100.0, 10)
	await _steps(2)
	var ore := dropped.filter(func(d: Array) -> bool: return d[0] == Gear.ORE)
	_check(ore.size() == OreRock.HEALTH / OreRock.ORE_EVERY and dropped.size() == ore.size(),
			"a rock drops %d ore and nothing else (%d)" % [OreRock.HEALTH / OreRock.ORE_EVERY, ore.size()])
	rock.queue_free()

	for i in 2:
		a.inventory.add_to_bag(Gear.ORE)
	a.inventory.add_to_bag(Gear.LOG)
	var before: int = a.stats.chits
	_check(a.actions.sell_logs("The Dock Tradesman") == 3, "the tradesman buys ore with the logs")
	_check(a.stats.chits == before + 2 * 600 + 200, "ore at 600 chits (%d)" % (a.stats.chits - before))

	var market := Market.new()
	_root.add_child(market)
	var m := _spawn(11, 55, Coast.SHORE_SPAWN)
	m.stats.coins = 1000
	_check(market.ore_coin_price() > market.coin_price() * 2, "ore costs more than logs (%d vs %d)" % [
			market.ore_coin_price(), market.coin_price()])
	_check(market.ore_chit_price() >= 600, "never under the Tradesman's 600")
	var each := market.ore_coin_price()
	print("  ", market.trade(m, "buy_ore_coins", 3))
	_check(m.inventory.count_of(Gear.ORE) == 3 and m.stats.coins == 1000 - 3 * each, "a merchant buys ore for coins")
	_check(market.ore_stock == Market.ORE_START - 3, "from the dock's ore stock")
	market.add_ore_supply(5)
	_check(market.ore_stock == Market.ORE_START + 2, "workmen's ore goes into it")
	_free(a)
	_free(m)
	market.queue_free()


## Gear upgrade strings and numbers (log 0211).
func _upgrades() -> void:
	var caps := Gear.item("points", Gear.REGIMENTAL)
	_check(caps == "points_9" and Gear.price(caps) == 2500, "regimental caps are 2,500 chits")
	_check(Gear.item("points", 9, 3) == "points_9+3" and Gear.plus_of("points_9+3") == 3, "+3 is in the item")
	_check(Gear.tier_of("points_9+3") == 9 and Gear.slot_of("points_9+3") == "points", "and doesn't change its tier")
	_check(Gear.is_item("points_9+5") and not Gear.is_item("points_9+6") and not Gear.is_item("points_9+0"),
			"only +1 to +5 are real items")
	_check(Gear.price("points_9+1") == 0, "the Quartermaster doesn't sell upgraded gear")
	_check(Gear.upgraded("points_9+5") == "", "nothing past +5")
	var gains: Array = []
	for level in Gear.MAX_UPGRADE + 1:
		gains.append(Gear.bonuses(Gear.item("points", 9, level)).force)
	print("  regimental caps, +0..+5: ", gains)
	_check(gains[5] > gains[4] and gains[4] > gains[3] and gains[1] > gains[0], "each level adds")
	var full := PackedStringArray(["points_9", "plating_9", "", "eye_9", "voice_9"])
	_check(Gear.set_bonus(full) == {"vigor": 15, "force": 20}, "a full regimental set: +15 vigor, +20 force")
	var mixed := PackedStringArray(["points_9+5", "plating_9+5", "", "eye_9+5", "voice_9+2"])
	_check(Gear.set_level(mixed) == 2, "a set is as upgraded as its lowest piece")
	_check(Gear.set_bonus(mixed) == {"vigor": 18, "force": 24}, "and its bonus grows with it (%s)" % Gear.set_bonus(mixed))
	_check(Gear.set_tier(mixed) == 9, "upgraded pieces still make the set")
	_check(PlayerSave.clean_items(["points_9+4", "points_9+9", "ore"], 3) == PackedStringArray(["points_9+4", "", "ore"]),
			"saves keep upgrades and ore, and drop nonsense")


## The Blacksmith (log 0211): coins for +1 to +3, ore too for +4 and +5.
func _smith() -> void:
	var p := _spawn(12, 50, Coast.SHORE_SPAWN)
	for slot in Gear.MILITARY_SLOTS:
		p.inventory.add_to_bag(Gear.item(slot, Gear.REGIMENTAL))
	for i in 4:
		p.inventory._submit_equip(p.inventory.bag.find(Gear.item(Gear.MILITARY_SLOTS[i], Gear.REGIMENTAL)))
	await _steps(2)
	_check(Gear.set_tier(p.inventory.equipped) == 9, "wearing full regimental")
	var force_before: int = p.stats.force
	var worn_caps := PlayerActions.UPGRADE_WORN + Gear.SLOTS.find("points")
	p.stats.coins = 150
	_check(p.actions.upgrade(worn_caps) == "points_9+1" and p.stats.coins == 50, "+1 for 100 coins")
	_check(p.stats.force == force_before + 1, "worn: force goes up at once (%d -> %d)" % [force_before, p.stats.force])
	_check(p.actions.upgrade(worn_caps) == "" and p.stats.coins == 50, "+2 needs 200 coins")
	p.stats.coins = 100000
	p.actions.upgrade(worn_caps)
	p.actions.upgrade(worn_caps)
	_check(p.inventory.worn("points") == "points_9+3", "+3 with coins alone")
	_check(p.actions.upgrade(worn_caps) == "", "+4 needs ore")
	for i in 10:
		p.inventory.add_to_bag(Gear.ORE)
	_check(p.actions.upgrade(worn_caps) == "points_9+4", "+4 with 10 ore from the bag")
	_check(p.inventory.count_of(Gear.ORE) == 0 and p.stats.smith_ore == 0, "the ore's used")
	p.stats.smith_ore = 30
	_check(p.actions.upgrade(worn_caps) == "points_9+5" and p.stats.smith_ore == 5, "+5 with 25 ore on account")
	_check(p.actions.upgrade(worn_caps) == "", "and no further")
	var expected := 100000 - 200 - 300 - 500 - 1000
	_check(p.stats.coins == expected, "coins spent: 200 + 300 + 500 + 1,000 (%d)" % p.stats.coins)
	# Stats stay right through taking it off and putting it back.
	var force_on: int = p.stats.force
	p.inventory._submit_unequip(Gear.SLOTS.find("points"), -1)
	p.inventory._submit_equip(p.inventory.bag.find("points_9+5"))
	_check(p.stats.force == force_on, "off and on again: same force (%d)" % p.stats.force)
	var saved := PlayerSave.sanitize(PlayerSave.progress(p))
	_check(saved.smith_ore == 5 and "points_9+5" in saved.equipped, "ore on account and upgrades are saved")
	_free(p)


## Promissory notes (log 0212): bought for coins, stacking, filling orders.
func _notes() -> void:
	_check(Gear.note_count("note_12") == 12 and Gear.is_item("note_50") and not Gear.is_item("note_51")
			and not Gear.is_item("note_0") and not Gear.is_item("note_07"), "note stacks are note_1..note_50")
	var market := Market.new()
	_root.add_child(market)
	market.stock = 60
	var m := _spawn(13, 55, Coast.SHORE_SPAWN)
	m.stats.coins = 5000
	var each := market.coin_price()
	print("  ", market.trade(m, "buy_notes", 30))
	_check(m.inventory.count_notes() == 30 and m.stats.coins == 5000 - 30 * each, "30 notes for coins (%d each)" % each)
	_check(m.inventory.bag.count("note_30") == 1, "in one slot")
	_check(market.stock == 30, "taken from the dock's stock")
	market.stock = 60
	market.trade(m, "buy_notes", 50)
	_check(m.inventory.count_notes() == 80 and m.inventory.bag.count("note_50") == 1, "stacks fill to 50, then a new one")
	# Merging two stacks by dragging one onto the other.
	var a := m.inventory.bag.find("note_50")
	var b := m.inventory.bag.find("note_30")
	m.inventory._submit_swap(b, a)
	_check(m.inventory.bag[a] == "note_50" and m.inventory.bag[b] == "note_30", "a full stack takes no more")
	m.inventory.take_notes(20)
	_check(m.inventory.count_notes() == 60, "smallest stack used first (%s)" % [m.inventory.bag.slice(0, 3)])
	var c := m.inventory.bag.find("note_10")
	m.inventory._submit_swap(c, m.inventory.bag.find("note_50"))
	_check(m.inventory.count_notes() == 60 and m.inventory.bag.count("note_50") == 1
			and m.inventory.bag.count("note_10") == 1, "merging keeps every note")
	# A booth order: logs first, then notes.
	var order: Dictionary = market.orders_for(m.peer_id)[0]
	m.inventory.add_to_bag(Gear.LOG)
	var coins: int = m.stats.coins
	print("  ", market.trade(m, "deliver", order.id))
	_check(m.inventory.count_of(Gear.LOG) == 0 and m.inventory.count_notes() == 60 - (order.qty - 1),
			"an order takes the log, then notes for the rest")
	_check(m.stats.coins == coins + order.qty * order.price, "and pays")
	_check(Gear.is_consumable("note_7"), "an heir keeps notes")
	_free(m)
	market.queue_free()


## The family strongroom (log 0212): chests for coins, kept by heirs and saved.
func _vault() -> void:
	var keeper_data: Dictionary = CenterTerrain.npcs().filter(func(d: Dictionary) -> bool: return d.get("role") == "vault")[0]
	var keeper := Npc.create(keeper_data)
	_root.add_child(keeper)
	var p := _spawn(14, 55, keeper_data.at + Vector2(40, -40))
	await _steps(2)
	p.stats.coins = 999
	_check(not p.actions.buy_chest() and p.inventory.vault.is_empty(), "the first chest is 1,000 coins")
	p.stats.coins = 20000
	_check(p.actions.buy_chest() and p.inventory.vault.size() == PlayerInventory.VAULT_CHEST_SLOTS
			and p.stats.coins == 19000, "bought: 10 slots")
	p.inventory.add_to_bag("plating_9+4")
	var from := p.inventory.bag.find("plating_9+4")
	p.inventory._submit_swap(from, PlayerInventory.VAULT_BASE + 3)
	_check(p.inventory.vault[3] == "plating_9+4" and p.inventory.bag[from] == "", "stored at the strongroom")
	p.actions.buy_chest()
	p.actions.buy_chest()
	_check(p.inventory.vault_chests() == 3 and p.stats.coins == 19000 - 3000 - 8000, "three chests at most")
	_check(not p.actions.buy_chest(), "no fourth")
	var saved := PlayerSave.sanitize(PlayerSave.progress(p))
	_check(saved.vault.size() == 30 and saved.vault[3] == "plating_9+4", "saved with the family's progress")
	_check(PlayerSave.sanitize({"level": 1, "vault": ["x", "ore"]}).vault.is_empty(), "part of a chest isn't kept")
	p.inventory.reset_for_heir()
	_check(p.inventory.vault[3] == "plating_9+4", "an heir keeps the strongroom")
	p.teleport(Coast.SHORE_SPAWN)
	await _steps(3)
	p.inventory._submit_swap(PlayerInventory.VAULT_BASE + 3, 0)
	_check(p.inventory.vault[3] == "plating_9+4", "only at the strongroom")
	await _heirlooms(p, keeper_data)
	_free(p)
	keeper.queue_free()


## Heirlooms (log 0216): worn armor passes down; a full slot asks which to keep.
func _heirlooms(p: PlayerShape, keeper_data: Dictionary) -> void:
	var bare := _spawn(15, 55, Coast.SHORE_SPAWN)
	bare.inventory.equipped = PackedStringArray(["points_9", "", "", "", ""])
	bare.inventory.reset_for_heir()
	_check(bare.inventory.heirlooms[0] == "", "no strongroom, nothing passed down")
	_free(bare)

	p.inventory.equipped = PackedStringArray(["points_9+2", "plating_8", "", "eye_9", ""])
	p.inventory.reset_for_heir()
	_check(p.inventory.heirlooms == PackedStringArray(["points_9+2", "plating_8", "", "eye_9", ""]),
			"an heir's worn armor goes to the empty heirloom slots")
	_check(p.inventory.heirloom_pending.count("") == 5, "nothing to choose yet")
	_check(p.inventory.equipped.count("") == 5, "and the new heir wears nothing")

	p.inventory.equipped = PackedStringArray(["points_9+5", "plating_6", "", "", "voice_9"])
	p.inventory.reset_for_heir()
	_check(p.inventory.heirlooms[4] == "voice_9", "an empty slot fills at once")
	_check(p.inventory.heirloom_pending[0] == "points_9+5" and p.inventory.heirloom_pending[1] == "plating_6"
			and p.inventory.heirlooms[0] == "points_9+2", "full slots wait for a choice, the old kept meanwhile")
	p.inventory._submit_choose_heirloom(0, true)
	_check(p.inventory.heirlooms[0] == "points_9+5" and p.inventory.heirloom_pending[0] == "", "choosing the new")
	p.inventory._submit_choose_heirloom(1, false)
	_check(p.inventory.heirlooms[1] == "plating_8" and p.inventory.heirloom_pending[1] == "", "choosing the old")

	# A choice left waiting is settled for the older piece at the next succession.
	p.inventory.equipped = PackedStringArray(["points_5", "", "", "", ""])
	p.inventory.reset_for_heir()
	p.inventory.equipped = PackedStringArray(["points_6", "", "", "", ""])
	p.inventory.reset_for_heir()
	_check(p.inventory.heirlooms[0] == "points_9+5" and p.inventory.heirloom_pending[0] == "points_6",
			"an unanswered choice keeps the old heirloom")
	var saved := PlayerSave.sanitize(PlayerSave.progress(p))
	_check(saved.heirlooms[0] == "points_9+5" and saved.heirloom_pending[0] == "points_6",
			"heirlooms and the waiting choice are saved")
	_check(PlayerSave.sanitize({"level": 1, "heirlooms": ["plating_9"]}).heirlooms[0] == "",
			"no strongroom, no heirlooms in a save; wrong slots are dropped")

	# Taking one out, and the slot taking only its own kind.
	p.teleport(keeper_data.at + Vector2(40, -40))
	await _steps(3)
	p.inventory.bag = PlayerInventory.blank(PlayerInventory.BAG_SIZE)
	p.inventory._submit_swap(PlayerInventory.HEIRLOOM_BASE + 0, 0)
	_check(p.inventory.bag[0] == "points_9+5" and p.inventory.heirlooms[0] == "", "taken out at the strongroom")
	p.inventory.bag[1] = "plating_9"
	p.inventory.bag = p.inventory.bag
	p.inventory._submit_swap(1, PlayerInventory.HEIRLOOM_BASE + 0)
	_check(p.inventory.heirlooms[0] == "", "the caps slot won't take plating")
	p.inventory._submit_swap(0, PlayerInventory.HEIRLOOM_BASE + 0)
	_check(p.inventory.heirlooms[0] == "points_9+5", "but takes caps back")


func _spawn(id: int, apex: int, pos: Vector2) -> PlayerShape:
	var p := PlayerShape.create({"id": id, "family": "Coast%d" % id, "sides": 3, "kind": "isosceles",
			"apex": apex, "luck": 0, "generation": 1, "progress": {}, "chest": [], "pos": pos})
	_root.add_child(p)
	_players[id] = p
	return p


func _free(p: PlayerShape) -> void:
	_players.erase(p.peer_id)
	p.queue_free()


func _report(boat: Boat, p: PlayerShape, steps: int, label: String) -> void:
	await _steps(steps)
	_print_boat(boat, p, label)


func _print_boat(boat: Boat, p: PlayerShape, label: String) -> void:
	print("BOAT %-8s x=%6d y=%4d speed=%4d lean=%4.0f° aboard=%s" % [label, boat.position.x, boat.position.y,
			boat.linear_velocity.x, rad_to_deg(boat.rotation), p in boat.riders()])


func _steps(n: int) -> void:
	for i in n:
		await tree.physics_frame


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL ", what)
	else:
		print("ok   ", what)

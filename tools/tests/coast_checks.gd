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
	await _trees()
	_selling()
	_market()

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
	var tree_node := Timber.create({"name": "T0", "pos": Vector2(x, Coast.ground_y(x))})
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

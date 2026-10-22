class_name Market
extends Node2D
## The merchants' game (design log 0205): two markets to time.
##
## - The dock (the Harbourmaster): sells logs from one stock, shared by
##   everyone, for chits or coins. The price follows the stock: scarce is
##   dear, a glut is cheap. Logs the workmen sell to the Dock Tradesman go
##   into it; a crew adds a few; now and then a glut washes in or a
##   shipwright buys a pile. A merchant can post a work order for logs the
##   dock doesn't have, paid up front in coins at a premium; workmen's
##   deliveries fill it first, the crew slowly otherwise, and the logs wait
##   at the dock to be collected.
## - Merchants' Row in the Center: each merchant's booth gets buyers'
##   orders (some buyer wants so many logs at so many coins each, for a
##   while). Bring the logs in your bag to fill one, for coins. Some offers
##   come in under the dock's price: buy cheap, hold, and wait.
##
## Merchants are triangles with a 55°+ apex, or any higher rank (Regions
## "merchants"). Every peer builds the Market (it draws the Row's stalls);
## only the server trades. A player's screen gets a snapshot after each
## trade (PlayerScreen.show_market). *Proposed* numbers throughout.

const GROUP := "market"

const STOCK_START := 20
const STOCK_FULL := 40  # "a full dock": the price is low from here
const STOCK_MAX := 80
const CREW_EVERY := 30.0  # s per log the dock's crew brings in
## The dock's price, at normal stock, and how far it can move.
const BASE_CHITS := 260
const CHITS_RANGE := Vector2i(210, 420)  # never under what the Tradesman pays (200)
const BASE_COINS := 28
const COINS_RANGE := Vector2i(12, 50)
## A work order costs this much more than the dock's coin price, per log.
const WORK_PREMIUM := 1.5
const WORK_EVERY := 20.0  # s per log the crew brings for a work order
const WORK_MAX := 10  # logs one work order can ask for
const HELD_MAX := 30  # logs waiting at the dock for one merchant
## Swings: every SWING_EVERY s (random in range), a glut or a shortage.
const SWING_EVERY := Vector2(150.0, 300.0)
const SWING_SIZE := Vector2i(10, 20)
## Buyers' orders at a merchant's booth.
const ORDERS_MAX := 3
const ORDER_EVERY := 90.0  # s between new orders
const ORDER_TIME := 600.0  # s an order stays open
const ORDER_SIZE := Vector2i(2, 8)
const ORDER_PRICE := 32  # coins per log, times a random 0.6-1.5
const BUYERS: Array[String] = ["The Carpenter", "The Cooper", "The Shipwright", "A Noble's Steward",
		"The Wheelwright", "The Temple's Verger"]

## The Row's stalls, in the Center, on the flat of the east rise (x of
## each, floor y).
const STALLS: Array[float] = [745.0, 850.0, 955.0]
const ROW_FLOOR := -110.0

const HARBOURMASTER := "The Harbourmaster"
const CLERK := "The Market Clerk"
## The market's people (World builds them as Npc).
const NPCS: Array[Dictionary] = [
	{
		"name": HARBOURMASTER, "at": Vector2(-6980, Coast.SHORE_Y), "sides": 4, "radius": 27.0,
		"role": "market", "serves": "merchants",
		"lines": ["Logs by the stack, for chits or coin. The price is the tide's, not mine."],
		"refusals": ["The stock's for merchants, friend. Sell your logs to the Tradesman."],
	},
	{
		"name": CLERK, "at": Vector2(850, ROW_FLOOR), "sides": 3, "kind": "equilateral", "radius": 26.0,
		"role": "booth", "serves": "merchants",
		"lines": ["Your booth's orders, merchant. Fill them before they go elsewhere."],
		"refusals": ["Merchants' Row is for merchants. A wider apex, and we'll talk."],
	},
]

var stock := STOCK_START
var _crew := 0.0
var _swing := 200.0
var _orders := {}  # peer id -> [{"id", "buyer", "qty", "price", "left"}]
var _order_timer := {}  # peer id -> s until their next order
var _next_order_id := 0
var _work := {}  # peer id -> {"left": logs to come, "timer": s}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(GROUP)
	_rng.randomize()
	_swing = _rng.randf_range(SWING_EVERY.x, SWING_EVERY.y)


# --- Prices -----------------------------------------------------------------

## Dearer when the dock is short, cheaper when it's full: 1.6 at empty, 1.0
## at STOCK_START, 0.8 at STOCK_FULL, 0.5 at STOCK_MAX.
func scarcity() -> float:
	if stock <= STOCK_START:
		return lerpf(1.6, 1.0, float(stock) / STOCK_START)
	if stock <= STOCK_FULL:
		return lerpf(1.0, 0.8, float(stock - STOCK_START) / (STOCK_FULL - STOCK_START))
	return lerpf(0.8, 0.5, clampf(float(stock - STOCK_FULL) / (STOCK_MAX - STOCK_FULL), 0.0, 1.0))


func chit_price() -> int:
	return clampi(roundi(BASE_CHITS * scarcity()), CHITS_RANGE.x, CHITS_RANGE.y)


func coin_price() -> int:
	return clampi(roundi(BASE_COINS * scarcity()), COINS_RANGE.x, COINS_RANGE.y)


func work_price() -> int:
	return ceili(coin_price() * WORK_PREMIUM)


# --- Time (server) ------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_crew += delta
	if _crew >= CREW_EVERY:
		_crew = 0.0
		if stock < STOCK_FULL:
			stock += 1
	_swing -= delta
	if _swing <= 0.0:
		_swing = _rng.randf_range(SWING_EVERY.x, SWING_EVERY.y)
		var size := _rng.randi_range(SWING_SIZE.x, SWING_SIZE.y)
		stock = clampi(stock + (size if _rng.randf() < 0.5 else -size), 0, STOCK_MAX)
	for id: int in _work.keys():
		var work: Dictionary = _work[id]
		work.timer -= delta
		if work.timer <= 0.0:
			work.timer = WORK_EVERY
			_deliver_work(id, 1)
	for id: int in _orders.keys():
		var open: Array = _orders[id]
		for order: Dictionary in open:
			order.left -= delta
		_orders[id] = open.filter(func(o: Dictionary) -> bool: return o.left > 0.0)
	for id: int in _order_timer.keys():
		_order_timer[id] -= delta
		if _order_timer[id] <= 0.0:
			_order_timer[id] = ORDER_EVERY
			_new_order(id)


## Server only. A merchant's booth starts getting orders once they've
## visited it (orders_for), and stops when they leave (forget).
func forget(id: int) -> void:
	_orders.erase(id)
	_order_timer.erase(id)
	_work.erase(id)


func _new_order(id: int) -> void:
	var open: Array = _orders.get(id, [])
	if open.size() >= ORDERS_MAX:
		return
	_next_order_id += 1
	open.append({
		"id": _next_order_id,
		"buyer": BUYERS[_rng.randi_range(0, BUYERS.size() - 1)],
		"qty": _rng.randi_range(ORDER_SIZE.x, ORDER_SIZE.y),
		"price": maxi(roundi(ORDER_PRICE * _rng.randf_range(0.6, 1.5)), 1),
		"left": ORDER_TIME,
	})
	_orders[id] = open


## Server only. A merchant's open orders; the first visit starts them off.
func orders_for(id: int) -> Array:
	if not _order_timer.has(id):
		_order_timer[id] = ORDER_EVERY
		_new_order(id)
		_new_order(id)
	return _orders.get(id, [])


# --- Trades (server) ----------------------------------------------------------

## Server only. Logs sold to the Dock Tradesman (log 0204) come to the
## dock: work orders first, then the stock.
func add_supply(count: int) -> void:
	for id: int in _work.keys():
		if count <= 0:
			break
		var take := mini(count, int(_work[id].left))
		count -= take
		_deliver_work(id, take)
	stock = mini(stock + count, STOCK_MAX)


func _deliver_work(id: int, count: int) -> void:
	if not _work.has(id) or count <= 0:
		return
	var p := _player(id)
	if p != null:
		p.stats.dock_held = mini(p.stats.dock_held + count, HELD_MAX)
	_work[id].left -= count
	if _work[id].left <= 0:
		_work.erase(id)
		if p != null:
			p.screen.tell(HARBOURMASTER, "Your work order's in. Collect it at the dock.")


## Server only. A merchant's trade; returns what to tell them, or "".
## "buy_chits" / "buy_coins": `amount` logs from the stock into the bag.
## "work": post a work order for `amount` logs. "collect": held logs into
## the bag. "deliver": fill order `amount` from the bag.
func trade(p: PlayerShape, action: String, amount: int) -> String:
	if not Regions.admits("merchants", p.sides, p.kind, p.apex):
		return "Merchants only."
	match action:
		"buy_chits", "buy_coins":
			return _buy(p, action == "buy_coins", amount)
		"work":
			return _post_work(p, amount)
		"collect":
			return _collect(p)
		"deliver":
			return _fill_order(p, amount)
	return ""


func _buy(p: PlayerShape, with_coins: bool, amount: int) -> String:
	amount = clampi(amount, 1, PlayerInventory.BAG_SIZE)
	if stock <= 0:
		return "The dock's bare. Post a work order, or wait for the tide."
	amount = mini(amount, stock)
	var free := p.inventory.bag.count("")
	if free == 0:
		return "Your bag's full."
	amount = mini(amount, free)
	var each := coin_price() if with_coins else chit_price()
	var have := p.stats.coins if with_coins else p.stats.chits
	amount = mini(amount, have / each)
	if amount <= 0:
		return "That's %d %s a log. You can't cover one." % [each, "coins" if with_coins else "chits"]
	for i in amount:
		p.inventory.add_to_bag(Gear.LOG)
	if with_coins:
		p.stats.coins -= amount * each
	else:
		p.stats.chits -= amount * each
	stock -= amount
	return "%d %s at %d %s. Mind they don't get wet." % [amount, "log" if amount == 1 else "logs", each,
			"coins" if with_coins else "chits"]


func _post_work(p: PlayerShape, amount: int) -> String:
	if _work.has(p.peer_id):
		return "You've a work order out already: %d to come." % _work[p.peer_id].left
	amount = clampi(amount, 1, WORK_MAX)
	var cost := amount * work_price()
	if p.stats.coins < cost:
		return "A work order for %d is %d coins. You have %d." % [amount, cost, p.stats.coins]
	p.stats.coins -= cost
	_work[p.peer_id] = {"left": amount, "timer": WORK_EVERY}
	return "Work order posted: %d logs, %d coins. The crew's on it." % [amount, cost]


func _collect(p: PlayerShape) -> String:
	var held := p.stats.dock_held
	if held <= 0:
		return "Nothing waiting for you."
	var take := mini(held, p.inventory.bag.count(""))
	if take <= 0:
		return "Your bag's full."
	for i in take:
		p.inventory.add_to_bag(Gear.LOG)
	p.stats.dock_held -= take
	return "%d %s collected%s." % [take, "log" if take == 1 else "logs",
			"" if take == held else "; %d still waiting" % (held - take)]


func _fill_order(p: PlayerShape, order_id: int) -> String:
	var open: Array = _orders.get(p.peer_id, [])
	for order: Dictionary in open:
		if order.id != order_id:
			continue
		if p.inventory.count_of(Gear.LOG) < order.qty:
			return "%s wants %d logs. You have %d." % [order.buyer, order.qty, p.inventory.count_of(Gear.LOG)]
		for i in order.qty:
			p.inventory.take_from_bag(Gear.LOG)
		var paid: int = order.qty * order.price
		p.stats.add_coins(paid)
		open.erase(order)
		return "%s takes %d logs: %d coins." % [order.buyer, order.qty, paid]
	return "That order's gone."


## What a player's screen shows (PlayerScreen.show_market).
func snapshot(p: PlayerShape) -> Dictionary:
	var orders: Array = []
	for order: Dictionary in orders_for(p.peer_id):
		orders.append([order.id, order.buyer, order.qty, order.price, roundi(order.left)])
	return {
		"stock": stock, "chit_price": chit_price(), "coin_price": coin_price(), "work_price": work_price(),
		"work_left": int(_work[p.peer_id].left) if _work.has(p.peer_id) else 0,
		"held": p.stats.dock_held, "orders": orders,
	}


func _player(id: int) -> PlayerShape:
	var world := get_tree().get_first_node_in_group(World.GROUP)
	return world.call("player", id) if world != null else null


# --- Drawing: Merchants' Row ------------------------------------------------

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for x in STALLS:
		var base := Vector2(x, ROW_FLOOR)
		var awning := PackedVector2Array([base + Vector2(-50, -110), base + Vector2(50, -110), base + Vector2(60, -85),
				base + Vector2(-60, -85)])
		draw_colored_polygon(awning, Palette.PARCHMENT_LIGHT)
		Gear.draw_hatch(self, awning, [[90.0], 14.0], 1.0, Color(Palette.INK, 0.3))
		awning.append(awning[0])
		draw_polyline(awning, Palette.INK, 2.0, true)
		for side in [-1.0, 1.0]:
			draw_line(base + Vector2(side * 50, -110), base + Vector2(side * 50, 0), Palette.INK, 2.5)
		var counter := Rect2(base + Vector2(-46, -40), Vector2(92, 40))
		draw_rect(counter, Palette.PARCHMENT_LIGHT)
		draw_rect(counter, Palette.INK, false, 2.0)
	draw_string(font, Vector2(STALLS[1] - 200, ROW_FLOOR - 128), "Merchants' Row", HORIZONTAL_ALIGNMENT_CENTER,
			400, 20, Palette.INK)

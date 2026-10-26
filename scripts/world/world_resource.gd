class_name WorldResource
extends StaticBody2D
## Something workmen gather by hitting it (design logs 0202, 0211): a tree
## on the Logging Isle (Timber), an ore rock on the Quarry Isle (OreRock).
## (Not "Resource": Godot already has a class by that name.)
##
## Jump (or roll) a corner into it to hurt it, as you would an enemy
## (PlayerCombat). It has `health`, never shown; every `drop_every` damage
## drops `item` for one of the players who hit it, picked at random
## weighted by how much each did. At 0 it's spent (felled, quarried out)
## and grows back after `regrow` seconds.
##
## The server spawns them (World, create) and copies them to clients;
## `felled` and `struck` (to shake it) are synced. A subclass sets the
## numbers in _init, and gives its outline (_outline) and drawing (_draw).

const GROUP := "world_resources"
const SHAKE_TIME := 0.25

## Set by each kind in _init.
var health := 10000
var drop_every := 1000
var item := Gear.LOG
var regrow := 180.0
var hit_lift := 80.0  # px above the foot where damage numbers show

var felled := false:
	set(value):
		felled = value
		if _body != null:
			_body.set_deferred("disabled", value)
var struck := 0:  # hits so far, so clients can shake it
	set(value):
		struck = value
		_shake = SHAKE_TIME

var _body: CollisionPolygon2D
var _damage := 0  # server: dealt so far this growth
var _dropped := 0  # items dropped so far this growth
var _by_peer := {}  # server: peer id -> damage dealt
var _regrow_left := 0.0
var _shake := 0.0
var _seed := 0


## The spawn function (World): data {"name", "pos" (its foot, on the
## ground), "kind" ("tree", the default, or "ore")}.
static func create(data: Dictionary) -> WorldResource:
	var r: WorldResource = OreRock.new() if data.get("kind", "tree") == "ore" else Timber.new()
	r.name = data.name
	r.position = data.pos
	r._seed = hash(data.name)
	r.collision_layer = PlayerShape.LAYER_TERRAIN
	r.collision_mask = 0
	r._body = CollisionPolygon2D.new()
	r._body.polygon = r._outline()
	r.add_child(r._body)

	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var config := SceneReplicationConfig.new()
	config.add_property(".:position")
	config.property_set_spawn(".:position", true)
	config.property_set_replication_mode(".:position", SceneReplicationConfig.REPLICATION_MODE_NEVER)
	for prop: String in [".:felled", ".:struck"]:
		config.add_property(prop)
		config.property_set_spawn(prop, true)
		config.property_set_replication_mode(prop, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	sync.replication_config = config
	sync.add_visibility_filter(func(id: int) -> bool: return Net.players.has(id))
	r.add_child(sync)
	return r


## Its collision outline, from the foot (0, 0) up. Subclasses override.
func _outline() -> PackedVector2Array:
	return PackedVector2Array()


## How far from its middle a drop lands, beside it. Subclasses override.
func _drop_reach() -> float:
	return 60.0


func _ready() -> void:
	add_to_group(GROUP)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or not felled:
		return
	_regrow_left -= delta
	if _regrow_left <= 0.0:
		_grow_back()


func _grow_back() -> void:
	_damage = 0
	_dropped = 0
	_by_peer.clear()
	_regrow_left = 0.0
	felled = false


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake -= delta
		queue_redraw()


## Server only. A player's corner hit (PlayerCombat).
func take_hit(raw: float, from_peer: int, crit := false) -> void:
	if felled:
		return
	var dealt := roundi(raw)
	if dealt <= 0:
		return
	_damage += dealt
	_by_peer[from_peer] = int(_by_peer.get(from_peer, 0)) + dealt
	struck += 1
	get_tree().call_group(World.GROUP, "show_damage", position + Vector2(0, -hit_lift - randf() * 60), dealt,
			"crit" if crit else "enemy")
	while _dropped < health / drop_every and _damage >= (_dropped + 1) * drop_every:
		_dropped += 1
		_drop()
	if _damage >= health:
		felled = true
		_regrow_left = regrow


## "tree" or "ore", as `create` takes it.
func kind() -> String:
	return "ore" if self is OreRock else "tree"


## Server only. Health left this growth (0 once spent).
func health_left() -> int:
	return 0 if felled else maxi(health - _damage, 0)


## Server only. Seconds until it grows back (0 while standing).
func regrow_left() -> float:
	return maxf(_regrow_left, 0.0) if felled else 0.0


## Server only (admin `resources deplete`, log 0217): spends it at once.
## Every drop still due goes to `who`: on the ground beside it, as a hit's
## would, or straight into the bag (the rest on the ground). Returns
## {"dropped": n, "bagged": n}.
func deplete(who: PlayerShape, to_bag := false) -> Dictionary:
	var out := {"dropped": 0, "bagged": 0}
	if felled:
		return out
	var due := health / drop_every - _dropped
	_damage = health
	_dropped += due
	felled = true
	_regrow_left = regrow
	struck += 1
	var world := get_tree().get_first_node_in_group(World.GROUP)
	for i in due:
		if to_bag and who.inventory.add_to_bag(item):
			out.bagged += 1
		elif world != null:  # a full bag's overflow lands on the ground too
			world.call_deferred("drop_item", item, who.peer_id, _drop_spot(who))
			out.dropped += 1
		else:
			continue
		who.quests.notify(item, "")
	return out


## Server only (admin `resources regrow`): grows back now. False if standing.
func regrow_now() -> bool:
	if not felled:
		return false
	_grow_back()
	return true


## Where a drop for `who` lands: beside it, on their side.
func _drop_spot(who: PlayerShape) -> Vector2:
	var side := signf(who.position.x - position.x)
	if side == 0.0:
		side = 1.0
	return position + Vector2(side * _drop_reach(), -30.0)


## One `item` for one of the players who hit it, weighted by damage dealt.
func _drop() -> void:
	var world := get_tree().get_first_node_in_group(World.GROUP)  # World, or a test's stand-in
	if world == null:
		return
	var total := 0
	var hitters := {}
	for id: int in _by_peer:
		if world.call("player", id) != null:
			hitters[id] = _by_peer[id]
			total += _by_peer[id]
	if total <= 0:
		return
	var roll := randi_range(1, total)
	for id: int in hitters:
		roll -= hitters[id]
		if roll <= 0:
			var who: PlayerShape = world.call("player", id)
			world.call_deferred("drop_item", item, id, _drop_spot(who))
			who.quests.notify(item, "")
			return

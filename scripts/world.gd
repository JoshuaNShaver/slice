class_name World
extends Node2D
## The world: the Center, the respawn hub (DESIGN §1), and the training cave
## to its west (design log 0027).
##
## The server spawns a PlayerShape for each registered player, the cave's
## enemies and their loot, and runs the physics. MultiplayerSpawners copy
## all of these to every client.
##
## Each player's own machine saves their heir's progress into the family
## save every few seconds and on leaving (design log 0038).

const MENU_SCENE := "res://scenes/main_menu.tscn"
const GROUP := "world"  # PlayerShape asks the world to drop items
const DamageNumber := preload("res://scripts/world/damage_number.gd")
const ENEMY_RESPAWN := 12.0  # s
const BOSS_RESPAWN := 90.0
## Chance (before luck) that a cave enemy drops a piece of its room's gear
## tier for each player who hit it. The boss always drops (design log 0029).
const GEAR_DROP_CHANCE := 0.15
## Chances (before luck) for a healing potion from a cave enemy, and a
## blessed certificate from the boss (design logs 0032, 0037). The boss
## always drops a potion.
const POTION_DROP_CHANCE := 0.1
const BLESSED_DROP_CHANCE := 0.05
const SAVE_INTERVAL := 3.0  # s between progress saves

var _players_root: Node2D
var _spawner: MultiplayerSpawner
var _camera: Camera2D
var _background: ParchmentBackground
var _hud: Hud
var _priest: Priest
var _enemies_root: Node2D
var _enemy_spawner: MultiplayerSpawner
var _pickups_root: Node2D
var _pickup_spawner: MultiplayerSpawner
var _pickup_count := 0
var _rng := RandomNumberGenerator.new()
var _save_timer := 0.0


func _ready() -> void:
	var back := CanvasLayer.new()
	back.layer = -1
	add_child(back)
	_background = ParchmentBackground.new()
	_background.auto_drift = false
	back.add_child(_background)

	add_to_group(GROUP)
	_rng.randomize()
	add_child(CenterTerrain.new())
	add_child(Cave.new())
	_priest = Priest.new()
	add_child(_priest)

	_enemies_root = _add_spawned_root("Enemies", Enemy.create)
	_enemy_spawner = get_node("EnemiesSpawner")
	_pickups_root = _add_spawned_root("Pickups", Pickup.create)
	_pickup_spawner = get_node("PickupsSpawner")

	_players_root = Node2D.new()
	_players_root.name = "Players"
	add_child(_players_root)
	_spawner = MultiplayerSpawner.new()
	_spawner.name = "Spawner"
	_spawner.spawn_path = NodePath("../Players")
	_spawner.spawn_function = PlayerShape.create
	add_child(_spawner)

	_camera = Camera2D.new()
	_camera.position = CenterTerrain.SPAWN_POINT
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 6.0
	_camera.limit_left = int(Cave.WEST_X - 100)
	_camera.limit_right = int(CenterTerrain.RIGHT_EDGE + 100)
	_camera.limit_bottom = 400
	add_child(_camera)

	_hud = Hud.new()
	_hud.leave_requested.connect(_leave)
	add_child(_hud)

	Net.players_changed.connect(_on_players_changed)
	Net.session_ended.connect(_on_session_ended)
	Net.heir_born.connect(_on_heir_born)
	if multiplayer.is_server():
		_spawn_all_enemies()
		_on_players_changed()
	else:
		Net.announce_ready()


func _process(delta: float) -> void:
	var me := _local_player()
	if me != null:
		_camera.position = me.position
		_hud.update(me)
		_priest.prompt = _priest_prompt(me)
		_save_timer -= delta
		if _save_timer <= 0.0:
			_save_timer = SAVE_INTERVAL
			_save_progress(me)
	_background.view_offset = _camera.get_screen_center_position()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_progress(_local_player())


func _local_player() -> PlayerShape:
	return _players_root.get_node_or_null(str(multiplayer.get_unique_id())) as PlayerShape


## Owner's machine: keep the family save in step with this heir. Waits while
## a new heir's shape hasn't synced yet, so the old heir's level can't be
## saved onto the new one.
func _save_progress(me: PlayerShape) -> void:
	var family := FamilyStore.active_family()
	if me == null or family == null or family.extinct or me.generation != family.generation:
		return
	var now := me.progress()
	if now == family.progress:
		return
	family.progress = now
	FamilyStore.save_slot(FamilyStore.active_slot)


func _on_players_changed() -> void:
	if multiplayer.is_server():
		_sync_player_shapes()
	_hud.refresh_players()


## Server only: one shape per registered player.
func _sync_player_shapes() -> void:
	for id: int in Net.players:
		if not _players_root.has_node(str(id)):
			var info: Dictionary = Net.players[id]
			# Spread arrivals a little so shapes don't land in one heap.
			var n := _players_root.get_child_count()
			var offset := Vector2((n % 5) * 50.0 * (1 if n % 2 == 0 else -1), 0.0)
			_spawner.spawn({
				"id": id,
				"family": info.family,
				"sides": info.sides,
				"kind": info.kind,
				"apex": info.apex,
				"luck": info.luck,
				"generation": info.generation,
				"progress": Net.progress.get(id, {}),
				"pos": CenterTerrain.SPAWN_POINT + offset,
			})
	for shape: PlayerShape in _players_root.get_children():
		if not Net.players.has(shape.peer_id):
			_players_root.remove_child(shape)
			shape.queue_free()
		else:
			shape.sync.update_visibility()


## A root node for server-spawned things, plus the spawner that copies them.
func _add_spawned_root(root_name: String, create: Callable) -> Node2D:
	var root := Node2D.new()
	root.name = root_name
	add_child(root)
	var spawner := MultiplayerSpawner.new()
	spawner.name = root_name + "Spawner"
	spawner.spawn_path = NodePath("../" + root_name)
	spawner.spawn_function = create
	add_child(spawner)
	return root


func _priest_prompt(me: PlayerShape) -> String:
	if me.position.distance_to(Priest.POSITION) > Priest.REACH:
		return ""
	var certificate := me.marriage_certificate()
	if certificate == "":
		return "Bring me a marriage certificate."
	if certificate == Gear.BLESSED_CERTIFICATE and me.sides == 3 and me.kind != "equilateral":
		return "%s: marry (uses your blessed certificate)" % Controls.describe("interact")
	return "%s: marry (uses a certificate)" % Controls.describe("interact")


func _on_heir_born(heir: Dictionary) -> void:
	var shape := Family.with_article(Family.describe_shape(heir.sides, heir.kind, heir.apex))
	if heir.blessed:
		_hud.show_message("Blessed! Your heir is born %s." % shape)
	elif heir.gained_side:
		_hud.show_message("Married! Your heir is %s." % shape)
	elif heir.kind == "isosceles":
		_hud.show_message("Married! Your heir is %s, 5° nearer equilateral." % shape)
	else:
		_hud.show_message("Married! Your heir is %s. Only equilateral triangles have square heirs." % shape)


# --- Enemies (server only) ------------------------------------------------

func _spawn_all_enemies() -> void:
	var points := Cave.spawn_points()
	for i in points.size():
		_spawn_enemy(i, points[i])


func _spawn_enemy(index: int, point: Dictionary) -> void:
	if not is_inside_tree() or not multiplayer.is_server():
		return
	var data := point.duplicate()
	data.name = "E%d" % index
	if _enemies_root.has_node(String(data.name)):
		return
	var enemy: Enemy = _enemy_spawner.spawn(data)
	enemy.died.connect(_on_enemy_died.bind(index, point), CONNECT_ONE_SHOT)


func _on_enemy_died(enemy: Enemy, index: int, point: Dictionary) -> void:
	var info := enemy.info()
	for id: int in enemy.contributors:
		var player := _players_root.get_node_or_null(str(id)) as PlayerShape
		if player == null:
			continue
		player.add_xp(info.xp)
		var luck_chance := Stats.lucky_chance(GEAR_DROP_CHANCE, player.luck)
		if enemy.is_boss() or _rng.randf() < luck_chance:
			drop_item.call_deferred(Gear.random_item(info.tier, _rng), id, enemy.position)
		if enemy.is_boss() or _rng.randf() < Stats.lucky_chance(POTION_DROP_CHANCE, player.luck):
			drop_item.call_deferred(Gear.POTION, id, enemy.position + Vector2(-40, 0))
		if enemy.is_boss():
			drop_item.call_deferred(Gear.CERTIFICATE, id, enemy.position + Vector2(40, 0))
			if _rng.randf() < Stats.lucky_chance(BLESSED_DROP_CHANCE, player.luck):
				drop_item.call_deferred(Gear.BLESSED_CERTIFICATE, id, enemy.position + Vector2(80, 0))
	# Deferred: this runs inside a physics callback.
	enemy.queue_free()
	var wait := BOSS_RESPAWN if enemy.is_boss() else ENEMY_RESPAWN
	get_tree().create_timer(wait).timeout.connect(_spawn_enemy.bind(index, point))


## Server only. Puts an item on the ground that only `owner_id` can take.
func drop_item(item: String, owner_id: int, pos: Vector2) -> void:
	_pickup_count += 1
	_pickup_spawner.spawn({"name": "P%d" % _pickup_count, "item": item, "owner": owner_id, "pos": pos})


## Server only. Every player sees a hit's damage float up from `pos`
## (design log 0046). `kind` is "enemy", "crit" (logs 0047) or "player"
## (damage a player took).
func show_damage(pos: Vector2, amount: int, kind: String) -> void:
	if multiplayer.is_server() and amount > 0:
		_show_damage.rpc(pos, amount, kind)


@rpc("authority", "call_local", "unreliable")
func _show_damage(pos: Vector2, amount: int, kind: String) -> void:
	if DisplayServer.get_name() == "headless":  # a dedicated server has no one to show
		return
	var number := DamageNumber.new()
	number.position = pos
	number.amount = amount
	number.kind = kind
	add_child(number)


func _leave() -> void:
	_save_progress(_local_player())
	Net.leave()
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_session_ended(reason: String) -> void:
	Net.last_message = reason
	get_tree().change_scene_to_file(MENU_SCENE)

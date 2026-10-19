class_name World
extends Node2D
## The world (DESIGN §1, Regions): the Center, the barracks to the west,
## the Noble Quarter and the Priests' Hill to the east, the underworld below
## (the Undercroft and the training cave), and the missions' battlefields far
## off (design logs 0027, 0051-0072).
##
## The server spawns a PlayerShape for each registered player, the cave's
## and the drill yard's enemies and their loot, mission battlefields
## (Missions), and runs the physics. MultiplayerSpawners copy
## all of these to every client. NPCs, elevators and the house door are built
## from data on every peer alike; only the server acts on them (interact).
##
## The server saves each player's family and chests through Net.accounts
## (design logs 0097, 0113): it checks every few seconds and writes what
## changed, sooner for what matters.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const GROUP := "world"  # PlayerShape asks the world to drop items
const DamageNumber := preload("res://scripts/world/damage_number.gd")
const ENEMY_RESPAWN := 12.0  # s
const BOSS_RESPAWN := 90.0
## Gear and potion drop chances are per enemy type (Enemy.TYPES "drop",
## "potion"), rolled per player who hit it (design logs 0029, 0037). The
## chance (before luck) of a blessed certificate from a boss that drops
## certificates (design log 0032):
const BLESSED_DROP_CHANCE := 0.05
const SAVE_CHECK_INTERVAL := 3.0  # s between the server's save checks

var _players_root: Node2D
var _spawner: MultiplayerSpawner
var _camera: Camera2D
var _background: ParchmentBackground
var _hud: Hud
var _atmosphere: Atmosphere
var _place_id := ""
var _enemies_root: Node2D
var _enemy_spawner: MultiplayerSpawner
var _pickups_root: Node2D
var _pickup_spawner: MultiplayerSpawner
var _pickup_count := 0
var _missions_root: Node2D
var _mission_spawner: MultiplayerSpawner
var _missions: Missions
var _camera_place := "-"
var _rng := RandomNumberGenerator.new()
var _save_timer := 0.0


func _ready() -> void:
	var back := CanvasLayer.new()
	back.layer = -1
	add_child(back)
	_background = ParchmentBackground.new()
	_background.auto_drift = false
	back.add_child(_background)

	var front := CanvasLayer.new()
	front.layer = 1
	add_child(front)
	_atmosphere = Atmosphere.new()
	front.add_child(_atmosphere)

	add_to_group(GROUP)
	_rng.randomize()
	add_child(CenterTerrain.new())
	add_child(Barracks.new())
	add_child(UpperEast.new())
	add_child(Underworld.new())
	add_child(Cave.new())
	for lift: Dictionary in [CenterTerrain.LIFT_DOWN, CenterTerrain.LIFT_UP]:
		add_child(Elevator.create(lift))
	for data: Dictionary in CenterTerrain.NPCS + Barracks.NPCS + UpperEast.NPCS + Underworld.NPCS:
		add_child(Npc.create(data))
	var door := HouseDoor.new()
	door.position = Buildings.east_door(UpperEast.HOME, UpperEast.HOME_WIDTH)
	add_child(door)

	_enemies_root = _add_spawned_root("Enemies", Enemy.create)
	_enemy_spawner = get_node("EnemiesSpawner")
	_pickups_root = _add_spawned_root("Pickups", Pickup.create)
	_pickup_spawner = get_node("PickupsSpawner")
	_missions_root = _add_spawned_root("Missions", Mission.create)
	_mission_spawner = get_node("MissionsSpawner")
	_missions = Missions.new()
	_missions.name = "MissionControl"
	_missions.world = self
	add_child(_missions)

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
	add_child(_camera)
	_set_camera_limits(_world_bounds())

	_hud = Hud.new()
	_hud.layer = 2
	_hud.leave_requested.connect(_leave)
	add_child(_hud)

	Net.players_changed.connect(_on_players_changed)
	Net.session_ended.connect(_on_session_ended)
	Net.heir_born.connect(_on_heir_born)
	if multiplayer.is_server():
		Net.accounts.find_player = player
		_spawn_all_enemies()
		_on_players_changed()
	else:
		Net.announce_ready()


func _process(delta: float) -> void:
	var me := _local_player()
	if me != null:
		_camera.position = me.position
		_hud.update(me)
		_update_prompts(me)
		_announce_place(me)
		if _hud.storage_open() and not me.inventory.can_use_chest():
			_hud.close_storage()
		var panel := _hud.open_panel_name()
		if panel != "" and not Npc.near_role(me, "general" if panel == "orders" else "quartermaster"):
			_hud.close_panel()
		_follow_camera_limits(me)
	if multiplayer.is_server():
		_save_timer -= delta
		if _save_timer <= 0.0:
			_save_timer = SAVE_CHECK_INTERVAL
			for shape: PlayerShape in _players_root.get_children():
				Net.accounts.checkpoint(shape)
	var view := _camera.get_screen_center_position()
	_background.view_offset = view
	_background.depth = Regions.underworld_blend(view.y)
	_atmosphere.view = view


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and multiplayer.is_server():
		Net.accounts.save_all_now()


func _local_player() -> PlayerShape:
	return player(multiplayer.get_unique_id())


func player(peer_id: int) -> PlayerShape:
	return _players_root.get_node_or_null(str(peer_id)) as PlayerShape


## The camera stays inside the main world, or inside a mission's field.
func _world_bounds() -> Rect2:
	return Rect2(Cave.WEST_X - 100, UpperEast.TOP, UpperEast.EAST_X - Cave.WEST_X + 200,
			Underworld.BOTTOM - 200 - UpperEast.TOP)


func _follow_camera_limits(me: PlayerShape) -> void:
	var slot := Regions.mission_slot_at(me.position)
	var key := str(slot)
	if key == _camera_place:
		return
	_camera_place = key
	var bounds := _world_bounds()
	if slot >= 0:  # from just west of the field's wall
		bounds = Regions.mission_rect(slot)
		var west := Mission.origin(slot).x - 200.0
		bounds = Rect2(west, bounds.position.y, bounds.end.x - west, bounds.size.y)
	_set_camera_limits(bounds)
	_camera.reset_smoothing()


func _set_camera_limits(bounds: Rect2) -> void:
	_camera.limit_left = int(bounds.position.x)
	_camera.limit_right = int(bounds.end.x)
	_camera.limit_top = int(bounds.position.y)
	_camera.limit_bottom = int(bounds.end.y)


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
				"chest": Net.chests.get(id, PackedStringArray()),
				"pos": Regions.spawn_for(info.kind) + offset,
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


# --- Interaction (NPCs, elevators, the house door) ------------------------

## The interactable nearest `pos` and within its reach, or null. Each one has
## reach_distance(pos), prompt_for(player), interact(player) and `prompt`.
func _nearest_interactable(pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group(Npc.GROUP):
		var d: float = node.reach_distance(pos)
		if d < best_d:
			best_d = d
			best = node
	return best


## Local player: only the nearest interactable shows its prompt.
func _update_prompts(me: PlayerShape) -> void:
	var nearest := _nearest_interactable(me.position)
	for node in get_tree().get_nodes_in_group(Npc.GROUP):
		node.prompt = node.prompt_for(me) if node == nearest else ""


## Server only (PlayerActions._submit_interact).
func interact(who: PlayerShape) -> void:
	var target := _nearest_interactable(who.position)
	if target != null:
		target.interact(who)


## Server only (PlayerActions._submit_mission): the General's orders.
func request_mission(who: PlayerShape, mission_type: String) -> void:
	_missions.request(who, mission_type)


## Server only (PlayerActions._submit_ready): Ready in a countdown popup.
func mission_ready(who: PlayerShape) -> void:
	_missions.mark_ready(who)


## Local player: name each place on arriving there.
func _announce_place(me: PlayerShape) -> void:
	var place := Regions.at(me.position)
	if place.is_empty():
		return
	if _place_id != "" and place.id != _place_id:
		_hud.show_message(place.name)
	_place_id = place.id


func _on_heir_born(heir: Dictionary) -> void:
	var shape := Family.with_article(Family.describe_shape(heir.sides, heir.kind, heir.apex))
	if heir.blessed:
		_hud.think("Blessed! Your heir is born %s." % shape)
	elif heir.gained_side:
		_hud.think("Married! Your heir is %s." % shape)
	elif heir.kind == "isosceles":
		_hud.think("Married! Your heir is %s, 5° nearer equilateral." % shape)
	else:
		_hud.think("Married! Your heir is %s. Only equilateral triangles have square heirs." % shape)
	if heir.kind == "irregular":
		_hud.think("Married! Your heir is %s, and irregulars live below. Welcome to the Undercroft." % shape)


# --- Enemies (server only) ------------------------------------------------

## The cave's and the drill yard's enemies, which come back after dying.
func _spawn_all_enemies() -> void:
	var points := Cave.spawn_points() + Barracks.spawn_points()
	for i in points.size():
		_respawn_enemy(i, points[i])


func _respawn_enemy(index: int, point: Dictionary) -> void:
	if not is_inside_tree() or not multiplayer.is_server():
		return
	var data := point.duplicate()
	data.name = "E%d" % index
	if _enemies_root.has_node(String(data.name)):
		return
	var enemy := spawn_enemy(data)
	enemy.died.connect(_on_enemy_died.bind(index, point), CONNECT_ONE_SHOT)


## Server only. Spawns an enemy from Enemy.create data, on every peer.
func spawn_enemy(data: Dictionary) -> Enemy:
	return _enemy_spawner.spawn(data)


## Server only. Spawns a mission's battlefield (Mission.create data).
func spawn_mission(data: Dictionary) -> Mission:
	return _mission_spawner.spawn(data)


func _on_enemy_died(enemy: Enemy, index: int, point: Dictionary) -> void:
	reward_kill(enemy)
	# Deferred: this runs inside a physics callback.
	enemy.queue_free()
	var wait: float = point.get("respawn", BOSS_RESPAWN if enemy.is_boss() else ENEMY_RESPAWN)
	get_tree().create_timer(wait).timeout.connect(_respawn_enemy.bind(index, point))


## Server only. XP for everyone who hit `enemy`, and with `drops`, each
## one's own loot rolls (design logs 0028, 0029).
func reward_kill(enemy: Enemy, drops := true) -> void:
	var info := enemy.info()
	for id: int in enemy.contributors:
		var who := player(id)
		if who == null:
			continue
		who.stats.add_xp(info.xp)
		if not drops:
			continue
		if info.tier > 0 and _rng.randf() < Stats.lucky_chance(info.get("drop", 0.0), who.stats.luck):
			drop_item.call_deferred(Gear.random_item(info.tier, _rng), id, enemy.position)
		if _rng.randf() < Stats.lucky_chance(info.get("potion", 0.0), who.stats.luck):
			drop_item.call_deferred(Gear.POTION, id, enemy.position + Vector2(-40, 0))
		if enemy.is_boss():
			drop_item.call_deferred(Gear.CERTIFICATE, id, enemy.position + Vector2(40, 0))
			if _rng.randf() < Stats.lucky_chance(BLESSED_DROP_CHANCE, who.stats.luck):
				drop_item.call_deferred(Gear.BLESSED_CERTIFICATE, id, enemy.position + Vector2(80, 0))


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
	Net.leave()  # a local server saves everyone first
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_session_ended(reason: String) -> void:
	Net.last_message = reason
	get_tree().change_scene_to_file(MENU_SCENE)

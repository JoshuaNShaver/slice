extends Node2D
## The world. For now it holds only the Center, the respawn hub (DESIGN §1).
##
## The server spawns a PlayerShape for each registered player and runs the
## physics. The MultiplayerSpawner copies those shapes to every client.

const MENU_SCENE := "res://scenes/main_menu.tscn"

var _players_root: Node2D
var _spawner: MultiplayerSpawner
var _camera: Camera2D
var _background: ParchmentBackground
var _player_list: VBoxContainer
var _session_label: Label
var _health_bar: StatBar
var _energy_bar: StatBar
var _stats_label: Label


func _ready() -> void:
	PlayerShape.ensure_input_actions()

	var back := CanvasLayer.new()
	back.layer = -1
	add_child(back)
	_background = ParchmentBackground.new()
	_background.auto_drift = false
	back.add_child(_background)

	add_child(CenterTerrain.new())

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
	_camera.limit_left = int(CenterTerrain.LEFT_EDGE - 100)
	_camera.limit_right = int(CenterTerrain.RIGHT_EDGE + 100)
	_camera.limit_bottom = 400
	add_child(_camera)

	_build_hud()

	Net.players_changed.connect(_on_players_changed)
	Net.session_ended.connect(_on_session_ended)
	if multiplayer.is_server():
		_on_players_changed()
	else:
		Net.announce_ready()


func _process(_delta: float) -> void:
	var me := _players_root.get_node_or_null(str(multiplayer.get_unique_id()))
	if me != null:
		_camera.position = me.position
		_update_stat_hud(me)
	_background.view_offset = _camera.get_screen_center_position()


func _on_players_changed() -> void:
	if multiplayer.is_server():
		_sync_player_shapes()
	_refresh_player_list()


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
				"luck": info.luck,
				"pos": CenterTerrain.SPAWN_POINT + offset,
			})
	for shape: PlayerShape in _players_root.get_children():
		if not Net.players.has(shape.peer_id):
			_players_root.remove_child(shape)
			shape.queue_free()
		else:
			shape.sync.update_visibility()


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.build()
	hud.add_child(root)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	root.add_child(margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	var top := HBoxContainer.new()
	column.add_child(top)
	var title := Label.new()
	title.text = "The Center"
	title.add_theme_font_size_override("font_size", 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var leave := Button.new()
	leave.text = "Leave"
	leave.focus_mode = Control.FOCUS_NONE  # so Space jumps instead of pressing it
	leave.pressed.connect(_leave)
	top.add_child(leave)

	_session_label = Label.new()
	_session_label.text = Net.describe_session()
	_session_label.add_theme_color_override("font_color", Palette.INK_FADED)
	column.add_child(_session_label)

	_player_list = VBoxContainer.new()
	_player_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_player_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_player_list)

	# Your bars and stats, bottom left (design log 0021).
	_health_bar = StatBar.new("Health", Palette.HEALTH)
	column.add_child(_health_bar)
	_energy_bar = StatBar.new("Energy", Palette.ENERGY)
	column.add_child(_energy_bar)
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 15)
	column.add_child(_stats_label)

	var hint := Label.new()
	hint.text = "← → or A D to roll  ·  Space to jump (%d energy)" % PlayerShape.JUMP_COST
	if OS.is_debug_build():
		hint.text += "  ·  L to level up (debug)"
	hint.add_theme_color_override("font_color", Palette.INK_FADED)
	column.add_child(hint)


func _update_stat_hud(me: PlayerShape) -> void:
	_health_bar.set_values(me.hp, me.max_hp)
	_energy_bar.set_values(me.energy, Stats.MAX_ENERGY)
	_stats_label.text = "Level %d   Vigor %d   Mettle %d   Force %d   Rigidity %d   Torque %d   Luck %d" % [
		me.level, me.vigor, me.mettle, me.force, me.rigidity, me.torque, me.luck]


func _refresh_player_list() -> void:
	for child in _player_list.get_children():
		child.queue_free()
	for id: int in Net.players:
		var info: Dictionary = Net.players[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(ShapeIcon.new(info.sides, info.kind, 28))
		var label := Label.new()
		label.text = "The %s family: %s" % [info.family, Family.describe_shape(info.sides, info.kind)]
		if id == multiplayer.get_unique_id():
			label.text += "  (you)"
		row.add_child(label)
		_player_list.add_child(row)


func _leave() -> void:
	Net.leave()
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_session_ended(reason: String) -> void:
	Net.last_message = reason
	get_tree().change_scene_to_file(MENU_SCENE)

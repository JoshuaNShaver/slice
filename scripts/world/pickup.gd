class_name Pickup
extends Node2D
## An item on the ground (design log 0029). Loot is per player, Realm of the
## Mad God style: each one belongs to one player, and only they can take it.
## Everyone else sees it faded. The server runs the pickup; clients draw it.
##
## Nothing is taken by touch: press the pickup key (G) nearby to put it in
## your bag (design log 0036). Dropped items come back here too.

const RADIUS := 16.0
const LIFETIME := 90.0  # s before an untaken item disappears
const REACH := 70.0  # px from your center to grab it
const GROUP := "pickups"

var item := ""
var owner_id := 0

var _age := 0.0


static func create(data: Dictionary) -> Pickup:
	var p := Pickup.new()
	p.name = data.name
	p.item = data.item
	p.owner_id = data.owner
	p.position = data.pos
	# Only for visibility: clients whose world hasn't loaded don't get it yet.
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var config := SceneReplicationConfig.new()
	config.add_property(".:position")
	config.property_set_spawn(".:position", true)
	config.property_set_replication_mode(".:position", SceneReplicationConfig.REPLICATION_MODE_NEVER)
	sync.replication_config = config
	sync.add_visibility_filter(func(id: int) -> bool: return Net.players.has(id))
	p.add_child(sync)
	return p


func _ready() -> void:
	add_to_group(GROUP)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_age += delta
	if _age > LIFETIME:
		queue_free()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var mine := owner_id == multiplayer.get_unique_id()
	var bob := Vector2(0, sin(Time.get_ticks_msec() / 300.0) * 3.0)
	Gear.draw_icon(self, item, bob, 1.0 if mine else 0.3)
	if not mine:
		return
	var font := ThemeDB.fallback_font
	var text := Gear.item_name(item)
	if _local_player_near():
		text = "%s: pick up %s" % [Controls.describe("pickup"), text]
	draw_string(font, bob + Vector2(-150, 34), text, HORIZONTAL_ALIGNMENT_CENTER, 300, 14, Palette.INK)


func _local_player_near() -> bool:
	for node in get_tree().get_nodes_in_group(PlayerShape.GROUP):
		var player := node as PlayerShape
		if player.is_local():
			return player.position.distance_to(position) <= REACH
	return false

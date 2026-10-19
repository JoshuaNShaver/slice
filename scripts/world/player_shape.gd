class_name PlayerShape
extends RigidBody2D
## One player's polygon in the world.
##
## The server simulates it; clients only draw it (design log 0013). The owner
## sends its input to the server (PlayerInput). Because it is a real polygon,
## slope grip comes from the shape itself: sharp shapes rest on steep ground
## while many-sided shapes roll off.
##
## This node is the body: who you are (family, sides, kind), your outline,
## drawing, and the order things happen each physics step. Each job lives in
## a child node, made in create() alike on the server and every client, so
## their RPCs and synced properties line up (design log 0106):
## - motion (PlayerMotion): rolling, jumping, teleports, elevators, launches.
## - moves (PlayerMoves): queuing and using learned abilities (log 0086).
## - combat (PlayerCombat): hits given and taken, healing, death.
## - stats (PlayerStats): level, XP, stats, health, energy, pay, abilities.
## - inventory (PlayerInventory): bag, gear and house chests (logs 0036, 0064).
## - actions (PlayerActions): NPCs, shops, missions, marriage.
## - screen (PlayerScreen): server -> owner HUD messages and panels.
## - input (PlayerInput): the owner's keys, sent to the server.
## Saved progress (log 0038) is PlayerSave: progress() is what the family
## save keeps of this heir; create() restores it.

const RADIUS := 28.0
const COLLISION_PAD := 2.0
const LAYER_TERRAIN := 1
const LAYER_PLAYERS := 2
const GROUP := "players"
const CHEST_SLOTS := PlayerInventory.CHEST_SLOTS  # Net checks saved chests with this

var peer_id := 0
var family_name := ""
var sides := 3:
	set(value):
		sides = value
		_outline_dirty = true
var kind := "regular":
	set(value):
		kind = value
		_outline_dirty = true
var apex := 0:  # isosceles and irregular triangles (design logs 0031, 0096)
	set(value):
		apex = value
		_outline_dirty = true
var generation := 1  # which heir of the family this is
var spawn_point := Vector2.ZERO
var dead := false  # server only
var sync: MultiplayerSynchronizer
## Server -> clients each frame: x, y, rotation, vx, vy, spin, time (design
## logs 0093, 0095). Clients smooth it rather than snapping to each update.
var net_state := PackedFloat32Array():
	set(value):
		net_state = value
		if _smoother != null:
			_smoother.push(value)

var motion: PlayerMotion
var moves: PlayerMoves
var combat: PlayerCombat
var stats: PlayerStats
var inventory: PlayerInventory
var actions: PlayerActions
var screen: PlayerScreen
var input: PlayerInput

var points: PackedVector2Array  # the drawn outline
var corners: PackedVector2Array  # collision outline
var corner_angles: PackedFloat32Array
var _collision: CollisionPolygon2D
var _outline_dirty := true
var _smoother: NetSmoother  # clients only


## Used by the world's MultiplayerSpawner on the server and on every client.
static func create(data: Dictionary) -> PlayerShape:
	var p := PlayerShape.new()
	p.peer_id = data.id
	p.name = str(data.id)
	p.family_name = data.family
	p.sides = data.sides
	p.kind = data.kind
	p.apex = data.get("apex", 0)
	p.generation = data.get("generation", 1)
	p.spawn_point = data.pos
	p.position = data.pos
	p._rebuild_outline()
	# Same names and order everywhere: RPCs find these nodes by path.
	p.motion = p._part(PlayerMotion.new(), "Motion")
	p.moves = p._part(PlayerMoves.new(), "Moves")
	p.combat = p._part(PlayerCombat.new(), "Combat")
	p.stats = p._part(PlayerStats.new(), "Stats")
	p.inventory = p._part(PlayerInventory.new(), "Inventory")
	p.actions = p._part(PlayerActions.new(), "Actions")
	p.screen = p._part(PlayerScreen.new(), "Screen")
	p.input = p._part(PlayerInput.new(), "Input")
	p.stats.luck = data.get("luck", 0)
	PlayerSave.apply(p, data.get("progress", {}), data.get("chest", []))

	# Players pass through each other for now; they hit terrain and enemies.
	p.collision_layer = LAYER_PLAYERS
	p.collision_mask = LAYER_TERRAIN | Enemy.LAYER
	p.physics_material_override = PhysicsMaterial.new()
	p.physics_material_override.friction = 0.9
	p.physics_material_override.bounce = 0.2
	p.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	p.angular_damp = 0.1  # keep spin: momentum is the point
	p.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE  # stops fast corners sinking into the ground
	p.contact_monitor = true
	p.max_contacts_reported = 6
	p.custom_integrator = false
	p.can_sleep = false

	p.sync = MultiplayerSynchronizer.new()
	p.sync.name = "Sync"
	var config := SceneReplicationConfig.new()
	# Position and rotation arrive once at spawn, then as net_state.
	for prop: String in [".:position", ".:rotation"]:
		config.add_property(prop)
		config.property_set_spawn(prop, true)
		config.property_set_replication_mode(prop, SceneReplicationConfig.REPLICATION_MODE_NEVER)
	config.add_property(".:net_state")
	config.property_set_spawn(".:net_state", false)  # the first update is a live one
	config.property_set_replication_mode(".:net_state", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	config.add_property("Stats:energy")
	config.property_set_spawn("Stats:energy", true)
	config.property_set_replication_mode("Stats:energy", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var on_change: Array[String] = []
	for stat: String in ["level", "vigor", "mettle", "force", "torque", "rigidity", "luck", "hp", "max_hp",
			"xp", "pay", "abilities"]:
		on_change.append("Stats:" + stat)
	for items: String in ["bag", "equipped", "chest"]:
		on_change.append("Inventory:" + items)
	for prop: String in ["sides", "kind", "apex", "generation"]:
		on_change.append(".:" + prop)
	for prop in on_change:
		config.add_property(prop)
		config.property_set_spawn(prop, true)
		config.property_set_replication_mode(prop, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	p.sync.replication_config = config
	# Only peers whose world has loaded (registered players) get this shape.
	p.sync.add_visibility_filter(func(id: int) -> bool: return Net.players.has(id))
	p.add_child(p.sync)
	return p


func _part(node: Node, part_name: String) -> Node:
	node.name = part_name
	node.set("player", self)
	add_child(node)
	return node


## Server only: true inside an RPC from this shape's owner (or a local call).
func from_owner() -> bool:
	return multiplayer.is_server() and multiplayer.get_remote_sender_id() in [peer_id, 0]


## Outline and collision for the current sides and kind. Runs again when an
## heir takes over the shape.
func _rebuild_outline() -> void:
	_outline_dirty = false
	points = ShapeGeometry.points(sides, kind, RADIUS, apex)
	# The collision outline is a little bigger than the drawing, so the solver's
	# small overlap on impact doesn't look like corners sinking into the ground.
	corners = ShapeGeometry.points(sides, kind, RADIUS + COLLISION_PAD, apex)
	corner_angles = ShapeGeometry.corner_angles(corners)
	if _collision == null:
		_collision = CollisionPolygon2D.new()
		add_child(_collision)
	_collision.polygon = corners


func _ready() -> void:
	add_to_group(GROUP)
	# Clients never simulate: the server's position and rotation are copied in.
	if not multiplayer.is_server():
		freeze = true
		freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		_smoother = NetSmoother.new()
		_smoother.live = is_local()


func is_local() -> bool:
	return peer_id == multiplayer.get_unique_id()


func _process(delta: float) -> void:
	if multiplayer.is_server():
		net_state = NetSmoother.state_of(self)
	elif not _smoother.is_empty():
		var s := _smoother.current(delta)
		position = Vector2(s.x, s.y)
		rotation = s.z
	if _outline_dirty:
		_rebuild_outline()
	queue_redraw()  # keeps the name tag upright as the shape turns


## Server only. One physics step, in this order: energy and healing, then
## movement (which may end the step), then abilities, then corner hits.
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not multiplayer.is_server():
		return
	stats.regen_energy(state.step)
	combat.tick(state.step)
	var phase := motion.integrate(state)
	if phase == PlayerMotion.HALT:
		return
	if phase == PlayerMotion.THROWN:
		moves.drop_queued()
	else:
		if phase == PlayerMotion.JUMPED:
			moves.on_jump()
		moves.tick(state)
	combat.hit_check(state)


## Server only. Moves the shape to `pos` on the next physics step.
func teleport(pos: Vector2) -> void:
	motion.teleport(pos)


## Server only. Thrown by a spike up (SpikeUpAbility calls this on players
## and enemies alike).
func launch(velocity: Vector2, onto: Node2D) -> void:
	motion.launch(velocity, onto)


## Server only. Saved progress (design log 0038), for the family save.
func progress() -> Dictionary:
	return PlayerSave.progress(self)


## Server only. A save from the player's machine, checked (PlayerSave).
static func sanitize_progress(raw: Dictionary) -> Dictionary:
	return PlayerSave.sanitize(raw)


static func _clean_items(raw: Variant, size: int) -> PackedStringArray:
	return PlayerSave.clean_items(raw, size)


## Server only. The heir takes over this shape, starting fresh at level 1 with
## no gear, back at the spawn point (design log 0030). The certificate used
## is already gone; spare certificates, potions and pay are kept, gear is not.
func become_heir(heir: Dictionary) -> void:
	inventory.reset_for_heir()
	stats.abilities = PackedStringArray()  # the heir hasn't been drilled (design log 0086)
	sides = heir.sides
	kind = heir.kind
	apex = heir.apex
	stats.luck = heir.luck
	generation += 1
	spawn_point = Regions.spawn_for(kind)  # an irregular heir goes below (log 0059)
	_rebuild_outline()
	stats.reset_for_heir()
	teleport(spawn_point)


func _draw() -> void:
	Gear.draw_shape(self, points, sides, inventory.equipped)

	draw_set_transform(Vector2.ZERO, -rotation)
	var font := ThemeDB.fallback_font
	var tag := family_name + (" (you)" if is_local() else "")
	draw_string(font, Vector2(-150, -RADIUS - 12), tag, HORIZONTAL_ALIGNMENT_CENTER, 300, 15, Palette.faded_at(position))
	# Under the name: other players' health; your energy (your health is in the HUD).
	if is_local():
		_draw_energy_pips()
	else:
		var bar := Rect2(-24, -RADIUS - 9, 48, 5)
		draw_rect(bar, Palette.PARCHMENT)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * stats.hp / maxf(stats.max_hp, 1), bar.size.y)), Palette.HEALTH)
		draw_rect(bar, Palette.INK, false, 1.0)


## One pip per ability's worth of energy (design logs 0026, 0087). Faded when
## full, so it only draws the eye while you're spending it.
func _draw_energy_pips() -> void:
	var energy := stats.energy
	var count := ceili(Stats.MAX_ENERGY / Abilities.COST)
	var pip := Vector2(12, 6)
	var gap := 3.0
	var left := -(count * pip.x + (count - 1) * gap) / 2.0
	var alpha := 0.35 if energy >= Stats.MAX_ENERGY else 1.0
	for i in count:
		var box := Rect2(left + i * (pip.x + gap), -RADIUS - 10, pip.x, pip.y)
		var share := clampf((energy - i * Abilities.COST) / Abilities.COST, 0.0, 1.0)
		draw_rect(box, Color(Palette.PARCHMENT, alpha))
		draw_rect(Rect2(box.position, Vector2(box.size.x * share, box.size.y)), Color(Palette.ENERGY, alpha))
		draw_rect(box, Color(Palette.INK, alpha), false, 1.0)

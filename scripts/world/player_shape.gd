class_name PlayerShape
extends RigidBody2D
## One player's polygon in the world.
##
## The server simulates it; clients only draw it (design log 0013). The owner
## sends its input to the server. Left/right spin the shape so it tumbles over
## its corners, and Space jumps (design log 0004). Because it is a real
## polygon, slope grip comes from the shape itself: sharp shapes rest on steep
## ground while many-sided shapes roll off.
##
## Movement is momentum-based. Holding a roll key raises your top spin over a
## few seconds, and nothing caps the speed you gain rolling downhill. Jumping
## again right as you land is a bounce: off a face it goes higher, and off a
## corner it goes higher still and flips you.
##
## Stats (design logs 0021-0022) live here too. The server owns them and they
## sync to every client for the bars. A jump costs energy; with too little
## energy you still jump, just weakly.
##
## Combat (design log 0027): your corners hurt enemies they strike, and
## theirs hurt you (Combat). Kills give XP (log 0028) and loot (log 0029).
## Health at 0 is death, and with no heir it ends the family (log 0015).
##
## Items (design log 0036): the server owns your bag and your five gear
## slots (Gear). You grab items off the ground with the pickup key; the HUD
## asks to move, use, equip, unequip or drop them. Gear adds to your stats
## while worn. The bag's last QUICK_SLOTS slots are the quick-use slots,
## used with keys 1-5 (design log 0043).
##
## Home and healing (logs 0033-0034, 0037): the home key teleports you to
## the Center, and the priest heals you in full whenever you're in the Center.
## Health also regenerates, faster out of combat, and potions heal at once.
##
## Saved progress (log 0038): progress() is what the owner's family save
## keeps of this heir; create() restores it, checked by sanitize_progress().

const RADIUS := 28.0
const COLLISION_PAD := 2.0

# Rolling
const SPIN_ACCEL := 5.0  # rad/s² you add while holding a roll key
## Extra push, as a multiple of gravity's pull at one radius. Above 1, any
## shape can tip over its corner from rest.
const TIP_ASSIST := .75
const BASE_SPIN := 5.0  # top spin (rad/s) you can push to right away
const TOP_SPIN := 12.0  # top spin after holding the key for RAMP_TIME
const RAMP_TIME := 1.5
const AIR_SPEED := 120.0  # top sideways speed you can steer to in the air
const AIR_ACCEL := 150.0

# Jumping
const JUMP_SPEED := 150.0
const FACE_BOUNCE := 1.3  # jump multiplier when bouncing off a face
const CORNER_BOUNCE := 1.55  # ... and off a corner
const FLIP_SPIN := 16.0  # rad/s spin a corner bounce gives you
const FLIP_PUSH := 160.0  # sideways speed a corner bounce adds
const BOUNCE_WINDOW := 0.18  # jump this soon after landing to bounce
const MIN_AIR_TIME := 0.12  # shorter hops don't count as a landing
const COYOTE_TIME := 0.1  # can still jump this long after leaving the ground
const JUMP_BUFFER := 0.15  # a jump pressed this long before landing still counts
## Landing counts as on a face if the two lowest corners are this level
## (sine of the tilt between the bottom edge and the ground).
const FACE_TILT := 0.14

const JUMP_COST := 25.0
const WEAK_JUMP := 0.55  # jump speed multiplier when you can't pay the cost

const FALL_LIMIT := 2000.0  # fall below this and you go back to the spawn point

const LAYER_TERRAIN := 1
const LAYER_PLAYERS := 2
const GROUP := "players"
const INVULNERABLE_TIME := 0.6  # s after being hit before you can be hit again
const BAG_SLOTS := 10  # the bag proper
const QUICK_SLOTS := 5  # quick-use slots (keys 1-5), the bag's last five
const BAG_SIZE := BAG_SLOTS + QUICK_SLOTS

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
var apex := 0:  # isosceles triangles only (design log 0031)
	set(value):
		apex = value
		_outline_dirty = true
var generation := 1  # which heir of the family this is
var spawn_point := Vector2.ZERO
var sync: MultiplayerSynchronizer

# Stats: set by the server, synced to clients.
var level := 1
var vigor := 0
var mettle := 0
var force := 0
var torque := 0
var rigidity := 0  # from armor only (design log 0021)
var luck := 0
var hp := Stats.BASE_HP
var max_hp := Stats.BASE_HP
var energy := Stats.MAX_ENERGY
var xp := 0  # toward the next level
# Items (design log 0036): set by the server, synced to clients. "" is empty.
var bag := _blank(BAG_SIZE)
var equipped := _blank(Gear.SLOTS.size())  # indexed like Gear.SLOTS

var _points: PackedVector2Array
var _corners: PackedVector2Array  # collision outline
var _corner_angles: PackedFloat32Array
var _collision: CollisionPolygon2D
var _outline_dirty := true
# Server-side combat state.
var _prev_linear := Vector2.ZERO
var _prev_angular := 0.0
var _hit_cooldowns: Dictionary = {}
var _invulnerable := 0.0
var _since_combat := INF  # s since you last hit or were hit
var _regen_carry := 0.0  # health regen builds up in fractions
var _teleport_to: Variant = null  # Vector2 to move to on the next physics step
var _dead := false
# Server-side state.
var _move := 0.0
var _jump_timer := 0.0
var _since_ground := INF
var _air_time := 0.0
var _landed_timer := 0.0
var _landed_on_corner := false
var _ground_normal := Vector2.UP
var _hold_time := 0.0
var _hold_dir := 0.0
# Owner-side: last move value sent, so we only send changes.
var _sent_move := 0.0


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
	p.luck = data.get("luck", 0)
	p.spawn_point = data.pos
	p.position = data.pos
	p._rebuild_outline()
	p._apply_progress(data.get("progress", {}))

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
	for prop: String in [".:position", ".:rotation", ".:energy"]:
		config.add_property(prop)
		config.property_set_spawn(prop, true)
		config.property_set_replication_mode(prop, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	for stat: String in ["level", "vigor", "mettle", "force", "torque", "rigidity", "luck", "hp", "max_hp",
			"xp", "bag", "equipped", "sides", "kind", "apex", "generation"]:
		var prop := ".:" + stat
		config.add_property(prop)
		config.property_set_spawn(prop, true)
		config.property_set_replication_mode(prop, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	p.sync.replication_config = config
	# Only peers whose world has loaded (registered players) get this shape.
	p.sync.add_visibility_filter(func(id: int) -> bool: return Net.players.has(id))
	p.add_child(p.sync)
	return p


## Outline and collision for the current sides and kind. Runs again when an
## heir takes over the shape.
func _rebuild_outline() -> void:
	_outline_dirty = false
	_points = ShapeGeometry.points(sides, kind, RADIUS, apex)
	# The collision outline is a little bigger than the drawing, so the solver's
	# small overlap on impact doesn't look like corners sinking into the ground.
	_corners = ShapeGeometry.points(sides, kind, RADIUS + COLLISION_PAD, apex)
	_corner_angles = ShapeGeometry.corner_angles(_corners)
	if _collision == null:
		_collision = CollisionPolygon2D.new()
		add_child(_collision)
	_collision.polygon = _corners


func _ready() -> void:
	add_to_group(GROUP)
	# Clients never simulate: the server's position and rotation are copied in.
	if not multiplayer.is_server():
		freeze = true
		freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC


func is_local() -> bool:
	return peer_id == multiplayer.get_unique_id()


func _physics_process(_delta: float) -> void:
	if not is_local():
		return
	if Controls.capturing:  # the controls screen is waiting for a key
		return
	var move := Input.get_axis("roll_left", "roll_right")
	if move != _sent_move:
		_sent_move = move
		_submit_move.rpc_id(1, move)
	if Input.is_action_just_pressed("jump"):
		_submit_jump.rpc_id(1)
	if Input.is_action_just_pressed("interact"):
		_submit_marry.rpc_id(1)
	if Input.is_action_just_pressed("pickup"):
		_submit_pickup.rpc_id(1)
	if Input.is_action_just_pressed("drink"):
		_submit_drink.rpc_id(1, -1)
	if Input.is_action_just_pressed("home"):
		_submit_home.rpc_id(1)
	for n in QUICK_SLOTS:
		if Input.is_action_just_pressed("quick_%d" % (n + 1)):
			request_use(BAG_SLOTS + n)
	# There's no XP yet, so debug builds can level up by hand to test scaling.
	if OS.is_debug_build() and Input.is_action_just_pressed("debug_level_up"):
		_submit_debug_level_up.rpc_id(1)


func _process(_delta: float) -> void:
	if _outline_dirty:
		_rebuild_outline()
	queue_redraw()  # keeps the name tag upright as the shape turns


## Owner -> server.
@rpc("any_peer", "call_local", "reliable")
func _submit_move(move: float) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() in [peer_id, 0]:
		_move = clampf(move, -1.0, 1.0)


## Owner -> server.
@rpc("any_peer", "call_local", "reliable")
func _submit_jump() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() in [peer_id, 0]:
		_jump_timer = JUMP_BUFFER


## Owner -> server: marry at the priest, using a certificate (design log 0030).
@rpc("any_peer", "call_local", "reliable")
func _submit_marry() -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() not in [peer_id, 0]:
		return
	var certificate := marriage_certificate()
	if _dead or certificate == "" or position.distance_to(Priest.POSITION) > Priest.REACH:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	take_from_bag(certificate)
	var heir := Family.roll_heir(sides, kind, apex, rng, certificate == Gear.BLESSED_CERTIFICATE)
	become_heir(heir)
	Net.heir_born_on_server(peer_id, heir)


## The certificate marrying would use, or "". A triangle short of
## equilateral uses a blessed one first (design log 0032); anyone else keeps
## it and uses an ordinary one, if they have one.
func marriage_certificate() -> String:
	var blessed := count_of(Gear.BLESSED_CERTIFICATE) > 0
	if blessed and sides == 3 and kind != "equilateral":
		return Gear.BLESSED_CERTIFICATE
	if count_of(Gear.CERTIFICATE) > 0:
		return Gear.CERTIFICATE
	return Gear.BLESSED_CERTIFICATE if blessed else ""


## Owner -> server: teleport to the Center, from anywhere, any time (log 0034).
@rpc("any_peer", "call_local", "reliable")
func _submit_home() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() in [peer_id, 0] and not _dead:
		_teleport_to = spawn_point


## Owner -> server: drink a potion (design log 0037), from a bag slot or,
## with -1, the first one in the bag. Not at full health.
@rpc("any_peer", "call_local", "reliable")
func _submit_drink(bag_index: int) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() not in [peer_id, 0] or _dead:
		return
	if bag_index == -1:
		bag_index = bag.find(Gear.POTION)
	if bag_index < 0 or bag_index >= BAG_SIZE or bag[bag_index] != Gear.POTION or hp >= max_hp:
		return
	var new_bag := bag
	new_bag[bag_index] = ""
	bag = new_bag
	hp = mini(hp + Stats.potion_heal(max_hp), max_hp)


## Server only. Health regen (design log 0037), slower in combat.
func _regenerate(step: float) -> void:
	_since_combat += step
	if _dead or hp >= max_hp:
		_regen_carry = 0.0
		return
	_regen_carry += Stats.hp_regen(max_hp, _since_combat < Stats.OUT_OF_COMBAT_TIME) * step
	var whole := floori(_regen_carry)
	if whole > 0:
		_regen_carry -= whole
		hp = mini(hp + whole, max_hp)


## Server only. In the Center the priest heals you in full, for free (log 0033).
func _priest_heal() -> void:
	if _dead or hp >= max_hp or not CenterTerrain.contains(position):
		return
	hp = max_hp
	_priest_blessed.rpc_id(peer_id, Priest.random_blessing())


## Server -> the healed player.
@rpc("authority", "call_local", "reliable")
func _priest_blessed(line: String) -> void:
	get_tree().call_group(Hud.GROUP, "show_message", "The Priest: “%s”" % line)


## Owner -> server. Debug builds only.
@rpc("any_peer", "call_local", "reliable")
func _submit_debug_level_up() -> void:
	if OS.is_debug_build() and multiplayer.is_server() and multiplayer.get_remote_sender_id() in [peer_id, 0]:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		level_up(rng)


## Server only.
func level_up(rng: RandomNumberGenerator) -> void:
	if level >= Stats.MAX_LEVEL:
		return
	level += 1
	var gains := Stats.roll_level_gains(rng)
	vigor += gains.vigor
	mettle += gains.mettle
	force += gains.force
	torque += gains.torque
	var new_max := Stats.max_hp(vigor)
	hp += new_max - max_hp  # the new health arrives full
	max_hp = new_max


## Server only. A hit from an enemy's corner; `push` points from it to you.
func take_hit(raw: float, push: Vector2) -> void:
	if _dead or _invulnerable > 0.0:
		return
	_invulnerable = INVULNERABLE_TIME
	_since_combat = 0.0
	var damage := roundi(Stats.damage_taken(raw, rigidity))
	hp = maxi(hp - damage, 0)
	get_tree().call_group(World.GROUP, "show_damage", position + Vector2(0, -24), damage, "player")
	apply_central_impulse(push * Combat.KNOCKBACK * mass)
	if hp == 0:
		_dead = true
		# Deferred: this runs inside a physics callback.
		Net.player_died.call_deferred(peer_id)


## Damage one of your corners deals (design §3). Dents deal none.
func corner_damage(corner: int) -> float:
	return maxf(Stats.corner_damage(_corner_angles[corner], force), 0.0)


## Server only. Levels up as many times as the XP covers (design log 0028).
func add_xp(amount: int) -> void:
	if level >= Stats.MAX_LEVEL:
		return  # renown comes later (DESIGN §4)
	xp += amount
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	while level < Stats.MAX_LEVEL and xp >= Stats.xp_to_next(level):
		xp -= Stats.xp_to_next(level)
		level_up(rng)
	if level >= Stats.MAX_LEVEL:
		xp = 0


# --- Items (design log 0036) ----------------------------------------------

static func _blank(size: int) -> PackedStringArray:
	var a := PackedStringArray()
	a.resize(size)
	return a


func count_of(item: String) -> int:
	return bag.count(item)


func worn(slot: String) -> String:
	return equipped[Gear.SLOTS.find(slot)]


## Owner side, for the HUD.
func request_equip(bag_index: int) -> void:
	_submit_equip.rpc_id(1, bag_index)


## Takes gear off into a chosen bag slot, or the first free one (-1).
func request_unequip(slot_index: int, bag_index := -1) -> void:
	_submit_unequip.rpc_id(1, slot_index, bag_index)


func request_drop(bag_index: int) -> void:
	_submit_drop.rpc_id(1, bag_index)


func request_drink(bag_index: int) -> void:
	_submit_drink.rpc_id(1, bag_index)


## Double-click or a quick-use key: drink a potion, wear gear.
func request_use(bag_index: int) -> void:
	if bag_index < 0 or bag_index >= BAG_SIZE:
		return
	if bag[bag_index] == Gear.POTION:
		request_drink(bag_index)
	elif Gear.is_gear(bag[bag_index]):
		request_equip(bag_index)


## Drag and drop between bag slots: move, or swap with what's there.
func request_swap(from: int, to: int) -> void:
	_submit_swap.rpc_id(1, from, to)


@rpc("any_peer", "call_local", "reliable")
func _submit_swap(from: int, to: int) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() not in [peer_id, 0] or _dead:
		return
	if from == to or from < 0 or to < 0 or from >= BAG_SIZE or to >= BAG_SIZE:
		return
	var moving := bag[from]
	var new_bag := bag
	new_bag[from] = bag[to]
	new_bag[to] = moving
	bag = new_bag


## Owner -> server: grab the nearest of your items on the ground.
@rpc("any_peer", "call_local", "reliable")
func _submit_pickup() -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() not in [peer_id, 0] or _dead:
		return
	var best: Pickup = null
	var best_d := Pickup.REACH
	for node in get_tree().get_nodes_in_group(Pickup.GROUP):
		var p := node as Pickup
		if p.owner_id != peer_id or p.is_queued_for_deletion():
			continue
		var d := p.position.distance_to(position)
		if d <= best_d:
			best_d = d
			best = p
	if best != null and add_to_bag(best.item):
		best.queue_free()


## Owner -> server: wear a bag item. What was in that slot goes back to its place.
@rpc("any_peer", "call_local", "reliable")
func _submit_equip(bag_index: int) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() not in [peer_id, 0] or _dead:
		return
	if bag_index < 0 or bag_index >= BAG_SIZE or not Gear.is_gear(bag[bag_index]):
		return
	var item := bag[bag_index]
	var slot_index := Gear.SLOTS.find(Gear.slot_of(item))
	var old := equipped[slot_index]
	_apply_gains(Gear.set_bonus(equipped), -1)
	_apply_bonuses(old, -1)
	_apply_bonuses(item, 1)
	var new_bag := bag
	new_bag[bag_index] = old
	var new_equipped := equipped
	new_equipped[slot_index] = item
	bag = new_bag
	equipped = new_equipped
	_apply_gains(Gear.set_bonus(equipped), 1)


## Owner -> server: take gear off, into a bag slot (-1: the first free one).
## Dropped on gear for the same slot, the two swap.
@rpc("any_peer", "call_local", "reliable")
func _submit_unequip(slot_index: int, bag_index: int) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() not in [peer_id, 0] or _dead:
		return
	if slot_index < 0 or slot_index >= equipped.size() or equipped[slot_index] == "":
		return
	if bag_index >= 0 and bag_index < BAG_SIZE and bag[bag_index] != "":
		if Gear.slot_of(bag[bag_index]) == Gear.SLOTS[slot_index]:
			_submit_equip(bag_index)
		return
	var item := equipped[slot_index]
	if bag_index >= 0 and bag_index < BAG_SIZE:
		var new_bag := bag
		new_bag[bag_index] = item
		bag = new_bag
	elif not add_to_bag(item):
		return
	_apply_gains(Gear.set_bonus(equipped), -1)  # a set can't survive losing a piece
	_apply_bonuses(item, -1)
	var new_equipped := equipped
	new_equipped[slot_index] = ""
	equipped = new_equipped


## Owner -> server: put a bag item on the ground. It stays yours until it
## vanishes (Pickup.LIFETIME), so a misclick can be undone.
@rpc("any_peer", "call_local", "reliable")
func _submit_drop(bag_index: int) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() not in [peer_id, 0] or _dead:
		return
	if bag_index < 0 or bag_index >= BAG_SIZE or bag[bag_index] == "":
		return
	var item := bag[bag_index]
	var new_bag := bag
	new_bag[bag_index] = ""
	bag = new_bag
	get_tree().call_group(World.GROUP, "drop_item", item, peer_id, position)


## Server only. Puts an item in the first empty slot, the bag proper before
## the quick-use slots; false if all are full.
## (Packed arrays are copied on assignment, which is what lets the sync see it.)
func add_to_bag(item: String) -> bool:
	var i := bag.find("")  # the bag proper comes first
	if i == -1:
		return false
	var new_bag := bag
	new_bag[i] = item
	bag = new_bag
	return true


## Server only. Removes one of an item from the bag; false if there was none.
func take_from_bag(item: String) -> bool:
	var i := bag.find(item)
	if i == -1:
		return false
	var new_bag := bag
	new_bag[i] = ""
	bag = new_bag
	return true


## Adds (direction 1) or removes (direction -1) a gear item's stats.
func _apply_bonuses(item: String, direction: int) -> void:
	_apply_gains(Gear.bonuses(item), direction)


## Adds (direction 1) or removes (direction -1) stat gains, e.g. {"force": 15}.
func _apply_gains(gains: Dictionary, direction: int) -> void:
	for stat: String in gains:
		set(stat, get(stat) + direction * gains[stat])
	if gains.has("vigor"):
		var new_max := Stats.max_hp(vigor)
		if new_max > max_hp:
			hp += new_max - max_hp  # like a level-up: the new health arrives full
		max_hp = new_max
		hp = mini(hp, max_hp)


## Server only. The heir takes over this shape, starting fresh at level 1 with
## no gear, back at the spawn point (design log 0030). The certificate used
## is already gone; spare certificates and potions are kept, gear is not.
func become_heir(heir: Dictionary) -> void:
	var kept := bag  # consumables stay where they were, e.g. potions on the hotbar
	for i in kept.size():
		if kept[i] not in Gear.CONSUMABLES:
			kept[i] = ""
	bag = kept
	equipped = _blank(Gear.SLOTS.size())
	sides = heir.sides
	kind = heir.kind
	apex = heir.apex
	luck = heir.luck
	generation += 1
	_rebuild_outline()
	level = 1
	xp = 0
	for stat: String in Stats.LEVELED:
		set(stat, 0)
	rigidity = 0
	max_hp = Stats.max_hp(vigor)
	hp = max_hp
	energy = Stats.MAX_ENERGY
	_teleport_to = spawn_point


# --- Saved progress (design log 0038) -------------------------------------

## What the family save keeps of this heir. Stats are stored without gear,
## which adds its bonuses back when the progress is restored.
func progress() -> Dictionary:
	var base := {}
	for stat: String in Stats.LEVELED:
		base[stat] = get(stat)
	var worn_gains: Array[Dictionary] = [Gear.set_bonus(equipped)]
	for item in equipped:
		worn_gains.append(Gear.bonuses(item))
	for gains in worn_gains:
		for stat: String in gains:
			if base.has(stat):
				base[stat] -= gains[stat]
	return {
		"level": level,
		"xp": xp,
		"stats": base,
		"bag": Array(bag),
		"equipped": Array(equipped),
	}


## Puts saved progress (already checked) on a fresh shape.
func _apply_progress(saved: Dictionary) -> void:
	if saved.is_empty():
		return
	level = saved.level
	xp = saved.xp
	for stat: String in Stats.LEVELED:
		set(stat, saved.stats[stat])
	bag = PackedStringArray(saved.bag)
	equipped = PackedStringArray(saved.equipped)
	max_hp = Stats.max_hp(vigor)
	for item in equipped:
		_apply_bonuses(item, 1)
	_apply_gains(Gear.set_bonus(equipped), 1)
	hp = max_hp


## Server only. A save comes from the player's own machine, so keep every
## value in what play could produce. Returns {} for a fresh heir.
static func sanitize_progress(raw: Dictionary) -> Dictionary:
	if raw.is_empty():
		return {}
	var clean_level := clampi(_as_int(raw.get("level"), 1), 1, Stats.MAX_LEVEL)
	var top_xp := 0 if clean_level >= Stats.MAX_LEVEL else Stats.xp_to_next(clean_level) - 1
	var raw_stats: Variant = raw.get("stats", {})
	var stats := {}
	for stat: String in Stats.LEVELED:
		var value: Variant = raw_stats.get(stat) if raw_stats is Dictionary else null
		stats[stat] = clampi(_as_int(value, 0), 0, Stats.GAIN_MAX * (clean_level - 1))
	var clean_bag := _clean_items(raw.get("bag", []), BAG_SIZE)
	var raw_equipped := _clean_items(raw.get("equipped", []), Gear.SLOTS.size())
	var clean_equipped := _blank(Gear.SLOTS.size())
	for i in raw_equipped.size():
		if Gear.slot_of(raw_equipped[i]) == Gear.SLOTS[i]:
			clean_equipped[i] = raw_equipped[i]
	return {
		"level": clean_level,
		"xp": clampi(_as_int(raw.get("xp"), 0), 0, top_xp),
		"stats": stats,
		"bag": clean_bag,
		"equipped": clean_equipped,
	}


static func _as_int(value: Variant, fallback: int) -> int:
	return int(value) if value is int or value is float else fallback  # JSON numbers are floats


static func _clean_items(raw: Variant, size: int) -> PackedStringArray:
	var out := _blank(size)
	if raw is Array:
		for i in mini(raw.size(), size):
			var it: Variant = raw[i]
			if it is String and Gear.is_item(it):
				out[i] = it
	return out


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not multiplayer.is_server():
		return
	energy = minf(energy + Stats.energy_regen(mettle) * state.step, Stats.MAX_ENERGY)
	_invulnerable -= state.step
	_regenerate(state.step)
	_priest_heal()
	if _teleport_to == null and state.transform.origin.y > FALL_LIMIT:
		_teleport_to = spawn_point
	if _teleport_to != null:
		state.transform = Transform2D(0.0, _teleport_to)
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0
		_teleport_to = null
		return

	# The ground contact farthest in the rolling direction is the corner we
	# tip over next.
	var step := state.step
	var normal := Vector2.ZERO
	for i in state.get_contact_count():
		var n := state.get_contact_local_normal(i)
		if n.y < -0.5:
			normal += n
	var touching_ground := normal != Vector2.ZERO
	if touching_ground:
		_ground_normal = normal.normalized()
		if _air_time > MIN_AIR_TIME:
			_landed_timer = BOUNCE_WINDOW
			_landed_on_corner = _resting_on_corner(state.transform)
		_air_time = 0.0
		_since_ground = 0.0
	else:
		_air_time += step
		_since_ground += step
	_landed_timer -= step
	var grounded := _since_ground <= COYOTE_TIME

	# Holding the same direction raises your top spin.
	if _move != 0.0 and _move == _hold_dir:
		_hold_time += step
	else:
		_hold_dir = _move
		_hold_time = 0.0

	var spin_scale := Stats.spin_scale(torque)
	if grounded and _move != 0.0:
		var top := spin_scale * lerpf(BASE_SPIN, TOP_SPIN, clampf(_hold_time / RAMP_TIME, 0.0, 1.0))
		# Push only up to the top spin. Gravity can take you past it downhill.
		if state.angular_velocity * _move < top:
			var tip := TIP_ASSIST * state.total_gravity.length() * RADIUS * state.inverse_inertia / state.inverse_mass
			state.angular_velocity += _move * (SPIN_ACCEL * spin_scale + tip) * step
	elif not grounded and _move != 0.0:
		# Mid-air you can drift sideways but not turn (DESIGN §9 question 5 is open).
		var vx := state.linear_velocity.x
		if absf(vx) < AIR_SPEED or signf(vx) != signf(_move):
			state.linear_velocity.x = move_toward(vx, _move * AIR_SPEED, AIR_ACCEL * step)

	if _jump_timer > 0.0:
		_jump_timer -= step
		if grounded:
			_jump(state)

	if not _dead:
		for hit in Combat.find_hits(state, _corners, _prev_linear, _prev_angular,
				func(o: Object) -> bool: return o is Enemy, _hit_cooldowns):
			var enemy: Enemy = hit.target
			enemy.apply_central_impulse(hit.push * Combat.KNOCKBACK * enemy.mass)
			var crit := randf() < Stats.lucky_chance(Stats.CRIT_CHANCE, luck)
			var damage := corner_damage(hit.corner) * (Stats.CRIT_MULT if crit else 1.0)
			enemy.take_hit(damage, peer_id, crit)
			_since_combat = 0.0
	_prev_linear = state.linear_velocity
	_prev_angular = state.angular_velocity


func _jump(state: PhysicsDirectBodyState2D) -> void:
	var bounce := _landed_timer > 0.0
	var power := 1.0
	if bounce:
		power = CORNER_BOUNCE if _landed_on_corner else FACE_BOUNCE
	if energy >= JUMP_COST:
		energy -= JUMP_COST
	else:
		power *= WEAK_JUMP
	# Jump away from the ground, leaning with the slope.
	var dir := (Vector2.UP + _ground_normal).normalized()
	var v := state.linear_velocity
	v += dir * (JUMP_SPEED * power - v.dot(dir))
	if bounce and _landed_on_corner:
		var flip_dir := signf(_move)
		if flip_dir == 0.0:
			flip_dir = signf(v.x) if absf(v.x) > 20.0 else signf(state.angular_velocity)
		if flip_dir == 0.0:
			flip_dir = 1.0
		state.angular_velocity = flip_dir * maxf(FLIP_SPIN, absf(state.angular_velocity))
		v.x += flip_dir * FLIP_PUSH
	state.linear_velocity = v
	_jump_timer = 0.0
	_landed_timer = 0.0
	_since_ground = INF


## True if a corner, not a flat face, is what's touching the ground.
func _resting_on_corner(xform: Transform2D) -> bool:
	var lowest := Vector2.ZERO
	var second := Vector2.ZERO
	var low_h := INF
	var second_h := INF
	for p in _points:
		var w := xform * p
		var h := w.dot(_ground_normal)  # higher points have bigger h
		if h < low_h:
			second = lowest
			second_h = low_h
			lowest = w
			low_h = h
		elif h < second_h:
			second = w
			second_h = h
	return (second_h - low_h) / maxf(lowest.distance_to(second), 0.001) > FACE_TILT


func _draw() -> void:
	Gear.draw_shape(self, _points, sides, equipped)

	draw_set_transform(Vector2.ZERO, -rotation)
	var font := ThemeDB.fallback_font
	var tag := family_name + (" (you)" if is_local() else "")
	draw_string(font, Vector2(-150, -RADIUS - 12), tag, HORIZONTAL_ALIGNMENT_CENTER, 300, 15, Palette.INK_FADED)
	# Under the name: other players' health; your energy (your health is in the HUD).
	if is_local():
		_draw_energy_pips()
	else:
		var bar := Rect2(-24, -RADIUS - 9, 48, 5)
		draw_rect(bar, Palette.PARCHMENT)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * hp / maxf(max_hp, 1), bar.size.y)), Palette.HEALTH)
		draw_rect(bar, Palette.INK, false, 1.0)


## One pip per full jump's worth of energy (design log 0026). Faded when full,
## so it only draws the eye while you're spending it.
func _draw_energy_pips() -> void:
	var count := ceili(Stats.MAX_ENERGY / JUMP_COST)
	var pip := Vector2(12, 6)
	var gap := 3.0
	var left := -(count * pip.x + (count - 1) * gap) / 2.0
	var alpha := 0.35 if energy >= Stats.MAX_ENERGY else 1.0
	for i in count:
		var box := Rect2(left + i * (pip.x + gap), -RADIUS - 10, pip.x, pip.y)
		var share := clampf((energy - i * JUMP_COST) / JUMP_COST, 0.0, 1.0)
		draw_rect(box, Color(Palette.PARCHMENT, alpha))
		draw_rect(Rect2(box.position, Vector2(box.size.x * share, box.size.y)), Color(Palette.ENERGY, alpha))
		draw_rect(box, Color(Palette.INK, alpha), false, 1.0)

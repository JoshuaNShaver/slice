class_name SpikeUpAbility
extends Ability
## Spike up (design logs 0086, 0089): your sharpest corner flips up with a
## face flat on the ground, held for HOLD, and nearby enemies are thrown up
## to fall onto it. Any other move or a jump lets go. *Proposed* numbers.

const RANGE := 260.0  # px: enemies this close are thrown
const HEIGHT := 140.0  # ... and no more than this far above or below
const LAUNCH := 420.0  # px/s straight up
const HOLD := 1.0  # s you hold the spike unless you roll or jump
const STEER := 25.0  # turn rate (rad/s) per radian off target
const MAX_SPIN := 30.0

var _time := 0.0  # s left holding it
var _rotation := 0.0


func _init() -> void:
	id = "spike_up"
	name = "Spike up"
	action = "spike_up"
	price = 5000  # chits (design log 0206)
	text = "Plant a face on the ground, sharpest corner up. Nearby enemies are thrown up onto it."


## Throws hostile enemies, but not bosses: too heavy (design log 0089).
func use_by_player(player: PlayerShape, state: PhysicsDirectBodyState2D) -> void:
	if not player.multiplayer.is_server():  # playing on through a gap: only the server throws
		start(player, state, player.corners, player.corner_angles, PlayerShape.RADIUS, [])
		return
	var foes: Array = player.get_tree().get_nodes_in_group(Enemy.GROUP).filter(func(e: Node) -> bool:
		var enemy := e as Enemy
		return enemy != null and enemy.players_can_hit(player.peer_id) and not enemy.freeze and enemy.hp > 0 \
				and not enemy.is_boss())
	start(player, state, player.corners, player.corner_angles, PlayerShape.RADIUS, foes)


## Plants a face, sharpest corner up, and throws every one of `targets`
## within reach (RANGE past the body's own size) up to land on it.
## Targets need launch(velocity, onto).
func start(body: Node2D, state: PhysicsDirectBodyState2D, corners: PackedVector2Array,
		angles: PackedFloat32Array, radius: float, targets: Array) -> void:
	_rotation = rotation_for(corners, angles, state.transform.get_rotation())
	_time = HOLD
	_began()
	var reach := RANGE + radius - 28.0
	var flight := 2.0 * LAUNCH / maxf(state.total_gravity.y, 1.0)
	for node: Variant in targets:
		var t := node as Node2D
		if t == null or t == body:
			continue
		var d := t.global_position - body.global_position
		if absf(d.x) <= reach and absf(d.y) <= HEIGHT + radius - 28.0:
			t.call("launch", Vector2(-d.x / flight, -LAUNCH), body)


## Holds the pose, pressed flat to the ground.
func step(state: PhysicsDirectBodyState2D, _corners: PackedVector2Array, _angles: PackedFloat32Array,
		_touching_ground: bool) -> void:
	if _time <= 0.0:
		return
	_time -= state.step
	var off := wrapf(_rotation - state.transform.get_rotation(), -PI, PI)
	state.angular_velocity = clampf(off * STEER, -MAX_SPIN, MAX_SPIN)
	var v := state.linear_velocity
	v.x = move_toward(v.x, 0.0, 2000.0 * state.step)
	v.y = maxf(v.y, 0.0)
	state.linear_velocity = v


func active() -> bool:
	return _time > 0.0


func cancel() -> void:
	_time = 0.0


func on_other_start(_other: Ability) -> void:
	_time = 0.0


func on_jump() -> void:
	_time = 0.0


## The rotation that puts a face flat on the ground with the sharpest
## corner as high as it goes. Among equals, the nearest to `now`.
static func rotation_for(corners: PackedVector2Array, angles: PackedFloat32Array, now: float) -> float:
	var tip := Abilities.sharpest_corner(corners, angles, Transform2D(now, Vector2.ZERO), Vector2.UP)
	var area := 0.0
	for i in corners.size():
		area += corners[i].cross(corners[(i + 1) % corners.size()])
	var best := now
	var best_height := -INF
	var best_turn := INF
	for i in corners.size():
		var edge := corners[(i + 1) % corners.size()] - corners[i]
		# The face's outward normal, whichever way the outline winds.
		var out := Vector2(edge.y, -edge.x) if area > 0.0 else Vector2(-edge.y, edge.x)
		var rot := Vector2.DOWN.angle() - out.angle()  # turns that face to the floor
		var height := -Vector2(corners[tip] - corners[i]).rotated(rot).y
		var turn := absf(wrapf(rot - now, -PI, PI))
		if height > best_height + 0.5 or (absf(height - best_height) <= 0.5 and turn < best_turn):
			best = rot
			best_height = height
			best_turn = turn
	return best

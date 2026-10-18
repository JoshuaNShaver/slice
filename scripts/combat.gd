class_name Combat
## Corner strikes (DESIGN §3, design log 0027). Only corners deal damage: when
## one of your corners touches an enemy fast enough, that's a hit. Faces do
## nothing. Players and enemies use the same rule.
##
## A body checks only its own corners. When a corner meets a face, only the
## corner's owner finds a hit; when two corners meet, both do.

const MIN_HIT_SPEED := 70.0  # closing speed (px/s) a corner needs to count
const CORNER_REACH := 7.0  # px from a corner that a contact still counts as that corner
const HIT_COOLDOWN := 0.3  # s before the same body can hit the same target again
const KNOCKBACK := 140.0  # px/s added to the target, away from the corner


## Corner hits in this physics step, as [{"target": Object, "corner": int}].
## `corners` is the body's collision outline in local space. `prev_linear` and
## `prev_angular` are last step's velocities: by now the solver has already
## bounced this step's, so the impact speed has to come from before it.
## `cooldowns` maps target instance id -> time left, and is updated here.
static func find_hits(state: PhysicsDirectBodyState2D, corners: PackedVector2Array,
		prev_linear: Vector2, prev_angular: float, is_target: Callable,
		cooldowns: Dictionary) -> Array[Dictionary]:
	for id: int in cooldowns.keys():
		cooldowns[id] -= state.step
		if cooldowns[id] <= 0.0:
			cooldowns.erase(id)

	var hits: Array[Dictionary] = []
	var origin := state.transform.origin
	for i in state.get_contact_count():
		var target := state.get_contact_collider_object(i)
		if target == null or not is_target.call(target):
			continue
		var id := target.get_instance_id()
		if cooldowns.has(id):
			continue
		var contact := state.get_contact_local_position(i)  # global coordinates
		var corner := _nearest_corner(state.transform, corners, contact)
		if corner < 0:
			continue
		var r := state.transform * corners[corner] - origin
		var corner_velocity := prev_linear + Vector2(-prev_angular * r.y, prev_angular * r.x)
		var relative := corner_velocity - state.get_contact_collider_velocity_at_position(i)
		# The contact normal points from the target toward us.
		var closing := -relative.dot(state.get_contact_local_normal(i))
		if closing < MIN_HIT_SPEED:
			continue
		cooldowns[id] = HIT_COOLDOWN
		hits.append({"target": target, "corner": corner, "push": (contact - origin).normalized()})
	return hits


static func _nearest_corner(xform: Transform2D, corners: PackedVector2Array, point: Vector2) -> int:
	var best := -1
	var best_d := CORNER_REACH
	for i in corners.size():
		var d := (xform * corners[i]).distance_to(point)
		if d < best_d:
			best_d = d
			best = i
	return best

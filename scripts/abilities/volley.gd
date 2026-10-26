class_name VolleyAbility
extends Ability
## Volley (design log 0244): hold, then let go to lob SHOT_MULT times your
## throwing tips' shot count in a fan of arcs. Held longer, they fly
## farther. Past the top of the arc they seek the nearest enemy. Needs tips.
## *Proposed* numbers.

const SHOT_MULT := 3
const MAX_HOLD := 1.0  # s: held this long, it lets go by itself at full power
const MIN_SPEED := 380.0  # px/s, a tap
const MAX_SPEED := 860.0  # px/s, held fully
const LAUNCH := 58.0  # degrees above level
const FAN := 26.0  # degrees the shots spread over
const GRAVITY := 900.0  # px/s²
const SEEK_AFTER := 0.4  # s up the arc before the shots seek
const SEEK_TURN := 6.0  # rad/s
const LIFE := 2.2  # s


func _init() -> void:
	id = "volley"
	name = "Volley"
	slot = Abilities.UP
	short = "Volley"
	shop = "ranger"
	currency = "coins"
	price = 600  # *proposed*
	text = "Hold, then let go: three times your tips' shots in arcs, farther the longer you hold. They seek the nearest enemy."


func works_in_air() -> bool:
	return true


func usable_by(player: PlayerShape) -> bool:
	return not Gear.shots_of(player.inventory.worn("points")).is_empty()


func holds() -> bool:
	return true


func max_hold() -> float:
	return MAX_HOLD


func release_by_player(player: PlayerShape, _state: PhysicsDirectBodyState2D, held: float) -> void:
	var projectiles := Projectiles.find(player.get_tree())
	var tips := Gear.shots_of(player.inventory.worn("points"))
	if projectiles == null or tips.is_empty():
		return
	var count := int(tips.count) * SHOT_MULT
	var speed := lerpf(MIN_SPEED, MAX_SPEED, clampf(held / MAX_HOLD, 0.0, 1.0))
	for i in count:
		var shot := projectiles.player_shot(player)  # each its own crit roll
		var facing := signf((shot.dir as Vector2).x)
		if facing == 0.0:
			facing = 1.0
		var t := 0.0 if count <= 1 else float(i) / (count - 1) - 0.5
		var up := deg_to_rad(LAUNCH + FAN * t)
		shot.dir = Vector2(cos(up) * facing, -sin(up))
		shot.speed = speed
		shot.gravity = GRAVITY
		shot.seek_after = SEEK_AFTER
		shot.turn = SEEK_TURN
		shot.life = LIFE
		projectiles.throw(shot)
	_began()

class_name ChargedShotAbility
extends Ability
## Charged shot (design log 0244): hold to charge, let go to throw one fast,
## straight shot at the nearest enemy. It doesn't seek once thrown, so a
## moving target can dodge it. Charging raises its damage up to MAX_MULT at
## FULL; let go inside the critical window (your shape flashes) and it
## crits. Needs tips. *Proposed* numbers.

const FULL := 1.2  # s to full charge
const MAX_MULT := 2.0  # damage at full charge, times a shot's
const CRIT_FROM := 1.2  # s: the critical window opens...
const CRIT_UNTIL := 1.5  # ... and closes
const MAX_HOLD := 4.0  # s: held this long, it lets go by itself
const SPEED := 950.0  # px/s
const LIFE := 1.6  # s
const SIZE := 8.0  # px, bigger than a plain shot


func _init() -> void:
	id = "charged_shot"
	name = "Charged shot"
	slot = Abilities.DOWN
	short = "Charge"
	shop = "ranger"
	currency = "coins"
	price = 900  # *proposed*
	text = "Hold to charge, let go to throw one straight, hard shot at the nearest enemy. Let go as you flash and it crits."


func works_in_air() -> bool:
	return true


func usable_by(player: PlayerShape) -> bool:
	return not Gear.shots_of(player.inventory.worn("points")).is_empty()


func holds() -> bool:
	return true


func max_hold() -> float:
	return MAX_HOLD


func crit_window() -> Vector2:
	return Vector2(CRIT_FROM, CRIT_UNTIL)


func release_by_player(player: PlayerShape, _state: PhysicsDirectBodyState2D, held: float) -> void:
	var projectiles := Projectiles.find(player.get_tree())
	if projectiles == null or not usable_by(player):
		return
	var shot := projectiles.player_shot(player)
	var crit: bool = shot.crit or (held >= CRIT_FROM and held <= CRIT_UNTIL)
	var charge := lerpf(1.0, MAX_MULT, clampf(held / FULL, 0.0, 1.0))
	shot.damage = Projectiles.shot_damage(player) * charge * (Stats.CRIT_MULT if crit else 1.0)
	shot.crit = crit
	shot.target = null  # straight: aimed where the enemy is now
	shot.speed = SPEED
	shot.life = LIFE
	shot.size = SIZE
	projectiles.throw(shot)
	_began()

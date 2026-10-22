class_name PlayerCombat
extends Node
## A player's hits and health (PlayerShape's "Combat"). Server only.
##
## Combat (design log 0027): your corners hurt enemies they strike, and
## theirs hurt you (Combat). Health at 0 is death, and with no heir it ends
## the family (log 0015). Health regenerates, faster out of combat (log
## 0037); provisions heal over time (log 0084); healers (Npc) heal you in
## full inside their areas, if they serve your kind (logs 0033, 0052).

const INVULNERABLE_TIME := 0.6  # s after being hit before you can be hit again

var player: PlayerShape
var _prev_linear := Vector2.ZERO
var _prev_angular := 0.0
var _hit_cooldowns: Dictionary = {}
var _invulnerable := 0.0
var _since_combat := INF  # s since you last hit or were hit
var _regen_carry := 0.0  # health regen builds up in fractions
var _meal_left := 0.0  # health a provision still has to give (design log 0084)
var _meal_rate := 0.0  # health per second while it lasts
var _safe_until := 0  # ms (Time.get_ticks_msec); unhurt while watching a cutscene


## Every physics step, before movement.
func tick(step: float) -> void:
	_invulnerable -= step
	_regenerate(step)
	_area_heal()


## A hit from an enemy's corner; `push` points from it to you. False if it
## didn't land (just hit, dead, or watching a cutscene).
## A sparring partner's hits aren't `lethal`: they stop at 1 health (log 0072).
## `leave_at` >= 0: the hit leaves you at that much health instead, if you
## had more (Darren's opening hit, log 0181).
func take_hit(raw: float, push: Vector2, lethal := true, leave_at := -1) -> bool:
	if player.dead or _invulnerable > 0.0 or Time.get_ticks_msec() < _safe_until:
		return false
	var stats := player.stats
	_invulnerable = INVULNERABLE_TIME
	_since_combat = 0.0
	var damage := roundi(Stats.damage_taken(raw, stats.rigidity))
	if leave_at >= 0 and stats.hp > leave_at:
		damage = stats.hp - leave_at
	stats.hp = maxi(stats.hp - damage, 0 if lethal else 1)
	player.get_tree().call_group(World.GROUP, "show_damage", player.position + Vector2(0, -24), damage, "player")
	player.apply_central_impulse(push * Combat.KNOCKBACK * player.mass)
	if stats.hp == 0:
		player.dead = true
		# Deferred: this runs inside a physics callback.
		Net.player_died.call_deferred(player.peer_id)
	return true


## Server only. Can't be hurt for `seconds` (0 ends it): a cutscene is
## playing on the owner's screen (Net.play_cutscene).
func keep_safe(seconds: float) -> void:
	_safe_until = Time.get_ticks_msec() + int(seconds * 1000.0) if seconds > 0.0 else 0


## Damage one of your corners deals (design §3). Dents deal none.
func corner_damage(corner: int) -> float:
	return maxf(Stats.corner_damage(player.corner_angles[corner], player.stats.force), 0.0)


## Your corners' hits on enemies and the Logging Isle's trees (Timber, log
## 0202) this step (Combat), then remember this step's velocities for the next.
func hit_check(state: PhysicsDirectBodyState2D) -> void:
	if not player.dead:
		for hit in Combat.find_hits(state, player.corners, _prev_linear, _prev_angular, _can_hit, _hit_cooldowns):
			var crit := randf() < Stats.lucky_chance(Stats.CRIT_CHANCE, player.stats.luck)
			var damage := corner_damage(hit.corner) * (Stats.CRIT_MULT if crit else 1.0)
			if hit.target is Timber:
				(hit.target as Timber).take_hit(damage, player.peer_id, crit)
				continue
			var enemy: Enemy = hit.target
			enemy.apply_central_impulse(hit.push * Combat.KNOCKBACK * enemy.mass)
			enemy.take_hit(damage, player.peer_id, crit)
			_since_combat = 0.0
	_prev_linear = state.linear_velocity
	_prev_angular = state.angular_velocity


func _can_hit(o: Object) -> bool:
	if o is Timber:
		return true
	return o is Enemy and (o as Enemy).players_can_hit(player.peer_id)


## Fills your health (healers, design log 0033).
func heal_full() -> void:
	if not player.dead:
		player.stats.hp = player.stats.max_hp


## Heals at once, up to full (a potion, design log 0037).
func heal(amount: int) -> void:
	player.stats.hp = mini(player.stats.hp + amount, player.stats.max_hp)


## A provision (design log 0084): heals `share` of max health over
## Stats.MEAL_TIME; eating more adds to what's left.
func eat(share: float) -> void:
	_meal_left += player.stats.max_hp * share
	_meal_rate = _meal_left / Stats.MEAL_TIME


## Health regen (design log 0037), slower in combat.
func _regenerate(step: float) -> void:
	var stats := player.stats
	_since_combat += step
	if player.dead or stats.hp >= stats.max_hp:
		_regen_carry = 0.0
		_meal_left = 0.0  # a meal stops once you're full, or dead
		return
	_regen_carry += Stats.hp_regen(stats.max_hp, _since_combat < Stats.OUT_OF_COMBAT_TIME) * step
	if _meal_left > 0.0:
		var bite := minf(_meal_rate * step, _meal_left)
		_meal_left -= bite
		_regen_carry += bite
	var whole := floori(_regen_carry)
	if whole > 0:
		_regen_carry -= whole
		stats.hp = mini(stats.hp + whole, stats.max_hp)


## A healer whose area you're in heals you in full, for free, if they serve
## your kind (design logs 0033, 0052).
func _area_heal() -> void:
	var stats := player.stats
	if player.dead or stats.hp >= stats.max_hp:
		return
	for node in get_tree().get_nodes_in_group(Npc.HEALERS):
		var healer := node as Npc
		if healer.heal_area.has_point(player.position) and healer.serves_player(player):
			stats.hp = stats.max_hp
			if not healer.heal_lines.is_empty():
				player.screen.tell(healer.display_name, healer.heal_lines.pick_random())
			return

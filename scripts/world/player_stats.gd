class_name PlayerStats
extends Node
## A player's numbers (PlayerShape's "Stats", design logs 0021-0022). The
## server owns them and they sync to every client for the bars.
##
## Jumps are free (log 0087); energy pays for abilities (log 0086). Kills
## give XP (log 0028). `chits` are army pay (log 0204), earned on missions
## and by work and spent at the Quartermaster; `coins` are trade money, the
## merchants' (log 0205). `abilities` are the ones you've learned.

const MAX_CHITS := 1000000

var player: PlayerShape
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
var chits := 0  # army pay (design log 0204)
var coins := 0  # trade money (design logs 0204, 0205)
var dock_held := 0  # a merchant's logs waiting at the dock (Market, log 0205)
var abilities := PackedStringArray()  # learned ability ids (design log 0086)


## Server only, every physics step.
func regen_energy(step: float) -> void:
	energy = minf(energy + Stats.energy_regen(mettle) * step, Stats.MAX_ENERGY)


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


## Server only. Jumps to `target` level (admin command, log 0125). Going
## up rolls each level's gains, like leveling; going down re-rolls from
## level 1, so stats always match the level. Gear's bonuses stay.
func set_level(target: int, rng: RandomNumberGenerator) -> void:
	target = clampi(target, 1, Stats.MAX_LEVEL)
	if target < level:
		var gear := Gear.total_bonus(player.inventory.equipped)
		apply_gains(gear, -1)
		level = 1
		for stat: String in Stats.LEVELED:
			set(stat, 0)
		apply_gains(gear, 1)
		max_hp = Stats.max_hp(vigor)
		hp = clampi(hp, 1, max_hp)
	while level < target:
		level_up(rng)
	xp = 0


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


## Server only. Wages for a mission or work (design log 0204).
func add_chits(amount: int) -> void:
	chits = clampi(chits + amount, 0, MAX_CHITS)


## Server only. Trade money (design log 0205).
func add_coins(amount: int) -> void:
	coins = clampi(coins + amount, 0, MAX_CHITS)


## Adds (direction 1) or removes (direction -1) a gear item's stats.
func apply_bonuses(item: String, direction: int) -> void:
	apply_gains(Gear.bonuses(item), direction)


## Adds (direction 1) or removes (direction -1) stat gains, e.g. {"force": 15}.
func apply_gains(gains: Dictionary, direction: int) -> void:
	for stat: String in gains:
		set(stat, get(stat) + direction * gains[stat])
	if gains.has("vigor"):
		var new_max := Stats.max_hp(vigor)
		if new_max > max_hp:
			hp += new_max - max_hp  # like a level-up: the new health arrives full
		max_hp = new_max
		hp = mini(hp, max_hp)


## Server only. A new heir starts at level 1 (design log 0030); luck and
## money are set apart.
func reset_for_heir() -> void:
	level = 1
	xp = 0
	for stat: String in Stats.LEVELED:
		set(stat, 0)
	rigidity = 0
	max_hp = Stats.max_hp(vigor)
	hp = max_hp
	energy = Stats.MAX_ENERGY

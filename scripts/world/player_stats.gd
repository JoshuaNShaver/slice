class_name PlayerStats
extends Node
## A player's numbers (PlayerShape's "Stats", design logs 0021-0022). The
## server owns them and they sync to every client for the bars.
##
## Jumps are free (log 0087); energy pays for abilities (log 0086). Kills
## give XP (log 0028). `pay` is combatant pay (log 0071), earned on missions
## and spent at the Quartermaster. `abilities` are the ones you've learned.

const MAX_PAY := 1000000

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
var pay := 0  # combatant pay (design log 0071)
var abilities := PackedStringArray()  # learned ability ids (design log 0086)


## Server only, every physics step.
func regen_energy(step: float) -> void:
	energy = minf(energy + Stats.energy_regen(mettle) * step, Stats.MAX_ENERGY)


## Owner -> server. Debug builds only.
@rpc("any_peer", "call_local", "reliable")
func _submit_debug_level_up() -> void:
	if OS.is_debug_build() and player.from_owner():
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


## Server only. Wages for a mission (design log 0071).
func add_pay(amount: int) -> void:
	pay = clampi(pay + amount, 0, MAX_PAY)


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
## pay are set apart.
func reset_for_heir() -> void:
	level = 1
	xp = 0
	for stat: String in Stats.LEVELED:
		set(stat, 0)
	rigidity = 0
	max_hp = Stats.max_hp(vigor)
	hp = max_hp
	energy = Stats.MAX_ENERGY

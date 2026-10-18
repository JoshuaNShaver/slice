class_name Stats
## Stat formulas (design logs 0021-0023). Scaling is Realm of the Mad God
## style: every stat but rigidity and luck grows a random 1-2 points per level,
## and each grows about 3x from level 1 to 20.
##
## Stats start at 0 at level 1, so the base values below are a fresh shape.

const MAX_LEVEL := 20
const MAX_LUCK := 100

# Vigor -> health
const BASE_HP := 200
const HP_PER_VIGOR := 10

# Mettle -> energy regen. The pool itself never grows.
const MAX_ENERGY := 100.0
const BASE_REGEN := 5.0  # energy/s
const REGEN_PER_METTLE := 0.35

# Force -> damage
const BASE_DAMAGE_SCALE := 0.5  # a level 1 triangle corner does 60
const DAMAGE_PER_FORCE := 0.07

# Torque -> spin (top roll speed and how fast you build it)
const SPIN_PER_TORQUE := 0.07

# Rigidity (armor only) -> flat damage reduction
const MIN_DAMAGE_TAKEN := 0.15  # a hit always does at least 15%

# Luck -> chance rolls
const LUCK_FOR_DOUBLE := 50.0  # 50 luck doubles every chance
const BIRTH_LUCK_MAX := 10  # regular shapes are born with 0-10
const IRREGULAR_LUCK_MULT := 2

## Stats that grow when you level up.
const LEVELED: Array[String] = ["vigor", "mettle", "force", "torque"]
const GAIN_MIN := 1
const GAIN_MAX := 2


static func max_hp(vigor: int) -> int:
	return BASE_HP + HP_PER_VIGOR * vigor


static func energy_regen(mettle: int) -> float:
	return BASE_REGEN + REGEN_PER_METTLE * mettle


## Damage from one corner hit. Corner angle in degrees.
static func corner_damage(corner_deg: float, force: int) -> float:
	return (180.0 - corner_deg) * BASE_DAMAGE_SCALE * (1.0 + DAMAGE_PER_FORCE * force)


## Multiplier on top spin and spin build-up.
static func spin_scale(torque: int) -> float:
	return 1.0 + SPIN_PER_TORQUE * torque


static func damage_taken(raw: float, rigidity: int) -> float:
	return maxf(raw - rigidity, raw * MIN_DAMAGE_TAKEN)


## A good-outcome chance (a drop, a certificate) after luck. Capped at 100%.
static func lucky_chance(chance: float, luck: int) -> float:
	return minf(chance * (1.0 + luck / LUCK_FOR_DOUBLE), 1.0)


static func roll_birth_luck(kind: String, rng: RandomNumberGenerator) -> int:
	var luck := rng.randi_range(0, BIRTH_LUCK_MAX)
	return luck * IRREGULAR_LUCK_MULT if kind == "irregular" else luck


## Points gained on one level-up: {"vigor": 2, "mettle": 1, ...}
static func roll_level_gains(rng: RandomNumberGenerator) -> Dictionary:
	var gains := {}
	for stat in LEVELED:
		gains[stat] = rng.randi_range(GAIN_MIN, GAIN_MAX)
	return gains

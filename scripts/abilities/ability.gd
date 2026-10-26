class_name Ability
extends RefCounted
## One ability (design log 0086), the base each ability script extends
## (design log 0107). Its data (id, name, key slot, price, text, energy
## cost) is set in _init. You equip an ability you own into its key slot
## (design log 0243): W, S or Shift (Abilities.UP, DOWN, SIDE). A body, a player or a Revolt boss (log 0089), keeps
## its own instance of each in a MoveSet, since a move under way has state.
##
## How a move starts depends on who uses it: a player's move starts with
## use_by_player(); a boss calls the ability's own start(...) with its aim.
## Then step() runs every physics step, after the body's own movement.

## Emitted by start(...), so the body's other moves can let go (MoveSet).
signal began(ability: Ability)

var id := ""
var name := ""
var slot := Abilities.UP  # the key slot it's equipped into (design log 0243)
var short := ""  # its touch button's label
var shop := "quartermaster"  # who sells it: "quartermaster" or "ranger" (log 0244)
var price := 0  # chits at the Quartermaster (design log 0206), or coins (`currency`)
var currency := "chits"  # what `price` is in: the ranger quartermaster's drills are coins (log 0246)
var text := ""
var cost := Abilities.COST  # energy per use


## The shop and HUD's view of it.
func info() -> Dictionary:
	return {"name": name, "slot": slot, "action": Abilities.SLOT_ACTIONS[slot], "short": short, "shop": shop,
			"price": price, "currency": currency, "text": text, "cost": cost, "holds": holds(),
			"crit_window": crit_window()}


## False if it can only start while you're on the ground (a pressed one
## waits, like a buffered jump).
func works_in_air() -> bool:
	return false


## False if this player can't use it right now (no tips to throw with, a
## double jump already spent); a press is then dropped, costing nothing.
func usable_by(_player: PlayerShape) -> bool:
	return true


## True for a move you hold, then let go (volley, charged shot; log 0244):
## pressing starts the hold, and release_by_player() does the move, paid
## for then. Held to max_hold(), it goes off by itself.
func holds() -> bool:
	return false


func max_hold() -> float:
	return 0.0


## Seconds held for a hold that crits when let go inside them (the charged
## shot's flash, log 0244), or ZERO.
func crit_window() -> Vector2:
	return Vector2.ZERO


## A held move let go after `held` seconds.
func release_by_player(_player: PlayerShape, _state: PhysicsDirectBodyState2D, _held: float) -> void:
	pass


## Starts the move for a player who pressed its key, with energy to pay.
func use_by_player(_player: PlayerShape, _state: PhysicsDirectBodyState2D) -> void:
	pass


## Steers the move while it's under way. Every physics step.
func step(_state: PhysicsDirectBodyState2D, _corners: PackedVector2Array, _angles: PackedFloat32Array,
		_touching_ground: bool) -> void:
	pass


## In the middle of this move (bosses hit harder then).
func active() -> bool:
	return false


func cancel() -> void:
	pass


## Another of the body's moves just started.
func on_other_start(_other: Ability) -> void:
	pass


## The body jumped.
func on_jump() -> void:
	pass


## Call from start(...).
func _began() -> void:
	began.emit(self)

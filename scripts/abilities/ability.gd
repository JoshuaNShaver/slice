class_name Ability
extends RefCounted
## One ability (design log 0086), the base each ability script extends
## (design log 0107). Its data (id, name, input action, price, text, energy
## cost) is set in _init. A body, a player or a Revolt boss (log 0089), keeps
## its own instance of each in a MoveSet, since a move under way has state.
##
## How a move starts depends on who uses it: a player's move starts with
## use_by_player(); a boss calls the ability's own start(...) with its aim.
## Then step() runs every physics step, after the body's own movement.

## Emitted by start(...), so the body's other moves can let go (MoveSet).
signal began(ability: Ability)

var id := ""
var name := ""
var action := ""  # its Controls input action
var price := 0  # combatant pay at the Quartermaster
var text := ""
var cost := Abilities.COST  # energy per use


## The shop and HUD's view of it.
func info() -> Dictionary:
	return {"name": name, "action": action, "price": price, "text": text, "cost": cost}


## False if it can only start while you're on the ground (a pressed one
## waits, like a buffered jump).
func works_in_air() -> bool:
	return false


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

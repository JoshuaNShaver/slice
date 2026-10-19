class_name MoveSet
extends RefCounted
## One body's abilities: a player's (bought, design log 0086) or a Revolt
## boss's (periodic, design log 0089), one instance of each in
## Abilities.SCRIPTS. The body starts a move, then calls step() every
## physics step to steer it. Server only.

var _all: Array[Ability] = []
var _by_id := {}


func _init() -> void:
	for script: GDScript in Abilities.SCRIPTS:
		var ability: Ability = script.new()
		ability.began.connect(_on_began)
		_all.append(ability)
		_by_id[ability.id] = ability


## The body's instance of an ability, or null.
func get_ability(id: String) -> Ability:
	return _by_id.get(id)


## In the middle of a move (bosses hit harder then).
func active() -> bool:
	for ability in _all:
		if ability.active():
			return true
	return false


func cancel() -> void:
	for ability in _all:
		ability.cancel()


func on_jump() -> void:
	for ability in _all:
		ability.on_jump()


func _on_began(started: Ability) -> void:
	for ability in _all:
		if ability != started:
			ability.on_other_start(started)


## Steers whatever move is under way. Call every physics step, after your
## own movement, so the move wins.
func step(state: PhysicsDirectBodyState2D, corners: PackedVector2Array, angles: PackedFloat32Array,
		touching_ground: bool) -> void:
	for ability in _all:
		ability.step(state, corners, angles, touching_ground)

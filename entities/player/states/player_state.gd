class_name PlayerState
extends Node
## One of Mariane's states, a child of her StateMachine, named after itself
## ("Idle", "Run"...). The machine calls enter()/exit() on a switch, runs
## physics_update() every frame before she moves, then asks get_transition()
## which state comes next (&"" to stay).

var player: Player


func enter(_previous: StringName) -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func get_transition() -> StringName:
	return &""


## Moves she can start while standing (Idle, Run).
func grounded_transition() -> StringName:
	if player.is_on_floor() and player.take_rest_request():
		return &"Rest"
	if player.wants_attack():
		return &"Attack"
	if player.wants_spell():
		return &"Cast"
	if player.wants_guard():
		return &"Guard"
	if player.wants_dash():
		return &"Dash"
	if player.wants_jump():
		return &"Jump"
	if player.wants_climb():
		return &"Climb"
	if not player.is_on_floor():
		return &"Fall"
	return &""


## Moves she can start in the air (Jump, Fall).
func airborne_transition() -> StringName:
	if player.wants_attack():
		return &"Attack"
	if player.wants_dash():
		return &"Dash"
	if player.wants_climb():
		return &"Climb"
	if player.detect_ledge():
		return &"LedgeHang"
	if player.velocity.y > 0.0 and player.is_pressing_into_wall():
		return &"WallSlide"
	return &""


## Where she goes after a move ends: standing, running or falling.
func settle() -> StringName:
	if not player.is_on_floor():
		return &"Fall"
	if player.is_down_held():
		return &"Crouch"
	return &"Run" if player.input_direction() != 0.0 else &"Idle"

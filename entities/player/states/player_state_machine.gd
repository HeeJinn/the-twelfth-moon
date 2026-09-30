class_name PlayerStateMachine
extends Node
## Runs Mariane's states (its PlayerState children). The Player calls
## physics_update() before moving and check_transition() after.

@export var initial_state: PlayerState

var current: PlayerState

var _states: Dictionary[StringName, PlayerState] = {}


func setup(player: Player) -> void:
	for child: Node in get_children():
		var state: PlayerState = child as PlayerState
		if state != null:
			state.player = player
			_states[StringName(state.name)] = state
	current = initial_state
	current.enter(&"")


func physics_update(delta: float) -> void:
	current.physics_update(delta)


func check_transition() -> void:
	var next: StringName = current.get_transition()
	if next != &"":
		transition_to(next)


## Switches state. Switching to the current state does nothing unless
## `force` is set (then it exits and re-enters).
func transition_to(state_name: StringName, force: bool = false) -> void:
	if not _states.has(state_name):
		push_error("Player has no state '%s'." % state_name)
		return
	if current.name == state_name and not force:
		return
	var previous: StringName = StringName(current.name)
	current.exit()
	current = _states[state_name]
	current.enter(previous)


func is_in(state_name: StringName) -> bool:
	return current != null and current.name == state_name

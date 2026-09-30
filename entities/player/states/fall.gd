extends PlayerState
## Falling. Grabs a ledge or slides down a wall when pressing toward one,
## and still jumps for a moment after walking off an edge (coyote time).


func enter(_previous: StringName) -> void:
	player.play_animation(&"up_to_fall")


func physics_update(delta: float) -> void:
	if player.steer_lock <= 0.0:
		player.turn_toward_input()
	player.apply_gravity(delta)
	var direction: float = player.input_direction()
	player.apply_horizontal(direction, player.stats.air_acceleration, player.stats.air_friction, delta)


func get_transition() -> StringName:
	if player.wants_jump() and player.can_coyote_jump():
		return &"Jump"
	var next: StringName = airborne_transition()
	if next != &"":
		return next
	if player.is_on_floor():
		return settle()
	return &""

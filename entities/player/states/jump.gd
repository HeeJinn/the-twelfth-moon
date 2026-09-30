extends PlayerState
## Rising after a jump. Coming off a wall slide it's a wall jump: she kicks
## away from the wall and can't steer back into it for a moment.


func enter(previous: StringName) -> void:
	player.consume_jump()
	player.velocity.y = -player.stats.jump_velocity
	if previous == &"WallSlide":
		player.face(-player.facing)
		player.velocity.x = player.facing * player.stats.wall_jump_push
		player.steer_lock = player.stats.wall_jump_lock
	elif previous == &"Climb":
		player.velocity.y *= 0.75  # A small hop off a vine.
	player.play_animation(&"jump")


func physics_update(delta: float) -> void:
	if player.steer_lock <= 0.0:
		player.turn_toward_input()
	player.apply_jump_cut()
	player.apply_gravity(delta)
	var direction: float = player.input_direction()
	player.apply_horizontal(direction, player.stats.air_acceleration, player.stats.air_friction, delta)


func get_transition() -> StringName:
	var next: StringName = airborne_transition()
	if next != &"":
		return next
	if player.velocity.y >= 0.0:
		return &"Fall"
	return &""

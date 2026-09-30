extends PlayerState
## Climbing a vine ladder with up/down. Jump hops off. Climbing past the
## top stands her on whatever the vine leads up to; past the bottom she
## lets go. Planks don't block her while she climbs through them.


func enter(_previous: StringName) -> void:
	player.velocity = Vector2.ZERO
	player.global_position.x = player.ladder_x()
	player.reset_physics_interpolation()
	player.set_platforms_solid(false)
	player.air_dash_available = true
	player.play_animation(&"climb")


func exit() -> void:
	player.set_platforms_solid(true)
	player.sprite.speed_scale = 1.0


func physics_update(_delta: float) -> void:
	var vertical: float = player.input_vertical()
	player.velocity = Vector2(0.0, vertical * player.stats.climb_speed)
	# The climbing loop only plays while she moves.
	player.sprite.speed_scale = 1.0 if vertical != 0.0 else 0.0


func get_transition() -> StringName:
	if player.wants_jump():
		return &"Jump"
	# Starting down from the top, only her feet touch the vine at first.
	var going_down: bool = player.velocity.y > 0.0
	if player.on_ladder() or (going_down and player.ladder_continues_below()):
		if player.is_on_floor() and (going_down or player.input_direction() != 0.0):
			return settle()  # At the bottom: step off onto the ground.
		return &""
	if player.velocity.y < 0.0:
		# Climbed past the top: step onto it.
		player.global_position.y = player.ladder_top_y()
		player.velocity = Vector2.ZERO
		player.reset_physics_interpolation()
		return &"Idle"
	return &"Fall"

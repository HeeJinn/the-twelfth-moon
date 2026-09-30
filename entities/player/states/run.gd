extends PlayerState
## Running (or walking, when a story scene walks her somewhere). Pressing
## down while running fast starts a slide.


func enter(_previous: StringName) -> void:
	player.play_animation(_animation())


func physics_update(delta: float) -> void:
	player.turn_toward_input()
	player.apply_gravity(delta)
	var direction: float = player.input_direction()
	player.apply_horizontal(direction, player.stats.acceleration, player.stats.friction, delta)
	if player.sprite.animation != _animation():
		player.play_animation(_animation())


func get_transition() -> StringName:
	var next: StringName = grounded_transition()
	if next != &"":
		return next
	if player.is_down_held():
		var fast: bool = absf(player.velocity.x) >= player.stats.slide_trigger_speed
		return &"Slide" if fast else &"Crouch"
	if player.input_direction() == 0.0:
		return &"Idle"
	return &""


func _animation() -> StringName:
	return &"walk" if player.is_walking_scripted() else &"run"

extends PlayerState
## Crouching (hold down). Low enough to duck under magic. Attack slashes
## low; pressing a direction or dash slides; down + jump on a plank drops
## through it.


func enter(previous: StringName) -> void:
	player.set_low_body(true)
	player.play_animation(&"crouch")
	if previous == &"CrouchAttack":
		player.sprite.frame = 2  # Already down: skip crouching again.


func exit() -> void:
	player.set_low_body(false)


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.apply_horizontal(0.0, 0.0, player.stats.friction, delta)


func get_transition() -> StringName:
	if player.wants_jump():
		if player.try_drop_through():
			return &"Fall"
		if player.can_stand():
			return &"Jump"
	if not player.is_on_floor():
		return &"Fall"
	if player.wants_attack():
		return &"CrouchAttack"
	if player.input_direction() != 0.0 or player.wants_dash():
		player.turn_toward_input()
		return &"Slide"
	if not player.is_down_held() and player.can_stand():
		return &"Idle"
	return &""

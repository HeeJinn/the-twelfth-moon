extends PlayerState
## A low slide along the ground. She can't be hurt while sliding, and she
## keeps sliding under a low ceiling until there's room to stand.

var _time_left: float = 0.0


func enter(_previous: StringName) -> void:
	player.set_low_body(true)
	player.play_animation(&"slide")
	_time_left = player.stats.slide_time
	player.velocity.x = player.facing * player.stats.slide_speed
	player.iframe_timer = player.stats.slide_time
	if player.wants_dash():
		player.consume_dash()


func exit() -> void:
	player.set_low_body(false)


func physics_update(delta: float) -> void:
	_time_left -= delta
	player.apply_gravity(delta)
	if player.is_on_wall():
		# Hit a wall (a dead end under a ledge): slide back the other way.
		player.face(-player.facing)
	var target: float = player.facing * player.stats.slide_min_speed
	player.velocity.x = move_toward(player.velocity.x, target, player.stats.slide_friction * delta)


func get_transition() -> StringName:
	if not player.is_on_floor():
		return &"Fall"
	if player.wants_jump() and player.can_stand():
		return &"Jump"
	if _time_left > 0.0 or not player.can_stand():
		return &""
	return settle()

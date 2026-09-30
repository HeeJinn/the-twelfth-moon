extends PlayerState
## Hanging from a ledge by her hands. Jump or up climbs onto it; down or
## pressing away lets go.


func enter(_previous: StringName) -> void:
	player.velocity = Vector2.ZERO
	player.global_position = player.hang_position()
	player.reset_physics_interpolation()
	player.air_dash_available = true
	player.play_animation(&"ledge_grab")


func physics_update(_delta: float) -> void:
	player.velocity = Vector2.ZERO


func get_transition() -> StringName:
	if player.wants_jump() or player.is_up_held():
		player.consume_jump()
		return &"LedgeClimb"
	var direction: float = player.input_direction()
	if player.is_down_held() or signf(direction) == -player.facing:
		player.let_go_of_ledge()
		return &"Fall"
	return &""

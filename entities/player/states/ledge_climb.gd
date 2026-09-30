extends PlayerState
## Pulls herself up onto the ledge. The WallClimb art does the moving (it
## rises and steps forward by Player.CLIMB_SHIFT), so her body waits at the
## hang spot without physics and moves onto the ledge once the art is done.


func enter(_previous: StringName) -> void:
	player.uses_physics = false
	player.velocity = Vector2.ZERO
	player.play_animation(&"ledge_climb")


func exit() -> void:
	player.uses_physics = true


func get_transition() -> StringName:
	if player.finished_animation != &"ledge_climb":
		return &""
	player.global_position = player.climbed_position()
	player.reset_physics_interpolation()
	return &"Idle"

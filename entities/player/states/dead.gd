extends PlayerState
## Collapsed. Stays here until the level calls respawn().


func enter(_previous: StringName) -> void:
	player.velocity.x = 0.0
	player.play_animation(&"death")
	player.mark_dead()


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)

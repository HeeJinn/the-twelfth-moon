extends PlayerState
## Getting back up off the ground: when she wakes at a campfire after
## falling, or when a chapter starts with her asleep. Pressing a direction
## near the end cuts it short.

## From this frame of "get_up" she's on her feet enough to run off.
const MOVE_FROM_FRAME: int = 4


func enter(_previous: StringName) -> void:
	player.velocity.x = 0.0
	player.play_animation(&"get_up")


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.apply_horizontal(0.0, 0.0, player.stats.friction, delta)


func get_transition() -> StringName:
	if player.finished_animation == &"get_up":
		return settle()
	if player.sprite.frame >= MOVE_FROM_FRAME and player.input_direction() != 0.0:
		return settle()
	return &""

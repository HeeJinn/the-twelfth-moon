extends PlayerState
## Knocked back after a hit; no control for a moment.

var _time_left: float = 0.0


func enter(_previous: StringName) -> void:
	_time_left = player.stats.hurt_duration
	player.play_animation(&"hurt")


func physics_update(delta: float) -> void:
	_time_left -= delta
	player.apply_gravity(delta)
	player.apply_horizontal(0.0, 0.0, player.stats.air_friction, delta)


func get_transition() -> StringName:
	return settle() if _time_left <= 0.0 else &""

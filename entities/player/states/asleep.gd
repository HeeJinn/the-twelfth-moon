extends PlayerState
## Lying asleep (a chapter can start this way, see Player.fall_asleep). The
## player wakes her by finishing the next conversation, then she gets up.


func enter(_previous: StringName) -> void:
	player.velocity = Vector2.ZERO
	player.play_animation(&"asleep")


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.apply_horizontal(0.0, 0.0, player.stats.friction, delta)

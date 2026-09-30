extends PlayerState
## Standing still. Coming out of a landing, a crouch or a slide she first
## plays that move's recovery; after standing still a while she relaxes
## into her calm stance.

## Previous state -> the short animation she recovers with.
const RECOVERIES: Dictionary[StringName, StringName] = {
	&"Fall": &"land",
	&"Crouch": &"stand_up",
	&"CrouchAttack": &"stand_up",
	&"Slide": &"slide_end",
}

var _still_time: float = 0.0


func enter(previous: StringName) -> void:
	_still_time = 0.0
	player.play_animation(RECOVERIES.get(previous, &"idle"))


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.apply_horizontal(0.0, 0.0, player.stats.friction, delta)
	_still_time += delta
	if player.finished_animation in RECOVERIES.values():
		player.play_animation(&"idle")
	elif _still_time >= player.stats.calm_delay and player.sprite.animation == &"idle":
		player.play_animation(&"idle_calm")


func get_transition() -> StringName:
	var next: StringName = grounded_transition()
	if next != &"":
		return next
	if player.is_down_held():
		return &"Crouch"
	if player.input_direction() != 0.0:
		return &"Run"
	return &""

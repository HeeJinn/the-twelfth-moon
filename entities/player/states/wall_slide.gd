extends PlayerState
## Sliding slowly down a wall she's pressing into. Jump kicks off it (a
## wall jump); pressing away lets go.

var _wall_direction: float = 1.0


func enter(_previous: StringName) -> void:
	_wall_direction = signf(player.input_direction())
	if _wall_direction == 0.0:
		_wall_direction = player.facing
	player.face(_wall_direction)  # The art reaches toward the wall.
	player.air_dash_available = true
	player.play_animation(&"wall_slide")


func physics_update(delta: float) -> void:
	player.apply_gravity(delta, player.stats.wall_slide_speed)
	# Lean into the wall so she stays touching it.
	player.velocity.x = _wall_direction * 20.0


func get_transition() -> StringName:
	if player.wants_jump():
		return &"Jump"
	if player.wants_dash():
		player.face(-_wall_direction)
		return &"Dash"
	if player.is_on_floor():
		return &"Idle"
	if player.detect_ledge():
		return &"LedgeHang"
	var direction: float = player.input_direction()
	if signf(direction) == -_wall_direction or not player.wall_ahead(_wall_direction):
		return &"Fall"
	return &""

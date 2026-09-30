extends PlayerState
## Guard up (hold block): she plants her feet with her sword raised. Blows
## from the front do no harm (Player.take_damage) and flash on the blade.
## She can turn to face a threat, jump or swing out of it; letting go
## lowers the sword.

var _lowering: bool = false


func enter(_previous: StringName) -> void:
	_lowering = false
	player.is_guarding = true
	player.blocked_hit = false
	player.play_animation(&"guard_up")


func exit() -> void:
	player.is_guarding = false
	player.blocked_hit = false


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.apply_horizontal(0.0, 0.0, player.stats.friction, delta)
	if _lowering:
		return
	player.turn_toward_input()
	if player.blocked_hit:
		player.blocked_hit = false
		player.play_animation(&"block")


func get_transition() -> StringName:
	if not player.is_on_floor():
		return &"Fall"
	if player.wants_jump():
		return &"Jump"
	if player.wants_attack():
		return &"Attack"
	if _lowering:
		return settle() if player.finished_animation == &"guard_down" else &""
	if not player.wants_guard():
		_lowering = true
		player.is_guarding = false
		player.play_animation(&"guard_down")
	return &""

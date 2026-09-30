extends PlayerState
## Attack held after a swing: she lifts her sword and moonlight fills it.
## Once it's full (a flash), letting go swings a Moon Slash; letting go
## earlier just lowers the sword.

## How bright she flashes when the sword is full.
const READY_FLASH: Color = Color(1.6, 1.9, 2.0)

var _time: float = 0.0
var _is_ready: bool = false


func enter(_previous: StringName) -> void:
	_time = 0.0
	_is_ready = false
	player.play_animation(&"charge")


func exit() -> void:
	player.sprite.self_modulate = Color.WHITE


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.apply_horizontal(0.0, 0.0, player.stats.friction, delta)
	_time += delta
	if not _is_ready and _time >= player.stats.charge_time:
		_is_ready = true
		player.sprite.self_modulate = READY_FLASH
		var tween: Tween = create_tween()
		tween.tween_property(player.sprite, "self_modulate", Color.WHITE, 0.2)


func get_transition() -> StringName:
	if not player.is_on_floor():
		return &"Fall"
	if player.is_attack_held():
		return &""
	return &"MoonSlash" if _is_ready else settle()

extends PlayerState
## The Moon Slash: a great crescent swing that hits hard up close and sends
## a wave of moonlight flying on ahead (moon_wave.gd).

## Frames of "moon_slash" during which the crescent can hit.
const ACTIVE_FRAMES: Array[int] = [1, 2, 3]
## The wave leaves the blade on this frame, from here (feet, facing right).
const WAVE_FRAME: int = 1
const WAVE_OFFSET: Vector2 = Vector2(22.0, -14.0)

var _hits: Array[Damageable] = []
var _launched: bool = false


func enter(_previous: StringName) -> void:
	_hits.clear()
	_launched = false
	player.play_animation(&"moon_slash")


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.apply_horizontal(0.0, 0.0, player.stats.friction, delta)
	if player.sprite.frame in ACTIVE_FRAMES:
		player.hit_enemies(Player.Reach.CRESCENT, player.stats.moon_slash_damage, _hits)
	if not _launched and player.sprite.frame >= WAVE_FRAME and player.moon_wave_scene:
		_launched = true
		player.launch(player.moon_wave_scene, WAVE_OFFSET)


func get_transition() -> StringName:
	if player.finished_animation == &"moon_slash":
		return settle()
	return &""

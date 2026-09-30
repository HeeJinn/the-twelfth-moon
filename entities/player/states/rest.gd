extends PlayerState
## A moment at a campfire she just lit: she warms herself (HPRecovery, gold
## sparkles gather round her) and gathers moonlight (MPRecovery, silver-blue
## ones). Her hearts and moons were already refilled by Player.rest(); this
## shows it.

const HEAL_GOLD: SpriteFrames = preload("res://entities/effects/heal_gold_frames.tres")
const HEAL_MOON: SpriteFrames = preload("res://entities/effects/heal_moon_frames.tres")
## Where on her the sparkles gather (her feet are the origin).
const GLOW_OFFSET: Vector2 = Vector2(0.0, -14.0)


func enter(_previous: StringName) -> void:
	player.velocity.x = 0.0
	player.play_animation(&"heal")
	_glow(HEAL_GOLD)


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.apply_horizontal(0.0, 0.0, player.stats.friction, delta)
	if player.finished_animation == &"heal":
		player.play_animation(&"restore")
		_glow(HEAL_MOON)


func get_transition() -> StringName:
	if not player.is_on_floor():
		return &"Fall"
	if player.finished_animation == &"restore":
		return settle()
	return &""


func _glow(frames: SpriteFrames) -> void:
	OneShot.play(player.get_parent(), frames, player.global_position + GLOW_OFFSET, 5)

class_name OneShot
extends RefCounted
## Plays a one-shot effect (a SpriteFrames with a "play" animation) at a spot
## and frees it when it ends: hit sparks, dust, bursts.


static func play(parent: Node, frames: SpriteFrames, at: Vector2, z_index: int = 4,
		flip: bool = false) -> AnimatedSprite2D:
	var effect: AnimatedSprite2D = AnimatedSprite2D.new()
	effect.sprite_frames = frames
	effect.z_index = z_index
	effect.flip_h = flip
	parent.add_child(effect)
	effect.global_position = at
	effect.play(&"play")
	effect.animation_finished.connect(effect.queue_free)
	return effect

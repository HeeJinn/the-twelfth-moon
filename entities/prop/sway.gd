extends AnimatedSprite2D
## A looping prop that moves on its own: a tree or grass swaying in the
## wind, a firefly jar, blinking eyes. Each one starts at a random point of
## its loop and runs at a slightly different speed, so a row of trees never
## sways in step.

## How much the speed may differ from the animation's own (0.15 = +-15%).
@export var speed_variation: float = 0.15


func _ready() -> void:
	play()
	frame = randi() % sprite_frames.get_frame_count(animation)
	speed_scale = randf_range(1.0 - speed_variation, 1.0 + speed_variation)

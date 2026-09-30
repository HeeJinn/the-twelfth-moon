class_name ShootingStars
extends Node2D
## Now and then a star falls across the night sky: one short, gentle streak in
## the upper part of the view, never more than one at a time, nothing that
## flashes. Put it under a Parallax2D with a scroll scale of zero so it stays
## on the screen. It pauses with the game.
##
## Scene: ShootingStars (Node2D, this script)
##   %Sprite  AnimatedSprite2D with a one-shot "play" animation
##   %Timer   Timer (one shot), restarted with a random wait after each star

## Seconds between stars.
@export var delay: Vector2 = Vector2(10.0, 20.0)
## Where a streak may begin, in screen pixels (the view is 480x270).
@export var area: Rect2 = Rect2(30.0, 6.0, 330.0, 60.0)

@onready var _sprite: AnimatedSprite2D = %Sprite
@onready var _timer: Timer = %Timer


func _ready() -> void:
	_sprite.visible = false
	_sprite.animation_finished.connect(_on_animation_finished)
	_timer.timeout.connect(shoot)
	_wait()


## Sends a star across now, unless one is already falling. The next one comes
## after the usual wait.
func shoot() -> void:
	if _sprite.visible:
		return
	_sprite.position = area.position + Vector2(randf() * area.size.x, randf() * area.size.y)
	_sprite.flip_h = randf() < 0.5
	_sprite.visible = true
	_sprite.play(&"play")


func is_shooting() -> bool:
	return _sprite.visible


func _on_animation_finished() -> void:
	_sprite.visible = false
	_wait()


func _wait() -> void:
	_timer.start(randf_range(delay.x, delay.y))

extends Node2D
## A fish that now and then leaps out of the river in a little arc and
## splashes back in. Place it on the water's surface.
##
## Scene: LeapingFish (Node2D, origin on the water surface)
##   %Sprite  AnimatedSprite2D "walk" (flopping), art faces right

@export var leap_height: float = 40.0
@export var leap_width: float = 36.0
@export var leap_time: float = 0.9
## Seconds between leaps.
@export var wait_time: Vector2 = Vector2(2.5, 6.0)

@onready var _sprite: AnimatedSprite2D = %Sprite


func _ready() -> void:
	_sprite.hide()
	_leap_later()


func _leap_later() -> void:
	await get_tree().create_timer(randf_range(wait_time.x, wait_time.y)).timeout
	if is_inside_tree():
		_leap()


func _leap() -> void:
	var direction: float = 1.0 if randf() < 0.5 else -1.0
	_sprite.flip_h = direction < 0.0
	_sprite.position = Vector2(-direction * leap_width / 2.0, 0.0)
	_sprite.rotation = -direction * 0.6
	_sprite.show()
	_sprite.play(&"walk")
	var end: Vector2 = Vector2(direction * leap_width / 2.0, 0.0)
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(_sprite, "position:x", end.x, leap_time)
	tween.tween_property(_sprite, "rotation", direction * 0.6, leap_time)
	var arc: Tween = create_tween()
	arc.tween_property(_sprite, "position:y", -leap_height, leap_time / 2.0) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	arc.tween_property(_sprite, "position:y", 0.0, leap_time / 2.0) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	await arc.finished
	_sprite.hide()
	_leap_later()

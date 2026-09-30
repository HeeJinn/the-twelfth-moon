class_name MovingPlatform
extends AnimatableBody2D
## A stone lift that glides between where it stands and `travel` away, resting
## a moment at each end. Mariane rides it: stand on it and it carries her. It is
## one-way like a ledge, so she can jump up through it from below and drop off
## it with down + jump, and it never crushes anyone.
##
## Scene: MovingPlatform (AnimatableBody2D, origin at the middle of its top
## surface, collision layer 2 "platforms", sync to physics)
##   Sprite2D          castle_lift.png, five tiles wide
##   CollisionShape2D  one-way, along the top

## Where it glides to, from where the map places it (px).
@export var travel: Vector2 = Vector2(0.0, -64.0)
## Gliding speed, px/s.
@export var speed: float = 26.0
## Seconds it rests at each end.
@export var rest_time: float = 1.0
## Seconds before it first moves, to stagger a row of them.
@export var start_delay: float = 0.0


func _ready() -> void:
	var home: Vector2 = position
	var away: Vector2 = position + travel
	var seconds: float = maxf(travel.length() / speed, 0.1)
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	var tween: Tween = create_tween().set_loops()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(rest_time)
	tween.tween_property(self, "position", away, seconds)
	tween.tween_interval(rest_time)
	tween.tween_property(self, "position", home, seconds)

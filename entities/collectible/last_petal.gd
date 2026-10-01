class_name LastPetal
extends Collectible
## The twenty-first petal, which falls from Kael at the reveal. It is part of
## the map from the start (so the HUD shows one petal still to find), but it
## stays hidden and can't be picked up until release() lets it drift down.


func _ready() -> void:
	super()
	add_to_group(&"last_petal")
	hide()
	monitoring = false


func is_released() -> bool:
	return visible


## Drifts down from `from` to the ground at `to` (global), swaying a little,
## then can be picked up.
func release(from: Vector2, to: Vector2, seconds: float = 2.6) -> void:
	global_position = from
	reset_physics_interpolation()
	show()
	var fall: Tween = create_tween().set_parallel()
	fall.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	fall.tween_property(self, "global_position:y", to.y, seconds).set_trans(Tween.TRANS_SINE)
	var sway: Tween = create_tween()
	sway.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	var steps: int = 4
	for i: int in steps:
		var x: float = lerpf(from.x, to.x, float(i + 1) / steps) + (6.0 if i % 2 == 0 else -6.0)
		if i == steps - 1:
			x = to.x
		sway.tween_property(self, "global_position:x", x, seconds / steps) \
				.set_trans(Tween.TRANS_SINE)
	await fall.finished
	monitoring = true

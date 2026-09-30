extends PlayerState
## A quick straight burst forward, on the ground or once in the air. She
## can't be hurt while dashing. Attack during a dash lunges into a slash.
## The pack has no dash art, so she leans in with her sword swept back and
## leaves a trail of moonlit afterimages.

## Seconds between afterimages.
const AFTERIMAGE_INTERVAL: float = 0.035

var _time_left: float = 0.0
var _afterimage_timer: float = 0.0


func enter(_previous: StringName) -> void:
	player.turn_toward_input()
	player.consume_dash()
	_time_left = player.stats.dash_time
	player.iframe_timer = player.stats.dash_time + 0.05
	player.velocity = Vector2(player.facing * player.stats.dash_speed, 0.0)
	player.play_animation(&"dash" if player.is_on_floor() else &"air_dash")
	_afterimage_timer = 0.0


func exit() -> void:
	# Carry some speed out of the dash so it flows into running or falling.
	player.velocity.x = player.facing * player.stats.max_speed


func physics_update(delta: float) -> void:
	_time_left -= delta
	player.velocity = Vector2(player.facing * player.stats.dash_speed, 0.0)
	_afterimage_timer -= delta
	if _afterimage_timer <= 0.0:
		_afterimage_timer = AFTERIMAGE_INTERVAL
		player.leave_afterimage()


func get_transition() -> StringName:
	if player.wants_attack():
		return &"DashAttack"
	if _time_left > 0.0 and not player.is_on_wall():
		return &""
	return settle()

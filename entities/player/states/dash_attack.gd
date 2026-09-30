extends PlayerState
## A lunging slash out of a dash (Attack2's wide sweep): longer reach and
## double damage.

## Frames of "dash_attack" during which the blade can hit.
const ACTIVE_FRAMES: Array[int] = [1, 2, 3]

var _hits: Array[Damageable] = []


func enter(_previous: StringName) -> void:
	player.consume_attack()
	_hits.clear()
	player.velocity.x = player.facing * player.stats.dash_attack_speed
	player.play_animation(&"dash_attack")


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, 450.0 * delta)
	if player.sprite.frame in ACTIVE_FRAMES:
		player.hit_enemies(Player.Reach.LUNGE, player.stats.dash_attack_damage, _hits)


func get_transition() -> StringName:
	if player.finished_animation == &"dash_attack":
		return settle()
	return &""

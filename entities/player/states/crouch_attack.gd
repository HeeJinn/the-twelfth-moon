extends PlayerState
## A slash from a crouch. She stays low (under magic and spores) and hits
## what's close to the ground in front of her.

## Frames of "crouch_attack" during which the blade can hit.
const ACTIVE_FRAMES: Array[int] = [4, 5, 6]

var _hits: Array[Damageable] = []


func enter(_previous: StringName) -> void:
	player.set_low_body(true)
	player.consume_attack()
	_hits.clear()
	player.play_animation(&"crouch_attack")


func exit() -> void:
	player.set_low_body(false)


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.apply_horizontal(0.0, 0.0, player.stats.friction, delta)
	if player.sprite.frame in ACTIVE_FRAMES:
		player.hit_enemies(Player.Reach.LOW, player.stats.attack_damage, _hits)


func get_transition() -> StringName:
	if not player.is_on_floor():
		return &"Fall"
	if player.finished_animation != &"crouch_attack":
		return &""
	if player.is_down_held() or not player.can_stand():
		return &"Crouch"
	return settle()

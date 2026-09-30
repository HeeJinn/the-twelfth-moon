extends PlayerState
## Sword swings. On the ground, pressing attack again during a swing chains
## up to three slashes (Attack1, 2, 3; the third hits harder). In the air
## it's two (JumpAttack1, 2). Keeping attack held when a ground swing ends
## starts charging a Moon Slash.

const GROUND_COMBO: Array[StringName] = [&"attack", &"attack_2", &"attack_3"]
const AIR_COMBO: Array[StringName] = [&"air_attack", &"air_attack_2"]
## Frames of each swing during which the blade can hit.
const ACTIVE_FRAMES: Dictionary[StringName, Array] = {
	&"attack": [2, 3, 4],
	&"attack_2": [1, 2, 3],
	&"attack_3": [2, 3, 4],
	&"air_attack": [2, 3, 4],
	&"air_attack_2": [1, 2, 3],
}

var _combo: Array[StringName] = GROUND_COMBO
var _step: int = 0
var _queued: bool = false
## Attack has been held down without a break since this swing began.
var _held: bool = false
var _hits: Array[Damageable] = []


func enter(_previous: StringName) -> void:
	_combo = GROUND_COMBO if player.is_on_floor() else AIR_COMBO
	_start(0)


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	if player.is_on_floor():
		player.apply_horizontal(0.0, 0.0, player.stats.friction, delta)
	else:
		var direction: float = player.input_direction()
		player.apply_horizontal(direction, player.stats.air_acceleration, player.stats.air_friction, delta)
	var has_next: bool = _step + 1 < _combo.size()
	if has_next and player.wants_attack() and player.sprite.frame >= 1:
		_queued = true
		player.consume_attack()
	if not player.is_attack_held():
		_held = false
	var swing: StringName = _combo[_step]
	if player.sprite.frame in ACTIVE_FRAMES[swing]:
		var damage: int = player.stats.attack_damage
		if swing == &"attack_3":
			damage = player.stats.finisher_damage
		player.hit_enemies(Player.Reach.SWORD, damage, _hits)


func get_transition() -> StringName:
	if player.finished_animation != _combo[_step]:
		return &""
	if _queued:
		_start(_step + 1)
		return &""
	if _held and player.is_on_floor():
		return &"Charge"
	return settle()


func _start(step: int) -> void:
	_step = step
	_queued = false
	_held = true
	_hits.clear()
	player.consume_attack()
	player.play_animation(_combo[step])

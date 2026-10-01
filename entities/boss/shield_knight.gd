class_name ShieldKnight
extends Damageable
## Kael's Shield, Chapter Three's mini-boss at the winter gate. A duel that
## teaches reading an opponent, kept gentle for a player new to games:
## touching him never hurts, every attack shows a "!" and a slow wind-up,
## and her own guard stops his blows.
##
## His loop: GUARDING (shield raised; sword blows from the front glance off
## it with a blue spark; he walks, or leaps, to close the distance) ->
## WINDING UP ("!", the start of a swing) -> ATTACKING (the blade can hurt)
## -> OPEN (shield lowered, catching his breath: the moment to strike).
## Two hits in one opening and he rolls away. Moonlight (the Moon Slash,
## its wave, the Moon Spark) goes straight through the shield and staggers
## him. At half health he adds a low sweep (jump it) and a ground strike
## that raises a row of frost spikes toward her. Beaten, he kneels and
## yields; the arena scene takes it from there.
##
## Moves where the art travels (roll, leap, sweep) carry his body along
## frame by frame (MOTION), so his sword and body stay where they're drawn.
##
## Scene: ShieldKnight (CharacterBody2D, origin at the feet; layer 8, mask 0)
##   %AnimatedSprite2D   192x64 frames, body at x 64, feet at y 44 (faces right)
##   CollisionShape2D    his body, for her sword
##   %BladeHitbox        ShapeCast2D, mask 4 (player), shaped per attack
##   %Alert              AnimatedSprite2D "!" over his head, hidden

## Emitted when his health runs out. He kneels until the arena moves on.
signal defeated

enum Phase { WAITING, GUARDING, WALKING, LEAPING, ATTACKING, OPEN, STAGGERED, ROLLING, YIELDED }

const SPIKES_SCENE: PackedScene = preload("res://entities/hazard/frost_spikes.tscn")
const GUARD_SPARK: SpriteFrames = preload("res://entities/effects/guard_spark_frames.tres")
const LANDING: SpriteFrames = preload("res://entities/effects/landing_dust_frames.tres")
## Frame centre (96, 32) from his feet (64, 44) when facing right.
const SPRITE_OFFSET: Vector2 = Vector2(32.0, -12.0)
## How far forward his body is drawn on each frame of the moves that travel.
const MOTION: Dictionary[StringName, Array] = {
	&"roll": [0, 0, 5, 8, 11, 25, 43, 59, 67, 75, 79, 81, 81, 81, 81],
	&"leap": [0, 0, 0, 4, 13, 21, 30, 41, 49, 54, 62, 61, 61, 61, 61],
	&"sweep": [4, 6, 10, 27, 27, 27, 27, 27],
}
## Attack -> [frames when the blade hurts, hitbox size, hitbox centre].
const ATTACKS: Dictionary[StringName, Array] = {
	&"thrust": [[5, 6, 7], Vector2(46, 14), Vector2(34, -18)],
	&"slash": [[1, 2], Vector2(50, 40), Vector2(22, -24)],
	&"sweep": [[3, 4], Vector2(62, 14), Vector2(30, -8)],
}
## The slash's frame where his sword strikes the ground (phase two raises
## frost spikes from there).
const STRIKE_FRAME: int = 2
const SPIKE_SPACING: float = 40.0
const SPIKE_COUNT: int = 4

@export var display_name: String = "The Shield Knight"
@export var max_health: int = 8
## His voice bank (see Audio): a grunt as he winds up, a shout for the sweep.
@export var voice_bank: StringName = &"ian"
## Seconds he holds his guard before attacking.
@export var guard_time: Vector2 = Vector2(1.1, 1.8)
## Seconds his shield stays down after an attack.
@export var open_time: float = 1.9
@export var stagger_time: float = 1.4
@export var walk_speed: float = 55.0
## He walks toward her until this close, and leaps when she's further
## than `leap_distance`.
@export var reach: float = 58.0
@export var leap_distance: float = 190.0
## Seconds his guard takes to turn to face her when she gets behind him.
@export var turn_delay: float = 0.35

## Left and right edge (global x) he must stay between, set by the arena.
var bounds: Vector2 = Vector2(-INF, INF)

var _target: Player
var _phase: Phase = Phase.WAITING
var _health: int = 0
var _timer: float = 0.0
var _turn_timer: float = 0.0
var _facing: float = -1.0
var _attack: StringName = &"thrust"
var _attack_count: int = 0
var _hit_landed: bool = false
var _hits_this_opening: int = 0
var _spikes_raised: bool = false
var _motion_frame: int = 0

@onready var _sprite: AnimatedSprite2D = %AnimatedSprite2D
@onready var _blade: ShapeCast2D = %BladeHitbox
@onready var _alert: AnimatedSprite2D = %Alert


func _ready() -> void:
	_health = max_health
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.frame_changed.connect(_on_frame_changed)
	_alert.hide()
	_apply_facing()
	_sprite.play(&"idle")


func _physics_process(delta: float) -> void:
	match _phase:
		Phase.GUARDING:
			_turn_to_target(delta)
			_timer -= delta
			var distance: float = _distance_to_target()
			if distance > leap_distance and _room_to_leap():
				_start_leap()
			elif distance > reach:
				_phase = Phase.WALKING
				_sprite.play(&"run")
			elif _timer <= 0.0:
				_wind_up()
		Phase.WALKING:
			_face_target()
			var step: float = walk_speed * delta * _facing
			global_position.x = clampf(global_position.x + step, bounds.x, bounds.y)
			if _distance_to_target() <= reach or _at_bound():
				_guard(0.3)
		Phase.ATTACKING:
			_update_blade()
		Phase.OPEN, Phase.STAGGERED:
			_timer -= delta
			if _timer <= 0.0:
				_guard()


## Begins the duel against `player`.
func start_fight(player: Player) -> void:
	_target = player
	_health = max_health
	_attack_count = 0
	collision_layer = 8
	EventBus.boss_started.emit(display_name, max_health)
	_guard()


## Back to the start (after Mariane is knocked out mid-fight).
func reset(at: Vector2) -> void:
	_phase = Phase.WAITING
	_health = max_health
	_alert.hide()
	global_position = at
	reset_physics_interpolation()
	_facing = -1.0
	_apply_facing()
	_sprite.play(&"idle")
	EventBus.boss_finished.emit()


func take_hit(amount: int, source_position: Vector2) -> void:
	if _phase in [Phase.WAITING, Phase.ROLLING, Phase.LEAPING, Phase.YIELDED]:
		return
	if is_guarding_against(source_position):
		_glance(source_position)
		return
	_hurt(amount)
	if _phase == Phase.YIELDED:
		return
	_hits_this_opening += 1
	if _hits_this_opening >= 2 and _phase != Phase.STAGGERED:
		_roll_away()


## Moonlight goes straight through the shield and staggers him.
func take_moon_hit(amount: int, _source_position: Vector2) -> void:
	if _phase in [Phase.WAITING, Phase.ROLLING, Phase.LEAPING, Phase.YIELDED]:
		return
	_hurt(amount)
	if _phase != Phase.YIELDED:
		_stagger()


func is_guarding_against(source_position: Vector2) -> bool:
	var winding_up: bool = _phase == Phase.ATTACKING and _sprite.frame < _first_active_frame()
	if _phase not in [Phase.GUARDING, Phase.WALKING] and not winding_up:
		return false
	var side: float = signf(source_position.x - global_position.x)
	return side == _facing or side == 0.0


func is_open() -> bool:
	return _phase in [Phase.OPEN, Phase.STAGGERED]


func _is_angry() -> bool:
	return _health * 2 <= max_health


func _first_active_frame() -> int:
	var active: Array = ATTACKS[_attack][0]
	return active[0]


func _guard(seconds: float = -1.0) -> void:
	_phase = Phase.GUARDING
	_alert.hide()
	_sprite.speed_scale = 1.0
	_hits_this_opening = 0
	_timer = seconds if seconds >= 0.0 else randf_range(guard_time.x, guard_time.y)
	_face_target()
	if _sprite.animation != &"guard":
		_sprite.play(&"guard")


## Starts a swing. Its first frames are the wind-up (a "!" shows and his
## shield still guards); it can hurt from its first active frame.
func _wind_up() -> void:
	_attack_count += 1
	var choices: Array[StringName] = [&"thrust", &"slash"]
	if _is_angry():
		choices.append(&"sweep")
	_attack = choices[_attack_count % choices.size()]
	_face_target()
	_hit_landed = false
	_spikes_raised = false
	var spec: Array = ATTACKS[_attack]
	var box: RectangleShape2D = _blade.shape as RectangleShape2D
	box.size = spec[1]
	var centre: Vector2 = spec[2]
	_blade.position = Vector2(centre.x * _facing, centre.y)
	_alert.show()
	_alert.play(&"play")
	Audio.voice(voice_bank, &"shout" if _attack == &"sweep" else &"grunt")
	_motion_frame = 0
	_sprite.speed_scale = 1.0
	_sprite.play(_attack)
	_phase = Phase.ATTACKING


func _update_blade() -> void:
	var active: Array = ATTACKS[_attack][0]
	var frame: int = _sprite.frame
	if frame >= active[0]:
		_alert.hide()
	if _attack == &"slash" and _is_angry() and frame >= STRIKE_FRAME and not _spikes_raised:
		_spikes_raised = true
		_raise_spikes()
	if _hit_landed or frame not in active:
		return
	_blade.force_shapecast_update()
	for i: int in _blade.get_collision_count():
		var player: Player = _blade.get_collider(i) as Player
		if player != null and not player.is_dead():
			_hit_landed = true
			player.take_damage(1, global_position)


## A row of frost spikes running toward her along the ground.
func _raise_spikes() -> void:
	for i: int in SPIKE_COUNT:
		var x: float = global_position.x + _facing * (48.0 + i * SPIKE_SPACING)
		if x < bounds.x or x > bounds.y:
			break
		var spikes: FrostSpikes = SPIKES_SCENE.instantiate() as FrostSpikes
		spikes.repeating = false
		spikes.start_delay = 0.12 * i
		var arena: Node2D = get_parent() as Node2D
		spikes.position = arena.to_local(Vector2(x, global_position.y))
		arena.add_child(spikes)


func _open() -> void:
	_phase = Phase.OPEN
	_alert.hide()
	_sprite.speed_scale = 1.0
	_timer = open_time * (0.75 if _is_angry() else 1.0)
	_sprite.play(&"idle")


func _stagger() -> void:
	_phase = Phase.STAGGERED
	_alert.hide()
	_timer = stagger_time
	_sprite.play(&"idle")
	_sprite.speed_scale = 0.5


func _hurt(amount: int) -> void:
	_health = maxi(_health - amount, 0)
	EventBus.boss_health_changed.emit(_health, max_health)
	_sprite.modulate = Color(1.0, 0.5, 0.55)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.25)
	if _health == 0:
		_yield()
	else:
		Audio.voice(voice_bank, &"hurt")


## A sword blow glances off his raised shield.
func _glance(source_position: Vector2) -> void:
	var at: Vector2 = global_position + Vector2(_facing * 10.0, -20.0)
	OneShot.play(get_parent(), GUARD_SPARK, at, 5)
	var tween: Tween = create_tween()
	tween.tween_property(_sprite, "position:x", -signf(source_position.x - at.x) * 2.0, 0.05)
	tween.tween_property(_sprite, "position:x", 0.0, 0.08)


func _start_leap() -> void:
	_phase = Phase.LEAPING
	_face_target()
	_motion_frame = 0
	collision_layer = 0
	_sprite.play(&"leap")


func _roll_away() -> void:
	_phase = Phase.ROLLING
	_alert.hide()
	var away: float = -signf(_target.global_position.x - global_position.x) if _target else -_facing
	var room: float = (bounds.y - global_position.x) if away > 0.0 else (global_position.x - bounds.x)
	if room < 90.0:
		away = -away  # Cornered: roll past her instead.
	_facing = away if away != 0.0 else -_facing
	_apply_facing()
	_motion_frame = 0
	collision_layer = 0
	_sprite.play(&"roll")


func _yield() -> void:
	_phase = Phase.YIELDED
	_alert.hide()
	_sprite.speed_scale = 1.0
	collision_layer = 0
	_sprite.play(&"yield")
	Audio.voice(voice_bank, &"death")
	EventBus.boss_finished.emit()
	defeated.emit.call_deferred()


func _distance_to_target() -> float:
	return absf(_target.global_position.x - global_position.x) if _target else 0.0


func _room_to_leap() -> bool:
	var landing: float = global_position.x + signf(_target.global_position.x - global_position.x) * 61.0
	return landing > bounds.x and landing < bounds.y


func _at_bound() -> bool:
	return global_position.x <= bounds.x + 0.5 or global_position.x >= bounds.y - 0.5


## Turns his guard toward her, a moment after she gets behind him.
func _turn_to_target(delta: float) -> void:
	if _target == null:
		return
	var side: float = signf(_target.global_position.x - global_position.x)
	if side == 0.0 or side == _facing:
		_turn_timer = 0.0
		return
	_turn_timer += delta
	if _turn_timer >= turn_delay:
		_turn_timer = 0.0
		_face_target()


func _face_target() -> void:
	if _target != null:
		var side: float = signf(_target.global_position.x - global_position.x)
		if side != 0.0:
			_facing = side
	_apply_facing()


func _apply_facing() -> void:
	_sprite.flip_h = _facing < 0.0
	var drawn_ahead: float = 0.0
	if MOTION.has(_sprite.animation):
		var motion: Array = MOTION[_sprite.animation]
		drawn_ahead = motion[mini(_sprite.frame, motion.size() - 1)]
	_sprite.offset = Vector2((SPRITE_OFFSET.x - drawn_ahead) * _facing, SPRITE_OFFSET.y)


## Moves that travel carry his body along with the art, frame by frame.
func _on_frame_changed() -> void:
	if not MOTION.has(_sprite.animation):
		_apply_facing()
		return
	var motion: Array = MOTION[_sprite.animation]
	var frame: int = mini(_sprite.frame, motion.size() - 1)
	var step: float = float(motion[frame]) - float(motion[mini(_motion_frame, motion.size() - 1)])
	_motion_frame = frame
	global_position.x = clampf(global_position.x + step * _facing, bounds.x, bounds.y)
	_apply_facing()


func _on_animation_finished() -> void:
	match _sprite.animation:
		&"thrust", &"slash", &"sweep":
			_motion_frame = 0
			_open()
		&"leap":
			collision_layer = 8
			_motion_frame = 0
			OneShot.play(get_parent(), LANDING, global_position + Vector2(0.0, -16.0), 1)
			_sprite.play(&"guard")
			_guard(0.4)
		&"roll":
			collision_layer = 8
			_motion_frame = 0
			_sprite.play(&"guard")
			_guard(0.6)

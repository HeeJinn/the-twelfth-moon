class_name MoonProjectile
extends Node2D
## Moonlight Mariane sends flying. Player.launch() places it and calls fly().
##   SPARK  the Moon Spark (Magic Pack spark): a ball of light that bursts on
##          the first monster or wall it touches.
##   WAVE   the Moon Slash's crescent: passes through monsters, hitting each
##          once, and fades out at the end of its range or at a wall.
## Hits are found with a shape query every frame (Area2D overlaps arrive a
## couple of frames late).
##
## Scene: MoonProjectile (Node2D)
##   %Sprite   the art, facing right (spark: AnimatedSprite2D with "fly" and
##             "burst"; wave: Sprite2D)
##   %Hitbox   ShapeCast2D, target_position (0, 0), enabled off,
##             mask 1 (world) + 8 (enemies)

enum Kind { SPARK, WAVE }

## The wave fades over this last part of its range.
const FADE_PART: float = 0.35

@export var kind: Kind = Kind.SPARK

var _direction: float = 1.0
var _speed: float = 0.0
var _range: float = 0.0
var _damage: int = 1
var _travelled: float = 0.0
var _is_done: bool = false
var _hits: Array[Damageable] = []

@onready var _sprite: Node2D = %Sprite
@onready var _hitbox: ShapeCast2D = %Hitbox


func fly(direction: float, stats: PlayerStats) -> void:
	_direction = signf(direction) if direction != 0.0 else 1.0
	_sprite.scale.x = _direction
	if kind == Kind.SPARK:
		_speed = stats.spark_speed
		_range = stats.spark_range
		_damage = stats.spark_damage
	else:
		_speed = stats.moon_wave_speed
		_range = stats.moon_wave_range
		_damage = stats.moon_wave_damage


func _physics_process(delta: float) -> void:
	if _is_done:
		return
	var step: float = _speed * delta
	position.x += _direction * step
	_travelled += step
	_hitbox.force_shapecast_update()
	for i: int in _hitbox.get_collision_count():
		var enemy: Damageable = _hitbox.get_collider(i) as Damageable
		if enemy == null:
			_finish()  # A wall.
			return
		if enemy in _hits:
			continue
		_hits.append(enemy)
		enemy.take_moon_hit(_damage, global_position - Vector2(_direction * 8.0, 0.0))
		if kind == Kind.SPARK:
			_finish()
			return
	if kind == Kind.WAVE:
		var left: float = (_range - _travelled) / (_range * FADE_PART)
		_sprite.modulate.a = clampf(left, 0.0, 1.0)
	if _travelled >= _range:
		_finish()


func _finish() -> void:
	_is_done = true
	var burst: AnimatedSprite2D = _sprite as AnimatedSprite2D
	if burst != null and burst.sprite_frames.has_animation(&"burst"):
		burst.play(&"burst")
		await burst.animation_finished
		queue_free()
		return
	var tween: Tween = create_tween()
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.12)
	tween.tween_callback(queue_free)

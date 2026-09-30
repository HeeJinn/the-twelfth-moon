class_name ThrownProjectile
extends Node2D
## Something a monster throws at Mariane: the skeleton's spinning sword
## (flies level, `aimed` off) or the flying eye's spit (flies straight at
## where she was, `aimed` on). Slow enough to see coming; her guard stops
## it. It bursts on her, on a wall, or at the end of its range. Hits are
## found with a shape query every frame (Area2D overlaps arrive late).
##
## Scene: ThrownProjectile (Node2D)
##   %Sprite   AnimatedSprite2D with "fly" (looping) and "burst"
##   %Hitbox   ShapeCast2D, target_position (0, 0), enabled off,
##             mask 1 (world) + 4 (player)

## Aim at her chest, not her feet.
const CHEST: Vector2 = Vector2(0.0, -16.0)

@export var speed: float = 110.0
@export var max_distance: float = 260.0
@export var damage: int = 1
## True: flies toward her. False: flies straight left or right.
@export var aimed: bool = false

var _velocity: Vector2 = Vector2.ZERO
var _travelled: float = 0.0
var _is_done: bool = false

@onready var _sprite: AnimatedSprite2D = %Sprite
@onready var _hitbox: ShapeCast2D = %Hitbox


func _ready() -> void:
	_sprite.play(&"fly")


## Called by the monster that throws it, with Mariane's position (her feet).
func launch(target: Vector2) -> void:
	var direction: Vector2 = Vector2(signf(target.x - global_position.x), 0.0)
	if aimed:
		direction = global_position.direction_to(target + CHEST)
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	_velocity = direction * speed
	_sprite.flip_h = direction.x < 0.0


func _physics_process(delta: float) -> void:
	if _is_done:
		return
	var step: Vector2 = _velocity * delta
	position += step
	_travelled += step.length()
	_hitbox.force_shapecast_update()
	for i: int in _hitbox.get_collision_count():
		var player: Player = _hitbox.get_collider(i) as Player
		if player != null:
			if player.is_dead():
				continue
			player.take_damage(damage, global_position)
		_burst()
		return
	if _travelled >= max_distance:
		_burst()


func _burst() -> void:
	_is_done = true
	_sprite.play(&"burst")
	await _sprite.animation_finished
	queue_free()

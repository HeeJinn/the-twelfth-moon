class_name GoblinBomb
extends CharacterBody2D
## The goblin's bomb: lobbed in an arc toward where Mariane stood, it lands,
## fizzes for a moment (her cue to step away) and explodes.
##
## Scene: GoblinBomb (CharacterBody2D, layer 0, mask 1+2 so it lands on ground)
##   %AnimatedSprite2D  animations: fly, fuse, explode
##   CollisionShape2D   small circle

enum Phase { FLYING, FUSE, EXPLODING }

## Longest throw, in px, so a far-off target doesn't get an impossible lob.
const MAX_THROW: float = 150.0

@export var damage: int = 1
@export var blast_radius: float = 26.0
@export var fuse_time: float = 0.7
@export var flight_time: float = 0.8

var _phase: Phase = Phase.FLYING
var _timer: float = 0.0
var _gravity: float = 980.0

@onready var _sprite: AnimatedSprite2D = %AnimatedSprite2D


func _ready() -> void:
	_gravity = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.play("fly")


## Throws the bomb so it comes down at `target` after flight_time seconds.
func launch(target: Vector2) -> void:
	var offset: Vector2 = target - global_position
	offset.x = clampf(offset.x, -MAX_THROW, MAX_THROW)
	var t: float = flight_time
	velocity = Vector2(offset.x / t, (offset.y - 0.5 * _gravity * t * t) / t)


func _physics_process(delta: float) -> void:
	match _phase:
		Phase.FLYING:
			velocity.y += _gravity * delta
			var hit: KinematicCollision2D = move_and_collide(velocity * delta)
			if hit != null:
				if hit.get_normal().y < -0.5:
					_start_fuse()
				else:
					velocity.x = -velocity.x * 0.3  # Bounce off a wall.
		Phase.FUSE:
			_timer -= delta
			_sprite.modulate = Color.WHITE if fmod(_timer, 0.2) > 0.1 else Color(1.0, 0.6, 0.5)
			if _timer <= 0.0:
				_explode()


func _start_fuse() -> void:
	_phase = Phase.FUSE
	_timer = fuse_time
	velocity = Vector2.ZERO
	_sprite.play("fuse")


func _explode() -> void:
	_phase = Phase.EXPLODING
	Audio.effect_at(&"fire", global_position)
	_sprite.modulate = Color.WHITE
	_sprite.play("explode")
	var target: Player = get_tree().get_first_node_in_group(&"player") as Player
	if target == null:
		return
	var her_centre: Vector2 = target.global_position + Vector2(0.0, -14.0)
	if her_centre.distance_to(global_position) <= blast_radius:
		target.take_damage(damage, global_position)


func _on_animation_finished() -> void:
	if _sprite.animation == &"explode":
		queue_free()

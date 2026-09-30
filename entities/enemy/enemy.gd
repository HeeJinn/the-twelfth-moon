class_name Enemy
extends Damageable
## A monster that walks back and forth, turning at walls and ledges, and
## hurts Mariane on contact. When she comes within `attack_reach` it stops,
## turns to her and plays its "attack" animation, which can throw a
## projectile (the goblin's bomb, the skeleton's sword, the eye's spit)
## and/or burst around it (the mushroom's spores). Every attack has a
## wind-up first, with a "!" over its head, so there's time to react.
## A sword hit interrupts an attack. Dies from sword hits or a stomp.
## Flying monsters (`flies`) ignore gravity and ledges and bob in the air.
##
## Scene: Enemy (CharacterBody2D, origin at the feet; layer 8, mask 1+2)
##   %AnimatedSprite2D  animations: walk, attack (art faces right)
##   CollisionShape2D
##   %LedgeCheck  RayCast2D just ahead of the feet, pointing down (mask 1+2)
##   %Hitbox      ShapeCast2D, same shape as the body, target_position (0, 0),
##                enabled off, mask 4 (player)

## Seconds the enemy stops walking after being hit.
const STUN_TIME: float = 0.35
## Horizontal knockback speed when hit.
const KNOCKBACK_SPEED: float = 110.0
const DEATH_PUFF: SpriteFrames = preload("res://entities/effects/dust_puff_frames.tres")
const ALERT: SpriteFrames = preload("res://entities/effects/alert_frames.tres")
## The "!" is white in the pack; warm red reads on light skies and dark caves.
const ALERT_COLOR: Color = Color(1.0, 0.42, 0.32)
## How far a flier bobs up and down, and how long one bob takes.
const BOB_HEIGHT: float = 3.0
const BOB_TIME: float = 1.4
## The cries it makes (see voice_bank), loaded when it appears.
const CRY_GROUPS: Array[StringName] = [&"hurt", &"death"]

@export var speed: float = 30.0
@export var damage: int = 1
@export var max_health: int = 2
## The player's feet must be at least this far above the enemy's feet to
## count as a stomp. About half the enemy's height works well.
@export var stomp_height: float = 14.0
@export_enum("Left:-1", "Right:1") var start_direction: int = -1
## The body sits this many px left of the frame centre when facing right.
@export var sprite_offset: Vector2 = Vector2.ZERO
## How far (px) it wanders from where it started before turning back, so
## monsters stay in their part of the level. Zero = no limit.
@export var patrol_distance: float = 0.0
## Flies: no gravity, no turning at ledges, a gentle bob.
@export var flies: bool = false
## Height of the "!" shown while it winds up an attack, above its feet.
@export var alert_height: float = 46.0

@export_group("Voice")
## The voice bank (see Audio) it cries out with when hurt and when it falls,
## pitched by voice_pitch. Empty means it makes no sound.
@export var voice_bank: StringName = &""
@export var voice_pitch: float = 1.0

@export_group("Attack")
## How far away (x) and how far up or down (y) Mariane can be for it to
## attack. Zero means it never attacks.
@export var attack_reach: Vector2 = Vector2.ZERO
@export var attack_cooldown: float = 2.5
## Frame of "attack" when the projectile leaves its hand.
@export var release_frame: int = 0
## Thrown at release_frame toward Mariane (needs a launch(target) method).
@export var projectile_scene: PackedScene
## Where the projectile starts, relative to the feet, when facing right.
@export var projectile_offset: Vector2 = Vector2.ZERO
## Frames of "attack" that hurt Mariane within burst_radius of its body.
@export var burst_frames: PackedInt32Array = PackedInt32Array()
@export var burst_radius: float = 0.0

var _direction: float = -1.0
var _home_x: float = 0.0
var _health: int = 0
var _stun_timer: float = 0.0
var _cooldown: float = 1.0
var _is_dead: bool = false
var _attacking: bool = false
var _released: bool = false
var _burst_landed: bool = false
var _alert: AnimatedSprite2D

@onready var _sprite: AnimatedSprite2D = %AnimatedSprite2D
@onready var _ledge_check: RayCast2D = %LedgeCheck
@onready var _hitbox: ShapeCast2D = %Hitbox


func _ready() -> void:
	_health = max_health
	_home_x = global_position.x
	_direction = float(start_direction)
	_sprite.animation_finished.connect(_on_animation_finished)
	if not voice_bank.is_empty():
		Audio.preload_voice(voice_bank, CRY_GROUPS)
	_face_direction()
	_play(&"walk")
	_alert = AnimatedSprite2D.new()
	_alert.sprite_frames = ALERT
	_alert.position = Vector2(0.0, -alert_height)
	_alert.modulate = ALERT_COLOR
	_alert.z_index = 5
	_alert.hide()
	add_child(_alert)
	if flies:
		var base_y: float = _sprite.offset.y
		var bob: Tween = create_tween().set_loops()
		bob.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(_sprite, "offset:y", base_y - BOB_HEIGHT, BOB_TIME / 2.0)
		bob.tween_property(_sprite, "offset:y", base_y, BOB_TIME / 2.0)


func _physics_process(delta: float) -> void:
	if not flies and not is_on_floor():
		velocity += get_gravity() * delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _attacking:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		_update_attack()
	elif _stun_timer > 0.0:
		_stun_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, KNOCKBACK_SPEED * 4.0 * delta)
	else:
		velocity.x = _direction * speed
		var target: Player = _target_in_reach()
		if target != null:
			_start_attack(target)
	move_and_slide()

	var at_ledge: bool = not flies and not _ledge_check.is_colliding()
	var turning: bool = is_on_wall() or at_ledge or _past_patrol_edge()
	if not _attacking and _stun_timer <= 0.0 and (is_on_floor() or flies) and turning:
		_direction = -_direction
		_face_direction()
	_check_player_contact()


## Called by the player's sword.
func take_hit(amount: int, source_position: Vector2) -> void:
	if _is_dead:
		return
	_health -= amount
	if _health <= 0:
		die()
		return
	_cry(&"hurt")
	if _attacking:
		_attacking = false
		_cooldown = attack_cooldown * 0.5
		_alert.hide()
		_play(&"walk")
	_stun_timer = STUN_TIME
	var away: float = signf(global_position.x - source_position.x)
	velocity.x = (away if away != 0.0 else 1.0) * KNOCKBACK_SPEED
	var tween: Tween = create_tween()
	_sprite.modulate = Color(1.0, 0.45, 0.45)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.25)


func die() -> void:
	if _is_dead:
		return
	_is_dead = true
	_cry(&"death")
	_alert.hide()
	set_physics_process(false)
	set_deferred("collision_layer", 0)
	var puff: AnimatedSprite2D = AnimatedSprite2D.new()
	puff.sprite_frames = DEATH_PUFF
	puff.z_index = 2
	get_parent().add_child(puff)
	puff.global_position = global_position + Vector2(0.0, -14.0)
	puff.play("play")
	puff.animation_finished.connect(puff.queue_free)
	var tween: Tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_sprite.modulate = Color(1.0, 0.45, 0.45)
	tween.tween_property(_sprite, "scale:y", 0.2, 0.12)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)


func _cry(group: StringName) -> void:
	if not voice_bank.is_empty():
		Audio.voice(voice_bank, group, 1.0, voice_pitch)


## Walked too far from home in the direction it's heading?
func _past_patrol_edge() -> bool:
	if patrol_distance <= 0.0:
		return false
	return (global_position.x - _home_x) * _direction > patrol_distance


## Mariane, if she's close enough to attack and it's ready to.
func _target_in_reach() -> Player:
	if attack_reach == Vector2.ZERO or _cooldown > 0.0 or not (is_on_floor() or flies):
		return null
	var target: Player = get_tree().get_first_node_in_group(&"player") as Player
	if target == null or target.is_dead():
		return null
	var offset: Vector2 = target.global_position - global_position
	if absf(offset.x) > attack_reach.x or absf(offset.y) > attack_reach.y:
		return null
	return target


func _start_attack(target: Player) -> void:
	_attacking = true
	_released = false
	_burst_landed = false
	var toward: float = signf(target.global_position.x - global_position.x)
	if toward != 0.0:
		_direction = toward
		_face_direction()
	_play(&"attack")
	_alert.show()
	_alert.play(&"play")


func _update_attack() -> void:
	var frame: int = _sprite.frame
	if projectile_scene != null and not _released and frame >= release_frame:
		_released = true
		_alert.hide()
		_throw()
	if burst_radius > 0.0 and not _burst_landed and frame in burst_frames:
		var target: Player = get_tree().get_first_node_in_group(&"player") as Player
		var centre: Vector2 = global_position + Vector2(0.0, -14.0)
		var her_centre: Vector2 = target.global_position + Vector2(0.0, -14.0) if target else centre
		_alert.hide()
		if target != null and her_centre.distance_to(centre) <= burst_radius:
			_burst_landed = true
			target.take_damage(damage, global_position)


func _throw() -> void:
	var target: Player = get_tree().get_first_node_in_group(&"player") as Player
	if target == null:
		return
	var projectile: Node2D = projectile_scene.instantiate() as Node2D
	get_parent().add_child(projectile)
	projectile.global_position = global_position + Vector2(
			projectile_offset.x * _direction, projectile_offset.y)
	projectile.call(&"launch", target.global_position)


func _face_direction() -> void:
	# The art faces right. Flipping mirrors the texture inside its rect, so
	# the body offset is mirrored too.
	_sprite.flip_h = _direction < 0.0
	_sprite.offset = Vector2(sprite_offset.x * _direction, sprite_offset.y)
	_ledge_check.position.x = absf(_ledge_check.position.x) * _direction
	# The ray moved; refresh it now so the next frame doesn't turn again.
	_ledge_check.force_raycast_update()


func _play(animation: StringName) -> void:
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(animation):
		_sprite.play(animation)


func _on_animation_finished() -> void:
	if _sprite.animation == &"attack" and _attacking:
		_attacking = false
		_alert.hide()
		_cooldown = attack_cooldown
		_play(&"walk")


# An immediate shape query instead of an Area2D: Area2D overlap lists arrive
# about two physics frames after contact, and by then a fast-falling player
# is already on the ground and the stomp reads as a side hit. Polling every
# frame also repeats contact damage once the player's invulnerability ends.
func _check_player_contact() -> void:
	_hitbox.force_shapecast_update()
	for i: int in _hitbox.get_collision_count():
		var player: Player = _hitbox.get_collider(i) as Player
		if player == null or player.is_dead():
			continue
		# Judge by where the feet were before the player's latest move, so the
		# result doesn't depend on whether the player moved first this frame.
		var previous_feet_y: float = player.global_position.y - player.get_position_delta().y
		var is_stomp: bool = (
				player.velocity.y > 0.0
				and previous_feet_y < global_position.y - stomp_height
		)
		if is_stomp:
			player.bounce()
			die()
			return
		player.take_damage(damage, global_position)

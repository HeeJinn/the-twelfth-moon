class_name Critter
extends CharacterBody2D
## A small animal that makes the road feel lived in. Sheep graze, amble
## about and doze off; a snake slithers to and fro; a frog sits, flicks its
## tongue and hops. They never hurt anyone and nothing hurts them. When
## Mariane comes running close, they shy away from her.
##
## They obey gravity like everything else: one placed in mid-air (or over a
## gap) falls and lands, ground and walls stop it, and it will not stroll off
## a ledge on purpose (`avoid_ledges`). One that ends up in a dip stays
## there. A critter that falls out of the world is removed.
##
## Scene: Critter (CharacterBody2D, origin at the feet, collision_layer 0 so
## nothing bumps into it, collision_mask 3 = world + platforms)
##   %Sprite          AnimatedSprite2D: `idle_animation`, `move_animation`,
##                    and the optional `rest_animation` (a long loop, like
##                    sleeping) and `fidget_animation` (a short one, like a
##                    tongue flick)
##   CollisionShape2D a small box standing on the origin (bottom edge at y = 0)

enum Mood { IDLE, MOVING, RESTING, FIDGETING }

## A drop of up to this many px is a slope, more is a ledge it won't step off.
const LEDGE_DROP: float = 12.0
## How far ahead of its feet a walking critter looks for the ground, px.
const LEDGE_LOOKAHEAD: float = 8.0
## Terminal velocity of a fall, px/s.
const MAX_FALL_SPEED: float = 600.0
## Fallen this far below where it was placed: out of the world, remove it.
const OUT_OF_WORLD: float = 1200.0

@export var art_faces_left: bool = false
## Walking speed, px/s. With `hops`, the distance of one hop instead.
@export var speed: float = 12.0
## How far from home it wanders, px.
@export var wander_distance: float = 40.0
## Moves in hops (one "move" animation = one hop in a little arc).
@export var hops: bool = false
@export var hop_height: float = 10.0
## Seconds it stands still between strolls.
@export var idle_time: Vector2 = Vector2(1.5, 4.0)
## Chance, each time it stops, to rest (sleep) or fidget instead.
@export_range(0.0, 1.0) var rest_chance: float = 0.0
@export var rest_time: Vector2 = Vector2(5.0, 10.0)
@export_range(0.0, 1.0) var fidget_chance: float = 0.0
@export var idle_animation: StringName = &"idle"
@export var move_animation: StringName = &"walk"
@export var rest_animation: StringName = &""
@export var fidget_animation: StringName = &""
## Mariane closer than this and running: it hurries away from her.
@export var shy_distance: float = 36.0
## Stops at the edge of a drop instead of walking off it.
@export var avoid_ledges: bool = true

var _mood: Mood = Mood.IDLE
var _home_x: float = 0.0
var _spawn_y: float = 0.0
var _target_x: float = 0.0
var _timer: float = 0.0
var _speed_scale: float = 1.0
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
var _hop_in_air: bool = false
var _hop_hit_wall: bool = false

@onready var _sprite: AnimatedSprite2D = %Sprite


func _ready() -> void:
	_home_x = position.x
	_spawn_y = position.y
	_sprite.animation_finished.connect(_on_animation_finished)
	_face(1.0 if randf() < 0.5 else -1.0)
	_idle(randf_range(0.0, idle_time.y))


func _physics_process(delta: float) -> void:
	_check_for_mariane()
	match _mood:
		Mood.IDLE, Mood.RESTING:
			_timer -= delta
			if _timer <= 0.0 and is_on_floor():
				_stroll()
		Mood.MOVING:
			if not hops:
				_walk(delta)
	if _mood != Mood.MOVING:
		velocity.x = 0.0
	velocity.y = minf(velocity.y + _gravity * delta, MAX_FALL_SPEED)
	move_and_slide()
	if hops and _mood == Mood.MOVING:
		_track_hop()
	if position.y > _spawn_y + OUT_OF_WORLD:
		queue_free()


## Picks a spot near home and walks (or hops) there.
func _stroll() -> void:
	_target_x = _home_x + randf_range(-wander_distance, wander_distance)
	if absf(_target_x - position.x) < 4.0:
		_idle(randf_range(idle_time.x, idle_time.y))
		return
	if not _move_toward(_target_x, 1.0):
		_idle(randf_range(idle_time.x, idle_time.y))


## Starts walking (or hopping) toward `x`. False, and nothing happens, when a
## wall or a drop is in the way.
func _move_toward(x: float, speed_scale: float) -> bool:
	var direction: float = signf(x - position.x)
	if _blocked(direction, speed * speed_scale if hops else LEDGE_LOOKAHEAD):
		return false
	_mood = Mood.MOVING
	_target_x = x
	_speed_scale = speed_scale
	_face(direction)
	_sprite.speed_scale = speed_scale
	_sprite.play(move_animation)
	if hops:
		_start_hop()
	return true


## Walks toward the target, and stops at a wall or the edge of a drop.
func _walk(delta: float) -> void:
	var to_go: float = _target_x - position.x
	var direction: float = signf(to_go)
	if not is_on_floor():
		velocity.x = 0.0
		return
	if absf(to_go) < 1.0 or _blocked(direction, LEDGE_LOOKAHEAD):
		velocity.x = 0.0
		_stop()
		return
	velocity.x = direction * minf(speed * _speed_scale, absf(to_go) / delta)


## One hop: up and forward `speed` px, while the hop animation plays.
func _start_hop() -> void:
	var direction: float = signf(_target_x - position.x)
	var take_off: float = sqrt(2.0 * _gravity * hop_height)
	var air_time: float = 2.0 * take_off / _gravity
	velocity = Vector2(direction * speed * _speed_scale / air_time, -take_off)
	_hop_in_air = false
	_hop_hit_wall = false
	# Stretch the hop animation over the time it spends in the air.
	var frames: SpriteFrames = _sprite.sprite_frames
	var animation_seconds: float = frames.get_frame_count(move_animation) \
			/ frames.get_animation_speed(move_animation)
	_sprite.speed_scale = animation_seconds / air_time
	_sprite.frame = 0


## Notices when a hop has landed, then hops again or stops.
func _track_hop() -> void:
	if is_on_wall():
		_hop_hit_wall = true
	if not is_on_floor():
		_hop_in_air = true
		return
	if not _hop_in_air:
		return
	_hop_in_air = false
	velocity.x = 0.0
	var direction: float = signf(_target_x - position.x)
	var far_to_go: bool = absf(_target_x - position.x) > speed * 0.5
	if far_to_go and not _hop_hit_wall and not _blocked(direction, speed * _speed_scale):
		_sprite.play(move_animation)
		_start_hop()
	else:
		_stop()


## True when a step of `distance` px toward `direction` would run into a wall,
## or (with `avoid_ledges`) off the edge of a drop.
func _blocked(direction: float, distance: float) -> bool:
	if direction == 0.0:
		return true
	if test_move(global_transform, Vector2(direction * 2.0, 0.0)):
		return true
	return avoid_ledges and not _ground_ahead(direction * distance)


## Whether there is ground within `LEDGE_DROP` below the feet, `offset_x` px
## away. Casts a ray from just above the feet, so a one-way plank counts too.
func _ground_ahead(offset_x: float) -> bool:
	var from: Vector2 = global_position + Vector2(offset_x, -2.0)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			from, from + Vector2(0.0, 2.0 + LEDGE_DROP), collision_mask)
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _stop() -> void:
	_sprite.speed_scale = 1.0
	var roll: float = randf()
	if roll < rest_chance and rest_animation != &"":
		_mood = Mood.RESTING
		_timer = randf_range(rest_time.x, rest_time.y)
		_sprite.play(rest_animation)
	elif roll < rest_chance + fidget_chance and fidget_animation != &"":
		_mood = Mood.FIDGETING
		_sprite.play(fidget_animation)
	else:
		_idle(randf_range(idle_time.x, idle_time.y))


func _idle(seconds: float) -> void:
	_mood = Mood.IDLE
	_timer = seconds
	_sprite.speed_scale = 1.0
	_sprite.play(idle_animation)


## Mariane running close by startles it (a sleeper wakes up first).
func _check_for_mariane() -> void:
	if not is_on_floor():
		return
	if _mood == Mood.MOVING and _speed_scale > 1.0:
		return
	var mariane: Player = get_tree().get_first_node_in_group(&"player") as Player
	if mariane == null:
		return
	var away: float = global_position.x - mariane.global_position.x
	var running: bool = absf(mariane.velocity.x) > 60.0
	if absf(away) > shy_distance or not running:
		return
	if absf(mariane.global_position.y - global_position.y) > 24.0:
		return
	var flee_to: float = position.x + signf(away if away != 0.0 else 1.0) * wander_distance
	flee_to = clampf(flee_to, _home_x - wander_distance * 1.5, _home_x + wander_distance * 1.5)
	if absf(flee_to - position.x) > 4.0:
		_move_toward(flee_to, 2.0)


func _face(direction: float) -> void:
	if direction != 0.0:
		_sprite.flip_h = (direction < 0.0) != art_faces_left


func _on_animation_finished() -> void:
	if _sprite.animation == fidget_animation:
		_idle(randf_range(idle_time.x, idle_time.y))

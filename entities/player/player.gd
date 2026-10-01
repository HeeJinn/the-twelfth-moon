class_name Player
extends CharacterBody2D
## Mariane, the heroine (the Warrior Woman from Dreamir's Characters Pack).
##
## Her moves are a node-based state machine (%StateMachine, one script per
## state in states/). This script holds what the states share: stats,
## health and moonlight, input with buffering and locks, gravity and
## steering, her body shape, the senses (walls, ledges, ladders), animation,
## sword hits and the spells. It also holds the public API other scenes use
## (take_damage, respawn, rest...).
##
## Each physics frame: update timers, let the current state steer,
## move_and_slide(), then ask the state whether to switch.
##
## Death never ends the chapter: she emits `died`, and the level that owns
## her calls respawn() at the last campfire, where she gets back up.
##
## Moonlight: the moons beside her hearts. A Moon Spark spends one; they
## come back slowly, and all at once when she rests at a campfire.
##
## Story moments: her controls lock while a conversation is open and while a
## cutscene holds them (lock_controls/unlock_controls; locks stack). A
## cutscene can walk her somewhere with `await player.walk_to(x)`, and a
## chapter can start with her asleep (fall_asleep); she gets up when the
## first conversation ends.
##
## Scene: Player (CharacterBody2D, origin at the feet, group "player")
##   %AnimatedSprite2D   art faces right, feet at y 48 and body at x 44 of
##                       each 80x64 frame
##   %StandShape, %LowShape   CollisionShape2D, one enabled at a time
##   %StandCheck         ShapeCast2D the size of StandShape: room to stand up?
##   %AttackHitbox, %DashAttackHitbox, %LowAttackHitbox, %SlashHitbox
##                       ShapeCast2D, mask 8 (enemies)
##   %WallRay, %HeadRay, %LedgeTopRay   RayCast2D, mask 1 (world)
##   %LadderDetector, %LadderBelow      Area2D, mask 128 (climbables)
##   %Camera2D
##   %StateMachine > Idle, Run, Crouch, CrouchAttack, Slide, Jump, Fall,
##                   WallSlide, LedgeHang, LedgeClimb, Climb, Dash,
##                   DashAttack, Attack, Charge, MoonSlash, Cast, Guard,
##                   Rest, Hurt, Dead, Asleep, GetUp

## Emitted once when she dies (health reached 0 or she fell out of the map).
signal died
## Emitted when a scripted walk_to() reaches its target (or gives up).
signal arrived

## Which of her hitboxes a swing uses.
enum Reach { SWORD, LUNGE, LOW, CRESCENT }

## 1-based physics layer used by one-way platforms (see the layer table).
const PLATFORM_LAYER: int = 2
## How long platform collisions stay off when dropping through.
const DROP_THROUGH_TIME: float = 0.2
## Stomp bounce speed as a fraction of a full jump.
const STOMP_BOUNCE_RATIO: float = 0.75
## How hard a monster she walks into pushes her back, px/s.
const BUMP_SPEED: float = 90.0
const BLINK_PERIOD: float = 0.1
## Every frame is 80x64 with her feet at y 48 and her body at x 44, so the
## frame centre (40, 32) sits this far from her feet when she faces right.
const SPRITE_OFFSET: Vector2 = Vector2(-4.0, -16.0)
## Extra nudges for single animations (x mirrors with her facing): the wall
## slide pose reaches forward, so it's drawn back to keep her hand on the
## wall's face instead of inside it.
const ANIMATION_OFFSETS: Dictionary[StringName, Vector2] = {
	&"wall_slide": Vector2(-5.0, 0.0),
}
## While hanging, the ledge's top corner is this far above her feet...
const HANG_HAND_HEIGHT: float = 20.0
## ...and this far in front of her (the art's hand is at x 58, y 28).
const HANG_WALL_GAP: float = 14.0
## The ledge climb art ends this far forward and up from where it starts
## (standing on the ledge), so her body moves there when it finishes.
const CLIMB_SHIFT: Vector2 = Vector2(20.0, -20.0)
## Animations that lead straight into another when they finish.
const ANIMATION_CHAINS: Dictionary[StringName, StringName] = {
	&"up_to_fall": &"fall",
	&"ledge_grab": &"ledge_hang",
	&"guard_up": &"guard",
	&"block": &"guard",
	&"charge": &"charge_hold",
}
## How far ahead the wall and ledge rays look.
const REACH: float = 10.0
## After controls unlock, button presses are ignored this long, so the press
## that closed a conversation doesn't also make her jump or swing.
const INPUT_GRACE: float = 0.2
## A scripted walk counts as arrived within this many px of its target.
const ARRIVE_DISTANCE: float = 2.0
## A scripted walk gives up this many seconds after it should have arrived
## (e.g. blocked by a wall).
const WALK_SPARE_TIME: float = 2.0
## A spark where her sword lands, and dust when she lands from a real fall.
const HIT_SPARK: SpriteFrames = preload("res://entities/effects/hit_spark_frames.tres")
## Where moonlight lands, or her sword lands on a boss: a bigger, blue impact.
const MOON_IMPACT: SpriteFrames = preload("res://entities/effects/moon_impact_frames.tres")
const LANDING_DUST: SpriteFrames = preload("res://entities/effects/landing_dust_frames.tres")
## Seconds of falling before a landing kicks up dust (about a three-tile drop).
const DUST_FALL_TIME: float = 0.32
## Dash afterimages: how long each lingers and their tint.
const AFTERIMAGE_TIME: float = 0.25
const AFTERIMAGE_COLOR: Color = Color(0.55, 0.9, 1.0, 0.6)
## Her voice bank (see Audio) and the animations that come with a sound.
const VOICE: StringName = &"mariane"
## Everything she says, loaded when she appears so the first grunt never waits on the disk.
const VOICE_GROUPS: Array[StringName] = [
	&"grunt", &"land", &"hurt", &"death", &"shout", &"sigh", &"gasp",
]
const ANIMATION_VOICES: Dictionary[StringName, StringName] = {
	&"get_up": &"gasp",
	&"heal": &"sigh",
	&"death": &"death",
}
## Sound effects that start with an animation (assets/audio/sfx/).
const ANIMATION_EFFECTS: Dictionary[StringName, StringName] = {
	&"jump": &"jump", &"dash": &"dash", &"climb": &"climb", &"ledge_grab": &"climb",
	&"ledge_climb": &"climb", &"charge": &"charge", &"moon_slash": &"moon_slash",
	&"heal": &"heal", &"restore": &"absorb", &"get_up": &"revive",
}
## Sword swings, each with a small chance of an effort grunt.
const SWING_ANIMATIONS: Array[StringName] = [
	&"attack", &"attack_2", &"attack_3", &"air_attack", &"air_attack_2",
	&"crouch_attack", &"dash_attack",
]
## Frames of "run" and "walk" on which a foot lands (read off the art: the
## frame after both feet leave the ground in the run, the front foot's touch-down
## in the walk). Slides, dashes and crouching have their own animations and no steps.
const STEP_FRAMES: Dictionary[StringName, Array] = {
	&"run": [2, 6],
	&"walk": [1, 4],
}
## A landing is heard as a step this much louder than a normal one (dB).
const LANDING_STEP_DB: float = 3.0
const LANDING_VOICE_DB: float = -3.0
## The follow camera leads her a little in the direction she runs, and keeps
## the height of the ground she last stood on while she jumps (so a jump
## doesn't bob the view). It follows her at once when she drops below that
## ground, and looks further down while she falls fast, to show where she'll
## land. Its smoothing (on the Camera2D) eases every move.
const CAMERA_HEIGHT: float = 24.0
const CAMERA_LEAD: float = 40.0
## How fast the lead swings over when she turns, px/s.
const CAMERA_LEAD_SPEED: float = 90.0
## She may rise this far above the last ground before the view follows her up.
const CAMERA_RISE_ROOM: float = 72.0
const CAMERA_LOOK_DOWN: float = 48.0
## Falling faster than this (px/s), the view starts to look down.
const CAMERA_LOOK_DOWN_SPEED: float = 200.0
## States where she holds on to something: they count as ground for the camera.
const CAMERA_FOOTING_STATES: Array[StringName] = [&"Climb", &"LedgeHang", &"LedgeClimb", &"WallSlide"]

@export var stats: PlayerStats
## The Moon Spark she casts (Cast state).
@export var spark_scene: PackedScene
## The crescent of light the Moon Slash sends flying.
@export var moon_wave_scene: PackedScene

## Set by the level: dropping below this y kills the player.
var fall_limit_y: float = INF
## 1 = facing right, -1 = facing left. States change it with face().
var facing: float = 1.0
## The camera keeps to the height of the ground she last stood on (see CAMERA_*).
var _camera_ground_y: float = 0.0
var _camera_lead: float = 0.0
## One air dash per jump; landing, walls, ledges and ladders refill it.
var air_dash_available: bool = true
## Seconds her steering is ignored after a wall jump.
var steer_lock: float = 0.0
## Seconds she can't be hurt (dash, slide), on top of the post-hit blink.
var iframe_timer: float = 0.0
## Where the last detect_ledge() found the ledge's top corner.
var ledge_corner: Vector2 = Vector2.ZERO
## The name of the last animation that finished; states read and clear it.
var finished_animation: StringName = &""
## False while a state moves her by hand (ledge climb) instead of physics.
var uses_physics: bool = true
## True while her guard is up (the Guard state sets it).
var is_guarding: bool = false
## Set when a blow lands on her guard; the Guard state plays the block.
var blocked_hit: bool = false

var _health: int = 0
var _moonlight: int = 0
var _moonlight_timer: float = 0.0
var _input_enabled: bool = true
var _control_locks: int = 0
var _input_grace: float = 0.0
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _attack_buffer_timer: float = 0.0
var _dash_buffer_timer: float = 0.0
var _spell_buffer_timer: float = 0.0
var _dash_cooldown: float = 0.0
var _block_cooldown: float = 0.0
var _invulnerable_timer: float = 0.0
var _drop_timer: float = 0.0
var _ledge_cooldown: float = 0.0
var _rest_pending: bool = false
var _is_scripted_walking: bool = false
var _walk_target_x: float = 0.0
var _walk_timer: float = 0.0
var _ladder_top_y: float = 0.0
var _fall_time: float = 0.0

@onready var sprite: AnimatedSprite2D = %AnimatedSprite2D
@onready var _state_machine: PlayerStateMachine = %StateMachine
@onready var _stand_shape: CollisionShape2D = %StandShape
@onready var _low_shape: CollisionShape2D = %LowShape
@onready var _stand_check: ShapeCast2D = %StandCheck
@onready var _hitboxes: Dictionary[Reach, ShapeCast2D] = {
	Reach.SWORD: %AttackHitbox,
	Reach.LUNGE: %DashAttackHitbox,
	Reach.LOW: %LowAttackHitbox,
	Reach.CRESCENT: %SlashHitbox,
}
@onready var _wall_ray: RayCast2D = %WallRay
@onready var _head_ray: RayCast2D = %HeadRay
@onready var _ledge_top_ray: RayCast2D = %LedgeTopRay
@onready var _ladder_detector: Area2D = %LadderDetector
@onready var _ladder_below: Area2D = %LadderBelow
@onready var _camera: Camera2D = %Camera2D


func _ready() -> void:
	if stats == null:
		stats = PlayerStats.new()
	_health = stats.max_health
	_moonlight = stats.max_moonlight
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	sprite.frame_changed.connect(_on_sprite_frame_changed)
	Audio.preload_voice(VOICE, VOICE_GROUPS)
	EventBus.level_completed.connect(_on_level_completed)
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.dialogue_finished.connect(_on_dialogue_finished)
	EventBus.player_health_changed.emit(_health, stats.max_health)
	EventBus.player_moonlight_changed.emit(_moonlight, stats.max_moonlight)
	face(facing)
	_state_machine.setup(self)
	_camera_ground_y = global_position.y


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	# The give-up timer counts here, once a frame: states may ask for the
	# walk's direction several times a frame.
	if _is_scripted_walking:
		_walk_timer -= delta
	_state_machine.physics_update(delta)
	if uses_physics:
		move_and_slide()
	_update_camera(delta)
	if is_on_floor():
		if _fall_time >= DUST_FALL_TIME and not is_dead():
			OneShot.play(get_parent(), LANDING_DUST, global_position + Vector2(0.0, -16.0), 1)
			Audio.step(step_surface(), LANDING_STEP_DB)
			Audio.voice(VOICE, &"land", 1.0, 1.0, LANDING_VOICE_DB)
			Audio.effect(&"land")
		_fall_time = 0.0
		_coyote_timer = stats.coyote_time
		air_dash_available = true
	elif velocity.y > 0.0 and uses_physics:
		_fall_time += delta
	_track_ladder_top()
	_state_machine.check_transition()
	if global_position.y > fall_limit_y:
		die()


# --- Public API (other scenes) -------------------------------------------

## Called by hazards and enemies. Ignored while invulnerable or dead. A blow
## from the front while her guard is up does no harm.
func take_damage(amount: int, source_position: Vector2) -> void:
	if is_invulnerable() or is_dead():
		return
	if _blocks_blow_from(source_position):
		_block(source_position)
		return
	_health = maxi(_health - amount, 0)
	EventBus.player_health_changed.emit(_health, stats.max_health)
	if _health == 0:
		die()
		return
	Audio.voice(VOICE, &"hurt")
	Audio.effect(&"hurt")
	_invulnerable_timer = stats.invulnerability_time
	var away: float = signf(global_position.x - source_position.x)
	if away == 0.0:
		away = -facing
	velocity = Vector2(away * stats.knockback.x, stats.knockback.y)
	_state_machine.transition_to(&"Hurt")


## Called by a monster she walks into: a gentle push away from it, no harm.
## Repeated every frame they touch, so she can't walk through it.
func bump(source_position: Vector2) -> void:
	if is_dead() or not uses_physics:
		return
	var away: float = signf(global_position.x - source_position.x)
	if away == 0.0:
		away = -facing
	velocity.x = away * maxf(absf(velocity.x), BUMP_SPEED)


## Called by an enemy that was stomped.
func bounce() -> void:
	_state_machine.transition_to(&"Jump")
	velocity.y = -stats.jump_velocity * STOMP_BOUNCE_RATIO


func die() -> void:
	if is_dead():
		return
	_state_machine.transition_to(&"Dead")


func is_dead() -> bool:
	return _state_machine.is_in(&"Dead")


## What her footsteps sound like right now: wood on planks, otherwise the
## chapter's ground (see LevelData.step_surface).
func step_surface() -> StringName:
	return Audio.surface_at(global_position.x, _is_on_platform())


## Name of her current state ("Idle", "Slide"...), for tests and debugging.
func state_name() -> StringName:
	return StringName(_state_machine.current.name)


func health() -> int:
	return _health


func heal_full() -> void:
	if is_dead():
		return
	_health = stats.max_health
	EventBus.player_health_changed.emit(_health, stats.max_health)


## Called when she lights a campfire: hearts and moons refill at once, and
## she stops to warm herself (HPRecovery) and gather moonlight (MPRecovery)
## as soon as she's standing on the ground.
func rest() -> void:
	heal_full()
	refill_moonlight()
	_rest_pending = true


## True once after rest() (the Rest state takes it when she can stop).
func take_rest_request() -> bool:
	var pending: bool = _rest_pending
	_rest_pending = false
	return pending


## Brings her back at `at` (feet position) with full health. With
## `wake_up`, she's lying there and gets up (after dying).
func respawn(at: Vector2, wake_up: bool = false) -> void:
	global_position = at
	velocity = Vector2.ZERO
	_health = stats.max_health
	_input_enabled = true
	_is_scripted_walking = false
	_rest_pending = false
	_fall_time = 0.0
	_invulnerable_timer = stats.invulnerability_time
	uses_physics = true
	_state_machine.transition_to(&"GetUp" if wake_up else &"Idle", true)
	_camera_ground_y = global_position.y
	_update_camera(0.0)
	reset_physics_interpolation()
	_camera.reset_smoothing()
	EventBus.player_health_changed.emit(_health, stats.max_health)
	refill_moonlight()


## Lays her down asleep. She gets up when the next conversation ends.
func fall_asleep() -> void:
	_state_machine.transition_to(&"Asleep", true)


func is_asleep() -> bool:
	return _state_machine.is_in(&"Asleep")


## Stops reading the player's input until a matching unlock_controls().
func lock_controls() -> void:
	_control_locks += 1


func unlock_controls() -> void:
	_control_locks = maxi(_control_locks - 1, 0)
	if _control_locks == 0:
		_input_grace = INPUT_GRACE
		_jump_buffer_timer = 0.0
		_attack_buffer_timer = 0.0
		_dash_buffer_timer = 0.0
		_spell_buffer_timer = 0.0


## Walks her to `target_x` even while controls are locked. Await it.
func walk_to(target_x: float) -> void:
	if absf(target_x - global_position.x) <= ARRIVE_DISTANCE:
		return
	_walk_target_x = target_x
	_walk_timer = absf(target_x - global_position.x) / stats.walk_speed + WALK_SPARE_TIME
	_is_scripted_walking = true
	await arrived


func is_walking_scripted() -> bool:
	return _is_scripted_walking


## Turns her to face left (negative) or right (positive).
func face(direction: float) -> void:
	if direction == 0.0:
		return
	facing = signf(direction)
	sprite.flip_h = facing < 0.0
	_apply_sprite_offset()


## Her follow camera, so a cutscene can start its own camera from the same view.
func get_camera() -> Camera2D:
	return _camera


## Where the follow camera aims, relative to her: a lead toward where she runs,
## and the height of her last ground (see the CAMERA_* constants).
func _update_camera(delta: float) -> void:
	if is_dead():
		return
	if is_on_floor() or CAMERA_FOOTING_STATES.any(_state_machine.is_in):
		_camera_ground_y = global_position.y
	var target_y: float = _camera_ground_y
	if global_position.y > _camera_ground_y:
		target_y = global_position.y
		if velocity.y > CAMERA_LOOK_DOWN_SPEED:
			target_y += minf((velocity.y - CAMERA_LOOK_DOWN_SPEED) / 2.0, CAMERA_LOOK_DOWN)
	elif global_position.y < _camera_ground_y - CAMERA_RISE_ROOM:
		target_y = global_position.y + CAMERA_RISE_ROOM
	if absf(velocity.x) > 30.0:
		_camera_lead = move_toward(_camera_lead, facing * CAMERA_LEAD, CAMERA_LEAD_SPEED * delta)
	_camera.position = Vector2(_camera_lead, target_y - global_position.y - CAMERA_HEIGHT)


## Called by the level loader so the camera never shows outside the map.
func set_camera_limits(bounds: Rect2) -> void:
	_camera.limit_left = floori(bounds.position.x)
	_camera.limit_top = floori(bounds.position.y)
	_camera.limit_right = ceili(bounds.end.x)
	_camera.limit_bottom = ceili(bounds.end.y)
	_camera.reset_smoothing()


# --- Moonlight ---------------------------------------------------------------

func moonlight() -> int:
	return _moonlight


## Spends one moon. Returns false (and spends nothing) when there's none.
func spend_moonlight() -> bool:
	if _moonlight <= 0:
		return false
	if _moonlight == stats.max_moonlight:
		_moonlight_timer = stats.moonlight_regen_time
	_moonlight -= 1
	EventBus.player_moonlight_changed.emit(_moonlight, stats.max_moonlight)
	return true


func refill_moonlight() -> void:
	_moonlight = stats.max_moonlight
	EventBus.player_moonlight_changed.emit(_moonlight, stats.max_moonlight)


# --- Input, for states ------------------------------------------------------

## Left/right input, -1..1. Follows a scripted walk when one is running.
func input_direction() -> float:
	if _is_scripted_walking:
		return _get_scripted_direction()
	if not _is_controllable():
		return 0.0
	return Input.get_axis("move_left", "move_right")


func is_down_held() -> bool:
	return _is_controllable() and Input.is_action_pressed("move_down")


func is_up_held() -> bool:
	return _is_controllable() and Input.is_action_pressed("move_up")


func is_attack_held() -> bool:
	return _is_controllable() and Input.is_action_pressed("attack")


## Up/down input for climbing: -1 up, 1 down.
func input_vertical() -> float:
	if not _is_controllable():
		return 0.0
	return Input.get_axis("move_up", "move_down")


func wants_jump() -> bool:
	return _jump_buffer_timer > 0.0


func consume_jump() -> void:
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0


func can_coyote_jump() -> bool:
	return _coyote_timer > 0.0


func wants_attack() -> bool:
	return _attack_buffer_timer > 0.0


func consume_attack() -> void:
	_attack_buffer_timer = 0.0


## A dash is wanted, off cooldown, and allowed here (air dashes are limited).
func wants_dash() -> bool:
	if _dash_buffer_timer <= 0.0 or _dash_cooldown > 0.0:
		return false
	return is_on_floor() or air_dash_available


func consume_dash() -> void:
	_dash_buffer_timer = 0.0
	_dash_cooldown = stats.dash_cooldown
	if not is_on_floor():
		air_dash_available = false


## Block held, on the ground.
func wants_guard() -> bool:
	return _is_controllable() and Input.is_action_pressed("block") and is_on_floor()


## Spell pressed, on the ground, with a moon to spend.
func wants_spell() -> bool:
	return _spell_buffer_timer > 0.0 and _moonlight > 0 and is_on_floor()


func consume_spell() -> void:
	_spell_buffer_timer = 0.0


## Up on a ladder, or down on the ground right above one.
func wants_climb() -> bool:
	if not _is_controllable():
		return false
	if is_up_held() and on_ladder():
		return true
	return is_down_held() and is_on_floor() and ladder_continues_below()


## Turns her toward the input direction (used by states that allow turning).
func turn_toward_input() -> void:
	face(input_direction())


# --- Movement, for states -------------------------------------------------

func apply_gravity(delta: float, max_speed: float = -1.0) -> void:
	var limit: float = stats.max_fall_speed if max_speed < 0.0 else max_speed
	var gravity: float = stats.jump_gravity if velocity.y < 0.0 else stats.fall_gravity
	velocity.y = minf(velocity.y + gravity * delta, limit)


func apply_horizontal(direction: float, accel: float, decel: float, delta: float) -> void:
	if steer_lock > 0.0:
		return
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * stats.max_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)


## Variable jump height: while rising without jump held, cap the upward
## speed. Checking "held" instead of "just released" also catches taps
## shorter than one physics frame.
func apply_jump_cut() -> void:
	var cut_speed: float = -stats.jump_velocity * stats.jump_cut
	var held: bool = _is_controllable() and Input.is_action_pressed("jump")
	if velocity.y < cut_speed and not held:
		velocity.y = cut_speed


## Down + jump on a one-way platform drops through it. Returns true if so.
func try_drop_through() -> bool:
	if not (is_on_floor() and _is_on_platform()):
		return false
	consume_jump()
	set_platforms_solid(false)
	_drop_timer = DROP_THROUGH_TIME
	return true


func set_platforms_solid(solid: bool) -> void:
	set_collision_mask_value(PLATFORM_LAYER, solid)


# --- Body shape and senses, for states --------------------------------------

## Low body for crouching and sliding (fits one-tile gaps).
func set_low_body(low: bool) -> void:
	_stand_shape.disabled = low
	_low_shape.disabled = not low


## Is there room to stand up here?
func can_stand() -> bool:
	_stand_check.force_shapecast_update()
	return not _stand_check.is_colliding()


func is_invulnerable() -> bool:
	return _invulnerable_timer > 0.0 or iframe_timer > 0.0


## Is there a wall right in front of her, in `direction`, at chest height?
func wall_ahead(direction: float) -> bool:
	if direction == 0.0:
		return false
	_wall_ray.target_position = Vector2(direction * REACH, 0.0)
	_wall_ray.force_raycast_update()
	return _wall_ray.is_colliding()


## Pressing into a wall while in the air?
func is_pressing_into_wall() -> bool:
	var direction: float = input_direction()
	return direction != 0.0 and wall_ahead(direction)


## Looks for a ledge top at hand height in front of her while she falls
## toward it. Fills ledge_corner and returns true when there is one.
func detect_ledge() -> bool:
	if _ledge_cooldown > 0.0 or velocity.y < 0.0 or is_down_held():
		return false
	var direction: float = input_direction()
	if direction == 0.0 or not wall_ahead(direction):
		return false
	_head_ray.target_position = Vector2(direction * REACH, 0.0)
	_head_ray.force_raycast_update()
	if _head_ray.is_colliding():
		return false  # The wall goes on above her hands: no ledge here.
	_ledge_top_ray.position.x = direction * REACH
	_ledge_top_ray.force_raycast_update()
	if not _ledge_top_ray.is_colliding():
		return false
	var wall_x: float = _wall_ray.get_collision_point().x
	ledge_corner = Vector2(wall_x, _ledge_top_ray.get_collision_point().y)
	face(direction)
	return true


## Where her feet go while hanging from ledge_corner.
func hang_position() -> Vector2:
	return Vector2(ledge_corner.x - facing * HANG_WALL_GAP, ledge_corner.y + HANG_HAND_HEIGHT)


## Where she stands once she has climbed up onto ledge_corner.
func climbed_position() -> Vector2:
	return hang_position() + Vector2(CLIMB_SHIFT.x * facing, CLIMB_SHIFT.y)


## Stops ledge grabs for a moment, so letting go doesn't grab again.
func let_go_of_ledge() -> void:
	_ledge_cooldown = stats.ledge_regrab_delay


func on_ladder() -> bool:
	return _ladder_detector.has_overlapping_areas()


## Is there more vine just under her feet?
func ladder_continues_below() -> bool:
	return _ladder_below.has_overlapping_areas()


## Centre x of the ladder she is on (or right above).
func ladder_x() -> float:
	var areas: Array[Area2D] = _ladder_detector.get_overlapping_areas()
	if areas.is_empty():
		areas = _ladder_below.get_overlapping_areas()
	return areas[0].global_position.x if not areas.is_empty() else global_position.x


## Top of the ladder she was last on (feet height to step off at the top).
func ladder_top_y() -> float:
	return _ladder_top_y


# --- Visuals and combat, for states -----------------------------------------

func play_animation(animation_name: StringName) -> void:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)
		finished_animation = &""
		_apply_sprite_offset()
		if ANIMATION_VOICES.has(animation_name):
			Audio.voice(VOICE, ANIMATION_VOICES[animation_name])
		elif animation_name in SWING_ANIMATIONS:
			Audio.voice(VOICE, &"grunt", stats.swing_grunt_chance)
			Audio.effect(&"swing")
		if ANIMATION_EFFECTS.has(animation_name):
			Audio.effect(ANIMATION_EFFECTS[animation_name])


## Hits every enemy within `reach` once per swing (tracked in `hits`). The
## Moon Slash's crescent is moonlight, which no shield stops.
func hit_enemies(reach: Reach, damage: int, hits: Array[Damageable]) -> void:
	var hitbox: ShapeCast2D = _hitboxes[reach]
	hitbox.position.x = absf(hitbox.position.x) * facing
	hitbox.force_shapecast_update()
	for i: int in hitbox.get_collision_count():
		var enemy: Damageable = hitbox.get_collider(i) as Damageable
		if enemy == null or enemy in hits:
			continue
		hits.append(enemy)
		var blocked: bool = reach != Reach.CRESCENT and enemy.is_guarding_against(global_position)
		if not blocked:
			var between: Vector2 = (global_position + enemy.global_position) / 2.0
			var heavy: bool = reach == Reach.CRESCENT or not enemy is Enemy
			OneShot.play(get_parent(), MOON_IMPACT if heavy else HIT_SPARK,
					between + Vector2(0.0, -16.0), 5)
			Audio.effect(&"hit")
		else:
			Audio.effect(&"block")
		if reach == Reach.CRESCENT:
			enemy.take_moon_hit(damage, global_position)
		else:
			enemy.take_hit(damage, global_position)


## Launches `scene` (a Moon Spark or a Moon Wave) from `offset` (relative to
## her feet, facing right) in the direction she faces.
func launch(scene: PackedScene, offset: Vector2) -> void:
	var projectile: Node2D = scene.instantiate() as Node2D
	get_parent().add_child(projectile)
	projectile.global_position = global_position + Vector2(offset.x * facing, offset.y)
	projectile.call(&"fly", facing, stats)
	Audio.voice(VOICE, &"shout")
	if scene == spark_scene:
		Audio.effect(&"spark")


## A fading copy of her current frame, left behind while she dashes.
func leave_afterimage() -> void:
	var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var ghost: Sprite2D = Sprite2D.new()
	ghost.texture = texture
	ghost.flip_h = sprite.flip_h
	ghost.offset = sprite.offset
	ghost.modulate = AFTERIMAGE_COLOR
	ghost.z_index = sprite.z_index - 1
	get_parent().add_child(ghost)
	ghost.global_position = global_position
	var tween: Tween = ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, AFTERIMAGE_TIME)
	tween.tween_callback(ghost.queue_free)


func mark_dead() -> void:
	_input_enabled = false
	sprite.modulate.a = 1.0
	died.emit()
	EventBus.player_died.emit()


# --- Internals --------------------------------------------------------------

func _update_timers(delta: float) -> void:
	_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_attack_buffer_timer = maxf(_attack_buffer_timer - delta, 0.0)
	_dash_buffer_timer = maxf(_dash_buffer_timer - delta, 0.0)
	_spell_buffer_timer = maxf(_spell_buffer_timer - delta, 0.0)
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	_block_cooldown = maxf(_block_cooldown - delta, 0.0)
	_ledge_cooldown = maxf(_ledge_cooldown - delta, 0.0)
	_input_grace = maxf(_input_grace - delta, 0.0)
	steer_lock = maxf(steer_lock - delta, 0.0)
	iframe_timer = maxf(iframe_timer - delta, 0.0)
	var reads_buttons: bool = _is_controllable() and _input_grace <= 0.0
	if reads_buttons and Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = stats.jump_buffer_time
	if reads_buttons and Input.is_action_just_pressed("attack"):
		_attack_buffer_timer = stats.attack_buffer_time
	if reads_buttons and Input.is_action_just_pressed("dash"):
		_dash_buffer_timer = stats.dash_buffer_time
	if reads_buttons and Input.is_action_just_pressed("spell"):
		_spell_buffer_timer = stats.attack_buffer_time

	if _moonlight < stats.max_moonlight and not is_dead():
		_moonlight_timer -= delta
		if _moonlight_timer <= 0.0:
			_moonlight += 1
			_moonlight_timer = stats.moonlight_regen_time
			EventBus.player_moonlight_changed.emit(_moonlight, stats.max_moonlight)

	if _drop_timer > 0.0:
		_drop_timer -= delta
		if _drop_timer <= 0.0 and not _state_machine.is_in(&"Climb"):
			set_platforms_solid(true)

	if _invulnerable_timer > 0.0:
		_invulnerable_timer = maxf(_invulnerable_timer - delta, 0.0)
		var blink_on: bool = fmod(_invulnerable_timer, BLINK_PERIOD * 2.0) > BLINK_PERIOD
		sprite.modulate.a = 0.35 if blink_on and _invulnerable_timer > 0.0 else 1.0


func _is_controllable() -> bool:
	return _input_enabled and _control_locks == 0


func _get_scripted_direction() -> float:
	var remaining: float = _walk_target_x - global_position.x
	if absf(remaining) <= ARRIVE_DISTANCE or _walk_timer <= 0.0:
		_is_scripted_walking = false
		velocity.x = 0.0
		arrived.emit()
		return 0.0
	# A calm walking pace, slowing on approach so she doesn't overshoot.
	var pace: float = stats.walk_speed / stats.max_speed
	return signf(remaining) * pace * clampf(absf(remaining) / 8.0, 0.5, 1.0)


func _apply_sprite_offset() -> void:
	var extra: Vector2 = ANIMATION_OFFSETS.get(sprite.animation, Vector2.ZERO)
	sprite.offset = Vector2((SPRITE_OFFSET.x + extra.x) * facing, SPRITE_OFFSET.y + extra.y)


## Guard up and the blow comes from in front of her (or right on top).
func _blocks_blow_from(source_position: Vector2) -> bool:
	if not is_guarding:
		return false
	var side: float = source_position.x - global_position.x
	return absf(side) < 2.0 or signf(side) == facing


func _block(source_position: Vector2) -> void:
	blocked_hit = true
	if _block_cooldown > 0.0:
		return
	_block_cooldown = stats.block_cooldown
	Audio.effect(&"block")
	var away: float = signf(global_position.x - source_position.x)
	velocity.x = (away if away != 0.0 else -facing) * stats.block_push


func _is_on_platform() -> bool:
	var platform_bit: int = 1 << (PLATFORM_LAYER - 1)
	for i: int in get_slide_collision_count():
		var collision: KinematicCollision2D = get_slide_collision(i)
		if collision.get_normal().dot(up_direction) < 0.7:
			continue  # Not a floor contact.
		var layer: int = PhysicsServer2D.body_get_collision_layer(collision.get_collider_rid())
		if layer & platform_bit:
			return true
	return false


## Remembers the top of the ladder while she overlaps it, so the Climb state
## can stand her on top when she climbs past its end.
func _track_ladder_top() -> void:
	var areas: Array[Area2D] = _ladder_detector.get_overlapping_areas()
	if areas.is_empty():
		return  # Keep the last value: that's where she stepped off.
	var top: float = INF
	for area: Area2D in areas:
		var ladder: VineLadder = area as VineLadder
		var height: float = ladder.height if ladder != null else 0.0
		top = minf(top, area.global_position.y - height)
	_ladder_top_y = top


func _on_sprite_animation_finished() -> void:
	finished_animation = sprite.animation
	if ANIMATION_CHAINS.has(sprite.animation):
		sprite.play(ANIMATION_CHAINS[sprite.animation])
		_apply_sprite_offset()


## A foot lands on the frames listed in STEP_FRAMES, while she is on the ground.
func _on_sprite_frame_changed() -> void:
	if not STEP_FRAMES.has(sprite.animation) or not is_on_floor():
		return
	if sprite.frame in STEP_FRAMES[sprite.animation]:
		Audio.step(step_surface())


func _on_level_completed() -> void:
	_input_enabled = false


func _on_dialogue_started(_dialogue_id: String) -> void:
	lock_controls()


func _on_dialogue_finished(_dialogue_id: String) -> void:
	unlock_controls()
	if is_asleep():
		_state_machine.transition_to(&"GetUp")

class_name MoonWitch
extends Damageable
## The Moon Witch, Chapter Two's mini-boss. Kept gentle for a player new to
## games: touching her never hurts, every attack is announced, and after
## each attack she stands tired for a while, which is the moment to strike.
##
## Her loop: appear at one of `spots` (away from Mariane) -> charge (a violet
## glow) -> cast (crystal spikes burst along the ground in front of her;
## every second cast, and every cast once she's hurt, also sends a slow orb
## at head height) -> tired -> vanish -> next spot. A hit makes her flinch
## and vanish early. The arena scene starts, resets and ends the fight.
##
## Scene: MoonWitch (CharacterBody2D, origin at the feet; layer 8, mask 0)
##   %AnimatedSprite2D  idle, charge, attack, hurt, death (art faces right)
##   CollisionShape2D   her body, for the sword
##   %SpikeHitbox       ShapeCast2D in front of her, mask 4 (player), disabled
##   %Glow              Sprite2D, additive, lit while she charges

## Emitted when her health runs out. She stands, beaten, until dissolve().
signal defeated

enum Phase { WAITING, APPEARING, CHARGING, CASTING, TIRED, HURT, VANISHING, DEFEATED }

const ORB_SCENE: PackedScene = preload("res://entities/boss/witch_orb.tscn")
const APPEAR_EFFECT: SpriteFrames = preload("res://entities/effects/moon_absorb_frames.tres")
## Her frames are 144x48 with the body 40 px from the left and feet at the bottom.
const SPRITE_OFFSET: Vector2 = Vector2(32.0, -24.0)
## Frames of "attack" when the crystal spikes are out.
const SPIKE_FRAMES: Array[int] = [5, 6, 7, 8]
## Frame of "attack" when the orb leaves her hand.
const ORB_FRAME: int = 2
const FADE_TIME: float = 0.35
## She won't appear closer to Mariane than this.
const SAFE_DISTANCE: float = 96.0

@export var display_name: String = "The Moon Witch"
@export var max_health: int = 6
@export var charge_time: float = 0.9
@export var tired_time: float = 1.9
@export var hurt_time: float = 0.35
@export var orb_speed: float = 75.0
## Her voice bank (see Audio).
@export var voice_bank: StringName = &"karen"

## Global positions she can appear at, set by the arena.
var spots: Array[Vector2] = []

var _target: Player
var _phase: Phase = Phase.WAITING
var _health: int = 0
var _timer: float = 0.0
var _facing: float = 1.0
var _cast_count: int = 0
var _orb_fired: bool = false
var _spikes_hit: bool = false
var _last_spot: int = -1

@onready var _sprite: AnimatedSprite2D = %AnimatedSprite2D
@onready var _spike_hitbox: ShapeCast2D = %SpikeHitbox
@onready var _glow: Sprite2D = %Glow


func _ready() -> void:
	_health = max_health
	_sprite.animation_finished.connect(_on_animation_finished)
	_glow.modulate.a = 0.0
	hide()
	collision_layer = 0


func _physics_process(delta: float) -> void:
	match _phase:
		Phase.CHARGING:
			_face_target()
			_timer -= delta
			if _timer <= 0.0:
				_start_cast()
		Phase.CASTING:
			_update_cast()
		Phase.TIRED:
			_timer -= delta
			if _timer <= 0.0:
				_vanish()
		Phase.HURT:
			_timer -= delta
			if _timer <= 0.0:
				_vanish()


## Begins the fight against `player`.
func start_fight(player: Player) -> void:
	_target = player
	_health = max_health
	_cast_count = 0
	EventBus.boss_started.emit(display_name, max_health)
	_appear()


## Makes her appear at a spot and wait, for the introduction.
func appear_at(spot: Vector2) -> void:
	global_position = spot
	Audio.effect_at(&"teleport", spot)
	_show_up()


## Back to the start (after Mariane is knocked out mid-fight).
func reset() -> void:
	_phase = Phase.WAITING
	_health = max_health
	_glow.modulate.a = 0.0
	collision_layer = 0
	hide()
	EventBus.boss_finished.emit()


func take_hit(amount: int, source_position: Vector2) -> void:
	if _phase in [Phase.WAITING, Phase.APPEARING, Phase.VANISHING, Phase.DEFEATED]:
		return
	_health = maxi(_health - amount, 0)
	EventBus.boss_health_changed.emit(_health, max_health)
	_sprite.modulate = Color(1.0, 0.5, 0.6)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.25)
	if _health == 0:
		_die()
		return
	Audio.voice(voice_bank, &"hurt")
	_facing = signf(source_position.x - global_position.x)
	_apply_facing()
	_phase = Phase.HURT
	_timer = hurt_time
	_glow.modulate.a = 0.0
	_sprite.play("hurt")


func _is_angry() -> bool:
	return _health <= max_health * 0.5


func _appear() -> void:
	global_position = _pick_spot()
	_show_up()
	await get_tree().create_timer(FADE_TIME + 0.2).timeout
	if _phase == Phase.APPEARING:
		_start_charge()


func _show_up() -> void:
	_phase = Phase.APPEARING
	show()
	modulate.a = 0.0
	collision_layer = 8
	_face_target()
	_sprite.play("idle")
	_play_effect(APPEAR_EFFECT, global_position + Vector2(0.0, -20.0))
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_TIME)


func _pick_spot() -> Vector2:
	var choices: Array[int] = []
	for i: int in spots.size():
		var far_enough: bool = (
				_target == null
				or absf(spots[i].x - _target.global_position.x) >= SAFE_DISTANCE
		)
		if i != _last_spot and far_enough:
			choices.append(i)
	if choices.is_empty():
		for i: int in spots.size():
			if i != _last_spot:
				choices.append(i)
	_last_spot = choices[randi() % choices.size()]
	return spots[_last_spot]


func _start_charge() -> void:
	_phase = Phase.CHARGING
	_timer = charge_time * (0.7 if _is_angry() else 1.0)
	_sprite.play("charge")
	create_tween().tween_property(_glow, "modulate:a", 0.9, _timer)


func _start_cast() -> void:
	_phase = Phase.CASTING
	_cast_count += 1
	_orb_fired = false
	_spikes_hit = false
	Audio.voice(voice_bank, &"shout")
	_sprite.play("attack")


func _update_cast() -> void:
	var frame: int = _sprite.frame
	var sends_orb: bool = _is_angry() or _cast_count % 2 == 0
	if frame == ORB_FRAME and sends_orb and not _orb_fired:
		_orb_fired = true
		_fire_orb()
	if frame in SPIKE_FRAMES and not _spikes_hit:
		_spike_hitbox.position.x = absf(_spike_hitbox.position.x) * _facing
		_spike_hitbox.force_shapecast_update()
		for i: int in _spike_hitbox.get_collision_count():
			var player: Player = _spike_hitbox.get_collider(i) as Player
			if player != null:
				_spikes_hit = true
				player.take_damage(1, global_position)


func _fire_orb() -> void:
	var orb: WitchOrb = ORB_SCENE.instantiate() as WitchOrb
	orb.direction = _facing
	orb.speed = orb_speed
	orb.position = global_position + Vector2(_facing * 18.0, -24.0)
	get_parent().add_child(orb)


func _start_tired() -> void:
	_phase = Phase.TIRED
	_timer = tired_time * (0.75 if _is_angry() else 1.0)
	_sprite.play("idle")
	create_tween().tween_property(_glow, "modulate:a", 0.0, 0.3)


func _vanish() -> void:
	_phase = Phase.VANISHING
	collision_layer = 0
	_glow.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	await tween.finished
	await get_tree().create_timer(0.4).timeout
	if _phase == Phase.VANISHING:
		_appear()


func _die() -> void:
	_phase = Phase.DEFEATED
	collision_layer = 0
	_glow.modulate.a = 0.0
	_sprite.play("hurt")
	Audio.voice(voice_bank, &"hurt")
	EventBus.boss_finished.emit()
	defeated.emit.call_deferred()


## Her farewell: she dissolves into light (after the arena's last words).
func dissolve() -> void:
	_sprite.play("death")
	Audio.voice(voice_bank, &"death")
	await _sprite.animation_finished
	hide()


func _face_target() -> void:
	if _target != null:
		var direction: float = signf(_target.global_position.x - global_position.x)
		if direction != 0.0:
			_facing = direction
	_apply_facing()


func _apply_facing() -> void:
	_sprite.flip_h = _facing < 0.0
	_sprite.offset = Vector2(SPRITE_OFFSET.x * _facing, SPRITE_OFFSET.y)


func _play_effect(frames: SpriteFrames, at: Vector2) -> void:
	var effect: AnimatedSprite2D = AnimatedSprite2D.new()
	effect.sprite_frames = frames
	effect.z_index = 4
	get_parent().add_child(effect)
	effect.global_position = at
	effect.play("play")
	effect.animation_finished.connect(effect.queue_free)


func _on_animation_finished() -> void:
	match _sprite.animation:
		&"attack":
			if _phase == Phase.CASTING:
				_start_tired()
		&"hurt":
			if _phase == Phase.DEFEATED:
				_sprite.play("idle")

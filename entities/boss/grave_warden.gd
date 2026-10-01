class_name GraveWarden
extends Damageable
## Kael's third lieutenant, keeper of the undercroft: Chapter Four's mini-boss.
## A caster, kept gentle for a player new to games like the others: touching
## him never hurts, and everything he does marks the ground first.
##
## His loop: DRIFTING (he walks a little, keeping his distance) -> CASTING (a
## "!", he lifts a glowing skull; marks open on the ground under her and beyond
## her, and a second later Dark-Bolts fall on them) or SUMMONING (a blob of blood
## wells up under her, then rears up as a many-legged thing) -> WEARY (he leans
## on his staff, catching his breath: the moment to strike). The bolts always
## fall on her far side from him, so stepping toward him is always safe. Two
## hits and he blinks away to the other end of the crypt. At half health the
## bolts come in threes and he summons more often. Beaten, he stands a moment
## (the arena lets him speak), then crumbles into bones when told to.
##
## Scene: GraveWarden (CharacterBody2D, origin at the feet; layer 8 in the fight)
##   %AnimatedSprite2D   96x96 frames, body at x 52, feet at y 64 (faces right)
##   CollisionShape2D    his body, for her sword
##   %Alert              AnimatedSprite2D "!" over his head, hidden

## Emitted when his health runs out. He stands, spent, until crumble().
signal defeated

enum Phase { WAITING, DRIFTING, CASTING, SUMMONING, WEARY, BLINKING, FALLEN }

const BOLT_SCENE: PackedScene = preload("res://entities/hazard/dark_bolt.tscn")
const SPAWN_SCENE: PackedScene = preload("res://entities/hazard/blood_spawn.tscn")
## Frame centre (48, 48) from his feet (52, 64) when facing right.
const SPRITE_OFFSET: Vector2 = Vector2(-4.0, -16.0)
## The cast frame when the marks open. The bolts fall a second later, just as
## he thrusts the skull down.
const MARK_FRAME: int = 9
## The summon frame when the blob wells up (as he conjures at his feet).
const CONJURE_FRAME: int = 9
## His colour while he leans on his staff, weary.
const WEARY_TINT: Color = Color(0.58, 0.56, 0.7)

@export var display_name: String = "The Grave Warden"
@export var max_health: int = 8
## His voice bank (see Audio), pitched down: a grunt as he casts, a shout as he
## summons, cries when hurt.
@export var voice_bank: StringName = &"ian"
@export var voice_pitch: float = 0.72
## Seconds he walks before each spell.
@export var drift_time: Vector2 = Vector2(1.0, 1.6)
@export var walk_speed: float = 28.0
## While drifting he heads for a spot this far from her.
@export var keep_distance: float = 130.0
## Seconds he leans on his staff after a spell (less once he's angry).
@export var weary_time: float = 2.4
## Distance between the bolts of one spell.
@export var bolt_spacing: float = 72.0
## Seconds between one bolt and the next one further from him.
@export var bolt_stagger: float = 0.12

## Left and right edge (global x) he and his spells stay between, set by the arena.
var bounds: Vector2 = Vector2(-INF, INF)

var _target: Player
var _phase: Phase = Phase.WAITING
var _health: int = 0
var _timer: float = 0.0
var _facing: float = -1.0
var _drift_x: float = 0.0
var _spell_count: int = 0
var _spell_released: bool = false
var _hits_since_blink: int = 0

@onready var _sprite: AnimatedSprite2D = %AnimatedSprite2D
@onready var _alert: AnimatedSprite2D = %Alert


func _ready() -> void:
	_health = max_health
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.frame_changed.connect(_on_frame_changed)
	_alert.hide()
	_apply_facing()
	_sprite.play(&"idle")
	Audio.preload_voice(voice_bank, [&"grunt", &"shout", &"hurt", &"death"])


func _physics_process(delta: float) -> void:
	match _phase:
		Phase.DRIFTING:
			_timer -= delta
			var gap: float = _drift_x - global_position.x
			if absf(gap) > 1.0:
				_facing = signf(gap)
				_apply_facing()
				global_position.x = clampf(
						global_position.x + _facing * minf(walk_speed * delta, absf(gap)),
						bounds.x, bounds.y)
			elif _sprite.animation == &"walk":
				_face_target()
				_sprite.play(&"idle")
			if _timer <= 0.0:
				_begin_spell()
		Phase.WEARY:
			_timer -= delta
			if _timer <= 0.0:
				_drift()


## Begins the fight against `player`.
func start_fight(player: Player) -> void:
	_target = player
	_health = max_health
	_spell_count = 0
	_hits_since_blink = 0
	collision_layer = 8
	EventBus.boss_started.emit(display_name, max_health)
	_drift(0.8)


## Back to the start (after Mariane is knocked out mid-fight).
func reset(at: Vector2) -> void:
	_phase = Phase.WAITING
	_health = max_health
	_alert.hide()
	collision_layer = 0
	global_position = at
	reset_physics_interpolation()
	_facing = -1.0
	_sprite.speed_scale = 1.0
	_sprite.modulate = Color.WHITE
	_apply_facing()
	_sprite.play(&"idle")
	EventBus.boss_finished.emit()


## After his last words: he crumbles into a skeleton, then a pile of bones.
func crumble() -> void:
	_sprite.speed_scale = 1.0
	_sprite.modulate = Color.WHITE
	_sprite.play(&"death")
	Audio.voice(voice_bank, &"death", 1.0, voice_pitch)


func take_hit(amount: int, _source_position: Vector2) -> void:
	if _phase in [Phase.WAITING, Phase.BLINKING, Phase.FALLEN]:
		return
	_hurt(amount)
	if _phase == Phase.FALLEN:
		return
	_hits_since_blink += 1
	if _hits_since_blink >= 2:
		_blink()


func is_weary() -> bool:
	return _phase == Phase.WEARY


func is_fallen() -> bool:
	return _phase == Phase.FALLEN


func _is_angry() -> bool:
	return _health * 2 <= max_health


## A short walk toward a spot a little way from her, then a spell.
func _drift(seconds: float = -1.0) -> void:
	_phase = Phase.DRIFTING
	_alert.hide()
	_sprite.speed_scale = 1.0
	_sprite.modulate = Color.WHITE
	_timer = seconds if seconds >= 0.0 else randf_range(drift_time.x, drift_time.y)
	var side: float = signf(global_position.x - _target.global_position.x) if _target else 1.0
	if side == 0.0:
		side = 1.0
	_drift_x = clampf(_target.global_position.x + side * keep_distance if _target
			else global_position.x, bounds.x, bounds.y)
	_sprite.play(&"walk")


## Two Dark-Bolts and then a summon, over and over (once he's angry, a bolt then
## a summon, and three bolts at a time).
func _begin_spell() -> void:
	_spell_count += 1
	_spell_released = false
	_face_target()
	_alert.show()
	_alert.play(&"play")
	if _spell_count % (2 if _is_angry() else 3) == 0:
		_phase = Phase.SUMMONING
		Audio.voice(voice_bank, &"shout", 1.0, voice_pitch)
		_sprite.play(&"summon")
	else:
		_phase = Phase.CASTING
		Audio.voice(voice_bank, &"grunt", 1.0, voice_pitch)
		_sprite.play(&"cast")


## Marks under her and further on, away from him; each bolt falls a moment
## after the one before it.
func _call_bolts() -> void:
	var away: float = _away_from_me()
	var count: int = 3 if _is_angry() else 2
	for i: int in count:
		var x: float = _target.global_position.x + away * i * bolt_spacing
		if x < bounds.x - 16.0 or x > bounds.y + 16.0:
			break
		var bolt: FrostSpikes = BOLT_SCENE.instantiate() as FrostSpikes
		bolt.start_delay = bolt_stagger * i
		_add_spell(bolt, x)


## A blob of blood wells up under her (and, once he's angry, a second one further on).
func _conjure() -> void:
	var away: float = _away_from_me()
	var spots: Array[float] = [_target.global_position.x]
	if _is_angry():
		spots.append(_target.global_position.x + away * 64.0)
	for x: float in spots:
		if x < bounds.x - 16.0 or x > bounds.y + 16.0:
			continue
		_add_spell(SPAWN_SCENE.instantiate() as FrostSpikes, x)


## Spells go into the arena (so it can clear them), on the floor at global `x`.
func _add_spell(spell: FrostSpikes, x: float) -> void:
	var arena: Node2D = get_parent() as Node2D
	spell.position = arena.to_local(Vector2(x, global_position.y))
	arena.add_child(spell)


## Which way is "further from him", seen from her.
func _away_from_me() -> float:
	var away: float = signf(_target.global_position.x - global_position.x)
	return away if away != 0.0 else _facing


func _weary() -> void:
	_phase = Phase.WEARY
	_alert.hide()
	_timer = weary_time * (0.75 if _is_angry() else 1.0)
	_sprite.play(&"idle")
	_sprite.speed_scale = 0.5
	_sprite.modulate = WEARY_TINT


func _hurt(amount: int) -> void:
	_health = maxi(_health - amount, 0)
	EventBus.boss_health_changed.emit(_health, max_health)
	var settle: Color = WEARY_TINT if _phase == Phase.WEARY else Color.WHITE
	_sprite.modulate = Color(1.0, 0.5, 0.55)
	create_tween().tween_property(_sprite, "modulate", settle, 0.25)
	if _health == 0:
		_fall()
	else:
		Audio.voice(voice_bank, &"hurt", 1.0, voice_pitch)


## He reels away as a ghost, and appears again at the far end of the crypt.
func _blink() -> void:
	_phase = Phase.BLINKING
	Audio.effect_at(&"teleport", global_position)
	_alert.hide()
	_sprite.speed_scale = 1.0
	collision_layer = 0
	_sprite.play(&"blink")


func _reappear() -> void:
	var middle: float = (bounds.x + bounds.y) / 2.0
	var her_x: float = _target.global_position.x if _target else middle
	global_position.x = (bounds.y - 24.0) if her_x < middle else (bounds.x + 24.0)
	reset_physics_interpolation()
	_hits_since_blink = 0
	collision_layer = 8
	_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_face_target()
	_sprite.play(&"idle")
	create_tween().tween_property(_sprite, "modulate:a", 1.0, 0.35)
	_drift(0.7)


## Spent: he stands with his staff lowered until the arena lets him crumble.
func _fall() -> void:
	_phase = Phase.FALLEN
	_alert.hide()
	collision_layer = 0
	_sprite.play(&"idle")
	_sprite.speed_scale = 0.3
	EventBus.boss_finished.emit()
	defeated.emit.call_deferred()


func _face_target() -> void:
	if _target != null:
		var side: float = signf(_target.global_position.x - global_position.x)
		if side != 0.0:
			_facing = side
	_apply_facing()


func _apply_facing() -> void:
	_sprite.flip_h = _facing < 0.0
	_sprite.offset = Vector2(SPRITE_OFFSET.x * _facing, SPRITE_OFFSET.y)


func _on_frame_changed() -> void:
	if _spell_released or _target == null:
		return
	if _phase == Phase.CASTING and _sprite.frame >= MARK_FRAME:
		_spell_released = true
		_call_bolts()
	elif _phase == Phase.SUMMONING and _sprite.frame >= CONJURE_FRAME:
		_spell_released = true
		_conjure()


func _on_animation_finished() -> void:
	match _sprite.animation:
		&"cast", &"summon":
			if _phase in [Phase.CASTING, Phase.SUMMONING]:
				_weary()
		&"blink":
			if _phase == Phase.BLINKING:
				_reappear()

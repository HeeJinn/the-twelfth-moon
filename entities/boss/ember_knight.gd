class_name EmberKnight
extends Damageable
## Kael, the Ember Knight: the last fight, on the roof of Ember Keep under the
## red moon. He is holding back, and it shows: touching him never hurts, every
## swing shows a "!" and holds its wind-up a moment, her guard stops every
## blow, and he leaves himself open after each one.
##
## Phase one, the sword: STALKING (he walks to her) -> ATTACKING (a "!", the
## sword held high a moment, then an overhead slash or a double slash) -> OPEN
## (catching his breath: the moment to strike). Two hits in a row and he hops
## back out of reach.
## Phase two, the fire (from half health, after the arena lets him speak): his
## swings end in a burst of fire in front of him, and every other turn he
## hurls fire into the sky instead. Embers fall back where rings glow on the
## roof: under her and beyond her, never between her and him, so stepping
## toward him is always safe.
## Beaten, he plants his sword and sinks to one knee, and stays there (the arena
## plays the reveal) until fall() lets him go down.
##
## Scene: EmberKnight (CharacterBody2D, origin at the feet; layer 8 in the fight)
##   %AnimatedSprite2D   200x112 frames, body at x 86, feet at y 112 (faces right)
##   CollisionShape2D    his body, for her sword
##   %BladeHitbox        ShapeCast2D, mask 4 (player), shaped per swing
##   %Alert              AnimatedSprite2D "!" over his head, hidden

## Emitted when his health runs out. He kneels until fall().
signal defeated
## Emitted once, at half health. He waits until begin_fire_phase().
signal fire_phase_reached

enum Phase { WAITING, STALKING, ATTACKING, OPEN, HOPPING, CASTING, PAUSED, KNEELING }

const EMBER_SCENE: PackedScene = preload("res://entities/hazard/ember_rain.tscn")
## Frame centre (100, 56) from his feet (86, 112) when facing right.
const SPRITE_OFFSET: Vector2 = Vector2(14.0, -56.0)
## Swing -> its strikes, each [frames when it hurts, hitbox size, hitbox centre].
const SWINGS: Dictionary[StringName, Array] = {
	&"slash": [[[4, 5, 6], Vector2(64, 70), Vector2(32, -35)]],
	&"double": [[[4, 5, 6], Vector2(64, 70), Vector2(32, -35)],
			[[12, 14, 15], Vector2(70, 50), Vector2(35, -25)]],
	&"fire_combo": [[[4, 5, 6], Vector2(64, 70), Vector2(32, -35)],
			[[12, 14, 15], Vector2(70, 50), Vector2(35, -25)],
			[[22, 23, 24], Vector2(84, 70), Vector2(58, -35)]],
}
## The swing frame he holds, sword raised, before it comes down.
const HOLD_FRAME: int = 3
## The "!" shows this many frames before each strike.
const ALERT_LEAD: int = 4
## The cast frame when the fire leaves his hand: the rings appear then.
const RINGS_FRAME: int = 5

@export var display_name: String = "The Ember Knight"
@export var max_health: int = 14
## His voice bank (see Audio): a grunt as he swings, a shout as he casts.
@export var voice_bank: StringName = &"ian"
@export var voice_pitch: float = 0.9
@export var walk_speed: float = 48.0
## He walks toward her until this close.
@export var reach: float = 62.0
## Seconds his sword stays raised before a swing comes down.
@export var hold_time: float = 0.5
## Seconds he stays open after a swing (less in phase two) and after a cast.
@export var open_time: float = 1.8
@export var cast_open_time: float = 2.2
## How far a hop back carries him.
@export var hop_distance: float = 96.0
## Distance between the embers of one cast, and how many fall.
@export var ember_spacing: float = 56.0
@export var ember_count: int = 4

## Left and right edge (global x) he and his embers stay between, set by the arena.
var bounds: Vector2 = Vector2(-INF, INF)

var _target: Player
var _phase: Phase = Phase.WAITING
var _health: int = 0
var _timer: float = 0.0
var _facing: float = -1.0
var _turn: int = 0
var _fire: bool = false
var _swing: StringName = &"slash"
var _struck: Array[int] = []
var _held: bool = false
var _hold_done: bool = false
var _hop: Array[Tween] = []
var _rings_cast: bool = false
var _hits_in_a_row: int = 0

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
	Audio.preload_voice(voice_bank, [&"grunt", &"shout", &"hurt", &"death"])


func _physics_process(delta: float) -> void:
	match _phase:
		Phase.STALKING:
			_face_target()
			if _fire and _turn % 2 == 1:
				_cast()
			elif _distance_to_target() <= reach:
				_wind_up()
			else:
				var step: float = walk_speed * delta * _facing
				global_position.x = clampf(global_position.x + step, bounds.x, bounds.y)
				if _sprite.animation != &"run":
					_sprite.play(&"run")
					_sprite.speed_scale = 0.6
		Phase.ATTACKING:
			if _held:
				_timer -= delta
				if _timer <= 0.0:
					_held = false
					_sprite.play()
			_update_blade()
		Phase.OPEN:
			_timer -= delta
			if _timer <= 0.0:
				_stalk()


## Begins the fight against `player`.
func start_fight(player: Player) -> void:
	_target = player
	_health = max_health
	_turn = 0
	_fire = false
	_hits_in_a_row = 0
	collision_layer = 8
	EventBus.boss_started.emit(display_name, max_health)
	_stalk()


## Phase two starts (the arena calls this after his words).
func begin_fire_phase() -> void:
	_fire = true
	_turn = 1  # The fire opens with a cast.
	collision_layer = 8
	_stalk()


## Back to the start (after Mariane is knocked out mid-fight).
func reset(at: Vector2) -> void:
	_phase = Phase.WAITING
	_health = max_health
	_fire = false
	_held = false
	for tween: Tween in _hop:
		tween.kill()
	_hop.clear()
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


## After the reveal: he lets go of his sword and falls.
func fall() -> void:
	_sprite.speed_scale = 1.0
	_sprite.play(&"fall")
	Audio.voice(voice_bank, &"death", 1.0, voice_pitch)


func take_hit(amount: int, _source_position: Vector2) -> void:
	if _phase in [Phase.WAITING, Phase.HOPPING, Phase.PAUSED, Phase.KNEELING]:
		return
	_health = maxi(_health - amount, 0)
	EventBus.boss_health_changed.emit(_health, max_health)
	_sprite.modulate = Color(1.0, 0.5, 0.55)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.25)
	if _health == 0:
		_kneel()
		return
	Audio.voice(voice_bank, &"hurt", 1.0, voice_pitch)
	if not _fire and _health * 2 <= max_health:
		_pause_for_fire()
		return
	_hits_in_a_row += 1
	if _hits_in_a_row >= 2 and _phase in [Phase.STALKING, Phase.OPEN]:
		_hop_back()
	elif _phase == Phase.OPEN:
		_sprite.play(&"hurt")


func is_open() -> bool:
	return _phase == Phase.OPEN


func is_kneeling() -> bool:
	return _phase == Phase.KNEELING


func is_fire_phase() -> bool:
	return _fire


func _stalk() -> void:
	_phase = Phase.STALKING
	_alert.hide()
	_sprite.modulate = Color.WHITE
	_face_target()


## Starts a swing: a "!" and the sword raised (held a moment), then it falls.
func _wind_up() -> void:
	_turn += 1
	if _fire:
		_swing = &"fire_combo"
	else:
		_swing = &"slash" if _turn % 2 == 1 else &"double"
	_face_target()
	_struck.clear()
	_held = false
	_hold_done = false
	_phase = Phase.ATTACKING
	_alert.show()
	_alert.play(&"play")
	Audio.voice(voice_bank, &"grunt", 1.0, voice_pitch)
	_sprite.speed_scale = 1.0
	_sprite.play(_swing)


## Fire into the sky; rings show where the embers will fall.
func _cast() -> void:
	_turn += 1
	_face_target()
	_rings_cast = false
	_phase = Phase.CASTING
	_alert.show()
	_alert.play(&"play")
	Audio.voice(voice_bank, &"shout", 1.0, voice_pitch)
	_sprite.speed_scale = 1.0
	_sprite.play(&"cast")


func _call_embers() -> void:
	var away: float = signf(_target.global_position.x - global_position.x)
	if away == 0.0:
		away = _facing
	for i: int in ember_count:
		var x: float = _target.global_position.x + away * i * ember_spacing
		if x < bounds.x - 16.0 or x > bounds.y + 16.0:
			break
		var ember: FrostSpikes = EMBER_SCENE.instantiate() as FrostSpikes
		ember.start_delay = 0.15 * i
		var arena: Node2D = get_parent() as Node2D
		ember.position = arena.to_local(Vector2(x, global_position.y))
		arena.add_child(ember)


## Shows the "!" before each strike, and lets each strike hurt once.
func _update_blade() -> void:
	var frame: int = _sprite.frame
	var strikes: Array = SWINGS[_swing]
	var warn: bool = _held
	for index: int in strikes.size():
		var strike: Array = strikes[index]
		var frames: Array = strike[0]
		var first: int = frames[0]
		if index not in _struck and frame < first and first - frame <= ALERT_LEAD:
			warn = true
		if index in _struck or frame not in frames:
			continue
		var box: RectangleShape2D = _blade.shape as RectangleShape2D
		box.size = strike[1]
		var centre: Vector2 = strike[2]
		_blade.position = Vector2(centre.x * _facing, centre.y)
		_blade.force_shapecast_update()
		for i: int in _blade.get_collision_count():
			var player: Player = _blade.get_collider(i) as Player
			if player != null and not player.is_dead():
				_struck.append(index)
				player.take_damage(1, global_position)
				break
	_alert.visible = warn


func _open(seconds: float) -> void:
	_phase = Phase.OPEN
	_alert.hide()
	_hits_in_a_row = 0
	_timer = seconds
	_sprite.speed_scale = 1.0
	_sprite.play(&"idle")


## A hop back, away from her (or over her, when there's no room behind him).
func _hop_back() -> void:
	_phase = Phase.HOPPING
	_alert.hide()
	_hits_in_a_row = 0
	collision_layer = 0
	var away: float = -signf(_target.global_position.x - global_position.x)
	if away == 0.0:
		away = -_facing
	var landing: float = global_position.x + away * hop_distance
	if landing < bounds.x or landing > bounds.y:
		landing = clampf(global_position.x - away * hop_distance * 1.6, bounds.x, bounds.y)
	var floor_y: float = global_position.y
	_sprite.speed_scale = 1.0
	_sprite.play(&"hop_up")
	var across: Tween = create_tween()
	across.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	across.tween_property(self, "global_position:x", landing, 0.6)
	var arc: Tween = create_tween()
	arc.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	arc.tween_property(self, "global_position:y", floor_y - 34.0, 0.3) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	arc.tween_callback(func() -> void: _sprite.play(&"hop_down"))
	arc.tween_property(self, "global_position:y", floor_y, 0.3) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_hop = [across, arc]
	await arc.finished
	_hop.clear()
	if _phase != Phase.HOPPING:
		return
	collision_layer = 8
	_face_target()
	_open(0.35)


## Half health: he stops, and waits for the arena to let him speak.
func _pause_for_fire() -> void:
	_phase = Phase.PAUSED
	_alert.hide()
	_held = false
	collision_layer = 0
	_sprite.speed_scale = 1.0
	_sprite.play(&"idle")
	fire_phase_reached.emit.call_deferred()


func _kneel() -> void:
	_phase = Phase.KNEELING
	_alert.hide()
	_held = false
	collision_layer = 0
	_sprite.speed_scale = 1.0
	_sprite.play(&"kneel")
	EventBus.boss_finished.emit()
	defeated.emit.call_deferred()


func _distance_to_target() -> float:
	return absf(_target.global_position.x - global_position.x) if _target else INF


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
	if _phase == Phase.ATTACKING:
		for strike: Array in SWINGS[_swing]:
			if _sprite.frame == (strike[0] as Array)[0]:
				Audio.effect_at(&"slash", global_position)
	if _phase == Phase.ATTACKING and _sprite.frame == HOLD_FRAME and not _hold_done:
		_held = true
		_hold_done = true
		_timer = hold_time
		_sprite.pause()
	elif _phase == Phase.CASTING and _sprite.frame >= RINGS_FRAME and not _rings_cast:
		_rings_cast = true
		_alert.hide()
		_call_embers()


func _on_animation_finished() -> void:
	match _sprite.animation:
		&"slash", &"double", &"fire_combo":
			if _phase == Phase.ATTACKING:
				_open(open_time * (0.8 if _fire else 1.0))
		&"cast":
			if _phase == Phase.CASTING:
				_open(cast_open_time)
		&"hurt":
			if _phase == Phase.OPEN:
				_sprite.play(&"idle")

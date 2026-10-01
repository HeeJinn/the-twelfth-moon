extends Cutscene
## Chapter Five's ending: the summit of Ember Keep, where Kael waits under the
## red moon. Walking up, Mariane is stopped; walls of fire close the summit and
## the fight begins. At half health he stops and speaks (the fire phase), and
## the fight goes on. If she's knocked out, everything resets and walking back
## in starts it again with a shorter greeting. Beaten, he kneels beside his
## sword: the reveal. He falls, the twenty-first petal drifts down from where
## he knelt, she picks it up, and the moon cracks (the chapter ends).
##
## Like the Grave Warden's crypt, the summit is about one screen wide, so the
## cutscene camera holds all of it: higher while someone speaks, lower in the
## fight. A knock-out hands the view back to Mariane.
##
## Scene: RooftopArena (Area2D, origin at the middle of the summit's floor)
##   CollisionShape2D   trigger just inside the west wall
##   %Camera2D          disabled until the scene starts
##   %Kael              EmberKnight
##   %Barrier           StaticBody2D (world layer), a wall at each edge
##   %BarrierGlow       Node2D, the visible walls of fire
##   %MoonLight         a column of red light that pours into him at the reveal
##   FlashLayer > %Flash  ColorRect, white when the moon cracks

## Where Mariane stops for the greeting, from the summit's middle.
const GREETING_OFFSET_X: float = -150.0
## How far from the middle Kael and his embers may go (inside the walls).
const KAEL_RANGE: float = 210.0
## Camera centres, from the summit's middle: while someone speaks, and in the fight.
const TALK_VIEW: Vector2 = Vector2(0.0, -48.0)
const FIGHT_VIEW: Vector2 = Vector2(0.0, -95.0)
## How far from where he knelt the last petal comes to rest, on her side.
const PETAL_REST_DISTANCE: float = 24.0
## How close she comes to him for the reveal.
const REVEAL_DISTANCE: float = 44.0

var _intro_seen: bool = false
var _fighting: bool = false
var _kael_home: Vector2 = Vector2.ZERO

@onready var _kael: EmberKnight = %Kael
@onready var _barrier: StaticBody2D = %Barrier
@onready var _barrier_glow: Node2D = %BarrierGlow
@onready var _flash: ColorRect = %Flash
@onready var _moon_light: Sprite2D = %MoonLight


func _ready() -> void:
	super()
	_kael_home = _kael.global_position
	_kael.bounds = Vector2(global_position.x - KAEL_RANGE, global_position.x + KAEL_RANGE)
	_kael.defeated.connect(_on_kael_defeated)
	_kael.fire_phase_reached.connect(_on_fire_phase_reached)
	EventBus.player_died.connect(_on_player_died)
	_set_barrier(false)


func _play() -> void:
	take_camera()
	if _intro_seen:
		_set_barrier(true)
		await pan_camera(global_position + TALK_VIEW, 0.6)
		await say("kael_again")
	else:
		_intro_seen = true
		Music.play(&"kael_theme")
		await player.walk_to(global_position.x + GREETING_OFFSET_X)
		player.face(1.0)
		await pan_camera(global_position + TALK_VIEW, 1.2)
		await wait(0.8)
		await say("kael_intro")
		_set_barrier(true)
		shake(2.0, 0.3)
	await pan_camera(global_position + FIGHT_VIEW, 0.6)
	_fighting = true
	_kael.start_fight(player)


## True while the fight's camera holds the whole summit.
func is_holding_view() -> bool:
	return _camera.is_current() and _camera.global_position.is_equal_approx(
			global_position + FIGHT_VIEW)


func _set_barrier(active: bool) -> void:
	for child: Node in _barrier.get_children():
		(child as CollisionShape2D).set_deferred("disabled", not active)
	_barrier_glow.visible = active


## Embers still on their way.
func _clear_embers() -> void:
	for child: Node in get_children():
		if child is FrostSpikes:
			child.queue_free()


func _on_player_died() -> void:
	if not _fighting:
		return
	_fighting = false
	_clear_embers()
	_kael.reset(_kael_home)
	_set_barrier(false)
	return_camera(0.4)
	rearm()


## Half health: he stops and speaks, then the fire begins.
func _on_fire_phase_reached() -> void:
	if not _fighting:
		return
	_clear_embers()
	player.lock_controls()
	Music.play(&"kael_fire")
	await wait(0.6)
	await say("kael_fire")
	player.unlock_controls()
	_kael.begin_fire_phase()


func _on_kael_defeated() -> void:
	_fighting = false
	_clear_embers()
	_set_barrier(false)
	player.lock_controls()
	Music.play(&"reveal", 3.0)
	var side: float = signf(player.global_position.x - _kael.global_position.x)
	if side == 0.0:
		side = -1.0
	await pan_camera(global_position + TALK_VIEW, 1.2)
	await player.walk_to(_kael.global_position.x + side * REVEAL_DISTANCE)
	player.face(-side)
	# The moon's light pours down into him.
	_moon_light.global_position = _kael.global_position + Vector2(0.0, -110.0)
	var light: Tween = create_tween()
	light.tween_property(_moon_light, "modulate:a", 0.85, 1.6)
	await light.finished
	await say("reveal")
	_kael.fall()
	create_tween().tween_property(_moon_light, "modulate:a", 0.0, 1.0)
	await wait(1.2)
	var petal: LastPetal = get_tree().get_first_node_in_group(&"last_petal") as LastPetal
	if petal != null:
		var rest: Vector2 = _kael.global_position + Vector2(side * PETAL_REST_DISTANCE, 0.0)
		await petal.release(_kael.global_position + Vector2(0.0, -30.0), rest)
		await player.walk_to(rest.x)
		await wait(0.8)
	await say("reveal_after")
	# The moon cracks.
	shake(4.0, 1.2)
	var crack: Tween = create_tween()
	crack.tween_property(_flash, "color:a", 1.0, 1.2)
	await crack.finished
	await wait(0.5)
	EventBus.level_completed.emit()

extends Cutscene
## Chapter Three's ending: the frozen gate at the top of the winter pass,
## where Kael's Shield stands guard. Walking up, Mariane is stopped; walls
## of frost close the gate and the duel begins. If she's knocked out,
## everything resets, and walking back in starts it again with a shorter
## greeting. Beaten, he kneels and tells her Kael is waiting, and the
## chapter ends (then the past-life memory plays).
##
## Scene: ShieldArena (Area2D, origin at the middle of the gate's floor)
##   CollisionShape2D   trigger just inside the west edge
##   %Camera2D          disabled until the scene starts
##   %Knight            ShieldKnight
##   %Barrier           StaticBody2D (world layer), a wall at each edge
##   %BarrierGlow       Node2D, the visible frost walls

## Where Mariane stops for the greeting, from the gate's middle.
const GREETING_OFFSET_X: float = -150.0
## How far from the middle the Knight may go (inside the frost walls).
const KNIGHT_RANGE: float = 250.0

var _intro_seen: bool = false
var _fighting: bool = false
var _knight_home: Vector2 = Vector2.ZERO

@onready var _knight: ShieldKnight = %Knight
@onready var _barrier: StaticBody2D = %Barrier
@onready var _barrier_glow: Node2D = %BarrierGlow


func _ready() -> void:
	super()
	_knight_home = _knight.global_position
	_knight.bounds = Vector2(global_position.x - KNIGHT_RANGE, global_position.x + KNIGHT_RANGE)
	_knight.defeated.connect(_on_knight_defeated)
	EventBus.player_died.connect(_on_player_died)
	_set_barrier(false)


func _play() -> void:
	if _intro_seen:
		_set_barrier(true)
		await say("knight_again")
	else:
		_intro_seen = true
		await player.walk_to(global_position.x + GREETING_OFFSET_X)
		player.face(1.0)
		take_camera()
		await pan_camera(global_position + Vector2(0.0, -70.0), 1.0)
		await wait(0.5)
		await say("knight_intro")
		_set_barrier(true)
		shake(2.0, 0.3)
		await return_camera(0.6)
	_fighting = true
	_knight.start_fight(player)


func _set_barrier(active: bool) -> void:
	for child: Node in _barrier.get_children():
		(child as CollisionShape2D).set_deferred("disabled", not active)
	_barrier_glow.visible = active


func _on_player_died() -> void:
	if not _fighting:
		return
	_fighting = false
	_knight.reset(_knight_home)
	_set_barrier(false)
	rearm()


func _on_knight_defeated() -> void:
	_fighting = false
	player.lock_controls()
	await wait(1.2)
	await say("knight_yields")
	_set_barrier(false)
	await wait(0.6)
	await say("knight_after")
	await wait(0.5)
	EventBus.level_completed.emit()

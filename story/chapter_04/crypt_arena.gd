extends Cutscene
## Chapter Four's ending: the Grave Warden's crypt at the far end of the
## undercroft. Walking in, Mariane is stopped; walls of red moonlight close
## the crypt and the fight begins. If she's knocked out, everything resets
## (his spells vanish too), and walking back in starts it again with a shorter
## greeting. Beaten, he speaks his last words, crumbles into bones, and the
## chapter ends (then the past-life memory plays).
##
## The crypt is about one screen wide, so the cutscene camera holds all of it
## from the greeting to the end: higher while someone speaks (so the dialogue
## box covers no one), lower in the fight (both walls in view). The talking
## view looks a little past the bottom of the map, so the camera's bottom limit
## is lifted (the dialogue box covers that strip). A knock-out hands the view
## back to Mariane.
##
## Scene: CryptArena (Area2D, origin at the middle of the crypt's floor)
##   CollisionShape2D   trigger just inside the west wall
##   %Camera2D          disabled until the scene starts
##   %Warden            GraveWarden
##   %Barrier           StaticBody2D (world layer), a wall at each edge
##   %BarrierGlow       Node2D, the visible walls of light

## Where Mariane stops for the greeting, from the crypt's middle.
const GREETING_OFFSET_X: float = -150.0
## How far from the middle the Warden and his spells may go (inside the walls).
const WARDEN_RANGE: float = 210.0
## Camera centres, from the crypt's middle: while someone speaks, and in the fight.
const TALK_VIEW: Vector2 = Vector2(0.0, -48.0)
const FIGHT_VIEW: Vector2 = Vector2(0.0, -95.0)

var _intro_seen: bool = false
var _fighting: bool = false
var _warden_home: Vector2 = Vector2.ZERO

@onready var _warden: GraveWarden = %Warden
@onready var _barrier: StaticBody2D = %Barrier
@onready var _barrier_glow: Node2D = %BarrierGlow


func _ready() -> void:
	super()
	_warden_home = _warden.global_position
	_warden.bounds = Vector2(global_position.x - WARDEN_RANGE, global_position.x + WARDEN_RANGE)
	_warden.defeated.connect(_on_warden_defeated)
	EventBus.player_died.connect(_on_player_died)
	_set_barrier(false)


func _play() -> void:
	take_camera()
	_camera.limit_bottom = 1000000
	if _intro_seen:
		_set_barrier(true)
		await pan_camera(global_position + TALK_VIEW, 0.6)
		await say("warden_again")
	else:
		_intro_seen = true
		await player.walk_to(global_position.x + GREETING_OFFSET_X)
		player.face(1.0)
		await pan_camera(global_position + TALK_VIEW, 1.0)
		await wait(0.5)
		await say("warden_intro")
		_set_barrier(true)
		shake(2.0, 0.3)
	await pan_camera(global_position + FIGHT_VIEW, 0.6)
	_fighting = true
	_warden.start_fight(player)


## True while the fight's camera holds the whole crypt.
func is_holding_view() -> bool:
	return _camera.is_current() and _camera.global_position.is_equal_approx(
			global_position + FIGHT_VIEW)


func _set_barrier(active: bool) -> void:
	for child: Node in _barrier.get_children():
		(child as CollisionShape2D).set_deferred("disabled", not active)
	_barrier_glow.visible = active


## Dark-Bolts and blood creatures still on their way.
func _clear_spells() -> void:
	for child: Node in get_children():
		if child is FrostSpikes:
			child.queue_free()


func _on_player_died() -> void:
	if not _fighting:
		return
	_fighting = false
	_clear_spells()
	_warden.reset(_warden_home)
	_set_barrier(false)
	return_camera(0.4)
	rearm()


func _on_warden_defeated() -> void:
	_fighting = false
	_clear_spells()
	player.lock_controls()
	await pan_camera(global_position + TALK_VIEW, 1.0)
	await say("warden_falls")
	_warden.crumble()
	await wait(4.0)
	_set_barrier(false)
	await say("warden_after")
	await wait(0.5)
	EventBus.level_completed.emit()

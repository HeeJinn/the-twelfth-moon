extends Cutscene
## Chapter Two's ending: the Moon Witch's clearing. Walking in, Mariane
## meets the witch; a violet barrier closes the clearing and the fight
## begins. If Mariane is knocked out, everything resets and walking back in
## starts the fight again (with a shorter greeting). When the witch is
## beaten she lets slip that the Ember Knight ordered her to make Mariane
## stronger, then dissolves, and the chapter ends.
##
## Scene: WitchArena (Area2D, origin at the middle of the clearing's floor)
##   CollisionShape2D   trigger just inside the west edge
##   %Camera2D          disabled until the scene starts
##   %Witch             MoonWitch
##   %Spots             Node2D > Marker2D where she can appear
##   %Barrier           StaticBody2D (world layer), a wall at each edge
##   %BarrierGlow       Node2D, the visible magic walls

## Where Mariane stops for the greeting, from the clearing's middle.
const GREETING_OFFSET_X: float = -170.0

var _intro_seen: bool = false
var _fighting: bool = false

@onready var _witch: MoonWitch = %Witch
@onready var _spots: Node2D = %Spots
@onready var _barrier: StaticBody2D = %Barrier
@onready var _barrier_glow: Node2D = %BarrierGlow


func _ready() -> void:
	super()
	var spots: Array[Vector2] = []
	for marker: Node in _spots.get_children():
		spots.append((marker as Marker2D).global_position)
	_witch.spots = spots
	_witch.defeated.connect(_on_witch_defeated)
	EventBus.player_died.connect(_on_player_died)
	_set_barrier(false)


func _play() -> void:
	if _intro_seen:
		_set_barrier(true)
		await say("witch_again")
	else:
		_intro_seen = true
		await player.walk_to(global_position.x + GREETING_OFFSET_X)
		player.face(1.0)
		take_camera()
		await pan_camera(global_position + Vector2(0.0, -70.0), 1.0)
		_witch.appear_at(_spots.get_child(2).global_position)
		await wait(1.0)
		await say("witch_intro")
		_set_barrier(true)
		shake(2.0, 0.3)
		await return_camera(0.6)
	_fighting = true
	_witch.start_fight(player)


func _set_barrier(active: bool) -> void:
	for child: Node in _barrier.get_children():
		(child as CollisionShape2D).set_deferred("disabled", not active)
	_barrier_glow.visible = active


func _on_player_died() -> void:
	if not _fighting:
		return
	_fighting = false
	_witch.reset()
	_set_barrier(false)
	rearm()


func _on_witch_defeated() -> void:
	_fighting = false
	player.lock_controls()
	await wait(0.8)
	await say("witch_defeated")
	await _witch.dissolve()
	_set_barrier(false)
	await wait(0.6)
	await say("witch_after")
	await wait(0.5)
	EventBus.level_completed.emit()

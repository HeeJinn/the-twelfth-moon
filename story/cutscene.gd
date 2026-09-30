class_name Cutscene
extends Area2D
## A scripted story moment that starts when Mariane walks into its area.
## Subclasses override _play() and build the scene from the helpers below.
## Her controls stay locked until _play() returns.
##
## Scene: Cutscene (Area2D, origin at the feet; layer 64, mask 4)
##   CollisionShape2D  where the scene starts
##   %Camera2D         takes over the view while the scene plays; keep it
##                     disabled in the scene so it can't steal the view early

signal finished

const EFFECT_Z: int = 5

var player: Player

var _has_played: bool = false
var _shake_tween: Tween

@onready var _camera: Camera2D = %Camera2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


## Override: the scene itself. Await the helpers in order.
func _play() -> void:
	pass


## Lets the scene start again the next time Mariane walks in (e.g. to retry
## a boss fight after she was knocked out).
func rearm() -> void:
	_has_played = false
	monitoring = false
	set_deferred("monitoring", true)  # Re-reports her if she's standing inside.


## Plays a conversation from the chapter's dialogue script and waits for it.
func say(dialogue_id: String) -> void:
	EventBus.dialogue_requested.emit(dialogue_id)
	await EventBus.dialogue_finished


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Switches to the cutscene camera, starting from exactly what the player sees.
func take_camera() -> void:
	var follow: Camera2D = player.get_camera()
	_camera.limit_left = follow.limit_left
	_camera.limit_top = follow.limit_top
	_camera.limit_right = follow.limit_right
	_camera.limit_bottom = follow.limit_bottom
	_camera.global_position = follow.get_screen_center_position()
	_camera.reset_physics_interpolation()
	_camera.enabled = true
	_camera.make_current()


## Glides the cutscene camera so `target` (global) is centred.
func pan_camera(target: Vector2, seconds: float) -> void:
	var tween: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(_camera, "global_position", target, seconds)
	await tween.finished


## Glides back to Mariane and hands the view back to her camera.
func return_camera(seconds: float = 0.8) -> void:
	var follow: Camera2D = player.get_camera()
	await pan_camera(follow.get_screen_center_position(), seconds)
	follow.make_current()
	_camera.enabled = false


func shake(strength: float, seconds: float) -> void:
	if _shake_tween:
		_shake_tween.kill()
	_shake_tween = create_tween()
	var steps: int = maxi(int(seconds / 0.05), 1)
	for i: int in steps:
		var fade: float = 1.0 - float(i) / steps
		var offset: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		_shake_tween.tween_property(_camera, "offset", (offset * strength * fade).round(), 0.05)
	_shake_tween.tween_property(_camera, "offset", Vector2.ZERO, 0.05)


## Plays a one-shot effect animation ("play") at a global position.
func play_effect(frames: SpriteFrames, at: Vector2, flip: bool = false) -> AnimatedSprite2D:
	var effect: AnimatedSprite2D = AnimatedSprite2D.new()
	effect.sprite_frames = frames
	effect.flip_h = flip
	effect.z_index = EFFECT_Z
	add_child(effect)
	effect.global_position = at
	effect.play("play")
	effect.animation_finished.connect(effect.queue_free)
	return effect


func _on_body_entered(body: Node2D) -> void:
	var entered: Player = body as Player
	if entered == null or entered.is_dead() or _has_played:
		return
	_has_played = true
	player = entered
	_run.call_deferred()


func _run() -> void:
	player.lock_controls()
	await _play()
	if is_instance_valid(player):
		player.unlock_controls()
	finished.emit()

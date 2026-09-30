class_name Npc
extends Area2D
## A villager. Strolls around home (or stands still), turns to face Mariane
## when she comes close, and talks when she presses interact. Now and then
## says a short line out loud ("barks") so the village feels alive.
##
## Some villagers speak first (auto_talk), and some walk off afterwards
## (leave_after_talk), which is how the story scenes in the village work.
## Until Mariane has heard what they have to say, a "?" floats over them.
##
## Scene: Npc (Area2D, origin at the feet; layer 64, mask 4)
##   %AnimatedSprite2D  animations: idle, walk, run (art faces LEFT)
##   CollisionShape2D   talking range
##   %TalkPrompt        Node2D above the head: bubble + "E", hidden
##   %BarkLabel         Label above the head, hidden

## Seconds interact is ignored after a conversation ends, so the press that
## closed it doesn't start it again.
const TALK_COOLDOWN: float = 0.4
const BARK_SHOW_TIME: float = 3.0
const LEAVE_SPEED: float = 80.0
const LEAVE_TIME: float = 3.0
## Barks only play while Mariane is this close (px), so the whole village
## doesn't talk over itself.
const BARK_RANGE: float = 150.0
const QUESTION: SpriteFrames = preload("res://entities/effects/question_frames.tres")

## Conversation in the chapter's dialogue script (e.g. "rosa").
@export var dialogue_id: String = ""
## Starts talking the first time Mariane comes into range.
@export var auto_talk: bool = false
## Seconds before this villager notices Mariane (keeps the start of a
## chapter clear for the intro card).
@export var start_delay: float = 0.0
@export var face_left: bool = false

@export_group("Walking")
## How far from home the villager strolls, in px. 0 stands still.
@export var wander_distance: float = 0.0
@export var walk_speed: float = 20.0
## Runs off and fades away once the conversation ends.
@export var leave_after_talk: bool = false
@export_enum("Left:-1", "Right:1") var leave_direction: int = -1

@export_group("Barks")
## Short lines said out loud now and then, without stopping Mariane.
@export var barks: PackedStringArray = []
@export var bark_interval: float = 8.0

var _player: Player
var _home_x: float = 0.0
var _target_x: float = 0.0
var _rest_timer: float = 0.0
var _bark_timer: float = 0.0
var _cooldown: float = 0.0
var _is_talking: bool = false
var _dialogue_open: bool = false
var _is_leaving: bool = false
var _leave_timer: float = 0.0
var _bark_tween: Tween
var _was_heard: bool = false
var _question: AnimatedSprite2D

@onready var _sprite: AnimatedSprite2D = %AnimatedSprite2D
@onready var _talk_prompt: Node2D = %TalkPrompt
@onready var _bark_label: Label = %BarkLabel


func _ready() -> void:
	_home_x = position.x
	_target_x = _home_x
	_rest_timer = randf_range(0.5, 3.0)
	_bark_timer = randf_range(2.0, bark_interval)
	_face(-1.0 if face_left else 1.0)
	_sprite.play("idle")
	_talk_prompt.hide()
	_bark_label.modulate.a = 0.0
	_question = AnimatedSprite2D.new()
	_question.sprite_frames = QUESTION
	_question.position = _talk_prompt.position + Vector2(0.0, -2.0)
	_question.z_index = 5
	add_child(_question)
	_question.play(&"play")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.dialogue_finished.connect(_on_dialogue_finished)
	if start_delay > 0.0:
		monitoring = false
		await get_tree().create_timer(start_delay).timeout
		monitoring = true  # Reports a player already standing here.


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_question.visible = (
			not _was_heard and not dialogue_id.is_empty() and not _talk_prompt.visible
			and not _dialogue_open and not _is_leaving
	)
	if _is_leaving:
		_update_leaving(delta)
		return
	if _player != null and not _player.is_dead():
		_face_toward(_player.global_position.x)
		_play("idle")
		_talk_prompt.visible = _can_talk()
		if _can_talk() and Input.is_action_just_pressed("interact"):
			talk()
	else:
		_talk_prompt.hide()
		_update_wander(delta)
	_update_barks(delta)


## Starts this villager's conversation.
func talk() -> void:
	if dialogue_id.is_empty() or _dialogue_open:
		return
	_is_talking = true
	_talk_prompt.hide()
	_hide_bark()
	EventBus.dialogue_requested.emit(dialogue_id)


func _can_talk() -> bool:
	return not dialogue_id.is_empty() and not _dialogue_open and _cooldown <= 0.0


func _update_wander(delta: float) -> void:
	if wander_distance <= 0.0:
		_play("idle")
		return
	if absf(position.x - _target_x) > 0.5:
		_face_toward(_target_x)
		position.x = move_toward(position.x, _target_x, walk_speed * delta)
		_play("walk")
		return
	_play("idle")
	_rest_timer -= delta
	if _rest_timer <= 0.0:
		_rest_timer = randf_range(2.0, 5.0)
		_target_x = _home_x + randf_range(-wander_distance, wander_distance)


func _update_leaving(delta: float) -> void:
	position.x += leave_direction * LEAVE_SPEED * delta
	_leave_timer += delta
	if _leave_timer >= LEAVE_TIME:
		set_physics_process(false)
		var tween: Tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.4)
		tween.tween_callback(queue_free)


func _update_barks(delta: float) -> void:
	if barks.is_empty() or _dialogue_open or _is_talking:
		return
	_bark_timer -= delta
	if _bark_timer > 0.0:
		return
	_bark_timer = bark_interval + randf_range(-2.0, 2.0)
	var listener: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
	if listener == null or listener.global_position.distance_to(global_position) > BARK_RANGE:
		return
	_bark_label.text = barks[randi() % barks.size()]
	if _bark_tween:
		_bark_tween.kill()
	_bark_tween = create_tween()
	_bark_tween.tween_property(_bark_label, "modulate:a", 1.0, 0.25)
	_bark_tween.tween_interval(BARK_SHOW_TIME)
	_bark_tween.tween_property(_bark_label, "modulate:a", 0.0, 0.4)


func _hide_bark() -> void:
	if _bark_tween:
		_bark_tween.kill()
	_bark_label.modulate.a = 0.0


func _face_toward(x: float) -> void:
	if absf(x - global_position.x) > 1.0:
		_face(signf(x - global_position.x))


## The GandalfHardcore villager art faces left, so it flips to face right.
func _face(direction: float) -> void:
	if direction != 0.0:
		_sprite.flip_h = direction > 0.0


func _play(animation: StringName) -> void:
	if _sprite.animation != animation:
		_sprite.play(animation)


func _on_body_entered(body: Node2D) -> void:
	var player: Player = body as Player
	if player == null:
		return
	_player = player
	if auto_talk and not _is_talking and not _is_leaving:
		talk.call_deferred()
		auto_talk = false


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null


func _on_dialogue_started(_dialogue_id: String) -> void:
	_dialogue_open = true
	_hide_bark()


func _on_dialogue_finished(finished_id: String) -> void:
	_dialogue_open = false
	_cooldown = TALK_COOLDOWN
	if not _is_talking or finished_id != dialogue_id:
		return
	_is_talking = false
	_was_heard = true
	if leave_after_talk:
		_is_leaving = true
		_talk_prompt.hide()
		_face(float(leave_direction))
		_sprite.play("run")
		monitoring = false

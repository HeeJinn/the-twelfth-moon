class_name Hint
extends Area2D
## A tutorial line that fades in while the player stands nearby.
##
## Scene: Hint (Area2D, origin at cell bottom; layer 64, mask 4)
##   CollisionShape2D  wide box around the spot
##   %Label            centred above the spot, hidden until the player is near

const FADE_TIME: float = 0.3

@export_multiline var text: String = ""
## What it says on a touch screen, where the keys are buttons. Empty: `text`.
@export_multiline var touch_text: String = ""
## Seconds before the hint can appear. Keeps a hint near the start from
## overlapping the chapter intro card.
@export var start_delay: float = 0.0

var _tween: Tween
var _player_inside: bool = false
var _dialogue_open: bool = false

@onready var _label: Label = %Label


func _ready() -> void:
	_label.text = touch_text if TouchControls.is_touch() and not touch_text.is_empty() else text
	_label.modulate.a = 0.0
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Step aside while someone is talking, then come back.
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.dialogue_finished.connect(_on_dialogue_finished)
	if start_delay > 0.0:
		monitoring = false
		await get_tree().create_timer(start_delay).timeout
		# Re-enabling monitoring reports a player already standing here.
		monitoring = true


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_inside = true
		_refresh()


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_inside = false
		_refresh()


func _on_dialogue_started(_dialogue_id: String) -> void:
	_dialogue_open = true
	_refresh()


func _on_dialogue_finished(_dialogue_id: String) -> void:
	_dialogue_open = false
	_refresh()


func _refresh() -> void:
	_fade_to(1.0 if _player_inside and not _dialogue_open else 0.0)


func _fade_to(alpha: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_label, "modulate:a", alpha, FADE_TIME)

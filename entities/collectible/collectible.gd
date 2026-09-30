class_name Collectible
extends Area2D
## A memory petal. Reports itself on EventBus and drifts away when picked up.
## Soft coloured sparks rise from it, so it catches the eye from afar.
##
## Scene: Collectible (Area2D, origin at cell bottom; layer 16, mask 4)
##   %Sprite2D  offset up so it floats mid-cell
##   CollisionShape2D

## How far the petal bobs up and down, in px.
const BOB_HEIGHT: float = 3.0
const BOB_TIME: float = 0.9
const GLIMMER: SpriteFrames = preload("res://entities/effects/glimmer_frames.tres")

var _glimmer: AnimatedSprite2D

@export var value: int = 1

@onready var _sprite: Sprite2D = %Sprite2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_glimmer = AnimatedSprite2D.new()
	_glimmer.sprite_frames = GLIMMER
	_glimmer.position = Vector2(0.0, _sprite.offset.y - 8.0)
	_glimmer.modulate.a = 0.8
	_glimmer.z_index = -1
	add_child(_glimmer)
	_glimmer.play(&"play")
	# Bob the sprite's offset, not the node's position, so the pickup area
	# stays put and physics interpolation is not involved.
	var base_y: float = _sprite.offset.y
	var bob: Tween = create_tween().set_loops()
	bob.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_sprite, "offset:y", base_y - BOB_HEIGHT, BOB_TIME)
	bob.tween_property(_sprite, "offset:y", base_y, BOB_TIME)


func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	# Physics state cannot change inside a physics callback: defer it.
	set_deferred("monitoring", false)
	EventBus.collectible_collected.emit(value)

	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(_glimmer, "modulate:a", 0.0, 0.2)
	tween.tween_property(_sprite, "offset:y", _sprite.offset.y - 16.0, 0.4)
	tween.tween_property(_sprite, "scale", Vector2(1.6, 1.6), 0.4)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(queue_free)

class_name Checkpoint
extends Area2D
## A campfire. Touching it lights it; the level then respawns the player here
## and refills her health.
##
## Scene: Checkpoint (Area2D, origin at cell bottom; layer 64, mask 4)
##   %AnimatedSprite2D  animation: burn (looping)
##   CollisionShape2D

## Emitted the first time the player touches this campfire.
signal activated(checkpoint: Checkpoint)

const UNLIT_COLOR: Color = Color(0.3, 0.3, 0.4)

## Where she wakes up, relative to the fire (so she isn't standing in it).
@export var respawn_offset: Vector2 = Vector2(-24.0, 0.0)

var is_lit: bool = false

@onready var _sprite: AnimatedSprite2D = %AnimatedSprite2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_sprite.stop()
	_sprite.frame = 0
	_sprite.modulate = UNLIT_COLOR


func get_respawn_position() -> Vector2:
	return global_position + respawn_offset


func _on_body_entered(body: Node2D) -> void:
	var player: Player = body as Player
	if player == null or player.is_dead() or is_lit:
		return
	is_lit = true
	_sprite.play("burn")
	var tween: Tween = create_tween()
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.4)
	activated.emit(self)

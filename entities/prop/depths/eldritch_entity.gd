class_name EldritchEntity
extends Node2D
## A huge face asleep in the wall of the undercroft. When Mariane comes near, it
## opens its eyes and keeps them open, watching her go. It never moves or hurts.
##
## Scene: EldritchEntity (Node2D, origin at the bottom middle of the face)
##   %Face  Sprite2D, the sleeping face (behind the gameplay)

## How close Mariane comes before it wakes, px from its middle.
@export var wake_distance: float = 150.0
@export var awake_texture: Texture2D

var _awake: bool = false

@onready var _face: Sprite2D = %Face


func _physics_process(_delta: float) -> void:
	var mariane: Player = get_tree().get_first_node_in_group(&"player") as Player
	if mariane == null:
		return
	var middle: Vector2 = global_position + Vector2(0.0, -_face.texture.get_height() / 2.0)
	if mariane.global_position.distance_to(middle) < wake_distance:
		wake()


func wake() -> void:
	if _awake:
		return
	_awake = true
	_face.texture = awake_texture
	set_physics_process(false)
	# A slow brightening, like eyes getting used to the dark.
	_face.modulate = Color(0.7, 0.7, 0.75)
	create_tween().tween_property(_face, "modulate", Color.WHITE, 1.2)


func is_awake() -> bool:
	return _awake

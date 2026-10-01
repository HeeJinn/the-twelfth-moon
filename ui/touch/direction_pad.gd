class_name DirectionPad
extends Node2D
## The left-hand direction pad for touch screens: four arrow buttons around a
## middle point. A thumb anywhere on it presses the directions it points to,
## diagonals included (run and slide, or push toward a ledge and climb up), and
## can slide around without lifting. Pressed arrows show pushed down.
##
## Scene: DirectionPad (Node2D, origin at the pad's middle)
##   %Left, %Right, %Up, %Down   Sprite2D arrows, textures swapped when pressed

## Touches this far from the middle (or nearer) belong to the pad.
@export var radius: float = 62.0
## Within this distance of the middle, nothing is pressed.
@export var dead_zone: float = 7.0

var _touch: int = -1
var _held: Dictionary[StringName, bool] = {}

@onready var _arrows: Dictionary[StringName, Sprite2D] = {
	&"move_left": %Left, &"move_right": %Right, &"move_up": %Up, &"move_down": %Down,
}
@onready var _textures: Dictionary[StringName, Array] = {
	&"move_left": [load("res://assets/ui/touch/left.png"), load("res://assets/ui/touch/left_pressed.png")],
	&"move_right": [load("res://assets/ui/touch/right.png"), load("res://assets/ui/touch/right_pressed.png")],
	&"move_up": [load("res://assets/ui/touch/up.png"), load("res://assets/ui/touch/up_pressed.png")],
	&"move_down": [load("res://assets/ui/touch/down.png"), load("res://assets/ui/touch/down_pressed.png")],
}


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		release()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		var offset: Vector2 = touch.position - global_position
		if touch.pressed and _touch < 0 and offset.length() <= radius:
			_touch = touch.index
			aim(offset)
		elif not touch.pressed and touch.index == _touch:
			release()
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null and drag.index == _touch:
		aim(drag.position - global_position)


## Presses the directions a thumb at `offset` (from the middle) points to.
func aim(offset: Vector2) -> void:
	var across: float = absf(offset.x)
	var updown: float = absf(offset.y)
	var wanted: Dictionary[StringName, bool] = {
		&"move_left": offset.x < -dead_zone and across >= updown * 0.5,
		&"move_right": offset.x > dead_zone and across >= updown * 0.5,
		&"move_up": offset.y < -dead_zone and updown >= across * 0.6,
		&"move_down": offset.y > dead_zone and updown >= across * 0.6,
	}
	for action: StringName in wanted:
		_set_held(action, wanted[action])


## Lets go of every direction.
func release() -> void:
	_touch = -1
	for action: StringName in _arrows:
		_set_held(action, false)


func is_held(action: StringName) -> bool:
	return _held.get(action, false)


func _set_held(action: StringName, held: bool) -> void:
	if is_held(action) == held:
		return
	_held[action] = held
	if held:
		Input.action_press(action)
	else:
		Input.action_release(action)
	if is_node_ready():
		(_arrows[action] as Sprite2D).texture = _textures[action][1 if held else 0]

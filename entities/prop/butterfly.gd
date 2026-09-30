extends AnimatedSprite2D
## A butterfly fluttering in lazy loops around where the map put it. Only the
## drawing offset moves, so it needs no physics.

const COLORS: Array[Color] = [
	Color(1.0, 1.0, 1.0), Color(1.0, 0.95, 0.6), Color(1.0, 0.75, 0.85), Color(0.75, 0.9, 1.0),
]

## How far it wanders sideways and up/down, in px.
@export var reach: Vector2 = Vector2(30.0, 10.0)
## Height above the ground it circles at, in px.
@export var height: float = 34.0

var _time: float = 0.0
var _speed: float = 1.0


func _ready() -> void:
	modulate = COLORS[randi() % COLORS.size()]
	_time = randf() * TAU
	_speed = randf_range(0.5, 0.9)
	play()


func _process(delta: float) -> void:
	_time += delta * _speed
	var drift: Vector2 = Vector2(
			sin(_time) * reach.x,
			-height + sin(_time * 2.3) * reach.y + sin(_time * 9.0) * 1.5,
	)
	offset = drift.round()
	flip_h = cos(_time) < 0.0

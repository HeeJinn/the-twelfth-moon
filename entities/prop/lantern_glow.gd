extends Sprite2D
## A lantern's warm glow that breathes a little, each at its own pace.

@export var strength: float = 0.7

var _time: float = 0.0
var _speed: float = 1.0


func _ready() -> void:
	_time = randf() * TAU
	_speed = randf_range(1.5, 2.5)


func _process(delta: float) -> void:
	_time += delta * _speed
	modulate.a = strength + sin(_time) * 0.12 + sin(_time * 3.7) * 0.05

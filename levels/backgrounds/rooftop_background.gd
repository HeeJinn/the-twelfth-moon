extends Node2D
## The storm over Ember Keep's roof, and the huge red moon in it. Now and then
## lightning flickers in the clouds: the bolts in the cloud ceiling fade in and
## out over half a second and the sky brightens a little with them. Gentle and
## rare, never a hard strobe. It pauses with the game.
##
## Scene: RooftopBackground (Node2D, this script)
##   Sky, Far, Near, Ceiling: Parallax2D cloud layers
##   %Bolts   Sprite2D under Ceiling, hidden until a flash
##   Moon     Parallax2D that does not scroll, in front of the clouds (the
##            ceiling scrolls and would otherwise hide it on the summit)
##   %Timer   Timer (one shot), restarted with a random wait after each flash

## Seconds between flashes.
@export var delay: Vector2 = Vector2(7.0, 13.0)

@onready var _bolts: Sprite2D = %Bolts
@onready var _timer: Timer = %Timer
@onready var _lit: Array[CanvasItem] = [$Sky as CanvasItem, $Far as CanvasItem, $Near as CanvasItem]


func _ready() -> void:
	_bolts.modulate.a = 0.0
	_timer.timeout.connect(flash)
	_wait()


## Lightning flickers in the clouds now.
func flash() -> void:
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(_bolts, "modulate:a", 1.0, 0.06)
	for layer: CanvasItem in _lit:
		tween.tween_property(layer, "modulate", Color(1.25, 1.25, 1.35), 0.06)
	tween.chain().tween_interval(0.1)
	tween.chain().tween_property(_bolts, "modulate:a", 0.0, 0.4)
	for layer: CanvasItem in _lit:
		tween.tween_property(layer, "modulate", Color.WHITE, 0.4)
	_wait()


func _wait() -> void:
	_timer.start(randf_range(delay.x, delay.y))

extends Node2D
## Chapter Three's sky, which changes as Mariane travels: the autumn hills
## with the castle on the horizon, then the deep golden wood (Pixel Valley)
## closing in overhead, then the winter hills, where snow starts to fall and
## thickens into a blizzard near the gate. Each set of layers fades in and
## out by where the camera is, so the season turns while she walks. Inside
## the ice cave (the shelter) no snow falls and the sky is lost in the dark.
##
## Scene: RoadBackground (Node2D, z_index -100, this script)
##   %Autumn, %Wood, %Winter   Node2D, each holding Parallax2D layers
##   RedMoon                   Parallax2D fixed to the screen
##   %CaveDark                 Parallax2D > the ice cave's back wall: dark
##                             stone tiled from Crawling Depths
##   %Weather                  Parallax2D fixed to the screen, drawn above
##                             the level (z 40) > Blizzard AnimatedSprite2D

## World x (px) where the golden wood begins and ends (full strength
## between, fading over `fade_width` at each end).
@export var wood_start: float = 2150.0
@export var wood_end: float = 3150.0
## World x where winter starts to fade in, and where it's complete.
@export var winter_from: float = 3450.0
@export var winter_to: float = 3950.0
@export var fade_width: float = 240.0
## Snow: starts falling at `snow_from`, is at its heaviest from `snow_full`.
@export var snow_from: float = 3600.0
@export var snow_full: float = 6600.0
@export_range(0.0, 1.0) var snow_light: float = 0.22
@export_range(0.0, 1.0) var snow_heavy: float = 0.6
## World x range of the ice cave: dark behind, no snow.
@export var shelter_from: float = 5184.0
@export var shelter_to: float = 5952.0

@onready var _autumn: Node2D = %Autumn
@onready var _wood: Node2D = %Wood
@onready var _winter: Node2D = %Winter
@onready var _weather: Node2D = %Weather
@onready var _cave_dark: Node2D = %CaveDark


func _process(_delta: float) -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return
	var x: float = camera.get_screen_center_position().x
	var winter: float = _ramp(x, winter_from, winter_to)
	var wood: float = minf(_ramp(x, wood_start - fade_width, wood_start),
			1.0 - _ramp(x, wood_end, wood_end + fade_width))
	_winter.modulate.a = winter
	_wood.modulate.a = wood * (1.0 - winter)
	_autumn.visible = winter < 1.0
	_wood.visible = _wood.modulate.a > 0.0
	var snow: float = 0.0
	if x >= snow_from:
		snow = lerpf(snow_light, snow_heavy, _ramp(x, snow_from, snow_full))
		snow *= _ramp(x, snow_from, snow_from + fade_width)
	var sheltered: float = minf(_ramp(x, shelter_from - fade_width, shelter_from + 60.0),
			1.0 - _ramp(x, shelter_to - 60.0, shelter_to + fade_width))
	snow *= 1.0 - sheltered
	_weather.modulate.a = snow
	_weather.visible = snow > 0.0
	_cave_dark.modulate.a = sheltered
	_cave_dark.visible = sheltered > 0.0


## 0 before `from`, 1 after `to`, smooth in between.
func _ramp(x: float, from: float, to: float) -> float:
	return smoothstep(from, to, x)

class_name TouchControls
extends CanvasLayer
## On-screen buttons for playing on a phone or tablet: the direction pad on the
## left, and jump, sword, shield, moon spark, dash and talk on the right, with
## pause in the top corner. Sword and shield work when held (the Moon Slash, the
## guard), like the keys. The buttons show on touch screens, hide when a key is
## pressed (a laptop with a touch screen) and come back on the next touch. While
## someone is talking they step aside, and a tap anywhere reads on. While the
## game is paused only the pause button stays. Holding the phone upright shows
## a note to turn it sideways.
##
## Scene: TouchControls (CanvasLayer, process always)
##   %Pad       DirectionPad
##   %Buttons   Node2D > TouchScreenButton per action (jump, attack, guard, ...)
##   %Pause     TouchScreenButton (pause)
##   %Upright   Control: the "turn your phone sideways" note

## How see-through the buttons are, so the game shows through them.
const BUTTON_ALPHA: float = 0.6

## For screenshots and tests on a computer: show the buttons anyway.
static var forced: bool = false

var _using_touch: bool = false
var _talking: bool = false
var _paused: bool = false

@onready var _pad: DirectionPad = %Pad
@onready var _buttons: Node2D = %Buttons
@onready var _pause: TouchScreenButton = %Pause
@onready var _upright: Control = %Upright


## True on a touch screen (or when `forced`).
static func is_touch() -> bool:
	return forced or DisplayServer.is_touchscreen_available()


## On a touch screen every tap is also sent as a left mouse click, which is
## bound to the sword: drop the mouse buttons from the sword and the shield, so
## a tap on the pad or the jump button doesn't swing as well. Called once at
## startup (GameManager).
static func adapt_input_map() -> void:
	if not DisplayServer.is_touchscreen_available():
		return
	for action: StringName in [&"attack", &"block"]:
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventMouseButton:
				InputMap.action_erase_event(action, event)


func _ready() -> void:
	_using_touch = is_touch()
	if DisplayServer.is_touchscreen_available():
		# Fill a phone's screen: whole-number scaling would leave wide borders.
		get_window().content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	for button: Node in _buttons.get_children():
		(button as CanvasItem).modulate.a = BUTTON_ALPHA
	_pause.modulate.a = BUTTON_ALPHA
	EventBus.dialogue_started.connect(func(_id: String) -> void:
		_talking = true
		_refresh())
	EventBus.dialogue_finished.connect(func(_id: String) -> void:
		_talking = false
		_refresh())
	EventBus.pause_toggled.connect(func(is_paused: bool) -> void:
		_paused = is_paused
		_refresh())
	_refresh()


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton:
		if _using_touch and not forced:
			_using_touch = false
			_refresh()
	elif event is InputEventScreenTouch and not _using_touch:
		_using_touch = true
		_refresh()


func _process(_delta: float) -> void:
	var size: Vector2i = get_window().size
	_upright.visible = _using_touch and size.y > size.x


func _refresh() -> void:
	visible = _using_touch
	var playing: bool = not _talking and not _paused
	_pad.visible = playing
	_buttons.visible = playing
	_pause.visible = not _talking

extends Control
## Title screen: "The Twelfth Moon" and a line for her. It opens slowly: the
## red moon rises in its glow, then the title, the line and the buttons fade in
## one after another (any key or click shows them at once). Under the blossom
## tree on the hill Mariane sleeps, as Chapter One begins; petals drift across
## the sky, the moon's glow breathes and now and then a star falls.
##
## Scene: TitleScreen (Control, full rect)
##   Background (TextureRect, the night sky)
##   %MoonGlow (Sprite2D, additive), %RedMoon (TextureRect)
##   ShootingStars, Hill (Polygon2D), FloweringTree, %Sleeper, PetalWind
##   CenterContainer > VBoxContainer
##     %TitleLabel, %SubtitleLabel, Gap, %StartButton, %ContinueButton,
##     %FullscreenButton (not in the Android app, always fullscreen), %QuitButton

## How far below its place the moon starts, and how long it takes to rise (s).
const MOON_RISE: float = 40.0
const RISE_TIME: float = 3.2
## The moon's slow bob once it has risen (px), and its glow's breathing.
const MOON_BOB: float = 2.0
const GLOW_ALPHA: float = 0.4
const GLOW_BREATH: float = 0.12
## When each part fades in (s from the start), and how long the fade takes.
const TITLE_AT: float = 1.0
const SUBTITLE_AT: float = 2.2
const BUTTONS_AT: float = 3.2
const FADE_TIME: float = 1.4

var _time: float = 0.0
var _moon_home: Vector2 = Vector2.ZERO
var _glow: float = 0.0
var _intro: Tween

@onready var _red_moon: TextureRect = %RedMoon
@onready var _moon_glow: Sprite2D = %MoonGlow
@onready var _sleeper: AnimatedSprite2D = %Sleeper
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _start_button: Button = %StartButton
@onready var _continue_button: Button = %ContinueButton
@onready var _fullscreen_button: Button = %FullscreenButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	Music.play(&"title")
	for button: Button in _buttons():
		button.mouse_entered.connect(Audio.effect.bind(&"ui_hover"))
		button.focus_entered.connect(Audio.effect.bind(&"ui_hover"))
		button.pressed.connect(Audio.effect.bind(&"ui_confirm"))
	# On a phone's browser the game goes fullscreen as it starts (the address
	# bar takes a third of a sideways screen); the tap allows it.
	if OS.has_feature("web") and TouchControls.is_touch():
		_start_button.pressed.connect(GameManager.set_fullscreen.bind(true))
		_continue_button.pressed.connect(GameManager.set_fullscreen.bind(true))
	_start_button.pressed.connect(GameManager.start_new_game)
	_continue_button.pressed.connect(GameManager.continue_game)
	_fullscreen_button.pressed.connect(GameManager.toggle_fullscreen)
	_quit_button.pressed.connect(get_tree().quit)
	_continue_button.visible = GameManager.has_progress()
	_fullscreen_button.visible = not OS.has_feature("android")
	# A browser tab can't be quit from inside the page.
	_quit_button.visible = not OS.has_feature("web")
	_start_button.grab_focus()  # Keyboard and gamepad navigation.
	_sleeper.play(&"asleep")
	_play_intro()


func _process(delta: float) -> void:
	_time += delta
	if _intro == null or not _intro.is_running():
		_red_moon.position.y = _moon_home.y + roundf(sin(_time * 0.9) * MOON_BOB)
	_moon_glow.position = _red_moon.position + _red_moon.size * 0.5
	# The browser can leave fullscreen on its own (Esc), so ask each frame.
	_fullscreen_button.text = "Window" if GameManager.is_fullscreen() else "Fullscreen"
	_moon_glow.modulate.a = (GLOW_ALPHA + GLOW_BREATH * sin(_time * 1.3)) * _glow


func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventKey or event is InputEventMouseButton
			or event is InputEventScreenTouch or event is InputEventJoypadButton) \
			and event.is_pressed()
	if pressed and _intro != null and _intro.is_running():
		_finish_intro()
		get_viewport().set_input_as_handled()


func _play_intro() -> void:
	_moon_home = _red_moon.position
	_red_moon.position.y = _moon_home.y + MOON_RISE
	_red_moon.modulate.a = 0.0
	for part: CanvasItem in _fading_parts():
		part.modulate.a = 0.0
	_intro = create_tween().set_parallel()
	_intro.tween_property(_red_moon, "position:y", _moon_home.y, RISE_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_intro.tween_property(_red_moon, "modulate:a", 1.0, RISE_TIME * 0.6)
	_intro.tween_property(self, "_glow", 1.0, RISE_TIME)
	_intro.tween_property(_title_label, "modulate:a", 1.0, FADE_TIME).set_delay(TITLE_AT)
	_intro.tween_property(_subtitle_label, "modulate:a", 1.0, FADE_TIME).set_delay(SUBTITLE_AT)
	for button: Button in _buttons():
		_intro.tween_property(button, "modulate:a", 1.0, FADE_TIME).set_delay(BUTTONS_AT)


## Any key or click during the opening shows everything at once.
func _finish_intro() -> void:
	_intro.kill()
	_red_moon.position.y = _moon_home.y
	_red_moon.modulate.a = 1.0
	_glow = 1.0
	for part: CanvasItem in _fading_parts():
		part.modulate.a = 1.0


func _fading_parts() -> Array[CanvasItem]:
	var parts: Array[CanvasItem] = [_title_label, _subtitle_label]
	parts.append_array(_buttons())
	return parts


func _buttons() -> Array[Button]:
	return [_start_button, _continue_button, _fullscreen_button, _quit_button]

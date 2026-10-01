extends Control
## Title screen: "The Twelfth Moon, a story for Mariane".
##
## Scene: TitleScreen (Control, full rect)
##   Background (TextureRect)
##   CenterContainer > VBoxContainer
##     TitleLabel, SubtitleLabel
##     %StartButton, %ContinueButton, %QuitButton

@onready var _start_button: Button = %StartButton
@onready var _continue_button: Button = %ContinueButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	Music.play(&"title")
	for button: Button in [_start_button, _continue_button, _quit_button]:
		button.mouse_entered.connect(Audio.effect.bind(&"ui_hover"))
		button.focus_entered.connect(Audio.effect.bind(&"ui_hover"))
		button.pressed.connect(Audio.effect.bind(&"ui_confirm"))
	_start_button.pressed.connect(GameManager.start_new_game)
	_continue_button.pressed.connect(GameManager.continue_game)
	_quit_button.pressed.connect(get_tree().quit)
	_continue_button.visible = GameManager.has_progress()
	# A browser tab can't be quit from inside the page.
	_quit_button.visible = not OS.has_feature("web")
	_start_button.grab_focus()  # Keyboard and gamepad navigation.

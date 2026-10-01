extends Control
## Shown after the last chapter in GameManager.LEVELS. While the story is
## being built it says "to be continued"; the real ending replaces it later.
##
## Scene: EndScreen (Control, full rect)
##   CenterContainer > VBoxContainer
##     %MessageLabel (Label, autowrap on, fixed min width)
##     %StatsLabel (Label)
##     %PlayAgainButton, %TitleButton (Button)

## Number words, because the Pixelmax font has no digits.
const NUMBER_WORDS: Array[String] = [
	"no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
	"ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen",
	"seventeen", "eighteen", "nineteen", "twenty", "twenty-one",
]

## The message. Edit it in the Inspector of end_screen.tscn.
@export_multiline var message: String = "To be continued..."

@onready var _message_label: Label = %MessageLabel
@onready var _stats_label: Label = %StatsLabel
@onready var _play_again_button: Button = %PlayAgainButton
@onready var _title_button: Button = %TitleButton


func _ready() -> void:
	Music.play(&"credits")
	_message_label.text = message
	var petals: int = GameManager.total_collected
	var word: String = NUMBER_WORDS[clampi(petals, 0, NUMBER_WORDS.size() - 1)]
	_stats_label.text = "You found %s petal%s." % [word, "" if petals == 1 else "s"]
	_play_again_button.pressed.connect(GameManager.start_new_game)
	_title_button.pressed.connect(GameManager.go_to_title)
	_play_again_button.grab_focus()  # Keyboard and gamepad navigation.

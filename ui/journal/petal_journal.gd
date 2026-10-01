extends CanvasLayer
## The petal journal: each petal she finds brings back one line of her past
## life (story/petal_journal.txt, in order). A new line shows at the top of the
## screen for a few seconds. On the pause screen, "Petal journal" opens the
## book: two lines to a page, up to the newest one found; the lines still to
## come show as "...". The arrow keys (or A/D) and the page buttons turn the
## pages, Back returns to the pause screen, and unpausing closes it.
##
## Scene: PetalJournal (CanvasLayer above the HUD, always processing)
##   %Toast (Label, under the boss bar; hidden while paused)
##   %OpenButton (Button, bottom centre, shown while paused)
##   %Book (Control, full rect, hidden)
##     Shade (ColorRect), Art (TextureRect, journal_book.png)
##     %LeftPage, %RightPage (VBoxContainers inside each page's frame, two Labels each)
##     %PrevButton, %NextButton (in the pages' bottom corners), %BackButton (below)

const ENTRIES_PER_PAGE: int = 2
const INK: Color = Color(0.29, 0.18, 0.19)
const FADED_INK: Color = Color(0.29, 0.18, 0.19, 0.3)
const BLANK_TEXT: String = "..."
const TOAST_FADE: float = 0.5
const TOAST_HOLD: float = 4.5

@export_file("*.txt") var lines_path: String = "res://story/petal_journal.txt"

var _lines: PackedStringArray = PackedStringArray()
## Petals found the last time a petal was picked up.
var _known: int = 0
var _spread: int = 0
var _toast_tween: Tween

@onready var _toast: Label = %Toast
@onready var _open_button: Button = %OpenButton
@onready var _book: Control = %Book
@onready var _left_page: VBoxContainer = %LeftPage
@onready var _right_page: VBoxContainer = %RightPage
@onready var _prev_button: Button = %PrevButton
@onready var _next_button: Button = %NextButton
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_lines = read_lines(lines_path)
	_known = GameManager.petals_found()
	_toast.modulate.a = 0.0
	_book.hide()
	_open_button.hide()
	EventBus.collectible_collected.connect(_on_collectible_collected)
	EventBus.pause_toggled.connect(_on_pause_toggled)
	_open_button.pressed.connect(open_book)
	_prev_button.pressed.connect(turn_page.bind(-1))
	_next_button.pressed.connect(turn_page.bind(1))
	_back_button.pressed.connect(close_book)


func _unhandled_input(event: InputEvent) -> void:
	if not _book.visible:
		return
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		turn_page(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		turn_page(1)
		get_viewport().set_input_as_handled()


## The journal's lines, one per petal, from a text file ("#" lines are notes).
static func read_lines(path: String) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Cannot read the petal journal '%s'. In an exported build, add *.txt "
				% path + "to the export preset's non-resource filter.")
	for raw_line: String in text.replace("\r", "").split("\n"):
		var line: String = raw_line.strip_edges()
		if not line.is_empty() and not line.begins_with("#"):
			lines.append(line)
	return lines


## The line the newest petal brought back (empty before the first one).
func newest_line() -> String:
	var found: int = mini(GameManager.petals_found(), _lines.size())
	return _lines[found - 1] if found > 0 else ""


func is_open() -> bool:
	return _book.visible


## The text on the open spread, left page then right, for tests.
func spread_text() -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for page: VBoxContainer in [_left_page, _right_page]:
		for child: Node in page.get_children():
			texts.append((child as Label).text)
	return texts


func open_book() -> void:
	Audio.effect(&"ui_confirm")
	_spread = _last_spread()
	_show_spread()
	_open_button.hide()
	_book.show()
	if _next_button.visible:
		_next_button.grab_focus()
	else:
		_back_button.grab_focus()


func close_book() -> void:
	_book.hide()
	if get_tree().paused:
		_open_button.show()
		_open_button.grab_focus()


func turn_page(step: int) -> void:
	var spread: int = clampi(_spread + step, 0, _last_spread())
	if spread == _spread:
		return
	_spread = spread
	Audio.effect(&"ui_hover")
	_show_spread()


## The spread holding the newest line found.
func _last_spread() -> int:
	var found: int = mini(GameManager.petals_found(), _lines.size())
	@warning_ignore("integer_division")
	return maxi(found - 1, 0) / (ENTRIES_PER_PAGE * 2)


func _show_spread() -> void:
	var found: int = GameManager.petals_found()
	var first: int = _spread * ENTRIES_PER_PAGE * 2
	_fill_page(_left_page, first, found)
	_fill_page(_right_page, first + ENTRIES_PER_PAGE, found)
	_prev_button.visible = _spread > 0
	_next_button.visible = _spread < _last_spread()


func _fill_page(page: VBoxContainer, first: int, found: int) -> void:
	for i: int in ENTRIES_PER_PAGE:
		var label: Label = page.get_child(i) as Label
		var index: int = first + i
		if index >= _lines.size():
			label.text = ""
		elif index < found:
			label.text = _lines[index]
			label.add_theme_color_override(&"font_color", INK)
		else:
			label.text = BLANK_TEXT
			label.add_theme_color_override(&"font_color", FADED_INK)


func _show_toast(text: String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, TOAST_FADE)
	_toast_tween.tween_interval(TOAST_HOLD)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, TOAST_FADE * 2.0)


func _on_collectible_collected(_value: int) -> void:
	var found: int = GameManager.petals_found()
	if found > _known and found <= _lines.size():
		_show_toast(_lines[found - 1])
	_known = maxi(_known, found)


func _on_pause_toggled(is_paused: bool) -> void:
	_book.hide()
	_toast.visible = not is_paused
	_open_button.visible = is_paused
	if is_paused:
		_open_button.grab_focus()

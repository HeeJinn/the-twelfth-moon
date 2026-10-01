extends Control
## The credits: every line of credits.txt rolls up over the night sky to the
## credits music, and the last line stops in the middle of the screen. Holding
## jump, attack, interact or a finger on the screen rolls faster; Esc (pause)
## skips. Then the after-credits scene.
##
## Scene: Credits (Control, full rect)
##   Background (TextureRect, the purple stars)
##   %Roll (VBoxContainer; its lines are built here from credits.txt)
##   HintLayer > %SkipLabel

const HEADING_COLOR: Color = Color(1.0, 0.8, 0.88)
## Height of an empty line, and the extra space above a heading (px).
const GAP: float = 10.0
## How fast the lines rise (px/s), and how much faster while held.
const SPEED: float = 22.0
const FAST: float = 5.0
const FAST_ACTIONS: Array[StringName] = [&"jump", &"attack", &"interact"]
## How long the last line stays in the middle before moving on (s).
const LAST_HOLD: float = 4.0

@export_file("*.txt") var credits_path: String = "res://ui/credits/credits.txt"
@export_file("*.tscn") var next_scene: String = "res://story/ending/after_credits.tscn"
## Pixelmax with drawn digits as its fallback (licences have version numbers).
@export var font: Font

var _is_rolling: bool = false
var _has_finished: bool = false
var _is_leaving: bool = false
var _is_touching: bool = false
var _last_line: Control

@onready var _roll: VBoxContainer = %Roll
@onready var _skip_label: Label = %SkipLabel


func _ready() -> void:
	Music.play(&"credits")
	_build(FileAccess.get_file_as_string(credits_path))
	var hint: Tween = create_tween()
	hint.tween_interval(4.0)
	hint.tween_property(_skip_label, "modulate:a", 0.0, 1.0)
	# The roll knows its height once its lines are laid out.
	await get_tree().process_frame
	_roll.position.y = size.y
	_is_rolling = true


func _process(delta: float) -> void:
	if not _is_rolling:
		return
	var speed: float = SPEED * (FAST if _is_fast() else 1.0)
	_roll.position.y -= speed * delta
	if _last_line != null and _roll.position.y + _last_line.position.y \
			+ _last_line.size.y * 0.5 <= size.y * 0.5:
		_is_rolling = false
		_has_finished = true
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_leave()
	elif event is InputEventScreenTouch:
		_is_touching = (event as InputEventScreenTouch).pressed


## True once the last line has reached the middle of the screen.
func is_finished() -> bool:
	return _has_finished


func _is_fast() -> bool:
	if _is_touching:
		return true
	for action: StringName in FAST_ACTIONS:
		if Input.is_action_pressed(action):
			return true
	return false


func _build(text: String) -> void:
	if text.is_empty():
		push_error("Cannot read the credits '%s'. In an exported build, add *.txt to the "
				% credits_path + "export preset's non-resource filter.")
	for raw_line: String in text.replace("\r", "").split("\n"):
		var line: String = raw_line.strip_edges()
		if line.begins_with("#"):
			continue
		if line.is_empty():
			var gap: Control = Control.new()
			gap.custom_minimum_size = Vector2(0.0, GAP)
			_roll.add_child(gap)
			continue
		var label: Label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if font != null:
			label.add_theme_font_override(&"font", font)
		if line.begins_with("[") and line.ends_with("]"):
			label.text = line.substr(1, line.length() - 2)
			label.add_theme_color_override(&"font_color", HEADING_COLOR)
			var space: Control = Control.new()
			space.custom_minimum_size = Vector2(0.0, GAP)
			_roll.add_child(space)
		else:
			label.text = line
		_roll.add_child(label)
		_last_line = label


func _finish() -> void:
	await get_tree().create_timer(LAST_HOLD).timeout
	_leave()


func _leave() -> void:
	if _is_leaving:
		return
	_is_leaving = true
	_is_rolling = false
	SceneManager.change_scene(next_scene)

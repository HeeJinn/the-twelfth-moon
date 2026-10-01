class_name DialogueBox
extends CanvasLayer
## Plays conversations from the chapter's dialogue script at the bottom of
## the screen: portrait, name, text typed out letter by letter.
##
## Anyone asks for a conversation with EventBus.dialogue_requested(id); this
## box announces dialogue_started / dialogue_finished. Interact, jump, attack
## or a click shows the whole line, then moves to the next one.
##
## Scene: DialogueBox (CanvasLayer, layer 20)
##   %Panel (PanelContainer, bottom of the screen) > MarginContainer > HBox
##     %PortraitFrame (PanelContainer) > %Portrait (TextureRect)
##     VBox > %NameLabel, %TextLabel
##   %NextArrow (TextureRect, bottom-right of the panel)

const CHARACTERS_PER_SECOND: float = 45.0
const ARROW_BOB: float = 2.0
const NARRATOR_COLOR: Color = Color(0.9, 0.88, 1.0)
const ADVANCE_ACTIONS: Array[StringName] = [&"interact", &"jump", &"attack"]
## A villager's hello and goodbye are this much quieter than a cry (dB).
const GREETING_VOLUME_DB: float = -4.0

## Everyone who can speak. Unknown names still show, without a portrait.
@export var speakers: SpeakerLibrary
## Optional: load this script on start (for scenes without a level).
@export_file("*.txt") var script_path: String = ""
## Odds that a villager says hello as a conversation opens with them (the
## first time only), and goodbye as it closes.
@export_range(0.0, 1.0) var greet_chance: float = 0.8
@export_range(0.0, 1.0) var farewell_chance: float = 0.4

var _script: DialogueScript
var _lines: Array[DialogueScript.Line] = []
var _index: int = 0
var _requested_id: String = ""
var _is_open: bool = false
var _is_typing: bool = false
var _typed: float = 0.0
var _heard: Dictionary[String, bool] = {}
## Who greeted as this conversation opened, and says goodbye as it closes.
var _greeter: Speaker
var _arrow_time: float = 0.0
var _arrow_base_y: float = 0.0

@onready var _panel: PanelContainer = %Panel
@onready var _portrait_frame: PanelContainer = %PortraitFrame
@onready var _portrait: TextureRect = %Portrait
@onready var _name_label: Label = %NameLabel
@onready var _text_label: Label = %TextLabel
@onready var _next_arrow: TextureRect = %NextArrow


func _ready() -> void:
	_panel.hide()
	_next_arrow.hide()
	_arrow_base_y = _next_arrow.position.y
	EventBus.dialogue_requested.connect(_on_dialogue_requested)
	if not script_path.is_empty():
		load_script(script_path)


func _process(delta: float) -> void:
	if not _is_open:
		return
	if _is_typing:
		_typed += CHARACTERS_PER_SECOND * delta
		_text_label.visible_characters = int(_typed)
		if _text_label.visible_characters >= _text_label.get_total_character_count():
			_finish_typing()
	else:
		_arrow_time += delta
		_next_arrow.position.y = _arrow_base_y + roundf(sin(_arrow_time * 6.0) * ARROW_BOB)


func _unhandled_input(event: InputEvent) -> void:
	if _is_open and _is_advance(event):
		get_viewport().set_input_as_handled()
		_advance()


## A tap on a touch screen reads on. Caught here, before the box's own panel
## (a GUI control) would take the touch for itself.
func _input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if _is_open and touch != null and touch.pressed:
		get_viewport().set_input_as_handled()
		_advance()


func _advance() -> void:
	if _is_typing:
		_finish_typing()
	else:
		_show_line(_index + 1)


## Reads the conversations for this chapter (see DialogueScript for the format).
func load_script(path: String) -> void:
	_script = DialogueScript.load_file(path)


func is_open() -> bool:
	return _is_open


func _on_dialogue_requested(dialogue_id: String) -> void:
	if _is_open:
		return
	_requested_id = dialogue_id
	var play_id: String = dialogue_id
	if _heard.has(dialogue_id) and _script != null and _script.has(dialogue_id + "_again"):
		play_id = dialogue_id + "_again"
	var first_time: bool = not _heard.has(dialogue_id)
	_heard[dialogue_id] = true
	_lines = _script.get_lines(play_id) if _script != null else []
	if _lines.is_empty():
		push_warning("No dialogue named '%s'." % play_id)
		# Still report it, next frame, so a waiting cutscene doesn't hang.
		EventBus.dialogue_finished.emit.call_deferred(dialogue_id)
		return
	_is_open = true
	_panel.show()
	EventBus.dialogue_started.emit(dialogue_id)
	_show_line(0)
	_greeter = _first_speaker()
	if _greeter != null and first_time:
		Audio.voice(_greeter.voice_bank, &"greet", greet_chance, 1.0, GREETING_VOLUME_DB)


func _show_line(index: int) -> void:
	if index >= _lines.size():
		_close()
		return
	_index = index
	var line: DialogueScript.Line = _lines[index]
	var speaker: Speaker = speakers.find(line.speaker_name) if speakers else null
	_name_label.visible = not line.speaker_name.is_empty()
	if speaker != null:
		_name_label.text = speaker.shown_as if not speaker.shown_as.is_empty() else speaker.display_name
		_name_label.add_theme_color_override("font_color", speaker.name_color)
	else:
		_name_label.text = line.speaker_name
		_name_label.remove_theme_color_override("font_color")
	_portrait_frame.visible = speaker != null and speaker.portrait != null
	if _portrait_frame.visible:
		_portrait.texture = speaker.portrait
	var is_narration: bool = line.speaker_name.is_empty()
	if is_narration:
		_text_label.add_theme_color_override("font_color", NARRATOR_COLOR)
	else:
		_text_label.remove_theme_color_override("font_color")
	_text_label.text = line.text
	_text_label.visible_characters = 0
	_typed = 0.0
	_is_typing = true
	_next_arrow.hide()


func _finish_typing() -> void:
	_is_typing = false
	_text_label.visible_characters = -1
	_arrow_time = 0.0
	_next_arrow.show()


## The first line's speaker, when they greet people and have a voice.
func _first_speaker() -> Speaker:
	var line: DialogueScript.Line = _lines[0]
	var speaker: Speaker = speakers.find(line.speaker_name) if speakers else null
	if speaker == null or not speaker.greets or speaker.voice_bank.is_empty():
		return null
	return speaker


func _close() -> void:
	if _greeter != null:
		Audio.voice(_greeter.voice_bank, &"farewell", farewell_chance, 1.0, GREETING_VOLUME_DB)
		_greeter = null
	_is_open = false
	_is_typing = false
	_panel.hide()
	_next_arrow.hide()
	EventBus.dialogue_finished.emit(_requested_id)


func _is_advance(event: InputEvent) -> bool:
	if event.is_echo():
		return false
	for action: StringName in ADVANCE_ACTIONS:
		if event.is_action_pressed(action):
			return true
	return false

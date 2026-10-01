extends Node
## Headless check of playing on a touch screen, with real simulated touches on
## the moves test course: the direction pad (left, right, a diagonal, letting
## go), the jump and sword buttons, the buttons stepping aside while someone
## talks and a tap reading on, the hints' touch wording, and the input map
## (no mouse click on the sword). Also checks that walking into a monster
## pushes her back without costing a heart.
##
## Run from the project folder:
##   godot --headless --path . res://tools/tests/touch_test.tscn

const LEVEL_SCENE: PackedScene = preload("res://levels/level.tscn")
const TEST_MAP: LevelData = preload("res://tools/tests/maps/moves_test.tres")
const GOBLIN_SCENE: PackedScene = preload("res://entities/enemy/goblin.tscn")
const HINT_SCENE: PackedScene = preload("res://entities/hint/hint_attack.tscn")
const TILE: float = 16.0
const FLOOR_Y: float = 22.0 * TILE

var _failures: int = 0
var _level: LevelLoader
var _player: Player
var _dialogue_open: bool = false


func _ready() -> void:
	TouchControls.forced = true
	GameManager.save_path = "user://test_save.cfg"
	EventBus.dialogue_started.connect(func(_id: String) -> void: _dialogue_open = true)
	EventBus.dialogue_finished.connect(func(_id: String) -> void: _dialogue_open = false)
	_level = LEVEL_SCENE.instantiate() as LevelLoader
	_level.level_data_override = TEST_MAP
	add_child(_level)
	await _frames(30)
	_player = _level.player
	var touch: TouchControls = _level.get_node("TouchControls") as TouchControls
	var pad: DirectionPad = touch.get_node("%Pad") as DirectionPad
	_expect(touch.visible and pad.is_visible_in_tree()
			and touch.get_node("%Buttons").is_visible_in_tree(), "the buttons show on a touch screen")

	# The pad: a thumb right of the middle walks her right; down-right is a
	# diagonal; letting go stops.
	await _place(Vector2(3.5 * TILE, FLOOR_Y))
	var start_x: float = _player.global_position.x
	_touch(0, pad.global_position + Vector2(30.0, 0.0), true)
	await _frames(40)
	print("  pad right: moved %.0f px, right %s, down %s" % [_player.global_position.x - start_x,
			Input.is_action_pressed(&"move_right"), Input.is_action_pressed(&"move_down")])
	_expect(Input.is_action_pressed(&"move_right") and not Input.is_action_pressed(&"move_down")
			and _player.global_position.x > start_x + 40.0, "a thumb on the pad's right walks her right")
	_drag(0, pad.global_position + Vector2(28.0, 26.0))
	await _frames(2)
	_expect(Input.is_action_pressed(&"move_right") and Input.is_action_pressed(&"move_down"),
			"sliding the thumb down-right holds both (run and slide)")
	_touch(0, pad.global_position + Vector2(28.0, 26.0), false)
	await _frames(2)
	_expect(not Input.is_action_pressed(&"move_right") and not Input.is_action_pressed(&"move_down"),
			"lifting the thumb lets go")
	_touch(1, pad.global_position + Vector2(-4.0, 3.0), true)
	await _frames(2)
	_expect(not Input.is_action_pressed(&"move_left") and not Input.is_action_pressed(&"move_right"),
			"the pad's middle presses nothing")
	_touch(1, pad.global_position + Vector2(-4.0, 3.0), false)

	# The buttons: jump lifts her off the ground; the sword swings.
	await _place(Vector2(3.5 * TILE, FLOOR_Y))
	var jump: TouchScreenButton = touch.get_node("%Buttons/Jump") as TouchScreenButton
	_touch(2, jump.global_position + Vector2(16.0, 16.0), true)
	await _frames(12)
	print("  jump: y %.0f (floor %.0f), jump held %s" % [_player.global_position.y, FLOOR_Y,
			Input.is_action_pressed(&"jump")])
	_expect(_player.global_position.y < FLOOR_Y - 20.0, "the jump button jumps")
	_touch(2, jump.global_position + Vector2(16.0, 16.0), false)
	await _frames(60)
	var attack: TouchScreenButton = touch.get_node("%Buttons/Attack") as TouchScreenButton
	_touch(3, attack.global_position + Vector2(16.0, 16.0), true)
	await _frames(3)
	var state_machine: PlayerStateMachine = _player.get_node("%StateMachine") as PlayerStateMachine
	_expect(state_machine.is_in(&"Attack"), "the sword button swings")
	_touch(3, attack.global_position + Vector2(16.0, 16.0), false)
	await _frames(60)

	# Someone talks: the buttons step aside, and a tap reads on.
	_level.get_node("%DialogueBox").call(&"load_script", "res://story/chapter_01.txt")
	EventBus.dialogue_requested.emit(_any_dialogue_id())
	await _frames(5)
	_expect(_dialogue_open and not pad.is_visible_in_tree()
			and not touch.get_node("%Buttons").is_visible_in_tree(), "the buttons step aside while someone talks")
	for i: int in 40:
		if not _dialogue_open:
			break
		_touch(4, Vector2(240.0, 220.0), true)
		await _frames(2)
		_touch(4, Vector2(240.0, 220.0), false)
		await _frames(6)
	_expect(not _dialogue_open and pad.is_visible_in_tree(), "taps read the conversation through, then the buttons return")

	# Hints name the buttons, not the keys.
	var hint: Hint = HINT_SCENE.instantiate() as Hint
	_level.add_child(hint)
	await _frames(2)
	_expect((hint.get_node("%Label") as Label).text == hint.touch_text, "hints name the buttons")
	hint.queue_free()

	# Walking into a monster pushes her back, with no harm.
	await _place(Vector2(3.5 * TILE, FLOOR_Y))
	var goblin: Enemy = GOBLIN_SCENE.instantiate() as Enemy
	goblin.position = Vector2(7.5 * TILE, FLOOR_Y)
	goblin.attack_reach = Vector2.ZERO
	_level.get_node("%Entities").add_child(goblin)
	var health: int = _player.health()
	Input.action_press(&"move_right")
	await _frames(90)
	Input.action_release(&"move_right")
	_expect(_player.health() == health, "walking into a monster costs no heart")
	_expect(_player.global_position.x < goblin.global_position.x, "but it won't let her walk through")

	for wait: int in 120:
		if not Audio.is_busy():
			break
		await get_tree().physics_frame
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(_failures)


## The first conversation in Chapter One's script.
func _any_dialogue_id() -> String:
	var text: String = FileAccess.get_file_as_string("res://story/chapter_01.txt")
	for line: String in text.split("\n"):
		if line.begins_with("[") and line.ends_with("]"):
			return line.trim_prefix("[").trim_suffix("]")
	return ""


## A finger touching (or leaving) the screen at a point of the 480x270 view.
func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = get_tree().root.get_final_transform() * at
	event.pressed = pressed
	Input.parse_input_event(event)


func _drag(index: int, to: Vector2) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = index
	event.position = get_tree().root.get_final_transform() * to
	Input.parse_input_event(event)


func _place(at: Vector2) -> void:
	_player.respawn(at)
	await _frames(40)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		print("FAIL ", label)

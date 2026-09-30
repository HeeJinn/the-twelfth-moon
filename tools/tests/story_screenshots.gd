extends Node
## Saves screenshots of the story scenes for checking without playing.
## Needs a window (not headless).
##
## Run from the project folder, once per part:
##   godot --path . res://tools/tests/story_screenshots.tscn -- <folder> prologue
##   godot --path . res://tools/tests/story_screenshots.tscn -- <folder> chapter

const PROLOGUE_SCENE: PackedScene = preload("res://story/prologue/prologue.tscn")
const LEVEL_SCENE: PackedScene = preload("res://levels/level.tscn")
const TILE: float = 32.0
## Village columns to photograph, walking east.
const VILLAGE_SPOTS: Array[int] = [13, 24, 34, 44, 52, 66, 104]
## Frames after Mariane's first line at the shrine -> screenshot name.
const SHRINE_MOMENTS: Dictionary[int, String] = {
	150: "kael_arrives", 220: "shard_pull", 336: "fire_slam", 380: "shrine_burning",
}

var _output_dir: String = ""
var _dialogue_open: bool = false
var _current_dialogue: String = ""


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_output_dir = args[0] if args.size() > 0 else OS.get_user_data_dir()
	var part: String = args[1] if args.size() > 1 else "chapter"
	EventBus.dialogue_started.connect(func(id: String) -> void:
		_dialogue_open = true
		_current_dialogue = id)
	EventBus.dialogue_finished.connect(func(_id: String) -> void: _dialogue_open = false)
	if part == "prologue":
		await _shoot_prologue()
	else:
		await _shoot_chapter()
	get_tree().quit()


func _shoot_prologue() -> void:
	add_child(PROLOGUE_SCENE.instantiate())
	await _frames(200)
	await _capture("p1_opening")
	await _read_until("prologue_1")
	await _frames(90)
	await _capture("p2_lovers")
	await _finish_dialogue()
	await _frames(150)
	await _capture("p3_moon_swells")
	await _frames(150)
	await _capture("p4_she_falls")


func _shoot_chapter() -> void:
	var level: LevelLoader = LEVEL_SCENE.instantiate() as LevelLoader
	add_child(level)
	await _frames(100)
	await _capture("c0_chapter_card")
	await _frames_until(func() -> bool: return _dialogue_open, 400)
	await _frames(90)
	await _capture("c1_wake_up")
	await _finish_dialogue()
	for column: int in VILLAGE_SPOTS:
		level.player.respawn(Vector2(column * TILE + TILE / 2.0, 9 * TILE))
		await _frames(150)
		await _capture("c2_x%d" % column)
		if _dialogue_open:
			await _frames(40)
			await _capture("c2_x%d_talk_%s" % [column, _current_dialogue])
			await _finish_dialogue()

	var scene: Cutscene = null
	for child: Node in level.get_node("%Entities").get_children():
		if child is Cutscene:
			scene = child
	level.player.respawn(scene.global_position + Vector2(-240.0, 0.0))
	await _frames(60)
	Input.action_press("move_right")
	await _frames_until(func() -> bool: return _dialogue_open, 300)
	Input.action_release("move_right")
	await _frames(60)
	await _capture("s0_arrive")
	await _finish_dialogue()
	var frame: int = 0
	var captured: Array[String] = []
	while frame < 3000 and GameManager.state != GameManager.GameState.WON:
		if SHRINE_MOMENTS.has(frame):
			await _capture("s1_" + SHRINE_MOMENTS[frame])
		if _dialogue_open and not captured.has(_current_dialogue):
			captured.append(_current_dialogue)
			await _frames(70)
			frame += 70
			await _capture("s2_" + _current_dialogue)
		if _dialogue_open:
			await _press("interact")
			await _frames(6)
			frame += 7
		else:
			await get_tree().physics_frame
			frame += 1


func _read_until(dialogue_id: String) -> void:
	for i: int in 400:
		if _dialogue_open and _current_dialogue == dialogue_id:
			return
		if _dialogue_open:
			await _press("interact")
			await _frames(6)
		else:
			await get_tree().physics_frame


func _finish_dialogue() -> void:
	for i: int in 80:
		if not _dialogue_open:
			return
		await _press("interact")
		await _frames(6)


func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().physics_frame


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(_output_dir.path_join(file_name + ".png"))
	print("saved ", file_name)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _frames_until(condition: Callable, limit: int) -> void:
	for i: int in limit:
		if condition.call():
			return
		await get_tree().physics_frame

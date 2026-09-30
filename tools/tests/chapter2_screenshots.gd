extends Node
## Saves screenshots of Chapter Two, the Ember memory, and the Chapter One
## village, for checking art without playing. Needs a window (not headless).
##
## Run from the project folder, once per part:
##   godot --path . res://tools/tests/chapter2_screenshots.tscn -- <folder> forest
##   godot --path . res://tools/tests/chapter2_screenshots.tscn -- <folder> fight
##   godot --path . res://tools/tests/chapter2_screenshots.tscn -- <folder> memory
##   godot --path . res://tools/tests/chapter2_screenshots.tscn -- <folder> village

const LEVEL_SCENE: PackedScene = preload("res://levels/level.tscn")
const MEMORY_SCENE: PackedScene = preload("res://story/memories/memory_ember.tscn")
const TILE: float = 16.0
## Forest spots to photograph: (column, feet row).
const FOREST_SPOTS: Array[Vector2] = [
	Vector2(12, 28), Vector2(44, 28), Vector2(62, 28), Vector2(80, 28), Vector2(116, 28),
	Vector2(136, 12), Vector2(153, 18), Vector2(158, 4), Vector2(177, 6), Vector2(190, 5),
	Vector2(234, 28),
]

var _output_dir: String = ""
var _dialogue_open: bool = false


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_output_dir = args[0] if args.size() > 0 else OS.get_user_data_dir()
	var part: String = args[1] if args.size() > 1 else "forest"
	EventBus.dialogue_started.connect(func(_id: String) -> void: _dialogue_open = true)
	EventBus.dialogue_finished.connect(func(_id: String) -> void: _dialogue_open = false)
	match part:
		"forest":
			await _shoot_forest()
		"fight":
			await _shoot_fight()
		"memory":
			await _shoot_memory()
		"village":
			await _shoot_village()
	get_tree().quit()


func _load_chapter(index: int) -> LevelLoader:
	GameManager.current_level_index = index
	var level: LevelLoader = LEVEL_SCENE.instantiate() as LevelLoader
	add_child(level)
	await _frames(60)
	return level


func _shoot_forest() -> void:
	var level: LevelLoader = await _load_chapter(1)
	await _capture("f00_start")
	for spot: Vector2 in FOREST_SPOTS:
		level.player.respawn(Vector2(spot.x * TILE + TILE / 2.0, spot.y * TILE))
		await _frames(60)
		if _dialogue_open:
			await _frames(40)
			await _capture("f_x%d_talk" % spot.x)
			await _finish_dialogue()
		await _capture("f_x%d" % spot.x)
	# A goblin throwing a bomb.
	level.player.respawn(Vector2(91.0 * TILE, 28.0 * TILE))
	await _frames(55)
	await _capture("f_goblin_throw")
	await _frames(35)
	await _capture("f_bomb_explodes")


func _shoot_fight() -> void:
	var level: LevelLoader = await _load_chapter(1)
	level.player.respawn(Vector2(252.0 * TILE, 28.0 * TILE))
	await _frames(40)
	Input.action_press("move_right")
	await _frames_until(func() -> bool: return _dialogue_open, 400)
	Input.action_release("move_right")
	await _frames(60)
	await _capture("w0_intro")
	await _finish_dialogue()
	for i: int in 6:
		await _frames(35)
		await _capture("w%d_fight" % (i + 1))


func _shoot_memory() -> void:
	add_child(MEMORY_SCENE.instantiate())
	await _frames(150)
	await _capture("m0_opening")
	await _press(&"interact")
	await _frames(10)
	await _press(&"interact")
	await _frames(20)
	for i: int in 5:
		await _frames(60)
		await _capture("m%d" % (i + 1))
		await _press(&"interact")
		await _frames(8)
		await _press(&"interact")


func _shoot_village() -> void:
	var level: LevelLoader = await _load_chapter(0)
	await _frames_until(func() -> bool: return _dialogue_open, 400)
	await _finish_dialogue()
	for column: int in [8, 20, 40]:
		level.player.respawn(Vector2(column * 32.0 + 16.0, 9.0 * 32.0))
		for shot: int in 3:
			await _frames(50)
			await _capture("v_x%d_%d" % [column, shot])
			if _dialogue_open:
				await _finish_dialogue()


func _finish_dialogue() -> void:
	for i: int in 80:
		if not _dialogue_open:
			return
		await _press(&"interact")
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
	get_viewport().get_texture().get_image().save_png(_output_dir.path_join(file_name + ".png"))
	print("saved ", file_name)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _frames_until(condition: Callable, limit: int) -> void:
	for i: int in limit:
		if condition.call():
			return
		await get_tree().physics_frame

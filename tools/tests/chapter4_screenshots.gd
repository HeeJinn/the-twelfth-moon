extends Node
## Saves screenshots of Chapter Four, Ember Keep, for checking its art and
## layout without playing. Needs a window (not headless).
##
## Run from the project folder:
##   godot --path . res://tools/tests/chapter4_screenshots.tscn -- <output folder>

const LEVEL_SCENE: PackedScene = preload("res://levels/level.tscn")
const TILE: float = 16.0
## Spots to photograph: (column, row of the floor she stands on).
const SPOTS: Array[Vector2] = [
	Vector2(6, 22), Vector2(27, 22), Vector2(52, 20), Vector2(74, 20), Vector2(91, 22),
	Vector2(120, 10), Vector2(134, 10), Vector2(147, 10), Vector2(170, 10), Vector2(183, 10),
	Vector2(196, 16), Vector2(224, 24), Vector2(229, 24), Vector2(255, 24), Vector2(270, 24),
	Vector2(290, 24), Vector2(302, 24), Vector2(316, 24),
]

var _output_dir: String = ""
var _dialogue_open: bool = false


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_output_dir = args[0] if args.size() > 0 else OS.get_user_data_dir()
	EventBus.dialogue_started.connect(func(_id: String) -> void: _dialogue_open = true)
	EventBus.dialogue_finished.connect(func(_id: String) -> void: _dialogue_open = false)
	GameManager.save_path = "user://test_save.cfg"
	GameManager.current_level_index = 3
	var level: LevelLoader = LEVEL_SCENE.instantiate() as LevelLoader
	add_child(level)
	await _frames(80)
	await _capture("k00_start")
	for spot: Vector2 in SPOTS:
		level.player.respawn(Vector2(spot.x * TILE + TILE / 2.0, spot.y * TILE))
		await _frames(75)
		# A thought may have started here: read it through so it doesn't cover the shot.
		for i: int in 60:
			if not _dialogue_open:
				break
			for pressed: bool in [true, false]:
				var event: InputEventAction = InputEventAction.new()
				event.action = &"interact"
				event.pressed = pressed
				Input.parse_input_event(event)
				await get_tree().physics_frame
			await _frames(6)
		await _frames(10)
		await _capture("k_x%d" % spot.x)
	get_tree().quit()


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_output_dir.path_join(file_name + ".png"))


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame

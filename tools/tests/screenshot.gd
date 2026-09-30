extends Node
## Captures screenshots of the title screen and several spots in Chapter One,
## for checking art placement without playing. Needs a window (not headless).
##
## Run from the project folder:
##   godot --path . res://tools/tests/screenshot.tscn -- <output folder>

const TITLE_SCENE: PackedScene = preload("res://ui/title_screen/title_screen.tscn")
const LEVEL_SCENE: PackedScene = preload("res://levels/level.tscn")
const TILE: float = 32.0
## Map columns to photograph, with the row her feet stand on (top of ground).
const SPOTS: Array[Vector2i] = [
	Vector2i(2, 9), Vector2i(20, 8), Vector2i(37, 9), Vector2i(53, 9),
	Vector2i(59, 7), Vector2i(91, 7), Vector2i(104, 9),
]

var _output_dir: String = ""


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_output_dir = args[0] if args.size() > 0 else OS.get_user_data_dir()

	var title: Node = TITLE_SCENE.instantiate()
	add_child(title)
	await _frames(40)
	await _capture("00_title")
	title.queue_free()
	await _frames(2)

	var level: LevelLoader = LEVEL_SCENE.instantiate() as LevelLoader
	add_child(level)
	await _frames(70)
	await _capture("01_start")
	for i: int in SPOTS.size():
		var spot: Vector2i = SPOTS[i]
		level.player.respawn(Vector2(spot.x * TILE + TILE / 2.0, spot.y * TILE))
		await _frames(50)
		await _capture("%02d_x%d" % [i + 2, spot.x])

	# Mid-swing while facing left, to check the mirrored sprite offset.
	level.player.respawn(Vector2(30 * TILE, 9 * TILE))
	await _frames(70)  # Let the respawn blink finish.
	Input.action_press("move_left")
	await _frames(3)
	Input.action_release("move_left")
	await _frames(10)
	Input.action_press("attack")
	await _frames(2)
	Input.action_release("attack")
	await _frames(6)
	await _capture("10_attack_left")
	get_tree().quit()


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = _output_dir.path_join(file_name + ".png")
	image.save_png(path)
	print("saved ", path)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame

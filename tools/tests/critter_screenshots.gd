extends Node
## Saves screenshots of critters under gravity, for checking them by eye:
## Chapter One's sheep that hangs above the dip (now standing in it), and a
## sheep dropped from the sky (three moments of its fall). Needs a window (not
## headless).
##
## Run from the project folder:
##   godot --path . res://tools/tests/critter_screenshots.tscn -- <output folder>

const LEVEL_SCENE: PackedScene = preload("res://levels/level.tscn")
const SHEEP_WHITE: PackedScene = preload("res://entities/critter/sheep_white.tscn")
const TILE: float = 32.0

var _output_dir: String = ""


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_output_dir = args[0] if args.size() > 0 else OS.get_user_data_dir()
	GameManager.save_path = "user://test_save.cfg"
	GameManager.current_level_index = 0
	var level: LevelLoader = LEVEL_SCENE.instantiate() as LevelLoader
	add_child(level)
	# Before any physics frame: the sheep still hangs where the map put it.
	level.player.respawn(Vector2(82.0 * TILE, 9.0 * TILE))
	await _frames(1)
	await _capture("c0_spawn")
	await _frames(90)
	await _capture("c1_settled")

	var sheep: Critter = SHEEP_WHITE.instantiate() as Critter
	sheep.position = Vector2(80.0 * TILE, 9.0 * TILE - 150.0)
	level.get_node("%Entities").add_child(sheep)
	await _frames(12)
	await _capture("c2_falling")
	await _frames(14)
	await _capture("c3_nearly_down")
	await _frames(40)
	await _capture("c4_landed")
	get_tree().quit()


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_output_dir.path_join(file_name + ".png"))


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame

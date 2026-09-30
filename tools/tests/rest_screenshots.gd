extends Node
## Saves screenshots of Mariane resting at a campfire in the Lantern Forest:
## the gold sparkles while she warms herself, then the silver-blue ones while
## she gathers moonlight. Needs a window (not headless).
##
## Run from the project folder:
##   godot --path . res://tools/tests/rest_screenshots.tscn -- <output folder>

const LEVEL_SCENE: PackedScene = preload("res://levels/level.tscn")

var _output_dir: String = ""


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_output_dir = args[0] if args.size() > 0 else OS.get_user_data_dir()
	GameManager.save_path = "user://test_save.cfg"
	GameManager.current_level_index = 1
	var level: LevelLoader = LEVEL_SCENE.instantiate() as LevelLoader
	add_child(level)
	await _frames(100)
	level.player.rest()
	for shot: int in 8:
		await _frames(9)
		await _capture("rest_%d" % shot)
	get_tree().quit()


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_output_dir.path_join(file_name + ".png"))


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame

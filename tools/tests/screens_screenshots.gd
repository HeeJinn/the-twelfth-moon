extends Node
## Saves screenshots of the title screen and the end screen, for checking their
## skies without playing. Needs a window (not headless).
##
## Run from the project folder:
##   godot --path . res://tools/tests/screens_screenshots.tscn -- <output folder>

const TITLE_SCENE: PackedScene = preload("res://ui/title_screen/title_screen.tscn")
const END_SCENE: PackedScene = preload("res://ui/end_screen/end_screen.tscn")

var _output_dir: String = ""


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_output_dir = args[0] if args.size() > 0 else OS.get_user_data_dir()
	for shot: Array in [["title", TITLE_SCENE], ["end", END_SCENE]]:
		var screen: Node = (shot[1] as PackedScene).instantiate()
		add_child(screen)
		for i: int in 40:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
				_output_dir.path_join("%s.png" % shot[0]))
		screen.queue_free()
		await get_tree().physics_frame
	get_tree().quit()

extends Node
## Saves screenshots for checking the follow camera and the pause screen:
## running (the view leads her), a jump up onto a higher roof (the view keeps
## its height until she lands), a fall (the view follows and looks down), and
## the pause screen with the controls. Needs a window (not headless). With
## "touch" after the folder, the phone buttons are shown too.
##
## Run from the project folder:
##   godot --path . res://tools/tests/camera_screenshots.tscn -- <output folder> [touch]

const LEVEL_SCENE: PackedScene = preload("res://levels/level.tscn")
const TILE: float = 16.0

var _output_dir: String = ""


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_output_dir = args[0] if args.size() > 0 else OS.get_user_data_dir()
	TouchControls.forced = args.size() > 1 and args[1] == "touch"
	GameManager.save_path = "user://test_save.cfg"
	GameManager.current_level_index = 4
	var level: LevelLoader = LEVEL_SCENE.instantiate() as LevelLoader
	add_child(level)
	await _frames(80)
	var player: Player = level.player
	# The battlements: run right, then jump up onto the first tower.
	player.respawn(Vector2(36.5 * TILE, 24.0 * TILE))
	await _frames(60)
	Input.action_press("move_right")
	await _frames(70)
	await _capture("c1_running")
	await _until(func() -> bool: return player.global_position.x >= 44.0 * TILE, 200)
	Input.action_press("jump")
	await _frames(14)
	await _capture("c2_jump_rising")
	await _frames(16)
	Input.action_release("jump")
	await _capture("c3_jump_top")
	Input.action_release("move_right")
	await _frames(60)
	await _capture("c4_landed_higher")
	# Off the second tower's far edge, down to the low roof under the ledge.
	player.respawn(Vector2(66.5 * TILE, 18.0 * TILE))
	await _frames(60)
	Input.action_press("move_right")
	await _until(func() -> bool: return player.velocity.y > 260.0, 200)
	Input.action_release("move_right")
	await _capture("c5_falling")
	await _frames(60)
	await _capture("c6_landed_lower")
	# The pause screen.
	var pause: InputEventAction = InputEventAction.new()
	pause.action = &"pause"
	pause.pressed = true
	Input.parse_input_event(pause)
	await _frames(5)
	await _capture("c7_paused")
	get_tree().paused = false
	get_tree().quit()


func _until(condition: Callable, limit: int) -> bool:
	for i: int in limit:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_output_dir.path_join(file_name + ".png"))


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame

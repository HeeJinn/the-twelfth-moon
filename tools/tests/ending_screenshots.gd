extends Node
## Saves screenshots through the ending, the credits and the after-credits
## scene, sped up, reading every conversation on its own. Needs a window (not
## headless). A shot every `interval` game seconds, named in order.
##
## Run from the project folder:
##   godot --path . res://tools/tests/ending_screenshots.tscn -- <folder> [ending|credits|after] [interval]

const SCENES: Dictionary[String, String] = {
	"ending": "res://story/ending/ending.tscn",
	"credits": "res://ui/credits/credits.tscn",
	"after": "res://story/ending/after_credits.tscn",
}
const SPEED: float = 3.0


class Shooter:
	extends Node

	var output_dir: String = ""
	var interval: float = 2.0
	var dialogue_open: bool = false

	func run(first_scene: String) -> void:
		EventBus.dialogue_started.connect(func(_id: String) -> void: dialogue_open = true)
		EventBus.dialogue_finished.connect(func(_id: String) -> void: dialogue_open = false)
		Engine.time_scale = SPEED
		get_tree().change_scene_to_file(first_scene)
		var shot: int = 0
		var clock: float = 0.0
		var reading: float = 0.0
		while shot < 200:
			await get_tree().process_frame
			var step: float = get_process_delta_time()
			clock += step
			if dialogue_open:
				reading += step
				if reading > 1.1:
					reading = 0.0
					_press(&"interact")
			if clock >= interval:
				clock = 0.0
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(
						output_dir.path_join("%03d.png" % shot))
				shot += 1
			var scene: Node = get_tree().current_scene
			if scene != null and scene.scene_file_path == GameManager.END_SCREEN_PATH \
					and not SceneManager.is_transitioning():
				break
		Engine.time_scale = 1.0
		get_tree().quit()

	func _press(action: StringName) -> void:
		var event: InputEventAction = InputEventAction.new()
		event.action = action
		event.pressed = true
		Input.parse_input_event(event)
		var release: InputEventAction = InputEventAction.new()
		release.action = action
		release.pressed = false
		Input.parse_input_event.call_deferred(release)


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var shooter: Shooter = Shooter.new()
	shooter.output_dir = args[0] if args.size() > 0 else OS.get_user_data_dir()
	var part: String = args[1] if args.size() > 1 else "ending"
	if args.size() > 2:
		shooter.interval = args[2].to_float()
	get_tree().root.add_child.call_deferred(shooter)
	shooter.ready.connect(shooter.run.bind(SCENES.get(part, SCENES["ending"])))

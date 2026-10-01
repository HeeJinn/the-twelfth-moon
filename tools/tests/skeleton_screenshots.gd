extends Node
## Saves six screenshots of an enemy attacking Mariane (by default Chapter
## Three's first flail skeleton): walking, then five moments of its attack.
## Needs a window (not headless).
##
## Run from the project folder:
##   godot --path . res://tools/tests/skeleton_screenshots.tscn -- <output folder>
##       [chapter index] [enemy scene file] [attack frames, comma separated]

const FIRST_SKELETON: Vector2 = Vector2(32.5 * 32.0, 0.0)


class Shooter:
	extends Node

	var output_dir: String = ""
	var chapter: int = 2
	var scene_name: String = "skeleton.tscn"
	var attack_frames: Array[int] = [4, 10, 13, 16, 20]

	func run() -> void:
		GameManager.go_to_level(chapter)
		for i: int in 600:
			if GameManager.is_playing() and not SceneManager.is_transitioning():
				break
			await get_tree().physics_frame
		await _frames(30)
		var skeleton: Enemy = null
		for node: Node in get_tree().current_scene.find_children("*", "", true, false):
			var enemy: Enemy = node as Enemy
			if enemy != null and enemy.scene_file_path.ends_with(scene_name) and (skeleton == null
					or absf(enemy.global_position.x - FIRST_SKELETON.x)
					< absf(skeleton.global_position.x - FIRST_SKELETON.x)):
				skeleton = enemy
		if skeleton == null:
			push_error("No skeleton found")
			get_tree().quit(1)
			return
		var player: Player = get_tree().get_first_node_in_group(&"player") as Player
		player.global_position = skeleton.global_position + Vector2(-56.0, 0.0)
		player.reset_physics_interpolation()
		player.get_camera().reset_smoothing()
		var sprite: AnimatedSprite2D = skeleton.get_node(^"%AnimatedSprite2D") as AnimatedSprite2D
		await _shoot("0_walk")
		for i: int in 400:
			if sprite.animation == &"attack":
				break
			await get_tree().physics_frame
		for frame: int in attack_frames:
			for i: int in 200:
				if sprite.animation != &"attack" or sprite.frame >= frame:
					break
				await get_tree().physics_frame
			await _shoot("%d_attack_%02d" % [frame, frame])
		get_tree().quit()

	func _shoot(shot_name: String) -> void:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
				output_dir.path_join("%s.png" % shot_name))

	func _frames(count: int) -> void:
		for i: int in count:
			await get_tree().physics_frame


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var shooter: Shooter = Shooter.new()
	shooter.output_dir = args[0] if args.size() > 0 else OS.get_user_data_dir()
	if args.size() > 2:
		shooter.chapter = args[1].to_int()
		shooter.scene_name = args[2]
	if args.size() > 3:
		shooter.attack_frames.clear()
		for frame: String in args[3].split(","):
			shooter.attack_frames.append(frame.to_int())
	get_tree().root.add_child.call_deferred(shooter)
	shooter.ready.connect(shooter.run)

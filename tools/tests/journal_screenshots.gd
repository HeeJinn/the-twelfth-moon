extends Node
## Saves screenshots of the petal journal in Chapter One, with twelve petals
## found (a scratch save): a new line at the top of the screen, the pause
## screen with its button, the newest spread and the first. Needs a window.
##
## Run from the project folder:
##   godot --path . res://tools/tests/journal_screenshots.tscn -- <output folder>

const SCRATCH_SAVE: String = "user://test_save.cfg"


class Shooter:
	extends Node

	var output_dir: String = ""

	func run() -> void:
		GameManager.save_path = SCRATCH_SAVE
		GameManager.petals_best = {1: 5, 2: 2}
		GameManager.go_to_level(0)
		for i: int in 400:
			if GameManager.is_playing() and not SceneManager.is_transitioning():
				break
			await get_tree().physics_frame
		await _frames(200)  # The chapter card fades.
		var journal: Node = get_tree().current_scene.get_node(^"PetalJournal")
		for i: int in 5:
			EventBus.collectible_collected.emit(1)
		await _frames(40)
		await _shoot("toast")
		GameManager.toggle_pause()
		await _frames(10)
		await _shoot("paused")
		journal.call(&"open_book")
		await _frames(10)
		await _shoot("book_newest")
		journal.call(&"turn_page", -1)
		journal.call(&"turn_page", -1)
		await _frames(10)
		await _shoot("book_first")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_SAVE))
		get_tree().quit()

	func _shoot(shot_name: String) -> void:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
				output_dir.path_join("%s.png" % shot_name))

	func _frames(count: int) -> void:
		for i: int in count:
			await get_tree().process_frame


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var shooter: Shooter = Shooter.new()
	shooter.output_dir = args[0] if args.size() > 0 else OS.get_user_data_dir()
	get_tree().root.add_child.call_deferred(shooter)
	shooter.ready.connect(shooter.run)

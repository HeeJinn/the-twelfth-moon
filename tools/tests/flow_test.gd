extends Node
## Headless check of the game's opening flow: Begin -> prologue (read through)
## -> Chapter One, then Begin again -> prologue skipped with Esc -> Chapter One.
##
## The checks run on a watcher node added to the root, because the scene
## changes free this node.
##
## Run from the project folder:
##   godot --headless --path . res://tools/tests/flow_test.tscn


class Watcher:
	extends Node

	var failures: int = 0
	var dialogue_open: bool = false

	func run() -> void:
		GameManager.save_path = "user://test_save.cfg"
		EventBus.dialogue_started.connect(func(_id: String) -> void: dialogue_open = true)
		EventBus.dialogue_finished.connect(func(_id: String) -> void: dialogue_open = false)

		GameManager.start_new_game()
		await _until_scene(GameManager.PROLOGUE_PATH, 120)
		_expect(_scene_is(GameManager.PROLOGUE_PATH), "Begin opens the prologue")
		for i: int in 4000:
			if _scene_is(GameManager.LEVEL_SCENE_PATH):
				break
			if dialogue_open:
				await _press(&"interact")
				await _frames(6)
			else:
				await get_tree().physics_frame
		_expect(_scene_is(GameManager.LEVEL_SCENE_PATH), "the prologue leads into Chapter One")

		GameManager.start_new_game()
		await _until_scene(GameManager.PROLOGUE_PATH, 120)
		await _frames(60)
		await _press(&"pause")
		await _until_scene(GameManager.LEVEL_SCENE_PATH, 120)
		_expect(_scene_is(GameManager.LEVEL_SCENE_PATH), "Esc skips the prologue")

		print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
		get_tree().quit(failures)

	func _scene_is(path: String) -> bool:
		var scene: Node = get_tree().current_scene
		return scene != null and scene.scene_file_path == path

	func _until_scene(path: String, limit: int) -> void:
		for i: int in limit:
			if _scene_is(path) and not SceneManager.is_transitioning():
				return
			await get_tree().physics_frame

	func _press(action: StringName) -> void:
		for pressed: bool in [true, false]:
			var event: InputEventAction = InputEventAction.new()
			event.action = action
			event.pressed = pressed
			Input.parse_input_event(event)
			await get_tree().physics_frame

	func _frames(count: int) -> void:
		for i: int in count:
			await get_tree().physics_frame

	func _expect(condition: bool, label: String) -> void:
		if condition:
			print("PASS ", label)
		else:
			failures += 1
			print("FAIL ", label)


func _ready() -> void:
	var watcher: Watcher = Watcher.new()
	get_tree().root.add_child.call_deferred(watcher)
	watcher.ready.connect(watcher.run)

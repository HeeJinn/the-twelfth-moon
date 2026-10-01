extends Node
## Headless check of the story's flow from Chapter Two to the end: finishing
## Chapter Two plays the Ember memory and then loads Chapter Three; finishing
## Chapter Three plays the Red Ribbon memory (read all the way through) and
## then loads Chapter Four, Ember Keep; finishing that plays the Oath memory
## (read all the way through) and then shows the end screen.
## Progress is saved to a scratch file.
##
## The checks run on a watcher node added to the root, because the scene
## changes free this node.
##
## Run from the project folder:
##   godot --headless --path . res://tools/tests/story_flow_test.tscn

const SCRATCH_SAVE: String = "user://test_save.cfg"
const EMBER_MEMORY: String = "res://story/memories/memory_ember.tscn"
const RIBBON_MEMORY: String = "res://story/memories/memory_ribbon.tscn"
const OATH_MEMORY: String = "res://story/memories/memory_oath.tscn"


class Watcher:
	extends Node

	var failures: int = 0
	var dialogue_open: bool = false
	var dialogues: Array[String] = []

	func run() -> void:
		GameManager.save_path = SCRATCH_SAVE
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_SAVE))
		GameManager.highest_unlocked_level = 0
		EventBus.dialogue_started.connect(func(id: String) -> void:
			dialogue_open = true
			dialogues.append(id))
		EventBus.dialogue_finished.connect(func(_id: String) -> void: dialogue_open = false)

		GameManager.go_to_level(1)
		await _until_scene(GameManager.LEVEL_SCENE_PATH, 240)
		await _frames(30)
		_expect(GameManager.get_current_level().title == "Chapter Two", "Chapter Two is loaded")

		EventBus.level_completed.emit()
		await _until_scene(EMBER_MEMORY, 400)
		_expect(_scene_is(EMBER_MEMORY), "finishing Chapter Two plays the Ember memory")
		await _read_until_scene(GameManager.LEVEL_SCENE_PATH, 6000)
		await _frames(30)
		_expect(GameManager.current_level_index == 2
				and GameManager.get_current_level().title == "Chapter Three",
				"the memory leads into Chapter Three")
		_expect(dialogues.has("memory_ember") and dialogues.has("memory_wake"),
				"the whole Ember memory was read")

		var level: LevelLoader = get_tree().current_scene as LevelLoader
		_expect(level != null and level.player != null, "Chapter Three has Mariane")
		EventBus.level_completed.emit()
		await _until_scene(RIBBON_MEMORY, 400)
		_expect(_scene_is(RIBBON_MEMORY), "finishing Chapter Three plays the Red Ribbon memory")
		await _read_until_scene(GameManager.LEVEL_SCENE_PATH, 6000)
		await _frames(30)
		_expect(GameManager.current_level_index == 3
				and GameManager.get_current_level().title == "Chapter Four",
				"the memory leads into Chapter Four, Ember Keep")
		_expect(dialogues.has("memory_ribbon") and dialogues.has("memory_wake"),
				"the whole Red Ribbon memory was read")
		EventBus.level_completed.emit()
		await _until_scene(OATH_MEMORY, 400)
		_expect(_scene_is(OATH_MEMORY), "finishing Chapter Four plays the Oath memory")
		await _read_until_scene(GameManager.END_SCREEN_PATH, 6000)
		_expect(_scene_is(GameManager.END_SCREEN_PATH), "the memory leads to the end screen")
		_expect(dialogues.has("memory_oath"), "the whole Oath memory was read")
		_expect(GameManager.highest_unlocked_level == 3, "Chapter Four stays unlocked")
		_expect(FileAccess.file_exists(SCRATCH_SAVE), "progress went to the scratch save")

		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_SAVE))
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

	## Presses through every conversation until `path` is the current scene.
	func _read_until_scene(path: String, limit: int) -> void:
		for i: int in limit:
			if _scene_is(path) and not SceneManager.is_transitioning():
				return
			if dialogue_open:
				await _press(&"interact")
				await _frames(6)
			else:
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

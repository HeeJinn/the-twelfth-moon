extends Node
## Headless check of the end of the story, sped up: finishing Chapter Five
## fades through white into the ending (the moon shatters, dawn in the village,
## both title cards), which rolls into the credits (every line, with digits,
## faster while jump is held), then the after-credits scene, then the end
## screen. Then Esc skips each of the three in turn.
## Progress is saved to a scratch file.
##
## The checks run on a watcher node added to the root, because the scene
## changes free this node.
##
## Run from the project folder:
##   godot --headless --path . res://tools/tests/ending_test.tscn

const SCRATCH_SAVE: String = "user://test_save.cfg"
const SPEED: float = 4.0


class Watcher:
	extends Node

	var failures: int = 0
	var dialogue_open: bool = false
	var dialogues: Array[String] = []

	func run() -> void:
		GameManager.save_path = SCRATCH_SAVE
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_SAVE))
		EventBus.dialogue_started.connect(func(id: String) -> void:
			dialogue_open = true
			dialogues.append(id))
		EventBus.dialogue_finished.connect(func(_id: String) -> void: dialogue_open = false)
		Engine.time_scale = SPEED

		GameManager.go_to_level(4)
		await _until_scene(GameManager.LEVEL_SCENE_PATH, 600)
		await _frames(30)
		EventBus.level_completed.emit()
		var fade: ColorRect = SceneManager.get_child(0) as ColorRect
		var through_white: bool = false
		for i: int in 600:
			if fade.modulate.a > 0.9 and fade.color == Color.WHITE:
				through_white = true
			if _scene_is(GameManager.ENDING_PATH):
				break
			await get_tree().physics_frame
		_expect(through_white, "Chapter Five fades through white (the cracked moon) into the ending")
		var ending: Node = get_tree().current_scene
		var flash: ColorRect = ending.get_node(^"FlashLayer/Flash") as ColorRect
		_expect(flash.color.a > 0.6 and flash.color.r > 0.9,
				"the ending opens on that white (%.2f)" % flash.color.a)
		await _until_scene(GameManager.ENDING_PATH, 200)
		var moon: Sprite2D = ending.get_node(^"Roof/Moon") as Sprite2D

		# Read through to the credits, watching for the moon and the cards.
		var cards: Node = ending.get_node(^"CardLayer/CenterContainer/Cards")
		var title_card: Label = cards.get_node(^"TitleCard") as Label
		var birthday_card: Label = cards.get_node(^"BirthdayCard") as Label
		var moon_shattered: bool = false
		var saw_title: bool = false
		var saw_birthday: bool = false
		for i: int in 20000:
			if _scene_is(GameManager.CREDITS_PATH) and not SceneManager.is_transitioning():
				break
			if is_instance_valid(moon) and not moon.visible:
				moon_shattered = true
			if is_instance_valid(title_card) and title_card.modulate.a > 0.95:
				saw_title = true
			if is_instance_valid(birthday_card) and birthday_card.modulate.a > 0.95:
				saw_birthday = birthday_card.text.contains("Twenty-First Birthday")
			if dialogue_open:
				await _press(&"interact")
				await _frames(6)
			else:
				await get_tree().physics_frame
		_expect(moon_shattered, "the moon shatters")
		for id: String in ["ending_sky", "ending_dawn", "ending_village", "ending_sky_again"]:
			_expect(dialogues.has(id), "the ending plays '%s'" % id)
		_expect(saw_title, "the title card \"The Twelfth Moon\" is shown")
		_expect(saw_birthday, "the card \"Happy Twenty-First Birthday, Mariane\" is shown")
		_expect(_scene_is(GameManager.CREDITS_PATH), "the ending rolls into the credits")

		# The credits.
		var credits: Node = get_tree().current_scene
		var roll: VBoxContainer = credits.get_node(^"Roll") as VBoxContainer
		var lines: int = 0
		var licence: Label = null
		for child: Node in roll.get_children():
			if child is Label:
				lines += 1
				if (child as Label).text.begins_with("CC BY 4.0"):
					licence = child as Label
		_expect(lines > 60, "every line of credits.txt is on the roll (%d)" % lines)
		var font: FontVariation = null
		if licence != null:
			font = licence.get_theme_font(&"font") as FontVariation
		_expect(font != null and not font.base_font.has_char(52)
				and font.fallbacks.size() == 1 and font.fallbacks[0].has_char(52),
				"licence lines use Pixelmax with the drawn digits as fallback")
		var start_y: float = roll.position.y
		await _frames(30)
		var slow_rise: float = start_y - roll.position.y
		_expect(slow_rise > 0.0, "the credits roll up")
		Input.action_press(&"jump")
		await _frames(30)
		var fast_rise: float = start_y - roll.position.y - slow_rise
		_expect(fast_rise > slow_rise * 3.0, "holding jump rolls them faster")
		var reached_end: bool = false
		for i: int in 20000:
			if (credits as Object).call(&"is_finished"):
				reached_end = true
				break
			await get_tree().physics_frame
		Input.action_release(&"jump")
		_expect(reached_end, "the last line stops in the middle of the screen")
		await _until_scene(GameManager.AFTER_CREDITS_PATH, 2000)
		_expect(_scene_is(GameManager.AFTER_CREDITS_PATH), "then the after-credits scene")

		# After the credits.
		await _read_until_scene(GameManager.END_SCREEN_PATH, 20000)
		_expect(dialogues.has("after_spring") and dialogues.has("after_meeting"),
				"spring, and the meeting under the tree")
		_expect(_scene_is(GameManager.END_SCREEN_PATH), "the story ends on the end screen")
		_expect(GameManager.state == GameManager.GameState.WON, "the game is won")

		# Esc skips each part.
		SceneManager.change_scene(GameManager.ENDING_PATH)
		await _until_scene(GameManager.ENDING_PATH, 400)
		await _frames(20)
		await _press(&"pause")
		await _until_scene(GameManager.CREDITS_PATH, 400)
		_expect(_scene_is(GameManager.CREDITS_PATH), "Esc skips the ending to the credits")
		await _frames(20)
		await _press(&"pause")
		await _until_scene(GameManager.AFTER_CREDITS_PATH, 400)
		_expect(_scene_is(GameManager.AFTER_CREDITS_PATH), "Esc skips the credits")
		await _frames(20)
		await _press(&"pause")
		await _until_scene(GameManager.END_SCREEN_PATH, 400)
		_expect(_scene_is(GameManager.END_SCREEN_PATH), "Esc skips the after-credits scene")

		Engine.time_scale = 1.0
		# A track still playing (or fading) at exit is reported as a leak.
		Music.stop(0.1)
		await _frames(180)
		for i: int in 600:
			if not Audio.is_busy():
				break
			await get_tree().physics_frame
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

extends Node
## Headless check of the petal journal in Chapter One: each petal shows its
## line at the top of the screen; the pause screen's "Petal journal" opens the
## book on the newest line, pages turn with the buttons and the arrow keys but
## never past the newest line, lines not yet found read "..."; Back and
## unpausing close it. Finishing the chapter saves its petals, loading brings
## them back, and replaying the chapter never counts a petal twice.
## Progress is saved to a scratch file.
##
## Run from the project folder:
##   godot --headless --path . res://tools/tests/journal_test.tscn

const SCRATCH_SAVE: String = "user://test_save.cfg"
const JOURNAL_SCRIPT: GDScript = preload("res://ui/journal/petal_journal.gd")


class Watcher:
	extends Node

	var failures: int = 0

	func run() -> void:
		GameManager.save_path = SCRATCH_SAVE
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_SAVE))
		GameManager.petals_best.clear()
		var lines: PackedStringArray = JOURNAL_SCRIPT.call(&"read_lines",
				"res://story/petal_journal.txt")
		_expect(lines.size() == GameManager.TOTAL_PETALS,
				"the journal has one line per petal (%d)" % lines.size())
		var longest: int = 0
		for line: String in lines:
			longest = maxi(longest, line.length())
		_expect(longest <= 46, "every line fits its place on a page (longest %d)" % longest)

		GameManager.go_to_level(0)
		await _until_level()
		var journal: Node = get_tree().current_scene.get_node(^"PetalJournal")
		var toast: Label = journal.get_node(^"Toast") as Label
		var open_button: Button = journal.get_node(^"OpenButton") as Button
		_expect(toast.modulate.a < 0.1 and not open_button.visible,
				"nothing shows before a petal or a pause")

		EventBus.collectible_collected.emit(1)
		await _frames(60)
		_expect(GameManager.petals_found() == 1, "the first petal is found")
		_expect(toast.text == lines[0] and toast.modulate.a > 0.9,
				"its line shows at the top of the screen")
		await _frames(420)
		_expect(toast.modulate.a < 0.1, "and fades away again")
		for i: int in 4:
			EventBus.collectible_collected.emit(1)
			await _frames(5)
		_expect(GameManager.petals_found() == 5 and toast.text == lines[4],
				"each petal brings the next line (five found)")

		GameManager.toggle_pause()
		await _frames(5)
		_expect(open_button.visible, "the pause screen offers the petal journal")
		open_button.pressed.emit()
		await _frames(5)
		_expect(journal.call(&"is_open"), "it opens the book")
		var spread: PackedStringArray = journal.call(&"spread_text")
		_expect(spread == PackedStringArray([lines[4], "...", "...", "..."]),
				"it opens on the newest line; the rest read \"...\"")
		var next_button: Button = journal.get_node(^"Book/NextButton") as Button
		var prev_button: Button = journal.get_node(^"Book/PrevButton") as Button
		_expect(not next_button.visible and prev_button.visible,
				"no page past the newest line, one page back")
		prev_button.pressed.emit()
		await _frames(3)
		spread = journal.call(&"spread_text")
		_expect(spread == PackedStringArray([lines[0], lines[1], lines[2], lines[3]]),
				"the page before holds the first four lines")
		journal.call(&"turn_page", -1)
		_expect(journal.call(&"spread_text") == spread, "and nothing comes before it")
		await _press(&"move_right")
		spread = journal.call(&"spread_text")
		_expect(spread[0] == lines[4], "the arrow keys turn the pages too")
		(journal.get_node(^"Book/BackButton") as Button).pressed.emit()
		await _frames(3)
		_expect(not journal.call(&"is_open") and open_button.visible,
				"Back closes the book and returns to the pause screen")
		open_button.pressed.emit()
		await _frames(3)
		GameManager.toggle_pause()
		await _frames(3)
		_expect(not journal.call(&"is_open") and not open_button.visible,
				"unpausing closes everything")

		# Finishing the chapter saves the petals.
		EventBus.level_completed.emit()
		await _frames(30)
		_expect(GameManager.petals_best.get(0, 0) == 5, "finishing the chapter keeps its five")
		GameManager.petals_best.clear()
		GameManager.load_progress()
		_expect(GameManager.petals_best.get(0, 0) == 5, "and they come back from the save")
		await _until_transition_done()

		# Replaying the chapter never counts a petal twice.
		GameManager.go_to_level(0)
		await _until_level()
		journal = get_tree().current_scene.get_node(^"PetalJournal")
		toast = journal.get_node(^"Toast") as Label
		for i: int in 3:
			EventBus.collectible_collected.emit(1)
			await _frames(5)
		await _frames(30)
		_expect(GameManager.petals_found() == 5, "a replay counts no petal twice (still five)")
		_expect(toast.modulate.a < 0.1, "and brings back no line already known")

		Music.stop(0.1)
		await _frames(180)
		for i: int in 600:
			if not Audio.is_busy():
				break
			await get_tree().physics_frame
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_SAVE))
		print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
		get_tree().quit(failures)

	func _until_level() -> void:
		for i: int in 600:
			var scene: Node = get_tree().current_scene
			if scene != null and scene.scene_file_path == GameManager.LEVEL_SCENE_PATH \
					and not SceneManager.is_transitioning() and GameManager.is_playing():
				return
			await get_tree().physics_frame

	func _until_transition_done() -> void:
		for i: int in 600:
			if not SceneManager.is_transitioning() and GameManager.state != \
					GameManager.GameState.TRANSITIONING:
				return
			await get_tree().physics_frame

	func _press(action: StringName) -> void:
		for pressed: bool in [true, false]:
			var event: InputEventAction = InputEventAction.new()
			event.action = action
			event.pressed = pressed
			Input.parse_input_event(event)
			await get_tree().process_frame

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

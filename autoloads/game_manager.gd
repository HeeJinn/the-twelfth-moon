extends Node
## Owns run-wide state (autoload "GameManager"): the chapter order, the current
## chapter, petal counts, pause, win flow and the save file.
##
## Gameplay nodes never call this to report events; they emit on EventBus and
## GameManager reacts. UI may call the public methods (start_new_game, ...).
## Deaths are handled by the level itself (respawn at the last campfire), so
## a death never restarts the chapter or loses petals.

enum GameState { MENU, PLAYING, PAUSED, TRANSITIONING, WON }

const PROLOGUE_PATH: String = "res://story/prologue/prologue.tscn"
const LEVEL_SCENE_PATH: String = "res://levels/level.tscn"
const TITLE_SCREEN_PATH: String = "res://ui/title_screen/title_screen.tscn"
const END_SCREEN_PATH: String = "res://ui/end_screen/end_screen.tscn"
## The last chapter's outro: the ending, then the credits and after-credits.
const ENDING_PATH: String = "res://story/ending/ending.tscn"
const CREDITS_PATH: String = "res://ui/credits/credits.tscn"
const AFTER_CREDITS_PATH: String = "res://story/ending/after_credits.tscn"
const SAVE_PATH: String = "user://save.cfg"
## Petals hidden across the whole story, one for each year of Mariane's life.
const TOTAL_PETALS: int = 21
## Seconds to wait after reaching the goal before changing scene.
const NEXT_LEVEL_DELAY: float = 0.8
## Play order. Add one LevelData .tres per chapter.
const LEVELS: Array[LevelData] = [
	preload("res://levels/maps/chapter_01.tres"),
	preload("res://levels/maps/chapter_02.tres"),
	preload("res://levels/maps/chapter_03.tres"),
	preload("res://levels/maps/chapter_04.tres"),
	preload("res://levels/maps/chapter_05.tres"),
]

## Where progress is saved. Tests point this at a scratch file so they never
## touch the real save.
var save_path: String = SAVE_PATH
var state: GameState = GameState.MENU
var current_level_index: int = 0
var collected_in_level: int = 0
var collectibles_in_level: int = 0
## Petals banked from completed chapters in this run.
var total_collected: int = 0
## Saved progress: the furthest chapter reached.
var highest_unlocked_level: int = 0
## Saved: the most petals ever found in each chapter (chapter index -> count).
## The petal journal reads its lines from the sum, so a petal found once stays
## found, and replaying a chapter never counts its petals twice.
var petals_best: Dictionary[int, int] = {}


func _ready() -> void:
	# Keep receiving the pause action while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	TouchControls.adapt_input_map()
	EventBus.level_started.connect(_on_level_started)
	EventBus.collectible_collected.connect(_on_collectible_collected)
	EventBus.level_completed.connect(_on_level_completed)
	load_progress()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and state in [GameState.PLAYING, GameState.PAUSED]:
		toggle_pause()
		get_viewport().set_input_as_handled()


## A new story starts with the prologue, which then calls go_to_level(0).
func start_new_game() -> void:
	total_collected = 0
	state = GameState.TRANSITIONING
	get_tree().paused = false
	SceneManager.change_scene(PROLOGUE_PATH)


func continue_game() -> void:
	go_to_level(highest_unlocked_level)


func has_progress() -> bool:
	return highest_unlocked_level > 0


func go_to_level(index: int) -> void:
	current_level_index = clampi(index, 0, LEVELS.size() - 1)
	state = GameState.TRANSITIONING
	get_tree().paused = false
	SceneManager.change_scene(LEVEL_SCENE_PATH)


func go_to_title() -> void:
	state = GameState.MENU
	get_tree().paused = false
	SceneManager.change_scene(TITLE_SCREEN_PATH)


func get_current_level() -> LevelData:
	return LEVELS[current_level_index]


## Every petal found so far: the saved best of each chapter, with the chapter
## being played counted as it goes. At most TOTAL_PETALS.
func petals_found() -> int:
	var found: int = 0
	for index: int in LEVELS.size():
		var best: int = petals_best.get(index, 0)
		if index == current_level_index and state in [GameState.PLAYING, GameState.PAUSED]:
			best = maxi(best, collected_in_level)
		found += best
	return mini(found, TOTAL_PETALS)


func is_playing() -> bool:
	return state == GameState.PLAYING


func toggle_pause() -> void:
	if state == GameState.PLAYING:
		state = GameState.PAUSED
	elif state == GameState.PAUSED:
		state = GameState.PLAYING
	else:
		return
	get_tree().paused = state == GameState.PAUSED
	EventBus.pause_toggled.emit(get_tree().paused)


func save_progress() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("progress", "highest_unlocked_level", highest_unlocked_level)
	config.set_value("progress", "petals", petals_best)
	var error: Error = config.save(save_path)
	if error != OK:
		push_warning("Could not save progress: %s" % error_string(error))


func load_progress() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(save_path) != OK:
		return  # No save yet.
	var saved: Variant = config.get_value("progress", "highest_unlocked_level", 0)
	if saved is int:  # Never trust file contents to have the right type.
		var level_index: int = saved
		highest_unlocked_level = clampi(level_index, 0, LEVELS.size() - 1)
	petals_best.clear()
	var petals: Variant = config.get_value("progress", "petals", {})
	if petals is Dictionary:
		for key: Variant in (petals as Dictionary):
			var count: Variant = (petals as Dictionary)[key]
			if key is int and count is int:
				var index: int = key
				var found: int = count
				if index >= 0 and index < LEVELS.size():
					petals_best[index] = clampi(found, 0, TOTAL_PETALS)


func _on_level_started(_level_data: LevelData, collectibles_total: int) -> void:
	state = GameState.PLAYING
	collected_in_level = 0
	collectibles_in_level = collectibles_total
	EventBus.collectibles_changed.emit(collected_in_level, collectibles_in_level)


func _on_collectible_collected(value: int) -> void:
	collected_in_level += value
	EventBus.collectibles_changed.emit(collected_in_level, collectibles_in_level)


## Called by a chapter's outro scene when it's finished.
func finish_outro() -> void:
	_advance()


func _on_level_completed() -> void:
	if state != GameState.PLAYING:
		return
	state = GameState.TRANSITIONING
	total_collected += collected_in_level
	petals_best[current_level_index] = maxi(
			petals_best.get(current_level_index, 0), collected_in_level)
	var outro: String = get_current_level().outro_scene
	if not outro.is_empty():
		highest_unlocked_level = maxi(
				highest_unlocked_level, mini(current_level_index + 1, LEVELS.size() - 1))
		save_progress()
		await get_tree().create_timer(NEXT_LEVEL_DELAY).timeout
		SceneManager.change_scene(outro, get_current_level().outro_fade)
		return
	_advance()


## Called by the after-credits scene, the very end of the story.
func finish_story() -> void:
	state = GameState.WON
	save_progress()
	SceneManager.change_scene(END_SCREEN_PATH)


## Goes on to the next chapter, or the end screen after the last one.
func _advance() -> void:
	state = GameState.TRANSITIONING
	var next_index: int = current_level_index + 1
	if next_index < LEVELS.size():
		highest_unlocked_level = maxi(highest_unlocked_level, next_index)
		save_progress()
		await get_tree().create_timer(NEXT_LEVEL_DELAY).timeout
		go_to_level(next_index)
	else:
		state = GameState.WON
		save_progress()
		await get_tree().create_timer(NEXT_LEVEL_DELAY).timeout
		SceneManager.change_scene(END_SCREEN_PATH)

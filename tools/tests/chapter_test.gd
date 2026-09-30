extends Node
## Headless gameplay check for Chapter One. Loads the real level scene and
## drives Mariane with simulated input, printing PASS/FAIL per check.
##
## Run from the project folder:
##   godot --headless --path . res://tools/tests/chapter_test.tscn

const LEVEL_SCENE: PackedScene = preload("res://levels/level.tscn")
const TILE: float = 32.0

var _failures: int = 0
var _level: LevelLoader
var _dialogue_open: bool = false
var _dialogues_seen: Array[String] = []
var _chapter_completed: bool = false


func _ready() -> void:
	GameManager.save_path = "user://test_save.cfg"
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.dialogue_finished.connect(_on_dialogue_finished)
	EventBus.level_completed.connect(func() -> void: _chapter_completed = true)
	GameManager.current_level_index = 0
	_level = LEVEL_SCENE.instantiate() as LevelLoader
	add_child(_level)
	await _frames(30)
	_check_tiles()
	await _check_wake_up()
	await _check_run_and_jump()
	await _check_villager_talk()
	await _check_sword()
	await _check_petal()
	await _check_campfire_and_respawn()
	await _check_shrine_scene()
	print("dialogues seen: ", _dialogues_seen)
	# A sound cut off by quitting would be reported as a leak on exit.
	for wait: int in 120:
		if not Audio.is_busy():
			break
		await get_tree().physics_frame
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(_failures)


func _check_tiles() -> void:
	var terrain: TileMapLayer = _level.get_node("%TerrainLayer") as TileMapLayer
	_expect(terrain.get_used_cells().size() > 300, "terrain painted")
	_expect(terrain.get_cell_atlas_coords(Vector2i(2, 9)) == Vector2i(1, 0), "grass top tile")
	_expect(terrain.get_cell_atlas_coords(Vector2i(2, 10)) == Vector2i(1, 1), "fill tile")
	_expect(terrain.get_cell_atlas_coords(Vector2i(40, 11)) == Vector2i(1, 1), "bottom row is fill")
	var platforms: TileMapLayer = _level.get_node("%PlatformLayer") as TileMapLayer
	_expect(platforms.get_used_cells().size() == 12, "twelve plank cells")


func _check_wake_up() -> void:
	var player: Player = _level.player
	_expect(player.is_on_floor(), "standing after spawn")
	# Grandpa Tomas speaks once the chapter card has faded.
	await _frames_until(func() -> bool: return _dialogue_open, 400)
	_expect(_dialogues_seen.has("wake_up"), "Grandpa Tomas wakes her up")
	var x_before: float = player.global_position.x
	Input.action_press("move_right")
	await _frames(20)
	Input.action_release("move_right")
	_expect(absf(player.global_position.x - x_before) < 1.0, "she can't walk off mid-conversation")
	await _finish_dialogue()
	_expect(not _dialogue_open, "conversation closes")


func _check_run_and_jump() -> void:
	var player: Player = _level.player
	await _frames(20)
	var start_x: float = player.global_position.x
	Input.action_press("move_right")
	await _frames(60)
	Input.action_release("move_right")
	var ran: float = player.global_position.x - start_x
	print("ran %.1f px in one second" % ran)
	_expect(ran > 90.0, "runs right after the conversation")
	await _frames(30)
	var ground_y: float = player.global_position.y
	var highest: float = ground_y
	Input.action_press("jump")
	for i: int in 60:
		await get_tree().physics_frame
		highest = minf(highest, player.global_position.y)
	Input.action_release("jump")
	await _frames(30)
	_expect(ground_y - highest > 70.0, "full jump clears two tiles")


func _check_villager_talk() -> void:
	var player: Player = _level.player
	var rosa: Npc = _find_npc("Rosa")
	_expect(rosa != null, "Rosa is in the village")
	if rosa == null:
		return
	_teleport(player, rosa.global_position + Vector2(-20.0, 0.0))
	await _frames(10)
	_press("interact")
	await _frames(5)
	_expect(_dialogues_seen.has("rosa"), "talking to Rosa")
	await _finish_dialogue()
	await _frames(40)  # Past the talk cooldown.
	_press("interact")
	await _frames(5)
	await _finish_dialogue()
	_expect(_dialogues_seen.count("rosa") == 2, "Rosa can be talked to again")


func _check_sword() -> void:
	var player: Player = _level.player
	var goblin: Enemy = _first_of_type(Enemy) as Enemy
	_teleport(player, goblin.global_position + Vector2(-22.0, 0.0))
	goblin.set_physics_process(false)  # Hold still for the test.
	player.face(1.0)
	player.heal_full()
	for press: int in 3:
		Input.action_press("attack")
		await _frames(2)
		Input.action_release("attack")
		await _frames(16)
	await _frames(30)
	_expect(not is_instance_valid(goblin), "sword defeats a goblin")


func _check_petal() -> void:
	var player: Player = _level.player
	var petal: Collectible = _first_of_type(Collectible) as Collectible
	var before: int = GameManager.collected_in_level
	_teleport(player, petal.global_position)
	await _frames(40)
	_expect(GameManager.collected_in_level == before + 1, "petal collected")


func _check_campfire_and_respawn() -> void:
	var player: Player = _level.player
	var campfire: Checkpoint = _first_of_type(Checkpoint) as Checkpoint
	_teleport(player, campfire.global_position)
	await _frames(10)
	_expect(campfire.is_lit, "campfire lights on touch")
	player.die()
	await _frames(150)
	_expect(not player.is_dead(), "respawned after dying")
	_expect(player.global_position.distance_to(campfire.get_respawn_position()) < 2.0,
			"respawned at the campfire")
	await _frames(80)


func _check_shrine_scene() -> void:
	var player: Player = _level.player
	var scene: Cutscene = _first_of_type(Cutscene) as Cutscene
	_teleport(player, scene.global_position + Vector2(-260.0, 0.0))
	await _frames(5)
	Input.action_press("move_right")
	await _frames_until(func() -> bool: return _dialogue_open, 300)
	Input.action_release("move_right")
	_expect(_dialogues_seen.has("shrine_arrive"), "the shrine scene starts")
	# Keep reading until the chapter ends.
	for i: int in 3000:
		if _chapter_completed:
			break
		if _dialogue_open:
			_press("interact")
			await _frames(8)
		else:
			await get_tree().physics_frame
	_expect(_dialogues_seen.has("shrine_kael"), "the Ember Knight speaks")
	_expect(_dialogues_seen.has("shrine_after"), "Grandpa Tomas arrives")
	_expect(_chapter_completed, "the chapter ends after the scene")


## Presses and releases an action as real input events, so both polling
## code and _unhandled_input() see it.
func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().physics_frame


func _finish_dialogue() -> void:
	for i: int in 60:
		if not _dialogue_open:
			return
		await _press("interact")
		await _frames(6)


func _find_npc(npc_name: String) -> Npc:
	for child: Node in _level.get_node("%Entities").get_children():
		if child is Npc and child.name == npc_name:
			return child as Npc
	return null


func _first_of_type(type: Variant) -> Node:
	for child: Node in _level.get_node("%Entities").get_children():
		if is_instance_of(child, type):
			return child
	return null


func _teleport(player: Player, at: Vector2) -> void:
	player.global_position = at
	player.velocity = Vector2.ZERO
	player.reset_physics_interpolation()


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _frames_until(condition: Callable, limit: int) -> void:
	for i: int in limit:
		if condition.call():
			return
		await get_tree().physics_frame


func _on_dialogue_started(dialogue_id: String) -> void:
	_dialogue_open = true
	_dialogues_seen.append(dialogue_id)


func _on_dialogue_finished(_dialogue_id: String) -> void:
	_dialogue_open = false


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		print("FAIL ", label)

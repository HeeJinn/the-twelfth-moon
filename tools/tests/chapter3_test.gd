extends Node
## Headless check of Chapter Three on the real map: the layout and seasons,
## Pell's warning and a skeleton's sword stopped by her guard, Hild, the
## flying eyes, each obstacle played with simulated input (the hay loft,
## the footbridge, the ladders up the tall rock, its ledge, the broken
## bridge, the snowy steps, the frost spikes in the ice cave), then the
## Shield Knight's duel including a knock-out and retry, through to the
## chapter's end.
##
## Run from the project folder:
##   godot --headless --path . res://tools/tests/chapter3_test.tscn

const LEVEL_SCENE: PackedScene = preload("res://levels/level.tscn")
const TILE: float = 32.0
const FLOOR_Y: float = 12.0 * TILE

var _failures: int = 0
var _level: LevelLoader
var _player: Player
var _dialogue_open: bool = false
var _dialogues_seen: Array[String] = []
var _chapter_completed: bool = false


func _ready() -> void:
	GameManager.save_path = "user://test_save.cfg"
	EventBus.dialogue_started.connect(func(id: String) -> void:
		_dialogue_open = true
		_dialogues_seen.append(id))
	EventBus.dialogue_finished.connect(func(_id: String) -> void: _dialogue_open = false)
	EventBus.level_completed.connect(func() -> void: _chapter_completed = true)
	GameManager.current_level_index = 2
	_level = LEVEL_SCENE.instantiate() as LevelLoader
	add_child(_level)
	await _frames(30)
	_player = _level.player
	_check_layout()
	await _check_pell()
	await _check_skeleton_throw()
	await _check_hild()
	await _check_flying_eye()
	for child: Node in _level.get_node("%Entities").get_children():
		if child is Enemy or child is FrostSpikes:
			child.queue_free()
	await _check_loft()
	await _check_footbridge()
	await _check_tall_rock()
	await _check_broken_bridge()
	await _check_snowy_steps()
	await _check_frost_spikes()
	await _check_knight_duel()
	print("dialogues seen: ", _dialogues_seen)
	# A sound cut off by quitting would be reported as a leak on exit.
	for wait: int in 120:
		if not Audio.is_busy():
			break
		await get_tree().physics_frame
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(_failures)


func _check_layout() -> void:
	var counts: Dictionary[String, int] = {}
	for child: Node in _level.get_node("%Entities").get_children():
		var kind: String = child.scene_file_path.get_file().get_basename()
		if child is Collectible:
			kind = "petal"
		elif child is Checkpoint:
			kind = "campfire"
		counts[kind] = counts.get(kind, 0) + 1
	print("  entities: ", counts)
	_expect(counts.get("petal", 0) == 5 and counts.get("campfire", 0) == 5,
			"five petals and five campfires")
	_expect(counts.get("skeleton", 0) == 4 and counts.get("flying_eye", 0) == 4,
			"skeletons and flying eyes on the road")
	_expect(counts.get("sheep_white", 0) == 3 and counts.get("sheep_black", 0) == 1
			and counts.get("frog", 0) == 2 and counts.get("snake", 0) == 1
			and counts.get("leaping_fish", 0) == 2, "sheep, frogs, a snake and fish")
	_expect(counts.get("oak_sway", 0) == 4 and counts.get("frost_spikes", 0) == 3,
			"swaying oaks and frost spikes are placed")
	var terrain: TileMapLayer = _level.get_node("%TerrainLayer") as TileMapLayer
	var autumn: int = terrain.get_cell_tile_data(Vector2i(5, 12)).terrain
	var winter: int = terrain.get_cell_tile_data(Vector2i(140, 12)).terrain
	_expect(autumn == 1 and winter == 2, "autumn ground before the river, snow after it")


func _check_pell() -> void:
	await _place(Vector2(16.5 * TILE, FLOOR_Y))
	Input.action_press("move_right")
	await _until(func() -> bool: return _dialogue_open, 300)
	Input.action_release("move_right")
	_expect(_dialogues_seen.has("pell_road"), "Pell calls out on the road")
	await _finish_dialogue()


## The first skeleton throws its sword; raised, her guard stops it.
func _check_skeleton_throw() -> void:
	var skeleton: Enemy = _nearest(Enemy, Vector2(32.5 * TILE, FLOOR_Y))
	await _place(skeleton.global_position + Vector2(-130.0, 0.0))
	_player.face(1.0)
	Input.action_press("block")
	var start: int = _player.health()
	var thrown: bool = await _until(func() -> bool: return _has(ThrownProjectile), 300)
	_expect(thrown, "the skeleton throws its sword")
	await _until(func() -> bool: return not _has(ThrownProjectile), 200)
	_expect(_player.health() == start, "her guard stops the thrown sword")
	Input.action_release("block")
	await _frames(20)


func _check_hild() -> void:
	var hild: Npc = _nearest(Npc, Vector2(48.5 * TILE, FLOOR_Y))
	await _place(hild.global_position + Vector2(-30.0, 0.0))
	await _frames(20)
	await _press(&"interact")
	await _until(func() -> bool: return _dialogue_open, 60)
	_expect(_dialogues_seen.has("hild"), "Hild the shepherdess talks to her")
	await _finish_dialogue()


## A flying eye can be reached with a jump and a swing.
func _check_flying_eye() -> void:
	var eye: Enemy = _nearest(Enemy, Vector2(89.5 * TILE, 9.0 * TILE))
	eye.set_physics_process(false)
	await _place(eye.global_position * Vector2(1.0, 0.0) + Vector2(-26.0, FLOOR_Y))
	_player.face(1.0)
	Input.action_press("jump")
	await _frames(14)
	await _tap("attack")
	await _frames(20)
	Input.action_release("jump")
	await _frames(30)
	var health: int = eye.get(&"_health") if is_instance_valid(eye) else 0
	_expect(health < 2, "a jump attack reaches a flying eye")


func _check_loft() -> void:
	await _place(Vector2(53.5 * TILE, FLOOR_Y))
	await _hop_to(55.0, 10.0)
	await _hop_to(56.0, 8.0)
	_expect(_player.global_position.y <= 8.0 * TILE + 1.0, "hops up to the hay loft")


func _check_footbridge() -> void:
	await _place(Vector2(73.5 * TILE, FLOOR_Y))
	Input.action_press("move_right")
	await _until(func() -> bool: return _player.global_position.x > 83.0 * TILE, 180)
	Input.action_release("move_right")
	await _frames(10)
	_expect(absf(_player.global_position.y - FLOOR_Y) < 1.0, "walks over the pond's footbridge")


## The tall rock: up the first ladder onto it, up the second to the branch.
func _check_tall_rock() -> void:
	await _place(Vector2(97.5 * TILE, FLOOR_Y))
	Input.action_press("move_up")
	await _until(func() -> bool: return _player.state_name() == &"Climb", 20)
	await _until(func() -> bool: return _player.state_name() != &"Climb", 240)
	Input.action_release("move_up")
	await _frames(10)
	print("  top of the first ladder: %s" % _player.global_position)
	_expect(absf(_player.global_position.y - 9.0 * TILE) < 1.5, "climbs the ladder onto the rock")
	await _place(Vector2(99.5 * TILE, 9.0 * TILE))
	Input.action_press("move_up")
	await _until(func() -> bool: return _player.state_name() == &"Climb", 20)
	await _until(func() -> bool: return _player.state_name() != &"Climb", 240)
	Input.action_release("move_up")
	await _frames(10)
	_expect(absf(_player.global_position.y - 6.0 * TILE) < 1.5, "and the next one up to the branch")
	# The other way up: jump at the rock and grab its edge.
	await _place(Vector2(96.5 * TILE, FLOOR_Y))
	Input.action_press("move_right")
	Input.action_press("jump")
	var grabbed: bool = await _until(func() -> bool: return _player.state_name() == &"LedgeHang", 90)
	Input.action_release("jump")
	Input.action_release("move_right")
	_expect(grabbed, "or jumps at the rock and grabs its edge")
	await _tap("move_up")
	await _until(func() -> bool: return _player.state_name() == &"Idle", 60)
	await _frames(5)
	_expect(absf(_player.global_position.y - 9.0 * TILE) < 1.5, "and pulls herself up")


func _check_broken_bridge() -> void:
	await _place(Vector2(113.5 * TILE, FLOOR_Y))
	Input.action_press("move_right")
	await _until(func() -> bool: return _player.global_position.x >= 115.6 * TILE, 120)
	Input.action_press("jump")
	await _frames(12)
	await _tap("dash")
	await _frames(20)
	Input.action_release("jump")
	await _frames(40)
	Input.action_release("move_right")
	print("  after the broken bridge: %s" % _player.global_position)
	_expect(_player.global_position.x > 119.0 * TILE and absf(_player.global_position.y - FLOOR_Y) < 1.0,
			"jump + dash crosses the broken bridge")


func _check_snowy_steps() -> void:
	await _place(Vector2(141.5 * TILE, FLOOR_Y))
	await _hop_to(144.5, 10.0)
	await _place(Vector2(147.8 * TILE, 10.0 * TILE))
	await _hop_to(150.0, 8.0)
	_expect(absf(_player.global_position.y - 8.0 * TILE) < 1.5, "climbs the snowy steps")


## Frost spikes warn before they burst, and hurt when they do.
func _check_frost_spikes() -> void:
	var spikes: FrostSpikes = load("res://entities/hazard/frost_spikes.tscn").instantiate()
	spikes.calm_time = 0.5
	_level.get_node("%Entities").add_child(spikes)
	spikes.global_position = Vector2(170.5 * TILE, FLOOR_Y)
	await _place(spikes.global_position)
	var start: int = _player.health()
	var sprite: AnimatedSprite2D = spikes.get_node("%Sprite")
	var warned: bool = await _until(func() -> bool: return sprite.animation == &"warn", 60)
	await _frames(5)
	_expect(warned and _player.health() == start, "frost gathers first, as a warning")
	await _until(func() -> bool: return _player.health() < start, 120)
	_expect(_player.health() < start, "then the spikes burst up and hurt")
	spikes.queue_free()
	await _frames(90)


func _check_knight_duel() -> void:
	var arena: Cutscene = null
	var last_campfire: Checkpoint = null
	for child: Node in _level.get_node("%Entities").get_children():
		if child is Cutscene and child.has_node("%Knight"):
			arena = child
		if child is Checkpoint:
			last_campfire = child
	var knight: ShieldKnight = arena.get_node("%Knight") as ShieldKnight
	await _place(last_campfire.global_position)
	await _frames(100)
	await _place(Vector2(194.0 * TILE, FLOOR_Y))
	Input.action_press("move_right")
	await _until(func() -> bool: return _dialogue_open, 400)
	Input.action_release("move_right")
	_expect(_dialogues_seen.has("knight_intro"), "the Shield Knight bars the gate")
	await _finish_dialogue()
	await _frames(40)

	# His shield turns her sword from the front; moonlight goes through.
	var health: int = knight.get(&"_health")
	await _until(func() -> bool: return knight.is_guarding_against(_player.global_position), 120)
	knight.take_hit(1, _player.global_position)
	_expect(knight.get(&"_health") == health, "his raised shield turns her sword")
	knight.take_moon_hit(2, _player.global_position)
	_expect(knight.get(&"_health") == health - 2 and knight.is_open(),
			"moonlight goes through the shield and staggers him")

	# He attacks; her guard stops it.
	await _until(func() -> bool: return not knight.is_open(), 200)
	_player.face(signf(knight.global_position.x - _player.global_position.x))
	Input.action_press("block")
	var before: int = _player.health()
	await _until(func() -> bool: return knight.is_open(), 400)
	_expect(_player.health() == before, "her guard stops his blows")
	Input.action_release("block")

	# Knocked out mid-duel: everything resets.
	_player.die()
	await _frames(200)
	_expect(knight.get(&"_health") == knight.max_health, "a knock-out resets the duel")
	Input.action_press("move_right")
	await _until(func() -> bool: return _dialogue_open, 900)
	Input.action_release("move_right")
	_expect(_dialogues_seen.has("knight_again"), "walking back in starts it again")
	await _finish_dialogue()

	# Strike whenever his shield is down (her sword's reach is tested elsewhere).
	for i: int in 6000:
		if _dialogue_open or _chapter_completed:
			break
		if i % 10 == 0 and knight.is_open():
			knight.take_hit(1, knight.global_position + Vector2(knight.get(&"_facing") * 20.0, 0.0))
		if i % 30 == 0 and _player.health() < 3:
			_player.heal_full()
		await get_tree().physics_frame
	_expect(_dialogues_seen.has("knight_yields"), "he yields when beaten")
	for i: int in 3000:
		if _chapter_completed:
			break
		if _dialogue_open:
			await _press(&"interact")
			await _frames(6)
		else:
			await get_tree().physics_frame
	_expect(_dialogues_seen.has("knight_after"), "Mariane looks toward the keep")
	_expect(_chapter_completed, "the chapter ends")


## A full jump, steering toward column x the whole way (like a player would).
func _hop_to(column: float, row: float) -> void:
	var target: float = column * TILE
	Input.action_press("jump")
	for i: int in 50:
		var gap: float = target - _player.global_position.x
		Input.action_release("move_right")
		Input.action_release("move_left")
		if absf(gap) > 3.0:
			Input.action_press("move_right" if gap > 0.0 else "move_left")
		await get_tree().physics_frame
	Input.action_release("move_right")
	Input.action_release("move_left")
	Input.action_release("jump")
	await _frames(30)
	print("  hop toward (%.1f, %.1f): now %s" % [column, row, _player.global_position / TILE])


func _nearest(type: Variant, to: Vector2) -> Node2D:
	var best: Node2D = null
	for child: Node in _level.get_node("%Entities").get_children():
		if is_instance_of(child, type):
			var node: Node2D = child as Node2D
			if best == null or node.global_position.distance_to(to) < best.global_position.distance_to(to):
				best = node
	return best


func _has(type: Variant) -> bool:
	for child: Node in _level.get_node("%Entities").get_children():
		if is_instance_of(child, type):
			return true
	return false


func _place(at: Vector2) -> void:
	_player.respawn(at)
	await _frames(80)


func _finish_dialogue() -> void:
	for i: int in 80:
		if not _dialogue_open:
			return
		await _press(&"interact")
		await _frames(6)


## A real key event (the dialogue box listens for events, not action state).
func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().physics_frame


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame


func _until(condition: Callable, limit: int) -> bool:
	for i: int in limit:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		print("FAIL ", label)

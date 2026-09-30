extends Node
## Headless check of Chapter Two on the real map: Wren's greeting, then each
## obstacle played with simulated input (the slide tunnel, the dash gap, the
## vine wall, the tall ledge, the chimney by its planks), then the Moon Witch
## fight including a knock-out and retry, through to the chapter's end.
## Monsters are removed first so they don't get in the way of the course.
##
## Run from the project folder:
##   godot --headless --path . res://tools/tests/chapter2_test.tscn

const LEVEL_SCENE: PackedScene = preload("res://levels/level.tscn")
const TILE: float = 16.0
const FLOOR_Y: float = 28.0 * TILE
const PLATEAU_Y: float = 18.0 * TILE

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
	GameManager.current_level_index = 1
	_level = LEVEL_SCENE.instantiate() as LevelLoader
	add_child(_level)
	await _frames(30)
	_player = _level.player
	_check_layout()
	await _check_night_sky()
	await _check_wren()
	for child: Node in _level.get_node("%Entities").get_children():
		if child is Enemy:
			child.queue_free()
	await _check_tunnel()
	await _check_gap()
	await _check_vine_wall()
	await _check_ledge_block()
	await _check_chimney()
	await _check_witch_fight()
	print("dialogues seen: ", _dialogues_seen)
	# A sound cut off by quitting would be reported as a leak on exit.
	for wait: int in 120:
		if not Audio.is_busy():
			break
		await get_tree().physics_frame
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(_failures)


func _check_layout() -> void:
	var petals: int = 0
	var enemies: int = 0
	var campfires: int = 0
	for child: Node in _level.get_node("%Entities").get_children():
		petals += 1 if child is Collectible else 0
		enemies += 1 if child is Enemy else 0
		campfires += 1 if child is Checkpoint else 0
	print("petals %d, monsters %d, campfires %d" % [petals, enemies, campfires])
	_expect(petals == 5 and campfires == 4 and enemies == 8, "chapter two is populated")
	var terrain: TileMapLayer = _level.get_node("%TerrainLayer") as TileMapLayer
	_expect(terrain.tile_set.tile_size == Vector2i(16, 16), "forest uses 16 px tiles")


## The Starry Night sky: a drifting sky, the red moon, and three sideways
## tiling silhouette layers, with shooting stars that fall one at a time.
func _check_night_sky() -> void:
	var background: Node = _level.get_child(0)
	var layers: Array[String] = []
	for child: Node in background.get_children():
		if child is Parallax2D:
			layers.append(child.name)
	print("  sky layers: ", layers)
	_expect(layers == ["Sky", "RedMoon", "Stars", "Far", "Mid", "Near"],
			"the night sky has its sky, red moon, stars and three silhouette layers")
	var tiling: bool = true
	for layer: String in ["Far", "Mid", "Near"]:
		var parallax: Parallax2D = background.get_node(layer) as Parallax2D
		tiling = tiling and parallax.repeat_size.x == 640.0 and parallax.scroll_scale.x > 0.0
	_expect(tiling, "the silhouettes tile sideways and scroll")
	var stars: ShootingStars = background.get_node("Stars/ShootingStars") as ShootingStars
	_expect(not stars.is_shooting(), "no star is falling at first")
	stars.shoot()
	_expect(stars.is_shooting(), "a shooting star can be sent across")
	stars.shoot()
	await _frames(120)
	_expect(not stars.is_shooting(), "and it is gone after a moment, one star at a time")


func _check_wren() -> void:
	await _place(Vector2(10.5 * TILE, FLOOR_Y))
	Input.action_press("move_right")
	await _until(func() -> bool: return _dialogue_open, 200)
	Input.action_release("move_right")
	_expect(_dialogues_seen.has("wren"), "Wren greets her at the forest edge")
	await _finish_dialogue()


func _check_tunnel() -> void:
	await _place(Vector2(40.5 * TILE, FLOOR_Y))
	Input.action_press("move_right")
	await _frames(25)
	Input.action_press("move_down")
	await _frames(70)
	Input.action_release("move_down")
	await _frames(20)
	Input.action_release("move_right")
	# She keeps sliding on her own until there's room to stand.
	await _until(func() -> bool: return _player.state_name() != &"Slide", 120)
	await _frames(10)
	print("  after the hollow log: x=%.0f" % _player.global_position.x)
	_expect(_player.global_position.x > 54.0 * TILE, "slides under the hollow log")


func _check_gap() -> void:
	await _place(Vector2(76.5 * TILE, FLOOR_Y))
	Input.action_press("move_right")
	await _until(func() -> bool: return _player.global_position.x >= 81.0 * TILE + 10.0, 120)
	Input.action_press("jump")
	await _frames(12)
	await _tap("dash")
	await _frames(20)
	Input.action_release("jump")
	await _frames(40)
	Input.action_release("move_right")
	print("  after the gap: %s" % _player.global_position)
	_expect(_player.global_position.x > 88.0 * TILE and absf(_player.global_position.y - FLOOR_Y) < 1.0,
			"jump + air dash crosses the firefly gap")


func _check_vine_wall() -> void:
	await _place(Vector2(119.5 * TILE, FLOOR_Y))
	Input.action_press("move_up")
	await _until(func() -> bool: return _player.state_name() == &"Climb", 20)
	await _until(func() -> bool: return _player.state_name() != &"Climb", 300)
	Input.action_release("move_up")
	await _frames(10)
	_expect(absf(_player.global_position.y - PLATEAU_Y) < 1.5, "climbs the vine to the canopy")


func _check_ledge_block() -> void:
	await _place(Vector2(131.5 * TILE, PLATEAU_Y))
	Input.action_press("move_right")
	Input.action_press("jump")
	await _until(func() -> bool: return _player.state_name() == &"LedgeHang", 90)
	Input.action_release("jump")
	Input.action_release("move_right")
	_expect(_player.state_name() == &"LedgeHang", "grabs the tall ledge")
	await _tap("move_up")
	await _until(func() -> bool: return _player.state_name() == &"Idle", 60)
	await _frames(5)
	_expect(absf(_player.global_position.y - 12.0 * TILE) < 1.5, "climbs onto it")


## The slow, forgiving way up the chimney: plank to plank.
func _check_chimney() -> void:
	await _place(Vector2(152.5 * TILE, PLATEAU_Y))
	await _hop_to(152.5, 14.0)
	await _hop_to(154.5, 10.0)
	await _hop_to(152.5, 7.0)
	# Last hop: up and right onto the treetops (landing or grabbing the edge).
	Input.action_press("move_right")
	Input.action_press("jump")
	await _frames(40)
	Input.action_release("jump")
	await _until(func() -> bool: return _player.state_name() != &"LedgeHang", 5)
	if _player.state_name() == &"LedgeHang":
		await _tap("move_up")
		await _frames(30)
	await _frames(20)
	Input.action_release("move_right")
	print("  top of the chimney: %s" % _player.global_position)
	_expect(absf(_player.global_position.y - 4.0 * TILE) < 1.5 and _player.global_position.x > 156.0 * TILE,
			"climbs the chimney plank by plank to the treetops")


func _check_witch_fight() -> void:
	var arena: Cutscene = null
	var last_campfire: Checkpoint = null
	for child: Node in _level.get_node("%Entities").get_children():
		if child is Cutscene:
			arena = child
		if child is Checkpoint:
			last_campfire = child
	var witch: MoonWitch = arena.get_node("%Witch") as MoonWitch
	# Light Pell's campfire so a knock-out respawns her there.
	await _place(last_campfire.global_position)
	await _frames(5)
	await _place(Vector2(252.0 * TILE, FLOOR_Y))
	Input.action_press("move_right")
	await _until(func() -> bool: return _dialogue_open, 400)
	Input.action_release("move_right")
	_expect(_dialogues_seen.has("witch_intro"), "the Moon Witch greets her")
	await _finish_dialogue()
	await _frames(60)
	_expect(witch.visible, "the fight begins")
	var boss_bar: TextureProgressBar = _level.get_node("HUD").get_node("%BossHealth") as TextureProgressBar
	_expect(boss_bar != null and boss_bar.is_visible_in_tree()
			and boss_bar.max_value == float(witch.max_health),
			"the boss bar shows the Moon Witch's health")

	# Knocked out mid-fight: everything resets.
	_player.die()
	await _frames(200)
	_expect(not witch.visible, "a knock-out resets the fight")
	Input.action_press("move_right")
	await _until(func() -> bool: return _dialogue_open, 900)
	Input.action_release("move_right")
	_expect(_dialogues_seen.has("witch_again"), "walking back in restarts the fight")
	await _finish_dialogue()

	# Strike whenever she can be hit (the sword's own reach is tested elsewhere).
	for i: int in 3000:
		if _dialogue_open or _chapter_completed:
			break
		if i % 20 == 0 and witch.visible:
			witch.take_hit(1, _player.global_position)
		await get_tree().physics_frame
	_expect(_dialogues_seen.has("witch_defeated"), "she yields when beaten")
	for i: int in 3000:
		if _chapter_completed:
			break
		if _dialogue_open:
			await _press(&"interact")
			await _frames(6)
		else:
			await get_tree().physics_frame
	_expect(_dialogues_seen.has("witch_after"), "Mariane wonders why")
	_expect(_chapter_completed, "the chapter ends")


## Jumps toward column `x` (tile units), steering in the air like a person
## would, and lands on the plank at `row`.
func _hop_to(x: float, row: float) -> void:
	var target: float = x * TILE
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
	print("  on plank row %d? feet y=%.1f (want %.0f)" % [row, _player.global_position.y, row * TILE])


func _place(at: Vector2) -> void:
	_player.respawn(at)
	await _frames(80)


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame


func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().physics_frame


func _finish_dialogue() -> void:
	for i: int in 80:
		if not _dialogue_open:
			return
		await _press(&"interact")
		await _frames(6)


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

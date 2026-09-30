extends Node
## Saves screenshots of Chapter Three and the Red Ribbon memory, for checking
## art without playing. Needs a window (not headless).
##
## Run from the project folder, once per part:
##   godot --path . res://tools/tests/chapter3_screenshots.tscn -- <folder> road
##   godot --path . res://tools/tests/chapter3_screenshots.tscn -- <folder> duel
##   godot --path . res://tools/tests/chapter3_screenshots.tscn -- <folder> memory
##   godot --path . res://tools/tests/chapter3_screenshots.tscn -- <folder> fx

const LEVEL_SCENE: PackedScene = preload("res://levels/level.tscn")
const MEMORY_SCENE: PackedScene = preload("res://story/memories/memory_ribbon.tscn")
const TILE: float = 32.0
## Road spots to photograph: (column, feet row).
const ROAD_SPOTS: Array[Vector2] = [
	Vector2(8, 12), Vector2(27, 11), Vector2(45, 12), Vector2(55, 12), Vector2(68, 12),
	Vector2(78, 12), Vector2(88, 12), Vector2(101, 6), Vector2(108, 12), Vector2(114, 12),
	Vector2(128, 12), Vector2(140, 12), Vector2(151, 8), Vector2(166, 12), Vector2(176, 12),
	Vector2(184, 12), Vector2(192, 12),
]

var _output_dir: String = ""
var _dialogue_open: bool = false


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_output_dir = args[0] if args.size() > 0 else OS.get_user_data_dir()
	var part: String = args[1] if args.size() > 1 else "road"
	EventBus.dialogue_started.connect(func(_id: String) -> void: _dialogue_open = true)
	EventBus.dialogue_finished.connect(func(_id: String) -> void: _dialogue_open = false)
	match part:
		"road":
			await _shoot_road()
		"duel":
			await _shoot_duel()
		"memory":
			await _shoot_memory()
		"fx":
			await _shoot_effects()
	get_tree().quit()


func _load_chapter() -> LevelLoader:
	GameManager.current_level_index = 2
	var level: LevelLoader = LEVEL_SCENE.instantiate() as LevelLoader
	add_child(level)
	await _frames(60)
	return level


func _shoot_road() -> void:
	var level: LevelLoader = await _load_chapter()
	await _capture("r00_start")
	for spot: Vector2 in ROAD_SPOTS:
		level.player.respawn(Vector2(spot.x * TILE + TILE / 2.0, spot.y * TILE))
		await _frames(75)
		if _dialogue_open:
			await _frames(40)
			await _capture("r_x%d_talk" % spot.x)
			await _finish_dialogue()
			await _frames(20)
		await _capture("r_x%d" % spot.x)
	# A skeleton winding up its throw, and the sword in flight.
	level.player.respawn(Vector2(28.0 * TILE, 12.0 * TILE))
	await _frames(40)
	for i: int in 180:
		if _has_node_of(ThrownProjectile, level):
			break
		await get_tree().physics_frame
	await _frames(8)
	await _capture("r_skeleton_throw")


func _shoot_duel() -> void:
	var level: LevelLoader = await _load_chapter()
	level.player.respawn(Vector2(194.0 * TILE, 12.0 * TILE))
	await _frames(40)
	Input.action_press("move_right")
	await _frames_until(func() -> bool: return _dialogue_open, 400)
	Input.action_release("move_right")
	await _frames(60)
	await _capture("d0_intro")
	await _finish_dialogue()
	var knight: ShieldKnight = null
	for child: Node in level.get_node("%Entities").get_children():
		if child is Cutscene and child.has_node("%Knight"):
			knight = child.get_node("%Knight") as ShieldKnight
	for i: int in 8:
		await _frames(45)
		level.player.heal_full()
		await _capture("d%d_duel" % (i + 1))
	# Half health: sweeps and frost spikes join in.
	knight.take_moon_hit(4, level.player.global_position)
	for i: int in 6:
		await _frames(40)
		level.player.heal_full()
		await _capture("d%d_angry" % (i + 1))


func _shoot_memory() -> void:
	add_child(MEMORY_SCENE.instantiate())
	await _frames(150)
	await _capture("m1_opening")
	await _finish_dialogue()
	await _frames(90)
	await _capture("m2_ribbon")


## The small feedback every chapter now has: a "!" before a monster
## attacks, sparks where her sword lands, dust when she lands.
func _shoot_effects() -> void:
	var level: LevelLoader = await _load_chapter()
	var player: Player = level.player
	var skeleton: Enemy = null
	for child: Node in level.get_node("%Entities").get_children():
		if child is Enemy and child.scene_file_path.ends_with("skeleton.tscn"):
			skeleton = child
			break
	player.respawn(skeleton.global_position + Vector2(-110.0, 0.0))
	for i: int in 240:
		if skeleton.get(&"_attacking"):
			break
		await get_tree().physics_frame
	await _frames(4)
	await _capture("x1_alert")
	player.respawn(skeleton.global_position + Vector2(-22.0, 0.0))
	await _frames(70)
	player.face(1.0)
	Input.action_press("attack")
	await get_tree().physics_frame
	Input.action_release("attack")
	await _frames(9)
	await _capture("x2_hit_spark")
	player.respawn(Vector2(101.0 * TILE, 6.0 * TILE))
	await _frames(70)
	Input.action_press("move_right")
	for i: int in 120:
		if player.is_on_floor() and player.global_position.y > 8.0 * TILE:
			break
		await get_tree().physics_frame
	Input.action_release("move_right")
	await _frames(3)
	await _capture("x3_landing_dust")


func _has_node_of(type: Variant, level: LevelLoader) -> bool:
	for child: Node in level.get_node("%Entities").get_children():
		if is_instance_of(child, type):
			return true
	return false


func _finish_dialogue() -> void:
	for i: int in 80:
		if not _dialogue_open:
			return
		for pressed: bool in [true, false]:
			var event: InputEventAction = InputEventAction.new()
			event.action = &"interact"
			event.pressed = pressed
			Input.parse_input_event(event)
			await get_tree().physics_frame
		await _frames(6)


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(_output_dir.path_join(file_name + ".png"))


func _frames_until(condition: Callable, limit: int) -> void:
	for i: int in limit:
		if condition.call():
			return
		await get_tree().physics_frame


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame

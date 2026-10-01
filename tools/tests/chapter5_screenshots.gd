extends Node
## Saves screenshots of Chapter Five, the Twelfth Night, for checking its art
## and layout without playing. Needs a window (not headless).
##
## Run from the project folder:
##   godot --path . res://tools/tests/chapter5_screenshots.tscn -- <output folder> [roof|fight]
## "roof" (the default) photographs the way up; "fight" the fight with Kael, from
## his greeting through the fire to the reveal, the last petal and the moon cracking.

const LEVEL_SCENE: PackedScene = preload("res://levels/level.tscn")
const TILE: float = 16.0
## Spots to photograph: (column, row of the floor she stands on).
const SPOTS: Array[Vector2] = [
	Vector2(4, 24), Vector2(20, 24), Vector2(36, 24), Vector2(50, 20), Vector2(56, 21),
	Vector2(63, 18), Vector2(71, 15), Vector2(80, 12), Vector2(92, 12),
]

var _output_dir: String = ""
var _dialogue_open: bool = false
var _dialogue_id: String = ""


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_output_dir = args[0] if args.size() > 0 else OS.get_user_data_dir()
	var mode: String = args[1] if args.size() > 1 else "roof"
	EventBus.dialogue_started.connect(func(id: String) -> void:
		_dialogue_open = true
		_dialogue_id = id)
	EventBus.dialogue_finished.connect(func(_id: String) -> void: _dialogue_open = false)
	GameManager.save_path = "user://test_save.cfg"
	GameManager.current_level_index = 4
	var level: LevelLoader = LEVEL_SCENE.instantiate() as LevelLoader
	add_child(level)
	await _frames(80)
	if mode == "fight":
		await _fight(level)
	else:
		await _capture("r00_start")
		for spot: Vector2 in SPOTS:
			level.player.respawn(Vector2(spot.x * TILE + TILE / 2.0, spot.y * TILE))
			await _frames(75)
			await _read_through()
			await _frames(10)
			await _capture("r_x%d" % spot.x)
	get_tree().quit()


func _fight(level: LevelLoader) -> void:
	var player: Player = level.player
	player.respawn(Vector2(92.5 * TILE, 12.0 * TILE))
	await _frames(80)
	Input.action_press("move_right")
	for i: int in 900:
		if _dialogue_open:
			break
		await get_tree().physics_frame
	Input.action_release("move_right")
	await _frames(70)
	await _capture("f0_greeting")
	await _read_through()
	var arena: Node = null
	for child: Node in level.get_node("%Entities").get_children():
		if child is Cutscene and child.has_node("%Kael"):
			arena = child
	var kael: EmberKnight = arena.get_node("%Kael") as EmberKnight
	await _frames(40)
	await _capture("f1_fight")
	# His sword held high (the "!"), then the swing.
	await _until(func() -> bool: return kael.get(&"_held") == true, 600)
	await _capture("f2_wind_up")
	await _until(func() -> bool: return kael.is_open(), 300)
	player.heal_full()
	# Down to half: his words before the fire.
	await _strike_until(kael, player, func() -> bool: return _dialogue_open)
	await _frames(40)
	await _capture("f3_fire_words")
	await _read_through()
	# The cast, the rings, and the embers bursting.
	await _until(func() -> bool: return kael.get(&"_phase") == EmberKnight.Phase.CASTING, 300)
	await _frames(30)
	await _capture("f4_cast")
	await _until(func() -> bool: return _ember_showing(arena, &"warn"), 120)
	await _capture("f5_rings")
	await _until(func() -> bool: return _ember_showing(arena, &"burst"), 120)
	await _capture("f6_embers")
	player.heal_full()
	# Beat him: the reveal on his knee.
	await _strike_until(kael, player, func() -> bool: return _dialogue_id == "reveal")
	await _frames(40)
	await _capture("f7_reveal")
	for line: int in 3:
		await _press_interact()
		await _frames(50)
	await _capture("f8_ember_speaks")
	await _read_through()
	await _frames(60)
	await _capture("f9_fallen_petal")
	await _frames(120)
	await _capture("fa_petal")
	for i: int in 600:
		if _dialogue_open:
			break
		await get_tree().physics_frame
	await _read_through()
	await _frames(45)
	await _capture("fb_moon_cracks")


## Hits him whenever he's open (reading through words) until `condition`.
func _strike_until(kael: EmberKnight, player: Player, condition: Callable) -> void:
	for i: int in 9000:
		if condition.call():
			return
		if _dialogue_open and _dialogue_id == "kael_fire" and not condition.call():
			await _read_through()
			continue
		if i % 10 == 0 and kael.is_open():
			kael.take_hit(1, player.global_position)
		if i % 20 == 0:
			player.heal_full()
		await get_tree().physics_frame


func _ember_showing(arena: Node, animation: StringName) -> bool:
	for child: Node in arena.get_children():
		if child is FrostSpikes:
			var sprite: AnimatedSprite2D = child.get_node("%Sprite") as AnimatedSprite2D
			if sprite.visible and sprite.animation == animation and sprite.frame >= 2:
				return true
	return false


func _read_through() -> void:
	for i: int in 80:
		if not _dialogue_open:
			return
		await _press_interact()
		await _frames(6)


func _press_interact() -> void:
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = &"interact"
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().physics_frame


func _until(condition: Callable, limit: int) -> bool:
	for i: int in limit:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_output_dir.path_join(file_name + ".png"))


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame

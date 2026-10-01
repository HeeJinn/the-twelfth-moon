extends Node
## Saves screenshots of Chapter Four, Ember Keep, for checking its art and
## layout without playing. Needs a window (not headless).
##
## Run from the project folder:
##   godot --path . res://tools/tests/chapter4_screenshots.tscn -- <output folder> [crypt|memory]
## "crypt" photographs the Grave Warden's fight (greeting, marks, bolts, the blood
## creature, his last words and his crumbling); "memory" the Oath memory.

const LEVEL_SCENE: PackedScene = preload("res://levels/level.tscn")
const OATH_MEMORY: PackedScene = preload("res://story/memories/memory_oath.tscn")
const TILE: float = 16.0
## Spots to photograph: (column, row of the floor she stands on).
const SPOTS: Array[Vector2] = [
	Vector2(6, 22), Vector2(27, 22), Vector2(52, 20), Vector2(74, 20), Vector2(91, 22),
	Vector2(120, 10), Vector2(134, 10), Vector2(147, 10), Vector2(170, 10), Vector2(183, 10),
	Vector2(196, 16), Vector2(224, 24), Vector2(229, 24), Vector2(255, 24), Vector2(270, 24),
	Vector2(290, 24), Vector2(302, 24), Vector2(316, 24),
]

var _output_dir: String = ""
var _dialogue_open: bool = false


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_output_dir = args[0] if args.size() > 0 else OS.get_user_data_dir()
	EventBus.dialogue_started.connect(func(_id: String) -> void: _dialogue_open = true)
	EventBus.dialogue_finished.connect(func(_id: String) -> void: _dialogue_open = false)
	GameManager.save_path = "user://test_save.cfg"
	GameManager.current_level_index = 3
	var mode: String = args[1] if args.size() > 1 else "keep"
	if mode == "memory":
		add_child(OATH_MEMORY.instantiate())
		for shot: int in 4:
			await _frames(150)
			await _capture("m_oath_%d" % shot)
		get_tree().quit()
		return
	var level: LevelLoader = LEVEL_SCENE.instantiate() as LevelLoader
	add_child(level)
	await _frames(80)
	if mode == "crypt":
		await _crypt(level)
		get_tree().quit()
		return
	await _capture("k00_start")
	for spot: Vector2 in SPOTS:
		level.player.respawn(Vector2(spot.x * TILE + TILE / 2.0, spot.y * TILE))
		await _frames(75)
		# A thought may have started here: read it through so it doesn't cover the shot.
		for i: int in 60:
			if not _dialogue_open:
				break
			for pressed: bool in [true, false]:
				var event: InputEventAction = InputEventAction.new()
				event.action = &"interact"
				event.pressed = pressed
				Input.parse_input_event(event)
				await get_tree().physics_frame
			await _frames(6)
		await _frames(10)
		await _capture("k_x%d" % spot.x)
	get_tree().quit()


## The Grave Warden's fight, from the greeting to the pile of bones.
func _crypt(level: LevelLoader) -> void:
	var player: Player = level.player
	player.respawn(Vector2(326.5 * TILE, 24.0 * TILE))
	await _frames(80)
	Input.action_press("move_right")
	for i: int in 900:
		if _dialogue_open:
			break
		await get_tree().physics_frame
	Input.action_release("move_right")
	await _frames(60)
	await _capture("w0_greeting")
	await _read_through()
	var arena: Node = null
	for child: Node in level.get_node("%Entities").get_children():
		if child is Cutscene and child.has_node("%Warden"):
			arena = child
	var warden: GraveWarden = arena.get_node("%Warden") as GraveWarden
	await _frames(40)
	await _capture("w1_fight")
	# Two volleys of bolts and a summon: a shot of each warning and each strike.
	var shots: Array[String] = ["w2_marks", "w3_bolts", "w4_marks", "w5_bolts", "w6_blob", "w7_creature"]
	var shot: int = 0
	var phase: StringName = &"warn"
	for i: int in 2400:
		if shot >= shots.size():
			break
		if i % 20 == 0:
			player.heal_full()
		for child: Node in arena.get_children():
			if child is FrostSpikes:
				var sprite: AnimatedSprite2D = child.get_node("%Sprite") as AnimatedSprite2D
				if sprite.visible and sprite.animation == phase and sprite.frame >= 2:
					await _capture(shots[shot])
					shot += 1
					phase = &"burst" if phase == &"warn" else &"warn"
					break
		await get_tree().physics_frame
	# Angry: three bolts at a time.
	warden.set(&"_health", 4)
	await _until_weary(warden)
	await _capture("w8_weary")
	for i: int in 4:
		warden.take_hit(1, player.global_position)
		await _frames(2)
		if not warden.is_fallen():
			await _until_weary(warden)
	for i: int in 300:
		if _dialogue_open:
			break
		await get_tree().physics_frame
	await _frames(30)
	await _capture("w9_last_words")
	await _read_through()
	await _frames(25)
	await _capture("wa_crumbling")
	await _frames(150)
	await _capture("wb_bones")


func _until_weary(warden: GraveWarden) -> void:
	for i: int in 900:
		if warden.is_weary():
			return
		await get_tree().physics_frame


func _read_through() -> void:
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
	get_viewport().get_texture().get_image().save_png(_output_dir.path_join(file_name + ".png"))


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame

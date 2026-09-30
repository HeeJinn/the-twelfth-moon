extends Node
## Saves one contact sheet of Mariane in every animation, standing on real
## ground in the moves test course, to check that each pose lines up with
## her feet and faces the right way. Posed ones first (a middle frame of
## each animation, facing right then left), then the moves that need a
## wall, ledge or vine, done for real. Needs a window (not headless).
##
## Run from the project folder:
##   godot --path . res://tools/tests/heroine_screenshots.tscn -- <folder>

const LEVEL_SCENE: PackedScene = preload("res://levels/level.tscn")
const TEST_MAP: LevelData = preload("res://tools/tests/maps/moves_test.tres")
const TILE: float = 16.0
const FLOOR_Y: float = 22.0 * TILE
## Size of each picture around her (viewport px) and how much it's enlarged.
const CELL: Vector2i = Vector2i(96, 72)
const SCALE: int = 2
const COLUMNS: int = 8
## Animation -> the frame to show.
const POSES: Dictionary[StringName, int] = {
	&"idle": 0, &"idle_calm": 3, &"walk": 2, &"run": 2, &"jump": 2, &"up_to_fall": 0,
	&"fall": 1, &"land": 0, &"crouch": 2, &"stand_up": 0, &"crouch_attack": 5,
	&"slide": 4, &"slide_end": 1, &"attack": 3, &"attack_2": 2, &"attack_3": 2,
	&"air_attack": 3, &"air_attack_2": 2, &"dash": 0, &"air_dash": 0,
	&"dash_attack": 2, &"guard_up": 1, &"guard": 3, &"guard_down": 0, &"block": 2,
	&"charge": 4, &"charge_hold": 1, &"moon_slash": 1, &"cast": 9, &"heal": 5,
	&"restore": 5, &"hurt": 1, &"death": 6, &"asleep": 0, &"get_up": 3,
	&"ledge_grab": 1, &"ledge_hang": 2, &"wall_slide": 0, &"ledge_climb": 3,
	&"climb": 2,
}

var _output_dir: String = ""
var _cells: Array[Image] = []
var _level: LevelLoader
var _player: Player


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_output_dir = args[0] if args.size() > 0 else OS.get_user_data_dir()
	_level = LEVEL_SCENE.instantiate() as LevelLoader
	_level.level_data_override = TEST_MAP
	add_child(_level)
	await _frames(20)
	_player = _level.player
	for facing: float in [1.0, -1.0]:
		await _pose_all(facing)
	await _real_moves()
	_save_sheet()
	get_tree().quit()


func _pose_all(facing: float) -> void:
	_player.respawn(Vector2(52.5 * TILE, FLOOR_Y))
	await _frames(90)
	_player.set_physics_process(false)
	_player.face(facing)
	for animation: StringName in POSES:
		_player.play_animation(animation)
		_player.sprite.pause()
		_player.sprite.frame = POSES[animation]
		await _frames(2)
		await _capture()
	_player.set_physics_process(true)


func _real_moves() -> void:
	# Hanging from the tall block, then halfway up it.
	_player.respawn(Vector2(22.5 * TILE, FLOOR_Y))
	await _frames(80)
	Input.action_press("move_right")
	Input.action_press("jump")
	await _until(func() -> bool: return _player.state_name() == &"LedgeHang", 90)
	Input.action_release("jump")
	Input.action_release("move_right")
	await _frames(20)
	await _capture()
	Input.action_press("move_up")
	await _frames(3)
	Input.action_release("move_up")
	await _frames(12)
	await _capture()
	await _frames(40)
	await _capture()
	# Sliding down the tall wall.
	_player.respawn(Vector2(33.0 * TILE, 9.0 * TILE))
	Input.action_press("move_right")
	await _until(func() -> bool: return _player.state_name() == &"WallSlide", 60)
	await _frames(10)
	await _capture()
	Input.action_release("move_right")
	# Halfway up the vine.
	_player.respawn(Vector2(44.5 * TILE, FLOOR_Y))
	await _frames(80)
	Input.action_press("move_up")
	await _frames(50)
	await _capture()
	Input.action_release("move_up")
	# A dash (afterimages), a Moon Slash (wave) and a Moon Spark in flight.
	_player.respawn(Vector2(50.5 * TILE, FLOOR_Y))
	await _frames(80)
	_player.face(1.0)
	await _tap("dash")
	await _frames(6)
	await _capture()
	await _frames(40)
	Input.action_press("attack")
	await _until(func() -> bool: return _player.state_name() == &"Charge", 60)
	await _frames(40)
	Input.action_release("attack")
	await _frames(12)
	await _capture()
	await _frames(60)
	await _tap("spell")
	await _frames(40)
	await _capture()


func _capture() -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var at: Vector2 = _player.get_global_transform_with_canvas().origin
	var corner: Vector2i = Vector2i(roundi(at.x) - CELL.x / 2, roundi(at.y) - CELL.y + 16)
	corner = corner.clamp(Vector2i.ZERO, image.get_size() - CELL)
	var cell: Image = image.get_region(Rect2i(corner, CELL))
	cell.resize(CELL.x * SCALE, CELL.y * SCALE, Image.INTERPOLATE_NEAREST)
	_cells.append(cell)


func _save_sheet() -> void:
	var size: Vector2i = CELL * SCALE
	var rows: int = ceili(_cells.size() / float(COLUMNS))
	var sheet: Image = Image.create_empty(COLUMNS * size.x, rows * size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.12))
	for i: int in _cells.size():
		var cell: Image = _cells[i]
		cell.convert(Image.FORMAT_RGBA8)
		var spot: Vector2i = Vector2i(i % COLUMNS * size.x, i / COLUMNS * size.y)
		sheet.blit_rect(cell, Rect2i(Vector2i.ZERO, size), spot)
		# A thin frame between cells.
		sheet.fill_rect(Rect2i(spot, Vector2i(size.x, 1)), Color(0.1, 0.1, 0.12))
		sheet.fill_rect(Rect2i(spot, Vector2i(1, size.y)), Color(0.1, 0.1, 0.12))
	sheet.save_png(_output_dir.path_join("heroine_poses.png"))
	print("saved %d poses" % _cells.size())


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

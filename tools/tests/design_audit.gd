extends Node
## Prints the numbers behind a design review (not a pass/fail test): each
## chapter's size, what's in it, the distance between campfires, bottomless
## drops and how much there is to read; how the follow camera trails her when
## she runs and bobs when she jumps; and how often each boss is off screen
## while she chases it.
##
## Run from the project folder:
##   godot --headless --path . res://tools/tests/design_audit.tscn

const LEVEL_SCENE: PackedScene = preload("res://levels/level.tscn")
const HALF_VIEW: Vector2 = Vector2(240.0, 135.0)

var _dialogue_open: bool = false


func _ready() -> void:
	GameManager.save_path = "user://test_save.cfg"
	EventBus.dialogue_started.connect(func(_id: String) -> void: _dialogue_open = true)
	EventBus.dialogue_finished.connect(func(_id: String) -> void: _dialogue_open = false)
	for index: int in GameManager.LEVELS.size():
		await _audit_level(index)
	await _audit_camera()
	await _audit_boss(1, "%Witch")
	await _audit_boss(2, "%Knight")
	await _audit_boss(3, "%Warden")
	await _audit_boss(4, "%Kael")
	for wait: int in 120:
		if not Audio.is_busy():
			break
		await get_tree().physics_frame
	get_tree().quit()


func _audit_level(index: int) -> void:
	var level: LevelLoader = await _load(index)
	var data: LevelData = GameManager.get_current_level()
	var rows: PackedStringArray = FileAccess.get_file_as_string(data.map_path).replace("\r", "").strip_edges().split("\n")
	var tile: float = level.get_node("%TerrainLayer").tile_set.tile_size.x
	var width: int = rows[0].length()
	print("\n== %s: %s (%d x %d cells of %d px = %d px wide)" % [
			data.title, data.subtitle, width, rows.size(), tile, width * tile])
	var counts: Dictionary[String, int] = {}
	var fires: Array[float] = []
	var ends: Array[float] = []
	var hints: Array[String] = []
	for child: Node in level.get_node("%Entities").get_children():
		var kind: String = "other"
		var path: String = child.scene_file_path
		if child is Enemy:
			kind = "monsters"
		elif child is FrostSpikes:
			kind = "warned hazards"
		elif child is Checkpoint:
			kind = "campfires"
			fires.append((child as Node2D).global_position.x)
		elif child is Collectible:
			kind = "petals"
		elif path.contains("thought_"):
			kind = "thoughts"
		elif path.contains("/hint/"):
			kind = "hints"
			hints.append(path.get_file().get_basename().trim_prefix("hint_"))
		elif path.contains("/npc/"):
			kind = "villagers"
		elif child is Cutscene or path.contains("goal"):
			kind = "endings"
			ends.append((child as Node2D).global_position.x)
		elif path.contains("/platform/"):
			kind = "moving platforms"
		elif path.contains("/critter/"):
			kind = "critters"
		elif path.contains("/prop/") or path.contains("decor"):
			kind = "props"
		counts[kind] = counts.get(kind, 0) + 1
	print("  ", counts)
	print("  hints: ", ", ".join(hints))
	fires.sort()
	var start: float = level.player.global_position.x
	var stops: Array[float] = [start]
	stops.append_array(fires)
	if not ends.is_empty():
		stops.append(ends.max())
	var gaps: Array[String] = []
	var longest: float = 0.0
	for i: int in range(1, stops.size()):
		var gap: float = stops[i] - stops[i - 1]
		longest = maxf(longest, gap)
		gaps.append("%d" % roundi(gap / tile))
	print("  start, campfires, end: gaps in cells ", ", ".join(gaps),
			"; longest %.0f px, about %.0f s at full run" % [longest, longest / 110.0])
	# Columns with nothing solid in them: falling there is a fall out of the map.
	var open: Array[String] = []
	var run_start: int = -1
	for x: int in width:
		var solid: bool = false
		for row: String in rows:
			if x < row.length() and row[x] in "#=|H~-":
				solid = true
				break
		if not solid and run_start < 0:
			run_start = x
		elif solid and run_start >= 0:
			open.append("%d-%d" % [run_start, x - 1])
			run_start = -1
	print("  bottomless columns: ", ", ".join(open) if not open.is_empty() else "none")
	var text: String = FileAccess.get_file_as_string(data.dialogue_path)
	var lines: int = 0
	for line: String in text.split("\n"):
		if not line.is_empty() and not line.begins_with("#") and not line.begins_with("["):
			lines += 1
	print("  lines of dialogue in the chapter's script: %d" % lines)
	level.queue_free()
	await _frames(5)


## Chapter One's open village: how the camera trails her running and bobs with a jump.
func _audit_camera() -> void:
	var level: LevelLoader = await _load(0)
	var player: Player = level.player
	var camera: Camera2D = player.get_camera()
	print("\n== Camera (Chapter One): smoothing %s at %.1f, drag %s, offset %s" % [
			camera.position_smoothing_enabled, camera.position_smoothing_speed,
			camera.drag_horizontal_enabled or camera.drag_vertical_enabled, camera.position])
	player.respawn(Vector2(40.5 * 32.0, player.global_position.y), false)
	await _frames(90)
	Input.action_press("move_right")
	await _frames(150)
	var lead: float = camera.get_screen_center_position().x - player.global_position.x
	Input.action_release("move_right")
	print("  running right, the view leads her by %.0f px: she sees %.0f px ahead, %.0f px behind" % [
			lead, HALF_VIEW.x + lead, HALF_VIEW.x - lead])
	await _frames(90)
	var rest: float = camera.get_screen_center_position().y
	var top: float = rest
	var bottom: float = rest
	Input.action_press("jump")
	for i: int in 70:
		if i == 30:
			Input.action_release("jump")
		await get_tree().physics_frame
		top = minf(top, camera.get_screen_center_position().y)
		bottom = maxf(bottom, camera.get_screen_center_position().y)
	print("  a full jump in place moves the view %.0f px up and back (her jump rises 80 px)" % (rest - top))
	var feet_to_bottom: float = rest + HALF_VIEW.y - player.global_position.y
	print("  standing, the view shows %.0f px below her feet and %.0f px above" % [
			feet_to_bottom, HALF_VIEW.y * 2.0 - feet_to_bottom])
	level.queue_free()
	await _frames(5)


## Walks into a boss arena, then chases the boss for 30 s (she follows it when
## it's more than 60 px away) and counts the frames it is out of view.
func _audit_boss(index: int, boss_path: String) -> void:
	var level: LevelLoader = await _load(index)
	var player: Player = level.player
	var arena: Cutscene = null
	for child: Node in level.get_node("%Entities").get_children():
		if child is Cutscene and child.has_node(boss_path):
			arena = child
	var boss: Node2D = arena.get_node(boss_path) as Node2D
	player.respawn(arena.global_position + Vector2(-300.0, 0.0))
	await _frames(80)
	Input.action_press("move_right")
	for i: int in 900:
		if _dialogue_open:
			break
		await get_tree().physics_frame
	Input.action_release("move_right")
	await _read_through()
	await _frames(90)
	var frames: int = 1800
	var hidden: int = 0
	var edge: int = 0
	var widest: float = 0.0
	for i: int in frames:
		if _dialogue_open:
			await _read_through()
		if i % 30 == 0:
			player.heal_full()
		var gap: float = boss.global_position.x - player.global_position.x
		Input.action_release("move_left")
		Input.action_release("move_right")
		if absf(gap) > 60.0:
			Input.action_press("move_right" if gap > 0.0 else "move_left")
		await get_tree().physics_frame
		var camera: Camera2D = get_viewport().get_camera_2d()
		var seen: float = absf(boss.global_position.x - camera.get_screen_center_position().x)
		widest = maxf(widest, seen)
		if seen > HALF_VIEW.x + 8.0:
			hidden += 1
		elif seen > HALF_VIEW.x - 24.0:
			edge += 1
	Input.action_release("move_left")
	Input.action_release("move_right")
	print("\n== %s's fight: out of view %d%% of the time, at the screen's edge %d%%; farthest %.0f px from the middle (half the view is 240)" % [
			boss.name, roundi(100.0 * hidden / frames), roundi(100.0 * edge / frames), widest])
	level.queue_free()
	await _frames(5)


func _load(index: int) -> LevelLoader:
	GameManager.current_level_index = index
	var level: LevelLoader = LEVEL_SCENE.instantiate() as LevelLoader
	add_child(level)
	await _frames(40)
	return level


func _read_through() -> void:
	for i: int in 120:
		if not _dialogue_open:
			return
		for pressed: bool in [true, false]:
			var event: InputEventAction = InputEventAction.new()
			event.action = &"interact"
			event.pressed = pressed
			Input.parse_input_event(event)
			await get_tree().physics_frame
		await _frames(6)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame

extends Node
## Headless check of Chapter Four, Ember Keep, on the real map: what stands
## where, the story text, the keep guard (it winds up, her guard stops its sweep,
## it hurts without a guard, sword hits make it flinch and crumble), the ember
## vents (a ring first, then fire, then calm), every petal within a jump, the two
## climbs in the courtyard, the three lifts up the shaft to the moon gallery, the
## lift across the gap, and the stair at the end.
##
## Run from the project folder:
##   godot --headless --path . res://tools/tests/chapter4_test.tscn

const LEVEL_SCENE: PackedScene = preload("res://levels/level.tscn")
const VENT_SCENE: PackedScene = preload("res://entities/hazard/ember_vent.tscn")
const MOUTH_SCENE: PackedScene = preload("res://entities/hazard/mouth.tscn")
const TENTACLE_SCENE: PackedScene = preload("res://entities/hazard/tentacle.tscn")
const TILE: float = 16.0

var _failures: int = 0
var _level: LevelLoader
var _player: Player
var _entities: Node2D
var _chapter_completed: bool = false
var _dialogue_open: bool = false
## Where each lift stands when the chapter begins (its lower or western end).
var _lift_home: Dictionary[MovingPlatform, Vector2] = {}


func _ready() -> void:
	GameManager.save_path = "user://test_save.cfg"
	EventBus.level_completed.connect(func() -> void: _chapter_completed = true)
	EventBus.dialogue_started.connect(func(_id: String) -> void: _dialogue_open = true)
	EventBus.dialogue_finished.connect(func(_id: String) -> void: _dialogue_open = false)
	GameManager.current_level_index = 3
	_level = LEVEL_SCENE.instantiate() as LevelLoader
	add_child(_level)
	_entities = _level.get_node("%Entities") as Node2D
	await _frames(2)
	for child: Node in _entities.get_children():
		if child is MovingPlatform:
			_lift_home[child as MovingPlatform] = (child as MovingPlatform).position
	await _frames(28)
	_player = _level.player
	_check_layout()
	_check_story_text()
	await _check_keep_guard()
	await _check_warned_hazard(VENT_SCENE, ["a ring shows first, and it does no harm",
			"then the fire bursts", "the fire hurts anyone standing in it", "then it is quiet again"])
	await _check_warned_hazard(MOUTH_SCENE, ["a mouth bares its teeth first, and does no harm",
			"then it snaps shut", "the snap hurts anyone standing on it", "then it lies shut again"])
	await _check_warned_hazard(TENTACLE_SCENE, ["the ground rumbles at a crack first, and does no harm",
			"then a tentacle rises", "it hurts anyone standing over the crack", "then it sinks again"])
	_check_petals_within_a_jump()
	# The rest is about getting around, so nothing else may interfere.
	for child: Node in _entities.get_children():
		if child is Enemy or child is FrostSpikes:
			child.queue_free()
	await _check_courtyard()
	await _check_shaft_lifts()
	await _check_gap_lift()
	await _check_the_stair()
	await _check_chasm()
	await _check_entity()
	await _check_undercroft_walk()
	# A sound cut off by quitting would be reported as a leak on exit.
	for wait: int in 120:
		if not Audio.is_busy():
			break
		await get_tree().physics_frame
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(_failures)


func _check_layout() -> void:
	var counts: Dictionary[String, int] = {}
	for child: Node in _entities.get_children():
		var kind: String = child.scene_file_path.get_file().get_basename()
		if child is Collectible:
			kind = "petal"
		elif child is Checkpoint:
			kind = "campfire"
		counts[kind] = counts.get(kind, 0) + 1
	print("  entities: ", counts)
	_expect(counts.get("petal", 0) == 5 and counts.get("campfire", 0) == 9,
			"five petals and nine campfires")
	_expect(counts.get("amalgam", 0) == 1 and counts.get("mouth", 0) == 2
			and counts.get("tentacle", 0) == 3 and counts.get("floating_rock", 0) == 4
			and counts.get("eldritch_entity", 0) == 1 and counts.get("book_altar", 0) == 1,
			"the undercroft has its Amalgam, mouths, tentacles, floating rocks, face and altar")
	_expect(counts.get("keep_guard", 0) == 5 and counts.get("goblin", 0) == 2
			and counts.get("flying_eye", 0) == 2, "keep guards, goblins and flying eyes")
	_expect(counts.get("ember_vent", 0) == 6 and counts.get("lift_up", 0) == 2
			and counts.get("lift_up_short", 0) == 1 and counts.get("lift_side", 0) == 1,
			"ember vents and four lifts")
	_expect(counts.get("window_arch", 0) > 0 and counts.get("chandelier", 0) > 0
			and counts.get("brazier", 0) > 0, "the keep is dressed with windows, chandeliers and braziers")
	var terrain: TileMapLayer = _level.get_node("%TerrainLayer") as TileMapLayer
	_expect(terrain.tile_set.tile_size == Vector2i(16, 16)
			and terrain.tile_set.get_terrain_name(0, 0) == "stone", "the keep is 16 px stone")


## Every thought trigger in the map has its lines in the chapter's text.
func _check_story_text() -> void:
	var text: String = FileAccess.get_file_as_string("res://story/chapter_04.txt")
	var ids: Array[String] = []
	for line: String in text.split("\n"):
		if line.begins_with("#"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			ids.append(line.trim_prefix("[").trim_suffix("]"))
	var all_found: bool = true
	var thoughts: int = 0
	for child: Node in _entities.get_children():
		if child.scene_file_path.contains("thought_"):
			thoughts += 1
			if not ids.has(str(child.get(&"dialogue_id"))):
				all_found = false
				print("  no lines for ", child.get(&"dialogue_id"))
	_expect(thoughts == 8 and all_found, "all eight thoughts have their lines")
	_expect(not _has_digit(_spoken_lines(text)), "the chapter's text has no numerals (the font has none)")


## The text without its comment lines (which may name files like chapter_03.txt).
func _spoken_lines(text: String) -> String:
	var kept: Array[String] = []
	for line: String in text.split("\n"):
		if not line.begins_with("#"):
			kept.append(line)
	return "\n".join(kept)


func _has_digit(text: String) -> bool:
	for character: String in text:
		if character >= "0" and character <= "9":
			return true
	return false


func _check_keep_guard() -> void:
	var guard: Enemy = _nearest(Enemy, Vector2(26.5 * TILE, 22.0 * TILE)) as Enemy
	var sprite: AnimatedSprite2D = guard.get_node("%AnimatedSprite2D") as AnimatedSprite2D
	_expect(guard.scene_file_path.ends_with("keep_guard.tscn"), "a keep guard stands in the courtyard")
	var start_health: int = _player.health()
	# With her guard up she is safe from the sweep, and she sees it wind up first.
	await _place(guard.global_position + Vector2(-34.0, 0.0))
	_player.face(1.0)
	Input.action_press("block")
	var winding: bool = await _until(func() -> bool: return sprite.animation == &"attack", 300)
	_expect(winding, "the guard winds up its polearm when she comes close")
	await _until(func() -> bool: return sprite.animation != &"attack", 200)
	_expect(_player.health() == start_health, "her guard stops the sweep")
	Input.action_release("block")
	# Without it the sweep hurts.
	await _place(guard.global_position + Vector2(-24.0, 0.0))
	_player.face(1.0)
	var hurt: bool = await _until(func() -> bool: return _player.health() < start_health, 500)
	_expect(hurt, "without a guard the sweep hurts")
	await _place(Vector2(6.5 * TILE, 22.0 * TILE))
	# Sword hits: it flinches, then collapses into bones.
	guard.take_hit(1, guard.global_position + Vector2(-20.0, 0.0))
	_expect(sprite.animation == &"hurt", "a sword hit makes it flinch")
	await _frames(30)
	guard.take_hit(1, guard.global_position + Vector2(-20.0, 0.0))
	await _frames(30)
	guard.take_hit(1, guard.global_position + Vector2(-20.0, 0.0))
	_expect(sprite.animation == &"death", "three hits and it collapses")
	var guard_id: int = guard.get_instance_id()
	var gone: bool = await _until(
			func() -> bool: return not is_instance_valid(instance_from_id(guard_id)), 400)
	_expect(gone, "the bones fade away")


## A fresh vent over flat ground: a ring (no harm), then fire, then quiet.
## A fresh warn-then-strike hazard (ember vent, mouth or tentacle, all the frost
## spikes' script) at her feet on flat ground: the warning does no harm, then it
## strikes and hurts, then it is calm. `labels` names the four checks.
func _check_warned_hazard(scene: PackedScene, labels: Array[String]) -> void:
	await _place(Vector2(40.5 * TILE, 20.0 * TILE))
	var start_health: int = _player.health()
	var hazard: FrostSpikes = scene.instantiate() as FrostSpikes
	hazard.position = _player.position
	_entities.add_child(hazard)
	var sprite: AnimatedSprite2D = hazard.get_node("%Sprite") as AnimatedSprite2D
	await _frames(30)
	_expect(sprite.animation == &"warn" and _player.health() == start_health, labels[0])
	var struck: bool = await _until(func() -> bool: return sprite.animation == &"burst", 90)
	_expect(struck, labels[1])
	var hurt: bool = await _until(func() -> bool: return _player.health() < start_health, 70)
	_expect(hurt, labels[2])
	var calm: bool = await _until(func() -> bool: return not sprite.visible, 120)
	_expect(calm, labels[3])
	hazard.queue_free()


## Every petal is within a jump of the ground, a ledge, or a lift.
func _check_petals_within_a_jump() -> void:
	var worst: float = 0.0
	var space: PhysicsDirectSpaceState2D = _level.get_world_2d().direct_space_state
	for child: Node in _entities.get_children():
		if not child is Collectible:
			continue
		var petal: Collectible = child as Collectible
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
				petal.global_position, petal.global_position + Vector2(0.0, 400.0), 3)
		var hit: Dictionary = space.intersect_ray(query)
		var gap: float = 999.0
		if not hit.is_empty():
			gap = (hit["position"] as Vector2).y - petal.global_position.y
		for lift: MovingPlatform in _lift_home:
			var spans_x: bool = absf(petal.global_position.x - lift.position.x) < 200.0
			if spans_x and lift.position.y >= petal.global_position.y:
				gap = minf(gap, lift.position.y - petal.global_position.y)
		worst = maxf(worst, gap)
		if gap > 76.0:
			print("  too high to reach: petal at ", petal.global_position / TILE, " gap ", gap)
	print("  highest petal above its footing: %.0f px" % worst)
	_expect(worst <= 76.0, "every petal is within a jump (her jump rises eighty px)")


## The step up to the ember hall, and the ledge with the first petal.
func _check_courtyard() -> void:
	await _place(Vector2(13.5 * TILE, 22.0 * TILE))
	Input.action_press("jump")
	await _frames(16)
	Input.action_release("jump")
	await _until(func() -> bool: return _player.is_on_floor(), 90)
	_expect(absf(_player.global_position.y - 18.0 * TILE) < 1.5, "a jump reaches the first petal's ledge")
	await _place(Vector2(31.5 * TILE, 22.0 * TILE))
	Input.action_press("move_right")
	await _frames(25)
	Input.action_press("jump")
	await _until(func() -> bool: return _player.global_position.x > 36.5 * TILE, 120)
	Input.action_release("jump")
	await _until(func() -> bool: return _player.is_on_floor() and _player.global_position.y < 21.0 * TILE, 90)
	Input.action_release("move_right")
	_expect(_player.global_position.x > 36.0 * TILE and absf(_player.global_position.y - 20.0 * TILE) < 1.5,
			"she runs and jumps up the step into the ember hall")


## Up the shaft: lift, ledge, lift, ledge, lift, and off onto the gallery floor.
func _check_shaft_lifts() -> void:
	var lifts: Array[MovingPlatform] = _lifts_in(88.0, 114.0)
	lifts.sort_custom(func(a: MovingPlatform, b: MovingPlatform) -> bool: return a.position.x < b.position.x)
	_expect(lifts.size() == 3, "three lifts rise up the shaft")
	if lifts.size() != 3:
		return
	# Lift A: ride from the shaft floor up to the first ledge.
	await _place(Vector2(91.5 * TILE, 22.0 * TILE))
	await _wait_for_bottom(lifts[0])
	# It docks a tile above the floor: a jump puts her on it, and it carries her up.
	Input.action_press("jump")
	await _frames(20)
	Input.action_release("jump")
	await _until(func() -> bool: return _at_top(lifts[0]), 400)
	await _frames(8)
	_expect(_player.global_position.y <= 18.0 * TILE + 3.0, "the first lift carries her up")
	await _walk_to(94.8 * TILE)
	_expect(absf(_player.global_position.y - 18.0 * TILE) < 2.0, "she steps off onto the first ledge")
	# Lift B: a short jump across the gap, then up.
	await _cross_to(lifts[1], 99.5 * TILE)
	await _until(func() -> bool: return _at_top(lifts[1]), 400)
	await _frames(8)
	_expect(_player.global_position.y <= 14.0 * TILE + 3.0, "the second lift carries her up")
	await _walk_to(103.8 * TILE)
	_expect(absf(_player.global_position.y - 14.0 * TILE) < 2.0, "she steps off onto the second ledge")
	# Lift C: and up to the gallery floor.
	await _cross_to(lifts[2], 108.5 * TILE)
	await _until(func() -> bool: return _at_top(lifts[2]), 400)
	await _frames(8)
	await _walk_to(116.0 * TILE)
	_expect(absf(_player.global_position.y - 10.0 * TILE) < 2.0 and _player.global_position.x > 113.0 * TILE,
			"the third lift brings her out onto the moon gallery")


## The lift that crosses the gap in the gallery.
func _check_gap_lift() -> void:
	var lifts: Array[MovingPlatform] = _lifts_in(146.0, 166.0)
	_expect(lifts.size() == 1, "one lift crosses the gap")
	if lifts.size() != 1:
		return
	var lift: MovingPlatform = lifts[0]
	await _place(Vector2(148.5 * TILE, 10.0 * TILE))
	await _wait_for_bottom(lift)
	Input.action_press("move_right")
	await _until(func() -> bool: return _player.global_position.x > 152.0 * TILE, 90)
	Input.action_release("move_right")
	var start_health: int = _player.health()
	await _until(func() -> bool: return _at_top(lift), 500)
	_expect(_player.global_position.x > 157.0 * TILE, "the lift carries her across the gap")
	await _walk_to(164.0 * TILE)
	_expect(absf(_player.global_position.y - 10.0 * TILE) < 2.0 and _player.health() == start_health
			and not _player.is_dead(), "and she steps off onto the far side")


## The stair at the end of the keep leads down into the cellar under it.
func _check_the_stair() -> void:
	await _place(Vector2(187.5 * TILE, 12.0 * TILE))
	await _walk_right_until(func() -> bool: return _player.global_position.x > 227.0 * TILE, 900)
	await _until(func() -> bool: return _player.is_on_floor(), 60)
	_expect(absf(_player.global_position.y - 24.0 * TILE) < 1.5 and not _player.is_dead(),
			"the stair leads down into the cellar under the keep")


## Across the chasm on the floating rocks, one hop at a time.
func _check_chasm() -> void:
	await _place(Vector2(229.5 * TILE, 24.0 * TILE))
	for column: float in [233.5, 237.5, 241.5, 245.5, 250.0]:
		await _hop_to(column)
		if _player.is_dead():
			break
	_expect(_player.global_position.x > 248.0 * TILE and not _player.is_dead()
			and absf(_player.global_position.y - 24.0 * TILE) < 1.5,
			"she crosses the chasm on the floating rocks")


## The great face in the wall sleeps until she comes near, then watches.
func _check_entity() -> void:
	var entity: EldritchEntity = _nearest(EldritchEntity, Vector2(305.5 * TILE, 24.0 * TILE)) as EldritchEntity
	_expect(entity != null and not entity.is_awake(), "a great face sleeps in the undercroft wall")
	if entity == null:
		return
	await _place(Vector2(300.5 * TILE, 24.0 * TILE))
	_expect(entity.is_awake(), "it opens its eyes as she comes near")
	await _finish_dialogue()


## From the far side of the chasm, walking on reaches the end of the chapter.
func _check_undercroft_walk() -> void:
	await _place(Vector2(252.5 * TILE, 24.0 * TILE))
	await _walk_right_until(func() -> bool: return _chapter_completed, 1500)
	_expect(_chapter_completed, "the undercroft leads to the end of the chapter")


# --- Helpers ----------------------------------------------------------------------

func _lifts_in(left_tile: float, right_tile: float) -> Array[MovingPlatform]:
	var found: Array[MovingPlatform] = []
	for lift: MovingPlatform in _lift_home:
		var column: float = _lift_home[lift].x / TILE
		if column >= left_tile and column <= right_tile:
			found.append(lift)
	return found


func _at_bottom(lift: MovingPlatform) -> bool:
	return lift.position.distance_to(_lift_home[lift]) < 2.0


func _at_top(lift: MovingPlatform) -> bool:
	return lift.position.distance_to(_lift_home[lift] + lift.travel) < 2.0


## Waits for the lift to come back to where it starts, and to settle there.
func _wait_for_bottom(lift: MovingPlatform) -> void:
	await _until(func() -> bool: return _at_top(lift), 700)
	await _until(func() -> bool: return _at_bottom(lift), 700)
	await _frames(6)


## Holds a direction until she is at `x` (and stops), then waits to settle.
func _walk_to(x: float) -> void:
	Input.action_press("move_right")
	await _until(func() -> bool: return _player.global_position.x >= x, 200)
	Input.action_release("move_right")
	await _frames(12)


## Jumps the two-tile gap onto a lift that is resting at its lower end.
func _cross_to(lift: MovingPlatform, x: float) -> void:
	await _wait_for_bottom(lift)
	Input.action_press("move_right")
	await _frames(2)
	Input.action_press("jump")
	await _until(func() -> bool: return _player.global_position.x >= x, 60)
	Input.action_release("jump")
	Input.action_release("move_right")
	await _frames(10)


## Holds right until `condition`, reading through any thought that stops her.
func _walk_right_until(condition: Callable, limit: int) -> bool:
	for i: int in limit:
		if condition.call():
			break
		if _dialogue_open:
			Input.action_release("move_right")
			await _finish_dialogue()
		Input.action_press("move_right")
		await get_tree().physics_frame
	Input.action_release("move_right")
	return condition.call()


## A full jump that steers toward `column` (in tiles) and lands.
func _hop_to(column: float) -> void:
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
	print("  hop toward %.1f: now %s" % [column, _player.global_position / TILE])


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


func _nearest(type: Variant, to: Vector2) -> Node2D:
	var best: Node2D = null
	for child: Node in _entities.get_children():
		if is_instance_of(child, type):
			var node: Node2D = child as Node2D
			if best == null or node.global_position.distance_to(to) < best.global_position.distance_to(to):
				best = node
	return best


func _place(at: Vector2) -> void:
	_player.respawn(at)
	await _frames(80)


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

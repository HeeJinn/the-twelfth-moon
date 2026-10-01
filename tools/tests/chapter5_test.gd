extends Node
## Headless check of Chapter Five, the Twelfth Night, on the real map: what
## stands where and the story text, the lightning rods and Kael's embers (each
## warns first, then strikes), the climb from the stair to the summit with
## simulated input, and the whole fight with Kael: her guard stops his swings,
## two hits make him hop back, at half health he speaks and the fire begins,
## his embers land under her and beyond her so stepping toward him dodges them,
## a knock-out resets the fight, and beating him plays the reveal on his knee,
## the twenty-first petal, and the end of the chapter.
##
## Run from the project folder:
##   godot --headless --path . res://tools/tests/chapter5_test.tscn

const LEVEL_SCENE: PackedScene = preload("res://levels/level.tscn")
const ROD_SCENE: PackedScene = preload("res://entities/hazard/lightning_rod.tscn")
const EMBER_SCENE: PackedScene = preload("res://entities/hazard/ember_rain.tscn")
const TILE: float = 16.0

var _failures: int = 0
var _level: LevelLoader
var _player: Player
var _entities: Node2D
var _chapter_completed: bool = false
var _dialogue_open: bool = false
var _dialogues_seen: Array[String] = []


func _ready() -> void:
	GameManager.save_path = "user://test_save.cfg"
	EventBus.level_completed.connect(func() -> void: _chapter_completed = true)
	EventBus.dialogue_started.connect(func(id: String) -> void:
		_dialogue_open = true
		_dialogues_seen.append(id))
	EventBus.dialogue_finished.connect(func(_id: String) -> void: _dialogue_open = false)
	GameManager.current_level_index = 4
	_level = LEVEL_SCENE.instantiate() as LevelLoader
	add_child(_level)
	_entities = _level.get_node("%Entities") as Node2D
	await _frames(30)
	_player = _level.player
	_check_layout()
	_check_story_text()
	await _check_warned_hazard(ROD_SCENE, ["sparks gather on a rod first, and do no harm",
			"then lightning strikes it", "the strike hurts anyone beside the rod",
			"then it is quiet again"])
	await _check_warned_hazard(EMBER_SCENE, ["an ember's ring glows first, and does no harm",
			"then the ember bursts", "the burst hurts anyone in the ring", "then it is gone"])
	for child: Node in _entities.get_children():
		if child is FrostSpikes:
			child.queue_free()
	await _check_climb()
	await _check_fight()
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
		if child is Checkpoint:
			kind = "campfire"
		counts[kind] = counts.get(kind, 0) + 1
	print("  entities: ", counts)
	_expect(counts.get("campfire", 0) == 3 and counts.get("lightning_rod", 0) == 4,
			"three campfires and four lightning rods")
	_expect(counts.get("rooftop_arena", 0) == 1, "Kael waits on the summit")
	var petal: LastPetal = get_tree().get_first_node_in_group(&"last_petal") as LastPetal
	_expect(petal != null and not petal.is_released() and _level.collectibles_total == 1,
			"the last petal is counted, but hidden")
	_expect(GameManager.get_current_level().title == "Chapter Five", "it is Chapter Five")


func _check_story_text() -> void:
	var text: String = FileAccess.get_file_as_string("res://story/chapter_05.txt")
	var ids: Array[String] = []
	for line: String in text.split("\n"):
		if line.begins_with("[") and line.ends_with("]"):
			ids.append(line.trim_prefix("[").trim_suffix("]"))
	var thoughts: int = 0
	var all_found: bool = true
	for child: Node in _entities.get_children():
		if child.scene_file_path.contains("thought_"):
			thoughts += 1
			all_found = all_found and ids.has(str(child.get(&"dialogue_id")))
	_expect(thoughts == 3 and all_found, "all three thoughts have their lines")
	var scenes: bool = true
	for id: String in ["kael_intro", "kael_again", "kael_fire", "reveal", "reveal_after"]:
		scenes = scenes and ids.has(id)
	_expect(scenes, "the fight and the reveal have their lines")
	_expect(not _has_digit(_spoken_lines(text)), "the chapter's text has no numerals")


func _check_warned_hazard(scene: PackedScene, labels: Array[String]) -> void:
	await _place(Vector2(30.5 * TILE, 24.0 * TILE))
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
	var sprite_ref: WeakRef = weakref(sprite)
	var calm: bool = await _until(func() -> bool:
			var left: AnimatedSprite2D = sprite_ref.get_ref() as AnimatedSprite2D
			return left == null or not left.visible, 120)
	_expect(calm, labels[3])
	if is_instance_valid(hazard):
		hazard.queue_free()
	_player.heal_full()


## From the head of the stair to the summit: the battlements, the first tower,
## the gap and its ledge, the second tower, the ledge, the summit.
func _check_climb() -> void:
	await _place(Vector2(2.5 * TILE, 24.0 * TILE))
	await _walk_right_to(44.0)
	await _hop_to(47.0)
	_expect(_on_row(20.0), "a jump reaches the top of the first tower")
	await _walk_right_to(54.0)
	await _hop_to(56.0)
	_expect(_on_row(21.0), "then the ledge over the gap")
	await _hop_to(60.0)
	_expect(_on_row(18.0), "then the second tower")
	await _walk_right_to(68.0)
	await _hop_to(71.0)
	_expect(_on_row(15.0), "then the ledge below the summit")
	await _hop_to(76.0)
	_expect(_on_row(12.0), "then the summit")
	# The gap has a floor: dropping in is safe, and the ledge climbs back out.
	var back: Vector2 = _player.global_position
	await _place(Vector2(56.5 * TILE, 24.0 * TILE))
	_expect(_on_row(24.0) and not _player.is_dead(), "dropping into the gap is safe")
	await _hop_to(56.5)
	await _hop_to(60.0)
	_expect(_on_row(18.0), "and the ledge leads back out of it")
	await _place(back)
	await _walk_right_until(func() -> bool: return _dialogues_seen.has("kael_intro"), 1500)
	_expect(_dialogues_seen.has("kael_intro"), "walking on along the summit, Kael stops her")


func _check_fight() -> void:
	var arena: Cutscene = null
	for child: Node in _entities.get_children():
		if child is Cutscene and child.has_node("%Kael"):
			arena = child
	var kael: EmberKnight = arena.get_node("%Kael") as EmberKnight
	await _finish_dialogue()
	await _until(func() -> bool: return kael.collision_layer == 8, 300)
	_expect(kael.collision_layer == 8, "the fight begins after his words")
	_expect(arena.call(&"is_holding_view"), "the camera holds the whole summit")

	# He comes to her and swings; her guard stops it.
	var before: int = _player.health()
	_player.face(signf(kael.global_position.x - _player.global_position.x))
	Input.action_press("block")
	var swung: bool = await _until(func() -> bool: return kael.is_open(), 900)
	Input.action_release("block")
	_expect(swung and _player.health() == before, "her guard stops his sword")

	# Two hits while he's open, and he hops back.
	var health: int = kael.get(&"_health")
	var near: float = absf(kael.global_position.x - _player.global_position.x)
	kael.take_hit(1, _player.global_position)
	kael.take_hit(1, _player.global_position)
	_expect(kael.get(&"_health") == health - 2
			and kael.get(&"_phase") == EmberKnight.Phase.HOPPING, "two hits and he hops back")
	await _frames(60)
	_expect(absf(kael.global_position.x - _player.global_position.x) > near + 40.0,
			"out of her reach")

	# Down to half health: he stops and speaks, and the fire begins.
	await _strike_until(kael, func() -> bool: return _dialogues_seen.has("kael_fire"))
	_expect(_dialogues_seen.has("kael_fire"), "at half health he stops, and warns her about the fire")
	await _finish_dialogue()
	await _until(func() -> bool: return kael.is_fire_phase(), 60)

	# His embers: rings under her and beyond her; stepping toward him dodges them.
	var start_health: int = _player.health()
	var far_side: bool = true
	var under_her: bool = false
	var embers_seen: bool = false
	for i: int in 900:
		var fresh: Array[FrostSpikes] = []
		for child: Node in arena.get_children():
			if child is FrostSpikes:
				fresh.append(child as FrostSpikes)
		if not fresh.is_empty():
			embers_seen = true
			var away: float = signf(_player.global_position.x - kael.global_position.x)
			for ember: FrostSpikes in fresh:
				var offset: float = ember.global_position.x - _player.global_position.x
				if absf(offset) <= 1.0:
					under_her = true
				elif signf(offset) != away:
					far_side = false
			var toward: StringName = &"move_left" if away > 0.0 else &"move_right"
			Input.action_press(toward)
			await _frames(30)
			Input.action_release(toward)
			break
		await get_tree().physics_frame
	await _until(func() -> bool: return kael.is_open(), 300)
	_expect(embers_seen and under_her and far_side,
			"his embers fall under her and beyond her, never between them")
	_expect(_player.health() == start_health, "stepping toward him dodges the embers")

	# Knocked out: everything resets.
	_player.die()
	await _frames(200)
	_expect(kael.get(&"_health") == kael.max_health and not kael.is_fire_phase(),
			"a knock-out resets the fight")
	Input.action_press("move_right")
	await _until(func() -> bool: return _dialogue_open, 1500)
	Input.action_release("move_right")
	_expect(_dialogues_seen.has("kael_again"), "walking back in starts it again")
	await _finish_dialogue()

	# Beat him: strike whenever he's open (her sword's reach is tested elsewhere).
	await _strike_until(kael, func() -> bool: return _dialogues_seen.has("reveal"))
	_expect(kael.is_kneeling(), "beaten, he sinks to one knee beside his sword")
	_expect(_dialogues_seen.has("reveal"), "and the reveal begins there")
	for i: int in 4000:
		if _chapter_completed:
			break
		if _dialogue_open:
			await _finish_dialogue()
		else:
			await get_tree().physics_frame
	var sprite: AnimatedSprite2D = kael.get_node("%AnimatedSprite2D") as AnimatedSprite2D
	_expect(sprite.animation == &"fall", "then he falls")
	_expect(GameManager.collected_in_level == 1, "the last petal falls from him, and she takes it")
	_expect(_dialogues_seen.has("reveal_after") and _chapter_completed, "and the chapter ends")


## Hits him whenever he's open (reading through any words) until `condition`.
func _strike_until(kael: EmberKnight, condition: Callable) -> void:
	for i: int in 12000:
		if condition.call():
			return
		if _dialogue_open:
			await _finish_dialogue()
			continue
		if i % 10 == 0 and kael.is_open():
			kael.take_hit(1, _player.global_position)
		if i % 30 == 0 and _player.health() < 3:
			_player.heal_full()
		await get_tree().physics_frame


# --- Helpers ----------------------------------------------------------------------

func _on_row(row: float) -> bool:
	return absf(_player.global_position.y - row * TILE) < 1.5 and not _player.is_dead()


func _walk_right_to(column: float) -> void:
	await _walk_right_until(func() -> bool: return _player.global_position.x >= column * TILE, 600)
	await _frames(12)


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


func _place(at: Vector2) -> void:
	_player.respawn(at)
	await _frames(80)


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

extends Node
## Headless check of the sound effects (assets/audio/sfx/, from RPG Essentials):
## every effect the game names has its clip, and real events on the moves test
## course play them: a swing, a jump, a dash, being hurt, her guard stopping a
## blow, taking a petal, a hazard bursting nearby (and a far one staying
## quiet), a monster dying, a boss appearing, and pausing.
##
## Run from the project folder:
##   godot --headless --path . res://tools/tests/sfx_test.tscn

const LEVEL_SCENE: PackedScene = preload("res://levels/level.tscn")
const TEST_MAP: LevelData = preload("res://tools/tests/maps/moves_test.tres")
const PETAL_SCENE: PackedScene = preload("res://entities/collectible/petal.tscn")
const SPIKES_SCENE: PackedScene = preload("res://entities/hazard/frost_spikes.tscn")
const GOBLIN_SCENE: PackedScene = preload("res://entities/enemy/goblin.tscn")
const TILE: float = 16.0
const FLOOR_Y: float = 22.0 * TILE
const START: Vector2 = Vector2(3.5 * TILE, FLOOR_Y)

var _failures: int = 0
var _level: LevelLoader
var _player: Player


func _ready() -> void:
	GameManager.save_path = "user://test_save.cfg"
	var missing: Array[StringName] = []
	for name: StringName in Audio.EFFECT_DB:
		if not ResourceLoader.exists(Audio.SFX_PATH % name):
			missing.append(name)
	_expect(missing.is_empty(), "every effect the game names has its clip %s" % [missing])

	_level = LEVEL_SCENE.instantiate() as LevelLoader
	_level.level_data_override = TEST_MAP
	add_child(_level)
	await _frames(30)
	_player = _level.player
	await _place(START)
	Audio.reset()

	await _tap(&"attack")
	await _frames(20)
	_expect(Audio.play_count(&"sfx/swing") >= 1, "a swing whooshes")
	await _frames(40)
	await _tap(&"jump")
	await _frames(70)
	_expect(Audio.play_count(&"sfx/jump") >= 1, "a jump is heard")
	await _place(START)
	await _tap(&"dash")
	await _frames(30)
	_expect(Audio.play_count(&"sfx/dash") >= 1, "a dash rushes")

	await _place(START)
	await _frames(80)  # Past the respawn blink.
	_player.take_damage(1, _player.global_position + Vector2(-20.0, 0.0))
	await _frames(2)
	_expect(Audio.play_count(&"sfx/hurt") >= 1, "being hurt is heard")
	await _place(START)
	await _frames(80)
	_player.face(1.0)
	Input.action_press(&"block")
	await _frames(10)
	_player.take_damage(1, _player.global_position + Vector2(20.0, -10.0))
	await _frames(2)
	Input.action_release(&"block")
	_expect(Audio.play_count(&"sfx/block") >= 1, "her guard stopping a blow clangs")

	await _place(START)
	var petal: Collectible = PETAL_SCENE.instantiate() as Collectible
	petal.position = _player.position
	_level.get_node("%Entities").add_child(petal)
	await _frames(10)
	_expect(Audio.play_count(&"sfx/petal") == 1, "taking a petal chimes")

	var near: FrostSpikes = SPIKES_SCENE.instantiate() as FrostSpikes
	near.repeating = false
	near.position = _player.position + Vector2(40.0, 0.0)
	_level.get_node("%Entities").add_child(near)
	var far: FrostSpikes = SPIKES_SCENE.instantiate() as FrostSpikes
	far.repeating = false
	far.start_delay = 0.5
	far.position = _player.position + Vector2(900.0, 0.0)
	_level.get_node("%Entities").add_child(far)
	await _frames(150)
	_expect(Audio.play_count(&"sfx/ice") == 1, "a hazard bursting nearby is heard, a far one isn't")

	var goblin: Enemy = GOBLIN_SCENE.instantiate() as Enemy
	goblin.position = _player.position + Vector2(60.0, 0.0)
	_level.get_node("%Entities").add_child(goblin)
	await _frames(2)
	goblin.die()
	await _frames(2)
	_expect(Audio.play_count(&"sfx/enemy_death") == 1, "a monster's death is heard")

	EventBus.boss_started.emit("Test", 1)
	EventBus.boss_finished.emit()
	_expect(Audio.play_count(&"sfx/encounter") == 1, "a boss appearing sounds a warning")
	EventBus.pause_toggled.emit(true)
	EventBus.pause_toggled.emit(false)
	_expect(Audio.play_count(&"sfx/pause") == 1 and Audio.play_count(&"sfx/unpause") == 1,
			"pausing and going back are heard")

	if is_instance_valid(far):
		far.queue_free()
	for wait: int in 120:
		if not Audio.is_busy():
			break
		await get_tree().physics_frame
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(_failures)


func _place(at: Vector2) -> void:
	_player.respawn(at)
	await _frames(30)


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		print("FAIL ", label)

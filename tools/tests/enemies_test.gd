extends Node
## Headless check of the monsters' attacks on the moves test course: the
## goblin throws a bomb that lands and explodes, the mushroom bursts spores
## up close, and a sword hit interrupts an attack.
##
## Run from the project folder:
##   godot --headless --path . res://tools/tests/enemies_test.tscn

const LEVEL_SCENE: PackedScene = preload("res://levels/level.tscn")
const TEST_MAP: LevelData = preload("res://tools/tests/maps/moves_test.tres")
const MUSHROOM_SCENE: PackedScene = preload("res://entities/enemy/mushroom.tscn")
const TILE: float = 16.0
const FLOOR_Y: float = 22.0 * TILE

var _failures: int = 0
var _level: LevelLoader
var _player: Player
var _health: int = 0


func _ready() -> void:
	GameManager.save_path = "user://test_save.cfg"
	EventBus.player_health_changed.connect(func(current: int, _maximum: int) -> void:
		_health = current)
	_level = LEVEL_SCENE.instantiate() as LevelLoader
	_level.level_data_override = TEST_MAP
	add_child(_level)
	await _frames(20)
	_player = _level.player
	await _check_goblin_bomb()
	await _check_mushroom_burst()
	await _check_interrupt()
	# A cry cut off by quitting would be reported as a leak on exit.
	await _until(func() -> bool: return not Audio.is_busy(), 120)
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(_failures)


func _goblin() -> Enemy:
	for child: Node in _level.get_node("%Entities").get_children():
		if child is Enemy:
			return child
	return null


func _check_goblin_bomb() -> void:
	var goblin: Enemy = _goblin()
	_player.respawn(goblin.global_position + Vector2(-100.0, 0.0))
	await _frames(5)
	var start_health: int = _health
	var saw_bomb: bool = false
	for i: int in 180:
		for child: Node in _level.get_node("%Entities").get_children():
			if child is GoblinBomb:
				saw_bomb = true
		await get_tree().physics_frame
	_expect(saw_bomb, "the goblin throws a bomb when she's in range")
	_expect(_health < start_health, "a bomb that lands beside her explodes and hurts")


func _check_mushroom_burst() -> void:
	var mushroom: Enemy = MUSHROOM_SCENE.instantiate() as Enemy
	mushroom.position = Vector2(60.0 * TILE, FLOOR_Y)
	_level.get_node("%Entities").add_child(mushroom)
	_player.respawn(Vector2(58.5 * TILE, FLOOR_Y))
	await _frames(100)  # Past the respawn blink.
	_player.heal_full()
	var start_health: int = _health
	# Touching it doesn't hurt (it only pushes her), so wait for a burst: the
	# first may come while it has nudged her just out of its reach.
	for i: int in 300:
		if _health < start_health:
			break
		await get_tree().physics_frame
	_expect(_health < start_health, "the mushroom bursts spores when she's close")
	mushroom.queue_free()


func _check_interrupt() -> void:
	var goblin: Enemy = _goblin()
	_player.respawn(goblin.global_position + Vector2(-24.0, 0.0))
	_player.face(1.0)
	await _frames(100)
	var sprite: AnimatedSprite2D = goblin.get_node("%AnimatedSprite2D") as AnimatedSprite2D
	await _until(func() -> bool: return sprite.animation == &"attack", 240)
	_expect(sprite.animation == &"attack", "the goblin winds up an attack")
	goblin.take_hit(1, _player.global_position)
	await _frames(2)
	_expect(sprite.animation == &"walk", "a sword hit interrupts it")


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

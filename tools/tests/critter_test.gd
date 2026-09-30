extends Node
## Headless check that critters (sheep, frogs, the snake) obey gravity on the
## real maps: the sheep that used to hang in the air above Chapter One's dip
## now stands on its floor, a critter dropped in mid-air falls and lands, they
## stop at walls and at the edge of a drop (unless told they may fall), one
## that falls out of the world is removed, and Chapter Three's flock, frogs and
## snake all stay on the ground they were placed on.
##
## Run from the project folder:
##   godot --headless --path . res://tools/tests/critter_test.tscn

const LEVEL_SCENE: PackedScene = preload("res://levels/level.tscn")
const SHEEP_WHITE: PackedScene = preload("res://entities/critter/sheep_white.tscn")
const TILE: float = 32.0
## Chapter One: the village ground's top edge (row 9), the floor of the four
## tile wide dip after column 82 (row 10), and that dip's left and right walls.
const GROUND_Y: float = 9.0 * TILE
const DIP_FLOOR_Y: float = 10.0 * TILE
const DIP_LEFT_X: float = 83.0 * TILE
const DIP_RIGHT_X: float = 87.0 * TILE

var _failures: int = 0
var _level: LevelLoader
var _entities: Node2D


func _ready() -> void:
	GameManager.save_path = "user://test_save.cfg"
	await _load_chapter(0)
	await _check_chapter_one_sheep()
	await _check_dropped_sheep()
	await _check_ledge_and_wall()
	await _check_walking_off_when_allowed()
	await _check_out_of_world()
	await _load_chapter(2)
	await _check_road_critters()
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(_failures)


func _load_chapter(index: int) -> void:
	if _level != null:
		_level.queue_free()
		await _frames(3)
	GameManager.current_level_index = index
	_level = LEVEL_SCENE.instantiate() as LevelLoader
	add_child(_level)
	_entities = _level.get_node("%Entities") as Node2D


## The map's own sheep: two white (`<<`) and one black (`>`) stand in the wheat
## field, and one of the white ones was placed a tile above the dip.
func _check_chapter_one_sheep() -> void:
	var critters: Array[Critter] = _critters()
	var spawn_y: Dictionary[Critter, float] = {}
	for critter: Critter in critters:
		spawn_y[critter] = critter.position.y
	_expect(critters.size() == 3, "Chapter One has three sheep (found %d)" % critters.size())
	var pit_sheep: Critter = null
	for critter: Critter in critters:
		if critter.position.x > DIP_LEFT_X and critter.position.x < DIP_RIGHT_X:
			pit_sheep = critter
	_expect(pit_sheep != null and is_equal_approx(spawn_y[pit_sheep], GROUND_Y),
			"one sheep starts a tile above the dip, in mid-air")
	if pit_sheep == null:
		return
	await _frames(90)
	_expect(absf(pit_sheep.position.y - DIP_FLOOR_Y) < 1.0 and pit_sheep.is_on_floor(),
			"it falls into the dip and stands on its floor (y %.1f)" % pit_sheep.position.y)
	var on_ground: bool = true
	for critter: Critter in critters:
		if critter != pit_sheep and not (
				absf(critter.position.y - GROUND_Y) < 1.0 and critter.is_on_floor()):
			on_ground = false
	_expect(on_ground, "the other two stand on the village ground")

	# Fifteen seconds of wandering: the two on the ground never step off the
	# edge, and the one in the dip never walks into its walls.
	var lowest_on_ground: float = 0.0
	var pit_left: float = INF
	var pit_right: float = -INF
	for step: int in 30:
		await _frames(30)
		for critter: Critter in critters:
			if critter == pit_sheep:
				pit_left = minf(pit_left, critter.position.x)
				pit_right = maxf(pit_right, critter.position.x)
			else:
				lowest_on_ground = maxf(lowest_on_ground, critter.position.y)
	_expect(lowest_on_ground < GROUND_Y + 1.0, "sheep on the ground never wander off a ledge")
	_expect(pit_left > DIP_LEFT_X and pit_right < DIP_RIGHT_X,
			"the sheep in the dip stays between its walls (x %.0f to %.0f)" % [pit_left, pit_right])
	_expect(absf(pit_sheep.position.y - DIP_FLOOR_Y) < 1.0, "and stays on the dip's floor")


## A sheep placed high above flat ground falls and lands on it.
func _check_dropped_sheep() -> void:
	var sheep: Critter = _add_sheep(Vector2(1200.0, 100.0))
	await _frames(8)
	_expect(sheep.position.y > 100.0 and not sheep.is_on_floor(), "a sheep in mid-air falls")
	await _frames(120)
	_expect(absf(sheep.position.y - GROUND_Y) < 1.0 and sheep.is_on_floor(),
			"and lands on the ground (y %.1f)" % sheep.position.y)
	sheep.queue_free()


## A sheep that wants to wander far, standing a few px from the edge of the
## ground and beside the dip: it never goes over, and it does move about.
func _check_ledge_and_wall() -> void:
	var sheep: Critter = _add_sheep(Vector2(DIP_LEFT_X - 8.0, GROUND_Y))
	sheep.wander_distance = 200.0
	sheep.idle_time = Vector2(0.1, 0.3)
	sheep.rest_chance = 0.0
	var lowest: float = 0.0
	var left: float = INF
	var right: float = -INF
	for step: int in 30:
		await _frames(30)
		lowest = maxf(lowest, sheep.position.y)
		left = minf(left, sheep.position.x)
		right = maxf(right, sheep.position.x)
	_expect(lowest < GROUND_Y + 1.0, "it stops at the ledge instead of walking off")
	_expect(right - left > 12.0, "and still wanders about (x %.0f to %.0f)" % [left, right])
	sheep.queue_free()


## With `avoid_ledges` off it walks over the edge and drops into the dip.
func _check_walking_off_when_allowed() -> void:
	var sheep: Critter = _add_sheep(Vector2(DIP_LEFT_X - 8.0, GROUND_Y))
	sheep.avoid_ledges = false
	await _frames(4)
	sheep._move_toward(DIP_LEFT_X + 60.0, 1.0)
	await _frames(300)
	_expect(absf(sheep.position.y - DIP_FLOOR_Y) < 1.0 and sheep.is_on_floor(),
			"with avoid_ledges off it walks off the edge and lands in the dip (y %.1f)"
			% sheep.position.y)
	sheep.queue_free()


## Over a bottomless drop it falls until it is removed, so nothing simulates
## forever.
func _check_out_of_world() -> void:
	var sheep: Critter = _add_sheep(Vector2(1200.0, 1000.0))
	await _frames(300)
	_expect(not is_instance_valid(sheep), "a critter that falls out of the world is removed")


## Chapter Three's road: every critter stays on the ground it was placed on.
func _check_road_critters() -> void:
	var critters: Array[Critter] = _critters()
	var spawn_y: Dictionary[Critter, float] = {}
	for critter: Critter in critters:
		spawn_y[critter] = critter.position.y
	_expect(critters.size() == 7,
			"the road has four sheep, two frogs and a snake (found %d)" % critters.size())
	await _frames(60)
	var grounded: bool = true
	for critter: Critter in critters:
		if not (critter.is_on_floor() or critter.hops):
			grounded = false
			print("  not on the ground after settling: ", critter.name, " at ", critter.position)
	_expect(grounded, "every sheep and the snake stand on the ground")
	var lowest: Dictionary[Critter, float] = {}
	var highest: Dictionary[Critter, float] = {}
	var west: Dictionary[Critter, float] = {}
	var east: Dictionary[Critter, float] = {}
	for critter: Critter in critters:
		lowest[critter] = critter.position.y
		highest[critter] = critter.position.y
		west[critter] = critter.position.x
		east[critter] = critter.position.x
	for step: int in 40:
		await _frames(30)
		for critter: Critter in critters:
			if is_instance_valid(critter):
				lowest[critter] = maxf(lowest[critter], critter.position.y)
				highest[critter] = minf(highest[critter], critter.position.y)
				west[critter] = minf(west[critter], critter.position.x)
				east[critter] = maxf(east[critter], critter.position.x)
	var all_present: bool = true
	var no_fall: bool = true
	var no_float: bool = true
	for critter: Critter in critters:
		if not is_instance_valid(critter):
			all_present = false
			continue
		if lowest[critter] > spawn_y[critter] + 1.0:
			no_fall = false
			print("  fell: ", critter.name, " from ", spawn_y[critter], " to ", lowest[critter])
		if highest[critter] < spawn_y[critter] - critter.hop_height - 2.0:
			no_float = false
			print("  rose: ", critter.name, " ", spawn_y[critter], " -> ", highest[critter])
	var frog_hopped: bool = false
	for critter: Critter in critters:
		if critter.hops and is_instance_valid(critter) and east[critter] - west[critter] > 8.0:
			frog_hopped = true
	_expect(frog_hopped, "the frogs hop along the ground")
	_expect(all_present, "none of them fell out of the world in twenty seconds")
	_expect(no_fall, "none fell off the ground")
	_expect(no_float, "and only the frogs leave it, in hops")


func _critters() -> Array[Critter]:
	var found: Array[Critter] = []
	for child: Node in _entities.get_children():
		if child is Critter:
			found.append(child as Critter)
	return found


func _add_sheep(at: Vector2) -> Critter:
	var sheep: Critter = SHEEP_WHITE.instantiate() as Critter
	sheep.position = at
	_entities.add_child(sheep)
	return sheep


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		print("FAIL ", label)

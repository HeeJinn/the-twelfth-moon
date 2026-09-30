extends Node
## Headless check of every one of Mariane's moves on a small test course
## (tools/tests/maps/moves_test.txt): slide, crouch, ledge grab and climb,
## wall slide and wall jump, vine ladder, dash, air dash, dash attack, the
## three-slash combo, the air combo, the crouch slash, the Moon Slash and its
## wave, the Moon Spark, the guard, resting, getting up, sleeping and the
## calm stance.
##
## Run from the project folder:
##   godot --headless --path . res://tools/tests/moves_test.tscn

const LEVEL_SCENE: PackedScene = preload("res://levels/level.tscn")
const GOBLIN_SCENE: PackedScene = preload("res://entities/enemy/goblin.tscn")
const TEST_MAP: LevelData = preload("res://tools/tests/maps/moves_test.tres")
const TILE: float = 16.0
const FLOOR_Y: float = 22.0 * TILE

var _failures: int = 0
var _level: LevelLoader
var _player: Player


func _ready() -> void:
	GameManager.save_path = "user://test_save.cfg"
	_level = LEVEL_SCENE.instantiate() as LevelLoader
	_level.level_data_override = TEST_MAP
	add_child(_level)
	await _frames(20)
	_player = _level.player
	await _check_crouch()
	await _check_slide()
	await _check_ledge()
	await _check_wall_slide()
	await _check_ladder()
	await _check_dash()
	await _check_dash_attack()
	await _check_combo()
	await _check_air_combo()
	await _check_crouch_attack()
	await _check_moon_slash()
	await _check_moon_spark()
	await _check_guard()
	await _check_rest_and_wake()
	await _check_feedback_effects()
	# A sound cut off by quitting would be reported as a leak on exit.
	for wait: int in 120:
		if not Audio.is_busy():
			break
		await get_tree().physics_frame
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(_failures)


func _check_crouch() -> void:
	await _place(Vector2(6.5 * TILE, FLOOR_Y))
	Input.action_press("move_down")
	await _frames(10)
	_expect(_player.state_name() == &"Crouch", "holding down crouches")
	Input.action_release("move_down")
	await _frames(10)
	_expect(_player.state_name() == &"Idle", "letting go stands up")


func _check_slide() -> void:
	await _place(Vector2(3.5 * TILE, FLOOR_Y))
	Input.action_press("move_right")
	await _frames(25)
	Input.action_press("move_down")
	await _frames(3)
	_expect(_player.state_name() == &"Slide", "down while running slides")
	await _frames(60)
	Input.action_release("move_down")
	Input.action_release("move_right")
	await _frames(40)
	print("  after the tunnel: x=%.0f state=%s" % [_player.global_position.x, _player.state_name()])
	_expect(_player.global_position.x > 16.0 * TILE, "slides all the way through a one-tile tunnel")
	_expect(_player.state_name() == &"Idle", "stands up after the tunnel")


func _check_ledge() -> void:
	# The block's top is 80 px up: too tall to jump onto, but she can grab it.
	await _place(Vector2(22.5 * TILE, FLOOR_Y))
	Input.action_press("move_right")
	Input.action_press("jump")
	var grabbed: bool = await _until(func() -> bool: return _player.state_name() == &"LedgeHang", 90)
	Input.action_release("jump")
	Input.action_release("move_right")
	_expect(grabbed, "jumping at a tall ledge grabs it")
	var ledge_top: float = 17.0 * TILE
	print("  hanging with feet at y=%.1f (ledge top %.0f)" % [_player.global_position.y, ledge_top])
	_expect(absf(_player.global_position.y - (ledge_top + Player.HANG_HAND_HEIGHT)) < 1.0,
			"hangs with her hands on the ledge")
	await _frames(10)
	_expect(_player.state_name() == &"LedgeHang", "keeps hanging with no input")
	Input.action_press("move_up")
	await _frames(3)
	Input.action_release("move_up")
	await _until(func() -> bool: return _player.state_name() == &"Idle", 60)
	await _frames(5)
	print("  after climbing: %s" % _player.global_position)
	_expect(absf(_player.global_position.y - ledge_top) < 1.0 and _player.global_position.x > 24.0 * TILE,
			"up climbs onto the ledge")


func _check_wall_slide() -> void:
	# Drop her in the air beside the wall (no settling, or she lands first).
	_player.respawn(Vector2(33.0 * TILE, 9.0 * TILE))
	Input.action_press("move_right")
	var sliding: bool = await _until(func() -> bool: return _player.state_name() == &"WallSlide", 60)
	_expect(sliding, "pressing into a wall in the air slides down it")
	await _frames(20)
	print("  wall slide speed %.0f px/s" % _player.velocity.y)
	_expect(_player.velocity.y <= _player.stats.wall_slide_speed + 1.0, "slides down slowly")
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	Input.action_release("move_right")
	_expect(_player.state_name() == &"Jump" and _player.velocity.x < 0.0, "jump kicks off the wall")


func _check_ladder() -> void:
	await _place(Vector2(44.5 * TILE, FLOOR_Y))
	Input.action_press("move_up")
	await _frames(4)
	_expect(_player.state_name() == &"Climb", "up at a vine starts climbing")
	await _until(func() -> bool: return _player.state_name() != &"Climb", 240)
	Input.action_release("move_up")
	await _frames(10)
	var top: float = 12.0 * TILE
	print("  after climbing up: %s state=%s" % [_player.global_position, _player.state_name()])
	_expect(absf(_player.global_position.y - top) < 1.5 and _player.is_on_floor(),
			"stands on the plank at the top of the vine")
	Input.action_press("move_down")
	await _frames(4)
	_expect(_player.state_name() == &"Climb", "down on the plank climbs back down")
	await _until(func() -> bool: return _player.state_name() != &"Climb", 240)
	Input.action_release("move_down")
	await _frames(10)
	print("  after climbing down: %s state=%s" % [_player.global_position, _player.state_name()])
	_expect(absf(_player.global_position.y - FLOOR_Y) < 1.5, "climbs down to the ground")


func _check_dash() -> void:
	await _place(Vector2(48.5 * TILE, FLOOR_Y))
	_player.face(1.0)
	var start_x: float = _player.global_position.x
	await _tap("dash")
	_expect(_player.state_name() == &"Dash", "dash starts")
	await _frames(12)
	print("  dash moved %.0f px" % (_player.global_position.x - start_x))
	_expect(_player.global_position.x - start_x > 45.0, "dash bursts forward")
	await _frames(30)
	Input.action_press("jump")
	await _frames(8)
	await _tap("dash")
	_expect(_player.state_name() == &"Dash", "one dash in the air")
	await _frames(14)
	await _tap("dash")
	_expect(_player.state_name() != &"Dash", "no second dash before landing")
	Input.action_release("jump")
	await _frames(60)


func _check_dash_attack() -> void:
	var goblin: Enemy = null
	for child: Node in _level.get_node("%Entities").get_children():
		if child is Enemy:
			goblin = child
	goblin.set_physics_process(false)
	await _place(goblin.global_position + Vector2(-60.0, 0.0))
	_player.face(1.0)
	await _tap("dash")
	print("  after dash tap: ", _player.state_name())
	await _frames(2)
	await _tap("attack")
	print("  after attack tap: ", _player.state_name())
	await _frames(3)
	_expect(_player.state_name() == &"DashAttack", "attack during a dash lunges")
	await _frames(40)
	_expect(not is_instance_valid(goblin), "the lunge defeats a goblin in one hit")


func _check_combo() -> void:
	await _place(Vector2(52.5 * TILE, FLOOR_Y))
	_player.face(1.0)
	var dummy: Enemy = _spawn_dummy(_player.global_position + Vector2(24.0, 0.0))
	var swings: Array[StringName] = []
	for i: int in 3:
		await _tap("attack")
		for frame: int in 14:
			if not swings.has(_player.sprite.animation):
				swings.append(_player.sprite.animation)
			await get_tree().physics_frame
	await _until(func() -> bool: return _player.state_name() == &"Idle", 60)
	print("  swings: %s, dummy health %d" % [swings, _health_of(dummy)])
	_expect(swings.has(&"attack_2") and swings.has(&"attack_3"),
			"attack three times chains three slashes")
	_expect(_health_of(dummy) == 10 - 4, "the combo hits for one, one, then two")
	dummy.queue_free()


func _check_air_combo() -> void:
	await _place(Vector2(52.5 * TILE, FLOOR_Y))
	Input.action_press("jump")
	await _frames(6)
	await _tap("attack")
	_expect(_player.sprite.animation == &"air_attack", "attack in the air swings JumpAttack1")
	await _frames(8)
	await _tap("attack")
	await _until(func() -> bool: return _player.sprite.animation == &"air_attack_2", 20)
	_expect(_player.sprite.animation == &"air_attack_2", "a second press follows with JumpAttack2")
	Input.action_release("jump")
	await _frames(60)


func _check_crouch_attack() -> void:
	await _place(Vector2(52.5 * TILE, FLOOR_Y))
	_player.face(1.0)
	var dummy: Enemy = _spawn_dummy(_player.global_position + Vector2(20.0, 0.0))
	Input.action_press("move_down")
	await _frames(8)
	await _tap("attack")
	_expect(_player.state_name() == &"CrouchAttack", "attack while crouching slashes low")
	await _until(func() -> bool: return _player.state_name() == &"Crouch", 60)
	_expect(_player.state_name() == &"Crouch", "stays down after a low slash")
	_expect(_health_of(dummy) == 9, "the low slash hits")
	Input.action_release("move_down")
	await _frames(20)
	dummy.queue_free()


func _check_moon_slash() -> void:
	await _place(Vector2(52.5 * TILE, FLOOR_Y))
	_player.face(1.0)
	var near: Enemy = _spawn_dummy(_player.global_position + Vector2(20.0, 0.0))
	var far: Enemy = _spawn_dummy(_player.global_position + Vector2(110.0, 0.0))
	Input.action_press("attack")
	var charging: bool = await _until(func() -> bool: return _player.state_name() == &"Charge", 60)
	_expect(charging, "holding attack after a swing charges")
	await _frames(40)
	Input.action_release("attack")
	await _frames(2)
	_expect(_player.state_name() == &"MoonSlash", "letting go when charged swings a Moon Slash")
	await _frames(60)
	print("  near health %d, far health %d" % [_health_of(near), _health_of(far)])
	_expect(_health_of(near) <= 10 - 1 - 3, "the Moon Slash hits hard up close")
	_expect(_health_of(far) == 10 - 2, "its wave of light hits further along")
	# Letting go too early just lowers the sword.
	Input.action_press("attack")
	await _until(func() -> bool: return _player.state_name() == &"Charge", 60)
	await _frames(5)
	Input.action_release("attack")
	await _frames(3)
	_expect(_player.state_name() == &"Idle", "letting go early doesn't slash")
	near.queue_free()
	far.queue_free()


func _check_moon_spark() -> void:
	await _place(Vector2(52.5 * TILE, FLOOR_Y))
	_player.face(1.0)
	_player.refill_moonlight()
	var target: Enemy = _spawn_dummy(_player.global_position + Vector2(130.0, 0.0))
	await _tap("spell")
	_expect(_player.state_name() == &"Cast", "the spell button casts")
	await _frames(70)
	_expect(_player.moonlight() == _player.stats.max_moonlight - 1, "a Moon Spark spends one moon")
	_expect(_health_of(target) == 10 - 2, "the spark flies and hits")
	while _player.spend_moonlight():
		pass
	await _tap("spell")
	_expect(_player.state_name() != &"Cast", "no spark without moonlight")
	target.queue_free()


func _check_guard() -> void:
	await _place(Vector2(52.5 * TILE, FLOOR_Y))
	_player.face(1.0)
	Input.action_press("block")
	await _frames(6)
	_expect(_player.state_name() == &"Guard", "holding block raises her guard")
	var before: int = _player.health()
	_player.take_damage(1, _player.global_position + Vector2(20.0, -10.0))
	await _frames(2)
	_expect(_player.health() == before and _player.sprite.animation == &"block",
			"a blow from the front is blocked")
	await _frames(20)
	_player.take_damage(1, _player.global_position + Vector2(-20.0, -10.0))
	_expect(_player.health() == before - 1, "a blow from behind still hurts")
	Input.action_release("block")
	await _frames(40)


func _check_rest_and_wake() -> void:
	await _place(Vector2(52.5 * TILE, FLOOR_Y))
	_player.spend_moonlight()
	_player.rest()
	await _frames(2)
	_expect(_player.state_name() == &"Rest", "lighting a campfire makes her rest")
	_expect(_player.moonlight() == _player.stats.max_moonlight, "resting refills the moons")
	_expect(_effect_playing("heal_gold_frames"), "gold sparkles gather round her as she warms herself")
	var moon_glow: bool = await _until(
			func() -> bool: return _effect_playing("heal_moon_frames"), 120)
	_expect(moon_glow, "then silver-blue ones as she gathers moonlight")
	var rested: bool = await _until(func() -> bool: return _player.state_name() == &"Idle", 150)
	_expect(rested, "she's done resting after a moment")
	_player.respawn(_player.global_position, true)
	await _frames(2)
	_expect(_player.state_name() == &"GetUp", "after a fall she gets back up at the campfire")
	await _until(func() -> bool: return _player.state_name() == &"Idle", 90)
	_player.fall_asleep()
	await _frames(30)
	_expect(_player.state_name() == &"Asleep", "a chapter can start with her asleep")
	EventBus.dialogue_started.emit("test")
	EventBus.dialogue_finished.emit("test")
	await _frames(2)
	_expect(_player.state_name() == &"GetUp", "she gets up when the conversation ends")
	await _until(func() -> bool: return _player.state_name() == &"Idle", 90)
	await _frames(roundi(_player.stats.calm_delay * 60.0) + 10)
	_expect(_player.sprite.animation == &"idle_calm", "standing still a while, she relaxes")


## The little effects that make her moves feel real: a spark where her sword
## lands, dust when she lands from a real drop (and none from a hop).
func _check_feedback_effects() -> void:
	await _place(Vector2(52.5 * TILE, FLOOR_Y))
	_player.face(1.0)
	var dummy: Enemy = _spawn_dummy(_player.global_position + Vector2(24.0, 0.0))
	var saw_spark: bool = false
	await _tap("attack")
	for i: int in 30:
		saw_spark = saw_spark or _effect_playing("hit_spark_frames")
		await get_tree().physics_frame
	_expect(saw_spark, "a spark flashes where her sword lands")
	dummy.queue_free()
	await _frames(60)

	var saw_dust: bool = false
	_player.respawn(Vector2(52.5 * TILE, FLOOR_Y - 150.0))
	for i: int in 90:
		saw_dust = saw_dust or _effect_playing("landing_dust_frames")
		await get_tree().physics_frame
	_expect(saw_dust, "dust puffs up when she lands from a real drop")

	await _place(Vector2(52.5 * TILE, FLOOR_Y))
	var hopped_dust: bool = false
	Input.action_press("jump")
	await _frames(4)
	Input.action_release("jump")
	for i: int in 60:
		hopped_dust = hopped_dust or _effect_playing("landing_dust_frames")
		await get_tree().physics_frame
	_expect(not hopped_dust, "but not from a little hop")


func _effect_playing(frames_name: String) -> bool:
	for child: Node in _level.get_node("%Entities").get_children():
		var effect: AnimatedSprite2D = child as AnimatedSprite2D
		if effect != null and effect.sprite_frames != null 				and effect.sprite_frames.resource_path.ends_with(frames_name + ".tres"):
			return true
	return false


## A goblin that stands still and has ten health, for counting hits.
func _spawn_dummy(at: Vector2) -> Enemy:
	var dummy: Enemy = GOBLIN_SCENE.instantiate() as Enemy
	dummy.max_health = 10
	dummy.attack_reach = Vector2.ZERO
	_level.get_node("%Entities").add_child(dummy)
	dummy.global_position = at
	dummy.set_physics_process(false)
	return dummy


func _health_of(enemy: Enemy) -> int:
	return enemy.get(&"_health") if is_instance_valid(enemy) else 0


func _place(at: Vector2) -> void:
	_player.respawn(at)
	await _frames(80)  # Past the respawn blink.


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

extends Cutscene
## Chapter One ending: the Ember Knight takes the moon shard from the village
## shrine and sets it alight. He knows Mariane's name. Grandpa Tomas hurries
## over, explains the legend, and she sets out. Ends the chapter.
##
## Scene: ShrineCutscene (Area2D, origin at the shrine's feet)
##   CollisionShape2D  trigger, a few tiles left of the shrine
##   %Camera2D         disabled until the scene starts
##   %Shrine           Sprite2D (angel statue)
##   %Shard            Node2D above the statue: crystal, glow, sparkles
##   %Kael             AnimatedSprite2D, hidden, right of the shrine
##   %Tomas            AnimatedSprite2D, hidden, arrives at the end

const FIRE_BURST: SpriteFrames = preload("res://entities/effects/fire_burst_frames.tres")
const FIRE_PUFF: SpriteFrames = preload("res://entities/effects/fire_puff_frames.tres")
const MOON_ABSORB: SpriteFrames = preload("res://entities/effects/moon_absorb_frames.tres")
const SHARD_BURST: SpriteFrames = preload("res://entities/effects/shard_burst_frames.tres")
const FLAMES: SpriteFrames = preload("res://entities/checkpoint/campfire_frames.tres")
## Where Mariane stops walking, relative to the shrine.
const STAND_OFFSET_X: float = -150.0
## Seconds into Kael's special attack when the sword hits the ground.
const SLAM_TIME: float = 0.85
const CHARRED: Color = Color(0.32, 0.27, 0.3)

var _shard_bob: Tween

@onready var _shrine: Sprite2D = %Shrine
@onready var _shard: Node2D = %Shard
@onready var _kael: AnimatedSprite2D = %Kael
@onready var _tomas: AnimatedSprite2D = %Tomas


func _ready() -> void:
	super()
	_kael.hide()
	_tomas.hide()
	_shard_bob = create_tween().set_loops()
	_shard_bob.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_shard_bob.tween_property(_shard, "position:y", _shard.position.y - 3.0, 1.0)
	_shard_bob.tween_property(_shard, "position:y", _shard.position.y, 1.0)


func _play() -> void:
	await player.walk_to(global_position.x + STAND_OFFSET_X)
	player.face(1.0)
	await say("shrine_arrive")

	take_camera()
	await pan_camera(global_position + Vector2(24.0, -64.0), 1.2)
	await wait(0.4)

	# The Ember Knight steps out of a burst of fire.
	shake(3.0, 0.5)
	play_effect(FIRE_BURST, _kael.global_position + Vector2(0.0, -30.0))
	await wait(0.25)
	_kael.show()
	_kael.play("idle")
	Audio.voice(&"mariane", &"gasp")
	await wait(1.2)

	# He draws the moon shard into his hand; its light swirls in with it.
	var hand: Vector2 = _kael.global_position + Vector2(-12.0, -30.0)
	play_effect(MOON_ABSORB, hand)
	_shard_bob.kill()
	var pull: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pull.tween_property(_shard, "global_position", hand, 0.9)
	await pull.finished
	play_effect(SHARD_BURST, hand)
	_shard.hide()
	await wait(0.6)

	# ...then brings his sword down on the shrine.
	_kael.play("special")
	Audio.voice(&"ian", &"shout")
	await wait(SLAM_TIME)
	shake(5.0, 0.7)
	play_effect(FIRE_BURST, global_position + Vector2(0.0, -28.0))
	for x: float in [-18.0, 2.0, 18.0]:
		play_effect(FIRE_PUFF, global_position + Vector2(x, -12.0))
	var burn: Tween = create_tween()
	burn.tween_property(_shrine, "modulate", CHARRED, 0.6)
	_light_fires()
	await _kael.animation_finished
	_kael.play("idle")
	await wait(0.8)

	var between: Vector2 = (player.global_position + _kael.global_position) / 2.0
	await pan_camera(between + Vector2(0.0, -40.0), 1.0)
	await say("shrine_kael")
	await wait(1.4)  # He looks at her a moment too long.
	play_effect(FIRE_BURST, _kael.global_position + Vector2(0.0, -30.0))
	await wait(0.2)
	_kael.hide()
	await wait(1.2)
	await return_camera()

	# Grandpa Tomas hurries over from the village.
	_tomas.global_position = player.global_position + Vector2(-260.0, 0.0)
	_tomas.flip_h = true  # Villager art faces left; he runs right.
	_tomas.show()
	_tomas.play("run")
	var run: Tween = create_tween()
	run.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	run.tween_property(_tomas, "global_position:x", player.global_position.x - 36.0, 2.2)
	await run.finished
	_tomas.play("idle")
	player.face(-1.0)
	await say("shrine_after")
	await wait(0.5)
	EventBus.level_completed.emit()


## Small fires left burning around the charred shrine.
func _light_fires() -> void:
	for x: float in [-26.0, 20.0]:
		var fire: AnimatedSprite2D = AnimatedSprite2D.new()
		fire.sprite_frames = FLAMES
		fire.offset = Vector2(0.0, -16.0)
		fire.position = Vector2(x, 2.0)
		fire.z_index = 1
		add_child(fire)
		fire.play("burn")

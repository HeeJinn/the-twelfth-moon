extends Node2D
## After the credits: spring, on the hill above the village, where a flowering
## tree has grown from his sword. Mariane walks up to it. A young man with a
## familiar face (the one from her memories) walks up too: "Sorry... have we
## met before?" She smiles, and the screen fades to "In every life." Then the
## end screen. Esc (pause) skips to it.
##
## Scene: AfterCredits (Node2D, fixed camera)
##   Camera2D, Sky, Sun, Clouds, Hills, Wood, %Ground (TileMapLayer)
##   FloweringTree, grass, butterflies, PetalWind (CPUParticles2D)
##   %Hero (Mariane), %Stranger (AnimatedSprite2D, the past-life young man)
##   FlashLayer > %Flash (ColorRect, black at the start)
##   CardLayer > %LastCard (Label "In every life.")
##   DialogueBox (story/ending.txt), HintLayer > %SkipLabel

const GROUND_ROWS: Array[int] = [7, 8, 9]
const GROUND_COLUMNS: Vector2i = Vector2i(-1, 16)
## Walking speed for both of them (px/s), and where each stops by the tree.
const WALK_SPEED: float = 38.0
const HERO_STOP_X: float = 206.0
const STRANGER_STOP_X: float = 270.0

var _is_leaving: bool = false

@onready var _ground: TileMapLayer = %Ground
@onready var _hero: AnimatedSprite2D = %Hero
@onready var _stranger: AnimatedSprite2D = %Stranger
@onready var _flash: ColorRect = %Flash
@onready var _last_card: Label = %LastCard
@onready var _skip_label: Label = %SkipLabel


func _ready() -> void:
	Music.play(&"after_credits", 2.0)
	_paint_ground()
	_stranger.hide()
	var hint: Tween = create_tween()
	hint.tween_interval(4.0)
	hint.tween_property(_skip_label, "modulate:a", 0.0, 1.0)
	_play()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_leave()


func _play() -> void:
	await _wait(1.0)
	await _say("after_spring")
	_fade_flash(0.0, 2.5)
	await _walk(_hero, HERO_STOP_X)
	_hero.play(&"idle_calm")
	await _wait(2.5)
	if _is_leaving:
		return
	_stranger.show()
	await _walk(_stranger, STRANGER_STOP_X)
	_stranger.play(&"idle")
	await _wait(1.2)
	_hero.play(&"idle")
	await _wait(0.6)
	await _say("after_meeting")
	_hero.play(&"idle_calm")
	await _wait(2.0)
	await _fade_flash(1.0, 2.5)
	await _wait(0.8)
	if _is_leaving:
		return
	var card: Tween = create_tween()
	card.tween_property(_last_card, "modulate:a", 1.0, 2.0)
	card.tween_interval(4.5)
	card.tween_property(_last_card, "modulate:a", 0.0, 1.5)
	await card.finished
	await _wait(0.8)
	_leave()


func _paint_ground() -> void:
	var cells: Array[Vector2i] = []
	for row: int in GROUND_ROWS:
		for column: int in range(GROUND_COLUMNS.x, GROUND_COLUMNS.y + 1):
			cells.append(Vector2i(column, row))
	_ground.set_cells_terrain_connect(cells, 0, 0)


func _walk(sprite: AnimatedSprite2D, to_x: float) -> void:
	if _is_leaving:
		return
	sprite.play(&"walk")
	var seconds: float = absf(to_x - sprite.position.x) / WALK_SPEED
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "position:x", to_x, seconds)
	await tween.finished


func _say(dialogue_id: String) -> void:
	if _is_leaving:
		return
	EventBus.dialogue_requested.emit(dialogue_id)
	await EventBus.dialogue_finished


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _fade_flash(alpha: float, seconds: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_flash, "color:a", alpha, seconds)
	await tween.finished


func _leave() -> void:
	if _is_leaving:
		return
	_is_leaving = true
	GameManager.finish_story()

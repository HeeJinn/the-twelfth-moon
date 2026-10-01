extends Node2D
## The prologue, a memory from a thousand years ago: two lovers under the
## flowering tree as the red moon rises. It takes her; he swears to find her
## again. Then Grandpa Tomas's voice wakes Mariane, and Chapter One begins.
## Esc (pause) skips it.
##
## Scene: Prologue (Node2D, fixed camera)
##   Sky, %Ground (TileMapLayer)
##   MoonLayer (CanvasLayer above the tint, so only the moon keeps its red)
##     %RedMoon (Node2D > %MoonGlow, Moon)
##   FloweringTree, %Her, %Him (AnimatedSprite2D), Fireflies
##   MemoryTint (CanvasLayer > ColorRect with memory_tint.gdshader)
##   FlashLayer (CanvasLayer > %Flash ColorRect)
##   DialogueBox (reads prologue.txt), HintLayer > %SkipLabel

## Map rows (32 px cells) painted as ground, and the columns they span.
const GROUND_ROWS: Array[int] = [7, 8]
const GROUND_COLUMNS: Vector2i = Vector2i(-1, 16)

var _is_leaving: bool = false

@onready var _ground: TileMapLayer = %Ground
@onready var _moon_glow: Sprite2D = %MoonGlow
@onready var _her: AnimatedSprite2D = %Her
@onready var _him: AnimatedSprite2D = %Him
@onready var _flash: ColorRect = %Flash
@onready var _skip_label: Label = %SkipLabel


func _ready() -> void:
	Music.play(&"memory")
	_paint_ground()
	_her.play("idle")
	_him.play("idle")
	var hint: Tween = create_tween()
	hint.tween_interval(4.0)
	hint.tween_property(_skip_label, "modulate:a", 0.0, 1.0)
	_play()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_leave()


func _play() -> void:
	await _wait(1.2)
	await _say("prologue_opening")
	await _wait(0.6)
	await _say("prologue_1")

	# The moon's glow swells until it fills the sky.
	var swell: Tween = create_tween().set_parallel()
	swell.tween_property(_moon_glow, "scale", Vector2(3.0, 3.0), 3.0)
	swell.tween_property(_moon_glow, "modulate:a", 1.0, 3.0)
	await swell.finished
	await _flash_to(Color(1.0, 0.2, 0.25, 0.85), 0.15)
	_her.play("death")
	await _flash_to(Color(1.0, 0.2, 0.25, 0.0), 1.0)
	await _wait(1.6)
	await _say("prologue_2")

	await _flash_to(Color(1.0, 1.0, 1.0, 1.0), 1.4)
	await _wait(0.6)
	await _flash_to(Color(0.0, 0.0, 0.0, 1.0), 1.0)
	await _say("prologue_wake")
	_leave()


func _paint_ground() -> void:
	var cells: Array[Vector2i] = []
	for row: int in GROUND_ROWS:
		for column: int in range(GROUND_COLUMNS.x, GROUND_COLUMNS.y + 1):
			cells.append(Vector2i(column, row))
	# One extra hidden row below so the bottom row tiles as solid fill.
	for column: int in range(GROUND_COLUMNS.x, GROUND_COLUMNS.y + 1):
		cells.append(Vector2i(column, GROUND_ROWS[-1] + 1))
	_ground.set_cells_terrain_connect(cells, 0, 0)


func _say(dialogue_id: String) -> void:
	if _is_leaving:
		return
	EventBus.dialogue_requested.emit(dialogue_id)
	await EventBus.dialogue_finished


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _flash_to(color: Color, seconds: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_flash, "color", color, seconds)
	await tween.finished


func _leave() -> void:
	if _is_leaving:
		return
	_is_leaving = true
	GameManager.go_to_level(0)

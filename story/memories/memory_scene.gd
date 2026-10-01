extends Node2D
## A past-life memory played between chapters, in the faded "memory" look.
## Plays `conversations` in order, fades to black, plays `wake_conversation`
## (Mariane coming back to herself), then hands back to GameManager.
## Esc (pause) skips it. Reusable: build a scene per memory.
##
## Scene: MemoryScene (Node2D, fixed camera)
##   Camera2D, Sky, %Ground (TileMapLayer), props and people
##   MemoryTint (CanvasLayer > ColorRect with memory_tint.gdshader)
##   FlashLayer (CanvasLayer > %Flash ColorRect)
##   DialogueBox (script_path = this memory's .txt), HintLayer > %SkipLabel

## Map rows (32 px cells) painted as ground, and the columns they span.
const GROUND_ROWS: Array[int] = [7, 8]
const GROUND_COLUMNS: Vector2i = Vector2i(-1, 16)

@export var conversations: PackedStringArray = []
@export var wake_conversation: String = ""
## Village tileset terrain for the ground: 0 grass, 1 autumn, 2 snow.
@export var ground_terrain: int = 0

var _is_leaving: bool = false

@onready var _ground: TileMapLayer = %Ground
@onready var _flash: ColorRect = %Flash
@onready var _skip_label: Label = %SkipLabel


func _ready() -> void:
	Music.play(&"memory")
	_paint_ground()
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
	for dialogue_id: String in conversations:
		await _say(dialogue_id)
		await _wait(0.5)
	var tween: Tween = create_tween()
	tween.tween_property(_flash, "color", Color.BLACK, 1.4)
	await tween.finished
	if not wake_conversation.is_empty():
		await _say(wake_conversation)
	_leave()


func _paint_ground() -> void:
	var cells: Array[Vector2i] = []
	for row: int in GROUND_ROWS + [GROUND_ROWS[-1] + 1]:
		for column: int in range(GROUND_COLUMNS.x, GROUND_COLUMNS.y + 1):
			cells.append(Vector2i(column, row))
	_ground.set_cells_terrain_connect(cells, 0, ground_terrain)


func _say(dialogue_id: String) -> void:
	if _is_leaving:
		return
	EventBus.dialogue_requested.emit(dialogue_id)
	await EventBus.dialogue_finished


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _leave() -> void:
	if _is_leaving:
		return
	_is_leaving = true
	GameManager.finish_outro()

extends CanvasLayer
## In-chapter HUD. Only listens to EventBus; it never polls or holds game state.
## Shows hearts for health, moons for moonlight (Moon Spark charges), one
## petal icon per petal in the chapter, the chapter intro card, and the
## pause label. No digits: the Pixelmax font has none, so counts are drawn
## as icons.
##
## Scene: HUD (CanvasLayer)
##   MarginContainer (full rect) > HBoxContainer
##     VBoxContainer > %Hearts, %Moons (HBoxContainers)   filled at runtime
##     spacer
##     %Petals (HBoxContainer)   filled at runtime
##   %IntroCard (VBoxContainer, centred)
##     %TitleLabel, %SubtitleLabel, %NightLabel
##   %PauseDim (ColorRect over the screen), %PauseLabel and %PauseControls
##   (Labels, centred): shown only while paused
##   %BossBar (VBoxContainer, top centre, hidden) > %BossName, %BossHealth

const HEART_FULL: Texture2D = preload("res://assets/generated/heart_full.png")
const HEART_EMPTY: Texture2D = preload("res://assets/generated/heart_empty.png")
const MOON_FULL: Texture2D = preload("res://assets/generated/moon_full.png")
const MOON_EMPTY: Texture2D = preload("res://assets/generated/moon_empty.png")
const PETAL: Texture2D = preload("res://assets/generated/petal.png")
const PETAL_MISSING_COLOR: Color = Color(0.25, 0.25, 0.35, 0.6)
## Hearts (9x8) and moons (7x7) are tiny, so they are drawn at a whole-number 2x scale.
const HEART_SCALE: float = 2.0
## Seconds the chapter card stays fully visible.
const INTRO_HOLD: float = 2.5
const INTRO_FADE: float = 0.8

## The pause screen's list on a touch screen, where the keys are buttons.
const TOUCH_CONTROLS: String = (
	"The arrows on the left walk, climb and crouch\n"
	+ "The button on the far right jumps\n"
	+ "The sword swings. Hold it for a Moon Slash\n"
	+ "Hold the shield to guard. The moon throws a spark\n"
	+ "The double arrow dashes. The bubble talks\n"
	+ "Tap pause again to go back to the game"
)

@onready var _hearts: HBoxContainer = %Hearts
@onready var _moons: HBoxContainer = %Moons
@onready var _petals: HBoxContainer = %Petals
@onready var _intro_card: VBoxContainer = %IntroCard
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _night_label: Label = %NightLabel
@onready var _pause_label: Label = %PauseLabel
@onready var _pause_dim: ColorRect = %PauseDim
@onready var _pause_controls: Label = %PauseControls
@onready var _boss_bar: VBoxContainer = %BossBar
@onready var _boss_name: Label = %BossName
@onready var _boss_health: TextureProgressBar = %BossHealth


func _ready() -> void:
	EventBus.level_started.connect(_on_level_started)
	EventBus.collectibles_changed.connect(_on_collectibles_changed)
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.player_moonlight_changed.connect(_on_player_moonlight_changed)
	EventBus.pause_toggled.connect(_on_pause_toggled)
	EventBus.boss_started.connect(_on_boss_started)
	EventBus.boss_health_changed.connect(_on_boss_health_changed)
	EventBus.boss_finished.connect(_boss_bar.hide)
	if TouchControls.is_touch():
		_pause_controls.text = TOUCH_CONTROLS
	_on_pause_toggled(false)
	_boss_bar.hide()
	_intro_card.modulate.a = 0.0


func _on_level_started(level_data: LevelData, _collectibles_total: int) -> void:
	_title_label.text = level_data.title
	_subtitle_label.text = level_data.subtitle
	_night_label.text = level_data.night_text
	var tween: Tween = create_tween()
	tween.tween_property(_intro_card, "modulate:a", 1.0, INTRO_FADE)
	tween.tween_interval(INTRO_HOLD)
	tween.tween_property(_intro_card, "modulate:a", 0.0, INTRO_FADE)


func _on_collectibles_changed(collected: int, total: int) -> void:
	_fill_icons(_petals, total)
	for i: int in total:
		var icon: TextureRect = _petals.get_child(i) as TextureRect
		icon.texture = PETAL
		icon.custom_minimum_size = PETAL.get_size()
		icon.modulate = Color.WHITE if i < collected else PETAL_MISSING_COLOR


func _on_player_health_changed(current: int, maximum: int) -> void:
	_fill_icons(_hearts, maximum)
	for i: int in maximum:
		var icon: TextureRect = _hearts.get_child(i) as TextureRect
		icon.texture = HEART_FULL if i < current else HEART_EMPTY
		icon.custom_minimum_size = HEART_FULL.get_size() * HEART_SCALE


func _on_player_moonlight_changed(current: int, maximum: int) -> void:
	_fill_icons(_moons, maximum)
	for i: int in maximum:
		var icon: TextureRect = _moons.get_child(i) as TextureRect
		icon.texture = MOON_FULL if i < current else MOON_EMPTY
		icon.custom_minimum_size = MOON_FULL.get_size() * HEART_SCALE


## Paused: the screen dims and the controls are listed, for whoever forgot a key.
func _on_pause_toggled(is_paused: bool) -> void:
	_pause_label.visible = is_paused
	_pause_dim.visible = is_paused
	_pause_controls.visible = is_paused


func _on_boss_started(boss_name: String, maximum: int) -> void:
	_boss_name.text = boss_name
	_boss_health.max_value = maximum
	_boss_health.value = maximum
	_boss_bar.show()


func _on_boss_health_changed(current: int, maximum: int) -> void:
	_boss_health.max_value = maximum
	var tween: Tween = create_tween()
	tween.tween_property(_boss_health, "value", float(current), 0.25)


## Makes sure `container` holds exactly `count` TextureRects.
func _fill_icons(container: HBoxContainer, count: int) -> void:
	while container.get_child_count() < count:
		var icon: TextureRect = TextureRect.new()
		# Size comes from custom_minimum_size, set by the caller.
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		container.add_child(icon)
	while container.get_child_count() > count:
		var extra: Node = container.get_child(container.get_child_count() - 1)
		container.remove_child(extra)
		extra.queue_free()

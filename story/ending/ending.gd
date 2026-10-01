extends Node2D
## The ending, straight after the moon cracks on the roof of Ember Keep. The
## white of the crack fades on the roof: the moon trembles and shatters, its
## pieces fall as a rain of stars, Ember fades into light, and fireworks fill
## the sky. Then dawn on the twelfth day in the village, lit with lanterns:
## everyone is waiting for her, and the title cards close it. Then the credits.
## Esc (pause) skips to the credits.
##
## Scene: Ending (Node2D)
##   %Camera2D  fixed; jumps from the roof to the village behind the black
##   %Roof (the view is 0..480 x 0..270, the roof's top at y 176)
##     Sky, %MoonGlow, %Moon, %ShardRain (CPUParticles2D), %RoofSky (stars and
##     fireworks go here), %RoofGround (TileMapLayer), %Kael, %Hero
##   %Village (at VILLAGE_ORIGIN; ground at local y 224, like the memories)
##     Sky, %DawnSky (fireworks), %Land (tinted for dawn) > hills, %VillageGround,
##     houses, lanterns, villagers, %Walker (Mariane), SkyLanterns
##   FlashLayer > %Flash (ColorRect, white at the start, as the crack left it)
##   CardLayer > %CardShade, %TitleCard, %BirthdayCard
##   DialogueBox (story/ending.txt), HintLayer > %SkipLabel

const ROOF_VIEW: Vector2 = Vector2(240.0, 135.0)
const VILLAGE_ORIGIN: Vector2 = Vector2(0.0, 2000.0)
const VILLAGE_VIEW: Vector2 = Vector2(240.0, 180.0)
const ROOF_ROWS: Vector2i = Vector2i(11, 17)
const ROOF_COLUMNS: Vector2i = Vector2i(-1, 30)
const VILLAGE_ROWS: Array[int] = [7, 8, 9]
const VILLAGE_COLUMNS: Vector2i = Vector2i(-1, 16)
const STAR_FRAMES: SpriteFrames = preload("res://entities/effects/shooting_star_frames.tres")
const BURST_FRAMES: SpriteFrames = preload("res://entities/effects/light_burst_frames.tres")
const SPARKLE_FRAMES: SpriteFrames = preload("res://entities/effects/sparkle_frames.tres")
const FIREWORK_FRAMES: Array[SpriteFrames] = [
	preload("res://entities/effects/firework_green_frames.tres"),
	preload("res://entities/effects/firework_yellow_frames.tres"),
]
## Fireworks are tinted from these, so the two bursts make many colours.
const FIREWORK_COLORS: Array[Color] = [
	Color(1.0, 1.0, 1.0), Color(1.0, 0.72, 0.85), Color(0.7, 0.85, 1.0),
	Color(1.0, 0.85, 0.55), Color(0.85, 0.75, 1.0),
]
const STAR_COLORS: Array[Color] = [
	Color(1.0, 1.0, 1.0), Color(1.0, 0.85, 0.9), Color(1.0, 0.95, 0.75), Color(0.85, 0.9, 1.0),
]
## Mariane's walking speed into the village (px/s), like her scripted walks.
const WALK_SPEED: float = 42.0
## Where she stops, in front of everyone (village x).
const HERO_STOP_X: float = 176.0

## Where the credits are.
@export_file("*.tscn") var next_scene: String = "res://ui/credits/credits.tscn"

var _is_leaving: bool = false

@onready var _camera: Camera2D = %Camera2D
@onready var _roof: Node2D = %Roof
@onready var _moon: Sprite2D = %Moon
@onready var _moon_glow: Sprite2D = %MoonGlow
@onready var _shard_rain: CPUParticles2D = %ShardRain
@onready var _roof_sky: Node2D = %RoofSky
@onready var _roof_ground: TileMapLayer = %RoofGround
@onready var _kael: AnimatedSprite2D = %Kael
@onready var _hero: AnimatedSprite2D = %Hero
@onready var _village: Node2D = %Village
@onready var _dawn_sky: Node2D = %DawnSky
@onready var _village_ground: TileMapLayer = %VillageGround
@onready var _walker: AnimatedSprite2D = %Walker
@onready var _villagers: Node2D = %Villagers
@onready var _flash: ColorRect = %Flash
@onready var _card_shade: ColorRect = %CardShade
@onready var _title_card: Label = %TitleCard
@onready var _birthday_card: Label = %BirthdayCard
@onready var _skip_label: Label = %SkipLabel


func _ready() -> void:
	Music.play(&"ending", 2.0)
	_paint_ground()
	_camera.position = ROOF_VIEW
	_village.position = VILLAGE_ORIGIN
	_village.hide()
	_hero.play(&"idle_calm")
	# He lies where he fell.
	_kael.animation = &"fall"
	_kael.frame = _kael.sprite_frames.get_frame_count(&"fall") - 1
	for villager: AnimatedSprite2D in _villager_sprites():
		villager.play(&"idle")
	var hint: Tween = create_tween()
	hint.tween_interval(4.0)
	hint.tween_property(_skip_label, "modulate:a", 0.0, 1.0)
	_play()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_leave()


func _play() -> void:
	# The white of the crack clears: the moon still hangs there, broken.
	await _fade_flash(0.0, 2.5)
	await _wait(0.8)
	await _tremble(_moon, 1.4)
	if _is_leaving:
		return
	# It shatters.
	Audio.effect(&"ice", 2.0, 0.7)
	_burst(_roof_sky, BURST_FRAMES, _moon.position, 2.0)
	_flash.color = Color(1.0, 1.0, 1.0, 0.75)
	_fade_flash(0.0, 0.9)
	_moon.hide()
	create_tween().tween_property(_moon_glow, "modulate:a", 0.0, 2.5)
	_shard_rain.emitting = true
	_rain_stars(_roof_sky, 12.0)
	await _wait(1.6)
	_hero.play(&"idle")
	_fade_away(_kael)
	await _wait(1.4)
	await _say("ending_sky")
	_fireworks(_roof_sky, 9.0, Rect2(40.0, 20.0, 400.0, 110.0))
	await _wait(6.5)
	_hero.play(&"idle_calm")
	await _wait(2.0)

	# Dawn on the twelfth day.
	await _fade_flash_to(Color.BLACK, 1.8)
	if _is_leaving:
		return
	_roof.hide()
	_village.show()
	_camera.position = VILLAGE_ORIGIN + VILLAGE_VIEW
	_camera.reset_physics_interpolation()
	await _wait(0.8)
	await _say("ending_dawn")
	_fade_flash(0.0, 2.2)
	await _walk(_walker, HERO_STOP_X)
	_walker.play(&"idle")
	await _wait(0.6)
	await _say("ending_village")
	await _wait(0.6)
	_fireworks(_dawn_sky, 7.0, Rect2(60.0, 50.0, 360.0, 80.0))
	await _wait(2.4)
	_walker.play(&"idle_calm")
	await _say("ending_sky_again")
	await _wait(1.6)

	# The title cards.
	var shade: Tween = create_tween()
	shade.tween_property(_card_shade, "color:a", 0.55, 1.5)
	await shade.finished
	await _show_card(_title_card, 3.5)
	await _show_card(_birthday_card, 5.0)
	await _fade_flash_to(Color.BLACK, 1.5)
	await _wait(0.6)
	_leave()


func _paint_ground() -> void:
	var roof: Array[Vector2i] = []
	for row: int in range(ROOF_ROWS.x, ROOF_ROWS.y + 1):
		for column: int in range(ROOF_COLUMNS.x, ROOF_COLUMNS.y + 1):
			roof.append(Vector2i(column, row))
	_roof_ground.set_cells_terrain_connect(roof, 0, 0)
	var grass: Array[Vector2i] = []
	for row: int in VILLAGE_ROWS:
		for column: int in range(VILLAGE_COLUMNS.x, VILLAGE_COLUMNS.y + 1):
			grass.append(Vector2i(column, row))
	_village_ground.set_cells_terrain_connect(grass, 0, 0)


func _villager_sprites() -> Array[AnimatedSprite2D]:
	var sprites: Array[AnimatedSprite2D] = []
	for child: Node in _villagers.get_children():
		if child is AnimatedSprite2D:
			sprites.append(child as AnimatedSprite2D)
	return sprites


## Shakes a sprite in place, harder as it goes, then sets it back.
func _tremble(sprite: Node2D, seconds: float) -> void:
	var home: Vector2 = sprite.position
	var tween: Tween = create_tween()
	var steps: int = int(seconds / 0.05)
	for i: int in steps:
		var strength: float = 0.5 + 2.5 * float(i) / steps
		var offset: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		tween.tween_property(sprite, "position", home + (offset * strength).round(), 0.05)
	tween.tween_property(sprite, "position", home, 0.05)
	await tween.finished


## Stars fall all over the sky for a while, thick at first, then thinning out.
func _rain_stars(parent: Node2D, seconds: float) -> void:
	var elapsed: float = 0.0
	while elapsed < seconds and not _is_leaving:
		var star: AnimatedSprite2D = _burst(parent, STAR_FRAMES,
				Vector2(randf_range(0.0, 520.0), randf_range(-10.0, 120.0)), 1.0)
		star.flip_h = randf() < 0.5
		var tint: Color = STAR_COLORS.pick_random()
		star.modulate = tint
		var gap: float = lerpf(0.08, 0.45, elapsed / seconds) * randf_range(0.6, 1.4)
		elapsed += gap
		await _wait(gap)


## Fireworks burst one after another in `area` (local to `parent`).
func _fireworks(parent: Node2D, seconds: float, area: Rect2) -> void:
	var elapsed: float = 0.0
	while elapsed < seconds and not _is_leaving:
		var at: Vector2 = area.position + Vector2(randf() * area.size.x, randf() * area.size.y)
		var frames: SpriteFrames = FIREWORK_FRAMES.pick_random()
		var firework: AnimatedSprite2D = _burst(parent, frames, at, 2.0)
		var tint: Color = FIREWORK_COLORS.pick_random()
		firework.modulate = tint
		Audio.effect(&"fire", -6.0, randf_range(1.5, 1.9))
		var gap: float = randf_range(0.35, 0.9)
		elapsed += gap
		await _wait(gap)


## Plays a one-shot effect at `scale` (whole numbers keep the pixels square).
func _burst(parent: Node2D, frames: SpriteFrames, at: Vector2,
		size: float) -> AnimatedSprite2D:
	var effect: AnimatedSprite2D = OneShot.play(parent, frames, Vector2.ZERO, 0)
	effect.position = at
	effect.scale = Vector2(size, size)
	return effect


## Ember fades into the light, with a sparkle where he lay.
func _fade_away(sprite: AnimatedSprite2D) -> void:
	var sparkle: AnimatedSprite2D = _burst(_roof, SPARKLE_FRAMES,
			sprite.position + Vector2(0.0, -12.0), 1.0)
	sparkle.z_index = 2
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.9, 0.8, 0.0), 3.0)


func _walk(sprite: AnimatedSprite2D, to_x: float) -> void:
	sprite.play(&"walk")
	var seconds: float = absf(to_x - sprite.position.x) / WALK_SPEED
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "position:x", to_x, seconds)
	await tween.finished


func _show_card(card: Label, hold: float) -> void:
	if _is_leaving:
		return
	var tween: Tween = create_tween()
	tween.tween_property(card, "modulate:a", 1.0, 1.5)
	tween.tween_interval(hold)
	tween.tween_property(card, "modulate:a", 0.0, 1.2)
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


## Fades to a colour from clear (the flash keeps its alpha, takes the colour).
func _fade_flash_to(color: Color, seconds: float) -> void:
	_flash.color = Color(color, _flash.color.a)
	await _fade_flash(color.a, seconds)


func _leave() -> void:
	if _is_leaving:
		return
	_is_leaving = true
	SceneManager.change_scene(next_scene)

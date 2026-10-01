extends SceneTree
## Generates the resources that would otherwise be clicked together by hand:
## sprite animations (SpriteFrames) and the village TileSet with its terrain
## peering bits, collision and the one-way plank.
##
## Run after importing assets, from the project folder:
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/build_resources.gd
## Re-running overwrites the generated .tres files.

const N: TileSet.CellNeighbor = TileSet.CELL_NEIGHBOR_TOP_SIDE
const S: TileSet.CellNeighbor = TileSet.CELL_NEIGHBOR_BOTTOM_SIDE
const E: TileSet.CellNeighbor = TileSet.CELL_NEIGHBOR_RIGHT_SIDE
const W: TileSet.CellNeighbor = TileSet.CELL_NEIGHBOR_LEFT_SIDE
const NE: TileSet.CellNeighbor = TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER
const NW: TileSet.CellNeighbor = TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER
const SE: TileSet.CellNeighbor = TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER
const SW: TileSet.CellNeighbor = TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER

const TILE: int = 32
## Rows between the grass, autumn and snow copies of the layout in floor_tiles.png.
const SEASON_ROW_STRIDE: int = 6
const SEASON_NAMES: Array[String] = ["grass", "autumn", "snow"]
const SEASON_COLORS: Array[Color] = [Color(0.4, 0.7, 0.3), Color(0.8, 0.5, 0.2), Color(0.8, 0.9, 1.0)]


## Villagers built by tools/import_story_assets.py (assets/villagers/<name>.png).
const VILLAGERS: Array[String] = [
	"tomas", "rosa", "lina", "mara", "joss", "bram", "theo", "wren", "pell", "hild",
	"past_girl", "past_boy",
]
## Effect strip -> [frame width, frame height, fps, loops].
const EFFECTS: Dictionary[String, Array] = {
	"fire_burst": [64, 64, 20.0, false],
	"fire_puff": [32, 32, 16.0, false],
	"moon_absorb": [64, 64, 24.0, false],
	"sparkle": [48, 48, 14.0, true],
	"shard_burst": [32, 32, 20.0, false],
	"dust_puff": [32, 32, 18.0, false],
	# From the 16x16 Fantasy pack, used in every chapter.
	"hit_spark": [32, 32, 22.0, false],
	"guard_spark": [32, 32, 22.0, false],
	"landing_dust": [48, 32, 20.0, false],
	"glimmer": [20, 44, 10.0, true],
	"alert": [16, 16, 8.0, true],
	"question": [16, 16, 6.0, true],
	# From the Starry Night package, the Lantern Forest's shooting star.
	"shooting_star": [62, 85, 10.0, false],
	# From the Holy effects pack, recoloured: the campfire rest (gold for the
	# hearts, silver-blue for the moons).
	"heal_gold": [64, 64, 14.0, false],
	"heal_moon": [64, 64, 14.0, false],
}
## Village decor prop -> [texture, z_index]. Big backdrop pieces sit at -3,
## small clutter at -2, villagers at -1 and Mariane at 0.
const PROPS: Dictionary[String, Array] = {
	"crate": ["decor/crate.png", -2],
	"crates": ["decor/crates.png", -2],
	"barrel": ["decor/barrel.png", -2],
	"barrels": ["decor/barrels.png", -2],
	"chopping_block": ["decor/chopping_block.png", -2],
	"apple_stand": ["decor/apple_stand.png", -2],
	"basket": ["decor/basket.png", -2],
	"log_pile": ["decor/log_pile.png", -2],
	"pumpkin": ["decor/pumpkin.png", -2],
	"wheat_bundle": ["decor/wheat_bundle.png", -2],
	"rocks": ["decor/rocks.png", -2],
	"rocks_big": ["decor/rocks_big.png", -3],
	"scarecrow": ["decor/scarecrow.png", -3],
	"laundry": ["decor/laundry.png", -3],
	"bush": ["decor/bush.png", -2],
	"bush_small": ["decor/bush_small.png", -2],
	"flower_pot_purple": ["decor/flower_pot_purple.png", -2],
	"flower_pot_green": ["decor/flower_pot_green.png", -2],
	"tent_large": ["tent_large.png", -3],
	"tent_small": ["tent_small.png", -3],
}


func _init() -> void:
	_build_player_frames()
	_build_goblin_frames()
	_build_campfire_frames()
	_build_village_tileset()
	_build_forest_tileset()
	_build_castle_tileset()
	_build_villager_frames()
	_build_kael_frames()
	_build_effect_frames()
	_build_small_animations()
	_build_prop_scenes()
	_build_witch_frames()
	_build_forest_props()
	_build_road_resources()
	_build_castle_resources()
	_build_depths_resources()
	_build_warden_resources()
	print("build_resources: done")
	quit()


func _build_witch_frames() -> void:
	# Strips from import_forest_assets.py: 144x48 frames, body at x = 40.
	var specs: Dictionary[String, Array] = {
		"idle": [8.0, true], "run": [10.0, true], "charge": [8.0, true],
		"attack": [10.0, false], "hurt": [10.0, false], "death": [10.0, false],
	}
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	for animation: String in specs:
		var sheet: Texture2D = load("res://assets/witch/witch_%s.png" % animation)
		var count: int = int(sheet.get_width() / 144.0)
		var spec: Array = specs[animation]
		_add_animation(frames, StringName(animation), _row(sheet, 0, count, Vector2(144, 48)),
				spec[0], spec[1])
	_save(frames, "res://entities/boss/moon_witch_frames.tres")

	# The mushroom's "Attack3" sheet (11 frames): 0-2 a standing sway, used
	# as its walk; 3-6 it hunkers down (the warning), 7-10 spores burst out.
	var mushroom: Texture2D = load("res://assets/monster_creatures/mushroom_attack3.png")
	var spores: Array[Texture2D] = _row(mushroom, 0, 11, Vector2(150, 150))
	var walk: SpriteFrames = SpriteFrames.new()
	walk.remove_animation(&"default")
	_add_animation(walk, &"walk", _frames_between(spores, 0, 3), 5.0, true)
	_add_animation(walk, &"attack", _frames_between(spores, 3, 11), 9.0, false)
	_save(walk, "res://entities/enemy/mushroom_frames.tres")

	var forge: Texture2D = load("res://assets/gandalfhardcore/forge_sheet.png")
	var fire: SpriteFrames = SpriteFrames.new()
	fire.remove_animation(&"default")
	_add_animation(fire, &"default", _row(forge, 0, 6, Vector2(64, 64)), 8.0, true)
	_save(fire, "res://entities/prop/forge_frames.tres")


## Forest decorations as Sprite2D scenes. Hanging ones ("top") hang from the
## cell above where the map places them; the rest stand on the ground. Each
## lantern in the art gets a softly breathing glow.
func _build_forest_props() -> void:
	# name -> [anchor, z_index, lantern positions in the image]
	var props: Dictionary[String, Array] = {
		"coral_tree": ["bottom", -3, [Vector2(35, 80), Vector2(53, 104), Vector2(71, 76), Vector2(94, 88)]],
		"coral_tree_small": ["bottom", -3, [Vector2(21, 38), Vector2(7, 41), Vector2(35, 51)]],
		"lantern_vine": ["top", -2, [Vector2(10, 26), Vector2(2, 17)]],
		"lantern_vine_long": ["top", -2, [Vector2(2, 43), Vector2(6, 35)]],
		"rock_purple": ["bottom", -2, []],
		"red_plant": ["bottom", -2, []],
		"bush_dark": ["bottom", -2, []],
		"bush_wide": ["bottom", -2, []],
		"sprout": ["bottom", -2, []],
	}
	var glow_texture: Texture2D = load("res://assets/forest/glow_lantern.png")
	var glow_script: Script = load("res://entities/prop/lantern_glow.gd")
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for prop: String in props:
		var spec: Array = props[prop]
		var texture: Texture2D = load("res://assets/forest/props/%s.png" % prop)
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = prop.to_pascal_case()
		sprite.texture = texture
		sprite.centered = false
		var left: float = -floorf(texture.get_width() / 2.0)
		var top: float = -16.0 if spec[0] == "top" else -texture.get_height() + 1.0
		sprite.offset = Vector2(left, top)
		sprite.z_index = spec[1]
		var lanterns: Array = spec[2]
		for i: int in lanterns.size():
			var glow: Sprite2D = Sprite2D.new()
			glow.name = "Glow%d" % (i + 1)
			glow.texture = glow_texture
			glow.material = additive
			glow.set_script(glow_script)
			glow.position = sprite.offset + (lanterns[i] as Vector2)
			sprite.add_child(glow)
			glow.owner = sprite
		var scene: PackedScene = PackedScene.new()
		scene.pack(sprite)
		_save(scene, "res://entities/prop/forest/%s.tscn" % prop)
		sprite.free()


func _build_villager_frames() -> void:
	for villager: String in VILLAGERS:
		var sheet: Texture2D = load("res://assets/villagers/%s.png" % villager)
		var frames: SpriteFrames = SpriteFrames.new()
		frames.remove_animation(&"default")
		# Sheet rows (80x64 cells): idle 5, walk 8, run 8, jump 4, fall 4,
		# attack 6, death 10.
		_add_animation(frames, &"idle", _row(sheet, 0, 5, Vector2(80, 64)), 6.0, true)
		_add_animation(frames, &"walk", _row(sheet, 1, 8, Vector2(80, 64)), 9.0, true)
		_add_animation(frames, &"run", _row(sheet, 2, 8, Vector2(80, 64)), 13.0, true)
		_add_animation(frames, &"death", _row(sheet, 6, 10, Vector2(80, 64)), 9.0, false)
		_save(frames, "res://entities/npc/frames/%s_frames.tres" % villager)


func _build_kael_frames() -> void:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_animation(frames, &"idle", _load_sequence("idle", "fire_knight"), 10.0, true)
	_add_animation(frames, &"run", _load_sequence("run", "fire_knight"), 12.0, true)
	_add_animation(frames, &"special", _load_sequence("special", "fire_knight"), 14.0, false)
	_save(frames, "res://story/actors/kael_frames.tres")


func _build_effect_frames() -> void:
	for effect: String in EFFECTS:
		var spec: Array = EFFECTS[effect]
		var size: Vector2 = Vector2(spec[0], spec[1])
		var sheet: Texture2D = load("res://assets/effects/%s.png" % effect)
		var count: int = int(sheet.get_width() / size.x)
		var frames: SpriteFrames = SpriteFrames.new()
		frames.remove_animation(&"default")
		_add_animation(frames, &"play", _row(sheet, 0, count, size), spec[2], spec[3])
		_save(frames, "res://entities/effects/%s_frames.tres" % effect)


func _build_small_animations() -> void:
	var cooking: Texture2D = load("res://assets/gandalfhardcore/cooking_stall_sheet.png")
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_animation(frames, &"default", _row(cooking, 0, 12, Vector2(64, 64)), 8.0, true)
	_save(frames, "res://entities/prop/cooking_stall_frames.tres")

	var butterfly: Texture2D = load("res://assets/generated/butterfly.png")
	frames = SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_animation(frames, &"default", _row(butterfly, 0, 2, Vector2(5, 4)), 8.0, true)
	_save(frames, "res://entities/prop/butterfly_frames.tres")


## One Sprite2D scene per decor prop, origin at its base so it stands on the
## ground where the map places it.
func _build_prop_scenes() -> void:
	for prop: String in PROPS:
		var spec: Array = PROPS[prop]
		var texture: Texture2D = load("res://assets/gandalfhardcore/%s" % spec[0])
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = prop.to_pascal_case()
		sprite.texture = texture
		sprite.centered = false
		# Sink one pixel so nothing seems to hover over the grass.
		sprite.offset = Vector2(-floorf(texture.get_width() / 2.0), -texture.get_height() + 1)
		sprite.z_index = spec[1]
		var scene: PackedScene = PackedScene.new()
		scene.pack(sprite)
		_save(scene, "res://entities/prop/%s.tscn" % prop)
		sprite.free()


## Chapter Three: the Long Road. Art from tools/import_road_assets.py.
func _build_road_resources() -> void:
	_build_road_props()
	_build_road_animations()
	_build_knight_frames()
	_build_road_monster_frames()
	_build_critter_frames()


## Static road props as Sprite2D scenes (origin at the base, or at the top
## for things that hang from a ceiling), like the village decor.
func _build_road_props() -> void:
	# name -> [anchor, z_index]. Big trees stand furthest back.
	var props: Dictionary[String, Array] = {
		"wheat": ["bottom", -2], "tall_grass": ["bottom", -2], "grass_tuft": ["bottom", -2],
		"fern": ["bottom", -2], "sapling": ["bottom", -2], "cattail": ["bottom", -2],
		"reeds": ["bottom", -2], "hollow_stump": ["bottom", -3], "signpost": ["bottom", -2],
		"signpost_small": ["bottom", -2], "bush_gold": ["bottom", -2], "bush_round": ["bottom", -2],
		"bush_low": ["bottom", -2], "stone": ["bottom", -2], "boulder": ["bottom", -3],
		"red_mushrooms": ["bottom", -3], "mine_cart": ["bottom", -2], "mine_door": ["bottom", -3],
		"ice_urchin": ["bottom", -3], "ice_crystals": ["bottom", -2], "ice_column": ["bottom", -3],
		"ice_cluster": ["bottom", -3], "ice_spikes": ["bottom", -2], "icicle": ["top", -2],
		"green_crystal": ["bottom", -2], "red_pine": ["bottom", -4], "red_pine_small": ["bottom", -4],
		"red_fir": ["bottom", -3], "red_tree": ["bottom", -4], "teal_pine": ["bottom", -4],
		"teal_pine_small": ["bottom", -4], "teal_fir": ["bottom", -3], "teal_fir_small": ["bottom", -3],
		"bare_tree": ["bottom", -4], "teal_tree": ["bottom", -4], "stump_snow": ["bottom", -2],
		"fence": ["bottom", -2], "fence_snow": ["bottom", -2], "snow_bush": ["bottom", -2],
		"snow_bush_small": ["bottom", -2], "snow_mound": ["bottom", -2], "frost_cypress": ["bottom", -2],
		"frost_fern": ["bottom", -2], "well": ["bottom", -3], "vein_statue": ["bottom", -3],
		"vein_column": ["bottom", -3],
	}
	for prop: String in props:
		var spec: Array = props[prop]
		var texture: Texture2D = load("res://assets/road/props/%s.png" % prop)
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = prop.to_pascal_case()
		sprite.texture = texture
		sprite.centered = false
		var top: float = -32.0 if spec[0] == "top" else -texture.get_height() + 1.0
		sprite.offset = Vector2(-floorf(texture.get_width() / 2.0), top)
		sprite.z_index = spec[1]
		_save_scene(sprite, "res://entities/prop/road/%s.tscn" % prop)


## Animated road props: trees and grass swaying in the wind (each starts at
## a random point of its loop, see sway.gd), and a few small loops.
func _build_road_animations() -> void:
	var sway_script: Script = load("res://entities/prop/sway.gd")
	# name -> [frame size, frame count, fps, z_index, anchor]
	var animated: Dictionary[String, Array] = {
		"oak_sway": [Vector2(195, 166), 42, 10.0, -4, "bottom"],
		"pine_sway": [Vector2(59, 110), 28, 9.0, -4, "bottom"],
		"pine_tall_sway": [Vector2(71, 123), 60, 12.0, -4, "bottom"],
		"grass_sway": [Vector2(118, 25), 58, 12.0, -2, "bottom"],
		"fireflies_jar": [Vector2(16, 16), 4, 6.0, -2, "bottom"],
		"little_eyes_1": [Vector2(16, 16), 36, 8.0, -3, "centre"],
		"vein_a1": [Vector2(32, 16), 12, 7.0, -3, "centre"],
		"ice_glints": [Vector2(20, 44), 10, 8.0, -1, "bottom"],
		"waterfall": [Vector2(32, 128), 20, 12.0, -1, "top"],
	}
	for prop: String in animated:
		var spec: Array = animated[prop]
		var size: Vector2 = spec[0]
		var sheet: Texture2D = load("res://assets/road/%s.png" % prop)
		var frames: SpriteFrames = SpriteFrames.new()
		frames.remove_animation(&"default")
		_add_animation(frames, &"default", _grid(sheet, spec[1], size), spec[2], true)
		var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
		sprite.name = prop.to_pascal_case()
		sprite.sprite_frames = frames
		sprite.animation = &"default"
		sprite.centered = false
		match spec[4]:
			"bottom":
				sprite.offset = Vector2(-floorf(size.x / 2.0), -size.y + 1.0)
			"top":
				sprite.offset = Vector2(-floorf(size.x / 2.0), -32.0)
			_:
				sprite.offset = -(size / 2.0).floor()
		sprite.z_index = spec[3]
		sprite.set_script(sway_script)
		_save_scene(sprite, "res://entities/prop/road/%s.tscn" % prop)

	var water: SpriteFrames = SpriteFrames.new()
	water.remove_animation(&"default")
	var surface: Texture2D = load("res://assets/road/water_surface.png")
	_add_animation(water, &"default", _row(surface, 0, 20, Vector2(32, 32)), 8.0, true)
	_save(water, "res://entities/water/water_surface_frames.tres")

	var blizzard: SpriteFrames = SpriteFrames.new()
	blizzard.remove_animation(&"default")
	var snow: Texture2D = load("res://assets/road/blizzard.png")
	_add_animation(blizzard, &"default", _grid(snow, 30, Vector2(484, 274), 5), 12.0, true)
	_save(blizzard, "res://levels/backgrounds/blizzard_frames.tres")

	# Frost spikes (16x16 Fantasy "Ice"): 1-6 a little frost (the warning),
	# 7-12 the pillar bursts up and stands, 13-15 it sinks again.
	var ice: Texture2D = load("res://assets/road/frost_spikes.png")
	var spikes: Array[Texture2D] = _row(ice, 0, 16, Vector2(48, 32))
	var spike_frames: SpriteFrames = SpriteFrames.new()
	spike_frames.remove_animation(&"default")
	_add_animation(spike_frames, &"warn", _frames_between(spikes, 1, 7), 10.0, false)
	_add_animation(spike_frames, &"burst", _frames_between(spikes, 7, 13), 16.0, false)
	_add_animation(spike_frames, &"sink", _frames_between(spikes, 13, 16), 12.0, false)
	_save(spike_frames, "res://entities/hazard/frost_spikes_frames.tres")


## Kael's Shield (the Knight pack), straightened onto 192x64 frames with his
## body at x 64 and his feet at y 44.
func _build_knight_frames() -> void:
	# name -> [fps, loops]
	var specs: Dictionary[String, Array] = {
		"idle": [10.0, true], "run": [12.0, true], "thrust": [12.0, false],
		"slash": [10.0, false], "sweep": [12.0, false], "guard": [12.0, false],
		"roll": [18.0, false], "leap": [14.0, false],
	}
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	for animation: String in specs:
		var sheet: Texture2D = load("res://assets/knight/knight_%s.png" % animation)
		var count: int = int(sheet.get_width() / 192.0)
		var spec: Array = specs[animation]
		_add_animation(frames, StringName(animation), _row(sheet, 0, count, Vector2(192, 64)),
				spec[0], spec[1])
	# Death 0-8: he sinks to one knee, his sword planted. There he yields.
	var death: Texture2D = load("res://assets/knight/knight_death.png")
	_add_animation(frames, &"yield", _row(death, 0, 9, Vector2(192, 64)), 9.0, false)
	_save(frames, "res://entities/boss/shield_knight_frames.tres")


func _build_road_monster_frames() -> void:
	# Skeleton "Attack3" (6 frames of 150): 0-1 sword raised behind its
	# shield (its walk), 2 the wind-up, 3 the throw, 4-5 the follow-through.
	var skeleton: Array[Texture2D] = _row(
			load("res://assets/monster_creatures/skeleton_attack3.png"), 0, 6, Vector2(150, 150))
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_animation(frames, &"walk", _frames_between(skeleton, 0, 2), 4.0, true)
	_add_animation(frames, &"attack", _frames_between(skeleton, 0, 6), 6.0, false)
	_save(frames, "res://entities/enemy/skeleton_frames.tres")

	# The thrown sword (8 frames of 92x102): 0-2 spinning, 3-7 it shatters.
	var sword: Array[Texture2D] = _row(
			load("res://assets/monster_creatures/skeleton_projectile.png"), 0, 8, Vector2(92, 102))
	frames = SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_animation(frames, &"fly", _frames_between(sword, 0, 3), 14.0, true)
	_add_animation(frames, &"burst", _frames_between(sword, 3, 8), 16.0, false)
	_save(frames, "res://entities/enemy/skeleton_sword_frames.tres")

	# Flying eye "Attack3" (6 frames of 150): 0 wings folded, 1-2 a squint
	# (the wind-up), 3 wings flare, 4-5 wings up. Flapping: 0, 3, 4, 5.
	var eye: Array[Texture2D] = _row(
			load("res://assets/monster_creatures/flying_eye_attack3.png"), 0, 6, Vector2(150, 150))
	frames = SpriteFrames.new()
	frames.remove_animation(&"default")
	var flap: Array[Texture2D] = [eye[0], eye[3], eye[4], eye[5], eye[4], eye[3]]
	_add_animation(frames, &"walk", flap, 10.0, true)
	_add_animation(frames, &"attack", _frames_between(eye, 1, 6), 6.0, false)
	_save(frames, "res://entities/enemy/flying_eye_frames.tres")

	# The spit (8 frames of 48): 0-2 a spinning glob, 3-7 a splatter.
	var spit: Array[Texture2D] = _row(
			load("res://assets/monster_creatures/flying_eye_projectile.png"), 0, 8, Vector2(48, 48))
	frames = SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_animation(frames, &"fly", _frames_between(spit, 0, 3), 12.0, true)
	_add_animation(frames, &"burst", _frames_between(spit, 3, 8), 16.0, false)
	_save(frames, "res://entities/enemy/eye_spit_frames.tres")


## Sheep (16x16 Fantasy), and the frog, fish and snake (Pixel Valley).
func _build_critter_frames() -> void:
	var sheep_fps: Dictionary[String, float] = {"idle": 6.0, "walk": 10.0, "sleep": 4.0}
	for colour: String in ["white", "black"]:
		var frames: SpriteFrames = SpriteFrames.new()
		frames.remove_animation(&"default")
		for animation: String in sheep_fps:
			var sheet: Texture2D = load("res://assets/road/sheep_%s_%s.png" % [colour, animation])
			var size: Vector2 = Vector2(sheet.get_width() / 8.0, sheet.get_height())
			_add_animation(frames, StringName(animation), _row(sheet, 0, 8, size),
					sheep_fps[animation], true)
		_save(frames, "res://entities/critter/sheep_%s_frames.tres" % colour)

	# Frog (14 of 27x20): 0-1 sitting, 2-4 its tongue flicks, 5-13 a hop.
	var frog: Array[Texture2D] = _row(load("res://assets/road/frog.png"), 0, 14, Vector2(27, 20))
	var frog_frames: SpriteFrames = SpriteFrames.new()
	frog_frames.remove_animation(&"default")
	_add_animation(frog_frames, &"idle", _frames_between(frog, 0, 2), 3.0, true)
	_add_animation(frog_frames, &"walk", _frames_between(frog, 5, 14), 16.0, false)
	_add_animation(frog_frames, &"tongue", _frames_between(frog, 2, 5), 8.0, false)
	_save(frog_frames, "res://entities/critter/frog_frames.tres")

	var fish: SpriteFrames = SpriteFrames.new()
	fish.remove_animation(&"default")
	_add_animation(fish, &"walk", _row(load("res://assets/road/fish.png"), 0, 7, Vector2(29, 17)),
			12.0, true)
	_save(fish, "res://entities/critter/fish_frames.tres")

	var snake: SpriteFrames = SpriteFrames.new()
	snake.remove_animation(&"default")
	var slither: Array[Texture2D] = _row(load("res://assets/road/snake.png"), 0, 6, Vector2(23, 16))
	_add_animation(snake, &"walk", slither, 8.0, true)
	_add_animation(snake, &"idle", _frames_between(slither, 0, 1), 1.0, true)
	_save(snake, "res://entities/critter/snake_frames.tres")


## `count` cells of `size`, read left to right and top to bottom from a
## sheet `columns` cells wide (tools/import_road_assets.py packs 8 wide).
func _grid(sheet: Texture2D, count: int, size: Vector2, columns: int = 8) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	for i: int in count:
		var cell: Vector2 = Vector2(i % columns, floori(i / float(columns))) * size
		textures.append(_atlas(sheet, Rect2(cell, size)))
	return textures


## Packs a node tree into a scene file and frees the nodes.
func _save_scene(root: Node, path: String) -> void:
	var scene: PackedScene = PackedScene.new()
	scene.pack(root)
	_save(scene, path)
	root.free()


## `count` cells of `size` from one row of a sheet.
func _row(sheet: Texture2D, row: int, count: int, size: Vector2) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	for i: int in count:
		textures.append(_atlas(sheet, Rect2(Vector2(i * size.x, row * size.y), size)))
	return textures


## Mariane's animations, cut from the Warrior Woman sheets (80x64 frames,
## feet at y 48, body at x 44). Every sheet the pack has is used; the two
## "combo" sheets are the single attacks joined, so those are played in a row.
func _build_player_frames() -> void:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	var jump: Array[Texture2D] = _heroine("jump")
	var crouch: Array[Texture2D] = _heroine("crouch")
	var slide: Array[Texture2D] = _heroine("slide")
	var guard: Array[Texture2D] = _heroine("idle_block")
	var spell: Array[Texture2D] = _heroine("spell")
	var hang: Array[Texture2D] = _heroine("wall_hang")
	var getting_up: Array[Texture2D] = _heroine("getting_up")

	_add_animation(frames, &"idle", _heroine("idle"), 8.0, true)
	# The relaxed stance, after standing still a while and in conversations.
	_add_animation(frames, &"idle_calm", _heroine("idle_2"), 7.0, true)
	# Scripted walks in story scenes.
	_add_animation(frames, &"walk", _heroine("walk"), 10.0, true)
	_add_animation(frames, &"run", _heroine("run"), 12.0, true)

	# Jump: 0 takeoff, 1-4 rising, 5 the turn at the top, 6-8 falling,
	# 9-10 landing.
	_add_animation(frames, &"jump", _frames_between(jump, 0, 5), 14.0, false)
	_add_animation(frames, &"up_to_fall", _frames_between(jump, 5, 6), 12.0, false)
	_add_animation(frames, &"fall", _frames_between(jump, 6, 9), 10.0, true)
	_add_animation(frames, &"land", _frames_between(jump, 9, 11), 16.0, false)

	# Crouch: 0-2 goes down (held on 2), 3-4 stands back up.
	_add_animation(frames, &"crouch", _frames_between(crouch, 0, 3), 16.0, false)
	_add_animation(frames, &"stand_up", _frames_between(crouch, 3, 5), 16.0, false)
	_add_animation(frames, &"crouch_attack", _heroine("crouch_attack"), 20.0, false)
	# Slide: 0-6 goes down and slides (held on 6), 7-9 gets back up.
	_add_animation(frames, &"slide", _frames_between(slide, 0, 7), 18.0, false)
	_add_animation(frames, &"slide_end", _frames_between(slide, 7, 10), 18.0, false)

	# The ground combo: Attack1 (from frame 1, so the swing starts at once),
	# Attack2, Attack3. Together they are the pack's AttackCombo sheet.
	_add_animation(frames, &"attack", _frames_between(_heroine("attack_1"), 1, 7), 18.0, false)
	_add_animation(frames, &"attack_2", _heroine("attack_2"), 18.0, false)
	_add_animation(frames, &"attack_3", _heroine("attack_3"), 16.0, false)
	# The air combo: JumpAttack1 then JumpAttack2 (the pack's JumpAttack).
	_add_animation(frames, &"air_attack", _heroine("jump_attack_1"), 18.0, false)
	_add_animation(frames, &"air_attack_2", _heroine("jump_attack_2"), 18.0, false)
	# No dash sheet: she leans into the dash with her sword swept back
	# (Attack3 frame 0 on the ground, JumpAttack1 frame 0 in the air) and
	# leaves afterimages. The lunge out of it is Attack2's wide sweep.
	_add_animation(frames, &"dash", _frames_between(_heroine("attack_3"), 0, 1), 10.0, false)
	_add_animation(frames, &"air_dash", _frames_between(_heroine("jump_attack_1"), 0, 1), 10.0, false)
	_add_animation(frames, &"dash_attack", _heroine("attack_2"), 16.0, false)

	# Guard: IdleBlock 0-1 raises the sword, 2-10 holds it, 11 lowers it.
	# Block is the flash of a blow stopped on the blade.
	_add_animation(frames, &"guard_up", _frames_between(guard, 0, 2), 16.0, false)
	_add_animation(frames, &"guard", _frames_between(guard, 2, 11), 9.0, true)
	_add_animation(frames, &"guard_down", _frames_between(guard, 11, 12), 16.0, false)
	_add_animation(frames, &"block", _heroine("block"), 18.0, false)

	# Moon Slash (Spell): 0-8 lifts the sword and fills it with moonlight
	# (held glowing on 6-8), 9-15 swings it in a great crescent.
	_add_animation(frames, &"charge", _frames_between(spell, 0, 6), 14.0, false)
	_add_animation(frames, &"charge_hold", _frames_between(spell, 6, 9), 10.0, true)
	_add_animation(frames, &"moon_slash", _frames_between(spell, 9, 16), 16.0, false)
	# Moon Spark (Spell2): light gathers in her hand, flies off on frame 8.
	_add_animation(frames, &"cast", _heroine("spell_2"), 16.0, false)
	# Resting at a campfire: warmth (HPRecovery), then moonlight (MPRecovery).
	_add_animation(frames, &"heal", _heroine("hp_recovery"), 14.0, false)
	_add_animation(frames, &"restore", _heroine("mp_recovery"), 14.0, false)

	_add_animation(frames, &"hurt", _heroine("hit"), 10.0, false)
	_add_animation(frames, &"death", _heroine("death"), 10.0, false)
	# Lying down (asleep, or waking at a campfire), then getting up.
	_add_animation(frames, &"asleep", _frames_between(getting_up, 0, 1), 1.0, false)
	_add_animation(frames, &"get_up", getting_up, 12.0, false)

	# WallHang: 0-2 reaches up and catches the ledge, 3-7 hangs from it.
	# Frame 2 alone is her pressed to a wall, reaching up it.
	_add_animation(frames, &"ledge_grab", _frames_between(hang, 0, 4), 16.0, false)
	_add_animation(frames, &"ledge_hang", _frames_between(hang, 3, 8), 7.0, true)
	_add_animation(frames, &"wall_slide", _frames_between(hang, 2, 3), 1.0, false)
	# WallClimb pulls her up over the ledge (the art rises 20 px).
	_add_animation(frames, &"ledge_climb", _heroine("wall_climb"), 16.0, false)
	_add_animation(frames, &"climb", _heroine("ladder_climb"), 10.0, true)
	_save(frames, "res://entities/player/player_frames.tres")

	# The Moon Spark: a pulsing ball of light (frames 1-2) that bursts (3-6).
	var spark: Array[Texture2D] = _row(load("res://assets/magic/spark.png"), 0, 7, Vector2(32, 32))
	var spark_frames: SpriteFrames = SpriteFrames.new()
	spark_frames.remove_animation(&"default")
	_add_animation(spark_frames, &"fly", _frames_between(spark, 1, 3), 10.0, true)
	_add_animation(spark_frames, &"burst", _frames_between(spark, 3, 7), 16.0, false)
	_save(spark_frames, "res://entities/player/moon_spark_frames.tres")


func _build_goblin_frames() -> void:
	# The goblin's "Attack3" sheet (12 frames): 1-5 are its stance, used as a
	# shuffling walk; 5-11 light a bomb and throw it (frame 10 is the throw).
	var sheet: Texture2D = load("res://assets/monster_creatures/goblin_attack3.png")
	var all: Array[Texture2D] = _row(sheet, 0, 12, Vector2(150, 150))
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_animation(frames, &"walk", _frames_between(all, 1, 6), 6.0, true)
	_add_animation(frames, &"attack", _frames_between(all, 5, 12), 8.0, false)
	_save(frames, "res://entities/enemy/goblin_frames.tres")

	# The bomb (19 frames of 100x100): 0-2 lit fuse, 3-8 spinning, 9-18 blast.
	var bomb_sheet: Texture2D = load("res://assets/monster_creatures/goblin_projectile.png")
	var bomb: Array[Texture2D] = _row(bomb_sheet, 0, 19, Vector2(100, 100))
	var bomb_frames: SpriteFrames = SpriteFrames.new()
	bomb_frames.remove_animation(&"default")
	_add_animation(bomb_frames, &"fly", _frames_between(bomb, 3, 9), 14.0, true)
	_add_animation(bomb_frames, &"fuse", _frames_between(bomb, 0, 3), 12.0, true)
	_add_animation(bomb_frames, &"explode", _frames_between(bomb, 9, 19), 16.0, false)
	_save(bomb_frames, "res://entities/enemy/goblin_bomb_frames.tres")


func _build_campfire_frames() -> void:
	var sheet: Texture2D = load("res://assets/gandalfhardcore/campfire_sheet.png")
	var burn: Array[Texture2D] = []
	for row: int in 8:
		for column: int in 5:
			burn.append(_atlas(sheet, Rect2(column * TILE, row * TILE, TILE, TILE)))
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_animation(frames, &"burn", burn, 12.0, true)
	_save(frames, "res://entities/checkpoint/campfire_frames.tres")


func _build_village_tileset() -> void:
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)  # "world"
	tile_set.set_physics_layer_collision_mask(0, 0)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(1, 2)  # "platforms"
	tile_set.set_physics_layer_collision_mask(1, 0)
	tile_set.add_terrain_set()
	tile_set.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	for i: int in SEASON_NAMES.size():
		tile_set.add_terrain(0)
		tile_set.set_terrain_name(0, i, SEASON_NAMES[i])
		tile_set.set_terrain_color(0, i, SEASON_COLORS[i])

	var ground: TileSetAtlasSource = TileSetAtlasSource.new()
	ground.texture = load("res://assets/gandalfhardcore/floor_tiles.png")
	ground.texture_region_size = Vector2i(TILE, TILE)
	# Attach before creating tiles so their TileData knows the physics layers.
	tile_set.add_source(ground, 0)
	var half: float = TILE / 2.0
	var full_square: PackedVector2Array = PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half),
	])
	var layout: Dictionary[Vector2i, Array] = _ground_layout()
	for season: int in SEASON_NAMES.size():
		for base: Vector2i in layout:
			var coords: Vector2i = base + Vector2i(0, season * SEASON_ROW_STRIDE)
			ground.create_tile(coords)
			var data: TileData = ground.get_tile_data(coords, 0)
			data.terrain_set = 0
			data.terrain = season
			for neighbor: TileSet.CellNeighbor in layout[base]:
				data.set_terrain_peering_bit(neighbor, season)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, full_square)

	var planks: TileSetAtlasSource = TileSetAtlasSource.new()
	planks.texture = load("res://assets/generated/village_plank.png")
	planks.texture_region_size = Vector2i(TILE, TILE)
	tile_set.add_source(planks, 1)
	planks.create_tile(Vector2i.ZERO)
	var plank: TileData = planks.get_tile_data(Vector2i.ZERO, 0)
	plank.add_collision_polygon(1)
	plank.set_collision_polygon_points(1, 0, PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, -half + 6.0),
		Vector2(-half, -half + 6.0),
	]))
	plank.set_collision_polygon_one_way(1, 0, true)
	_save(tile_set, "res://levels/tilesets/village_tileset.tres")


## The Lantern Forest: 16 px mossy blocks drawn by import_forest_assets.py,
## one tile per neighbour mask (256), so every cell has an exact match, plus
## the stringstar plank platform (left end, middle, right end, single).
func _build_forest_tileset() -> void:
	_save(_build_block_tileset("res://assets/forest/forest_terrain.png",
			"res://assets/forest/forest_platform.png", "moss", Color(0.2, 0.4, 0.35)),
			"res://levels/tilesets/forest_tileset.tres")


## Ember Keep: 16 px stone blocks drawn by import_castle_assets.py, one tile per
## neighbour mask (256), plus its one-way stone ledge (left end, middle, right end,
## single), built the same way as the forest's.
func _build_castle_tileset() -> void:
	var tile_set: TileSet = _build_block_tileset("res://assets/castle/castle_terrain.png",
			"res://assets/castle/castle_platform.png", "stone", Color(0.5, 0.47, 0.4))
	# The undercroft's slate (import_depths_assets.py) is terrain 1: chapter_04.tres
	# switches "#" to it at the chasm, where the two never touch.
	_add_block_terrain(tile_set, "res://assets/depths/depths_terrain.png", 2, "slate",
			Color(0.35, 0.36, 0.5))
	_save(tile_set, "res://levels/tilesets/castle_tileset.tres")


## A 16 px tileset with one block terrain (source 0) and a one-way ledge (source 1).
func _build_block_tileset(terrain_path: String, platform_path: String, terrain_name: String,
		terrain_color: Color) -> TileSet:
	const BLOCK_TILE: int = 16
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(BLOCK_TILE, BLOCK_TILE)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)  # "world"
	tile_set.set_physics_layer_collision_mask(0, 0)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(1, 2)  # "platforms"
	tile_set.set_physics_layer_collision_mask(1, 0)
	tile_set.add_terrain_set()
	tile_set.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	_add_block_terrain(tile_set, terrain_path, 0, terrain_name, terrain_color)
	var half: float = BLOCK_TILE / 2.0

	var planks: TileSetAtlasSource = TileSetAtlasSource.new()
	planks.texture = load(platform_path)
	planks.texture_region_size = Vector2i(BLOCK_TILE, BLOCK_TILE)
	tile_set.add_source(planks, 1)
	for i: int in 4:
		planks.create_tile(Vector2i(i, 0))
		var plank: TileData = planks.get_tile_data(Vector2i(i, 0), 0)
		plank.add_collision_polygon(1)
		plank.set_collision_polygon_points(1, 0, PackedVector2Array([
			Vector2(-half, -half), Vector2(half, -half), Vector2(half, -half + 5.0),
			Vector2(-half, -half + 5.0),
		]))
		plank.set_collision_polygon_one_way(1, 0, true)
	return tile_set


## Adds a terrain to terrain set 0 from a 256-tile neighbour-mask atlas (tile index =
## mask, bits N, NE, E, SE, S, SW, W, NW as the importers draw them), as atlas source
## `source_id`, every tile a full square on the "world" physics layer.
func _add_block_terrain(tile_set: TileSet, texture_path: String, source_id: int,
		terrain_name: String, terrain_color: Color) -> void:
	var terrain: int = tile_set.get_terrains_count(0)
	tile_set.add_terrain(0)
	tile_set.set_terrain_name(0, terrain, terrain_name)
	tile_set.set_terrain_color(0, terrain, terrain_color)
	var size: int = tile_set.tile_size.x
	var ground: TileSetAtlasSource = TileSetAtlasSource.new()
	ground.texture = load(texture_path)
	ground.texture_region_size = Vector2i(size, size)
	tile_set.add_source(ground, source_id)
	var half: float = size / 2.0
	var square: PackedVector2Array = PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half),
	])
	var neighbors: Array[TileSet.CellNeighbor] = [N, NE, E, SE, S, SW, W, NW]
	for mask: int in 256:
		var coords: Vector2i = Vector2i(mask % 16, mask / 16)
		ground.create_tile(coords)
		var data: TileData = ground.get_tile_data(coords, 0)
		data.terrain_set = 0
		data.terrain = terrain
		for bit: int in neighbors.size():
			if mask & (1 << bit):
				data.set_terrain_peering_bit(neighbors[bit], terrain)
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, square)


## Atlas coords (grass rows) -> neighbors that are ground, read off the art in
## floor_tiles.png. Autumn and snow repeat the same layout further down.
func _ground_layout() -> Dictionary[Vector2i, Array]:
	return {
		# Solid block: corners, edges and fill.
		Vector2i(0, 0): [E, S, SE],
		Vector2i(1, 0): [E, W, S, SE, SW],
		Vector2i(2, 0): [W, S, SW],
		Vector2i(0, 1): [N, S, E, NE, SE],
		Vector2i(1, 1): [N, S, E, W, NE, NW, SE, SW],
		Vector2i(2, 1): [N, S, W, NW, SW],
		Vector2i(0, 2): [N, E, NE],
		Vector2i(1, 2): [N, E, W, NE, NW],
		Vector2i(2, 2): [N, W, NW],
		# Inner corners: solid all round except one diagonal.
		Vector2i(6, 0): [N, S, E, W, NE, NW, SW],
		Vector2i(8, 0): [N, S, E, W, NE, NW, SE],
		Vector2i(6, 2): [N, S, E, W, NW, SE, SW],
		Vector2i(8, 2): [N, S, E, W, NE, SE, SW],
		# One tile thick: a floating ledge and a pillar.
		Vector2i(6, 5): [E],
		Vector2i(7, 5): [E, W],
		Vector2i(8, 5): [W],
		Vector2i(6, 3): [S],
		Vector2i(3, 1): [N, S],
		Vector2i(6, 4): [N],
		# Thin L-shaped corners from the ring.
		Vector2i(3, 0): [E, S],
		Vector2i(5, 0): [W, S],
		Vector2i(3, 2): [N, E],
		Vector2i(5, 2): [N, W],
	}


## Frames from index `from` up to, not including, `to`.
func _frames_between(textures: Array[Texture2D], from: int, to: int) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	for i: int in range(from, to):
		result.append(textures[i])
	return result


## Every 80x64 frame of one of Mariane's sheets (assets/heroine/<name>.png).
func _heroine(sheet_name: String) -> Array[Texture2D]:
	var sheet: Texture2D = load("res://assets/heroine/%s.png" % sheet_name)
	return _row(sheet, 0, int(sheet.get_width() / 80.0), Vector2(80, 64))


func _load_sequence(animation: String, character: String) -> Array[Texture2D]:
	var directory: String = "res://assets/%s/%s" % [character, animation]
	var textures: Array[Texture2D] = []
	var files: PackedStringArray = DirAccess.get_files_at(directory)
	var pngs: Array[String] = []
	for file: String in files:
		if file.ends_with(".png"):
			pngs.append(file)
	pngs.sort()
	for file: String in pngs:
		textures.append(load(directory.path_join(file)) as Texture2D)
	return textures


func _atlas(sheet: Texture2D, region: Rect2) -> AtlasTexture:
	var texture: AtlasTexture = AtlasTexture.new()
	texture.atlas = sheet
	texture.region = region
	return texture


func _add_animation(
		frames: SpriteFrames, animation: StringName, textures: Array[Texture2D],
		fps: float, loop: bool,
) -> void:
	frames.add_animation(animation)
	frames.set_animation_speed(animation, fps)
	frames.set_animation_loop(animation, loop)
	for texture: Texture2D in textures:
		frames.add_frame(animation, texture)


func _save(resource: Resource, path: String) -> void:
	var error: Error = ResourceSaver.save(resource, path)
	if error != OK:
		push_error("Could not save %s: %s" % [path, error_string(error)])
	else:
		print("saved ", path)


## Ember Keep (import_castle_assets.py, import_skeleton_assets.py): the keep guard,
## the ember vents, the animated lights and the red-moon windows.
func _build_castle_resources() -> void:
	# The keep guard, from the Skeleton Sprite Pack: 56x40 frames with the body at x = 14.
	var guard: SpriteFrames = SpriteFrames.new()
	guard.remove_animation(&"default")
	# animation -> [sheet, frame count, fps, loops]
	var guard_sheets: Dictionary[String, Array] = {
		"walk": ["walk", 13, 10.0, true],
		"attack": ["attack", 18, 12.0, false],
		"hurt": ["hit", 8, 24.0, false],
		"death": ["dead", 15, 14.0, false],
	}
	for animation: String in guard_sheets:
		var spec: Array = guard_sheets[animation]
		var sheet: Texture2D = load("res://assets/skeleton/skeleton_%s.png" % spec[0])
		_add_animation(guard, StringName(animation),
				_row(sheet, 0, spec[1], Vector2(56, 40)), spec[2], spec[3])
	_save(guard, "res://entities/enemy/keep_guard_frames.tres")

	# The ember vent, from Magic Pack 9's Fire-bomb (14 of 64x64): 0-3 a shrinking blue
	# ring and 4-7 a spark are the warning, 8-13 the dome of fire is the burst.
	var bomb: Array[Texture2D] = _row(load("res://assets/effects/fire_bomb.png"), 0, 14,
			Vector2(64, 64))
	var vent: SpriteFrames = SpriteFrames.new()
	vent.remove_animation(&"default")
	_add_animation(vent, &"warn", _frames_between(bomb, 0, 8), 10.0, false)
	_add_animation(vent, &"burst", _frames_between(bomb, 8, 14), 14.0, false)
	_add_animation(vent, &"sink", _frames_between(bomb, 13, 14), 10.0, false)
	_save(vent, "res://entities/hazard/ember_vent_frames.tres")

	# Animated lights: name -> [frames, frame size, fps, anchor]. Hanging lights hang
	# from the top of their cell, the rest stand on the bottom of it.
	var lights: Dictionary[String, Array] = {
		"lantern": [6, Vector2(48, 32), 8.0, "top"],
		"chandelier": [5, Vector2(64, 64), 6.0, "top"],
		"brazier": [4, Vector2(32, 16), 8.0, "bottom"],
		"gold_brazier": [4, Vector2(16, 16), 8.0, "bottom"],
		"sconce_a": [3, Vector2(16, 16), 8.0, "bottom"],
		"sconce_b": [3, Vector2(16, 16), 8.0, "bottom"],
		"sconce_c": [3, Vector2(16, 16), 8.0, "bottom"],
		"sconce_d": [3, Vector2(16, 16), 8.0, "bottom"],
		"candles": [3, Vector2(16, 16), 6.0, "bottom"],
	}
	var sway: Script = load("res://entities/prop/sway.gd")
	for light: String in lights:
		var spec: Array = lights[light]
		var size: Vector2 = spec[1]
		var frames: SpriteFrames = SpriteFrames.new()
		frames.remove_animation(&"default")
		var sheet: Texture2D = load("res://assets/castle/%s.png" % light)
		_add_animation(frames, &"default", _row(sheet, 0, spec[0], size), spec[2], true)
		var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
		sprite.name = light.to_pascal_case()
		sprite.sprite_frames = frames
		sprite.set_script(sway)
		sprite.offset = Vector2(0.0, -16.0 + size.y / 2.0) if spec[3] == "top" 				else Vector2(0.0, -size.y / 2.0 + 1.0)
		sprite.z_index = -2
		_save_scene(sprite, "res://entities/prop/castle/%s.tscn" % light)

	# The windows with the red moon behind them, standing on the bottom of their cell.
	for window: String in ["window_tall", "window_arch", "window_twin"]:
		var texture: Texture2D = load("res://assets/castle/%s.png" % window)
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = window.to_pascal_case()
		sprite.texture = texture
		sprite.offset = Vector2(0.0, -texture.get_height() / 2.0 + 1.0)
		sprite.z_index = -3
		_save_scene(sprite, "res://entities/prop/castle/%s.tscn" % window)


## The undercroft (import_depths_assets.py): the tentacle, the mouth in the floor,
## the floating rock, the Amalgam, and the statues, urn, vein column and book altar.
func _build_depths_resources() -> void:
	# The tentacle (21 of 32x64): 0-3 the rumble at its crack, 4-16 rising and
	# swaying (it hurts), 17-20 sinking. Played by the frost spikes' script.
	var tentacle: Array[Texture2D] = _row(load("res://assets/depths/tentacle.png"), 0, 21,
			Vector2(32, 64))
	var rise: SpriteFrames = SpriteFrames.new()
	rise.remove_animation(&"default")
	_add_animation(rise, &"warn", _frames_between(tentacle, 0, 4), 6.0, false)
	_add_animation(rise, &"burst", _frames_between(tentacle, 4, 17), 12.0, false)
	_add_animation(rise, &"sink", _frames_between(tentacle, 17, 21), 12.0, false)
	_save(rise, "res://entities/hazard/tentacle_frames.tres")

	# The mouth (18 of 64x64): 13-17 then 0-2 it opens and bares its teeth (the
	# warning), 3-7 it snaps shut (it hurts), 8 it lies closed again.
	var mouth: Array[Texture2D] = _row(load("res://assets/depths/mouth.png"), 0, 18,
			Vector2(64, 64))
	var snap: SpriteFrames = SpriteFrames.new()
	snap.remove_animation(&"default")
	var opening: Array[Texture2D] = _frames_between(mouth, 13, 18)
	opening.append_array(_frames_between(mouth, 0, 3))
	_add_animation(snap, &"warn", opening, 8.0, false)
	_add_animation(snap, &"burst", _frames_between(mouth, 3, 8), 14.0, false)
	_add_animation(snap, &"sink", _frames_between(mouth, 8, 9), 10.0, false)
	_save(snap, "res://entities/hazard/mouth_frames.tres")

	var amalgam: SpriteFrames = SpriteFrames.new()
	amalgam.remove_animation(&"default")
	_add_animation(amalgam, &"walk", _row(load("res://assets/depths/amalgam.png"), 0, 9,
			Vector2(64, 64)), 7.0, true)
	_save(amalgam, "res://entities/enemy/amalgam_frames.tres")

	var rock: SpriteFrames = SpriteFrames.new()
	rock.remove_animation(&"default")
	_add_animation(rock, &"default", _row(load("res://assets/depths/floating_rock.png"), 0, 6,
			Vector2(32, 32)), 6.0, true)
	_save(rock, "res://entities/platform/floating_rock_frames.tres")

	# Standing props, on the bottom of their cell, behind the gameplay.
	for prop: String in ["book_altar", "statue_a1", "statue_b1", "urn_1", "vein_column_tall"]:
		var texture: Texture2D = load("res://assets/depths/%s.png" % prop)
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = prop.to_pascal_case()
		sprite.texture = texture
		sprite.offset = Vector2(0.0, -texture.get_height() / 2.0 + 1.0)
		sprite.z_index = -3
		_save_scene(sprite, "res://entities/prop/depths/%s.tscn" % prop)


## The Grave Warden (import_warden_assets.py): his animations on 96x96 cells (body
## at x 52, feet at y 64, facing right), his Dark-Bolt and the blood creature he
## summons. Both of those are played by the frost spikes' script: warn, then hurt.
func _build_warden_resources() -> void:
	# animation -> [frame count in its sheet, first frame used, frames used, fps, loops]
	var specs: Dictionary[String, Array] = {
		"idle": [50, 0, 50, 12.0, true],
		"walk": [10, 0, 10, 10.0, true],
		# Attack: 8-30 he lifts the skull and it glows, 31-32 he thrusts it down
		# (the bolts strike), 33-36 he lowers it again.
		"cast": [47, 8, 29, 14.0, false],
		# Spawn: 9-14 he conjures at his feet (the creature itself is cut out).
		"summon": [20, 0, 20, 12.0, false],
		# GetHit with its ghost: he reels away, the blink.
		"blink": [9, 0, 9, 14.0, false],
		# Death: he crumbles into a skeleton, then a pile of bones.
		"death": [52, 0, 52, 14.0, false],
	}
	var warden: SpriteFrames = SpriteFrames.new()
	warden.remove_animation(&"default")
	for animation: String in specs:
		var spec: Array = specs[animation]
		var cells: Array[Texture2D] = _grid(load("res://assets/warden/warden_%s.png" % animation),
				spec[0], Vector2(96, 96))
		_add_animation(warden, StringName(animation),
				_frames_between(cells, spec[1], spec[1] + spec[2]), spec[3], spec[4])
	_save(warden, "res://entities/boss/grave_warden_frames.tres")

	# The Dark-Bolt (19 of 64x88): 0-7 a mark opens on the ground and 8-11 the bolt
	# falls onto it (the warning, one second), 12-15 it bursts, 16-18 it fades.
	var bolt: Array[Texture2D] = _row(load("res://assets/warden/dark_bolt.png"), 0, 19,
			Vector2(64, 88))
	var strike: SpriteFrames = SpriteFrames.new()
	strike.remove_animation(&"default")
	_add_animation(strike, &"warn", _frames_between(bolt, 0, 12), 12.0, false)
	_add_animation(strike, &"burst", _frames_between(bolt, 12, 16), 14.0, false)
	_add_animation(strike, &"sink", _frames_between(bolt, 16, 19), 12.0, false)
	_save(strike, "res://entities/hazard/dark_bolt_frames.tres")

	# The blood creature (10 of 48x64): 0-3 a blob wells up (the warning), 4-7 it
	# rears up (it hurts), 8-9 it dissolves.
	var creature: Array[Texture2D] = _row(load("res://assets/warden/blood_spawn.png"), 0, 10,
			Vector2(48, 64))
	var rise: SpriteFrames = SpriteFrames.new()
	rise.remove_animation(&"default")
	_add_animation(rise, &"warn", _frames_between(creature, 0, 4), 4.0, false)
	_add_animation(rise, &"burst", _frames_between(creature, 4, 8), 10.0, false)
	_add_animation(rise, &"sink", _frames_between(creature, 8, 10), 10.0, false)
	_save(rise, "res://entities/hazard/blood_spawn_frames.tres")

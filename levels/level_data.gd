class_name LevelData
extends Resource
## Metadata for one chapter. Save one .tres per chapter next to its map file,
## then add it to GameManager.LEVELS.

## Chapter heading shown on the intro card and in the HUD, e.g. "Chapter One".
@export var title: String = ""
## Place name shown under the heading, e.g. "The Village".
@export var subtitle: String = ""
## Countdown line on the intro card, e.g. "Twelve nights remain".
@export var night_text: String = ""
## ASCII map read by LevelLoader. Plain .txt files are not exported by
## default: add *.txt to the export preset's non-resource filter.
@export_file("*.txt") var map_path: String = ""
## Every conversation in the chapter (see DialogueScript for the format).
@export_file("*.txt") var dialogue_path: String = ""
## Scene played after the chapter ends (a past-life memory, say). It calls
## GameManager.finish_outro() when it's done. Optional.
@export_file("*.tscn") var outro_scene: String = ""
## The chapter opens with Mariane asleep; she gets up when the first
## conversation ends (Chapter One: Grandpa Tomas wakes her).
@export var hero_starts_asleep: bool = false
## Screen clear color behind the tiles and background.
@export var background_color: Color = Color(0.11, 0.12, 0.2)

@export_group("Look")
## Tiles for this chapter. Its tile size sets the map's cell size.
@export var tile_set: TileSet
## Terrain inside terrain set 0 that "#" paints (0 grass, 1 autumn, 2 snow).
@export var terrain: int = 0
## Parallax background scene instanced behind the level. Optional.
@export var background_scene: PackedScene
## From this map column on, "#" paints `terrain_after_switch` instead: the
## season changes. -1 means never. Put it where no ground touches across it
## (a chasm), or the two terrains meet with an edge.
@export var terrain_switch_column: int = -1
@export var terrain_after_switch: int = 2

@export_group("Sound")
## What her footsteps sound like on this chapter's ground. Planks are always
## wood. The sounds are in assets/audio/steps/.
@export_enum("dirt", "gravel", "snow", "wood", "tiles", "water") var step_surface: String = "dirt"
## The ground's sound from terrain_switch_column on (snow after the river).
@export_enum("dirt", "gravel", "snow", "wood", "tiles", "water") var step_surface_after_switch: String = "snow"

@export_group("Map symbols")
## Map characters that mean something else in this chapter. They replace
## the spawn_table entries on level.tscn, e.g. "B": skeleton.tscn.
@export var spawn_overrides: Dictionary[String, PackedScene] = {}

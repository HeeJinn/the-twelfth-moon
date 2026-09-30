class_name LevelLoader
extends Node2D
## Builds a chapter at runtime from an ASCII map (script on the root of level.tscn).
##
## "#" cells are painted in one set_cells_terrain_connect() call so the terrain
## autotiles (or two, when the chapter's season changes part way), "=" cells
## get a single one-way platform tile, "P" spawns the player and any
## character in spawn_table (or the chapter's spawn_overrides) spawns that
## scene. Spawned scenes
## are placed at the bottom-center of their cell, so every entity scene keeps
## its origin at its feet.
##
## The level also owns respawning: when the player dies she wakes up at the
## last campfire she lit (or the start) with full health, and nothing she
## collected is lost. Lighting a campfire makes her stop and rest there.
##
## Scene: Level (Node2D, this script)
##   %TerrainLayer   TileMapLayer (TileSet comes from the LevelData)
##   %PlatformLayer  TileMapLayer (same TileSet, one-way tile)
##   %Entities       Node2D, spawned scenes go here
##   HUD             instance of hud.tscn
##   %DialogueBox    instance of dialogue_box.tscn, given the chapter's script
## All three Node2D children must stay at position (0, 0).

## Extra pixels below the map before a falling player dies.
const FALL_MARGIN: float = 32.0
## Seconds between dying and the fade to the respawn.
const RESPAWN_DELAY: float = 1.2

## Leave empty in the real game. Set it to run level.tscn directly (F6).
@export var level_data_override: LevelData
@export var player_scene: PackedScene
## One map character -> the scene it spawns, e.g. "C": collectible.tscn.
@export var spawn_table: Dictionary[String, PackedScene] = {}

@export_group("Tiles")
@export var terrain_set: int = 0
## Atlas source with the one-way platform tile(s). With four tiles in a row
## (left end, middle, right end, single) the ends are picked automatically;
## with one tile, that tile is used everywhere.
@export var platform_source_id: int = 1
## Map character that is a platform with a ladder running through it (the
## top of a vine), spawned from spawn_table["|"].
@export var ladder_platform_symbol: String = "H"

var player: Player
var collectibles_total: int = 0
## Map size in pixels, available after build().
var bounds: Rect2 = Rect2()

var _terrain: int = 0
var _terrain_after_switch: int = 0
var _switch_column: int = -1
## spawn_table with the chapter's own symbols on top.
var _symbols: Dictionary[String, PackedScene] = {}
var _respawn_position: Vector2 = Vector2.ZERO

@onready var _terrain_layer: TileMapLayer = %TerrainLayer
@onready var _platform_layer: TileMapLayer = %PlatformLayer
@onready var _entities: Node2D = %Entities
@onready var _dialogue_box: DialogueBox = %DialogueBox


func _ready() -> void:
	var level_data: LevelData = level_data_override
	if level_data == null:
		level_data = GameManager.get_current_level()

	var map_text: String = FileAccess.get_file_as_string(level_data.map_path)
	if map_text.is_empty():
		push_error("Cannot read map '%s' (%s). In an exported build, add *.txt to the "
				% [level_data.map_path, error_string(FileAccess.get_open_error())]
				+ "export preset's non-resource filter.")
		return

	RenderingServer.set_default_clear_color(level_data.background_color)
	_terrain_layer.tile_set = level_data.tile_set
	_platform_layer.tile_set = level_data.tile_set
	_terrain = level_data.terrain
	_switch_column = level_data.terrain_switch_column
	_terrain_after_switch = level_data.terrain_after_switch
	_symbols = spawn_table.duplicate()
	_symbols.merge(level_data.spawn_overrides, true)
	if not level_data.dialogue_path.is_empty():
		_dialogue_box.load_script(level_data.dialogue_path)
	if level_data.background_scene:
		var background: Node = level_data.background_scene.instantiate()
		add_child(background)
		move_child(background, 0)
	build(map_text)
	if level_data.hero_starts_asleep and player != null:
		player.fall_asleep()
	EventBus.level_started.emit(level_data, collectibles_total)


## Clears the level and rebuilds it from map text.
func build(map_text: String) -> void:
	_clear()
	if _symbols.is_empty():
		_symbols = spawn_table.duplicate()
	var rows: PackedStringArray = map_text.replace("\r", "").strip_edges(false, true).split("\n")
	var solid_cells: Array[Vector2i] = []
	var width: int = 0

	for y: int in rows.size():
		var row: String = rows[y]
		width = maxi(width, row.length())
		for x: int in row.length():
			var cell: Vector2i = Vector2i(x, y)
			var symbol: String = row[x]
			if symbol == ladder_platform_symbol:
				_place_platform(row, x, y)
				_spawn(_symbols["|"], cell)
				continue
			match symbol:
				".", " ":
					pass
				"#":
					solid_cells.append(cell)
				"=":
					_place_platform(row, x, y)
				"P":
					_spawn_player(cell)
				_:
					if _symbols.has(symbol):
						_spawn(_symbols[symbol], cell)
					else:
						push_warning("Unknown map character '%s' at %s." % [symbol, cell])

	solid_cells.append_array(_edge_padding(solid_cells, width, rows.size()))
	# One batched call per terrain: terrain matching looks at neighbors, so
	# painting cells one at a time gives worse edges and is slower.
	var before: Array[Vector2i] = []
	var after: Array[Vector2i] = []
	for cell: Vector2i in solid_cells:
		if _switch_column >= 0 and cell.x >= _switch_column:
			after.append(cell)
		else:
			before.append(cell)
	_terrain_layer.set_cells_terrain_connect(before, terrain_set, _terrain)
	if not after.is_empty():
		_terrain_layer.set_cells_terrain_connect(after, terrain_set, _terrain_after_switch)

	var tile_size: Vector2 = Vector2(_terrain_layer.tile_set.tile_size)
	bounds = Rect2(Vector2.ZERO, Vector2(width, rows.size()) * tile_size)
	_add_side_walls()
	if player == null:
		push_error("Map has no player start 'P'.")
		return
	_respawn_position = player.global_position
	player.fall_limit_y = bounds.end.y + FALL_MARGIN
	player.set_camera_limits(bounds)
	player.died.connect(_on_player_died)


func _clear() -> void:
	_terrain_layer.clear()
	_platform_layer.clear()
	for child: Node in _entities.get_children():
		child.queue_free()
	player = null
	collectibles_total = 0


func _spawn_player(cell: Vector2i) -> void:
	if player != null:
		push_warning("Map has more than one 'P'; using the first.")
		return
	player = _spawn(player_scene, cell) as Player


func _spawn(scene: PackedScene, cell: Vector2i) -> Node2D:
	var node: Node2D = scene.instantiate() as Node2D
	# map_to_local() is the cell center; shift down half a tile to its floor.
	var half_tile: float = _terrain_layer.tile_set.tile_size.y / 2.0
	node.position = _terrain_layer.map_to_local(cell) + Vector2(0.0, half_tile)
	_entities.add_child(node)
	if node is Collectible:
		collectibles_total += 1
	elif node is Checkpoint:
		var checkpoint: Checkpoint = node
		checkpoint.activated.connect(_on_checkpoint_activated)
	return node


## One-way platform cell, with end caps when the platform source has them.
func _place_platform(row: String, x: int, y: int) -> void:
	var source: TileSetAtlasSource = _platform_layer.tile_set.get_source(platform_source_id)
	var coords: Vector2i = Vector2i.ZERO
	if source.has_tile(Vector2i(3, 0)):
		var platform_symbols: String = "=" + ladder_platform_symbol
		var left: bool = x > 0 and platform_symbols.contains(row[x - 1])
		var right: bool = x < row.length() - 1 and platform_symbols.contains(row[x + 1])
		if left and right:
			coords = Vector2i(1, 0)
		elif right:
			coords = Vector2i(0, 0)
		elif left:
			coords = Vector2i(2, 0)
		else:
			coords = Vector2i(3, 0)
	_platform_layer.set_cell(Vector2i(x, y), platform_source_id, coords)


## Solid cells just outside the map's left, right and bottom edges. The
## camera never shows them, but they make the visible edge cells autotile as
## ground that continues off screen instead of a rounded cliff edge.
func _edge_padding(solid_cells: Array[Vector2i], width: int, height: int) -> Array[Vector2i]:
	var padding: Array[Vector2i] = []
	for cell: Vector2i in solid_cells:
		var at_left: bool = cell.x == 0
		var at_right: bool = cell.x == width - 1
		var at_bottom: bool = cell.y == height - 1
		if at_bottom:
			padding.append(cell + Vector2i.DOWN)
		if at_left:
			padding.append(cell + Vector2i.LEFT)
		if at_right:
			padding.append(cell + Vector2i.RIGHT)
		if at_left and at_bottom:
			padding.append(cell + Vector2i(-1, 1))
		if at_right and at_bottom:
			padding.append(cell + Vector2i(1, 1))
	return padding


## Invisible walls at the map's left and right edges.
func _add_side_walls() -> void:
	var walls: StaticBody2D = StaticBody2D.new()
	walls.name = "SideWalls"
	walls.collision_layer = 1
	walls.collision_mask = 0
	for side: int in [-1, 1]:
		var shape: CollisionShape2D = CollisionShape2D.new()
		var boundary: WorldBoundaryShape2D = WorldBoundaryShape2D.new()
		boundary.normal = Vector2(-side, 0.0)
		shape.shape = boundary
		shape.position = Vector2(bounds.position.x if side < 0 else bounds.end.x, 0.0)
		walls.add_child(shape)
	_entities.add_child(walls)


func _on_checkpoint_activated(checkpoint: Checkpoint) -> void:
	_respawn_position = checkpoint.get_respawn_position()
	if player != null:
		player.rest()


func _on_player_died() -> void:
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	if not is_inside_tree() or player == null:
		return
	await SceneManager.fade_out()
	if is_inside_tree() and player != null:
		player.respawn(_respawn_position, true)
	await SceneManager.fade_in()

extends Node
## The music: one track at a time, cross-faded, from assets/music/<name>.ogg
## (or .mp3, or .wav: a WAV is compressed and set to loop in its import
## settings). A track that isn't there yet falls back to a related one (see
## FALLBACKS) or is silence, so the game runs the same before and after the
## files are added. It keeps playing while the game is paused; the M key mutes
## it with everything else (it plays on its own bus, sent to Master).
##
## Who asks for what:
##   title screen "title"; the prologue and every memory "memory"; each chapter
##   its LevelData.music, and LevelData.music_after_switch from the chapter's
##   terrain_switch_column on (Chapter Three's snow, Chapter Four's undercroft);
##   the Moon Witch, the Shield Knight and the Grave Warden "boss" while their
##   fight lasts; Kael "kael_theme" when he appears, "kael_sword" in the fight,
##   "kael_fire" from half health, "reveal" when he kneels; the end screen
##   "credits". The full list, with what each should sound like, is in the plan.
##
##   Music.play(name, fade)   Music.stop(fade)   Music.current (the name asked for)

const FOLDER: String = "res://assets/music/"
const EXTENSIONS: Array[String] = ["ogg", "mp3", "wav"]
const BUS: StringName = &"Music"
## Music sits under the voices and footsteps.
const VOLUME_DB: float = -8.0
const SILENT_DB: float = -60.0
const FADE: float = 1.5
## Tracks that play once instead of looping.
const ONCE: Array[StringName] = [&"reveal", &"ending"]
## A missing track plays this one instead (and that one's, in turn).
const FALLBACKS: Dictionary[StringName, StringName] = {
	&"winter_pass": &"long_road",
	&"undercroft": &"ember_keep",
	&"kael_fire": &"kael_sword",
	&"kael_sword": &"boss",
	&"kael_theme": &"rooftop",
	&"after_credits": &"title",
	&"ending": &"credits",
	&"credits": &"title",
}
## Bosses (by the name on their health bar) with a track of their own.
const BOSS_TRACKS: Dictionary[String, StringName] = {
	"The Ember Knight": &"kael_sword",
}
## How often the chapter's track is checked against where she is, in seconds.
const CHECK_TIME: float = 0.5
## Per-file level trims (dB) that bring each track to about -20 dBFS RMS, measured
## with tools/tests/music_levels.tscn (the two gentle pieces sit a little lower).
## Re-measure when a track changes.
const TRIM_DB: Dictionary[String, float] = {
	"boss": -3.3,
	"ember_keep": 0.3,
	"lantern_forest": -3.0,
	"long_road": -6.3,
	"memory": 3.7,
	"reveal": 1.3,
	"rooftop": -4.8,
	"title": -3.4,
	"village": -0.2,
	"winter_pass": -2.2,
	"undercroft": 3.0,
	"kael_theme": 1.0,
	"kael_fire": -7.6,
	"ending": -5.3,
	"after_credits": 8.0,
}

## The track last asked for (even if its file is missing).
var current: StringName = &""
## Where the tracks are looked for (tests point it elsewhere).
var folder: String = FOLDER

var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _fades: Array[Tween] = [null, null]
var _level_track: StringName = &""
var _after_switch_track: StringName = &""
var _switch_x: float = INF
var _in_boss_fight: bool = false
var _check_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Declared in default_bus_layout.tres (a bus added from code is silent on the
	# web); this is only a fallback.
	if AudioServer.get_bus_index(BUS) < 0:
		AudioServer.add_bus()
		var index: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, BUS)
		AudioServer.set_bus_send(index, &"Master")
	for i: int in 2:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = BUS
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)
	EventBus.level_started.connect(_on_level_started)
	EventBus.boss_started.connect(_on_boss_started)
	EventBus.boss_finished.connect(_on_boss_finished)


func _process(delta: float) -> void:
	if _switch_x == INF or _in_boss_fight:
		return
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = CHECK_TIME
	var hero: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
	if hero != null and current in [_level_track, _after_switch_track]:
		play(_chapter_track_at(hero.global_position.x))


## Cross-fades to `track` (a file name in assets/music without its extension).
func play(track: StringName, fade: float = FADE) -> void:
	if track == current:
		return
	current = track
	var stream: AudioStream = _find(track)
	var playing: AudioStreamPlayer = _players[_active]
	if stream != null and playing.playing and playing.stream == stream:
		return  # A fallback that is already playing: keep it going.
	_fade(_active, SILENT_DB, fade, true)
	if stream == null:
		return
	_active = 1 - _active
	var player: AudioStreamPlayer = _players[_active]
	player.stream = stream
	player.volume_db = SILENT_DB
	player.play()
	_fade(_active, VOLUME_DB + TRIM_DB.get(stream.resource_path.get_file().get_basename(), 0.0),
			fade, false)


## Fades the music out.
func stop(fade: float = FADE) -> void:
	current = &""
	_fade(_active, SILENT_DB, fade, true)


## The stream for `track`, or for its fallback, or null.
func _find(track: StringName) -> AudioStream:
	var name: StringName = track
	for i: int in 4:
		for extension: String in EXTENSIONS:
			var path: String = "%s%s.%s" % [folder, name, extension]
			if ResourceLoader.exists(path):
				var stream: AudioStream = load(path)
				if "loop" in stream:
					stream.set("loop", track not in ONCE)
				return stream
		if not FALLBACKS.has(name):
			break
		name = FALLBACKS[name]
	return null


func _fade(index: int, volume_db: float, seconds: float, then_stop: bool) -> void:
	if _fades[index] != null:
		_fades[index].kill()
	var player: AudioStreamPlayer = _players[index]
	if not player.playing:
		return
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", volume_db, maxf(seconds, 0.01))
	if then_stop:
		tween.tween_callback(player.stop)
	_fades[index] = tween


func _chapter_track_at(x: float) -> StringName:
	if x >= _switch_x and not _after_switch_track.is_empty():
		return _after_switch_track
	return _level_track


func _on_level_started(level_data: LevelData, _collectibles_total: int) -> void:
	_in_boss_fight = false
	_level_track = level_data.music
	_after_switch_track = level_data.music_after_switch
	_switch_x = INF
	if level_data.terrain_switch_column >= 0 and level_data.tile_set != null:
		_switch_x = level_data.terrain_switch_column * float(level_data.tile_set.tile_size.x)
	_check_timer = 0.0
	var hero: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
	play(_chapter_track_at(hero.global_position.x) if hero != null else _level_track)


func _on_boss_started(boss_name: String, _maximum: int) -> void:
	_in_boss_fight = true
	play(BOSS_TRACKS.get(boss_name, &"boss"))


func _on_boss_finished() -> void:
	if not _in_boss_fight:
		return
	_in_boss_fight = false
	var hero: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
	play(_chapter_track_at(hero.global_position.x) if hero != null else _level_track)

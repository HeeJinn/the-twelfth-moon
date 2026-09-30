extends Node
## Sound for the whole game (autoload "Audio"): footsteps by surface, voices
## by bank, and one-off effects. Every call is fire-and-forget. A clip that is
## missing, a muted game or a machine with no sound device is a silent no-op,
## never an error, so tests can run headless.
##
## Clips come from tools/import_audio.py, under res://assets/audio/:
##   steps/<surface>/step_NN.ogg      dirt, gravel, snow, wood, tiles, water
##   voice/<bank>/<group>_NN.wav      banks mariane, karen, alex, sean, ian
## Takes are found by counting up from 01, so adding a file is enough.
##
## Usage:
##   Audio.step(&"dirt")                      one footstep
##   Audio.voice(&"mariane", &"hurt")         one of her hurt takes
##   Audio.voice(&"alex", &"death", 1.0, 1.4) the same bank, pitched up
##   Audio.sfx(stream)                        any stream, on the effects bus
## Each call plays a random take that is never the one it played last, with a
## little pitch and volume jitter. Voices keep quiet for a while after
## speaking (BANK_COOLDOWN, GROUP_COOLDOWNS), so they never spam.
##
## Two buses are made at startup, SFX and Voice, both sent to Master. The M key
## mutes Master; the choice is saved in user://settings.cfg, not in the game save.
## The node keeps running while the game is paused.

## Emitted for every sound that was started (muted or not). `key` looks like
## "step/dirt" or "voice/mariane/hurt"; `take` is the index of the clip.
signal played(key: StringName, take: int)
signal mute_changed(is_muted: bool)

const SFX_BUS: StringName = &"SFX"
const VOICE_BUS: StringName = &"Voice"
const MASTER_BUS: StringName = &"Master"
const SETTINGS_PATH: String = "user://settings.cfg"
const STEP_PATH: String = "res://assets/audio/steps/%s/step_%%02d.ogg"
const VOICE_PATH: String = "res://assets/audio/voice/%s/%s_%%02d.wav"
## Most takes of one sound that get looked for.
const MAX_TAKES: int = 32
const SFX_PLAYERS: int = 6
const VOICE_PLAYERS: int = 3

## What a footstep on planks sounds like, whatever the chapter's ground is.
const PLANK_SURFACE: StringName = &"wood"
## Footsteps sit under the voices.
const STEP_VOLUME_DB: float = -12.0
## Brings every surface to the same loudness: the FreeSteps clips were recorded
## at very different levels. Measured at unity gain (mean RMS of the sounding
## part, dBFS): dirt -34.6, gravel -30.0, snow -27.7, wood -25.8, water -23.5,
## tiles -18.4. With these trims each comes out near -28 (the audio test checks).
const STEP_TRIM_DB: Dictionary[StringName, float] = {
	&"dirt": 6.0,
	&"gravel": 2.0,
	&"snow": 0.0,
	&"wood": -2.0,
	&"water": -5.0,
	&"tiles": -10.0,
}
const STEP_PITCH_JITTER: float = 0.08
const STEP_VOLUME_JITTER_DB: float = 2.0
## Seconds before the same surface can step again (a double trigger is ignored).
const STEP_COOLDOWN: float = 0.1
const VOICE_PITCH_JITTER: float = 0.04
const VOICE_VOLUME_JITTER_DB: float = 1.5
## Seconds a bank stays quiet after it spoke (or until its clip ends).
const BANK_COOLDOWN: float = 0.45
## Extra seconds a group waits before it can play again: effort grunts and
## greetings would be tiresome every time.
const GROUP_COOLDOWNS: Dictionary[StringName, float] = {
	&"grunt": 2.0,
	&"land": 1.0,
	&"hurt": 0.35,
	&"shout": 0.6,
	&"greet": 6.0,
	&"farewell": 6.0,
	&"sigh": 1.0,
	&"gasp": 1.0,
}
## Groups that may speak over their bank's cooldown: a cry of pain after a
## grunt matters more than the grunt. Death also ignores its own cooldown.
const LOUD_GROUPS: Array[StringName] = [&"hurt", &"shout", &"death"]

## Randomness for takes, jitter and chances. Tests can seed it.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Where the mute choice is kept. Tests point this at a scratch file.
var settings_path: String = SETTINGS_PATH
## How many times each sound was started since startup or reset(), by key.
var plays: Dictionary[StringName, int] = {}
## The take each sound played last, by key.
var last_take: Dictionary[StringName, int] = {}
## Key of the sound that started last.
var last_key: StringName = &""

var _is_muted: bool = false
var _surface: StringName = &"dirt"
var _surface_after_switch: StringName = &"snow"
## From this x on (pixels), the ground is _surface_after_switch.
var _switch_x: float = INF
var _takes: Dictionary[StringName, Array] = {}
## Time (seconds since startup) when each bank / group / surface may sound again.
var _ready_at: Dictionary[StringName, float] = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _voice_players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	_make_bus(SFX_BUS)
	_make_bus(VOICE_BUS)
	_sfx_players = _make_players(SFX_BUS, SFX_PLAYERS)
	_voice_players = _make_players(VOICE_BUS, VOICE_PLAYERS)
	_load_settings()
	EventBus.level_started.connect(_on_level_started)


## Lets go of every clip when the game closes, so one still playing at that
## moment is not reported as a leak.
func _exit_tree() -> void:
	for player: AudioStreamPlayer in _sfx_players:
		player.stop()
		player.stream = null
	for player: AudioStreamPlayer in _voice_players:
		player.stop()
		player.stream = null
	_takes.clear()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mute") and not event.is_echo():
		toggle_mute()
		get_viewport().set_input_as_handled()


# --- Playing ---------------------------------------------------------------

## A footstep on `surface` (dirt, gravel, snow, wood, tiles or water).
## Returns false when nothing played.
func step(surface: StringName, volume_db: float = 0.0) -> bool:
	var key: StringName = StringName("step/" + surface)
	if _is_waiting(key):
		return false
	var takes: Array = _takes_of(key, STEP_PATH % surface)
	if takes.is_empty():
		return false
	_ready_at[key] = _now() + STEP_COOLDOWN
	var index: int = _pick_take(key, takes.size())
	var trim_db: float = STEP_TRIM_DB.get(surface, 0.0)
	_start(_sfx_players, takes[index] as AudioStream, key, index,
			volume_db + STEP_VOLUME_DB + trim_db + _jitter(STEP_VOLUME_JITTER_DB),
			1.0 + _jitter(STEP_PITCH_JITTER))
	return true


## One take of `group` from `bank` (see the folder list above). `chance` is the
## odds it speaks at all (a missed roll costs no cooldown); `pitch` and
## `volume_db` reshape the voice, e.g. a goblin is a man's cry pitched up.
## Returns false when it stayed quiet: the roll missed, the bank or group is
## still cooling down, or the clip is missing.
func voice(bank: StringName, group: StringName, chance: float = 1.0,
		pitch: float = 1.0, volume_db: float = 0.0) -> bool:
	var bank_key: StringName = StringName("bank/" + bank)
	var group_key: StringName = StringName("group/%s/%s" % [bank, group])
	var is_death: bool = group == &"death"
	if not is_death and (_is_waiting(group_key)
			or (not group in LOUD_GROUPS and _is_waiting(bank_key))):
		return false
	if chance < 1.0 and rng.randf() >= chance:
		return false
	var key: StringName = StringName("voice/%s/%s" % [bank, group])
	var takes: Array = _takes_of(key, VOICE_PATH % [bank, group])
	if takes.is_empty():
		return false
	var index: int = _pick_take(key, takes.size())
	var stream: AudioStream = takes[index] as AudioStream
	var scale: float = pitch * (1.0 + _jitter(VOICE_PITCH_JITTER))
	var now: float = _now()
	_ready_at[bank_key] = now + maxf(BANK_COOLDOWN, stream.get_length() / scale)
	var group_cooldown: float = GROUP_COOLDOWNS.get(group, 0.0)
	_ready_at[group_key] = now + group_cooldown
	_start(_voice_players, stream, key, index,
			volume_db + _jitter(VOICE_VOLUME_JITTER_DB), scale)
	return true


## Any stream on the effects bus (there are no effect clips yet; this is the
## way in for the next ones). Returns false for a null stream.
func sfx(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> bool:
	if stream == null:
		return false
	_start(_sfx_players, stream, &"sfx", 0, volume_db, pitch)
	return true


## Forgets every cooldown, so the next call plays (tests, scene starts).
func reset_cooldowns() -> void:
	_ready_at.clear()


## Forgets the cooldowns, the last takes and the play counters.
func reset() -> void:
	reset_cooldowns()
	plays.clear()
	last_take.clear()
	last_key = &""


## How many times `key` ("step/dirt", "voice/mariane/hurt") has played.
func play_count(key: StringName) -> int:
	return plays.get(key, 0)


## Every voice and step that has been loaded or looked for is cached; this
## loads one set now, so the first real call never waits on the disk.
func preload_takes(key: StringName) -> int:
	var parts: PackedStringArray = String(key).split("/")
	if parts[0] == "step" and parts.size() == 2:
		return _takes_of(key, STEP_PATH % parts[1]).size()
	if parts[0] == "voice" and parts.size() == 3:
		return _takes_of(key, VOICE_PATH % [parts[1], parts[2]]).size()
	return 0


## Loads the clips of each of `groups` of `bank` now (see preload_takes).
func preload_voice(bank: StringName, groups: Array[StringName]) -> void:
	for group: StringName in groups:
		preload_takes(StringName("voice/%s/%s" % [bank, group]))


## True while any sound is still sounding. Quitting in the middle of one is
## reported as a leak on exit, so tests wait for silence first.
func is_busy() -> bool:
	for player: AudioStreamPlayer in _sfx_players + _voice_players:
		if player.playing:
			return true
	return false


# --- Surfaces --------------------------------------------------------------

## Takes the chapter's ground sounds from its LevelData. Called when a level
## starts; tests call it to try a chapter without building it.
func use_level(level_data: LevelData) -> void:
	_surface = StringName(level_data.step_surface)
	_surface_after_switch = StringName(level_data.step_surface_after_switch)
	var tile_width: float = 32.0
	if level_data.tile_set != null:
		tile_width = float(level_data.tile_set.tile_size.x)
	_switch_x = level_data.terrain_switch_column * tile_width \
			if level_data.terrain_switch_column >= 0 else INF
	# Load the footsteps now, so the first step on each ground never waits on the disk.
	var surfaces: Array[StringName] = [_surface, PLANK_SURFACE]
	if _switch_x != INF:
		surfaces.append(_surface_after_switch)
	for surface: StringName in surfaces:
		preload_takes(StringName("step/" + surface))


## The surface under feet at world x: planks are wood, anything else is the
## chapter's ground (which changes at its terrain_switch_column).
func surface_at(x: float, on_planks: bool = false) -> StringName:
	if on_planks:
		return PLANK_SURFACE
	return _surface_after_switch if x >= _switch_x else _surface


# --- Mute ------------------------------------------------------------------

func is_muted() -> bool:
	return _is_muted


func toggle_mute() -> void:
	set_muted(not _is_muted)


## Mutes or unmutes everything (the Master bus) and remembers the choice.
func set_muted(muted: bool) -> void:
	_is_muted = muted
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MASTER_BUS), muted)
	_save_settings()
	mute_changed.emit(muted)


# --- Internals -------------------------------------------------------------

func _on_level_started(level_data: LevelData, _collectibles_total: int) -> void:
	use_level(level_data)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _is_waiting(key: StringName) -> bool:
	var until: float = _ready_at.get(key, 0.0)
	return _now() < until


func _jitter(amount: float) -> float:
	return rng.randf_range(-amount, amount)


## Loads (once) the numbered takes of `path_pattern` ("...%02d.ogg").
func _takes_of(key: StringName, path_pattern: String) -> Array:
	if _takes.has(key):
		return _takes[key]
	var takes: Array = []
	for number: int in range(1, MAX_TAKES + 1):
		var path: String = path_pattern % number
		if not ResourceLoader.exists(path):
			break
		var stream: AudioStream = load(path) as AudioStream
		if stream == null:
			break
		takes.append(stream)
	_takes[key] = takes
	return takes


## A random take that is not the one played last (unless there is only one).
func _pick_take(key: StringName, count: int) -> int:
	var last: int = last_take.get(key, -1)
	var index: int = rng.randi_range(0, count - 1)
	if count > 1 and last >= 0:
		index = rng.randi_range(0, count - 2)
		if index >= last:
			index += 1
	last_take[key] = index
	return index


func _start(pool: Array[AudioStreamPlayer], stream: AudioStream, key: StringName,
		take: int, volume_db: float, pitch: float) -> void:
	plays[key] = play_count(key) + 1
	last_key = key
	var player: AudioStreamPlayer = _free_player(pool)
	if player != null:
		player.stream = stream
		player.volume_db = volume_db
		player.pitch_scale = pitch
		player.play()
	played.emit(key, take)


## An idle player, or else the one that has been playing the longest.
func _free_player(pool: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	if pool.is_empty():
		return null
	var oldest: AudioStreamPlayer = pool[0]
	for player: AudioStreamPlayer in pool:
		if not player.playing:
			return player
		if player.get_playback_position() > oldest.get_playback_position():
			oldest = player
	return oldest


func _make_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, MASTER_BUS)


func _make_players(bus_name: StringName, count: int) -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	for i: int in count:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = bus_name
		add_child(player)
		players.append(player)
	return players


func _load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	_is_muted = bool(config.get_value("audio", "muted", false))
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MASTER_BUS), _is_muted)


func _save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(settings_path)  # Keep whatever else is in there.
	config.set_value("audio", "muted", _is_muted)
	var error: Error = config.save(settings_path)
	if error != OK:
		push_warning("Audio: cannot save '%s' (%s)." % [settings_path, error_string(error)])

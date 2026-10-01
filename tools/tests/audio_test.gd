extends Node
## Headless check of the sound: every shipped clip loads, the Audio API plays a
## random take that is never the same twice, keeps its cooldowns and stays
## silent when a clip is missing, the footstep surface per chapter and on
## planks, every surface's footsteps equally loud (played through a capture
## effect), clips loaded ahead of need, the M-key mute and its settings file (a
## scratch one), and the real
## gameplay hooks: her steps on the run's foot-down frames (and none while she
## slides, dashes or crouches), landing, hurt, swings, Moon Slash and Moon
## Spark shouts, death, waking and resting, villagers' hellos and goodbyes,
## goblin and mushroom cries, silent skeletons and eyes, and both bosses.
##
## Runs on a small test course (tools/tests/maps/moves_test.txt) with the real
## Player. The dummy audio driver is fine: the checks read Audio's counters.
##
## Run from the project folder:
##   godot --headless --path . res://tools/tests/audio_test.tscn

const LEVEL_SCENE: PackedScene = preload("res://levels/level.tscn")
const GOBLIN_SCENE: PackedScene = preload("res://entities/enemy/goblin.tscn")
const MUSHROOM_SCENE: PackedScene = preload("res://entities/enemy/mushroom.tscn")
const SKELETON_SCENE: PackedScene = preload("res://entities/enemy/skeleton.tscn")
const EYE_SCENE: PackedScene = preload("res://entities/enemy/flying_eye.tscn")
const KNIGHT_SCENE: PackedScene = preload("res://entities/boss/shield_knight.tscn")
const WITCH_SCENE: PackedScene = preload("res://entities/boss/moon_witch.tscn")
const TEST_MAP: LevelData = preload("res://tools/tests/maps/moves_test.tres")
const CHAPTER_ONE: LevelData = preload("res://levels/maps/chapter_01.tres")
const CHAPTER_TWO: LevelData = preload("res://levels/maps/chapter_02.tres")
const CHAPTER_THREE: LevelData = preload("res://levels/maps/chapter_03.tres")
const SPEAKERS: SpeakerLibrary = preload("res://story/speakers.tres")
const AUDIO_DIR: String = "res://assets/audio"
const SCRATCH_SETTINGS: String = "user://test_settings.cfg"
const TILE: float = 16.0
const FLOOR_Y: float = 22.0 * TILE
## The shipped audio stays about this small (bytes).
const SIZE_LIMIT: int = 6_000_000
## Footsteps on every ground, after their trims, stay within this many dB.
const STEP_LEVEL_SPREAD_DB: float = 3.0
## Samples quieter than this (linear) are silence when measuring a clip.
const SILENCE: float = 0.003

## Every voice group the game asks for, by bank, and every footstep surface.
const VOICES: Dictionary[StringName, Array] = {
	&"mariane": [&"grunt", &"land", &"hurt", &"death", &"shout", &"sigh", &"gasp"],
	&"karen": [&"greet", &"farewell", &"hurt", &"shout", &"death"],
	&"alex": [&"greet", &"farewell", &"hurt", &"death"],
	&"sean": [&"greet", &"farewell"],
	&"ian": [&"shout", &"hurt", &"grunt", &"death"],
}
const SURFACES: Array[StringName] = [&"dirt", &"gravel", &"snow", &"wood", &"tiles", &"water"]
## Speaker name -> voice bank, for everyone who has a voice.
const SPEAKER_BANKS: Dictionary[String, StringName] = {
	"Mariane": &"mariane", "Kael": &"ian", "Knight": &"ian", "Witch": &"karen",
	"Tomas": &"sean", "Pell": &"sean",
	"Rosa": &"karen", "Lina": &"karen", "Mara": &"karen", "Wren": &"karen", "Hild": &"karen",
	"Joss": &"alex", "Bram": &"alex", "Theo": &"alex",
}
## Of those, the ones who say hello and goodbye.
const GREETERS: Array[String] = [
	"Tomas", "Pell", "Rosa", "Lina", "Mara", "Wren", "Hild", "Joss", "Bram", "Theo",
]

var _failures: int = 0
var _level: LevelLoader
var _player: Player
## Every sound started while a check listens: [key, animation, frame].
var _heard: Array[Array] = []
var _dialogue_open: bool = false


func _ready() -> void:
	GameManager.save_path = "user://test_save.cfg"
	_check_files()
	_check_buses_and_input()
	await _check_api()
	_check_surfaces()
	await _check_step_levels()
	await _check_mute()
	_level = LEVEL_SCENE.instantiate() as LevelLoader
	_level.level_data_override = TEST_MAP
	add_child(_level)
	await _frames(20)
	_player = _level.player
	_player.stats.swing_grunt_chance = 0.0  # Quiet unless a check asks for grunts.
	EventBus.dialogue_started.connect(func(_id: String) -> void: _dialogue_open = true)
	EventBus.dialogue_finished.connect(func(_id: String) -> void: _dialogue_open = false)
	await _check_loading_ahead()
	await _check_footsteps()
	await _check_quiet_moves()
	await _check_landing()
	await _check_hurt_and_swings()
	await _check_spells()
	await _check_rest()
	await _check_monsters()
	await _check_dialogue()
	await _check_shield_knight()
	await _check_moon_witch()
	await _check_death_and_waking()
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(_failures)


# --- The files ------------------------------------------------------------

func _check_files() -> void:
	var paths: Array[String] = []
	_collect_clips(AUDIO_DIR, paths)
	var unloadable: int = 0
	var bytes: int = 0
	for path: String in paths:
		if not load(path) is AudioStream:
			unloadable += 1
			print("  does not load: ", path)
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file != null:
			bytes += file.get_length()
	print("  %d clips, %.2f MB" % [paths.size(), bytes / 1e6])
	_expect(paths.size() >= 100 and unloadable == 0, "every audio file loads as an AudioStream")
	_expect(bytes <= SIZE_LIMIT, "the shipped audio stays under about six megabytes")

	var missing: Array[String] = []
	for bank: StringName in VOICES:
		for group: StringName in VOICES[bank]:
			if Audio.preload_takes(StringName("voice/%s/%s" % [bank, group])) == 0:
				missing.append("%s/%s" % [bank, group])
	for surface: StringName in SURFACES:
		if Audio.preload_takes(StringName("step/" + surface)) < 4:
			missing.append("steps/" + surface)
	print("  missing or thin: ", missing)
	_expect(missing.is_empty(), "every voice group and surface the game asks for has clips")

	var credits: String = FileAccess.get_file_as_string(AUDIO_DIR + "/CREDITS.txt")
	_expect("Dillon Becker" in credits and "CC BY 4.0" in credits
			and "trimmed, level-matched, resampled, mono" in credits,
			"the audio credits name the voices' author, licence and changes")
	_expect("FreeSteps" in credits and "confirm" in credits,
			"the credits flag the footsteps' unknown author")

	var wrong: Array[String] = []
	for speaker_name: String in SPEAKER_BANKS:
		var speaker: Speaker = SPEAKERS.find(speaker_name)
		if speaker == null or speaker.voice_bank != SPEAKER_BANKS[speaker_name] \
				or speaker.greets != (speaker_name in GREETERS):
			wrong.append(speaker_name)
	for speaker_name: String in ["Her", "Him"]:
		var speaker: Speaker = SPEAKERS.find(speaker_name)
		if speaker == null or not speaker.voice_bank.is_empty() or speaker.greets:
			wrong.append(speaker_name)
	print("  speakers with the wrong voice: ", wrong)
	_expect(wrong.is_empty(), "each speaker has the right male or female bank; only villagers greet")


func _collect_clips(path: String, found: Array[String]) -> void:
	for file: String in DirAccess.get_files_at(path):
		if file.ends_with(".wav") or file.ends_with(".ogg"):
			found.append(path.path_join(file))
	for folder: String in DirAccess.get_directories_at(path):
		_collect_clips(path.path_join(folder), found)


func _check_buses_and_input() -> void:
	var sfx: int = AudioServer.get_bus_index(Audio.SFX_BUS)
	var voice: int = AudioServer.get_bus_index(Audio.VOICE_BUS)
	_expect(sfx != -1 and voice != -1, "the SFX and Voice buses exist")
	_expect(sfx != -1 and AudioServer.get_bus_send(sfx) == Audio.MASTER_BUS
			and voice != -1 and AudioServer.get_bus_send(voice) == Audio.MASTER_BUS,
			"both buses feed the Master bus")
	_expect(Audio.process_mode == Node.PROCESS_MODE_ALWAYS, "Audio keeps working while the game is paused")
	var has_m: bool = false
	for event: InputEvent in InputMap.action_get_events("mute"):
		var key: InputEventKey = event as InputEventKey
		if key != null and key.physical_keycode == KEY_M:
			has_m = true
	_expect(InputMap.has_action("mute") and has_m, "the M key is the mute action")


# --- The API ----------------------------------------------------------------

func _check_api() -> void:
	Audio.reset()
	_expect(Audio.step(&"dirt"), "a footstep plays")
	_expect(Audio.play_count(&"step/dirt") == 1 and Audio.last_key == &"step/dirt",
			"the play is counted")
	_expect(not Audio.step(&"dirt") and Audio.play_count(&"step/dirt") == 1,
			"a step right after a step is ignored (cooldown)")

	# Never the same take twice in a row, yet not always the same one.
	Audio.reset()
	var takes: Array[int] = []
	var record: Callable = func(_key: StringName, take: int) -> void: takes.append(take)
	Audio.played.connect(record)
	for i: int in 60:
		Audio.reset_cooldowns()
		Audio.step(&"gravel")
	var repeats: int = 0
	for i: int in range(1, takes.size()):
		if takes[i] == takes[i - 1]:
			repeats += 1
	_expect(takes.size() == 60 and repeats == 0 and takes.any(func(t: int) -> bool: return t != takes[0]),
			"60 steps in a row: random takes, never the same twice")
	takes.clear()
	for i: int in 40:
		Audio.reset_cooldowns()
		Audio.voice(&"mariane", &"hurt")
	repeats = 0
	for i: int in range(1, takes.size()):
		if takes[i] == takes[i - 1]:
			repeats += 1
	_expect(takes.size() == 40 and repeats == 0, "voices never repeat a take either")
	Audio.played.disconnect(record)

	# Cooldowns.
	Audio.reset()
	_expect(Audio.voice(&"mariane", &"grunt"), "a grunt plays")
	_expect(not Audio.voice(&"mariane", &"grunt"), "a second grunt right away is held back (group cooldown)")
	_expect(Audio.voice(&"mariane", &"hurt"), "a cry of pain is not held back by the grunt before it")
	_expect(not Audio.voice(&"mariane", &"land"), "a quiet sound right after a voice waits (bank cooldown)")
	_expect(Audio.voice(&"mariane", &"death") and Audio.voice(&"mariane", &"death"),
			"death always plays")
	_expect(Audio.voice(&"sean", &"greet"), "another bank is unaffected")
	Audio.reset_cooldowns()
	_expect(Audio.voice(&"mariane", &"grunt"), "cooldowns end")

	# Chance: a missed roll costs nothing.
	Audio.reset()
	_expect(not Audio.voice(&"mariane", &"hurt", 0.0) and Audio.plays.is_empty(),
			"chance 0 never speaks")
	Audio.rng.seed = 20261012
	var spoke: int = 0
	for i: int in 300:
		Audio.reset_cooldowns()
		if Audio.voice(&"mariane", &"hurt", 0.3):
			spoke += 1
	print("  chance 0.3 spoke %d times in 300" % spoke)
	_expect(spoke > 60 and spoke < 120, "a chance of 0.3 speaks about 30 percent of the time")
	Audio.rng.randomize()

	# Silence, not errors, for what is missing.
	Audio.reset()
	_expect(not Audio.voice(&"nobody", &"hurt") and not Audio.voice(&"mariane", &"yodel")
			and not Audio.step(&"lava") and not Audio.sfx(null) and Audio.plays.is_empty(),
			"a missing clip, bank or surface is a silent no-op")
	var stream: AudioStream = load("res://assets/audio/steps/dirt/step_01.ogg") as AudioStream
	_expect(Audio.sfx(stream) and Audio.play_count(&"sfx") == 1, "any stream can play on the effects bus")
	_expect(Audio.voice(&"alex", &"hurt", 1.0, 1.45), "a voice can be pitched")

	# Works while the game is paused.
	Audio.reset()
	get_tree().paused = true
	var stepped: bool = Audio.step(&"snow")
	get_tree().paused = false
	_expect(stepped, "sounds play while the game is paused")
	Audio.reset()


# --- Surfaces ---------------------------------------------------------------

func _check_surfaces() -> void:
	Audio.use_level(CHAPTER_ONE)
	_expect(Audio.surface_at(10.0) == &"dirt" and Audio.surface_at(9000.0) == &"dirt",
			"Chapter One's village ground is dirt, all along")
	_expect(Audio.surface_at(400.0, true) == &"wood", "planks are wood")
	Audio.use_level(CHAPTER_TWO)
	_expect(Audio.surface_at(500.0) == &"dirt", "Chapter Two's forest floor is dirt")
	Audio.use_level(CHAPTER_THREE)
	var switch_x: float = CHAPTER_THREE.terrain_switch_column \
			* float(CHAPTER_THREE.tile_set.tile_size.x)
	_expect(Audio.surface_at(10.0) == &"dirt" and Audio.surface_at(switch_x - 1.0) == &"dirt",
			"Chapter Three is dirt before the river gap")
	_expect(Audio.surface_at(switch_x) == &"snow" and Audio.surface_at(switch_x + 900.0) == &"snow",
			"and snow from its switch column on")
	_expect(Audio.surface_at(switch_x + 100.0, true) == &"wood"
			and Audio.surface_at(100.0, true) == &"wood",
			"a plank is wood on either side of the switch")
	Audio.use_level(CHAPTER_ONE)


# --- Levels and loading ------------------------------------------------------

## The FreeSteps clips come at wildly different loudness; Audio.STEP_TRIM_DB
## evens them out. Plays every clip into a capture effect (headless, the dummy
## driver still mixes) and checks that each surface ends up equally loud.
func _check_step_levels() -> void:
	AudioServer.add_bus()
	var bus: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, &"LevelMeter")
	AudioServer.set_bus_send(bus, Audio.MASTER_BUS)
	var capture: AudioEffectCapture = AudioEffectCapture.new()
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(bus, capture)
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = &"LevelMeter"
	add_child(player)
	var levels: Dictionary[StringName, float] = {}
	var untrimmed: Array[StringName] = []
	for surface: StringName in SURFACES:
		if not Audio.STEP_TRIM_DB.has(surface):
			untrimmed.append(surface)
		var loudness: float = await _step_loudness(surface, player, capture)
		levels[surface] = loudness + Audio.STEP_TRIM_DB.get(surface, 0.0)
	player.free()
	AudioServer.remove_bus(AudioServer.get_bus_index(&"LevelMeter"))
	var quietest: float = INF
	var loudest: float = -INF
	for surface: StringName in levels:
		quietest = minf(quietest, levels[surface])
		loudest = maxf(loudest, levels[surface])
	print("  footstep loudness after trims (dBFS): ", levels)
	_expect(untrimmed.is_empty(), "every footstep surface has a level trim")
	_expect(levels.size() == SURFACES.size() and loudest - quietest <= STEP_LEVEL_SPREAD_DB,
			"footsteps are about equally loud on every surface")


## Mean loudness (dBFS, RMS of the part that sounds) of a surface's clips at
## unity gain, or -INF when it has none.
func _step_loudness(surface: StringName, player: AudioStreamPlayer,
		capture: AudioEffectCapture) -> float:
	var pattern: String = Audio.STEP_PATH % surface
	var total: float = 0.0
	var clips: int = 0
	for take: int in range(1, Audio.MAX_TAKES + 1):
		if not ResourceLoader.exists(pattern % take):
			break
		var stream: AudioStream = load(pattern % take) as AudioStream
		capture.clear_buffer()
		player.stream = stream
		player.play()
		await get_tree().create_timer(stream.get_length() + 0.1).timeout
		var energy: float = 0.0
		var sounding: int = 0
		for frame: Vector2 in capture.get_buffer(capture.get_frames_available()):
			var sample: float = (frame.x + frame.y) / 2.0
			if absf(sample) > SILENCE:
				energy += sample * sample
				sounding += 1
		if sounding > 0:
			total += linear_to_db(sqrt(energy / sounding))
			clips += 1
	return total / clips if clips > 0 else -INF


## Clips are loaded when a level or a character appears, so the first sound
## never waits on the disk. A second Audio node starts with nothing loaded.
func _check_loading_ahead() -> void:
	var fresh: Node = (load("res://autoloads/audio.gd") as GDScript).new() as Node
	add_child(fresh)
	var cache: Dictionary = fresh.get(&"_takes")
	_expect(cache.is_empty(), "nothing is loaded before it is needed")
	fresh.call(&"use_level", CHAPTER_ONE)
	_expect(cache.has(&"step/dirt") and cache.has(&"step/wood") and not cache.has(&"step/snow"),
			"a level loads its ground's footsteps and the planks', not the other season's")
	fresh.call(&"use_level", CHAPTER_THREE)
	_expect(cache.has(&"step/snow"), "a level with a season change loads the second ground too")
	var cries: Array[StringName] = [&"hurt", &"death"]
	fresh.call(&"preload_voice", &"alex", cries)
	_expect(cache.has(&"voice/alex/hurt") and cache.has(&"voice/alex/death")
			and not cache.has(&"voice/alex/greet"), "preload_voice loads just the groups asked for")
	fresh.free()

	# The real characters ask for theirs (forget them first to see it happen).
	var loaded: Dictionary = Audio.get(&"_takes")
	for key: StringName in [&"voice/alex/hurt", &"voice/alex/death", &"voice/mariane/hurt",
			&"voice/mariane/gasp"]:
		loaded.erase(key)
	var goblin: Node2D = _spawn(GOBLIN_SCENE, Vector2(30.0 * TILE, FLOOR_Y))
	_expect(loaded.has(&"voice/alex/hurt") and loaded.has(&"voice/alex/death"),
			"a goblin loads its cries as it appears")
	goblin.free()
	var spare: Player = _level.player_scene.instantiate() as Player
	add_child(spare)
	_expect(loaded.has(&"voice/mariane/hurt") and loaded.has(&"voice/mariane/gasp"),
			"Mariane loads her voice as she appears")
	spare.free()

	# Audio knows when it is still sounding (quitting mid-sound leaks on exit).
	Audio.reset()
	Audio.voice(&"mariane", &"death")
	_expect(Audio.is_busy(), "Audio is busy while a voice sounds")
	var quiet: bool = await _until(func() -> bool: return not Audio.is_busy(), 400)
	_expect(quiet, "and quiet again when it ends")
	Audio.reset()


# --- Mute --------------------------------------------------------------------

func _check_mute() -> void:
	var real_before: String = _file_text(Audio.SETTINGS_PATH)
	var was_muted: bool = Audio.is_muted()
	Audio.settings_path = SCRATCH_SETTINGS
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_SETTINGS))
	Audio.set_muted(false)
	var master: int = AudioServer.get_bus_index(Audio.MASTER_BUS)

	await _press_key(KEY_M)
	_expect(Audio.is_muted() and AudioServer.is_bus_mute(master), "the M key mutes")
	var saved: ConfigFile = ConfigFile.new()
	saved.load(SCRATCH_SETTINGS)
	_expect(saved.get_value("audio", "muted", false) == true, "the choice is saved to the settings file")
	_expect(Audio.settings_path != GameManager.save_path, "and not to the game save")
	var fresh: Node = (load("res://autoloads/audio.gd") as GDScript).new() as Node
	fresh.set(&"settings_path", SCRATCH_SETTINGS)
	add_child(fresh)
	_expect(fresh.call(&"is_muted") == true, "a fresh start reads the choice back")
	fresh.free()

	get_tree().paused = true
	await _press_key(KEY_M)
	get_tree().paused = false
	_expect(not Audio.is_muted() and not AudioServer.is_bus_mute(master),
			"M also works while the game is paused, and unmutes")
	var saved_again: ConfigFile = ConfigFile.new()
	saved_again.load(SCRATCH_SETTINGS)
	_expect(saved_again.get_value("audio", "muted", true) == false, "the unmuted choice is saved too")

	# Muted or not, the game keeps counting what it plays.
	Audio.set_muted(true)
	Audio.reset()
	_expect(Audio.step(&"dirt") and Audio.play_count(&"step/dirt") == 1, "a muted game still runs its sounds")

	Audio.set_muted(was_muted)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_SETTINGS))
	Audio.settings_path = Audio.SETTINGS_PATH
	_expect(_file_text(Audio.SETTINGS_PATH) == real_before, "the real settings file was never touched")
	Audio.reset()


# --- Gameplay ---------------------------------------------------------------

func _check_footsteps() -> void:
	var listen: Callable = _listen()
	await _place(Vector2(52.5 * TILE, FLOOR_Y))
	Audio.reset()
	_heard.clear()
	Input.action_press("move_left")
	await _frames(100)
	Input.action_release("move_left")
	await _frames(20)
	var steps: int = Audio.play_count(&"step/dirt")
	var off_beat: int = 0
	for event: Array in _heard:
		if event[0] == &"step/dirt" and not (event[1] == &"run" and event[2] in [2, 6]):
			off_beat += 1
	print("  %d steps while running, %d off the foot-down frames" % [steps, off_beat])
	_expect(steps >= 3 and steps <= 8, "running makes a step each time a foot lands")
	_expect(off_beat == 0, "steps fall on frames 2 and 6 of the run, nowhere else")
	_expect(_player.step_surface() == &"dirt", "on the test course's ground her steps are dirt")
	Audio.played.disconnect(listen)


func _check_quiet_moves() -> void:
	await _place(Vector2(52.5 * TILE, FLOOR_Y))
	Audio.reset()
	# Sliding.
	Input.action_press("move_left")
	await _frames(25)
	Input.action_press("move_down")
	var sliding: bool = await _until(func() -> bool: return _player.state_name() == &"Slide", 10)
	var before: int = Audio.play_count(&"step/dirt")
	await _until(func() -> bool: return _player.state_name() != &"Slide", 120)
	Input.action_release("move_down")
	Input.action_release("move_left")
	_expect(sliding and Audio.play_count(&"step/dirt") == before, "a slide is quiet")
	await _frames(40)
	# Crouching.
	await _place(Vector2(52.5 * TILE, FLOOR_Y))
	Audio.reset()
	Input.action_press("move_down")
	await _frames(60)
	Input.action_release("move_down")
	_expect(_player.state_name() in [&"Crouch", &"Idle"] and Audio.plays.is_empty(),
			"crouching is quiet")
	await _frames(20)
	# Dashing.
	await _place(Vector2(52.5 * TILE, FLOOR_Y))
	Audio.reset()
	_player.face(-1.0)
	await _tap("dash")
	var dashing: bool = await _until(func() -> bool: return _player.state_name() == &"Dash", 10)
	before = Audio.play_count(&"step/dirt")
	await _until(func() -> bool: return _player.state_name() != &"Dash", 60)
	_expect(dashing and Audio.play_count(&"step/dirt") == before, "a dash is quiet")
	await _frames(30)


func _check_landing() -> void:
	# A drop from 192 px: a thud of dirt and a soft "oof".
	Audio.reset()
	_player.respawn(Vector2(52.5 * TILE, 10.0 * TILE))
	await _frames(90)
	_expect(Audio.play_count(&"step/dirt") == 1 and Audio.play_count(&"voice/mariane/land") == 1,
			"a real drop lands with a step and a soft voice")
	# A hop makes neither.
	Audio.reset()
	await _place(Vector2(52.5 * TILE, FLOOR_Y - 6.0))
	_expect(Audio.play_count(&"voice/mariane/land") == 0, "a hop lands silently")
	# Planks are wood, in the landing and in her surface.
	Audio.reset()
	_player.respawn(Vector2(46.5 * TILE, 2.0 * TILE))
	await _frames(90)
	print("  on the plank: surface %s, state %s" % [_player.step_surface(), _player.state_name()])
	_expect(_player.step_surface() == &"wood", "standing on a plank her steps are wood")
	_expect(Audio.play_count(&"step/wood") == 1 and Audio.play_count(&"step/dirt") == 0,
			"and the landing on it sounds like wood")


func _check_hurt_and_swings() -> void:
	await _place(Vector2(52.5 * TILE, FLOOR_Y))
	Audio.reset()
	_player.take_damage(1, _player.global_position + Vector2(24.0, 0.0))
	_expect(Audio.play_count(&"voice/mariane/hurt") == 1, "damage on her gives a hurt voice")
	_player.take_damage(1, _player.global_position + Vector2(24.0, 0.0))
	_expect(Audio.play_count(&"voice/mariane/hurt") == 1, "a blow while she is invulnerable gives none")
	await _frames(30)

	# Swings: a grunt now and then, never every swing.
	await _place(Vector2(52.5 * TILE, FLOOR_Y))
	Audio.reset()
	_player.stats.swing_grunt_chance = 1.0
	for i: int in 3:
		await _tap("attack")
		await _frames(14)
	await _until(func() -> bool: return _player.state_name() == &"Idle", 60)
	_expect(Audio.play_count(&"voice/mariane/grunt") == 1, "three swings in a row: one grunt, not three")
	_player.stats.swing_grunt_chance = 0.0
	Audio.reset()
	await _tap("attack")
	await _until(func() -> bool: return _player.state_name() == &"Idle", 60)
	_expect(Audio.play_count(&"voice/mariane/grunt") == 0, "with a chance of zero a swing is silent")
	await _frames(10)


func _check_spells() -> void:
	await _place(Vector2(52.5 * TILE, FLOOR_Y))
	_player.face(1.0)
	Audio.reset()
	await _tap("spell")
	await _until(func() -> bool: return Audio.play_count(&"voice/mariane/shout") > 0, 60)
	_expect(Audio.play_count(&"voice/mariane/shout") == 1, "the Moon Spark comes with a shout")
	await _until(func() -> bool: return _player.state_name() == &"Idle", 60)
	await _frames(20)

	await _place(Vector2(52.5 * TILE, FLOOR_Y))
	_player.face(1.0)
	Audio.reset()
	Input.action_press("attack")
	await _until(func() -> bool: return _player.state_name() == &"Charge", 60)
	await _frames(40)
	_expect(Audio.play_count(&"voice/mariane/shout") == 0, "charging is silent")
	Input.action_release("attack")
	await _until(func() -> bool: return Audio.play_count(&"voice/mariane/shout") > 0, 60)
	_expect(Audio.play_count(&"voice/mariane/shout") == 1, "the Moon Slash's release comes with a shout")
	await _until(func() -> bool: return _player.state_name() == &"Idle", 90)


func _check_rest() -> void:
	await _place(Vector2(52.5 * TILE, FLOOR_Y))
	Audio.reset()
	_player.rest()
	await _until(func() -> bool: return _player.state_name() == &"Rest", 10)
	_expect(Audio.play_count(&"voice/mariane/sigh") == 1, "resting at a campfire comes with a breath")
	await _until(func() -> bool: return _player.state_name() == &"Idle", 150)


func _check_monsters() -> void:
	Audio.reset()
	var goblin: Enemy = _spawn(GOBLIN_SCENE, Vector2(30.0 * TILE, FLOOR_Y)) as Enemy
	goblin.take_hit(1, goblin.global_position + Vector2(10.0, 0.0))
	_expect(Audio.play_count(&"voice/alex/hurt") == 1, "a hurt goblin cries out")
	Audio.reset_cooldowns()
	goblin.take_hit(1, goblin.global_position + Vector2(10.0, 0.0))
	_expect(Audio.play_count(&"voice/alex/death") == 1, "a beaten goblin cries out again")
	var mushroom: Enemy = _spawn(MUSHROOM_SCENE, Vector2(32.0 * TILE, FLOOR_Y)) as Enemy
	Audio.reset()
	mushroom.take_hit(1, mushroom.global_position + Vector2(10.0, 0.0))
	mushroom.take_hit(99, mushroom.global_position + Vector2(10.0, 0.0))
	_expect(Audio.play_count(&"voice/alex/hurt") == 1 and Audio.play_count(&"voice/alex/death") == 1,
			"a Minotaur hurts and falls with a voice too")
	_expect(goblin.voice_pitch < 1.0 and mushroom.voice_pitch < goblin.voice_pitch,
			"the soldier's voice is a little low and the Minotaur's lower")
	Audio.reset()
	var skeleton: Enemy = _spawn(SKELETON_SCENE, Vector2(34.0 * TILE, FLOOR_Y)) as Enemy
	var eye: Enemy = _spawn(EYE_SCENE, Vector2(36.0 * TILE, FLOOR_Y)) as Enemy
	for enemy: Enemy in [skeleton, eye]:
		enemy.take_hit(1, enemy.global_position + Vector2(10.0, 0.0))
		enemy.take_hit(99, enemy.global_position + Vector2(10.0, 0.0))
	var voiced: Array = Audio.plays.keys().filter(
			func(key: StringName) -> bool: return String(key).begins_with("voice/"))
	_expect(voiced.is_empty() and Audio.play_count(&"sfx/enemy_death") >= 1,
			"skeletons and flying eyes have no voice (only the death sound)")


func _check_dialogue() -> void:
	var box: DialogueBox = _level.get_node("%DialogueBox") as DialogueBox
	box.load_script("res://story/chapter_01.txt")
	box.greet_chance = 1.0
	box.farewell_chance = 1.0
	Audio.reset()
	EventBus.dialogue_requested.emit("theo")
	await _frames(3)
	_expect(_dialogue_open and Audio.play_count(&"voice/alex/greet") == 1,
			"a villager conversation opens with a greeting in the villager's voice")
	await _press("interact")
	await _press("interact")
	_expect(Audio.play_count(&"voice/alex/greet") == 1, "only the first line greets")
	Audio.reset_cooldowns()
	await _finish_dialogue()
	_expect(Audio.play_count(&"voice/alex/farewell") == 1, "and closing says goodbye")
	# Talking again is no new introduction.
	Audio.reset()
	EventBus.dialogue_requested.emit("theo")
	await _frames(3)
	_expect(_dialogue_open and Audio.play_count(&"voice/alex/greet") == 0,
			"the second time she talks to them there is no greeting")
	await _finish_dialogue()
	# Kael is no villager.
	Audio.reset()
	EventBus.dialogue_requested.emit("shrine_kael")
	await _frames(3)
	_expect(_dialogue_open and Audio.plays.is_empty(), "the Ember Knight's conversation opens without a hello")
	await _finish_dialogue()
	Audio.reset()


func _check_shield_knight() -> void:
	await _place(Vector2(52.5 * TILE, FLOOR_Y))
	_player.iframe_timer = 60.0
	Audio.reset()
	var knight: ShieldKnight = KNIGHT_SCENE.instantiate() as ShieldKnight
	_level.get_node("%Entities").add_child(knight)
	knight.global_position = _player.global_position + Vector2(50.0, 0.0)
	knight.start_fight(_player)
	var attacked: bool = await _until(func() -> bool:
			return Audio.play_count(&"voice/ian/grunt") + Audio.play_count(&"voice/ian/shout") > 0, 400)
	_expect(attacked, "the Shield Knight grunts as he winds up a swing")
	Audio.reset_cooldowns()
	knight.take_moon_hit(1, _player.global_position)
	_expect(Audio.play_count(&"voice/ian/hurt") == 1, "and cries out when moonlight hurts him")
	Audio.reset_cooldowns()
	knight.take_moon_hit(99, _player.global_position)
	_expect(Audio.play_count(&"voice/ian/death") == 1, "and groans as he yields")
	knight.queue_free()
	_player.iframe_timer = 0.0
	await _frames(10)


func _check_moon_witch() -> void:
	await _place(Vector2(52.5 * TILE, FLOOR_Y))
	_player.iframe_timer = 60.0
	Audio.reset()
	var witch: MoonWitch = WITCH_SCENE.instantiate() as MoonWitch
	_level.get_node("%Entities").add_child(witch)
	witch.spots = [Vector2(45.5 * TILE, FLOOR_Y), Vector2(59.0 * TILE, FLOOR_Y)]
	witch.start_fight(_player)
	var cast: bool = await _until(func() -> bool: return Audio.play_count(&"voice/karen/shout") > 0, 400)
	_expect(cast, "the Moon Witch cries out as she casts")
	Audio.reset_cooldowns()
	witch.take_hit(1, _player.global_position)
	_expect(Audio.play_count(&"voice/karen/hurt") == 1, "and when she is hurt")
	Audio.reset_cooldowns()
	witch.take_hit(99, _player.global_position)
	witch.dissolve()
	_expect(Audio.play_count(&"voice/karen/death") == 1, "and as she dissolves")
	witch.queue_free()
	_player.iframe_timer = 0.0
	await _frames(10)


## Last: she dies, the level brings her back, and she wakes with a breath.
func _check_death_and_waking() -> void:
	await _place(Vector2(52.5 * TILE, FLOOR_Y))
	Audio.reset()
	_player.die()
	await _frames(2)
	_expect(Audio.play_count(&"voice/mariane/death") == 1, "dying comes with her voice")
	var woke: bool = await _until(func() -> bool: return Audio.play_count(&"voice/mariane/gasp") > 0, 400)
	_expect(woke and Audio.play_count(&"voice/mariane/death") == 1,
			"waking up at the campfire comes with a small gasp")
	await _until(func() -> bool: return _player.state_name() == &"Idle", 120)


# --- Helpers ----------------------------------------------------------------

## Records every sound with her animation and frame, until disconnected.
func _listen() -> Callable:
	var listen: Callable = func(key: StringName, _take: int) -> void:
		_heard.append([key, _player.sprite.animation, _player.sprite.frame])
	Audio.played.connect(listen)
	return listen


func _spawn(scene: PackedScene, at: Vector2) -> Node2D:
	var node: Node2D = scene.instantiate() as Node2D
	_level.get_node("%Entities").add_child(node)
	node.global_position = at
	node.set_physics_process(false)
	return node


func _file_text(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "(none)"


func _place(at: Vector2) -> void:
	_player.respawn(at)
	await _frames(80)  # Past the respawn blink.


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame


## Presses and releases an action as real input events.
func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().physics_frame


func _press_key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
		await get_tree().process_frame


func _finish_dialogue() -> void:
	for i: int in 60:
		if not _dialogue_open:
			return
		await _press("interact")
		await _frames(6)


func _until(condition: Callable, limit: int) -> bool:
	for i: int in limit:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		print("FAIL ", label)

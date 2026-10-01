extends Node
## Headless check of which music each moment asks for (the files themselves may
## not be there yet; a missing one is silence, with no error): every chapter's
## track, Chapter Three's switch to winter after the river and back, a
## mini-boss's fight and the return to the chapter's track, and Kael's own track.
## Then the files: every must-have track plays (its own file or its stand-in),
## the memory theme loops, the reveal plays once.
##
## Run from the project folder:
##   godot --headless --path . res://tools/tests/music_test.tscn

const LEVEL_SCENE: PackedScene = preload("res://levels/level.tscn")
const MUST_HAVE: Array[StringName] = [
	&"title", &"memory", &"village", &"lantern_forest", &"boss", &"long_road", &"ember_keep",
	&"rooftop", &"kael_sword", &"reveal", &"credits",
]
const NICE_TO_HAVE: Array[StringName] = [
	&"winter_pass", &"undercroft", &"kael_theme", &"kael_fire", &"ending", &"after_credits",
]
const CHAPTER_TRACKS: Array[StringName] = [
	&"village", &"lantern_forest", &"long_road", &"ember_keep", &"rooftop",
]

var _failures: int = 0


func _ready() -> void:
	GameManager.save_path = "user://test_save.cfg"
	var all_right: bool = true
	for index: int in CHAPTER_TRACKS.size():
		var level: LevelLoader = await _load(index)
		if Music.current != CHAPTER_TRACKS[index]:
			all_right = false
			print("  chapter %d asks for %s" % [index + 1, Music.current])
		if index != 2:
			level.queue_free()
			await _frames(3)
			continue
		# Chapter Three: winter after the river, autumn again before it.
		var hero: Player = level.player
		var switch_x: float = GameManager.get_current_level().terrain_switch_column * 32.0
		hero.respawn(Vector2(switch_x + 64.0, hero.global_position.y))
		await _frames(50)
		_expect(Music.current == &"winter_pass", "past the river the road's music turns to winter")
		hero.respawn(Vector2(switch_x - 200.0, hero.global_position.y))
		await _frames(50)
		_expect(Music.current == &"long_road", "and back before it")
		EventBus.boss_started.emit("The Shield Knight", 8)
		_expect(Music.current == &"boss", "a mini-boss fight has the boss music")
		EventBus.boss_finished.emit()
		_expect(Music.current == &"long_road", "and the chapter's music comes back after it")
		EventBus.boss_started.emit("The Ember Knight", 14)
		_expect(Music.current == &"kael_sword", "Kael has his own")
		EventBus.boss_finished.emit()
		level.queue_free()
		await _frames(3)
	_expect(all_right, "each chapter asks for its own music")

	# The files themselves.
	var missing: Array[String] = []
	for track: StringName in MUST_HAVE:
		Music.play(track, 0.0)
		await _frames(2)
		if _playing_file().is_empty():
			missing.append(track)
	print("  must-have tracks with nothing to play: ", missing)
	_expect(missing.is_empty(), "every must-have track plays (its own file or its stand-in)")
	var stand_ins: Array[String] = []
	for track: StringName in NICE_TO_HAVE:
		Music.play(track, 0.0)
		await _frames(2)
		if _playing_file().get_basename() != track:
			stand_ins.append("%s plays %s" % [track, _playing_file()])
	print("  nice-to-have tracks still on a stand-in: ", stand_ins)
	_expect(stand_ins.is_empty(), "every nice-to-have track has its own file")
	Music.play(&"kael_sword", 0.0)
	await _frames(2)
	_expect(_playing_file() == "boss.mp3", "Kael's fight plays the boss track for now")
	Music.play(&"credits", 0.0)
	await _frames(2)
	_expect(_playing_file() == "title.mp3", "the credits play the title's track")
	Music.play(&"memory", 0.0)
	await _frames(2)
	var memory: AudioStreamWAV = _playing_stream() as AudioStreamWAV
	_expect(memory != null and memory.loop_mode == AudioStreamWAV.LOOP_FORWARD, "the memory theme loops")
	Music.play(&"reveal", 0.0)
	await _frames(2)
	_expect(_playing_file() == "reveal.ogg" and not _playing_stream().get(&"loop"),
			"the reveal plays once")
	Music.play(&"village", 0.0)
	await _frames(2)
	_expect(_playing_stream().get(&"loop") == true, "a chapter's track loops")
	Music.play(&"no_such_track")
	await _frames(5)
	_expect(Music.current == &"no_such_track", "a missing track is silence, not an error")
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(_failures)


## The file the music is playing now, or "" when it is silent.
func _playing_file() -> String:
	var stream: AudioStream = _playing_stream()
	return stream.resource_path.get_file() if stream != null else ""


func _playing_stream() -> AudioStream:
	var players: Array[AudioStreamPlayer] = Music.get(&"_players")
	var player: AudioStreamPlayer = players[Music.get(&"_active")]
	return player.stream if player.playing else null


func _load(index: int) -> LevelLoader:
	GameManager.current_level_index = index
	var level: LevelLoader = LEVEL_SCENE.instantiate() as LevelLoader
	add_child(level)
	await _frames(30)
	return level


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		print("FAIL ", label)

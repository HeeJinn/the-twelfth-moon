extends Node
## Measures how loud each music track is (not a pass/fail test): three windows
## of four seconds (early, middle, late) are played at unity gain through a
## capture effect, and the RMS of the part that sounds is printed in dBFS,
## with the trim that would bring each track to TARGET_DB. Copy the trims into
## Music.TRIM_DB. Takes about twelve seconds a track.
##
## Run from the project folder:
##   godot --headless --path . res://tools/tests/music_levels.tscn

const TARGET_DB: float = -20.0
const WINDOW: float = 4.0
const SILENCE: float = 0.001


func _ready() -> void:
	AudioServer.add_bus()
	var bus: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, &"MusicMeter")
	AudioServer.set_bus_send(bus, &"Master")
	var capture: AudioEffectCapture = AudioEffectCapture.new()
	capture.buffer_length = WINDOW + 1.0
	AudioServer.add_bus_effect(bus, capture)
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = &"MusicMeter"
	add_child(player)
	var files: PackedStringArray = DirAccess.get_files_at(Music.FOLDER)
	for file: String in files:
		if file.get_extension() not in Music.EXTENSIONS:
			continue
		var stream: AudioStream = load(Music.FOLDER + file) as AudioStream
		var length: float = stream.get_length()
		var energy: float = 0.0
		var sounding: int = 0
		var peak: float = 0.0
		for at: float in [0.1, 0.45, 0.75]:
			capture.clear_buffer()
			player.stream = stream
			player.play(length * at)
			await get_tree().create_timer(WINDOW).timeout
			player.stop()
			for frame: Vector2 in capture.get_buffer(capture.get_frames_available()):
				var sample: float = (frame.x + frame.y) / 2.0
				peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
				if absf(sample) > SILENCE:
					energy += sample * sample
					sounding += 1
		var level: float = linear_to_db(sqrt(energy / sounding)) if sounding > 0 else -INF
		print("%-20s %5.0f s  RMS %6.1f dBFS  peak %6.1f dBFS  trim %+5.1f dB" % [
				file, length, level, linear_to_db(peak), TARGET_DB - level])
	get_tree().quit()

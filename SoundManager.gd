class_name SoundManager
extends Node

var player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var generator: AudioStreamGenerator
var playback: AudioStreamGeneratorPlayback

const SAMPLE_RATE = 22050 # Lower sample rate for performance (retro feel)
const PULSE_HZ = 440.0

var sfx_volume: float = 0.5
var music_volume: float = 0.5: set = set_music_volume

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS # Play even when game paused (Shop)
	
	player = AudioStreamPlayer.new()
	add_child(player)
	
	generator = AudioStreamGenerator.new()
	generator.mix_rate = SAMPLE_RATE
	generator.buffer_length = 0.5
	
	player.stream = generator
	player.play()
	
	playback = player.get_stream_playback()
	
	setup_music()

func setup_music():
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	var stream = load("res://assets/CrystalCascades.ogg")
	if stream:
		if stream is AudioStreamOggVorbis:
			stream.loop = true # Ensure looping is on
		music_player.stream = stream
		music_player.volume_db = -10.0 # Start a bit lower so it's not blasting
	
	# Trigger initial state
	set_music_volume(music_volume)

func set_music_volume(val: float):
	music_volume = val
	if music_player:
		# Convert linear energy (0-1) to decibels
		music_player.volume_db = linear_to_db(music_volume)
		
		# Allow muting
		if music_volume <= 0.01:
			if music_player.playing: music_player.stop()
		else:
			if not music_player.playing and music_player.stream: music_player.play()

func play_tone(freq: float, duration: float, volume: float = 0.5, wave_type: String = "square"):
	if sfx_volume <= 0.01: return
	if not playback: return
	var frames = int(SAMPLE_RATE * duration)
	var phase = 0.0
	var increment = freq / SAMPLE_RATE
	
	# Fill buffer
	var buffer = PackedVector2Array()
	buffer.resize(frames)
	
	for i in range(frames):
		var val = 0.0
		
		match wave_type:
			"square":
				val = 1.0 if (phase < 0.5) else -1.0
			"triangle":
				val = 4.0 * abs(phase - 0.5) - 1.0
			"sawtooth":
				val = (phase * 2.0) - 1.0
			"noise":
				val = (randf() * 2.0) - 1.0
		
		# Simple envelope (fade out)
		var env = 1.0 - (float(i) / frames)
		
		var sample = val * volume * env * sfx_volume
		buffer[i] = Vector2(sample, sample)
		
		phase = fmod(phase + increment, 1.0)
		
	playback.push_buffer(buffer)

func play_slide():
	# Quick Pitch Sweep (Move)
	play_sweep(300, 600, 0.1)

func play_match(count: int, type = null):
	# Match sound: Pitch scales with count
	var base = 400 + (count * 100)
	
	print("SoundManager Match: Count=%d Type=%s" % [count, type])
	
	# Tile.Type enum mapping: RED=0, YELLOW=1, GREEN=2, BLUE=3, BLACK=4, PURPLE=5, ORANGE=6
	var TYPE_GREEN = 2
	var TYPE_BLUE = 3
	var TYPE_BLACK = 4
	
	if type == TYPE_BLUE:
		# Blue: Crystal/Chime (Triangle) - Higher pitch, smooth
		base = 600 + (count * 150)
		play_tone(base, 0.2, 0.4, "triangle")
		await get_tree().create_timer(0.05).timeout
		play_tone(base * 2.0, 0.25, 0.2, "triangle")
		
	elif type == TYPE_GREEN:
		# Green: Nature/Vibrant (Sawtooth/Square mix?) - Major interval
		base = 440 + (count * 100)
		play_tone(base, 0.15, 0.35, "square")
		await get_tree().create_timer(0.08).timeout
		play_tone(base * 1.25, 0.15, 0.25, "square") # Major 3rdish
		
	elif type == TYPE_BLACK:
		# Black: Dissonant/Low (Sawtooth/Low Square) - "Less happy"
		base = 150 + (count * 50)
		play_tone(base, 0.3, 0.5, "sawtooth")
		await get_tree().create_timer(0.05).timeout
		play_tone(base * 1.41, 0.3, 0.4, "sawtooth") # Tritone-ish (diminished 5th approx)
		
	else:
		# Default (Retro Square)
		play_tone(base, 0.15, 0.4, "square")
		# Little echo
		await get_tree().create_timer(0.1).timeout
		play_tone(base * 1.5, 0.1, 0.2, "square")

func play_error():
	# Low buzz
	play_tone(150, 0.2, 0.5)

func play_cast():
	# Powerup arpeggio
	play_sweep(400, 800, 0.1)
	await get_tree().create_timer(0.1).timeout
	play_sweep(800, 1200, 0.2)

func play_sweep(start_freq: float, end_freq: float, duration: float, volume: float = 0.5):
	if sfx_volume <= 0.01: return
	if not playback: return
	var frames = int(SAMPLE_RATE * duration)
	var phase = 0.0
	
	var buffer = PackedVector2Array()
	buffer.resize(frames)
	
	for i in range(frames):
		var t = float(i) / frames
		var current_freq = lerp(start_freq, end_freq, t)
		var increment = current_freq / SAMPLE_RATE
		
		# Sawtoothish
		var val = (phase * 2.0) - 1.0
		var env = 1.0 - t
		
		var sample = val * volume * env * sfx_volume
		buffer[i] = Vector2(sample, sample)
		
		phase = fmod(phase + increment, 1.0)
		
	playback.push_buffer(buffer)

func play_gold_tick():
	# Metallic ping (high square/triangle mix)
	# Frequency: ~2000Hz, very short
	play_one_shot_tone(1500 + randf() * 200, 0.05, 0.3, "square")

func play_diamond_tick():
	# Sparkle (high triangle)
	# Frequency: ~3000Hz
	play_one_shot_tone(2500 + randf() * 500, 0.05, 0.3, "triangle")

func play_one_shot_tone(freq: float, duration: float, volume: float = 0.5, wave_type: String = "square"):
	if sfx_volume <= 0.01: return
	
	var temp_player = AudioStreamPlayer.new()
	add_child(temp_player)
	
	var temp_gen = AudioStreamGenerator.new()
	temp_gen.mix_rate = SAMPLE_RATE
	temp_gen.buffer_length = duration + 0.1
	
	temp_player.stream = temp_gen
	temp_player.play()
	
	var temp_playback = temp_player.get_stream_playback()
	if not temp_playback:
		temp_player.queue_free()
		return
		
	var frames = int(SAMPLE_RATE * duration)
	var phase = 0.0
	var increment = freq / SAMPLE_RATE
	
	var buffer = PackedVector2Array()
	buffer.resize(frames)
	
	for i in range(frames):
		var val = 0.0
		match wave_type:
			"square": val = 1.0 if (phase < 0.5) else -1.0
			"triangle": val = 4.0 * abs(phase - 0.5) - 1.0
			"sawtooth": val = (phase * 2.0) - 1.0
			"noise": val = (randf() * 2.0) - 1.0
			
		var env = 1.0 - (float(i) / frames)
		var sample = val * volume * env * sfx_volume
		buffer[i] = Vector2(sample, sample)
		phase = fmod(phase + increment, 1.0)
		
	temp_playback.push_buffer(buffer)
	
	await get_tree().create_timer(duration + 0.1).timeout
	temp_player.queue_free()

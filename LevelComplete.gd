extends Control

signal continued
signal animation_completed

@onready var level_val = $CenterContainer/VBox/StatsContainer/LevelValue
@onready var score_val = $CenterContainer/VBox/StatsContainer/ScoreValue
@onready var turns_val = $CenterContainer/VBox/StatsContainer/TurnsValue
@onready var gold_reward = $CenterContainer/VBox/GoldReward
@onready var diam_reward = $CenterContainer/VBox/DiamondReward/Value
@onready var cont_label = $CenterContainer/VBox/ContinueLabel
var shake_strength: float = 0.0

var current_score: float
var current_turns: int
var start_level: int
var end_level: int
var target_gold: float
var target_diam: float

var sound_manager: SoundManager
# Track previous integer values to trigger sounds on change
var _last_gold_tick: float = -1.0
var _last_diam_tick: float = -1.0

var tween: Tween
var animation_finished: bool = false

func setup(rewards: Dictionary, final_score: float, turns_left: int, start_lvl: int, end_lvl: int, sound_mgr: SoundManager = null):
	# Initial State
	current_score = final_score
	current_turns = turns_left
	start_level = start_lvl
	end_level = end_lvl
	target_gold = float(rewards.get("gold", 0))
	target_diam = float(rewards.get("diamonds", 0))
	sound_manager = sound_mgr
	
	level_val.text = str(start_level)
	score_val.text = str(current_score)
	turns_val.text = str(current_turns)
	gold_reward.text = "+0 Gold"
	diam_reward.text = "+0"
	
	cont_label.modulate.a = 0
	
	if end_lvl > start_lvl:
		level_val.text = str(start_lvl)
		if (end_lvl - start_lvl) > 1:
			level_val.add_theme_color_override("font_color", Color.GREEN)
			shake_strength = min(end_lvl - start_lvl, 10) # Shake for skips
	else:
		level_val.text = str(start_lvl)
	
	set_process_input(true) # Enable input immediately to allow skipping
	start_animation()

func _process(delta):
	if shake_strength > 0:
		shake_strength = lerp(shake_strength, 0.0, 2.0 * delta)
		# Update pivot for correct rotation center
		level_val.pivot_offset = level_val.size / 2.0
		level_val.rotation = randf_range(-0.05 * shake_strength, 0.05 * shake_strength)
		
		# "Camera" Shake (Move the whole UI Layer)
		position = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
	else:
		level_val.rotation = 0.0
		position = Vector2.ZERO

func start_animation():
	if tween: tween.kill()
	tween = create_tween()
	
	_last_gold_tick = 0.0
	_last_diam_tick = 0.0
	
	# Phase 1: Score -> Gold (1.5s)
	tween.tween_method(func(v):
		score_val.text = Utils.format_currency(v, 1000000000.0)
	, current_score, 0.0, 1.5)
	
	# Animate Level Skip parallel to Gold if skipping
	if end_level > start_level:
		tween.parallel().tween_method(func(v):
			var current = int(v)
			var diff = current - start_level
			if diff > 0 and (end_level - start_level) > 1:
				level_val.text = "%d (+%d)" % [current, diff]
			else:
				level_val.text = str(current)
		, float(start_level), float(end_level), 1.5)

	tween.parallel().tween_method(func(v):
		var val = v
		gold_reward.text = "+%s Gold" % Utils.format_currency(val, 1000000000.0)
		if val > _last_gold_tick:
			_last_gold_tick = val
			if sound_manager and int(val) % 2 == 0:
				sound_manager.play_gold_tick()
			elif sound_manager and target_gold < 20:
				sound_manager.play_gold_tick()
	, 0.0, target_gold, 1.5)
	
	# Phase 2: Turns -> Diamonds (1.0s)
	tween.tween_method(func(v):
		turns_val.text = str(int(v))
	, current_turns, 0, 1.0)
	
	tween.parallel().tween_method(func(v):
		var val = int(v)
		diam_reward.text = "+%s" % Utils.format_currency(val, 1000000000.0)
		
		var diff = val - _last_diam_tick
		if diff > 0:
			# FIX: Only play ONE sound per frame, even if multiple diamonds added.
			# Prevents "gross sound" and audio engine crashes on lag spikes.
			if sound_manager:
				sound_manager.play_diamond_tick()
			_last_diam_tick = val
	, 0, target_diam, 1.0)
	
	# End: Show Continue
	tween.tween_property(cont_label, "modulate:a", 1.0, 0.5)
	tween.tween_callback(func():
		animation_finished = true
		# Finalize text format
		if end_level > start_level and (end_level - start_level) > 1:
			level_val.text = "%d (+%d)" % [end_level, end_level - start_level]
		
		emit_signal("animation_completed")
	)

func skip_animation():
	if tween: tween.kill()
	
	# Snap to final values
	# Snap to final values
	if end_level > start_level and (end_level - start_level) > 1:
		level_val.text = "%d (+%d)" % [end_level, end_level - start_level]
	else:
		level_val.text = str(end_level)
	score_val.text = "0"
	gold_reward.text = "+%s Gold" % Utils.format_currency(target_gold, 1000000000.0)
	turns_val.text = "0"
	diam_reward.text = "+%s" % Utils.format_currency(target_diam, 1000000000.0)
	cont_label.modulate.a = 1.0
	
	# Play a finish sound?
	if sound_manager: sound_manager.play_ui_click()

	# Add a small delay/cooldown before allowing potential "Continue" input
	# This prevents double-events (Touch + Mouse Emulation) from skipping AND dismissing in one frame
	await get_tree().create_timer(0.3).timeout
	animation_finished = true
	emit_signal("animation_completed")

func _ready():
	set_process_input(false)

var _continued_pressed = false

func _input(event):
	if _continued_pressed:
		get_viewport().set_input_as_handled()
		return
	
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		get_viewport().set_input_as_handled()
		
		if not animation_finished:
			skip_animation()
		else:
			_continued_pressed = true
			emit_signal("continued")

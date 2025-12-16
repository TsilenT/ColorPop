extends Control

signal continued

@onready var score_val = $CenterContainer/VBox/StatsContainer/ScoreValue
@onready var turns_val = $CenterContainer/VBox/StatsContainer/TurnsValue
@onready var gold_reward = $CenterContainer/VBox/GoldReward
@onready var diam_reward = $CenterContainer/VBox/DiamondReward/Value
@onready var cont_label = $CenterContainer/VBox/ContinueLabel

var current_score: int
var current_turns: int
var target_gold: int
var target_diam: int

var sound_manager: SoundManager
# Track previous integer values to trigger sounds on change
var _last_gold_tick: int = -1
var _last_diam_tick: int = -1

func setup(rewards: Dictionary, final_score: int, turns_left: int, sound_mgr: SoundManager = null):
	# Initial State
	current_score = final_score
	current_turns = turns_left
	target_gold = rewards.get("gold", 0)
	target_diam = rewards.get("diamonds", 0)
	sound_manager = sound_mgr
	
	score_val.text = str(current_score)
	turns_val.text = str(current_turns)
	gold_reward.text = "+0 Gold"
	diam_reward.text = "+0"
	
	cont_label.modulate.a = 0
	
	start_animation()

func start_animation():
	var tween = create_tween()
	
	_last_gold_tick = 0
	_last_diam_tick = 0
	
	# Phase 1: Score -> Gold (1.5s)
	tween.tween_method(func(v):
		score_val.text = str(int(v))
	, current_score, 0, 1.5)
	
	tween.parallel().tween_method(func(v):
		var val = int(v)
		gold_reward.text = "+%d Gold" % val
		if val > _last_gold_tick:
			_last_gold_tick = val
			if sound_manager and val % 2 == 0: # Rate limit slightly (every 2 gold) or checks
				sound_manager.play_gold_tick()
			elif sound_manager and target_gold < 20: # If small amount, play every tick
				sound_manager.play_gold_tick()
	, 0, target_gold, 1.5)
	
	# Phase 2: Turns -> Diamonds (1.0s)
	tween.tween_method(func(v):
		turns_val.text = str(int(v))
	, current_turns, 0, 1.0)
	
	tween.parallel().tween_method(func(v):
		var val = int(v)
		diam_reward.text = "+%d" % val
		
		var diff = val - _last_diam_tick
		if diff > 0:
			if sound_manager:
				for i in range(diff):
					sound_manager.play_diamond_tick()
			_last_diam_tick = val
	, 0, target_diam, 1.0)
	
	# End: Show Continue
	tween.tween_property(cont_label, "modulate:a", 1.0, 0.5)
	tween.tween_callback(func(): set_process_input(true))

func _ready():
	set_process_input(false) # Disable click until anim matches

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		emit_signal("continued")
	elif event is InputEventScreenTouch and event.pressed:
		emit_signal("continued")

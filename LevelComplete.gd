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

func setup(rewards: Dictionary, final_score: int, turns_left: int):
	# Initial State
	current_score = final_score
	current_turns = turns_left
	target_gold = rewards.get("gold", 0)
	target_diam = rewards.get("diamonds", 0)
	
	score_val.text = str(current_score)
	turns_val.text = str(current_turns)
	gold_reward.text = "+0 Gold"
	diam_reward.text = "+0"
	
	cont_label.modulate.a = 0
	
	start_animation()

func start_animation():
	var tween = create_tween()
	
	# Phase 1: Turns -> Diamonds
	# Duration: 1.0s
	tween.tween_method(func(v):
		var t_left = int(v)
		var d_gained = int((current_turns - t_left) * (float(target_diam)/max(1, current_turns)))
		# Fix: Just lerp independently
	, current_turns, 0, 1.0)
	
	# Parallel: Lerp visual numbers
	# Turns Draining
	tween.parallel().tween_method(func(v): turns_val.text = str(int(v)), current_turns, 0, 1.0)
	# Diamonds Filling
	tween.parallel().tween_method(func(v): diam_reward.text = "+%d" % int(v), 0, target_diam, 1.0)
	
	# Phase 2: Score -> Gold
	# Duration: 1.5s
	# Score Draining
	tween.tween_method(func(v): score_val.text = str(int(v)), current_score, 0, 1.5)
	# Gold Filling
	tween.parallel().tween_method(func(v): gold_reward.text = "+%d Gold" % int(v), 0, target_gold, 1.5)
	
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

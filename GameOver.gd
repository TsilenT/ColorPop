extends CanvasLayer

signal restart_requested

@onready var reason_label = $Panel/VBox/ReasonLabel
@onready var level_label = $Panel/VBox/StatsContainer/LevelLabel
@onready var best_label = $Panel/VBox/StatsContainer/BestLabel
@onready var restart_button = $Panel/VBox/RestartButton

func setup(current_level: int, best_level: int, reason: String):
	reason_label.text = reason
	level_label.text = "Reached Level %d" % current_level
	best_label.text = "Best: Level %d" % best_level
	
	# Simple pop-in animation
	$Panel.scale = Vector2.ZERO
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property($Panel, "scale", Vector2.ONE, 0.4)

func _on_restart_button_pressed():
	emit_signal("restart_requested")

class_name Shop
extends CanvasLayer

signal close_requested
signal upgrade_purchased(key: String, cost: int)

@onready var grid_container: GridContainer = $Panel/ScrollContainer/GridContainer
@onready var gold_label: Label = $Panel/GoldLabel
@onready var close_btn: Button = $Panel/CloseButtonContainer/CloseButton

func _ready():
	if close_btn:
		close_btn.pressed.connect(func(): emit_signal("close_requested"))

var level_manager = null # Reference to LevelManager

# Upgrade Definitions
var upgrades = [
	{ "id": "mana_cap", "name": "Mana Cap", "base_cost": 100, "desc": "+10 Max Mana" },
	{ "id": "spell_cost", "name": "Spell Cost", "base_cost": 150, "desc": "-5 Spell Cost" },
	{ "id": "mult_red", "name": "Red Mult", "base_cost": 200, "desc": "+10% Red Score" },
	{ "id": "mult_yellow", "name": "Yellow Mult", "base_cost": 200, "desc": "+10% Yellow Score" },
	{ "id": "mult_green", "name": "Green Mult", "base_cost": 200, "desc": "+10% Mult Gain" },
	{ "id": "mult_blue", "name": "Blue Mult", "base_cost": 200, "desc": "+10% Mana Gain" },
	{ "id": "mult_purple", "name": "Purple Mult", "base_cost": 200, "desc": "+10% Purple Score" },
	{ "id": "mult_orange", "name": "Orange Mult", "base_cost": 200, "desc": "+10% Orange Score" },
	# Black tile usually bad, no upgrade for now
]

func setup(lm):
	level_manager = lm
	refresh_ui()

func refresh_ui():
	if not level_manager: return
	
	gold_label.text = "Gold: %d" % level_manager.save_manager.get_gold()
	
	# Clear existing children
	for child in grid_container.get_children():
		child.queue_free()
		
	# Rebuild Grid
	for up in upgrades:
		var card = UpgradeCardScene.instantiate()
		grid_container.add_child(card)
		
		var lvl = level_manager.save_manager.get_upgrade_level(up["id"])
		card.setup(up, lvl)
		card.update_state(level_manager.save_manager.get_gold())
		
		# Connect signal
		card.buy_pressed.connect(_on_buy_pressed)

var UpgradeCardScene = preload("res://UpgradeCard.tscn")

# create_upgrade_card removed in favor of Scene instantiation

@onready var feedback_label: Label = $FeedbackLabel

# ... (setup and refresh_ui remain similar)

func _on_buy_pressed(key: String, cost: int):
	if level_manager:
		if level_manager.purchase_upgrade(key, cost):
			show_feedback("Purchased!", Color.GREEN)
			emit_signal("upgrade_purchased", key, cost)
			refresh_ui()
		else:
			show_feedback("Not Enough Gold!", Color.RED)

func show_feedback(text: String, color: Color):
	if feedback_label:
		# Kill previous animation to restart
		if feedback_label.has_meta("tween"):
			var t = feedback_label.get_meta("tween")
			if t and t.is_valid():
				t.kill()
			
		feedback_label.text = text
		feedback_label.add_theme_color_override("font_color", color)
		feedback_label.modulate.a = 1.0 # Reset alpha is critical
		feedback_label.visible = true
		feedback_label.move_to_front() # Ensure it's the last child to draw on top
		
		# Debug print to confirm logic execution
		print("Showing feedback: ", text)
		
		var tween = create_tween()
		feedback_label.set_meta("tween", tween)
		# Hold for 1.0s, then fade out
		tween.tween_interval(0.8)
		tween.tween_property(feedback_label, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func(): feedback_label.visible = false)

func _on_close_button_pressed():
	emit_signal("close_requested")

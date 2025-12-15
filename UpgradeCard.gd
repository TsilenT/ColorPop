class_name UpgradeCard
extends PanelContainer

signal buy_pressed(id: String, cost: int)

@onready var name_label: Label = $VBox/NameLabel
@onready var desc_label: Label = $VBox/DescLabel
@onready var lvl_label: Label = $VBox/LevelContainer/LevelLabel
@onready var buy_button: Button = $VBox/BuyButton

var upgrade_id: String
var current_cost: int
var is_maxed: bool = false

func setup(data, current_level: int):
	upgrade_id = data["id"]
	name_label.text = data["name"]
	desc_label.text = data["desc"]
	
	# Cost Formatting
	var base = data["base_cost"]
	# Using the same cost formula as Shop.gs for consistency
	current_cost = base + (current_level * (base * 0.5))
	
	lvl_label.text = "Lvl %d" % current_level
	
	buy_button.text = "%d g" % current_cost
	buy_button.pressed.connect(_on_buy_pressed)
	
	# Check affordability hook (Shop will call this externally or we manage it?)
	# Ideally Shop iterates and updates availability.
	
func update_state(gold: int):
	if buy_button:
		buy_button.disabled = (gold < current_cost)
		if buy_button.disabled:
			buy_button.modulate = Color(0.7, 0.7, 0.7)
		else:
			buy_button.modulate = Color(1, 1, 1)

func _on_buy_pressed():
	emit_signal("buy_pressed", upgrade_id, current_cost)

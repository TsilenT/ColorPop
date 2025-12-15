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
	
	# Check Max
	var max_lvl = data.get("max", -1)
	is_maxed = (max_lvl != -1 and current_level >= max_lvl)
	
	# Cost Formatting
	var base = data["base_cost"]
	if is_maxed:
		current_cost = 0
	else:
		current_cost = base + (current_level * (base * 0.5))
	
	lvl_label.text = "Lvl %d" % current_level
	if max_lvl != -1: lvl_label.text += " / %d" % max_lvl
	
	buy_button.pressed.connect(_on_buy_pressed)
	
	# Styling based on currency
	var currency = data.get("currency", "gold")
	if is_maxed:
		buy_button.text = "MAXED"
		buy_button.disabled = true
	else:
		if currency == "diamonds":
			buy_button.text = "%d 💎" % current_cost # Unicode diamond or just text
			buy_button.add_theme_color_override("font_color", Color(0.26, 0.8, 1))
		else:
			buy_button.text = "%d g" % current_cost
			buy_button.add_theme_color_override("font_color", Color(1, 1, 0.6))
	
func update_state(player_currency: int):
	if is_maxed:
		buy_button.disabled = true
		buy_button.modulate = Color(0.7, 0.7, 0.7)
		return

	if buy_button:
		buy_button.disabled = (player_currency < current_cost)
		if buy_button.disabled:
			buy_button.modulate = Color(0.7, 0.7, 0.7)
		else:
			buy_button.modulate = Color(1, 1, 1)

func _on_buy_pressed():
	if not is_maxed:
		emit_signal("buy_pressed", upgrade_id, current_cost)

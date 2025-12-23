class_name UpgradeCard
extends PanelContainer

signal buy_pressed(id: String, cost: int, amount: int)

@onready var name_label: Label = $VBox/NameLabel
@onready var desc_label: Label = $VBox/DescLabel
@onready var lvl_label: Label = $VBox/LevelContainer/LevelLabel
@onready var buy_button: Button = $VBox/BuyButton
@onready var cost_label: Label = $VBox/BuyButton/Content/CostLabel
@onready var icon_rect: TextureRect = $VBox/BuyButton/Content/IconRect

var upgrade_id: String
var current_cost: int
var is_maxed: bool = false
var purchase_amount: int = 1

func setup(data, current_level: int, multiplier: int = 1):
	upgrade_id = data["id"]
	name_label.text = data["name"]
	desc_label.text = data["desc"]
	
	# Check Max
	var max_lvl = data.get("max", -1)
	is_maxed = (max_lvl != -1 and current_level >= max_lvl)
	
	# Calculate actual amount to buy (clamp to max)
	purchase_amount = multiplier
	if max_lvl != -1 and not is_maxed:
		var remaining = max_lvl - current_level
		if purchase_amount > remaining:
			purchase_amount = remaining

	# Cost Formatting
	var base = data["base_cost"]
	if is_maxed:
		current_cost = 0
	else:
		if upgrade_id.begins_with("exchange_"):
			# Exchange items don't scale cost with level, just multiply base by amount
			current_cost = base * purchase_amount
		else:
			# Formula: n * B + (B * 0.5) * n * ((2.0 * L + n - 1) / 2.0)
			# n = purchase_amount
			# L = current_level
			# B = base

			var n = purchase_amount
			var L = current_level
			var B = base

			# Breaking down to avoid float issues where possible, though 0.5 forces float
			var base_term = n * B
			var scale_term = (B * 0.5) * n * ((2.0 * L + n - 1) / 2.0)

			current_cost = int(base_term + scale_term)
	
	if data.get("hide_level", false):
		lvl_label.visible = false
	else:
		lvl_label.visible = true
		lvl_label.text = "Lvl %d" % current_level
		if max_lvl != -1: lvl_label.text += " / %d" % max_lvl
	
	buy_button.pressed.connect(_on_buy_pressed)
	

	buy_button.text = "" # Clear default
	buy_button.icon = null
	
	var currency = data.get("currency", "gold")
	if is_maxed:
		cost_label.text = "MAXED"
		icon_rect.visible = false
		buy_button.disabled = true
	else:
		var txt = ""
		if purchase_amount > 1:
			txt += "%dx " % purchase_amount

		if currency == "diamonds":
			cost_label.text = txt + "%d" % current_cost
			icon_rect.texture = preload("res://assets/icon_diamond.svg")
			icon_rect.visible = true
			cost_label.add_theme_color_override("font_color", Color(0.26, 0.8, 1))
		else:
			cost_label.text = txt + "%d g" % current_cost
			icon_rect.visible = false
			cost_label.add_theme_color_override("font_color", Color(1, 1, 0.6))
	
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
		emit_signal("buy_pressed", upgrade_id, current_cost, purchase_amount)

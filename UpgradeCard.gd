class_name UpgradeCard
extends PanelContainer

signal buy_pressed(id: String, cost: float, amount: int)

@onready var name_label: Label = $VBox/NameLabel
@onready var desc_label: Label = $VBox/DescLabel
@onready var lvl_label: Label = $VBox/LevelContainer/LevelLabel
@onready var buy_button: Button = $VBox/BuyButton
@onready var cost_label: Label = $VBox/BuyButton/Content/CostLabel
@onready var icon_rect: TextureRect = $VBox/BuyButton/Content/IconRect

var upgrade_id: String
var current_cost: float
var is_maxed: bool = false
var purchase_amount: int = 1

# Helper for Quadratic Calculation
# n^2 + (3 + 2L)n - (4 * Cost / B) = 0
func _calculate_max_buy(available_gold: float, L: float, B: float) -> int:
	if B == 0: return 999999
	var c_term = - (4.0 * available_gold) / B
	var b_term = 3.0 + (2.0 * L)
	
	# Quadratic Formula: (-b + sqrt(b^2 - 4ac)) / 2a
	# a = 1
	var discriminant = (b_term * b_term) - (4.0 * 1.0 * c_term)
	if discriminant < 0: return 0
	
	var n = (-b_term + sqrt(discriminant)) / 2.0
	return int(floor(n))

func setup(data, current_level: int, multiplier: int = 1, currency_available: float = 0.0):
	upgrade_id = data["id"]
	name_label.text = data["name"]
	desc_label.text = data["desc"]
	
	var base = data["base_cost"]
	
	# Check Max
	var max_lvl = data.get("max", -1)
	is_maxed = (max_lvl != -1 and current_level >= max_lvl)
	
	buy_button.disabled = false
	buy_button.modulate = Color(1, 1, 1)

	# Calculate actual amount to buy (clamp to max)
	purchase_amount = multiplier
	
	# Handle MAX Mode
	if multiplier == -1:
		if upgrade_id.begins_with("exchange_"):
			# Linear cost: Cost = n * Base
			if base > 0:
				purchase_amount = int(floor(currency_available / base))
			else:
				purchase_amount = 999
		else:
			# Quadratic cost
			purchase_amount = _calculate_max_buy(currency_available, current_level, base)
		
		# Ensure at least 1 is shown (even if unaffordable) to show NEXT step cost
		if purchase_amount < 1: purchase_amount = 1
		
	# Clamp to Max Level
	if max_lvl != -1 and not is_maxed:
		var remaining = max_lvl - current_level
		if purchase_amount > remaining:
			purchase_amount = remaining
			
	# Cost Formatting
	if is_maxed:
		current_cost = 0
	else:
		if upgrade_id.begins_with("exchange_"):
			# Exchange items don't scale cost with level, just multiply base by amount
			current_cost = base * purchase_amount
			# Update Description dynamically
			# 100 Diamonds = 500 Gold. So 5 * cost.
			var gold_amount = current_cost * 5
			desc_label.text = "%s Gold" % Utils.format_currency(gold_amount)
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

			current_cost = float(base_term + scale_term)
	
	if data.get("hide_level", false):
		lvl_label.visible = false
	else:
		lvl_label.visible = true
		lvl_label.text = "Lvl %s" % Utils.format_currency(current_level, 1000000.0)
		if max_lvl != -1: lvl_label.text += " / %s" % Utils.format_currency(max_lvl, 1000000.0)
	
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
			txt += "%dx | " % purchase_amount

		if currency == "diamonds":
			cost_label.text = txt + "%s" % Utils.format_currency(current_cost)
			icon_rect.texture = preload("res://assets/icon_diamond.svg")
			icon_rect.visible = true
			cost_label.add_theme_color_override("font_color", Color(0.26, 0.8, 1))
		else:
			cost_label.text = txt + "%s" % Utils.format_currency(current_cost)
			icon_rect.texture = preload("res://assets/icon_gold.svg")
			icon_rect.visible = true
			cost_label.add_theme_color_override("font_color", Color(1, 1, 0.6))
	
func update_state(player_currency: float):
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

class_name UpgradeCard
extends PanelContainer

signal buy_pressed(id: String, cost: Big, amount: float)

@onready var name_label: Label = $VBox/NameLabel
@onready var desc_label: Label = $VBox/DescLabel
@onready var lvl_label: Label = $VBox/LevelContainer/LevelLabel
@onready var buy_button: Button = $VBox/BuyButton
@onready var cost_label: Label = $VBox/BuyButton/Content/CostLabel
@onready var icon_rect: TextureRect = $VBox/BuyButton/Content/IconRect

var upgrade_id: String
var current_cost: Big = Big.zero()
var is_maxed: bool = false
var purchase_amount: float = 1.0

# Helper for Quadratic Calculation
# n^2 + (3 + 2L)n - (4 * Gold / B) = 0
# All float/Big math — no int casts, so ridiculous gold can't wrap.
func _calculate_max_buy(available_gold: Big, L: float, B: float) -> float:
	if B <= 0: return 999999.0
	var c = available_gold.mul_f(4.0 / B) # 4G/B as Big
	var b_term = 3.0 + (2.0 * L)

	var cf = c.to_float() # Saturates at ~1.8e308 instead of wrapping
	if not is_finite(b_term) or cf > 1e300:
		# Gold term dwarfs the linear term: n ~= sqrt(16G/B)/2, via log space
		var n = pow(10.0, (c.lg() + Big.log10_f(4.0)) / 2.0) / 2.0
		return floor(n) if is_finite(n) else 1.7976e308

	# Quadratic Formula: (-b + sqrt(b^2 + 16G/B)) / 2, with c = 4G/B
	var discriminant = (b_term * b_term) + 4.0 * cf
	if discriminant < 0: return 0.0
	return floor((-b_term + sqrt(discriminant)) / 2.0)

# cost(n) = n*B + (B/4)*n*(2L + n - 1), computed in Big
func _cost_for(n: float, L: float, B: float) -> Big:
	var linear = Big.of(n).mul_f(B)
	var quad = Big.of(n).mul(Big.of(2.0 * L + n - 1.0)).mul_f(B * 0.25)
	return linear.add(quad)

func setup(data, current_level: float, multiplier: int = 1, currency_available: Big = null):
	if currency_available == null: currency_available = Big.zero()
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
				purchase_amount = floor(currency_available.div(Big.of(float(base))).to_float())
			else:
				purchase_amount = 999.0
		else:
			# Quadratic cost
			purchase_amount = _calculate_max_buy(currency_available, current_level, float(base))

		# Ensure at least 1 is shown (even if unaffordable) to show NEXT step cost
		if purchase_amount < 1: purchase_amount = 1.0

	# Clamp to Max Level
	if max_lvl != -1 and not is_maxed:
		var remaining = float(max_lvl) - current_level
		if purchase_amount > remaining:
			purchase_amount = remaining

	# Cost Formatting
	if is_maxed:
		current_cost = Big.zero()
	else:
		if upgrade_id.begins_with("exchange_"):
			# Exchange items don't scale cost with level, just multiply base by amount
			current_cost = Big.of(float(base)).mul_f(purchase_amount)
			# Update Description dynamically
			# 100 Diamonds = 500 Gold. So 5 * cost.
			desc_label.text = "%s Gold" % current_cost.mul_f(5.0).format()
		else:
			current_cost = _cost_for(purchase_amount, current_level, float(base))

			# Fix float precision in Max Buy where cost slightly exceeds gold.
			# Back off proportionally (min 1 level) so huge n converges fast.
			if multiplier == -1 and current_cost.gt(currency_available) and purchase_amount > 1:
				var guard = 0
				while current_cost.gt(currency_available) and purchase_amount > 1 and guard < 64:
					guard += 1
					purchase_amount = max(1.0, floor(purchase_amount - max(1.0, purchase_amount * 0.000001)))
					current_cost = _cost_for(purchase_amount, current_level, float(base))
	
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
			txt += "%s x | " % Utils.format_currency(purchase_amount, 100000.0)

		if currency == "diamonds":
			cost_label.text = txt + "%s" % current_cost.format()
			icon_rect.texture = preload("res://assets/icon_diamond.svg")
			icon_rect.visible = true
			cost_label.add_theme_color_override("font_color", Color(0.26, 0.8, 1))
		else:
			cost_label.text = txt + "%s" % current_cost.format()
			icon_rect.texture = preload("res://assets/icon_gold.svg")
			icon_rect.visible = true
			cost_label.add_theme_color_override("font_color", Color(1, 1, 0.6))

func update_state(player_currency: Big):
	if is_maxed:
		buy_button.disabled = true
		buy_button.modulate = Color(0.7, 0.7, 0.7)
		return

	if buy_button:
		buy_button.disabled = player_currency.lt(current_cost)
		if buy_button.disabled:
			buy_button.modulate = Color(0.7, 0.7, 0.7)
		else:
			buy_button.modulate = Color(1, 1, 1)

func _on_buy_pressed():
	if not is_maxed:
		emit_signal("buy_pressed", upgrade_id, current_cost, purchase_amount)

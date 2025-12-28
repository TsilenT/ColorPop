class_name Shop
extends CanvasLayer

signal close_requested
signal upgrade_purchased(key: String, cost: float)

@onready var grid_container: GridContainer = $Panel/ScrollContainer/GridContainer
@onready var gold_label: Label = $Panel/GoldLabel
@onready var close_btn: Button = $Panel/CloseButtonContainer/CloseButton

@onready var gold_tab: Button = $Panel/Tabs/GoldTab
@onready var diam_tab: Button = $Panel/Tabs/DiamondTab

@onready var mult_btns = {
	1: $Panel/MultiplierContainer/Mult1x,
	10: $Panel/MultiplierContainer/Mult10x,
	100: $Panel/MultiplierContainer/Mult100x,
	-1: $Panel/MultiplierContainer/Mult1000x
}

var level_manager = null
var sound_manager = null
var current_tab = "gold"
var purchase_multiplier = 1

# Upgrade Definitions
var gold_upgrades = [
	{"id": "mana_cap", "name": "Mana Well", "base_cost": 100, "desc": "+10 Max Mana"},
	{"id": "spell_cost", "name": "Efficiency", "base_cost": 150, "desc": "-5 Catalyst Cost", "max": 8},
	{"id": "mult_green", "name": "Green Mastery", "base_cost": 200, "desc": "+10% Multiplier Gain"},
	{"id": "mult_blue", "name": "Blue Mastery", "base_cost": 200, "desc": "+10% Mana Gain"},
	{"id": "mult_purple", "name": "Purple Mastery", "base_cost": 200, "desc": "+10% Purple Score"},
	{"id": "mult_orange", "name": "Orange Mastery", "base_cost": 200, "desc": "+10% Orange Score"},
	{"id": "mult_red", "name": "Red Mastery", "base_cost": 200, "desc": "+10% Red Score"},
	{"id": "mult_yellow", "name": "Yellow Mastery", "base_cost": 200, "desc": "+10% Yellow Score"},
]

var diamond_upgrades = [
	{"id": "super_diamond", "name": "Gem Fortune", "base_cost": 10, "desc": "+1% Super Diamond Chance Per Tile in a Super Match (4 or More)", "currency": "diamonds", "max": 20},
	{"id": "harvest", "name": "Harvest", "base_cost": 100, "desc": "Unlocks Harvest Spell: Safely Collect All Tiles in a Row", "max": 1, "currency": "diamonds"},
	{"id": "cinderella", "name": "Cinderella", "base_cost": 250, "desc": "+25% Green Tile Spawn Rate", "max": 4, "currency": "diamonds"},
	{"id": "columns", "name": "Grid Expansion", "base_cost": 2000, "desc": "More Columns Means More Tiles!", "max": 2, "currency": "diamonds"}
	
]

const EXCHANGE_ITEMS = [
	{"id": "exchange_100", "name": "Gold Sack", "base_cost": 100, "desc": "500 Gold", "currency": "diamonds", "hide_level": true, "max": - 1}
]

const RELAX_ITEM = {
	"id": "relax",
	"name": "Relax",
	"base_cost": 100000,
	"desc": "It's time to stop playing. Let AI do it for you!",
	"max": 1,
	"currency": "diamonds",
	"hide_level": true
}

func _ready():
	if close_btn:
		close_btn.pressed.connect(func():
			if sound_manager: sound_manager.play_tone(400, 0.05)
			emit_signal("close_requested")
		)
	if gold_tab:
		gold_tab.pressed.connect(switch_tab.bind("gold"))
	if diam_tab:
		diam_tab.pressed.connect(switch_tab.bind("diamonds"))

	for m in mult_btns:
		if mult_btns[m]:
			mult_btns[m].mouse_entered.connect(func(): if sound_manager: sound_manager.play_tone(500, 0.02)) # Optional hover sound
			mult_btns[m].pressed.connect(_on_multiplier_pressed.bind(m))
			mult_btns[m].focus_mode = Control.FOCUS_NONE
	
	if mult_btns.has(-1):
		mult_btns[-1].text = "MAX"

	if gold_tab: gold_tab.focus_mode = Control.FOCUS_NONE
	if diam_tab: diam_tab.focus_mode = Control.FOCUS_NONE

func setup(lm, sm = null):
	level_manager = lm
	sound_manager = sm
	if not current_tab: current_tab = "gold"
	refresh_ui()

func switch_tab(tab: String):
	if sound_manager: sound_manager.play_tone(400, 0.05)
	current_tab = tab
	refresh_ui()

func are_all_diamond_upgrades_maxed() -> bool:
	if not level_manager: return false
	
	var list = diamond_upgrades.duplicate()
	list.append(RELAX_ITEM)
	
	for up in list:
		var current = level_manager.save_manager.get_upgrade_level(up["id"])
		var max_lvl = up.get("max", -1)
		if max_lvl != -1 and current < max_lvl:
			return false
	return true


func refresh_ui():
	if not level_manager: return
	
	gold_label.text = "Gold: %s" % Utils.format_currency(level_manager.save_manager.get_gold())
	var diam_label = $Panel/DiamondLabel
	if diam_label:
		diam_label.visible = (current_tab == "diamonds")
		diam_label.text = "Diamonds: %s" % Utils.format_currency(level_manager.save_manager.get_diamonds())
	
	gold_label.visible = (current_tab == "gold")
	
	# Tab Styling
	var active_color_gold = Color(1, 0.84, 0)
	var active_color_diam = Color(0.26, 0.8, 1)
	
	# Subdued colors (Darkened)
	var inactive_gold = active_color_gold.darkened(0.5)
	var inactive_diam = active_color_diam.darkened(0.5)
	var inactive_white = Color(0.6, 0.6, 0.6) # For multipliers
	
	if gold_tab:
		var active = (current_tab == "gold")
		var c = active_color_gold if active else inactive_gold
		_set_btn_color(gold_tab, c, active)
		
	if diam_tab:
		var active = (current_tab == "diamonds")
		var c = active_color_diam if active else inactive_diam
		_set_btn_color(diam_tab, c, active)
	
	# Multiplier Styling
	for m in mult_btns:
		if mult_btns[m]:
			var active = (purchase_multiplier == m)
			var c = Color.WHITE if active else inactive_white
			_set_btn_color(mult_btns[m], c, active)

	# Clear existing children
	for child in grid_container.get_children():
		child.queue_free()
		
	# Select List
	var list = []
	var currency_amount = level_manager.save_manager.get_gold()
	
	if current_tab == "diamonds":
		list = diamond_upgrades.duplicate()
		currency_amount = level_manager.save_manager.get_diamonds()
		
		# "Relax" Upgrade Logic (Hidden unless 1M diamonds or owned)
		var relax_level = level_manager.save_manager.get_upgrade_level("relax")
		if currency_amount >= 10000 or relax_level > 0:
			list.append(RELAX_ITEM)

		# Check for Maxed Out Shop
		if are_all_diamond_upgrades_maxed():
			list.append_array(EXCHANGE_ITEMS)
	else:
		list = gold_upgrades.duplicate()

	# Rebuild Grid
	for up in list:
		var card = UpgradeCardScene.instantiate()
		grid_container.add_child(card)
		
		var lvl = level_manager.save_manager.get_upgrade_level(up["id"])
		card.setup(up, lvl, purchase_multiplier, currency_amount)
		card.update_state(currency_amount)
		
		# Connect signal
		card.buy_pressed.connect(_on_buy_pressed)

var UpgradeCardScene = preload("res://UpgradeCard.tscn")

@onready var feedback_label: Label = $FeedbackLabel


func _on_multiplier_pressed(m: int):
	if sound_manager: sound_manager.play_tone(400, 0.05)
	purchase_multiplier = m
	refresh_ui()

func _on_buy_pressed(key: String, cost: float, amount: int = 1):
	if level_manager:
		# Handle Exchange Items (Special Case)
		if key.begins_with("exchange_"):
			if level_manager.save_manager.spend_diamonds(cost):
				var gold_gain = cost * 5
				level_manager.save_manager.add_gold(gold_gain)
				
				show_feedback("Converted!", Color.GREEN)
				if sound_manager: sound_manager.play_match(3)
				emit_signal("upgrade_purchased", key, cost)
				refresh_ui()
			else:
				show_feedback("Not Enough!", Color.RED)
				if sound_manager: sound_manager.play_error()
			return

		var currency = "gold"
		if current_tab == "diamonds": currency = "diamonds"
		
		if level_manager.purchase_upgrade(key, cost, currency, amount):
			show_feedback("Purchased!", Color.GREEN)
			if sound_manager: sound_manager.play_match(3) # Nice ding
			emit_signal("upgrade_purchased", key, cost)
			refresh_ui()
		else:
			show_feedback("Not Enough!", Color.RED)
			if sound_manager: sound_manager.play_error()

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
		

		var tween = create_tween()
		feedback_label.set_meta("tween", tween)
		# Hold for 1.0s, then fade out
		tween.tween_interval(0.8)
		tween.tween_property(feedback_label, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func(): feedback_label.visible = false)

func _on_close_button_pressed():
	if sound_manager: sound_manager.play_tone(300, 0.05)
	emit_signal("close_requested")

func _set_btn_color(btn: Button, color: Color, is_active: bool = false):
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_pressed_color", color)
	btn.add_theme_color_override("font_hover_color", color)
	btn.add_theme_color_override("font_focus_color", color)
	
	if is_active:
		# Create a StyleBox that looks like the button is selected (Border)
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.5) # Semi-transparent background
		sb.border_width_bottom = 2
		sb.border_width_top = 2
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_color = Color.WHITE
		sb.corner_radius_top_left = 4
		sb.corner_radius_top_right = 4
		sb.corner_radius_bottom_right = 4
		sb.corner_radius_bottom_left = 4
		
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		
		# Keep the text outline for extra pop? Or maybe too much?
		# User said "white outline on the whole button".
		# Let's remove the text outline to be safe and stick to the box.
		btn.add_theme_constant_override("outline_size", 0)
	else:
		btn.remove_theme_stylebox_override("normal")
		btn.remove_theme_stylebox_override("hover")
		btn.remove_theme_stylebox_override("pressed")
		btn.add_theme_constant_override("outline_size", 0)
	
	# Also reset modulate just in case
	btn.modulate = Color(1, 1, 1)

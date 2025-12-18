class_name Shop
extends CanvasLayer

signal close_requested
signal upgrade_purchased(key: String, cost: int)

@onready var grid_container: GridContainer = $Panel/ScrollContainer/GridContainer
@onready var gold_label: Label = $Panel/GoldLabel
@onready var close_btn: Button = $Panel/CloseButtonContainer/CloseButton

@onready var gold_tab: Button = $Panel/Tabs/GoldTab
@onready var diam_tab: Button = $Panel/Tabs/DiamondTab

var level_manager = null
var sound_manager = null
var current_tab = "gold"

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
	{"id": "super_diamond", "name": "Gem Fortune", "base_cost": 10, "desc": "+1% Super Diamond Chance per Tile in a Super Match (4 or more)", "currency": "diamonds", "max": 20},
	{"id": "harvest", "name": "Harvest", "base_cost": 100, "desc": "Unlocks Harvest Spell: Safely collect all tiles in a row", "max": 1, "currency": "diamonds"},
	{"id": "cinderella", "name": "Cinderella", "base_cost": 250, "desc": "+25% Green Tile Spawn Rate", "max": 4, "currency": "diamonds"},
	{"id": "columns", "name": "Grid Expansion", "base_cost": 2000, "desc": "More Columns means more tiles!", "max": 2, "currency": "diamonds"}
	
]

const EXCHANGE_ITEMS = [
	{"id": "exchange_10", "name": "Small Pouch", "base_cost": 10, "desc": "100 Gold", "currency": "diamonds", "hide_level": true, "max": - 1},
	{"id": "exchange_100", "name": "Medium Bag", "base_cost": 100, "desc": "1,000 Gold", "currency": "diamonds", "hide_level": true, "max": - 1},
	{"id": "exchange_1k", "name": "Large Sack", "base_cost": 1000, "desc": "10,000 Gold", "currency": "diamonds", "hide_level": true, "max": - 1},
	{"id": "exchange_10k", "name": "Vault", "base_cost": 10000, "desc": "100,000 Gold", "currency": "diamonds", "hide_level": true, "max": - 1}
]

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
	
	for up in diamond_upgrades:
		var current = level_manager.save_manager.get_upgrade_level(up["id"])
		var max_lvl = up.get("max", -1)
		if max_lvl != -1 and current < max_lvl:
			return false
	return true


func refresh_ui():
	if not level_manager: return
	
	gold_label.text = "Gold: %d" % level_manager.save_manager.get_gold()
	var diam_label = $Panel/DiamondLabel
	if diam_label:
		diam_label.visible = (current_tab == "diamonds")
		diam_label.text = "Diamonds: %d" % level_manager.save_manager.get_diamonds()
	
	gold_label.visible = (current_tab == "gold")
	
	# Tab Styling
	if gold_tab: gold_tab.modulate = Color(1, 1, 1) if current_tab == "gold" else Color(0.5, 0.5, 0.5)
	if diam_tab: diam_tab.modulate = Color(1, 1, 1) if current_tab == "diamonds" else Color(0.5, 0.5, 0.5)
	
	# Clear existing children
	for child in grid_container.get_children():
		child.queue_free()
		
	# Select List
	var list = []
	var currency_amount = level_manager.save_manager.get_gold()
	
	if current_tab == "diamonds":
		list = diamond_upgrades.duplicate()
		currency_amount = level_manager.save_manager.get_diamonds()
		
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
		card.setup(up, lvl)
		card.update_state(currency_amount)
		
		# Connect signal
		card.buy_pressed.connect(_on_buy_pressed)

var UpgradeCardScene = preload("res://UpgradeCard.tscn")

@onready var feedback_label: Label = $FeedbackLabel


func _on_buy_pressed(key: String, cost: int):
	if level_manager:
		# Handle Exchange Items (Special Case)
		if key.begins_with("exchange_"):
			if level_manager.save_manager.spend_diamonds(cost):
				var gold_gain = cost * 10
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
		
		if level_manager.purchase_upgrade(key, cost, currency):
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

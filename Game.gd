class_name Game
extends Node2D

const COLS = 8
const ROWS = 8
const TILE_SIZE = 70
var GRID_OFFSET = Vector2(100, 100)

#region Scene References
@export var TileScene: PackedScene = preload("res://Tile.tscn")
@onready var board_container: Node2D = $BoardContainer
@export var SettingsScene: PackedScene = preload("res://Settings.tscn")

# UI References
@onready var ui_container: Control = $HUD/UIContainer
@onready var level_label: Label = $HUD/UIContainer/RightPanel/VBox/LevelLabel
@onready var score_bar: ProgressBar = $HUD/UIContainer/RightPanel/VBox/ScoreProgressBar
@onready var score_text: Label = $HUD/UIContainer/RightPanel/VBox/ScoreProgressBar/OverlayLabel
@onready var turns_label: Label = $HUD/UIContainer/RightPanel/VBox/TurnsLabel
@onready var multi_label: Label = $HUD/UIContainer/RightPanel/VBox/MultiLabel
@onready var gold_label: Label = $HUD/UIContainer/Header/GoldContainer/GoldLabel
@onready var diam_label: Label = $HUD/UIContainer/Header/DiamondContainer/DiamondLabel

@onready var mana_label: Label = $HUD/UIContainer/SpellDock/HBox/ManaContainer/ManaLabel
@onready var mana_bar: ProgressBar = $HUD/UIContainer/SpellDock/HBox/ManaContainer/ManaBar
@onready var spell_button: Button = $HUD/UIContainer/SpellDock/HBox/SpellButton
@onready var harvest_button: Button = $HUD/UIContainer/SpellDock/HBox/HarvestButton

@onready var shop_button: TextureButton = $HUD/UIContainer/Header/Buttons/ShopButton
@onready var settings_button: TextureButton = $HUD/UIContainer/Header/Buttons/SettingsButton

@onready var reset_button: Button = $HUD/UIContainer/RightPanel/VBox/ResetButton
@onready var log_label: RichTextLabel = $HUD/UIContainer/RightPanel/VBox/LogPanel/LogLabel
#endregion

#region State Variables
@export var level_manager: LevelManager # Injected or created in ready
var sound_manager: SoundManager
var board_manager: BoardManager
var input_handler: InputHandler

var score: float = 0
var turns: int = 20
var multiplier: float = 1.0
var mana: float = 0
var green_matched_this_turn: bool = false
var input_locked: bool = false # Processing flag

# Legend UI
var legend_labels: Dictionary = {}
var legend_box: GridContainer
#endregion


func _ready():
	level_manager = LevelManager.new()
	add_child(level_manager)
	level_manager.setup_run()
	
	setup_managers()
	
	start_next_level()
	
	get_window().move_to_center()
	randomize()
	
	setup_ui_connections()
	
	setup_background_grid()
	
	# Handle Resizing
	get_tree().root.size_changed.connect(resize_game)
	resize_game()
	
	update_ui() # Initial UI Set
	setup_legend_ui()
	update_legend()

func setup_managers():
	# Audio
	sound_manager = SoundManager.new()
	add_child(sound_manager)
	
	# Apply Settings
	if level_manager and level_manager.save_manager:
		# sound_manager.sound_enabled = level_manager.save_manager.get_setting("sound_enabled", true)
		sound_manager.sfx_volume = level_manager.save_manager.get_setting("sfx_volume", 0.5)
		sound_manager.music_volume = level_manager.save_manager.get_setting("music_volume", 0.5)
		sound_manager.set_music_volume(sound_manager.music_volume)
		
	# Board
	board_manager = BoardManager.new()
	add_child(board_manager)
	board_manager.setup(board_container, TileScene, level_manager, GRID_OFFSET)
	
	# Input
	input_handler = InputHandler.new()
	add_child(input_handler)
	input_handler.setup(board_manager, level_manager, board_container)
	
	# Connect Signals
	input_handler.move_requested.connect(_on_move_requested)
	input_handler.spell_cast_requested.connect(_on_spell_cast_requested)
	input_handler.harvest_requested.connect(_on_harvest_requested)

func setup_ui_connections():
	if spell_button:
		spell_button.pressed.connect(activate_spell_mode.bind("catalyst"))
		spell_button.pressed.connect(func(): if sound_manager: sound_manager.play_tone(440, 0.1))
	
	if harvest_button:
		harvest_button.pressed.connect(activate_spell_mode.bind("harvest"))
		harvest_button.pressed.connect(func(): if sound_manager: sound_manager.play_tone(440, 0.1))
		
	if shop_button: shop_button.pressed.connect(open_shop)
	if settings_button: settings_button.pressed.connect(open_settings)
	if reset_button:
		reset_button.pressed.connect(reset_game)
		reset_button.visible = false

#region Resize Handling
func resize_game():
	var vp_size = get_viewport_rect().size
	var target_width = 1280.0
	var margin_x = max(0, (vp_size.x - target_width) / 2.0)
	
	# Update Board Visual
	var board_frame = $BoardFrame
	if board_frame:
		board_frame.position.x = 45.0 + margin_x
		
	# Update Logic Offset
	GRID_OFFSET.x = 100.0 + margin_x
	
	# Propagate to Board Manager
	if board_manager:
		board_manager.GRID_OFFSET = GRID_OFFSET
		# Reposition existing tiles
		for r in range(ROWS):
			for c in range(COLS):
				var tile = board_manager.get_tile(r, c)
				if tile: tile.position = board_manager.grid_to_pixel(r, c)
	
	update_dock_layout()

func update_dock_layout():
	# Center SpellDock on the BOARD, not the screen
	var dock = $HUD/UIContainer/SpellDock
	var board_frame = $BoardFrame
	if dock and board_frame:
		# Calculate dynamic width based on visibility
		var harvest_btn = $HUD/UIContainer/SpellDock/HBox/HarvestButton
		var width = 300 # Base small size
		if harvest_btn and harvest_btn.visible:
			width = 480 # Expanded size
		
		# Determine Board Center X in UI coordinates
		# Board X is at 45 + margin_x
		# UIContainer is full screen
		var vp_size = get_viewport_rect().size
		var target_width = 1280.0
		var margin_x = max(0, (vp_size.x - target_width) / 2.0)
		var board_center_x = (45.0 + margin_x) + (600.0 / 2.0)
		
		# Set Position manually (override anchors if needed, or use them)
		# Simplest is to set global position X centered on board_center_x
		dock.custom_minimum_size.x = width
		dock.size.x = width
		dock.position.x = board_center_x - (width / 2.0)
		# Keep Y at bottom
		dock.position.y = vp_size.y - 80
#endregion

func start_next_level():
	var target = level_manager.get_current_target()
	turns = 20
	input_locked = false
	input_handler.set_state(InputHandler.State.IDLE)
	
	score = 0
	multiplier = 1.0
	mana = 0
	
	if log_label:
		log_label.text = "Welcome to Match-3 Roguelite!"
	
	if score_bar:
		score_bar.max_value = target
		score_bar.value = 0
	
	board_manager.initialize_board()
	update_ui()
	add_log("Level %d Start! Target: %d" % [level_manager.current_level, target])

func reset_game():
	level_manager.setup_run()
	start_next_level()
	reset_button.visible = false
	if turns_label: turns_label.text = "Turns: %d" % turns

#region Input Signals
func _on_move_requested(start: Vector2i, end: Vector2i):
	attempt_move(start, end)

func _on_spell_cast_requested(grid_pos: Vector2i):
	try_cast_spell(grid_pos)

func _on_harvest_requested(row_idx: int):
	try_cast_harvest(row_idx)

func activate_spell_mode(mode: String = "catalyst"):
	if turns <= 0: return
	
	# Toggle Off logic
	if input_handler.current_state == InputHandler.State.CASTING and input_handler.active_spell_type == mode:
		input_handler.set_state(InputHandler.State.IDLE)
		add_log("Spell Cancelled.")
		update_ui() # Ensure UI reflects cancelled state
		return

	var cost = 0
	if mode == "catalyst": cost = get_spell_cost()
	elif mode == "harvest": cost = 50 # Rebalanced 100 -> 50
	
	if mana >= cost:
		input_handler.set_spell_mode(mode)
		if mode == "catalyst":
			print("Select a BLACK tile to transform!")
			add_log("Select a BLACK tile!")
		elif mode == "harvest":
			print("Select Row to Harvest!")
			add_log("Select Row to Harvest!")
		update_ui() # Update visuals for active state
#endregion

#region Core Mechanics (Delegated)
func attempt_move(start: Vector2i, end: Vector2i):
	print("Move: ", start, " -> ", end)
	
	input_locked = true
	input_handler.set_state(InputHandler.State.LOCKED)
	
	# 1. Tentative Shift
	board_manager.perform_shift(start, end, sound_manager)
	
	# 2. Check matches
	var matches = MatchUtils.find_matches(board_manager.board, ROWS, COLS)
	
	if matches.is_empty():
		# Invalid Move
		if sound_manager: sound_manager.play_error()
		add_log("Invalid Move! No matches.")
		
		await get_tree().create_timer(0.25).timeout
		
		# Revert
		board_manager.perform_shift(end, start, null) # No sound on revert
		await get_tree().create_timer(0.25).timeout
		
		input_locked = false
		input_handler.set_state(InputHandler.State.IDLE)
	else:
		# Valid Move
		turns -= 1
		green_matched_this_turn = false
		
		await get_tree().create_timer(0.3).timeout
		resolve_matches()

func resolve_matches():
	var matched_tiles = MatchUtils.find_matches(board_manager.board, ROWS, COLS)
	if matched_tiles.is_empty():
		end_turn_processing()
		return
		
	var groups = MatchUtils.get_match_groups(matched_tiles, board_manager.board, ROWS, COLS)
	for group in groups:
		process_match_group(group)
	
	# Remove tiles
	for tile in matched_tiles:
		board_manager.remove_tile_at(tile.coordinates)
	
	update_ui()
	
	await get_tree().create_timer(0.1).timeout
	board_manager.apply_gravity()
	board_manager.refill_board()
	
	await get_tree().create_timer(0.6).timeout
	resolve_matches()

func end_turn_processing():
	input_locked = false
	input_handler.set_state(InputHandler.State.IDLE)
	update_ui()
	check_game_over()

func process_match_group(group: Array):
	if group.is_empty(): return
	var type = group[0].tile_type
	var match_count = group.size()
	var efficiency = max(1.0, (1.25) ** (match_count - 3))
	
	var base_score = 0
	if level_manager:
		level_manager.mark_discovered(type)
		base_score = level_manager.get_tile_score(type)
	
	var type_name = "Unknown"
	match type:
		Tile.Type.RED: type_name = "RED"
		Tile.Type.YELLOW: type_name = "YELLOW"
		Tile.Type.ORANGE: type_name = "ORANGE"
		Tile.Type.BLACK: type_name = "BLACK"
		Tile.Type.PURPLE: type_name = "PURPLE"
		Tile.Type.GREEN: type_name = "GREEN"
		Tile.Type.BLUE: type_name = "BLUE"
	
	var match_score = match_count * base_score * multiplier * efficiency
	
	# Apply Granular Multiplier Upgrades
	if level_manager:
		var type_str = ""
		match type:
			Tile.Type.RED: type_str = "mult_red"
			Tile.Type.YELLOW: type_str = "mult_yellow"
			Tile.Type.PURPLE: type_str = "mult_purple"
			Tile.Type.ORANGE: type_str = "mult_orange"
		
		if type_str != "":
			var up_level = level_manager.save_manager.get_upgrade_level(type_str)
			match_score *= (1.0 + (up_level * 0.1))
	
	score = max(0, score + match_score)
	
	if match_score != 0:
		add_log("Matched %d %s! Pts: %d" % [match_count, type_name, int(match_score)])
	
	if sound_manager: sound_manager.play_match(match_count, type)
	
	if type == Tile.Type.GREEN:
		green_matched_this_turn = true
		var gain = 0.1 * match_count * efficiency
		if level_manager:
			var up_level = level_manager.save_manager.get_upgrade_level("mult_green")
			gain *= (1.0 + (up_level * 0.1))
		multiplier += gain
		add_log("Matched %d GREEN! Mult +%.2f -> %.2fx" % [match_count, gain, multiplier])
	
	if type == Tile.Type.BLUE:
		var gain = match_count * 5 * efficiency
		if level_manager:
			var up_level = level_manager.save_manager.get_upgrade_level("mult_blue")
			gain *= (1.0 + (up_level * 0.1))
		mana = min(get_max_mana(), mana + gain)
		add_log("Matched %d BLUE! Mana +%d" % [match_count, int(gain)])
#endregion

#region Spells
func try_cast_spell(grid_pos: Vector2i):
	var tile = board_manager.get_tile(grid_pos.x, grid_pos.y)
	if not tile: return
	
	if tile.tile_type != Tile.Type.BLACK:
		if sound_manager: sound_manager.play_error()
		add_log("Must select a BLACK tile!")
		return
		
	var cost = get_spell_cost()
	if mana >= cost:
		mana -= cost
		
		if sound_manager: sound_manager.play_cast()
		
		
		# Convert to High Value Tile
		var target_type = Tile.Type.RED
		if level_manager:
			target_type = level_manager.get_highest_value_tile_type()
			level_manager.mark_discovered(target_type)
			
		tile.tile_type = target_type
		tile.update_visuals()
		
		add_log("Catalyst! Black -> %s!" % [Tile.Type.keys()[target_type]])
		
		await get_tree().create_timer(0.3).timeout
		resolve_matches()
	else:
		if sound_manager: sound_manager.play_error()
		add_log("Not enough Mana!")
		input_handler.set_state(InputHandler.State.IDLE)

func try_cast_harvest(row_idx: int):
	var cost = 50 # Rebalanced
	if mana >= cost:
		mana -= cost
		if sound_manager: sound_manager.play_cast()
		
		add_log("Harvesting Row %d!" % row_idx)
		
		# Collect and Group tiles by type
		var tiles_to_remove = []
		var type_groups = {}
		
		for c in range(COLS):
			var t = board_manager.get_tile(row_idx, c)
			if t:
				# Exclude Black tiles from scoring groups
				if t.tile_type != Tile.Type.BLACK:
					if not type_groups.has(t.tile_type):
						type_groups[t.tile_type] = []
					type_groups[t.tile_type].append(t)
				
				tiles_to_remove.append(t)
		
		# Process each group as a match
		for type in type_groups:
			var group = type_groups[type]
			# Process Group
			process_match_group(group)
		
		# Remove all tiles in row
		for t in tiles_to_remove:
			board_manager.remove_tile_at(t.coordinates)
			
		update_ui()
		await get_tree().create_timer(0.2).timeout
		board_manager.apply_gravity()
		board_manager.refill_board()
		
		await get_tree().create_timer(0.5).timeout
		resolve_matches()
	else:
		if sound_manager: sound_manager.play_error()
		add_log("Not enough Mana!")
		input_handler.set_state(InputHandler.State.IDLE)

func get_max_mana() -> int:
	var base = 50
	if level_manager:
		base += (level_manager.save_manager.get_upgrade_level("mana_cap") * 10)
	return base
	
func get_spell_cost() -> int:
	var base = 50
	if level_manager:
		base -= (level_manager.save_manager.get_upgrade_level("spell_cost") * 5)
	return max(10, base)
#endregion

#region Helpers
func add_log(msg: String):
	if log_label:
		log_label.text += "\n" + msg

func setup_background_grid():
	var grid_bg = $BoardFrame/GridBackground
	if not grid_bg: return
	for child in grid_bg.get_children():
		child.queue_free()
	for i in range(ROWS * COLS):
		var cell = ColorRect.new()
		cell.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
		var r = i / COLS
		var c = i % COLS
		if (r + c) % 2 == 0:
			cell.color = Color(0.15, 0.15, 0.15, 0.8)
		else:
			cell.color = Color(0.2, 0.2, 0.2, 0.8)
		grid_bg.add_child(cell)
#endregion

#region UI (Settings/Shop/Flow)
func open_shop():
	var shop = preload("res://Shop.tscn").instantiate()
	add_child(shop)
	shop.setup(level_manager, sound_manager)
	if sound_manager: sound_manager.play_tone(400, 0.05)
	get_tree().paused = true
	shop.upgrade_purchased.connect(func(_key, _cost): update_ui())
	shop.close_requested.connect(func():
		shop.queue_free()
		get_tree().paused = false
		update_ui()
	)

func open_settings():
	var settings = SettingsScene.instantiate()
	add_child(settings)
	settings.setup(level_manager, sound_manager)
	if sound_manager: sound_manager.play_tone(400, 0.05)
	get_tree().paused = true
	settings.close_requested.connect(func():
		settings.queue_free()
		get_tree().paused = false
		# Volume is updated live in Settings.gd, no need to re-apply here
	)

func check_game_over():
	if ui_container.has_node("LevelComplete"): return
	
	if level_manager and score >= level_manager.get_current_target():
		var turns_left = turns
		# Calculate and Save Rewards
		var rewards = level_manager.complete_level(score, turns_left)
		
		# Show Screen
		var complete_scn = preload("res://LevelComplete.tscn").instantiate()
		complete_scn.name = "LevelComplete"
		ui_container.add_child(complete_scn)
		complete_scn.setup(rewards, score, turns_left, sound_manager)
		
		complete_scn.continued.connect(func():
			level_manager.advance_level()
			complete_scn.queue_free()
			start_next_level()
		)
		
	elif turns <= 0:
		add_log("Game Over! Out of Turns.")
		if sound_manager: sound_manager.play_error()
		reset_button.visible = true
		input_handler.set_state(InputHandler.State.LOCKED)

func update_ui():
	print("UI UPDATE: Score: %s | Turns: %s | Mult: %s | Mana: %s" % [score, turns, multiplier, mana])
	if level_label and level_manager: level_label.text = "Level: %d" % level_manager.current_level
	if score_text and level_manager:
		score_text.text = "%d / %d" % [int(score), level_manager.get_current_target()]
	if score_bar: score_bar.value = score
	if turns_label: turns_label.text = "Turns: %d" % turns
	if multi_label: multi_label.text = "Multiplier: %.2fx" % multiplier
	if gold_label and level_manager: gold_label.text = str(level_manager.save_manager.get_gold())
	if diam_label and level_manager: diam_label.text = str(level_manager.save_manager.get_diamonds())
	
	var max_mana = get_max_mana()
	if mana_label: mana_label.text = "Mana: %d/%d" % [int(mana), max_mana]
	if mana_bar:
		mana_bar.max_value = max_mana
		mana_bar.value = mana
	
	# Determine Active State (Green if casting this specific spell)
	var is_casting = (input_handler.current_state == InputHandler.State.CASTING)
	var active_spell = input_handler.active_spell_type if is_casting else ""
	
	# Catalyst Button
	if spell_button:
		var cost = get_spell_cost()
		spell_button.text = "Catalyst (%d)" % cost
		
		if active_spell == "catalyst":
			# Active State
			spell_button.disabled = false
			spell_button.modulate = Color(0.6, 1.0, 0.6) # Green
		elif mana >= cost:
			# Available State
			spell_button.disabled = false
			spell_button.modulate = Color(1, 1, 1) # Normal
		else:
			# Disabled State
			spell_button.disabled = true
			spell_button.modulate = Color(1, 1, 1) # Normal dimming handles by disabled
			
	# Harvest Button
	if harvest_button:
		if level_manager and level_manager.save_manager.get_upgrade_level("harvest") > 0:
			harvest_button.visible = true
			var h_cost = 50
			harvest_button.text = "Harvest (%d)" % h_cost
			
			if active_spell == "harvest":
				harvest_button.disabled = false
				harvest_button.modulate = Color(0.6, 1.0, 0.6) # Green
			elif mana >= h_cost:
				harvest_button.disabled = false
				harvest_button.modulate = Color(1, 1, 1)
			else:
				harvest_button.disabled = true
				harvest_button.modulate = Color(1, 1, 1)
		else:
			harvest_button.visible = false
	
	update_legend()

func setup_legend_ui():
	var vbox = $HUD/UIContainer/RightPanel/VBox
	if not vbox: return
	
	# Only create if not exists (checked by legend_box usually but let's be safe)
	if legend_box: return
	
	legend_box = GridContainer.new()
	legend_box.columns = 2
	legend_box.add_theme_constant_override("h_separation", 10)
	
	vbox.add_child(legend_box)
	vbox.move_child(legend_box, 4)
	
	var types = [Tile.Type.RED, Tile.Type.YELLOW, Tile.Type.PURPLE, Tile.Type.ORANGE]
	for type in types:
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 5)
		
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var path = Tile.TEXTURE_PATHS.get(type, "")
		if path != "": icon.texture = load(path)
		hbox.add_child(icon)
		
		var lbl = Label.new()
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(lbl)
		
		legend_box.add_child(hbox)
		legend_labels[type] = lbl

func update_legend():
	if legend_labels.is_empty() or not level_manager: return
	for type in legend_labels:
		var lbl = legend_labels[type]
		var val_text = "???"
		if level_manager.is_type_discovered(type):
			var s = level_manager.get_tile_score(type)
			val_text = level_manager.get_score_text(s)
		lbl.text = val_text
		lbl.modulate = Color.WHITE
#endregion

class_name Game
extends Node2D

const COLS = 8
const ROWS = 8
const TILE_SIZE = 70
var GRID_OFFSET = Vector2(100, 100)

#region Scene References
@export var TileScene: PackedScene = preload("res://Tile.tscn")
@onready var board_container: Node2D = $BoardContainer

# UI References
@onready var ui_container: Control = $HUD/UIContainer
@onready var level_label: Label = $HUD/UIContainer/RightPanel/VBox/LevelLabel
@onready var score_bar: ProgressBar = $HUD/UIContainer/RightPanel/VBox/ScoreProgressBar
@onready var score_text: Label = $HUD/UIContainer/RightPanel/VBox/ScoreProgressBar/OverlayLabel
@onready var turns_label: Label = $HUD/UIContainer/RightPanel/VBox/TurnsLabel
@onready var multi_label: Label = $HUD/UIContainer/RightPanel/VBox/MultiLabel
@onready var gold_label: Label = $HUD/UIContainer/Header/GoldContainer/GoldLabel
@onready var mana_label: Label = $HUD/UIContainer/BottomPanel/ManaLabel
@onready var spell_button: Button = $HUD/UIContainer/BottomPanel/SpellButton
@onready var shop_button: TextureButton = $HUD/UIContainer/Header/Buttons/ShopButton
@onready var settings_button: TextureButton = $HUD/UIContainer/Header/Buttons/SettingsButton

@onready var reset_button: Button = $HUD/UIContainer/RightPanel/VBox/ResetButton
@onready var log_label: RichTextLabel = $HUD/UIContainer/RightPanel/VBox/LogPanel/LogLabel
#endregion

#region State Variables
var board: Array[Array] = []
var selected_tile_coord: Vector2i = Vector2i(-1, -1)
var input_start_pos: Vector2

@export var level_manager: LevelManager
var score: float = 0
var turns: int = 20
var multiplier: float = 1.0
var mana: float = 0
var green_matched_this_turn: bool = false

enum State { IDLE, DRAGGING, PROCESSING, CASTING }
var current_state: State = State.IDLE
# Legend UI
var legend_labels: Dictionary = {}
var legend_box: GridContainer
#endregion

@export var SettingsScene: PackedScene = preload("res://Settings.tscn")

func _ready():
	level_manager = LevelManager.new()
	add_child(level_manager)
	level_manager.setup_run()
	
	start_next_level()
	
	get_window().move_to_center()
	randomize()
	if spell_button:
		spell_button.pressed.connect(activate_spell_mode)
		
	# Shop Connections
	if shop_button: shop_button.pressed.connect(open_shop)
	if settings_button: settings_button.pressed.connect(open_settings)
	
	if reset_button:
		reset_button.pressed.connect(reset_game)
		reset_button.visible = false
	
	setup_background_grid()
	
	# Handle Resizing
	get_tree().root.size_changed.connect(resize_game)
	resize_game()
	
	update_ui() # Initial UI Set
	setup_legend_ui()
	update_legend()
	
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
	
	# Reposition existing tiles
	if board_container:
		for child in board_container.get_children():
			if child.has_method("get_class"): # Basic check
				# Re-calc position from grid coords if available
				# Tiles have 'coordinates' property
				if "coordinates" in child:
					child.position = grid_to_pixel(child.coordinates.x, child.coordinates.y)
	
func open_shop():
	var shop = preload("res://Shop.tscn").instantiate()
	add_child(shop)
	shop.setup(level_manager)
	get_tree().paused = true
	
	# Refresh UI immediately on purchase (for background visibility)
	shop.upgrade_purchased.connect(func(_key, _cost): update_ui())
	
	shop.close_requested.connect(func(): 
		shop.queue_free()
		get_tree().paused = false
	)
	
func open_settings():
	var settings = SettingsScene.instantiate()
	add_child(settings)
	settings.setup(level_manager)
	get_tree().paused = true
	settings.close_requested.connect(func():
		settings.queue_free()
		get_tree().paused = false
	)

func setup_background_grid():
	var grid_bg = $BoardFrame/GridBackground
	if grid_bg:
		for i in range(ROWS * COLS):
			var cell = ColorRect.new()
			cell.custom_minimum_size = Vector2(70, 70)
			# Checkerboard pattern
			var row = i / COLS
			var col = i % COLS
			if (row + col) % 2 == 0:
				cell.color = Color(0.15, 0.15, 0.15, 0.5)
			else:
				cell.color = Color(0.2, 0.2, 0.2, 0.5)
			# Add border/spacing visual by shrinking rect inside container?
			# Simpler: just color distinct from background
			grid_bg.add_child(cell)

func start_next_level():
	var target = level_manager.get_current_target()
	turns = 20 # Fixed turns per level for now
	current_state = State.IDLE
	score = 0
	multiplier = 1.0
	mana = 0
	
	if log_label:
		log_label.text = "Welcome to Match-3 Roguelite!"
	
	if score_bar:
		score_bar.max_value = target
		score_bar.value = 0
	
	initialize_board()
	update_ui()
	add_log("Level %d Start! Target: %d" % [level_manager.current_level, target])

func reset_game():
	# Restart the entire run
	level_manager.setup_run()
	start_next_level()
	reset_button.visible = false
	if turns_label: turns_label.text = "Turns: %d" % turns

#region Board Management
func initialize_board():
	for child in board_container.get_children():
		child.queue_free()
	
	board.resize(ROWS)
	for r in range(ROWS):
		board[r] = []
		board[r].resize(COLS)
		for c in range(COLS):
			var type = get_weighted_random_type()
			while (c >= 2 and board[r][c-1].tile_type == type and board[r][c-2].tile_type == type) or \
				  (r >= 2 and board[r-1][c].tile_type == type and board[r-2][c].tile_type == type):
				type = get_weighted_random_type()
			spawn_tile(r, c, type)

func spawn_tile(r: int, c: int, type_override = null):
	var tile = TileScene.instantiate()
	
	if type_override != null:
		tile.tile_type = type_override
	else:
		tile.tile_type = get_weighted_random_type()
		
	tile.coordinates = Vector2i(r, c)
	tile.position = grid_to_pixel(r, c)
	board_container.add_child(tile)
	board[r][c] = tile
#endregion

func get_weighted_random_type() -> Tile.Type:
	# Probability Table (Total Weight = 13)
	# 0-1: RED, 2-3: YELLOW, 4-5: PURPLE, 6-7: ORANGE (Regulars)
	# 8: GREEN (Mult), 9-10: BLUE (Mana), 11-12: BLACK (Bad)
	# (NOTE: Previous logic had weights: Red < 2 (0,1), Yellow < 4 (2,3), Purple < 6 (4,5), Orange < 8 (6,7))
	# Green < 9 (8), Blue < 11 (9,10), Black (11,12... Wait. randi() % 13 means 0..12)
	# My previous code was % 12 or 13? Let's check view_file. It said % 13.
	# 0-1: RED, 2-3: YELLOW, 4-5: PURPLE, 6-7: ORANGE (Regulars)
	# 8: GREEN (Mult), 9-10: BLUE (Mana), 11: BLACK (Bad)
	var roll = randi() % 12
	if roll < 2: return Tile.Type.RED 
	elif roll < 4: return Tile.Type.YELLOW
	elif roll < 6: return Tile.Type.PURPLE
	elif roll < 8: return Tile.Type.ORANGE
	elif roll < 9: return Tile.Type.GREEN # Weight 1
	elif roll < 11: return Tile.Type.BLUE # Weight 2
	else: return Tile.Type.BLACK # Weight 1

#region Helpers
func add_log(msg: String):
	if log_label:
		log_label.text += "\n" + msg

func grid_to_pixel(r: int, c: int) -> Vector2:
	return Vector2(c * TILE_SIZE, r * TILE_SIZE) + GRID_OFFSET

func pixel_to_grid(pos: Vector2) -> Vector2i:
	var local_pos = pos - GRID_OFFSET
	var c = int(round(local_pos.x / TILE_SIZE))
	var r = int(round(local_pos.y / TILE_SIZE))
	return Vector2i(r, c)

func is_valid_coord(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.x < ROWS and coord.y >= 0 and coord.y < COLS
#endregion



#region Input Handling
var highlight_rect: Line2D = null
var row_highlight: ColorRect = null
var col_highlight: ColorRect = null

func handle_click_start(grid_pos: Vector2i, pos: Vector2):
	if current_state == State.IDLE:
		# Clean up any orphaned highlights first (defensive)
		if highlight_rect:
			highlight_rect.queue_free()
			highlight_rect = null
		if row_highlight:
			row_highlight.queue_free()
			row_highlight = null
		if col_highlight:
			col_highlight.queue_free()
			col_highlight = null
		
		selected_tile_coord = grid_pos
		input_start_pos = pos
		current_state = State.DRAGGING
		
		# Create Highlight Visual for selected tile
		var tile = board[grid_pos.x][grid_pos.y]
		highlight_rect = Line2D.new()
		highlight_rect.default_color = Color(1, 0.8, 0.2, 0.8) # Gold/Yellow
		highlight_rect.width = 4.0
		highlight_rect.closed = true
		var s = (TILE_SIZE / 2.0) - 4
		highlight_rect.points = [Vector2(-s, -s), Vector2(s, -s), Vector2(s, s), Vector2(-s, s)]
		highlight_rect.position = tile.position
		board_container.add_child(highlight_rect)
		
		# Check setting for extra highlights
		var show_highlights = true
		if level_manager and level_manager.save_manager:
			show_highlights = level_manager.save_manager.get_setting("highlight_enabled", true)
			
		if show_highlights:
			# Create Row Highlight
			row_highlight = ColorRect.new()
			row_highlight.color = Color(1, 1, 1, 0.2) # White tint
			var row_pos = grid_to_pixel(grid_pos.x, 0)
			row_highlight.position = Vector2(row_pos.x - TILE_SIZE/2, row_pos.y - TILE_SIZE/2)
			row_highlight.size = Vector2(COLS * TILE_SIZE, TILE_SIZE)
			row_highlight.z_index = 1 # Above background, below tiles
			add_child(row_highlight)
			
			# Create Column Highlight
			col_highlight = ColorRect.new()
			col_highlight.color = Color(1, 1, 1, 0.2) # White tint
			var col_pos = grid_to_pixel(0, grid_pos.y)
			col_highlight.position = Vector2(col_pos.x - TILE_SIZE/2, col_pos.y - TILE_SIZE/2)
			col_highlight.size = Vector2(TILE_SIZE, ROWS * TILE_SIZE)
			col_highlight.z_index = 1 # Above background, below tiles
			add_child(col_highlight)
		
		tile.z_index = 10 # Bring to front
		
	elif current_state == State.CASTING:
		try_cast_spell(grid_pos)

func _input(event):
	if turns <= 0 and current_state != State.PROCESSING:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var grid_pos = pixel_to_grid(event.position)
			if is_valid_coord(grid_pos):
				handle_click_start(grid_pos, event.position)
		else:
			handle_click_release(event.position)
	
	elif event is InputEventMouseMotion and current_state == State.DRAGGING:
		if selected_tile_coord != Vector2i(-1, -1):
			var tile = board[selected_tile_coord.x][selected_tile_coord.y]
			tile.position = event.position
			
			var target_grid = pixel_to_grid(event.position)
			if is_valid_coord(target_grid):
				update_preview(selected_tile_coord, target_grid)

func update_preview(start: Vector2i, curr: Vector2i):
	# Reset all tiles to default positions first
	for r in range(ROWS):
		for c in range(COLS):
			if board[r][c] and Vector2i(r, c) != start:
				board[r][c].position = grid_to_pixel(r, c)
	
	# Apply visual shift if valid drag
	if start.x == curr.x: # Row
		if start.y < curr.y:
			for c in range(start.y, curr.y):
				if board[start.x][c+1]:
					board[start.x][c+1].position = grid_to_pixel(start.x, c)
		elif start.y > curr.y:
			for c in range(start.y, curr.y, -1):
				if board[start.x][c-1]:
					board[start.x][c-1].position = grid_to_pixel(start.x, c)
					
	elif start.y == curr.y: # Col
		if start.x < curr.x:
			for r in range(start.x, curr.x):
				if board[r+1][start.y]:
					board[r+1][start.y].position = grid_to_pixel(r, start.y)
		elif start.x > curr.x:
			for r in range(start.x, curr.x, -1):
				if board[r-1][start.y]:
					board[r-1][start.y].position = grid_to_pixel(r, start.y)

func handle_click_release(pos: Vector2):
	if current_state == State.DRAGGING:
		var end_grid_pos = pixel_to_grid(pos)
		
		# Cleanup Helper Visuals
		if highlight_rect:
			highlight_rect.queue_free()
			highlight_rect = null
		
		# Clean up row/column highlights
		if row_highlight:
			row_highlight.queue_free()
			row_highlight = null
		if col_highlight:
			col_highlight.queue_free()
			col_highlight = null
		
		# Determine if valid move will happen
		var valid_move = is_valid_coord(end_grid_pos) and selected_tile_coord != Vector2i(-1, -1) and selected_tile_coord != end_grid_pos and (selected_tile_coord.x == end_grid_pos.x or selected_tile_coord.y == end_grid_pos.y)
		
		if selected_tile_coord != Vector2i(-1, -1):
			var tile = board[selected_tile_coord.x][selected_tile_coord.y]
			tile.z_index = 0
			
			if not valid_move:
				# Snap back visually only if invalid
				tile.position = grid_to_pixel(selected_tile_coord.x, selected_tile_coord.y)
				# Reset preview
				update_preview(Vector2i(-1,-1), Vector2i(-1,-1)) 
			# Else: Leave visuals as-is (previewed), attempt_move will handle animation/revert
		
		if valid_move:
			attempt_move(selected_tile_coord, end_grid_pos)
		
		if current_state == State.DRAGGING:
			current_state = State.IDLE
		selected_tile_coord = Vector2i(-1, -1)
#endregion

#region Core Mechanics
func attempt_move(start: Vector2i, end: Vector2i):
	if start == end: return
	if start.x != end.x and start.y != end.y: return # Diagonal/Invalid

	print("Move: ", start, " -> ", end)
	
	current_state = State.PROCESSING
	
	# 1. Perform tentative shift
	perform_shift(start, end)
	
	# 2. Check matches
	var matches = MatchUtils.find_matches(board, ROWS, COLS)
	
	if matches.is_empty():
		# Invalid Move
		add_log("Invalid Move! No matches.")
		
		# Wait for animation
		await get_tree().create_timer(0.25).timeout
		
		# Revert
		perform_shift(end, start)
		await get_tree().create_timer(0.25).timeout
		
		current_state = State.IDLE
	else:
		# Valid Move
		turns -= 1
		green_matched_this_turn = false
		
		# Wait for animation then resolve
		await get_tree().create_timer(0.3).timeout
		resolve_matches()

func perform_shift(start: Vector2i, end: Vector2i):
	var mover_tile = board[start.x][start.y]
	
	if start.x == end.x: # Row
		var r = start.x
		if start.y < end.y:
			for c in range(start.y, end.y):
				shift_tile(r, c+1, r, c)
		else:
			for c in range(start.y, end.y, -1):
				shift_tile(r, c-1, r, c)
		board[r][end.y] = mover_tile
		animate_tile(mover_tile, r, end.y)
		
	elif start.y == end.y: # Col
		var c = start.y
		if start.x < end.x:
			for r in range(start.x, end.x):
				shift_tile(r+1, c, r, c)
		else:
			for r in range(start.x, end.x, -1):
				shift_tile(r-1, c, r, c)
		board[end.x][c] = mover_tile
		animate_tile(mover_tile, end.x, c)

func shift_tile(from_r, from_c, to_r, to_c):
	var t = board[from_r][from_c]
	board[to_r][to_c] = t
	animate_tile(t, to_r, to_c)

func animate_tile(tile: Node2D, r: int, c: int):
	tile.coordinates = Vector2i(r, c)
	var tween = create_tween()
	tween.tween_property(tile, "position", grid_to_pixel(r, c), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
#endregion

#region Matching & Scoring
func resolve_matches():
	var matched_tiles = MatchUtils.find_matches(board, ROWS, COLS)
	if matched_tiles.is_empty():
		end_turn_processing()
		return
		
	var groups = MatchUtils.get_match_groups(matched_tiles, board, ROWS, COLS)
	for group in groups:
		process_match_group(group)
	
	# Remove tiles
	for tile in matched_tiles:
		board[tile.coordinates.x][tile.coordinates.y] = null
		tile.queue_free()
	
	update_ui()
	
	await get_tree().create_timer(0.1).timeout
	apply_gravity()
	refill_board()
	
	# Wait for animation (0.2s) + extra time for player to see results/fall
	await get_tree().create_timer(0.6).timeout
	resolve_matches()

func end_turn_processing():
	# No decay
	current_state = State.IDLE
	update_ui()
	check_game_over()

func process_match_group(group: Array):
	if group.is_empty(): return
	var type = group[0].tile_type
	var match_count = group.size()
	var efficiency = (1.25)**(match_count - 3)
	
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
		# Generic calc: if type is RED, check "mult_red" upgrade
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
	
	if match_score > 0:
		add_log("Matched %d %s! Pts: %d" % [match_count, type_name, int(match_score)])
	
	if type == Tile.Type.GREEN:
		green_matched_this_turn = true
		var gain = 0.1 * match_count * efficiency
		
		# Apply Upgrade
		if level_manager:
			var up_level = level_manager.save_manager.get_upgrade_level("mult_green")
			gain *= (1.0 + (up_level * 0.1))
			
		multiplier += gain
		add_log("Matched %d GREEN! Mult +%.1f -> %.1fx" % [match_count, gain, multiplier])
	
	if type == Tile.Type.BLUE:
		var gain = match_count * 5 * efficiency
		
		# Apply Upgrade
		if level_manager:
			var up_level = level_manager.save_manager.get_upgrade_level("mult_blue")
			gain *= (1.0 + (up_level * 0.1))
			
		mana = min(get_max_mana(), mana + gain)
		add_log("Matched %d BLUE! Mana +%d" % [match_count, int(gain)])
#endregion

func get_max_mana() -> int:
	var base = 50
	if level_manager:
		base += (level_manager.save_manager.get_upgrade_level("mana_cap") * 10)
	return base
	
func get_spell_cost() -> int:
	var base = 50
	if level_manager:
		base -= (level_manager.save_manager.get_upgrade_level("spell_cost") * 5)
	return max(10, base) # Minimum cost 10



#region Board Physics
func apply_gravity():
	for c in range(COLS):
		var write = ROWS - 1
		for r in range(ROWS - 1, -1, -1):
			if board[r][c] != null:
				if r != write:
					board[write][c] = board[r][c]
					board[r][c] = null
					animate_tile(board[write][c], write, c)
				write -= 1

func refill_board():
	for c in range(COLS):
		for r in range(ROWS):
			if board[r][c] == null:
				spawn_tile(r, c)
				board[r][c].position.y -= 100
				animate_tile(board[r][c], r, c)
#endregion

#region UI Updates
func update_ui():
	print("UI UPDATE: Score: %s | Turns: %s | Mult: %s | Mana: %s" % [score, turns, multiplier, mana])
	if level_label and level_manager: level_label.text = "Level: %d" % level_manager.current_level
	if score_text and level_manager:
		score_text.text = "%d / %d" % [int(score), level_manager.get_current_target()]
	if score_bar: score_bar.value = score
	if turns_label: turns_label.text = "Turns: %d" % turns
	if multi_label: multi_label.text = "Multiplier: %.1fx" % multiplier
	if gold_label and level_manager: gold_label.text = "Gold: %d" % level_manager.save_manager.get_gold()
	var max_mana = get_max_mana()
	if mana_label: mana_label.text = "Mana: %d/%d" % [int(mana), max_mana]
	
	if spell_button:
		var cost = get_spell_cost()
		spell_button.text = "Cast Catalyst (%d)" % cost
		spell_button.disabled = (mana < cost)
	
	update_legend()

func setup_legend_ui():
	# Insert into VBox
	var vbox = $HUD/UIContainer/RightPanel/VBox
	if not vbox: return
	
	legend_box = GridContainer.new()
	legend_box.columns = 2
	legend_box.add_theme_constant_override("h_separation", 10)
	
	# Insert before LogPanel (which acts as a filler usually)
	# LogPanel is at index 4 in scene (Level, Score, Turns, Multi, Log)
	vbox.add_child(legend_box)
	vbox.move_child(legend_box, 4)
	
	var types = [Tile.Type.RED, Tile.Type.YELLOW, Tile.Type.PURPLE, Tile.Type.ORANGE]
	for type in types:
		var lbl = Label.new()
		lbl.add_theme_font_size_override("font_size", 16)
		legend_box.add_child(lbl)
		legend_labels[type] = lbl

func update_legend():
	if legend_labels.is_empty() or not level_manager: return
	
	var names = {
		Tile.Type.RED: "RED",
		Tile.Type.YELLOW: "YLW",
		Tile.Type.PURPLE: "PUR",
		Tile.Type.ORANGE: "ORG"
	}
	
	for type in legend_labels:
		var lbl = legend_labels[type]
		var type_name = names.get(type, "???")
		var val_text = "???"
		
		# Color logic
		var col = Color.WHITE
		match type:
			Tile.Type.RED: col = Color(1, 0.4, 0.4)
			Tile.Type.YELLOW: col = Color(1, 1, 0.4)
			Tile.Type.PURPLE: col = Color(0.8, 0.4, 1)
			Tile.Type.ORANGE: col = Color(1, 0.6, 0.2)
			
		if level_manager.is_type_discovered(type):
			var s = level_manager.get_tile_score(type)
			val_text = level_manager.get_score_text(s)
		
		lbl.text = "%s: %s" % [type_name, val_text]
		lbl.modulate = col
#endregion

#region Game Flow
func check_game_over():
	# Win Condition (Level Complete)
	if level_manager and score >= level_manager.get_current_target():
		var reward = level_manager.complete_level()
		add_log("Level Complete! +%d Gold" % reward)
		await get_tree().create_timer(1.0).timeout
		start_next_level()
		current_state = State.IDLE
		return

	# Loss Condition
	if turns <= 0:
		add_log("GAME OVER!")
		print("GAME OVER")
		current_state = State.PROCESSING # Lock inputs
		if turns_label: turns_label.text = "GAME OVER"
		if reset_button: reset_button.visible = true
#endregion

#region Ability Logic
func activate_spell_mode():
	if turns <= 0: return # Locked if Game Over
	
	var cost = get_spell_cost()
	if mana >= cost:
		current_state = State.CASTING
		print("Select a BLACK tile to transform!")
		add_log("Select a BLACK tile!")

func try_cast_spell(grid_pos: Vector2i):
	var tile = board[grid_pos.x][grid_pos.y]
	if tile.tile_type == Tile.Type.BLACK:
		var cost = get_spell_cost()
		mana -= cost
		var target_type = Tile.Type.RED
		if level_manager:
			target_type = level_manager.get_highest_value_tile_type()
			
		tile.tile_type = target_type
		# Update Visual
		tile._ready() 
		
		print("Spell Cast! Converted Black to High Value Tile.")
		add_log("Spell: Black -> High Value!")
		current_state = State.PROCESSING
		resolve_matches() # Check if this created a match
	else:
		print("Invalid Target. Select BLACK tile.")
		current_state = State.IDLE
#region Shop Logic
#endregion

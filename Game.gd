class_name Game
extends Node2D

const COLS = 8
const ROWS = 8
const TILE_SIZE = 70
const GRID_OFFSET = Vector2(100, 100)

#region Scene References
@export var TileScene: PackedScene = preload("res://Tile.tscn")
@onready var board_container: Node2D = $BoardContainer

# UI References
@onready var score_bar: ProgressBar = $HUD/RightPanel/VBox/ScoreProgressBar
@onready var score_text: Label = $HUD/RightPanel/VBox/ScoreProgressBar/OverlayLabel
@onready var turns_label: Label = $HUD/RightPanel/VBox/TurnsLabel
@onready var multi_label: Label = $HUD/RightPanel/VBox/MultiLabel
@onready var gold_label: Label = $HUD/TopRightPanel/VBox/GoldLabel
@onready var mana_label: Label = $HUD/BottomPanel/ManaLabel
@onready var spell_button: Button = $HUD/BottomPanel/SpellButton
@onready var shop_button: Button = $HUD/TopRightPanel/VBox/ShopButton

# Legacy internal shop nodes removed
var shop_panel = null 
var shop_close_btn = null
var btn_upgrade_mana = null
var btn_upgrade_spell = null
var btn_upgrade_score = null
@onready var reset_button: Button = $HUD/RightPanel/VBox/ResetButton
@onready var log_label: RichTextLabel = $HUD/RightPanel/VBox/LogPanel/LogLabel
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
#endregion

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
	# Legacy internal shop buttons removed
	
	if reset_button:
		reset_button.pressed.connect(reset_game)
		reset_button.visible = false
	
	setup_background_grid()
	update_ui() # Initial UI Set

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
	
	# Manual _ready removed to avoid double initialization error
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

func handle_click_start(grid_pos: Vector2i, pos: Vector2):
	if current_state == State.IDLE:
		selected_tile_coord = grid_pos
		input_start_pos = pos
		current_state = State.DRAGGING
		
		# Create Highlight Visual
		var tile = board[grid_pos.x][grid_pos.y]
		highlight_rect = Line2D.new()
		highlight_rect.default_color = Color(1, 0.8, 0.2, 0.8) # Gold/Yellow
		highlight_rect.width = 4.0
		highlight_rect.closed = true
		var s = (TILE_SIZE / 2.0) - 4
		highlight_rect.points = [Vector2(-s, -s), Vector2(s, -s), Vector2(s, s), Vector2(-s, s)]
		highlight_rect.position = tile.position
		board_container.add_child(highlight_rect)
		
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
	var efficiency = 1.0 + (match_count - 3) * 0.25
	
	var base_score = 0
	if level_manager:
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
			Tile.Type.GREEN: type_str = "mult_green"
			Tile.Type.BLUE: type_str = "mult_blue"
			Tile.Type.PURPLE: type_str = "mult_purple"
			Tile.Type.ORANGE: type_str = "mult_orange"
		
		if type_str != "":
			var up_level = level_manager.upgrades.get(type_str, 0)
			match_score *= (1.0 + (up_level * 0.1))
	
	score = max(0, score + match_score)
	
	add_log("Matched %d %s! Pts: %d" % [match_count, type_name, int(match_score)])
	
	if type == Tile.Type.GREEN:
		green_matched_this_turn = true
		var gain = 0.1 * match_count * efficiency
		multiplier += gain
		add_log("Green Match! Mult +%.1f -> %.1fx" % [gain, multiplier])
	
	if type == Tile.Type.BLUE:
		var gain = match_count * 5 * efficiency
		mana = min(get_max_mana(), mana + gain)
		add_log("Mana +%d" % int(gain))
#endregion

func get_max_mana() -> int:
	var base = 50
	if level_manager:
		base += (level_manager.upgrades.get("mana_cap", 0) * 10)
	return base
	
func get_spell_cost() -> int:
	var base = 50
	if level_manager:
		base -= (level_manager.upgrades.get("spell_cost", 0) * 5)
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
	if score_text and level_manager:
		score_text.text = "%d / %d" % [int(score), level_manager.get_current_target()]
	if score_bar: score_bar.value = score
	if turns_label: turns_label.text = "Turns: %d" % turns
	if multi_label: multi_label.text = "Multiplier: %.1fx" % multiplier
	if gold_label and level_manager: gold_label.text = "Gold: %d" % level_manager.gold
	var max_mana = get_max_mana()
	if mana_label: mana_label.text = "Mana: %d/%d" % [int(mana), max_mana]
	
	if spell_button:
		var cost = get_spell_cost()
		spell_button.text = "Cast Catalyst (%d)" % cost
		spell_button.disabled = (mana < cost)
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
		# tile._ready() # Removed as per previous fix, but we actually MIGHT need it here for texture update? 
		# Actually, since tile is already in tree, _ready won't auto-run. We DO need to force update the visual if we change type.
		# Let's call the logic that updates appearance. Tile.gd _ready does that. 
		# But we know calling _ready directly can be unsafe if it does other things. 
		# Tile.gd _ready is clean (just sets texture/modulate). Let's check Tile.gd again? 
		# Wait, I removed the _read() call in spawn, but here the node is fully active. It should be safe to call _ready() to refresh visuals.
		# Or better, extract visual update to a function. 
		# For now, I'll assume _ready() is safe here as the node is definitely in tree.
		tile._ready() 
		
		print("Spell Cast! Converted Black to High Value Tile.")
		add_log("Spell: Black -> High Value!")
		current_state = State.PROCESSING
		resolve_matches() # Check if this created a match
	else:
		print("Invalid Target. Select BLACK tile.")
		current_state = State.IDLE
#region Shop Logic
#region Shop Logic
func open_shop():
	if not level_manager: return
	
	var shop_scene = preload("res://Shop.tscn").instantiate()
	add_child(shop_scene)
	shop_scene.setup(level_manager)
	
	# Connect signals
	shop_scene.close_requested.connect(func(): 
		shop_scene.queue_free()
		current_state = State.IDLE # Unlock
	)
	
	shop_scene.upgrade_purchased.connect(try_buy_upgrade)
	# Lock input
	current_state = State.PROCESSING

func try_buy_upgrade(key: String, cost: int):
	# Purchase logic moved to Shop.gd for better feedback control
	# This function now just updates the main UI
	add_log("Purchased %s!" % key)
	update_ui()
#endregion

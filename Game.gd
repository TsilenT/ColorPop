class_name Game
extends Node2D

var COLS = 8
const ROWS = 8
const TILE_SIZE = 70
var GRID_OFFSET = Vector2(100, 100)

#region Scene References
@export var TileScene: PackedScene = preload("res://Tile.tscn")
@export var MatchParticlesScene: PackedScene = preload("res://MatchParticles.tscn")
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
var auto_match_timer: float = 0.0

# Legend UI
var legend_labels: Dictionary = {}
var legend_box: GridContainer

# Shake constants and vars
var game_camera: Camera2D
var shake_strength: float = 0.0
var shake_decay: float = 5.0

const TILE_COLORS = {
	Tile.Type.RED: Color(1.0, 0.4, 0.4),
	Tile.Type.YELLOW: Color(1.0, 0.9, 0.2),
	Tile.Type.GREEN: Color(0.4, 1.0, 0.5),
	Tile.Type.BLUE: Color(0.4, 0.7, 1.0),
	Tile.Type.BLACK: Color(0.9, 0.9, 0.9), # White text for black tiles
	Tile.Type.PURPLE: Color(0.8, 0.5, 1.0),
	Tile.Type.ORANGE: Color(1.0, 0.7, 0.2),
	Tile.Type.DIAMOND: Color(0.8, 0.95, 1.0)
}
#endregion


func is_relax_active() -> bool:
	if not level_manager or not level_manager.save_manager: return false
	var relax_level = level_manager.save_manager.get_upgrade_level("relax")
	var auto = level_manager.save_manager.get_setting("auto_match_enabled", true)
	return relax_level > 0 and auto

func _process(delta):
	if shake_strength > 0:
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
		if game_camera:
			game_camera.offset = Vector2(
				randf_range(-shake_strength, shake_strength),
				randf_range(-shake_strength, shake_strength)
			)

	# Relax / Auto Match Logic
	if level_manager and level_manager.save_manager:
		var relax_level = level_manager.save_manager.get_upgrade_level("relax")
		var auto_enabled = level_manager.save_manager.get_setting("auto_match_enabled", true)

		if relax_level > 0 and auto_enabled:
			auto_match_timer += delta
			if auto_match_timer >= 0.5:
				auto_match_timer = 0.0
				if not input_locked and turns > 0 and not ui_container.has_node("LevelComplete") and not ui_container.has_node("GameOver"):
					perform_auto_match()

func perform_auto_match():
	# 1. Simulate Moves
	var best_move_start = Vector2i(-1, -1)
	var best_move_end = Vector2i(-1, -1)

	var best_green_size = -1
	var best_score = -1.0

	# Create a lightweight virtual board representation for simulation
	# We just need types.
	var virtual_board: Array[Array] = []
	for r in range(ROWS):
		var row = []
		for c in range(COLS):
			var t = board_manager.get_tile(r, c)
			if t: row.append(t) # Storing references for MatchUtils compatibility
			else: row.append(null)
		virtual_board.append(row)

	for r in range(ROWS):
		for c in range(COLS):
			# Row Moves (Try moving to every other column in SAME ROW)
			for target_c in range(COLS):
				if c == target_c: continue
				
				# Optimization: Pruning
				# Only simulate if the move lands the tile near a compatible neighbor
				if not _has_potential_match(virtual_board, r, c, r, target_c):
					continue
				
				var res = _evaluate_move(virtual_board, Vector2i(r, c), Vector2i(r, target_c))
				if res.valid:
					# Debug for Green
					if res.green_size > 0:
						print("AutoMatch: Found Green Check (G=%d) %s -> %s" % [res.green_size, Vector2i(r, c), Vector2i(r, target_c)])
						
					if res.green_size > best_green_size:
						best_green_size = res.green_size
						best_score = res.score
						best_move_start = Vector2i(r, c)
						best_move_end = Vector2i(r, target_c)
					elif res.green_size == best_green_size:
						if res.score > best_score:
							best_score = res.score
							best_move_start = Vector2i(r, c)
							best_move_end = Vector2i(r, target_c)

			# Column Moves (Try moving to every other row in SAME COL)
			for target_r in range(ROWS):
				if r == target_r: continue
				
				# Optimization: Pruning
				if not _has_potential_match(virtual_board, r, c, target_r, c):
					continue
				
				var res = _evaluate_move(virtual_board, Vector2i(r, c), Vector2i(target_r, c))
				if res.valid:
					# Debug for Green
					if res.green_size > 0:
						print("AutoMatch: Found Green Check (G=%d) %s -> %s" % [res.green_size, Vector2i(r, c), Vector2i(target_r, c)])
						
					if res.green_size > best_green_size:
						best_green_size = res.green_size
						best_score = res.score
						best_move_start = Vector2i(r, c)
						best_move_end = Vector2i(target_r, c)
					elif res.green_size == best_green_size:
						if res.score > best_score:
							best_score = res.score
							best_move_start = Vector2i(r, c)
							best_move_end = Vector2i(target_r, c)

	if best_move_start != Vector2i(-1, -1):
		attempt_move(best_move_start, best_move_end)

# Optimization Helper: Checks if moving tile at start->end has any chance of matching
# Checks perpendicular neighbors at destination.
func _has_potential_match(v_board: Array, start_r: int, start_c: int, end_r: int, end_c: int) -> bool:
	var t = v_board[start_r][start_c]
	if not t: return false
	
	var type = t.tile_type
	if type == Tile.Type.DIAMOND: return true # Diamonds match everything, always check
	
	# Check Neighbors at DESTINATION (excluding the axis of movement)
	# If moving Vertically (Row Change), check Left/Right neighbors at End Row
	if start_c == end_c: # Vertical Move
		# Check Left
		if end_c > 0:
			var n = v_board[end_r][end_c - 1]
			if n and (n.tile_type == type or n.tile_type == Tile.Type.DIAMOND): return true
		# Check Right
		if end_c < COLS - 1:
			var n = v_board[end_r][end_c + 1]
			if n and (n.tile_type == type or n.tile_type == Tile.Type.DIAMOND): return true
			
		# Also check "Vertical" neighbors that might NOT be moving?
		# Actually, if we move tile to (end_r, c), the tile previously at (end_r, c) moves away.
		# But the tile at (end_r + 1, c) stays static (unless it's part of the shift range).
		# To be safe and simple: Just checking Perpendicular neighbors handles 80% of cases.
		
	# If moving Horizontally (Col Change), check Up/Down neighbors at End Col
	elif start_r == end_r: # Horizontal Move
		# Check Up
		if end_r > 0:
			var n = v_board[end_r - 1][end_c]
			if n and (n.tile_type == type or n.tile_type == Tile.Type.DIAMOND): return true
		# Check Down
		if end_r < ROWS - 1:
			var n = v_board[end_r + 1][end_c]
			if n and (n.tile_type == type or n.tile_type == Tile.Type.DIAMOND): return true
			
	return false

func _evaluate_move(v_board: Array[Array], start: Vector2i, end: Vector2i) -> Dictionary:
	var result = {"valid": false, "green_size": 0, "score": 0.0}

	var t1 = v_board[start.x][start.y]
	if not t1: return result
	# Note: t2 is not simply the tile at end, because we shift, not swap.
	
	# Create a deep copy of the row or column to revert later easily
	# actually for speed, we'll just replicate the shift logic and revert it by shifting back?
	# Or simpler: Backup the affected line.
	
	# Determine if Row or Col
	var is_row = (start.x == end.x)
	var is_col = (start.y == end.y)
	
	if not is_row and not is_col: return result # Should not happen based on loop logic
	
	# Backup State
	var backup_line = []
	if is_row:
		for k in range(COLS): backup_line.append(v_board[start.x][k])
	else:
		for k in range(ROWS): backup_line.append(v_board[k][start.y])
		
	# -- PERFORM SHIFT on v_board (Logic copied/adapted from BoardManager) --
	if is_row:
		var r = start.x
		var mover_tile = v_board[r][start.y]
		if start.y < end.y:
			for k in range(start.y, end.y):
				v_board[r][k] = v_board[r][k + 1]
		else:
			for k in range(start.y, end.y, -1):
				v_board[r][k] = v_board[r][k - 1]
		v_board[r][end.y] = mover_tile
	
	elif is_col:
		var c = start.y
		var mover_tile = v_board[start.x][c]
		if start.x < end.x:
			for k in range(start.x, end.x):
				v_board[k][c] = v_board[k + 1][c]
		else:
			for k in range(start.x, end.x, -1):
				v_board[k][c] = v_board[k - 1][c]
		v_board[end.x][c] = mover_tile
	# -----------------------------------------------------------------------

	# Check Matches
	var matches = MatchUtils.find_matches(v_board, ROWS, COLS)
	if not matches.is_empty():
		result.valid = true
		var groups = MatchUtils.get_match_groups(matches, v_board, ROWS, COLS)

		var max_green = 0
		var total_score = 0.0

		for group in groups:
			if group.is_empty(): continue

			# Analyze Group
			var type = Tile.Type.DIAMOND
			var has_concrete = false
			for t in group:
				if t.tile_type != Tile.Type.DIAMOND:
					type = t.tile_type
					has_concrete = true
					break

			var size = group.size()

			# Priority 1: Green
			if has_concrete and type == Tile.Type.GREEN:
				if size > max_green: max_green = size

			# Priority 2: Score (Approx)
			var base_score = 10
			if level_manager: base_score = level_manager.get_tile_score(type)

			# Just sum base scores for estimation
			total_score += (base_score * size)

		result.green_size = max_green
		result.score = total_score

	# Revert State
	if is_row:
		for k in range(COLS): v_board[start.x][k] = backup_line[k]
	else:
		for k in range(ROWS): v_board[k][start.y] = backup_line[k]

	return result

func setup_camera():
	game_camera = Camera2D.new()
	game_camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(game_camera)
	
func shake_screen(intensity: float):
	shake_strength = max(shake_strength, intensity)

func spawn_floating_text(pos: Vector2, text: String, color: Color, scale: float = 1.0, outline_color: Color = Color.BLACK):
	var ft = preload("res://FloatingText.tscn").instantiate()
	get_parent().add_child(ft)
	# Add slight random jitter to prevent perfect stacking
	var jitter = Vector2(randf_range(-15, 15), randf_range(-15, 15))
	ft.global_position = pos + jitter
	ft.setup(text, color, scale, outline_color)


func _ready():
	level_manager = LevelManager.new()
	add_child(level_manager)
	level_manager.setup_run()
	
	setup_managers()
	setup_camera() # Keep valid ones, ensure no duplicates above
	
	# Handle Resizing First (Sets Grid Offset)
	get_tree().root.size_changed.connect(resize_game)
	resize_game()
	
	setup_background_grid()
	
	start_next_level()
	
	get_window().move_to_center()
	randomize()
	
	setup_ui_connections()
	
	update_ui() # Initial UI Set
	
	update_ui() # Initial UI Set
	setup_legend_ui()
	update_legend()

func get_upgrade_key(type: Tile.Type) -> String:
	match type:
		Tile.Type.RED: return "mult_red"
		Tile.Type.YELLOW: return "mult_yellow"
		Tile.Type.PURPLE: return "mult_purple"
		Tile.Type.ORANGE: return "mult_orange"
		Tile.Type.GREEN: return "mult_green"
		Tile.Type.BLUE: return "mult_blue"
	return ""

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
	
	# Update COLS based on upgrades
	if level_manager and level_manager.save_manager:
		var extra = level_manager.save_manager.get_upgrade_level("columns")
		COLS = 8 + extra
		
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
		reset_button.pressed.connect(restart_full_game)
		reset_button.visible = false

#region Resize Handling
func resize_game():
	var vp_size = get_viewport_rect().size
	var target_width = 1280.0
	var margin_x = max(0, (vp_size.x - target_width) / 2.0)
	
	# Update Board Visual
	var board_frame = $BoardFrame
	if board_frame:
		board_frame.size.x = (COLS * TILE_SIZE) + 40 # 20 padding each side
		board_frame.position.x = 45.0 + margin_x
		
	# Update Logic Offset
	# Revert to original Logic Offset causing "good alignment"
	GRID_OFFSET.x = 100.0 + margin_x
	
	# Propagate to Board Manager
	if board_manager:
		board_manager.GRID_OFFSET = GRID_OFFSET
		
		# Only try to reposition if board is initialized
		if not board_manager.board.is_empty() and board_manager.board.size() == ROWS:
			# Reposition existing tiles
			for r in range(ROWS):
				# Use actual array size to prevent crash if COLS increased but board not resized yet
				var row_size = board_manager.board[r].size()
				for c in range(row_size):
					var tile = board_manager.get_tile(r, c)
					if tile: tile.position = board_manager.grid_to_pixel(r, c)
	
	update_dock_layout()

func update_dock_layout():
	var dock = $HUD/UIContainer/SpellDock
	var board_frame = $BoardFrame
	
	if dock and board_frame:
		# Reset size constraints to allow shrinking
		dock.custom_minimum_size.x = 0
		dock.size.x = 0 # Force reset to min size
		
		var frame_center = board_frame.position.x + (board_frame.size.x / 2.0)
		var dock_width = dock.get_combined_minimum_size().x
		
		# Center based on actual content width
		dock.position.x = frame_center - (dock_width / 2.0)
		
		# Keep Y at bottom
		var vp_size = get_viewport_rect().size
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
	
	# Check for grid expansion
	if level_manager and level_manager.save_manager:
		var extra = level_manager.save_manager.get_upgrade_level("columns")
		COLS = 8 + extra
		if board_manager:
			board_manager.COLS = COLS
			
	setup_background_grid()
	resize_game()
	
	if log_label:
		log_label.text = "Welcome to ColorPop!"
	
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
			add_log("Select a BLACK tile!")
		elif mode == "harvest":
			add_log("Select Row to Harvest!")
		update_ui() # Update visuals for active state
#endregion

#region Core Mechanics (Delegated)
func attempt_move(start: Vector2i, end: Vector2i):
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
		if not is_relax_active():
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
	
	update_ui()
	await get_tree().create_timer(0.2).timeout
	board_manager.apply_gravity()
	await get_tree().create_timer(0.1).timeout
	board_manager.refill_board()
	
	# Reset Spawn Flags for next cascade step
	for r in range(ROWS):
		for c in range(COLS):
			var t = board_manager.get_tile(r, c)
			if t: t.is_newly_spawned = false
	
	await get_tree().create_timer(0.6).timeout
	resolve_matches()

func end_turn_processing():
	input_locked = false
	input_handler.set_state(InputHandler.State.IDLE)
	update_ui()
	check_game_over()

func process_match_group(group: Array):
	if group.is_empty(): return

	var match_count = group.size()
	
	# Robust Type Detection: Find first non-diamond
	var type = Tile.Type.DIAMOND # Default to Diamond if all are diamonds
	var has_concrete_type = false
	
	for t in group:
		if t.tile_type != Tile.Type.DIAMOND:
			type = t.tile_type
			has_concrete_type = true
			break
	
	var type_name = Tile.Type.keys()[type]
	var efficiency = max(1.0, (1.25) ** (match_count - 3))
	
	# Calculate center position for effects
	var center_pos = Vector2.ZERO
	if not group.is_empty():
		for t in group: center_pos += t.global_position
		center_pos /= group.size()
	
	# Discovery
	if has_concrete_type and level_manager:
		level_manager.mark_discovered(type)
	
	# Scoring
	var match_score = 0.0
	var base_score = 10
	if level_manager: base_score = level_manager.get_tile_score(type)
	
	var group_upgrade_mult = 1.0
	if has_concrete_type:
		var t_key = get_upgrade_key(type)
		if t_key != "" and level_manager:
			var t_level = level_manager.save_manager.get_upgrade_level(t_key)
			group_upgrade_mult = (1.0 + (t_level * 0.1))
	
	# 2x Multiplier per Diamond
	var diamond_count = 0
	for t in group:
		if t.tile_type == Tile.Type.DIAMOND:
			diamond_count += 1
			
	var diamond_mult = 1.0
	if diamond_count > 0:
		diamond_mult = pow(2, diamond_count)
	
	for t in group:
		var tile_pts = 0.0
		var is_diamond = (t.tile_type == Tile.Type.DIAMOND)
		
		# Diamond Reward Logic (Log +1)
		if is_diamond:
			if level_manager and level_manager.save_manager:
				level_manager.save_manager.add_diamonds(1)
				spawn_floating_text(t.global_position, "+1 Diamond!", Color(0, 1, 1), 0.8)
				
		if not has_concrete_type:
			tile_pts = 300
		else:
			tile_pts = base_score * multiplier * efficiency * group_upgrade_mult
		
		match_score += tile_pts
		
	# Apply Diamond Multiplier to TOTAL match score
	match_score *= diamond_mult
		
	# Check if Visual Effects are enabled
	var fx_enabled = true
	if level_manager and level_manager.save_manager:
		fx_enabled = level_manager.save_manager.get_setting("visual_effects_enabled", true)

	# Side Effects (Green/Blue/Black)
	if has_concrete_type:
		if type == Tile.Type.BLACK:
			# Black tiles are negative points or just penalties? 
			# Assuming they have a score value defined in LevelManager (usually negative)
			# Show the score text specifically for Black
			if fx_enabled:
				spawn_floating_text(center_pos, "%s" % Utils.format_currency(match_score), Color.BLACK, 1.2, Color.WHITE) # White outline for black text
			
		if type == Tile.Type.GREEN:
			green_matched_this_turn = true
			var gain = 0.1 * match_count * efficiency * diamond_mult
			
			if level_manager:
				var up_level = level_manager.save_manager.get_upgrade_level("mult_green")
				gain = (gain / diamond_mult) * (1.0 + (up_level * 0.1))
			
			multiplier += gain
			add_log("Matched %d GREEN! Mult +%.2f -> %.2fx" % [match_count, gain, multiplier])
			if fx_enabled:
				spawn_floating_text(center_pos + Vector2(0, -20), "+%.2fx Mult" % gain, Color.GREEN)
		
		if type == Tile.Type.BLUE:
			var gain = match_count * 5 * efficiency
			if level_manager:
				var up_level = level_manager.save_manager.get_upgrade_level("mult_blue")
				gain *= (1.0 + (up_level * 0.1))
			mana = min(get_max_mana(), mana + gain)
			add_log("Matched %d BLUE! +%d Mana" % [match_count, int(gain)])
			if fx_enabled:
				spawn_floating_text(center_pos + Vector2(0, 20), "+%d Mana" % int(gain), Color.BLUE, 1.0, Color.WHITE)

	score = max(0, score + match_score)
	
	if fx_enabled:
		# FX: Screen Shake
		if match_count >= 4:
			var shake = 0.0
			if match_count == 4: shake = 5.0
			else: shake = 5.0 + ((match_count - 4) * 4.0)
			shake_screen(min(shake, 35.0))
			
		# FX: Particles
		if MatchParticlesScene:
			var parts = MatchParticlesScene.instantiate()
			add_child(parts)
			parts.global_position = center_pos
			var p_color = TILE_COLORS.get(type, Color.WHITE)
			
			if parts is CPUParticles2D:
				parts.color = p_color
			elif parts is GPUParticles2D and parts.process_material is ParticleProcessMaterial:
				parts.process_material.color = p_color
				
		# FX: Main Score Text (Skip for Black since we handled it above specially, OR ensure we don't double dip)
		if match_score != 0 and type != Tile.Type.BLACK: # Black uses special negative formatting above
			var txt_color = TILE_COLORS.get(type, Color.WHITE)
			if match_score < 0:
				spawn_floating_text(center_pos, "%s" % Utils.format_currency(match_score), txt_color, 1.2)
			else:
				spawn_floating_text(center_pos, "+%s" % Utils.format_currency(match_score), txt_color, 1.2)
	
	if match_score != 0:
		var log_msg = "Matched %d %s! Pts: %s" % [match_count, type_name, Utils.format_currency(match_score)]
		if diamond_count > 0:
			log_msg += "\n(Diamond Bonus: x%d! +%d Diamond)" % [int(diamond_mult), diamond_count]
		add_log(log_msg)
	
	if sound_manager: sound_manager.play_match(match_count, type)

	# Default Removal / Spawn Logic
	var diamond_level = 0
	if level_manager:
		diamond_level = level_manager.save_manager.get_upgrade_level("super_diamond")
	
	var spawn_chance = diamond_level * 0.01 # 1% per level
	var can_spawn = (match_count > 3)
	
	for tile in group:
		var spawned = false
		if can_spawn and diamond_level > 0 and tile.tile_type != Tile.Type.DIAMOND:
			if randf() < spawn_chance:
				tile.tile_type = Tile.Type.DIAMOND
				tile.update_visuals()
				spawned = true
				if sound_manager: sound_manager.play_cast()
				add_log("SUPER DIAMOND SPAWNED!")
				spawn_floating_text(tile.global_position, "Super Diamond!", Color(0, 1, 1), 1.5)
		
		if not spawned:
			if is_instance_valid(tile) and not tile.is_queued_for_deletion():
				board_manager.remove_tile_at(tile.coordinates)
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
		
		# Immediately lock input to clear highlight and prevent interaction
		input_handler.set_state(InputHandler.State.LOCKED)
		
		if sound_manager: sound_manager.play_cast()
		
		add_log("Harvesting Row %d!" % row_idx)
		
		# Collect and Group tiles by type
		var tiles_to_remove = []
		var type_groups = {}
		var diamonds = []
		
		# First Pass: Collect Tiles and Separate Diamonds
		for c in range(COLS):
			var t = board_manager.get_tile(row_idx, c)
			if t:
				if t.tile_type == Tile.Type.DIAMOND:
					diamonds.append(t)
				elif t.tile_type != Tile.Type.BLACK:
					if not type_groups.has(t.tile_type):
						type_groups[t.tile_type] = []
					type_groups[t.tile_type].append(t)
				
				tiles_to_remove.append(t)
		
		# Second Pass: Distribute Diamonds to ALL groups (Wildcard behavior)
		if type_groups.is_empty():
			# Special Case: Only Diamonds (or Diamonds + Black)
			if not diamonds.is_empty():
				type_groups[Tile.Type.DIAMOND] = diamonds
		else:
			# Add every diamond to every existing color group
			for type in type_groups:
				for d in diamonds:
					type_groups[type].append(d)
		
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

# Helpers
func add_log(msg: String):
	if log_label:
		log_label.text += "\n" + msg

func setup_background_grid():
	var grid_bg = $BoardFrame/GridBackground
	if not grid_bg: return
	
	# Update columns to match dynamic grid
	grid_bg.columns = COLS
	
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
		
		# Calculate Skips
		var excess = score - level_manager.get_current_target()
		var skips = level_manager.calculate_level_skips(excess)
		var next_lvl = level_manager.current_level + 1 + skips

		# Show Screen
		var complete_scn = preload("res://LevelComplete.tscn").instantiate()
		complete_scn.name = "LevelComplete"
		ui_container.add_child(complete_scn)
		complete_scn.setup(rewards, score, turns_left, level_manager.current_level, next_lvl, sound_manager)
		
		# Lock Board Input
		input_handler.set_state(InputHandler.State.LOCKED)
		
		complete_scn.continued.connect(func():
			level_manager.advance_level(1 + skips)
			complete_scn.queue_free()
			start_next_level()
		)

		if is_relax_active():
			complete_scn.animation_completed.connect(func():
				if not is_instance_valid(complete_scn): return
				get_tree().create_timer(5.0, false).timeout.connect(func():
					if is_instance_valid(complete_scn) and ui_container.has_node("LevelComplete"):
						level_manager.advance_level(1 + skips)
						complete_scn.queue_free()
						start_next_level()
				)
			)
		
	elif turns <= 0:
		# Game Over Logic
		if sound_manager: sound_manager.play_error()
		input_handler.set_state(InputHandler.State.LOCKED)
		
		# Update High Score
		if level_manager and level_manager.save_manager:
			level_manager.save_manager.update_highest_level(level_manager.current_level)
		
		# Award Gold for Failure (Consolation)
		var rewards = {"gold": 0}
		if level_manager:
			rewards = level_manager.complete_level(score, 0) # 0 turns left
		
		# Show Game Over Screen
		var game_over_scn = preload("res://GameOver.tscn").instantiate()
		game_over_scn.name = "GameOver"
		ui_container.add_child(game_over_scn)
		
		var best_lvl = 1
		if level_manager and level_manager.save_manager:
			best_lvl = level_manager.save_manager.get_highest_level()
			
		game_over_scn.setup(level_manager.current_level, best_lvl, "Out of Turns!", rewards.get("gold", 0))
		
		game_over_scn.restart_requested.connect(func():
			game_over_scn.queue_free()
			restart_full_game()
		)

func restart_full_game():
	if level_manager:
		level_manager.setup_run() # Reset to Level 1
	start_next_level()

func update_ui():
	if level_label and level_manager: level_label.text = "Level: %d" % level_manager.current_level
	if score_text and level_manager:
		score_text.text = "%s / %s" % [Utils.format_currency(score, 1000000000.0), Utils.format_currency(level_manager.get_current_target(), 1000000000.0)]
	if score_bar: score_bar.value = score
	if turns_label: turns_label.text = "Turns: %d" % turns
	if multi_label: multi_label.text = "Multiplier: %.2fx" % multiplier
	if gold_label and level_manager:
		gold_label.text = Utils.format_currency(level_manager.save_manager.get_gold())
	if diam_label and level_manager:
		diam_label.text = Utils.format_currency(level_manager.save_manager.get_diamonds())
	
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
			spell_button.remove_theme_color_override("font_color")
			spell_button.remove_theme_color_override("font_hover_color")
			spell_button.remove_theme_color_override("font_pressed_color")
			spell_button.remove_theme_color_override("font_focus_color")
		elif mana >= cost:
			# Available State
			spell_button.disabled = false
			spell_button.modulate = Color(1, 1, 1) # Normal
			spell_button.add_theme_color_override("font_color", Color.GREEN)
			spell_button.add_theme_color_override("font_hover_color", Color.GREEN)
			spell_button.add_theme_color_override("font_pressed_color", Color.GREEN)
			spell_button.add_theme_color_override("font_focus_color", Color.GREEN)
		else:
			# Disabled State
			spell_button.disabled = true
			spell_button.modulate = Color(1, 1, 1) # Normal dimming handles by disabled
			spell_button.remove_theme_color_override("font_color")
			spell_button.remove_theme_color_override("font_hover_color")
			spell_button.remove_theme_color_override("font_pressed_color")
			spell_button.remove_theme_color_override("font_focus_color")
			
	# Harvest Button
	if harvest_button:
		if level_manager and level_manager.save_manager.get_upgrade_level("harvest") > 0:
			harvest_button.visible = true
			var h_cost = 50
			harvest_button.text = "Harvest (%d)" % h_cost
			
			if active_spell == "harvest":
				harvest_button.disabled = false
				harvest_button.modulate = Color(0.6, 1.0, 0.6) # Green
				harvest_button.remove_theme_color_override("font_color")
				harvest_button.remove_theme_color_override("font_hover_color")
				harvest_button.remove_theme_color_override("font_pressed_color")
				harvest_button.remove_theme_color_override("font_focus_color")
			elif mana >= h_cost:
				harvest_button.disabled = false
				harvest_button.modulate = Color(1, 1, 1)
				harvest_button.add_theme_color_override("font_color", Color.GREEN)
				harvest_button.add_theme_color_override("font_hover_color", Color.GREEN)
				harvest_button.add_theme_color_override("font_pressed_color", Color.GREEN)
				harvest_button.add_theme_color_override("font_focus_color", Color.GREEN)
			else:
				harvest_button.disabled = true
				harvest_button.modulate = Color(1, 1, 1)
				harvest_button.remove_theme_color_override("font_color")
				harvest_button.remove_theme_color_override("font_hover_color")
				harvest_button.remove_theme_color_override("font_pressed_color")
				harvest_button.remove_theme_color_override("font_focus_color")
		else:
			harvest_button.visible = false
	
	update_legend()
	update_dock_layout()

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

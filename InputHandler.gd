class_name InputHandler
extends Node

signal move_requested(start: Vector2i, end: Vector2i)
signal spell_cast_requested(grid_pos: Vector2i)
signal harvest_requested(row_idx: int)

enum State {IDLE, DRAGGING, CASTING, LOCKED}
var current_state: State = State.IDLE

var board_manager: BoardManager
var level_manager: LevelManager # For settings
var container: Node2D # Where to draw highlights

var selected_tile_coord: Vector2i = Vector2i(-1, -1)
var active_spell_type: String = "catalyst"

# Visuals
var highlight_rect: Line2D
var row_highlight: ColorRect
var col_highlight: ColorRect
var harvest_highlight: ColorRect

const TILE_SIZE = 70

func setup(bm: BoardManager, lm: LevelManager, visual_container: Node2D):
	board_manager = bm
	level_manager = lm
	container = visual_container

func set_state(state: State):
	if current_state == State.DRAGGING and state != State.DRAGGING:
		cancel_drag()
		
	current_state = state
	if state == State.IDLE or state == State.LOCKED:
		cleanup_highlights()
		selected_tile_coord = Vector2i(-1, -1)
		
func set_spell_mode(mode: String):
	if current_state == State.DRAGGING:
		cancel_drag()
		
	active_spell_type = mode
	current_state = State.CASTING
	cleanup_highlights()

func cleanup_highlights():
	if highlight_rect:
		highlight_rect.queue_free()
		highlight_rect = null
	if row_highlight:
		row_highlight.queue_free()
		row_highlight = null
	if col_highlight:
		col_highlight.queue_free()
		col_highlight = null
	if harvest_highlight:
		harvest_highlight.queue_free()
		harvest_highlight = null

func _input(event):
	if current_state == State.LOCKED: return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var grid_pos = board_manager.pixel_to_grid(event.position)
			if board_manager.is_valid_coord(grid_pos):
				# Only handle click if valid coord
				handle_click(grid_pos, event.position)
			else:
				pass
		else:
			handle_click_release(event.position)
			
	elif event is InputEventMouseMotion:
		handle_motion(event.position)

func handle_click(grid_pos: Vector2i, _pos: Vector2):
	if current_state == State.CASTING:
		if active_spell_type == "catalyst":
			emit_signal("spell_cast_requested", grid_pos)
		elif active_spell_type == "harvest":
			emit_signal("harvest_requested", grid_pos.x)
		return
		
	if current_state == State.IDLE:
		cleanup_highlights()
		selected_tile_coord = grid_pos
		current_state = State.DRAGGING
		
		create_highlights(grid_pos)
		
		# Visual Feedback
		var tile = board_manager.get_tile(grid_pos.x, grid_pos.y)
		if tile: tile.z_index = 10

func handle_motion(pos: Vector2):
	if current_state == State.DRAGGING:
		if selected_tile_coord != Vector2i(-1, -1):
			var tile = board_manager.get_tile(selected_tile_coord.x, selected_tile_coord.y)
			if tile:
				tile.position = pos
				
				var target_grid = board_manager.pixel_to_grid(pos)
				if board_manager.is_valid_coord(target_grid):
					update_preview(selected_tile_coord, target_grid)
					
	elif current_state == State.CASTING and active_spell_type == "harvest":
		var grid_pos = board_manager.pixel_to_grid(pos)
		update_harvest_preview(grid_pos)

func handle_click_release(pos: Vector2):
	if current_state == State.DRAGGING:
		var end_grid_pos = board_manager.pixel_to_grid(pos)
		
		var valid = false
		if board_manager.is_valid_coord(end_grid_pos):
			if selected_tile_coord != end_grid_pos:
				# Orthogonal check
				if selected_tile_coord.x == end_grid_pos.x or selected_tile_coord.y == end_grid_pos.y:
					valid = true
		
		if valid:
			# Visual reset is handled by BoardManager shift or Revert (which calls set_state)
			var tile = board_manager.get_tile(selected_tile_coord.x, selected_tile_coord.y)
			if tile: tile.z_index = 0
			
			var start_coord = selected_tile_coord
			
			# Transition to IDLE BEFORE emitting signal to prevent set_state(LOCKED) from triggering cancel_drag
			cleanup_highlights()
			current_state = State.IDLE
			selected_tile_coord = Vector2i(-1, -1)
			
			emit_signal("move_requested", start_coord, end_grid_pos)
			
		else:
			cancel_drag()
			current_state = State.IDLE

func cancel_drag():
	cleanup_highlights()
	if selected_tile_coord != Vector2i(-1, -1):
		var tile = board_manager.get_tile(selected_tile_coord.x, selected_tile_coord.y)
		if tile:
			tile.z_index = 0
			# Snap back
			tile.position = board_manager.grid_to_pixel(selected_tile_coord.x, selected_tile_coord.y)
	
	update_preview(Vector2i(-1, -1), Vector2i(-1, -1)) # Reset board
	selected_tile_coord = Vector2i(-1, -1)

# Visual Helpers
func create_highlights(grid_pos: Vector2i):
	var tile = board_manager.get_tile(grid_pos.x, grid_pos.y)
	if not tile: return
	
	highlight_rect = Line2D.new()
	highlight_rect.default_color = Color(1, 1, 1, 0.5)
	highlight_rect.width = 4.0
	highlight_rect.closed = true
	var s = (TILE_SIZE / 2.0) - 4
	highlight_rect.points = [Vector2(-s, -s), Vector2(s, -s), Vector2(s, s), Vector2(-s, s)]
	highlight_rect.position = tile.position
	container.add_child(highlight_rect)
	
	var show_highlights = true
	if level_manager and level_manager.save_manager:
		show_highlights = level_manager.save_manager.get_setting("highlight_enabled", true)
		
	if show_highlights:
		row_highlight = ColorRect.new()
		row_highlight.color = Color(1, 1, 1, 0.2)
		var row_pos = board_manager.grid_to_pixel(grid_pos.x, 0)
		row_highlight.position = Vector2(row_pos.x - TILE_SIZE / 2, row_pos.y - TILE_SIZE / 2)
		row_highlight.size = Vector2(board_manager.COLS * TILE_SIZE, TILE_SIZE)
		row_highlight.z_index = 1
		container.add_child(row_highlight)
		
		col_highlight = ColorRect.new()
		col_highlight.color = Color(1, 1, 1, 0.2)
		var col_pos = board_manager.grid_to_pixel(0, grid_pos.y)
		col_highlight.position = Vector2(col_pos.x - TILE_SIZE / 2, col_pos.y - TILE_SIZE / 2)
		col_highlight.size = Vector2(TILE_SIZE, board_manager.ROWS * TILE_SIZE)
		col_highlight.z_index = 1
		container.add_child(col_highlight)

func update_harvest_preview(grid_pos: Vector2i):
	if board_manager.is_valid_coord(grid_pos):
		if not harvest_highlight:
			harvest_highlight = ColorRect.new()
			harvest_highlight.color = Color(1.0, 0.0, 0.0, 0.3)
			harvest_highlight.z_index = 5
			container.add_child(harvest_highlight)
		
		var row_pos = board_manager.grid_to_pixel(grid_pos.x, 0)
		harvest_highlight.position = Vector2(row_pos.x - TILE_SIZE / 2, row_pos.y - TILE_SIZE / 2)
		harvest_highlight.size = Vector2(board_manager.COLS * TILE_SIZE, TILE_SIZE)
		harvest_highlight.visible = true
	else:
		if harvest_highlight: harvest_highlight.visible = false

func update_preview(start: Vector2i, curr: Vector2i):
	# Reset all
	for r in range(board_manager.ROWS):
		for c in range(board_manager.COLS):
			var t = board_manager.get_tile(r, c)
			if t and Vector2i(r, c) != start:
				t.position = board_manager.grid_to_pixel(r, c)
	
	# Apply shift
	if start.x == curr.x: # Row
		if start.y < curr.y:
			for c in range(start.y, curr.y):
				var t = board_manager.get_tile(start.x, c + 1)
				if t: t.position = board_manager.grid_to_pixel(start.x, c)
		elif start.y > curr.y:
			for c in range(start.y, curr.y, -1):
				var t = board_manager.get_tile(start.x, c - 1)
				if t: t.position = board_manager.grid_to_pixel(start.x, c)
	elif start.y == curr.y: # Col
		if start.x < curr.x:
			for r in range(start.x, curr.x):
				var t = board_manager.get_tile(r + 1, start.y)
				if t: t.position = board_manager.grid_to_pixel(r, start.y)
		elif start.x > curr.x:
			for r in range(start.x, curr.x, -1):
				var t = board_manager.get_tile(r - 1, start.y)
				if t: t.position = board_manager.grid_to_pixel(r, start.y)

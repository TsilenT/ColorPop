class_name BoardManager
extends Node

# Signals

# Constants (Shared with Game, or passed in)
var COLS = 8
const ROWS = 8
const TILE_SIZE = 70
var GRID_OFFSET = Vector2(100, 100)

var board: Array[Array] = []
var board_container: Node2D
var tile_scene: PackedScene
var level_manager: LevelManager

func setup(container: Node2D, t_scene: PackedScene, lm: LevelManager, offset: Vector2):
	board_container = container
	tile_scene = t_scene
	level_manager = lm
	GRID_OFFSET = offset
	if level_manager:
		var extra = level_manager.save_manager.get_upgrade_level("columns")
		COLS = 8 + extra
	
	# initialize_board() <- Called by Game.start_next_level() explicitly

func initialize_board():
	for child in board_container.get_children():
		child.queue_free()
	
	board.resize(ROWS)
	for r in range(ROWS):
		board[r] = []
		board[r].resize(COLS)
		for c in range(COLS):
			var type = get_weighted_random_type()
			# Prevent initial matches
			while (c >= 2 and board[r][c - 1].tile_type == type and board[r][c - 2].tile_type == type) or \
				  (r >= 2 and board[r - 1][c].tile_type == type and board[r - 2][c].tile_type == type):
				type = get_weighted_random_type()
			
			# Spawn and animate with staggered column heights
			spawn_tile(r, c, type)
			var t = board[r][c]
			if t:
				# Stagger: Left column starts low (-400), Right column starts high (-400 - (7 * 100) = -1100)
				var stagger_offset = 400 + (c * 100)
				t.position.y -= stagger_offset
				animate_tile(t, r, c)
			
func spawn_tile(r: int, c: int, type_override = null):
	var tile = tile_scene.instantiate()
	
	if type_override != null:
		tile.tile_type = type_override
	else:
		tile.tile_type = get_weighted_random_type()
		
	tile.coordinates = Vector2i(r, c)
	tile.position = grid_to_pixel(r, c)
	board_container.add_child(tile)
	board[r][c] = tile

func get_weighted_random_type() -> int: # Tile.Type
	# Determine weights
	var weights = {
		0: 1.0, # RED
		1: 1.0, # YELLOW
		2: 0.5, # GREEN
		3: 1.0, # BLUE
		5: 1.0, # PURPLE
		6: 1.0, # ORANGE
		4: 0.5 # BLACK
	}
	
	# Cinderella Upgrade Check
	if level_manager:
		var cinderella_level = level_manager.save_manager.get_upgrade_level("cinderella")
		if cinderella_level > 0:
			var multiplier = 1.0 + (0.25 * cinderella_level)
			weights[2] = weights[2] * multiplier # GREEN
		
	var total_weight = 0.0
	for w in weights.values():
		total_weight += w
		
	var roll = randf() * total_weight
	var current = 0.0
	for type in weights:
		current += weights[type]
		if roll <= current:
			return type
	
	return 0 # RED

# Coordinates
func grid_to_pixel(r: int, c: int) -> Vector2:
	return Vector2(c * TILE_SIZE, r * TILE_SIZE) + GRID_OFFSET

func pixel_to_grid(pos: Vector2) -> Vector2i:
	var local_pos = pos - GRID_OFFSET
	var c = int(round(local_pos.x / TILE_SIZE))
	var r = int(round(local_pos.y / TILE_SIZE))
	return Vector2i(r, c)

func is_valid_coord(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.x < ROWS and coord.y >= 0 and coord.y < COLS

# Actions
func perform_shift(start: Vector2i, end: Vector2i, sound_manager = null):
	var mover_tile = board[start.x][start.y]
	
	if start.x == end.x: # Row
		var r = start.x
		if start.y < end.y:
			for c in range(start.y, end.y):
				shift_tile_data(r, c + 1, r, c)
		else:
			for c in range(start.y, end.y, -1):
				shift_tile_data(r, c - 1, r, c)
		board[r][end.y] = mover_tile
		animate_tile(mover_tile, r, end.y)
		if sound_manager: sound_manager.play_slide()
		
	elif start.y == end.y: # Col
		var c = start.y
		if start.x < end.x:
			for r in range(start.x, end.x):
				shift_tile_data(r + 1, c, r, c)
		else:
			for r in range(start.x, end.x, -1):
				shift_tile_data(r - 1, c, r, c)
		board[end.x][c] = mover_tile
		animate_tile(mover_tile, end.x, c)
		if sound_manager: sound_manager.play_slide()

func shift_tile_data(from_r, from_c, to_r, to_c):
	var t = board[from_r][from_c]
	board[to_r][to_c] = t
	animate_tile(t, to_r, to_c)

func animate_tile(tile: Node2D, r: int, c: int):
	if not is_instance_valid(tile): return
	
	tile.coordinates = Vector2i(r, c)
	
	# Kill existing tween to prevent conflicts (Ghost/Lagging tiles)
	if tile.has_meta("tween"):
		var old: Tween = tile.get_meta("tween")
		if old and old.is_valid(): old.kill()
		
	var tween = create_tween()
	tile.set_meta("tween", tween)
	
	var target_pos = grid_to_pixel(r, c)
	var distance = tile.position.distance_to(target_pos)
	
	# Dynamic Duration: Base 0.2s, plus time for distance
	# e.g. 500px / 1500 speed = 0.33s -> total 0.53s
	var duration = clamp(0.15 + (distance / 1200.0), 0.2, 0.6)
	
	tween.tween_property(tile, "position", target_pos, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

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

func get_tile(r: int, c: int):
	if is_valid_coord(Vector2i(r, c)):
		return board[r][c]
	return null

func remove_tile_at(coord: Vector2i):
	var tile = board[coord.x][coord.y]
	if tile:
		board[coord.x][coord.y] = null
		tile.queue_free()

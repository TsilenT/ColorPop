class_name AutoMatcher
extends RefCounted


static func find_best_move(board_manager: BoardManager, level_manager: LevelManager, rows: int, cols: int) -> Dictionary:
	var best_move_start = Vector2i(-1, -1)
	var best_move_end = Vector2i(-1, -1)

	var best_green_size = -1
	var best_score = -1.0

	# Create a lightweight virtual board representation for simulation
	# We just need types.
	var virtual_board: Array[Array] = []
	for r in range(rows):
		var row = []
		for c in range(cols):
			var t = board_manager.get_tile(r, c)
			if t: row.append(t) # Storing references for MatchUtils compatibility
			else: row.append(null)
		virtual_board.append(row)

	for r in range(rows):
		for c in range(cols):
			# Row Moves (Try moving to every other column in SAME ROW)
			for target_c in range(cols):
				if c == target_c: continue
				
				# Optimization: Pruning
				if not _has_potential_match(virtual_board, r, c, r, target_c, rows, cols):
					continue
				
				var res = _evaluate_move(virtual_board, Vector2i(r, c), Vector2i(r, target_c), rows, cols, level_manager)
				if res.valid:
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
			for target_r in range(rows):
				if r == target_r: continue
				
				# Optimization: Pruning
				if not _has_potential_match(virtual_board, r, c, target_r, c, rows, cols):
					continue
				
				var res = _evaluate_move(virtual_board, Vector2i(r, c), Vector2i(target_r, c), rows, cols, level_manager)
				if res.valid:
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

	return {"start": best_move_start, "end": best_move_end}

# Optimization Helper: Checks if moving tile at start->end has any chance of matching
# Checks perpendicular neighbors at destination.
static func _has_potential_match(v_board: Array, start_r: int, start_c: int, end_r: int, end_c: int, rows: int, cols: int) -> bool:
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
		if end_c < cols - 1:
			var n = v_board[end_r][end_c + 1]
			if n and (n.tile_type == type or n.tile_type == Tile.Type.DIAMOND): return true
		
	# If moving Horizontally (Col Change), check Up/Down neighbors at End Col
	elif start_r == end_r: # Horizontal Move
		# Check Up
		if end_r > 0:
			var n = v_board[end_r - 1][end_c]
			if n and (n.tile_type == type or n.tile_type == Tile.Type.DIAMOND): return true
		# Check Down
		if end_r < rows - 1:
			var n = v_board[end_r + 1][end_c]
			if n and (n.tile_type == type or n.tile_type == Tile.Type.DIAMOND): return true
			
	return false

static func _evaluate_move(v_board: Array[Array], start: Vector2i, end: Vector2i, rows: int, cols: int, level_manager: LevelManager) -> Dictionary:
	var result = {"valid": false, "green_size": 0, "score": 0.0}

	var t1 = v_board[start.x][start.y]
	if not t1: return result
	
	# Determine if Row or Col
	var is_row = (start.x == end.x)
	var is_col = (start.y == end.y)
	
	if not is_row and not is_col: return result # Should not happen based on loop logic
	
	# Backup State
	var backup_line = []
	if is_row:
		for k in range(cols): backup_line.append(v_board[start.x][k])
	else:
		for k in range(rows): backup_line.append(v_board[k][start.y])
		
	# -- PERFORM SHIFT on v_board --
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
	var matches = MatchUtils.find_matches(v_board, rows, cols)
	if not matches.is_empty():
		result.valid = true
		var groups = MatchUtils.get_match_groups(matches, v_board, rows, cols)

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
		for k in range(cols): v_board[start.x][k] = backup_line[k]
	else:
		for k in range(rows): v_board[k][start.y] = backup_line[k]

	return result

class_name MatchUtils

static func find_matches(board: Array[Array], rows: int, cols: int) -> Array[Node2D]:
	var matched: Array[Node2D] = []
	# Horizontal
	for r in range(rows):
		for c in range(cols-2):
			var t1 = board[r][c]; var t2 = board[r][c+1]; var t3 = board[r][c+2]
			if t1 and t2 and t3 and t1.tile_type == t2.tile_type and t2.tile_type == t3.tile_type:
				if not t1 in matched: matched.append(t1)
				if not t2 in matched: matched.append(t2)
				if not t3 in matched: matched.append(t3)
	# Vertical
	for c in range(cols):
		for r in range(rows-2):
			var t1 = board[r][c]; var t2 = board[r+1][c]; var t3 = board[r+2][c]
			if t1 and t2 and t3 and t1.tile_type == t2.tile_type and t2.tile_type == t3.tile_type:
				if not t1 in matched: matched.append(t1)
				if not t2 in matched: matched.append(t2)
				if not t3 in matched: matched.append(t3)
	return matched

static func get_match_groups(tiles: Array[Node2D], board: Array[Array], rows: int, cols: int) -> Array[Array]:
	var groups: Array[Array] = []
	var visited = {}
	for t in tiles:
		if visited.has(t): continue
		var group = []
		var stack = [t]
		visited[t] = true
		var type = t.tile_type
		while not stack.is_empty():
			var curr = stack.pop_back()
			group.append(curr)
			for n in get_neighbors(curr, board, rows, cols):
				if n in tiles and not visited.has(n) and n.tile_type == type:
					visited[n] = true
					stack.append(n)
		groups.append(group)
	return groups

static func get_neighbors(tile: Node2D, board: Array[Array], rows: int, cols: int) -> Array:
	var list = []
	var r = tile.coordinates.x; var c = tile.coordinates.y
	for d in [Vector2i(0,1), Vector2i(0,-1), Vector2i(1,0), Vector2i(-1,0)]:
		var nr = r + d.x; var nc = c + d.y
		if nr >= 0 and nr < rows and nc >= 0 and nc < cols:
			if board[nr][nc]: list.append(board[nr][nc])
	return list

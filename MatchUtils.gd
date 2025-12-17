class_name MatchUtils

static func find_matches(board: Array[Array], rows: int, cols: int) -> Array[Node2D]:
	var matched: Array[Node2D] = []
	# Horizontal
	for r in range(rows):
		for c in range(cols - 2):
			var t1 = board[r][c]; var t2 = board[r][c + 1]; var t3 = board[r][c + 2]
			if t1 and t2 and t3:
				if are_compatible_3(t1, t2, t3):
					if not t1 in matched: matched.append(t1)
					if not t2 in matched: matched.append(t2)
					if not t3 in matched: matched.append(t3)
	# Vertical
	for c in range(cols):
		for r in range(rows - 2):
			var t1 = board[r][c]; var t2 = board[r + 1][c]; var t3 = board[r + 2][c]
			if t1 and t2 and t3:
				if are_compatible_3(t1, t2, t3):
					if not t1 in matched: matched.append(t1)
					if not t2 in matched: matched.append(t2)
					if not t3 in matched: matched.append(t3)
	return matched

static func are_compatible_3(t1: Node2D, t2: Node2D, t3: Node2D) -> bool:
	var types = [t1.tile_type, t2.tile_type, t3.tile_type]
	return get_common_type(types) != -1

static func get_common_type(types: Array) -> int:
	var common = -1 # -1 means "undetermined" (could be anything if only diamonds seen so far)
	
	for t in types:
		if t == Tile.Type.DIAMOND:
			continue # Wildcard matches anything
		
		if common == -1:
			common = t
		elif common != t:
			return -1 # Incompatible types found (e.g. RED and BLUE)
			
	if common == -1: return Tile.Type.DIAMOND # If all were diamonds
	return common

static func get_match_groups(tiles: Array[Node2D], board: Array[Array], rows: int, cols: int) -> Array[Array]:
	# We can't just flood fill because Diamond connects Red and Blue, 
	# but we want [Red, Diamond, Red] and [Blue, Diamond, Blue] as SEPARATE groups.
	# Step 1: Find all horizontal and vertical match segments.
	# A segment is a list of connected tiles that are compatible.
	var segments: Array[Array] = []
	
	# Horizontal segments
	for r in range(rows):
		var current_seg = []
		for c in range(cols):
			var t = board[r][c]
			if not t or not (t in tiles):
				if current_seg.size() >= 3: segments.append(current_seg)
				current_seg = []
				continue
			
			if current_seg.is_empty():
				current_seg.append(t)
			else:
				var last = current_seg[-1]
				if are_compatible_2(last, t):
					current_seg.append(t)
				else:
					if current_seg.size() >= 3: segments.append(current_seg)
					current_seg = [t]
		if current_seg.size() >= 3: segments.append(current_seg)
	
	# Vertical segments
	for c in range(cols):
		var current_seg = []
		for r in range(rows):
			var t = board[r][c]
			if not t or not (t in tiles):
				if current_seg.size() >= 3: segments.append(current_seg)
				current_seg = []
				continue
			
			if current_seg.is_empty():
				current_seg.append(t)
			else:
				var last = current_seg[-1]
				if are_compatible_2(last, t):
					current_seg.append(t)
				else:
					if current_seg.size() >= 3: segments.append(current_seg)
					current_seg = [t]
		if current_seg.size() >= 3: segments.append(current_seg)

	# Step 2: Merge intersecting segments ONLY if they are color-compatible.
	# We can represent segments as "Proto-Groups".
	# If Segment A and Segment B share a tile (intersect):
	#   Get "Concrete Color" of A.
	#   Get "Concrete Color" of B.
	#   If Compatible, Merge.
	#   Else, Keep separate (Diamond stays in both).
	
	var final_groups: Array[Array] = []
	var processed_segments = [] # Track which indices are merged
	
	# Helper to get segment color (first non-diamond)
	var get_seg_type = func(seg):
		for t in seg:
			if t.tile_type != Tile.Type.DIAMOND: return t.tile_type
		return Tile.Type.DIAMOND # Pure diamond
	
	for i in range(segments.size()):
		if i in processed_segments: continue
		
		var current_group = segments[i].duplicate()
		var current_type = get_seg_type.call(current_group)
		processed_segments.append(i)
		
		# Iteratively try to merge other segments
		var changed = true
		while changed:
			changed = false
			for j in range(segments.size()):
				if j in processed_segments: continue
				
				var seg = segments[j]
				var seg_type = get_seg_type.call(seg)
				
				# Check if types are compatible
				var types_ok = false
				if current_type == Tile.Type.DIAMOND or seg_type == Tile.Type.DIAMOND:
					types_ok = true
				elif current_type == seg_type:
					types_ok = true
				
				if not types_ok: continue
				
				# Check intersection (share at least one tile)
				var intersects = false
				for t in seg:
					if t in current_group:
						intersects = true
						break
				
				if intersects:
					# Merge!
					for t in seg:
						if not t in current_group:
							current_group.append(t)
					
					# Update type if we went from Diamond -> Concrete
					if current_type == Tile.Type.DIAMOND and seg_type != Tile.Type.DIAMOND:
						current_type = seg_type
						
					processed_segments.append(j)
					changed = true
					
		final_groups.append(current_group)
		
	return final_groups

static func are_compatible_2(t1: Node2D, t2: Node2D) -> bool:
	if t1.tile_type == Tile.Type.DIAMOND or t2.tile_type == Tile.Type.DIAMOND:
		return true
	return t1.tile_type == t2.tile_type

static func get_neighbors(tile: Node2D, board: Array[Array], rows: int, cols: int) -> Array:
	var list = []
	var r = tile.coordinates.x; var c = tile.coordinates.y
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var nr = r + d.x; var nc = c + d.y
		if nr >= 0 and nr < rows and nc >= 0 and nc < cols:
			if board[nr][nc]: list.append(board[nr][nc])
	return list

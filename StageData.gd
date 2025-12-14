class_name StageData
extends Resource

@export var target_score: int = 10000
@export var max_turns: int = 20

# Dictionary mapping Tile.Type (int) to Score (int)
# Keys must be integers matching Tile.Type enum
@export var tile_scores: Dictionary = {}

func get_score(type_id: int) -> int:
	if tile_scores.has(type_id):
		return tile_scores[type_id]
	return 0

class_name LevelManager
extends Node

var current_level: int = 1
var tile_scores: Dictionary = {}
var save_manager: SaveManager

# Score Tiers
const SCORE_LOW = 50
const SCORE_MED = 100
const SCORE_HIGH = 150

func _init():
	save_manager = SaveManager.new()

func setup_run():
	current_level = 1
	randomize_tile_scores() # Initial randomization

func randomize_tile_scores():
	# Pool: 1 Low, 2 Medium, 1 High
	var score_pool = [SCORE_LOW, SCORE_MED, SCORE_MED, SCORE_HIGH]
	score_pool.shuffle()
	
	# Assign to the 4 main types
	tile_scores = {
		Tile.Type.RED: score_pool[0],
		Tile.Type.YELLOW: score_pool[1],
		Tile.Type.PURPLE: score_pool[2],
		Tile.Type.ORANGE: score_pool[3],
		# Fixed/Special values for others if needed, or 0
		Tile.Type.GREEN: 0, # Multiplier only
		Tile.Type.BLUE: 0, # Mana only
		Tile.Type.BLACK: get_black_tile_score() # Bad tile
	}
	
	print("Level %d Tile Scores: %s" % [current_level, tile_scores])
	
	discovered_types = {}

var discovered_types: Dictionary = {}

func mark_discovered(type: Tile.Type):
	discovered_types[type] = true

func is_type_discovered(type: Tile.Type) -> bool:
	return discovered_types.get(type, false)

func get_score_text(score: int) -> String:
	if score == SCORE_LOW: return "LOW"
	elif score == SCORE_MED: return "MED"
	elif score == SCORE_HIGH: return "HIGH"
	return str(score)

func get_current_target() -> int:
	return (current_level * 5000) * (1.05 ** (current_level - 1))

func get_tile_score(type: Tile.Type) -> int:
	return tile_scores.get(type, 0)

func complete_level(final_score: int, turns_left: int) -> Dictionary:
	# Gold: 2% of Score
	var gold_reward = int(final_score * 0.02)
	
	# Diamonds: 0.5 * Level * Turns
	var base_diamonds = floor(turns_left * 0.5 * current_level)
	var diam_reward = int(base_diamonds)
	
	save_manager.add_gold(gold_reward)
	save_manager.add_diamonds(diam_reward)
	
	return {"gold": gold_reward, "diamonds": diam_reward}

func advance_level():
	current_level += 1
	randomize_tile_scores()

func get_black_tile_score() -> int:
	# Base -50, scales by -50 per level
	return -50 - (current_level * 50)


func purchase_upgrade(key: String, cost: int, currency: String = "gold") -> bool:
	if currency == "diamonds":
		if save_manager.spend_diamonds(cost):
			save_manager.increment_upgrade(key)
			return true
	else:
		if save_manager.spend_gold(cost):
			save_manager.increment_upgrade(key)
			return true
	return false

func get_highest_value_tile_type() -> Tile.Type:
	var best_type = Tile.Type.RED
	var best_score = -9999
	
	for type in tile_scores:
		if tile_scores[type] > best_score:
			best_score = tile_scores[type]
			best_type = type
			
	return best_type

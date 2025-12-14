class_name LevelManager
extends Node

var current_level: int = 1
var gold: int = 0
var tile_scores: Dictionary = {}
var upgrades: Dictionary = {
	"mana_cap": 0,
	"spell_cost": 0,
	"tile_mult": 0
}

const SAVE_PATH = "user://savegame.json"

# Score Tiers
const SCORE_LOW = 50
const SCORE_MED = 100
const SCORE_HIGH = 150

func _init():
	load_game()

func save_game():
	var save_data = {
		"gold": gold,
		"upgrades": upgrades
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		return # No save file
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var json = JSON.new()
		if json.parse(content) == OK:
			var data = json.data
			if "gold" in data: gold = int(data["gold"])
			if "upgrades" in data: upgrades = data["upgrades"]

func setup_run():
	current_level = 1
	# Do NOT reset gold here as it persists
	save_game() # Save start of run state
	randomize_tile_scores()

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
		Tile.Type.BLUE: 0,  # Mana only
		Tile.Type.BLACK: get_black_tile_score()  # Bad tile
	}
	
	print("Run Initialized. Tile Scores: ", tile_scores)

func get_current_target() -> int:
	return 1000 + (current_level * 5000)

func get_tile_score(type: Tile.Type) -> int:
	return tile_scores.get(type, 0)

func complete_level() -> int:
	var reward = 100 * current_level
	gold += reward
	save_game() # Save progress
	current_level += 1
	return reward

func get_black_tile_score() -> int:
	# Base -50, scales by -50 per level
	return -50 - (current_level * 50)



func purchase_upgrade(key: String, cost: int) -> bool:
	if gold >= cost:
		gold -= cost
		if key in upgrades:
			upgrades[key] += 1
		else:
			upgrades[key] = 1
		save_game()
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

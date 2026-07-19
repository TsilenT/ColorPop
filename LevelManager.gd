class_name LevelManager
extends Node

# Safety valve only — 5000 skips means the target grew by ~10^100x past the
# excess, unreachable in practice. Bounds the loop regardless of score.
const MAX_LEVEL_SKIPS = 5000

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


	discovered_types = {}

var discovered_types: Dictionary = {}

func mark_discovered(type: Tile.Type):
	discovered_types[type] = true

func is_type_discovered(type: Tile.Type) -> bool:
	return discovered_types.get(type, false)

func get_score_text(score: float) -> String:
	if score == SCORE_LOW: return "LOW"
	elif score == SCORE_MED: return "MED"
	elif score == SCORE_HIGH: return "HIGH"
	return str(score)

func get_current_target(level_idx: int = -1) -> Big:
	if level_idx == -1: level_idx = current_level
	# level * 5000 * 1.05^(level-1), built in log space so it never overflows
	var lg = Big.log10_f(float(level_idx) * 5000.0) + float(level_idx - 1) * Big.log10_f(1.05)
	return Big.from_log10(lg)

func get_tile_score(type: Tile.Type) -> float:
	return float(tile_scores.get(type, 0))

func complete_level(final_score: Big, turns_left: int) -> Dictionary:
	# Gold: 2% of Score * Difficulty Multiplier
	var difficulty = save_manager.get_setting("difficulty", "normal")
	var diff_mult = 2.0 # Normal default (2x existing)

	if difficulty == "hard":
		diff_mult = 1.0 # Original (1x)
	elif difficulty == "easy":
		diff_mult = 4.0 # 4x

	var gold_reward: Big = final_score.mul_f(0.02 * diff_mult)

	# Diamonds: 0.5 * Level * Turns
	var diam_reward: Big = Big.of(floor(float(turns_left) * 0.5 * float(current_level)))

	save_manager.add_gold(gold_reward)
	save_manager.add_diamonds(diam_reward)

	return {"gold": gold_reward, "diamonds": diam_reward}

func advance_level(amount: int = 1):
	current_level += amount
	randomize_tile_scores()

func calculate_level_skips(excess_score: Big) -> int:
	var skips = 0
	var check_level = current_level + 1
	var remaining_excess = excess_score.copy()

	while skips < MAX_LEVEL_SKIPS:
		var target = get_current_target(check_level)
		if remaining_excess.gte(target):
			skips += 1
			remaining_excess = remaining_excess.sub(target)
			check_level += 1
		else:
			break

	return skips

func get_black_tile_score() -> float:
	# Base -50, scales by -50 per level (float: level can be huge after skips)
	return -50.0 - (float(current_level) * 50.0)


func purchase_upgrade(key: String, cost: Big, currency: String = "gold", amount: float = 1.0) -> bool:
	if currency == "diamonds":
		if save_manager.spend_diamonds(cost):
			save_manager.increment_upgrade(key, amount)
			return true
	else:
		if save_manager.spend_gold(cost):
			save_manager.increment_upgrade(key, amount)
			return true
	return false

func get_highest_value_tile_type() -> Tile.Type:
	var best_type = Tile.Type.RED
	var best_score = -INF

	for type in tile_scores:
		if tile_scores[type] > best_score:
			best_score = tile_scores[type]
			best_type = type

	return best_type

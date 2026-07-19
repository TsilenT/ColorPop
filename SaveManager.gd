class_name SaveManager
extends Node

const SAVE_PATH = "user://savegame.json"

# gold/diamonds are Big; upgrade levels are floats (they can get ridiculous
# via MAX buys — precision loss past 2^53 is acceptable by design).
var data = {
	"gold": Big.zero(),
	"upgrades": {
		"mana_cap": 0.0,
		"spell_cost": 0.0,
		"mult_red": 0.0,
		"mult_yellow": 0.0,
		"mult_green": 0.0,
		"mult_blue": 0.0,
		"mult_purple": 0.0,
		"mult_orange": 0.0,
		"harvest": 0.0,
		"columns": 0.0,
		"cinderella": 0.0,
		"relax": 0.0
	},
	"settings": {
		"highlight_enabled": true,
		"visual_effects_enabled": true,
		"auto_match_enabled": true,
		"sfx_volume": 0.5,
		"music_volume": 0.5,
		"difficulty": "normal"
	},
	"diamonds": Big.zero(),
	"stats": {
		"highest_level": 1
	}
}

var _save_queued: bool = false

func _init():
	load_game()

# Coalesces bursts of mutations (e.g. per-tile diamond rewards during a
# cascade) into a single disk write at the end of the frame.
func queue_save():
	if _save_queued: return
	_save_queued = true
	_flush_save.call_deferred()

func _flush_save():
	_save_queued = false
	save_game()

func save_game():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var out = {
			"gold": data["gold"].to_save(),
			"diamonds": data["diamonds"].to_save(),
			"upgrades": data["upgrades"],
			"settings": data["settings"],
			"stats": data["stats"],
		}
		file.store_string(JSON.stringify(out))

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		save_game() # Create default file if missing
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var json = JSON.new()
		if json.parse(content) == OK:
			var loaded_data = json.data
			# Big.from_save also accepts plain numbers from pre-Big saves
			if "gold" in loaded_data: data["gold"] = Big.from_save(loaded_data["gold"])
			if "diamonds" in loaded_data: data["diamonds"] = Big.from_save(loaded_data["diamonds"])

			# Merge Upgrades (levels are floats now; old int saves convert)
			if "upgrades" in loaded_data:
				for k in loaded_data["upgrades"]:
					var v = float(loaded_data["upgrades"][k])
					data["upgrades"][k] = v if is_finite(v) and v > 0.0 else 0.0

			# Merge Settings
			if "settings" in loaded_data:
				for k in loaded_data["settings"]:
					data["settings"][k] = loaded_data["settings"][k]

			# Merge Stats
			if "stats" in loaded_data:
				for k in loaded_data["stats"]:
					if not "stats" in data: data["stats"] = {}
					data["stats"][k] = loaded_data["stats"][k]

func get_gold() -> Big:
	return data["gold"]

func add_gold(amount: Big):
	data["gold"] = data["gold"].add(amount)
	queue_save()

func get_diamonds() -> Big:
	return data["diamonds"]

func add_diamonds(amount: Big):
	data["diamonds"] = data["diamonds"].add(amount)
	queue_save()

func spend_gold(amount: Big) -> bool:
	if data["gold"].gte(amount):
		data["gold"] = data["gold"].sub(amount)
		queue_save()
		return true
	return false

func spend_diamonds(amount: Big) -> bool:
	if data["diamonds"].gte(amount):
		data["diamonds"] = data["diamonds"].sub(amount)
		queue_save()
		return true
	return false

func get_upgrade_level(key: String) -> float:
	return float(data["upgrades"].get(key, 0.0))

func increment_upgrade(key: String, amount: float = 1.0):
	data["upgrades"][key] = get_upgrade_level(key) + amount
	queue_save()

func get_setting(key: String, default = null):
	return data["settings"].get(key, default)

func set_setting(key: String, value):
	data["settings"][key] = value
	queue_save()

func get_highest_level() -> int:
	if not "stats" in data: return 1
	return data["stats"].get("highest_level", 1)

func update_highest_level(level: int):
	if not "stats" in data: data["stats"] = {"highest_level": 1}
	var current = data["stats"].get("highest_level", 1)
	if level > current:
		data["stats"]["highest_level"] = level
		queue_save()

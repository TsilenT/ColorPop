class_name SaveManager
extends Node

const SAVE_PATH = "user://savegame.json"

var data = {
	"gold": 0.0,
	"upgrades": {
		"mana_cap": 0,
		"spell_cost": 0,
		"mult_red": 0,
		"mult_yellow": 0,
		"mult_green": 0,
		"mult_blue": 0,
		"mult_purple": 0,
		"mult_orange": 0,
		"harvest": 0,
		"columns": 0,
		"cinderella": 0,
		"relax": 0
	},
	"settings": {
		"highlight_enabled": true,
		"visual_effects_enabled": true,
		"auto_match_enabled": true,
		"sfx_volume": 0.5,
		"music_volume": 0.5,
		"difficulty": "normal"
	},
	"diamonds": 0.0,
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
		file.store_string(JSON.stringify(data))

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
			# Merge loaded data with defaults to handle missing keys
			if "gold" in loaded_data: data["gold"] = float(loaded_data["gold"])
			if "diamonds" in loaded_data: data["diamonds"] = float(loaded_data["diamonds"])
			
			# Merge Upgrades
			if "upgrades" in loaded_data:
				for k in loaded_data["upgrades"]:
					data["upgrades"][k] = loaded_data["upgrades"][k]
					
			# Merge Settings
			if "settings" in loaded_data:
				for k in loaded_data["settings"]:
					data["settings"][k] = loaded_data["settings"][k]
					
			# Merge Stats
			if "stats" in loaded_data:
				for k in loaded_data["stats"]:
					if not "stats" in data: data["stats"] = {}
					data["stats"][k] = loaded_data["stats"][k]

func get_gold() -> float:
	return data["gold"]

func add_gold(amount: float):
	data["gold"] += amount
	queue_save()

func get_diamonds() -> float:
	return data.get("diamonds", 0.0)

func add_diamonds(amount: float):
	if not "diamonds" in data: data["diamonds"] = 0
	data["diamonds"] += amount
	queue_save()

func spend_gold(amount: float) -> bool:
	if data["gold"] >= amount:
		data["gold"] -= amount
		queue_save()
		return true
	return false

func spend_diamonds(amount: float) -> bool:
	if not "diamonds" in data: data["diamonds"] = 0.0
	if data["diamonds"] >= amount:
		data["diamonds"] -= amount
		queue_save()
		return true
	return false

func get_upgrade_level(key: String) -> int:
	return data["upgrades"].get(key, 0)

func increment_upgrade(key: String, amount: int = 1):
	if key in data["upgrades"]:
		data["upgrades"][key] += amount
	else:
		data["upgrades"][key] = amount
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

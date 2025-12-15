class_name SaveManager
extends Node

const SAVE_PATH = "user://savegame.json"

var data = {
	"gold": 0,
	"upgrades": {
		"mana_cap": 0,
		"spell_cost": 0,
		"tile_mult": 0
	},
	"settings": {
		"highlight_enabled": true
	}
}

func _init():
	load_game()

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
			if "gold" in loaded_data: data["gold"] = int(loaded_data["gold"])
			if "upgrades" in loaded_data: data["upgrades"] = loaded_data["upgrades"]
			if "settings" in loaded_data:
				# Merge settings specifically to preserve defaults for new keys
				for k in loaded_data["settings"]:
					data["settings"][k] = loaded_data["settings"][k]

func get_gold() -> int:
	return data["gold"]

func add_gold(amount: int):
	data["gold"] += amount
	save_game()

func spend_gold(amount: int) -> bool:
	if data["gold"] >= amount:
		data["gold"] -= amount
		save_game()
		return true
	return false

func get_upgrade_level(key: String) -> int:
	return data["upgrades"].get(key, 0)

func increment_upgrade(key: String):
	if key in data["upgrades"]:
		data["upgrades"][key] += 1
	else:
		data["upgrades"][key] = 1
	save_game()

func get_setting(key: String, default = null):
	return data["settings"].get(key, default)

func set_setting(key: String, value):
	data["settings"][key] = value
	save_game()

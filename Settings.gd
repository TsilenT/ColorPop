class_name Settings
extends CanvasLayer

signal close_requested

var level_manager
var sound_manager

@onready var highlight_toggle: CheckButton = $Panel/VBoxContainer/HighlightToggle
@onready var vfx_toggle: CheckButton = $Panel/VBoxContainer/VFXToggle
@onready var auto_match_toggle: CheckButton = $Panel/VBoxContainer/AutoMatchToggle
@onready var difficulty_option: OptionButton = $Panel/VBoxContainer/DifficultyContainer/DifficultyOption
@onready var sfx_slider: HSlider = $Panel/VBoxContainer/SFXSlider
@onready var music_slider: HSlider = $Panel/VBoxContainer/MusicSlider
@onready var close_button: Button = $Panel/CloseButton

func _ready():
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	if highlight_toggle:
		highlight_toggle.toggled.connect(_on_highlight_toggled)
	if vfx_toggle:
		vfx_toggle.toggled.connect(_on_vfx_toggled)
	if auto_match_toggle:
		auto_match_toggle.toggled.connect(_on_auto_match_toggled)
	if difficulty_option:
		difficulty_option.item_selected.connect(_on_difficulty_selected)
	if sfx_slider:
		sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	if music_slider:
		music_slider.value_changed.connect(_on_music_volume_changed)

func setup(lm, sm = null):
	level_manager = lm
	sound_manager = sm
	if level_manager and level_manager.save_manager:
		var hl_enabled = level_manager.save_manager.get_setting("highlight_enabled", true)
		if highlight_toggle: highlight_toggle.button_pressed = hl_enabled
		
		var vfx_enabled = level_manager.save_manager.get_setting("visual_effects_enabled", true)
		if vfx_toggle: vfx_toggle.button_pressed = vfx_enabled
		
		var am_enabled = level_manager.save_manager.get_setting("auto_match_enabled", true)
		if auto_match_toggle:
			auto_match_toggle.button_pressed = am_enabled
			if level_manager.save_manager.get_upgrade_level("relax") > 0:
				auto_match_toggle.visible = true
			else:
				auto_match_toggle.visible = false
				
			# Resize Panel
			if $Panel:
				var target_h = 450 # Original base height
				if auto_match_toggle.visible:
					target_h = 520 # Expanded height
				
				$Panel.custom_minimum_size.y = target_h
				$Panel.size.y = target_h
				# Maintain Center Anchor
				$Panel.offset_top = - target_h / 2.0
				$Panel.offset_bottom = target_h / 2.0

		var sfx_vol = level_manager.save_manager.get_setting("sfx_volume", 0.5)
		if sfx_slider: sfx_slider.value = sfx_vol
		
		var mus_vol = level_manager.save_manager.get_setting("music_volume", 0.5)
		if music_slider: music_slider.value = mus_vol
		
		# Difficulty Setup
		var difficulty = level_manager.save_manager.get_setting("difficulty", "normal")
		if difficulty_option:
			var idx = 1 # Normal
			if difficulty == "easy": idx = 0
			elif difficulty == "hard": idx = 2
			difficulty_option.selected = idx

func _on_difficulty_selected(idx: int):
	if level_manager and level_manager.save_manager:
		var difficulty = "normal"
		if idx == 0: difficulty = "easy"
		elif idx == 2: difficulty = "hard"
		level_manager.save_manager.set_setting("difficulty", difficulty)

func _on_highlight_toggled(toggled_on: bool):
	if level_manager and level_manager.save_manager:
		level_manager.save_manager.set_setting("highlight_enabled", toggled_on)

func _on_vfx_toggled(toggled_on: bool):
	if level_manager and level_manager.save_manager:
		level_manager.save_manager.set_setting("visual_effects_enabled", toggled_on)

func _on_auto_match_toggled(toggled_on: bool):
	if level_manager and level_manager.save_manager:
		level_manager.save_manager.set_setting("auto_match_enabled", toggled_on)

func _on_sfx_volume_changed(value: float):
	if level_manager and level_manager.save_manager:
		level_manager.save_manager.set_setting("sfx_volume", value)
	if sound_manager:
		sound_manager.sfx_volume = value

func _on_music_volume_changed(value: float):
	if level_manager and level_manager.save_manager:
		level_manager.save_manager.set_setting("music_volume", value)
	if sound_manager:
		sound_manager.music_volume = value
		
func _on_close_pressed():
	if sound_manager: sound_manager.play_tone(400, 0.05)
	emit_signal("close_requested")
	queue_free()

class_name Settings
extends CanvasLayer

signal close_requested

var level_manager

@onready var highlight_toggle: CheckButton = $Panel/VBoxContainer/HighlightToggle
@onready var sound_toggle: CheckButton = $Panel/VBoxContainer/SoundToggle
@onready var close_button: Button = $Panel/CloseButton

func _ready():
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	if highlight_toggle:
		highlight_toggle.toggled.connect(_on_highlight_toggled)
	if sound_toggle:
		sound_toggle.toggled.connect(_on_sound_toggled)

func setup(lm):
	level_manager = lm
	if level_manager and level_manager.save_manager:
		var hl_enabled = level_manager.save_manager.get_setting("highlight_enabled", true)
		if highlight_toggle: highlight_toggle.button_pressed = hl_enabled
		
		var snd_enabled = level_manager.save_manager.get_setting("sound_enabled", true)
		if sound_toggle: sound_toggle.button_pressed = snd_enabled
		
func _on_highlight_toggled(toggled_on: bool):
	if level_manager and level_manager.save_manager:
		level_manager.save_manager.set_setting("highlight_enabled", toggled_on)

func _on_sound_toggled(toggled_on: bool):
	if level_manager and level_manager.save_manager:
		level_manager.save_manager.set_setting("sound_enabled", toggled_on)
		
func _on_close_pressed():
	emit_signal("close_requested")
	queue_free()

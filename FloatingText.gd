extends Control

func setup(text: String, color: Color, scale_factor: float = 1.0, outline_color: Color = Color.BLACK):
	$Label.text = text
	
	# Create dynamic label settings for outline
	var settings = LabelSettings.new()
	settings.font_color = color
	settings.outline_size = 4
	settings.outline_color = outline_color
	settings.font_size = 24 # Make it bold/large
	
	$Label.label_settings = settings

	
	scale = Vector2(scale_factor, scale_factor)
	
	# Animate up and fade out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 50, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)

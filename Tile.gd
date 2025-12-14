class_name Tile
extends Area2D

enum Type { RED, YELLOW, GREEN, BLUE, BLACK, PURPLE, ORANGE }

@export var tile_type: Type = Type.RED
@export var coordinates: Vector2i # To store its position (row, col)

@onready var sprite: Sprite2D = $Sprite2D
@onready var icon_label: Label = $IconLabel

const TEXTURE_PATHS = {
	Type.RED: "res://assets/tile_red.svg",
	Type.YELLOW: "res://assets/tile_yellow.svg",
	Type.GREEN: "res://assets/tile_green.svg",
	Type.BLUE: "res://assets/tile_blue.svg",
	Type.BLACK: "res://assets/tile_black.svg",
	Type.PURPLE: "res://assets/tile_purple.svg",
	Type.ORANGE: "res://assets/tile_orange.svg"
}

func _ready():
	if sprite:
		# Load Texture
		var path = TEXTURE_PATHS.get(tile_type, "")
		if path != "":
			sprite.texture = load(path)
			if not sprite.texture:
				sprite.texture = load("res://icon.svg")
		else:
			sprite.texture = load("res://icon.svg")
		
		# Reset Modulate (Textures determine color now)
		sprite.modulate = Color.WHITE
		
		# Special handling for BLACK tile (since we reused asset)
		if tile_type == Type.BLACK:
			sprite.modulate = Color(0.2, 0.2, 0.2) # Dark tint
	
	if icon_label:
		if tile_type == Type.GREEN:
			icon_label.visible = true
			icon_label.text = "x2"
		else:
			icon_label.visible = false
			icon_label.text = ""
			
	# Scale to 1.0 for 64x64 SVGs to fit in 70x70 tile slot
	scale = Vector2(1.0, 1.0)

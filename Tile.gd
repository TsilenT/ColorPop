class_name Tile
extends Area2D

enum Type { RED, YELLOW, GREEN, BLUE, BLACK }

@export var tile_type: Type = Type.RED
@export var coordinates: Vector2i # To store its position (row, col)

class_name Game
extends Node2D

const COLS = 8
const ROWS = 8

@export var TileScene: PackedScene
@onready var board_container: GridContainer = $BoardContainer

var board: Array[Array] = []

func _ready():
	initialize_board()

func initialize_board():
	board.resize(ROWS)
	for r in range(ROWS):
		board[r] = []
		board[r].resize(COLS)
		for c in range(COLS):
			var tile = TileScene.instantiate()
			tile.tile_type = Tile.Type.values()[randi() % Tile.Type.values().size()]
			tile.coordinates = Vector2i(r, c)
			board_container.add_child(tile)
			board[r][c] = tile

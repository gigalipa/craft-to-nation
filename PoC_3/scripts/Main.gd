extends Node3D

@onready var mundo := $VoxelWorld
@onready var jugador: Player = $Player


func _ready() -> void:
	jugador.mundo = mundo

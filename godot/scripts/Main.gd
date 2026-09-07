extends Node3D

const Player = preload("res://scripts/Player.gd")  # TEMP: ver nota de verificación tras mover el proyecto a godot/

@onready var mundo := $VoxelWorld
@onready var jugador: Player = $Player


func _ready() -> void:
	jugador.mundo = mundo

extends Node3D

const Player = preload("res://scripts/Player.gd")  # TEMP: ver nota de verificación tras mover el proyecto a godot/

@onready var mundo := $VoxelWorld
@onready var jugador: Player = $Player
@onready var camara_cenital: Camera3D = $CamaraCenital
@onready var zona_overlay: Node3D = $ZonaOverlay

var cenital_activa := false


func _ready() -> void:
	jugador.mundo = mundo


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var tecla := event as InputEventKey
		if tecla.pressed and tecla.keycode == KEY_C:
			_alternar_camara_cenital()


## Alterna entre la cámara en 1ª persona del jugador y la cenital: congela
## el movimiento del jugador mientras la cenital está activa (conserva su
## posición al volver), y muestra/oculta el overlay de zonas — solo debe
## verse desde arriba, nunca en 1ª persona (decisión explícita del usuario).
func _alternar_camara_cenital() -> void:
	cenital_activa = not cenital_activa
	if cenital_activa:
		camara_cenital.posicionar_sobre_influencia()
	camara_cenital.current = cenital_activa
	jugador.camara.current = not cenital_activa
	jugador.set_physics_process(not cenital_activa)
	zona_overlay.visible = cenital_activa
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if cenital_activa else Input.MOUSE_MODE_CAPTURED

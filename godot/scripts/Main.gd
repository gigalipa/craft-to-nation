extends Node3D

@onready var mundo := $VoxelWorld
@onready var jugador: Player = $Player
@onready var camara_cenital: Camera3D = $CamaraCenital
@onready var zona_overlay: Node3D = $ZonaOverlay
@onready var mira_ui: CanvasLayer = $MiraUI
@onready var hud: CanvasLayer = $HUDLayer

var cenital_activa := false


func _ready() -> void:
	jugador.mundo = mundo
	Zonificacion.limite_mundo = Vector2i(mundo.ANCHO_MUNDO, mundo.LARGO_MUNDO)
	Colonos.mundo = mundo
	Economia.mundo = mundo
	mundo.obra_a_fantasma.connect(jugador._on_obra_a_fantasma)
	var centro_x: int = mundo.ANCHO_MUNDO / 2
	var centro_z: int = mundo.LARGO_MUNDO / 2
	var altura_spawn: int = mundo.altura_en(centro_x, centro_z)
	jugador.position = Vector3(centro_x, altura_spawn + 1, centro_z)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var tecla := event as InputEventKey
		if tecla.pressed and tecla.keycode == KEY_C:
			_alternar_camara_cenital()


## Alterna entre la cámara en 1ª persona del jugador y la cenital: congela
## el movimiento del jugador mientras la cenital está activa (conserva su
## posición al volver), muestra/oculta el overlay de zonas — solo debe verse
## desde arriba, nunca en 1ª persona —, oculta la mira (MiraUI/Mira), que
## solo tiene sentido en 1ª persona (decisión explícita del usuario), y sale
## de cualquier modo de interacción de la cenital (nivelación, colocar mina)
## al volver a 1ª persona — esos modos dibujan overlays como hijos directos
## de CamaraCenital, independientes de si esa cámara está activa, así que
## sin esto quedaban visibles y congelados encima de la vista en 1ª persona.
func _alternar_camara_cenital() -> void:
	cenital_activa = not cenital_activa
	if cenital_activa:
		camara_cenital.posicionar_sobre(Vector2(jugador.position.x, jugador.position.z))
		zona_overlay.reconstruir()
	else:
		camara_cenital.salir_de_todos_los_modos()
	camara_cenital.current = cenital_activa
	jugador.camara.current = not cenital_activa
	jugador.set_physics_process(not cenital_activa)
	zona_overlay.visible = cenital_activa
	mira_ui.visible = not cenital_activa
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if cenital_activa else Input.MOUSE_MODE_CAPTURED
	hud.set_vista(not cenital_activa)
	if not cenital_activa and jugador.modo_deconstruccion:
		jugador.mostrar_contexto_deconstruccion()

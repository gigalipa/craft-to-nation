extends Node3D

@onready var mundo := $VoxelWorld
@onready var jugador: Player = $Player
@onready var camara_cenital: Camera3D = $CamaraCenital
@onready var zona_overlay: Node3D = $ZonaOverlay
@onready var mira_ui: CanvasLayer = $MiraUI
@onready var hud: CanvasLayer = $HUDLayer

var cenital_activa := false

## Duración de la animación de cambio de cámara (segundos).
const DURACION_TRANSICION := 0.6

## Cámara "libre" que hace el vuelo de una vista a otra: durante la
## transición es la única cámara `current`, ninguna de las dos vistas
## procesa entrada (CamaraCenital._process()/_unhandled_input() vuelven de
## inmediato si `current` es falso; Player ignora WASD/salto/nado vía
## jugador.movimiento_habilitado, pero sigue cayendo por gravedad, y el
## ratón se libera, lo que también desactiva su mouse-look).
var _camara_transicion := Camera3D.new()
var _en_transicion := false


func _ready() -> void:
	_camara_transicion.current = false
	add_child(_camara_transicion)
	jugador.mundo = mundo
	Zonificacion.limite_mundo = Vector2i(mundo.ANCHO_MUNDO, mundo.LARGO_MUNDO)
	Colonos.mundo = mundo
	Obras.mundo = mundo
	Obras.aviso.connect(hud.notificar)
	var marcas_demolicion := preload("res://scripts/MarcasDemolicionOverlay.gd").new()
	marcas_demolicion.obras = Obras
	add_child(marcas_demolicion)
	if has_node("ViaObraOverlay"):
		$ViaObraOverlay.obras = Obras

	Economia.mundo = mundo
	mundo.obra_a_fantasma.connect(jugador._on_obra_a_fantasma)
	Colonos.colono_creado.connect(func(_id: int) -> void: hud.notificar("Nuevo colono en la ciudad."))
	Colonos.tecnicos_formados.connect(func(cantidad: int) -> void: hud.notificar("Se formaron %d técnicos." % cantidad))
	var centro_x: int = mundo.ANCHO_MUNDO / 2
	var centro_z: int = mundo.LARGO_MUNDO / 2
	var altura_spawn: int = mundo.altura_en(centro_x, centro_z)
	jugador.position = Vector3(centro_x, altura_spawn + 1, centro_z)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var tecla := event as InputEventKey
		if tecla.pressed and tecla.keycode == KEY_C and not _en_transicion:
			_alternar_camara_cenital()


## Alterna entre la cámara en 1ª persona del jugador y la cenital, con una
## transición animada: una cámara libre (_camara_transicion) vuela de la
## posición de la vista saliente a la de la entrante mientras el HUD hace un
## crossfade (ver HUD.iniciar_transicion()). Congela el jugador y la cenital
## durante el vuelo (ver comentario de _camara_transicion) y, al llegar,
## aplica el resto de cambios de vista: overlay de zonas — solo debe verse
## desde arriba, nunca en 1ª persona —, mira (MiraUI/Mira, solo con sentido
## en 1ª persona) y salida de cualquier modo de interacción de la cenital
## (nivelación, colocar mina) al volver a 1ª persona — esos modos dibujan
## overlays como hijos directos de CamaraCenital, independientes de si esa
## cámara está activa, así que sin esto quedaban visibles y congelados
## encima de la vista en 1ª persona.
func _alternar_camara_cenital() -> void:
	cenital_activa = not cenital_activa
	var origen: Transform3D
	var destino: Transform3D
	var fov_origen: float
	var fov_destino: float
	if cenital_activa:
		origen = jugador.camara.global_transform
		fov_origen = jugador.camara.fov
		# "atrás" del avatar (opuesto a su frente, -basis.z, ver
		# Player._direccion_cardinal()): la cenital orbita detrás de hacia
		# dónde mira, como un seguimiento en 3ª persona.
		var atras := jugador.global_transform.basis.z
		var angulo_avatar := atan2(atras.x, atras.z)
		camara_cenital.posicionar_sobre(Vector2(jugador.position.x, jugador.position.z), angulo_avatar)
		destino = camara_cenital.global_transform
		fov_destino = camara_cenital.fov
	else:
		origen = camara_cenital.global_transform
		fov_origen = camara_cenital.fov
		camara_cenital.salir_de_todos_los_modos()
		destino = jugador.camara.global_transform
		fov_destino = jugador.camara.fov

	_en_transicion = true
	# Solo se ignora el movimiento (WASD/salto/nado, ver Player.gd): la
	# gravedad sigue corriendo, si no un avatar en caída libre quedaba
	# "flotando" en el aire durante el vuelo (reportado jugando en vivo,
	# 2026-09-29).
	jugador.movimiento_habilitado = false
	camara_cenital.current = false
	jugador.camara.current = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_camara_transicion.global_transform = origen
	# La cenital usa un fov distinto al de 1ª persona (60° vs 75° por
	# defecto): sin interpolarlo también, al intercambiar de cámara al
	# principio/final del vuelo se veía un salto de encuadre (reportado por
	# el usuario, 2026-09-27).
	_camara_transicion.fov = fov_origen
	_camara_transicion.current = true
	hud.iniciar_transicion(cenital_activa, DURACION_TRANSICION)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_camara_transicion, "global_transform", destino, DURACION_TRANSICION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camara_transicion, "fov", fov_destino, DURACION_TRANSICION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_callback(_terminar_transicion)


func _terminar_transicion() -> void:
	_en_transicion = false
	_camara_transicion.current = false
	camara_cenital.current = cenital_activa
	jugador.camara.current = not cenital_activa
	jugador.movimiento_habilitado = not cenital_activa
	zona_overlay.visible = cenital_activa
	if cenital_activa:
		zona_overlay.reconstruir()
	mira_ui.visible = not cenital_activa
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if cenital_activa else Input.MOUSE_MODE_CAPTURED
	if not cenital_activa and jugador.modo_deconstruccion:
		jugador.mostrar_contexto_deconstruccion()

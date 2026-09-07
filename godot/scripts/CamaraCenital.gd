extends Camera3D

## Cámara cenital mínima para pintar zonas (ver spec:
## docs/superpowers/specs/2026-09-07-zonificacion-design.md). Sin
## paneo/zoom ni selección de tropas — eso es PoC 5 completo (Fase 3), esta
## versión solo existe para poder pintar zonas desde arriba.

@onready var mundo: Node = get_node("../VoxelWorld")
@onready var overlay: Node3D = get_node("../ZonaOverlay")

var tipo_zona_seleccionada: String = Zonificacion.ZONAS_PINTABLES[0]
var esperando_segunda_esquina := false
var primera_esquina := Vector2i.ZERO


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = 40.0
	rotation_degrees = Vector3(-90, 0, 0)


## Centra la cámara sobre la zona de influencia (o el origen, si todavía no
## existe núcleo urbano declarado). Llamada por Main.gd al activar la
## cámara cenital.
func posicionar_sobre_influencia() -> void:
	var centro: Vector2i
	if Zonificacion.nucleo_declarado:
		centro = (Zonificacion.influencia_min + Zonificacion.influencia_max) / 2
	else:
		centro = Vector2i.ZERO
	global_position = Vector3(centro.x, 20.0, centro.y)


func _unhandled_input(event: InputEvent) -> void:
	if not current:
		return

	if event is InputEventKey:
		var tecla := event as InputEventKey
		if tecla.pressed and tecla.keycode == KEY_1:
			tipo_zona_seleccionada = Zonificacion.ZONAS_PINTABLES[0]
			print("Zona seleccionada: ", tipo_zona_seleccionada)
		elif tecla.pressed and tecla.keycode == KEY_2:
			tipo_zona_seleccionada = Zonificacion.ZONAS_PINTABLES[1]
			print("Zona seleccionada: ", tipo_zona_seleccionada)

	if event is InputEventMouseButton:
		var boton := event as InputEventMouseButton
		if boton.pressed and boton.button_index == MOUSE_BUTTON_LEFT:
			_procesar_clic(boton.position)


## Convierte una posición de pantalla en la celda de grid (X,Z) que hay
## debajo, intersecando el rayo de la cámara con el plano y = 0.
func _celda_bajo_mouse(posicion_pantalla: Vector2) -> Vector2i:
	var origen := project_ray_origin(posicion_pantalla)
	var direccion := project_ray_normal(posicion_pantalla)
	var distancia: float = -origen.y / direccion.y
	var punto: Vector3 = origen + direccion * distancia
	var celda: Vector3i = mundo.local_to_map(mundo.to_local(punto))
	return Vector2i(celda.x, celda.z)


func _procesar_clic(posicion_pantalla: Vector2) -> void:
	var celda := _celda_bajo_mouse(posicion_pantalla)
	if not esperando_segunda_esquina:
		primera_esquina = celda
		esperando_segunda_esquina = true
		print("Primera esquina de la zona: ", primera_esquina)
		return

	var pintadas: int = Zonificacion.pintar_zona(primera_esquina, celda, tipo_zona_seleccionada)
	print("Zona '", tipo_zona_seleccionada, "' pintada en ", pintadas, " celda(s).")
	if pintadas == 0 and not Zonificacion.nucleo_declarado:
		print("Todavía no existe una zona de influencia — declara tu primer edificio residencial primero.")
	esperando_segunda_esquina = false
	overlay.reconstruir()

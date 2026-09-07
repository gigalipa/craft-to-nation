extends Camera3D

## Cámara cenital con perspectiva oblicua para pintar zonas (ver spec:
## docs/superpowers/specs/2026-09-07-zonificacion-design.md, ampliada a
## petición del usuario tras la primera prueba en vivo: perspectiva oblicua
## en vez de ortogonal recta, con paneo (WASD) y rotación orbital (Q/E)
## alrededor de un punto de mira — sin zoom ni selección de tropas por
## arrastre todavía, eso sigue siendo PoC 6/Fase 4).

const DISTANCIA_CAMARA := 25.0
const ANGULO_INCLINACION := deg_to_rad(55.0)  # inclinación fija sobre la horizontal
const VELOCIDAD_PANEO := 20.0  # celdas/segundo
const VELOCIDAD_ORBITA := deg_to_rad(90.0)  # radianes/segundo

@onready var mundo: Node = get_node("../VoxelWorld")
@onready var overlay: Node3D = get_node("../ZonaOverlay")

var tipo_zona_seleccionada: String = Zonificacion.ZONAS_PINTABLES[0]
var esperando_segunda_esquina := false
var primera_esquina := Vector2i.ZERO

## Punto de mira sobre el plano del suelo (Y siempre 0): la cámara orbita y
## se desplaza alrededor de este punto, nunca se mueve directamente.
var foco := Vector3.ZERO
var angulo_orbital := 0.0


func _ready() -> void:
	projection = PROJECTION_PERSPECTIVE
	fov = 60.0


## Centra el punto de mira sobre las coordenadas X/Z dadas (la posición del
## jugador en el momento de activar la cenital) y reinicia la orientación
## orbital. Llamada por Main.gd al activar la cámara cenital.
func posicionar_sobre(foco_xz: Vector2) -> void:
	foco = Vector3(foco_xz.x, 0.0, foco_xz.y)
	angulo_orbital = 0.0
	_actualizar_transform()


## Recalcula la posición/orientación de la cámara a partir de foco +
## angulo_orbital, manteniendo siempre la misma distancia e inclinación
## (órbita de cámara clásica: la cámara nunca se mueve directamente, solo
## el punto de mira y el ángulo alrededor de él).
func _actualizar_transform() -> void:
	var direccion_horizontal := Vector3(sin(angulo_orbital), 0.0, cos(angulo_orbital))
	var offset := direccion_horizontal * DISTANCIA_CAMARA * cos(ANGULO_INCLINACION)
	offset.y = DISTANCIA_CAMARA * sin(ANGULO_INCLINACION)
	global_position = foco + offset
	look_at(foco, Vector3.UP)


func _process(delta: float) -> void:
	if not current:
		return

	var paneo := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		paneo.y -= 1
	if Input.is_key_pressed(KEY_S):
		paneo.y += 1
	if Input.is_key_pressed(KEY_A):
		paneo.x -= 1
	if Input.is_key_pressed(KEY_D):
		paneo.x += 1

	var giro := 0.0
	if Input.is_key_pressed(KEY_Q):
		giro -= 1.0
	if Input.is_key_pressed(KEY_E):
		giro += 1.0

	var necesita_actualizar := false
	if paneo != Vector2.ZERO:
		# El paneo es relativo a la orientación actual de la cámara: "adelante"
		# siempre aleja el punto de mira de la cámara en pantalla, sin importar
		# el ángulo de órbita.
		paneo = paneo.normalized() * VELOCIDAD_PANEO * delta
		var adelante := Vector3(sin(angulo_orbital), 0.0, cos(angulo_orbital))
		var derecha := Vector3(adelante.z, 0.0, -adelante.x)
		foco += adelante * paneo.y + derecha * paneo.x
		necesita_actualizar = true
	if giro != 0.0:
		angulo_orbital += giro * VELOCIDAD_ORBITA * delta
		necesita_actualizar = true
	if necesita_actualizar:
		_actualizar_transform()


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

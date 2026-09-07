extends Camera3D

const NiveladorTerreno = preload("res://scripts/NiveladorTerreno.gd")

## Cámara cenital con perspectiva oblicua para pintar zonas y nivelar
## terreno (ver spec: docs/superpowers/specs/2026-09-07-zonificacion-design.md,
## ampliada a petición del usuario tras pruebas en vivo: perspectiva oblicua
## en vez de ortogonal recta, con paneo (WASD) y rotación orbital (Q/E)
## alrededor de un punto de mira; y modo de nivelación de terreno (tecla
## `B`, ver GDD Sección 5) — sin zoom ni selección de tropas por arrastre
## todavía, eso sigue siendo PoC 6/Fase 4).

const DISTANCIA_CAMARA := 25.0
const ANGULO_INCLINACION := deg_to_rad(55.0)  # inclinación fija sobre la horizontal
const VELOCIDAD_PANEO := 20.0  # celdas/segundo
const VELOCIDAD_ORBITA := deg_to_rad(90.0)  # radianes/segundo

const COLOR_HUELLA_VALIDA := Color(0.2, 1.0, 0.3, 0.4)
const COLOR_HUELLA_INVALIDA := Color(1.0, 0.2, 0.2, 0.4)
const MITAD_HUELLA := 2  # (NiveladorTerreno.TAMANO_HUELLA - 1) / 2, para una huella de 5x5

@onready var mundo: Node = get_node("../VoxelWorld")
@onready var overlay: Node3D = get_node("../ZonaOverlay")

var tipo_zona_seleccionada: String = Zonificacion.ZONAS_PINTABLES[0]
var esperando_segunda_esquina := false
var primera_esquina := Vector2i.ZERO

## Modo de nivelación de terreno (tecla `B`): un recuadro fantasma de
## NiveladorTerreno.TAMANO_HUELLA x TAMANO_HUELLA sigue la celda bajo el
## cursor (esa celda es el CENTRO de la huella, no la esquina) hasta que el
## jugador hace clic para confirmar.
var nivelador: RefCounted
var modo_nivelacion := false
var _huella_fantasma: MeshInstance3D

## Punto de mira sobre el plano del suelo (Y siempre 0): la cámara orbita y
## se desplaza alrededor de este punto, nunca se mueve directamente.
var foco := Vector3.ZERO
var angulo_orbital := 0.0


func _ready() -> void:
	projection = PROJECTION_PERSPECTIVE
	fov = 60.0
	nivelador = NiveladorTerreno.new(mundo.generador)
	_crear_huella_fantasma()


## Crea el recuadro fantasma de previsualización (5x5, translúcido) como
## hijo de esta cámara con top_level = true, para poder fijar su posición
## en coordenadas globales sin heredar la rotación/posición de la cámara.
func _crear_huella_fantasma() -> void:
	var tamano: float = float(NiveladorTerreno.TAMANO_HUELLA)
	var malla := PlaneMesh.new()
	malla.size = Vector2(tamano, tamano)

	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = COLOR_HUELLA_VALIDA

	_huella_fantasma = MeshInstance3D.new()
	_huella_fantasma.mesh = malla
	_huella_fantasma.material_override = material
	_huella_fantasma.top_level = true
	_huella_fantasma.visible = false
	add_child(_huella_fantasma)


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

	if modo_nivelacion:
		_actualizar_huella_fantasma()


## Recalcula la posición y el color del recuadro fantasma según la celda
## actual bajo el cursor (esa celda es el CENTRO de la huella) y si la
## pendiente ahí es válida o no.
func _actualizar_huella_fantasma() -> void:
	var centro := _celda_bajo_mouse(get_viewport().get_mouse_position())
	var esquina := centro - Vector2i(MITAD_HUELLA, MITAD_HUELLA)
	var valida: bool = nivelador.verificar_pendiente(esquina)
	var altura: int = nivelador.altura_objetivo(esquina)

	var material: StandardMaterial3D = _huella_fantasma.material_override
	material.albedo_color = COLOR_HUELLA_VALIDA if valida else COLOR_HUELLA_INVALIDA
	_huella_fantasma.position = Vector3(centro.x, altura + 0.1, centro.y)


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
		elif tecla.pressed and tecla.keycode == KEY_B:
			_alternar_modo_nivelacion()

	if event is InputEventMouseButton:
		var boton := event as InputEventMouseButton
		if boton.pressed and boton.button_index == MOUSE_BUTTON_LEFT:
			if modo_nivelacion:
				_procesar_clic_nivelacion(boton.position)
			else:
				_procesar_clic(boton.position)


func _alternar_modo_nivelacion() -> void:
	modo_nivelacion = not modo_nivelacion
	_huella_fantasma.visible = modo_nivelacion
	if modo_nivelacion:
		print("Modo nivelación activo: haz clic para nivelar la huella marcada (B de nuevo para cancelar).")
	else:
		print("Modo nivelación cancelado.")


func _salir_de_modo_nivelacion() -> void:
	modo_nivelacion = false
	_huella_fantasma.visible = false


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


## Confirma la nivelación de la huella marcada por el recuadro fantasma
## (celda bajo el cursor = centro de la huella). Rechaza si la pendiente
## excede NiveladorTerreno.LIMITE_PENDIENTE; si es válida, rellena con
## "tierra" cada celda hasta la altura máxima de la huella e imprime el
## total de bloques usados. Sale del modo nivelación en ambos casos.
func _procesar_clic_nivelacion(posicion_pantalla: Vector2) -> void:
	var centro := _celda_bajo_mouse(posicion_pantalla)
	var esquina := centro - Vector2i(MITAD_HUELLA, MITAD_HUELLA)

	if not nivelador.verificar_pendiente(esquina):
		print("Nivelación rechazada: la pendiente de esta huella supera el límite permitido (", NiveladorTerreno.LIMITE_PENDIENTE, " bloques por celda).")
		_salir_de_modo_nivelacion()
		return

	var relleno: Dictionary = nivelador.calcular_relleno(esquina)
	var total_bloques := 0
	for celda_relleno in relleno:
		var cantidad: int = relleno[celda_relleno]
		var altura_actual: int = mundo.generador.altura_en(celda_relleno.x, celda_relleno.y)
		for h in range(1, cantidad + 1):
			mundo.colocar_bloque(Vector3i(celda_relleno.x, altura_actual + h, celda_relleno.y), "tierra")
		total_bloques += cantidad

	print("Terreno nivelado: ", total_bloques, " bloques de tierra usados.")
	_salir_de_modo_nivelacion()

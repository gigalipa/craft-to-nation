extends Camera3D

const NiveladorTerreno = preload("res://scripts/NiveladorTerreno.gd")

## Envoltorio para NiveladorTerreno: siempre llama a altura_en(x, z, true)
## (ignora agua). NiveladorTerreno solo necesita .altura_en(x, z) por duck
## typing (mismo patrón que el propio VoxelWorld), así que este envoltorio
## basta para que verificar_pendiente()/calcular_relleno()/altura_objetivo()
## evalúen el terreno REAL bajo un puesto, no la superficie del agua — el
## agua bajo la huella se drena de todos modos al confirmar (ver
## VoxelWorld.drenar_agua()), así que la pendiente y el relleno deben verse
## contra lo que quedará después de drenar, no contra el nivel del mar. La
## tecla `B` ya no activa nivelación manual (ver _alternar_modo_colocar_
## blueprint() más abajo, Task 7).
class _AlturaSinAgua:
	var _mundo: Object

	func _init(mundo: Object) -> void:
		_mundo = mundo

	func altura_en(x: int, z: int) -> int:
		return _mundo.altura_en(x, z, true)

## Cámara cenital con perspectiva oblicua para pintar zonas y nivelar
## terreno (ver spec: docs/superpowers/specs/2026-09-07-zonificacion-design.md,
## rediseñada a petición del usuario tras varias rondas de prueba en vivo):
## - Posición clásica de cámara orbital: global_position = foco + offset
##   (angulo_orbital, angulo_inclinacion, distancia_camara) — ver
##   _posicion_ideal().
## - Paneo (WASD): traslada "foco.x/z" en un plano horizontal perfectamente
##   liso — nunca sigue el relieve, nunca pasa por raycast.
## - Órbita (Q/E) e inclinación (Ctrl+W/Ctrl+S): al EMPEZAR el gesto (tecla
##   recién presionada, ver _gesto_orbital_activo), un raycast fija "foco" al
##   bloque real bajo el centro de la vista y "distancia_camara" a la
##   distancia real de la cámara a ese punto — ese centro/radio queda fijo
##   mientras el gesto continúa (sin volver a hacer raycast cada fotograma),
##   así el paneo simultáneo no lo perturba. Como la altura depende de
##   angulo_inclinacion/distancia_camara, orbitar mantiene la altura (gira en
##   una esfera), e inclinar SÍ cambia la altura (sube/baja por esa esfera).
## - Zoom (rueda del ratón): cambia distancia_camara directamente — también
##   cambia la altura, por la misma fórmula.
## - Altura (Shift+W/Shift+S): mueve "foco.y" directamente — como el offset
##   de altura no depende de foco.y, esto traslada la cámara verticalmente
##   SIN tocar angulo_inclinacion. Altura mínima: la superficie real bajo la
##   propia cámara (raycast vertical) + 1 bloque.
## - Detector de colisiones (_posicion_libre()): ningún control puede mover
##   la cámara dentro de un bloque sólido — si el movimiento comandado
##   colisiona, ese movimiento simplemente no se aplica esta vez (nunca se
##   redirige a otro sentido distinto al que pidió el jugador).
## - Colocación de puestos periféricos con huella real (mina: tecla `M`;
##   caza y recolección: tecla `H`; ver GDD Sección 3 y
##   docs/superpowers/specs/2026-09-10-puestos-huella-real-caza-recoleccion-design.md):
##   huella fantasma de N×M celdas, rotable 90° con Ctrl+rueda del mouse,
##   ficha en vivo en el HUD, confirma solo si pasan las 5 validaciones
##   (zona de influencia, relieve, huella libre de madera/estructura, sin
##   choque con otro puesto, al menos una esquina en tierra firme). Junto a
##   la huella se dibuja un círculo informativo del área de acción real del
##   tipo (radio distinto de la huella — ver _actualizar_area_accion()), y
##   al confirmar la colocación se drena el agua bajo la huella (ver
##   VoxelWorld.drenar_agua()) y se nivela automáticamente el terreno real
##   resultante (mismo mecanismo de nivelación que usa el modo de colocación
##   de blueprint, tecla `B` — ver _AlturaSinAgua/nivelador_puesto — pero
##   ignorando el agua) antes de colocar el marcador.
## - Colocación de blueprint (tecla `B`, ver Task 7 de este plan) reemplaza
##   la antigua nivelación standalone — sin selección de tropas por
##   arrastre todavía, eso sigue siendo PoC 6/Fase 4.

const DISTANCIA_INICIAL := 25.0
const DISTANCIA_MIN := 8.0
const DISTANCIA_MAX := 60.0
const VELOCIDAD_ZOOM := 2.5  # celdas por "tick" de rueda del ratón

const ANGULO_INCLINACION_INICIAL := deg_to_rad(55.0)
const ANGULO_INCLINACION_MIN := deg_to_rad(10.0)  # casi al ras del horizonte
const ANGULO_INCLINACION_MAX := deg_to_rad(89.9)  # cenital recta
const VELOCIDAD_INCLINACION := deg_to_rad(60.0)  # radianes/segundo

const VELOCIDAD_PANEO := 20.0  # celdas/segundo
const VELOCIDAD_ORBITA := deg_to_rad(90.0)  # radianes/segundo

## Shift+W/S: tope superior de altura y velocidad de subida/bajada variable
## — cuadrática según la altura ACTUAL de la cámara (global_position.y, no
## foco.y), para que cambiar de altura sea lento cerca del piso y rápido en
## las alturas máximas (ver _velocidad_altura()).
const ALTURA_MAXIMA_CAMARA := 300.0
const VELOCIDAD_ALTURA_MIN := 15.0  # celdas/segundo, a nivel del piso
const VELOCIDAD_ALTURA_MAX := 300.0  # celdas/segundo, a ALTURA_MAXIMA_CAMARA

const COLOR_PUESTO_VALIDO := Color(1.0, 0.85, 0.0, 0.4)
const COLOR_PUESTO_INVALIDO := Color(1.0, 0.2, 0.2, 0.4)

## Color fijo (no codifica validez, eso ya lo hace la huella) del círculo
## informativo de área de acción — ver _crear_area_accion().
const COLOR_AREA_ACCION := Color(0.3, 0.7, 1.0, 0.15)

## El mayor ancho/alto entre los tipos de puesto existentes (mina 5x5, caza
## y recolección 4x4) — tamaño del pool de planos fantasma reutilizable
## entre cualquier tipo (ver _crear_huella_puesto()).
const MAX_ANCHO_HUELLA_PUESTO := 5
const MAX_ALTO_HUELLA_PUESTO := 5

## El mayor radio de área de acción entre los tipos de puesto existentes
## (Recoleccion.RADIO_AREA_MINA = 6, RADIO_AREA_CAZA_RECOLECCION = 12) —
## mismo criterio que MAX_ANCHO/ALTO_HUELLA_PUESTO: tamaño del pool de
## planos del círculo informativo, reutilizado por cualquier tipo (ver
## _crear_area_accion()).
const RADIO_AREA_ACCION_MAX := 12
const ALCANCE_RAYCAST := 200.0  # cubre cámara + relieve + margen de sobra

## Raycast vertical bajo la propia cámara (ver _altura_bajo_camara()), para
## la altura mínima al bajar con Shift+S — origen bien por encima de
## cualquier relieve/edificio posible, alcance generoso hacia abajo.
const ORIGEN_RAYCAST_VERTICAL_Y := 100.0
const ALCANCE_RAYCAST_VERTICAL := 150.0

## Mismo desfase que ZonaOverlay.gd: GridMap.map_to_local() ubica el origen
## de cada celda en su esquina (no en su centro), así que una celda con
## altura_en() = Y ocupa el rango vertical [Y, Y+1] en el mundo — su cara
## superior real está en Y+1, no en Y. DESF recentra X/Z (la esquina de
## menor X/Z -> el centro de la celda); ALTURA_SOBRE_SUPERFICIE deja el
## plano justo sobre la cara superior real (Y+1), con un pequeño margen.
const DESF := 0.5
const ALTURA_SOBRE_SUPERFICIE := 1.01

## Margen menor que ALTURA_SOBRE_SUPERFICIE a propósito: el círculo de área
## de acción y la huella comparten celdas cerca del centro (el área siempre
## es igual o más grande que la huella), y con la prueba de profundidad
## normal (no_depth_test = false) el plano más alto ocluye al más bajo —
## así la huella (más alta) queda visible sobre el círculo en las celdas
## donde se solapan, y el círculo solo se ve como un halo alrededor.
const ALTURA_SOBRE_SUPERFICIE_AREA_ACCION := 1.001

@onready var mundo: Node = get_node("../VoxelWorld")
@onready var overlay: Node3D = get_node("../ZonaOverlay")
@onready var hud: CanvasLayer = get_node("../HUDLayer")

var tipo_zona_seleccionada: String = Zonificacion.ZONAS_PINTABLES[0]
var esperando_segunda_esquina := false
var primera_esquina := Vector2i.ZERO

var nivelador_puesto: RefCounted

## Modo de colocación de puesto periférico (mina: tecla `M`; caza y
## recolección: tecla `H`) — un rectángulo fantasma de
## _ancho_puesto_activo x _alto_puesto_activo celdas sigue la celda bajo el
## cursor (esa celda es su CENTRO, igual que la huella de nivelación),
## dorado si las 3 validaciones (zona de influencia, relieve, huella libre +
## sin choque con otro puesto) pasan, o rojo si alguna falla. `Ctrl` + rueda
## del mouse rota la huella 90° (intercambia ancho/alto) — ver
## _rotar_huella_puesto(). Mientras el modo está activo, la ficha del HUD
## correspondiente al tipo se actualiza cada fotograma.
var modo_colocar_puesto := false
var _tipo_puesto_activo := ""  # "mina" | "caza_recoleccion"
var _ancho_puesto_activo := 0
var _alto_puesto_activo := 0
var _huella_puesto: Array[MeshInstance3D] = []

## Círculo informativo del área de acción del puesto activo (radio real
## según el tipo — Recoleccion.RADIO_AREA_MINA o RADIO_AREA_CAZA_RECOLECCION
## — no RADIO_AREA_ACCION_MAX, que solo dimensiona el pool), mostrado JUNTO
## a la huella, no en su lugar: la huella marca dónde se construye, el
## círculo hasta dónde recolecta una vez construido. Precalculado para el
## radio máximo existente y filtrado en vivo al radio real del tipo activo
## (ver _actualizar_area_accion()), sin necesitar un pool por tipo.
var _offsets_area_accion: Array[Vector2i] = []
var _area_accion: Array[MeshInstance3D] = []

## Modo de colocación de blueprint (tecla `B`) — reemplaza la antigua
## nivelación standalone. A diferencia de la huella plana de los puestos
## (un rectángulo verde/rojo que solo marca "dónde"), aquí se previsualiza
## una copia translúcida en 3D de la forma REAL del blueprint (una caja por
## celda de blueprint["celdas_3d"]) — "qué" se va a construir, en la
## posición exacta donde quedará tras nivelar. El TAMAÑO (cantidad de
## cajas) varía según el blueprint activo, así que el pool se crea de
## nuevo cada vez que se activa el modo (_crear_huella_blueprint()) en vez
## de tener un tamaño fijo — solo existe un blueprint (residencial) por
## ahora, activarse no es un evento frecuente por fotograma.
var modo_colocar_blueprint := false
var _blueprint_activo: Dictionary = {}
var _huella_blueprint: Array[MeshInstance3D] = []
var _offsets_huella_blueprint: Array[Vector3i] = []

## Punto de mira: la cámara orbita y se inclina a distancia constante
## alrededor de este punto (posición clásica foco + offset, ver
## _posicion_ideal()). El paneo (WASD) mueve "foco.x/z" directamente, sin
## pasar nunca por raycast. Shift+W/S mueve "foco.y" directamente (ver
## _process()) — como el offset de altura depende solo del ángulo/
## distancia, no de foco.y, esto traslada la cámara verticalmente sin
## cambiar su inclinación.
var foco := Vector3.ZERO
var angulo_orbital := 0.0
var angulo_inclinacion := ANGULO_INCLINACION_INICIAL
var distancia_camara := DISTANCIA_INICIAL

## true si en el fotograma anterior había alguna tecla de órbita (Q/E) o
## inclinación (Ctrl+W/S) presionada — para detectar el fotograma exacto en
## que EMPIEZA un gesto de este tipo (ver _process()): "foco" y
## "distancia_camara" solo se recalculan por raycast en ese primer
## fotograma, y quedan fijos como centro/radio del giro mientras el gesto
## continúa, sin importar qué otro movimiento (paneo) ocurra a la vez.
var _gesto_orbital_activo := false


func _ready() -> void:
	projection = PROJECTION_PERSPECTIVE
	fov = 60.0
	# Se le pasa VoxelWorld (mundo), no mundo.generador: NiveladorTerreno solo
	# llama a .altura_en(x,z) por duck typing, y necesitamos la altura REAL
	# del mundo (que sí refleja minado/construcción/nivelaciones previas), no
	# el ruido original de GeneradorMundo — ver VoxelWorld.altura_en().
	nivelador_puesto = NiveladorTerreno.new(_AlturaSinAgua.new(mundo))
	_crear_huella_puesto()
	_crear_area_accion()


## Pool de planos fantasma de tamaño fijo (MAX_ANCHO_HUELLA_PUESTO x
## MAX_ALTO_HUELLA_PUESTO), reutilizado por cualquier tipo de puesto — mismo
## patrón de pool que _crear_huella_puesto(), para no generar basura de
## nodos cada fotograma. Solo se muestran/reposicionan los primeros
## ancho*alto planos de la huella activa (ver _mostrar_huella_puesto()); el
## resto del pool queda oculto.
func _crear_huella_puesto() -> void:
	var malla := PlaneMesh.new()
	malla.size = Vector2(1.0, 1.0)
	for i in range(MAX_ANCHO_HUELLA_PUESTO * MAX_ALTO_HUELLA_PUESTO):
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = COLOR_PUESTO_VALIDO
		material.no_depth_test = false

		var plano := MeshInstance3D.new()
		plano.mesh = malla
		plano.material_override = material
		plano.top_level = true
		plano.visible = false
		add_child(plano)
		_huella_puesto.append(plano)


## Precalcula los offsets (dx, dz) dentro del círculo de radio
## RADIO_AREA_ACCION_MAX (el mayor radio existente) y crea un plano fantasma
## por offset — mismo patrón de pool que _crear_huella_puesto(). Cada
## fotograma solo se muestran los offsets dentro del radio REAL del tipo
## activo (ver _actualizar_area_accion()), así que un solo pool sirve para
## cualquier tipo de puesto sin importar su radio.
func _crear_area_accion() -> void:
	for dx in range(-RADIO_AREA_ACCION_MAX, RADIO_AREA_ACCION_MAX + 1):
		for dz in range(-RADIO_AREA_ACCION_MAX, RADIO_AREA_ACCION_MAX + 1):
			if Vector2(dx, dz).length() <= RADIO_AREA_ACCION_MAX:
				_offsets_area_accion.append(Vector2i(dx, dz))

	var malla := PlaneMesh.new()
	malla.size = Vector2(1.0, 1.0)
	for i in range(_offsets_area_accion.size()):
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = COLOR_AREA_ACCION
		material.no_depth_test = false

		var plano := MeshInstance3D.new()
		plano.mesh = malla
		plano.material_override = material
		plano.top_level = true
		plano.visible = false
		add_child(plano)
		_area_accion.append(plano)


## (Re)crea el pool de cajas fantasma para la previsualización 3D del
## blueprint activo, UNA POR CELDA de "celdas_3d" (a diferencia de
## _crear_huella_puesto(), que usa planos y un pool fijo reutilizado por
## varios tipos — aquí solo hay un blueprint activo a la vez, así que no
## hace falta sobredimensionar). "_offsets_huella_blueprint" guarda el
## offset relativo de cada caja, en el mismo orden que _huella_blueprint,
## para poder reposicionarlas en _actualizar_previsualizacion_blueprint()
## sin depender del orden de iteración del Dictionary en cada fotograma.
## Libera las cajas de una activación anterior antes de crear las nuevas.
func _crear_huella_blueprint(celdas_3d: Dictionary) -> void:
	for caja in _huella_blueprint:
		caja.queue_free()
	_huella_blueprint.clear()
	_offsets_huella_blueprint.clear()

	var malla := BoxMesh.new()
	malla.size = Vector3.ONE
	for rel: Vector3i in celdas_3d:
		_offsets_huella_blueprint.append(rel)

		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = COLOR_PUESTO_VALIDO
		material.no_depth_test = false

		var caja := MeshInstance3D.new()
		caja.mesh = malla
		caja.material_override = material
		caja.top_level = true
		caja.visible = true
		add_child(caja)
		_huella_blueprint.append(caja)


func _mostrar_huella_blueprint(visible_ahora: bool) -> void:
	for plano in _huella_blueprint:
		plano.visible = visible_ahora


## Centra el punto de mira sobre las coordenadas X/Z dadas (la posición del
## jugador en el momento de activar la cenital) y reinicia la orientación
## orbital, la inclinación, la distancia y el estado del gesto de
## órbita/inclinación. Llamada por Main.gd al activar la cámara cenital.
func posicionar_sobre(foco_xz: Vector2) -> void:
	var altura_inicial: int = mundo.altura_en(int(foco_xz.x), int(foco_xz.y))
	foco = Vector3(foco_xz.x, altura_inicial, foco_xz.y)
	angulo_orbital = 0.0
	angulo_inclinacion = ANGULO_INCLINACION_INICIAL
	distancia_camara = DISTANCIA_INICIAL
	_gesto_orbital_activo = false
	_actualizar_transform()
	_refinar_foco_por_mira()
	_actualizar_transform()


## Recalcula la posición/orientación de la cámara a partir de foco,
## angulo_orbital, angulo_inclinacion y distancia_camara (órbita de cámara
## clásica: la cámara nunca se mueve directamente por sí sola). Devuelve la
## posición IDEAL resultante (sin aplicar todavía detección de colisión) —
## quien llama decide si es segura (ver _posicion_libre()) antes de
## comprometerse a ella.
func _posicion_ideal() -> Vector3:
	var direccion_horizontal := Vector3(sin(angulo_orbital), 0.0, cos(angulo_orbital))
	var offset := direccion_horizontal * distancia_camara * cos(angulo_inclinacion)
	offset.y = distancia_camara * sin(angulo_inclinacion)
	return foco + offset


## Aplica la posición/orientación actuales (foco/ángulos/distancia) a la
## cámara de verdad. Separado de _posicion_ideal() para que _process() (ver
## más abajo) pueda calcular la posición candidata, validarla contra
## _posicion_libre() y solo comprometerse (llamando a esta función) si es
## segura.
func _actualizar_transform() -> void:
	global_position = _posicion_ideal()
	look_at(foco, Vector3.UP)


## Detector de colisiones: true si "posicion" NO está dentro de ningún
## cuerpo físico sólido (terreno o edificio) — usa una consulta de punto
## (más directa que un raycast para "¿este punto exacto está ocupado?").
## Quien llama a esto SIEMPRE debe conservar el estado anterior (foco/
## ángulos/distancia) si devuelve false, nunca intentar "corregir" o
## redirigir el movimiento — el jugador solo debe sentir que su comando se
## ignora este fotograma, nunca que la cámara se desvía a otro lado.
func _posicion_libre(posicion: Vector3) -> bool:
	var consulta := PhysicsPointQueryParameters3D.new()
	consulta.position = posicion
	consulta.collide_with_areas = false
	consulta.collide_with_bodies = true
	var resultados: Array = get_world_3d().direct_space_state.intersect_point(consulta, 1)
	return resultados.is_empty()


## Ajusta "foco" al punto real (relieve/bloques, no un plano Y=0 asumido)
## que la cámara tiene efectivamente en la mira — el centro exacto de la
## pantalla, ya que _actualizar_transform() siempre apunta la cámara hacia
## "foco" con look_at(). Requiere que la cámara YA esté posicionada con el
## "foco" previo (llamar _actualizar_transform() antes); si el rayo no
## golpea nada (mira al cielo), conserva el "foco" anterior sin cambios.
## Se usa SOLO para órbita (Q/E) e inclinación (Ctrl+W/S) — el paneo y la
## altura mueven "foco" directamente, nunca a través de este raycast (ver
## _process()), para que esos dos controles se sientan como un
## desplazamiento totalmente liso, jamás "enganchado" al relieve.
func _refinar_foco_por_mira() -> void:
	var centro := get_viewport().get_visible_rect().size / 2.0
	var origen := project_ray_origin(centro)
	var direccion := project_ray_normal(centro)
	var consulta := PhysicsRayQueryParameters3D.create(origen, origen + direccion * ALCANCE_RAYCAST)
	var resultado: Dictionary = get_world_3d().direct_space_state.intersect_ray(consulta)
	if not resultado.is_empty():
		foco = resultado["position"]


## Raycast físico vertical (de arriba hacia abajo) en la posición X/Z ACTUAL
## de la cámara — para la altura mínima de Shift+S (ver _process()), no debe
## depender de dónde está mirando la cámara, solo de qué terreno/edificio
## tiene debajo de sí misma en este momento. Si no golpea nada, devuelve
## -INF (sin piso mínimo real ahí, no se aplica ningún límite).
func _altura_bajo_camara() -> float:
	var x := global_position.x
	var z := global_position.z
	var origen := Vector3(x, ORIGEN_RAYCAST_VERTICAL_Y, z)
	var destino := Vector3(x, ORIGEN_RAYCAST_VERTICAL_Y - ALCANCE_RAYCAST_VERTICAL, z)
	var consulta := PhysicsRayQueryParameters3D.create(origen, destino)
	var resultado: Dictionary = get_world_3d().direct_space_state.intersect_ray(consulta)
	if resultado.is_empty():
		return -INF
	return resultado["position"].y


## Velocidad de Shift+W/S para la altura ACTUAL de la cámara — cuadrática
## entre VELOCIDAD_ALTURA_MIN (a nivel del piso) y VELOCIDAD_ALTURA_MAX (en
## ALTURA_MAXIMA_CAMARA): lenta cerca del suelo, rápida en las alturas
## máximas. "altura_actual" se recorta a [0, ALTURA_MAXIMA_CAMARA] antes de
## calcular la proporción, para que una altura fuera de rango (p. ej. 0 o
## negativa cerca del piso) no distorsione la curva.
func _velocidad_altura(altura_actual: float) -> float:
	var proporcion: float = clampf(altura_actual / ALTURA_MAXIMA_CAMARA, 0.0, 1.0)
	return lerp(VELOCIDAD_ALTURA_MIN, VELOCIDAD_ALTURA_MAX, proporcion * proporcion)


func _process(delta: float) -> void:
	if not current:
		return

	# Shift+W/S ajustan la altura directamente; Ctrl+W/S inclinan la cámara
	# sobre el punto de mira — ambos se comprueban antes que el paneo para
	# que W/S no hagan dos cosas a la vez mientras Shift o Ctrl están
	# presionados.
	var con_mayus: bool = Input.is_key_pressed(KEY_SHIFT)
	var con_ctrl: bool = Input.is_key_pressed(KEY_CTRL)
	var modificador_activo := con_mayus or con_ctrl

	var paneo := Vector2.ZERO
	if not modificador_activo and Input.is_key_pressed(KEY_W):
		paneo.y -= 1
	if not modificador_activo and Input.is_key_pressed(KEY_S):
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

	var cabeceo := 0.0
	if con_ctrl and Input.is_key_pressed(KEY_W):
		cabeceo += 1.0
	if con_ctrl and Input.is_key_pressed(KEY_S):
		cabeceo -= 1.0

	var vuelo := 0.0
	if con_mayus and Input.is_key_pressed(KEY_W):
		vuelo += 1.0
	if con_mayus and Input.is_key_pressed(KEY_S):
		vuelo -= 1.0

	# Detecta el fotograma exacto en que EMPIEZA un gesto de órbita/
	# inclinación (transición de "ninguna tecla" a "alguna tecla" de este
	# grupo) — ver _gesto_orbital_activo.
	var orbita_o_inclina := giro != 0.0 or cabeceo != 0.0
	var inicia_gesto := orbita_o_inclina and not _gesto_orbital_activo
	_gesto_orbital_activo = orbita_o_inclina

	if paneo == Vector2.ZERO and not orbita_o_inclina and vuelo == 0.0:
		if modo_colocar_blueprint:
			_actualizar_previsualizacion_blueprint()
		elif modo_colocar_puesto:
			_actualizar_previsualizacion_puesto()
		elif esperando_segunda_esquina:
			_actualizar_previsualizacion_zona()
		return

	# Estado tentativo: se aplican todos los controles activos este
	# fotograma sobre COPIAS locales, y solo se comprometen (se asignan a
	# las variables reales) si la posición resultante no colisiona — así
	# el jugador nunca ve la cámara "meterse" en un bloque sólido, ni
	# tampoco la ve desviarse a un sentido distinto al que comandó: si hay
	# colisión, el movimiento de este fotograma simplemente no ocurre.
	var foco_nuevo := foco
	var angulo_orbital_nuevo := angulo_orbital
	var angulo_inclinacion_nuevo := angulo_inclinacion
	var distancia_camara_nueva := distancia_camara

	# Solo en el PRIMER fotograma del gesto: fija "foco" al bloque real bajo
	# la mira (raycast) y la distancia real actual entre la cámara y ese
	# punto como radio del giro. Mientras el gesto continúe (tecla
	# mantenida), NO se vuelve a hacer raycast — foco/distancia quedan fijos
	# como centro/radio, así la órbita/inclinación no tiembla ni salta,
	# aunque el paneo siga moviendo foco.x/z simultáneamente.
	if inicia_gesto:
		_refinar_foco_por_mira()
		foco_nuevo = foco
		distancia_camara_nueva = clampf(global_position.distance_to(foco), DISTANCIA_MIN, DISTANCIA_MAX)

	if paneo != Vector2.ZERO:
		# El paneo es relativo a la orientación actual de la cámara: "adelante"
		# siempre aleja el punto de mira de la cámara en pantalla, sin importar
		# el ángulo de órbita. Nunca toca foco.y: el paneo es un plano
		# horizontal perfectamente liso.
		var paneo_norm := paneo.normalized() * VELOCIDAD_PANEO * delta
		var adelante := Vector3(sin(angulo_orbital), 0.0, cos(angulo_orbital))
		var derecha := Vector3(adelante.z, 0.0, -adelante.x)
		foco_nuevo += adelante * paneo_norm.y + derecha * paneo_norm.x
	if giro != 0.0:
		angulo_orbital_nuevo += giro * VELOCIDAD_ORBITA * delta
	if cabeceo != 0.0:
		angulo_inclinacion_nuevo = clampf(
			angulo_inclinacion_nuevo + cabeceo * VELOCIDAD_INCLINACION * delta,
			ANGULO_INCLINACION_MIN,
			ANGULO_INCLINACION_MAX
		)
	if vuelo != 0.0:
		# Shift+W/S mueve foco.y directamente — el offset de altura
		# (distancia*sin(inclinación)) no depende de foco.y, así que esto
		# traslada la cámara verticalmente SIN cambiar angulo_inclinacion.
		# Velocidad cuadrática según la altura ACTUAL (antes de este cambio):
		# lenta cerca del piso, rápida en las alturas máximas. Altura mínima:
		# la superficie real bajo la propia cámara (raycast vertical, no el
		# punto de mira) + 1 bloque de margen. Altura máxima: ALTURA_MAXIMA_
		# CAMARA.
		var offset_y: float = distancia_camara_nueva * sin(angulo_inclinacion_nuevo)
		var velocidad: float = _velocidad_altura(global_position.y)
		var altura_deseada: float = foco_nuevo.y + vuelo * velocidad * delta + offset_y
		var altura_minima: float = _altura_bajo_camara() + 1.0
		altura_deseada = clampf(altura_deseada, altura_minima, ALTURA_MAXIMA_CAMARA)
		foco_nuevo.y = altura_deseada - offset_y

	# Calcula la posición candidata con el estado tentativo (sin
	# comprometerlo todavía) y valida colisión antes de aplicar nada.
	var foco_previo := foco
	var angulo_orbital_previo := angulo_orbital
	var angulo_inclinacion_previo := angulo_inclinacion
	var distancia_camara_previa := distancia_camara
	foco = foco_nuevo
	angulo_orbital = angulo_orbital_nuevo
	angulo_inclinacion = angulo_inclinacion_nuevo
	distancia_camara = distancia_camara_nueva
	var candidata := _posicion_ideal()
	if _posicion_libre(candidata):
		_actualizar_transform()
	else:
		# Colisión: se descarta TODO el movimiento tentativo de este
		# fotograma (no se intenta aplicar parcialmente ni redirigir) — la
		# cámara se queda exactamente donde estaba.
		foco = foco_previo
		angulo_orbital = angulo_orbital_previo
		angulo_inclinacion = angulo_inclinacion_previo
		distancia_camara = distancia_camara_previa

	if modo_colocar_blueprint:
		_actualizar_previsualizacion_blueprint()
	elif modo_colocar_puesto:
		_actualizar_previsualizacion_puesto()
	elif esperando_segunda_esquina:
		_actualizar_previsualizacion_zona()


## Previsualización en vivo de la zona a pintar: mientras se espera la
## segunda esquina (tras el primer click), el rectángulo entre
## "primera_esquina" y la celda actual bajo el cursor se dibuja en
## ZonaOverlay con el color de "tipo_zona_seleccionada", sin escribir nada
## todavía en Zonificacion.zonas — la escritura real ocurre recién en el
## segundo click (ver _procesar_clic()).
func _actualizar_previsualizacion_zona() -> void:
	var celda := _celda_bajo_mouse(get_viewport().get_mouse_position())
	overlay.previsualizar(primera_esquina, celda, tipo_zona_seleccionada)


## true si la huella (esquina, ancho x alto) tiene AL MENOS una esquina en
## tierra firme (no sobre agua) — evita construir puestos enteramente
## flotando en medio de un lago. Basta con revisar las 4 esquinas reales de
## la huella, no la huella completa: alcanza con una esquina firme para
## anclar la construcción, y el resto del agua bajo la huella se drena al
## confirmar (ver VoxelWorld.drenar_agua()).
func _huella_tiene_esquina_en_tierra(esquina: Vector2i, ancho: int, alto: int) -> bool:
	var esquinas := [
		esquina,
		Vector2i(esquina.x + ancho - 1, esquina.y),
		Vector2i(esquina.x, esquina.y + alto - 1),
		Vector2i(esquina.x + ancho - 1, esquina.y + alto - 1),
	]
	for e in esquinas:
		if mundo.obtener_tipo(Vector3i(e.x, mundo.altura_en(e.x, e.y), e.y)) != "agua":
			return true
	return false


## true si algún punto de la huella (esquina, ancho x alto) cae dentro de
## un puesto ya colocado (Recoleccion.puestos, cualquier tipo — mina, caza/
## recolección, o "blueprint") o de una construcción fantasma activa (una
## celda todavía en curso de ser surtida, ver Construccion.gd) — recorre la
## huella completa, no basta revisar solo las esquinas, sería incorrecto
## para un rectángulo genérico. Antes tomaba solo "esquina" y leía
## _ancho_puesto_activo/_alto_puesto_activo — ahora recibe ancho/alto
## explícitos para poder reutilizarse también desde el modo de colocación
## de blueprint (Task 7), que tiene su propio ancho/alto.
func _huella_choca_con_otro_puesto(esquina: Vector2i, ancho: int, alto: int) -> bool:
	for dx in range(ancho):
		for dz in range(alto):
			var xz := Vector2i(esquina.x + dx, esquina.y + dz)
			if Recoleccion.celda_dentro_de_algun_puesto(xz):
				return true
			var celda_superficie := Vector3i(xz.x, mundo.altura_en(xz.x, xz.y) + 1, xz.y)
			if Construccion.construccion_de(celda_superficie) != -1:
				return true
	return false


## Grupos de conversión, en el orden en que se surten (ver spec: relleno de
## tierra -> piso -> paredes/puertas/ventanas -> mobiliario). El relleno de
## tierra no aparece aquí: se calcula y antepone aparte en
## _procesar_clic_blueprint(), antes de estas celdas del blueprint mismo.
## El grupo ["piso"] está hoy siempre vacío en la práctica: "celdas_3d"
## (BlueprintValidator.estructura_a_blueprint()) nunca contiene celdas
## "piso", porque VoxelWorld.detectar_estructura() las excluye a propósito
## (el relleno de piso/terreno nunca forma parte de una estructura
## declarada). Se conserva el grupo de todos modos, por si eso cambia —
## no es código muerto por accidente.
const ORDEN_GRUPOS_CONSTRUCCION := [
	["piso"],
	["pared", "puerta_inferior", "puerta_superior", "ventana"],
	["cama_cabecera", "cama_pies", "baul"],
]


## Devuelve las celdas de "celdas_mundo" (Vector3i real -> tipo) ordenadas
## para conversión: por grupo (ver ORDEN_GRUPOS_CONSTRUCCION, en ese orden),
## y dentro de cada grupo por (y, x, z) para que el orden sea determinista
## y no dependa del orden de iteración del Dictionary de Godot.
func _ordenar_celdas_construccion(celdas_mundo: Dictionary) -> Array:
	var orden: Array[Vector3i] = []
	for grupo in ORDEN_GRUPOS_CONSTRUCCION:
		var celdas_grupo: Array[Vector3i] = []
		for celda in celdas_mundo:
			if grupo.has(celdas_mundo[celda]):
				celdas_grupo.append(celda)
		celdas_grupo.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			if a.y != b.y:
				return a.y < b.y
			if a.x != b.x:
				return a.x < b.x
			return a.z < b.z
		)
		orden.append_array(celdas_grupo)
	return orden


## Recalcula la posición/color de la huella activa según la celda bajo el
## cursor (esa celda es su CENTRO) y la ficha del HUD correspondiente al
## tipo activo. Reemplaza _actualizar_previsualizacion_mina() — ahora
## genérica sobre _tipo_puesto_activo/_ancho_puesto_activo/_alto_puesto_activo.
func _actualizar_previsualizacion_puesto() -> void:
	var centro := _celda_bajo_mouse(get_viewport().get_mouse_position())
	@warning_ignore("integer_division")
	var esquina := centro - Vector2i(_ancho_puesto_activo / 2, _alto_puesto_activo / 2)

	var fuera_de_influencia: bool = not Zonificacion.dentro_de_influencia(centro)
	var relieve_valido: bool = nivelador_puesto.verificar_pendiente(esquina, _ancho_puesto_activo, _alto_puesto_activo)
	var resultado_huella: Dictionary = mundo.verificar_huella_libre(esquina, _ancho_puesto_activo, _alto_puesto_activo)
	var valida: bool = fuera_de_influencia and relieve_valido and resultado_huella["valida"] \
			and not _huella_choca_con_otro_puesto(esquina, _ancho_puesto_activo, _alto_puesto_activo) \
			and _huella_tiene_esquina_en_tierra(esquina, _ancho_puesto_activo, _alto_puesto_activo)
	var color: Color = COLOR_PUESTO_VALIDO if valida else COLOR_PUESTO_INVALIDO

	var i := 0
	for dx in range(_ancho_puesto_activo):
		for dz in range(_alto_puesto_activo):
			var x: int = esquina.x + dx
			var z: int = esquina.y + dz
			var altura_celda: int = mundo.altura_en(x, z, true)
			var plano: MeshInstance3D = _huella_puesto[i]
			var material: StandardMaterial3D = plano.material_override
			material.albedo_color = color
			plano.position = Vector3(x + DESF, altura_celda + ALTURA_SOBRE_SUPERFICIE, z + DESF)
			i += 1

	if _tipo_puesto_activo == "mina":
		var altura_superficie: int = mundo.altura_en(centro.x, centro.y)
		var conteo: Dictionary = Recoleccion.detectar_recursos(mundo, centro, altura_superficie)
		var tasas: Dictionary = Recoleccion.tasas_recoleccion(conteo)
		hud.actualizar_tasas_mina(tasas)
		_actualizar_area_accion(centro, Recoleccion.RADIO_AREA_MINA)
	else:
		var promedios: Dictionary = Recoleccion.detectar_fauna_frutal(mundo.generador, centro)
		var tasas_caza: Dictionary = Recoleccion.tasas_caza_recoleccion(promedios)
		hud.actualizar_tasas_caza(tasas_caza)
		_actualizar_area_accion(centro, Recoleccion.RADIO_AREA_CAZA_RECOLECCION)


## Altura real (en bloques) de un blueprint: máximo "rel.y" entre las claves
## de "celdas_3d" (offsets Vector3i relativos), más 1 — usada para que
## verificar_huella_libre() revise todos los niveles que ocupará el
## blueprint al colocarse, no solo el nivel superficie+1 (suficiente para
## los puestos de un solo bloque, insuficiente para un edificio de varios
## pisos).
func _altura_blueprint(blueprint: Dictionary) -> int:
	var max_y := 0
	for rel: Vector3i in blueprint["celdas_3d"]:
		max_y = max(max_y, rel.y)
	return max_y + 1


## Recalcula la posición/color de la previsualización 3D del blueprint
## activo según la celda bajo el cursor (esa celda es su CENTRO, igual que
## los puestos). A diferencia de los puestos (regla: fuera de la zona de
## influencia), aquí la regla de zona es la opuesta: la celda debe caer
## DENTRO de una zona pintada que coincida con blueprint["zona_permitida"].
## Cada caja se posiciona en la misma coordenada exacta donde quedaría el
## bloque real si se confirmara ahora mismo (mismo cálculo que
## _procesar_clic_blueprint(): esquina + rel, apoyado sobre "objetivo" —
## la altura a la que quedaría nivelado el terreno), así la previsualización
## no miente sobre dónde va a caer la construcción.
func _actualizar_previsualizacion_blueprint() -> void:
	var centro := _celda_bajo_mouse(get_viewport().get_mouse_position())
	var ancho: int = _blueprint_activo["ancho"]
	var alto: int = _blueprint_activo["profundidad"]
	@warning_ignore("integer_division")
	var esquina := centro - Vector2i(ancho / 2, alto / 2)

	var zona_correcta: bool = Zonificacion.consultar_zona(centro) == _blueprint_activo["zona_permitida"]
	var relieve_valido: bool = nivelador_puesto.verificar_pendiente(esquina, ancho, alto)
	var altura_blueprint: int = _altura_blueprint(_blueprint_activo)
	var resultado_huella: Dictionary = mundo.verificar_huella_libre(esquina, ancho, alto, altura_blueprint)
	var valida: bool = zona_correcta and relieve_valido and resultado_huella["valida"] \
			and not _huella_choca_con_otro_puesto(esquina, ancho, alto) \
			and _huella_tiene_esquina_en_tierra(esquina, ancho, alto)
	var color: Color = COLOR_PUESTO_VALIDO if valida else COLOR_PUESTO_INVALIDO

	var objetivo: int = nivelador_puesto.altura_objetivo(esquina, ancho, alto)
	for i in range(_offsets_huella_blueprint.size()):
		var rel: Vector3i = _offsets_huella_blueprint[i]
		var x: int = esquina.x + rel.x
		var y: int = objetivo + 1 + rel.y
		var z: int = esquina.y + rel.z
		var caja: MeshInstance3D = _huella_blueprint[i]
		var material: StandardMaterial3D = caja.material_override
		material.albedo_color = color
		caja.position = Vector3(x + DESF, y + DESF, z + DESF)


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
		elif tecla.pressed and tecla.keycode == KEY_M:
			_alternar_modo_colocar_puesto("mina", Recoleccion.ANCHO_HUELLA_MINA, Recoleccion.ALTO_HUELLA_MINA)
		elif tecla.pressed and tecla.keycode == KEY_H:
			_alternar_modo_colocar_puesto("caza_recoleccion", Recoleccion.ANCHO_HUELLA_CAZA_RECOLECCION, Recoleccion.ALTO_HUELLA_CAZA_RECOLECCION)
		elif tecla.pressed and tecla.keycode == KEY_B:
			_alternar_modo_colocar_blueprint()

	if event is InputEventMouseButton:
		var boton := event as InputEventMouseButton
		if boton.pressed and boton.button_index == MOUSE_BUTTON_LEFT:
			if modo_colocar_blueprint:
				_procesar_clic_blueprint(boton.position)
			elif modo_colocar_puesto:
				_procesar_clic_puesto(boton.position)
			else:
				_procesar_clic(boton.position)
		elif boton.pressed and boton.button_index == MOUSE_BUTTON_WHEEL_UP:
			if modo_colocar_puesto and Input.is_key_pressed(KEY_CTRL):
				_rotar_huella_puesto()
			else:
				_intentar_zoom(-VELOCIDAD_ZOOM)
		elif boton.pressed and boton.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if modo_colocar_puesto and Input.is_key_pressed(KEY_CTRL):
				_rotar_huella_puesto()
			else:
				_intentar_zoom(VELOCIDAD_ZOOM)


## Igual que el resto de controles: aplica el zoom tentativamente, y solo
## lo compromete (y mueve la cámara) si la posición resultante no
## colisiona — si colisiona, la distancia de zoom no cambia (nunca se
## "fuerza" a una distancia distinta a la pedida).
func _intentar_zoom(delta_distancia: float) -> void:
	var distancia_previa := distancia_camara
	distancia_camara = clampf(distancia_camara + delta_distancia, DISTANCIA_MIN, DISTANCIA_MAX)
	var candidata := _posicion_ideal()
	if _posicion_libre(candidata):
		_actualizar_transform()
	else:
		distancia_camara = distancia_previa


## Activa el modo de colocación del puesto "tipo" (huella ancho x alto). Si
## ya estaba activo ESE MISMO tipo, lo cancela (mismo toggle que antes tenía
## _alternar_modo_colocar_puesto()); si estaba activo otro tipo, cambia
## directamente al nuevo sin necesidad de cancelar primero. M y H llaman a
## esta misma función con su tipo/huella respectivos (ver _unhandled_input()).
func _alternar_modo_colocar_puesto(tipo: String, ancho: int, alto: int) -> void:
	if modo_colocar_puesto and _tipo_puesto_activo == tipo:
		_salir_de_modo_colocar_puesto()
		print("Modo colocar %s cancelado." % tipo)
		return
	# Ver el comentario equivalente en _alternar_modo_colocar_blueprint(): los
	# modos son mutuamente excluyentes.
	if modo_colocar_blueprint:
		_salir_de_modo_colocar_blueprint()
	hud.ocultar_ficha_mina()
	hud.ocultar_ficha_caza()
	assert(ancho <= MAX_ANCHO_HUELLA_PUESTO and alto <= MAX_ALTO_HUELLA_PUESTO, "Huella de puesto excede el pool fijo de planos fantasma")
	modo_colocar_puesto = true
	_tipo_puesto_activo = tipo
	_ancho_puesto_activo = ancho
	_alto_puesto_activo = alto
	_mostrar_huella_puesto(true)
	if tipo == "mina":
		hud.mostrar_ficha_mina()
	else:
		hud.mostrar_ficha_caza()
	print("Modo colocar %s activo: haz clic para confirmar (misma tecla de nuevo para cancelar)." % tipo)


func _salir_de_modo_colocar_puesto() -> void:
	modo_colocar_puesto = false
	_mostrar_huella_puesto(false)
	_ocultar_area_accion()
	hud.ocultar_ficha_mina()
	hud.ocultar_ficha_caza()
	_tipo_puesto_activo = ""


## Ctrl + rueda del mouse, solo con un puesto en modo colocación: rota la
## huella activa 90° (intercambia ancho/alto). Sin efecto visible en mina
## (5x5) ni caza/recolección (4x4) — ambas cuadradas — hasta que exista un
## puesto con huella no cuadrada (p. ej. un futuro maderero, 3x4).
func _rotar_huella_puesto() -> void:
	var ancho_previo := _ancho_puesto_activo
	_ancho_puesto_activo = _alto_puesto_activo
	_alto_puesto_activo = ancho_previo
	_mostrar_huella_puesto(true)


## Activa/cancela el modo de colocación de blueprint (toggle simple, un solo
## blueprint posible a la vez — a diferencia de _alternar_modo_colocar_puesto(),
## no recibe tipo/ancho/alto porque hoy solo existe un blueprint guardado,
## el de "residencial_investigacion"). Si no hay ningún blueprint guardado
## todavía, avisa y no entra al modo.
func _alternar_modo_colocar_blueprint() -> void:
	if modo_colocar_blueprint:
		_salir_de_modo_colocar_blueprint()
		print("Modo colocar blueprint cancelado.")
		return
	var blueprint: Dictionary = Blueprints.obtener("residencial_investigacion")
	if blueprint.is_empty():
		print("No hay ningún blueprint guardado todavía — declara un edificio primero.")
		return
	if modo_colocar_puesto:
		_salir_de_modo_colocar_puesto()
	_blueprint_activo = blueprint
	_crear_huella_blueprint(blueprint["celdas_3d"])
	modo_colocar_blueprint = true
	print("Modo colocar blueprint activo: haz clic dentro de una zona residencial para confirmar (B de nuevo para cancelar).")


func _salir_de_modo_colocar_blueprint() -> void:
	modo_colocar_blueprint = false
	_mostrar_huella_blueprint(false)
	_blueprint_activo = {}


## Sale de cualquier modo de interacción de esta cámara (colocar blueprint,
## colocar puesto, pintar zona) — llamada por Main.gd al cambiar a la cámara
## en 1ª persona. Sin esto, la huella fantasma del blueprint o la huella del
## puesto (hijos de esta cámara, independientes de si `current` está activo)
## seguirían visibles y congeladas tras salir de la vista cenital, porque su
## visibilidad solo depende de estas banderas de modo, nunca de qué cámara
## está activa.
func salir_de_todos_los_modos() -> void:
	_salir_de_modo_colocar_blueprint()
	_salir_de_modo_colocar_puesto()


## Muestra los primeros _ancho_puesto_activo * _alto_puesto_activo planos
## del pool (ver _crear_huella_puesto()) y oculta el resto; con
## visible_ahora=false oculta todo el pool.
func _mostrar_huella_puesto(visible_ahora: bool) -> void:
	for plano in _huella_puesto:
		plano.visible = false
	if not visible_ahora:
		return
	for i in range(_ancho_puesto_activo * _alto_puesto_activo):
		_huella_puesto[i].visible = true


## Muestra, centrados en "centro", los planos del pool de _area_accion cuyo
## offset cae dentro de "radio" (a la altura real de su propia celda,
## ignorando agua — mismo criterio visual que la huella) y oculta el resto
## del pool. Se filtra por longitud en cada llamada (no por un rango fijo
## del pool) porque el radio real cambia según el tipo de puesto activo.
func _actualizar_area_accion(centro: Vector2i, radio: int) -> void:
	for i in range(_offsets_area_accion.size()):
		var offset: Vector2i = _offsets_area_accion[i]
		var plano: MeshInstance3D = _area_accion[i]
		if offset.length() > radio:
			plano.visible = false
			continue
		var x: int = centro.x + offset.x
		var z: int = centro.y + offset.y
		var altura_celda: int = mundo.altura_en(x, z, true)
		plano.position = Vector3(x + DESF, altura_celda + ALTURA_SOBRE_SUPERFICIE_AREA_ACCION, z + DESF)
		plano.visible = true


func _ocultar_area_accion() -> void:
	for plano in _area_accion:
		plano.visible = false


## Convierte una posición de pantalla en la celda de grid (X,Z) que hay
## debajo, mediante un raycast físico real contra la colisión del terreno
## (la misma que usa Player.gd para minar/colocar) — no basta con
## intersecar un plano fijo en y = 0: con relieve real (0-15 de altura) y
## una cámara en ángulo oblicuo, un rayo que visualmente toca el terreno a
## media altura sigue viajando mucho más lejos horizontalmente antes de
## llegar a y = 0, desplazando la celda detectada muy lejos del cursor. Si
## el rayo no golpea nada (apunta al cielo, fuera del mundo generado), cae
## de vuelta a la intersección con el plano y = 0 como aproximación.
func _celda_bajo_mouse(posicion_pantalla: Vector2) -> Vector2i:
	var origen := project_ray_origin(posicion_pantalla)
	var direccion := project_ray_normal(posicion_pantalla)

	var consulta := PhysicsRayQueryParameters3D.create(origen, origen + direccion * ALCANCE_RAYCAST)
	var resultado: Dictionary = get_world_3d().direct_space_state.intersect_ray(consulta)

	var punto: Vector3
	if resultado.is_empty():
		var distancia: float = -origen.y / direccion.y
		punto = origen + direccion * distancia
	else:
		# Desplaza ligeramente hacia adentro de la cara golpeada (misma técnica
		# que Player._celda_impactada()) para caer siempre dentro de la celda
		# sólida y no en la vecina vacía.
		var normal: Vector3 = resultado["normal"]
		punto = resultado["position"] - normal * 0.5

	var celda: Vector3i = mundo.local_to_map(mundo.to_local(punto))
	return Vector2i(celda.x, celda.z)


func _procesar_clic(posicion_pantalla: Vector2) -> void:
	var celda := _celda_bajo_mouse(posicion_pantalla)
	if not esperando_segunda_esquina:
		primera_esquina = celda
		esperando_segunda_esquina = true
		print("Primera esquina de la zona: ", primera_esquina)
		overlay.previsualizar(primera_esquina, primera_esquina, tipo_zona_seleccionada)
		return

	var pintadas: int = Zonificacion.pintar_zona(primera_esquina, celda, tipo_zona_seleccionada)
	print("Zona '", tipo_zona_seleccionada, "' pintada en ", pintadas, " celda(s).")
	if pintadas == 0 and not Zonificacion.nucleo_declarado:
		print("Todavía no existe una zona de influencia — declara tu primer edificio residencial primero.")
	esperando_segunda_esquina = false
	overlay.reconstruir()


## Confirma la colocación del puesto activo en la celda bajo el cursor si
## las 5 validaciones (zona de influencia, relieve, huella libre, sin choque
## con otro puesto, al menos una esquina en tierra firme) pasan — si no,
## imprime el motivo y PERMANECE en modo colocar-puesto (el jugador puede
## reintentar de inmediato, igual que la mina original; mismo comportamiento
## que _procesar_clic_blueprint() con el modo de colocación de blueprint). El
## follaje detectado se elimina; luego se drena el agua bajo la huella
## (VoxelWorld.drenar_agua()) y se nivela al punto más alto del terreno REAL
## resultante contra "nivelador_puesto" — que ignora el agua, ver
## _AlturaSinAgua — antes de colocar el marcador, así la "construcción"
## siempre queda sobre terreno plano y seco, nunca sobre o bajo el agua. La
## validación de pendiente (verificar_pendiente(), arriba) ya usa ese mismo
## terreno sin agua — es la que decide si la huella es demasiado empinada
## para nivelarse de forma razonable.
func _procesar_clic_puesto(posicion_pantalla: Vector2) -> void:
	var centro := _celda_bajo_mouse(posicion_pantalla)
	@warning_ignore("integer_division")
	var esquina := centro - Vector2i(_ancho_puesto_activo / 2, _alto_puesto_activo / 2)

	if Zonificacion.dentro_de_influencia(centro):
		print("No se puede colocar un puesto dentro de la zona de influencia.")
		return
	if not nivelador_puesto.verificar_pendiente(esquina, _ancho_puesto_activo, _alto_puesto_activo):
		print("Colocación rechazada: la pendiente de esta huella supera el límite permitido.")
		return
	var resultado_huella: Dictionary = mundo.verificar_huella_libre(esquina, _ancho_puesto_activo, _alto_puesto_activo)
	if not resultado_huella["valida"]:
		print("Colocación rechazada: la huella choca con un recurso de madera o una estructura existente.")
		return
	if _huella_choca_con_otro_puesto(esquina, _ancho_puesto_activo, _alto_puesto_activo):
		print("Colocación rechazada: la huella choca con un puesto ya colocado.")
		return
	if not _huella_tiene_esquina_en_tierra(esquina, _ancho_puesto_activo, _alto_puesto_activo):
		print("Colocación rechazada: la huella necesita al menos una esquina sobre tierra firme.")
		return

	for celda_follaje in resultado_huella["follaje_a_eliminar"]:
		mundo.eliminar_follaje(celda_follaje)

	var total_drenado := 0
	for dx in range(_ancho_puesto_activo):
		for dz in range(_alto_puesto_activo):
			total_drenado += mundo.drenar_agua(esquina.x + dx, esquina.y + dz)
	if total_drenado > 0:
		print("Agua drenada bajo el puesto: ", total_drenado, " bloques reemplazados por tierra.")

	var objetivo: int = nivelador_puesto.altura_objetivo(esquina, _ancho_puesto_activo, _alto_puesto_activo)
	var relleno: Dictionary = nivelador_puesto.calcular_relleno(esquina, _ancho_puesto_activo, _alto_puesto_activo)
	var total_relleno := 0
	for celda_relleno in relleno:
		var cantidad: int = relleno[celda_relleno]
		var altura_actual: int = mundo.altura_en(celda_relleno.x, celda_relleno.y)
		for h in range(1, cantidad + 1):
			mundo.colocar_bloque(Vector3i(celda_relleno.x, altura_actual + h, celda_relleno.y), "tierra")
		total_relleno += cantidad
	if total_relleno > 0:
		print("Terreno nivelado bajo el puesto: ", total_relleno, " bloques de tierra usados.")

	var bloque_marcador: String = "mina" if _tipo_puesto_activo == "mina" else "puesto_caza"
	for dx in range(_ancho_puesto_activo):
		for dz in range(_alto_puesto_activo):
			mundo.colocar_bloque(Vector3i(esquina.x + dx, objetivo + 1, esquina.y + dz), bloque_marcador)

	Recoleccion.colocar_puesto(esquina, _tipo_puesto_activo, _ancho_puesto_activo, _alto_puesto_activo)
	print("Puesto '%s' colocado en (%d, %d)." % [_tipo_puesto_activo, esquina.x, esquina.y])

	_salir_de_modo_colocar_puesto()


## Confirma la colocación del blueprint activo en la celda bajo el cursor
## si las 5 validaciones (zona correcta, relieve, huella libre, sin choque,
## esquina en tierra firme) pasan — si no, imprime el motivo y PERMANECE en
## modo colocar-blueprint. A diferencia de _procesar_clic_puesto() (que
## coloca el marcador de inmediato), esto NO completa nada: drena el agua,
## calcula el relleno de nivelación, reubica blueprint["celdas_3d"] en el
## mundo, arma el orden de conversión (relleno de tierra primero, luego
## piso/paredes-puertas-ventanas/mobiliario — ver _ordenar_celdas_construccion())
## e inicia la construcción fantasma (VoxelWorld.iniciar_construccion_fantasma()) —
## la finalización real ocurre después, celda por celda, cuando el jugador
## la surte (ver Player._minar()/_completar_construccion()).
func _procesar_clic_blueprint(posicion_pantalla: Vector2) -> void:
	var centro := _celda_bajo_mouse(posicion_pantalla)
	var ancho: int = _blueprint_activo["ancho"]
	var alto: int = _blueprint_activo["profundidad"]
	@warning_ignore("integer_division")
	var esquina := centro - Vector2i(ancho / 2, alto / 2)

	if Zonificacion.consultar_zona(centro) != _blueprint_activo["zona_permitida"]:
		print("Colocación rechazada: esta zona no acepta este blueprint.")
		return
	if not nivelador_puesto.verificar_pendiente(esquina, ancho, alto):
		print("Colocación rechazada: la pendiente de esta huella supera el límite permitido.")
		return
	var altura_blueprint: int = _altura_blueprint(_blueprint_activo)
	var resultado_huella: Dictionary = mundo.verificar_huella_libre(esquina, ancho, alto, altura_blueprint)
	if not resultado_huella["valida"]:
		print("Colocación rechazada: la huella choca con un recurso de madera o una estructura existente.")
		return
	if _huella_choca_con_otro_puesto(esquina, ancho, alto):
		print("Colocación rechazada: la huella choca con un puesto o construcción ya colocada.")
		return
	if not _huella_tiene_esquina_en_tierra(esquina, ancho, alto):
		print("Colocación rechazada: la huella necesita al menos una esquina sobre tierra firme.")
		return

	for celda_follaje in resultado_huella["follaje_a_eliminar"]:
		mundo.eliminar_follaje(celda_follaje)

	var total_drenado := 0
	for dx in range(ancho):
		for dz in range(alto):
			total_drenado += mundo.drenar_agua(esquina.x + dx, esquina.y + dz)
	if total_drenado > 0:
		print("Agua drenada bajo la construcción: ", total_drenado, " bloques reemplazados por tierra.")

	var objetivo: int = nivelador_puesto.altura_objetivo(esquina, ancho, alto)
	var relleno: Dictionary = nivelador_puesto.calcular_relleno(esquina, ancho, alto)
	var relleno_orden: Array[Vector3i] = []
	for celda_relleno in relleno:
		var cantidad: int = relleno[celda_relleno]
		var altura_actual: int = mundo.altura_en(celda_relleno.x, celda_relleno.y)
		for h in range(1, cantidad + 1):
			relleno_orden.append(Vector3i(celda_relleno.x, altura_actual + h, celda_relleno.y))

	var celdas_mundo: Dictionary = {}  # Vector3i real -> tipo
	for rel in _blueprint_activo["celdas_3d"]:
		var real := Vector3i(esquina.x + rel.x, objetivo + 1 + rel.y, esquina.y + rel.z)
		celdas_mundo[real] = _blueprint_activo["celdas_3d"][rel]

	var orden: Array = relleno_orden + _ordenar_celdas_construccion(celdas_mundo)
	var tipos: Dictionary = {}
	for celda_r in relleno_orden:
		tipos[celda_r] = "tierra"
	for celda in celdas_mundo:
		tipos[celda] = celdas_mundo[celda]

	var huella_xz: Array = []
	var vistos_xz: Dictionary = {}
	for celda in celdas_mundo:
		var xz := Vector2i(celda.x, celda.z)
		if not vistos_xz.has(xz):
			vistos_xz[xz] = true
			huella_xz.append(xz)

	var metadata := {
		"blueprint": _blueprint_activo,
		"huella_xz": huella_xz,
		"esquina": esquina,
		"ancho": ancho,
		"profundidad": alto,
	}
	mundo.iniciar_construccion_fantasma(orden, tipos, metadata)
	print("Construcción fantasma iniciada en (", esquina.x, ", ", esquina.y, ") — surtir para completarla.")

	_salir_de_modo_colocar_blueprint()

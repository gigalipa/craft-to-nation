extends Camera3D

const NiveladorTerreno = preload("res://scripts/NiveladorTerreno.gd")
const NivelacionOverlay = preload("res://scripts/NivelacionOverlay.gd")
const TrazadorVias = preload("res://scripts/TrazadorVias.gd")
const ConstructorVias = preload("res://scripts/ConstructorVias.gd")
const PlantillasPuesto = preload("res://scripts/PlantillasPuesto.gd")

## Envoltorio para NiveladorTerreno: siempre llama a altura_en(x, z, true)
## (ignora agua). NiveladorTerreno solo necesita .altura_en(x, z) por duck
## typing (mismo patrón que el propio VoxelWorld), así que este envoltorio
## basta para que verificar_pendiente()/calcular_relleno()/altura_objetivo()
## evalúen el terreno REAL bajo un puesto, no la superficie del agua — el
## agua bajo la huella de un puesto se drena al confirmar (ver
## VoxelWorld.drenar_agua()), así que la pendiente y el relleno deben verse
## contra lo que quedará después de drenar, no contra el nivel del mar. Los
## blueprints, en cambio, no drenan al confirmar: su agua se rellena celda a
## celda al surtirlos (ver VoxelWorld._reemplazar_celda()). La
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
##   caza y recolección: tecla `H`; maderero: tecla `L`; pesca y frutos del
##   mar: tecla `F`; ver GDD Sección 3 y
##   docs/superpowers/specs/2026-09-10-puestos-huella-real-caza-recoleccion-design.md):
##   huella fantasma de N×M celdas, rotable 90° con Ctrl+rueda del mouse,
##   ficha en vivo en el HUD, confirma solo si pasan las 5 validaciones
##   (zona de influencia, relieve, huella libre de madera/estructura, sin
##   choque con otro puesto, al menos una esquina en tierra firme para la
##   mayoría de los tipos — "pesca_frutos_mar" es la excepción: exactamente
##   uno de sus dos extremos debe ser agua, ver
##   _extremo_agua_de_huella_pesca()). Junto a la huella se dibuja un
##   círculo informativo del área de acción real del tipo (radio distinto
##   de la huella — ver
##   _actualizar_area_accion()), y al confirmar la colocación se drena el
##   agua bajo la huella (ver VoxelWorld.drenar_agua()) y se nivela
##   automáticamente el terreno real resultante (mismo mecanismo de
##   nivelación que usa el modo de colocación de blueprint, tecla `B` — ver
##   _AlturaSinAgua/nivelador_puesto — pero ignorando el agua) antes de
##   colocar el marcador — de nuevo con la excepción de "pesca_frutos_mar",
##   que en vez de drenar coloca pilotes bajo la huella (ver
##   _procesar_clic_puesto()).
## - Colocación de blueprint (tecla `B`, ver Task 7 de este plan) reemplaza
##   la antigua nivelación standalone — sin selección de tropas por
##   arrastre todavía, eso sigue siendo PoC 7/Fase 4.

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
## y recolección 4x4, pesca y frutos del mar 4x6 — este último es el que fija
## el valor actual (6)) — tamaño del pool de planos fantasma reutilizable
## entre cualquier tipo (ver _crear_huella_puesto()).
const MAX_ANCHO_HUELLA_PUESTO := 6
const MAX_ALTO_HUELLA_PUESTO := 6

## El mayor radio de área de acción entre los tipos de puesto existentes
## (Recoleccion.RADIO_AREA_MINA = 6, RADIO_AREA_CAZA_RECOLECCION = 12,
## RADIO_AREA_PESCA_FRUTOS_MAR = 25 — este último es el que fija el valor
## actual) — mismo criterio que MAX_ANCHO/ALTO_HUELLA_PUESTO: tamaño del
## pool de planos del círculo informativo, reutilizado por cualquier tipo
## (ver _crear_area_accion()).
const RADIO_AREA_ACCION_MAX := 25
const ALCANCE_RAYCAST := 200.0  # cubre cámara + relieve + margen de sobra
## Las consultas físicas de la cámara (picking del terreno, altura mínima,
## colisión de la propia cámara) solo deben ver el mundo (capa 1), no los
## cuerpos de los colonos (capa 2, ver ColonosRenderer.gd).
const MASCARA_MUNDO := 1

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
@onready var via_preview: Node3D = get_node("../ViaPreviewOverlay")
@onready var hud: CanvasLayer = get_node("../HUDLayer")

## Modo zonificación (tecla `Z`): mientras está activo, el clic izquierdo pinta
## zona (dos esquinas) y `1`/`2`/`0` eligen la zona A, la zona B o borrar. Sin
## este modo (ni otro) el clic solo abre/cierra el panel de un puesto.
var modo_zonificar := false
var tipo_zona_seleccionada: String = Zonificacion.ZONAS_PINTABLES[0]
var esperando_segunda_esquina := false
var primera_esquina := Vector2i.ZERO

## Modo trazador de vías (tecla `V`) — ver spec de vías Sección 4.
var modo_trazar_via := false
var _hay_tramo_en_curso := false
var _vertice_inicio_tramo := Vector2i.ZERO
var _tramos_fijos: Array = []  # Array[Array[Vector2i]]
var _trazador_via: RefCounted = null

## Último origen/vértice bajo el mouse para los que se corrió
## buscar_ruta() en _actualizar_preview_via() — evita repetir la A*
## completa cada fotograma cuando ninguno cambió (ver I2 de la revisión
## final: un objetivo inalcanzable expandía hasta MAX_NODOS_EXPANDIDOS
## cada fotograma). Vector2i(999999, 999999): centinela que nunca es un
## vértice real del mundo, así la primera llamada siempre recalcula.
const SIN_VERTICE_PREVIO := Vector2i(999999, 999999)
var _ultimo_origen_preview := SIN_VERTICE_PREVIO
var _ultimo_vertice_preview := SIN_VERTICE_PREVIO

## Tope de nodos expandidos de la búsqueda de la VISTA PREVIA (no la del
## clic real, que sigue usando TrazadorVias.MAX_NODOS_EXPANDIDOS) —
## reportado jugando en vivo (2026-09-23): un destino inalcanzable agota
## el tope completo (5000) cada vez que se consulta por primera vez, y
## eso se sentía pesado incluso con la memoización de TrazadorVias. Con
## un tope más bajo, "sin ruta" se confirma más rápido mientras se traza;
## el clic real (una sola vez, no cada fotograma) sigue con el tope
## completo para no perder alcance real de trazado.
const MAX_NODOS_PREVIEW_VIA := 600

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
var _tipo_puesto_activo := ""  # "mina" | "caza_recoleccion" | "maderero" | "pesca_frutos_mar"
var _ancho_puesto_activo := 0
var _alto_puesto_activo := 0
## Cuartos de vuelta horarios (0-3) de la plantilla del puesto activo; Ctrl +
## rueda lo avanza (ver _rotar_huella_puesto()) y decide hacia dónde mira la puerta.
var _giros_puesto := 0
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
## Última esquina para la que se calculó el resumen de materiales del HUD
## (se recalcula solo si cambia, o si se invalida al rotar/entrar al modo).
const SIN_RESUMEN := Vector2i(-999999, -999999)
var _resumen_blueprint_vigente: Vector2i = SIN_RESUMEN
## Última esquina para la que se dibujaron los overlays de nivelación (mismo
## criterio que _resumen_blueprint_vigente).
var _overlay_vigente: Vector2i = SIN_RESUMEN
var _overlay_nivelacion: NivelacionOverlay

const MENSAJES_BASE_Y := {
	"pendiente": "Colocación rechazada: el desnivel entre una puerta y el suelo frente a ella supera el límite permitido.",
	"puertas": "Colocación rechazada: las puertas de este edificio quedarían a niveles distintos (el suelo frente a cada una tiene otra altura).",
	"frente": "Colocación rechazada: el suelo frente a una puerta es agua o queda fuera del mundo.",
}

## Altura en bloques del despeje de una puerta: hasta dónde se revisa que el
## frente (la fachada) esté libre de árboles y estructuras.
const ALTURA_PUERTA := 2

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
	_overlay_nivelacion = NivelacionOverlay.new()
	add_child(_overlay_nivelacion)


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
	consulta.collision_mask = MASCARA_MUNDO
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
	consulta.collision_mask = MASCARA_MUNDO
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
	consulta.collision_mask = MASCARA_MUNDO
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
		elif modo_trazar_via and _hay_tramo_en_curso:
			_actualizar_preview_via()
		elif modo_trazar_via and not _hay_tramo_en_curso:
			_actualizar_preview_vertice_inicial()
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


## Genera las columnas Vector2i(dx, dz) de un rectángulo ancho x alto
## (offsets relativos a una esquina) — usada por los puestos periféricos
## (mina, caza/recolección), que siguen siendo rectángulos fijos, para
## seguir pasando su huella a las funciones ya generalizadas a "columnas"
## (ver docs/superpowers/specs/2026-09-10-huellas-irregulares-design.md).
## Los blueprints, en cambio, usan directamente blueprint["huella_relativa"].
func _columnas_rectangulo(ancho: int, alto: int) -> Array[Vector2i]:
	var columnas: Array[Vector2i] = []
	for dx in range(ancho):
		for dz in range(alto):
			columnas.append(Vector2i(dx, dz))
	return columnas


## true si AL MENOS una columna real de la huella (esquina + columnas)
## está en tierra firme (no sobre agua) — evita construir puestos o
## blueprints enteramente flotando en medio de un lago. Basta con una
## columna firme para anclar la construcción; el resto del agua bajo la
## huella se drena al confirmar un puesto (ver VoxelWorld.drenar_agua()) o,
## en un blueprint, se rellena celda a celda al surtirlo (ver
## VoxelWorld._reemplazar_celda()). Antes solo
## revisaba las 4 esquinas del rectángulo delimitador — para una huella
## irregular (un edificio en L) esas esquinas pueden no ser parte real del
## edificio, así que ahora revisa TODAS las columnas reales (ver
## docs/superpowers/specs/2026-09-10-huellas-irregulares-design.md); para
## un rectángulo esto es un superconjunto estrictamente más permisivo que
## antes (4 columnas -> todas), nunca rechaza un caso que antes aceptaba.
func _huella_tiene_columna_en_tierra(esquina: Vector2i, columnas: Array[Vector2i]) -> bool:
	for rel in columnas:
		var x: int = esquina.x + rel.x
		var z: int = esquina.y + rel.y
		if mundo.obtener_tipo(Vector3i(x, mundo.altura_en(x, z), z)) != "agua":
			return true
	return false


## true si el eje largo de la huella de pesca (siempre 4 x 6) corre por Z
## (sin rotar: alto=6 > ancho=4) — false si fue rotada con Ctrl+rueda
## (ancho=6 > alto=4, eje largo por X). Nunca son iguales para este puesto,
## así que no hay caso ambiguo.
static func _eje_largo_pesca_es_z(ancho: int, alto: int) -> bool:
	return alto > ancho


## Las celdas (offsets dx,dz relativos a "esquina") del extremo "indice"
## (0 o 1) a lo largo del eje largo de la huella — siempre 4 celdas, sobre
## el eje corto. Antes esto asumía que el eje largo era siempre Z (dz);
## generalizado para que la rotación (Ctrl+rueda, que solo intercambia
## ancho/alto) también rote qué eje del mundo se revisa como extremo — sin
## esto, rotar la huella 90° seguía revisando filas de 6 celdas en Z en vez
## de columnas de 4 celdas en X, y la colocación este-oeste era imposible
## (bug encontrado jugando en vivo).
static func _celdas_extremo_pesca(ancho: int, alto: int, indice: int) -> Array[Vector2i]:
	var celdas: Array[Vector2i] = []
	if _eje_largo_pesca_es_z(ancho, alto):
		var dz: int = 0 if indice == 0 else alto - 1
		for dx in range(ancho):
			celdas.append(Vector2i(dx, dz))
	else:
		var dx: int = 0 if indice == 0 else ancho - 1
		for dz in range(alto):
			celdas.append(Vector2i(dx, dz))
	return celdas


## true si las celdas del extremo "indice" (ver _celdas_extremo_pesca()) son
## TODAS agua, false si son TODAS tierra firme, "" (cadena vacía) si están
## mezcladas — usa el bloque REAL actual (mundo.obtener_tipo()), mismo
## criterio que _huella_tiene_columna_en_tierra().
func _extremo_uniforme_en(esquina: Vector2i, ancho: int, alto: int, indice: int) -> String:
	var celdas := _celdas_extremo_pesca(ancho, alto, indice)
	var vistos_agua := 0
	for rel in celdas:
		var x: int = esquina.x + rel.x
		var z: int = esquina.y + rel.y
		if mundo.obtener_tipo(Vector3i(x, mundo.altura_en(x, z), z)) == "agua":
			vistos_agua += 1
	if vistos_agua == celdas.size():
		return "agua"
	if vistos_agua == 0:
		return "tierra"
	return ""


## true si las celdas que rodean por fuera el extremo "indice" son todas
## agua: las 2 celdas de flanco (a los lados del extremo, sobre el eje
## corto) más toda la fila/columna inmediatamente más allá del extremo a lo
## largo del eje largo, extendida un bloque más allá de cada flanco — mismo
## conteo (ancho_extremo + 4 = 8 para ancho_extremo = 4) sin importar la
## orientación. Exige que el extremo no sea un charco angosto que termine
## justo en el borde de la huella.
func _periferia_extremo_es_agua(esquina: Vector2i, ancho: int, alto: int, indice: int) -> bool:
	var eje_z := _eje_largo_pesca_es_z(ancho, alto)
	var celdas_extremo := _celdas_extremo_pesca(ancho, alto, indice)
	var df: int = -1 if indice == 0 else 1
	if eje_z:
		var fila_agua: int = celdas_extremo[0].y
		var fila_frente: int = fila_agua + df
		for dx in range(-1, ancho + 1):
			var x: int = esquina.x + dx
			var z: int = esquina.y + fila_frente
			if mundo.obtener_tipo(Vector3i(x, mundo.altura_en(x, z), z)) != "agua":
				return false
		for dx in [-1, ancho]:
			var x: int = esquina.x + dx
			var z: int = esquina.y + fila_agua
			if mundo.obtener_tipo(Vector3i(x, mundo.altura_en(x, z), z)) != "agua":
				return false
	else:
		var col_agua: int = celdas_extremo[0].x
		var col_frente: int = col_agua + df
		for dz in range(-1, alto + 1):
			var x: int = esquina.x + col_frente
			var z: int = esquina.y + dz
			if mundo.obtener_tipo(Vector3i(x, mundo.altura_en(x, z), z)) != "agua":
				return false
		for dz in [-1, alto]:
			var x: int = esquina.x + col_agua
			var z: int = esquina.y + dz
			if mundo.obtener_tipo(Vector3i(x, mundo.altura_en(x, z), z)) != "agua":
				return false
	return true


## Regla de colocación exclusiva de "pesca_frutos_mar": exactamente uno de
## los dos extremos (ver _celdas_extremo_pesca(), ya generalizado a ambas
## orientaciones) debe ser completamente agua (celdas Y periferia) y el
## opuesto completamente tierra firme. Devuelve el ÍNDICE del extremo de
## agua (0 o 1 — ya NO es una coordenada dz, ver _celdas_extremo_pesca()
## para las celdas reales de ese extremo) si la huella es válida, o -1 si
## no lo es.
func _extremo_agua_de_huella_pesca(esquina: Vector2i, ancho: int, alto: int) -> int:
	var extremo_0 := _extremo_uniforme_en(esquina, ancho, alto, 0)
	var extremo_1 := _extremo_uniforme_en(esquina, ancho, alto, 1)
	if extremo_0 == "agua" and extremo_1 == "tierra" and _periferia_extremo_es_agua(esquina, ancho, alto, 0):
		return 0
	if extremo_1 == "agua" and extremo_0 == "tierra" and _periferia_extremo_es_agua(esquina, ancho, alto, 1):
		return 1
	return -1


## true si TODAS las columnas reales de la huella (esquina + columnas)
## caen dentro de una zona pintada que coincida con "zona_permitida".
## Antes solo se revisaba la celda central bajo el mouse — generalización
## necesaria para una huella irregular (un edificio en L no debe poder
## "asomar" su hueco a una zona distinta), y de paso cierra el pendiente ya
## documentado de que la validación de zona era puntual, solo para
## blueprints; la zona de influencia de los puestos (chequeo distinto,
## Zonificacion.dentro_de_influencia) no se toca.
func _huella_en_zona_correcta(esquina: Vector2i, columnas: Array[Vector2i], zona_permitida: String) -> bool:
	for rel in columnas:
		var xz := Vector2i(esquina.x + rel.x, esquina.y + rel.y)
		if Zonificacion.consultar_zona(xz) != zona_permitida:
			return false
	return true


## true si alguna columna real de la huella (esquina + columnas) cae dentro
## de un puesto ya colocado (Recoleccion.puestos, cualquier tipo — mina,
## caza/recolección, o "blueprint"), de una cola de relleno activa (una
## celda de nivelación todavía en curso de ser surtida, ver Construccion.gd)
## o de un edificio ya registrado (mundo.id_de_edificio()).
## "columnas" son offsets relativos a "esquina" (ver
## docs/superpowers/specs/2026-09-10-huellas-irregulares-design.md) — un
## rectángulo es solo el caso particular de pasar
## _columnas_rectangulo(ancho, alto); una huella irregular (un edificio en
## L) pasa sus columnas reales, así que el hueco de la L nunca exige estar
## libre.
## "ignorar_vias" salta el rechazo por Vias.hay_via_en_columna() — usado
## SOLO por _confirmar_trazo_via() (ver spec de vías Sección 4/6): un
## trazo que cierra sobre una vía YA CONSTRUIDA (intersección/red) debe
## poder unirse a ella, aunque puesto/blueprint sigan rechazando colocarse
## sobre una vía (llamadores por defecto, sin pasar este parámetro).
func _huella_choca_con_otro_puesto(esquina: Vector2i, columnas: Array[Vector2i], ignorar_vias := false) -> bool:
	for rel in columnas:
		var xz := Vector2i(esquina.x + rel.x, esquina.y + rel.y)
		if Recoleccion.celda_dentro_de_algun_puesto(xz):
			return true
		if not ignorar_vias and Vias.hay_via_en_columna(xz):
			return true
		var celda_superficie := Vector3i(xz.x, mundo.altura_en(xz.x, xz.y) + 1, xz.y)
		if mundo.id_de_edificio(celda_superficie) != -1 or Construccion.construccion_de(celda_superficie) != -1:
			return true
	return false


## Recalcula la posición/color de la huella activa según la celda bajo el
## cursor (esa celda es su CENTRO) y la ficha del HUD correspondiente al
## tipo activo. Reemplaza _actualizar_previsualizacion_mina() — ahora
## genérica sobre _tipo_puesto_activo/_ancho_puesto_activo/_alto_puesto_activo.
func _actualizar_previsualizacion_puesto() -> void:
	var centro := _celda_bajo_mouse(get_viewport().get_mouse_position())
	@warning_ignore("integer_division")
	var esquina := centro - Vector2i(_ancho_puesto_activo / 2, _alto_puesto_activo / 2)
	var columnas := _columnas_rectangulo(_ancho_puesto_activo, _alto_puesto_activo)

	var fuera_de_influencia: bool = not Zonificacion.dentro_de_influencia(centro)
	var relieve_valido: bool = nivelador_puesto.verificar_pendiente(esquina, columnas)
	var resultado_huella: Dictionary = mundo.verificar_huella_libre(esquina, columnas)
	var huella_anclada: bool
	var extremo_agua_indice := -1
	if _tipo_puesto_activo == "pesca_frutos_mar":
		extremo_agua_indice = _extremo_agua_de_huella_pesca(esquina, _ancho_puesto_activo, _alto_puesto_activo)
		huella_anclada = extremo_agua_indice != -1
	else:
		huella_anclada = _huella_tiene_columna_en_tierra(esquina, columnas)
	var valida: bool = fuera_de_influencia and relieve_valido and resultado_huella["valida"] \
			and not _huella_choca_con_otro_puesto(esquina, columnas) \
			and huella_anclada
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
		var conteo: Dictionary = Recoleccion.detectar_recursos_extraibles(mundo, centro, altura_superficie)
		var tasas: Dictionary = Recoleccion.tasas_recoleccion(conteo)
		hud.actualizar_tasas_mina(tasas)
		_actualizar_area_accion(centro, Recoleccion.RADIO_AREA_MINA)
	elif _tipo_puesto_activo == "caza_recoleccion":
		var promedios: Dictionary = Recoleccion.detectar_fauna_frutal(mundo.generador, centro)
		var tasas_caza: Dictionary = Recoleccion.tasas_caza_recoleccion(promedios)
		hud.actualizar_tasas_caza(tasas_caza)
		_actualizar_area_accion(centro, Recoleccion.RADIO_AREA_CAZA_RECOLECCION)
	elif _tipo_puesto_activo == "pesca_frutos_mar":
		if extremo_agua_indice != -1:
			var celdas_extremo := _celdas_extremo_pesca(_ancho_puesto_activo, _alto_puesto_activo, extremo_agua_indice)
			@warning_ignore("integer_division")
			var centro_agua := esquina + celdas_extremo[celdas_extremo.size() / 2]
			var celdas_agua: Dictionary = Recoleccion.celdas_agua_conectadas(mundo, centro_agua, Recoleccion.RADIO_AREA_PESCA_FRUTOS_MAR)
			var promedios: Dictionary = Recoleccion.detectar_pesca_frutos_mar(mundo.generador, celdas_agua)
			var tasas_pesca: Dictionary = Recoleccion.tasas_pesca_frutos_mar(promedios)
			hud.actualizar_tasas_pesca(tasas_pesca)
			_actualizar_area_accion_agua(centro_agua, celdas_agua)
		else:
			hud.actualizar_tasas_pesca({})
			_ocultar_area_accion()
	else:
		var promedio_arbol: float = Recoleccion.detectar_arbol(mundo.generador, centro)
		var tasas_madero: Dictionary = Recoleccion.tasa_maderero(promedio_arbol)
		hud.actualizar_tasas_madero(tasas_madero)
		_actualizar_area_accion(centro, Recoleccion.RADIO_AREA_MADERERO)


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


## El suelo frente a una puerta debe ser tierra firme dentro del mundo: ni
## agua ni fuera de los límites. nivelador_puesto ignora el agua
## (_AlturaSinAgua), por eso esto se revisa aquí con el mundo real.
func _frente_es_suelo_firme(frente: Vector2i) -> bool:
	if frente.x < 0 or frente.y < 0 or frente.x >= mundo.ANCHO_MUNDO or frente.y >= mundo.LARGO_MUNDO:
		return false
	return mundo.obtener_tipo(Vector3i(frente.x, mundo.altura_en(frente.x, frente.y), frente.y)) != "agua"


## Nivel base del blueprint activo en "esquina" (ver
## NiveladorTerreno.calcular_base_y()) más la validación de sus frentes.
## Fuente ÚNICA de base_y para el clic y la previsualización. Devuelve el
## mismo diccionario que calcular_base_y(); "motivo" ∈ {"", "pendiente",
## "puertas", "frente"} (clave de MENSAJES_BASE_Y).
func _base_y_blueprint(esquina: Vector2i) -> Dictionary:
	var resultado: Dictionary = nivelador_puesto.calcular_base_y(esquina, _blueprint_activo["celdas_3d"])
	if not resultado["valido"]:
		return resultado
	for frente: Vector2i in resultado["frentes"]:
		if not _frente_es_suelo_firme(frente):
			resultado["valido"] = false
			resultado["motivo"] = "frente"
			return resultado
	return resultado


## Celdas de terreno REAL a retirar bajo la huella (de calcular_excavacion(),
## sin las que ya están vacías, p. ej. cuevas).
func _celdas_excavacion(esquina: Vector2i, columnas: Array[Vector2i], base_y: int) -> Array[Vector3i]:
	var celdas: Array[Vector3i] = []
	for celda in nivelador_puesto.calcular_excavacion(esquina, columnas, base_y):
		if mundo.get_cell_item(celda) != GridMap.INVALID_CELL_ITEM:
			celdas.append(celda)
	return celdas


## Cuánto de cada material se recogería al excavar "celdas" (material_real
## de lo que hay ahora en cada una).
func _material_excavado(celdas: Array[Vector3i]) -> Dictionary:
	var recogido: Dictionary = {}
	for celda in celdas:
		var material: String = mundo.material_real(mundo.obtener_tipo(celda))
		recogido[material] = recogido.get(material, 0) + 1
	return recogido


## "columnas_mundo" (Vector2i mundiales) como offsets relativos a "esquina" —
## el mismo formato que "columnas" de la huella.
func _columnas_relativas(esquina: Vector2i, columnas_mundo: Array) -> Array[Vector2i]:
	var relativas: Array[Vector2i] = []
	for columna: Vector2i in columnas_mundo:
		relativas.append(columna - esquina)
	return relativas


## Celdas mundiales del blueprint activo colocado en "esquina" con su celda
## rel.y=0 en "base_y" (Vector3i real -> tipo).
func _celdas_mundo_blueprint(esquina: Vector2i, base_y: int) -> Dictionary:
	var celdas_mundo: Dictionary = {}
	for rel in _blueprint_activo["celdas_3d"]:
		var real := Vector3i(esquina.x + rel.x, base_y + rel.y, esquina.y + rel.z)
		celdas_mundo[real] = _blueprint_activo["celdas_3d"][rel]
	return celdas_mundo


## Todo lo que hay que cavar y rellenar para emplazar el blueprint: la huella
## (hasta `base_y - 1`) más la fachada (cada columna a su nivel). Fuente ÚNICA
## del clic, el resumen de materiales y los overlays. "excavacion" son celdas
## de terreno REAL (sin las ya vacías), huella primero; "relleno" es columna
## mundial -> cantidad de bloques.
## "Levanta" cualquier vía dentro de las columnas de "fachada" (Vector2i
## absoluto -> nivel objetivo, ver NiveladorTerreno.calcular_nivelacion_
## fachada()) y la vuelve a registrar de inmediato a ese nivel — decisión
## del usuario jugando en vivo, 2026-09-23: "eliminarla, nivelar el
## terreno y volverla a colocar". Si el soporte era una cuña
## (cuna_recta/cuna_esquina/cuna_diag_*/diag_lat), la reemplaza por
## "tierra" plana primero, para que la cola de excavación/relleno normal
## (que solo entiende bloques de terreno genéricos) la trate como
## cualquier otra columna. El relleno/excavación real bajo la vía sigue
## el proceso gradual de siempre (fantasma -> surtir); solo el registro y
## el overlay de Vias.gd se actualizan al instante, así que pueden verse
## un momento por delante del terreno real mientras se completa la cola.
func _despejar_vias_de_fachada(fachada: Dictionary) -> void:
	for columna: Vector2i in fachada:
		var altura_actual: int = mundo.altura_en(columna.x, columna.y)
		var celda_actual := Vector3i(columna.x, altura_actual, columna.y)
		if not Vias.es_via(celda_actual):
			continue
		var tipo_via: String = Vias.tipo_en(celda_actual)
		Vias.quitar([celda_actual])
		var tipo_bloque: String = mundo.obtener_tipo(celda_actual)
		if tipo_bloque.begins_with("cuna_") or tipo_bloque == "diag_lat":
			mundo.set_cell_item(celda_actual, mundo.id_de_tipo("tierra"), 0)
		var nivel_objetivo: int = fachada[columna]
		Vias.agregar([Vector3i(columna.x, nivel_objetivo, columna.y)], tipo_via)


func _plan_nivelacion(esquina: Vector2i, columnas: Array[Vector2i], base_y: int, fachada: Dictionary) -> Dictionary:
	var excavacion: Array[Vector3i] = _celdas_excavacion(esquina, columnas, base_y)
	var relleno: Dictionary = nivelador_puesto.calcular_relleno_hasta(esquina, columnas, base_y - 1)
	var nivelacion_fachada: Dictionary = nivelador_puesto.calcular_nivelacion_fachada(fachada)
	for celda: Vector3i in nivelacion_fachada["excavacion"]:
		if mundo.get_cell_item(celda) != GridMap.INVALID_CELL_ITEM:
			excavacion.append(celda)
	relleno.merge(nivelacion_fachada["relleno"])
	return {"excavacion": excavacion, "relleno": relleno}


## Evalúa TODAS las condiciones para emplazar el blueprint activo en
## "esquina" sin tocar el mundo: fuente única de la previsualización y del
## clic (ver _mensaje_rechazo_blueprint()). "columnas_union" es la huella más
## la fachada (lo que se nivela), como offsets relativos a "esquina".
func _evaluar_blueprint(esquina: Vector2i) -> Dictionary:
	var columnas: Array[Vector2i] = _blueprint_activo["huella_relativa"]
	var resultado_base: Dictionary = _base_y_blueprint(esquina)
	var fachada: Dictionary = resultado_base["fachada"]
	var columnas_fachada: Array[Vector2i] = _columnas_relativas(esquina, fachada.keys())
	var columnas_union: Array[Vector2i] = []
	columnas_union.append_array(columnas)
	columnas_union.append_array(columnas_fachada)
	var celdas_mundo: Dictionary = _celdas_mundo_blueprint(esquina, resultado_base["base_y"])
	return {
		"columnas": columnas,
		"resultado_base": resultado_base,
		"fachada": fachada,
		"columnas_fachada": columnas_fachada,
		"columnas_union": columnas_union,
		"celdas_mundo": celdas_mundo,
		"zona_correcta": _huella_en_zona_correcta(esquina, columnas, _blueprint_activo["zona_permitida"]),
		"errores_vivienda": BlueprintValidator.validar_limites_vivienda(_blueprint_activo, Ciudad.NIVELES_VIVIENDA[Ciudad.nivel]),
		"relieve_valido": nivelador_puesto.verificar_pendiente(esquina, columnas_union),
		"resultado_huella": mundo.verificar_huella_libre(esquina, columnas, _altura_blueprint(_blueprint_activo)),
		"resultado_fachada": mundo.verificar_huella_libre(esquina, columnas_fachada, ALTURA_PUERTA),
		# La huella ESTRUCTURAL sí rechaza sobre una vía (no se puede construir
		# encima de una ruta); el despeje de puertas/ventanas la ignora —
		# el frente de una puerta sobre una vía es justo lo esperado, no un
		# choque (reportado jugando en vivo, 2026-09-23).
		"choca": _huella_choca_con_otro_puesto(esquina, columnas) or _huella_choca_con_otro_puesto(esquina, columnas_fachada, true),
		"en_tierra": _huella_tiene_columna_en_tierra(esquina, columnas),
		"despejes_ok": mundo.verificar_despejes(celdas_mundo, fachada),
	}


## Motivo de rechazo de una evaluación (_evaluar_blueprint()), en el mismo
## orden en que se validaba al hacer clic; "" si es válida. La previsualización
## considera válida exactamente lo que el clic aceptaría.
func _mensaje_rechazo_blueprint(ev: Dictionary) -> String:
	if not ev["zona_correcta"]:
		return "Colocación rechazada: esta zona no acepta este blueprint."
	if not ev["errores_vivienda"].is_empty():
		return "Colocación rechazada: " + ev["errores_vivienda"][0]
	if not ev["relieve_valido"]:
		return "Colocación rechazada: la pendiente de esta huella (o del frente de sus puertas) supera el límite permitido."
	if not ev["resultado_huella"]["valida"]:
		return "Colocación rechazada: la huella choca con un recurso de madera o una estructura existente."
	if not ev["resultado_fachada"]["valida"]:
		return "Colocación rechazada: el frente de una puerta choca con un recurso de madera o una estructura existente."
	if ev["choca"]:
		return "Colocación rechazada: la huella (o el frente de una puerta) choca con un puesto o construcción ya colocada."
	if not ev["en_tierra"]:
		return "Colocación rechazada: la huella necesita al menos una columna sobre tierra firme."
	if not ev["resultado_base"]["valido"]:
		return MENSAJES_BASE_Y[ev["resultado_base"]["motivo"]]
	if not ev["despejes_ok"]:
		return "Colocación rechazada: una ventana o puerta quedaría sin el despeje mínimo, o invade el despeje de otro edificio."
	return ""


## Actualiza la ficha de materiales del HUD para el blueprint activo en
## "esquina" (evaluación "ev" de _evaluar_blueprint()). Se recalcula solo si
## cambió la esquina (o se invalidó, ver SIN_RESUMEN). Si la colocación no es
## válida muestra "-". Cuenta la nivelación de la huella Y de la fachada.
func _actualizar_resumen_materiales(esquina: Vector2i, ev: Dictionary, valida: bool) -> void:
	var clave: Vector2i = esquina if valida else SIN_RESUMEN
	if clave == _resumen_blueprint_vigente:
		return
	_resumen_blueprint_vigente = clave
	if not valida:
		hud.actualizar_materiales({})
		return
	var plan: Dictionary = _plan_nivelacion(esquina, ev["columnas"], ev["resultado_base"]["base_y"], ev["fachada"])
	var total_relleno := 0
	for cantidad in plan["relleno"].values():
		total_relleno += cantidad
	var recogido: Dictionary = _material_excavado(plan["excavacion"])
	hud.actualizar_materiales(nivelador_puesto.resumen_materiales(_blueprint_activo["celdas_3d"], total_relleno, recogido))


## Dibuja los overlays del blueprint activo en "esquina" (evaluación "ev" de
## _evaluar_blueprint()): las celdas reservadas delante de puertas y ventanas
## (rojas si están bloqueadas, ver VoxelWorld.despeje_bloqueado()) y la región
## nivelada (huella + fachada, por acción). Se recalcula solo si cambió la
## esquina (o se invalidó al rotar/entrar al modo), y también cuando la
## colocación es inválida, para ver qué la bloquea.
func _actualizar_overlays(esquina: Vector2i, ev: Dictionary) -> void:
	if esquina == _overlay_vigente:
		return
	_overlay_vigente = esquina
	var fachada: Dictionary = ev["fachada"]
	var plan: Dictionary = _plan_nivelacion(esquina, ev["columnas"], ev["resultado_base"]["base_y"], fachada)
	var cava: Dictionary = {}  # columna mundial -> true
	for celda: Vector3i in plan["excavacion"]:
		cava[Vector2i(celda.x, celda.z)] = true
	var region: Array = []
	for rel: Vector2i in ev["columnas_union"]:
		var columna: Vector2i = esquina + rel
		var accion := "nivel"
		if cava.has(columna):
			accion = "cavar"
		elif plan["relleno"].has(columna):
			accion = "rellenar"
		region.append({"columna": columna, "y": mundo.altura_en(columna.x, columna.y, true), "accion": accion})
	var reservadas: Array = []
	for celda: Vector3i in mundo.calcular_despeje(ev["celdas_mundo"]):
		reservadas.append({"celda": celda, "bloqueada": mundo.despeje_bloqueado(celda, fachada)})
	_overlay_nivelacion.mostrar(reservadas, region)


## Recalcula la posición/color de la previsualización 3D del blueprint
## activo según la celda bajo el cursor (esa celda es su CENTRO, igual que
## los puestos). A diferencia de los puestos (regla: fuera de la zona de
## influencia), aquí la regla de zona es la opuesta: la celda debe caer
## DENTRO de una zona pintada que coincida con blueprint["zona_permitida"].
## Cada caja se posiciona en la misma coordenada exacta donde quedaría el
## bloque real si se confirmara ahora mismo (mismo cálculo que
## _procesar_clic_blueprint(): esquina + rel, en `base_y` — el nivel al que
## la puerta queda a ras del suelo frontal, ver `_base_y_blueprint()`), así la previsualización
## no miente sobre dónde va a caer la construcción. La validez es exactamente
## la del clic (`_mensaje_rechazo_blueprint()`), incluidos los despejes y el
## frente nivelado.
func _actualizar_previsualizacion_blueprint() -> void:
	var centro := _celda_bajo_mouse(get_viewport().get_mouse_position())
	var ancho: int = _blueprint_activo["ancho"]
	var alto: int = _blueprint_activo["profundidad"]
	@warning_ignore("integer_division")
	var esquina := centro - Vector2i(ancho / 2, alto / 2)
	var ev: Dictionary = _evaluar_blueprint(esquina)
	var valida: bool = _mensaje_rechazo_blueprint(ev) == ""
	var color: Color = COLOR_PUESTO_VALIDO if valida else COLOR_PUESTO_INVALIDO

	var base_y: int = ev["resultado_base"]["base_y"]
	for i in range(_offsets_huella_blueprint.size()):
		var rel: Vector3i = _offsets_huella_blueprint[i]
		var x: int = esquina.x + rel.x
		var y: int = base_y + rel.y
		var z: int = esquina.y + rel.z
		var caja: MeshInstance3D = _huella_blueprint[i]
		var material: StandardMaterial3D = caja.material_override
		# Puertas y ventanas se destacan solo si la colocación es válida; si
		# no, siguen en rojo para no perder el aviso de rechazo.
		var tipo_celda: String = _blueprint_activo["celdas_3d"][rel]
		material.albedo_color = mundo.COLOR_DESTACADO.get(tipo_celda, color) if valida else color
		caja.position = Vector3(x + DESF, y + DESF, z + DESF)
	_actualizar_resumen_materiales(esquina, ev, valida)
	_actualizar_overlays(esquina, ev)


func _unhandled_input(event: InputEvent) -> void:
	if not current:
		return

	if event is InputEventKey:
		var tecla := event as InputEventKey
		if tecla.pressed and tecla.keycode == KEY_ESCAPE:
			salir_de_todos_los_modos()
		elif tecla.pressed and tecla.keycode == KEY_Z:
			_alternar_modo_zonificar()
		elif tecla.pressed and modo_zonificar and tecla.keycode == KEY_1:
			_elegir_zona(Zonificacion.ZONAS_PINTABLES[0])
		elif tecla.pressed and modo_zonificar and tecla.keycode == KEY_2:
			_elegir_zona(Zonificacion.ZONAS_PINTABLES[1])
		elif tecla.pressed and modo_zonificar and tecla.keycode == KEY_0:
			_elegir_zona(Zonificacion.MARCADOR_BORRAR)
		elif tecla.pressed and tecla.keycode == KEY_M:
			_alternar_modo_colocar_puesto("mina", Recoleccion.ANCHO_HUELLA_MINA, Recoleccion.ALTO_HUELLA_MINA)
		elif tecla.pressed and tecla.keycode == KEY_H:
			_alternar_modo_colocar_puesto("caza_recoleccion", Recoleccion.ANCHO_HUELLA_CAZA_RECOLECCION, Recoleccion.ALTO_HUELLA_CAZA_RECOLECCION)
		elif tecla.pressed and tecla.keycode == KEY_L:
			_alternar_modo_colocar_puesto("maderero", Recoleccion.ANCHO_HUELLA_MADERERO, Recoleccion.ALTO_HUELLA_MADERERO)
		elif tecla.pressed and tecla.keycode == KEY_F:
			_alternar_modo_colocar_puesto("pesca_frutos_mar", Recoleccion.ANCHO_HUELLA_PESCA_FRUTOS_MAR, Recoleccion.ALTO_HUELLA_PESCA_FRUTOS_MAR)
		elif tecla.pressed and tecla.keycode == KEY_B:
			_alternar_modo_colocar_blueprint()
		elif tecla.pressed and tecla.keycode == KEY_V:
			_alternar_modo_trazar_via()

	if event is InputEventMouseButton:
		var boton := event as InputEventMouseButton
		if boton.pressed and boton.button_index == MOUSE_BUTTON_LEFT:
			if modo_colocar_blueprint:
				_procesar_clic_blueprint(boton.position)
			elif modo_colocar_puesto:
				_procesar_clic_puesto(boton.position)
			elif modo_zonificar:
				_procesar_clic(boton.position)
			elif modo_trazar_via:
				_procesar_clic_via(boton.position)
			else:
				_procesar_clic_interaccion(boton.position)
		elif boton.pressed and boton.button_index == MOUSE_BUTTON_RIGHT:
			if modo_trazar_via:
				_cancelar_tramo_via()
			_cancelar_pintado_zona()
		elif boton.pressed and boton.button_index == MOUSE_BUTTON_WHEEL_UP:
			if modo_colocar_puesto and Input.is_key_pressed(KEY_CTRL):
				_rotar_huella_puesto()
			elif modo_colocar_blueprint and Input.is_key_pressed(KEY_CTRL):
				_rotar_blueprint()
			else:
				_intentar_zoom(-VELOCIDAD_ZOOM)
		elif boton.pressed and boton.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if modo_colocar_puesto and Input.is_key_pressed(KEY_CTRL):
				_rotar_huella_puesto()
			elif modo_colocar_blueprint and Input.is_key_pressed(KEY_CTRL):
				_rotar_blueprint()
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
## directamente al nuevo sin necesidad de cancelar primero. M, H y L llaman a
## esta misma función con su tipo/huella respectivos (ver _unhandled_input()).
func _alternar_modo_colocar_puesto(tipo: String, ancho: int, alto: int) -> void:
	if modo_colocar_puesto and _tipo_puesto_activo == tipo:
		_salir_de_modo_colocar_puesto()
		print("Modo colocar %s cancelado." % tipo)
		return
	# Ver el comentario equivalente en _alternar_modo_colocar_blueprint(): los
	# modos son mutuamente excluyentes.
	_salir_de_modo_zonificar()
	if modo_colocar_blueprint:
		_salir_de_modo_colocar_blueprint()
	if modo_trazar_via:
		_salir_de_modo_trazar_via()
	hud.ocultar_ficha_mina()
	hud.ocultar_ficha_caza()
	hud.ocultar_ficha_madero()
	hud.ocultar_ficha_pesca()
	assert(ancho <= MAX_ANCHO_HUELLA_PUESTO and alto <= MAX_ALTO_HUELLA_PUESTO, "Huella de puesto excede el pool fijo de planos fantasma")
	modo_colocar_puesto = true
	_tipo_puesto_activo = tipo
	_ancho_puesto_activo = ancho
	_alto_puesto_activo = alto
	_giros_puesto = 0
	_mostrar_huella_puesto(true)
	if tipo == "mina":
		hud.mostrar_ficha_mina()
	elif tipo == "caza_recoleccion":
		hud.mostrar_ficha_caza()
	elif tipo == "maderero":
		hud.mostrar_ficha_madero()
	else:
		hud.mostrar_ficha_pesca()
	print("Modo colocar %s activo: haz clic para confirmar (misma tecla de nuevo para cancelar)." % tipo)


func _salir_de_modo_colocar_puesto() -> void:
	modo_colocar_puesto = false
	_mostrar_huella_puesto(false)
	_ocultar_area_accion()
	hud.ocultar_ficha_mina()
	hud.ocultar_ficha_caza()
	hud.ocultar_ficha_madero()
	hud.ocultar_ficha_pesca()
	_tipo_puesto_activo = ""


## Ctrl + rueda del mouse, solo con un puesto en modo colocación: rota la
## huella activa 90° (intercambia ancho/alto) y avanza un cuarto de vuelta el
## giro de la plantilla (_giros_puesto, 0-3), que decide hacia dónde mira la puerta. Sin efecto visible en mina
## (5x5) ni caza/recolección (4x4) — ambas cuadradas — pero sí en el
## maderero (3x4, no cuadrada) y en pesca y frutos del mar (4x6, no
## cuadrada) — en este último caso, además de cambiar la forma visual de la
## huella, también rota qué eje del mundo (X o Z) se valida como extremo de
## agua/tierra (ver _eje_largo_pesca_es_z()/_celdas_extremo_pesca()), así
## que el puesto puede orientarse tanto norte-sur como este-oeste.
func _rotar_huella_puesto() -> void:
	var ancho_previo := _ancho_puesto_activo
	_ancho_puesto_activo = _alto_puesto_activo
	_alto_puesto_activo = ancho_previo
	_giros_puesto = (_giros_puesto + 1) % 4
	_mostrar_huella_puesto(true)


## Ctrl + rueda del mouse, con un blueprint en modo colocación: rota el
## blueprint activo 90° en sentido horario (mismo gesto que
## _rotar_huella_puesto(), pero un blueprint tiene estructura interna real
## — pared/puerta/ventana/mobiliario en posiciones relativas fijas, no un
## simple rectángulo uniforme — así que hace falta rotar cada celda de
## "celdas_3d"/"huella_relativa", no solo intercambiar ancho/profundidad.
## Fórmula de rotación 90° horaria para una caja de "profundidad_previa"
## celdas de profundidad (Z): (x, z) -> (profundidad_previa - 1 - z, x);
## la nueva caja mide "profundidad_previa" de ancho y "ancho_previo" de
## profundidad. _blueprint_activo es un duplicado propio (ver
## _alternar_modo_colocar_blueprint()), así que mutarlo aquí nunca toca el
## blueprint guardado en Blueprints. Reposiciona el pool de cajas fantasma
## ya existente (_offsets_huella_blueprint) en vez de recrearlo — la
## cantidad de celdas no cambia, solo sus offsets.
func _rotar_blueprint() -> void:
	var ancho_previo: int = _blueprint_activo["ancho"]
	var profundidad_previa: int = _blueprint_activo["profundidad"]

	var celdas_rotadas: Dictionary = {}
	for rel in _blueprint_activo["celdas_3d"]:
		var punto_rotado := Vector3i(profundidad_previa - 1 - rel.z, rel.y, rel.x)
		celdas_rotadas[punto_rotado] = _blueprint_activo["celdas_3d"][rel]
	_blueprint_activo["celdas_3d"] = celdas_rotadas

	var huella_rotada: Array[Vector2i] = []
	for rel in _blueprint_activo["huella_relativa"]:
		huella_rotada.append(Vector2i(profundidad_previa - 1 - rel.y, rel.x))
	_blueprint_activo["huella_relativa"] = huella_rotada

	_blueprint_activo["ancho"] = profundidad_previa
	_blueprint_activo["profundidad"] = ancho_previo

	for i in range(_offsets_huella_blueprint.size()):
		var rel: Vector3i = _offsets_huella_blueprint[i]
		_offsets_huella_blueprint[i] = Vector3i(profundidad_previa - 1 - rel.z, rel.y, rel.x)
	_resumen_blueprint_vigente = SIN_RESUMEN
	_overlay_vigente = SIN_RESUMEN
	_mostrar_huella_blueprint(true)


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
	_salir_de_modo_zonificar()
	if modo_colocar_puesto:
		_salir_de_modo_colocar_puesto()
	if modo_trazar_via:
		_salir_de_modo_trazar_via()
	# Duplicado (no la misma referencia): _rotar_blueprint() reemplaza
	# "celdas_3d"/"huella_relativa"/"ancho"/"profundidad" en _blueprint_activo
	# en cada rotación — sobre el dict original de Blueprints.obtener(), eso
	# rotaría PERMANENTEMENTE el blueprint guardado (mismo objeto Dictionary
	# por referencia), afectando toda colocación futura, no solo la actual.
	_blueprint_activo = blueprint.duplicate()
	_crear_huella_blueprint(_blueprint_activo["celdas_3d"])
	modo_colocar_blueprint = true
	_resumen_blueprint_vigente = SIN_RESUMEN
	_overlay_vigente = SIN_RESUMEN
	hud.mostrar_ficha_materiales()
	print("Modo colocar blueprint activo: haz clic dentro de una zona residencial para confirmar (B de nuevo para cancelar, Ctrl+rueda para rotar).")


func _salir_de_modo_colocar_blueprint() -> void:
	modo_colocar_blueprint = false
	_mostrar_huella_blueprint(false)
	_blueprint_activo = {}
	hud.ocultar_ficha_materiales()
	_overlay_nivelacion.ocultar()
	_overlay_vigente = SIN_RESUMEN


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
	_salir_de_modo_zonificar()
	_salir_de_modo_trazar_via()
	hud.cerrar_panel_puesto()


## Cancela la selección de esquinas de zona en curso (tras el primer
## click, antes del segundo) — usada por el click derecho (ver
## _unhandled_input()) y al salir del todo a primera persona (ver
## salir_de_todos_los_modos()), que antes dejaba esperando_segunda_esquina
## colgado si el jugador cambiaba de cámara a medio pintar. No-op si no
## había nada pendiente.
func _cancelar_pintado_zona() -> void:
	if not esperando_segunda_esquina:
		return
	esperando_segunda_esquina = false
	overlay.limpiar_previsualizacion()
	print("Pintado de zona cancelado.")


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


## Igual que _actualizar_area_accion(), pero en vez de un radio geométrico
## simple, muestra un plano solo si su celda absoluta está en "celdas_agua"
## (ver Recoleccion.celdas_agua_conectadas()) — exclusivo de
## "pesca_frutos_mar". Reutiliza el mismo pool _area_accion/_offsets_area_accion.
func _actualizar_area_accion_agua(centro: Vector2i, celdas_agua: Dictionary) -> void:
	for i in range(_offsets_area_accion.size()):
		var offset: Vector2i = _offsets_area_accion[i]
		var plano: MeshInstance3D = _area_accion[i]
		var x: int = centro.x + offset.x
		var z: int = centro.y + offset.y
		if not celdas_agua.has(Vector2i(x, z)):
			plano.visible = false
			continue
		var altura_celda: int = mundo.altura_en(x, z, true)
		plano.position = Vector3(x + DESF, altura_celda + ALTURA_SOBRE_SUPERFICIE_AREA_ACCION, z + DESF)
		plano.visible = true


func _ocultar_area_accion() -> void:
	for plano in _area_accion:
		plano.visible = false


## Convierte una posición de pantalla en la celda de grid (X,Z) que hay
## debajo, mediante un raycast físico real contra la colisión del terreno
## (la misma que usa Player.gd para minar/colocar) — no basta con
## intersecar un plano fijo en y = 0: con relieve real (0-130 de altura) y
## una cámara en ángulo oblicuo, un rayo que visualmente toca el terreno a
## media altura sigue viajando mucho más lejos horizontalmente antes de
## llegar a y = 0, desplazando la celda detectada muy lejos del cursor. Si
## el rayo no golpea nada (apunta al cielo, fuera del mundo generado), cae
## de vuelta a la intersección con el plano y = 0 como aproximación.
func _celda_bajo_mouse(posicion_pantalla: Vector2) -> Vector2i:
	var origen := project_ray_origin(posicion_pantalla)
	var direccion := project_ray_normal(posicion_pantalla)

	var consulta := PhysicsRayQueryParameters3D.create(origen, origen + direccion * ALCANCE_RAYCAST)
	consulta.collision_mask = MASCARA_MUNDO
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


## Igual que _celda_bajo_mouse() pero redondea al VÉRTICE (esquina entre
## 4 celdas) más cercano en vez de a la celda — ver spec de vías Sección
## 1/4. Sin el desplazamiento "hacia adentro de la cara" que usa
## _celda_bajo_mouse(): aquí interesa el punto de impacto real.
func _vertice_bajo_mouse(posicion_pantalla: Vector2) -> Vector2i:
	var origen := project_ray_origin(posicion_pantalla)
	var direccion := project_ray_normal(posicion_pantalla)
	var consulta := PhysicsRayQueryParameters3D.create(origen, origen + direccion * ALCANCE_RAYCAST)
	consulta.collision_mask = MASCARA_MUNDO
	var resultado: Dictionary = get_world_3d().direct_space_state.intersect_ray(consulta)
	var punto: Vector3
	if resultado.is_empty():
		var distancia: float = -origen.y / direccion.y
		punto = origen + direccion * distancia
	else:
		punto = resultado["position"]
	var local: Vector3 = mundo.to_local(punto)
	return Vector2i(roundi(local.x), roundi(local.z))


## Activa/desactiva el modo zonificación (tecla `Z`). Es excluyente con los
## demás modos de interacción de la cenital (colocar puesto, blueprint,
## trazar vías). Conserva la última zona elegida.
func _alternar_modo_zonificar() -> void:
	if modo_zonificar:
		_salir_de_modo_zonificar()
		return
	_salir_de_modo_colocar_blueprint()
	_salir_de_modo_colocar_puesto()
	_salir_de_modo_trazar_via()
	hud.cerrar_panel_puesto()
	modo_zonificar = true
	hud.mostrar_modo_zonificacion(_nombre_zona_seleccionada())


func _salir_de_modo_zonificar() -> void:
	modo_zonificar = false
	hud.ocultar_modo_zonificacion()
	_cancelar_pintado_zona()


## Activa/desactiva el modo trazador de vías (tecla `V`). Excluyente con
## los demás modos — ver spec de vías Sección 4.
func _alternar_modo_trazar_via() -> void:
	if modo_trazar_via:
		_salir_de_modo_trazar_via()
		return
	_salir_de_modo_colocar_blueprint()
	_salir_de_modo_colocar_puesto()
	_salir_de_modo_zonificar()
	hud.cerrar_panel_puesto()
	modo_trazar_via = true
	_trazador_via = TrazadorVias.new(mundo)
	_tramos_fijos.clear()
	_hay_tramo_en_curso = false
	_ultimo_origen_preview = SIN_VERTICE_PREVIO
	_ultimo_vertice_preview = SIN_VERTICE_PREVIO
	hud.mostrar_modo_trazar_via()


func _salir_de_modo_trazar_via() -> void:
	modo_trazar_via = false
	_hay_tramo_en_curso = false
	_tramos_fijos.clear()
	via_preview.limpiar()
	hud.ocultar_modo_trazar_via()


func _elegir_zona(tipo: String) -> void:
	tipo_zona_seleccionada = tipo
	# Cambiar de zona a medio rectángulo lo descarta, como cancelar con clic derecho.
	_cancelar_pintado_zona()
	hud.mostrar_modo_zonificacion(_nombre_zona_seleccionada())


func _nombre_zona_seleccionada() -> String:
	if tipo_zona_seleccionada == Zonificacion.MARCADOR_BORRAR:
		return "Borrar"
	return "Zona A" if tipo_zona_seleccionada == Zonificacion.ZONAS_PINTABLES[0] else "Zona B"


## Clic sin ningún modo activo: sobre un puesto de trabajo abre su panel; en
## cualquier otro sitio lo cierra.
func _procesar_clic_interaccion(posicion_pantalla: Vector2) -> void:
	var esquina_puesto := Recoleccion.esquina_de_puesto_en(_celda_bajo_mouse(posicion_pantalla))
	if esquina_puesto != Recoleccion.SIN_PUESTO:
		hud.abrir_panel_puesto(esquina_puesto)
	else:
		hud.cerrar_panel_puesto()


## Clic con el modo zonificación activo: primera esquina o cierre del rectángulo.
func _procesar_clic(posicion_pantalla: Vector2) -> void:
	var celda := _celda_bajo_mouse(posicion_pantalla)
	if not esperando_segunda_esquina:
		primera_esquina = celda
		esperando_segunda_esquina = true
		print("Primera esquina de la zona: ", primera_esquina)
		overlay.previsualizar(primera_esquina, primera_esquina, tipo_zona_seleccionada)
		return

	if tipo_zona_seleccionada == Zonificacion.MARCADOR_BORRAR:
		var borradas: int = Zonificacion.despintar_zona(primera_esquina, celda)
		print("Zona borrada en ", borradas, " celda(s).")
	else:
		var pintadas: int = Zonificacion.pintar_zona(primera_esquina, celda, tipo_zona_seleccionada)
		print("Zona '", tipo_zona_seleccionada, "' pintada en ", pintadas, " celda(s).")
		if pintadas == 0 and not Zonificacion.nucleo_declarado:
			print("Todavía no existe una zona de influencia — declara tu primer edificio residencial primero.")
	esperando_segunda_esquina = false
	overlay.reconstruir()


## Clic con el modo trazador activo — ver spec de vías Sección 4.
func _procesar_clic_via(posicion_pantalla: Vector2) -> void:
	var vertice := _vertice_bajo_mouse(posicion_pantalla)
	if not _hay_tramo_en_curso:
		_vertice_inicio_tramo = vertice
		_hay_tramo_en_curso = true
		return

	if vertice == _vertice_inicio_tramo:
		# Doble clic sobre el mismo punto sin haberse movido: si ya hay algún
		# tramo fijado (el jugador "presiona nuevamente sobre el bloque
		# final" que acaba de fijar, ver spec de vías Sección 4), esto
		# confirma TODO lo acumulado. Sin ningún tramo fijado todavía
		# (recién se puso el origen), no hay nada que confirmar: cancela.
		if _tramos_fijos.is_empty():
			_cancelar_tramo_via()
		else:
			_confirmar_trazo_via()
			_hay_tramo_en_curso = false
			_tramos_fijos.clear()
			via_preview.limpiar()
		return

	var ruta: Array[Vector2i] = _trazador_via.buscar_ruta(_vertice_inicio_tramo, vertice)
	if ruta.is_empty():
		print("Trazado rechazado: no hay ruta posible hasta ese punto.")
		return

	var tramo: Array[Vector2i] = [_vertice_inicio_tramo]
	tramo.append_array(ruta)
	# Se comprueba ANTES de agregar "tramo" a _tramos_fijos: el tramo recién
	# trazado siempre termina en "vertice" por construcción, así que
	# comprobar después haría que cualquier clic "cerrara" contra su propio
	# destino — ver spec de vías Sección 4 y el autochequeo de C1.
	var cierra_trazo := _vertice_pertenece_a_via(vertice)
	_tramos_fijos.append(tramo)

	if cierra_trazo:
		_confirmar_trazo_via()
		_hay_tramo_en_curso = false
		_tramos_fijos.clear()
		via_preview.limpiar()
		return

	_vertice_inicio_tramo = vertice


func _cancelar_tramo_via() -> void:
	if not _hay_tramo_en_curso:
		return
	_hay_tramo_en_curso = false
	via_preview.limpiar()
	print("Trazado de vía cancelado.")


## true si CUALQUIER columna del bloque de soporte de "vertice" ya tiene
## una vía registrada, O si "vertice" ya aparece en algún tramo de
## _tramos_fijos (la vista previa acumulada del trazo en curso) — usado
## para saber si el clic cierra el trazo, como intersección con una vía
## construida o como cierre sobre la propia ruta acumulada (ver spec de
## vías Sección 4). Llamar SIEMPRE antes de agregar el tramo recién
## trazado a _tramos_fijos (ver _procesar_clic_via()).
func _vertice_pertenece_a_via(vertice: Vector2i) -> bool:
	for col in _trazador_via.bloque_de_vertice(vertice):
		var y: int = mundo.altura_en(col.x, col.y)
		if Vias.es_via(Vector3i(col.x, y, col.y)):
			return true
	for tramo: Array[Vector2i] in _tramos_fijos:
		if tramo.has(vertice):
			return true
	return false


## Vista previa del bloque de soporte bajo el cursor ANTES del primer clic
## (todavía no hay origen fijado) — para que el jugador vea dónde caería el
## inicio del trazo. previsualizar_tramo() acepta el mismo vértice repetido:
## dibuja solo su propio bloque 2x2, sin ninguna ruta.
func _actualizar_preview_vertice_inicial() -> void:
	var vertice := _vertice_bajo_mouse(get_viewport().get_mouse_position())
	var vertices: Array[Vector2i] = [vertice, vertice]
	via_preview.previsualizar_tramo(vertices, _trazador_via.vertice_transitable(vertice))


## Vista previa en vivo del trazo actual: los tramos YA fijados
## (_tramos_fijos) permanecen visibles (spec de vías Sección 4: "la
## anterior quedando 'fija' como previsualización") seguidos del tramo en
## curso (origen fijado + ruta hasta el cursor) — ver _process(). Cachea
## el último origen/vértice consultados (ver I2 de la revisión final)
## para no repetir buscar_ruta() (hasta TrazadorVias.MAX_NODOS_EXPANDIDOS
## nodos, cada uno con varias consultas al mundo) en cada fotograma
## mientras el cursor sigue sobre el mismo vértice — solo reaplica el
## último resultado.
func _actualizar_preview_via() -> void:
	var vertice := _vertice_bajo_mouse(get_viewport().get_mouse_position())
	if vertice == _ultimo_vertice_preview and _vertice_inicio_tramo == _ultimo_origen_preview:
		# Ni el vértice bajo el mouse ni el origen del tramo cambiaron desde
		# el fotograma anterior: la malla de la vista previa ya está al día,
		# no hace falta reconstruirla (reportado jugando en vivo, ver
		# MAX_NODOS_PREVIEW_VIA — esto evita el costo de reconstrucción de
		# ViaPreviewOverlay.previsualizar_tramo() además del de la A*).
		return

	var ruta: Array[Vector2i] = _trazador_via.buscar_ruta(_vertice_inicio_tramo, vertice, MAX_NODOS_PREVIEW_VIA)
	_ultimo_origen_preview = _vertice_inicio_tramo
	_ultimo_vertice_preview = vertice

	var vertices: Array[Vector2i] = []
	for tramo_fijo: Array[Vector2i] in _tramos_fijos:
		for v in tramo_fijo:
			if vertices.is_empty() or vertices[-1] != v:
				vertices.append(v)
	if vertices.is_empty() or vertices[-1] != _vertice_inicio_tramo:
		vertices.append(_vertice_inicio_tramo)
	vertices.append_array(ruta)
	via_preview.previsualizar_tramo(vertices, not ruta.is_empty())


## Confirma TODOS los tramos acumulados (_tramos_fijos) de una sola vez —
## ver spec de vías Sección 5. Deduplica vértices consecutivos repetidos
## (el punto de cierre de un tramo es también el inicio del siguiente).
func _confirmar_trazo_via() -> void:
	var vertices: Array[Vector2i] = []
	for tramo in _tramos_fijos:
		for v in tramo:
			if vertices.is_empty() or vertices[-1] != v:
				vertices.append(v)

	var choca := func(columnas_abs: Array[Vector2i]) -> bool:
		if columnas_abs.is_empty():
			return false
		var esquina: Vector2i = columnas_abs[0]
		return _huella_choca_con_otro_puesto(esquina, _columnas_relativas(esquina, columnas_abs), true)

	if not ConstructorVias.construir(mundo, vertices, choca):
		print("Trazado rechazado: choca con un edificio, puesto u obra existente.")


## Confirma la colocación del puesto activo en la celda bajo el cursor si
## las 5 validaciones (zona de influencia, relieve, huella libre, sin choque
## con otro puesto, al menos una esquina en tierra firme — "pesca_frutos_mar"
## es la excepción: exactamente un extremo completo de agua y el opuesto
## completo de tierra, ver _extremo_agua_de_huella_pesca()) pasan — si no,
## imprime el motivo y PERMANECE en modo colocar-puesto (el jugador puede
## reintentar de inmediato, igual que la mina original; mismo comportamiento
## que _procesar_clic_blueprint() con el modo de colocación de blueprint). El
## follaje detectado se elimina; luego, para la mayoría de los tipos, se
## drena el agua bajo la huella (VoxelWorld.drenar_agua()) y se nivela al
## punto más alto del terreno REAL resultante contra "nivelador_puesto" —
## que ignora el agua, ver _AlturaSinAgua — antes de colocar el marcador,
## así la "construcción" siempre queda sobre terreno plano y seco, nunca
## sobre o bajo el agua. "pesca_frutos_mar" es de nuevo la excepción: en vez
## de drenar, coloca pilotes (bloque "pared") bajo las dos columnas del
## extremo de agua y rellena de tierra el resto, dejando el agua abierta
## intacta bajo la plataforma. La validación de pendiente
## (verificar_pendiente(), arriba) ya usa ese mismo terreno sin agua — es la
## que decide si la huella es demasiado empinada para nivelarse de forma
## razonable.
func _procesar_clic_puesto(posicion_pantalla: Vector2) -> void:
	var centro := _celda_bajo_mouse(posicion_pantalla)
	@warning_ignore("integer_division")
	var esquina := centro - Vector2i(_ancho_puesto_activo / 2, _alto_puesto_activo / 2)
	var columnas := _columnas_rectangulo(_ancho_puesto_activo, _alto_puesto_activo)

	if Zonificacion.dentro_de_influencia(centro):
		print("No se puede colocar un puesto dentro de la zona de influencia.")
		return
	if not nivelador_puesto.verificar_pendiente(esquina, columnas):
		print("Colocación rechazada: la pendiente de esta huella supera el límite permitido.")
		return
	var altura_plantilla: int = PlantillasPuesto.altura(_tipo_puesto_activo) + NiveladorTerreno.LIMITE_PENDIENTE
	var resultado_huella: Dictionary = mundo.verificar_huella_libre(esquina, columnas, altura_plantilla)
	if not resultado_huella["valida"]:
		print("Colocación rechazada: la huella choca con un recurso de madera o una estructura existente.")
		return
	if _huella_choca_con_otro_puesto(esquina, columnas):
		print("Colocación rechazada: la huella choca con un puesto ya colocado.")
		return
	var extremo_agua_indice := -1
	if _tipo_puesto_activo == "pesca_frutos_mar":
		extremo_agua_indice = _extremo_agua_de_huella_pesca(esquina, _ancho_puesto_activo, _alto_puesto_activo)
		if extremo_agua_indice == -1:
			print("Colocación rechazada: la huella necesita un extremo completo sobre agua (con su periferia despejada) y el opuesto completo sobre tierra firme.")
			return
	elif not _huella_tiene_columna_en_tierra(esquina, columnas):
		print("Colocación rechazada: la huella necesita al menos una columna sobre tierra firme.")
		return

	# Giro efectivo de la plantilla: en la pesca, el edificio debe caer en el extremo de tierra.
	var giros := _giros_puesto
	if _tipo_puesto_activo == "pesca_frutos_mar" and PlantillasPuesto.indice_extremo_agua(giros) != extremo_agua_indice:
		giros = (giros + 2) % 4
	var objetivo: int = nivelador_puesto.altura_objetivo(esquina, columnas)
	# La puerta debe dar a suelo firme: a lo sumo 1 bloque de desnivel, sin agua ni otro puesto.
	var servicio: Vector2i = esquina + PlantillasPuesto.celda_de_servicio(_tipo_puesto_activo, giros)
	var altura_servicio: int = mundo.altura_en(servicio.x, servicio.y)
	if absi(altura_servicio - objetivo) > 1 or mundo.obtener_tipo(Vector3i(servicio.x, altura_servicio, servicio.y)) == "agua" or Recoleccion.celda_dentro_de_algun_puesto(servicio):
		print("Colocación rechazada: la puerta del puesto no da a suelo firme y libre.")
		return

	var centro_agua := Recoleccion.SIN_CENTRO
	if _tipo_puesto_activo == "pesca_frutos_mar":
		var celdas_extremo_pesca := _celdas_extremo_pesca(_ancho_puesto_activo, _alto_puesto_activo, extremo_agua_indice)
		@warning_ignore("integer_division")
		centro_agua = esquina + celdas_extremo_pesca[celdas_extremo_pesca.size() / 2]
	var entorno_puesto: Dictionary = Recoleccion.entorno_de_puesto(_tipo_puesto_activo, mundo, centro, mundo.altura_en(centro.x, centro.y), centro_agua)
	var tasas_puesto: Dictionary = Recoleccion.tasas_de_entorno(_tipo_puesto_activo, mundo, entorno_puesto)

	for celda_follaje in resultado_huella["follaje_a_eliminar"]:
		mundo.eliminar_follaje(celda_follaje)

	var total_relleno := 0
	var total_pilotes := 0
	if _tipo_puesto_activo == "pesca_frutos_mar":
		var celdas_extremo := _celdas_extremo_pesca(_ancho_puesto_activo, _alto_puesto_activo, extremo_agua_indice)
		var esquinas_pilote: Array[Vector2i] = [
			esquina + celdas_extremo[0],
			esquina + celdas_extremo[celdas_extremo.size() - 1],
		]
		for dx in range(_ancho_puesto_activo):
			for dz in range(_alto_puesto_activo):
				var x: int = esquina.x + dx
				var z: int = esquina.y + dz
				var xz := Vector2i(x, z)
				var es_pilote: bool = esquinas_pilote.has(xz)
				var es_agua_real: bool = mundo.obtener_tipo(Vector3i(x, mundo.altura_en(x, z), z)) == "agua"
				if es_agua_real and not es_pilote:
					continue  # agua abierta bajo la plataforma: no se toca
				var fondo: int = mundo.altura_en(x, z, true)
				var bloque: String = "pared" if es_pilote else "tierra"
				for h in range(fondo + 1, objetivo + 1):
					mundo.colocar_bloque(Vector3i(x, h, z), bloque)
					if es_pilote:
						total_pilotes += 1
					else:
						total_relleno += 1
	else:
		var total_drenado := 0
		for dx in range(_ancho_puesto_activo):
			for dz in range(_alto_puesto_activo):
				total_drenado += mundo.drenar_agua(esquina.x + dx, esquina.y + dz)
		if total_drenado > 0:
			print("Agua drenada bajo el puesto: ", total_drenado, " bloques reemplazados por tierra.")
		var relleno: Dictionary = nivelador_puesto.calcular_relleno(esquina, columnas)
		for celda_relleno in relleno:
			var cantidad: int = relleno[celda_relleno]
			var altura_actual: int = mundo.altura_en(celda_relleno.x, celda_relleno.y)
			for h in range(1, cantidad + 1):
				mundo.colocar_bloque(Vector3i(celda_relleno.x, altura_actual + h, celda_relleno.y), "tierra")
			total_relleno += cantidad
	if total_pilotes > 0:
		print("Pilotes colocados bajo el puesto: ", total_pilotes, " bloques de \"pared\".")
	if total_relleno > 0:
		print("Terreno nivelado bajo el puesto: ", total_relleno, " bloques usados.")

	# La plantilla del puesto: bloques reales sobre el terreno nivelado, registrados
	# como edificio completo (se deconstruye bloque a bloque, como un residencial).
	var y_base := objetivo + 1
	var celdas_plantilla: Dictionary = PlantillasPuesto.en_mundo(_tipo_puesto_activo, giros, esquina, y_base)
	var celdas_puesto: Dictionary = {}
	for celda_plantilla in celdas_plantilla:
		if mundo.colocar_bloque(celda_plantilla, celdas_plantilla[celda_plantilla]):
			celdas_puesto[celda_plantilla] = celdas_plantilla[celda_plantilla]
	mundo.registrar_edificio_completo(celdas_puesto, {"puesto": esquina})
	mundo.reemparejar_construccion(celdas_puesto.keys())
	var deposito_local: Vector3i = PlantillasPuesto.celda_deposito(_tipo_puesto_activo, giros)
	var deposito := Vector3i(esquina.x + deposito_local.x, y_base + deposito_local.y, esquina.y + deposito_local.z)

	Recoleccion.colocar_puesto(esquina, _tipo_puesto_activo, _ancho_puesto_activo, _alto_puesto_activo)
	Economia.registrar_puesto(esquina, _tipo_puesto_activo, _ancho_puesto_activo, _alto_puesto_activo, tasas_puesto, entorno_puesto, servicio, deposito)
	print("Puesto '%s' colocado en (%d, %d)." % [_tipo_puesto_activo, esquina.x, esquina.y])

	_salir_de_modo_colocar_puesto()


## Confirma la colocación del blueprint activo en la celda bajo el cursor
## si _evaluar_blueprint() la acepta (zona, relieve sobre huella + fachada,
## huella y frente libres, sin choque, esquina en tierra firme, nivel base
## `base_y` válido para las puertas y despejes de ventanas/puertas) — si no,
## imprime el motivo (_mensaje_rechazo_blueprint()) y PERMANECE en modo
## colocar-blueprint. A diferencia de _procesar_clic_puesto() (que coloca el
## marcador de inmediato), esto NO completa nada: NO modifica el terreno (el
## agua y el follaje se retiran celda a celda al surtir), calcula el nivel
## base (`base_y`, puerta a ras del suelo frontal) y la nivelación
## (_plan_nivelacion(): huella + fachada, excavación y relleno), reubica
## blueprint["celdas_3d"] en el mundo e inicia UNA cola
## de preparación del terreno (excavación primero, luego relleno;
## Construccion.gd, vía VoxelWorld.iniciar_construccion_fantasma()) más el
## orden de la estructura del edificio (VoxelWorld.edificio_orden, ver
## VoxelWorld.ordenar_celdas_edificio()) — la finalización real ocurre
## después, celda por celda, cuando el jugador la surte (ver
## Player._completar_construccion()); la estructura solo avanza
## cuando la cola de preparación se agota.
func _procesar_clic_blueprint(posicion_pantalla: Vector2) -> void:
	var centro := _celda_bajo_mouse(posicion_pantalla)
	var ancho: int = _blueprint_activo["ancho"]
	var alto: int = _blueprint_activo["profundidad"]
	@warning_ignore("integer_division")
	var esquina := centro - Vector2i(ancho / 2, alto / 2)

	var ev: Dictionary = _evaluar_blueprint(esquina)
	var mensaje: String = _mensaje_rechazo_blueprint(ev)
	if mensaje != "":
		print(mensaje)
		return
	var columnas: Array[Vector2i] = ev["columnas"]
	var fachada: Dictionary = ev["fachada"]
	var base_y: int = ev["resultado_base"]["base_y"]
	var celdas_mundo: Dictionary = ev["celdas_mundo"]

	# Si alguna columna de la fachada ya tiene una vía, "levantarla" antes
	# de nivelar (ver _despejar_vias_de_fachada()) — el despeje de puertas
	# ya ignora vías al validar el choque (ver _evaluar_blueprint()), así
	# que una construcción puede quedar frente a una ruta existente; sin
	# esto, la vía se veía enterrada o flotando sobre el nuevo nivel.
	_despejar_vias_de_fachada(fachada)

	# Cola de "preparación del terreno" (ver VoxelWorld._aplicar_paso_cola()):
	# primero se CAVA (terreno real sobre la losa y sobre el nivel de la
	# fachada), luego se RELLENA (columnas por debajo). Una celda cavada que
	# además es de la estructura (la losa enterrada) queda "fantasma", no vacía.
	var plan: Dictionary = _plan_nivelacion(esquina, columnas, base_y, fachada)
	var excavacion: Array[Vector3i] = plan["excavacion"]
	var relleno: Dictionary = plan["relleno"]
	var relleno_orden: Array[Vector3i] = []
	var tipos_relleno: Dictionary = {}
	for celda_e in excavacion:
		relleno_orden.append(celda_e)
		tipos_relleno[celda_e] = "fantasma" if celdas_mundo.has(celda_e) else "aire"
	var total_relleno := 0
	for celda_relleno in relleno:
		var cantidad: int = relleno[celda_relleno]
		total_relleno += cantidad
		# Sin agua: al emplazar el agua sigue en el mundo y las celdas de agua
		# bajo el nivel de la losa son parte del relleno (ver VoxelWorld._reemplazar_celda()).
		var altura_actual: int = mundo.altura_en(celda_relleno.x, celda_relleno.y, true)
		for h in range(1, cantidad + 1):
			var celda_r := Vector3i(celda_relleno.x, altura_actual + h, celda_relleno.y)
			relleno_orden.append(celda_r)
			tipos_relleno[celda_r] = "tierra"

	var orden_estructura: Array = mundo.ordenar_celdas_edificio(celdas_mundo)

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
		"base_y": base_y,
		"fachada": fachada,
	}
	var id_edificio: int = mundo.iniciar_construccion_fantasma(relleno_orden, tipos_relleno, orden_estructura, celdas_mundo, metadata)
	# El follaje NO se borra al emplazar: se registra y desaparece por columna con
	# el primer paso que se aplique en ella (ver VoxelWorld.registrar_follaje_pendiente()).
	var follaje: Array = []
	follaje.append_array(ev["resultado_huella"]["follaje_a_eliminar"])
	follaje.append_array(ev["resultado_fachada"]["follaje_a_eliminar"])
	mundo.registrar_follaje_pendiente(id_edificio, follaje)
	metadata["id_edificio"] = id_edificio
	print("Construcción fantasma iniciada en (", esquina.x, ", ", esquina.y, ") — excavación: ", excavacion.size(), " bloques, relleno: ", total_relleno, " (huella + frente de las puertas) — surtir para completarla.")

	_salir_de_modo_colocar_blueprint()

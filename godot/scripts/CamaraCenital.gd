extends Camera3D

const NiveladorTerreno = preload("res://scripts/NiveladorTerreno.gd")

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
## - Colocación de minas (tecla `M`, ver GDD Sección 3 y
##   docs/superpowers/specs/2026-09-08-puestos-recoleccion-minas-design.md):
##   disco de previsualización del área de acción, ficha en vivo en el HUD,
##   confirma solo fuera de la zona de influencia.
## Modo de nivelación de terreno con tecla `B` (ver GDD Sección 5) — sin
## selección de tropas por arrastre todavía, eso sigue siendo PoC 6/Fase 4.

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

const COLOR_HUELLA_VALIDA := Color(0.2, 1.0, 0.3, 0.4)
const COLOR_HUELLA_INVALIDA := Color(1.0, 0.2, 0.2, 0.4)
const COLOR_MINA_VALIDA := Color(1.0, 0.85, 0.0, 0.4)
const COLOR_MINA_INVALIDA := Color(1.0, 0.2, 0.2, 0.4)
const MITAD_HUELLA := 2  # (NiveladorTerreno.TAMANO_HUELLA - 1) / 2, para una huella de 5x5
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

@onready var mundo: Node = get_node("../VoxelWorld")
@onready var overlay: Node3D = get_node("../ZonaOverlay")
@onready var hud: CanvasLayer = get_node("../HUDLayer")

var tipo_zona_seleccionada: String = Zonificacion.ZONAS_PINTABLES[0]
var esperando_segunda_esquina := false
var primera_esquina := Vector2i.ZERO

## Modo de nivelación de terreno (tecla `B`): un recuadro fantasma de
## NiveladorTerreno.TAMANO_HUELLA x TAMANO_HUELLA sigue la celda bajo el
## cursor (esa celda es el CENTRO de la huella, no la esquina) hasta que el
## jugador hace clic para confirmar. Un mini-plano por celda, cada uno seguio
## la altura real de su propia celda (igual que ZonaOverlay) — un solo plano
## grande a la altura máxima quedaba enterrado bajo el relieve en las
## celdas más bajas de la huella.
var nivelador: RefCounted
var modo_nivelacion := false
var _huella_fantasma: Array[MeshInstance3D] = []

## Modo de colocación de mina (tecla `M`): un disco fantasma (radio
## Recoleccion.RADIO_AREA_MINA, precalculado en offsets circulares) sigue la
## celda bajo el cursor, verde si es válida (fuera de la zona de influencia)
## o rojo si no. Mientras el modo está activo, la ficha del HUD se actualiza
## cada fotograma con los recursos reales detectados en esa posición.
var modo_colocar_mina := false
var _disco_mina: Array[MeshInstance3D] = []
var _offsets_disco_mina: Array[Vector2i] = []

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
	nivelador = NiveladorTerreno.new(mundo)
	_crear_huella_fantasma()
	_crear_disco_mina()


## Crea la cuadrícula de mini-planos fantasma (uno por celda de la huella,
## TAMANO_HUELLA x TAMANO_HUELLA en total) como hijos de esta cámara con
## top_level = true, para poder fijar su posición en coordenadas globales
## sin heredar la rotación/posición de la cámara. Se crean una sola vez y
## se reposicionan cada frame en _actualizar_huella_fantasma() — no se
## recrean, para no generar basura de nodos en cada fotograma.
func _crear_huella_fantasma() -> void:
	var malla := PlaneMesh.new()
	malla.size = Vector2(1.0, 1.0)

	for i in range(NiveladorTerreno.TAMANO_HUELLA * NiveladorTerreno.TAMANO_HUELLA):
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = COLOR_HUELLA_VALIDA
		material.no_depth_test = false

		var plano := MeshInstance3D.new()
		plano.mesh = malla
		plano.material_override = material
		plano.top_level = true
		plano.visible = false
		add_child(plano)
		_huella_fantasma.append(plano)


## Precalcula los offsets (dx, dz) dentro del círculo de radio
## Recoleccion.RADIO_AREA_MINA (mismo criterio de distancia que
## Recoleccion.detectar_recursos(), en el plano horizontal) y crea un plano
## fantasma por offset — mismo patrón de pool reutilizable que
## _crear_huella_fantasma(), para no generar basura de nodos cada fotograma.
func _crear_disco_mina() -> void:
	for dx in range(-Recoleccion.RADIO_AREA_MINA, Recoleccion.RADIO_AREA_MINA + 1):
		for dz in range(-Recoleccion.RADIO_AREA_MINA, Recoleccion.RADIO_AREA_MINA + 1):
			if Vector2(dx, dz).length() <= Recoleccion.RADIO_AREA_MINA:
				_offsets_disco_mina.append(Vector2i(dx, dz))

	var malla := PlaneMesh.new()
	malla.size = Vector2(1.0, 1.0)
	for i in range(_offsets_disco_mina.size()):
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = COLOR_MINA_VALIDA
		material.no_depth_test = false

		var plano := MeshInstance3D.new()
		plano.mesh = malla
		plano.material_override = material
		plano.top_level = true
		plano.visible = false
		add_child(plano)
		_disco_mina.append(plano)


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
		if modo_nivelacion:
			_actualizar_huella_fantasma()
		elif modo_colocar_mina:
			_actualizar_previsualizacion_mina()
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

	if modo_nivelacion:
		_actualizar_huella_fantasma()
	elif modo_colocar_mina:
		_actualizar_previsualizacion_mina()
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


## Recalcula la posición y el color de cada mini-plano de la huella según
## la celda actual bajo el cursor (esa celda es el CENTRO de la huella) y
## si la pendiente ahí es válida o no — cada plano sigue la altura real de
## su propia celda, igual que ZonaOverlay, para no quedar enterrado bajo
## el relieve de celdas vecinas más altas dentro de la misma huella.
func _actualizar_huella_fantasma() -> void:
	var centro := _celda_bajo_mouse(get_viewport().get_mouse_position())
	var esquina := centro - Vector2i(MITAD_HUELLA, MITAD_HUELLA)
	var valida: bool = nivelador.verificar_pendiente(esquina)
	var color: Color = COLOR_HUELLA_VALIDA if valida else COLOR_HUELLA_INVALIDA

	var i := 0
	for dx in range(NiveladorTerreno.TAMANO_HUELLA):
		for dz in range(NiveladorTerreno.TAMANO_HUELLA):
			var x: int = esquina.x + dx
			var z: int = esquina.y + dz
			var altura_celda: int = mundo.altura_en(x, z)
			var plano: MeshInstance3D = _huella_fantasma[i]
			var material: StandardMaterial3D = plano.material_override
			material.albedo_color = color
			plano.position = Vector3(x + DESF, altura_celda + ALTURA_SOBRE_SUPERFICIE, z + DESF)
			i += 1


## Recalcula la posición/color del disco de área de acción según la celda
## bajo el cursor (verde fuera de la zona de influencia = válida, rojo
## dentro = inválida) y la ficha de recolección prevista en el HUD, a partir
## de los recursos reales detectados por Recoleccion.detectar_recursos().
func _actualizar_previsualizacion_mina() -> void:
	var centro := _celda_bajo_mouse(get_viewport().get_mouse_position())
	var valida: bool = not Zonificacion.dentro_de_influencia(centro)
	var color: Color = COLOR_MINA_VALIDA if valida else COLOR_MINA_INVALIDA

	for i in range(_offsets_disco_mina.size()):
		var offset: Vector2i = _offsets_disco_mina[i]
		var x: int = centro.x + offset.x
		var z: int = centro.y + offset.y
		var altura_celda: int = mundo.altura_en(x, z)
		var plano: MeshInstance3D = _disco_mina[i]
		var material: StandardMaterial3D = plano.material_override
		material.albedo_color = color
		plano.position = Vector3(x + DESF, altura_celda + ALTURA_SOBRE_SUPERFICIE, z + DESF)

	var altura_superficie: int = mundo.altura_en(centro.x, centro.y)
	var conteo: Dictionary = Recoleccion.detectar_recursos(mundo, centro, altura_superficie)
	var tasas: Dictionary = Recoleccion.tasas_recoleccion(conteo)
	hud.actualizar_tasas_mina(tasas)


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
		elif tecla.pressed and tecla.keycode == KEY_M:
			_alternar_modo_colocar_mina()

	if event is InputEventMouseButton:
		var boton := event as InputEventMouseButton
		if boton.pressed and boton.button_index == MOUSE_BUTTON_LEFT:
			if modo_nivelacion:
				_procesar_clic_nivelacion(boton.position)
			elif modo_colocar_mina:
				_procesar_clic_mina(boton.position)
			else:
				_procesar_clic(boton.position)
		elif boton.pressed and boton.button_index == MOUSE_BUTTON_WHEEL_UP:
			_intentar_zoom(-VELOCIDAD_ZOOM)
		elif boton.pressed and boton.button_index == MOUSE_BUTTON_WHEEL_DOWN:
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


func _alternar_modo_nivelacion() -> void:
	modo_nivelacion = not modo_nivelacion
	_mostrar_huella_fantasma(modo_nivelacion)
	if modo_nivelacion:
		print("Modo nivelación activo: haz clic para nivelar la huella marcada (B de nuevo para cancelar).")
	else:
		print("Modo nivelación cancelado.")


func _salir_de_modo_nivelacion() -> void:
	modo_nivelacion = false
	_mostrar_huella_fantasma(false)


func _mostrar_huella_fantasma(visible_ahora: bool) -> void:
	for plano in _huella_fantasma:
		plano.visible = visible_ahora


func _alternar_modo_colocar_mina() -> void:
	modo_colocar_mina = not modo_colocar_mina
	_mostrar_disco_mina(modo_colocar_mina)
	if modo_colocar_mina:
		hud.mostrar_ficha_mina()
		print("Modo colocar mina activo: haz clic fuera de la zona de influencia para confirmar (M de nuevo para cancelar).")
	else:
		hud.ocultar_ficha_mina()
		print("Modo colocar mina cancelado.")


func _mostrar_disco_mina(visible_ahora: bool) -> void:
	for plano in _disco_mina:
		plano.visible = visible_ahora


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


## Confirma la colocación de la mina en la celda bajo el cursor si está
## fuera de la zona de influencia — si no, imprime el rechazo y SIGUE en
## modo colocar-mina (a diferencia de la nivelación, que siempre sale del
## modo tras un clic; aquí el jugador puede reintentar de inmediato). El
## bloque marcador se coloca UNA celda por encima de la superficie
## (altura_superficie + 1): la celda de superficie ya está ocupada por el
## bloque "piso" del terreno, así que colocar el marcador ahí mismo siempre
## fallaría (VoxelWorld.colocar_bloque() rechaza celdas ya ocupadas).
func _procesar_clic_mina(posicion_pantalla: Vector2) -> void:
	var celda := _celda_bajo_mouse(posicion_pantalla)
	if Zonificacion.dentro_de_influencia(celda):
		print("No se puede colocar una mina dentro de la zona de influencia.")
		return

	var altura_superficie: int = mundo.altura_en(celda.x, celda.y)
	mundo.colocar_bloque(Vector3i(celda.x, altura_superficie + 1, celda.y), "mina")
	Recoleccion.colocar_mina(celda)
	print("Mina colocada en (", celda.x, ", ", celda.y, ").")

	modo_colocar_mina = false
	_mostrar_disco_mina(false)
	hud.ocultar_ficha_mina()


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
		var altura_actual: int = mundo.altura_en(celda_relleno.x, celda_relleno.y)
		for h in range(1, cantidad + 1):
			mundo.colocar_bloque(Vector3i(celda_relleno.x, altura_actual + h, celda_relleno.y), "tierra")
		total_bloques += cantidad

	print("Terreno nivelado: ", total_bloques, " bloques de tierra usados.")
	_salir_de_modo_nivelacion()

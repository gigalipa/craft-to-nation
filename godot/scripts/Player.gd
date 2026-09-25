extends CharacterBody3D
class_name Player

const GeneradorMundo = preload("res://scripts/GeneradorMundo.gd")

## Avatar en 1ra persona: movimiento WASD + mouse look, y minado/colocación
## de bloques por raycast contra las celdas de VoxelWorld.

const VELOCIDAD := 5.0
## Gravedad y salto calibrados juntos: VELOCIDAD_SALTO = sqrt(2 * GRAVEDAD *
## ALTURA_SALTO_OBJETIVO) para un salto de ~1.2m (sube un bloque sin pasarse
## por mucho) con una caída con más peso que la gravedad original (9.8).
const GRAVEDAD := 19.6
const VELOCIDAD_SALTO := 6.86
const SENSIBILIDAD_MOUSE := 0.003
const ALCANCE_RAYCAST := 5.0
const DANO_TALA := 1

## Velocidad vertical al nadar hacia arriba/abajo (Espacio/Ctrl) una vez que
## los pies llegan al 2do bloque de agua o más profundo — ver
## _profundidad_agua_en_pies(). Un solo bloque de agua no alcanza para nadar:
## el jugador lo atraviesa cayendo con gravedad normal, como si no hubiera
## nada (ver _physics_process()).
const VELOCIDAD_NATACION := 3.0
## Hundimiento lento por defecto al nadar sin tocar Espacio/Ctrl — más lento
## que VELOCIDAD_NATACION, para que "dejarse caer" en el agua no se sienta
## como estar de pie sobre ella.
const VELOCIDAD_HUNDIMIENTO := 1.0

## Corriente de río/cascada (diseño 2026-09-17, a partir de una captura real
## de un río en pendiente de montaña): a mayor pendiente del cauce (ver
## VoxelWorld.corriente_en()/GeneradorMundo.caida_en()), mayor empuje
## horizontal — un tramo llano (caida 0) empuja poco pero nunca cero, y el
## empuje crece con la caída hasta el umbral de cascada
## (GeneradorMundo.UMBRAL_CASCADA); más allá de eso el tramo ya es
## prácticamente vertical y el empuje horizontal relevante es el de
## EMPUJE_CASCADA_BASE_* al pie de la caída, no este. Ver _empuje_rio().
const EMPUJE_RIO_MINIMO := 0.4
const EMPUJE_RIO_POR_CAIDA := 0.7

## Empuje horizontal EXTRA (sumado al de _empuje_rio()) al pie de una
## cascada, interpolado según qué tan grande sea el salto (caida): un salto
## justo en el umbral empuja poco (EMPUJE_CASCADA_BASE_MINIMO), uno grande
## (CAIDA_EMPUJE_SATURA bloques o más) empuja fuerte (EMPUJE_CASCADA_BASE_
## MAXIMO) — ver _empuje_base_cascada().
const EMPUJE_CASCADA_BASE_MINIMO := 0.5
const EMPUJE_CASCADA_BASE_MAXIMO := 9.0
const CAIDA_EMPUJE_SATURA := 12

## Margen vertical (celdas) desde el fondo tallado de una cascada
## (VoxelWorld.columna_cascada_en()["y_base"]) dentro del cual se considera
## que el jugador está "al pie" de la caída — ver _procesar_corriente().
const MARGEN_PIE_CASCADA := 2

## Efecto visual de flotación (solo cosmético, no afecta velocity/colisión):
## mece la cámara con un seno mientras el jugador nada con la cabeza fuera
## del agua, para que se note que está en el agua y no caminando sobre ella
## (ver _procesar_flotacion()).
const AMPLITUD_FLOTACION := 0.08
const FRECUENCIA_FLOTACION := 1.0

## Segundos de aire disponibles con la cabeza sumergida (ver
## _cabeza_sumergida()) antes de ahogarse. Sin sistema de salud todavía (ver
## _morir_jugador()/_ejecutar_sucesion()): llegar a 0 reusa la misma
## sucesión del avatar que la tecla K de prueba.
const OXIGENO_MAXIMO := 10.0
const TASA_CONSUMO_OXIGENO := 1.0
const TASA_RECUPERACION_OXIGENO := 2.0

## Intervalo entre repeticiones de colocar (y de deconstruir, con su contador de
## "sostener") mientras se mantiene el click presionado. Minar, talar y recolectar
## frutos ya no repiten: avanzan por tiempo con ProgresoAccion (ver Recoleccion.
## tiempo_minado_de()).
const INTERVALO_ACCION_REPETIDA := 0.20
const ProgresoAccionScript = preload("res://scripts/ProgresoAccion.gd")

@onready var camara: Camera3D = $Camara
@onready var raycast: RayCast3D = $Camara/RayCast3D

var tipos_disponibles := ["pared", "puerta", "ventana", "piso", "cama", "baul"]
var tipo_seleccionado := 0

var mundo: Node  # asignada por Main.gd al iniciar la escena
@onready var hud: CanvasLayer = get_node("../HUDLayer")

var _excepciones_obra: Dictionary = {}  # int (id de obra) -> cuerpo con el que el avatar tiene excepción
var _minando := false
var _colocando := false
var _temporizador_accion := 0.0
var _progreso_accion: RefCounted = ProgresoAccionScript.new()

var modo_deconstruccion := false
var _id_listo_para_remocion := -1
var _ticks_listo_para_remocion := 0

var oxigeno_actual := OXIGENO_MAXIMO

var _altura_camara_base := 0.0
var _tiempo_flotacion := 0.0

## Cuántos "ticks" de acción repetida (INTERVALO_ACCION_REPETIDA, 0.2s)
## seguidos apuntando al MISMO edificio ya reducido a fantasma vacío hacen
## falta para eliminarlo del todo — demora deliberada (~1s) para evitar
## borrados accidentales al mantener el click presionado.
const TICKS_REMOCION_FINAL := 5


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	raycast.target_position = Vector3(0, 0, -ALCANCE_RAYCAST)
	_altura_camara_base = camara.position.y
	# Las rampas de las vías (cuna_recta/cuna_diag_*) suben 1 bloque en 1
	# celda de distancia horizontal — una pendiente de 45° EXACTOS, justo
	# en el límite del floor_max_angle por defecto de CharacterBody3D
	# (también 45°). Justo en ese límite, pequeñas variaciones de punto
	# flotante en la normal de contacto hacen que Godot trate la rampa
	# como pared en vez de piso al azar, bloqueando el paso (reportado
	# jugando en vivo: "a veces" hay que saltar para pasar). Con margen
	# de sobra por encima de 45° esto no depende de la suerte.
	floor_max_angle = deg_to_rad(50.0)


func _input(event: InputEvent) -> void:
	if not camara.current:
		return
	if event is InputEventKey:
		var tecla := event as InputEventKey
		if tecla.pressed and tecla.keycode == KEY_ESCAPE:
			# Esc desactiva primero la herramienta activa (modo deconstrucción);
			# sin ninguna activa, libera el mouse como siempre.
			if modo_deconstruccion:
				_alternar_modo_deconstruccion()
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if tecla.pressed and tecla.keycode == KEY_B:
			_declarar_edificio()
		if tecla.pressed and tecla.keycode == KEY_G:
			_alternar_modo_deconstruccion()
		if tecla.pressed and not tecla.echo and tecla.keycode == KEY_E:
			_interactuar()
		if tecla.pressed and tecla.keycode == KEY_K:
			_morir_jugador()
		if tecla.pressed:
			var indice: int = tecla.keycode - KEY_1
			if indice >= 0 and indice < tipos_disponibles.size():
				tipo_seleccionado = indice
				print("Tipo de bloque seleccionado: ", tipos_disponibles[tipo_seleccionado])

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var movimiento := event as InputEventMouseMotion
		rotate_y(-movimiento.relative.x * SENSIBILIDAD_MOUSE)
		camara.rotate_x(-movimiento.relative.y * SENSIBILIDAD_MOUSE)
		camara.rotation.x = clamp(camara.rotation.x, -PI / 2.2, PI / 2.2)

	if event is InputEventMouseButton:
		var boton := event as InputEventMouseButton
		if boton.button_index == MOUSE_BUTTON_LEFT:
			_minando = boton.pressed
			if boton.pressed and modo_deconstruccion:
				_temporizador_accion = 0.0
				_deconstruir()
		elif boton.button_index == MOUSE_BUTTON_RIGHT:
			_colocando = boton.pressed
			if boton.pressed:
				_temporizador_accion = 0.0
				_colocar()


## Mientras el jugador mantiene un botón: E recolecta frutos, el clic izquierdo
## mina/tala (por tiempo) o deconstruye (por repetición, con su contador) y el
## derecho coloca (por repetición). Prioridad frutos > izquierdo > derecho, como
## antes lo era izquierdo > derecho: la intención del jugador en un instante es
## una sola acción. Sin ninguna, el avance se pierde y la barra se oculta.
func _procesar_accion_repetida(delta: float) -> void:
	if not camara.current:
		_progreso_accion.soltar()
		hud.ocultar_progreso()
		return
	if Input.is_key_pressed(KEY_E):
		_procesar_frutos(delta)
		return
	if _minando:
		_procesar_minado(delta)
		return
	_progreso_accion.soltar()
	if not _colocando:
		hud.ocultar_progreso()
		return
	_temporizador_accion += delta
	if _temporizador_accion >= INTERVALO_ACCION_REPETIDA:
		_temporizador_accion = 0.0
		_colocar()
	_mostrar_progreso_de_obra(false)


## Barra del avance de la obra apuntada (construye: avanza; deconstruye: retrocede).
## Solo se muestra si la obra está a medias; completa o sin obra, se oculta.
func _mostrar_progreso_de_obra(retrocede: bool) -> void:
	var fraccion := -1.0
	if raycast.is_colliding() and mundo != null:
		fraccion = mundo.fraccion_de_obra(_celda_impactada())
	if fraccion < 0.0 or (not retrocede and fraccion >= 1.0) or (retrocede and fraccion <= 0.0):
		hud.ocultar_progreso()
	else:
		hud.mostrar_progreso(fraccion, retrocede)


## Guarda en el inventario (= almacén central) lo que rindió una extracción del
## avatar; lo que no cabe por tope lleno se pierde, como las entregas de los acarreadores.
func _guardar_en_inventario(rendido: Dictionary) -> void:
	if rendido.is_empty():
		return
	Economia.entregar(rendido)
	print("Recolectado: ", rendido)


## Un frame de clic izquierdo mantenido: deconstruir (repetición + contador),
## talar (si el objetivo es un árbol) o minar (por tiempo del tipo de bloque).
func _procesar_minado(delta: float) -> void:
	if modo_deconstruccion:
		_temporizador_accion += delta
		if _temporizador_accion >= INTERVALO_ACCION_REPETIDA:
			_temporizador_accion = 0.0
			_deconstruir()
		if _ticks_listo_para_remocion > 0:
			hud.mostrar_progreso(1.0 - float(_ticks_listo_para_remocion) / TICKS_REMOCION_FINAL, true)
		else:
			_mostrar_progreso_de_obra(true)
		return
	if not raycast.is_colliding() or mundo == null:
		_progreso_accion.soltar()
		hud.ocultar_progreso()
		return
	var celda := _celda_impactada()
	if mundo.TIPOS_ARBOL.has(mundo.obtener_tipo(celda)):
		_procesar_tala(celda, delta)
		return
	if not mundo.es_minable(celda):
		_progreso_accion.soltar()
		hud.ocultar_progreso()
		return
	var duracion: float = Recoleccion.tiempo_minado_de(mundo.material_real(mundo.obtener_tipo(celda)))
	if _progreso_accion.avanzar("celda:%s" % celda, duracion, delta):
		_guardar_en_inventario(mundo.extraer_por_avatar(celda))
		_progreso_accion.soltar()
		hud.ocultar_progreso()
	else:
		hud.mostrar_progreso(_progreso_accion.fraccion(), false)


## Talar: cada TIEMPO_TALA_POR_SALUD segundos sostenidos resta 1 de salud al árbol
## y rinde 10 de madera. El daño se conserva al soltar (la salud vive en el árbol);
## la barra muestra la salud que le queda.
func _procesar_tala(celda: Vector3i, delta: float) -> void:
	var id: int = mundo.arboles.obtener_arbol_de(celda)
	if id == -1:
		_progreso_accion.soltar()
		hud.ocultar_progreso()
		return
	if _progreso_accion.avanzar("arbol:%d" % id, Recoleccion.TIEMPO_TALA_POR_SALUD, delta):
		var derribado: bool = mundo.talar_bloque_de_arbol(celda, DANO_TALA)
		_guardar_en_inventario({"madera": Recoleccion.rendimiento_de("madera") * DANO_TALA})
		if derribado:
			_progreso_accion.soltar()
			hud.ocultar_progreso()
			return
	hud.mostrar_progreso(float(mundo.arboles.salud_de(id)) / mundo.arboles.salud_maxima_de(id), true)


## Pulsar E (no mantener) sobre el objeto apuntado. Hoy solo alterna puertas;
## la ventana de contenido del baúl se enchufará aquí (ver "Pendientes").
## Mantener E sigue siendo _procesar_frutos().
func _interactuar() -> void:
	if not raycast.is_colliding() or mundo == null or mundo.puertas == null:
		return
	var base: Vector3i = mundo.puertas.celda_de_colisionador(raycast.get_collider())
	if base != Vector3i.MAX:
		mundo.puertas.alternar(base)


## Frutos: mantener E sobre un árbol con frutos, o sobre el baúl de un puesto
## (pasa al inventario lo que quepa de su almacén local). No consume el árbol (ver
## VoxelWorld.recolectar_frutos()).
func _procesar_frutos(delta: float) -> void:
	if not raycast.is_colliding() or mundo == null:
		_progreso_accion.soltar()
		hud.ocultar_progreso()
		return
	if mundo.puertas != null and mundo.puertas.celda_de_colisionador(raycast.get_collider()) != Vector3i.MAX:
		_progreso_accion.soltar()
		hud.ocultar_progreso()
		return
	var celda := _celda_impactada()
	var esquina_deposito: Vector2i = Economia.puesto_con_deposito(celda)
	if esquina_deposito != Recoleccion.SIN_PUESTO:
		_progreso_accion.soltar()
		hud.ocultar_progreso()
		var tomado: Dictionary = Economia.retirar_deposito(esquina_deposito)
		if not tomado.is_empty():
			print("Tomado del depósito del puesto: ", tomado)
		return
	if mundo.frutos_disponibles(celda, Ciudad.horas_juego) <= 0.0:
		_progreso_accion.soltar()
		hud.ocultar_progreso()
		return
	var id: int = mundo.arboles.obtener_arbol_de(celda)
	if _progreso_accion.avanzar("frutos:%d" % id, Recoleccion.TIEMPO_RECOLECCION_FRUTOS, delta):
		_guardar_en_inventario({"comida": mundo.recolectar_frutos(celda, Ciudad.horas_juego)})
		_progreso_accion.soltar()
		hud.ocultar_progreso()
	else:
		hud.mostrar_progreso(_progreso_accion.fraccion(), false)


func _physics_process(delta: float) -> void:
	_procesar_accion_repetida(delta)
	var direccion := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		direccion -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		direccion += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		direccion -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		direccion += transform.basis.x
	direccion = direccion.normalized()

	var nadando := _profundidad_agua_en_pies() >= 2
	var celda_pies: Vector3i = _celda_en(global_position) if mundo != null else Vector3i.ZERO
	var bono := 1.0
	if mundo != null:
		bono = Vias.bono_en(celda_pies - Vector3i(0, 1, 0))
	velocity.x = direccion.x * VELOCIDAD * bono
	velocity.z = direccion.z * VELOCIDAD * bono
	if nadando:
		if Input.is_key_pressed(KEY_SPACE):
			velocity.y = VELOCIDAD_NATACION
		elif Input.is_key_pressed(KEY_CTRL):
			velocity.y = -VELOCIDAD_NATACION
		elif not mundo.columna_cascada_en(celda_pies.x, celda_pies.z).is_empty():
			# Dentro de una cascada, la corriente cae tan rápido como la
			# gravedad normal (diseño 2026-09-17) — mismo cálculo que la
			# rama "sin nadar" de abajo, en vez del hundimiento pasivo.
			velocity.y -= GRAVEDAD * delta
		else:
			velocity.y = -VELOCIDAD_HUNDIMIENTO
	elif not is_on_floor():
		velocity.y -= GRAVEDAD * delta
	elif Input.is_key_pressed(KEY_SPACE):
		velocity.y = VELOCIDAD_SALTO
	else:
		velocity.y = 0.0
	if mundo != null:
		_procesar_corriente(celda_pies)
		_actualizar_permisos_avatar()

	move_and_slide()
	if mundo != null:
		var limitada := _limitar_al_mundo(global_position, mundo.ANCHO_MUNDO, mundo.LARGO_MUNDO)
		if limitada != global_position:
			# Anula también la velocidad que empujaba hacia afuera.
			if limitada.x != global_position.x:
				velocity.x = 0.0
			if limitada.z != global_position.z:
				velocity.z = 0.0
			global_position = limitada
		# +0.1: la posición del CharacterBody3D queda a veces apenas por debajo
		# del suelo por el margen de colisión; así la celda siempre es la de los pies.
		Colonos.actualizar_avatar(_celda_en(global_position + Vector3.UP * 0.1), velocity)
	_procesar_oxigeno(delta)
	_procesar_flotacion(delta, nadando)


## Cuenta cuántos bloques de agua consecutivos hay desde la celda de los pies
## del jugador hacia arriba (0 si los pies no están en agua). Determina tanto
## si hay suficiente profundidad para nadar (>= 2, ver _physics_process()) —
## un solo bloque de agua no alcanza, el jugador lo atraviesa cayendo con
## gravedad normal — como cuántos bloques lleva hundidos dentro del cuerpo de
## agua.
func _profundidad_agua_en_pies() -> int:
	return _profundidad_agua_en(global_position)


## Recibe la posición como parámetro (en vez de leer global_position
## directamente) para poder probarla en PlayerNatacionTest.gd sin necesitar
## que el nodo esté dentro del árbol de la escena.
func _profundidad_agua_en(posicion: Vector3) -> int:
	if mundo == null:
		return 0
	var celda: Vector3i = _celda_en(posicion)
	if mundo.obtener_tipo(celda) != "agua":
		return 0
	var profundidad := 1
	celda += Vector3i(0, 1, 0)
	while mundo.obtener_tipo(celda) == "agua":
		profundidad += 1
		celda += Vector3i(0, 1, 0)
	return profundidad


## Celda de grilla (VoxelWorld) bajo "posicion" — asume mundo != null.
func _celda_en(posicion: Vector3) -> Vector3i:
	return mundo.local_to_map(mundo.to_local(posicion))


## true si los pies o la cabeza del avatar están dentro del volumen de la obra.
func _dentro_de_obra(id_obra: int) -> bool:
	var pies: Vector3i = _celda_en(global_position + Vector3.UP * 0.1)
	return mundo.celda_en_volumen(id_obra, pies) or mundo.celda_en_volumen(id_obra, pies + Vector3i(0, 1, 0))


## Una obra acaba de pasar a fantasma (se emplazó un blueprint o empezó a
## deconstruirse un edificio completo): si el avatar está dentro de su
## volumen, recibe permiso para salir sin chocar con sus fantasmas (Sección 6
## del spec de colonos y pathfinding). Conectada en Main.gd.
func _on_obra_a_fantasma(id_obra: int) -> void:
	if mundo != null and _dentro_de_obra(id_obra):
		mundo.otorgar_permiso_salida(id_obra, "avatar")


## true si los pies o la cabeza están dentro del volumen de la obra ampliado 1
## celda en x y z: la cápsula (radio 0.4) aún solapa las cajas del borde cuando
## la celda de los pies ya salió, y quitar la excepción en ese momento la
## empujaría. Solo para mantener/revocar el permiso; otorgarlo usa _dentro_de_obra().
func _cerca_de_obra(id_obra: int) -> bool:
	var pies: Vector3i = _celda_en(global_position + Vector3.UP * 0.1)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var columna := pies + Vector3i(dx, 0, dz)
			if mundo.celda_en_volumen(id_obra, columna) or mundo.celda_en_volumen(id_obra, columna + Vector3i(0, 1, 0)):
				return true
	return false


## Mantiene la excepción de colisión del avatar con las obras donde tiene
## permiso vigente, y lo revoca (para siempre) al salir de su volumen (con
## margen, ver _cerca_de_obra()): desde fuera los fantasmas vuelven a ser
## sólidos y no se puede volver a entrar. Se llama cada frame de física.
## _excepciones_obra recuerda con qué cuerpo se añadió cada excepción: así se
## quita la excepción correcta aunque la obra se destruya o su cuerpo se recree.
func _actualizar_permisos_avatar() -> void:
	for id_obra in mundo.obras_con_permiso("avatar"):
		if _cerca_de_obra(id_obra):
			var cuerpo: Node = mundo.cuerpo_de_obra(id_obra)
			if cuerpo != null and _excepciones_obra.get(id_obra) != cuerpo:
				add_collision_exception_with(cuerpo)
				_excepciones_obra[id_obra] = cuerpo
		else:
			mundo.revocar_permiso_salida(id_obra, "avatar")
	# Excepciones registradas cuyo permiso ya no existe (se revocó o la obra se
	# destruyó) o cuyo cuerpo ya no es el vigente (se recreó).
	var vigentes: Array[int] = mundo.obras_con_permiso("avatar")
	for id_obra in _excepciones_obra.keys():
		var registrado = _excepciones_obra[id_obra]
		if not vigentes.has(id_obra) or registrado != mundo.cuerpo_de_obra(id_obra):
			if is_instance_valid(registrado):
				remove_collision_exception_with(registrado)
			_excepciones_obra.erase(id_obra)


## Empuje de corriente de río/cascada (ver EMPUJE_RIO_MINIMO más arriba):
## se SUMA a velocity.x/z después del control WASD normal, así que el
## jugador conserva su propio movimiento sobre la corriente en vez de que
## esta lo reemplace. Cubre tanto el empuje a lo largo de todo el cauce
## (VoxelWorld.corriente_en(), incluyendo tramos llanos) como el empuje
## extra al pie de una cascada (VoxelWorld.columna_cascada_en()).
func _procesar_corriente(celda_pies: Vector3i) -> void:
	# Solo empuja si la celda de los pies es agua REAL ahora mismo — no basta
	# con que GeneradorMundo la haya marcado como franja de río al generar el
	# mundo: un pasillo minado detrás de una cascada sigue devolviendo
	# corriente_en()/columna_cascada_en() no vacíos (esos datos son estáticos
	# y no saben que el jugador ya vació esa celda), y sin este chequeo el
	# empuje seguía "halando" al jugador hacia afuera del pasillo aunque ya
	# no hubiera ni una gota de agua ahí (bug real, reportado jugando en
	# vivo, 2026-09-18).
	if mundo.obtener_tipo(celda_pies) != "agua":
		return
	var corriente: Dictionary = mundo.corriente_en(celda_pies.x, celda_pies.z)
	if not corriente.is_empty() and corriente["direccion"] != Vector2i.ZERO:
		var empuje: float = _empuje_rio(corriente["caida"])
		velocity.x += corriente["direccion"].x * empuje
		velocity.z += corriente["direccion"].y * empuje
	var cascada: Dictionary = mundo.columna_cascada_en(celda_pies.x, celda_pies.z)
	if cascada.is_empty() or cascada["direccion"] == Vector2i.ZERO:
		return
	if celda_pies.y > cascada["y_base"] + MARGEN_PIE_CASCADA:
		return
	var empuje_base: float = _empuje_base_cascada(cascada["caida"])
	velocity.x += cascada["direccion"].x * empuje_base
	velocity.z += cascada["direccion"].y * empuje_base


## Empuje horizontal de un tramo de río con esta "caida" de altura (Sección
## diseño 2026-09-17) — mínimo pero no cero en llano, creciendo linealmente
## hasta el umbral de cascada (más allá de eso, ver _empuje_base_cascada()).
## Función pura (sin acceder a "mundo"/"velocity") para poder probarla
## directamente en PlayerNatacionTest.gd.
static func _empuje_rio(caida: int) -> float:
	return EMPUJE_RIO_MINIMO + minf(float(caida), float(GeneradorMundo.UMBRAL_CASCADA)) * EMPUJE_RIO_POR_CAIDA


## Empuje horizontal EXTRA al pie de una cascada de esta "caida" (altura del
## salto): satura entre EMPUJE_CASCADA_BASE_MINIMO (justo en el umbral) y
## EMPUJE_CASCADA_BASE_MAXIMO (CAIDA_EMPUJE_SATURA bloques o más). Función
## pura, mismo motivo que _empuje_rio().
static func _empuje_base_cascada(caida: int) -> float:
	var factor: float = clampf(float(caida - GeneradorMundo.UMBRAL_CASCADA) / float(CAIDA_EMPUJE_SATURA - GeneradorMundo.UMBRAL_CASCADA), 0.0, 1.0)
	return lerpf(EMPUJE_CASCADA_BASE_MINIMO, EMPUJE_CASCADA_BASE_MAXIMO, factor)


## Confina "posicion" al mundo (x en [0, ancho], z en [0, largo]) dejando
## "radio" (el de la cápsula del avatar) de margen respecto al borde; y no se
## toca. Función pura, mismo motivo que _empuje_rio().
static func _limitar_al_mundo(posicion: Vector3, ancho: int, largo: int, radio: float = 0.4) -> Vector3:
	return Vector3(
		clampf(posicion.x, radio, ancho - radio),
		posicion.y,
		clampf(posicion.z, radio, largo - radio)
	)


## Efecto cosmético (no toca velocity ni colisión): mece la cámara con un
## seno mientras el jugador nada con la cabeza fuera del agua, para que se
## note que está en el agua y no caminando sobre ella. Se apaga (altura base,
## fase en 0) en cuanto deja de nadar o se sumerge del todo.
func _procesar_flotacion(delta: float, nadando: bool) -> void:
	if nadando and not _cabeza_sumergida():
		_tiempo_flotacion += delta
		camara.position.y = _altura_camara_base + sin(_tiempo_flotacion * FRECUENCIA_FLOTACION * TAU) * AMPLITUD_FLOTACION
	else:
		_tiempo_flotacion = 0.0
		camara.position.y = _altura_camara_base


## true si el bloque en la cámara (altura de los ojos) es agua — es lo que
## gasta oxígeno, no _pies_en_agua() (ver _procesar_oxigeno()).
func _cabeza_sumergida() -> bool:
	if mundo == null:
		return false
	return mundo.obtener_tipo(mundo.local_to_map(mundo.to_local(camara.global_position))) == "agua"


## Aritmética pura de oxígeno, sin nodos ni estado — extraída así para poder
## probarla en PlayerOxigenoTest.gd sin necesitar una escena real. Clampeada
## a [0, OXIGENO_MAXIMO].
static func _calcular_oxigeno(actual: float, sumergido: bool, delta: float) -> float:
	if sumergido:
		return max(0.0, actual - TASA_CONSUMO_OXIGENO * delta)
	return min(OXIGENO_MAXIMO, actual + TASA_RECUPERACION_OXIGENO * delta)


func _procesar_oxigeno(delta: float) -> void:
	var sumergido := _cabeza_sumergida()
	oxigeno_actual = _calcular_oxigeno(oxigeno_actual, sumergido, delta)
	if sumergido or oxigeno_actual < OXIGENO_MAXIMO:
		hud.actualizar_oxigeno(oxigeno_actual / OXIGENO_MAXIMO)
	else:
		hud.ocultar_oxigeno()
	if oxigeno_actual <= 0.0:
		_ejecutar_sucesion("ahogamiento")


## GridMap expone una única forma física para todo el mapa (no un cuerpo por
## celda), así que la celda impactada se calcula a partir del punto de
## colisión, desplazado ligeramente hacia adentro de la cara golpeada para
## caer siempre dentro de la celda sólida y no en la vecina vacía.
func _celda_impactada() -> Vector3i:
	var punto := raycast.get_collision_point()
	var normal := raycast.get_collision_normal()
	return mundo.local_to_map(mundo.to_local(punto - normal * 0.5))


## Activa/desactiva el modo deconstrucción — muestra/oculta el aviso en el
## HUD. Al desactivarse, también se olvida cualquier progreso de "sostener
## para remoción final" (ver _procesar_deconstruccion()) — si el jugador
## sale del modo a medio sostener el click, no debe contar para la próxima
## vez que lo reactive.
func _alternar_modo_deconstruccion() -> void:
	modo_deconstruccion = not modo_deconstruccion
	if modo_deconstruccion:
		hud.mostrar_modo_deconstruccion()
	else:
		hud.ocultar_modo_deconstruccion()
	_id_listo_para_remocion = -1
	_ticks_listo_para_remocion = 0


## Un intento de deconstrucción sobre el bloque bajo la mira (modo G). Minar y
## talar ahora van por tiempo (ver _procesar_minado()).
func _deconstruir() -> void:
	if not raycast.is_colliding() or mundo == null:
		return
	_procesar_deconstruccion(_celda_impactada())


## Se llama en cada click/repetición de _deconstruir() mientras modo_deconstruccion
## está activo. Delega toda la lógica de "qué revertir" en
## VoxelWorld.procesar_deconstruccion() — aquí solo se maneja lo que le
## corresponde al jugador/Ciudad/Zonificacion/Recoleccion: negarse sobre el
## núcleo urbano (exento), retirar camas la primera vez, y contar
## TICKS_REMOCION_FINAL intentos consecutivos sobre el MISMO edificio ya
## listo para remoción antes de eliminarlo del todo.
func _procesar_deconstruccion(celda: Vector3i) -> void:
	if Zonificacion.celda_es_del_nucleo(Vector2i(celda.x, celda.z)):
		print("El núcleo urbano no se puede deconstruir.")
		_id_listo_para_remocion = -1
		_ticks_listo_para_remocion = 0
		return

	var resultado: Dictionary = mundo.procesar_deconstruccion(celda)
	if resultado.is_empty():
		_id_listo_para_remocion = -1
		_ticks_listo_para_remocion = 0
		return

	Ciudad.retirar_edificio_residencial(resultado["id"])  # idempotente
	var metadata_obra: Dictionary = mundo.edificio_metadata.get(resultado["id"], {})
	if metadata_obra.has("puesto"):
		Economia.desactivar_puesto(metadata_obra["puesto"])  # idempotente: un puesto en deconstrucción deja de funcionar
	if resultado["total_camas"] > 0:
		print("Deconstrucción iniciada: ", resultado["total_camas"], " cama(s) retiradas de Ciudad.")

	if not resultado["lista_para_remocion"]:
		_id_listo_para_remocion = -1
		_ticks_listo_para_remocion = 0
		return

	var id: int = resultado["id"]
	if _id_listo_para_remocion == id:
		_ticks_listo_para_remocion += 1
	else:
		_id_listo_para_remocion = id
		_ticks_listo_para_remocion = 1

	if _ticks_listo_para_remocion >= TICKS_REMOCION_FINAL:
		var metadata_final: Dictionary = mundo.edificio_metadata.get(id, {})  # eliminar_edificio() la borra
		var esquina: Vector2i = mundo.eliminar_edificio(id)
		if metadata_final.has("puesto"):
			esquina = metadata_final["puesto"]  # la esquina del puesto, no la de las celdas de la plantilla
		Zonificacion.retirar_contribucion(id)
		Recoleccion.quitar_puesto(esquina)
		Economia.quitar_puesto(esquina)  # libera a sus trabajadores (no-op si era un edificio)
		print("Edificio deconstruido por completo.")
		_id_listo_para_remocion = -1
		_ticks_listo_para_remocion = 0


## Redondea hacia dónde mira el cuerpo (solo yaw, sin el pitch de la cámara,
## que es un nodo hijo separado) a una de las 4 direcciones cardinales.
func _direccion_cardinal() -> Vector3i:
	var adelante := -transform.basis.z
	if abs(adelante.x) > abs(adelante.z):
		return Vector3i(sign(adelante.x), 0, 0)
	return Vector3i(0, 0, sign(adelante.z))


## Antes de intentar colocar un bloque nuevo, intenta surtir la celda
## apuntada como parte de una construcción en curso (ver
## CamaraCenital._procesar_clic_blueprint() / VoxelWorld.surtir_construccion()).
## Se intenta sin importar el TIPO actual de la celda (fantasma o ya
## convertida a bloque real): mientras la construcción a la que pertenece
## siga incompleta, surtir_construccion() encuentra su id igual por
## cualquiera de sus celdas y avanza la cola — así el jugador puede seguir
## suministrando mobiliario interior (cama, baúl) apuntando a una pared
## exterior ya construida, aunque el interior haya quedado encerrado y ya
## no sea alcanzable con la mira. Antes se exigía que la celda apuntada
## fuera literalmente "fantasma", lo que causaba dos bugs: 1) una vez
## cerrada la estructura exterior, el mobiliario interior pendiente
## quedaba fuera de alcance y el edificio nunca se completaba; 2) al
## mantener el click sostenido, la celda fantasma se convertía en bloque
## real en el primer tick y el SIGUIENTE tick (mismo click) ya no
## encontraba una celda fantasma, así que caía a colocar un bloque nuevo
## no solicitado contra el edificio.
## Reutiliza el click derecho (colocar) en vez del izquierdo (minar)
## porque conceptualmente "surtir" es aportar material, no destruir.
## Una vez completa la construcción (edificio_progreso >= orden.size() en
## VoxelWorld.gd), surtir_construccion() devuelve {} para esa celda y esta
## función cae al flujo normal de colocar un bloque nuevo contra la cara
## apuntada — igual que contra cualquier otra superficie del edificio ya
## terminado.
func _colocar() -> void:
	if not raycast.is_colliding() or mundo == null:
		return
	var celda := _celda_impactada()
	var resultado: Dictionary = mundo.surtir_construccion(celda)
	if not resultado.is_empty():
		if resultado.get("bloqueada", false):
			print("Hay alguien dentro del sitio de la obra %d: deben salir antes de iniciarla." % resultado["id"])
		elif resultado.get("completa", false):
			_completar_construccion(resultado["metadata"])
		return
	var normal := raycast.get_collision_normal()
	var celda_destino := celda + Vector3i(round(normal.x), round(normal.y), round(normal.z))
	var tipo: String = tipos_disponibles[tipo_seleccionado]
	var colocado: bool
	if tipo == "puerta":
		colocado = mundo.colocar_puerta(celda_destino)
	elif tipo == "cama":
		colocado = mundo.colocar_cama(celda_destino, _direccion_cardinal())
	else:
		colocado = mundo.colocar_bloque(celda_destino, tipo, true)
	if not colocado:
		print("No hay espacio suficiente para colocar: ", tipo)


## Declara como edificio la estructura conectada al bloque apuntado. Solo se
## activa apuntando a una puerta (la entrada principal), no a cualquier pared,
## para que "declarar" sea una acción intencional del jugador sobre un punto
## reconocible de la construcción.
func _declarar_edificio() -> void:
	if not raycast.is_colliding() or mundo == null:
		return
	var celda := _celda_impactada()
	var tipo_apuntado: String = mundo.obtener_tipo(celda)
	if tipo_apuntado != "puerta_inferior" and tipo_apuntado != "puerta_superior":
		print("Declarar edificio: apunta a la puerta principal de la estructura.")
		return
	if mundo.id_de_edificio(celda) != -1:
		print("Declarar edificio: ese edificio ya fue declarado.")
		return
	var celdas: Dictionary = mundo.detectar_estructura(celda)
	if celdas.is_empty():
		print("Declarar edificio: esa puerta no fue colocada por el jugador.")
		return
	var blueprint := BlueprintValidator.estructura_a_blueprint(celdas)

	# Huella en planta (X,Z) del edificio, sin repetir celdas — usada tanto
	# para el bootstrap del núcleo urbano como, más adelante, para pintarla
	# como Núcleo A. "celda" es la puerta apuntada, la misma referencia que
	# ya usa detectar_estructura() para "dónde está" el edificio. "esquina"
	# (mínimo x, mínimo z) se calcula en la misma pasada, para pasarla a
	# _completar_construccion() vía metadata igual que un blueprint.
	var celda_puerta_xz := Vector2i(celda.x, celda.z)
	var huella: Array = []
	var huella_vista: Dictionary = {}  # Vector2i -> true, para no repetir celdas
	var esquina := celda_puerta_xz
	for pos in celdas.keys():
		var punto_xz := Vector2i(pos.x, pos.z)
		esquina.x = min(esquina.x, punto_xz.x)
		esquina.y = min(esquina.y, punto_xz.y)
		if not huella_vista.has(punto_xz):
			huella_vista[punto_xz] = true
			huella.append(punto_xz)

	var limites_vivienda: Dictionary = Ciudad.NIVELES_VIVIENDA[Ciudad.nivel]
	var resultado: Dictionary
	if not Zonificacion.nucleo_declarado:
		resultado = BlueprintValidator.validar_blueprint(blueprint, "", {}, {}, limites_vivienda)
	else:
		var zona_destino: String = Zonificacion.consultar_zona(celda_puerta_xz)
		resultado = BlueprintValidator.validar_blueprint(blueprint, zona_destino, {}, {}, limites_vivienda)

	print("Declarar edificio -> Válido: ", resultado["valido"], " | Errores: ", resultado["errores"])
	if not resultado["valido"]:
		return
	if not mundo.verificar_despejes(celdas):
		print("Declarar edificio: una ventana o puerta quedaría sin el despeje mínimo, o invade el despeje de otro edificio.")
		return

	Blueprints.guardar(blueprint)
	# Delega en _completar_construccion() (mismo camino que un edificio
	# terminado vía blueprint) para que un edificio declarado a mano quede
	# con el mismo edificio_orden/edificio_progreso — deconstruirlo y
	# volver a completarlo funciona igual que cualquier otro, sin perder
	# sus camas/zona/puesto (ver spec de rediseño, punto 11).
	var metadata := {
		"blueprint": blueprint,
		"huella_xz": huella,
		"esquina": esquina,
		"ancho": blueprint["ancho"],
		"profundidad": blueprint["profundidad"],
	}
	var id_edificio: int = mundo.registrar_edificio_completo(celdas, metadata)
	metadata["id_edificio"] = id_edificio
	_completar_construccion(metadata)


## Tecla de prueba (K): simula la muerte del jugador para poder probar la
## sucesión del Avatar en vivo. No hay salud/combate real todavía (ver
## PoC_4/); ver _ejecutar_sucesion() para la causa real de muerte que sí
## existe hoy (ahogamiento, ver _procesar_oxigeno()).
func _morir_jugador() -> void:
	_ejecutar_sucesion("prueba (tecla K)")


## Compartida entre la tecla K de prueba y cualquier causa de muerte real
## (hoy solo ahogamiento, ver _procesar_oxigeno()) — sin sistema de
## salud/combate todavía, toda muerte pasa por la misma sucesión de Ciudad.
func _ejecutar_sucesion(motivo: String) -> void:
	var resultado: String = Ciudad.suceder_avatar()
	print("Muerte del jugador (", motivo, ") -> Sucesión: ", resultado)
	if resultado == "sucesion_exitosa":
		global_position = Vector3(0, 1, 0)
		velocity = Vector3.ZERO
		oxigeno_actual = OXIGENO_MAXIMO
		print("Sucesor al mando. Jugador reaparece en el punto de partida.")


## Se llama cuando VoxelWorld.surtir_construccion() indica que una
## construcción fantasma quedó completa. "metadata" es la que se pasó a
## VoxelWorld.iniciar_construccion_fantasma() al colocarla (ver
## CamaraCenital._procesar_clic_blueprint()) — un edificio residencial, o un
## puesto de recolección que se volvió a completar tras deconstruirse
## (metadata {"puesto": esquina}): este solo reactiva su Economia y no pasa
## por el registro de Ciudad/Zonificacion.
func _completar_construccion(metadata: Dictionary) -> void:
	if metadata.is_empty():
		return
	if metadata.has("puesto"):
		Economia.reactivar_puesto(metadata["puesto"])
		print("Puesto reactivado en ", metadata["puesto"], ".")
		return
	var blueprint: Dictionary = metadata["blueprint"]

	# El primer edificio declarado es el núcleo urbano: no es habitable, así que
	# no suma camas (no llegan colonos todavía) ni baúles al tope del almacén; en
	# cambio, declararlo duplica los topes del inventario.
	if not Zonificacion.nucleo_declarado:
		Zonificacion.declarar_nucleo(metadata["huella_xz"])
		Ciudad.ampliar_almacen()
		print("Núcleo urbano declarado (no habitable: no llegan colonos todavía). Zona de influencia: ", Zonificacion.influencia_min, " a ", Zonificacion.influencia_max, ". Topes del inventario duplicados.")
		Recoleccion.colocar_puesto(metadata["esquina"], "blueprint", metadata["ancho"], metadata["profundidad"])
		return

	var camas_por_piso: Array[int] = []
	var total_camas := 0
	for piso in blueprint["pisos"]:
		var camas: int = (piso.get("camas", []) as Array).size()
		camas_por_piso.append(camas)
		total_camas += camas
	var baules: int = BlueprintValidator.contar_baules(blueprint)
	Ciudad.registrar_edificio_residencial(metadata["id_edificio"], camas_por_piso, baules)
	print("Construcción completa: camas registradas en Ciudad: ", total_camas, " (capacidad de camas actual: ", Ciudad.capacidad_camas_construida, "), baúles: ", baules)

	Zonificacion.ampliar_influencia(metadata.get("id_edificio", -1), metadata["huella_xz"], blueprint["categoria"])
	print("Zona de influencia ampliada: ", Zonificacion.influencia_min, " a ", Zonificacion.influencia_max)

	Recoleccion.colocar_puesto(metadata["esquina"], "blueprint", metadata["ancho"], metadata["profundidad"])

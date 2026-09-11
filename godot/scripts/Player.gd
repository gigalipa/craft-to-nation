extends CharacterBody3D
class_name Player

const BlueprintValidator = preload("res://scripts/BlueprintValidator.gd")  # TEMP: ver nota de verificación tras mover el proyecto a godot/

## Avatar en 1ra persona: movimiento WASD + mouse look, y minado/colocación
## de bloques por raycast contra las celdas de VoxelWorld.

const VELOCIDAD := 5.0
const GRAVEDAD := 9.8
const VELOCIDAD_SALTO := 5.5
const SENSIBILIDAD_MOUSE := 0.003
const ALCANCE_RAYCAST := 5.0
const DANO_TALA := 1

## Intervalo entre repeticiones de minar/colocar mientras se mantiene el
## click presionado. Placeholder único para todo tipo de bloque/herramienta
## — a futuro cada bloque tendrá su propia "vida"/tiempo de minado (como
## Minecraft) y esto dependerá también de la herramienta equipada.
const INTERVALO_ACCION_REPETIDA := 0.20

@onready var camara: Camera3D = $Camara
@onready var raycast: RayCast3D = $Camara/RayCast3D

var tipos_disponibles := ["pared", "puerta", "ventana", "piso", "cama", "baul"]
var tipo_seleccionado := 0

var mundo: Node  # asignada por Main.gd al iniciar la escena
@onready var hud: CanvasLayer = get_node("../HUDLayer")

var _minando := false
var _colocando := false
var _temporizador_accion := 0.0

var modo_deconstruccion := false
var _id_listo_para_remocion := -1
var _ticks_listo_para_remocion := 0

## Cuántos "ticks" de acción repetida (INTERVALO_ACCION_REPETIDA, 0.2s)
## seguidos apuntando al MISMO edificio ya reducido a fantasma vacío hacen
## falta para eliminarlo del todo — demora deliberada (~1s) para evitar
## borrados accidentales al mantener el click presionado.
const TICKS_REMOCION_FINAL := 5


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	raycast.target_position = Vector3(0, 0, -ALCANCE_RAYCAST)


func _input(event: InputEvent) -> void:
	if not camara.current:
		return
	if event is InputEventKey:
		var tecla := event as InputEventKey
		if tecla.pressed and tecla.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if tecla.pressed and tecla.keycode == KEY_B:
			_declarar_edificio()
		if tecla.pressed and tecla.keycode == KEY_G:
			_alternar_modo_deconstruccion()
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
			if boton.pressed:
				_temporizador_accion = 0.0
				_minar()
		elif boton.button_index == MOUSE_BUTTON_RIGHT:
			_colocando = boton.pressed
			if boton.pressed:
				_temporizador_accion = 0.0
				_colocar()


## Mientras el jugador mantiene el click, repite minar/colocar cada
## INTERVALO_ACCION_REPETIDA — un solo temporizador compartido porque nunca
## se puede minar y colocar al mismo tiempo (son botones distintos, pero la
## intención del jugador en un instante dado es una sola acción).
func _procesar_accion_repetida(delta: float) -> void:
	if not _minando and not _colocando:
		return
	_temporizador_accion += delta
	if _temporizador_accion < INTERVALO_ACCION_REPETIDA:
		return
	_temporizador_accion = 0.0
	if _minando:
		_minar()
	elif _colocando:
		_colocar()


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

	velocity.x = direccion.x * VELOCIDAD
	velocity.z = direccion.z * VELOCIDAD
	if not is_on_floor():
		velocity.y -= GRAVEDAD * delta
	elif Input.is_key_pressed(KEY_SPACE):
		velocity.y = VELOCIDAD_SALTO
	else:
		velocity.y = 0.0

	move_and_slide()


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


func _minar() -> void:
	if not raycast.is_colliding() or mundo == null:
		return
	var celda := _celda_impactada()
	if modo_deconstruccion:
		_procesar_deconstruccion(celda)
		return
	if mundo.TIPOS_ARBOL.has(mundo.obtener_tipo(celda)):
		mundo.talar_bloque_de_arbol(celda, DANO_TALA)
	else:
		mundo.minar_bloque(celda)


## Se llama en cada click/repetición de _minar() mientras modo_deconstruccion
## está activo. Delega toda la lógica de "qué revertir" en
## VoxelWorld.procesar_deconstruccion() — aquí solo se maneja lo que le
## corresponde al jugador/Ciudad/Zonificacion/Recoleccion: negarse sobre el
## núcleo urbano (exento), retirar camas la primera vez, y contar
## TICKS_REMOCION_FINAL intentos consecutivos sobre el MISMO edificio ya
## listo para remoción antes de eliminarlo del todo.
func _procesar_deconstruccion(celda: Vector3i) -> void:
	if Zonificacion.celda_es_del_nucleo(Vector2i(celda.x, celda.z)):
		print("El núcleo urbano no se puede deconstruir.")
		return

	var resultado: Dictionary = mundo.procesar_deconstruccion(celda)
	if resultado.is_empty():
		_id_listo_para_remocion = -1
		_ticks_listo_para_remocion = 0
		return

	if resultado["total_camas"] > 0:
		Ciudad.retirar_edificio_residencial(resultado["total_camas"])
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
		var esquina: Vector2i = mundo.eliminar_edificio(id)
		Zonificacion.retirar_contribucion(id)
		Recoleccion.quitar_puesto(esquina)
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
## Una vez completa la construcción, surtir_construccion() ya no encuentra
## ningún id (Construccion limpia su registro) y esta función cae al flujo
## normal de colocar un bloque nuevo contra la cara apuntada — igual que
## contra cualquier otra superficie del edificio ya terminado.
func _colocar() -> void:
	if not raycast.is_colliding() or mundo == null:
		return
	var celda := _celda_impactada()
	var resultado: Dictionary = mundo.surtir_construccion(celda)
	if not resultado.is_empty():
		if resultado.get("completa", false):
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
	var celdas: Dictionary = mundo.detectar_estructura(celda)
	if celdas.is_empty():
		print("Declarar edificio: esa puerta no fue colocada por el jugador.")
		return
	var blueprint := BlueprintValidator.estructura_a_blueprint(celdas)

	# Huella en planta (X,Z) del edificio, sin repetir celdas — usada tanto
	# para el bootstrap del núcleo urbano como, más adelante, para pintarla
	# como Núcleo A. "celda" es la puerta apuntada, la misma referencia que
	# ya usa detectar_estructura() para "dónde está" el edificio.
	var celda_puerta_xz := Vector2i(celda.x, celda.z)
	var huella: Array = []
	var huella_vista: Dictionary = {}  # Vector2i -> true, para no repetir celdas
	for pos in celdas.keys():
		var punto_xz := Vector2i(pos.x, pos.z)
		if not huella_vista.has(punto_xz):
			huella_vista[punto_xz] = true
			huella.append(punto_xz)

	var resultado: Dictionary
	if not Zonificacion.nucleo_declarado:
		resultado = BlueprintValidator.validar_blueprint(blueprint)
	else:
		var zona_destino: String = Zonificacion.consultar_zona(celda_puerta_xz)
		resultado = BlueprintValidator.validar_blueprint(blueprint, zona_destino)

	print("Declarar edificio -> Válido: ", resultado["valido"], " | Errores: ", resultado["errores"])
	if resultado["valido"]:
		Blueprints.guardar(blueprint)
		var id_edificio: int = mundo.registrar_edificio(celdas.keys())
		var total_camas := 0
		for piso in blueprint["pisos"]:
			total_camas += (piso.get("camas", []) as Array).size()
		Ciudad.registrar_edificio_residencial(total_camas)
		print("Camas registradas en Ciudad: ", total_camas, " (total construido: ", Ciudad.capacidad_camas_construida, ")")

		if not Zonificacion.nucleo_declarado:
			Zonificacion.declarar_nucleo(huella)
			print("Núcleo urbano declarado. Zona de influencia: ", Zonificacion.influencia_min, " a ", Zonificacion.influencia_max)
		else:
			Zonificacion.ampliar_influencia(id_edificio, huella, blueprint["categoria"])
			print("Zona de influencia ampliada: ", Zonificacion.influencia_min, " a ", Zonificacion.influencia_max)


## Tecla de prueba (K): simula la muerte del jugador para poder probar la
## sucesión del Avatar en vivo. No hay salud/combate real todavía (ver
## PoC_4/); esta PoC no modela ninguna causa de muerte física.
func _morir_jugador() -> void:
	var resultado: String = Ciudad.suceder_avatar()
	print("Muerte del jugador -> Sucesión: ", resultado)
	if resultado == "sucesion_exitosa":
		global_position = Vector3(0, 1, 0)
		velocity = Vector3.ZERO
		print("Sucesor al mando. Jugador reaparece en el punto de partida.")


## Se llama cuando VoxelWorld.surtir_construccion() indica que una
## construcción fantasma quedó completa. "metadata" es la que se pasó a
## VoxelWorld.iniciar_construccion_fantasma() al colocarla (ver
## CamaraCenital._procesar_clic_blueprint()) — hoy siempre un edificio; un
## puesto periférico completado (sub-proyecto B, futuro) no pasaría por
## este registro de Ciudad/Zonificacion (metadata vacía o de otra forma).
func _completar_construccion(metadata: Dictionary) -> void:
	if metadata.is_empty():
		return
	var blueprint: Dictionary = metadata["blueprint"]
	var total_camas := 0
	for piso in blueprint["pisos"]:
		total_camas += (piso.get("camas", []) as Array).size()
	Ciudad.registrar_edificio_residencial(total_camas)
	print("Construcción completa: camas registradas en Ciudad: ", total_camas, " (total construido: ", Ciudad.capacidad_camas_construida, ")")

	if not Zonificacion.nucleo_declarado:
		Zonificacion.declarar_nucleo(metadata["huella_xz"])
		print("Núcleo urbano declarado. Zona de influencia: ", Zonificacion.influencia_min, " a ", Zonificacion.influencia_max)
	else:
		Zonificacion.ampliar_influencia(metadata["id_edificio"], metadata["huella_xz"], blueprint["categoria"])
		print("Zona de influencia ampliada: ", Zonificacion.influencia_min, " a ", Zonificacion.influencia_max)

	Recoleccion.colocar_puesto(metadata["esquina"], "blueprint", metadata["ancho"], metadata["profundidad"])

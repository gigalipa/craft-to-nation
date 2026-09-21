extends Node

## Autoload "Colonos": los ciudadanos NPC de la ciudad. Estado y
## comportamiento puros (sin nodos de escena, como Ciudad.gd/Zonificacion.gd);
## el dibujo y el cuerpo físico los pone ColonosRenderer. Ver spec:
## docs/superpowers/specs/2026-09-20-colonos-pathfinding-design.md (Sección 3).
##
## Ciudad.demografia sigue siendo la fuente de verdad de las CANTIDADES:
## reconciliar() crea o retira colonos para igualarla cuando Ciudad emite
## tick_simulado. Las dependencias (mundo, ciudad, zona) son inyectables para
## poder probar todo sin escena (ColonosTest.gd).

const BuscadorRutas = preload("res://scripts/BuscadorRutas.gd")

signal colono_creado(id: int)
signal colono_retirado(id: int)

## Valor centinela de "no hay celda": una celda imposible.
const INVALIDA := Vector3i(999999, 999999, 999999)

## Placeholders sin balance real.
const VELOCIDAD_COLONO := 2.5  # celdas por segundo
const ESPERA_ENTRE_DESTINOS_MIN := 1.0
const ESPERA_ENTRE_DESTINOS_MAX := 3.0
const ESPERA_BLOQUEO := 0.5  # segundos esperando antes de esquivar
const INTENTOS_DESTINO := 8
const INTENTOS_APARICION := 200
const PROBABILIDAD_CASA := 0.5  # de deambular hacia su hogar en vez de por la ciudad
const ESPERA_TRABAJO := 1.0  # segundos que espera un recolector/acarreador antes de volver a decidir
const INTENTOS_SERVICIO := 6  # celdas junto a una huella que se prueban al buscar ruta

## El mundo (VoxelWorld en el juego). Asignarlo crea el buscador de rutas.
var mundo: Object = null:
	set(valor):
		if mundo != null and mundo.has_signal("obra_a_fantasma") and mundo.obra_a_fantasma.is_connected(_on_obra_a_fantasma):
			mundo.obra_a_fantasma.disconnect(_on_obra_a_fantasma)
		mundo = valor
		_buscador = BuscadorRutas.new(valor) if valor != null else null
		if valor != null and valor.has_signal("obra_a_fantasma"):
			valor.obra_a_fantasma.connect(_on_obra_a_fantasma)
var ciudad: Object = null  # Ciudad
var zona: Object = null  # Zonificacion
var economia: Object = null:  # Economia
	set(valor):
		if economia != null and economia.puesto_quitado.is_connected(_on_puesto_quitado):
			economia.puesto_quitado.disconnect(_on_puesto_quitado)
		economia = valor
		if valor != null:
			valor.puesto_quitado.connect(_on_puesto_quitado)

## id -> {"id", "tipo", "hogar", "celda", "posicion", "ruta", "progreso",
## "moviendo", "espera", "bloqueo", "trabajo", "carga", "fase", "fallos_servicio"}. "celda" es la celda donde está parado;
## "posicion" (Vector3, los pies) es lo que dibuja el renderer.
var colonos: Dictionary = {}
## Vector3i -> id de colono: la celda que ocupa cada colono y, mientras da un
## paso, también la celda a la que va (reserva).
var ocupadas: Dictionary = {}
## Celdas que el avatar ocupa ahora (Vector3i -> true): la suya y, si se está
## moviendo, la de adelante. Los colonos las esquivan pero no huyen: solo
## abandonan su destino si quedan bloqueados (ver _esquivar()).
var celdas_avatar: Dictionary = {}

var _siguiente_id := 1
var _buscador: RefCounted = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if ciudad == null:
		ciudad = Ciudad
	if zona == null:
		zona = Zonificacion
	if economia == null:
		economia = Economia
	ciudad.tick_simulado.connect(reconciliar)


func _process(delta: float) -> void:
	avanzar(delta)


## Agrega un colono en "celda" (que debe ser transitable) y lo devuelve.
func agregar_colono(tipo: String, celda: Vector3i, hogar: int = -1) -> int:
	var id := _siguiente_id
	_siguiente_id += 1
	var ruta: Array[Vector3i] = []
	colonos[id] = {
		"id": id, "tipo": tipo, "hogar": hogar,
		"celda": celda, "posicion": _centro_de(celda),
		"ruta": ruta, "progreso": 0.0, "moviendo": false,
		"espera": 0.0, "bloqueo": 0.0,
		"evacuando": -1, "ruta_de_evacuacion": false,
		"trabajo": {}, "carga": {}, "fase": "", "fallos_servicio": 0,
	}
	ocupadas[celda] = id
	colono_creado.emit(id)
	return id


## Crea o retira colonos hasta que haya uno por cada unidad de
## Ciudad.demografia[tipo], y reasigna los hogares que ya no existen.
func reconciliar() -> void:
	if _buscador == null:
		return  # todavía no se asignó el mundo (p. ej. una escena de pruebas sin Main)
	var demografia: Dictionary = ciudad.demografia
	for tipo in demografia:
		var existentes: Array[int] = _ids_de_tipo(tipo)
		while existentes.size() > demografia[tipo]:
			_retirar(existentes.pop_back())
		while existentes.size() < demografia[tipo]:
			var celda: Vector3i = _celda_aparicion()
			if celda == INVALIDA:
				break  # sin celda de aparición transitable: se reintenta en el siguiente tick
			existentes.append(agregar_colono(tipo, celda, _elegir_hogar()))
	_reasignar_hogares()


func _ids_de_tipo(tipo: String) -> Array[int]:
	var ids: Array[int] = []
	for id in colonos:
		if colonos[id]["tipo"] == tipo:
			ids.append(id)
	return ids


func _retirar(id: int) -> void:
	var colono: Dictionary = colonos[id]
	if not colono["trabajo"].is_empty():
		economia.liberar(id)
	if colono["evacuando"] != -1:
		mundo.revocar_permiso_salida(colono["evacuando"], id)
	ocupadas.erase(colono["celda"])
	if colono["moviendo"] and not colono["ruta"].is_empty():
		ocupadas.erase(colono["ruta"][0])
	colonos.erase(id)
	colono_retirado.emit(id)


## Los pies del colono están en el borde inferior de su celda; x y z, al centro.
func _centro_de(celda: Vector3i) -> Vector3:
	return Vector3(celda.x + 0.5, celda.y, celda.z + 0.5)


## Camas totales de un hogar (suma de las de todos sus pisos).
func _capacidad_hogar(id: int) -> float:
	var total := 0.0
	for camas in ciudad.edificios_residenciales.get(id, []):
		total += camas
	return total


## Vivienda que ocupan sus colonos: cada uno pesa 1 / x_cama.
func _ocupacion_hogar(id: int) -> float:
	var total := 0.0
	for c in colonos.values():
		if c["hogar"] == id:
			total += 1.0 / float(ciudad.TIPOS_POBLACION[c["tipo"]]["x_cama"])
	return total


## El hogar con menor ocupación relativa (ocupación / camas); en empate, el de
## id menor. -1 si no hay ningún edificio residencial con camas. El hogar solo
## determina a dónde entra el colono: el límite vinculante de población es la
## capacidad global de Ciudad, y un hogar puede quedar algo por encima.
## ponytail: no fuerza capacidad por casa; añadirlo si hace falta un tope
## individual.
func _elegir_hogar() -> int:
	var ids: Array = ciudad.edificios_residenciales.keys()
	ids.sort()
	var mejor := -1
	var mejor_ratio := INF
	for id: int in ids:
		var capacidad := _capacidad_hogar(id)
		if capacidad <= 0.0:
			continue
		var ratio := _ocupacion_hogar(id) / capacidad
		if ratio < mejor_ratio - 1e-9:
			mejor = id
			mejor_ratio = ratio
	return mejor


func _reasignar_hogares() -> void:
	for c in colonos.values():
		if c["hogar"] == -1 or not ciudad.edificios_residenciales.has(c["hogar"]):
			c["hogar"] = _elegir_hogar()


func avanzar(delta: float) -> void:
	if _buscador == null:
		return
	for c in colonos.values():
		_avanzar_colono(c, delta)


func _avanzar_colono(c: Dictionary, delta: float) -> void:
	if c["moviendo"]:
		_completar_paso(c, delta)
		return
	if c["evacuando"] != -1:
		_avanzar_evacuacion(c, delta)
		return
	if c["espera"] > 0.0:
		c["espera"] -= delta
		return
	if c["ruta"].is_empty():
		if c["trabajo"].is_empty():
			_elegir_destino(c)
		else:
			_decidir_trabajo(c)
		return
	_iniciar_paso(c, delta)


## Empieza a caminar hacia la siguiente celda de la ruta, si sigue siendo
## transitable (el mundo pudo cambiar: minado, obra, agua) y nadie la ocupa.
func _iniciar_paso(c: Dictionary, delta: float) -> void:
	var siguiente: Vector3i = c["ruta"][0]
	if not _buscador.es_transitable(siguiente, _ignorar_de(c)):
		_replanificar(c)
		return
	if _ocupada_por_otro(siguiente, c["id"]):
		c["bloqueo"] += delta
		if c["bloqueo"] >= ESPERA_BLOQUEO:
			c["bloqueo"] = 0.0
			_esquivar(c)
		return
	c["bloqueo"] = 0.0
	ocupadas[siguiente] = c["id"]  # reserva la celda a la que va
	c["moviendo"] = true
	if not c["trabajo"].is_empty():
		economia.marcar_presente(c["id"], false)  # se aleja del puesto: deja de producir
	c["progreso"] = 0.0
	_completar_paso(c, delta)


func _completar_paso(c: Dictionary, delta: float) -> void:
	c["progreso"] += delta * VELOCIDAD_COLONO
	var siguiente: Vector3i = c["ruta"][0]
	var t: float = minf(c["progreso"], 1.0)
	c["posicion"] = _centro_de(c["celda"]).lerp(_centro_de(siguiente), t)
	if c["progreso"] < 1.0:
		return
	ocupadas.erase(c["celda"])
	c["celda"] = siguiente
	c["ruta"].pop_front()
	c["moviendo"] = false
	c["progreso"] = 0.0
	if c["ruta"].is_empty() and c["trabajo"].is_empty():
		c["espera"] = _rng.randf_range(ESPERA_ENTRE_DESTINOS_MIN, ESPERA_ENTRE_DESTINOS_MAX)


## La llama Player.gd en cada frame de física con la celda donde está y su
## velocidad. Si se mueve (más de 0.5 celdas/s horizontales), la celda de
## adelante, en el sentido dominante de la velocidad, también cuenta.
func actualizar_avatar(celda: Vector3i, velocidad: Vector3) -> void:
	celdas_avatar.clear()
	celdas_avatar[celda] = true
	var horizontal := Vector2(velocidad.x, velocidad.z)
	if horizontal.length() <= 0.5:
		return
	if absf(horizontal.x) > absf(horizontal.y):
		celdas_avatar[celda + Vector3i(int(signf(horizontal.x)), 0, 0)] = true
	else:
		celdas_avatar[celda + Vector3i(0, 0, int(signf(horizontal.y)))] = true


func _ocupada_por_otro(celda: Vector3i, id: int) -> bool:
	return (ocupadas.has(celda) and ocupadas[celda] != id) or celdas_avatar.has(celda)


## Celdas que este colono no puede pisar ahora: las de los demás colonos y
## las del avatar.
func _bloqueadas_para(id: int) -> Dictionary:
	var bloqueadas := {}
	for celda in ocupadas:
		if ocupadas[celda] != id:
			bloqueadas[celda] = true
	for celda in celdas_avatar:
		bloqueadas[celda] = true
	return bloqueadas


## Ids de obra cuyos fantasmas este colono puede atravesar: solo la que está
## evacuando.
func _ignorar_de(c: Dictionary) -> Array:
	return [c["evacuando"]] if c["evacuando"] != -1 else []


func _opciones_ruta(c: Dictionary) -> Dictionary:
	return {"bloqueadas": _bloqueadas_para(c["id"]), "ignorar_fantasmas": _ignorar_de(c)}


## Una obra acaba de pasar a fantasma: cada colono cuya celda esté dentro de
## su volumen recibe permiso de salida y pasa a evacuar (ver
## _avanzar_evacuacion()). Los de fuera no cambian nada. Conectada a
## VoxelWorld.obra_a_fantasma.
func _on_obra_a_fantasma(id_obra: int) -> void:
	for c in colonos.values():
		if c["evacuando"] == -1 and mundo.celda_en_volumen(id_obra, c["celda"]):
			mundo.otorgar_permiso_salida(id_obra, c["id"])
			c["evacuando"] = id_obra
			c["ruta_de_evacuacion"] = false  # se planifica en el siguiente paso, cuando no esté a medio paso


## Mientras evacúa no hace otra cosa: cuando ya no está dentro del volumen
## revoca su permiso (para siempre) y vuelve a lo suyo; si no, planifica o
## recorre la ruta de salida (que atraviesa los fantasmas de esa obra).
func _avanzar_evacuacion(c: Dictionary, delta: float) -> void:
	var id_obra: int = c["evacuando"]
	if not mundo.celda_en_volumen(id_obra, c["celda"]):
		mundo.revocar_permiso_salida(id_obra, c["id"])
		c["evacuando"] = -1
		c["ruta_de_evacuacion"] = false
		var vacia: Array[Vector3i] = []
		c["ruta"] = vacia
		c["espera"] = _rng.randf_range(ESPERA_ENTRE_DESTINOS_MIN, ESPERA_ENTRE_DESTINOS_MAX)
		return
	if c["espera"] > 0.0:
		c["espera"] -= delta
		return
	if not c["ruta_de_evacuacion"]:
		var vacia: Array[Vector3i] = []
		c["ruta"] = vacia  # abandona lo que hacía
		_planear_evacuacion(c)
		return
	if c["ruta"].is_empty():
		c["ruta_de_evacuacion"] = false  # se agotó o se rompió: se replanifica
		return
	_iniciar_paso(c, delta)


func _planear_evacuacion(c: Dictionary) -> void:
	var id_obra: int = c["evacuando"]
	var esta_dentro := func(celda: Vector3i) -> bool: return mundo.celda_en_volumen(id_obra, celda)
	var ruta: Array[Vector3i] = _buscador.buscar_salida(c["celda"], esta_dentro, _opciones_ruta(c))
	c["ruta"] = ruta
	c["ruta_de_evacuacion"] = not ruta.is_empty()
	if ruta.is_empty():
		c["espera"] = 1.0  # sin salida ahora mismo: reintenta en un segundo


## Vuelve a calcular la ruta al MISMO destino sin obstáculos de otros
## (el mundo cambió bajo la ruta); si ya no hay ruta, abandona el destino.
func _replanificar(c: Dictionary) -> void:
	var vacia: Array[Vector3i] = []
	if c["ruta"].is_empty():
		return
	var destino: Vector3i = c["ruta"].back()
	var nueva: Array[Vector3i] = _buscador.buscar_ruta(c["celda"], destino, {"ignorar_fantasmas": _ignorar_de(c)})
	c["ruta"] = nueva if not nueva.is_empty() else vacia
	if nueva.is_empty():
		c["espera"] = _rng.randf_range(ESPERA_ENTRE_DESTINOS_MIN, ESPERA_ENTRE_DESTINOS_MAX)


## Otro colono (o el avatar) le cierra el paso: rodea sus celdas; si no hay
## forma, abandona el destino y elige otro tras esperar. Dos colonos de frente
## en un pasillo de 1 celda se resuelven porque ambos abandonan su destino.
## ponytail: sin negociación de prioridad; añadirla si aparecen atascos
## persistentes con mucha población.
func _esquivar(c: Dictionary) -> void:
	var vacia: Array[Vector3i] = []
	var destino: Vector3i = c["ruta"].back()
	var nueva: Array[Vector3i] = _buscador.buscar_ruta(c["celda"], destino, _opciones_ruta(c))
	if nueva.is_empty():
		c["ruta"] = vacia
		c["espera"] = _rng.randf_range(ESPERA_ENTRE_DESTINOS_MIN, ESPERA_ENTRE_DESTINOS_MAX)
	else:
		c["ruta"] = nueva


## Recuperación de un colono atrapado, común a deambular y a trabajar. true si
## puede seguir planificando (su celda es transitable o se reubicó); false si
## quien llama debe volver (recibió permiso y evacúa, o no pudo reubicarse y espera).
func _recuperar_si_atrapado(c: Dictionary) -> bool:
	# Si algo se volvió sólido sobre el colono (bloque, agua, fantasma), la
	# búsqueda de ruta falla siempre desde un origen no transitable y quedaría
	# congelado: se reubica en lo alto de su propia columna. (No hay reserva en
	# vuelo: aquí solo se llega con "moviendo" en falso.)
	if not _buscador.es_transitable(c["celda"]):
		# Atrapado en un fantasma SIN permiso: (a) a medio paso, su celda reservada
		# cayó en un volumen que pasó a fantasma (_on_obra_a_fantasma solo mira
		# c["celda"]); o (b) una puerta donde estaba revirtió a fantasma al
		# deconstruir, tras la única emisión. Se le da el permiso y evacúa (lo
		# retoma _avanzar_evacuacion). Solo se comprueba la celda de los pies: un
		# fantasma únicamente sobre su cabeza no se trata aquí.
		if mundo.obtener_tipo(c["celda"]) == "fantasma":
			var id_obra: int = mundo.id_de_edificio(c["celda"])
			if id_obra != -1 and mundo.celda_en_volumen(id_obra, c["celda"]):
				mundo.otorgar_permiso_salida(id_obra, c["id"])
				c["evacuando"] = id_obra
				c["ruta_de_evacuacion"] = false
				return false
		var reubicada := Vector3i(c["celda"].x, mundo.altura_en(c["celda"].x, c["celda"].z) + 1, c["celda"].z)
		if not _buscador.es_transitable(reubicada) or _ocupada_por_otro(reubicada, c["id"]):
			c["espera"] = _rng.randf_range(ESPERA_ENTRE_DESTINOS_MIN, ESPERA_ENTRE_DESTINOS_MAX)
			return false
		ocupadas.erase(c["celda"])
		c["celda"] = reubicada
		c["posicion"] = _centro_de(reubicada)
		ocupadas[reubicada] = c["id"]
	return true


## Elige el siguiente destino: la mitad de las veces su casa (si tiene), el
## resto un punto de la zona de influencia. Prueba INTENTOS_DESTINO veces hasta
## dar con uno alcanzable; si no, espera y reintenta.
func _elegir_destino(c: Dictionary) -> void:
	if not _recuperar_si_atrapado(c):
		return
	var opciones := _opciones_ruta(c)
	var a_casa: bool = c["hogar"] != -1 and _rng.randf() < PROBABILIDAD_CASA
	for i in range(INTENTOS_DESTINO):
		var destino: Vector3i = _candidato_en_casa(c["hogar"]) if a_casa else _candidato_exterior()
		if destino == INVALIDA:
			continue
		var ruta: Array[Vector3i] = _buscador.buscar_ruta(c["celda"], destino, opciones)
		if not ruta.is_empty():
			c["ruta"] = ruta
			return
	c["espera"] = _rng.randf_range(ESPERA_ENTRE_DESTINOS_MIN, ESPERA_ENTRE_DESTINOS_MAX)


## Una celda transitable al azar dentro de la caja envolvente de las celdas del
## hogar (puede quedar sobre una cama o junto a ella); INVALIDA si cae en una
## pared o en el aire.
func _candidato_en_casa(hogar: int) -> Vector3i:
	var celdas: Array = mundo.edificio_a_celdas.get(hogar, [])
	if celdas.is_empty():
		return INVALIDA
	var minimo: Vector3i = celdas[0]
	var maximo: Vector3i = celdas[0]
	for celda: Vector3i in celdas:
		minimo = Vector3i(mini(minimo.x, celda.x), mini(minimo.y, celda.y), mini(minimo.z, celda.z))
		maximo = Vector3i(maxi(maximo.x, celda.x), maxi(maximo.y, celda.y), maxi(maximo.z, celda.z))
	var candidata := Vector3i(
		_rng.randi_range(minimo.x, maximo.x),
		_rng.randi_range(minimo.y, maximo.y),
		_rng.randi_range(minimo.z, maximo.z)
	)
	return candidata if _buscador.es_transitable(candidata) else INVALIDA


## Una celda transitable dentro de la zona de influencia, al azar; INVALIDA si
## el azar cayó fuera de la zona o en una celda sin suelo transitable.
func _candidato_exterior() -> Vector3i:
	var minimo: Vector2i = zona.influencia_min
	var maximo: Vector2i = zona.influencia_max
	var x := _rng.randi_range(minimo.x, maximo.x)
	var z := _rng.randi_range(minimo.y, maximo.y)
	if not zona.dentro_de_influencia(Vector2i(x, z)):
		return INVALIDA
	var celda := Vector3i(x, mundo.altura_en(x, z) + 1, z)
	return celda if _buscador.es_transitable(celda) else INVALIDA


## true si algún vecino ortogonal (x, z) queda fuera de la zona de influencia.
func _es_borde_de_zona(xz: Vector2i) -> bool:
	for direccion in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not zona.dentro_de_influencia(xz + direccion):
			return true
	return false


## Donde aparece un migrante: una celda transitable libre en el BORDE de la
## zona de influencia (llegan "desde fuera"); si tras INTENTOS_APARICION
## intentos no cae ninguna en el borde, cualquier celda transitable libre.
## ponytail: muestreo aleatorio en la caja de la zona; suficiente mientras la
## zona sea grande y casi convexa.
func _celda_aparicion() -> Vector3i:
	var respaldo := INVALIDA
	for i in range(INTENTOS_APARICION):
		var celda: Vector3i = _candidato_exterior()
		if celda == INVALIDA or ocupadas.has(celda) or celdas_avatar.has(celda):
			continue
		if _es_borde_de_zona(Vector2i(celda.x, celda.z)):
			return celda
		if respaldo == INVALIDA:
			respaldo = celda
	return respaldo


## Contrata a un desempleado (el de id menor) para un puesto con un rol
## ("recolector" o "acarreador"): pasa a obrero en Ciudad.demografia y en el
## colono. Falso si no hay desempleados, el puesto no existe o no tiene cupo.
func contratar(esquina: Vector2i, rol: String) -> bool:
	var desempleados: Array[int] = _ids_de_tipo("desempleado")
	if desempleados.is_empty():
		return false
	desempleados.sort()
	var id: int = desempleados[0]
	if not economia.asignar(esquina, rol, id):
		return false
	ciudad.reasignar_tipo("desempleado", "obrero")
	var c: Dictionary = colonos[id]
	c["tipo"] = "obrero"
	c["trabajo"] = {"puesto": esquina, "rol": rol}
	c["fase"] = ""
	c["carga"] = {}
	c["fallos_servicio"] = 0
	_dejar_lo_que_hacia(c)
	return true


## Despide al último colono contratado con ese rol en el puesto; vuelve a
## desempleado y pierde lo que llevara. Falso si no hay ninguno.
func despedir(esquina: Vector2i, rol: String) -> bool:
	var id: int = economia.ultimo_de(esquina, rol)
	if id == -1 or not colonos.has(id):
		return false
	economia.liberar(id)
	_volver_a_desempleado(colonos[id])
	return true


## El puesto se quitó (se deconstruyó): sus trabajadores ya fueron liberados en
## Economia; aquí solo vuelven a desempleado. Conectada a Economia.puesto_quitado.
func _on_puesto_quitado(ids: Array) -> void:
	for id in ids:
		if colonos.has(id):
			_volver_a_desempleado(colonos[id])


func _volver_a_desempleado(c: Dictionary) -> void:
	c["trabajo"] = {}
	c["carga"] = {}
	c["fase"] = ""
	c["fallos_servicio"] = 0
	c["tipo"] = "desempleado"
	ciudad.reasignar_tipo("obrero", "desempleado")
	_dejar_lo_que_hacia(c)


## Abandona la ruta en curso (si no está a medio paso) para que el colono
## decida de nuevo con su oficio nuevo o sin él.
func _dejar_lo_que_hacia(c: Dictionary) -> void:
	if c["moviendo"] or c["evacuando"] != -1:
		return  # termina el paso o la evacuación y decide después
	var vacia: Array[Vector3i] = []
	c["ruta"] = vacia
	c["espera"] = 0.0


## Lo que hace un trabajador cuando está quieto, sin ruta ni espera: un
## recolector va a su puesto y se queda (presente); un acarreador cicla
## puesto -> núcleo -> puesto.
func _decidir_trabajo(c: Dictionary) -> void:
	if not _recuperar_si_atrapado(c):
		return
	var esquina: Vector2i = c["trabajo"]["puesto"]
	var huella_puesto: Array = economia.huella_de(esquina)
	if huella_puesto.is_empty():
		c["espera"] = ESPERA_TRABAJO  # el puesto ya no existe: Economia avisará
		return
	if c["trabajo"]["rol"] == "recolector":
		if _junto_a(c["celda"], huella_puesto):
			economia.marcar_presente(c["id"], true)
			c["espera"] = ESPERA_TRABAJO
		else:
			_ir_junto_a(c, huella_puesto)
		return
	var huella_nucleo: Array = zona.huella_del_nucleo()
	if c["fase"] == "entregar":
		if _junto_a(c["celda"], huella_nucleo):
			economia.entregar(c["carga"])
			c["carga"] = {}
			c["fase"] = "recoger"
		else:
			_ir_junto_a(c, huella_nucleo)
		return
	# fase "" o "recoger": ir al puesto y pedir la carga.
	if not _junto_a(c["celda"], huella_puesto):
		_ir_junto_a(c, huella_puesto)
		return
	var carga: Dictionary = economia.recoger(esquina, economia.CAPACIDAD_CARGA)
	if carga.is_empty():
		c["espera"] = ESPERA_TRABAJO  # todavía no hay carga (o nada que llevar)
		return
	c["carga"] = carga
	c["fase"] = "entregar"


## true si "celda" está en la columna pegada (4 direcciones) a alguna celda de
## la huella y no dentro de ella.
func _junto_a(celda: Vector3i, huella: Array) -> bool:
	var xz := Vector2i(celda.x, celda.z)
	if huella.has(xz):
		return false
	for direccion in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if huella.has(xz + direccion):
			return true
	return false


## Celdas transitables en el anillo que rodea una huella (una por columna,
## sobre la superficie).
func _celdas_junto_a(huella: Array) -> Array[Vector3i]:
	var vistas := {}
	var celdas: Array[Vector3i] = []
	for celda: Vector2i in huella:
		for direccion in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var vecina: Vector2i = celda + direccion
			if huella.has(vecina) or vistas.has(vecina):
				continue
			vistas[vecina] = true
			var altura: int = mundo.altura_en(vecina.x, vecina.y)
			if altura < 0:
				continue
			var candidata := Vector3i(vecina.x, altura + 1, vecina.y)
			if _buscador.es_transitable(candidata):
				celdas.append(candidata)
	return celdas


## Planifica una ruta hasta la celda libre más cercana junto a la huella; si
## ninguna de las INTENTOS_SERVICIO más cercanas es alcanzable, espera y reintenta.
func _ir_junto_a(c: Dictionary, huella: Array) -> void:
	var candidatas: Array[Vector3i] = _celdas_junto_a(huella)
	var origen: Vector3i = c["celda"]
	candidatas.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return (a - origen).length_squared() < (b - origen).length_squared())
	var opciones := _opciones_ruta(c)
	for i in range(mini(candidatas.size(), INTENTOS_SERVICIO)):
		var ruta: Array[Vector3i] = _buscador.buscar_ruta(origen, candidatas[i], opciones)
		if not ruta.is_empty():
			c["ruta"] = ruta
			c["fallos_servicio"] = 0
			return
	# Sin ruta (o sin celda libre): retroceso exponencial (1, 2, 4, 8 s) para no
	# repetir hasta INTENTOS_SERVICIO búsquedas costosas cada segundo.
	c["fallos_servicio"] = mini(c["fallos_servicio"] + 1, 4)
	c["espera"] = ESPERA_TRABAJO * pow(2.0, c["fallos_servicio"] - 1)

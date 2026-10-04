extends Node

## Coordinador de las obras que hacen los colonos libres (ver
## docs/superpowers/specs/2026-10-02-obras-por-colonos-design.md). Las obras de
## construcción NO se registran aquí: se derivan de VoxelWorld (un edificio con
## progreso incompleto que nadie abandonó). Lo que sí guarda son las marcas de
## demolición, las obras pausadas por falta de material, las abandonadas
## (deconstruidas a medias por el jugador o desmarcadas: no se reconstruyen solas)
## y los vetos temporales por colono. No mueve colonos: Colonos.gd pide
## siguiente_tarea() y llama a trabajar().

const FinalizacionObras = preload("res://scripts/FinalizacionObras.gd")
const NiveladorTerrenoScript = preload("res://scripts/NiveladorTerreno.gd")
const PanelPuestoScript = preload("res://scripts/PanelPuesto.gd")

## Cambió la marca de demolición de un edificio (la dibuja MarcasDemolicionOverlay).
signal marca_cambiada(id: int, marcado: bool)
## Mensaje para el jugador (Main lo envía al HUD).
signal aviso(texto: String)

const ESPERA_BLOQUEADA := 1.0  # s que espera un colono si hay alguien dentro de la obra
const DURACION_VETO_MS := 30000  # una obra a la que un colono no pudo llegar se le oculta ese tiempo
const DURACION_RECLAMO_MS := 3000  # tras actuar el jugador a mano sobre un edificio, los colonos se lo ceden ese tiempo

## El mundo (VoxelWorld en el juego), asignado por Main.
var mundo: Object = null
var ciudad: Object = null  # Ciudad
var zona: Object = null  # Zonificacion
var colonos: Object = null  # Colonos

## Funciones de fin de obra; sustituibles en las pruebas.
var al_completar: Callable = FinalizacionObras.completar_construccion
var al_deconstruir: Callable = FinalizacionObras.al_deconstruir
var al_retirar: Callable = FinalizacionObras.retirar_edificio

var marcados: Dictionary = {}  # id -> true
var demolicion_programada: Dictionary = {}  # id -> horas restantes
var abandonadas: Dictionary = {}  # id -> true
var pausadas: Dictionary = {}  # id -> recurso que falta
var pausadas_por_jugador: Dictionary = {}  # id -> true (pausa pedida desde la ventana del edificio)
var _necesidades: Dictionary = {}  # id -> cantidad del recurso que pide el paso que quedó pausado
var _vetos: Dictionary = {}  # "id:colono" -> ms hasta los que dura
var _reclamos: Dictionary = {}  # id -> ms hasta los que el jugador lo tiene reclamado


func _ready() -> void:
	if ciudad == null:
		ciudad = Ciudad
	if zona == null:
		zona = Zonificacion
	if colonos == null:
		colonos = Colonos
	if ciudad != null and not ciudad.tick_simulado.is_connected(simular_hora):
		ciudad.tick_simulado.connect(simular_hora)


func esta_marcado(id: int) -> bool:
	return marcados.has(id)


func esta_programada(id: int) -> bool:
	return demolicion_programada.has(id)


func horas_programadas(id: int) -> int:
	return demolicion_programada.get(id, 0)


## Programa la demolición para iniciar tras "horas" de simulación.
func programar_demolicion(id: int, horas: int = 5) -> String:
	if mundo == null or not mundo.edificio_orden.has(id):
		return "Eso no es un edificio."
	if _es_del_nucleo(id):
		return "El núcleo urbano no se puede demoler."
	demolicion_programada[id] = horas
	abandonadas.erase(id)
	marca_cambiada.emit(id, true)
	return ""


## Cancela una demolición programada o en curso.
func cancelar_demolicion(id: int) -> String:
	var habia_p: bool = demolicion_programada.erase(id)
	var habia_m: bool = marcados.erase(id)
	if habia_p or habia_m:
		marca_cambiada.emit(id, false)
	return ""


## Avanza la cuenta regresiva de las demoliciones programadas.
func simular_hora() -> void:
	var para_marcar: Array[int] = []
	for id in demolicion_programada:
		demolicion_programada[id] -= 1
		if demolicion_programada[id] <= 0:
			para_marcar.append(id)
	for id in para_marcar:
		demolicion_programada.erase(id)
		marcados[id] = true
		abandonadas.erase(id)
		marca_cambiada.emit(id, true)
		aviso.emit("Demolición iniciada.")


## Marca o desmarca un edificio para demolición inmediata. Devuelve "" si lo hizo, o el
## motivo del rechazo. Desmarcar uno que los colonos ya empezaron a demoler lo deja
## abandonado (ver _demoler_un_paso()); uno que nadie tocó sigue siendo una obra normal.
func alternar_marca(id: int) -> String:
	if demolicion_programada.has(id):
		cancelar_demolicion(id)
		return ""
	if marcados.has(id):
		marcados.erase(id)
		marca_cambiada.emit(id, false)
		return ""
	if mundo == null or not mundo.edificio_orden.has(id):
		return "Eso no es un edificio."
	if _es_del_nucleo(id):
		return "El núcleo urbano no se puede demoler."
	marcados[id] = true
	abandonadas.erase(id)
	marca_cambiada.emit(id, true)
	return ""


## true si el edificio es del núcleo urbano (que no se demuele).
func _es_del_nucleo(id: int) -> bool:
	if zona != null and zona.get("id_nucleo") != null and zona.id_nucleo == id:
		return true
	if ciudad != null and ciudad.get("id_nucleo") != null and ciudad.id_nucleo == id:
		return true
	if mundo != null and mundo.edificio_a_celdas.has(id):
		for celda: Vector3i in mundo.edificio_a_celdas[id]:
			if zona != null and zona.celda_es_del_nucleo(Vector2i(celda.x, celda.z)):
				return true
	return false


func es_del_nucleo(id: int) -> bool:
	return _es_del_nucleo(id)


## El jugador deconstruyó parte de este edificio a mano: los colonos no lo reconstruyen.
func abandonar(id: int) -> void:
	abandonadas[id] = true


## El edificio dejó de existir (o se retiró): borra todo rastro de él.
func olvidar(id: int) -> void:
	var habia_m: bool = marcados.erase(id)
	var habia_p: bool = demolicion_programada.erase(id)
	var habia_marca: bool = habia_m or habia_p
	abandonadas.erase(id)
	pausadas.erase(id)
	_necesidades.erase(id)
	pausadas_por_jugador.erase(id)
	_reclamos.erase(id)
	if habia_marca:
		marca_cambiada.emit(id, false)


func vetar(id: int, id_colono: int) -> void:
	_vetos["%d:%d" % [id, id_colono]] = Time.get_ticks_msec() + DURACION_VETO_MS


func _vetada(id: int, id_colono: int) -> bool:
	return _vetos.get("%d:%d" % [id, id_colono], 0) > Time.get_ticks_msec()


## El jugador acaba de construir o deconstruir este edificio a mano: los colonos le ceden la obra un rato.
func reclamar(id: int) -> void:
	_reclamos[id] = Time.get_ticks_msec() + DURACION_RECLAMO_MS


func esta_reclamada(id: int) -> bool:
	return _reclamos.get(id, 0) > Time.get_ticks_msec()


## Pausa o reanuda la obra (de construcción o de demolición) a petición del jugador. No impide que
## el jugador la siga a mano.
func alternar_pausa(id: int) -> void:
	if pausadas_por_jugador.has(id) or abandonadas.has(id):
		pausadas_por_jugador.erase(id)
		abandonadas.erase(id)  # «Reanudar» también devuelve a los colonos una obra abandonada
	else:
		pausadas_por_jugador[id] = true


func esta_pausada_por_jugador(id: int) -> bool:
	return pausadas_por_jugador.has(id)


## Una obra no se ofrece ni se trabaja mientras el jugador la tiene reclamada o pausada.
func _cedida(id: int) -> bool:
	return pausadas_por_jugador.has(id) or esta_reclamada(id)


## Una obra sin material se pausa; el aviso sale solo la primera vez que falta ese recurso.
func pausar(id: int, recurso: String, necesita: float = 0.0) -> void:
	if pausadas.get(id, "") != recurso:
		aviso.emit("Obra detenida: falta %s." % recurso)
	pausadas[id] = recurso
	_necesidades[id] = necesita


## Hay al menos "necesita" (y algo, si es 0) de ese recurso: lo que pide el paso que quedó pausado.
func _hay_recurso(recurso: String, necesita: float = 0.0) -> bool:
	var almacen: Dictionary = ciudad.almacen
	var minimo: float = maxf(necesita, 0.0001)
	if recurso == "madera":
		return almacen["tablas"].cantidad + almacen["madera"].cantidad >= minimo
	return almacen.has(recurso) and almacen[recurso].cantidad >= minimo


func _candidatas(tipo: String) -> Array[int]:
	var ids: Array[int] = []
	if mundo == null:
		return ids
	if tipo == "demoler":
		for id: int in marcados:
			if mundo.edificio_orden.has(id) and not _cedida(id) and not _es_del_nucleo(id):
				ids.append(id)
		return ids
	for id: int in mundo.edificio_orden:
		if marcados.has(id) or abandonadas.has(id) or _cedida(id):
			continue
		if mundo.edificio_progreso[id] >= mundo.edificio_orden[id].size():
			continue
		if pausadas.has(id) and not _hay_recurso(pausadas[id], _necesidades.get(id, 0.0)):
			continue
		ids.append(id)
	return ids


## true si hay alguna obra de construcción o demolición pendiente con materiales disponibles.
func hay_obras_pendientes() -> bool:
	return not _candidatas("construir").is_empty() or not _candidatas("demoler").is_empty()


## La tarea que le toca a un colono libre que está en "desde": primero construir,
## luego demoler; en cada grupo la obra más cercana (en empate, la de id menor).
## {} si no hay trabajo para él.
func siguiente_tarea(desde: Vector3i, id_colono: int = -1) -> Dictionary:
	for tipo in ["construir", "demoler"]:
		var mejor := -1
		var mejor_distancia := INF
		for id in _candidatas(tipo):
			if _vetada(id, id_colono):
				continue
			if colonos != null and colonos.obreros_en(id) >= 4:
				continue
			var distancia: float = Vector3(desde).distance_to(Vector3(mundo.edificio_a_celdas[id][0]))
			if distancia < mejor_distancia - 0.0001 or (absf(distancia - mejor_distancia) <= 0.0001 and id < mejor):
				mejor = id
				mejor_distancia = distancia
		if mejor != -1:
			return {"tipo": tipo, "id": mejor}
	return {}


## Columnas (x, z) del edificio: junto a ellas se para el colono. Vacío si no existe.
func huella_de(id: int) -> Array:
	var huella: Array = []
	if mundo == null or not mundo.edificio_a_celdas.has(id):
		return huella
	for celda: Vector3i in mundo.edificio_a_celdas[id]:
		var columna := Vector2i(celda.x, celda.z)
		if not huella.has(columna):
			huella.append(columna)
	return huella


## Id del edificio que tiene alguna celda en la columna "columna" (x, z), o -1.
func id_en_columna(columna: Vector2i) -> int:
	if mundo == null:
		return -1
	for id: int in mundo.edificio_a_celdas:
		for celda: Vector3i in mundo.edificio_a_celdas[id]:
			if celda.x == columna.x and celda.z == columna.y:
				return id
	return -1


## Datos para la ventana del edificio: nombre y tipo; estado ("demolicion" si está marcado,
## "construccion" si le faltan celdas, "completo"); si el jugador la pausó; salud (fracción
## construida, 0..1: 1.0 en un edificio completo) y los materiales que faltan para terminarlo
## (el costo de las celdas aún sin construir). {} si el edificio no existe.
func resumen_de(id: int) -> Dictionary:
	if mundo == null or not mundo.edificio_orden.has(id):
		return {}
	var orden: Array = mundo.edificio_orden[id]
	var progreso: int = mundo.edificio_progreso[id]
	var faltantes := {}
	for i in range(progreso, orden.size()):
		var costo: Dictionary = NiveladorTerrenoScript.COSTO_POR_CELDA.get(mundo.edificio_tipos[id][orden[i]], {})
		for recurso in costo:
			faltantes[recurso] = faltantes.get(recurso, 0) + costo[recurso]
	var estado := "completo"
	if demolicion_programada.has(id):
		estado = "demolicion_programada"
	elif marcados.has(id):
		estado = "demolicion"
	elif progreso < orden.size():
		estado = "construccion"
	var meta: Dictionary = mundo.edificio_metadata.get(id, {})
	var nombre := "Edificio %d" % id
	var tipo := "Edificio"
	if meta.has("puesto_nuevo") or meta.has("puesto"):
		var tipo_puesto: String = meta["puesto_nuevo"]["tipo"] if meta.has("puesto_nuevo") else Economia.puestos.get(meta["puesto"], {}).get("tipo", "")
		nombre = PanelPuestoScript.NOMBRES_PUESTO.get(tipo_puesto, nombre)
		tipo = "Puesto"
	elif meta.has("blueprint"):
		nombre = str(meta["blueprint"].get("nombre", nombre))
		tipo = str(meta["blueprint"].get("categoria", tipo)).capitalize()
	return {
		"nombre": nombre, "tipo": tipo, "estado": estado, "pausada": estado != "completo" and (pausadas_por_jugador.has(id) or abandonadas.has(id)),
		"salud": float(progreso) / maxf(float(orden.size()), 1.0), "faltantes": faltantes,
		"horas_demolicion": demolicion_programada.get(id, 0),
	}


## Celdas (Vector3i) del edificio; vacío si no existe. Lo usa MarcasDemolicionOverlay.
func celdas_de(id: int) -> Array:
	if mundo == null or not mundo.edificio_a_celdas.has(id):
		return []
	return mundo.edificio_a_celdas[id]


## Un paso de trabajo de un colono sobre la obra "id" ("construir" o "demoler").
## Devuelve {"estado", "espera"}: "avanzo" (sigue), "pausada" (falta material),
## "bloqueada" (alguien dentro), "completa" (terminó este edificio), "terminada"
## (no había nada que surtir) o "invalida" (el edificio ya no existe); "espera" es
## cuánto debe esperar el colono antes de volver a decidir.
func trabajar(id: int, tipo: String) -> Dictionary:
	if mundo == null or not mundo.edificio_orden.has(id):
		olvidar(id)
		return {"estado": "invalida", "espera": 0.0}
	# La tarea debe seguir vigente: si cambió la marca, el edificio quedó abandonado o pasó a ser el núcleo, se suelta.
	if tipo == "demoler":
		if not marcados.has(id):
			return {"estado": "invalida", "espera": 0.0}
		if _es_del_nucleo(id):
			olvidar(id)
			return {"estado": "invalida", "espera": 0.0}
	elif marcados.has(id) or abandonadas.has(id):
		return {"estado": "invalida", "espera": 0.0}
	if _cedida(id):
		return {"estado": "pausada", "espera": ESPERA_BLOQUEADA}  # el jugador la tiene o la pausó
	var celda: Vector3i = mundo.edificio_a_celdas[id][0]
	if tipo == "demoler":
		return _demoler_un_paso(id, celda)
	return _construir_un_paso(id, celda)


func _construir_un_paso(id: int, celda: Vector3i) -> Dictionary:
	var r: Dictionary = mundo.surtir_construccion(celda)
	if r.is_empty():
		return {"estado": "terminada", "espera": 0.0}
	if r.get("bloqueada", false):
		return {"estado": "bloqueada", "espera": ESPERA_BLOQUEADA}
	if r.get("insuficiente", false):
		pausar(id, r["recurso"], float(NiveladorTerrenoScript.COSTO_POR_CELDA.get(r["tipo"], {}).get(r["recurso"], 0)))
		return {"estado": "pausada", "espera": 0.0}
	pausadas.erase(id)
	if r.get("completa", false):
		var mensaje: String = al_completar.call(mundo, r["metadata"])
		if mensaje != "":
			aviso.emit(mensaje)
		return {"estado": "completa", "espera": 0.0}
	return {"estado": "avanzo", "espera": FinalizacionObras.intervalo_del_paso(mundo, celda)}


func _demoler_un_paso(id: int, celda: Vector3i) -> Dictionary:
	var r: Dictionary = mundo.procesar_deconstruccion(celda)
	if r.is_empty():
		olvidar(id)
		return {"estado": "invalida", "espera": 0.0}
	al_deconstruir.call(mundo, r)
	abandonar(id)  # si se desmarca ahora, queda a medias y los colonos no la reconstruyen
	if r["lista_para_remocion"]:
		al_retirar.call(mundo, id)
		olvidar(id)
		aviso.emit("Edificio demolido.")
		return {"estado": "completa", "espera": 0.0}
	return {"estado": "avanzo", "espera": FinalizacionObras.INTERVALO_PASO}

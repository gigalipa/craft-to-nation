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
const ConstructorViasScript = preload("res://scripts/ConstructorVias.gd")

## Cambió la marca de demolición de un edificio (la dibuja MarcasDemolicionOverlay).
signal marca_cambiada(id: int, marcado: bool)
## Mensaje para el jugador (Main lo envía al HUD).
signal aviso(texto: String)

## Señales de obras de tendido de vías (para overlays)
signal obra_via_creada(id_via: int)
signal obra_via_paso(id_via: int, celda: Vector3i)
signal obra_via_completada(id_via: int)

## Señales de demolición de vías
signal demolicion_via_creada(id_demolicion: int)
signal demolicion_via_paso(id_demolicion: int, celda: Vector3i)
signal demolicion_via_completada(id_demolicion: int)


const ESPERA_BLOQUEADA := 1.0  # s que espera un colono si hay alguien dentro de la obra
const DURACION_VETO_MS := 30000  # una obra a la que un colono no pudo llegar se le oculta ese tiempo
const DURACION_RECLAMO_MS := 3000  # tras actuar el jugador a mano sobre un edificio, los colonos se lo ceden ese tiempo

const PRIORIDAD_ALTA := 2
const PRIORIDAD_NORMAL := 1
const PRIORIDAD_BAJA := 0

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
var prioridades: Dictionary = {}  # id -> int (2=Alta, 1=Normal, 0=Baja; default 1)
var obras_vias: Dictionary = {}  # id_via (negativo) -> Dictionary de obra vial
var _siguiente_id_via: int = -1
var obras_demolicion_vias: Dictionary = {}  # id (< -10000) -> Dictionary de demolición de vía
var _siguiente_id_demolicion_via: int = -10000
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


## El edificio o la obra vial dejó de existir (o se retiró): borra todo rastro de él.
func olvidar(id: int) -> void:
	if id < 0:
		obras_vias.erase(id)
		obras_demolicion_vias.erase(id)
		prioridades.erase(id)
		_reclamos.erase(id)
		return
	var habia_m: bool = marcados.erase(id)
	var habia_p: bool = demolicion_programada.erase(id)
	var habia_marca: bool = habia_m or habia_p
	abandonadas.erase(id)
	pausadas.erase(id)
	_necesidades.erase(id)
	pausadas_por_jugador.erase(id)
	prioridades.erase(id)
	_reclamos.erase(id)
	if habia_marca:
		marca_cambiada.emit(id, false)



func fijar_prioridad(id: int, p: int) -> void:
	if p == PRIORIDAD_NORMAL:
		prioridades.erase(id)
	else:
		prioridades[id] = p


func prioridad_de(id: int) -> int:
	return prioridades.get(id, PRIORIDAD_NORMAL)


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


## true si hay alguna obra de construcción, demolición o vía pendiente con materiales disponibles.
func hay_obras_pendientes() -> bool:
	return not _candidatas("construir").is_empty() or not _candidatas("demoler").is_empty() or not obras_vias.is_empty() or not obras_demolicion_vias.is_empty()



## La tarea que le toca a un colono libre que está en "desde" según la jerarquía:
## 1. Construcción Alta (2)
## 2. Construcción Normal (1)
## 3. Demoliciones (edificios y vías)
## 4. Tendido de vías
## 5. Construcción Baja (0)
## En cada grupo la obra más cercana (en empate, la de id menor). {} si no hay trabajo.
func siguiente_tarea(desde: Vector3i, id_colono: int = -1) -> Dictionary:
	# 1. Construcción Alta
	var t_alta := _mejor_construccion(desde, id_colono, PRIORIDAD_ALTA)
	if not t_alta.is_empty():
		return t_alta

	# 2. Construcción Normal
	var t_normal := _mejor_construccion(desde, id_colono, PRIORIDAD_NORMAL)
	if not t_normal.is_empty():
		return t_normal

	# 3. Demoliciones
	var t_demoler := _mejor_demolicion(desde, id_colono)
	if not t_demoler.is_empty():
		return t_demoler

	# 4. Tendido de vías (se activa en Task 2)
	if has_method("siguiente_tarea_via"):
		var t_via: Dictionary = siguiente_tarea_via(desde, id_colono)
		if not t_via.is_empty():
			return t_via

	# 5. Construcción Baja
	var t_baja := _mejor_construccion(desde, id_colono, PRIORIDAD_BAJA)
	if not t_baja.is_empty():
		return t_baja

	return {}


func _mejor_construccion(desde: Vector3i, id_colono: int, p_filtro: int) -> Dictionary:
	var mejor := -1
	var mejor_distancia := INF
	for id in _candidatas("construir"):
		if prioridad_de(id) != p_filtro:
			continue
		if _vetada(id, id_colono):
			continue
		if colonos != null and colonos.obreros_en(id) >= 4:
			continue
		var distancia: float = Vector3(desde).distance_to(Vector3(mundo.edificio_a_celdas[id][0]))
		if distancia < mejor_distancia - 0.0001 or (absf(distancia - mejor_distancia) <= 0.0001 and id < mejor):
			mejor = id
			mejor_distancia = distancia
	if mejor != -1:
		return {"tipo": "construir", "id": mejor}
	return {}


func _mejor_demolicion(desde: Vector3i, id_colono: int) -> Dictionary:
	var mejor := -1
	var mejor_distancia := INF
	for id in _candidatas("demoler"):
		if _vetada(id, id_colono):
			continue
		if colonos != null and colonos.obreros_en(id) >= 4:
			continue
		var distancia: float = Vector3(desde).distance_to(Vector3(mundo.edificio_a_celdas[id][0]))
		if distancia < mejor_distancia - 0.0001 or (absf(distancia - mejor_distancia) <= 0.0001 and id < mejor):
			mejor = id
			mejor_distancia = distancia
	if mejor != -1:
		return {"tipo": "demoler", "id": mejor}
	if has_method("siguiente_tarea_demoler_via"):
		var t_dvia: Dictionary = siguiente_tarea_demoler_via(desde, id_colono)
		if not t_dvia.is_empty():
			return t_dvia
	return {}


## Columnas (x, z) del edificio o vía: junto a ellas se para el colono. Vacío si no existe.
func huella_de(id: int) -> Array:
	if id < 0:
		if obras_vias.has(id):
			return huella_via(id)
		if obras_demolicion_vias.has(id):
			var huella_dem: Array = []
			for c in obras_demolicion_vias[id]["celdas"]:
				var col := Vector2i(c.x, c.z)
				if not huella_dem.has(col):
					huella_dem.append(col)
			return huella_dem
		return []
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


## Celdas (Vector3i) del edificio o vía; vacío si no existe. Lo usa MarcasDemolicionOverlay.
func celdas_de(id: int) -> Array:
	if id < 0:
		if obras_vias.has(id):
			return celdas_pendientes_via(id)
		if obras_demolicion_vias.has(id):
			return obras_demolicion_vias[id]["celdas"]
		return []
	if mundo == null or not mundo.edificio_a_celdas.has(id):
		return []
	return mundo.edificio_a_celdas[id]


## Un paso de trabajo de un colono sobre la obra "id" ("construir", "demoler", "via_construir" o "via_demoler").
## Devuelve {"estado", "espera"}: "avanzo" (sigue), "pausada" (falta material),
## "bloqueada" (alguien dentro), "completa" (terminó este edificio), "terminada"
## (no había nada que surtir) o "invalida" (el edificio ya no existe); "espera" es
## cuánto debe esperar el colono antes de volver a decidir.
func trabajar(id: int, tipo: String) -> Dictionary:
	if id < 0:
		if _cedida(id):
			return {"estado": "pausada", "espera": ESPERA_BLOQUEADA}
		if tipo == "via_construir":
			return trabajar_via(id)
		elif tipo == "via_demoler":
			return trabajar_demoler_via(id)
		return {"estado": "invalida", "espera": 0.0}
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


## Busca si algún vértice o columna de un nuevo trazado conecta con una obra de vía incompleta.
## Devuelve el id_via si encuentra coincidencia, o 0 si no.
func buscar_obra_via_conectada(nuevos_vertices: Array, nuevas_columnas: Array = []) -> int:
	for id_via in obras_vias:
		var obra: Dictionary = obras_vias[id_via]
		for v in nuevos_vertices:
			if obra["vertices"].has(v):
				return id_via
		for c in nuevas_columnas:
			if obra["columnas"].has(c):
				return id_via
	return 0


## Registra una obra de vía a partir del plan devuelto por ConstructorVias.planificar().
## Si comparte vértices/columnas con una obra incompleta, se fusiona con ella (evita cuadrillas duplicadas).
## Devuelve el id_via asignado o fusionado (entero negativo).
func crear_obra_via(plan: Dictionary) -> int:
	if plan.is_empty() or plan.get("pasos", []).is_empty():
		return 0
	var id_existente: int = buscar_obra_via_conectada(plan["vertices"], plan.get("columnas", []))
	if id_existente != 0:
		var obra: Dictionary = obras_vias[id_existente]
		for v in plan["vertices"]:
			if not obra["vertices"].has(v):
				obra["vertices"].append(v)
		for c in plan.get("columnas", []):
			if not obra["columnas"].has(c):
				obra["columnas"].append(c)
		for p in plan["pasos"]:
			var existe := false
			for ep in obra["pasos"]:
				if ep["columna"] == p["columna"]:
					existe = true
					break
			if not existe:
				obra["pasos"].append(p)
		obra_via_creada.emit(id_existente)
		return id_existente

	var id_via := _siguiente_id_via
	_siguiente_id_via -= 1
	obras_vias[id_via] = {
		"id": id_via,
		"vertices": (plan["vertices"] as Array).duplicate(),
		"columnas": (plan.get("columnas", []) as Array).duplicate(),
		"pasos": (plan["pasos"] as Array).duplicate(),
		"pasos_completados": [],
		"celdas_soporte": []
	}
	obra_via_creada.emit(id_via)
	return id_via


## Ejecuta un paso de la obra de vía (la siguiente celda pendiente, o la apuntada si se especifica).
func trabajar_via(id_via: int, celda_apuntada: Vector3i = Vector3i.ZERO) -> Dictionary:
	if not obras_vias.has(id_via):
		return {"estado": "invalida", "espera": 0.0}
	var obra: Dictionary = obras_vias[id_via]
	if obra["pasos"].is_empty():
		obras_vias.erase(id_via)
		obra_via_completada.emit(id_via)
		return {"estado": "completa", "espera": 0.0}

	var paso: Dictionary = {}
	if celda_apuntada != Vector3i.ZERO:
		for i in range(obra["pasos"].size()):
			var p: Dictionary = obra["pasos"][i]
			if p["celda"] == celda_apuntada or (p["columna"].x == celda_apuntada.x and p["columna"].y == celda_apuntada.z):
				paso = obra["pasos"][i]
				obra["pasos"].remove_at(i)
				break
	if paso.is_empty():
		paso = obra["pasos"].pop_front()

	var c_soporte: Vector3i = ConstructorViasScript.ejecutar_paso(mundo, paso)
	obra["pasos_completados"].append(paso)
	obra["celdas_soporte"].append(c_soporte)
	obra_via_paso.emit(id_via, c_soporte)

	if obra["pasos"].is_empty():
		obras_vias.erase(id_via)
		obra_via_completada.emit(id_via)
		aviso.emit("Vía completada.")
		return {"estado": "completa", "espera": 0.0}
	return {"estado": "avanzo", "espera": FinalizacionObras.INTERVALO_PASO}


## Selecciona la mejor tarea de tendido de vía para un colono en "desde".
func siguiente_tarea_via(desde: Vector3i, id_colono: int = -1) -> Dictionary:
	var mejor := 0
	var mejor_distancia := INF
	for id_via in obras_vias:
		if _cedida(id_via):
			continue
		if _vetada(id_via, id_colono):
			continue
		if colonos != null and colonos.obreros_en(id_via) >= 4:
			continue
		var obra: Dictionary = obras_vias[id_via]
		if obra["pasos"].is_empty():
			continue
		var celda_paso: Vector3i = obra["pasos"][0]["celda"]
		var distancia: float = Vector3(desde).distance_to(Vector3(celda_paso))
		if distancia < mejor_distancia - 0.0001 or (absf(distancia - mejor_distancia) <= 0.0001 and (mejor == 0 or absi(id_via) < absi(mejor))):
			mejor = id_via
			mejor_distancia = distancia
	if mejor != 0:
		return {"tipo": "via_construir", "id": mejor}
	return {}


## Huella (columnas XZ) de las celdas pendientes de una obra de vía.
func huella_via(id_via: int) -> Array:
	var huella: Array = []
	if not obras_vias.has(id_via):
		return huella
	for paso in obras_vias[id_via]["pasos"]:
		if not huella.has(paso["columna"]):
			huella.append(paso["columna"])
	return huella


## Celdas 3D pendientes de una obra de vía.
func celdas_pendientes_via(id_via: int) -> Array[Vector3i]:
	var celdas_res: Array[Vector3i] = []
	if not obras_vias.has(id_via):
		return celdas_res
	for paso in obras_vias[id_via]["pasos"]:
		celdas_res.append(paso["celda"])
	return celdas_res


## Todas las celdas 3D con obra de vía pendiente (para el overlay wireframe).
func todas_las_celdas_obras_vias() -> Array[Vector3i]:
	var todas: Array[Vector3i] = []
	for id_via in obras_vias:
		for paso in obras_vias[id_via]["pasos"]:
			todas.append(paso["celda"])
	return todas


## Todas las celdas 3D con orden de demolición de vía pendiente (para el overlay outline de demolición).
func todas_las_celdas_demolicion_vias() -> Array[Vector3i]:
	var todas: Array[Vector3i] = []
	for id_dem in obras_demolicion_vias:
		for c in obras_demolicion_vias[id_dem]["celdas"]:
			todas.append(c)
	return todas


## Devuelve el id_via de la obra que contiene la columna "col", o 0 si ninguna.
func obra_via_en_columna(col: Vector2i) -> int:
	for id_via in obras_vias:
		for paso in obras_vias[id_via]["pasos"]:
			if paso["columna"] == col:
				return id_via
	return 0


## Crea una orden de demolición de un tramo de vía (celdas Vector3i).
func crear_demolicion_via(celdas_via: Array) -> int:
	if celdas_via.is_empty():
		return 0
	var id_dem := _siguiente_id_demolicion_via
	_siguiente_id_demolicion_via -= 1
	var celdas_limpias: Array[Vector3i] = []
	for c in celdas_via:
		if c is Vector3i:
			celdas_limpias.append(c)
	obras_demolicion_vias[id_dem] = {
		"id": id_dem,
		"celdas": celdas_limpias,
		"celdas_retiradas": []
	}
	demolicion_via_creada.emit(id_dem)
	return id_dem


## Trabaja un paso de demolición de vía: retira una celda de Vias.gd y cuñas de GridMap,
## sin tocar bloques de nivelación (tierra/roca base).
func trabajar_demoler_via(id_dem: int, celda_apuntada: Vector3i = Vector3i.ZERO) -> Dictionary:
	if not obras_demolicion_vias.has(id_dem):
		return {"estado": "invalida", "espera": 0.0}
	var obra: Dictionary = obras_demolicion_vias[id_dem]
	if obra["celdas"].is_empty():
		obras_demolicion_vias.erase(id_dem)
		demolicion_via_completada.emit(id_dem)
		return {"estado": "completa", "espera": 0.0}

	var celda: Vector3i = Vector3i.ZERO
	if celda_apuntada != Vector3i.ZERO:
		var idx: int = obra["celdas"].find(celda_apuntada)
		if idx != -1:
			celda = obra["celdas"][idx]
			obra["celdas"].remove_at(idx)
	if celda == Vector3i.ZERO:
		celda = obra["celdas"].pop_front()

	if mundo != null:
		var tipo: String = mundo.obtener_tipo(celda)
		if tipo.begins_with("cuna_"):
			mundo.set_cell_item(celda, -1)
			if mundo.get("colocado_por_jugador") != null:
				mundo.colocado_por_jugador.erase(celda)

	Vias.quitar([celda])
	obra["celdas_retiradas"].append(celda)
	demolicion_via_paso.emit(id_dem, celda)

	if obra["celdas"].is_empty():
		obras_demolicion_vias.erase(id_dem)
		demolicion_via_completada.emit(id_dem)
		if not esta_reclamada(id_dem):
			aviso.emit("Tramo de vía demolido.")
		return {"estado": "completa", "espera": 0.0}
	return {"estado": "avanzo", "espera": FinalizacionObras.INTERVALO_PASO}


## Selecciona la mejor tarea de demolición de vía para un colono.
func siguiente_tarea_demoler_via(desde: Vector3i, id_colono: int = -1) -> Dictionary:
	var mejor := 0
	var mejor_distancia := INF
	for id_dem in obras_demolicion_vias:
		if _cedida(id_dem):
			continue
		if _vetada(id_dem, id_colono):
			continue
		if colonos != null and colonos.obreros_en(id_dem) >= 4:
			continue
		var obra: Dictionary = obras_demolicion_vias[id_dem]
		if obra["celdas"].is_empty():
			continue
		var celda: Vector3i = obra["celdas"][0]
		var distancia: float = Vector3(desde).distance_to(Vector3(celda))
		if distancia < mejor_distancia - 0.0001 or (absf(distancia - mejor_distancia) <= 0.0001 and (mejor == 0 or absi(id_dem) < absi(mejor))):
			mejor = id_dem
			mejor_distancia = distancia
	if mejor != 0:
		return {"tipo": "via_demoler", "id": mejor}
	return {}


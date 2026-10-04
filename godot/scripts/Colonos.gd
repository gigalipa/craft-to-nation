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
## Una escuela graduó a una cohorte: "cantidad" colonos pasaron a técnico (el que sobraba se fue).
## ponytail: solo existe la escuela técnica; con la de especialistas se añadirá el tipo destino.
signal tecnicos_formados(cantidad: int)

## Valor centinela de "no hay celda": una celda imposible.
const INVALIDA := Vector3i(999999, 999999, 999999)

## Orden de preferencia de transporte de recursos en vías estrechas o atascos.
const ORDEN_PRIORIDAD_RECURSOS := [
	"comida",
	"combustible",
	"crudo",
	"acero",
	"mineral_refinado",
	"hierro",
	"cobre",
	"carbon",
	"tierras_raras",
	"tablas",
	"madera",
	"piedra",
	"tierra",
	"agua",
]

## Placeholders sin balance real.
const VELOCIDAD_COLONO := 2.5  # celdas por segundo
const ESPERA_ENTRE_DESTINOS_MIN := 1.0
const ESPERA_ENTRE_DESTINOS_MAX := 3.0
const ESPERA_BLOQUEO := 0.5  # segundos esperando antes de esquivar
const INTENTOS_DESTINO := 8
const INTENTOS_APARICION := 200
const PROBABILIDAD_CASA := 0.5  # de deambular hacia su hogar en vez de por la ciudad
const ESPERA_TRABAJO := 1.0  # segundos que espera un recolector/acarreador antes de volver a decidir
## Nodos de búsqueda de rutas que se reparten entre TODOS los colonos en cada llamada a
## avanzar() (~10 ms). La ruta a un puesto se busca por partes: una búsqueda larga o
## inalcanzable agota el tope de nodos (~0,5 s de golpe) y, con varios colonos
## reintentando, congelaba el juego.
const NODOS_POR_FRAME := 300
const FALLOS_PARA_VETAR := 3  # búsquedas fallidas seguidas hacia una obra antes de dejarla (a ese colono) un rato
const RADIO_SERVICIO := 2  # celdas (Chebyshev) alrededor de la celda de servicio de un puesto con puerta

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
		if economia != null:
			if economia.puesto_quitado.is_connected(_on_puesto_quitado):
				economia.puesto_quitado.disconnect(_on_puesto_quitado)
			if economia.trabajadores_liberados.is_connected(_on_trabajadores_liberados):
				economia.trabajadores_liberados.disconnect(_on_trabajadores_liberados)
			if economia.cohorte_graduada.is_connected(_on_cohorte_graduada):
				economia.cohorte_graduada.disconnect(_on_cohorte_graduada)
		economia = valor
		if valor != null:
			valor.puesto_quitado.connect(_on_puesto_quitado)
			valor.trabajadores_liberados.connect(_on_trabajadores_liberados)
			valor.cohorte_graduada.connect(_on_cohorte_graduada)

## Coordinador de obras (Obras en el juego): reparte la construcción y demolición a los colonos libres.
var obras: Object = null:
	set(valor):
		if obras != null and obras.has_signal("marca_cambiada") and obras.marca_cambiada.is_connected(_on_marca_cambiada):
			obras.marca_cambiada.disconnect(_on_marca_cambiada)
		obras = valor
		if obras != null:
			if obras.get("colonos") == null:
				obras.colonos = self
			if obras.has_signal("marca_cambiada") and not obras.marca_cambiada.is_connected(_on_marca_cambiada):
				obras.marca_cambiada.connect(_on_marca_cambiada)

## id -> {"id", "tipo", "hogar", "celda", "posicion", "ruta", "progreso",
## "moviendo", "espera", "bloqueo", "trabajo", "tarea", "carga", "fase", "fallos_servicio"}. "fase" del acarreador:
## "" (decide), "recoger"/"entregar" (puesto de recolección) o, en una refinería, "cargar", "entrada",
## "salida" y "entregar". "celda" es la celda donde está parado;
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
var _nodos_libres := 0  # lo que queda del presupuesto NODOS_POR_FRAME en esta llamada a avanzar()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if ciudad == null:
		ciudad = Ciudad
	if zona == null:
		zona = Zonificacion
	if economia == null:
		economia = Economia
	if obras == null:
		obras = Obras
	elif obras != null:
		if obras.colonos == null:
			obras.colonos = self
		if obras.has_signal("marca_cambiada") and not obras.marca_cambiada.is_connected(_on_marca_cambiada):
			obras.marca_cambiada.connect(_on_marca_cambiada)
	if ciudad != null:
		if not ciudad.tick_simulado.is_connected(reconciliar):
			ciudad.tick_simulado.connect(reconciliar)
		if ciudad.has_signal("nucleo_reasignado") and not ciudad.nucleo_reasignado.is_connected(_on_nucleo_reasignado):
			ciudad.nucleo_reasignado.connect(_on_nucleo_reasignado)


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
		"trabajo": {}, "tarea": {}, "carga": {}, "fase": "", "fallos_servicio": 0,
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


## Ids de los colonos de ese tipo que no trabajan en ningún puesto.
func _ids_sin_puesto(tipo: String) -> Array[int]:
	var ids: Array[int] = []
	for id in _ids_de_tipo(tipo):
		if colonos[id]["trabajo"].is_empty():
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


func _on_nucleo_reasignado(nuevo_id: int, id_viejo: int) -> void:
	mudar_residentes(nuevo_id, id_viejo)
	reconciliar()
	_reasignar_hogares()


func mudar_residentes(de_hogar: int, a_hogar: int) -> void:
	for c in colonos.values():
		if c.get("hogar", -1) == de_hogar:
			c["hogar"] = a_hogar


func residentes_en(hogar_id: int) -> Dictionary:
	var conteo: Dictionary = {}
	for c in colonos.values():
		if c.get("hogar", -1) == hogar_id:
			var tipo: String = c.get("tipo", "")
			conteo[tipo] = conteo.get(tipo, 0) + 1
	return conteo


func avanzar(delta: float) -> void:
	if _buscador == null:
		return
	_nodos_libres = NODOS_POR_FRAME
	for c in colonos.values():
		_avanzar_colono(c, delta)


func _avanzar_colono(c: Dictionary, delta: float) -> void:
	if c["moviendo"]:
		_completar_paso(c, delta)
		return
	if c["evacuando"] != -1:
		c["busqueda"] = {}  # la búsqueda en curso partió de una celda que dejará de ser la suya
		_avanzar_evacuacion(c, delta)
		return
	if c["espera"] > 0.0:
		if c["trabajo"].is_empty() and c["tarea"].is_empty() and (c["tipo"] == "desempleado" or c["tipo"] == "obrero" or c["tipo"] == "tecnico"):
			if obras != null and obras.has_method("hay_obras_pendientes") and obras.hay_obras_pendientes():
				c["espera"] = 0.0
			else:
				c["espera"] -= delta
				return
		else:
			c["espera"] -= delta
			return
	if not c.get("busqueda", {}).is_empty():
		_avanzar_busqueda(c)  # sigue buscando el camino que empezó en un fotograma anterior
		return
	if c["ruta"].is_empty():
		if c["trabajo"].is_empty():
			_decidir_ocioso(c)
		else:
			_decidir_trabajo(c)
		return
	if c["trabajo"].is_empty() and c["tarea"].is_empty() and (c["tipo"] == "desempleado" or c["tipo"] == "obrero" or c["tipo"] == "tecnico"):
		if obras != null and obras.has_method("hay_obras_pendientes") and obras.hay_obras_pendientes():
			var tarea: Dictionary = obras.siguiente_tarea(c["celda"], c["id"])
			if not tarea.is_empty():
				var vacia: Array[Vector3i] = []
				c["ruta"] = vacia
				c["tarea"] = tarea
				_trabajar_en_obra(c)
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
		var otro_id: int = ocupadas.get(siguiente, -1)
		if otro_id != -1 and colonos.has(otro_id):
			var otro: Dictionary = colonos[otro_id]
			if not otro["moviendo"] and _tiene_prioridad(c, otro):
				if _apartar_a_lado(otro, c["celda"]):
					pass  # celda despejada: continúa y la toma abajo
				elif _ceder_paso(c, otro):
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
	var soporte: Vector3i = c["celda"] + Vector3i(0, -1, 0)
	c["progreso"] += delta * VELOCIDAD_COLONO * Vias.bono_en(soporte)
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
	c["busqueda"] = {}
	if c["ruta"].is_empty() and c["trabajo"].is_empty() and c["tarea"].is_empty():
		c["espera"] = _rng.randf_range(ESPERA_ENTRE_DESTINOS_MIN, ESPERA_ENTRE_DESTINOS_MAX)


## La llama Player.gd en cada frame de física con la celda donde está y su
## velocidad. Si se mueve (más de 0.5 celdas/s horizontales), la celda de
## adelante, en el sentido dominante de la velocidad, también cuenta.
func actualizar_avatar(celda: Vector3i, velocidad: Vector3) -> void:
	celdas_avatar.clear()
	celdas_avatar[celda] = true
	var horizontal := Vector2(velocidad.x, velocidad.z)
	if horizontal.length() > 0.5:
		if absf(horizontal.x) > absf(horizontal.y):
			celdas_avatar[celda + Vector3i(int(signf(horizontal.x)), 0, 0)] = true
		else:
			celdas_avatar[celda + Vector3i(0, 0, int(signf(horizontal.y)))] = true
	for celda_avatar in celdas_avatar:
		_empujar_de(celda_avatar)


## El avatar empuja a un colono quieto que esté en su celda a una celda libre vecina (decisión
## del usuario, 2026-10-02: el jugador empuja a los colonos y ellos lo esquivan, nunca al revés).
## Los que caminan no hacen falta: su siguiente paso ya evita las celdas del avatar.
func _empujar_de(celda: Vector3i) -> void:
	var id: int = ocupadas.get(celda, -1)
	if id == -1 or not colonos.has(id) or colonos[id]["moviendo"] or colonos[id]["celda"] != celda:
		return
	for direccion in BuscadorRutas.DIRECCIONES:
		var destino: Vector3i = celda + direccion
		if not _buscador.es_transitable(destino) or _ocupada_por_otro(destino, id):
			continue
		var c: Dictionary = colonos[id]
		ocupadas.erase(celda)
		ocupadas[destino] = id
		c["celda"] = destino
		c["posicion"] = _centro_de(destino)
		c["ruta"] = []
		c["busqueda"] = {}
		c["espera"] = 0.0
		if not c["trabajo"].is_empty():
			economia.marcar_presente(id, false)
		return


## Calcula los factores de prioridad de un colono para resolver atascos en la vía:
## Tier 4: Acarreador con carga (según prioridad de recurso y cantidad).
## Tier 3: Acarreador sin carga (en viaje de transporte).
## Tier 2: Colono con empleo o tarea activa de obra.
## Tier 1: Colono ocioso / esperando / deambulando.
func _prioridad_colono(c: Dictionary) -> Dictionary:
	var tier := 1
	var indice_recurso := 999
	var cantidad := 0.0

	if not c.get("carga", {}).is_empty():
		tier = 4
		for rec in c["carga"]:
			var cant: float = float(c["carga"][rec])
			var idx: int = ORDEN_PRIORIDAD_RECURSOS.find(rec)
			if idx == -1:
				idx = 900
			if idx < indice_recurso or (idx == indice_recurso and cant > cantidad):
				indice_recurso = idx
				cantidad = cant
	elif c.get("trabajo", {}).get("rol", "") == "acarreador":
		tier = 3
	elif not c.get("trabajo", {}).is_empty() or not c.get("tarea", {}).is_empty():
		tier = 2
	else:
		tier = 1

	return {"tier": tier, "recurso": indice_recurso, "cantidad": cantidad, "id": c.get("id", 0)}


## true si c1 tiene mayor preferencia que c2 para avanzar primero.
func _tiene_prioridad(c1: Dictionary, c2: Dictionary) -> bool:
	var p1: Dictionary = _prioridad_colono(c1)
	var p2: Dictionary = _prioridad_colono(c2)
	if p1["tier"] != p2["tier"]:
		return p1["tier"] > p2["tier"]
	if p1["tier"] == 4:
		if p1["recurso"] != p2["recurso"]:
			return p1["recurso"] < p2["recurso"]  # menor índice en la lista = mayor prioridad
		if not is_equal_approx(p1["cantidad"], p2["cantidad"]):
			return p1["cantidad"] > p2["cantidad"]
		return p1["id"] < p2["id"]
	if p1["tier"] == 3:
		return p1["id"] < p2["id"]
	return false  # entre peatones del mismo nivel sin carga se esquivan normalmente



## Intenta apartar a un colono quieto a una celda libre adyacente,
## dejando libre el paso hacia la celda que quiere pisar el colono prioritario.
func _apartar_a_lado(otro: Dictionary, celda_evitar: Vector3i) -> bool:
	if otro["moviendo"]:
		return false
	for direccion in BuscadorRutas.DIRECCIONES:
		var destino: Vector3i = otro["celda"] + direccion
		if destino == celda_evitar:
			continue
		if not _buscador.es_transitable(destino) or _ocupada_por_otro(destino, otro["id"]):
			continue
		ocupadas.erase(otro["celda"])
		ocupadas[destino] = otro["id"]
		otro["celda"] = destino
		otro["posicion"] = _centro_de(destino)
		otro["ruta"] = []
		otro["busqueda"] = {}
		otro["espera"] = 0.0
		if not otro["trabajo"].is_empty():
			economia.marcar_presente(otro["id"], false)
		return true
	return false


## En pasillos o caminos de 1 bloque sin desvíos laterales:
## El colono de mayor prioridad "c" avanza a "siguiente", y "otro" le cede
## el paso intercambiando posición hacia la celda que "c" deja libre.
func _ceder_paso(c: Dictionary, otro: Dictionary) -> bool:
	if otro["moviendo"]:
		return false
	var celda_c: Vector3i = c["celda"]
	var celda_otro: Vector3i = otro["celda"]

	ocupadas[celda_c] = otro["id"]
	ocupadas[celda_otro] = c["id"]

	c["celda"] = celda_otro
	c["posicion"] = _centro_de(celda_otro)
	c["ruta"].pop_front()
	c["bloqueo"] = 0.0
	c["busqueda"] = {}
	if not c["trabajo"].is_empty():
		economia.marcar_presente(c["id"], false)

	otro["celda"] = celda_c
	otro["posicion"] = _centro_de(celda_c)
	otro["bloqueo"] = 0.0
	otro["busqueda"] = {}
	if not otro["ruta"].is_empty() and otro["ruta"][0] == celda_c:
		otro["ruta"].pop_front()
	elif not otro["ruta"].is_empty():
		_replanificar(otro)
	if not otro["trabajo"].is_empty():
		economia.marcar_presente(otro["id"], false)

	if c["ruta"].is_empty() and c["trabajo"].is_empty() and c["tarea"].is_empty():
		c["espera"] = _rng.randf_range(ESPERA_ENTRE_DESTINOS_MIN, ESPERA_ENTRE_DESTINOS_MAX)
	if otro["ruta"].is_empty() and otro["trabajo"].is_empty() and otro["tarea"].is_empty():
		otro["espera"] = _rng.randf_range(ESPERA_ENTRE_DESTINOS_MIN, ESPERA_ENTRE_DESTINOS_MAX)

	return true



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
	despertar_ociosos()


func _on_marca_cambiada(_id: int, _marcado: bool) -> void:
	despertar_ociosos()


## Cancela el deambular o la espera de los colonos libres para que puedan tomar
## obras de inmediato cuando se emplaza una construcción o se marca una demolición.
func despertar_ociosos() -> void:
	for c in colonos.values():
		if c["trabajo"].is_empty() and c["tarea"].is_empty() and (c["tipo"] == "desempleado" or c["tipo"] == "obrero" or c["tipo"] == "tecnico"):
			_dejar_lo_que_hacia(c)



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
	var opciones := _opciones_ruta(c)
	opciones["max_nodos"] = TOPE_NODOS_DESTINO
	var ruta: Array[Vector3i] = _buscador.buscar_salida(c["celda"], esta_dentro, opciones)
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
	var nueva: Array[Vector3i] = _buscador.buscar_ruta(c["celda"], destino, {"ignorar_fantasmas": _ignorar_de(c), "max_nodos": TOPE_NODOS_DESTINO})
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
	var opciones := _opciones_ruta(c)
	opciones["max_nodos"] = TOPE_NODOS_DESTINO
	var nueva: Array[Vector3i] = _buscador.buscar_ruta(c["celda"], destino, opciones)
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


## Tope de nodos para las búsquedas LOCALES: el deambular exploratorio de
## _elegir_destino() (casa o zona de influencia), rodear a otro colono
## (_esquivar()), replanificar (_replanificar()) y evacuar una obra. No hace falta el
## tope general de BuscadorRutas.MAX_NODOS_EXPANDIDOS (cruzar el mapa): con él, una
## búsqueda que falla (destino inalcanzable, o una puerta de 1 celda atascada por
## otros colonos) recorre todo el mundo y cuesta ~0,5 s cada vez, y con varios
## colonos a la vez se sentía como un freeze cada pocos segundos.
const TOPE_NODOS_DESTINO := 2500

## Elige el siguiente destino: la mitad de las veces su casa (si tiene), el
## resto un punto de la zona de influencia. Prueba INTENTOS_DESTINO veces hasta
## dar con uno alcanzable; si no, espera y reintenta.
func _elegir_destino(c: Dictionary) -> void:
	if not _recuperar_si_atrapado(c):
		return
	var a_casa: bool = c["hogar"] != -1 and _rng.randf() < PROBABILIDAD_CASA
	var grupos: Array = []
	for i in range(INTENTOS_DESTINO):
		var destino: Vector3i = _candidato_en_casa(c["hogar"]) if a_casa else _candidato_exterior()
		if destino != INVALIDA:
			grupos.append([destino])
	# Un destino tras otro (cada uno es un grupo de una celda), repartido entre fotogramas.
	c["busqueda"] = {"grupos": grupos, "actual": null, "tope": TOPE_NODOS_DESTINO, "deambular": true}
	_avanzar_busqueda(c)


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


## Contrata a un colono para un puesto con un rol. Para "recolector", "aprendiz" y "acarreador" toma
## a un desempleado (el de id menor) y lo pasa a obrero en Ciudad.demografia y en el colono. Para
## "tecnico" y "especialista" toma a un libre de ese oficio (el de id menor): ya tiene su oficio, así que no
## cambia de tipo ni la demografía; un desempleado nunca se convierte en técnico ni en especialista, hay que
## formarlo. Falso si no hay candidato, el puesto no existe, el rol no es de ese puesto, no tiene cupo o su nivel
## no admite ese oficio (en ese caso no se toca nada).
func contratar(esquina: Vector2i, rol: String) -> bool:
	if rol == "investigador":
		var candidatos_inv: Array[int] = _ids_sin_puesto("investigador")
		var es_nuevo_investigador := false
		if candidatos_inv.is_empty():
			candidatos_inv = _ids_sin_puesto("especialista")
			es_nuevo_investigador = true
		if candidatos_inv.is_empty():
			return false
		candidatos_inv.sort()
		var id_inv: int = candidatos_inv[0]
		if not economia.asignar(esquina, rol, id_inv):
			return false
		if es_nuevo_investigador:
			ciudad.reasignar_tipo("especialista", "investigador")
		var c_inv: Dictionary = colonos[id_inv]
		c_inv["tipo"] = "investigador"
		c_inv["trabajo"] = {"puesto": esquina, "rol": rol}
		c_inv["fase"] = ""
		c_inv["carga"] = {}
		c_inv["fallos_servicio"] = 0
		_dejar_lo_que_hacia(c_inv)
		return true
	var origen: String = Recoleccion.ESCUELAS.get(economia.puestos.get(esquina, {}).get("tipo", ""), {}).get("origen", "") if rol == "aprendiz" else ""
	var oficio: String = origen if origen == "tecnico" else (rol if rol == "tecnico" or rol == "especialista" else "")
	var candidatos: Array[int] = _ids_sin_puesto(oficio) if not oficio.is_empty() else _ids_de_tipo("desempleado")
	if candidatos.is_empty():
		return false
	candidatos.sort()
	var id: int = candidatos[0]
	if not economia.asignar(esquina, rol, id):
		return false
	if oficio.is_empty():
		ciudad.reasignar_tipo("desempleado", "obrero")
	var c: Dictionary = colonos[id]
	c["tipo"] = oficio if not oficio.is_empty() else "obrero"
	c["trabajo"] = {"puesto": esquina, "rol": rol}
	c["fase"] = ""
	c["carga"] = {}
	c["fallos_servicio"] = 0
	_dejar_lo_que_hacia(c)
	return true


## Técnicos sin puesto (formados en una escuela y todavía sin empleo).
func tecnicos_libres() -> int:
	return _ids_sin_puesto("tecnico").size()


## Especialistas sin puesto (hoy ninguno: la escuela de especialistas todavía no existe).
func especialistas_libres() -> int:
	return _ids_sin_puesto("especialista").size()


## Investigadores sin puesto (formados a partir de especialistas).
func investigadores_libres() -> int:
	return _ids_sin_puesto("investigador").size()


## Despide al último colono contratado con ese rol en el puesto; queda sin
## puesto y pierde lo que llevara. Falso si no hay ninguno.
func despedir(esquina: Vector2i, rol: String) -> bool:
	var id: int = economia.ultimo_de(esquina, rol)
	if id == -1 or not colonos.has(id):
		return false
	economia.liberar(id)
	_quedar_sin_puesto(colonos[id])
	return true


## El puesto se quitó (se deconstruyó): sus trabajadores ya fueron liberados en
## Economia; aquí solo quedan sin puesto. Conectada a Economia.puesto_quitado.
func _on_puesto_quitado(ids: Array) -> void:
	for id in ids:
		if colonos.has(id):
			_quedar_sin_puesto(colonos[id])


## Trabajadores liberados de un puesto que sigue en pie (agotado o desactivado):
## quedan sin puesto, salvo un acarreador que lleva carga (producto o insumo), que
## primero termina el viaje y la entrega en el núcleo (ver _decidir_trabajo()).
func _on_trabajadores_liberados(ids: Array) -> void:
	for id in ids:
		if not colonos.has(id):
			continue
		var c: Dictionary = colonos[id]
		if not c["carga"].is_empty():
			c["fase"] = "entregar"
			c["retirar_al_entregar"] = true
		else:
			_quedar_sin_puesto(c)


## Una escuela graduó a su cohorte (Economia.cohorte_graduada; los ids ya están libres): de cada
## x_cama[origen] colonos salen x_cama[destino] del tipo destino (los de id menor, ya sin puesto) y
## el resto se va de la ciudad; así la vivienda ocupada se conserva y nadie queda desahuciado.
func _on_cohorte_graduada(esquina: Vector2i, ids: Array) -> void:
	var escuela: Dictionary = Recoleccion.ESCUELAS[economia.puestos[esquina]["tipo"]]
	var salen: int = ciudad.TIPOS_POBLACION[escuela["destino"]]["x_cama"]
	var graduados := 0
	var ordenados: Array = ids.duplicate()
	ordenados.sort()
	for id in ordenados:
		if not colonos.has(id):
			continue  # ya no existe (p. ej. lo retiró una hambruna en el mismo tick)
		# Si una hambruna/desahucio ya bajó la demografía de origen (reconciliar() aún no retiró al colono), no hay a quién convertir: se retira sin tocar la demografía.
		if graduados < salen and ciudad.reasignar_tipo(escuela["origen"], escuela["destino"]):
			var c: Dictionary = colonos[id]
			c["tipo"] = escuela["destino"]
			c["trabajo"] = {}
			c["carga"] = {}
			c["fase"] = ""
			c["fallos_servicio"] = 0
			_dejar_lo_que_hacia(c)
			graduados += 1
		else:
			if graduados >= salen and ciudad.demografia[escuela["origen"]] > 0:
				ciudad.demografia[escuela["origen"]] -= 1
			_retirar(id)
	if graduados > 0:
		tecnicos_formados.emit(graduados)


## El colono deja su puesto. Un técnico o un especialista conserva su oficio y queda libre; cualquier otro
## vuelve a desempleado. Pierde lo que llevara (salvo el insumo de refinería en fase "entrada").
func _quedar_sin_puesto(c: Dictionary) -> void:
	var tipo_previo: String = c["tipo"]
	# Solo el insumo de refinería (fase "entrada", ya retirado del stock) se devuelve; el resto de la carga se pierde, para que despedir no teletransporte recursos al stock.
	if c["fase"] == "entrada" and not c["carga"].is_empty():
		economia.entregar(c["carga"])
	c["trabajo"] = {}
	c["carga"] = {}
	c["fase"] = ""
	c["fallos_servicio"] = 0
	c["retirar_al_entregar"] = false
	if tipo_previo != "tecnico" and tipo_previo != "especialista" and tipo_previo != "investigador":
		c["tipo"] = "desempleado"
		ciudad.reasignar_tipo(tipo_previo, "desempleado")
	_dejar_lo_que_hacia(c)


## Abandona la ruta en curso (si no está a medio paso) para que el colono
## decida de nuevo con su oficio nuevo o sin él.
func _dejar_lo_que_hacia(c: Dictionary) -> void:
	c["tarea"] = {}
	c["busqueda"] = {}
	if c["moviendo"] or c["evacuando"] != -1:
		return  # termina el paso o la evacuación y decide después
	var vacia: Array[Vector3i] = []
	c["ruta"] = vacia
	c["espera"] = 0.0


## Colonos que ahora mismo tienen como tarea la obra "id" (para la ventana del edificio).
func obreros_en(id: int) -> int:
	var total := 0
	for c in colonos.values():
		if not c["tarea"].is_empty() and c["tarea"]["id"] == id:
			total += 1
	return total


## Un colono libre (desempleado, o técnico sin puesto) ayuda en las obras: toma la tarea que le
## ofrece Obras (construir o demoler lo más cercano) y la sigue hasta que se acaba; sin obras
## deambula. Un colono con puesto ni pasa por aquí.
func _decidir_ocioso(c: Dictionary) -> void:
	if obras != null and (c["tipo"] == "desempleado" or c["tipo"] == "obrero" or c["tipo"] == "tecnico"):
		if c["tarea"].is_empty():
			c["tarea"] = obras.siguiente_tarea(c["celda"], c["id"])
		if not c["tarea"].is_empty():
			_trabajar_en_obra(c)
			return
	_elegir_destino(c)


## Va junto a la obra de su tarea y, ya allí, hace un paso (el tiempo que dure el paso es la
## espera). Suelta la tarea si la obra se acabó, no existe o no se puede alcanzar.
func _trabajar_en_obra(c: Dictionary) -> void:
	var tarea: Dictionary = c["tarea"]
	var huella: Array = obras.huella_de(tarea["id"])
	if huella.is_empty():
		c["tarea"] = {}  # la obra ya no existe
		return
	if not _junto_a(c["celda"], huella):
		if c["fallos_servicio"] >= FALLOS_PARA_VETAR:
			obras.vetar(tarea["id"], c["id"])
			c["tarea"] = {}
			c["fallos_servicio"] = 0
			return
		_ir_junto_a(c, huella)
		return
	var resultado: Dictionary = obras.trabajar(tarea["id"], tarea["tipo"])
	c["espera"] = resultado["espera"]
	match resultado["estado"]:
		"avanzo":
			pass
		"bloqueada":
			pass  # alguien está saliendo de la obra: espera y reintenta
		_:
			c["tarea"] = {}  # pausada, completa, terminada o inválida: pide otra tarea
			if resultado["estado"] == "pausada":
				c["espera"] = ESPERA_TRABAJO


## Lo que hace un trabajador cuando está quieto, sin ruta ni espera: un
## recolector o técnico va a su puesto y se queda (presente); un acarreador cicla
## puesto -> núcleo -> puesto (en una refinería, ver _decidir_acarreo_refineria()).
func _decidir_trabajo(c: Dictionary) -> void:
	if not _recuperar_si_atrapado(c):
		return
	if c.get("retirar_al_entregar", false):
		# Ya no trabaja en el puesto (agotado o desactivado), pero termina su viaje.
		if _llevar_al_nucleo(c):
			_quedar_sin_puesto(c)
		return
	var esquina: Vector2i = c["trabajo"]["puesto"]
	var huella_puesto: Array = economia.huella_de(esquina)
	if huella_puesto.is_empty():
		c["espera"] = ESPERA_TRABAJO  # el puesto ya no existe: Economia avisará
		return
	var servicio: Vector2i = economia.servicio_de(esquina)
	var suelo: int = economia.suelo_de(esquina)
	if c["trabajo"]["rol"] != "acarreador":
		if _en_puesto(c["celda"], huella_puesto, servicio, suelo):
			economia.marcar_presente(c["id"], true)
			c["espera"] = ESPERA_TRABAJO
			if not huella_puesto.has(Vector2i(c["celda"].x, c["celda"].z)):
				# Espera fuera: si mientras tanto se libera un sitio dentro, entra.
				_ir_junto_a(c, huella_puesto, servicio, _celdas_interiores(huella_puesto, suelo, servicio), true)
		else:
			_ir_junto_a(c, huella_puesto, servicio, _celdas_interiores(huella_puesto, suelo, servicio))
		return
	if economia.es_refineria(esquina):
		_decidir_acarreo_refineria(c, esquina, huella_puesto, servicio, economia.salida_de(esquina))
		return
	if c["fase"] == "entregar":
		if _llevar_al_nucleo(c):
			c["fase"] = "recoger"
		return
	# fase "" o "recoger": ir al puesto y pedir la carga.
	if not _en_puesto(c["celda"], huella_puesto, servicio, suelo):
		_ir_junto_a(c, huella_puesto, servicio, _celdas_interiores(huella_puesto, suelo, servicio))
		return
	var carga: Dictionary = economia.recoger(esquina, economia.CAPACIDAD_CARGA)
	if carga.is_empty():
		c["espera"] = ESPERA_TRABAJO  # todavía no hay carga (o nada que llevar)
		return
	c["carga"] = carga
	c["fase"] = "entregar"


## Acarreador de una refinería: núcleo (retira insumo) -> entrada (lo deja) -> salida (recoge el
## producto) -> núcleo (lo entrega). La fase "" decide si vale la pena un viaje: retirar insumo si
## hay al menos Economia.CARGA_MINIMA que llevar (rellena por adelantado) o si a la refinería no le
## alcanza para producir y hay algo que llevarle (Economia.conviene_cargar()), o recoger producto si
## hay al menos esa cantidad acumulada; si no, espera donde está, sin viajar en vacío.
func _decidir_acarreo_refineria(c: Dictionary, esquina: Vector2i, huella: Array, entrada: Vector2i, salida: Vector2i) -> void:
	match c["fase"]:
		"entregar":
			if _llevar_al_nucleo(c):
				c["fase"] = ""
		"cargar":
			var nucleo: Array = zona.huella_del_nucleo()
			if not _junto_a(c["celda"], nucleo):
				_ir_junto_a(c, nucleo)
				return
			c["carga"] = economia.cargar_insumo(esquina)
			c["fase"] = "entrada" if not c["carga"].is_empty() else ""
		"entrada":
			if not _junto_a(c["celda"], huella, entrada):
				_ir_junto_a(c, huella, entrada)
				return
			economia.descargar_insumo(esquina, c["carga"])
			c["carga"] = {}
			c["fase"] = "salida"
		"salida":
			if not _junto_a(c["celda"], huella, salida):
				_ir_junto_a(c, huella, salida)
				return
			c["carga"] = economia.recoger_producto(esquina, economia.CAPACIDAD_CARGA)
			c["fase"] = "entregar" if not c["carga"].is_empty() else ""
			if c["carga"].is_empty():
				c["espera"] = ESPERA_TRABAJO
		_:
			if economia.conviene_cargar(esquina):
				c["fase"] = "cargar"
			elif economia.producto_pendiente(esquina) >= economia.CARGA_MINIMA:
				c["fase"] = "salida"
			else:
				c["espera"] = ESPERA_TRABAJO


## Un paso hacia el núcleo urbano con la carga del colono: si ya está junto a él,
## la entrega y devuelve true; si no, planifica la ruta y devuelve false.
func _llevar_al_nucleo(c: Dictionary) -> bool:
	var huella_nucleo: Array = zona.huella_del_nucleo()
	if _junto_a(c["celda"], huella_nucleo):
		economia.entregar(c["carga"])
		c["carga"] = {}
		return true
	_ir_junto_a(c, huella_nucleo)
	return false


## true si el colono está "en el puesto": dentro del edificio (piso interior, a
## la altura "suelo" de su plantilla) o, si no cupo dentro, en la zona de servicio
## junto a la puerta (ver _junto_a()).
func _en_puesto(celda: Vector3i, huella: Array, servicio: Vector2i, suelo: int) -> bool:
	if suelo != economia.SIN_SUELO and huella.has(Vector2i(celda.x, celda.z)):
		# Parado en la puerta no cuenta (taponaría la entrada): solo el piso libre interior.
		if celda.y != suelo or mundo.obtener_tipo(celda) != "":
			return false
		# Tampoco la celda pegada a la puerta por dentro (el vestíbulo), salvo que sea el único
		# sitio libre del edificio: quien se detenga ahí a medio camino impediría entrar a los demás.
		if _es_vestibulo(celda, huella, servicio):
			return _celdas_interiores(huella, suelo, servicio).size() <= 1
		return true
	return _junto_a(celda, huella, servicio)


## true si "celda" está dentro del edificio, pegada (a 1 celda) a la puerta que da a "servicio".
func _es_vestibulo(celda: Vector3i, huella: Array, servicio: Vector2i) -> bool:
	var puerta := _puerta_xz(huella, servicio)
	return puerta != Vector2i.MAX and absi(celda.x - puerta.x) + absi(celda.z - puerta.y) <= 1


## Columna (X, Z) de la puerta: la de la huella pegada a la celda de servicio; MAX si no hay.
func _puerta_xz(huella: Array, servicio: Vector2i) -> Vector2i:
	if servicio == Vector2i.MAX:
		return Vector2i.MAX
	for direccion in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if huella.has(servicio + direccion):
			return servicio + direccion
	return Vector2i.MAX


## true si desde la celda frente a la puerta (X, Z "servicio") se puede pasar a la
## puerta del edificio, a la altura "suelo". Comprobación local y barata: sin ella,
## buscar una ruta a un interior cuya entrada es inalcanzable (p. ej. el suelo de
## afuera queda muy por encima de la puerta) recorre todo el mundo hasta el tope de
## nodos cada vez, y con varios colonos reintentando eso congela el juego.
func _entrada_practicable(servicio: Vector2i, suelo: int) -> bool:
	var altura: int = mundo.altura_en(servicio.x, servicio.y)
	if altura < 0:
		return false
	var frente := Vector3i(servicio.x, altura + 1, servicio.y)
	if not _buscador.es_transitable(frente):
		return false
	for vecina in _buscador.vecinos(frente):
		if vecina.y == suelo and mundo.obtener_tipo(vecina) == "puerta_inferior":
			return true
	return false


## Celdas libres y transitables del piso interior (altura "suelo") del edificio de
## un puesto: donde entran a trabajar los colonos. Sin las de bloque (puerta,
## baúl, pared). [] si el puesto no tiene plantilla o su entrada no es practicable.
func _celdas_interiores(huella: Array, suelo: int, servicio: Vector2i) -> Array[Vector3i]:
	var celdas: Array[Vector3i] = []
	if suelo == economia.SIN_SUELO or servicio == Vector2i.MAX or not _entrada_practicable(servicio, suelo):
		return celdas
	for xz: Vector2i in huella:
		var celda := Vector3i(xz.x, suelo, xz.y)
		if mundo.obtener_tipo(celda) == "" and _buscador.es_transitable(celda):
			celdas.append(celda)
	return celdas


## true si "celda" está en la columna pegada (4 direcciones) a alguna celda de
## la huella y no dentro de ella. Con "servicio" (celda de la puerta de un
## puesto), en cambio: dentro de la zona de servicio (RADIO_SERVICIO) y fuera de la huella.
func _junto_a(celda: Vector3i, huella: Array, servicio: Vector2i = Vector2i.MAX) -> bool:
	var xz := Vector2i(celda.x, celda.z)
	if huella.has(xz):
		return false
	if servicio != Vector2i.MAX:
		# La celda frente a la puerta no cuenta: quien espere ahí la taponaría.
		return xz != servicio and absi(xz.x - servicio.x) <= RADIO_SERVICIO and absi(xz.y - servicio.y) <= RADIO_SERVICIO
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


## Celdas transitables de la zona de servicio de un puesto (fuera de la huella,
## sobre la superficie).
func _celdas_de_servicio(servicio: Vector2i, huella: Array) -> Array[Vector3i]:
	var celdas: Array[Vector3i] = []
	for dx in range(-RADIO_SERVICIO, RADIO_SERVICIO + 1):
		for dz in range(-RADIO_SERVICIO, RADIO_SERVICIO + 1):
			var xz := servicio + Vector2i(dx, dz)
			if huella.has(xz) or xz == servicio:
				continue
			var altura: int = mundo.altura_en(xz.x, xz.y)
			if altura < 0:
				continue
			var candidata := Vector3i(xz.x, altura + 1, xz.y)
			if _buscador.es_transitable(candidata):
				celdas.append(candidata)
	return celdas


## Planifica una ruta hasta una celda libre del interior del edificio (si el puesto
## tiene plantilla; con "solo_dentro", solo eso), o hasta la más cercana junto a la huella (en la zona de
## servicio, si el puesto tiene puerta), con una sola búsqueda por grupo; si ninguno es
## alcanzable, espera y reintenta.
func _ir_junto_a(c: Dictionary, huella: Array, servicio: Vector2i = Vector2i.MAX, interiores: Array[Vector3i] = [], solo_dentro := false) -> void:
	var dentro: Array[Vector3i] = []
	for celda in interiores:
		if not _ocupada_por_otro(celda, c["id"]):
			dentro.append(celda)
	# La celda pegada a la puerta por dentro no se ocupa (taponaría la entrada), salvo que sea
	# el único sitio libre del edificio: se llena desde el fondo.
	if interiores.size() > 1:
		var fondo: Array[Vector3i] = []
		for celda in dentro:
			if not _es_vestibulo(celda, huella, servicio):
				fondo.append(celda)
		dentro = fondo
	# UNA búsqueda por grupo (interior, luego fuera), repartida entre fotogramas: probar
	# las celdas de una en una, o de golpe, cuesta el tope de nodos por cada inalcanzable
	# (ver BuscadorRutas.iniciar_busqueda_a_alguna()).
	var grupos: Array = []
	if not dentro.is_empty():
		# Primero las celdas más alejadas de la puerta: llenar desde el fondo evita que los
		# primeros en llegar (los que están más cerca) sellen la entrada desde dentro.
		var puerta := _puerta_xz(huella, servicio)
		var lejos := 0
		for celda in dentro:
			lejos = maxi(lejos, absi(celda.x - puerta.x) + absi(celda.z - puerta.y))
		var mas_lejanas: Array[Vector3i] = []
		for celda in dentro:
			if absi(celda.x - puerta.x) + absi(celda.z - puerta.y) == lejos:
				mas_lejanas.append(celda)
		if mas_lejanas.size() < dentro.size():
			grupos.append(mas_lejanas)
		grupos.append(dentro)
	if not solo_dentro:
		var fuera: Array[Vector3i] = []
		var candidatas: Array[Vector3i] = _celdas_junto_a(huella) if servicio == Vector2i.MAX else _celdas_de_servicio(servicio, huella)
		for celda in candidatas:
			if not _ocupada_por_otro(celda, c["id"]):
				fuera.append(celda)
		grupos.append(fuera)
	if grupos.is_empty():
		return  # solo_dentro y ningún sitio libre dentro: nada que intentar
	c["busqueda"] = {"grupos": grupos, "actual": null}
	if solo_dentro:
		# Reintento desde la zona de espera: cerca, así que con el tope local, y sin
		# penalizar si falla (ya está en su sitio de trabajo).
		c["busqueda"]["tope"] = TOPE_NODOS_DESTINO
		c["busqueda"]["reintento"] = true
	_avanzar_busqueda(c)


## Continúa la búsqueda del colono (c["busqueda"]) con lo que quede del presupuesto de
## nodos de este fotograma. Al terminar con ruta, la asigna; si ningún grupo de
## destinos es alcanzable, el que deambula espera un rato al azar y el que va a su
## puesto espera con retroceso exponencial (1, 2, 4, 8 s).
func _avanzar_busqueda(c: Dictionary) -> void:
	var b: Dictionary = c["busqueda"]
	while true:
		if b["actual"] == null:
			if b["grupos"].is_empty():
				c["busqueda"] = {}
				if b.get("deambular", false):
					c["espera"] = _rng.randf_range(ESPERA_ENTRE_DESTINOS_MIN, ESPERA_ENTRE_DESTINOS_MAX)
				elif b.get("reintento", false):
					c["espera"] = ESPERA_TRABAJO * 4.0
				else:
					c["fallos_servicio"] = mini(c["fallos_servicio"] + 1, 4)
					c["espera"] = ESPERA_TRABAJO * pow(2.0, c["fallos_servicio"] - 1)
				return
			var opciones := _opciones_ruta(c)
			if b.has("tope"):
				opciones["max_nodos"] = b["tope"]
			b["actual"] = _buscador.iniciar_busqueda_a_alguna(c["celda"], b["grupos"].pop_front(), opciones)
		var busqueda = b["actual"]
		if not busqueda.terminada:
			if _nodos_libres <= 0:
				return  # el resto, en el próximo fotograma
			_nodos_libres -= busqueda.avanzar(_nodos_libres)
		if busqueda.terminada:
			if busqueda.exito:
				c["ruta"] = busqueda.ruta
				if not b.get("deambular", false) and not b.get("reintento", false):
					c["fallos_servicio"] = 0
				c["busqueda"] = {}
				return
			b["actual"] = null

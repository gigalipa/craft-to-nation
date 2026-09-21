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

## El mundo (VoxelWorld en el juego). Asignarlo crea el buscador de rutas.
var mundo: Object = null:
	set(valor):
		mundo = valor
		_buscador = BuscadorRutas.new(valor) if valor != null else null
var ciudad: Object = null  # Ciudad
var zona: Object = null  # Zonificacion

## id -> {"id", "tipo", "hogar", "celda", "posicion", "ruta", "progreso",
## "moviendo", "espera", "bloqueo"}. "celda" es la celda donde está parado;
## "posicion" (Vector3, los pies) es lo que dibuja el renderer.
var colonos: Dictionary = {}
## Vector3i -> id de colono: la celda que ocupa cada colono y, mientras da un
## paso, también la celda a la que va (reserva).
var ocupadas: Dictionary = {}

var _siguiente_id := 1
var _buscador: RefCounted = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if ciudad == null:
		ciudad = Ciudad
	if zona == null:
		zona = Zonificacion
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
	if c["espera"] > 0.0:
		c["espera"] -= delta
		return
	if c["ruta"].is_empty():
		_elegir_destino(c)
		return
	_iniciar_paso(c, delta)


## Empieza a caminar hacia la siguiente celda de la ruta, si sigue siendo
## transitable (el mundo pudo cambiar: minado, obra, agua) y nadie la ocupa.
func _iniciar_paso(c: Dictionary, delta: float) -> void:
	var siguiente: Vector3i = c["ruta"][0]
	if not _buscador.es_transitable(siguiente):
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
	if c["ruta"].is_empty():
		c["espera"] = _rng.randf_range(ESPERA_ENTRE_DESTINOS_MIN, ESPERA_ENTRE_DESTINOS_MAX)


func _ocupada_por_otro(celda: Vector3i, id: int) -> bool:
	return ocupadas.has(celda) and ocupadas[celda] != id


## Celdas que este colono no puede pisar ahora: las de los demás colonos.
## (La Tarea 4 añade las del avatar.)
func _bloqueadas_para(id: int) -> Dictionary:
	var bloqueadas := {}
	for celda in ocupadas:
		if ocupadas[celda] != id:
			bloqueadas[celda] = true
	return bloqueadas


## Vuelve a calcular la ruta al MISMO destino sin obstáculos de otros
## (el mundo cambió bajo la ruta); si ya no hay ruta, abandona el destino.
func _replanificar(c: Dictionary) -> void:
	var vacia: Array[Vector3i] = []
	if c["ruta"].is_empty():
		return
	var destino: Vector3i = c["ruta"].back()
	var nueva: Array[Vector3i] = _buscador.buscar_ruta(c["celda"], destino)
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
	var nueva: Array[Vector3i] = _buscador.buscar_ruta(c["celda"], destino, {"bloqueadas": _bloqueadas_para(c["id"])})
	if nueva.is_empty():
		c["ruta"] = vacia
		c["espera"] = _rng.randf_range(ESPERA_ENTRE_DESTINOS_MIN, ESPERA_ENTRE_DESTINOS_MAX)
	else:
		c["ruta"] = nueva


## Elige el siguiente destino: la mitad de las veces su casa (si tiene), el
## resto un punto de la zona de influencia. Prueba INTENTOS_DESTINO veces hasta
## dar con uno alcanzable; si no, espera y reintenta.
func _elegir_destino(c: Dictionary) -> void:
	var a_casa: bool = c["hogar"] != -1 and _rng.randf() < PROBABILIDAD_CASA
	for i in range(INTENTOS_DESTINO):
		var destino: Vector3i = _candidato_en_casa(c["hogar"]) if a_casa else _candidato_exterior()
		if destino == INVALIDA:
			continue
		var ruta: Array[Vector3i] = _buscador.buscar_ruta(c["celda"], destino, {"bloqueadas": _bloqueadas_para(c["id"])})
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
		if celda == INVALIDA or ocupadas.has(celda):
			continue
		if _es_borde_de_zona(Vector2i(celda.x, celda.z)):
			return celda
		if respaldo == INVALIDA:
			respaldo = celda
	return respaldo

extends Node

## Autoload "Canalizaciones": estado puro, catálogo, geometría y topología
## de la red de acueductos y tuberías (Etapa 9.3).
## Sin class_name (colisionaría con el nombre del autoload).

signal canalizaciones_cambiadas
signal derrame_detectado(celda: Vector3i, recurso: String)

const ALTURA_DESPEJE := 3
const ALTURA_DUCTO_RELATIVA := 4
const INTERVALO_COLUMNAS := 5

var TIPOS: Dictionary = {
	"acueducto": {
		"nombre": "Acueducto",
		"bloque_ducto": "acueducto",
		"bloque_columna": "bloque_piedra",
		"fluidos": ["agua", "combustible"],
		"costo_ducto": {"bloque_piedra": 1, "bloque_madera": 1},
		"costo_columna": {"bloque_piedra": 1},
	},
	"tuberia": {
		"nombre": "Tubería",
		"bloque_ducto": "tuberia",
		"bloque_columna": "estructura_hierro",
		"fluidos": ["agua", "crudo", "combustible"],
		"costo_ducto": {"bloque_acero": 1},
		"costo_columna": {"estructura_hierro": 1},
	},
}

## Registro de topología:
## celda_a_red: Vector3i (celda ducto) -> int id_red
var celda_a_red: Dictionary = {}
## red_a_celdas: int id_red -> Array[Vector3i]
var red_a_celdas: Dictionary = {}
## tipo_por_red: int id_red -> String ("acueducto" | "tuberia")
var tipo_por_red: Dictionary = {}
## recurso_por_red: int id_red -> String ("agua" | "crudo" | "combustible" | "")
var recurso_por_red: Dictionary = {}
## columnas: Vector3i -> int id_red
var columnas: Dictionary = {}
## puertos_conectados: Vector3i (celda puerto) -> int id_red
var puertos_conectados: Dictionary = {}
## derrames_activos: Vector3i (extremo abierto) -> String (recurso)
var derrames_activos: Dictionary = {}

var _siguiente_id_red := 1


func reiniciar() -> void:
	celda_a_red.clear()
	red_a_celdas.clear()
	tipo_por_red.clear()
	recurso_por_red.clear()
	columnas.clear()
	puertos_conectados.clear()
	derrames_activos.clear()
	_siguiente_id_red = 1


func es_fluido_permitido(tipo_ducto: String, fluido: String) -> bool:
	if not TIPOS.has(tipo_ducto):
		return false
	return TIPOS[tipo_ducto]["fluidos"].has(fluido)


func es_puerto_compatible(tipo_ducto: String, tipo_puerto: String) -> bool:
	if not TIPOS.has(tipo_ducto):
		return false
	var rec: String = ""
	if tipo_puerto.begins_with("puerto_agua"):
		rec = "agua"
	elif tipo_puerto.begins_with("puerto_crudo"):
		rec = "crudo"
	elif tipo_puerto.begins_with("puerto_combustible"):
		rec = "combustible"
	if rec == "":
		return false
	return es_fluido_permitido(tipo_ducto, rec)


func recurso_de_red(id_red: int) -> String:
	return recurso_por_red.get(id_red, "")


func asignar_puerto_a_red(id_red: int, celda_puerto: Vector3i, tipo_puerto: String) -> bool:
	var tipo_ducto: String = tipo_por_red.get(id_red, "")
	if not es_puerto_compatible(tipo_ducto, tipo_puerto):
		return false
	var rec_puerto: String = ""
	if tipo_puerto.begins_with("puerto_agua"):
		rec_puerto = "agua"
	elif tipo_puerto.begins_with("puerto_crudo"):
		rec_puerto = "crudo"
	elif tipo_puerto.begins_with("puerto_combustible"):
		rec_puerto = "combustible"

	var rec_actual: String = recurso_por_red.get(id_red, "")
	if rec_actual == "":
		recurso_por_red[id_red] = rec_puerto
	elif rec_actual != rec_puerto:
		return false
	puertos_conectados[celda_puerto] = id_red
	return true


func es_celda_canalizacion(celda: Vector3i) -> bool:
	return celda_a_red.has(celda)


func obtener_red_de_celda(celda: Vector3i) -> int:
	return celda_a_red.get(celda, -1)


func ficha_tecnica(tipo: String, celdas_ducto: int = 0, celdas_columna: int = 0) -> String:
	if not TIPOS.has(tipo):
		return ""
	var datos: Dictionary = TIPOS[tipo]
	var nombre: String = datos.get("nombre", tipo.capitalize())
	var costo_d: Dictionary = datos.get("costo_ducto", {})
	var costo_c: Dictionary = datos.get("costo_columna", {})
	var fluidos_str: String = ", ".join(datos.get("fluidos", []))

	var partes_costo: Array = []
	if celdas_ducto > 0 or celdas_columna > 0:
		var totales: Dictionary = {}
		for rec in costo_d:
			totales[rec] = totales.get(rec, 0) + costo_d[rec] * celdas_ducto
		for rec in costo_c:
			totales[rec] = totales.get(rec, 0) + costo_c[rec] * celdas_columna
		for rec in totales:
			partes_costo.append("%d %s" % [totales[rec], rec])
	else:
		for rec in costo_d:
			partes_costo.append("%d %s/m" % [costo_d[rec], rec])

	var costo_str: String = " + ".join(partes_costo) if not partes_costo.is_empty() else "N/A"
	return "%s\nFluidos: %s\nMateriales: %s\nDespeje: 3 bloques\nColumnas: cada 5 bloques" % [
		nombre,
		fluidos_str,
		costo_str
	]


## Calcula la geometría del tramo: celdas de ducto a Y_suelo+4,
## columnas cada 5 bloques (vano 4), esquinas de 90°, pendientes diagonales y cruces a desnivel.
func calcular_geometria_tramo(tipo: String, puntos_2d: Array[Vector2i], mundo: Object) -> Dictionary:
	var resultado := {
		"valido": true,
		"motivo": "",
		"celdas_ducto": [] as Array[Vector3i],
		"celdas_columna": [] as Array[Vector3i],
		"costo": {} as Dictionary,
		"esquinas": [] as Array[Vector2i],
	}

	if puntos_2d.is_empty():
		resultado.valido = false
		resultado.motivo = "Tramo vacío."
		return resultado

	var n := puntos_2d.size()
	# 1. Identificar posiciones que llevan columna:
	# - Índice 0 y n-1 (extremos)
	# - Esquinas de 90° (cambio de dirección horizontal)
	# - Cada 5 bloques de distancia acumulada
	var indices_columna: Array[int] = [0]
	var ultimo_indice_col := 0

	for i in range(1, n - 1):
		var dir_ant: Vector2i = puntos_2d[i] - puntos_2d[i - 1]
		var dir_sig: Vector2i = puntos_2d[i + 1] - puntos_2d[i]
		if dir_ant != dir_sig:
			# Esquina
			if not indices_columna.has(i):
				indices_columna.append(i)
				ultimo_indice_col = i
				resultado.esquinas.append(puntos_2d[i])
		elif (i - ultimo_indice_col) >= INTERVALO_COLUMNAS:
			if not indices_columna.has(i):
				indices_columna.append(i)
				ultimo_indice_col = i

	if not indices_columna.has(n - 1) and n > 1:
		indices_columna.append(n - 1)

	indices_columna.sort()

	# 2. Calcular alturas de las cimas de las columnas:
	# Cima de columna en punto p es mundo.altura_en(p.x, p.y) + ALTURA_DUCTO_RELATIVA
	var altura_cima: Dictionary = {} # int (índice) -> int (Y_ducto)
	for idx in indices_columna:
		var p: Vector2i = puntos_2d[idx]
		var h_suelo: int = mundo.altura_en(p.x, p.y)
		altura_cima[idx] = h_suelo + ALTURA_DUCTO_RELATIVA

	# 3. Interpolar alturas de ducto entre columnas contiguas:
	var alturas_ducto: Array[int] = []
	alturas_ducto.resize(n)

	for c in range(indices_columna.size()):
		var idx_a: int = indices_columna[c]
		alturas_ducto[idx_a] = altura_cima[idx_a]
		if c < indices_columna.size() - 1:
			var idx_b: int = indices_columna[c + 1]
			var dist: int = idx_b - idx_a
			for k in range(idx_a + 1, idx_b):
				var t: float = float(k - idx_a) / float(dist)
				alturas_ducto[k] = roundi(lerp(float(altura_cima[idx_a]), float(altura_cima[idx_b]), t))

	# 4. Generar celdas de ducto con detección de cruce a desnivel (+1 cota si ya hay canalización)
	var celdas_ducto: Array[Vector3i] = []
	for i in range(n):
		var p: Vector2i = puntos_2d[i]
		var y: int = alturas_ducto[i]
		var celda_tentativa := Vector3i(p.x, y, p.y)
		# Verificar si hay canalización preexistente a la misma cota
		var tipo_existente: String = mundo.obtener_tipo(celda_tentativa)
		if tipo_existente == "acueducto" or tipo_existente == "tuberia" or celda_a_red.has(celda_tentativa):
			# Sobre-elevar 1 bloque para pasar por encima
			celda_tentativa.y += 1
		celdas_ducto.append(celda_tentativa)

	resultado.celdas_ducto = celdas_ducto

	# 5. Generar columnas verticales desde el suelo hasta justo debajo del ducto:
	var celdas_columna: Array[Vector3i] = []
	for idx in indices_columna:
		var p: Vector2i = puntos_2d[idx]
		var y_ducto: int = celdas_ducto[idx].y
		var h_suelo: int = mundo.altura_en(p.x, p.y)
		for y_col in range(h_suelo + 1, y_ducto):
			celdas_columna.append(Vector3i(p.x, y_col, p.y))

	resultado.celdas_columna = celdas_columna

	# 6. Calcular costo de materiales:
	var datos_tipo: Dictionary = TIPOS.get(tipo, {})
	var c_ducto: Dictionary = datos_tipo.get("costo_ducto", {})
	var c_col: Dictionary = datos_tipo.get("costo_columna", {})
	var costo_total: Dictionary = {}
	for rec in c_ducto:
		costo_total[rec] = costo_total.get(rec, 0) + c_ducto[rec] * celdas_ducto.size()
	for rec in c_col:
		costo_total[rec] = costo_total.get(rec, 0) + c_col[rec] * celdas_columna.size()

	resultado.costo = costo_total
	return resultado


## Construye físicamente el tramo en mundo y lo registra en la red.
func construir_tramo(tipo: String, geom: Dictionary, mundo: Object) -> int:
	if not geom.get("valido", false):
		return -1

	var id := _siguiente_id_red
	_siguiente_id_red += 1

	var bloque_d: String = TIPOS[tipo]["bloque_ducto"]
	var bloque_c: String = TIPOS[tipo]["bloque_columna"]

	var celdas_d: Array = geom["celdas_ducto"]
	var celdas_c: Array = geom["celdas_columna"]

	# Colocar columnas
	for col: Vector3i in celdas_c:
		mundo.colocar_bloque(col, bloque_c, true)
		columnas[col] = id

	# Colocar ductos
	var registradas: Array[Vector3i] = []
	for c: Vector3i in celdas_d:
		mundo.colocar_bloque(c, bloque_d, true)
		celda_a_red[c] = id
		registradas.append(c)
		# Marcar que sobre el ducto no caminan colonos
		if mundo.has_method("registrar_edificio"):
			mundo.celda_sobre_techo[c + Vector3i(0, 1, 0)] = id

	red_a_celdas[id] = registradas
	tipo_por_red[id] = tipo
	canalizaciones_cambiadas.emit()
	return id


## Elimina las celdas especificadas y actualiza la red.
func quitar_celdas(celdas: Array, mundo: Object) -> void:
	for celda: Vector3i in celdas:
		if celda_a_red.has(celda):
			var id: int = celda_a_red[celda]
			celda_a_red.erase(celda)
			if red_a_celdas.has(id):
				red_a_celdas[id].erase(celda)
		if columnas.has(celda):
			columnas.erase(celda)
		if mundo.has_method("minar_bloque"):
			mundo.minar_bloque(celda)
	canalizaciones_cambiadas.emit()

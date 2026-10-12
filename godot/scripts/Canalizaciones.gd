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
		"bloque_ducto": "acueducto_lineal",
		"bloque_ducto_lineal": "acueducto_lineal",
		"bloque_ducto_quiebre": "acueducto_quiebre",
		"bloque_columna": "bloque_piedra",
		"fluidos": ["agua", "combustible"],
		"costo_ducto": {"bloque_piedra": 1, "bloque_madera": 1},
		"costo_columna": {"bloque_piedra": 1},
	},
	"tuberia": {
		"nombre": "Tubería",
		"bloque_ducto": "tuberia_lineal",
		"bloque_ducto_lineal": "tuberia_lineal",
		"bloque_ducto_quiebre": "tuberia_quiebre",
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
## columnas_xz: Vector2i -> int (número de bloques de columna en esa coordenada XZ)
var columnas_xz: Dictionary = {}
## puertos_conectados: Vector3i (celda puerto) -> int id_red
var puertos_conectados: Dictionary = {}
## derrames_activos: Vector3i (extremo abierto) -> String (recurso)
var derrames_activos: Dictionary = {}
## nodos_diagonales: int id_red -> Array[Node3D] (mallas diagonales continuas)
var nodos_diagonales: Dictionary = {}

var _siguiente_id_red := 1


var tipo_por_puerto: Dictionary = {} # Vector3i -> String


func reiniciar() -> void:
	for id_r in nodos_diagonales:
		for item in nodos_diagonales[id_r]:
			var nodo: Node3D = item.get("nodo", null) if item is Dictionary else item
			if is_instance_valid(nodo):
				nodo.queue_free()
	nodos_diagonales.clear()
	celda_a_red.clear()
	red_a_celdas.clear()
	tipo_por_red.clear()
	recurso_por_red.clear()
	columnas.clear()
	columnas_xz.clear()
	puertos_conectados.clear()
	tipo_por_puerto.clear()
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


func tipo_de_red(id_red: int) -> String:
	return tipo_por_red.get(id_red, "")


func cancelar_derrame_de_red(id_red: int, mundo: Object = null) -> void:
	var derrames_a_borrar: Array[Vector3i] = []
	for d: Vector3i in derrames_activos:
		if celda_a_red.get(d, -1) == id_red or red_a_celdas.get(id_red, []).has(d):
			derrames_a_borrar.append(d)
	for d in derrames_a_borrar:
		derrames_activos.erase(d)
		if mundo != null and mundo.has_method("minar_bloque"):
			mundo.minar_bloque(d)


func asignar_puerto_a_red(id_red: int, celda_puerto: Vector3i, tipo_puerto: String, mundo: Object = null) -> bool:
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
	tipo_por_puerto[celda_puerto] = tipo_puerto

	if tipo_puerto.ends_with("_in"):
		cancelar_derrame_de_red(id_red, mundo)

	canalizaciones_cambiadas.emit()
	return true


func destinos_de_puerto_salida(celda_puerto_salida: Vector3i) -> Array[Vector3i]:
	var destinos: Array[Vector3i] = []
	if not puertos_conectados.has(celda_puerto_salida):
		return destinos
	var id_red: int = puertos_conectados[celda_puerto_salida]

	# Si celda_a_red está vacía (pruebas unitarias/mocks con red_a_celdas o puertos directos)
	if celda_a_red.is_empty():
		for p: Vector3i in puertos_conectados:
			if p == celda_puerto_salida:
				continue
			if puertos_conectados[p] == id_red:
				var tipo_p: String = tipo_por_puerto.get(p, "")
				if tipo_p.ends_with("_in"):
					destinos.append(p)
		return destinos

	# 1. Encontrar celdas de ducto adyacentes al puerto de salida
	var inicio_ducto: Array[Vector3i] = []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				var c := celda_puerto_salida + Vector3i(dx, dy, dz)
				if celda_a_red.get(c, -1) == id_red:
					inicio_ducto.append(c)

	if inicio_ducto.is_empty():
		return destinos

	# 2. BFS para encontrar todas las celdas de ducto contiguas alcanzables
	var visitados: Dictionary = {}
	var cola: Array[Vector3i] = []
	for c in inicio_ducto:
		visitados[c] = true
		cola.append(c)

	while not cola.is_empty():
		var actual: Vector3i = cola.pop_front()
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					if dx == 0 and dy == 0 and dz == 0:
						continue
					var vec := actual + Vector3i(dx, dy, dz)
					if celda_a_red.get(vec, -1) == id_red and not visitados.has(vec):
						visitados[vec] = true
						cola.append(vec)

	# 3. Comprobar qué puertos de entrada tienen al menos una celda de ducto alcanzable adyacente
	for p: Vector3i in puertos_conectados:
		if p == celda_puerto_salida:
			continue
		if puertos_conectados[p] == id_red:
			var tipo_p: String = tipo_por_puerto.get(p, "")
			if tipo_p.ends_with("_in"):
				var alcanzable := false
				for dx in [-1, 0, 1]:
					for dy in [-1, 0, 1]:
						for dz in [-1, 0, 1]:
							if visitados.has(p + Vector3i(dx, dy, dz)):
								alcanzable = true
								break
						if alcanzable:
							break
				if alcanzable:
					destinos.append(p)
	if destinos.size() > 1:
		return [destinos[0]] as Array[Vector3i]
	return destinos


func extremos_abiertos_de_red(id_red: int) -> Array[Vector3i]:
	var abiertos: Array[Vector3i] = []
	if not red_a_celdas.has(id_red):
		return abiertos
	var celdas: Array = red_a_celdas[id_red]
	if celdas.is_empty():
		return abiertos
	for c: Vector3i in celdas:
		var vecinos_misma_red := 0
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					if dx == 0 and dy == 0 and dz == 0:
						continue
					if celda_a_red.get(c + Vector3i(dx, dy, dz), -1) == id_red:
						vecinos_misma_red += 1
		if vecinos_misma_red <= 1:
			var tiene_puerto := false
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					for dz in [-1, 0, 1]:
						var delta := Vector3i(dx, dy, dz)
						if puertos_conectados.has(c + delta) and puertos_conectados[c + delta] == id_red:
							tiene_puerto = true
							break
					if tiene_puerto:
						break
			if not tiene_puerto:
				abiertos.append(c)
	if abiertos.is_empty() and celdas.size() > 0:
		var tiene_algun_puerto := false
		for p: Vector3i in puertos_conectados:
			if puertos_conectados[p] == id_red:
				tiene_algun_puerto = true
				break
		if not tiene_algun_puerto:
			abiertos.append(celdas[-1])
	return abiertos


func verter_derrame(id_red: int, recurso: String, mundo: Object) -> Vector3i:
	var abiertos: Array[Vector3i] = extremos_abiertos_de_red(id_red)
	if abiertos.is_empty():
		return Vector3i.ZERO
	var celda_extremo: Vector3i = abiertos[0]
	if mundo != null:
		mundo.colocar_bloque(celda_extremo, recurso, true)
	derrames_activos[celda_extremo] = recurso
	derrame_detectado.emit(celda_extremo, recurso)
	return celda_extremo


func estado_de_puerto(celda_puerto: Vector3i) -> String:
	if not puertos_conectados.has(celda_puerto):
		return "desconectado"
	var id_red: int = puertos_conectados[celda_puerto]

	# Si celda_a_red no está vacía (partida real), verificar contigüidad física
	if not celda_a_red.is_empty():
		var tiene_ducto_adyacente := false
		if red_a_celdas.get(id_red, []).has(celda_puerto):
			tiene_ducto_adyacente = true
		else:
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					for dz in [-1, 0, 1]:
						if celda_a_red.get(celda_puerto + Vector3i(dx, dy, dz), -1) == id_red:
							tiene_ducto_adyacente = true
							break
					if tiene_ducto_adyacente:
						break
		if not tiene_ducto_adyacente:
			return "desconectado"

	for d: Vector3i in derrames_activos:
		if celda_a_red.get(d, -1) == id_red or red_a_celdas.get(id_red, []).has(d):
			return "derrame"
	var tipo_p: String = tipo_por_puerto.get(celda_puerto, "")
	if tipo_p.ends_with("_out"):
		var destinos: Array = destinos_de_puerto_salida(celda_puerto)
		if destinos.is_empty():
			return "derrame"
		return "conectado"
	elif tipo_p.ends_with("_in"):
		# Para un puerto de entrada: ¿hay algún puerto de salida conectado que lo alcance?
		var alcanzado := false
		for p_out: Vector3i in puertos_conectados:
			if p_out == celda_puerto:
				continue
			if puertos_conectados[p_out] == id_red and tipo_por_puerto.get(p_out, "").ends_with("_out"):
				if destinos_de_puerto_salida(p_out).has(celda_puerto):
					alcanzado = true
					break
		if not alcanzado:
			return "desconectado"
		return "conectado"
	return "conectado"


func es_celda_canalizacion(celda: Vector3i) -> bool:
	return celda_a_red.has(celda)


func obtener_red_de_celda(celda: Vector3i) -> int:
	return celda_a_red.get(celda, -1)


func red_en_celda(celda: Vector3i) -> int:
	if celda_a_red.has(celda):
		return celda_a_red[celda]
	if columnas.has(celda):
		return columnas[celda]
	if puertos_conectados.has(celda):
		return puertos_conectados[celda]
	return -1


func red_en_columna(xz: Vector2i) -> int:
	for c: Vector3i in celda_a_red:
		if c.x == xz.x and c.z == xz.y:
			return celda_a_red[c]
	for c: Vector3i in columnas:
		if c.x == xz.x and c.z == xz.y:
			return columnas[c]
	for p: Vector3i in puertos_conectados:
		if p.x == xz.x and p.z == xz.y:
			return puertos_conectados[p]
	return -1


func es_columna(celda: Vector3i) -> bool:
	return columnas.has(celda)


func tiene_columna_en(xz: Vector2i) -> bool:
	if columnas_xz.is_empty() and not columnas.is_empty():
		for c: Vector3i in columnas:
			var c_xz := Vector2i(c.x, c.z)
			columnas_xz[c_xz] = columnas_xz.get(c_xz, 0) + 1
	return columnas_xz.has(xz)


func info_de_red(id_red: int) -> Dictionary:
	var res := {
		"id": id_red,
		"existe": false,
		"tipo": "",
		"recurso": "",
		"celdas_ducto": 0,
		"celdas_columna": 0,
		"puertos": [],
		"extremos_abiertos": [],
		"derrames": [],
	}
	if not tipo_por_red.has(id_red):
		return res

	res["existe"] = true
	res["tipo"] = tipo_por_red.get(id_red, "")
	res["recurso"] = recurso_por_red.get(id_red, "")
	res["celdas_ducto"] = red_a_celdas.get(id_red, []).size()

	var cols := 0
	for c: Vector3i in columnas:
		if columnas[c] == id_red:
			cols += 1
	res["celdas_columna"] = cols

	var lista_puertos: Array[Dictionary] = []
	for p: Vector3i in puertos_conectados:
		if puertos_conectados[p] == id_red:
			var tipo_p: String = tipo_por_puerto.get(p, "")
			var dir_p: String = "Entrada" if tipo_p.ends_with("_in") else "Salida"
			var rec_p: String = ""
			if tipo_p.begins_with("puerto_agua"): rec_p = "agua"
			elif tipo_p.begins_with("puerto_crudo"): rec_p = "crudo"
			elif tipo_p.begins_with("puerto_combustible"): rec_p = "combustible"

			var nombre_edificio := "Edificio"
			var esq_puesto: Vector2i = Vector2i(-99999, -99999)
			if Economia != null and Economia.has_method("buscar_puesto_por_puerto"):
				esq_puesto = Economia.buscar_puesto_por_puerto(p)
				if esq_puesto != Vector2i(-99999, -99999):
					var p_info: Dictionary = Economia.puestos.get(esq_puesto, {})
					var tipo_edif: String = p_info.get("tipo", "")
					if tipo_edif == "almacen":
						nombre_edificio = "Almacén"
					elif tipo_edif != "":
						var PanelPuestoScript = preload("res://scripts/PanelPuesto.gd")
						nombre_edificio = PanelPuestoScript.NOMBRES_PUESTO.get(tipo_edif, tipo_edif.capitalize())

			var est_p: String = estado_de_puerto(p)
			lista_puertos.append({
				"celda": p,
				"tipo_puerto": tipo_p,
				"direccion": dir_p,
				"recurso": rec_p,
				"edificio": nombre_edificio,
				"esquina": esq_puesto,
				"estado": est_p,
			})
	res["puertos"] = lista_puertos
	res["extremos_abiertos"] = extremos_abiertos_de_red(id_red)

	var lista_derrames: Array[Vector3i] = []
	for d: Vector3i in derrames_activos:
		if celda_a_red.get(d, -1) == id_red or red_a_celdas.get(id_red, []).has(d):
			lista_derrames.append(d)
	res["derrames"] = lista_derrames
	return res


static func nombre_recurso_legible(clave: String) -> String:
	var nombres := {
		"bloque_acero": "Bloque de acero",
		"estructura_hierro": "Estructura de hierro",
		"bloque_piedra": "Bloque de piedra",
		"bloque_madera": "Bloque de madera",
	}
	return nombres.get(clave, clave.replace("_", " ").capitalize())


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
			partes_costo.append("%d %s" % [totales[rec], nombre_recurso_legible(rec)])
	else:
		for rec in costo_d:
			partes_costo.append("%d %s/m" % [costo_d[rec], nombre_recurso_legible(rec)])

	var costo_str: String = " + ".join(partes_costo) if not partes_costo.is_empty() else "N/A"
	return "%s\nFluidos: %s\nMateriales: %s\nDespeje: 3 bloques\nColumnas: cada 5 bloques" % [
		nombre,
		fluidos_str,
		costo_str
	]


## Busca si una celda 2D tiene un puerto adyacente (o en la misma celda) en el mundo.
## Devuelve Dictionary con {"existe": bool, "celda_puerto": Vector3i, "tipo_puerto": String, "altura": int}
func buscar_puerto_adyacente(p_2d: Vector2i, tipo_ducto: String, mundo: Object) -> Dictionary:
	var res := {"existe": false, "celda_puerto": Vector3i.ZERO, "tipo_puerto": "", "altura": 0}
	if mundo == null:
		return res

	var vecinos_2d: Array[Vector2i] = [
		p_2d + Vector2i(1, 0),
		p_2d + Vector2i(-1, 0),
		p_2d + Vector2i(0, 1),
		p_2d + Vector2i(0, -1),
		p_2d,
	]

	for v_2d in vecinos_2d:
		var h_base: int = mundo.altura_en(v_2d.x, v_2d.y) if mundo.has_method("altura_en") else 10
		var y_min: int = mini(0, h_base - 8)
		var y_max: int = maxi(30, h_base + 15)
		for y in range(y_min, y_max):
			var c_3d := Vector3i(v_2d.x, y, v_2d.y)
			var tipo_b: String = mundo.obtener_tipo(c_3d) if mundo.has_method("obtener_tipo") else ""
			if tipo_b.begins_with("puerto_"):
				if tipo_ducto == "" or es_puerto_compatible(tipo_ducto, tipo_b):
					res.existe = true
					res.celda_puerto = c_3d
					res.tipo_puerto = tipo_b
					res.altura = y
					return res
	return res


## Calcula la geometría del tramo: celdas de ducto a Y_suelo+4 (o altura de puerto si inicia/termina en él),
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

	# Detectar si extremos conectan con puertos compatibles
	var puerto_inicio: Dictionary = buscar_puerto_adyacente(puntos_2d[0], tipo, mundo)
	var puerto_fin: Dictionary = buscar_puerto_adyacente(puntos_2d[n - 1], tipo, mundo) if n > 1 else {"existe": false}

	# 1. Identificar posiciones que son anclas / llevan columna:
	# - Índice 0 es ancla. Si no tiene puerto, lleva columna.
	# - Esquinas de 90° son ancla y llevan columna.
	# - Cada 5 bloques de distancia acumulada desde el ancla anterior es ancla y lleva columna.
	# - Índice n-1 es ancla. Si no tiene puerto, lleva columna.
	var indices_ancla: Array[int] = [0]
	var indices_columna: Array[int] = []
	if not puerto_inicio.get("existe", false):
		indices_columna.append(0)

	var ultimo_indice_ref := 0

	for i in range(1, n - 1):
		var dir_ant: Vector2i = puntos_2d[i] - puntos_2d[i - 1]
		var dir_sig: Vector2i = puntos_2d[i + 1] - puntos_2d[i]
		if dir_ant != dir_sig:
			# Esquina
			if not indices_ancla.has(i):
				indices_ancla.append(i)
				indices_columna.append(i)
				ultimo_indice_ref = i
				resultado.esquinas.append(puntos_2d[i])
		elif (i - ultimo_indice_ref) >= INTERVALO_COLUMNAS:
			if not indices_ancla.has(i):
				indices_ancla.append(i)
				indices_columna.append(i)
				ultimo_indice_ref = i

	if n > 1:
		if not indices_ancla.has(n - 1):
			indices_ancla.append(n - 1)
		if not puerto_fin.get("existe", false):
			if not indices_columna.has(n - 1):
				indices_columna.append(n - 1)

	# Detectar cruces a desnivel con canalizaciones existentes:
	var cruces_detectados: Array[int] = []
	for i in range(1, n - 1):
		var p_c: Vector2i = puntos_2d[i]
		var h_s: int = mundo.altura_en(p_c.x, p_c.y) if mundo != null and mundo.has_method("altura_en") else 0
		var h_base: int = 0
		if i == 0 and puerto_inicio.get("existe", false):
			h_base = puerto_inicio["altura"]
		elif i == n - 1 and puerto_fin.get("existe", false):
			h_base = puerto_fin["altura"]
		else:
			h_base = h_s + ALTURA_DUCTO_RELATIVA

		# Comprobar si hay ducto existente en esta celda o cota
		var hay_ducto := false
		for y_chk in range(h_base, h_base + 8):
			var c_chk := Vector3i(p_c.x, y_chk, p_c.y)
			var tipo_chk: String = mundo.obtener_tipo(c_chk) if mundo != null and mundo.has_method("obtener_tipo") else ""
			if tipo_chk.begins_with("acueducto") or tipo_chk.begins_with("tuberia") or celda_a_red.has(c_chk):
				hay_ducto = true
				break

		if hay_ducto:
			cruces_detectados.append(i)

	var alturas_cruce: Dictionary = {} # int (índice) -> int (altura_cruce)
	for i in cruces_detectados:
		var p_c: Vector2i = puntos_2d[i]
		var h_s: int = mundo.altura_en(p_c.x, p_c.y) if mundo != null and mundo.has_method("altura_en") else 0
		var y_elevado: int = h_s + 6

		alturas_cruce[i] = y_elevado
		if not indices_ancla.has(i):
			indices_ancla.append(i)
		indices_columna.erase(i)

		# Columna de sobre-elevación y cabezal en celda adyacente anterior (i - 1)
		if i > 0:
			alturas_cruce[i - 1] = y_elevado
			if not indices_ancla.has(i - 1):
				indices_ancla.append(i - 1)
			if not indices_columna.has(i - 1):
				if not (i - 1 == 0 and puerto_inicio.get("existe", false)):
					indices_columna.append(i - 1)

		# Columna de sobre-elevación y cabezal en celda adyacente posterior (i + 1)
		if i < n - 1:
			alturas_cruce[i + 1] = y_elevado
			if not indices_ancla.has(i + 1):
				indices_ancla.append(i + 1)
			if not indices_columna.has(i + 1):
				if not (i + 1 == n - 1 and puerto_fin.get("existe", false)):
					indices_columna.append(i + 1)

	indices_ancla.sort()
	indices_columna.sort()

	# 2. Calcular alturas de las cimas de las columnas / anclas:
	var altura_cima: Dictionary = {} # int (índice ancla) -> int (Y_ducto)
	for idx in indices_ancla:
		if alturas_cruce.has(idx):
			altura_cima[idx] = alturas_cruce[idx]
		elif idx == 0 and puerto_inicio.get("existe", false):
			altura_cima[0] = puerto_inicio["altura"]
		elif idx == n - 1 and puerto_fin.get("existe", false):
			altura_cima[n - 1] = puerto_fin["altura"]
		else:
			var p: Vector2i = puntos_2d[idx]
			var h_suelo: int = mundo.altura_en(p.x, p.y) if mundo.has_method("altura_en") else 0
			altura_cima[idx] = h_suelo + ALTURA_DUCTO_RELATIVA

	# 3. Interpolar alturas de ducto entre anclas contiguas y detectar tramos:
	var alturas_ducto: Array[int] = []
	alturas_ducto.resize(n)
	var tramos: Array[Dictionary] = []
	var tramos_diagonales: Array[Dictionary] = []
	var indices_diagonales: Dictionary = {}
	var indices_intermedios_totales: Dictionary = {}

	for c in range(indices_ancla.size()):
		var idx_a: int = indices_ancla[c]
		alturas_ducto[idx_a] = altura_cima[idx_a]
		if c < indices_ancla.size() - 1:
			var idx_b: int = indices_ancla[c + 1]
			var dist: int = idx_b - idx_a
			var y_a: int = altura_cima[idx_a]
			var y_b: int = altura_cima[idx_b]
			var es_diagonal: bool = (y_a != y_b)
			var indices_intermedios: Array[int] = []
			for k in range(idx_a + 1, idx_b):
				var t: float = float(k - idx_a) / float(dist)
				alturas_ducto[k] = roundi(lerp(float(y_a), float(y_b), t))
				indices_intermedios.append(k)
				indices_diagonales[k] = true
				indices_intermedios_totales[k] = true

			var p_a: Vector2i = puntos_2d[idx_a]
			var p_b: Vector2i = puntos_2d[idx_b]
			var datos_tramo := {
				"inicio": Vector3i(p_a.x, y_a, p_a.y),
				"fin": Vector3i(p_b.x, y_b, p_b.y),
				"tipo": tipo,
				"indices": indices_intermedios,
				"distancia": dist,
			}
			# Se crea tramo si hay distancia > 1 o si hay desnivel (y_a != y_b)
			# o si une bloques contiguos elevados a cota de cruce
			if dist > 1 or es_diagonal or (alturas_cruce.has(idx_a) and alturas_cruce.has(idx_b)):
				tramos.append(datos_tramo)
			if es_diagonal:
				tramos_diagonales.append(datos_tramo)

	# 3b. Clasificar nodos de ducto (Lineal vs Quiebre vs Extremo):
	var nodos_ducto: Array[Dictionary] = []
	var datos_tipo: Dictionary = TIPOS.get(tipo, {})
	var b_lineal: String = datos_tipo.get("bloque_ducto_lineal", datos_tipo.get("bloque_ducto", tipo))
	var b_quiebre: String = datos_tipo.get("bloque_ducto_quiebre", b_lineal)

	for c in range(indices_ancla.size()):
		var idx: int = indices_ancla[c]
		var p: Vector2i = puntos_2d[idx]
		var y: int = altura_cima[idx]
		var celda_nodo := Vector3i(p.x, y, p.y)

		var es_extremo: bool = (idx == 0 and bool(puerto_inicio.get("existe", false))) or (idx == n - 1 and bool(puerto_fin.get("existe", false)))
		var tipo_bloque := b_lineal
		var subtipo := "lineal"

		if es_extremo:
			subtipo = "extremo"
			tipo_bloque = b_lineal
		elif idx > 0 and idx < n - 1:
			var dir_in: Vector2i = puntos_2d[idx] - puntos_2d[idx - 1]
			var dir_out: Vector2i = puntos_2d[idx + 1] - puntos_2d[idx]
			if dir_in != dir_out:
				subtipo = "quiebre"
				tipo_bloque = b_quiebre
			else:
				subtipo = "lineal"
				tipo_bloque = b_lineal
		else:
			subtipo = "lineal"
			tipo_bloque = b_lineal

		nodos_ducto.append({
			"indice": idx,
			"celda": celda_nodo,
			"subtipo": subtipo,
			"tipo_bloque": tipo_bloque,
			"es_extremo": es_extremo,
		})

	# 4. Generar celdas de ducto y respeto de despejes de otros puertos
	var celdas_ducto: Array[Vector3i] = []
	for i in range(n):
		var p: Vector2i = puntos_2d[i]
		var y: int = alturas_ducto[i]
		var celda_tentativa := Vector3i(p.x, y, p.y)

		# Comprobar si la celda invade el despeje reservado de otro puerto (Observación 3)
		if mundo != null and "celda_a_despeje" in mundo and mundo.celda_a_despeje is Dictionary:
			if mundo.celda_a_despeje.has(celda_tentativa):
				var orig_desp := ""
				var val_desp = mundo.celda_a_despeje[celda_tentativa]
				if val_desp is Dictionary:
					if "edificio_despeje" in mundo and mundo.edificio_despeje is Dictionary:
						for id_edif in val_desp:
							var desp_dict = mundo.edificio_despeje.get(id_edif)
							if desp_dict is Dictionary:
								var tipo_cand: String = desp_dict.get(celda_tentativa, "")
								if tipo_cand.begins_with("puerto_"):
									orig_desp = tipo_cand
									break
				elif val_desp is int:
					if "edificio_despeje" in mundo and mundo.edificio_despeje is Dictionary:
						var desp_dict = mundo.edificio_despeje.get(val_desp)
						if desp_dict is Dictionary:
							orig_desp = desp_dict.get(celda_tentativa, "")
				elif val_desp is String:
					orig_desp = val_desp

				if orig_desp.begins_with("puerto_"):
					var rec_puerto := ""
					if orig_desp.begins_with("puerto_agua"): rec_puerto = "agua"
					elif orig_desp.begins_with("puerto_crudo"): rec_puerto = "crudo"
					elif orig_desp.begins_with("puerto_combustible"): rec_puerto = "combustible"

					var rec_ducto := ""
					if tipo == "acueducto":
						rec_ducto = "agua"
					elif puerto_inicio.get("existe", false):
						if puerto_inicio["tipo_puerto"].begins_with("puerto_agua"): rec_ducto = "agua"
						elif puerto_inicio["tipo_puerto"].begins_with("puerto_crudo"): rec_ducto = "crudo"
						elif puerto_inicio["tipo_puerto"].begins_with("puerto_combustible"): rec_ducto = "combustible"
					elif puerto_fin.get("existe", false):
						if puerto_fin["tipo_puerto"].begins_with("puerto_agua"): rec_ducto = "agua"
						elif puerto_fin["tipo_puerto"].begins_with("puerto_crudo"): rec_ducto = "crudo"
						elif puerto_fin["tipo_puerto"].begins_with("puerto_combustible"): rec_ducto = "combustible"

					if rec_puerto != "" and (rec_ducto == "" or rec_puerto != rec_ducto):
						resultado.valido = false
						resultado.motivo = "Trazado inválido: la tubería invade el espacio reservado del puerto de %s." % rec_puerto
						return resultado

		celdas_ducto.append(celda_tentativa)

	resultado.celdas_ducto = celdas_ducto
	resultado["nodos_ducto"] = nodos_ducto
	resultado["tramos"] = tramos
	resultado["tramos_diagonales"] = tramos_diagonales
	resultado["indices_diagonales"] = indices_diagonales
	resultado["indices_intermedios"] = indices_intermedios_totales

	# 5. Generar columnas verticales desde el suelo hasta justo debajo del ducto:
	var celdas_columna: Array[Vector3i] = []
	for idx in indices_columna:
		var p: Vector2i = puntos_2d[idx]
		var y_ducto: int = celdas_ducto[idx].y
		var h_suelo: int = mundo.altura_en(p.x, p.y) if mundo.has_method("altura_en") else 0
		for y_col in range(h_suelo + 1, y_ducto):
			celdas_columna.append(Vector3i(p.x, y_col, p.y))

	resultado.celdas_columna = celdas_columna

	# 6. Calcular costo de materiales:
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
func construir_tramo(tipo: String, geom: Dictionary, mundo: Object, id_existente: int = -1) -> int:
	if not geom.get("valido", false):
		return -1

	var id: int = id_existente if id_existente > 0 else _siguiente_id_red
	if id_existente <= 0:
		_siguiente_id_red += 1

	var bloque_c: String = TIPOS[tipo]["bloque_columna"]

	var celdas_d: Array = geom["celdas_ducto"]
	var celdas_c: Array = geom["celdas_columna"]
	var nodos_d: Array = geom.get("nodos_ducto", [])
	var tramos_a_crear: Array = geom.get("tramos", geom.get("tramos_diagonales", []))

	# 1. Colocar columnas en mundo
	for col: Vector3i in celdas_c:
		mundo.colocar_bloque(col, bloque_c, true)
		columnas[col] = id
		var xz := Vector2i(col.x, col.z)
		columnas_xz[xz] = columnas_xz.get(xz, 0) + 1

	# 2. Colocar bloques de ducto en mundo (solo en nodos ancla: lineal / quiebre / extremos)
	if not nodos_d.is_empty():
		for nodo: Dictionary in nodos_d:
			var c: Vector3i = nodo["celda"]
			var tipo_b: String = nodo["tipo_bloque"]
			mundo.colocar_bloque(c, tipo_b, true)
	else:
		var bloque_d: String = TIPOS[tipo]["bloque_ducto_lineal"]
		var indices_diag: Dictionary = geom.get("indices_diagonales", {})
		for i in range(celdas_d.size()):
			if not indices_diag.has(i):
				mundo.colocar_bloque(celdas_d[i], bloque_d, true)

	# 3. Registrar todas las celdas en celda_a_red para topología y simulación
	var registradas: Array[Vector3i] = []
	if red_a_celdas.has(id):
		registradas.append_array(red_a_celdas[id])
	for c: Vector3i in celdas_d:
		celda_a_red[c] = id
		if not registradas.has(c):
			registradas.append(c)
		# Marcar que sobre el ducto no caminan colonos
		if mundo != null and mundo.has_method("registrar_edificio"):
			mundo.celda_sobre_techo[c + Vector3i(0, 1, 0)] = id

	# 4. Generar tramos continuos (vigas de sección 1x1, H=1) que pivotan verticalmente entre centros
	var infos_creadas: Array[Dictionary] = []
	for tramo: Dictionary in tramos_a_crear:
		var c_a: Vector3
		var c_b: Vector3
		if mundo != null and mundo.has_method("map_to_local"):
			c_a = mundo.map_to_local(tramo["inicio"])
			c_b = mundo.map_to_local(tramo["fin"])
		else:
			c_a = Vector3(tramo["inicio"].x + 0.5, tramo["inicio"].y + 0.5, tramo["inicio"].z + 0.5)
			c_b = Vector3(tramo["fin"].x + 0.5, tramo["fin"].y + 0.5, tramo["fin"].z + 0.5)

		var dir_total := c_b - c_a
		var len_total := dir_total.length()
		if len_total < 0.001:
			continue

		var u := dir_total / len_total
		var d_h := Vector3(dir_total.x, 0.0, dir_total.z)
		var u_h := d_h.normalized() if d_h.length_squared() > 0.0001 else Vector3.FORWARD
		var w := Vector3.UP.cross(u_h).normalized()
		var v := u.cross(w).normalized()

		# 8 vértices del tramo extruido entre los centros c_a y c_b
		# En el centro del bloque A (c_a):
		var v0 := c_a - w * 0.5 - v * 0.5
		var v1 := c_a + w * 0.5 - v * 0.5
		var v2 := c_a + w * 0.5 + v * 0.5
		var v3 := c_a - w * 0.5 + v * 0.5

		# En el centro del bloque B (c_b):
		var v4 := c_b - w * 0.5 - v * 0.5
		var v5 := c_b + w * 0.5 - v * 0.5
		var v6 := c_b + w * 0.5 + v * 0.5
		var v7 := c_b - w * 0.5 + v * 0.5

		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

		var mat := StandardMaterial3D.new()
		if tipo == "acueducto":
			mat.albedo_color = Color(0.7, 0.65, 0.55)
		else:
			mat.albedo_color = Color(0.35, 0.38, 0.42)
		mat.roughness = 0.9
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		st.set_material(mat)

		# 6 caras en orden CCW visto desde afuera (normales hacia el exterior) con UVs longitudinales:
		var quads_info := [
			[[v3, v7, v6, v2], [Vector2(0.0, 0.0), Vector2(len_total, 0.0), Vector2(len_total, 1.0), Vector2(0.0, 1.0)]], # Superior (+v)
			[[v0, v1, v5, v4], [Vector2(0.0, 0.0), Vector2(0.0, 1.0), Vector2(len_total, 1.0), Vector2(len_total, 0.0)]], # Inferior (-v)
			[[v0, v4, v7, v3], [Vector2(0.0, 0.0), Vector2(len_total, 0.0), Vector2(len_total, 1.0), Vector2(0.0, 1.0)]], # Lateral izquierda (-w)
			[[v1, v2, v6, v5], [Vector2(0.0, 0.0), Vector2(0.0, 1.0), Vector2(len_total, 1.0), Vector2(len_total, 0.0)]], # Lateral derecha (+w)
			[[v0, v3, v2, v1], [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]],             # Tapa A (-u)
			[[v4, v5, v6, v7], [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]],             # Tapa B (+u)
		]
		for item in quads_info:
			var q: Array = item[0]
			var q_uvs: Array = item[1]
			var n: Vector3 = (q[1] - q[0]).cross(q[2] - q[0]).normalized()
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_normal(n)
				st.set_uv(q_uvs[idx])
				st.add_vertex(q[idx])

		var mesh_inst := MeshInstance3D.new()
		mesh_inst.mesh = st.commit()

		var body := StaticBody3D.new()
		body.name = "DuctoTramo_%d_%d" % [id, infos_creadas.size()]
		body.add_child(mesh_inst)

		var col_shape := CollisionShape3D.new()
		var convex_shape := ConvexPolygonShape3D.new()
		convex_shape.points = PackedVector3Array([v0, v1, v2, v3, v4, v5, v6, v7])
		col_shape.shape = convex_shape
		body.add_child(col_shape)

		body.transform = Transform3D.IDENTITY

		if mundo != null and mundo.has_method("add_child"):
			mundo.add_child(body)

		# Celdas asociadas a este tramo específico
		var celdas_asoc: Array[Vector3i] = [tramo["inicio"], tramo["fin"]]
		for idx_inter in tramo.get("indices", []):
			if idx_inter < celdas_d.size():
				celdas_asoc.append(celdas_d[idx_inter])
		for col in celdas_c:
			if (col.x == tramo["inicio"].x and col.z == tramo["inicio"].z) or (col.x == tramo["fin"].x and col.z == tramo["fin"].z):
				celdas_asoc.append(col)

		infos_creadas.append({
			"nodo": body,
			"celdas": celdas_asoc,
		})

	if not infos_creadas.is_empty():
		if not nodos_diagonales.has(id):
			nodos_diagonales[id] = []
		nodos_diagonales[id].append_array(infos_creadas)

	red_a_celdas[id] = registradas
	tipo_por_red[id] = tipo
	canalizaciones_cambiadas.emit()
	return id


## Elimina las celdas especificadas y actualiza la red.
func quitar_celdas(celdas: Array, mundo: Object = null) -> void:
	var redes_afectadas: Dictionary = {}
	for celda: Vector3i in celdas:
		if celda_a_red.has(celda):
			var id: int = celda_a_red[celda]
			redes_afectadas[id] = true
			celda_a_red.erase(celda)
			if red_a_celdas.has(id):
				red_a_celdas[id].erase(celda)
		else:
			for id in red_a_celdas:
				if red_a_celdas[id].has(celda):
					redes_afectadas[id] = true
					red_a_celdas[id].erase(celda)
		if columnas.has(celda):
			var id_c: int = columnas[celda]
			redes_afectadas[id_c] = true
			columnas.erase(celda)
			var xz := Vector2i(celda.x, celda.z)
			if columnas_xz.has(xz):
				columnas_xz[xz] -= 1
				if columnas_xz[xz] <= 0:
					columnas_xz.erase(xz)
		if mundo != null:
			if mundo.has_method("set_cell_item"):
				mundo.set_cell_item(celda, GridMap.INVALID_CELL_ITEM)
			if mundo.has_method("minar_bloque"):
				mundo.minar_bloque(celda)
			var cp = mundo.get("celdas_pagadas")
			if cp is Dictionary:
				cp.erase(celda)
			var cj = mundo.get("colocado_por_jugador")
			if cj is Dictionary:
				cj.erase(celda)
			var ct = mundo.get("celda_sobre_techo")
			if ct is Dictionary:
				ct.erase(celda)
				ct.erase(celda + Vector3i(0, 1, 0))

	# Borrado de tramos diagonales:
	for id_r in redes_afectadas:
		if nodos_diagonales.has(id_r):
			var restantes: Array = []
			for item in nodos_diagonales[id_r]:
				var nodo: Node3D = item.get("nodo", null) if item is Dictionary else item
				var celdas_tramo: Array = item.get("celdas", []) if item is Dictionary else []
				var destruido := false
				if (red_a_celdas.has(id_r) and red_a_celdas[id_r].is_empty()) or celdas_tramo.is_empty():
					destruido = true
				else:
					for c in celdas:
						if celdas_tramo.has(c):
							destruido = true
							break
				if destruido:
					if is_instance_valid(nodo):
						nodo.queue_free()
				else:
					restantes.append(item)
			if restantes.is_empty() or (red_a_celdas.has(id_r) and red_a_celdas[id_r].is_empty()):
				nodos_diagonales.erase(id_r)
			else:
				nodos_diagonales[id_r] = restantes

		# Si la red quedó sin celdas de ducto, eliminarla por completo
		if red_a_celdas.has(id_r) and red_a_celdas[id_r].is_empty():
			red_a_celdas.erase(id_r)
			tipo_por_red.erase(id_r)
			recurso_por_red.erase(id_r)
			cancelar_derrame_de_red(id_r, mundo)

	# Limpiar puertos desconectados
	var puertos_a_eliminar: Array[Vector3i] = []
	for p: Vector3i in puertos_conectados:
		var tiene_ducto_adyacente := false
		var id_p: int = puertos_conectados[p]
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					if celda_a_red.get(p + Vector3i(dx, dy, dz), -1) == id_p:
						tiene_ducto_adyacente = true
						break
				if tiene_ducto_adyacente:
					break
		if not tiene_ducto_adyacente:
			puertos_a_eliminar.append(p)
	for p in puertos_a_eliminar:
		puertos_conectados.erase(p)
		tipo_por_puerto.erase(p)

	canalizaciones_cambiadas.emit()

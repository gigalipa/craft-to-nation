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
## nodos_diagonales: int id_red -> Array[Node3D] (mallas diagonales continuas)
var nodos_diagonales: Dictionary = {}

var _siguiente_id_red := 1


var tipo_por_puerto: Dictionary = {} # Vector3i -> String


func reiniciar() -> void:
	for id_r in nodos_diagonales:
		for nodo in nodos_diagonales[id_r]:
			if is_instance_valid(nodo):
				nodo.queue_free()
	nodos_diagonales.clear()
	celda_a_red.clear()
	red_a_celdas.clear()
	tipo_por_red.clear()
	recurso_por_red.clear()
	columnas.clear()
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
	tipo_por_puerto[celda_puerto] = tipo_puerto
	return true


func destinos_de_puerto_salida(celda_puerto_salida: Vector3i) -> Array[Vector3i]:
	var destinos: Array[Vector3i] = []
	if not puertos_conectados.has(celda_puerto_salida):
		return destinos
	var id_red: int = puertos_conectados[celda_puerto_salida]
	for p: Vector3i in puertos_conectados:
		if p == celda_puerto_salida:
			continue
		if puertos_conectados[p] == id_red:
			var tipo_p: String = tipo_por_puerto.get(p, "")
			if tipo_p.ends_with("_in"):
				destinos.append(p)
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
		var ultimo: Vector3i = celdas[-1]
		if not puertos_conectados.has(ultimo):
			abiertos.append(ultimo)
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
	for d: Vector3i in derrames_activos:
		if celda_a_red.get(d, -1) == id_red or red_a_celdas.get(id_red, []).has(d):
			return "derrame"
	var tipo_p: String = tipo_por_puerto.get(celda_puerto, "")
	if tipo_p.ends_with("_out"):
		var destinos: Array = destinos_de_puerto_salida(celda_puerto)
		if destinos.is_empty():
			return "derrame"
		return "conectado"
	return "conectado"


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

	indices_ancla.sort()
	indices_columna.sort()

	# 2. Calcular alturas de las cimas de las columnas / anclas:
	var altura_cima: Dictionary = {} # int (índice ancla) -> int (Y_ducto)
	for idx in indices_ancla:
		if idx == 0 and puerto_inicio.get("existe", false):
			altura_cima[0] = puerto_inicio["altura"]
		elif idx == n - 1 and puerto_fin.get("existe", false):
			altura_cima[n - 1] = puerto_fin["altura"]
		else:
			var p: Vector2i = puntos_2d[idx]
			var h_suelo: int = mundo.altura_en(p.x, p.y) if mundo.has_method("altura_en") else 0
			altura_cima[idx] = h_suelo + ALTURA_DUCTO_RELATIVA

	# 3. Interpolar alturas de ducto entre anclas contiguas y detectar tramos diagonales:
	var alturas_ducto: Array[int] = []
	alturas_ducto.resize(n)
	var tramos_diagonales: Array[Dictionary] = []
	var indices_diagonales: Dictionary = {}

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
				if es_diagonal:
					indices_diagonales[k] = true
					indices_intermedios.append(k)
			if es_diagonal:
				var p_a: Vector2i = puntos_2d[idx_a]
				var p_b: Vector2i = puntos_2d[idx_b]
				tramos_diagonales.append({
					"inicio": Vector3i(p_a.x, y_a, p_a.y),
					"fin": Vector3i(p_b.x, y_b, p_b.y),
					"tipo": tipo,
					"indices": indices_intermedios,
				})

	# 4. Generar celdas de ducto con detección de cruce a desnivel (+1 cota si ya hay canalización)
	var celdas_ducto: Array[Vector3i] = []
	for i in range(n):
		var p: Vector2i = puntos_2d[i]
		var y: int = alturas_ducto[i]
		var celda_tentativa := Vector3i(p.x, y, p.y)
		# Verificar si hay canalización preexistente a la misma cota
		var tipo_existente: String = mundo.obtener_tipo(celda_tentativa) if mundo.has_method("obtener_tipo") else ""
		if tipo_existente == "acueducto" or tipo_existente == "tuberia" or celda_a_red.has(celda_tentativa):
			# Sobre-elevar 1 bloque para pasar por encima
			celda_tentativa.y += 1
		celdas_ducto.append(celda_tentativa)

	resultado.celdas_ducto = celdas_ducto
	resultado["tramos_diagonales"] = tramos_diagonales
	resultado["indices_diagonales"] = indices_diagonales

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
	var indices_diagonales: Dictionary = geom.get("indices_diagonales", {})
	var tramos_diagonales: Array = geom.get("tramos_diagonales", [])

	# Colocar columnas
	for col: Vector3i in celdas_c:
		mundo.colocar_bloque(col, bloque_c, true)
		columnas[col] = id

	# Colocar ductos (omitiendo celdas intermedias del vano en tramos diagonales)
	var registradas: Array[Vector3i] = []
	for i in range(celdas_d.size()):
		var c: Vector3i = celdas_d[i]
		if not indices_diagonales.has(i):
			mundo.colocar_bloque(c, bloque_d, true)
		celda_a_red[c] = id
		registradas.append(c)
		# Marcar que sobre el ducto no caminan colonos
		if mundo.has_method("registrar_edificio"):
			mundo.celda_sobre_techo[c + Vector3i(0, 1, 0)] = id

	# Generar tramos diagonales continuos entre columnas con cambio de cota
	var nodos_creados: Array[Node3D] = []
	for tramo: Dictionary in tramos_diagonales:
		var c_a: Vector3
		var c_b: Vector3
		if mundo != null and mundo.has_method("map_to_local"):
			c_a = mundo.map_to_local(tramo["inicio"])
			c_b = mundo.map_to_local(tramo["fin"])
		else:
			c_a = Vector3(tramo["inicio"].x + 0.5, tramo["inicio"].y + 0.5, tramo["inicio"].z + 0.5)
			c_b = Vector3(tramo["fin"].x + 0.5, tramo["fin"].y + 0.5, tramo["fin"].z + 0.5)

		var d_h := Vector3(c_b.x - c_a.x, 0.0, c_b.z - c_a.z)
		var u_h := d_h.normalized() if d_h.length_squared() > 0.0001 else Vector3.FORWARD

		var f_a := c_a + u_h * 0.5
		var f_b := c_b - u_h * 0.5

		var v := f_b - f_a
		var long_neta := v.length()
		var dir := v.normalized()
		var long_total := long_neta + 0.2
		var centro := (f_a + f_b) * 0.5

		var eje_z := dir
		var eje_x := Vector3.UP.cross(eje_z).normalized()
		if eje_x.length_squared() < 0.001:
			eje_x = Vector3.RIGHT
		var eje_y := eje_z.cross(eje_x).normalized()
		var basis_diag := Basis(eje_x, eje_y, eje_z)
		var xform := Transform3D(basis_diag, centro)

		var body := StaticBody3D.new()
		body.name = "DuctoDiagonal_%d_%d" % [id, nodos_creados.size()]

		var mesh_inst := MeshInstance3D.new()
		var malla := BoxMesh.new()
		malla.size = Vector3(1.0, 1.0, long_total)
		var mat := StandardMaterial3D.new()
		if tipo == "acueducto":
			mat.albedo_color = Color(0.7, 0.65, 0.55)
		else:
			mat.albedo_color = Color(0.35, 0.38, 0.42)
		mat.roughness = 0.9
		malla.material = mat
		mesh_inst.mesh = malla
		body.add_child(mesh_inst)

		var col_shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(1.0, 1.0, long_total)
		col_shape.shape = box_shape
		body.add_child(col_shape)

		body.transform = xform

		if mundo != null and mundo.has_method("add_child"):
			mundo.add_child(body)
		nodos_creados.append(body)

	if not nodos_creados.is_empty():
		nodos_diagonales[id] = nodos_creados

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
		if columnas.has(celda):
			var id_c: int = columnas[celda]
			redes_afectadas[id_c] = true
			columnas.erase(celda)
		if mundo != null and mundo.has_method("minar_bloque"):
			mundo.minar_bloque(celda)

	for id_r in redes_afectadas:
		if nodos_diagonales.has(id_r):
			for nodo in nodos_diagonales[id_r]:
				if is_instance_valid(nodo):
					nodo.queue_free()
			nodos_diagonales.erase(id_r)

	canalizaciones_cambiadas.emit()


extends RefCounted

## Construye instantáneamente los tramos de vía ya confirmados por el
## trazador (ver spec de vías Sección 5) — RefCounted puro, sin nodos,
## probado con un mundo falso (mismo patrón que NiveladorTerreno/
## Construccion). No decide el trazado (eso es TrazadorVias.gd) ni el
## modo de la cámara (CamaraCenital.gd): solo transforma una lista de
## vértices ya aceptada en cambios reales sobre "mundo" y en registros de
## Vias.gd.

const NiveladorVia = preload("res://scripts/NiveladorVia.gd")

const TIPO_VIA := "tierra_pisada"


## Intenta construir la vía que pasa por "vertices" (en orden, sin
## vértices consecutivos repetidos). "mundo" necesita altura_en(x,z),
## obtener_tipo(celda), colocar_bloque(celda,tipo,por_jugador),
## talar_bloque_de_arbol(celda,dano), eliminar_follaje(celda),
## set_cell_item(celda,id,orientacion), id_de_tipo(tipo) — VoxelWorld
## real los tiene todos (id_de_tipo() nuevo, ver Task 5) — y
## colocado_por_jugador, un Dictionary ESCRIBIBLE (esta función escribe
## directo ahí para cada cuña colocada). "choca" es
## Callable(columnas_absolutas: Array[Vector2i]) -> bool, inyectada por
## el llamador (CamaraCenital._huella_choca_con_otro_puesto — ver spec
## Sección 6) para no acoplar esta clase a Recoleccion/Construccion.
## Devuelve false (nada se construye) si "vertices" tiene menos de 2
## elementos o si "choca" rechaza cualquier columna tocada.
## Desglosa la construcción de la vía en un plan detallado de pasos (celdas y cuñas).
## Devuelve {} si vertices tiene menos de 2 elementos o si "choca" rechaza cualquier columna.
static func planificar(mundo: Object, vertices: Array[Vector2i], choca: Callable) -> Dictionary:
	if vertices.size() < 2:
		return {}

	var nivelador := NiveladorVia.new(mundo)
	var niveles: Array[int] = nivelador.niveles_efectivos(vertices)

	var columnas_totales: Array[Vector2i] = []
	for v in vertices:
		for col in nivelador.bloque_de_vertice(v):
			if not columnas_totales.has(col):
				columnas_totales.append(col)

	var planes: Array[Dictionary] = []
	var notches: Array[Dictionary] = []
	var solapes_totales: Array[Vector2i] = []
	for i in range(vertices.size() - 1):
		var plan_trans: Dictionary = nivelador.plan_transicion(vertices[i], vertices[i + 1], niveles[i], niveles[i + 1])
		planes.append(plan_trans)
		notches.append_array(nivelador.notches_de_paso(vertices[i], vertices[i + 1]))
		for col in nivelador.columnas_solape(vertices[i], vertices[i + 1]):
			if not solapes_totales.has(col):
				solapes_totales.append(col)
		if plan_trans.is_empty():
			continue
		for dato: Dictionary in plan_trans["cunas"]:
			if not columnas_totales.has(dato["columna"]):
				columnas_totales.append(dato["columna"])

	if choca.call(columnas_totales):
		return {}

	var objetivo_relleno: Dictionary = {}  # Vector2i -> int
	for i in range(vertices.size()):
		var nivel: int = niveles[i]
		for col in nivelador.bloque_de_vertice(vertices[i]):
			objetivo_relleno[col] = maxi(objetivo_relleno.get(col, nivel), nivel)

	var cunas: Dictionary = {}  # Vector2i -> Dictionary
	for plan_trans: Dictionary in planes:
		if plan_trans.is_empty():
			continue
		for col in plan_trans["relleno_extra"]:
			objetivo_relleno[col] = maxi(objetivo_relleno.get(col, 0), plan_trans["y_base"])
		for dato: Dictionary in plan_trans["cunas"]:
			cunas[dato["columna"]] = {"y": plan_trans["y_base"], "tipo": dato["tipo"], "direccion_alta": dato["direccion_alta"]}
	for col in cunas:
		objetivo_relleno.erase(col)

	var notches_filtrados: Dictionary = {}
	for dato: Dictionary in notches:
		var col: Vector2i = dato["columna"]
		if solapes_totales.has(col):
			continue
		if objetivo_relleno.has(col):
			notches_filtrados[col] = dato["esquina_omitida"]

	var pasos: Array[Dictionary] = []
	var columnas_agregadas: Dictionary = {}

	var agregar_paso_col := func(col: Vector2i) -> void:
		if columnas_agregadas.has(col):
			return
		columnas_agregadas[col] = true
		if cunas.has(col):
			var datos: Dictionary = cunas[col]
			pasos.append({
				"tipo": "cuna",
				"columna": col,
				"y": datos["y"],
				"celda": Vector3i(col.x, datos["y"] + 1, col.y),
				"cuna_tipo": datos["tipo"],
				"direccion_alta": datos["direccion_alta"]
			})
		elif objetivo_relleno.has(col):
			var y: int = objetivo_relleno[col]
			var p := {
				"tipo": "nivelar",
				"columna": col,
				"y": y,
				"celda": Vector3i(col.x, y, col.y)
			}
			if notches_filtrados.has(col):
				p["notch"] = notches_filtrados[col]
			pasos.append(p)

	for i in range(vertices.size()):
		for col in nivelador.bloque_de_vertice(vertices[i]):
			agregar_paso_col.call(col)
		if i < planes.size():
			var plan_trans: Dictionary = planes[i]
			if not plan_trans.is_empty():
				for dato: Dictionary in plan_trans["cunas"]:
					agregar_paso_col.call(dato["columna"])
				for col in plan_trans["relleno_extra"]:
					agregar_paso_col.call(col)

	for col in objetivo_relleno:
		agregar_paso_col.call(col)
	for col in cunas:
		agregar_paso_col.call(col)

	return {
		"vertices": vertices,
		"columnas": columnas_totales,
		"pasos": pasos
	}


## Ejecuta un único paso de obra vial (nivelar o cuña) y registra la celda en Vias.gd.
## Devuelve la celda de soporte resultante (Vector3i).
static func ejecutar_paso(mundo: Object, paso: Dictionary) -> Vector3i:
	var col: Vector2i = paso["columna"]
	if paso["tipo"] == "nivelar":
		_nivelar_columna(mundo, col, paso["y"])
		var celda: Vector3i = paso["celda"]
		if paso.has("notch"):
			Vias.marcar_notch(celda, paso["notch"])
		Vias.agregar([celda], TIPO_VIA)
		return celda
	elif paso["tipo"] == "cuna":
		_nivelar_columna(mundo, col, paso["y"])
		var celda_cuna: Vector3i = paso["celda"]
		mundo.set_cell_item(celda_cuna, mundo.id_de_tipo(paso["cuna_tipo"]), _orientacion(paso["direccion_alta"], paso["cuna_tipo"]))
		mundo.colocado_por_jugador[celda_cuna] = true
		Vias.agregar([celda_cuna], TIPO_VIA)
		return celda_cuna
	return Vector3i.ZERO


## Intenta construir la vía que pasa por "vertices" (en orden, sin
## vértices consecutivos repetidos). Construcción instantánea completa.
## Devuelve false si "vertices" tiene menos de 2 elementos o si "choca" rechaza.
static func construir(mundo: Object, vertices: Array[Vector2i], choca: Callable) -> bool:
	var plan := planificar(mundo, vertices, choca)
	if plan.is_empty():
		return false
	for paso: Dictionary in plan["pasos"]:
		ejecutar_paso(mundo, paso)
	return true



## Rellena "col" con "tierra" desde la superficie actual hasta
## "y_objetivo" (nunca cava). Cualquier árbol/follaje en el camino se
## tala primero (spec Sección 5): mundo.altura_en() ya ignora los
## árboles al calcular la superficie real, así que su tronco nunca queda
## por debajo de la superficie. Siempre revisa al menos la celda
## inmediatamente encima de la superficie, aunque no haga falta relleno
## (el caso normal de una vía recta atravesando un bosque en terreno ya
## nivelado): esa celda solo se tala si tiene árbol/follaje, nunca se
## rellena con tierra si ya está a la altura objetivo o por encima.
static func _nivelar_columna(mundo: Object, col: Vector2i, y_objetivo: int) -> void:
	var y_actual: int = mundo.altura_en(col.x, col.y)
	var techo: int = maxi(y_objetivo, y_actual + 1)
	for y in range(y_actual + 1, techo + 1):
		var celda := Vector3i(col.x, y, col.y)
		var tipo: String = mundo.obtener_tipo(celda)
		if tipo == "madera":
			mundo.talar_bloque_de_arbol(celda, 999)
		elif tipo == "follaje":
			mundo.eliminar_follaje(celda)
		if y <= y_objetivo:
			mundo.colocar_bloque(celda, "tierra", true)


## Dirección de referencia con la que se modeló cada tipo de cuña (ver
## Task 4 y el sistema de rampa diagonal completo, geometría exacta de
## docs/Rampa_CtN.obj): "cuna_recta" con su lado alto hacia +Z;
## "cuna_esquina" con su esquina alta hacia +X+Z; las 4 piezas del
## sistema de rampa diagonal (cuna_diag_bajo/arriba/lat_izq/lat_der) se
## modelaron juntas para UNA sola direccion_alta de referencia, (1,-1) —
## deben rotar SIEMPRE las 4 con el mismo ángulo entre esa referencia y
## la direccion_alta real, para que la rampa completa gire como una sola
## unidad (ver spec de vías, decisión del usuario jugando en vivo,
## 2026-09-22).
const REFERENCIA_POR_TIPO := {
	"cuna_recta": Vector2(0, 1),
	"cuna_esquina": Vector2(1, 1),
	"cuna_diag_bajo": Vector2(1, -1),
	"cuna_diag_arriba": Vector2(1, -1),
	"cuna_diag_lat_izq": Vector2(1, -1),
	"cuna_diag_lat_der": Vector2(1, -1),
	"diag_lat": Vector2(1, -1),
}


## Índice de orientación de GridMap (0-23) para que el lado ALTO de una
## cuña de tipo "tipo" quede orientado hacia "direccion_alta" (Vector2i
## en XZ) — usar la referencia equivocada da un ángulo que no es múltiplo
## de 90° y hace que get_orthogonal_index_from_basis() falle (ver I1 de
## la revisión final). ponytail: el signo de la rotación se fija
## visualmente en el editor real (Task 9); si sale espejado, invertir
## "-angulo" a "angulo" aquí es el único cambio necesario.
static func _orientacion(direccion_alta: Vector2i, tipo: String) -> int:
	var referencia: Vector2 = REFERENCIA_POR_TIPO[tipo]
	var angulo: float = referencia.angle_to(Vector2(direccion_alta.x, direccion_alta.y))
	# get_orthogonal_index_from_basis() no es estático en Godot 4.7: hace
	# falta una instancia de GridMap (descartable, nunca en el árbol) para
	# llamarlo — se libera enseguida, GridMap no es RefCounted.
	var gridmap_descartable := GridMap.new()
	var indice: int = gridmap_descartable.get_orthogonal_index_from_basis(Basis(Vector3.UP, -angulo))
	gridmap_descartable.free()
	return indice

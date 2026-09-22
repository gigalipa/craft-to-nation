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
static func construir(mundo: Object, vertices: Array[Vector2i], choca: Callable) -> bool:
	if vertices.size() < 2:
		return false

	var nivelador := NiveladorVia.new(mundo)
	var columnas_totales: Array[Vector2i] = []
	for v in vertices:
		for col in nivelador.bloque_de_vertice(v):
			if not columnas_totales.has(col):
				columnas_totales.append(col)

	if choca.call(columnas_totales):
		return false

	var objetivo_relleno: Dictionary = {}  # Vector2i -> int
	for v in vertices:
		var nivel: int = nivelador.nivel_de_bloque(v)
		for col in nivelador.bloque_de_vertice(v):
			objetivo_relleno[col] = maxi(objetivo_relleno.get(col, nivel), nivel)

	var cunas: Dictionary = {}  # Vector2i -> Dictionary
	for i in range(vertices.size() - 1):
		var plan: Dictionary = nivelador.plan_transicion(vertices[i], vertices[i + 1])
		if plan.is_empty():
			continue
		for col in plan["relleno_extra"]:
			objetivo_relleno[col] = maxi(objetivo_relleno.get(col, 0), plan["y_base"])
		for dato: Dictionary in plan["cunas"]:
			cunas[dato["columna"]] = {"y": plan["y_base"], "tipo": dato["tipo"], "direccion_alta": dato["direccion_alta"]}
	for col in cunas:
		objetivo_relleno.erase(col)

	var celdas_soporte: Array[Vector3i] = []
	for col in objetivo_relleno:
		var y: int = objetivo_relleno[col]
		_nivelar_columna(mundo, col, y)
		celdas_soporte.append(Vector3i(col.x, y, col.y))
	for col in cunas:
		var datos: Dictionary = cunas[col]
		_nivelar_columna(mundo, col, datos["y"])
		# La cuña va UNA celda por encima de "y" (= y_base, la superficie del
		# lado bajo): su cara inferior descansa sobre la cara superior real
		# del lado bajo (mundo Y = y_base+1), no sobre la celda de piso en sí
		# (ver C3 de la revisión final — colocarla en "y" cavaba una zanja de
		# un bloque en vez de tender un puente).
		var celda_cuna := Vector3i(col.x, datos["y"] + 1, col.y)
		mundo.set_cell_item(celda_cuna, mundo.id_de_tipo(datos["tipo"]), _orientacion(datos["direccion_alta"], datos["tipo"] == "cuna_esquina"))
		mundo.colocado_por_jugador[celda_cuna] = true
		celdas_soporte.append(celda_cuna)

	Vias.agregar(celdas_soporte, TIPO_VIA)
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


## Índice de orientación de GridMap (0-23) para que el lado ALTO de una
## cuña quede orientado hacia "direccion_alta" (Vector2i en XZ). La
## referencia depende de QUÉ pieza se orienta (ver Task 4): "cuna_recta"
## se modeló con su lado alto hacia +Z, pero "cuna_esquina" se modeló con
## su esquina alta hacia +X+Z — usar la referencia de cuna_recta para una
## cuna_esquina da un ángulo de 45°, que no es múltiplo de 90° y hace que
## get_orthogonal_index_from_basis() falle (ver I1 de la revisión final).
## ponytail: el signo de la rotación se fija visualmente en el editor
## real (Task 9); si sale espejado, invertir "-angulo" a "angulo" aquí es
## el único cambio necesario.
static func _orientacion(direccion_alta: Vector2i, diagonal: bool) -> int:
	var referencia := Vector2(1, 1) if diagonal else Vector2(0, 1)
	var angulo: float = referencia.angle_to(Vector2(direccion_alta.x, direccion_alta.y))
	# get_orthogonal_index_from_basis() no es estático en Godot 4.7: hace
	# falta una instancia de GridMap (descartable, nunca en el árbol) para
	# llamarlo — se libera enseguida, GridMap no es RefCounted.
	var gridmap_descartable := GridMap.new()
	var indice: int = gridmap_descartable.get_orthogonal_index_from_basis(Basis(Vector3.UP, -angulo))
	gridmap_descartable.free()
	return indice

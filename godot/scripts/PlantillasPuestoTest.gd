extends Node

## Pruebas de PlantillasPuesto.gd (datos y rotación) y del ciclo real de un
## puesto como edificio completo: estampar, deconstruir (el baúl sale primero,
## la obra guarda su metadata) y volver a completar, sobre un VoxelWorld real
## sin _ready() (mismo patrón que FantasmasPermeablesTest.gd).

const PlantillasPuesto = preload("res://scripts/PlantillasPuesto.gd")
const VoxelWorld = preload("res://scripts/VoxelWorld.gd")

const TIPOS := ["mina", "caza_recoleccion", "maderero", "pesca_frutos_mar"]


func _ready() -> void:
	ejecutar_pruebas()


func _mundo() -> Node:
	var mundo: Node = VoxelWorld.new()
	mundo.mesh_library = load("res://assets/BlockLibrary.res")
	mundo.cell_size = Vector3.ONE
	mundo._indexar_biblioteca()
	return mundo


func _huella_esperada(tipo: String) -> Vector2i:
	match tipo:
		"mina":
			return Vector2i(Recoleccion.ANCHO_HUELLA_MINA, Recoleccion.ALTO_HUELLA_MINA)
		"caza_recoleccion":
			return Vector2i(Recoleccion.ANCHO_HUELLA_CAZA_RECOLECCION, Recoleccion.ALTO_HUELLA_CAZA_RECOLECCION)
		"maderero":
			return Vector2i(Recoleccion.ANCHO_HUELLA_MADERERO, Recoleccion.ALTO_HUELLA_MADERERO)
	return Vector2i(Recoleccion.ANCHO_HUELLA_PESCA_FRUTOS_MAR, Recoleccion.ALTO_HUELLA_PESCA_FRUTOS_MAR)


func _primera(celdas: Dictionary, bloque: String) -> Vector3i:
	for celda in celdas:
		if celdas[celda] == bloque:
			return celda
	assert(false, "no hay un bloque " + bloque)
	return Vector3i.ZERO


func ejecutar_pruebas() -> void:
	print("=== TEST 1: la huella de cada plantilla coincide con la del tipo y todas las capas miden lo mismo ===")
	for tipo in TIPOS:
		assert(PlantillasPuesto.dimensiones(tipo) == _huella_esperada(tipo), tipo + ": huella base")
		for capa in PlantillasPuesto.PLANTILLAS[tipo]["capas"]:
			assert(capa.size() == _huella_esperada(tipo).y, tipo + ": filas por capa")
			for fila in capa:
				assert(fila.length() == _huella_esperada(tipo).x, tipo + ": columnas por fila")
		assert(PlantillasPuesto.altura(tipo) >= 2, tipo + ": al menos puerta de 2 bloques")

	print("\n=== TEST 2: cada plantilla tiene una losa de piso sólida (capa 0), una puerta de 2 bloques en la fila frontal justo encima (capa 1) y al menos un baúl ===")
	for tipo in TIPOS:
		var base: Dictionary = PlantillasPuesto.celdas(tipo, 0)
		var puertas := 0
		var baules := 0
		for celda in base:
			if base[celda] == "puerta_inferior":
				puertas += 1
				assert(celda.z == 0 and celda.y == 1, tipo + ": puerta en la fila frontal, una capa sobre la losa de piso")
				assert(base.get(celda + Vector3i(0, 1, 0)) == "puerta_superior", tipo + ": puerta_superior encima")
				assert(base.get(celda - Vector3i(0, 1, 0)) != null, tipo + ": losa de piso (capa 0) bajo la puerta")
			elif base[celda] == "baul":
				baules += 1
		assert(puertas == 1, tipo + ": exactamente una puerta")
		assert(baules >= 1, tipo + ": tiene depósito")

	print("\n=== TEST 3: los 4 giros conservan las celdas dentro de la huella y la celda de servicio queda fuera, frente a la puerta ===")
	for tipo in TIPOS:
		for giros in range(4):
			var h: Vector2i = PlantillasPuesto.huella(tipo, giros)
			var d: Vector2i = PlantillasPuesto.dimensiones(tipo)
			assert(h == (d if giros % 2 == 0 else Vector2i(d.y, d.x)), tipo + ": huella girada")
			var celdas_g: Dictionary = PlantillasPuesto.celdas(tipo, giros)
			for celda in celdas_g:
				assert(celda.x >= 0 and celda.x < h.x and celda.z >= 0 and celda.z < h.y, tipo + ": dentro de la huella girada")
			var puerta: Vector3i = _primera(celdas_g, "puerta_inferior")
			var servicio: Vector2i = PlantillasPuesto.celda_de_servicio(tipo, giros)
			assert(servicio.x < 0 or servicio.x >= h.x or servicio.y < 0 or servicio.y >= h.y, tipo + ": servicio fuera de la huella")
			assert(absi(servicio.x - puerta.x) + absi(servicio.y - puerta.z) == 1, tipo + ": servicio adyacente a la puerta")
			assert(celdas_g.get(PlantillasPuesto.celda_deposito(tipo, giros)) == "baul", tipo + ": la celda del depósito es el baúl")

	print("\n=== TEST 4: la puerta mira a −Z sin girar y a +X con un giro horario; cuatro giros vuelven al inicio ===")
	var mina0: Dictionary = PlantillasPuesto.celdas("mina", 0)
	assert(PlantillasPuesto.celda_de_servicio("mina", 0).y == -1, "sin girar, el servicio queda en z = -1")
	assert(_primera(PlantillasPuesto.celdas("mina", 1), "puerta_inferior").x == 4, "girada 90° horario, la puerta cae en el borde x = 4")
	assert(PlantillasPuesto.celda_de_servicio("mina", 1).x == 5, "y el servicio en x = 5")
	for tipo in TIPOS:
		assert(PlantillasPuesto.celdas(tipo, 4) == PlantillasPuesto.celdas(tipo, 0), tipo + ": 4 giros = 0 giros")
	assert(mina0.size() > 0)

	print("\n=== TEST 5: en_mundo() traslada la plantilla a la esquina y a la altura base (la losa de piso, capa 0) ===")
	var mundo5: Dictionary = PlantillasPuesto.en_mundo("mina", 0, Vector2i(10, 20), 5)
	assert(mundo5.get(Vector3i(12, 5, 20)) == "adobe", "capa 0 (y_base) es la losa de piso")
	assert(mundo5.get(Vector3i(12, 6, 20)) == "puerta_inferior", "puerta en (esquina.x + 2, y_base + 1, esquina.z)")
	assert(mundo5.get(Vector3i(12, 7, 20)) == "puerta_superior")
	assert(mundo5.size() == PlantillasPuesto.celdas("mina", 0).size())

	print("\n=== TEST 6: el extremo de agua de la pesca cambia con el giro (1, 0, 0, 1) ===")
	var indices: Array[int] = []
	for giros in range(4):
		indices.append(PlantillasPuesto.indice_extremo_agua(giros))
	assert(indices == [1, 0, 0, 1], "extremo de agua por giro: " + str(indices))

	print("\n=== TEST 7: todos los bloques de las plantillas existen en la biblioteca del mundo ===")
	var mundo7: Node = _mundo()
	for tipo in TIPOS:
		for bloque in PlantillasPuesto.celdas(tipo, 0).values():
			assert(mundo7._id_por_tipo.has(bloque), "falta el bloque " + bloque)

	print("\n=== TEST 8: un puesto estampado es un edificio completo: no se mina, el baúl sale primero y al volver a completarlo devuelve su metadata ===")
	var mundo8: Node = _mundo()
	var esquina8 := Vector2i(20, 20)
	var celdas8: Dictionary = PlantillasPuesto.en_mundo("maderero", 0, esquina8, 5)
	var id8: int = mundo8.estampar_puesto(celdas8, esquina8)
	assert(mundo8.edificio_metadata[id8]["puesto"] == esquina8)
	for celda in celdas8:
		assert(mundo8.obtener_tipo(celda) == celdas8[celda], "se estampó " + str(celda))
		assert(mundo8.es_celda_estructural(celda), "cuenta como estructura (el overlay de zonas no pinta sobre su techo): " + str(celda))
	var deposito_local: Vector3i = PlantillasPuesto.celda_deposito("maderero", 0)
	var deposito8 := Vector3i(esquina8.x + deposito_local.x, 5 + deposito_local.y, esquina8.y + deposito_local.z)
	assert(mundo8.obtener_tipo(deposito8) == "baul")
	assert(not mundo8.minar_bloque(deposito8), "un puesto no se mina bloque a bloque")
	var paso8: Dictionary = mundo8.procesar_deconstruccion(deposito8)
	assert(paso8["id"] == id8 and not paso8["lista_para_remocion"], "es el edificio del puesto y no está vacío")
	assert(mundo8.obtener_tipo(deposito8) == "fantasma", "el baúl es lo primero en revertirse")
	assert(mundo8.edificio_metadata[id8]["puesto"] == esquina8, "la metadata sobrevive a la deconstrucción")
	var avance8: Dictionary = mundo8.surtir_construccion(deposito8)
	assert(avance8.get("completa", false) and avance8["metadata"]["puesto"] == esquina8, "al completarse, devuelve la metadata del puesto")
	assert(mundo8.obtener_tipo(deposito8) == "baul", "el baúl vuelve")

	print("\n=== TEST 9: la fachada son las 2 columnas delante de todo el lado de la puerta, fuera de la huella, en los 4 giros ===")
	for tipo in TIPOS:
		for giros in range(4):
			var h9: Vector2i = PlantillasPuesto.huella(tipo, giros)
			var fachada9: Array[Vector2i] = PlantillasPuesto.fachada(tipo, giros)
			var servicio9: Vector2i = PlantillasPuesto.celda_de_servicio(tipo, giros)
			var lado9: int = h9.x if servicio9.y < 0 or servicio9.y >= h9.y else h9.y  # largo del lado de la puerta
			assert(fachada9.size() == 2 * lado9, tipo + ": 2 columnas de fondo por todo el lado (" + str(fachada9.size()) + ")")
			assert(fachada9.has(servicio9), tipo + ": incluye la celda de servicio")
			for c9 in fachada9:
				assert(c9.x < 0 or c9.x >= h9.x or c9.y < 0 or c9.y >= h9.y, tipo + ": fuera de la huella")
			var unicas9 := {}
			for c9 in fachada9:
				unicas9[c9] = true
			assert(unicas9.size() == fachada9.size(), tipo + ": sin columnas repetidas")
	assert(PlantillasPuesto.fachada("mina", 0).has(Vector2i(0, -2)) and PlantillasPuesto.fachada("mina", 0).has(Vector2i(4, -1)), "mina sin girar: franja x 0..4, z -2..-1")
	assert(PlantillasPuesto.fachada("mina", 1).has(Vector2i(6, 0)) and PlantillasPuesto.fachada("mina", 1).has(Vector2i(5, 4)), "mina girada un cuarto: franja x 5..6, z 0..4")

	print("\n=== TEST 10: detrás de la puerta hay siempre una celda libre (con 2 de altura) y todo el interior libre es alcanzable desde ella ===")
	for tipo in TIPOS:
		var base10: Dictionary = PlantillasPuesto.celdas(tipo, 0)
		var d10: Vector2i = PlantillasPuesto.dimensiones(tipo)
		var puerta10: Vector3i = _primera(base10, "puerta_inferior")
		var piso10: int = puerta10.y  # capa del piso interior TRANSITABLE (una sobre la losa, capa 0)
		var vestibulo10 := Vector3i(puerta10.x, piso10, puerta10.z + 1)
		assert(not base10.has(vestibulo10) and not base10.has(vestibulo10 + Vector3i(0, 1, 0)), tipo + ": la celda detrás de la puerta debe estar libre (no un baúl ni una pared)")
		# Relleno por inundación desde el vestíbulo sobre las celdas libres del piso interior dentro de la huella.
		var alcanzadas10 := {vestibulo10: true}
		var pendientes10: Array[Vector3i] = [vestibulo10]
		while not pendientes10.is_empty():
			var actual10: Vector3i = pendientes10.pop_back()
			for dir10 in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
				var vecina10: Vector3i = actual10 + dir10
				if vecina10.x < 0 or vecina10.x >= d10.x or vecina10.z < 1 or vecina10.z >= d10.y:
					continue
				if base10.has(vecina10) or alcanzadas10.has(vecina10):
					continue
				alcanzadas10[vecina10] = true
				pendientes10.append(vecina10)
		var libres10 := 0
		for x10 in range(d10.x):
			for z10 in range(1, d10.y):
				var c10 := Vector3i(x10, piso10, z10)
				var techo10: bool = PlantillasPuesto.celdas(tipo, 0).has(Vector3i(x10, PlantillasPuesto.altura(tipo) - 1, z10))
				# libre en el piso interior y con techo encima (es interior, no el muelle abierto)
				if not base10.has(c10) and techo10:
					libres10 += 1
					assert(alcanzadas10.has(c10), tipo + ": celda interior libre inalcanzable " + str(c10))
		assert(libres10 >= 1, tipo + ": tiene interior libre")

	print("\n=== TEST 11: la siderúrgica tiene entrada y salida separadas, en lados opuestos, y la fachada cubre ambos ===")
	assert(PlantillasPuesto.dimensiones("siderurgica") == Vector2i(5, 5))
	assert(PlantillasPuesto.MATERIAL["siderurgica"] == "bloque_piedra")
	var base11: Dictionary = PlantillasPuesto.celdas("siderurgica", 0)
	var puertas11 := 0
	for c11 in base11:
		if base11[c11] == "puerta_inferior":
			puertas11 += 1
	assert(puertas11 == 2, "dos puertas: entrada y salida")
	for giros11 in range(4):
		var h11: Vector2i = PlantillasPuesto.huella("siderurgica", giros11)
		var entrada11: Vector2i = PlantillasPuesto.celda_de_servicio("siderurgica", giros11)
		var salida11: Vector2i = PlantillasPuesto.celda_de_salida("siderurgica", giros11)
		assert(entrada11 != salida11, "entrada y salida son celdas distintas")
		for c11 in [entrada11, salida11]:
			assert(c11.x < 0 or c11.x >= h11.x or c11.y < 0 or c11.y >= h11.y, "las celdas de servicio quedan fuera de la huella")
		assert(absi(entrada11.x - salida11.x) + absi(entrada11.y - salida11.y) == 6, "lados opuestos: 5 de huella + 1")
		var fachada11: Array[Vector2i] = PlantillasPuesto.fachada("siderurgica", giros11)
		assert(fachada11.has(entrada11) and fachada11.has(salida11), "la fachada incluye ambas celdas de servicio")
		assert(fachada11.size() == 20, "2 columnas de fondo por los 5 de cada lado, en ambos lados (%d)" % fachada11.size())
		var guia11: Vector3i = PlantillasPuesto.puerta_de_entrada("siderurgica", giros11)
		assert(PlantillasPuesto.celdas("siderurgica", giros11)[guia11] == "puerta_inferior", "la puerta guía es una puerta inferior")
		assert(absi(guia11.x - entrada11.x) + absi(guia11.z - entrada11.y) == 1, "y es la que da a la celda de servicio de entrada")
	for tipo11 in TIPOS:
		for giros11 in range(4):
			assert(PlantillasPuesto.celda_de_salida(tipo11, giros11) == PlantillasPuesto.celda_de_servicio(tipo11, giros11), tipo11 + ": con una sola puerta, salida == servicio")

	print("\n=== TEST 12: la chimenea de la siderúrgica sobresale del techo y gira con el edificio ===")
	assert(PlantillasPuesto.altura("siderurgica") == 6)
	for giros12 in range(4):
		var tope12: Vector3i = PlantillasPuesto.celda_chimenea("siderurgica", giros12)
		var celdas12: Dictionary = PlantillasPuesto.celdas("siderurgica", giros12)
		assert(celdas12[tope12] == "bloque_piedra", "el tope de la chimenea es un bloque de piedra")
		assert(celdas12[tope12 - Vector3i(0, 1, 0)] == "bloque_piedra" and celdas12[tope12 - Vector3i(0, 2, 0)] == "bloque_piedra", "y se apoya sobre el techo")
		assert(not celdas12.has(tope12 + Vector3i(0, 1, 0)), "nada encima")
	assert(PlantillasPuesto.celda_chimenea("siderurgica", 0) == Vector3i(3, 5, 2))

	print("\n=== TEST 13: las refinerías nuevas (tierras raras, aserradero, carbonera) cumplen lo de toda refinería ===")
	var materiales13 := {}
	for tipo13 in ["refineria_tierras_raras", "aserradero", "carbonera"]:
		materiales13[PlantillasPuesto.MATERIAL[tipo13]] = true
		var base13: Dictionary = PlantillasPuesto.celdas(tipo13, 0)
		var conteo13 := {"puerta_inferior": 0, "vidrio": 0, "baul": 0}
		for c13 in base13:
			if conteo13.has(base13[c13]):
				conteo13[base13[c13]] += 1
		assert(conteo13["puerta_inferior"] == 2, tipo13 + ": puerta de entrada y de salida")
		assert(conteo13["vidrio"] >= 2 and conteo13["baul"] == 1, tipo13 + ": ventanas y un baúl")
		for giros13 in range(4):
			assert(PlantillasPuesto.celda_de_servicio(tipo13, giros13) != PlantillasPuesto.celda_de_salida(tipo13, giros13), tipo13 + ": entrada y salida distintas")
			var tope13: Vector3i = PlantillasPuesto.celda_chimenea(tipo13, giros13)
			var celdas13: Dictionary = PlantillasPuesto.celdas(tipo13, giros13)
			assert(celdas13[tope13] == PlantillasPuesto.MATERIAL[tipo13], tipo13 + ": el indicador de actividad es un bloque de su material")
			assert(not celdas13.has(tope13 + Vector3i(0, 1, 0)), tipo13 + ": nada sobre el indicador")
			assert(tope13.y == PlantillasPuesto.altura(tipo13) - 1)
	assert(materiales13.size() == 3 and not materiales13.has("bloque_piedra"), "cada refinería nueva tiene su material propio, distinto de la siderúrgica")
	assert(PlantillasPuesto.dimensiones("aserradero") == Vector2i(5, 6))

	print("\n=== Las 13 pruebas de PlantillasPuesto pasaron correctamente ===")

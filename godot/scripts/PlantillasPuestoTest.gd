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

	print("\n=== TEST 2: cada plantilla tiene una puerta de 2 bloques en z = 0 y al menos un baúl ===")
	for tipo in TIPOS:
		var base: Dictionary = PlantillasPuesto.celdas(tipo, 0)
		var puertas := 0
		var baules := 0
		for celda in base:
			if base[celda] == "puerta_inferior":
				puertas += 1
				assert(celda.z == 0 and celda.y == 0, tipo + ": puerta a ras de suelo, en la fila frontal")
				assert(base.get(celda + Vector3i(0, 1, 0)) == "puerta_superior", tipo + ": puerta_superior encima")
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

	print("\n=== TEST 5: en_mundo() traslada la plantilla a la esquina y a la altura base ===")
	var mundo5: Dictionary = PlantillasPuesto.en_mundo("mina", 0, Vector2i(10, 20), 5)
	assert(mundo5.get(Vector3i(12, 5, 20)) == "puerta_inferior", "puerta en (esquina.x + 2, y_base, esquina.z)")
	assert(mundo5.get(Vector3i(12, 6, 20)) == "puerta_superior")
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

	print("\n=== Las 9 pruebas de PlantillasPuesto pasaron correctamente ===")

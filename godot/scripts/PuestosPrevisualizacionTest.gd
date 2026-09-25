extends Node

## Pruebas de la evaluación única de la colocación de un puesto
## (CamaraCenital._evaluar_puesto() / _mensaje_rechazo_puesto()): es lo que usan
## a la vez el clic y la previsualización, así que la vista previa no puede
## mentir. Mundo plano real sin _ready() y una CamaraCenital sin árbol (mismo
## patrón que PlantillasPuestoTest.gd). Corre esta escena y revisa el panel
## "Output": debe imprimir todas las pruebas y no lanzar ningún error de assert().

const VoxelWorld = preload("res://scripts/VoxelWorld.gd")
const CamaraCenitalScript = preload("res://scripts/CamaraCenital.gd")
const PlantillasPuesto = preload("res://scripts/PlantillasPuesto.gd")
const NiveladorTerreno = preload("res://scripts/NiveladorTerreno.gd")

const LADO := 40  # el suelo plano cubre x, z en [0, LADO)


func _ready() -> void:
	ejecutar_pruebas()


## Mundo de prueba: suelo de "tierra" a y=0 (altura 0) en LADO x LADO columnas.
func _mundo_plano() -> Node:
	var mundo: Node = VoxelWorld.new()
	mundo.mesh_library = load("res://assets/BlockLibrary.res")
	mundo.cell_size = Vector3.ONE
	mundo._indexar_biblioteca()
	for x in range(LADO):
		for z in range(LADO):
			mundo.colocar_bloque(Vector3i(x, 0, z), "tierra")
	return mundo


## CamaraCenital sin árbol, con el puesto "tipo" activo (huella y giro base).
func _camara(mundo: Node, tipo: String, giros: int = 0) -> Camera3D:
	var camara: Camera3D = CamaraCenitalScript.new()
	camara.mundo = mundo
	camara.nivelador_puesto = NiveladorTerreno.new(CamaraCenitalScript._AlturaSinAgua.new(mundo))
	var huella: Vector2i = PlantillasPuesto.huella(tipo, giros)
	camara._tipo_puesto_activo = tipo
	camara._ancho_puesto_activo = huella.x
	camara._alto_puesto_activo = huella.y
	camara._giros_puesto = giros
	return camara


func ejecutar_pruebas() -> void:
	print("=== TEST 1: una colocación válida trae la plantilla, la fachada y el nivel real ===")
	var mundo: Node = _mundo_plano()
	var camara: Camera3D = _camara(mundo, "mina")
	var esquina := Vector2i(10, 10)
	var ev: Dictionary = camara._evaluar_puesto(esquina)
	assert(camara._mensaje_rechazo_puesto(ev) == "", "sobre suelo plano y libre la colocación es válida, salió: %s" % camara._mensaje_rechazo_puesto(ev))
	assert(ev["y_base"] == 1, "la capa 0 va sobre el suelo (objetivo 0 + 1)")
	assert(ev["giros"] == 0)
	assert(ev["celdas_plantilla"] == PlantillasPuesto.en_mundo("mina", 0, esquina, 1), "la plantilla en su posición real")
	var fachada_rel: Array[Vector2i] = PlantillasPuesto.fachada("mina", 0)
	assert(ev["fachada"].size() == fachada_rel.size() and not ev["fachada"].is_empty(), "una columna de fachada por cada columna relativa")
	for rel in fachada_rel:
		assert(ev["fachada"][esquina + rel] == 0, "la fachada se nivela al objetivo")
	assert(ev["columnas_union"].size() == ev["columnas"].size() + fachada_rel.size(), "huella + fachada")
	print("OK: evaluación válida.")
	camara.free()

	print("=== TEST 2: cada rechazo del clic aparece en el mensaje ===")
	# Pendiente: una columna de la huella 4 bloques más alta que sus vecinas.
	for y in range(1, 5):
		mundo.colocar_bloque(Vector3i(12, y, 12), "tierra")
	camara = _camara(mundo, "mina")
	ev = camara._evaluar_puesto(esquina)
	assert("pendiente" in camara._mensaje_rechazo_puesto(ev), "una columna muy alta rompe el relieve: %s" % camara._mensaje_rechazo_puesto(ev))
	camara.free()
	# Frente de la puerta: una pared en la fachada (mina sobre otra esquina, terreno liso).
	var esquina_b := Vector2i(24, 24)
	camara = _camara(mundo, "mina")
	var fachada_b: Array[Vector2i] = PlantillasPuesto.fachada("mina", 0)
	var columna_frente: Vector2i = esquina_b + fachada_b[0]
	mundo.colocar_bloque(Vector3i(columna_frente.x, 1, columna_frente.y), "pared", true)
	ev = camara._evaluar_puesto(esquina_b)
	assert("frente" in camara._mensaje_rechazo_puesto(ev), "una estructura delante de la puerta la rechaza: %s" % camara._mensaje_rechazo_puesto(ev))
	camara.free()
	print("OK: rechazos por relieve y frente.")

	print("=== TEST 3: en pesca el giro efectivo pone el edificio del lado de tierra ===")
	var mundo_p: Node = _mundo_plano()
	# Agua en el extremo de z alto: fondo a y=-1 y una lámina de agua a y=0 rodeando el extremo.
	for x in range(9, 15):
		for z in range(14, 20):
			mundo_p.set_cell_item(Vector3i(x, 0, z), GridMap.INVALID_CELL_ITEM)
			mundo_p.colocar_bloque(Vector3i(x, -1, z), "tierra")
			mundo_p.colocar_bloque(Vector3i(x, 0, z), "agua")
	var esquina_p := Vector2i(10, 10)
	var camara_0: Camera3D = _camara(mundo_p, "pesca_frutos_mar", 0)
	var ev_0: Dictionary = camara_0._evaluar_puesto(esquina_p)
	var camara_2: Camera3D = _camara(mundo_p, "pesca_frutos_mar", 2)
	var ev_2: Dictionary = camara_2._evaluar_puesto(esquina_p)
	assert(ev_0["extremo_agua_indice"] != -1, "el extremo de agua se detecta")
	assert(ev_0["giros"] == ev_2["giros"], "sea cual sea el giro pedido, el efectivo deja el edificio del lado de tierra")
	assert(camara_0._mensaje_rechazo_puesto(ev_0) == "", "válida en pesca: %s" % camara_0._mensaje_rechazo_puesto(ev_0))
	camara_0.free()
	camara_2.free()
	mundo_p.free()
	print("OK: giro efectivo de pesca.")

	mundo.free()
	print("\n=== Las 3 pruebas de previsualización de puestos pasaron correctamente ===")

extends Node

## Pruebas aisladas de Recoleccion.gd (mismo patrón que
## NiveladorTerrenoTest.gd/BlueprintValidatorTest.gd). Corre esta escena
## (RecoleccionTest.tscn) con F6 en el editor de Godot y revisa el panel
## "Output": debe imprimir las pruebas y no debe lanzar ningún error de
## assert().

const VoxelWorld = preload("res://scripts/VoxelWorld.gd")


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	print("=== TEST 1: detectar_recursos() cuenta tipos reales dentro del radio ===")
	# VoxelWorld.new() sin _ready() (evita la generación automática del mundo
	# de 200x200) — mismo patrón que BlueprintValidatorTest.gd.
	var mundo: Node = VoxelWorld.new()
	mundo.mesh_library = load("res://assets/BlockLibrary.res")
	mundo.cell_size = Vector3.ONE * 1.0
	mundo._indexar_biblioteca()

	# Superficie plana en y=10 rellena de "piedra" en un radio generoso, con
	# 2 celdas de "hierro" colocadas a mano dentro del radio de acción — el
	# resto queda como aire (no cuenta, "" en obtener_tipo()).
	var centro := Vector2i(0, 0)
	var altura_superficie := 10
	for dx in range(-Recoleccion.RADIO_AREA_MINA, Recoleccion.RADIO_AREA_MINA + 1):
		for dz in range(-Recoleccion.RADIO_AREA_MINA, Recoleccion.RADIO_AREA_MINA + 1):
			if Vector2(dx, dz).length() > Recoleccion.RADIO_AREA_MINA:
				continue
			mundo.colocar_bloque(Vector3i(dx, altura_superficie - 1, dz), "piedra")
	mundo.minar_bloque(Vector3i(0, altura_superficie - 1, 0))
	mundo.colocar_bloque(Vector3i(0, altura_superficie - 1, 0), "hierro")
	mundo.minar_bloque(Vector3i(1, altura_superficie - 1, 0))
	mundo.colocar_bloque(Vector3i(1, altura_superficie - 1, 0), "hierro")

	var conteo: Dictionary = Recoleccion.detectar_recursos(mundo, centro, altura_superficie)
	print("Conteo detectado: ", conteo)
	assert(conteo.get("hierro", 0) == 2)
	assert(conteo.get("piedra", 0) > 0)
	assert(not conteo.has(""))
	var piedra_antes: int = conteo.get("piedra", 0)

	# Bloque de piedra en una esquina que cae DENTRO de la caja delimitadora
	# ingenua (dx en [-6,6], dy en [0,8], dz en [-6,6]) pero FUERA de la
	# semiesfera real (Vector3(6,-6,0).length() ≈ 8.49 > RADIO_AREA_MINA=6):
	# si detectar_recursos() usara una caja en vez de la esfera real, este
	# bloque se contaría de más.
	mundo.colocar_bloque(Vector3i(6, altura_superficie - 6, 0), "piedra")
	var conteo_esquina: Dictionary = Recoleccion.detectar_recursos(mundo, centro, altura_superficie)
	print("Conteo piedra antes de la esquina fuera de esfera: ", piedra_antes, " / después: ", conteo_esquina.get("piedra", 0))
	assert(conteo_esquina.get("piedra", 0) == piedra_antes)

	print("\n=== TEST 2: tasas_recoleccion() reparte proporcionalmente ===")
	var conteo_simple := {"piedra": 3, "hierro": 1}
	var tasas: Dictionary = Recoleccion.tasas_recoleccion(conteo_simple)
	print("Tasas: ", tasas)
	assert(is_equal_approx(tasas["piedra"], 1.5))  # 3/4 * 2.0
	assert(is_equal_approx(tasas["hierro"], 0.5))  # 1/4 * 2.0

	print("\n=== TEST 3: tasas_recoleccion() con conteo vacío no divide por cero ===")
	var tasas_vacias: Dictionary = Recoleccion.tasas_recoleccion({})
	assert(tasas_vacias.is_empty())

	print("\n=== TEST 4: colocar_puesto() registra el puesto por su huella ===")
	Recoleccion.puestos.clear()  # aislar de otras pruebas que compartan el autoload
	Recoleccion.colocar_puesto(Vector2i(5, 5), "mina", Recoleccion.ANCHO_HUELLA_MINA, Recoleccion.ALTO_HUELLA_MINA)
	assert(Recoleccion.puestos.has(Vector2i(5, 5)))
	assert(Recoleccion.puestos[Vector2i(5, 5)]["tipo"] == "mina")
	assert(Recoleccion.puestos[Vector2i(5, 5)]["ancho"] == 5)
	assert(Recoleccion.puestos[Vector2i(5, 5)]["nivel"] == 1)

	print("\n=== TEST 5: detectar_recursos() ignora bloques de árbol (madera/follaje) ===")
	var mundo_bosque: Node = VoxelWorld.new()
	mundo_bosque.mesh_library = load("res://assets/BlockLibrary.res")
	mundo_bosque.cell_size = Vector3.ONE * 1.0
	mundo_bosque._indexar_biblioteca()
	var centro_bosque := Vector2i(50, 50)
	var altura_bosque := 10
	mundo_bosque.colocar_bloque(Vector3i(centro_bosque.x, altura_bosque - 1, centro_bosque.y), "piedra")
	mundo_bosque.colocar_bloque(Vector3i(centro_bosque.x + 1, altura_bosque - 1, centro_bosque.y), "hierro")
	mundo_bosque.colocar_bloque(Vector3i(centro_bosque.x, altura_bosque, centro_bosque.y), "madera")
	mundo_bosque.colocar_bloque(Vector3i(centro_bosque.x, altura_bosque + 1, centro_bosque.y), "follaje")
	var conteo_bosque: Dictionary = Recoleccion.detectar_recursos(mundo_bosque, centro_bosque, altura_bosque)
	print("Conteo detectado junto a un árbol: ", conteo_bosque)
	assert(not conteo_bosque.has("madera"))
	assert(not conteo_bosque.has("follaje"))
	assert(conteo_bosque.get("piedra", 0) > 0)
	assert(conteo_bosque.get("hierro", 0) > 0)
	print("OK: 'madera' y 'follaje' nunca aparecen en el conteo de una mina, aunque estén dentro de su área de acción.")

	print("\n=== TEST 6: celda_dentro_de_algun_puesto() detecta solapamiento entre puestos de cualquier tipo ===")
	Recoleccion.puestos.clear()
	Recoleccion.colocar_puesto(Vector2i(0, 0), "mina", Recoleccion.ANCHO_HUELLA_MINA, Recoleccion.ALTO_HUELLA_MINA)
	assert(Recoleccion.celda_dentro_de_algun_puesto(Vector2i(2, 2)))       # dentro de la huella 5x5 de (0,0): 0..4
	assert(not Recoleccion.celda_dentro_de_algun_puesto(Vector2i(5, 5)))   # justo fuera de esa huella
	Recoleccion.colocar_puesto(Vector2i(20, 20), "caza_recoleccion", 4, 4)
	assert(Recoleccion.celda_dentro_de_algun_puesto(Vector2i(22, 22)))     # dentro del segundo puesto
	assert(not Recoleccion.celda_dentro_de_algun_puesto(Vector2i(24, 24))) # huella 4x4 de (20,20): 20..23
	print("OK: celda_dentro_de_algun_puesto() detecta el puesto correcto sin importar su tipo.")

	print("\n=== Las 6 pruebas de Recoleccion pasaron correctamente ===")

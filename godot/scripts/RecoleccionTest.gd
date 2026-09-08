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

	print("\n=== TEST 2: tasas_recoleccion() reparte proporcionalmente ===")
	var conteo_simple := {"piedra": 3, "hierro": 1}
	var tasas: Dictionary = Recoleccion.tasas_recoleccion(conteo_simple)
	print("Tasas: ", tasas)
	assert(is_equal_approx(tasas["piedra"], 1.5))  # 3/4 * 2.0
	assert(is_equal_approx(tasas["hierro"], 0.5))  # 1/4 * 2.0

	print("\n=== TEST 3: tasas_recoleccion() con conteo vacío no divide por cero ===")
	var tasas_vacias: Dictionary = Recoleccion.tasas_recoleccion({})
	assert(tasas_vacias.is_empty())

	print("\n=== TEST 4: colocar_mina() registra el puesto ===")
	Recoleccion.puestos.clear()  # aislar de otras pruebas que compartan el autoload
	Recoleccion.colocar_mina(Vector2i(5, 5))
	assert(Recoleccion.puestos.has(Vector2i(5, 5)))
	assert(Recoleccion.puestos[Vector2i(5, 5)]["nivel"] == 1)

	print("\n=== Las 4 pruebas de Recoleccion pasaron correctamente ===")

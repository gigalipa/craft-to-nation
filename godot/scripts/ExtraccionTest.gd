extends Node

## Pruebas aisladas de la extracción del avatar (sub-proyecto 2B): ProgresoAccion,
## tiempos de minado, extraer_por_avatar() y frutos de VoxelWorld. Sin escena de
## juego (mismo patrón que RecoleccionTest.gd). Corre esta escena y revisa que
## no lance ningún assert().

const ProgresoAccionScript = preload("res://scripts/ProgresoAccion.gd")


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	print("=== TEST 1: ProgresoAccion avanza, se completa y se reinicia ===")
	var progreso: RefCounted = ProgresoAccionScript.new()
	assert(progreso.fraccion() == 0.0)
	assert(not progreso.avanzar("celda:a", 1.0, 0.4))
	assert(is_equal_approx(progreso.fraccion(), 0.4))
	assert(not progreso.avanzar("celda:a", 1.0, 0.4))
	assert(progreso.avanzar("celda:a", 1.0, 0.4), "0.4 + 0.4 + 0.4 >= 1.0 completa")
	assert(progreso.fraccion() == 0.0, "al completar, el avance vuelve a 0")

	print("\n=== TEST 2: cambiar de objetivo o soltar reinicia el avance ===")
	progreso.avanzar("celda:a", 1.0, 0.5)
	assert(not progreso.avanzar("celda:b", 1.0, 0.1), "otro bloque: empieza de cero")
	assert(is_equal_approx(progreso.fraccion(), 0.1))
	progreso.soltar()
	assert(progreso.fraccion() == 0.0)
	assert(not progreso.avanzar("celda:b", 1.0, 0.1))
	assert(is_equal_approx(progreso.fraccion(), 0.1), "tras soltar no se conserva nada")
	assert(progreso.avanzar("arbol:3", 0.0, 0.0), "una duración 0 completa de inmediato, sin dividir por cero")

	print("\n=== Las 2 pruebas de la extracción del avatar pasaron correctamente ===")

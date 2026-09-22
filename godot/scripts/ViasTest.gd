extends Node

## Pruebas aisladas de Vias.gd/NiveladorVia.gd/TrazadorVias.gd/
## ConstructorVias.gd, sin escena visual — corre esta escena y revisa que
## no lance ningún assert(). Mismo patrón que ZonificacionTest.gd/
## NiveladorTerrenoTest.gd.

# Preloads for future tasks (Task 2, 3, 4):
# const NiveladorVia = preload("res://scripts/NiveladorVia.gd")
# const TrazadorVias = preload("res://scripts/TrazadorVias.gd")
# const ConstructorVias = preload("res://scripts/ConstructorVias.gd")


func _ready() -> void:
	ejecutar_pruebas()
	print("=== TODAS LAS PRUEBAS DE ViasTest PASARON ===")


func ejecutar_pruebas() -> void:
	print("=== TEST 1: agregar()/es_via()/tipo_en() ===")
	Vias.celdas.clear()
	Vias._columnas.clear()
	var celda := Vector3i(5, 10, 5)
	assert(not Vias.es_via(celda))
	Vias.agregar([celda], "tierra_pisada")
	assert(Vias.es_via(celda))
	assert(Vias.tipo_en(celda) == "tierra_pisada")

	print("\n=== TEST 2: bono_en() ===")
	assert(is_equal_approx(Vias.bono_en(celda), 1.35))
	assert(is_equal_approx(Vias.bono_en(Vector3i(0, 0, 0)), 1.0))

	print("\n=== TEST 3: hay_via_en_columna() ===")
	assert(Vias.hay_via_en_columna(Vector2i(5, 5)))
	assert(not Vias.hay_via_en_columna(Vector2i(0, 0)))

	print("\n=== TEST 4: quitar() ===")
	Vias.quitar([celda])
	assert(not Vias.es_via(celda))
	assert(not Vias.hay_via_en_columna(Vector2i(5, 5)))

	print("\n=== TEST 5: quitar() una celda que no es vía es no-op ===")
	Vias.quitar([Vector3i(1, 1, 1)])  # no debe lanzar error

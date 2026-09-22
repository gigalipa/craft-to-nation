extends Node

## Pruebas aisladas de Vias.gd/NiveladorVia.gd/TrazadorVias.gd/
## ConstructorVias.gd, sin escena visual — corre esta escena y revisa que
## no lance ningún assert(). Mismo patrón que ZonificacionTest.gd/
## NiveladorTerrenoTest.gd.

# Preloads for future tasks (Task 2, 3, 4):
const NiveladorVia = preload("res://scripts/NiveladorVia.gd")
# const TrazadorVias = preload("res://scripts/TrazadorVias.gd")
# const ConstructorVias = preload("res://scripts/ConstructorVias.gd")

## Generador falso: altura = x + z (una pendiente diagonal simple para
## probar niveles de bloque distintos entre vértices vecinos).
class GeneradorPendienteDiagonal:
	func altura_en(x: int, z: int) -> int:
		return x + z


## Generador falso: altura constante 10 en todo el mapa.
class GeneradorPlano:
	func altura_en(_x: int, _z: int) -> int:
		return 10


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

	print("\n=== TEST 6: bloque_de_vertice() — 4 columnas alrededor del vértice ===")
	var nivelador_plano := NiveladorVia.new(GeneradorPlano.new())
	var bloque: Array[Vector2i] = nivelador_plano.bloque_de_vertice(Vector2i(5, 5))
	assert(bloque.size() == 4)
	for esperado in [Vector2i(4, 4), Vector2i(5, 4), Vector2i(4, 5), Vector2i(5, 5)]:
		assert(bloque.has(esperado))

	print("\n=== TEST 7: nivel_de_bloque() en terreno plano ===")
	assert(nivelador_plano.nivel_de_bloque(Vector2i(5, 5)) == 10)

	print("\n=== TEST 8: nivel_de_bloque() usa el máximo de las 4 columnas ===")
	var nivelador_diagonal := NiveladorVia.new(GeneradorPendienteDiagonal.new())
	# Vértice (1,1): columnas (0,0)=0, (1,0)=1, (0,1)=1, (1,1)=2 -> máximo 2.
	assert(nivelador_diagonal.nivel_de_bloque(Vector2i(1, 1)) == 2)

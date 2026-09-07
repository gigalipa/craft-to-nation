extends Node

## Pruebas aisladas de GeneradorMundo.gd (mismo patrón que ZonificacionTest.gd
## y CiudadTest.gd). Corre esta escena (GeneradorMundoTest.tscn) con F6 en el
## editor de Godot y revisa el panel "Output": debe imprimir las 4 pruebas y
## no debe lanzar ningún error de assert().

const GeneradorMundoScript = preload("res://scripts/GeneradorMundo.gd")


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	print("=== TEST 1: Determinismo (misma semilla, mismas coordenadas) ===")
	var gen_a: RefCounted = GeneradorMundoScript.new(12345)
	var gen_b: RefCounted = GeneradorMundoScript.new(12345)
	for i in range(20):
		var x: int = i * 7
		var z: int = i * 3
		assert(gen_a.altura_en(x, z) == gen_b.altura_en(x, z))
	print("OK: 20 puntos de muestra coinciden entre dos instancias con la misma semilla.")

	print("\n=== TEST 2: Alturas dentro del rango esperado ===")
	var gen: RefCounted = GeneradorMundoScript.new(999)
	for x in range(-50, 50, 5):
		for z in range(-50, 50, 5):
			var altura: int = gen.altura_en(x, z)
			assert(altura >= GeneradorMundoScript.ALTURA_MINIMA)
			assert(altura <= GeneradorMundoScript.ALTURA_MAXIMA)
	print("OK: todas las alturas muestreadas (incluyendo coordenadas negativas) están en rango.")

	print("\n=== TEST 3: Semillas distintas producen mapas distintos ===")
	var gen_1: RefCounted = GeneradorMundoScript.new(1)
	var gen_2: RefCounted = GeneradorMundoScript.new(2)
	var hay_diferencia := false
	for x in range(0, 100, 3):
		for z in range(0, 100, 3):
			if gen_1.altura_en(x, z) != gen_2.altura_en(x, z):
				hay_diferencia = true
				break
		if hay_diferencia:
			break
	assert(hay_diferencia)
	print("OK: al menos un punto muestreado difiere entre semilla 1 y semilla 2.")

	print("\n=== TEST 4: tipo_en_profundidad() por capas ===")
	var gen_capas: RefCounted = GeneradorMundoScript.new(1)
	for p in range(GeneradorMundoScript.GROSOR_TIERRA):
		assert(gen_capas.tipo_en_profundidad(p) == "tierra")
	assert(gen_capas.tipo_en_profundidad(GeneradorMundoScript.GROSOR_TIERRA) == "piedra")
	assert(gen_capas.tipo_en_profundidad(GeneradorMundoScript.GROSOR_TIERRA + 10) == "piedra")
	print("OK: tierra hasta GROSOR_TIERRA, piedra en adelante.")

	print("\n=== Las 4 pruebas de GeneradorMundo pasaron correctamente ===")

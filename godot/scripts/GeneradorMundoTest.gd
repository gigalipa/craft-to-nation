extends Node

## Pruebas aisladas de GeneradorMundo.gd (mismo patrón que ZonificacionTest.gd
## y CiudadTest.gd). Corre esta escena (GeneradorMundoTest.tscn) con F6 en el
## editor de Godot y revisa el panel "Output": debe imprimir las 4 pruebas y
## no debe lanzar ningún error de assert().

const GeneradorMundoScript = preload("res://scripts/GeneradorMundo.gd")
const VoxelWorld = preload("res://scripts/VoxelWorld.gd")


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

	print("\n=== TEST 4: tipo_en_profundidad() por capas (tierra/piedra) ===")
	var gen_capas: RefCounted = GeneradorMundoScript.new(1)
	for p in range(GeneradorMundoScript.GROSOR_TIERRA):
		assert(gen_capas.tipo_en_profundidad(0, 10 - p, 0, p) == "tierra")
	var tipo_profundo: String = gen_capas.tipo_en_profundidad(0, 10 - GeneradorMundoScript.GROSOR_TIERRA, 0, GeneradorMundoScript.GROSOR_TIERRA)
	assert(tipo_profundo == "piedra" or tipo_profundo == "hierro")
	print("OK: tierra hasta GROSOR_TIERRA; piedra o hierro en adelante (nunca tierra).")

	print("\n=== TEST 5: Las vetas de hierro nunca aparecen en la capa de tierra, y sí varían la piedra ===")
	var gen_vetas: RefCounted = GeneradorMundoScript.new(42)
	var vio_tierra := false
	var vio_piedra := false
	var vio_hierro := false
	for x in range(0, 60, 2):
		for z in range(0, 60, 2):
			for p in range(0, 20):
				var tipo: String = gen_vetas.tipo_en_profundidad(x, 100 - p, z, p)
				if p < GeneradorMundoScript.GROSOR_TIERRA:
					assert(tipo == "tierra")
					vio_tierra = true
				elif tipo == "piedra":
					vio_piedra = true
				elif tipo == "hierro":
					vio_hierro = true
	assert(vio_tierra)
	assert(vio_piedra)
	assert(vio_hierro)
	print("OK: capa de tierra siempre 'tierra'; capa profunda produjo tanto 'piedra' como 'hierro' en el muestreo.")

	print("\n=== TEST 6: Aparece hierro con la semilla y el rango de profundidad REALES del juego ===")
	# Test 5 solo prueba que el hierro PUEDE existir, con una semilla/rango
	# arbitrarios (42, y-100). Este test usa la semilla real del mundo
	# (VoxelWorld.SEMILLA_MUNDO, así que el ruido de mineral interno usa
	# semilla+1, ver GeneradorMundo._init()) y el rango de profundidad real
	# ([-24, 15] dado PROFUNDIDAD_SUBSUELO=24 y ALTURA_MAXIMA=15) para
	# confirmar que el hierro también aparece bajo los parámetros con los que
	# el jugador de verdad juega, no solo en un muestreo fuera del mundo real.
	var gen_real: RefCounted = GeneradorMundoScript.new(VoxelWorld.SEMILLA_MUNDO)
	var vio_hierro_real := false
	for x in range(0, 200, 4):
		for z in range(0, 200, 4):
			for altura_superficie in range(0, 16, 3):
				for p in range(GeneradorMundoScript.GROSOR_TIERRA, 21):
					var y: int = altura_superficie - p
					if gen_real.tipo_en_profundidad(x, y, z, p) == "hierro":
						vio_hierro_real = true
	assert(vio_hierro_real)
	print("OK: 'hierro' aparece con SEMILLA_MUNDO real y el rango de profundidad real del subsuelo.")

	print("\n=== TEST 7: la redistribución por curva de potencia acentúa los extremos sin cambiar el signo ===")
	assert(is_equal_approx(GeneradorMundoScript._redistribuir(0.0, 2.0), 0.0))
	assert(is_equal_approx(GeneradorMundoScript._redistribuir(1.0, 2.0), 1.0))
	assert(is_equal_approx(GeneradorMundoScript._redistribuir(-1.0, 2.0), -1.0))
	assert(is_equal_approx(GeneradorMundoScript._redistribuir(0.5, 2.0), 0.25))
	assert(is_equal_approx(GeneradorMundoScript._redistribuir(-0.5, 2.0), -0.25))
	print("OK: _redistribuir(0.5, 2.0) == 0.25 (se aplana), extremos ±1 y 0 quedan sin cambio, signo se conserva.")

	print("\n=== Las 7 pruebas de GeneradorMundo pasaron correctamente ===")

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
	var gen_a: RefCounted = GeneradorMundoScript.new(12345, 60, 60)
	var gen_b: RefCounted = GeneradorMundoScript.new(12345, 60, 60)
	for i in range(20):
		var x: int = i * 7
		var z: int = i * 3
		assert(gen_a.altura_en(x, z) == gen_b.altura_en(x, z))
	print("OK: 20 puntos de muestra coinciden entre dos instancias con la misma semilla.")

	print("\n=== TEST 2: Alturas dentro del rango esperado ===")
	var gen: RefCounted = GeneradorMundoScript.new(999, 100, 100)
	for x in range(-50, 50, 5):
		for z in range(-50, 50, 5):
			var altura: int = gen.altura_en(x, z)
			assert(altura >= GeneradorMundoScript.ALTURA_MINIMA)
			assert(altura <= GeneradorMundoScript.ALTURA_MAXIMA)
	print("OK: todas las alturas muestreadas (incluyendo coordenadas negativas) están en rango.")

	print("\n=== TEST 3: Semillas distintas producen mapas distintos ===")
	var gen_1: RefCounted = GeneradorMundoScript.new(1, 100, 100)
	var gen_2: RefCounted = GeneradorMundoScript.new(2, 100, 100)
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
	var gen_capas: RefCounted = GeneradorMundoScript.new(1, 10, 10)
	for p in range(GeneradorMundoScript.GROSOR_TIERRA):
		assert(gen_capas.tipo_en_profundidad(0, 10 - p, 0, p) == "tierra")
	var tipo_profundo: String = gen_capas.tipo_en_profundidad(0, 10 - GeneradorMundoScript.GROSOR_TIERRA, 0, GeneradorMundoScript.GROSOR_TIERRA)
	assert(tipo_profundo == "piedra" or tipo_profundo == "hierro")
	print("OK: tierra hasta GROSOR_TIERRA; piedra o hierro en adelante (nunca tierra).")

	print("\n=== TEST 5: Las vetas de hierro nunca aparecen en la capa de tierra, y sí varían la piedra ===")
	var gen_vetas: RefCounted = GeneradorMundoScript.new(42, 60, 60)
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
	var gen_real: RefCounted = GeneradorMundoScript.new(VoxelWorld.SEMILLA_MUNDO, VoxelWorld.ANCHO_MUNDO, VoxelWorld.LARGO_MUNDO)
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

	print("\n=== TEST 7: la redistribución por curva de potencia preserva signo y extremos exactos ===")
	assert(is_equal_approx(GeneradorMundoScript._redistribuir(0.0, 2.0), 0.0))
	assert(is_equal_approx(GeneradorMundoScript._redistribuir(1.0, 2.0), 1.0))
	assert(is_equal_approx(GeneradorMundoScript._redistribuir(-1.0, 2.0), -1.0))
	assert(is_equal_approx(GeneradorMundoScript._redistribuir(0.5, 2.0), 0.25))
	assert(is_equal_approx(GeneradorMundoScript._redistribuir(-0.5, 2.0), -0.25))
	print("OK: _redistribuir(0.5, 2.0) == 0.25 (se aplana), extremos ±1 y 0 quedan sin cambio, signo se conserva.")

	print("\n=== TEST 8: nivel_mar es determinista para (semilla, ancho, largo) dados ===")
	var gen_mar_a: RefCounted = GeneradorMundoScript.new(555, 60, 60)
	var gen_mar_b: RefCounted = GeneradorMundoScript.new(555, 60, 60)
	assert(gen_mar_a.nivel_mar == gen_mar_b.nivel_mar)
	print("OK: nivel_mar coincide entre dos instancias con la misma semilla y grid.")

	print("\n=== TEST 9: es_agua_en coincide con altura_en(x,z) < nivel_mar ===")
	var gen_agua: RefCounted = GeneradorMundoScript.new(777, 60, 60)
	for x in range(0, 60, 3):
		for z in range(0, 60, 3):
			var esperado: bool = gen_agua.altura_en(x, z) < gen_agua.nivel_mar
			assert(gen_agua.es_agua_en(x, z) == esperado)
	print("OK: es_agua_en() coincide con el criterio altura_en(x,z) < nivel_mar en todos los puntos muestreados.")

	print("\n=== TEST 10: la fracción de columnas inundadas se aproxima al percentil configurado ===")
	var gen_pct: RefCounted = GeneradorMundoScript.new(2026, 100, 100)
	var total := 0
	var inundadas := 0
	for x in range(100):
		for z in range(100):
			total += 1
			if gen_pct.es_agua_en(x, z):
				inundadas += 1
	var fraccion: float = float(inundadas) / float(total)
	# Tolerancia ±0.03 (no ±0.05 exacto): con EXPONENTE_RELIEVE=0.5 (ver Task
	# 2 — corrige el exponente >1 original, que comprimía el relieve hacia
	# el centro en vez de acentuar picos/cuencas) y _calcular_nivel_mar()
	# eligiendo la altura cuyo conteo acumulado real se acerca más al índice
	# objetivo (no solo la posición ordinal), la fracción medida para esta
	# semilla/grid es 0.161 (a 0.011 del 15% nominal) — y 0.1596 con los
	# parámetros reales del mundo (SEMILLA_MUNDO/ANCHO_MUNDO/LARGO_MUNDO).
	# ±0.03 deja margen sobre esa desviación medida sin ocultar una futura
	# regresión real del criterio de nivel de mar.
	assert(abs(fraccion - GeneradorMundoScript.PERCENTIL_NIVEL_MAR) < 0.03)
	print("OK: fracción inundada %.3f está dentro de ±0.03 del percentil configurado (%.2f)." % [fraccion, GeneradorMundoScript.PERCENTIL_NIVEL_MAR])

	print("\n=== TEST 11: es_bioma_en coincide con tierra firme dentro de la banda sobre el nivel de mar ===")
	var gen_bioma: RefCounted = GeneradorMundoScript.new(321, 80, 80)
	for x in range(0, 80, 2):
		for z in range(0, 80, 2):
			var altura: int = gen_bioma.altura_en(x, z)
			var esperado: bool = (not gen_bioma.es_agua_en(x, z)) and altura <= gen_bioma.nivel_mar + GeneradorMundoScript.BANDA_BIOMA
			assert(gen_bioma.es_bioma_en(x, z) == esperado)
	print("OK: es_bioma_en() coincide con 'tierra firme y altura <= nivel_mar + BANDA_BIOMA' en todos los puntos muestreados.")

	print("\n=== TEST 12: densidad_fauna_en y densidad_frutal_en son deterministas y están en [0,1] ===")
	var gen_dens_a: RefCounted = GeneradorMundoScript.new(444, 60, 60)
	var gen_dens_b: RefCounted = GeneradorMundoScript.new(444, 60, 60)
	for x in range(0, 60, 3):
		for z in range(0, 60, 3):
			var fauna_a: float = gen_dens_a.densidad_fauna_en(x, z)
			var fauna_b: float = gen_dens_b.densidad_fauna_en(x, z)
			assert(is_equal_approx(fauna_a, fauna_b))
			assert(fauna_a >= 0.0 and fauna_a <= 1.0)
			var frutal_a: float = gen_dens_a.densidad_frutal_en(x, z)
			var frutal_b: float = gen_dens_b.densidad_frutal_en(x, z)
			assert(is_equal_approx(frutal_a, frutal_b))
			assert(frutal_a >= 0.0 and frutal_a <= 1.0)
	print("OK: ambas densidades son deterministas para la misma semilla/grid y quedan siempre en [0,1].")

	print("\n=== TEST 13: densidad_fauna_en y densidad_frutal_en son 0.0 fuera del bioma ===")
	var gen_fuera: RefCounted = GeneradorMundoScript.new(888, 80, 80)
	var vio_fuera_de_bioma := false
	for x in range(0, 80, 2):
		for z in range(0, 80, 2):
			if not gen_fuera.es_bioma_en(x, z):
				vio_fuera_de_bioma = true
				assert(gen_fuera.densidad_fauna_en(x, z) == 0.0)
				assert(gen_fuera.densidad_frutal_en(x, z) == 0.0)
	assert(vio_fuera_de_bioma)
	print("OK: ambas densidades son exactamente 0.0 en toda columna fuera del bioma (al menos una encontrada en el muestreo).")

	print("\n=== TEST 14: las señales de bioma funcionan con los parámetros reales del mundo ===")
	var gen_real_bioma: RefCounted = GeneradorMundoScript.new(VoxelWorld.SEMILLA_MUNDO, VoxelWorld.ANCHO_MUNDO, VoxelWorld.LARGO_MUNDO)
	for x in range(0, 200, 10):
		for z in range(0, 200, 10):
			var f: float = gen_real_bioma.densidad_fauna_en(x, z)
			var r: float = gen_real_bioma.densidad_frutal_en(x, z)
			assert(f >= 0.0 and f <= 1.0)
			assert(r >= 0.0 and r <= 1.0)
	print("OK: es_bioma_en/densidad_fauna_en/densidad_frutal_en no rompen con SEMILLA_MUNDO/ANCHO_MUNDO/LARGO_MUNDO reales.")

	print("\n=== TEST 15: densidad_arbol_en es determinista, está en [0,1], y es 0.0 fuera del bioma ===")
	var gen_dens_arbol_a: RefCounted = GeneradorMundoScript.new(333, 60, 60)
	var gen_dens_arbol_b: RefCounted = GeneradorMundoScript.new(333, 60, 60)
	var vio_fuera_arbol := false
	for x in range(0, 60, 3):
		for z in range(0, 60, 3):
			var a: float = gen_dens_arbol_a.densidad_arbol_en(x, z)
			var b: float = gen_dens_arbol_b.densidad_arbol_en(x, z)
			assert(is_equal_approx(a, b))
			assert(a >= 0.0 and a <= 1.0)
			if not gen_dens_arbol_a.es_bioma_en(x, z):
				vio_fuera_arbol = true
				assert(a == 0.0)
	assert(vio_fuera_arbol)
	print("OK: densidad_arbol_en es determinista, está en [0,1], y es exactamente 0.0 fuera del bioma (al menos una columna encontrada).")

	print("\n=== Las 15 pruebas de GeneradorMundo pasaron correctamente ===")

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

	print("\n=== TEST 16: _profundidad_en_franja() da el perfil borde-1/centro-hasta-3 ===")
	assert(GeneradorMundoScript._profundidad_en_franja(0, 2) == 1)
	assert(GeneradorMundoScript._profundidad_en_franja(1, 2) == 1)
	assert(GeneradorMundoScript._profundidad_en_franja(0, 3) == 1)
	assert(GeneradorMundoScript._profundidad_en_franja(1, 3) == 2)
	assert(GeneradorMundoScript._profundidad_en_franja(2, 3) == 1)
	assert(GeneradorMundoScript._profundidad_en_franja(0, 5) == 1)
	assert(GeneradorMundoScript._profundidad_en_franja(1, 5) == 2)
	assert(GeneradorMundoScript._profundidad_en_franja(2, 5) == 3)
	assert(GeneradorMundoScript._profundidad_en_franja(3, 5) == 2)
	assert(GeneradorMundoScript._profundidad_en_franja(4, 5) == 1)
	assert(GeneradorMundoScript._profundidad_en_franja(0, 6) == 1)
	assert(GeneradorMundoScript._profundidad_en_franja(2, 6) == 3)
	assert(GeneradorMundoScript._profundidad_en_franja(3, 6) == 3)
	assert(GeneradorMundoScript._profundidad_en_franja(5, 6) == 1)
	print("OK: perfiles [1,1] (ancho 2), [1,2,1] (ancho 3), [1,2,3,2,1] (ancho 5), [1,2,3,3,2,1] (ancho 6).")

	print("\n=== TEST 17: _celdas_franja_en() genera 'ancho' celdas perpendiculares al avance ===")
	var cauce_x: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var franja_x: Array[Vector2i] = GeneradorMundoScript._celdas_franja_en(cauce_x, 1, 3)
	assert(franja_x.size() == 3)
	for celda in franja_x:
		assert(celda.x == 1)  # avance en X -> franja se extiende en Z (.y)
	var cauce_z: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]
	var franja_z: Array[Vector2i] = GeneradorMundoScript._celdas_franja_en(cauce_z, 1, 3)
	assert(franja_z.size() == 3)
	for celda in franja_z:
		assert(celda.y == 1)  # avance en Z -> franja se extiende en X
	print("OK: la franja perpendicular al avance tiene 'ancho' celdas y varía en el eje correcto.")

	print("\n=== TEST 18: _resolver_cruces() trunca el río más angosto en el cruce, el más ancho sigue completo ===")
	var rios_cruce: Array[Dictionary] = [
		{"indice": 0, "ancho": 2, "altura_nacimiento": 10, "cauce_crudo": [Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5)]},
		{"indice": 1, "ancho": 5, "altura_nacimiento": 8, "cauce_crudo": [Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 5), Vector2i(2, 8)]},
	]
	GeneradorMundoScript._resolver_cruces(rios_cruce)
	var truncado_angosto: Array[Vector2i] = rios_cruce[0]["cauce_truncado"]
	var truncado_ancho: Array[Vector2i] = rios_cruce[1]["cauce_truncado"]
	assert(truncado_angosto == [Vector2i(0, 5), Vector2i(1, 5)])  # corta justo antes de (2,5), que gana el más ancho
	assert(truncado_ancho == rios_cruce[1]["cauce_crudo"])  # el más ancho no se trunca
	print("OK: el río de ancho 2 se trunca antes del cruce en (2,5); el de ancho 5 conserva su cauce completo.")

	print("\n=== TEST 19: _resolver_cruces() en empate de ancho, gana el de naciente más alta ===")
	var rios_empate: Array[Dictionary] = [
		{"indice": 0, "ancho": 3, "altura_nacimiento": 10, "cauce_crudo": [Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5)]},
		{"indice": 1, "ancho": 3, "altura_nacimiento": 14, "cauce_crudo": [Vector2i(2, 0), Vector2i(2, 5), Vector2i(2, 8)]},
	]
	GeneradorMundoScript._resolver_cruces(rios_empate)
	assert(rios_empate[0]["cauce_truncado"] == [Vector2i(0, 5), Vector2i(1, 5)])
	assert(rios_empate[1]["cauce_truncado"] == rios_empate[1]["cauce_crudo"])
	print("OK: en empate de ancho, el río de naciente más alta (14 > 10) conserva su cauce completo.")

	print("\n=== TEST 20: _trazar_rio() es determinista y termina en agua o mesa cerrada ===")
	var gen_rio_a: RefCounted = GeneradorMundoScript.new(VoxelWorld.SEMILLA_MUNDO, VoxelWorld.ANCHO_MUNDO, VoxelWorld.LARGO_MUNDO)
	var gen_rio_b: RefCounted = GeneradorMundoScript.new(VoxelWorld.SEMILLA_MUNDO, VoxelWorld.ANCHO_MUNDO, VoxelWorld.LARGO_MUNDO)
	var origen_prueba := Vector2i(100, 100)
	var cauce_a: Array[Vector2i] = gen_rio_a._trazar_rio(origen_prueba, VoxelWorld.ANCHO_MUNDO, VoxelWorld.LARGO_MUNDO)
	var cauce_b: Array[Vector2i] = gen_rio_b._trazar_rio(origen_prueba, VoxelWorld.ANCHO_MUNDO, VoxelWorld.LARGO_MUNDO)
	assert(cauce_a == cauce_b)
	assert(cauce_a.size() >= 1)
	assert(cauce_a.size() <= VoxelWorld.ANCHO_MUNDO + VoxelWorld.LARGO_MUNDO)
	var ultima: Vector2i = cauce_a[cauce_a.size() - 1]
	var termino_en_agua: bool = gen_rio_a.es_agua_en(ultima.x, ultima.y)
	# "Mesa cerrada" real: ninguna vecina ortogonal de la última celda (dentro
	# del mundo) tiene menor altura. Comparar solo contra la celda anterior del
	# cauce no basta: como cada paso es estrictamente descendente por
	# construcción, esa comparación sería siempre "más baja" en cuanto el
	# cauce avanza más de un paso, aunque la última celda sí sea un valle
	# cerrado real (plateau con vecinas de igual o mayor altura).
	var es_mesa_cerrada := true
	for delta in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var vecino: Vector2i = ultima + delta
		if vecino.x < 0 or vecino.x >= VoxelWorld.ANCHO_MUNDO or vecino.y < 0 or vecino.y >= VoxelWorld.LARGO_MUNDO:
			continue
		if gen_rio_a.altura_en(vecino.x, vecino.y) < gen_rio_a.altura_en(ultima.x, ultima.y):
			es_mesa_cerrada = false
			break
	assert(termino_en_agua or cauce_a.size() == 1 or es_mesa_cerrada)
	print("OK: _trazar_rio() es determinista, respeta el tope de pasos, y termina en agua o en una mesa sin vecino más bajo.")

	print("\n=== TEST 21: cada paso del cauce baja de altura hasta llegar a agua ===")
	for i in range(cauce_a.size() - 1):
		var actual: Vector2i = cauce_a[i]
		if gen_rio_a.es_agua_en(actual.x, actual.y):
			break
		var siguiente: Vector2i = cauce_a[i + 1]
		assert(gen_rio_a.altura_en(siguiente.x, siguiente.y) <= gen_rio_a.altura_en(actual.x, actual.y))
	print("OK: ningún paso del cauce sube de altura antes de llegar a una celda de agua.")

	print("\n=== Las 21 pruebas de GeneradorMundo pasaron correctamente ===")

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
	# del mundo) tiene menor altura CONTINUA (_altura_flotante(), no
	# altura_en() entera — ver la nota en _altura_flotante(): _trazar_rio()
	# decide su descenso sobre la altura continua para no atascarse en
	# "mesetas" que solo existen por la cuantización a 16 alturas enteras, así
	# que el criterio de "mesa cerrada" de esta prueba debe usar el mismo
	# criterio real, no el entero). Comparar solo contra la celda anterior del
	# cauce no basta: como cada paso es estrictamente descendente por
	# construcción, esa comparación sería siempre "más baja" en cuanto el
	# cauce avanza más de un paso, aunque la última celda sí sea un valle
	# cerrado real (plateau con vecinas de igual o mayor altura).
	var es_mesa_cerrada := true
	for delta in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var vecino: Vector2i = ultima + delta
		if vecino.x < 0 or vecino.x >= VoxelWorld.ANCHO_MUNDO or vecino.y < 0 or vecino.y >= VoxelWorld.LARGO_MUNDO:
			continue
		if gen_rio_a._altura_flotante(vecino.x, vecino.y) < gen_rio_a._altura_flotante(ultima.x, ultima.y):
			es_mesa_cerrada = false
			break
	assert(termino_en_agua or cauce_a.size() == 1 or es_mesa_cerrada)
	print("OK: _trazar_rio() es determinista, respeta el tope de pasos, y termina en agua o en una mesa sin vecino más bajo (altura continua).")

	print("\n=== TEST 21: cada paso del cauce baja de altura continua hasta llegar a agua ===")
	for i in range(cauce_a.size() - 1):
		var actual: Vector2i = cauce_a[i]
		if gen_rio_a.es_agua_en(actual.x, actual.y):
			break
		var siguiente: Vector2i = cauce_a[i + 1]
		assert(gen_rio_a._altura_flotante(siguiente.x, siguiente.y) < gen_rio_a._altura_flotante(actual.x, actual.y))
	print("OK: ningún paso del cauce sube de altura continua antes de llegar a una celda de agua.")

	print("\n=== TEST 22: la generación de ríos es determinista end-to-end ===")
	var gen_full_a: RefCounted = GeneradorMundoScript.new(VoxelWorld.SEMILLA_MUNDO, VoxelWorld.ANCHO_MUNDO, VoxelWorld.LARGO_MUNDO)
	var gen_full_b: RefCounted = GeneradorMundoScript.new(VoxelWorld.SEMILLA_MUNDO, VoxelWorld.ANCHO_MUNDO, VoxelWorld.LARGO_MUNDO)
	var vio_rio := false
	for x in range(VoxelWorld.ANCHO_MUNDO):
		for z in range(VoxelWorld.LARGO_MUNDO):
			var a_es_rio: bool = gen_full_a.es_rio_en(x, z)
			assert(a_es_rio == gen_full_b.es_rio_en(x, z))
			if a_es_rio:
				vio_rio = true
				assert(gen_full_a.profundidad_rio_en(x, z) == gen_full_b.profundidad_rio_en(x, z))
				assert(gen_full_a.direccion_flujo_en(x, z) == gen_full_b.direccion_flujo_en(x, z))
	assert(vio_rio)
	print("OK: dos instancias con SEMILLA_MUNDO producen exactamente el mismo mapa de ríos, y al menos una celda de río existe.")

	print("\n=== TEST 23: profundidad_rio_en() está siempre en [1, PROFUNDIDAD_MAXIMA_RIO] donde es_rio_en() es true ===")
	for x in range(VoxelWorld.ANCHO_MUNDO):
		for z in range(VoxelWorld.LARGO_MUNDO):
			if gen_full_a.es_rio_en(x, z):
				var p: int = gen_full_a.profundidad_rio_en(x, z)
				assert(p >= 1 and p <= GeneradorMundoScript.PROFUNDIDAD_MAXIMA_RIO)
			else:
				assert(gen_full_a.profundidad_rio_en(x, z) == 0)
	print("OK: profundidad_rio_en() nunca sale de rango, y es 0 fuera de cualquier río.")

	print("\n=== TEST 24: direccion_flujo_en() en las celdas del CAUCE (no de su franja) apunta a altura continua menor ===")
	# direccion_flujo_en() está definida sobre TODA la franja de un río (Sección
	# 5 del spec: las celdas de franja heredan la dirección de su celda de
	# cauce por diseño) — una celda de franja no tiene ninguna garantía propia
	# de "cuesta abajo" en esa dirección, solo la celda de cauce que la generó
	# sí la tiene (ver _trazar_rio(), que ahora desciende por altura CONTINUA,
	# no entera — ver _altura_flotante()). Esta prueba reproduce exactamente
	# la selección de nacientes de _generar_rios() (mismo RNG sembrado en
	# semilla+5) para poder verificar la invariante real sobre las celdas de
	# cauce mismas, no sobre toda la franja.
	var altura_min_naciente_t24: int = GeneradorMundoScript.ALTURA_MAXIMA - GeneradorMundoScript.MARGEN_NACIENTE_RIO[0]
	var altura_max_naciente_t24: int = GeneradorMundoScript.ALTURA_MAXIMA - GeneradorMundoScript.MARGEN_NACIENTE_RIO[1]
	var candidatos_brutos_t24: Array[Vector2i] = []
	for x in range(VoxelWorld.ANCHO_MUNDO):
		for z in range(VoxelWorld.LARGO_MUNDO):
			var h_t24: int = gen_full_a.altura_en(x, z)
			if h_t24 >= altura_min_naciente_t24 and h_t24 <= altura_max_naciente_t24:
				candidatos_brutos_t24.append(Vector2i(x, z))
	var regiones_t24: Array = GeneradorMundoScript._agrupar_regiones_elevadas(candidatos_brutos_t24)
	var candidatos_t24: Array[Vector2i] = []
	for region_t24 in regiones_t24:
		candidatos_t24.append(gen_full_a._representante_de_region(region_t24))
	var rng_t24 := RandomNumberGenerator.new()
	rng_t24.seed = VoxelWorld.SEMILLA_MUNDO + 5
	var revisadas_t24 := 0
	var rios_generados_t24 := 0
	for i in range(GeneradorMundoScript.NUM_RIOS):
		if candidatos_t24.is_empty():
			break
		var idx: int = rng_t24.randi() % candidatos_t24.size()
		var origen: Vector2i = candidatos_t24[idx]
		candidatos_t24.remove_at(idx)
		rng_t24.randi_range(GeneradorMundoScript.ANCHO_MINIMO_RIO, GeneradorMundoScript.ANCHO_MAXIMO_RIO)  # consumir el mismo sorteo de ancho, aunque no se use aquí
		var candidatos_lejanos_t24: Array[Vector2i] = []
		for c in candidatos_t24:
			if Vector2(c.x - origen.x, c.y - origen.y).length() >= GeneradorMundoScript.MIN_DISTANCIA_NACIENTES:
				candidatos_lejanos_t24.append(c)
		candidatos_t24 = candidatos_lejanos_t24
		rios_generados_t24 += 1
		var cauce_t24: Array[Vector2i] = gen_full_a._trazar_rio(origen, VoxelWorld.ANCHO_MUNDO, VoxelWorld.LARGO_MUNDO)
		for j in range(cauce_t24.size() - 1):
			var actual_t24: Vector2i = cauce_t24[j]
			var siguiente_t24: Vector2i = cauce_t24[j + 1]
			assert(gen_full_a._altura_flotante(siguiente_t24.x, siguiente_t24.y) < gen_full_a._altura_flotante(actual_t24.x, actual_t24.y))
			revisadas_t24 += 1
	assert(revisadas_t24 > 0)
	print("OK: cada paso de cauce real (%d pasos revisados en los %d ríos) baja de altura continua, sin excepción." % [revisadas_t24, rios_generados_t24])

	print("\n=== TEST 25: toda celda de cascada es también una celda de río real ===")
	for x in range(VoxelWorld.ANCHO_MUNDO):
		for z in range(VoxelWorld.LARGO_MUNDO):
			if gen_full_a.es_cascada_en(x, z):
				assert(gen_full_a.es_rio_en(x, z))
	print("OK: ninguna celda de cascada existe fuera de la franja de un río.")

	print("\n=== TEST 26: es_cascada_en() coincide exactamente con la regla de caída de altura (cauce sintético) ===")
	# Semilla 42 con el par fijo (10,10)/(11,10) daba caída 0, así que ese
	# cauce sintético nunca ejercitaba la rama "sí es cascada" (habría pasado
	# igual aunque _marcar_cascadas() nunca marcara nada). En su lugar,
	# buscamos (mismo patrón que TEST 27) un par real de celdas vecinas con
	# caída de altura >= UMBRAL_CASCADA, para garantizar que
	# deberia_ser_cascada_26 sea true al menos una vez.
	var gen_casc: RefCounted = GeneradorMundoScript.new(42, 60, 60)
	var celda_a26 := Vector2i(-1, -1)
	var celda_b26 := Vector2i(-1, -1)
	for x26 in range(1, 59):
		for z26 in range(1, 59):
			var a26 := Vector2i(x26, z26)
			var b26 := Vector2i(x26 + 1, z26)
			if gen_casc.altura_en(a26.x, a26.y) - gen_casc.altura_en(b26.x, b26.y) >= GeneradorMundoScript.UMBRAL_CASCADA:
				celda_a26 = a26
				celda_b26 = b26
				break
		if celda_a26 != Vector2i(-1, -1):
			break
	assert(celda_a26 != Vector2i(-1, -1))
	var cauce_sintetico_26: Array[Vector2i] = [celda_a26, celda_b26]
	# _aplicar_ancho_profundidad() primero (mismo orden que _generar_rios()):
	# _marcar_cascadas() ahora exige que la celda ya esté registrada como río
	# real en _profundidad_rio antes de poder marcarla como cascada (ver
	# TEST 27) — sin este paso, la celda nunca calificaría sin importar la
	# caída real de altura.
	gen_casc._aplicar_ancho_profundidad(cauce_sintetico_26, 3, 60, 60)
	gen_casc._marcar_cascadas(cauce_sintetico_26, 3, 60, 60)
	var caida_26: int = gen_casc.altura_en(celda_a26.x, celda_a26.y) - gen_casc.altura_en(celda_b26.x, celda_b26.y)
	var deberia_ser_cascada_26: bool = caida_26 >= GeneradorMundoScript.UMBRAL_CASCADA
	assert(gen_casc.es_cascada_en(celda_a26.x, celda_a26.y) == deberia_ser_cascada_26)
	print("OK (caída real detectada: %d, UMBRAL_CASCADA=%d): es_cascada_en() coincide con la regla exacta de caída de altura." % [caida_26, GeneradorMundoScript.UMBRAL_CASCADA])

	print("\n=== TEST 27: _marcar_cascadas() nunca marca cascada una celda de franja que no está registrada como río real (invariante es_cascada_en => es_rio_en) ===")
	var gen_casc27: RefCounted = GeneradorMundoScript.new(7, 60, 60)
	var actual27 := Vector2i(-1, -1)
	var siguiente27 := Vector2i(-1, -1)
	for x27 in range(1, 59):
		for z27 in range(1, 59):
			var a27 := Vector2i(x27, z27)
			var b27 := Vector2i(x27 + 1, z27)
			if gen_casc27.altura_en(a27.x, a27.y) - gen_casc27.altura_en(b27.x, b27.y) >= GeneradorMundoScript.UMBRAL_CASCADA:
				actual27 = a27
				siguiente27 = b27
				break
		if actual27 != Vector2i(-1, -1):
			break
	assert(actual27 != Vector2i(-1, -1))
	var cauce_sintetico_27: Array[Vector2i] = [actual27, siguiente27]
	# A propósito NO se llama _aplicar_ancho_profundidad() aquí: simula que
	# estas celdas de franja nunca quedaron registradas como río real (por
	# estar bajo agua o reclamadas antes por un río más fuerte en
	# _resolver_cruces()) — _marcar_cascadas() no debe marcarlas como
	# cascada de todas formas, aunque la caída de altura del paso supere
	# UMBRAL_CASCADA. Antes del fix, _marcar_cascadas() marcaba TODA la
	# franja sin este chequeo, rompiendo es_cascada_en() => es_rio_en().
	gen_casc27._marcar_cascadas(cauce_sintetico_27, 3, 60, 60)
	for offset27 in [-1, 0, 1]:
		var celda27 := Vector2i(actual27.x, actual27.y + offset27)
		assert(not gen_casc27.es_rio_en(celda27.x, celda27.y))
		assert(not gen_casc27.es_cascada_en(celda27.x, celda27.y))
	print("OK: ninguna celda de franja se marca como cascada si _aplicar_ancho_profundidad() no la registró antes como río real.")

	print("\n=== TEST 28: un cauce crudo que no llega a agua se descarta y se reintenta con la siguiente candidata (sin gastar un cupo de NUM_RIOS) ===")
	# Reproduce exactamente la selección de nacientes/anchos de _generar_rios()
	# (mismo RNG sembrado en semilla+5, mismo orden de sorteos, mismo criterio
	# de reintento) para poder identificar, en un mundo real ya generado,
	# candidatas cuyo cauce crudo NO llega a agua — esas deben tener CERO
	# celdas registradas como río en el mundo final, y no deben contar para
	# los NUM_RIOS ríos finales (Sección 1: se reintenta con la siguiente
	# candidata en vez de terminar con menos ríos de los necesarios).
	var gen_t28: RefCounted = GeneradorMundoScript.new(VoxelWorld.SEMILLA_MUNDO, VoxelWorld.ANCHO_MUNDO, VoxelWorld.LARGO_MUNDO)
	var altura_min_naciente_t28: int = GeneradorMundoScript.ALTURA_MAXIMA - GeneradorMundoScript.MARGEN_NACIENTE_RIO[0]
	var altura_max_naciente_t28: int = GeneradorMundoScript.ALTURA_MAXIMA - GeneradorMundoScript.MARGEN_NACIENTE_RIO[1]
	var candidatos_brutos_t28: Array[Vector2i] = []
	for x in range(VoxelWorld.ANCHO_MUNDO):
		for z in range(VoxelWorld.LARGO_MUNDO):
			var h_t28: int = gen_t28.altura_en(x, z)
			if h_t28 >= altura_min_naciente_t28 and h_t28 <= altura_max_naciente_t28:
				candidatos_brutos_t28.append(Vector2i(x, z))
	var regiones_t28: Array = GeneradorMundoScript._agrupar_regiones_elevadas(candidatos_brutos_t28)
	var candidatos_t28: Array[Vector2i] = []
	for region_t28 in regiones_t28:
		candidatos_t28.append(gen_t28._representante_de_region(region_t28))
	var rng_t28 := RandomNumberGenerator.new()
	rng_t28.seed = VoxelWorld.SEMILLA_MUNDO + 5
	var vio_descartado_t28 := false
	var vio_sobreviviente_t28 := false
	var rios_encontrados_t28 := 0
	while rios_encontrados_t28 < GeneradorMundoScript.NUM_RIOS and not candidatos_t28.is_empty():
		var idx: int = rng_t28.randi() % candidatos_t28.size()
		var origen: Vector2i = candidatos_t28[idx]
		candidatos_t28.remove_at(idx)
		rng_t28.randi_range(GeneradorMundoScript.ANCHO_MINIMO_RIO, GeneradorMundoScript.ANCHO_MAXIMO_RIO)  # consumir el sorteo de ancho, mismo orden que _generar_rios()
		var candidatos_lejanos_t28: Array[Vector2i] = []
		for c in candidatos_t28:
			if Vector2(c.x - origen.x, c.y - origen.y).length() >= GeneradorMundoScript.MIN_DISTANCIA_NACIENTES:
				candidatos_lejanos_t28.append(c)
		candidatos_t28 = candidatos_lejanos_t28
		var cauce_t28: Array[Vector2i] = gen_t28._trazar_rio(origen, VoxelWorld.ANCHO_MUNDO, VoxelWorld.LARGO_MUNDO)
		var ultima_t28: Vector2i = cauce_t28[cauce_t28.size() - 1]
		if cauce_t28.size() < 2 or not gen_t28.es_agua_en(ultima_t28.x, ultima_t28.y):
			vio_descartado_t28 = true
			for celda_t28 in cauce_t28:
				assert(not gen_t28.es_rio_en(celda_t28.x, celda_t28.y))
			continue
		vio_sobreviviente_t28 = true
		rios_encontrados_t28 += 1
	assert(vio_descartado_t28)
	assert(vio_sobreviviente_t28)
	print("OK: los cauces crudos que no llegan a agua quedan con cero celdas registradas como río, y se reintenta con la siguiente candidata sin gastar un cupo de NUM_RIOS.")

	print("\n=== TEST 29: _agrupar_regiones_elevadas() separa regiones desconectadas y agrupa una región en L completa ===")
	var celdas_dos_islas: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1),  # isla A (conectada)
		Vector2i(10, 10), Vector2i(11, 10),  # isla B (conectada, lejos de A)
	]
	var regiones_dos_islas: Array = GeneradorMundoScript._agrupar_regiones_elevadas(celdas_dos_islas)
	assert(regiones_dos_islas.size() == 2)
	var tamanos_dos_islas: Array = []
	for r in regiones_dos_islas:
		tamanos_dos_islas.append(r.size())
	tamanos_dos_islas.sort()
	assert(tamanos_dos_islas == [2, 3])

	# Región en L: (0,0)-(0,1)-(0,2)-(1,2) — conectada por 4-vecindad aunque
	# no sea un rectángulo; (5,5) queda como región aparte (diagonal a (1,2)
	# no cuenta como conectada en 4-vecindad).
	var celdas_forma_l: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(5, 5)]
	var regiones_forma_l: Array = GeneradorMundoScript._agrupar_regiones_elevadas(celdas_forma_l)
	assert(regiones_forma_l.size() == 2)
	var tamanos_forma_l: Array = []
	for r in regiones_forma_l:
		tamanos_forma_l.append(r.size())
	tamanos_forma_l.sort()
	assert(tamanos_forma_l == [1, 4])
	print("OK: dos islas separadas dan dos regiones; una forma en L conectada por 4-vecindad da una sola región, sin fundirse con una celda diagonal aislada.")

	print("\n=== TEST 30: _representante_de_region() elige un punto real de la cumbre, cercano a su centro ===")
	# Busca en un mundo real una región conectada con al menos 2 celdas
	# empatadas en la altura máxima, para que el criterio de "más cercano al
	# centro de la cumbre" tenga más de un candidato real que decidir entre
	# ellos (con una sola celda en la cumbre, el resultado sería trivial).
	var gen_t30: RefCounted = GeneradorMundoScript.new(99, 80, 80)
	var altura_min_naciente_t30: int = GeneradorMundoScript.ALTURA_MAXIMA - GeneradorMundoScript.MARGEN_NACIENTE_RIO[0]
	var altura_max_naciente_t30: int = GeneradorMundoScript.ALTURA_MAXIMA - GeneradorMundoScript.MARGEN_NACIENTE_RIO[1]
	var candidatos_brutos_t30: Array[Vector2i] = []
	for x in range(80):
		for z in range(80):
			var h_t30: int = gen_t30.altura_en(x, z)
			if h_t30 >= altura_min_naciente_t30 and h_t30 <= altura_max_naciente_t30:
				candidatos_brutos_t30.append(Vector2i(x, z))
	var regiones_t30: Array = GeneradorMundoScript._agrupar_regiones_elevadas(candidatos_brutos_t30)
	var probada_t30 := false
	for region_t30 in regiones_t30:
		var max_altura_t30: int = gen_t30.altura_en(region_t30[0].x, region_t30[0].y)
		for celda in region_t30:
			max_altura_t30 = max(max_altura_t30, gen_t30.altura_en(celda.x, celda.y))
		var cumbre_t30: Array[Vector2i] = []
		for celda in region_t30:
			if gen_t30.altura_en(celda.x, celda.y) == max_altura_t30:
				cumbre_t30.append(celda)
		if cumbre_t30.size() < 2:
			continue
		var representante_t30: Vector2i = gen_t30._representante_de_region(region_t30)
		# El representante debe pertenecer a la cumbre (compartir su altura máxima)...
		assert(gen_t30.altura_en(representante_t30.x, representante_t30.y) == max_altura_t30)
		# ...y ser el más cercano al centro geométrico de esa cumbre, entre las
		# celdas de la propia cumbre (no de toda la región).
		var suma_x_t30 := 0
		var suma_z_t30 := 0
		for celda in cumbre_t30:
			suma_x_t30 += celda.x
			suma_z_t30 += celda.y
		var centro_t30 := Vector2(float(suma_x_t30) / cumbre_t30.size(), float(suma_z_t30) / cumbre_t30.size())
		var mejor_distancia_t30: float = Vector2(representante_t30.x, representante_t30.y).distance_to(centro_t30)
		for celda in cumbre_t30:
			assert(Vector2(celda.x, celda.y).distance_to(centro_t30) >= mejor_distancia_t30)
		probada_t30 = true
		break
	assert(probada_t30)
	print("OK: el representante de una región pertenece a su cumbre y es el más cercano al centro geométrico de esa cumbre.")

	print("\n=== TEST 31: densidad_peces_en() es determinista, está en [0,1], y es 0.0 fuera del agua (incluyendo ríos) ===")
	var gen_dens_peces_a: RefCounted = GeneradorMundoScript.new(555, 60, 60)
	var gen_dens_peces_b: RefCounted = GeneradorMundoScript.new(555, 60, 60)
	var vio_fuera_peces := false
	var vio_dentro_peces := false
	for x in range(0, 60, 3):
		for z in range(0, 60, 3):
			var a: float = gen_dens_peces_a.densidad_peces_en(x, z)
			var b: float = gen_dens_peces_b.densidad_peces_en(x, z)
			assert(is_equal_approx(a, b))
			assert(a >= 0.0 and a <= 1.0)
			if not gen_dens_peces_a.es_agua_en(x, z):
				vio_fuera_peces = true
				assert(a == 0.0)
			else:
				vio_dentro_peces = true
	assert(vio_fuera_peces)
	assert(vio_dentro_peces)

	# Verificar con la semilla real que hay ríos y dan densidad_peces no-cero
	var gen_peces_real: RefCounted = GeneradorMundoScript.new(VoxelWorld.SEMILLA_MUNDO, VoxelWorld.ANCHO_MUNDO, VoxelWorld.LARGO_MUNDO)
	var vio_rio_con_peces := false
	var vio_tierra_seca_cero := false
	for x in range(0, VoxelWorld.ANCHO_MUNDO, 5):
		for z in range(0, VoxelWorld.LARGO_MUNDO, 5):
			if gen_peces_real.es_rio_en(x, z):
				# Un río está FUERA del agua (altura > nivel_mar), pero debe dar densidad no-cero
				var dens: float = gen_peces_real.densidad_peces_en(x, z)
				assert(dens >= 0.0 and dens <= 1.0)
				if not is_equal_approx(dens, 0.0):
					vio_rio_con_peces = true
			elif not gen_peces_real.es_agua_en(x, z):
				# Tierra seca real (ni agua ni río) debe ser 0.0
				vio_tierra_seca_cero = true
				assert(gen_peces_real.densidad_peces_en(x, z) == 0.0)
	assert(vio_rio_con_peces)
	assert(vio_tierra_seca_cero)
	print("OK: densidad_peces_en es determinista, está en [0,1], es exactamente 0.0 en tierra seca, y da valores no-cero en ríos reales (confirmando que maneja both es_agua_en y es_rio_en).")

	print("\n=== TEST 32: densidad_algas_en()/_profundidad_relativa_agua_en() normalizan cada columna contra el techo de SU tipo de cuerpo de agua ===")
	var gen_algas: RefCounted = GeneradorMundoScript.new(VoxelWorld.SEMILLA_MUNDO, VoxelWorld.ANCHO_MUNDO, VoxelWorld.LARGO_MUNDO)
	var vio_rio_algas := false
	var vio_mar_algas := false
	for x in range(VoxelWorld.ANCHO_MUNDO):
		for z in range(VoxelWorld.LARGO_MUNDO):
			if not gen_algas.es_agua_en(x, z) and not gen_algas.es_rio_en(x, z):
				continue
			var relativa: float = gen_algas._profundidad_relativa_agua_en(x, z)
			assert(relativa >= 0.0 and relativa <= 1.0)
			assert(is_equal_approx(gen_algas.densidad_algas_en(x, z), 1.0 - relativa))
			if gen_algas.es_rio_en(x, z):
				vio_rio_algas = true
				var esperado_rio: float = float(gen_algas.profundidad_rio_en(x, z)) / float(GeneradorMundoScript.PROFUNDIDAD_MAXIMA_RIO)
				assert(is_equal_approx(relativa, esperado_rio))
			else:
				vio_mar_algas = true
				var techo: int = gen_algas.nivel_mar - GeneradorMundoScript.ALTURA_MINIMA
				var esperado_mar: float = clampf(float(gen_algas.nivel_mar - gen_algas.altura_en(x, z)) / float(techo), 0.0, 1.0)
				assert(is_equal_approx(relativa, esperado_mar))
	assert(vio_rio_algas)
	assert(vio_mar_algas)
	print("OK: la profundidad relativa de cada columna de agua se normaliza contra el techo de su propio tipo (río: PROFUNDIDAD_MAXIMA_RIO; mar/lago: nivel_mar - ALTURA_MINIMA), y densidad_algas_en() es siempre 1.0 menos esa profundidad relativa.")

	print("\n=== Las 32 pruebas de GeneradorMundo pasaron correctamente ===")

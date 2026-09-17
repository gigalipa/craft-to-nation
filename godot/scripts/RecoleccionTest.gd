extends Node

## Pruebas aisladas de Recoleccion.gd (mismo patrón que
## NiveladorTerrenoTest.gd/BlueprintValidatorTest.gd). Corre esta escena
## (RecoleccionTest.tscn) con F6 en el editor de Godot y revisa el panel
## "Output": debe imprimir las pruebas y no debe lanzar ningún error de
## assert().

const VoxelWorld = preload("res://scripts/VoxelWorld.gd")

## Generador falso: densidad de fauna/frutal constante dentro de un
## "bioma" cuadrado (|x|<=12, |z|<=12), 0.0 fuera — mismo patrón de
## generador falso determinista que NiveladorTerrenoTest.gd, para poder
## verificar el promedio con precisión (GeneradorMundo real usa ruido).
## Nota: bioma es ±12 para que todos los puntos dentro del círculo de radio 12
## caigan dentro del bioma, permitiendo que el promedio sea exacto.
class GeneradorBiomaFalso:
	func densidad_fauna_en(x: int, z: int) -> float:
		return 0.8 if abs(x) <= 12 and abs(z) <= 12 else 0.0
	func densidad_frutal_en(x: int, z: int) -> float:
		return 0.4 if abs(x) <= 12 and abs(z) <= 12 else 0.0
	func densidad_arbol_en(x: int, z: int) -> float:
		return 0.6 if abs(x) <= 12 and abs(z) <= 12 else 0.0


class GeneradorAguaFalso:
	func es_agua_o_rio_en(x: int, _z: int) -> bool:
		return x >= 0
	func densidad_peces_en(x: int, _z: int) -> float:
		return 0.5 if x >= 0 else 0.0
	func densidad_algas_en(x: int, _z: int) -> float:
		return 0.3 if x >= 0 else 0.0


## Agua conectada: cuadrado 6x6 en x=[0,5], z=[0,5] (36 celdas), más un
## charco de 1 celda en (10,10) SIN conexión con el cuadrado — separado por
## tierra. Sirve para distinguir un escaneo circular simple (que contaría
## el charco si cae dentro del radio) de un flood-fill real (que no debe
## alcanzarlo).
class GeneradorAguaConectadaFalso:
	func es_agua_o_rio_en(x: int, z: int) -> bool:
		if x == 10 and z == 10:
			return true
		return x >= 0 and x <= 5 and z >= 0 and z <= 5
	func densidad_peces_en(_x: int, _z: int) -> float:
		return 1.0
	func densidad_algas_en(_x: int, _z: int) -> float:
		return 1.0


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
	# ingenua (dx en [-6,6], dy en [0,8], dz en [-6,6]) pero FUERA del
	# semielipsoide real ((6/6)² + (6/8)² = 1.5625 > 1, con profundidad por
	# defecto = PROFUNDIDAD_MINA_NIVEL_1 = 8): si detectar_recursos() usara
	# una caja en vez del elipsoide real, este bloque se contaría de más.
	mundo.colocar_bloque(Vector3i(6, altura_superficie - 6, 0), "piedra")
	var conteo_esquina: Dictionary = Recoleccion.detectar_recursos(mundo, centro, altura_superficie)
	print("Conteo piedra antes de la esquina fuera del elipsoide: ", piedra_antes, " / después: ", conteo_esquina.get("piedra", 0))
	assert(conteo_esquina.get("piedra", 0) == piedra_antes)

	print("\n=== TEST 1b: 'profundidad' alcanza más hondo sin tocar el radio horizontal ===")
	# Bloque justo debajo del centro, a profundidad 12: fuera del alcance
	# nivel 1 (PROFUNDIDAD_MINA_NIVEL_1=8) pero dentro del alcance nivel 2
	# (PROFUNDIDAD_MINA_NIVEL_2=16) — confirma que subir "profundidad" sí
	# extiende el alcance vertical (antes quedaba sin efecto, capado por
	# RADIO_AREA_MINA=6 sin importar qué tan grande fuera "profundidad").
	mundo.colocar_bloque(Vector3i(0, altura_superficie - 12, 0), "hierro")
	var conteo_nivel_1: Dictionary = Recoleccion.detectar_recursos(mundo, centro, altura_superficie, Recoleccion.PROFUNDIDAD_MINA_NIVEL_1)
	var conteo_nivel_2: Dictionary = Recoleccion.detectar_recursos(mundo, centro, altura_superficie, Recoleccion.PROFUNDIDAD_MINA_NIVEL_2)
	assert(conteo_nivel_1.get("hierro", 0) == 2)
	assert(conteo_nivel_2.get("hierro", 0) == 3)
	print("OK: nivel 1 no alcanza el bloque a profundidad 12; nivel 2 sí.")

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

	print("\n=== TEST 7: detectar_fauna_frutal() promedia dentro del radio ===")
	var generador_bioma := GeneradorBiomaFalso.new()
	var promedios: Dictionary = Recoleccion.detectar_fauna_frutal(generador_bioma, Vector2i(0, 0))
	print("Promedios (centro del bioma): ", promedios)
	assert(is_equal_approx(promedios["fauna"], 0.8))
	assert(is_equal_approx(promedios["frutal"], 0.4))

	print("\n=== TEST 8: detectar_fauna_frutal() fuera del bioma da 0.0/0.0 ===")
	var promedios_fuera: Dictionary = Recoleccion.detectar_fauna_frutal(generador_bioma, Vector2i(1000, 1000))
	assert(is_equal_approx(promedios_fuera["fauna"], 0.0))
	assert(is_equal_approx(promedios_fuera["frutal"], 0.0))

	print("\n=== TEST 9: tasas_caza_recoleccion() multiplica cada señal por su tasa base ===")
	var tasas_caza: Dictionary = Recoleccion.tasas_caza_recoleccion({"fauna": 0.5, "frutal": 0.25})
	assert(is_equal_approx(tasas_caza["caza"], 0.5 * Recoleccion.TASA_BASE_CAZA_RECOLECCION_POR_CIUDADANO))
	assert(is_equal_approx(tasas_caza["recoleccion"], 0.25 * Recoleccion.TASA_BASE_CAZA_RECOLECCION_POR_CIUDADANO))

	print("\n=== TEST 10: quitar_puesto() libera la reserva ===")
	Recoleccion.puestos.clear()
	Recoleccion.colocar_puesto(Vector2i(50, 50), "blueprint", 5, 5)
	assert(Recoleccion.celda_dentro_de_algun_puesto(Vector2i(52, 52)))
	Recoleccion.quitar_puesto(Vector2i(50, 50))
	assert(not Recoleccion.celda_dentro_de_algun_puesto(Vector2i(52, 52)))
	Recoleccion.quitar_puesto(Vector2i(999, 999))  # no existía, no debe fallar
	print("OK: quitar_puesto() libera la reserva; quitar una esquina sin nada registrado no falla.")

	print("\n=== TEST 11: detectar_recursos() cuenta 'piso' como 'tierra' (superficie expuesta) ===")
	var mundo_superficie: Node = VoxelWorld.new()
	mundo_superficie.mesh_library = load("res://assets/BlockLibrary.res")
	mundo_superficie.cell_size = Vector3.ONE * 1.0
	mundo_superficie._indexar_biblioteca()
	assert(mundo_superficie.material_real("piso") == "tierra")
	assert(mundo_superficie.material_real("piedra") == "piedra")  # sin traducción, se devuelve igual

	# Misma superficie plana que TEST 1, pero con la capa expuesta como
	# "piso" (dy=0) y "tierra" real justo debajo (dy=1) — replica lo que
	# hace VoxelWorld._generar_terreno() en el mundo real.
	var centro_superficie := Vector2i(100, 100)
	var altura_sup := 10
	for dx in range(-Recoleccion.RADIO_AREA_MINA, Recoleccion.RADIO_AREA_MINA + 1):
		for dz in range(-Recoleccion.RADIO_AREA_MINA, Recoleccion.RADIO_AREA_MINA + 1):
			if Vector2(dx, dz).length() > Recoleccion.RADIO_AREA_MINA:
				continue
			mundo_superficie.colocar_bloque(Vector3i(centro_superficie.x + dx, altura_sup, centro_superficie.y + dz), "piso")
			mundo_superficie.colocar_bloque(Vector3i(centro_superficie.x + dx, altura_sup - 1, centro_superficie.y + dz), "tierra")

	var conteo_superficie: Dictionary = Recoleccion.detectar_recursos(mundo_superficie, centro_superficie, altura_sup)
	print("Conteo detectado (piso + tierra): ", conteo_superficie)
	assert(not conteo_superficie.has("piso"))
	assert(conteo_superficie.get("tierra", 0) > 0)
	# La celda dy=0 (el disco completo de radio 6, todas "piso") y la celda
	# dy=1 (mismo disco, todas "tierra" real) deben sumarse en un solo
	# conteo de "tierra". No es simplemente el doble de un disco 2D: al
	# igual que detectar_recursos(), la esfera real de acción usa distancia
	# 3D (dx, -dy, dz) — la capa dy=1 pierde algunas celdas del borde que sí
	# entran en el filtro 2D de colocación pero no en la esfera 3D exacta.
	var celdas_capa_0 := 0
	var celdas_capa_1 := 0
	for dx2 in range(-Recoleccion.RADIO_AREA_MINA, Recoleccion.RADIO_AREA_MINA + 1):
		for dz2 in range(-Recoleccion.RADIO_AREA_MINA, Recoleccion.RADIO_AREA_MINA + 1):
			if Vector3(dx2, 0, dz2).length() <= Recoleccion.RADIO_AREA_MINA:
				celdas_capa_0 += 1
			if Vector3(dx2, -1, dz2).length() <= Recoleccion.RADIO_AREA_MINA:
				celdas_capa_1 += 1
	assert(conteo_superficie["tierra"] == celdas_capa_0 + celdas_capa_1)
	print("OK: la capa superficial 'piso' se cuenta como 'tierra', sumada a la 'tierra' real de debajo.")

	print("\n=== TEST 12: detectar_recursos() ignora bloques estructurales de un edificio ===")
	var mundo_edificio: Node = VoxelWorld.new()
	mundo_edificio.mesh_library = load("res://assets/BlockLibrary.res")
	mundo_edificio.cell_size = Vector3.ONE * 1.0
	mundo_edificio._indexar_biblioteca()
	var centro_edificio := Vector2i(200, 200)
	var altura_edificio := 10
	mundo_edificio.colocar_bloque(Vector3i(centro_edificio.x, altura_edificio - 1, centro_edificio.y), "piedra")
	mundo_edificio.colocar_bloque(Vector3i(centro_edificio.x, altura_edificio, centro_edificio.y), "pared")
	mundo_edificio.colocar_bloque(Vector3i(centro_edificio.x + 1, altura_edificio, centro_edificio.y), "ventana")
	mundo_edificio.colocar_bloque(Vector3i(centro_edificio.x + 2, altura_edificio, centro_edificio.y), "puerta_inferior")
	mundo_edificio.colocar_bloque(Vector3i(centro_edificio.x + 3, altura_edificio, centro_edificio.y), "cama_pies")
	mundo_edificio.colocar_bloque(Vector3i(centro_edificio.x + 4, altura_edificio, centro_edificio.y), "baul")
	var conteo_edificio: Dictionary = Recoleccion.detectar_recursos(mundo_edificio, centro_edificio, altura_edificio)
	print("Conteo detectado bajo un edificio: ", conteo_edificio)
	assert(not conteo_edificio.has("pared"))
	assert(not conteo_edificio.has("ventana"))
	assert(not conteo_edificio.has("puerta_inferior"))
	assert(not conteo_edificio.has("cama_pies"))
	assert(not conteo_edificio.has("baul"))
	assert(conteo_edificio.get("piedra", 0) > 0)
	print("OK: una mina bajo un edificio nunca reporta sus bloques estructurales como recurso minable.")

	print("\n=== TEST 13: detectar_arbol()/tasa_maderero() — mismo patrón que caza/recolección ===")
	var generador_bioma_arbol := GeneradorBiomaFalso.new()
	var promedio_arbol: float = Recoleccion.detectar_arbol(generador_bioma_arbol, Vector2i(0, 0))
	print("Promedio de árbol (centro del bioma): ", promedio_arbol)
	assert(is_equal_approx(promedio_arbol, 0.6))
	var tasa_madero: Dictionary = Recoleccion.tasa_maderero(promedio_arbol)
	assert(is_equal_approx(tasa_madero["madera"], 0.6 * Recoleccion.TASA_BASE_MADERERO_POR_CIUDADANO))

	var promedio_arbol_fuera: float = Recoleccion.detectar_arbol(generador_bioma_arbol, Vector2i(1000, 1000))
	assert(is_equal_approx(promedio_arbol_fuera, 0.0))
	assert(is_equal_approx(Recoleccion.tasa_maderero(promedio_arbol_fuera)["madera"], 0.0))
	print("OK: detectar_arbol()/tasa_maderero() promedian densidad_arbol_en() igual que caza/recolección con fauna/frutal.")

	print("\n=== TEST 14: detectar_pesca_frutos_mar() promedia exactamente las celdas del Dictionary recibido ===")
	var generador_agua := GeneradorAguaFalso.new()
	var celdas_prueba: Dictionary = {Vector2i(0, 0): true, Vector2i(1, 0): true, Vector2i(2, 0): true}
	var promedios_pesca: Dictionary = Recoleccion.detectar_pesca_frutos_mar(generador_agua, celdas_prueba)
	print("Promedios (3 celdas dadas): ", promedios_pesca)
	assert(is_equal_approx(promedios_pesca["peces"], 0.5))
	assert(is_equal_approx(promedios_pesca["algas"], 0.3))
	print("OK: detectar_pesca_frutos_mar() promedia exactamente las celdas del Dictionary recibido, sin escanear nada por su cuenta.")

	print("\n=== TEST 15: detectar_pesca_frutos_mar() con un Dictionary vacío da 0.0/0.0 ===")
	var promedios_sin_agua: Dictionary = Recoleccion.detectar_pesca_frutos_mar(generador_agua, {})
	assert(is_equal_approx(promedios_sin_agua["peces"], 0.0))
	assert(is_equal_approx(promedios_sin_agua["algas"], 0.0))
	print("OK: sin ninguna celda de agua, ambas señales devuelven 0.0 sin dividir por cero.")

	print("\n=== TEST 16: tasas_pesca_frutos_mar() multiplica cada señal por su tasa base ===")
	var tasas_pesca: Dictionary = Recoleccion.tasas_pesca_frutos_mar({"peces": 0.5, "algas": 0.3})
	assert(is_equal_approx(tasas_pesca["pesca"], 0.5 * Recoleccion.TASA_BASE_PESCA_FRUTOS_MAR_POR_CIUDADANO))
	assert(is_equal_approx(tasas_pesca["frutos_mar"], 0.3 * Recoleccion.TASA_BASE_PESCA_FRUTOS_MAR_POR_CIUDADANO))

	print("\n=== TEST 17: celdas_agua_conectadas() sigue solo agua conectada por adyacencia, ignora un charco aislado dentro del mismo radio ===")
	var generador_conectada := GeneradorAguaConectadaFalso.new()
	var celdas: Dictionary = Recoleccion.celdas_agua_conectadas(generador_conectada, Vector2i(0, 0), 25)
	assert(celdas.size() == 36)
	for x in range(6):
		for z in range(6):
			assert(celdas.has(Vector2i(x, z)))
	assert(not celdas.has(Vector2i(10, 10)))
	print("OK: celdas_agua_conectadas() encontró las 36 celdas del cuadrado conectado e ignoró el charco aislado en (10,10).")

	print("\n=== TEST 18: celdas_agua_conectadas() nunca sale del radio, aunque el agua siga conectada más allá ===")
	var generador_infinita := GeneradorAguaFalso.new()
	var celdas_acotadas: Dictionary = Recoleccion.celdas_agua_conectadas(generador_infinita, Vector2i(0, 0), 5)
	assert(celdas_acotadas.size() > 0)
	for xz in celdas_acotadas:
		assert(Vector2(xz).length() <= 5.0)
	print("OK: celdas_agua_conectadas() respeta el radio como tope, aunque el agua siga conectada más allá (GeneradorAguaFalso es infinito en x>=0).")

	print("\n=== Las 18 pruebas de Recoleccion pasaron correctamente ===")

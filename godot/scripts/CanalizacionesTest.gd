extends Node

## Pruebas de Canalizaciones (Etapa 9.3):
## Catálogo, geometría con columnas cada 5 bloques (vano libre 4),
## esquinas, pendientes diagonales, cruces a desnivel y construcción.

const CanalizacionesScript = preload("res://scripts/Canalizaciones.gd")
const VoxelWorld = preload("res://scripts/VoxelWorld.gd")

class MundoMock:
	var _bloques: Dictionary = {} # Vector3i -> String
	var _alturas: Dictionary = {} # Vector2i -> int
	var altura_default: int = 10

	func altura_en(x: int, z: int) -> int:
		return _alturas.get(Vector2i(x, z), altura_default)

	func fijar_altura(x: int, z: int, h: int) -> void:
		_alturas[Vector2i(x, z)] = h

	func obtener_tipo(celda: Vector3i) -> String:
		return _bloques.get(celda, "")

	func colocar_bloque(celda: Vector3i, tipo: String, _por_jugador: bool = true) -> bool:
		_bloques[celda] = tipo
		return true

	func id_de_edificio(_celda: Vector3i) -> int:
		return -1

	func es_terreno_natural(_celda: Vector3i) -> bool:
		return false


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	print("=== CANALIZACIONES TEST 1: Catálogo y fluidos permitidos ===")
	var canalizaciones = CanalizacionesScript.new()
	assert(canalizaciones.TIPOS.has("acueducto"), "debe existir acueducto")
	assert(canalizaciones.TIPOS.has("tuberia"), "debe existir tuberia")
	assert(canalizaciones.es_fluido_permitido("acueducto", "agua"), "acueducto permite agua")
	assert(canalizaciones.es_fluido_permitido("acueducto", "combustible"), "acueducto permite combustible")
	assert(not canalizaciones.es_fluido_permitido("acueducto", "crudo"), "acueducto NO permite crudo")
	assert(canalizaciones.es_fluido_permitido("tuberia", "agua"), "tuberia permite agua")
	assert(canalizaciones.es_fluido_permitido("tuberia", "crudo"), "tuberia permite crudo")
	assert(canalizaciones.es_fluido_permitido("tuberia", "combustible"), "tuberia permite combustible")
	print("OK: Catálogo verificado.")

	print("\n=== CANALIZACIONES TEST 2: Geometría recta con columnas cada 5 bloques (vano 4) ===")
	var mundo = MundoMock.new()
	# Tramo recto de (0,0) a (10,0) (11 celdas horizontales, índices 0 a 10)
	var puntos_2d: Array[Vector2i] = []
	for x in range(11):
		puntos_2d.append(Vector2i(x, 0))

	var geom = canalizaciones.calcular_geometria_tramo("tuberia", puntos_2d, mundo)
	assert(geom.valido, "tramo recto debe ser valido")
	assert(geom.celdas_ducto.size() == 11, "debe haber 11 celdas de ducto")
	for c in geom.celdas_ducto:
		assert(c.y == 14, "altura de ducto debe ser Y=14 (10 + 4), fue %d" % c.y)

	# Columnas en índice 0 (0,0), índice 5 (5,0) y índice 10 (10,0)
	# Cada columna va de Y=11 a Y=13 (3 bloques de soporte)
	var columnas_por_xz: Dictionary = {}
	for col in geom.celdas_columna:
		var xz = Vector2i(col.x, col.z)
		if not columnas_por_xz.has(xz):
			columnas_por_xz[xz] = []
		columnas_por_xz[xz].append(col.y)

	assert(columnas_por_xz.has(Vector2i(0, 0)), "debe haber columna en x=0")
	assert(columnas_por_xz.has(Vector2i(5, 0)), "debe haber columna en x=5")
	assert(columnas_por_xz.has(Vector2i(10, 0)), "debe haber columna en x=10")
	assert(columnas_por_xz.size() == 3, "debe haber exactamente 3 columnas en total")
	assert(columnas_por_xz[Vector2i(0, 0)] == [11, 12, 13], "columna en 0 debe tener alturas 11, 12, 13")
	assert(columnas_por_xz[Vector2i(5, 0)] == [11, 12, 13], "columna en 5 debe tener alturas 11, 12, 13")
	assert(columnas_por_xz[Vector2i(10, 0)] == [11, 12, 13], "columna en 10 debe tener alturas 11, 12, 13")
	print("OK: Columnas en índices 0, 5, 10 con 4 celdas libres de vano entre ellas.")

	print("\n=== CANALIZACIONES TEST 3: Columnas en esquinas de 90° ===")
	# Tramo en L: (0,0) a (3,0) a (3,3)
	var puntos_l: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
		Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3)
	]
	var geom_l = canalizaciones.calcular_geometria_tramo("acueducto", puntos_l, mundo)
	assert(geom_l.valido, "tramo en L valido")
	var cols_l: Dictionary = {}
	for col in geom_l.celdas_columna:
		cols_l[Vector2i(col.x, col.z)] = true
	assert(cols_l.has(Vector2i(0, 0)), "columna en inicio")
	assert(cols_l.has(Vector2i(3, 0)), "columna OBLIGATORIA en esquina 90° (3,0)")
	assert(cols_l.has(Vector2i(3, 3)), "columna en fin")
	print("OK: Esquina de 90° tiene columna de soporte.")

	print("\n=== CANALIZACIONES TEST 4: Cruces a desnivel (+1 cota en intersección) ===")
	# Colocar previamente una tubería en mundo en (5, 14, 5) orientada en Z
	mundo.colocar_bloque(Vector3i(5, 14, 5), "tuberia")
	# Trazar una nueva tubería en X cruzando por (5, 5) horizontalmente de x=3 a x=7
	var puntos_cruce: Array[Vector2i] = []
	for x in range(3, 8):
		puntos_cruce.append(Vector2i(x, 5))
	var geom_cruce = canalizaciones.calcular_geometria_tramo("tuberia", puntos_cruce, mundo)
	assert(geom_cruce.valido, "cruce a desnivel debe ser valido")
	var ducto_en_cruce: Vector3i = Vector3i.ZERO
	for c in geom_cruce.celdas_ducto:
		if c.x == 5 and c.z == 5:
			ducto_en_cruce = c
			break
	assert(ducto_en_cruce != Vector3i.ZERO, "debe existir celda en (5,5)")
	assert(ducto_en_cruce.y == 15, "la celda de cruce debe sobre-elevarse a Y=15 (14 + 1), fue %d" % ducto_en_cruce.y)
	print("OK: Cruce a desnivel se eleva a Y=15.")

	print("\n=== CANALIZACIONES TEST 5: Pendientes diagonales entre columnas ===")
	# Terreno con pendiente entre x=0 (h=10) y x=5 (h=12)
	var mundo_pendiente = MundoMock.new()
	mundo_pendiente.fijar_altura(0, 0, 10)
	mundo_pendiente.fijar_altura(1, 0, 10)
	mundo_pendiente.fijar_altura(2, 0, 11)
	mundo_pendiente.fijar_altura(3, 0, 11)
	mundo_pendiente.fijar_altura(4, 0, 12)
	mundo_pendiente.fijar_altura(5, 0, 12)
	var puntos_pendiente: Array[Vector2i] = []
	for x in range(6):
		puntos_pendiente.append(Vector2i(x, 0))
	var geom_pend = canalizaciones.calcular_geometria_tramo("tuberia", puntos_pendiente, mundo_pendiente)
	assert(geom_pend.valido, "tramo en pendiente valido")
	# Columnas solo en 0 y 5
	var cols_pend: Dictionary = {}
	for col in geom_pend.celdas_columna:
		cols_pend[Vector2i(col.x, col.z)] = true
	assert(cols_pend.size() == 2, "debe haber solo 2 columnas en los extremos del vano de 4 celdas")
	assert(cols_pend.has(Vector2i(0, 0)) and cols_pend.has(Vector2i(5, 0)), "columnas en 0 y 5")
	# Ducto asciende desde 14 (10+4) hasta 16 (12+4)
	assert(geom_pend.celdas_ducto[0].y == 14, "inicio a 14")
	assert(geom_pend.celdas_ducto[-1].y == 16, "final a 16")
	print("OK: Pendiente diagonal une cimas sin columnas intermedias adicionales.")

	print("\n=== CANALIZACIONES TEST 6: Construir tramo materializa bloques y registra red ===")
	var id_red = canalizaciones.construir_tramo("tuberia", geom, mundo)
	assert(id_red > 0, "debe devolver un id_red valido")
	assert(mundo.obtener_tipo(Vector3i(0, 14, 0)) == "tuberia", "bloque ducto colocado en mundo")
	assert(mundo.obtener_tipo(Vector3i(0, 11, 0)) == "estructura_hierro", "columna colocada en mundo")
	assert(canalizaciones.obtener_red_de_celda(Vector3i(0, 14, 0)) == id_red, "celda registrada en red")
	print("OK: Tramo construido y registrado.")

	print("\n=== CANALIZACIONES TEST 7: Compatibilidad de ductos con puertos ===")
	assert(canalizaciones.es_puerto_compatible("acueducto", "puerto_agua_in"), "acueducto compatible con puerto_agua_in")
	assert(canalizaciones.es_puerto_compatible("acueducto", "puerto_combustible_out"), "acueducto compatible con puerto_combustible_out")
	assert(not canalizaciones.es_puerto_compatible("acueducto", "puerto_crudo_in"), "acueducto RECHAZA puerto_crudo_in")
	assert(not canalizaciones.es_puerto_compatible("acueducto", "puerto_crudo_out"), "acueducto RECHAZA puerto_crudo_out")
	assert(canalizaciones.es_puerto_compatible("tuberia", "puerto_crudo_in"), "tuberia compatible con puerto_crudo_in")
	print("OK: Compatibilidad de ducto y puerto validada.")

	print("\n=== CANALIZACIONES TEST 8: Despeje exterior de puerto acepta ducto compatible ===")
	var mundo_real: Node = VoxelWorld.new()
	mundo_real.mesh_library = load("res://assets/BlockLibrary.res")
	mundo_real.cell_size = Vector3.ONE * 1.0
	mundo_real._indexar_biblioteca()

	# Colocar tuberia en celda (1, 4, 0)
	mundo_real.colocar_bloque(Vector3i(1, 4, 0), "tuberia")
	assert(not mundo_real.despeje_bloqueado(Vector3i(1, 4, 0), {}, "puerto_crudo_out"), "tuberia en despeje de puerto_crudo_out NO bloquea")
	assert(not mundo_real.despeje_bloqueado(Vector3i(1, 4, 0), {}, "puerto_agua_in"), "tuberia en despeje de puerto_agua_in NO bloquea")

	# Colocar acueducto en (2, 4, 0)
	mundo_real.colocar_bloque(Vector3i(2, 4, 0), "acueducto")
	assert(not mundo_real.despeje_bloqueado(Vector3i(2, 4, 0), {}, "puerto_agua_out"), "acueducto en despeje de puerto_agua_out NO bloquea")
	assert(mundo_real.despeje_bloqueado(Vector3i(2, 4, 0), {}, "puerto_crudo_out"), "acueducto en despeje de puerto_crudo_out SI bloquea (incompatible)")

	# Colocar un bloque no ducto en (3, 4, 0)
	mundo_real.colocar_bloque(Vector3i(3, 4, 0), "bloque_piedra")
	assert(mundo_real.despeje_bloqueado(Vector3i(3, 4, 0), {}, "puerto_agua_out"), "bloque de piedra no ducto SI bloquea")
	print("OK: Despeje exterior de puerto acepta ductos compatibles y rechaza incompatibles.")

	print("\n=== CANALIZACIONES TEST 9: Conectar puertos a red y rechazar incompatibles ===")
	var red_agua: int = canalizaciones.construir_tramo("tuberia", geom, mundo)
	assert(canalizaciones.asignar_puerto_a_red(red_agua, Vector3i(0, 14, 0), "puerto_agua_out"), "asigna puerto agua out a red")
	assert(canalizaciones.recurso_de_red(red_agua) == "agua", "recurso de la red es agua")
	# Intentar conectar un puerto de crudo a la misma red de agua debe ser RECHAZADO
	assert(not canalizaciones.asignar_puerto_a_red(red_agua, Vector3i(10, 14, 0), "puerto_crudo_in"), "rechaza conectar puerto crudo a red de agua")
	print("OK: Regla de un solo recurso por red respetada.")

	print("\n=== Todas las pruebas de Canalizaciones pasaron correctamente ===")

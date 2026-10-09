extends Node

## Pruebas de Canalizaciones (Etapa 9.3):
## Catálogo, geometría con columnas cada 5 bloques (vano libre 4),
## esquinas, pendientes diagonales, cruces a desnivel y construcción.

const CanalizacionesScript = preload("res://scripts/Canalizaciones.gd")
const VoxelWorld = preload("res://scripts/VoxelWorld.gd")

class MundoMock:
	var _bloques: Dictionary = {} # Vector3i -> String
	var _alturas: Dictionary = {} # Vector2i -> int
	var celda_a_despeje: Dictionary = {} # Vector3i -> String
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

	func minar_bloque(celda: Vector3i) -> void:
		_bloques.erase(celda)

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
	assert(geom_cruce.tramos_diagonales.size() == 2, "debe generar 2 tramos diagonales (subida desde columna anterior y bajada a columna siguiente)")
	assert(geom_cruce.tramos_diagonales[0].fin == Vector3i(5, 15, 5), "el primer tramo diagonal llega al bloque elevado")
	assert(geom_cruce.tramos_diagonales[1].inicio == Vector3i(5, 15, 5), "el segundo tramo diagonal parte del bloque elevado")
	print("OK: Cruce a desnivel se eleva a Y=15 con tramos diagonales conectados a columnas anterior y siguiente.")

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
	# Tramo diagonal continuo detectado entre columnas
	assert(geom_pend.get("tramos_diagonales", []).size() == 1, "detecta 1 tramo diagonal continuo")
	assert(geom_pend.tramos_diagonales[0].inicio == Vector3i(0, 14, 0), "inicio de diagonal en cabezal de columna 0")
	assert(geom_pend.tramos_diagonales[0].fin == Vector3i(5, 16, 0), "fin de diagonal en cabezal de columna 5")
	var id_pend = canalizaciones.construir_tramo("tuberia", geom_pend, mundo_pendiente)
	assert(mundo_pendiente.obtener_tipo(Vector3i(0, 14, 0)) == "tuberia", "cubo cabezal en columna 0")
	assert(mundo_pendiente.obtener_tipo(Vector3i(5, 16, 0)) == "tuberia", "cubo cabezal en columna 5")
	assert(mundo_pendiente.obtener_tipo(Vector3i(2, 15, 0)) == "", "vano diagonal no coloca cubos discretos en GridMap")
	assert(canalizaciones.obtener_red_de_celda(Vector3i(2, 15, 0)) == id_pend, "celda intermedia registrada en red")
	print("OK: Pendiente diagonal une cimas sin columnas intermedias adicionales y con tramo diagonal continuo.")

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

	print("\n=== CANALIZACIONES TEST 10: Flujo instantáneo a destinos y derrames físicos ===")
	# Asignar puerto de entrada a red_agua en el otro extremo (10, 14, 0)
	assert(canalizaciones.asignar_puerto_a_red(red_agua, Vector3i(10, 14, 0), "puerto_agua_in"), "asigna puerto agua in a red")
	var destinos: Array = canalizaciones.destinos_de_puerto_salida(Vector3i(0, 14, 0))
	assert(destinos.has(Vector3i(10, 14, 0)), "destino conectado encontrado")
	assert(canalizaciones.estado_de_puerto(Vector3i(0, 14, 0)) == "conectado", "puerto en estado conectado")

	# Crear una red trunca sin puerto de entrada para probar derrame
	var puntos_derrame: Array[Vector2i] = [Vector2i(20, 20), Vector2i(21, 20), Vector2i(22, 20)]
	var geom_derrame = canalizaciones.calcular_geometria_tramo("tuberia", puntos_derrame, mundo)
	var red_derrame: int = canalizaciones.construir_tramo("tuberia", geom_derrame, mundo)
	canalizaciones.asignar_puerto_a_red(red_derrame, Vector3i(20, 14, 20), "puerto_crudo_out")
	assert(canalizaciones.destinos_de_puerto_salida(Vector3i(20, 14, 20)).is_empty(), "sin destino conectado")

	# Verter derrame
	var celda_derrame: Vector3i = canalizaciones.verter_derrame(red_derrame, "crudo", mundo)
	assert(celda_derrame != Vector3i.ZERO, "celda de derrame generada")
	assert(mundo.obtener_tipo(celda_derrame) == "crudo", "bloque crudo colocado fisicamente en el mundo")
	assert(canalizaciones.estado_de_puerto(Vector3i(20, 14, 20)) == "derrame", "puerto marcado en estado derrame")
	print("\n=== CANALIZACIONES TEST 11: Inicio frente a puerto alinea altura obligatoria y coloca 1ra columna a 5 bloques ===")
	var mundo_puerto = MundoMock.new()
	# Suelo en h=10
	for x in range(20):
		mundo_puerto.fijar_altura(x, 5, 10)
	# Puerto a altura Y=6 en (5, 6, 5)
	mundo_puerto.colocar_bloque(Vector3i(5, 6, 5), "puerto_agua_out")

	var puntos_puerto: Array[Vector2i] = []
	for x in range(6, 14): # x = 6 a 13 (8 bloques)
		puntos_puerto.append(Vector2i(x, 5))

	var geom_pto = canalizaciones.calcular_geometria_tramo("tuberia", puntos_puerto, mundo_puerto)
	assert(geom_pto.valido, "tramo desde puerto valido")
	# Celda 0 frente al puerto toma obligatoriamente la altura Y=6 del puerto (no 14)
	assert(geom_pto.celdas_ducto[0] == Vector3i(6, 6, 5), "inicio de ducto a cota del puerto Y=6")
	# La primera celda NO debe tener columna debajo
	var cols_pto: Dictionary = {}
	for col in geom_pto.celdas_columna:
		cols_pto[Vector2i(col.x, col.z)] = true
	assert(not cols_pto.has(Vector2i(6, 5)), "no hay columna en la celda inicial frente al puerto")
	# La primera columna debe estar exactamente a 5 bloques de distancia: x = 6 + 5 = 11
	assert(cols_pto.has(Vector2i(11, 5)), "primera columna ubicada a 5 bloques de distancia en x=11")
	# Altura del ducto en x=11 debe ser h_suelo + 4 = 14
	assert(geom_pto.celdas_ducto[5] == Vector3i(11, 14, 5), "ducto en columna 1 a cota normal Y=14")
	# Debe haber un tramo diagonal continuo que conecte (6, 6, 5) con (11, 14, 5)
	assert(geom_pto.tramos_diagonales.size() >= 1, "debe generarse tramo diagonal desde el puerto a la 1ra columna")
	assert(geom_pto.tramos_diagonales[0].inicio == Vector3i(6, 6, 5), "diagonal inicia en ducto de puerto")
	assert(geom_pto.tramos_diagonales[0].fin == Vector3i(11, 14, 5), "diagonal termina en cabezal de 1ra columna")
	print("OK: Altura obligatoria de puerto y primera columna a 5 bloques verificada.")

	print("\n=== CANALIZACIONES TEST 12: Despeje de puertos contiguos y desconexión/derrame dinámico al minar ===")
	canalizaciones = CanalizacionesScript.new()
	var mundo12 = MundoMock.new()
	# 1. Registrar despeje de un puerto de crudo
	mundo12.celda_a_despeje[Vector3i(5, 14, 1)] = "puerto_crudo_out"
	# Trazar acueducto que pasa por (5, 14, 1) debe ser rechazado
	var puntos_invaden: Array[Vector2i] = [Vector2i(5, 0), Vector2i(5, 1), Vector2i(5, 2)]
	var geom_inv = canalizaciones.calcular_geometria_tramo("acueducto", puntos_invaden, mundo12)
	assert(not geom_inv.valido, "acueducto no debe invadir despeje de puerto de crudo")
	assert("puerto de crudo" in geom_inv.motivo, "motivo debe indicar el puerto invadido: %s" % geom_inv.motivo)

	# 2. Probar desconexión / derrame al minar bloque intermedio
	var puntos_flujo: Array[Vector2i] = [Vector2i(0, 40), Vector2i(1, 40), Vector2i(2, 40), Vector2i(3, 40)]
	for pt in puntos_flujo:
		mundo12.fijar_altura(pt.x, pt.y, 10)
	var geom_flujo = canalizaciones.calcular_geometria_tramo("tuberia", puntos_flujo, mundo12)
	var red_flujo: int = canalizaciones.construir_tramo("tuberia", geom_flujo, mundo12)
	var p_out12 := Vector3i(0, 14, 40)
	var p_in12 := Vector3i(3, 14, 40)
	canalizaciones.asignar_puerto_a_red(red_flujo, p_out12, "puerto_crudo_out")
	canalizaciones.asignar_puerto_a_red(red_flujo, p_in12, "puerto_crudo_in")
	assert(canalizaciones.estado_de_puerto(p_out12) == "conectado")
	assert(canalizaciones.estado_de_puerto(p_in12) == "conectado")

	# Minar el bloque en x=2
	canalizaciones.quitar_celdas([Vector3i(2, 14, 40)], mundo12)
	assert(canalizaciones.estado_de_puerto(p_out12) == "derrame", "al romperse la vía hacia el destino, la salida pasa a derrame: %s" % canalizaciones.estado_de_puerto(p_out12))
	assert(canalizaciones.estado_de_puerto(p_in12) == "desconectado", "al quedar inalcanzable, la entrada pasa a desconectado")
	print("OK: Despeje y desconexión/derrame dinámico verificados.")

	print("\n=== Todas las pruebas de Canalizaciones pasaron correctamente ===")


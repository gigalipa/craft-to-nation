extends Node

const VoxelWorld = preload("res://scripts/VoxelWorld.gd")

## Equivalente GDScript de ejecutar_pruebas() en PoC_2 (tests 1-6), más
## pruebas propias de PoC 3 para "declarar edificio" (7-8, ver
## VoxelWorld.detectar_estructura()), objetos multi-celda puerta/cama (9,
## ver VoxelWorld.colocar_puerta()/colocar_cama()), una casa real
## multi-nivel de punta a punta (10, ver BlueprintValidator.estructura_a_
## blueprint() — fusión de capas de Y en "pisos" por historia), el rechazo
## de un techo abierto (11, ver validar_techo_y_suelo()), un edificio de 2
## pisos con hueco de escalera en la losa intermedia (12, ver
## _es_losa_parcial()), y el rechazo de un piso con altura insuficiente (13,
## ver validar_altura_piso()), y que "piso" nunca es material estructural,
## ni siquiera como relleno de terreno tocando la losa de un edificio (14,
## ver VoxelWorld.TIPOS_ESTRUCTURA), que altura_en() ignora los bloques de
## árbol al buscar la celda sólida más alta (15, ver VoxelWorld.TIPOS_ARBOL),
## que verificar_huella_libre() detecta madera, follaje y estructura (16,
## ver VoxelWorld.verificar_huella_libre()), y que estructura_a_blueprint()
## conserva la forma 3D real en celdas_3d (17, ver BlueprintValidator.celdas_3d),
## y que iniciar_construccion_fantasma()/surtir_construccion() colocan y
## convierten bloques "fantasma" en orden fijo y reemparejan puertas/camas al
## completarse (18, ver VoxelWorld.iniciar_construccion_fantasma()), y que
## altura_en() también salta "fantasma" (como los árboles) y que
## verificar_huella_libre() revisa varios niveles Y cuando se le pasa
## "altura" > 1 (19, ver VoxelWorld.altura_en()/verificar_huella_libre()), y
## que registrar_edificio() vuelve inmunes al minado las celdas, tanto en
## fantasmas como en bloques reales (20, ver VoxelWorld.registrar_edificio()/
## minar_bloque()), y que estructura_a_blueprint() reconoce una huella
## irregular (un edificio en L) sin exigir que su caja delimitadora
## completa tenga suelo/techo, y calcula "huella_relativa" con solo las
## columnas reales (21, ver BlueprintValidator._es_losa_completa()/
## _es_losa_parcial()), y que procesar_deconstruccion()/eliminar_edificio()
## revierten un edificio recorriendo en reversa el MISMO orden canónico
## de construcción (mobiliario primero, piso al final — un solo índice
## bidireccional, ver
## docs/superpowers/specs/2026-09-11-construccion-reversible-design.md) (22,
## ver VoxelWorld.procesar_deconstruccion()), que deconstruir un edificio a
## medio construir solo revierte hasta donde llegó el progreso, sin tocar
## celdas que nunca se surtieron (23), y que iniciar_construccion_fantasma()
## nunca registra el relleno de nivelación como parte del edificio (24, ver
## VoxelWorld.iniciar_construccion_fantasma()), que pausar una construcción,
## deconstruir una parte, y retomarla usa el mismo índice de progreso en
## ambos sentidos sin perder ni duplicar celdas (25, ver
## VoxelWorld.surtir_construccion()/procesar_deconstruccion()), que
## procesar_deconstruccion() sobre un puesto periférico (tipo de bloque no
## deconstruible) es un no-op silencioso, nunca un error (26), y que
## registrar_edificio_completo() deja un edificio declarado a mano tan
## reversible como uno por blueprint, sin perder su metadata (27, ver
## Player._declarar_edificio()), que calcular_despeje() reserva 1 celda
## externa por ventana y 2 por puerta en ambos niveles (28-29, ver
## docs/superpowers/specs/2026-09-11-despeje-ventanas-puertas-design.md),
## que verificar_despejes() rechaza tanto un despeje propio ocupado (30)
## como una celda estructural nueva que invade el despeje ajeno (31), que
## los despejes de dos edificios distintos pueden solaparse libremente sin
## rechazo (32), y que eliminar_edificio() libera la reserva de despeje de
## inmediato (33), y que cuando el despeje de dos edificios se solapa,
## deconstruir uno de ellos no libera por error la reserva del vecino que
## sigue en pie, y solo se libera del todo cuando ambos dueños desaparecen
## (34, ver VoxelWorld.celda_a_despeje).
## Correr esta escena (Test.tscn) con F6 en el editor de Godot y revisar el
## panel "Output": debe imprimir los 34 tests y no debe lanzar ningún error
## de assert().

const BLUEPRINT_VALIDO_JSON := """
{
  "nombre": "Cabana_Colono_v1",
  "tipo": "residencial",
  "zona_permitida": "residencial_investigacion",
  "pisos": [
    {
      "nivel": 0,
      "celdas": {
        "0,0": "pared", "1,0": "puerta", "2,0": "pared",
        "0,1": "pared", "1,1": "baul",   "2,1": "pared",
        "0,2": "pared", "1,2": "ventana","2,2": "pared"
      },
      "camas": [{"pos": "1,1"}]
    }
  ]
}
"""


func _ready() -> void:
	ejecutar_pruebas()


func _rectangulo(ancho: int, alto: int) -> Array[Vector2i]:
	var columnas: Array[Vector2i] = []
	for x in range(ancho):
		for z in range(alto):
			columnas.append(Vector2i(x, z))
	return columnas


func ejecutar_pruebas() -> void:
	print("=== TEST 1: Blueprint Válido (debe pasar sin errores) ===")
	var bp_valido: Dictionary = JSON.parse_string(BLUEPRINT_VALIDO_JSON)
	var resultado: Dictionary = BlueprintValidator.validar_blueprint(bp_valido, "residencial_investigacion")
	print("Válido: ", resultado["valido"], " | Errores: ", resultado["errores"])
	assert(resultado["valido"])

	print("\n=== TEST 2: Hueco en el Perímetro ===")
	var bp_con_hueco: Dictionary = JSON.parse_string(BLUEPRINT_VALIDO_JSON)
	bp_con_hueco["pisos"][0]["celdas"]["2,1"] = "piso"
	resultado = BlueprintValidator.validar_blueprint(bp_con_hueco)
	print("Válido: ", resultado["valido"], " | Errores: ", resultado["errores"])
	assert(not resultado["valido"])

	print("\n=== TEST 3: Esquina Reemplazada por Ventana ===")
	var bp_esquina: Dictionary = JSON.parse_string(BLUEPRINT_VALIDO_JSON)
	bp_esquina["pisos"][0]["celdas"]["0,0"] = "ventana"
	resultado = BlueprintValidator.validar_blueprint(bp_esquina)
	print("Válido: ", resultado["valido"], " | Errores: ", resultado["errores"])
	assert(not resultado["valido"])

	print("\n=== TEST 4: Sin Ventana ===")
	var bp_sin_ventana: Dictionary = JSON.parse_string(BLUEPRINT_VALIDO_JSON)
	bp_sin_ventana["pisos"][0]["celdas"]["1,2"] = "pared"
	resultado = BlueprintValidator.validar_blueprint(bp_sin_ventana)
	print("Válido: ", resultado["valido"], " | Errores: ", resultado["errores"])
	assert(not resultado["valido"])

	print("\n=== TEST 5: Cama sin Baúl (conteo total, no emparejado por posición) ===")
	var bp_sin_baul: Dictionary = JSON.parse_string(BLUEPRINT_VALIDO_JSON)
	bp_sin_baul["pisos"][0]["celdas"]["1,1"] = "piso"  # quita el único baúl del edificio
	resultado = BlueprintValidator.validar_blueprint(bp_sin_baul)
	print("Válido: ", resultado["valido"], " | Errores: ", resultado["errores"])
	assert(not resultado["valido"])
	assert(resultado["errores"][0].contains("cama(s) pero solo 0 baúl(es)"))

	print("\n=== TEST 6: Colocación en Zona Incorrecta ===")
	resultado = BlueprintValidator.validar_blueprint(bp_valido, "fabricacion_militar")
	print("Válido: ", resultado["valido"], " | Errores: ", resultado["errores"])
	assert(not resultado["valido"])

	print("\n=== TEST 7: Declarar Edificio - Habitaciones, Puerta Interior, Cama y Baúl ===")
	# Planta 7x3 (x:0-6, z:0-2), con suelo (y=0) y techo (y=4) reales para
	# satisfacer la verificación de suelo/techo sólido (ver TEST 11), y 3
	# capas de pared (y=1,2,3) para cumplir la altura mínima por piso (ver
	# TEST 13). La habitación (y=1, la única con mobiliario) tiene puerta
	# principal en x=0, puerta interior en
	# x=3 (el caso que motivó este diseño: ¿el flood-fill reconoce ambos
	# lados aunque la puerta interior esté cerrada? Sí, porque avanza por
	# bloques sólidos contiguos, no por espacio transitable), una cama de
	# 2 celdas (x=1,2) y un baúl (x=5) en la habitación este — habitaciones
	# distintas, sin emparejamiento por posición, para demostrar la regla de
	# conteo total. Puertas y cama se colocan con colocar_puerta()/
	# colocar_cama(), no con colocar_bloque() directo, para ejercitar la
	# verificación de espacio de 2 celdas (su mitad superior queda en y=2).
	# Instanciar VoxelWorld.new() para evitar la generación automática del terreno (_ready() no se llamará).
	var mundo: Node = VoxelWorld.new()
	mundo.mesh_library = load("res://assets/BlockLibrary.res")
	mundo.cell_size = Vector3.ONE * 1.0
	mundo._indexar_biblioteca()
	for x in range(7):
		for z in range(3):
			mundo.colocar_bloque(Vector3i(x, 0, z), "pared", true)  # suelo
			mundo.colocar_bloque(Vector3i(x, 4, z), "pared", true)  # techo
	# Tercera capa de pared (y=3): solo el anillo perimetral, sin mobiliario
	# ni aberturas — necesaria únicamente para llegar a la altura mínima.
	for x in [0, 6]:
		for z in range(3):
			mundo.colocar_bloque(Vector3i(x, 3, z), "pared", true)
	for x in range(1, 6):
		mundo.colocar_bloque(Vector3i(x, 3, 0), "pared", true)
		mundo.colocar_bloque(Vector3i(x, 3, 2), "pared", true)
	var tipos_simples := {
		Vector3i(0, 1, 0): "pared", Vector3i(1, 1, 0): "pared", Vector3i(2, 1, 0): "pared",
		Vector3i(3, 1, 0): "pared", Vector3i(4, 1, 0): "pared", Vector3i(5, 1, 0): "pared",
		Vector3i(6, 1, 0): "pared",
		Vector3i(4, 1, 1): "pared", Vector3i(5, 1, 1): "baul", Vector3i(6, 1, 1): "ventana",
		Vector3i(0, 1, 2): "pared", Vector3i(1, 1, 2): "pared", Vector3i(2, 1, 2): "pared",
		Vector3i(3, 1, 2): "pared", Vector3i(4, 1, 2): "pared", Vector3i(5, 1, 2): "pared",
		Vector3i(6, 1, 2): "pared",
	}
	for celda in tipos_simples.keys():
		mundo.colocar_bloque(celda, tipos_simples[celda], true)
	assert(mundo.colocar_puerta(Vector3i(0, 1, 1)))  # puerta principal (y=1 y y=2)
	assert(mundo.colocar_puerta(Vector3i(3, 1, 1)))  # puerta interior (y=1 y y=2)
	assert(mundo.colocar_cama(Vector3i(1, 1, 1), Vector3i(1, 0, 0)))  # cabecera (1,1), pies (2,1)

	var puerta_principal := Vector3i(0, 1, 1)
	var estructura: Dictionary = mundo.detectar_estructura(puerta_principal)
	# 21 (suelo) + 21 (techo) + 21 (habitación, y=1, huella completa) + 2
	# (mitades superiores de las 2 puertas, y=2) + 16 (anillo perimetral en
	# y=3) = 81 celdas físicas.
	print("Celdas físicas detectadas: ", estructura.size(), " (esperadas: 81)")
	assert(estructura.size() == 81)

	var blueprint_detectado := BlueprintValidator.estructura_a_blueprint(estructura)
	# Suelo y techo son losas — se descartan, queda 1 solo "piso" (la
	# habitación) con sus 21 celdas abstractas (las mitades superiores de
	# puerta se remapean a "pared" y no generan celdas nuevas).
	print("Pisos abstractos: ", blueprint_detectado["pisos"].size(), " (esperados: 1)")
	assert(blueprint_detectado["pisos"].size() == 1)
	print("Celdas del Blueprint: ", blueprint_detectado["pisos"][0]["celdas"].size(), " (esperadas: 21)")
	assert(blueprint_detectado["pisos"][0]["celdas"].size() == 21)
	assert(blueprint_detectado["pisos"][0]["camas"].size() == 1)

	resultado = BlueprintValidator.validar_blueprint(blueprint_detectado)
	print("Válido: ", resultado["valido"], " | Errores: ", resultado["errores"])
	# Estructura completa y válida de punta a punta: cerramiento, esquinas,
	# puertas/ventanas, techo/suelo sólidos, cama detectada Y un baúl en el
	# edificio (aunque en una habitación distinta, sin emparejamiento por
	# posición) alcanzan para pasar todas las reglas.
	assert(resultado["valido"])
	assert(resultado["errores"].is_empty())

	print("\n=== TEST 8: Declarar Edificio - Rechaza Bloque no Marcado como Jugador ===")
	# Un bloque colocado sin marcar como colocado_por_jugador no se detecta
	# como estructura. Simular el escenario del terreno del mundo (_generar_terreno)
	# que nunca marca sus bloques como colocado_por_jugador.
	var celda_terreno := Vector3i(0, -1, 0)
	mundo.colocar_bloque(celda_terreno, "piso", false)  # no marcado como jugador
	assert(mundo.obtener_tipo(celda_terreno) == "piso")
	assert(mundo.detectar_estructura(celda_terreno).is_empty())
	print("Correcto: el bloque no marcado como jugador no es detectado como estructura.")

	print("\n=== TEST 9: Puerta y Cama Rechazadas por Falta de Espacio ===")
	var base_puerta := Vector3i(10, 0, 0)
	mundo.colocar_bloque(base_puerta + Vector3i(0, 1, 0), "pared", true)  # bloquea la mitad superior
	assert(not mundo.colocar_puerta(base_puerta))
	assert(mundo.obtener_tipo(base_puerta) == "")
	print("Correcto: la puerta no se coloca sin 2 celdas verticales libres.")

	var base_cama := Vector3i(20, 0, 0)
	mundo.colocar_bloque(base_cama + Vector3i(0, 0, 1), "pared", true)  # bloquea la celda de los pies
	assert(not mundo.colocar_cama(base_cama, Vector3i(0, 0, 1)))
	assert(mundo.obtener_tipo(base_cama) == "")
	print("Correcto: la cama no se coloca sin 2 celdas libres en la dirección indicada.")

	print("\n=== TEST 10: Declarar Edificio - Casa Real Multi-Nivel (suelo+3+techo) ===")
	# Replica el reporte de bug real: una casa de 4x5 de huella y 5 de alto,
	# con suelo (y=0) y techo (y=4) sólidos de "pared", puerta principal
	# (2 celdas verticales, y=1-2), ventana (y=2) y una cama+baúl en la
	# esquina interior (y=1) — dejando el resto del espacio interior sin
	# ningún bloque (aire transitable), tal como construiría un jugador real.
	# Antes del fix, cada capa de Y se validaba como su propio "piso": el
	# suelo/techo fallaban por falta de puerta/ventana, y la cama/baúl
	# generaban "hueco en el perímetro" falso porque su vecino interior
	# (aire, sin bloque) no estaba registrado en esa misma capa. Coordenadas
	# desplazadas +50 en X para no chocar con los bloques de tests previos.
	const OX := 50
	for x in range(OX, OX + 4):
		for z in range(5):
			mundo.colocar_bloque(Vector3i(x, 0, z), "pared", true)  # suelo
			mundo.colocar_bloque(Vector3i(x, 4, z), "pared", true)  # techo
	for y in range(1, 4):
		for x in range(OX, OX + 4):
			for z in range(5):
				var es_borde: bool = x == OX or x == OX + 3 or z == 0 or z == 4
				if not es_borde:
					continue
				if x == OX and z == 2:
					continue  # puerta principal, se coloca aparte
				if x == OX + 3 and z == 2 and y == 2:
					continue  # ventana, se coloca aparte
				mundo.colocar_bloque(Vector3i(x, y, z), "pared", true)
	assert(mundo.colocar_puerta(Vector3i(OX, 1, 2)))  # puerta principal (y=1 y y=2)
	mundo.colocar_bloque(Vector3i(OX, 3, 2), "pared", true)  # pared sobre la puerta
	mundo.colocar_bloque(Vector3i(OX + 3, 2, 2), "ventana", true)
	assert(mundo.colocar_cama(Vector3i(OX + 1, 1, 1), Vector3i(0, 0, 1)))  # cabecera/pies interior
	mundo.colocar_bloque(Vector3i(OX + 1, 1, 3), "baul", true)  # a los pies de la cama

	var estructura_casa: Dictionary = mundo.detectar_estructura(Vector3i(OX, 1, 2))
	var blueprint_casa := BlueprintValidator.estructura_a_blueprint(estructura_casa)
	print("Pisos abstractos: ", blueprint_casa["pisos"].size(), " (esperados: 1 — suelo y techo son losas, se descartan)")
	assert(blueprint_casa["pisos"].size() == 1)

	resultado = BlueprintValidator.validar_blueprint(blueprint_casa)
	print("Válido: ", resultado["valido"], " | Errores: ", resultado["errores"])
	assert(resultado["valido"])
	assert(resultado["errores"].is_empty())

	print("\n=== TEST 17: estructura_a_blueprint() conserva la forma 3D real en celdas_3d ===")
	# Misma casa de TEST 10: reconstruir celdas_3d normalizado a mano y
	# comparar contra la estructura original (también normalizada) — debe
	# conservar los tipos SIN aplanar (puerta_inferior/superior distintos,
	# no colapsados a "puerta"/"pared" como hace "pisos").
	assert(blueprint_casa["ancho"] == 4)
	assert(blueprint_casa["profundidad"] == 5)
	assert(blueprint_casa["categoria"] == "residencial")
	var celdas_3d_casa: Dictionary = blueprint_casa["celdas_3d"]
	assert(celdas_3d_casa.size() == estructura_casa.size())
	var y_min_casa: int = estructura_casa.keys()[0].y
	var x_min_casa: int = estructura_casa.keys()[0].x
	var z_min_casa: int = estructura_casa.keys()[0].z
	for pos in estructura_casa.keys():
		y_min_casa = min(y_min_casa, pos.y)
		x_min_casa = min(x_min_casa, pos.x)
		z_min_casa = min(z_min_casa, pos.z)
	for pos in estructura_casa.keys():
		var normalizado: Vector3i = pos - Vector3i(x_min_casa, y_min_casa, z_min_casa)
		assert(celdas_3d_casa.has(normalizado))
		assert(celdas_3d_casa[normalizado] == estructura_casa[pos])
	# La puerta principal debe seguir apareciendo como 2 celdas distintas
	# (puerta_inferior/puerta_superior en Y consecutiva), no colapsada.
	var puerta_inferior_normalizada := Vector3i(OX, 1, 2) - Vector3i(x_min_casa, y_min_casa, z_min_casa)
	var puerta_superior_normalizada := puerta_inferior_normalizada + Vector3i(0, 1, 0)
	assert(celdas_3d_casa[puerta_inferior_normalizada] == "puerta_inferior")
	assert(celdas_3d_casa[puerta_superior_normalizada] == "puerta_superior")
	print("OK: celdas_3d conserva la forma real completa, ancho/profundidad correctos.")

	print("\n=== TEST 11: Declarar Edificio - Rechaza Techo Abierto ===")
	# Misma casa que TEST 10 (suelo + 3 capas de pared, puerta y ventana),
	# pero sin colocar el techo (y=4) — el caso reportado tras el fix de
	# TEST 10: el jugador dejó el techo abierto a propósito al construir un
	# 2do piso, y la estructura se declaraba "válida" igual, porque nada
	# comprobaba que existiera un techo físico por encima de la historia.
	# Coordenadas +100 en X para no chocar con los bloques de tests previos.
	const OX2 := 100
	for x in range(OX2, OX2 + 4):
		for z in range(5):
			mundo.colocar_bloque(Vector3i(x, 0, z), "pared", true)  # solo suelo, sin techo
	for y in range(1, 4):
		for x in range(OX2, OX2 + 4):
			for z in range(5):
				var es_borde: bool = x == OX2 or x == OX2 + 3 or z == 0 or z == 4
				if not es_borde:
					continue
				if x == OX2 and z == 2:
					continue  # puerta principal
				if x == OX2 + 3 and z == 2 and y == 2:
					continue  # ventana
				mundo.colocar_bloque(Vector3i(x, y, z), "pared", true)
	assert(mundo.colocar_puerta(Vector3i(OX2, 1, 2)))
	mundo.colocar_bloque(Vector3i(OX2, 3, 2), "pared", true)
	mundo.colocar_bloque(Vector3i(OX2 + 3, 2, 2), "ventana", true)

	var estructura_sin_techo: Dictionary = mundo.detectar_estructura(Vector3i(OX2, 1, 2))
	var blueprint_sin_techo := BlueprintValidator.estructura_a_blueprint(estructura_sin_techo)
	resultado = BlueprintValidator.validar_blueprint(blueprint_sin_techo)
	print("Válido: ", resultado["valido"], " | Errores: ", resultado["errores"])
	# Esta casa tampoco tiene cama (no es el foco de este test), así que
	# también reporta "no tiene ninguna cama" — lo relevante es que detecte
	# el techo faltante.
	assert(not resultado["valido"])
	var tiene_error_techo := false
	for error in resultado["errores"]:
		if (error as String).contains("falta un techo sólido"):
			tiene_error_techo = true
	assert(tiene_error_techo)

	print("\n=== TEST 12: Declarar Edificio - 2 Pisos con Hueco de Escalera ===")
	# Casa de 2 historias, huella 5x5 (x:0-4, z:0-4): suelo (y=0) y techo (y=8)
	# completos; historia 1 (y=1-3, con puerta+ventana+cama+baúl); losa
	# intermedia (y=4) sólida EXCEPTO un hueco de 1 celda en el centro (2,2)
	# — la "escalera" — que la deja por debajo del 100% pero muy por encima
	# del 50% de cobertura estructural interior, así que sigue reconociéndose
	# como losa (parcial) y no rompe el edificio en 2 "no-pisos" separados;
	# historia 2 (y=5-7, con su propia puerta+ventana). Debe detectarse como
	# 2 pisos válidos, no como 1 solo ni como error de techo/suelo.
	const OX3 := 200
	for x in range(OX3, OX3 + 5):
		for z in range(5):
			mundo.colocar_bloque(Vector3i(x, 0, z), "pared", true)  # suelo base
			mundo.colocar_bloque(Vector3i(x, 8, z), "pared", true)  # techo exterior
	for y in range(1, 4):
		for x in range(OX3, OX3 + 5):
			for z in range(5):
				var es_borde: bool = x == OX3 or x == OX3 + 4 or z == 0 or z == 4
				if not es_borde:
					continue
				if x == OX3 and z == 2:
					continue  # puerta historia 1
				if x == OX3 + 4 and z == 2 and y == 2:
					continue  # ventana historia 1
				mundo.colocar_bloque(Vector3i(x, y, z), "pared", true)
	assert(mundo.colocar_puerta(Vector3i(OX3, 1, 2)))
	mundo.colocar_bloque(Vector3i(OX3, 3, 2), "pared", true)
	mundo.colocar_bloque(Vector3i(OX3 + 4, 2, 2), "ventana", true)
	assert(mundo.colocar_cama(Vector3i(OX3 + 1, 1, 1), Vector3i(1, 0, 0)))
	mundo.colocar_bloque(Vector3i(OX3 + 3, 1, 1), "baul", true)
	for x in range(OX3, OX3 + 5):
		for z in range(5):
			if x == OX3 + 2 and z == 2:
				continue  # hueco de escalera (centro de la losa intermedia)
			mundo.colocar_bloque(Vector3i(x, 4, z), "pared", true)
	for y in range(5, 8):
		for x in range(OX3, OX3 + 5):
			for z in range(5):
				var es_borde2: bool = x == OX3 or x == OX3 + 4 or z == 0 or z == 4
				if not es_borde2:
					continue
				if x == OX3 and z == 2:
					continue  # puerta historia 2
				if x == OX3 + 4 and z == 2 and y == 6:
					continue  # ventana historia 2
				mundo.colocar_bloque(Vector3i(x, y, z), "pared", true)
	assert(mundo.colocar_puerta(Vector3i(OX3, 5, 2)))
	mundo.colocar_bloque(Vector3i(OX3, 7, 2), "pared", true)
	mundo.colocar_bloque(Vector3i(OX3 + 4, 6, 2), "ventana", true)

	var estructura_2p: Dictionary = mundo.detectar_estructura(Vector3i(OX3, 1, 2))
	var blueprint_2p := BlueprintValidator.estructura_a_blueprint(estructura_2p)
	print("Pisos abstractos: ", blueprint_2p["pisos"].size(), " (esperados: 2)")
	assert(blueprint_2p["pisos"].size() == 2)

	resultado = BlueprintValidator.validar_blueprint(blueprint_2p)
	print("Válido: ", resultado["valido"], " | Errores: ", resultado["errores"])
	assert(resultado["valido"])
	assert(resultado["errores"].is_empty())

	print("\n=== TEST 13: Declarar Edificio - Rechaza Piso con Altura Insuficiente ===")
	# Casa mínima 3x3 con suelo (y=0), techo (y=3) y una sola capa de pared
	# habitable (y=1-2, altura 2) — por debajo del mínimo de 3 capas.
	const OX4 := 300
	for x in range(OX4, OX4 + 3):
		for z in range(3):
			mundo.colocar_bloque(Vector3i(x, 0, z), "pared", true)
			mundo.colocar_bloque(Vector3i(x, 3, z), "pared", true)
	for y in range(1, 3):
		for x in range(OX4, OX4 + 3):
			for z in range(3):
				var es_borde3: bool = x == OX4 or x == OX4 + 2 or z == 0 or z == 2
				if es_borde3:
					mundo.colocar_bloque(Vector3i(x, y, z), "pared", true)

	var estructura_baja: Dictionary = mundo.detectar_estructura(Vector3i(OX4, 0, 0))
	var blueprint_bajo := BlueprintValidator.estructura_a_blueprint(estructura_baja)
	assert(blueprint_bajo["pisos"].size() == 1)
	resultado = BlueprintValidator.validar_blueprint(blueprint_bajo)
	print("Válido: ", resultado["valido"], " | Errores: ", resultado["errores"])
	assert(not resultado["valido"])
	var tiene_error_altura := false
	for error in resultado["errores"]:
		if (error as String).contains("altura insuficiente"):
			tiene_error_altura = true
	assert(tiene_error_altura)

	print("\n=== TEST 14: Declarar Edificio - 'piso' NUNCA es Estructural (ni en losas) ===")
	# Reemplaza el TEST 14 original (que validaba que "piso" SÍ podía ser una
	# losa de suelo/techo real). Bug reportado por el usuario jugando en vivo:
	# si el jugador coloca un bloque de "piso" para rellenar terreno bajo la
	# losa de suelo de un edificio (hecha con "pared"), el flood-fill lo
	# reconocía como parte del edificio. Decisión de diseño confirmada: "piso"
	# deja de ser material estructural en absoluto — ni en muros, ni en losas
	# de suelo/techo. Los materiales estructurales válidos para la PoC son
	# solo "pared" (más adelante: madera, piedra, metal, vidrio).
	# Casa 5x6 con suelo/techo/muros de "pared" (como TEST 10), más un bloque
	# de "piso" colocado_por_jugador=true justo debajo de la losa de suelo,
	# simulando el relleno de terreno del reporte del bug. Coordenadas +150 en
	# X para no chocar con los bloques de tests previos.
	const OX5 := 150
	for x in range(OX5, OX5 + 5):
		for z in range(6):
			mundo.colocar_bloque(Vector3i(x, 0, z), "pared", true)  # suelo
			mundo.colocar_bloque(Vector3i(x, 4, z), "pared", true)  # techo
	for y in [1, 2, 3]:
		for x in range(OX5, OX5 + 5):
			for z in range(6):
				var es_borde5: bool = x == OX5 or x == OX5 + 4 or z == 0 or z == 5
				if es_borde5:
					mundo.colocar_bloque(Vector3i(x, y, z), "pared", true)
	mundo.minar_bloque(Vector3i(OX5, 1, 3))
	mundo.minar_bloque(Vector3i(OX5, 2, 3))
	assert(mundo.colocar_puerta(Vector3i(OX5, 1, 3)))
	mundo.minar_bloque(Vector3i(OX5 + 4, 2, 2))
	mundo.colocar_bloque(Vector3i(OX5 + 4, 2, 2), "ventana", true)
	assert(mundo.colocar_cama(Vector3i(OX5 + 2, 1, 1), Vector3i(0, 0, 1)))
	mundo.colocar_bloque(Vector3i(OX5 + 1, 1, 1), "baul", true)

	# Relleno de terreno: un bloque de "piso" colocado por el jugador, tocando
	# físicamente la losa de suelo del edificio (y=-1, justo debajo de y=0).
	var celda_relleno := Vector3i(OX5 + 2, -1, 3)
	mundo.colocar_bloque(celda_relleno, "piso", true)

	var estructura_piso_real: Dictionary = mundo.detectar_estructura(Vector3i(OX5, 1, 3))
	assert(not estructura_piso_real.has(celda_relleno))
	print("Correcto: el relleno de 'piso' no se incluyó en la estructura detectada.")

	# El bloque de relleno tampoco puede servir de ORIGEN para declarar un
	# edificio: "piso" nunca es estructural, así que detectar_estructura()
	# devuelve vacío aunque esté colocado_por_jugador.
	assert(mundo.detectar_estructura(celda_relleno).is_empty())

	var blueprint_piso_real := BlueprintValidator.estructura_a_blueprint(estructura_piso_real)
	print("Pisos abstractos: ", blueprint_piso_real["pisos"].size(), " (esperados: 1)")
	assert(blueprint_piso_real["pisos"].size() == 1)
	assert(blueprint_piso_real["pisos"][0]["altura_capas"] == 3)
	assert(blueprint_piso_real["pisos"][0]["suelo_completo"])
	assert(blueprint_piso_real["pisos"][0]["techo_completo"])

	resultado = BlueprintValidator.validar_blueprint(blueprint_piso_real)
	print("Válido: ", resultado["valido"], " | Errores: ", resultado["errores"])
	assert(resultado["valido"])
	assert(resultado["errores"].is_empty())

	print("\n=== TEST 15: altura_en() ignora bloques de árbol (madera/follaje) ===")
	# Bug reportado por el usuario jugando en vivo: el overlay de zona y la
	# colocación de minas usan altura_en() para ubicarse sobre "el suelo",
	# pero esa función contaba cualquier bloque sólido como tal —
	# incluyendo los árboles que VoxelWorld._generar_arboles() coloca sobre
	# el terreno, así que overlay/minas terminaban aterrizando sobre la
	# copa de un árbol en vez del terreno real debajo.
	const OX6 := 400
	mundo.colocar_bloque(Vector3i(OX6, 0, 0), "piso")
	mundo.colocar_bloque(Vector3i(OX6, 1, 0), "madera")
	mundo.colocar_bloque(Vector3i(OX6, 2, 0), "madera")
	mundo.colocar_bloque(Vector3i(OX6, 3, 0), "follaje")
	assert(mundo.altura_en(OX6, 0) == 0)
	print("OK: altura_en() devuelve la altura del 'piso' real (0), no la del follaje que lo cubre (3).")

	print("\n=== TEST 16: verificar_huella_libre() detecta madera, follaje y estructura ===")
	const OX7 := 500

	# Huella A: "madera" invalida la huella completa.
	for dx in range(4):
		for dz in range(4):
			mundo.colocar_bloque(Vector3i(OX7 + dx, 0, OX7 + dz), "piso")
	mundo.colocar_bloque(Vector3i(OX7, 1, OX7), "madera")
	var resultado_madera: Dictionary = mundo.verificar_huella_libre(Vector2i(OX7, OX7), _rectangulo(4, 4))
	assert(not resultado_madera["valida"])

	# Huella B: "follaje" no invalida, se acumula para eliminar.
	var base_b := OX7 + 20
	for dx in range(4):
		for dz in range(4):
			mundo.colocar_bloque(Vector3i(base_b + dx, 0, OX7 + dz), "piso")
	mundo.colocar_bloque(Vector3i(base_b + 1, 1, OX7), "follaje")
	var resultado_follaje: Dictionary = mundo.verificar_huella_libre(Vector2i(base_b, OX7), _rectangulo(4, 4))
	assert(resultado_follaje["valida"])
	assert(resultado_follaje["follaje_a_eliminar"].size() == 1)
	assert(resultado_follaje["follaje_a_eliminar"][0] == Vector3i(base_b + 1, 1, OX7))

	# Huella C: un bloque estructural del jugador ("pared") invalida la huella.
	var base_c := OX7 + 40
	for dx in range(4):
		for dz in range(4):
			mundo.colocar_bloque(Vector3i(base_c + dx, 0, OX7 + dz), "piso")
	mundo.colocar_bloque(Vector3i(base_c + 2, 1, OX7), "pared", true)
	var resultado_estructura: Dictionary = mundo.verificar_huella_libre(Vector2i(base_c, OX7), _rectangulo(4, 4))
	assert(not resultado_estructura["valida"])

	# Huella D: sin nada encima — válida, sin follaje que eliminar.
	var base_d := OX7 + 60
	for dx in range(4):
		for dz in range(4):
			mundo.colocar_bloque(Vector3i(base_d + dx, 0, OX7 + dz), "piso")
	var resultado_libre: Dictionary = mundo.verificar_huella_libre(Vector2i(base_d, OX7), _rectangulo(4, 4))
	assert(resultado_libre["valida"])
	assert(resultado_libre["follaje_a_eliminar"].is_empty())

	print("OK: madera/estructura invalidan la huella, follaje se acumula sin invalidar, huella limpia queda válida.")

	print("\n=== TEST 18: iniciar_construccion_fantasma()/surtir_construccion() ===")
	const OX8 := 600
	for dx in range(2):
		for dz in range(2):
			mundo.colocar_bloque(Vector3i(OX8 + dx, 0, OX8 + dz), "piso")
	var orden_18: Array[Vector3i] = [
		Vector3i(OX8, 1, OX8), Vector3i(OX8 + 1, 1, OX8),
	]
	var tipos_18 := {
		Vector3i(OX8, 1, OX8): "puerta_inferior",
		Vector3i(OX8 + 1, 1, OX8): "pared",
	}
	mundo.colocar_bloque(Vector3i(OX8, 2, OX8), "puerta_superior")  # ya real, no fantasma: completa el par de la puerta
	mundo.iniciar_construccion_fantasma([], {}, orden_18, tipos_18)
	assert(mundo.obtener_tipo(Vector3i(OX8, 1, OX8)) == "fantasma")
	assert(mundo.obtener_tipo(Vector3i(OX8 + 1, 1, OX8)) == "fantasma")

	var s1: Dictionary = mundo.surtir_construccion(Vector3i(OX8 + 1, 1, OX8))  # apunta a la 2da, pero convierte la 1ra (orden fijo)
	assert(mundo.obtener_tipo(Vector3i(OX8, 1, OX8)) == "puerta_inferior")
	assert(mundo.obtener_tipo(Vector3i(OX8 + 1, 1, OX8)) == "fantasma")
	assert(not s1.get("completa", true))

	var s2: Dictionary = mundo.surtir_construccion(Vector3i(OX8 + 1, 1, OX8))
	assert(mundo.obtener_tipo(Vector3i(OX8 + 1, 1, OX8)) == "pared")
	assert(s2["completa"])
	assert(mundo.pareja.get(Vector3i(OX8, 1, OX8)) == Vector3i(OX8, 2, OX8))  # reemparejada al completarse
	assert(mundo.pareja.get(Vector3i(OX8, 2, OX8)) == Vector3i(OX8, 1, OX8))

	var s3: Dictionary = mundo.surtir_construccion(Vector3i(OX8, 1, OX8))  # ya no es una celda fantasma
	assert(s3.is_empty())
	print("OK: la construcción fantasma se surte en orden fijo, se reempareja al completarse, y no puede volver a surtirse.")

	print("\n=== TEST 19: altura_en() salta 'fantasma', verificar_huella_libre() revisa varios niveles ===")
	const OX9 := 700
	for dx in range(2):
		for dz in range(2):
			mundo.colocar_bloque(Vector3i(OX9 + dx, 0, OX9 + dz), "piso")
	mundo.colocar_bloque(Vector3i(OX9, 1, OX9), "fantasma")
	assert(mundo.altura_en(OX9, OX9) == 0)  # salta el fantasma, ve el piso real debajo

	# Una celda "madera" flotando en y=2 (con un hueco vacío en y=1, sobre el
	# "piso" real en y=0) debe rechazar una huella de altura >= 2 que la
	# alcance, aunque la huella de altura 1 (comportamiento por defecto,
	# como usan los puestos) no llegue tan alto y no la vea.
	mundo.colocar_bloque(Vector3i(OX9 + 1, 2, OX9), "madera")
	var resultado_baja: Dictionary = mundo.verificar_huella_libre(Vector2i(OX9, OX9), _rectangulo(2, 2))
	assert(resultado_baja["valida"])  # altura por defecto (1): no llega al madera en y=2
	var resultado_alta: Dictionary = mundo.verificar_huella_libre(Vector2i(OX9, OX9), _rectangulo(2, 2), 2)
	assert(not resultado_alta["valida"])  # altura 2: sí llega al madera en y=2, rechaza
	print("OK: altura_en() ignora 'fantasma', verificar_huella_libre() revisa 'altura' niveles hacia arriba.")

	print("\n=== TEST 20: registrar_edificio() vuelve inmune al minado ===")

	# Celda normal, no registrada: sigue minándose igual que siempre.
	var celda_normal := Vector3i(800, 50, 800)
	mundo.colocar_bloque(celda_normal, "pared", true)
	var mineo_normal: bool = mundo.minar_bloque(celda_normal)
	assert(mineo_normal, "Una celda normal, no registrada, debe poder minarse")
	assert(mundo.obtener_tipo(celda_normal) == "", "La celda normal minada debe quedar vacía")

	# Celda registrada directamente (simula un puesto o un núcleo declarado):
	# no debe poder minarse.
	var celda_edificio := Vector3i(801, 50, 800)
	mundo.colocar_bloque(celda_edificio, "pared", true)
	mundo.registrar_edificio([celda_edificio])
	var mineo_edificio: bool = mundo.minar_bloque(celda_edificio)
	assert(not mineo_edificio, "Una celda registrada como parte de un edificio no debe poder minarse")
	assert(mundo.obtener_tipo(celda_edificio) == "pared", "La celda registrada debe seguir intacta tras intentar minarla")

	# Fantasma en curso: inmune desde que se inicia, antes de surtir nada.
	var celda_fantasma := Vector3i(802, 50, 800)
	var orden_fantasma: Array[Vector3i] = [celda_fantasma]
	var tipos_fantasma := {celda_fantasma: "pared"}
	mundo.iniciar_construccion_fantasma([], {}, orden_fantasma, tipos_fantasma)
	var mineo_fantasma: bool = mundo.minar_bloque(celda_fantasma)
	assert(not mineo_fantasma, "Una celda fantasma en curso no debe poder minarse")
	assert(mundo.obtener_tipo(celda_fantasma) == "fantasma", "La celda fantasma debe seguir intacta tras intentar minarla")

	# Se completa surtiendo la única celda pendiente: debe seguir inmune
	# después de convertirse en bloque real.
	mundo.surtir_construccion(celda_fantasma)
	var mineo_fantasma_completo: bool = mundo.minar_bloque(celda_fantasma)
	assert(not mineo_fantasma_completo, "Una celda de un edificio ya terminado (vía fantasma) no debe poder minarse")
	assert(mundo.obtener_tipo(celda_fantasma) == "pared", "La celda debe haberse convertido a su tipo real")

	print("OK: minar_bloque() ignora cualquier celda registrada con registrar_edificio(), sea directa, fantasma en curso, o fantasma completada.")

	print("\n=== TEST 21: estructura_a_blueprint() reconoce una huella en L ===")
	# Construye "celdas" (Vector3i -> tipo físico) a mano, sin pasar por
	# VoxelWorld: un edificio en L (cuadrado de 5x5 menos un cuadrado de 2x2
	# en una esquina, 21 columnas reales en vez de las 25 de la caja
	# delimitadora). Antes del fix, _es_losa_completa()/_es_losa_parcial()
	# exigían las 25 columnas completas y esta construcción se rechazaba con
	# "falta un suelo/techo sólido" pese a estar perfectamente cerrada.
	var interiores_l: Array[Vector2i] = [
		Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
		Vector2i(1, 2), Vector2i(2, 2), Vector2i(1, 3),
	]
	var notch_l: Array[Vector2i] = [Vector2i(3, 3), Vector2i(3, 4), Vector2i(4, 3), Vector2i(4, 4)]

	var celdas_l: Dictionary = {}
	for x in range(5):
		for z in range(5):
			if notch_l.has(Vector2i(x, z)):
				continue
			celdas_l[Vector3i(x, 0, z)] = "pared"  # suelo
			celdas_l[Vector3i(x, 4, z)] = "pared"  # techo
	for y in range(1, 4):
		for x in range(5):
			for z in range(5):
				var col := Vector2i(x, z)
				if notch_l.has(col) or interiores_l.has(col):
					continue
				if x == 1 and z == 0:
					continue  # puerta principal, se coloca aparte
				if x == 0 and z == 2 and y == 2:
					continue  # ventana, se coloca aparte
				celdas_l[Vector3i(x, y, z)] = "pared"
	celdas_l[Vector3i(1, 1, 0)] = "puerta_inferior"
	celdas_l[Vector3i(1, 2, 0)] = "puerta_superior"
	celdas_l[Vector3i(1, 3, 0)] = "pared"  # pared sobre la puerta
	celdas_l[Vector3i(0, 2, 2)] = "ventana"
	celdas_l[Vector3i(1, 1, 1)] = "cama_cabecera"
	celdas_l[Vector3i(2, 1, 1)] = "cama_pies"
	celdas_l[Vector3i(2, 1, 2)] = "baul"

	var blueprint_l := BlueprintValidator.estructura_a_blueprint(celdas_l)
	print("Columnas de la huella real: ", blueprint_l["huella_relativa"].size(), " (esperadas: 21, no 25 = 5x5 completo)")
	assert(blueprint_l["huella_relativa"].size() == 21)
	assert(blueprint_l["ancho"] == 5)
	assert(blueprint_l["profundidad"] == 5)
	for celda_notch in notch_l:
		assert(not blueprint_l["huella_relativa"].has(celda_notch), "El hueco de la L no debe aparecer en huella_relativa")

	var resultado_l: Dictionary = BlueprintValidator.validar_blueprint(blueprint_l)
	print("Válido: ", resultado_l["valido"], " | Errores: ", resultado_l["errores"])
	assert(resultado_l["valido"])
	assert(resultado_l["errores"].is_empty())
	print("OK: estructura_a_blueprint() reconoce la huella en L y validar_blueprint() la acepta.")

	print("\n=== TEST 22: procesar_deconstruccion()/eliminar_edificio() revierten en el mismo orden de construcción, mobiliario primero ===")
	const OX10 := 900
	var celda_piso_22 := Vector3i(OX10, 0, OX10)
	var celda_pared_22 := Vector3i(OX10, 1, OX10)
	var celda_cabecera_22 := Vector3i(OX10 + 1, 1, OX10)
	var celda_pies_22 := Vector3i(OX10 + 2, 1, OX10)
	var celda_baul_22 := Vector3i(OX10 + 3, 1, OX10)
	mundo.colocar_bloque(celda_piso_22, "piso", true)
	mundo.colocar_bloque(celda_pared_22, "pared", true)
	mundo.colocar_bloque(celda_cabecera_22, "cama_cabecera", true)
	mundo.colocar_bloque(celda_pies_22, "cama_pies", true)
	mundo.colocar_bloque(celda_baul_22, "baul", true)
	var celdas_mundo_22 := {
		celda_piso_22: "piso",
		celda_pared_22: "pared",
		celda_cabecera_22: "cama_cabecera",
		celda_pies_22: "cama_pies",
		celda_baul_22: "baul",
	}
	var id_22: int = mundo.registrar_edificio_completo(celdas_mundo_22)

	# Primer intento: revierte la ÚLTIMA celda del orden canónico
	# (mobiliario, ordenado por x: cabecera antes que pies antes que
	# baúl) — aunque el jugador haya apuntado a la pared.
	var r1_22: Dictionary = mundo.procesar_deconstruccion(celda_pared_22)
	assert(r1_22["id"] == id_22)
	assert(r1_22["total_camas"] == 1, "Debe contar 1 cama_cabecera al cruzar de completo a incompleto")
	assert(mundo.obtener_tipo(celda_baul_22) == "fantasma", "El baúl es el último del orden, se revierte primero")
	assert(mundo.obtener_tipo(celda_pies_22) == "cama_pies", "Todavía no le toca")
	assert(not r1_22["completa_reversion"])

	var r2_22: Dictionary = mundo.procesar_deconstruccion(celda_pared_22)
	assert(mundo.obtener_tipo(celda_pies_22) == "fantasma")
	assert(r2_22["total_camas"] == 0, "Solo cuenta en el cruce completo -> incompleto")

	var _r3_22: Dictionary = mundo.procesar_deconstruccion(celda_pared_22)
	assert(mundo.obtener_tipo(celda_cabecera_22) == "fantasma")

	var r4_22: Dictionary = mundo.procesar_deconstruccion(celda_pared_22)
	assert(mundo.obtener_tipo(celda_pared_22) == "fantasma", "Estructura después del mobiliario")
	assert(not r4_22["completa_reversion"])

	var r5_22: Dictionary = mundo.procesar_deconstruccion(celda_pared_22)
	assert(mundo.obtener_tipo(celda_piso_22) == "fantasma", "Piso al final")
	assert(r5_22["completa_reversion"] and r5_22["lista_para_remocion"])

	var r6_22: Dictionary = mundo.procesar_deconstruccion(celda_pared_22)
	assert(r6_22["lista_para_remocion"])

	var esquina_22: Vector2i = mundo.eliminar_edificio(id_22)
	assert(esquina_22 == Vector2i(OX10, OX10))
	for c_22 in [celda_piso_22, celda_pared_22, celda_cabecera_22, celda_pies_22, celda_baul_22]:
		assert(mundo.obtener_tipo(c_22) == "")
		assert(mundo.id_de_edificio(c_22) == -1)
	print("OK: procesar_deconstruccion() revierte en el mismo orden de construcción recorrido en reversa (mobiliario -> estructura -> piso), cuenta camas solo al cruzar el borde de completo, y eliminar_edificio() borra todo.")

	print("\n=== TEST 23: deconstruir un edificio a medio construir revierte solo hasta donde llegó el progreso ===")
	const OX11 := 950
	var celda_piso_23 := Vector3i(OX11, 0, OX11)
	var celda_pared_real_23 := Vector3i(OX11, 1, OX11)
	var celda_pared_fantasma_23 := Vector3i(OX11 + 1, 1, OX11)
	var orden_23: Array[Vector3i] = [celda_piso_23, celda_pared_real_23, celda_pared_fantasma_23]
	var tipos_23 := {
		celda_piso_23: "piso",
		celda_pared_real_23: "pared",
		celda_pared_fantasma_23: "pared",
	}
	mundo.iniciar_construccion_fantasma([], {}, orden_23, tipos_23)
	mundo.surtir_construccion(celda_piso_23)  # piso real
	mundo.surtir_construccion(celda_piso_23)  # pared real (2da del orden); la 3ra sigue fantasma
	assert(mundo.obtener_tipo(celda_piso_23) == "piso")
	assert(mundo.obtener_tipo(celda_pared_real_23) == "pared")
	assert(mundo.obtener_tipo(celda_pared_fantasma_23) == "fantasma", "Todavía no se surtió")

	var r1_23: Dictionary = mundo.procesar_deconstruccion(celda_pared_real_23)
	assert(mundo.obtener_tipo(celda_pared_real_23) == "fantasma", "La celda real más reciente (progreso - 1) se revierte")
	assert(mundo.obtener_tipo(celda_pared_fantasma_23) == "fantasma", "Ya lo era, sin cambios")
	assert(not r1_23["completa_reversion"])

	var r2_23: Dictionary = mundo.procesar_deconstruccion(celda_pared_real_23)
	assert(mundo.obtener_tipo(celda_piso_23) == "fantasma")
	assert(r2_23["completa_reversion"] and r2_23["lista_para_remocion"])
	print("OK: deconstruir un edificio a medio construir solo revierte celdas que ya eran reales, hasta llegar a progreso 0.")

	print("\n=== TEST 24: iniciar_construccion_fantasma() no registra el relleno como parte del edificio ===")
	const OX12 := 970
	var celda_relleno_24 := Vector3i(OX12, 1, OX12)
	var celda_estructural_24 := Vector3i(OX12 + 1, 1, OX12)
	var tipos_24 := {celda_estructural_24: "pared"}
	mundo.iniciar_construccion_fantasma([celda_relleno_24], {celda_relleno_24: "tierra"}, [celda_estructural_24], tipos_24)
	assert(mundo.id_de_edificio(celda_relleno_24) == -1, "El relleno nunca se registra, aunque esté en 'orden'")
	assert(mundo.id_de_edificio(celda_estructural_24) != -1, "La celda estructural sí se registra")
	var mineo_relleno_24: bool = mundo.minar_bloque(celda_relleno_24)
	assert(mineo_relleno_24, "El relleno, aunque siga siendo fantasma, es minable de inmediato (no es inmune)")
	assert(mundo.obtener_tipo(celda_relleno_24) == "", "Se minó de verdad")
	var mineo_estructural_24: bool = mundo.minar_bloque(celda_estructural_24)
	assert(not mineo_estructural_24, "La celda estructural sigue inmune")
	print("OK: el relleno de nivelación nunca queda registrado como parte del edificio, aunque comparta 'orden' con las celdas estructurales.")

	print("\n=== TEST 24b: surtir_construccion() completa primero el relleno del grupo, sin importar a qué celda del grupo apunte el jugador ===")
	const OX12B := 975
	var celda_relleno_24b := Vector3i(OX12B, 1, OX12B)
	var celda_estructural_24b := Vector3i(OX12B + 1, 1, OX12B)
	mundo.iniciar_construccion_fantasma([celda_relleno_24b], {celda_relleno_24b: "tierra"}, [celda_estructural_24b], {celda_estructural_24b: "pared"})

	# Apunta a la celda ESTRUCTURAL, pero como el relleno del grupo sigue
	# pendiente, debe avanzar el relleno en su lugar -- la estructura no se
	# toca todavía.
	var s1_24b: Dictionary = mundo.surtir_construccion(celda_estructural_24b)
	assert(not s1_24b.get("completa", false), "El relleno nunca dispara 'completa' del grupo")
	assert(mundo.obtener_tipo(celda_relleno_24b) == "tierra", "El relleno se surtió aunque se apuntó a la celda estructural")
	assert(mundo.obtener_tipo(celda_estructural_24b) == "fantasma", "La estructura no avanza mientras quede relleno pendiente")

	# Con el relleno agotado, el mismo click (a cualquier celda del grupo)
	# ahora sí avanza la estructura.
	var s2_24b: Dictionary = mundo.surtir_construccion(celda_estructural_24b)
	assert(s2_24b["completa"], "Con el relleno completo, la estructura se completa normalmente")
	assert(mundo.obtener_tipo(celda_estructural_24b) == "pared", "Se convierte a su tipo real de estructura")
	print("OK: surtir_construccion() surte primero el relleno del grupo completo antes de avanzar la estructura, sin importar a qué celda del grupo se apunte.")

	print("\n=== TEST 25: pausar una construcción, deconstruir parte, y retomarla — el progreso es el mismo índice en ambos sentidos ===")
	const OX13 := 990
	var celda_piso_25 := Vector3i(OX13, 0, OX13)
	var celda_pared_25 := Vector3i(OX13, 1, OX13)
	var celda_baul_25 := Vector3i(OX13 + 1, 1, OX13)
	var orden_25: Array[Vector3i] = [celda_piso_25, celda_pared_25, celda_baul_25]
	var tipos_25 := {
		celda_piso_25: "piso",
		celda_pared_25: "pared",
		celda_baul_25: "baul",
	}
	mundo.iniciar_construccion_fantasma([], {}, orden_25, tipos_25)
	mundo.surtir_construccion(celda_pared_25)  # convierte la PRIMERA celda pendiente del orden (piso), no la pared -- orden fijo
	assert(mundo.obtener_tipo(celda_piso_25) == "piso", "El piso fue el primero en surtirse (orden fijo, no el que se apunta)")
	assert(mundo.obtener_tipo(celda_pared_25) == "fantasma", "La pared todavía no se ha surtido")
	assert(mundo.obtener_tipo(celda_baul_25) == "fantasma", "El baúl todavía no se ha surtido")

	# Deconstruir apuntando a la pared (todavía fantasma) -- revierte la
	# única celda real (el piso, progreso - 1), sin tocar el baúl (nunca
	# llegó a ser real, no participa).
	var r1_25: Dictionary = mundo.procesar_deconstruccion(celda_pared_25)
	assert(mundo.obtener_tipo(celda_piso_25) == "fantasma", "El piso (única celda real) debe revertirse")
	assert(mundo.obtener_tipo(celda_baul_25) == "fantasma", "El baúl sigue sin construirse")
	assert(r1_25["completa_reversion"] and r1_25["lista_para_remocion"], "Con una sola celda real, la reversión se completa de inmediato")

	# Retomar la construcción desde progreso 0: debe volver a surtir el
	# piso primero, exactamente igual que la primera vez -- MISMO índice,
	# ninguna operación especial de "reanudar".
	mundo.surtir_construccion(celda_pared_25)
	mundo.surtir_construccion(celda_pared_25)
	mundo.surtir_construccion(celda_pared_25)
	assert(mundo.obtener_tipo(celda_piso_25) == "piso")
	assert(mundo.obtener_tipo(celda_pared_25) == "pared")
	assert(mundo.obtener_tipo(celda_baul_25) == "baul")
	print("OK: pausar, deconstruir parcialmente y retomar la construcción usa el mismo índice de progreso en ambos sentidos, sin perder ni duplicar celdas.")

	print("\n=== TEST 26: procesar_deconstruccion() sobre un puesto periférico no falla, es un no-op ===")
	const OX14 := 995
	var celda_mina_26 := Vector3i(OX14, 1, OX14)
	mundo.colocar_bloque(celda_mina_26, "mina")
	var id_mina_26: int = mundo.registrar_edificio([celda_mina_26])
	var r_mina_26: Dictionary = mundo.procesar_deconstruccion(celda_mina_26)
	assert(r_mina_26.is_empty(), "Un puesto periférico (tipo no deconstruible) debe ser un no-op silencioso, no un error")
	assert(mundo.obtener_tipo(celda_mina_26) == "mina", "El marcador del puesto no debe alterarse")
	assert(mundo.id_de_edificio(celda_mina_26) == id_mina_26, "El puesto sigue registrado (sigue inmune al minado) tras el intento fallido")
	print("OK: procesar_deconstruccion() sobre un tipo de bloque no deconstruible (p. ej. un puesto periférico) es un no-op, nunca un error.")

	print("\n=== TEST 27: registrar_edificio_completo() deja un edificio declarado a mano tan reversible como uno por blueprint ===")
	const OX15 := 1000
	var celda_piso_27 := Vector3i(OX15, 0, OX15)
	var celda_pared_27 := Vector3i(OX15, 1, OX15)
	var celda_cabecera_27 := Vector3i(OX15 + 1, 1, OX15)
	var celda_pies_27 := Vector3i(OX15 + 2, 1, OX15)
	mundo.colocar_bloque(celda_piso_27, "piso", true)
	mundo.colocar_bloque(celda_pared_27, "pared", true)
	mundo.colocar_bloque(celda_cabecera_27, "cama_cabecera", true)
	mundo.colocar_bloque(celda_pies_27, "cama_pies", true)
	var celdas_mundo_27 := {
		celda_piso_27: "piso",
		celda_pared_27: "pared",
		celda_cabecera_27: "cama_cabecera",
		celda_pies_27: "cama_pies",
	}
	var metadata_27 := {"huella_xz": [Vector2i(OX15, OX15)], "esquina": Vector2i(OX15, OX15), "ancho": 1, "profundidad": 1}
	var _id_27: int = mundo.registrar_edificio_completo(celdas_mundo_27, metadata_27)

	# Deconstruye el mobiliario (2 celdas) y confirma que la huella SIGUE
	# registrada (no hay "construcción fantasma" bloqueando) mientras el
	# progreso no llega a 0.
	mundo.procesar_deconstruccion(celda_pared_27)
	var r_parcial_27: Dictionary = mundo.procesar_deconstruccion(celda_pared_27)
	assert(not r_parcial_27["lista_para_remocion"])
	assert(mundo.id_de_edificio(celda_piso_27) != -1, "La huella sigue registrada a medio deconstruir")

	# Retomar y volver a completar: metadata debe seguir intacta (no se
	# perdió al pasar por registrar_edificio_completo() en vez de
	# iniciar_construccion_fantasma()).
	var _s1_27: Dictionary = mundo.surtir_construccion(celda_pared_27)
	var s2_27: Dictionary = mundo.surtir_construccion(celda_pared_27)
	assert(s2_27["completa"])
	assert(s2_27["metadata"] == metadata_27, "La metadata pasada a registrar_edificio_completo() se conserva")
	print("OK: un edificio declarado a mano (registrar_edificio_completo()) es tan reversible como uno por blueprint, sin perder su metadata.")

	print("\n=== TEST 28: calcular_despeje() de una ventana exige 1 celda hacia el lado externo ===")
	const OX16 := 1010
	# Edificio de 1x1: una única celda "ventana" en (OX16, 1, OX16). Su
	# huella es solo esa columna, así que sus 4 vecinos XZ son TODOS
	# externos -- calcular_despeje() debe reservar las 4, una por cada
	# lado, a la misma altura Y.
	var celda_ventana_28 := Vector3i(OX16, 1, OX16)
	var celdas_mundo_28 := {celda_ventana_28: "ventana"}
	var despeje_28: Array = mundo.calcular_despeje(celdas_mundo_28)
	assert(despeje_28.size() == 4, "Una ventana aislada (huella de 1 celda) tiene sus 4 lados externos")
	for direccion_28 in mundo.VECINOS_ORTOGONALES_XZ:
		var esperado_28 := Vector3i(OX16 + direccion_28.x, 1, OX16 + direccion_28.y)
		assert(despeje_28.has(esperado_28), "Falta la celda de despeje en la dirección " + str(direccion_28))
	print("OK: calcular_despeje() reserva exactamente 1 celda por cada lado externo de una ventana.")

	print("\n=== TEST 29: calcular_despeje() de una puerta exige 2 celdas en AMBOS niveles ===")
	const OX17 := 1020
	# Edificio de 1x1 con una puerta completa (2 celdas verticales) en la
	# misma columna. Igual que TEST 28, huella de 1 celda -> los 4 lados
	# son externos, pero ahora con profundidad 2 en cada nivel Y: 4
	# direcciones x 2 niveles x 2 celdas de profundidad = 16 celdas.
	var celda_puerta_inf_29 := Vector3i(OX17, 1, OX17)
	var celda_puerta_sup_29 := Vector3i(OX17, 2, OX17)
	var celdas_mundo_29 := {
		celda_puerta_inf_29: "puerta_inferior",
		celda_puerta_sup_29: "puerta_superior",
	}
	var despeje_29: Array = mundo.calcular_despeje(celdas_mundo_29)
	assert(despeje_29.size() == 16, "4 direcciones x 2 niveles x 2 celdas de profundidad = 16")
	for direccion_29 in mundo.VECINOS_ORTOGONALES_XZ:
		for nivel_29 in [1, 2]:
			for paso_29 in [1, 2]:
				var esperado_29 := Vector3i(
					OX17 + direccion_29.x * paso_29, nivel_29, OX17 + direccion_29.y * paso_29
				)
				assert(despeje_29.has(esperado_29), "Falta despeje de puerta en nivel " + str(nivel_29))
	print("OK: calcular_despeje() reserva 2 celdas de profundidad por cada lado externo de una puerta, en ambos niveles.")

	print("\n=== TEST 30: verificar_despejes() rechaza si el propio despeje no está vacío ===")
	const OX18 := 1030
	var celda_ventana_30 := Vector3i(OX18, 1, OX18)
	var celdas_mundo_30 := {celda_ventana_30: "ventana"}
	var celda_bloqueo_30 := Vector3i(OX18 + 1, 1, OX18)  # una de las 4 celdas de despeje
	mundo.colocar_bloque(celda_bloqueo_30, "madera")
	assert(not mundo.verificar_despejes(celdas_mundo_30), "El despeje de la ventana está ocupado por un árbol")
	mundo.minar_bloque(celda_bloqueo_30)
	assert(mundo.verificar_despejes(celdas_mundo_30), "Con el despeje vacío, la validación debe pasar")
	print("OK: verificar_despejes() rechaza cuando el propio despeje no está físicamente vacío.")

	print("\n=== TEST 31: verificar_despejes() rechaza si una celda estructural nueva invade el despeje ajeno ===")
	const OX19 := 1040
	var celda_ventana_31 := Vector3i(OX19, 1, OX19)
	var celdas_mundo_31a := {celda_ventana_31: "ventana"}
	mundo.colocar_bloque(celda_ventana_31, "ventana", true)
	mundo.registrar_edificio_completo(celdas_mundo_31a)
	# El despeje de esta ventana incluye Vector3i(OX19 + 1, 1, OX19). Un
	# segundo edificio hipotético con una pared exactamente ahí debe ser
	# rechazado.
	var celda_pared_31 := Vector3i(OX19 + 1, 1, OX19)
	var celdas_mundo_31b := {celda_pared_31: "pared"}
	assert(not mundo.verificar_despejes(celdas_mundo_31b), "Una pared nueva no puede caer en el despeje reservado de otro edificio")
	print("OK: verificar_despejes() rechaza una celda estructural nueva que invade el despeje reservado de otro edificio.")

	print("\n=== TEST 32: los despejes de dos edificios distintos pueden solaparse libremente ===")
	const OX20 := 1050
	# Dos edificios de 1x1 con puertas enfrentadas, separados por 2 celdas
	# vacías en X -- sus despejes (2 celdas de profundidad cada uno) se
	# solapan exactamente en el hueco del medio, pero ninguna celda
	# ESTRUCTURAL de uno cae en el despeje del otro.
	var celda_puerta_a_32 := Vector3i(OX20, 1, OX20)
	var celda_puerta_b_32 := Vector3i(OX20 + 3, 1, OX20)
	mundo.colocar_bloque(celda_puerta_a_32, "puerta_inferior", true)
	mundo.colocar_bloque(celda_puerta_a_32 + Vector3i(0, 1, 0), "puerta_superior", true)
	var celdas_mundo_32a := {
		celda_puerta_a_32: "puerta_inferior",
		celda_puerta_a_32 + Vector3i(0, 1, 0): "puerta_superior",
	}
	mundo.registrar_edificio_completo(celdas_mundo_32a)
	var celdas_mundo_32b := {
		celda_puerta_b_32: "puerta_inferior",
		celda_puerta_b_32 + Vector3i(0, 1, 0): "puerta_superior",
	}
	assert(mundo.verificar_despejes(celdas_mundo_32b), "El segundo edificio debe poder colocarse: su despeje se solapa con el del primero, pero ninguna celda estructural invade al otro")
	mundo.colocar_bloque(celda_puerta_b_32, "puerta_inferior", true)
	mundo.colocar_bloque(celda_puerta_b_32 + Vector3i(0, 1, 0), "puerta_superior", true)
	mundo.registrar_edificio_completo(celdas_mundo_32b)
	print("OK: los despejes de dos edificios distintos pueden solaparse sin rechazo, solo se prohíbe invadir con una celda estructural.")

	print("\n=== TEST 33: eliminar_edificio() libera la reserva de despeje ===")
	const OX21 := 1060
	var celda_ventana_33 := Vector3i(OX21, 1, OX21)
	mundo.colocar_bloque(celda_ventana_33, "ventana", true)
	var celdas_mundo_33 := {celda_ventana_33: "ventana"}
	var id_33: int = mundo.registrar_edificio_completo(celdas_mundo_33)
	var celda_pared_33 := Vector3i(OX21 + 1, 1, OX21)  # cae en el despeje de la ventana
	var celdas_mundo_33b := {celda_pared_33: "pared"}
	assert(not mundo.verificar_despejes(celdas_mundo_33b), "Antes de eliminar, el despeje sigue bloqueando")
	mundo.eliminar_edificio(id_33)
	assert(mundo.verificar_despejes(celdas_mundo_33b), "Tras eliminar el edificio, su despeje debe liberarse de inmediato")
	print("OK: eliminar_edificio() libera por completo la reserva de despeje del edificio eliminado.")

	print("\n=== TEST 34: al deconstruir un edificio, el despeje compartido con un vecino que sigue en pie NO se libera ===")
	const OX22 := 1070
	# Mismo patrón que TEST 32: dos puertas enfrentadas separadas por 2
	# celdas -- sus despejes se solapan exactamente en el hueco del medio.
	var celda_puerta_a_34 := Vector3i(OX22, 1, OX22)
	var celda_puerta_b_34 := Vector3i(OX22 + 3, 1, OX22)
	mundo.colocar_bloque(celda_puerta_a_34, "puerta_inferior", true)
	mundo.colocar_bloque(celda_puerta_a_34 + Vector3i(0, 1, 0), "puerta_superior", true)
	var celdas_mundo_34a := {
		celda_puerta_a_34: "puerta_inferior",
		celda_puerta_a_34 + Vector3i(0, 1, 0): "puerta_superior",
	}
	var id_a_34: int = mundo.registrar_edificio_completo(celdas_mundo_34a)
	mundo.colocar_bloque(celda_puerta_b_34, "puerta_inferior", true)
	mundo.colocar_bloque(celda_puerta_b_34 + Vector3i(0, 1, 0), "puerta_superior", true)
	var celdas_mundo_34b := {
		celda_puerta_b_34: "puerta_inferior",
		celda_puerta_b_34 + Vector3i(0, 1, 0): "puerta_superior",
	}
	var id_b_34: int = mundo.registrar_edificio_completo(celdas_mundo_34b)
	# Celda del hueco compartido: a 1 celda de la puerta A y 2 de la puerta
	# B -- cae dentro del despeje (profundidad 2) de AMBAS.
	var celda_pared_34 := Vector3i(OX22 + 1, 1, OX22)
	var celdas_mundo_34_pared := {celda_pared_34: "pared"}
	assert(not mundo.verificar_despejes(celdas_mundo_34_pared), "Con los dos edificios en pie, la zona compartida sigue reservada")
	mundo.eliminar_edificio(id_a_34)
	assert(not mundo.verificar_despejes(celdas_mundo_34_pared), "Deconstruir el edificio A no debe liberar la reserva que el edificio B (todavía en pie) tiene sobre la misma celda")
	mundo.eliminar_edificio(id_b_34)
	assert(mundo.verificar_despejes(celdas_mundo_34_pared), "Con ambos edificios eliminados, la zona compartida debe quedar libre")
	print("OK: celda_a_despeje conserva la reserva del vecino en pie al deconstruir uno de dos edificios con despeje compartido, y la libera solo cuando ambos desaparecen.")

	print("\n=== TEST 35: minar_bloque() no hace nada sobre una celda de agua ===")
	const OX35 := 1080
	var celda_agua_35 := Vector3i(OX35, 1, OX35)
	mundo.colocar_bloque(celda_agua_35, "agua")
	var resultado_35: bool = mundo.minar_bloque(celda_agua_35)
	assert(not resultado_35, "minar_bloque() debe devolver false sobre una celda de agua")
	assert(mundo.obtener_tipo(celda_agua_35) == "agua", "la celda de agua no debe modificarse")
	print("OK: minar_bloque() no hace nada sobre una celda de agua.")

	print("\n=== TEST 36: colocar_bloque() sobre una celda de agua la sustituye ===")
	const OX36 := 1090
	var celda_agua_36 := Vector3i(OX36, 1, OX36)
	mundo.colocar_bloque(celda_agua_36, "agua")
	var resultado_36: bool = mundo.colocar_bloque(celda_agua_36, "piedra")
	assert(resultado_36, "colocar_bloque() debe poder sustituir una celda de agua")
	assert(mundo.obtener_tipo(celda_agua_36) == "piedra", "la celda debe pasar a tener el tipo nuevo")
	print("OK: colocar_bloque() sustituye una celda de agua por el tipo nuevo.")

	print("\n=== TEST 37: colocar_bloque() sigue rechazando celdas no vacías que no son agua ===")
	const OX37 := 1100
	var celda_piedra_37 := Vector3i(OX37, 1, OX37)
	mundo.colocar_bloque(celda_piedra_37, "piedra")
	var resultado_37: bool = mundo.colocar_bloque(celda_piedra_37, "tierra")
	assert(not resultado_37, "colocar_bloque() no debe sustituir una celda sólida que no sea agua")
	assert(mundo.obtener_tipo(celda_piedra_37) == "piedra", "la celda sólida original no debe cambiar")
	print("OK: colocar_bloque() sigue rechazando celdas sólidas no vacías que no son agua.")

	print("\n=== TEST 38: minar_bloque() bajo un bloque de agua hace que el agua caiga a la celda recién vaciada (escurrimiento vertical) ===")
	const OX38 := 1110
	var piso_38 := Vector3i(OX38, 0, OX38)
	var bloqueo_38 := Vector3i(OX38, 1, OX38)
	var agua_38 := Vector3i(OX38, 2, OX38)
	mundo.colocar_bloque(piso_38, "piedra")
	mundo.colocar_bloque(bloqueo_38, "piedra")
	mundo.colocar_bloque(agua_38, "agua")
	mundo.minar_bloque(bloqueo_38)
	mundo._drenar_escurrimiento_para_pruebas()  # el escurrimiento ahora es gradual (ver _process()) — esto fuerza el resultado final para poder comprobarlo sin simular frames reales
	assert(mundo.obtener_tipo(bloqueo_38) == "agua", "la celda recién vaciada bajo el agua debe llenarse con agua (escurrimiento vertical)")
	assert(mundo.obtener_tipo(agua_38) == "agua", "el agua original no debe desaparecer (sin secado/recesión, ver diseño 2026-09-18)")
	print("OK: minar_bloque() bajo agua hace que el agua caiga a la celda vaciada, sin desaparecer de su origen.")

	print("\n=== TEST 39: minar_bloque() al lado del agua (con piso debajo) llena la celda vaciada con nivel 1, y sigue con nivel 2 en la siguiente celda plana ===")
	const OZ39 := 1120
	var agua_39 := Vector3i(OZ39, 1, OZ39)
	var piso_agua_39 := Vector3i(OZ39, 0, OZ39)
	var bloqueo1_39 := Vector3i(OZ39 + 1, 1, OZ39)
	var piso1_39 := Vector3i(OZ39 + 1, 0, OZ39)
	var piso2_39 := Vector3i(OZ39 + 2, 0, OZ39)
	mundo.colocar_bloque(piso_agua_39, "piedra")
	mundo.colocar_bloque(agua_39, "agua")
	mundo.colocar_bloque(bloqueo1_39, "piedra")
	mundo.colocar_bloque(piso1_39, "piedra")
	mundo.colocar_bloque(piso2_39, "piedra")
	# Cierra los otros lados (mundo abierto de la prueba: cualquier vecino sin
	# piso cuenta como una caída y desviaría el agua hacia allá).
	mundo.colocar_bloque(Vector3i(OZ39 - 1, 1, OZ39), "piedra")
	mundo.colocar_bloque(Vector3i(OZ39, 1, OZ39 + 1), "piedra")
	mundo.colocar_bloque(Vector3i(OZ39, 1, OZ39 - 1), "piedra")
	mundo.colocar_bloque(Vector3i(OZ39 + 1, 1, OZ39 + 1), "piedra")
	mundo.colocar_bloque(Vector3i(OZ39 + 1, 1, OZ39 - 1), "piedra")
	mundo.colocar_bloque(Vector3i(OZ39 + 2, 1, OZ39 + 1), "piedra")
	mundo.colocar_bloque(Vector3i(OZ39 + 2, 1, OZ39 - 1), "piedra")
	mundo.colocar_bloque(Vector3i(OZ39 + 3, 1, OZ39), "piedra")
	mundo.minar_bloque(bloqueo1_39)
	mundo._drenar_escurrimiento_para_pruebas()
	assert(mundo.obtener_tipo(bloqueo1_39) == "agua", "debe esparcirse lateralmente hacia la celda recién vaciada")
	assert(mundo.nivel_agua_en(bloqueo1_39) == 1, "la celda vaciada junto a la fuente es agua de flujo nivel 1")
	assert(mundo.nivel_agua_en(Vector3i(OZ39 + 2, 1, OZ39)) == 2, "la siguiente celda plana es nivel 2 (un semibloque más bajo)")
	print("OK: el agua llena la celda vaciada con nivel 1 y sigue en plano con nivel 2, cada vez más baja.")

	print("\n=== TEST 40: el escurrimiento nunca sobreescribe bedrock ===")
	const OX40 := 1130
	var piso_40 := Vector3i(OX40, 0, OX40)
	var bloqueo_40 := Vector3i(OX40, 1, OX40)
	var agua_40 := Vector3i(OX40, 2, OX40)
	mundo.colocar_bloque(piso_40, "bedrock")
	mundo.colocar_bloque(bloqueo_40, "piedra")
	mundo.colocar_bloque(agua_40, "agua")
	mundo.minar_bloque(bloqueo_40)
	mundo._drenar_escurrimiento_para_pruebas()
	assert(mundo.obtener_tipo(bloqueo_40) == "agua", "debe seguir escurriendo hacia la celda vaciada")
	assert(mundo.obtener_tipo(piso_40) == "bedrock", "el escurrimiento nunca debe sobreescribir bedrock")
	print("OK: el escurrimiento se detiene ante bedrock, sin sobreescribirlo.")

	print("\n=== TEST 41: colocar_bloque(..., \"agua\", true) encola escurrimiento; sin por_jugador (como en _generar_terreno()) no encola nada ===")
	const OX41 := 1140
	var piso_agua_41a := Vector3i(OX41, 0, OX41)
	var vacio_lateral_41a := Vector3i(OX41 + 1, 1, OX41)
	var piso_lateral_41a := Vector3i(OX41 + 1, 0, OX41)
	mundo.colocar_bloque(piso_agua_41a, "piedra")
	mundo.colocar_bloque(piso_lateral_41a, "piedra")
	for cerco_41 in [Vector3i(OX41 - 1, 1, OX41), Vector3i(OX41, 1, OX41 + 1), Vector3i(OX41, 1, OX41 - 1), Vector3i(OX41 + 1, 1, OX41 + 1), Vector3i(OX41 + 1, 1, OX41 - 1), Vector3i(OX41 + 2, 1, OX41)]:
		mundo.colocar_bloque(cerco_41, "piedra")  # evita que vecinos sin piso desvíen el agua (ver TEST 39)
	mundo.colocar_bloque(Vector3i(OX41, 1, OX41), "agua", true)
	mundo._drenar_escurrimiento_para_pruebas()
	assert(mundo.obtener_tipo(vacio_lateral_41a) == "agua", "colocar agua con por_jugador=true debe escurrir hacia el vecino vacío")

	const OX41B := 1150
	var piso_agua_41b := Vector3i(OX41B, 0, OX41B)
	var vacio_lateral_41b := Vector3i(OX41B + 1, 1, OX41B)
	var piso_lateral_41b := Vector3i(OX41B + 1, 0, OX41B)
	mundo.colocar_bloque(piso_agua_41b, "piedra")
	mundo.colocar_bloque(piso_lateral_41b, "piedra")
	mundo.colocar_bloque(Vector3i(OX41B, 1, OX41B), "agua")  # sin por_jugador, como en _generar_terreno()
	assert(mundo.obtener_tipo(vacio_lateral_41b) != "agua", "colocar agua sin por_jugador (generación) NO debe disparar escurrimiento")
	print("OK: colocar_bloque() solo escurre cuando por_jugador=true, evitando disparar esto en cada bloque de agua de _generar_terreno().")

	print("\n=== TEST 42: _escurrir_agua_desde() nunca deja agua \"flotando\" (sin piso debajo) aunque el tope de esparcido se agote justo al llegar a un hueco sin piso ===")
	# Reproduce el bug real (2026-09-18): una celda al lado de la fuente sin
	# piso (un "acantilado"). Con limite=1, el esparcido llega exactamente a
	# la celda del acantilado en la 1ra y última unidad de presupuesto
	# permitida. La vieja
	# implementación (cola FIFO que encolaba la celda recién esparcida y
	# dejaba SU PROPIA caída para un turno futuro) se quedaba sin
	# presupuesto justo ahí, sin llegar nunca a comprobar que esa celda
	# debía seguir cayendo — quedaba agua plantada sobre el vacío. La
	# versión corregida resuelve la caída de cada celda esparcida de
	# inmediato y sin tope propio, así que esto no puede pasar sin importar
	# dónde se agote "limite".
	const OX42 := 1160
	var agua_42 := Vector3i(OX42, 0, OX42)
	mundo.colocar_bloque(agua_42 + Vector3i(0, -1, 0), "piedra")  # piso bajo la fuente
	mundo.colocar_bloque(agua_42, "agua")  # la fuente es agua real (si estuviera vacía, el esparcido se devolvería a ella y gastaría presupuesto)
	# Encierra la fuente por todos los otros lados: solo debe poder avanzar
	# en +X hacia el pasillo — sin esto, el esparcido escapa también hacia
	# atrás/los lados, cae por el "mundo abierto" de la prueba (sin piso
	# ahí, nunca pensado para tenerlo) hasta el límite vertical real
	# (ALTURA_BUSQUEDA_MIN) y esa celda de límite se ve como "flotante" sin
	# serlo realmente (no es el bug, es una fuga del propio montaje de la
	# prueba).
	mundo.colocar_bloque(Vector3i(OX42 - 1, 0, OX42), "piedra")
	mundo.colocar_bloque(Vector3i(OX42, 0, OX42 + 1), "piedra")
	mundo.colocar_bloque(Vector3i(OX42, 0, OX42 - 1), "piedra")
	# muros laterales en Z para que el esparcido solo pueda avanzar en X
	mundo.colocar_bloque(Vector3i(OX42 + 1, 0, OX42 + 1), "piedra")
	mundo.colocar_bloque(Vector3i(OX42 + 1, 0, OX42 - 1), "piedra")
	mundo.colocar_bloque(Vector3i(OX42 + 2, 0, OX42), "piedra")
	# (OX42+1, -1, OX42) queda sin piso a propósito: el "acantilado" — pero
	# sí tiene un fondo real varios niveles más abajo, para que la caída
	# aterrice en piso de verdad y no en el límite vertical de búsqueda del
	# mundo (que no representa ningún piso real, ver _celda_escurrible()).
	mundo.colocar_bloque(Vector3i(OX42 + 1, -6, OX42), "piedra")
	mundo._limite_escurrimiento = 1
	var semillas_42: Array[Vector3i] = [agua_42]
	mundo._escurrir_agua_desde(semillas_42)
	mundo._drenar_escurrimiento_para_pruebas()
	mundo._limite_escurrimiento = VoxelWorld.LIMITE_ESCURRIMIENTO  # no afectar pruebas futuras
	var flotantes_42 := 0
	for x in range(OX42 - 1, OX42 + 8):
		for y in range(-40, 5):
			for z in range(OX42 - 2, OX42 + 3):
				var celda := Vector3i(x, y, z)
				if mundo.obtener_tipo(celda) == "agua":
					var abajo := celda + Vector3i(0, -1, 0)
					if mundo.get_cell_item(abajo) == -1:
						flotantes_42 += 1
	assert(flotantes_42 == 0, "ninguna celda de agua debe quedar flotando (sin piso ni otra agua debajo)")
	assert(mundo.obtener_tipo(Vector3i(OX42 + 1, 0, OX42)) == "agua", "el esparcido debe haber llegado hasta la celda del acantilado")
	print("OK: ninguna celda de agua queda flotando, incluso agotando el tope justo al llegar al hueco sin piso.")

	print("\n=== TEST 43: el agua corre en plano con niveles crecientes (más bajos) y se detiene tras NIVEL_MAXIMO_FLUJO celdas ===")
	# Pasillo plano y largo, con piso y muros laterales en toda su extensión:
	# el agua solo puede avanzar en +X. La celda i celdas a la derecha de la
	# fuente es de nivel i (altura (8 - i) / 8) hasta NIVEL_MAXIMO_FLUJO, y
	# ahí se detiene (pedido del usuario, 2026-09-20).
	const OX43 := 1170
	var maxima_43: int = VoxelWorld.NIVEL_MAXIMO_FLUJO
	mundo.colocar_bloque(Vector3i(OX43, -1, OX43), "piedra")
	mundo.colocar_bloque(Vector3i(OX43, 0, OX43), "agua")
	mundo.colocar_bloque(Vector3i(OX43 - 1, 0, OX43), "piedra")
	mundo.colocar_bloque(Vector3i(OX43, 0, OX43 + 1), "piedra")
	mundo.colocar_bloque(Vector3i(OX43, 0, OX43 - 1), "piedra")
	for i in range(1, maxima_43 + 4):
		mundo.colocar_bloque(Vector3i(OX43 + i, -1, OX43), "piedra")
		mundo.colocar_bloque(Vector3i(OX43 + i, 0, OX43 + 1), "piedra")
		mundo.colocar_bloque(Vector3i(OX43 + i, 0, OX43 - 1), "piedra")
	var semillas_43: Array[Vector3i] = [Vector3i(OX43, 0, OX43)]
	mundo._escurrir_agua_desde(semillas_43)
	mundo._drenar_escurrimiento_para_pruebas()
	assert(mundo.nivel_agua_en(Vector3i(OX43, 0, OX43)) == -1, "la fuente no tiene nivel de flujo")
	assert(is_equal_approx(mundo.altura_agua_en(Vector3i(OX43, 0, OX43)), 1.0), "la fuente se ve llena")
	for i in range(1, maxima_43 + 1):
		var celda_43 := Vector3i(OX43 + i, 0, OX43)
		assert(mundo.obtener_tipo(celda_43) == "agua", "el agua debe llegar hasta NIVEL_MAXIMO_FLUJO celdas de la fuente")
		assert(mundo.nivel_agua_en(celda_43) == i, "la celda %d debe ser de nivel %d" % [i, i])
		assert(is_equal_approx(mundo.altura_agua_en(celda_43), float(8 - i) / 8.0), "la altura baja con el nivel")
	assert(mundo.obtener_tipo(Vector3i(OX43 + maxima_43 + 1, 0, OX43)) != "agua", "el agua NO debe esparcirse más allá de NIVEL_MAXIMO_FLUJO celdas sin caer")
	print("OK: en plano el agua avanza con niveles 1..7 (cada vez más baja) y se detiene.")

	print("\n=== TEST 44: si hay un vecino con caída (vacío debajo), el agua va solo hacia allá y no se esparce en plano ===")
	# Feedback real (2026-09-18): "solo continúe horizontal si no hay bloques
	# más bajos". La fuente tiene un vecino plano (+X, con piso) y un vecino
	# con caída (-X, sin piso, con un fondo real más abajo): el agua debe ir
	# solo hacia -X.
	const OX44 := 1180
	mundo.colocar_bloque(Vector3i(OX44, -1, OX44), "piedra")
	mundo.colocar_bloque(Vector3i(OX44, 0, OX44), "agua")
	mundo.colocar_bloque(Vector3i(OX44 + 1, -1, OX44), "piedra")  # vecino plano (+X), con piso
	mundo.colocar_bloque(Vector3i(OX44, 0, OX44 + 1), "piedra")
	mundo.colocar_bloque(Vector3i(OX44, 0, OX44 - 1), "piedra")
	# vecino con caída (-X): sin piso en y=-1; fondo real en y=-6 (losa 3x3 para
	# que el esparcido del fondo no siga cayendo por el mundo abierto)
	for dx_44 in range(-2, 1):
		for dz_44 in range(-1, 2):
			mundo.colocar_bloque(Vector3i(OX44 - 1 + dx_44 + 1, -6, OX44 + dz_44), "piedra")
	for dz_44 in [-1, 1]:
		mundo.colocar_bloque(Vector3i(OX44 - 1, 0, OX44 + dz_44), "piedra")
	mundo.colocar_bloque(Vector3i(OX44 - 2, 0, OX44), "piedra")
	var semillas_44: Array[Vector3i] = [Vector3i(OX44, 0, OX44)]
	mundo._escurrir_agua_desde(semillas_44)
	mundo._drenar_escurrimiento_para_pruebas()
	assert(mundo.obtener_tipo(Vector3i(OX44 - 1, 0, OX44)) == "agua", "el agua debe ir hacia el vecino con caída")
	assert(mundo.obtener_tipo(Vector3i(OX44 + 1, 0, OX44)) != "agua", "el agua NO debe esparcirse en plano hacia +X cuando hay una caída al otro lado")
	print("OK: con una caída cerca, el agua va solo hacia ella.")

	print("\n=== TEST 45: al quitar la fuente, el flujo se seca en cadena (cada semibloque necesita una fuente conectada) ===")
	const OX45 := 1190
	mundo.colocar_bloque(Vector3i(OX45, -1, OX45), "piedra")
	mundo.colocar_bloque(Vector3i(OX45, 0, OX45), "agua")  # fuente
	mundo.colocar_bloque(Vector3i(OX45 - 1, 0, OX45), "piedra")
	mundo.colocar_bloque(Vector3i(OX45, 0, OX45 + 1), "piedra")
	mundo.colocar_bloque(Vector3i(OX45, 0, OX45 - 1), "piedra")
	for i in range(1, 5):
		mundo.colocar_bloque(Vector3i(OX45 + i, -1, OX45), "piedra")
		mundo.colocar_bloque(Vector3i(OX45 + i, 0, OX45 + 1), "piedra")
		mundo.colocar_bloque(Vector3i(OX45 + i, 0, OX45 - 1), "piedra")
	mundo.colocar_bloque(Vector3i(OX45 + 5, 0, OX45), "piedra")
	var semillas_45: Array[Vector3i] = [Vector3i(OX45, 0, OX45)]
	mundo._escurrir_agua_desde(semillas_45)
	mundo._drenar_escurrimiento_para_pruebas()
	for i in range(1, 5):
		assert(mundo.obtener_tipo(Vector3i(OX45 + i, 0, OX45)) == "agua", "antes de quitar la fuente, el flujo existe")
	# Quitar la fuente: reemplazarla por un bloque (colocar_bloque ya reemplaza agua).
	mundo.colocar_bloque(Vector3i(OX45, 0, OX45), "piedra", true)
	mundo._drenar_escurrimiento_para_pruebas()
	for i in range(1, 5):
		assert(mundo.obtener_tipo(Vector3i(OX45 + i, 0, OX45)) == "", "sin fuente conectada, el semibloque %d debe secarse" % i)
		assert(mundo.nivel_agua_en(Vector3i(OX45 + i, 0, OX45)) == -1, "un semibloque seco no conserva su nivel")
	print("OK: quitar la fuente seca todo el flujo conectado a ella, en cadena.")

	print("\n=== TEST 46: un semibloque con dos fuentes conectadas no se seca al perder solo una ===")
	const OX46 := 1200
	mundo.colocar_bloque(Vector3i(OX46, -1, OX46), "piedra")
	mundo.colocar_bloque(Vector3i(OX46, 0, OX46), "agua")  # fuente A
	mundo.colocar_bloque(Vector3i(OX46 - 1, 0, OX46), "piedra")
	mundo.colocar_bloque(Vector3i(OX46, 0, OX46 + 1), "piedra")
	mundo.colocar_bloque(Vector3i(OX46, 0, OX46 - 1), "piedra")
	for i in range(1, 5):
		mundo.colocar_bloque(Vector3i(OX46 + i, -1, OX46), "piedra")
		mundo.colocar_bloque(Vector3i(OX46 + i, 0, OX46 + 1), "piedra")
		mundo.colocar_bloque(Vector3i(OX46 + i, 0, OX46 - 1), "piedra")
	mundo.colocar_bloque(Vector3i(OX46 + 4, 0, OX46), "agua")  # fuente B, al otro extremo
	mundo.colocar_bloque(Vector3i(OX46 + 5, 0, OX46), "piedra")
	var semillas_46: Array[Vector3i] = [Vector3i(OX46, 0, OX46), Vector3i(OX46 + 4, 0, OX46)]
	mundo._escurrir_agua_desde(semillas_46)
	mundo._drenar_escurrimiento_para_pruebas()
	for i in range(1, 4):
		assert(mundo.obtener_tipo(Vector3i(OX46 + i, 0, OX46)) == "agua", "las 3 celdas intermedias se llenan")
	mundo.colocar_bloque(Vector3i(OX46, 0, OX46), "piedra", true)  # quita la fuente A
	mundo._drenar_escurrimiento_para_pruebas()
	assert(mundo.obtener_tipo(Vector3i(OX46 + 1, 0, OX46)) == "", "la celda pegada a la fuente A quitada se seca (su único alimentador era A)")
	assert(mundo.obtener_tipo(Vector3i(OX46 + 2, 0, OX46)) == "agua", "la celda 2 sigue alimentada por el flujo que viene de la fuente B")
	assert(mundo.obtener_tipo(Vector3i(OX46 + 3, 0, OX46)) == "agua", "la celda 3, pegada a la fuente B, sigue existiendo")
	print("OK: con dos fuentes, quitar una seca solo lo que dependía exclusivamente de ella.")

	print("\n=== TEST 47: una columna de agua que cae se seca al quitar la fuente de arriba ===")
	const OX47 := 1210
	for dx_47 in range(-8, 9):
		for dz_47 in range(-8, 9):
			mundo.colocar_bloque(Vector3i(OX47 + dx_47, 0, OX47 + dz_47), "piedra")  # losa de piso
	mundo.colocar_bloque(Vector3i(OX47, 5, OX47), "agua")  # fuente en el aire, 4 celdas sobre el piso
	mundo._limite_escurrimiento = 12
	var semillas_47: Array[Vector3i] = [Vector3i(OX47, 5, OX47)]
	mundo._escurrir_agua_desde(semillas_47)
	mundo._drenar_escurrimiento_para_pruebas()
	assert(mundo.nivel_agua_en(Vector3i(OX47, 3, OX47)) == 0, "la columna cae: nivel de caída (0), se ve llena")
	assert(mundo.obtener_tipo(Vector3i(OX47, 1, OX47)) == "agua", "la columna llega hasta el piso")
	mundo.colocar_bloque(Vector3i(OX47, 5, OX47), "piedra", true)  # quita la fuente
	mundo._drenar_escurrimiento_para_pruebas()
	mundo._limite_escurrimiento = VoxelWorld.LIMITE_ESCURRIMIENTO
	var restante_47 := 0
	for x_47 in range(OX47 - 8, OX47 + 9):
		for y_47 in range(-40, 8):
			for z_47 in range(OX47 - 8, OX47 + 9):
				if mundo.obtener_tipo(Vector3i(x_47, y_47, z_47)) == "agua":
					restante_47 += 1
	assert(restante_47 == 0, "sin la fuente de arriba, la columna y todo el flujo que esta alimentaba deben secarse (quedan %d celdas de agua)" % restante_47)
	print("OK: al quitar la fuente, la columna que cae y su esparcido al aterrizar se secan por completo.")

	print("\n=== TEST 48: la cola de preparación cava terreno real (aire/fantasma) antes de rellenar, y la losa enterrada queda como fantasma ===")
	const OX48 := 1300
	var celda_cavar_48 := Vector3i(OX48, 1, OX48)        # terreno suelto, no es parte del edificio
	var celda_losa_48 := Vector3i(OX48 + 1, 1, OX48)     # terreno que la losa del edificio va a ocupar
	var celda_relleno_48 := Vector3i(OX48 + 2, 1, OX48)  # hueco por rellenar
	mundo.colocar_bloque(celda_cavar_48, "tierra")
	mundo.colocar_bloque(celda_losa_48, "piedra")
	var orden_prep_48: Array[Vector3i] = [celda_cavar_48, celda_losa_48, celda_relleno_48]
	var tipos_prep_48 := {celda_cavar_48: "aire", celda_losa_48: "fantasma", celda_relleno_48: "tierra"}
	mundo.iniciar_construccion_fantasma(orden_prep_48, tipos_prep_48, [celda_losa_48], {celda_losa_48: "pared"})
	assert(mundo.obtener_tipo(celda_cavar_48) == "tierra", "el terreno a cavar sigue intacto al emplazar")
	assert(mundo.obtener_tipo(celda_losa_48) == "piedra")
	assert(mundo.obtener_tipo(celda_relleno_48) == "fantasma")
	assert(not mundo.minar_bloque(celda_losa_48), "la celda de la estructura es inmune al minado normal")

	# Apunta al terreno suelto (no es del edificio): avanza la cola y lo cava.
	var s1_48: Dictionary = mundo.surtir_construccion(celda_cavar_48)
	assert(mundo.obtener_tipo(celda_cavar_48) == "", "la celda 'aire' queda vacía")
	assert(mundo.obtener_tipo(celda_losa_48) == "piedra")
	assert(not s1_48.get("completa", false))

	# Apunta a la estructura: el grupo avanza su cola de preparación primero -> la losa
	# se retira y queda fantasma (la estructura aún no avanza).
	mundo.surtir_construccion(celda_losa_48)
	assert(mundo.obtener_tipo(celda_losa_48) == "fantasma", "la celda 'fantasma' retira el terreno y deja el fantasma")
	assert(mundo.obtener_tipo(celda_relleno_48) == "fantasma", "el relleno espera a que termine la excavación")

	# Ahora el relleno, y por último la estructura.
	var s3_48: Dictionary = mundo.surtir_construccion(celda_losa_48)
	assert(mundo.obtener_tipo(celda_relleno_48) == "tierra")
	assert(not s3_48.get("completa", false))
	var s4_48: Dictionary = mundo.surtir_construccion(celda_losa_48)
	assert(mundo.obtener_tipo(celda_losa_48) == "pared")
	assert(s4_48["completa"])
	print("OK: la cola cava (aire/fantasma) antes de rellenar y solo entonces avanza la estructura.")

	print("\n=== TEST 48b: excavar una celda 'aire' bajo agua deja caer el agua a la celda cavada (mismo retiro que minar_bloque) ===")
	const OX48B := 1350
	var piso_48b := Vector3i(OX48B, 0, OX48B)
	var celda_cavar_48b := Vector3i(OX48B, 1, OX48B)
	var agua_48b := Vector3i(OX48B, 2, OX48B)
	var celda_estructura_48b := Vector3i(OX48B + 5, 1, OX48B)
	mundo.colocar_bloque(piso_48b, "piedra")
	mundo.colocar_bloque(celda_cavar_48b, "piedra")
	mundo.colocar_bloque(agua_48b, "agua")
	var orden_prep_48b: Array[Vector3i] = [celda_cavar_48b]
	mundo.iniciar_construccion_fantasma(orden_prep_48b, {celda_cavar_48b: "aire"}, [celda_estructura_48b], {celda_estructura_48b: "pared"})
	mundo.surtir_construccion(celda_cavar_48b)
	mundo._drenar_escurrimiento_para_pruebas()
	assert(mundo.obtener_tipo(celda_cavar_48b) == "agua", "la celda cavada bajo el agua debe llenarse (escurrimiento al retirar el bloque)")
	assert(mundo.obtener_tipo(agua_48b) == "agua", "el agua original no debe desaparecer")
	print("OK: la excavación 'aire' avisa al agua vecina igual que minar_bloque().")

	print("\n=== TEST 48c: eliminar_edificio() descarta la excavación pendiente y retira el relleno fantasma pendiente de su cola ===")
	const OX48C := 1400
	var celda_cavar_48c := Vector3i(OX48C, 1, OX48C)        # terreno real que se iba a cavar
	var celda_estructura_48c := Vector3i(OX48C + 1, 1, OX48C)
	var celda_relleno_48c := Vector3i(OX48C + 2, 1, OX48C)  # hueco por rellenar
	mundo.colocar_bloque(celda_cavar_48c, "tierra")
	var orden_prep_48c: Array[Vector3i] = [celda_cavar_48c, celda_relleno_48c]
	var id_48c: int = mundo.iniciar_construccion_fantasma(orden_prep_48c, {celda_cavar_48c: "aire", celda_relleno_48c: "tierra"}, [celda_estructura_48c], {celda_estructura_48c: "pared"})
	var r_48c: Dictionary = mundo.procesar_deconstruccion(celda_estructura_48c)
	assert(r_48c["lista_para_remocion"], "un edificio a progreso 0 ya está listo para remoción")
	mundo.eliminar_edificio(id_48c)
	assert(mundo.surtir_construccion(celda_cavar_48c).is_empty(), "la excavación pendiente de un edificio eliminado ya no se aplica")
	assert(mundo.obtener_tipo(celda_cavar_48c) == "tierra", "el terreno real no se cava")
	assert(mundo.obtener_tipo(celda_relleno_48c) == "", "el fantasma del relleno pendiente se retira junto con el edificio")
	assert(mundo.surtir_construccion(celda_relleno_48c).is_empty(), "y ya no hay nada que surtir ahí")
	print("OK: eliminar_edificio() cancela lo pendiente de la cola: la excavación no se aplica y el fantasma del relleno desaparece.")

	print("\n=== TEST 48d: eliminar_edificio() conserva el relleno YA hecho y lo ya excavado, y retira solo el relleno fantasma pendiente ===")
	const OX48D := 1420
	var celda_cavar_48d := Vector3i(OX48D, 1, OX48D)
	var celda_estructura_48d := Vector3i(OX48D + 1, 1, OX48D)
	var celda_relleno_hecho_48d := Vector3i(OX48D + 2, 1, OX48D)
	var celda_relleno_pendiente_48d := Vector3i(OX48D + 3, 1, OX48D)
	mundo.colocar_bloque(celda_cavar_48d, "tierra")
	var orden_prep_48d: Array[Vector3i] = [celda_cavar_48d, celda_relleno_hecho_48d, celda_relleno_pendiente_48d]
	var tipos_prep_48d := {celda_cavar_48d: "aire", celda_relleno_hecho_48d: "tierra", celda_relleno_pendiente_48d: "tierra"}
	var id_48d: int = mundo.iniciar_construccion_fantasma(orden_prep_48d, tipos_prep_48d, [celda_estructura_48d], {celda_estructura_48d: "pared"})
	mundo.surtir_construccion(celda_estructura_48d)  # cava
	mundo.surtir_construccion(celda_estructura_48d)  # rellena el primero
	assert(mundo.obtener_tipo(celda_relleno_hecho_48d) == "tierra")
	assert(mundo.obtener_tipo(celda_relleno_pendiente_48d) == "fantasma")
	assert(mundo.procesar_deconstruccion(celda_estructura_48d)["lista_para_remocion"])
	mundo.eliminar_edificio(id_48d)
	assert(mundo.obtener_tipo(celda_relleno_hecho_48d) == "tierra", "el relleno ya hecho es terreno real y se conserva")
	assert(mundo.obtener_tipo(celda_cavar_48d) == "", "lo ya excavado no se restaura")
	assert(mundo.obtener_tipo(celda_relleno_pendiente_48d) == "", "el fantasma pendiente desaparece")
	print("OK: solo el relleno fantasma pendiente se retira; el terreno ya modificado se conserva.")

	print("\n=== TEST 48e: eliminar_edificio() no toca el terreno real que la estructura aún no había cavado ===")
	const OX48E := 1440
	var celda_terreno_48e := Vector3i(OX48E, 1, OX48E)  # terreno real bajo una celda de la estructura (p. ej. la losa enterrada), aún sin cavar
	var celda_pared_48e := Vector3i(OX48E + 1, 1, OX48E)  # celda de la estructura sobre aire: fantasma
	mundo.colocar_bloque(celda_terreno_48e, "piedra")
	var tipos_48e := {celda_terreno_48e: "pared", celda_pared_48e: "pared"}
	var id_48e: int = mundo.iniciar_construccion_fantasma([celda_terreno_48e], {celda_terreno_48e: "fantasma"}, [celda_terreno_48e, celda_pared_48e], tipos_48e)
	assert(mundo.obtener_tipo(celda_terreno_48e) == "piedra", "al emplazar no se modifica el terreno")
	assert(mundo.obtener_tipo(celda_pared_48e) == "fantasma")
	assert(mundo.procesar_deconstruccion(celda_pared_48e)["lista_para_remocion"])
	mundo.eliminar_edificio(id_48e)
	assert(mundo.obtener_tipo(celda_terreno_48e) == "piedra", "el terreno que nunca se cavó no se borra")
	assert(mundo.obtener_tipo(celda_pared_48e) == "", "el fantasma sí se retira")
	assert(mundo.id_de_edificio(celda_terreno_48e) == -1, "y la celda de terreno deja de figurar como parte del edificio")
	assert(mundo.minar_bloque(celda_terreno_48e), "vuelve a ser minable como cualquier terreno")
	print("OK: quitar un edificio recién emplazado no abre huecos en el terreno.")

	print("\n=== TEST 49: celdas_fantasma_destacadas() marca solo puertas y ventanas todavía fantasma, y se actualiza al surtir y deconstruir ===")
	# Mundo PROPIO para las pruebas 49-50: celdas_fantasma_destacadas() recorre TODOS los
	# edificios del mundo, y las pruebas anteriores dejan en `mundo` edificios con
	# puertas/ventanas pendientes que falsearían los conteos.
	var mundo_d: Node = VoxelWorld.new()
	mundo_d.mesh_library = load("res://assets/BlockLibrary.res")
	mundo_d.cell_size = Vector3.ONE * 1.0
	mundo_d._indexar_biblioteca()
	const OX49 := 1450
	var pared_49 := Vector3i(OX49, 1, OX49)
	var puerta_inf_49 := Vector3i(OX49 + 1, 1, OX49)
	var puerta_sup_49 := Vector3i(OX49 + 1, 2, OX49)
	var ventana_49 := Vector3i(OX49 + 2, 1, OX49)
	var baul_49 := Vector3i(OX49 + 3, 1, OX49)
	var tipos_49 := {
		pared_49: "pared", puerta_inf_49: "puerta_inferior", puerta_sup_49: "puerta_superior",
		ventana_49: "ventana", baul_49: "baul",
	}
	var orden_49: Array = mundo_d.ordenar_celdas_edificio(tipos_49)
	var id_49: int = mundo_d.iniciar_construccion_fantasma([], {}, orden_49, tipos_49)
	var d_49: Dictionary = mundo_d.celdas_fantasma_destacadas()
	assert(d_49.size() == 3, "solo puerta (2 mitades) y ventana; ni pared ni baúl")
	assert(d_49[puerta_inf_49] == "puerta_inferior")
	assert(d_49[puerta_sup_49] == "puerta_superior")
	assert(d_49[ventana_49] == "ventana")
	assert(not d_49.has(pared_49) and not d_49.has(baul_49))

	# Surtir en el orden fijo [pared, puerta_inf, ventana, puerta_sup, baúl]: cada
	# celda destacada sale del resultado cuando deja de ser fantasma.
	mundo_d.surtir_construccion(pared_49)
	assert(mundo_d.celdas_fantasma_destacadas().size() == 3, "la pared no es destacada")
	mundo_d.surtir_construccion(pared_49)  # puerta_inferior
	assert(not mundo_d.celdas_fantasma_destacadas().has(puerta_inf_49))
	assert(mundo_d.celdas_fantasma_destacadas().size() == 2)
	mundo_d.surtir_construccion(pared_49)  # ventana
	assert(mundo_d.celdas_fantasma_destacadas().size() == 1)
	mundo_d.surtir_construccion(pared_49)  # puerta_superior
	mundo_d.surtir_construccion(pared_49)  # baúl (completa)
	assert(mundo_d.celdas_fantasma_destacadas().is_empty(), "edificio completo: nada pendiente")

	# Deconstruir revierte primero el baúl y luego la puerta superior: esa vuelve a destacarse.
	mundo_d.procesar_deconstruccion(pared_49)  # baúl
	assert(mundo_d.celdas_fantasma_destacadas().is_empty())
	mundo_d.procesar_deconstruccion(pared_49)  # puerta_superior
	var d_decon_49: Dictionary = mundo_d.celdas_fantasma_destacadas()
	assert(d_decon_49.size() == 1 and d_decon_49.has(puerta_sup_49))
	mundo_d.procesar_deconstruccion(pared_49)  # ventana
	mundo_d.procesar_deconstruccion(pared_49)  # puerta_inferior
	mundo_d.procesar_deconstruccion(pared_49)  # pared -> progreso 0
	assert(mundo_d.celdas_fantasma_destacadas().size() == 3)
	mundo_d.eliminar_edificio(id_49)
	assert(mundo_d.celdas_fantasma_destacadas().is_empty(), "un edificio eliminado no deja marcadores")
	print("OK: solo puertas/ventanas pendientes se destacan, y el resultado sigue al surtir, deconstruir y eliminar.")

	print("\n=== TEST 49b: una puerta enterrada bajo terreno sin cavar no se destaca hasta que la cola de excavación la deja como fantasma ===")
	const OX49B := 1460
	var celda_enterrada_49b := Vector3i(OX49B, 1, OX49B)
	mundo_d.colocar_bloque(celda_enterrada_49b, "tierra")
	mundo_d.iniciar_construccion_fantasma(
		[celda_enterrada_49b], {celda_enterrada_49b: "fantasma"},
		[celda_enterrada_49b], {celda_enterrada_49b: "puerta_inferior"}
	)
	assert(mundo_d.obtener_tipo(celda_enterrada_49b) == "tierra")
	assert(mundo_d.celdas_fantasma_destacadas().is_empty(), "todavía es terreno real, no un fantasma")
	mundo_d.surtir_construccion(celda_enterrada_49b)  # cava y deja fantasma
	assert(mundo_d.celdas_fantasma_destacadas().has(celda_enterrada_49b))
	print("OK: la puerta enterrada se destaca recién cuando se cava.")

	print("\n=== TEST 50: fantasmas_cambiados se emite al iniciar, surtir (relleno y estructura), deconstruir y eliminar ===")
	const OX50 := 1470
	var pared_50 := Vector3i(OX50, 1, OX50)
	var ventana_50 := Vector3i(OX50 + 1, 1, OX50)
	var relleno_50 := Vector3i(OX50 + 2, 1, OX50)
	var tipos_50 := {pared_50: "pared", ventana_50: "ventana"}
	var cuenta_50: Array = [0]
	mundo_d.fantasmas_cambiados.connect(func() -> void: cuenta_50[0] += 1)
	var id_50: int = mundo_d.iniciar_construccion_fantasma([relleno_50], {relleno_50: "tierra"}, mundo_d.ordenar_celdas_edificio(tipos_50), tipos_50)
	assert(cuenta_50[0] == 1, "iniciar")
	mundo_d.surtir_construccion(pared_50)  # relleno
	assert(cuenta_50[0] == 2, "surtir: paso de relleno")
	mundo_d.surtir_construccion(pared_50)  # pared
	assert(cuenta_50[0] == 3, "surtir: paso de estructura")
	mundo_d.surtir_construccion(pared_50)  # ventana (completa)
	assert(cuenta_50[0] == 4)
	mundo_d.procesar_deconstruccion(pared_50)  # revierte ventana
	assert(cuenta_50[0] == 5, "deconstruir")
	mundo_d.procesar_deconstruccion(pared_50)  # revierte pared -> progreso 0
	assert(cuenta_50[0] == 6)
	mundo_d.procesar_deconstruccion(pared_50)  # progreso 0: no revierte nada
	assert(cuenta_50[0] == 6, "sin celda revertida no hay emisión")
	mundo_d.eliminar_edificio(id_50)
	assert(cuenta_50[0] == 7, "eliminar")
	print("OK: la señal se emite en cada punto que puede cambiar los marcadores.")

	print("\n=== TEST 50b: al deconstruir, un receptor síncrono de fantasmas_cambiados ya ve la puerta recién revertida ===")
	const OX50B := 1480
	var pared_50b := Vector3i(OX50B, 1, OX50B)
	var puerta_inf_50b := Vector3i(OX50B + 1, 1, OX50B)
	var puerta_sup_50b := Vector3i(OX50B + 1, 2, OX50B)
	var tipos_50b := {pared_50b: "pared", puerta_inf_50b: "puerta_inferior", puerta_sup_50b: "puerta_superior"}
	var orden_50b: Array = mundo_d.ordenar_celdas_edificio(tipos_50b)
	assert(orden_50b.back() == puerta_sup_50b, "la puerta superior es la última celda: se revierte primero")
	var id_50b: int = mundo_d.iniciar_construccion_fantasma([], {}, orden_50b, tipos_50b)
	for _i in orden_50b.size():
		mundo_d.surtir_construccion(pared_50b)
	# (mundo_d conserva la puerta enterrada de la prueba 49b: no se cuenta el tamaño total.)
	assert(not mundo_d.celdas_fantasma_destacadas().has(puerta_sup_50b), "edificio completo: nada pendiente")
	# El receptor guarda la foto DENTRO de la señal (Array: la lambda captura por referencia).
	var foto_50b: Array = [{}]
	mundo_d.fantasmas_cambiados.connect(func() -> void: foto_50b[0] = mundo_d.celdas_fantasma_destacadas())
	foto_50b[0] = {}
	mundo_d.procesar_deconstruccion(pared_50b)  # revierte puerta_superior
	assert(foto_50b[0].has(puerta_sup_50b), "el receptor síncrono ya ve la puerta recién revertida")
	assert(not foto_50b[0].has(puerta_inf_50b), "solo la celda revertida se destaca")
	mundo_d.eliminar_edificio(id_50b)
	print("OK: la señal de deconstrucción se emite con el progreso ya actualizado.")

	print("\n=== TEST 51: verificar_despejes() acepta terreno natural sobre el nivel en una columna a nivelar, y sigue rechazando árbol, estructura y terreno fuera de la fachada ===")
	const OX51 := 1500
	var celdas_51 := {
		Vector3i(OX51, 1, OX51): "puerta_inferior",
		Vector3i(OX51, 2, OX51): "puerta_superior",
	}
	var despeje_51: Array = mundo_d.calcular_despeje(celdas_51)
	assert(despeje_51.size() == 16, "4 direcciones x 2 pasos x 2 niveles")
	for celda_51 in despeje_51:
		mundo_d.colocar_bloque(celda_51, "tierra")
	var niveles_51: Dictionary = {}
	for celda_51 in despeje_51:
		niveles_51[Vector2i(celda_51.x, celda_51.z)] = 0
	assert(not mundo_d.verificar_despejes(celdas_51), "sin nivelación, el terreno en el despeje rechaza (comportamiento anterior)")
	assert(mundo_d.verificar_despejes(celdas_51, niveles_51), "terreno natural sobre el nivel de una columna a nivelar no bloquea")

	var celda_prueba_51: Vector3i = despeje_51[0]
	var columna_prueba_51 := Vector2i(celda_prueba_51.x, celda_prueba_51.z)
	mundo_d.set_cell_item(celda_prueba_51, GridMap.INVALID_CELL_ITEM)
	mundo_d.colocar_bloque(celda_prueba_51, "madera")
	assert(not mundo_d.verificar_despejes(celdas_51, niveles_51), "un árbol sigue bloqueando")
	mundo_d.set_cell_item(celda_prueba_51, GridMap.INVALID_CELL_ITEM)
	mundo_d.colocar_bloque(celda_prueba_51, "pared")
	assert(not mundo_d.verificar_despejes(celdas_51, niveles_51), "una estructura sigue bloqueando")
	mundo_d.set_cell_item(celda_prueba_51, GridMap.INVALID_CELL_ITEM)
	mundo_d.colocar_bloque(celda_prueba_51, "tierra")
	assert(mundo_d.verificar_despejes(celdas_51, niveles_51), "restaurado el terreno, vuelve a aceptarse")

	var niveles_sin_51: Dictionary = niveles_51.duplicate()
	niveles_sin_51.erase(columna_prueba_51)
	assert(not mundo_d.verificar_despejes(celdas_51, niveles_sin_51), "terreno en una columna que no se nivela sigue bloqueando")
	var niveles_altos_51: Dictionary = niveles_51.duplicate()
	niveles_altos_51[columna_prueba_51] = celda_prueba_51.y
	assert(mundo_d.despeje_bloqueado(celda_prueba_51, niveles_altos_51), "una celda que no está POR ENCIMA del nivel sigue bloqueando")
	assert(not mundo_d.despeje_bloqueado(celda_prueba_51, niveles_51))
	print("OK: el terreno natural sobre el nivel no bloquea; árbol, estructura y columnas fuera de la fachada sí.")

	print("\n=== TEST 52: es_terreno_natural() distingue terreno de árbol, estructura, fantasma, agua, vacío y edificio ===")
	const OX52 := 1510
	var c_tierra_52 := Vector3i(OX52, 1, OX52)
	mundo_d.colocar_bloque(c_tierra_52, "tierra")
	assert(mundo_d.es_terreno_natural(c_tierra_52))
	assert(not mundo_d.es_terreno_natural(Vector3i(OX52 + 1, 1, OX52)), "celda vacía")
	for tipo_52 in ["madera", "follaje", "pared", "fantasma", "agua"]:
		var celda_52 := Vector3i(OX52 + 2, 1, OX52)
		mundo_d.set_cell_item(celda_52, GridMap.INVALID_CELL_ITEM)
		mundo_d.colocar_bloque(celda_52, tipo_52)
		assert(not mundo_d.es_terreno_natural(celda_52), "no es terreno natural: " + tipo_52)
	mundo_d.registrar_edificio([c_tierra_52])
	assert(not mundo_d.es_terreno_natural(c_tierra_52), "una celda que pertenece a un edificio no es terreno")
	print("OK: solo el suelo/subsuelo libre cuenta como terreno natural.")

	# `arboles` lo crea VoxelWorld._ready(), que no corre en estos mundos de prueba;
	# eliminar_follaje() lo necesita para desregistrar el follaje de su árbol.
	mundo_d.arboles = load("res://scripts/GeneradorArbol.gd").new()

	print("\n=== TEST 53: emplazar no sobrescribe el agua; su celda se vuelve tierra (con limpieza de niveles) solo cuando le toca su paso ===")
	const OX53 := 1600
	var celda_agua_53 := Vector3i(OX53, 1, OX53)          # relleno sobre agua
	var celda_vacia_53 := Vector3i(OX53 + 1, 1, OX53)     # relleno sobre aire
	var celda_estructura_53 := Vector3i(OX53 + 2, 1, OX53)
	mundo_d.colocar_bloque(celda_agua_53, "agua")
	mundo_d._nivel_agua[celda_agua_53] = 3  # simula agua de flujo: colocar_bloque() debe limpiar esta entrada
	var orden_53: Array[Vector3i] = [celda_agua_53, celda_vacia_53]
	mundo_d.iniciar_construccion_fantasma(orden_53, {celda_agua_53: "tierra", celda_vacia_53: "tierra"}, [celda_estructura_53], {celda_estructura_53: "pared"})
	assert(mundo_d.obtener_tipo(celda_agua_53) == "agua", "al emplazar el agua no se drena ni se reemplaza por un fantasma")
	assert(mundo_d.obtener_tipo(celda_vacia_53) == "fantasma", "la celda vacía sí recibe su fantasma")
	var ocupadas_53: Array[Vector3i] = mundo_d.celdas_fantasma_ocupadas()
	assert(ocupadas_53.size() == 1 and ocupadas_53[0] == celda_agua_53, "la celda de agua pendiente se reporta como ocupada")
	mundo_d.surtir_construccion(celda_estructura_53)  # primer paso de la cola: la celda de agua
	assert(mundo_d.obtener_tipo(celda_agua_53) == "tierra", "al llegar su turno, el agua se vuelve tierra sólida")
	assert(not mundo_d._nivel_agua.has(celda_agua_53), "y su entrada de nivel de agua se limpia")
	assert(mundo_d.celdas_fantasma_ocupadas().is_empty())
	print("OK: el agua espera su turno y se drena en el mismo instante en que su celda se vuelve sólida.")

	print("\n=== TEST 54: el follaje registrado desaparece por columna con el primer paso de esa columna, no antes ===")
	const OX54 := 1610
	var relleno_a_54 := Vector3i(OX54, 1, OX54)             # columna A: celda de relleno (vacía -> fantasma)
	var follaje_a_54 := Vector3i(OX54, 2, OX54)             # columna A: follaje sobre el relleno, sin ser celda del edificio
	var estructura_b_54 := Vector3i(OX54 + 1, 1, OX54)      # columna B: celda de estructura ocupada por follaje
	mundo_d.colocar_bloque(follaje_a_54, "follaje")
	mundo_d.colocar_bloque(estructura_b_54, "follaje")
	var orden_54: Array[Vector3i] = [relleno_a_54]
	var id_54: int = mundo_d.iniciar_construccion_fantasma(orden_54, {relleno_a_54: "tierra"}, [estructura_b_54], {estructura_b_54: "pared"})
	mundo_d.registrar_follaje_pendiente(id_54, [follaje_a_54, estructura_b_54])
	assert(mundo_d.obtener_tipo(follaje_a_54) == "follaje" and mundo_d.obtener_tipo(estructura_b_54) == "follaje", "al emplazar el follaje sigue en pie")
	assert(mundo_d.obtener_tipo(relleno_a_54) == "fantasma")
	var ocupadas_54: Array[Vector3i] = mundo_d.celdas_fantasma_ocupadas()
	assert(ocupadas_54.size() == 1 and ocupadas_54[0] == estructura_b_54, "solo la celda de estructura ocupada (el follaje suelto no es del edificio)")
	mundo_d.surtir_construccion(estructura_b_54)  # paso de la columna A (relleno)
	assert(mundo_d.obtener_tipo(relleno_a_54) == "tierra")
	assert(mundo_d.obtener_tipo(follaje_a_54) == "", "el follaje de la columna A desaparece con su primer paso")
	assert(mundo_d.obtener_tipo(estructura_b_54) == "follaje", "el de la columna B espera: su columna aún no tuvo ningún paso")
	var resultado_54: Dictionary = mundo_d.surtir_construccion(estructura_b_54)  # paso de estructura, columna B
	assert(mundo_d.obtener_tipo(estructura_b_54) == "pared", "la celda de estructura pasa de follaje a pared sólida")
	assert(resultado_54["completa"])
	print("OK: el follaje se retira por columna con su primer paso, y la celda de estructura liberada queda sólida.")

	print("\n=== TEST 55: quitar el edificio antes de tiempo deja el follaje registrado sin tocar ===")
	const OX55 := 1620
	var follaje_55 := Vector3i(OX55, 1, OX55)
	var estructura_55 := Vector3i(OX55 + 1, 1, OX55)
	mundo_d.colocar_bloque(follaje_55, "follaje")
	var id_55: int = mundo_d.iniciar_construccion_fantasma([], {}, [estructura_55], {estructura_55: "pared"})
	mundo_d.registrar_follaje_pendiente(id_55, [follaje_55])
	assert(mundo_d.procesar_deconstruccion(estructura_55)["lista_para_remocion"])
	mundo_d.eliminar_edificio(id_55)
	assert(mundo_d.obtener_tipo(follaje_55) == "follaje", "el follaje nunca se tocó")
	mundo_d._despejar_follaje_de_columna(Vector2i(OX55, OX55))
	assert(mundo_d.obtener_tipo(follaje_55) == "follaje", "y ya no hay un registro que lo retire")
	print("OK: eliminar el edificio antes de tiempo no modifica el follaje.")

	print("\n=== TEST 62: validar_limites_vivienda() aplica el límite de pisos y de camas por piso ===")
	var limites_n1 := {"camas_por_piso": 2, "pisos": 2}
	var casa_ok := {
		"zona_permitida": "residencial_investigacion",
		"pisos": [
			{"nivel": 0, "camas": [{}, {}]},
			{"nivel": 1, "camas": [{}, {}]},
		],
	}
	assert(BlueprintValidator.validar_limites_vivienda(casa_ok, limites_n1).is_empty(), "2 pisos x 2 camas cabe en el nivel 1")
	var casa_alta := {
		"zona_permitida": "residencial_investigacion",
		"pisos": [
			{"nivel": 0, "camas": [{}]},
			{"nivel": 1, "camas": [{}]},
			{"nivel": 2, "camas": [{}]},
		],
	}
	var errores_alta: Array = BlueprintValidator.validar_limites_vivienda(casa_alta, limites_n1)
	assert(errores_alta.size() == 1, "3 pisos excede los 2 del nivel 1")
	var casa_barracon := {
		"zona_permitida": "residencial_investigacion",
		"pisos": [{"nivel": 0, "camas": [{}, {}, {}, {}, {}]}],
	}
	var errores_barracon: Array = BlueprintValidator.validar_limites_vivienda(casa_barracon, limites_n1)
	assert(errores_barracon.size() == 1, "5 camas en un piso excede las 2 del nivel 1")
	print("OK: ", errores_alta[0], " | ", errores_barracon[0])

	print("\n=== TEST 63: los límites solo aplican a la zona residencial y validar_blueprint() los acepta como parámetro opcional ===")
	var industrial := {
		"zona_permitida": "fabricacion_militar",
		"pisos": [{"nivel": 0, "camas": []}, {"nivel": 1, "camas": []}, {"nivel": 2, "camas": []}],
	}
	assert(BlueprintValidator.validar_limites_vivienda(industrial, limites_n1).is_empty(), "una fábrica no tiene límite de pisos habitables")
	var bp_limites: Dictionary = JSON.parse_string(BLUEPRINT_VALIDO_JSON)
	assert(BlueprintValidator.validar_blueprint(bp_limites)["valido"], "sin el parámetro opcional, el blueprint válido sigue válido")
	var limites_cero := {"camas_por_piso": 0, "pisos": 0}
	var res_limites: Dictionary = BlueprintValidator.validar_blueprint(bp_limites, "", {}, {}, limites_cero)
	assert(not res_limites["valido"], "con límites imposibles el blueprint válido queda rechazado")

	print("\n=== TEST 64: contar_baules() suma los baúles de todos los pisos ===")
	var bp_baules := {"pisos": [
		{"celdas": {Vector3i(0, 0, 0): "baul", Vector3i(1, 0, 0): "pared", Vector3i(2, 0, 0): "baul"}},
		{"celdas": {Vector3i(0, 0, 0): "baul"}},
	]}
	assert(BlueprintValidator.contar_baules(bp_baules) == 3)
	assert(BlueprintValidator.contar_baules({"pisos": []}) == 0)

	print("\n=== Las 64 pruebas de BlueprintValidator pasaron correctamente ===")

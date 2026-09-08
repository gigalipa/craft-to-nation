extends Node

const BlueprintValidator = preload("res://scripts/BlueprintValidator.gd")  # TEMP: ver nota de verificación tras mover el proyecto a godot/
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
## ver VoxelWorld.TIPOS_ESTRUCTURA). Correr esta escena (Test.tscn) con F6 en
## el editor de Godot y revisar el panel "Output": debe imprimir los 14 tests
## y no debe lanzar ningún error de assert().

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

	print("\n=== Las 14 pruebas de BlueprintValidator pasaron correctamente ===")

extends Node

## Equivalente GDScript de ejecutar_pruebas() en PoC_2 (tests 1-6), más
## pruebas propias de PoC 3 para "declarar edificio" (7-8, ver
## VoxelWorld.detectar_estructura()) y para los objetos multi-celda puerta/
## cama (9, ver VoxelWorld.colocar_puerta()/colocar_cama()). Correr esta
## escena (Test.tscn) con F6 en el editor de Godot y revisar el panel
## "Output": debe imprimir los 9 tests y no debe lanzar ningún error de
## assert().

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
	# Planta 7x3 (x:0-6, z:0-2): puerta principal en x=0, puerta interior en
	# x=3 (el caso que motivó este diseño: ¿el flood-fill reconoce ambos
	# lados aunque la puerta interior esté cerrada? Sí, porque avanza por
	# bloques sólidos contiguos, no por espacio transitable), una cama de
	# 2 celdas (x=1,2) y un baúl (x=5) en la habitación este — habitaciones
	# distintas, sin emparejamiento por posición, para demostrar la regla de
	# conteo total. Puertas y cama se colocan con colocar_puerta()/
	# colocar_cama(), no con colocar_bloque() directo, para ejercitar la
	# verificación de espacio de 2 celdas.
	var mundo: Node = $VoxelWorld
	var tipos_simples := {
		Vector3i(0, 0, 0): "pared", Vector3i(1, 0, 0): "pared", Vector3i(2, 0, 0): "pared",
		Vector3i(3, 0, 0): "pared", Vector3i(4, 0, 0): "pared", Vector3i(5, 0, 0): "pared",
		Vector3i(6, 0, 0): "pared",
		Vector3i(4, 0, 1): "piso", Vector3i(5, 0, 1): "baul", Vector3i(6, 0, 1): "ventana",
		Vector3i(0, 0, 2): "pared", Vector3i(1, 0, 2): "pared", Vector3i(2, 0, 2): "pared",
		Vector3i(3, 0, 2): "pared", Vector3i(4, 0, 2): "pared", Vector3i(5, 0, 2): "pared",
		Vector3i(6, 0, 2): "pared",
	}
	for celda in tipos_simples.keys():
		mundo.colocar_bloque(celda, tipos_simples[celda], true)
	assert(mundo.colocar_puerta(Vector3i(0, 0, 1)))  # puerta principal
	assert(mundo.colocar_puerta(Vector3i(3, 0, 1)))  # puerta interior
	assert(mundo.colocar_cama(Vector3i(1, 0, 1), Vector3i(1, 0, 0)))  # cabecera (1,1), pies (2,1)

	var puerta_principal := Vector3i(0, 0, 1)
	var estructura: Dictionary = mundo.detectar_estructura(puerta_principal)
	# 17 celdas simples + 2x2 celdas físicas de las puertas (base+mitad
	# superior) + 2 celdas de la cama = 23 celdas físicas detectadas.
	print("Celdas físicas detectadas: ", estructura.size(), " (esperadas: 23)")
	assert(estructura.size() == 23)

	var blueprint_detectado := BlueprintValidator.estructura_a_blueprint(estructura)
	# Al convertir, cada "puerta_superior" se omite (ver comentario en
	# estructura_a_blueprint) — quedan 21 celdas abstractas: las 17 simples +
	# 1 por puerta (la mitad inferior, remapeada a "puerta") + 2 de la cama.
	print("Celdas del Blueprint: ", blueprint_detectado["pisos"][0]["celdas"].size(), " (esperadas: 21)")
	assert(blueprint_detectado["pisos"][0]["celdas"].size() == 21)
	assert(blueprint_detectado["pisos"][0]["camas"].size() == 1)

	resultado = BlueprintValidator.validar_blueprint(blueprint_detectado)
	print("Válido: ", resultado["valido"], " | Errores: ", resultado["errores"])
	# Estructura completa y válida de punta a punta: cerramiento, esquinas,
	# puertas/ventanas, cama detectada Y un baúl en el edificio (aunque en
	# una habitación distinta, sin emparejamiento por posición) alcanzan
	# para pasar validar_camas_y_almacenamiento().
	assert(resultado["valido"])
	assert(resultado["errores"].is_empty())

	print("\n=== TEST 8: Declarar Edificio - Rechaza Piso de Tierra ===")
	# El piso generado por VoxelWorld._generar_piso_inicial() (y=-1) nunca se
	# marca como colocado_por_jugador, así que no puede declararse edificio.
	var celda_terreno := Vector3i(0, -1, 0)
	assert(mundo.obtener_tipo(celda_terreno) == "piso")
	assert(mundo.detectar_estructura(celda_terreno).is_empty())
	print("Correcto: el piso de tierra no es detectado como estructura.")

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

	print("\n=== Las 9 pruebas de BlueprintValidator pasaron correctamente ===")

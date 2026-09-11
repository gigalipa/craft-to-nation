extends Node

## Pruebas aisladas de Zonificacion.gd (mismo patrón que CiudadTest.gd).
## Corre esta escena (ZonificacionTest.tscn) con F6 en el editor de Godot y
## revisa el panel "Output": debe imprimir las 11 pruebas y no debe lanzar
## ningún error de assert(). No usa el autoload "Zonificacion" — instancia
## una Zonificacion nueva vía preload, para poder correr las pruebas de
## forma aislada y repetible (igual que CiudadTest.gd con Ciudad).

const ZonificacionScript = preload("res://scripts/Zonificacion.gd")


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	print("=== TEST 1: Sin núcleo declarado, todo fuera de influencia ===")
	var zona: Node = ZonificacionScript.new()
	assert(not zona.dentro_de_influencia(Vector2i(0, 0)))
	assert(zona.pintar_zona(Vector2i(-5, -5), Vector2i(5, 5), "residencial_investigacion") == 0)

	print("\n=== TEST 2: declarar_nucleo() con huella no cuadrada (10x7) ===")
	var huella: Array = []
	for x in range(0, 10):
		for z in range(0, 7):
			huella.append(Vector2i(x, z))
	zona.declarar_nucleo(huella)
	assert(zona.nucleo_declarado)
	print("Influencia: ", zona.influencia_min, " a ", zona.influencia_max)
	assert(zona.influencia_min == Vector2i(-15, -15))
	assert(zona.influencia_max == Vector2i(24, 21))
	assert(zona.consultar_zona(Vector2i(0, 0)) == "residencial_investigacion")
	assert(zona.consultar_zona(Vector2i(9, 6)) == "residencial_investigacion")

	print("\n=== TEST 3: dentro_de_influencia() en el borde del margen ===")
	assert(zona.dentro_de_influencia(Vector2i(-15, -15)))
	assert(zona.dentro_de_influencia(Vector2i(24, 21)))
	assert(not zona.dentro_de_influencia(Vector2i(-16, -15)))
	assert(not zona.dentro_de_influencia(Vector2i(25, 21)))

	print("\n=== TEST 4: pintar_zona() con ambas esquinas dentro ===")
	var pintadas: int = zona.pintar_zona(Vector2i(-10, -10), Vector2i(-5, -5), "fabricacion_militar")
	print("Celdas pintadas: ", pintadas)
	assert(pintadas == 36)
	assert(zona.consultar_zona(Vector2i(-10, -10)) == "fabricacion_militar")
	assert(zona.consultar_zona(Vector2i(-5, -5)) == "fabricacion_militar")
	assert(zona.consultar_zona(Vector2i(-7, -7)) == "fabricacion_militar")

	print("\n=== TEST 5: pintar_zona() recortado a la influencia ===")
	var pintadas_recorte: int = zona.pintar_zona(Vector2i(20, 15), Vector2i(30, 25), "residencial_investigacion")
	print("Celdas pintadas (rectángulo parcialmente fuera): ", pintadas_recorte)
	assert(pintadas_recorte == 35)  # x: 20..24 (5) * z: 15..21 (7)

	print("\n=== TEST 6: pintar_zona() con tipo inválido ===")
	assert(zona.pintar_zona(Vector2i(0, 0), Vector2i(1, 1), "periferia") == 0)
	assert(zona.pintar_zona(Vector2i(0, 0), Vector2i(1, 1), "zona_inexistente") == 0)

	print("\n=== TEST 7: consultar_zona() de celda nunca pintada ===")
	assert(zona.consultar_zona(Vector2i(100, 100)) == "periferia")

	print("\n=== TEST 8: declarar_nucleo() llamado dos veces ===")
	var influencia_min_original: Vector2i = zona.influencia_min
	var huella_2: Array = [Vector2i(50, 50)]
	zona.declarar_nucleo(huella_2)
	assert(zona.influencia_min == influencia_min_original)
	assert(zona.consultar_zona(Vector2i(50, 50)) == "periferia")

	print("\n=== TEST 9: ampliar_influencia() con margen según categoría ===")
	var zona_sin_nucleo: Node = ZonificacionScript.new()
	zona_sin_nucleo.ampliar_influencia(1, [Vector2i(100, 100)], "militar")
	assert(not zona_sin_nucleo.nucleo_declarado, "ampliar_influencia() no debe declarar un núcleo por sí sola")
	assert(zona_sin_nucleo.influencia_min == Vector2i.ZERO and zona_sin_nucleo.influencia_max == Vector2i.ZERO, "Sin núcleo declarado, ampliar_influencia() no debe hacer nada")

	var influencia_min_antes: Vector2i = zona.influencia_min
	var influencia_max_antes: Vector2i = zona.influencia_max

	# Edificio residencial (margen 6) lejos del núcleo.
	zona.ampliar_influencia(101, [Vector2i(100, 100)], "residencial")
	print("Influencia tras ampliar con un residencial: ", zona.influencia_min, " a ", zona.influencia_max)
	assert(zona.influencia_min == influencia_min_antes, "Solo debe crecer el máximo, no mover el mínimo")
	assert(zona.influencia_max == Vector2i(106, 106), "Margen residencial (6): 100+6=106")

	# Edificio militar (margen 12), más lejos todavía — debe crecer más que el residencial.
	zona.ampliar_influencia(102, [Vector2i(200, 200)], "militar")
	print("Influencia tras ampliar con un militar: ", zona.influencia_min, " a ", zona.influencia_max)
	assert(zona.influencia_max == Vector2i(212, 212), "Margen militar (12): 200+12=212")

	# Categoría desconocida cae al margen de respaldo (6, igual que residencial).
	zona.ampliar_influencia(103, [Vector2i(300, 300)], "categoria_inexistente")
	assert(zona.influencia_max == Vector2i(306, 306), "Categoría desconocida usa MARGEN_CATEGORIA_DEFECTO")

	print("\n=== TEST 10: retirar_contribucion() reduce la zona correctamente ===")
	zona.retirar_contribucion(103)
	assert(zona.influencia_max == Vector2i(212, 212), "Al quitar la contribución más lejana, vuelve a lo que aporta el militar")
	zona.retirar_contribucion(102)
	assert(zona.influencia_max == Vector2i(106, 106), "Al quitar también el militar, vuelve a lo que aporta el residencial")
	zona.retirar_contribucion(101)
	assert(zona.influencia_max == influencia_max_antes, "Sin ninguna contribución, vuelve exactamente a la del núcleo")
	zona.retirar_contribucion(999)  # no existía, no debe fallar
	assert(zona.influencia_max == influencia_max_antes, "Retirar un id inexistente no debe hacer nada")
	print("OK: cada edificio amplía la zona según su propio margen por categoría, y retirar_contribucion() la reduce correctamente.")

	print("\n=== TEST 11: despintar_zona() borra solo lo que estaba pintado ===")
	# Reutiliza el bloque de TEST 4 (fabricacion_militar, -10,-10 a -5,-5, 36 celdas).
	var borradas: int = zona.despintar_zona(Vector2i(-10, -10), Vector2i(-7, -10))
	print("Celdas borradas: ", borradas)
	assert(borradas == 4)  # x: -10..-7 (4) * z: -10 (1)
	assert(zona.consultar_zona(Vector2i(-10, -10)) == "periferia")
	assert(zona.consultar_zona(Vector2i(-7, -10)) == "periferia")
	assert(zona.consultar_zona(Vector2i(-5, -5)) == "fabricacion_militar", "El resto del bloque sigue pintado")

	var borradas_vacio: int = zona.despintar_zona(Vector2i(1000, 1000), Vector2i(1001, 1001))
	assert(borradas_vacio == 0, "Borrar donde no había nada pintado no cuenta celdas")
	print("OK: despintar_zona() borra solo las celdas que tenían una zona pintada, deja el resto intacto.")

	print("\n=== Las 11 pruebas de Zonificacion pasaron correctamente ===")

extends Node

## Pruebas aisladas de Zonificacion.gd (mismo patrón que CiudadTest.gd).
## Corre esta escena (ZonificacionTest.tscn) con F6 en el editor de Godot y
## revisa el panel "Output": debe imprimir las 8 pruebas y no debe lanzar
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

	print("\n=== Las 8 pruebas de Zonificacion pasaron correctamente ===")

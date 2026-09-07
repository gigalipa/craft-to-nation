extends Node

## Puerto directo de ejecutar_pruebas() de PoC_1 (Python) a GDScript. Corre
## esta escena (CiudadTest.tscn) con F6 en el editor de Godot y revisa el
## panel "Output": debe imprimir los 7 tests y no debe lanzar ningún error
## de assert(). No usa el autoload "Ciudad" (que ya vive en el árbol de
## escena con su propio Timer) — instancia una Ciudad nueva vía preload,
## igual que PoC_1 hace `urbe = Ciudad()`, para poder correr las pruebas de
## forma aislada y repetible.

const CiudadScript = preload("res://scripts/Ciudad.gd")


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	var urbe: Node = CiudadScript.new()
	var jugador: RefCounted = CiudadScript.Avatar.new(urbe)

	print("=== TEST 1: Estado Inicial (Supervivencia Nivel 1) ===")
	urbe.instalaciones["tipo_1"] = 2
	urbe.demografia["trabajador_tipo_1"] = 2
	urbe.demografia["jovenes"] = 1
	print("Nivel Potencial: ", urbe.nivel_potencial, " | Nivel Efectivo: ", urbe.nivel)
	print("Hambre del Avatar: ", jugador.tasa_hambre, "/tick")
	var res: Dictionary = urbe.simular_tick(jugador.tasa_hambre)
	print("Gasto Comida: ", res["gasto_comida"], " | Stock Restante: ", urbe.almacen["comida"].cantidad, "\n")
	# Verificación de tasa_neta/recurso_critico (para el HUD, ver PoC_4/):
	# la comida es el único recurso con consumo real en este tick, así que
	# debe tener la tasa más negativa y ser el recurso crítico.
	print("Tasa neta de comida: ", urbe.almacen["comida"].tasa_neta, " | Recurso crítico: ", urbe.recurso_critico())
	assert(urbe.almacen["comida"].tasa_neta < 0)
	assert(urbe.recurso_critico() == "comida")
	assert(urbe.almacen["madera"].tasa_neta == 0.0)
	assert(urbe.almacen["hierro"].tasa_neta == 0.0)

	print("=== TEST 2: Ratio Permite Nivel 3, pero Investigación Bloquea el Nivel Efectivo ===")
	urbe.instalaciones["tipo_3"] = 7  # con tipo_1=2 y tipo_2=1 ya presentes, esto lleva el índice a 2.5
	urbe.instalaciones["tipo_2"] = 1
	urbe.demografia["investigador"] = 0  # sin investigadores asignados, la investigación no avanza
	res = urbe.simular_tick(jugador.tasa_hambre)
	print("Nivel Potencial: ", res["nivel_potencial"], " | Nivel Efectivo: ", res["nivel_ciudad"], " (debe seguir en 1 sin investigadores)")
	assert(res["nivel_ciudad"] == 1)

	print("\n=== TEST 3: Investigación Completa 'Metalurgia Aplicada' con Investigadores Asignados ===")
	urbe.demografia["investigador"] = 5
	urbe.almacen["hierro"].cantidad = 1000
	urbe.almacen["madera"].cantidad = 1000
	for i in range(10):  # 5 investigadores * 10 ticks = 50 horas-investigador > umbral de Nivel 2 (20) y Nivel 3 (50)
		urbe.simular_tick(jugador.tasa_hambre)
	print("Nivel Investigado: ", urbe.nivel_investigado, " | Nivel Efectivo: ", urbe.nivel)
	assert(urbe.nivel_investigado >= 2)

	print("\n=== TEST 4: Variedad de Fuentes Alimentarias y Bono de Moral Gradual ===")
	for categoria in urbe.CATEGORIAS_COMIDA:
		urbe.fuentes_comida_activas[categoria] = 10.0  # las 6 categorías activas
	for i in range(30):  # suficientes ticks para converger cerca del bono máximo
		urbe.simular_tick(jugador.tasa_hambre)
	var bono_con_variedad: float = urbe.bono_moral_variedad
	print("Bono de moral tras activar las 6 categorías (30 ticks): ", bono_con_variedad)
	urbe.fuentes_comida_activas["sintetico"] = 0.0  # se desactiva una categoría
	urbe.simular_tick(jugador.tasa_hambre)
	print("Bono inmediatamente tras desactivar una categoría: ", urbe.bono_moral_variedad, " (debe decaer gradualmente, no a 0)")
	assert(urbe.bono_moral_variedad > 0 and urbe.bono_moral_variedad < bono_con_variedad)

	print("\n=== TEST 5: Asedio Militar y Degradación por Destrucción ===")
	print(">> El enemigo destruye todas las plantas Tipo 3...")
	urbe.instalaciones["tipo_3"] = 0
	urbe.demografia["trabajador_tipo_1"] = 6
	res = urbe.simular_tick(jugador.tasa_hambre)
	print("Nivel Potencial Tras Ataque: ", res["nivel_potencial"], " | Nivel Efectivo: ", res["nivel_ciudad"])
	print("Ciudadanos Desahuciados: ", urbe.desahuciados)
	print("Censo Restante en Viviendas Legales: ", urbe.censo_total)

	print("\n=== TEST 6: Sucesión del Avatar ===")
	urbe.demografia["militar"] = 2
	var resultado: String = urbe.suceder_avatar()
	print("Resultado de sucesión con militares disponibles: ", resultado)
	assert(resultado == "sucesion_exitosa")
	assert(urbe.periodo_elecciones_restante == 5)

	urbe.demografia["militar"] = 0
	var resultado_sin_sucesor: String = urbe.suceder_avatar()
	print("Resultado de sucesión sin militares disponibles: ", resultado_sin_sucesor)
	assert(resultado_sin_sucesor == "sin_sucesor_elegible")

	print("\n=== TEST 7: Registro de Edificios Residenciales Declarados ===")
	# Ver Player.gd::_declarar_edificio: al declarar un edificio válido, suma
	# las camas de todos sus pisos a Ciudad.capacidad_camas_construida.
	assert(urbe.capacidad_camas_construida == 0)
	urbe.registrar_edificio_residencial(2)
	urbe.registrar_edificio_residencial(3)
	print("Capacidad de camas construida tras declarar 2 edificios: ", urbe.capacidad_camas_construida)
	assert(urbe.capacidad_camas_construida == 5)

	print("\n=== Las 7 pruebas de Ciudad pasaron correctamente ===")

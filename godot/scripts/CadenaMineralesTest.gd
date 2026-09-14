extends Node

## Pruebas aisladas de CadenaMinerales.gd (mismo patrón que
## RecoleccionTest.gd/NiveladorTerrenoTest.gd). Corre esta escena
## (CadenaMineralesTest.tscn) con F6 en el editor de Godot y revisa el
## panel "Output": debe imprimir las pruebas y no debe lanzar ningún error
## de assert().


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	print("=== TEST 1: procesar_tick() con ambas recetas a la vez, insumo suficiente ===")
	var almacen_1 := {"hierro": 100.0, "tierras_raras": 100.0}
	var trabajadores_1 := {"hierro": 1, "tierras_raras": 1}
	var resultado_1: Dictionary = CadenaMinerales.procesar_tick(1.0, almacen_1, trabajadores_1)
	# hierro: consumo = 2 * 1 * 2.0 * 1.0 = 4.0 -> 2 lotes -> 2.0 acero
	assert(is_equal_approx(resultado_1["hierro"], 96.0))
	assert(is_equal_approx(resultado_1["acero"], 2.0))
	# tierras_raras: consumo = 3 * 1 * 2.0 * 1.0 = 6.0 -> 2 lotes -> 2.0 mineral_refinado
	assert(is_equal_approx(resultado_1["tierras_raras"], 94.0))
	assert(is_equal_approx(resultado_1["mineral_refinado"], 2.0))
	print("OK: ambas recetas se procesan en el mismo tick sin interferir entre sí.")

	print("\n=== TEST 2: procesar_tick() sin trabajadores no cambia el almacén ===")
	var almacen_2 := {"hierro": 50.0, "tierras_raras": 50.0}
	var resultado_2: Dictionary = CadenaMinerales.procesar_tick(1.0, almacen_2, {})
	assert(is_equal_approx(resultado_2["hierro"], 50.0))
	assert(is_equal_approx(resultado_2["tierras_raras"], 50.0))
	assert(not resultado_2.has("acero"))
	assert(not resultado_2.has("mineral_refinado"))
	print("OK: sin trabajadores asignados, ninguna receta se ejecuta.")

	print("\n=== TEST 3: procesar_tick() con insumo insuficiente consume solo lo disponible ===")
	var almacen_3 := {"hierro": 3.0}
	var trabajadores_3 := {"hierro": 1}
	# demanda teórica = 2 * 1 * 2.0 * 1.0 = 4.0, pero solo hay 3.0 disponibles
	var resultado_3: Dictionary = CadenaMinerales.procesar_tick(1.0, almacen_3, trabajadores_3)
	assert(is_equal_approx(resultado_3["hierro"], 0.0))
	# 3.0 consumidos / 2 por lote = 1.5 lotes -> 1.5 acero (no 2.0, la producción "completa")
	assert(is_equal_approx(resultado_3["acero"], 1.5))
	print("OK: el consumo se limita a lo disponible, y la producción refleja exactamente lo consumido.")

	print("\n=== TEST 4: procesar_tick() no muta el Dictionary 'almacen' recibido ===")
	var almacen_4 := {"hierro": 20.0}
	var copia_4 := almacen_4.duplicate()
	CadenaMinerales.procesar_tick(1.0, almacen_4, {"hierro": 1})
	assert(almacen_4 == copia_4)
	print("OK: 'almacen' queda exactamente igual después de la llamada — procesar_tick() devuelve un Dictionary nuevo.")

	print("\n=== TEST 5: procesar_tick() copia sin cambios un tipo sin receta (p. ej. cobre) ===")
	var almacen_5 := {"cobre": 42.0, "hierro": 10.0}
	var resultado_5: Dictionary = CadenaMinerales.procesar_tick(1.0, almacen_5, {"hierro": 1})
	assert(is_equal_approx(resultado_5["cobre"], 42.0))
	print("OK: un mineral sin receta (cobre) pasa sin cambios al resultado.")

	print("\n=== TEST 6: tasas_refinado() con ambas recetas activas ===")
	var tasas_6: Dictionary = CadenaMinerales.tasas_refinado({"hierro": 2, "tierras_raras": 1})
	# hierro: consumo = 2 * 2 * 2.0 = 8.0/h -> produccion = (8.0/2)*1 = 4.0/h
	assert(is_equal_approx(tasas_6["hierro"]["consumo"], 8.0))
	assert(is_equal_approx(tasas_6["hierro"]["produccion"], 4.0))
	assert(tasas_6["hierro"]["tipo_salida"] == "acero")
	# tierras_raras: consumo = 3 * 1 * 2.0 = 6.0/h -> produccion = (6.0/3)*1 = 2.0/h
	assert(is_equal_approx(tasas_6["tierras_raras"]["consumo"], 6.0))
	assert(is_equal_approx(tasas_6["tierras_raras"]["produccion"], 2.0))
	print("OK: tasas_refinado() calcula el consumo/producción por hora exactos para cada receta activa.")

	print("\n=== TEST 7: tasas_refinado() omite (no pone en 0.0) una receta sin trabajadores ===")
	var tasas_7: Dictionary = CadenaMinerales.tasas_refinado({"hierro": 1})
	assert(tasas_7.has("hierro"))
	assert(not tasas_7.has("tierras_raras"))
	print("OK: una receta sin trabajadores asignados no aparece como clave en el resultado.")

	print("\n=== TEST 8: determinismo — mismos argumentos dan siempre el mismo resultado ===")
	var almacen_8 := {"hierro": 77.0, "tierras_raras": 33.0}
	var trabajadores_8 := {"hierro": 2, "tierras_raras": 1}
	var resultado_8a: Dictionary = CadenaMinerales.procesar_tick(0.5, almacen_8, trabajadores_8)
	var resultado_8b: Dictionary = CadenaMinerales.procesar_tick(0.5, almacen_8, trabajadores_8)
	assert(resultado_8a == resultado_8b)
	var tasas_8a: Dictionary = CadenaMinerales.tasas_refinado(trabajadores_8)
	var tasas_8b: Dictionary = CadenaMinerales.tasas_refinado(trabajadores_8)
	assert(tasas_8a == tasas_8b)
	print("OK: procesar_tick()/tasas_refinado() son deterministas para los mismos argumentos.")

	print("\n=== Las 8 pruebas de CadenaMinerales pasaron correctamente ===")

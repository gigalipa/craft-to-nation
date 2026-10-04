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
	var almacen_1 := {"hierro": 100.0, "carbon": 100.0, "tierras_raras": 100.0}
	var trabajadores_1 := {"hierro": 1, "tierras_raras": 1}
	var resultado_1: Dictionary = CadenaMinerales.procesar_tick(1.0, almacen_1, trabajadores_1)
	# siderúrgica: 1 * 2.0 * 1.0 = 2 lotes -> consume 6 hierro y 8 carbón, produce 4 acero
	assert(is_equal_approx(resultado_1["hierro"], 94.0))
	assert(is_equal_approx(resultado_1["carbon"], 92.0))
	assert(is_equal_approx(resultado_1["acero"], 4.0))
	# tierras_raras: 1 * 0.5 * 1.0 = 0.5 lote -> consume 1.5, produce 0.5 mineral_refinado
	assert(is_equal_approx(resultado_1["tierras_raras"], 98.5))
	assert(is_equal_approx(resultado_1["mineral_refinado"], 0.5))
	print("OK: ambas recetas se procesan en el mismo tick sin interferir entre sí.")

	print("\n=== TEST 2: procesar_tick() sin trabajadores no cambia el almacén ===")
	var almacen_2 := {"hierro": 50.0, "carbon": 50.0, "tierras_raras": 50.0}
	var resultado_2: Dictionary = CadenaMinerales.procesar_tick(1.0, almacen_2, {})
	assert(is_equal_approx(resultado_2["hierro"], 50.0))
	assert(is_equal_approx(resultado_2["tierras_raras"], 50.0))
	assert(not resultado_2.has("acero"))
	assert(not resultado_2.has("mineral_refinado"))
	print("OK: sin trabajadores asignados, ninguna receta se ejecuta.")

	print("\n=== TEST 3: procesar_tick() con insumo insuficiente consume solo lo disponible ===")
	var almacen_3 := {"hierro": 100.0, "carbon": 2.0}
	var trabajadores_3 := {"hierro": 1}
	# demanda teórica = 2 lotes, pero 2.0 de carbón alcanzan para 0.5 lote (4 por lote)
	var resultado_3: Dictionary = CadenaMinerales.procesar_tick(1.0, almacen_3, trabajadores_3)
	assert(is_equal_approx(resultado_3["carbon"], 0.0))
	assert(is_equal_approx(resultado_3["hierro"], 98.5), "el hierro solo baja lo que pide el carbón disponible")
	assert(is_equal_approx(resultado_3["acero"], 1.0), "0.5 lote -> 1 acero")
	var sin_carbon: Dictionary = CadenaMinerales.procesar_tick(1.0, {"hierro": 50.0}, {"hierro": 1})
	assert(is_equal_approx(sin_carbon["hierro"], 50.0) and is_equal_approx(sin_carbon["acero"], 0.0), "sin carbón no se refina")
	print("OK: el consumo se limita a lo disponible, y la producción refleja exactamente lo consumido.")

	print("\n=== TEST 4: procesar_tick() no muta el Dictionary 'almacen' recibido ===")
	var almacen_4 := {"hierro": 20.0, "carbon": 20.0}
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
	# siderúrgica con 2 técnicos: 4 lotes/h -> 12 hierro + 16 carbón/h -> 8 acero/h
	assert(is_equal_approx(tasas_6["hierro"]["consumo"]["hierro"], 12.0))
	assert(is_equal_approx(tasas_6["hierro"]["consumo"]["carbon"], 16.0))
	assert(is_equal_approx(tasas_6["hierro"]["produccion"], 8.0))
	assert(tasas_6["hierro"]["tipo_salida"] == "acero")
	# tierras_raras: 0.5 lote/h -> 1.5/h -> produccion 0.5/h
	assert(is_equal_approx(tasas_6["tierras_raras"]["consumo"]["tierras_raras"], 1.5))
	assert(is_equal_approx(tasas_6["tierras_raras"]["produccion"], 0.5))
	print("OK: tasas_refinado() calcula el consumo/producción por hora exactos para cada receta activa.")

	print("\n=== TEST 7: tasas_refinado() omite (no pone en 0.0) una receta sin trabajadores ===")
	var tasas_7: Dictionary = CadenaMinerales.tasas_refinado({"hierro": 1})
	assert(tasas_7.has("hierro"))
	assert(not tasas_7.has("tierras_raras"))
	print("OK: una receta sin trabajadores asignados no aparece como clave en el resultado.")

	print("\n=== TEST 8: determinismo — mismos argumentos dan siempre el mismo resultado ===")
	var almacen_8 := {"hierro": 77.0, "carbon": 50.0, "tierras_raras": 33.0}
	var trabajadores_8 := {"hierro": 2, "tierras_raras": 1}
	var resultado_8a: Dictionary = CadenaMinerales.procesar_tick(0.5, almacen_8, trabajadores_8)
	var resultado_8b: Dictionary = CadenaMinerales.procesar_tick(0.5, almacen_8, trabajadores_8)
	assert(resultado_8a == resultado_8b)
	var tasas_8a: Dictionary = CadenaMinerales.tasas_refinado(trabajadores_8)
	var tasas_8b: Dictionary = CadenaMinerales.tasas_refinado(trabajadores_8)
	assert(tasas_8a == tasas_8b)
	print("OK: procesar_tick()/tasas_refinado() son deterministas para los mismos argumentos.")

	print("\n=== TEST 9: aserradero (madera -> tablas) y carbonera (madera -> carbón) ===")
	# aserradero: 1 técnico * 0.5 lote/h -> 0.5 madera -> 1.5 tablas
	var tasas_9: Dictionary = CadenaMinerales.tasas_refinado({"aserradero": 1, "carbonera": 1})
	assert(is_equal_approx(tasas_9["aserradero"]["consumo"]["madera"], 0.5))
	assert(is_equal_approx(tasas_9["aserradero"]["produccion"], 1.5))
	assert(tasas_9["aserradero"]["tipo_salida"] == "tablas")
	# carbonera: 1 * 2.0 = 2 lotes/h -> 6 madera -> 2 carbón
	assert(is_equal_approx(tasas_9["carbonera"]["consumo"]["madera"], 6.0))
	assert(is_equal_approx(tasas_9["carbonera"]["produccion"], 2.0))
	var resultado_9: Dictionary = CadenaMinerales.procesar_tick(1.0, {"madera": 10.0}, {"aserradero": 1})
	assert(is_equal_approx(resultado_9["madera"], 9.5) and is_equal_approx(resultado_9["tablas"], 1.5))
	for tipo_9 in ["siderurgica", "refineria_tierras_raras", "aserradero", "carbonera"]:
		assert(CadenaMinerales.RECETAS.has(CadenaMinerales.REFINERIAS[tipo_9]), tipo_9 + " apunta a una receta")
		assert(Recoleccion.cupo_de(tipo_9) == 4 and Recoleccion.capacidad_almacen_de(tipo_9) == 1000, tipo_9 + ": 4 técnicos, almacén 1000")
	print("OK: las recetas nuevas producen y consumen según la ficha; cupo 4 y almacén 1000 en todas las refinerías.")

	print("\n=== TEST 10: recetas de combustible (petroleo y combustible_sintetico), energía y espacio ===")
	# petroleo: 1 trabajador * 1.0 lote/h -> consume 2 crudo, produce 1 combustible
	var almac_p := {"crudo": 10.0}
	var res_p: Dictionary = CadenaMinerales.procesar_receta("petroleo", 1, 1.0, almac_p, 1.0)
	assert(is_equal_approx(res_p["crudo"], 8.0))
	assert(is_equal_approx(res_p["combustible"], 1.0))
	assert(almac_p["crudo"] == 10.0, "almacen original no se muta")

	# combustible_sintetico: 1 trabajador * 1.0 lote/h -> consume 3 carbon + 1 agua, produce 2 combustible
	var almac_s := {"carbon": 10.0, "agua": 5.0}
	var res_s: Dictionary = CadenaMinerales.procesar_receta("combustible_sintetico", 1, 1.0, almac_s, 1.0)
	assert(is_equal_approx(res_s["carbon"], 7.0))
	assert(is_equal_approx(res_s["agua"], 4.0))
	assert(is_equal_approx(res_s["combustible"], 2.0))

	# Factor de energía 0: no produce ni consume
	var res_p0: Dictionary = CadenaMinerales.procesar_receta("petroleo", 1, 1.0, {"crudo": 10.0}, 0.0)
	assert(is_equal_approx(res_p0["crudo"], 10.0) and is_equal_approx(res_p0["combustible"], 0.0))

	# Factor de energía 0.4: escala al 40 % sin redondear
	var res_p4: Dictionary = CadenaMinerales.procesar_receta("petroleo", 1, 1.0, {"crudo": 10.0}, 0.4)
	assert(is_equal_approx(res_p4["crudo"], 10.0 - 0.8))
	assert(is_equal_approx(res_p4["combustible"], 0.4))

	var res_s4: Dictionary = CadenaMinerales.procesar_receta("combustible_sintetico", 1, 1.0, {"carbon": 10.0, "agua": 5.0}, 0.4)
	assert(is_equal_approx(res_s4["carbon"], 10.0 - 1.2))
	assert(is_equal_approx(res_s4["agua"], 5.0 - 0.4))
	assert(is_equal_approx(res_s4["combustible"], 0.8))

	# Salida casi llena: si solo cabe 1.0 de producto, la producción se limita proporcionalmente antes de consumir
	# combustible_sintetico produce 2/lote. Con espacio para 1 combustible en almacén de 1000:
	var almac_lleno := {"carbon": 10.0, "agua": 5.0, "combustible": 999.0}
	var res_lleno: Dictionary = CadenaMinerales.procesar_receta("combustible_sintetico", 1, 1.0, almac_lleno, 1.0, 1000.0)
	assert(is_equal_approx(res_lleno["combustible"], 1000.0), "tope en 1000 combustible")
	# Produjo 1.0 combustible (0.5 lotes) -> consumió 1.5 carbon y 0.5 agua
	assert(is_equal_approx(res_lleno["carbon"], 8.5))
	assert(is_equal_approx(res_lleno["agua"], 4.5))

	# Recetas sólidas conservan sus tasas y no consumen energía
	var res_solido: Dictionary = CadenaMinerales.procesar_receta("hierro", 1, 1.0, {"hierro": 10.0, "carbon": 10.0}, 0.0)
	assert(is_equal_approx(res_solido["acero"], 4.0), "receta de hierro funciona sin energía (factor 0)")

	for tipo_f in ["refineria_petrolera", "productor_combustible"]:
		assert(CadenaMinerales.RECETAS.has(CadenaMinerales.REFINERIAS[tipo_f]), tipo_f + " apunta a una receta válida")
		assert(Recoleccion.cupo_de(tipo_f) == 4 and Recoleccion.capacidad_almacen_de(tipo_f) == 1000)

	print("\n=== Las 10 pruebas de CadenaMinerales pasaron correctamente ===")

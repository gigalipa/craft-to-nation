extends Node

## Puerto directo de ejecutar_pruebas() de PoC_1 (Python) a GDScript. Corre
## esta escena (CiudadTest.tscn) con F6 en el editor de Godot y revisa el
## panel "Output": debe imprimir los 7 tests y no debe lanzar ningún error
## de assert(). No usa el autoload "Ciudad" (que ya vive en el árbol de
## escena con su propio Timer) — instancia una Ciudad nueva vía preload,
## igual que PoC_1 hace `urbe = Ciudad()`, para poder correr las pruebas de
## forma aislada y repetible.

const CiudadScript = preload("res://scripts/Ciudad.gd")
const Ajustes = preload("res://scripts/ajustes.gd")


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	var urbe: Node = CiudadScript.new()
	var jugador: RefCounted = CiudadScript.Avatar.new(urbe)
	# Las pruebas 1-6 fijan la demografía a mano: se les da vivienda de sobra
	# (5 edificios de 2 pisos x 2 camas = 20 camas en el nivel 1) y se apaga
	# la migración para que no altere las cifras.
	for id_edificio in range(1, 6):
		urbe.registrar_edificio_residencial(id_edificio, [2, 2])
	urbe.migracion_activa = false

	print("=== TEST 1: Estado Inicial (Supervivencia Nivel 1) ===")
	urbe.instalaciones["tipo_1"] = 2
	urbe.demografia["obrero"] = 2
	urbe.demografia["ciudadano"] = 1
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
		urbe.actualizar_investigacion(5.0)
		urbe.simular_tick(jugador.tasa_hambre)
	print("Nivel Investigado: ", urbe.nivel_investigado, " | Nivel Efectivo: ", urbe.nivel)
	assert(urbe.nivel_investigado >= 2)

	print("\n=== TEST 4: Variedad de Fuentes Alimentarias y Bono de Moral de Dieta ===")
	for categoria in urbe.CATEGORIAS_COMIDA:
		urbe.sub_almacen_comida[categoria] = 1000.0  # las 6 categorías activas
	urbe.almacen["comida"].cantidad = 6000.0
	urbe.simular_tick(jugador.tasa_hambre)
	var bono_con_variedad: float = urbe.delta_dieta_actual()
	print("Bono de moral tras activar las 6 categorías: ", bono_con_variedad)
	assert(is_equal_approx(bono_con_variedad, 2.0), "6 categorías deben dar +2.0")
	urbe.sub_almacen_comida["sintetico"] = 0.0  # se desactiva una categoría (quedan 5)
	urbe.simular_tick(jugador.tasa_hambre)
	var bono_5_fuentes: float = urbe.delta_dieta_actual()
	print("Bono tras reducir a 5 categorías: ", bono_5_fuentes)
	assert(is_equal_approx(bono_5_fuentes, 1.0), "5 categorías deben dar +1.0")
	assert(bono_5_fuentes < bono_con_variedad)

	print("\n=== TEST 5: Asedio Militar y Degradación por Destrucción ===")
	print(">> El enemigo destruye todas las plantas Tipo 3...")
	urbe.instalaciones["tipo_3"] = 0
	urbe.demografia["obrero"] = 6
	res = urbe.simular_tick(jugador.tasa_hambre)
	print("Nivel Potencial Tras Ataque: ", res["nivel_potencial"], " | Nivel Efectivo: ", res["nivel_ciudad"])
	print("Ciudadanos Desahuciados: ", urbe.desahuciados)
	assert(urbe.desahuciados == 0, "con 20 camas de sobra, nadie se desahucia")
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

	print("\n=== TEST 7: Registro de Edificios Residenciales por id ===")
	# Ver Player.gd::_completar_construccion: al completar un edificio
	# residencial se registran sus camas POR PISO, identificadas por el id de
	# edificio que asigna VoxelWorld. Se usa una Ciudad nueva para partir de 0.
	var vivienda: Node = CiudadScript.new()
	assert(vivienda.capacidad_camas_construida == 0)
	vivienda.registrar_edificio_residencial(1, [1, 1])
	vivienda.registrar_edificio_residencial(2, [2, 1])
	print("Capacidad de camas tras registrar 2 edificios: ", vivienda.capacidad_camas_construida)
	assert(vivienda.capacidad_camas_construida == 5)

	print("\n=== TEST 8: retirar_edificio_residencial() ===")
	vivienda.retirar_edificio_residencial(1)
	assert(vivienda.capacidad_camas_construida == 3)
	vivienda.retirar_edificio_residencial(999)  # un id desconocido no hace nada
	assert(vivienda.capacidad_camas_construida == 3)
	vivienda.retirar_edificio_residencial(2)
	assert(vivienda.capacidad_camas_construida == 0, "Retirar el último edificio deja la capacidad en 0")

	print("\n=== TEST 9: Vivienda Fraccionaria (x Cama) ===")
	var v: Node = CiudadScript.new()
	v.registrar_edificio_residencial(1, [2, 2])  # 4 camas en el nivel 1
	v.demografia["obrero"] = 8  # 8 / 4 = 2.0
	v.demografia["tecnico"] = 3  # 3 / 3 = 1.0
	v.demografia["investigador"] = 1  # 1 / 1 = 1.0
	print("Vivienda ocupada: ", v.vivienda_ocupada, " | libre: ", v.vivienda_libre)
	assert(is_equal_approx(v.vivienda_ocupada, 4.0))
	assert(is_equal_approx(v.vivienda_libre, 0.0))
	v.demografia["obrero"] = 4  # 1.0 en vez de 2.0
	assert(is_equal_approx(v.vivienda_libre, 1.0))

	print("\n=== TEST 10: El registro es idempotente por id ===")
	var idem: Node = CiudadScript.new()
	idem.registrar_edificio_residencial(1, [2, 2])
	idem.registrar_edificio_residencial(1, [2, 2])  # el mismo edificio otra vez
	assert(idem.capacidad_camas_construida == 4, "Registrar dos veces el mismo id no debe duplicar las camas")

	print("\n=== TEST 11: La capacidad respeta los pisos y camas por piso del nivel ===")
	var niv: Node = CiudadScript.new()
	niv.registrar_edificio_residencial(1, [4, 4, 4, 4, 4])  # 5 pisos de 4 camas
	assert(niv.capacidad_camas_construida == 4, "Nivel 1: 2 pisos x min(4, 2) camas")
	niv.instalaciones["tipo_2"] = 3  # con solo tipo_2 el índice es 2.0 y hay 3 plantas: nivel potencial 2
	niv.nivel_investigado = 2
	assert(niv.nivel == 2)
	assert(niv.capacidad_camas_construida == 16, "Nivel 2: 4 pisos x min(4, 4) camas")

	print("\n=== TEST 12: Bajar de nivel desahucia a quien vivía en los pisos que dejan de contar ===")
	niv.demografia["obrero"] = 64  # 64 / 4 = 16.0: cabe justo en el nivel 2
	niv.regular_densidad_vertical()
	assert(niv.demografia["obrero"] == 64 and niv.desahuciados == 0)
	niv.instalaciones["tipo_2"] = 0  # el ratio cae: nivel efectivo 1, solo 4 camas cuentan
	assert(niv.nivel == 1)
	niv.regular_densidad_vertical()
	print("Obreros tras bajar de nivel: ", niv.demografia["obrero"], " | desahuciados: ", niv.desahuciados)
	assert(niv.demografia["obrero"] == 16)
	assert(niv.desahuciados == 48)

	print("\n=== TEST 13: Orden de desahucio (primero quien no produce) ===")
	var orden_test: Node = CiudadScript.new()
	orden_test.registrar_edificio_residencial(1, [2, 2])  # 4 camas
	orden_test.demografia["desempleado"] = 8  # 2.0
	orden_test.demografia["ciudadano"] = 4  # 0.8 (x_cama 5 desde el balance 2026-09-28)
	orden_test.demografia["obrero"] = 4  # 1.0
	orden_test.demografia["tecnico"] = 3  # 1.0
	orden_test.demografia["militar"] = 4  # 1.33..  -> total 6.13.., sobran 2.13..
	orden_test.regular_densidad_vertical()
	assert(orden_test.demografia["desempleado"] == 0, "los desempleados se desahucian primero")
	assert(orden_test.demografia["ciudadano"] == 2, "luego los ciudadanos con x_cama 4, solo los necesarios")
	assert(orden_test.demografia["obrero"] == 4 and orden_test.demografia["tecnico"] == 3 and orden_test.demografia["militar"] == 4)
	assert(orden_test.desahuciados == 10)

	print("\n=== TEST 14: Migración de colonos ===")
	# 14a: con vivienda y tasa mensual acumulada, llega cuando el acumulador cruza 1.0.
	var mig: Node = CiudadScript.new()
	mig.registrar_edificio_residencial(1, [2, 2])  # 4 camas = hasta 16 desempleados
	mig._migrantes_acumulados = 0.999
	var res_mig: Dictionary = mig.simular_tick(5.0)
	assert(mig.demografia["desempleado"] == 1)
	assert(res_mig["migrantes"] == 1, "al cruzar 1.0 llega un desempleado")

	# 14b: sin ninguna vivienda no llega nadie.
	var sin_casa: Node = CiudadScript.new()
	for i in range(10):
		sin_casa.simular_tick(5.0)
	assert(sin_casa.demografia["desempleado"] == 0)

	# 14c: la hambruna bloquea la migración.
	var hambre: Node = CiudadScript.new()
	hambre.registrar_edificio_residencial(1, [2, 2])
	hambre.almacen["comida"].cantidad = 0.0
	for i in range(4):
		hambre.simular_tick(5.0)
	assert(hambre.demografia["desempleado"] == 0)

	# 14d: con la vivienda llena no llegan más, y tampoco se acumula una
	# "bolsa" de migrantes que entre de golpe al liberarse espacio.
	var llena: Node = CiudadScript.new()
	llena.registrar_edificio_residencial(1, [1])  # 1 cama = 4 desempleados
	llena.demografia["desempleado"] = 4
	llena.almacen["comida"].cantidad = 2000.0
	llena._migrantes_acumulados = 1.0
	llena.simular_tick(5.0)
	assert(llena.demografia["desempleado"] == 4, "vivienda llena no recibe más")
	assert(is_equal_approx(llena._migrantes_acumulados, 1.0), "acumulador queda topado a 1")
	llena.registrar_edificio_residencial(2, [1])  # otra cama: caben 4 más
	llena.alternar_colonizable(2)  # permitir inmigración para probar la tasa de llegada
	llena.simular_tick(5.0)
	assert(llena.demografia["desempleado"] == 5, "llega de uno en uno, sin ráfaga de 4")

	print("\n=== TEST 15: simular_tick() emite tick_simulado ===")
	var senal: Node = CiudadScript.new()
	var contador := [0]
	senal.tick_simulado.connect(func() -> void: contador[0] += 1)
	senal.simular_tick(5.0)
	senal.simular_tick(5.0)
	assert(contador[0] == 2)

	print("\n=== TEST 16: La hambruna también cobra bajas entre los desempleados ===")
	var famelica: Node = CiudadScript.new()
	famelica.registrar_edificio_residencial(1, [2, 2])
	famelica.migracion_activa = false
	famelica.demografia["desempleado"] = 8
	famelica.almacen["comida"].cantidad = 0.0
	famelica.simular_tick(5.0)
	print("Desempleados tras la hambruna: ", famelica.demografia["desempleado"])
	assert(famelica.demografia["desempleado"] < 8, "la hambruna debe quitar desempleados")
	assert(famelica.demografia["desempleado"] == 6, "bajas = max(1, int(8 * 0.25)) = 2")

	print("\n=== TEST 16b: La hambruna también cobra bajas entre especialistas e investigadores ===")
	var famelica_esp: Node = CiudadScript.new()
	famelica_esp.registrar_edificio_residencial(1, [2, 2])
	famelica_esp.registrar_edificio_residencial(2, [2, 2])
	famelica_esp.migracion_activa = false
	famelica_esp.demografia["especialista"] = 4
	famelica_esp.demografia["investigador"] = 4
	famelica_esp.almacen["comida"].cantidad = 0.0
	famelica_esp.simular_tick(5.0)
	assert(famelica_esp.demografia["especialista"] == 2, "bajas = max(1, int(8 * 0.25)) = 2 sobre especialistas")
	famelica_esp.demografia["especialista"] = 0
	famelica_esp.simular_tick(5.0)
	assert(famelica_esp.demografia["investigador"] == 3, "al agotarse especialistas, cobra bajas en investigadores")

	print("\n=== TEST 17: la ciudad recién creada no pasa hambruna durante 10 minutos de juego ===")
	# Sin producción de comida, el stock inicial debe alcanzar para que el
	# avatar coma 10 minutos (300 ticks de 2 s) sin hambruna.
	var recien_nacida: Node = CiudadScript.new()
	recien_nacida.migracion_activa = false
	assert(recien_nacida.almacen["comida"].cantidad == recien_nacida.COMIDA_INICIAL, "la comida inicial es COMIDA_INICIAL")
	var hubo_hambruna := false
	for i in range(300):
		if recien_nacida.simular_tick(5.0)["hambruna"]:
			hubo_hambruna = true
	print("Comida tras 300 ticks: ", recien_nacida.almacen["comida"].cantidad)
	assert(not hubo_hambruna, "no debe haber hambruna en los primeros 10 minutos")

	print("\n=== TEST 18: el almacén tiene los 15 recursos de la economía ===")
	var ocho: Node = CiudadScript.new()
	for clave in ["madera", "comida", "hierro", "tierra", "piedra", "cobre", "carbon", "tierras_raras", "acero", "mineral_refinado", "tablas", "bloques_piedra", "agua", "crudo", "combustible"]:
		assert(ocho.almacen.has(clave), "falta el recurso " + clave)
	assert(ocho.almacen.size() == 15)
	assert(ocho.almacen["acero"].cantidad == 0.0 and ocho.almacen["acero"].limite == 500.0, "el acero empieza en 0 con el tope inicial")
	assert(ocho.almacen["tierra"].cantidad == 0.0 and ocho.almacen["tierras_raras"].limite == 500.0, "el tope inicial de un recurso es 500")
	assert(ocho.almacen["bloques_piedra"].cantidad == 0.0 and ocho.almacen["bloques_piedra"].limite == 500.0)
	assert(ocho.almacen["comida"].cantidad == ocho.COMIDA_INICIAL, "la comida inicial es COMIDA_INICIAL")
	assert(ocho.almacen["comida"].limite == 5000.0, "el tope inicial de comida es 5000")

	print("\n=== TEST 19: reasignar_tipo() mueve un habitante de un tipo a otro ===")
	var reasig: Node = CiudadScript.new()
	reasig.demografia["desempleado"] = 2
	assert(reasig.reasignar_tipo("desempleado", "obrero"))
	assert(reasig.demografia["desempleado"] == 1 and reasig.demografia["obrero"] == 1)
	assert(reasig.censo_total == 2, "el censo total no cambia")
	assert(reasig.reasignar_tipo("desempleado", "obrero"))
	assert(not reasig.reasignar_tipo("desempleado", "obrero"), "sin desempleados no reasigna")
	assert(reasig.demografia["desempleado"] == 0 and reasig.demografia["obrero"] == 2)

	print("\n=== TEST 20: tasa_neta se mide entre cierres de tick consecutivos ===")
	var neta: Node = CiudadScript.new()
	neta.migracion_activa = false
	neta.simular_tick(0.0)  # primer tick: sin consumo, todas las tasas en 0
	assert(neta.almacen["madera"].tasa_neta == 0.0)
	# Una entrega ENTRE ticks (la de un acarreador) debe verse en la tasa del siguiente.
	neta.almacen["madera"].agregar(30.0)
	neta.simular_tick(0.0)
	assert(is_equal_approx(neta.almacen["madera"].tasa_neta, 30.0), "la entrega entre ticks cuenta")
	neta.simular_tick(0.0)
	assert(neta.almacen["madera"].tasa_neta == 0.0, "sin entregas, vuelve a 0")

	print("\n=== TEST 21: tasa_neta_promedio promedia las últimas VENTANA_TASA_PROMEDIO horas ===")
	var prom: Node = CiudadScript.new()
	prom.migracion_activa = false
	prom.simular_tick(0.0)  # primer tick: tasa 0 (1 muestra)
	assert(prom.almacen["madera"].tasa_neta_promedio == 0.0)
	# Una entrega de 30 cada 3 horas (a tirones, como los acarreadores): media 10/h.
	for i in range(3):
		prom.almacen["madera"].agregar(30.0)
		prom.simular_tick(0.0)
		prom.simular_tick(0.0)
		prom.simular_tick(0.0)
	# La ventana (10 muestras: el tick inicial + 9 horas) suma las 3 entregas: 90 / 10.
	var esperado: float = 90.0 / prom.VENTANA_TASA_PROMEDIO
	assert(is_equal_approx(prom.almacen["madera"].tasa_neta_promedio, esperado), "media de la ventana: %s" % prom.almacen["madera"].tasa_neta_promedio)
	assert(prom.almacen["madera"].tasa_neta == 0.0, "tasa_neta sigue siendo la de la última hora")
	# Tras VENTANA_TASA_PROMEDIO horas sin entregas, la ventana ya no recuerda las entregas.
	for i in range(prom.VENTANA_TASA_PROMEDIO):
		prom.simular_tick(0.0)
	assert(prom.almacen["madera"].tasa_neta_promedio == 0.0, "la ventana descarta las muestras viejas")

	print("\n=== TEST 22: topes iniciales, ampliar_almacen(), bono por baúles y stock que excede el tope ===")
	var lim: Node = CiudadScript.new()
	assert(lim.almacen["piedra"].limite == 500.0 and lim.almacen["comida"].limite == 5000.0)
	lim.ampliar_almacen()
	assert(lim.almacen["piedra"].limite == 1000.0 and lim.almacen["comida"].limite == 10000.0, "declarar el núcleo duplica los topes")
	lim.ampliar_almacen()
	assert(lim.almacen["piedra"].limite == 1000.0, "ampliar_almacen() es idempotente")
	lim.registrar_edificio_residencial(7, [2], 3)
	assert(lim.almacen["piedra"].limite == 1300.0 and lim.almacen["comida"].limite == 11200.0, "3 baúles: +300 (+1200 comida)")
	lim.registrar_edificio_residencial(7, [2], 3)
	assert(lim.almacen["piedra"].limite == 1300.0, "registrar dos veces el mismo edificio no duplica sus baúles")
	lim.registrar_edificio_residencial(8, [1])
	assert(lim.almacen["piedra"].limite == 1300.0, "sin baúles no cambia el tope")
	lim.almacen["piedra"].cantidad = 1250.0
	lim.retirar_edificio_residencial(7)
	assert(lim.almacen["piedra"].limite == 1000.0, "deconstruir el edificio quita su bono")
	assert(lim.almacen["piedra"].cantidad == 1250.0, "el stock que excede el nuevo tope se conserva")
	assert(lim.almacen["piedra"].agregar(50.0) == 0.0 and lim.almacen["piedra"].cantidad == 1250.0, "sin espacio no entra nada y nada se destruye")
	assert(lim.horas_juego == 0)
	lim.simular_tick(0.0)
	lim.simular_tick(0.0)
	assert(lim.horas_juego == 2, "cada tick es una hora de juego")

	print("\n=== TEST 23: las tablas cuentan como madera al pagar un costo (consumir_costo) ===")
	var talado: Node = CiudadScript.new()
	talado.almacen["madera"].cantidad = 10.0
	talado.almacen["tablas"].cantidad = 5.0
	assert(talado.consumir_costo("madera", 8.0))
	assert(talado.almacen["tablas"].cantidad == 0.0 and talado.almacen["madera"].cantidad == 7.0, "paga primero con tablas y el resto con madera")
	assert(not talado.consumir_costo("madera", 8.0) and talado.almacen["madera"].cantidad == 7.0, "sin alcanzar no cobra nada")
	talado.almacen["hierro"].cantidad = 3.0
	assert(talado.consumir_costo("hierro", 3.0) and not talado.consumir_costo("hierro", 1.0), "un recurso que no es madera se cobra normal")
	talado.almacen["madera"].cantidad = 10.0
	talado.almacen["tablas"].cantidad = 4.0
	var detalle: Dictionary = talado.consumir_costo_con_detalle("madera", 6.0)
	assert(detalle == {"tablas": 4.0, "madera": 2.0}, "desglosa exactamente lo cobrado: %s" % detalle)

	print("\n=== TEST 23b: los bloques_piedra cuentan como piedra al pagar un costo (consumir_costo) ===")
	var canteria: Node = CiudadScript.new()
	canteria.almacen["piedra"].cantidad = 10.0
	canteria.almacen["bloques_piedra"].cantidad = 5.0
	assert(canteria.consumir_costo("piedra", 8.0))
	assert(canteria.almacen["bloques_piedra"].cantidad == 0.0 and canteria.almacen["piedra"].cantidad == 7.0, "paga primero con bloques_piedra y el resto con piedra")
	assert(not canteria.consumir_costo("piedra", 8.0) and canteria.almacen["piedra"].cantidad == 7.0, "sin alcanzar no cobra nada")
	canteria.almacen["piedra"].cantidad = 10.0
	canteria.almacen["bloques_piedra"].cantidad = 4.0
	var detalle_p: Dictionary = canteria.consumir_costo_con_detalle("piedra", 6.0)
	assert(detalle_p == {"bloques_piedra": 4.0, "piedra": 2.0}, "desglosa exactamente lo cobrado: %s" % detalle_p)
	canteria.almacen["bloques_piedra"].cantidad = 4.0
	assert(canteria.almacen_general()["piedra"] == 12.0, "almacen_general suma piedra (8) y bloques_piedra (4)")

	print("\n=== TEST 24: horas explícitas de investigación, atomicidad de cobro e instalaciones físicas ===")
	var ciu24: Node = CiudadScript.new()
	ciu24.instalaciones["tipo_2"] = 3  # habilita nivel potencial 2
	ciu24.almacen["hierro"].cantidad = 100.0
	ciu24.almacen["madera"].cantidad = 100.0
	var hierro_antes: float = ciu24.almacen["hierro"].cantidad
	var madera_antes: float = ciu24.almacen["madera"].cantidad
	assert(not ciu24.consumir_costos({"hierro": hierro_antes + 1.0, "madera": 1.0}))
	assert(ciu24.almacen["hierro"].cantidad == hierro_antes)
	assert(ciu24.almacen["madera"].cantidad == madera_antes)
	assert(ciu24.consumir_costos({"hierro": 10.0, "madera": 10.0}))
	assert(ciu24.almacen["hierro"].cantidad == hierro_antes - 10.0)
	assert(ciu24.almacen["madera"].cantidad == madera_antes - 10.0)

	# 0 horas no avanza
	assert(not ciu24.actualizar_investigacion(0.0))
	assert(ciu24.progreso_investigacion[2] == 0.0)
	# 2 investigadores aportan 2 h
	assert(not ciu24.actualizar_investigacion(2.0))
	assert(ciu24.progreso_investigacion[2] == 2.0)

	# Nivel potencial insuficiente pausa el progreso
	ciu24.instalaciones["tipo_2"] = 0  # baja a nivel potencial 1
	assert(not ciu24.actualizar_investigacion(5.0))
	assert(ciu24.progreso_investigacion[2] == 2.0, "potencial insuficiente no pierde progreso pero no avanza")
	ciu24.instalaciones["tipo_2"] = 3  # recupera potencial 2

	# Recursos insuficientes al umbral: progreso queda topado en 20 h sin cobro parcial
	ciu24.almacen["hierro"].cantidad = 10.0
	ciu24.almacen["madera"].cantidad = 10.0
	assert(not ciu24.actualizar_investigacion(30.0))
	assert(ciu24.progreso_investigacion[2] == 20.0, "progreso topado en 20 h")
	assert(ciu24.almacen["hierro"].cantidad == 10.0, "no cobró hierro parcial")
	assert(ciu24.nivel_investigado == 1)

	# Al reponer recursos completa una vez
	ciu24.almacen["hierro"].cantidad = 500.0
	ciu24.almacen["madera"].cantidad = 500.0
	assert(ciu24.actualizar_investigacion(1.0))
	assert(ciu24.nivel_investigado == 2)
	assert(ciu24.almacen["hierro"].cantidad == 200.0, "cobró exactamente 300 hierro")
	assert(ciu24.almacen["madera"].cantidad == 300.0, "cobró exactamente 200 madera")

	# Sofisticación física: registro idempotente de instalaciones
	var ciu_inst: Node = CiudadScript.new()
	assert(ciu_inst.instalaciones["tipo_2"] == 0)
	ciu_inst.registrar_instalacion(10, "siderurgica")
	assert(ciu_inst.instalaciones["tipo_2"] == 1)
	ciu_inst.registrar_instalacion(10, "siderurgica")
	assert(ciu_inst.instalaciones["tipo_2"] == 1, "idempotente")
	ciu_inst.registrar_instalacion(11, "aserradero")
	assert(ciu_inst.instalaciones["tipo_2"] == 2)
	ciu_inst.desregistrar_instalacion(10)
	assert(ciu_inst.instalaciones["tipo_2"] == 1)
	ciu_inst.desregistrar_instalacion(10)
	assert(ciu_inst.instalaciones["tipo_2"] == 1, "desregistrar dos veces es no-op")

	print("\n=== TEST 25: recursos fluidos agua, crudo y combustible ===")
	var ciu25: Node = CiudadScript.new()
	assert(ciu25.almacen.has("agua") and ciu25.almacen["agua"].cantidad == 0.0 and ciu25.almacen["agua"].limite == Ciudad.LIMITE_BASE)
	assert(ciu25.almacen.has("crudo") and ciu25.almacen["crudo"].cantidad == 0.0 and ciu25.almacen["crudo"].limite == Ciudad.LIMITE_BASE)
	assert(ciu25.almacen.has("combustible") and ciu25.almacen["combustible"].cantidad == 0.0 and ciu25.almacen["combustible"].limite == Ciudad.LIMITE_BASE)

	print("\n=== TEST 26: traslado de núcleo urbano y desahucio priorizado ===")
	var ciu26: Node = CiudadScript.new()
	ciu26.migracion_activa = false
	ciu26.guardar_datos_nucleo(1, [1], 1)
	ciu26.registrar_edificio_residencial(2, [4], 2)
	assert(ciu26.camas_de(1) == 1)
	assert(ciu26.camas_de(2) == 4)
	assert(ciu26.baules_de(1) == 1)
	assert(ciu26.baules_de(2) == 2)

	ciu26.demografia["investigador"] = 4
	assert(absf(ciu26.vivienda_ocupada - 4.0) < 0.001)

	var deficit: float = ciu26.calcular_deficit_traslado(2)
	assert(absf(deficit - 3.0) < 0.001)

	ciu26.demografia["obrero"] = 12
	ciu26.programar_traslado_nucleo(2, 2)
	assert(ciu26.esta_traslado_programado(2))
	assert(ciu26.horas_traslado_programado() == 2)
	ciu26.simular_tick(0.0)
	assert(ciu26.horas_traslado_programado() == 1)
	assert(ciu26.id_nucleo == 1)
	ciu26.simular_tick(0.0)
	assert(not ciu26.esta_traslado_programado(2))
	assert(ciu26.id_nucleo == 2)
	assert(ciu26.camas_de(2) == 4)
	assert(ciu26.camas_de(1) == 1)
	ciu26.demografia["obrero"] = 0
	ciu26.demografia["investigador"] = 1

	print("\n=== TEST 27: Sistema de colonizabilidad (buffers e inmigración) ===")
	var ciu27: Node = CiudadScript.new()
	ciu27.almacen["comida"].cantidad = 5000.0
	ciu27.registrar_edificio_residencial(1, [1])
	assert(ciu27.es_colonizable(1), "el 1er edificio es colonizable inmediatamente")
	assert(ciu27.horas_colonizacion_restantes(1) == 0)

	ciu27.registrar_edificio_residencial(2, [1])
	assert(not ciu27.es_colonizable(2), "edificios posteriores nacen como buffer inactivo")
	assert(ciu27.horas_colonizacion_restantes(2) == 24, "cuenta regresiva de 24 horas")
	assert(ciu27.capacidad_camas_colonizable == 1, "solo cuenta la cama del edificio 1")
	assert(ciu27.capacidad_camas_construida == 2, "capacidad total construida incluye el buffer")

	# Llenar edificio 1 con 4 desempleados
	ciu27.demografia["desempleado"] = 4
	ciu27.sincronizar_desempleados()
	assert(ciu27.demografia["desempleado"] == 4, "edificio 1 lleno")
	assert(ciu27.vivienda_colonizable_libre == 0.0, "sin camas colonizables libres")

	# Nuevos inmigrantes NO entran al buffer
	ciu27._migrantes_acumulados = 1.0
	var mig_antes: int = ciu27.demografia["desempleado"]
	ciu27.simular_tick(0.0)
	assert(ciu27.demografia["desempleado"] == mig_antes, "el buffer bloquea inmigrantes foráneos")

	# Alternar colonizabilidad manualmente
	ciu27.alternar_colonizable(2)
	assert(ciu27.es_colonizable(2), "alternar activa la colonizabilidad")
	assert(ciu27.horas_colonizacion_restantes(2) == 0)
	ciu27._migrantes_acumulados = 1.0
	ciu27.simular_tick(0.0)
	assert(ciu27.demografia["desempleado"] == 5, "ahora sí recibe inmigrantes")

	# Apertura automática tras 24 horas de juego
	var ciu27b: Node = CiudadScript.new()
	ciu27b.registrar_edificio_residencial(10, [1])
	ciu27b.registrar_edificio_residencial(20, [1])
	assert(not ciu27b.es_colonizable(20))
	for i in range(23):
		ciu27b.simular_tick(0.0)
	assert(not ciu27b.es_colonizable(20), "tras 23 horas sigue inactivo")
	assert(ciu27b.horas_colonizacion_restantes(20) == 1)
	ciu27b.simular_tick(0.0)
	assert(ciu27b.es_colonizable(20), "a las 24 horas transiciona automáticamente a ACTIVO")
	assert(ciu27b.horas_colonizacion_restantes(20) == 0)

	print("\n=== TEST 28: Remodelación, reubicación y estado Sin Techo ===")
	var ciu28: Node = CiudadScript.new()
	ciu28.migracion_activa = false

	# Remodelar núcleo urbano: inmediato sin camas ni penalizaciones
	ciu28.guardar_datos_nucleo(1, [2], 2)
	var res_nuc: Dictionary = ciu28.iniciar_remodelacion_residencial(1)
	assert(res_nuc["exito"] and res_nuc["es_nucleo"] and res_nuc["sin_techo_generados"] == 0)
	assert(ciu28.remodelando_nucleo and ciu28.id_nucleo == -1)

	# Remodelación con reubicación completa en buffers existentes
	ciu28.registrar_edificio_residencial(10, [1])
	ciu28.registrar_edificio_residencial(20, [1])  # buffer
	ciu28.demografia["desempleado"] = 4  # caben en la cama de 20
	var res10: Dictionary = ciu28.iniciar_remodelacion_residencial(10)
	assert(res10["exito"] and res10["sin_techo_generados"] == 0)
	assert(ciu28.sin_techo == 0)
	assert(ciu28.demografia["desempleado"] == 4, "los 4 se reubicaron en el buffer 20")

	# Remodelación con exceso poblacional -> Sin Techo
	ciu28.registrar_edificio_residencial(15, [1])
	ciu28.demografia["desempleado"] = 8  # 4 caben en 15, 4 exceden al remodelar 20
	assert(ciu28.calcular_sin_techo_al_remodelar(20) == 4)
	var res20: Dictionary = ciu28.iniciar_remodelacion_residencial(20)
	assert(res20["exito"] and res20["sin_techo_generados"] == 4)
	assert(ciu28.sin_techo == 4)
	assert(ciu28.demografia["desempleado"] == 4)
	assert(ciu28.censo_total == 8, "censo total incluye a los sin techo")

	# Consumo de comida de los sin techo: 3/tick igual a desempleado
	ciu28.almacen["comida"].cantidad = 1000.0
	var comida_inicio: float = ciu28.almacen["comida"].cantidad
	ciu28.simular_tick(0.0)
	# Gasto: 4 alojados * 3 + 4 sin techo * 3 = 24
	assert(is_equal_approx(ciu28.almacen["comida"].cantidad, comida_inicio - 24.0))
	assert(ciu28.tiempo_sin_techo == 1)

	# Reabsorción inmediata al habilitar nueva vivienda
	ciu28.registrar_edificio_residencial(30, [1])  # 1 cama = 4 desempleados
	assert(ciu28.sin_techo == 0, "sin techo reabsorbidos inmediatamente")
	assert(ciu28.demografia["desempleado"] == 8)
	assert(ciu28.tiempo_sin_techo == 0)

	# Exilio por temporizador de 72 horas sin cama (GDD v3.56)
	var res30: Dictionary = ciu28.iniciar_remodelacion_residencial(30)
	assert(res30["sin_techo_generados"] == 4)
	assert(ciu28.sin_techo == 4)
	for i in range(71):
		ciu28.simular_tick(0.0)
	assert(ciu28.sin_techo == 4 and ciu28.tiempo_sin_techo == 71)
	var desah_antes: int = ciu28.desahuciados
	ciu28.simular_tick(0.0)
	assert(ciu28.sin_techo == 0, "emigran al cumplirse las 72 horas")
	assert(ciu28.tiempo_sin_techo == 0)
	assert(ciu28.desahuciados == desah_antes + 4)

	print("\n=== TEST 29: Dinámica de Moral y Multiplicador de Productividad ===")
	var ciu29: Node = CiudadScript.new()
	assert(ciu29.moral == 75.0, "la moral inicial debe comenzar en 75.0 (optimismo inicial)")
	assert(is_equal_approx(CiudadScript.calcular_multiplicador_productividad(0.0), 0.5), "productividad a moral 0 debe ser 0.5")
	assert(is_equal_approx(CiudadScript.calcular_multiplicador_productividad(50.0), 1.0), "productividad a moral 50 debe ser 1.0")
	assert(is_equal_approx(CiudadScript.calcular_multiplicador_productividad(100.0), 2.0), "productividad a moral 100 debe ser 2.0")

	# Caída severa ante hambruna prolongada
	ciu29.migracion_activa = false
	ciu29.demografia["obrero"] = 5
	ciu29.almacen["comida"].cantidad = 0.0 # Hambruna
	var moral_antes: float = ciu29.moral
	ciu29.simular_tick(0.0)
	assert(ciu29.moral < moral_antes, "la moral debe descender fuertemente durante la hambruna")
	assert(ciu29.tasa_cambio_moral < -2.0, "tasa de cambio de moral debe reflejar fuerte penalización")

	print("\n=== TEST 30: Buffer de Peligrosidad (7 días / 168 horas) ===")
	var ciu30: Node = CiudadScript.new()
	ciu30.migracion_activa = false
	ciu30.registrar_edificio_residencial(1, [2, 2])
	ciu30.demografia["obrero"] = 1
	ciu30.almacen["comida"].cantidad = 5000.0

	ciu30.registrar_baja_seguridad(2)
	ciu30.registrar_herido_seguridad(3)
	ciu30.registrar_robo_seguridad(100.0)
	# Impacto esperado: -(0.5*2 + 0.1*3 + 0.005*100) = -(1.0 + 0.3 + 0.5) = -1.8
	assert(is_equal_approx(ciu30.impacto_peligrosidad_7d(), 1.8), "impacto de peligrosidad acumulado en 7d")
	ciu30.simular_tick(0.0)
	assert(ciu30.tasa_cambio_moral < 0.0, "la peligrosidad reduce la tasa de moral")

	# Tras 168 horas, el impacto se desvanece
	for i in range(168):
		ciu30.simular_tick(0.0)
	assert(is_equal_approx(ciu30.impacto_peligrosidad_7d(), 0.0), "el buffer de 168h expira eventos antiguos")

	print("\n=== TEST 31: Flujo Migratorio Escalonado, Éxodo Jerárquico y Desempleo de 10 Días ===")
	var ciu31: Node = CiudadScript.new()
	ciu31.registrar_edificio_residencial(1, [2, 2])
	ciu31.almacen["comida"].cantidad = 5000.0

	# 0. Verificación de tasas mensuales escalonadas
	assert(CiudadScript.calcular_tasa_migracion_mensual(5.0) == -5.0)
	assert(CiudadScript.calcular_tasa_migracion_mensual(10.0) == -3.0)
	assert(CiudadScript.calcular_tasa_migracion_mensual(15.0) == -2.0)
	assert(CiudadScript.calcular_tasa_migracion_mensual(20.0) == -1.0)
	assert(CiudadScript.calcular_tasa_migracion_mensual(25.0) == 1.0)
	assert(CiudadScript.calcular_tasa_migracion_mensual(35.0) == 2.0)
	assert(CiudadScript.calcular_tasa_migracion_mensual(50.0) == 3.0)
	assert(CiudadScript.calcular_tasa_migracion_mensual(75.0) == 3.0)
	assert(CiudadScript.calcular_tasa_migracion_mensual(100.0) == 5.0)

	# 1. Éxodo jerárquico cuando moral <= 20
	ciu31.moral = 15.0
	ciu31.demografia["investigador"] = 1
	ciu31.demografia["obrero"] = 1
	ciu31._migrantes_acumulados = -1.0
	ciu31._migrar(false) # Con acumulador que cruza el umbral
	# Fuga de cerebros: investigador emigra primero que obrero
	assert(ciu31.demografia["investigador"] == 0, "el investigador emigra primero en fuga de cerebros")
	assert(ciu31.demografia["obrero"] == 1, "el obrero permanece")

	# 2a. Inmigración con moral <= 50 y sin camas libres: NO desborda a sin techo
	var ciu31b1: Node = CiudadScript.new()
	ciu31b1.moral = 40.0
	ciu31b1.guardar_datos_nucleo(1, [1], 0)
	ciu31b1.registrar_edificio_residencial(1, [1]) # 1 cama = 4 desempleados
	ciu31b1.demografia["desempleado"] = 4 # vivienda llena
	ciu31b1._migrantes_acumulados = 1.0
	ciu31b1._migrar(false)
	assert(ciu31b1.sin_techo == 0, "con moral <= 50 no genera sin techo si las camas estan llenas")
	assert(is_equal_approx(ciu31b1._migrantes_acumulados, 1.0), "acumulador queda topado a 1.0 a la espera de camas")

	# 2b. Inmigración masiva con moral > 50: desborda a Sin Techo si hay núcleo urbano
	var ciu31b2: Node = CiudadScript.new()
	ciu31b2.moral = 60.0
	ciu31b2.guardar_datos_nucleo(1, [1], 0)
	ciu31b2.registrar_edificio_residencial(1, [1]) # 1 cama = 4 desempleados
	ciu31b2.demografia["desempleado"] = 4 # vivienda llena
	ciu31b2._migrantes_acumulados = 1.0
	ciu31b2._migrar(false)
	assert(ciu31b2.sin_techo == 1, "si moral > 50 y no hay camas libres, el nuevo colono se convierte en sin techo")

	# 3. Éxodo por desempleo tras 240 horas (10 días)
	var ciu31c: Node = CiudadScript.new()
	ciu31c.migracion_activa = false
	ciu31c.registrar_edificio_residencial(1, [2, 2])
	ciu31c.demografia["desempleado"] = 1
	ciu31c.sincronizar_desempleados()
	var desah_antes_31: int = ciu31c.desahuciados
	for i in range(239):
		ciu31c.simular_tick(0.0)
	assert(ciu31c.demografia["desempleado"] == 1, "a las 239h todavía no emigra")
	ciu31c.simular_tick(0.0) # Hora 240
	assert(ciu31c.demografia["desempleado"] == 0, "a las 240h el desempleado emigra de la ciudad")
	assert(ciu31c.desahuciados == desah_antes_31 + 1)

	# 4. Boost de inmigración: solo se puede activar con moral que produce inmigración positiva
	var ciu_boost: Node = CiudadScript.new()
	ciu_boost.moral = 15.0 # Éxodo
	assert(not ciu_boost.puede_activar_boost_inmigracion(), "no se debe poder activar boost cuando hay éxodo")
	assert(not ciu_boost.activar_boost_inmigracion(), "activar_boost_inmigracion debe retornar false durante éxodo")
	assert(ciu_boost.horas_boost_inmigracion == 0)

	ciu_boost.moral = 50.0 # Inmigración positiva (+3.0)
	assert(ciu_boost.puede_activar_boost_inmigracion(), "se debe poder activar boost con moral positiva")
	assert(ciu_boost.tasa_migracion_mensual_efectiva() == 3.0, "sin boost activo la tasa efectiva es igual a la base")
	assert(ciu_boost.activar_boost_inmigracion(), "activar_boost_inmigracion debe retornar true")
	assert(ciu_boost.horas_boost_inmigracion == int(CiudadScript.HORAS_POR_MES))
	assert(not ciu_boost.puede_activar_boost_inmigracion(), "no se puede reactivar si ya está activo")
	assert(ciu_boost.tasa_migracion_mensual_efectiva() == 3.0 * Ajustes.CIUDAD_MULTIPLICADOR_BOOST_INMIGRACION)
	assert(ciu_boost.dias_boost_inmigracion_restantes() == 30)

	print("\n=== TEST 32: Escasez de Comida Dinámica, Alertas con Histéresis y Autonomía ===")
	var ciu32: Node = CiudadScript.new()
	ciu32.migracion_activa = false
	ciu32.demografia["obrero"] = 1
	var com_32 = ciu32.almacen["comida"]
	com_32.limite = 5000.0

	# Caso 1: Superávit (>= 90%, 4600 / 5000 = 92%). Con tasa negativa, no hay penalización por escasez
	com_32.cantidad = 4600.0
	com_32.tasa_neta_promedio = -10.0
	ciu32.moral = 50.0 # Moral neutral (inercia = 0)
	ciu32.simular_tick(0.0)
	assert(ciu32.tasa_cambio_moral >= 0.0, "en superávit (>=90%) no hay penalización por escasez aunque la tasa sea negativa")

	# Caso 2: Estable (80% a 90%, 4200 / 5000 = 84%). Con tasa negativa, es neutro (0 penalización)
	com_32.cantidad = 4200.0
	com_32.tasa_neta_promedio = -10.0
	ciu32.moral = 50.0
	ciu32.simular_tick(0.0)
	assert(ciu32.tasa_cambio_moral >= -0.05, "en estado estable (80-90%) no hay penalización por escasez")

	# Caso 3: Escasez (< 80%, 2500 / 5000 = 50%) con tasa negativa (-50 u/h -> 50 h de autonomía < 72 h)
	com_32.cantidad = 2500.0
	com_32.tasa_neta_promedio = -50.0
	var urg: Dictionary = ciu32.recurso_critico_urgente()
	assert(urg["recurso"] == "comida", "debe identificar comida como recurso crítico")
	assert(is_equal_approx(urg["horas"], 50.0), "autonomía calculada correctamente: 2500 / 50 = 50 h")
	ciu32.moral = 50.0
	ciu32.simular_tick(0.0)
	assert(ciu32.tasa_cambio_moral < -0.5, "en escasez (<80%) con autonomía <72h hay penalización en la moral")

	# Caso 5: Notificación < 5% con histéresis (> 15%)
	var notificados: Array[String] = []
	ciu32.recurso_escaso_notificado.connect(func(c: String) -> void: notificados.append(c))
	ciu32.almacen["madera"].limite = 1000.0
	ciu32.almacen["madera"].cantidad = 40.0 # 4% (< 5%)
	ciu32.simular_tick(0.0)
	assert(notificados.has("madera"), "emite alerta al caer por debajo del 5%")
	notificados.clear()

	# Segundo tick al 4%: NO debe volver a emitir (histéresis activa)
	ciu32.simular_tick(0.0)
	assert(notificados.is_empty(), "no emite de nuevo mientras siga por debajo de 15%")

	# Recupera al 10% (aún <= 15%): no se rearma
	ciu32.almacen["madera"].cantidad = 100.0
	ciu32.simular_tick(0.0)
	assert(ciu32.recursos_alertados_5pct.get("madera", false), "aún no se rearma al 10%")

	# Recupera al 16% (> 15%): se rearma
	ciu32.almacen["madera"].cantidad = 160.0
	ciu32.simular_tick(0.0)
	assert(not ciu32.recursos_alertados_5pct.get("madera", false), "se rearma al superar el 15%")

	# Vuelve a caer al 3%: emite de nuevo
	ciu32.almacen["madera"].cantidad = 30.0
	ciu32.simular_tick(0.0)
	assert(notificados.has("madera"), "vuelve a emitir alerta tras haberse rearmado")

	print("\n=== TEST 31: Suelo biológico de consumo y balance metabólico ===")
	assert(Ajustes.CIUDAD_TIPOS_POBLACION["investigador"]["comida"] == 2.0, "investigador debe consumir 2.0 comida/h")
	assert(Ajustes.CIUDAD_TIPOS_POBLACION["ciudadano"]["x_cama"] == 4, "ciudadano x_cama debe ser 4")
	assert(Ajustes.CIUDAD_TIPOS_POBLACION["obrero"]["comida"] == 4.0, "obrero debe consumir 4.0 comida/h")
	assert(Ajustes.CIUDAD_TIPOS_POBLACION["tecnico"]["energia"] == 0.5, "tecnico debe consumir 0.5 energia/h")
	assert(Ajustes.CIUDAD_TIPOS_POBLACION["especialista"]["combustible"] == 1.0, "especialista debe consumir 1.0 combustible/h")
	assert(Ajustes.CIUDAD_TIPOS_POBLACION["militar"]["comida"] == 3.0, "militar base debe consumir 3.0 comida/h")

	print("\n=== TEST 32: Cascada de Consumo Estratificada de Comida ===")
	ciu32 = CiudadScript.new()
	ciu32.sub_almacen_comida = {
		"pesca": 20.0,
		"recoleccion_caza": 30.0,
		"sembradios": 50.0,
		"granjas_animales": 0.0,
		"hidroponia": 0.0,
		"sintetico": 0.0,
	}
	ciu32.almacen["comida"].cantidad = 100.0
	# Consumir 35 unidades: agota pesca (20), toma 15 de recoleccion_caza (quedan 15), sembradios intacto (50)
	var exito_32: bool = ciu32._descontar_comida_estratificada(35.0)
	assert(exito_32, "consumo estratificado debe ser exitoso")
	assert(is_equal_approx(ciu32.sub_almacen_comida["pesca"], 0.0), "pesca debe agotarse primero")
	assert(is_equal_approx(ciu32.sub_almacen_comida["recoleccion_caza"], 15.0), "recoleccion_caza debe quedar en 15.0")
	assert(is_equal_approx(ciu32.sub_almacen_comida["sembradios"], 50.0), "sembradios no debe tocarse")
	assert(is_equal_approx(ciu32.almacen["comida"].cantidad, 65.0), "stock unificado debe reflejar 65.0")

	# Review Focus 1: Si hay hambruna total, sub_almacen_comida se resetea a cero
	ciu32._descontar_comida_estratificada(100.0) # excede 65.0
	for cat in ciu32.sub_almacen_comida:
		assert(ciu32.sub_almacen_comida[cat] == 0.0, "hambruna debe limpiar sub_almacen_comida")

	# Review Focus 3: Ingreso sin categoría o categoría desconocida va a recoleccion_caza
	ciu32.ingresar_comida_estratificada(10.0, "desconocida")
	assert(is_equal_approx(ciu32.sub_almacen_comida["recoleccion_caza"], 10.0))

	# Entrega estratificada desde Economía
	var econ_test: Node = preload("res://scripts/Economia.gd").new()
	econ_test.ciudad = ciu32
	assert(econ_test.categoria_comida_de_puesto(Vector2i(-999, -999)) == "recoleccion_caza")
	econ_test.puestos[Vector2i(10, 10)] = {"tipo": "pesca_frutos_mar"}
	assert(econ_test.categoria_comida_de_puesto(Vector2i(10, 10)) == "pesca")
	econ_test.entregar({"comida": 25.0}, econ_test.categoria_comida_de_puesto(Vector2i(10, 10)))
	assert(is_equal_approx(ciu32.sub_almacen_comida["pesca"], 25.0))

	print("\n=== TEST 33: Gracia de Monocultivo (360h) y Escala de Dieta ===")
	var ciu33: Node = CiudadScript.new()
	ciu33.migracion_activa = false
	ciu33.demografia["obrero"] = 1
	ciu33.registrar_edificio_residencial(1, [2, 2])
	ciu33.sub_almacen_comida = {"recoleccion_caza": 10000.0, "pesca": 0.0, "sembradios": 0.0, "granjas_animales": 0.0, "hidroponia": 0.0, "sintetico": 0.0}
	ciu33.almacen["comida"].cantidad = 10000.0

	# 360 horas de monocultivo dentro de la gracia
	for h in range(360):
		ciu33.simular_tick(0.0)
	assert(ciu33.horas_monocultivo_continuo == 360, "debe acumular 360 horas de monocultivo")
	assert(ciu33.delta_dieta_actual() == 0.0, "dentro de la gracia de 360h no hay penalización")

	# Hora 361: se activa la penalización de monocultivo (-0.2/h)
	ciu33.simular_tick(0.0)
	assert(ciu33.horas_monocultivo_continuo == 361)
	assert(is_equal_approx(ciu33.delta_dieta_actual(), -0.2), "a partir de 361h aplica penalización de -0.2")

	# Review Focus 2: Agregar una 2da fuente resetea el contador y da bono de +0.3
	ciu33.sub_almacen_comida["pesca"] = 50.0
	ciu33.simular_tick(0.0)
	assert(ciu33.horas_monocultivo_continuo == 0, "segunda fuente resetea contador de monocultivo")
	assert(is_equal_approx(ciu33.delta_dieta_actual(), 0.3), "2 fuentes otorgan bono +0.3/h")
	ciu33.sub_almacen_comida["sembradios"] = 50.0
	ciu33.sub_almacen_comida["granjas_animales"] = 50.0
	assert(is_equal_approx(ciu33.delta_dieta_actual(), 1.0), "4 fuentes otorgan bono +1.0/h")
	ciu33.sub_almacen_comida["hidroponia"] = 50.0
	ciu33.sub_almacen_comida["sintetico"] = 50.0
	assert(is_equal_approx(ciu33.delta_dieta_actual(), 2.0), "6 fuentes otorgan bono +2.0/h")

	print("\n=== TEST 34: Suelo de Productividad Agraria ===")
	assert(is_equal_approx(CiudadScript.calcular_multiplicador_productividad(0.0, false), 0.5), "moral 0 general debe ser 0.5")
	assert(is_equal_approx(CiudadScript.calcular_multiplicador_productividad(0.0, true), 0.75), "moral 0 alimento debe tener suelo de 0.75")
	assert(is_equal_approx(CiudadScript.calcular_multiplicador_productividad(50.0, true), 1.0), "moral 50 alimento rinde 1.0")
	assert(is_equal_approx(CiudadScript.calcular_multiplicador_productividad(100.0, true), 2.0), "moral 100 alimento rinde 2.0")

	print("\n=== TEST 35: Gasto de Comida de Militares en Guarnición vs Desplegados ===")
	var ciu35: Node = CiudadScript.new()
	ciu35.migracion_activa = false
	ciu35.registrar_edificio_residencial(1, [2, 2])
	ciu35.demografia["militar"] = 2
	ciu35.almacen["comida"].cantidad = 5000.0
	# Sin militares desplegados: 2 militares * 3.0 = 6.0
	ciu35.militares_desplegados_override = 0
	var res_guarnicion = ciu35.simular_tick(0.0)
	assert(is_equal_approx(res_guarnicion["gasto_comida"], 6.0))
	# Con 1 militar desplegado: 1 * 3.0 (guarnición) + 1 * 5.0 (desplegado) = 8.0
	ciu35.militares_desplegados_override = 1
	var res_desplegado = ciu35.simular_tick(0.0)
	assert(is_equal_approx(res_desplegado["gasto_comida"], 8.0))

	print("\n=== TEST 36: Decreto Cívico de Racionamiento Estricto ===")
	var ciu36: Node = CiudadScript.new()
	ciu36.migracion_activa = false
	ciu36.registrar_edificio_residencial(1, [2, 2])
	ciu36.demografia["obrero"] = 10  # 10 * 4.0 = 40.0 comida base
	ciu36.moral = 80.0
	ciu36.almacen["comida"].cantidad = 5000.0

	ciu36.alternar_decreto_racionamiento()
	assert(ciu36.decreto_racionamiento_activo, "decreto debe estar activo")

	var res36 = ciu36.simular_tick(0.0)
	# Reducción del 35%: 40.0 * (1.0 - 0.35) = 26.0
	assert(is_equal_approx(res36["gasto_comida"], 26.0), "consumo debe reducirse un 35%")
	# Review Focus 4: Moral limitada estrictamente a 35.0 máximo
	assert(ciu36.moral <= 35.0, "moral bajo racionamiento no puede exceder 35.0")

	print("\n=== Las pruebas de Ciudad pasaron correctamente ===")


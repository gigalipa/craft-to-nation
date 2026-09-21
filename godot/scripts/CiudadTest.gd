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
	orden_test.demografia["ciudadano"] = 4  # 1.0
	orden_test.demografia["obrero"] = 4  # 1.0
	orden_test.demografia["tecnico"] = 3  # 1.0
	orden_test.demografia["militar"] = 4  # 1.33..  -> total 6.33.., sobran 2.33..
	orden_test.regular_densidad_vertical()
	assert(orden_test.demografia["desempleado"] == 0, "los desempleados se desahucian primero")
	assert(orden_test.demografia["ciudadano"] == 2, "luego los ciudadanos, solo los necesarios")
	assert(orden_test.demografia["obrero"] == 4 and orden_test.demografia["tecnico"] == 3 and orden_test.demografia["militar"] == 4)
	assert(orden_test.desahuciados == 10)

	print("\n=== TEST 14: Migración de colonos ===")
	# 14a: con vivienda, llega un desempleado cada 2 ticks (0.5 colonos/h).
	var mig: Node = CiudadScript.new()
	mig.registrar_edificio_residencial(1, [2, 2])  # 4 camas = hasta 16 desempleados
	var res_mig: Dictionary = {}
	for i in range(4):
		res_mig = mig.simular_tick(5.0)
	print("Desempleados tras 4 ticks: ", mig.demografia["desempleado"])
	assert(mig.demografia["desempleado"] == 2)
	assert(res_mig["migrantes"] == 1, "en el tick 4 llegó uno")

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
	llena.almacen["comida"].cantidad = 2000.0
	for i in range(20):
		llena.simular_tick(5.0)
	assert(llena.demografia["desempleado"] == 4)
	llena.registrar_edificio_residencial(2, [1])  # otra cama: caben 4 más
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

	print("\n=== TEST 17: la ciudad recién creada no pasa hambruna durante 10 minutos de juego ===")
	# Sin producción de comida, el stock inicial debe alcanzar para que el
	# avatar coma 10 minutos (300 ticks de 2 s) sin hambruna.
	var recien_nacida: Node = CiudadScript.new()
	recien_nacida.migracion_activa = false
	assert(recien_nacida.almacen["comida"].cantidad == recien_nacida.almacen["comida"].limite, "la comida inicial debe ser igual a su límite")
	var hubo_hambruna := false
	for i in range(300):
		if recien_nacida.simular_tick(5.0)["hambruna"]:
			hubo_hambruna = true
	print("Comida tras 300 ticks: ", recien_nacida.almacen["comida"].cantidad)
	assert(not hubo_hambruna, "no debe haber hambruna en los primeros 10 minutos")

	print("\n=== TEST 18: el almacén tiene los 8 recursos de la economía ===")
	var ocho: Node = CiudadScript.new()
	for clave in ["madera", "comida", "hierro", "tierra", "piedra", "cobre", "carbon", "tierras_raras"]:
		assert(ocho.almacen.has(clave), "falta el recurso " + clave)
	assert(ocho.almacen.size() == 8)
	assert(ocho.almacen["tierra"].cantidad == 0.0 and ocho.almacen["tierras_raras"].limite == 1000.0)
	assert(ocho.almacen["comida"].cantidad == ocho.almacen["comida"].limite, "la comida inicial es su límite")
	assert(ocho.almacen["comida"].limite > 1000.0, "el límite de comida supera el de los demás")

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

	print("\n=== Las 20 pruebas de Ciudad pasaron correctamente ===")

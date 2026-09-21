extends Node

## Pruebas aisladas de Economia.gd, sin escena: una Ciudad real instanciada
## fuera del árbol (igual que ColonosTest.gd) y una Economia nueva con esa
## ciudad inyectada. Corre esta escena y revisa que no lance ningún assert().

const EconomiaScript = preload("res://scripts/Economia.gd")
const CiudadScript = preload("res://scripts/Ciudad.gd")

const ESQ := Vector2i(10, 10)


func _ready() -> void:
	ejecutar_pruebas()


## Una Economia con un maderero (5 de cupo) en ESQ y tasa 3 madera/h.
func _nueva(ciudad: Node) -> Node:
	var economia: Node = EconomiaScript.new()
	economia.ciudad = ciudad
	economia.registrar_puesto(ESQ, "maderero", 3, 4, {"madera": 3.0})
	return economia


func ejecutar_pruebas() -> void:
	print("=== TEST 1: registrar_puesto() y huella_de() ===")
	var e1: Node = _nueva(CiudadScript.new())
	assert(e1.tiene_puesto(ESQ) and not e1.tiene_puesto(Vector2i(0, 0)))
	assert(e1.huella_de(ESQ).size() == 12 and e1.huella_de(ESQ).has(Vector2i(12, 13)))
	assert(e1.huella_de(Vector2i(0, 0)).is_empty())
	assert(e1.cupo_libre(ESQ) == 5, "el maderero admite 5 trabajadores")
	assert(e1.trabajadores_de(ESQ) == {"recolectores": 0, "acarreadores": 0, "presentes": 0})

	print("\n=== TEST 2: asignar() respeta el cupo total y no repite colonos ===")
	for id in range(1, 6):
		assert(e1.asignar(ESQ, "recolector" if id <= 3 else "acarreador", id))
	assert(e1.cupo_libre(ESQ) == 0)
	assert(not e1.asignar(ESQ, "recolector", 6), "cupo lleno")
	assert(e1.trabajadores_de(ESQ)["recolectores"] == 3 and e1.trabajadores_de(ESQ)["acarreadores"] == 2)
	e1.liberar(4)
	assert(e1.cupo_libre(ESQ) == 1)
	assert(not e1.asignar(ESQ, "recolector", 1), "un colono ya asignado no se asigna otra vez")
	assert(not e1.asignar(Vector2i(0, 0), "recolector", 9), "un puesto inexistente no admite trabajadores")
	assert(not e1.asignar(ESQ, "jardinero", 9), "rol desconocido")
	assert(e1.ultimo_de(ESQ, "recolector") == 3 and e1.ultimo_de(ESQ, "acarreador") == 5)
	assert(e1.ultimo_de(Vector2i(0, 0), "recolector") == -1)

	print("\n=== TEST 3: solo producen los recolectores PRESENTES ===")
	var e3: Node = _nueva(CiudadScript.new())
	e3.asignar(ESQ, "recolector", 1)
	e3.asignar(ESQ, "recolector", 2)
	e3.asignar(ESQ, "acarreador", 3)
	e3.simular_hora()
	assert(e3.almacen_local(ESQ).is_empty(), "nadie presente: no produce")
	e3.marcar_presente(1, true)
	e3.marcar_presente(3, true)  # un acarreador no cuenta como productor
	assert(e3.trabajadores_de(ESQ)["presentes"] == 1)
	e3.simular_hora()
	assert(is_equal_approx(e3.almacen_local(ESQ)["madera"], 3.0))
	assert(is_equal_approx(e3.produccion_por_hora(ESQ)["madera"], 3.0))
	e3.marcar_presente(2, true)
	e3.simular_hora()
	assert(is_equal_approx(e3.almacen_local(ESQ)["madera"], 9.0), "3 + 2 recolectores x 3")
	e3.marcar_presente(2, false)
	assert(e3.trabajadores_de(ESQ)["presentes"] == 1)

	print("\n=== TEST 4: el almacén local tiene tope (el de su tipo de puesto) y el exceso se pierde ===")
	var e4: Node = _nueva(CiudadScript.new())
	e4.registrar_puesto(Vector2i(50, 50), "mina", 5, 5, {"hierro": 30.0, "piedra": 10.0})
	e4.asignar(Vector2i(50, 50), "recolector", 1)
	e4.marcar_presente(1, true)
	var tope4: float = Recoleccion.capacidad_almacen_de("mina")
	for i in range(int(ceil(tope4 / 40.0)) + 2):  # 40/h de producción: se pasa del tope seguro
		e4.simular_hora()
	var local4: Dictionary = e4.almacen_local(Vector2i(50, 50))
	assert(is_equal_approx(local4["hierro"] + local4["piedra"], tope4), "nunca pasa del tope del puesto")
	assert(is_equal_approx(local4["hierro"] / local4["piedra"], 3.0), "conserva la proporción de la tasa")

	print("\n=== TEST 5: caza, frutos, pesca y algas suman en comida ===")
	var e5: Node = _nueva(CiudadScript.new())
	e5.registrar_puesto(Vector2i(60, 60), "caza_recoleccion", 4, 4, {"caza": 7.5, "recoleccion": 1.25})
	e5.asignar(Vector2i(60, 60), "recolector", 1)
	e5.marcar_presente(1, true)
	e5.simular_hora()
	var local5: Dictionary = e5.almacen_local(Vector2i(60, 60))
	assert(local5.size() == 1 and is_equal_approx(local5["comida"], 8.75))
	e5.registrar_puesto(Vector2i(70, 70), "pesca_frutos_mar", 4, 6, {"pesca": 2.5, "frutos_mar": 0.3})
	e5.asignar(Vector2i(70, 70), "recolector", 2)
	e5.marcar_presente(2, true)
	e5.simular_hora()
	assert(is_equal_approx(e5.almacen_local(Vector2i(70, 70))["comida"], 2.8))

	print("\n=== TEST 6: recoger() entrega carga completa, o el resto si ya no hay recolectores ===")
	var e6: Node = _nueva(CiudadScript.new())
	e6.asignar(ESQ, "recolector", 1)
	e6.marcar_presente(1, true)
	for i in range(3):
		e6.simular_hora()  # 9 madera
	assert(e6.recoger(ESQ, 20.0).is_empty(), "con recolectores presentes espera a tener la carga completa")
	for i in range(4):
		e6.simular_hora()  # 21 madera
	var carga6: Dictionary = e6.recoger(ESQ, 20.0)
	assert(is_equal_approx(carga6["madera"], 20.0))
	assert(is_equal_approx(e6.almacen_local(ESQ)["madera"], 1.0), "queda el resto")
	assert(e6.recoger(ESQ, 20.0).is_empty(), "queda 1 y sigue habiendo un recolector presente")
	e6.marcar_presente(1, false)
	var resto6: Dictionary = e6.recoger(ESQ, 20.0)
	assert(is_equal_approx(resto6["madera"], 1.0), "sin recolectores presentes se lleva lo que quede")
	assert(e6.almacen_local(ESQ).is_empty(), "el almacén queda vacío, sin claves en cero")
	assert(e6.recoger(ESQ, 20.0).is_empty(), "vacío: nada que llevar")
	assert(e6.recoger(Vector2i(0, 0), 20.0).is_empty(), "puesto inexistente")

	print("\n=== TEST 7: recoger() reparte la carga entre recursos sin pasarse ===")
	var e7: Node = _nueva(CiudadScript.new())
	e7.registrar_puesto(Vector2i(50, 50), "mina", 5, 5, {"hierro": 12.0, "piedra": 12.0})
	e7.asignar(Vector2i(50, 50), "recolector", 1)
	e7.marcar_presente(1, true)
	e7.simular_hora()
	e7.simular_hora()  # 24 hierro + 24 piedra = 48 en total
	var carga7: Dictionary = e7.recoger(Vector2i(50, 50), 20.0)
	var total7 := 0.0
	for v in carga7.values():
		total7 += v
	assert(is_equal_approx(total7, 20.0), "lleva exactamente la capacidad")
	var quedan7 := 0.0
	for v in e7.almacen_local(Vector2i(50, 50)).values():
		quedan7 += v
	assert(is_equal_approx(quedan7, 28.0))

	print("\n=== TEST 8: entregar() suma al stock central y respeta su límite ===")
	var ciudad8: Node = CiudadScript.new()
	var e8: Node = _nueva(ciudad8)
	var antes8: float = ciudad8.almacen["madera"].cantidad
	e8.entregar({"madera": 20.0, "tierras_raras": 4.0})
	assert(is_equal_approx(ciudad8.almacen["madera"].cantidad, antes8 + 20.0))
	assert(is_equal_approx(ciudad8.almacen["tierras_raras"].cantidad, 4.0))
	e8.entregar({"madera": 5000.0})
	assert(ciudad8.almacen["madera"].cantidad == ciudad8.almacen["madera"].limite, "lo que no cabe se pierde")

	print("\n=== TEST 9: quitar_puesto() libera a los trabajadores y avisa ===")
	var e9: Node = _nueva(CiudadScript.new())
	e9.asignar(ESQ, "recolector", 1)
	e9.asignar(ESQ, "acarreador", 2)
	var avisados := []
	e9.puesto_quitado.connect(func(ids: Array) -> void: avisados.append_array(ids))
	e9.quitar_puesto(ESQ)
	assert(not e9.tiene_puesto(ESQ))
	assert(avisados.size() == 2 and avisados.has(1) and avisados.has(2))
	assert(e9.asignar(Vector2i(0, 0), "recolector", 1) == false)
	e9.registrar_puesto(ESQ, "maderero", 3, 4, {"madera": 3.0})
	assert(e9.asignar(ESQ, "recolector", 1), "los colonos liberados quedan libres para otro puesto")
	e9.quitar_puesto(Vector2i(0, 0))  # inexistente: no hace nada

	print("\n=== TEST 10: simular_hora() se dispara con Ciudad.tick_simulado ===")
	var ciudad10: Node = CiudadScript.new()
	ciudad10.migracion_activa = false
	var e10: Node = _nueva(ciudad10)
	e10._ready()  # conecta el tick (fuera del árbol no se llama solo)
	e10.asignar(ESQ, "recolector", 1)
	e10.marcar_presente(1, true)
	ciudad10.simular_tick(0.0)
	assert(is_equal_approx(e10.almacen_local(ESQ)["madera"], 3.0))

	print("\n=== Las 10 pruebas de Economia pasaron correctamente ===")

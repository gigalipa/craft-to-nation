extends Node

## Pruebas aisladas de Obras.gd (autoload): un mundo falso con obras de pocas
## celdas, una Ciudad real instanciada fuera del árbol y una zona falsa. Las
## funciones de fin de obra (al_completar/al_deconstruir/al_retirar) se
## sustituyen por registradores, así que no tocan los autoloads reales.

const ObrasScript = preload("res://scripts/Obras.gd")
const CiudadScript = preload("res://scripts/Ciudad.gd")
const FinalizacionObras = preload("res://scripts/FinalizacionObras.gd")
const ConstructorViasScript = preload("res://scripts/ConstructorVias.gd")



class MundoObraFalso extends RefCounted:
	var edificio_orden: Dictionary = {}
	var edificio_progreso: Dictionary = {}
	var edificio_a_celdas: Dictionary = {}
	var edificio_metadata: Dictionary = {}
	var edificio_tipos: Dictionary = {}  # id -> {celda -> tipo final}
	var resultados_surtir: Array = []  # se consumen en orden
	var resultados_deconstruir: Array = []
	var eliminados: Array = []

	## Un edificio de "celdas" celdas en fila a lo largo de x desde "origen", con "progreso" celdas hechas.
	func agregar(id: int, origen: Vector3i, celdas: int, progreso: int) -> void:
		var lista: Array[Vector3i] = []
		for i in range(celdas):
			lista.append(origen + Vector3i(i, 0, 0))
		edificio_orden[id] = lista
		edificio_a_celdas[id] = lista
		edificio_progreso[id] = progreso
		edificio_metadata[id] = {}
		edificio_tipos[id] = {}
		for celda in lista:
			edificio_tipos[id][celda] = "bloque_piedra"

	func surtir_construccion(_celda: Vector3i) -> Dictionary:
		return resultados_surtir.pop_front() if not resultados_surtir.is_empty() else {}

	func procesar_deconstruccion(_celda: Vector3i) -> Dictionary:
		return resultados_deconstruir.pop_front() if not resultados_deconstruir.is_empty() else {}

	func proximo_paso_pendiente(_celda: Vector3i) -> Dictionary:
		return {}

	func eliminar_edificio(id: int) -> Vector2i:
		eliminados.append(id)
		edificio_orden.erase(id)
		edificio_a_celdas.erase(id)
		edificio_progreso.erase(id)
		edificio_metadata.erase(id)
		return Vector2i.ZERO

	var celdas_mundo: Dictionary = {}
	var colocado_por_jugador: Dictionary = {}
	var _ids: Dictionary = {"tierra": 1, "cuna_recta": 2, "cuna_esquina": 3}

	func altura_en(_x: int, _z: int) -> int:
		return 0

	func obtener_tipo(celda: Vector3i) -> String:
		return celdas_mundo.get(celda, "")

	func talar_bloque_de_arbol(_celda: Vector3i, _dano: int) -> void:
		pass

	func eliminar_follaje(_celda: Vector3i) -> void:
		pass

	func colocar_bloque(celda: Vector3i, tipo: String, _por_jugador: bool) -> void:
		celdas_mundo[celda] = tipo

	func set_cell_item(celda: Vector3i, id: int, _orientacion: int = 0) -> void:
		if id == -1:
			celdas_mundo.erase(celda)
		else:
			for k in _ids:
				if _ids[k] == id:
					celdas_mundo[celda] = k

	func id_de_tipo(tipo: String) -> int:
		return _ids.get(tipo, 1)



## Zona falsa: solo la celda (0, 0) es del núcleo urbano.
class ZonaFalsa extends RefCounted:
	var nucleo := Vector2i(0, 0)

	func celda_es_del_nucleo(celda: Vector2i) -> bool:
		return celda == nucleo


class ColonosMock extends RefCounted:
	var conteos: Dictionary = {}

	func obreros_en(id: int) -> int:
		return conteos.get(id, 0)


func _ready() -> void:
	ejecutar_pruebas()


func _nuevas(mundo: MundoObraFalso, ciudad: Node = null) -> Node:
	var obras: Node = ObrasScript.new()
	obras.mundo = mundo
	obras.ciudad = ciudad if ciudad != null else CiudadScript.new()
	obras.zona = ZonaFalsa.new()
	obras.al_completar = func(_m: Object, _meta: Dictionary) -> String: return "listo"
	obras.al_deconstruir = func(_m: Object, _r: Dictionary) -> void: pass
	obras.al_retirar = func(_m: Object, _id: int) -> void: pass
	return obras


func ejecutar_pruebas() -> void:
	print("=== TEST 1: siguiente_tarea elige la obra pendiente más cercana y prefiere construir a demoler ===")
	var mundo1 := MundoObraFalso.new()
	mundo1.agregar(1, Vector3i(10, 0, 10), 3, 1)  # lejos
	mundo1.agregar(2, Vector3i(3, 0, 3), 3, 0)  # cerca
	mundo1.agregar(3, Vector3i(4, 0, 4), 3, 3)  # completo
	var obras1: Node = _nuevas(mundo1)
	var t1: Dictionary = obras1.siguiente_tarea(Vector3i(2, 1, 2))
	assert(t1 == {"tipo": "construir", "id": 2}, "la obra pendiente más cercana: %s" % str(t1))
	assert(obras1.siguiente_tarea(Vector3i(11, 1, 11)) == {"tipo": "construir", "id": 1}, "desde el otro lado, la otra")
	assert(obras1.alternar_marca(3) == "", "se puede marcar el edificio completo")
	assert(obras1.siguiente_tarea(Vector3i(2, 1, 2))["id"] == 2, "con construcción pendiente se prefiere construir aunque haya una demolición más cerca")
	mundo1.edificio_progreso[1] = 3
	mundo1.edificio_progreso[2] = 3
	assert(obras1.siguiente_tarea(Vector3i(2, 1, 2)) == {"tipo": "demoler", "id": 3}, "sin nada que construir, demoler lo marcado")
	assert(ObrasScript.new().siguiente_tarea(Vector3i.ZERO).is_empty(), "sin mundo no hay tarea")

	print("\n=== TEST 2: marcar y desmarcar alternan, el núcleo se rechaza, y desmarcar a medias no reconstruye ===")
	var mundo2 := MundoObraFalso.new()
	mundo2.agregar(1, Vector3i(5, 0, 5), 4, 4)
	mundo2.agregar(2, Vector3i(0, 0, 0), 4, 4)  # contiene la celda (0, 0): el núcleo
	var obras2: Node = _nuevas(mundo2)
	var cambios2: Array = []
	obras2.marca_cambiada.connect(func(id: int, marcado: bool) -> void: cambios2.append([id, marcado]))
	assert(obras2.alternar_marca(2) != "", "el núcleo urbano se rechaza con un motivo")
	assert(not obras2.esta_marcado(2) and cambios2.is_empty(), "y no queda marcado")
	assert(obras2.alternar_marca(99) != "", "un id que no es un edificio se rechaza")
	assert(obras2.alternar_marca(1) == "" and obras2.esta_marcado(1), "marcar")
	mundo2.resultados_deconstruir = [{"id": 1, "completa_reversion": false, "lista_para_remocion": false, "total_camas": 0}]
	obras2.trabajar(1, "demoler")  # los colonos demuelen una celda
	mundo2.edificio_progreso[1] = 2  # y ya llevan la mitad
	assert(obras2.alternar_marca(1) == "" and not obras2.esta_marcado(1), "desmarcar")
	assert(cambios2 == [[1, true], [1, false]], "cada cambio emite la señal: %s" % str(cambios2))
	assert(obras2.siguiente_tarea(Vector3i(6, 1, 6)).is_empty(), "un edificio desmarcado tras empezar a demolerse queda abandonado: los colonos no lo reconstruyen")
	obras2.abandonar(1)
	mundo2.edificio_progreso[1] = 4
	assert(obras2.siguiente_tarea(Vector3i(6, 1, 6)).is_empty(), "completo no tiene trabajo")

	print("\n=== TEST 3: Player deconstruyendo a mano abandona la obra; olvidar la limpia ===")
	var mundo3 := MundoObraFalso.new()
	mundo3.agregar(1, Vector3i(5, 0, 5), 4, 2)
	var obras3: Node = _nuevas(mundo3)
	assert(obras3.siguiente_tarea(Vector3i(5, 1, 5))["id"] == 1, "obra pendiente")
	obras3.abandonar(1)
	assert(obras3.siguiente_tarea(Vector3i(5, 1, 5)).is_empty(), "abandonada: ya no se ofrece")
	obras3.olvidar(1)
	assert(obras3.siguiente_tarea(Vector3i(5, 1, 5))["id"] == 1, "olvidar la quita de abandonadas (un edificio nuevo con ese id vuelve a ser candidato)")

	print("\n=== TEST 4: una obra sin material se pausa, se avisa una vez y vuelve cuando hay el recurso ===")
	var mundo4 := MundoObraFalso.new()
	mundo4.agregar(1, Vector3i(5, 0, 5), 4, 0)
	var ciudad4: Node = CiudadScript.new()
	ciudad4.almacen["piedra"].cantidad = 0.0
	var obras4: Node = _nuevas(mundo4, ciudad4)
	var avisos4: Array = []
	obras4.aviso.connect(func(texto: String) -> void: avisos4.append(texto))
	mundo4.resultados_surtir = [{"insuficiente": true, "recurso": "piedra", "tipo": "bloque_piedra"}, {"insuficiente": true, "recurso": "piedra", "tipo": "bloque_piedra"}]
	var r4: Dictionary = obras4.trabajar(1, "construir")
	assert(r4["estado"] == "pausada", "sin material: pausada")
	assert(obras4.siguiente_tarea(Vector3i(5, 1, 5)).is_empty(), "una obra pausada no se ofrece mientras falte el recurso")
	obras4.trabajar(1, "construir")
	assert(avisos4.size() == 1, "el aviso sale una sola vez por obra y recurso: %d" % avisos4.size())
	ciudad4.almacen["piedra"].cantidad = 50.0
	assert(obras4.siguiente_tarea(Vector3i(5, 1, 5))["id"] == 1, "con el recurso de nuevo, se ofrece")
	mundo4.resultados_surtir = [{"completa": false, "metadata": {}}]
	assert(obras4.trabajar(1, "construir")["estado"] == "avanzo" and not obras4.pausadas.has(1), "al avanzar deja de estar pausada")

	print("\n=== TEST 5: trabajar construye paso a paso, completa con aviso y reporta bloqueos o fin ===")
	var mundo5 := MundoObraFalso.new()
	mundo5.agregar(1, Vector3i(5, 0, 5), 4, 0)
	var obras5: Node = _nuevas(mundo5)
	var avisos5: Array = []
	obras5.aviso.connect(func(texto: String) -> void: avisos5.append(texto))
	mundo5.resultados_surtir = [{"completa": false, "metadata": {}}, {"bloqueada": true, "id": 1}, {"completa": true, "metadata": {}}, {}]
	var avance5: Dictionary = obras5.trabajar(1, "construir")
	assert(avance5["estado"] == "avanzo" and is_equal_approx(avance5["espera"], FinalizacionObras.INTERVALO_PASO), "avanzar espera el intervalo del paso")
	assert(obras5.trabajar(1, "construir")["estado"] == "bloqueada", "con ocupantes dentro, bloqueada")
	assert(obras5.trabajar(1, "construir")["estado"] == "completa" and avisos5 == ["listo"], "al completar se ejecuta al_completar y se avisa")
	assert(obras5.trabajar(1, "construir")["estado"] == "terminada", "sin nada que surtir, terminada")
	assert(obras5.trabajar(77, "construir")["estado"] == "invalida", "una obra que ya no existe es inválida, sin error")

	print("\n=== TEST 6: demoler revierte celda a celda y, al quedar vacío, retira el edificio y lo desmarca ===")
	var mundo6 := MundoObraFalso.new()
	mundo6.agregar(1, Vector3i(5, 0, 5), 2, 2)
	var obras6: Node = _nuevas(mundo6)
	var retirados6: Array = []
	obras6.al_retirar = func(_m: Object, id: int) -> void: retirados6.append(id)
	obras6.alternar_marca(1)
	mundo6.resultados_deconstruir = [
		{"id": 1, "completa_reversion": false, "lista_para_remocion": false, "total_camas": 0},
		{"id": 1, "completa_reversion": true, "lista_para_remocion": true, "total_camas": 0},
	]
	assert(obras6.trabajar(1, "demoler")["estado"] == "avanzo", "revierte una celda")
	assert(obras6.esta_marcado(1) and retirados6.is_empty(), "sigue marcado y en pie")
	assert(obras6.trabajar(1, "demoler")["estado"] == "completa" and retirados6 == [1], "al quedar vacío se retira")
	assert(not obras6.esta_marcado(1), "y deja de estar marcado")
	assert(obras6.trabajar(1, "demoler")["estado"] == "invalida", "ya no existe: inválida")

	print("\n=== TEST 7: un colono vetado no recibe esa obra; huella_de devuelve las columnas del edificio ===")
	var mundo7 := MundoObraFalso.new()
	mundo7.agregar(1, Vector3i(5, 0, 5), 3, 0)
	var obras7: Node = _nuevas(mundo7)
	obras7.vetar(1, 42)
	assert(obras7.siguiente_tarea(Vector3i(5, 1, 5), 42).is_empty(), "vetada para el colono 42")
	assert(obras7.siguiente_tarea(Vector3i(5, 1, 5), 43)["id"] == 1, "no para otro")
	assert(obras7.huella_de(1) == [Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5)], "huella: una entrada por columna")
	assert(obras7.huella_de(9).is_empty(), "un id desconocido no tiene huella")

	print("\n=== TEST 8: el jugador tiene preferencia (reclamo con caducidad) y puede pausar cualquier obra ===")
	var mundo8 := MundoObraFalso.new()
	mundo8.agregar(1, Vector3i(5, 0, 5), 3, 0)
	mundo8.agregar(2, Vector3i(8, 0, 8), 2, 2)
	var obras8: Node = _nuevas(mundo8)
	obras8.alternar_marca(2)
	obras8.reclamar(1)
	assert(obras8.esta_reclamada(1), "recién reclamada")
	assert(obras8.siguiente_tarea(Vector3i(5, 1, 5))["id"] == 2, "mientras el jugador la tiene, los colonos toman otra tarea (aquí, la demolición)")
	assert(obras8.trabajar(1, "construir")["estado"] == "pausada", "y quien ya estaba en ella la cede")
	obras8._reclamos[1] = 0  # caducó
	assert(not obras8.esta_reclamada(1), "el reclamo caduca")
	assert(obras8.siguiente_tarea(Vector3i(5, 1, 5))["id"] == 1, "al caducar vuelve a ofrecerse")
	obras8.alternar_pausa(1)
	assert(obras8.esta_pausada_por_jugador(1) and obras8.siguiente_tarea(Vector3i(5, 1, 5))["id"] == 2, "una obra pausada no se ofrece")
	assert(obras8.trabajar(1, "construir")["estado"] == "pausada", "ni se trabaja")
	obras8.alternar_pausa(2)
	assert(obras8.siguiente_tarea(Vector3i(5, 1, 5)).is_empty(), "también se puede pausar una demolición")
	obras8.alternar_pausa(1)
	obras8.alternar_pausa(2)
	assert(obras8.siguiente_tarea(Vector3i(5, 1, 5))["id"] == 1, "reanudar la devuelve")
	obras8.olvidar(1)
	assert(not obras8.esta_pausada_por_jugador(1) and not obras8.esta_reclamada(1), "olvidar limpia la pausa y el reclamo")

	print("\n=== TEST 9: resumen_de da el estado, la salud y los materiales que faltan; id_en_columna encuentra el edificio ===")
	var mundo9 := MundoObraFalso.new()
	mundo9.agregar(1, Vector3i(5, 0, 5), 4, 1)  # 3 celdas por hacer, 5 de piedra cada una
	mundo9.agregar(2, Vector3i(9, 0, 9), 2, 2)  # completo
	var obras9: Node = _nuevas(mundo9)
	var res9: Dictionary = obras9.resumen_de(1)
	assert(res9["estado"] == "construccion" and not res9["pausada"], "en construcción")
	assert(is_equal_approx(res9["salud"], 0.25), "salud = fracción construida: %f" % res9["salud"])
	assert(res9["faltantes"] == {"piedra": 15}, "faltan 3 celdas x 5 de piedra: %s" % str(res9["faltantes"]))
	assert(res9["nombre"] == "Edificio 1" and res9["tipo"] == "Edificio", "sin metadata, nombre genérico")
	var res9b: Dictionary = obras9.resumen_de(2)
	assert(res9b["estado"] == "completo" and is_equal_approx(res9b["salud"], 1.0) and res9b["faltantes"].is_empty(), "un edificio completo: 100 % y nada que falte")
	obras9.alternar_marca(2)
	obras9.alternar_pausa(2)
	assert(obras9.resumen_de(2)["estado"] == "demolicion" and obras9.resumen_de(2)["pausada"], "marcado: demolición; y se refleja la pausa")
	mundo9.edificio_metadata[1] = {"blueprint": {"nombre": "Casa", "categoria": "residencial"}}
	assert(obras9.resumen_de(1)["nombre"] == "Casa" and obras9.resumen_de(1)["tipo"] == "Residencial", "nombre y tipo del blueprint")
	assert(obras9.resumen_de(99).is_empty(), "un id desconocido no tiene resumen")
	assert(obras9.id_en_columna(Vector2i(6, 5)) == 1 and obras9.id_en_columna(Vector2i(0, 0)) == -1, "id_en_columna")

	print("\n=== TEST 10: celdas_de devuelve las celdas del edificio ===")
	var mundo10 := MundoObraFalso.new()
	mundo10.agregar(1, Vector3i(5, 0, 5), 2, 0)
	var obras10: Node = _nuevas(mundo10)
	assert(obras10.celdas_de(1) == [Vector3i(5, 0, 5), Vector3i(6, 0, 5)] and obras10.celdas_de(9).is_empty())

	print("\n=== TEST 11: lo que cambia durante el trabajo (cancelar, marcar, núcleo, recurso insuficiente, desmarcar sin demoler) ===")
	# Cancelar una demolición en curso detiene a quien ya está demoliendo.
	var mundo11 := MundoObraFalso.new()
	mundo11.agregar(1, Vector3i(5, 0, 5), 4, 4)
	var obras11: Node = _nuevas(mundo11)
	obras11.alternar_marca(1)
	mundo11.resultados_deconstruir = [
		{"id": 1, "completa_reversion": false, "lista_para_remocion": false, "total_camas": 0},
		{"id": 1, "completa_reversion": false, "lista_para_remocion": false, "total_camas": 0},
	]
	assert(obras11.trabajar(1, "demoler")["estado"] == "avanzo", "empieza a demoler")
	obras11.alternar_marca(1)  # el jugador cancela
	assert(obras11.trabajar(1, "demoler")["estado"] == "invalida", "tras cancelar, quien demolía suelta la tarea")
	assert(mundo11.resultados_deconstruir.size() == 1, "y no se revierte ni una celda más")
	# Marcar una obra en construcción saca a los constructores.
	var mundo11b := MundoObraFalso.new()
	mundo11b.agregar(1, Vector3i(5, 0, 5), 4, 1)
	var obras11b: Node = _nuevas(mundo11b)
	mundo11b.resultados_surtir = [{"completa": false, "metadata": {}}]
	obras11b.alternar_marca(1)
	assert(obras11b.trabajar(1, "construir")["estado"] == "invalida", "una obra marcada ya no se construye")
	assert(mundo11b.resultados_surtir.size() == 1, "y no se surte ninguna celda")
	# Si lo marcado pasa a ser el núcleo urbano, los demoledores lo dejan.
	var mundo11c := MundoObraFalso.new()
	mundo11c.agregar(1, Vector3i(5, 0, 5), 4, 4)
	var obras11c: Node = _nuevas(mundo11c)
	obras11c.alternar_marca(1)
	obras11c.zona.nucleo = Vector2i(6, 5)  # se declara núcleo después de marcarlo
	mundo11c.resultados_deconstruir = [{"id": 1, "completa_reversion": false, "lista_para_remocion": false, "total_camas": 0}]
	assert(obras11c.trabajar(1, "demoler")["estado"] == "invalida", "el núcleo no se demuele aunque estuviera marcado")
	assert(not obras11c.esta_marcado(1) and mundo11c.resultados_deconstruir.size() == 1, "y deja de estar marcado sin tocarlo")
	assert(obras11c.siguiente_tarea(Vector3i(5, 1, 5)).is_empty(), "ni se ofrece")
	# Con recurso insuficiente para el paso, la obra sigue pausada aunque haya algo.
	var mundo11d := MundoObraFalso.new()
	mundo11d.agregar(1, Vector3i(5, 0, 5), 4, 0)
	var ciudad11d: Node = CiudadScript.new()
	ciudad11d.almacen["piedra"].cantidad = 0.0
	var obras11d: Node = _nuevas(mundo11d, ciudad11d)
	mundo11d.resultados_surtir = [{"insuficiente": true, "recurso": "piedra", "tipo": "bloque_piedra"}]
	obras11d.trabajar(1, "construir")
	ciudad11d.almacen["piedra"].cantidad = 3.0  # un bloque de piedra cuesta 5
	assert(obras11d.siguiente_tarea(Vector3i(5, 1, 5)).is_empty(), "con 3 de piedra no alcanza para un paso de 5: sigue pausada")
	ciudad11d.almacen["piedra"].cantidad = 5.0
	assert(obras11d.siguiente_tarea(Vector3i(5, 1, 5))["id"] == 1, "con 5 sí se ofrece")
	# Marcar y desmarcar sin que nadie demoliera no abandona la obra.
	var mundo11e := MundoObraFalso.new()
	mundo11e.agregar(1, Vector3i(5, 0, 5), 20, 3)
	var obras11e: Node = _nuevas(mundo11e)
	obras11e.alternar_marca(1)
	obras11e.alternar_marca(1)
	assert(obras11e.siguiente_tarea(Vector3i(5, 1, 5))["id"] == 1, "una obra marcada por error y desmarcada se sigue construyendo")
	# Una obra abandonada se puede devolver a los colonos con «Reanudar».
	obras11e.abandonar(1)
	assert(obras11e.resumen_de(1)["pausada"], "abandonada se muestra como pausada")
	assert(obras11e.siguiente_tarea(Vector3i(5, 1, 5)).is_empty(), "y no se ofrece")
	obras11e.alternar_pausa(1)
	assert(not obras11e.resumen_de(1)["pausada"] and obras11e.siguiente_tarea(Vector3i(5, 1, 5))["id"] == 1, "Reanudar la devuelve a los colonos")

	print("\n=== TEST 12: tope de cuadrilla a 4 obreros y demolición programada con espera de 5 horas ===")
	var mundo12 := MundoObraFalso.new()
	mundo12.agregar(1, Vector3i(5, 0, 5), 20, 5)
	var obras12: Node = _nuevas(mundo12)

	# Mock colonos con tope de cuadrilla
	var col_mock := ColonosMock.new()
	obras12.colonos = col_mock

	col_mock.conteos[1] = 4
	assert(obras12.siguiente_tarea(Vector3i(5, 1, 5)).is_empty(), "con 4 obreros asignados la obra no se ofrece a otro colono")
	col_mock.conteos[1] = 3
	assert(obras12.siguiente_tarea(Vector3i(5, 1, 5))["id"] == 1, "con 3 obreros sí se ofrece")

	# Demolición programada
	assert(obras12.programar_demolicion(1, 5) == "")
	assert(obras12.esta_programada(1) and not obras12.esta_marcado(1))
	assert(obras12.horas_programadas(1) == 5)
	assert(obras12.resumen_de(1)["estado"] == "demolicion_programada")
	assert(obras12.resumen_de(1)["horas_demolicion"] == 5)

	# Durante la espera no se ofrece para demoler
	mundo12.edificio_progreso[1] = 20  # construcción terminada
	assert(obras12.siguiente_tarea(Vector3i(5, 1, 5)).is_empty(), "durante la espera de demolición no se ofrece demoler")

	# Simulamos 4 horas
	for _i in range(4):
		obras12.simular_hora()
	assert(obras12.horas_programadas(1) == 1 and not obras12.esta_marcado(1))

	# A la 5ª hora se marca para demoler
	obras12.simular_hora()
	assert(not obras12.esta_programada(1) and obras12.esta_marcado(1))
	assert(obras12.resumen_de(1)["estado"] == "demolicion")
	assert(obras12.siguiente_tarea(Vector3i(5, 1, 5)) == {"tipo": "demoler", "id": 1}, "al cumplirse las 5 h se ofrece demoler")

	# Cancelar demolición
	obras12.cancelar_demolicion(1)
	assert(not obras12.esta_marcado(1))

	# Cancelar durante la espera
	obras12.programar_demolicion(1, 5)
	assert(obras12.esta_programada(1))
	obras12.cancelar_demolicion(1)
	assert(not obras12.esta_programada(1))

	print("\n=== TEST 13: prioridades de obras (Alta, Normal, Baja) y jerarquía de asignación ===")
	var mundo13 := MundoObraFalso.new()
	mundo13.agregar(1, Vector3i(10, 0, 10), 5, 0)  # lejos
	mundo13.agregar(2, Vector3i(3, 0, 3), 5, 0)   # cerca
	mundo13.agregar(3, Vector3i(4, 0, 4), 5, 5)   # para demoler
	var obras13: Node = _nuevas(mundo13)

	# Constantes y valores por defecto
	assert(obras13.PRIORIDAD_ALTA == 2 and obras13.PRIORIDAD_NORMAL == 1 and obras13.PRIORIDAD_BAJA == 0)
	assert(obras13.prioridad_de(1) == obras13.PRIORIDAD_NORMAL, "prioridad por defecto es Normal")
	assert(obras13.prioridad_de(2) == obras13.PRIORIDAD_NORMAL)

	# Ambas en Normal: elige la más cercana (2)
	assert(obras13.siguiente_tarea(Vector3i(2, 1, 2)) == {"tipo": "construir", "id": 2})

	# Si la lejana (1) pasa a Alta, se prefiere 1 sobre la cercana en Normal (2)
	obras13.fijar_prioridad(1, obras13.PRIORIDAD_ALTA)
	assert(obras13.prioridad_de(1) == obras13.PRIORIDAD_ALTA)
	assert(obras13.siguiente_tarea(Vector3i(2, 1, 2)) == {"tipo": "construir", "id": 1})

	# Marcamos edificio 3 para demoler
	assert(obras13.alternar_marca(3) == "")
	# Alta (1) le gana a Demolición (3)
	assert(obras13.siguiente_tarea(Vector3i(2, 1, 2)) == {"tipo": "construir", "id": 1})

	# Si 1 pasa a Normal, Normal (1 y 2) le gana a Demolición (3)
	obras13.fijar_prioridad(1, obras13.PRIORIDAD_NORMAL)
	assert(obras13.siguiente_tarea(Vector3i(2, 1, 2))["tipo"] == "construir")

	# Si ambas en construcción pasan a Baja (0), Demolición (3) le gana a Baja
	obras13.fijar_prioridad(1, obras13.PRIORIDAD_BAJA)
	obras13.fijar_prioridad(2, obras13.PRIORIDAD_BAJA)
	assert(obras13.siguiente_tarea(Vector3i(2, 1, 2)) == {"tipo": "demoler", "id": 3})

	# Al olvidar la obra, se limpia la prioridad
	obras13.olvidar(1)
	assert(obras13.prioridad_de(1) == obras13.PRIORIDAD_NORMAL)
	print("\n=== TEST 14: obras de vías (creación, asignación, fusión y ejecución paso a paso) ===")
	Vias.celdas.clear()
	Vias._columnas.clear()
	Vias.notches.clear()

	var mundo14 := MundoObraFalso.new()
	# Edificio 1 con prioridad Baja (0)
	mundo14.agregar(1, Vector3i(10, 0, 10), 3, 0)
	var obras14: Node = _nuevas(mundo14)
	obras14.fijar_prioridad(1, obras14.PRIORIDAD_BAJA)

	# Planificar tramo de vía
	var sin_choque := func(_cols): return false
	var vertices1: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	var plan1: Dictionary = ConstructorViasScript.planificar(mundo14, vertices1, sin_choque)
	assert(not plan1.is_empty())

	# Crear obra de vía
	var id_via1: int = obras14.crear_obra_via(plan1)
	assert(id_via1 < 0, "las obras de vías tienen ID negativo")
	assert(obras14.hay_obras_pendientes())
	assert(obras14.huella_de(id_via1).size() > 0)
	assert(obras14.celdas_de(id_via1).size() == plan1["pasos"].size())

	# Jerarquía: Vías están sobre edificios de prioridad Baja (0)
	var tarea_libre: Dictionary = obras14.siguiente_tarea(Vector3i(0, 1, 0))
	assert(tarea_libre == {"tipo": "via_construir", "id": id_via1}, "Vías tienen preferencia sobre edificios de prioridad Baja")

	# Si edificio 1 sube a Normal (1), el edificio le gana al tendido de vía
	obras14.fijar_prioridad(1, obras14.PRIORIDAD_NORMAL)
	assert(obras14.siguiente_tarea(Vector3i(0, 1, 0)) == {"tipo": "construir", "id": 1}, "Edificios Normal ganan a vías")
	obras14.fijar_prioridad(1, obras14.PRIORIDAD_BAJA)

	# Fusión de tramos contiguos: trazar un tramo que comparte vértices se fusiona en id_via1
	var vertices2: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0)]
	var plan2: Dictionary = ConstructorViasScript.planificar(mundo14, vertices2, sin_choque)
	var pasos_antes: int = obras14.obras_vias[id_via1]["pasos"].size()
	var id_via2: int = obras14.crear_obra_via(plan2)
	assert(id_via2 == id_via1, "Tramos conectados se fusionan bajo la misma obra")
	assert(obras14.obras_vias[id_via1]["pasos"].size() > pasos_antes)

	# Ejecutar pasos con trabajar()
	var pasos_totales: int = obras14.obras_vias[id_via1]["pasos"].size()
	for i in range(pasos_totales - 1):
		var r: Dictionary = obras14.trabajar(id_via1, "via_construir")
		assert(r["estado"] == "avanzo")
	# Último paso completa la obra
	var r_final: Dictionary = obras14.trabajar(id_via1, "via_construir")
	assert(r_final["estado"] == "completa")
	assert(not obras14.obras_vias.has(id_via1), "la obra completada se limpia")
	assert(Vias.celdas.size() > 0, "todas las celdas quedaron registradas en Vias")

	# Demolición de vías
	var celda_demoler: Vector3i = Vias.celdas.keys()[0]
	var id_dem_via: int = obras14.crear_demolicion_via([celda_demoler])
	assert(id_dem_via < 0)
	# Demoliciones le ganan a obras viales y a edificios Baja
	assert(obras14.siguiente_tarea(Vector3i(0, 1, 0)) == {"tipo": "via_demoler", "id": id_dem_via})
	var r_dem: Dictionary = obras14.trabajar(id_dem_via, "via_demoler")
	# Reclamar una obra de vía cede el turno frente a colonos pero permite el trabajo manual
	var plan3: Dictionary = ConstructorViasScript.planificar(mundo14, vertices1, sin_choque)
	var id_via3: int = obras14.crear_obra_via(plan3)
	obras14.reclamar(id_via3)
	assert(obras14.esta_reclamada(id_via3))
	# Los colonos ven la obra cedida y esperan
	var r_colono: Dictionary = obras14.trabajar(id_via3, "via_construir")
	assert(r_colono["estado"] == "pausada", "Colonos no tocan obra reclamada por el jugador")
	# El jugador trabaja manualmente sin ser bloqueado
	var r_manual: Dictionary = obras14.trabajar_via(id_via3)
	assert(r_manual["estado"] == "avanzo" or r_manual["estado"] == "completa", "El trabajo manual del jugador no se bloquea a sí mismo")

	print("\n=== Las 14 pruebas de Obras pasaron correctamente ===")


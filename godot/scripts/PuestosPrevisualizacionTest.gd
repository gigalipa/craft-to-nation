extends Node

## Pruebas de la evaluación única de la colocación de un puesto
## (CamaraCenital._evaluar_puesto() / _mensaje_rechazo_puesto()): es lo que usan
## a la vez el clic y la previsualización, así que la vista previa no puede
## mentir. Mundo plano real sin _ready() y una CamaraCenital sin árbol (mismo
## patrón que PlantillasPuestoTest.gd). Corre esta escena y revisa el panel
## "Output": debe imprimir todas las pruebas y no lanzar ningún error de assert().

const VoxelWorld = preload("res://scripts/VoxelWorld.gd")
const CamaraCenitalScript = preload("res://scripts/CamaraCenital.gd")
const PlantillasPuesto = preload("res://scripts/PlantillasPuesto.gd")
const NiveladorTerreno = preload("res://scripts/NiveladorTerreno.gd")
const NivelacionOverlayScript = preload("res://scripts/NivelacionOverlay.gd")
const HUDScript = preload("res://scripts/HUD.gd")
const PlayerScript = preload("res://scripts/Player.gd")
const GeneradorArbolScript = preload("res://scripts/GeneradorArbol.gd")

const LADO := 40  # el suelo plano cubre x, z en [0, LADO)


func _ready() -> void:
	ejecutar_pruebas()


## Mundo de prueba: suelo de "tierra" a y=0 (altura 0) en LADO x LADO columnas.
func _mundo_plano() -> Node:
	var mundo: Node = VoxelWorld.new()
	mundo.mesh_library = load("res://assets/BlockLibrary.res")
	mundo.cell_size = Vector3.ONE
	mundo._indexar_biblioteca()
	mundo.arboles = GeneradorArbolScript.new()
	for x in range(LADO):
		for z in range(LADO):
			mundo.colocar_bloque(Vector3i(x, 0, z), "tierra")
	return mundo


## CamaraCenital sin árbol, con el puesto "tipo" activo (huella y giro base).
func _camara(mundo: Node, tipo: String, giros: int = 0) -> Camera3D:
	var camara: Camera3D = CamaraCenitalScript.new()
	camara.mundo = mundo
	camara.nivelador_puesto = NiveladorTerreno.new(CamaraCenitalScript._AlturaSinAgua.new(mundo))
	var huella: Vector2i = PlantillasPuesto.huella(tipo, giros)
	camara._tipo_puesto_activo = tipo
	camara._ancho_puesto_activo = huella.x
	camara._alto_puesto_activo = huella.y
	camara._giros_puesto = giros
	return camara


## Cada caja del fantasma está en la celda real de un bloque de la plantilla, y su
## color es el "esperado" (o el destacado propio de puertas y ventanas si es válida).
func _verificar_fantasma(camara: Camera3D, mundo: Node, esquina: Vector2i, ev: Dictionary, color: Color, valida: bool) -> void:
	assert(camara._huella_blueprint.size() == ev["celdas_plantilla"].size(), "una caja por bloque de la plantilla")
	for i in range(camara._huella_blueprint.size()):
		var rel: Vector3i = camara._offsets_huella_blueprint[i]
		var real := Vector3i(esquina.x + rel.x, ev["y_base"] + rel.y, esquina.y + rel.z)
		assert(ev["celdas_plantilla"].has(real), "la caja %s cae en una celda de la plantilla" % [real])
		var caja: MeshInstance3D = camara._huella_blueprint[i]
		assert(caja.position.is_equal_approx(Vector3(real) + Vector3(0.5, 0.5, 0.5)), "la caja está en su celda real")
		var tipo: String = ev["celdas_plantilla"][real]
		var esperado: Color = mundo.COLOR_DESTACADO.get(tipo, color) if valida else color
		assert((caja.material_override as StandardMaterial3D).albedo_color == esperado, "color de %s" % tipo)


func ejecutar_pruebas() -> void:
	print("=== TEST 1: una colocación válida trae la plantilla, la fachada y el nivel real ===")
	var mundo: Node = _mundo_plano()
	var camara: Camera3D = _camara(mundo, "mina")
	var esquina := Vector2i(10, 10)
	var ev: Dictionary = camara._evaluar_puesto(esquina)
	assert(camara._mensaje_rechazo_puesto(ev) == "", "sobre suelo plano y libre la colocación es válida, salió: %s" % camara._mensaje_rechazo_puesto(ev))
	assert(ev["y_base"] == 0, "la losa de piso (capa 0) queda enterrada al nivel del suelo natural (objetivo 0)")
	assert(ev["giros"] == 0)
	assert(ev["celdas_plantilla"] == PlantillasPuesto.en_mundo("mina", 0, esquina, 0), "la plantilla en su posición real")
	var fachada_rel: Array[Vector2i] = PlantillasPuesto.fachada("mina", 0)
	assert(ev["fachada"].size() == fachada_rel.size() and not ev["fachada"].is_empty(), "una columna de fachada por cada columna relativa")
	for rel in fachada_rel:
		assert(ev["fachada"][esquina + rel] == 0, "la fachada se nivela al objetivo")
	assert(ev["columnas_union"].size() == ev["columnas"].size() + fachada_rel.size(), "huella + fachada")
	print("OK: evaluación válida.")
	camara.free()

	print("=== TEST 2: cada rechazo del clic aparece en el mensaje ===")
	# Pendiente: una columna de la huella 4 bloques más alta que sus vecinas.
	for y in range(1, 5):
		mundo.colocar_bloque(Vector3i(12, y, 12), "tierra")
	camara = _camara(mundo, "mina")
	ev = camara._evaluar_puesto(esquina)
	assert("pendiente" in camara._mensaje_rechazo_puesto(ev), "una columna muy alta rompe el relieve: %s" % camara._mensaje_rechazo_puesto(ev))
	camara.free()
	# Frente de la puerta: un muro en la fachada (mina sobre otra esquina, terreno liso).
	var esquina_b := Vector2i(24, 24)
	camara = _camara(mundo, "mina")
	var fachada_b: Array[Vector2i] = PlantillasPuesto.fachada("mina", 0)
	var columna_frente: Vector2i = esquina_b + fachada_b[0]
	mundo.colocar_bloque(Vector3i(columna_frente.x, 1, columna_frente.y), "bloque_piedra", true)
	ev = camara._evaluar_puesto(esquina_b)
	assert("frente" in camara._mensaje_rechazo_puesto(ev), "una estructura delante de la puerta la rechaza: %s" % camara._mensaje_rechazo_puesto(ev))
	camara.free()
	print("OK: rechazos por relieve y frente.")

	print("=== TEST 3: en pesca el giro efectivo pone el edificio del lado de tierra ===")
	var mundo_p: Node = _mundo_plano()
	# Agua en el extremo de z alto: fondo a y=-1 y una lámina de agua a y=0 rodeando el extremo.
	for x in range(9, 15):
		for z in range(14, 20):
			mundo_p.set_cell_item(Vector3i(x, 0, z), GridMap.INVALID_CELL_ITEM)
			mundo_p.colocar_bloque(Vector3i(x, -1, z), "tierra")
			mundo_p.colocar_bloque(Vector3i(x, 0, z), "agua")
	var esquina_p := Vector2i(10, 10)
	var camara_0: Camera3D = _camara(mundo_p, "pesca_frutos_mar", 0)
	var ev_0: Dictionary = camara_0._evaluar_puesto(esquina_p)
	var camara_2: Camera3D = _camara(mundo_p, "pesca_frutos_mar", 2)
	var ev_2: Dictionary = camara_2._evaluar_puesto(esquina_p)
	assert(ev_0["extremo_agua_indice"] != -1, "el extremo de agua se detecta")
	assert(ev_0["giros"] == ev_2["giros"], "sea cual sea el giro pedido, el efectivo deja el edificio del lado de tierra")
	assert(camara_0._mensaje_rechazo_puesto(ev_0) == "", "válida en pesca: %s" % camara_0._mensaje_rechazo_puesto(ev_0))
	camara_0.free()
	camara_2.free()
	mundo_p.free()
	print("OK: giro efectivo de pesca.")

	print("=== TEST 4: el fantasma sigue la plantilla real y su validez ===")
	camara = _camara(mundo, "caza_recoleccion")
	esquina = Vector2i(14, 30)
	ev = camara._evaluar_puesto(esquina)
	assert(camara._mensaje_rechazo_puesto(ev) == "", "válida sobre suelo plano")
	camara._actualizar_fantasma_puesto(esquina, ev, true)
	_verificar_fantasma(camara, mundo, esquina, ev, CamaraCenitalScript.COLOR_PUESTO_VALIDO, true)
	camara._actualizar_fantasma_puesto(esquina, ev, false)
	_verificar_fantasma(camara, mundo, esquina, ev, CamaraCenitalScript.COLOR_PUESTO_INVALIDO, false)
	# Al girar la plantilla, el fantasma se reconstruye con la plantilla girada.
	var huella_girada: Vector2i = PlantillasPuesto.huella("caza_recoleccion", 1)
	camara._giros_puesto = 1
	camara._ancho_puesto_activo = huella_girada.x
	camara._alto_puesto_activo = huella_girada.y
	ev = camara._evaluar_puesto(esquina)
	camara._actualizar_fantasma_puesto(esquina, ev, true)
	assert(camara._giros_fantasma_puesto == 1, "el fantasma se reconstruyó con el giro efectivo")
	_verificar_fantasma(camara, mundo, esquina, ev, CamaraCenitalScript.COLOR_PUESTO_VALIDO, true)
	print("OK: fantasma del puesto.")

	print("=== TEST 5: los overlays de despeje y nivelación reciben la evaluación del puesto ===")
	camara._overlay_nivelacion = NivelacionOverlayScript.new()
	camara._actualizar_overlays(esquina, ev)
	var reservadas: int = mundo.calcular_despeje(ev["celdas_mundo"]).size()
	assert(reservadas > 0, "una puerta y ventanas reservan despeje")
	assert(camara._overlay_nivelacion.get_child_count() == reservadas + ev["columnas_union"].size(), "cajas de despeje + un plano por columna de huella y fachada")
	camara._overlay_nivelacion.free()
	camara.free()
	print("OK: overlays del puesto.")

	mundo.free()

	print("=== TEST 6: el resumen de materiales del blueprint residencial llega al cuadro de información en el MISMO frame ===")
	# Regresión encontrada en revisión de código (2026-09-29):
	# _actualizar_previsualizacion_blueprint() llamaba hud.mostrar_contexto()
	# (que BORRA la línea "extra" en cada llamada, corre todos los frames)
	# ANTES de _actualizar_resumen_materiales() — el resumen quedaba visible
	# un solo frame hasta que el siguiente mostrar_contexto() lo limpiaba de
	# nuevo. El orden correcto es: calcular el resumen primero, pasarlo como
	# texto_extra de mostrar_contexto().
	var mundo6: Node = _mundo_plano()
	var camara6: Camera3D = CamaraCenitalScript.new()
	camara6.mundo = mundo6
	camara6.nivelador_puesto = NiveladorTerreno.new(CamaraCenitalScript._AlturaSinAgua.new(mundo6))
	camara6._blueprint_activo = {
		"celdas_3d": {Vector3i(0, 0, 0): "bloque_piedra"},
		"pisos": [{"celdas": {}, "camas": [{"pos": "0,0"}]}],
	}
	var columnas6: Array[Vector2i] = [Vector2i(0, 0)]
	var ev6 := {"columnas": columnas6, "resultado_base": {"base_y": 0}, "fachada": {}}
	camara6._actualizar_resumen_materiales(Vector2i(5, 5), ev6, true)
	assert(camara6._resumen_blueprint_texto.contains("Camas: 1"), "cuenta la cama del blueprint")
	assert(camara6._resumen_blueprint_texto.contains("piedra"), "bloque_piedra cuesta piedra")

	var hud6: CanvasLayer = HUDScript.new()
	var oxigeno6 := Label.new()
	oxigeno6.name = "OxigenoLabel"
	hud6.add_child(oxigeno6)
	add_child(hud6)
	camara6.hud = hud6
	# Mismo orden que el código real: mostrar_contexto() recibe el resumen YA
	# calculado como texto_extra, en vez de que algo lo actualice después.
	hud6.mostrar_contexto("Edificio residencial", {}, ["COLOCAR"], true, camara6._resumen_blueprint_texto)
	assert(hud6._contexto.extra.visible and hud6._contexto.extra.text == camara6._resumen_blueprint_texto, "el resumen sigue visible tras mostrar_contexto(), no se borra")
	hud6.queue_free()
	camara6.free()
	mundo6.free()
	print("OK: el resumen de materiales llega al cuadro de información sin perderse.")

	print("=== TEST 7: colocar un puesto arma una cola de construcción pagada, no lo estampa al instante ===")
	var mundo7: Node = _mundo_plano()
	var camara7: Camera3D = _camara(mundo7, "maderero")
	camara7.hud = HUDScript.new()
	add_child(camara7.hud)
	var esquina7 := Vector2i(20, 20)
	var ev7: Dictionary = camara7._evaluar_puesto(esquina7)
	assert(camara7._mensaje_rechazo_puesto(ev7) == "", "válida sobre suelo plano")
	for recurso7 in ["tierra", "madera", "piedra"]:
		Ciudad.almacen[recurso7].cantidad = 0.0
	camara7._confirmar_puesto(esquina7)
	# La puerta (capa 1, sobre la losa de piso) siempre empieza vacía, así que se
	# marca "fantasma" de inmediato — a diferencia de la losa (capa 0), que puede
	# coincidir con terreno natural todavía sin excavar (igual que la losa
	# enterrada de un residencial, ver VoxelWorld._colocar_fantasma_si_vacia()).
	var celda_muro_7: Vector3i
	for celda in ev7["celdas_plantilla"]:
		if ev7["celdas_plantilla"][celda] == "puerta_inferior":
			celda_muro_7 = celda
			break
	assert(mundo7.obtener_tipo(celda_muro_7) == "fantasma", "la plantilla queda como fantasma, no estampada")
	assert(not Recoleccion.puestos.has(esquina7), "no se registra en Recoleccion hasta completarse")
	print("OK: colocar un puesto solo inicia su construcción fantasma.")

	print("=== TEST 8: completar la construcción del puesto lo registra en Recoleccion/Economia — antes, no ===")
	# surtir_construccion(celda_muro_7) sirve para avanzar CUALQUIER cola del
	# mismo edificio (relleno primero, estructura después) apuntando siempre
	# a la misma celda de la plantilla — mismo criterio que ya usan las
	# pruebas de construcción de un residencial (ver BlueprintValidatorTest.gd).
	for recurso8 in ["tierra", "madera", "piedra"]:
		Ciudad.almacen[recurso8].cantidad = 999999.0
	var resultado8: Dictionary
	var limite8 := 0
	while limite8 < 2000:
		resultado8 = mundo7.surtir_construccion(celda_muro_7)
		limite8 += 1
		if resultado8.get("completa", false):
			break
		assert(not resultado8.get("insuficiente", false), "con fondos de sobra, ningún paso debe rechazarse por falta de recurso")
	assert(resultado8.get("completa", false), "la construcción se completó dentro del límite de pasos")
	assert(not Recoleccion.puestos.has(esquina7), "surtir_construccion() por sí sola NO registra el puesto: falta _completar_construccion()")

	var jugador8: CharacterBody3D = PlayerScript.new()
	jugador8.mundo = mundo7
	jugador8.hud = camara7.hud
	jugador8._completar_construccion(resultado8["metadata"])
	assert(Recoleccion.puestos.has(esquina7), "_completar_construccion() registra el puesto en Recoleccion al completarse")
	assert(Economia.puestos.has(esquina7), "...y en Economia")
	jugador8.free()
	camara7.hud.queue_free()
	camara7.free()
	mundo7.free()
	print("OK: el puesto se activa exactamente al completar su construcción.")

	print("=== TEST 9: al confirmar un puesto de pesca, el agua abierta bajo la plataforma no se drena ===")
	# Regresión encontrada en revisión de código (2026-09-29): el drenado del
	# footprint (antes solo para puestos NO-pesca, ver código anterior a esta
	# rama) pasó a correr siempre — para pesca eso convertía toda el agua en
	# tierra ANTES de que la lógica de pilotes/relleno pudiera distinguir
	# "agua real" de "ya drenada", dejando la plataforma entera sin agua
	# navegable (el puesto queda sin peces que pescar).
	var mundo9: Node = _mundo_plano()
	for x in range(9, 15):
		for z in range(14, 20):
			mundo9.set_cell_item(Vector3i(x, 0, z), GridMap.INVALID_CELL_ITEM)
			mundo9.colocar_bloque(Vector3i(x, -1, z), "tierra")
			mundo9.colocar_bloque(Vector3i(x, 0, z), "agua")
	var esquina9 := Vector2i(10, 10)
	var camara9: Camera3D = _camara(mundo9, "pesca_frutos_mar", 0)
	camara9.hud = HUDScript.new()
	add_child(camara9.hud)
	var ev9: Dictionary = camara9._evaluar_puesto(esquina9)
	assert(camara9._mensaje_rechazo_puesto(ev9) == "", "válida en pesca: %s" % camara9._mensaje_rechazo_puesto(ev9))
	var extremo9: Array[Vector2i] = CamaraCenitalScript._celdas_extremo_pesca(camara9._ancho_puesto_activo, camara9._alto_puesto_activo, ev9["extremo_agua_indice"])
	var columna_agua_abierta: Vector2i = esquina9 + extremo9[1]  # ni primera ni última: no es pilote
	var celda_agua_abierta := Vector3i(columna_agua_abierta.x, mundo9.altura_en(columna_agua_abierta.x, columna_agua_abierta.y), columna_agua_abierta.y)
	assert(mundo9.obtener_tipo(celda_agua_abierta) == "agua", "columna de agua abierta antes de confirmar")
	camara9._confirmar_puesto(esquina9)
	assert(mundo9.obtener_tipo(celda_agua_abierta) == "agua", "el agua abierta bajo la plataforma de pesca no se drena al confirmar")
	camara9.hud.queue_free()
	camara9.free()
	mundo9.free()
	print("OK: pesca conserva su agua abierta al confirmar.")

	print("=== TEST 10: deconstruir un puesto nuevo lo desactiva, y reconstruirlo lo reactiva sin re-registrarlo ===")
	# Regresión encontrada en revisión de código (2026-09-29): un puesto recién
	# construido llevaba SOLO metadata {"puesto_nuevo": {...}} — el mecanismo
	# existente de pausa/reanuda (Economia.desactivar_puesto()/reactivar_puesto(),
	# que lee metadata["puesto"]) nunca se disparaba: el puesto seguía activo
	# mientras se deconstruía, y al reconstruirlo volvía a caer en la rama
	# "puesto_nuevo" (registrar_puesto() de nuevo, pisando el almacén local y
	# huérfanos en _puesto_de). Fix: la metadata también lleva "puesto": esquina
	# desde el inicio, y _completar_construccion() borra "puesto_nuevo" tras
	# registrar — así la SEGUNDA vez que se completa (tras deconstruir y
	# resurtir) cae en la rama "puesto" (reactivar), no en "puesto_nuevo".
	var mundo10: Node = _mundo_plano()
	var camara10: Camera3D = _camara(mundo10, "maderero")
	camara10.hud = HUDScript.new()
	add_child(camara10.hud)
	var esquina10 := Vector2i(30, 4)
	var ev10: Dictionary = camara10._evaluar_puesto(esquina10)
	assert(camara10._mensaje_rechazo_puesto(ev10) == "", "válida sobre suelo plano")
	for recurso10 in ["tierra", "madera", "piedra"]:
		Ciudad.almacen[recurso10].cantidad = 999999.0
	camara10._confirmar_puesto(esquina10)
	var celda_estructura10: Vector3i = ev10["celdas_plantilla"].keys()[0]
	var resultado10: Dictionary
	var limite10 := 0
	while limite10 < 2000:
		resultado10 = mundo10.surtir_construccion(celda_estructura10)
		limite10 += 1
		if resultado10.get("completa", false):
			break
	assert(resultado10.get("completa", false), "la construcción se completó dentro del límite de pasos")
	var metadata10: Dictionary = resultado10["metadata"]
	var jugador10: CharacterBody3D = PlayerScript.new()
	jugador10.mundo = mundo10
	jugador10.hud = camara10.hud
	jugador10._completar_construccion(metadata10)
	assert(Economia.puestos.has(esquina10) and Economia.puestos[esquina10]["activo"], "el puesto queda activo al completarse por primera vez")
	assert(metadata10.has("puesto"), "la metadata también lleva la clave 'puesto' desde el inicio, para el mecanismo de pausa/reanuda")
	assert(not metadata10.has("puesto_nuevo"), "_completar_construccion() borra 'puesto_nuevo' tras registrar, para no volver a registrar al reconstruir")

	var deco10: Dictionary = mundo10.procesar_deconstruccion(celda_estructura10)
	var metadata_obra10: Dictionary = mundo10.edificio_metadata.get(deco10["id"], {})
	assert(metadata_obra10.has("puesto"), "la obra en deconstrucción expone metadata['puesto'] para desactivarse")
	Economia.desactivar_puesto(metadata_obra10["puesto"])
	assert(not Economia.puestos[esquina10]["activo"], "deconstruir un puesto ya construido lo desactiva")

	var resultado10b: Dictionary
	limite10 = 0
	while limite10 < 2000:
		resultado10b = mundo10.surtir_construccion(celda_estructura10)
		limite10 += 1
		if resultado10b.get("completa", false):
			break
	assert(resultado10b.get("completa", false), "resurtir la celda revertida vuelve a completar la obra")
	jugador10._completar_construccion(resultado10b["metadata"])
	assert(Economia.puestos[esquina10]["activo"], "reconstruir un puesto ya registrado lo reactiva (rama 'puesto', no 'puesto_nuevo')")
	assert(Recoleccion.puestos.has(esquina10), "el puesto sigue registrado")

	jugador10.free()
	camara10.hud.queue_free()
	camara10.free()
	mundo10.free()
	print("OK: deconstruir/reconstruir un puesto nuevo usa el mecanismo existente de pausa/reanuda.")

	print("=== TEST 11: incluso sobre terreno ya parejo, el primer paso es excavar 1 nivel para la losa de piso — no cobra de inmediato ===")
	# Reporte del usuario (2026-09-29): con 0 tierra en el inventario, al colocar
	# un puesto salía "No hay suficiente tierra" de inmediato, como si el primer
	# paso fuera colocar un bloque en vez de excavar. Causa real: la plantilla no
	# tenía losa de piso (capa 0 era la puerta), así que sobre terreno YA parejo
	# no había nada que excavar y la cola arrancaba directo en la estructura. Fix:
	# la plantilla ahora siempre trae una losa de piso (capa 0) que, sobre
	# terreno parejo, coincide con el bloque natural existente — así que SIEMPRE
	# hay al menos 1 paso de excavación antes de cualquier cobro (VoxelWorld.
	# _bloqueado_por_falta_de() nunca bloquea un paso de excavación, "aire"/
	# "fantasma", ver VoxelWorld.gd:1982).
	var mundo11: Node = _mundo_plano()
	var camara11: Camera3D = _camara(mundo11, "mina")
	camara11.hud = HUDScript.new()
	add_child(camara11.hud)
	var esquina11 := Vector2i(30, 20)
	var ev11: Dictionary = camara11._evaluar_puesto(esquina11)
	assert(camara11._mensaje_rechazo_puesto(ev11) == "", "válida sobre suelo plano (ya parejo)")
	for recurso11 in ["tierra", "madera", "piedra", "hierro"]:
		Ciudad.almacen[recurso11].cantidad = 0.0
	camara11._confirmar_puesto(esquina11)
	var celda_puerta11: Vector3i
	for celda in ev11["celdas_plantilla"]:
		if ev11["celdas_plantilla"][celda] == "puerta_inferior":
			celda_puerta11 = celda
			break
	var paso11: Dictionary = mundo11.proximo_paso_pendiente(celda_puerta11)
	assert(paso11["tipo"] == "fantasma" or paso11["tipo"] == "aire", "el primer paso pendiente es de excavación, no de estructura/relleno — salió '%s'" % paso11.get("tipo", "?"))
	var resultado11: Dictionary = mundo11.surtir_construccion(celda_puerta11)
	assert(not resultado11.get("insuficiente", false), "un paso de excavación nunca se bloquea por falta de recursos, incluso con el almacén en 0")
	camara11.hud.queue_free()
	camara11.free()
	mundo11.free()
	print("OK: siempre hay al menos 1 nivel de excavación antes de cualquier cobro, incluso sobre terreno ya parejo.")

	print("=== TEST 12: la ficha de previsualización muestra el costo REAL de cada tipo, no un placeholder fijo ===")
	# Reporte del usuario (2026-09-30, con captura): la ficha de "MINA" mostraba
	# "10 tierra · 10 madera · 5 piedra" — el mismo placeholder fijo para los 4
	# tipos de puesto (HUD.costo_de_puesto(), ya eliminado), sin relación con su
	# costo real. Ninguna plantilla de puesto usa bloque_piedra (mina =
	# adobe, maderero/caza = bloque_madera, pesca = bloque_piedra pero
	# mina/maderero/caza no), así que "piedra" nunca debería aparecer en el
	# costo de mina ni de maderero.
	var mundo12: Node = _mundo_plano()
	var camara12: Camera3D = _camara(mundo12, "mina")
	var esquina12 := Vector2i(10, 30)
	var ev12: Dictionary = camara12._evaluar_puesto(esquina12)
	assert(camara12._mensaje_rechazo_puesto(ev12) == "", "válida sobre suelo plano")
	# _resumen_materiales_puesto() devuelve {"neto": ..., "bloques": ...}
	# desde 2026-09-30 (reporte del usuario: la ficha no decía cuántos
	# bloques representa el costo, solo el recurso crudo).
	var costo_mina12: Dictionary = camara12._resumen_materiales_puesto(esquina12, ev12)["neto"]
	assert(not costo_mina12.has("piedra"), "mina no usa piedra en ningún bloque de su plantilla, salió: %s" % costo_mina12)
	assert(costo_mina12.has("tierra"), "mina cuesta tierra (adobe): %s" % costo_mina12)
	assert(costo_mina12.has("madera"), "la puerta y el baúl de mina cuestan madera: %s" % costo_mina12)
	camara12.free()

	var camara12b: Camera3D = _camara(mundo12, "maderero")
	var esquina12b := Vector2i(20, 30)
	var ev12b: Dictionary = camara12b._evaluar_puesto(esquina12b)
	assert(camara12b._mensaje_rechazo_puesto(ev12b) == "", "válida sobre suelo plano")
	var resumen_maderero12: Dictionary = camara12b._resumen_materiales_puesto(esquina12b, ev12b)
	var costo_maderero12: Dictionary = resumen_maderero12["neto"]
	assert(not costo_maderero12.has("piedra"), "maderero no usa piedra en ningún bloque de su plantilla, salió: %s" % costo_maderero12)
	assert(costo_maderero12.has("madera"), "maderero cuesta madera (bloque_madera): %s" % costo_maderero12)
	assert(costo_mina12 != costo_maderero12, "dos tipos distintos ya no comparten el mismo costo fijo")
	assert(resumen_maderero12["bloques"].get("madera", 0) > 0, "maderero cuenta bloque_madera reales en la plantilla, salió: %s" % resumen_maderero12["bloques"])
	camara12b.free()
	mundo12.free()
	print("OK: el costo mostrado depende del tipo de puesto y de su plantilla real, no de un placeholder.")

	print("\n=== TEST 13: la siderúrgica solo se coloca dentro de la zona de influencia y sobre zona industrial; el frente de la salida se nivela al nivel de la entrada ===")
	Recoleccion.puestos.clear()  # los puestos de las pruebas 7-11 siguen registrados y chocarían con la huella de esta
	var mundo13: Node = _mundo_plano()
	var esquina13 := Vector2i(18, 18)
	var camara13: Camera3D = _camara(mundo13, "siderurgica")
	var ev13: Dictionary = camara13._evaluar_puesto(esquina13)
	assert("zona de influencia" in camara13._mensaje_rechazo_puesto(ev13), "sin núcleo declarado está fuera de la zona de influencia: %s" % camara13._mensaje_rechazo_puesto(ev13))
	Zonificacion.declarar_nucleo([Vector2i(30, 30), Vector2i(31, 30), Vector2i(30, 31), Vector2i(31, 31)])
	ev13 = camara13._evaluar_puesto(esquina13)
	assert("zona industrial" in camara13._mensaje_rechazo_puesto(ev13), "dentro de la influencia pero sin zona pintada: %s" % camara13._mensaje_rechazo_puesto(ev13))
	Zonificacion.pintar_zona(esquina13, esquina13 + Vector2i(4, 4), Zonificacion.ZONAS_PINTABLES[0])
	ev13 = camara13._evaluar_puesto(esquina13)
	assert("zona industrial" in camara13._mensaje_rechazo_puesto(ev13), "una zona residencial tampoco sirve: %s" % camara13._mensaje_rechazo_puesto(ev13))
	Zonificacion.pintar_zona(esquina13, esquina13 + Vector2i(4, 4), Zonificacion.ZONAS_PINTABLES[1])
	ev13 = camara13._evaluar_puesto(esquina13)
	assert(camara13._mensaje_rechazo_puesto(ev13) == "", "dentro de la influencia y sobre zona industrial es válida: %s" % camara13._mensaje_rechazo_puesto(ev13))
	assert(ev13["fachada"].size() == 20, "fachada de ambos lados (%d)" % ev13["fachada"].size())
	var costo13: Dictionary = camara13._resumen_materiales_puesto(esquina13, ev13)["neto"]
	assert(costo13.get("piedra", 0) > 0, "construir una siderúrgica cuesta piedra (muros de bloque_piedra)")
	# Media huella sobre zona industrial no alcanza.
	Zonificacion.despintar_zona(esquina13 + Vector2i(0, 4), esquina13 + Vector2i(4, 4))
	assert("zona industrial" in camara13._mensaje_rechazo_puesto(camara13._evaluar_puesto(esquina13)), "toda la huella debe estar sobre zona industrial")
	Zonificacion.pintar_zona(esquina13, esquina13 + Vector2i(4, 4), Zonificacion.ZONAS_PINTABLES[1])
	camara13.free()
	# Una mina, en cambio, no puede ir en la zona de influencia.
	var camara13m: Camera3D = _camara(mundo13, "mina")
	assert("influencia" in camara13m._mensaje_rechazo_puesto(camara13m._evaluar_puesto(esquina13)), "una mina no se coloca en la zona de influencia")
	camara13m.free()
	# Entrada y salida a distinto nivel: el terreno al sur de la salida (z >= 23) está 1 más alto. Manda la
	# entrada (norte, nivel 0); el frente de la salida se nivela cavando ese bloque, no se rechaza.
	for x13 in range(LADO):
		for z13 in range(23, LADO):
			mundo13.colocar_bloque(Vector3i(x13, 1, z13), "tierra")
	var camara13d: Camera3D = _camara(mundo13, "siderurgica")
	var ev13d: Dictionary = camara13d._evaluar_puesto(esquina13)
	assert(camara13d._mensaje_rechazo_puesto(ev13d) == "", "el desnivel entre entrada y salida no rechaza: %s" % camara13d._mensaje_rechazo_puesto(ev13d))
	assert(ev13d["resultado_base"]["base_y"] == 0, "la entrada decide la altura")
	var frente_salida13: Vector2i = esquina13 + PlantillasPuesto.celda_de_salida("siderurgica", 0)
	assert(ev13d["fachada"][frente_salida13] == 0, "el frente de la salida se nivela al nivel de la entrada")
	var plan13: Dictionary = camara13d._plan_nivelacion(esquina13, ev13d["columnas"], ev13d["resultado_base"]["base_y"], ev13d["fachada"])
	assert(plan13["excavacion"].has(Vector3i(frente_salida13.x, 1, frente_salida13.y)), "se cava el bloque que sobra frente a la salida")
	camara13d.free()
	Zonificacion.nucleo_declarado = false  # no contaminar otras pruebas de esta escena
	mundo13.free()

	print("\n=== TEST 14: la escuela técnica solo se coloca dentro de la zona de influencia y sobre zona residencial ===")
	Recoleccion.puestos.clear()
	var mundo14: Node = _mundo_plano()
	var esquina14 := Vector2i(24, 18)
	var camara14: Camera3D = _camara(mundo14, "escuela_tecnica")
	var ev14: Dictionary = camara14._evaluar_puesto(esquina14)
	var mensaje14: String = camara14._mensaje_rechazo_puesto(ev14)
	assert("zona de influencia" in mensaje14 and "escuela" in mensaje14, "sin núcleo declarado está fuera de la zona de influencia: %s" % mensaje14)
	Zonificacion.declarar_nucleo([Vector2i(30, 30), Vector2i(31, 30), Vector2i(30, 31), Vector2i(31, 31)])
	ev14 = camara14._evaluar_puesto(esquina14)
	assert("zona residencial" in camara14._mensaje_rechazo_puesto(ev14), "dentro de la influencia pero sin zona pintada: %s" % camara14._mensaje_rechazo_puesto(ev14))
	Zonificacion.pintar_zona(esquina14, esquina14 + Vector2i(4, 4), Zonificacion.ZONAS_PINTABLES[1])
	ev14 = camara14._evaluar_puesto(esquina14)
	assert("zona residencial" in camara14._mensaje_rechazo_puesto(ev14), "una zona industrial tampoco sirve: %s" % camara14._mensaje_rechazo_puesto(ev14))
	Zonificacion.pintar_zona(esquina14, esquina14 + Vector2i(4, 4), Zonificacion.ZONAS_PINTABLES[0])
	ev14 = camara14._evaluar_puesto(esquina14)
	assert(camara14._mensaje_rechazo_puesto(ev14) == "", "dentro de la influencia y sobre zona residencial es válida: %s" % camara14._mensaje_rechazo_puesto(ev14))
	assert(ev14["fachada"].size() == 10, "fachada de un solo lado (%d)" % ev14["fachada"].size())
	assert(not camara14._resumen_materiales_puesto(esquina14, ev14)["neto"].is_empty(), "construirla cuesta materiales")
	Zonificacion.despintar_zona(esquina14 + Vector2i(0, 4), esquina14 + Vector2i(4, 4))
	assert("zona residencial" in camara14._mensaje_rechazo_puesto(camara14._evaluar_puesto(esquina14)), "toda la huella debe estar sobre zona residencial")
	Zonificacion.pintar_zona(esquina14, esquina14 + Vector2i(4, 4), Zonificacion.ZONAS_PINTABLES[0])
	camara14.hud = HUDScript.new()
	add_child(camara14.hud)
	camara14._confirmar_puesto(esquina14)
	var info14: Dictionary = {}
	for meta14 in mundo14.edificio_metadata.values():
		if meta14.has("puesto_nuevo") and meta14["puesto_nuevo"]["tipo"] == "escuela_tecnica":
			info14 = meta14["puesto_nuevo"]
	assert(not info14.is_empty(), "colocar la escuela inicia su construcción")
	assert(info14["deposito"] == Economia.SIN_DEPOSITO, "sin baúl, el puesto se registra sin depósito")
	camara14.free()
	Zonificacion.nucleo_declarado = false  # no contaminar otras pruebas de esta escena
	mundo14.free()

	print("\n=== Las 14 pruebas de previsualización de puestos pasaron correctamente ===")

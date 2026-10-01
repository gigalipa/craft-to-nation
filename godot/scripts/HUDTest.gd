extends Node

## Pruebas de los widgets del HUD por modos (mismo patrón que PuertasTest.gd).
## Corre HUDTest.tscn y revisa el panel "Output": debe imprimir todas las
## pruebas y la línea final, sin ningún error de assert().
## Ver docs/superpowers/specs/2026-09-25-hud-por-modos-design.md.

const BarraSuperiorScript = preload("res://scripts/BarraSuperior.gd")
const PanelContextualScript = preload("res://scripts/PanelContextual.gd")
const BarraModosScript = preload("res://scripts/BarraModos.gd")
const HotbarScript = preload("res://scripts/Hotbar.gd")
const HUDScript = preload("res://scripts/HUD.gd")
const CaraApuntadaScript = preload("res://scripts/CaraApuntada.gd")
const VentanaPoblacionScript = preload("res://scripts/VentanaPoblacion.gd")
const VentanaAlmacenScript = preload("res://scripts/VentanaAlmacen.gd")


## Recurso falso: BarraSuperior solo lee estos cuatro campos (duck typing).
class RecursoFalso:
	var nombre: String
	var cantidad: float
	var limite: float
	var tasa_neta_promedio: float

	func _init(p_nombre: String, p_cantidad: float, p_limite: float, p_tasa: float) -> void:
		nombre = p_nombre
		cantidad = p_cantidad
		limite = p_limite
		tasa_neta_promedio = p_tasa


func _ready() -> void:
	await ejecutar_pruebas()
	print("HUDTest: todas las pruebas pasaron")


func ejecutar_pruebas() -> void:
	probar_barra_superior_calculos()
	probar_barra_superior()
	probar_panel_contextual()
	probar_panel_temporal()
	await probar_panel_desvanece()
	await probar_transicion_hud()
	probar_barra_modos()
	probar_hotbar()
	probar_formateadores_hud()
	probar_cara_apuntada()
	probar_ventanas_datos()


func probar_barra_superior_calculos() -> void:
	print("=== TEST 1a: BarraSuperior (cálculos estáticos) ===")
	assert(BarraSuperiorScript.texto_poblacion(38, 48, 5) == "Población 38/48 (5)")
	assert(BarraSuperiorScript.fraccion_moral(Ciudad.BONO_MORAL_MAXIMO / 2.0) == 0.5)
	# Moral fuera de rango: la barra se acota a 0-1.
	assert(BarraSuperiorScript.fraccion_moral(-3.0) == 0.0)
	assert(BarraSuperiorScript.fraccion_moral(Ciudad.BONO_MORAL_MAXIMO * 4.0) == 1.0)
	assert(BarraSuperiorScript.texto_tasa(12.0) == "+12.0/h")
	assert(BarraSuperiorScript.texto_tasa(-3.0) == "-3.0/h")
	assert(BarraSuperiorScript.texto_tasa(0.0) == "+0.0/h")
	assert(BarraSuperiorScript.texto_comida(126.0, 200.0, -5.0) == "Comida 126/200 -5.0/h")

	var almacen := {
		"a": RecursoFalso.new("A", 100.0, 500.0, 2.0),
		"b": RecursoFalso.new("B", 50.0, 500.0, -3.0),
	}
	assert(BarraSuperiorScript.totales(almacen) == {"cantidad": 150.0, "limite": 1000.0, "tasa": -1.0})
	assert(BarraSuperiorScript.totales({}) == {"cantidad": 0.0, "limite": 0.0, "tasa": 0.0})

	# Recurso crítico: la tasa más negativa; sin decrecientes, la menor positiva.
	assert(BarraSuperiorScript.clave_critica({"a": RecursoFalso.new("A", 0, 1, 5.0), "b": RecursoFalso.new("B", 0, 1, -1.0), "c": RecursoFalso.new("C", 0, 1, -4.0)}) == "c")
	assert(BarraSuperiorScript.clave_critica({"a": RecursoFalso.new("A", 0, 1, 5.0), "b": RecursoFalso.new("B", 0, 1, 1.0), "c": RecursoFalso.new("C", 0, 1, 3.0)}) == "b")
	# Una tasa 0 no cuenta como "menor positiva": el recurso sin movimiento no es crítico.
	assert(BarraSuperiorScript.clave_critica({"a": RecursoFalso.new("A", 0, 1, 0.0), "b": RecursoFalso.new("B", 0, 1, 2.0)}) == "b")
	assert(BarraSuperiorScript.clave_critica({"a": RecursoFalso.new("A", 0, 1, 0.0), "b": RecursoFalso.new("B", 0, 1, 0.0)}) == "")
	assert(BarraSuperiorScript.clave_critica({}) == "")


## Clic en Población/Almacén de la barra superior (dato_pedido) y las
## ventanas que abre (VentanaPoblacion, VentanaAlmacen).
func probar_ventanas_datos() -> void:
	print("=== TEST 1c: dato_pedido y ventanas de Población/Almacén ===")
	var barra: PanelContainer = BarraSuperiorScript.new()
	add_child(barra)
	var pedidos: Array = []
	barra.dato_pedido.connect(func(cual: String) -> void: pedidos.append(cual))
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	barra.poblacion.emit_signal("gui_input", clic)
	barra.almacen_total.emit_signal("gui_input", clic)
	assert(pedidos == ["poblacion", "almacen"], "salió %s" % [pedidos])
	barra.queue_free()

	var ventana_poblacion: PanelContainer = VentanaPoblacionScript.new()
	add_child(ventana_poblacion)
	assert(not ventana_poblacion.visible and not ventana_poblacion.abierta)
	assert(ventana_poblacion.position == VentanaPoblacionScript.POSICION_INICIAL, "debe abrir en la esquina superior izquierda")
	ventana_poblacion.abrir()
	assert(ventana_poblacion.visible and ventana_poblacion.abierta)
	assert(ventana_poblacion._caja.get_child_count() > 0)
	# Regresión: _actualizar() reconstruía TODA la ventana (título incluido)
	# cada fotograma, destruyendo el botón de cerrar a mitad de clic (entre
	# el press y el release) — el "pressed" nunca llegaba a emitirse. El
	# botón debe sobrevivir intacto a varios fotogramas.
	var boton_cerrar: Button = ventana_poblacion._caja_raiz.get_child(0).get_child(1)
	assert(boton_cerrar.text == "X")
	for i in range(5):
		ventana_poblacion._process(0.0)
	assert(ventana_poblacion._caja_raiz.get_child(0).get_child(1) == boton_cerrar, "el botón de cerrar no debe recrearse en cada _process()")
	boton_cerrar.pressed.emit()
	assert(not ventana_poblacion.visible and not ventana_poblacion.abierta, "pressed debe cerrar la ventana")
	ventana_poblacion.abrir()
	# Cambiar de vista a 1ª persona la oculta sin cerrarla ni mover su posición.
	ventana_poblacion.position = Vector2(200, 150)
	ventana_poblacion.ocultar_temporalmente()
	assert(not ventana_poblacion.visible and ventana_poblacion.abierta)
	ventana_poblacion.restaurar()
	assert(ventana_poblacion.visible and ventana_poblacion.position == Vector2(200, 150))
	# Se actualiza en vivo mientras está visible.
	Ciudad.demografia["ciudadano"] += 1
	ventana_poblacion._process(0.0)
	var texto_ciudadanos := ""
	for hijo in ventana_poblacion._caja.get_children():
		if hijo is Label and (hijo as Label).text.begins_with("Ciudadanos:"):
			texto_ciudadanos = (hijo as Label).text
	assert(texto_ciudadanos == "Ciudadanos: %d" % Ciudad.demografia["ciudadano"], "salió '%s'" % texto_ciudadanos)
	Ciudad.demografia["ciudadano"] -= 1
	# Arrastre: mousedown, arrastrar, mouseup.
	var abajo := InputEventMouseButton.new()
	abajo.button_index = MOUSE_BUTTON_LEFT
	abajo.pressed = true
	abajo.position = Vector2(10, 10)
	ventana_poblacion._gui_input(abajo)
	var mover := InputEventMouseMotion.new()
	mover.position = Vector2(40, 30)
	ventana_poblacion._gui_input(mover)
	assert(ventana_poblacion.position == Vector2(230, 170), "salió %s" % ventana_poblacion.position)
	var arriba := InputEventMouseButton.new()
	arriba.button_index = MOUSE_BUTTON_LEFT
	arriba.pressed = false
	ventana_poblacion._gui_input(arriba)
	mover.position = Vector2(999, 999)
	ventana_poblacion._gui_input(mover)  # ya no arrastra: no debe moverse
	assert(ventana_poblacion.position == Vector2(230, 170))
	ventana_poblacion.cerrar()
	assert(not ventana_poblacion.visible and not ventana_poblacion.abierta)
	ventana_poblacion.queue_free()

	var ventana_almacen: PanelContainer = VentanaAlmacenScript.new()
	add_child(ventana_almacen)
	ventana_almacen.abrir()
	assert(ventana_almacen.visible and ventana_almacen.abierta)
	assert(ventana_almacen._caja.get_child_count() > 0)
	var boton_cerrar_almacen: Button = ventana_almacen._caja_raiz.get_child(0).get_child(1)
	ventana_almacen._process(0.0)
	assert(ventana_almacen._caja_raiz.get_child(0).get_child(1) == boton_cerrar_almacen)
	ventana_almacen.ocultar_temporalmente()
	assert(not ventana_almacen.visible and ventana_almacen.abierta)
	ventana_almacen.restaurar()
	assert(ventana_almacen.visible)
	ventana_almacen.cerrar()
	assert(not ventana_almacen.visible and not ventana_almacen.abierta)
	ventana_almacen.queue_free()


func probar_barra_superior() -> void:
	print("=== TEST 1b: BarraSuperior (widget con Ciudad real) ===")
	var barra: PanelContainer = BarraSuperiorScript.new()
	add_child(barra)
	var respaldo := {}
	for clave in Ciudad.almacen:
		respaldo[clave] = Ciudad.almacen[clave].tasa_neta_promedio
		Ciudad.almacen[clave].tasa_neta_promedio = 0.0

	Ciudad.almacen["comida"].cantidad = 126.0
	Ciudad.almacen["comida"].tasa_neta_promedio = -5.0
	barra.actualizar()
	assert(barra.comida.text.begins_with("Comida 126/"), "salió '%s'" % barra.comida.text)
	assert(barra.comida.get_theme_color("font_color") == BarraSuperiorScript.TemaHUD.INVALIDO)
	Ciudad.almacen["comida"].tasa_neta_promedio = 2.0
	barra.actualizar()
	assert(barra.comida.text.begins_with("Comida 126/") and barra.comida.text.ends_with("+2.0/h"), "salió '%s'" % barra.comida.text)
	assert(barra.comida.get_theme_color("font_color") == BarraSuperiorScript.TemaHUD.TEXTO)

	# Comida es la de menor tasa positiva (2.0) frente al resto en 0: es la crítica.
	assert(barra.critico.text == "Crítico: Comida +2.0/h", "salió '%s'" % barra.critico.text)
	Ciudad.almacen["madera"].tasa_neta_promedio = -2.0
	barra.actualizar()
	assert(barra.critico.text == "Crítico: Madera -2.0/h", "salió '%s'" % barra.critico.text)
	Ciudad.almacen["comida"].tasa_neta_promedio = 0.0
	Ciudad.almacen["madera"].tasa_neta_promedio = 0.0
	barra.actualizar()
	assert(barra.critico.text == "Crítico —", "salió '%s'" % barra.critico.text)

	assert(barra.almacen_total.text.begins_with("Almacén "), "salió '%s'" % barra.almacen_total.text)
	assert(barra.era.text == "Era 1 · Prehistórica")
	assert(barra.nivel.text.begins_with("Nivel "))

	for clave in respaldo:
		Ciudad.almacen[clave].tasa_neta_promedio = respaldo[clave]
	barra.queue_free()


func probar_panel_contextual() -> void:
	print("=== TEST 2: PanelContextual ===")
	assert(PanelContextualScript.texto_costo({"madera": 24, "piedra": 8}) == "24 madera · 8 piedra")
	assert(PanelContextualScript.texto_costo({}) == "")
	# Con "bloques" (material -> cantidad de bloques reales): suma "(N
	# bloques)" solo al material que tenga conteo; sin él, se ve igual que siempre.
	assert(PanelContextualScript.texto_costo({"madera": 24, "piedra": 8}, {"madera": 6}) == "24 madera (6 bloques) · 8 piedra")

	var panel: PanelContainer = PanelContextualScript.new()
	add_child(panel)
	panel.mostrar("Taller maderero", {"madera": 24, "piedra": 8}, ["ROTAR", "COLOCAR"], true, "Personal máximo: 5")
	assert(panel.visible)
	assert(panel.titulo.text == "TALLER MADERERO")
	assert(panel.costo.text == "24 madera · 8 piedra" and panel.costo.visible)
	assert(panel.acciones.text == "ROTAR  ·  COLOCAR")
	assert(panel.validez.visible and panel.validez.text == "Ubicación válida")
	assert(panel.extra.visible and panel.extra.text == "Personal máximo: 5")

	panel.mostrar("Taller maderero", {}, ["COLOCAR"], false)
	assert(panel.validez.text == "Ubicación no válida")

	# Sin costo, sin validez y sin línea extra (zonas, vías, deconstruir): esas
	# filas quedan ocultas, no vacías.
	panel.mostrar("Trazar vía", {}, ["SALIR (Esc)"])
	assert(not panel.costo.visible and not panel.validez.visible and not panel.extra.visible)

	panel.ocultar()
	assert(not panel.visible)
	panel.queue_free()

	print("=== TEST 2e: PanelContextual.set_extra() actualiza solo esa línea, sin tocar el resto ===")
	var panel_extra: PanelContainer = PanelContextualScript.new()
	add_child(panel_extra)
	panel_extra.mostrar("Edificio residencial", {}, ["ROTAR (Ctrl+rueda)", "COLOCAR (clic)"], true)
	assert(not panel_extra.extra.visible, "sin resumen todavía, la línea extra empieza oculta")
	panel_extra.set_extra("Camas: 2 · Baúles: 1\nMateriales de construcción:\n79 piedra")
	assert(panel_extra.extra.visible and panel_extra.extra.text == "Camas: 2 · Baúles: 1\nMateriales de construcción:\n79 piedra")
	assert(panel_extra.titulo.text == "EDIFICIO RESIDENCIAL", "set_extra() no toca el título ni el resto del panel")
	assert(panel_extra.validez.visible and panel_extra.validez.text == "Ubicación válida")
	panel_extra.set_extra("")
	assert(not panel_extra.extra.visible, "texto vacío vuelve a ocultar la línea")
	panel_extra.queue_free()


func probar_panel_temporal() -> void:
	print("=== TEST 2b: PanelContextual temporal ===")
	var panel: PanelContainer = PanelContextualScript.new()
	add_child(panel)
	panel.mostrar_temporal("Pared", {}, ["COLOCAR (clic der.)"])
	assert(panel.visible and panel.temporal)
	assert(panel.titulo.text == "PARED")
	assert(not panel.validez.visible, "el feedback de validez lo da el overlay, no el panel")

	# Un panel permanente (deconstrucción, cenital) cancela lo temporal: no se desvanece.
	panel.mostrar("Deconstruir", {}, ["G para salir"])
	assert(panel.visible and not panel.temporal)
	assert(is_equal_approx(panel.modulate.a, 1.0))

	panel.mostrar_temporal("Puerta", {}, ["COLOCAR (clic der.)"])
	panel.ocultar()
	assert(not panel.visible and not panel.temporal)
	assert(is_equal_approx(panel.modulate.a, 1.0), "ocultar debe dejar el panel listo para el próximo mostrar")
	panel.queue_free()


func probar_panel_desvanece() -> void:
	print("=== TEST 2c: el panel temporal se desvanece solo; el fijo no ===")
	var panel: PanelContainer = PanelContextualScript.new()
	add_child(panel)
	panel.mostrar_temporal("Pared", {}, ["COLOCAR"], 0.05)
	await get_tree().create_timer(0.6).timeout
	assert(not panel.visible and not panel.temporal, "debe haberse ocultado solo")
	assert(is_equal_approx(panel.modulate.a, 1.0), "y quedar listo para el próximo mostrar")

	# Un temporal reemplazado por uno fijo antes de expirar no se oculta.
	panel.mostrar_temporal("Pared", {}, ["COLOCAR"], 0.05)
	panel.mostrar("Deconstruir", {}, ["G para salir"])
	await get_tree().create_timer(0.6).timeout
	assert(panel.visible and panel.titulo.text == "DECONSTRUIR", "el panel fijo no debe desvanecerse")

	# Un segundo temporal reinicia la cuenta: el temporizador del primero no lo oculta.
	panel.mostrar_temporal("Pared", {}, ["COLOCAR"], 0.05)
	panel.mostrar_temporal("Puerta", {}, ["COLOCAR"], 5.0)
	await get_tree().create_timer(0.6).timeout
	assert(panel.visible and panel.titulo.text == "PUERTA", "el temporizador viejo no debe ocultar el panel nuevo")
	panel.queue_free()


## HUD.iniciar_transicion(): crossfade entre hotbar y barra de modos que
## acompaña el vuelo de cámara de Main.gd (ver Main._alternar_camara_cenital()).
func probar_transicion_hud() -> void:
	print("=== TEST 2d: HUD.iniciar_transicion() (crossfade hotbar <-> barra de modos) ===")
	var hud: CanvasLayer = HUDScript.new()
	# HUD._ready() espera $OxigenoLabel (@onready): en la escena real lo pone
	# Main.tscn; aquí se agrega a mano antes de add_child.
	var oxigeno := Label.new()
	oxigeno.name = "OxigenoLabel"
	hud.add_child(oxigeno)
	add_child(hud)
	await get_tree().process_frame  # deja correr _ready() (set_vista(true) inicial)
	assert(hud._hotbar.visible and not hud._barra_modos.visible, "arranca en 1ª persona")

	hud.iniciar_transicion(true, 0.1)  # hacia la cenital
	await get_tree().create_timer(0.3).timeout
	assert(not hud._hotbar.visible and hud._barra_modos.visible, "debe terminar en la cenital")
	assert(is_equal_approx(hud._barra_modos.modulate.a, 1.0), "la entrante queda opaca")
	assert(is_equal_approx(hud._hotbar.modulate.a, 1.0), "la saliente queda lista (opaca) para la próxima")

	hud.iniciar_transicion(false, 0.1)  # de vuelta a 1ª persona
	await get_tree().create_timer(0.3).timeout
	assert(hud._hotbar.visible and not hud._barra_modos.visible, "debe volver a 1ª persona")
	hud.queue_free()


func probar_barra_modos() -> void:
	print("=== TEST 3: BarraModos (menú de 3 niveles: Ver/Construir/Zonificar/Demoler → categoría → edificio) ===")
	var barra: Control = BarraModosScript.new()
	add_child(barra)
	assert(barra.boton_activo() == "ver", "sin modo debe estar activo Ver")
	assert(not barra.construccion_visible())
	# Las categorías de Construir van en un panel propio, a la derecha de la principal.
	assert(not barra._panel_categorias.visible)
	assert(barra._panel_categorias.get_parent() == barra and barra._panel_principal.get_parent() == barra)
	assert(barra._panel_principal.get_index() < barra._panel_categorias.get_index())

	barra.set_modo("zonificar")
	assert(barra.boton_activo() == "zonificar")
	barra.set_modo("demoler")
	assert(barra.boton_activo() == "demoler")
	barra.set_modo("")
	assert(barra.boton_activo() == "ver")

	print("=== TEST 3a: categorías de Construir, y sus edificios en el panel de la categoría activa ===")
	barra.set_modo("construir", "", "")
	assert(barra.boton_activo() == "construir" and barra.construccion_visible())
	assert(barra._panel_categorias.visible and barra.categoria_activa() == "")
	for id in barra._paneles_construccion:
		assert(not barra._paneles_construccion[id].visible, "sin categoría elegida, ningún panel de edificios se muestra (%s)" % id)

	barra.set_modo("construir", "maderero", "periferico")
	assert(barra.categoria_activa() == "periferico" and barra.construccion_activa() == "maderero")
	assert(barra._paneles_construccion["periferico"].visible)
	assert(not barra._paneles_construccion["residencial"].visible)
	assert(barra._botones_categoria["periferico"].button_pressed)
	assert(barra._botones_construccion["maderero"].button_pressed)

	barra.set_modo("construir", "residencial", "residencial")  # cambio directo de categoría, como al cambiar de puesto
	assert(barra.categoria_activa() == "residencial" and barra.construccion_activa() == "residencial")
	assert(barra._botones_construccion["residencial"].button_pressed)
	assert(not barra._paneles_construccion["periferico"].visible, "cambiar de categoría oculta el panel de la anterior")
	assert(not barra._botones.has("puestos"), "ya no hay botón Puestos")
	barra.set_modo("")
	assert(not barra.construccion_visible() and not barra._panel_categorias.visible)

	print("=== TEST 3a-bis: Investigación tiene la Escuela técnica; Industrial no tiene un botón con su propio id ===")
	barra.set_modo("construir", "", "investigacion")
	assert(barra._paneles_construccion["investigacion"].visible)
	assert(barra._botones_construccion.has("escuela_tecnica"), "Investigación ofrece la escuela técnica")
	assert(not barra._botones_construccion.has("industrial"), "no hay ningún tipo de edificio con id 'industrial'")
	barra.set_modo("")

	print("=== TEST 3b: Residencial atenuado sin blueprint, normal con uno declarado ===")
	assert(Blueprints.obtener("residencial_investigacion").is_empty(), "arranca vacío en esta escena de prueba")
	barra.set_modo("construir", "", "residencial")
	assert(barra._botones_construccion["residencial"].modulate.a < 1.0, "sin blueprint: atenuado")
	Blueprints.guardar({"zona_permitida": "residencial_investigacion", "ancho": 1, "profundidad": 1, "celdas_3d": {Vector3i.ZERO: "bloque_madera"}, "huella_relativa": [Vector2i.ZERO]})
	barra.set_modo("construir", "", "residencial")
	assert(barra._botones_construccion["residencial"].modulate.a == 1.0, "con blueprint declarado: ya no atenuado")

	print("\n=== TEST 3c: las miniaturas de construcción se generan con malla real y cambian con set_giros() ===")
	barra.set_giros(0)
	var miniatura_mina: TextureRect = barra._miniaturas_construccion["mina"]
	assert(miniatura_mina.texture != null, "mina tiene celdas con malla real: miniatura no vacía")
	var miniatura_residencial: TextureRect = barra._miniaturas_construccion["residencial"]
	assert(miniatura_residencial.texture != null, "con el blueprint de un solo bloque_madera declarado arriba, la miniatura no está vacía")
	barra.set_giros(1)
	assert(barra._giros_menu == 1)
	barra.set_giros(5)
	assert(barra._giros_menu == 1, "posmod(5, 4) == 1, mismo valor que antes: set_giros() normaliza a 0-3")

	print("\n=== TEST 3e: re-renderizar una miniatura libera el SubViewport anterior, no acumula uno por cada rotación ===")
	assert(barra._viewports_construccion.size() == 10, "una construcción con malla real por cada uno de los 10 tipos con miniatura (mina/caza/madera/pesca/las 4 refinerías/la escuela + residencial con el blueprint declarado arriba)")
	for giro in [2, 3, 0, 1, 2, 3]:
		barra.set_giros(giro)
	assert(barra._viewports_construccion.size() == 10, "sigue habiendo un solo SubViewport trackeado por tipo tras varias rotaciones, no uno acumulado por cada llamada")

	print("\n=== TEST 3f: cada edificio (incluido Residencial) anuncia su propia tecla numérica de categoría ===")
	var textos_residencial: Array = []
	for hijo in barra._botones_construccion["residencial"].get_children():
		for nieto in hijo.get_children():
			if nieto is Label:
				textos_residencial.append((nieto as Label).text)
	assert(textos_residencial == ["Residencial", "1"], "nombre y tecla (esquina inferior izquierda) por separado, salió: %s" % [textos_residencial])
	assert(barra._botones_construccion["refineria_tierras_raras"].custom_minimum_size.x >= barra._botones_construccion["siderurgica"].custom_minimum_size.x, "un nombre más largo no da un botón más angosto")

	barra.set_modo("")

	print("\n=== TEST 3d: _crear_boton() sin ícono se ve igual que antes; con ícono, antepone un TextureRect ===")
	var boton_sin_icono: Button = barra._crear_boton("Prueba", Vector2(88, 56))
	assert(boton_sin_icono.text == "Prueba", "sin ícono: el texto va directo en el Button, como siempre")
	var textura_prueba := PlaceholderTexture2D.new()
	var boton_con_icono: Button = barra._crear_boton("Prueba", Vector2(88, 56), textura_prueba)
	assert(boton_con_icono.text == "", "con ícono: el texto ya no va en el Button, va en un Label hijo")
	var encontro_icono := false
	for hijo in boton_con_icono.get_children():
		for nieto in hijo.get_children():
			if nieto is TextureRect and (nieto as TextureRect).texture == textura_prueba:
				encontro_icono = true
	assert(encontro_icono, "el TextureRect con la textura pasada está entre los descendientes del botón")

	# Un clic emite la señal; si quien la recibe no cambia el modo (p. ej.
	# Demoler todavía sin implementar del todo), la barra vuelve a reflejar el real.
	var pedidos: Array = []
	barra.modo_pedido.connect(func(modo: String) -> void: pedidos.append(modo))
	barra._botones["demoler"].button_pressed = true
	barra._botones["demoler"].pressed.emit()
	assert(pedidos == ["demoler"], "salió %s" % [pedidos])
	assert(barra.boton_activo() == "ver", "el botón debe volver al modo real, salió %s" % barra.boton_activo())
	assert(not barra._botones["demoler"].button_pressed, "el botón de Demoler no debe quedar marcado")

	print("\n=== TEST 3g: clic en una categoría emite categoria_pedida ===")
	var categorias_pedidas: Array = []
	barra.categoria_pedida.connect(func(categoria: String) -> void: categorias_pedidas.append(categoria))
	barra.set_modo("construir", "", "")
	barra._botones_categoria["vias"].pressed.emit()
	assert(categorias_pedidas == ["vias"], "salió %s" % [categorias_pedidas])

	var construcciones_pedidas: Array = []
	barra.construccion_pedida.connect(func(tipo: String) -> void: construcciones_pedidas.append(tipo))
	barra.set_modo("construir", "mina", "periferico")
	barra._botones_construccion["pesca_frutos_mar"].pressed.emit()
	assert(construcciones_pedidas == ["pesca_frutos_mar"], "salió %s" % [construcciones_pedidas])
	# Las zonas tienen su propio panel, solo visible con Zonificar activo.
	assert(not barra._panel_zonas.visible and not barra.zonificar_visible())
	assert(barra._panel_categorias.get_index() < barra._panel_zonas.get_index())
	barra.set_modo("zonificar", Zonificacion.ZONAS_PINTABLES[1])
	assert(barra._panel_zonas.visible and not barra._panel_categorias.visible)
	assert(barra.zona_activa() == Zonificacion.ZONAS_PINTABLES[1])
	assert(barra._botones_zona[Zonificacion.ZONAS_PINTABLES[1]].button_pressed)
	var zonas_pedidas: Array = []
	barra.zona_pedida.connect(func(tipo: String) -> void: zonas_pedidas.append(tipo))
	barra._botones_zona[Zonificacion.MARCADOR_BORRAR].pressed.emit()
	assert(zonas_pedidas == [Zonificacion.MARCADOR_BORRAR], "salió %s" % [zonas_pedidas])
	barra.set_modo("")
	assert(not barra._panel_zonas.visible and barra.zona_activa() == "")
	barra.queue_free()


func probar_hotbar() -> void:
	print("=== TEST 4: Hotbar ===")
	assert(HotbarScript.nombre_de("baul") == "Baúl")
	assert(HotbarScript.nombre_de("algo_nuevo") == "Algo Nuevo")

	var hotbar: PanelContainer = HotbarScript.new()
	add_child(hotbar)
	hotbar.configurar(["bloque_piedra", "puerta", "vidrio"])
	assert(hotbar.indice_seleccionado() == 0)
	hotbar.seleccionar(2)
	assert(hotbar.indice_seleccionado() == 2)
	# Fuera de rango: se ignora sin error.
	hotbar.seleccionar(7)
	hotbar.seleccionar(-1)
	assert(hotbar.indice_seleccionado() == 2)

	# Las cantidades están ocultas hasta que se llame set_cantidad()/actualizar_cantidades().
	assert(not hotbar.cantidad_visible(0))
	hotbar.set_cantidad(0, 32)
	assert(hotbar.cantidad_visible(0))
	hotbar.set_cantidad(0, -1)
	assert(not hotbar.cantidad_visible(0))
	hotbar.set_cantidad(9, 5)  # fuera de rango: ignora

	print("=== TEST 4b: Hotbar.actualizar_cantidades() muestra stock ÷ costo por NiveladorTerreno.COSTO_POR_CELDA ===")
	Ciudad.almacen["piedra"].cantidad = 12.0
	hotbar.actualizar_cantidades()
	assert(hotbar.cantidad_visible(0), "bloque_piedra (índice 0) tiene costo definido (5 piedra)")
	hotbar.queue_free()


func probar_formateadores_hud() -> void:
	print("=== TEST 5: formateadores de HUD.gd ===")
	assert(HUDScript.texto_tasas("mina", {}) == "Recolección prevista: sin recursos detectados")
	assert(HUDScript.texto_tasas("mina", {"hierro": 2.0}) == "Recolección prevista por ciudadano:\n  2.0 hierro/h")
	assert(HUDScript.texto_tasas("maderero", {"madera": 0.0}) == "Recolección prevista: sin árboles detectados")
	assert(HUDScript.texto_tasas("maderero", {"madera": 12.0}) == "Recolección prevista por ciudadano:\n  12.0 madera/h")
	assert(HUDScript.texto_tasas("caza_recoleccion", {"caza": 0.0, "recoleccion": 0.0}) == "Recolección prevista: sin fauna ni fruta detectada")
	assert(HUDScript.texto_tasas("caza_recoleccion", {"caza": 3.0, "recoleccion": 0.0}) == "Recolección prevista por ciudadano:\n  3.0 comida/h por caza\n  0.0 comida/h por recolección")
	# Pesca sin extremo de agua válido llega como diccionario vacío.
	assert(HUDScript.texto_tasas("pesca_frutos_mar", {}) == "Recolección prevista: sin agua detectada")
	assert(HUDScript.texto_tasas("pesca_frutos_mar", {"pesca": 1.5, "frutos_mar": 0.5}) == "Recolección prevista por ciudadano:\n  1.5 comida/h por pesca\n  0.5 comida/h por frutos del mar")


func probar_cara_apuntada() -> void:
	print("=== TEST 6: CaraApuntada ===")
	var cara: MeshInstance3D = CaraApuntadaScript.new()
	add_child(cara)
	assert(not cara.visible, "arranca oculta")

	# Cara superior de un bloque: el quad queda horizontal, apenas por encima.
	cara.mostrar_en(Vector3(1, 2, 3), Vector3.UP)
	assert(cara.visible)
	assert(cara.global_transform.basis.z.is_equal_approx(Vector3.UP), "salió %s" % cara.global_transform.basis.z)
	assert(cara.global_transform.origin.is_equal_approx(Vector3(1, 2 + CaraApuntadaScript.DESFASE, 3)), "salió %s" % cara.global_transform.origin)

	# Cara lateral: el quad se orienta según la normal, también en cada eje.
	cara.mostrar_en(Vector3(0, 0, 0), Vector3.RIGHT)
	assert(cara.global_transform.basis.z.is_equal_approx(Vector3.RIGHT))
	cara.mostrar_en(Vector3(0, 0, 0), Vector3.BACK)
	assert(cara.global_transform.basis.z.is_equal_approx(Vector3.BACK))
	cara.mostrar_en(Vector3(0, 0, 0), Vector3.DOWN)
	assert(cara.global_transform.basis.z.is_equal_approx(Vector3.DOWN))

	cara.ocultar()
	assert(not cara.visible)
	cara.queue_free()

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
	probar_barra_modos()
	probar_hotbar()
	probar_formateadores_hud()
	probar_cara_apuntada()


func probar_barra_superior_calculos() -> void:
	print("=== TEST 1a: BarraSuperior (cálculos estáticos) ===")
	assert(BarraSuperiorScript.texto_poblacion(38, 48) == "Población 38/48")
	assert(BarraSuperiorScript.fraccion_moral(Ciudad.BONO_MORAL_MAXIMO / 2.0) == 0.5)
	# Moral fuera de rango: la barra se acota a 0-1.
	assert(BarraSuperiorScript.fraccion_moral(-3.0) == 0.0)
	assert(BarraSuperiorScript.fraccion_moral(Ciudad.BONO_MORAL_MAXIMO * 4.0) == 1.0)
	assert(BarraSuperiorScript.texto_tasa(12.0) == "+12.0/h")
	assert(BarraSuperiorScript.texto_tasa(-3.0) == "-3.0/h")
	assert(BarraSuperiorScript.texto_tasa(0.0) == "+0.0/h")

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
	assert(barra.comida.text == "Comida 126 -5.0/h", "salió '%s'" % barra.comida.text)
	assert(barra.comida.get_theme_color("font_color") == BarraSuperiorScript.TemaHUD.INVALIDO)
	Ciudad.almacen["comida"].tasa_neta_promedio = 2.0
	barra.actualizar()
	assert(barra.comida.text == "Comida 126 +2.0/h", "salió '%s'" % barra.comida.text)
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


func probar_barra_modos() -> void:
	print("=== TEST 3: BarraModos ===")
	var barra: Control = BarraModosScript.new()
	add_child(barra)
	assert(barra.boton_activo() == "ver", "sin modo debe estar activo Ver")
	assert(not barra.puestos_visibles())
	# Los puestos van en una barra propia, a la derecha de la principal.
	assert(not barra._panel_sub.visible)
	assert(barra._panel_sub.get_parent() == barra and barra._panel_principal.get_parent() == barra)
	assert(barra._panel_principal.get_index() < barra._panel_sub.get_index())

	barra.set_modo("zonas")
	assert(barra.boton_activo() == "zonas")
	barra.set_modo("")
	assert(barra.boton_activo() == "ver")

	barra.set_modo("puestos", "maderero")
	assert(barra.boton_activo() == "puestos" and barra.puestos_visibles())
	assert(barra._panel_sub.visible)
	assert(barra.puesto_activo() == "maderero")
	barra.set_modo("puestos", "caza_recoleccion")  # cambio directo M -> H
	assert(barra.puesto_activo() == "caza_recoleccion")
	barra.set_modo("")
	assert(not barra.puestos_visibles() and not barra._panel_sub.visible)

	# Un clic emite la señal; si quien la recibe no cambia el modo (p. ej.
	# Construir sin blueprint guardado), la barra vuelve a reflejar el real.
	var pedidos: Array = []
	barra.modo_pedido.connect(func(modo: String) -> void: pedidos.append(modo))
	barra._botones["vias"].button_pressed = true
	barra._botones["vias"].pressed.emit()
	assert(pedidos == ["vias"], "salió %s" % [pedidos])
	assert(barra.boton_activo() == "ver", "el botón debe volver al modo real, salió %s" % barra.boton_activo())
	assert(not barra._botones["vias"].button_pressed, "el botón de Vías no debe quedar marcado")

	var puestos_pedidos: Array = []
	barra.puesto_pedido.connect(func(tipo: String) -> void: puestos_pedidos.append(tipo))
	barra.set_modo("puestos", "mina")
	barra._botones_puesto["pesca_frutos_mar"].pressed.emit()
	assert(puestos_pedidos == ["pesca_frutos_mar"], "salió %s" % [puestos_pedidos])
	# Las zonas tienen su propia subbarra, solo visible con Zonas activo.
	assert(not barra._panel_zonas.visible and not barra.zonas_visibles())
	assert(barra._panel_sub.get_index() < barra._panel_zonas.get_index())
	barra.set_modo("zonas", Zonificacion.ZONAS_PINTABLES[1])
	assert(barra._panel_zonas.visible and not barra._panel_sub.visible)
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
	hotbar.configurar(["pared", "puerta", "ventana"])
	assert(hotbar.indice_seleccionado() == 0)
	hotbar.seleccionar(2)
	assert(hotbar.indice_seleccionado() == 2)
	# Fuera de rango: se ignora sin error.
	hotbar.seleccionar(7)
	hotbar.seleccionar(-1)
	assert(hotbar.indice_seleccionado() == 2)

	# Las cantidades están ocultas hasta que el inventario las aporte.
	assert(not hotbar.cantidad_visible(0))
	hotbar.set_cantidad(0, 32)
	assert(hotbar.cantidad_visible(0))
	hotbar.set_cantidad(0, -1)
	assert(not hotbar.cantidad_visible(0))
	hotbar.set_cantidad(9, 5)  # fuera de rango: ignora
	hotbar.queue_free()


func probar_formateadores_hud() -> void:
	print("=== TEST 5: formateadores de HUD.gd ===")
	assert(HUDScript.costo_de_puesto("mina") == Recoleccion.COSTO_CONSTRUCCION)
	assert(HUDScript.costo_de_puesto("maderero") == Recoleccion.COSTO_CONSTRUCCION_MADERERO)
	assert(HUDScript.costo_de_puesto("desconocido").is_empty())

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

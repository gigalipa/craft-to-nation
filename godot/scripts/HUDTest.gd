extends Node

## Pruebas de los widgets del HUD por modos (mismo patrón que PuertasTest.gd).
## Corre HUDTest.tscn y revisa el panel "Output": debe imprimir todas las
## pruebas y la línea final, sin ningún error de assert().
## Ver docs/superpowers/specs/2026-09-25-hud-por-modos-design.md.

const BarraSuperiorScript = preload("res://scripts/BarraSuperior.gd")
const PanelContextualScript = preload("res://scripts/PanelContextual.gd")
const BarraModosScript = preload("res://scripts/BarraModos.gd")
const HotbarScript = preload("res://scripts/Hotbar.gd")


func _ready() -> void:
	ejecutar_pruebas()
	print("HUDTest: todas las pruebas pasaron")


func ejecutar_pruebas() -> void:
	probar_barra_superior()
	probar_panel_contextual()
	probar_barra_modos()
	probar_hotbar()


func probar_barra_superior() -> void:
	print("=== TEST 1: BarraSuperior ===")
	assert(BarraSuperiorScript.texto_poblacion(38, 48) == "Población 38/48")
	assert(BarraSuperiorScript.fraccion_moral(Ciudad.BONO_MORAL_MAXIMO / 2.0) == 0.5)
	# Moral fuera de rango: la barra se acota a 0-1.
	assert(BarraSuperiorScript.fraccion_moral(-3.0) == 0.0)
	assert(BarraSuperiorScript.fraccion_moral(Ciudad.BONO_MORAL_MAXIMO * 4.0) == 1.0)

	var barra: PanelContainer = BarraSuperiorScript.new()
	# Una clave que no está en el almacén muestra 0 en vez de fallar.
	barra.recursos = ["comida", "inexistente"]
	add_child(barra)
	Ciudad.almacen["comida"].cantidad = 126.0
	barra.actualizar()
	assert(barra.texto_de("comida") == "Comida 126", "salió '%s'" % barra.texto_de("comida"))
	assert(barra.texto_de("inexistente") == "Inexistente 0", "salió '%s'" % barra.texto_de("inexistente"))
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


func probar_barra_modos() -> void:
	print("=== TEST 3: BarraModos ===")
	var barra: PanelContainer = BarraModosScript.new()
	add_child(barra)
	assert(barra.boton_activo() == "ver", "sin modo debe estar activo Ver")
	assert(not barra.puestos_visibles())

	barra.set_modo("zonas")
	assert(barra.boton_activo() == "zonas")
	barra.set_modo("")
	assert(barra.boton_activo() == "ver")

	barra.set_modo("puestos", "maderero")
	assert(barra.boton_activo() == "puestos" and barra.puestos_visibles())
	assert(barra.puesto_activo() == "maderero")
	barra.set_modo("puestos", "caza_recoleccion")  # cambio directo M -> H
	assert(barra.puesto_activo() == "caza_recoleccion")
	barra.set_modo("")
	assert(not barra.puestos_visibles())

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

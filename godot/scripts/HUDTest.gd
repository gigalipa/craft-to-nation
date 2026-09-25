extends Node

## Pruebas de los widgets del HUD por modos (mismo patrón que PuertasTest.gd).
## Corre HUDTest.tscn y revisa el panel "Output": debe imprimir todas las
## pruebas y la línea final, sin ningún error de assert().
## Ver docs/superpowers/specs/2026-09-25-hud-por-modos-design.md.

const BarraSuperiorScript = preload("res://scripts/BarraSuperior.gd")
const PanelContextualScript = preload("res://scripts/PanelContextual.gd")


func _ready() -> void:
	ejecutar_pruebas()
	print("HUDTest: todas las pruebas pasaron")


func ejecutar_pruebas() -> void:
	probar_barra_superior()
	probar_panel_contextual()


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

extends Node

## Pruebas de los widgets del HUD por modos (mismo patrón que PuertasTest.gd).
## Corre HUDTest.tscn y revisa el panel "Output": debe imprimir todas las
## pruebas y la línea final, sin ningún error de assert().
## Ver docs/superpowers/specs/2026-09-25-hud-por-modos-design.md.

const BarraSuperiorScript = preload("res://scripts/BarraSuperior.gd")


func _ready() -> void:
	ejecutar_pruebas()
	print("HUDTest: todas las pruebas pasaron")


func ejecutar_pruebas() -> void:
	probar_barra_superior()


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

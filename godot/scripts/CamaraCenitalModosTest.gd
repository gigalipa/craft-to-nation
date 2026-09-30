extends Node

## Pruebas de _alternar_modo_menu_construir()/_salir_de_modo_menu_construir()
## (tecla B / botón "Construir" de BarraModos, desacoplados de activar una
## colocación — ver docs/superpowers/specs/2026-09-30-previsualizacion-
## construcciones-cenital-design.md, Sección 6). Solo cubre el camino "abrir
## el menú vacío / cerrarlo de nuevo": el camino que cancela una colocación
## YA activa (mina/blueprint en curso) necesita overlay/nivelador reales, no
## una CamaraCenital sin árbol (mismo motivo que PlantillasPuestoTest.gd no
## instancia el mundo completo) — ese camino se verifica jugando, ver Task 5
## del plan. Corre esta escena y revisa el panel "Output": debe imprimir
## todas las pruebas y la línea final, sin ningún error de assert().

const CamaraCenitalScript = preload("res://scripts/CamaraCenital.gd")
const HUDScript = preload("res://scripts/HUD.gd")


func _ready() -> void:
	ejecutar_pruebas()


func _camara() -> Camera3D:
	var camara: Camera3D = CamaraCenitalScript.new()
	camara.hud = HUDScript.new()
	return camara


func ejecutar_pruebas() -> void:
	print("=== TEST 1: primera pulsación abre el menú sin activar ninguna colocación ===")
	var camara: Camera3D = _camara()
	assert(not camara._menu_construir_abierto)
	camara._alternar_modo_menu_construir()
	assert(camara._menu_construir_abierto, "el menú queda marcado como abierto")
	assert(not camara.modo_colocar_blueprint, "abrir el menú NO activa la colocación de Residencial")
	assert(not camara.modo_colocar_puesto, "abrir el menú NO activa la colocación de un puesto")
	camara.hud.queue_free()

	print("\n=== TEST 2: segunda pulsación con el menú abierto y nada activo lo cierra ===")
	var camara2: Camera3D = _camara()
	camara2._alternar_modo_menu_construir()
	camara2._alternar_modo_menu_construir()
	assert(not camara2._menu_construir_abierto, "segunda pulsación cierra el menú")
	assert(not camara2.modo_colocar_blueprint and not camara2.modo_colocar_puesto)
	camara2.hud.queue_free()

	print("\n=== TEST 3: _giros_menu se reinicia a 0 cada vez que se abre el menú ===")
	var camara3: Camera3D = _camara()
	camara3._alternar_modo_menu_construir()
	assert(camara3.hud._barra_modos._giros_menu == 0, "el HUD recibe 0 al abrir")
	camara3.hud.queue_free()

	print("\n=== Las 3 pruebas de CamaraCenitalModosTest pasaron correctamente ===")

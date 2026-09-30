extends Node

## Pruebas de _alternar_modo_menu_construir()/_salir_de_modo_menu_construir()
## y de la navegación por categorías del menú Construir (tecla `1` / botón
## "Construir" de BarraModos, desacoplados de activar una colocación — ver
## docs/superpowers/specs/2026-09-30-previsualizacion-construcciones-cenital-
## design.md, Sección 6, y el rediseño a menú numérico de 3 niveles). Solo
## cubre el camino "abrir el menú vacío / cerrarlo de nuevo / elegir una
## categoría": el camino que cancela una colocación YA activa (mina/blueprint
## en curso) necesita overlay/nivelador reales, no una CamaraCenital sin árbol
## (mismo motivo que PlantillasPuestoTest.gd no instancia el mundo completo) —
## ese camino se verifica jugando, ver Task 5 del plan. Corre esta escena y
## revisa el panel "Output": debe imprimir todas las pruebas y la línea final,
## sin ningún error de assert().

const CamaraCenitalScript = preload("res://scripts/CamaraCenital.gd")
const HUDScript = preload("res://scripts/HUD.gd")
const NivelacionOverlayScript = preload("res://scripts/NivelacionOverlay.gd")
const ZonaOverlayScript = preload("res://scripts/ZonaOverlay.gd")
const ViaPreviewOverlayScript = preload("res://scripts/ViaPreviewOverlay.gd")


func _ready() -> void:
	ejecutar_pruebas()


## salir_de_todos_los_modos() llama sin condición a _overlay_nivelacion.
## ocultar()/overlay.limpiar_previsualizacion()/via_preview.limpiar() (para
## limpiar cualquier resto visual, haya estado activo ese modo o no) — en el
## juego real siempre existen porque _ready() los crea; aquí, sin árbol,
## hace falta plantarlos a mano con las clases reales (ninguna de las tres
## toca el árbol de escena en esos métodos, solo listas internas propias).
func _camara() -> Camera3D:
	var camara: Camera3D = CamaraCenitalScript.new()
	camara.hud = HUDScript.new()
	camara._overlay_nivelacion = NivelacionOverlayScript.new()
	camara.overlay = ZonaOverlayScript.new()
	camara.via_preview = ViaPreviewOverlayScript.new()
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

	print("\n=== TEST 3: _giros_menu se reinicia a 0 cada vez que se abre el menú (partiendo de un giro != 0) ===")
	var camara3: Camera3D = _camara()
	camara3.hud.set_giros_construccion(2)
	assert(camara3.hud._barra_modos._giros_menu == 2, "arranca en 2 para que el reinicio a 0 sea observable")
	camara3._alternar_modo_menu_construir()
	assert(camara3.hud._barra_modos._giros_menu == 0, "el HUD recibe 0 al abrir")
	camara3.hud.queue_free()

	print("\n=== TEST 4: Esc (salir_de_todos_los_modos) cierra el HUD aunque el menú estuviera abierto sin nada activo ===")
	var camara4: Camera3D = _camara()
	camara4._alternar_modo_menu_construir()
	assert(camara4.hud._barra_modos.boton_activo() == "construir", "el HUD muestra Construir con el menú abierto")
	camara4.salir_de_todos_los_modos()
	assert(not camara4._menu_construir_abierto, "Esc también suelta el flag")
	assert(camara4.hud._barra_modos.boton_activo() == "ver", "Esc debe devolver el HUD a Ver, no dejarlo en Construir")
	camara4.hud.queue_free()

	print("\n=== TEST 5: entrar a Zonificar con el menú Construir abierto suelta el flag, y una tecla `1` posterior no cierra Zonificar a ciegas ===")
	var camara5: Camera3D = _camara()
	camara5._alternar_modo_menu_construir()
	camara5._alternar_modo_zonificar()
	assert(not camara5._menu_construir_abierto, "entrar a Zonificar debe soltar el flag del menú Construir")
	assert(camara5.modo_zonificar, "Zonificar queda activo")
	assert(camara5.hud._barra_modos.boton_activo() == "zonificar", "el HUD muestra Zonificar, no Construir")
	camara5._alternar_modo_menu_construir()
	assert(not camara5.modo_zonificar, "la tecla `1` debe salir de Zonificar al entrar de nuevo a Construir")
	assert(camara5._menu_construir_abierto, "y abrir el menú Construir")
	assert(camara5.hud._barra_modos.boton_activo() == "construir")
	camara5.hud.queue_free()

	print("\n=== TEST 6: elegir una categoría abre su panel de edificios sin activar ninguna colocación ===")
	var camara6: Camera3D = _camara()
	camara6._alternar_modo_menu_construir()
	camara6._elegir_categoria("periferico")
	assert(camara6._menu_construir_abierto, "elegir una categoría no cierra el menú Construir")
	assert(camara6.hud._barra_modos.categoria_activa() == "periferico")
	assert(not camara6.modo_colocar_puesto and not camara6.modo_colocar_blueprint and not camara6.modo_trazar_via, "elegir la categoría NO activa ninguna colocación todavía")
	camara6.hud.queue_free()

	print("\n=== TEST 7: elegir la misma categoría de nuevo colapsa a la lista de categorías (sin nada activo) ===")
	var camara7: Camera3D = _camara()
	camara7._alternar_modo_menu_construir()
	camara7._elegir_categoria("periferico")
	camara7._elegir_categoria("periferico")
	assert(camara7._menu_construir_abierto, "colapsar a la lista de categorías no cierra todo el menú Construir")
	assert(camara7.hud._barra_modos.categoria_activa() == "", "vuelve a la lista de categorías")
	camara7.hud.queue_free()

	print("\n=== TEST 8: elegir otra categoría cambia directamente, sin cerrar el menú ===")
	var camara8: Camera3D = _camara()
	camara8._alternar_modo_menu_construir()
	camara8._elegir_categoria("periferico")
	camara8._elegir_categoria("residencial")
	assert(camara8._menu_construir_abierto)
	assert(camara8.hud._barra_modos.categoria_activa() == "residencial")
	camara8.hud.queue_free()

	print("\n=== TEST 9: Vías es una categoría de Construir — activarla mantiene el flag del menú (no es un modo hermano) ===")
	var camara9: Camera3D = _camara()
	camara9._alternar_modo_menu_construir()
	camara9._elegir_categoria("vias")
	camara9._alternar_modo_trazar_via()
	assert(camara9.modo_trazar_via, "Vías queda activo")
	assert(camara9._menu_construir_abierto, "Vías es parte de Construir: el flag del menú sigue activo")
	assert(camara9.hud._barra_modos.boton_activo() == "construir", "el HUD muestra Construir, no un modo aparte")
	assert(camara9.hud._barra_modos.categoria_activa() == "vias")
	camara9.hud.queue_free()

	print("\n=== TEST 10: Demoler es un modo hermano de Construir/Zonificar, sin submenú ===")
	var camara10: Camera3D = _camara()
	camara10._alternar_modo_menu_construir()
	camara10._alternar_modo_demoler()
	assert(not camara10._menu_construir_abierto, "entrar a Demoler debe soltar el flag del menú Construir")
	assert(camara10.modo_demoler, "Demoler queda activo")
	assert(camara10.hud._barra_modos.boton_activo() == "demoler")
	camara10._alternar_modo_demoler()
	assert(not camara10.modo_demoler, "la misma tecla lo desactiva")
	assert(camara10.hud._barra_modos.boton_activo() == "ver")
	camara10.hud.queue_free()

	print("\n=== Las 10 pruebas de CamaraCenitalModosTest pasaron correctamente ===")

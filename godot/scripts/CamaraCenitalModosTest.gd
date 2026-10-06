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


## Mundo mínimo: la cámara solo le pide altura_en(x, z).
class MundoFalso extends Node:
	func altura_en(_x: int, _z: int) -> int:
		return 12
	func id_de_edificio(_celda: Vector3i) -> int:
		return -1


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

	print("\n=== TEST 11: centrar_en_edificio lleva el foco al centro del edificio, a la altura del suelo ahí ===")
	var camara11: Camera3D = _camara()
	camara11.mundo = MundoFalso.new()
	var esquina11 := Vector2i(700, 710)
	Economia.registrar_puesto(esquina11, "mina", 5, 3, {})
	var destino11: Vector3 = camara11._destino_foco_de(esquina11)
	assert(destino11 == Vector3(702.5, 12.0, 711.5), "salió %s" % destino11)
	camara11.angulo_orbital = 1.0
	camara11.distancia_camara = 33.0
	camara11.centrar_en_edificio(esquina11)  # sin árbol no hay tween: aplica el destino directo
	assert(camara11.foco == destino11, "salió %s" % camara11.foco)
	assert(camara11.angulo_orbital == 1.0 and camara11.distancia_camara == 33.0, "conserva órbita y distancia")
	camara11.centrar_en_edificio(Vector2i(-5, -5))  # sin puesto en esa esquina: no hace nada
	assert(camara11.foco == destino11)
	Economia.puestos.erase(esquina11)
	camara11.hud.queue_free()

	print("\n=== TEST 12: Navegación de menús con Z/X y paginación con máx 10 items ===")
	var camara12: Camera3D = _camara()
	assert(camara12._digito_de_tecla(KEY_0) == 10, "KEY_0 mapea a 10")
	camara12._alternar_modo_menu_construir()
	camara12._manejar_tecla_construir(1)
	assert(camara12._categoria_construir == "residencial")
	camara12._manejar_tecla_z()
	assert(camara12._categoria_construir == "" and camara12._menu_construir_abierto)
	camara12._manejar_tecla_z()
	assert(not camara12._menu_construir_abierto and camara12.hud._barra_modos.boton_activo() == "ver")

	camara12._alternar_modo_menu_construir()
	camara12._elegir_categoria("industrial")
	assert(camara12.hud.pagina_actual("industrial") == 1)
	assert(camara12.hud._barra_modos.ITEMS_POR_PAGINA == 10)
	camara12.hud._barra_modos._paginas["industrial"] = 2
	assert(camara12.hud.pagina_actual("industrial") == 2)
	camara12._manejar_tecla_z()
	assert(camara12.hud.pagina_actual("industrial") == 1 and camara12._categoria_construir == "industrial")
	camara12._manejar_tecla_z()
	assert(camara12._categoria_construir == "" and camara12._menu_construir_abierto)
	camara12.hud.queue_free()

	print("\n=== TEST 13: Visibilidad condicionada de zonas pintadas ===")
	var camara13: Camera3D = _camara()
	assert(not camara13.overlay.mostrar_zonas, "arranca oculto en Ver")
	camara13._alternar_modo_zonificar()
	assert(camara13.overlay.mostrar_zonas, "zonas visibles en Zonificar")
	camara13._salir_de_modo_zonificar()
	assert(not camara13.overlay.mostrar_zonas, "zonas ocultas tras salir de Zonificar")

	camara13._alternar_modo_menu_construir()
	camara13._elegir_categoria("periferico")
	assert(not camara13.overlay.mostrar_zonas, "zonas ocultas en Periférico")
	camara13._elegir_categoria("vias")
	assert(not camara13.overlay.mostrar_zonas, "zonas ocultas en Vías")
	camara13._elegir_categoria("residencial")
	assert(camara13.overlay.mostrar_zonas, "zonas visibles en Residencial")
	camara13._elegir_categoria("industrial")
	assert(camara13.overlay.mostrar_zonas, "zonas visibles en Industrial")
	camara13._elegir_categoria("investigacion")
	assert(camara13.overlay.mostrar_zonas, "zonas visibles en Investigación")
	camara13._manejar_tecla_z()
	assert(not camara13.overlay.mostrar_zonas, "zonas ocultas en menú de categorías")
	camara13.hud.queue_free()

	print("\n=== TEST 14: _huella_choca_con_otro_puesto no rechaza por bloques de nivelación huérfanos/en cola ===")
	var camara14: Camera3D = _camara()
	var mundo14 := MundoFalso.new()
	camara14.mundo = mundo14
	var cols: Array[Vector2i] = [Vector2i(0, 0)]
	assert(not camara14._huella_choca_con_otro_puesto(Vector2i(0, 0), cols), "bloques de nivelación no causan choque")
	camara14.hud.queue_free()
	mundo14.free()

	print("\n=== TEST 15: _cancelar_tramo_via limpia tramos fijos, estado y cache de previsualizacion ===")
	var camara15: Camera3D = _camara()
	var mundo15 := MundoFalso.new()
	camara15.mundo = mundo15
	camara15._alternar_modo_trazar_via()
	assert(camara15.modo_trazar_via, "modo trazar vía activo")
	camara15._hay_tramo_en_curso = true
	var tramo_prueba: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 1)]
	camara15._tramos_fijos.append(tramo_prueba)
	camara15._ultimo_origen_preview = Vector2i(0, 0)
	camara15._ultimo_vertice_preview = Vector2i(1, 1)
	assert(camara15._vertice_pertenece_a_via(Vector2i(0, 0)), "el vertice pertenecia al tramo acumulado antes de cancelar")

	camara15._cancelar_tramo_via()
	assert(not camara15._hay_tramo_en_curso, "ya no hay tramo en curso tras cancelar")
	assert(camara15._tramos_fijos.is_empty(), "_tramos_fijos debe quedar vacio tras cancelar")
	assert(camara15._ultimo_origen_preview == CamaraCenitalScript.SIN_VERTICE_PREVIO, "cache de origen reiniciada")
	assert(camara15._ultimo_vertice_preview == CamaraCenitalScript.SIN_VERTICE_PREVIO, "cache de vertice reiniciada")
	assert(not camara15._vertice_pertenece_a_via(Vector2i(0, 0)), "el vertice ya no pertenece a ninguna via acumulada")
	camara15.hud.queue_free()
	mundo15.free()

	print("\n=== TEST 16: salir de modo colocar puesto o vias con cerrar_menu=false oculta el contexto ===")
	var camara16: Camera3D = _camara()
	var mundo16 := MundoFalso.new()
	camara16.mundo = mundo16
	camara16._alternar_modo_trazar_via()
	assert(camara16.hud._contexto.visible, "el contexto se mostro al iniciar trazar vias")
	camara16._salir_de_modo_trazar_via(false)
	assert(not camara16.hud._contexto.visible, "el contexto se oculta al salir del modo vias aunque cerrar_menu=false")
	camara16.hud.queue_free()
	mundo16.free()

	print("\n=== TEST 17: zonificacion muestra instrucciones de clicks y actualiza al marcar primera esquina ===")
	var camara17: Camera3D = _camara()
	var mundo17 := MundoFalso.new()
	camara17.mundo = mundo17
	camara17._alternar_modo_zonificar()
	assert(camara17.hud._contexto.visible, "contexto visible al zonificar")
	assert("FIJAR ESQUINA" in camara17.hud._contexto.acciones.text, "muestra fijar esquina inicialmente")
	camara17.esperando_segunda_esquina = true
	camara17._mostrar_contexto_zona()
	assert("CONFIRMAR ÁREA" in camara17.hud._contexto.acciones.text, "muestra confirmar area tras primer clic")
	camara17._cancelar_pintado_zona()
	assert(not camara17.esperando_segunda_esquina)
	assert("FIJAR ESQUINA" in camara17.hud._contexto.acciones.text, "vuelve a fijar esquina al cancelar")
	camara17.hud.queue_free()
	mundo17.free()

	print("\n=== Las 17 pruebas de CamaraCenitalModosTest pasaron correctamente ===")

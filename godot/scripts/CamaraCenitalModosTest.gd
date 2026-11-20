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
const ViaDemolicionOverlayScript = preload("res://scripts/ViaDemolicionOverlay.gd")



## Mundo mínimo: la cámara solo le pide altura_en(x, z).
class MundoFalso extends Node:
	var ANCHO_MUNDO: int = 64
	var LARGO_MUNDO: int = 64
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
	camara.via_demolicion_overlay = ViaDemolicionOverlayScript.new()
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
	print("\n=== TEST 18: modo demolición contextual (edificios y vías guiadas) ===")
	var camara18: Camera3D = _camara()
	var mundo18 := MundoFalso.new()
	camara18.mundo = mundo18

	# Activar modo demoler
	camara18._alternar_modo_demoler()
	assert(camara18.modo_demoler)
	assert(camara18.hud._contexto.visible)
	assert("MARCAR PARA DEMOLICIÓN" in camara18.hud._contexto.acciones.text)

	# Iniciar demolición de vía
	var celda_inicio := Vector3i(10, 0, 10)
	camara18._iniciar_demolicion_via(celda_inicio)
	assert(camara18._demolicion_via_activa)
	assert(camara18.via_demolicion_overlay.cantidad_celdas == 1)
	assert("CONFIRMAR DEMOLICIÓN" in camara18.hud._contexto.acciones.text)

	# Cancelar demolición de vía
	camara18._cancelar_demolicion_via()
	assert(not camara18._demolicion_via_activa)
	assert(camara18.via_demolicion_overlay.cantidad_celdas == 0)

	# Salir de modo demoler
	camara18._salir_de_modo_demoler()
	assert(not camara18.modo_demoler)
	assert(not camara18.hud._contexto.visible)

	camara18.hud.queue_free()
	mundo18.free()

	print("\n=== TEST 19: Categoría Ductos (6), acueducto (6-1) y tubería (6-2) ===")
	var camara19: Camera3D = _camara()
	var mundo19 := MundoFalso.new()
	camara19.mundo = mundo19
	camara19._alternar_modo_menu_construir()
	camara19._manejar_tecla_construir(6)
	assert(camara19.hud._barra_modos.categoria_activa() == "ductos", "tecla 6 abre categoria ductos")

	# Tecla 1 dentro de ductos: activa acueducto
	camara19._manejar_tecla_construir(1)
	assert(camara19.modo_trazar_ducto, "activa modo trazar ducto")
	assert(camara19._tipo_ducto_activo == "acueducto", "tipo activo es acueducto")
	assert(camara19.hud._barra_modos.categoria_activa() == "ductos")

	# Tecla 2 dentro de ductos: cambia a tubería
	camara19._manejar_tecla_construir(2)
	assert(camara19.modo_trazar_ducto, "sigue en modo trazar ducto")
	assert(camara19._tipo_ducto_activo == "tuberia", "tipo activo es tuberia")

	# Clic en botón acueducto y tubería desde el HUD
	camara19._on_construccion_pedida("acueducto")
	assert(camara19.modo_trazar_ducto and camara19._tipo_ducto_activo == "acueducto", "clic activa acueducto")
	camara19._on_construccion_pedida("tuberia")
	assert(camara19.modo_trazar_ducto and camara19._tipo_ducto_activo == "tuberia", "clic activa tuberia")

	print("\n=== TEST 20: Trazado interactivo de ductos, camino ortogonal y cancelación ===")
	var camara20: Camera3D = _camara()
	var mundo20 := MundoFalso.new()
	camara20.mundo = mundo20
	camara20._alternar_modo_trazar_ducto("acueducto")
	assert(camara20.modo_trazar_ducto)
	assert(not camara20._hay_tramo_ducto_en_curso)

	# Camino ortogonal
	var camino: Array = camara20._camino_ortogonal(Vector2i(0, 0), Vector2i(3, 2))
	assert(camino[0] == Vector2i(0, 0))
	assert(camino[-1] == Vector2i(3, 2))
	assert(camino.size() == 6, "camino Manhattan de (0,0) a (3,2) tiene 6 celdas")

	# Simular fijar primer punto
	camara20._punto_inicio_ducto = Vector2i(0, 0)
	var pts: Array[Vector2i] = [Vector2i(0, 0)]
	camara20._puntos_fijos_ducto = pts
	camara20._hay_tramo_ducto_en_curso = true

	# Cancelar tramo
	camara20._cancelar_tramo_ducto()
	assert(not camara20._hay_tramo_ducto_en_curso)
	assert(camara20._puntos_fijos_ducto.is_empty())

	camara20.hud.queue_free()
	mundo20.free()

	print("\n=== TEST 21: _refinar_foco_por_mira() y órbita/inclinación con foco fuera del mundo o fuera de rango ===")
	var camara21: Camera3D = _camara()
	var mundo21 := MundoFalso.new()
	camara21.mundo = mundo21

	# Fuera del árbol _refinar_foco_por_mira() debe devolver false de forma segura sin lanzar errores
	assert(not camara21._refinar_foco_por_mira(), "sin viewport ni world3d devuelve false de forma segura")

	# Simular foco fuera del mundo (p. ej. X < 0 o Z < 0 tras paneo)
	var foco_inicial := Vector3(-20.0, 15.0, -20.0)
	camara21.foco = foco_inicial
	camara21.distancia_camara = 25.0
	camara21.angulo_inclinacion = deg_to_rad(45.0)
	camara21.angulo_orbital = 0.0

	var pos_antes: Vector3 = camara21._posicion_ideal()
	# Simular inicio de gesto de órbita (Q/E) con foco apuntando fuera del mundo
	camara21._refinar_foco_por_mira()
	var foco_post: Vector3 = camara21.foco
	var distancia_post: float = camara21.distancia_camara

	assert(foco_post == foco_inicial, "foco no cambia si apunta fuera del mundo o sin impacto")
	assert(distancia_post == 25.0, "distancia_camara no sufre clamp desfasado")

	# Al orbitar (girar angulo_orbital), la altura Y de la cámara debe mantenerse exactamente constante
	camara21.angulo_orbital += deg_to_rad(45.0)
	var pos_despues: Vector3 = camara21._posicion_ideal()
	assert(is_equal_approx(pos_antes.y, pos_despues.y), "la altura Y de la camara se conserva exactamente al orbitar fuera del mundo")

	# Al inclinar (Ctrl+W/S), el radio de la esfera se mantiene constante sin saltos bruscos
	var dist_a_foco: float = pos_despues.distance_to(foco_post)
	assert(is_equal_approx(dist_a_foco, 25.0), "la distancia al foco se mantiene en el radio orbital")

	camara21.hud.queue_free()
	mundo21.free()

	print("\n=== TEST 22: Selección por recuadro 2D (solo militares), K+clic der. atacar, H mantener y Esc ===")
	var raiz22 := Node.new()
	add_child(raiz22)
	var mundo22 := MundoFalso.new()
	mundo22.name = "VoxelWorld"
	raiz22.add_child(mundo22)
	var ov_zona22: Node3D = ZonaOverlayScript.new()
	ov_zona22.name = "ZonaOverlay"
	raiz22.add_child(ov_zona22)
	var ov_via22: Node3D = ViaPreviewOverlayScript.new()
	ov_via22.name = "ViaPreviewOverlay"
	raiz22.add_child(ov_via22)
	var hud22: CanvasLayer = HUDScript.new()
	hud22.name = "HUDLayer"
	raiz22.add_child(hud22)
	var player_falso := CharacterBody3D.new()
	player_falso.name = "Player"
	raiz22.add_child(player_falso)
	var camara22: Camera3D = CamaraCenitalScript.new()
	raiz22.add_child(camara22)
	camara22.current = true
	camara22.hud.set_vista(false)
	camara22.global_position = Vector3(2.0, 18.0, 10.0)
	camara22.look_at(Vector3(2.0, 1.5, 2.0), Vector3.UP)

	var id_civ22: int = Colonos.agregar_colono("obrero", Vector3i(1, 1, 2), -1)
	var id_m1_22: int = Colonos.agregar_colono("militar", Vector3i(2, 1, 2), -1)
	var id_m2_22: int = Colonos.agregar_colono("militar", Vector3i(30, 1, -20), -1)

	var p_m1: Vector2 = camara22.unproject_position(Colonos.colonos[id_m1_22]["posicion"])
	var rect_sel := Rect2(p_m1 - Vector2(20, 20), Vector2(40, 40))
	camara22._seleccionar_militares_en_recuadro(rect_sel, false)
	assert(Colonos.unidades_seleccionadas == [id_m1_22], "recuadro 2D selecciona solo militar dentro del rectángulo (excluye civil y militar lejano): %s" % str(Colonos.unidades_seleccionadas))

	# Shift + recuadro añade/conserva sin perder id_m1_22
	var p_m2: Vector2 = camara22.unproject_position(Colonos.colonos[id_m2_22]["posicion"])
	camara22._seleccionar_militares_en_recuadro(Rect2(p_m2 - Vector2(20, 20), Vector2(40, 40)), true)
	assert(Colonos.unidades_seleccionadas.has(id_m1_22) and Colonos.unidades_seleccionadas.has(id_m2_22), "Shift+recuadro añade segundo militar a la selección")

	# Tecla K activa submodo atacar; primer Esc cancela K pero conserva tropa
	var ev_k := InputEventKey.new()
	ev_k.keycode = KEY_K
	ev_k.pressed = true
	camara22._unhandled_input(ev_k)
	assert(camara22._submodo_orden_cenital == "atacar", "tecla K activa submodo atacar en Modo Ver")

	var ev_esc := InputEventKey.new()
	ev_esc.keycode = KEY_ESCAPE
	ev_esc.pressed = true
	camara22._unhandled_input(ev_esc)
	assert(camara22._submodo_orden_cenital == "", "primer Esc cancela submodo K")
	assert(Colonos.unidades_seleccionadas.size() == 2, "primer Esc conserva selección militar")

	# K + clic derecho sobre celda ejecuta orden atacar incluso hacia coordenada/edificio propio
	camara22._unhandled_input(ev_k)
	var ev_rclick := InputEventMouseButton.new()
	ev_rclick.button_index = MOUSE_BUTTON_RIGHT
	ev_rclick.pressed = true
	ev_rclick.position = p_m1
	camara22._unhandled_input(ev_rclick)
	assert(Colonos.colonos[id_m1_22]["orden_militar"].get("tipo", "") == "atacar", "K + clic der. ordena atacar")
	assert(camara22._submodo_orden_cenital == "", "submodo K se limpia tras ejecutar ataque")

	# Tecla H ordena mantener posición
	var ev_h := InputEventKey.new()
	ev_h.keycode = KEY_H
	ev_h.pressed = true
	camara22._unhandled_input(ev_h)
	assert(Colonos.colonos[id_m1_22]["orden_militar"].get("tipo", "") == "mantener", "tecla H ordena mantener posición")

	# Esc en Modo Ver con selección la limpia
	camara22._unhandled_input(ev_esc)
	assert(Colonos.unidades_seleccionadas.is_empty(), "Esc limpia selección de unidades en Modo Ver")

	for cid in [id_civ22, id_m1_22, id_m2_22]:
		var cel: Vector3i = Colonos.colonos[cid]["celda"]
		Colonos.ocupadas.erase(cel)
		Colonos.colonos.erase(cid)
	raiz22.queue_free()

	print("\n=== TEST 23: Categoría Militar (7) separada de Industrial, cuartel (7-1) y zona industrial/militar ===")
	var camara23: Camera3D = _camara()
	var mundo23 := MundoFalso.new()
	camara23.mundo = mundo23
	assert(not CamaraCenitalScript.PUESTOS_INDUSTRIAL.has("cuartel"), "cuartel no está en PUESTOS_INDUSTRIAL")
	assert(camara23._categoria_de_puesto("cuartel") == "militar", "cuartel pertenece a la categoría militar")
	camara23._alternar_modo_menu_construir()
	camara23._manejar_tecla_construir(7)
	assert(camara23._categoria_construir == "militar", "tecla 7 abre la categoría militar")
	assert(camara23.hud._barra_modos.categoria_activa() == "militar", "HUD refleja categoría militar activa")
	assert(camara23.overlay.mostrar_zonas, "las zonas pintadas son visibles en categoría Militar (se construye en Zona Industrial)")
	camara23._manejar_tecla_construir(1)
	assert(camara23.modo_colocar_puesto and camara23._tipo_puesto_activo == "cuartel", "tecla 1 dentro de militar activa colocación de cuartel")
	assert(camara23.hud._barra_modos.categoria_activa() == "militar", "HUD conserva categoría militar al elegir cuartel")
	camara23._alternar_modo_zonificar()
	camara23._elegir_zona(Zonificacion.ZONAS_PINTABLES[1])
	assert("Militar" in camara23._categorias_permitidas_zona(), "Zona Industrial indica que también permite categoría Militar")
	camara23.hud.queue_free()
	mundo23.free()

	print("\n=== TEST 24: Techo/pared en capa 1 impide seleccionar unidad interior en capa 2 ===")
	var raiz24 := Node3D.new()
	add_child(raiz24)
	var mundo24 := MundoFalso.new()
	mundo24.name = "VoxelWorld"
	raiz24.add_child(mundo24)
	var ov_zona24: Node3D = ZonaOverlayScript.new()
	ov_zona24.name = "ZonaOverlay"
	raiz24.add_child(ov_zona24)
	var ov_via24: Node3D = ViaPreviewOverlayScript.new()
	ov_via24.name = "ViaPreviewOverlay"
	raiz24.add_child(ov_via24)
	var hud24: CanvasLayer = HUDScript.new()
	hud24.name = "HUDLayer"
	raiz24.add_child(hud24)
	var player24 := CharacterBody3D.new()
	player24.name = "Player"
	raiz24.add_child(player24)
	var camara24: Camera3D = CamaraCenitalScript.new()
	raiz24.add_child(camara24)
	camara24.current = true
	camara24.global_position = Vector3(5.0, 12.0, 12.0)
	camara24.look_at(Vector3(5.0, 1.5, 5.0), Vector3.UP)

	var cuerpo_trab := AnimatableBody3D.new()
	cuerpo_trab.collision_layer = 2
	cuerpo_trab.collision_mask = 0
	cuerpo_trab.set_meta("colono_id", 999)
	var cs_trab := CollisionShape3D.new()
	cs_trab.shape = BoxShape3D.new()
	cuerpo_trab.add_child(cs_trab)
	cuerpo_trab.position = Vector3(5.0, 1.5, 5.0)
	raiz24.add_child(cuerpo_trab)

	var cuerpo_techo := StaticBody3D.new()
	cuerpo_techo.collision_layer = 1
	cuerpo_techo.collision_mask = 0
	var cs_techo := CollisionShape3D.new()
	var box_techo := BoxShape3D.new()
	box_techo.size = Vector3(4.0, 0.5, 4.0)
	cs_techo.shape = box_techo
	cuerpo_techo.add_child(cs_techo)
	cuerpo_techo.position = Vector3(5.0, 4.0, 5.0)
	raiz24.add_child(cuerpo_techo)

	await get_tree().physics_frame
	await get_tree().physics_frame
	var punto_pantalla: Vector2 = camara24.unproject_position(Vector3(5.0, 1.5, 5.0))
	assert(camara24._unidad_bajo_mouse(punto_pantalla) == -1, "el techo en capa 1 debe bloquear el raycast antes del trabajador en capa 2")
	cuerpo_techo.collision_layer = 0
	await get_tree().physics_frame
	assert(camara24._unidad_bajo_mouse(punto_pantalla) == 999, "sin techo delante, el raycast sí selecciona al trabajador")
	raiz24.queue_free()

	print("\n=== Las 24 pruebas de CamaraCenitalModosTest pasaron correctamente ===")


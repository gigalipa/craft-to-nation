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
const VentanaOcupacionesScript = preload("res://scripts/VentanaOcupaciones.gd")
const PanelPuestoScript = preload("res://scripts/PanelPuesto.gd")
const PanelEdificioScript = preload("res://scripts/PanelEdificio.gd")
const Strings = preload("res://scripts/strings.gd")


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


class ObrasPanelFalso extends RefCounted:
	var resumen: Dictionary = {}
	var marcados: Dictionary = {}
	var prioridades: Dictionary = {}
	var pausas := 0
	var rechazo := ""
	var es_nucleo := false
	var id_columna := -1

	func id_en_columna(_col: Vector2i) -> int:
		return id_columna

	func fijar_prioridad(id: int, p: int) -> void:
		prioridades[id] = p

	func prioridad_de(id: int) -> int:
		return prioridades.get(id, 1)

	func resumen_de(_id: int) -> Dictionary:
		return resumen

	func alternar_pausa(_id: int) -> void:
		pausas += 1
		resumen["pausada"] = not resumen["pausada"]

	func alternar_marca(id: int) -> String:
		if rechazo != "":
			return rechazo
		if marcados.has(id):
			marcados.erase(id)
			resumen["estado"] = "construccion"
		else:
			marcados[id] = true
			resumen["estado"] = "demolicion"
		return ""

	func esta_marcado(id: int) -> bool:
		return marcados.has(id)

	func esta_programada(_id: int) -> bool:
		return false

	func programar_demolicion(id: int, _horas: int = 5) -> String:
		return alternar_marca(id)

	func cancelar_demolicion(id: int) -> String:
		return alternar_marca(id)

	func es_del_nucleo(_id: int) -> bool:
		return es_nucleo


class ColonosPanelFalso extends RefCounted:
	func obreros_en(_id: int) -> int:
		return 3

	func residentes_en(_id: int) -> Dictionary:
		return {"obrero": 2}


class ObrasFalsa extends RefCounted:
	signal marca_cambiada(id: int, marcado: bool)
	var marcados: Dictionary = {}
	var celdas: Dictionary = {}
	func celdas_de(id: int) -> Array:
		return celdas.get(id, [])


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
	probar_ventana_poblacion_empleo()
	probar_ventana_ocupaciones()
	await probar_ventana_energia()
	await probar_ventana_moral()
	probar_panel_escuela()
	probar_panel_niveles()
	probar_panel_extractores_y_refinerias()
	probar_panel_canalizacion()
	probar_panel_edificio()
	probar_panel_edificio_racionamiento()
	probar_marcas_demolicion()
	probar_zona_overlay_reactividad_terreno()
	probar_investigacion_ui()
	probar_transporte_ui()


func probar_barra_superior_calculos() -> void:
	print("=== TEST 1a: BarraSuperior (cálculos estáticos) ===")
	assert(BarraSuperiorScript.texto_poblacion(38, 48, 5) == "Población: 38/48 (5)")
	assert(BarraSuperiorScript.fraccion_moral(Ciudad.BONO_MORAL_MAXIMO / 2.0) == 0.5)
	# Moral y emojis de estado anímico (GDD v3.56)
	assert(BarraSuperiorScript.emoji_moral(15.0) == "😡", "moral < 20 debe ser enojado")
	assert(BarraSuperiorScript.emoji_moral(25.0) == "🙁", "20 <= moral < 35 debe ser triste")
	assert(BarraSuperiorScript.emoji_moral(50.0) == "😐", "35 <= moral <= 65 debe ser neutro")
	assert(BarraSuperiorScript.emoji_moral(80.0) == "🙂", "moral > 65 debe ser feliz")
	assert(BarraSuperiorScript.texto_moral(75.0) == "🙂 75%", "texto de moral formateado con emoji")
	# Moral fuera de rango: la barra se acota a 0-1.
	assert(BarraSuperiorScript.fraccion_moral(-3.0) == 0.0)
	assert(BarraSuperiorScript.fraccion_moral(Ciudad.BONO_MORAL_MAXIMO * 4.0) == 1.0)
	assert(BarraSuperiorScript.texto_tasa(12.0) == "+12.0/h")
	assert(BarraSuperiorScript.texto_tasa(-3.0) == "-3.0/h")
	assert(BarraSuperiorScript.texto_tasa(0.0) == "+0.0/h")
	assert(BarraSuperiorScript.texto_comida(126.0, 200.0, -5.0) == "Comida: 126/200 (-5.0/h)")

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
	assert(BarraSuperiorScript.clave_critica({"a": RecursoFalso.new("A", 0, 1, 0.0), "b": RecursoFalso.new("B", 0, 1, 0.0)}) == "")
	assert(BarraSuperiorScript.clave_critica({}) == "")
	assert(BarraSuperiorScript.texto_energia(30.0, 50.0, -20.0) == "Energía: 30/50 (-20.0/h)")

	# Recursos fluidos y combustible
	assert(HUDScript.NOMBRES_RECURSO["agua"] == "Agua")
	assert(HUDScript.NOMBRES_RECURSO["crudo"] == "Crudo")
	assert(HUDScript.NOMBRES_RECURSO["combustible"] == "Combustible")

	# Estados visibles de energía en PanelPuesto
	assert(PanelPuestoScript.texto_estado_energia(false, 10.0, 0.0, 20.0) == "Sin conexión")
	assert(PanelPuestoScript.texto_estado_energia(true, 0.0, 1.0, 20.0) == "Sin demanda")
	assert(PanelPuestoScript.texto_estado_energia(true, 10.0, 0.0, 0.0) == "Sin generación")
	assert(PanelPuestoScript.texto_estado_energia(true, 50.0, 0.6, 30.0) == "Déficit 60 %")
	assert(PanelPuestoScript.texto_estado_energia(true, 20.0, 1.0, 20.0) == "Con energía")


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
	barra.almacen_total.pressed.emit()
	barra.energia.pressed.emit()
	assert(pedidos == ["poblacion", "almacen", "energia"], "salió %s" % [pedidos])
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
	assert(boton_cerrar is Button and (boton_cerrar.icon != null or boton_cerrar.text == "X"))
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
		elif hijo is Container:
			for nieto in hijo.get_children():
				if nieto is Label and (nieto as Label).text.begins_with("Ciudadanos:"):
					texto_ciudadanos = (nieto as Label).text
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
	Ciudad.sub_almacen_comida["sembradios"] = 150.0
	ventana_almacen.abrir()
	assert(ventana_almacen.visible and ventana_almacen.abierta)
	assert(ventana_almacen._caja.get_child_count() > 0)
	var btn_comida: Button = null
	var btn_tierra: Button = null
	var nombres_recursos: Array = []
	for hijo in ventana_almacen._caja.get_children():
		if hijo is Label:
			nombres_recursos.append((hijo as Label).text.split(":")[0])
		elif hijo is Container:
			for nieto in hijo.get_children():
				if nieto is Button:
					var b := nieto as Button
					if b.text.contains("Comida:"):
						btn_comida = b
					elif b.text.contains("Tierra:"):
						btn_tierra = b
					var txt: String = b.text.replace("▶ ", "").replace("▼ ", "")
					nombres_recursos.append(txt.split(":")[0])
					break
				elif nieto is Label:
					nombres_recursos.append((nieto as Label).text.split(":")[0])
					break
	assert(btn_comida != null, "boton desplegable de comida debe existir")
	assert(btn_tierra != null, "boton desplegable de tierra debe existir")
	assert(btn_comida.text.contains("▶ Comida:"), "por defecto debe estar cerrado con ▶")
	btn_comida.emit_signal("pressed")
	# Tras pulsar, _desplegado_comida es true y el texto tiene ▼
	assert(ventana_almacen._desplegado_comida, "_desplegado_comida debe ser true tras click")
	assert(btn_comida.text.contains("▼ Comida:"), "tras click debe mostrar flecha ▼")
	assert(ventana_almacen._contenedores_hijos["comida"].visible, "contenedor de hijos de comida debe ser visible")
	btn_tierra.emit_signal("pressed")
	ventana_almacen._actualizar()
	assert(ventana_almacen._desplegados.get("tierra", false), "tierra debe quedar desplegado tras click")
	assert(btn_tierra.text.contains("▼ Tierra:"), "tierra debe mostrar flecha ▼")
	# Verificar que _process() no destruye los botones bajo el cursor del usuario
	var ref_btn_comida := btn_comida
	ventana_almacen._process(0.016)
	assert(ventana_almacen._botones_desplegable["comida"] == ref_btn_comida, "los botones no deben ser destruidos entre fotogramas")
	var nombres_ordenados := nombres_recursos.duplicate()
	nombres_ordenados.sort_custom(func(a: String, b: String) -> bool: return a.nocasecmp_to(b) < 0)
	assert(nombres_recursos == nombres_ordenados, "almacen debe estar ordenado alfabeticamente: %s vs %s" % [nombres_recursos, nombres_ordenados])
	var boton_toggle_todo: Button = ventana_almacen._btn_toggle_todo
	assert(boton_toggle_todo != null, "boton toggle todo debe existir")
	ventana_almacen.alternar_expandir_todo()
	assert(ventana_almacen.estan_todos_expandidos(), "todos deben estar expandidos")
	assert(boton_toggle_todo.text == "Contraer todo")
	ventana_almacen.alternar_expandir_todo()
	assert(not ventana_almacen.estan_todos_expandidos(), "todos deben estar contraidos")
	assert(boton_toggle_todo.text == "Expandir todo")

	var boton_cerrar_almacen: Button = ventana_almacen._caja_raiz.get_child(0).get_child(2)
	ventana_almacen._process(0.0)
	assert(ventana_almacen._caja_raiz.get_child(0).get_child(2) == boton_cerrar_almacen)
	assert(ventana_almacen._caja_raiz.get_child(0).get_child(1) == boton_toggle_todo)
	ventana_almacen.ocultar_temporalmente()
	assert(not ventana_almacen.visible and ventana_almacen.abierta)
	ventana_almacen.restaurar()
	assert(ventana_almacen.visible)
	ventana_almacen.cerrar()
	assert(not ventana_almacen.visible and not ventana_almacen.abierta)
	ventana_almacen.queue_free()

	const VentanaBaulScript = preload("res://scripts/VentanaBaul.gd")
	var ventana_baul: PanelContainer = VentanaBaulScript.new()
	add_child(ventana_baul)
	var esq_puesto := Vector2i(100, 100)
	Economia.registrar_puesto(esq_puesto, "maderero", 3, 4, {})
	ventana_baul.abrir(esq_puesto)
	assert(ventana_baul.visible)
	assert(ventana_baul.custom_minimum_size == Vector2(320, 260), "VentanaBaul debe tener tamaño acotado de 320x260")
	assert(ventana_baul.grow_horizontal == Control.GROW_DIRECTION_BOTH and ventana_baul.grow_vertical == Control.GROW_DIRECTION_BOTH, "VentanaBaul debe crecer hacia ambos lados para permanecer centrada")
	assert(ventana_baul.offset_left == -160.0 and ventana_baul.offset_top == -130.0, "VentanaBaul debe tener offsets centrados respecto a anclas 0.5")
	var scroll_encontrado := false
	for hijo in ventana_baul.get_children():
		for sub in hijo.get_children():
			if sub is ScrollContainer:
				scroll_encontrado = true
				break
	assert(scroll_encontrado, "VentanaBaul debe contener un ScrollContainer para la lista de recursos")
	var tecla_e := InputEventKey.new()
	tecla_e.keycode = KEY_E
	tecla_e.pressed = true
	ventana_baul._unhandled_key_input(tecla_e)
	assert(ventana_baul.visible, "en el mismo fotograma de apertura no debe cerrarse por propagación")
	ventana_baul._frame_apertura -= 1
	ventana_baul._unhandled_key_input(tecla_e)
	assert(not ventana_baul.visible, "pulsar E en fotograma posterior debe cerrar VentanaBaul")
	ventana_baul.abrir(esq_puesto)
	assert(ventana_baul.visible)
	var tecla_esc := InputEventKey.new()
	tecla_esc.keycode = KEY_ESCAPE
	tecla_esc.pressed = true
	ventana_baul._frame_apertura -= 1
	ventana_baul._unhandled_key_input(tecla_esc)
	assert(not ventana_baul.visible, "pulsar Escape debe cerrar VentanaBaul")
	ventana_baul.queue_free()
	Economia.puestos.erase(esq_puesto)


func _textos(caja: Node) -> Array:
	var textos: Array = []
	for hijo in caja.get_children():
		if hijo is Label:
			textos.append((hijo as Label).text)
		elif hijo is Container:
			for nieto in hijo.get_children():
				if nieto is Label:
					textos.append((nieto as Label).text)
	return textos


## Ventana Población: total, camas y empleo por tipo; el botón "Ocupaciones".
func probar_ventana_poblacion_empleo() -> void:
	print("=== TEST 1d: Población muestra total, camas y empleo por tipo, y el botón Ocupaciones ===")
	var demografia_previa: Dictionary = Ciudad.demografia
	var colonos_previos: Dictionary = Colonos.colonos
	Ciudad.demografia = {"ciudadano": 0, "desempleado": 2, "obrero": 4, "tecnico": 5, "especialista": 0, "investigador": 0, "militar": 0}
	Colonos.colonos = {}
	var trabajo := {"puesto": Vector2i(1, 1), "rol": "recolector"}
	for i in range(5):
		Colonos.colonos[i] = {"tipo": "tecnico", "trabajo": trabajo if i < 3 else {}}
	Colonos.colonos[10] = {"tipo": "obrero", "trabajo": {"puesto": Vector2i(2, 2), "rol": "aprendiz"}}  # un aprendiz es obrero empleado
	var ventana: PanelContainer = VentanaPoblacionScript.new()
	add_child(ventana)
	ventana.abrir()
	var textos: Array = _textos(ventana._caja)
	assert("Población total: 11" in textos, "salió %s" % [textos])
	assert("Camas construidas: %d" % Ciudad.capacidad_camas_construida in textos, "salió %s" % [textos])
	assert("Técnicos: 5 · 3 empleados · 2 desempleados" in textos, "salió %s" % [textos])
	assert("Obreros: 6 · 1 empleado · 5 desempleados" in textos, "salió %s" % [textos])
	assert(not textos.any(func(t: String) -> bool: return t.begins_with("Desempleados:")), "no hay fila separada de desempleados: %s" % [textos])
	assert(not textos.any(func(t: String) -> bool: return t.contains("Ciudadanos") or t.contains("Especialistas")), "los tipos sin habitantes no salen")
	assert(not textos.any(func(t: String) -> bool: return t.contains("Puestos de trabajo")), "la lista de puestos pasó a Ocupaciones")
	# Un técnico libre cuenta como sin empleo aunque los demás trabajen: el mínimo de "sin empleo" es 0.
	Ciudad.demografia["tecnico"] = 2
	ventana._actualizar()
	assert("Técnicos: 2 · 3 empleados · 0 desempleados" in _textos(ventana._caja), "salió %s" % [_textos(ventana._caja)])
	# El botón vive fuera del contenido dinámico: sobrevive a los fotogramas y emite la señal.
	var boton: Button = ventana._boton_ocupaciones
	assert(boton != null and boton.text == "Ocupaciones" and boton.get_parent() == ventana._caja_raiz)
	for i in range(5):
		ventana._process(0.0)
	assert(ventana._boton_ocupaciones == boton and boton.get_parent() == ventana._caja_raiz and not boton.is_queued_for_deletion(), "el botón no se recrea")
	var pedidas: Array = []
	ventana.ocupaciones_pedidas.connect(func() -> void: pedidas.append(true))
	boton.pressed.emit()
	assert(pedidas.size() == 1, "pressed emite ocupaciones_pedidas")
	ventana.queue_free()
	Ciudad.demografia = demografia_previa
	Colonos.colonos = colonos_previos


## Ventana Ocupaciones: una fila-botón por sitio de trabajo.
func probar_ventana_ocupaciones() -> void:
	print("=== TEST 1e: Ocupaciones lista los sitios de trabajo por categorías desplegables, ordenados por construcción ===")
	var puestos_previos: Dictionary = Economia.puestos
	Economia.puestos = {}
	var ventana: PanelContainer = VentanaOcupacionesScript.new()
	add_child(ventana)
	assert(ventana.position == VentanaOcupacionesScript.POSICION_INICIAL and not ventana.visible and not ventana.abierta)
	assert(ventana.position.x >= VentanaPoblacionScript.POSICION_INICIAL.x + 320, "no solapa con Población")
	ventana.abrir()
	assert("Ninguno todavía" in _textos(ventana._caja), "salió %s" % [_textos(ventana._caja)])
	var e_mina := Vector2i(1000, 1000)
	var e_madero := Vector2i(1050, 1000)
	var e_esc := Vector2i(1100, 1000)
	var e_bp := Vector2i(1200, 1000)
	Economia.registrar_puesto(e_mina, "mina", 5, 5, {})
	Economia.registrar_puesto(e_madero, "maderero", 3, 4, {})
	Economia.registrar_puesto(e_esc, "escuela_tecnica", 5, 5, {})
	Economia.registrar_puesto(e_bp, "blueprint", 5, 5, {})
	Economia.puestos[e_mina]["recolectores"] = [1, 2]
	Economia.puestos[e_mina]["acarreadores"] = [3]
	ventana._actualizar()

	# Categorías presentes y blueprint ignorado
	assert(ventana._headers_categoria.has("recoleccion"))
	assert(ventana._headers_categoria.has("investigacion"))
	assert(not ventana._headers_categoria.has("industria"))
	assert(not ventana._headers_categoria.has("energia"))
	assert(not "Ninguno todavía" in _textos(ventana._caja))

	# Dentro de recolección: el más nuevo (maderero) arriba de la mina
	var boton_madero: Button = ventana._botones[e_madero]
	var boton_mina: Button = ventana._botones[e_mina]
	var boton_esc: Button = ventana._botones[e_esc]
	assert(boton_madero.get_index() < boton_mina.get_index(), "el más nuevo arriba")

	var cupo_mina: int = Economia.puestos[e_mina]["cupo"]
	assert(boton_mina.text == "Mina 3/%d" % cupo_mina, "salió '%s'" % boton_mina.text)
	assert(boton_esc.text.begins_with("Escuela técnica 0/"), "salió '%s'" % boton_esc.text)

	# Desplegable: plegar y desplegar recolección
	var cont_recol: Control = ventana._contenedores_categoria["recoleccion"]
	assert(cont_recol.visible)
	ventana._headers_categoria["recoleccion"].pressed.emit()
	assert(not cont_recol.visible, "al hacer clic se pliega")
	ventana._headers_categoria["recoleccion"].pressed.emit()
	assert(cont_recol.visible, "al hacer clic se despliega")

	# Sin cambiar el conjunto de puestos, los botones son los mismos pero el texto se actualiza.
	Economia.puestos[e_mina]["acarreadores"] = []
	Economia.puestos[e_mina]["activo"] = false
	ventana._actualizar()
	assert(ventana._botones[e_mina] == boton_mina, "no se recrean las filas")
	assert(boton_mina.text == "Mina 2/%d (inactivo)" % cupo_mina, "salió '%s'" % boton_mina.text)
	Economia.puestos[e_mina]["activo"] = true
	Economia.puestos[e_mina]["agotado"] = true
	ventana._actualizar()
	assert(boton_mina.text == "Mina 2/%d (agotado)" % cupo_mina, "salió '%s'" % boton_mina.text)

	# El clic emite la esquina de su fila.
	var pedidos: Array = []
	ventana.edificio_pedido.connect(func(esquina: Vector2i) -> void: pedidos.append(esquina))
	boton_mina.pressed.emit()
	boton_esc.pressed.emit()
	assert(pedidos == [e_mina, e_esc], "salió %s" % [pedidos])

	# Si cambia el conjunto, se reconstruye.
	Economia.puestos.erase(e_esc)
	ventana._actualizar()
	assert(not ventana._headers_categoria.has("investigacion"))
	assert(ventana._botones.size() == 2)

	# Cierre, ocultar/restaurar, como las demás ventanas.
	var cerrar: Button = ventana._caja_raiz.get_child(0).get_child(1)
	ventana.ocultar_temporalmente()
	assert(not ventana.visible and ventana.abierta)
	ventana.restaurar()
	assert(ventana.visible)
	cerrar.pressed.emit()
	assert(not ventana.visible and not ventana.abierta)
	ventana.queue_free()
	Economia.puestos = puestos_previos


func probar_ventana_energia() -> void:
	print("=== TEST 1f: VentanaEnergia modal interactiva y boton en topbar ===")
	const VentanaEnergiaScript = preload("res://scripts/VentanaEnergia.gd")

	# 1. Probar clic en energía desde HUD
	var hud: CanvasLayer = HUDScript.new()
	var oxigeno := Label.new()
	oxigeno.name = "OxigenoLabel"
	hud.add_child(oxigeno)
	add_child(hud)
	await get_tree().process_frame

	assert(not hud._ventana_energia.visible and not hud._ventana_energia.abierta)
	hud._barra_superior.energia.pressed.emit()
	assert(hud._ventana_energia.visible and hud._ventana_energia.abierta, "clic en boton energia de barra superior debe abrir VentanaEnergia")
	hud.queue_free()

	# 2. Probar widget VentanaEnergia de forma aislada
	var puestos_previos: Dictionary = Economia.puestos
	var balance_previo: Dictionary = Economia.balance_energia
	Economia.puestos = {}

	var ventana: PanelContainer = VentanaEnergiaScript.new()
	add_child(ventana)
	assert(not ventana.visible and not ventana.abierta)
	assert(ventana.custom_minimum_size == Vector2(480, 420), "VentanaEnergia debe tener tamaño 480x420")
	assert(ventana.position == Vector2(336, 114), "VentanaEnergia debe tener posición inicial correcta")

	ventana.abrir()
	assert(ventana.visible and ventana.abierta)

	# 3. Encabezado con balance global
	Economia.balance_energia = {
		"capacidad": 100.0,
		"demanda": 60.0,
		"entregada": 60.0,
		"factor": 1.0,
		"deficit": false,
		"conectados": {},
	}
	ventana._actualizar()
	assert(ventana._lbl_capacidad.text == "Capacidad: 100 kW", "capacidad: '%s'" % ventana._lbl_capacidad.text)
	assert(ventana._lbl_demanda.text == "Demanda: 60 kW", "demanda: '%s'" % ventana._lbl_demanda.text)
	assert(ventana._lbl_balance.text == "Balance neto: +40 kW", "balance neto: '%s'" % ventana._lbl_balance.text)
	assert(ventana._lbl_cobertura.text == "Cobertura: 100%", "cobertura: '%s'" % ventana._lbl_cobertura.text)

	# 4. Generadores y Consumidores en lista interactiva
	var esq_central := Vector2i(200, 200)
	var esq_refineria := Vector2i(210, 200)
	Economia.registrar_puesto(esq_central, "central_termoelectrica", 5, 5, {})
	Economia.puestos[esq_central]["presentes"] = [1, 2]
	Economia.puestos[esq_central]["almacen"] = {"carbon": 150.0}
	Economia.puestos[esq_central]["combustible_activo"] = "carbon"

	Economia.registrar_puesto(esq_refineria, "refineria_petrolera", 5, 5, {})
	Economia.puestos[esq_refineria]["presentes"] = [3]

	Economia.balance_energia = {
		"capacidad": 40.0,
		"demanda": 1.0,
		"entregada": 1.0,
		"factor": 1.0,
		"deficit": false,
		"conectados": {esq_central: true, esq_refineria: true},
	}
	ventana._actualizar()

	assert(ventana._botones_generadores.has(esq_central), "central debe estar en la lista de generadores")
	var btn_gen: Button = ventana._botones_generadores[esq_central]
	assert("Central termoeléctrica" in btn_gen.text)
	assert("Carbón" in btn_gen.text)
	assert("150" in btn_gen.text, "stock local debe figurar en el boton")

	assert(ventana._botones_consumidores.has(esq_refineria), "refineria debe estar en la lista de consumidores")
	var btn_con: Button = ventana._botones_consumidores[esq_refineria]
	assert("Refinería petrolera" in btn_con.text)
	assert("Demanda: 1 kW" in btn_con.text)
	assert("Conectado" in btn_con.text)

	# 5. Clic en generador o consumidor: emite edificio_pedido(esquina) sin cerrar ventana
	var edificios_pedidos: Array = []
	ventana.edificio_pedido.connect(func(esq: Vector2i) -> void: edificios_pedidos.append(esq))

	btn_gen.pressed.emit()
	assert(ventana.visible and ventana.abierta, "clic en generador NO debe cerrar la ventana")
	assert(edificios_pedidos == [esq_central], "debe emitir edificio_pedido de la central")

	btn_con.pressed.emit()
	assert(ventana.visible and ventana.abierta, "clic en consumidor NO debe cerrar la ventana")
	assert(edificios_pedidos == [esq_central, esq_refineria], "debe emitir edificio_pedido de la refineria")

	# 6. Cierre con botón X, tecla E y tecla Esc
	var boton_cerrar: Button = ventana._caja_raiz.get_child(0).get_child(1)
	assert(boton_cerrar is Button and (boton_cerrar.icon != null or boton_cerrar.text == "X"))
	boton_cerrar.pressed.emit()
	assert(not ventana.visible and not ventana.abierta, "boton X debe cerrar VentanaEnergia")

	ventana.abrir()
	var tecla_e := InputEventKey.new()
	tecla_e.keycode = KEY_E
	tecla_e.pressed = true
	if ventana.has_method("_unhandled_key_input"):
		ventana._unhandled_key_input(tecla_e)
	assert(ventana.visible and ventana.abierta, "tecla E no debe cerrar VentanaEnergia (solo boton X)")
	boton_cerrar.pressed.emit()
	assert(not ventana.visible and not ventana.abierta, "boton X debe cerrar VentanaEnergia")

	ventana.queue_free()
	Economia.puestos = puestos_previos
	Economia.balance_energia = balance_previo


func probar_ventana_moral() -> void:
	print("=== TEST 1g: VentanaMoral modal interactiva y boton en topbar ===")
	const VentanaMoralScript = preload("res://scripts/VentanaMoral.gd")

	# 1. Probar clic en moral desde HUD
	var hud: CanvasLayer = HUDScript.new()
	var oxigeno := Label.new()
	oxigeno.name = "OxigenoLabel"
	hud.add_child(oxigeno)
	add_child(hud)
	await get_tree().process_frame

	assert(not hud._ventana_moral.visible and not hud._ventana_moral.abierta)
	hud._barra_superior.moral.pressed.emit()
	assert(hud._ventana_moral.visible and hud._ventana_moral.abierta, "clic en boton moral de barra superior debe abrir VentanaMoral")
	hud.queue_free()

	# 2. Probar widget VentanaMoral de forma aislada
	var ventana: PanelContainer = VentanaMoralScript.new()
	add_child(ventana)
	assert(not ventana.visible and not ventana.abierta)
	assert(ventana.custom_minimum_size == Vector2(380, 440), "VentanaMoral debe tener tamaño 380x440")

	ventana.abrir()
	assert(ventana.visible and ventana.abierta)

	# 3. Datos de moral reflejados
	Ciudad.moral = 85.0
	Ciudad.tasa_cambio_moral = 0.5
	ventana.actualizar()
	assert("85.0%" in ventana._lbl_moral_val.text and ventana._rect_moral.texture != null)
	assert("+0.50" in ventana._lbl_tendencia.text)
	assert("Inmigración" in ventana._lbl_migracion.text)

	# Moral crítica
	Ciudad.moral = 15.0
	Ciudad.tasa_cambio_moral = -1.5
	ventana.actualizar()
	assert("15.0%" in ventana._lbl_moral_val.text and ventana._rect_moral.texture != null)
	assert("Éxodo" in ventana._lbl_migracion.text)
	assert(ventana._btn_boost.disabled, "Boton boost debe estar deshabilitado con éxodo")
	assert("bloqueado" in ventana._lbl_boost_info.text.to_lower() or "negativa" in ventana._lbl_boost_info.text.to_lower())

	# Boost disponible con moral positiva
	Ciudad.moral = 60.0
	Ciudad.horas_boost_inmigracion = 0
	ventana.actualizar()
	assert(not ventana._btn_boost.disabled, "Boton boost debe estar habilitado con moral positiva")
	ventana._btn_boost.pressed.emit()
	assert(Ciudad.horas_boost_inmigracion > 0, "Al presionar el boton se activa el boost")
	ventana.actualizar()
	assert(ventana._btn_boost.disabled, "Boton boost debe deshabilitarse tras activación")
	assert("Base" in ventana._lbl_migracion.text, "Migración debe mostrar desglose con boost")
	assert("activo" in ventana._lbl_boost_info.text.to_lower())
	Ciudad.horas_boost_inmigracion = 0

	# 4. Validar que teclas M / Esc no cierran VentanaMoral (solo boton X)
	var tecla_m := InputEventKey.new()
	tecla_m.keycode = KEY_M
	tecla_m.pressed = true
	if ventana.has_method("_unhandled_input"):
		ventana._unhandled_input(tecla_m)
	assert(ventana.visible and ventana.abierta, "tecla M no debe cerrar VentanaMoral")

	var boton_cerrar_m: Button = ventana._caja_raiz.get_child(0).get_child(2)
	assert(boton_cerrar_m is Button)
	boton_cerrar_m.pressed.emit()
	assert(not ventana.visible and not ventana.abierta, "solo boton X debe cerrar VentanaMoral")

	ventana.queue_free()


func probar_barra_superior() -> void:
	print("=== TEST 1b: BarraSuperior (widget con Ciudad real) ===")
	var barra: PanelContainer = BarraSuperiorScript.new()
	add_child(barra)

	# Verificación de moral interactiva (Button)
	assert(barra.moral is Button, "moral debe ser un Button interactivo")
	var pedidos_moral := []
	barra.dato_pedido.connect(func(c: String) -> void: pedidos_moral.append(c))
	barra.moral.pressed.emit()
	assert(pedidos_moral.has("moral"), "clic en boton moral debe emitir dato_pedido('moral')")

	var respaldo := {}
	for clave in Ciudad.almacen:
		respaldo[clave] = Ciudad.almacen[clave].tasa_neta_promedio
		Ciudad.almacen[clave].tasa_neta_promedio = 0.0

	Ciudad.almacen["comida"].cantidad = 126.0
	Ciudad.almacen["comida"].tasa_neta_promedio = -5.0
	barra.actualizar()
	assert(barra.comida.text.begins_with("Comida: 126/"), "salió '%s'" % barra.comida.text)
	assert(barra.comida.get_theme_color("font_color") == BarraSuperiorScript.TemaHUD.INVALIDO)
	Ciudad.almacen["comida"].tasa_neta_promedio = 2.0
	barra.actualizar()
	assert(barra.comida.text.begins_with("Comida: 126/") and barra.comida.text.ends_with("(+2.0/h)"), "salió '%s'" % barra.comida.text)
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

	assert(barra.almacen_total.text == "Almacén", "salió '%s'" % barra.almacen_total.text)
	assert(barra.era.text == "Asentamiento Pionero", "salió '%s'" % barra.era.text)
	assert(barra.nivel.text.begins_with("IDU:"), "salió '%s'" % barra.nivel.text)
	assert(barra._icono_nivel != null and barra._icono_nivel.texture != null)

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
	assert(panel.acciones.text == "ROTAR\nCOLOCAR")
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
	panel.mostrar("Puerta", {}, ["(clic der.) COLOCAR", "[E] INTERACTUAR"])
	assert(panel.acciones.get_parsed_text().contains("[E] INTERACTUAR"), "el atajo de tecla se muestra literal, antes de la acción")
	assert(PanelContextualScript.texto_acciones(["MARCAR PARA DEMOLICIÓN (clic der.)"]).contains("click_der.svg"), "la acción de demolición lleva el ícono del clic derecho")
	assert(PanelContextualScript.texto_acciones(["(clic izq.) COLOCAR"]).contains("click_izq.svg"), "clic izq lleva el icono del clic izquierdo")
	assert(PanelContextualScript.texto_acciones(["(doble clic) CONFIRMAR"]).contains("click_izq.svg") and PanelContextualScript.texto_acciones(["(doble clic) CONFIRMAR"]).contains("x2"), "doble clic lleva el icono de clic izquierdo con x2")
	assert(PanelContextualScript.texto_acciones(["[Ctrl+scroll] ROTAR"]).contains("scroll.svg"), "scroll lleva el icono de scroll")
	assert(PanelContextualScript.texto_acciones(["[Ctrl+rueda] ROTAR"]).contains("scroll.svg"), "rueda lleva el icono de scroll")
	assert(PanelContextualScript.texto_acciones(["COLOCAR (clic)"]).contains("click_izq.svg"), "(clic) simple se mapea al icono de clic izquierdo")
	assert(ResourceLoader.load("res://assets/icons/click_der.svg") != null, "click_der.svg es un recurso cargable")
	assert(ResourceLoader.load("res://assets/icons/click_izq.svg") != null, "click_izq.svg es un recurso cargable")
	assert(ResourceLoader.load("res://assets/icons/scroll.svg") != null, "scroll.svg es un recurso cargable")

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
	assert(barra._botones_construccion.has("escuela_especialistas"), "Investigación ofrece la escuela de especialistas")
	barra.set_modo("construir", "", "industrial")
	assert(barra._botones_construccion.has("refineria_petrolera"))
	assert(barra._botones_construccion.has("productor_combustible"))
	assert(barra._botones_construccion.has("central_termoelectrica"))
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
	assert(barra._viewports_construccion.size() == BarraModosScript.TIPOS_CON_MINIATURA.size(), "una construcción con malla real por cada uno de los tipos con miniatura")
	for giro in [2, 3, 0, 1, 2, 3]:
		barra.set_giros(giro)
	assert(barra._viewports_construccion.size() == BarraModosScript.TIPOS_CON_MINIATURA.size(), "sigue habiendo un solo SubViewport trackeado por tipo tras varias rotaciones")

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
	# Las tablas cuentan como madera (reporte del usuario, 2026-10-02).
	var madera_antes: float = Ciudad.almacen["madera"].cantidad
	var tablas_antes: float = Ciudad.almacen["tablas"].cantidad
	hotbar.configurar(["bloque_madera"])
	Ciudad.almacen["madera"].cantidad = 0.0
	Ciudad.almacen["tablas"].cantidad = 15.0
	hotbar.actualizar_cantidades()
	assert(hotbar.cantidad_de(0) == 3, "solo con tablas se cuentan 3 bloques de madera (5 de madera cada uno)")
	Ciudad.almacen["madera"].cantidad = madera_antes
	Ciudad.almacen["tablas"].cantidad = tablas_antes
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
	assert(HUDScript.texto_tasas_mina_por_nivel([{"hierro": 2.0, "tierra": 0.1}, {}, {"hierro": 5.0}]) == "Recolección prevista por trabajador:\n  Nivel 1: 2.0 hierro/h\n  Nivel 2: nada\n  Nivel 3: 5.0 hierro/h", "se omiten las tasas menores de 0,3/h y cada nivel muestra solo su franja")
	assert(HUDScript.texto_tasas_mina_por_nivel([{}, {}, {"tierras_raras": 0.5}]) == "Recolección prevista por trabajador:\n  Nivel 1: nada\n  Nivel 2: nada\n  Nivel 3: 0.5 tierras raras/h", "reemplaza guiones bajos por espacios en tierras raras")
	assert(HUDScript.texto_tasas_mina_por_nivel([{}, {}, {}]) == "Recolección prevista por trabajador:\n  Nivel 1: nada\n  Nivel 2: nada\n  Nivel 3: nada")


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


func probar_panel_escuela() -> void:
	print("=== TEST 7: PanelPuesto de una escuela técnica (aprendices, progreso) y de una refinería (técnicos libres) ===")
	var esquina7 := Vector2i(900, 900)
	var esquina7r := Vector2i(930, 900)
	Economia.registrar_puesto(esquina7, "escuela_tecnica", 5, 5, {})
	Economia.registrar_puesto(esquina7r, "siderurgica", 5, 5, {})
	var panel: PanelContainer = PanelPuestoScript.new()
	add_child(panel)
	panel.abrir(esquina7)
	assert(panel._titulo.text == "Escuela técnica")
	assert(panel._filas["aprendiz"]["fila"].visible and not panel._filas["recolector"]["fila"].visible and not panel._filas["tecnico"]["fila"].visible)
	assert(not panel._filas["acarreador"]["fila"].visible, "una escuela no tiene acarreadores")
	assert(not panel._almacen.visible and not panel._produccion.visible, "ni almacén local ni producción")
	assert("Aprendices: 0 / 4" in panel._trabajadores.text and "0 / %d h" % Economia.HORAS_FORMACION in panel._trabajadores.text, "cohorte y horas: %s" % panel._trabajadores.text)
	var esquina7e := Vector2i(905, 900)
	Economia.registrar_puesto(esquina7e, "escuela_especialistas", 5, 5, {})
	panel.abrir(esquina7e)
	assert(panel._titulo.text == "Escuela de especialistas")
	assert("Técnicos en formación: 0 / 3" in panel._trabajadores.text and "0 / 48 h" in panel._trabajadores.text)
	Economia.puestos.erase(esquina7e)
	var esquina7u := Vector2i(910, 900)
	Economia.registrar_puesto(esquina7u, "universidad", 5, 5, {})
	panel.abrir(esquina7u)
	assert(panel._titulo.text == "Universidad")
	assert(panel._filas["investigador"]["fila"].visible and not panel._filas["aprendiz"]["fila"].visible and not panel._filas["recolector"]["fila"].visible)
	assert(not panel._filas["acarreador"]["fila"].visible and not panel._almacen.visible and not panel._produccion.visible)
	assert("Investigadores: 0 / 3" in panel._trabajadores.text and "Proyecto:" in panel._trabajadores.text)
	Economia.puestos.erase(esquina7u)
	panel.abrir(esquina7r)
	assert(panel._filas["tecnico"]["fila"].visible and not panel._filas["aprendiz"]["fila"].visible and panel._filas["acarreador"]["fila"].visible)
	assert(panel._almacen.visible and panel._filas["tecnico"]["libres"].text == "(%d libres)" % Colonos.tecnicos_libres(), "la refinería muestra los técnicos libres: %s" % panel._filas["tecnico"]["libres"].text)
	assert(not panel._filas["especialista"]["fila"].visible and not panel._filas["recolector"]["fila"].visible, "una refinería no tiene filas de obreros ni de especialistas")
	panel.queue_free()
	Economia.puestos.erase(esquina7)
	Economia.puestos.erase(esquina7r)


func probar_panel_niveles() -> void:
	print("=== TEST 8: PanelPuesto de un puesto con niveles (una fila por oficio, nivel en el título) ===")
	var esquina8 := Vector2i(960, 900)
	Economia.registrar_puesto(esquina8, "maderero", 3, 4, {"madera": 3.0})
	var panel: PanelContainer = PanelPuestoScript.new()
	add_child(panel)
	panel.abrir(esquina8)
	assert(panel._titulo.text == "Puesto maderero", "título sin nivel en texto: %s" % panel._titulo.text)
	assert(panel._icono_nivel.visible and panel._icono_nivel.texture != null, "nivel solo por ícono romano")
	assert(panel._filas["recolector"]["fila"].visible and panel._filas["tecnico"]["fila"].visible and panel._filas["acarreador"]["fila"].visible)
	assert(not panel._filas["aprendiz"]["fila"].visible)
	assert(panel._filas["especialista"]["fila"].visible, "la fila de especialistas siempre aparece en puestos con niveles")
	assert(panel._filas["tecnico"]["libres"].text == "(%d libres)" % Colonos.tecnicos_libres())
	assert(panel._filas["recolector"]["libres"].text == "(%d libres)" % Ciudad.demografia["desempleado"])
	Economia.asignar(esquina8, "tecnico", 99999)
	panel._actualizar()
	assert(panel._titulo.text == "Puesto maderero", "título permanece sin texto de nivel: %s" % panel._titulo.text)
	assert(Economia.nivel_de(esquina8) == 2 and panel._icono_nivel.visible)
	assert(panel._filas["recolector"]["mas"].disabled, "un puesto de nivel 2 no admite obreros")
	assert(panel._filas["tecnico"]["cantidad"].text == "1" and panel._filas["recolector"]["cantidad"].text == "0")
	assert(not panel._filas["tecnico"]["menos"].disabled and panel._filas["recolector"]["menos"].disabled)
	Economia.liberar(99999)
	panel.queue_free()
	Economia.puestos.erase(esquina8)


func probar_panel_extractores_y_refinerias() -> void:
	print("=== TEST 8b: PanelPuesto para extractores, almacén y selección de combustible en central ===")
	# 1. Estación de bombeo
	var esq_bombeo := Vector2i(1000, 1000)
	Economia.registrar_puesto(esq_bombeo, "estacion_bombeo", 4, 6, {"agua": 2.0})
	var panel: PanelContainer = PanelPuestoScript.new()
	add_child(panel)
	panel.abrir(esq_bombeo)
	assert(panel._titulo.text == "Estación de bombeo")
	assert(panel._filas["tecnico"]["fila"].visible, "admite técnicos")
	assert(not panel._filas["recolector"]["fila"].visible and not panel._filas["acarreador"]["fila"].visible, "sin obreros ni acarreadores")
	assert(panel._puertos.visible, "muestra puertos")
	assert("Salida agua" in panel._puertos.text and "Desconectado" in panel._puertos.text, "puerto de agua de salida")

	# 2. Centro de extracción
	var esq_ext := Vector2i(1020, 1000)
	var dp := {"tipo_pozo": "crudo", "bloques_hierro": 3, "perforacion": Vector2i(1022, 1002), "y_superficie": 5, "y_fondo": 0}
	var entorno_ext := {"datos_perforacion": dp}
	Economia.registrar_puesto(esq_ext, "centro_extraccion", 5, 5, {"crudo": 5.0}, entorno_ext)
	Economia.puestos[esq_ext]["crudo_restante"] = 15
	panel.abrir(esq_ext)
	assert(panel._titulo.text == "Centro de extracción")
	assert(panel._crudo_restante.visible, "etiqueta de crudo restante visible")
	assert("15" in panel._crudo_restante.text, "muestra cantidad de crudo restante")
	assert(not panel._filas["acarreador"]["fila"].visible, "centro de extracción no tiene acarreadores")

	# 3. Central termoeléctrica con selector de combustible
	var esq_central := Vector2i(1040, 1000)
	Economia.registrar_puesto(esq_central, "central_termoelectrica", 5, 5, {})
	panel.abrir(esq_central)
	assert(panel._selector_combustible.visible, "selector de combustible visible en central")
	assert(panel._filas["acarreador"]["fila"].visible, "carbón permite acarreadores")
	assert(Economia.puestos[esq_central]["combustible_activo"] == "carbon")
	# Cambiar a combustible líquido
	panel._botones_combustible["combustible"].pressed.emit()
	assert(Economia.puestos[esq_central]["combustible_activo"] == "combustible")
	assert(not panel._filas["acarreador"]["fila"].visible, "combustible líquido oculta acarreadores")
	assert("Combustible: Desconectado" in panel._puertos.text or "Entrada combustible" in panel._puertos.text, "puerto de combustible")

	# 4. Almacén
	var esq_alm := Vector2i(1060, 1000)
	Economia.registrar_puesto(esq_alm, "almacen", 5, 5, {})
	panel.abrir(esq_alm)
	assert(panel._titulo.text == "Almacén")
	assert(not panel._filas["recolector"]["fila"].visible and not panel._filas["tecnico"]["fila"].visible and not panel._filas["acarreador"]["fila"].visible, "almacén sin trabajadores")
	assert(panel._puertos.visible, "almacén muestra sus 6 puertos")
	assert(panel._bloques_recurso["agua"].visible and panel._bloques_recurso["crudo"].visible and panel._bloques_recurso["combustible"].visible, "almacén tiene los 3 bloques de recurso")
	assert(panel._botones_recurso["agua"].text.contains("Agua I⚪/O⚪:"))
	assert(panel._etiquetas_in["agua"].text.contains("* Entrada: ⚪ Desconectado"))
	assert(panel._etiquetas_out["agua"].text.contains("* Salida: ⚪ Desconectado"))
	Economia.puestos[esq_alm]["almacen"]["crudo"] = 50.0
	panel._actualizar()
	assert("50.0 Crudo" in panel._almacen.text, "el almacén muestra el crudo guardado")

	# 5. Estados de conexión y derrame en vivo
	Canalizaciones.reiniciar()
	var celda_p_out := Vector3i(1000, 4, 1000)
	var celda_p_in := Vector3i(1001, 4, 1000)
	Canalizaciones.puertos_conectados[celda_p_out] = 99
	Canalizaciones.tipo_por_puerto[celda_p_out] = "puerto_agua_out"
	Canalizaciones.puertos_conectados[celda_p_in] = 99
	Canalizaciones.tipo_por_puerto[celda_p_in] = "puerto_agua_in"
	Canalizaciones.tipo_por_red[99] = "tuberia"
	Canalizaciones.recurso_por_red[99] = "agua"
	Canalizaciones.red_a_celdas[99] = [celda_p_out, celda_p_in]
	panel.abrir(esq_bombeo)
	assert("Conectado" in panel._puertos.text and "🟢" in panel._puertos.text, "puerto en estado Conectado con indicador verde")

	# Simular derrame en la red
	Canalizaciones.derrames_activos[celda_p_in] = "agua"
	panel._actualizar()
	assert("Derrame" in panel._puertos.text and "🔴" in panel._puertos.text, "puerto en estado Derrame con indicador rojo")
	Canalizaciones.reiniciar()

	panel.queue_free()
	Economia.puestos.erase(esq_bombeo)
	Economia.puestos.erase(esq_ext)
	Economia.puestos.erase(esq_central)
	Economia.puestos.erase(esq_alm)


func probar_panel_edificio() -> void:
	print("=== TEST: PanelEdificio muestra los datos del edificio y sus botones actúan sobre Obras ===")
	var PanelEdificioScript = preload("res://scripts/PanelEdificio.gd")
	var ciudad: Node = preload("res://scripts/Ciudad.gd").new()
	ciudad.almacen["piedra"].cantidad = 4.0
	var obras := ObrasPanelFalso.new()
	obras.resumen = {"nombre": "Casa", "tipo": "Residencial", "estado": "construccion", "pausada": false, "salud": 0.25, "faltantes": {"piedra": 15}}
	var panel: PanelContainer = PanelEdificioScript.new()
	panel.obras = obras
	panel.colonos = ColonosPanelFalso.new()
	panel.ciudad = ciudad
	add_child(panel)
	var avisos: Array = []
	panel.aviso.connect(func(texto: String) -> void: avisos.append(texto))
	panel.abrir(7)
	assert(panel.visible, "se abre")
	assert(panel._titulo.text == "Edificio residencial" and panel._tipo.text.contains("Residencial"), "nombre y tipo")
	assert(panel._camas.visible and panel._baules.visible and panel._residentes.visible, "info residencial")
	assert(panel._residentes.text.contains("Obrero: 2"), "residentes listados")
	assert(panel._estado.text.contains("En construcción") and not panel._estado.text.contains("pausada"), "estado")
	assert(panel._salud.text == "Salud: 25 %", "salud: %s" % panel._salud.text)
	assert(panel._obreros.visible and panel._obreros.text == "Obreros: 3", "obreros")
	assert(panel._materiales.visible and panel._materiales.text.contains("15") and panel._materiales.text.contains("4"), "faltan 15 de piedra y hay 4: %s" % panel._materiales.text)
	assert(panel._pausar.visible and panel._pausar.text == "Pausar construcción" and panel._demoler.text == "Demoler", "botones")
	assert(panel._fila_prioridad.visible and panel._lbl_prioridad.text == "Prioridad: Normal", "prioridad visible y normal en construcción")
	panel._btn_prioridad_subir.pressed.emit()
	assert(obras.prioridad_de(7) == 2 and panel._lbl_prioridad.text == "Prioridad: Alta" and panel._btn_prioridad_subir.disabled, "sube a Alta")
	panel._btn_prioridad_bajar.pressed.emit()
	assert(obras.prioridad_de(7) == 1 and panel._lbl_prioridad.text == "Prioridad: Normal", "baja a Normal")
	panel._btn_prioridad_bajar.pressed.emit()
	assert(obras.prioridad_de(7) == 0 and panel._lbl_prioridad.text == "Prioridad: Baja" and panel._btn_prioridad_bajar.disabled, "baja a Baja")
	assert(panel._dialogo_demoler.has_theme_stylebox_override("panel"), "dialogo estilizado con panel")
	assert(panel._dialogo_demoler.get_theme_color("title_color") == Color(1.0, 0.85, 0.4), "titulo dorado en dialogo")
	panel._pausar.pressed.emit()
	assert(obras.pausas == 1 and panel._pausar.text == "Reanudar" and panel._estado.text.contains("pausada"), "pausar actúa sobre Obras y cambia la etiqueta")
	panel._demoler.pressed.emit()
	panel._dialogo_demoler.confirmed.emit()
	panel._dialogo_demoler.hide()
	assert(obras.marcados.has(7) and panel._demoler.text == "Cancelar demolición" and panel._pausar.text == "Reanudar", "demoler marca el edificio")
	obras.rechazo = "El núcleo urbano no se puede demoler."
	panel._demoler.pressed.emit()
	assert(avisos == ["El núcleo urbano no se puede demoler."], "un rechazo se avisa")
	obras.resumen = {"nombre": "Casa", "tipo": "Residencial", "estado": "completo", "pausada": false, "salud": 1.0, "faltantes": {}}
	ciudad.registrar_edificio_residencial(7, [2])
	panel._actualizar()
	assert(panel._salud.text == "Salud: 100 %" and not panel._materiales.visible and not panel._obreros.visible and not panel._pausar.visible and not panel._fila_prioridad.visible, "completo: 100 %, sin materiales, sin obreros, sin pausa y sin prioridad")
	assert(panel._asignar_nucleo.visible, "residencial completo permite asignar como núcleo")
	assert(panel._remodelar.visible and panel._remodelar.text == "Iniciar remodelación", "botón remodelar visible")
	assert(panel._colonizable.visible and panel._toggle_colonizable.visible, "colonizabilidad visible")
	assert(panel._colonizable.text.contains("Colonizable: SÍ"), "primer edificio es colonizable SÍ")
	assert(panel._toggle_colonizable.text == "Pausar colonización")
	panel._toggle_colonizable.pressed.emit()
	assert(not ciudad.es_colonizable(7), "toggle pausa colonización")
	assert(panel._colonizable.text.contains("Colonizable: NO"), "texto actualizado a NO")
	assert(panel._toggle_colonizable.text == "Permitir colonización")
	panel._remodelar.pressed.emit()
	assert(panel._dialogo_remodelar.visible, "abre dialogo de remodelar")
	panel._dialogo_remodelar.hide()

	obras.es_nucleo = true
	panel._actualizar()
	assert(panel._titulo.text == "Núcleo urbano", "título núcleo")
	assert(not panel._demoler.visible, "núcleo sin botón demoler")
	assert(not panel._asignar_nucleo.visible, "núcleo sin botón asignar núcleo")
	assert(panel._remodelar.visible, "núcleo permite remodelar")
	assert(not panel._colonizable.visible, "núcleo no tiene colonizabilidad de camas")
	assert(panel._btn_racionamiento.visible, "racionamiento visible en núcleo completo")
	assert(panel._btn_racionamiento.text == Strings.PANEL_EDIFICIO_RACIONAMIENTO_INACTIVO)
	panel._btn_racionamiento.pressed.emit()
	assert(ciudad.decreto_racionamiento_activo, "alterna racionamiento a activo")
	assert(panel._btn_racionamiento.text == Strings.PANEL_EDIFICIO_RACIONAMIENTO_ACTIVO)
	panel._btn_racionamiento.pressed.emit()
	assert(not ciudad.decreto_racionamiento_activo, "alterna racionamiento de vuelta a inactivo")
	assert(panel._btn_racionamiento.text == Strings.PANEL_EDIFICIO_RACIONAMIENTO_INACTIVO)

	obras.es_nucleo = false
	obras.resumen = {}
	panel._process(0.0)
	assert(not panel.visible, "se cierra solo si el edificio desaparece")
	panel.queue_free()
	ciudad.free()


func probar_panel_edificio_racionamiento() -> void:
	print("\n=== TEST: Boton de Racionamiento en PanelEdificio del Núcleo ===")
	var PanelEdificioScript = preload("res://scripts/PanelEdificio.gd")
	var panel_ed := PanelEdificioScript.new()
	add_child(panel_ed)
	assert(panel_ed._btn_racionamiento != null)
	panel_ed.queue_free()


func probar_marcas_demolicion() -> void:
	print("=== TEST: MarcasDemolicionOverlay dibuja una caja roja por celda de cada edificio marcado ===")
	var MarcasScript = preload("res://scripts/MarcasDemolicionOverlay.gd")
	var obras := ObrasFalsa.new()
	obras.marcados = {7: true}
	obras.celdas = {7: [Vector3i(1, 1, 1), Vector3i(2, 1, 1)], 8: [Vector3i(5, 1, 5)]}
	var overlay: Node3D = MarcasScript.new()
	overlay.obras = obras
	add_child(overlay)
	overlay.reconstruir()
	assert(overlay.get_child_count() == 2, "una caja por celda del edificio marcado y ninguna del otro: %d" % overlay.get_child_count())
	obras.marcados = {}
	overlay.reconstruir()
	assert(overlay.get_child_count() == 0, "al desmarcar se quitan")
	obras.marcados = {8: true}
	obras.marca_cambiada.emit(8, true)
	assert(overlay.get_child_count() == 1, "la señal marca_cambiada reconstruye")
	overlay.queue_free()


func probar_panel_canalizacion() -> void:
	print("=== TEST: PanelCanalizacion muestra datos de la red de ducto y sus conexiones ===")
	var PanelCanalizacionScript = preload("res://scripts/PanelCanalizacion.gd")
	Canalizaciones.reiniciar()
	var red_test: int = 101
	Canalizaciones.tipo_por_red[red_test] = "tuberia"
	Canalizaciones.recurso_por_red[red_test] = "crudo"
	Canalizaciones.red_a_celdas[red_test] = [Vector3i(10, 4, 10), Vector3i(11, 4, 10)]

	var esq_orig := Vector2i(10, 10)
	var esq_dest := Vector2i(20, 10)
	Economia.registrar_puesto(esq_orig, "centro_extraccion", 5, 5, {})
	Economia.registrar_puesto(esq_dest, "almacen", 5, 5, {})

	var p_out := Vector3i(10, 4, 10)
	var p_in := Vector3i(20, 4, 10)
	Canalizaciones.puertos_conectados[p_out] = red_test
	Canalizaciones.tipo_por_puerto[p_out] = "puerto_crudo_out"
	Canalizaciones.puertos_conectados[p_in] = red_test
	Canalizaciones.tipo_por_puerto[p_in] = "puerto_crudo_in"

	var panel: PanelContainer = PanelCanalizacionScript.new()
	add_child(panel)
	panel.abrir(red_test)
	assert(panel.visible, "el panel se abre")
	assert("Tubería #101" in panel._titulo.text)
	assert("Crudo" in panel._recurso.text)
	assert("Centro de extracción" in panel._conexiones.text, "muestra edificio origen conectado")
	assert("Almacén" in panel._conexiones.text, "muestra edificio destino conectado")

	# Probar demoler desde el panel
	panel._confirmar_demoler()
	assert(not panel.visible, "tras demoler el panel se cierra")
	assert(not Canalizaciones.tipo_por_red.has(red_test), "la red fue eliminada")

	panel.queue_free()
	Economia.puestos.erase(esq_orig)
	Economia.puestos.erase(esq_dest)
	Canalizaciones.reiniciar()
	print("OK: PanelCanalizacion verificado.")


class MundoFalsoZonaOverlay extends Node:
	signal terreno_modificado(celda: Vector3i)

	var alturas: Dictionary = {}
	var tipos: Dictionary = {}

	func altura_en(x: int, z: int, _ignorar_agua: bool = false) -> int:
		return alturas.get(Vector2i(x, z), 10)

	func es_celda_estructural(_celda: Vector3i) -> bool:
		return false

	func obtener_tipo(celda: Vector3i) -> String:
		return tipos.get(celda, "tierra")


func probar_zona_overlay_reactividad_terreno() -> void:
	print("=== TEST: ZonaOverlay se actualiza automáticamente al modificar terreno sin esperar herramienta de zonificación ===")
	var ZonaOverlayScript = preload("res://scripts/ZonaOverlay.gd")
	var mundo_falso := MundoFalsoZonaOverlay.new()
	var overlay: Node3D = ZonaOverlayScript.new()
	overlay.mundo = mundo_falso
	add_child(overlay)

	# Declarar núcleo urbano para inicializar la zona de influencia correctamente
	Zonificacion.nucleo_declarado = false
	Zonificacion.declarar_nucleo([Vector2i(5, 5)])
	mundo_falso.alturas[Vector2i(5, 5)] = 10
	overlay.visible = true
	overlay.reconstruir()

	assert(not overlay._sucio, "arranca limpio tras reconstruir")

	# Cavar en (5, 5): la altura baja a 7
	mundo_falso.alturas[Vector2i(5, 5)] = 7
	mundo_falso.terreno_modificado.emit(Vector3i(5, 10, 5))

	assert(overlay._sucio, "la señal terreno_modificado marca sucio el overlay")

	# El siguiente frame procesa y reconstruye automáticamente
	overlay._process(0.0)
	assert(not overlay._sucio, "tras procesar vuelve a estar limpio")

	# Comprobar que el plano de la celda (5, 5) ahora está a la nueva altura 7
	var encontrado := false
	for hijo in overlay.get_children():
		if hijo is MeshInstance3D and is_equal_approx(hijo.position.x, 5.5) and is_equal_approx(hijo.position.z, 5.5):
			assert(is_equal_approx(hijo.position.y, 7.0 + 1.01), "el plano se actualizó a la nueva altura del terreno cavado (7 + 1.01)")
			encontrado = true
			break
	assert(encontrado, "se encontró el plano en la celda cavada con la altura actualizada")

	overlay.queue_free()
	mundo_falso.queue_free()
	Zonificacion.nucleo_declarado = false
	Zonificacion._huella_nucleo.clear()
	Zonificacion._caja_nucleo.clear()
	Zonificacion.zonas.clear()
	print("OK: ZonaOverlay reacciona a terreno_modificado en tiempo real.")


func probar_investigacion_ui() -> void:
	print("\n=== TEST: Widget de Era e IDU en BarraSuperior ===")
	var barra: PanelContainer = BarraSuperiorScript.new()
	add_child(barra)
	assert(barra._lbl_era != null, "_lbl_era no debe ser nulo")
	assert(barra._lbl_idu != null, "_lbl_idu no debe ser nulo")
	barra.actualizar()
	assert(barra._lbl_era.text.contains("Asentamiento Pionero"), "debe mostrar Asentamiento Pionero inicial: %s" % barra._lbl_era.text)
	assert(barra._lbl_idu.text.begins_with("IDU:"), "debe mostrar IDU formateado: %s" % barra._lbl_idu.text)
	assert(barra._lbl_idu.tooltip_text.contains("Sofisticación"), "tooltip debe contener desglose S")
	assert(barra._lbl_idu.tooltip_text.contains("Cualificación"), "tooltip debe contener desglose Q")
	assert(barra._lbl_idu.tooltip_text.contains("Ciencia"), "tooltip debe contener desglose K")
	var tt_control = barra._make_custom_tooltip(barra._lbl_idu.tooltip_text)
	assert(tt_control != null and tt_control is PanelContainer, "debe generar un Control de tooltip estilizado")

	barra._on_nivel_mouse_entered()
	assert(barra._panel_hover_idu != null and barra._panel_hover_idu.visible, "hover sobre nivel debe abrir panel flotante")
	assert(barra._lbl_hover_idu_titulo.text.contains("Nivel I"), "debe mostrar Nivel I para IDU 1.0")
	barra._on_nivel_mouse_exited()
	assert(not barra._panel_hover_idu.visible, "mouse exit debe cerrar el panel flotante")
	barra.queue_free()

	print("\n=== TEST: Controles de Capa 1 en PanelPuesto (Universidad) ===")
	var esq_uni := Vector2i(2000, 2000)
	Economia.registrar_puesto(esq_uni, "universidad", 5, 5, {})
	var panel_p := PanelPuestoScript.new()
	add_child(panel_p)
	panel_p.abrir(esq_uni)
	assert(panel_p._caja_ciencias_teoricas != null, "_caja_ciencias_teoricas debe existir en PanelPuesto")
	assert(panel_p._caja_ciencias_teoricas.visible, "universidad debe mostrar caja de ciencias teoricas")

	# Verificar persistencia de botones de ciencias teóricas a través de múltiples frames sin recreación
	var btn_primera_tech: Button = null
	for id_c in panel_p._items_ciencias_teoricas:
		var btn = panel_p._items_ciencias_teoricas[id_c]["btn"]
		if btn != null:
			btn_primera_tech = btn
			break
	assert(btn_primera_tech != null, "debe existir al menos un boton de ciencia teorica")

	for i in range(5):
		panel_p._process(0.0)

	var btn_despues: Button = null
	for id_c in panel_p._items_ciencias_teoricas:
		var btn = panel_p._items_ciencias_teoricas[id_c]["btn"]
		if btn != null:
			btn_despues = btn
			break
	assert(btn_primera_tech == btn_despues, "los botones no deben ser recreados en cada frame")

	# Probar puesto industrial con mejoras prácticas (central termoeléctrica)
	var esq_central := Vector2i(2010, 2010)
	Economia.registrar_puesto(esq_central, "central_termoelectrica", 5, 5, {})
	panel_p.abrir(esq_central)
	assert(panel_p._caja_mejoras_practicas != null, "_caja_mejoras_practicas debe existir")
	assert(panel_p._caja_mejoras_practicas.visible, "central termoelectrica debe mostrar caja de mejoras")
	assert(panel_p._btn_reconversion != null, "_btn_reconversion debe existir")

	var btn_mejora_ref: Button = null
	for id_m in panel_p._items_mejoras_practicas:
		var btn = panel_p._items_mejoras_practicas[id_m]["btn"]
		if btn != null:
			btn_mejora_ref = btn
			break
	assert(btn_mejora_ref != null, "debe existir boton de mejora practica en central")

	for i in range(5):
		panel_p._process(0.0)

	var btn_mejora_despues: Button = null
	for id_m in panel_p._items_mejoras_practicas:
		var btn = panel_p._items_mejoras_practicas[id_m]["btn"]
		if btn != null:
			btn_mejora_despues = btn
			break
	assert(btn_mejora_ref == btn_mejora_despues, "los botones de mejoras no deben ser recreados en cada frame")

	panel_p.cerrar()
	panel_p.queue_free()
	Economia.puestos.erase(esq_uni)
	Economia.puestos.erase(esq_central)

	print("\n=== TEST: Controles de Mejoras y Reconversión en PanelEdificio ===")
	var PanelEdificioScript = preload("res://scripts/PanelEdificio.gd")
	var panel_e: PanelContainer = PanelEdificioScript.new()
	add_child(panel_e)
	assert(panel_e._caja_mejoras != null, "_caja_mejoras debe existir en PanelEdificio")
	assert(panel_e._btn_reconversion != null, "_btn_reconversion debe existir en PanelEdificio")

	var btn_rec_ref = panel_e._btn_reconversion
	for i in range(5):
		panel_e._process(0.0)
	assert(panel_e._btn_reconversion == btn_rec_ref, "el boton de reconversion no debe ser recreado en cada frame")
	panel_e.queue_free()


func probar_transporte_ui() -> void:
	print("\n=== TEST: Controles de Transporte y Taller en PanelPuesto ===")
	var panel_p := PanelPuestoScript.new()
	add_child(panel_p)
	assert(panel_p._caja_transporte_puesto != null, "_caja_transporte_puesto debe existir en PanelPuesto")
	assert(panel_p._caja_taller_transporte != null, "_caja_taller_transporte debe existir en PanelPuesto")
	assert(panel_p._lbl_transporte_actual != null, "_lbl_transporte_actual debe existir en PanelPuesto")
	assert(panel_p._lbl_nombre_evolutivo_taller != null, "_lbl_nombre_evolutivo_taller debe existir en PanelPuesto")
	assert(panel_p._barra_progreso_taller != null, "_barra_progreso_taller debe existir en PanelPuesto")

	# 1. Puesto periférico con acarreadores (ej. mina)
	var esq_mina := Vector2i(3000, 3000)
	Economia.registrar_puesto(esq_mina, "mina", 5, 5, {})
	panel_p.abrir(esq_mina)
	assert(panel_p._caja_transporte_puesto.visible, "puesto de mina debe mostrar caja de transporte")
	assert(not panel_p._caja_taller_transporte.visible, "puesto de mina no debe mostrar caja de taller de transporte")
	assert(panel_p._lbl_transporte_actual.text.contains("Acarreador a Pie"), "transporte inicial debe ser Acarreador a Pie: %s" % panel_p._lbl_transporte_actual.text)

	# Verificar persistencia de botones de asignación de transporte sin recreación por frame
	var btn_pie: Button = panel_p._botones_transporte.get("acarreador_pie")
	assert(btn_pie != null, "debe existir boton para volver a acarreador a pie")
	assert(btn_pie.disabled, "el boton del vehiculo actualmente asignado debe estar deshabilitado")

	# Añadir un vehiculo al parque disponible de la ciudad y comprobar visibilidad del boton
	Ciudad.registrar_vehiculo_disponible("carreta_mano", 1)
	panel_p._process(0.0)
	var btn_carreta: Button = panel_p._botones_transporte.get("carreta_mano")
	assert(btn_carreta != null and btn_carreta.visible, "el boton de carreta_mano debe hacerse visible al haber unidades disponibles")
	assert(not btn_carreta.disabled, "el boton de carreta_mano disponible debe estar habilitado")

	for i in range(5):
		panel_p._process(0.0)
	assert(panel_p._botones_transporte.get("carreta_mano") == btn_carreta, "los botones de transporte no deben recrearse en cada frame")

	# Asignar carreta de mano al puesto
	assert(Economia.asignar_tipo_transporte_puesto(esq_mina, "carreta_mano"), "debe poder asignar carreta_mano")
	panel_p._process(0.0)
	assert(panel_p._lbl_transporte_actual.text.contains("Carreta de Mano"), "debe reflejar Carreta de Mano asignada")
	assert(btn_carreta.disabled, "boton de carreta_mano debe deshabilitarse tras ser asignado")
	assert(not btn_pie.disabled, "boton de volver a pie debe habilitarse")

	# 2. Puesto Taller de Transporte
	var era_previa: int = Ciudad.era_actual
	Ciudad.era_actual = 2
	var esq_taller := Vector2i(3010, 3010)
	Economia.registrar_puesto(esq_taller, "taller_transporte", 5, 5, {})
	panel_p.abrir(esq_taller)
	assert(not panel_p._caja_transporte_puesto.visible, "taller no debe mostrar caja de asignacion de transporte")
	assert(panel_p._caja_taller_transporte.visible, "taller debe mostrar caja de taller de transporte")
	var nom_evolutivo: String = Economia.obtener_nombre_evolutivo_taller(esq_taller)
	assert(panel_p._lbl_nombre_evolutivo_taller.text == nom_evolutivo, "debe mostrar nombre evolutivo del taller")

	# Botones de fabricacion persistentes
	var btn_fab_carreta: Button = panel_p._botones_fabricacion.get("carreta_mano")
	assert(btn_fab_carreta != null, "debe existir boton de fabricacion de carreta_mano en catalogo")
	for i in range(5):
		panel_p._process(0.0)
	assert(panel_p._botones_fabricacion.get("carreta_mano") == btn_fab_carreta, "los botones de fabricacion no deben recrearse en cada frame")

	# Simular orden de fabricacion y progreso
	Ciudad.almacen["madera"].cantidad = 500.0
	Ciudad.almacen["hierro"].cantidad = 500.0
	panel_p._process(0.0)
	assert(not btn_fab_carreta.disabled, "con recursos suficientes el boton de fabricar debe estar habilitado")
	assert(Economia.ordenar_fabricacion_vehiculo(esq_taller, "carreta_mano"), "debe poder ordenar fabricacion")
	panel_p._process(0.0)
	assert(panel_p._lbl_estado_ensamblaje.text.contains("Carreta de Mano"), "debe mostrar estado de ensamblaje en curso")
	assert(panel_p._barra_progreso_taller.visible, "la barra de progreso de ensamblaje debe ser visible")

	panel_p.cerrar()
	panel_p.queue_free()
	Economia.puestos.erase(esq_mina)
	Economia.puestos.erase(esq_taller)
	Ciudad.era_actual = era_previa
	print("OK: Controles de transporte y taller de transporte en PanelPuesto verificados correctamente.")

	print("\n=== TEST 16: Hotbar cuenta bloques_piedra para bloque_piedra y PanelEdificio auto-transición a PanelPuesto ===")
	# 1. Hotbar con bloques_piedra
	var hotbar_test: PanelContainer = HotbarScript.new()
	add_child(hotbar_test)
	hotbar_test.configurar(["bloque_piedra"])
	var cant_piedra_previa: float = Ciudad.almacen["piedra"].cantidad if Ciudad.almacen.has("piedra") else 0.0
	var cant_bp_previa: float = Ciudad.almacen["bloques_piedra"].cantidad if Ciudad.almacen.has("bloques_piedra") else 0.0
	Ciudad.almacen["piedra"].cantidad = 0.0
	Ciudad.almacen["bloques_piedra"].cantidad = 50.0
	hotbar_test.actualizar_cantidades()
	assert(hotbar_test.cantidad_de(0) == 10, "solo con bloques_piedra se cuentan 10 bloques de piedra (5 cada uno): %d" % hotbar_test.cantidad_de(0))
	Ciudad.almacen["piedra"].cantidad = cant_piedra_previa
	Ciudad.almacen["bloques_piedra"].cantidad = cant_bp_previa
	hotbar_test.queue_free()

	# 2. PanelEdificio auto-transición al completarse un puesto
	var panel_trans: PanelContainer = PanelEdificioScript.new()
	add_child(panel_trans)
	var obras_mock := ObrasPanelFalso.new()
	panel_trans.obras = obras_mock
	panel_trans.ciudad = Ciudad
	panel_trans.colonos = Colonos
	obras_mock.resumen = {"nombre": "Pesca", "tipo": "Puesto", "estado": "construccion", "pausada": false, "salud": 0.5, "faltantes": {}}
	var esq_puesto_test := Vector2i(9900, 9900)
	var puesto_solicitado: Array[Vector2i] = [Vector2i(-1, -1)]
	panel_trans.solicitar_abrir_puesto.connect(func(e: Vector2i) -> void: puesto_solicitado[0] = e)
	panel_trans.abrir(77)
	assert(panel_trans.visible and panel_trans.id == 77, "panel de edificio abierto en construccion")

	# Completar obra y registrar puesto en Recoleccion
	Recoleccion.colocar_puesto(esq_puesto_test, "pesca_frutos_mar", 4, 6)
	Economia.registrar_puesto(esq_puesto_test, "pesca_frutos_mar", 4, 6, {})
	obras_mock.id_columna = 77
	obras_mock.resumen = {"nombre": "Pesca", "tipo": "Puesto", "estado": "completo", "pausada": false, "salud": 1.0, "faltantes": {}}
	panel_trans._actualizar()
	assert(puesto_solicitado[0] == esq_puesto_test, "debe emitir solicitar_abrir_puesto con la esquina del puesto: %s" % str(puesto_solicitado[0]))
	assert(not panel_trans.visible, "PanelEdificio debe cerrarse tras auto-transición")
	Recoleccion.puestos.erase(esq_puesto_test)
	Economia.puestos.erase(esq_puesto_test)
	panel_trans.queue_free()
	print("OK: Hotbar y auto-transición a PanelPuesto verificados correctamente.")


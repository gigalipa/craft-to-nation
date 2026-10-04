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
	var pausas := 0
	var rechazo := ""
	var es_nucleo := false

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
	probar_panel_escuela()
	probar_panel_niveles()
	probar_panel_edificio()
	probar_marcas_demolicion()


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
	assert(BarraSuperiorScript.clave_critica({"a": RecursoFalso.new("A", 0, 1, 0.0), "b": RecursoFalso.new("B", 0, 1, 0.0)}) == "")
	assert(BarraSuperiorScript.clave_critica({}) == "")
	assert(BarraSuperiorScript.texto_energia(30.0, 50.0) == "Energía: 30/50 E/h")

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


func _textos(caja: Node) -> Array:
	var textos: Array = []
	for hijo in caja.get_children():
		if hijo is Label:
			textos.append((hijo as Label).text)
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
	assert("Técnicos: 5 · 3 empleados · 2 sin empleo" in textos, "salió %s" % [textos])
	assert("Obreros: 4 · 1 empleados · 3 sin empleo" in textos, "salió %s" % [textos])
	assert("Desempleados: 2" in textos, "solo el total: %s" % [textos])
	assert(not textos.any(func(t: String) -> bool: return t.contains("Ciudadanos") or t.contains("Especialistas")), "los tipos sin habitantes no salen")
	assert(not textos.any(func(t: String) -> bool: return t.contains("Puestos de trabajo")), "la lista de puestos pasó a Ocupaciones")
	# Un técnico libre cuenta como sin empleo aunque los demás trabajen: el mínimo de "sin empleo" es 0.
	Ciudad.demografia["tecnico"] = 2
	ventana._actualizar()
	assert("Técnicos: 2 · 3 empleados · 0 sin empleo" in _textos(ventana._caja), "salió %s" % [_textos(ventana._caja)])
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
	print("=== TEST 1e: Ocupaciones lista los sitios de trabajo, se actualiza sin recrear filas y emite edificio_pedido ===")
	var puestos_previos: Dictionary = Economia.puestos
	Economia.puestos = {}
	var ventana: PanelContainer = VentanaOcupacionesScript.new()
	add_child(ventana)
	assert(ventana.position == VentanaOcupacionesScript.POSICION_INICIAL and not ventana.visible and not ventana.abierta)
	assert(ventana.position.x >= VentanaPoblacionScript.POSICION_INICIAL.x + 320, "no solapa con Población")
	ventana.abrir()
	assert("Ninguno todavía" in _textos(ventana._caja), "salió %s" % [_textos(ventana._caja)])
	var e_mina := Vector2i(1000, 1000)
	var e_esc := Vector2i(1100, 1000)
	var e_bp := Vector2i(1200, 1000)
	Economia.registrar_puesto(e_mina, "mina", 5, 5, {})
	Economia.registrar_puesto(e_esc, "escuela_tecnica", 5, 5, {})
	Economia.registrar_puesto(e_bp, "blueprint", 5, 5, {})
	Economia.puestos[e_mina]["recolectores"] = [1, 2]
	Economia.puestos[e_mina]["acarreadores"] = [3]
	ventana._actualizar()
	var botones: Array = ventana._caja.get_children().filter(func(n: Node) -> bool: return n is Button)
	assert(botones.size() == 2, "mina y escuela; el blueprint no es puesto de trabajo (%d)" % botones.size())
	assert(not "Ninguno todavía" in _textos(ventana._caja))
	var cupo_mina: int = Economia.puestos[e_mina]["cupo"]
	var boton_mina: Button = botones[0]
	assert(boton_mina.text == "Mina 3/%d" % cupo_mina, "salió '%s'" % boton_mina.text)
	assert((botones[1] as Button).text.begins_with("Escuela técnica 0/"), "salió '%s'" % (botones[1] as Button).text)
	# Sin cambiar el conjunto de puestos, los botones son los mismos pero el texto se actualiza.
	Economia.puestos[e_mina]["acarreadores"] = []
	Economia.puestos[e_mina]["activo"] = false
	ventana._actualizar()
	assert(ventana._caja.get_children().filter(func(n: Node) -> bool: return n is Button)[0] == boton_mina, "no se recrean las filas")
	assert(boton_mina.text == "Mina 2/%d (inactivo)" % cupo_mina, "salió '%s'" % boton_mina.text)
	Economia.puestos[e_mina]["activo"] = true
	Economia.puestos[e_mina]["agotado"] = true
	ventana._actualizar()
	assert(boton_mina.text == "Mina 2/%d (agotado)" % cupo_mina, "salió '%s'" % boton_mina.text)
	# El clic emite la esquina de su fila.
	var pedidos: Array = []
	ventana.edificio_pedido.connect(func(esquina: Vector2i) -> void: pedidos.append(esquina))
	boton_mina.pressed.emit()
	(ventana._caja.get_children().filter(func(n: Node) -> bool: return n is Button)[1] as Button).pressed.emit()
	assert(pedidos == [e_mina, e_esc], "salió %s" % [pedidos])
	# Si cambia el conjunto, se reconstruye.
	Economia.puestos.erase(e_esc)
	ventana._actualizar()
	assert(ventana._caja.get_children().filter(func(n: Node) -> bool: return n is Button).size() == 1)
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
	panel.mostrar("Puerta", {}, ["(clic der.) COLOCAR", "[E] INTERACTUAR"])
	assert(panel.acciones.get_parsed_text().contains("[E] INTERACTUAR"), "el atajo de tecla se muestra literal, antes de la acción")
	assert(PanelContextualScript.texto_acciones(["MARCAR PARA DEMOLICIÓN (clic der.)"]).contains("click_der.svg"), "la acción de demolición lleva el ícono del clic derecho")

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
	assert(panel._titulo.text == "Puesto maderero, nivel 1", "nivel en el título: %s" % panel._titulo.text)
	assert(panel._filas["recolector"]["fila"].visible and panel._filas["tecnico"]["fila"].visible and panel._filas["acarreador"]["fila"].visible)
	assert(not panel._filas["aprendiz"]["fila"].visible)
	assert(panel._filas["especialista"]["fila"].visible, "la fila de especialistas siempre aparece en puestos con niveles")
	assert(panel._filas["tecnico"]["libres"].text == "(%d libres)" % Colonos.tecnicos_libres())
	assert(panel._filas["recolector"]["libres"].text == "(%d libres)" % Ciudad.demografia["desempleado"])
	Economia.asignar(esquina8, "tecnico", 99999)
	panel._actualizar()
	assert(panel._titulo.text == "Puesto maderero, nivel 2", "con un técnico sube a nivel 2: %s" % panel._titulo.text)
	assert(panel._filas["recolector"]["mas"].disabled, "un puesto de nivel 2 no admite obreros")
	assert(panel._filas["tecnico"]["cantidad"].text == "1" and panel._filas["recolector"]["cantidad"].text == "0")
	assert(not panel._filas["tecnico"]["menos"].disabled and panel._filas["recolector"]["menos"].disabled)
	Economia.liberar(99999)
	panel.queue_free()
	Economia.puestos.erase(esquina8)


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
	panel._pausar.pressed.emit()
	assert(obras.pausas == 1 and panel._pausar.text == "Reanudar" and panel._estado.text.contains("pausada"), "pausar actúa sobre Obras y cambia la etiqueta")
	panel._demoler.pressed.emit()
	panel._dialogo_demoler.confirmed.emit()
	assert(obras.marcados.has(7) and panel._demoler.text == "Cancelar demolición" and panel._pausar.text == "Reanudar", "demoler marca el edificio")
	obras.rechazo = "El núcleo urbano no se puede demoler."
	panel._demoler.pressed.emit()
	assert(avisos == ["El núcleo urbano no se puede demoler."], "un rechazo se avisa")
	obras.resumen = {"nombre": "Casa", "tipo": "Residencial", "estado": "completo", "pausada": false, "salud": 1.0, "faltantes": {}}
	panel._actualizar()
	assert(panel._salud.text == "Salud: 100 %" and not panel._materiales.visible and not panel._obreros.visible and not panel._pausar.visible, "completo: 100 %, sin materiales, sin obreros y sin botón de pausa")
	assert(panel._asignar_nucleo.visible, "residencial completo permite asignar como núcleo")

	obras.es_nucleo = true
	panel._actualizar()
	assert(panel._titulo.text == "Núcleo urbano", "título núcleo")
	assert(not panel._demoler.visible, "núcleo sin botón demoler")
	assert(not panel._asignar_nucleo.visible, "núcleo sin botón asignar núcleo")

	obras.es_nucleo = false
	obras.resumen = {}
	panel._process(0.0)
	assert(not panel.visible, "se cierra solo si el edificio desaparece")
	panel.queue_free()
	ciudad.free()


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

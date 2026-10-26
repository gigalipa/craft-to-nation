extends PanelContainer

## Panel de un puesto de recolección (clic izquierdo sobre él en la cenital,
## ver CamaraCenital._procesar_clic). Se construye por código: título, filas
## "Obreros/Técnicos/Especialistas/Aprendices [-] n [+] (libres)" y "Acarreadores ...", el título muestra el
## nivel del puesto; además almacén local, producción y distancia al núcleo. Las reglas viven en
## Economia/Colonos; esto solo las muestra y les pasa los clics.

const Ajustes = preload("res://scripts/ajustes.gd")
const Strings = preload("res://scripts/strings.gd")
const HUDScript = preload("res://scripts/HUD.gd")
const TemaHUD = preload("res://scripts/TemaHUD.gd")

const PlantillasPuesto = preload("res://scripts/PlantillasPuesto.gd")

static var NOMBRES_PUESTO: Dictionary = Strings.NOMBRES_PUESTO
## Mensaje para el jugador (el HUD lo envía a las notificaciones).
signal aviso(texto: String)

static var NOMBRES_ROL: Dictionary = {
	"recolector": Strings.PANEL_PUESTO_ROL_OBREROS,
	"tecnico": Strings.PANEL_PUESTO_ROL_TECNICOS,
	"especialista": Strings.PANEL_PUESTO_ROL_ESPECIALISTAS,
	"aprendiz": Strings.PANEL_PUESTO_ROL_APRENDICES,
	"investigador": Strings.PANEL_PUESTO_ROL_INVESTIGADORES,
	"acarreador": Strings.PANEL_PUESTO_ROL_ACARREADORES,
}

var esquina := Recoleccion.SIN_PUESTO

class ContenedorPuertos extends VBoxContainer:
	var text: String = ""

class ContenedorProduccion extends HBoxContainer:
	var text: String = ""

var _icono_puesto := TextureRect.new()
var _icono_nivel := TextureRect.new()
var _titulo := TemaHUD.etiqueta()
var _trabajadores := TemaHUD.etiqueta()
var _libres := TemaHUD.etiqueta()
var _almacen := TemaHUD.etiqueta()
var _produccion := ContenedorProduccion.new()
var _caja_items_prod := VBoxContainer.new()
var _scroll_prod := ScrollContainer.new()
var _energia := TemaHUD.etiqueta()
var _crudo_restante := TemaHUD.etiqueta()
var _selector_combustible := HBoxContainer.new()
var _botones_combustible: Dictionary = {}
var _puertos := ContenedorPuertos.new()
var _desplegado_conexiones: bool = true
var _desplegados_recursos: Dictionary = {
	"agua": true,
	"crudo": true,
	"combustible": true,
}
var _btn_conexiones: Button
var _caja_conexiones: VBoxContainer
var _bloques_recurso: Dictionary = {}
var _botones_recurso: Dictionary = {}
var _contenedores_recurso: Dictionary = {}
var _etiquetas_in: Dictionary = {}
var _etiquetas_out: Dictionary = {}
var _distancia := TemaHUD.etiqueta()
var _demoler := Button.new()
var _dialogo_demoler := ConfirmationDialog.new()
var _filas := {}  # rol -> {"fila": HBoxContainer, "cantidad": Label, "menos": Button, "mas": Button, "libres": Label}
var _fila_reserva := HBoxContainer.new()
var _lbl_reserva_val := TemaHUD.etiqueta()
var _btn_reserva_subir := Button.new()
var _btn_reserva_bajar := Button.new()
var _btn_reserva := Button.new()

var _caja_investigacion: VBoxContainer
var _lbl_inv_estado: Label
var _barra_inv: ProgressBar
var _caja_botones_tech: VBoxContainer
var _botones_tech: Dictionary = {}  # id_tech -> Button
var _caja_controles_inv: HBoxContainer
var _btn_pausar_inv: Button
var _btn_cancelar_inv: Button
var _dialogo_investigar := ConfirmationDialog.new()
var _contenido_dialogo_inv: VBoxContainer
var _dialogo_cancelar_inv := ConfirmationDialog.new()
var _id_tech_seleccionada: int = 0

var _caja_ciencias_teoricas: VBoxContainer = null
var _lbl_teoricas_titulo: Label = null
var _lista_ciencias_teoricas: VBoxContainer = null
var _caja_mejoras_practicas: VBoxContainer = null
var _lbl_mejoras_titulo: Label = null
var _lista_mejoras_practicas: VBoxContainer = null
var _btn_reconversion: Button = null
var _dialogo_reconversion := ConfirmationDialog.new()
var _id_mejora_reconversion: String = ""


func _ready() -> void:
	visible = false
	TemaHUD.aplicar_panel(self)
	mouse_filter = Control.MOUSE_FILTER_STOP  # los botones +/- necesitan capturar el clic
	# Abajo a la derecha: arriba las notificaciones ocupan ese lugar (decisión del usuario, 2026-10-02).
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -372.0
	offset_bottom = -12.0
	offset_right = -12.0
	custom_minimum_size.x = 360.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN  # si crece, hacia la izquierda
	grow_vertical = Control.GROW_DIRECTION_BEGIN  # y hacia arriba
	var caja := VBoxContainer.new()
	add_child(caja)

	var fila_tit := HBoxContainer.new()
	fila_tit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila_tit.add_theme_constant_override("separation", 6)
	_icono_puesto.custom_minimum_size = Vector2(20, 20)
	_icono_puesto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fila_tit.add_child(_icono_puesto)
	_titulo.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DORADO_SUAVE)
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_tit.add_child(_titulo)
	_icono_nivel.custom_minimum_size = Vector2(16, 16)
	_icono_nivel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fila_tit.add_child(_icono_nivel)
	caja.add_child(fila_tit)

	for rol in ["recolector", "tecnico", "especialista", "aprendiz", "investigador", "acarreador"]:
		caja.add_child(_crear_fila(rol))
	# Selector de combustible para central termoeléctrica
	var lbl_comb := TemaHUD.etiqueta("Combustible:")
	_selector_combustible.add_child(lbl_comb)
	for id_c in ["carbon", "combustible", "crudo"]:
		var btn := Button.new()
		btn.text = HUDScript.NOMBRES_RECURSO.get(id_c, id_c).capitalize()
		btn.icon = IconosHUD.icono(id_c)
		btn.expand_icon = true
		TemaHUD.estilizar_boton(btn)
		btn.pressed.connect(func() -> void:
			if Economia.tiene_puesto(esquina):
				Economia.cambiar_combustible_central(esquina, id_c)
				_actualizar()
		)
		_selector_combustible.add_child(btn)
		_botones_combustible[id_c] = btn
	caja.add_child(_selector_combustible)

	for etiqueta in [_trabajadores, _libres, _crudo_restante, _almacen, _energia, _distancia]:
		# Las líneas largas (varios recursos) parten en vez de ensanchar el panel.
		etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		etiqueta.custom_minimum_size.x = 340.0

	caja.add_child(_trabajadores)
	caja.add_child(_libres)
	caja.add_child(_crudo_restante)
	caja.add_child(_almacen)

	_produccion.add_theme_constant_override("separation", 6)
	_produccion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl_prod_pref := TemaHUD.etiqueta("Producción:")
	_produccion.add_child(lbl_prod_pref)
	_scroll_prod.custom_minimum_size = Vector2(250, 72)
	_scroll_prod.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_caja_items_prod.add_theme_constant_override("separation", 4)
	_caja_items_prod.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll_prod.add_child(_caja_items_prod)
	_produccion.add_child(_scroll_prod)
	caja.add_child(_produccion)

	_fila_reserva.add_theme_constant_override("separation", 6)
	var lbl_res := TemaHUD.etiqueta("Reserva central:")
	lbl_res.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_res.size_flags_vertical = Control.SIZE_FILL
	_fila_reserva.add_child(lbl_res)
	_lbl_reserva_val.custom_minimum_size.x = 135.0
	_lbl_reserva_val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_reserva_val.size_flags_vertical = Control.SIZE_FILL
	_fila_reserva.add_child(_lbl_reserva_val)
	_btn_reserva_subir.icon = IconosHUD.icono("btn_subir")
	_btn_reserva_subir.custom_minimum_size = Vector2(24, 24)
	_btn_reserva_subir.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_btn_reserva_subir.expand_icon = true
	_btn_reserva_subir.tooltip_text = "Aumentar reserva central"
	TemaHUD.estilizar_boton_icono(_btn_reserva_subir)
	_btn_reserva_subir.pressed.connect(func() -> void:
		if Economia.tiene_puesto(esquina):
			Economia.subir_reserva_insumo(esquina)
			_actualizar()
	)
	_fila_reserva.add_child(_btn_reserva_subir)
	_btn_reserva_bajar.icon = IconosHUD.icono("btn_bajar")
	_btn_reserva_bajar.custom_minimum_size = Vector2(24, 24)
	_btn_reserva_bajar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_btn_reserva_bajar.expand_icon = true
	_btn_reserva_bajar.tooltip_text = "Reducir reserva central"
	TemaHUD.estilizar_boton_icono(_btn_reserva_bajar)
	_btn_reserva_bajar.pressed.connect(func() -> void:
		if Economia.tiene_puesto(esquina):
			Economia.bajar_reserva_insumo(esquina)
			_actualizar()
	)
	_fila_reserva.add_child(_btn_reserva_bajar)
	caja.add_child(_fila_reserva)

	caja.add_child(_energia)

	_caja_investigacion = VBoxContainer.new()
	_caja_investigacion.add_theme_constant_override("separation", 4)
	caja.add_child(_caja_investigacion)

	_lbl_inv_estado = TemaHUD.etiqueta()
	_lbl_inv_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_inv_estado.custom_minimum_size.x = 340.0
	_caja_investigacion.add_child(_lbl_inv_estado)

	_barra_inv = ProgressBar.new()
	_barra_inv.show_percentage = true
	_barra_inv.custom_minimum_size = Vector2(340, 18)
	var sb_bg_inv := TemaHUD.caja_boton(Color(0.04, 0.08, 0.06, 0.9), TemaHUD.DORADO)
	var sb_fg_inv := StyleBoxFlat.new()
	sb_fg_inv.bg_color = Color(0.2, 0.7, 0.3)
	sb_fg_inv.set_corner_radius_all(3)
	_barra_inv.add_theme_stylebox_override("background", sb_bg_inv)
	_barra_inv.add_theme_stylebox_override("fill", sb_fg_inv)
	_caja_investigacion.add_child(_barra_inv)

	_caja_botones_tech = VBoxContainer.new()
	_caja_botones_tech.add_theme_constant_override("separation", 4)
	_caja_investigacion.add_child(_caja_botones_tech)

	for id_tech: int in Ciudad.COSTOS_INVESTIGACION:
		var btn := Button.new()
		TemaHUD.estilizar_boton(btn)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.icon = IconosHUD.icono("tec_metalurgia" if id_tech == 2 else "tec_automatizacion")
		btn.expand_icon = true
		btn.pressed.connect(func() -> void: _abrir_dialogo_investigar(id_tech))
		_caja_botones_tech.add_child(btn)
		_botones_tech[id_tech] = btn

	_caja_controles_inv = HBoxContainer.new()
	_caja_controles_inv.add_theme_constant_override("separation", 6)
	_caja_investigacion.add_child(_caja_controles_inv)

	_btn_pausar_inv = Button.new()
	_btn_pausar_inv.text = Strings.PANEL_PUESTO_BTN_PAUSAR
	_btn_pausar_inv.icon = IconosHUD.icono("btn_pausa")
	_btn_pausar_inv.expand_icon = true
	TemaHUD.estilizar_boton(_btn_pausar_inv)
	_btn_pausar_inv.pressed.connect(_on_pausar_investigacion)
	_caja_controles_inv.add_child(_btn_pausar_inv)

	_btn_cancelar_inv = Button.new()
	_btn_cancelar_inv.text = Strings.PANEL_PUESTO_BTN_CANCELAR
	_btn_cancelar_inv.icon = IconosHUD.icono("cruz")
	_btn_cancelar_inv.expand_icon = true
	TemaHUD.estilizar_boton(_btn_cancelar_inv)
	_btn_cancelar_inv.pressed.connect(func() -> void: _dialogo_cancelar_inv.popup_centered())
	_caja_controles_inv.add_child(_btn_cancelar_inv)

	_dialogo_investigar.title = "Confirmar investigación"
	_dialogo_investigar.ok_button_text = "Investigar"
	_dialogo_investigar.cancel_button_text = Strings.PANEL_PUESTO_BTN_CANCELAR
	_dialogo_investigar.confirmed.connect(_confirmar_investigacion)
	TemaHUD.estilizar_dialogo(_dialogo_investigar)
	_contenido_dialogo_inv = VBoxContainer.new()
	_contenido_dialogo_inv.add_theme_constant_override("separation", 6)
	_dialogo_investigar.add_child(_contenido_dialogo_inv)
	add_child(_dialogo_investigar)

	_dialogo_cancelar_inv.title = "Confirmar cancelación"
	_dialogo_cancelar_inv.dialog_text = "¿Cancelar la investigación en curso? Se reembolsará la totalidad de los recursos gastados."
	_dialogo_cancelar_inv.ok_button_text = Strings.PANEL_EDIFICIO_BTN_CONFIRMAR
	_dialogo_cancelar_inv.cancel_button_text = Strings.PANEL_PUESTO_BTN_CANCELAR
	_dialogo_cancelar_inv.confirmed.connect(_confirmar_cancelar_investigacion)
	TemaHUD.estilizar_dialogo(_dialogo_cancelar_inv)
	add_child(_dialogo_cancelar_inv)

	_caja_ciencias_teoricas = VBoxContainer.new()
	_caja_ciencias_teoricas.add_theme_constant_override("separation", 4)
	caja.add_child(_caja_ciencias_teoricas)

	_lbl_teoricas_titulo = TemaHUD.etiqueta("Ciencias Básicas Teóricas (Capa 1):")
	_lbl_teoricas_titulo.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DORADO_SUAVE)
	_caja_ciencias_teoricas.add_child(_lbl_teoricas_titulo)

	_lista_ciencias_teoricas = VBoxContainer.new()
	_lista_ciencias_teoricas.add_theme_constant_override("separation", 4)
	_caja_ciencias_teoricas.add_child(_lista_ciencias_teoricas)

	_caja_mejoras_practicas = VBoxContainer.new()
	_caja_mejoras_practicas.add_theme_constant_override("separation", 4)
	caja.add_child(_caja_mejoras_practicas)

	_lbl_mejoras_titulo = TemaHUD.etiqueta("Mejoras Prácticas (Capa 2):")
	_lbl_mejoras_titulo.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DORADO_SUAVE)
	_caja_mejoras_practicas.add_child(_lbl_mejoras_titulo)

	_lista_mejoras_practicas = VBoxContainer.new()
	_lista_mejoras_practicas.add_theme_constant_override("separation", 4)
	_caja_mejoras_practicas.add_child(_lista_mejoras_practicas)

	_btn_reconversion = Button.new()
	_btn_reconversion.text = Strings.RECONVERSION_BTN_INICIAR
	_btn_reconversion.icon = IconosHUD.icono("modo_construir")
	_btn_reconversion.expand_icon = true
	_btn_reconversion.tooltip_text = Strings.RECONVERSION_TOOLTIP
	TemaHUD.estilizar_boton(_btn_reconversion)
	_btn_reconversion.pressed.connect(func() -> void:
		if _id_mejora_reconversion != "":
			_dialogo_reconversion.popup_centered()
	)
	_caja_mejoras_practicas.add_child(_btn_reconversion)

	_dialogo_reconversion.title = Strings.RECONVERSION_BTN_INICIAR
	_dialogo_reconversion.dialog_text = "¿Deseas iniciar la reconversión industrial doctrinal de este edificio?"
	_dialogo_reconversion.ok_button_text = Strings.PANEL_EDIFICIO_BTN_CONFIRMAR
	_dialogo_reconversion.cancel_button_text = Strings.PANEL_PUESTO_BTN_CANCELAR
	_dialogo_reconversion.confirmed.connect(_confirmar_reconversion)
	TemaHUD.estilizar_dialogo(_dialogo_reconversion)
	add_child(_dialogo_reconversion)

	_construir_widgets_puertos()
	caja.add_child(_puertos)

	caja.add_child(_distancia)

	_demoler.icon = IconosHUD.icono("modo_demoler")
	_demoler.expand_icon = true
	TemaHUD.estilizar_boton(_demoler)
	_demoler.pressed.connect(_on_demoler)
	caja.add_child(_demoler)
	_dialogo_demoler.title = "Confirmar demolición"
	_dialogo_demoler.dialog_text = "¿Demoler este puesto? Comenzará en 5 horas de juego."
	_dialogo_demoler.ok_button_text = Strings.PANEL_EDIFICIO_BTN_CONFIRMAR
	_dialogo_demoler.cancel_button_text = Strings.PANEL_PUESTO_BTN_CANCELAR
	_dialogo_demoler.confirmed.connect(_confirmar_demoler)
	TemaHUD.estilizar_dialogo(_dialogo_demoler)
	add_child(_dialogo_demoler)


func _construir_widgets_puertos() -> void:
	_puertos.add_theme_constant_override("separation", 3)
	_puertos.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_btn_conexiones = Button.new()
	_btn_conexiones.alignment = HORIZONTAL_ALIGNMENT_LEFT
	TemaHUD.estilizar_boton(_btn_conexiones)
	_btn_conexiones.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DORADO_SUAVE)
	_btn_conexiones.pressed.connect(func() -> void:
		_desplegado_conexiones = not _desplegado_conexiones
		_actualizar()
	)
	_puertos.add_child(_btn_conexiones)

	var margen_con := MarginContainer.new()
	margen_con.add_theme_constant_override("margin_left", 8)
	margen_con.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_puertos.add_child(margen_con)

	_caja_conexiones = VBoxContainer.new()
	_caja_conexiones.add_theme_constant_override("separation", 3)
	_caja_conexiones.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margen_con.add_child(_caja_conexiones)

	for rec in ["agua", "crudo", "combustible"]:
		var bloque := VBoxContainer.new()
		bloque.add_theme_constant_override("separation", 2)
		bloque.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_caja_conexiones.add_child(bloque)
		_bloques_recurso[rec] = bloque

		var btn_rec := Button.new()
		btn_rec.alignment = HORIZONTAL_ALIGNMENT_LEFT
		TemaHUD.estilizar_boton(btn_rec)
		btn_rec.add_theme_color_override("font_color", TemaHUD.TEXTO)
		btn_rec.pressed.connect(func() -> void:
			_desplegados_recursos[rec] = not _desplegados_recursos.get(rec, true)
			_actualizar()
		)
		bloque.add_child(btn_rec)
		_botones_recurso[rec] = btn_rec

		var margen_rec := MarginContainer.new()
		margen_rec.add_theme_constant_override("margin_left", 14)
		margen_rec.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bloque.add_child(margen_rec)
		_contenedores_recurso[rec] = margen_rec

		var caja_detalles := VBoxContainer.new()
		caja_detalles.add_theme_constant_override("separation", 2)
		caja_detalles.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margen_rec.add_child(caja_detalles)

		var lbl_in := TemaHUD.etiqueta()
		lbl_in.add_theme_font_size_override("font_size", 12)
		lbl_in.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caja_detalles.add_child(lbl_in)
		_etiquetas_in[rec] = lbl_in

		var lbl_out := TemaHUD.etiqueta()
		lbl_out.add_theme_font_size_override("font_size", 12)
		lbl_out.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caja_detalles.add_child(lbl_out)
		_etiquetas_out[rec] = lbl_out


func _crear_fila(rol: String) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	var ic := IconosHUD.crear_rect(IconosHUD.icono_demografia(rol), 16)
	ic.custom_minimum_size = Vector2(16, 16)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(ic)
	var nombre := TemaHUD.etiqueta(NOMBRES_ROL[rol])
	nombre.custom_minimum_size.x = 135.0
	nombre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nombre.size_flags_vertical = Control.SIZE_FILL
	fila.add_child(nombre)
	
	var cont_cant := HBoxContainer.new()
	cont_cant.custom_minimum_size.x = 95.0
	cont_cant.add_theme_constant_override("separation", 4)
	cont_cant.size_flags_vertical = Control.SIZE_FILL
	var cantidad := TemaHUD.etiqueta()
	cantidad.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var libres := TemaHUD.etiqueta()
	libres.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cont_cant.add_child(cantidad)
	cont_cant.add_child(libres)
	fila.add_child(cont_cant)
	
	var cont_acciones := HBoxContainer.new()
	cont_acciones.add_theme_constant_override("separation", 4)
	cont_acciones.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var mas := Button.new()
	mas.icon = IconosHUD.icono("btn_subir")
	if mas.icon == null:
		mas.text = "+"
	mas.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mas.expand_icon = true
	mas.custom_minimum_size = Vector2(24, 24)
	mas.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mas.tooltip_text = Strings.PANEL_PUESTO_BTN_CONTRATAR_TOOLTIP
	TemaHUD.estilizar_boton_icono(mas)
	mas.pressed.connect(func() -> void: Colonos.contratar(esquina, rol))
	
	var menos := Button.new()
	menos.icon = IconosHUD.icono("btn_bajar")
	if menos.icon == null:
		menos.text = "-"
	menos.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menos.expand_icon = true
	menos.custom_minimum_size = Vector2(24, 24)
	menos.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menos.tooltip_text = Strings.PANEL_PUESTO_BTN_DESPEDIR_TOOLTIP
	TemaHUD.estilizar_boton_icono(menos)
	menos.pressed.connect(func() -> void: Colonos.despedir(esquina, rol))
	
	cont_acciones.add_child(mas)
	cont_acciones.add_child(menos)
	fila.add_child(cont_acciones)
	_filas[rol] = {"fila": fila, "nombre": nombre, "cantidad": cantidad, "menos": menos, "mas": mas, "libres": libres}
	return fila


func abrir(nueva_esquina: Vector2i) -> void:
	if not Economia.tiene_puesto(nueva_esquina):
		return
	esquina = nueva_esquina
	visible = true
	if Economia.puestos[esquina].get("agotado", false):
		Economia.recalcular_tasas(esquina)
	_actualizar()


func cerrar() -> void:
	visible = false
	esquina = Recoleccion.SIN_PUESTO


func _process(_delta: float) -> void:
	if not visible:
		return
	if not Economia.tiene_puesto(esquina):
		cerrar()  # el puesto se deconstruyó con el panel abierto
		return
	_actualizar()


func _actualizar() -> void:
	var puesto: Dictionary = Economia.puestos[esquina]
	var t: Dictionary = Economia.trabajadores_de(esquina)
	var es_escuela: bool = Economia.es_escuela(esquina)
	var es_universidad: bool = Economia.es_universidad(esquina)
	var con_niveles: bool = Economia.tiene_niveles(esquina)
	# Oficios que producen aquí: vacíos en el almacén, investigadores en la universidad, aprendices en la escuela, solo técnicos en la refinería/extractores, los tres oficios en los puestos con niveles.
	var oficios: Array = [] if puesto["tipo"] == "almacen" else (["investigador"] if es_universidad else (["aprendiz"] if es_escuela else (["recolector", "tecnico", "especialista"] if con_niveles else ["tecnico"])))
	var estado := ""
	if not puesto["activo"]:
		estado = " (inactivo)"
	elif puesto["agotado"]:
		estado = " (agotado)"
	_titulo.text = NOMBRES_PUESTO.get(puesto["tipo"], puesto["tipo"]) + estado
	_icono_puesto.texture = IconosHUD.icono(puesto["tipo"])
	_icono_nivel.texture = IconosHUD.icono(IconosHUD.icono_nivel_romano(Economia.nivel_de(esquina))) if con_niveles else null
	_icono_nivel.visible = con_niveles
	var sin_cupo: bool = Economia.cupo_libre(esquina) <= 0
	var origen_escuela: String = Recoleccion.ESCUELAS[puesto["tipo"]]["origen"] if es_escuela else ""
	var nombre_aprendiz: String = "Técnicos en formación" if origen_escuela == "tecnico" else Strings.PANEL_PUESTO_ROL_APRENDICES
	_filas["aprendiz"]["nombre"].text = nombre_aprendiz
	for rol in ["recolector", "tecnico", "especialista", "aprendiz", "investigador"]:
		var fila: Dictionary = _filas[rol]
		if rol != "aprendiz" or not es_escuela:
			fila["nombre"].text = NOMBRES_ROL[rol]
		var empleados: int = _empleados(rol, t, con_niveles)
		var libres: int = _libres_de(rol)
		fila["fila"].visible = oficios.has(rol)
		fila["cantidad"].text = str(empleados)
		fila["libres"].text = "(%d libres)" % libres
		fila["menos"].disabled = empleados == 0
		var limite_inv: bool = (rol == "investigador" and not Ciudad.COSTOS_INVESTIGACION.has(Ciudad.nivel_investigado + 1))
		fila["mas"].disabled = sin_cupo or libres <= 0 or not puesto["activo"] or not Economia.admite_rol(esquina, rol) or limite_inv
	var acarreadores: Dictionary = _filas["acarreador"]
	acarreadores["fila"].visible = Economia.roles_de(esquina).has("acarreador")
	acarreadores["cantidad"].text = str(t["acarreadores"])
	acarreadores["libres"].text = "(%d libres)" % Ciudad.demografia["desempleado"]
	acarreadores["menos"].disabled = t["acarreadores"] == 0
	acarreadores["mas"].disabled = sin_cupo or Ciudad.demografia["desempleado"] <= 0 or not puesto["activo"]
	if puesto["tipo"] == "almacen":
		_trabajadores.text = "Almacén logístico (sin personal)"
	elif es_universidad:
		var id_act: int = puesto.get("investigacion_activa", 0)
		var nom_proy: String = "Ninguno"
		if id_act > 0 and Ciudad.COSTOS_INVESTIGACION.has(id_act):
			nom_proy = Ciudad.COSTOS_INVESTIGACION[id_act]["nombre"]
		_trabajadores.text = "Investigadores: %d / %d (presentes: %d)\nProyecto: %s" % [t["recolectores"], puesto["cupo"], t["presentes"], nom_proy]
	elif es_escuela:
		var horas: int = Recoleccion.ESCUELAS[puesto["tipo"]]["horas"]
		_trabajadores.text = "%s: %d / %d (presentes: %d)\nFormación de la cohorte: %d / %d h" % [nombre_aprendiz, t["recolectores"], puesto["cupo"], t["presentes"], int(puesto["progreso"]), horas]
	else:
		_trabajadores.text = "Trabajadores: %d / %d (presentes: %d)" % [t["recolectores"] + t["acarreadores"], puesto["cupo"], t["presentes"]]
	var siguiente_inv: int = Ciudad.nivel_investigado + 1
	var sin_candidatos_inv: bool = es_universidad and _libres_de("investigador") == 0 and Ciudad.COSTOS_INVESTIGACION.has(siguiente_inv)
	var total_trabajadores: int = t["recolectores"] + t["acarreadores"]
	var hay_vacantes: bool = total_trabajadores < puesto["cupo"]
	_libres.visible = (not es_escuela and not con_niveles and not es_universidad and puesto["tipo"] != "almacen" and Colonos.tecnicos_libres() == 0 and hay_vacantes) or sin_candidatos_inv
	if sin_candidatos_inv:
		_libres.text = "Sin candidatos libres: requiere %s" % ("técnicos o especialistas" if siguiente_inv == 2 else "especialistas")
	else:
		if Ciudad.demografia.get("tecnico", 0) > 0:
			_libres.text = "No hay técnicos libres"
		else:
			_libres.text = "Sin técnicos libres: fórmalos en una escuela técnica"
	_almacen.visible = not es_escuela and not es_universidad
	_produccion.visible = not es_escuela and not es_universidad and puesto["tipo"] != "central_termoelectrica" and puesto["tipo"] != "almacen"
	_almacen.text = "Almacén local: " + _texto_recursos(Economia.almacen_local(esquina), "vacío") + " (máx. %d)" % puesto["capacidad"]
	_actualizar_produccion(Economia.produccion_por_hora(esquina))

	if Economia.es_refineria(esquina) or puesto["tipo"] == "central_termoelectrica":
		_fila_reserva.visible = true
		var val_res: float = Economia.obtener_reserva_insumo(esquina)
		var recurso_insumo: String = "carbon" if puesto["tipo"] == "central_termoelectrica" else ""
		if recurso_insumo == "":
			var entradas: Dictionary = Economia.entradas_de(esquina)
			for r in entradas:
				if not Economia.RECURSOS_LIQUIDOS.has(r):
					recurso_insumo = r
					break
		var unid_res: float = Economia.calcular_reserva_en_unidades(esquina, recurso_insumo)
		if val_res <= 0.0:
			_lbl_reserva_val.text = "Sin reserva (0% / 0 u)"
			_btn_reserva.text = _lbl_reserva_val.text
			_btn_reserva_bajar.disabled = true
			_btn_reserva_subir.disabled = false
		else:
			var pct_int: int = int(round(val_res * 100.0))
			_lbl_reserva_val.text = "%d%% (%.0f u)" % [pct_int, unid_res]
			_btn_reserva.text = _lbl_reserva_val.text
			_btn_reserva_bajar.disabled = false
			var lista: Array = Economia.PORCENTAJES_RESERVA_INSUMO
			_btn_reserva_subir.disabled = is_equal_approx(val_res, lista.back())
	else:
		_fila_reserva.visible = false

	if puesto["tipo"] == "central_termoelectrica":
		_selector_combustible.visible = true
		var comb_act: String = puesto.get("combustible_activo", "carbon")
		for id_c in _botones_combustible:
			_botones_combustible[id_c].disabled = (id_c == comb_act)
		_energia.visible = true
		var t_pres: int = t["presentes"]
		var alm: Dictionary = puesto["almacen"]
		var stock: float = alm.get("combustible", 0.0) + alm.get("crudo", 0.0) + alm.get("carbon", 0.0)
		var cap_esta: float = minf(float(t_pres), stock) * Ajustes.ENERGIA_POR_LOTE_CENTRAL
		var res: Dictionary = Economia.balance_energia
		var cap_total: float = res.get("capacidad", 0.0)
		var entregada_total: float = res.get("entregada", 0.0)
		var uso: float = 0.0
		if cap_total > 1e-9:
			uso = entregada_total * (cap_esta / cap_total)
		var comb_actual := "ninguno"
		for c in Ajustes.ENERGIA_ORDEN_COMBUSTIBLES:
			if alm.get(c, 0.0) > 1e-9:
				comb_actual = "%s (%.1f)" % [HUDScript.NOMBRES_RECURSO.get(c, c), alm[c]]
				break
		_energia.text = "Capacidad: %.0f E/h\nGeneración usada: %.1f E/h\nCombustible actual: %s" % [cap_esta, uso, comb_actual]
	elif puesto["tipo"] == "refineria_petrolera" or puesto["tipo"] == "productor_combustible" or es_universidad:
		var demanda: float = 0.0
		if puesto["tipo"] == "refineria_petrolera" or puesto["tipo"] == "productor_combustible":
			demanda = float(t["presentes"]) * 1.0
		elif es_universidad:
			var id_act_e: int = puesto.get("investigacion_activa", 0)
			if id_act_e == 3:
				demanda = float(t["presentes"]) * 2.0
		_selector_combustible.visible = false
		if es_universidad and demanda <= 0.0:
			_energia.visible = false
		else:
			_energia.visible = true
			var res: Dictionary = Economia.balance_energia
			var conectados: Dictionary = res.get("conectados", {})
			var conectado: bool = conectados.get(esquina, false)
			var factor: float = Economia.factor_energia_de(esquina)
			var cap_red: float = res.get("capacidad", 0.0)
			var estado_e: String = texto_estado_energia(conectado, demanda, factor, cap_red)
			_energia.text = "Energía: %s" % estado_e
	else:
		_selector_combustible.visible = false
		_energia.visible = false

	_caja_investigacion.visible = es_universidad
	if es_universidad:
		var id_act: int = puesto.get("investigacion_activa", 0)
		var pausada: bool = puesto.get("investigacion_pausada", false)
		if id_act > 0 and Ciudad.COSTOS_INVESTIGACION.has(id_act):
			var info_act: Dictionary = Ciudad.COSTOS_INVESTIGACION[id_act]
			var nom_tech: String = info_act["nombre"]
			var meta: float = float(info_act["horas_investigador"])
			var prog: float = Ciudad.progreso_investigacion.get(id_act, 0.0)
			var pct: int = int(clampf((prog / meta) * 100.0, 0.0, 100.0))
			var restantes_h: float = maxf(0.0, meta - prog)
			var cant_efectiva: int = t["presentes"] if t["presentes"] > 0 else t["recolectores"]
			var str_tiempo: String
			if cant_efectiva > 0:
				var horas_est: int = int(ceil(restantes_h / float(cant_efectiva)))
				str_tiempo = "%d horas" % horas_est
			else:
				str_tiempo = "Sin investigadores"
			if pausada:
				str_tiempo += " (Pausado)"
			_lbl_inv_estado.text = "Investigación en curso: %s\nProgreso: %d%% | %s" % [nom_tech, pct, str_tiempo]
			_lbl_inv_estado.visible = true
			if _barra_inv != null:
				_barra_inv.visible = true
				_barra_inv.value = pct
			_caja_botones_tech.visible = false
			_caja_controles_inv.visible = true
			_btn_pausar_inv.disabled = false
			_btn_pausar_inv.text = Strings.PANEL_PUESTO_BTN_REANUDAR if pausada else Strings.PANEL_PUESTO_BTN_PAUSAR
			_btn_pausar_inv.icon = IconosHUD.icono("btn_play" if pausada else "btn_pausa")
			_btn_cancelar_inv.disabled = false
			_btn_cancelar_inv.icon = IconosHUD.icono("cruz")
		else:
			if _barra_inv != null:
				_barra_inv.visible = false
			_caja_controles_inv.visible = false
			_btn_pausar_inv.disabled = true
			_btn_cancelar_inv.disabled = true
			var todas_listas := true
			for k: int in Ciudad.COSTOS_INVESTIGACION:
				if Ciudad.nivel_investigado < k:
					todas_listas = false
					break
			if todas_listas:
				_lbl_inv_estado.text = "Todas las investigaciones completadas"
				_caja_botones_tech.visible = false
			else:
				_lbl_inv_estado.text = "Investigaciones disponibles:"
				_caja_botones_tech.visible = true
				for id_tech: int in Ciudad.COSTOS_INVESTIGACION:
					var btn: Button = _botones_tech[id_tech]
					var info_tech: Dictionary = Ciudad.COSTOS_INVESTIGACION[id_tech]
					if Ciudad.nivel_investigado >= id_tech:
						btn.text = Strings.PANEL_PUESTO_TECH_COMPLETADA % info_tech["nombre"]
						btn.disabled = true
					elif id_tech > 2 and Ciudad.nivel_investigado < id_tech - 1:
						btn.text = "🔒 %s (Requiere nivel %d)" % [info_tech["nombre"], id_tech - 1]
						btn.disabled = true
					elif Economia.investigacion_en_curso_en_otra_universidad(esquina, id_tech):
						btn.text = "⏳ %s (%s)" % [info_tech["nombre"], Strings.PANEL_PUESTO_TECH_YA_EN_CURSO]
						btn.disabled = true
					else:
						btn.text = "Investigar: %s" % info_tech["nombre"]
						btn.disabled = false

	if _caja_ciencias_teoricas != null:
		if es_universidad:
			_caja_ciencias_teoricas.visible = true
			for child in _lista_ciencias_teoricas.get_children():
				child.queue_free()

			var era_actual_ciudad: int = Ciudad.era_actual if ("era_actual" in Ciudad) else 1
			for id_c in Ajustes.CIENCIAS_TEORICAS_CATALOGO:
				var info_c: Dictionary = Ajustes.CIENCIAS_TEORICAS_CATALOGO[id_c]
				var nom_c: String = info_c.get("nombre", id_c)
				var era_c: int = int(info_c.get("era", 1))
				var pts_c: int = int(info_c.get("costo_puntos", 100))
				var prerreq_c: String = info_c.get("prerrequisito", "")
				var descubierta: bool = Ciudad.esta_ciencia_descubierta(id_c) if Ciudad.has_method("esta_ciencia_descubierta") else false
				var activa: bool = (Ciudad.ciencia_teorica_activa == id_c) if ("ciencia_teorica_activa" in Ciudad) else false

				if descubierta:
					var lbl_d := TemaHUD.etiqueta("✅ %s (Completada)" % nom_c)
					lbl_d.add_theme_color_override("font_color", TemaHUD.VALIDO)
					_lista_ciencias_teoricas.add_child(lbl_d)
				elif activa:
					var vbox_a := VBoxContainer.new()
					vbox_a.add_theme_constant_override("separation", 2)
					var prog: float = Ciudad.progreso_ciencia_teorica.get(id_c, 0.0) if ("progreso_ciencia_teorica" in Ciudad) else 0.0
					var pct: int = int(clampf((prog / float(pts_c)) * 100.0, 0.0, 100.0))
					var lbl_a := TemaHUD.etiqueta("🔬 %s: %d / %d pts (%d%%)" % [nom_c, int(prog), pts_c, pct])
					lbl_a.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DORADO_SUAVE)
					vbox_a.add_child(lbl_a)
					var bar := ProgressBar.new()
					bar.show_percentage = false
					bar.max_value = float(pts_c)
					bar.value = prog
					bar.custom_minimum_size = Vector2(320, 12)
					var sb_bg := TemaHUD.caja_boton(Color(0.04, 0.08, 0.06, 0.9), TemaHUD.DORADO)
					var sb_fg := StyleBoxFlat.new()
					sb_fg.bg_color = TemaHUD.color_doctrina(info_c.get("doctrina", "")) if info_c.has("doctrina") else Color(0.2, 0.7, 0.3)
					sb_fg.set_corner_radius_all(2)
					bar.add_theme_stylebox_override("background", sb_bg)
					bar.add_theme_stylebox_override("fill", sb_fg)
					vbox_a.add_child(bar)
					_lista_ciencias_teoricas.add_child(vbox_a)
				else:
					var req_ok: bool = prerreq_c == "" or (Ciudad.has_method("esta_ciencia_descubierta") and Ciudad.esta_ciencia_descubierta(prerreq_c))
					var era_ok: bool = era_c <= era_actual_ciudad
					if not era_ok:
						var lbl_l := TemaHUD.etiqueta("🔒 %s (Requiere Era %d)" % [nom_c, era_c])
						lbl_l.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DESHABILITADO)
						_lista_ciencias_teoricas.add_child(lbl_l)
					elif not req_ok:
						var nom_pre: String = Ajustes.CIENCIAS_TEORICAS_CATALOGO.get(prerreq_c, {}).get("nombre", prerreq_c)
						var lbl_l := TemaHUD.etiqueta("🔒 %s (Requiere: %s)" % [nom_c, nom_pre])
						lbl_l.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DESHABILITADO)
						_lista_ciencias_teoricas.add_child(lbl_l)
					else:
						var btn_c := Button.new()
						btn_c.text = "Investigar: %s (%d pts)" % [nom_c, pts_c]
						TemaHUD.estilizar_boton(btn_c)
						var id_cap: String = id_c
						btn_c.pressed.connect(func() -> void:
							if Ciudad.has_method("iniciar_ciencia_teorica"):
								Ciudad.iniciar_ciencia_teorica(id_cap)
								_actualizar()
						)
						_lista_ciencias_teoricas.add_child(btn_c)
		else:
			_caja_ciencias_teoricas.visible = false

	if _caja_mejoras_practicas != null:
		var tipo_puesto: String = puesto.get("tipo", "")
		var posibles_mejoras: Array = []
		for id_m in Ajustes.MEJORAS_PRACTICAS_CATALOGO:
			var m_data: Dictionary = Ajustes.MEJORAS_PRACTICAS_CATALOGO[id_m]
			if m_data.get("edificio_tipo", "") == tipo_puesto:
				posibles_mejoras.append(id_m)

		if posibles_mejoras.is_empty():
			_caja_mejoras_practicas.visible = false
		else:
			_caja_mejoras_practicas.visible = true
			for child in _lista_mejoras_practicas.get_children():
				child.queue_free()

			var instaladas: Array = puesto.get("mejoras", [])
			var pm: Dictionary = puesto.get("proyecto_mejora", {})
			var era_actual_ciudad: int = Ciudad.era_actual if ("era_actual" in Ciudad) else 1

			if not pm.is_empty():
				var id_act_m: String = pm.get("id", "")
				var info_pm: Dictionary = Ajustes.MEJORAS_PRACTICAS_CATALOGO.get(id_act_m, {})
				var nom_pm: String = info_pm.get("nombre", id_act_m)
				var estado_pm: String = pm.get("estado", "ESPERANDO_PERSONAL")
				var es_rec: bool = pm.get("es_reconversion", false) or puesto.get("estado_operativo", "") == "RECONVERSION"
				var req_inv: int = int(pm.get("investigadores_requeridos", 1))

				var id_proy: String = "mejora_%d_%d" % [esquina.x, esquina.y]
				var presentes_inv: int = 0
				if Colonos != null and "comisiones_activas" in Colonos and Colonos.comisiones_activas.has(id_proy):
					var com_info: Dictionary = Colonos.comisiones_activas[id_proy]
					var dest_proy: Vector3i = com_info.get("destino", Vector3i.ZERO)
					for cid in com_info.get("miembros", []):
						if Colonos.colonos.has(cid) and Colonos.colonos[cid].get("celda") == dest_proy:
							presentes_inv += 1

				var desc_est := "Esperando personal científico (%d/%d)" % [presentes_inv, req_inv]
				if estado_pm == "EN_EJECUCION":
					desc_est = "En ejecución (%d/%d)" % [presentes_inv, req_inv]
				var prefijo := "Reconversión" if es_rec else "Mejora"
				var lbl_proy := TemaHUD.etiqueta("⚙ %s: %s\nEstado: %s" % [prefijo, nom_pm, desc_est])
				lbl_proy.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DORADO_SUAVE)
				_lista_mejoras_practicas.add_child(lbl_proy)

				var prog_m: float = float(pm.get("progreso", 0.0))
				var t_total: float = float(pm.get("tiempo", 1.0))
				var bar_m := ProgressBar.new()
				bar_m.show_percentage = true
				bar_m.max_value = t_total
				bar_m.value = prog_m
				bar_m.custom_minimum_size = Vector2(320, 14)
				_lista_mejoras_practicas.add_child(bar_m)
				_btn_reconversion.visible = false
			else:
				var incompatible_para_reconversion: String = ""
				for id_m in posibles_mejoras:
					var info_m: Dictionary = Ajustes.MEJORAS_PRACTICAS_CATALOGO[id_m]
					var nom_m: String = info_m.get("nombre", id_m)
					var doc_m: String = info_m.get("doctrina", "")
					var nom_doc: String = Strings.DOCTRINA_NOMBRES.get(doc_m, doc_m.capitalize())

					if instaladas.has(id_m):
						var lbl_inst := TemaHUD.etiqueta("✅ %s (%s)" % [nom_m, nom_doc])
						lbl_inst.add_theme_color_override("font_color", TemaHUD.color_doctrina(doc_m))
						_lista_mejoras_practicas.add_child(lbl_inst)
					else:
						var prerreq_m: String = info_m.get("prerrequisito", "")
						var req_ok: bool = prerreq_m == "" or (Ciudad.has_method("esta_ciencia_descubierta") and Ciudad.esta_ciencia_descubierta(prerreq_m))
						var era_ok: bool = int(info_m.get("era", 1)) <= era_actual_ciudad

						var es_incompatible: bool = false
						for ex in info_m.get("excluye", []):
							if instaladas.has(ex):
								es_incompatible = true
								break
						for m_inst in instaladas:
							var inst_data: Dictionary = Ajustes.MEJORAS_PRACTICAS_CATALOGO.get(m_inst, {})
							if inst_data.get("excluye", []).has(id_m):
								es_incompatible = true
								break
							if inst_data.get("doctrina", "") != "" and doc_m != "" and inst_data.get("doctrina", "") != doc_m:
								es_incompatible = true

						if es_incompatible:
							if req_ok and era_ok:
								incompatible_para_reconversion = id_m
							var lbl_inc := TemaHUD.etiqueta("⚠ %s (Incompatible con doctrina instalada)" % nom_m)
							lbl_inc.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3))
							_lista_mejoras_practicas.add_child(lbl_inc)
						elif not req_ok:
							var nom_req: String = Ajustes.CIENCIAS_TEORICAS_CATALOGO.get(prerreq_m, {}).get("nombre", prerreq_m)
							var lbl_lock := TemaHUD.etiqueta("🔒 %s (Requiere: %s)" % [nom_m, nom_req])
							lbl_lock.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DESHABILITADO)
							_lista_mejoras_practicas.add_child(lbl_lock)
						elif not era_ok:
							var lbl_lock := TemaHUD.etiqueta("🔒 %s (Requiere Era %d)" % [nom_m, int(info_m.get("era", 1))])
							lbl_lock.add_theme_color_override("font_color", Ajustes.COLOR_HUD_TEXTO_DESHABILITADO)
							_lista_mejoras_practicas.add_child(lbl_lock)
						else:
							var btn_inst := Button.new()
							btn_inst.text = "Instalar: %s (%s)" % [nom_m, nom_doc]
							TemaHUD.estilizar_boton(btn_inst)
							var id_capturado_m: String = id_m
							btn_inst.pressed.connect(func() -> void:
								if Economia != null and Economia.has_method("iniciar_mejora_practica"):
									Economia.iniciar_mejora_practica(esquina, id_capturado_m)
									_actualizar()
							)
							_lista_mejoras_practicas.add_child(btn_inst)

				if incompatible_para_reconversion != "" and instaladas.size() > 0:
					_btn_reconversion.visible = true
					_id_mejora_reconversion = incompatible_para_reconversion
					_btn_reconversion.text = "%s: %s" % [Strings.RECONVERSION_BTN_INICIAR, Ajustes.MEJORAS_PRACTICAS_CATALOGO[incompatible_para_reconversion]["nombre"]]
				else:
					_btn_reconversion.visible = false

	if puesto["tipo"] == "centro_extraccion":
		_crudo_restante.visible = true
		var dp: Dictionary = puesto.get("entorno", {}).get("datos_perforacion", {})
		if dp.get("tipo_pozo", "") == "crudo":
			_crudo_restante.text = "Crudo restante en pozo: %d bloques" % puesto.get("crudo_restante", 0)
		else:
			_crudo_restante.text = "Pozo de agua (inagotable)"
	else:
		_crudo_restante.visible = false

	var lista_puertos: Array[Dictionary] = _puertos_del_puesto()
	if not lista_puertos.is_empty():
		_puertos.visible = true
		_btn_conexiones.text = "%s Conexiones" % ("▼" if _desplegado_conexiones else "▶")
		_caja_conexiones.get_parent().visible = _desplegado_conexiones

		var lineas_resumen: Array[String] = ["Puertos de conexión:"]

		for rec in ["agua", "crudo", "combustible"]:
			var p_in = null
			var p_out = null
			for p_data in lista_puertos:
				if p_data["recurso"] == rec:
					if p_data["direccion"] == "Entrada":
						p_in = p_data
					elif p_data["direccion"] == "Salida":
						p_out = p_data

			if p_in == null and p_out == null:
				_bloques_recurso[rec].visible = false
				continue

			_bloques_recurso[rec].visible = true

			var sim_in := _simbolo_estado(p_in["estado"]) if p_in != null else "—"
			var sim_out := _simbolo_estado(p_out["estado"]) if p_out != null else "—"
			var nombre_rec: String = HUDScript.NOMBRES_RECURSO.get(rec, rec.capitalize())
			var desplegado_rec: bool = _desplegados_recursos.get(rec, true)
			var flecha_rec := "▼" if desplegado_rec else "▶"

			var texto_hdr := ""
			if p_in != null and p_out != null:
				texto_hdr = "%s %s I%s/O%s:" % [flecha_rec, nombre_rec, sim_in, sim_out]
			elif p_in != null:
				texto_hdr = "%s %s I%s:" % [flecha_rec, nombre_rec, sim_in]
			else:
				texto_hdr = "%s %s O%s:" % [flecha_rec, nombre_rec, sim_out]

			_botones_recurso[rec].text = texto_hdr
			_contenedores_recurso[rec].visible = desplegado_rec

			if p_in != null:
				_etiquetas_in[rec].visible = true
				_etiquetas_in[rec].text = "* Entrada: %s %s" % [sim_in, _texto_estado(p_in["estado"])]
				lineas_resumen.append("• %s: %s %s" % [p_in["nombre"], sim_in, _texto_estado(p_in["estado"])])
			else:
				_etiquetas_in[rec].visible = false

			if p_out != null:
				_etiquetas_out[rec].visible = true
				_etiquetas_out[rec].text = "* Salida: %s %s" % [sim_out, _texto_estado(p_out["estado"])]
				lineas_resumen.append("• %s: %s %s" % [p_out["nombre"], sim_out, _texto_estado(p_out["estado"])])
			else:
				_etiquetas_out[rec].visible = false

		_puertos.text = "\n".join(lineas_resumen)
	else:
		_puertos.visible = false
		_puertos.text = ""

	_distancia.text = "Distancia al núcleo: %s" % _distancia_al_nucleo()
	var id_puesto: int = Obras.id_en_columna(esquina)
	var en_demo: bool = Obras.esta_marcado(id_puesto) or Obras.esta_programada(id_puesto)
	_demoler.text = Strings.PANEL_PUESTO_BTN_CANCELAR_DEMOLICION if en_demo else "Demoler"


static func texto_estado_energia(conectado: bool, demanda: float, factor: float, capacidad_red: float) -> String:
	if not conectado:
		return "Sin conexión"
	if demanda <= 0.0:
		return "Sin demanda"
	if capacidad_red <= 0.0:
		return "Sin generación"
	if factor < 1.0 - 1e-9:
		return "Déficit %d %%" % roundi(factor * 100.0)
	return "Con energía"


static func _simbolo_estado(estado: String) -> String:
	match estado:
		"conectado": return "🟢"
		"derrame": return "🔴"
		_: return "⚪"


static func _texto_estado(estado: String) -> String:
	match estado:
		"conectado": return Strings.PANEL_PUESTO_PUERTO_ESTADO_CONECTADO
		"derrame": return "Derrame"
		_: return Strings.PANEL_PUESTO_PUERTO_ESTADO_DESCONECTADO



## Cuántos del oficio "rol" trabajan en el puesto: en los puestos con niveles se cuenta por rango; en la
## refinería y la escuela, todos sus recolectores (técnicos o aprendices).
func _empleados(rol: String, t: Dictionary, con_niveles: bool) -> int:
	if con_niveles:
		return Economia.contar_rango(esquina, Economia.RANGO_DE_ROL.get(rol, 0))
	return t["recolectores"]


## Colonos libres de ese oficio que se podrían contratar: técnicos y especialistas libres, o desempleados.
func _libres_de(rol: String) -> int:
	if rol == "investigador":
		var libres_inv: int = Colonos.investigadores_libres() if Colonos.has_method("investigadores_libres") else 0
		return libres_inv + Colonos.especialistas_libres()
	if rol == "aprendiz" and Economia.puestos.has(esquina):
		var tipo_p: String = Economia.puestos[esquina]["tipo"]
		if Recoleccion.ESCUELAS.has(tipo_p) and Recoleccion.ESCUELAS[tipo_p]["origen"] == "tecnico":
			return Colonos.tecnicos_libres()
	match rol:
		"tecnico": return Colonos.tecnicos_libres()
		"especialista": return Colonos.especialistas_libres()
	return Ciudad.demografia["desempleado"]


## Marca (o desmarca) el edificio del puesto para demolición, sin activar la herramienta.
func _on_demoler() -> void:
	var id: int = Obras.id_en_columna(esquina)
	if id == -1:
		aviso.emit("No se encontró el edificio del puesto.")
		return
	if Obras.esta_programada(id) or Obras.esta_marcado(id):
		var motivo: String = Obras.cancelar_demolicion(id)
		if motivo != "":
			aviso.emit(motivo)
		_actualizar()
		return
	_dialogo_demoler.popup_centered()


func _confirmar_demoler() -> void:
	var id: int = Obras.id_en_columna(esquina)
	if id == -1:
		aviso.emit("No se encontró el edificio del puesto.")
		return
	var motivo: String = Obras.programar_demolicion(id, 5)
	if motivo != "":
		aviso.emit(motivo)
	_actualizar()


func _actualizar_produccion(recursos: Dictionary) -> void:
	for hijo in _caja_items_prod.get_children():
		hijo.queue_free()
	_produccion.text = "Producción: " + _texto_recursos(recursos, "ninguna", "/h")
	if recursos.is_empty():
		var lbl := TemaHUD.etiqueta("ninguna")
		_caja_items_prod.add_child(lbl)
		return
	for rec in recursos:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 4)
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icono := IconosHUD.crear_rect(rec, 16)
		item.add_child(icono)
		var nombre_rec: String = HUDScript.NOMBRES_RECURSO.get(rec, rec).capitalize()
		var cant: float = recursos[rec]
		var lbl := TemaHUD.etiqueta("%.1f %s/h" % [cant, nombre_rec])
		item.add_child(lbl)
		_caja_items_prod.add_child(item)


static func _texto_recursos(recursos: Dictionary, vacio: String, sufijo: String = "") -> String:
	var partes: Array = []
	for recurso in recursos:
		partes.append("%.1f %s%s" % [recursos[recurso], HUDScript.NOMBRES_RECURSO.get(recurso, recurso), sufijo])
	return ", ".join(partes) if not partes.is_empty() else vacio


## Celdas (en línea recta sobre X,Z) entre el centro del puesto y el centro del
## núcleo; "-" si todavía no hay núcleo.
func _distancia_al_nucleo() -> String:
	var nucleo: Array = Zonificacion.huella_del_nucleo()
	if nucleo.is_empty():
		return "-"
	var suma := Vector2.ZERO
	for celda: Vector2i in nucleo:
		suma += Vector2(celda)
	var centro_nucleo: Vector2 = suma / nucleo.size()
	var puesto: Dictionary = Economia.puestos[esquina]
	var centro_puesto := Vector2(esquina) + Vector2(puesto["ancho"], puesto["alto"]) / 2.0
	return "%d celdas" % roundi(centro_nucleo.distance_to(centro_puesto))


func _puertos_del_puesto() -> Array[Dictionary]:
	var puesto: Dictionary = Economia.puestos.get(esquina, {})
	var tipo: String = puesto.get("tipo", "")
	var lista_info: Array = PlantillasPuesto.puertos_de(tipo)
	if lista_info.is_empty():
		return []

	var m: Object = Economia.mundo if Economia.mundo != null else (get_tree().root.find_child("VoxelWorld", true, false) if get_tree() != null and get_tree().root != null else null)
	var ancho: int = puesto.get("ancho", 0)
	var alto: int = puesto.get("alto", 0)
	var suelo: int = puesto.get("suelo", 0)
	var y_puerto: int = suelo + Ajustes.CANALIZACIONES_ALTURA_DUCTO_RELATIVA

	var celdas_puerto_encontradas: Array[Dictionary] = []
	if m != null and m.has_method("obtener_tipo"):
		for dx in range(ancho):
			for dz in range(alto):
				var celda := Vector3i(esquina.x + dx, y_puerto, esquina.y + dz)
				var tipo_b: String = m.obtener_tipo(celda)
				if tipo_b.begins_with("puerto_"):
					var estado := "desconectado"
					if Canalizaciones != null and Canalizaciones.has_method("estado_de_puerto"):
						estado = Canalizaciones.estado_de_puerto(celda)
					celdas_puerto_encontradas.append({
						"celda": celda,
						"tipo_bloque": tipo_b,
						"estado": estado,
					})

	var resultado: Array[Dictionary] = []
	for i in range(lista_info.size()):
		var info: Dictionary = lista_info[i]
		var estado := "desconectado"
		var celda_asoc := Vector3i.ZERO
		for c_data in celdas_puerto_encontradas:
			var tipo_b: String = c_data["tipo_bloque"]
			var rec_b: String = ""
			if tipo_b.begins_with("puerto_agua"): rec_b = "agua"
			elif tipo_b.begins_with("puerto_crudo"): rec_b = "crudo"
			elif tipo_b.begins_with("puerto_combustible"): rec_b = "combustible"
			var dir_b: String = "Entrada" if tipo_b.ends_with("_in") else "Salida"
			if rec_b == info.get("recurso", "") and dir_b == info.get("direccion", ""):
				estado = c_data["estado"]
				celda_asoc = c_data["celda"]
				break

		if estado == "desconectado" and Canalizaciones != null and Canalizaciones.has_method("estado_de_puerto"):
			for p_celda in Canalizaciones.puertos_conectados:
				if p_celda.x >= esquina.x and p_celda.x < esquina.x + ancho and p_celda.z >= esquina.y and p_celda.z < esquina.y + alto:
					var tipo_p: String = Canalizaciones.tipo_por_puerto.get(p_celda, "")
					var rec_b: String = ""
					if tipo_p.begins_with("puerto_agua"): rec_b = "agua"
					elif tipo_p.begins_with("puerto_crudo"): rec_b = "crudo"
					elif tipo_p.begins_with("puerto_combustible"): rec_b = "combustible"
					var dir_b: String = "Entrada" if tipo_p.ends_with("_in") else "Salida"
					if rec_b == info.get("recurso", "") and dir_b == info.get("direccion", ""):
						estado = Canalizaciones.estado_de_puerto(p_celda)
						celda_asoc = p_celda
						break

		resultado.append({
			"nombre": info.get("nombre", "Puerto"),
			"recurso": info.get("recurso", ""),
			"direccion": info.get("direccion", ""),
			"estado": estado,
			"celda": celda_asoc,
		})
	return resultado


func _abrir_dialogo_investigar(id_tech: int) -> void:
	if not Economia.tiene_puesto(esquina):
		return
	_id_tech_seleccionada = id_tech
	var info: Dictionary = Ciudad.COSTOS_INVESTIGACION[id_tech]
	var t: Dictionary = Economia.trabajadores_de(esquina)
	var cant_inv: int = t["recolectores"]
	var meta: float = float(info["horas_investigador"])
	var tiempo_str: String
	if cant_inv > 0:
		var h_est: int = int(ceil(meta / float(cant_inv)))
		tiempo_str = "%d horas (%d investigador%s)" % [h_est, cant_inv, "es" if cant_inv > 1 else ""]
	else:
		tiempo_str = "Sin investigadores asignados (se requiere al menos 1 para comenzar)"

	_dialogo_investigar.title = "Investigar: %s" % info["nombre"]
	_dialogo_investigar.dialog_text = ""
	for h in _contenido_dialogo_inv.get_children():
		h.queue_free()

	var fila_costo := HBoxContainer.new()
	fila_costo.add_theme_constant_override("separation", 6)
	var lbl_costo := TemaHUD.etiqueta("Costo:")
	fila_costo.add_child(lbl_costo)

	var ic_hierro := IconosHUD.crear_rect("hierro", 18)
	fila_costo.add_child(ic_hierro)
	var lbl_hierro := TemaHUD.etiqueta("%d hierro" % info["hierro"])
	fila_costo.add_child(lbl_hierro)

	var ic_madera := IconosHUD.crear_rect("madera", 18)
	fila_costo.add_child(ic_madera)
	var lbl_madera := TemaHUD.etiqueta("%d madera" % info["madera"])
	fila_costo.add_child(lbl_madera)
	_contenido_dialogo_inv.add_child(fila_costo)

	var fila_tiempo := HBoxContainer.new()
	fila_tiempo.add_theme_constant_override("separation", 6)
	var ic_tiempo := IconosHUD.crear_rect("reloj_arena", 18)
	fila_tiempo.add_child(ic_tiempo)
	var lbl_tiempo := TemaHUD.etiqueta("Tiempo estimado: %s" % tiempo_str)
	fila_tiempo.add_child(lbl_tiempo)
	_contenido_dialogo_inv.add_child(fila_tiempo)

	var btn_ok: Button = _dialogo_investigar.get_ok_button()
	if btn_ok != null:
		btn_ok.disabled = (cant_inv <= 0)
	_dialogo_investigar.popup_centered()


func _confirmar_investigacion() -> void:
	if _id_tech_seleccionada <= 0 or not Economia.tiene_puesto(esquina):
		return
	var info: Dictionary = Ciudad.COSTOS_INVESTIGACION[_id_tech_seleccionada]
	var costos := {"hierro": float(info["hierro"]), "madera": float(info["madera"])}
	if not Ciudad.puede_pagar(costos):
		aviso.emit("Recursos insuficientes: requiere %d hierro, %d madera" % [info["hierro"], info["madera"]])
		return
	if not Ciudad.consumir_costos(costos):
		aviso.emit("Error al cobrar recursos de investigación")
		return
	Economia.iniciar_investigacion(esquina, _id_tech_seleccionada)
	aviso.emit("Investigación iniciada: %s" % info["nombre"])
	_actualizar()


func _on_pausar_investigacion() -> void:
	if not Economia.tiene_puesto(esquina):
		return
	var p: Dictionary = Economia.puestos[esquina]
	var pausada: bool = p.get("investigacion_pausada", false)
	Economia.pausar_investigacion(esquina, not pausada)
	_actualizar()


func _confirmar_cancelar_investigacion() -> void:
	if not Economia.tiene_puesto(esquina):
		return
	var p: Dictionary = Economia.puestos[esquina]
	var id_act: int = p.get("investigacion_activa", 0)
	if id_act <= 0:
		return
	var nom: String = Ciudad.COSTOS_INVESTIGACION.get(id_act, {}).get("nombre", "")
	Economia.cancelar_investigacion(esquina)
	aviso.emit("Investigación cancelada: %s. Recursos reembolsados." % nom)


func _confirmar_reconversion() -> void:
	if _id_mejora_reconversion != "" and Economia != null and Economia.has_method("iniciar_reconversion_industrial"):
		var exito: bool = Economia.iniciar_reconversion_industrial(esquina, _id_mejora_reconversion)
		if exito:
			var nom_m: String = Ajustes.MEJORAS_PRACTICAS_CATALOGO.get(_id_mejora_reconversion, {}).get("nombre", _id_mejora_reconversion)
			aviso.emit(Strings.RECONVERSION_AVISO_COMPLETADA % nom_m)
		_actualizar()


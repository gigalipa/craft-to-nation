extends Node3D

const Ajustes = preload("res://scripts/ajustes.gd")
const Strings = preload("res://scripts/strings.gd")

@onready var mundo := $VoxelWorld
@onready var jugador: Player = $Player
@onready var camara_cenital: Camera3D = $CamaraCenital
@onready var zona_overlay: Node3D = $ZonaOverlay
@onready var mira_ui: CanvasLayer = $MiraUI
@onready var hud: CanvasLayer = $HUDLayer
@onready var menu_pausa: Control = get_node_or_null("MenuPausaLayer/MenuPausa")

var cenital_activa := false

## Duración de la animación de cambio de cámara (segundos).
static var DURACION_TRANSICION: float = Ajustes.MAIN_DURACION_TRANSICION_CAMARA

## Cámara "libre" que hace el vuelo de una vista a otra: durante la
## transición es la única cámara `current`, ninguna de las dos vistas
## procesa entrada (CamaraCenital._process()/_unhandled_input() vuelven de
## inmediato si `current` es falso; Player ignora WASD/salto/nado vía
## jugador.movimiento_habilitado, pero sigue cayendo por gravedad, y el
## ratón se libera, lo que también desactiva su mouse-look).
var _camara_transicion := Camera3D.new()
var _en_transicion := false

const TIPOS_PUESTOS_INDUSTRIALES: Array[String] = [
	"mina", "pozo_agua", "extractor_crudo", "aserradero", "carbonera",
	"fabrica_bloques", "siderurgica", "refineria_cobre", "refineria_tierras_raras",
	"refineria_petrolera", "productor_combustible", "planta_concreto",
	"fabrica_componentes", "central_termoelectrica",
	"vidriera", "estacion_bombeo", "centro_extraccion", "taller_transporte",
]
var _acumulador_eval_musica: float = 0.0
var _acumulador_eval_campana: float = 0.0
var _eval_campana_pendiente: bool = false
var _overlay_epilogo: CanvasLayer = null

var _sucesion_en_curso: bool = false
var _sucesion_fase: String = ""  # "", "caminando", "transformando", "revelando"
var _sucesion_colono_id: int = -1
var _sucesion_celdas_nucleo: Array[Vector3i] = []
var _sucesion_timer_s: float = 0.0
var _sucesion_luz: OmniLight3D = null
var _sucesion_pos_interior: Vector3 = Vector3.ZERO
var _overlay_game_over: CanvasLayer = null


func _ready() -> void:
	_camara_transicion.current = false
	add_child(_camara_transicion)
	jugador.mundo = mundo
	zona_overlay.mundo = mundo
	Zonificacion.limite_mundo = Vector2i(mundo.ANCHO_MUNDO, mundo.LARGO_MUNDO)
	Colonos.mundo = mundo
	Obras.mundo = mundo
	Obras.aviso.connect(hud.notificar)
	var marcas_demolicion := preload("res://scripts/MarcasDemolicionOverlay.gd").new()
	marcas_demolicion.obras = Obras
	add_child(marcas_demolicion)
	if has_node("ViaObraOverlay"):
		$ViaObraOverlay.obras = Obras

	Economia.mundo = mundo
	var atmosfera := get_node_or_null("AtmosferaCiclo")
	if atmosfera != null:
		atmosfera.luz_solar = get_node_or_null("Luz") as DirectionalLight3D
	var alumbrado := get_node_or_null("AlumbradoUrbano")
	if alumbrado != null:
		alumbrado.mundo = mundo
		alumbrado.atmosfera = atmosfera
		alumbrado.modo_cenital = cenital_activa
		if not mundo.edificios_cambiados.is_connected(alumbrado.marcar_sucio):
			mundo.edificios_cambiados.connect(alumbrado.marcar_sucio)
		if Vias != null and not Vias.vias_cambiadas.is_connected(alumbrado.marcar_sucio):
			Vias.vias_cambiadas.connect(alumbrado.marcar_sucio)
	mundo.obra_a_fantasma.connect(jugador._on_obra_a_fantasma)
	Colonos.colono_creado.connect(func(_id: int) -> void: hud.notificar(Strings.NOTIF_NUEVO_COLONO))
	Colonos.tecnicos_formados.connect(func(cantidad: int) -> void: hud.notificar(Strings.NOTIF_TECNICOS_FORMADOS % cantidad))
	Ciudad.recurso_escaso_notificado.connect(func(clave: String) -> void:
		var nom: String = Strings.NOMBRES_RECURSO.get(clave, clave.capitalize())
		hud.notificar(Strings.NOTIF_RECURSO_MENOS_5_PCT % nom)
	)
	var centro_x: int = mundo.ANCHO_MUNDO / 2
	var centro_z: int = mundo.LARGO_MUNDO / 2
	var altura_spawn: int = mundo.altura_en(centro_x, centro_z)
	jugador.position = Vector3(centro_x, altura_spawn + 1, centro_z)

	if menu_pausa != null:
		menu_pausa.reanudar_solicitado.connect(_alternar_menu_pausa)
		menu_pausa.salir_al_menu_solicitado.connect(_salir_al_menu_principal)

	if GestorPartida != null and not GestorPartida.partida_pendiente_a_cargar.is_empty():
		var archivo_a_cargar := GestorPartida.partida_pendiente_a_cargar
		GestorPartida.partida_pendiente_a_cargar = ""
		GestorPartida.cargar_partida(archivo_a_cargar)

	if Sonidos != null and Sonidos.has_method("reiniciar_director_musica"):
		Sonidos.reiniciar_director_musica()
		Sonidos.evaluar_contexto_musical(construir_estado_musical(), 0.0)
	else:
		Sonidos.reproducir_musica_juego()

	if Campana != null:
		if Campana.fase == Campana.Fase.PROLOGO and Ciudad != null:
			Campana.comenzar_actos_en_mundo(Ciudad.almacen)
		if not Campana.epilogo_solicitado.is_connected(_mostrar_epilogo_campana):
			Campana.epilogo_solicitado.connect(_mostrar_epilogo_campana)
		if hud != null and hud._panel_campana != null:
			hud._panel_campana.sincronizar()
		if mundo != null:
			if not mundo.edificios_cambiados.is_connected(_marcar_eval_campana_inmediata):
				mundo.edificios_cambiados.connect(_marcar_eval_campana_inmediata)
			if not mundo.terreno_modificado.is_connected(_marcar_eval_campana_inmediata):
				mundo.terreno_modificado.connect(_marcar_eval_campana_inmediata)
		if Zonificacion != null and not Zonificacion.zonas_cambiadas.is_connected(_marcar_eval_campana_inmediata):
			Zonificacion.zonas_cambiadas.connect(_marcar_eval_campana_inmediata)
		if Vias != null and not Vias.vias_cambiadas.is_connected(_marcar_eval_campana_inmediata):
			Vias.vias_cambiadas.connect(_marcar_eval_campana_inmediata)
		if Colonos != null and not Colonos.colono_creado.is_connected(_marcar_eval_campana_inmediata):
			Colonos.colono_creado.connect(_marcar_eval_campana_inmediata)
		if Colonos != null and not Colonos.tecnicos_formados.is_connected(_marcar_eval_campana_inmediata):
			Colonos.tecnicos_formados.connect(_marcar_eval_campana_inmediata)
		if Ciudad != null and not Ciudad.tick_simulado.is_connected(_marcar_eval_campana_inmediata):
			Ciudad.tick_simulado.connect(_marcar_eval_campana_inmediata)
		if hud != null and hud.has_signal("almacen_abierto_1p") and not hud.almacen_abierto_1p.is_connected(_marcar_eval_campana_inmediata):
			hud.almacen_abierto_1p.connect(_marcar_eval_campana_inmediata)
		if Campana.has_signal("accion_campana_registrada") and not Campana.accion_campana_registrada.is_connected(_marcar_eval_campana_inmediata):
			Campana.accion_campana_registrada.connect(_marcar_eval_campana_inmediata)

	if hud != null and hud.has_signal("menu_pausa_pedido") and not hud.menu_pausa_pedido.is_connected(_alternar_menu_pausa):
		hud.menu_pausa_pedido.connect(_alternar_menu_pausa)

	if jugador != null and jugador.has_signal("muerte_jugador_solicitada") and not jugador.muerte_jugador_solicitada.is_connected(_iniciar_secuencia_sucesion):
		jugador.muerte_jugador_solicitada.connect(_iniciar_secuencia_sucesion)


func _marcar_eval_campana_inmediata(_a: Variant = null, _b: Variant = null) -> void:
	_eval_campana_pendiente = true


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if _sucesion_en_curso:
		_procesar_sucesion(delta)
	_acumulador_eval_musica += delta
	if _acumulador_eval_musica >= Ajustes.MUSICA_INTERVALO_EVALUACION_S:
		var dt := _acumulador_eval_musica
		_acumulador_eval_musica = 0.0
		if Sonidos != null and Sonidos.has_method("evaluar_contexto_musical"):
			Sonidos.evaluar_contexto_musical(construir_estado_musical(), dt)

	if Campana != null and Campana.esta_activa():
		_acumulador_eval_campana += delta
		if _eval_campana_pendiente or _acumulador_eval_campana >= Ajustes.CAMPANA_INTERVALO_EVALUACION_S:
			var dt_c := _acumulador_eval_campana
			_acumulador_eval_campana = 0.0
			_eval_campana_pendiente = false
			Campana.evaluar_progreso(construir_contexto_campana(), dt_c)


func construir_contexto_campana() -> Dictionary:
	var tiene_zona_a := false
	var tiene_zona_b := false
	if Zonificacion != null:
		for c_xz in Zonificacion.zonas:
			var z_val := str(Zonificacion.zonas[c_xz])
			if z_val == "residencial_investigacion" and not Zonificacion.celda_es_del_nucleo(c_xz):
				tiene_zona_a = true
			elif z_val == "fabricacion_militar":
				tiene_zona_b = true
			if tiene_zona_a and tiene_zona_b:
				break
	if not tiene_zona_a and Ciudad != null and not Ciudad.edificios_residenciales.is_empty():
		tiene_zona_a = true

	var tiene_puerta_o_cama := false
	var tiene_puerta := false
	var tiene_ventana := false
	var tiene_cama := false
	var tiene_baul := false
	var bloques_estructurales_colocados := 0
	if mundo != null:
		for c_jug in mundo.colocado_por_jugador:
			var t_b: String = mundo.obtener_tipo(c_jug)
			if t_b == "puerta_inferior":
				tiene_puerta = true
				tiene_puerta_o_cama = true
			elif t_b == "vidrio":
				tiene_ventana = true
			elif t_b == "cama_cabecera":
				tiene_cama = true
				tiene_puerta_o_cama = true
			elif t_b == "baul":
				tiene_baul = true
			elif t_b in ["adobe", "bloque_madera", "bloque_piedra", "estructura_hierro", "bloque_acero"]:
				bloques_estructurales_colocados += 1

	var tiene_obra_residencial_extra := false
	var tiene_residencial_completado := Ciudad != null and not Ciudad.edificios_residenciales.is_empty()
	if mundo != null:
		for id_ed in mundo.edificio_a_celdas:
			if Ciudad != null and id_ed == Ciudad.id_nucleo:
				continue
			var meta_ed: Dictionary = mundo.edificio_metadata.get(id_ed, {})
			if not meta_ed.has("puesto") and not meta_ed.has("puesto_nuevo"):
				tiene_obra_residencial_extra = true
				break

	var tiene_obra_puesto_comida := false
	var tiene_obra_puesto_material := false
	if mundo != null:
		for id_ed in mundo.edificio_metadata:
			var meta_p: Dictionary = mundo.edificio_metadata[id_ed]
			if meta_p.has("puesto_nuevo"):
				var info_pn: Dictionary = meta_p["puesto_nuevo"]
				var tpn: String = str(info_pn.get("tipo", ""))
				if tpn == "caza_recoleccion" or tpn == "pesca_frutos_mar":
					tiene_obra_puesto_comida = true
				elif tpn == "maderero" or tpn == "mina":
					tiene_obra_puesto_material = true

	var tiene_puesto_comida := false
	var comida_tiene_recolector := false
	var comida_tiene_acarreador := false
	var puesto_comida_con_personal := false
	var tiene_puesto_material := false
	var material_tiene_recolector := false
	var material_tiene_acarreador := false
	var tiene_puesto_material_con_personal := false
	var tiene_escuela_tecnica := false
	var tiene_aserradero := false
	var aserradero_con_personal := false
	var aserradero_produciendo := false
	if Economia != null:
		for esq in Economia.puestos:
			var p: Dictionary = Economia.puestos[esq]
			var tp: String = str(p.get("tipo", ""))
			var rec_n: int = (p.get("recolectores", []) as Array).size()
			var aca_n: int = (p.get("acarreadores", []) as Array).size()
			var tec_n: int = (p.get("tecnicos", []) as Array).size()
			if tp == "caza_recoleccion" or tp == "pesca_frutos_mar":
				tiene_puesto_comida = true
				if rec_n >= 1:
					comida_tiene_recolector = true
				if aca_n >= 1:
					comida_tiene_acarreador = true
				if rec_n >= 1 and aca_n >= 1:
					puesto_comida_con_personal = true
			elif tp == "maderero" or tp == "mina":
				tiene_puesto_material = true
				if rec_n >= 1:
					material_tiene_recolector = true
				if aca_n >= 1:
					material_tiene_acarreador = true
				if rec_n >= 1 and aca_n >= 1:
					tiene_puesto_material_con_personal = true
			elif tp == "escuela_tecnica":
				tiene_escuela_tecnica = true
			elif tp == "aserradero":
				tiene_aserradero = true
				if (tec_n >= 1 or rec_n >= 1) and aca_n >= 1:
					aserradero_con_personal = true
				if bool(p.get("activo", false)) and (tec_n >= 1 or rec_n >= 1) and aca_n >= 1:
					aserradero_produciendo = true

	var stocks := {}
	if Ciudad != null and Ciudad.almacen != null:
		for rec in ["madera", "piedra", "tierra", "comida", "tablas"]:
			if Ciudad.almacen.has(rec):
				stocks[rec] = float(Ciudad.almacen[rec].cantidad)

	var st_ini: Dictionary = Campana.stock_inicial_partida if Campana != null else {}
	var gano_madera: bool = float(stocks.get("madera", 0.0)) > float(st_ini.get("madera", 0.0))
	var gano_piedra_o_tierra: bool = float(stocks.get("piedra", 0.0)) > float(st_ini.get("piedra", 0.0)) or float(stocks.get("tierra", 0.0)) > float(st_ini.get("tierra", 0.0))
	var gano_comida: bool = float(stocks.get("comida", 0.0)) > float(st_ini.get("comida", 0.0))

	if aserradero_produciendo and float(stocks.get("tablas", 0.0)) <= float(st_ini.get("tablas", 0.0)):
		aserradero_produciendo = false

	var escaner_ext := false
	if cenital_activa and camara_cenital != null and "_tipo_puesto_activo" in camara_cenital:
		var tp_prev := str(camara_cenital._tipo_puesto_activo)
		if tp_prev == "mina" or tp_prev == "centro_extraccion":
			escaner_ext = true

	return {
		"id_nucleo": Ciudad.id_nucleo if Ciudad != null else -1,
		"cenital_activa": cenital_activa,
		"tiene_zona_a": tiene_zona_a,
		"tiene_zona_b": tiene_zona_b,
		"total_colonos": Colonos.colonos.size() if Colonos != null else 0,
		"tiene_puerta_o_cama": tiene_puerta_o_cama,
		"tiene_puerta": tiene_puerta,
		"tiene_ventana": tiene_ventana,
		"tiene_cama": tiene_cama,
		"tiene_baul": tiene_baul,
		"apuntando_puerta_modo_t": jugador != null and jugador.has_method("apunta_a_puerta_en_construccion") and jugador.apunta_a_puerta_en_construccion(),
		"bloques_estructurales_colocados": bloques_estructurales_colocados,
		"tiene_obra_residencial_extra": tiene_obra_residencial_extra,
		"tiene_residencial_completado": tiene_residencial_completado,
		"tiene_obra_puesto_comida": tiene_obra_puesto_comida,
		"tiene_obra_puesto_material": tiene_obra_puesto_material,
		"tiene_puesto_comida": tiene_puesto_comida,
		"comida_tiene_recolector": comida_tiene_recolector,
		"comida_tiene_acarreador": comida_tiene_acarreador,
		"puesto_comida_con_personal": puesto_comida_con_personal,
		"tiene_puesto_material": tiene_puesto_material,
		"material_tiene_recolector": material_tiene_recolector,
		"material_tiene_acarreador": material_tiene_acarreador,
		"tiene_puesto_material_con_personal": tiene_puesto_material_con_personal,
		"total_celdas_via": Vias.celdas.size() if Vias != null else 0,
		"tiene_escuela_tecnica": tiene_escuela_tecnica,
		"total_tecnicos": int(Ciudad.demografia.get("tecnico", 0)) if Ciudad != null else 0,
		"tiene_aserradero": tiene_aserradero,
		"aserradero_con_personal": aserradero_con_personal,
		"aserradero_produciendo": aserradero_produciendo,
		"lampara_encendida": jugador != null and jugador.lampara_encendida,
		"escaner_extractor_activo": escaner_ext,
		"gano_madera": gano_madera,
		"gano_piedra_o_tierra": gano_piedra_o_tierra,
		"gano_comida": gano_comida,
		"consulto_almacen": Campana.consulto_almacen_1p if Campana != null else false,
		"stocks": stocks,
	}


func _mostrar_epilogo_campana() -> void:
	if _overlay_epilogo != null:
		return
	_overlay_epilogo = CanvasLayer.new()
	_overlay_epilogo.layer = 110
	_overlay_epilogo.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay_epilogo)

	var sec := preload("res://scripts/SecuenciaVideoCampana.gd").new()
	sec.es_epilogo = true
	sec.continuar_ciudad_solicitado.connect(func():
		if Campana != null:
			Campana.pasar_a_modo_libre()
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if cenital_activa else Input.MOUSE_MODE_CAPTURED
		if is_instance_valid(_overlay_epilogo):
			_overlay_epilogo.queue_free()
		_overlay_epilogo = null
	)
	sec.nueva_nacion_solicitada.connect(func():
		get_tree().paused = false
		if Campana != null:
			Campana.desactivar()
			Campana.abrir_nueva_partida_en_menu = true
		Sonidos.reproducir_musica_menu()
		GestorPartida.reiniciar_partida()
		get_tree().change_scene_to_file("res://scenes/MenuInicio.tscn")
	)
	_overlay_epilogo.add_child(sec)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func construir_estado_musical() -> Dictionary:
	var punto_foco: Vector3 = camara_cenital.foco if cenital_activa else jugador.global_position
	var pos_2d := Vector2(punto_foco.x, punto_foco.z)
	var celda_foco := Vector2i(int(floor(punto_foco.x)), int(floor(punto_foco.z)))
	var radio := Ajustes.MUSICA_RADIO_DETECCION_INDUSTRIA
	var radio_sq := radio * radio

	var en_industria := false
	if Zonificacion != null:
		if str(Zonificacion.zonas.get(celda_foco, "")) == "fabricacion_militar":
			en_industria = true
		else:
			for c_zona in Zonificacion.zonas:
				if Zonificacion.zonas[c_zona] == "fabricacion_militar":
					var dz := Vector2(c_zona.x, c_zona.y) - pos_2d
					if dz.length_squared() <= radio_sq:
						en_industria = true
						break

	if not en_industria and Economia != null:
		for esquina in Economia.puestos:
			var p: Dictionary = Economia.puestos[esquina]
			if TIPOS_PUESTOS_INDUSTRIALES.has(str(p.get("tipo", ""))):
				var centro := Vector2(esquina.x + float(p.get("ancho", 1)) * 0.5, esquina.y + float(p.get("alto", 1)) * 0.5)
				if pos_2d.distance_squared_to(centro) <= radio_sq:
					en_industria = true
					break

	var tiene_nucleo: bool = Ciudad != null and Ciudad.id_nucleo != -1
	var en_influencia: bool = tiene_nucleo and Zonificacion != null and Zonificacion.dentro_de_influencia(celda_foco)
	var modo_constr: bool = hud != null and hud.has_method("modo_construccion_cenital_activo") and bool(hud.modo_construccion_cenital_activo())
	var panel_ind: bool = hud != null and hud.has_method("panel_industrial_o_energia_abierto") and bool(hud.panel_industrial_o_energia_abierto(TIPOS_PUESTOS_INDUSTRIALES))
	var constr_reciente: bool = (not cenital_activa) and jugador != null and jugador.construccion_reciente_activa(10.0)

	return {
		"tiene_nucleo": tiene_nucleo,
		"en_influencia": en_influencia,
		"modo_construccion_activo": modo_constr,
		"construccion_reciente": constr_reciente,
		"en_industria": en_industria,
		"panel_industria_abierto": panel_ind,
		"en_combate": false,
	}


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var tecla := event as InputEventKey
		if tecla.pressed and tecla.keycode == KEY_F11 and not _en_transicion:
			_alternar_menu_pausa()
			get_viewport().set_input_as_handled()
			return
		if tecla.pressed and tecla.keycode == KEY_F12 and not _en_transicion and not (menu_pausa != null and menu_pausa.esta_abierto()):
			if GestorPartida != null:
				var ok_qs: bool = GestorPartida.guardado_rapido()
				if ok_qs:
					Sonidos.reproducir("sfx_ui_guardar")
					if hud != null and hud.has_method("notificar"):
						hud.notificar(Strings.t("MENU_QUICKSAVE_NOTIF", "¡Guardado rápido realizado (F12)!"))
				else:
					if hud != null and hud.has_method("notificar"):
						hud.notificar(Strings.t("MENU_QUICKSAVE_ERROR", "Error al realizar guardado rápido."))
			get_viewport().set_input_as_handled()
			return
		if tecla.pressed and tecla.keycode == KEY_C and not _en_transicion and not (menu_pausa != null and menu_pausa.esta_abierto()):
			_alternar_camara_cenital()


func _alternar_menu_pausa() -> void:
	if menu_pausa == null or _en_transicion:
		return
	if menu_pausa.esta_abierto():
		menu_pausa.ocultar()
		get_tree().paused = false
		if not cenital_activa:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if jugador != null:
			jugador._minando = false
			jugador._colocando = false
		menu_pausa.mostrar()
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Sonidos.reproducir("sfx_ui_modal_abrir")


func _salir_al_menu_principal() -> void:
	get_tree().paused = false
	Sonidos.reproducir_musica_menu()
	GestorPartida.reiniciar_partida()
	get_tree().change_scene_to_file("res://scenes/MenuInicio.tscn")


## Alterna entre la cámara en 1ª persona del jugador y la cenital, con una
## transición animada: una cámara libre (_camara_transicion) vuela de la
## posición de la vista saliente a la de la entrante mientras el HUD hace un
## crossfade (ver HUD.iniciar_transicion()). Congela el jugador y la cenital
## durante el vuelo (ver comentario de _camara_transicion) y, al llegar,
## aplica el resto de cambios de vista: overlay de zonas — solo debe verse
## desde arriba, nunca en 1ª persona —, mira (MiraUI/Mira, solo con sentido
## en 1ª persona) y salida de cualquier modo de interacción de la cenital
## (nivelación, colocar mina) al volver a 1ª persona — esos modos dibujan
## overlays como hijos directos de CamaraCenital, independientes de si esa
## cámara está activa, así que sin esto quedaban visibles y congelados
## encima de la vista en 1ª persona.
func _alternar_camara_cenital(forzado_sistema: bool = false) -> void:
	if not forzado_sistema:
		if _sucesion_en_curso:
			return
		if not cenital_activa and Campana != null and Campana.esta_activa() and (Ciudad == null or Ciudad.id_nucleo == -1):
			Sonidos.reproducir("sfx_ui_notificacion_alerta", -2.0)
			if hud != null and hud.has_method("notificar"):
				hud.notificar(Strings.t("CAMPANA_BLOQUEO_CENITAL_SIN_NUCLEO"))
			return
		if not cenital_activa and jugador != null and jugador.has_method("motivo_bloqueo_cenital"):
			var motivo_bloqueo: String = jugador.motivo_bloqueo_cenital()
			if motivo_bloqueo != "":
				Sonidos.reproducir("sfx_ui_notificacion_alerta", -2.0)
				if hud != null and hud.has_method("notificar"):
					hud.notificar(motivo_bloqueo)
				return
	cenital_activa = not cenital_activa
	var alumbrado := get_node_or_null("AlumbradoUrbano")
	if alumbrado != null:
		alumbrado.modo_cenital = cenital_activa
	var origen: Transform3D
	var destino: Transform3D
	var fov_origen: float
	var fov_destino: float
	if cenital_activa:
		jugador.salir_de_todas_las_herramientas()
		if jugador.has_method("iniciar_animacion_cenital"):
			jugador.iniciar_animacion_cenital()
		Sonidos.reproducir("sfx_ui_camara_a_cenital")
		origen = jugador.camara.global_transform
		fov_origen = jugador.camara.fov
		# "atrás" del avatar (opuesto a su frente, -basis.z, ver
		# Player._direccion_cardinal()): la cenital orbita detrás de hacia
		# dónde mira, como un seguimiento en 3ª persona.
		var atras := jugador.global_transform.basis.z
		var angulo_avatar := atan2(atras.x, atras.z)
		camara_cenital.posicionar_sobre(Vector2(jugador.position.x, jugador.position.z), angulo_avatar)
		destino = camara_cenital.global_transform
		fov_destino = camara_cenital.fov
	else:
		if jugador.has_method("salir_animacion_cenital"):
			jugador.salir_animacion_cenital(DURACION_TRANSICION)
		Sonidos.reproducir("sfx_ui_camara_a_avatar")
		origen = camara_cenital.global_transform
		fov_origen = camara_cenital.fov
		camara_cenital.salir_de_todos_los_modos()
		destino = jugador.camara.global_transform
		fov_destino = jugador.camara.fov

	_en_transicion = true
	# Solo se ignora el movimiento (WASD/salto/nado, ver Player.gd): la
	# gravedad sigue corriendo, si no un avatar en caída libre quedaba
	# "flotando" en el aire durante el vuelo (reportado jugando en vivo,
	# 2026-09-29).
	jugador.movimiento_habilitado = false
	camara_cenital.current = false
	jugador.camara.current = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_camara_transicion.global_transform = origen
	# La cenital usa un fov distinto al de 1ª persona (60° vs 75° por
	# defecto): sin interpolarlo también, al intercambiar de cámara al
	# principio/final del vuelo se veía un salto de encuadre (reportado por
	# el usuario, 2026-09-27).
	_camara_transicion.fov = fov_origen
	_camara_transicion.current = true
	hud.iniciar_transicion(cenital_activa, DURACION_TRANSICION)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_camara_transicion, "global_transform", destino, DURACION_TRANSICION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camara_transicion, "fov", fov_destino, DURACION_TRANSICION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_callback(_terminar_transicion)


func _terminar_transicion() -> void:
	_en_transicion = false
	_camara_transicion.current = false
	camara_cenital.current = cenital_activa
	jugador.camara.current = not cenital_activa
	jugador.movimiento_habilitado = not cenital_activa
	zona_overlay.visible = cenital_activa
	if cenital_activa:
		zona_overlay.reconstruir()
	mira_ui.visible = not cenital_activa
	if not cenital_activa and jugador.has_method("finalizar_salida_cenital"):
		jugador.finalizar_salida_cenital()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if cenital_activa else Input.MOUSE_MODE_CAPTURED


# ==============================================================================
# SUCESIÓN VISUAL EN EL NÚCLEO URBANO Y GAME OVER
# ==============================================================================

func _obtener_celdas_interiores_nucleo() -> Array[Vector3i]:
	var resultado: Array[Vector3i] = []
	if mundo == null or Ciudad == null or Ciudad.id_nucleo == -1:
		return resultado
	var id_n: int = Ciudad.id_nucleo
	if not mundo.edificio_a_celdas.has(id_n):
		return resultado
	var vol: Dictionary = mundo.edificio_volumen.get(id_n, {})
	var celdas_ed: Array = mundo.edificio_a_celdas[id_n]
	var y_suelo_interior: int = (vol.get("min", Vector3i.ZERO) as Vector3i).y + 1
	var buscador := preload("res://scripts/BuscadorRutas.gd").new(mundo)

	for c: Vector3i in celdas_ed:
		if mundo.obtener_tipo(c) == "puerta_inferior":
			y_suelo_interior = c.y
			break

	if not vol.is_empty():
		var mn: Vector3i = vol["min"]
		var mx: Vector3i = vol["max"]
		for x in range(mn.x + 1, mx.x):
			for z in range(mn.z + 1, mx.z):
				var celda := Vector3i(x, y_suelo_interior, z)
				if not mundo.celda_a_edificio.has(celda) and buscador.es_transitable(celda):
					resultado.append(celda)

	if resultado.is_empty():
		for c: Vector3i in celdas_ed:
			if mundo.obtener_tipo(c) != "puerta_inferior":
				continue
			for d: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
				var v: Vector3i = c + d
				if not mundo.celda_a_edificio.has(v) and buscador.es_transitable(v):
					resultado.append(v)
	return resultado


func _iniciar_secuencia_sucesion(_motivo: String = "") -> void:
	if _sucesion_en_curso:
		return
	_sucesion_en_curso = true
	if not cenital_activa:
		_alternar_camara_cenital(true)

	var tiene_nucleo: bool = Ciudad != null and Ciudad.id_nucleo != -1 and mundo != null and mundo.edificio_a_celdas.has(Ciudad.id_nucleo)
	var id_suc: int = -1
	if tiene_nucleo and Colonos != null and Colonos.has_method("elegir_colono_sucesion_ciudad"):
		id_suc = Colonos.elegir_colono_sucesion_ciudad(Ciudad.genero_avatar)

	if not tiene_nucleo or id_suc == -1:
		_sucesion_fase = "game_over_espera"
		_sucesion_timer_s = 0.85
		return

	_sucesion_colono_id = id_suc
	_sucesion_celdas_nucleo = _obtener_celdas_interiores_nucleo()
	if _sucesion_celdas_nucleo.is_empty():
		_sucesion_fase = "game_over_espera"
		_sucesion_timer_s = 0.85
		return

	if hud != null and hud.has_method("notificar"):
		hud.notificar(Strings.t("SUCESION_INICIADA_NOTIF"))
	Colonos.iniciar_marcha_sucesion(id_suc, _sucesion_celdas_nucleo)
	_sucesion_fase = "caminando"
	_sucesion_timer_s = 0.0


func _procesar_sucesion(delta: float) -> void:
	match _sucesion_fase:
		"game_over_espera":
			_sucesion_timer_s -= delta
			if _sucesion_timer_s <= 0.0:
				_sucesion_fase = ""
				var sin_nuc: bool = Ciudad == null or Ciudad.id_nucleo == -1
				_mostrar_overlay_game_over(sin_nuc)
		"caminando":
			_sucesion_timer_s += delta
			if not Colonos.colonos.has(_sucesion_colono_id):
				var nuevo_id: int = Colonos.elegir_colono_sucesion_ciudad(Ciudad.genero_avatar)
				if nuevo_id == -1:
					_sucesion_fase = ""
					_mostrar_overlay_game_over(false)
					return
				_sucesion_colono_id = nuevo_id
				Colonos.iniciar_marcha_sucesion(nuevo_id, _sucesion_celdas_nucleo)
				_sucesion_timer_s = 0.0
				return

			var c: Dictionary = Colonos.colonos[_sucesion_colono_id]
			if camara_cenital != null and not _en_transicion:
				var p_col: Vector3 = c.get("posicion", Vector3.ZERO)
				camara_cenital.foco = camara_cenital.foco.lerp(Vector3(p_col.x, camara_cenital.foco.y, p_col.z), minf(1.0, delta * 3.5))

			var celda_col: Vector3i = c.get("celda", Vector3i.ZERO)
			var llego := _sucesion_celdas_nucleo.has(celda_col) and not bool(c.get("moviendo", false))
			if llego or _sucesion_timer_s >= Ajustes.SUCESION_TIMEOUT_CAMINATA_NUCLEO_S:
				if not _sucesion_celdas_nucleo.has(celda_col):
					var dest := _sucesion_celdas_nucleo[0]
					c["celda"] = dest
					c["posicion"] = Vector3(dest.x + 0.5, dest.y, dest.z + 0.5)
					c["ruta"] = []
					c["moviendo"] = false
				_iniciar_transformacion_nucleo()
		"transformando":
			_sucesion_timer_s += delta
			var dur_t: float = Ajustes.SUCESION_DURACION_TRANSFORMACION_S
			if _sucesion_luz != null:
				var pulso := 0.5 + 0.5 * sin(_sucesion_timer_s * 24.0)
				_sucesion_luz.light_energy = lerpf(Ajustes.SUCESION_LUZ_ENERGIA_MIN, Ajustes.SUCESION_LUZ_ENERGIA_MAX, pulso)
			if _sucesion_timer_s >= dur_t * 0.6:
				_aplicar_relevo_avatar_en_nucleo()
		"revelando":
			_sucesion_timer_s += delta
			if _sucesion_luz != null:
				var frac := clampf(1.0 - (_sucesion_timer_s / 0.8), 0.0, 1.0)
				_sucesion_luz.light_energy = Ajustes.SUCESION_LUZ_ENERGIA_MAX * frac * (0.65 + 0.35 * sin(_sucesion_timer_s * 22.0))
			if _sucesion_timer_s >= 0.8:
				_finalizar_secuencia_sucesion()


func _iniciar_transformacion_nucleo() -> void:
	_sucesion_fase = "transformando"
	_sucesion_timer_s = 0.0
	var c: Dictionary = Colonos.colonos.get(_sucesion_colono_id, {})
	_sucesion_pos_interior = c.get("posicion", Vector3.ZERO)
	if camara_cenital != null:
		camara_cenital.foco = Vector3(_sucesion_pos_interior.x, camara_cenital.foco.y, _sucesion_pos_interior.z)

	var renderer := get_node_or_null("ColonosRenderer")
	if renderer != null and renderer.has_method("establecer_resplandor_sucesion"):
		renderer.establecer_resplandor_sucesion(_sucesion_colono_id, true, 3.0)

	_sucesion_luz = OmniLight3D.new()
	_sucesion_luz.name = "LuzSucesionNucleo"
	_sucesion_luz.position = _sucesion_pos_interior + Vector3(0.0, 1.25, 0.0)
	_sucesion_luz.light_color = Ajustes.COLOR_SUCESION_RESPLANDOR
	_sucesion_luz.omni_range = Ajustes.SUCESION_LUZ_RANGO
	_sucesion_luz.light_energy = Ajustes.SUCESION_LUZ_ENERGIA_MAX
	_sucesion_luz.shadow_enabled = true
	add_child(_sucesion_luz)


func _aplicar_relevo_avatar_en_nucleo() -> void:
	_sucesion_fase = "revelando"
	_sucesion_timer_s = 0.0
	Ciudad.completar_sucesion_desde_colono(_sucesion_colono_id, Colonos)
	_sucesion_colono_id = -1

	if jugador != null:
		jugador.global_position = _sucesion_pos_interior
		jugador.velocity = Vector3.ZERO
		jugador.oxigeno_actual = Player.OXIGENO_MAXIMO
		if jugador._animador != null:
			jugador._animador.reiniciar()
			jugador._animador.establecer_vista_primera_persona(false)
			jugador._animador.establecer_resplandor_sucesion(true, 3.0, Ciudad.tono_piel_avatar, Ciudad.color_equipo)


func _finalizar_secuencia_sucesion() -> void:
	if _sucesion_luz != null and is_instance_valid(_sucesion_luz):
		_sucesion_luz.queue_free()
	_sucesion_luz = null
	if jugador != null:
		if jugador._animador != null:
			jugador._animador.establecer_resplandor_sucesion(false, 1.0, Ciudad.tono_piel_avatar, Ciudad.color_equipo)
		if jugador.has_method("_sincronizar_equipamiento_avatar"):
			jugador._sincronizar_equipamiento_avatar()
		jugador.sucesion_en_curso = false
	_sucesion_fase = ""
	_sucesion_en_curso = false
	if hud != null and hud.has_method("notificar"):
		hud.notificar(Strings.t("SUCESION_COMPLETADA_NOTIF"))
	if cenital_activa:
		_alternar_camara_cenital(true)


func _mostrar_overlay_game_over(sin_nucleo: bool) -> void:
	if _overlay_game_over != null:
		return
	var TemaHUD = preload("res://scripts/TemaHUD.gd")
	_overlay_game_over = CanvasLayer.new()
	_overlay_game_over.layer = 120
	_overlay_game_over.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay_game_over)

	var fondo := ColorRect.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.02, 0.02, 0.03, 0.88)
	_overlay_game_over.add_child(fondo)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 230)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_theme_stylebox_override("panel", TemaHUD.caja())
	_overlay_game_over.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var lbl_tit := Label.new()
	lbl_tit.text = Strings.t("GAME_OVER_TITULO", "FIN DE LA PARTIDA")
	lbl_tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_tit.add_theme_color_override("font_color", TemaHUD.INVALIDO)
	lbl_tit.add_theme_font_size_override("font_size", 24)
	vbox.add_child(lbl_tit)

	var lbl_desc := Label.new()
	lbl_desc.text = Strings.t("GAME_OVER_DESC_SIN_NUCLEO" if sin_nucleo else "GAME_OVER_DESC_SIN_COLONO")
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_desc.add_theme_color_override("font_color", TemaHUD.TEXTO)
	vbox.add_child(lbl_desc)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)

	var btn_cargar := Button.new()
	btn_cargar.text = Strings.t("GAME_OVER_BTN_CARGAR", "Cargar Partida")
	btn_cargar.custom_minimum_size = Vector2(180, 40)
	TemaHUD.estilizar_boton(btn_cargar)
	btn_cargar.pressed.connect(func() -> void:
		if menu_pausa != null:
			_overlay_game_over.queue_free()
			_overlay_game_over = null
			menu_pausa.mostrar()
			if menu_pausa.has_method("_mostrar_subpanel_cargar"):
				menu_pausa._mostrar_subpanel_cargar()
	)
	hbox.add_child(btn_cargar)

	var btn_menu := Button.new()
	btn_menu.text = Strings.t("GAME_OVER_BTN_MENU", "Volver al Menú Principal")
	btn_menu.custom_minimum_size = Vector2(210, 40)
	TemaHUD.estilizar_boton(btn_menu)
	btn_menu.pressed.connect(func() -> void:
		_salir_al_menu_principal()
	)
	hbox.add_child(btn_menu)

	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

extends Node

## Singleton Autoload "Campana": director de estado de la Campaña-Tutorial
## («La Fractura Multiversal»). Evalúa hitos de los Actos I–IV sin bloquear al jugador.

const Ajustes = preload("res://scripts/ajustes.gd")
const CampanaCatalogo = preload("res://scripts/CampanaCatalogo.gd")

enum Fase { INACTIVA, PROLOGO, EN_CURSO, ESPERANDO_EPILOGO, EPILOGO, MODO_LIBRE }

signal paso_cambiado(paso: Dictionary)
signal hitos_cambiados(paso: Dictionary, cumplidos: Array)
signal estado_campana_cambiado(activa: bool)
signal accion_campana_registrada
signal epilogo_solicitado

var fase: int = Fase.INACTIVA
var indice_paso: int = 0
var tiempo_en_paso_s: float = 0.0
var tiempo_espera_epilogo_s: float = 0.0
var duracion_voz_actual_s: float = 0.0
var stock_inicial_partida: Dictionary = {}
var recolecto_recurso_manual: bool = false
var recolecto_madera: bool = false
var recolecto_piedra_o_tierra: bool = false
var recolecto_comida: bool = false
var exploro_con_lampara_o_escaner: bool = false
var consulto_almacen_1p: bool = false
var entro_en_cenital: bool = false
var ultimos_hitos_cumplidos: Array = []
var abrir_nueva_partida_en_menu: bool = false


func esta_activa() -> bool:
	return fase == Fase.EN_CURSO or fase == Fase.ESPERANDO_EPILOGO


func obtener_paso_actual() -> Dictionary:
	return CampanaCatalogo.obtener_paso(indice_paso)


func _reiniciar_banderas_progreso() -> void:
	recolecto_recurso_manual = false
	recolecto_madera = false
	recolecto_piedra_o_tierra = false
	recolecto_comida = false
	exploro_con_lampara_o_escaner = false
	consulto_almacen_1p = false
	entro_en_cenital = false
	ultimos_hitos_cumplidos = []


func iniciar_nueva_campana() -> void:
	fase = Fase.PROLOGO
	indice_paso = 0
	tiempo_en_paso_s = 0.0
	tiempo_espera_epilogo_s = 0.0
	duracion_voz_actual_s = 0.0
	stock_inicial_partida.clear()
	_reiniciar_banderas_progreso()
	Ajustes.SEMILLA = Ajustes.SEMILLA_CAMPANA
	Ajustes.SEMILLA_MUNDO = Ajustes.SEMILLA_CAMPANA


func comenzar_actos_en_mundo(almacen_actual: Dictionary) -> void:
	stock_inicial_partida.clear()
	for k in almacen_actual:
		var rec = almacen_actual[k]
		if typeof(rec) == TYPE_OBJECT and rec != null and "cantidad" in rec:
			stock_inicial_partida[str(k)] = float(rec.cantidad)
		elif rec is float or rec is int:
			stock_inicial_partida[str(k)] = float(rec)
	fase = Fase.EN_CURSO
	indice_paso = 0
	tiempo_en_paso_s = 0.0
	duracion_voz_actual_s = 0.0
	_reiniciar_banderas_progreso()
	estado_campana_cambiado.emit(true)
	_activar_paso_actual()


func pasar_a_modo_libre() -> void:
	fase = Fase.MODO_LIBRE
	if Sonidos != null and Sonidos.has_method("detener_voz"):
		Sonidos.detener_voz()
	estado_campana_cambiado.emit(false)


func desactivar() -> void:
	fase = Fase.INACTIVA
	indice_paso = 0
	tiempo_en_paso_s = 0.0
	tiempo_espera_epilogo_s = 0.0
	duracion_voz_actual_s = 0.0
	stock_inicial_partida.clear()
	_reiniciar_banderas_progreso()
	if Sonidos != null and Sonidos.has_method("detener_voz"):
		Sonidos.detener_voz()
	estado_campana_cambiado.emit(false)


func registrar_recoleccion_manual() -> void:
	recolecto_recurso_manual = true
	accion_campana_registrada.emit()


func registrar_recursos_recolectados(rendido: Dictionary) -> void:
	if rendido.is_empty():
		return
	var cambio := false
	if float(rendido.get("madera", 0.0)) > 0.0:
		recolecto_madera = true
		recolecto_recurso_manual = true
		cambio = true
	if float(rendido.get("piedra", 0.0)) > 0.0 or float(rendido.get("tierra", 0.0)) > 0.0:
		recolecto_piedra_o_tierra = true
		recolecto_recurso_manual = true
		cambio = true
	if float(rendido.get("comida", 0.0)) > 0.0:
		recolecto_comida = true
		recolecto_recurso_manual = true
		cambio = true
	if cambio:
		accion_campana_registrada.emit()


func registrar_exploracion_subsuelo() -> void:
	exploro_con_lampara_o_escaner = true
	accion_campana_registrada.emit()


func registrar_consulta_almacen() -> void:
	consulto_almacen_1p = true
	accion_campana_registrada.emit()


func repetir_voz_actual() -> void:
	var paso := obtener_paso_actual()
	if paso.is_empty():
		return
	duracion_voz_actual_s = 0.0
	if Sonidos != null and Sonidos.has_method("reproducir_voz"):
		var pv: AudioStreamPlayer = Sonidos.reproducir_voz(str(paso["id"]))
		if pv != null and pv.stream != null:
			duracion_voz_actual_s = maxf(0.0, pv.stream.get_length())
	paso_cambiado.emit(paso)


func _activar_paso_actual() -> void:
	var paso := obtener_paso_actual()
	if paso.is_empty():
		return
	tiempo_en_paso_s = 0.0
	duracion_voz_actual_s = 0.0
	ultimos_hitos_cumplidos = []
	var hitos_def: Array = paso.get("hitos", [])
	for _i in range(hitos_def.size()):
		ultimos_hitos_cumplidos.append(false)
	if Sonidos != null and Sonidos.has_method("reproducir_voz"):
		var pv: AudioStreamPlayer = Sonidos.reproducir_voz(str(paso["id"]))
		if pv != null and pv.stream != null:
			duracion_voz_actual_s = maxf(0.0, pv.stream.get_length())
	if str(paso["id"]) == "A4_01":
		exploro_con_lampara_o_escaner = false
	if str(paso["id"]) == "A4_05":
		fase = Fase.ESPERANDO_EPILOGO
		tiempo_espera_epilogo_s = duracion_voz_actual_s + Ajustes.CAMPANA_RETRASO_EPILOGO_S
	paso_cambiado.emit(paso)


func evaluar_hitos_de_paso(id_paso: String, ctx: Dictionary) -> Array:
	var id_nucleo: int = int(ctx.get("id_nucleo", -1))
	var cenital_activa: bool = bool(ctx.get("cenital_activa", false))
	var tiene_zona_a: bool = bool(ctx.get("tiene_zona_a", false))
	var tiene_zona_b: bool = bool(ctx.get("tiene_zona_b", false))
	var total_colonos: int = int(ctx.get("total_colonos", 0))
	var tiene_puesto_comida: bool = bool(ctx.get("tiene_puesto_comida", false))
	var puesto_comida_con_personal: bool = bool(ctx.get("puesto_comida_con_personal", false))
	var total_celdas_via: int = int(ctx.get("total_celdas_via", 0))
	var total_tecnicos: int = int(ctx.get("total_tecnicos", 0))
	var aserradero_produciendo: bool = bool(ctx.get("aserradero_produciendo", false))
	var stocks: Dictionary = ctx.get("stocks", {})

	match id_paso:
		"A1_01":
			var g_madera: bool = recolecto_madera or bool(ctx.get("gano_madera", float(stocks.get("madera", 0.0)) > float(stock_inicial_partida.get("madera", 0.0))))
			var g_piedra: bool = recolecto_piedra_o_tierra or bool(ctx.get("gano_piedra_o_tierra", float(stocks.get("piedra", 0.0)) > float(stock_inicial_partida.get("piedra", 0.0)) or float(stocks.get("tierra", 0.0)) > float(stock_inicial_partida.get("tierra", 0.0))))
			var g_comida: bool = recolecto_comida or bool(ctx.get("gano_comida", float(stocks.get("comida", 0.0)) > float(stock_inicial_partida.get("comida", 0.0))))
			var alm_ok: bool = consulto_almacen_1p or bool(ctx.get("consulto_almacen", false))
			return [g_madera or id_nucleo != -1, g_piedra or id_nucleo != -1, g_comida or id_nucleo != -1, alm_ok or id_nucleo != -1]
		"A1_02":
			var bloques_ok: bool = int(ctx.get("bloques_estructurales_colocados", 0)) >= 12 or id_nucleo != -1
			var puerta_ok: bool = bool(ctx.get("tiene_puerta", false)) or id_nucleo != -1
			var ventana_ok: bool = bool(ctx.get("tiene_ventana", false)) or id_nucleo != -1
			var cama_ok: bool = bool(ctx.get("tiene_cama", false)) or id_nucleo != -1
			var baul_ok: bool = bool(ctx.get("tiene_baul", false)) or id_nucleo != -1
			return [bloques_ok, puerta_ok, ventana_ok, cama_ok, baul_ok]
		"A1_03":
			var apuntando_puerta: bool = bool(ctx.get("apuntando_puerta_modo_t", false)) or id_nucleo != -1
			return [apuntando_puerta, id_nucleo != -1]
		"A2_01":
			return [entro_en_cenital or cenital_activa]
		"A2_02":
			return [tiene_zona_a]
		"A2_03":
			var res_comp: bool = bool(ctx.get("tiene_residencial_completado", false))
			var casa_emplazada: bool = bool(ctx.get("tiene_obra_residencial_extra", false)) or res_comp
			return [casa_emplazada, res_comp and total_colonos >= 1]
		"A3_01":
			var obra_comida: bool = bool(ctx.get("tiene_obra_puesto_comida", false)) or tiene_puesto_comida
			return [obra_comida, tiene_puesto_comida]
		"A3_02":
			var rec_ok: bool = bool(ctx.get("comida_tiene_recolector", puesto_comida_con_personal))
			var aca_ok: bool = bool(ctx.get("comida_tiene_acarreador", puesto_comida_con_personal))
			return [rec_ok, aca_ok]
		"A3_03":
			var mat_comp: bool = bool(ctx.get("tiene_puesto_material", false))
			var mat_obra: bool = bool(ctx.get("tiene_obra_puesto_material", false)) or mat_comp
			var mat_rec: bool = bool(ctx.get("material_tiene_recolector", false))
			var mat_aca: bool = bool(ctx.get("material_tiene_acarreador", false))
			return [mat_obra, mat_rec, mat_aca]
		"A3_04":
			return [total_celdas_via >= 3]
		"A4_01":
			return [exploro_con_lampara_o_escaner]
		"A4_02":
			return [tiene_zona_b]
		"A4_03":
			var esc_ok: bool = bool(ctx.get("tiene_escuela_tecnica", total_tecnicos >= 1))
			return [esc_ok, total_tecnicos >= 1]
		"A4_04":
			var ase_ok: bool = bool(ctx.get("tiene_aserradero", aserradero_produciendo))
			var per_ase: bool = bool(ctx.get("aserradero_con_personal", aserradero_produciendo))
			return [ase_ok, per_ase, aserradero_produciendo]
		_:
			return []


func evaluar_progreso(ctx: Dictionary, delta: float, ignorar_tiempo_minimo: bool = false) -> void:
	if fase == Fase.ESPERANDO_EPILOGO:
		tiempo_espera_epilogo_s -= maxf(0.0, delta)
		var umbral_epilogo: float = duracion_voz_actual_s if ignorar_tiempo_minimo else 0.0
		if tiempo_espera_epilogo_s <= umbral_epilogo:
			fase = Fase.EPILOGO
			estado_campana_cambiado.emit(false)
			epilogo_solicitado.emit()
		return

	if fase != Fase.EN_CURSO:
		return

	if bool(ctx.get("cenital_activa", false)):
		entro_en_cenital = true
	if bool(ctx.get("lampara_encendida", false)) or bool(ctx.get("escaner_extractor_activo", false)):
		exploro_con_lampara_o_escaner = true
	if bool(ctx.get("consulto_almacen", false)):
		consulto_almacen_1p = true

	tiempo_en_paso_s += maxf(0.0, delta)
	var paso := obtener_paso_actual()
	if paso.is_empty():
		return
	var id_paso_actual: String = str(paso["id"])

	var nuevos_hitos: Array = evaluar_hitos_de_paso(id_paso_actual, ctx)
	for idx_l in range(mini(nuevos_hitos.size(), ultimos_hitos_cumplidos.size())):
		if bool(ultimos_hitos_cumplidos[idx_l]):
			nuevos_hitos[idx_l] = true
	if nuevos_hitos != ultimos_hitos_cumplidos:
		var gano_alguno := false
		for idx in range(mini(nuevos_hitos.size(), ultimos_hitos_cumplidos.size())):
			if bool(nuevos_hitos[idx]) and not bool(ultimos_hitos_cumplidos[idx]):
				gano_alguno = true
				break
		ultimos_hitos_cumplidos = nuevos_hitos.duplicate()
		hitos_cambiados.emit(paso, ultimos_hitos_cumplidos)
		if gano_alguno and Sonidos != null and Sonidos.has_method("reproducir"):
			Sonidos.reproducir("sfx_ui_notificacion_info", -6.0)

	var tiempo_min_s: float = Ajustes.CAMPANA_TIEMPO_MINIMO_PASO_S
	if (id_paso_actual == "A1_04" or id_paso_actual == "A2_04" or id_paso_actual == "A3_05") and duracion_voz_actual_s > 0.0:
		tiempo_min_s = maxf(tiempo_min_s, duracion_voz_actual_s + 0.8)
	if not ignorar_tiempo_minimo and tiempo_en_paso_s < tiempo_min_s:
		return
	var avanza: bool = (id_paso_actual == "A1_04" or id_paso_actual == "A2_04" or id_paso_actual == "A3_05") or (not ultimos_hitos_cumplidos.is_empty() and not ultimos_hitos_cumplidos.has(false))
	if avanza:
		if indice_paso + 1 < CampanaCatalogo.total_pasos():
			indice_paso += 1
			_activar_paso_actual()


func _cumple_condicion_avance_de(id_paso: String, ctx: Dictionary) -> bool:
	if id_paso == "A1_04" or id_paso == "A2_04" or id_paso == "A3_05":
		return true
	var hitos: Array = evaluar_hitos_de_paso(id_paso, ctx)
	return not hitos.is_empty() and not hitos.has(false)


func exportar_estado() -> Dictionary:
	return {
		"fase": fase,
		"indice_paso": indice_paso,
		"tiempo_en_paso_s": tiempo_en_paso_s,
		"tiempo_espera_epilogo_s": tiempo_espera_epilogo_s,
		"stock_inicial_partida": stock_inicial_partida.duplicate(true),
		"recolecto_recurso_manual": recolecto_recurso_manual,
		"recolecto_madera": recolecto_madera,
		"recolecto_piedra_o_tierra": recolecto_piedra_o_tierra,
		"recolecto_comida": recolecto_comida,
		"consulto_almacen_1p": consulto_almacen_1p,
		"entro_en_cenital": entro_en_cenital,
		"exploro_con_lampara_o_escaner": exploro_con_lampara_o_escaner,
		"ultimos_hitos_cumplidos": ultimos_hitos_cumplidos.duplicate(),
	}


func importar_estado(d: Dictionary) -> void:
	if d.is_empty():
		desactivar()
		return
	fase = int(d.get("fase", Fase.INACTIVA))
	indice_paso = clampi(int(d.get("indice_paso", 0)), 0, CampanaCatalogo.total_pasos() - 1)
	tiempo_en_paso_s = float(d.get("tiempo_en_paso_s", 0.0))
	tiempo_espera_epilogo_s = float(d.get("tiempo_espera_epilogo_s", 0.0))
	var st: Variant = d.get("stock_inicial_partida", {})
	stock_inicial_partida = (st as Dictionary).duplicate(true) if st is Dictionary else {}
	recolecto_recurso_manual = bool(d.get("recolecto_recurso_manual", false))
	recolecto_madera = bool(d.get("recolecto_madera", false))
	recolecto_piedra_o_tierra = bool(d.get("recolecto_piedra_o_tierra", false))
	recolecto_comida = bool(d.get("recolecto_comida", false))
	consulto_almacen_1p = bool(d.get("consulto_almacen_1p", false))
	entro_en_cenital = bool(d.get("entro_en_cenital", false))
	exploro_con_lampara_o_escaner = bool(d.get("exploro_con_lampara_o_escaner", false))
	var hc: Variant = d.get("ultimos_hitos_cumplidos", [])
	ultimos_hitos_cumplidos = (hc as Array).duplicate() if hc is Array else []
	estado_campana_cambiado.emit(esta_activa())
	if esta_activa():
		paso_cambiado.emit(obtener_paso_actual())

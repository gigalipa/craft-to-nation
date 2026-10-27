extends Node

## Autoload "Economia": producción y acarreo de los puestos de recolección
## (sub-proyecto 2A, ver docs/superpowers/specs/2026-09-21-economia-puestos-
## produccion-acarreo-design.md). Estado y reglas puros, sin escena (mismo
## patrón que Ciudad.gd/Recoleccion.gd): guarda por puesto sus trabajadores,
## su almacén local y sus tasas, y produce una hora de juego por cada
## Ciudad.tick_simulado. El movimiento físico de los colonos (ir al puesto,
## recoger, llevar al núcleo) lo ejecuta Colonos.gd, que llama a
## marcar_presente(), recoger() y entregar(). "ciudad" es inyectable para
## probar sin escena (EconomiaTest.gd).

## Ids de los colonos que se quedaron sin puesto porque este se quitó
## (Colonos.gd los vuelve a desempleado).
signal puesto_quitado(ids: Array)

## Ids de colonos que dejan de trabajar en un puesto que sigue en pie (se
## desactivó por deconstrucción, o se agotó: Colonos.gd los devuelve a
## desempleado, salvo a un acarreador con carga, que termina su viaje).
signal trabajadores_liberados(ids: Array)

## Una escuela completó las horas de su cohorte. Los "ids" ya están liberados de su puesto; Colonos
## los convierte (ver Colonos._on_cohorte_graduada()).
signal cohorte_graduada(esquina: Vector2i, ids: Array)

## Una universidad completó una investigación tecnológica.
signal investigacion_finalizada(nombre_tecnologia: String)

const Ajustes = preload("res://scripts/ajustes.gd")
const Energia = preload("res://scripts/Energia.gd")

## Valores «ninguno» de la celda de servicio (X, Z de la puerta) y del depósito
## (celda del baúl) de un puesto sin plantilla.
const SIN_SERVICIO := Vector2i.MAX
const SIN_DEPOSITO := Vector3i.MAX
## Sin piso interior conocido (puesto sin plantilla): los colonos solo esperan fuera.
const SIN_SUELO := -1

## Unidades que un acarreador lleva por viaje (placeholder). Con ~20 celdas de ruta
## un acarreador mueve ~16 comida/h, es decir 1 acarreador por cada 2 recolectores;
## los puestos más lejanos rinden menos.
static var CAPACIDAD_CARGA: float = Ajustes.ECONOMIA_CAPACIDAD_CARGA

## Valores admisibles para la reserva de insumo en el almacén central en porcentajes (0% a 50%)
static var PORCENTAJES_RESERVA_INSUMO: Array[float] = Ajustes.ECONOMIA_PORCENTAJES_RESERVA_INSUMO
static var VALORES_RESERVA_INSUMO: Array[float] = PORCENTAJES_RESERVA_INSUMO

## Mínimo de unidades que justifica un viaje del acarreador de una refinería (retirar insumo
## del stock central o recoger producto): evita viajes de 1 unidad. ponytail: un resto menor
## de este valor queda en el almacén local hasta acumular más.
static var CARGA_MINIMA: float = Ajustes.ECONOMIA_CARGA_MINIMA

## "tecnico" opera la receta en las refinerías y, en los puestos de recolección, recolecta como técnico;
## "recolector" (un obrero) y "especialista" solo existen en los puestos de recolección; "aprendiz" solo en las
## escuelas. "acarreador" vale en los puestos de recolección y en las refinerías (ver roles_de()).
const ROLES := ["recolector", "tecnico", "especialista", "aprendiz", "investigador", "acarreador"]
const RECURSOS_LIQUIDOS: Array[String] = ["agua", "crudo", "combustible"]

## Rango de oficio de quien recolecta: es el nivel mínimo de puesto que ocupa (ver nivel_de()). Obrero 1,
## técnico 2, especialista 3.
const RANGO_DE_ROL := {"recolector": 1, "tecnico": 2, "especialista": 3}

## Horas de juego que estudia una cohorte antes de graduarse (placeholder sin balance real).
static var HORAS_FORMACION: int = Ajustes.ECONOMIA_HORAS_FORMACION

## Tipos de puesto que consumen el mundo al producir; caza/recolección y pesca
## no consumen bloques (sus tasas dependen del entorno, ver recalcular_tasas()).
const TIPOS_QUE_CONSUMEN := ["mina", "maderero", "centro_extraccion"]

## Cada cuántas horas de juego se recalculan las tasas de todos los puestos
## según lo que queda en su entorno (árboles, bloques de mina, agua).
static var TICKS_RECALCULO: int = Ajustes.ECONOMIA_TICKS_RECALCULO

## Las tasas de un puesto usan las claves de Recoleccion.tasas_*(); estas cuatro
## son formas de obtener comida y se suman en el recurso "comida". El resto de
## claves (minerales, "madera") ya son el nombre del recurso.
const RECURSO_DE_TASA := {
	"caza": "comida", "recoleccion": "comida",
	"pesca": "comida", "frutos_mar": "comida",
}

var ciudad: Object = null  # Ciudad
## Colonos, inyectable o resuelto vía singleton / escena
var colonos: Object = null
## VoxelWorld, inyectable (Main.gd lo asigna). Sin él los puestos producen sin
## consumir el mundo.
var mundo: Object = null
var zonificacion: Object = null
var vias: Object = null

const COSTOS_BASE_EDIFICIO: Dictionary = {
	"central_termoelectrica": {"hierro": 100, "piedra": 100},
	"siderurgica": {"hierro": 80, "piedra": 80},
	"sembradios": {"madera": 50, "tierra": 50},
	"refineria_petrolera": {"hierro": 120, "piedra": 80},
	"productor_combustible": {"hierro": 100, "acero": 50},
}
var _ultimo_resumen_energia: Dictionary = {
	"demanda": 0.0,
	"capacidad": 0.0,
	"entregada": 0.0,
	"factor": 1.0,
	"deficit": false,
	"conectados": {},
}
var balance_energia: Dictionary:
	get: return _ultimo_resumen_energia.duplicate()
	set(val): _ultimo_resumen_energia = val.duplicate()

var _factores_energia: Dictionary = {}
var _horas_desde_recalculo := 0

func resumen_energia() -> Dictionary:
	return _ultimo_resumen_energia.duplicate()

func factor_energia_de(esquina: Vector2i) -> float:
	return _factores_energia.get(esquina, 0.0)


## Depósito compartido de fluidos entre todos los almacenes industriales del mapa.
var reserva_fluidos: Dictionary = {
	"agua": 0.0,
	"crudo": 0.0,
	"combustible": 0.0,
}

func capacidad_total_fluidos() -> float:
	var total := 0.0
	for esquina in puestos:
		var p: Dictionary = puestos[esquina]
		if p.get("tipo", "") == "almacen" and p.get("activo", false):
			total += p.get("capacidad", 1000.0)
	return total

func ingresar_fluido_almacen(recurso: String, cantidad: float) -> float:
	if not reserva_fluidos.has(recurso):
		return 0.0
	var cap_total := capacidad_total_fluidos()
	var espacio: float = INF
	if cap_total > 0.0:
		var total_actual := _total(reserva_fluidos)
		espacio = maxf(0.0, cap_total - total_actual)
	var admitido: float = minf(cantidad, espacio)
	if admitido > 1e-9:
		reserva_fluidos[recurso] = reserva_fluidos.get(recurso, 0.0) + admitido
		if ciudad != null and ciudad.almacen.has(recurso):
			if ciudad.almacen[recurso] is Object and ciudad.almacen[recurso].has_method("agregar"):
				ciudad.almacen[recurso].agregar(admitido)
			elif ciudad.almacen[recurso] is Object and "cantidad" in ciudad.almacen[recurso]:
				ciudad.almacen[recurso].cantidad += admitido
			elif ciudad.almacen[recurso] is float or ciudad.almacen[recurso] is int:
				ciudad.almacen[recurso] += admitido
		return admitido
	return 0.0

func extraer_fluido_almacen(recurso: String, cantidad: float) -> float:
	if not reserva_fluidos.has(recurso):
		return 0.0
	var disponible: float = reserva_fluidos.get(recurso, 0.0)
	var sacado: float = minf(disponible, cantidad)
	if sacado > 1e-9:
		reserva_fluidos[recurso] = maxf(0.0, disponible - sacado)
		if ciudad != null and ciudad.almacen.has(recurso):
			if ciudad.almacen[recurso] is Object and ciudad.almacen[recurso].has_method("quitar"):
				ciudad.almacen[recurso].quitar(sacado)
			elif ciudad.almacen[recurso] is Object and "cantidad" in ciudad.almacen[recurso]:
				ciudad.almacen[recurso].cantidad = maxf(0.0, ciudad.almacen[recurso].cantidad - sacado)
			elif ciudad.almacen[recurso] is float or ciudad.almacen[recurso] is int:
				ciudad.almacen[recurso] = maxf(0.0, ciudad.almacen[recurso] - sacado)
		return sacado
	return 0.0


## true mientras _actualizar_agotamiento() libera personal y reevalúa el área: evita que cada liberación
## recalcule por su cuenta.
var _recalculando := false
## true mientras desactivar_puesto() libera a todos de golpe: _actualizar_nivel() no toca el nivel.
var _liberando_todos := false

## Vector2i (esquina de la huella) -> {"tipo", "ancho", "alto", "cupo",
## "capacidad", "tasas" (clave de tasa -> unidades por recolector y hora),
## "entorno" (lo que Recoleccion.entorno_de_puesto() recordó del mundo al
## colocarlo), "en_curso" (recurso -> {"tipo": "bloque"|"arbol", "restante"
## en unidades, y "celda" o "id"}: el bloque o árbol que se está agotando),
## "recolectores": Array[int], "acarreadores": Array[int],
## "presentes": Dictionary (id de recolector -> true),
## "almacen": Dictionary (recurso -> float)}.
var puestos: Dictionary = {}
## id de colono -> esquina del puesto donde trabaja.
var _puesto_de: Dictionary = {}
var _contador_orden := 0


func _ready() -> void:
	if ciudad == null:
		ciudad = Ciudad
	if colonos == null and Engine.has_singleton("Colonos"):
		colonos = Engine.get_singleton("Colonos")
	ciudad.tick_simulado.connect(simular_hora)


## Cantidad de puestos construidos de "tipo".
func contar_tipo(tipo: String) -> int:
	var total := 0
	for p in puestos.values():
		if p.get("tipo", "") == tipo:
			total += 1
	return total


## Registra un puesto recién colocado, sin trabajadores. "tasas" son las de
## Recoleccion.tasas_de_entorno() al colocarlo y "entorno" el de
## Recoleccion.entorno_de_puesto() ({} = el puesto no consume ni recalcula).
## "servicio" (X, Z) es la celda exterior frente a su puerta y "deposito" la
## celda de su baúl (ver PlantillasPuesto.gd); sin ellas Colonos usa el anillo
## que rodea la huella y no hay depósito físico. "suelo" es la altura Y del piso
## interior TRANSITABLE de la plantilla (donde vive la puerta — una capa por
## encima de la losa de piso, capa 0, ver PlantillasPuesto.gd): los colonos
## entran a trabajar a las celdas libres de esa capa. "salida" (X, Z) es la celda frente a la
## puerta de salida de una refinería (la de entrada es "servicio"); SIN_SERVICIO en los puestos
## de una sola puerta. "chimenea" es la celda sobre la que sale el humo de una refinería activa
## (ver esta_refinando()); SIN_DEPOSITO si no tiene. "progreso" son las horas de estudio de la
## cohorte (solo escuelas, ver _formar()).
func registrar_puesto(esquina: Vector2i, tipo: String, ancho: int, alto: int, tasas: Dictionary, entorno: Dictionary = {}, servicio: Vector2i = SIN_SERVICIO, deposito: Vector3i = SIN_DEPOSITO, suelo: int = SIN_SUELO, salida: Vector2i = SIN_SERVICIO, chimenea: Vector3i = SIN_DEPOSITO) -> void:
	_contador_orden += 1
	var crudo_rest := 0
	if tipo == "centro_extraccion":
		var dp: Dictionary = entorno.get("datos_perforacion", {})
		if dp.get("tipo_pozo", "") == "crudo":
			if mundo != null and dp.has("perforacion"):
				crudo_rest = Recoleccion.contar_crudo_pozo(mundo, dp["perforacion"], dp["y_superficie"], dp["y_fondo"])
			else:
				crudo_rest = dp.get("bloques_hierro", 0)
	puestos[esquina] = {
		"tipo": tipo, "ancho": ancho, "alto": alto,
		"orden_construccion": _contador_orden,
		"cupo": Recoleccion.cupo_de(tipo),
		"capacidad": 500 if tipo == "central_termoelectrica" else Recoleccion.capacidad_almacen_de(tipo),
		"tasas": tasas.duplicate(),
		"entorno": entorno.duplicate(),
		"en_curso": {},
		"recolectores": [], "acarreadores": [],
		"presentes": {}, "almacen": {},
		"activo": true, "agotado": false,
		"servicio": servicio, "deposito": deposito, "suelo": suelo,
		"salida": salida, "chimenea": chimenea,
		"progreso": 0.0,  # horas que lleva estudiando la cohorte (solo escuelas)
		"nivel": 1,  # 1-3, solo en los puestos con niveles: rango mínimo de sus recolectores (ver nivel_de())
		"rangos": {},  # id de recolector -> rango de su oficio (RANGO_DE_ROL)
		"combustible_activo": "carbon" if tipo == "central_termoelectrica" else "",
		"crudo_restante": crudo_rest,
		"investigacion_activa": 0,
		"investigacion_pausada": false,
		"reserva_insumo": 0.0,
		"mejoras": [],
		"proyecto_mejora": {},
		"estado_operativo": "normal",
		"tipo_transporte": "acarreador_pie",
	}
	if tipo == "taller_transporte":
		puestos[esquina]["cola_fabricacion"] = []


## Quita el puesto (se deconstruyó): lo que quepa de su almacén local pasa al núcleo
## (el resto se pierde) y sus trabajadores quedan libres; se avisa con puesto_quitado. No-op si no existe.
func quitar_puesto(esquina: Vector2i) -> void:
	if not puestos.has(esquina):
		return
	if es_universidad(esquina):
		cancelar_investigacion(esquina)
	var p: Dictionary = puestos[esquina]
	# Review Focus 5: Retorno de vehículos asignados al demoler
	var vehiculo_asig: String = str(p.get("tipo_transporte", ""))
	if not vehiculo_asig.is_empty() and vehiculo_asig != "acarreador_pie":
		if ciudad != null:
			if "parque_transporte_asignado" in ciudad and ciudad.parque_transporte_asignado.has(vehiculo_asig):
				ciudad.parque_transporte_asignado[vehiculo_asig] = maxi(0, ciudad.parque_transporte_asignado[vehiculo_asig] - 1)
			if ciudad.has_method("registrar_vehiculo_disponible"):
				ciudad.registrar_vehiculo_disponible(vehiculo_asig, 1)
			elif "parque_transporte_disponible" in ciudad:
				ciudad.parque_transporte_disponible[vehiculo_asig] = ciudad.parque_transporte_disponible.get(vehiculo_asig, 0) + 1
	if not p.get("proyecto_mejora", {}).is_empty():
		if colonos != null and colonos.has_method("liberar_comision"):
			var id_proy: String = "mejora_%d_%d" % [esquina.x, esquina.y]
			colonos.liberar_comision(id_proy)
	for m_id in p.get("mejoras", []):
		var info_m: Dictionary = Ajustes.MEJORAS_PRACTICAS_CATALOGO.get(m_id, {})
		var doct: String = info_m.get("doctrina", "")
		var pts: float = float(info_m.get("puntos_doctrina", 0))
		if ciudad != null and doct != "" and pts > 0.0 and ciudad.has_method("agregar_puntos_doctrina"):
			ciudad.agregar_puntos_doctrina(doct, -pts)
		var otro_tiene := false
		for ot_esq in puestos:
			if ot_esq != esquina and puestos[ot_esq].get("mejoras", []).has(m_id):
				otro_tiene = true
				break
		if not otro_tiene and ciudad != null and "mejoras_practicas_instaladas" in ciudad:
			ciudad.mejoras_practicas_instaladas.erase(m_id)
	if ciudad != null and ciudad.has_method("actualizar_pacing_era"):
		ciudad.actualizar_pacing_era()
	retirar_deposito(esquina)  # último intento (el stock pudo liberar espacio desde que empezó la deconstrucción)
	var dp: Dictionary = p.get("entorno", {}).get("datos_perforacion", {})
	if not dp.is_empty() and mundo != null and dp.has("perforacion"):
		mundo.retirar_tuberia_extraccion(dp["perforacion"], dp["y_superficie"], dp["y_fondo"])
	var ids: Array = p["recolectores"] + p["acarreadores"]
	for id in ids:
		_puesto_de.erase(id)
	puestos.erase(esquina)
	puesto_quitado.emit(ids)


func tiene_puesto(esquina: Vector2i) -> bool:
	return puestos.has(esquina)


## Celdas (X,Z) de la huella del puesto; [] si no existe.
func huella_de(esquina: Vector2i) -> Array:
	if not puestos.has(esquina):
		return []
	var celdas: Array = []
	for dx in range(puestos[esquina]["ancho"]):
		for dz in range(puestos[esquina]["alto"]):
			celdas.append(Vector2i(esquina.x + dx, esquina.y + dz))
	return celdas


func cupo_libre(esquina: Vector2i) -> int:
	if not puestos.has(esquina):
		return 0
	var p: Dictionary = puestos[esquina]
	return p["cupo"] - p["recolectores"].size() - p["acarreadores"].size()


## Asigna un colono a un puesto con un rol. Falso si el puesto no existe, el
## rol no es válido, el cupo está lleno, el colono ya trabaja en algún puesto o el
## nivel del puesto no admite ese oficio (ver admite_rol()).
func asignar(esquina: Vector2i, rol: String, colono_id: int) -> bool:
	if not puestos.has(esquina) or not roles_de(esquina).has(rol) or _puesto_de.has(colono_id):
		return false  # roles válidos por tipo de puesto: ver roles_de()
	var p: Dictionary = puestos[esquina]
	if not p["activo"] or not admite_rol(esquina, rol) or (p["agotado"] and rol == "recolector" and not tiene_niveles(esquina)):
		return false  # inactivo (se está deconstruyendo), su nivel no admite ese oficio o está agotado sin niveles
	if cupo_libre(esquina) <= 0:
		return false
	p[_lista_de(rol)].append(colono_id)
	_puesto_de[colono_id] = esquina
	if tiene_niveles(esquina) and RANGO_DE_ROL.has(rol):
		p["rangos"][colono_id] = RANGO_DE_ROL[rol]
		_actualizar_nivel(esquina)
	return _puesto_de.has(colono_id)  # falso si subir el nivel dejó el puesto agotado y lo despidió al instante


## Roles que admite el puesto: aprendices en una escuela; técnicos y acarreadores en una refinería;
## obreros (recolector), técnicos, especialistas y acarreadores en los demás.
func roles_de(esquina: Vector2i) -> Array:
	if not puestos.has(esquina):
		return []
	var tipo: String = puestos[esquina]["tipo"]
	if tipo == "almacen":
		return []
	if es_escuela(esquina):
		return ["aprendiz"]
	if es_universidad(esquina):
		return ["investigador"]
	if tipo == "estacion_bombeo" or tipo == "centro_extraccion" or tipo == "refineria_petrolera":
		return ["tecnico"]
	var roles_res: Array = []
	if tipo == "central_termoelectrica":
		if puestos[esquina].get("combustible_activo", "carbon") == "carbon":
			roles_res = ["tecnico", "acarreador"]
		else:
			return ["tecnico"]
	elif es_refineria(esquina):
		roles_res = ["tecnico", "acarreador"]
	else:
		roles_res = ["recolector", "tecnico", "especialista", "acarreador"]

	var tipo_t: String = str(puestos[esquina].get("tipo_transporte", ""))
	if not tipo_t.is_empty() and Ajustes.TRANSPORTE_CATALOGO_UNIDADES.has(tipo_t):
		if int(Ajustes.TRANSPORTE_CATALOGO_UNIDADES[tipo_t].get("cantidad_tripulacion", 1)) == 0:
			roles_res.erase("acarreador")
	return roles_res


## true si el puesto tiene niveles (Recoleccion.TIPOS_CON_NIVELES).
func tiene_niveles(esquina: Vector2i) -> bool:
	return puestos.has(esquina) and Recoleccion.TIPOS_CON_NIVELES.has(puestos[esquina]["tipo"])


## Nivel del puesto (1-3): el rango mínimo de sus recolectores; sin recolectores conserva el último (parte en 1).
func nivel_de(esquina: Vector2i) -> int:
	return puestos[esquina]["nivel"] if puestos.has(esquina) else 1


## Recolectores del puesto cuyo oficio tiene ese rango (1 obrero, 2 técnico, 3 especialista).
func contar_rango(esquina: Vector2i, rango: int) -> int:
	if not puestos.has(esquina):
		return 0
	var total := 0
	for r in puestos[esquina]["rangos"].values():
		if r == rango:
			total += 1
	return total


## true si el nivel actual del puesto admite ese oficio: rango igual o superior al nivel y, estando agotado
## a su nivel, solo un rango superior (así un técnico puede reabrir un puesto de obreros agotado). Siempre
## true en los puestos sin niveles y para los acarreadores. No mira el cupo ni si está activo.
func admite_rol(esquina: Vector2i, rol: String) -> bool:
	if not tiene_niveles(esquina) or not RANGO_DE_ROL.has(rol):
		return true
	var p: Dictionary = puestos[esquina]
	var rango: int = RANGO_DE_ROL[rol]
	if rango >= p["nivel"]:
		return rango > p["nivel"] or (rango == p["nivel"] and not p["agotado"])
	# rango < p["nivel"]: permite retroceder de nivel si no está agotado en ese rango
	if mundo != null and p.has("entorno") and not p["entorno"].is_empty():
		var tasas_rango: Dictionary = Recoleccion.tasas_de_entorno(p["tipo"], mundo, p["entorno"], rango)
		return not _sin_tasas(tasas_rango)
	return not p.get("agotado", false)


## Recalcula el nivel como el rango mínimo de los recolectores; sin recolectores lo conserva. Si cambió,
## reevalúa de inmediato el área, las tasas y el agotamiento (salvo dentro de _actualizar_agotamiento()).
func _actualizar_nivel(esquina: Vector2i) -> void:
	var p: Dictionary = puestos[esquina]
	if _liberando_todos or p["rangos"].is_empty():
		return
	var minimo := 99
	for rango in p["rangos"].values():
		minimo = mini(minimo, rango)
	if minimo == p["nivel"]:
		return
	p["nivel"] = minimo
	if not _recalculando:
		recalcular_tasas(esquina)


## Quita a un colono de su puesto (despido o muerte). No-op si no trabaja.
func liberar(colono_id: int) -> void:
	if not _puesto_de.has(colono_id):
		return
	var esquina: Vector2i = _puesto_de[colono_id]
	var p: Dictionary = puestos[esquina]
	p["recolectores"].erase(colono_id)
	p["acarreadores"].erase(colono_id)
	p["presentes"].erase(colono_id)
	p["rangos"].erase(colono_id)
	if es_escuela(esquina):
		p["progreso"] = 0.0  # si se va un aprendiz, la cohorte empieza de nuevo
	_puesto_de.erase(colono_id)
	if tiene_niveles(esquina):
		_actualizar_nivel(esquina)  # al irse el de rango mínimo, el nivel puede subir


## El último colono asignado con ese rol, o -1: a quien despide el panel. En los puestos con niveles es el
## último con ese oficio (el botón «−» de Técnicos no despide a un obrero).
func ultimo_de(esquina: Vector2i, rol: String) -> int:
	if not puestos.has(esquina):
		return -1
	var p: Dictionary = puestos[esquina]
	var lista: Array = p[_lista_de(rol)]
	if tiene_niveles(esquina) and RANGO_DE_ROL.has(rol):
		for i in range(lista.size() - 1, -1, -1):
			if p["rangos"].get(lista[i], 0) == RANGO_DE_ROL[rol]:
				return lista[i]
		return -1
	return lista.back() if not lista.is_empty() else -1


## Lista interna donde vive cada rol: los técnicos y los aprendices comparten la de los recolectores (el cupo y la presencia funcionan igual).
static func _lista_de(rol: String) -> String:
	return "acarreadores" if rol == "acarreador" else "recolectores"


## Un recolector está (o deja de estar) en su puesto: solo entonces produce.
## Ignora a quien no sea recolector asignado.
func marcar_presente(colono_id: int, presente: bool) -> void:
	if not _puesto_de.has(colono_id):
		return
	var p: Dictionary = puestos[_puesto_de[colono_id]]
	if not p["recolectores"].has(colono_id):
		return
	if presente:
		p["presentes"][colono_id] = true
	else:
		p["presentes"].erase(colono_id)


func trabajadores_de(esquina: Vector2i) -> Dictionary:
	if not puestos.has(esquina):
		return {"recolectores": 0, "acarreadores": 0, "presentes": 0}
	var p: Dictionary = puestos[esquina]
	return {
		"recolectores": p["recolectores"].size(),
		"acarreadores": p["acarreadores"].size(),
		"presentes": p["presentes"].size(),
	}


## Unidades por hora de cada recurso con los recolectores presentes ahora.
func produccion_por_hora(esquina: Vector2i) -> Dictionary:
	var resultado: Dictionary = {}
	if not puestos.has(esquina):
		return resultado
	var mult_operativo: float = multiplicador_operativo_puesto(esquina)
	var factor_moral: float = 1.0
	if ciudad != null and "moral" in ciudad:
		factor_moral = ciudad.calcular_multiplicador_productividad(ciudad.moral)

	if es_refineria(esquina):
		var tasas_ref: Dictionary = CadenaMinerales.tasas_refinado({insumo_de(esquina): puestos[esquina]["presentes"].size()})
		for entrada in tasas_ref:
			resultado[tasas_ref[entrada]["tipo_salida"]] = tasas_ref[entrada]["produccion"] * factor_moral * mult_operativo
		return resultado
	var p: Dictionary = puestos[esquina]
	var presentes: int = p["presentes"].size()
	var multiplicador: float = Recoleccion.multiplicador_de_nivel(p["tipo"], p["nivel"])
	for clave in p["tasas"]:
		var recurso: String = RECURSO_DE_TASA.get(clave, clave)
		var es_alimento: bool = (recurso == "comida")
		var factor_moral_recurso: float = 1.0
		if ciudad != null and ciudad.has_method("calcular_multiplicador_productividad"):
			factor_moral_recurso = ciudad.calcular_multiplicador_productividad(ciudad.moral, es_alimento)
		resultado[recurso] = resultado.get(recurso, 0.0) + p["tasas"][clave] * presentes * multiplicador * factor_moral_recurso * mult_operativo
	return resultado


func almacen_local(esquina: Vector2i) -> Dictionary:
	if not puestos.has(esquina):
		return {}
	var p: Dictionary = puestos[esquina]
	if p.get("tipo", "") == "almacen":
		for r in ["agua", "crudo", "combustible"]:
			if not p["almacen"].has(r) and reserva_fluidos.get(r, 0.0) > 1e-9:
				p["almacen"][r] = reserva_fluidos[r]
	return p["almacen"].duplicate()


static func _total(almacen: Dictionary) -> float:
	var total := 0.0
	for v in almacen.values():
		total += v
	return total


## Una hora de juego de producción en todos los puestos: cada recolector
## presente suma su tasa al almacén local, pero solo lo que el entorno permita
## extraer (mina y maderero consumen bloques y árboles reales; ver _extraer()).
## Si el total local llegaría a pasar de la capacidad, solo entra lo que cabe,
## en proporción (el exceso se pierde: la producción se frena contra el tope y
## avisa de que falta acarreo).
func simular_hora() -> void:
	var obj_zonif: Object = zonificacion if zonificacion != null else Zonificacion
	var obj_vias: Object = vias if vias != null else Vias
	var red: Dictionary = Energia.calcular(puestos, obj_zonif, obj_vias, ciudad)
	_ultimo_resumen_energia = red.get("resumen", {})
	var factores_energia: Dictionary = red.get("factores", {})
	_factores_energia = factores_energia.duplicate()
	var quema_energia: Dictionary = red.get("quema", {})

	for esq_central: Vector2i in quema_energia:
		if puestos.has(esq_central):
			var local_central: Dictionary = puestos[esq_central]["almacen"]
			var quemado: Dictionary = quema_energia[esq_central]
			for tipo_comb: String in quemado:
				var cant: float = quemado[tipo_comb]
				local_central[tipo_comb] = maxf(0.0, local_central.get(tipo_comb, 0.0) - cant)
				if local_central[tipo_comb] <= 1e-9:
					local_central.erase(tipo_comb)

	for esquina in puestos:
		var p: Dictionary = puestos[esquina]
		if not p["activo"]:
			continue
		_tick_mejora_puesto(esquina)
		_liberar_acarreadores_si_agotado(esquina)
		if es_universidad(esquina):
			_tick_universidad(esquina, factores_energia.get(esquina, 0.0))
			continue
		if es_escuela(esquina):
			_formar(esquina)
			continue
		if es_refineria(esquina):
			_refinar(esquina, factores_energia.get(esquina, 0.0))
			continue
		if p["tipo"] == "central_termoelectrica":
			continue
		if p["tipo"] == "taller_transporte":
			_tick_taller_transporte(esquina, 1.0)
			continue
		var producido: Dictionary = produccion_por_hora(esquina)
		var total_producido := _total(producido)
		if total_producido <= 0.0:
			continue
		var espacio: float = p["capacidad"] - _total(p["almacen"])
		if espacio <= 0.0:
			continue
		var factor: float = minf(1.0, espacio / total_producido)
		for recurso in producido:
			var concedido: float = _extraer(esquina, recurso, producido[recurso] * factor)
			if concedido > 0.0:
				p["almacen"][recurso] = p["almacen"].get(recurso, 0.0) + concedido
	_procesar_transporte_fluidos()
	_horas_desde_recalculo += 1
	if _horas_desde_recalculo >= TICKS_RECALCULO:
		_horas_desde_recalculo = 0
		recalcular_todas()


## Transporta fluidos acumulados en almacenes locales a través de tuberías conectadas.
func _procesar_transporte_fluidos() -> void:
	if mundo == null:
		return
	for esquina: Vector2i in puestos:
		var p: Dictionary = puestos[esquina]
		var alm: Dictionary = p.get("almacen", {})
		if alm.is_empty():
			continue

		for rec in ["agua", "crudo", "combustible"]:
			var cant_disp: float = alm.get(rec, 0.0)
			if cant_disp <= 1e-9:
				continue

			var puertos_out: Array[Vector3i] = _puertos_salida_de_puesto(esquina, rec)
			for p_out in puertos_out:
				if cant_disp <= 1e-9:
					break
				if Canalizaciones == null:
					break
				var destinos: Array[Vector3i] = Canalizaciones.destinos_de_puerto_salida(p_out)
				if destinos.is_empty():
					var id_red: int = Canalizaciones.puertos_conectados.get(p_out, -1)
					if id_red > 0 and not Canalizaciones.extremos_abiertos_de_red(id_red).is_empty():
						var c_derrame: Vector3i = Canalizaciones.verter_derrame(id_red, rec, mundo)
						if c_derrame != Vector3i.ZERO:
							var derramado: float = minf(cant_disp, 10.0)
							alm[rec] -= derramado
							cant_disp -= derramado
							if p.get("tipo", "") == "almacen":
								extraer_fluido_almacen(rec, derramado)
							if alm[rec] <= 1e-9:
								alm.erase(rec)
					continue

				var cuota: float = cant_disp / float(destinos.size())
				for p_in in destinos:
					var enviado := 0.0
					var esq_dest: Vector2i = _buscar_puesto_por_puerto(p_in)
					var p_dest: Dictionary = puestos.get(esq_dest, {})
					if p_dest.get("tipo", "") == "almacen":
						var cap_dest: float = p_dest.get("capacidad", 3000.0)
						var espacio_dest: float = maxf(0.0, cap_dest - _total(p_dest.get("almacen", {})))
						var cuota_admitida: float = minf(cuota, espacio_dest)
						enviado = ingresar_fluido_almacen(rec, cuota_admitida)
						if enviado > 1e-9:
							p_dest["almacen"][rec] = p_dest["almacen"].get(rec, 0.0) + enviado
					elif not p_dest.is_empty():
						var espacio_dest: float = espacio_disponible_para(esq_dest, rec)
						enviado = minf(cuota, espacio_dest)
						if enviado > 1e-9:
							p_dest["almacen"][rec] = p_dest["almacen"].get(rec, 0.0) + enviado

					if enviado > 1e-9:
						alm[rec] -= enviado
						cant_disp -= enviado
						if p.get("tipo", "") == "almacen":
							extraer_fluido_almacen(rec, enviado)
						if alm[rec] <= 1e-9:
							alm.erase(rec)


func _puertos_salida_de_puesto(esquina: Vector2i, rec: String) -> Array[Vector3i]:
	var res: Array[Vector3i] = []
	if not puestos.has(esquina):
		return res
	var p: Dictionary = puestos[esquina]
	var ancho: int = p.get("ancho", 0)
	var alto: int = p.get("alto", 0)
	var patron := "puerto_" + rec + "_out"

	# 1. Buscar en Canalizaciones.puertos_conectados dentro del área del puesto
	if Canalizaciones != null:
		for celda: Vector3i in Canalizaciones.puertos_conectados:
			if celda.x >= esquina.x and celda.x < esquina.x + ancho and celda.z >= esquina.y and celda.z < esquina.y + alto:
				if Canalizaciones.tipo_por_puerto.get(celda, "") == patron:
					res.append(celda)

	# 2. Si no encontró en Canalizaciones, escanear en mundo
	if res.is_empty() and mundo != null and mundo.has_method("obtener_tipo"):
		var suelo: int = p.get("suelo", 0)
		if suelo != SIN_SUELO:
			var y_p: int = suelo + 4
			for dx in range(ancho):
				for dz in range(alto):
					var celda := Vector3i(esquina.x + dx, y_p, esquina.y + dz)
					var tipo_b: String = mundo.obtener_tipo(celda)
					if tipo_b == patron:
						res.append(celda)
	return res


func _buscar_puesto_por_puerto(celda_puerto: Vector3i) -> Vector2i:
	for esq: Vector2i in puestos:
		var p: Dictionary = puestos[esq]
		var ancho: int = p.get("ancho", 0)
		var alto: int = p.get("alto", 0)
		if celda_puerto.x >= esq.x and celda_puerto.x < esq.x + ancho and celda_puerto.z >= esq.y and celda_puerto.z < esq.y + alto:
			return esq
	return Vector2i(-99999, -99999)


func buscar_puesto_por_puerto(celda_puerto: Vector3i) -> Vector2i:
	return _buscar_puesto_por_puerto(celda_puerto)



## Vuelve a medir el entorno de cada puesto y actualiza sus tasas.
func recalcular_todas() -> void:
	for esquina in puestos:
		recalcular_tasas(esquina)


## Actualiza las tasas de un puesto con el estado actual del mundo (ver
## Recoleccion.tasas_de_entorno()). No-op sin mundo, sin entorno o si el puesto
## no existe.
func recalcular_tasas(esquina: Vector2i) -> void:
	if mundo == null or not puestos.has(esquina):
		return
	var p: Dictionary = puestos[esquina]
	if p["entorno"].is_empty():
		return
	p["entorno"] = Recoleccion.entorno_de_nivel(p["tipo"], mundo, p["entorno"], p["nivel"])
	p["tasas"] = Recoleccion.tasas_de_entorno(p["tipo"], mundo, p["entorno"], p["nivel"])
	if p["tipo"] == "centro_extraccion":
		var dp: Dictionary = p["entorno"].get("datos_perforacion", {})
		if dp.get("tipo_pozo", "") == "crudo" and dp.has("perforacion"):
			p["crudo_restante"] = Recoleccion.contar_crudo_pozo(mundo, dp["perforacion"], dp["y_superficie"], dp["y_fondo"])
			if p["crudo_restante"] <= 0:
				p["agotado"] = true
				p["tasas"]["crudo"] = 0.0
	_actualizar_agotamiento(esquina)


## Descuenta del mundo hasta "unidades" de "recurso" para el puesto y devuelve
## cuántas se pudieron extraer de verdad (menos si el área se agotó). Trabaja
## sobre el bloque o árbol "en curso" del recurso: cuando se agota, se retira
## del mundo y se pasa al siguiente. Sin mundo o sin entorno, o en puestos que
## no consumen, devuelve "unidades" sin tocar nada.
func _extraer(esquina: Vector2i, recurso: String, unidades: float) -> float:
	var p: Dictionary = puestos[esquina]
	if mundo == null or p["entorno"].is_empty() or not TIPOS_QUE_CONSUMEN.has(p["tipo"]):
		return unidades
	if p["tipo"] == "centro_extraccion" and recurso != "crudo":
		return unidades
	var extraido := 0.0
	while unidades - extraido > 1e-9:
		var actual: Dictionary = p["en_curso"].get(recurso, {})
		if not actual.is_empty() and not _en_curso_valido(actual):
			actual = {}  # el avatar lo derribó o lo minó: se descarta
		if actual.is_empty():
			actual = _siguiente_bloque(p, recurso)
			if actual.is_empty():
				p["en_curso"].erase(recurso)
				if p["tipo"] == "centro_extraccion" and recurso == "crudo":
					p["crudo_restante"] = 0
					p["agotado"] = true
					p["tasas"]["crudo"] = 0.0
					_actualizar_agotamiento(esquina)
				break
			p["en_curso"][recurso] = actual
		var tomado: float = minf(unidades - extraido, actual["restante"])
		actual["restante"] -= tomado
		extraido += tomado
		if actual["restante"] <= 1e-9:
			_terminar_bloque(actual)
			p["en_curso"].erase(recurso)
			if p["tipo"] == "centro_extraccion" and recurso == "crudo":
				var dp: Dictionary = p["entorno"].get("datos_perforacion", {})
				if not dp.is_empty() and dp.has("perforacion"):
					p["crudo_restante"] = Recoleccion.contar_crudo_pozo(mundo, dp["perforacion"], dp["y_superficie"], dp["y_fondo"])
					if p["crudo_restante"] <= 0:
						p["agotado"] = true
						p["tasas"]["crudo"] = 0.0
						_actualizar_agotamiento(esquina)
	return extraido


## Bloque de mina o árbol siguiente para "recurso" ({} si no queda ninguno).
func _siguiente_bloque(p: Dictionary, recurso: String) -> Dictionary:
	var entorno: Dictionary = p["entorno"]
	if p["tipo"] == "mina":
		var celda: Vector3i = Recoleccion.siguiente_bloque_mina(mundo, entorno["centro"], entorno["altura"], recurso, Recoleccion.profundidad_de_nivel(p["nivel"]))
		if celda == Recoleccion.SIN_BLOQUE:
			return {}
		return {"tipo": "bloque", "celda": celda, "recurso": recurso, "restante": Recoleccion.rendimiento_de(recurso)}
	if p["tipo"] == "centro_extraccion":
		var dp: Dictionary = entorno.get("datos_perforacion", {})
		if recurso == "crudo" and not dp.is_empty() and dp.has("perforacion"):
			var celda: Vector3i = Recoleccion.siguiente_bloque_crudo_pozo(mundo, dp["perforacion"], dp["y_superficie"], dp["y_fondo"])
			if celda == Recoleccion.SIN_BLOQUE:
				return {}
			return {"tipo": "bloque", "celda": celda, "recurso": "crudo", "restante": Recoleccion.rendimiento_de("crudo")}
		return {}
	var id: int = mundo.arboles.mas_cercano_en_radio(entorno["centro"], entorno["radio_arboles"])
	if id == -1:
		return {}
	return {"tipo": "arbol", "id": id, "restante": Recoleccion.rendimiento_de("madera")}


## Sigue existiendo el bloque o árbol "en curso" (el avatar pudo quitarlo antes).
func _en_curso_valido(actual: Dictionary) -> bool:
	if actual["tipo"] == "bloque":
		var celda: Vector3i = actual["celda"]
		return mundo.material_real(mundo.obtener_tipo(celda)) == actual["recurso"] and Recoleccion.es_extraible(mundo, celda)
	return mundo.arboles.salud_de(actual["id"]) > 0


## Un bloque quedó agotado: se retira del mundo; un árbol pierde 1 de salud
## (una celda de tronco, 10 unidades) y cae entero al llegar a 0.
func _terminar_bloque(actual: Dictionary) -> void:
	if actual["tipo"] == "bloque":
		mundo.retirar_bloque_extraido(actual["celda"])
		return
	var celdas: Array = mundo.arboles.celdas_de(actual["id"])
	if not celdas.is_empty():
		mundo.talar_bloque_de_arbol(celdas[0], 1)


## Un acarreador que está en el puesto pide su carga: hasta "capacidad"
## unidades, repartidas por recurso en el orden del almacén. Solo se la dan si
## el almacén ya tiene la carga completa, o si no hay recolectores presentes
## y queda algo (así ningún resto queda atascado ni se hacen viajes de una
## unidad mientras se sigue produciendo). {} si no se cumple.
func recoger(esquina: Vector2i, capacidad: float = CAPACIDAD_CARGA) -> Dictionary:
	if not puestos.has(esquina):
		return {}
	var p: Dictionary = puestos[esquina]
	var total_solido := 0.0
	for r in p["almacen"]:
		if not RECURSOS_LIQUIDOS.has(r):
			total_solido += p["almacen"][r]
	if total_solido <= 1e-9:
		return {}
	# Carga parcial: solo sin recolectores o si el puesto ya no produce (resto de un área agotada).
	if total_solido < capacidad and not p["presentes"].is_empty() and _total(produccion_por_hora(esquina)) > 0.0:
		return {}
	var carga: Dictionary = {}
	var restante := capacidad
	for recurso in p["almacen"].keys():
		if RECURSOS_LIQUIDOS.has(recurso):
			continue
		if restante <= 1e-9:
			break
		var tomado: float = minf(p["almacen"][recurso], restante)
		carga[recurso] = tomado
		restante -= tomado
		p["almacen"][recurso] -= tomado
		if p["almacen"][recurso] <= 1e-9:
			p["almacen"].erase(recurso)
	return carga


## Un acarreador llegó al núcleo urbano: suma su carga al stock central. Lo
## que no cabe (stock lleno) se retiene en el vehículo/carga sin destruirse ni desbordar (Review Focus 1).
func entregar(carga: Dictionary, origen_categoria: String = "") -> Dictionary:
	var restante: Dictionary = {}
	for recurso in carga.keys():
		var monto: float = float(carga[recurso])
		if ciudad != null and ciudad.almacen.has(recurso):
			var ingreso_real: float = ciudad.almacen[recurso].agregar(monto)
			if recurso == "comida" and ciudad.has_method("ingresar_comida_estratificada"):
				ciudad.ingresar_comida_estratificada(ingreso_real, origen_categoria)
			var sobrante: float = monto - ingreso_real
			if sobrante > 1e-9:
				restante[recurso] = sobrante
				carga[recurso] = sobrante
			else:
				carga.erase(recurso)
		else:
			restante[recurso] = monto
	return restante


func categoria_comida_de_puesto(esquina: Vector2i) -> String:
	if not puestos.has(esquina):
		return "recoleccion_caza"
	var t: String = puestos[esquina].get("tipo", "")
	match t:
		"pesca_frutos_mar": return "pesca"
		"caza_recoleccion": return "recoleccion_caza"
		"sembradios": return "sembradios"
		"granjas_animales": return "granjas_animales"
		"hidroponia": return "hidroponia"
		"sintetico": return "sintetico"
		_: return "recoleccion_caza"


## Celda (X, Z) de servicio del puesto (frente a su puerta) o SIN_SERVICIO.
func servicio_de(esquina: Vector2i) -> Vector2i:
	return puestos[esquina]["servicio"] if puestos.has(esquina) else SIN_SERVICIO


## Altura Y del piso interior del puesto o SIN_SUELO.
func suelo_de(esquina: Vector2i) -> int:
	return puestos[esquina]["suelo"] if puestos.has(esquina) else SIN_SUELO


## Celda (X, Z) frente a la puerta de salida de una refinería o SIN_SERVICIO.
func salida_de(esquina: Vector2i) -> Vector2i:
	return puestos[esquina]["salida"] if puestos.has(esquina) else SIN_SERVICIO


## true si el puesto es una refinería (CadenaMinerales.REFINERIAS): produce a partir de su almacén
## local con una receta, en vez de extraer del entorno.
func es_refineria(esquina: Vector2i) -> bool:
	return puestos.has(esquina) and CadenaMinerales.REFINERIAS.has(puestos[esquina]["tipo"])


## true si el puesto es una escuela (Recoleccion.ESCUELAS): forma a sus aprendices en vez de producir.
func es_escuela(esquina: Vector2i) -> bool:
	return puestos.has(esquina) and Recoleccion.ESCUELAS.has(puestos[esquina]["tipo"])


## true si el puesto es una universidad: investiga proyectos de ciudad.
func es_universidad(esquina: Vector2i) -> bool:
	return puestos.has(esquina) and puestos[esquina]["tipo"] == "universidad"


## true si el puesto es una central termoeléctrica.
func es_central_termoelectrica(esquina: Vector2i) -> bool:
	return puestos.has(esquina) and puestos[esquina]["tipo"] == "central_termoelectrica"


## Espacio disponible en un puesto para un recurso específico respetando particiones y topes.
func espacio_disponible_para(esquina: Vector2i, recurso: String) -> float:
	if not puestos.has(esquina):
		return 0.0
	var p: Dictionary = puestos[esquina]
	var cap: float = float(p.get("capacidad", 1000.0))
	var espacio_total: float = maxf(0.0, cap - _total(p.get("almacen", {})))
	if p.get("tipo", "") == "refineria_petrolera":
		if recurso == "crudo":
			var crudo_actual: float = p.get("almacen", {}).get("crudo", 0.0)
			return minf(espacio_total, maxf(0.0, CadenaMinerales.LIMITE_CRUDO_REFINERIA - crudo_actual))
		elif recurso == "combustible":
			var comb_actual: float = p.get("almacen", {}).get("combustible", 0.0)
			return minf(espacio_total, maxf(0.0, CadenaMinerales.RESERVA_COMBUSTIBLE_REFINERIA - comb_actual))
	elif p.get("tipo", "") == "central_termoelectrica":
		if recurso == "carbon":
			var carb_actual: float = p.get("almacen", {}).get("carbon", 0.0)
			return minf(espacio_total, maxf(0.0, 500.0 - carb_actual))
	return espacio_total


## Inyecta hasta 'cantidad' de fluido al puesto respetando sus límites.
func inyectar_fluido_puesto(esquina: Vector2i, recurso: String, cantidad: float) -> float:
	if not puestos.has(esquina):
		return 0.0
	var espacio: float = espacio_disponible_para(esquina, recurso)
	var admitido: float = minf(cantidad, espacio)
	if admitido > 1e-9:
		var p: Dictionary = puestos[esquina]
		p["almacen"][recurso] = p["almacen"].get(recurso, 0.0) + admitido
		return admitido
	return 0.0


## Retira hasta 'cantidad_max' de carbón del stock central (núcleo) para abastecer a la central.
func cargar_carbon_de_nucleo(cantidad_max: float = CAPACIDAD_CARGA) -> Dictionary:
	if ciudad == null or not ciudad.almacen.has("carbon"):
		return {}
	var sacado: float = ciudad.almacen["carbon"].quitar(cantidad_max)
	if sacado > 1e-9:
		return {"carbon": sacado}
	return {}


## Retira hasta 'cantidad_max' de carbón del almacén especificado para abastecer a la central.
func cargar_carbon_de_almacen(esquina_almacen: Vector2i, cantidad_max: float = CAPACIDAD_CARGA) -> Dictionary:
	if not puestos.has(esquina_almacen):
		return {}
	var p: Dictionary = puestos[esquina_almacen]
	var local: Dictionary = p.get("almacen", {})
	var disp: float = local.get("carbon", 0.0)
	var sacado: float = minf(disp, cantidad_max)
	if sacado > 1e-9:
		local["carbon"] -= sacado
		if local["carbon"] <= 1e-9:
			local.erase("carbon")
		return {"carbon": sacado}
	return {}


func investigacion_en_curso_en_otra_universidad(esquina_actual: Vector2i, id_tech: int) -> bool:
	for esq in puestos:
		if esq != esquina_actual and es_universidad(esq):
			if puestos[esq].get("investigacion_activa", 0) == id_tech:
				return true
	return false


func iniciar_investigacion(esquina: Vector2i, id_tech: int) -> bool:
	if not es_universidad(esquina):
		return false
	var p: Dictionary = puestos[esquina]
	p["investigacion_activa"] = id_tech
	p["investigacion_pausada"] = false
	p["progreso"] = ciudad.progreso_investigacion.get(id_tech, 0.0) if ciudad != null else 0.0
	return true


func pausar_investigacion(esquina: Vector2i, pausar: bool) -> void:
	if not es_universidad(esquina):
		return
	puestos[esquina]["investigacion_pausada"] = pausar


func cancelar_investigacion(esquina: Vector2i) -> void:
	if not es_universidad(esquina):
		return
	var p: Dictionary = puestos[esquina]
	var id_act: int = p.get("investigacion_activa", 0)
	if id_act <= 0:
		return
	if ciudad != null and Ciudad.COSTOS_INVESTIGACION.has(id_act):
		var costo: Dictionary = Ciudad.COSTOS_INVESTIGACION[id_act]
		if ciudad.almacen.has("hierro"):
			(ciudad.almacen["hierro"] as Ciudad.Recurso).agregar(float(costo["hierro"]))
		if ciudad.almacen.has("madera"):
			(ciudad.almacen["madera"] as Ciudad.Recurso).agregar(float(costo["madera"]))
		ciudad.progreso_investigacion[id_act] = 0.0
	p["investigacion_activa"] = 0
	p["investigacion_pausada"] = false
	p["progreso"] = 0.0


func _avanzar_investigacion(esquina: Vector2i, id_tech: int, horas: float) -> void:
	if not Ciudad.COSTOS_INVESTIGACION.has(id_tech) or ciudad == null:
		return
	var costo: Dictionary = Ciudad.COSTOS_INVESTIGACION[id_tech]
	var meta: float = float(costo["horas_investigador"])
	var prog_actual: float = ciudad.progreso_investigacion.get(id_tech, 0.0) + horas
	ciudad.progreso_investigacion[id_tech] = minf(meta, prog_actual)
	var p: Dictionary = puestos[esquina]
	p["progreso"] = ciudad.progreso_investigacion[id_tech]
	if ciudad.progreso_investigacion[id_tech] >= meta:
		ciudad.nivel_investigado = max(ciudad.nivel_investigado, id_tech)
		p["investigacion_activa"] = 0
		p["investigacion_pausada"] = false
		p["progreso"] = 0.0
		investigacion_finalizada.emit(costo["nombre"])


## Calcula el delta horario de puntos de ciencia según investigadores, moral y electrificación.
func calcular_delta_puntos_ciencia(investigadores: int, mult_moral: float, energizada: bool) -> float:
	return float(investigadores) * 1.0 * mult_moral * (1.0 if energizada else 0.5)


## Helper para calcular puntos de ciencia generados en un intervalo de horas.
func generar_puntos_ciencia(horas: float, investigadores_activos: int, mult_moral: float, energizada: bool) -> float:
	return calcular_delta_puntos_ciencia(investigadores_activos, mult_moral, energizada) * horas


## Simula el avance horario en una universidad (investigación de era legacy y Capa 1 de ciencia teórica).
func _tick_universidad(esquina: Vector2i = Vector2i(-999999, -999999), factor_energia: float = 1.0) -> void:
	if esquina == Vector2i(-999999, -999999):
		for esq in puestos:
			if es_universidad(esq):
				_tick_universidad(esq, factor_energia_de(esq))
		return
	if not puestos.has(esquina):
		return
	var p: Dictionary = puestos[esquina]
	var id_act: int = p.get("investigacion_activa", 0)
	if id_act > 0 and not p.get("investigacion_pausada", false):
		var factor_uni: float = 1.0
		if ciudad != null and id_act == 3:
			factor_uni = factor_energia
		var horas_uni: float = float(p["presentes"].size()) * factor_uni
		if horas_uni > 0.0 and ciudad != null:
			_avanzar_investigacion(esquina, id_act, horas_uni)

	# Capa 1: Ciencia teórica en la Universidad y acumulación de puntos_ciencia
	if ciudad != null and ciudad.ciencia_teorica_activa != "":
		var inv_activos: int = p["presentes"].size()
		if inv_activos > 0:
			var mult_moral: float = 1.0
			if ciudad.has_method("calcular_multiplicador_productividad"):
				mult_moral = ciudad.calcular_multiplicador_productividad(ciudad.moral)
			var energizada: bool = factor_energia > 0.0
			var delta_pts: float = calcular_delta_puntos_ciencia(inv_activos, mult_moral, energizada)
			ciudad.acumular_ciencia_teorica(delta_pts)


## Recurso principal que consume la refinería (tipo_entrada de su receta, p. ej. "hierro").
func insumo_de(esquina: Vector2i) -> String:
	return CadenaMinerales.REFINERIAS[puestos[esquina]["tipo"]]


## Insumos de la receta de la refinería por lote (p. ej. {"hierro": 3, "carbon": 4}).
func entradas_de(esquina: Vector2i) -> Dictionary:
	return CadenaMinerales.RECETAS[insumo_de(esquina)]["entradas"]


## Recurso que produce la refinería (p. ej. "acero").
func producto_de(esquina: Vector2i) -> String:
	return CadenaMinerales.RECETAS[insumo_de(esquina)]["tipo_salida"]


## Una hora de estudio: la cohorte (el cupo completo de aprendices) suma 1 h solo si los aprendices
## están TODOS presentes; si falta alguno el conteo se pausa, y con menos aprendices que el cupo se
## reinicia. A HORAS_FORMACION se gradúa: los aprendices se liberan y Colonos los convierte.
func _formar(esquina: Vector2i) -> void:
	var p: Dictionary = puestos[esquina]
	if p["recolectores"].size() < p["cupo"]:
		p["progreso"] = 0.0
		return
	if p["presentes"].size() < p["cupo"]:
		return
	p["progreso"] += 1.0
	var horas_meta: int = Recoleccion.ESCUELAS[p["tipo"]]["horas"] if Recoleccion.ESCUELAS.has(p["tipo"]) else HORAS_FORMACION
	if p["progreso"] < horas_meta:
		return
	var ids: Array = p["recolectores"].duplicate()
	for id in ids:
		liberar(id)  # también reinicia "progreso"
	cohorte_graduada.emit(esquina, ids)


## Una hora de refinado: los técnicos presentes consumen insumo del almacén local y lo convierten
## en producto (CadenaMinerales.procesar_tick()). No hay nada que hacer sin ellos. Si el resultado
## no cupiera en el almacén (compartido entre insumo y producto), esa hora no se refina.
## ponytail: todo o nada al llenarse; con las recetas actuales (2 -> 1, 3 -> 1) el total nunca crece,
## así que solo importaría para una receta que multiplique (aserradero).
func _refinar(esquina: Vector2i, factor_energia: float = 1.0) -> void:
	var p: Dictionary = puestos[esquina]
	var presentes: int = p["presentes"].size()
	if presentes <= 0:
		return
	var factor_moral: float = 1.0
	if ciudad != null and "moral" in ciudad:
		factor_moral = ciudad.calcular_multiplicador_productividad(ciudad.moral)
	var mult_op: float = multiplicador_operativo_puesto(esquina)
	var resultado: Dictionary = CadenaMinerales.procesar_receta(insumo_de(esquina), presentes, 1.0, p["almacen"], factor_energia * factor_moral * mult_op, float(p["capacidad"]))
	if _total(resultado) > p["capacidad"] + 1e-9:
		return
	for recurso in resultado.keys():
		if resultado[recurso] <= 1e-9:
			resultado.erase(recurso)
	p["almacen"] = resultado


func cambiar_combustible_central(esquina: Vector2i, combustible: String) -> void:
	if not puestos.has(esquina) or puestos[esquina]["tipo"] != "central_termoelectrica":
		return
	var p: Dictionary = puestos[esquina]
	p["combustible_activo"] = combustible
	if combustible != "carbon":
		_liberar_de(esquina, p["acarreadores"].duplicate())


func obtener_reserva_insumo(esquina: Vector2i) -> float:
	if not puestos.has(esquina):
		return 0.0
	return float(puestos[esquina].get("reserva_insumo", 0.0))


func establecer_reserva_insumo(esquina: Vector2i, valor: float) -> void:
	if not puestos.has(esquina):
		return
	puestos[esquina]["reserva_insumo"] = valor


func subir_reserva_insumo(esquina: Vector2i) -> float:
	if not puestos.has(esquina):
		return 0.0
	var actual: float = obtener_reserva_insumo(esquina)
	var lista: Array[float] = PORCENTAJES_RESERVA_INSUMO
	var idx: int = -1
	for i in range(lista.size()):
		if is_equal_approx(lista[i], actual):
			idx = i
			break
	var nuevo_idx: int = mini(lista.size() - 1, (idx + 1) if idx != -1 else 0)
	var siguiente: float = lista[nuevo_idx]
	establecer_reserva_insumo(esquina, siguiente)
	return siguiente


func bajar_reserva_insumo(esquina: Vector2i) -> float:
	if not puestos.has(esquina):
		return 0.0
	var actual: float = obtener_reserva_insumo(esquina)
	var lista: Array[float] = PORCENTAJES_RESERVA_INSUMO
	var idx: int = -1
	for i in range(lista.size()):
		if is_equal_approx(lista[i], actual):
			idx = i
			break
	var nuevo_idx: int = maxi(0, (idx - 1) if idx != -1 else 0)
	var anterior: float = lista[nuevo_idx]
	establecer_reserva_insumo(esquina, anterior)
	return anterior


func ciclar_reserva_insumo(esquina: Vector2i) -> float:
	if not puestos.has(esquina):
		return 0.0
	var actual: float = obtener_reserva_insumo(esquina)
	var idx: int = -1
	for i in range(VALORES_RESERVA_INSUMO.size()):
		if is_equal_approx(VALORES_RESERVA_INSUMO[i], actual):
			idx = i
			break
	var siguiente: float = VALORES_RESERVA_INSUMO[(idx + 1) % VALORES_RESERVA_INSUMO.size()] if idx != -1 else VALORES_RESERVA_INSUMO[0]
	establecer_reserva_insumo(esquina, siguiente)
	return siguiente


func calcular_reserva_en_unidades(esquina: Vector2i, recurso: String) -> float:
	var val: float = obtener_reserva_insumo(esquina)
	if val <= 0.0:
		return 0.0
	if val > 1.0:
		return val  # compatibilidad con valores fijos legacy
	if ciudad != null and ciudad.almacen.has(recurso):
		return ciudad.almacen[recurso].limite * val
	return 0.0


## Qué retiraría ahora un acarreador del stock central para esta refinería: {recurso: cantidad}.
## Cada insumo tiene su tope en el almacén local, repartido en la proporción de la receta (así uno
## no llena el almacén y deja sin sitio al otro), y la carga total no pasa de capacidad_carga ni
## del espacio libre. Respeta el umbral de reserva_insumo fijado para la refinería/central. {} si no es refinería o no hay nada que llevar.
## ponytail: reparto fijo por receta; si el almacén se desbalancea mucho, esto no lo corrige.
func insumos_a_cargar(esquina: Vector2i, capacidad_carga: float = CAPACIDAD_CARGA) -> Dictionary:
	if not puestos.has(esquina):
		return {}
	var p: Dictionary = puestos[esquina]
	if p["tipo"] == "central_termoelectrica":
		if p.get("combustible_activo", "carbon") != "carbon":
			return {}
		var stock_actual: float = p["almacen"].get("carbon", 0.0)
		if stock_actual >= 500.0 - 1e-9:
			return {}
		if ciudad != null and ciudad.almacen.has("carbon") and ciudad.almacen["carbon"].cantidad > 1e-9:
			var reserva_cen: float = calcular_reserva_en_unidades(esquina, "carbon")
			var disp_cen: float = maxf(0.0, ciudad.almacen["carbon"].cantidad - reserva_cen)
			var cant: float = minf(capacidad_carga, disp_cen)
			if cant > 1e-9:
				return {"carbon": cant}
		return {}
	if not es_refineria(esquina):
		return {}
	var entradas: Dictionary = entradas_de(esquina)
	var suma: float = 0.0
	for recurso in entradas:
		if not RECURSOS_LIQUIDOS.has(recurso):
			suma += entradas[recurso]
	if suma <= 1e-9:
		return {}
	var plan: Dictionary = {}
	var total: float = 0.0
	for recurso in entradas:
		if RECURSOS_LIQUIDOS.has(recurso):
			continue
		var reserva: float = calcular_reserva_en_unidades(esquina, recurso)
		var parte: float = entradas[recurso] / suma
		var espacio: float = p["capacidad"] * parte - p["almacen"].get(recurso, 0.0)
		var stock_ciudad: float = ciudad.almacen[recurso].cantidad if (ciudad != null and ciudad.almacen.has(recurso)) else 0.0
		var disp: float = maxf(0.0, stock_ciudad - reserva)
		var cantidad: float = minf(minf(capacidad_carga * parte, espacio), disp)
		if cantidad > 1e-9:
			plan[recurso] = cantidad
			total += cantidad
	var libre: float = p["capacidad"] - _total(p["almacen"])
	if total > libre:
		for recurso in plan:
			plan[recurso] *= maxf(0.0, libre) / total
	return plan


## Total de unidades de insumos_a_cargar().
func insumo_a_cargar(esquina: Vector2i, capacidad_carga: float = CAPACIDAD_CARGA) -> float:
	return _total(insumos_a_cargar(esquina, capacidad_carga))


## true si el almacén local no alcanza para producir ni 1 unidad de producto (falta algún insumo).
func falta_insumo(esquina: Vector2i) -> bool:
	if not puestos.has(esquina):
		return false
	var p: Dictionary = puestos[esquina]
	if p["tipo"] == "central_termoelectrica":
		var stock: float = p["almacen"].get("combustible", 0.0) + p["almacen"].get("crudo", 0.0) + p["almacen"].get("carbon", 0.0)
		return stock < 1.0 - 1e-9
	var entradas: Dictionary = entradas_de(esquina)
	var salida: int = CadenaMinerales.RECETAS[insumo_de(esquina)]["cantidad_salida"]
	for recurso in entradas:
		if puestos[esquina]["almacen"].get(recurso, 0.0) < float(entradas[recurso]) / salida - 1e-9:
			return true
	return false


## true si vale la pena que un acarreador vaya al núcleo por insumo: hay al menos CARGA_MINIMA que
## llevar (rellenar por adelantado) o, aunque sea menos, a la refinería no le alcanza para producir
## y hay algo con qué ayudarla (la pide).
func conviene_cargar(esquina: Vector2i) -> bool:
	var cantidad: float = insumo_a_cargar(esquina)
	return cantidad >= CARGA_MINIMA or (cantidad > 1e-9 and falta_insumo(esquina))


## true si la refinería está produciendo ahora: hay técnicos presentes, tiene insumo para un lote
## completo y espacio en el almacén local. Es lo que el humo de la chimenea muestra.
func esta_refinando(esquina: Vector2i) -> bool:
	if not puestos.has(esquina):
		return false
	var p: Dictionary = puestos[esquina]
	if p["tipo"] == "central_termoelectrica":
		if not p["activo"] or p["presentes"].is_empty():
			return false
		var stock: float = p["almacen"].get("combustible", 0.0) + p["almacen"].get("crudo", 0.0) + p["almacen"].get("carbon", 0.0)
		return stock > 1e-9 and _ultimo_resumen_energia.get("entregada", 0.0) > 1e-9
	if not es_refineria(esquina):
		return false
	if not p["activo"] or p["presentes"].is_empty() or _total(p["almacen"]) >= p["capacidad"] - 1e-9:
		return false
	var entradas: Dictionary = entradas_de(esquina)
	for recurso in entradas:
		if p["almacen"].get(recurso, 0.0) < entradas[recurso] - 1e-9:
			return false
	return true


## El acarreador retira insumos del stock central (ver insumos_a_cargar()). {} si no hay nada que llevar.
func cargar_insumo(esquina: Vector2i, capacidad_carga: float = CAPACIDAD_CARGA) -> Dictionary:
	var carga: Dictionary = {}
	var plan: Dictionary = insumos_a_cargar(esquina, capacidad_carga)
	for recurso in plan:
		var sacado: float = ciudad.almacen[recurso].quitar(plan[recurso])
		if sacado > 1e-9:
			carga[recurso] = sacado
	return carga


## El acarreador deja su carga en el almacén local; lo que ya no cupiera vuelve al stock central.
func descargar_insumo(esquina: Vector2i, carga: Dictionary) -> void:
	if not puestos.has(esquina):
		entregar(carga)
		return
	var p: Dictionary = puestos[esquina]
	for recurso in carga:
		var cabe: float = minf(carga[recurso], espacio_disponible_para(esquina, recurso))
		if cabe > 1e-9:
			p["almacen"][recurso] = p["almacen"].get(recurso, 0.0) + cabe
		if carga[recurso] - cabe > 1e-9:
			entregar({recurso: carga[recurso] - cabe})


## Producto refinado esperando en el almacén local.
func producto_pendiente(esquina: Vector2i) -> float:
	if not es_refineria(esquina):
		return 0.0
	return puestos[esquina]["almacen"].get(producto_de(esquina), 0.0)


## El acarreador recoge el producto (nada más) hasta "capacidad". Sin mínimo: el mínimo lo decide
## Colonos al elegir si vale la pena el viaje. {} si no hay nada.
func recoger_producto(esquina: Vector2i, capacidad: float = CAPACIDAD_CARGA) -> Dictionary:
	if not es_refineria(esquina):
		return {}
	var producto: String = producto_de(esquina)
	if RECURSOS_LIQUIDOS.has(producto):
		return {}
	var pendiente: float = producto_pendiente(esquina)
	var tomado: float = minf(pendiente, capacidad)
	if tomado <= 1e-9:
		return {}
	var local: Dictionary = puestos[esquina]["almacen"]
	local[producto] -= tomado
	if local[producto] <= 1e-9:
		local.erase(producto)
	return {producto: tomado}


## Esquina del puesto cuyo baúl (depósito) está en "celda", o Recoleccion.SIN_PUESTO.
func puesto_con_deposito(celda: Vector3i) -> Vector2i:
	for esquina in puestos:
		if puestos[esquina]["deposito"] == celda:
			return esquina
	return Recoleccion.SIN_PUESTO


## Extrae hasta "monto" de un recurso del depósito hacia el stock central
## (nunca más de lo que había ni de lo que cabe en el stock). Devuelve lo
## transferido, 0.0 si nada (usado por retirar_deposito() y VentanaBaul).
func retirar_uno(esquina: Vector2i, recurso: String, monto: float) -> float:
	if not puestos.has(esquina) or not ciudad.almacen.has(recurso):
		return 0.0
	var local: Dictionary = puestos[esquina]["almacen"]
	var disponible: float = local.get(recurso, 0.0)
	if disponible <= 0.0:
		return 0.0
	var ingreso: float = ciudad.almacen[recurso].agregar(min(disponible, monto))
	if ingreso <= 1e-9:
		return 0.0
	local[recurso] -= ingreso
	if local[recurso] <= 1e-9:
		local.erase(recurso)
	return ingreso


## Carga hasta "monto" de un recurso del stock central hacia el depósito
## (nunca más de lo disponible ni de lo que cabe en el puesto). Devuelve lo
## transferido, 0.0 si nada (usado por agregar_deposito() y VentanaBaul).
func agregar_uno(esquina: Vector2i, recurso: String, monto: float) -> float:
	if not puestos.has(esquina) or not ciudad.almacen.has(recurso):
		return 0.0
	var espacio: float = espacio_disponible_para(esquina, recurso)
	if espacio <= 0.0:
		return 0.0
	var salida: float = ciudad.almacen[recurso].quitar(min(espacio, monto))
	if salida <= 1e-9:
		return 0.0
	var local: Dictionary = puestos[esquina]["almacen"]
	local[recurso] = local.get(recurso, 0.0) + salida
	return salida


## El avatar toma del depósito: pasa al stock central lo que quepa (el resto se
## queda en el almacén local). Devuelve lo transferido, {} si nada.
func retirar_deposito(esquina: Vector2i) -> Dictionary:
	var tomado: Dictionary = {}
	if not puestos.has(esquina):
		return tomado
	for recurso in puestos[esquina]["almacen"].keys():
		var ingreso: float = retirar_uno(esquina, recurso, INF)
		if ingreso > 0.0:
			tomado[recurso] = ingreso
	return tomado


## El avatar carga al depósito: pasa del stock central al almacén local lo
## que quepa (el resto se queda en el stock central). Devuelve lo
## transferido, {} si nada.
func agregar_deposito(esquina: Vector2i) -> Dictionary:
	var entregado: Dictionary = {}
	if not puestos.has(esquina):
		return entregado
	for recurso in ciudad.almacen.keys():
		var salida: float = agregar_uno(esquina, recurso, INF)
		if salida > 0.0:
			entregado[recurso] = salida
	return entregado


## El puesto empieza a deconstruirse: deja de funcionar y todos sus trabajadores
## quedan libres. Su almacén local pasa al núcleo lo que quepa (ver retirar_deposito()).
## Idempotente; no-op si el puesto no existe.
func desactivar_puesto(esquina: Vector2i) -> void:
	if not puestos.has(esquina) or not puestos[esquina]["activo"]:
		return
	var p: Dictionary = puestos[esquina]
	p["activo"] = false
	retirar_deposito(esquina)  # el baúl se desmonta: lo que quepa pasa al núcleo urbano en vez de perderse
	_liberando_todos = true  # que el orden de las bajas no suba el nivel del puesto que se demuele
	_liberar_de(esquina, p["recolectores"] + p["acarreadores"])
	_liberando_todos = false


## La obra del puesto volvió a completarse: vuelve a funcionar, sin trabajadores.
## Recalcula el entorno por si el recurso se agotó mientras tanto.
func reactivar_puesto(esquina: Vector2i) -> void:
	if not puestos.has(esquina):
		return
	puestos[esquina]["activo"] = true
	recalcular_tasas(esquina)


static func _sin_tasas(tasas: Dictionary) -> bool:
	for tasa in tasas.values():
		if tasa > 0.0:
			return false
	return true


## Un puesto sin ninguna tasa positiva está agotado a su nivel actual: pierde a los recolectores de rango
## mínimo (y a sus acarreadores en cuanto su almacén local se vacía). Si quien queda tiene un rango mayor,
## el nivel sube, el área crece y se reevalúa el agotamiento; así hasta el nivel 3.
func _actualizar_agotamiento(esquina: Vector2i) -> void:
	var p: Dictionary = puestos[esquina]
	p["agotado"] = _sin_tasas(p["tasas"])
	if p["agotado"] and not tiene_niveles(esquina):
		_liberar_de(esquina, p["recolectores"].duplicate())  # sin niveles no hay rangos: se va todo el personal
	elif p["agotado"]:
		_recalculando = true
		while p["agotado"]:
			var nivel_previo: int = p["nivel"]
			_liberar_de(esquina, _recolectores_de_rango(p, nivel_previo))
			if p["nivel"] == nivel_previo:
				break  # nadie más sube el nivel: se queda agotado
			p["entorno"] = Recoleccion.entorno_de_nivel(p["tipo"], mundo, p["entorno"], p["nivel"])
			p["tasas"] = Recoleccion.tasas_de_entorno(p["tipo"], mundo, p["entorno"], p["nivel"])
			p["agotado"] = _sin_tasas(p["tasas"])
		_recalculando = false
	_liberar_acarreadores_si_agotado(esquina)


## Ids de los recolectores del puesto cuyo oficio tiene ese rango (copia).
func _recolectores_de_rango(p: Dictionary, rango: int) -> Array:
	var ids: Array = []
	for id in p["rangos"]:
		if p["rangos"][id] == rango:
			ids.append(id)
	return ids


func _liberar_acarreadores_si_agotado(esquina: Vector2i) -> void:
	var p: Dictionary = puestos[esquina]
	if p["agotado"] and _total(p["almacen"]) <= 1e-9:
		_liberar_de(esquina, p["acarreadores"].duplicate())


## Libera a "ids" (copia, no la lista viva del puesto) y avisa a Colonos.
func _liberar_de(_esquina: Vector2i, ids: Array) -> void:
	if ids.is_empty():
		return
	for id in ids:
		liberar(id)
	trabajadores_liberados.emit(ids)


## Devuelve la celda Vector3i representativa del puesto (depósito, servicio o esquina en suelo).
func _destino_de_puesto(esquina: Vector2i) -> Vector3i:
	if not puestos.has(esquina):
		return Vector3i.ZERO
	var p: Dictionary = puestos[esquina]
	var y_suelo: int = p.get("suelo", 0) if p.get("suelo", 0) >= 0 else 0
	if p.get("deposito", SIN_DEPOSITO) != SIN_DEPOSITO:
		return p["deposito"]
	if p.get("servicio", SIN_SERVICIO) != SIN_SERVICIO:
		return Vector3i(p["servicio"].x, y_suelo, p["servicio"].y)
	return Vector3i(esquina.x, y_suelo, esquina.y)


## Inicia la instalación in-situ de una mejora práctica en un puesto.
func iniciar_mejora_practica(esquina: Vector2i, id_mejora: String) -> bool:
	if not puestos.has(esquina):
		return false
	if not Ajustes.MEJORAS_PRACTICAS_CATALOGO.has(id_mejora):
		return false
	var p: Dictionary = puestos[esquina]
	var info: Dictionary = Ajustes.MEJORAS_PRACTICAS_CATALOGO[id_mejora]

	if p.get("mejoras", []).has(id_mejora):
		return false
	if not p.get("proyecto_mejora", {}).is_empty():
		return false

	var req: String = str(info.get("req", info.get("prerrequisito", "")))
	if req != "" and ciudad != null and ciudad.has_method("esta_ciencia_descubierta"):
		if not ciudad.esta_ciencia_descubierta(req):
			return false

	var doct_nueva: String = str(info.get("doctrina", ""))
	for ex in info.get("excluye", []):
		if p.get("mejoras", []).has(ex):
			return false
	for m_inst in p.get("mejoras", []):
		var info_inst: Dictionary = Ajustes.MEJORAS_PRACTICAS_CATALOGO.get(m_inst, {})
		if info_inst.get("excluye", []).has(id_mejora):
			return false
		var doct_inst: String = str(info_inst.get("doctrina", ""))
		if doct_nueva != "" and doct_inst != "" and doct_nueva != doct_inst:
			return false

	var tipo_edif: String = str(info.get("edificio_tipo", ""))
	if tipo_edif != "" and p.get("tipo", "") != tipo_edif:
		return false

	var costo: Dictionary = info.get("costo", {})
	if ciudad != null and ciudad.has_method("consumir_costos"):
		if not ciudad.consumir_costos(costo):
			return false

	var num_inv: int = int(info.get("investigadores", 1))
	if colonos != null and colonos.has_method("despachar_comision_cientifica"):
		var dest: Vector3i = _destino_de_puesto(esquina)
		var id_edificio: String = "puesto_%d_%d" % [esquina.x, esquina.y]
		var id_proy: String = "mejora_%d_%d" % [esquina.x, esquina.y]
		colonos.despachar_comision_cientifica(dest, id_edificio, num_inv, id_proy)

	p["proyecto_mejora"] = {
		"id": id_mejora,
		"estado": "ESPERANDO_PERSONAL",
		"progreso": 0.0,
		"tiempo": float(info.get("tiempo", 1.0)),
		"es_reconversion": false,
		"id_anterior": "",
		"investigadores_requeridos": num_inv,
	}
	return true


## Inicia la reconversión industrial doctrinal de un puesto sustituyendo una mejora previa sin demolerlo.
func iniciar_reconversion_industrial(esquina: Vector2i, nueva_mejora: String) -> bool:
	if not puestos.has(esquina):
		return false
	if not Ajustes.MEJORAS_PRACTICAS_CATALOGO.has(nueva_mejora):
		return false
	var p: Dictionary = puestos[esquina]
	var info: Dictionary = Ajustes.MEJORAS_PRACTICAS_CATALOGO[nueva_mejora]

	if p.get("mejoras", []).has(nueva_mejora):
		return false
	if not p.get("proyecto_mejora", {}).is_empty():
		return false

	var req: String = str(info.get("req", info.get("prerrequisito", "")))
	if req != "" and ciudad != null and ciudad.has_method("esta_ciencia_descubierta"):
		if not ciudad.esta_ciencia_descubierta(req):
			return false

	var tipo_edif: String = str(info.get("edificio_tipo", ""))
	if tipo_edif != "" and p.get("tipo", "") != tipo_edif:
		return false

	var mejora_anterior: String = ""
	for m in p.get("mejoras", []):
		if info.get("excluye", []).has(m):
			mejora_anterior = m
			break
		var m_info: Dictionary = Ajustes.MEJORAS_PRACTICAS_CATALOGO.get(m, {})
		if m_info.get("excluye", []).has(nueva_mejora):
			mejora_anterior = m
			break
	if mejora_anterior == "" and not p.get("mejoras", []).is_empty():
		mejora_anterior = p["mejoras"][0]
	if mejora_anterior == "":
		return false

	var costo_reforma: Dictionary = {}
	var factor_mat: float = Ajustes.RECONVERSION_FACTOR_MATERIALES_MEJORA
	var costo_mat: Dictionary = info.get("costo", {})
	for rec in costo_mat:
		costo_reforma[rec] = float(costo_mat[rec]) * factor_mat

	var factor_edif: float = Ajustes.RECONVERSION_FACTOR_COSTO_EDIFICIO
	var costo_base: Dictionary = COSTOS_BASE_EDIFICIO.get(p.get("tipo", ""), {})
	for rec in costo_base:
		costo_reforma[rec] = costo_reforma.get(rec, 0.0) + float(costo_base[rec]) * factor_edif

	if ciudad != null and ciudad.has_method("consumir_costos"):
		if not ciudad.consumir_costos(costo_reforma):
			return false

	p["estado_operativo"] = "RECONVERSION"

	var num_inv: int = int(info.get("investigadores", 1))
	if colonos != null and colonos.has_method("despachar_comision_cientifica"):
		var dest: Vector3i = _destino_de_puesto(esquina)
		var id_edificio: String = "puesto_%d_%d" % [esquina.x, esquina.y]
		var id_proy: String = "mejora_%d_%d" % [esquina.x, esquina.y]
		colonos.despachar_comision_cientifica(dest, id_edificio, num_inv, id_proy)

	var tiempo_base: float = float(info.get("tiempo", 1.0))
	var tiempo_reconv: float = tiempo_base * Ajustes.RECONVERSION_FACTOR_TIEMPO
	p["proyecto_mejora"] = {
		"id": nueva_mejora,
		"estado": "ESPERANDO_PERSONAL",
		"progreso": 0.0,
		"tiempo": tiempo_reconv,
		"es_reconversion": true,
		"id_anterior": mejora_anterior,
		"investigadores_requeridos": num_inv,
	}
	return true


## Multiplicador de producción o refinado según el estado operativo del edificio.
func multiplicador_operativo_puesto(esquina: Vector2i) -> float:
	if not puestos.has(esquina):
		return 1.0
	if puestos[esquina].get("estado_operativo", "normal") == "RECONVERSION":
		return Ajustes.RECONVERSION_PRODUCCION_PENALIZADA
	return 1.0


## Finaliza la mejora o reconversión activa en el puesto y actualiza doctrina e IDU.
func completar_mejora_en_puesto(esquina: Vector2i) -> void:
	if not puestos.has(esquina):
		return
	var p: Dictionary = puestos[esquina]
	var pm: Dictionary = p.get("proyecto_mejora", {})
	if pm.is_empty():
		return
	var id_m: String = pm.get("id", "")
	if not Ajustes.MEJORAS_PRACTICAS_CATALOGO.has(id_m):
		p["proyecto_mejora"] = {}
		p["estado_operativo"] = "normal"
		return
	var info: Dictionary = Ajustes.MEJORAS_PRACTICAS_CATALOGO[id_m]

	if pm.get("es_reconversion", false) and pm.get("id_anterior", "") != "":
		var id_ant: String = pm["id_anterior"]
		var info_ant: Dictionary = Ajustes.MEJORAS_PRACTICAS_CATALOGO.get(id_ant, {})
		if ciudad != null and ciudad.has_method("agregar_puntos_doctrina"):
			var doct_ant: String = str(info_ant.get("doctrina", ""))
			var pts_ant: float = float(info_ant.get("puntos_doctrina", 0))
			if doct_ant != "":
				ciudad.agregar_puntos_doctrina(doct_ant, -pts_ant)
		p["mejoras"].erase(id_ant)

		if ciudad != null and "mejoras_practicas_instaladas" in ciudad:
			var aun_instalada := false
			for otra_esq in puestos:
				if puestos[otra_esq].get("mejoras", []).has(id_ant):
					aun_instalada = true
					break
			if not aun_instalada:
				ciudad.mejoras_practicas_instaladas.erase(id_ant)

	if not p["mejoras"].has(id_m):
		p["mejoras"].append(id_m)

	if ciudad != null:
		if ciudad.has_method("agregar_puntos_doctrina"):
			var doct: String = str(info.get("doctrina", ""))
			var pts: float = float(info.get("puntos_doctrina", 0))
			if doct != "":
				ciudad.agregar_puntos_doctrina(doct, pts)
		if "mejoras_practicas_instaladas" in ciudad:
			if not ciudad.mejoras_practicas_instaladas.has(id_m):
				ciudad.mejoras_practicas_instaladas.append(id_m)
		if ciudad.has_method("actualizar_pacing_era"):
			ciudad.actualizar_pacing_era()

	p["estado_operativo"] = "normal"
	p["proyecto_mejora"] = {}

	if colonos != null and colonos.has_method("liberar_comision"):
		var id_proy: String = "mejora_%d_%d" % [esquina.x, esquina.y]
		colonos.liberar_comision(id_proy)


## Actualiza el avance de la obra in-situ de una mejora práctica o reconversión.
func _tick_mejora_puesto(esquina: Vector2i) -> void:
	if not puestos.has(esquina):
		return
	var p: Dictionary = puestos[esquina]
	var pm: Dictionary = p.get("proyecto_mejora", {})
	if pm.is_empty():
		return
	var id_proy: String = "mejora_%d_%d" % [esquina.x, esquina.y]
	if pm.get("estado", "") == "ESPERANDO_PERSONAL":
		if colonos != null and colonos.has_method("comision_esta_completa_en_destino"):
			var dest: Vector3i = _destino_de_puesto(esquina)
			if colonos.comision_esta_completa_en_destino(id_proy, dest):
				pm["estado"] = "EN_EJECUCION"
	if pm.get("estado", "") == "EN_EJECUCION":
		pm["progreso"] = pm.get("progreso", 0.0) + 1.0
		if pm["progreso"] >= float(pm.get("tiempo", 1.0)):
			completar_mejora_en_puesto(esquina)


## Nombre evolutivo de un taller de transporte según la era y ciencias de la ciudad.
func obtener_nombre_evolutivo_taller(_esquina: Vector2i = Vector2i.ZERO) -> String:
	if ciudad == null:
		return "Taller de Carretas"
	var era: int = ciudad.era_actual if ("era_actual" in ciudad) else 1
	var tiene_era_3_plus: bool = (era >= 3)
	if not tiene_era_3_plus and "ciencias_teoricas_descubiertas" in ciudad:
		for id_c in ciudad.ciencias_teoricas_descubiertas:
			var info: Dictionary = Ajustes.CIENCIAS_TEORICAS_CATALOGO.get(id_c, {})
			if int(info.get("era", 1)) >= 3:
				tiene_era_3_plus = true
				break
	if tiene_era_3_plus:
		return "Taller de Maquinaria y Transporte"
	if "ciencias_teoricas_descubiertas" in ciudad and ciudad.ciencias_teoricas_descubiertas.has("traccion_animal_engranajes"):
		return "Establo de Transporte"
	return "Taller de Carretas"


## Catálogo de vehículos que pueden fabricarse actualmente en el taller de transporte.
func vehiculos_fabricables_en_taller(_esquina: Vector2i = Vector2i.ZERO) -> Array[String]:
	var fabricables: Array[String] = []
	if ciudad == null:
		return fabricables
	var era: int = ciudad.era_actual if ("era_actual" in ciudad) else 1
	var techs: Array = ciudad.ciencias_teoricas_descubiertas if ("ciencias_teoricas_descubiertas" in ciudad) else []

	for tipo in Ajustes.TRANSPORTE_CATALOGO_UNIDADES:
		if tipo == "acarreador_pie":
			continue
		var unit: Dictionary = Ajustes.TRANSPORTE_CATALOGO_UNIDADES[tipo]
		var era_min: int = unit.get("era_minima", 1)
		if era < era_min:
			continue
		var tech_req: String = unit.get("tech_requerida", "")
		if tech_req != "" and not techs.has(tech_req):
			continue
		var req_puesto: String = unit.get("req_puesto", "")
		if req_puesto != "":
			var puesto_encontrado := false
			for esq in puestos:
				var p: Dictionary = puestos[esq]
				if p.get("tipo", "") == req_puesto and p.get("activo", true):
					puesto_encontrado = true
					break
			if not puesto_encontrado:
				continue
		fabricables.append(tipo)
	return fabricables


func _obreros_en_taller(p: Dictionary) -> int:
	var obreros: int = int(p.get("obreros", 0))
	var recolectores: int = p.get("recolectores", []).size()
	return maxi(obreros, recolectores)


## Ordena la fabricación de un vehículo en el taller de transporte tras cobrar los insumos del almacén central.
func ordenar_fabricacion_vehiculo(esquina: Vector2i, tipo_vehiculo: String) -> bool:
	if not puestos.has(esquina):
		return false
	var p: Dictionary = puestos[esquina]
	if p.get("tipo", "") != "taller_transporte":
		return false
	if not vehiculos_fabricables_en_taller(esquina).has(tipo_vehiculo):
		return false
	if not Ajustes.TRANSPORTE_CATALOGO_UNIDADES.has(tipo_vehiculo):
		return false
	var unit: Dictionary = Ajustes.TRANSPORTE_CATALOGO_UNIDADES[tipo_vehiculo]
	var costo: Dictionary = unit.get("costo_fabricacion", {})
	if ciudad == null:
		return false
	if ciudad.has_method("consumir_costos"):
		if not ciudad.consumir_costos(costo):
			return false
	elif "almacen" in ciudad and ciudad.almacen != null:
		for rec in costo:
			if not ciudad.almacen.has(rec) or ciudad.almacen[rec].cantidad < float(costo[rec]):
				return false
		for rec in costo:
			if ciudad.almacen[rec].has_method("quitar"):
				ciudad.almacen[rec].quitar(float(costo[rec]))
			else:
				ciudad.almacen[rec].cantidad -= float(costo[rec])
	else:
		return false

	if not p.has("cola_fabricacion"):
		p["cola_fabricacion"] = []
	p["cola_fabricacion"].append({
		"tipo": tipo_vehiculo,
		"progreso": 0.0,
		"tiempo_total": float(unit.get("tiempo_fabricacion", 15.0))
	})
	return true


## Simula el avance horario o por delta de la cola de ensamblaje en el taller de transporte.
func _tick_taller_transporte(esquina: Vector2i, delta: float = 1.0) -> void:
	if not puestos.has(esquina):
		return
	var p: Dictionary = puestos[esquina]
	var cola: Array = p.get("cola_fabricacion", [])
	if cola.is_empty():
		return
	var cant_obreros: int = _obreros_en_taller(p)
	if cant_obreros <= 0:
		return
	var item: Dictionary = cola[0]
	item["progreso"] = item.get("progreso", 0.0) + delta * float(cant_obreros)
	if item["progreso"] >= float(item.get("tiempo_total", 1.0)):
		completar_fabricacion_en_taller(esquina)


## Concluye el ensamble del vehículo al frente de la cola y lo incorpora al parque disponible de la ciudad.
func completar_fabricacion_en_taller(esquina: Vector2i) -> void:
	if not puestos.has(esquina):
		return
	var p: Dictionary = puestos[esquina]
	var cola: Array = p.get("cola_fabricacion", [])
	if cola.is_empty():
		return
	var item: Dictionary = cola.pop_front()
	var tipo_v: String = str(item.get("tipo", ""))
	if tipo_v.is_empty():
		return
	if ciudad != null:
		if ciudad.has_method("registrar_vehiculo_disponible"):
			ciudad.registrar_vehiculo_disponible(tipo_v, 1)
		elif "parque_transporte_disponible" in ciudad:
			ciudad.parque_transporte_disponible[tipo_v] = ciudad.parque_transporte_disponible.get(tipo_v, 0) + 1


## Despliega y asigna un tipo de vehículo de transporte al puesto, administrando el parque móvil de la ciudad.
func asignar_tipo_transporte_puesto(esquina: Vector2i, tipo_vehiculo: String) -> bool:
	if not puestos.has(esquina):
		return false
	var p: Dictionary = puestos[esquina]

	if tipo_vehiculo == "" or tipo_vehiculo == "acarreador_pie":
		tipo_vehiculo = "acarreador_pie"
	elif not Ajustes.TRANSPORTE_CATALOGO_UNIDADES.has(tipo_vehiculo):
		return false

	var vehiculo_anterior: String = str(p.get("tipo_transporte", "acarreador_pie"))
	if vehiculo_anterior.is_empty():
		vehiculo_anterior = "acarreador_pie"

	if vehiculo_anterior == tipo_vehiculo:
		return true

	# Si tenía asignado otro vehículo motorizado/tracción, liberarlo
	if vehiculo_anterior != "acarreador_pie":
		if ciudad != null:
			if "parque_transporte_asignado" in ciudad and ciudad.parque_transporte_asignado.has(vehiculo_anterior):
				ciudad.parque_transporte_asignado[vehiculo_anterior] = maxi(0, ciudad.parque_transporte_asignado[vehiculo_anterior] - 1)
			if ciudad.has_method("registrar_vehiculo_disponible"):
				ciudad.registrar_vehiculo_disponible(vehiculo_anterior, 1)
			elif "parque_transporte_disponible" in ciudad:
				ciudad.parque_transporte_disponible[vehiculo_anterior] = ciudad.parque_transporte_disponible.get(vehiculo_anterior, 0) + 1

	if tipo_vehiculo == "acarreador_pie":
		p["tipo_transporte"] = "acarreador_pie"
		if colonos != null and colonos.has_method("reconciliar_tripulacion_puesto"):
			colonos.reconciliar_tripulacion_puesto(esquina)
		return true

	# Validar stock disponible en la ciudad
	var disp: int = 0
	if ciudad != null:
		if "parque_transporte_disponible" in ciudad:
			disp = ciudad.parque_transporte_disponible.get(tipo_vehiculo, 0)
		if disp <= 0:
			return false

	var unit_info: Dictionary = Ajustes.TRANSPORTE_CATALOGO_UNIDADES.get(tipo_vehiculo, {})

	# Retirar 1 de disponible y sumar 1 a asignado
	if ciudad != null:
		if ciudad.has_method("retirar_vehiculo_disponible"):
			if not ciudad.retirar_vehiculo_disponible(tipo_vehiculo, 1):
				return false
		elif "parque_transporte_disponible" in ciudad:
			ciudad.parque_transporte_disponible[tipo_vehiculo] = disp - 1

		if "parque_transporte_asignado" in ciudad:
			ciudad.parque_transporte_asignado[tipo_vehiculo] = ciudad.parque_transporte_asignado.get(tipo_vehiculo, 0) + 1

	p["tipo_transporte"] = tipo_vehiculo

	# Review Focus 4: Dron autónomo opera con tripulación 0 (libera acarreadores humanos)
	if int(unit_info.get("cantidad_tripulacion", 1)) == 0:
		if colonos != null and colonos.has_method("despedir"):
			while p.get("acarreadores", []).size() > 0:
				if not colonos.despedir(esquina, "acarreador"):
					break
		if p.get("acarreadores", []).size() > 0:
			for cid in p.get("acarreadores", []).duplicate():
				liberar(cid)
	elif colonos != null and colonos.has_method("reconciliar_tripulacion_puesto"):
		colonos.reconciliar_tripulacion_puesto(esquina)

	return true

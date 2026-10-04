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
const CAPACIDAD_CARGA := 150.0

## Mínimo de unidades que justifica un viaje del acarreador de una refinería (retirar insumo
## del stock central o recoger producto): evita viajes de 1 unidad. ponytail: un resto menor
## de este valor queda en el almacén local hasta acumular más.
const CARGA_MINIMA := 10.0

## "tecnico" opera la receta en las refinerías y, en los puestos de recolección, recolecta como técnico;
## "recolector" (un obrero) y "especialista" solo existen en los puestos de recolección; "aprendiz" solo en las
## escuelas. "acarreador" vale en los puestos de recolección y en las refinerías (ver roles_de()).
const ROLES := ["recolector", "tecnico", "especialista", "aprendiz", "investigador", "acarreador"]

## Rango de oficio de quien recolecta: es el nivel mínimo de puesto que ocupa (ver nivel_de()). Obrero 1,
## técnico 2, especialista 3.
const RANGO_DE_ROL := {"recolector": 1, "tecnico": 2, "especialista": 3}

## Horas de juego que estudia una cohorte antes de graduarse (placeholder sin balance real).
const HORAS_FORMACION := 24

## Tipos de puesto que consumen el mundo al producir; caza/recolección y pesca
## no consumen bloques (sus tasas dependen del entorno, ver recalcular_tasas()).
const TIPOS_QUE_CONSUMEN := ["mina", "maderero"]

## Cada cuántas horas de juego se recalculan las tasas de todos los puestos
## según lo que queda en su entorno (árboles, bloques de mina, agua).
const TICKS_RECALCULO := 6

## Las tasas de un puesto usan las claves de Recoleccion.tasas_*(); estas cuatro
## son formas de obtener comida y se suman en el recurso "comida". El resto de
## claves (minerales, "madera") ya son el nombre del recurso.
const RECURSO_DE_TASA := {
	"caza": "comida", "recoleccion": "comida",
	"pesca": "comida", "frutos_mar": "comida",
}

var ciudad: Object = null  # Ciudad
## VoxelWorld, inyectable (Main.gd lo asigna). Sin él los puestos producen sin
## consumir el mundo.
var mundo: Object = null
var zonificacion: Object = null
var vias: Object = null
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

var _factores_energia: Dictionary = {}
var _horas_desde_recalculo := 0

func resumen_energia() -> Dictionary:
	return _ultimo_resumen_energia.duplicate()

func factor_energia_de(esquina: Vector2i) -> float:
	return _factores_energia.get(esquina, 0.0)


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


func _ready() -> void:
	if ciudad == null:
		ciudad = Ciudad
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
	puestos[esquina] = {
		"tipo": tipo, "ancho": ancho, "alto": alto,
		"cupo": Recoleccion.cupo_de(tipo),
		"capacidad": Recoleccion.capacidad_almacen_de(tipo),
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
	}


## Quita el puesto (se deconstruyó): lo que quepa de su almacén local pasa al núcleo
## (el resto se pierde) y sus trabajadores quedan libres; se avisa con puesto_quitado. No-op si no existe.
func quitar_puesto(esquina: Vector2i) -> void:
	if not puestos.has(esquina):
		return
	retirar_deposito(esquina)  # último intento (el stock pudo liberar espacio desde que empezó la deconstrucción)
	var p: Dictionary = puestos[esquina]
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
	if es_escuela(esquina):
		return ["aprendiz"]
	if es_universidad(esquina):
		return ["investigador"]
	if es_refineria(esquina) or (puestos.has(esquina) and puestos[esquina]["tipo"] == "central_termoelectrica"):
		return ["tecnico", "acarreador"]
	return ["recolector", "tecnico", "especialista", "acarreador"]


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
	if es_refineria(esquina):
		var tasas_ref: Dictionary = CadenaMinerales.tasas_refinado({insumo_de(esquina): puestos[esquina]["presentes"].size()})
		for entrada in tasas_ref:
			resultado[tasas_ref[entrada]["tipo_salida"]] = tasas_ref[entrada]["produccion"]
		return resultado
	var p: Dictionary = puestos[esquina]
	var presentes: int = p["presentes"].size()
	var multiplicador: float = Recoleccion.multiplicador_de_nivel(p["tipo"], p["nivel"])
	for clave in p["tasas"]:
		var recurso: String = RECURSO_DE_TASA.get(clave, clave)
		resultado[recurso] = resultado.get(recurso, 0.0) + p["tasas"][clave] * presentes * multiplicador
	return resultado


func almacen_local(esquina: Vector2i) -> Dictionary:
	return puestos[esquina]["almacen"].duplicate() if puestos.has(esquina) else {}


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

	var horas_investigacion := 0.0
	for esquina in puestos:
		var p: Dictionary = puestos[esquina]
		if not p["activo"]:
			continue
		_liberar_acarreadores_si_agotado(esquina)
		if es_universidad(esquina):
			var factor_uni: float = 1.0
			if ciudad != null and ciudad.nivel_investigado + 1 == 3:
				factor_uni = factores_energia.get(esquina, 0.0)
			horas_investigacion += float(p["presentes"].size()) * factor_uni
			continue
		if es_escuela(esquina):
			_formar(esquina)
			continue
		if es_refineria(esquina):
			_refinar(esquina, factores_energia.get(esquina, 0.0))
			continue
		if p["tipo"] == "central_termoelectrica":
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
	if horas_investigacion > 0.0 and ciudad != null:
		ciudad.actualizar_investigacion(horas_investigacion)
	_horas_desde_recalculo += 1
	if _horas_desde_recalculo >= TICKS_RECALCULO:
		_horas_desde_recalculo = 0
		recalcular_todas()


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
	var extraido := 0.0
	while unidades - extraido > 1e-9:
		var actual: Dictionary = p["en_curso"].get(recurso, {})
		if not actual.is_empty() and not _en_curso_valido(actual):
			actual = {}  # el avatar lo derribó o lo minó: se descarta
		if actual.is_empty():
			actual = _siguiente_bloque(p, recurso)
			if actual.is_empty():
				p["en_curso"].erase(recurso)
				break
			p["en_curso"][recurso] = actual
		var tomado: float = minf(unidades - extraido, actual["restante"])
		actual["restante"] -= tomado
		extraido += tomado
		if actual["restante"] <= 1e-9:
			_terminar_bloque(actual)
			p["en_curso"].erase(recurso)
	return extraido


## Bloque de mina o árbol siguiente para "recurso" ({} si no queda ninguno).
func _siguiente_bloque(p: Dictionary, recurso: String) -> Dictionary:
	var entorno: Dictionary = p["entorno"]
	if p["tipo"] == "mina":
		var celda: Vector3i = Recoleccion.siguiente_bloque_mina(mundo, entorno["centro"], entorno["altura"], recurso, Recoleccion.profundidad_de_nivel(p["nivel"]))
		if celda == Recoleccion.SIN_BLOQUE:
			return {}
		return {"tipo": "bloque", "celda": celda, "recurso": recurso, "restante": Recoleccion.rendimiento_de(recurso)}
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
func recoger(esquina: Vector2i, capacidad: float) -> Dictionary:
	if not puestos.has(esquina):
		return {}
	var p: Dictionary = puestos[esquina]
	var total := _total(p["almacen"])
	if total <= 1e-9:
		return {}
	# Carga parcial: solo sin recolectores o si el puesto ya no produce (resto de un área agotada).
	if total < capacidad and not p["presentes"].is_empty() and _total(produccion_por_hora(esquina)) > 0.0:
		return {}
	var carga: Dictionary = {}
	var restante := capacidad
	for recurso in p["almacen"].keys():
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
## que no cabe (stock lleno) se pierde.
func entregar(carga: Dictionary) -> void:
	for recurso in carga:
		if ciudad.almacen.has(recurso):
			ciudad.almacen[recurso].agregar(carga[recurso])


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
	var resultado: Dictionary = CadenaMinerales.procesar_receta(insumo_de(esquina), presentes, 1.0, p["almacen"], factor_energia, float(p["capacidad"]))
	if _total(resultado) > p["capacidad"] + 1e-9:
		return
	for recurso in resultado.keys():
		if resultado[recurso] <= 1e-9:
			resultado.erase(recurso)
	p["almacen"] = resultado


## Qué retiraría ahora un acarreador del stock central para esta refinería: {recurso: cantidad}.
## Cada insumo tiene su tope en el almacén local, repartido en la proporción de la receta (así uno
## no llena el almacén y deja sin sitio al otro), y la carga total no pasa de CAPACIDAD_CARGA ni
## del espacio libre. {} si no es refinería o no hay nada que llevar.
## ponytail: reparto fijo por receta; si el almacén se desbalancea mucho, esto no lo corrige.
func insumos_a_cargar(esquina: Vector2i) -> Dictionary:
	if not puestos.has(esquina):
		return {}
	var p: Dictionary = puestos[esquina]
	if p["tipo"] == "central_termoelectrica":
		var libre_central: float = p["capacidad"] - _total(p["almacen"])
		if libre_central <= 1e-9:
			return {}
		for tipo_comb in ["combustible", "crudo", "carbon"]:
			if ciudad != null and ciudad.almacen.has(tipo_comb) and ciudad.almacen[tipo_comb].cantidad > 1e-9:
				var cant: float = minf(minf(CAPACIDAD_CARGA, libre_central), ciudad.almacen[tipo_comb].cantidad)
				if cant > 1e-9:
					return {tipo_comb: cant}
		return {}
	if not es_refineria(esquina):
		return {}
	var entradas: Dictionary = entradas_de(esquina)
	var suma: float = 0.0
	for recurso in entradas:
		suma += entradas[recurso]
	var plan: Dictionary = {}
	var total: float = 0.0
	for recurso in entradas:
		var parte: float = entradas[recurso] / suma
		var espacio: float = p["capacidad"] * parte - p["almacen"].get(recurso, 0.0)
		var cantidad: float = minf(minf(CAPACIDAD_CARGA * parte, espacio), ciudad.almacen[recurso].cantidad)
		if cantidad > 1e-9:
			plan[recurso] = cantidad
			total += cantidad
	var libre: float = p["capacidad"] - _total(p["almacen"])
	if total > libre:
		for recurso in plan:
			plan[recurso] *= maxf(0.0, libre) / total
	return plan


## Total de unidades de insumos_a_cargar().
func insumo_a_cargar(esquina: Vector2i) -> float:
	return _total(insumos_a_cargar(esquina))


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
func cargar_insumo(esquina: Vector2i) -> Dictionary:
	var carga: Dictionary = {}
	var plan: Dictionary = insumos_a_cargar(esquina)
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
		var cabe: float = minf(carga[recurso], maxf(0.0, p["capacidad"] - _total(p["almacen"])))
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
func recoger_producto(esquina: Vector2i, capacidad: float) -> Dictionary:
	var pendiente: float = producto_pendiente(esquina)
	var tomado: float = minf(pendiente, capacidad)
	if tomado <= 1e-9:
		return {}
	var producto: String = producto_de(esquina)
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
	var local: Dictionary = puestos[esquina]["almacen"]
	var espacio: float = puestos[esquina]["capacidad"] - _total(local)
	if espacio <= 0.0:
		return 0.0
	var salida: float = ciudad.almacen[recurso].quitar(min(espacio, monto))
	if salida <= 1e-9:
		return 0.0
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

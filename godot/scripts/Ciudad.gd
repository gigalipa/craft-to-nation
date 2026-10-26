extends Node

## Autoload "Ciudad": puerto directo de PoC_1 (Python) a GDScript. Motor de
## datos puro (recursos, demografía, investigación, variedad alimentaria,
## sucesión de avatar) — NO lee ni escribe VoxelWorld/Player/BlueprintValidator
## todavía. Ver PoC_4/ para el diseño completo.
##
## Simulación por ticks discretos (como PoC_1), no en tiempo real: un Timer
## interno dispara _avanzar_tick() cada SEGUNDOS_POR_TICK. Las pruebas
## (CiudadTest.gd) llaman a simular_tick() directamente en bucle, sin esperar
## al Timer, igual que PoC_1 llama a simular_tick() en un bucle de Python.

const Ajustes = preload("res://scripts/ajustes.gd")
const Strings = preload("res://scripts/strings.gd")

## Emitida al final de cada simular_tick(); Colonos.gd (Plan 2) la escucha
## para reconciliar los colonos visibles con demografia.
signal tick_simulado
signal nucleo_reasignado(nuevo_id: int, id_viejo: int)
signal traslado_nucleo_programado_cambiado(activo: bool)
signal recurso_escaso_notificado(clave: String)

static var SEGUNDOS_POR_TICK: float = Ajustes.CIUDAD_SEGUNDOS_POR_TICK

## Tipos de población (fuente: docs/Recursos.xlsx, hoja "Relacion"; el Excel
## reemplaza la tabla de roles del GDD Sección 6). "x_cama" es cuántos
## habitantes de ese tipo caben por cama construida: cada cama aporta 1
## unidad de vivienda y una persona ocupa 1 / x_cama de ella (vivienda
## fraccionaria compartida, ver vivienda_ocupada). Solo "comida" se aplica
## hoy; combustible y energía quedan transcritos para el sub-proyecto de
## economía (consumo con eficiencia proporcional). "ciudadano" no tiene
## ninguna fuente todavía (no hay nacimientos ni envejecimiento): los
## colonos llegan como "desempleado".
static var TIPOS_POBLACION: Dictionary = Ajustes.CIUDAD_TIPOS_POBLACION

## Límites de vivienda por nivel EFECTIVO de ciudad (decisión del usuario,
## 2026-09-20): cuántas camas por piso y cuántos pisos puede tener una casa.
## La población máxima es la vivienda real construida, no un tope por nivel.
## Los 12 pisos quedan reservados para el nivel máximo de desarrollo, que
## todavía no existe.
static var NIVELES_VIVIENDA: Dictionary = Ajustes.CIUDAD_NIVELES_VIVIENDA

## A quién se desahucia primero cuando la vivienda ocupada excede la
## capacidad: primero quien no produce. Los últimos tres solo garantizan que
## el bucle de regular_densidad_vertical() siempre termina.
static var ORDEN_DESAHUCIO: Array = Ajustes.CIUDAD_ORDEN_DESAHUCIO

## A quién quita primero la hambruna: militar, obrero y técnico como antes de
## la taxonomía nueva; desempleado y ciudadano al final, porque la migración
## solo produce desempleados y sin ellos una ciudad hambrienta no sufriría
## bajas y nunca se recuperaría.
static var ORDEN_BAJAS_HAMBRUNA: Array = Ajustes.CIUDAD_ORDEN_BAJAS_HAMBRUNA

## Horas de simulación correspondientes a un mes de juego (30 días de 24h)
static var HORAS_POR_MES: float = Ajustes.CIUDAD_HORAS_POR_MES

## Costo de activación por nivel (GDD Sección 7).
static var COSTOS_INVESTIGACION: Dictionary = Ajustes.CIUDAD_COSTOS_INVESTIGACION

## Sofisticación física: tipo de puesto -> nivel de instalación (2 o 3).
static var TIPO_INSTALACION: Dictionary = Ajustes.CIUDAD_TIPO_INSTALACION

static var CATEGORIAS_COMIDA: Array = Ajustes.CIUDAD_CATEGORIAS_COMIDA
## Horas (ticks) que abarca Recurso.tasa_neta_promedio: un acarreador tarda
## ~8-10 h por viaje de ida y vuelta, así que menos de 10 seguiría oscilando.
static var VENTANA_TASA_PROMEDIO: int = Ajustes.CIUDAD_VENTANA_TASA_PROMEDIO
static var BONO_MORAL_MAXIMO: float = Ajustes.CIUDAD_BONO_MORAL_MAXIMO
static var VELOCIDAD_SUAVIZADO_MORAL: float = Ajustes.CIUDAD_VELOCIDAD_SUAVIZADO_MORAL

## Sistema de Moral Dinámica y Población (GDD v3.56)
static var MORAL_INICIAL: float = Ajustes.CIUDAD_MORAL_INICIAL
static var MORAL_NEUTRAL: float = Ajustes.CIUDAD_MORAL_NEUTRAL
static var INERCIA_MORAL: float = Ajustes.CIUDAD_INERCIA_MORAL
static var TOLERANCIA_SIN_TECHO_HORAS: int = Ajustes.CIUDAD_TOLERANCIA_SIN_TECHO_HORAS
static var TOLERANCIA_DESEMPLEO_HORAS: int = Ajustes.CIUDAD_TOLERANCIA_DESEMPLEO_HORAS
static var VENTANA_PELIGRO_HORAS: int = Ajustes.CIUDAD_VENTANA_PELIGRO_HORAS
static var ORDEN_EXODO_MORAL: Array = Ajustes.CIUDAD_ORDEN_EXODO_MORAL
static var TRAMOS_MIGRACION: Array = Ajustes.CIUDAD_TRAMOS_MIGRACION
static var UMBRAL_EXODO_MORAL: float = Ajustes.CIUDAD_UMBRAL_EXODO_MORAL
static var UMBRAL_INMIGRACION_MASIVA: float = Ajustes.CIUDAD_UMBRAL_INMIGRACION_MASIVA
static var MULTIPLICADOR_BOOST_INMIGRACION: float = Ajustes.CIUDAD_MULTIPLICADOR_BOOST_INMIGRACION
static var PRODUCTIVIDAD_BASE: float = Ajustes.CIUDAD_PRODUCTIVIDAD_BASE
static var PRODUCTIVIDAD_EXPONENCIAL_BASE: float = Ajustes.CIUDAD_PRODUCTIVIDAD_EXPONENCIAL_BASE
static var PRODUCTIVIDAD_DIVISOR_MORAL: float = Ajustes.CIUDAD_PRODUCTIVIDAD_DIVISOR_MORAL

## Inventario del avatar = almacén central (ver docs/superpowers/specs/
## 2026-09-24-extraccion-fisica-agotamiento-design.md, Sección 6). Al empezar
## la partida los topes son bajos; declarar el núcleo los duplica y cada baúl
## de un edificio residencial posterior suma un bono. Placeholders de balance.
static var LIMITE_BASE: float = Ajustes.CIUDAD_LIMITE_BASE
static var LIMITE_BASE_COMIDA: float = Ajustes.CIUDAD_LIMITE_BASE_COMIDA
static var FACTOR_NUCLEO: float = Ajustes.CIUDAD_FACTOR_NUCLEO
static var BONO_BAUL: float = Ajustes.CIUDAD_BONO_BAUL
static var BONO_BAUL_COMIDA: float = Ajustes.CIUDAD_BONO_BAUL_COMIDA
## Comida con la que empieza la partida: el tope base (el inventario inicia lleno).
static var COMIDA_INICIAL: float = Ajustes.CIUDAD_COMIDA_INICIAL
static var MADERA_INICIAL: float = Ajustes.CIUDAD_MADERA_INICIAL


class Recurso:
	var nombre: String
	var cantidad: float
	var limite: float
	## Cambio neto de "cantidad" entre el cierre del simular_tick() anterior y
	## el de este (positivo = ganancia, negativo = consumo neto): así incluye lo
	## que llega entre ticks, como las entregas de los acarreadores. Usado por
	## el HUD (lista de recursos).
	var tasa_neta: float = 0.0
	## Media de las últimas VENTANA_TASA_PROMEDIO tasas_netas (horas): suaviza
	## las entregas a tirones de los acarreadores para que el HUD muestre si la
	## relación producción/consumo es positiva. Ver registrar_tasa().
	var tasa_neta_promedio: float = 0.0
	var _historial_tasa: Array[float] = []

	func _init(p_nombre: String, p_cantidad: float, p_limite: float) -> void:
		nombre = p_nombre
		cantidad = max(0.0, p_cantidad)
		limite = p_limite

	## Fija tasa_neta (última hora) y recalcula tasa_neta_promedio.
	func registrar_tasa(tasa: float) -> void:
		tasa_neta = tasa
		_historial_tasa.append(tasa)
		if _historial_tasa.size() > Ajustes.CIUDAD_VENTANA_TASA_PROMEDIO:
			_historial_tasa.pop_front()
		var suma := 0.0
		for t in _historial_tasa:
			suma += t
		tasa_neta_promedio = suma / _historial_tasa.size()

	func agregar(monto: float) -> float:
		var espacio_libre: float = max(0.0, limite - cantidad)
		var ingreso_real: float = min(espacio_libre, monto)
		cantidad += ingreso_real
		return ingreso_real

	## Retira hasta "monto" del stock (nunca más de lo disponible); devuelve
	## lo realmente retirado. Simétrico a agregar(), para transferencias
	## parciales (ver Economia.agregar_deposito()).
	func quitar(monto: float) -> float:
		var salida: float = min(cantidad, monto)
		cantidad -= salida
		return salida

	func consumir(monto: float) -> bool:
		if cantidad >= monto:
			cantidad -= monto
			return true
		return false


## Aislado del Player 3D por ahora (ver diseño de PoC_4): es el mismo modelo
## de datos que PoC_1, no la avatar jugable de VoxelWorld/Player.gd.
class Avatar:
	var ciudad: Node
	var salud := 100.0

	func _init(p_ciudad: Node) -> void:
		ciudad = p_ciudad

	var tasa_hambre: float:
		get:
			var tabla_hambre := {1: 5.0, 2: 4.0, 3: 3.0}
			return tabla_hambre.get(ciudad.nivel, 5.0)

	func aplicar_estado(hambruna_activa: bool) -> void:
		if hambruna_activa:
			salud = max(0.0, salud - 15.0)
		else:
			salud = min(100.0, salud + 2.0)


var instalaciones := {"tipo_1": 0, "tipo_2": 0, "tipo_3": 0}
var instalaciones_edificio: Dictionary = {}  # id_edificio -> int (2 o 3)
var demografia: Dictionary = {}
var almacen: Dictionary = {}
var desahuciados := 0
var nivel_investigado := 1
var progreso_investigacion := {2: 0.0, 3: 0.0}
var fuentes_comida_activas: Dictionary = {}
var sub_almacen_comida: Dictionary = {
	"pesca": 0.0,
	"recoleccion_caza": 0.0,
	"sembradios": 0.0,
	"granjas_animales": 0.0,
	"hidroponia": 0.0,
	"sintetico": 0.0,
}
var bono_moral_variedad := 0.0
var horas_monocultivo_continuo: int = 0
## Estado de Moral Dinámica
var moral: float = MORAL_INICIAL
var tasa_cambio_moral: float = 0.0
var recursos_alertados_5pct: Dictionary = {}
var cola_desempleo: Array[int] = []
var historial_peligrosidad: Array[Dictionary] = []
var bajas_7d: int = 0
var heridos_7d: int = 0
var robos_7d: float = 0.0
var cobertura_energia: float = 1.0
var periodo_elecciones_restante := 0
## Edificios residenciales registrados: id de edificio (el que asigna
## VoxelWorld) -> Array[int] con las camas de CADA piso. Ver
## registrar_edificio_residencial().
var edificios_residenciales: Dictionary = {}
## id de edificio residencial -> cantidad de baúles (cada uno suma al tope del
## almacén, ver recalcular_limites()).
var baules_por_edificio: Dictionary = {}
## true desde que se declara el núcleo urbano (duplica los topes).
var almacen_ampliado := false
var id_nucleo := -1
var camas_nucleo: Array = []
var baules_nucleo := 0
var traslado_nucleo: Dictionary = {}  # {"id": nuevo_id, "horas": 5}
## true mientras el núcleo urbano está en proceso de remodelación
var remodelando_nucleo := false
## Control de colonizabilidad de residenciales (buffers e inmigración)
var primer_residencial_registrado := false
var colonizable_por_edificio: Dictionary = {}  # id -> bool (true = inmigración externa)
var horas_apertura_colonizacion: Dictionary = {}  # id -> int (horas restantes para apertura a inmigrantes)
## Colonos sin techo tras remodelaciones sin camas suficientes
var sin_techo := 0
var tiempo_sin_techo := 0
## Horas de juego transcurridas (1 por simular_tick); reloj de los frutos del avatar.
var horas_juego := 0

## Si es false, simular_tick() no hace llegar colonos (lo usan las pruebas
## que fijan la demografía a mano).
var migracion_activa := true
var _migrantes_acumulados := 0.0
var horas_boost_inmigracion := 0
## Cantidad de cada recurso al cierre del último simular_tick(); base de
## Recurso.tasa_neta (ver simular_tick()).
var _cantidad_al_cierre: Dictionary = {}

var _timer: Timer


func _init() -> void:
	for tipo in TIPOS_POBLACION:
		demografia[tipo] = 0
	almacen = {
		"madera": Recurso.new("Madera", 200, LIMITE_BASE),
		"comida": Recurso.new("Comida", COMIDA_INICIAL, LIMITE_BASE_COMIDA),
		# Recursos que llegan de los puestos y del avatar: empiezan en 0. El
		# hierro no es una excepción (Era 1 Prehistórica: nada procesado
		# todavía) — reportado jugando en vivo, 2026-09-28.
		"hierro": Recurso.new("Hierro", 0, LIMITE_BASE),
		"tierra": Recurso.new("Tierra", 0, LIMITE_BASE),
		"piedra": Recurso.new("Piedra", 0, LIMITE_BASE),
		"cobre": Recurso.new("Cobre", 0, LIMITE_BASE),
		"carbon": Recurso.new("Carbón", 0, LIMITE_BASE),
		"tierras_raras": Recurso.new("Tierras raras", 0, LIMITE_BASE),
		"acero": Recurso.new("Acero", 0, LIMITE_BASE),  # lo produce la siderúrgica (ver Economia.gd)
		"mineral_refinado": Recurso.new("Mineral refinado", 0, LIMITE_BASE),  # refinería de tierras raras
		"tablas": Recurso.new("Tablas", 0, LIMITE_BASE),  # aserradero; cuentan como madera (consumir_costo())
		"bloques_piedra": Recurso.new("Bloques de piedra", 0, LIMITE_BASE),  # fábrica de bloques; cuentan como piedra
		"agua": Recurso.new("Agua", 0, LIMITE_BASE),
		"crudo": Recurso.new("Crudo", 0, LIMITE_BASE),
		"combustible": Recurso.new("Combustible", 0, LIMITE_BASE),
	}
	for categoria in CATEGORIAS_COMIDA:
		fuentes_comida_activas[categoria] = 0.0
	sub_almacen_comida["recoleccion_caza"] = COMIDA_INICIAL * 0.5
	sub_almacen_comida["pesca"] = COMIDA_INICIAL * 0.5


## Cobra "monto" de "recurso" del stock central devolviendo un desglose {recurso: cantidad}
## de lo efectivamente descontado, o {} si no alcanza. Para "madera", cobra primero con tablas
## y el remanente con madera cruda. Para "piedra", cobra primero con bloques_piedra y el remanente con piedra.
func consumir_costo_con_detalle(recurso: String, monto: float) -> Dictionary:
	if recurso == "madera":
		var tablas: Recurso = almacen["tablas"]
		var madera: Recurso = almacen["madera"]
		if tablas.cantidad + madera.cantidad < monto:
			return {}
		var de_tablas: float = minf(tablas.cantidad, monto)
		var de_madera: float = monto - de_tablas
		tablas.cantidad -= de_tablas
		madera.cantidad -= de_madera
		var desglose: Dictionary = {}
		if de_tablas > 0.0:
			desglose["tablas"] = de_tablas
		if de_madera > 0.0:
			desglose["madera"] = de_madera
		return desglose
	elif recurso == "piedra":
		var bloques: Recurso = almacen["bloques_piedra"]
		var piedra: Recurso = almacen["piedra"]
		if bloques.cantidad + piedra.cantidad < monto:
			return {}
		var de_bloques: float = minf(bloques.cantidad, monto)
		var de_piedra: float = monto - de_bloques
		bloques.cantidad -= de_bloques
		piedra.cantidad -= de_piedra
		var desglose: Dictionary = {}
		if de_bloques > 0.0:
			desglose["bloques_piedra"] = de_bloques
		if de_piedra > 0.0:
			desglose["piedra"] = de_piedra
		return desglose
	else:
		if not almacen.has(recurso) or (almacen[recurso] as Recurso).cantidad < monto:
			return {}
		(almacen[recurso] as Recurso).consumir(monto)
		return {recurso: monto}


## Cobra "monto" de "recurso" del stock central (true si alcanzó; false y sin cobrar si no).
## Las tablas cuentan como madera y los bloques de piedra cuentan como piedra.
func consumir_costo(recurso: String, monto: float) -> bool:
	return not consumir_costo_con_detalle(recurso, monto).is_empty()


func ingresar_comida_estratificada(cantidad: float, categoria: String = "recoleccion_caza") -> void:
	if cantidad <= 0.0:
		return
	var cat: String = categoria if sub_almacen_comida.has(categoria) else "recoleccion_caza"
	sub_almacen_comida[cat] = sub_almacen_comida.get(cat, 0.0) + cantidad


func _descontar_comida_estratificada(cantidad_requerida: float) -> bool:
	var restante := cantidad_requerida
	for cat in Ajustes.CIUDAD_ORDEN_CONSUMO_COMIDA:
		var disponible: float = sub_almacen_comida.get(cat, 0.0)
		if disponible <= 0.0:
			continue
		var tomar: float = minf(disponible, restante)
		sub_almacen_comida[cat] -= tomar
		restante -= tomar
		if restante <= 1e-5:
			break

	var exito: bool = (almacen["comida"] as Recurso).consumir(cantidad_requerida)
	if not exito:
		for cat in sub_almacen_comida:
			sub_almacen_comida[cat] = 0.0
	return exito


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = SEGUNDOS_POR_TICK
	_timer.timeout.connect(_on_tick_timeout)
	add_child(_timer)
	_timer.start()


func _on_tick_timeout() -> void:
	var avatar_logico := Avatar.new(self)
	var resultado: Dictionary = simular_tick(avatar_logico.tasa_hambre)
	avatar_logico.aplicar_estado(resultado["hambruna"])


func _suma_dict(diccionario: Dictionary) -> float:
	var total := 0.0
	for valor in diccionario.values():
		total += valor
	return total


var total_instalaciones: int:
	get: return int(_suma_dict(instalaciones))

var censo_total: int:
	get: return int(_suma_dict(demografia)) + sin_techo

var indice_sofisticacion: float:
	get:
		var total: int = total_instalaciones
		if total == 0:
			return 1.0
		var puntos: int = (
			instalaciones["tipo_1"] * 1
			+ instalaciones["tipo_2"] * 2
			+ instalaciones["tipo_3"] * 3
		)
		return float(puntos) / float(total)

## Nivel que el ratio de instalaciones PERMITE, antes de investigación.
var nivel_potencial: int:
	get:
		var idx: float = indice_sofisticacion
		if idx >= Ajustes.CIUDAD_INDICE_SOFISTICACION_NIVEL_3 and instalaciones["tipo_3"] >= Ajustes.CIUDAD_MINIMO_INSTALACIONES_NIVEL:
			return 3
		elif idx >= Ajustes.CIUDAD_INDICE_SOFISTICACION_NIVEL_2 and instalaciones["tipo_2"] >= Ajustes.CIUDAD_MINIMO_INSTALACIONES_NIVEL:
			return 2
		return 1

## Nivel EFECTIVO: el potencial, acotado por lo ya investigado.
var nivel: int:
	get: return min(nivel_potencial, nivel_investigado)

## Camas que cuentan HOY: de cada edificio, solo los pisos que el nivel
## efectivo permite, y de cada piso a lo sumo las camas por piso del nivel.
## Si baja el nivel, los pisos superiores dejan de contar y quien vivía ahí
## se desahucia (GDD Sección 5).
var capacidad_camas_construida: int:
	get:
		var limites: Dictionary = NIVELES_VIVIENDA[nivel]
		var total := 0
		for camas_por_piso: Array in edificios_residenciales.values():
			for i in range(mini(camas_por_piso.size(), limites["pisos"])):
				total += mini(camas_por_piso[i], limites["camas_por_piso"])
		return total

## Capacidad de camas en edificios con colonizabilidad ACTIVA (disponibles para inmigración)
var capacidad_camas_colonizable: int:
	get:
		var limites: Dictionary = NIVELES_VIVIENDA[nivel]
		var total := 0
		for id: int in edificios_residenciales:
			if colonizable_por_edificio.get(id, false):
				var camas_por_piso: Array = edificios_residenciales[id]
				for i in range(mini(camas_por_piso.size(), limites["pisos"])):
					total += mini(camas_por_piso[i], limites["camas_por_piso"])
		return total

## Suma de 1 / x_cama de cada habitante: la vivienda que ocupa la población.
var vivienda_ocupada: float:
	get:
		var total := 0.0
		for tipo in demografia:
			total += float(demografia[tipo]) / float(TIPOS_POBLACION[tipo]["x_cama"])
		return total

var vivienda_libre: float:
	get: return float(capacidad_camas_construida) - vivienda_ocupada

var vivienda_colonizable_libre: float:
	get: return maxf(0.0, float(capacidad_camas_colonizable) - vivienda_ocupada)


## Registra una instalación física completada (tipo 2 o 3) identificada por id_edificio. Idempotente.
func registrar_instalacion(id_edificio: int, tipo_puesto: String) -> void:
	if id_edificio == -1 or not TIPO_INSTALACION.has(tipo_puesto):
		return
	if instalaciones_edificio.has(id_edificio):
		return
	instalaciones_edificio[id_edificio] = TIPO_INSTALACION[tipo_puesto]
	_recalcular_instalaciones()


## Retira una instalación física que empieza a deconstruirse.
func desregistrar_instalacion(id_edificio: int) -> void:
	if instalaciones_edificio.erase(id_edificio):
		_recalcular_instalaciones()


func _recalcular_instalaciones() -> void:
	var conteo := {"tipo_1": 0, "tipo_2": 0, "tipo_3": 0}
	for nivel_inst: int in instalaciones_edificio.values():
		var clave: String = "tipo_%d" % nivel_inst
		conteo[clave] = conteo.get(clave, 0) + 1
	instalaciones = conteo


## Verifica si el stock alcanza para pagar todos los recursos de "costos" {recurso: cantidad}.
## Las tablas cuentan como madera y los bloques de piedra cuentan como piedra.
func puede_pagar(costos: Dictionary) -> bool:
	for recurso in costos:
		if not almacen.has(recurso):
			return false
		var cant: float = (almacen[recurso] as Recurso).cantidad
		if recurso == "madera" and almacen.has("tablas"):
			cant += (almacen["tablas"] as Recurso).cantidad
		elif recurso == "piedra" and almacen.has("bloques_piedra"):
			cant += (almacen["bloques_piedra"] as Recurso).cantidad
		if cant < float(costos[recurso]):
			return false
	return true


## Devuelve un diccionario con las cantidades efectivas de los recursos centrales,
## unificando los recursos procesados equivalentes (tablas cuentan como madera, bloques_piedra como piedra).
func almacen_general() -> Dictionary:
	var resumen: Dictionary = {}
	for clave in almacen:
		resumen[clave] = (almacen[clave] as Recurso).cantidad
	if almacen.has("tablas"):
		resumen["madera"] = resumen.get("madera", 0.0) + (almacen["tablas"] as Recurso).cantidad
	if almacen.has("bloques_piedra"):
		resumen["piedra"] = resumen.get("piedra", 0.0) + (almacen["bloques_piedra"] as Recurso).cantidad
	return resumen


## Cobro atómico: valida primero que alcance para todo el diccionario; si falta
## cualquier recurso, devuelve false sin cobrar nada. Si alcanza, descuenta todo.
func consumir_costos(costos: Dictionary) -> bool:
	if not puede_pagar(costos):
		return false
	for recurso in costos:
		consumir_costo(recurso, float(costos[recurso]))
	return true


## Acumula horas-investigador explícitas y activa el siguiente nivel al completar el umbral.
## Devuelve true solo si se completó y activó la investigación en este llamado.
func actualizar_investigacion(horas: float) -> bool:
	var siguiente: int = nivel_investigado + 1
	if not COSTOS_INVESTIGACION.has(siguiente):
		return false
	var costo: Dictionary = COSTOS_INVESTIGACION[siguiente]
	if nivel_potencial < siguiente:
		return false  # el ratio de instalaciones aún no habilita esta investigación
	if horas <= 0.0:
		return false

	var meta: float = float(costo["horas_investigador"])
	progreso_investigacion[siguiente] = min(meta, progreso_investigacion.get(siguiente, 0.0) + horas)
	if progreso_investigacion[siguiente] >= meta:
		var costos_pago := {"hierro": costo["hierro"], "madera": costo["madera"]}
		if consumir_costos(costos_pago):
			nivel_investigado = siguiente
			return true
	return false


## Calcula el multiplicador continuo de productividad laboral según la moral (0 a 100)
## X = PRODUCTIVIDAD_BASE * PRODUCTIVIDAD_EXPONENCIAL_BASE^(moral / PRODUCTIVIDAD_DIVISOR_MORAL).
## Con valores base: a 0 da 0.5x, a 50 da 1.0x, a 100 da 2.0x.
static func calcular_multiplicador_productividad(p_moral: float) -> float:
	return PRODUCTIVIDAD_BASE * pow(PRODUCTIVIDAD_EXPONENCIAL_BASE, clampf(p_moral, 0.0, 100.0) / PRODUCTIVIDAD_DIVISOR_MORAL)


## Tasa de migración neta mensual (ciudadanos/mes) según tramos escalonados de moral.
## <=20: Éxodo (-5 a -1/mes). 20..50: Inmigración con camas (1 a 3/mes). >50: Inmigración masiva (3 a 5/mes).
static func calcular_tasa_migracion_mensual(p_moral: float) -> float:
	var m: float = clampf(p_moral, 0.0, 100.0)
	for tramo in TRAMOS_MIGRACION:
		if m <= tramo["umbral_moral"]:
			return tramo["tasa_mensual"]
	return 5.0


## Mantiene la cola de desempleados con la demografía real
func sincronizar_desempleados() -> void:
	var cant_real: int = demografia.get("desempleado", 0)
	while cola_desempleo.size() < cant_real:
		cola_desempleo.append(0)
	while cola_desempleo.size() > cant_real:
		cola_desempleo.pop_back()


## Registra eventos para el buffer móvil de peligrosidad de 168h
func registrar_baja_seguridad(cantidad: int = 1) -> void:
	if historial_peligrosidad.is_empty():
		historial_peligrosidad.append({"bajas": 0, "heridos": 0, "robos": 0.0})
	historial_peligrosidad[historial_peligrosidad.size() - 1]["bajas"] += cantidad
	_recalcular_peligrosidad_7d()


func registrar_herido_seguridad(cantidad: int = 1) -> void:
	if historial_peligrosidad.is_empty():
		historial_peligrosidad.append({"bajas": 0, "heridos": 0, "robos": 0.0})
	historial_peligrosidad[historial_peligrosidad.size() - 1]["heridos"] += cantidad
	_recalcular_peligrosidad_7d()


func registrar_robo_seguridad(monto: float) -> void:
	if historial_peligrosidad.is_empty():
		historial_peligrosidad.append({"bajas": 0, "heridos": 0, "robos": 0.0})
	historial_peligrosidad[historial_peligrosidad.size() - 1]["robos"] += monto
	_recalcular_peligrosidad_7d()


func _recalcular_peligrosidad_7d() -> void:
	bajas_7d = 0
	heridos_7d = 0
	robos_7d = 0.0
	for entrada: Dictionary in historial_peligrosidad:
		bajas_7d += entrada.get("bajas", 0)
		heridos_7d += entrada.get("heridos", 0)
		robos_7d += entrada.get("robos", 0.0)



func puede_activar_boost_inmigracion() -> bool:
	if horas_boost_inmigracion > 0:
		return false
	return calcular_tasa_migracion_mensual(moral) > 0.0


func activar_boost_inmigracion() -> bool:
	if not puede_activar_boost_inmigracion():
		return false
	horas_boost_inmigracion = int(HORAS_POR_MES)
	return true


func dias_boost_inmigracion_restantes() -> int:
	return int(ceil(float(horas_boost_inmigracion) / 24.0))


func tasa_migracion_mensual_efectiva() -> float:
	var base: float = calcular_tasa_migracion_mensual(moral)
	if base > 0.0 and horas_boost_inmigracion > 0:
		return base * MULTIPLICADOR_BOOST_INMIGRACION
	return base


func actualizar_fuentes_comida_desde_economia() -> void:
	for cat in CATEGORIAS_COMIDA:
		if not fuentes_comida_activas.has(cat):
			fuentes_comida_activas[cat] = 0.0
	if Economia != null and "puestos" in Economia:
		for p in Economia.puestos.values():
			if not p.get("activo", false):
				continue
			var tipo: String = p.get("tipo", "")
			if tipo == "caza_recoleccion":
				fuentes_comida_activas["recoleccion_caza"] = maxf(fuentes_comida_activas.get("recoleccion_caza", 0.0), 1.0)
			elif tipo == "pesca_frutos_mar":
				fuentes_comida_activas["pesca"] = maxf(fuentes_comida_activas.get("pesca", 0.0), 1.0)

func impacto_peligrosidad_7d() -> float:
	return 0.5 * float(bajas_7d) + 0.1 * float(heridos_7d) + 0.005 * robos_7d


func fuentes_comida_en_reserva() -> int:
	var c := 0
	for cat in sub_almacen_comida:
		if sub_almacen_comida[cat] > 0.0:
			c += 1
	return c


func delta_dieta_actual() -> float:
	var activas: int = fuentes_comida_en_reserva()
	if activas == 0:
		return 0.0
	if activas == 1:
		if horas_monocultivo_continuo > Ajustes.CIUDAD_GRACIA_MONOCULTIVO_HORAS:
			return Ajustes.CIUDAD_PENALIZACION_MONOCULTIVO_MORAL
		return 0.0
	if activas <= 3:
		return Ajustes.CIUDAD_BONO_DIETA_2_3_FUENTES
	if activas <= 5:
		return Ajustes.CIUDAD_BONO_DIETA_4_5_FUENTES
	return Ajustes.CIUDAD_BONO_DIETA_6_FUENTES


func actualizar_bono_variedad() -> void:
	var activas: int = fuentes_comida_en_reserva()
	if activas == 1:
		horas_monocultivo_continuo += 1
	elif activas > 1:
		horas_monocultivo_continuo = 0
	bono_moral_variedad = delta_dieta_actual()


## Desahucia, de uno en uno y en ORDEN_DESAHUCIO, hasta que la vivienda
## ocupada cabe en la capacidad construida (tolerancia 1e-6 por los
## flotantes de las fracciones).
func regular_densidad_vertical() -> void:
	var capacidad := float(capacidad_camas_construida)
	while vivienda_ocupada > capacidad + 1e-6:
		var desahuciado := false
		for tipo in ORDEN_DESAHUCIO:
			if demografia[tipo] > 0:
				demografia[tipo] -= 1
				desahuciados += 1
				desahuciado = true
				break
		if not desahuciado:
			break


## Mueve un habitante de un tipo de población a otro (p. ej. desempleado ->
## obrero al asignarlo a un puesto). Falso, sin cambios, si no queda ninguno
## del tipo de origen.
func reasignar_tipo(de: String, a: String) -> bool:
	if demografia[de] <= 0:
		return false
	demografia[de] -= 1
	demografia[a] += 1
	if de == "desempleado" and not cola_desempleo.is_empty():
		cola_desempleo.pop_back()
	elif a == "desempleado":
		cola_desempleo.append(0)
	return true


## Registra un edificio residencial completo (ver
## Player.gd::_completar_construccion). "id" es el id de edificio de
## VoxelWorld y "camas_por_piso" las camas de cada piso, en orden. Idempotente
## por id: registrar dos veces el mismo edificio (p. ej. al deconstruirlo y
## volver a completarlo) no duplica sus camas.
func registrar_edificio_residencial(id: int, camas_por_piso: Array, baules: int = 0) -> void:
	var es_nuevo: bool = not edificios_residenciales.has(id)
	edificios_residenciales[id] = camas_por_piso.duplicate()
	baules_por_edificio[id] = baules
	if es_nuevo and not colonizable_por_edificio.has(id):
		if not primer_residencial_registrado:
			primer_residencial_registrado = true
			colonizable_por_edificio[id] = true
		else:
			colonizable_por_edificio[id] = false
			horas_apertura_colonizacion[id] = 24
	recalcular_limites()
	# Si había colonos sin techo y ahora hay camas libres, se reincorporan como desempleados
	var espacio_minimo: float = 1.0 / float(TIPOS_POBLACION["desempleado"]["x_cama"])
	while sin_techo > 0 and vivienda_libre >= espacio_minimo - 1e-6:
		sin_techo -= 1
		demografia["desempleado"] += 1
		cola_desempleo.append(0)
	if sin_techo == 0:
		tiempo_sin_techo = 0


## Retira las camas de un edificio residencial que empieza a deconstruirse
## (ver Player.gd::_procesar_deconstruccion) — simétrica a
## registrar_edificio_residencial(). Se llama al INICIAR la deconstrucción de
## un edificio ya terminado (no al completarla): un colono no debería poder
## "vivir" en una cama que ya está siendo desmontada. Un id desconocido no
## hace nada.
func retirar_edificio_residencial(id: int) -> void:
	edificios_residenciales.erase(id)
	baules_por_edificio.erase(id)
	colonizable_por_edificio.erase(id)
	horas_apertura_colonizacion.erase(id)
	recalcular_limites()


## Consulta si el edificio residencial permite actualmente inmigración externa.
func es_colonizable(id: int) -> bool:
	return colonizable_por_edificio.get(id, false)


## Horas de juego restantes para apertura automática de colonización.
func horas_colonizacion_restantes(id: int) -> int:
	return horas_apertura_colonizacion.get(id, 0)


## Alterna manualmente el estado de colonizabilidad de un edificio residencial.
func alternar_colonizable(id: int) -> void:
	if not edificios_residenciales.has(id):
		return
	var actual: bool = colonizable_por_edificio.get(id, false)
	colonizable_por_edificio[id] = not actual
	horas_apertura_colonizacion.erase(id)


## Calcula cuántos colonos quedarían sin techo si se remodela el edificio "id".
func calcular_sin_techo_al_remodelar(id: int) -> int:
	if id == id_nucleo or not edificios_residenciales.has(id):
		return 0
	var limites: Dictionary = NIVELES_VIVIENDA[nivel]
	var camas_perdidas := 0
	var c_edificio: Array = edificios_residenciales[id]
	for i in range(mini(c_edificio.size(), limites["pisos"])):
		camas_perdidas += mini(c_edificio[i], limites["camas_por_piso"])
	var nueva_capacidad: float = float(capacidad_camas_construida - camas_perdidas)
	var exceso: float = maxf(0.0, vivienda_ocupada - nueva_capacidad)
	if exceso <= 1e-6:
		return 0
	var cont := 0
	var occ := vivienda_ocupada
	var demo_temp: Dictionary = demografia.duplicate()
	while occ > nueva_capacidad + 1e-6:
		var quitado := false
		for tipo in ORDEN_DESAHUCIO:
			if demo_temp[tipo] > 0:
				demo_temp[tipo] -= 1
				occ -= 1.0 / float(TIPOS_POBLACION[tipo]["x_cama"])
				cont += 1
				quitado = true
				break
		if not quitado:
			break
	return cont


## Inicia la remodelación cívica de un edificio: el núcleo no desaloja; en residenciales
## reubica residentes en camas libres (incluso buffers) y pasa el exceso a "sin techo".
func iniciar_remodelacion_residencial(id: int) -> Dictionary:
	if id == id_nucleo:
		remodelando_nucleo = true
		id_nucleo = -1
		camas_nucleo.clear()
		baules_nucleo = 0
		return {"exito": true, "es_nucleo": true, "sin_techo_generados": 0}
	if not edificios_residenciales.has(id):
		return {"exito": false, "motivo": Strings.CIUDAD_ERR_NO_RESIDENCIAL_NI_NUCLEO}

	var limites: Dictionary = NIVELES_VIVIENDA[nivel]
	var camas_perdidas := 0
	var c_edificio: Array = edificios_residenciales[id]
	for i in range(mini(c_edificio.size(), limites["pisos"])):
		camas_perdidas += mini(c_edificio[i], limites["camas_por_piso"])
	var nueva_capacidad: float = float(capacidad_camas_construida - camas_perdidas)

	var nuevos_sin_techo := 0
	while vivienda_ocupada > nueva_capacidad + 1e-6:
		var desahuciado := false
		for tipo in ORDEN_DESAHUCIO:
			if demografia[tipo] > 0:
				demografia[tipo] -= 1
				sin_techo += 1
				nuevos_sin_techo += 1
				desahuciado = true
				break
		if not desahuciado:
			break

	retirar_edificio_residencial(id)
	return {"exito": true, "es_nucleo": false, "sin_techo_generados": nuevos_sin_techo}


## Se declaró el núcleo urbano: los topes del almacén se duplican. Idempotente.
func ampliar_almacen() -> void:
	almacen_ampliado = true
	recalcular_limites()


func guardar_datos_nucleo(id: int, camas: Array, baules: int) -> void:
	id_nucleo = id
	camas_nucleo = camas.duplicate()
	baules_nucleo = baules


func camas_de(id: int) -> int:
	if id == id_nucleo:
		var c := 0
		for cant in camas_nucleo:
			c += cant
		return c
	if edificios_residenciales.has(id):
		var c := 0
		for cant in edificios_residenciales[id]:
			c += cant
		return c
	return 0


func camas_efectivas_de(id: int) -> int:
	if id == id_nucleo or not edificios_residenciales.has(id):
		return 0
	var limites: Dictionary = NIVELES_VIVIENDA[nivel]
	var c := 0
	var c_edificio: Array = edificios_residenciales[id]
	for i in range(mini(c_edificio.size(), limites["pisos"])):
		c += mini(c_edificio[i], limites["camas_por_piso"])
	return c


func baules_de(id: int) -> int:
	if id == id_nucleo:
		return baules_nucleo
	return baules_por_edificio.get(id, 0)


func programar_traslado_nucleo(nuevo_id: int, horas: int = Ajustes.CIUDAD_HORAS_TRASLADO_NUCLEO) -> void:
	traslado_nucleo = {"id": nuevo_id, "horas": horas}
	traslado_nucleo_programado_cambiado.emit(true)


func cancelar_traslado_nucleo() -> void:
	traslado_nucleo = {}
	traslado_nucleo_programado_cambiado.emit(false)


func esta_traslado_programado(edificio_id: int) -> bool:
	return not traslado_nucleo.is_empty() and traslado_nucleo.get("id", -1) == edificio_id


func horas_traslado_programado() -> int:
	return traslado_nucleo.get("horas", 0)


func calcular_deficit_traslado(nuevo_id: int) -> float:
	var limites: Dictionary = NIVELES_VIVIENDA[nivel]
	var camas_perdidas := 0
	var camas_ganadas := 0
	var c_nuevo: Array = edificios_residenciales.get(nuevo_id, [])
	for i in range(mini(c_nuevo.size(), limites["pisos"])):
		camas_perdidas += mini(c_nuevo[i], limites["camas_por_piso"])
	for i in range(mini(camas_nucleo.size(), limites["pisos"])):
		camas_ganadas += mini(camas_nucleo[i], limites["camas_por_piso"])
	var nueva_capacidad: float = float(capacidad_camas_construida - camas_perdidas + camas_ganadas)
	return maxf(0.0, vivienda_ocupada - nueva_capacidad)


## Reasigna el núcleo urbano a un nuevo edificio residencial.
func reasignar_nucleo(nuevo_id: int) -> void:
	var id_viejo: int = id_nucleo
	var camas_del_nuevo: Array = edificios_residenciales.get(nuevo_id, []).duplicate()
	var baules_del_nuevo: int = baules_por_edificio.get(nuevo_id, 0)

	retirar_edificio_residencial(nuevo_id)

	if id_viejo != -1 and not camas_nucleo.is_empty():
		registrar_edificio_residencial(id_viejo, camas_nucleo, baules_nucleo)

	id_nucleo = nuevo_id
	camas_nucleo = camas_del_nuevo
	baules_nucleo = baules_del_nuevo

	regular_densidad_vertical()
	nucleo_reasignado.emit(nuevo_id, id_viejo)
	recalcular_limites()


## tope = base x (FACTOR_NUCLEO si el núcleo está declarado) + baúles x bono.
## Si el tope baja por debajo del stock (se deconstruyó un edificio), el stock
## se conserva y simplemente no entra nada nuevo (ver Recurso.agregar()).
func recalcular_limites() -> void:
	var factor: float = FACTOR_NUCLEO if almacen_ampliado else 1.0
	var baules := 0
	for cantidad in baules_por_edificio.values():
		baules += cantidad
	for clave in almacen:
		var comida: bool = clave == "comida"
		var base: float = LIMITE_BASE_COMIDA if comida else LIMITE_BASE
		var bono: float = BONO_BAUL_COMIDA if comida else BONO_BAUL
		(almacen[clave] as Recurso).limite = base * factor + baules * bono


## Aplica la sucesión del avatar tras su muerte (GDD Sección 9).
func suceder_avatar() -> String:
	if censo_total == 0:
		return "game_over"
	if demografia["militar"] <= 0:
		return "sin_sucesor_elegible"

	demografia["militar"] -= 1
	periodo_elecciones_restante = 5  # ticks de penalización de liderazgo
	return "sucesion_exitosa"


## Devuelve la clave de almacen (una de las 9 del almacén) con la tasa neta más
## negativa (promedio de las últimas horas) — el recurso en mayor déficit ahora mismo. Si
## ninguno está en déficit, igual devuelve el de tasa más baja (puede ser 0
## o positiva); el HUD decide cómo mostrarlo (ver Ciudad.recurso_critico()).
func recurso_critico() -> String:
	var peor_clave := ""
	var peor_tasa := INF
	for clave in almacen:
		var tasa: float = (almacen[clave] as Recurso).tasa_neta_promedio
		if tasa < peor_tasa:
			peor_tasa = tasa
			peor_clave = clave
	return peor_clave


## Acumula TASA_MIGRACION y hace llegar desempleados mientras haya vivienda
## para ellos y no haya hambruna. Devuelve cuántos llegaron. Nunca guarda más
## de 1 en el acumulador: sin esto, tras un bloqueo largo entraría una ráfaga
## de golpe al liberarse espacio.
## ponytail: sin cola de migrantes; si el diseño pide una "bolsa" de
## migrantes en espera, sustituir el tope de 1 por un contador real.
## Acumula movimiento migratorio y modula la población según la moral (umbral 20).
## Si moral <= 20.0: Éxodo poblacional escalonado con fuga de cerebros (investigador > especialista > ... > obrero).
## Si moral > 20.0 y <= 50.0: Inmigración solo si hay camas disponibles (no genera sin techo).
## Si moral > 50.0: Inmigración masiva que desborda a sin techo si hay núcleo urbano.
func _migrar(hambruna: bool) -> int:
	if not migracion_activa:
		return 0

	var tasa_mensual: float = calcular_tasa_migracion_mensual(moral)
	var tasa_horaria: float = tasa_mensual / HORAS_POR_MES

	# 1. Éxodo por desesperanza (Moral <= 20.0, tasa_horaria < 0)
	if tasa_horaria < 0.0:
		_migrantes_acumulados += tasa_horaria
		var salidos := 0
		while _migrantes_acumulados <= -1.0:
			var expulsado := false
			for rol in ORDEN_EXODO_MORAL:
				if demografia.get(rol, 0) > 0:
					demografia[rol] -= 1
					desahuciados += 1
					expulsado = true
					salidos += 1
					break
			if not expulsado:
				if sin_techo > 0:
					sin_techo -= 1
					desahuciados += 1
					salidos += 1
					expulsado = true
			_migrantes_acumulados += 1.0
			if not expulsado:
				_migrantes_acumulados = 0.0
				break
		sincronizar_desempleados()
		return -salidos

	# 2. Inmigración (Moral > UMBRAL_EXODO_MORAL, tasa_horaria > 0)
	var mult_boost: float = MULTIPLICADOR_BOOST_INMIGRACION if horas_boost_inmigracion > 0 else 1.0
	_migrantes_acumulados += tasa_horaria * mult_boost
	var llegados := 0
	var espacio_minimo: float = 1.0 / float(TIPOS_POBLACION["desempleado"]["x_cama"])
	var solo_con_camas: bool = (moral <= UMBRAL_INMIGRACION_MASIVA) and (horas_boost_inmigracion <= 0)
	while _migrantes_acumulados >= 1.0:
		if hambruna:
			_migrantes_acumulados = 1.0
			break
		if vivienda_colonizable_libre >= espacio_minimo - 1e-6:
			demografia["desempleado"] += 1
			cola_desempleo.append(0)
			llegados += 1
			_migrantes_acumulados -= 1.0
		elif not solo_con_camas and id_nucleo != -1:
			# Inmigración masiva (moral > UMBRAL_INMIGRACION_MASIVA): desborda a sin techo si hay núcleo urbano
			sin_techo += 1
			llegados += 1
			_migrantes_acumulados -= 1.0
		else:
			# Con moral <= UMBRAL_INMIGRACION_MASIVA o sin núcleo, no entra sin cama disponible
			_migrantes_acumulados = 1.0
			break
	sincronizar_desempleados()
	return llegados


## Ejecuta un ciclo horario verificando alimentación, habitabilidad, desempleo e investigación.
func simular_tick(avatar_consumo: float) -> Dictionary:
	# tasa_neta se mide entre cierres de tick consecutivos, no dentro de un
	# tick: así incluye lo que se agrega entre ticks (entregas de acarreadores).
	# El primer tick no tiene cierre previo y usa la cantidad con la que empieza.
	var referencia: Dictionary = _cantidad_al_cierre.duplicate()
	if referencia.is_empty():
		for clave in almacen:
			referencia[clave] = (almacen[clave] as Recurso).cantidad

	if not traslado_nucleo.is_empty():
		traslado_nucleo["horas"] -= 1
		if traslado_nucleo["horas"] <= 0:
			var destino: int = traslado_nucleo["id"]
			traslado_nucleo = {}
			traslado_nucleo_programado_cambiado.emit(false)
			reasignar_nucleo(destino)

	# Actualizar cuentas regresivas de 24h para apertura de colonizabilidad
	var expirados_col: Array[int] = []
	for ed_id: int in horas_apertura_colonizacion:
		horas_apertura_colonizacion[ed_id] -= 1
		if horas_apertura_colonizacion[ed_id] <= 0:
			expirados_col.append(ed_id)
	for ed_id in expirados_col:
		horas_apertura_colonizacion.erase(ed_id)
		colonizable_por_edificio[ed_id] = true

	# Temporizador de 72h para colonos sin techo (tolerancia ampliada de 3 días)
	if sin_techo > 0:
		tiempo_sin_techo += 1
		if tiempo_sin_techo >= TOLERANCIA_SIN_TECHO_HORAS:
			desahuciados += sin_techo
			moral = maxf(0.0, moral - 10.0)
			bono_moral_variedad = maxf(-15.0, bono_moral_variedad - 10.0)
			sin_techo = 0
			tiempo_sin_techo = 0
	else:
		tiempo_sin_techo = 0

	# Temporizador de desempleo de 10 días (240 horas de juego)
	sincronizar_desempleados()
	var i_des := 0
	while i_des < cola_desempleo.size():
		cola_desempleo[i_des] += 1
		if cola_desempleo[i_des] >= TOLERANCIA_DESEMPLEO_HORAS:
			cola_desempleo.remove_at(i_des)
			demografia["desempleado"] -= 1
			desahuciados += 1
		else:
			i_des += 1

	regular_densidad_vertical()
	actualizar_bono_variedad()

	var gasto_poblacion := 0.0
	for tipo in demografia:
		gasto_poblacion += demografia[tipo] * TIPOS_POBLACION[tipo]["comida"]
	gasto_poblacion += sin_techo * TIPOS_POBLACION["desempleado"]["comida"]
	var gasto_total: float = gasto_poblacion + avatar_consumo

	if periodo_elecciones_restante > 0:
		gasto_total *= 1.10
		periodo_elecciones_restante -= 1

	var exito_comida: bool = _descontar_comida_estratificada(gasto_total)

	var bajas_inanicion := 0
	if not exito_comida:
		bajas_inanicion = max(1, int(censo_total * 0.25))
		(almacen["comida"] as Recurso).cantidad = 0.0
		for rol in ORDEN_BAJAS_HAMBRUNA:
			if demografia[rol] > 0 and bajas_inanicion > 0:
				var quitar: int = min(demografia[rol], bajas_inanicion)
				demografia[rol] -= quitar
				bajas_inanicion -= quitar

	# Buffer móvil de 168 horas (7 días) de peligrosidad
	historial_peligrosidad.append({"bajas": 0, "heridos": 0, "robos": 0.0})
	if historial_peligrosidad.size() > VENTANA_PELIGRO_HORAS:
		historial_peligrosidad.pop_front()
	_recalcular_peligrosidad_7d()

	# Dinámica temporal de Moral (tasa horaria delta_M)
	var total_ciu: int = censo_total
	var delta_inercia: float = (MORAL_NEUTRAL - moral) * INERCIA_MORAL
	var delta_escasez := 0.0
	var todos_positivos := true
	var hay_consumo_activo := false

	# Comida (recurso crítico principal)
	var com_rec: Recurso = almacen.get("comida")
	if com_rec != null:
		hay_consumo_activo = true
		var cap_c: float = com_rec.limite if com_rec.limite > 0.0 else Ajustes.CIUDAD_LIMITE_BASE_COMIDA
		var f_c: float = clampf(com_rec.cantidad / cap_c, 0.0, 1.0)
		if not exito_comida or com_rec.cantidad <= 0.0:
			delta_escasez -= Ajustes.CIUDAD_PESO_ESCASEZ_COMIDA
			todos_positivos = false
		elif f_c >= Ajustes.CIUDAD_UMBRAL_COMIDA_SUPERAVIT:
			# Superávit (>=90%): no hay penalización y cuenta como positivo
			pass
		elif f_c >= Ajustes.CIUDAD_UMBRAL_COMIDA_ESTABLE:
			# Estable (80%-90%): neutral ante tasas negativas
			if com_rec.tasa_neta_promedio < 0.0:
				todos_positivos = false
		else:
			# Escasez (<80%): penaliza si la tasa es negativa según autonomía y déficit
			if com_rec.tasa_neta_promedio < 0.0:
				todos_positivos = false
				var horas_autonomia: float = com_rec.cantidad / absf(com_rec.tasa_neta_promedio)
				var def_c: float = (Ajustes.CIUDAD_UMBRAL_COMIDA_ESTABLE - f_c) / Ajustes.CIUDAD_UMBRAL_COMIDA_ESTABLE
				if horas_autonomia < Ajustes.CIUDAD_HORAS_AUTONOMIA_ALARMA:
					var urg: float = 1.0 - (horas_autonomia / Ajustes.CIUDAD_HORAS_AUTONOMIA_ALARMA)
					delta_escasez -= Ajustes.CIUDAD_PESO_ESCASEZ_COMIDA * (0.5 * def_c + 0.5 * urg)
				else:
					var tasa_rel: float = absf(com_rec.tasa_neta_promedio) / cap_c
					delta_escasez -= clampf(Ajustes.CIUDAD_PESO_ESCASEZ_COMIDA * def_c * minf(1.0, tasa_rel * 20.0), 0.1, 1.5)

	if cobertura_energia < 1.0:
		delta_escasez -= 1.5 * (1.0 - cobertura_energia)
		todos_positivos = false

	# Recursos no críticos (Madera, Piedra, etc.)
	for clave in almacen:
		if clave == "comida":
			continue
		var rec: Recurso = almacen[clave]
		var cap_r: float = rec.limite if rec.limite > 0.0 else Ajustes.CIUDAD_LIMITE_BASE
		var f_r: float = clampf(rec.cantidad / cap_r, 0.0, 1.0)
		if rec.tasa_neta_promedio < 0.0 or (rec.cantidad <= 0.0 and rec.tasa_neta < 0.0):
			hay_consumo_activo = true
			todos_positivos = false
			if rec.cantidad <= 0.0:
				delta_escasez -= 0.4
			elif f_r < 0.80:
				var def_r: float = (0.80 - f_r) / 0.80
				var tasa_rel_r: float = absf(rec.tasa_neta_promedio) / cap_r
				var pen_r: float = 0.5 * def_r * minf(1.0, tasa_rel_r * 10.0)
				delta_escasez -= clampf(pen_r, 0.05, 0.4)

	# Notificaciones de recursos bajos (<5%) con histéresis (>15%)
	for clave in almacen:
		var rec_notif: Recurso = almacen[clave]
		var cap_notif: float = rec_notif.limite if rec_notif.limite > 0.0 else Ajustes.CIUDAD_LIMITE_BASE
		var f_notif: float = clampf(rec_notif.cantidad / cap_notif, 0.0, 1.0)
		if f_notif < Ajustes.CIUDAD_UMBRAL_NOTIF_RECURSO_BAJO:
			if not recursos_alertados_5pct.get(clave, false):
				recursos_alertados_5pct[clave] = true
				recurso_escaso_notificado.emit(clave)
		elif f_notif > Ajustes.CIUDAD_UMBRAL_REARME_RECURSO_BAJO:
			if recursos_alertados_5pct.get(clave, false):
				recursos_alertados_5pct[clave] = false

	var delta_abundancia := 0.0
	if total_ciu > 0:
		var com_rec_ab: Recurso = almacen.get("comida")
		var f_c_ab: float = (com_rec_ab.cantidad / com_rec_ab.limite) if (com_rec_ab != null and com_rec_ab.limite > 0.0) else 0.0
		if com_rec_ab != null and f_c_ab >= Ajustes.CIUDAD_UMBRAL_COMIDA_SUPERAVIT:
			delta_abundancia = Ajustes.CIUDAD_BONO_SUPERAVIT_COMIDA
		elif hay_consumo_activo and todos_positivos:
			delta_abundancia = Ajustes.CIUDAD_BONO_SUPERAVIT_COMIDA

	if horas_boost_inmigracion > 0:
		horas_boost_inmigracion -= 1
	var delta_dieta: float = delta_dieta_actual() if total_ciu > 0 else 0.0
	bono_moral_variedad = delta_dieta
	var delta_sin_techo: float = -0.05 * float(sin_techo)
	var delta_peligro: float = -impacto_peligrosidad_7d()

	var delta_empleo := 0.0
	if total_ciu > 0:
		var ocupados: int = total_ciu - demografia.get("desempleado", 0) - sin_techo
		var tasa_empleo: float = float(ocupados) / float(total_ciu)
		delta_empleo = (tasa_empleo - 0.5) * 0.3

	tasa_cambio_moral = delta_inercia + delta_abundancia + delta_escasez + delta_dieta + delta_sin_techo + delta_peligro + delta_empleo
	moral = clampf(moral + tasa_cambio_moral / 24.0, 0.0, 100.0)

	var migrantes: int = _migrar(not exito_comida)

	for clave in almacen:
		var recurso: Recurso = almacen[clave]
		recurso.registrar_tasa(recurso.cantidad - float(referencia[clave]))
		_cantidad_al_cierre[clave] = recurso.cantidad

	var resultado := {
		"gasto_comida": gasto_total,
		"hambruna": not exito_comida,
		"bajas": bajas_inanicion,
		"nivel_ciudad": nivel,
		"nivel_potencial": nivel_potencial,
		"bono_moral_variedad": snapped(bono_moral_variedad, 0.01),
		"moral": snapped(moral, 0.1),
		"tasa_cambio_moral": snapped(tasa_cambio_moral, 0.01),
		"multiplicador_productividad": calcular_multiplicador_productividad(moral),
		"migrantes": migrantes,
	}
	horas_juego += 1
	tick_simulado.emit()
	return resultado


## Devuelve datos del recurso crítico en mayor urgencia si tiene tasa negativa
## y autonomía < CIUDAD_HORAS_AUTONOMIA_ALARMA (72 h):
## {"recurso": clave, "horas": horas_autonomia, "cantidad": cant, "tasa": tasa}
## o {} si ninguno está en crisis.
func recurso_critico_urgente() -> Dictionary:
	var peor: Dictionary = {}
	var min_horas: float = 999999.0

	var com: Recurso = almacen.get("comida")
	if com != null and com.tasa_neta_promedio < -1e-6:
		var cap_c: float = com.limite if com.limite > 0.0 else Ajustes.CIUDAD_LIMITE_BASE_COMIDA
		if (com.cantidad / cap_c) < Ajustes.CIUDAD_UMBRAL_COMIDA_ESTABLE:
			var h_c: float = com.cantidad / absf(com.tasa_neta_promedio)
			if h_c < Ajustes.CIUDAD_HORAS_AUTONOMIA_ALARMA:
				min_horas = h_c
				peor = {"recurso": "comida", "horas": h_c, "cantidad": com.cantidad, "tasa": com.tasa_neta_promedio}

	for comb_nom in ["carbon", "combustible"]:
		var rec: Recurso = almacen.get(comb_nom)
		if rec != null and rec.tasa_neta_promedio < -1e-6:
			var cap_comb: float = rec.limite if rec.limite > 0.0 else Ajustes.CIUDAD_LIMITE_BASE
			if (rec.cantidad / cap_comb) < Ajustes.CIUDAD_UMBRAL_COMIDA_ESTABLE:
				var h_comb: float = rec.cantidad / absf(rec.tasa_neta_promedio)
				if h_comb < Ajustes.CIUDAD_HORAS_AUTONOMIA_ALARMA and h_comb < min_horas:
					min_horas = h_comb
					peor = {"recurso": comb_nom, "horas": h_comb, "cantidad": rec.cantidad, "tasa": rec.tasa_neta_promedio}

	return peor

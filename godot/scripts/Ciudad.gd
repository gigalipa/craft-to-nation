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

## Emitida al final de cada simular_tick(); Colonos.gd (Plan 2) la escucha
## para reconciliar los colonos visibles con demografia.
signal tick_simulado

const SEGUNDOS_POR_TICK := 2.0

## Tipos de población (fuente: docs/Recursos.xlsx, hoja "Relacion"; el Excel
## reemplaza la tabla de roles del GDD Sección 6). "x_cama" es cuántos
## habitantes de ese tipo caben por cama construida: cada cama aporta 1
## unidad de vivienda y una persona ocupa 1 / x_cama de ella (vivienda
## fraccionaria compartida, ver vivienda_ocupada). Solo "comida" se aplica
## hoy; combustible y energía quedan transcritos para el sub-proyecto de
## economía (consumo con eficiencia proporcional). "ciudadano" no tiene
## ninguna fuente todavía (no hay nacimientos ni envejecimiento): los
## colonos llegan como "desempleado".
const TIPOS_POBLACION := {
	"ciudadano": {"comida": 2, "combustible": 0, "energia": 0, "x_cama": 4},
	"desempleado": {"comida": 3, "combustible": 0, "energia": 0, "x_cama": 4},
	"obrero": {"comida": 5, "combustible": 0, "energia": 0, "x_cama": 4},
	"tecnico": {"comida": 3, "combustible": 0, "energia": 0, "x_cama": 3},
	"especialista": {"comida": 2, "combustible": 1, "energia": 1, "x_cama": 2},
	"investigador": {"comida": 1, "combustible": 0, "energia": 2, "x_cama": 1},
	"militar": {"comida": 4, "combustible": 3, "energia": 0, "x_cama": 3},
}

## Límites de vivienda por nivel EFECTIVO de ciudad (decisión del usuario,
## 2026-09-20): cuántas camas por piso y cuántos pisos puede tener una casa.
## La población máxima es la vivienda real construida, no un tope por nivel.
## Los 12 pisos quedan reservados para el nivel máximo de desarrollo, que
## todavía no existe.
const NIVELES_VIVIENDA := {
	1: {"camas_por_piso": 2, "pisos": 2},
	2: {"camas_por_piso": 4, "pisos": 4},
	3: {"camas_por_piso": 4, "pisos": 8},
}

## A quién se desahucia primero cuando la vivienda ocupada excede la
## capacidad: primero quien no produce. Los últimos tres solo garantizan que
## el bucle de regular_densidad_vertical() siempre termina.
const ORDEN_DESAHUCIO := ["desempleado", "ciudadano", "obrero", "tecnico", "especialista", "investigador", "militar"]

## A quién quita primero la hambruna (igual que antes de la taxonomía nueva).
const ORDEN_BAJAS_HAMBRUNA := ["militar", "obrero", "tecnico"]

## Costo de activación por nivel (GDD Sección 7).
const COSTOS_INVESTIGACION := {
	2: {"nombre": "Metalurgia Aplicada", "hierro": 300, "madera": 200, "horas_investigador": 20},
	3: {"nombre": "Automatización Industrial", "hierro": 800, "madera": 100, "horas_investigador": 50},
}

const CATEGORIAS_COMIDA := [
	"sembradios", "granjas_animales", "recoleccion_caza",
	"hidroponia", "pesca", "sintetico",
]
const BONO_MORAL_MAXIMO := 15.0
const VELOCIDAD_SUAVIZADO_MORAL := 0.15


class Recurso:
	var nombre: String
	var cantidad: float
	var limite: float
	## Cambio neto de "cantidad" en el último simular_tick() (positivo =
	## ganancia, negativo = consumo neto). Ver Ciudad.simular_tick(), que
	## toma una foto de "cantidad" antes y después de aplicar las
	## transacciones del tick. Usado por el HUD (comida, recurso crítico).
	var tasa_neta: float = 0.0

	func _init(p_nombre: String, p_cantidad: float, p_limite: float) -> void:
		nombre = p_nombre
		cantidad = max(0.0, p_cantidad)
		limite = p_limite

	func agregar(monto: float) -> float:
		var espacio_libre: float = limite - cantidad
		var ingreso_real: float = min(espacio_libre, monto)
		cantidad += ingreso_real
		return ingreso_real

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
var demografia: Dictionary = {}
var almacen: Dictionary = {}
var desahuciados := 0
var nivel_investigado := 1
var progreso_investigacion := {2: 0.0, 3: 0.0}
var fuentes_comida_activas: Dictionary = {}
var bono_moral_variedad := 0.0
var periodo_elecciones_restante := 0
## Edificios residenciales registrados: id de edificio (el que asigna
## VoxelWorld) -> Array[int] con las camas de CADA piso. Ver
## registrar_edificio_residencial().
var edificios_residenciales: Dictionary = {}

## Si es false, simular_tick() no hace llegar colonos (lo usan las pruebas
## que fijan la demografía a mano).
var migracion_activa := true
var _migrantes_acumulados := 0.0

var _timer: Timer


func _init() -> void:
	for tipo in TIPOS_POBLACION:
		demografia[tipo] = 0
	almacen = {
		"madera": Recurso.new("Madera", 200, 1000),
		"comida": Recurso.new("Comida", 150, 2000),
		"hierro": Recurso.new("Hierro", 50, 1000),
	}
	for categoria in CATEGORIAS_COMIDA:
		fuentes_comida_activas[categoria] = 0.0


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
	get: return int(_suma_dict(demografia))

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
		if idx >= 2.5 and instalaciones["tipo_3"] >= 3:
			return 3
		elif idx >= 1.7 and instalaciones["tipo_2"] >= 3:
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

## Suma de 1 / x_cama de cada habitante: la vivienda que ocupa la población.
var vivienda_ocupada: float:
	get:
		var total := 0.0
		for tipo in demografia:
			total += float(demografia[tipo]) / float(TIPOS_POBLACION[tipo]["x_cama"])
		return total

var vivienda_libre: float:
	get: return float(capacidad_camas_construida) - vivienda_ocupada


## Acumula horas-investigador y activa el siguiente nivel al completar el umbral.
func actualizar_investigacion() -> void:
	var siguiente: int = nivel_investigado + 1
	if not COSTOS_INVESTIGACION.has(siguiente):
		return
	var costo: Dictionary = COSTOS_INVESTIGACION[siguiente]
	if nivel_potencial < siguiente:
		return  # el ratio de instalaciones aún no habilita esta investigación
	if demografia["investigador"] <= 0:
		return

	progreso_investigacion[siguiente] += demografia["investigador"]
	if progreso_investigacion[siguiente] >= costo["horas_investigador"]:
		var hierro_ok: bool = (almacen["hierro"] as Recurso).consumir(costo["hierro"])
		var madera_ok: bool = (almacen["madera"] as Recurso).consumir(costo["madera"])
		if hierro_ok and madera_ok:
			nivel_investigado = siguiente


## Desplaza el bono de moral gradualmente hacia el objetivo de diversidad activa.
func actualizar_bono_variedad() -> void:
	var activas := 0
	for valor in fuentes_comida_activas.values():
		if valor > 0:
			activas += 1
	var objetivo: float = (float(activas) / float(CATEGORIAS_COMIDA.size())) * BONO_MORAL_MAXIMO
	var diferencia: float = objetivo - bono_moral_variedad
	bono_moral_variedad += diferencia * VELOCIDAD_SUAVIZADO_MORAL


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


## Registra un edificio residencial completo (ver
## Player.gd::_completar_construccion). "id" es el id de edificio de
## VoxelWorld y "camas_por_piso" las camas de cada piso, en orden. Idempotente
## por id: registrar dos veces el mismo edificio (p. ej. al deconstruirlo y
## volver a completarlo) no duplica sus camas.
func registrar_edificio_residencial(id: int, camas_por_piso: Array) -> void:
	edificios_residenciales[id] = camas_por_piso.duplicate()


## Retira las camas de un edificio residencial que empieza a deconstruirse
## (ver Player.gd::_procesar_deconstruccion) — simétrica a
## registrar_edificio_residencial(). Se llama al INICIAR la deconstrucción de
## un edificio ya terminado (no al completarla): un colono no debería poder
## "vivir" en una cama que ya está siendo desmontada. Un id desconocido no
## hace nada.
func retirar_edificio_residencial(id: int) -> void:
	edificios_residenciales.erase(id)


## Aplica la sucesión del avatar tras su muerte (GDD Sección 9).
func suceder_avatar() -> String:
	if censo_total == 0:
		return "game_over"
	if demografia["militar"] <= 0:
		return "sin_sucesor_elegible"

	demografia["militar"] -= 1
	periodo_elecciones_restante = 5  # ticks de penalización de liderazgo
	return "sucesion_exitosa"


## Devuelve la clave de almacen (comida/madera/hierro) con la tasa neta más
## negativa del último tick — el recurso en mayor déficit ahora mismo. Si
## ninguno está en déficit, igual devuelve el de tasa más baja (puede ser 0
## o positiva); el HUD decide cómo mostrarlo (ver Ciudad.recurso_critico()).
func recurso_critico() -> String:
	var peor_clave := ""
	var peor_tasa := INF
	for clave in almacen:
		var tasa: float = (almacen[clave] as Recurso).tasa_neta
		if tasa < peor_tasa:
			peor_tasa = tasa
			peor_clave = clave
	return peor_clave


## Ejecuta un ciclo horario verificando alimentación, habitabilidad e investigación.
func simular_tick(avatar_consumo: float) -> Dictionary:
	var cantidad_antes: Dictionary = {}
	for clave in almacen:
		cantidad_antes[clave] = (almacen[clave] as Recurso).cantidad

	regular_densidad_vertical()
	actualizar_investigacion()
	actualizar_bono_variedad()

	var gasto_poblacion := 0.0
	for tipo in demografia:
		gasto_poblacion += demografia[tipo] * TIPOS_POBLACION[tipo]["comida"]
	var gasto_total: float = gasto_poblacion + avatar_consumo

	if periodo_elecciones_restante > 0:
		gasto_total *= 1.10
		periodo_elecciones_restante -= 1

	var exito_comida: bool = (almacen["comida"] as Recurso).consumir(gasto_total)

	var bajas_inanicion := 0
	if not exito_comida:
		bajas_inanicion = max(1, int(censo_total * 0.25))
		(almacen["comida"] as Recurso).cantidad = 0.0
		for rol in ORDEN_BAJAS_HAMBRUNA:
			if demografia[rol] > 0 and bajas_inanicion > 0:
				var quitar: int = min(demografia[rol], bajas_inanicion)
				demografia[rol] -= quitar
				bajas_inanicion -= quitar

	for clave in almacen:
		var recurso: Recurso = almacen[clave]
		recurso.tasa_neta = recurso.cantidad - float(cantidad_antes[clave])

	return {
		"gasto_comida": gasto_total,
		"hambruna": not exito_comida,
		"bajas": bajas_inanicion,
		"nivel_ciudad": nivel,
		"nivel_potencial": nivel_potencial,
		"bono_moral_variedad": snapped(bono_moral_variedad, 0.01),
	}

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

const SEGUNDOS_POR_TICK := 2.0

const CONSUMO_POR_ROL := {
	"jovenes": 2,
	"trabajador_tipo_1": 5,
	"trabajador_tipo_2": 4,
	"trabajador_tipo_3": 3,
	"investigador": 2,
	"militar": 4,
	"ancianos": 2,
}

## Habitabilidad base por piso disponible según nivel EFECTIVO de ciudad.
const CAMAS_POR_PISO_PERMITIDO := {
	1: 4,   # Nivel 1: Suelo + 1 piso = 2 niveles (4 camas)
	2: 8,   # Nivel 2: Suelo + 3 pisos = 4 niveles (8 camas)
	3: 12,  # Nivel 3: Suelo + 5 pisos = 6 niveles (12 camas)
}

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
## Suma de camas de todos los edificios residenciales declarados válidos por
## el jugador (ver Player.gd::_declarar_edificio). No es población real, solo
## capacidad habitacional construida — la demografía sigue siendo manual
## hasta que exista un modelo de crecimiento poblacional.
var capacidad_camas_construida := 0

var _timer: Timer


func _init() -> void:
	for rol in CONSUMO_POR_ROL:
		demografia[rol] = 0
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

var capacidad_habitacional: int:
	get: return CAMAS_POR_PISO_PERMITIDO.get(nivel, 4)


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


## Verifica si la población excede el límite permitido por el nivel EFECTIVO.
func regular_densidad_vertical() -> void:
	var limite: int = capacidad_habitacional
	if censo_total > limite:
		var exceso: int = censo_total - limite
		desahuciados += exceso

		var orden_recorte := ["trabajador_tipo_1", "jovenes", "trabajador_tipo_2", "ancianos"]
		for rol in orden_recorte:
			if exceso <= 0:
				break
			var disponibles: int = demografia[rol]
			var a_remover: int = min(disponibles, exceso)
			demografia[rol] -= a_remover
			exceso -= a_remover


## Registra un edificio residencial recién declarado válido (ver
## Player.gd::_declarar_edificio). ponytail: no deduplica — declarar el mismo
## edificio dos veces suma sus camas dos veces; corregir cuando exista un
## registro real de edificios declarados (identidad/posición), no solo un
## contador acumulado.
func registrar_edificio_residencial(total_camas: int) -> void:
	capacidad_camas_construida += total_camas


## Retira la capacidad de camas de un edificio residencial que empieza a
## deconstruirse (ver Player.gd::_procesar_deconstruccion) — simétrica a
## registrar_edificio_residencial(). Se llama al INICIAR la deconstrucción
## de un edificio ya terminado (no al completarla): un ciudadano no debería
## poder "vivir" en una cama que ya está siendo desmontada, aunque las
## paredes tarden más en desaparecer. clamp a 0 por seguridad (nunca debería
## bajar de 0 si la contabilidad es correcta, pero un edificio nunca debe
## dejar el contador en negativo).
func retirar_edificio_residencial(total_camas: int) -> void:
	capacidad_camas_construida = max(0, capacidad_camas_construida - total_camas)


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
	for rol in demografia:
		gasto_poblacion += demografia[rol] * CONSUMO_POR_ROL[rol]
	var gasto_total: float = gasto_poblacion + avatar_consumo

	if periodo_elecciones_restante > 0:
		gasto_total *= 1.10
		periodo_elecciones_restante -= 1

	var exito_comida: bool = (almacen["comida"] as Recurso).consumir(gasto_total)

	var bajas_inanicion := 0
	if not exito_comida:
		bajas_inanicion = max(1, int(censo_total * 0.25))
		(almacen["comida"] as Recurso).cantidad = 0.0
		for rol in ["militar", "trabajador_tipo_1", "trabajador_tipo_2"]:
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

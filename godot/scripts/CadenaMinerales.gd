extends Node

## Autoload "CadenaMinerales": recetas de refinado de minerales (PoC 5,
## sub-proyecto 1 — GDD Sección 4). Reutiliza Recoleccion.TIPOS_MINERALES
## como catálogo de minerales crudos; esta clase solo agrega las recetas
## que transforman un mineral en otro recurso. Sin class_name (mismo
## motivo que Recoleccion.gd/Zonificacion.gd/Ciudad.gd).

const Ajustes = preload("res://scripts/ajustes.gd")

## tipo_entrada -> {"entradas": {recurso: cantidad por lote}, "tipo_salida": String,
## "cantidad_salida": int (por lote), "tasa_base": float (lotes por hora por trabajador)}.
## Cada refinería tiene una única receta fija (ningún edificio soporta más de una, GDD Sección 4) —
## por eso el catálogo se indexa por tipo_entrada (el insumo principal), no por nombre de edificio.
static var RECETAS: Dictionary = Ajustes.CADENA_MINERALES_RECETAS

## Tipo de edificio -> tipo_entrada de su receta (clave de RECETAS). Una refinería es un
## puesto de Economia con tipo en este diccionario (ver Economia.es_refineria()).
const REFINERIAS := {
	"siderurgica": "hierro",
	"refineria_tierras_raras": "tierras_raras",
	"aserradero": "aserradero",
	"fabrica_bloques": "fabrica_bloques",
	"carbonera": "carbonera",
	"refineria_petrolera": "petroleo",
	"productor_combustible": "combustible_sintetico",
}

# Todas las refinerías comparten personal y almacén local (el costo REAL de construirlas es el de
# los bloques de su plantilla, ver PlantillasPuesto).
static var PERSONAL_MAXIMO_REFINERIA: int = Ajustes.CADENA_MINERALES_PERSONAL_MAXIMO_REFINERIA
static var CAPACIDAD_ALMACENAMIENTO_REFINERIA: int = Ajustes.CADENA_MINERALES_CAPACIDAD_ALMACENAMIENTO_REFINERIA  # insumo y producto lo comparten
static var LIMITE_CRUDO_REFINERIA: float = Ajustes.CADENA_MINERALES_LIMITE_CRUDO_REFINERIA  # máximo 40% de crudo para refinería petrolera
static var RESERVA_COMBUSTIBLE_REFINERIA: float = Ajustes.CADENA_MINERALES_RESERVA_COMBUSTIBLE_REFINERIA  # reserva de 60% para combustible


func admite_crudo(almacen: Dictionary, cantidad: float = 0.0) -> bool:
	return almacen.get("crudo", 0.0) + cantidad <= LIMITE_CRUDO_REFINERIA


## Procesa una receta específica de duración "delta" horas contra un almacén local:
## lotes limitados por personal * tasa_base * delta, factor_energia, insumos disponibles y espacio de salida.
## Devuelve un Dictionary NUEVO (String -> float) — NO muta "almacen".
func procesar_receta(tipo_entrada: String, num_trabajadores: int, delta: float, almacen: Dictionary, factor_energia: float = 1.0, capacidad: float = INF) -> Dictionary:
	var resultado: Dictionary = almacen.duplicate()
	if num_trabajadores <= 0 or not RECETAS.has(tipo_entrada):
		return resultado
	var receta: Dictionary = RECETAS[tipo_entrada]
	var lotes: float = num_trabajadores * receta["tasa_base"] * delta
	if receta.get("energia_por_lote", 0) > 0:
		lotes *= maxf(0.0, factor_energia)
	for recurso in receta["entradas"]:
		lotes = minf(lotes, resultado.get(recurso, 0.0) / float(receta["entradas"][recurso]))
	if capacidad < INF:
		var cap_salida: float = capacidad
		if tipo_entrada == "petroleo":
			cap_salida = minf(capacidad, RESERVA_COMBUSTIBLE_REFINERIA)
		var espacio_salida: float = maxf(0.0, cap_salida - resultado.get(receta["tipo_salida"], 0.0))
		lotes = minf(lotes, espacio_salida / float(receta["cantidad_salida"]))
		var cambio_neto: float = float(receta["cantidad_salida"])
		for cant_in in receta["entradas"].values():
			cambio_neto -= float(cant_in)
		if cambio_neto > 0.0:
			var total_actual := 0.0
			for v: float in resultado.values():
				total_actual += v
			var libre_total: float = maxf(0.0, capacidad - total_actual)
			lotes = minf(lotes, libre_total / cambio_neto)
	for recurso in receta["entradas"]:
		resultado[recurso] = resultado.get(recurso, 0.0) - lotes * receta["entradas"][recurso]
	var tipo_salida: String = receta["tipo_salida"]
	resultado[tipo_salida] = resultado.get(tipo_salida, 0.0) + lotes * receta["cantidad_salida"]
	return resultado


## Procesa un tick de refinado de duración "delta" horas: por cada receta en
## RECETAS con al menos 1 trabajador asignado (trabajadores[tipo_entrada]).
func procesar_tick(delta: float, almacen: Dictionary, trabajadores: Dictionary, factor_energia: float = 1.0, capacidad: float = INF) -> Dictionary:
	var resultado: Dictionary = almacen.duplicate()
	for tipo_entrada in RECETAS:
		var num_trabajadores: int = trabajadores.get(tipo_entrada, 0)
		if num_trabajadores <= 0:
			continue
		resultado = procesar_receta(tipo_entrada, num_trabajadores, delta, resultado, factor_energia, capacidad)
	return resultado


## Tasas netas de consumo/producción POR HORA de cada receta con al menos 1
## trabajador asignado (con insumo de sobra) — no muta ningún almacén, solo informa
## (mismo patrón que Recoleccion.tasas_recoleccion()/tasas_caza_recoleccion()). Una receta
## sin trabajadores asignados no aparece en el resultado.
## {"hierro": {"consumo": {recurso: float}, "produccion": float, "tipo_salida": String}, ...}
func tasas_refinado(trabajadores: Dictionary) -> Dictionary:
	var tasas: Dictionary = {}
	for tipo_entrada in RECETAS:
		var num_trabajadores: int = trabajadores.get(tipo_entrada, 0)
		if num_trabajadores <= 0:
			continue
		var receta: Dictionary = RECETAS[tipo_entrada]
		var lotes_hora: float = num_trabajadores * receta["tasa_base"]
		var consumo: Dictionary = {}
		for recurso in receta["entradas"]:
			consumo[recurso] = receta["entradas"][recurso] * lotes_hora
		tasas[tipo_entrada] = {"consumo": consumo, "produccion": lotes_hora * receta["cantidad_salida"], "tipo_salida": receta["tipo_salida"]}
	return tasas

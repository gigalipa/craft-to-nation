extends Node

## Autoload "CadenaMinerales": recetas de refinado de minerales (PoC 5,
## sub-proyecto 1 — GDD Sección 4). Reutiliza Recoleccion.TIPOS_MINERALES
## como catálogo de minerales crudos; esta clase solo agrega las recetas
## que transforman un mineral en otro recurso. Sin class_name (mismo
## motivo que Recoleccion.gd/Zonificacion.gd/Ciudad.gd).

## tipo_entrada -> {"entradas": {recurso: cantidad por lote}, "tipo_salida": String,
## "cantidad_salida": int (por lote), "tasa_base": float (lotes por hora por trabajador)}.
## Cada refinería tiene una única receta fija (ningún edificio soporta más de una, GDD Sección 4) —
## por eso el catálogo se indexa por tipo_entrada (el insumo principal), no por nombre de edificio.
const RECETAS: Dictionary = {
	"hierro": {"entradas": {"hierro": 3, "carbon": 4}, "tipo_salida": "acero", "cantidad_salida": 2, "tasa_base": 2.0},
	"tierras_raras": {"entradas": {"tierras_raras": 3}, "tipo_salida": "mineral_refinado", "cantidad_salida": 1, "tasa_base": 2.0},
}

## Tipo de edificio -> tipo_entrada de su receta (clave de RECETAS). Una refinería es un
## puesto de Economia con tipo en este diccionario (ver Economia.es_refineria()).
const REFINERIAS := {"siderurgica": "hierro"}

# GDD Sección 4 — mismos valores placeholder que los puestos periféricos
# (Recoleccion.COSTO_CONSTRUCCION), sin balance real todavía. El costo REAL de
# construir una refinería es el de los bloques de su plantilla (ver PlantillasPuesto).
const COSTO_CONSTRUCCION_REFINERIA_HIERRO := {"tierra": 10, "madera": 10, "piedra": 5}
const PERSONAL_MAXIMO_REFINERIA_HIERRO := 4
const CAPACIDAD_ALMACENAMIENTO_REFINERIA_HIERRO := 1000  # igual que los puestos; hierro y acero lo comparten

const COSTO_CONSTRUCCION_REFINERIA_TIERRAS_RARAS := {"tierra": 10, "madera": 10, "piedra": 5}
const PERSONAL_MAXIMO_REFINERIA_TIERRAS_RARAS := 3
const CAPACIDAD_ALMACENAMIENTO_REFINERIA_TIERRAS_RARAS := 1000


## Procesa un tick de refinado de duración "delta" horas: por cada receta en
## RECETAS con al menos 1 trabajador asignado (trabajadores[tipo_entrada]),
## hace hasta "num_trabajadores * tasa_base * delta" lotes, sin pasar de lo que alcance el
## insumo más escaso en "almacen" (un trabajador sin insumo suficiente simplemente refina
## menos, no se bloquea ni da error), consume "entradas * lotes" y produce "cantidad_salida * lotes".
## Devuelve un Dictionary NUEVO (String -> float) — NO muta "almacen"; cualquier tipo no
## tocado por ninguna receta se copia sin cambios.
func procesar_tick(delta: float, almacen: Dictionary, trabajadores: Dictionary) -> Dictionary:
	var resultado: Dictionary = almacen.duplicate()
	for tipo_entrada in RECETAS:
		var num_trabajadores: int = trabajadores.get(tipo_entrada, 0)
		if num_trabajadores <= 0:
			continue
		var receta: Dictionary = RECETAS[tipo_entrada]
		var lotes: float = num_trabajadores * receta["tasa_base"] * delta
		for recurso in receta["entradas"]:
			lotes = minf(lotes, resultado.get(recurso, 0.0) / receta["entradas"][recurso])
		for recurso in receta["entradas"]:
			resultado[recurso] = resultado.get(recurso, 0.0) - lotes * receta["entradas"][recurso]
		var tipo_salida: String = receta["tipo_salida"]
		resultado[tipo_salida] = resultado.get(tipo_salida, 0.0) + lotes * receta["cantidad_salida"]
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

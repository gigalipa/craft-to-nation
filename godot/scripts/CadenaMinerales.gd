extends Node

## Autoload "CadenaMinerales": recetas de refinado de minerales (PoC 5,
## sub-proyecto 1 — GDD Sección 4). Reutiliza Recoleccion.TIPOS_MINERALES
## como catálogo de minerales crudos; esta clase solo agrega las recetas
## que transforman un mineral en otro recurso. Sin class_name (mismo
## motivo que Recoleccion.gd/Zonificacion.gd/Ciudad.gd).

## tipo_entrada -> {"tipo_salida": String, "cantidad_entrada": int,
## "cantidad_salida": int, "tasa_base": float}. Cada refinería tiene una
## única receta fija (ningún edificio soporta más de una, GDD Sección 4) —
## por eso el catálogo se indexa por tipo_entrada, no por nombre de edificio.
const RECETAS: Dictionary = {
	"hierro": {"tipo_salida": "acero", "cantidad_entrada": 2, "cantidad_salida": 1, "tasa_base": 2.0},
	"tierras_raras": {"tipo_salida": "mineral_refinado", "cantidad_entrada": 3, "cantidad_salida": 1, "tasa_base": 2.0},
}

# GDD Sección 4 — mismos valores placeholder que los puestos periféricos
# (Recoleccion.COSTO_CONSTRUCCION), sin balance real todavía.
const COSTO_CONSTRUCCION_REFINERIA_HIERRO := {"tierra": 10, "madera": 10, "piedra": 5}
const PERSONAL_MAXIMO_REFINERIA_HIERRO := 3
const CAPACIDAD_ALMACENAMIENTO_REFINERIA_HIERRO := 100

const COSTO_CONSTRUCCION_REFINERIA_TIERRAS_RARAS := {"tierra": 10, "madera": 10, "piedra": 5}
const PERSONAL_MAXIMO_REFINERIA_TIERRAS_RARAS := 3
const CAPACIDAD_ALMACENAMIENTO_REFINERIA_TIERRAS_RARAS := 100


## Procesa un tick de refinado de duración "delta" horas: por cada receta en
## RECETAS con al menos 1 trabajador asignado (trabajadores[tipo_entrada]),
## consume hasta "cantidad_entrada * num_trabajadores * tasa_base * delta"
## unidades del insumo (nunca más de lo disponible en "almacen" — un
## trabajador sin insumo suficiente simplemente refina menos, no se bloquea
## ni da error) y produce la proporción exacta de producto. Devuelve un
## Dictionary NUEVO (String -> float) — NO muta "almacen"; cualquier tipo no
## tocado por ninguna receta se copia sin cambios.
func procesar_tick(delta: float, almacen: Dictionary, trabajadores: Dictionary) -> Dictionary:
	var resultado: Dictionary = almacen.duplicate()
	for tipo_entrada in RECETAS:
		var num_trabajadores: int = trabajadores.get(tipo_entrada, 0)
		if num_trabajadores <= 0:
			continue
		var receta: Dictionary = RECETAS[tipo_entrada]
		var disponible: float = resultado.get(tipo_entrada, 0.0)
		var demanda: float = receta["cantidad_entrada"] * num_trabajadores * receta["tasa_base"] * delta
		var consumido: float = minf(disponible, demanda)
		var lotes: float = consumido / receta["cantidad_entrada"]
		var producido: float = lotes * receta["cantidad_salida"]
		var tipo_salida: String = receta["tipo_salida"]
		resultado[tipo_entrada] = disponible - consumido
		resultado[tipo_salida] = resultado.get(tipo_salida, 0.0) + producido
	return resultado


## Tasas netas de consumo/producción POR HORA de cada receta con al menos 1
## trabajador asignado — no muta ningún almacén, solo informa (mismo patrón
## que Recoleccion.tasas_recoleccion()/tasas_caza_recoleccion()). Una receta
## sin trabajadores asignados no aparece en el resultado.
## {"hierro": {"consumo": float, "produccion": float, "tipo_salida": String}, ...}
func tasas_refinado(trabajadores: Dictionary) -> Dictionary:
	var tasas: Dictionary = {}
	for tipo_entrada in RECETAS:
		var num_trabajadores: int = trabajadores.get(tipo_entrada, 0)
		if num_trabajadores <= 0:
			continue
		var receta: Dictionary = RECETAS[tipo_entrada]
		var consumo_hora: float = receta["cantidad_entrada"] * num_trabajadores * receta["tasa_base"]
		var produccion_hora: float = (consumo_hora / receta["cantidad_entrada"]) * receta["cantidad_salida"]
		tasas[tipo_entrada] = {"consumo": consumo_hora, "produccion": produccion_hora, "tipo_salida": receta["tipo_salida"]}
	return tasas

# Cadena de Minerales (PoC 5, sub-proyecto 1) — Diseño

**Alcance:** PoC 5 (Fase 3 del roadmap, GDD Sección 11) — primer sub-proyecto
del "Catálogo de Recursos y Cadenas de Producción" (GDD Sección 4), acotado
deliberadamente a los **minerales**: el catálogo de 6 tipos que ya extraen
las minas (`Recoleccion.TIPOS_MINERALES`) y las dos refinerías que
transforman uno de esos minerales en otro recurso ("hierro" → "acero",
"tierras_raras" → "mineral_refinado"). Madera (aserradero/carbonera),
fluidos (agua/crudo/combustible) y energía quedan **explícitamente fuera de
alcance** — son sub-proyectos futuros de esta misma PoC, decididos así por
el usuario para no intentar la Sección 4 completa de una sola vez.

**Repo:** `C:\Users\peraz\Projects\Misc\CityCraft`, proyecto Godot 4.7 compartido en `godot/`.

## Decisiones de alcance confirmadas con el usuario

- **Solo minerales por ahora** — de los 4 grupos de la Sección 4 (minerales,
  madera, fluidos, energía), este sub-proyecto cubre únicamente el primero.
  Los demás se abordarán en sub-proyectos separados de PoC 5.
- **Corrección de una contradicción real del GDD:** la Sección 4 dice, en
  una misma subsección, que "el carbón alimenta la carbonera" (carbón como
  insumo de la carbonera) y que "la carbonera diversifica madera en carbón"
  (carbón como producto, insumo=madera) — dos afirmaciones incompatibles.
  El usuario confirmó que la segunda es la correcta: **la carbonera consume
  madera y produce carbón**; la primera frase es un error del GDD (debería
  decir que el carbón alimenta únicamente al productor de combustible). Se
  corrige el texto del GDD como parte de esta pieza (ver "Documentación").
  La carbonera en sí (edificio, receta, integración) queda fuera de
  alcance — pertenece al sub-proyecto de madera.
- **`carbón` se cataloga pero no se consume todavía:** las minas ya pueden
  dar `carbon` (`Recoleccion.TIPOS_MINERALES` lo incluye desde PoC 6). Este
  sub-proyecto no le agrega ninguna refinería propia — sus consumidores
  (carbonera, productor de combustible) son de sub-proyectos futuros. No
  hace falta ningún cambio para esto: simplemente `CadenaMinerales.gd` no
  define ninguna receta con `carbon` como insumo.
- **`tierra`, `piedra` y `cobre` son recursos "directos", sin receta:**
  igual que ya lo describe el GDD — van al almacén tal cual, sin ninguna
  transformación en este sub-proyecto. No se modela ninguna refinería para
  ellos.
- **Solo lógica pura + escena de prueba, sin refinerías colocables
  todavía:** mismo patrón que `Ciudad.gd`/`Zonificacion.gd`/`Recoleccion.gd`
  — un autoload nuevo con las recetas y el cálculo de balance, verificado
  con una escena de pruebas automatizadas (asserts, como el resto del
  proyecto) y una escena de demostración interactiva simple (controles de
  teclado, mismo patrón ya usado por `CamaraCenital.gd`) para poder "jugar"
  con los números de balance en vivo. Construir refinerías reales como
  puestos periféricos colocables en el mundo (como se hizo con el puesto de
  pesca) es un sub-proyecto/PoC posterior, no esta pieza.
- **Recetas propuestas (placeholder, ajustable):** `2 hierro → 1 acero` y
  `3 tierras_raras → 1 mineral_refinado` — números redondos simples,
  mismo espíritu que el aserradero ya documentado (`1 madera → 3 tablas`,
  sub-proyecto de madera, todavía no implementado). Sin balance real
  todavía (igual alcance reducido que el resto del proyecto: costo de
  construcción, personal máximo y capacidad de almacenamiento son
  placeholders, no cifras balanceadas).

## 1. `CadenaMinerales.gd` — autoload nuevo

Mismo patrón que `Recoleccion.gd`: sin `class_name` (evita el bug de caché
de clases globales de Godot, ya documentado en ese archivo), estado y
lógica pura, sin dependencia de ningún nodo de escena. Reutiliza
`Recoleccion.TIPOS_MINERALES` como catálogo de minerales crudos — no lo
redefine.

```gdscript
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
```

**`PERSONAL_MAXIMO_*` es informativo, no se aplica todavía:** igual que
`Recoleccion.PERSONAL_MAXIMO` en los puestos periféricos, ningún código de
este sub-proyecto rechaza ni recorta `trabajadores[tipo]` contra este
límite — es un valor de referencia para una futura ficha de HUD, no una
validación. `procesar_tick()`/`tasas_refinado()` aceptan cualquier
`num_trabajadores >= 0` sin comprobarlo contra `PERSONAL_MAXIMO_*`.

```gdscript


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
```

Registrar como autoload en `godot/project.godot`, mismo bloque `[autoload]`
donde ya están `Ciudad`/`Zonificacion`/`Recoleccion`/`Construccion`.

**Nota de diseño — por qué `procesar_tick()` no muta `almacen`:** a
diferencia de `Ciudad.simular_tick()` (que sí muta sus `Recurso` en sitio,
porque están atados al autoload singleton real), esta función se piensa
para ser llamada tanto desde pruebas deterministas (con un `Dictionary`
plano de usar y tirar) como desde la futura integración con el almacén real
de `Ciudad`/`Recoleccion` — devolver un `Dictionary` nuevo evita que un
error de integración futura corrompa silenciosamente el almacén real a
mitad de cálculo.

## 2. Pruebas automatizadas — `CadenaMineralesTest.gd`/`.tscn`

Mismo patrón que `RecoleccionTest.gd`/`NiveladorTerrenoTest.gd`: escena
`Node` raíz, `_ready()` llama `ejecutar_pruebas()`, cada test imprime un
encabezado y termina en `assert()`.

Casos a cubrir (lista, no código exacto — el plan de implementación fija el
código con `assert()` línea por línea):

1. `procesar_tick()` con trabajadores en ambas recetas a la vez, insumo
   suficiente para ambas: verifica el consumo/producción exactos de hierro→acero
   y tierras_raras→mineral_refinado en el mismo tick, sin que una receta
   afecte a la otra.
2. `procesar_tick()` sin trabajadores asignados (`trabajadores = {}`): el
   almacén vuelve exactamente igual (ninguna receta se ejecuta).
3. `procesar_tick()` con insumo insuficiente para la demanda completa:
   consume solo lo disponible (no queda negativo) y produce la proporción
   exacta correspondiente a lo realmente consumido — no la producción
   "completa" que hubiera dado la demanda teórica.
4. `procesar_tick()` no muta el `Dictionary` "almacen" que recibe (compara
   el diccionario original antes/después de la llamada).
5. `procesar_tick()` con un tipo de mineral que no tiene receta (p. ej.
   `cobre`) presente en el almacén: pasa sin cambios al resultado.
6. `tasas_refinado()` con ambas recetas activas: verifica los valores
   exactos de consumo/producción por hora para cada una.
7. `tasas_refinado()` sin trabajadores en una receta: esa receta no aparece
   en el resultado (no una entrada con valores en 0.0 — la clave misma está
   ausente, para que un consumidor futuro tipo HUD pueda usar
   `tasas.has(tipo)` para decidir si mostrar la ficha de esa refinería).
8. Determinismo: dos llamadas a `procesar_tick()`/`tasas_refinado()` con los
   mismos argumentos dan exactamente el mismo resultado.

## 3. Escena de demostración interactiva — `CadenaMineralesDemo.tscn`/`.gd`

Escena standalone (no integrada con `Main.tscn` todavía — mismo alcance
reducido que el resto del proyecto: "probar valores de balance en vivo",
no una herramienta de producción final), controlada por teclado, mismo
patrón que los modos de `CamaraCenital.gd` (una tecla por acción, texto
simple en pantalla vía `Label`, sin sliders ni menús).

**Controles:**
- Teclas `1`-`6`: agregan 10 unidades del mineral correspondiente al
  almacén simulado (`1`=tierra, `2`=piedra, `3`=hierro, `4`=cobre,
  `5`=carbon, `6`=tierras_raras — mismo orden que `Recoleccion.TIPOS_MINERALES`).
  Añadir carbón demuestra visualmente que se acumula sin ninguna receta que
  lo consuma todavía (documenta en la propia demo el "fuera de alcance").
- Tecla `Q`/`W`: resta/suma 1 trabajador a la refinería de hierro (mínimo 0).
- Tecla `A`/`S`: resta/suma 1 trabajador a la refinería de tierras raras
  (mínimo 0).
- Tecla `Espacio`: avanza un tick de `1.0` hora (`CadenaMinerales.procesar_tick(1.0, almacen, trabajadores)`),
  reemplazando el almacén simulado por el resultado.
- Un `Label` muestra en todo momento: cantidades del almacén simulado (solo
  los tipos con cantidad > 0, para no listar los 8 tipos siempre) y las
  tasas por hora de `tasas_refinado()` (solo las recetas activas).

Este script mantiene su propio `almacen: Dictionary` y `trabajadores: Dictionary`
locales (no toca `Ciudad.almacen` ni ningún estado real del juego) — es una
caja de arena aislada para probar los números de `CadenaMinerales.RECETAS`.

## 4. Documentación

- **Corregir el GDD (Sección 4):** la frase "el carbón alimenta la
  carbonera y el productor de combustible" se corrige a "el carbón
  alimenta el productor de combustible" (quitando la mención a la
  carbonera, que consume madera, no carbón — ver la oración siguiente del
  mismo párrafo, que ya lo decía correctamente).
- **Crear `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Catálogo de Recursos y Cadenas de Producción.md`**
  (carpeta nueva, no existe todavía) — mismo patrón que `PoC_6/`: Alcance,
  decisiones, código de referencia, pruebas, verificado, próximos pasos
  (madera/fluidos/energía como sub-proyectos futuros de esta misma PoC).
- **Actualizar GDD Sección 11** (tabla de la Fase 3): el bullet de "PoC 5
  — pendiente de brainstorm/spec/plan propio" pasa a reflejar que el
  sub-proyecto de minerales está en curso/completo, con los demás grupos
  (madera/fluidos/energía) listados como pendientes de esta misma PoC.

## Fuera de alcance (explícito)

- Madera (aserradero, carbonera), fluidos (bombas de agua/crudo, refinería
  de crudo, productor de combustible) y energía (generadores, transmisión)
  — sub-proyectos futuros de PoC 5, cada uno con su propio spec.
- Refinerías reales colocables como puestos periféricos en el mundo (con
  huella, validación de colocación, bloque marcador en la `MeshLibrary`,
  radio de acción, ficha de HUD) — sub-proyecto/PoC posterior, una vez que
  el balance de recetas esté probado aquí.
- Integración con el almacén real de `Ciudad.gd`/inventario del jugador —
  `CadenaMineralesDemo.tscn` usa un almacén simulado propio, aislado.
- Cobro de costo de construcción, producción real por tick en el juego
  real, niveles 2/3 de refinería — mismo alcance reducido que el resto del
  proyecto.
- Recetas alternativas o múltiples por edificio (GDD: "ningún edificio
  soporta más de una receta" — ya está resuelto por el diseño: `RECETAS` se
  indexa 1:1 por tipo de entrada).

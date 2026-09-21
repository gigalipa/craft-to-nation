# Fichas de Consumo/Producción

Transcripción de `docs/Recursos.xlsx` (hojas "Relacion", "Recetas", "Niveles", "Puestos" y "Economia") a formato de ficha, cruzada contra el código ya implementado (`Recoleccion.gd`, `Economia.gd`, `Ciudad.gd`, `Colonos.gd`, `CadenaMinerales.gd`). No introduce ningún balance nuevo: cada número viene del Excel o del código; donde no existe ninguno de los dos, la ficha dice "por definir" en vez de inventar uno.

**Estado de cada ficha:**
- **Implementado** — el número ya vive en un script del proyecto (`Recoleccion.gd`, `Economia.gd`, `Ciudad.gd`, `CadenaMinerales.gd`).
- **Propuesta (Excel)** — valor cargado en `docs/Recursos.xlsx`, sin código todavía (ver hoja "Recetas", columna "Fuente").
- **Por definir** — ni el GDD ni el Excel lo especifican; se deja el campo vacío a propósito.

---

## 1. Fichas de Unidad

Fuente: hoja "Relacion", columnas B–H (consumo por hora, filas Comida/Combustible/Energía/"x Cama").

| Unidad | Comida/h | Combustible/h | Energía/h | "x Cama" |
|---|---|---|---|---|
| Ciudadano | 2 | — | — | 4 |
| Desempleado | 3 | — | — | 4 |
| Obrero | 5 | — | — | 4 |
| Técnico | 3 | — | — | 3 |
| Especialista | 2 | 1 | 1 | 2 |
| Investigador | 1 | — | 2 | 1 |
| Militar | 4 | 3 | — | 3 |

- **Comida/h:** implementado como concepto genérico (GDD Sección 6, "Comida como Recurso Genérico"); la tasa de hambre por nivel de avatar está en la hoja "Niveles" (5/4/3 según nivel), no por tipo de unidad — estas dos tablas de comida (por tipo de unidad y por nivel de avatar) todavía no se han conciliado en el GDD.
- **Combustible/h y Energía/h:** propuesta (Excel) — Especialista/Militar consumiendo combustible e Investigador/Especialista consumiendo energía no está descrito en el GDD todavía; ningún código las aplica.
- **"x Cama":** implementado (`Ciudad.TIPOS_POBLACION`): cuántos habitantes de ese tipo caben por cada cama construida. Cada cama aporta 1 unidad de vivienda y una persona ocupa `1 / x_cama` de ella (vivienda fraccionaria compartida, `Ciudad.vivienda_ocupada`).
- **Obrero:** un `obrero` es ahora un desempleado asignado a un puesto de recolección (`Colonos.contratar`), así que su consumo pasa de 3 (desempleado) a 5 comida/h; combustible y energía siguen sin aplicarse.
- **Vivienda por nivel de ciudad** (hoja "Niveles", `Ciudad.NIVELES_VIVIENDA`): camas por piso × pisos máximos de una casa — nivel 1 = 2 × 2, nivel 2 = 4 × 4, nivel 3 = 4 × 8.

---

## 2. Fichas de Puesto Periférico (recolección de crudos)

Fuente: hoja "Puestos" de `docs/Recursos.xlsx` (tasas base de la hoja "Relacion", columnas O–AB "Costo/producción por Bloque o NPC") y `Recoleccion.gd`. Cada puesto entrega su recurso crudo directo (Sección 4 del GDD), sin receta.

| Puesto | Recurso | Tasa base (unid/trabajador/hora) | Estado |
|---|---|---|---|
| Mina — tierra | Tierra | 1 | **Implementado** |
| Mina — piedra | Piedra | 5 | **Implementado** |
| Mina — hierro | Hierro | 5 | **Implementado** |
| Mina — cobre | Cobre | 5 | **Implementado** |
| Mina — carbón | Carbón | 5 | **Implementado** |
| Mina — tierras raras | Tierras raras | 5 | **Implementado** |
| Maderero | Madera (Tronco) | 5 | **Implementado** |
| Caza y recolección — caza (venado) | Comida | 15 | **Implementado** |
| Caza y recolección — frutos | Comida | 5 (columna "Árbol (obj)" del Excel, Comida 5; interpretada como frutos) | **Implementado** |
| Pesca y frutos del mar — pesca | Comida | 5 | **Implementado** |
| Pesca y frutos del mar — algas | Comida | 1 | **Implementado** |
| Caza — conejo | Comida | 8 | Propuesta (Excel), no implementada |
| Pozo de petróleo | Crudo | 2 | Propuesta (Excel), no implementada |
| Pozo de agua | Agua | 2 | Propuesta (Excel), no implementada |

**Fórmula vigente** (`Recoleccion.gd`, `Economia.gd`): la tasa de un recurso = tasa base del Excel × fracción (minerales) o densidad (madera, fauna, frutal, peces, algas) detectada en el área de acción del puesto, por trabajador presente y hora. Un minero reparte su esfuerzo entre los minerales según la composición del área; en caza/recolección y en pesca las dos señales se producen a la vez y se suman en `comida`. El `TASA_BASE_POR_CIUDADANO = 2.0` genérico ya no existe.

Por puesto (`Recoleccion.gd`, iguales en los cuatro salvo lo indicado):

| Puesto | Personal máximo | Almacén local | Huella (ancho × alto) | Radio del área |
|---|---|---|---|---|
| Mina | 5 | 100 | 5 × 5 | 6 (profundidad 8/16/24 según nivel) |
| Maderero | 5 | 100 | 3 × 4 | 12 |
| Caza y recolección | 7 | 100 | 4 × 4 | 12 |
| Pesca y frutos del mar | 7 | 100 | 4 × 6 | 25 (agua conectada) |

El personal máximo es el cupo total de trabajadores (recolectores + acarreadores) y el almacén local cuenta el total entre recursos. Además: `COSTO_CONSTRUCCION = {"tierra": 10, "madera": 10, "piedra": 5}` (informativo, no se cobra todavía).

---

## Acarreo y almacén central

Fuente: hoja "Economia" de `docs/Recursos.xlsx`, `Economia.gd`, `Ciudad.gd` y `Colonos.gd`.

Flujo: producción de los recolectores presentes → **almacén local** del puesto (tope 100; el exceso se pierde) → **acarreador** a pie (carga 20 por viaje; ciclo puesto → núcleo urbano → puesto) → **stock central** de 8 recursos (madera, comida, hierro, tierra, piedra, cobre, carbón y tierras raras; límite 1000 por recurso, comida 2000). La comida de caza, frutos, pesca y algas se suma en `comida`. Un tick = 2 s reales = 1 hora de juego; un colono camina 2,5 celdas/s (5 por hora de juego).

| Parámetro | Valor | Fuente |
|---|---|---|
| Duración de un tick | 2 s reales = 1 hora de juego | `Ciudad.SEGUNDOS_POR_TICK` |
| Velocidad de un colono | 2,5 celdas/s | `Colonos.VELOCIDAD_COLONO` |
| Carga de un acarreador | 20 unidades por viaje (placeholder) | `Economia.CAPACIDAD_CARGA` |
| Almacén local de un puesto | 100 unidades en total | `Recoleccion.CAPACIDAD_ALMACENAMIENTO*` |
| Límite del stock central | 1000 por recurso (comida 2000) | `Ciudad.almacen` |
| Stock inicial | comida 2000, madera 200, hierro 50, el resto 0 | `Ciudad.almacen` |
| Migración de colonos | 0,5 por hora de juego (con vivienda libre y sin hambruna) | `Ciudad.TASA_MIGRACION` |
| Consumo de un obrero de puesto | 5 comida/h (desempleado: 3) | `Ciudad.TIPOS_POBLACION` |

Todavía no existe: extracción física de bloques y agotamiento del entorno (sub-proyecto 2B), refinerías y energía (2C), carretas y carreteras (sub-proyecto 6), moral y nivel del puesto, y drones o transporte automatizado.

---

## 3. Fichas de Refinería

Fuente: hoja "Relacion", columnas AD–AQ, y hoja "Recetas".

| Refinería | Consume | Produce | Ciclo (h) | Almacén (entra/sale) | Estado | Fuente |
|---|---|---|---|---|---|---|
| Siderúrgica | Hierro ×2 | Acero ×1 | 1 | 1 / 2 | **Implementado** | `CadenaMinerales.gd` (receta "hierro") |
| Refinería de mineral | Tierras raras ×3 | Mineral refinado ×1 | 2 | 1 / 3 | **Implementado** | `CadenaMinerales.gd` (receta "tierras_raras") |
| Aserradero | Madera ×1 | Tablas ×3 (cuentan como "madera", GDD Sec. 4) | 2 | 3 / 1 | Propuesta (Excel + GDD Sec. 4) | Tasa aún no definida en código |
| Carbonera | Madera ×3 | Carbón ×1 | 1 | 1 / 3 | Propuesta (Excel) | Confirma la corrección del GDD ya aplicada en PoC 5 (madera→carbón) |
| Refinería petrolera | Crudo ×2 **y** Energía ×1 | Combustible ×1 | 1 | 1 / 2 | Propuesta (Excel), no implementada | — |
| Licuefactora de hidrocarburo | Carbón ×3, Agua ×1 **y** Energía ×1 | Combustible ×2 | 1 | 1 / 4 | Propuesta (Excel), no implementada | — |
| Central termoeléctrica | Carbón ×1 **o** Crudo ×1 **o** Combustible ×1 (cualquiera de los tres) | Energía ×20 | 1 | 60/30/10 (según insumo) / — | Propuesta (Excel), no implementada | — |

`tasa_base` (unid./ciudadano/hora) de las dos recetas implementadas: `2.0` para ambas (`CadenaMinerales.RECETAS`) — la tabla de arriba muestra cantidades por ciclo de receta, no por ciudadano; ver `CadenaMinerales.procesar_tick()` para la fórmula completa (demanda teórica recortada a lo disponible en almacén).

Refinerías propuestas todavía sin `PERSONAL_MAXIMO_*`/`COSTO_CONSTRUCCION_*` definidos — mismo criterio que dejó pendientes madera/fluidos/energía en el documento técnico de PoC 5 ("Próximos Pasos"): no se inventan aquí.

---

## 4. Fichas de Fábrica

Fuente: hoja "Relacion", columnas J–M ("Consumo por Objeto"). El GDD (Sección 3.1) menciona "fábricas de objetos" como categoría del Núcleo B, pero no define una ficha de edificio (trabajadores, costo de construcción, ciclo) — solo el consumo por objeto fabricado, transcrito aquí tal cual:

| Objeto | Consume | Estado |
|---|---|---|
| Vidrio | Tierra ×1 | Propuesta (Excel) |
| Cama | Madera ×2 | Propuesta (Excel) |
| Puerta | Madera ×2 | Propuesta (Excel) |
| Baúl | Madera ×1 (provee 30 de almacenamiento al colocarse) | Propuesta (Excel) |

**Ficha de edificio "Fábrica" (genérica):** por definir — el Excel y el GDD dan el consumo por objeto, pero no personal máximo, costo de construcción, ciclo de producción ni capacidad de almacenamiento propios del edificio. No se completan aquí para no mezclar una decisión de balance con esta transcripción (ver CLAUDE.md: "no mezcles las PoC sin una decisión explícita").

---

## Pendientes

- Conciliar la tabla de comida por tipo de unidad (Sección 1) con la tasa de hambre por nivel de avatar (hoja "Niveles") — hoy son dos sistemas de comida sin relacionar en el GDD.
- Confirmar que la columna `Árbol (obj)` (Comida 5) del Excel es la tasa de frutos.
- Balance del acarreo (`CAPACIDAD_CARGA`, cupos) tras jugar.
- Definir personal máximo/costo de construcción/ciclo para: Aserradero, Carbonera, Refinería petrolera, Licuefactora de hidrocarburo, Central termoeléctrica, y el edificio "Fábrica" genérico — cada uno como su propio sub-proyecto/PoC, según el roadmap de la Sección 11 del GDD.

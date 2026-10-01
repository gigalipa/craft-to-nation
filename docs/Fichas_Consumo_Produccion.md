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
| Ciudadano | 2 | — | — | 5 |
| Desempleado | 3 | — | — | 4 |
| Obrero | 5 | — | — | 4 |
| Técnico | 3 | — | — | 3 |
| Especialista | 2 | — | 1 | 2 |
| Investigador | 1 | — | 2 | 1 |
| Militar | 4 | 2 | — | 3 |

- **Comida/h:** implementado como concepto genérico (GDD Sección 6, "Comida como Recurso Genérico"); la tasa de hambre por nivel de avatar está en la hoja "Niveles" (5/4/3 según nivel), no por tipo de unidad — estas dos tablas de comida (por tipo de unidad y por nivel de avatar) todavía no se han conciliado en el GDD.
- **Combustible/h y Energía/h:** propuesta (Excel) — Militar consumiendo combustible e Investigador/Especialista consumiendo energía no está descrito en el GDD todavía; ningún código las aplica.
- **"x Cama":** implementado (`Ciudad.TIPOS_POBLACION`): cuántos habitantes de ese tipo caben por cada cama construida. Cada cama aporta 1 unidad de vivienda y una persona ocupa `1 / x_cama` de ella (vivienda fraccionaria compartida, `Ciudad.vivienda_ocupada`).
- **Obrero:** un `obrero` es ahora un desempleado asignado a un puesto de recolección (`Colonos.contratar`), así que su consumo pasa de 3 (desempleado) a 5 comida/h; combustible y energía siguen sin aplicarse.
- **Técnico:** opera las refinerías. Se forma en la **Escuela técnica**: una cohorte de 4 obreros (`x_cama` 4) estudia 24 h y sale como 3 técnicos (`x_cama` 3), de modo que la vivienda ocupada se conserva (4 × 1/4 = 3 × 1/3) y el cuarto colono se va de la ciudad. Un técnico sin puesto (técnico libre) conserva el oficio y también podrá trabajar en obras como un obrero desempleado. Las refinerías ya no convierten desempleados.
- **Ciudadano:** un `ciudadano` es un NPC que no está en edad de trabajar (niños/ancianos), está sin aplicarse debido a que aún no se ha implementado sistema de nacimientos o envejecimiento. Los niños aumentan la población y su "producción" aumenta en relación con la moral, la cantidada de ancianos y el superhábit de alimento. Habrá la posibilidad de desarrollar y configurar la "eutanasia" por lo que se podrá controlar la cantidad de ancianos. Los ancianos aumentan la moral y la tasa de nacimientos.
- **Vivienda por nivel de ciudad** (hoja "Niveles", `Ciudad.NIVELES_VIVIENDA`): camas por piso × pisos máximos de una casa — nivel 1 = 2 × 2, nivel 2 = 4 × 4, nivel 3 = 4 × 8.
- **Balance 2026-09-28:** decisión del usuario — Ciudadano sube de 4 a 5 "x Cama", Especialista deja de consumir combustible (queda solo con energía) y Militar baja de 3 a 2 combustible/h. Aplicado a `Ciudad.TIPOS_POBLACION` y a la hoja "Relacion" del Excel.

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
| Caza y recolección — caza | Comida | 17 (decisión del usuario, 2026-09-21: 10 en el primer balance del mismo día y 14 en el segundo; reemplaza el venado 15 del Excel, que sigue en la hoja "Relacion") | **Implementado** |
| Caza y recolección — frutos | Comida | 10 (la columna "Árbol (obj)" del Excel decía Comida 5, interpretada como frutos; cambiado a 8 y luego a 10 por decisión del usuario, 2026-09-21) | **Implementado** |
| Pesca y frutos del mar — pesca | Comida | 17 (decisión del usuario, 2026-09-21: 12 en el primer balance del día; sube para compensar el descuento por profundidad, ver la fórmula de pesca más abajo) | **Implementado** |
| Pesca y frutos del mar — algas | Comida | 3 (balance del 2026-09-21; se multiplica por la misma escala por tamaño del agua que la pesca) | **Implementado** |
| Caza — conejo | Comida | 8 | Propuesta (Excel), no implementada |
| Pozo de petróleo | Crudo | 2 | Propuesta (Excel), no implementada |
| Pozo de agua | Agua | 2 | Propuesta (Excel), no implementada |

**Meta de balance de comida (2026-09-21):** cada recolector de comida debe aportar al menos 7,5/h: 5 para sí mismo (consume 5/h) + 2,5 que sostienen a medio acarreador. Con el primer balance de pesca 12 y algas 3 a densidad media 0,5 daba 7,5/h (12 x 0,5 + 3 x 0,5); la pesca ahora se calcula por tamaño y profundidad del agua (ver la fórmula de pesca más abajo). Con el primer balance de caza 10 y frutos 5 el mundo real (semilla 12345, densidad media de fauna 0,45 y de frutal 0,46) daba solo 6,83/h por recolector (p10 5,34, p90 7,95) frente a 8,56/h de la pesca (p10 8,07, p90 9,07), así que el usuario subió caza a 14 y frutos a 8 (2026-09-21) y, como aún quedaba por debajo de una costa buena y obligaba a ciudades costeras, a 17 y 10: 17 x 0,45 + 10 x 0,46 = ~12,25/h (un buen sitio con fauna y frutal de 0,6 da ~15,6/h). La meta se cumple con margen: caza y recolección ~12,2/h, pesca ~8,6/h de media en el mundo actual (pero muy variable según el agua, hasta ~14/h en una costa grande y profunda). Así caza y recolección es la opción estable, disponible en cualquier terreno, y la pesca una apuesta de alto rendimiento que solo iguala a la caza en costas grandes y profundas. Tres obreros (2 recolectores + 1 acarreador) se sostienen solos; con el 4.º recolector sobran 2,5/h para el avatar (5/h a nivel 1). Un puesto más lejano del núcleo rinde menos, porque el acarreador tarda más en cada viaje.

**Fórmula vigente** (`Recoleccion.gd`, `Economia.gd`): la tasa de un recurso = tasa base del Excel × fracción (minerales) o densidad (madera, fauna, frutal, peces, algas) detectada en el área de acción del puesto, por trabajador presente y hora. Un minero reparte su esfuerzo entre los minerales según la composición del área; en caza/recolección y en pesca las dos señales se producen a la vez y se suman en `comida`. El `TASA_BASE_POR_CIUDADANO = 2.0` genérico ya no existe.

**Fórmula de pesca** (`Recoleccion.detectar_pesca_frutos_mar()` y `tasas_pesca_frutos_mar()`, decisión del usuario, 2026-09-21): la pesca depende del tamaño y la profundidad del agua (2026-09-21): los peces de cada celda de agua se ponderan por la profundidad relativa (`peces × (0,5 + (1 − algas))`, de ×0,5 en el agua más somera a ×1,5 en la más profunda, porque `densidad_algas_en = 1 − profundidad relativa`) y ambas tasas (pesca y algas) se multiplican por una escala por tamaño del agua conectada (`celdas / 450`, mínima 0,4 y máxima 1,5; 450 celdas es la mediana del mundo actual dentro del radio 25). La base de pesca sube de 12 a 17 para compensar el descuento por profundidad; la de algas sigue en 3. Las dos tasas son `pesca = peces efectivo medio × 17 × escala` y `frutos_mar = algas medias × 3 × escala`; sin agua conectada todo vale 0. Medido en el mundo real (semilla 12345, 227 puestos costeros candidatos): antes la media era 8,34/h (mín 6,10, p10 6,31, mediana 8,71, p90 9,35, máx 10,17), casi constante porque era un promedio y no importaba el tamaño ni la profundidad del agua; ahora la media es 8,60/h (mín 2,50, p10 3,03, mediana 9,19, p90 12,90, máx 13,98). Un lago pequeño y somero rinde ≈2,5–3 comida/h y una costa grande y profunda ≈13–14, con media ≈8,6 (caza + frutos con 17 y 10 tiene media ≈12,2). Un puesto ya colocado conserva las tasas calculadas al colocarlo (se guardan al colocar), así que los puestos de pesca existentes mantienen los números antiguos hasta reconstruirlos.

Por puesto (`Recoleccion.gd`, iguales en los cuatro salvo lo indicado):

| Puesto | Personal máximo | Almacén local | Huella (ancho × alto) | Radio del área |
|---|---|---|---|---|
| Mina | 5 | 1000 | 5 × 5 | 6 (profundidad 8/16/24 según nivel) |
| Maderero | 5 | 1000 | 3 × 4 | 12 |
| Caza y recolección | 7 | 1000 | 4 × 4 | 12 |
| Pesca y frutos del mar | 7 | 1000 | 4 × 6 | 25 (agua conectada) |

El personal máximo es el cupo total de trabajadores (recolectores + acarreadores) y el almacén local cuenta el total entre recursos. Además: `COSTO_CONSTRUCCION = {"tierra": 10, "madera": 10, "piedra": 5}` (informativo, no se cobra todavía).

---

## Acarreo y almacén central

Fuente: hoja "Economia" de `docs/Recursos.xlsx`, `Economia.gd`, `Ciudad.gd` y `Colonos.gd`.

Flujo: producción de los recolectores presentes → **almacén local** del puesto (tope 1000; el exceso se pierde) → **acarreador** a pie (carga 150 por viaje; ciclo puesto → núcleo urbano → puesto) → **stock central** (madera, comida, hierro, tierra, piedra, cobre, carbón, tierras raras y acero; tope base 500 por recurso, comida 5000; ver la tabla). La comida de caza, frutos, pesca y algas se suma en `comida`. Un tick = 2 s reales = 1 hora de juego; un colono camina 2,5 celdas/s (5 por hora de juego).

| Parámetro | Valor | Fuente |
|---|---|---|
| Duración de un tick | 2 s reales = 1 hora de juego | `Ciudad.SEGUNDOS_POR_TICK` |
| Velocidad de un colono | 2,5 celdas/s | `Colonos.VELOCIDAD_COLONO` |
| Carga de un acarreador | 150 unidades por viaje (placeholder) | `Economia.CAPACIDAD_CARGA` |
| Almacén local de un puesto | 1000 unidades en total | `Recoleccion.CAPACIDAD_ALMACENAMIENTO*` |
| Límite del stock central | 500 por recurso (comida 5000) al empezar; ×2 al declarar el núcleo; cada baúl suma +100 (comida +400) | `Ciudad.LIMITE_BASE*`, `FACTOR_NUCLEO`, `BONO_BAUL*`, `recalcular_limites()` |
| Stock inicial | comida 5000, madera 200, el resto 0 (hierro y acero incluidos) | `Ciudad.almacen` |
| Migración de colonos | 0,5 por hora de juego (con vivienda libre y sin hambruna) | `Ciudad.TASA_MIGRACION` |
| Consumo de un obrero de puesto | 5 comida/h (desempleado: 3) | `Ciudad.TIPOS_POBLACION` |

Todavía no existe: energía completa (el costo de colocación en recursos y la siderúrgica real ya están implementados, ver la tabla de extracción abajo y la Sección 3), carretas y carreteras (sub-proyecto 6), moral y nivel del puesto, y drones o transporte automatizado.

---

## Extracción: bloques minables, unidades de recurso y bloques colocables

Fuente: hoja "Extraccion" de `docs/Recursos.xlsx`, `Recoleccion.RENDIMIENTO_POR_BLOQUE`, `Recoleccion.TIEMPO_MINADO` (sub-proyecto 2B) y `NiveladorTerreno.COSTO_POR_CELDA` (sub-proyecto 2C, parte 1, implementado — ver `docs/superpowers/specs/2026-09-29-costo-colocacion-bloques-design.md`). Modelo de tres capas: **bloque de extracción** (lo que se retira del mundo, sea por el avatar minando/talando o por un puesto) → **unidades de recurso** (lo que entra al almacén/inventario) → **bloque de construcción** (lo que se coloca de vuelta, cobrado de `Ciudad.almacen` al colocar y reembolsado al volver a minarlo).

| Bloque minable | Unidades de recurso | Bloque colocable | Unidades por bloque colocado | Estado |
|---|---|---|---|---|
| 1 bloque de tierra (incluye la capa "hierba") | 1 tierra | `tierra` (natural) / `tierra_compactada` (estructural) | 1 tierra cada uno | **Implementado** |
| 1 bloque de piedra | 10 piedra | `bloque_piedra` | 5 piedra | **Implementado** |
| 1 bloque de hierro | 10 hierro | `estructura_hierro` | 5 hierro | **Implementado** |
| 1 tronco (por celda de tronco; el follaje no rinde) | 10 madera | `bloque_madera` | 5 madera | **Implementado** |
| — (no se mina; se fabrica) | — | `vidrio` | 1 tierra | **Implementado** |
| Cobre, carbón, tierras raras | 10 c/u | — (no tienen bloque colocable) | — | Extracción implementada; sin bloque de construcción, sin uso todavía |
| 3 acero (de la siderúrgica; no se mina) | — | `bloque_acero` | 3 acero | **Implementado** |
| Agua | 2 agua | — (no tienen bloque colocable) | — | Reservado, sin uso todavía |
| Petróleo | 2 crudo | — (no tienen bloque colocable) | — | Reservado, sin uso todavía |

- **Bloques minables vs. colocados:** una mina o el avatar minando solo retira bloques del **terreno natural** (`VoxelWorld.es_terreno_natural`); un bloque que el jugador ya colocó, al volver a minarlo, regresa lo mismo que costó al colocar (`VoxelWorld._reembolsar_si_corresponde()`), para que colocar y minar en bucle no cree recursos.
- **Cobre, carbón, tierras raras y los líquidos (agua, crudo) no se convierten en bloques colocables**: son insumos de refinería/energía (Sección 3), no material de construcción — el Excel y el código no les definen un bloque de construcción.
- **`bloque_acero`** (3 acero por bloque, décima casilla de la hotbar, tecla `0`) ya tiene fuente real de `acero`: la siderúrgica real lo entrega al stock central (Sección 3).
- `puerta` (2 madera), `cama` (2 madera) y `baúl` (1 madera) también están implementados con costo real, ver la Sección 2 del spec de 2026-09-29 — coinciden con la "Ficha de Fábrica" (Sección 4 de este documento), que ya tenía estos montos correctos.

---

## 3. Fichas de Refinería

Fuente: hoja "Relacion", columnas AD–AQ, y hoja "Recetas".

| Refinería | Consume | Produce | Ciclo (h) | Almacén (entra/sale) | Estado | Fuente |
|---|---|---|---|---|---|---|
| Siderúrgica | Hierro ×2 | Acero ×1 | 1 | 1 / 2 | **Implementado (edificio real)** | `CadenaMinerales.gd` (receta "hierro"), `Economia.gd`, `Colonos.gd` |
| Refinería de mineral | Tierras raras ×3 | Mineral refinado ×1 | 2 | 1 / 3 | **Implementado (edificio real)** | `CadenaMinerales.gd` (receta "tierras_raras") |
| Aserradero | Madera ×1 | Tablas ×3 (cuentan como "madera", GDD Sec. 4) | 2 | 3 / 1 | **Implementado (edificio real)** | `CadenaMinerales.gd` (receta "aserradero", `tasa_base` 0,5) |
| Carbonera | Madera ×3 | Carbón ×1 | 1 | 1 / 3 | **Implementado (edificio real)** | `CadenaMinerales.gd` (receta "carbonera", `tasa_base` 2,0). Confirma la corrección del GDD (madera→carbón) |
| Refinería petrolera | Crudo ×2 **y** Energía ×1 | Combustible ×1 | 1 | 1 / 2 | Propuesta (Excel), no implementada | — |
| Licuefactora de hidrocarburo | Carbón ×3, Agua ×1 **y** Energía ×1 | Combustible ×2 | 1 | 1 / 4 | Propuesta (Excel), no implementada | — |
| Central termoeléctrica | Carbón ×1 **o** Crudo ×1 **o** Combustible ×1 (cualquiera de los tres) | Energía ×20 | 1 | 60/30/10 (según insumo) / — | Propuesta (Excel), no implementada | — |

`tasa_base` (lotes/técnico/hora, `CadenaMinerales.RECETAS`): siderúrgica `2.0`, tierras raras `0.5`, aserradero `0.5`, carbonera `2.0` — la tabla de arriba muestra cantidades por ciclo de receta, no por ciudadano; ver `CadenaMinerales.procesar_tick()` para la fórmula completa (demanda teórica recortada a lo disponible en almacén).

Siderúrgica real: plantilla de 5×5 en `bloque_piedra` con puertas de entrada y salida separadas (la de entrada decide la altura y el frente de la salida se nivela a ella); personal máximo 3 técnicos; almacén local de 1000 compartido entre hierro y acero; velocidad = técnicos presentes × 4 hierro/h → 2 acero/h por técnico. Un solo acarreador hace el ciclo núcleo → entrada → salida → núcleo (mínimo 10 unidades por viaje, `Economia.CARGA_MINIMA`). Si se despide al acarreador (o se quita el puesto) con hierro en fase de entrada, ese hierro vuelve al stock; el producto de la refinería y la carga de recolección se pierden. Al deconstruir un puesto (de cualquier tipo), lo que quepa de su almacén local pasa automáticamente al núcleo urbano; el resto se pierde. Su costo de construcción es el de los bloques de su plantilla (las constantes `COSTO_CONSTRUCCION_REFINERIA_*` no se usan). Las cuatro refinerías comparten personal máximo 4 y almacén local 1000 (`CadenaMinerales.PERSONAL_MAXIMO_REFINERIA`); cada una tiene plantilla, material e indicador de actividad propios (ver el documento técnico de PoC 5). Las **tablas** del aserradero son un recurso aparte del stock central pero cuentan como madera al pagar construcciones (`Ciudad.consumir_costo()`).

Refinerías propuestas todavía sin `PERSONAL_MAXIMO_*`/`COSTO_CONSTRUCCION_*` definidos — mismo criterio que dejó pendientes madera/fluidos/energía en el documento técnico de PoC 5 ("Próximos Pasos"): no se inventan aquí.

---

## 4. Fichas de Fábrica

Fuente: hoja "Relacion", columnas J–M ("Consumo por Objeto"). El GDD (Sección 3.1) menciona "fábricas de objetos" como categoría del Núcleo B, pero no define una ficha de edificio (trabajadores, costo de construcción, ciclo) — solo el consumo por objeto fabricado, transcrito aquí tal cual:

| Objeto | Consume | Estado |
|---|---|---|
| Vidrio | Tierra ×1 | **Implementado** (`NiveladorTerreno.COSTO_POR_CELDA`) |
| Cama | Madera ×2 | **Implementado** |
| Puerta | Madera ×2 | **Implementado** |
| Baúl | Madera ×1 (provee 30 de almacenamiento al colocarse) | **Implementado** |

**Ficha de edificio "Fábrica" (genérica):** por definir — el Excel y el GDD dan el consumo por objeto, pero no personal máximo, costo de construcción, ciclo de producción ni capacidad de almacenamiento propios del edificio. No se completan aquí para no mezclar una decisión de balance con esta transcripción (ver CLAUDE.md: "no mezcles las PoC sin una decisión explícita").

---

## Pendientes

- Conciliar la tabla de comida por tipo de unidad (Sección 1) con la tasa de hambre por nivel de avatar (hoja "Niveles") — hoy son dos sistemas de comida sin relacionar en el GDD.
- La tasa de frutos parte de la columna `Árbol (obj)` (Comida 5) del Excel, interpretada como frutos; hoy vale 10 por decisión del usuario (2026-09-21; antes 8).
- Balance del acarreo (`CAPACIDAD_CARGA`, cupos) tras jugar.
- Ajustar tras jugar los parámetros de la pesca por tamaño y profundidad (`PECES_FACTOR_SOMERO` 0,5, `AGUA_REFERENCIA` 450, `ESCALA_AGUA_MIN` 0,4, `ESCALA_AGUA_MAX` 1,5, base 17): los puestos de pesca ya colocados conservan las tasas antiguas hasta reconstruirlos.
- Verificar jugando que 2 recolectores + 1 acarreador se sostienen (la meta de 7,5/h por recolector se cumple con margen de media en el mundo actual, caza y recolección ~12,2/h y pesca ~8,6/h; pero un lago pequeño y somero rinde solo ≈2,5–3/h por la nueva escala de pesca y no la cumple; con menos densidad, por ejemplo poca fauna, o con un puesto más lejano, puede no cumplirse).
- Formación de especialistas (escuela propia, solo con técnicos libres): sin diseñar; ver docs/ideas-backlog.md.
- ~~Edificio real de la refinería de tierras raras, aserradero y carbonera~~ — ✅ hecho (2026-10-01).
- Definir personal máximo/costo de construcción/ciclo para: Refinería petrolera, Licuefactora de hidrocarburo, Central termoeléctrica, y el edificio "Fábrica" genérico — cada uno como su propio sub-proyecto/PoC, según el roadmap de la Sección 11 del GDD.
- ~~Definir el costo en unidades de recurso del bloque de madera colocable... Implica también programar el reembolso al volver a minar un bloque colocado.~~ — ✅ hecho (2026-09-29): `Player._colocar()` cobra de `Ciudad.almacen` según `NiveladorTerreno.COSTO_POR_CELDA` y `VoxelWorld._retirar_bloque()` reembolsa exactamente lo cobrado al volver a minar, ver `docs/superpowers/specs/2026-09-29-costo-colocacion-bloques-design.md`.

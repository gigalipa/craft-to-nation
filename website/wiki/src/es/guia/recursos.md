---
title: "Recursos, Industrias y Energía"
description: "Catálogo de recursos, 6 minerales por cota de profundidad, materiales de construcción, cadenas de refinación, fábrica de bloques y red eléctrica."
---

# Recursos, Industrias y Energía

![Complejo industrial y procesamiento de recursos en primera persona](/assets/fp-industry.webp)

La economía de **Craft to Nation** se fundamenta en un ecosistema físico de recursos naturales, fluidos dinámicos, insumos energéticos y bienes manufacturados. Cada recurso cuenta con iconos vectoriales pixel-art propios en el HUD (`IconosHUD.gd`), listado de **materias primas en orden alfabético A–Z con desplegables jerárquicos (`▶`/`▼`) para sus recursos refinados y las 6 categorías de comida** (más un botón **`[Expandir todo]` / `[Contraer todo]`** en el encabezado de `VentanaAlmacen`), reservas estratégicas porcentuales (`0%–50%`) y tasas de extracción auditadas en el motor de simulación.

---

## 1. Catálogo de Recursos Primarios y Manufacturados (`VentanaAlmacen` con Desplegables)

| Recurso | Categoría | Fuente Principal | Método de Obtención |
| :--- | :--- | :--- | :--- |
| <ResourceBadge name="Acero" category="Aleación" /> | Rascacielos / Tuberías *(bajo Hierro)* | Siderúrgica (`1 -> 3 -> 1`) | `3 Hierro + 4 Carbón` → `2 Acero` |
| <ResourceBadge name="Agua" category="Vital" /> | Vital / Fluido | Ríos, lagos, mares y acuíferos | Estación de bombeo (`1 -> 2 -> 5`), centro de extracción y acueductos |
| <ResourceBadge name="Bloques de Piedra" category="Procesado" /> | Mampostería Eficiente *(bajo Piedra)* | Fábrica de Bloques (`1 -> 3 -> 4`) | `1 Piedra` → `3 Bloques de Piedra` (se consume primero al construir con piedra) |
| <ResourceBadge name="Carbón" category="Energético" /> | Siderurgia / Vidriera / Termoeléctrica | Vetas subterráneas o Carbonera | Mina (`10 u/bloque`) o Carbonera (`1 -> 3 -> 6`: `3 Madera` → `1 Carbón`) |
| <ResourceBadge name="Cobre" category="Mineral" /> | Conducción / Tecnología | Vetas medias (`prof. 8–16`) | Mina Nivel II+ (`10 u/bloque`) |
| <ResourceBadge name="Combustible" category="Fluido" /> | Combustible Líquido *(bajo Crudo/Carbón)* | Refinería Petrolera / Productor | `2 Crudo` → `1 Combustible` o `3 Carbón + 1 Agua` → `2 Combustible` |
| <ResourceBadge name="Comida" category="Vital" /> | Vital / Metabólico *(6 subcategorías)* | Fauna, árboles frutales, granjas y pesca | Despliega: `Frutos silvestres`, `Carne de caza`, `Pescado y algas`, `Cultivos agrícolas`, `Panadería y granos`, `Conservas industriales` |
| <ResourceBadge name="Crudo" category="Fluido" /> | Petroquímica / Energía | Yacimientos profundos (`prof. >= 4`) | Centro de Extracción (`1 -> 2 -> 6`) con columna de perforación de hierro |
| <ResourceBadge name="Hierro" category="Mineral" /> | Metalurgia / Estructuras | Vetas medias (`prof. 8–16`) | Mina Nivel II+ (`10 u/bloque`) |
| <ResourceBadge name="Madera" category="Básico" /> | Construcción / Insumo | Bosques del mundo procedural | Tala manual con <kbd>Clic Izq.</kbd> (`10 u/celda`) o Puesto Maderero (`1 -> 2 -> 2`) |
| <ResourceBadge name="Mineral Refinado" category="Avanzado" /> | Componentes Avanzados *(bajo Tierras Raras)* | Refinería de Tierras Raras (`1 -> 3 -> 2`) | `3 Tierras Raras` → `1 Mineral Refinado` |
| <ResourceBadge name="Piedra" category="Básico" /> | Construcción / Insumo | Afloramientos y subsuelo | Minado manual (`10 u/bloque`) o Mina (`1 -> 2 -> 3`) |
| <ResourceBadge name="Tablas" category="Procesado" /> | Construcción Eficiente *(bajo Madera)* | Aserradero (`1 -> 3 -> 3`) | `1 Madera` → `3 Tablas` (se consume primero al construir con madera) |
| <ResourceBadge name="Tierra" category="Básico" /> | Nivelación / Adobe / Insumo de Vidrio | Capa superficial (`GROSOR_TIERRA`) | Minado manual (`1 u/bloque`) o Mina |
| <ResourceBadge name="Tierras Raras" category="Avanzado" /> | Alta Tecnología | Estratos profundos (`prof. 16–24`) | Mina Nivel III (`10 u/bloque`) |
| <ResourceBadge name="Vidrio" category="Procesado" /> | Ventanas / Cabinas de Vehículos *(bajo Tierra)* | Vidriera (`1 -> 3 -> 5`) | `1 Tierra + 1 Carbón` → `3 Vidrio` (se consume primero en bloques de ventana y es exclusivo en vehículos) |
| <ResourceBadge name="Energía" category="Red Eléctrica" /> | Alimentación Industrial | Central Termoeléctrica (`1 -> 3 -> 9`) | Generación continua en red (`kW`), hasta `20 E/h` por planta |

---

## 2. Tasas Base de Extracción en Puestos Periféricos (`1 -> 2 -> 1..6`)

Todos los puestos periféricos deben emplazarse **fuera de la Zona de Influencia** del Núcleo Urbano:

| Menú | Puesto Periférico | Recurso Obtenido | Tasa Base (u/trabajador/h) | Personal | Almacén Local | Huella y Requisitos |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`1-2-1`** | **Caza y Recolección** (`caza_recoleccion`) | <ResourceBadge name="Comida" /> | **17,0** caza + **10,0** frutos (`~12,2 u/h` media) | Hasta 7 obreros | 1.000 u | `4×4` celdas / Radio 12 |
| **`1-2-2`** | **Puesto Maderero** (`maderero`) | <ResourceBadge name="Madera" /> | **5,0** × densidad × nivel | Hasta 5 obreros | 1.000 u | `3×4` celdas / Radio 12 |
| **`1-2-3`** | **Mina** (`mina`) | <ResourceBadge name="Piedra" /> <ResourceBadge name="Hierro" /> <ResourceBadge name="Cobre" /> <ResourceBadge name="Carbón" /> <ResourceBadge name="Tierras Raras" /> <ResourceBadge name="Tierra" /> | **5,0** minerales / **1,0** tierra (× fracción de veta) | Hasta 5 mineros | 1.000 u | `5×5` celdas / Radio 6 / Prof. **8 / 16 / 24** |
| **`1-2-4`** | **Pesca y Frutos del Mar** (`pesca_frutos_mar`) | <ResourceBadge name="Comida" /> | **17,0** pesca + **3,0** algas (`~8,6 u/h` media) | Hasta 7 obreros | 1.000 u | `4×6` celdas (mitad tierra / mitad agua) / Radio 25 |
| **`1-2-5`** | **Estación de Bombeo** (`estacion_bombeo`) | <ResourceBadge name="Agua" /> | **2,0** u/h por técnico | 3 técnicos (0 acarreadores) | 500 u | `4×6` celdas (requiere **`>= 2` bloques de profundidad de agua** bajo su muelle; puerto `puerto_agua_out` en `Y + 4`) |
| **`1-2-6`** | **Centro de Extracción** (`centro_extraccion`) | <ResourceBadge name="Crudo" /> / <ResourceBadge name="Agua" /> | **2,0** u/h por técnico | 3 técnicos (0 acarreadores) | 500 u | `5×5` celdas sobre pozo subterráneo (añade costo de `estructura_hierro` según profundidad y genera columna física de perforación) |

> [!NOTE] Niveles de Puesto (I, II, III) y Regla del Rango Mínimo
> - En **Puesto Maderero**, **Caza** y **Pesca**, los niveles aplican un multiplicador de velocidad (**Nivel I = `1,0×`**, **Nivel II = `1,5×`**, **Nivel III = `2,0×`**). En las **Minas**, amplían la profundidad de excavación (**8 / 16 / 24 capas**).
> - **Regla del Rango Mínimo:** El nivel efectivo del puesto lo determina el **rango mínimo entre sus recolectores contratados**. Si una Mina de Nivel II (operada por 1 Técnico) contrata además a 1 Obrero, el puesto permite contratarlo y regresa limpiamente a **Nivel I** hasta que todos sus recolectores sean al menos Técnicos.

---

## 3. Costos de Construcción y Control de Reserva Central Porcentual (`0% – 50%`)

Al colocar bloques manualmente o abastecer obras, `Ciudad.gd` **descuenta primero los materiales procesados** (`Tablas`, `Bloques de piedra` y `Vidrio`) antes de gastar madera, piedra o tierra en bruto, y muestra como disponibilidad total los bloques efectivos construibles:

| Bloque Colocable | Material en Almacén | Costo por Bloque | Equivalencia con Material Procesado |
| :--- | :--- | :--- | :--- |
| **`tierra`** | <ResourceBadge name="Tierra" /> | `1 Tierra` | — |
| **`adobe`** | <ResourceBadge name="Tierra" /> | `5 Tierra` | — |
| **`vidrio` *(Bloque de Ventana)*** | <ResourceBadge name="Vidrio" /> o <ResourceBadge name="Tierra" /> | `1 Vidrio` (o `3 Tierra` si no hay vidrio) | **1 Tierra + 1 Carbón → 3 Vidrio** *(en vehículos como camiones y trolebuses solo se admite `Vidrio`, nunca `Tierra`)* |
| **`bloque_madera` / `puerta` / `cama` / `baul`** | <ResourceBadge name="Tablas" /> o <ResourceBadge name="Madera" /> | `1 Tabla` (o `5 Madera`) por celda | **1 Madera → 3 Tablas** (multiplica ×15 la eficiencia constructiva) |
| **`bloque_piedra`** | <ResourceBadge name="Bloques de Piedra" /> o <ResourceBadge name="Piedra" /> | `1 Bloque de Piedra` (o `5 Piedra`) | **1 Piedra → 3 Bloques** (multiplica ×15 la eficiencia constructiva) |
| **`estructura_hierro`** | <ResourceBadge name="Hierro" /> | `5 Hierro` | — |
| **`bloque_acero`** | <ResourceBadge name="Acero" /> | `3 Acero` | — |

### Selector Porcentual de Reserva Central en Refinerías y Termoeléctrica (`0%` a `50%`)
En el `PanelPuesto` de cada refinería o central termoeléctrica, debajo de la línea de producción aparece la fila **`Reserva central:`** acompañada de botones de subir y bajar (**`▲` `btn_subir.svg` / `▼` `btn_bajar.svg`**) que ajustan el umbral entre **`0% (Sin reserva)` → `10%` → `20%` → `30%` → `40%` → `50%`** de la capacidad del almacén central. Los acarreadores de esa planta solo retirarán el excedente por encima del porcentaje reservado, protegiendo tus materiales de construcción contra el sobre-refinado.

---

## 4. Instalaciones Industriales, Energéticas y de Transporte (`1 -> 3 -> 1..10` en Zona Industrial)

Todas las refinerías requieren **Técnicos (`Técnicos`)** graduados en la Escuela Técnica (`1 -> 4 -> 1`) para producir:

| Menú | Instalación Industrial | Huella | Personal | Receta por Lote (Entradas → Salida) | Lotes/h por Trabajador | Consumo / Generación Eléctrica |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`1-3-1`** | **Siderúrgica** (`siderurgica`) | `5×5` | 4 Técnicos + Acarreadores | `3 Hierro + 4 Carbón` → `2 Acero` | `2,0 lotes/h` (`4,0 acero/h`) | `0 E` |
| **`1-3-2`** | **Refinería Tierras Raras** (`refineria_tierras_raras`) | `5×5` | 4 Técnicos + Acarreadores | `3 Tierras Raras` → `1 Mineral Refinado` | `0,5 lotes/h` (`0,5 ref/h`) | `0 E` |
| **`1-3-3`** | **Aserradero** (`aserradero`) | `5×6` | 4 Técnicos + Acarreadores | `1 Madera` → `3 Tablas` | `0,5 lotes/h` (`1,5 tablas/h`) | `0 E` |
| **`1-3-4`** | **Fábrica de Bloques** (`fabrica_bloques`) | `5×6` | 4 Técnicos + Acarreadores | `1 Piedra` → `3 Bloques de Piedra` | `0,5 lotes/h` (`1,5 bloques/h`) | `0 E` |
| **`1-3-5`** | **Vidriera** (`vidriera`) | `5×6` *(adobe)* | 4 Técnicos + Acarreadores | `1 Tierra + 1 Carbón` → `3 Vidrio` | `0,5 lotes/h` (`1,5 vidrio/h`) | `0 E` |
| **`1-3-6`** | **Carbonera** (`carbonera`) | `5×5` | 4 Técnicos + Acarreadores | `3 Madera` → `1 Carbón` | `2,0 lotes/h` (`2,0 carbón/h`) | `0 E` |
| **`1-3-7`** | **Refinería Petrolera** (`refineria_petrolera`) | `5×5` | 4 Técnicos (sin acarreadores: usa ductos) | `2 Crudo` → `1 Combustible` | `1,0 lote/h` (`1,0 comb/h`) | Consume **1 E/lote** (Tope local: `400 Crudo / 600 Combustible`) |
| **`1-3-8`** | **Productor Combustible** (`productor_combustible`) | `5×5` | 4 Técnicos + Acarreadores (solo acarrean `carbón`) | `3 Carbón + 1 Agua` → `2 Combustible` | `1,0 lote/h` (`2,0 comb/h`) | Consume **1 E/lote** (`puerto_agua_in` + `puerto_combustible_out`) |
| **`1-3-9`** | **Central Termoeléctrica** (`central_termoelectrica`) | `5×5` | 4 Técnicos (+ Acarreadores en modo `[Carbón]`) | Selector: `[Carbón]` (`2:1`), `[Crudo]` (`1,5:1`) o `[Combustible]` (`1:1`) | Hasta `5,0 E/h` por técnico | Genera hasta **20 E/h** (en modo `[Combustible]` o `[Crudo]` libera acarreadores y se alimenta por tubería) |
| **`1-3-0`** | **Taller de Transporte / Almacén** (`taller_transporte` / `almacen`) | `5×6` / `5×5` | Técnicos (Taller) / 0 (Almacén) | Ensamblaje de 6 tipos de vehículos logísticos / **6 puertos de fluidos en `Y=4`** (`agua`, `crudo`, `combustible`) | Parque móvil / Pool global de fluidos (`1.000 u/almacén`) + `+3.000 u` sólidos | `0 E` |

### Estados del Monitor de Energía y su Iconografía en la Barra Superior

El botón de **Energía** en la barra superior del HUD (`BarraSuperior.gd`) y la **Ventana de Red Eléctrica** (`VentanaEnergia.gd`) reflejan en tiempo real el balance entre generación y demanda eléctrica de la colonia a través de tres estados e íconos vectoriales dinámicos:

| Ícono | Estado en HUD | Condición de Simulación (`BarraSuperior.gd`) | Efecto en la Colonia y la Industria |
| :---: | :--- | :--- | :--- |
| ![Superávit](/icons/energia_dorado.svg) | **Dorado (`energia_dorado.svg`)**<br>*(Suministro Estable / Superávit)* | `capacidad >= demanda` y `capacidad > 0`<br>Lectura: `+X kW` o `0 kW` neto | **Operación normal (100%):** Todas las industrias consumidoras conectadas trabajan a plena capacidad. La lámpara eléctrica del avatar recarga batería en zona cívica (`+7,2 h/tick`). Sin penalizaciones. |
| ![Sin Demanda](/icons/energia_gris.svg) | **Gris (`energia_gris.svg`)**<br>*(Sin Demanda Activa)* | `capacidad <= 0` y `demanda <= 0`<br>Lectura: `0 kW` | **Estado neutral:** No hay generadores activos ni consumidores conectados demandando energía (frecuente en etapas iniciales antes de la industrialización). Sin penalizaciones ni efectos. |
| ![Déficit](/icons/energia_rojo.svg) | **Rojo (`energia_rojo.svg`)**<br>*(Déficit Eléctrico Crítico)* | `demanda > 0` y `entregada < demanda`<br>(o bandera `deficit == true`)<br>Lectura: `-X kW` neto | **Sobrecarga y déficit:** La producción de las refinerías consumidoras se reduce proporcionalmente a la energía entregada (`entregada / demanda`). Además, impone una penalización en la moral cívica diaria de hasta **-1,5 puntos / día**. |

> [!IMPORTANT] Ventana de Energía (`VentanaEnergia`) y Teletransporte de Cámara
> Al hacer clic en el botón **Energía** de la barra superior (`energia_dorado.svg`, `energia_gris.svg` o `energia_rojo.svg` con lectura en `kW`), se abre **`VentanaEnergia`** mostrando la capacidad generada, energía entregada, demanda total y las listas de **Fuentes Generadoras** y **Edificios Consumidores**. Si haces clic sobre cualquier edificio de la lista, la **Cámara Cenital vuela suavemente (`Tween`) hasta centrarse sobre sus coordenadas exactas** y abre su panel lateral para inspección inmediata.

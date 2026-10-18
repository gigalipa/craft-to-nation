# Recursos, Industrias y Energía

![Complejo industrial y procesamiento de recursos en primera persona](/assets/fp-industry.webp)

La economía de **Craft to Nation** se fundamenta en un ecosistema físico de recursos naturales, fluidos dinámicos, insumos energéticos y bienes manufacturados. Cada recurso cuenta con iconos vectoriales pixel-art propios en el HUD (`IconosHUD.gd`), orden alfabético A–Z en `VentanaAlmacen`, reservas estratégicas y tasas de extracción auditadas en el motor de simulación.

---

## 1. Catálogo de Recursos Primarios y Manufacturados (Orden A–Z en Almacén)

| Recurso | Categoría | Fuente Principal | Método de Obtención |
| :--- | :--- | :--- | :--- |
| <ResourceBadge name="Acero" category="Aleación" /> | Rascacielos / Tuberías | Siderúrgica (`1 -> 3 -> 1`) | `3 Hierro + 4 Carbón` → `2 Acero` |
| <ResourceBadge name="Agua" category="Vital" /> | Vital / Fluido | Ríos, lagos, mares y acuíferos | Estación de bombeo (`1 -> 2 -> 5`), centro de extracción y acueductos |
| <ResourceBadge name="Bloques de Piedra" category="Procesado" /> | Mampostería Eficiente | Fábrica de Bloques (`1 -> 3 -> 4`) | `1 Piedra` → `3 Bloques de Piedra` (se consume primero al construir con piedra) |
| <ResourceBadge name="Carbón" category="Energético" /> | Siderurgia / Termoeléctrica | Vetas subterráneas o Carbonera | Mina (`10 u/bloque`) o Carbonera (`1 -> 3 -> 5`: `3 Madera` → `1 Carbón`) |
| <ResourceBadge name="Cobre" category="Mineral" /> | Conducción / Tecnología | Vetas medias (`prof. 8–16`) | Mina Nivel II+ (`10 u/bloque`) |
| <ResourceBadge name="Combustible" category="Fluido" /> | Combustible Líquido | Refinería Petrolera / Productor | `2 Crudo` → `1 Combustible` o `3 Carbón + 1 Agua` → `2 Combustible` |
| <ResourceBadge name="Comida" category="Vital" /> | Vital / Metabólico | Fauna, árboles frutales y cardúmenes | Recolección manual con <kbd>E</kbd> (`60 u`), puesto de caza y muelle de pesca |
| <ResourceBadge name="Crudo" category="Fluido" /> | Petroquímica / Energía | Yacimientos profundos (`prof. >= 4`) | Centro de Extracción (`1 -> 2 -> 6`) con columna de perforación de hierro |
| <ResourceBadge name="Hierro" category="Mineral" /> | Metalurgia / Estructuras | Vetas medias (`prof. 8–16`) | Mina Nivel II+ (`10 u/bloque`) |
| <ResourceBadge name="Madera" category="Básico" /> | Construcción / Insumo | Bosques del mundo procedural | Tala manual con <kbd>Clic Izq.</kbd> (`10 u/celda`) o Puesto Maderero (`1 -> 2 -> 2`) |
| <ResourceBadge name="Mineral Refinado" category="Avanzado" /> | Componentes Avanzados | Refinería de Tierras Raras (`1 -> 3 -> 2`) | `3 Tierras Raras` → `1 Mineral Refinado` |
| <ResourceBadge name="Piedra" category="Básico" /> | Construcción / Insumo | Afloramientos y subsuelo | Minado manual (`10 u/bloque`) o Mina (`1 -> 2 -> 3`) |
| <ResourceBadge name="Tablas" category="Procesado" /> | Construcción Eficiente | Aserradero (`1 -> 3 -> 3`) | `1 Madera` → `3 Tablas` (se consume primero al construir con madera) |
| <ResourceBadge name="Tierra" category="Básico" /> | Nivelación / Adobe / Vidrio | Capa superficial (`GROSOR_TIERRA`) | Minado manual (`1 u/bloque`) o Mina |
| <ResourceBadge name="Tierras Raras" category="Avanzado" /> | Alta Tecnología | Estratos profundos (`prof. 16–24`) | Mina Nivel III (`10 u/bloque`) |
| <ResourceBadge name="Energía" category="Red Eléctrica" /> | Alimentación Industrial | Central Termoeléctrica (`1 -> 3 -> 8`) | Generación continua en red (`kW`), hasta `20 E/h` por planta |

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

## 3. Costos de Construcción y Control de Reserva Central (`0 / 50 / 100 / 250 / 500 u`)

Al colocar bloques manualmente o abastecer obras, `Ciudad.gd` **descuenta primero los materiales procesados** (`Tablas` y `Bloques de piedra`) antes de gastar madera o piedra en bruto, y muestra como disponibilidad total la suma de ambos stocks:

| Bloque Colocable | Material en Almacén | Costo por Bloque | Equivalencia con Material Procesado |
| :--- | :--- | :--- | :--- |
| **`tierra` / `vidrio`** | <ResourceBadge name="Tierra" /> | `1 Tierra` | — |
| **`adobe`** | <ResourceBadge name="Tierra" /> | `5 Tierra` | — |
| **`bloque_madera` / `puerta` / `cama` / `baul`** | <ResourceBadge name="Tablas" /> o <ResourceBadge name="Madera" /> | `1 Tabla` (o `5 Madera`) por celda | **1 Madera → 3 Tablas** (multiplica ×15 la eficiencia constructiva) |
| **`bloque_piedra`** | <ResourceBadge name="Bloques de Piedra" /> o <ResourceBadge name="Piedra" /> | `1 Bloque de Piedra` (o `5 Piedra`) | **1 Piedra → 3 Bloques** (multiplica ×15 la eficiencia constructiva) |
| **`estructura_hierro`** | <ResourceBadge name="Hierro" /> | `5 Hierro` | — |
| **`bloque_acero`** | <ResourceBadge name="Acero" /> | `3 Acero` | — |

### Selector de Reserva Central en Refinerías y Termoeléctrica
En el `PanelPuesto` de cada refinería o central termoeléctrica, debajo de la línea de producción aparece la fila **`Reserva central:`** con un botón que cicla entre **`Sin reserva (0 u)` → `50 u` → `100 u` → `250 u` → `500 u`**. Los acarreadores de esa planta solo retirarán el excedente por encima de la reserva configurada (`stock_central - reserva`), protegiendo tus materiales de construcción contra el sobre-refinado.

---

## 4. Instalaciones Industriales y Energéticas (`1 -> 3 -> 1..9` en Zona Industrial)

Todas las refinerías requieren **Técnicos (`Técnicos`)** graduados en la Escuela Técnica (`1 -> 4 -> 1`) para producir. Las instalaciones `6`, `7` y `8` se desbloquean tras completar la investigación **Metalurgia Aplicada** en la Universidad (`1 -> 4 -> 3`):

| Menú | Instalación Industrial | Huella | Personal | Receta por Lote (Entradas → Salida) | Lotes/h por Trabajador | Consumo / Generación Eléctrica |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`1-3-1`** | **Siderúrgica** (`siderurgica`) | `5×5` | 4 Técnicos + Acarreadores | `3 Hierro + 4 Carbón` → `2 Acero` | `2,0 lotes/h` (`4,0 acero/h`) | `0 E` |
| **`1-3-2`** | **Refinería Tierras Raras** (`refineria_tierras_raras`) | `5×5` | 4 Técnicos + Acarreadores | `3 Tierras Raras` → `1 Mineral Refinado` | `0,5 lotes/h` (`0,5 ref/h`) | `0 E` |
| **`1-3-3`** | **Aserradero** (`aserradero`) | `5×6` | 4 Técnicos + Acarreadores | `1 Madera` → `3 Tablas` | `0,5 lotes/h` (`1,5 tablas/h`) | `0 E` |
| **`1-3-4`** | **Fábrica de Bloques** (`fabrica_bloques`) | `5×6` | 4 Técnicos + Acarreadores | `1 Piedra` → `3 Bloques de Piedra` | `0,5 lotes/h` (`1,5 bloques/h`) | `0 E` |
| **`1-3-5`** | **Carbonera** (`carbonera`) | `5×5` | 4 Técnicos + Acarreadores | `3 Madera` → `1 Carbón` | `2,0 lotes/h` (`2,0 carbón/h`) | `0 E` |
| **`1-3-6`** | **Refinería Petrolera** (`refineria_petrolera`) | `5×5` | 4 Técnicos (sin acarreadores: usa ductos) | `2 Crudo` → `1 Combustible` | `1,0 lote/h` (`1,0 comb/h`) | Consume **1 E/lote** (Tope local: `400 Crudo / 600 Combustible`) |
| **`1-3-7`** | **Productor Combustible** (`productor_combustible`) | `5×5` | 4 Técnicos + Acarreadores (solo acarrean `carbón`) | `3 Carbón + 1 Agua` → `2 Combustible` | `1,0 lote/h` (`2,0 comb/h`) | Consume **1 E/lote** (`puerto_agua_in` + `puerto_combustible_out`) |
| **`1-3-8`** | **Central Termoeléctrica** (`central_termoelectrica`) | `5×5` | 4 Técnicos (+ Acarreadores en modo `[Carbón]`) | Selector: `[Carbón]` (`2:1`), `[Crudo]` (`1,5:1`) o `[Combustible]` (`1:1`) | Hasta `5,0 E/h` por técnico | Genera hasta **20 E/h** (en modo `[Combustible]` o `[Crudo]` libera acarreadores y se alimenta por tubería) |
| **`1-3-9`** | **Almacén** (`almacen`) | `5×5` | 0 trabajadores | **6 puertos de fluidos en `Y=4`** (3 entradas izq. / 3 salidas der.: `agua`, `crudo`, `combustible`) | Pool global de fluidos (`1.000 u/almacén`) + `+3.000 u` sólidos | `0 E` |

> [!IMPORTANT] Ventana de Energía (`VentanaEnergia`) y Teletransporte de Cámara
> Al hacer clic en el botón **Energía** de la barra superior (`energia_dorado.svg`, `energia_gris.svg` o `energia_rojo.svg` con lectura en `kW`), se abre **`VentanaEnergia`** mostrando la capacidad generada, energía entregada, demanda total y las listas de **Fuentes Generadoras** y **Edificios Consumidores**. Si haces clic sobre cualquier edificio de la lista, la **Cámara Cenital vuela suavemente (`Tween`) hasta centrarse sobre sus coordenadas exactas** y abre su panel lateral para inspección inmediata.

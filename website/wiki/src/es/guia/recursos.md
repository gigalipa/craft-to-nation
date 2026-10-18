# Recursos, Industrias y Energía

![Complejo industrial y procesamiento de recursos en primera persona](/assets/fp-industry.webp)

La economía de **Craft to Nation** se fundamenta en un ecosistema físico de recursos naturales, fluidos dinámicos, insumos energéticos y bienes manufacturados. Cada recurso cuenta con iconos vectoriales pixel-art propios en el HUD (`IconosHUD.gd`), peso logístico, reservas estratégicas y tasas de extracción auditadas en el motor de simulación.

---

## 1. Catálogo de Recursos Primarios y Manufacturados

| Recurso | Categoría | Fuente Principal | Método de Obtención |
| :--- | :--- | :--- | :--- |
| <ResourceBadge name="Agua" category="Vital" /> | Vital / Fluido | Ríos, lagos, mares y acuíferos | Estación de bombeo (`estacion_bombeo`), centro de extracción y acueductos |
| <ResourceBadge name="Comida" category="Vital" /> | Vital / Metabólico | Fauna silvestre, árboles frutales y cardúmenes | Recolección manual (`60 u`), puesto de caza/recolección y muelle de pesca |
| <ResourceBadge name="Madera" category="Básico" /> | Construcción / Insumo | Bosques del mundo procedural | Tala manual (`10 u/celda`) o Puesto Maderero (`puesto_maderero`) |
| <ResourceBadge name="Tablas" category="Procesado" /> | Construcción Eficiente | Aserradero (`aserradero`) | `1 Madera` → `3 Tablas` (rinde ×3 al construir muros de madera) |
| <ResourceBadge name="Piedra" category="Básico" /> | Construcción / Insumo | Afloramientos y subsuelo | Minado manual (`10 u/bloque`) o Mina (`mina`) |
| <ResourceBadge name="Bloques de Piedra" category="Procesado" /> | Mampostería Eficiente | Fábrica de Bloques (`fabrica_bloques`) | `1 Piedra` → `3 Bloques de Piedra` (rinde ×3 al construir mampostería) |
| <ResourceBadge name="Tierra" category="Básico" /> | Nivelación / Adobe / Vidrio | Capa superficial (`GROSOR_TIERRA`) | Minado manual (`1 u/bloque`) o Mina |
| <ResourceBadge name="Hierro" category="Mineral" /> | Metalurgia / Estructuras | Vetas medias (`prof. 8–16`) | Mina Nivel II+ (`10 u/bloque`) |
| <ResourceBadge name="Cobre" category="Mineral" /> | Conducción / Tecnología | Vetas medias (`prof. 8–16`) | Mina Nivel II+ (`10 u/bloque`) |
| <ResourceBadge name="Carbón" category="Energético" /> | Siderurgia / Termoeléctrica | Vetas subterráneas o Carbonera | Mina (`10 u/bloque`) o Carbonera (`3 Madera` → `1 Carbón`) |
| <ResourceBadge name="Tierras Raras" category="Avanzado" /> | Alta Tecnología | Estratos profundos (`prof. 16–24`) | Mina Nivel III (`10 u/bloque`) |
| <ResourceBadge name="Mineral Refinado" category="Avanzado" /> | Componentes Avanzados | Refinería de Tierras Raras | `3 Tierras Raras` → `1 Mineral Refinado` |
| <ResourceBadge name="Acero" category="Aleación" /> | Rascacielos / Defensa | Siderúrgica (`siderurgica`) | `3 Hierro + 4 Carbón` → `2 Acero` |
| <ResourceBadge name="Crudo" category="Fluido" /> | Petroquímica / Energía | Yacimientos profundos (3 capas sobre roca madre) | Centro de Extracción (`centro_extraccion`) y tuberías |
| <ResourceBadge name="Combustible" category="Fluido" /> | Combustible Líquido | Refinería Petrolera / Productor Sintético | `2 Crudo` → `1 Combustible` o `3 Carbón + 1 Agua` → `2 Combustible` |
| <ResourceBadge name="Energía" category="Red Eléctrica" /> | Alimentación Industrial | Central Termoeléctrica | Generación continua en red (`kW` / `MW`), hasta `20 E/h` por planta |

---

## 2. Tasas Base de Extracción en Puestos Periféricos

Las tasas representan el rendimiento horario por trabajador en condiciones de moral neutra (`Moral = 50`, multiplicador `1,0×`) y se recalculan cada `6 horas` de juego según los bloques reales presentes en el área:

| Puesto Periférico | Recurso Obtenido | Tasa Base (u/trabajador/h) | Cupo Máx. | Almacén Local | Huella y Alcance |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Puesto Maderero** (`maderero`) | <ResourceBadge name="Madera" /> | **5,0** × densidad × nivel | 5 obreros | 1.000 u | `3×4` celdas / Radio 12 |
| **Mina** (`mina`) | <ResourceBadge name="Piedra" /> <ResourceBadge name="Hierro" /> <ResourceBadge name="Cobre" /> <ResourceBadge name="Carbón" /> <ResourceBadge name="Tierras Raras" /> <ResourceBadge name="Tierra" /> | **5,0** minerales / **1,0** tierra (× fracción de veta) | 5 obreros | 1.000 u | `5×5` celdas / Radio 6 / Prof. **8 / 16 / 24** (Niveles I–III) |
| **Caza y Recolección** (`caza_recoleccion`) | <ResourceBadge name="Comida" /> | **17,0** caza + **10,0** frutos (`~12,2 u/h` media) | 7 obreros | 1.000 u | `4×4` celdas / Radio 12 |
| **Pesca y Frutos del Mar** (`pesca_frutos_mar`) | <ResourceBadge name="Comida" /> | **17,0** pesca + **3,0** algas (`~8,6 u/h` media) | 7 obreros | 1.000 u | `4×6` celdas (muelle en agua) / Radio 25 |
| **Estación de Bombeo** (`estacion_bombeo`) | <ResourceBadge name="Agua" /> | **2,0** u/h por operario | 3 técnicos | 500 u | `4×6` celdas (muelle en agua + puerto capa 4) |
| **Centro de Extracción** (`centro_extraccion`) | <ResourceBadge name="Crudo" /> / <ResourceBadge name="Agua" /> | **2,0** u/h por operario | 3 técnicos | 500 u | `5×5` celdas (perforación bajo el centro `(2,2)`) |

> [!NOTE] Multiplicadores de Nivel de Puesto (I, II y III) y Agotamiento Físico
> - En **Puesto Maderero**, **Caza y Recolección** y **Pesca**, los niveles aplican un multiplicador directo de velocidad: **Nivel I = `1,0×`**, **Nivel II = `1,5×`**, **Nivel III = `2,0×`**. Si un puesto maderero cae por debajo de `0,5 madera/h` por recolector, se marca como **Agotado**.
> - En las **Minas**, subir de nivel amplía la **profundidad vertical de excavación**: **Nivel I = `8` capas** (piedra y carbón somero), **Nivel II = `16` capas** (alcanza vetas de hierro y cobre), **Nivel III = `24` capas** (alcanza tierras raras). Cada bloque sólido extraído rinde **10 unidades** (`1 u` para tierra) y desaparece físicamente del subsuelo respetando las `2` capas bajo la superficie natural para no hundir el suelo.
> - **Física de Fluidos Subterráneos:** Al extraer bloques de agua o crudo, el fluido remanente se nivela por gravedad hacia las celdas vacías inferiores y laterales (alcance de propagación `7` en ríos, `5` en lagos y `3` en crudo con viscosidad `0,20`).

---

## 3. Bloques Naturales vs. Costos de Construcción y Reservas

Al colocar bloques manualmente o construir plantillas, el sistema (`Ciudad.consumir_costo()`) prioriza automáticamente los materiales procesados (**Tablas** y **Bloques de Piedra**) antes de gastar materia prima en bruto:

| Bloque Colocable | Material en Almacén | Costo por Bloque | Equivalencia con Material Procesado |
| :--- | :--- | :--- | :--- |
| **`tierra`** | <ResourceBadge name="Tierra" /> | `1 Tierra` | — |
| **`adobe`** | <ResourceBadge name="Tierra" /> | `5 Tierra` | — |
| **`vidrio`** | <ResourceBadge name="Tierra" /> | `1 Tierra` | — |
| **`bloque_madera`** | <ResourceBadge name="Tablas" /> o <ResourceBadge name="Madera" /> | `1 Tabla` (o `5 Madera`) | **1 Madera → 3 Tablas** (multiplica ×15 la eficiencia constructiva) |
| **`puerta` / `cama` / `baul`** | <ResourceBadge name="Tablas" /> o <ResourceBadge name="Madera" /> | `1 Tabla` (o `5 Madera`) por celda | Puerta = 2 celdas verticales; Cama = 2 horizontales; Baúl = 1 celda |
| **`bloque_piedra`** | <ResourceBadge name="Bloques de Piedra" /> o <ResourceBadge name="Piedra" /> | `1 Bloque de Piedra` (o `5 Piedra`) | **1 Piedra → 3 Bloques** (multiplica ×15 la eficiencia constructiva) |
| **`estructura_hierro`** | <ResourceBadge name="Hierro" /> | `5 Hierro` | — |
| **`bloque_acero`** | <ResourceBadge name="Acero" /> | `3 Acero` | — |

### Cuotas de Reserva de Materia Prima (`[0, 50, 100, 250, 500] u`)
Para evitar que el **Aserradero**, la **Carbonera** o la **Fábrica de Bloques** consuman toda tu madera o piedra en bruto dejándote sin stock para obras directas, puedes configurar en la **Ventana de Almacén** (`VentanaAlmacen`) o en la ficha de la fábrica un **umbral mínimo de reserva** (`0`, `50`, `100`, `250` o `500 u`). Los acarreadores solo retirarán el excedente por encima de esa reserva.

---

## 4. Las 8 Instalaciones Industriales y Energéticas (Zona B)

Todas las refinerías comparten una capacidad de almacén local de **1.000 unidades** (`300 u` en la Central Termoeléctrica) y un cupo máximo de **4 trabajadores** (**Técnicos** en plantas Tipo 2; **Especialistas** en plantas Tipo 3):

| Instalación Industrial | Tipo / Personal | Huella | Receta por Lote (Entradas → Salida) | Lotes/h por Trabajador | Consumo / Generación Eléctrica |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Aserradero** (`aserradero`) | Tipo 2 (4 Técnicos) | `5×6` | `1 Madera` → `3 Tablas` | `0,5 lotes/h` (`1,5 tablas/h`) | `0 E` |
| **Fábrica de Bloques** (`fabrica_bloques`) | Tipo 2 (4 Técnicos) | `5×6` | `1 Piedra` → `3 Bloques de Piedra` | `0,5 lotes/h` (`1,5 bloques/h`) | `0 E` |
| **Carbonera** (`carbonera`) | Tipo 2 (4 Técnicos) | `5×5` | `3 Madera` → `1 Carbón` | `2,0 lotes/h` (`2,0 carbón/h`) | `0 E` |
| **Siderúrgica** (`siderurgica`) | Tipo 2 (4 Técnicos) | `5×5` | `3 Hierro + 4 Carbón` → `2 Acero` | `2,0 lotes/h` (`4,0 acero/h`) | `0 E` |
| **Refinería de Tierras Raras** (`refineria_tierras_raras`) | Tipo 3 (4 Especialistas) | `5×5` | `3 Tierras Raras` → `1 Mineral Refinado` | `0,5 lotes/h` (`0,5 ref/h`) | `0 E` |
| **Refinería Petrolera** (`refineria_petrolera`) | Tipo 3 (4 Especialistas) | `5×5` | `2 Crudo` → `1 Combustible` | `1,0 lote/h` (`1,0 comb/h`) | Consume **1 E/lote** (Tope local: `400 Crudo / 600 Combustible`) |
| **Productor de Combustible** (`productor_combustible`) | Tipo 3 (4 Especialistas) | `5×5` | `3 Carbón + 1 Agua` → `2 Combustible` | `1,0 lote/h` (`2,0 comb/h`) | Consume **1 E/lote** |
| **Central Termoeléctrica** (`central_termoelectrica`) | Tipo 3 (4 Especialistas) | `5×5` | Quema `Combustible` (`1:1`), `Crudo` (`1,5:1`) o `Carbón` (`2:1`) | Hasta `5,0 E/h` por especialista | Genera hasta **20 E/h** (protege reserva de `500 Carbón` en almacén central) |

> [!IMPORTANT] Red Eléctrica en kW / MW e Indicador Tricolor en HUD
> La barra superior (`BarraSuperior.gd`) muestra el balance eléctrico en tiempo real formateado en **kW / MW** con un icono de rayo interactivo:
> - **Dorado:** Superávit o equilibrio con generación activa (`factor_energia = 1,0`).
> - **Gris:** Sin demanda ni generación eléctrica activa.
> - **Rojo:** Déficit energético (`factor_energia = generada / demandada`), lo que reduce proporcionalmente la velocidad de todas las plantas que requieren electricidad. Al hacer clic en el rayo se abre la **Ventana de Energía** (`VentanaEnergia`) con el desglose por edificio.


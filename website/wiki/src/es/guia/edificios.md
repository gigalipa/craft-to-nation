# Edificios, Niveles Urbanos y Almacenamiento

![Vista táctica cenital y planificación de distritos](/assets/hud-camara-cenital.png)

En **Craft to Nation**, las estructuras no son simples elementos decorativos; constituyen el corazón funcional de la civilización. Cada edificación se rige por validación volumétrica interior (`ValidadorEdificios.gd`), densidad demográfica por cama (`x_cama`), límites de altura según el **Nivel Urbano** de la ciudad y prioridades de obra configurables.

---

## 1. Clasificación Territorial de Edificios

El sistema organiza las construcciones en tres zonas excluyentes dentro del mundo de `200×200` celdas:

| Distrito | Categoría de Edificio | Ejemplos en el Motor | Regla de Emplazamiento |
| :--- | :--- | :--- | :--- |
| **Zona A (Residencial, Cívica y Académica)** | Viviendas, Almacenes, Escuelas, Universidad | Residencias (`blueprint`), `almacen` (`5×5`, `+3.000 u`), `escuela_tecnica`, `escuela_especialistas`, `universidad` | Dentro del Área de Influencia (`Radio 30`, `61×61` celdas) del Núcleo Urbano |
| **Zona B (Industrial y Energética)** | Refinerías Tipo 2 y Tipo 3, Termoeléctrica | `aserradero`, `fabrica_bloques`, `carbonera`, `siderurgica`, `refineria_tierras_raras`, `refineria_petrolera`, `productor_combustible`, `central_termoelectrica` | Polígono continuo de Zona B dentro del Área de Influencia |
| **Periferia Silvestre** | Puestos de Extracción y Bombeo | `maderero` (`3×4`), `mina` (`5×5`), `caza_recoleccion` (`4×4`), `pesca_frutos_mar` (`4×6`), `estacion_bombeo` (`4×6`), `centro_extraccion` (`5×5`) | Fuera de las zonas A/B, directamente sobre bosques, vetas, costas o pozos |

---

## 2. Niveles Urbanos (1 a 3), Densidad Residencial y Universidad

A medida que modernizas la arquitectura de tu ciudad (índice de sofisticación de bloques) e investigas tecnologías en la **Universidad** (`universidad`, `5×5` celdas de piedra, hasta 3 investigadores generando `1,0 hora_investigador/h` cada uno), tu asentamiento asciende de **Nivel Urbano**, desbloqueando edificios residenciales de mayor altura y reduciendo el gasto metabólico del avatar:

| Nivel Urbano | Nombre de Etapa | Máx. Pisos por Vivienda | Máx. Camas por Piso | Tope por Edificio | Consumo Avatar | Requisitos de Desbloqueo (`Ciudad.gd`) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Nivel 1** | Asentamiento Rudimentario | **2 pisos** | **2 camas/piso** | **4 camas** | `5,0 comida/h` | Nivel inicial de partida |
| **Nivel 2** | Asentamiento Productivo | **4 pisos** | **4 camas/piso** | **16 camas** | `4,0 comida/h` | Sofisticación media `>= 1,7` + mín. `3` plantas Tipo 2 + Tecnología **Metalurgia Aplicada** (`300 Hierro`, `200 Madera`, `20 h_inv`) |
| **Nivel 3** | Metrópolis Tecnificada | **8 pisos** | **4 camas/piso** | **32 camas** | `3,0 comida/h` (`2,0` en alcaldía) | Sofisticación media `>= 2,5` + mín. `3` plantas Tipo 3 + Tecnología **Automatización Industrial** (`800 Hierro`, `100 Madera`, `50 h_inv`) |

### Escuelas y Formación de Cohorte (`Zona A`)
- **Escuela Técnica (`escuela_tecnica`, `5×5` adobe):** Entrena una cohorte de **4 Obreros** (1 cama compartida) durante **24 horas de juego** y gradúa **3 Técnicos** (que ocupan exactamente 1 cama de técnico; el cuarto integrante se retira para conservar el equilibrio habitacional).
- **Escuela de Especialistas (`escuela_especialistas`, `5×5` piedra):** Entrena una cohorte de **3 Técnicos** (1 cama) durante **48 horas de juego** y gradúa **2 Especialistas** (1 cama).

---

## 3. Puestos Periféricos y Regresión de Nivel (`I`, `II`, `III`)

Los cuatro puestos de extracción clásicos (`mina`, `maderero`, `caza_recoleccion`, `pesca_frutos_mar`) muestran su nivel en números romanos (**`I`**, **`II`**, **`III`**) y la distancia con brújula al Núcleo Urbano (`🧭 Distancia al núcleo: X celdas`) en su panel (`PanelPuesto.gd`):

| Nivel del Puesto | Personal Requerido | Efecto en Maderero / Caza / Pesca | Efecto en Mina (`5×5`) |
| :--- | :--- | :--- | :--- |
| **Nivel I** | Obreros | Velocidad base **`1,0×`** | Excava hasta **8 capas** de profundidad (piedra y carbón superficial) |
| **Nivel II** | Requiere al menos **1 Técnico** (post-*Metalurgia Aplicada*) | Velocidad mejorada **`1,5×`** | Excava hasta **16 capas** de profundidad (alcanza hierro y cobre) |
| **Nivel III** | Requiere al menos **1 Especialista** (post-*Automatización Industrial*) | Velocidad avanzada **`2,0×`** | Excava hasta **24 capas** de profundidad (alcanza tierras raras) |

> [!WARNING] Regresión Automática de Nivel
> Si retiras al último Especialista de un puesto de **Nivel III**, el puesto regresa automáticamente a **Nivel II** (o a **Nivel I** si tampoco cuenta con Técnicos).

---

## 4. Jerarquía de Almacenamiento y Almacenes Dedicados

```
[Extracción en Puesto (1.000 u) / Bombeo (500 u) / Refinería (1.000 u)]
                                  ↓
        [Acarreadores Cívicos (150 u/viaje) o Red de Canalizaciones]
                                  ↓
                  [Almacén Central Municipal (Ciudad.almacen)]
                    • Base General: 500 u (×2 = 1.000 u con Núcleo Urbano)
                    • Base Comida: 5.000 u (×2 = 10.000 u con Núcleo Urbano)
                    • Bono por Baúl Residencial: +100 u general / +400 u comida
                    • Bono por Almacén Dedicado (5×5 en Zona A): +3.000 u
```

- **Baúles Residenciales (`BONO_BAUL`):** Cada baúl colocado en el interior de una vivienda declarada suma **+100 u** a la capacidad general y **+400 u** a la capacidad de comida. Puedes inspeccionarlo en primera persona con <kbd>E</kbd> (`VentanaBaul`).
- **Almacén Dedicado (`almacen`):** Edificio de mampostería de `5×5` celdas emplazable en **Zona A** (`240 madera + 160 piedra` equivalentes). Añade **+3.000 unidades** de capacidad general, cuenta con **2 puertas frontales** (entrada/salida) y **6 puertos de líquidos** en la capa 4 para conectarse directamente a redes de acueductos y oleoductos.

---

## 5. Obras, Prioridades y Remodelación No Destructiva

- **Cuadrillas de Obra (`Obras.gd`):** Cada obra de construcción, ampliación por niveles o demolición admite un máximo de **4 constructores simultáneos** (`MAX_CONSTRUCTORES_POR_OBRA = 4`), colocando o retirando bloques reales a razón de `2 bloques/s` por trabajador.
- **Selector de Prioridades (`Alta`, `Normal`, `Baja`):** Tanto las obras de edificios como los tramos de carretera en construcción (`ConstructorVias.gd`) permiten alternar su prioridad entre **Alta (`▲▲▲`)**, **Normal (`▲▲`)** y **Baja (`▲`)** para dirigir a los obreros libres hacia las infraestructuras críticas primero.
- **Remodelación No Destructiva (<kbd>Shift</kbd> + <kbd>B</kbd>):** Apuntando a la puerta principal de un edificio declarado y pulsando <kbd>Shift</kbd> + <kbd>B</kbd>, el edificio se abre a edición manual conservando a sus moradores en espera hasta que completes la ampliación y vuelvas a declararlo con <kbd>B</kbd>.


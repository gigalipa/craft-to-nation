# Guión de Verificaciones en Vivo (Live QA Script) — Craft to Nation

Este documento es el guión integral de pruebas manuales paso a paso para comprobar en vivo, directamente dentro del juego en ejecución (**F5** en Godot), que todas las mecánicas de avatar, fundación urbana, demografía, moral, red vial, cadena educativa, industria, fluidos, canalizaciones elevadas y red eléctrica operan de manera óptima y sin errores.

El guión está diseñado siguiendo **estrictamente el orden cronológico y de prerrequisitos reales de jugabilidad**: ninguna prueba exige edificios, oficios, tecnologías o estados del mundo que no hayan sido desbloqueados o construidos en los pasos previos.

---

## 0. Preparativos, Estado Inicial y Controles Globales

### Iniciar el entorno y condiciones de partida
1. Abrir el proyecto en Godot y pulsar **F5** (o ejecutar la escena principal `Main.tscn`).
2. Comprobar que el avatar aparece en 1ª persona y que la barra superior del HUD es visible.
3. **Inventario inicial de prueba (`Player.gd`):** Al iniciar en modo prueba, el almacén cuenta con **1000 unidades de cada recurso** y **5000 unidades de comida**, lo que permite ensayar la colocación de estructuras sin tener que talar o minar durante horas.
4. **Estado inicial de la colonia (`Ciudad.gd`):**
   - **Núcleo Urbano:** No declarado todavía (no existe Zona de Influencia ni llegan inmigrantes hasta declarar el primer edificio en el Bloque 2).
   - **Nivel tecnológico:** `nivel_investigado = 1` (la industria petroquímica y termoeléctrica requiere investigar *Metalurgia Aplicada* en el Bloque 5).
   - **Energía en red:** `0 E/h` (hasta construir y abastecer una Central Termoeléctrica en el Bloque 7).
   - **Moral ciudadana:** Arranca en `🙂 75%` (*Optimismo pionero*).

### Atajos de Teclado Clave

#### Primera Persona (Avatar)
| Tecla / Acción | Función |
| :--- | :--- |
| **C** | Alternar entre cámara en **1ª persona** y **Cámara Cenital** (con transición animada). |
| **W, A, S, D** | Movimiento del avatar. |
| **Espacio / Ctrl** | Saltar en tierra / Nadar hacia arriba (**Espacio**) o hacia abajo (**Ctrl**) en líquidos profundos ($\ge 2$ bloques). |
| **Clic izquierdo** | Talar árboles, minar terreno/vetas (con barra de progreso) o deconstruir si el modo **G** está activo. |
| **Clic derecho** | Colocar el bloque seleccionado en la hotbar (`1`–`0`) o surtir una obra fantasma apuntada. |
| **1 – 9, 0** | Seleccionar tipo de bloque en la hotbar (`tierra`, `adobe`, `bloque_madera`, `bloque_piedra`, `estructura_hierro`, `vidrio`, `puerta`, `cama`, `baul`, `bloque_acero`). |
| **L** | **Encender / apagar lámpara omnidireccional** del avatar (`PanelLampara`). |
| **E** | Pulsar: abrir/cerrar puertas o abrir el baúl de un puesto activo (`VentanaBaul`). Mantener sobre árbol: recolectar frutos. |
| **G** | Alternar modo deconstrucción manual a pie (clic izq. desmonta paso a paso; clic der. marca/desmarca para demolición). |
| **V** | Alternar modo interacción con vías a pie (clic izq. construye sección 2×2; clic der. demuele sección 2×2). |
| **B / Shift + B** | Declarar estructura terminada (**B**) / Iniciar remodelación (**Shift + B**) apuntando a su puerta exterior. |
| **M** | Abrir / cerrar la ventana analítica de **Moral Ciudadana** (`VentanaMoral`). |
| **Esc** | Cerrar ventana modal activa, salir del modo vías/deconstrucción o liberar el cursor. |

#### Cámara Cenital (Gestión Urbana)
| Tecla / Acción | Función |
| :--- | :--- |
| **W, A, S, D** | Paneo horizontal de la cámara sobre el plano X/Z. |
| **Q / E** | **Rotación orbital:** Gira la vista alrededor del foco a la izquierda (**Q**) o derecha (**E**). |
| **Rueda del ratón (Scroll)** | **Zoom:** Acerca o aleja oblicuamente respecto al punto focal. |
| **Ctrl + W / Ctrl + S** | **Inclinación:** Modifica el ángulo de inclinación vertical de la cámara. |
| **Shift + W / Shift + S** | **Altura vertical:** Sube (**Shift+W**) o baja (**Shift+S**) directamente la cota del foco. |
| **1** | Menú **Construir** (`1`: Residencial, `2`: Periférico, `3`: Industrial, `4`: Investigación, `5`: Vías, `6`: Ductos). |
| **2** | Menú **Zonificar** (`1`: Zona Residencial, `2`: Zona Industrial, `3`: Borrar). |
| **3** | Modo **Demoler** unificado (marca roja en edificios y demolición guiada naranja en vías). |
| **Z / X** | Retroceder submenú (**Z**) / Avanzar página (**X**) en menús numéricos con más de 9 ítems. |
| **M** | Abrir / cerrar la ventana analítica de **Moral Ciudadana** (`VentanaMoral`). |
| **Ctrl + Scroll** | Rotar previsualización de blueprint o plantilla de puesto en pasos de 90°. |
| **Clic izquierdo** | Fijar esquina de zona/vía/ducto, emplazar estructura o inspeccionar edificio/puesto/ducto en modo Ver. |
| **Doble clic izq.** | Confirmar trazado de vía, demolición de vía o canalización elevada. |
| **Clic derecho** | Cancelar tramo en curso / cancelar modo de colocación. |
| **Esc** | Volver al modo neutro **Ver** o cerrar paneles abiertos. |

---

## Bloque 1: Exploración Inicial en 1ª Persona, Agua, Oxígeno y Lámpara Térmica

> **Condición de partida:** Recién iniciada la escena (`F5`), antes de fundar la ciudad. Se comprueban las físicas del avatar a pie, la interacción con ríos/lagos superficiales, el secado de líquidos con bloques sólidos y el modo térmico inicial de la lámpara. *(Nota: Las físicas sobre `crudo` se verifican en el **Bloque 6.7** tras extraer crudo del subsuelo, ya que los pozos naturales de crudo yacen a profundidad $\ge 4$ bajo tierra).*

### 1.1 Movimiento, Tala, Minado y Colocación de Bloques a Pie
- [ ] **Acción:** Desplazarse con **W, A, S, D** y saltar con **Espacio**. Apuntar a un árbol o al suelo manteniendo **Clic Izquierdo**, y colocar bloques de la hotbar (`1`–`0`) con **Clic Derecho**.
- [ ] **Resultado esperado:**
  - El resaltado verde (`CaraApuntada`) marca la cara del bloque bajo la mira.
  - Al talar o minar aparece la barra de progreso circular/lineal y los recursos extraídos se suman al almacén.
  - No permite colocar un bloque en las 2 celdas ocupadas por el cuerpo del propio avatar.

### 1.2 Natación en Agua, Corrientes, Oxígeno y Drenado con Bloques Sólidos
- [ ] **Acción (Natación y Corriente):** Caminar hacia un río, cascada o lago con $\ge 2$ bloques de profundidad de `agua`.
- [ ] **Resultado esperado:**
  - En agua de 1 solo bloque de profundidad el avatar camina normal; al entrar en $\ge 2$ bloques de profundidad se activa la flotación suave de cámara y el nado vertical (**Espacio** sube, **Ctrl** baja).
  - En ríos y pies de cascada se percibe el empuje horizontal de la corriente sumado al movimiento del jugador.
- [ ] **Acción (Consumo de Oxígeno):** Sumergir la cabeza completa bajo el agua (`Ctrl`).
- [ ] **Resultado esperado:**
  - Aparece `PanelOxigeno` y la barra de oxígeno se reduce progresivamente (10 s de autonomía) y se recupera el doble de rápido al sacar la cabeza a la superficie.
- [ ] **Acción (Drenado / Secado con Bloques Sólidos):** Apuntar a una celda inundada de `agua` con un bloque sólido seleccionado en la hotbar (ej. `tierra` o `bloque_piedra`) y hacer **Clic Derecho**.
- [ ] **Resultado esperado:**
  - El bloque sólido **sobrescribe y desaloja el líquido de inmediato**, dejando la celda seca y ocupada por el bloque sólido sin rechazar la colocación.

### 1.3 Lámpara Omnidireccional en Modo Térmico Inicial (`L`) y Apilamiento con Oxígeno
- [ ] **Acción:** En 1ª persona (sin Central Termoeléctrica construida todavía en el mapa), pulsar la tecla **`L`**.
- [ ] **Resultado esperado:**
  - Se enciende la luz omnidireccional del avatar.
  - Como la ciudad aún produce `0 E/h`, `PanelLampara` se abre directamente en modo **`LÁMPARA TÉRMICA🟡`**.
  - Quema insumos del almacén central siguiendo la jerarquía configurada en `Player.gd`:
    1. **Combustible:** `10 h / unidad` (luz cálida clara, rango 14 m).
    2. **Carbón:** `6 h / unidad` (luz ámbar, rango 10 m).
    3. **Madera:** `5 h / unidad` (luz anaranjada tenue, rango 7 m).
  - El panel muestra `Tiempo restante: X h | Y Combustible` (descontando 1 unidad del almacén cada 10 horas de juego).
- [ ] **Acción (Ventana de Oxígeno Apilada):** Con la lámpara encendida y `PanelLampara` visible, sumergir la cabeza en el agua.
- [ ] **Resultado esperado:**
  - La ventana `PanelOxigeno` aparece **apilada verticalmente justo debajo** de `PanelLampara`, sin solaparse ni tapar la mira central.
- [ ] **Acción:** Pulsar **`L`** nuevamente para apagar la lámpara (el indicador pasa a `⚫` y el panel se oculta). *(El modo **`LÁMPARA ELÉCTRICA🟡`** con batería de 72 h se probará en el **Bloque 7.3**, una vez exista generación eléctrica en la ciudad).*

---

## Bloque 2: Fundación del Núcleo Urbano, Zonificación y Ciclo de Vida Residencial

> **Mecánicas y orden lógico:** El **primer edificio** declarado con `B` funda siempre el **Núcleo Urbano** (crea la Zona de Influencia y guarda el primer blueprint, pero aún no aloja colonos). A continuación se pinta la **Zona Residencial (`2 -> 1`)**, se construye la **1ª Residencia habitable** (que activa la inmigración con `Colonizable: SÍ`), se prueba el estado `"Sin techo"` al remodelarla, y luego se construye la **2ª Residencia** (que nace como buffer `Colonizable: NO 24h` y permite reubicar habitantes sin dejarlos sin techo).

### 2.1 Construcción a Mano de Casa de 2 Plantas y Declaración del Núcleo Urbano (`B`)
- [ ] **Acción:** En 1ª persona, levantar manualmente con bloques de la hotbar una estructura cerrada de **2 pisos** (respetando el límite de Nivel 1: máx. 2 pisos y máx. 2 camas por piso):
  - **Planta baja (Nivel 0):** Muros cerrados, **1 puerta exterior** (`7`), al menos **1 ventana de vidrio** (`6`), **1 o 2 camas** (`8`) y **1 baúl** (`9`).
  - **Planta alta (Nivel 1):** Muros cerrados, techo, escalera interior transitable desde planta baja, ventanas y hasta 2 camas, **sin ninguna puerta exterior**.
- [ ] **Acción:** Salir al exterior, apuntar a la puerta de planta baja y pulsar **`B`**.
- [ ] **Resultado esperado:**
  - La estructura se valida y declara con éxito: **no exige puerta exterior en el piso superior**.
  - Notificación: **`"Núcleo urbano declarado."`**
  - El edificio queda registrado como **Núcleo Urbano** (duplica los topes base del almacén central y establece la **Zona de Influencia** alrededor de la sede).
  - Se guarda automáticamente el diseño en el catálogo de blueprints bajo el nombre **`Residencia [camas]x[baules]`**.

### 2.2 Excepción de Remodelación en el Núcleo Urbano (`Shift + B`)
- [ ] **Acción:** Apuntar a la puerta del Núcleo Urbano recién declarado y pulsar **`Shift + B`** (o seleccionarlo en cenital y pulsar `[Iniciar remodelación]`).
- [ ] **Resultado esperado:**
  - Notificación: *"Remodelación iniciada para el núcleo urbano: ahora en edición libre."*
  - Los bloques quedan desprotegidos para ampliar o modificar muros sin perder la condición de sede.
- [ ] **Acción:** Volver a apuntar a su puerta y pulsar **`B`** para redeclarar el Núcleo Urbano.

### 2.3 Zonificación Residencial (`2 -> 1`) y Emplazamiento de la 1ª Residencia Habitable (`1 -> 1`)
- [ ] **Acción (Pintar Zona Residencial):** Pulsar **`C`** para pasar a la Cámara Cenital. Pulsar **`2`** (Zonificar) $\to$ **`1`** (Zona Residencial) y hacer dos clics izquierdos sobre terreno llano **dentro de la Zona de Influencia** para pintar un sector residencial.
- [ ] **Resultado esperado:**
  - Se dibuja el rectángulo de Zona Residencial. Al pulsar **`Esc`** para salir del modo Zonificar, los rectángulos de colores se ocultan limpiamente.
- [ ] **Acción (Emplazar Blueprint con Miniatura 3D):** En cenital, pulsar **`1`** (Construir) $\to$ **`1`** (Residencial).
- [ ] **Resultado esperado:**
  - El botón muestra el nombre `Residencia [camas]x[baules]` y su **miniatura isométrica 3D** generada en vivo (se admiten hasta 5 slots de blueprints).
  - Al seleccionarlo (`1`), la tarjeta contextual muestra los iconos vectoriales `[Ctrl] [Icono Scroll] ROTAR` y `[Icono Clic Izq.] COLOCAR`.
  - Girar con **`Ctrl + Rueda del ratón`** rota la huella fantasma 3D y la miniatura en pasos de 90°.
- [ ] **Acción (Construir la 1ª Residencia):** Hacer clic izquierdo sobre la **Zona Residencial** pintada para fijar el edificio fantasma. Volver a 1ª persona (**`C`**) y mantener **Clic Derecho** apuntando a los bloques fantasma (y luego a cualquier pared exterior) hasta completar el 100% de la obra.

### 2.4 1ª Residencia Habitable: `Colonizable: SÍ` y Llegada de los Primeros Colonos
- [ ] **Acción:** Pasar a cenital (**`C`**), asegurar modo Ver (**`Esc`**) y hacer clic izquierdo sobre la residencia recién terminada (no sobre el Núcleo Urbano).
- [ ] **Resultado esperado:**
  - `PanelEdificio` indica: **`Colonizable: SÍ (inmigración activa)`** y muestra el botón **`[Pausar colonización]`**.
  - Con el avance de los ticks horarios (cada 2 s), comienzan a inmigrar colonos (`desempleado`) que caminan hacia su nuevo hogar hasta llenar la capacidad de sus camas (4 desempleados/obreros por cama).
  - El panel desglosa exactamente cuántos residentes de cada categoría habitan el edificio.

### 2.5 Remodelación de Única Residencia Poblada: Estado "Sin Techo" y Reabsorción
- [ ] **Condición:** Esperar a que la 1ª Residencia habitable tenga colonos residiendo en ella (cuando todavía **no existe ninguna otra casa** con camas libres en la colonia).
- [ ] **Acción:** En cenital, seleccionar esa residencia y hacer clic en **`[Iniciar remodelación]`** (o en 1ª persona pulsar **`Shift + B`** apuntando a su puerta).
- [ ] **Resultado esperado:**
  - En cenital aparece un **diálogo modal estilizado con `TemaHUD`** advirtiendo cuántos habitantes quedarán **sin techo** por falta de camas alternativas.
  - Al confirmar, el edificio pasa a edición libre y los habitantes desalojados aparecen en la ventana **Población** como **`"Sin techo: X"`**.
  - Mientras están sin techo, consumen comida a tasa de desempleado, no trabajan en obras ni puestos y penalizan la moral en `-0.05/h`.
- [ ] **Acción (Reabsorción inmediata):** En 1ª persona, apuntar a la puerta de la casa y pulsar **`B`** para volver a declararla.
- [ ] **Resultado esperado:**
  - Los colonos `"Sin techo"` son **reabsorbidos al instante** en las camas recién declaradas (`Sin techo: 0`) y recuperan su actividad normal.

### 2.6 2ª Residencia en adelante: Buffer de 24 h (`Colonizable: NO`), Obra por Colonos y Reubicación
- [ ] **Acción:** En cenital (`1 -> 1`), emplazar una **2ª Residencia** sobre la Zona Residencial.
- [ ] **Resultado esperado (Construcción autónoma por colonos):**
  - Como ahora ya hay colonos desempleados/obreros en la ciudad, **los colonos acuden automáticamente a la obra fantasma** y la construyen bloque a bloque hasta terminarla sin intervención del jugador.
- [ ] **Acción:** Una vez terminada la 2ª Residencia, seleccionarla en modo Ver (`Esc`).
- [ ] **Resultado esperado (Buffer habitacional):**
  - Nace con estado **`Colonizable: NO (apertura en 24 h)`** y botón **`[Permitir colonización]`**.
  - Sus camas están protegidas como buffer para reubicaciones internas (no atraen nuevos inmigrantes externos hasta que el contador de 24 h llegue a 0 o el jugador lo abra manualmente).
  - Pulsar **`[Permitir colonización]`** cambia inmediatamente a `Colonizable: SÍ (inmigración activa)`; pulsar **`[Pausar colonización]`** lo devuelve a `Colonizable: NO (buffer protegido)`. Dejarlo en `NO` con camas libres.
- [ ] **Acción (Reubicación automática al remodelar):** Iniciar remodelación (`Shift + B` o cenital) sobre la **1ª Residencia poblada** mientras la 2ª Residencia tiene camas libres en buffer.
- [ ] **Resultado esperado:**
  - Los residentes de la 1ª Residencia **se mudan automáticamente a las camas libres de la 2ª Residencia**, generando **`0 colonos sin techo`**. Volver a declarar la 1ª Residencia con **`B`**.

### 2.7 Edificios Adosados (Pared con Pared) y Traslado del Núcleo Urbano
- [ ] **Acción (Adosados):** En 1ª persona, construir dos casas pequeñas pegadas **pared con pared** sobre Zona Residencial y declarar ambas con **`B`** (Edificio A y Edificio B).
  - Iniciar remodelación solo en el Edificio A (`Shift + B`): comprobar que el Edificio B permanece intacto y protegido contra minado.
  - Modificar un bloque en A y redeclararlo con **`B`**: comprobar que el algoritmo de *flood-fill* se detiene en los bloques ya registrados de B y declara A limpiamente sin fusionar ni absorber a B.
- [ ] **Acción (Traslado de Sede del Núcleo Urbano):** En cenital modo Ver (`Esc`), seleccionar una residencia secundaria terminada y pulsar **`[Asignar como núcleo urbano]`**.
- [ ] **Resultado esperado:**
  - Se abre un diálogo modal (`TemaHUD`) advirtiendo del período de gracia de **5 horas** (e informando si habrá déficit de camas durante el cambio).
  - Al confirmar, tras 5 ticks horarios el Núcleo Urbano y su radio de influencia se trasladan a la nueva sede sin pérdida de recursos, y el antiguo núcleo pasa a ser un edificio residencial habitable.

---

## Bloque 3: Infraestructura Vial, Prioridades de Obra y Tráfico

> **Condición previa:** La colonia ya cuenta con el Núcleo Urbano, varias residencias y colonos obreros libres para ejecutar obras viales, demoliciones y construcciones con distintas prioridades.

### 3.1 Trazador Cenital de Vías e Iconografía SVG (`1` -> `5` -> `1`)
- [ ] **Acción:** En cenital (**`C`**), pulsar **`1`** (Construir) $\to$ **`5`** (Vías) $\to$ **`1`** (Trazar vía).
- [ ] **Resultado esperado:**
  - La tarjeta contextual muestra iconos vectoriales SVG:
    - `[Icono Clic Izq.] FIJAR PUNTO`
    - `[Icono Clic Izq. (x2)] CONFIRMAR`
    - `[Icono Clic Der.] CANCELAR`
    - `[Esc] SALIR`
  - Ficha técnica dinámica con `Velocidad: +35%` y costos de piedra/tierra calculados en vivo según la longitud y nivelación del trazado.
- [ ] **Cancelación limpia:** Hacer un clic izquierdo en el suelo, desplazar el cursor para previsualizar un tramo y pulsar **Clic Derecho**: el tramo en curso se cancela al instante sin dejar baldosas fantasma.

### 3.2 Nivelación Compartida entre Puertas Enfrentadas
- [ ] **Acción:** Emplazar un edificio frente a otro con sus puertas enfrentadas a 2–3 celdas de distancia en terreno con desnivel, o trazar una calle entre ambas fachadas.
- [ ] **Resultado esperado:**
  - El terreno entre las puertas enfrentadas se nivela a una misma cota compartida, evitando escalones bruscos que bloqueen el acceso.

### 3.3 Tendido Progresivo de Vías por Colonos (`ViaObraOverlay`) y Fusión de Tramos
- [ ] **Acción:** Trazar una vía de varias celdas y confirmar con **doble clic izquierdo**.
- [ ] **Resultado esperado:**
  - Aparece el **contorno perimetral amarillo** en el suelo (`ViaObraOverlay`).
  - Hasta **4 obreros libres** acuden a la obra vial y construyen de forma **consecutiva de un extremo al otro** (nivelando, rellenando o colocando láminas y cuñas de rampa).
  - A medida que cada celda se completa, el contorno amarillo se retira progresivamente.
- [ ] **Fusión de tramos:** Mientras la obra vial sigue en construcción, trazar y confirmar un nuevo tramo contiguo: se fusiona automáticamente en la misma obra activa bajo la misma cuadrilla de hasta 4 obreros.

### 3.4 Intervención Manual de Vías a Pie en 1ª Persona (Tecla `V`)
- [ ] **Acción:** Trazar otra vía en cenital, pasar a 1ª persona (**`C`**) y pulsar **`V`** para activar el modo vías a pie.
- [ ] **Construir sección 2×2 (Clic Izquierdo):** Apuntar a una sección pendiente (con alambre amarillo) y hacer clic izquierdo:
  - Completa de golpe la **sección 2×2 entera** (4 celdas de ancho de vía o cuñas) sin emitir notificaciones repetitivas por cada celda.
- [ ] **Demoler sección 2×2 (Clic Derecho):** Apuntar a un tramo de vía ya construido y hacer clic derecho:
  - Retira al instante la sección 2×2 completa junto con sus cuñas.
- [ ] Pulsar **`V`** o **`Esc`** para salir del modo vías.

### 3.5 Herramienta Unificada de Demolición Cenital (Tecla `3`)
- [ ] **Demolición de Edificios:** En cenital, pulsar **`3`** (Demoler) y hacer clic izquierdo sobre un edificio secundario: alterna su marca roja de demolición para que los colonos lo desmonten.
- [ ] **Demolición Guiada de Vías en Esquinas de 90°:** Trazar y completar una vía en forma de "L" (con una esquina de 90°). Activar el modo **`3`**, hacer clic izquierdo en un extremo de la vía y mover el cursor hasta el otro extremo pasando por la esquina:
  - La previsualización **naranja translúcida** (`ViaDemolicionOverlay`) sigue la red vial mediante Dijkstra cubriendo **todo el ancho de 2 canales (sección 2×2)** en la esquina exterior sin recortar en diagonal.
- [ ] **Confirmación y Outline Naranja Persistente:** Hacer **doble clic izquierdo** para confirmar la demolición del tramo:
  - La vía queda marcada con un **outline naranja persistente** en el suelo.
  - Los colonos acuden a demoler la vía y el outline naranja se va eliminando sección a sección hasta desaparecer al completarse la demolición.

### 3.6 Prioridades Configurables de Obras (`PanelEdificio`) y Jerarquía de Despacho
- [ ] **Acción:** En cenital, iniciar una obra de edificio residencial, marcar otro para demolición y dejar un tramo de vía en obra. Seleccionar el edificio en construcción en modo Ver (`Esc`).
- [ ] **Resultado esperado:**
  - En `PanelEdificio` aparece el botón **`[Prioridad: Normal]`**.
  - Hacer clics sucesivos cicla el valor: **`Normal`** $\to$ **`Alta`** $\to$ **`Baja`** $\to$ **`Normal`**.
  - Comprobar que los colonos libres se despachan respetando estrictamente el orden de prioridad global:
    1. *Construcción en Prioridad Alta*
    2. *Construcción en Prioridad Normal*
    3. *Demoliciones de edificios y vías*
    4. *Tendido de Vías*
    5. *Construcción en Prioridad Baja*

---

## Bloque 4: Supervisión Cívica, Moral Dinámica y Puestos Periféricos de Recolección

> **Condición previa:** Con la ciudad fundada y las vías trazadas, se auditan los paneles globales del HUD (Almacén, Población, Ocupaciones y Moral) y se levantan fuera de la zona de influencia los primeros **Puestos Periféricos de Nivel 1** (que operan directamente con Obreros y habilitan por primera vez los baúles de puesto para probar `VentanaBaul` y las rutas de acarreo por vía).

### 4.1 Barra Superior, Almacén Alfabético (A-Z), Población y Ocupaciones
- [ ] **Barra Superior:** Verificar los contadores de **Comida**, **Energía**, **Recurso Crítico** (formateando minerales como `"tierras raras"` con espacios legibles), **Población** y **Moral**.
- [ ] **Ventana de Almacén:** Hacer clic en el botón **Almacén**:
  - La lista de recursos se muestra ordenada estrictamente de la **A a la Z** en español (`Acero`, `Agua`, `Bloques de piedra`, `Carbón`, `Cobre`, `Combustible`, `Comida`, `Crudo`, `Hierro`, `Madera`, `Mineral refinado`, `Piedra`, `Tablas`, `Tierra`, `Tierras raras`).
- [ ] **Ventana de Población y Ocupaciones:** Hacer clic en **Población**:
  - Muestra la fila unificada: **`Obreros: Total · X empleados · Y desempleados`** (más las filas de Técnicos, Especialistas, Investigadores, Militares y Sin techo si aplica).
  - Pulsar el botón **Ocupaciones** dentro de Población: muestra las 4 categorías colapsables (`▼ Recolección`, `▼ Industria`, `▼ Investigación`, `▼ Energía`) que se contraen (`▶`) o expanden (`▼`) al hacer clic, listando los puestos del más reciente al más antiguo.

### 4.2 Sistema Dinámico de Moral Ciudadana (`VentanaMoral` — Tecla `M`)
- [ ] **Acción:** Observar el botón de moral en la barra superior (por defecto en torno a `🙂 75%` al inicio) y hacer clic sobre él o pulsar la tecla **`M`**.
- [ ] **Resultado esperado:**
  - Se despliega la ventana modal centrada **`VentanaMoral`** estilizada con `TemaHUD`.
  - Muestra el **Estado Anímico Actual** (con umbrales visuales: `😡` <20%, `🙁` 20–35%, `😐` 35–65%, `🙂` $\ge$65%), la **Tasa Horaria Proyectada** ($\Delta M$/h), el **Multiplicador de Productividad Laboral** continuo ($X = 0.5 \times 2^{(Y/50)}$, donde 50% = `1.00x`, 75% $\approx$ `1.41x`, 100% = `2.00x`) y el estado del **Flujo Migratorio**.
  - Detalla el desglose analítico de factores:
    1. *Inercia hacia neutralidad (50%)*
    2. *Abundancia / Escasez de recursos y cobertura energética*
    3. *Variedad de dieta alimentaria*
    4. *Desgaste por colonos sin techo (-0.05/h por colono)*
    5. *Buffer móvil de peligrosidad de los últimos 7 días (168 h)*
  - Se cierra limpiamente con el botón `X`, la tecla **`M`** o **`Esc`**.

### 4.3 Puestos Periféricos de Recolección (`1 -> 2 -> 1..4`: Caza, Madera, Mina, Pesca)
- [ ] **Regla de exclusión de Zona de Influencia:** En cenital, pulsar **`1`** (Construir) $\to$ **`2`** (Periférico) y elegir **Mina (`3`)**, **Madera (`2`)** o **Caza (`1`)**.
  - Mover el cursor **dentro** de la Zona de Influencia de la ciudad: la huella se muestra **roja (inválida)** porque los puestos periféricos deben situarse fuera del núcleo urbano.
  - Mover el cursor **fuera** de la Zona de Influencia (sobre bosque para Caza/Maderero, terreno firme para Mina, o costa mitad agua / mitad tierra para Pesca `4`): la huella pasa a **dorada (válida)** rodeada por el **halo circular azul** de su radio de acción.
- [ ] **Construcción y Operación con Obreros:** Emplazar una **Mina (`1-2-3`)** y un **Maderero (`1-2-2`)** fuera de la zona de influencia y dejar que los colonos completen la obra.
  - Hacer clic izquierdo sobre el puesto terminado en modo Ver (`Esc`) para abrir `PanelPuesto`.
  - Contratar **Recolectores** (toma Obreros/Desempleados) y **Acarreadores** con el botón `+`:
    - Verificar que cuando los recolectores llegan al interior del puesto (`presentes`), el puesto extrae mineral/madera física del entorno (la mina excava su cantera por franjas y el maderero tala árboles reales).
    - Verificar que los **acarreadores** recogen la carga desde la celda exterior frontal de `servicio` (frente a la puerta) y la llevan al almacén central sin quedarse congelados dentro del edificio.

### 4.4 Preferencia de Vías en el Pathfinding (`BuscadorRutas`) y Prioridad de Tráfico
- [ ] **Acción:** Trazar una **vía de tierra pisada (`1 -> 5 -> 1`)** que conecte el Núcleo Urbano con las inmediaciones de la Mina o Maderero periférico (rodeando un sector de campo abierto).
- [ ] **Resultado esperado (Preferencia A*):**
  - Al observar el recorrido de los acarreadores y trabajadores entre la ciudad y el puesto, **prefieren desplazarse por la vía de tierra pisada** (`coste_ruta = 3`) en vez de cortar por el terreno natural (`COSTE_TERRENO_NATURAL = 8`).
  - Si la puerta del puesto no toca directamente la vía, el colono viaja por la vía hasta el punto más próximo posible y solo pisa terreno natural en los últimos bloques.
- [ ] **Prioridad de paso en cuellos de botella:** En un paso estrecho de 1 celda, cuando dos colonos se cruzan de frente, el colono que transporta carga prioritaria (`comida > combustible > crudo > acero...`) mantiene su ruta y el colono descargado o de menor prioridad se aparta a una celda lateral para cederle el paso.

### 4.5 Interacción en 1ª Persona con el Baúl de un Puesto (`VentanaBaul` — Tecla `E`)
- [ ] **Condición cumplida:** Ahora que ya existe al menos un puesto periférico terminado y activo con su propio baúl de depósito.
- [ ] **Acción:** Cambiar a 1ª persona (**`C`**), caminar hasta la Mina o Maderero, abrir su puerta con **`E`**, apuntar la mira al **baúl interior** y pulsar **`E`**.
- [ ] **Resultado esperado:**
  - Se abre la ventana **`VentanaBaul`** perfectamente centrada en pantalla con dimensiones compactas (`320x260`) y barra de scroll vertical.
  - El cursor queda libre para transferir unidades entre el depósito local del puesto y el almacén central mediante los botones **`-`**, **`+`** o **`"Extraer todo"`**.
- [ ] **Cierre rápido:** Pulsar nuevamente **`E`** (o **`Esc`**) $\to$ la ventana se cierra de inmediato y el control de cámara en 1ª persona se restaura al instante.

---

## Bloque 5: Cadena Educativa, Industria de Nivel 1, Reservas e Investigación

> **Orden estricto de desbloqueo en código (`CamaraCenital.gd` y `Economia.gd`):**
> 1. Todas las refinerías (`Siderúrgica`, `Aserradero`, `Fábrica de bloques`, `Carbonera`, `Tierras raras`) exigen **Técnicos** para producir $\to$ primero debemos construir la **Escuela Técnica (`1-4-1`)** y graduar Técnicos.
> 2. La **Escuela de Especialistas (`1-4-2`)** exige tener al menos **1 Escuela Técnica construida** y gradúa Especialistas a partir de Técnicos.
> 3. La **Universidad (`1-4-3`)** exige tener al menos **1 Escuela de Especialistas construida** y emplea Especialistas como Investigadores.
> 4. La `Refinería petrolera`, el `Productor de combustible` y la `Central termoeléctrica` están bloqueadas hasta que la Universidad complete la investigación de **Metalurgia Aplicada** (`Ciudad.nivel_investigado >= 2`).

### 5.1 Escuela Técnica (`1 -> 4 -> 1`), Graduación de Técnicos y Niveles de Puesto
- [ ] **Acción (Construcción):** En cenital, asegurarse de tener espacio libre en **Zona Residencial (`2 -> 1`)** dentro de la Zona de Influencia. Pulsar **`1` (Construir) -> `4` (Investigación) -> `1` (Escuela técnica)** y colocarla sobre Zona Residencial.
- [ ] **Acción (Formación de Cohorte):** Una vez construida la Escuela Técnica, seleccionarla en modo Ver (`Esc`) y contratar el cupo completo de **4 Aprendices** (toma 4 obreros/desempleados).
- [ ] **Resultado esperado:**
  - Cuando los 4 aprendices están **presentes** dentro de la escuela en sus mesas de estudio, el progreso avanza 1 hora por tick (si se despide a uno antes de terminar, el progreso se reinicia a 0).
  - Al cumplirse las **24 horas**, la cohorte se gradúa y convierte a los 4 obreros en **3 Técnicos libres** (conservando exactamente 1 cama de vivienda ocupada).
- [ ] **Prueba de ascenso y retroceso de nivel en Mina/Maderero:**
  - Abrir el `PanelPuesto` de la Mina periférica, despedir a los recolectores obreros y contratar **1 Técnico**: el puesto sube a **Nivel 2** (mayor radio, profundidad 16 y multiplicador de extracción).
  - Contratar además **1 Recolector (Obrero)** en esa misma Mina: comprobar que el puesto **permite contratarlo y retrocede limpiamente a Nivel 1** (el rango mínimo de sus trabajadores) sin bloquearse.

### 5.2 Zonificación Industrial (`2 -> 2`), Fábrica de Bloques (`1 -> 3 -> 4`) y Refinerías de Nivel 1
- [ ] **Acción (Pintar Zona Industrial):** En cenital, pulsar **`2` (Zonificar) -> `2` (Zona Industrial)** y pintar un sector industrial **dentro de la Zona de Influencia** de la ciudad. Salir con `Esc`.
- [ ] **Acción (Construir Fábrica de Bloques y Siderúrgica):** Pulsar **`1` (Construir) -> `3` (Industrial)**:
  - Comprobar que el submenú Industrial lista 9 instalaciones (con paginación `Z`/`X` si aplica): `1: Siderúrgica`, `2: Tierras raras`, `3: Aserradero`, `4: Fábrica de bloques`, `5: Carbonera`, `6: Refinería petrolera`, `7: Productor combustible`, `8: Central termoeléctrica`, `9: Almacén`.
  - Seleccionar **`4` (Fábrica de bloques)**: verificar su miniatura 3D isométrica y emplazar su huella de **5×6 celdas** sobre la Zona Industrial. Emplazar también una **Siderúrgica (`1 -> 3 -> 1`)** y un **Aserradero (`1 -> 3 -> 3`)**.
- [ ] **Resultado esperado en la Fábrica de Bloques (`1 -> 3 -> 4`):**
  - Muros de `bloque_piedra`, puerta frontal de entrada de servicio ($Z=0$) para piedra cruda, puerta trasera de salida ($Z=5$) para bloques procesados y baúl interior.
  - En su `PanelPuesto`, contratar **Técnicos** (graduados en 5.1) y **Acarreadores (Obreros)**.
  - Al producir: la chimenea del techo (`Vector2i(2, 3)`) emite humo y polvo de cantería en vivo (`HumoRefinerias`), convirtiendo cada **1 unidad de `piedra` cruda en 3 unidades de `bloques_piedra`** (rendimiento $\times 3$).
- [ ] **Prioridad de Consumo Cívico de `bloques_piedra` en Obras:**
  - Con `bloques_piedra` ya entregados en el almacén central, colocar bloques de piedra a mano o iniciar una obra que demande piedra:
  - Comprobar en la ventana **Almacén** que `Ciudad.gd` **descuenta primero los `bloques_piedra` procesados** antes de gastar la `piedra` cruda, y que la disponibilidad general de piedra suma ambos stocks.

### 5.3 Control de Reserva Central de Materias Primas en Refinerías (`0 / 50 / 100 / 250 / 500 u`)
- [ ] **Acción:** En modo Ver (`Esc`), abrir el `PanelPuesto` de la **Fábrica de bloques**, **Siderúrgica** o **Aserradero**.
- [ ] **Resultado esperado:**
  - Debajo de la línea de producción aparece la fila **`Reserva central:`** con un botón selector estilizado con `TemaHUD`.
- [ ] **Acción (Ciclar umbrales):** Hacer clic sucesivo sobre el botón de reserva.
- [ ] **Resultado esperado:**
  - El texto del botón cicla en orden:
    `Sin reserva (0 u)` $\to$ `50 u` $\to$ `100 u` $\to$ `250 u` $\to$ `500 u` $\to$ `Sin reserva (0 u)`.
- [ ] **Acción (Protección contra sobre-refinado):** Fijar la reserva en un umbral (ej. `500 u`) y observar a los acarreadores de la refinería cuando el stock del almacén central esté en o por debajo de ese umbral:
  - Los acarreadores solo retiran del almacén central el excedente por encima de la reserva (`stock_central - reserva`). Si el stock central es $\le$ a la reserva configurada, detienen la extracción de insumos para no dejar al jugador sin hierro, madera o piedra para construir.

### 5.4 Escuela de Especialistas (`1 -> 4 -> 2`) y Graduación de Especialistas
- [ ] **Acción:** En cenital, pulsar **`1` (Construir) -> `4` (Investigación) -> `2` (Escuela de especialistas)** y colocarla sobre **Zona Residencial** dentro de la Zona de Influencia. *(Gracias a haber construido la Escuela Técnica en 5.1, el prerrequisito se cumple).*
- [ ] **Acción:** Una vez terminada la obra, abrir su `PanelPuesto` y contratar el cupo de **3 Aprendices** (toma 3 Técnicos libres; si tus Técnicos están ocupados en refinerías, despide temporalmente a 3 con `-` o gradúa otra cohorte en la Escuela Técnica).
- [ ] **Resultado esperado:**
  - Con los 3 técnicos aprendices presentes, tras **48 horas** de estudio se gradúa la cohorte convirtiéndose en **2 Especialistas libres** (3 técnicos = 2 especialistas = 1 cama).

### 5.5 Universidad Interactiva (`1 -> 4 -> 3`) e Investigación de "Metalurgia Aplicada"
- [ ] **Acción (Construcción):** En cenital, pulsar **`1` (Construir) -> `4` (Investigación) -> `3` (Universidad)** y colocarla sobre **Zona Residencial** dentro de la Zona de Influencia. *(Cumple el prerrequisito de tener al menos 1 Escuela de especialistas construida).*
- [ ] **Acción (Contratación e Inicio Manual):** Una vez construida la Universidad, seleccionarla en modo Ver (`Esc`):
  - Verificar que **no inicia ninguna investigación automáticamente** y muestra el botón **`[Iniciar Investigación]`**.
  - Pulsar `+` en la fila **Investigadores** para contratar a los **Especialistas libres** (graduados en 5.4), quienes pasan al oficio de `investigador`.
  - Pulsar **`[Iniciar Investigación]`**: se abre el diálogo modal (`TemaHUD`) para **`Investigar: Metalurgia Aplicada`** indicando `Costo: 300 hierro, 200 madera` y el `Tiempo estimado` según el número de investigadores asignados (meta: `20 horas-investigador`). Confirmar.
- [ ] **Acción (Aceleración, Pausa y Cancelación con Reembolso):**
  - **Aceleración:** Asignar un segundo investigador y comprobar que la velocidad de avance se duplica y las horas estimadas se reducen a la mitad.
  - **Pausar / Reanudar:** Hacer clic en **`[Pausar]`** $\to$ el estado indica `(Pausado)`, el progreso se congela y el botón cambia a **`[Reanudar]`**. Pulsar **`[Reanudar]`**.
  - **Cancelar con reembolso íntegro:** Hacer clic en **`[Cancelar]`** y confirmar en el diálogo modal $\to$ la investigación se cancela, el progreso vuelve a 0% y **se reembolsan íntegramente los 300 de hierro y 200 de madera** al almacén central.
- [ ] **Acción (Completar "Metalurgia Aplicada"):** Volver a pulsar **`[Iniciar Investigación]`**, confirmar y dejar que los investigadores alcancen el **100% (20 horas-investigador)**.
- [ ] **Resultado esperado:**
  - Notificación de tecnología completada: **`Metalurgia Aplicada`** (`Ciudad.nivel_investigado = 2`).
  - Quedan desbloqueadas en el menú Industrial (`1 -> 3`) la **Refinería petrolera (`6`)**, el **Productor de combustible (`7`)** y la **Central termoeléctrica (`8`)**.

---

## Bloque 6: Extracción de Fluidos, Industria Petroquímica y Canalizaciones Elevadas

> **Condición previa cumplida:** Ya disponemos de **Técnicos** (Bloque 5.1) para operar los extractores y refinerías, y ya hemos investigado **Metalurgia Aplicada** (Bloque 5.5) para construir la Refinería Petrolera y el Productor de Combustible.

### 6.1 Estación de Bombeo de Agua (`1 -> 2 -> 5` — Periférico)
- [ ] **Prueba de rechazo en agua somera:** En cenital, seleccionar **`1` -> `2` -> `5` (Estación de bombeo)** e intentar colocarla sobre la orilla con solo 1 bloque de profundidad de agua: rechaza con el aviso *"requiere al menos 2 bloques de profundidad de agua bajo su muelle"*.
- [ ] **Colocación válida en agua profunda ($\ge 2$ bloques):** Ubicarla **fuera de la Zona de Influencia** con el muelle sobre agua de $\ge 2$ bloques de profundidad y la plataforma sobre tierra firme (usando `Ctrl + Scroll` para orientarla).
- [ ] **Resultado esperado:**
  - Una vez construida, cuenta con el bloque **`puerto_agua_out`** en su pared de tierra a cota elevada ($Y = Y_{base} + 4$).
  - En su `PanelPuesto`, solo admite el rol **`Técnicos`** (0 acarreadores, ya que los fluidos viajan exclusivamente por ductos) y muestra el desplegable de su puerto de salida (`⚪ Desconectado`). Contratar al menos 1 Técnico.

### 6.2 Centro de Extracción Subterráneo (`1 -> 2 -> 6` — Periférico)
- [ ] **Prueba sin depósito:** Seleccionar **`1` -> `2` -> `6` (Centro de extracción)** y mover el cursor sobre terreno común sin yacimiento: la huella se muestra roja y la tarjeta indica *"No se detecta depósito subterráneo de agua o crudo"*.
- [ ] **Detección de pozo subterráneo y columna de perforación:** Mover el cursor **fuera de la Zona de Influencia** explorando el mapa hasta que la huella se torne **dorada** sobre un pozo subterráneo de `crudo` (o `agua`).
  - Comprobar que la ficha técnica añade dinámicamente el costo en **`Estructura de hierro`** (`estructura_hierro`) proporcional a la profundidad del pozo bajo tierra.
  - Hacer clic izquierdo para emplazarlo y dejar que se complete la obra.
- [ ] **Resultado esperado:**
  - Al completarse, se genera físicamente bajo el edificio la columna vertical de `estructura_hierro` hasta el fondo del yacimiento.
  - Al seleccionarlo en modo Ver (`Esc`), `PanelPuesto` indica **`Crudo restante en pozo: X bloques`** (o `Pozo de agua (inagotable)`), cuenta con puerto de salida a cota $Y=4$ y admite únicamente **Técnicos**. Contratar al menos 1 Técnico.

### 6.3 Almacén de Fluidos (`1 -> 3 -> 9`), Refinería Petrolera (`1 -> 3 -> 6`) y Productor de Combustible (`1 -> 3 -> 7`)
- [ ] **Almacén (`1 -> 3 -> 9`):** En cenital, colocar un **Almacén** (5×5 de piedra) sobre **Zona Industrial (`2 -> 2`)**.
  - Al terminarse, comprobar que tiene **6 puertos exteriores** a cota $Y=4$: pared izquierda con 3 entradas (`agua`, `crudo`, `combustible`) y pared derecha con 3 salidas (`agua`, `crudo`, `combustible`).
  - En `PanelPuesto`, los 6 puertos aparecen agrupados en **desplegables colapsables por recurso** con indicadores `⚪ Desconectado`, `🟢 Conectado` o `🔴 Derrame`. Todos los almacenes comparten un depósito global de fluidos instantáneo (1000 u por almacén).
- [ ] **Refinería Petrolera (`1 -> 3 -> 6`):** Colocarla sobre **Zona Industrial** (ya desbloqueada por *Metalurgia Aplicada*).
  - Cuenta con `puerto_crudo_in` (izquierda) y `puerto_combustible_out` (derecha), sin acarreadores de fluidos. Contratar **Técnicos**.
- [ ] **Productor de Combustible (`1 -> 3 -> 7`):** Colocarlo sobre **Zona Industrial**.
  - Cuenta con `puerto_agua_in` y `puerto_combustible_out`. Admite **Técnicos** y **Acarreadores** (sus acarreadores solo transportan `carbón` sólido desde el almacén central, respetando la `Reserva central:` configurada).

### 6.4 Trazado de Canalizaciones Elevadas (`1 -> 6 -> 1` Acueducto / `1 -> 6 -> 2` Tubería)
- [ ] **Ficha técnica con etiquetas legibles:** En cenital, pulsar **`1` (Construir) -> `6` (Ductos)** y elegir **`1` (Acueducto)** o **`2` (Tubería)**:
  - Verificar que la tarjeta contextual muestra nombres legibles en español (ej. `1 Bloque de piedra`, `1 Bloque de acero`, `1 Estructura de hierro`), **nunca** claves de código como `bloque_acero`.
- [ ] **Cota elevada ($Y_{suelo} + 4$), Columnas cada 5 bloques y Mallas sin Z-Fighting:**
  - Trazar un tramo en "L" de al menos 11 bloques haciendo clic izquierdo en el inicio, clic izquierdo en la esquina de 90° y **doble clic izquierdo** en el final:
  - El ducto se construye elevado dejando **3 bloques libres de altura bajo la viga** ($Y = Y_{suelo} + 4$).
  - Las columnas de soporte se colocan cada **5 bloques** (en 0, 5, 10..., dejando 4 celdas de vano libre entre pilares) y siempre en cada esquina de 90°.
  - Las texturas del ducto se ven bien orientadas y la unión entre las vigas horizontales y los bloques sobre las columnas **no presenta parpadeos ni *z-fighting***.
- [ ] **Libre circulación inferior de colonos y vías terrestres:**
  - Caminar con el avatar en 1ª persona por debajo de los vanos del ducto: paso totalmente despejado.
  - En cenital, activar el trazador de vías (**`1 -> 5 -> 1`**) y trazar una vía de tierra pisada que cruce **por debajo** del vano del ducto elevado: la vía se construye limpiamente sin colisionar con el ducto.

### 6.5 Cruces a Desnivel entre Dos Ductos (Doble Columna a $Y=6$ y Aire Libre a $Y=5$)
- [ ] **Acción:** Tener un Acueducto construido (ej. en dirección Norte-Sur a $Y = Y_{suelo} + 4$) y trazar una **Tubería** (`1 -> 6 -> 2`) que lo cruce perpendicularmente (Este-Oeste).
- [ ] **Resultado esperado:**
  - En las dos celdas inmediatamente adyacentes al punto de cruce, se levantan automáticamente **dos columnas nuevas de 6 bloques de altura** ($Y = Y_{suelo} + 5$) con su bloque de ducto encima.
  - El tramo superior cruza a **$Y = Y_{suelo} + 6$**, dejando **1 bloque completo de aire libre** ($Y = Y_{suelo} + 5$) entre el ducto inferior y el superior.
  - Ambos ductos quedan físicamente separados: no se mezclan sus fluidos ni se rompe uno al demoler el otro.

### 6.6 Conexión a Puertos, Partición 400/600 en Refinería, Inspección (`PanelCanalizacion`) y Demolición Limpia
- [ ] **Conexión de Acueducto (Estación de Bombeo $\to$ Almacén):**
  - Con **`1 -> 6 -> 1` (Acueducto)**, hacer clic izquierdo en la celda exterior frente al `puerto_agua_out` de la Estación de Bombeo (el primer bloque se engancha a cota $Y=4$ sin columna debajo) y llevar el trazado hasta la celda frente al `puerto_agua_in` (entrada 1) del Almacén, confirmando con **doble clic izquierdo**.
  - En `PanelPuesto` de ambos edificios, los puertos pasan a **`🟢 Conectado`** y el agua extraída ingresa cada hora al depósito global de fluidos sin usar acarreadores.
- [ ] **Conexión de Tubería y Límite 400/600 en Refinería Petrolera:**
  - Con **`1 -> 6 -> 2` (Tubería)**, conectar el `puerto_crudo_out` del Centro de Extracción de Crudo al `puerto_crudo_in` de la Refinería Petrolera, y conectar el `puerto_combustible_out` de la Refinería al puerto de entrada de combustible del Almacén.
  - Verificar en el `PanelPuesto` de la Refinería Petrolera que:
    - El crudo en el pozo subterráneo va disminuyendo bloque a bloque (`Crudo restante en pozo: X bloques`).
    - El inventario local de crudo dentro de la Refinería **nunca supera las 400 unidades (40%)**, reservando siempre **600 unidades (60%)** de espacio libre para que la producción de combustible jamás se bloquee por sobrellenado.
- [ ] **Inspección (`PanelCanalizacion`) y Demolición sin Bloques Fantasma:**
  - En cenital modo Ver (`Esc`), hacer clic izquierdo sobre cualquier bloque de una canalización: se abre **`PanelCanalizacion`** mostrando Tipo, Recurso transportado, Longitud, Edificios conectados y Estado (`🟢 Conectado`).
  - Hacer clic en **`[Demoler canalización]`** y confirmar: el ducto completo se retira reembolsando sus materiales, y la celda frente al puerto del edificio queda **completamente limpia (sin bloques fantasma)**, permitiendo volver a conectar un nuevo ducto en ese mismo puerto de inmediato.

### 6.7 Derrame Físico de Crudo (Spill), Físicas de Viscosidad/Drenado en 1ª Persona y Reconexión desde Columna
- [ ] **Provocar un Derrame en Extremo Abierto:**
  - Con **`1 -> 6 -> 2` (Tubería)**, iniciar un trazado en el `puerto_crudo_out` del Centro de Extracción de Crudo (con al menos 1 Técnico trabajando), avanzar 6–8 celdas hacia terreno despejado y confirmar con **doble clic izquierdo dejando el extremo final suelto en el aire** (sin conectar a ningún edificio).
- [ ] **Resultado esperado (Spill y Spreading):**
  - En el siguiente tick horario, el estado del ducto y del puerto cambia a **`🔴 Derrame`** y el HUD emite una alerta.
  - En la boca abierta del extremo desconectado se engendra un bloque físico de **`crudo`** que cae al suelo y **activa la física de *spreading* viscoso** (extendiéndose lentamente hasta 3 celdas horizontales por gravedad).
- [ ] **Prueba en 1ª Persona: Viscosidad Pesada en Crudo (0.20) y Drenado con Bloques Sólidos:**
  - Pulsar **`C`** para bajar a 1ª persona y caminar hacia los bloques de **`crudo`** recién derramados:
    - Comprobar que el bloque de crudo es translúcido oscuro aceitoso y permeable.
    - Al entrar en el crudo, la velocidad horizontal, el salto y la caída del avatar se reducen drásticamente (**factor de viscosidad `0.20`**, cinco veces más denso que en seco y notablemente más pesado que el agua).
  - Seleccionar un bloque sólido en la hotbar (ej. `tierra` con tecla `1`), apuntar a un bloque de `crudo` derramado en el suelo y hacer **Clic Derecho**:
    - Comprobar que el bloque sólido **reemplaza y drena el bloque de crudo al instante**, permitiendo "secar" manualmente cualquier charco de crudo.
- [ ] **Reconstrucción / Extensión desde Columna en Derrame o Desconectada:**
  - Volver a cenital (**`C`**), activar **`1 -> 6 -> 2` (Tubería)** y hacer clic izquierdo directamente sobre la **última columna** de la tubería que está en estado `🔴 Derrame` (o `⚪ Desconectado`).
  - Continuar el trazado desde esa columna hasta la celda frente al `puerto_crudo_in` de la Refinería Petrolera (o del Almacén) y confirmar con **doble clic izquierdo**.
  - **Resultado esperado:** Los nuevos tramos se fusionan con la tubería existente, la red queda sellada en estado **`🟢 Conectado`** y el derrame activo se detiene y limpia de inmediato.

---

## Bloque 7: Generación Termoeléctrica, `VentanaEnergia`, Lámpara Eléctrica y Estrés Demográfico

> **Cierre del ciclo de pruebas:** Con la red petroquímica operativa y *Metalurgia Aplicada* investigada, se levanta la **Central Termoeléctrica** para electrificar la colonia, se audita el modal interactivo **`VentanaEnergia`**, se comprueba la conmutación de la lámpara del avatar a **`LÁMPARA ELÉCTRICA🟡`** (con batería de 72 h) y se cierra la sesión con las pruebas extremas de demografía.

### 7.1 Central Termoeléctrica (`1 -> 3 -> 8`): Selector de Combustible, Reserva y Acarreo de Carbón
- [ ] **Construcción:** En cenital, pulsar **`1` (Construir) -> `3` (Industrial) -> `8` (Central termoeléctrica)** y emplazarla sobre **Zona Industrial** dentro de la Zona de Influencia.
- [ ] **Operación en modo Carbón (Acarreo Sólido):**
  - Una vez construida, abrir su `PanelPuesto` en modo Ver (`Esc`).
  - Verificar los tres botones del selector de combustible: **`[Carbón]`** (activo por defecto), **`[Combustible]`** y **`[Crudo]`**, además de la fila **`Reserva central:`**.
  - Contratar **Técnicos** y **Acarreadores (Obreros)**:
    - Comprobar que los acarreadores buscan `carbón` en el Núcleo Urbano o almacenes centrales (respetando el umbral de `Reserva central:`) y lo descargan en la central (capacidad local hasta 500 u).
    - Con técnicos presentes y carbón en su depósito, la central empieza a generar energía eléctrica para la ciudad y su chimenea emite humo.
- [ ] **Operación en modos Crudo / Combustible (Por Tubería):**
  - Hacer clic en **`[Combustible]`** o **`[Crudo]`**: comprobar que la central libera automáticamente a sus acarreadores (ya no muestra la fila de acarreadores) y pasa a alimentarse exclusivamente a través de sus puertos laterales de tubería (`puerto_combustible_in` o `puerto_crudo_in`). Volver a dejarla con combustible disponible y generando energía.

### 7.2 Botón "Energía" en Barra Superior, Modal `VentanaEnergia` y Teletransporte de Cámara
- [ ] **Acción:** En la barra superior del HUD, mover el cursor sobre el indicador de **Energía** y hacer clic izquierdo.
- [ ] **Resultado esperado:**
  - El indicador funciona como un **botón interactivo** (con el mismo estilo visual que `Almacén`, `Población` y `Moral`) y abre la ventana modal centrada **`VentanaEnergia`** (`TemaHUD`).
- [ ] **Resumen Global y Listados en `VentanaEnergia`:**
  - **Cabecera de Balance:** Muestra **Capacidad Total Generada** (E/h), **Energía Entregada** (E/h), **Demanda Total de la Ciudad** (E/h) y **Balance** (`Superávit (100%)` en verde o `Déficit (-X%)` en rojo cuando la demanda de consumidores supera la generación).
  - **Sección Fuentes Generadoras:** Lista cada Central Termoeléctrica indicando su combustible activo (`Carbón`, `Combustible` o `Crudo`), las unidades restantes en su depósito local y los E/h aportados.
  - **Sección Edificios Consumidores:** Lista cada edificio que demanda electricidad (Refinería petrolera, Productor de combustible, etc.), su estado (`Conectado`, `Sin conexión`, `Déficit`) y su consumo individual en E/h.
- [ ] **Teletransporte de Cámara al Hacer Clic:**
  - Hacer clic izquierdo sobre cualquiera de los edificios listados en `VentanaEnergia` (generador o consumidor):
  - La Cámara Cenital **vuela con una transición suave (`Tween`) hasta centrarse sobre las coordenadas exactas de ese edificio** y abre su panel lateral, permitiendo inspeccionarlo o abastecerlo al instante.

### 7.3 Conmutación de la Lámpara del Avatar a `LÁMPARA ELÉCTRICA🟡` y Ciclo de Batería (72 h)
- [ ] **Condición cumplida:** La Central Termoeléctrica está activa y entregando energía a la red de la ciudad (`capacidad > 0`).
- [ ] **Acción (Encendido Eléctrico en Ciudad):** Pasar a 1ª persona (**`C`**) estando **dentro de la Zona de Influencia** de la colonia y pulsar **`L`** para encender la lámpara.
- [ ] **Resultado esperado:**
  - Como ahora la ciudad produce energía eléctrica, la lámpara se enciende en modo **`LÁMPARA ELÉCTRICA🟡`** (luz blanca intensa, rango 18 m, sin gastar combustibles sólidos ni líquidos del almacén).
  - `PanelLampara` muestra el título **`LÁMPARA ELÉCTRICA🟡`** y el estado **`Batería: 100% | 72 h`**.
- [ ] **Acción (Descarga fuera de la Zona de Influencia):** Caminar con la lámpara encendida **fuera de la Zona de Influencia** de la ciudad y esperar varios ticks horarios (2 s por hora):
  - `PanelLampara` pasa a mostrar la descarga progresiva de la batería: **`Batería: -X% | Y h`** (descontando 1 h de batería por cada hora de juego fuera de cobertura).
  - *(Si la batería llegara a `0 h` estando fuera de la zona de influencia, conmuta automáticamente a `LÁMPARA TÉRMICA🟡` consumiendo combustible/carbón/madera del inventario).*
- [ ] **Acción (Recarga Automática al Regresar a la Ciudad):** Volver a entrar en la **Zona de Influencia** de la ciudad electrificada:
  - La lámpara se mantiene (o conmuta de inmediato) en **`LÁMPARA ELÉCTRICA🟡`** y recarga su batería rápidamente a razón de **`+7.2 h` por cada hora de juego** (`Batería: +X% | Y h`) hasta alcanzar nuevamente el `100% | 72 h`.

### 7.4 Pruebas de Estrés Demográfico y Sucesión (Fin de Sesión)
> *(Nota: Ejecutar estas comprobaciones al cierre de la sesión de pruebas, ya que alteran la población o fuerzan estados de emergencia en la colonia).*

- [ ] **Tolerancia de Desempleo (240 h) y Sin Techo (72 h):**
  - Comprobar que los colonos que permanecen en estado `"Sin techo"` más de **72 horas (3 días)** emigran de la colonia penalizando `-10` puntos de moral.
  - Comprobar que los colonos que permanecen como `"desempleado"` durante **240 horas (10 días)** continuas sin ser contratados emigran pacíficamente incrementando el contador de desahuciados/emigrados.
- [ ] **Hambruna (0 Comida) y Éxodo por Moral Crítica (<20%):**
  - Si el stock de `comida` cae a `0`, cada hora de inanición provoca bajas en la población según `ORDEN_BAJAS_HAMBRUNA` (`militar > obrero > tecnico > especialista > investigador > desempleado`) y reduce la moral en **`-3.0/h`**.
  - Cuando la moral cae por debajo del **20% (`😡`)**, el flujo migratorio se invierte en **éxodo activo por desesperanza**, provocando una fuga de talentos que expulsa primero a los colonos más cualificados según `ORDEN_EXODO_MORAL` (`investigador > especialista > tecnico > militar > obrero > desempleado`).
- [ ] **Sucesión del Avatar (Tecla `K` o Ahogamiento):**
  - Pulsar la tecla de prueba **`K`** en 1ª persona (o agotar a 0 la barra de oxígeno bajo el agua): se ejecuta `Ciudad.suceder_avatar()` (si hay militares aplica sucesión con 5 h de penalización electoral y reaparece en el origen `(0, 1, 0)` con oxígeno al máximo).

---

## Bloque 8: Verificación en Vivo de la Iconografía Integral y Miniaturas 3D (HUD / UI)

### 8.1 Barra Superior e Iconografía Vectorial
- [ ] **Acción:** Observar la barra superior en 1ª persona y en cenital.
- [ ] **Resultado esperado:**
  - El censo muestra el ícono de grupo demográfico (`censo.svg`).
  - La moral exhibe el ícono emocional correspondiente según su valor actual (`moral_alta.svg` 🙂, `moral_neutra.svg` 😐, `moral_baja.svg` 🙁, `moral_critica.svg` 😡).
  - El botón Almacén muestra el ícono de cofre/almacén (`almacen.svg`).
  - La comida muestra el ícono de saco de trigo (`comida.svg`) y la flecha de tendencia horaria (`tasa_arriba.svg`, `tasa_neutra.svg` o `tasa_abajo.svg`).
  - El botón de Energía muestra el rayo interactivo (`energia_dorado.svg` con superávit, `energia_gris.svg` con balance neutro o `energia_rojo.svg` con déficit) junto a la lectura en kW (ej. `12 kW / 8 kW`).
  - El nivel de la ciudad muestra la insignia de números romanos (`romano_1.svg`, `romano_2.svg`, etc.).

### 8.2 Botones de Construcción con Insignias en 3 Esquinas y Miniaturas 3D Vivas
- [ ] **Acción:** Pasar a la cámara cenital (`C`) y presionar `1` (Construir) $\to$ revisar los submenús de categorías (`1` a `6`).
- [ ] **Resultado esperado:**
  - Los botones de edificios tienen tamaño ampliado (104×76 px) y muestran el sistema de insignias en 3 esquinas:
    1. **Esquina superior izquierda:** Columna vertical de íconos (14×14 px) con los recursos requeridos para construir la estructura.
    2. **Centro superior:** Ícono de energía dorado (14×14 px) si el edificio requiere suministro eléctrico continuo para operar.
    3. **Esquina superior derecha:** Ícono representativo (18×18 px) del bien o función principal que produce el edificio.
  - En la categoría Vías (`5`), el botón muestra una miniatura 3D en vivo con balastro de grava y durmientes de madera.
  - En la categoría Ductos (`6`), el Acueducto muestra canal de piedra sobre columnas, y la Tubería muestra ducto cilíndrico metálico con codo.
  - En la hotbar de 1ª persona, los bloques de vidrio y puertas muestran marcos de contraste de madera para no perder visibilidad.

### 8.3 Interfaz en Primera Persona y Herramienta de Minado Contextual
- [ ] **Acción:** Pasar a 1ª persona (`C`). Encender la lámpara (`L`), sumergirse en agua y comenzar a picar distintos tipos de bloques manteniendo clic izquierdo.
- [ ] **Resultado esperado:**
  - El panel de la lámpara muestra el ícono de bombilla/antorcha y una barra de progreso porcentual (`ProgressBar`) estilizada en verde/oro.
  - Al sumergirse, el indicador de oxígeno muestra una fila de burbujas celestes que se vacían progresivamente.
  - Al picar piedra, aparece la barra de progreso de minado acompañada a la izquierda del ícono contextual del pico (`herr_pico.svg`); al palear tierra, el ícono de la pala (`herr_pala.svg`); al talar árboles, el hacha (`herr_hacha.svg`).

### 8.4 Ventanas Globales, Paneles de Edificio/Puesto y Diálogos Modales
- [ ] **Acción:** Abrir Población (`P`), Almacén (`A`), Ocupaciones, Energía (`E`) y Moral (`M`).
- [ ] **Resultado esperado:**
  - Todos los títulos de ventana cuentan con su ícono temático correspondiente y botón de cierre `✕`.
  - En `VentanaAlmacen`, cada recurso cuenta con su ícono de 20×20 px junto al nombre.
  - En `VentanaPoblacion` y `VentanaOcupaciones`, cada oficio y categoría cuenta con su ícono representativo.
  - En `VentanaMoral`, el medidor analítico central integra el rostro emocional en 32×32 px y los factores desglosan íconos de balanza, comida, cornucopia y escudo.
  - En `VentanaBaul`, cada recurso cuenta con su ícono y los botones de extracción muestran `btn_menos`, `btn_mas` y `extraer_todo`.
  - En `PanelEdificio` y `PanelPuesto`, los estados de colonización muestran íconos de candado/reloj/puerta, los botones de pausa/play muestran sus íconos, la prioridad muestra insignias `prio_alta`/`prio_normal`/`prio_baja`, y las escuelas muestran las insignias romanas de nivel.
  - Los diálogos modales de confirmación (demoler, remodelar, etc.) exhiben el botón Aceptar con ícono `check.svg` verde y Cancelar con `cruz.svg` roja.

---

## Tabla de Resumen y Aprobación Rápida

| Bloque | Característica comprobada (en orden lógico de juego) | Estado (OK / Fallo) | Notas del tester |
| :--- | :--- | :---: | :--- |
| **1.1** | Movimiento en 1ª persona, resaltado de cara, tala/minado con progreso y colocación | | |
| **1.2** | Natación en agua ($\ge 2$ bloques), corrientes, oxígeno y drenado con bloques sólidos | | |
| **1.3** | Lámpara en modo Térmico inicial (`L`: combustible 10h, carbón 6h, madera 5h) y oxígeno apilado | | |
| **2.1** | 1er Edificio declarado con `B` (2 plantas, piso 1 sin puerta exterior) funda el **Núcleo Urbano** y crea blueprint | | |
| **2.2** | Remodelación del Núcleo Urbano (`Shift+B`) en edición libre sin pérdida de sede | | |
| **2.3** | Pintado de Zona Residencial (`2-1`), miniatura 3D de blueprint (`1-1`), rotación `Ctrl+Scroll` y surtido a pie | | |
| **2.4** | 1ª Residencia habitable nace con `Colonizable: SÍ` y atrae a los primeros colonos | | |
| **2.5** | Remodelación de única residencia poblada genera colonos `"Sin techo"` y redeclarar con `B` los reabsorbe | | |
| **2.6** | 2ª Residencia construida por colonos nace como buffer (`Colonizable: NO 24h`) y permite reubicar sin dejar sin techo | | |
| **2.7** | Edificios adosados (flood-fill se detiene en muro vecino) y traslado de Núcleo Urbano (gracia de 5 h) | | |
| **3.1** | Trazador cenital de vías (`1-5-1`) con iconos SVG, ficha técnica (`+35%`) y cancelación limpia con clic derecho | | |
| **3.2** | Nivelación y despeje compartidos entre puertas enfrentadas en una calle | | |
| **3.3** | Tendido progresivo de vías por colonos (`ViaObraOverlay` amarillo consecutivo) y fusión de tramos | | |
| **3.4** | Intervención manual de vías a pie (`V`): construir (clic izq.) y demoler (clic der.) secciones 2×2 | | |
| **3.5** | Demolición cenital unificada (`3`): edificios y vías con Dijkstra en esquinas de 90° y outline naranja | | |
| **3.6** | Prioridades de obra (`Normal`/`Alta`/`Baja` en `PanelEdificio`) y jerarquía estricta de despacho | | |
| **4.1** | Topbar responsiva (`"tierras raras"`), Almacén alfabético A-Z (`"Bloques de piedra"`), Población y Ocupaciones (▼/▶) | | |
| **4.2** | Moral dinámica: botón con 4 emojis y modal `VentanaMoral` (`M`) con productividad y desglose de factores | | |
| **4.3** | Puestos periféricos (`1-2-1..4`) fuera de zona de influencia: extracción física y acarreo en celda `servicio` | | |
| **4.4** | Preferencia de vías en pathfinding (`BuscadorRutas`: vía coste 3 vs campo 8) y prioridad de paso con carga | | |
| **4.5** | Interacción en 1ª persona con baúl de puesto activo (`VentanaBaul` con `E`: centrada `320x260`, scroll y cierre rápido) | | |
| **5.1** | Escuela técnica (`1-4-1` en Zona Residencial): cohorte de 4 aprendices (24 h) gradúa **3 Técnicos** y niveles en mina | | |
| **5.2** | Zona Industrial (`2-2`) y Fábrica de bloques (`1-3-4`): huella 5×6, chimenea, receta 1:3 y prioridad de gasto en obras | | |
| **5.3** | Control de reserva central (`0/50/100/250/500 u`) en refinerías: protección del stock contra sobre-refinado | | |
| **5.4** | Escuela de especialistas (`1-4-2`): exige Escuela técnica y gradúa **2 Especialistas** tras 48 h | | |
| **5.5** | Universidad (`1-4-3`): exige Escuela de especialistas, inicio manual, pausa, cancelación con reembolso y **Metalurgia Aplicada** | | |
| **6.1** | Estación de bombeo (`1-2-5`): validación de agua $\ge 2$ bloques, muelle, `puerto_agua_out` y operación con Técnicos | | |
| **6.2** | Centro de extracción (`1-2-6`): detección de pozo subterráneo, columna de hierro dinámica y agotamiento de crudo | | |
| **6.3** | Almacén de fluidos (`1-3-9`, 6 puertos en desplegables), Refinería petrolera (`1-3-6`) y Productor de combustible (`1-3-7`) | | |
| **6.4** | Canalizaciones elevadas (`1-6-1`/`1-6-2`): etiquetas legibles, cota $Y+4$, paso libre de vías/colonos y columnas cada 5 bloques | | |
| **6.5** | Cruces a desnivel de ductos: doble columna lateral a $Y=6$ con 1 bloque de aire libre intermedio ($Y=5$) | | |
| **6.6** | Conexión a puertos, partición 400/600 en Refinería petrolera, `PanelCanalizacion` y demolición limpia sin fantasmas | | |
| **6.7** | Derrame físico en extremo abierto (`🔴 Derrame`), viscosidad 0.20 y drenado de `crudo` en 1ª persona, y reconexión desde columna | | |
| **7.1** | Central termoeléctrica (`1-3-8`): selector `Carbón`/`Combustible`/`Crudo`, reserva central y acarreo de carbón | | |
| **7.2** | Botón "Energía" en topbar y `VentanaEnergia`: balance global, generadores, consumidores y teletransporte de cámara | | |
| **7.3** | Conmutación de lámpara a `LÁMPARA ELÉCTRICA🟡` (batería 72 h en red, descarga fuera de influencia y recarga `+7.2 h/tick`) | | |
| **7.4** | Estrés demográfico final: emigración por sin techo (72 h) / desempleo (240 h), hambruna, éxodo (<20% moral) y sucesión (`K`) | | |
| **8.1** | Barra superior: censo, 4 estados de moral, almacén, tendencia de comida, y rayo interactivo tri-color de energía en kW | | |
| **8.2** | Menú Construir (104×76 px): overlay de insignias en 3 esquinas (insumos, energía, producto) y miniaturas 3D (vías, acueducto, tubería) | | |
| **8.3** | Interfaz 1ª persona: farol con ProgressBar de batería, burbujas de oxígeno y herramienta contextual al minar | | |
| **8.4** | Paneles globales y de interacción: íconos de recursos en almacén/baúl, oficios en población/ocupaciones, factores en moral | | |
| **8.5** | Diálogos modales y controles: confirmación con `check`/`cruz`, estados de puerta en edificios y keycaps dorados | | |

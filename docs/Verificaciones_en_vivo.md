# Guión de Verificaciones en Vivo (Live QA Script) — Craft to Nation

Este documento es el guión integral de pruebas manuales paso a paso para comprobar en vivo, directamente dentro del juego en ejecución (**F5** en Godot), que todas las mecánicas de avatar, fundación urbana, decretos cívicos, demografía, moral dinámica, alimentación estratificada, red vial, cadena educativa, evolución de eras (IDU), investigación en dos capas, reconversión doctrinal, logística de transporte, industria (incluida vidriería), fluidos, canalizaciones elevadas y red eléctrica operan de manera óptima y sin errores.

El guión está diseñado siguiendo **estrictamente el orden cronológico y de prerrequisitos reales de jugabilidad**: ninguna prueba exige edificios, oficios, eras, tecnologías o estados del mundo que no hayan sido desbloqueados o construidos en los pasos previos.

---

## 0. Preparativos, Estado Inicial y Controles Globales

### Iniciar el entorno y condiciones de partida
1. Abrir el proyecto en Godot y pulsar **F5** (o ejecutar la escena principal `Main.tscn`).
2. Comprobar que el avatar aparece en 1ª persona y que la barra superior del HUD es visible.
3. **Inventario inicial de prueba (`Player.gd` / `Ciudad.gd`):** Al iniciar en modo prueba, el almacén cuenta con **1000 unidades de cada recurso** (incluyendo `Vidrio`) y **5000 unidades de comida** (repartidas inicialmente en el sub-almacén alimentario entre `2500 Pescado y mariscos` y `2500 Caza y frutos`), lo que permite ensayar la colocación de estructuras sin tener que talar o minar durante horas.
4. **Estado inicial de la colonia (`Ciudad.gd`):**
   - **Núcleo Urbano:** No declarado todavía (no existe Zona de Influencia ni llegan inmigrantes hasta declarar el primer edificio en el Bloque 2).
   - **Era e Índice de Desarrollo Urbano (IDU):** Arranca en **Era 1 (`Asentamiento Pionero`)** con insignia romana **`I` (`IDU: 1.00`)** en el extremo derecho de la barra superior.
   - **Nivel tecnológico:** `nivel_investigado = 1` (la industria petroquímica y termoeléctrica requiere investigar *Metalurgia Aplicada* en la Universidad en el Bloque 5).
   - **Energía en red:** `0 kW` (hasta construir y abastecer una Central Termoeléctrica en el Bloque 7).
   - **Moral ciudadana:** Arranca en `🙂 75%` (*Optimismo pionero*) con barra sombreada de progreso en el botón de la barra superior.

### Atajos de Teclado Clave

> [!IMPORTANT]
> **Apertura y cierre de las ventanas de Moral (`VentanaMoral`) y Energía (`VentanaEnergia`):**
> Las teclas **`M`**, **`E`** y **`Esc`** **no** abren ni cierran las ventanas de Moral ni de Energía. Ambas ventanas se abren **únicamente haciendo clic izquierdo en su respectivo botón de la barra superior** y se cierran **exclusivamente pulsando su botón `X`** (`cruz.svg`) en la esquina superior derecha del modal.

#### Primera Persona (Avatar)
| Tecla / Acción | Función |
| :--- | :--- |
| **C** | Alternar entre cámara en **1ª persona** y **Cámara Cenital** (con transición animada; oculta temporalmente `VentanaMoral` y `VentanaEnergia` al bajar a 1ª persona y las restaura al volver a cenital). |
| **W, A, S, D** | Movimiento del avatar. |
| **Espacio / Ctrl** | Saltar en tierra / Nadar hacia arriba (**Espacio**) o hacia abajo (**Ctrl**) en líquidos profundos ($\ge 2$ bloques). |
| **Clic izquierdo** | Talar árboles, minar terreno/vetas (con barra de progreso e ícono de herramienta) o deconstruir si el modo **G** está activo. |
| **Clic derecho** | Colocar el bloque seleccionado en la hotbar (`1`–`0`) o surtir una obra fantasma apuntada (con ícono `modo_construir.svg`). |
| **1 – 9, 0** | Seleccionar tipo de bloque en la hotbar (`tierra`, `adobe`, `bloque_madera`, `bloque_piedra`, `estructura_hierro`, `vidrio`, `puerta`, `cama`, `baul`, `bloque_acero`). |
| **L** | **Encender / apagar lámpara omnidireccional** del avatar (`PanelLampara`). |
| **E** | Pulsar: abrir/cerrar puertas o abrir el baúl de un puesto activo (`VentanaBaul`). Mantener sobre árbol: recolectar frutos (`herr_cesta.svg`). |
| **G** | Alternar modo deconstrucción manual a pie (clic izq. desmonta paso a paso con ícono `modo_demoler.svg`; clic der. marca/desmarca para demolición). |
| **V** | Alternar modo interacción con vías a pie (clic izq. construye sección 2×2; clic der. demuele sección 2×2). |
| **B / Shift + B** | Declarar estructura terminada (**B**) / Iniciar remodelación (**Shift + B**, con diálogo de advertencia si hay riesgo de desahucio) apuntando a su puerta exterior. |
| **Esc** | Cerrar ventana de baúl/almacén/población, salir del modo vías/deconstrucción o liberar el cursor. |

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
| **Z / X** | Retroceder submenú o página (**Z**) / Avanzar página (**X**) en menús numéricos con más de 9 ítems (ej. categoría Industrial). |
| **Ctrl + Scroll** | Rotar previsualización de blueprint o plantilla de puesto en pasos de 90°. |
| **Clic izquierdo** | Fijar esquina de zona/vía/ducto, emplazar estructura o inspeccionar edificio/puesto/ducto en modo Ver. |
| **Doble clic izq.** | Confirmar trazado de vía, demolición de vía o canalización elevada. |
| **Clic derecho** | Cancelar tramo en curso / cancelar modo de colocación. |
| **Esc** | Volver al modo neutro **Ver** o cerrar paneles laterales abiertos. |

---

## Bloque 1: Exploración Inicial en 1ª Persona, Agua, Oxígeno y Lámpara Térmica

> **Condición de partida:** Recién iniciada la escena (`F5`), antes de fundar la ciudad. Se comprueban las físicas del avatar a pie, la recolección de frutos, la colocación de bloques (incluyendo la equivalencia `vidrio`/`tierra`), la interacción con ríos/lagos superficiales, el secado de líquidos con bloques sólidos y el modo térmico inicial de la lámpara. *(Nota: Las físicas sobre `crudo` se verifican en el **Bloque 6.7** tras extraer crudo del subsuelo).*

### 1.1 Movimiento, Tala, Minado, Recolección de Frutos (`E`) y Colocación de Bloques a Pie
- [ ] **Acción (Movimiento, Tala y Minado):** Desplazarse con **W, A, S, D** y saltar con **Espacio**. Apuntar a un árbol o al suelo manteniendo **Clic Izquierdo**, y colocar bloques de la hotbar (`1`–`0`) con **Clic Derecho**.
- [ ] **Resultado esperado:**
  - El resaltado verde (`CaraApuntada`) marca la cara del bloque bajo la mira.
  - Al talar o minar aparece la barra de progreso acompañada del ícono contextual de la herramienta (`herr_hacha.svg`, `herr_pico.svg` o `herr_pala.svg`) y los recursos extraídos se suman al almacén.
  - No permite colocar un bloque en las 2 celdas ocupadas por el cuerpo del propio avatar.
- [ ] **Acción (Recolección de Frutos con `E`):** Apuntar al tronco o follaje de un árbol frutal y mantener pulsada la tecla **`E`** durante 2 segundos.
- [ ] **Resultado esperado:**
  - Durante la acción, la barra de progreso muestra el ícono de la **cesta de recolección (`herr_cesta.svg`)**.
  - Al completarse, el HUD emite la notificación **`"Frutos recolectados: +60.0 Comida"`** y suma `60.0` unidades a la sub-categoría `Caza y frutos` del almacén de comida.
- [ ] **Acción (Equivalencia de Ventanas `vidrio` / `tierra` en Hotbar):** Seleccionar la ranura **`6` (`vidrio`)** en la hotbar.
- [ ] **Resultado esperado:**
  - El contador de disponibilidad de la ranura `6` refleja la suma de `vidrio` procesado más `floor(tierra / 3)` (`1 ventana = 1 vidrio` o, si se agota el vidrio, `3 unidades de tierra`).

### 1.2 Natación en Agua, Corrientes, Oxígeno y Drenado con Bloques Sólidos
- [ ] **Acción (Natación y Corriente):** Caminar hacia un río, cascada o lago con $\ge 2$ bloques de profundidad de `agua`.
- [ ] **Resultado esperado:**
  - En agua de 1 solo bloque de profundidad el avatar camina normal; al entrar en $\ge 2$ bloques de profundidad se activa la flotación suave de cámara y el nado vertical (**Espacio** sube, **Ctrl** baja).
  - En ríos y pies de cascada se percibe el empuje horizontal de la corriente sumado al movimiento del jugador.
- [ ] **Acción (Consumo de Oxígeno):** Sumergir la cabeza completa bajo el agua (`Ctrl`).
- [ ] **Resultado esperado:**
  - Aparece `PanelOxigeno` y la barra de burbujas de oxígeno se reduce progresivamente (10 s de autonomía) y se recupera el doble de rápido al sacar la cabeza a la superficie.
- [ ] **Acción (Drenado / Secado con Bloques Sólidos):** Apuntar a una celda inundada de `agua` con un bloque sólido seleccionado en la hotbar (ej. `tierra` o `bloque_piedra`) y hacer **Clic Derecho**.
- [ ] **Resultado esperado:**
  - El bloque sólido **sobrescribe y desaloja el líquido de inmediato**, dejando la celda seca y ocupada por el bloque sólido sin rechazar la colocación.

### 1.3 Lámpara Omnidireccional en Modo Térmico Inicial (`L`) y Apilamiento con Oxígeno
- [ ] **Acción:** En 1ª persona (sin Central Termoeléctrica construida todavía en el mapa), pulsar la tecla **`L`**.
- [ ] **Resultado esperado:**
  - Se enciende la luz omnidireccional del avatar.
  - Como la ciudad aún produce `0 kW`, `PanelLampara` se abre directamente en modo **`LÁMPARA TÉRMICA🟡`**.
  - Quema insumos del almacén central siguiendo la jerarquía configurada en `Player.gd`:
    1. **Combustible:** `10 h / unidad` (luz cálida clara, rango 14 m).
    2. **Carbón:** `6 h / unidad` (luz ámbar, rango 10 m).
    3. **Madera:** `5 h / unidad` (luz anaranjada tenue, rango 7 m).
  - El panel muestra `Tiempo restante: X h | Y Combustible` (descontando 1 unidad del almacén cada 10 horas de juego).
- [ ] **Acción (Ventana de Oxígeno Apilada):** Con la lámpara encendida y `PanelLampara` visible, sumergir la cabeza en el agua.
- [ ] **Resultado esperado:**
  - La ventana `PanelOxigeno` aparece **apilada verticalmente justo debajo** de `PanelLampara`, sin solaparse ni tapar la mira central.
- [ ] **Acción:** Pulsar **`L`** nuevamente para apagar la lámpara (el indicador pasa a `⚫` y el panel se oculta). *(El modo **`LÁMPARA ELÉCTRICA🟡`** con batería multicolor de 72 h se probará en el **Bloque 7.3**, una vez exista generación eléctrica en la ciudad).*

---

## Bloque 2: Fundación del Núcleo Urbano, Decretos Cívicos, Zonificación y Ciclo de Vida Residencial

> **Mecánicas y orden lógico:** El **primer edificio** declarado con `B` funda siempre el **Núcleo Urbano** (crea la Zona de Influencia, habilita los decretos cívicos de Impulso de Inmigración y Racionamiento Estricto, y guarda el primer blueprint, pero aún no aloja colonos). A continuación se pinta la **Zona Residencial (`2 -> 1`)**, se construye la **1ª Residencia habitable** (verificando los costos en previsualización, los íconos de camas/baúles/faltantes en `PanelEdificio` y el ícono `modo_construir` al surtir en 1ª persona), se prueba la advertencia de desahucio con `Shift + B` y la permanencia in-situ de colonos `"Sin techo"`, y luego se construye la **2ª Residencia** como buffer de reubicación.

### 2.1 Construcción a Mano de Casa de 2 Plantas, Ventanas sin Z-Fighting y Declaración del Núcleo Urbano (`B`)
- [ ] **Acción:** En 1ª persona, levantar manualmente con bloques de la hotbar una estructura cerrada de **2 pisos** (respetando el límite de Nivel 1: máx. 2 pisos y máx. 2 camas por piso):
  - **Planta baja (Nivel 0):** Muros cerrados, **1 puerta exterior** (`7`), al menos **1 ventana de vidrio** (`6`), **1 o 2 camas** (`8`) y **1 baúl** (`9`).
  - **Planta alta (Nivel 1):** Muros cerrados, techo, escalera interior transitable desde planta baja, ventanas y hasta 2 camas, **sin ninguna puerta exterior**.
- [ ] **Acción (Verificación Estética 3D y Ausencia de Z-Fighting en Ventanas):** Inspeccionar de cerca la puerta de madera y los bloques de ventana colocados:
  - Comprobar que la puerta de madera cuenta con relieve tridimensional visible: un **picaporte dorado** (`Color(0.85, 0.7, 0.2)`) y **dos bisagras metálicas oscuras** (`Color(0.15, 0.15, 0.15)`) en su marco lateral.
  - Mover la cámara frente y de costado a los bloques de ventana de vidrio (`mat_ventana.tres` con `cull_mode = 0`): comprobar que son **paneles transparentes delgados de $1/20$ de espesor ($0.05$ m)** sin caras laterales, superior ni inferior (`ventana` recta a media profundidad orientada hacia el avatar), que en las esquinas entre una ventana y otro bloque forman automáticamente un **panel en L (`ventana_esquina`)** rotado 90° en Y, y que al colocar una ventana mirando desde abajo hacia arriba o desde arriba hacia abajo se coloca un **panel horizontal de techo (`ventana_techo`)** alineado al ras con la cara superior del bloque ($Y \in [0.95, 1.0]$).
- [ ] **Acción:** Salir al exterior, apuntar a la puerta de planta baja y pulsar **`B`**.
- [ ] **Resultado esperado:**
  - La estructura se valida y declara con éxito (y si se construyó sobre o junto al agua, drena automáticamente cualquier bloque de líquido atrapado en el volumen de aire interior).
  - Notificación: **`"Núcleo urbano declarado."`**
  - El edificio queda registrado como **Núcleo Urbano** (duplica los topes base del almacén central y establece la **Zona de Influencia** alrededor de la sede).
  - Se guarda automáticamente el diseño en el catálogo de blueprints bajo el nombre **`Residencia [camas]x[baules]`**.

### 2.2 Excepción de Remodelación (`Shift + B`) y Controles Cívicos del Núcleo Urbano (`PanelEdificio`)
- [ ] **Acción (Remodelación libre del Núcleo):** Apuntar a la puerta del Núcleo Urbano recién declarado y pulsar **`Shift + B`** (o seleccionarlo en cenital y pulsar `[Iniciar remodelación]`):
  - Notificación: *"Remodelación iniciada para el núcleo urbano: ahora en edición libre."*
  - Volver a apuntar a su puerta y pulsar **`B`** para redeclarar el Núcleo Urbano.
- [ ] **Acción (Inspección del Núcleo Urbano en Cenital):** Pulsar **`C`** para pasar a la Cámara Cenital, asegurar modo Ver (**`Esc`**) y hacer clic izquierdo sobre el Núcleo Urbano para abrir `PanelEdificio`.
- [ ] **Resultado esperado:**
  - Muestra el ícono `ayuntamiento.svg`, el título `"Núcleo urbano"`, las filas con íconos vectoriales de **`cama.svg` (`Camas: X`)** y **`baul.svg` (`Baúles: Y`)**, y los dos botones de gestión cívica exclusivos de la sede:
    1. **`[Impulso inmigración (+250%)]`** (con ícono `censo.svg`).
    2. **`[Activar Decreto: Racionamiento Estricto (-35% comida, máx. 35% moral)]`** (con ícono `comida.svg`).
- [ ] **Acción (Probar Decreto de Racionamiento Estricto):** Hacer clic en **`[Activar Decreto: Racionamiento Estricto...]`**:
  - Comprobar que el texto del botón cambia a **`"Desactivar Decreto: Racionamiento Estricto (ACTIVO)"`** y que en la barra superior la moral ciudadana queda topada inmediatamente a un máximo de **`35.0%`** (mientras reduce el consumo de comida en un `-35%`).
  - Hacer clic nuevamente en el botón para **desactivar** el decreto antes de continuar con las pruebas de inmigración.

### 2.3 Zonificación Residencial (`2 -> 1`), Previsualización de Costos, Íconos en `PanelEdificio` y Surtido en 1ª Persona
- [ ] **Acción (Pintar Zona Residencial y Adaptación al Terreno):** En cenital, pulsar **`2`** (Zonificar) $\to$ **`1`** (Zona Residencial) y hacer dos clics izquierdos sobre terreno llano **dentro de la Zona de Influencia** para pintar un sector residencial.
- [ ] **Resultado esperado:**
  - Se dibuja el rectángulo de Zona Residencial (y si se modifica o nivela un bloque de terreno dentro de la zona, `ZonaOverlay` se reconstruye automáticamente adaptándose a la nueva altura). Al pulsar **`Esc`**, los rectángulos de colores se ocultan limpiamente.
- [ ] **Acción (Previsualización de Blueprint y Costos de Materiales):** En cenital, pulsar **`1`** (Construir) $\to$ **`1`** (Residencial) y seleccionar el blueprint **`1`** (`Residencia [camas]x[baules]`). Mover el cursor sobre la Zona Residencial sin hacer clic todavía.
- [ ] **Resultado esperado:**
  - El botón muestra la **miniatura isométrica 3D** generada en vivo.
  - Mientras se desplaza el cursor con la huella fantasma 3D, la tarjeta contextual (`PanelContextual`) **muestra en vivo la cantidad y tipo de recursos con sus íconos vectoriales** (`madera`, `piedra`, `vidrio`, `tierra`, etc.) que consumirá llevar a cabo la construcción (incluyendo nivelación).
  - Girar con **`Ctrl + Rueda del ratón`** rota la huella fantasma 3D en pasos de 90°.
- [ ] **Acción (Inspección del Blueprint Colocado en `PanelEdificio`):** Hacer clic izquierdo sobre la Zona Residencial para fijar el edificio fantasma. Pulsar **`Esc`** (modo Ver) y hacer clic izquierdo sobre el blueprint recién colocado.
- [ ] **Resultado esperado:**
  - `PanelEdificio` muestra:
    - La fila **`Camas: X`** precedida por su ícono vectorial **`cama.svg`**.
    - La fila **`Baúles: Y`** precedida por su ícono vectorial **`baul.svg`**.
    - El desglose vertical de **materiales faltantes**, donde cada recurso requerido aparece acompañado de su **ícono vectorial de 16 px** (`X Recurso (hay Y)`).
- [ ] **Acción (Ícono Contextual al Construir en 1ª Persona):** Pasar a 1ª persona (**`C`**), acercarse al edificio fantasma y mantener **Clic Derecho** apuntando a los bloques fantasma (y luego a cualquier pared exterior) hasta completar el 100% de la obra.
- [ ] **Resultado esperado:**
  - Mientras se mantiene presionado el clic derecho para construir, la barra de progreso central muestra a su izquierda el **ícono de Construcción (`modo_construir.svg`)**, **nunca** el ícono de la canasta de cosecha (`herr_cesta.svg`).

### 2.4 1ª Residencia Habitable: `Colonizable: SÍ`, Llegada de Colonos e Impulso de Inmigración (+250%)
- [ ] **Acción:** Pasar a cenital (**`C`**), asegurar modo Ver (**`Esc`**) y hacer clic izquierdo sobre la residencia recién terminada (no sobre el Núcleo Urbano).
- [ ] **Resultado esperado:**
  - `PanelEdificio` indica: **`Colonizable: SÍ (inmigración activa)`** y muestra el botón **`[Pausar colonización]`** (`puerta_candado.svg`).
- [ ] **Acción (Activar Impulso de Inmigración +250%):** Seleccionar el **Núcleo Urbano** (o abrir `VentanaMoral` desde la barra superior) y pulsar el botón **`[Impulso inmigración (+250%)]`**.
- [ ] **Resultado esperado:**
  - Notificación: **`"¡Impulso de inmigración activado en el núcleo urbano por 30 días!"`**
  - El botón pasa a estado deshabilitado indicando **`"Impulso activo (30 d restantes)"`**.
  - La tasa mensual de inmigración vigente se multiplica por **`2.5x` (+250%)** durante 30 días (720 horas de juego) y **elimina la limitación de disponibilidad de camas**, acelerando la llegada de colonos (`desempleado`) para dinamizar la partida.

### 2.5 Remodelación de Única Residencia Poblada (`Shift + B`): Advertencia de Desahucio y Colonos "Sin Techo" In-Situ
- [ ] **Condición:** Esperar a que la 1ª Residencia habitable tenga colonos residiendo en ella (cuando todavía **no existe ninguna otra casa** con camas libres en la colonia).
- [ ] **Acción (Advertencia de Desahucio con `Shift + B` en 1ª Persona):** Pasar a 1ª persona (**`C`**), apuntar a la puerta exterior de esa residencia habitada y pulsar **`Shift + B`**.
- [ ] **Resultado esperado:**
  - Como hay riesgo de desahucio (`calcular_sin_techo_al_remodelar(id) > 0`), **NO inicia la remodelación a ciegas**: se libera el cursor del ratón y se abre centrada la ventana modal **`"Confirmar remodelación"`** detallando los residentes actuales, cuántos serán reubicados y advirtiendo cuántos colonos **quedarán sin techo**.
  - Si se pulsa **`[Cancelar]`**, el diálogo se cierra y el cursor vuelve a capturarse inmediatamente para seguir jugando en 1ª persona.
- [ ] **Acción (Confirmar Remodelación y Verificar Permanencia In-Situ):** Volver a pulsar **`Shift + B`** (o pulsar `[Iniciar remodelación]` desde `PanelEdificio` en cenital) y hacer clic en **`[Confirmar]`**.
- [ ] **Resultado esperado:**
  - El edificio pasa a edición libre y los habitantes desalojados pasan al estado **`"Sin techo: X"`** en la ventana **Población**.
  - **Verificación crítica de reconciliación (`Colonos.gd`):** Los colonos que quedan sin techo **permanecen físicamente en su ubicación actual dentro de la ciudad** (`hogar = -1`); **NO desaparecen ni reaparecen caminando desde el borde del mapa** ni disparan notificaciones falsas de *"¡Ha llegado un nuevo colono!"*.
  - Mientras están sin techo, consumen comida a tasa de desempleado (`3.0 u/h`), no trabajan en obras ni puestos y penalizan la moral en `-0.05/día` por colono.
- [ ] **Acción (Reabsorción inmediata):** En 1ª persona, apuntar a la puerta de la casa y pulsar **`B`** para volver a declararla.
- [ ] **Resultado esperado:**
  - Los colonos `"Sin techo"` son **reabsorbidos al instante** en las camas recién declaradas (`Sin techo: 0`) y recuperan su actividad normal.

### 2.6 2ª Residencia en adelante: Buffer de 24 h (`Colonizable: NO`), Obra por Colonos y Reubicación
- [ ] **Acción:** En cenital (`1 -> 1`), emplazar una **2ª Residencia** sobre la Zona Residencial.
- [ ] **Resultado esperado (Construcción autónoma por colonos):**
  - Como ahora ya hay colonos desempleados/obreros en la ciudad, **los colonos acuden automáticamente a la obra fantasma** y la construyen bloque a bloque hasta terminarla sin intervención del jugador.
- [ ] **Acción:** Una vez terminada la 2ª Residencia, seleccionarla en modo Ver (`Esc`).
- [ ] **Resultado esperado (Buffer habitacional):**
  - Nace con estado **`Colonizable: NO (apertura en 24 h)`** y botón **`[Permitir colonización]`** (`puerta_reloj.svg`).
  - Sus camas están protegidas como buffer para reubicaciones internas. Pulsar **`[Permitir colonización]`** cambia a `Colonizable: SÍ`; pulsar **`[Pausar colonización]`** lo devuelve a `Colonizable: NO (buffer protegido)`. Dejarlo en `NO` con camas libres.
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

## Bloque 3: Infraestructura Vial, Prioridades de Obra con Flechas y Tráfico

> **Condición previa:** La colonia ya cuenta con el Núcleo Urbano, varias residencias y colonos obreros libres para ejecutar obras viales, demoliciones y construcciones con distintas prioridades.

### 3.1 Trazador Cenital de Vías e Iconografía SVG (`1` -> `5` -> `1`)
- [ ] **Acción:** En cenital (**`C`**), pulsar **`1`** (Construir) $\to$ **`5`** (Vías) $\to$ **`1`** (Trazar vía).
- [ ] **Resultado esperado:**
  - La tarjeta contextual muestra iconos vectoriales SVG (`FIJAR PUNTO`, `CONFIRMAR`, `CANCELAR`, `SALIR`) y ficha técnica con `Velocidad: +35%` y costos de piedra/tierra calculados en vivo.
- [ ] **Cancelación limpia:** Hacer un clic izquierdo en el suelo, desplazar el cursor para previsualizar un tramo y pulsar **Clic Derecho**: el tramo en curso se cancela al instante sin dejar baldosas fantasma.

### 3.2 Nivelación Compartida entre Puertas Enfrentadas
- [ ] **Acción:** Emplazar un edificio frente a otro con sus puertas enfrentadas a 2–3 celdas de distancia en terreno con desnivel, o trazar una calle entre ambas fachadas.
- [ ] **Resultado esperado:**
  - El terreno entre las puertas enfrentadas se nivela a una misma cota compartida, evitando escalones bruscos que bloqueen el acceso.

### 3.3 Tendido Progresivo de Vías por Colonos (`ViaObraOverlay`) y Fusión de Tramos
- [ ] **Acción:** Trazar una vía de varias celdas y confirmar con **doble clic izquierdo**.
- [ ] **Resultado esperado:**
  - Aparece el **contorno perimetral amarillo** en el suelo (`ViaObraOverlay`).
  - Hasta **4 obreros libres** acuden a la obra vial y construyen de forma **consecutiva de un extremo al otro**. A medida que cada celda se completa, el contorno amarillo se retira progresivamente.
- [ ] **Fusión de tramos:** Mientras la obra vial sigue en construcción, trazar y confirmar un nuevo tramo contiguo: se fusiona automáticamente en la misma obra activa bajo la misma cuadrilla de hasta 4 obreros.

### 3.4 Intervención Manual de Vías a Pie en 1ª Persona (Tecla `V`)
- [ ] **Acción:** Trazar otra vía en cenital, pasar a 1ª persona (**`C`**) y pulsar **`V`** para activar el modo vías a pie.
- [ ] **Construir sección 2×2 (Clic Izquierdo):** Apuntar a una sección pendiente (con alambre amarillo) y hacer clic izquierdo $\to$ completa de golpe la **sección 2×2 entera** sin notificaciones repetitivas.
- [ ] **Demoler sección 2×2 (Clic Derecho):** Apuntar a un tramo de vía ya construido y hacer clic derecho $\to$ retira al instante la sección 2×2 completa junto con sus cuñas. Pulsar **`V`** o **`Esc`** para salir.

### 3.5 Herramienta Unificada de Demolición Cenital (Tecla `3`)
- [ ] **Demolición de Edificios:** En cenital, pulsar **`3`** (Demoler) y hacer clic izquierdo sobre un edificio secundario: alterna su marca roja de demolición para que los colonos lo desmonten (y si el edificio estaba en contacto con el agua, al vaciarse sus celdas el agua vecina vuelve a escurrir naturalmente).
- [ ] **Demolición Guiada de Vías en Esquinas de 90°:** Trazar y completar una vía en forma de "L". Activar el modo **`3`**, hacer clic izquierdo en un extremo de la vía y mover el cursor hasta el otro extremo pasando por la esquina:
  - La previsualización **naranja translúcida** (`ViaDemolicionOverlay`) sigue la red vial mediante Dijkstra cubriendo **todo el ancho de 2 canales (sección 2×2)** en la esquina exterior sin recortar en diagonal.
- [ ] **Confirmación y Outline Naranja Persistente:** Hacer **doble clic izquierdo** para confirmar la demolición del tramo $\to$ queda marcado con un **outline naranja persistente** que se va retirando sección a sección a medida que los colonos lo demuelen.

### 3.6 Prioridades de Obra con Botones `▲` / `▼` (`PanelEdificio`) y Apertura Automática de `PanelPuesto`
- [ ] **Acción:** En cenital, iniciar una obra de edificio o puesto, marcar otro para demolición y dejar un tramo de vía en obra. Seleccionar el edificio en construcción en modo Ver (`Esc`).
- [ ] **Resultado esperado:**
  - En `PanelEdificio` aparece la fila de prioridad compuesta por el ícono (`prio_alta.svg`, `prio_normal.svg` o `prio_baja.svg`), la etiqueta **`Prioridad: Normal`** y dos botones de flecha compactos (`24x24`): **`btn_subir.svg` (`▲`, aumentar prioridad)** y **`btn_bajar.svg` (`▼`, reducir prioridad)**.
  - Pulsar **`▲`** sube de `Baja` $\to$ `Normal` $\to$ `Alta` (deshabilitando `▲` al llegar a `Alta`); pulsar **`▼`** baja de `Alta` $\to$ `Normal` $\to$ `Baja` (deshabilitando `▼` al llegar a `Baja`).
  - Los colonos libres se despachan respetando estrictamente la jerarquía global: *1. Construcción Alta $\to$ 2. Construcción Normal $\to$ 3. Demoliciones $\to$ 4. Tendido de Vías $\to$ 5. Construcción Baja*.
  - **Transición automática al terminar un puesto:** Si se mantiene abierto el `PanelEdificio` de un puesto en construcción cuando su progreso alcanza el 100%, `PanelEdificio` se cierra solo y abre automáticamente el `PanelPuesto` del nuevo edificio.

---

## Bloque 4: Supervisión Cívica, Almacén Jerárquico, Moral Dinámica y Puestos Periféricos

> **Condición previa:** Con la ciudad fundada y las vías trazadas, se auditan la barra superior (con el panel hover de IDU), la ventana de Almacén con desplegables jerárquicos (sub-almacén de comida y derivados refinados), la ventana de Moral (variedad dietética, monocultivo y suelo agrario del 75%) y los primeros **Puestos Periféricos de Nivel 1** (con lista de producción en scroll fijo y botones `▲`/`▼`).

### 4.1 Barra Superior (Hover IDU), Almacén con Desplegables (`▶`/`▼`), Población y Ocupaciones
- [ ] **Barra Superior (`BarraSuperior.gd`):**
  - Verificar los contadores de **Comida**, **Energía** (en formato `kW` o `MW`), **Recurso Crítico**, **Población** y **Moral** (con barra sombreada de progreso).
  - En el extremo derecho, verificar que se muestra el ícono **`era.svg`** junto al título **`Asentamiento Pionero`** y, a su derecha, la insignia romana **`I` (`romano_1.svg`)**.
  - **Panel Hover de Nivel (IDU):** Pasar el cursor del ratón sobre la insignia romana **`I`**: comprobar que se despliega en la esquina superior derecha un panel flotante (`_panel_hover_idu`) mostrando:
    - `Nivel I (IDU: X.XX)`
    - `- Sofisticación (S): X.XX`
    - `- Cualificación (Q): X.XX`
    - `- Ciencia (K): X.XX`
- [ ] **Ventana de Almacén Jerárquica (`VentanaAlmacen.gd`):** Hacer clic en el botón **Almacén** de la barra superior:
  - Verifica que lista los recursos base ordenados alfabéticamente de la **A a la Z** (`Agua`, `Carbón`, `Cobre`, `Comida`, `Crudo`, `Hierro`, `Madera`, `Piedra`, `Tierra`, `Tierras raras`).
  - **Desplegable Interactivo de Fuentes de Comida (`▶ Comida`):** Hacer clic sobre la fila **`▶ Comida`**:
    - Cambia a **`▼ Comida`** y despliega las **6 sub-categorías del sub-almacén alimentario** en su orden exacto de consumo por perecibilidad:
      1. `Pescado y mariscos: X`
      2. `Caza y frutos: Y`
      3. `Cereales y cultivos: 0`
      4. `Carne y lácteos: 0`
      5. `Raciones hidropónicas: 0`
      6. `Alimento sintético: 0`
    - Comprobar que con cada tick horario el consumo metabólico de la población se descuenta primero de `Pescado y mariscos` (la fuente más fresca) y, solo cuando esta se agota, empieza a descontar de `Caza y frutos`.
  - **Desplegables de Recursos Refinados y Botón «Expandir todo / Contraer todo»:** Hacer clic sobre **`▶ Crudo`**, **`▶ Hierro`**, **`▶ Madera`**, **`▶ Piedra`**, **`▶ Tierra`** y **`▶ Tierras raras`**:
    - Comprobar que cada uno despliega con sangría su producto refinado hijo con su propio ícono de 20 px, stock, límite y tasa horaria: `Combustible`, `Acero`, `Tablas` y `Carbón`, `Bloques de piedra`, **`Vidrio`** y `Mineral refinado`.
    - En el encabezado superior de la ventana (entre el título **`ALMACÉN`** y el botón **`X`**), pulsar el botón **`[Expandir todo]`**: comprobar que todos los desplegables se abren simultáneamente y el texto del botón cambia a **`[Contraer todo]`** (y al pulsarlo de nuevo, contrae todos los desplegables).
- [ ] **Ventana de Población y Ocupaciones:** Hacer clic en **Población**:
  - Muestra la fila unificada: **`Obreros: Total · X empleados · Y desempleados`** (más Técnicos, Especialistas, Investigadores, Militares y Sin techo si aplica).
  - Pulsar **Ocupaciones**: muestra las 4 categorías colapsables (`▼ Recolección`, `▼ Industria`, `▼ Investigación`, `▼ Energía`).

### 4.2 Sistema Dinámico de Moral Ciudadana (`VentanaMoral` — Solo Clic en Topbar y Cierre con `X`)
- [ ] **Acción (Apertura Centrada y Bloqueo de Teclado):** Hacer clic izquierdo en el botón de **Moral** de la barra superior.
- [ ] **Resultado esperado:**
  - Se abre **`VentanaMoral`** (`380x440`) **perfectamente centrada en la pantalla**.
  - Pulsar las teclas **`M`** y **`Esc`**: comprobar que **la ventana NO se cierra con el teclado** (solo se cierra al hacer clic en su botón **`X`** de la esquina superior derecha).
- [ ] **Acción (Ocultación Automática al Pasar a 1ª Persona):** Con `VentanaMoral` abierta en vista cenital, pulsar **`C`** para bajar a la vista de 1ª persona.
- [ ] **Resultado esperado:**
  - `VentanaMoral` **se oculta automáticamente** al entrar en 1ª persona para no estorbar la visión del avatar, y **vuelve a mostrarse automáticamente** al pulsar **`C`** para regresar a la vista cenital.
- [ ] **Verificación de Indicadores, Impulso y Factores en `VentanaMoral`:**
  - Muestra el **Estado Anímico Actual** (`😡` $\le$20%, `🙁` 20–35%, `😐` 35–65%, `🙂` >65%), la **Tendencia Diaria** (`%+.2f / día`), el **Multiplicador de Productividad Laboral** ($X = 0.5 \times 2^{(Y/50)}$, mientras que los puestos de alimentos tienen un **suelo mínimo garantizado de `0.75x` [75%]** incluso con moral crítica) y el **Flujo Migratorio** (`Éxodo de cerebros` $\le$20%, `Inmigración con camas` 20–50%, `Inmigración masiva` >50%).
  - Incluye la sección de **Impulso de Inmigración (+250%)** con su propio botón de activación sincronizado con el Núcleo Urbano.
  - En el desglose de factores (`/día`), comprobar que la fila **`Variedad de alimentos (X/6 grupos)`** reconoce las fuentes activas en reserva/producción (ej. `2/6 grupos: +7.20/día` al contar con pesca y caza/frutos; si la colonia permanece más de **360 horas [15 días]** con **1 sola fuente**, aplica la penalización de monocultivo `Variedad (Monocultivo crítico): -4.80/día`).

### 4.3 Puestos Periféricos de Recolección (`1 -> 2 -> 1..4`): Botones `▲`/`▼` y Lista de Producción con Scroll
- [ ] **Regla de exclusión de Zona de Influencia:** En cenital, pulsar **`1`** (Construir) $\to$ **`2`** (Periférico) y elegir **Caza (`1`)**, **Madera (`2`)**, **Mina (`3`)** o **Pesca (`4`)**.
  - Dentro de la Zona de Influencia la huella es **roja (inválida)**; fuera de la Zona de Influencia es **dorada (válida)** con su halo circular azul de radio de acción.
- [ ] **Construcción y Verificación de `PanelPuesto`:** Emplazar un puesto de **Caza (`1-2-1`)**, un **Maderero (`1-2-2`)** y una **Mina (`1-2-3`)** fuera de la zona de influencia y dejar que los colonos completen las obras. Hacer clic izquierdo sobre la **Mina** terminada en modo Ver (`Esc`):
  - **Encabezado e Insignia Romana:** Muestra `"Mina"` junto al ícono `mina.svg` y la insignia de nivel `romano_1.svg`.
  - **Botones de Asignación `▲` / `▼` Siempre Visibles:**
    - En cada fila de personal (`Obreros`, `Técnicos`, `Especialistas`, `Acarreadores`), comprobar que los botones compactos (`24x24`) muestran nítidamente los íconos **`btn_subir.svg` (`▲`, contratar)** y **`btn_bajar.svg` (`▼`, despedir)** tanto cuando están habilitados como cuando están deshabilitados (con borde y tinte atenuado, sin desaparecer nunca el símbolo).
  - **Lista Vertical de Producción con Scroll Fijo (`_scroll_prod`):**
    - Contratar **Obreros (`▲`)** y **Acarreadores (`▲`)** en la Mina y esperar a que lleguen al puesto (`presentes > 0`).
    - Comprobar que la sección **`Producción:`** muestra una **lista vertical con un único recurso por fila** (ícono vectorial de 16 px + `"%.1f Recurso/h"`), contenida dentro de un **área con scroll vertical de altura fija (`72 px`, equivalente a 3 filas visibles)**.
    - Si la mina extrae más de 3 recursos simultáneos (ej. `Tierra`, `Piedra`, `Carbón`, `Hierro`, `Cobre`), mover la rueda del ratón sobre la lista de producción para hacer **scroll vertical** y ver el resto de minerales, comprobando que la ventana `PanelPuesto` mantiene siempre un tamaño constante.
  - Contratar personal también en el puesto de **Caza** y en el **Maderero**: comprobar que los recolectores extraen recursos reales y los acarreadores los llevan al almacén central (y que la comida entregada por Caza ingresa a la sub-categoría `Caza y frutos` en `VentanaAlmacen`).

### 4.4 Preferencia de Vías en el Pathfinding (`BuscadorRutas`) y Prioridad de Tráfico
- [ ] **Acción:** Trazar una **vía de tierra pisada (`1 -> 5 -> 1`)** que conecte el Núcleo Urbano con las inmediaciones de la Mina o Maderero periférico.
- [ ] **Resultado esperado:**
  - Los acarreadores y trabajadores **prefieren desplazarse por la vía de tierra pisada** (`coste_ruta = 3`, bono `+35%` de velocidad) en vez de cortar por terreno natural (`COSTE_TERRENO_NATURAL = 8`).
  - En un paso estrecho de 1 celda, el colono que transporta carga prioritaria mantiene su ruta y el colono descargado o de menor prioridad se aparta a una celda lateral.

### 4.5 Interacción en 1ª Persona con el Baúl de un Puesto (`VentanaBaul` — Tecla `E`)
- [ ] **Acción:** Cambiar a 1ª persona (**`C`**), caminar hasta la Mina o Maderero, abrir su puerta con **`E`**, apuntar la mira al **baúl interior** y pulsar **`E`**.
- [ ] **Resultado esperado:**
  - Se abre **`VentanaBaul`** centrada en pantalla (`320x260`) con barra de scroll vertical.
  - Cada recurso muestra su ícono de 20 px, nombre alineado, cantidad local y los botones compactos **`btn_subir.svg` (`▲`, ingresar al baúl)** y **`btn_bajar.svg` (`▼`, retirar del baúl)**, además del botón **`"Extraer todo"`**.
- [ ] **Cierre rápido:** Pulsar nuevamente **`E`** (o **`Esc`**) $\to$ la ventana se cierra de inmediato y el control de cámara en 1ª persona se restaura al instante.

---

## Bloque 5: Cadena Educativa, Industria (con Vidriera), Evolución de Eras (IDU), Investigación en 2 Capas y Logística de Transporte

> **Orden estricto de desbloqueo en código (`CamaraCenital.gd`, `Ciudad.gd` y `Economia.gd`):**
> 1. Todas las refinerías (`Siderúrgica`, `Tierras raras`, `Aserradero`, `Fábrica de bloques`, `Vidriera`, `Carbonera`) exigen **Técnicos** $\to$ primero construimos la **Escuela Técnica (`1-4-1`)** y graduamos Técnicos.
> 2. Construimos las refinerías de Nivel 1 (incluyendo la **Fábrica de Bloques** y la nueva **Vidriera**) y probamos el control de **Reserva Central porcentual (`0%..50%`)**.
> 3. Construimos la **Escuela de Especialistas (`1-4-2`)**, graduamos Especialistas y levantamos la **Universidad (`1-4-3`)** (que **no exige electricidad** para construirse ni para funcionar en investigaciones básicas).
> 4. Con las refinerías y el personal cualificado activos, el **IDU supera `1.50`** y la colonia evoluciona orgánicamente a la **Era 2 (`Manufactura Temprana`)**, habilitando las **Ciencias Básicas Teóricas (Capa 1)** en la Universidad, las **Mejoras Prácticas In-Situ con Investigadores Itinerantes (Capa 2)** y el **Taller de Transporte Evolutivo (`1-3-X-1`)**.

### 5.1 Escuela Técnica (`1 -> 4 -> 1`), Graduación de Técnicos y Niveles de Puesto
- [ ] **Acción:** En cenital, pulsar **`1` (Construir) -> `4` (Investigación) -> `1` (Escuela técnica)** y colocarla sobre **Zona Residencial** dentro de la Zona de Influencia.
- [ ] **Acción:** Una vez construida, abrir su `PanelPuesto` y contratar el cupo completo de **4 Aprendices** (`▲`).
- [ ] **Resultado esperado:**
  - Con los 4 aprendices presentes en sus mesas de estudio, tras **24 horas** la cohorte se gradúa convirtiendo a los 4 obreros en **3 Técnicos libres** (notificación: `"¡Se han formado 3 nuevos técnicos!"`).
  - Graduar una segunda cohorte de Técnicos para disponer de personal suficiente para las refinerías y la Escuela de Especialistas.
- [ ] **Prueba de ascenso y retroceso de nivel en Mina:**
  - En la Mina periférica, despedir a los obreros (`▼`) y contratar **1 Técnico (`▲`)**: el puesto sube a **Nivel 2** (`romano_2.svg`, profundidad 16 y multiplicador $\times 1.5$).
  - Contratar además **1 Obrero (`▲`)**: el puesto retrocede limpiamente a **Nivel 1** (`romano_1.svg`) según el rango mínimo de sus trabajadores.

### 5.2 Zonificación Industrial (`2 -> 2`), Fábrica de Bloques (`1 -> 3 -> 4`), Nueva Vidriera (`1 -> 3 -> 5`) y Siderúrgica (`1 -> 3 -> 1`)
- [ ] **Acción (Pintar Zona Industrial):** En cenital, pulsar **`2` (Zonificar) -> `2` (Zona Industrial)** y pintar un sector industrial amplio **dentro de la Zona de Influencia**. Salir con `Esc`.
- [ ] **Acción (Explorar Submenú Industrial de 11 Edificios):** Pulsar **`1` (Construir) -> `3` (Industrial)**:
  - Comprobar que la **Página 1** lista los primeros 9 edificios:
    `1: Siderúrgica`, `2: Tierras raras`, `3: Aserradero`, `4: Fábrica de bloques`, **`5: Vidriera`**, `6: Carbonera`, `7: Refinería petrolera`, `8: Productor combustible`, `9: Central termoeléctrica`.
  - Pulsar **`X`** para avanzar a la **Página 2**: comprobar que lista `0: Almacén` y `1: Taller de transporte`. Pulsar **`Z`** para volver a la Página 1.
- [ ] **Acción (Construir Fábrica de Bloques, Vidriera, Siderúrgica y Aserradero):**
  - Emplazar sobre la Zona Industrial una **Siderúrgica (`1 -> 3 -> 1`)**, un **Aserradero (`1 -> 3 -> 3`)**, una **Fábrica de bloques (`1 -> 3 -> 4`)** y una **Vidriera (`1 -> 3 -> 5`)**.
- [ ] **Resultado esperado en la Fábrica de Bloques (`1 -> 3 -> 4`):**
  - Huella de 5×6 en `bloque_piedra` con chimenea activa (`HumoRefinerias`). Al contratar **Técnicos (`▲`)** y **Acarreadores (`▲`)**, convierte cada **`1 Piedra` en `3 Bloques de piedra`**.
  - Al construir obras que demanden piedra, `Ciudad.gd` **descuenta primero los `bloques_piedra` procesados** antes de gastar `piedra` cruda.
- [ ] **Resultado esperado en la Nueva Vidriera (`1 -> 3 -> 5`):**
  - Huella de 5×6 de `adobe` con ventanas de vidrio y chimenea en el techo (`Vector2i(2, 3)`).
  - En su `PanelPuesto`, contratar **Técnicos (`▲`)** y **Acarreadores (`▲`)**: convierte cada lote de **`1 Tierra + 1 Carbón` en `3 unidades de Vidrio`** (`vidrio.svg`).
  - Comprobar en `VentanaAlmacen` (desplegando **`▶ Tierra`**) que el stock de **`Vidrio`** se incrementa y que, al colocar ventanas de vidrio, se consume primero el `Vidrio` procesado antes de recurrir a `3 de Tierra`.

### 5.3 Control de Reserva Central Porcentual en Refinerías (`0% / 10% / 20% / 35% / 50%`)
- [ ] **Acción:** En modo Ver (`Esc`), abrir el `PanelPuesto` de la **Fábrica de bloques**, **Vidriera**, **Siderúrgica** o **Aserradero**.
- [ ] **Resultado esperado:**
  - Debajo de la lista de producción con scroll aparece la fila **`Reserva central:`** mostrando el porcentaje y su equivalencia en unidades del almacén central (por defecto **`Sin reserva (0% / 0 u)`**) junto a los botones compactos **`btn_subir.svg` (`▲`)** y **`btn_bajar.svg` (`▼`)**.
- [ ] **Acción (Subir y bajar umbrales):** Pulsar sucesivamente **`▲`** y luego **`▼`**.
- [ ] **Resultado esperado:**
  - El umbral sube en orden: `Sin reserva (0% / 0 u)` $\to$ `10% (X u)` $\to$ `20% (X u)` $\to$ `35% (X u)` $\to$ `50% (X u)` (deshabilitando `▲` en `50%` y `▼` en `0%`).
  - Cuando el stock del almacén central está en o por debajo de la reserva configurada, los acarreadores de la refinería detienen la retirada de materia prima para proteger las reservas de construcción de la ciudad.

### 5.4 Escuela de Especialistas (`1 -> 4 -> 2`) y Graduación de Especialistas
- [ ] **Acción:** En cenital, pulsar **`1` (Construir) -> `4` (Investigación) -> `2` (Escuela de especialistas)** y colocarla sobre **Zona Residencial** dentro de la Zona de Influencia.
- [ ] **Acción:** Una vez terminada la obra, abrir su `PanelPuesto` y contratar el cupo de **3 Técnicos en formación** (`▲`, toma 3 Técnicos libres).
- [ ] **Resultado esperado:**
  - Con los 3 técnicos aprendices presentes, tras **48 horas** de estudio se gradúa la cohorte convirtiéndose en **2 Especialistas libres** (3 técnicos = 2 especialistas = 1 cama).

### 5.5 Universidad (`1 -> 4 -> 3`), Investigación de "Metalurgia Aplicada" y Evolución Orgánica a Era 2 (IDU)
- [ ] **Verificación de Ausencia de Requisito Eléctrico en Universidad:**
  - En cenital, abrir `1` (Construir) $\to$ `4` (Investigación) y observar el botón **`3` (Universidad)**: comprobar que **NO muestra el ícono de rayo dorado en el centro superior** (la Universidad no requiere electricidad para construirse ni para funcionar en investigaciones de Nivel 2).
  - Emplazar la **Universidad (`1 -> 4 -> 3`)** sobre **Zona Residencial** dentro de la Zona de Influencia y esperar a que se complete.
- [ ] **Acción (Contratar Investigadores y Verificar Evolución a Era 2 por IDU):**
  - Abrir el `PanelPuesto` de la Universidad: comprobar que la línea de `Energía:` está **oculta** (no demanda electricidad mientras no se investigue *Automatización Industrial*).
  - Pulsar **`▲`** en la fila **Investigadores** para contratar a los **Especialistas libres** (graduados en 5.4).
  - **Comprobar en la Barra Superior (extremo derecho):** Con las refinerías de Tipo 2 construidas ($S$) y los Técnicos/Especialistas/Investigadores en el censo ($Q$), el **Índice de Desarrollo Urbano (IDU)** alcanza o supera **`1.50`**:
    - El título de la Era cambia automáticamente de `Asentamiento Pionero` a **`Manufactura Temprana` (Era 2)** y la insignia romana sube a **`II` (`romano_2.svg`)**.
    - Pasar el cursor sobre la insignia **`II`** para verificar el desglose actualizado de `S`, `Q` y `K` en el panel hover.
- [ ] **Acción (Diálogo de Investigación con Íconos, Barra de Progreso y Pausa/Cancelación):**
  - Si `Metalurgia Aplicada` aún aparece disponible en `"Investigaciones disponibles:"`, hacer clic en **`[Investigar: Metalurgia Aplicada]`**:
    - Verificar que el diálogo modal **`Confirmar investigación`** muestra los **íconos vectoriales de `hierro.svg` (`300 hierro`), `madera.svg` (`200 madera`) y el reloj de arena `reloj_arena.svg` (`Tiempo estimado: X horas`)**. Confirmar.
    - En `PanelPuesto`, verificar que se muestra la **barra de progreso porcentual (`ProgressBar`)** y los botones con sus **íconos vectoriales**: **`[Pausar]` (`btn_pausa.svg`)** y **`[Cancelar]` (`cruz.svg`)**.
    - Pulsar **`[Pausar]`**: el estado indica `(Pausado)` y el botón cambia a **`[Reanudar]`** con el ícono **`btn_play.svg`**. Pulsar **`[Reanudar]`** y dejar que se complete (o comprobar que al avanzar a Era 2 `Metalurgia Aplicada` queda desbloqueada, habilitando la Refinería petrolera, el Productor de combustible y la Central termoeléctrica).

### 5.6 Investigación en Dos Capas: Ciencias Básicas Teóricas (Capa 1), Mejoras Prácticas In-Situ con Investigadores Itinerantes (Capa 2) y Balanza Doctrinal
- [ ] **Capa 1 — Ciencias Básicas Teóricas en la Universidad (`PanelPuesto`):**
  - En el `PanelPuesto` de la Universidad (con al menos 1 Investigador presente y la ciudad en **Era 2**), localizar la sección **`"Ciencias Básicas Teóricas (Capa 1):"`**.
  - Comprobar que las ciencias de Era 2 están habilitadas como botones (`Investigar: Metalurgia de Hornos (100 pts)`, `Investigar: Hidráulica de Canales (120 pts)`, `Investigar: Tracción Animal y Engranajes (150 pts)`), mientras que las de Era 3 y Era 4 aparecen con candado (`🔒 Requiere Era 3` / `Era 4`).
  - Hacer clic en **`[Investigar: Metalurgia de Hornos (100 pts)]`**:
    - Aparece la etiqueta `🔬 Metalurgia de Hornos: X / 100 pts (X%)` y su barra de progreso horizontal.
    - Con cada tick horario, los investigadores presentes en la Universidad generan puntos de ciencia (`investigadores * 1.0 * mult_productividad`) hasta llegar a `100 / 100 pts`, descontando el costo de laboratorio (`50 hierro, 50 madera`) y marcando **`✅ Metalurgia de Hornos (Completada)`**.
- [ ] **Capa 2 — Mejoras Prácticas In-Situ e Investigador Itinerante (`PanelPuesto`):**
  - Una vez completada `Metalurgia de Hornos`, seleccionar la **Siderúrgica** en modo Ver (`Esc`) para abrir su `PanelPuesto`.
  - En la sección **`"Mejoras Prácticas (Capa 2):"`**, comprobar que ahora aparece habilitado el botón **`[Instalar: Inyección Forzada (Dieselpunk)]`**. Hacer clic sobre él.
- [ ] **Resultado esperado (Despacho de Comisión Científica Itinerante y Balanza Doctrinal):**
  - Se descuentan `100 hierro, 50 madera` del almacén central y el estado en la Siderúrgica pasa a **`⚙ Mejora: Inyección Forzada | Estado: Esperando personal científico (0/1)`**.
  - Observar la Universidad: **1 Investigador sale físicamente de la Universidad** como `investigador_itinerante` y se desplaza caminando por la red vial hasta la puerta de la Siderúrgica.
  - En cuanto el investigador llega a la Siderúrgica, el estado cambia a **`En ejecución (1/1)`** y la barra de progreso avanza durante `20 h`.
  - Al completarse:
    - La Siderúrgica muestra **`✅ Inyección Forzada (Dieselpunk)`** coloreado con el tono ámbar/cobre de la doctrina Dieselpunk, y el investigador regresa caminando a la Universidad.
    - Pasar el cursor sobre la insignia romana **`II`** en la barra superior: el panel hover muestra ahora la **Balanza Doctrinal activa**: **`Doctrina: Dieselpunk (D: 100%, C: 0%, S: 0%)`**.

### 5.7 Taller de Transporte Evolutivo (`1 -> 3 -> X -> 1`), Parque Móvil y Selector de Transporte en Puestos
- [ ] **Construcción del Taller de Transporte (`1 -> 3 -> X -> 1`):**
  - En cenital (estando ya en **Era 2**), pulsar **`1` (Construir) -> `3` (Industrial) -> `X` (Página 2) -> `1` (Taller de transporte)** y colocar su huella de 5×5 sobre **Zona Industrial** dentro de la Zona de Influencia.
- [ ] **Ensamblaje de Vehículos en el Taller Evolutivo:**
  - Una vez terminada la obra, abrir su `PanelPuesto` y contratar **Obreros (`▲`)** (que actúan como mecánicos de ensamblaje).
  - Verificar en la sección del taller su denominación evolutiva actual (**`Taller de Carretas`** en Era 2 base; si se investiga `Tracción Animal y Engranajes` en la Universidad evoluciona automáticamente a **`Establo de Transporte`**, y en Era 3+ a **`Taller de Maquinaria y Transporte`**).
  - Hacer clic en **`[Fabricar: Carreta de Mano (15s) — 40 Madera, 10 Hierro]`**:
    - Se descuentan los recursos del almacén central, se activa la barra de progreso **`Ensamblando: Carreta de Mano (X / 15 s)`** (pudiendo encolar varias unidades con `(+X en cola)`) y, al completarse, la unidad ingresa al **Parque Móvil Disponible** de la ciudad.
- [ ] **Asignación de Transporte en Puestos y Refinerías (`PanelPuesto`):**
  - Abrir el `PanelPuesto` de la **Mina**, **Maderero** o **Siderúrgica** y localizar la sección **`Transporte logístico:`**:
    - Por defecto muestra: `Transporte actual: Acarreador a Pie | Capacidad: 150 u | Velocidad: 2.5 m/s`.
    - Como ahora hay una carreta en el parque móvil, aparece el botón **`[Asignar: Carreta de Mano (1 disp.)]`**. Hacer clic sobre él.
  - **Resultado esperado:**
    - El puesto asigna el vehículo del parque móvil y actualiza la lectura a: **`Transporte actual: Carreta de Mano | Capacidad: 350 u | Velocidad: 3.2 m/s`**.
    - Los acarreadores de ese puesto transportan ahora hasta **350 unidades por viaje** (más del doble que a pie) y se desplazan a `3.2 m/s` por las vías.
    - Si se pulsa **`[Volver a Acarreador a Pie]`**, la carreta se devuelve inmediatamente al parque móvil disponible de la ciudad (`1 disp.`). Volver a dejar la carreta asignada al puesto.

---

## Bloque 6: Extracción de Fluidos, Industria Petroquímica y Canalizaciones Elevadas

> **Condición previa cumplida:** Ya disponemos de **Técnicos** (Bloque 5.1) y hemos alcanzado la **Era 2 / Metalurgia Aplicada** (Bloque 5.5) para construir la Estación de Bombeo, el Centro de Extracción, el Almacén de Fluidos, la Refinería Petrolera y el Productor de Combustible.

### 6.1 Estación de Bombeo de Agua (`1 -> 2 -> 5` — Periférico)
- [ ] **Prueba de rechazo en agua somera:** En cenital, seleccionar **`1` -> `2` -> `5` (Estación de bombeo)** e intentar colocarla sobre la orilla con solo 1 bloque de profundidad de agua: rechaza con el aviso *"requiere al menos 2 bloques de profundidad de agua bajo su muelle"*.
- [ ] **Colocación válida en agua profunda ($\ge 2$ bloques):** Ubicarla **fuera de la Zona de Influencia** con el muelle sobre agua de $\ge 2$ bloques de profundidad y la plataforma sobre tierra firme (`Ctrl + Scroll` para orientarla).
- [ ] **Resultado esperado:**
  - Una vez construida, cuenta con el bloque **`puerto_agua_out`** en su pared de tierra a cota elevada ($Y = Y_{base} + 4$).
  - En su `PanelPuesto`, admite **`Técnicos`** (`▲`) y muestra el desplegable de su puerto de salida (`⚪ Desconectado`). Contratar al menos 1 Técnico.

### 6.2 Centro de Extracción Subterráneo (`1 -> 2 -> 6` — Periférico)
- [ ] **Prueba sin depósito:** Seleccionar **`1` -> `2` -> `6` (Centro de extracción)** y mover el cursor sobre terreno común sin yacimiento: la huella se muestra roja (*"No se detecta depósito subterráneo de agua o crudo"*).
- [ ] **Detección de pozo subterráneo y columna de perforación:** Mover el cursor **fuera de la Zona de Influencia** hasta que la huella se torne **dorada** sobre un pozo subterráneo de `crudo` (o `agua`).
  - La ficha técnica añade dinámicamente el costo en **`Estructura de hierro`** proporcional a la profundidad del pozo. Emplazarlo y dejar que se complete.
- [ ] **Resultado esperado:**
  - Se genera físicamente bajo el edificio la columna vertical de `estructura_hierro` hasta el fondo del yacimiento.
  - En `PanelPuesto`, indica **`Crudo restante en pozo: X bloques`** (o `Pozo de agua (inagotable)`), cuenta con puerto de salida a cota $Y=4$ y admite **Técnicos** (`▲`). Contratar al menos 1 Técnico.

### 6.3 Almacén de Fluidos (`1 -> 3 -> X -> 0`), Refinería Petrolera (`1 -> 3 -> 7`) y Productor de Combustible (`1 -> 3 -> 8`)
- [ ] **Almacén (`1 -> 3 -> X -> 0`):** En cenital, abrir `1 -> 3`, pulsar **`X`** (página 2) y seleccionar **`0` (Almacén)** (5×5 de piedra) para colocarlo sobre **Zona Industrial (`2 -> 2`)**.
  - Al terminarse, comprobar que tiene **6 puertos exteriores** a cota $Y=4$: pared izquierda con 3 entradas (`agua`, `crudo`, `combustible`) y pared derecha con 3 salidas (`agua`, `crudo`, `combustible`).
  - En `PanelPuesto`, los 6 puertos aparecen agrupados en **desplegables colapsables por recurso** con indicadores `⚪ Desconectado`, `🟢 Conectado` o `🔴 Derrame`.
- [ ] **Refinería Petrolera (`1 -> 3 -> 7`):** En la página 1 del menú Industrial (`1 -> 3`), pulsar **`7` (Refinería petrolera)** y colocarla sobre **Zona Industrial**.
  - Cuenta con `puerto_crudo_in` (izquierda) y `puerto_combustible_out` (derecha). Contratar **Técnicos (`▲`)**.
- [ ] **Productor de Combustible (`1 -> 3 -> 8`):** Pulsar **`8` (Productor combustible)** y colocarlo sobre **Zona Industrial**.
  - Cuenta con `puerto_agua_in` y `puerto_combustible_out`. Admite **Técnicos (`▲`)** y **Acarreadores (`▲`)** (sus acarreadores transportan `carbón` sólido desde el almacén central, respetando la `Reserva central:` configurada).

### 6.4 Trazado de Canalizaciones Elevadas (`1 -> 6 -> 1` Acueducto / `1 -> 6 -> 2` Tubería)
- [ ] **Ficha técnica con etiquetas legibles:** En cenital, pulsar **`1` (Construir) -> `6` (Ductos)** y elegir **`1` (Acueducto)** o **`2` (Tubería)**:
  - Verificar que la tarjeta contextual muestra nombres legibles en español (`1 Bloque de piedra`, `1 Bloque de acero`, `1 Estructura de hierro`).
- [ ] **Cota elevada ($Y_{suelo} + 4$), Columnas cada 5 bloques y Mallas sin Z-Fighting:**
  - Trazar un tramo en "L" de al menos 11 bloques haciendo clic izquierdo en el inicio, clic izquierdo en la esquina de 90° y **doble clic izquierdo** en el final:
  - El ducto se construye elevado dejando **3 bloques libres de altura bajo la viga** ($Y = Y_{suelo} + 4$), con columnas cada **5 bloques** y en cada esquina de 90°, sin *z-fighting*.
- [ ] **Libre circulación inferior de colonos y vías terrestres:**
  - Caminar con el avatar en 1ª persona por debajo de los vanos del ducto y trazar una vía de tierra pisada (`1 -> 5 -> 1`) que cruce **por debajo** del vano del ducto elevado: ambos cruzan limpiamente sin colisionar.

### 6.5 Cruces a Desnivel entre Dos Ductos (Doble Columna a $Y=6$ y Aire Libre a $Y=5$)
- [ ] **Acción:** Tener un Acueducto construido a $Y = Y_{suelo} + 4$ y trazar una **Tubería** (`1 -> 6 -> 2`) que lo cruce perpendicularmente.
- [ ] **Resultado esperado:**
  - En las dos celdas adyacentes al cruce se levantan automáticamente **dos columnas de 6 bloques de altura** ($Y = Y_{suelo} + 5$) y el tramo superior cruza a **$Y = Y_{suelo} + 6$**, dejando **1 bloque completo de aire libre** ($Y = Y_{suelo} + 5$) entre ambos ductos.

### 6.6 Conexión a Puertos, Partición 400/600 en Refinería, Inspección (`PanelCanalizacion`) y Demolición Limpia
- [ ] **Conexión de Acueducto (Estación de Bombeo $\to$ Almacén):**
  - Con **`1 -> 6 -> 1` (Acueducto)**, conectar el `puerto_agua_out` de la Estación de Bombeo al `puerto_agua_in` del Almacén con **doble clic izquierdo**.
  - En `PanelPuesto` de ambos edificios, los puertos pasan a **`🟢 Conectado`** y el agua extraída ingresa cada hora al depósito global de fluidos.
- [ ] **Conexión de Tubería y Límite 400/600 en Refinería Petrolera:**
  - Con **`1 -> 6 -> 2` (Tubería)**, conectar el `puerto_crudo_out` del Centro de Extracción de Crudo al `puerto_crudo_in` de la Refinería Petrolera, y el `puerto_combustible_out` de la Refinería al puerto de entrada de combustible del Almacén.
  - Verificar en el `PanelPuesto` de la Refinería Petrolera que el inventario local de crudo **nunca supera las 400 unidades (40%)**, reservando siempre **600 unidades (60%)** para que la salida de combustible jamás se bloquee.
- [ ] **Inspección (`PanelCanalizacion`) y Demolición sin Bloques Fantasma:**
  - En cenital modo Ver (`Esc`), hacer clic izquierdo sobre cualquier bloque de una canalización para abrir **`PanelCanalizacion`**.
  - Pulsar **`[Demoler canalización]`** y confirmar: el ducto completo se retira reembolsando sus materiales y dejando las celdas frente a los puertos limpias para reconectar.

### 6.7 Derrame Físico de Crudo (Spill), Físicas de Viscosidad/Drenado en 1ª Persona y Reconexión desde Columna
- [ ] **Provocar un Derrame en Extremo Abierto:**
  - Con **`1 -> 6 -> 2` (Tubería)**, iniciar un trazado en el `puerto_crudo_out` del Centro de Extracción de Crudo, avanzar 6–8 celdas hacia terreno despejado y confirmar con **doble clic izquierdo dejando el extremo final abierto**.
- [ ] **Resultado esperado (Spill y Spreading):**
  - En el siguiente tick horario, el estado pasa a **`🔴 Derrame`**, el HUD emite alerta y en la boca abierta cae un bloque físico de **`crudo`** que se extiende por gravedad hasta 3 celdas horizontales.
- [ ] **Prueba en 1ª Persona: Viscosidad Pesada en Crudo (0.20) y Drenado con Bloques Sólidos:**
  - Bajar a 1ª persona (**`C`**), caminar sobre el `crudo` derramado (comprobando la reducción de velocidad al factor `0.20`) y hacer **Clic Derecho** con un bloque sólido (`tierra`) sobre el charco para comprobar que reemplaza y seca el crudo al instante.
- [ ] **Reconstrucción / Extensión desde Columna en Derrame:**
  - En cenital (**`C`**), activar **`1 -> 6 -> 2` (Tubería)**, hacer clic izquierdo sobre la **última columna** de la tubería en derrame y llevarla hasta el `puerto_crudo_in` de la Refinería Petrolera (o del Almacén) con **doble clic izquierdo**: los tramos se fusionan, el puerto pasa a **`🟢 Conectado`** y el derrame se detiene y limpia.

---

## Bloque 7: Generación Termoeléctrica, `VentanaEnergia`, Lámpara Eléctrica con Batería Multicolor, Reconversión Doctrinal y Estrés Demográfico

> **Cierre del ciclo de pruebas:** Con la red petroquímica operativa, se levanta la **Central Termoeléctrica (`1 -> 3 -> 9`)** para electrificar la colonia, se verifica la lectura de superávit positivo en la barra superior, la persistencia de **`VentanaEnergia`** al teletransportar la cámara, el cambio de color gradual de la batería de la lámpara eléctrica (`Verde -> Amarillo -> Naranja -> Rojo`), la reconversión industrial doctrinal y las pruebas finales de demografía.

### 7.1 Central Termoeléctrica (`1 -> 3 -> 9`): Selector de Combustible, Reserva Porcentual y Acarreo de Carbón
- [ ] **Construcción:** En cenital, pulsar **`1` (Construir) -> `3` (Industrial) -> `9` (Central termoeléctrica)** y emplazarla sobre **Zona Industrial** dentro de la Zona de Influencia.
- [ ] **Operación en modo Carbón (Acarreo Sólido):**
  - Una vez construida, abrir su `PanelPuesto` en modo Ver (`Esc`).
  - Verificar los tres botones del selector de combustible: **`[Carbón]`** (activo por defecto), **`[Combustible]`** y **`[Crudo]`**, además de la fila **`Reserva central:`** (`0%..50%` con flechas `▲`/`▼`).
  - Contratar **Técnicos (`▲`)** y **Acarreadores (`▲`)**:
    - Los acarreadores buscan `carbón` en el almacén central y lo descargan en la central (hasta 500 u).
    - Con técnicos presentes y carbón en su depósito, la central genera energía eléctrica (`20 kW` por lote activo) y su chimenea emite humo.
- [ ] **Operación en modos Crudo / Combustible (Por Tubería):**
  - Hacer clic en **`[Combustible]`** o **`[Crudo]`**: la central libera a sus acarreadores y pasa a alimentarse por sus puertos laterales de tubería (`puerto_combustible_in` o `puerto_crudo_in`). Dejarla generando energía activamente.

### 7.2 Botón "Energía" en Barra Superior (Balance Positivo en kW/MW), Modal `VentanaEnergia` y Persistencia al Teletransportar
- [ ] **Lectura de Balance Neto Positivo en la Barra Superior (`BarraSuperior.gd`):**
  - Observar el botón de **Energía** en la barra superior mientras la Central Termoeléctrica genera más energía de la que consumen las refinerías:
  - Comprobar que muestra el ícono **`energia_dorado.svg`** y el **valor positivo del excedente neto** en color verde claro (ej. **`+18 kW`** o **`+1.2 MW`** si supera los 1000 kW), cambiando a `0 kW` (`energia_gris.svg`) solo cuando generación y demanda son iguales, o a valor negativo en rojo (`energia_rojo.svg`) cuando hay déficit.
- [ ] **Apertura Centrada y Bloqueo de Teclado en `VentanaEnergia`:**
  - Hacer clic izquierdo sobre el botón de **Energía** en la barra superior:
  - Se abre **`VentanaEnergia`** (`480x420`) **perfectamente centrada en la pantalla**.
  - Pulsar las teclas **`E`** y **`Esc`**: comprobar que **la ventana NO se cierra con el teclado** (solo se cierra al pulsar su botón **`X`**).
- [ ] **Resumen Global, Teletransporte de Cámara y Persistencia de Ventana (`VentanaEnergia.gd`):**
  - Verificar la cabecera con **Capacidad Generada**, **Balance Neto**, **Demanda Total** y **Cobertura**, seguida de las listas de **Fuentes Generadoras** y **Edificios Consumidores** (mostrando a la Universidad como consumidor solo si está investigando *Automatización Industrial*).
  - **Prueba de Teletransporte sin Cierre:** Hacer clic izquierdo sobre cualquiera de los edificios listados en `VentanaEnergia` (generador o consumidor):
    - La Cámara Cenital **vuela suavemente (`Tween`) hasta centrarse sobre ese edificio** y abre su panel lateral, **PERO `VentanaEnergia` permanece abierta en pantalla** (permitiendo hacer clic en otros generadores o consumidores sucesivamente sin tener que reabrirla).
    - Cerrar `VentanaEnergia` haciendo clic en su botón **`X`**.

### 7.3 Conmutación a `LÁMPARA ELÉCTRICA🟡` y Color Dinámico de la Barra de Batería (72 h)
- [ ] **Condición cumplida:** La Central Termoeléctrica está activa y entregando energía a la red (`capacidad > 0`).
- [ ] **Acción (Encendido Eléctrico en Ciudad):** Pasar a 1ª persona (**`C`**) estando **dentro de la Zona de Influencia** y pulsar **`L`** para encender la lámpara.
- [ ] **Resultado esperado:**
  - Se enciende en modo **`LÁMPARA ELÉCTRICA🟡`** (luz blanca intensa, rango 18 m) y `PanelLampara` muestra **`Batería: 100% | 72 h`** con la barra de progreso en **color Verde**.
- [ ] **Acción (Descarga fuera de la Zona de Influencia y Gradiente de 4 Colores):** Caminar con la lámpara encendida **fuera de la Zona de Influencia** y observar la barra de progreso (`ProgressBar`) en `PanelLampara` a medida que desciende el porcentaje de carga:
  - **`> 50%` de carga:** La barra se muestra en **Verde** (`Color(0.35, 0.85, 0.40)`).
  - **`25% a 50%` de carga:** La barra cambia automáticamente a **Amarillo** (`Color(0.95, 0.85, 0.25)`).
  - **`10% a 25%` de carga:** La barra cambia a **Naranja** (`Color(0.95, 0.55, 0.20)`).
  - **`< 10%` de carga:** La barra cambia a **Rojo de alerta** (`Color(0.95, 0.25, 0.25)`).
- [ ] **Acción (Recarga Automática al Regresar a la Ciudad):** Volver a entrar en la **Zona de Influencia**:
  - La batería se recarga a razón de **`+7.2 h` por cada hora de juego** y la barra recorre los colores en sentido inverso hasta recuperar el **Verde (`100% | 72 h`)**.

### 7.4 Evolución a Era 3/4, Vehículos Pesados con Restricción Vial y Reconversión Industrial sin Demolición
- [ ] **Progresión a Era 3 (`Industrialización Plena`, `IDU >= 2.50`):**
  - Con las instalaciones de Tipo 3 activas (`Refinería petrolera`, `Productor de combustible`, `Central termoeléctrica`), más personal cualificado y las ciencias teóricas de Era 2 completadas, comprobar en la barra superior que al alcanzar **`IDU >= 2.50`** la ciudad avanza a **`Industrialización Plena` (Era 3, insignia `III` `romano_3.svg`)**.
  - En la Universidad se desbloquean las ciencias teóricas de Era 3: **`Termodinámica y Vapor (300 pts)`**, **`Redes Eléctricas y Bobinado (350 pts)`** y **`Química de Hidrocarburos (400 pts)`**.
- [ ] **Vehículos Pesados (`exige_via = true`) y Arrastre Lento (`1.2 m/s`):**
  - Tras investigar `Química de Hidrocarburos` (o `Redes Eléctricas y Bobinado`), abrir el **Taller de Transporte**: comprobar que su título evolucionó a **`Taller de Maquinaria y Transporte`** y permite fabricar el **`Camión Pesado Diésel (40s) — 80 Acero, 50 Combustible, 20 Vidrio`** (`1800 u | 6.5 m/s`) o el **`Trolebús Eléctrico Bio-Vía (35s) — 50 Tablas, 40 Acero, 30 Cobre, 15 Vidrio`** (`900 u | 5.0 m/s`).
  - **Restricción Vial Estricta:** Intentar asignar un Camión Pesado Diésel o Trolebús a un puesto que **no** tenga conexión continua por vía afirmada con el almacén central $\to$ el sistema rechaza o bloquea la ruta exigiendo red vial continua (`exige_via = true`). Conectarlo con una vía completa y comprobar que transporta hasta `1800 u` por viaje.
  - **Arrastre Lento sin Insumo:** Si el almacén se queda sin `combustible` (para el camión) o la red entra en déficit eléctrico (para el trolebús/dron), comprobar que el vehículo **no desaparece ni pierde su carga**, sino que reduce su velocidad al modo de arrastre forzado (`1.2 m/s`) hasta que se repone el suministro.
- [ ] **Reconversión Industrial Doctrinal sin Demolición (`PanelPuesto`):**
  - En la **Central Termoeléctrica**, instalar una mejora práctica de una doctrina (ej. **`Caldera Diésel de Alta Presión`** [Era 3, requiere `Química de Hidrocarburos`, despacha **2 Investigadores Itinerantes**, `+15 pts Dieselpunk`]).
  - Cuando se descubre una tecnología de otra doctrina incompatible para ese mismo edificio (ej. `Ciclo Geotérmico / Biocombustión Solarpunk` o `Control Cibernético` en Era 4), comprobar que en el `PanelPuesto` de la Central Termoeléctrica aparece el botón **`[Iniciar Reconversión Industrial: ...]`**.
  - Al pulsarlo y confirmar en el diálogo modal: se cobra la tasa de reforma (50% de la nueva mejora + 25% del edificio base), el edificio entra en estado `RECONVERSION` (produciendo al 25% durante $1.5\times$ el tiempo normal con una comisión científica) y al completarse **sustituye la mejora anterior y transfiere los puntos en la Balanza Doctrinal (`D / C / S`)** sin haber tenido que demoler la central.

### 7.5 Pruebas de Estrés Demográfico y Sucesión (Fin de Sesión)
> *(Nota: Ejecutar estas comprobaciones al cierre de la sesión de pruebas, ya que alteran la población o fuerzan estados de emergencia en la colonia).*

- [ ] **Alertas de Escasez (< 5% de Capacidad):**
  - Comprobar que cuando cualquier recurso del almacén desciende por debajo del **5%** de su capacidad máxima, el HUD emite la alerta **`"¡Atención! Reserva de [Recurso] por debajo del 5%"`**.
- [ ] **Tolerancia de Desempleo (240 h) y Sin Techo (72 h):**
  - Los colonos en estado `"Sin techo"` más de **72 horas (3 días)** emigran penalizando `-10` puntos de moral.
  - Los colonos que permanecen como `"desempleado"` durante **240 horas (10 días)** continuas emigran pacíficamente.
- [ ] **Hambruna (0 Comida) y Éxodo por Moral Crítica ($\le$ 20%):**
  - Si el stock de `comida` cae a `0`, cada hora de inanición provoca bajas según `ORDEN_BAJAS_HAMBRUNA` y penaliza la moral a razón de **`-3.0 / día`**.
  - Cuando la moral cae a **$\le$ 20% (`😡`)**, el flujo migratorio se invierte en **éxodo de cerebros** (`investigador > especialista > tecnico > militar > obrero > desempleado`) y el botón de Impulso de Inmigración queda bloqueado (`"Impulso bloqueado por éxodo"`).
- [ ] **Sucesión del Avatar (Tecla `K` o Ahogamiento):**
  - Pulsar la tecla de prueba **`K`** en 1ª persona (o agotar a 0 la barra de oxígeno bajo el agua): se ejecuta `Ciudad.suceder_avatar()` (si hay militares aplica sucesión con 5 h de penalización electoral y reaparece en el origen con oxígeno al máximo).

---

## Bloque 8: Verificación en Vivo de la Iconografía Integral y Miniaturas 3D (HUD / UI)

### 8.1 Barra Superior e Iconografía Vectorial
- [ ] **Acción:** Observar la barra superior en 1ª persona y en cenital.
- [ ] **Resultado esperado:**
  - El censo muestra el ícono de grupo demográfico (`censo.svg`).
  - La moral exhibe el ícono emocional correspondiente (`moral_alta.svg` 🙂, `moral_neutra.svg` 😐, `moral_baja.svg` 🙁, `moral_critica.svg` 😡) centrado sobre la barra sombreada de progreso.
  - El botón Almacén muestra el ícono de cofre/almacén (`almacen.svg`).
  - La comida muestra el ícono de saco de trigo (`comida.svg`) y la flecha de tendencia horaria (`tasa_arriba.svg`, `tasa_neutra.svg` o `tasa_abajo.svg`).
  - El botón de Energía muestra el rayo interactivo (`energia_dorado.svg` con superávit positivo `+X kW`/`MW`, `energia_gris.svg` en `0 kW` o `energia_rojo.svg` con déficit `-X kW`/`MW`).
  - El bloque derecho muestra el ícono `era.svg`, el título de la Era actual y la insignia de números romanos (`romano_1.svg` a `romano_4.svg`) con su panel hover interactivo de IDU y Doctrina.

### 8.2 Botones de Construcción con Insignias en 3 Esquinas y Miniaturas 3D Vivas
- [ ] **Acción:** Pasar a la cámara cenital (`C`) y presionar `1` (Construir) $\to$ revisar los submenús de categorías (`1` a `6`, incluyendo las 2 páginas de Industrial con `X`/`Z`).
- [ ] **Resultado esperado:**
  - Los botones de edificios (104×76 px) muestran el sistema de insignias en 3 esquinas:
    1. **Esquina superior izquierda:** Columna vertical de íconos (14×14 px) con los recursos requeridos para construir la estructura.
    2. **Centro superior:** Ícono de energía dorado (14×14 px) **únicamente** en edificios que requieren suministro eléctrico continuo para operar (comprobar que la **Universidad** no lo lleva).
    3. **Esquina superior derecha:** Ícono representativo (18×18 px) del bien o función principal que produce el edificio (incluyendo `vidrio.svg` en la nueva **Vidriera**).
  - Todos los edificios, incluyendo la **Vidriera** y el **Taller de transporte**, así como Vías (`5`) y Ductos (`6`), exhiben su miniatura 3D isométrica en vivo.

### 8.3 Interfaz en Primera Persona y Herramienta Contextual
- [ ] **Acción:** Pasar a 1ª persona (`C`). Encender la lámpara (`L`), sumergirse en agua, picar bloques con clic izquierdo, recolectar frutos con `E` y construir un blueprint con clic derecho.
- [ ] **Resultado esperado:**
  - El panel de la lámpara muestra el ícono de bombilla/antorcha y su barra de progreso porcentual multicolor.
  - Al picar piedra aparece `herr_pico.svg`; al palear tierra, `herr_pala.svg`; al talar árboles, `herr_hacha.svg`; al recolectar frutos con `E`, `herr_cesta.svg`; al construir un edificio en blueprint con clic derecho, **`modo_construir.svg`**; y al deconstruir con `G`, **`modo_demoler.svg`**.

### 8.4 Ventanas Globales, Paneles de Edificio/Puesto y Diálogos Modales
- [ ] **Acción:** Abrir Población, Almacén, Ocupaciones, Energía (clic en topbar) y Moral (clic en topbar).
- [ ] **Resultado esperado:**
  - `VentanaMoral` y `VentanaEnergia` abren centradas, se arrastran con el ratón y solo se cierran con su botón `X`.
  - En `VentanaAlmacen`, las filas con hijos (`Comida`, `Crudo`, `Hierro`, `Madera`, `Piedra`, `Tierra`, `Tierras raras`) funcionan como desplegables interactivos `▶`/`▼` mostrando el sub-almacén de comida y los recursos refinados con íconos de 20×20 px.
  - En `PanelEdificio`, las residencias muestran los íconos `cama.svg` y `baul.svg`, los materiales faltantes muestran su ícono vectorial por fila, y la prioridad de obra cuenta con botones `btn_subir.svg` (`▲`) y `btn_bajar.svg` (`▼`).
  - En `PanelPuesto` y `VentanaBaul`, todos los controles de incremento/decremento muestran los íconos `btn_subir.svg` (`▲`) y `btn_bajar.svg` (`▼`) visibles incluso cuando están deshabilitados; la producción de los puestos se aloja en un `ScrollContainer` de 3 filas (`72 px`), y la Universidad exhibe sus barras de progreso e íconos de recursos y reloj de arena.

---

## Tabla de Resumen y Aprobación Rápida

| Bloque | Característica comprobada (en orden lógico de juego) | Estado (OK / Fallo) | Notas del tester |
| :--- | :--- | :---: | :--- |
| **1.1** | Movimiento 1ª persona, tala/minado, recolección de frutos (`E` con `herr_cesta.svg`) y equivalencia `vidrio`/`tierra` (1:3) | | |
| **1.2** | Natación en agua ($\ge 2$ bloques), corrientes, oxígeno y drenado con bloques sólidos | | |
| **1.3** | Lámpara en modo Térmico inicial (`L`: combustible 10h, carbón 6h, madera 5h) y oxígeno apilado | | |
| **2.1** | 1er Edificio con `B`: puertas 3D, **ventanas sin Z-fighting lateral**, drenado interior automático y fundación de **Núcleo Urbano** | | |
| **2.2** | Remodelación del Núcleo (`Shift+B`) y botones cívicos en `PanelEdificio`: **Impulso (+250%)** y **Decreto de Racionamiento (-35% comida, máx. 35% moral)** | | |
| **2.3** | Zona Residencial (`2-1`), **costos con íconos en previsualización de blueprint (`1-1`)**, íconos de camas/baúles/faltantes en `PanelEdificio` e ícono `modo_construir` al surtir en 1ª persona | | |
| **2.4** | 1ª Residencia habitable (`Colonizable: SÍ`), llegada de colonos y activación del **Impulso de Inmigración (+250% por 30 días sin tope de camas)** | | |
| **2.5** | Remodelación con `Shift+B` en 1ª persona abre **diálogo de advertencia de desahucio**, colonos `"Sin techo"` **permanecen in-situ** (sin respawn desde el borde) y `B` los reabsorbe | | |
| **2.6** | 2ª Residencia construida por colonos nace como buffer (`Colonizable: NO 24h`) y permite reubicar sin dejar sin techo | | |
| **2.7** | Edificios adosados (flood-fill se detiene en muro vecino) y traslado de Núcleo Urbano (gracia de 5 h) | | |
| **3.1** | Trazador cenital de vías (`1-5-1`) con iconos SVG, ficha técnica (`+35%`) y cancelación limpia con clic derecho | | |
| **3.2** | Nivelación y despeje compartidos entre puertas enfrentadas en una calle | | |
| **3.3** | Tendido progresivo de vías por colonos (`ViaObraOverlay` amarillo consecutivo) y fusión de tramos | | |
| **3.4** | Intervención manual de vías a pie (`V`): construir (clic izq.) y demoler (clic der.) secciones 2×2 | | |
| **3.5** | Demolición cenital unificada (`3`): edificios (con escurrimiento de agua vecina) y vías con Dijkstra en esquinas de 90° | | |
| **3.6** | Prioridades de obra con botones `btn_subir` (`▲`) / `btn_bajar` (`▼`) en `PanelEdificio` y apertura automática de `PanelPuesto` al terminar obra | | |
| **4.1** | Topbar con **hover de Nivel (IDU)** y `VentanaAlmacen` con **desplegables `▶`/`▼`** (6 sub-categorías de comida por perecibilidad y recursos refinados hijos) | | |
| **4.2** | `VentanaMoral` centrada (solo clic en topbar y cierre con `X`, **se oculta al pasar a 1ª persona**), variedad dietética (`X/6`), regla de monocultivo (360h) y suelo agrario del 75% | | |
| **4.3** | Puestos periféricos (`1-2-1..4`): botones `▲`/`▼` siempre visibles y **lista vertical de producción con scroll fijo (`72 px`, 3 filas visibles)** | | |
| **4.4** | Preferencia de vías en pathfinding (`BuscadorRutas`: vía coste 3 vs campo 8) y prioridad de paso con carga | | |
| **4.5** | Interacción en 1ª persona con `VentanaBaul` (`E`): centrada, columnas alineadas y botones `▲`/`▼` para ingresar/retirar | | |
| **5.1** | Escuela técnica (`1-4-1`): cohorte de 4 aprendices (24 h) gradúa **3 Técnicos** y ascenso/retroceso de nivel en Mina | | |
| **5.2** | Zona Industrial (`2-2`), Fábrica de bloques (`1-3-4`, receta 1:3) y nueva **Vidriera (`1-3-5`, 1 tierra + 1 carbón $\to$ 3 vidrio)** | | |
| **5.3** | Control de **Reserva Central porcentual (`0% / 10% / 20% / 35% / 50%`)** con botones `▲`/`▼` en refinerías | | |
| **5.4** | Escuela de especialistas (`1-4-2`): exige Escuela técnica y gradúa **2 Especialistas** tras 48 h | | |
| **5.5** | Universidad (`1-4-3` **sin requisito eléctrico**): diálogo con íconos (`hierro`, `madera`, `reloj_arena`), barra de progreso, pausa/cancelación y transición orgánica a **Era 2 (`IDU >= 1.50`)** | | |
| **5.6** | Investigación en 2 capas: **Ciencias Básicas Teóricas (Capa 1)** en Universidad y **Mejoras Prácticas In-Situ (Capa 2)** con **Investigador Itinerante** y **Balanza Doctrinal (D/C/S)** | | |
| **5.7** | **Taller de Transporte Evolutivo (`1-3-X-1`)**: cola de fabricación de vehículos (`Carreta de Mano`) y selector **`Transporte logístico:`** en puestos (`350 u`) | | |
| **6.1** | Estación de bombeo (`1-2-5`): validación de agua $\ge 2$ bloques, muelle, `puerto_agua_out` y operación con Técnicos | | |
| **6.2** | Centro de extracción (`1-2-6`): detección de pozo subterráneo, columna de hierro dinámica y agotamiento de crudo | | |
| **6.3** | Almacén de fluidos (`1-3-X-0`, 6 puertos en desplegables), Refinería petrolera (`1-3-7`) y Productor de combustible (`1-3-8`) | | |
| **6.4** | Canalizaciones elevadas (`1-6-1`/`1-6-2`): etiquetas legibles, cota $Y+4$, paso libre de vías/colonos y columnas cada 5 bloques | | |
| **6.5** | Cruces a desnivel de ductos: doble columna lateral a $Y=6$ con 1 bloque de aire libre intermedio ($Y=5$) | | |
| **6.6** | Conexión a puertos, partición 400/600 en Refinería petrolera, `PanelCanalizacion` y demolición limpia sin fantasmas | | |
| **6.7** | Derrame físico en extremo abierto (`🔴 Derrame`), viscosidad 0.20 y drenado de `crudo` en 1ª persona, y reconexión desde columna | | |
| **7.1** | Central termoeléctrica (`1-3-9`): selector `Carbón`/`Combustible`/`Crudo`, reserva central porcentual y acarreo de carbón | | |
| **7.2** | Botón "Energía" en topbar (**muestra superávit positivo `+X kW/MW`**) y `VentanaEnergia` centrada (solo cierra con `X` y **NO se cierra al teletransportar cámara**) | | |
| **7.3** | Conmutación a `LÁMPARA ELÉCTRICA🟡` (72 h) y **cambio de color gradual de la barra de batería (`Verde -> Amarillo -> Naranja -> Rojo`)** | | |
| **7.4** | Evolución a Era 3/4, vehículos pesados con **restricción vial estricta (`exige_via`)**, **arrastre lento sin insumo (`1.2 m/s`)** y **Reconversión Industrial sin demolición** | | |
| **7.5** | Estrés demográfico final: alerta de recurso `<5%`, emigración sin techo (72 h) / desempleo (240 h), hambruna, éxodo ($\le$20%) y sucesión (`K`) | | |
| **8.1–8.4** | Auditoría visual completa de iconos SVG en Topbar, insignias de 3 esquinas, miniaturas 3D, herramientas en 1ª persona y paneles | | |

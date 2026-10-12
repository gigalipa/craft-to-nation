# Guión de Verificaciones en Vivo (Live QA Script) — Craft to Nation

Este documento es el guión integral de pruebas manuales paso a paso para comprobar en vivo, directamente dentro del juego en ejecución (**F5** en Godot), que todas las funciones, mecánicas de fluidos, trazado de ductos, gestión energética, colonos y balance del juego operan de manera óptima y sin errores.

El guión está estructurado en una **secuencia cronológica y lógica de juego**: desde las mecánicas en primera persona del avatar al comenzar la partida, pasando por la fundación urbana, la red vial, la economía, la industria pesada y la red elevada de canalizaciones, hasta la supervisión energética de la metrópoli.

---

## 0. Preparativos y Controles Globales

### Iniciar el entorno
1. Abrir el proyecto en Godot y pulsar **F5** (o ejecutar la escena principal `Main.tscn`).
2. Comprobar que el avatar aparece en el mundo y que la barra superior del HUD es visible.

### Atajos de Teclado Clave

#### Primera Persona (Avatar)
| Tecla / Acción | Función |
| :--- | :--- |
| **C** | Alternar entre cámara en **1ª persona** y **Cámara Cenital** (con vuelo y transición animada). |
| **W, A, S, D** | Movimiento del avatar. |
| **Espacio** | Salto / Nadar hacia arriba en líquidos. |
| **L** | **Encender / apagar lámpara omnidireccional** del avatar. |
| **E** | Interactuar (abrir/cerrar puertas y baúles) / Cerrar ventanas activas. |
| **G** | Alternar modo deconstrucción / demolición manual a pie. |
| **V** | Alternar modo interacción con vías a pie: clic izq. construir tramo, clic der. demoler tramo. |
| **B / Shift + B** | Declarar estructura (**B**) / Iniciar remodelación (**Shift + B**) apuntando a la puerta. |
| **Esc** | Cerrar ventana emergente activa, salir de modo vías o deconstrucción. |

#### Cámara Cenital (Gestión Urbana)
| Tecla / Acción | Función |
| :--- | :--- |
| **W, A, S, D** | Paneo horizontal de la cámara sobre el plano X/Z. |
| **Q / E** | **Rotación orbital:** Gira la vista 45° a la izquierda (**Q**) o a la derecha (**E**). |
| **Rueda del ratón (Scroll)** | **Zoom:** Acerca o aleja oblicuamente respecto al punto focal. |
| **Ctrl + W / Ctrl + S** | **Inclinación:** Modifica el ángulo de inclinación vertical de la cámara. |
| **Shift + W / Shift + S** | **Altura vertical:** Sube (**Shift+W**) o baja (**Shift+S**) directamente la cota de la cámara. |
| **1** | Menú **Construir** (1: Residencial, 2: Periférico, 3: Industrial, 4: Investigación, 5: Vías, 6: Ductos). |
| **2** | Menú **Zonificar** (1: Zona Residencial/A, 2: Zona Industrial/B, 3: Borrar). |
| **3** | Modo **Demoler** unificado (edificios y vías con previsualización guiada). |
| **Z / X** | Retroceder submenú (**Z**) / Avanzar página (**X**) en menús numéricos cenitales. |
| **Ctrl + Scroll** | Rotar previsualización de blueprint o edificio (giros de 90° durante colocación). |
| **Clic izquierdo** | Fijar punto de trazo, colocar estructura o inspeccionar edificio/ducto. |
| **Doble clic izq.** | Confirmar trazado de vía o canalización. |
| **Clic derecho** | Cancelar tramo acumulado / cancelar modo de colocación. |
| **Esc** | Volver al modo neutro "Ver" o cerrar ventanas abiertas. |

---

## Bloque 1: Físicas de Fluidos, Avatar y Herramientas a Pie (1ª Persona)

> **Mecánicas implementadas:** Viscosidad viscosa de crudo (0.20), inmersión, consumo de oxígeno, drenado de líquidos con sólidos, lámpara omnidireccional con jerarquía eléctrica/térmica y ventana de baúl centrada.

### 1.1 Inmersión y Viscosidad en Crudo y Líquidos
- [ ] **Acción:** Ubica o camina hacia un bloque de `crudo` natural o derramado.
- [ ] **Resultado esperado:**
  - El bloque de crudo es translúcido oscuro aceitoso y **no tiene colisión sólida** (permeable).
  - Al ingresar al crudo, la velocidad horizontal del avatar se reduce drásticamente (factor de viscosidad **0.20**; notablemente más denso y pesado que el agua).
  - El salto dentro del crudo está amortiguado y la velocidad de caída/hundimiento es lenta y pesada.
- [ ] **Acción (Consumo de Oxígeno):** Sumergir la cabeza por completo en el crudo o agua.
- [ ] **Resultado esperado:**
  - Comienza a consumirse la barra de oxígeno.

### 1.2 Drenado y Secado de Líquidos Colocando Bloques Sólidos
- [ ] **Acción:** Apuntar a una celda inundada de líquido (`crudo`, `agua` o `combustible`) con un bloque sólido seleccionado en la mano (tierra, madera, piedra, etc.) y hacer clic derecho para colocarlo.
- [ ] **Resultado esperado:**
  - El bloque sólido **sobrescribe y desaloja el líquido de inmediato**.
  - No rechaza la colocación: el líquido en esa celda queda drenado/seco y el bloque sólido queda establecido en el mundo.

### 1.3 Lámpara Omnidireccional del Jugador (Tecla `L`) y PanelLampara
- [ ] **Acción:** En 1ª persona, presionar la tecla **`L`**.
- [ ] **Resultado esperado:**
  - Se enciende una fuente de luz omnidireccional en el avatar.
  - En el HUD aparece la ventana **`PanelLampara`**:
    - Estando dentro de la zona de influencia de la ciudad con energía en red: muestra título **`LÁMPARA ELÉCTRICA🟡`** y detalle `Batería: 100% | 72 h` (o recargando `+X% | Y h`).
- [ ] **Descarga y conmutación térmica:** Camina con la lámpara encendida fuera de la zona de influencia de la colonia:
  - Al pasar las horas del juego, la batería se descarga progresivamente (`-X% | Y h`).
  - Al agotarse la batería (0 h), la lámpara conmuta automáticamente a **`LÁMPARA TÉRMICA🟡`** consumiendo insumos del stock central en orden:
    1. *Combustible* (24 h / unidad).
    2. *Carbón* (6 h / unidad).
    3. *Madera* (2 h / unidad).
  - El panel detalla: `Tiempo restante: X h | Y [Recurso]`.
- [ ] **Recarga automática:** Vuelve a la zona electrificada de la colonia: la lámpara conmuta de inmediato a Eléctrica y recarga su batería hasta 72 h.
- [ ] **Apagar:** Presionar **`L`** nuevamente: la luz se apaga y el indicador muestra el círculo negro `⚫`.

### 1.4 Ventana de Oxígeno Apilada
- [ ] **Acción:** Sumergir la cabeza del avatar en agua o crudo con la ventana de la lámpara activa.
- [ ] **Resultado esperado:**
  - La ventana `PanelOxigeno` se muestra **apilada verticalmente justo debajo** del panel de la lámpara sin solaparse ni interferir con la mira.

### 1.5 Interacción y Cierre Rápido de Baúl (`VentanaBaul`)
- [ ] **Acción:** Caminar hasta el baúl de un puesto construido, apuntar la mira y pulsar **E**.
- [ ] **Resultado esperado:**
  - Se abre `VentanaBaul` perfectamente centrada en pantalla con tamaño acotado (`320x260`).
  - Lista de recursos con barra de scroll vertical si hay múltiples elementos.
  - El cursor se libera para transferir recursos con `-`, `+` o `"Extraer todo"`.
- [ ] **Acción:** Pulsar nuevamente **E** (o presionar **Escape**).
- [ ] **Resultado esperado:**
  - La ventana se cierra inmediatamente y el control de la cámara se restaura al instante.

---

## Bloque 2: Fundación Urbana, Vivienda y Ciclo de Vida Residencial

> **Mecánicas implementadas:** Puerta obligatoria en Nivel 0, blueprints automáticos con miniaturas 3D, remodelación (`Shift+B` y cenital), desahucio/reubicación, edificios contiguos, buffer de inmigración (24h) y traslado de núcleo.

### 2.1 Construcción y Declaración de la 1ª Residencia (Planta Baja y Pisos Superiores)
- [ ] **Acción:** Levantar manualmente una casa de 2 plantas:
  - **Planta baja (Nivel 0):** Cerrada, con 1 puerta exterior, 1 ventana, camas y baúl.
  - **Planta alta (Nivel 1):** Con paredes, techo, escaleras de acceso y ventanas, **sin ninguna puerta exterior**.
- [ ] **Acción:** Apuntar a la puerta principal y presionar **B** para declarar.
- [ ] **Resultado esperado:**
  - El edificio se declara con éxito: no exige puerta en pisos superiores.
  - Se genera un blueprint nombrado automáticamente: `Residencia [camas]x[baules]`.

### 2.2 Blueprints y Miniaturas en Menú Cenital
- [ ] **Acción:** Pasar a vista cenital (**C**), pulsar **1** (Construir) -> **1** (Residencial).
- [ ] **Resultado esperado:**
  - Se listan hasta 5 blueprints con miniaturas isométricas 3D de cada diseño.
  - Al seleccionar uno para colocar, la tarjeta muestra: `[Ctrl] [Icono Scroll] ROTAR` y `[Icono Clic Izq.] COLOCAR`.
  - Rotar con Ctrl+Scroll gira la previsualización en pasos de 90°.

### 2.3 1ª Residencia: Colonizable Automática
- [ ] **Acción:** En vista cenital en modo Ver (`Esc`), hacer clic izquierdo sobre la primera residencia terminada.
- [ ] **Resultado esperado:**
  - `PanelEdificio` indica: `Colonizable: SÍ (inmigración activa)` y botón `[Pausar colonización]`.
  - Desglose exacto de residentes por categoría respetando el cupo de camas.

### 2.4 Remodelación en 1ª Persona (`Shift + B`) y Cenital
- [ ] **Acción en 1ª persona:** Caminar hacia la puerta de la residencia, apuntar a ella y pulsar **`Shift + B`**.
- [ ] **Resultado esperado:**
  - Notificación: *"Remodelación iniciada para el edificio X: ahora en edición libre."*
  - Los bloques se liberan de protección: es posible minar, ampliar muros o añadir camas.
  - Los residentes se reubican automáticamente en otras camas disponibles de la colonia.
- [ ] **Acción en cenital:** Seleccionar un edificio residencial poblado y hacer clic en **`[Iniciar remodelación]`**.
  - Muestra diálogo modal con desglose: residentes reubicados y advertencia si colonos quedan sin techo.
  - Al confirmar, el edificio pasa a edición libre.

### 2.5 Colonos "Sin Techo" y Reabsorción
- [ ] **Acción:** Iniciar remodelación en la única residencia poblada sin que haya otras camas en la colonia.
- [ ] **Resultado esperado:**
  - La ventana de **Población** muestra: `"Sin techo: X"`.
  - Consumen comida a tasa de desempleado y no ocupan puestos de trabajo.
- [ ] **Acción:** Volver a declarar la residencia (pulsando **B** en la puerta) o construir una nueva.
- [ ] **Resultado esperado:**
  - Los colonos sin techo se absorben de inmediato y recuperan su estado normal.

### 2.6 Edificios Adosados Pared con Pared
- [ ] **Acción:** Construir dos casas pegadas pared con pared y declarar ambas (Edificio A y Edificio B).
- [ ] **Acción:** Iniciar remodelación solo en el Edificio A.
- [ ] **Resultado esperado:**
  - Edificio A pasa a edición libre; Edificio B permanece intacto y protegido.
- [ ] **Acción:** Modificar el Edificio A y declararlo con **B**.
- [ ] **Resultado esperado:**
  - El *flood-fill* se detiene en seco en el muro de B: se declara A limpiamente sin absorber a B.

### 2.7 2ª Residencia en adelante: Buffers Habitacionales y Control Manual
- [ ] **Acción:** Construir y declarar una segunda residencia en la colonia.
- [ ] **Resultado esperado:**
  - Nace con `Colonizable: NO (apertura en 24 h)` y botón `[Permitir colonización]`.
  - Sus camas sirven para reubicar ciudadanos locales, pero no atraen inmigrantes externos.
  - Cada hora de juego reduce el contador hasta abrirse automáticamente a las 24 h.
- [ ] **Acción:** Pulsar `[Permitir colonización]`.
  - Pasa inmediatamente a `Colonizable: SÍ (inmigración activa)`.
- [ ] **Acción:** Pulsar `[Pausar colonización]`.
  - Vuelve a `Colonizable: NO (buffer protegido)`.

### 2.8 Excepción del Núcleo Urbano y Traslado
- [ ] **Acción:** Iniciar remodelación en el Núcleo Urbano (`Shift + B` o en cenital).
- [ ] **Resultado esperado:**
  - Entra en edición libre **sin desalojar habitantes ni generar colonos sin techo** (crecimiento orgánico).
- [ ] **Acción:** Seleccionar una residencia secundaria terminada y pulsar *"Asignar como núcleo urbano"*.
- [ ] **Resultado esperado:**
  - Modal de confirmación con período de gracia de 5 horas.
  - El núcleo y su radio de influencia se trasladan a la nueva sede sin pérdida de recursos.

---

## Bloque 3: Infraestructura Vial, Tráfico y Desplazamiento de Colonos

> **Mecánicas implementadas:** Ficha técnica de vías, iconografía SVG, cancelación con clic der., tendido progresivo por cuadrilla, intervención manual con V, demolición guiada con Dijkstra en esquinas de 90° y preferencia de vías en BuscadorRutas.

### 3.1 Trazador Cenital de Vías e Iconografía SVG (`1` -> `5` -> `1`)
- [ ] **Acción:** En cenital (**C**), pulsar **1** (Construir) -> **5** (Vías) -> **1** (Trazar vía).
- [ ] **Resultado esperado:**
  - La tarjeta contextual muestra iconos vectoriales reales:
    - `[Icono Clic Izq.] FIJAR PUNTO`
    - `[Icono Clic Izq. (x2)] CONFIRMAR`
    - `[Icono Clic Der.] CANCELAR`
    - `[Esc] SALIR`
  - Ficha técnica dinámica con `Velocidad: +35%` y costos calculados en vivo.
- [ ] **Cancelación limpia:** Hacer un clic izquierdo en el suelo, mover el ratón y presionar **Clic Derecho**:
  - El tramo se cancela al instante sin dejar baldosas fantasmas.

### 3.2 Nivelación Compartida entre Puertas Enfrentadas
- [ ] **Acción:** Trazar una vía o colocar un edificio frente a otro con sus puertas a 2–3 bloques de distancia en un terreno con pendiente.
- [ ] **Resultado esperado:**
  - El terreno entre ambas puertas se nivela a la misma cota compartida sin saltos bruscos ni escalones inaccesibles.

### 3.3 Tendido Progresivo de Vías por Colonos (`ViaObraOverlay`)
- [ ] **Acción:** Trazar una vía y confirmar con **doble clic izquierdo**.
- [ ] **Resultado esperado:**
  - Se genera una obra visible mediante un **contorno perimetral amarillo** en el suelo (`ViaObraOverlay`).
  - Hasta 4 obreros libres acuden a trabajar.
  - **Construcción consecutiva:** Avanza de un extremo a otro completando cada celda (nivelar, rellenar o cuña) en orden continuo.
  - Conforme se completan celdas, el contorno amarillo se retira hasta finalizar la obra.
- [ ] **Fusión de tramos:** Trazar un tramo nuevo contiguo a una obra vial en curso:
  - Se fusiona con la obra activa bajo la misma cuadrilla de 4 obreros.

### 3.4 Intervención Manual de Vías a Pie en 1ª Persona (Tecla `V`)
- [ ] **Acción:** En 1ª persona, pulsar **`V`** para activar el modo vías.
- [ ] **Construir (Clic Izq.):** Apuntar a una sección con alambre amarillo y hacer clic izquierdo:
  - Completa la **sección 2x2 entera** de inmediato colocando las láminas/cuñas físicas sin notificaciones repetitivas.
- [ ] **Demoler (Clic Der.):** Apuntar a una vía construida y hacer clic derecho:
  - Retira la sección 2x2 completa y sus cuñas al instante.
- [ ] Pulsar **`V`** o **Esc** para salir del modo vías.

### 3.5 Herramienta Unificada de Demolición Cenital (Tecla `3`)
- [ ] **Demolición de Edificios:** Pulsar **`3`** y hacer clic en un edificio: alterna su marca roja de demolición.
- [ ] **Demolición Guiada de Vías:** En modo **`3`**, hacer clic en una celda de vía construida:
  - Mover el cursor a lo largo de la vía: aparece una previsualización **naranja translúcida** (`ViaDemolicionOverlay`).
  - **Esquinas de 90°:** El trazado cubre ambos canales (sección completa de 4 celdas) y sigue fielmente la esquina exterior sin cortes diagonales.
- [ ] **Confirmación:** Hacer **doble clic izquierdo** sobre la previsualización:
  - Se fija un **outline / alambre naranja persistente** en el suelo.
  - Los colonos acuden a demoler y el outline naranja se va retirando celda a celda.

### 3.6 Preferencia de Vías en el Pathfinding de Colonos (`BuscadorRutas`)
- [ ] **Condición de prueba:** Tener un colono en un punto A y asignarle un destino B alejado, con una vía de tierra pisada que conecte ambos sectores rodeando un campo abierto.
- [ ] **Resultado esperado:**
  - El colono **prefiere caminar por la vía de tierra pisada** (coste de paso 3) en lugar de atravesar en línea recta por el terreno natural (coste de paso 8).
  - Si el destino no toca la vía, el colono viaja por la vía hasta el punto más cercano posible y solo pisa terreno natural en el tramo final.

### 3.7 Prioridad de Tráfico y Cesión de Paso en Senderos Angostos
- [ ] **Acción:** Observar colonos cruzándose de frente en una vía de 1 celda de ancho.
- [ ] **Resultado esperado:**
  - El colono con carga prioritaria (comida, combustible, etc.) tiene preferencia.
  - El colono vacío o desocupado se aparta a una casilla lateral para dejarlo pasar.

---

## Bloque 4: Supervisión Cívica, Logística y Gobierno de Obras

> **Mecánicas implementadas:** Topbar responsiva, almacén alfabético, ocupaciones colapsables, población unificada, autoasignación inmediata, prioridades de obra (Normal/Alta/Baja), puestos periféricos y hambruna selectiva.

### 4.1 Barra Superior y Almacén Alfabético
- [ ] **Acción:** Observar la barra superior:
  - Indicadores destacados: Comida, Energía y Recurso Crítico (los minerales raros formateados como `"tierras raras"`).
- [ ] **Acción:** Hacer clic en el botón **Almacén**:
  - Lista de recursos ordenada estrictamente de la **A a la Z** en español.

### 4.2 Ventana de Ocupaciones y Población Unificada
- [ ] **Acción:** Abrir Población y entrar a **Ocupaciones**:
  - 4 categorías colapsables: `▼ Recolección`, `▼ Industria`, `▼ Investigación`, `▼ Energía`.
  - Clic en una cabecera para contraer (`▶`) o expandir (`▼`). Edificios ordenados del más nuevo al más viejo.
- [ ] **Ventana de Población:** Muestra la línea unificada: `Obreros: Total · X empleados · Y desempleados`.

### 4.3 Paginación de Menús con Teclas `Z` y `X` y Ocultamiento de Zonas
- [ ] **Paginación:** En un submenú cenital con más de 10 ítems, pulsar **X** para avanzar de página y **Z** para retroceder o salir.
- [ ] **Zonificación:** Al salir del modo Zonas (`2`), los rectángulos de colores se ocultan limpiamente.

### 4.4 Modales y Cuadros de Diálogo con TemaHUD
- [ ] **Acción:** Provocar una alerta (confirmar demolición o traslado de núcleo).
- [ ] **Resultado esperado:** Ventana modal estilizada con fondo oscuro translúcido y marco definido (sin ventanas grises por defecto).

### 4.5 Prioridades Configurables de Obras (`PanelEdificio`)
- [ ] **Acción:** En cenital, seleccionar un edificio en construcción.
- [ ] **Resultado esperado:** Aparece el botón **`[Prioridad: Normal]`**.
- [ ] **Ciclar:** Clic sucesivo cicla: `Normal` -> `Alta` -> `Baja` -> `Normal`.
- [ ] **Jerarquía estricta de despacho de colonos:**
  1. *Construcción Alta*
  2. *Construcción Normal*
  3. *Demoliciones*
  4. *Tendido de Vías*
  5. *Construcción Baja*

### 4.6 Puestos de Recolección (Mina, Madera, Caza) y Acarreo
- [ ] **Acarreo en puerta:** Acarreadores recogen cajas en la celda frontal `servicio` sin congelarse dentro del edificio.
- [ ] **Retroceso de nivel:** Puestos con obreros en lugar de técnicos ajustan su tasa de producción al rango menor sin bloquearse.

### 4.7 Bajas por Hambruna Selectiva
- [ ] **Caso crítico (0 comida):** Si la hambruna causa bajas cívicas, el orden de desahucio afecta a **especialistas e investigadores** antes que a la base obrera.

---

## Bloque 5: Extracción de Fluidos y Adaptación Industrial

> **Mecánicas implementadas:** Estación de bombeo (agua >= 2), Centro de extracción (escaneo, columna de hierro, stock de crudo restante), almacén de fluidos compartido (6 puertos), refinería con límites 400/600, central termoeléctrica con selector de combustible y universidad interactiva.

### 5.1 Estación de Bombeo (`1` -> `2` -> `5`)
- [ ] **Prueba de agua somera:** Intentar colocarla en agua de 1 bloque de profundidad: rechazada con aviso *"requiere al menos 2 bloques de profundidad de agua bajo su muelle"*.
- [ ] **Prueba en agua profunda ($\ge 2$ bloques):** Colocar con muelle sobre agua profunda y losa en tierra:
  - Aceptada con éxito.
  - Pared en tierra cuenta con el bloque **`puerto_agua_out`** a cota $Y=4$. Extrae agua inagotable con técnicos.

### 5.2 Centro de Extracción Subterráneo (`1` -> `2` -> `6`)
- [ ] **Prueba sin depósito:** Mover el cursor sobre terreno sin pozo: rechaza con *"No se detecta depósito subterráneo de agua o crudo"*.
- [ ] **Prueba con pozo detectado:** Mover sobre una bolsa de crudo o agua subterránea:
  - Huella válida. La ficha técnica añade el costo dinámico en `estructura_hierro` según la profundidad del pozo.
- [ ] **Panel de información:** Clic sobre el Centro de Extracción en modo Ver (`Esc`):
  - Indica: `Crudo restante en pozo: X bloques` (o `Pozo de agua (inagotable)`).
  - Al operar, agota bloques físicos de crudo uno a uno en tiempo real.

### 5.3 Puesto Almacén de Fluidos (`1` -> `3` -> `8`)
- [ ] **Construcción:** Construir un `almacen` (5x5 de piedra).
- [ ] **Puertos exteriores:**
  - Pared izquierda: entradas `1` (agua), `3` (crudo), `5` (combustible).
  - Pared derecha: salidas `2` (agua), `4` (crudo), `6` (combustible).
- [ ] **Desplegables en PanelPuesto:** Al seleccionarlo, los puertos aparecen organizados en **desplegables colapsables por recurso** (Agua, Crudo, Combustible) con círculos de estado (`⚪`, `🟢`, `🔴`). Todos los almacenes comparten un depósito global de fluidos instantáneo.

### 5.4 Refinería Petrolera: Límites Particionados de Stock (400 Crudo / 600 Combustible)
- [ ] **Construcción:** Construir una `refineria_petrolera`.
- [ ] **Puertos:** Dispone de `puerto_crudo_in` y `puerto_combustible_out` (0 acarreadores de fluidos).
- [ ] **Límite de capacidad:** Conectar crudo por tubería:
  - El stock local de crudo se llena hasta un **máximo de 400 unidades (40%)**.
  - Detiene la entrada de más crudo garantizando siempre **600 espacios libres (60%)** para la producción de combustible.

### 5.5 Productor de Combustible
- [ ] **Construcción:** Construir un `productor_combustible`.
- [ ] **Puertos y logística:** Cuenta con `puerto_agua_in` y `puerto_combustible_out`. Sus acarreadores solo transportan carbón sólido.

### 5.6 Central Termoeléctrica: Selector de Combustible y Acarreo de Carbón
- [ ] **Selector:** En `PanelPuesto`, interactuar con los botones **`[Carbón]`**, **`[Combustible]`** y **`[Crudo]`**.
- [ ] **Acarreo en modo Carbón:** Al configurar en `Carbón` y contratar acarreadores:
  - Los acarreadores acuden al núcleo urbano o almacenes, cargan carbón y lo llevan a la central termoeléctrica para alimentarla.
- [ ] **Modos Crudo / Combustible:** En estos modos no admite acarreadores (alimentación exclusiva por ductos).

### 5.7 Universidad Interactiva: Inicio, Aceleración, Pausa y Cancelación con Reembolso
- [ ] **Inicio manual:** Clic en la Universidad en modo Ver: muestra el botón **`[Iniciar Investigación]`** (no arranca sola).
  - Clic abre diálogo modal con los costos en hierro y madera.
- [ ] **Aceleración:** Asignar más investigadores presentes incrementa la velocidad de avance de la cohorte.
- [ ] **Pausar / Reanudar:** Botón `[Pausar]` congela el avance y cambia a `[Reanudar]`.
- [ ] **Cancelar con reembolso:** Pulsar `[Cancelar]`: cuadro de confirmación que **reembolsa íntegramente los recursos** gastados.

---

## Bloque 6: Red de Canalizaciones Elevadas (Acueductos y Tuberías)

> **Mecánicas implementadas:** Menú 1-6 con etiquetas legibles, cota Y+4 con paso inferior de colonos y vías, columnas cada 5 bloques, cruces a desnivel con doble columna a Y+6 y 1 bloque libre, vigas continuas sin z-fighting, conexión a puertos, extensión desde redes desconectadas/derrame, demolición limpia y spreading de derrames.

### 6.1 Activación y Ficha Técnica Legible (`1` -> `6`)
- [ ] **Acción:** En cenital, pulsar **1** (Construir) -> **6** (Ductos) o hacer clic directo en el botón del HUD.
- [ ] **Seleccionar:** Elegir **1** (**Acueducto**) o **2** (**Tubería**).
- [ ] **Ficha técnica:** La tarjeta muestra nombres en lenguaje natural (ej. `1 Bloque de acero`, `1 Estructura de hierro`, nunca claves como `bloque_acero`).

### 6.2 Cota Elevada ($Y_{suelo}+4$) y Libre Circulación Terrestre Inferior
- [ ] **Trazado:** Fijar inicio con clic izq., extender varios bloques y confirmar con doble clic izq.
- [ ] **Resultado:** La canalización se eleva a 3 bloques de despeje sobre el suelo ($Y = Y_{suelo} + 4$).
- [ ] **Paso a pie:** Caminar con el avatar por debajo: el vano inferior está totalmente libre.
- [ ] **Paso de vías terrestres:** Activar trazador de vías (`1-5-1`) y trazar una vía que pase por debajo de la canalización:
  - La vía se construye en línea recta sin obstáculos ni impedimentos de altura.

### 6.3 Columnas cada 5 Bloques, Esquinas y Malla sin Z-Fighting
- [ ] **Columnas de vano 4:** Trazar un ducto recto de $\ge 11$ bloques:
  - Coloca columnas en bloque 0, bloque 5 y bloque 10 (dejando exactamente 4 celdas libres entre pilares).
- [ ] **Esquinas de 90°:** Trazar una "L": en el vértice del quiebre se coloca una columna obligatoria y un bloque de esquina orientado.
- [ ] **Calidad de malla:**
  - La textura de la canalización se muestra derecha y bien iluminada (normales hacia el exterior).
  - La unión entre las vigas continuas y los cubos de soporte sobre las columnas no presenta z-fighting ni parpadeos de caras coplanares.

### 6.4 Cruces a Desnivel de Ductos (Doble Columna a $Y=6$ y Aire Libre)
- [ ] **Acción:** Tener un ducto existente A (ej. Acueducto Norte-Sur a $Y = Y_{suelo} + 4$).
- [ ] **Acción:** Trazar un nuevo ducto B (ej. Tubería Este-Oeste) cruzando perpendicularmente sobre A.
- [ ] **Resultado esperado:**
  - En las celdas inmediatamente anterior y posterior al cruce, se levantan **dos columnas nuevas de soporte de 6 bloques de altura** (hasta $Y = Y_{suelo} + 5$).
  - El tramo superior cruza horizontalmente a **$Y = Y_{suelo} + 6$**.
  - Entre el ducto inferior y el superior queda **1 bloque completo de aire libre** ($Y = Y_{suelo} + 5$).
  - Ambas canalizaciones quedan físicamente aisladas sin tocarse.

### 6.5 Conexión a Puertos de Edificios
- [ ] **Acción:** Iniciar un trazo haciendo clic en la celda exterior frente a un puerto de salida (ej. Estación de Bombeo).
  - La primera celda toma la altura del puerto sin columna debajo; la primera columna se sitúa a 5 bloques.
- [ ] **Acción:** Conducir el extremo hasta el puerto de entrada de una refinería o almacén y confirmar:
  - La red se sella y ambos puertos pasan a estar conectados a la red física.

### 6.6 Inspección Cenital de Ductos (`PanelCanalizacion`) y Demolición Limpia
- [ ] **Inspección:** En modo Ver (`Esc`), hacer clic en cualquier bloque de la canalización:
  - Se abre `PanelCanalizacion` mostrando: Tipo, Recurso, Longitud, Edificios Conectados y Estado.
- [ ] **Demolición:** Clic en *"Demoler canalización"* y confirmar:
  - La canalización se elimina y se reembolsan los materiales.
  - **Sin bloque fantasma:** La celda exterior frente al puerto del edificio queda completamente limpia y vacía; un nuevo trazado hacia ese puerto lo reconoce inmediatamente sin obstáculos.

### 6.7 Reconstrucción y Extensión desde Columnas Desconectadas o en Derrame
- [ ] **Acción:** Tener una tubería incompleta o rota cuyo estado sea `Desconectado` o `Derrame`.
- [ ] **Acción:** Activar la herramienta de tuberías y hacer clic sobre una columna existente de esa red.
- [ ] **Resultado esperado:**
  - El nuevo trazado se engancha y pasa a formar parte de la red existente.
- [ ] **Acción:** Conectar el nuevo extremo a un edificio receptor compatible y confirmar:
  - La red se sella, el puerto pasa a **`🟢 Conectado`** y el derrame activo se cancela y limpia de inmediato.

### 6.8 Simulación de Flujo y Mecánica de Derrame Físico (Spill)
- [ ] **Flujo Conectado:** Bombeo desde Estación de Bombeo conectada a Almacén:
  - El agua se deposita automáticamente en el stock del Almacén cada hora sin acarreadores.
- [ ] **Derrame por Extremo Abierto:** Conectar un extractor a una tubería que termine en el aire sin receptor:
  - En el siguiente tick horario, el puerto pasa a **`🔴 Derrame`** y el HUD emite una alerta.
  - En el extremo abierto se engendra un bloque físico de líquido (`agua` o `crudo`) que cae y **escurre por el relieve con spreading** (el crudo avanza con viscosidad hasta 3 celdas horizontales).

---

## Bloque 7: Balance y Supervisión Energética (`VentanaEnergia`)

> **Mecánicas implementadas:** Botón interactivo "Energía" en BarraSuperior, modal de balance energético `VentanaEnergia` con desglose de capacidad, entregada, demanda, lista de centrales con combustible, lista de consumidores y teletransporte de cámara.

### 7.1 Botón "Energía" en la Barra Superior
- [ ] **Acción:** En la barra superior del HUD, mover el cursor sobre el texto de **Energía**.
- [ ] **Resultado esperado:**
  - El elemento es un **botón interactivo** clicable (con estilo idéntico a `Almacén` y `Población`).
- [ ] **Acción:** Hacer clic sobre el botón de Energía.
- [ ] **Resultado esperado:**
  - Se abre la ventana modal **`VentanaEnergia`** estilizada con `TemaHUD`.

### 7.2 Resumen Global de la Red Eléctrica
- [ ] **Acción:** Observar la cabecera de `VentanaEnergia`.
- [ ] **Resultado esperado:**
  - Métricas claras del sistema:
    - **Capacidad Total Generada:** (E/h).
    - **Energía Entregada:** (E/h).
    - **Demanda Total de la Ciudad:** (E/h).
    - **Balance:** `Superávit (100%)` o `Déficit (-X%)` en color rojo si la demanda supera la capacidad.

### 7.3 Desglose de Centrales Generadoras y Reservas
- [ ] **Acción:** Revisar la sección de **Fuentes Generadoras**:
  - Lista cada Central Termoeléctrica de la colonia mostrando:
    - Combustible activo (`Carbón`, `Combustible` o `Crudo`).
    - Reservas locales de combustible restante en su depósito.
    - Capacidad aportada a la red.

### 7.4 Desglose de Consumidores y Demanda
- [ ] **Acción:** Revisar la sección de **Edificios Consumidores**:
  - Lista cada edificio industrial, refinería o universidad que requiera electricidad.
  - Estado de conexión (`Conectado`, `Sin conexión`, `Déficit`).
  - Demanda individual en E/h y energía recibida.

### 7.5 Teletransporte de Cámara al Hacer Clic en Edificios
- [ ] **Acción:** Hacer clic izquierdo sobre cualquier edificio de la lista (generador o consumidor).
- [ ] **Resultado esperado:**
  - La cámara cenital vuela y se centra suavemente sobre las coordenadas de ese edificio en el mapa, facilitando su localización inmediata para tareas de mantenimiento o abastecimiento.

---

## Tabla de Resumen y Aprobación Rápida

| Bloque | Característica comprobada | Estado (OK / Fallo) | Notas del tester |
| :--- | :--- | :---: | :--- |
| **1.1** | Viscosidad pesada en crudo (0.20), inmersión y consumo de oxígeno | | |
| **1.2** | Drenado y secado de líquidos al colocar bloques sólidos | | |
| **1.3** | Lámpara omnidireccional con tecla `L`, PanelLampara, eléctrica/térmica y recarga | | |
| **1.4** | Ventana de oxígeno apilada bajo la lámpara al sumergirse | | |
| **1.5** | VentanaBaul centrada (`320x260`), scroll y cierre rápido con `E` o `Esc` | | |
| **2.1** | Puerta obligatoria únicamente en planta baja (Piso 1 sin puerta exterior) | | |
| **2.2** | Nombrado automático de blueprints `Residencia [camas]x[baules]` y 5 slots 3D | | |
| **2.3** | 1ª Residencia nace con `Colonizable: SÍ` y capacidad correcta por cama | | |
| **2.4** | Remodelación con `Shift+B` en puerta y cenital (edición libre y reubicación) | | |
| **2.5** | Estado "Sin techo" y reincorporación automática al construir camas | | |
| **2.6** | Edificios adosados (pared con pared): detención de flood-fill en muros de vecino | | |
| **2.7** | 2ª Residencia en adelante como buffers (`Colonizable: NO 24h`) y toggle manual | | |
| **2.8** | Remodelación de Núcleo Urbano sin desalojo y traslado de sede (gracia 5h) | | |
| **3.1** | Trazador de vías cenital con iconos SVG, ficha técnica y cancelación limpia | | |
| **3.2** | Nivelación y despeje compartidos entre puertas enfrentadas en una calle | | |
| **3.3** | Tendido progresivo de vías por colonos (`ViaObraOverlay` amarillo consecutivo) | | |
| **3.4** | Modo interacción manual de vías en 1ª persona (`V`): construir/demoler 2x2 | | |
| **3.5** | Demolición cenital unificada (`3`): Dijkstra en esquinas de 90° y outline naranja | | |
| **3.6** | Preferencia de vías en pathfinding (`BuscadorRutas`: vía coste 3 vs campo 8) | | |
| **3.7** | Cesión de paso y prioridad de tráfico en senderos angostos de 1 celda | | |
| **4.1** | Topbar responsiva (minerales como "tierras raras") y Almacén alfabético (A-Z) | | |
| **4.2** | Ventana de Ocupaciones colapsable (▼/▶) y Población unificada de obreros | | |
| **4.3** | Paginación con `Z`/`X` y ocultamiento limpio de overlays de zonas | | |
| **4.4** | Modales y cuadros de diálogo integrados con `TemaHUD` | | |
| **4.5** | Prioridades de obras (`PanelEdificio` Normal/Alta/Baja) y jerarquía de tareas | | |
| **4.6** | Puestos periféricos: acarreo en celda de servicio frontal y retroceso de nivel | | |
| **4.7** | Hambruna selectiva: especialistas e investigadores caen antes que obreros | | |
| **5.1** | Estación de bombeo: validación de agua $\ge 2$, muelle y `puerto_agua_out` | | |
| **5.2** | Centro de extracción: detección de pozo, columna de hierro y stock restante | | |
| **5.3** | Almacén de fluidos (5x5 con 6 puertos agrupados en desplegables en panel) | | |
| **5.4** | Refinería petrolera: puertos sin acarreo y stock particionado (400 crudo / 600 comb.) | | |
| **5.5** | Productor de combustible: puertos de fluidos y acarreo exclusivo de carbón | | |
| **5.6** | Central termoeléctrica: selector de combustible y acarreo entrante de carbón | | |
| **5.7** | Universidad interactiva: inicio manual, aceleración, pausa y cancelación con reembolso | | |
| **6.1** | Herramienta de ductos (`1-6-1`/`1-6-2`) con etiquetas legibles y costos dinámicos | | |
| **6.2** | Cota elevada $Y_{suelo}+4$ con libre paso de colonos y vías terrestres por debajo | | |
| **6.3** | Columnas cada 5 bloques (vano 4), esquinas de quiebre y mallas sin z-fighting | | |
| **6.4** | Cruces a desnivel de ductos: doble columna lateral a $Y=6$ y aire libre intermedio | | |
| **6.5** | Conexión automática a puertos de edificios a cota $Y=4$ | | |
| **6.6** | `PanelCanalizacion` y demolición limpia sin bloques fantasma en puertos | | |
| **6.7** | Reconstrucción y extensión desde columnas en estado Desconectado o Derrame | | |
| **6.8** | Simulación de flujo y derrames físicos con spreading en extremos abiertos | | |
| **7.1** | Botón interactivo "Energía" en la barra superior | | |
| **7.2** | `VentanaEnergia`: balance global (Capacidad, Entregada, Demanda, Déficit) | | |
| **7.3** | Desglose de fuentes generadoras (Centrales termoeléctricas y combustible) | | |
| **7.4** | Desglose de consumidores (estado de conexión y consumo individual) | | |
| **7.5** | Teletransporte suave de cámara al hacer clic sobre un edificio en la lista | | |

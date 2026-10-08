# Guión de Verificaciones en Vivo (Live QA Script) — Craft to Nation

Este documento es un guión de pruebas manuales paso a paso para comprobar en vivo, directamente dentro del juego en ejecución (**F5** en Godot), que las funciones, correcciones y ajustes de balance introducidos en los últimos commits están operando correctamente.

---

## 0. Preparativos y Controles Rápidos

### Iniciar el entorno
1. Abrir el proyecto en Godot 4.7 y pulsar **F5** (o ejecutar la escena principal `Main.tscn`).
2. Comprobar que el avatar aparece en el mundo y que la barra superior del HUD es visible.

### Atajos de teclado clave

#### Controles Generales y Primera Persona
| Tecla / Acción | Función |
| :--- | :--- |
| **C** | Alternar entre cámara en **1ª persona** y **Cámara Cenital** (con vuelo y transición animada). |
| **W, A, S, D** | Movimiento del avatar (1ª persona) o paneo horizontal del mapa sobre plano X/Z (cenital). |
| **E** | Interactuar en 1ª persona (abrir/cerrar puertas y baúles) / Cerrar ventanas emergentes activas. |
| **G** | Alternar modo deconstrucción / demolición manual (1ª persona). |
| **V** | Alternar modo interacción con vías: clic izq. construir, clic der. demoler (1ª persona). |
| **B / Shift + B** | Declarar estructura (**B**) / Iniciar remodelación (**Shift + B**) apuntando a la puerta (1ª persona). |
| **Esc** | Cerrar ventana activa, salir de modo vías/deconstrucción, o volver al modo neutro "Ver" en cenital. |

#### Controles de Cámara Cenital (Navegación Orbital)
| Tecla / Acción | Función |
| :--- | :--- |
| **Q / E** | **Rotación orbital:** Gira la vista hacia la izquierda (**Q**) o hacia la derecha (**E**) manteniendo la altura. |
| **Rueda del ratón (Scroll)** | **Zoom:** Acerca o aleja la cámara oblicuamente respecto al punto focal. |
| **Ctrl + W / Ctrl + S** | **Inclinación:** Modifica el ángulo de inclinación vertical de la cámara (sube/baja la órbita sobre la esfera). |
| **Shift + W / Shift + S** | **Altura vertical:** Sube (**Shift+W**) o baja (**Shift+S**) directamente la cota de la cámara sin alterar la inclinación. |
| **1, 2, 3...** | **Menú numérico cenital:** **1** Construir (**1** Residencial, **5** Vías...), **2** Zonificar, **3** Demoler. |
| **Z / X** | Retroceder (**Z**) / avanzar página (**X**) en submenús jerárquicos cenitales (o salir de submenú con Z). |
| **Ctrl + Scroll** | Rotar previsualización de blueprint o puesto (giros de 90° durante colocación). |
| **Clic izquierdo** | Fijar punto de vía, colocar estructura o interactuar. |
| **Doble clic izq.** | Confirmar y finalizar trazado de vía. |
| **Clic derecho** | Cancelar tramo acumulado / cancelar modo de colocación. |

---

## Bloque 1: Trazador de Vías, Cancelación Limpia e Iconografía SVG

> **Commits relacionados:** `cabbd9b` (iconos vectoriales en HUD), `3e84e5b` (limpieza de tramos con clic derecho).

### 1.1 Verificación de iconos en la tarjeta contextual
- [ ] **Acción:** Presionar **C** para cambiar a la vista cenital. Luego pulsar **1** (Construir) y **5** (Vías) —o hacer clic en Construir > Vías— para activar el trazador de vías.
- [ ] **Observar:** En la esquina inferior izquierda debe mostrarse la tarjeta contextual de "Trazar vía".
- [ ] **Resultado esperado:**
  - Las acciones deben estar desglosadas con iconos vectoriales reales:
    - `[Icono Clic Izq.] FIJAR PUNTO`
    - `[Icono Clic Izq. (x2)] CONFIRMAR`
    - `[Icono Clic Der.] CANCELAR`
    - `[Esc] SALIR`
  - Ningún texto debe mostrar etiquetas crudas como `(clic izq.)` o `(clic der.)` sin formatear.

### 1.2 Cancelación limpia de tramos acumulados con Clic Derecho
- [ ] **Acción:** Con el modo de vías activo, hacer un clic izquierdo en un punto del terreno y luego otro clic izquierdo a unos metros de distancia para generar un tramo fijo acumulado. La previsualización de la vía debe extenderse hacia el cursor.
- [ ] **Acción:** Presionar **Clic Derecho**.
- [ ] **Resultado esperado:**
  - El trazado se cancela de inmediato: se eliminan los tramos acumulados (`_tramos_fijos`), se borra la malla fantasma/overlay de la vía y se resetea la caché interna.
  - La consola debe imprimir: `Trazado de vía cancelado.`
  - No deben quedar baldosas fantasmas ni líneas residuales pegadas al cursor.
- [ ] **Acción adicional:** Pulsar **Esc** y verificar que sale del modo vía devolviendo la cámara cenital al estado neutro ("Ver").

### 1.3 Ficha técnica dinámica en la tarjeta de vías
- [ ] **Acción:** En modo vías (Construir > Vías), mover el cursor sobre el terreno para alargar o acortar el tramo de vía previsualizado.
- [ ] **Resultado esperado:**
  - En la tarjeta contextual debe verse la ficha técnica formateada con las propiedades de la vía:
    - **Nombre:** `Vía de tierra pisada`
    - **Recursos:** `N/A` (o costo acumulado según celdas proyectadas)
    - **Velocidad:** `+35%`
    - **Transmisión de energía:** `No`
    - **Tránsito vehicular:** `No`
  - La cantidad de celdas y costos deben actualizarse en vivo conforme el cursor cambia la longitud del tramo.

### 1.4 Limpieza de la tarjeta contextual al salir o deseleccionar herramientas
- [ ] **Acción:** Entrar a cualquier herramienta (ej. Trazar vía mediante Construir > Vías, o seleccionar un puesto o blueprint en Construir) para que se muestre su ficha técnica / tarjeta contextual.
- [ ] **Acción:** Deseleccionar la herramienta o salir de ella (pulsando **Esc**, haciendo clic en otra categoría, o pulsando **Z** para volver a la lista de categorías).
- [ ] **Resultado esperado:**
  - La tarjeta contextual y su ficha técnica desaparecen inmediatamente de la pantalla.
  - No queda información residual ni fichas técnicas obsoletas de herramientas anteriores fijas en el HUD.

---

## Bloque 2: Flexibilización de Blueprints Residenciales y Memoria

> **Commits relacionados:** `aed909d` (puerta obligatoria solo en 1er piso), `841e254` (nombre Residencia XxY), `a39b867` (5 slots con miniaturas).

### 2.1 Puerta obligatoria solo en planta baja (Piso 1 / Nivel 0)
- [ ] **Acción:** Entrar a 1ª persona (**C**) y levantar una estructura de 2 plantas:
  - **Planta baja (Nivel 0):** Cerrada, con al menos 1 puerta, 1 ventana, 1 cama y 1 baúl.
  - **Planta alta (Nivel 1):** Con paredes, suelo, techo, escaleras de acceso y al menos 1 ventana, **pero sin ninguna puerta que dé al exterior**.
- [ ] **Acción:** Declarar el edificio residencial.
- [ ] **Resultado esperado:**
  - El validador (`BlueprintValidator`) **debe aceptar el edificio con éxito**.
  - No debe lanzar el antiguo error *"Falta una puerta en el 2do piso"*. La exigencia de puerta exterior aplica estrictamente al nivel 0.

### 2.2 Nombres descriptivos automáticos
- [ ] **Acción:** Declarar un edificio con, por ejemplo, 2 camas y 1 baúl (o 3 camas y 2 baúles).
- [ ] **Resultado esperado:**
  - El blueprint guardado debe nombrarse automáticamente siguiendo la regla: `Residencia [camas]x[baules]` (por ejemplo: `Residencia 2x1` o `Residencia 3x2`).
  - No debe aparecer el texto genérico `"Edificio residencial"` ni `"Estructura_Detectada"`.

### 2.3 Memoria de 5 blueprints residenciales con miniaturas
- [ ] **Acción:** Pasar a vista cenital (**C**) y pulsar **1** (Construir) -> **1** (Residencial), o hacer clic en los botones correspondientes.
- [ ] **Resultado esperado:**
  - Se listan los blueprints guardados (hasta 5 slots, numerados del 1 al 5).
  - Cada botón debe renderizar una miniatura isométrica 3D real de la vivienda correspondiente.
- [ ] **Prueba de descarte FIFO:** Si se declara un 6.º blueprint, comprobar que el más nuevo pasa al slot 1 y el más antiguo (6.º) es descartado limpiamente de la memoria.

### 2.4 Iconos en tarjeta de previsualización de Blueprint
- [ ] **Acción:** Seleccionar un blueprint residencial para colocar en el mapa.
- [ ] **Resultado esperado:**
  - La tarjeta contextual inferior debe mostrar:
    - `[Ctrl] [Icono Scroll] ROTAR`
    - `[Icono Clic Izq.] COLOCAR`
  - Al girar la rueda con Ctrl presionado, el ghost rota en pasos de 90° de manera fluida.

---

## Bloque 3: Nivelación Compartida y Puertas Enfrentadas

> **Commits relacionados:** `037e7bf` y `626de41` (nivelación por cota de puerta guía y frente compartido).

### 3.1 Edificios enfrentados en una misma calle
- [ ] **Acción:** Colocar o tener un edificio ya construido en una ladera suave o terreno con desnivel.
- [ ] **Acción:** En modo cenital, seleccionar otro edificio o blueprint y colocarlo justo enfrente del primero, de modo que sus puertas queden enfrentadas a 2 o 3 bloques de distancia (simulando una calle entre ambos).
- [ ] **Resultado esperado:**
  - La previsualización de nivelación calcula la base $Y$ tomando como referencia la cota frontal de la puerta existente.
  - El terreno compartido entre ambas puertas se nivela a la misma altura sin crear saltos de pendiente, escalones inaccesibles ni rechazos por invasión de despeje frontal.

---

## Bloque 4: Interacción y Cierre Rápido de Baúl (`VentanaBaul`)

> **Commit relacionado:** `468b82e` (cerrar ventana de baúl pulsando E o Escape).

### 4.1 Apertura, centrado perfecto y dimensiones de VentanaBaul
- [ ] **Acción:** En 1ª persona, caminar hasta el baúl de un puesto de recolección construido (mina, maderero, caza, etc.).
- [ ] **Acción:** Apuntar la mira hacia el baúl y pulsar **E**.
- [ ] **Resultado esperado:**
  - Se abre limpiamente la `VentanaBaul` mostrando los recursos del depósito local y botones de transferencia.
  - La ventana **aparece perfectamente centrada** en la pantalla (no desviada hacia la esquina superior izquierda sobre la mira).
  - Sus dimensiones son fijas y acotadas (`320x260`): no desborda la pantalla ni la barra superior ni la hotbar en resoluciones pequeñas o ventanas reducidas.
  - El título `"BAÚL"` con la `"X"` permanece fijo arriba; el botón `"Extraer todo"` permanece fijo abajo.
  - Si hay múltiples tipos de recursos, la lista central se desplaza mediante un `ScrollContainer` con barra de scroll vertical, sin colisionar con los botones `+`.
  - La ventana permanece abierta y el cursor del ratón queda libre (no se cierra en el mismo fotograma por propagación de tecla).

### 4.2 Cierre rápido con E o Escape y baúl sin depósito
- [ ] **Acción:** Sin hacer clic en ningún botón de cerrar, pulsar nuevamente la tecla **E** (o presionar **Escape**).
- [ ] **Resultado esperado:**
  - La ventana se cierra inmediatamente.
  - El control de la cámara en 1ª persona y el bloqueo del cursor se restablecen al instante.
- [ ] **Acción adicional (baúl sin puesto):** Si se apunta a un baúl decorativo o residencial colocado a mano que no pertenece a un puesto activo y se pulsa **E**, el HUD notifica: *"Este baúl no pertenece a un puesto de trabajo con depósito activo."*

---

## Bloque 5: HUD Responsivo, Almacén Alfabético y Ocupaciones Categorizadas

> **Commits relacionados:** `4bfe858` (barra superior responsiva, almacén alfabético, ocupaciones por categorías), `b4f4b4f` (formateo de tierras raras).

### 5.1 Barra superior y recursos destacados
- [ ] **Acción:** Observar la barra superior en la parte superior de la pantalla.
- [ ] **Resultado esperado:**
  - El botón **Almacén** se presenta en formato compacto y limpio.
  - Se visualizan con claridad los tres indicadores principales:
    - **Comida** (cantidad y tasa por hora).
    - **Energía** (entregada / demanda y balance con color normal o rojo si hay déficit).
    - **Recurso Crítico** (el recurso con agotamiento más próximo en horas de consumo).
  - Si hay reservas o prospección de minerales raros, deben mostrarse formateados como `"tierras raras"` (con espacio, nunca con guión bajo `tierras_raras`).
- [ ] **Prueba de responsividad:** Cambiar el tamaño de la ventana del juego o probar diferentes resoluciones; los elementos de la barra deben reorganizarse sin desbordar la pantalla ni cortarse.

### 5.2 Ventana de Almacén alfabética
- [ ] **Acción:** Hacer clic sobre el botón **Almacén** en la barra superior.
- [ ] **Resultado esperado:**
  - La lista de recursos desplegada está ordenada de forma estrictamente **alfabética de la A a la Z** según su nombre en español (ej. *Acero*, *Agua*, *Carbón*, *Comida*, *Madera*, *Piedra*, etc.).
  - No debe haber orden arbitrario o por orden de inserción interna.

### 5.3 Ventana de Ocupaciones agrupada por categorías colapsables
- [ ] **Acción:** Hacer clic en el botón de **Población** y abrir la subventana de **Ocupaciones**.
- [ ] **Resultado esperado:**
  - Los puestos de trabajo se dividen en 4 categorías:
    1. **Recolección** (Mina, Caza y recolección, Maderero, Pesca).
    2. **Industria** (Siderúrgica, Refinerías, Aserradero, Carbonera, Combustible).
    3. **Investigación** (Escuela técnica, Escuela de especialistas, Universidad).
    4. **Energía** (Central termoeléctrica).
  - Cada categoría posee una cabecera con flecha indicadora y cantidad de edificios: `▼ Recolección (N)`.
  - Al hacer clic sobre una cabecera, la categoría se contrae cambiando a `▶` y ocultando sus filas.
  - Los edificios dentro de cada categoría están ordenados cronológicamente al revés (el edificio más recientemente construido aparece arriba).

### 5.4 Ventana de Población: línea unificada de Obreros
- [ ] **Acción:** Inspeccionar la ventana de **Población**.
- [ ] **Resultado esperado:**
  - La categoría de obreros y desempleados aparece unificada bajo una única línea clara:
    - `Obreros: Total · X empleados · Y desempleados`
  - Ya no aparece una fila redundante y separada de desempleados que confunda el censo.

---

## Bloque 6: Logística, Puestos y Colonos

> **Commits relacionados:** `45668bb` (acarreo sin congelamiento y recogida en puerta), `fe29e97` (prioridades con cesión de paso y retroceso de nivel), `41e7607` (autoasignación a obras), `8e60dc6` (tope de 4 obreros).

### 6.1 Acarreo fluido en puestos llenos y recogida en celda de servicio
- [ ] **Acción:** Asignar recolectores y acarreadores a un puesto (por ejemplo, Caza y Recolección o Mina). Dejar que el baúl del puesto acumule recursos.
- [ ] **Resultado esperado:**
  - Los acarreadores acuden a la **celda frontal de servicio** (`servicio`) a recoger la carga.
  - Ningún acarreador se queda congelado ni bloquea a los recolectores dentro del edificio.
  - Transportan periódicamente las cajas/cargas hacia el almacén central del núcleo urbano.

### 6.2 Prioridad de tráfico y cesión de paso en vía de 1 casilla
- [ ] **Acción:** Trazar un sendero o camino angosto de 1 solo bloque entre un puesto alejado y la base. Observar a los colonos cruzándose de frente.
- [ ] **Resultado esperado:**
  - Un acarreador que transporta carga crítica (comida, combustible, etc.) tiene prioridad de paso.
  - El colono sin carga o el colono ocioso se aparta a una casilla lateral o retrocede momentáneamente para permitir el tránsito del colono cargado, evitando atascos eternos cara a cara.

### 6.3 Retroceso de nivel en puestos
- [ ] **Acción:** En un puesto que requiera o admita diferentes niveles de trabajadores (ej. técnicos vs obreros simples), asignar personal de menor categoría.
- [ ] **Resultado esperado:**
  - El sistema permite el retroceso de nivel de operación (`Economia.admite_rol`), ajustando las tasas de extracción al rango actual del personal sin bloquear la producción ni dar error de rol no admitido.

### 6.4 Autoasignación inmediata a obras y límite de cuadrilla (máx. 4)
- [ ] **Acción:** Teniendo colonos desempleados/ociosos en la ciudad, emplazar una nueva obra de construcción o marcar un bloque/edificio para demolición.
- [ ] **Resultado esperado:**
  - Los obreros ociosos reaccionan de inmediato y se dirigen a trabajar a la obra sin esperar al cambio de hora o tick largo.
  - Si hay más de 4 obreros disponibles, comprobar que **como máximo 4 obreros** trabajan en la misma obra al mismo tiempo; el resto permanece en espera de otras tareas.

---

## Bloque 7: Gestión de Residencia y Traslado de Núcleo Urbano

> **Commits relacionados:** `105cc3c` (panel residencial y traslado de núcleo), `b4f4b4f` (hambruna ampliada).

### 7.1 Panel de información residencial
- [ ] **Acción:** En vista cenital (**C**), hacer clic sobre un edificio residencial ya construido.
- [ ] **Resultado esperado:**
  - Se abre el `PanelEdificio` mostrando:
    - Título del edificio (`Edificio residencial` o `Núcleo urbano`).
    - Recuento de Camas, Baúles y Residentes por categoría.
    - Si es el núcleo urbano actual, el botón "Demoler" está deshabilitado u oculto.

### 7.2 Traslado de núcleo urbano con período de gracia
- [ ] **Acción:** Seleccionar una residencia secundaria construida y pulsar el botón **"Asignar como núcleo urbano"**.
- [ ] **Resultado esperado:**
  - Aparece una ventana modal de advertencia estilizada con `TemaHUD`, informando del traslado y sus implicaciones.
  - Al confirmar, se inicia el proceso de mudanza (con período de gracia de 5 horas de juego).
  - El ancla de influencia de la ciudad se reubica al nuevo núcleo sin pérdida de existencias ni corrupción de datos.

### 7.3 Bajas por hambruna en sectores especializados
- [ ] **Condición de prueba (caso crítico):** Ciudad con reservas de comida en 0 y población con especialistas o investigadores activos.
- [ ] **Resultado esperado:**
  - Si la falta de comida persiste hasta provocar bajas por hambruna, el orden de desahucio/bajas (`ORDEN_BAJAS_HAMBRUNA`) debe afectar a **especialistas** e **investigadores** antes de diezmar la base obrera o a los ciudadanos comunes, protegiendo la subsistencia mínima de la colonia.

---

## Bloque 8: Paginación de Menús con Teclado (`Z` / `X`) y Visibilidad de Zonas

> **Commit relacionado:** `19d84e8` (paginación con ZX y ocultamiento de zonas).

### 8.1 Paginación con Z y X
- [ ] **Acción:** En la vista cenital, abrir un menú que contenga más de 10 elementos (o submenús navegables).
- [ ] **Acción:** Presionar la tecla **X** para avanzar a la página 2.
- [ ] **Resultado esperado:** El menú pasa a la siguiente página mostrando los ítems 11 en adelante con las teclas 1 a 0 remapeadas a esos ítems.
- [ ] **Acción:** Presionar la tecla **Z**.
- [ ] **Resultado esperado:** Retrocede a la página anterior. Si se pulsa **Z** estando en la página 1 de un submenú, regresa al menú de nivel superior.

### 8.2 Ocultamiento limpio del overlay de Zonas
- [ ] **Acción:** Entrar a la herramienta de zonificación (Zonas A / B). Los colores semitransparentes de las zonas deben ser visibles.
- [ ] **Acción:** Salir del modo de zonas (pulsando **Esc** o seleccionando **Ver** / **Trazar vía**).
- [ ] **Resultado esperado:**
  - Los rectángulos coloreados de las zonas A y B se ocultan por completo, dejando despejada la vista del mapa.
  - Solo se mantiene visible el contorno/área de influencia cuando la acción en curso lo requiere.

### 8.3 Zonificación: instrucciones operativas con iconos de ratón
- [ ] **Acción:** En modo cenital (**C**), entrar a la herramienta de zonificación (tecla **2** en el menú principal o botón Zonificar).
- [ ] **Resultado esperado:**
  - La tarjeta contextual inferior ya no muestra atajos numéricos obsoletos `[1]`, `[2]`, `[3]`, `[Esc]`, sino las instrucciones de acción con iconos vectoriales:
    - `[Icono Clic Izq.] FIJAR ESQUINA`
    - `[Icono Clic Der.] CANCELAR`
    - `[Esc] SALIR`
  - Al hacer clic izquierdo en el primer vértice de la zona para empezar a arrastrar:
    - La tarjeta se actualiza en tiempo real a: `[Icono Clic Izq.] CONFIRMAR ÁREA`
  - Al pulsar Clic Derecho para cancelar el área o al confirmar con clic izquierdo:
    - La tarjeta vuelve de inmediato a `[Icono Clic Izq.] FIJAR ESQUINA`.

---

## Bloque 9: Ventanas Modales y Alertas con `TemaHUD`

> **Commit relacionado:** `037e7bf` (estilizado de ventanas de alerta).

### 9.1 Aspecto coherente de cuadros de diálogo
- [ ] **Acción:** Provocar una alerta o diálogo modal en el juego (ej. confirmar demolición de un edificio, intentar construir sin recursos suficientes o la advertencia de traslado de núcleo urbano).
- [ ] **Resultado esperado:**
  - La ventana modal debe lucir integrada visualmente con el `TemaHUD`:
    - Fondo oscuro semitransparente con marco definido.
    - Tipografía, tamaños y colores de botones conformes con la interfaz general.
    - Sin cajas grises por defecto del motor Godot.

---

## Bloque 10: Remodelación de Edificaciones ("Desdeclaración" / Edición)

> **Mecánicas implementadas:** `VoxelWorld.desdeclarar_edificio()`, `FinalizacionObras.iniciar_remodelacion()`, `Player._iniciar_remodelacion()` (`Shift + B`), y `PanelEdificio._on_remodelar()`.

### 10.1 Remodelación en 1ª Persona con Shift + B
- [ ] **Acción:** En vista 1ª persona, caminar hacia un edificio residencial terminado y apuntar la mira a su puerta principal (bloque inferior o superior de la puerta).
- [ ] **Acción:** Pulsar la combinación **`Shift + B`**.
- [ ] **Resultado esperado:**
  - Aparece la notificación: *"Remodelación iniciada para el edificio X: ahora en edición libre."* (o advertencia de colonos sin techo si las camas restantes en la colonia no alcanzaran).
  - Los bloques del edificio **dejan de estar protegidos**: ahora es posible minar bloques con la piqueta/mano, agregar nuevos bloques, cambiar aberturas o colocar extensiones.
  - Los residentes que estaban en el edificio se reubican automáticamente en otras camas disponibles de la colonia (incluyendo edificios buffer).
- [ ] **Comprobación de rechazo (no puerta o no terminado):**
  - Si se apunta a una pared o al suelo y se pulsa `Shift + B`, el HUD notifica: *"Remodelar edificio: apunta a la puerta principal de la estructura."*
  - Si se apunta a una estructura no declarada o a una obra incompleta, notifica el rechazo correspondiente.

### 10.2 Remodelación y Demolición en Vista Cenital desde PanelEdificio
- [ ] **Acción:** Pasar a vista cenital (**C**) y hacer clic sobre un edificio residencial terminado.
- [ ] **Resultado esperado:**
  - En el `PanelEdificio` se muestra la ficha con:
    - Cantidad de camas.
    - Desglose exacto de residentes por tipo (ej. `Residentes: Obrero: 3, Desempleado: 2`).
    - La suma de residentes respeta estrictamente la capacidad de vivienda de las camas (ej. 4 obreros por cama, 3 técnicos, etc.).
- [ ] **Acción:** Hacer clic en **`[Iniciar remodelación]`** (o en **`[Demoler]`**).
- [ ] **Resultado esperado:**
  - Se abre un cuadro de diálogo modal de confirmación con estilo `TemaHUD`.
  - El mensaje desglosa con exactitud:
    - Cantidad de residentes actuales y sus tipos: `Residentes actuales (Obrero: 3, Desempleado: 2): 5`.
    - Cuántos se reubican en camas libres de otros edificios: `• Reubicados en camas libres: X`.
    - Si las camas restantes no alcanzan, advertencia clara de desahucio: `• Advertencia: Y colono(s) quedarán sin techo (24 h para reubicarse).`
- [ ] **Acción:** Pulsar **Confirmar**.
- [ ] **Resultado esperado:** El edificio se desdeclara, sus bloques quedan libres para ser modificados y la ventana se cierra limpiamente con la notificación emitida.

### 10.3 Excepción del Núcleo Urbano (Crecimiento Orgánico)
- [ ] **Acción:** Apuntar a la puerta del Núcleo Urbano en 1ª persona y pulsar **`Shift + B`** (o seleccionarlo en cenital y pulsar **`[Iniciar remodelación]`**).
- [ ] **Resultado esperado:**
  - El modal/notificación indica: *"Remodelación iniciada para el núcleo urbano: ahora en edición libre."*
  - **No desaloja a ningún habitante** ni genera colonos sin techo (el censo cívico permanece inalterado).
  - Los bloques del Núcleo quedan libres para agregar extensiones, pedestales o modificaciones.
- [ ] **Acción de re-declaración:** Modificar o mantener el Núcleo y pulsar **B** en 1ª persona sobre su puerta.
- [ ] **Resultado esperado:** Se vuelve a declarar el Núcleo Urbano con su nuevo volumen (`id_nucleo` actualizado, influencia y almacén preservados).

### 10.4 Colonos "Sin Techo" y Reincorporación
- [ ] **Condición de prueba:** Remodelar el único edificio residencial poblado de la ciudad de modo que todos sus residentes queden sin camas disponibles.
- [ ] **Resultado esperado:**
  - La ventana de **Población** muestra el indicador: `"Sin techo: X"`.
  - El censo total incluye a los sin techo (`censo_total = demografia + sin_techo`), pero su estado cívico no ocupa puestos laborales.
  - Consumen comida a la misma tasa que los desempleados.
- [ ] **Reincorporación inmediata:** Si se redeclara el edificio (con sus camas) o se construye una nueva residencia, los colonos sin techo se absorben inmediatamente volviendo a figurar como desempleados/ciudadanos con techo, desapareciendo el rótulo de "Sin techo".

### 10.5 Edificios Adosados / Contiguos Pared con Pared
- [ ] **Acción:** Construir dos edificios pegados inmediatamente uno al lado del otro (compartiendo o teniendo muros contiguos adyacentes).
- [ ] **Acción:** Declarar ambos edificios (Edificio A y Edificio B).
- [ ] **Acción:** Iniciar remodelación en el Edificio A (`Shift + B` o en cenital).
- [ ] **Resultado esperado:**
  - El Edificio A se desdeclara y sus bloques pasan a edición libre.
  - El Edificio B permanece intacto y protegido.
- [ ] **Acción:** Modificar el Edificio A y volver a declararlo apuntando a su puerta y pulsando **B**.
- [ ] **Resultado esperado:**
  - La herramienta de declaración **discierne entre los bloques libres de A y los bloques declarados de B**: el *flood-fill* se detiene en seco en la frontera con B y no lo absorbe.
  - El Edificio A se declara y valida con éxito sin colisionar con B ni dar error de estructura inválida.

---

## Bloque 11: Sistema de Colonizabilidad (Edificios Buffer e Inmigración)

> **Mecánicas implementadas:** `Ciudad.colonizable_por_edificio`, `Ciudad.horas_apertura_colonizacion`, temporizador de 24h del juego y control manual en `PanelEdificio`.

### 11.1 Primer Edificio Residencial (Colonizable automático)
- [ ] **Acción:** Al construir y declarar la **primera residencia** de la partida, abrir su `PanelEdificio` en vista cenital.
- [ ] **Resultado esperado:**
  - Muestra: `Colonizable: SÍ (inmigración activa)`.
  - El botón interactivo muestra: `[Pausar colonización]`.
  - Permite la llegada de los primeros inmigrantes/colonos a la ciudad según las reglas habituales de migración.

### 11.2 Edificios Residenciales Posteriores (2 en adelante como Buffers)
- [ ] **Acción:** Construir y declarar un **segundo edificio residencial**.
- [ ] **Acción:** Abrir su `PanelEdificio` en vista cenital.
- [ ] **Resultado esperado:**
  - Muestra: `Colonizable: NO (apertura en 24 h)`.
  - El botón interactivo muestra: `[Permitir colonización]`.
  - Las camas de este edificio están listas para recibir a ciudadanos locales reubicados por remodelaciones, pero **no provocan la llegada de nuevos colonos inmigrantes**.

### 11.3 Temporizador de 24 Horas y Apertura Automática
- [ ] **Acción:** Dejar avanzar los ticks de simulación del juego (o avanzar horas de juego).
- [ ] **Resultado esperado:**
  - Cada hora de juego reduce en 1 el contador del edificio: `apertura en 23 h`, `apertura en 22 h`...
  - Al llegar a 0 horas, el estado transiciona automáticamente a `Colonizable: SÍ (inmigración activa)` y el botón cambia a `[Pausar colonización]`.

### 11.4 Control Manual Inmediato (Toggle de Colonización)
- [ ] **Acción:** En un edificio residencial en estado `Colonizable: NO (apertura en X h)`, pulsar el botón **`[Permitir colonización]`**.
- [ ] **Resultado esperado:**
  - El estado cambia al instante a `Colonizable: SÍ (inmigración activa)`.
  - El temporizador se elimina y el botón pasa a `[Pausar colonización]`.
  - La ciudad ahora permite que nuevos colonos inmigren a ocupar esas camas.
- [ ] **Acción adicional:** Pulsar **`[Pausar colonización]`**.
- [ ] **Resultado esperado:**
  - El estado vuelve a `Colonizable: NO (buffer protegido)`.
  - Se detiene la inmigración externa hacia ese edificio; queda reservado como buffer para la población local.

---

## Bloque 12: Tendido Progresivo de Vías por Colonos y Overlay Guía

> **Mecánicas implementadas:** `Obras.crear_obra_via()`, `ConstructorVias`, `ViaObraOverlay.gd`, avance celda a celda con cuadrilla de hasta 4 obreros/técnicos.

### 12.1 Creación de Obra Vial en Vista Cenital
- [ ] **Acción:** En vista cenital (**C**), entrar a Construir -> Vías (**1** -> **5**).
- [ ] **Acción:** Fijar puntos con clic izquierdo y confirmar el trazado con **doble clic izquierdo**.
- [ ] **Resultado esperado:**
  - La vía **ya no aparece construida instantáneamente**.
  - En su lugar, se genera una **Obra de Vía** visible mediante un **overlay guía de contorno perimetral en color amarillo** (`ViaObraOverlay`), que dibuja los bordes de alambre de las celdas proyectadas en el suelo.
  - La consola o notificación confirma la creación de la obra vial.

### 12.2 Asignación de Cuadrilla y Construcción Consecutiva de Extremo a Extremo
- [ ] **Acción:** Asegurarse de tener colonos obreros o técnicos libres en la ciudad.
- [ ] **Resultado esperado:**
  - Los obreros libres se dirigen hacia el trazado de la obra vial.
  - Hasta un máximo de **4 obreros** trabajan en paralelo sobre el tramo.
  - **Orden de construcción consecutivo:** La obra avanza de un extremo al otro de la ruta paso a paso; cada celda se completa en su sitio (nivelación, relleno o cuña) a medida que avanza la vía, sin separar la obra en fases de "todas las planas primero y cuñas después".
  - Cada colono avanza su celda: tala árboles si estorban, nivela la columna, coloca cuñas si hay rampa y registra el soporte vial en `Vias.gd`.
  - Conforme se completan celdas, el contorno guía amarillo se retira celda por celda hasta finalizar la obra por completo.

### 12.3 Fusión de Tramos Contiguos
- [ ] **Acción:** Mientras una obra de vía está en curso (aún incompleta), trazar y confirmar con doble clic un nuevo tramo contiguo que empiece o conecte con la obra existente.
- [ ] **Resultado esperado:**
  - El nuevo tramo se **fusiona limpiamente** con la obra vial en curso en lugar de crear una cuadrilla duplicada.
  - La cuadrilla máxima sigue siendo de 4 obreros para todo el conjunto contiguo.

---

## Bloque 13: Herramienta Unificada de Demolición (Edificios y Vías)

> **Mecánicas implementadas:** Modo Demoler cenital (tecla `3`), `_procesar_clic_demoler()`, trazado guiado naranja con `ViaDemolicionOverlay.gd`, selección de sección completa (4 celdas / 2 canales), bifurcaciones y remoción de vías.

### 13.1 Detección Contextual: Edificios vs Vías
- [ ] **Acción:** En vista cenital (**C**), activar el modo **Demoler** pulsando la tecla **`3`** (o haciendo clic en Demoler en el menú principal).
- [ ] **Prueba sobre edificio:** Hacer clic izquierdo sobre un edificio construido.
  - **Resultado:** Alterna la marca roja de demolición del edificio (comportamiento estándar).
- [ ] **Prueba sobre vía existente:** Hacer clic izquierdo sobre cualquier celda con vía construida.
  - **Resultado:** Se activa el modo guiado de **Demolición de Vía**.

### 13.2 Previsualización Guiada Naranja (Sección Completa / Ambos Canales / Esquinas Fieles)
- [ ] **Acción:** Al hacer clic en una celda de vía, mover el cursor a lo largo del trazado de la vía atravesando esquinas o curvas de 90°.
- [ ] **Resultado esperado:**
  - Se muestra un **overlay translúcido color naranja** (`ViaDemolicionOverlay`) resaltando el camino sobre la red de vías entre el inicio y el cursor.
  - **Ambos canales y esquinas completas:** La previsualización abarca las secciones completas de 4 celdas (ancho de 2 bloques) y sigue fielmente las esquinas de 90° sin saltos diagonales ni huecos en el vértice exterior, cubriendo todo el ancho del tramo sin requerir clics adicionales en la esquina.
  - La tarjeta contextual indica: `(clic izq.) ELEGIR RAMA`, `(doble clic) CONFIRMAR DEMOLICIÓN`, `(clic der.) CANCELAR`.
- [ ] **Bifurcaciones:** Si la vía se divide en una intersección con múltiples salidas, hacer clic izquierdo sobre la rama deseada para guiar el camino de remoción.

### 13.3 Confirmación con Outline Naranja y Ejecución de Demolición Vial
- [ ] **Acción:** Presionar **doble clic izquierdo** sobre el tramo naranja previsualizado.
- [ ] **Resultado esperado:**
  - Se confirma la demolición del tramo completo (ambos canales): entra en la cola de demoliciones de `Obras`.
  - **Outline Naranja Persistente:** Al confirmar, la vía queda marcada en el suelo con un **overlay de outline / alambre naranja** (`ViaDemolicionOverlay`) en los bordes de cada celda programada para demolición.
  - A medida que los colonos (o el jugador en 1ª persona) avanzan en la demolición, el outline naranja se va retirando celda a celda hasta desaparecer por completo al concluir el tramo.
  - Al completar la demolición, se retira el registro de vía en `Vias.gd` y se eliminan las cuñas físicas, preservando el terreno nivelado intacto.
- [ ] **Cancelación:** Si en lugar de doble clic se presiona **clic derecho**, el trazado naranja se cancela y se limpia inmediatamente.

---

## Bloque 14: Intervención Manual en 1ª Persona (Modo Vías `V`)

> **Mecánicas implementadas:** Tecla `V` en 1ª persona, `Player._alternar_modo_vias()`, `_trabajar_via_manual()` y `_demoler_via_manual()`.

### 14.1 Activación del Modo Vías con Tecla `V`
- [ ] **Acción:** En primera persona, presionar la tecla **`V`**.
- [ ] **Resultado esperado:**
  - Se activa el modo de vías: en el panel contextual inferior se muestra:
    - `(clic izq.) CONSTRUIR VÍA`
    - `(clic der.) DEMOLER VÍA`
    - `[V] Salir del modo vías`
  - Mientras el modo esté activo, el clic no mina bloques comunes ni abre puertas/baúles; se concentra en la red vial.

### 14.2 Acelerar Construcción de Obra Vial a Mano (Clic Izquierdo)
- [ ] **Acción:** Caminar hacia una celda con contorno amarillo de obra vial pendiente.
- [ ] **Acción:** Apuntar a la sección y hacer **clic izquierdo** (o mantener presionado).
- [ ] **Resultado esperado:**
  - El avatar ejecuta y avanza la **sección completa** (las celdas del bloque 2x2 correspondiente): se colocan de inmediato las láminas de vía y/o cuñas físicas en el mundo y se retira el alambre amarillo de esa sección completa.
  - No emite notificaciones repetitivas en cada clic (el feedback visual directo de la aparición de las láminas/cuñas en el terreno es inmediato); únicamente notifica *"Vía completada."* al finalizar la totalidad de la obra vial.
  - La obra queda reclamada temporalmente por el jugador (`Obras.reclamar()`) para que los colonos no interfieran mientras el jugador trabaja en ella.

### 14.3 Demolición Manual Inmediata de Vía (Clic Derecho)
- [ ] **Acción:** Con el modo `V` activo, apuntar a una sección de vía ya construida y hacer **clic derecho** (o mantener presionado mientras se camina).
- [ ] **Resultado esperado:**
  - Se retira de inmediato la sección completa (las 4 celdas del bloque 2x2 y cuñas asociadas a ese tramo) del mundo real.
  - La textura y estructura de vía desaparecen al instante sin notificaciones repetitivas emergentes.
- [ ] **Acción adicional:** Pulsar **`V`** nuevamente (o **Esc**) para salir del modo de vías y volver a la interacción estándar.

---

## Bloque 15: Prioridades Configurables de Obras en Edificios

> **Mecánicas implementadas:** `Obras.prioridades`, `Obras.fijar_prioridad()`, botón `[Prioridad: Normal / Alta / Baja]` en `PanelEdificio`, jerarquía estricta de tareas de colonos.

### 15.1 Selector de Prioridad en PanelEdificio
- [ ] **Acción:** En vista cenital (**C**), seleccionar un edificio que esté en estado de construcción (`estado == "construccion"`).
- [ ] **Resultado esperado:**
  - En la lista de botones aparece el botón interactivo: **`[Prioridad: Normal]`** (valor predeterminado al emplazar).
- [ ] **Acción:** Hacer clic en el botón de prioridad de forma sucesiva.
- [ ] **Resultado esperado:**
  - El botón cicla limpiamente: `Prioridad: Normal` -> `Prioridad: Alta` -> `Prioridad: Baja` -> `Prioridad: Normal`.

### 15.2 Jerarquía Estricta de Asignación de Tareas
- [ ] **Condición de prueba:** Tener varias obras concurrentes en la ciudad:
  1. Un edificio A con **Prioridad Alta**.
  2. Un edificio B con **Prioridad Normal**.
  3. Un edificio C con **Prioridad Baja**.
  4. Una obra de **Tendido de Vía**.
  5. Una obra de **Demolición** (edificio o vía marcado).
- [ ] **Resultado esperado según la jerarquía del sistema:**
  - Los colonos libres atienden primero las obras en el siguiente orden riguroso:
    1. **Edificio en Prioridad Alta** (Edificio A).
    2. **Edificio en Prioridad Normal** (Edificio B).
    3. **Demoliciones** (edificios o vías marcados).
    4. **Tendido de Vías** (obras viales pendientes).
    5. **Edificio en Prioridad Baja** (Edificio C).
  - El Edificio C (Baja) solo recibe trabajadores si no hay edificios Normales/Altos, ni demoliciones, ni vías pendientes.

---

## Tabla de Resumen y Aprobación Rápida

| Bloque | Característica comprobada | Estado (OK / Fallo) | Notas del tester |
| :--- | :--- | :---: | :--- |
| **1.1** | Iconos SVG en tarjeta de vías (clic izq, der, doble clic, Esc) | | |
| **1.2** | Clic derecho limpia tramos de vía y caché de preview | | |
| **1.3** | Ficha técnica dinámica en tarjeta de vías (+35% y celdas) | | |
| **1.4** | Tarjeta contextual se limpia al salir o deseleccionar herramientas | | |
| **2.1** | Puerta obligatoria únicamente en piso 1 (piso 2+ sin puerta) | | |
| **2.2** | Nombre automático `Residencia [camas]x[baules]` | | |
| **2.3** | Memoria y miniaturas de 5 blueprints residenciales | | |
| **3.1** | Nivelación y despeje compartidos entre puertas enfrentadas | | |
| **4.1** | VentanaBaul centrada con tamaño acotado (320x260) y scroll | | |
| **4.2** | Abrir y cerrar baúl con tecla `E` o `Escape` | | |
| **5.1** | Barra superior responsiva (Comida, Energía, Crítico, tierras raras) | | |
| **5.2** | Almacén ordenado alfabéticamente (A-Z) | | |
| **5.3** | Ocupaciones agrupadas en 4 categorías colapsables (▼ / ▶) | | |
| **5.4** | Población: Obreros unificados con desglose de desempleados | | |
| **6.1** | Acarreadores en servicio frontal sin congelarse | | |
| **6.2** | Cesión de paso en vías de 1 celda según jerarquía de carga | | |
| **6.3** | Retroceso de nivel en puestos con trabajadores básicos | | |
| **6.4** | Autoasignación inmediata a obras y tope de 4 obreros | | |
| **7.1** | Panel de residencia con camas/baúles y traslado de núcleo | | |
| **7.2** | Bajas por hambruna aplicadas a especialistas e investigadores | | |
| **8.1** | Navegación de menús con teclas `Z` y `X` | | |
| **8.2** | Ocultamiento de overlays de zonas fuera de su modo | | |
| **8.3** | Zonificación con instrucciones de clics e iconos vectoriales | | |
| **9.1** | Modales y diálogos de alerta con estilo `TemaHUD` | | |
| **10.1** | Remodelación en 1ª persona con `Shift + B` (libera bloques para minar/construir) | | |
| **10.2** | Remodelación cenital en `PanelEdificio` con diálogo modal y aviso de sin techo | | |
| **10.3** | Remodelación del Núcleo Urbano sin desalojo cívico ni impacto demográfico | | |
| **10.4** | Colonos sin techo en Ventana Población y reabsorción al conseguir camas | | |
| **10.5** | Declaración de edificios adosados/contiguos (detención de flood-fill en bordes) | | |
| **11.1** | 1er edificio residencial nace con Colonizable: SÍ | | |
| **11.2** | 2º edificio en adelante nace con Colonizable: NO (buffer de 24h) | | |
| **11.3** | Apertura automática a colonos tras 24 horas del juego | | |
| **11.4** | Botón toggle `[Permitir colonización]` / `[Pausar colonización]` manual | | |
| **12.1** | Tendido progresivo de vías con overlay perimetral guía (`ViaObraOverlay`) | | |
| **12.2** | Cuadrilla de hasta 4 colonos nivelando y colocando cuñas paso a paso | | |
| **12.3** | Fusión limpia de tramos viales contiguos incompletos | | |
| **13.1** | Herramienta Demoler (tecla 3) contextual para edificios y vías | | |
| **13.2** | Demolición de vías guiada con overlay naranja (`ViaDemolicionOverlay`) | | |
| **13.3** | Retiro de cuñas y vías por colonos preservando nivelación del suelo | | |
| **14.1** | Modo interacción de vías en 1ª persona con tecla `V` | | |
| **14.2** | Acelerar obra de vía a pie con clic izquierdo | | |
| **14.3** | Demolición manual de vía a pie con clic derecho | | |
| **15.1** | Selector de prioridad en `PanelEdificio` (Normal -> Alta -> Baja) | | |
| **15.2** | Jerarquía de asignación: Alta -> Normal -> Demolición -> Vías -> Baja | | |


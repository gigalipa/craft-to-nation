# Pendientes y próximos pasos según el roadmap (GDD Sección 11)

## Ruta vigente

1. Mantener las 26 escenas de prueba limpias mediante `tools/run-godot-tests.ps1` (570 bloques de prueba), que también detecta errores de ejecución y escenas incompletas.
2. ✅ (2026-10-04) Formación de especialistas (`escuela_especialistas`), universidad e investigaciones de activación (Metalurgia Aplicada y Automatización Industrial).
3. ✅ (2026-10-04) Fluidos (`agua`, `crudo`, `combustible`), recetas de refinería (`refineria_petrolera`, `productor_combustible`), central termoeléctrica y transmisión energética por vías e influencia con déficit horario.
4. ✅ (2026-10-05) Gestión de obras y blueprints: autoasignación inmediata de ociosos, tope de cuadrilla (máx. 4 obreros por obra), hasta 5 blueprints guardados con miniaturas y nombrado automático `Residencia [camas]x[baules]`, nivelación compartida por cota de puerta guía, traslado del núcleo urbano desde el panel del edificio, y flexibilización de aberturas (puertas obligatorias únicamente en el 1er piso; pisos superiores no necesitan puertas).
5. ✅ (2026-10-05) Logística, tráfico y pathfinding: jerarquía de transporte en vías de 1 celda (recursos priorizados: comida > combustible > crudo > acero > mineral_refinado > hierro > cobre > carbón > tierras_raras > tablas > madera > piedra > tierra > agua), cesión de paso y apartados laterales, recogida en puerta de servicio, retroceso de nivel en puestos según el empleado de menor rango activo, y reserva de destinos interiores en escuelas técnicas evitando bucles entre exterior y vestíbulo.
6. ✅ (2026-10-05) HUD, tarjetas contextuales y trazado de vías: barra superior responsiva con botón de Almacén compacto, recursos destacados (Comida, Energía, Crítico), ventana de Almacén alfabética, ventana de Ocupaciones categorizada por tipo y ordenada por antigüedad; tarjetas contextuales de herramientas e interacción con presentación por línea, iconos SVG de clic izquierdo/derecho y scroll (`click_izq.svg`, `click_der.svg`, `scroll.svg`) y doble clic `x2`; y trazador de vías con cancelación limpia de tramos y previsualización, más ficha técnica con recursos calculados dinámicamente por celda (`Vias.ficha_tecnica`).
7. ✅ (2026-10-06) **Remodelación de edificaciones y sistema de colonizabilidad:** desdeclaración de edificios sin demoler para permitir modificaciones estructurales (apuntando a la puerta principal con `Shift + B` / botón en `PanelEdificio`), excepción limpia para el Núcleo Urbano, buffers habitables de inmigración con contador de 24h y toggle manual, reubicación cívica, y estado temporal de "sin techo" (consumo de desempleado, bloqueo laboral y exilio a las 24h con penalización moral; ver `docs/Propuesta_Remodelacion_y_Colonizabilidad.md`).
8. ✅ (2026-10-07) **Tendido de vías por colonos y prioridades configurables de obras:** ejecución incremental de obras viales (`ConstructorVias.planificar` y `ejecutar_paso`) por colonos libres (hasta 4 obreros por obra, fusión automática de tramos contiguos); sistema de prioridades configurables por obra en `PanelEdificio` (Alta=2, Normal=1, Baja=0, desempate por orden de emplazamiento); jerarquía global de despacho en `Obras.gd` (Construcción Alta > Construcción Normal > Demoliciones > Tendido de vías > Construcción Baja); overlays dedicados `ViaObraOverlay` (perímetro en tierra) y `ViaDemolicionOverlay` (franja translúcida naranja guiada); herramienta unificada de demolición (tecla `3` cenital) para edificios o vías en red guiadas (búsqueda en red, doble clic para confirmar, clic derecho para cancelar, conservando bloques de nivelación); y herramienta en 1ª persona (tecla `V` en `Player.gd`) con modo exclusivo para avanzar obras o demoler vías manualmente.
9. Implementar bombas de extracción directa en fuentes de agua y crudo.
10. Consumo universal de energía en Era 3 (edificios civiles al activar Automatización Industrial).
11. Cerrar los pendientes menores de la Fase 3 y hacer una pasada de balance jugando antes de iniciar Fase 4.

## Estado detallado e historial

### 1. HUD visual interactivo — ✅ actualizado y responsivo (2026-10-05)

Hecho: barra superior responsiva (se adapta a la resolución, botón compacto «Almacén» sin saturar con cantidades ni tasas, muestra de forma visible Comida, Energía y Recurso Crítico con tasas por hora; población muestra censo/camas y total desempleado; moral y era/nivel). Ventana de Almacén ordenada alfabéticamente. Ventana de Ocupaciones accesible desde Población con categorías colapsables (recolección, industria, investigación, energía) y edificios ordenados cronológicamente inverso (el más nuevo arriba). Cierre rápido con tecla `E` o `Escape` en ventanas de diálogo y `VentanaBaul`. Barra de modos de la cenital (Ver, Construir con miniaturas y menú Residencial/puestos, Zonas, Vías), hotbar 1–6 y panel contextual (ambas vistas) con instrucciones desglosadas por línea, iconos vectoriales SVG de clic izquierdo, derecho y scroll (`click_izq.svg`, `click_der.svg`, `scroll.svg`), formato `x2` para doble clic y ficha técnica dinámica de vías (recursos por celda, velocidad, energía y vehículos). Transición animada de cámara (vuelo + crossfade del HUD) y panel de notificaciones emergentes. **Queda para después:** batalla, escuadrón, salud y equipo; herramientas de recolección (pala, pico, hacha); modo Demoler en la cenital; arte de los iconos de Ver/Construir/Zonas/Vías y Zona A/B/Borrar; eventos bélicos futuros.

### 2. Ventana de interacción del baúl — ✅ hecho (2026-09-28, cierre con E 2026-10-05)

Apuntar a un baúl y pulsar `E` (pulsar, no mantener) abre `VentanaBaul`, que muestra el almacén local del puesto (una fila por recurso presente en el baúl o en el stock central) con botones -/+ (1 de cada vez, 10 con Shift) y "Extraer todo". Pulsar `E` nuevamente o `Escape` cierra la ventana.

### 3. Declaración de edificios por volumen interno — ✅ hecho (2026-09-28)

Resuelto con flood-fill 3D del volumen interior sellado, vestíbulo libre detrás de cada puerta (externa o interna) y verificación de acceso real por pathfinding a cada cama/baúl desde al menos una puerta externa.

### 4. PoC 5, sub-proyecto 2C — transformación — parte 1 (costo de colocación) ✅ hecho (2026-09-29)

Bloques estructurales reales con costo (`tierra_compactada`, `bloque_madera`, `bloque_piedra`, `estructura_hierro`, `vidrio`), cobro de `Ciudad.almacen` al colocar y reembolso al minar.

~~**Parte 2: industrias y refinerías**~~ ✅ hechas (2026-09-30 a 2026-10-04): siderúrgica, refinería de tierras raras, aserradero, carbonera, refinería petrolera, productor de combustible y central termoeléctrica. Formación de técnicos (escuela técnica) y especialistas (escuela de especialistas), universidad con investigaciones lineales automáticas (Metalurgia Aplicada y Automatización Industrial).

### 4b. Logística, jerarquía de transporte y niveles de puesto — ✅ completo (2026-10-05)

1. ✅ (2026-10-05) **Jerarquía de prioridades de acarreo:** en caminos estrechos de 1 celda, un colono o acarreador cede el paso o se aparta a una casilla libre según: acarreador con carga (comida > combustible > crudo > acero > mineral_refinado > hierro > cobre > carbón > tierras_raras > tablas > madera > piedra > tierra > agua, desempatando por cantidad y luego ID) > acarreador vacío > colono empleado > colono ocioso.
2. ✅ (2026-10-05) **Recogida en puerta de servicio:** los acarreadores pueden transferir recursos desde la celda frontal del puesto (`servicio`) sin bloquear el interior ni atascar a los recolectores/trabajadores.
3. ✅ (2026-10-05) **Retroceso de nivel de puestos:** un puesto que admite obreros retrocede de nivel si cuenta con ellos; el nivel del puesto lo determina el trabajador de menor rango activo (excluyendo acarreadores).
4. ✅ (2026-10-05) **Hambruna ampliada:** `ORDEN_BAJAS_HAMBRUNA` incluye a especialistas e investigadores antes que a los desempleados.

### 5. Gestión de obras y blueprints — ✅ completo (2026-10-05)

1. ✅ (2026-10-05) **Cuadrilla limitada y autoasignación:** máximo 4 obreros asignados por obra; los colonos ociosos se asignan automáticamente de forma inmediata al emplazarse o reanudarse una obra.
2. ✅ (2026-10-05) **Almacenamiento de blueprints:** soporte de hasta 5 blueprints con miniaturas y nombrado automático `Residencia [camas]x[baules]`.
3. ✅ (2026-10-05) **Nivelación compartida:** la cota de nivelación de un blueprint se calcula según la celda frontal de su puerta guía, permitiendo que edificios enfrentados compartan bloques de nivelación y despeje.
4. ✅ (2026-10-05) **Traslado de núcleo urbano:** opción en la ventana de edificio para reubicar el núcleo a otra residencia sin pérdida de datos.

### 5b. Remodelación de edificaciones y sistema de colonizabilidad — ✅ implementado y verificado (2026-10-06)

Basado en `docs/Propuesta_Remodelacion_y_Colonizabilidad.md`. Permite editar edificios declarados sin deconstruirlos, protegiendo la capacidad cívica mediante buffers habitables y gestionando la sobrepoblación temporal. Probado en `CiudadTest.gd`, `BlueprintValidatorTest.gd` y `HUDTest.gd`.

1. **Mecánica de Remodelación ("Desdeclaración" / Edición libre):**
   - **`VoxelWorld.desdeclarar_edificio(id_edificio)`:** libera la protección de celdas (`inmunidad_minado` y `edificio_por_celda`) y metadatos estructurales sin destruir ningún bloque del `GridMap`.
   - **Activación:** botón `[Iniciar Remodelación]` en `PanelEdificio` (cenital) y atajo `Shift + B` apuntando a la puerta principal del edificio registrado (1ª persona, en simetría directa: `B` declara, `Shift + B` desdeclara).
   - **Núcleo Urbano:** no contiene camas ni residentes; al remodelarse pasa inmediatamente a edición libre sin reubicaciones ni penalizaciones demográficas.
2. **Reubicación de Residentes y Estado "Sin Techo":**
   - **Reubicación prioritaria en buffers:** busca camas libres en cualquier edificio residencial registrado, **incluso si su colonizabilidad está inactiva** (los buffers protegen a ciudadanos existentes).
   - **Colonos "Sin Techo":** si las camas totales de la colonia no alcanzan:
     - Consumen comida a tasa de desempleado (3 unidades/tick).
     - No pueden trabajar ni ser asignados a puestos/industrias mientras carezcan de vivienda.
     - Temporizador de 24 horas de simulación: si no consiguen cama en ese plazo, emigran/abandonan la ciudad con penalización temporal en la moral cívica.
3. **Sistema de Colonizabilidad (Control de Inmigración Externa):**
   - Controla exclusivamente la llegada de **nuevos colonos inmigrantes** desde el exterior (no restringe a los ciudadanos locales).
   - **Primer edificio residencial:** nace como `Colonizable: ACTIVO` automáticamente.
   - **Edificios posteriores (2 en adelante):** nacen como `Colonizable: INACTIVO` (buffer protegido) con cuenta regresiva de **24 horas de juego** para apertura automática a `ACTIVO`.
   - **Control manual en `PanelEdificio`:** muestra estado `[Colonizable: SÍ/NO]`, tiempo restante para apertura y botón toggle `[Permitir Colonización]` / `[Pausar Colonización]` para congelar o forzar la apertura inmediatamente.
4. **Desglose de tareas técnicas por módulo:**
   - **Backend (`Ciudad.gd`):** rastreo de `sin_techo`, consumo, bloqueo laboral, contador 24h y exilio, propiedades `colonizable` y temporizador de apertura en edificios.
   - **Mundo (`VoxelWorld.gd`):** método `desdeclarar_edificio(id_edificio)` liberando celdas de `inmunidad_minado` y `edificio_por_celda` sin alterar bloques físicos.
   - **Jugador (`Player.gd`):** atajo `Shift + B` apuntando a la puerta principal de un edificio registrado para invocar `iniciar_remodelacion()`.
   - **UI / HUD (`PanelEdificio.gd`):** botón `[Iniciar Remodelación]`, indicador de colonizabilidad, contador y botón toggle.

### 6. Construcción/deconstrucción asistida por NPCs — ✅ tendido de vías y prioridades completadas (2026-10-07)

Los colonos libres construyen y demuelen obras de edificios y vías con tope de 4 obreros y pausa de edificio.

1. **Prioridades configurables por obra:**
   - Botón cíclico en `PanelEdificio`: `Prioridad: Normal` (por defecto) -> `Baja` -> `Alta`.
   - Desempate por orden cronológico de emplazamiento (ID más antiguo primero).
   - Jerarquía global de asignación de mano de obra en `Obras.siguiente_tarea()`:
     1. Obras de construcción con prioridad Alta (2).
     2. Obras de construcción con prioridad Normal (1).
     3. Demoliciones (edificios y vías marcadas).
     4. Obras de tendido de vías (`via_construir`).
     5. Obras de construcción con prioridad Baja (0).

2. **Tendido de vías incremental por colonos:**
   - Desglose en `ConstructorVias.planificar()` y `ejecutar_paso()`: registro progresivo celda a celda en `Vias.gd` y colocación de cuñas y relleno en `GridMap`.
   - Soporte para hasta 4 obreros en paralelo por obra vial.
   - Fusión automática de tramos de vía contiguos o conectados como una única obra compartida.
   - Posicionamiento de trabajo de colonos tanto adyacente como dentro de la huella del tramo vial.

3. **Overlays visuales de obra y demolición vial:**
   - `ViaObraOverlay`: dibuja el contorno/perímetro alámbrico en el suelo de las celdas viales pendientes de construir.
   - `ViaDemolicionOverlay`: dibuja una franja plana translúcida de color naranja guiada sobre las celdas seleccionadas para demoler.

4. **Herramienta unificada de demolición en cámara cenital (Tecla 3):**
   - Contextual al hacer clic:
     - Sobre un edificio: conmuta su marca de demolición.
     - Sobre una vía existente: inicia la selección guiada de demolición sobre la red de vías (`Vias.buscar_camino_en_red()`). Cada clic en una bifurcación fija el camino, doble clic confirma la orden de demolición y clic derecho cancela la selección.
     - Retira cuñas y el registro en `Vias.gd` sin tocar los bloques de nivelación o terreno base.

5. **Herramienta de interacción con vías en 1ª persona (Tecla V):**
   - Modo exclusivo activable con `V` en `Player.gd` (bloquea minado, tala y colocación de bloques ordinarios).
   - Clic izquierdo sobre celda con obra vial: avanza un paso de construcción (`Obras.trabajar_via`).
   - Clic derecho sobre celda con vía construida: desmonta el tramo de vía (`Obras.trabajar_demoler_via`).
   - Reclama temporalmente la obra para evitar que los colonos interfieran mientras el jugador trabaja.

Pendientes de esta línea:
- Traducción de modelos `.dae` a blueprints construibles y aplicación de texturas finales.

### 7. Cola de pendientes menores de la Fase 3 — no bloqueantes

Pueden intercalarse en cualquier momento.

- Cauces de río sinuosos (hoy solo ejes ortogonales del grid).
- Corrección de pathfinding para dar mayor prioridad al uso de rutas (ignorar rutas solo si el destino no es alcanzable).
- Percentil de nivel de mar dependiente de un "tipo de mundo" (concepto sin diseñar aún).
- Restaurar el terreno excavado al deconstruir un edificio.
- Revisar el dithering de Alpha Hash en ventanas cuando exista una textura real.
- Devolver "Agregar todo" a `VentanaBaul` solo en los baúles dentro de un edificio de almacén y en los del núcleo urbano, que son los que realmente surten de recursos a la ciudad (el botón se quitó de todos los baúles el 2026-10-01; `Economia.agregar_deposito()` sigue disponible).

### Después de cerrar la Fase 3

- **Fase 4 (PoC 7):** cámara dual y selección de tropas.
- **Fase 5 (PoC 8-10):** pathfinding, cintas/tuberías y el Sistema de Puentes (que ya puede apoyarse en los cuerpos de agua reales de PoC 6). Las carretas (vehículos/unidades) también dependen de esta fase.

---

## Hecho

- ~~**Previsualización isométrica de construcciones en el menú Construir** (2026-09-30).~~ Las 5 opciones del submenú Construir (Residencial + Mina/Caza/Madera/Pesca) muestran una miniatura 3D real (malla y material reales, vista desde la esquina superior-derecha-frontal) en un espacio de tamaño fijo, que gira en vivo junto con Ctrl+rueda. El botón Residencial se atenúa mientras no haya ningún blueprint declarado (sigue siendo clickeable, con la misma notificación de siempre). La tecla `B`/botón "Construir" ahora solo abren o cierran el submenú, sin activar automáticamente la colocación de Residencial — elegir una opción adentro sigue activando la colocación real, sin cambios. Placeholder de ícono opcional (sin arte todavía) agregado a los botones de las barras de Modos y Zonas. Ver `docs/superpowers/specs/2026-09-30-previsualizacion-construcciones-cenital-design.md`.
- ~~**Corrección del despeje de camas al colocar blueprints, y notificaciones más precisas** (2026-09-27).~~ El despeje de camas rechazaba por error sitios válidos al colocar un blueprint (reportado jugando en vivo: dos camas paralelas separadas por una sola pared no dejaba construir), porque comparaba el lado/techo libre contra el mundo real sin excavar aunque cayera dentro de la propia huella del edificio; corregido para tratar el terreno natural dentro de la huella como se excava junto con el resto del interior, igual que el resto de la construcción. Además, las notificaciones de rechazo ya no mezclan varias restricciones en un mismo mensaje: cada una dice específicamente si falló una ventana, una puerta, una cama o si invade el despeje de un edificio vecino, y declarar un edificio a mano ya no junta todos los errores de validación en una sola notificación.
- ~~**Notificaciones del HUD, despeje de camas y colocación más segura** (2026-09-27).~~ Panel de notificaciones emergentes (esquina superior derecha, apiladas con fade-in/out de 2,5 s) con los motivos de rechazo al colocar/declarar un edificio, árboles sin frutos, edificios declarados/construidos y colonos nuevos; mensajes de `BlueprintValidator` reformulados a un tono conversacional; regla de despeje de camas (Sección 5 del GDD, "Volumen Vital y Camas") implementada: un lado con ambos extremos libres (cabecera y pies, el mismo lado) y 2 celdas libres encima de cada extremo; y corregidos dos bugs de colocación reportados jugando en vivo: ya no se puede colocar un bloque en la celda del propio avatar, y completar una construcción con el clic sostenido ya no encadena la colocación de un bloque nuevo contra la fachada recién terminada.
- ~~**Previsualización de la colocación de puestos** (2026-09-25).~~ Al colocar un puesto se ve la plantilla fantasma (verde o roja según la validez, con puertas y ventanas destacadas), el despeje reservado de puertas y ventanas y el área de nivelación de la huella y del frente, con la misma evaluación que el clic (`CamaraCenital._evaluar_puesto()`). Limitación: en la pesca, la cubierta sobre agua se marca como «rellenar» aunque se coloquen pilotes — ver `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Edificios de Recolección.md`.
- ~~**Puertas interactivas** (2026-09-25).~~ Las puertas son una lámina fina que gira 90° al abrirse y queda pegada a la jamba del hueco; el avatar las alterna con `E` apuntándolas y los colonos las abren por proximidad (se cierran al irse, salvo las abiertas a mano). Las celdas conservan su tipo; el estado vive en `Puertas.gd` — ver `docs/superpowers/specs/2026-09-25-puertas-interactivas-design.md`. El baúl de un puesto sigue accesible por `E` mantenida hasta que exista su ventana (punto «Ventana de interacción del baúl»).
- ~~**Edificios de recolección jugables reales** (2026-09-24).~~ Los cuatro puestos son edificios de bloques con plantilla por tipo (provisionales, a reemplazar con el arte de SketchUp): puerta de servicio (los colonos trabajan en una zona junto a ella), baúl como depósito físico (`E` sobre el baúl pasa al inventario lo que quepa), rotación de 4 giros, deconstrucción bloque a bloque que desactiva el puesto y libera a sus trabajadores, y agotamiento que despide a los recolectores y conserva a los acarreadores hasta vaciar el almacén local — ver `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Edificios de Recolección.md`.
- ~~**PoC 5, sub-proyecto 2B: extracción física y agotamiento** (2026-09-24).~~ Los puestos de mina y maderero consumen bloques y árboles reales (la mina solo desde el subsuelo, no la superficie), las tasas de todos los puestos se recalculan cada 6 horas de juego según su entorno (árboles, bloques minerales y agua conectada), y el avatar mina, tala y recolecta frutos con tiempo e indicador de avance sobre un inventario limitado que arranca la partida — ver `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Fase 2B - Extracción Física y Agotamiento.md`. La bomba extractora y el petróleo quedan para el sub-proyecto de fluidos.
  - Consideraciones originales del usuario para este punto (ya implementadas):
    > Algunas consideraciones para esta sección:
    > 1. Una mina no debe extraer los bloques de la superficie, solo los del subsuelo, principalmente para no quedar flotando en el aire.
    > 2. Los edificios de producción deben recalcular y actualizar su tasa de producción cada cierta cantidad de ticks, para que la tasa tenga sentido, es decir: madereros y caza&recolección según la cantidad de árboles presentes en su área de acción, minas según la cantidad de bloques minerales que aún queden en el subsuelo dentro de su volúmen de acción, bombas extractoras según la cantidad de bloques de petróleo que haya en el pozo sobre el cuál se encuentren, pesca según la cantidad de bloques de agua en su área de acción (porque el jugador podría construir algo en el agua, drenando bloques de agua, o incluso podría conectar cuerpos de agua aumentando el volúmen de agua conectada).
- ~~Fase 3 (PoC 6): efecto visual/de jugabilidad para cascadas (`es_cascada_en()`).~~
- ~~Fase 3 (PoC 6): reglas de flotación/natación.~~
- ~~Fase 3 (PoC 6): puesto maderero jugable y puesto de pesca/frutos del mar.~~
- ~~Fase 3 (PoC 6): escalar PROFUNDIDAD_SUBSUELO hacia los ~300 bloques finales del GDD.~~
- ~~Fase 3 (PoC 6): generación de otros recursos del subsuelo siguiendo el patrón de ruido del hierro con distintas concentraciones.~~
- ~~Fase 3 (PoC 6): puertas "a nivel de suelo" en el sistema de construcción (cavar o elevar el piso bajo la huella), necesario para que las puertas queden a la altura de la carretera y cuenten como "conectadas" a la red.~~
- ~~**Vías de "tierra pisada" (sub-proyecto 6).**~~ Implementado y verificado jugando en vivo (2026-09-22 a 2026-09-23): trazador en la cámara cenital (tecla `V`), overlay 2x2, cuñas para desnivel de 1, relleno para 2-3, sistema completo de rampa diagonal suave (7 piezas + `diag_lat` condicional), nivelación de tramos en V al nivel más alto en vez de dos rampas, bono de velocidad +35% para colonos y avatar, despeje/nivelación de blueprints que ignoran o levantan vías existentes, y overlays sin z-fighting entre la vía construida y las zonas A/B pintadas — ver `docs/superpowers/specs/2026-09-22-vias-tierra-pisada-design.md`. Las carretas quedan pendientes (ver Fase 5).
- ~~**Sub-proyecto 2A: puestos, producción y acarreo** (2026-09-21).~~ Los puestos asignan recolectores/acarreadores desde un panel, producen al almacén local y acarrean a pie hasta el núcleo urbano — ver `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Fase 2A - Puestos, Producción y Acarreo.md`.

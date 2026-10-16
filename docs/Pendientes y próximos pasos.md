# Pendientes y próximos pasos según el roadmap (GDD Sección 11)

## Ruta vigente

1. Mantener las 28 escenas de prueba limpias mediante `tools/run-godot-tests.ps1`, que también detecta errores de ejecución y escenas incompletas.
2. ✅ (2026-10-04) Formación de especialistas (`escuela_especialistas`), universidad e investigaciones de activación (Metalurgia Aplicada y Automatización Industrial).
3. ✅ (2026-10-04) Fluidos (`agua`, `crudo`, `combustible`), recetas de refinería (`refineria_petrolera`, `productor_combustible`), central termoeléctrica y transmisión energética por vías e influencia con déficit horario.
4. ✅ (2026-10-05) Gestión de obras y blueprints: autoasignación inmediata de ociosos, tope de cuadrilla (máx. 4 obreros por obra), hasta 5 blueprints guardados con miniaturas y nombrado automático `Residencia [camas]x[baules]`, nivelación compartida por cota de puerta guía, traslado del núcleo urbano desde el panel del edificio, y flexibilización de aberturas (puertas obligatorias únicamente en el 1er piso; pisos superiores no necesitan puertas).
5. ✅ (2026-10-05) Logística, tráfico y pathfinding: jerarquía de transporte en vías de 1 celda (recursos priorizados: comida > combustible > crudo > acero > mineral_refinado > hierro > cobre > carbón > tierras_raras > tablas > madera > piedra > tierra > agua), cesión de paso y apartados laterales, recogida en puerta de servicio, retroceso de nivel en puestos según el empleado de menor rango activo, y reserva de destinos interiores en escuelas técnicas evitando bucles entre exterior y vestíbulo.
6. ✅ (2026-10-05) HUD, tarjetas contextuales y trazado de vías: barra superior responsiva con botón de Almacén compacto, recursos destacados (Comida, Energía, Crítico), ventana de Almacén alfabética, ventana de Ocupaciones categorizada por tipo y ordenada por antigüedad; tarjetas contextuales de herramientas e interacción con presentación por línea, iconos SVG de clic izquierdo/derecho y scroll (`click_izq.svg`, `click_der.svg`, `scroll.svg`) y doble clic `x2`; y trazador de vías con cancelación limpia de tramos y previsualización, más ficha técnica con recursos calculados dinámicamente por celda (`Vias.ficha_tecnica`).
7. ✅ (2026-10-06) **Remodelación de edificaciones y sistema de colonizabilidad:** desdeclaración de edificios sin demoler para permitir modificaciones estructurales (apuntando a la puerta principal con `Shift + B` / botón en `PanelEdificio`), excepción limpia para el Núcleo Urbano, buffers habitables de inmigración con contador de 24h y toggle manual, reubicación cívica, y estado temporal de "sin techo" (consumo de desempleado, bloqueo laboral y exilio a las 24h con penalización moral; ver `docs/Propuesta_Remodelacion_y_Colonizabilidad.md`).
8. ✅ (2026-10-07) **Tendido de vías por colonos y prioridades configurables de obras:** ejecución incremental de obras viales (`ConstructorVias.planificar` y `ejecutar_paso`) por colonos libres (hasta 4 obreros por obra, fusión automática de tramos contiguos); sistema de prioridades configurables por obra en `PanelEdificio` (Alta=2, Normal=1, Baja=0, desempate por orden de emplazamiento); jerarquía global de despacho en `Obras.gd` (Construcción Alta > Construcción Normal > Demoliciones > Tendido de vías > Construcción Baja); overlays dedicados `ViaObraOverlay` (perímetro en tierra) y `ViaDemolicionOverlay` (franja translúcida naranja guiada); herramienta unificada de demolición (tecla `3` cenital) para edificios o vías en red guiadas; y herramienta en 1ª persona (tecla `V` en `Player.gd`) para avanzar obras o demoler vías manualmente.
9. ✅ (2026-10-08 a 2026-10-12) **Red de tuberías y acueductos (Canalizaciones):** arquitectura modular de 4 piezas (columna, bloque de ducto lineal/quiebre, tramo continuo con pivot vertical y bloque extremo), cruces a desnivel en $Y_{suelo}+6$ con doble columna en $Y+5$, topología multi-entrada / salida única, cese de derrames al conectar, cálculo dinámico de flujos y ficha técnica con unidades legibles (`m³`, `m³/min`).
10. ✅ (2026-10-08 a 2026-10-12) **Subsuelo, pozos de crudo y físicas de fluidos:** yacimientos profundos de petróleo en el subsuelo, lámpara minera/farol de mano (`PlayerLamparaTest.gd`, tecla `L`), físicas de fluidos (viscosidad en crudo a 0.20, spreading de líquidos: agua 7, combustible 5, crudo 3, drenado por bloques sólidos e inundación de agua estilo Minecraft al minar bloques adyacentes a agua).
11. ✅ (2026-10-12) **Ajustes de industria, logística y energía:** acarreo de 150 unidades de carbón a central termoeléctrica si stock local < 500 (reserva 500) o abastecimiento 100% por ducto en modos líquidos; partición estricta de refinería petrolera (400 crudo / 600 combustible reservado); y presencia continua de aprendices y trabajadores en interiores.
12. ✅ (2026-10-12) **Interfaz modal de energía (`VentanaEnergia.gd`):** botón interactivo de energía en barra superior, ventana modal con balance global, cobertura, listas de generadores/consumidores y navegación por clic con teletransporte de cámara y panel de edificio.
13. ✅ (2026-10-12) **Pathfinding ponderado por vías:** coste de terreno natural = 8, vía de tierra pisada = 3, guiando a colonos por rutas construidas.
14. Consumo universal de energía en Era 3 (edificios civiles al activar Automatización Industrial; permanece pendiente hasta que los edificios civiles tengan funciones automatizadas).
15. ✅ (2026-10-12) **Extracción de fluidos y estaciones de bombeo:** La estación de bombeo (`estacion_bombeo`) ya existe y cumple la extracción directa desde cuerpos de agua naturales superficiales (con muelle sobre 2+ bloques de agua y `puerto_agua_out`). Por diseño, no existen afloramientos naturales de crudo superficial, por lo que no se utilizan estaciones de bombeo para crudo; el crudo se extrae exclusivamente en el subsuelo profundo mediante el centro de extracción (`centro_extraccion`).
16. ✅ (2026-10-14) **Fábrica de bloques y control de reservas en refinerías:** Edificio industrial fábrica de bloques (`fabrica_bloques`, 1 piedra -> 3 bloques_piedra con prioridad de pago en bloques de piedra); y sistema de reservas de materia prima en almacén central ([0, 50, 100, 250, 500] u) en refinerías (aserradero, siderúrgica, fábrica de bloques, carbonera, tierras raras y central termoeléctrica) para proteger materias primas de construcción.
17. ✅ (2026-10-15) **Sistema de Moral Dinámica, Productividad Continua y Dinámicas Poblacionales:** modelo continuo de moral [0 a 100] que modula la productividad laboral ($X = 0.5 \times 2^{(Y/50)}$) en recolección y refinado; tasa horaria $\Delta M$ afectada por superávit (+0.4/h), escasez de recursos (comida hasta -3.0/h, energía hasta -1.5/h, insumos industriales hasta -0.4/h), diversidad de dieta (+0.5/h max con 6 grupos), desgaste por colonos sin techo (-0.05/h por colono) y buffer móvil de peligrosidad de 168h (7 días); inmigración continua post-núcleo desbordando a sin techo si no hay camas libres; éxodo crítico si moral < 20.0 con fuga de cerebros jerárquica (investigador > especialista > técnico > militar > obrero); éxodo por desempleo a los 10 días (240h); tolerancia de sin techo ampliada a 72h; y botón interactivo en HUD con 4 estados emocionales (😡/🙁/😐/🙂) y modal explicativo `VentanaMoral.gd`. 28 escenas de prueba al 100% en verde.
18. ✅ (2026-10-16) **Sobreasignación e Integración de Iconografía Completa del HUD / UI:** Catálogo centralizado de más de 90 íconos vectoriales SVG pixel-art en `godot/assets/icons/` administrado por `IconosHUD.gd`; barra superior con íconos de censo, moral (4 rostros emocionales 😡/🙁/😐/🙂), almacén, tendencia horaria de comida, y rayo interactivo tri-color de energía con lectura en kW; botones de construcción ampliados a 104×76 px con overlay de insignias en 3 esquinas (insumos requeridos, electricidad y función producida) y miniaturas 3D vivas (vías con balastro, acueducto con pilares y tubería con codo); indicadores de 1ª persona con batería/ProgressBar de lámpara, burbujas de oxígeno e ícono de herramienta contextual al minar; keycaps dorados para atajos de teclado y cálculo de distancia al núcleo; íconos temáticos en todas las ventanas globales (`VentanaPoblacion`, `VentanaAlmacen`, `VentanaOcupaciones`, `VentanaEnergia`, `VentanaMoral`), paneles de interacción (`VentanaBaul`, `PanelEdificio`, `PanelPuesto`, `PanelCanalizacion`, `PanelNotificaciones`) y botones de confirmación modal (`check`/`cruz`). 28 escenas de prueba al 100% en verde.
19. **Pasada de balance en partida de larga duración:** balancear recolección, consumo, moral y refinamiento de recursos jugando en vivo tras implementar el control de cuotas, el sistema de moral y la interfaz con iconografía integrada, certificando la economía antes de iniciar Fase 4 (combate y tropas).

## Estado detallado e historial

### 1. HUD visual interactivo — ✅ actualizado, responsivo e iconografía integrada (2026-10-16)

Hecho: sistema integral de iconografía vectorial SVG (pixel-art `crispEdges`) con catálogo centralizado en `IconosHUD.gd`. Barra superior responsiva con íconos vectoriales (censo, 4 estados de moral, almacén, comida con tendencia y rayo de energía interactivo tri-color con lectura de kW). Ventana de Almacén alfabética con íconos de recursos. Ventana de Ocupaciones agrupada con íconos de oficios y categorías colapsables. Ventana de Energía con balance, generadores y consumidores navegables con teletransporte. Ventana de Moral con medidor dinámico y desglose analítico. Ventana de Baúl con íconos de recursos, botones de extracción y control de incremento. Panel de Edificio con íconos de puertas, pausa, prioridad y remodelación. Panel de Puesto con insignias de nivel romano y selección de combustible. Panel de Canalización con ícono de ducto. Panel de Notificaciones con categorías visuales. Botones de diálogo modal con confirmación estilizada (`check`/`cruz`). En cenital: botones de construcción ampliados (104×76 px) con insignias en 3 esquinas (insumos, electricidad, función) y miniaturas 3D vivas para vías, acueductos y tuberías. En 1ª persona: indicador de lámpara con batería/ProgressBar, burbujas de oxígeno e ícono contextual de herramienta de minado. Tarjetas contextuales con formateo keycap dorado. **Queda para después:** batalla, escuadrón, salud y equipo; eventos bélicos futuros.

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

### 7. Red de tuberías y acueductos (Canalizaciones) — ✅ completo (2026-10-12)

Red física aérea para transporte de fluidos con visualización, flujo, soporte estructural y cálculo dinámico (`Canalizaciones.gd`, `CanalizacionesTest.gd`):

1. **Arquitectura modular de 4 piezas:**
   - **Columnas de soporte:** bloques estructurales verticales colocados sobre el terreno natural hasta la cota del cabezal.
   - **Bloques de ducto (cabezales):** colocados en el tope de cada columna. Dos variantes: *Lineal* (alineación continua) y *Quiebre* (esquinas a 90°).
   - **Tramos conectores:** secciones prismáticas de altura fija $H$ igual a un bloque y longitud/ángulo dinámicos. Pivotan verticalmente sobre el centro perpendicular de los bloques que unen, absorbiendo pendientes y desniveles sin fisuras visuales ni z-fighting. Texturizado UV mapeado longitudinalmente de forma repetida.
   - **Bloques extremos:** conectan los tramos a los puertos de entrada o salida de los edificios.
2. **Cruces a desnivel en $Y_{suelo}+6$:**
   - Si una tubería cruza ortogonalmente sobre otra red a $Y_{suelo}+4$, el trazador eleva el cruce a $Y_{suelo}+6$.
   - Coloca columnas dobles de soporte en $idx-1$ e $idx+1$ hasta $Y_{suelo}+5$ coronadas con cabezales en $Y_{suelo}+6$.
   - La celda vertical intermedia $Y_{suelo}+5$ sobre el ducto inferior queda como aire libre, permitiendo el paso sin colisiones.
   - Los tramos inclinados ascienden y descienden limpiamente 2 cotas.
3. **Topología y dinámica de fluidos:**
   - Redes independientes y homogéneas por tipo de recurso (agua, crudo o combustible).
   - Topología multi-entrada hacia salida única: admite varios extractores que convergen hacia un único almacén o consumidor receptor.
   - Cancelación inmediata de derrames activos tan pronto como la red conecta con un puerto de destino válido.
   - Ficha técnica en el panel contextual con unidades legibles (`m³` para volumen transportado, `m³/min` para caudal).

### 8. Subsuelo, pozos de crudo, físicas de fluidos y lámpara — ✅ completo (2026-10-12)

Profundización del mundo procedural y mecánicas subterráneas (`VoxelWorld.gd`, `Player.gd`, `PlayerLamparaTest.gd`, `TranslucidosRendererTest.gd`):

1. **Pozos petrolíferos y subsuelo profundo:**
   - Generación procedural de yacimientos de petróleo en las capas subterráneas profundas.
   - Central de extracción de crudo que bombea el fluido subterráneo y lo inyecta a la red de ductos.
2. **Lámpara minera / Farol de mano:**
   - Lámpara omnidireccional equipable por el jugador para exploración de cavernas y minería subterránea.
   - Toggle mediante atajo `L` y control desde panel contextual.
3. **Físicas y viscosidad de fluidos:**
   - Viscosidad de crudo fijada en `0.20` con impulso de salto atenuado a `VELOCIDAD_SALTO * 0.20`, simulando densidad pesada al sumergirse.
   - Spreading horizontal diferenciado: agua 7 bloques, combustible 5 bloques, crudo 3 bloques.
   - Desalojo de líquidos: colocar un bloque sólido destruye el líquido existente en esa celda limpiamente.
   - Inundación de agua estilo Minecraft: al minar o retirar un bloque sólido rodeado por agua lateral o superior, la celda vaciada se llena de agua inmediatamente.

### 9. Ajustes de industria, logística, energía y pathfinding — ✅ completo (2026-10-12)

Refinamiento de cadenas productivas, interfaz de control y navegación de colonos (`Colonos.gd`, `Economia.gd`, `VentanaEnergia.gd`, `Vias.gd`, `BuscadorRutas.gd`):

1. **Logística de centrales termoeléctricas:**
   - Capacidad local fijada en 500 unidades de carbón (reserva de 500).
   - En modo carbón, si el stock < 500, acarreadores transportan lotes de 150 unidades y descargan cuando hay espacio suficiente.
   - En modo combustible o crudo, no admite acarreadores (abastecimiento 100% por ductos).
2. **Partición de refinerías petroleras:**
   - Almacén de 1000 unidades particionado estrictamente: máximo 400 unidades de crudo (40%) y 600 unidades reservadas para combustible producido (60%).
3. **Modal de energía (`VentanaEnergia.gd`):**
   - Botón interactivo de energía en la barra superior.
   - Ventana modal con estilo TemaHUD: muestra balance neto, demanda, generación y porcentaje de cobertura.
   - Listas interactivas de generadores y consumidores con combustible activo, potencia y estado.
   - Al hacer clic en un edificio de la lista, la ventana se cierra, la cámara se desplaza suavemente hacia su posición y se abre su panel de interacción.
4. **Pathfinding ponderado y estabilidad de presencia:**
   - Coste de paso: terreno natural = 8, vía de tierra pisada = 3, con penalización moderada (+1) por desnivel. Los colonos priorizan fuertemente desplazarse por caminos y vías construidas.
   - Presencia continua: los trabajadores mantienen su estado de presentes mientras se desplazan hacia sus puestos de trabajo en el interior de los edificios.

### 10. Fábrica de bloques y control de reservas en refinerías — ✅ completo (2026-10-14)

Implementación de la cadena de piedra procesada y protección de materias primas en el almacén central (`PlantillasPuesto.gd`, `CadenaMinerales.gd`, `Ciudad.gd`, `Economia.gd`, `BarraModos.gd`, `CamaraCenital.gd`, `HumoRefinerias.gd`, `PanelPuesto.gd`):

1. **Fábrica de bloques (`fabrica_bloques`):**
   - Huella 5x6 de bloques de piedra, puertas de entrada y salida diferenciadas, chimenea y baúl físico.
   - Receta de refinado: `1 piedra -> 3 bloques_piedra` (tasa 0.5, cupo 4 técnicos/acarreadores, capacidad de almacén 1000).
   - Humo de corte: partículas de polvo de piedra gris claro en `HumoRefinerias.gd`.
   - Incorporación al menú cenital industrial (tecla 4) y previsualización fantasma en zona industrial.
2. **Integración económica de `bloques_piedra`:**
   - Decimoquinto recurso en el almacén central de `Ciudad.gd`.
   - Cobro con prioridad: `consumir_costo_con_detalle()` y `puede_pagar()` descuentan primero los costos de piedra usando `bloques_piedra` y el remanente con `piedra` cruda (análogo a tablas y madera).
   - Función `almacen_general()` que devuelve el stock efectivo unificado de la ciudad.
3. **Control de reservas de materias primas (Esquema A):**
   - Valores admisibles: `[0.0, 50.0, 100.0, 250.0, 500.0]`.
   - Cada refinería (aserradero, siderúrgica, fábrica de bloques, carbonera, tierras raras y central termoeléctrica) dispone de su umbral individual `reserva_insumo`.
   - Botón interactivo cíclico en `PanelPuesto.gd` para cambiar la reserva sobre la marcha.
   - Los acarreadores retiran insumos del almacén central solo si el stock supera la reserva fijada (`disponible = maxf(0.0, stock_ciudad - reserva)`), evitando que las industrias consuman recursos esenciales para la construcción (`estructura_hierro`, tablas, piedra).

### 11. Sistema de Moral Dinámica, Productividad Continua y Demografía — ✅ completo (2026-10-15)

Simulación integral y continua del clima anímico ciudadano, modulación económica de rendimientos y dinámicas migratorias (`Ciudad.gd`, `Economia.gd`, `BarraSuperior.gd`, `VentanaMoral.gd`, `HUD.gd`):

1. **Simulación Dinámica de Moral:**
   - Escala continua de 0.0 a 100.0 puntos, iniciando con optimismo pionero en 75.0 y convergiendo inercialmente a 50.0 ($\Delta_{inercia} = (50.0 - M) \times 0.02$).
   - Factores horarios ($\Delta M$): superávit global (+0.4/h), escasez de comida (-0.6/h o -3.0/h en hambruna), déficit energético (hasta -1.5/h), balance de insumos industriales (-0.2/h a -0.4/h por recurso agotado), variedad de fuentes alimenticias (hasta +0.5/h con 6 grupos), desgaste por colonos sin techo (-0.05/h por colono) y buffer móvil de peligrosidad de 168 horas (7 días).
2. **Modulación Continua de la Productividad Laboral:**
   - Curva exponencial continua $X = 0.5 \times 2^{(Y/50)}$ donde $Y$ es la moral:
     - Moral 0.0 $\rightarrow$ Rendimiento 50% ($0.50\times$).
     - Moral 50.0 $\rightarrow$ Rendimiento estándar 100% ($1.00\times$).
     - Moral 100.0 $\rightarrow$ Rendimiento entusiasta 200% ($2.00\times$).
   - Aplicado a la extracción primaria en puestos y a la velocidad de refinado en todas las plantas industriales.
3. **Dinámicas Poblacionales y Éxodo Cívico:**
   - Inmigración continua a partir de la fundación del núcleo urbano; los colonos excedentes sin cama desbordan a «sin techo».
   - Tolerancia de colonos «sin techo» ampliada a 72 horas (3 días) antes de emigrar.
   - Desempleados emigran pacíficamente tras 10 días continuos (240 horas de simulación) sin oficio asignado.
   - Umbral crítico de moral en 20.0: desata éxodo migratorio activo proporcional con fuga jerárquica de talentos (`investigador` > `especialista` > `tecnico` > `militar` > `obrero` > `desempleado` > `ciudadano`).
4. **Interfaz Visual y HUD:**
   - Botón interactivo de moral en `BarraSuperior.gd` con 4 estados emocionales: 😡 Crítica (<20.0), 🙁 Baja (20.0-35.0), 😐 Neutra (35.0-65.0) y 🙂 Alta (>=65.0).
   - Ventana modal explicativa `VentanaMoral.gd` accesible con clic o tecla `M`, con métricas en vivo, multiplicador activo, tendencia horaria y desglose analítico factor por factor.

### 12. Cola de pendientes menores de la Fase 3 — no bloqueantes

Pueden intercalarse en cualquier momento.

- Cauces de río sinuosos (hoy solo ejes ortogonales del grid).
- ~~Corrección de pathfinding para dar mayor prioridad al uso de rutas~~ — ✅ resuelto (2026-10-12) con coste 8 natural vs 3 vía.
- Percentil de nivel de mar dependiente de un "tipo de mundo" (concepto sin diseñar aún).
- ~~Restaurar el terreno excavado al deconstruir un edificio~~ — ✅ Resuelto por diseño: la mecánica queda tal como está; el terreno excavado permanece tal como se haya cavado para la colocación del edificio (la terraformación es permanente).
- Revisar el dithering de Alpha Hash en ventanas cuando exista una textura real.
- ~~Devolver "Agregar todo" a `VentanaBaul` solo en los baúles dentro de un edificio de almacén y en los del núcleo urbano~~ — ✅ Resuelto por diseño: no habrá botón de "agregar todo" en los baúles de puestos periféricos ni refinerías; el comportamiento actual (transferencia individual y extracción) es definitivo.

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

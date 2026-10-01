# Pendientes y próximos pasos según el roadmap (GDD Sección 11)

## Ruta a seguir

### 1. HUD visual interactivo — ✅ primera entrega hecha (2026-09-25)

Hecho: barra superior (recursos, población, moral, nivel), barra de modos de la cenital (Ver, Construir con menú Residencial/puestos, Zonas, Vías), hotbar 1–6 y panel contextual (ambas vistas), ventanas de Población/Almacén (clic en la barra superior, en vivo, arrastrables, persisten posición/estado), transición animada de cámara (vuelo + crossfade del HUD, órbita de la cenital según hacia dónde mira el avatar) y panel de notificaciones emergentes (esquina superior derecha, apiladas con fade-in/out de 2,5 s, 2026-09-27) con los motivos de rechazo al colocar/declarar, edificios declarados/construidos y colonos nuevos. Spec: `docs/superpowers/specs/2026-09-25-hud-por-modos-design.md`. **Queda para después:** batalla, escuadrón, salud y equipo (no hay sistema detrás); cantidades por casilla de la hotbar (cuando el inventario del avatar, el almacén central, aporte el consumo de materiales); herramientas de recolección (pala, pico, hacha); modo Demoler en la cenital; arte de los iconos de Ver/Construir/Zonas/Vías y Zona A/B/Borrar (el mecanismo de `icono` opcional ya existe en `BarraModos.gd`, ver 2026-09-30, solo falta el arte); más eventos con notificación (ciudad bajo ataque, cuando exista combate).

Ventanas de datos (decisión del usuario, 2026-10-01): «Población» muestra población total, camas construidas y empleo por tipo (empleados / sin empleo); la nueva «Ocupaciones» (botón en Población) lista los sitios de trabajo con trabajadores/cupo y estado, y un clic centra la cámara en el edificio y abre su panel del puesto. Queda para después: filtros y ordenación de la lista.

Inspiración combinada de AoE y Minecraft. Se organiza por **modos** (construir, zonas, vías, etc.) con sus accesos directos, y no por edificios particulares: habrá demasiados como para asignar una tecla a cada uno. Va tras los edificios de recolección jugables (ya implementados) para definir la interfaz con ellos ya presentes, y antes de 2C y de las demás mecánicas para no rehacerla.

### 2. Ventana de interacción del baúl — ✅ hecho (2026-09-28)

Apuntar a un baúl y pulsar `E` (pulsar, no mantener) abre `VentanaBaul`, que muestra el almacén local del puesto (una fila por recurso presente en el baúl o en el stock central) con botones -/+ (1 de cada vez, 10 con Shift) y "Extraer todo" (el botón "Agregar todo" se quitó el 2026-10-01). Reemplazó al retiro automático por `E` mantenida sobre el baúl; mantener `E` quedó solo para los frutos (`Player._procesar_frutos()`). Se apoya en el despachador `_interactuar()` de `Player.gd`. Ver `godot/scripts/VentanaBaul.gd`.

### 3. Declaración de edificios por volumen interno — ✅ hecho (2026-09-28)

En este punto el jugador ya debe poder declarar y registrar distintos edificios residenciales. Pendiente de revisar: un edificio de dos niveles con una cama en cada nivel no fue reconocido por la declaración. El sistema debería cambiar a uno que detecte el **volumen interno** de una construcción, para permitir edificios personalizados de formas variadas (pirámides, cilindros, irregulares).

Resuelto con un flood-fill 3D del volumen interior sellado (reemplaza la comparación de cada losa contra la huella global del edificio), más el resto del checklist de "casa aprobable": vestíbulo libre detrás de cada puerta (externa o interna) y verificación de acceso real por pathfinding a cada cama/baúl desde al menos una puerta externa. Ver `docs/superpowers/specs/2026-09-28-volumen-interno-edificios-design.md` y `docs/superpowers/plans/2026-09-28-volumen-interno-edificios.md`.

### 4. PoC 5, sub-proyecto 2C — transformación — parte 1 (costo de colocación) ✅ hecho (2026-09-29)

~~Programar el consumo de recursos según los costos de "colocación" indicados en el documento de `Fichas_Consumo_Produccion.md`, y el reembolso simétrico al volver a minar un bloque colocado por el jugador (decisión del usuario, 2026-09-28).~~ Hecho: el placeholder único `pared` se reemplazó por bloques estructurales reales con costo (`tierra_compactada`, `bloque_madera`, `bloque_piedra`, `estructura_hierro`, `vidrio`), colocar desde la hotbar del avatar cobra el recurso crudo de `Ciudad.almacen` y volver a minar un bloque colocado reembolsa exactamente lo cobrado — ver `docs/superpowers/specs/2026-09-29-costo-colocacion-bloques-design.md` y `docs/superpowers/plans/2026-09-29-costo-colocacion-bloques.md`.

~~**Parte 2: siderúrgica real**~~ ✅ hecha (2026-09-30): edificio real de 5×5 con plantilla de `bloque_piedra`, puertas de entrada y salida separadas, que solo se coloca dentro de la zona de influencia y sobre zona industrial; operada por técnicos (un desempleado se vuelve técnico al asignarlo), con acarreo de ida y vuelta núcleo → entrada → salida → núcleo (mínimo 10 unidades por viaje) y `acero` en el stock central; `bloque_acero` (3 acero por bloque, décima casilla de la hotbar, tecla `0`) ya tiene fuente de acero — ver `docs/superpowers/specs/2026-09-30-siderurgica-real-design.md` y `docs/superpowers/plans/2026-09-30-siderurgica-real.md`.

~~**Parte 2, resto:** refinería de tierras raras, aserradero y carbonera~~ ✅ hechas (2026-10-01): edificios reales con plantilla, material e indicador de actividad propios (humo violáceo, humo negro, aserrín); personal máximo 4; `tasa_base` 0,5 (tierras raras y aserradero) y 2,0 (carbonera). Las tablas del aserradero son un recurso nuevo que cuenta como madera al pagar construcciones; ver `PoC_5/…Catálogo de Recursos y Cadenas de Producción.md`. La formación de técnicos ✅ está hecha (2026-10-01): la **Escuela técnica** (primer edificio de investigación, sobre zona residencial dentro de la influencia, con 4 mesas de estudio —bloque nuevo `mesa_estudio`— en vez de baúl) forma cohortes de 4 obreros que estudian 24 h y salen como 3 técnicos libres (la vivienda ocupada se conserva con `x_cama`; el cuarto colono se va de la ciudad); las refinerías solo contratan técnicos libres y un técnico despedido sigue siendo técnico. Spec: `docs/superpowers/specs/2026-10-01-escuela-tecnica-design.md`.

### 5. Resto del catálogo general de PoC 5

Ver `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Catálogo de Recursos y Cadenas de Producción.md`: sub-proyecto 2 (madera), 3 (fluidos: agua/crudo/combustible) y 4 (energía). El sub-proyecto 1 (minerales) ya está completo.

### 6. Construcción/deconstrucción asistida por NPCs

Los colonos participan en construir y deconstruir. Se apoya en el acarreo (2A) y en la extracción real (2B, ya implementada).
Traducción de modelos .dae a blueprints construibles.
Aplicación de primeras texturas.
Los técnicos libres (sin puesto) también harán obras de construcción, demolición y tendido de vías, igual que los obreros desempleados.

### 7. Cola de pendientes menores de la Fase 3 — no bloqueantes

Pueden intercalarse en cualquier momento.

- Cauces de río sinuosos (hoy solo ejes ortogonales del grid).
- Corrección de pathfinding para dar mayor prioridad al uso de rutas (ignorar rutas solo si el destino no es alcanzable).
- Percentil de nivel de mar dependiente de un "tipo de mundo" (concepto sin diseñar aún).
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

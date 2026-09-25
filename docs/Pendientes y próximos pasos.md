# Pendientes y próximos pasos según el roadmap (GDD Sección 11)

## Ruta a seguir

### 1. HUD visual interactivo — ✅ primera entrega hecha (2026-09-25)

Hecho: barra superior (recursos, población, moral, nivel), barra de modos de la cenital (Ver, Construir, Zonas, Vías, Puestos), hotbar 1–6 y panel contextual (ambas vistas). Spec: `docs/superpowers/specs/2026-09-25-hud-por-modos-design.md`. **Queda para después:** batalla, escuadrón, salud y equipo (no hay sistema detrás); cantidades por casilla de la hotbar (cuando el inventario del avatar, el almacén central, aporte el consumo de materiales); herramientas de recolección (pala, pico, hacha); modo Demoler en la cenital; iconos (hoy son texto, cada botón admite un `icono` opcional).

Inspiración combinada de AoE y Minecraft. Se organiza por **modos** (construir, zonas, vías, etc.) con sus accesos directos, y no por edificios particulares: habrá demasiados como para asignar una tecla a cada uno. Va tras los edificios de recolección jugables (ya implementados) para definir la interfaz con ellos ya presentes, y antes de 2C y de las demás mecánicas para no rehacerla.

### 2. Ventana de interacción del baúl

Apuntar a un baúl y pulsar `E` (pulsar, no mantener) abre una ventana similar a la de asignación de obreros, que muestra el contenido del baúl y ofrece extraer o agregar recursos. Reemplaza al retiro actual por `E` mantenida sobre el baúl (rama de `_procesar_frutos()`), que se elimina al construir la ventana; mantener `E` queda solo para los frutos. Se apoya en el despachador `_interactuar()` que ya existe en `Player.gd` (lo creó el punto de las puertas interactivas). Encaja con el HUD (punto 1).

### 3. Declaración de edificios por volumen interno

En este punto el jugador ya debe poder declarar y registrar distintos edificios residenciales. Pendiente de revisar: un edificio de dos niveles con una cama en cada nivel no fue reconocido por la declaración. El sistema debería cambiar a uno que detecte el **volumen interno** de una construcción, para permitir edificios personalizados de formas variadas (pirámides, cilindros, irregulares).

### 4. PoC 5, sub-proyecto 2C — transformación

Aserradero, carbonera, siderúrgica y refinería de tierras raras convertirían recursos crudos en procesados, con recetas.

### 5. Resto del catálogo general de PoC 5

Ver `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Catálogo de Recursos y Cadenas de Producción.md`: sub-proyecto 2 (madera), 3 (fluidos: agua/crudo/combustible) y 4 (energía). El sub-proyecto 1 (minerales) ya está completo.

### 6. Construcción/deconstrucción asistida por NPCs

Los colonos participan en construir y deconstruir. Se apoya en el acarreo (2A) y en la extracción real (2B, ya implementada).

### 7. Cola de pendientes menores de la Fase 3 — no bloqueantes

Pueden intercalarse en cualquier momento.

- Cauces de río sinuosos (hoy solo ejes ortogonales del grid).
- Corrección de pathfinding para dar mayor prioridad al uso de rutas (ignorar rutas solo si el destino no es alcanzable).
- Percentil de nivel de mar dependiente de un "tipo de mundo" (concepto sin diseñar aún).
- Revisar el dithering de Alpha Hash en ventanas cuando exista una textura real.

### Después de cerrar la Fase 3

- **Fase 4 (PoC 7):** cámara dual y selección de tropas.
- **Fase 5 (PoC 8-10):** pathfinding, cintas/tuberías y el Sistema de Puentes (que ya puede apoyarse en los cuerpos de agua reales de PoC 6). Las carretas (vehículos/unidades) también dependen de esta fase.

---

## Hecho

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

# Colonos NPC y Pathfinding a Pie — Diseño

**Alcance:** sub-proyecto 1 de 6 de la "lógica de recursos" (construcción,
unidades, tecnologías, economía de producción/consumo). Cubre solo la base
que todos los demás necesitan: **ciudadanos NPC que viven en las casas y
caminan por el mundo voxel**, con su taxonomía de población, su vivienda y
su migración. Une dos piezas del roadmap (GDD Sección 11) que hasta ahora
estaban separadas: los **colonos NPC** (Fase 2, PoC 4, "última pieza
pendiente") y el **pathfinding** (Fase 5, PoC 8, adelantado por decisión
explícita del usuario el 2026-09-20 — CLAUDE.md pide no mezclar PoC sin una
decisión explícita, y esta lo es).

**Repo:** `C:\Users\peraz\Projects\Misc\CityCraft`, proyecto Godot 4.7 compartido en `godot/`.

## Contexto: descomposición completa y orden

El usuario pidió diseñar la lógica de recursos completa (construcción,
entrenamiento de unidades, tecnologías, economía). Es demasiado para un solo
spec, y las dependencias (acarreo por NPC, obreros que construyen) exigen
ciudadanos que caminen. Se decidió, por capas:

| # | Sub-proyecto | Origen en el roadmap | Estado |
|---|---|---|---|
| 1 | **Colonos NPC + pathfinding a pie** | Fase 2 (colonos) + Fase 5/PoC 8 (adelantado) | **Este spec** |
| 2 | Núcleo de economía: almacenes locales, acarreo, producción/consumo, asignación recolección/acarreo | PoC 5, ampliado | Futuro |
| 3 | Construcción con costo real y obreros NPC | Fase 1/3 | Futuro |
| 4 | Entrenamiento de unidades (Investigador, Militar) | Fase 4/6 | Futuro |
| 5 | Tecnologías (catálogo por datos) | Sección 7 | Futuro |
| 6 | Carreteras y carretas | Fase 5 | Futuro |

Las decisiones de los sub-proyectos 2 a 6 ya tomadas están en "Decisiones
globales ya tomadas" al final, para que sus specs no vuelvan a preguntarlas.

## Decisiones de alcance confirmadas con el usuario (este sub-proyecto)

- **Entra:** colonos NPC (aparecen, tienen tipo y hogar, caminan, se ven en
  el mundo, se evitan entre sí y al avatar); pathfinding a pie; migración
  según vivienda libre; taxonomía de 7 tipos del Excel; vivienda
  fraccionaria ("x Cama"); límites de camas por piso y de pisos por casa
  según el nivel de ciudad (con su validación); **cuerpo visible del
  avatar**; **fantasmas de obra permeables hacia afuera** (Sección 6).
- **No entra:** trabajo, recolección, acarreo, almacenes, construcción por
  NPC, entrenamiento, tecnologías, carreteras, consumo de combustible y
  energía (solo se transcribe la tabla).
- **Pathfinding solo a pie por el terreno.** Carreteras y unidades de
  transporte son un sub-proyecto posterior.
- **A\* propio, no `NavigationServer3D`.** El GDD (Fase 5, PoC 8) dice
  `NavigationServer3D` nativo. No se usa: exige hornear una malla de
  navegación y este mundo cambia continuamente (minado, construcción
  fantasma, agua que fluye), lo que obligaría a rehornearla siempre. Un A\*
  que evalúa vecinos consultando `VoxelWorld` en el momento no necesita
  invalidar nada. Se actualiza el GDD (ver "Documentación").
- **Los colonos no se acuestan en camas concretas:** viven en una casa
  (hogar), entran en ella y pueden pararse encima de una cama o junto a
  ella (corrección del usuario, 2026-09-20). Una cama admite varios colonos.
- **Los colonos llegan como `desempleado`.** No hay nacimientos ni
  envejecimiento, así que `ciudadano` queda definido en la taxonomía pero
  sin ninguna fuente por ahora.
- **Vivienda fraccionaria compartida:** cada cama aporta 1 unidad de
  vivienda; una persona de tipo T ocupa `1 / x_cama[T]`. La suma no puede
  superar la capacidad.
- **El límite de población es la vivienda real** (camas construidas), no el
  tope de 4/8/12 por nivel de `Ciudad.gd`. El nivel de ciudad limita cuántas
  camas por piso y cuántos pisos puede tener una casa (ver Sección 4).

## Arquitectura

```
godot/
  scenes/
    BuscadorRutasTest.tscn      # Nueva: pruebas del A*
    ColonosTest.tscn            # Nueva: pruebas de Colonos.gd (sin escena visual)
    Main.tscn                   # + nodo ColonosRenderer
  scripts/
    BuscadorRutas.gd            # Nuevo: A* puro (RefCounted), sin nodos
    BuscadorRutasTest.gd        # Nuevo
    Colonos.gd                  # Nuevo: autoload, estado y comportamiento de los colonos
    ColonosTest.gd              # Nuevo
    ColonosRenderer.gd          # Nuevo: dibuja un MeshInstance3D por colono
    Ciudad.gd                   # Modificado: taxonomía, vivienda, migración, registro por edificio
    CiudadTest.gd               # Modificado
    BlueprintValidator.gd       # Modificado: límites de camas por piso y de pisos
    BlueprintValidatorTest.gd   # Modificado
    Player.gd                   # Modificado: registro/retiro de edificio con id y camas por piso;
                                #   cuerpo del avatar; exención de colisión con fantasmas de obra
    Player.tscn                 # Modificado: malla del cuerpo del avatar
    VoxelWorld.gd               # Modificado: permisos de salida, cuerpo de colisión por obra y puerta de inicio de obra
    (MeshLibrary)               # Modificado: el ítem "fantasma" pierde sus formas de colisión
    HUD.gd                      # Modificado: línea de población
  project.godot                 # + autoload "Colonos"
```

Mismo patrón que `Ciudad.gd`/`Zonificacion.gd`/`Recoleccion.gd`: autoloads
`extends Node` sin `class_name` (evita el bug de caché de clases globales de
Godot), estado y lógica puros, verificados con escenas `*Test.tscn`.

## Sección 2 — Pathfinding: `BuscadorRutas.gd`

Clase pura `RefCounted` (como `GeneradorMundo.gd` y `NiveladorTerreno.gd`),
construida con un objeto `mundo` que solo necesita
`obtener_tipo(celda: Vector3i) -> String` (`""` = vacía). Las pruebas le
pasan un mundo falso determinista.

**Celda transitable** (`es_transitable(celda)`): un NPC ocupa 2 celdas de
alto (como la puerta).

- Las celdas `c` y `c + arriba` están libres. Libres = `""`,
  `"puerta_inferior"`, `"puerta_superior"`. Todo lo demás es sólido para el
  pathfinding, incluido `"fantasma"` (los fantasmas tienen colisión),
  `"follaje"`, `"madera"`, camas y baúles.
- Excepción de agua: `c` puede ser `"agua"` siempre que `c + arriba` sea
  libre (agua de 1 bloque de profundidad: se cruza). Si `c` y `c + arriba`
  son ambas agua, la profundidad es de 2 o más y no es transitable
  (coherente con la natación del jugador, que solo nada desde 2 bloques).
- `c - arriba` es suelo: sólido y no agua. Una cama o un baúl es suelo, así
  que un colono puede pararse encima; no hace falta una regla especial.

**Movimientos:** solo los 4 ortogonales horizontales, con diferencia de
altura `dy ∈ {+1, 0, -1, -2, -3}` (sube 1 bloque, cae hasta 3). Las celdas
de la columna vecina entre la altura actual y la de destino, más las 2 de
alto del NPC, deben estar libres (subir exige además la celda `c + 2·arriba`
libre en la columna de origen). Sin diagonales.

**Búsqueda:** A\* con cola de prioridad binaria, coste 1 por paso, heurística
Manhattan 3D, tope de nodos expandidos por consulta
(`MAX_NODOS_EXPANDIDOS := 20000`, suficiente para cruzar el mapa de
200×200). `buscar_ruta(origen, destino) -> Array[Vector3i]` devuelve las
celdas a recorrer (sin incluir el origen) o `[]` si no hay ruta, el origen
o el destino no son transitables, o se agota el tope.
`# ponytail: tope fijo, búsqueda síncrona; pasar a búsqueda asíncrona o
jerárquica si el número de NPC lo exige.`

**Parámetros de consulta.** `buscar_ruta(origen, destino, opciones)` acepta
`opciones.bloqueadas: Dictionary` (celdas temporalmente ocupadas por otros
colonos o por el avatar, ver Sección 3) y `opciones.ignorar_fantasmas:
Array` (ids de obra cuyos bloques `"fantasma"` cuentan como libres para
este solicitante, ver Sección 6). Sin opciones, todo fantasma es sólido.
Para saber a qué obra pertenece un fantasma, el `mundo` que recibe el
buscador expone además `id_de_edificio(celda: Vector3i) -> int` (ya existe
en `VoxelWorld`; el mundo falso de las pruebas lo implementa igual), que solo
se consulta cuando `ignorar_fantasmas` no está vacío.

**Ruta que se rompe:** el colono verifica `es_transitable(siguiente)` antes
de cada paso. Si dejó de serlo (minado, construcción, agua), recalcula desde
su celda actual; si no hay ruta, elige otro destino. Sin sistema de
invalidación.

## Sección 3 — Colonos: `Colonos.gd` y `ColonosRenderer.gd`

**`Colonos.gd` (autoload, estado puro).** Guarda `colonos: Dictionary` de
`id -> {id, tipo, hogar, celda, posicion, ruta, espera, destino_es_hogar}`.
Referencia a `mundo` fijada por `Main.gd` (`Colonos.mundo = mundo`, como
`jugador.mundo`); las pruebas le asignan un mundo falso. Tiene `_process`
que llama a `avanzar(delta)`; las pruebas llaman a `avanzar()` directamente.

- **Hogar:** id de edificio residencial (el que ya asigna `VoxelWorld`,
  `celda_a_edificio`/`edificio_a_celdas`). Al llegar, cada colono recibe el
  hogar con **menor ocupación relativa** (colonos de ese hogar, cada uno
  ponderado por `1 / x_cama`, entre las camas del edificio). El hogar solo
  determina a dónde entra: el límite vinculante de población es la
  capacidad global de `Ciudad` (Sección 4), y un hogar puede quedar algo por
  encima de su capacidad sin efecto.
  `# ponytail: la asignación no fuerza capacidad por casa; añadir si hace
  falta que cada casa tenga su propio tope.`
- **Reasignación:** si un hogar se demuele (`Ciudad.retirar_edificio_residencial`),
  sus colonos se reasignan a otro hogar; si no queda ninguno, sigue el
  desahucio que ya calcula `Ciudad` (Sección 4).
- **Comportamiento — deambular:** alterna entre destinos dentro y fuera de
  su casa. Destino en casa: celda transitable aleatoria dentro de la caja
  envolvente del hogar (puede quedar sobre una cama o junto a ella). Destino
  fuera: celda transitable aleatoria dentro de la zona de influencia
  (`Zonificacion.dentro_de_influencia()`). Camina hasta él, espera unos
  segundos y elige otro. Si tras N intentos (placeholder 8) no encuentra
  destino con ruta, espera y reintenta.
- **Movimiento:** avanza celda a celda por su ruta a velocidad constante
  (`VELOCIDAD_COLONO := 2.5` celdas/s, placeholder), con la altura
  interpolada al subir y bajar.
- **Evitación (decisión del usuario, 2026-09-20):** dos colonos nunca
  ocupan la misma celda, ni un colono la del avatar. `Colonos` lleva
  `ocupadas: {celda -> id}` con la celda actual de cada colono y la que está
  a punto de pisar (reserva). Antes de pasar a la celda siguiente, reserva;
  si está ocupada por otro colono o por el avatar, espera un momento
  (`ESPERA_BLOQUEO := 0.5` s) y luego recalcula la ruta pasando las celdas
  ocupadas como `bloqueadas`. Si tampoco así hay ruta, abandona el destino y
  elige otro. El avatar cuenta como obstáculo en su celda y, mientras se
  mueve, también en la celda hacia la que avanza (posición + dirección de la
  velocidad); los colonos lo esquivan pero **no huyen de él**: no abandonan
  su destino salvo que queden bloqueados. Dos colonos de frente en un pasillo
  de 1 celda se resuelven porque ambos abandonan su destino tras la espera.
  `# ponytail: sin negociación de prioridad; añadir si aparecen atascos
  persistentes con mucha población.`
- **Cuerpo físico:** cada colono tiene un `AnimatableBody3D` con cápsula (en
  una capa de colisión propia que el jugador respeta) movido por código, para
  que el avatar no pueda atravesarlos. Lo crea `ColonosRenderer` junto a la
  malla.
- **Aparición:** al llegar un migrante, en una celda transitable del borde
  de la zona de influencia (`Zonificacion.influencia_min/max`); camina
  hacia su hogar. Si no hay celda de borde transitable, aparece junto al
  núcleo.
- **Reconciliación:** `Ciudad.demografia` sigue siendo la fuente de verdad
  de las cantidades (así `CiudadTest` sigue probando cifras puras). `Ciudad`
  emite la señal `tick_simulado` al final de cada tick; `Colonos` la escucha
  y reconcilia por tipo: si hay menos colonos que `demografia[tipo]`, crea;
  si hay más, retira (las bajas por hambruna o el desahucio se ven así en el
  mundo). `reconciliar()` también es invocable directamente en pruebas.

**`ColonosRenderer.gd` (nodo en `Main.tscn`).** Un `MeshInstance3D` con una
cápsula placeholder por colono, posicionado según `Colonos`. Las unidades
definitivas (Quaternius/KayKit, GDD Sección 11) solo cambiarían esa malla.
`# ponytail: un MeshInstance3D por colono; pasar a MultiMesh si la
población llega a miles.`

## Sección 3b — Cuerpo del avatar

Hoy el avatar no tiene malla: en primera persona solo existe la cámara. Se le
da un **cuerpo placeholder** (cápsula) como hijo de `Player`, **visible tanto
desde la cámara cenital como en primera persona** (decisión del usuario,
2026-09-20; igual que los colonos, sin sprite propio por ahora). El modelo
definitivo (Quaternius/KayKit, GDD Sección 11) solo reemplazaría la malla.
La celda que ocupa el avatar (`Vector3i` de su posición) es lo que `Colonos`
trata como obstáculo.

Detalle para que se vea en primera persona: la cámara está a la altura de
los ojos, así que si quedara **dentro** de la cápsula el culling de caras
traseras la haría invisible (o mostraría su interior). La cápsula del cuerpo
termina por debajo del ojo (a la altura de los hombros) y la cámara queda por
encima; al mirar hacia abajo se ve la parte superior del cuerpo. Se ajusta
visualmente al implementar (alturas y `near` de la cámara para no recortar el
cuerpo).
`# ponytail: cápsula sin animación ni brazos/piernas.`

## Sección 4 — Población, migración y vivienda en `Ciudad.gd`

**Taxonomía.** Tabla única `TIPOS_POBLACION` (fuente: `docs/Recursos.xlsx`,
hoja "Relacion"; el Excel reemplaza a la tabla de roles del GDD Sección 6):

| Tipo | Comida/h | Combustible/h | Energía/h | x Cama |
|---|---|---|---|---|
| ciudadano | 2 | 0 | 0 | 4 |
| desempleado | 3 | 0 | 0 | 4 |
| obrero | 5 | 0 | 0 | 4 |
| tecnico | 3 | 0 | 0 | 3 |
| especialista | 2 | 1 | 1 | 2 |
| investigador | 1 | 0 | 2 | 1 |
| militar | 4 | 3 | 0 | 3 |

Solo `comida` se aplica en este sub-proyecto; combustible y energía quedan
transcritos para el de economía. `CONSUMO_POR_ROL` se reemplaza por esta
tabla; las claves de `demografia` pasan a los 7 tipos. Equivalencia con los
roles anteriores: `trabajador_tipo_1`→`obrero`, `trabajador_tipo_2`→`tecnico`,
`trabajador_tipo_3`→`especialista`; `jovenes` y `ancianos` desaparecen.

**Niveles de vivienda** (decisión del usuario, 2026-09-20; reemplaza
`CAMAS_POR_PISO_PERMITIDO` = 4/8/12, que era un tope de censo, no de casa):

```
NIVELES_VIVIENDA = {
  1: {"camas_por_piso": 2, "pisos": 2},
  2: {"camas_por_piso": 4, "pisos": 4},
  3: {"camas_por_piso": 4, "pisos": 8},
}
```

Una casa de nivel 1 tiene hasta 4 camas (2 por piso × 2 pisos) y alberga
hasta 16 obreros/desempleados/ciudadanos (4 por cama); con técnicos 12, con
especialistas 8, con investigadores 4. El jugador puede construir tantas
casas como sus recursos y el espacio permitan: el reto es su tamaño y
cantidad frente a comida y reservas. **Nota:** el nivel 3 era suelo + 5
pisos (6 en total) en el GDD Sección 5; el usuario lo fija en 8. Los **12
pisos** quedan reservados para el nivel máximo de desarrollo de la
civilización (todavía no existe: el sistema llega hasta el nivel 3, ver
Sección 7 del GDD), fuera de alcance de este spec.

**Registro por edificio.** `Ciudad.registrar_edificio_residencial(id: int,
camas_por_piso: Array[int])` y `retirar_edificio_residencial(id: int)`
guardan `edificios_residenciales: {id -> camas_por_piso}`. Idempotente por
id (resuelve el aviso `ponytail:` existente sobre registro duplicado).
`capacidad_camas_construida` pasa a ser un valor derivado (suma de camas de
los pisos permitidos por el nivel actual, cada piso limitado a
`camas_por_piso` del nivel), no un contador. Si baja el nivel, los pisos
superiores dejan de contar y sus ocupantes se desahucian (GDD Sección 5).

**Vivienda fraccionaria.**
`vivienda_ocupada = Σ demografia[t] / x_cama[t]`;
`vivienda_libre = capacidad_camas_construida − vivienda_ocupada`.
`regular_densidad_vertical()` desahucia de uno en uno, en el orden
`desempleado, ciudadano, obrero, tecnico` (placeholder: se sacrifica primero
a quien no produce; luego el resto), hasta que `vivienda_ocupada ≤
capacidad` (con tolerancia `1e-6`). La hambruna sigue quitando `militar`,
`obrero`, `tecnico`, como hoy.

**Migración.** Cada tick se acumula `TASA_MIGRACION := 0.5` colonos/h
(placeholder). Cuando el acumulador llega a 1, entra un `desempleado` si el
tick no tuvo hambruna y `vivienda_libre ≥ 1 / x_cama["desempleado"]`.
Lógica numérica pura en `Ciudad`; `Colonos` solo la refleja. El resultado
de `simular_tick()` incluye `"migrantes"`.

**Validación de límites (`BlueprintValidator`).** Nueva
`validar_limites_vivienda(blueprint, nivel)`: para blueprints de la zona
`residencial_investigacion`, `blueprint["pisos"].size() ≤ pisos` y
`(piso["camas"]).size() ≤ camas_por_piso` por cada piso, según
`NIVELES_VIVIENDA[nivel]`. Se aplica al declarar un edificio y al colocar
una copia de un blueprint (el nivel pudo bajar desde que se declaró).
Rechazo con mensaje en español, como las demás reglas.

**Cambios de llamada en `Player.gd`:** `_completar_construccion` (línea
~575) pasa el id del edificio y las camas por piso (ya disponibles como
`piso["camas"]` en el blueprint); la deconstrucción (línea ~393) pasa
`resultado["id"]`, que `VoxelWorld.procesar_deconstruccion()` ya devuelve.

**HUD.** "Población: N / camas" pasa a mostrar la vivienda ocupada frente a
la capacidad construida (con fracciones, el censo ya no se compara
directamente con las camas), en rojo si excede.

## Sección 6 — Fantasmas de obra permeables hacia afuera

**Problema:** al colocar un blueprint, sus bloques `"fantasma"` son sólidos
(tienen colisión). Si un colono o el avatar está en el sitio, queda dentro
de un sólido: el pathfinding no encuentra ruta desde su celda y el avatar
queda atrapado. Decisión del usuario (2026-09-20): el fantasma es
transitable solo para quien ya está dentro, y nadie puede empezar la
construcción mientras haya alguien dentro.

**Regla.**
- Al emplazar un blueprint (o al empezar a deconstruir un edificio
  completo, cuando sus bloques vuelven a ser fantasma), se registra un
  **permiso de salida** para cada colono y para el avatar cuya celda esté
  dentro del volumen de la obra (caja envolvente de todas sus celdas,
  incluida la preparación de terreno). El permiso se guarda por obra en
  `VoxelWorld` (`permisos_salida: {id_obra -> {entidad -> true}}`).
- Con permiso, la entidad ignora la colisión con los fantasmas de **esa**
  obra: en `BuscadorRutas` mediante `opciones.ignorar_fantasmas`; en el
  avatar mediante `add_collision_exception_with(cuerpo_de_la_obra)` mientras
  el permiso esté vigente (y `remove_collision_exception_with` al revocarlo).
  Ver "Implementación de la colisión" más abajo.
- El permiso **se revoca al salir** del volumen y nunca se concede de nuevo:
  los mismos bloques que dejaban salir pasan a bloquear la entrada. Las
  caras externas son transitables solo hacia afuera y, sin permiso, son
  intransitables de afuera hacia adentro.
- **Los colonos con permiso evacúan** automáticamente: eligen la celda
  transitable más cercana fuera del volumen, calculan la ruta con
  `ignorar_fantasmas` y la recorren; no hacen otra cosa hasta salir.
- **Puerta de inicio de obra:** `VoxelWorld.surtir_construccion()` se niega
  (devuelve `{}`, con aviso al jugador: "hay alguien dentro del sitio; deben
  salir antes de iniciar la obra") mientras cualquier entidad conserve
  permiso vigente sobre esa obra. La regla se evalúa en el primer paso de
  la obra (cuando todavía todos sus bloques son fantasma), incluido el
  relleno y la excavación. Los obreros NPC futuros (sub-proyecto 3) usan la
  misma puerta.
- Un colono con permiso no elige destinos dentro del volumen; el avatar es el
  único que decide cuándo salir.
**Implementación de la colisión (decisión de diseño).** `GridMap` no permite
colisión por cara ni por celda: su colisión sale de las formas del ítem de la
`MeshLibrary`, en una sola capa por nodo. Por eso la idea de aplicar a las
caras externas del edificio un tránsito de un solo sentido (como el culling
de caras de los bloques translúcidos, que es solo visual) no se traslada
directamente a la colisión del avatar. Se hace así:

- El ítem `"fantasma"` de la `MeshLibrary` **pierde sus formas de colisión**;
  las celdas fantasma siguen en el `GridMap` (ocupación, render y
  `obtener_tipo()` no cambian).
- La colisión de los fantasmas la da un `StaticBody3D` **por obra**, hijo de
  `VoxelWorld`, con una forma de caja por celda fantasma pendiente. Se añaden
  y quitan formas al convertir una celda a bloque real o revertirla a
  fantasma (`_aplicar_paso_cola`, `_revertir_celda`, emplazar, eliminar). Sin
  celdas pendientes el cuerpo se libera.
- La exención por obra queda **exacta** (una excepción de colisión por
  cuerpo), en vez de global: dentro de una obra no se atraviesan los
  fantasmas de una obra vecina.

**Alternativa evaluada y no elegida:** un único cuerpo por obra con una malla
`ConcavePolygonShape3D` solo de sus caras externas, con normales hacia
afuera y `backface_collision = false`, que en teoría impediría entrar y
dejaría salir sin mantener permisos. No se elige porque el motor es
`GodotPhysics3D` y no está garantizado que el choque de una cápsula
(`CharacterBody3D`) con una malla cóncava respete `backface_collision` (esa
propiedad está documentada para colisión por ambos lados de una cara, pero
su efecto sobre el movimiento de un cuerpo depende del motor); habría que
comprobarlo con una prueba de humo. Aun si funcionara, el pathfinding
seguiría necesitando distinguir el interior del exterior. Si más adelante
se quiere simplificar, esta es la vía a explorar.

## Sección 5 — Pruebas y verificación

- **`BuscadorRutasTest`** (mundo falso determinista): ruta recta en llano;
  rodeo de un muro; subida de 1 bloque sí y de 2 no; caída de 3 sí y de 4
  no; agua de 1 bloque sí y de 2 no; puerta transitable; subirse a una
  cama; sin ruta devuelve `[]`; origen o destino no transitables; tope de
  nodos; determinismo; recálculo cuando una celda de la ruta se vuelve
  sólida a mitad de camino.
- **`CiudadTest`** (actualizado): claves renombradas; camas registradas al
  inicio de cada test que fija `demografia`; vivienda fraccionaria (ocupada
  y libre); migración (acumulador, bloqueo por hambruna, bloqueo por falta
  de vivienda); registro idempotente por id; capacidad que respeta los
  pisos y camas permitidos por nivel; desahucio por bajada de nivel; test 5
  reescrito contra camas reales; tests 7 y 8 con la nueva firma.
- **`ColonosTest`** (sin escena visual): reconciliación contra
  `demografia` (crear y retirar); hogar asignado por menor ocupación;
  reasignación al demoler; destino de deambular siempre transitable; espera
  y reintento sin destino; movimiento celda a celda determinista.
- **Evitación** (en `ColonosTest`): dos colonos no comparten celda;
  esperan y esquivan; abandonan destino si no hay ruta; esquivan la celda
  del avatar y la celda hacia la que avanza; no abandonan su destino solo
  porque el avatar pase cerca.
- **Fantasmas permeables** (en `ColonosTest`/`BuscadorRutasTest`, mundo
  falso): entidad con permiso cruza fantasma hacia afuera; sin permiso no
  cruza; el permiso se revoca al salir y no se recupera; un colono dentro
  evacúa; `surtir_construccion` se niega con alguien dentro y procede cuando
  todos salieron; se concede permiso al pasar un edificio completo a
  fantasma (deconstrucción); el cuerpo de colisión de la obra gana y pierde
  formas al surtir y revertir, y se libera al quedar sin fantasmas.
- **`BlueprintValidatorTest`** (ampliado): rechazo por exceso de pisos y de
  camas por piso, aceptación en el límite, según nivel.
- **Ejecución:** `godot/scenes/Test.tscn` con Godot 4.7 (obligatorio,
  CLAUDE.md), más `CiudadTest`, `BlueprintValidatorTest`, `BuscadorRutasTest`,
  `ColonosTest` y `ConstruccionTest` (por el cambio en `Player.gd`). Todas
  las aserciones deben pasar.
- **Verificación manual pendiente (no verificable en headless):** que en
  `Main.tscn` los colonos lleguen por el borde, entren a las casas, se
  paren sobre camas y no atraviesen paredes ni agua profunda; que se esquiven entre sí y al
  avatar sin huir de él; que el cuerpo del avatar se vea en la cenital y no
  en primera persona; y que al emplazar un blueprint sobre colonos o sobre
  el avatar puedan salir pero no volver a entrar.

## Documentación

- **GDD:** Sección 5 (camas por piso y pisos por casa según nivel: 2/2,
  4/4, 4/8; el límite de camas por piso pasa de pendiente a implementado);
  Sección 5 también documenta los fantasmas de obra permeables hacia afuera;
  Sección 6 (taxonomía de 7 tipos del Excel, "x Cama", migración); Sección
  11 (colonos completados en Fase 2; pathfinding adelantado desde Fase 5 y
  con A\* propio en vez de `NavigationServer3D`).
- **Documentos técnicos:** colonos en `PoC_4/` (donde la Fase 2 los dejó
  pendientes); pathfinding en una carpeta nueva `PoC_8/` (su número en el
  roadmap). La economía sigue en `PoC_5/`.
- **`docs/Recursos.xlsx`** no se modifica (trabajo en curso del usuario). Su
  hoja "Niveles" quedará desactualizada respecto a las camas por piso y
  pisos por casa nuevos.

## Diseño futuro documentado: deconstrucción marcada desde la cenital (tecla `G`)

**No se implementa en este sub-proyecto.** Se documenta aquí a petición del
usuario (2026-09-20) porque solo tiene sentido ahora que existen NPC, y se
implementaría con el sub-proyecto 3 (obreros NPC que construyen y
deconstruyen).

Hoy `G` en primera persona activa `Player.modo_deconstruccion`, y cada clic
sobre un edificio revierte un bloque a fantasma (`VoxelWorld.
procesar_deconstruccion()`); en la cámara cenital `G` no se usa. La idea:

- En la cenital, `G` activa el **modo de marcado de deconstrucción**, el
  opuesto de `B` (que emplaza un blueprint). Con el modo activo, un clic
  sobre un edificio lo **marca** para deconstruir. Sirve para edificios
  terminados, en obra o sin iniciar.
- Un edificio marcado avisa a los NPC: los obreros asignados se acercan y lo
  desmontan **bloque a bloque** hasta que el blueprint desaparece por
  completo. Reutiliza el mismo camino inverso que la deconstrucción manual
  (bloque real → fantasma → nada) y el pathfinding de este spec.
- Sigue valiendo que **el núcleo urbano no se puede deconstruir**
  (`Zonificacion.celda_es_del_nucleo`), y que la capacidad de camas del
  edificio se retira al **iniciar** su deconstrucción, no al terminarla.
- Encaja con la Sección 6: al empezar a desmontar un edificio completo, sus
  bloques vuelven a ser fantasma y se conceden permisos de salida a quien
  esté dentro; los colonos con permiso evacúan y los obreros no empiezan
  mientras quede alguien dentro de la obra.

**Preguntas abiertas (a resolver en el spec del sub-proyecto 3):**

1. Un blueprint **sin iniciar**: ¿se cancela al instante al marcarlo, o los
   NPC también retiran sus fantasmas uno a uno? (El usuario dijo "hasta que
   se elimine por completo el blueprint", lo que sugiere lo segundo.)
2. Si se **desmarca** un edificio a medio desmontar, ¿queda en el estado
   parcial en que estaba, o vuelve a reconstruirse?
3. **Materiales:** ¿la deconstrucción devuelve recursos al almacén, y cuántos?
   Depende del costo real por bloque del sub-proyecto 3. Igual para el
   terreno excavado, que el GDD ya deja como pendiente ("restaurar el
   terreno excavado al deconstruir").
4. **Sin obreros** disponibles: el marcado queda pendiente hasta que haya
   quien lo ejecute, y el jugador puede seguir deconstruyendo a mano con `G`
   en primera persona.

## Fuera de alcance

Trabajo/recolección/acarreo por NPC, almacenes, construcción por NPC,
entrenamiento, tecnologías, carreteras y carretas, consumo de combustible y
energía, natalidad y envejecimiento, negociación de prioridad entre colonos,
modelo definitivo del avatar y de los colonos (arte), casas de 12 pisos
(nivel máximo de desarrollo), pathfinding asíncrono o jerárquico, asignación de
capacidad por casa individual.

## Puntos a verificar al planificar

- Cómo obtiene `Player._completar_construccion` el id del edificio recién
  completado (`VoxelWorld.id_de_edificio()` sobre una celda de la
  construcción, o ampliar la metadata).
- Cómo trata la colisión del jugador a `puerta_inferior`/`puerta_superior`,
  para que el pathfinding las considere igual.
- Dónde se valida el blueprint al colocar una copia en `CamaraCenital.gd`,
  para añadir `validar_limites_vivienda` ahí.
- Cómo calcular la caja envolvente/celdas interiores de un hogar a partir de
  `edificio_a_celdas`.
- Qué celdas cuentan en el volumen de una obra (caja envolvente de
  `edificio_a_celdas` más las celdas de relleno/excavación) y cómo detectar
  qué colonos/avatar están dentro en el momento de emplazar.
- Cómo resuelve hoy `Player.gd` la celda apuntada por su raycast
  (minar/surtir): si asume que el colisionador es el `GridMap`, hay que
  admitir también el cuerpo fantasma de la obra (celda = posición del choque
  menos la normal), para que surtir y deconstruir un fantasma sigan
  funcionando.
- Que `CamaraCenital.gd` (que también hace picking del mundo) no dependa de
  la colisión de los fantasmas en el `GridMap`.
- Que la exención de colisión del avatar no interfiera con la natación,
  el salto ni la corriente de río.
- Coste de mantener un cuerpo de cajas por obra (centenares de formas por
  edificio); si pesa, fusionar las cajas por fila.
- Que la señal `tick_simulado` de `Ciudad` no rompa `CiudadTest`, que
  instancia `Ciudad` fuera del árbol de escena.

## Decisiones globales ya tomadas (sub-proyectos 2 a 6)

Confirmadas con el usuario el 2026-09-20; sus specs no deben volver a
preguntarlas.

- **Flujo de recursos (sub-proyecto 2):** almacén local por edificio con
  capacidad propia; los trabajadores de un puesto se reparten entre
  recolección y acarreo (decide el jugador); el acarreo lleva del almacén
  local al almacén más cercano. El núcleo urbano es el almacén central
  mientras no haya almacenes dedicados. Al conectarse el puesto por carretera
  con unidades de transporte, los acarreadores pasan a recolección. El panel
  de "control de recursos" muestra el total unificado de los almacenes
  conectados a la red, pero físicamente cada recurso está en un almacén
  concreto; una obra o industria necesita que alguien vaya a buscarlo. Los
  almacenes dedicados exigen carretera (aunque sea de tierra pisada) para
  contar en el panel, por lo que dependen del sub-proyecto 6.
  `PERSONAL_MAXIMO` (hoy 3) es dato de balance por definir; el usuario
  mencionó hasta 5 obreros en el maderero.
- **Agotamiento:** híbrido. Tierra, minerales, madera y petróleo se agotan
  porque se retiran bloques reales del mundo (el petróleo es un bloque
  fluido viscoso, aún inexistente en la generación del mundo). El agua no
  se agota (rinde según el nivel de la bomba). La comida (caza/recolección,
  pesca) no se agota, se recalcula periódicamente según el entorno (árboles,
  bloques de agua): un maderero cerca de un puesto de caza reduce su
  productividad. Un bosque puede consumirse por completo; es parte del reto
  (mantener un bosque virgen para caza), y una tecnología de reforestación
  vendrá más adelante.
- **Extracción física:** el maderero camina hasta el árbol; minas, canteras,
  excavación de tierra y pozos extraen desde el puesto, sin caminar al
  bloque (el bloque desaparece del área); caza/recolección y pesca no
  retiran bloques; el pozo de agua no retira bloques ni se agota.
- **Tasas:** las del Excel por recurso (p. ej. hierro 5/h, tierra 1/h),
  repartidas según la composición de bloques del área; reemplaza el 2.0
  genérico de `Recoleccion.gd`. Se mantiene la mina única del GDD.
- **Oficios:** Obrero, Técnico y Especialista los define el puesto al que se
  asigna un Desempleado (limitados por el nivel de ciudad: obrero desde el
  nivel 1, técnico desde el 2, especialista desde el 3). Investigador y
  Militar requieren entrenamiento previo en un edificio propio, con tiempo y
  costo en recursos, por catálogo de datos.
- **Construcción (sub-proyecto 3):** obreros NPC construyen según la
  fórmula del GDD (`Tiempo = (Suma del coste de bloques / Tasa base) / Nº de
  obreros`), y el jugador puede seguir surtiendo bloques a mano, pagando del
  mismo inventario. Costo en materia prima directa por tipo de bloque
  (puerta 2 madera, cama 2 madera, baúl 1 madera, vidrio 1 tierra); la
  fábrica de objetos que produciría esos ítems queda para más adelante.
- **Tecnologías (sub-proyecto 5):** catálogo por datos (costo en recursos y
  horas-investigador, prerrequisitos, efecto: desbloquear edificio, subir de
  nivel, mejorar una tasa, habilitar reforestación); investigación activa
  de una a la vez en un laboratorio.
- **Escasez:** la comida conserva la hambruna actual; combustible y energía
  dan eficiencia proporcional a lo recibido. Un edificio sin insumo
  suficiente produce menos, como en `CadenaMinerales.procesar_tick()`.
- **Tiempo:** 1 tick = 2 s reales = 1 hora de juego (`Ciudad.SEGUNDOS_POR_TICK`).

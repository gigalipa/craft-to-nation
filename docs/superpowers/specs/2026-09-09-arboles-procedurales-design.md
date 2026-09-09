# Diseño: Árboles Procedurales Talables (PoC 5, sub-proyecto siguiente a señales de bioma)

Contexto: GDD Sección 3.1 (categoría "Recolección": puestos madereros necesitan bosques reales). El sub-proyecto de señales de bioma (`es_bioma_en`, `densidad_fauna_en`, `densidad_frutal_en` en `GeneradorMundo.gd`) ya está completo y fusionado a `main`. Durante el brainstorming de ese sub-proyecto se aclaró que un árbol en Craft to Nation **no** es "un conjunto de bloques que se recogen uno por uno" (a diferencia de Minecraft): es un objeto generado proceduralmente por bloques (tronco + follaje, con formas variables como en Minecraft), pero que se comporta como **un solo objeto** con una salud igual a la madera extraíble — al talarlo progresivamente la salud baja, y solo cuando se agota toda la madera el árbol completo desaparece de golpe (no bloque por bloque).

## Alcance de esta etapa

- Generación procedural de la forma del árbol: tronco recto + copa esférica simple, con tamaño aleatorio dentro de un rango.
- Señal de densidad de árboles (`densidad_arbol_en`, cuarta señal en `GeneradorMundo.gd`, mismo patrón que fauna/frutal) y colocación real de árboles en `VoxelWorld` durante la generación del mundo, con espaciado mínimo para que las copas no se superpongan.
- Registro de árboles vivos con salud, y una función `talar_bloque_de_arbol()` que aplica daño y borra el árbol completo (todos sus bloques a la vez) al agotar la salud.
- **Fuera de alcance, documentado para un desarrollo futuro:**
  - Conectar la tala a la interacción real del jugador (`Player.gd`, tecla/clic de minar existente) — este sub-proyecto solo entrega el mecanismo (`talar_bloque_de_arbol`), probado de forma aislada.
  - Ramas irregulares/ramificaciones reales — esta versión usa tronco recto + copa esférica; una versión con ramas queda para cuando la variedad visual real (y un rendimiento de madera mucho mayor, 20-50 bloques) se necesite.
  - Que talar produzca un recurso real de madera en un inventario — el juego no tiene inventario de recursos todavía (mismo alcance reducido que el resto de PoC 5).
  - Puestos madereros consumiendo el registro de árboles — necesita que exista la mecánica de puestos de recolección extendida a madereros (fuera de alcance de este sub-proyecto).
  - Que el follaje cuente como madera extraíble — solo el tronco cuenta hacia la salud/rendimiento.

## Choque de escala resuelto durante el brainstorming

La cifra original de "20-50 bloques de madera por árbol" asumía una forma con ramas reales (más frondosa). Con la altura máxima real del mundo (`ALTURA_MAXIMA = 15`, nivel de mar ~5, banda de bioma hasta ~9), un tronco de 20-50 bloques de alto sería varias veces más alto que la montaña más alta del mundo. Se redujo el rango de altura a `[3, 8]` bloques para esta versión, y se agregó variación de **ancho** del tronco (lado del cuadrado en columnas, `[1, 2]` — reducido desde `[1, 4]` tras feedback visual, ver Sección 1) — un tronco ancho y bajo puede acumular tanta madera como uno alto y delgado, sin necesitar una altura irreal. Las ramas reales quedan como objetivo de una versión futura.

**Corrección posterior (feedback jugando en el editor real):** la primera implementación interpretó "ancho 1 a 4" como el radio de un disco euclidiano (`dx²+dz² <= radio²`), lo cual para radio 4 produce un tronco de ~9 celdas de diámetro (área ≈49) — mucho más grueso de lo previsto. La intención real era "1 a 4 columnas de lado", es decir, un tronco cuadrado de hasta 4×4 = 16 columnas. Corregido a un cuadrado (`LADO_TRONCO_MIN/MAX`, ver Sección 1) en vez de un disco.

## 1. Forma del árbol

Nueva clase pura `GeneradorArbol.gd` (`godot/scripts/`, sin nodos de escena, mismo patrón que `GeneradorMundo.gd`/`NiveladorTerreno.gd`).

Constantes:

```gdscript
const ALTURA_TRONCO_MIN := 3
const ALTURA_TRONCO_MAX := 8
const LADO_TRONCO_MIN := 1
const LADO_TRONCO_MAX := 2
```

`generar_forma_aleatoria(semilla_arbol: int) -> Dictionary`:

1. Usa un `RandomNumberGenerator` sembrado con `semilla_arbol` para elegir `altura_tronco` en `[ALTURA_TRONCO_MIN, ALTURA_TRONCO_MAX]` y `lado_tronco` en `[LADO_TRONCO_MIN, LADO_TRONCO_MAX]` (ambos inclusive). `radio_follaje` no tiene rango propio: es `radio_follaje = lado_tronco` (proporcional al tronco, para que la copa nunca quede más angosta que el tronco que la sostiene — corregido tras feedback visual; placeholder simple, a futuro esta relación podrá variar por tipo de bioma).
2. El tronco ocupa, para cada `y` en `[0, altura_tronco - 1]`, un cuadrado de `lado_tronco × lado_tronco` columnas: todo offset `Vector3i(dx, y, dz)` con `dx` y `dz` en `[0, lado_tronco - 1]` — un cuadrado, no un disco euclidiano (con `lado_tronco = 4` esto da 16 columnas por nivel, no las ~49 de un disco de radio 4). Todos estos offsets son tipo `"tronco"`.
3. El follaje es un blob esférico simple centrado en `Vector3i((lado_tronco-1)/2, altura_tronco, (lado_tronco-1)/2)` (el punto medio del cuadrado del tronco, división entera — con `lado_tronco` par el centro cae medio bloque desviado hacia la esquina `(0,0)`, aproximación suficiente para un placeholder; justo encima del nivel más alto del tronco): todo offset `(dx, dy, dz)` cuya distancia euclidiana al centro sea `<= radio_follaje`, tipo `"follaje"`, **excluyendo** cualquier offset que ya sea tronco (no hay superposición vertical real entre los dos bloques, ya que el follaje empieza en el nivel `altura_tronco`, uno por encima del tronco más alto — la exclusión es una salvaguarda, no algo que se espere disparar en la práctica).
4. Devuelve un `Dictionary` (`Vector3i` → `String`, `"tronco"` o `"follaje"`) con todos los offsets relativos a la base del árbol (`Vector3i(0,0,0)` es la esquina de la capa de tronco más baja).

Completamente determinista: la misma `semilla_arbol` produce siempre la misma forma exacta (misma altura, mismo lado de tronco, mismo radio de follaje, mismos offsets).

`medir_pisada(semilla_arbol: int) -> Dictionary`: devuelve `{"altura_tronco", "lado_tronco", "radio_follaje"}` — los mismos tres valores que produciría `generar_forma_aleatoria()` para la misma semilla, pero sin construir el `Dictionary` completo de offsets. Ambas funciones comparten la misma elección de parámetros internamente (mismo orden de llamadas a `RandomNumberGenerator`), así que siempre coinciden. La usa `VoxelWorld._generar_arboles()` (Sección 2) para decidir el espaciado antes de generar el árbol completo.

La **salud** del árbol es el número total de offsets tipo `"tronco"` generados (`altura_tronco * lado_tronco²` — varía con `altura_tronco` y `lado_tronco` juntos, un tronco ancho y bajo puede tener tanta madera como uno alto y delgado). El follaje es cosmético, no rinde recurso ni cuenta hacia la salud.

## 2. Señal de densidad y colocación en el mundo

`GeneradorMundo.gd` gana una cuarta señal de densidad, mismo patrón que `densidad_fauna_en`/`densidad_frutal_en`:

- Variable nueva `_ruido_arbol: FastNoiseLite`, semilla `semilla + 4` (no colisiona con `_ruido`, `_ruido_mineral` semilla+1, `_ruido_fauna` semilla+2, `_ruido_frutal` semilla+3), frecuencia `0.05` (mismo valor inicial que las otras dos señales).
- `densidad_arbol_en(x: int, z: int) -> float`: `0.0` si `es_bioma_en(x,z)` es falso; si no, `_ruido_arbol.get_noise_2d(x,z)` remapeado linealmente de `[-1,1]` a `[0,1]` (sin curva de redistribución, igual que fauna/frutal).

`VoxelWorld.gd` gana una pasada nueva, `_generar_arboles()`, llamada después de `_generar_terreno()` en `_ready()`:

1. Recorre las columnas `(x, z)` del mundo en orden.
2. Si `generador.densidad_arbol_en(x, z) > UMBRAL_ARBOL` (constante nueva, `0.5` como punto de partida a calibrar empíricamente — mismo patrón que `UMBRAL_HIERRO`/`EXPONENTE_RELIEVE`), mide el tamaño real que tendría el árbol en esa columna con `arboles.medir_pisada(semilla_arbol)` (ver Sección 1) **antes** de generarlo — sin construir la forma completa.
3. Con ese tamaño, calcula la huella del candidato: el cuadrado de tronco (`[x, x+lado_tronco-1] × [z, z+lado_tronco-1]`) y el centro/radio de su copa de follaje. Compara contra los árboles ya colocados en esta misma pasada: rechaza el candidato si su cuadrado de tronco, expandido por `GAP_MINIMO_TRONCOS` celdas en cada dirección, se solaparía con el cuadrado de algún árbol ya colocado (chequeo de cajas alineadas a los ejes, no de distancia entre centros — dos cuadrados pueden tocarse en una esquina sin que sus centros estén cerca), **o** si sus copas de follaje se solaparían más de `SOLAPE_MAXIMO_COPAS` celdas (`(radio_A + radio_B) - distancia_entre_centros > SOLAPE_MAXIMO_COPAS`).
   - `GAP_MINIMO_TRONCOS` (constante nueva, `2` — calibrada empíricamente tras feedback jugando en el editor real: los troncos nunca deben quedar pegados, para que el jugador y los NPCs puedan caminar entre los árboles del bosque).
   - `SOLAPE_MAXIMO_COPAS` (constante nueva, `1` — a diferencia de `GAP_MINIMO_TRONCOS`, esto es puramente estético; a futuro dependerá del tipo de bioma, p. ej. una selva húmeda tolera copas más solapadas que una sabana).
4. Si el candidato pasa ambos chequeos, la base del árbol es `Vector3i(x, generador.altura_en(x,z) + 1, z)` — la celda justo encima de la superficie de esa columna (usa el heightmap puro de `generador.altura_en()`, no `VoxelWorld.altura_en()`: esta última buscaría la celda sólida más alta real del `GridMap`, que en una columna vecina ya cubierta por el tronco o follaje ancho de un árbol previamente colocado devolvería esa altura de follaje y plantaría el árbol nuevo flotando en el aire).
5. Genera la forma con `arboles.generar_forma_aleatoria(semilla_arbol)`, donde `semilla_arbol` se deriva deterministamente de `(SEMILLA_MUNDO, x, z)` (p. ej. `SEMILLA_MUNDO + x * LARGO_MUNDO + z`, sin colisión con las semillas de `GeneradorMundo` porque es un espacio de valores distinto — no se usa como `.seed` de ningún `FastNoiseLite`, solo como semilla del `RandomNumberGenerator` de `GeneradorArbol`; `medir_pisada()` y `generar_forma_aleatoria()` usan la misma secuencia de `RandomNumberGenerator`, así que predicen exactamente el mismo tamaño).
6. Traduce cada offset relativo a una celda absoluta (`base + offset`), coloca el bloque real (`colocar_bloque`) con el tipo correspondiente (`"tronco"` o `"follaje"`), y registra el árbol completo (`arboles.registrar(celdas_mundiales, altura_tronco)`).

**Corrección posterior (feedback jugando en el editor real):** la primera versión de esta pasada solo comparaba la distancia entre las bases de los árboles contra una constante fija (`ESPACIADO_MINIMO_ARBOL := 3`), sin conocer el tamaño real de cada árbol candidato — los árboles terminaban naciendo demasiado juntos, con troncos pegados entre sí, sin espacio transitable para el jugador ni los NPCs. Corregido al algoritmo de arriba, que mide la huella real antes de decidir si el candidato cabe.

Dos bloques placeholder nuevos en la `MeshLibrary` (`BlockLibrarySource.tscn` → regenerar `BlockLibrary.res`), mismo patrón que `tierra`/`piedra`/`hierro`/`agua`: `"tronco"` (color plano marrón) y `"follaje"` (color plano verde), sin transparencia ni textura real.

## 3. Registro, salud y tala

`GeneradorArbol.gd` también guarda el registro de árboles vivos (misma clase pura, sin nodos de escena):

- `registrar(celdas_mundiales: Array, salud_maxima: int) -> int`: asigna un id incremental nuevo, guarda `{"celdas": celdas_mundiales, "salud": salud_maxima}`, y para cada celda en `celdas_mundiales` (tronco y follaje) registra `celda → id` en un índice inverso. Devuelve el id asignado.
- `obtener_arbol_de(celda: Vector3i) -> int`: `-1` si la celda no pertenece a ningún árbol registrado; si no, el id de su árbol.
- `celdas_de(id: int) -> Array`: todas las celdas mundiales (tronco y follaje) del árbol con ese id.
- `danar(id: int, dano: int) -> bool`: resta `dano` a la salud interna del árbol `id`; devuelve `true` si la salud quedó en `0` o menos ("completamente talado"), `false` si el árbol sigue con salud restante. No hace nada más — no borra bloques ni el registro (eso lo hace el llamador).
- `eliminar(id: int) -> void`: limpia el registro del árbol `id` (su entrada y todas sus celdas del índice inverso).

`VoxelWorld.gd` mantiene una instancia (`var arboles: RefCounted`, mismo patrón que `var generador: RefCounted`) y agrega:

```
func talar_bloque_de_arbol(celda: Vector3i, dano: int) -> bool
```

Busca `arboles.obtener_arbol_de(celda)`; si es `-1`, no hace nada y devuelve `false`. Si hay un árbol, llama a `arboles.danar(id, dano)`; si devuelve `true` (talado completo), borra del `GridMap` cada celda de `arboles.celdas_de(id)` (`set_cell_item` a `GridMap.INVALID_CELL_ITEM`, igual que `minar_bloque()` pero sin la lógica de `pareja`/`colocado_por_jugador`, que no aplica a árboles generados por el mundo) y llama a `arboles.eliminar(id)`. Devuelve lo que devolvió `danar()` (si el árbol quedó talado o no).

Mientras la salud no llegue a `0`, ningún bloque del árbol se toca — el árbol se ve exactamente igual durante toda la tala progresiva, y desaparece completo de una sola vez al agotarse. Esto es intencional: el árbol se comporta como un objeto único, no como bloques individuales minables.

## Pruebas

Nuevas pruebas en un archivo `GeneradorArbolTest.gd` (mismo patrón que `GeneradorMundoTest.gd`, corrido vía una escena `GeneradorArbolTest.tscn`):

- `generar_forma_aleatoria` es determinista para la misma `semilla_arbol` (misma altura de tronco, mismo lado de tronco, mismo radio de follaje, mismos offsets exactos).
- Todo offset tipo `"tronco"` tiene `y` en `[0, altura_tronco - 1]`, `dx` en `[0, lado_tronco - 1]` y `dz` en `[0, lado_tronco - 1]`; no hay offsets `"tronco"` fuera de ese rango de altura ni de ese cuadrado horizontal.
- El follaje generado nunca pisa una celda de tronco (ninguna celda es a la vez `"tronco"` y `"follaje"`).
- La salud devuelta al registrar coincide exactamente con la cantidad de offsets tipo `"tronco"` en la forma generada (no con `altura_tronco` sola, ya que ahora depende también de `lado_tronco`).
- `registrar`/`obtener_arbol_de`/`celdas_de` son consistentes: toda celda pasada a `registrar` devuelve el id correcto desde `obtener_arbol_de`, y `celdas_de(id)` devuelve exactamente el conjunto original.
- `danar` reduce la salud correctamente y devuelve `true` solo cuando la salud acumulada dañada alcanza o supera la salud máxima (p. ej. un árbol de salud 5 dañado con 2 y luego con 2 debe devolver `false` la primera vez y `true` la segunda con un daño de 2 más, o `true` de inmediato con un daño de 5 o más).
- `obtener_arbol_de` devuelve `-1` para una celda que nunca fue registrada.
- `medir_pisada(semilla_arbol)` predice exactamente la misma `altura_tronco`/`lado_tronco` que produce `generar_forma_aleatoria(semilla_arbol)` para la misma semilla.
- `radio_follaje == lado_tronco` en toda semilla muestreada (la copa nunca queda más angosta que el tronco).

Pruebas nuevas en `GeneradorMundoTest.gd` (continuando la numeración desde el Test 14 existente):

- `densidad_arbol_en` es determinista, está en `[0,1]`, y es exactamente `0.0` fuera del bioma (mismo patrón que los tests de fauna/frutal).

Verificación en `VoxelWorld` (vía `mcp__godot__run_project` sobre `Main.tscn`, headless): el mundo real (200×200) genera sin errores nuevos con la pasada de árboles agregada; `Test.tscn` y `GeneradorMundoTest.tscn` siguen pasando sin cambios de comportamiento. La confirmación visual real (formas de árbol razonables, espaciado sin superposición de copas) queda pendiente de revisión jugando en el editor real, mismo patrón que el resto de PoC 5.

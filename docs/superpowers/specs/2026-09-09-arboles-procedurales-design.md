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

La cifra original de "20-50 bloques de madera por árbol" asumía una forma con ramas reales (más frondosa). Con la forma simple de esta etapa (tronco recto sin ramas) y la altura máxima real del mundo (`ALTURA_MAXIMA = 15`, nivel de mar ~5, banda de bioma hasta ~9), un tronco de 20-50 bloques sería varias veces más alto que la montaña más alta del mundo. Se redujo el rango a `[3, 8]` bloques de tronco (= salud del árbol) para esta versión — los 20-50 bloques quedan como objetivo de una versión futura con ramas reales.

## 1. Forma del árbol

Nueva clase pura `GeneradorArbol.gd` (`godot/scripts/`, sin nodos de escena, mismo patrón que `GeneradorMundo.gd`/`NiveladorTerreno.gd`).

Constantes:

```gdscript
const ALTURA_TRONCO_MIN := 3
const ALTURA_TRONCO_MAX := 8
const RADIO_FOLLAJE_MIN := 1
const RADIO_FOLLAJE_MAX := 2
```

`generar_forma_aleatoria(semilla_arbol: int) -> Dictionary`:

1. Usa un `RandomNumberGenerator` sembrado con `semilla_arbol` para elegir `altura_tronco` en `[ALTURA_TRONCO_MIN, ALTURA_TRONCO_MAX]` y `radio_follaje` en `[RADIO_FOLLAJE_MIN, RADIO_FOLLAJE_MAX]` (ambos inclusive).
2. El tronco ocupa los offsets `Vector3i(0, y, 0)` para `y` en `[0, altura_tronco - 1]`, tipo `"tronco"`.
3. El follaje es un blob esférico simple centrado en `Vector3i(0, altura_tronco, 0)` (justo encima del tronco): todo offset `(dx, dy, dz)` cuya distancia euclidiana al centro sea `<= radio_follaje`, tipo `"follaje"`, **excluyendo** cualquier offset que ya sea tronco (para no pisarlo).
4. Devuelve un `Dictionary` (`Vector3i` → `String`, `"tronco"` o `"follaje"`) con todos los offsets relativos a la base del árbol (`Vector3i(0,0,0)` es la celda de tronco más baja).

Completamente determinista: la misma `semilla_arbol` produce siempre la misma forma exacta (mismo `altura_tronco`, mismo `radio_follaje`, mismos offsets).

`altura_tronco` es también la **salud** del árbol (número de bloques de "tronco" — el único material que cuenta como madera extraíble; el follaje es cosmético, no rinde recurso).

## 2. Señal de densidad y colocación en el mundo

`GeneradorMundo.gd` gana una cuarta señal de densidad, mismo patrón que `densidad_fauna_en`/`densidad_frutal_en`:

- Variable nueva `_ruido_arbol: FastNoiseLite`, semilla `semilla + 4` (no colisiona con `_ruido`, `_ruido_mineral` semilla+1, `_ruido_fauna` semilla+2, `_ruido_frutal` semilla+3), frecuencia `0.05` (mismo valor inicial que las otras dos señales).
- `densidad_arbol_en(x: int, z: int) -> float`: `0.0` si `es_bioma_en(x,z)` es falso; si no, `_ruido_arbol.get_noise_2d(x,z)` remapeado linealmente de `[-1,1]` a `[0,1]` (sin curva de redistribución, igual que fauna/frutal).

`VoxelWorld.gd` gana una pasada nueva, `_generar_arboles()`, llamada después de `_generar_terreno()` en `_ready()`:

1. Recorre las columnas `(x, z)` del mundo en orden.
2. Si `generador.densidad_arbol_en(x, z) > UMBRAL_ARBOL` (constante nueva, `0.5` como punto de partida a calibrar empíricamente — mismo patrón que `UMBRAL_HIERRO`/`EXPONENTE_RELIEVE`) **y** la columna está a más de `ESPACIADO_MINIMO_ARBOL` celdas de distancia horizontal (constante nueva, `3`) de la base de cualquier árbol ya colocado en esta misma pasada, coloca un árbol.
3. La base del árbol es `Vector3i(x, altura_en(x,z) + 1, z)` — la celda justo encima de la superficie de esa columna (reutiliza `altura_en()`, que ya busca la celda sólida más alta real).
4. Genera la forma con `arboles.generar_forma_aleatoria(semilla_arbol)`, donde `semilla_arbol` se deriva deterministamente de `(SEMILLA_MUNDO, x, z)` (p. ej. `SEMILLA_MUNDO + x * LARGO_MUNDO + z`, sin colisión con las semillas de `GeneradorMundo` porque es un espacio de valores distinto — no se usa como `.seed` de ningún `FastNoiseLite`, solo como semilla del `RandomNumberGenerator` de `GeneradorArbol`).
5. Traduce cada offset relativo a una celda absoluta (`base + offset`), coloca el bloque real (`colocar_bloque`) con el tipo correspondiente (`"tronco"` o `"follaje"`), y registra el árbol completo (`arboles.registrar(celdas_mundiales, altura_tronco)`).

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

- `generar_forma_aleatoria` es determinista para la misma `semilla_arbol` (misma altura de tronco, mismo radio de follaje, mismos offsets exactos).
- El tronco generado siempre tiene entre `ALTURA_TRONCO_MIN` y `ALTURA_TRONCO_MAX` bloques, todos tipo `"tronco"`, en `Vector3i(0, y, 0)` para `y` de `0` a `altura_tronco - 1`.
- El follaje generado nunca pisa una celda de tronco (ninguna celda es a la vez `"tronco"` y `"follaje"`).
- `registrar`/`obtener_arbol_de`/`celdas_de` son consistentes: toda celda pasada a `registrar` devuelve el id correcto desde `obtener_arbol_de`, y `celdas_de(id)` devuelve exactamente el conjunto original.
- `danar` reduce la salud correctamente y devuelve `true` solo cuando la salud acumulada dañada alcanza o supera la salud máxima (p. ej. un árbol de salud 5 dañado con 2 y luego con 2 debe devolver `false` la primera vez y `true` la segunda con un daño de 2 más, o `true` de inmediato con un daño de 5 o más).
- `obtener_arbol_de` devuelve `-1` para una celda que nunca fue registrada.

Pruebas nuevas en `GeneradorMundoTest.gd` (continuando la numeración desde el Test 14 existente):

- `densidad_arbol_en` es determinista, está en `[0,1]`, y es exactamente `0.0` fuera del bioma (mismo patrón que los tests de fauna/frutal).

Verificación en `VoxelWorld` (vía `mcp__godot__run_project` sobre `Main.tscn`, headless): el mundo real (200×200) genera sin errores nuevos con la pasada de árboles agregada; `Test.tscn` y `GeneradorMundoTest.tscn` siguen pasando sin cambios de comportamiento. La confirmación visual real (formas de árbol razonables, espaciado sin superposición de copas) queda pendiente de revisión jugando en el editor real, mismo patrón que el resto de PoC 5.

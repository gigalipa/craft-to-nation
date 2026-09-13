# Diseño: Ríos con Corriente y Cascadas (PoC 6, sub-proyecto 4 — extensión)

Contexto: GDD Sección 11 (Fase 3, PoC 6) — extiende el sub-proyecto 4 (Generación de Cuerpos de Agua), que documentó explícitamente esta pieza como "fuera de alcance, para un desarrollo futuro" (ver `docs/superpowers/specs/2026-09-08-cuerpos-de-agua-design.md`, sección "Alcance de esta etapa"). El agua hoy es un único criterio estático (nivel de mar por percentil, `GeneradorMundo.nivel_mar`/`es_agua_en()`): cualquier columna por debajo del nivel de mar se inunda, sin concepto de cauce, conexión ni dirección de flujo. Esta pieza agrega cauces reales que conectan tierras altas con el mar/lagos existentes, con ancho y profundidad variables, cascadas, resolución de cruces entre ríos, y dos cambios de comportamiento de TODA el agua (no solo ríos): deja de ser sólida para minado/colocación, y baja su opacidad para depuración visual.

Código existente que esta pieza extiende: `godot/scripts/GeneradorMundo.gd` (`altura_en()`, `nivel_mar`, `es_agua_en()`), `godot/scripts/VoxelWorld.gd` (`_generar_terreno()`, `colocar_bloque()`, `minar_bloque()`), `godot/scripts/Player.gd` (raycast de minado/colocación), `godot/scenes/BlockLibrarySource.tscn` (bloque `"agua"`), y el patrón de RNG sembrado de `godot/scripts/GeneradorArbol.gd` (`RandomNumberGenerator` con `.seed` derivado de la semilla del mundo).

## Alcance de esta etapa

- Cauces trazados por descenso por gradiente desde un número fijo de nacientes en tierras altas hasta el nivel de mar/lagos ya existentes.
- Ancho fijo por río (entre 2 y 6 bloques, elegido al nacer) con perfil de profundidad variable (borde 1 bloque, centro hasta 3), tallado real en el terreno.
- Cascadas: dato (ubicación + salto de altura), sin bloque visual ni efecto de jugabilidad todavía — mismo criterio de "pulido pendiente" que el resto de bloques placeholder del proyecto.
- **Cruce entre ríos (ver Sección 2b):** cuando dos cauces se cruzan, el más angosto termina ahí (se trunca) y solo continúa el más ancho; en empate de ancho, continúa el que nació a mayor altura.
- **Agua no sólida para minado/colocación (ver Sección 7), aplica a TODA el agua** (mar, lagos y ríos, no solo esta pieza): el jugador ya no puede minar agua ni colocarla como si fuera un bloque sólido normal; el raycast de minería/colocación la atraviesa y encuentra el bloque sólido real debajo, y colocar un bloque nuevo ahí sustituye el agua.
- **Opacidad de depuración (ver Sección 8):** el bloque `"agua"` baja su opacidad para que el fondo sea visible al jugar — facilita verificar visualmente el relieve/cauces mientras no exista un material de agua real.
- **Fuera de alcance, documentado para un desarrollo futuro:** cauces sinuosos (curvas reales de río, no limitados a los 4 ejes cardinales del grid) — esta etapa traza el cauce como una secuencia de pasos ortogonales (N/S/E/O) por simplicidad; un desarrollo posterior podría suavizar el trazado o usar un algoritmo de meandros. También fuera de alcance: bloque visual distinto para agua con corriente/cascada, efecto de jugabilidad más allá de la solidez (velocidad, arrastre, ahogamiento, natación), y que ríos generen afluentes reales (solo se resuelven cruces, no confluencias con cambio de curso).

## 1. Selección de nacientes

`GeneradorMundo._init()` ya calcula `nivel_mar` recorriendo la distribución de alturas del mundo (`_calcular_nivel_mar()`). Esta pieza reutiliza ese mismo recorrido para además:

1. Recolectar todas las columnas `(x, z)` con `altura_en(x, z) >= ALTURA_MAXIMA - MARGEN_NACIENTE_RIO` (constante nueva, valor `6` — calibrado jugando en vivo: con `3` solo calificaban las cumbres más altas del mundo, casi sin ríos visibles; con `6`, altura `>= 9`, también nacen ríos de colinas medias) como candidatas a naciente.
2. Con un `RandomNumberGenerator` sembrado (`.seed = semilla + 5`, siguiente hueco libre en la convención `semilla + N` que ya usan `_ruido_mineral`/`_ruido_fauna`/`_ruido_frutal`/`_ruido_arbol`), elegir hasta `NUM_RIOS` (constante nueva, valor `6`) candidatas al azar sin repetición como nacientes reales. Después de cada elección, se descartan del resto del sorteo todas las candidatas a menos de `MIN_DISTANCIA_NACIENTES` (constante nueva, valor `20`, distancia en línea recta) de la naciente recién elegida — evita que varios ríos nazcan de la misma montaña. Este filtro no consume el `RandomNumberGenerator`, así que no afecta el determinismo de los sorteos siguientes. Si el terreno alto está muy concentrado (pocas candidatas iniciales, o se agotan por el filtro de distancia), se generan menos de `NUM_RIOS` ríos — no es un error.
3. El mismo RNG (mismo objeto, mismo orden de llamadas — determinismo por semilla) elige a continuación, para cada naciente, su `ancho` con `rng.randi_range(ANCHO_MINIMO_RIO, ANCHO_MAXIMO_RIO)` (constantes nuevas, `2` y `6`).

## 2. Trazado del cauce (descenso por gradiente)

Desde cada naciente, en un método nuevo `_trazar_rio(origen: Vector2i) -> Array[Vector2i]`:

1. Empezar en `origen`, con un `Dictionary` de celdas visitadas (evita ciclos en mesetas).
2. En cada paso, evaluar las 4 celdas vecinas ortogonales (N/S/E/O) no visitadas. Si ninguna tiene `altura_en()` estrictamente menor que la celda actual, el cauce termina ahí (mesa/valle cerrado sin salida). `_trazar_rio()` en sí mismo devuelve ese cauce parcial tal cual — la decisión de qué hacer con un cauce que no llegó a agua se toma después, en `_generar_rios()` (ver el final de la Sección 2b): se descarta por completo, no se talla ni se marca nada de él.
3. Si hay una o más vecinas más bajas, moverse a la de menor altura (empate: la primera en el orden N/E/S/O, determinista).
4. El cauce termina exitosamente al entrar a una celda con `es_agua_en()` verdadero (llegó al mar o a un lago ya existente) — esa celda de agua se incluye como último elemento del cauce, pero no se tala ni se le agrega ancho/profundidad (ya es agua).
5. Tope de seguridad `MAX_PASOS_RIO` (constante nueva, valor inicial `ancho_mundo + largo_mundo`, cota superior generosa de cualquier camino simple en el grid) para evitar recorridos patológicos.

## 2b. Resolución de cruces entre ríos

El trazado de la Sección 2 se ejecuta para las `NUM_RIOS` nacientes de forma completamente independiente (el descenso por gradiente de un río no consulta ni se ve afectado por los demás — su forma depende solo del relieve). Después de trazar los `NUM_RIOS` cauces crudos, se resuelven los cruces en un paso aparte, antes de aplicar ancho/profundidad (Sección 3) o tallar nada (Sección 4):

1. **Definición de "cruce":** dos ríos se cruzan cuando sus cauces CENTRALES (la secuencia de celdas de la Sección 2, antes de aplicar el ancho) comparten una misma celda `(x, z)`. El ancho/franja perpendicular de un río no se considera para detectar cruces (simplificación documentada — dos cauces centrales que no se tocan pero cuyas franjas se solaparían no se tratan como cruce en esta etapa).
2. **Fuerza de un río:** tupla `(ancho, altura_en(nacimiento), -índice_de_generación)`, comparada en ese orden (mayor ancho gana; en empate, mayor altura de nacimiento; en empate total, el río generado primero — menor índice en el orden de la Sección 1 — gana). Da un orden total estricto entre los `NUM_RIOS` ríos, sin empates posibles.
3. **Dueño de cada celda:** se recorren los ríos de mayor a menor fuerza; cada celda del cauce crudo de un río que todavía no tenga dueño se le asigna a ese río. Una celda ya asignada a un río más fuerte no cambia de dueño.
4. **Truncado:** el cauce final de cada río es el prefijo de su cauce crudo (desde la naciente) hasta la ÚLTIMA celda de la que sigue siendo dueño (inclusive) — la primera celda cuyo dueño es otro río corta el cauce ahí ("el cauce menos ancho termina allí"). Un río más fuerte que cruza el cauce de uno más débil nunca se trunca por ese cruce (solo lo truncaría un río aún más fuerte que él mismo, en un cruce distinto).
5. El ancho/profundidad (Sección 3) y las cascadas (Sección 5) de cada río se calculan únicamente sobre su cauce YA truncado — un río truncado nunca talla ni marca celdas más allá de su punto de corte.
6. **Descarte de cauces sin desembocadura (decisión tomada jugando en vivo, ver `docs/superpowers/plans/`):** si la ÚLTIMA celda del cauce ya truncado no es agua (`es_agua_en()` falso) — porque terminó en una mesa/valle cerrado, o porque un cruce lo truncó antes de llegar al agua que sí alcanzaba su cauce crudo — el río completo se descarta: no se le aplica ancho/profundidad (Sección 3) ni se marcan sus cascadas (Sección 5). Un cauce que no conecta tierras altas con el mar/lago no se ve como un arroyo real, se ve como un error visual (un trazo suelto en medio del terreno) — más importante que "aprovechar" el trabajo de trazado ya hecho.

## 3. Ancho y perfil de profundidad

Para cada paso del cauce (excluyendo la celda final de agua ya existente, ver 2.4), se calcula una franja perpendicular a la dirección de avance local:

- Dirección de avance = vector unitario entre la celda anterior y la actual (para la naciente misma, entre la naciente y su primer paso). Como los pasos son ortogonales, la perpendicular es siempre el eje contrario (avance en X → franja en Z; avance en Z → franja en X) — no hace falta manejar diagonales.
- Offsets de la franja: `desde = -(ancho / 2)` (división entera) hasta `desde + ancho - 1`, es decir `ancho` offsets consecutivos centrados aproximadamente en la celda del cauce (para anchos impares, la celda del cauce cae exactamente en el offset 0; para anchos pares, queda ligeramente descentrada — asimetría aceptada, no afecta el resultado visual a esta escala de bloques).
- Profundidad por posición `i` dentro de la franja (`i` = índice 0-based del offset, en orden ascendente): `profundidad(i) = min(min(i, ancho - 1 - i) + 1, PROFUNDIDAD_MAXIMA_RIO)` (constante nueva, valor `3`). Da los perfiles: ancho 2 → `[1,1]`; ancho 3 → `[1,2,1]`; ancho 4 → `[1,2,2,1]`; ancho 5 → `[1,2,3,2,1]`; ancho 6 → `[1,2,3,3,2,1]`.
- Una celda de la franja que ya sea parte de otro río o que ya esté bajo el mar/lago (`es_agua_en()` verdadero) se omite (no se re-talla ni se reduce su profundidad ya existente).

## 4. Talla real en `VoxelWorld._generar_terreno()`

Para cada celda `(x, z)` de una franja de río con profundidad `d`, en vez de colocar el bloque de superficie normal (`"piso"`) y continuar con subsuelo debajo:

1. La altura natural `h = generador.altura_en(x, z)` no cambia (el algoritmo de relieve no se toca).
2. Se rellena de `"agua"` el rango `[h - d + 1, h]` (ambos inclusive) — `d` bloques de agua, con la superficie del agua siempre en `h` (a ras con la orilla, sea esta tierra firme fuera de la franja o el borde `d=1` de la propia franja).
3. El subsuelo natural que habría ocupado ese rango (tierra/piedra/hierro según `tipo_en_profundidad()`) no se coloca — se sustituye enteramente por agua. Por debajo de `h - d + 1` continúa el subsuelo normal, sin cambios.
4. Una celda con `d = 1` (borde de cualquier río, o todo el ancho de un río de ancho 2) es exactamente el modelo de relleno de una celda de mar/lago ya existente (un único bloque de agua en la superficie) — no se talla nada debajo.

## 5. API nueva de `GeneradorMundo`

- `es_rio_en(x: int, z: int) -> bool` — true si `(x, z)` cae dentro de la franja de algún río (naciente, cauce, o su ancho perpendicular), false en cualquier otro caso (incluida agua de mar/lago que no sea parte de un cauce).
- `direccion_flujo_en(x: int, z: int) -> Vector2i` — dirección unitaria (`Vector2i` con componentes en `{-1,0,1}`, una sola componente no nula) hacia la siguiente celda del cauce en esa columna; `Vector2i.ZERO` si `es_rio_en()` es falso o es la celda final (desembocadura). Las celdas de la franja perpendicular a una celda del cauce heredan la misma dirección que esa celda del cauce.
- `profundidad_rio_en(x: int, z: int) -> int` — profundidad tallada en esa celda (1 a `PROFUNDIDAD_MAXIMA_RIO`), `0` si `es_rio_en()` es falso.
- `es_cascada_en(x: int, z: int) -> bool` — true si el paso del cauce que pasa por `(x, z)` (o cuya franja incluye `(x, z)`) tiene una caída de altura `>= UMBRAL_CASCADA` (constante nueva, valor inicial `3`) hacia la siguiente celda del cauce.

Las cuatro consultas son de solo lectura sobre estructuras calculadas una única vez en `_init()` (mismo patrón que `nivel_mar`/`es_agua_en()`) — ningún consumidor futuro (puentes de PoC 10, logística) recalcula el trazado.

## 6. Agua no sólida para minado/colocación

Este cambio aplica a **todo** bloque `"agua"` del mundo (mar, lagos y ríos), no solo a las celdas nuevas de esta pieza — es un cambio de comportamiento general que se hace en el mismo momento porque los ríos son los primeros cuerpos de agua con relieve interesante para depurar visualmente.

- **`godot/scenes/BlockLibrarySource.tscn`:** se elimina el `CollisionShape3D` hijo del `MeshInstance3D` `"agua"` (los demás bloques conservan el suyo). Al reexportar `assets/BlockLibrary.res` (`mcp__godot__export_mesh_library`), el ítem `"agua"` de la `MeshLibrary` queda sin forma de colisión — `GridMap` no genera cuerpo físico para esas celdas. Un `RayCast3D` (usado tanto por `Player.gd` para minar/colocar como por `CamaraCenital._celda_bajo_mouse()`) que hoy golpearía la cara superior de un bloque de agua, en vez de eso continúa y golpea la primera superficie sólida real que encuentre detrás — sin ningún cambio de código en el raycasting, es una consecuencia directa de quitar la forma de colisión.
- **`VoxelWorld.minar_bloque(celda)`:** agrega una guarda al inicio — si `obtener_tipo(celda) == "agua"`, devuelve `false` sin hacer nada (no hay forma realista de que el raycast golpee agua directamente tras el cambio anterior, pero esta guarda cubre cualquier llamada directa, p. ej. futura lógica de NPCs, y dobla como documentación de la regla "el agua no se mina").
- **`VoxelWorld.colocar_bloque(celda, tipo, por_jugador)`:** hoy rechaza colocar si `get_cell_item(celda) != GridMap.INVALID_CELL_ITEM` (cualquier celda no vacía, agua incluida). Se cambia la condición para que una celda con `"agua"` cuente como colocable — colocar ahí SUSTITUYE el bloque de agua por el nuevo tipo (mismo `set_cell_item`, sin pasos adicionales; el agua que hubiera arriba de esa celda, si la hay, no se ve afectada). El resto de la función no cambia.
- Consecuencia esperada en juego: al apuntar sobre una celda con agua (mar, lago o río) y minar, el jugador mina el bloque sólido real que hay debajo del agua; al colocar, el bloque nuevo reemplaza esa celda de agua puntual (no toda la columna de agua sobre ella, si la hay).
- **Fuera de alcance:** reglas de flotación/natación, colisión física del propio jugador con el agua (el `CharacterBody3D` del jugador conserva su colisión normal — puede seguir "caminando" a través de la posición de una celda de agua exactamente igual que antes de este cambio, ver nota ya existente en `PoC_6/`, sub-proyecto 4).

## 7. Opacidad de depuración

En `godot/scenes/BlockLibrarySource.tscn`, `Mat_agua` gana `transparency = 1` y su `albedo_color` baja de alfa `1.0` a `0.45` (valor inicial, ajustable si en el editor real resulta insuficiente para ver el fondo) — mismo mecanismo que ya usa `Mat_fantasma`/`Mat_ventana`. Puramente visual, sin efecto en `es_agua_en()`/colisión/lógica de juego. Reexportar `assets/BlockLibrary.res` junto con el cambio de la Sección 6 (un solo re-export cubre ambos).

## 8. Pruebas

Nuevas pruebas en `GeneradorMundoTest.gd` (mismo patrón que las existentes — instancias deterministas, sin nodos de escena):

- Determinismo: la misma `(semilla, ancho_mundo, largo_mundo)` produce exactamente el mismo conjunto de nacientes, cauces y anchos.
- Cada cauce trazado termina en una celda con `es_agua_en() == true`, o agota vecinos más bajos (mesa cerrada) — nunca excede `MAX_PASOS_RIO`.
- El perfil de profundidad de una franja de ancho conocido coincide exactamente con la fórmula (`[1,2,1]` para ancho 3, `[1,2,3,2,1]` para ancho 5, etc.) — probado con un cauce sintético (no generado por ruido) para aislar la fórmula del trazado real.
- `es_cascada_en()` es verdadero exactamente en los pasos cuya caída de altura supera `UMBRAL_CASCADA`, sobre un cauce sintético con caídas conocidas.
- `direccion_flujo_en()` apunta siempre hacia una celda con `altura_en()` menor o igual, nunca mayor, en cualquier celda de río del mundo real.
- **Cruce de ríos (dos cauces sintéticos, no generados por ruido, construidos a mano para que se crucen en una celda conocida):** el río más angosto queda truncado justo en la celda de cruce (inclusive) y no tiene celdas después; el más ancho conserva su cauce completo sin truncar. Caso de empate de ancho: el de naciente más alta conserva su cauce completo; el otro se trunca.

Nuevas pruebas en `BlueprintValidatorTest.gd` (ejecutado por `Test.tscn` — mismo archivo donde ya viven las demás pruebas directas de `VoxelWorld`, como el TEST 20 de inmunidad al minado):

- `VoxelWorld.minar_bloque()` sobre una celda `"agua"` devuelve `false` y no modifica la celda.
- `VoxelWorld.colocar_bloque()` sobre una celda `"agua"` devuelve `true` y dicha celda pasa a tener el tipo nuevo colocado (sustituye el agua).
- `VoxelWorld.colocar_bloque()` sigue rechazando (devuelve `false`) sobre cualquier celda no vacía que NO sea `"agua"` (comportamiento existente, sin regresión).

`Test.tscn` debe seguir corriendo sin errores nuevos tras el cambio (mismo criterio de verificación que sub-proyectos anteriores).

## Nota para el futuro (fuera de alcance, ver arriba)

Cuando se aborden cauces sinuosos, esta pieza es el punto de partida: el trazado por descenso por gradiente seguiría siendo la base, pero permitiendo pasos no ortogonales (o un suavizado posterior del cauce ortogonal ya trazado) para que el río no quede visualmente alineado a los ejes del grid.

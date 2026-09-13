# Diseño: Ríos con Corriente y Cascadas (PoC 6, sub-proyecto 4 — extensión)

Contexto: GDD Sección 11 (Fase 3, PoC 6) — extiende el sub-proyecto 4 (Generación de Cuerpos de Agua), que documentó explícitamente esta pieza como "fuera de alcance, para un desarrollo futuro" (ver `docs/superpowers/specs/2026-09-08-cuerpos-de-agua-design.md`, sección "Alcance de esta etapa"). El agua hoy es un único criterio estático (nivel de mar por percentil, `GeneradorMundo.nivel_mar`/`es_agua_en()`): cualquier columna por debajo del nivel de mar se inunda, sin concepto de cauce, conexión ni dirección de flujo. Esta pieza agrega cauces reales que conectan tierras altas con el mar/lagos existentes, con ancho y profundidad variables, y marca las caídas bruscas como cascadas.

Código existente que esta pieza extiende: `godot/scripts/GeneradorMundo.gd` (`altura_en()`, `nivel_mar`, `es_agua_en()`), `godot/scripts/VoxelWorld.gd` (`_generar_terreno()`), y el patrón de RNG sembrado de `godot/scripts/GeneradorArbol.gd` (`RandomNumberGenerator` con `.seed` derivado de la semilla del mundo).

## Alcance de esta etapa

- Cauces trazados por descenso por gradiente desde un número fijo de nacientes en tierras altas hasta el nivel de mar/lagos ya existentes — no hay red de afluentes ni fusión especial entre ríos que se crucen.
- Ancho fijo por río (entre 2 y 6 bloques, elegido al nacer) con perfil de profundidad variable (borde 1 bloque, centro hasta 3), tallado real en el terreno.
- Cascadas: dato (ubicación + salto de altura), sin bloque visual ni efecto de jugabilidad todavía — mismo criterio de "pulido pendiente" que el resto de bloques placeholder del proyecto.
- **Fuera de alcance, documentado para un desarrollo futuro:** cauces sinuosos (curvas reales de río, no limitados a los 4 ejes cardinales del grid) — esta etapa traza el cauce como una secuencia de pasos ortogonales (N/S/E/O) por simplicidad; un desarrollo posterior podría suavizar el trazado o usar un algoritmo de meandros. También fuera de alcance: bloque visual distinto para agua con corriente/cascada, efecto de jugabilidad (velocidad, arrastre, ahogamiento), y que ríos se fusionen o generen afluentes.
- El jugador puede minar/colocar bloques en celdas de río igual que en cualquier otra celda de agua — sin cambios a `minar_bloque`/`colocar_bloque`.

## 1. Selección de nacientes

`GeneradorMundo._init()` ya calcula `nivel_mar` recorriendo la distribución de alturas del mundo (`_calcular_nivel_mar()`). Esta pieza reutiliza ese mismo recorrido para además:

1. Recolectar todas las columnas `(x, z)` con `altura_en(x, z) >= ALTURA_MAXIMA - MARGEN_NACIENTE_RIO` (constante nueva, valor inicial `3` — sujeta a calibración empírica como `UMBRAL_HIERRO`/`EXPONENTE_RELIEVE`) como candidatas a naciente.
2. Con un `RandomNumberGenerator` sembrado (`.seed = semilla + 5`, siguiente hueco libre en la convención `semilla + N` que ya usan `_ruido_mineral`/`_ruido_fauna`/`_ruido_frutal`/`_ruido_arbol`), elegir `NUM_RIOS` (constante nueva, valor inicial `6`) candidatas al azar sin repetición como nacientes reales. Si hay menos candidatas que `NUM_RIOS`, se usan todas las disponibles (no es un error).
3. El mismo RNG (mismo objeto, mismo orden de llamadas — determinismo por semilla) elige a continuación, para cada naciente, su `ancho` con `rng.randi_range(ANCHO_MINIMO_RIO, ANCHO_MAXIMO_RIO)` (constantes nuevas, `2` y `6`).

## 2. Trazado del cauce (descenso por gradiente)

Desde cada naciente, en un método nuevo `_trazar_rio(origen: Vector2i) -> Array[Vector2i]`:

1. Empezar en `origen`, con un `Dictionary` de celdas visitadas (evita ciclos en mesetas).
2. En cada paso, evaluar las 4 celdas vecinas ortogonales (N/S/E/O) no visitadas. Si ninguna tiene `altura_en()` estrictamente menor que la celda actual, el cauce termina ahí (mesa/valle cerrado sin salida — se conserva el cauce parcial tal cual, no es un error).
3. Si hay una o más vecinas más bajas, moverse a la de menor altura (empate: la primera en el orden N/E/S/O, determinista).
4. El cauce termina exitosamente al entrar a una celda con `es_agua_en()` verdadero (llegó al mar o a un lago ya existente) — esa celda de agua se incluye como último elemento del cauce, pero no se tala ni se le agrega ancho/profundidad (ya es agua).
5. Tope de seguridad `MAX_PASOS_RIO` (constante nueva, valor inicial `ancho_mundo + largo_mundo`, cota superior generosa de cualquier camino simple en el grid) para evitar recorridos patológicos.

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

## 6. Pruebas

Nuevas pruebas en `GeneradorMundoTest.gd` (mismo patrón que las existentes — instancias deterministas, sin nodos de escena):

- Determinismo: la misma `(semilla, ancho_mundo, largo_mundo)` produce exactamente el mismo conjunto de nacientes, cauces y anchos.
- Cada cauce trazado termina en una celda con `es_agua_en() == true`, o agota vecinos más bajos (mesa cerrada) — nunca excede `MAX_PASOS_RIO`.
- El perfil de profundidad de una franja de ancho conocido coincide exactamente con la fórmula (`[1,2,1]` para ancho 3, `[1,2,3,2,1]` para ancho 5, etc.) — probado con un cauce sintético (no generado por ruido) para aislar la fórmula del trazado real.
- `es_cascada_en()` es verdadero exactamente en los pasos cuya caída de altura supera `UMBRAL_CASCADA`, sobre un cauce sintético con caídas conocidas.
- `direccion_flujo_en()` apunta siempre hacia una celda con `altura_en()` menor o igual, nunca mayor, en cualquier celda de río del mundo real.

`Test.tscn` debe seguir corriendo sin errores nuevos tras el cambio (mismo criterio de verificación que sub-proyectos anteriores).

## Nota para el futuro (fuera de alcance, ver arriba)

Cuando se aborden cauces sinuosos, esta pieza es el punto de partida: el trazado por descenso por gradiente seguiría siendo la base, pero permitiendo pasos no ortogonales (o un suavizado posterior del cauce ortogonal ya trazado) para que el río no quede visualmente alineado a los ejes del grid.

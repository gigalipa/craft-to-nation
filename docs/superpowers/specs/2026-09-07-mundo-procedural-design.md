# Diseño: Mundo Procedural Finito (PoC 5, sub-proyecto 1 de 3)

**Fecha:** 2026-09-07
**Roadmap:** GDD Sección 11, Fase 3 ("Mundo Procedural y Puestos de Recolección") — primer sub-proyecto, ver GDD v3.14.
**Depende de:** `godot/scripts/VoxelWorld.gd` (GridMap + MeshLibrary existentes), `godot/scenes/Main.tscn`.

## Contexto

Hoy `VoxelWorld._generar_piso_inicial()` solo coloca un piso plano de 11×11 bloques `"piso"` en `y = -1`, como placeholder para poder probar construcción. El GDD (Sección 11, "Estilo Gráfico y Estrategia de Assets") define el mundo real como **procedural finito**: generado una única vez al inicio de la partida, con ~300 bloques de profundidad total (de la cima de la montaña más alta al fondo del subsuelo), usando el `GridMap` nativo de Godot — **no** un motor de vóxeles infinito con streaming de chunks (decisión ya tomada, ver esa misma sección).

Se evaluó adoptar un motor de vóxeles de terceros (`godot_voxel`/Zylann's Voxel Tools) para no reinventar generación procedural — descartado explícitamente por el usuario: es un motor de mundos infinitos con streaming/LOD, contradice la decisión ya tomada de usar `GridMap` finito, y sería un cambio de arquitectura mucho mayor que el de esta PoC. Para el mapa de alturas en sí, `FastNoiseLite` (nativo de Godot, sin dependencias) ya es la herramienta adecuada — no hace falta una librería externa para eso.

Este sub-proyecto es el primero de la Fase 3 y una dependencia dura de los otros dos (Nivelación de Terreno sobre Relieve, Puestos de Recolección) — ambos necesitan relieve real para tener sentido.

## Decisiones Confirmadas con el Usuario

1. **Tamaño horizontal de esta PoC:** 200×200 celdas en X/Z — suficiente para tener relieve real (varias montañas/valles), sin las complicaciones de rendimiento de un `GridMap` mucho más grande. El tamaño final del mundo del juego se ajusta después sin cambiar el algoritmo.
2. **Profundidad reducida para esta PoC:** ~30-35 bloques de subsuelo bajo la superficie generada, no los ~300 finales del GDD (200×200×300 ≈ 12 millones de celdas sólidas sería demasiado lento de generar de una sola vez). Escalar a la profundidad real queda anotado como optimización futura — posiblemente generando solo el margen alcanzable bajo la superficie visible, no perforando literalmente hasta el fondo real.
3. **Tipos de bloque nuevos:** solo `"tierra"` (3-4 celdas justo bajo la superficie) y `"piedra"` (todo lo demás, hasta el límite de profundidad de esta PoC) — sin variantes de bioma (pasto/arena/nieve) todavía; eso se evalúa en el sub-proyecto de Puestos de Recolección si hace falta.
4. **Algoritmo:** `FastNoiseLite` nativo de Godot (sin dependencias nuevas, sin plugins) para el mapa de alturas — no se adopta ningún motor de vóxeles de terceros.
5. **Lógica aislada y testeable:** la generación de alturas vive en un script nuevo sin nodos de escena (`GeneradorMundo.gd`), mismo patrón que `Zonificacion.gd`/`Ciudad.gd` — dado ancho, largo, semilla y rango de altura, expone `altura_en(x, z) -> int`, reusable después por la Nivelación de Terreno.

## Arquitectura

```
godot/
  scripts/
    GeneradorMundo.gd            # Nuevo: lógica pura, sin nodos de escena
    GeneradorMundoTest.gd        # Nuevo: pruebas aisladas (mismo patrón que ZonificacionTest.gd)
    VoxelWorld.gd                 # Modificado: _generar_piso_inicial() reemplazado
  scenes/
    GeneradorMundoTest.tscn      # Nueva escena de pruebas (sin gameplay)
    Main.tscn                     # Modificado: posición inicial del Player ajustada a la altura real del terreno
```

### Componentes

**`GeneradorMundo.gd` (script sin `class_name`, no es autoload — se instancia con `.new()` desde `VoxelWorld.gd` y desde las pruebas, como una utilidad pura):**
- `const ANCHO := 200`, `const LARGO := 200`
- `const PROFUNDIDAD_SUBSUELO := 32` (celdas de subsuelo bajo la superficie, para esta PoC — no los ~300 finales)
- `const GROSOR_TIERRA := 4` (celdas de `"tierra"` justo bajo la superficie; el resto del subsuelo es `"piedra"`)
- `const ALTURA_MINIMA := 0`, `const ALTURA_MAXIMA := 15` (rango de la superficie generada, en celdas — valles en `ALTURA_MINIMA`, picos en `ALTURA_MAXIMA`)
- `var ruido: FastNoiseLite`
- `func _init(semilla: int) -> void`: crea `FastNoiseLite`, fija `ruido.seed = semilla`, `ruido.noise_type = FastNoiseLite.TYPE_PERLIN`, y una frecuencia baja fija (constante, para que el relieve tenga escala de "colinas", no ruido de alta frecuencia tipo estática).
- `func altura_en(x: int, z: int) -> int`: `ruido.get_noise_2d(x, z)` devuelve un valor en `[-1, 1]`; se remapea linealmente a `[ALTURA_MINIMA, ALTURA_MAXIMA]` y se redondea a entero. Determinista: misma `(semilla, x, z)` siempre da la misma altura.
- `func tipo_en_profundidad(profundidad_bajo_superficie: int) -> String`: `"tierra"` si `profundidad_bajo_superficie < GROSOR_TIERRA`, si no `"piedra"`. `profundidad_bajo_superficie` es `0` en la celda de superficie misma, `1` en la primera celda debajo, etc.

**`VoxelWorld.gd` (cambios):**
- `_generar_piso_inicial()` se reemplaza por `_generar_terreno()`: crea un `GeneradorMundo` con una semilla (constante por ahora, `SEMILLA_MUNDO := 12345`, para desarrollo determinista — una semilla aleatoria real es trabajo de una fase posterior con selección de partida), y para cada `(x, z)` en `[0, ANCHO) × [0, LARGO)`:
  1. `altura := generador.altura_en(x, z)`
  2. Coloca `"piso"` en `Vector3i(x, altura, z)` como la celda de superficie (reutiliza el bloque `"piso"` existente para la capa caminable superior — no hace falta un tipo de bloque nuevo para la superficie misma).
  3. Para `profundidad` de `1` a `PROFUNDIDAD_SUBSUELO`: coloca `generador.tipo_en_profundidad(profundidad)` en `Vector3i(x, altura - profundidad, z)`.
- Ninguna de estas celdas se marca `colocado_por_jugador` (mismo comportamiento que el piso plano anterior — el terreno generado por el mundo nunca puede ser parte de un edificio declarado por el jugador).

**`Main.tscn`/`Main.gd` (cambios):**
- La posición inicial del `Player` (hoy fija en `Vector3(0, 1, 0)`) se calcula en `Main.gd::_ready()` como `Vector3(0, generador.altura_en(0, 0) + 1, 0)` — el jugador aparece de pie sobre el terreno real en `(0,0)`, no flotando o enterrado si esa celda no es la altura 0.

## Flujo de Datos

1. Al cargar `Main.tscn`, `VoxelWorld._ready()` llama a `_generar_terreno()` en vez de `_generar_piso_inicial()`.
2. `_generar_terreno()` recorre las 40.000 columnas (200×200), calculando la altura de cada una y colocando su superficie + subsuelo.
3. `Main.gd` reposiciona al `Player` sobre la altura real de `(0,0)`.
4. El resto del flujo de juego (minar, colocar, declarar edificio, zonificación) no cambia — el terreno generado se comporta igual que el piso plano anterior para todo lo demás (nunca es parte de una estructura declarada, porque nunca se marca `colocado_por_jugador`).

## Manejo de Errores / Casos Límite

- `altura_en()` siempre devuelve un entero dentro de `[ALTURA_MINIMA, ALTURA_MAXIMA]` — el remapeo lineal desde `[-1, 1]` garantiza el rango, sin necesidad de `clamp()` adicional (pero se agrega de todas formas como salvaguarda barata contra un valor de borde de `FastNoiseLite`).
- Si `PROFUNDIDAD_SUBSUELO` o `GROSOR_TIERRA` cambian de valor en el futuro (al escalar hacia los ~300 reales del GDD), `tipo_en_profundidad()` sigue siendo correcta sin cambios — la lógica es relativa a `GROSOR_TIERRA`, no a un número de capa absoluto.
- Generar 40.000 columnas × ~33 celdas de profundidad (~1.3 millones de llamadas a `colocar_bloque()`) al iniciar la escena puede tardar un tiempo perceptible (segundos) — aceptable para esta PoC, dado que el GDD ya descarta explícitamente streaming/generación diferida. Si en la verificación real resulta demasiado lento, la salida es reducir `ANCHO`/`LARGO` para esta PoC, no introducir generación asíncrona (fuera de alcance).

## Pruebas

`GeneradorMundoTest.gd` (mismo patrón que `ZonificacionTest.gd`, corrido vía `GeneradorMundoTest.tscn` con F6):
1. Misma semilla, mismas coordenadas → `altura_en()` devuelve el mismo valor (determinismo).
2. `altura_en()` devuelve valores dentro de `[ALTURA_MINIMA, ALTURA_MAXIMA]` para un muestreo de coordenadas (incluyendo negativas, por si el mundo se centra en el origen más adelante).
3. Semillas distintas producen mapas de altura distintos en al menos algún punto muestreado (para descartar que el ruido esté mal cableado y siempre devuelva lo mismo).
4. `tipo_en_profundidad(0)` hasta `tipo_en_profundidad(GROSOR_TIERRA - 1)` devuelven `"tierra"`; `tipo_en_profundidad(GROSOR_TIERRA)` en adelante devuelven `"piedra"`.

La generación real sobre `GridMap` (tiempo de carga, aspecto visual del relieve, spawn del jugador sobre terreno real) solo se puede confirmar por carga sin errores vía MCP (headless) y, para la parte visual/de rendimiento, jugando en el editor real — mismo patrón que HUD/zonificación (ver `PoC_4/`).

## Fuera de Alcance (explícito)

- Profundidad real de ~300 bloques (esta PoC usa ~30-35) — escalar es optimización futura.
- Biomas/variantes de superficie (pasto, arena, nieve) — evaluar en el sub-proyecto de Puestos de Recolección si hace falta.
- Cuevas/cavidades bajo tierra (GDD Sección 8, "Túneles y Cavernas" — Visión a futuro, depende de Fase 6).
- Nivelación de terreno al emplazar edificios sobre relieve (siguiente sub-proyecto de esta misma Fase — usará `GeneradorMundo.altura_en()`, pero no se implementa aquí).
- Semilla aleatoria real / selección de semilla al iniciar partida (esta PoC usa una constante fija para desarrollo determinista).
- Generación asíncrona/diferida — el GDD descarta explícitamente streaming de chunks; si el tiempo de carga resulta un problema, la solución es reducir el tamaño de esta PoC, no introducir async.

# Diseño: Generación de Cuerpos de Agua (PoC 5, sub-proyecto 4)

Contexto: GDD Sección 11 (Fase 3, PoC 5) — cuarto sub-proyecto, agregado en v3.20. Resuelve la dependencia silenciosa de los puestos de caza/recolección (Sección 3: "cerca de... ríos o lagos con peces") y la dependencia explícita del futuro Sistema de Puentes (Sección 4, PoC 9). Ver también `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Mundo Procedural y Puestos de Recolección.md`, sección "Próximos Pasos", y `godot/scripts/GeneradorMundo.gd` / `godot/scripts/VoxelWorld.gd` (código existente que este sub-proyecto extiende).

## Alcance de esta etapa

- Un único criterio de "cuerpo de agua": nivel de mar. No se modela la forma de un río (cauce alargado, corriente, conexión punto a punto) — cualquier depresión del terreno bajo el nivel de mar queda inundada, sea alargada o no. Esto permite mundos de archipiélagos, costas marinas o lacustres.
- **Fuera de alcance, documentado para un desarrollo futuro:** ríos con corriente y cascadas (cauces reales, dirección de flujo, salto de altura entre tramos). Cuando se aborden, probablemente requieran un algoritmo de trazado de cauce (descenso por gradiente) además de este umbral de nivel de mar.
- El jugador puede minar/colocar bloques en celdas de agua sin restricción nueva — `minar_bloque`/`colocar_bloque` no distinguen tipos hoy, y esto no cambia en este sub-proyecto. No hay reglas de flotación, natación ni de "no construir sobre agua".
- El bloque `"agua"` usa color plano placeholder (mismo patrón que `tierra`/`piedra`/`hierro`), sin transparencia ni textura real.
- Como el nivel de mar solo tiene sentido con relieve real, este sub-proyecto también ajusta el ruido de altura para que el mundo tenga picos y cuencas más marcados (ver sección 3).

## 1. Criterio de nivel de mar (percentil de altura)

`GeneradorMundo` calcula `nivel_mar` una vez en `_init()`, muestreando `altura_en(x, z)` sobre las `ancho_mundo * largo_mundo` columnas del grid y tomando el percentil 15 de esa distribución (constante `PERCENTIL_NIVEL_MAR := 0.15`).

Se eligió percentil sobre valor fijo porque el rango de altura teórico `[ALTURA_MINIMA, ALTURA_MAXIMA] = [0, 15]` no garantiza que una altura fija (p. ej. 4) produzca una fracción de mundo inundada consistente si cambian semilla, frecuencia de ruido o el exponente de relieve (sección 3) — el percentil es robusto a esos cambios porque se deriva de la distribución real generada.

**Fuera de alcance, documentado para un desarrollo futuro:** el percentil hoy es una constante fija (0.15); en un desarrollo posterior dependerá del "tipo de mundo" elegido (p. ej. archipiélago vs. continental), permitiendo mundos con más o menos agua.

El muestreo recorre las columnas una vez por `_init` (mismo orden de magnitud — 40 000 llamadas a `altura_en` en un grid 200×200 — que ya recorre `VoxelWorld._generar_terreno()` hoy; no introduce un costo de generación nuevo relevante).

## 2. API pública de `GeneradorMundo`

- `_init(semilla: int, ancho_mundo: int, largo_mundo: int)` — dos parámetros nuevos, solo para el muestreo del percentil. `VoxelWorld.gd` ya tiene `ANCHO_MUNDO`/`LARGO_MUNDO` y los pasa igual que hoy pasa `SEMILLA_MUNDO`.
- `nivel_mar: int` — propiedad de solo lectura calculada en `_init`, expuesta para que sub-proyectos futuros (adyacencia de puestos de caza/pesca, detección de vacíos para puentes de PoC 9) puedan consultarla sin repetir el cálculo.
- `es_agua_en(x: int, z: int) -> bool` — `return altura_en(x, z) < nivel_mar` (estrictamente menor: la columna exactamente en el nivel de mar queda como tierra emergida, no inundada). Es la función que sub-proyectos futuros consumirán para adyacencia/obstáculos; hoy su único llamador es `VoxelWorld._generar_terreno()`.

## 3. Relieve más escarpado (redistribución por curva de potencia)

`altura_en(x, z)` obtiene `valor := _ruido.get_noise_2d(x, z)` en `[-1, 1]` como hoy, pero antes de remapear a altura aplica una redistribución que acentúa los extremos:

```
valor_redistribuido = signo(valor) * abs(valor) ^ EXPONENTE_RELIEVE
```

con `EXPONENTE_RELIEVE := 2.0` como valor inicial (constante nueva en `GeneradorMundo.gd`, mismo patrón de calibración empírica que `UMBRAL_HIERRO`: se ajustará en el editor real y se documentará in-line si el valor final cambia). El remapeo a `[ALTURA_MINIMA, ALTURA_MAXIMA]` sigue igual, usando `valor_redistribuido` en vez de `valor`.

Esto aplana más los valores cercanos a 0 (llanos) y exagera los cercanos a ±1 (picos/cuencas), sin tocar la frecuencia del ruido base ni el rango vertical `[0, 15]`. El objetivo es que el criterio de nivel de mar (sección 1) separe tierra firme de cuencas inundadas de forma perceptible en el editor — el problema original (colinas suaves, sin diferencia de altura suficiente) se resuelve en la forma del relieve, no ampliando el rango vertical.

`tipo_en_profundidad()` no cambia — sigue operando sobre profundidad relativa a la superficie, que ya incorpora el nuevo relieve a través de `altura_en()`.

## 4. Relleno de agua en `VoxelWorld._generar_terreno()`

Para cada columna `(x, z)`:

1. Se coloca el bloque de superficie/subsuelo exactamente igual que hoy (lecho de la cuenca, sin cambios — sigue siendo `"piso"` en la superficie y `tierra`/`piedra`/`hierro` debajo).
2. Si `generador.es_agua_en(x, z)` es verdadero, se agregan bloques `"agua"` en cada celda vacía desde `altura + 1` hasta `generador.nivel_mar` inclusive.

Columnas no sumergidas no cambian. Ninguna celda de agua se marca `colocado_por_jugador` (mismo criterio que el resto del terreno generado).

Se agrega el bloque `"agua"` (color plano azul, sin transparencia) a la `MeshLibrary` del proyecto (`assets/BlockLibrary.res`), junto a los bloques placeholder existentes.

## Pruebas

Nuevas pruebas en `GeneradorMundoTest.gd` (mismo patrón que las 4 existentes — generadores/instancias deterministas, sin nodos de escena):

- `nivel_mar` es determinista para una (semilla, ancho, largo) dados.
- `es_agua_en(x, z)` coincide exactamente con `altura_en(x, z) < nivel_mar` para un conjunto de columnas de prueba.
- Sobre una muestra del grid, la fracción de columnas con `es_agua_en == true` se aproxima al 15% (tolerancia razonable — el percentil es exacto sobre los datos muestreados, pero la altura discreta puede desviar el porcentaje real ligeramente).
- La redistribución por curva de potencia no rompe el rango `[ALTURA_MINIMA, ALTURA_MAXIMA]` de `altura_en()`.

`Test.tscn` debe seguir corriendo sin errores nuevos tras el cambio (mismo criterio de verificación que sub-proyectos anteriores de PoC 5).

# Diseño: Señales de Bioma, Fauna y Frutal (PoC 5, pieza pendiente de "Recolección")

Contexto: GDD Sección 3 ("Área de Acción de los Puestos de Recolección") y Sección 3.1 (categoría "Recolección": madereros, minas, puestos de caza y recolección de alimento) — madereros y puestos de caza/recolección requieren "bosques, praderas con animales, árboles frutales, ríos o lagos con peces para tener recurso real que recolectar". Las minas (sub-proyecto 3 de PoC 5) y los cuerpos de agua (sub-proyecto 4) ya están completos; esta es la pieza que quedaba sin sub-proyecto propio, bloqueada por la falta de biomas/vegetación/fauna reales — ver `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Mundo Procedural y Puestos de Recolección.md`, "Próximos Pasos", ítem 3.

Este sub-proyecto cubre **solo la capa de señales/datos** (bioma único + densidad de fauna + densidad de frutal). Durante el brainstorming se descubrió que la vegetación real ("árboles" talables con salud, formados por 20-50 bloques de madera+follaje que se generan y desaparecen progresivamente) es una mecánica propia, no una simple detección de bloques como el hierro — queda fuera de alcance aquí, junto con los puestos de caza/madereros que la consumirán. Ver "Fuera de alcance" más abajo.

## Alcance de esta etapa

- Un único tipo de bioma (sin distinguir bosque/pradera/montaña todavía): cualquier columna de tierra firme dentro de una banda de altura sobre el nivel del mar.
- Dos señales de densidad numéricas (`[0, 1]`), independientes entre sí y del relieve/minerales: fauna y "frutal". Puramente datos — sin bloque, sin representación visual, sin NPCs ni objetos todavía.
- **Fuera de alcance, documentado para desarrollo futuro:**
  - Biomas diferenciados por una capa de ruido de humedad/temperatura (estilo Minecraft) en vez de un solo tipo derivado de altura+agua.
  - Árboles procedurales talables: objetos de 20-50 bloques (madera + follaje) con "salud" igual a la madera extraíble, que se reduce al talar y hacen desaparecer el árbol completo al agotarse. Esta señal de bioma es la que decidirá, más adelante, dónde y cuántos árboles genera un bosque — pero el árbol en sí (generación procedural, salud, tala progresiva) es un sub-proyecto propio.
  - NPCs de fauna con movimiento e IA de huida (estilo "gaia" de Age of Empires) — la señal `densidad_fauna_en` es la que alimentará esa generación cuando exista.
  - Objetos "frutal" — la señal `densidad_frutal_en` es la que alimentará su generación cuando exista.
  - Puestos de caza y madereros consumiendo estas señales (necesitan que existan las entidades/árboles de arriba primero).

## 1. Criterio de bioma único

`GeneradorMundo` gana `es_bioma_en(x: int, z: int) -> bool`:

```
es_bioma_en(x, z) = NOT es_agua_en(x, z) AND altura_en(x, z) <= nivel_mar + BANDA_BIOMA
```

`BANDA_BIOMA := 4` (constante nueva, calibrada empíricamente como punto de partida — mismo patrón que `GROSOR_TIERRA`/`UMBRAL_HIERRO`/`EXPONENTE_RELIEVE`: se ajustará si en el editor real la banda resulta demasiado angosta o demasiado ancha). Como `es_agua_en` ya es `altura_en(x,z) < nivel_mar`, su negación implica `altura_en(x,z) >= nivel_mar` — la banda de bioma es exactamente `[nivel_mar, nivel_mar + BANDA_BIOMA]`. Cumbres por encima de esa banda quedan estériles: sin vegetación ni fauna.

## 2. Señales de densidad de fauna y frutal

Dos instancias nuevas de `FastNoiseLite` (`_ruido_fauna`, `_ruido_frutal`), mismo patrón que `_ruido_mineral`: semillas derivadas (`semilla + 2`, `semilla + 3` — no colisionan con `_ruido` en `semilla` ni con `_ruido_mineral` en `semilla + 1`) para que ninguna de las tres capas quede correlacionada entre sí, y frecuencia baja (mismo valor inicial que `_ruido_mineral.frequency = 0.05`, calibrable después) para producir manchas de densidad en vez de ruido puntual disperso celda a celda.

Dos funciones públicas nuevas:

- `densidad_fauna_en(x: int, z: int) -> float`: `0.0` si `es_bioma_en(x, z)` es falso; si no, `_ruido_fauna.get_noise_2d(x, z)` remapeado de `[-1, 1]` a `[0, 1]` (mismo remapeo lineal que usa `altura_en()` para su rango, sin curva de redistribución — no hay evidencia de que la densidad necesite acentuar extremos, y ya se aprendió con `EXPONENTE_RELIEVE` que una curva mal calibrada puede invertir la intención).
- `densidad_frutal_en(x: int, z: int) -> float`: análoga, con `_ruido_frutal`.

Ambas devuelven una fracción en `[0, 1]` interpretable como "qué tan denso es este recurso aquí" — un sistema futuro la multiplicará por área para decidir cuántos NPCs de fauna u objetos "frutal" generar. Ninguna tiene efecto de bloque ni visual en esta etapa.

## Pruebas

Nuevas pruebas en `GeneradorMundoTest.gd` (mismo patrón que las 10 existentes):

- `es_bioma_en` coincide exactamente con el criterio (`NOT es_agua_en` Y `altura_en <= nivel_mar + BANDA_BIOMA`) para un conjunto de columnas de prueba.
- `densidad_fauna_en` y `densidad_frutal_en` son deterministas para una (semilla, ancho, largo) dados.
- Ambas están siempre en `[0, 1]` sobre una muestra del grid.
- Ambas son exactamente `0.0` en cualquier columna donde `es_bioma_en` sea falso (fuera de la banda o en agua).
- Las tres funciones se ejercitan también con `SEMILLA_MUNDO`/`ANCHO_MUNDO`/`LARGO_MUNDO` reales, sin errores.

`Test.tscn` debe seguir pasando sin cambios de comportamiento — nada más en el proyecto consume estas funciones todavía.

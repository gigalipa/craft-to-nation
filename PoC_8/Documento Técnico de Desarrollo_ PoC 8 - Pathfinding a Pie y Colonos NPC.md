# **Documento Técnico de Desarrollo: PoC 8 - Pathfinding a Pie y Colonos NPC**

**Identificador del Módulo:** POC-08-PATHFINDING-COLONOS

**Motor:** Godot Engine 4.7 (GDScript), sobre el proyecto compartido `godot/`.

**Dependencias de Diseño:** GDD Sección 2 (ciclo de juego, Fase 2), Sección 3 (zona de influencia), Sección 6 (población), Sección 11 (Fase 2 y Fase 5).

Spec: `docs/superpowers/specs/2026-09-20-colonos-pathfinding-design.md`. Plan: `docs/superpowers/plans/2026-09-20-colonos-pathfinding.md`.

**Nota de alcance.** La navegación de la Fase 5 (PoC 8) se **adelantó** por decisión explícita del usuario (2026-09-20) para poder construir sobre ella la economía de recursos (acarreo, obreros). Solo cubre caminar a pie por el terreno; las carreteras, carretas, cintas y tuberías siguen siendo de la Fase 5.

## **Decisión: A\* propio, no `NavigationServer3D`**

El GDD (Fase 5) preveía `NavigationServer3D`. No se usa: exige hornear una malla de navegación y este mundo cambia continuamente (minado, construcción fantasma, agua que fluye), lo que obligaría a rehornearla siempre. `BuscadorRutas.gd` evalúa los vecinos consultando `VoxelWorld.obtener_tipo()` en el momento, así que siempre ve el mundo actual y no hay nada que invalidar.

## **`BuscadorRutas.gd`**

Clase pura (`RefCounted`), probada con un mundo falso (`BuscadorRutasTest.gd`, 14 pruebas).

* **Celda transitable:** un NPC ocupa 2 celdas de alto; las dos deben estar libres (`""`, `puerta_inferior`, `puerta_superior`) y la de abajo ser suelo sólido. El agua de 1 bloque de profundidad se cruza; de 2 o más, no. Camas y baúles son suelo (un colono puede pararse encima).
* **Movimientos:** 4 ortogonales; sube 1 bloque, cae hasta 3. Coste `1 + |dy|`, heurística Manhattan 3D, tope de 20 000 nodos expandidos por consulta.
* **Cola de prioridad:** desempata por menor `h` (distancia al destino) y, a igualdad, por orden de inserción, para que el terreno llano abierto no degrade la búsqueda a una en anchura (hay una prueba de cruce largo de 150×150).
* **Ruta que se rompe:** el colono verifica que la siguiente celda siga siendo transitable antes de cada paso; si no, recalcula.

## **`Colonos.gd` y `ColonosRenderer.gd`**

Probados en `ColonosTest.gd` (13 pruebas).

* **`Colonos` (autoload, estado puro):** `Ciudad.demografia` es la fuente de verdad de las cantidades; `reconciliar()` crea o retira colonos al recibir `Ciudad.tick_simulado`. Cada colono tiene un hogar (edificio residencial con menor ocupación relativa, ponderada por `1 / x_cama`), aparece en el borde de la zona de influencia y deambula: la mitad de las veces hacia su casa (puede quedar sobre una cama o junto a ella) y el resto por la zona de influencia.
* **Evitación:** dos colonos nunca ocupan la misma celda (reserva de la celda siguiente). Si otro colono o el avatar la ocupa, espera 0,5 s, rodea sus celdas y, si no hay forma, abandona el destino. El avatar cuenta como obstáculo en su celda y, si se mueve, en la de adelante; los colonos lo esquivan pero no huyen de él.
* **`ColonosRenderer`:** una cápsula placeholder y un `AnimatableBody3D` por colono, para que el avatar no los atraviese.
* **Cuerpo del avatar:** cápsula visible en primera persona y en la cámara cenital (`Player.tscn`).

## **Fuera de alcance / Próximos pasos**

* Fantasmas de obra permeables hacia afuera (Plan 3 del mismo spec).
* Trabajo, recolección, acarreo, almacenes y construcción por NPC (sub-proyectos 2 y 3).
* Carreteras y carretas; pathfinding asíncrono o jerárquico si la población lo exige; negociación de prioridad entre colonos; unidades definitivas (arte).
* Verificación manual pendiente en el editor real: colonos llegan por el borde, entran a las casas, se paran sobre camas y no atraviesan paredes ni agua profunda.

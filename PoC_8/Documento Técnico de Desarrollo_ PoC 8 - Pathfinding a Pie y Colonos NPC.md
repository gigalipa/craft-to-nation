# **Documento Técnico de Desarrollo: PoC 8 - Pathfinding a Pie y Colonos NPC**

**Identificador del Módulo:** POC-08-PATHFINDING-COLONOS

**Motor:** Godot Engine 4.7 (GDScript), sobre el proyecto compartido `godot/`.

**Dependencias de Diseño:** GDD Sección 2 (ciclo de juego, Fase 2), Sección 3 (zona de influencia), Sección 6 (población), Sección 11 (Fase 2 y Fase 5).

Spec: `docs/superpowers/specs/2026-09-20-colonos-pathfinding-design.md`. Plan: `docs/superpowers/plans/2026-09-20-colonos-pathfinding.md`.

**Nota de alcance.** La navegación de la Fase 5 (PoC 8) se **adelantó** por decisión explícita del usuario (2026-09-20) para poder construir sobre ella la economía de recursos (acarreo, obreros). Solo cubre caminar a pie por el terreno; las carreteras, carretas, cintas y tuberías siguen siendo de la Fase 5.

## **Decisión: A\* propio, no `NavigationServer3D`**

El GDD (Fase 5) preveía `NavigationServer3D`. No se usa: exige hornear una malla de navegación y este mundo cambia continuamente (minado, construcción fantasma, agua que fluye), lo que obligaría a rehornearla siempre. `BuscadorRutas.gd` evalúa los vecinos consultando `VoxelWorld.obtener_tipo()` en el momento, así que siempre ve el mundo actual y no hay nada que invalidar.

## **`BuscadorRutas.gd`**

Clase pura (`RefCounted`), probada con un mundo falso (`BuscadorRutasTest.gd`, 17 pruebas).

* **Celda transitable:** un NPC ocupa 2 celdas de alto; las dos deben estar libres (`""`, `puerta_inferior`, `puerta_superior`) y la de abajo ser suelo sólido. El agua de 1 bloque de profundidad se cruza; de 2 o más, no. Camas y baúles son suelo (un colono puede pararse encima).
* **Movimientos:** 4 ortogonales; sube 1 bloque, cae hasta 3. Coste `1 + |dy|`, heurística Manhattan 3D, tope de 20 000 nodos expandidos por consulta.
* **Cola de prioridad:** desempata por menor `h` (distancia al destino) y, a igualdad, por orden de inserción, para que el terreno llano abierto no degrade la búsqueda a una en anchura (hay una prueba de cruce largo de 150×150).
* **Ruta que se rompe:** el colono verifica que la siguiente celda siga siendo transitable antes de cada paso; si no, recalcula.

## **`Colonos.gd` y `ColonosRenderer.gd`**

Probados en `ColonosTest.gd` (17 pruebas).

* **`Colonos` (autoload, estado puro):** `Ciudad.demografia` es la fuente de verdad de las cantidades; `reconciliar()` crea o retira colonos al recibir `Ciudad.tick_simulado`. Cada colono tiene un hogar (edificio residencial con menor ocupación relativa, ponderada por `1 / x_cama`), aparece en el borde de la zona de influencia y deambula: la mitad de las veces hacia su casa (puede quedar sobre una cama o junto a ella) y el resto por la zona de influencia.
* **Evitación:** dos colonos nunca ocupan la misma celda (reserva de la celda siguiente). Si otro colono o el avatar la ocupa, espera 0,5 s, rodea sus celdas y, si no hay forma, abandona el destino. El avatar cuenta como obstáculo en su celda y, si se mueve, en la de adelante; los colonos lo esquivan pero no huyen de él.
* **`ColonosRenderer`:** una cápsula placeholder y un `AnimatableBody3D` por colono, para que el avatar no los atraviese.
* **Cuerpo del avatar:** cápsula visible en primera persona y en la cámara cenital (`Player.tscn`).

## **Fantasmas de obra permeables hacia afuera**

* **Problema:** al emplazar un blueprint, sus bloques `fantasma` son sólidos; quien estuviera en el sitio quedaba dentro de un sólido (el pathfinding no encontraba ruta desde su celda y el avatar quedaba atrapado).
* **Solución:** `GridMap` no permite colisión por celda ni por cara, así que el ítem `fantasma` de la `MeshLibrary` ya no lleva formas de colisión y cada obra tiene un `StaticBody3D` propio (`CuerposObra.gd`) con una caja por fantasma pendiente. Quien está dentro del volumen de la obra al emplazarla (o al empezar a deconstruir un edificio completo, señal `obra_a_fantasma`) recibe un permiso de salida: el avatar ignora la colisión con ese cuerpo (`add_collision_exception_with`) y los colonos usan `ignorar_fantasmas` en `BuscadorRutas`. El permiso se revoca al salir y no se recupera. Los colonos con permiso evacúan por `buscar_salida()`.
* **Puerta de inicio de obra:** `VoxelWorld.surtir_construccion()` devuelve `{"bloqueada": true, "id": id}` mientras haya un permiso vigente (el `id` permite al aviso indicar de qué obra se trata).
* **Capas de colisión:** el mundo (terreno, edificios y cuerpos de obra fantasma) está en la capa 1; los `AnimatableBody3D` de los colonos, en la capa 2 con máscara 0; el avatar `Player` tiene `collision_mask = 3` (choca con el mundo y con los colonos). El `RayCast3D` del jugador usa máscara 1 y las cuatro consultas físicas de `CamaraCenital` usan `MASCARA_MUNDO = 1`, así que clics y rayos atraviesan a los colonos y golpean el terreno o los cuerpos de obra.
* **Pruebas:** `BuscadorRutasTest` 17, `ColonosTest` 17, `FantasmasPermeablesTest` 8 (2 de `CuerposObra`, con física real, y 6 de permisos, volumen y puerta de `VoxelWorld`), `CiudadTest` 16 y `Test.tscn` 63.
* **Limitaciones conocidas:** un colono que acaba de pie en una celda fantasma sin permiso (a medio paso, o una puerta que revierte a fantasma durante una deconstrucción) recibe el permiso y evacúa la próxima vez que elige destino (solo se comprueba la celda de los pies; un fantasma únicamente sobre su cabeza no se trata); un fantasma de follaje liberado creado para una obra vecina se sincroniza solo en el siguiente avance de esa obra (raro); el aviso de obra bloqueada es un `print` en consola, no un mensaje del HUD.
* **Alternativa no elegida:** una malla cóncava con solo las caras externas y `backface_collision = false`, que impediría entrar y dejaría salir sin permisos. No se garantiza que `GodotPhysics3D` la respete para el movimiento de un `CharacterBody3D`; queda como vía a explorar si se quiere simplificar.

## **Fuera de alcance / Próximos pasos**

* Deconstrucción marcada desde la cámara cenital con la tecla `G` (obreros NPC que desmontan un edificio marcado): diseño documentado en el spec, se implementa con el sub-proyecto de construcción por NPC.
* Trabajo, recolección, acarreo, almacenes y construcción por NPC (sub-proyectos 2 y 3).
* Carreteras y carretas; pathfinding asíncrono o jerárquico si la población lo exige; negociación de prioridad entre colonos; unidades definitivas (arte).
* Verificación manual pendiente en el editor real: colonos llegan por el borde, entran a las casas, se paran sobre camas y no atraviesan paredes ni agua profunda.
* Verificación manual pendiente (fantasmas permeables): que el avatar y los colonos salgan de un sitio emplazado encima de ellos y no puedan volver a entrar; el aviso al intentar surtir con alguien dentro; que surtir y deconstruir sobre un fantasma siga funcionando (el rayo ahora golpea el `StaticBody3D` de la obra, no el `GridMap`); que el picking sobre un fantasma en la cenital elija la celda correcta; que las obras vecinas sigan aisladas (estar dentro de una no permite cruzar los fantasmas de la otra); y que deconstruir un edificio completo con colonos dentro los haga salir. Sin prueba automática: el permiso del avatar con volumen ampliado (que salir de una obra emplazada encima no lo empuje) y destruir una obra con el avatar dentro sin errores.

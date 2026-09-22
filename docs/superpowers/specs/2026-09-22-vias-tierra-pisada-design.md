# Vías de tierra pisada (sub-proyecto 6, primer tramo)

Ver GDD Sección 4 ("Infraestructura de Transporte y Redes Logísticas"),
Sección 3.1 (evolución de transporte terrestre) y `docs/Pendientes y
próximos pasos.md` punto 1. Primer avance del sub-proyecto 6: solo el tipo
`tierra_pisada`. Calzada, carretera, vía férrea, cintas y tuberías quedan
como filas de datos futuras en el mismo catálogo, sin implementación.

## Contexto

Hoy los colonos y el avatar caminan a velocidad constante sin importar el
terreno (`Colonos.VELOCIDAD_COLONO`, `Player.VELOCIDAD`). El GDD prevé
"tierra afirmada" como el primer escalón de transporte terrestre, con
+35% de velocidad. No existe overlay de vía, ni piezas de transición de
altura (cuñas), ni un trazador dedicado en la cámara cenital.

## 1. Modelo de datos

**Vértice y bloque de vía.** El eje de una vía pasa por vértices enteros
`(vx, vz)` — las esquinas entre 4 celdas. El "bloque de soporte" de un
vértice es la 2×2 de celdas `(vx-1..vx, vz-1..vz)`. Una ruta es una lista
de vértices consecutivos, cada uno a 1 paso (8 direcciones) del anterior
— eso ya obliga el solape entre bloques consecutivos: 2 celdas en un paso
ortogonal, 1 celda en un paso diagonal. No hace falta ninguna regla extra
para el solape.

**`Vias.gd`, autoload nuevo** (lógica pura, sin nodos — mismo patrón que
`Zonificacion.gd`), registrado en `project.godot` junto a los demás.

- **`TIPOS: Dictionary`** — catálogo por datos. Único tipo implementado:
  ```gdscript
  "tierra_pisada": {
      "ancho": 2, "sentido": "doble", "bono_velocidad": 1.35,
      "costo": {}, "material": preload("res://assets/mat_tierra_pisada.tres"),
  }
  ```
  Tipos futuros (calzada +60%, vía férrea ancho 2 sentido único, cintas/
  tuberías ancho 1 sentido único, calzada peatonal ancho 1 sentido libre)
  se agregan como filas nuevas cuando se implementen — no antes.
- **`celdas: Dictionary`** (`Vector3i` soporte → `String` tipo). El
  soporte es la celda que lleva la vía en su cara superior: terreno
  nivelado, relleno, o una `cuna_recta`/`cuna_esquina`.
- **`_columnas: Dictionary`** (`Vector2i` → true), índice derivado de
  `celdas` para consultas por columna (ver Sección 6).
- **API:** `es_via(soporte) -> bool`, `tipo_en(soporte) -> String`,
  `bono_en(soporte) -> float` (1.0 si no es vía), `hay_via_en_columna(xz)
  -> bool`, `agregar(celdas: Dictionary, tipo: String)`, `quitar(celdas:
  Array)`. Señal `vias_cambiadas(celdas: Array)` para el renderer.

**Vínculo con el mundo:** `VoxelWorld._retirar_bloque()` llama a
`Vias.quitar([celda])` al final — minar el soporte borra la vía. No hay
persistencia de partida todavía (el juego no la tiene en ningún sistema).

## 2. Relleno y cuñas entre bloques

Cada bloque 2×2 se nivela a su altura máxima interna (mismo criterio de
`NiveladorTerreno.altura_objetivo()`: nunca se cava, solo se rellena).
Entre dos bloques consecutivos del trazo, con niveles `L_i`/`L_i+1`:

- **Diferencia 0:** overlay plano, sin pieza especial.
- **Diferencia 1:** las celdas de solape (2 en tramo recto, 1 en
  diagonal) se convierten en cuña — lado hacia el bloque bajo a altura
  relativa 0, lado hacia el bloque alto a altura relativa 1.
- **Diferencia 2 o 3:** las celdas del bloque más bajo que NO son parte
  del solape se rellenan con tierra hasta quedar a un solo nivel de
  diferencia del bloque alto (mismo material/patrón de relleno que ya usa
  `Construccion.gd`/`NiveladorTerreno` para blueprints); luego el solape
  se resuelve como el caso de diferencia 1.
- **Diferencia > 3:** el trazador la rechaza antes de llegar aquí (ver
  Sección 4) — no hay puente en este alcance, es del sistema de puentes
  futuro (GDD Sección "Sistema de Puentes").

Dos piezas nuevas en `BlockLibrarySource.tscn` (reexportadas con el
workaround headless de `export_mesh_library`, ver nota del bridge roto en
memoria de sesión):

- **`cuna_recta`:** pendiente en un solo eje (un lado a 1, el opuesto a
  0). 4 orientaciones vía la rotación nativa de `GridMap`. Usada en pasos
  ortogonales.
- **`cuna_esquina`:** la esquina baja en una punta, la alta en la
  diagonal opuesta. También 4 orientaciones. Usada en pasos diagonales.
- **Colisión de ambas:** `ConvexPolygonShape3D` con los vértices reales de
  la rampa — no una `BoxShape3D` — así avatar y colonos caminan la
  pendiente real.
- **Material:** `assets/mat_tierra_pisada.tres` (nuevo, tono más oscuro/
  compacto que `tierra`), el mismo que usa el overlay plano (Sección 3) —
  para que una vía se vea distinta del terreno desde el día uno, y una
  evolución futura a calzada/carretera solo cambie este material sin
  retrazar nada.

## 3. Overlay visual de tramos planos

`ViasRenderer.gd` nuevo, nodo hijo de `VoxelWorld` (calcado de
`TranslucidosRenderer.gd`: chunks de 16, reconstruye solo el chunk sucio
al recibir `vias_cambiadas`). Dibuja una malla delgada pegada a la cara
superior de cada celda de `Vias.celdas` cuyo soporte NO sea
`cuna_recta`/`cuna_esquina` (la cuña ya es la superficie visible), con el
material de `Vias.TIPOS[tipo]["material"]`.

## 4. Trazador en `CamaraCenital.gd`

Mismo patrón que zonificar (`Z`) y colocar puesto: modo exclusivo nuevo,
tecla `V`, sale con `Esc` o al activar otro modo (`_salir_de_todos_los_
modos()` gana esta salida).

**Estado:** `modo_trazar_via: bool`, `_tramos_fijos: Array` (cada uno,
`Array[Vector2i]` de vértices ya confirmados), `_vertice_inicio_tramo:
Vector2i`.

**Buscador por vértices:** reusa `BuscadorRutas`, pero sobre vértices
Vector2i con 8 vecinos (no celdas 3D con 4 vecinos como hoy lo usa
`Colonos`) e ignora `TIPOS_ARBOL` como obstáculo — un vértice solo es
intransitable por agua, estructura/edificio, o desnivel de bloque-soporte
mayor a 3 (Sección 2).

**Flujo de clics:**
1. Primer clic: fija `_vertice_inicio_tramo` en el vértice más cercano al
   cursor. No hay tramo previo.
2. Mientras el mouse se mueve: recalcula la ruta más corta entre
   `_vertice_inicio_tramo` y el vértice bajo el cursor y la pasa a la
   vista previa. Un tramo sin ruta posible se tiñe de rojo (mismo patrón
   que el rectángulo de zona inválido) y no se puede fijar.
3. Clic siguiente:
   - Mismo vértice que `_vertice_inicio_tramo` → cancela el tramo en
     curso, no confirma nada.
   - Vértice ya perteneciente a una vía construida o a la vista previa
     acumulada → ese tramo se fija como el último; se confirma TODO lo
     acumulado (Sección 5) de una vez, y el modo vuelve al paso 1.
   - Cualquier otro punto → el tramo actual pasa a `_tramos_fijos`; ese
     vértice se vuelve el `_vertice_inicio_tramo` nuevo.
4. Clic derecho: descarta solo el tramo en curso (`_tramos_fijos` no se
   toca) — mismo patrón que `_cancelar_pintado_zona()`.

## 5. Confirmación y construcción

Instantánea, sin cola de `Construccion.gd` (decisión del usuario — hoy no
hay costo ni mano de obra que justifique una cola; cuando exista
construcción por NPC/avatar, sección futura). Por cada tramo confirmado:

1. Cada vértice se traduce a su bloque de soporte 2×2.
2. **Choque, todo o nada:** por cada columna XZ tocada por el tramo
   (incluidas las de relleno), se reutiliza
   `_huella_choca_con_otro_puesto(esquina, columnas)` (la MISMA función
   que ya usan puestos y blueprints — ver Sección 6 para el lado inverso).
   Si choca en cualquier columna, el tramo entero se rechaza, ninguna
   celda se toca.
3. **Árboles:** antes de nivelar, cada celda de soporte con tipo `madera`
   se tala con `mundo.talar_bloque_de_arbol(celda, dano_total)` (daño
   suficiente para un solo golpe); cada celda `follaje` se limpia con
   `mundo.eliminar_follaje(celda)`. La vista previa (Sección 4) ya no
   trata árboles como obstáculo. Sin recolección real todavía — la madera
   desaparece, igual de "gratis" que el resto de este tipo de vía. Cuando
   exista construcción por NPC/avatar, la tala se conecta con recolección
   real (obreros llevan la madera al puesto maderero/almacén más
   cercano, o el avatar la suma directo al almacén central, como
   cualquier recurso que recolecta hoy).
4. Relleno y cuñas de la Sección 2, vía `VoxelWorld.colocar_bloque()`
   directo.
5. Cada celda de soporte se registra en `Vias.celdas` con tipo
   `"tierra_pisada"` y se emite `vias_cambiadas`.
6. Costo: `{}` — no se cobra nada, ni el relleno. Tipos futuros con costo
   (calzada, etc.) lo cobrarán cuando exista inventario real que
   descontar.

## 6. Choque inverso: edificio/puesto sobre vía

`_huella_choca_con_otro_puesto()` (única función compartida por puestos y
blueprints) gana una comprobación más: `Vias.hay_via_en_columna(xz)`. Con
este único cambio, ambos flujos (puesto y blueprint) rechazan colocarse
sobre una vía existente — mismo principio de "arreglar donde convergen
todos los llamadores" que ya sigue el resto del código.

Con las Secciones 5 y 6 juntas quedan cubiertas las 4 combinaciones:
vía-sobre-edificio, vía-sobre-puesto, edificio-sobre-vía,
puesto-sobre-vía — todas rechazadas.

## 7. Bono de velocidad

`Vias.bono_en(soporte: Vector3i) -> float` — recibe la celda de SOPORTE
(el bloque bajo los pies), no la celda donde está parado el personaje.

- **`Colonos.gd`, en `_completar_paso()`:** `delta * VELOCIDAD_COLONO`
  pasa a `delta * VELOCIDAD_COLONO * Vias.bono_en(c["celda"] - ARRIBA)` —
  el bono de la celda desde la que arranca el paso actual. No hace falta
  tocar `BuscadorRutas`: la vía ya es terreno transitable normal para el
  pathfinding, el bono es puramente de velocidad.
- **`Player.gd`, en `_physics_process()`:** antes de fijar
  `velocity.x/z`, si `mundo != null`, calcula `Vias.bono_en(_celda_en(
  global_position) - Vector3i(0, 1, 0))` y multiplica `VELOCIDAD` por ese
  factor. Sin transición suave — cambio instantáneo al cruzar la celda,
  igual que ya pasa con natación/oxígeno.

Caminar sobre una `cuna_recta`/`cuna_esquina` ya cuenta como estar sobre
`tierra_pisada` (están registradas en `Vias.celdas` igual que el terreno
plano), así que el bono aplica igual en la pendiente.

## 8. Fuera de alcance (explícito)

- Cobro de recursos por vía (más allá de `tierra_pisada`, gratis),
  construcción por NPC/avatar, y tala con recolección real.
- Calzada, carretera pavimentada, vía férrea, cintas transportadoras,
  tuberías: solo la fila de datos en `Vias.TIPOS`, sin pieza, sin
  renderer propio, sin trazador especial.
- Sistema de puentes (desnivel > 3, o cruce sobre agua/vías/edificios
  existentes elevando el tablero) — GDD lo define como etapa siguiente,
  independiente de este spec.

## 9. Verificación

Nueva escena `ViasTest.tscn` + `ViasTest.gd` (mismo patrón de aserciones
con `assert` y mundos falsos que `ZonificacionTest.gd`/
`NiveladorTerrenoTest.gd`):

- `Vias.agregar()`/`quitar()`/`es_via()`/`tipo_en()`/`bono_en()`/
  `hay_via_en_columna()`.
- Bloque de soporte 2×2 desde un vértice; solape recto (2 celdas) vs.
  diagonal (1 celda).
- Relleno + cuña recta (desnivel 1, 2, 3) y cuña de esquina en diagonal.
- Trazado por vértices con `BuscadorRutas` (8 vecinos, ignora árboles,
  respeta tope de desnivel 3, rechaza agua/estructura).
- Tala de árbol/follaje al confirmar un tramo que los atraviesa.
- Choque en ambos sentidos: vía sobre edificio/puesto rechazada, edificio/
  puesto sobre vía rechazado.
- Bono de velocidad de `Colonos` y `Player` sobre una celda de vía.

Verificación final (CLAUDE.md): `Test.tscn`, `ViasTest.tscn`,
`ColonosTest.tscn`, `NiveladorTerrenoTest.tscn`, y
`PlayerNatacionTest.tscn`/`PlayerOxigenoTest.tscn` (tocan `Player.gd` por
el bono de velocidad), corridas con Godot 4.7 vía las herramientas
`mcp__godot__*` headless, confirmando que todas las aserciones pasan y
sin errores nuevos al cargar `Main.tscn`.

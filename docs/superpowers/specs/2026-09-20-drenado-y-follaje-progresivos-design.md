# Drenado de Agua y Eliminación de Follaje Progresivos — Diseño

## Contexto

Al emplazar un blueprint, `CamaraCenital._procesar_clic_blueprint()` drena hoy
el agua de la huella y la fachada (`VoxelWorld.drenar_agua()`, que la convierte
en tierra) y borra el follaje detectado (`eliminar_follaje()`) **al instante**,
antes de que el jugador surta nada. Además `iniciar_construccion_fantasma()`
pone bloques `fantasma` con `colocar_bloque()`, que sí reemplaza el agua.

Regla pedida por el usuario: al emplazar un blueprint no se modifica el
terreno; este cambia bloque a bloque cuando el jugador o un NPC interactúa con
el fantasma (excavación → relleno → construcción). Por tanto **el drenado de
agua y la eliminación del follaje ocurren en el mismo instante en que el bloque
fantasma correspondiente se vuelve sólido**.

## Decisiones confirmadas con el usuario

- Mientras esperan su turno, las celdas del edificio ocupadas por agua o
  follaje se ven con un **marcador fantasma superpuesto** (caja translúcida
  azul sobre el agua/follaje).
- El follaje que queda en celdas que NO se vuelven sólidas (interior del
  edificio, sobre columnas cavadas) desaparece **por columna, con el primer
  paso de esa columna**.

## Restricción de diseño

Una celda del `GridMap` guarda un solo bloque: un fantasma no puede convivir
con agua o follaje en la misma celda. Las celdas ocupadas por agua o follaje se
comportan como el terreno sin cavar: siguen como están hasta que les toca su
turno, y entonces se retira el ocupante y queda el bloque sólido.

## Alcance

Dentro: no drenar ni borrar follaje al emplazar; no reemplazar agua con
fantasmas; sustitución de ocupantes al aplicar cada paso; registro y limpieza
de follaje por columna; marcadores superpuestos; pruebas; documentación.

Fuera: agua en celdas interiores sin construir (vaciarlas dejaría que el agua
vecina vuelva a entrar; queda como está); marcadores para terreno sin cavar;
destacar (color) puertas/ventanas ocupadas por follaje; los puestos periféricos
(siguen usando `drenar_agua`/`eliminar_follaje` al confirmar).

## Diseño

### 1. Emplazar no toca el mundo (`CamaraCenital.gd`)

- El clic deja de llamar a `eliminar_follaje()` y a `drenar_agua()` (y elimina
  su mensaje "Agua drenada…").
- La nivelación ya se calcula con `nivelador_puesto`, que usa la altura del
  **fondo** (sin agua, `_AlturaSinAgua`): las celdas de agua entre el fondo y
  el nivel base pasan a ser celdas de **relleno** ("tierra") sobre agua. Coste
  a tener presente: ese relleno cuesta tierra y aparece en el resumen de
  materiales; antes el drenado era gratis.
- Las celdas de relleno se colocan a partir de `altura_en(x, z, true)` (sin
  agua), no de `altura_en(x, z)`: el agua sigue en el mundo.
- Tras `iniciar_construccion_fantasma()`, el clic registra el follaje detectado
  (`resultado_huella` y `resultado_fachada`, `"follaje_a_eliminar"`) con
  `mundo.registrar_follaje_pendiente(id, celdas)`.

### 2. Las celdas ocupadas esperan su turno (`VoxelWorld.gd`)

- `iniciar_construccion_fantasma()` solo coloca `fantasma` en celdas
  **vacías** (`get_cell_item == INVALID_CELL_ITEM`). El agua deja de ser
  reemplazada; el follaje y el terreno ya no lo eran.
- Helper `_reemplazar_celda(celda, tipo)`, que sustituye el patrón
  "poner vacío y luego `colocar_bloque`" en el paso de estructura de
  `surtir_construccion()` y en `_aplicar_paso_cola()`:
  - agua: se sobrescribe con `colocar_bloque()` (no `set_cell_item` directo),
    que ya limpia `_nivel_agua` y encola el secado del agua vecina;
  - follaje: `eliminar_follaje()` (lo desregistra del árbol);
  - cualquier otra cosa: `set_cell_item(INVALID)` como hasta ahora.
  Así el agua se drena y el follaje desaparece en el mismo instante en que el
  bloque sólido ocupa la celda.

### 3. Follaje por columna (`VoxelWorld.gd`)

- `registrar_follaje_pendiente(id, celdas)`: agrupa las celdas por columna
  (`Vector2i`) y las guarda en `_follaje_por_columna` (columna → `{"id": id,
  "celdas": Array[Vector3i]}`) y en `edificio_follaje[id]` (las columnas del
  edificio, para poder descartarlas).
- Cada paso que se aplica (cola de preparación o estructura) llama primero a
  `_despejar_follaje_de_columna(columna_del_paso)`: retira con
  `eliminar_follaje()` el follaje registrado de esa columna que siga siendo
  follaje y borra la entrada. Si una celda liberada es una celda de estructura
  pendiente (registrada en `celda_a_edificio` y vacía) o de la cola
  (`Construccion.construccion_de(celda) != -1`), recibe su `fantasma`.
- `eliminar_edificio(id)` descarta las entradas de `edificio_follaje[id]`: si se
  quita el edificio antes de tiempo, el follaje no se toca.

### 4. Marcadores fantasma superpuestos

- `Construccion.celdas_pendientes(id) -> Array[Vector3i]`: las celdas de la
  cola `id` aún pendientes (índice ≥ `indice`).
- `VoxelWorld.celdas_fantasma_ocupadas() -> Array[Vector3i]` (lógica pura): las
  celdas pendientes de la estructura (índice ≥ `edificio_progreso`) y de la
  cola de preparación con destino `"tierra"` cuyo ocupante actual es `agua` o
  `follaje`.
- `FantasmasDestacados.gd` dibuja, además de las cajas de color de puertas y
  ventanas, una caja translúcida azul `Color(0.6, 0.7, 1.0, 0.35)` (constante
  `COLOR_FANTASMA_OCUPADO`, mismo tamaño 1.02) sobre cada celda de
  `celdas_fantasma_ocupadas()`. Se refresca con la señal `fantasmas_cambiados`
  (ya emitida en cada paso, y ahora también al registrar el follaje).

## Pruebas

Automáticas, `Test.tscn` (mundo `VoxelWorld.new()` propio):
- `iniciar_construccion_fantasma()` no reemplaza una celda de agua;
- un paso de relleno sobre una celda de agua la vuelve tierra y limpia
  `_nivel_agua`;
- el follaje de una columna desaparece con el primer paso de esa columna y no
  antes; una celda de estructura liberada recibe su fantasma;
- quitar el edificio antes de tiempo deja el follaje intacto;
- `celdas_fantasma_ocupadas()` y `Construccion.celdas_pendientes()`.
Manual: el dibujo de los marcadores; colocar un blueprint sobre agua y bajo
árboles y comprobar que nada cambia hasta surtir.

## Documentación

GDD §5 (Nivelación) y doc técnico de PoC 6: drenado y follaje progresivos,
marcadores, y que el agua bajo el edificio cuesta relleno.

## Riesgos conocidos

- La nivelación sobre agua pide más tierra que antes (el drenado ya no es
  gratis): el resumen de materiales lo refleja.
- Agua dentro de celdas interiores sin construir no se retira (fuera de
  alcance).
- El follaje registrado puede haber cambiado (talado, minado) antes de su
  columna: `_despejar_follaje_de_columna` solo retira lo que siga siendo
  follaje.

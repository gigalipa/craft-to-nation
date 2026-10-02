# Construcción y demolición por colonos — Especificación de diseño

Fecha: 2026-10-02. Punto 7b de `docs/Pendientes y próximos pasos.md` (sección 4b) y punto 6 de la lista principal («Construcción/deconstrucción asistida por NPCs»).

## Objetivo

Que las obras de edificios y puestos las construyan y demuelan los colonos libres, y que el jugador pueda ayudar a mano en cualquier momento. El jugador coloca una obra (cenital) o marca una demolición; los colonos hacen el trabajo.

## Decisiones del usuario

- Las obras puestas desde la cenital las construyen los colonos libres; el jugador puede seguir surtiéndolas en 1ª persona para acelerar.
- Constructores: obreros desempleados y técnicos libres (sin puesto). Un colono con empleo ignora las obras.
- Cuadrilla libre y sin tope por obra, al mismo ritmo que el jugador (mismo tiempo por paso).
- Las vías quedan fuera: siguen siendo instantáneas y gratis.
- Demolición: la marca es reversible (clic derecho en 1ª persona con el modo G activo, clic en la cenital). Los colonos deconstruyen como el jugador, con reembolso.
- Un edificio marcado se ve con un tinte rojo translúcido (cenital y 1ª persona).
- Prioridad: construir antes que demoler; a igualdad, la tarea más cercana.
- Enfoque elegido: coordinador nuevo (`Obras`) más lógica de finalización compartida con `Player`.

## Estado actual relevante

- Una obra es un edificio con `edificio_orden`, `edificio_progreso` y celdas fantasma. `VoxelWorld.surtir_construccion(celda)` avanza una celda por llamada, cobra el costo de esa celda al almacén (`Ciudad.consumir_costo`), devuelve `bloqueada` si hay ocupantes e `insuficiente` si falta material.
- `VoxelWorld.procesar_deconstruccion(celda)` revierte una celda y reembolsa; al llegar a lista para remoción, `Player` ejecuta la limpieza final (`eliminar_edificio`, `Zonificacion`, `Recoleccion`, `Economia`).
- El registro al completar una obra vive en `Player._completar_construccion(metadata)`.
- `Colonos.gd` no tiene un sistema genérico de tareas: `_decidir_trabajo` sigue `c["trabajo"]["rol"]` y `c["fase"]`. Se reutilizan `_ir_junto_a`, `_junto_a`, `_celdas_junto_a`, `_dejar_lo_que_hacia` y `_on_obra_a_fantasma`.
- La demolición cenital (`modo_demoler`) hoy no hace nada al hacer clic.

## Componentes

### `FinalizacionObras.gd` (script estático, nuevo)

Extrae de `Player` dos funciones que `Player` y los colonos usan por igual:
- `completar_construccion(mundo, metadata)`: lo que hoy hace `Player._completar_construccion` (puesto nuevo, reactivar puesto, núcleo, edificio residencial, influencia).
- `retirar_edificio(mundo, id)`: la limpieza al demoler (`Ciudad.retirar_edificio_residencial`, desactivar puesto, `eliminar_edificio`, `Zonificacion.retirar_contribucion`, `Recoleccion.quitar_puesto`, `Economia.quitar_puesto`).

`Player` pasa a llamarlas sin cambiar su comportamiento.

### `Obras.gd` (autoload, nuevo)

- Estado: lista de obras de construcción en curso (ids), conjunto de ids marcados para demolición, obras en pausa por material (con el recurso que falta) y vetos temporales por colono y obra.
- `marcar_demolicion(id) -> bool` / `desmarcar_demolicion(id)` / `esta_marcado(id)`: rechaza el núcleo urbano; emite `marca_cambiada(id, marcado)`.
- `siguiente_tarea(colono) -> Dictionary`: devuelve `{tipo: "construir"|"demoler", id, celda_acceso}` o vacío. Descarta obras en pausa, sin acceso y vetadas para ese colono; prefiere construir y desempata por distancia.
- `pausar(id, recurso)`: notifica una sola vez por obra y recurso. Una obra pausada vuelve a ofrecerse cuando el almacén tiene de nuevo ese recurso.
- Escucha `obra_a_fantasma` (alta de obra) y la eliminación de edificios (baja de obra y de marca).
- No mueve colonos ni modifica bloques.

### `Colonos.gd` (rama nueva en `_decidir_trabajo`)

Un colono libre (desempleado o técnico sin puesto) pide `Obras.siguiente_tarea`, camina junto a la obra con `_ir_junto_a`, espera el tiempo del paso (`proximo_paso_pendiente`, mismo cálculo que `Player._intervalo_accion_actual`) y llama a `surtir_construccion` o `procesar_deconstruccion`. Estados nuevos de `c["fase"]`: `obra_ir`, `obra_trabajar`.

### Marcado y presentación

- 1ª persona: con el modo G activo, el clic derecho alterna la marca (hoy solo avisa). La tarjeta ya anuncia «MARCAR PARA DEMOLICIÓN».
- Cenital: en `modo_demoler`, el clic alterna la marca del edificio bajo el cursor.
- Tinte rojo translúcido: un nodo overlay nuevo (`MarcasDemolicionOverlay.gd`) dibuja una caja translúcida roja por celda del edificio marcado, siguiendo el patrón de `ZonaOverlay.gd` y `NivelacionOverlay.gd`. Se actualiza con la señal `marca_cambiada`. (`TranslucidosRenderer` no sirve: es solo para agua y vidrio.)

## Flujo

### Construcción
1. La cenital crea la obra fantasma; `Obras` la registra.
2. El colono recibe la obra más cercana con trabajo y una celda libre de acceso junto a ella.
3. Camina, espera el tiempo del paso y llama a `surtir_construccion`:
   - avanzó: repite;
   - insuficiente: `Obras.pausar`, una notificación, el colono toma otra tarea;
   - bloqueada por ocupantes: espera o toma otra tarea;
   - completa: `FinalizacionObras.completar_construccion` y pide otra tarea.
4. Varios colonos pueden trabajar la misma obra: cada llamada avanza una celda en el orden de la obra. Todos deben estar fuera de ella.

### Demolición
1. Al marcar, `Obras` ofrece el edificio como tarea de demolición.
2. Cada paso llama a `procesar_deconstruccion` (reembolso por celda; al revertir la primera celda se retiran camas y se desactiva el puesto, como en 1ª persona).
3. Con el edificio «listo para remoción» el colono ejecuta `FinalizacionObras.retirar_edificio`. No usa `TICKS_REMOCION_FINAL`: ese contador evita borrados accidentales con el ratón.
4. Al desmarcar, los colonos dejan de deconstruir; el edificio queda a medias como obra fantasma y puede reconstruirse.
5. Un colono dentro de un edificio que se demuele sale antes (se reutiliza `_on_obra_a_fantasma`).

## Casos límite

- Sin colonos libres: las obras esperan; el jugador puede ayudar a mano.
- Obra o edificio eliminado con un colono trabajando: suelta la tarea y pide otra.
- Colono contratado mientras iba a una obra: deja la tarea; el empleo manda.
- Colono atrapado o sin ruta: `_recuperar_si_atrapado`; tras varios fallos, la obra queda vetada para él un tiempo.
- Jugador y colonos a la vez en una obra: sin conflicto (misma función, una celda por llamada).
- Marcar un edificio sin terminar: permitido; se deconstruye lo ya construido.
- Marcar el núcleo urbano: rechazado con notificación.
- Material insuficiente: una notificación por obra y recurso.

## Pruebas

- `ObrasTest.tscn` (nueva): `siguiente_tarea` elige lo más cercano, prefiere construir a demoler, y no ofrece obras pausadas, vetadas ni sin acceso; marcar y desmarcar alternan; el núcleo se rechaza.
- `ColonosTest`: un libre completa una obra y queda registrado el puesto; un libre demuele un edificio hasta eliminarlo con reembolso; un colono empleado ignora las obras.
- `Test` (`BlueprintValidatorTest`): `FinalizacionObras` produce el mismo resultado que el flujo previo de `Player`.
- `HUDTest` y pruebas de cámara: marca roja y clic derecho en modo G.

## Fuera de alcance

Tendido de vías por colonos, tope de cuadrilla por obra, filtros y prioridades configurables de obras, y niveles de puesto y empleo por tipo (puntos 2, 3 y 6 de la sección 4b).

## Documentación a actualizar al implementar

`docs/Pendientes y próximos pasos.md` (marcar 7b y el punto 6 de la lista principal) y el documento técnico de la PoC afectada (PoC_5, Fase 2A, sección de obras) con las decisiones de esta especificación.

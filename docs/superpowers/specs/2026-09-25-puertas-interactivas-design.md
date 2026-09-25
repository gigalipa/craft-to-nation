# Puertas interactivas — diseño

Punto 1 de `docs/Pendientes y próximos pasos.md`. Fecha: 2026-09-25.

## Objetivo

Que el avatar pueda entrar y salir de los edificios abriendo y cerrando puertas, sin romper a los colonos ni a los edificios ya construidos. Hoy las puertas (`puerta_inferior` + `puerta_superior`) son bloques sólidos para el avatar y solo las ignoran los colonos en su búsqueda de rutas.

## Decisiones del usuario

- La puerta ya no ocupa visualmente un bloque entero: es una lámina de 1/10 de bloque, de 2 celdas de alto.
- Abrir = la lámina gira al instante 90° sobre su eje vertical central: de cubrir la cara del hueco (intransitable) a verse de canto (transitable). Ocupa las mismas 2 celdas; solo cambia el estado.
- Avatar: pulsar `E` apuntando a la puerta la alterna.
- Colonos: no interactúan; la puerta reacciona por proximidad. Se cierra sola cuando se van, salvo la abierta por el avatar, que solo se cierra con `E`. Si el avatar cierra una puerta con un colono cerca, se reabre.
- Enfoque elegido: estado aparte del tipo de bloque (el tipo de celda no cambia).

## Estado y ciclo de vida

- `VoxelWorld` sigue siendo la fuente de verdad de la ocupación: las celdas siguen siendo `puerta_inferior`/`puerta_superior`. No se tocan las más de 100 comparaciones de tipo en validador, colonos y pruebas.
- Nodo nuevo `Puertas` (hijo de `VoxelWorld`, como `TranslucidosRenderer`) con `_puertas: Dictionary` (clave: celda inferior; valor: `abierta`, `manual`, nodo de la lámina, cuerpo). La celda superior no tiene entrada propia.
- Los ítems `puerta_inferior`/`puerta_superior` de la MeshLibrary quedan con malla y forma vacías, en `_indexar_biblioteca()` (como `fantasma`): no hay que reexportar el `.res`.
- Alta: una celda `puerta_inferior` con su pareja superior aparece (`colocar_puerta()` a mano, o `surtir_construccion()` al completar una obra; ambas pasan por `colocar_bloque()`). Nace cerrada. El registro depende solo de que ambas celdas tengan el tipo correcto, no del orden ni de `pareja`. No hay migración: el juego no tiene guardado de partidas, así que toda puerta nace en la sesión por esa vía y ya nace con estado.
- Baja: cualquiera de sus dos celdas deja de ser puerta (minada, revertida a fantasma, edificio eliminado).
- Un fantasma de puerta (obra sin surtir) no tiene lámina ni colisión aquí: lo cubre `CuerposObra`.
- Señal nueva `puerta_cambiada(celda)`, emitida desde los mismos puntos que hoy emiten `bloque_translucido_cambiado` (colocar, minar, revertir a fantasma, drenar, etc.), con el filtro de tipos de puerta. `Puertas` sincroniza solo esa celda.

## Geometría y colisión

- Lámina: `MeshInstance3D` con caja de 1 × 2 × 0,1 bloques y el material café-naranja de la puerta actual. Centrada en el grosor de la celda; abierta, el nodo gira 90° en el eje vertical central (por eso no hace falta saber cuál es el lado exterior). Sin animación.
- Orientación (sin datos nuevos, deducida de los vecinos): si las dos celdas laterales en ±X son sólidas, la pared corre por X; si lo son las de ±Z, por Z; sin par sólido (puerta suelta) se toma X. Un fantasma cuenta como sólido (es una pared aún por surtir). Se recalcula en cada chequeo periódico, porque en una obra la puerta puede surtirse antes que sus paredes.
- Colisión: un `StaticBody3D` por puerta con una `CollisionShape3D` que cambia según el estado.
  - Cerrada: caja de 1 × 2 × 0,1 en capa 1 (mundo). Bloquea al avatar y a los raycasts de la cámara cenital.
  - Abierta: la caja girada 90° en una capa nueva (capa 4). El avatar (`collision_mask = 3`) la atraviesa; el `RayCast3D` de `Player` se amplía con la capa 4 para poder apuntarla y cerrarla.
- El cuerpo lleva la celda inferior como metadato (`celda_puerta`); `Player` lo lee del colisionador del raycast.
- A verificar en el plan: con la puerta cerrada, el avatar no puede colarse por el 90 % del grosor de la celda sin colisión (aserción sobre la posición del avatar tras chocar).

## Interacción

- Avatar: en `Player.gd` se agrega un despachador `_interactuar()` al pulsar `E` (evento sin eco de repetición) según el objeto apuntado.
  - Puerta: `Puertas.alternar(celda)`. Al abrir con `E`, `manual = true`; al cerrar, `manual = false`.
  - Baúl: sin efecto por ahora (ver "Trabajo futuro").
- Mantener `E` sigue siendo `_procesar_frutos()`; solo se añade que sale sin hacer nada si el objetivo es una puerta. Pulsar y mantener no chocan: sobre una puerta, mantener no hace nada; sobre un árbol, pulsar no hace nada.
- Colonos: `Puertas` corre un chequeo cada ~0,25 s (no por frame). Por cada puerta busca en `Colonos.colonos` (`c["celda"]`) algún colono a distancia Chebyshev ≤ `RADIO_APERTURA` (2) en XZ y a ±1 de altura.
  - Con alguien cerca y cerrada: se abre con `manual = false`.
  - Sin nadie cerca, abierta y `manual = false`: se cierra.
  - `manual = true`: no se cierra sola.
- `BuscadorRutas` y los colonos no cambian: siguen tratando las puertas como libres; la puerta es solo un efecto para ellos y no los bloquea.

## Errores y bordes

- Una puerta que pierde una celda estando abierta se destruye por `puerta_cambiada` y libera sus nodos.
- `alternar()` sobre una celda que ya no es puerta no hace nada.
- Sin `Colonos` (escenas de prueba sin él) el chequeo no hace nada.

## Pruebas

Escena nueva `godot/scenes/PuertasTest.tscn` (mismo estilo de aserciones que `TranslucidosRendererTest`):

- Registro: una puerta colocada nace cerrada, con la orientación correcta (pared por X, por Z, puerta suelta).
- `alternar()` cambia estado, capa y forma del cuerpo.
- Proximidad: un colono cerca abre; al alejarse cierra. `manual = true` no cierra sola.
- Cierre del avatar con un colono cerca: se reabre.
- Ciclo de vida: minar una celda destruye entrada y nodos; una puerta con solo una mitad no se registra, sin importar el orden de colocación.

Además: `godot/scenes/Test.tscn` y las escenas afectadas (`ColonosTest`, `PlantillasPuestoTest`, `BlueprintValidatorTest`), según `CLAUDE.md`.

## Documentación

Actualizar el documento técnico de PoC 3 con esta decisión y mover el punto 1 de "Pendientes" a "Hecho" al terminar.

## Fuera de alcance

Animación de giro, sonido, puertas dobles, cerraduras/llaves, colonos bloqueados por una puerta cerrada, y el prompt de interacción en pantalla (lo resuelve el HUD, punto 2).

## Trabajo futuro (enchufa en `_interactuar()`)

Ventana de contenido del baúl (punto 3 de Pendientes): pulsar `E` apuntando a un baúl abre una ventana similar a la de asignación de obreros, con extraer y agregar recursos. Al construirla se elimina la rama de retiro del baúl por `E` mantenida en `_procesar_frutos()`; hasta entonces esa rama se conserva para que el baúl no quede sin acceso.

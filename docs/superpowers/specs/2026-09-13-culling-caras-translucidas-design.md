# Diseño: Culling de caras internas entre bloques translúcidos (agua/ventana)

Contexto: GDD Sección 11 (Fase 3, PoC 6). Reportado jugando en vivo: donde dos bloques translúcidos del mismo tipo (`"agua"` o `"ventana"`) quedan pegados, se ve un "panel" interno entre ambos — la cara compartida de cada cubo se dibuja igual, y al usar alpha blend las dos caras coincidentes se combinan de forma visible. Esto no es un problema de textura/material: `GridMap` coloca en cada celda la malla COMPLETA del cubo (6 caras) sin saber qué hay en las celdas vecinas, así que nunca hay culling de caras internas entre celdas — algo que para bloques opacos no se nota (el z-buffer solo deja ver la cara de encima) pero que en bloques translúcidos sí es visible.

Código existente relevante: `godot/scripts/VoxelWorld.gd` (`colocar_bloque()`, `minar_bloque()`, `obtener_tipo()`, `_generar_terreno()`, `_revertir_celda()`, `eliminar_edificio()`, `drenar_agua()` — todos los puntos donde una celda cambia de tipo), `godot/scenes/BlockLibrarySource.tscn` / `godot/assets/BlockLibrary.res` (mallas y materiales por tipo de bloque), `godot/scenes/Main.tscn` (árbol de nodos de la escena principal).

## Alcance de esta etapa

- Culling de caras internas para los dos tipos translúcidos existentes: `"agua"` y `"ventana"`.
- `GridMap` sigue siendo la ÚNICA fuente de verdad para ocupación/colisión/lógica de juego (minado, construcción, detección de estructura, despejes, etc.) — nada de eso cambia. Este diseño es puramente visual: qué caras se dibujan, no qué existe.
- La colisión de `"ventana"` (ya sólida, sin cambios) y la ausencia de colisión de `"agua"` (ya no sólida, ver spec de ríos) se mantienen exactamente igual.
- Regla de culling: una cara entre dos celdas se omite únicamente si AMBAS son del MISMO tipo translúcido. Agua junto a ventana, o junto a un bloque sólido, o junto a aire, siempre dibuja esa cara.
- **Fuera de alcance:** cualquier efecto visual adicional de agua/ventana (olas, reflejos, distorsión), y todo tipo de bloque translúcido futuro más allá de estos dos (el diseño es fácilmente extensible, pero esta etapa no generaliza más de lo necesario — ver Sección 1, `TIPOS_TRANSLUCIDOS`). También fuera de alcance: optimizar el caso de una cara translúcida contra un bloque OPACO como sólido (p. ej. el fondo de una columna de agua apoyada en tierra) — esa cara se sigue dibujando siempre según la regla de arriba, aunque en la práctica casi nunca se vea; no vale la pena la complejidad de detectarla como caso especial.

## 1. `TIPOS_TRANSLUCIDOS` y desactivación de la malla de `GridMap`

Nueva constante en `VoxelWorld.gd`:

```gdscript
const TIPOS_TRANSLUCIDOS := ["agua", "ventana"]
```

En `godot/scenes/BlockLibrarySource.tscn`, los `MeshInstance3D` de `"agua"` y `"ventana"` cambian su `mesh` a un `ArrayMesh` vacío (0 superficies) en vez del `BoxMesh` actual. El `CollisionShape3D` de `"ventana"` (hijo del mismo nodo) NO se toca — en Godot, la `MeshLibrary` exportada guarda `mesh` y `shapes` como propiedades independientes del ítem, así que un ítem sin malla visual conserva su forma de colisión normal. `"agua"` ya no tiene `CollisionShape3D` (cambio de la spec de ríos), así que no hay nada que preservar ahí. Tras el cambio, reexportar `assets/BlockLibrary.res` (`mcp__godot__export_mesh_library`).

Efecto: `GridMap` sigue ocupando la celda (colisión, `get_cell_item()`, `obtener_tipo()`, todo el registro de juego) exactamente igual que antes, pero ya no dibuja nada visible para esos dos tipos — el único renderizado visible de agua/ventana pasa a ser el de `TranslucidosRenderer` (Sección 2).

## 2. `TranslucidosRenderer` — nodo y estructura de datos

Nuevo script `godot/scripts/TranslucidosRenderer.gd`, `extends Node3D`, agregado como hijo de `VoxelWorld` en `Main.tscn` (mismo `Transform3D` que su padre — celdas en coordenadas de mundo enteras, igual que `GridMap` con `cell_size = 1`).

```gdscript
const CHUNK_SIZE := 16

var voxel_world: Node  # asignado en _ready() del padre — ver Sección 4
var _mesh_por_chunk: Dictionary = {}  # {tipo: String -> {chunk: Vector3i -> MeshInstance3D}}
var _material_por_tipo: Dictionary = {}  # String -> Material, indexado una vez desde mesh_library
```

- `_chunk_de(celda: Vector3i) -> Vector3i`: `Vector3i(floori(celda.x / float(CHUNK_SIZE)), floori(celda.y / float(CHUNK_SIZE)), floori(celda.z / float(CHUNK_SIZE)))` (división de piso real, no truncamiento — necesario para coordenadas negativas, que el mundo ya admite, ver `ALTURA_BUSQUEDA_MIN` en `VoxelWorld.gd`).
- Un `MeshInstance3D` por `(tipo, chunk)` con al menos una celda de ese tipo; se crea la primera vez que ese chunk tiene contenido y se elimina (`queue_free()` + borrar la entrada) si al reconstruirse queda con 0 caras.

## 3. Regla de culling (función pura y testable)

```gdscript
## true si debe dibujarse la cara entre una celda de tipo "tipo_propio"
## (uno de TIPOS_TRANSLUCIDOS) y su vecino de tipo "tipo_vecino" (""  si el
## vecino está vacío/fuera del mundo). Se omite la cara únicamente cuando
## ambos lados son del MISMO tipo translúcido (la cara es interna a un
## mismo cuerpo de agua/pared de ventanas) — cualquier otra combinación
## (aire, bloque sólido, u OTRO tipo translúcido distinto) sí se dibuja.
static func _cara_visible(tipo_propio: String, tipo_vecino: String) -> bool:
	return tipo_vecino != tipo_propio
```

Función estática, sin tocar `GridMap` — testable con pares de `String` sueltos.

## 4. Construcción de la malla de un chunk

```gdscript
func _reconstruir_chunk(chunk: Vector3i, tipo: String) -> void:
```

1. Recorre las `CHUNK_SIZE`³ celdas del chunk (`chunk * CHUNK_SIZE` hasta `chunk * CHUNK_SIZE + CHUNK_SIZE - 1` en cada eje).
2. Para cada celda cuyo `voxel_world.obtener_tipo(celda) == tipo`, evalúa sus 6 vecinos (`VoxelWorld.VECINOS_3D`, ya existente) con `voxel_world.obtener_tipo(vecino)` — nótese que esto SÍ cruza el borde del chunk hacia chunks adyacentes, consultando `GridMap` directamente (no hay problema de límites: `obtener_tipo()` ya maneja celdas fuera de cualquier rango, devolviendo `""` si están vacías).
3. Por cada vecino donde `_cara_visible()` da `true`, agrega un quad (2 triángulos) a un `SurfaceTool` en la posición/orientación de esa cara (offset `0.5` desde el centro de la celda en la dirección correspondiente, normal hacia esa dirección, UV `(0,0)-(1,1)` estándar de una cara de cubo unitario — mismo tamaño de celda que ya usa `GridMap.cell_size`).
4. Si el `SurfaceTool` no agregó ninguna cara, se borra el `MeshInstance3D` de ese `(tipo, chunk)` si existía; si agregó al menos una, se asigna `surface_tool.commit()` como `mesh` del `MeshInstance3D` (creándolo si no existía) y se le asigna `_material_por_tipo[tipo]` como material de superficie 0.

Este método es el único lugar que genera geometría — no hay meshing "greedy" (fusión de caras coplanares adyacentes en un solo quad más grande): cada cara sigue siendo un quad de 1x1, igual que ya es visualmente con `GridMap`. Fuera de alcance para esta etapa (optimización de recuento de triángulos, no de corrección visual).

## 5. Disparo de reconstrucción

**Reconstrucción inicial (generación del mundo):**

`VoxelWorld._ready()` llama a `translucidos.reconstruir_todo()` justo después de `_generar_terreno()` (antes de `_generar_arboles()`, que no coloca bloques translúcidos). `reconstruir_todo()`:

```gdscript
func reconstruir_todo() -> void:
	var chunks_por_tipo: Dictionary = {}  # String -> Dictionary (Vector3i -> true)
	for celda in voxel_world.get_used_cells():
		var tipo: String = voxel_world.obtener_tipo(celda)
		if not VoxelWorld.TIPOS_TRANSLUCIDOS.has(tipo):
			continue
		var chunk: Vector3i = _chunk_de(celda)
		if not chunks_por_tipo.has(tipo):
			chunks_por_tipo[tipo] = {}
		chunks_por_tipo[tipo][chunk] = true
	for tipo in chunks_por_tipo:
		for chunk in chunks_por_tipo[tipo]:
			_reconstruir_chunk(chunk, tipo)
```

Recorre `get_used_cells()` (API nativa de `GridMap`, ya contiene solo celdas ocupadas) UNA vez, agrupa por chunk, y reconstruye cada chunk afectado una sola vez — sin pasar por ninguna señal celda por celda durante la generación masiva inicial (miles de celdas de agua).

**Reconstrucción incremental (cambios posteriores — jugador coloca/mina):**

Nueva señal en `VoxelWorld.gd`:

```gdscript
signal bloque_translucido_cambiado(celda: Vector3i)
```

Emitida al final de `colocar_bloque()`, `minar_bloque()`, `_revertir_celda()`, `eliminar_edificio()` (una vez por celda) y `drenar_agua()` (una vez por celda reemplazada), pero SOLO si el tipo involucrado — el nuevo tipo en `colocar_bloque()`, el tipo que había ANTES de borrar en `minar_bloque()`/`_revertir_celda()`/`eliminar_edificio()`/`drenar_agua()` — pertenece a `TIPOS_TRANSLUCIDOS`. Evita procesar cualquier bloque sólido colocado/minado (la inmensa mayoría de las llamadas). Importante para la implementación: en las funciones que BORRAN una celda, el tipo debe leerse con `obtener_tipo(celda)` ANTES de llamar a `set_cell_item(celda, GridMap.INVALID_CELL_ITEM)` — una vez borrada, `obtener_tipo()` ya no puede saber qué había ahí. `TranslucidosRenderer` no necesita saber cuál era el tipo (Sección 5, `_on_bloque_translucido_cambiado()` reconstruye AMBOS tipos translúcidos igual), pero `VoxelWorld` sí lo necesita para decidir si emite la señal.

`TranslucidosRenderer._ready()` se conecta a esta señal:

```gdscript
func _on_bloque_translucido_cambiado(celda: Vector3i) -> void:
	var chunks_afectados: Dictionary = {}  # Vector3i -> true
	chunks_afectados[_chunk_de(celda)] = true
	for delta in VoxelWorld.VECINOS_3D:
		chunks_afectados[_chunk_de(celda + delta)] = true
	for chunk in chunks_afectados:
		for tipo in VoxelWorld.TIPOS_TRANSLUCIDOS:
			_reconstruir_chunk(chunk, tipo)
```

Marca sucios el chunk de la celda y los de sus 6 vecinos directos (nunca más de 7, normalmente 1 — solo son varios cuando la celda cae justo en un borde de chunk) y los reconstruye de inmediato para AMBOS tipos translúcidos en cada chunk afectado (simplifica el código: reconstruir un chunk que no tiene celdas de ese tipo es barato, ver Sección 4 punto 4 — sencillamente no genera malla). Este camino es para eventos raros (un bloque a la vez), así que reconstruir de más no es un problema de rendimiento.

## 6. Integración en `Main.tscn` / `VoxelWorld.gd`

- `Main.tscn`: nuevo nodo `TranslucidosRenderer` (`Node3D`, script `TranslucidosRenderer.gd`) como hijo de `VoxelWorld`.
- `VoxelWorld.gd`, en `_ready()`, después de `_generar_terreno()`:
  ```gdscript
  var translucidos: Node3D = get_node("TranslucidosRenderer")
  translucidos.voxel_world = self
  translucidos._indexar_materiales()  # lee mesh_library, guarda Mat_agua/Mat_ventana por tipo
  translucidos.reconstruir_todo()
  ```
- Las pruebas existentes que instancian `VoxelWorld.new()` sin agregarlo al árbol (ver `BlueprintValidatorTest.gd`) NO llaman a `_ready()`, así que no se ven afectadas por este cambio — `TranslucidosRenderer` nunca se construye en esos tests, y ninguna prueba existente depende de la malla visual.

## 7. Pruebas

Nuevo archivo `godot/scripts/TranslucidosRendererTest.gd` (mismo patrón que las pruebas puras existentes — sin necesidad de escena real para la función de culling):

- `_cara_visible()`: agua-agua → `false`; ventana-ventana → `false`; agua-"" (vacío/aire) → `true`; agua-ventana → `true`; agua-"pared" → `true`; ventana-"" → `true`.
- `_chunk_de()`: celdas dentro del mismo chunk (p. ej. `(0,0,0)` y `(15,15,15)`) dan la misma clave; `(16,0,0)` da una clave distinta en X; coordenadas negativas (p. ej. `(-1,0,0)`) dan chunk `(-1,0,0)`, no `(0,0,0)` (verifica división de piso real, no truncamiento).
- Prueba de integración ligera (instanciando `VoxelWorld` fuera del árbol, igual que `BlueprintValidatorTest.gd` ya hace, más un `TranslucidosRenderer` construido a mano apuntando a ese `VoxelWorld`): colocar dos celdas de `"agua"` adyacentes y llamar `reconstruir_todo()` — verificar que la malla resultante NO contiene ninguna cara en la dirección compartida (contando vértices/triángulos del `ArrayMesh` resultante, o verificando indirectamente vía `_cara_visible()` sobre las mismas celdas). Colocar una celda de agua junto a una de `"pared"` — verificar que esa cara SÍ se genera.
- Prueba de reconstrucción incremental: construir un `VoxelWorld` con `TranslucidosRenderer`, llamar `colocar_bloque()` con dos celdas de agua adyacentes UNA A LA VEZ (sin `reconstruir_todo()`, dependiendo solo de la señal), y verificar que el resultado final coincide con el de `reconstruir_todo()` sobre el mismo estado — confirma que el camino incremental y el de generación masiva convergen al mismo resultado.

`Test.tscn` y `GeneradorMundoTest.tscn` deben seguir corriendo sin errores nuevos tras el cambio (mismo criterio de verificación que etapas anteriores). Además, se debe correr `Main.tscn` real y confirmar visualmente (captura o inspección en el editor) que una celda de agua junto a otra celda de agua ya no muestra el panel interno, y que sigue viéndose la superficie/laterales expuestos correctamente.

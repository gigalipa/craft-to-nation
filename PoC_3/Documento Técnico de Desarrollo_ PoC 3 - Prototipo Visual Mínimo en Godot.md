# **Documento Técnico de Desarrollo: PoC 3 - Prototipo Visual Mínimo en Godot**

**Identificador del Módulo:** POC-03-VISUAL-PROTOTYPE

**Motor:** Godot Engine 4.3+ (GDScript, sin plugins ni assets de terceros en esta PoC)

**Dependencias de Diseño:** Sección 5 del GDD v3.3 (Mecánica de Plantillas), Sección 11 (Fase 1: Prototipo Visual Mínimo).

**Dependencia Técnica:** Puerto directo de la lógica de validación de `PoC_2/` a GDScript. No depende de `PoC_1/` (esa integración se planea para la Fase 2 del roadmap).

**✅ Verificado con Godot 4.7 (Steam), incluyendo GridMap, detección de edificios y objetos multi-celda:** `scenes/Test.tscn` corre (vía MCP de Godot) y los 9 tests de `BlueprintValidatorTest.gd` pasan sin errores de `assert()`. `scenes/Main.tscn` se jugó interactivamente (mouse/teclado, vía MCP de Godot + depurador): minar y colocar bloques funciona correctamente sobre `GridMap` + `MeshLibrary` (ver 2.1). Se agregó una mira mínima, el mecanismo de "declarar edificio" (flood-fill 3D, tecla `B` apuntando a una puerta — ver 2.5) y objetos multi-celda (puerta de 2 celdas verticales, cama de 2 celdas horizontales orientadas a la mirada del jugador, ambos con verificación de espacio y minado en cascada — ver 2.6), con 6 bugs reales encontrados y corregidos en total a lo largo de la PoC (ver 3.3). Se agregó también un bloque `baul` (placeholder de 1 celda, sin interacción) y la regla de almacenamiento se completó como conteo total por edificio (mínimo 1 baúl por cada cama, sin emparejar por posición — ver 2.6). Pendiente: mira contextual, interacción real del baúl, tests de evolución/personalización portados de PoC 2, y texturas PBR — ver Próximos Pasos.

---

## **FASE 1: IDEACIÓN**

### **1.1 Alcance y Objetivos de la PoC**

* **Avatar en 1ra Persona:** Controlador con movimiento WASD, mouse-look y gravedad básica.
* **Mundo Voxel Acotado:** Representación de bloques como celdas discretas (`Vector3i`), con colocación y remoción en tiempo real.
* **Minado y Colocación por Raycast:** Click izquierdo remueve la celda apuntada (o el objeto de 2 celdas completo, si aplica); click derecho coloca un bloque del tipo seleccionado (`pared`, `puerta`, `ventana`, `piso`, `cama`, `baul`) en la celda adyacente, según la normal del impacto. `baul` es un bloque placeholder de 1 celda sin ninguna interacción (no almacena objetos, no se puede abrir) — cuenta para la regla de almacenamiento (mínimo 1 baúl por cada cama del edificio, sin emparejamiento por posición — ver 2.6), pero no tiene comportamiento propio todavía.
* **Puerto del Validador de PoC 2 a GDScript:** Mismas siete reglas de validación (cerramiento, esquinas, aberturas, camas/baúl, zona, evolución, personalización de producción), operando sobre la misma estructura de datos (un Blueprint parseado de JSON), probadas con los mismos casos de PoC 2.
* **Declarar Edificio (detección automática):** apuntando a una puerta y presionando `B`, un flood-fill 3D sobre los bloques colocados por el jugador arma un Blueprint a partir de lo construido libremente y lo pasa por el mismo validador — ver 2.5.
* **Objetos Multi-Celda (puerta y cama):** la puerta ocupa 2 celdas apiladas verticalmente y la cama 2 celdas horizontales en la dirección de la mirada del jugador; ambas exigen que las 2 celdas estén libres antes de colocarse, y minar cualquiera de las dos borra el objeto completo — ver 2.6.

### **1.2 Fuera de Alcance**

* ~~**Detección automática de edificios**, pendiente de diseño.~~ **Implementado:** ver nueva Sección 2.5/3.3 — flood-fill 3D sobre bloques del jugador, activado apuntando a una puerta y presionando `B`.
* ~~**GridMap + MeshLibrary** pendiente por no poder abrir el editor.~~ **Migrado:** con el MCP de Godot conectado se generó `scenes/BlockLibrarySource.tscn` (4 `MeshInstance3D` con `CollisionShape3D` hijo directo, un ítem por tipo de bloque) y se exportó a `assets/BlockLibrary.res` vía `export_mesh_library`. `VoxelWorld.gd` ahora extiende `GridMap` en vez de gestionar nodos manualmente — ver 2.1 para el detalle de la migración.
* **Texturas PBR finales, inventario del avatar, zonificación real.** Quedan para fases posteriores.
* **Interacción real del baúl.** El bloque `baul` agregado es solo un placeholder visual de 1 celda (ver 1.1); no se abre y no almacena nada. Ya cuenta correctamente para la regla de validación (ver 2.6), pero cualquier inventario/gameplay real queda para fases posteriores.
* **Validación programática de la altura mínima por piso** (3 celdas de interior + 1 de techo, ver GDD Sección 5). Esta PoC solo hace que puerta y cama exijan su propio espacio de 2 celdas; verificar que un piso completo cumpla la altura mínima queda para cuando exista un sistema de pisos/historias más completo — la regla en sí ya está documentada en el GDD.

---

## **FASE 2: PLANEACIÓN**

### **2.1 Arquitectura del Proyecto**

```
PoC_3/
  project.godot
  assets/
    BlockLibrary.res  # MeshLibrary exportada desde BlockLibrarySource.tscn
  scenes/
    Main.tscn              # Escena jugable: VoxelWorld (GridMap) + Player + luz + mira
    Player.tscn             # CharacterBody3D reutilizable
    Test.tscn               # Escena de pruebas del validador (sin gameplay)
    BlockLibrarySource.tscn # Fuente de la MeshLibrary: 1 MeshInstance3D+CollisionShape3D por tipo
  scripts/
    VoxelWorld.gd     # GridMap: colocar/minar celdas vía set_cell_item
    Player.gd         # Movimiento, mouse-look, raycast de minado/colocación
    Main.gd           # Conecta Player con VoxelWorld
    BlueprintValidator.gd      # Puerto de PoC 2
    BlueprintValidatorTest.gd  # Puerto de las pruebas de PoC 2
```

**Decisión (actualizada): `GridMap` + `MeshLibrary` en vez de celdas por código.** La versión original de esta PoC generaba cada celda como un `MeshInstance3D`+`StaticBody3D` por código, porque un `GridMap` exige una `MeshLibrary` autorada en el editor y no era posible abrir Godot en ese momento. Con el editor disponible (MCP de Godot), se generó `BlockLibrarySource.tscn` — un `MeshInstance3D` con un `CollisionShape3D` como hijo directo por cada tipo de bloque (`pared`, `puerta`, `ventana`, `piso`) — y se exportó a `assets/BlockLibrary.res` con `export_mesh_library`. `VoxelWorld.gd` ahora extiende `GridMap` directamente: `colocar_bloque`/`minar_bloque` usan `set_cell_item`/`get_cell_item` sobre un índice tipo↔id construido en `_ready()`. Ganancia: rendimiento nativo del `GridMap` a gran escala (batching de mallas) y colisión gestionada por el motor, sin nodos ni metadatos manuales.

### **2.2 Movimiento y Cámara**

CharacterBody3D con:
* Movimiento horizontal relativo a la orientación del cuerpo (WASD), gravedad constante, sin salto (fuera de alcance — no es necesario para probar minado/colocación).
* Mouse-look: rotación en Y sobre el cuerpo, rotación en X solo sobre la cámara, con clamp para no voltear la cámara más allá de la vertical.
* `Input.mouse_mode = MOUSE_MODE_CAPTURED` al iniciar; `Escape` libera el mouse (necesario para poder interactuar con el editor/depurador durante pruebas).

### **2.3 Minado y Colocación**

Un único `RayCast3D`, hijo de la cámara, con `target_position` a 5 unidades al frente:

* **Minar (click izquierdo):** el `GridMap` expone una única forma física para todo el mapa (no un cuerpo por celda), así que la celda se deriva de `mundo.local_to_map(punto_impacto - normal * 0.5)` (el desplazamiento hacia adentro evita caer en la celda vecina vacía) y se llama `VoxelWorld.minar_bloque(celda)`.
* **Colocar (click derecho):** se toma esa misma celda impactada más la normal de colisión (redondeada a un vector entero) para obtener la celda vacía adyacente, y se llama `VoxelWorld.colocar_bloque(celda_destino, tipo_seleccionado)`.
* **Selección de tipo:** teclas `1`-`4` alternan entre `pared`, `puerta`, `ventana`, `piso`.

### **2.4 Puerto del Validador (Fase de Planeación ya cubierta en PoC 2)**

El modelo de datos y las siete reglas de validación ya se diseñaron en la Fase de Planeación de `PoC_2/` (ver esa Sección 2). Esta PoC no vuelve a diseñar las reglas — solo las traduce a GDScript preservando exactamente la misma semántica, aprovechando que `JSON.parse_string()` en Godot produce la misma jerarquía de `Dictionary`/`Array` que `json.loads()` en Python, por lo que **no hace falta ninguna clase de datos intermedia**: los Blueprints se manipulan como `Dictionary` directamente, igual que en Python.

### **2.5 Declarar Edificio: Detección Automática por Flood-Fill**

**Problema de diseño:** un edificio construido libremente puede tener habitaciones separadas por paredes con su propia puerta, cerradas entre sí. Un flood-fill que avance por *espacio transitable* (aire) no las uniría si las puertas están cerradas. La solución adoptada avanza por **bloques sólidos contiguos**, no por aire: dos paredes que se tocan físicamente quedan en la misma estructura sin importar si el espacio interior que encierran está aislado del resto. Esto es consistente con cómo ya funciona `BlueprintValidator`: no razona sobre "habitaciones", solo valida el conjunto plano de celdas de cada piso.

**Requisito de origen del bloque (no piso de tierra):** el edificio no puede incluir bloques generados por el mundo (el piso base creado en `_generar_piso_inicial()`), solo bloques colocados por el jugador. `VoxelWorld.gd` mantiene un `Dictionary` paralelo `colocado_por_jugador` (`Vector3i -> true`) que se marca únicamente cuando `Player._colocar()` coloca un bloque interactivamente; el piso del mundo nunca se marca. El flood-fill solo avanza sobre celdas presentes en este diccionario.

**Algoritmo (`VoxelWorld.detectar_estructura(origen)`):** BFS/DFS iterativo con 6-conectividad (`±x, ±y, ±z`) partiendo de `origen`, restringido a `colocado_por_jugador`. Si `origen` no fue colocado por el jugador, devuelve `{}` de inmediato.

**Conversión a Blueprint (`BlueprintValidator.estructura_a_blueprint()`):** agrupa las celdas detectadas por `y` (cada altura distinta es un `nivel`, normalizado para que el piso más bajo del jugador sea `nivel 0`, incluso si es negativo — un edificio con base bajo tierra se detecta igual) y normaliza `x`/`z` a coordenadas locales al edificio. `zona_permitida` se fija a un valor de relleno válido (`ponytail`, ver comentario en el código) porque la zonificación real es de Fase 2. El remapeo de los tipos físicos de puerta/cama (ver 2.6) a los tipos abstractos del Blueprint ocurre aquí mismo.

**Activación:** en `Player.gd`, la tecla `B` dispara `_declarar_edificio()`, que solo procede si el bloque apuntado por el raycast es una puerta (mitad inferior o superior) — la entrada principal, un punto reconocible de la construcción — no cualquier pared. Si la puerta no fue colocada por el jugador, o si no se apunta a una puerta, se imprime un mensaje explicativo en vez de intentar validar.

### **2.6 Objetos Multi-Celda: Puerta (Vertical) y Cama (Horizontal)**

**Motivación:** una puerta de 1 celda no tiene la altura de un avatar; una cama de 1 celda no se distingue de un simple bloque de piso. Ambas pasan a ocupar 2 celdas del `GridMap`, con verificación de espacio antes de colocarse.

**Ítems físicos:** la `MeshLibrary` (`BlockLibrarySource.tscn` → `assets/BlockLibrary.res`) tiene 4 ítems para estos dos objetos — `puerta_inferior`/`puerta_superior` y `cama_cabecera`/`cama_pies` — en vez de un ítem único, para que cada mitad pueda tener su propio placeholder visual desde ya (aunque hoy solo sea un color distinto).

**Colocación (`VoxelWorld.gd`):**
* `colocar_puerta(base)`: la celda apuntada por el jugador es siempre la mitad **inferior**; la superior (`base + (0,1,0)`) se agrega automáticamente. Si cualquiera de las dos celdas está ocupada, no coloca nada y devuelve `false`.
* `colocar_cama(base, direccion)`: `direccion` es uno de los 4 vectores cardinales, calculado en `Player._direccion_cardinal()` a partir del yaw del cuerpo del jugador (`-transform.basis.z`), ignorando el pitch de la cámara (que es un nodo hijo separado, sin influir en la rotación del cuerpo). Misma verificación de espacio que la puerta, sobre `base` y `base + direccion`.
* Ambas registran sus 2 celdas en `colocado_por_jugador` (para que "declarar edificio" las detecte) y en un nuevo `Dictionary pareja: Vector3i -> Vector3i` que vincula cada celda con su contraparte.

**Minado en cascada:** `minar_bloque(celda)` consulta `pareja` antes de borrar — si la celda pertenece a un objeto de 2 celdas, borra ambas mitades juntas. El mecanismo es genérico (no hay lógica especial por tipo de objeto), así que sirve igual para cualquier objeto multi-celda futuro.

**Impacto en la conversión a Blueprint — sin tocar las reglas de cerramiento/aberturas:** en `estructura_a_blueprint()`, `puerta_inferior` se remapea a `"puerta"` (el tipo que ya validan `validar_cerramiento`/`validar_aberturas`) y `puerta_superior` se **omite** por completo — es solo el volumen de altura de la puerta, y su inclusión rompería la suposición de que cada "piso" del Blueprint es una sola capa de `Y` (ver más abajo, regla de altura). `cama_cabecera`/`cama_pies` se agregan como celdas no sólidas (deben quedar en el interior de la planta, igual que "piso") y la cabecera además genera una entrada en la lista `camas` de su piso. `baul` pasa sin remapeo, como una celda no sólida más.

**Bloque `baul` y regla de almacenamiento (conteo total, no emparejado):** se agregó `baul` como octavo ítem de la `MeshLibrary` — un placeholder de 1 celda sin ninguna interacción (no se abre, no almacena nada). La regla original de PoC 2 ("cada cama con su baúl emparejado por posición") se reemplazó por una más flexible, a pedido explícito: `validar_camas_y_almacenamiento()` ahora cuenta el total de camas y el total de celdas `baul` en **todo el edificio** (todos los pisos) y exige `total_baules >= total_camas`, sin importar en qué habitación esté cada uno. Esto permite diseños como un barracón con varias camas juntas y una sola sección de casilleros en otro punto del edificio. La entrada de cada cama en la lista `camas` del Blueprint quedó reducida a `{"pos": ...}` (el campo `baul` por-cama ya no se usa).

**Regla de construcción documentada, no validada aún — altura mínima por piso:** el piso base de un edificio puede estar en valores de `Y` negativos (bajo tierra) sin ningún cambio de código, ya que la normalización usa el mínimo real del conjunto detectado. Se estableció además que cada piso/historia del edificio debe tener un mínimo de 3 celdas de interior libres más 1 celda de techo — así, tanto la puerta (2 celdas) como la cama (con 2 celdas libres exigidas encima, según el GDD) caben siempre dentro de un piso bien construido. **Esta PoC no valida esa altura mínima por código**: es una decisión consciente para no rediseñar el modelo de "piso = 1 capa de `Y`" del Blueprint antes de tener un sistema de pisos/historias completo (ver Próximos Pasos). La regla vive en el GDD (Sección 5) como requisito de diseño.

---

## **FASE 3: DESARROLLO**

### **3.1 Implementación**

Los cinco scripts viven en `PoC_3/scripts/`. A continuación, los fragmentos más relevantes de cada uno (el archivo completo está en la carpeta del proyecto):

**`VoxelWorld.gd`** — `GridMap` con índice tipo↔id sobre su propia `MeshLibrary`:

```gdscript
extends GridMap

var _id_por_tipo: Dictionary = {}  # String -> int
var _tipo_por_id: Dictionary = {}  # int -> String

func _ready() -> void:
    cell_size = Vector3.ONE
    for id in mesh_library.get_item_list():
        var nombre: String = mesh_library.get_item_name(id)
        _id_por_tipo[nombre] = id
        _tipo_por_id[id] = nombre

func colocar_bloque(celda: Vector3i, tipo: String) -> bool:
    if get_cell_item(celda) != GridMap.INVALID_CELL_ITEM or not _id_por_tipo.has(tipo):
        return false
    set_cell_item(celda, _id_por_tipo[tipo])
    return true

func minar_bloque(celda: Vector3i) -> bool:
    if get_cell_item(celda) == GridMap.INVALID_CELL_ITEM:
        return false
    set_cell_item(celda, GridMap.INVALID_CELL_ITEM)
    return true
```

**`Player.gd`** — minado/colocación por raycast (ver archivo completo para movimiento/mouse-look):

```gdscript
func _celda_impactada() -> Vector3i:
    var punto := raycast.get_collision_point()
    var normal := raycast.get_collision_normal()
    return mundo.local_to_map(mundo.to_local(punto - normal * 0.5))

func _minar() -> void:
    if not raycast.is_colliding() or mundo == null:
        return
    mundo.minar_bloque(_celda_impactada())

func _colocar() -> void:
    if not raycast.is_colliding() or mundo == null:
        return
    var celda := _celda_impactada()
    var normal := raycast.get_collision_normal()
    var celda_destino := celda + Vector3i(round(normal.x), round(normal.y), round(normal.z))
    mundo.colocar_bloque(celda_destino, tipos_disponibles[tipo_seleccionado])
```

**`BlueprintValidator.gd`** — puerto exacto de PoC 2 (ver archivo completo para las 7 funciones de validación):

```gdscript
static func validar_cerramiento(piso: Dictionary) -> Array:
    var errores: Array = []
    var celdas: Dictionary = piso["celdas"]
    var huella: Dictionary = {}
    for clave in celdas.keys():
        huella[_parsear_celda(clave)] = true

    for clave in celdas.keys():
        var pos: Vector2i = _parsear_celda(clave)
        var tipo: String = celdas[clave]
        var vecinos_ausentes: Array = []
        for delta in VECINOS_ORTOGONALES:
            if not huella.has(pos + delta):
                vecinos_ausentes.append(delta)
        if vecinos_ausentes.is_empty():
            continue
        if not TIPOS_CELDA_SOLIDA.has(tipo):
            errores.append("Piso %d: hueco en el perímetro en la celda (%d,%d), tipo '%s'"
                % [piso["nivel"], pos.x, pos.y, tipo])
            continue
        if vecinos_ausentes.size() == 2:
            var es_perpendicular: bool = vecinos_ausentes[0] != -vecinos_ausentes[1]
            if es_perpendicular and tipo != "pared":
                errores.append("Piso %d: la esquina (%d,%d) debe ser 'pared', no '%s'"
                    % [piso["nivel"], pos.x, pos.y, tipo])
    return errores
```

**`VoxelWorld.gd`** — flood-fill de "declarar edificio" (ver 2.5):

```gdscript
func detectar_estructura(origen: Vector3i) -> Dictionary:
    if not colocado_por_jugador.get(origen, false):
        return {}
    var visitados: Dictionary = {}
    var pendientes: Array = [origen]
    while not pendientes.is_empty():
        var actual: Vector3i = pendientes.pop_back()
        if visitados.has(actual) or not colocado_por_jugador.get(actual, false):
            continue
        visitados[actual] = obtener_tipo(actual)
        for delta in VECINOS_3D:
            var vecino: Vector3i = actual + delta
            if not visitados.has(vecino):
                pendientes.append(vecino)
    return visitados
```

**`BlueprintValidator.gd`** — conversión a Blueprint:

```gdscript
static func estructura_a_blueprint(celdas: Dictionary) -> Dictionary:
    if celdas.is_empty():
        return {}
    # ... calcula x_min/y_min/z_min, agrupa por (y - y_min) = nivel ...
    for pos in celdas.keys():
        var nivel: int = pos.y - y_min
        celdas_por_nivel[nivel]["%d,%d" % [pos.x - x_min, pos.z - z_min]] = celdas[pos]
    # ... arma {"pisos": [{"nivel": n, "celdas": {...}, "camas": []}, ...], "zona_permitida": "residencial_investigacion"} ...
```

### **3.2 Pruebas**

`BlueprintValidatorTest.gd` reproduce los 6 primeros tests de PoC 2, adaptados a la nueva regla de almacenamiento por conteo total (Tests 1 y 5, ver 2.6) — los tests de evolución/personalización de producción de PoC 2 no se portaron en esta PoC, quedan como trabajo pendiente listado abajo — más 3 pruebas propias de PoC 3: el escenario de dos habitaciones con puerta interior cerrada, una cama y un baúl en habitaciones distintas (Test 7, confirma que el flood-fill las une igual, que la cama se detecta y convierte correctamente — 23 celdas físicas, 21 celdas de Blueprint tras omitir las mitades superiores de puerta — y demuestra el flujo completo pasando la validación de punta a punta, `Válido: true`), el rechazo del piso de tierra como estructura (Test 8), y el rechazo de puerta/cama por falta de espacio de 2 celdas (Test 9). Cada test usa `assert()`, igual que en Python.

**Cómo ejecutarlos (una vez instalado Godot):**
1. Abrir `PoC_3/project.godot` en Godot 4.3+.
2. Abrir `scenes/Test.tscn` y presionar **F6** ("Run Current Scene").
3. Revisar el panel **Output**: deben imprimirse los 6 tests y el mensaje final "pasaron correctamente", sin que la ejecución se detenga por un `assert()` fallido.

**Cómo probar el prototipo jugable:**
1. Presionar **F5** (o abrir `scenes/Main.tscn` y F6) para correr `Main.tscn`.
2. Moverse con WASD, mirar con el mouse.
3. Click izquierdo sobre un bloque del piso para minarlo; click derecho para colocar un bloque nuevo (teclas 1-4 cambian el tipo).
4. `Escape` libera el cursor del mouse.

### **3.3 Bugs Encontrados y Corregidos al Verificar**

Ejecutar el proyecto en Godot 4.7 real (headless) reveló dos problemas que la sola lectura del código no mostró:

1. **Resolución de clase global antes del primer escaneo del proyecto:** `class_name BlueprintValidator` no era reconocido como identificador global al correr `Test.tscn` porque Godot no había escaneado el proyecto todavía (esto se resuelve solo la primera vez que se abre en el editor). **Corrección:** `BlueprintValidatorTest.gd` ahora usa `const BlueprintValidator = preload("res://scripts/BlueprintValidator.gd")`, que no depende de ese caché.
2. **Inferencia de tipo fallida en `Player.gd`:** `if event is InputEventKey and event.pressed: var indice := event.keycode - KEY_1` fallaba en tiempo de análisis porque el compilador no reduce el tipo de `event` a `InputEventKey` dentro de una condición compuesta con `and`. Lo mismo afectaba a `Main.gd`, que no reconocía las propiedades de `Player.gd` en `$Player`. **Corrección (temporal):** casts explícitos (`event as InputEventKey`, `event as InputEventMouseButton`, `event as InputEventMouseMotion`) en `Player.gd`, y `const Player = preload("res://scripts/Player.gd")` en `Main.gd` como workaround mientras el editor no había escaneado el proyecto.
3. **Identificador global shadowed (`SHADOWED_GLOBAL_IDENTIFIER`):** al abrir el proyecto en el editor real (con el MCP de Godot conectado), Godot escaneó el proyecto y registró `class_name Player`/`class_name BlueprintValidator` como identificadores globales — momento en el que los `const Player = preload(...)` y `const BlueprintValidator = preload(...)` del punto 1 y 2 (agregados como workaround) pasaron a *duplicar* esos nombres globales, generando el warning. **Corrección:** se eliminaron esos `const`, dejando que `Main.gd` y `BlueprintValidatorTest.gd` usen directamente los `class_name` globales, ya resueltos correctamente por el editor.

4. **`class_name` nuevo, no reconocido por el mismo motivo que el bug 1:** al implementar "declarar edificio" se intentó darle `class_name VoxelWorld` a `VoxelWorld.gd` para tipar `mundo: VoxelWorld` en `Player.gd` y en el test. Como el proyecto no había vuelto a escanearse tras ese cambio (esta vez corriendo vía el MCP de Godot, no el editor real), Godot no reconoció el identificador global — mismo problema que el bug 1, pero reaparece cada vez que se agrega una clase global nueva y se verifica antes de un escaneo. **Corrección:** en vez de depender del caché, se evitó la anotación de tipo nominal: `mundo` quedó tipado como `Node` (duck-typing, igual que antes de este cambio) y las llamadas a métodos de `VoxelWorld` que antes usaban inferencia (`:=`) pasaron a declarar el tipo de retorno explícitamente (`var celdas: Dictionary = mundo.detectar_estructura(...)`), lo cual no requiere resolver ningún nombre de clase global.
5. **Inferencia de tipo fallida en una expresión aritmética con elemento de `Array` sin tipar:** `const VECINOS_3D := [Vector3i(1,0,0), ...]` crea un `Array` genérico (no `Array[Vector3i]`), así que al iterar `for delta in VECINOS_3D`, `delta` es `Variant` y `var vecino := actual + delta` no puede inferir el tipo resultante. **Corrección:** declarar `const VECINOS_3D: Array[Vector3i] = [...]` (array tipado) y anotar `var vecino: Vector3i = actual + delta` explícitamente.

6. **Inferencia de tipo fallida al indexar un `Array` sin tipar declarado con `:=`:** al implementar la selección de tipo para colocar objetos multi-celda, `var tipo := tipos_disponibles[tipo_seleccionado]` (en `Player._colocar()`) falló en tiempo de análisis — mismo patrón que el bug 5, pero esta vez indexando en vez de iterando. **Corrección:** `var tipo: String = tipos_disponibles[tipo_seleccionado]` (tipo explícito en vez de inferencia).

Los seis son errores de **carga/parseo o resolución de nombres** (se detectan sin necesidad de simular input). Los bugs 1 y 4 son el mismo fenómeno (dependencia del caché de clases globales) apareciendo en dos momentos distintos; los bugs 5 y 6 son el mismo fenómeno (inferencia de tipo con `:=` sobre un `Array` sin tipar) en dos formas de uso distintas (iterar vs. indexar) — evidencia de que conviene, en este proyecto, declarar explícitamente el tipo de cualquier variable cuyo valor de origen no sea 100% estático (llamada dinámica, `Array` genérico), en vez de depender de `:=`.

### **3.4 Criterios de Aceptación Técnicos**

1. **Minado Preciso:** solo la celda exacta bajo el retículo (centro de pantalla) debe removerse al hacer click izquierdo, nunca una celda vecina.
2. **Colocación Adyacente Correcta:** un bloque colocado con click derecho debe aparecer siempre en la celda vacía inmediatamente adyacente a la cara impactada por el rayo, nunca superpuesto a un bloque existente.
3. **Paridad de Validación:** `BlueprintValidator.gd` debe producir el mismo veredicto (`valido`/errores) que `validar_blueprint()` de PoC 2 para los mismos 6 casos de prueba portados.
4. **Desacoplamiento:** `Player.gd` y `BlueprintValidator.gd` no deben depender el uno del otro ni de `VoxelWorld.gd` más allá de la referencia mínima necesaria (`mundo.colocar_bloque`/`minar_bloque`) — deben poder probarse por separado.
5. **Detección Correcta de Estructuras Cerradas:** el flood-fill de "declarar edificio" debe incluir habitaciones separadas por puertas propias (cerradas) siempre que sus bloques toquen físicamente el resto de la estructura, y debe rechazar (devolver vacío) cualquier intento de declarar un bloque generado por el mundo (piso de tierra) en vez de colocado por el jugador.
6. **Objetos Multi-Celda Atómicos:** `colocar_puerta`/`colocar_cama` no deben colocar ninguna de sus 2 celdas si falta espacio en cualquiera de las dos (todo o nada); `minar_bloque` sobre cualquiera de las 2 celdas de un objeto debe borrar ambas, nunca dejar una mitad huérfana.

---

## **Próximos Pasos de esta PoC**

> 1. ~~Instalar Godot y verificar manualmente.~~ **Completado:** Godot 4.7 (Steam) instalado; `Test.tscn` y `Main.tscn` corren sin errores en modo headless; 2 bugs de carga encontrados y corregidos (ver 3.3).
> 2. ~~Jugar `Main.tscn` interactivamente.~~ **Completado:** verificado con el MCP de Godot conectado y el depurador — minar/colocar bloques funciona; se agregó una mira (crosshair) mínima (`ColorRect` centrado en un `CanvasLayer`) y se corrigió un warning `SHADOWED_GLOBAL_IDENTIFIER` (los `const ... = preload(...)` usados como workaround en 3.3 ya no son necesarios una vez que el editor real escanea el proyecto y resuelve los `class_name` globales sin conflicto).
> 3. **Mira contextual (feedback visual):** hoy la mira es un punto blanco fijo. Diseño futuro: cambia de forma/color según distancia, herramienta seleccionada y tipo de objetivo — ej. punto pequeño sin objetivo válido a distancia; se expande a un recuadro al apuntar a un bloque recolectable cercano; amarillo si la herramienta activa no es la ideal para el recurso (pico apuntando a un árbol); X si el bloque pertenece a un edificio (no recolectable directamente); círculo con arma cuerpo a cuerpo seleccionada; crosshair de mira telescópica con arma a distancia. Son ejemplos iniciales — la mecánica completa (qué estados existen, cómo se determinan) queda por diseñar en una fase posterior, probablemente ligada a la introducción del inventario/herramientas.
> 4. ~~Migrar de celdas por código a `GridMap` + `MeshLibrary`.~~ **Completado:** `scenes/BlockLibrarySource.tscn` (1 `MeshInstance3D`+`CollisionShape3D` por tipo) exportada a `assets/BlockLibrary.res` con el MCP de Godot; `VoxelWorld.gd` ahora extiende `GridMap`; `Player.gd` deriva la celda impactada con `local_to_map()` en vez de leer metadatos de un `StaticBody3D` por celda. Verificado sin errores corriendo `Main.tscn` (ver 2.1).
> 5. ~~Decidir e implementar el mecanismo de "declarar un edificio".~~ **Completado:** flood-fill 3D sobre bloques del jugador (`VoxelWorld.detectar_estructura()`), activado con `B` apuntando a una puerta; conversión a Blueprint (`BlueprintValidator.estructura_a_blueprint()`) y validación con el mismo `validar_blueprint()` — ver 2.5. **Pendiente:** decidir el flujo de "construir" desde la vista cenital (fuera de esta PoC, requiere PoC 5).
> 6. ~~Objetos multi-celda: puerta (2 celdas verticales) y cama (2 celdas horizontales orientadas a la mirada).~~ **Completado:** `VoxelWorld.colocar_puerta()`/`colocar_cama()` con verificación de espacio y minado en cascada (`pareja: Vector3i -> Vector3i`); 4 ítems nuevos en la `MeshLibrary` (`puerta_inferior`/`puerta_superior`, `cama_cabecera`/`cama_pies`); remapeo transparente en `estructura_a_blueprint()` — ver 2.6. Verificado con Test 7 (cama detectada y convertida correctamente) y Test 9 (rechazo por falta de espacio).
> 7. ~~Agregar un bloque `baul` básico y cerrar la regla de almacenamiento.~~ **Completado:** ítem placeholder de 1 celda en la `MeshLibrary`, sin interacción (no se abre, no almacena nada). La regla se rediseñó de "cada cama con su baúl emparejado por posición" a "mínimo 1 baúl por cada cama, contado en todo el edificio" — decisión explícita para dar libertad de diseño (ej. barracones con una sección de casilleros compartida). Verificado con Test 7 (edificio con cama y baúl en habitaciones distintas, válido de punta a punta) y Test 5 (sin baúl, inválido). **Pendiente:** cualquier interacción real del baúl (abrir, almacenar objetos) — fuera de alcance de esta PoC.
> 8. **Portar los tests de evolución y personalización de producción de PoC 2** a `BlueprintValidatorTest.gd`.
> 9. **Reemplazar los materiales de color plano por las texturas PBR de Poly Haven** (decisión ya tomada en el GDD, Sección 11) sobre los ítems de `BlockLibrarySource.tscn`, una vez el prototipo de mecánica esté validado.

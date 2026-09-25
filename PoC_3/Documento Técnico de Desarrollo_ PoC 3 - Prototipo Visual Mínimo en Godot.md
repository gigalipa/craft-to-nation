# **Documento Técnico de Desarrollo: PoC 3 - Prototipo Visual Mínimo en Godot**

**Identificador del Módulo:** POC-03-VISUAL-PROTOTYPE

**Motor:** Godot Engine 4.3+ (GDScript, sin plugins ni assets de terceros en esta PoC)

**Dependencias de Diseño:** Sección 5 del GDD v3.6 (Mecánica de Plantillas), Sección 11 (Fase 1: Prototipo Visual Mínimo).

**Dependencia Técnica:** Puerto directo de la lógica de validación de `PoC_2/` a GDScript. No depende de `PoC_1/` (esa integración se planea para la Fase 2 del roadmap).

**✅ Verificado con Godot 4.7 (Steam), incluyendo GridMap, detección de edificios y objetos multi-celda:** `scenes/Test.tscn` corre (vía MCP de Godot) y los 14 tests de `BlueprintValidatorTest.gd` pasan sin errores de `assert()`. `scenes/Main.tscn` se jugó interactivamente (mouse/teclado, vía MCP de Godot + depurador): minar y colocar bloques funciona correctamente sobre `GridMap` + `MeshLibrary` (ver 2.1). Se agregó una mira mínima, el mecanismo de "declarar edificio" (flood-fill 3D, tecla `B` apuntando a una puerta — ver 2.5), objetos multi-celda (puerta de 2 celdas verticales, cama de 2 celdas horizontales orientadas a la mirada del jugador, ambos con verificación de espacio y minado en cascada — ver 2.6), el bloque `baul` (placeholder) y salto (`Espacio`) para pruebas de construcción. **Cuatro correcciones/ampliaciones tras pruebas de construcción real (ver 2.7):** `estructura_a_blueprint()` fusiona las capas de Y de cada historia en un solo "piso"; se agregó verificación explícita de techo/suelo sólido; se formalizó la definición de "piso" para edificios de varias historias — losa base y techo exterior 100% sólidos, losas intermedias entre historias apiladas pueden tener un hueco de escalera (>50% de su interior debe seguir siendo estructural), y altura mínima de 3 celdas por piso, ahora validada en código; y se corrigió la fusión de capas de pared sobre la plantilla de suelo/techo para que reconozca el bloque `"piso"` real (no solo `"pared"`, el tipo que usaban por error los datos de prueba anteriores) como relleno genérico sobrescribible — sin este fix, cualquier casa construida con el bloque `"piso"` real del juego (el único que un jugador de verdad usa) fallaba con "hueco en el perímetro" en casi todo el borde. Pendiente: mira contextual, interacción real del baúl, capacidad de población y límite de camas por piso (aprovechando esta definición), tests de evolución/personalización portados de PoC 2, y texturas PBR — ver Próximos Pasos.

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

> **Nota (post-PoC 3):** el proyecto de Godot descrito abajo vivía originalmente en `PoC_3/`. Al planear la Fase 2 (PoC 4, integración de Ciudad/Avatar) se movió a una carpeta compartida `godot/` en la raíz del repositorio, ya que varias PoCs futuras (4, 5, 6) siguen construyendo sobre el mismo mundo/avatar — no tiene sentido que cada una tenga su propia copia del proyecto Godot. `PoC_3/` conserva solo este documento técnico; el árbol de abajo describe la estructura interna, ahora bajo `godot/` en vez de `PoC_3/`. La mudanza reprodujo el bug 1/4 ya conocido (caché de `class_name` global vacío hasta que el editor real escanea el proyecto en su nueva ubicación): se agregaron temporalmente `const X = preload(...)` en `Player.gd`, `Main.gd` y `BlueprintValidatorTest.gd` para verificar por MCP; es de esperar que, al abrir `godot/` por primera vez en el editor real, aparezca de nuevo el warning `SHADOWED_GLOBAL_IDENTIFIER` — en ese momento se pueden volver a quitar, como ya pasó una vez en PoC 3.

```
godot/
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
* Movimiento horizontal relativo a la orientación del cuerpo (WASD), gravedad constante, y salto (`Espacio`, solo si `is_on_floor()`) — agregado para facilitar pruebas de construcción en vivo (moverse por encima de bloques colocados).
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

**Algoritmo (`VoxelWorld.detectar_estructura(origen)`):** BFS/DFS iterativo con 6-conectividad (`±x, ±y, ±z`) partiendo de `origen`, restringido a celdas `colocado_por_jugador` **y** de un tipo en `TIPOS_ESTRUCTURA` (ver 2.8 — `piso` queda fuera). Si `origen` no cumple ambas condiciones, devuelve `{}` de inmediato.

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

**Impacto en la conversión a Blueprint — sin tocar las reglas de cerramiento/aberturas:** en `estructura_a_blueprint()`, `puerta_inferior` se remapea a `"puerta"` (el tipo que ya validan `validar_cerramiento`/`validar_aberturas`) y `puerta_superior` se **omite** por completo — es solo el volumen de altura de la puerta. `cama_cabecera`/`cama_pies` se agregan como celdas no sólidas (deben quedar en el interior de la planta, igual que "piso") y la cabecera además genera una entrada en la lista `camas` de su piso. `baul` pasa sin remapeo, como una celda no sólida más. (Ver 2.7 para cómo se agrupan estas celdas en "pisos" cuando el edificio tiene varias capas de `Y` por historia — el modelo original de "1 piso = 1 capa de `Y`" se reemplazó tras encontrar un bug real, ver abajo.)

**Bloque `baul` y regla de almacenamiento (conteo total, no emparejado):** se agregó `baul` como octavo ítem de la `MeshLibrary` — un placeholder de 1 celda sin ninguna interacción (no se abre, no almacena nada). La regla original de PoC 2 ("cada cama con su baúl emparejado por posición") se reemplazó por una más flexible, a pedido explícito: `validar_camas_y_almacenamiento()` ahora cuenta el total de camas y el total de celdas `baul` en **todo el edificio** (todos los pisos) y exige `total_baules >= total_camas`, sin importar en qué habitación esté cada uno. Esto permite diseños como un barracón con varias camas juntas y una sola sección de casilleros en otro punto del edificio. La entrada de cada cama en la lista `camas` del Blueprint quedó reducida a `{"pos": ...}` (el campo `baul` por-cama ya no se usa).

### **2.7 Corrección: Agrupación de Pisos por Historia, No por Capa de Y**

**Bug real encontrado en pruebas de construcción en vivo:** el diseño original de `estructura_a_blueprint()` trataba cada capa de `Y` detectada como su propio "piso" del Blueprint (ver commit anterior de esta sección). Una casa real de varios bloques de alto — suelo sólido, 3 capas de pared con aire interior sin bloques (donde camina el jugador), techo sólido — rompía esto de dos formas: (1) el suelo y el techo (100% sólidos) fallaban `validar_aberturas` por no tener puerta ni ventana, algo que nunca deberían necesitar; (2) cualquier mobiliario (cama, baúl) con una celda de aire interior vecina — sin ningún bloque colocado ahí, simplemente el espacio donde camina el jugador — se marcaba como `"hueco en el perímetro"`, un falso positivo, porque el algoritmo de cerramiento no distingue "aire interior legítimo" de "hueco real en el muro" cuando esa celda vecina no está registrada en absoluto.

**Corrección:** `estructura_a_blueprint()` ahora:
1. Detecta **losas sólidas** (`_es_losa_solida()`): una capa de `Y` donde el 100% de las celdas de la huella x/z del edificio están presentes y son de tipo sólido (`pared`/`puerta`/`ventana`). El suelo y el techo de una casa bien construida son losas.
2. Las losas **no generan su propio "piso"** — se descartan de la validación (no necesitan puerta/ventana, y su solidez ya está garantizada por definición).
3. Las capas no-losa consecutivas de una misma historia se **fusionan en un solo "piso"**, usando la losa adyacente (abajo o, si no hay, arriba) como **plantilla base ya sin huecos** — cada celda de esa plantilla es sólida por construcción, así que el mobiliario que se superpone sobre ella nunca queda con un vecino "ausente": el resto de la plantilla simplemente conserva el tipo sólido de la losa. Una celda especial (puerta/ventana/mobiliario) de una capa nunca es sobreescrita por un "pared" de otra capa de la misma historia (`ponytail`: si dos capas tuvieran tipos especiales *distintos* en la misma celda, gana el de la capa más alta — caso raro que no debería darse en una construcción real).
4. Si una historia no tiene ninguna losa adyacente (casos mínimos de una sola capa, como en los Tests 1-9), se usa la unión simple de sus capas — mismo comportamiento que antes del fix, sin regresión.

**Efecto colateral positivo:** esto también resuelve, de facto, la regla de "altura mínima por piso" del GDD (Sección 5) sin necesidad de forzarla explícitamente: cualquier casa con un suelo y techo sólidos (sin importar cuántas capas de pared tenga en medio) ahora se valida como una sola historia correctamente.

Verificado con el nuevo **Test 10**: una casa de 4×5 de huella y 5 de alto (igual proporción a la reportada), con puerta, ventana, cama y baúl — se detecta como un único piso y se valida sin errores.

**Segundo bug real, encontrado en la siguiente prueba de construcción (2do piso con techo abierto a propósito):** el fix anterior evita huecos falsos, pero como efecto secundario no deseado, **eliminó por completo la verificación de que exista un techo real**. `validar_cerramiento` solo revisa el perímetro en planta (X/Z) de un piso — nunca comprobó, ni antes ni después del primer fix, que la construcción esté cerrada verticalmente (el GDD lo describe en prosa — "tejado que cubre la totalidad de la huella" — pero nunca estuvo implementado como regla de código, ni siquiera en PoC 1/2, porque el formato abstracto nunca modeló un techo en 3D). Con la fusión de capas, una historia sin techo real simplemente terminaba sin ninguna losa por encima, y nada lo penalizaba.

**Corrección:** `estructura_a_blueprint()` ahora marca cada "piso" con `suelo_completo`/`techo_completo` (`true` si la capa inmediatamente debajo/encima de la historia es una losa sólida). Nueva función `validar_techo_y_suelo(piso)` revisa estas banderas (con `.get(..., true)` para no afectar Blueprints hechos a mano al estilo PoC 2, que nunca las traen) y agrega `"Piso N: falta un suelo sólido debajo"` / `"...falta un techo sólido encima"` cuando falten. Se llama junto a `validar_cerramiento`/`validar_aberturas` en `validar_blueprint()`.

**Ajuste relacionado — `puerta_superior` ya no se omite, se remapea a `"pared"`:** omitirla por completo (diseño original) podía dejar una capa de Y sin ninguna celda registrada si esa capa coincidía por mala suerte con lo que debería ser un techo — `_es_losa_solida()` la rechazaría por esa única celda "fantasma" faltante, aunque el techo estuviera físicamente completo. Remapear a `"pared"` evita el hueco fantasma sin riesgo de confundirse con una puerta real, porque `validar_aberturas` exige el tipo exacto `"puerta"` (que solo aporta la mitad inferior), y la regla de fusión nunca deja que un `"pared"` de una capa sobrescriba un tipo especial ya asignado por otra.

Verificado con el nuevo **Test 11**: la misma casa de Test 10 pero sin colocar el techo — ahora se rechaza con `"Piso 0: falta un techo sólido encima"`.

**Tercera ampliación: definición formal de "piso" para edificios de varias historias.** Motivación de diseño (no un bug): los sistemas futuros (capacidad de población por piso según el nivel de la ciudad, límite de camas por piso para evitar "barracones" de un solo piso con camas infinitas) necesitan saber exactamente dónde empieza y termina cada piso de un edificio real. El modelo hasta este punto (2.7, arriba) solo distinguía "losa 100% sólida" de "capa de pared" — insuficiente para un edificio de 2+ pisos, cuya losa intermedia (el suelo del piso de arriba) necesita un hueco de escalera para conectar ambos pisos sin dejar de ser, funcionalmente, un suelo.

**Regla acordada:** el piso 0 empieza en la losa base y sube un mínimo de 3 celdas; se cierra con la losa de techo exterior (edificio de 1 piso) o con una losa de suelo intermedia (edificio de 2+ pisos), y así sucesivamente. El jugador puede hacer un piso más alto de 3 celdas libremente, nunca más bajo. La losa base y la de techo exterior deben ser 100% sólidas (sin huecos); las losas intermedias entre dos pisos apilados pueden tener un hueco, siempre que la mayoría de su superficie interior siga siendo estructural.

**Implementación:**
* `TIPOS_ESTRUCTURALES` (`pared`, `puerta`, `ventana` — ver 2.8, ya no incluye `piso`) — coincide ahora con `TIPOS_CELDA_SOLIDA` (la regla del perímetro 2D) — separa "material de construcción" de mobiliario (`cama_cabecera`/`cama_pies`/`baul`), que nunca cuenta hacia una losa.
* `_es_losa_completa(capa, x_max, z_max)`: 100% de la huella es estructural — la regla original, ahora reservada para el cimiento y el techo exterior.
* `_es_losa_parcial(capa, x_max, z_max)`: más de la mitad de las celdas **interiores** (excluyendo el anillo perimetral, presente tanto en una losa como en una capa de pared normal) son estructurales. Distingue una losa con hueco de escalera (mayormente sólida) de una capa de pared normal (interior mayormente vacío, con mobiliario disperso).
* `estructura_a_blueprint()` agrupa las capas en bandas usando `_es_losa_parcial()` (no `_es_losa_completa()`) para decidir los límites entre pisos — así una losa intermedia con hueco sigue reconociéndose como límite. Solo la primera banda (piso más bajo) y la última (piso más alto) exigen que su losa adyacente correspondiente (`_es_losa_completa()`) sea 100% sólida; las losas entre bandas intermedias solo necesitan ser parciales.
* Cada piso guarda `altura_capas` (número de capas de Y de esa banda); `validar_altura_piso()` rechaza cualquier piso con menos de `ALTURA_MINIMA_PISO = 3`.

Verificado con **Test 12** (edificio de 2 pisos, losa intermedia con un hueco de escalera de 1 celda en el centro — detecta correctamente 2 pisos, ambos válidos) y **Test 13** (piso de solo 2 celdas de altura — rechazado con `"altura insuficiente"`).

### **2.8 Corrección de Diseño: `piso` Deja de Ser Material Estructural**

**Bug real, reportado jugando en vivo:** si el jugador coloca un bloque de `piso` para rellenar un hueco de terreno justo debajo de la losa de suelo de su edificio (hecha de `pared`), el flood-fill de `detectar_estructura()` lo reconocía igualmente como parte del edificio — `piso` estaba en `colocado_por_jugador` (se coloca con `colocar_bloque(..., true)` como cualquier otro tipo) y el algoritmo no distinguía tipos.

**Decisión de diseño confirmada (revierte la premisa del Test 14 original, ver 2.7):** `piso` deja de ser un material estructural en absoluto, ni siquiera para una losa de suelo/techo intencional. Es exclusivamente material de **terreno/relleno** (el bloque de superficie que genera `_generar_terreno()`, y el que usa el modo de nivelación de terreno — ver GDD Sección 5), nunca un material de construcción. Para esta PoC, el único material estructural válido es `pared`; el GDD documenta que el juego final aceptará madera, piedra, metal y vidrio como materiales estructurales (más adelante, otros materiales o "texturas" cosméticas como ladrillo, piedra cincelada o metal pulido, sin afectar la regla estructural).

**Implementación:**
* Nueva constante `VoxelWorld.TIPOS_ESTRUCTURA` (`pared`, `puerta_inferior`, `puerta_superior`, `ventana`, `cama_cabecera`, `cama_pies`, `baul` — es decir, todos los tipos físicos que `Player.gd` puede colocar marcados como `colocado_por_jugador`, excepto `piso`). `detectar_estructura()` ahora exige `colocado_por_jugador.get(celda) and TIPOS_ESTRUCTURA.has(tipo)` tanto para el origen como en cada paso del flood-fill (función auxiliar `_es_celda_estructural()`) — un bloque de `piso` ni se incluye en la estructura detectada ni propaga la búsqueda a través de él.
* `BlueprintValidator.TIPOS_ESTRUCTURALES` pierde `piso`, quedando idéntica a `TIPOS_CELDA_SOLIDA` (`pared`, `puerta`, `ventana`). `TIPOS_RELLENO_GENERICO` (ver 2.7 anterior — fix de fusión de capas) queda reducida a `["pared"]`: ya no puede llegar una losa con `piso` como relleno heredado, porque `piso` nunca sobrevive al flood-fill hasta `estructura_a_blueprint()`.

Verificado reescribiendo **Test 14**: la misma casa de suelo/techo/muros en `pared` de los Tests anteriores, más un bloque de `piso` colocado por el jugador tocando físicamente la losa de suelo desde abajo — `detectar_estructura()` no lo incluye en el resultado, y usar ese bloque como origen devuelve `{}` (no es estructural aunque esté `colocado_por_jugador`). El Blueprint resultante de la casa real sigue siendo válido sin cambios. **Test 7** también se ajustó: una celda que usaba `piso` como relleno interior sin motivo (no probaba nada específico de `piso`) pasó a `pared`, preservando los conteos originales (81 celdas físicas, 21 celdas de Blueprint).

**Alcance:** esta PoC define y valida la estructura de "piso", pero no implementa todavía la capacidad de población ni el límite de camas por piso que la motivaron — eso depende de la integración con `Ciudad`/`Avatar` de PoC 1, planeada para la Fase 2 del roadmap (ver GDD Sección 11).

**Cuarto bug real, encontrado jugando en vivo después de completar PoC 4 (zonificación):** el usuario construyó una casa real de 5×6 usando el bloque `"piso"` real del juego (el que `Player.gd` ofrece de verdad, tecla `4`) tanto para el suelo como para el techo — no `"pared"`, que era lo que usaban TODOS los datos de prueba anteriores (Tests 10-13) para simular suelo/techo, por conveniencia al escribirlos. Con una casa así, `declarar edificio` la rechazaba con `"hueco en el perímetro"` en casi todo el borde (16 de 18 celdas perimetrales), además de `"falta puerta"`, `"falta ventana"`, `"falta suelo sólido debajo"` y `"altura insuficiente"` — un fallo mucho más amplio que cualquiera de los tres bugs anteriores.

**Root cause:** la regla de fusión de capas de una historia (2.7, punto 3 de la implementación) solo permitía que un bloque de pared normal (`"pared"`) sobrescribiera la plantilla heredada del suelo/techo cuando esa plantilla YA valía literalmente `"pared"`:
```gdscript
if not plantilla.has(clave) or plantilla[clave] == "pared" or tipo_capa != "pared":
    plantilla[clave] = tipo_capa
```
Como la plantilla en realidad hereda el tipo del bloque de losa (`"piso"`, no `"pared"`, cuando el jugador usa el bloque correcto para su suelo/techo), esta condición nunca se cumplía para un bloque de pared normal: `plantilla[clave] == "pared"` era falso (valía `"piso"`) y `tipo_capa != "pared"` también era falso (el bloque de pared SÍ es `"pared"`). El resultado: casi todo el perímetro quedaba congelado en `"piso"` — el tipo de la plantilla, nunca reemplazado por el muro real que el jugador construyó ahí — disparando `"hueco en el perímetro"` en cascada. Solo las celdas con un tipo ESPECIAL (puerta, ventana, cama, baúl) escapaban del bug, porque `tipo_capa != "pared"` sí era verdadero para ellas — lo cual explica por qué los Tests 10-13 (con floor/techo de `"pared"`) nunca lo detectaron: su plantilla ya empezaba en `"pared"`, así que la condición rota daba el resultado correcto por accidente.

**Corrección:** nueva constante `TIPOS_RELLENO_GENERICO := ["pared", "piso"]` — cualquier celda de la plantilla con uno de estos dos tipos (relleno sin significado especial a nivel de Blueprint) puede ser sobrescrita por el bloque real de una capa de pared, sea cual sea su tipo:
```gdscript
if not plantilla.has(clave) or TIPOS_RELLENO_GENERICO.has(plantilla[clave]) or tipo_capa != "pared":
    plantilla[clave] = tipo_capa
```
Un tipo ESPECIAL ya asignado (puerta/ventana/cama/baúl) sigue protegido de ser pisado por un `"pared"` posterior, igual que antes.

Verificado con **Test 14**: la misma casa 5×6 del reporte, con suelo y techo construidos con el bloque `"piso"` real (no `"pared"`) — ahora se detecta como un único piso, con `altura_capas = 3`, `suelo_completo`/`techo_completo` en `true`, y se valida sin errores.

---

## **FASE 3: DESARROLLO**

### **3.1 Implementación**

Los cinco scripts viven en `godot/scripts/`. A continuación, los fragmentos más relevantes de cada uno (el archivo completo está en la carpeta del proyecto):

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

`BlueprintValidatorTest.gd` reproduce los 6 primeros tests de PoC 2, adaptados a la nueva regla de almacenamiento por conteo total (Tests 1 y 5, ver 2.6) — los tests de evolución/personalización de producción de PoC 2 no se portaron en esta PoC, quedan como trabajo pendiente listado abajo — más 4 pruebas propias de PoC 3: el escenario de dos habitaciones con puerta interior cerrada, una cama y un baúl en habitaciones distintas (Test 7, confirma que el flood-fill las une igual, que la cama se detecta y convierte correctamente — 23 celdas físicas, 21 celdas de Blueprint tras omitir las mitades superiores de puerta — y demuestra el flujo completo pasando la validación de punta a punta, `Válido: true`), el rechazo del piso de tierra como estructura (Test 8), el rechazo de puerta/cama por falta de espacio de 2 celdas (Test 9), y una casa real multi-nivel de 4×5×5 con suelo/techo sólidos, puerta, ventana, cama y baúl (Test 10, ver 2.7 — el caso que reveló el bug de agrupación por capa de Y). Cada test usa `assert()`, igual que en Python.

**Cómo ejecutarlos (una vez instalado Godot):**
1. Abrir `godot/project.godot` en Godot 4.3+.
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

7. **Bug de diseño (no de sintaxis), encontrado solo con una prueba de construcción real:** `estructura_a_blueprint()` trataba cada capa de `Y` detectada como su propio "piso", lo que rompía con cualquier casa real de más de 1 bloque de alto — ver el análisis completo y la corrección en la Sección 2.7. A diferencia de los bugs 1-6 (detectables por carga/parseo, sin simular input), este solo se manifestó jugando la escena e intentando declarar una construcción real con `B`, reforzando que la verificación headless/de carga y la verificación funcional real son necesidades distintas y complementarias.
8. **Bug de diseño, encontrado en la prueba de construcción inmediatamente siguiente (un 2do piso con techo abierto a propósito):** el fix del bug 7 nunca verificaba que existiera un techo físico — solo evitaba huecos falsos en el mobiliario. `validar_cerramiento` únicamente revisa el perímetro en planta (X/Z); la comprobación de un techo real nunca estuvo implementada en código (ni en PoC 1/2, donde el GDD la describía en prosa sin que hubiera una regla correspondiente). Corregido con `validar_techo_y_suelo()` — ver 2.7.
9. **Bug de diseño, encontrado jugando en vivo tras completar PoC 4 (zonificación):** la regla de fusión de capas (2.7) solo dejaba que un `"pared"` real sobrescribiera la plantilla de suelo/techo cuando esa plantilla ya valía literalmente `"pared"` — pero la plantilla en realidad hereda el tipo del bloque de losa que el jugador usó, que en el juego real es `"piso"` (tecla `4`), no `"pared"`. Todos los datos de prueba anteriores (Tests 10-13) usaban `"pared"` para simular el suelo/techo, por lo que la condición rota nunca se ejercitó — daba el resultado correcto por una coincidencia del dato de prueba, no por estar bien escrita. Cualquier casa real construida con el bloque de suelo correcto fallaba con `"hueco en el perímetro"` en casi todo el borde. Corregido generalizando la condición a `TIPOS_RELLENO_GENERICO := ["pared", "piso"]` — ver 2.7 y Test 14. Este es el bug de mayor alcance encontrado hasta ahora por pruebas de construcción real: a diferencia de los bugs 7-8 (afectaban geometrías específicas — multi-nivel, techo abierto), este rompía prácticamente cualquier casa construida con las herramientas reales del juego.

### **3.4 Criterios de Aceptación Técnicos**

1. **Minado Preciso:** solo la celda exacta bajo el retículo (centro de pantalla) debe removerse al hacer click izquierdo, nunca una celda vecina.
2. **Colocación Adyacente Correcta:** un bloque colocado con click derecho debe aparecer siempre en la celda vacía inmediatamente adyacente a la cara impactada por el rayo, nunca superpuesto a un bloque existente.
3. **Paridad de Validación:** `BlueprintValidator.gd` debe producir el mismo veredicto (`valido`/errores) que `validar_blueprint()` de PoC 2 para los mismos 6 casos de prueba portados.
4. **Desacoplamiento:** `Player.gd` y `BlueprintValidator.gd` no deben depender el uno del otro ni de `VoxelWorld.gd` más allá de la referencia mínima necesaria (`mundo.colocar_bloque`/`minar_bloque`) — deben poder probarse por separado.
5. **Detección Correcta de Estructuras Cerradas:** el flood-fill de "declarar edificio" debe incluir habitaciones separadas por puertas propias (cerradas) siempre que sus bloques toquen físicamente el resto de la estructura, y debe rechazar (devolver vacío) cualquier intento de declarar un bloque generado por el mundo (piso de tierra) en vez de colocado por el jugador.
6. **Objetos Multi-Celda Atómicos:** `colocar_puerta`/`colocar_cama` no deben colocar ninguna de sus 2 celdas si falta espacio en cualquiera de las dos (todo o nada); `minar_bloque` sobre cualquiera de las 2 celdas de un objeto debe borrar ambas, nunca dejar una mitad huérfana.

---

### **3.5 Puertas interactivas (2026-09-25)**

Las puertas (`puerta_inferior` + `puerta_superior`) dejaron de ser bloques sólidos: son una lámina de 1 × 2 × 0,1 bloques, con su propio cuerpo de colisión, gestionada por `Puertas.gd` (hijo de `VoxelWorld`). Las celdas conservan su tipo (validador, colonos y `BuscadorRutas` no cambian); el ítem de la `MeshLibrary` queda sin malla ni forma y el estado abierta/cerrada vive en `Puertas`.

- **Abrir** gira la lámina 90° al instante sobre su eje vertical central: cerrada, cubre el hueco y bloquea al avatar (capa 1); abierta, se ve de canto y el avatar la atraviesa (capa 4, que el raycast del jugador sí detecta).
- **Avatar:** pulsar `E` apuntando a la puerta la alterna (`Player._interactuar()`). Una puerta abierta a mano solo se cierra a mano.
- **Colonos:** no interactúan; la puerta se abre sola si hay un colono a ≤ 2 celdas (Chebyshev en XZ, ±1 de altura) y se cierra cuando se van. Si el avatar cierra una puerta con un colono al lado, se reabre en el chequeo siguiente (cada 0,25 s).
- **Orientación:** se deduce de los vecinos laterales (pared por X o por Z; sin pared, eje X) y se recalcula en cada chequeo, porque una obra puede surtir la puerta antes que sus paredes.
- Sin guardado de partidas no hay migración: toda puerta nace cerrada al colocarse.
- Spec: `docs/superpowers/specs/2026-09-25-puertas-interactivas-design.md`.

---

## **Próximos Pasos de esta PoC**

> 1. ~~Instalar Godot y verificar manualmente.~~ **Completado:** Godot 4.7 (Steam) instalado; `Test.tscn` y `Main.tscn` corren sin errores en modo headless; 2 bugs de carga encontrados y corregidos (ver 3.3).
> 2. ~~Jugar `Main.tscn` interactivamente.~~ **Completado:** verificado con el MCP de Godot conectado y el depurador — minar/colocar bloques funciona; se agregó una mira (crosshair) mínima (`ColorRect` centrado en un `CanvasLayer`) y se corrigió un warning `SHADOWED_GLOBAL_IDENTIFIER` (los `const ... = preload(...)` usados como workaround en 3.3 ya no son necesarios una vez que el editor real escanea el proyecto y resuelve los `class_name` globales sin conflicto).
> 3. **Mira contextual (feedback visual):** hoy la mira es un punto blanco fijo. Diseño futuro: cambia de forma/color según distancia, herramienta seleccionada y tipo de objetivo — ej. punto pequeño sin objetivo válido a distancia; se expande a un recuadro al apuntar a un bloque recolectable cercano; amarillo si la herramienta activa no es la ideal para el recurso (pico apuntando a un árbol); X si el bloque pertenece a un edificio (no recolectable directamente); círculo con arma cuerpo a cuerpo seleccionada; crosshair de mira telescópica con arma a distancia. Son ejemplos iniciales — la mecánica completa (qué estados existen, cómo se determinan) queda por diseñar en una fase posterior, probablemente ligada a la introducción del inventario/herramientas.
> 4. ~~Migrar de celdas por código a `GridMap` + `MeshLibrary`.~~ **Completado:** `scenes/BlockLibrarySource.tscn` (1 `MeshInstance3D`+`CollisionShape3D` por tipo) exportada a `assets/BlockLibrary.res` con el MCP de Godot; `VoxelWorld.gd` ahora extiende `GridMap`; `Player.gd` deriva la celda impactada con `local_to_map()` en vez de leer metadatos de un `StaticBody3D` por celda. Verificado sin errores corriendo `Main.tscn` (ver 2.1).
> 5. ~~Decidir e implementar el mecanismo de "declarar un edificio".~~ **Completado:** flood-fill 3D sobre bloques del jugador (`VoxelWorld.detectar_estructura()`), activado con `B` apuntando a una puerta; conversión a Blueprint (`BlueprintValidator.estructura_a_blueprint()`) y validación con el mismo `validar_blueprint()` — ver 2.5. **Pendiente:** decidir el flujo de "construir" desde la vista cenital (fuera de esta PoC, requiere PoC 6 — la Cámara Dual completa se corrió de Fase 3 a Fase 4 del roadmap tras insertar Mundo Procedural/Puestos de Recolección, ver GDD Sección 11 v3.14).
> 6. ~~Objetos multi-celda: puerta (2 celdas verticales) y cama (2 celdas horizontales orientadas a la mirada).~~ **Completado:** `VoxelWorld.colocar_puerta()`/`colocar_cama()` con verificación de espacio y minado en cascada (`pareja: Vector3i -> Vector3i`); 4 ítems nuevos en la `MeshLibrary` (`puerta_inferior`/`puerta_superior`, `cama_cabecera`/`cama_pies`); remapeo transparente en `estructura_a_blueprint()` — ver 2.6. Verificado con Test 7 (cama detectada y convertida correctamente) y Test 9 (rechazo por falta de espacio).
> 7. ~~Agregar un bloque `baul` básico y cerrar la regla de almacenamiento.~~ **Completado:** ítem placeholder de 1 celda en la `MeshLibrary`, sin interacción (no se abre, no almacena nada). La regla se rediseñó de "cada cama con su baúl emparejado por posición" a "mínimo 1 baúl por cada cama, contado en todo el edificio" — decisión explícita para dar libertad de diseño (ej. barracones con una sección de casilleros compartida). Verificado con Test 7 (edificio con cama y baúl en habitaciones distintas, válido de punta a punta) y Test 5 (sin baúl, inválido). **Pendiente:** cualquier interacción real del baúl (abrir, almacenar objetos) — fuera de alcance de esta PoC.
> 8. ~~Agregar salto al avatar.~~ **Completado:** `Espacio` salta si `is_on_floor()` (`VELOCIDAD_SALTO`), para facilitar pruebas de construcción en vivo.
> 9. ~~Corregir la agrupación de pisos por capa de Y, y agregar verificación de techo/suelo (2 bugs encontrados en pruebas de construcción real consecutivas).~~ **Completado:** `estructura_a_blueprint()` detecta losas sólidas (suelo/techo) y fusiona las capas de pared de una misma historia en un solo "piso" usando la losa como plantilla base; `validar_techo_y_suelo()` rechaza explícitamente un piso sin techo o suelo real — ver 2.7. Verificado con Test 10 (casa real de 4×5×5, `Válido: true`) y Test 11 (misma casa sin techo, rechazada).
> 10. ~~Definir formalmente "qué es un piso" para edificios de varias historias.~~ **Completado:** losa base y techo exterior 100% sólidos (`_es_losa_completa`); losas intermedias entre pisos apilados pueden tener un hueco de escalera (`_es_losa_parcial`, >50% del interior estructural); altura mínima de 3 celdas por piso, ahora validada (`validar_altura_piso`) — ver 2.7. Verificado con Test 12 (2 pisos con hueco de escalera, válido) y Test 13 (altura insuficiente, rechazado). **Pendiente:** usar esta definición para calcular capacidad de población por piso (según nivel de ciudad) y limitar camas por piso — depende de la integración con `Ciudad`/`Avatar` de PoC 1 (Fase 2).
> 11. **Portar los tests de evolución y personalización de producción de PoC 2** a `BlueprintValidatorTest.gd`.
> 12. **Reemplazar los materiales de color plano por las texturas PBR de Poly Haven** (decisión ya tomada en el GDD, Sección 11) sobre los ítems de `BlockLibrarySource.tscn`, una vez el prototipo de mecánica esté validado.

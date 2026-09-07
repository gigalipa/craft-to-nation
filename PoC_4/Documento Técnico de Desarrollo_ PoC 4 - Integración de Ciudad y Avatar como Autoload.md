# **Documento Técnico de Desarrollo: PoC 4 - Integración de Ciudad y Avatar como Autoload, HUD Básico, y Vínculo con Player.gd**

**Identificador del Módulo:** POC-04-CIUDAD-AUTOLOAD

**Motor:** Godot Engine 4.7 (GDScript), sobre el proyecto compartido `godot/` (ver nota de convención de carpetas en el GDD, Sección 11).

**Dependencias de Diseño:** Secciones 6, 7 y 9 del GDD v3.6 (Demografía, Alimentación, Nivel Urbano e Investigación, Sucesión de Avatar) — las mismas que PoC 1.

**Dependencia Técnica:** Puerto directo de la lógica de `PoC_1/` (Python) a GDScript. El motor de datos (`Ciudad.gd`) sigue aislado de `VoxelWorld`/`BlueprintValidator`, pero `Player.gd` (de `PoC_3/`, ahora en `godot/`) ya llama al autoload `Ciudad` en dos puntos puntuales: muerte de prueba → `suceder_avatar()`, y declarar edificio válido → `registrar_edificio_residencial()`.

**✅ Verificado con Godot 4.7 (Steam) vía MCP:** `scenes/CiudadTest.tscn` corre y los 7 tests de `CiudadTest.gd` (puerto directo de los 6 asserts de PoC 1, 4 asserts de `tasa_neta`/`recurso_critico` para el HUD, y 1 test nuevo de `registrar_edificio_residencial`) pasan sin errores de `assert()`, con los mismos valores numéricos que la versión Python. `scenes/ZonificacionTest.tscn` corre y los 8 tests de `ZonificacionTest.gd` (bootstrap del núcleo urbano, zona de influencia, pintado por rectángulo con recorte, y consulta de zona) pasan sin errores de `assert()`. `scenes/Test.tscn` (13 tests de `BlueprintValidator`) sigue pasando sin cambios, incluido el Test 6 (colocación en zona incorrecta), que ya existía pero cuya lógica solo queda conectada al flujo real de juego con esta pieza. `scenes/Main.tscn` sigue cargando sin errores nuevos (solo las advertencias `class_name` ya conocidas, ver PoC_3, y un `WARNING` de división entera inherente al código de `CamaraCenital.gd`, ver 2.6) con los autoloads `Ciudad`/`Zonificacion`, el HUD (`HUDLayer`), la cámara cenital, el overlay de zonas y los cambios en `Player.gd`.

Esta PoC cubre ya **los 4 sub-proyectos** de la Fase 2: (1) autoload `Ciudad`/`Avatar`, (2) HUD básico, (3) vínculo parcial de `Player.gd` con `Ciudad` (muerte de prueba + registro de camas construidas), y (4) zonificación pintada sobre el grid con bloqueo de construcción fuera de zona (ver 2.6). Producción real de recursos y NPCs colonos quedan para trabajo posterior (ver Próximos Pasos).

---

## **FASE 1: IDEACIÓN**

### **1.1 Alcance y Objetivos de la PoC**

Esta PoC cubre los **4 sub-proyectos** de la **Fase 2 del roadmap** ("Ciudad y Demografía Visibles", GDD Sección 11): el autoload de Ciudad/Avatar, un HUD básico, el vínculo parcial de `Player.gd` con `Ciudad`, y zonificación con bloqueo de construcción. NPCs colonos queda como trabajo futuro (ver 1.2). Se decidió diseñar e implementar cada pieza por separado.

**Sub-proyecto 1 — Autoload:**
* **Puerto Fiel de PoC 1:** `Recurso`, `Ciudad` (con investigación de nivel, variedad alimentaria, sucesión de avatar) y `Avatar`, traducidos línea por línea de Python a GDScript, preservando exactamente la misma semántica y los mismos 6 casos de prueba.
* **Autoload como Singleton Global:** `Ciudad` se registra en `project.godot` bajo `[autoload]`, quedando accesible desde cualquier script del proyecto como `Ciudad.nivel`, `Ciudad.instalaciones`, etc.
* **Simulación por Ticks Discretos:** un `Timer` interno del autoload dispara un tick cada `SEGUNDOS_POR_TICK` segundos — mismo modelo de PoC 1 (ciclos horarios discretos), no una simulación en tiempo real continuo.

**Sub-proyecto 2 — HUD básico:**
* **Lectura en tiempo real del autoload:** un `CanvasLayer` (`HUDLayer`) en `Main.tscn` muestra, cada fotograma, el nivel urbano, la población, la moral, la comida y el "recurso crítico" — ver 2.4 y 3.4 para el diseño completo.

**Sub-proyecto 3 — Vínculo parcial con `Player.gd`:**
* **Muerte de prueba → sucesión:** una tecla de prueba (`K`, sin salud/combate real, ver 2.5) en `Player.gd` llama a `Ciudad.suceder_avatar()` para poder probar la sucesión en vivo. En caso de sucesión exitosa, el jugador reaparece en el punto de partida.
* **Camas construidas → `Ciudad`:** al declarar un edificio residencial válido (tecla `B`), `Player.gd` suma las camas de todos sus pisos y llama a `Ciudad.registrar_edificio_residencial()`, alimentando el nuevo campo `Ciudad.capacidad_camas_construida`. Ver 2.5 para el porqué de no tocar `instalaciones`/`fuentes_comida_activas` todavía.

**Sub-proyecto 4 — Zonificación pintada sobre el grid:**
* **Autoload `Zonificacion`:** estado y lógica pura de la zona de influencia y las zonas pintables (Núcleo A/Núcleo B), independiente de `Ciudad` — ver 2.6.
* **Bootstrap del núcleo urbano:** el primer edificio residencial válido declarado crea la zona de influencia y pinta su propia huella como Núcleo A, sin exigir zona pintada previa.
* **Cámara cenital mínima + overlay visual:** toggle (tecla `C`) entre 1ª persona y una cámara ortogonal top-down; pintado de zonas por rectángulo de 2 clics; overlay traslúcido visible solo desde la cenital.
* **Bloqueo real de construcción por zona:** `Player.gd::_declarar_edificio()` ahora pasa `zona_destino` a `BlueprintValidator.validar_blueprint()`, activando por primera vez `validar_colocacion()` (que ya existía en `BlueprintValidator.gd` pero nunca se usaba).

### **1.2 Fuera de Alcance**

* **NPCs colonos:** pieza de la Fase 2 original todavía no abordada — sub-proyecto independiente posterior, no cubierto por esta PoC.
* **Cámara cenital completa (paneo/zoom, selección de tropas por arrastre):** la versión implementada aquí es deliberadamente mínima — solo lo necesario para pintar zonas. La versión completa es PoC 5 (Fase 3, ver GDD Sección 11). Ver 2.6.
* **Emplazar blueprints desde la vista cenital:** el GDD real exige que el bloqueo de zona también aplique al colocar edificios completos desde arriba, pero esa mecánica no existe todavía (depende de PoC 5 completo) — el bloqueo de esta PoC solo se aplica al declarar edificio en 1ª persona (`Player.gd::_declarar_edificio`). Ver 2.6.
* **Los demás tipos de edificio de la taxonomía (GDD Sección 3.1):** investigación, industrial, producción, militar, recolección, defensivo. Solo existe el tipo residencial construible hoy; la regla de zona se implementó de forma genérica sobre `zona_permitida` para no requerir tocar la validación cuando se agreguen los demás.
* **Redimensionar/mover la zona de influencia, o deshacer una celda ya pintada con otro tipo:** `pintar_zona()` simplemente sobrescribe — comportamiento aceptable para esta PoC.
* **Salud/combate real del jugador:** `Player.gd` sigue sin ningún concepto de salud, daño por caída o combate. La "muerte" de este sub-proyecto es una tecla de prueba (`K`), deliberadamente, para poder probar `suceder_avatar()` sin construir un sistema de daño completo que esta PoC no necesita (ver 2.5).
* **`instalaciones`/`fuentes_comida_activas` desde edificios reales:** decidido explícitamente con el usuario que las casas residenciales que hoy se pueden declarar (con camas/baúles) NO son "instalaciones" de producción (`tipo_1`/`tipo_2`/`tipo_3`, fábricas según GDD Sección 7) — son conceptos distintos. Por eso solo se conecta la capacidad de camas (`capacidad_camas_construida`), no `instalaciones`. Conectar `instalaciones`/`fuentes_comida_activas` de verdad requiere que existan tipos de edificio de producción/comida construibles en `VoxelWorld`, que no existen todavía.
* **Producción real de recursos:** el modelo de `Ciudad` (heredado de PoC 1) solo modela *consumo* de comida y consumo puntual de madera/hierro por investigación — ningún edificio "produce" recursos por tick todavía. La "tasa neta" que muestra el HUD es honesta con este estado: para madera/hierro será casi siempre 0, con saltos puntuales al completarse una investigación. Modelar producción real queda para cuando existan edificios de recolección/fábricas conectados a `Ciudad`.
* **Panel desplegable de todos los recursos "recolectables":** el HUD básico solo muestra comida y el recurso crítico (más moral/población/nivel en una línea cada uno) — un desplegable con el detalle de todos los recursos queda para cuando exista producción real que mostrar.

---

## **FASE 2: PLANEACIÓN**

El modelo matemático y las reglas de negocio (tasas de consumo, índice de sofisticación, costos de investigación, bono de moral por variedad, sucesión de avatar) ya se diseñaron por completo en la Fase de Planeación de `PoC_1/` — ver ese documento, Sección 2. Esta PoC no vuelve a diseñar las reglas, solo las traduce a GDScript y decide cómo exponerlas como un servicio global del motor de juego.

### **2.1 Arquitectura del Proyecto**

```
godot/                      # Proyecto Godot compartido (ver GDD Sección 11)
  project.godot              # [autoload] Ciudad="*res://scripts/Ciudad.gd" + Zonificacion="*res://scripts/Zonificacion.gd"
  scenes/
    CiudadTest.tscn           # Escena de pruebas (sin gameplay)
    ZonificacionTest.tscn     # Escena de pruebas (sin gameplay), mismo patrón que CiudadTest.tscn
    Main.tscn                  # HUDLayer (CanvasLayer + HUD.gd) + CamaraCenital (Camera3D) + ZonaOverlay (Node3D)
  scripts/
    Ciudad.gd                 # Autoload: Ciudad + clases internas Recurso, Avatar
    CiudadTest.gd              # Puerto de ejecutar_pruebas() de PoC 1 + pruebas de tasa_neta/recurso_critico/registrar_edificio_residencial
    HUD.gd                     # Lee Ciudad cada fotograma, actualiza los Labels de Main.tscn
    Zonificacion.gd            # Autoload: estado + lógica pura de zona de influencia y zonas pintables
    ZonificacionTest.gd        # Puerto de pruebas aisladas de Zonificacion.gd (mismo patrón que CiudadTest.gd)
    CamaraCenital.gd            # Cámara ortogonal top-down: toggle, pintado de zonas por 2 clics
    ZonaOverlay.gd               # Overlay visual: un plano semitransparente por celda pintada
    Player.gd                  # (de PoC_3) Llama a Ciudad.suceder_avatar()/registrar_edificio_residencial() y Zonificacion.declarar_nucleo()/consultar_zona()
```

### **2.2 Decisión: Un Solo Archivo, Clases Internas**

GDScript permite declarar clases internas (`class Recurso: ...`) dentro de un mismo archivo `.gd`, igual que PoC 1 declara `Recurso`, `Ciudad` y `Avatar` en un solo módulo Python. Se mantuvo esa misma organización en `Ciudad.gd`: el archivo raíz (que es a la vez el script del autoload, extendiendo `Node` para poder alojar el `Timer`) contiene toda la lógica de `Ciudad`, y declara `Recurso` y `Avatar` como clases internas, accesibles desde otros scripts como `CiudadScript.Avatar`/`CiudadScript.Recurso` (vía `preload`).

**Decisión: sin `class_name` en el script del autoload.** Un autoload registrado bajo el nombre `Ciudad` ya crea un identificador global `Ciudad` apuntando a la instancia viva en el árbol de escena. Si el script además declarara `class_name Ciudad`, ese nombre competiría con el autoload por el mismo identificador — ambigüedad que Godot no permite limpiamente. El script simplemente no declara `class_name`; cualquier otro código que necesite instanciar una `Ciudad` nueva (como las pruebas, que necesitan una instancia aislada y repetible, no la única instancia global) lo hace vía `preload("res://scripts/Ciudad.gd").new()`.

### **2.3 Pruebas Aisladas del Árbol de Escena**

`_init()` (que Godot llama inmediatamente al hacer `.new()`, sin necesitar que el nodo esté en el árbol) inicializa todo el estado de datos (`demografia`, `almacen`, `fuentes_comida_activas`). El `Timer` y su conexión solo se crean en `_ready()` (que solo se dispara si el nodo se agrega al árbol con `add_child()`). Esto permite que `CiudadTest.gd` haga `CiudadScript.new()` y llame a `simular_tick()` directamente en un bucle — igual que PoC 1 hace `urbe = Ciudad()` y llama a `simular_tick()` en Python — sin necesitar una escena con el nodo corriendo de verdad, ni esperar al `Timer` real.

### **2.4 Diseño del HUD**

**Contenido y formato, decidido explícitamente con el usuario:**
* **Nivel urbano**: una línea, solo el valor actual — un nivel (1/2/3) no tiene una "tasa" con sentido.
* **Población**: una línea, `ciudadanos / camas construidas` (`Ciudad.censo_total` / `Ciudad.capacidad_camas_construida`, mismo formato `"%d / %d"` que usan comida y recurso crítico) — en rojo si el censo excede la capacidad, blanco si no. Es la señal directa de que hace falta ampliar la zona residencial o construir más edificios (agregado a petición del usuario, después del HUD inicial que solo mostraba el censo).
* **Moral (bono de variedad):** una línea, solo el valor actual — queda para un desplegable futuro (ver 1.2) mostrar su propia tasa de cambio si hace falta.
* **Comida** y **Recurso crítico**: 2 líneas cada uno — la cantidad almacenada (siempre en blanco) y la tasa neta del último tick (blanco si es ≥ 0, rojo si es negativa). El "recurso crítico" es, de los 3 recursos de `almacen` (comida/madera/hierro), el que tiene la tasa neta más negativa ahora mismo — casi siempre será "comida", honestamente, porque es el único con consumo continuo modelado (ver 1.2, Fuera de Alcance).

**Cálculo de la tasa neta (`Ciudad.gd`):** cada `Recurso` ganó un campo `tasa_neta`. Al inicio de `simular_tick()` se toma una foto de `cantidad` de los 3 recursos; al final, `tasa_neta = cantidad_después - cantidad_antes`. Esto captura el cambio neto real sin importar su causa (consumo de comida, consumo puntual de madera/hierro por investigación, o cualquier producción futura) — no hace falta que el HUD conozca las causas, solo el resultado neto. Nueva función `Ciudad.recurso_critico() -> String` recorre `almacen` y devuelve la clave con la `tasa_neta` más baja.

**HUD.gd:** un script de `CanvasLayer` (`HUDLayer` en `Main.tscn`) que en `_process(_delta)` lee las propiedades del autoload `Ciudad` y actualiza 8 `Label` hijos (nivel, población, moral, comida×2, crítico×3 — nombre + 2 líneas). Actualizar cada fotograma es barato (son solo lecturas de propiedades ya computadas), consistente con la decisión explícita del usuario de no optimizar esto a "solo por tick" en esta pasada.

### **2.5 Vínculo Parcial de `Player.gd` con `Ciudad`**

Dos decisiones tomadas explícitamente con el usuario antes de implementar (ver brainstorming de esta pasada):

**Muerte de prueba, no un sistema de daño real.** `Player.gd` no tiene ningún concepto de salud, caída, ni combate — construir eso completo no lo necesita esta PoC (YAGNI). Se agregó una tecla de prueba (`K`, junto a `B` para declarar edificio) que llama directamente a `Ciudad.suceder_avatar()`, igual de directa que la tecla `B`. Si la sucesión es exitosa, el jugador reaparece en `Vector3(0, 1, 0)` (el punto de partida) — un "respawn" mínimo, sin pantalla de game over ni menú: `sin_sucesor_elegible`/`game_over` solo se imprimen en consola.

**Camas, no instalaciones.** `Ciudad.instalaciones` (`tipo_1`/`tipo_2`/`tipo_3`) representa fábricas de producción (GDD Sección 7), un concepto que no tiene relación con las casas residenciales que hoy se pueden construir y declarar (con camas y baúles). Forzar una casa residencial a contar como "instalación tipo_1" habría sido incorrecto conceptualmente. En su lugar, se agregó un campo nuevo y aislado, `Ciudad.capacidad_camas_construida` (`int`, acumulado), y un método `Ciudad.registrar_edificio_residencial(total_camas: int)`. `Player.gd::_declarar_edificio()` lo llama cuando `resultado["valido"]` es `true`, sumando las camas (`piso["camas"].size()`) de todos los pisos del blueprint declarado.

`ponytail:` `registrar_edificio_residencial()` no deduplica — declarar el mismo edificio dos veces (apuntar y presionar `B` otra vez sobre la misma puerta) suma sus camas dos veces. Corregir esto requiere un registro real de "edificios ya declarados" (por identidad o posición), que no existe todavía y sería prematuro construir sin un caso de uso que lo necesite. Documentado como límite conocido, no como bug.

### **2.6 Zonificación Pintada sobre el Grid**

Diseño completo en `docs/superpowers/specs/2026-09-07-zonificacion-design.md`. `BlueprintValidator.gd` (PoC 3) ya tenía `ZONAS_VALIDAS`, `validar_zona_permitida()` y `validar_colocacion()` escritos, pero `Player.gd::_declarar_edificio()` llamaba a `validar_blueprint(blueprint)` sin `zona_destino`, así que el chequeo de zona nunca se ejecutaba. Este sub-proyecto conecta esa validación existente a un sistema real de zonas pintables sobre el grid.

**Autoload `Zonificacion.gd` (sin `class_name`, mismo patrón que `Ciudad.gd`):** estado puro, sin depender de ningún nodo de escena.
* Estado: `nucleo_declarado: bool`, `influencia_min`/`influencia_max: Vector2i` (esquinas de la caja delimitadora, ambas inclusive), `zonas: Dictionary` (`Vector2i(x,z) -> String`).
* `const MARGEN_ZONA_INFLUENCIA := 15`, `const ZONAS_PINTABLES := ["residencial_investigacion", "fabricacion_militar"]`.
* `declarar_nucleo(huella: Array) -> void`: calcula la caja delimitadora de `huella`, fija la zona de influencia expandiéndola `MARGEN_ZONA_INFLUENCIA` celdas por lado, y pinta cada celda de `huella` como `"residencial_investigacion"`. Idempotente — llamadas repetidas después de la primera se ignoran (`if nucleo_declarado: return`).
* `dentro_de_influencia(celda: Vector2i) -> bool`: `false` si `not nucleo_declarado`; si no, compara `celda` contra `influencia_min`/`influencia_max` (inclusive en ambos ejes).
* `pintar_zona(esquina_a, esquina_b: Vector2i, tipo: String) -> int`: pinta el rectángulo entre las dos esquinas, recortado a `dentro_de_influencia()`; si `tipo` no está en `ZONAS_PINTABLES` no pinta nada. Devuelve cuántas celdas pintó realmente, para que quien llama pueda avisar si el rectángulo cayó total o parcialmente fuera de la influencia.
* `consultar_zona(celda: Vector2i) -> String`: `zonas.get(celda, "periferia")` — toda celda no pintada es periferia por defecto.

**Bootstrap del núcleo urbano (decisión confirmada con el usuario):** no hay una zona pintada de antemano, así que el primer edificio residencial válido se acepta sin exigirla. `Player.gd::_declarar_edificio()` calcula la huella XZ del edificio (celdas únicas de `celdas.keys()`, el diccionario que devuelve `detectar_estructura()`); si `not Zonificacion.nucleo_declarado`, valida con `BlueprintValidator.validar_blueprint(blueprint)` (sin zona, como antes) y, si resulta válido, llama a `Zonificacion.declarar_nucleo(huella)` — creando la zona de influencia y pintando la huella como Núcleo A en la misma declaración. Edificios declarados después del bootstrap sí exigen zona real: se calcula `zona_destino := Zonificacion.consultar_zona(celda_puerta_xz)` (la misma `celda` que ya usa `detectar_estructura()` como referencia de "dónde está" el edificio) y se valida con `BlueprintValidator.validar_blueprint(blueprint, zona_destino)`, activando por fin `validar_colocacion()`.

**Cámara cenital mínima (`CamaraCenital.gd`, script de un `Camera3D` en `Main.tscn`):** proyección ortogonal (`PROJECTION_ORTHOGONAL`), mirando hacia abajo (`rotation_degrees.x = -90`). `posicionar_sobre_influencia()` la centra sobre `(influencia_min + influencia_max) / 2` (u origen, si aún no hay núcleo), llamada por `Main.gd` al activar el toggle. Pintado por rectángulo de 2 clics (estilo SimCity): teclas `1`/`2` seleccionan `ZONAS_PINTABLES[0]`/`[1]`; el primer clic marca una esquina (convertida de posición de pantalla a celda de grid vía raycast contra el plano `y = 0` y `VoxelWorld.local_to_map`), el segundo pinta el rectángulo con `Zonificacion.pintar_zona()`. **Alcance reducido frente a PoC 5:** sin paneo/zoom, sin transición suave de cámara, sin selección de tropas por arrastre — esta versión existe únicamente para poder pintar zonas desde arriba; la cámara cenital completa es Fase 3 del roadmap (GDD Sección 11).

**Overlay visual (`ZonaOverlay.gd`, `Node3D` en `Main.tscn`):** un `MeshInstance3D` (`PlaneMesh` + `StandardMaterial3D` translúcido, color por tipo de zona) por celda pintada en `Zonificacion.zonas`, en `y = 0.05`. `reconstruir()` limpia y recrea todos los planos cada vez que cambia algo — la zona de influencia está acotada (unos cientos de celdas), así que reconstruir todo es más simple que llevar un registro incremental. **Visibilidad condicionada a la cámara activa:** `Main.gd::_alternar_camara_cenital()` (tecla `C`) fija `zona_overlay.visible = cenital_activa` — el overlay solo es visible desde la cenital, nunca en 1ª persona (decisión explícita del usuario). El mismo toggle congela la física del jugador (`jugador.set_physics_process(not cenital_activa)`) mientras la cenital está activa, conservando su posición al volver.

**Límites conocidos, ya identificados en revisión de código y aceptados sin requerir cambios:** `declarar_nucleo()` no protege contra una `huella` vacía (ningún llamador del código actual la invoca así); `CamaraCenital.gd` usa `get_node("../X")` en vez del estilo `$X` usado en el resto del proyecto (solo de estilo, sin efecto funcional).

---

## **FASE 3: DESARROLLO**

### **3.1 Implementación**

El archivo completo vive en `godot/scripts/Ciudad.gd`. Fragmento representativo (propiedades computadas, como en Python):

```gdscript
var nivel_potencial: int:
	get:
		var idx: float = indice_sofisticacion
		if idx >= 2.5 and instalaciones["tipo_3"] >= 3:
			return 3
		elif idx >= 1.7 and instalaciones["tipo_2"] >= 3:
			return 2
		return 1

var nivel: int:
	get: return min(nivel_potencial, nivel_investigado)
```

### **3.2 Pruebas**

`CiudadTest.gd` reproduce los 6 tests de `ejecutar_pruebas()` de PoC 1 palabra por palabra (mismos valores de instalaciones/demografía/ticks), verificando exactamente los mismos criterios de aceptación. Los valores impresos (gasto de comida, stock restante, bono de moral) coinciden numéricamente con la versión Python. Se agregaron 4 asserts tras el Test 1, verificando `tasa_neta`/`recurso_critico`: con solo consumo de comida en ese tick, `almacen["comida"].tasa_neta < 0`, `recurso_critico() == "comida"`, y madera/hierro en `0.0` (sin consumo ese tick). Y un Test 7 nuevo, verificando `registrar_edificio_residencial()`: `capacidad_camas_construida` empieza en 0 y acumula correctamente tras dos llamadas (2 + 3 = 5).

**Cómo ejecutarlos:** abrir `godot/project.godot` en Godot 4.7+, abrir `scenes/CiudadTest.tscn` y presionar **F6**. El panel Output debe mostrar los 7 tests y terminar con "Las 7 pruebas de Ciudad pasaron correctamente", sin ningún `assert()` fallido.

**`ZonificacionTest.gd`** (mismo patrón, corrido vía `ZonificacionTest.tscn`, 8 tests, instancia una `Zonificacion` nueva vía `preload` para aislamiento, no usa el autoload):
1. `dentro_de_influencia()` es `false` antes de `declarar_nucleo()` (y `pintar_zona()` no pinta nada, devuelve 0).
2. `declarar_nucleo()` con una huella no cuadrada (10×7) fija `nucleo_declarado = true` y calcula la caja de influencia correctamente: `(15+10+15)×(15+7+15)` → verificado `influencia_min == (-15,-15)`, `influencia_max == (24,21)`; pinta la huella como `"residencial_investigacion"`.
3. `dentro_de_influencia()` es `true` justo en el borde del margen (`(-15,-15)` y `(24,21)`) y `false` un paso más allá (`(-16,-15)`, `(25,21)`).
4. `pintar_zona()` con ambas esquinas dentro pinta el rectángulo completo (36 celdas en el test), verificado en varias celdas incluidas las esquinas.
5. `pintar_zona()` con un rectángulo parcialmente fuera de la influencia solo pinta las celdas dentro (recorte: 35 de un rectángulo que geométricamente tendría más).
6. `pintar_zona()` con un `tipo` fuera de `ZONAS_PINTABLES` (incluido `"periferia"`, que no es pintable explícitamente) no pinta nada y devuelve 0.
7. `consultar_zona()` de una celda nunca pintada devuelve `"periferia"`.
8. `declarar_nucleo()` llamado dos veces: la segunda llamada no cambia `influencia_min`/`influencia_max` ni pinta la nueva huella.

**Cómo ejecutarlos:** `scenes/ZonificacionTest.tscn`, **F6**. El panel Output debe mostrar los 8 tests y terminar con "Las 8 pruebas de Zonificacion pasaron correctamente".

### **3.3 Criterios de Aceptación Técnicos**

Los mismos 6 de PoC 1 (ver ese documento, Sección 3.3), ahora verificados en GDScript, más:

1. `simular_tick()` no debe arrojar stocks de comida negativos.
2. `Avatar.tasa_hambre` responde de inmediato a `Ciudad.nivel` (propiedad computada, sin caché).
3. Al bajar de nivel, `censo_total` nunca excede la capacidad habitacional; el remanente se contabiliza en `desahuciados`.
4. `Ciudad.nivel` es siempre `min(nivel_potencial, nivel_investigado)`.
5. `bono_moral_variedad` decae gradualmente al desactivar una categoría de comida, nunca de golpe.
6. `suceder_avatar()` respeta la elegibilidad militar (solo militares pueden suceder al avatar).
7. **(HUD)** `recurso_critico()` siempre devuelve el recurso con la `tasa_neta` más negativa del último tick — nunca uno con tasa mayor mientras exista otro con déficit mayor.
8. **(HUD)** El HUD nunca debe mostrar la tasa de un recurso en blanco si es negativa, ni en rojo si es ≥ 0.
9. **(Vínculo `Player.gd`)** `registrar_edificio_residencial(n)` incrementa `capacidad_camas_construida` en exactamente `n`, sin afectar `instalaciones` ni ningún otro campo de `Ciudad`.
10. **(Vínculo `Player.gd`)** `_declarar_edificio()` solo llama a `registrar_edificio_residencial()` cuando `resultado["valido"]` es `true` — un edificio inválido no debe sumar camas.
11. **(Zonificación)** El bootstrap del núcleo urbano es correcto: el primer edificio residencial válido declarado, y solo ese, dispara `Zonificacion.declarar_nucleo()`, creando la zona de influencia a partir de su huella y pintándola como Núcleo A — sin exigir zona pintada previa.
12. **(Zonificación)** `dentro_de_influencia()`/`pintar_zona()` recortan correctamente al área de influencia — nunca pintan ni consideran "dentro" una celda fuera de `influencia_min`/`influencia_max`.
13. **(Zonificación)** Tras el bootstrap, `Player.gd::_declarar_edificio()` bloquea por zona: un edificio declarado sobre una celda no pintada (periferia) o pintada con el tipo incorrecto es rechazado por `validar_colocacion()` con el mismo mensaje de error que ya generaba `BlueprintValidator.gd` (Test 6 de `Test.tscn`), ahora sí alcanzado por el flujo real de juego.

### **3.4 Verificación Visual del HUD**

Verificado sin errores de carga corriendo `Main.tscn` vía MCP (headless, sin poder confirmar visualmente los colores/textos en pantalla — ver Próximos Pasos). La lógica de color (`COLOR_POSITIVO`/`COLOR_NEGATIVO` en `HUD.gd`) y los valores mostrados sí se verificaron indirectamente a través de los asserts nuevos de `CiudadTest.gd` (3.2), que ejercitan exactamente los mismos cálculos que consume el HUD.

### **3.5 Verificación Visual/Interactiva de la Zonificación**

Igual que el HUD (3.4), la cámara cenital, el pintado por mouse (clic de 2 esquinas) y la visibilidad condicionada del overlay solo se pueden confirmar por carga sin errores vía MCP (headless) — `Main.tscn` corre y carga sin errores nuevos (solo el `WARNING` de división entera de `CamaraCenital.gd:28`, ver 2.6), pero el toggle real con la tecla `C`, la conversión de posición de mouse a celda de grid, y que el overlay aparezca/desaparezca correctamente dependen de input de teclado/mouse y cámara en vivo, que requieren jugar la escena en el editor real de Godot. Queda pendiente de esa confirmación manual (ver Próximos Pasos).

---

## **Próximos Pasos de esta PoC**

> 1. ~~HUD básico (comida, moral, nivel urbano, población, recurso crítico) que lea el estado de `Ciudad` en tiempo real.~~ **Completado:** `HUDLayer` en `Main.tscn` + `HUD.gd`, actualizado cada fotograma — ver 2.4/3.4. **Pendiente:** confirmar visualmente los colores/textos jugando la escena (el MCP solo verificó carga sin errores, no apariencia real).
> 2. ~~Vincular el `Avatar` del autoload con `Player.gd` (muerte del jugador → `suceder_avatar()`).~~ **Completado parcialmente:** tecla de prueba `K` dispara `suceder_avatar()` — ver 2.5. **Pendiente:** una causa de muerte real (salud, caída, combate) que reemplace la tecla de prueba, cuando esta PoC la necesite.
> 3. ~~Alimentar `instalaciones`/`fuentes_comida_activas` desde `BlueprintValidator`/`VoxelWorld`.~~ **Completado parcialmente:** declarar un edificio residencial válido suma sus camas a `Ciudad.capacidad_camas_construida` — ver 2.5. **Pendiente:** `instalaciones`/`fuentes_comida_activas` de verdad, que requieren tipos de edificio de producción/comida construibles (no existen en `VoxelWorld` todavía).
> 4. **Modelar producción real de recursos** (edificios de recolección/fábricas que alimenten `almacen` por tick) — sin esto, la métrica de "recurso crítico" del HUD seguirá siendo casi siempre "comida" (ver 1.2).
> 5. **Panel desplegable con el detalle de todos los recursos "recolectables"**, una vez exista producción real que mostrar (ver 1.2).
> 6. ~~Zonificación pintada sobre el grid con bloqueo de construcción fuera de zona.~~ **Completado (sub-proyecto 4):** autoload `Zonificacion.gd`, bootstrap del núcleo urbano, cámara cenital mínima, overlay visual y bloqueo real en `Player.gd::_declarar_edificio()` vía `validar_colocacion()` — ver 2.6. **Pendiente:** confirmar visualmente el toggle de cámara, el pintado por clic y la visibilidad condicionada del overlay jugando en el editor real (ver 3.5); cámara cenital completa (paneo/zoom, selección de tropas por arrastre — PoC 5, Fase 3); emplazar blueprints desde la vista cenital (depende de PoC 5 completo); los demás tipos de edificio de la taxonomía (GDD Sección 3.1: investigación, industrial, producción, militar, recolección, defensivo) — solo existe el tipo residencial construible hoy.
> 7. **NPCs colonos simples** (sin pathfinding avanzado), poblando `demografia` a partir de ciudadanos visibles en el mundo.

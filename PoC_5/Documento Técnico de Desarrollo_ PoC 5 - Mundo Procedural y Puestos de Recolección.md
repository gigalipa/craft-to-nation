# **Documento Técnico de Desarrollo: PoC 5 - Mundo Procedural y Puestos de Recolección**

**Identificador del Módulo:** POC-05-MUNDO-PROCEDURAL

**Motor:** Godot Engine 4.7 (GDScript), sobre el proyecto compartido `godot/` (ver convención de carpetas en el GDD, Sección 11).

**Dependencias de Diseño:** GDD Sección 11 ("Estilo Gráfico y Estrategia de Assets", bullet "Mundo Procedural Finito"), Sección 5 ("Nivelación de Terreno en Emplazamientos con Relieve"), Sección 3 ("Área de Acción de los Puestos de Recolección"), Sección 3.1 (categoría "Recolección" de la taxonomía de edificios).

**Dependencia Técnica:** Extiende `VoxelWorld.gd` (de `PoC_3`/`PoC_4`, ahora en `godot/`), reemplazando su piso plano placeholder por terreno real generado por ruido.

**✅ Verificado con Godot 4.7 (Steam) vía MCP:** `scenes/GeneradorMundoTest.tscn` corre y los 4 tests de `GeneradorMundoTest.gd` (determinismo, rango de alturas, semillas distintas, capas de subsuelo) pasan sin errores de `assert()`. `scenes/NiveladorTerrenoTest.tscn` corre y los 4 tests de `NiveladorTerrenoTest.gd` (pendiente suave aceptada, pendiente pronunciada rechazada, terreno plano sin relleno, cálculo de relleno exacto sobre una rampa) pasan sin errores de `assert()`. `scenes/Main.tscn` carga en ~6 segundos sin errores nuevos con el mundo de 200×200 celdas generado por `GeneradorMundo` (relieve real en vez del piso plano de 11×11 anterior), el jugador apareciendo sobre la altura real del terreno en el **centro** del mundo generado, y la cámara cenital (`CamaraCenital.gd`) con perspectiva oblicua orbitable (paneo `WASD`, órbita `Q`/`E`) más el nuevo modo de nivelación de terreno (tecla `B`, huella fantasma 5×5 centrada en el cursor). `Test.tscn` (14 tests), `CiudadTest.tscn` (7 tests) y `ZonificacionTest.tscn` (8 tests) siguen pasando sin cambios.

Esta PoC cubre los **2 primeros sub-proyectos de 3** de la Fase 3 del roadmap (GDD Sección 11 v3.17): Mundo Procedural Finito y Nivelación de Terreno sobre Relieve. Puestos de Recolección + previsualización en HUD queda para un sub-proyecto posterior.

---

## **FASE 1: IDEACIÓN**

### **1.1 Alcance y Objetivos de esta Pieza**

* **Mundo con relieve real:** reemplazar el piso plano de `VoxelWorld._generar_piso_inicial()` (11×11 celdas de `"piso"` en `y = -1`) por un mundo de 200×200 celdas con altura variable, generado una única vez al arrancar la escena — sin streaming ni chunks dinámicos (decisión ya tomada en el GDD).
* **Determinismo:** el relieve depende únicamente de una semilla — misma semilla, mismo mundo, siempre. Relevante a futuro para el balance multijugador (GDD Sección 10).
* **Bloques de subsuelo:** dos tipos nuevos, `"tierra"` (capa superior del subsuelo) y `"piedra"` (el resto), agregados a la `MeshLibrary` existente con el mismo patrón de color plano que los demás bloques.

**Sub-proyecto 2 — Nivelación de Terreno sobre Relieve (GDD Sección 5):**
* **Modo de nivelación en la cámara cenital:** tecla `B` (solo con la cenital activa) muestra una huella fantasma de 5×5 celdas centrada en el cursor; un clic confirma.
* **Límite de pendiente:** rechaza la nivelación si el desnivel entre celdas horizontalmente/verticalmente adyacentes de la huella supera `LIMITE_PENDIENTE = 2` bloques.
* **Relleno al punto más alto:** si la pendiente es válida, cada celda de la huella se rellena con bloques de `"tierra"` hasta la altura máxima detectada dentro de esa huella; se imprime en consola el total de bloques usados.
* **Cámara cenital con perspectiva oblicua orbitable (ampliación no planeada originalmente):** durante la verificación en vivo del sub-proyecto 1, el usuario reportó que la cámara ortogonal recta original no permitía recorrer el mundo para ubicar la zona de influencia. Se reemplazó por una cámara en órbita clásica (perspectiva, paneo `WASD`, rotación `Q`/`E` alrededor de un punto de mira centrado en el jugador) — ver 3.2.

### **1.2 Fuera de Alcance**

* **Profundidad real de ~300 bloques:** esta pieza usa `PROFUNDIDAD_SUBSUELO = 8` (reducido desde 32 tras la revisión final — ver 3.2) — escalar a la cifra final del GDD es optimización futura (200×200×300 ≈ 12 millones de celdas sería demasiado lento de generar de una sola vez sin más trabajo de rendimiento).
* **Biomas/variantes de superficie** (pasto, arena, nieve): evaluar cuando se aborde el sub-proyecto de Puestos de Recolección, si hace falta distinguir tipos de terreno para determinar qué se puede recolectar dónde.
* **Cuevas/cavidades subterráneas:** GDD Sección 8 ("Túneles y Cavernas"), Visión a futuro — depende de la Fase 6 (Combate) del roadmap.
* **Puestos de Recolección + previsualización en HUD** (GDD Sección 3): tercer sub-proyecto de esta Fase, depende de esta pieza.
* **Semilla aleatoria real / selección de semilla al iniciar partida:** esta pieza usa una constante fija (`SEMILLA_MUNDO = 12345`) para desarrollo determinista.
* **Costo de recursos por nivelar:** el GDD describe la tierra de relleno como un material con costo (Sección 5), pero hoy colocar cualquier bloque es gratuito en todo el juego (sin inventario de recursos) — decidido explícitamente con el usuario dejar la nivelación sin costo, consistente con el resto del juego, hasta que exista un sistema de costos de construcción real.
* **Nivelación automática al emplazar un edificio completo:** el diseño final del GDD nivela automáticamente la huella de cualquier construcción que se emplace. Como hoy no existe un mecanismo de "emplazar una construcción completa" (el jugador solo coloca bloques uno por uno), esta pieza simula la mecánica con una huella fija de 5×5 activada manualmente desde la cámara cenital — conectar la nivelación real al emplazamiento de blueprints queda para cuando esa mecánica exista.
* ~~`GeneradorMundo.altura_en()` no se actualiza tras nivelar~~ — **resuelto**: se agregó `VoxelWorld.altura_en()`, que consulta el `GridMap` real en vez del ruido original, y todos los consumidores (`ZonaOverlay`, `CamaraCenital`, `Main.gd`, `NiveladorTerreno`) migraron a ella. Ver 3.6, tercer bug.

---

## **FASE 2: PLANEACIÓN**

### **2.1 Arquitectura**

```
godot/
  scenes/
    GeneradorMundoTest.tscn    # Nueva escena de pruebas (sin gameplay)
    BlockLibrarySource.tscn     # + bloques "tierra" y "piedra"
    Main.tscn                    # Sin cambios de estructura (el spawn se ajusta en Main.gd)
    Test.tscn                    # Nodo "VoxelWorld" huérfano eliminado (ver 3.2) — solo queda el nodo Test raíz
  scripts/
    GeneradorMundo.gd            # Nuevo: mapa de alturas puro, sin nodos de escena
    GeneradorMundoTest.gd        # Nuevo: pruebas aisladas
    VoxelWorld.gd                 # _generar_piso_inicial() -> _generar_terreno()
    Main.gd                       # _ready(): spawn sobre la altura real del terreno
    BlueprintValidatorTest.gd     # Instancia su propio VoxelWorld.new() aislado (ver 3.2)
  assets/
    BlockLibrary.res              # Regenerado desde BlockLibrarySource.tscn
```

### **2.2 Decisión: Lógica de Terreno Aislada de `GridMap`**

`GeneradorMundo.gd` no depende de ningún nodo de escena — es una clase de datos pura (`RefCounted`) que, dada una semilla, calcula alturas. Esto sigue el mismo patrón ya establecido en el proyecto (`Ciudad.gd`, `Zonificacion.gd`): la lógica que puede probarse sin una escena corriendo, se prueba sin una escena corriendo. `VoxelWorld.gd` es la única pieza que traduce ese mapa de alturas a celdas reales de `GridMap`.

### **2.3 Por Qué `FastNoiseLite` y No una Librería de Terceros**

Se evaluó adoptar `godot_voxel` (Zylann's Voxel Tools), un motor de vóxeles maduro de código abierto — descartado explícitamente: es un motor de mundos infinitos con streaming de chunks y LOD, lo cual contradice la decisión ya tomada en el GDD de usar `GridMap` nativo y finito (sin streaming). Para generar un mapa de alturas por ruido, `FastNoiseLite` ya es nativo de Godot — no hace falta ninguna dependencia externa.

---

## **FASE 3: DESARROLLO**

### **3.1 Implementación**

El archivo completo vive en `godot/scripts/GeneradorMundo.gd`. Fragmento representativo:

```gdscript
func altura_en(x: int, z: int) -> int:
	var valor: float = _ruido.get_noise_2d(x, z)
	var t: float = (valor + 1.0) / 2.0
	var altura: float = ALTURA_MINIMA + t * (ALTURA_MAXIMA - ALTURA_MINIMA)
	return clampi(roundi(altura), ALTURA_MINIMA, ALTURA_MAXIMA)
```

`VoxelWorld._generar_terreno()` recorre las 200×200 columnas del mundo (`ANCHO_MUNDO`/`LARGO_MUNDO`), colocando la celda de superficie (`"piso"`, reutilizando el bloque caminable existente) y el subsuelo (`"tierra"`/`"piedra"` según `GeneradorMundo.tipo_en_profundidad()`) debajo, hasta `PROFUNDIDAD_SUBSUELO` celdas. Ninguna de estas celdas se marca `colocado_por_jugador`, así que el terreno generado nunca puede formar parte de un edificio declarado (mismo comportamiento que el piso plano anterior). `Main.gd::_ready()` calcula la altura de spawn con `mundo.generador.altura_en(ANCHO_MUNDO / 2, LARGO_MUNDO / 2)` y coloca al jugador en el centro del mundo generado, no en la esquina `(0,0)` — ver 3.2.

### **3.2 Correcciones de la Revisión Final**

Dos hallazgos de la revisión final (whole-branch review), ambos corregidos antes de fusionar a `main`:

1. **Spawn en la esquina del mundo, no dentro de él.** La primera versión calculaba el spawn con `altura_en(0, 0)` y colocaba al jugador en `Vector3(0, altura+1, 0)` — la esquina más extrema del mundo generado (`[0, 200) × [0, 200)`), donde 2 de las 4 direcciones de movimiento llevan al jugador fuera del mapa de inmediato. Corregido calculando el spawn en el centro del mundo: `altura_en(ANCHO_MUNDO/2, LARGO_MUNDO/2)`, posicionando al jugador en `Vector3(ANCHO_MUNDO/2, altura+1, LARGO_MUNDO/2)`.
2. **Carga de ~35 segundos sin ninguna señal para el jugador.** La spec ya preveía este escape: si la generación resulta demasiado lenta, la salida es reducir el tamaño, no introducir generación asíncrona. Como el 97% del trabajo (32 de 33 celdas por columna) es subsuelo invisible que el jugador no puede ver hasta cavar, se redujo `PROFUNDIDAD_SUBSUELO` de `32` a `8` — mismo relieve visible, mismas capas `tierra`/`piedra`, sin ningún cambio de comportamiento salvo cuánto se puede cavar antes de llegar al fondo. `Main.tscn` pasó de ~35 segundos a ~6 segundos de carga.

**Nodo `VoxelWorld` Huérfano en `Test.tscn`:** durante la Tarea 3, al adaptar `BlueprintValidatorTest.gd` para que instanciara su propio `VoxelWorld.new()` aislado (en vez de depender de un nodo `VoxelWorld` en la escena, para no contaminar sus pruebas con el terreno generado de 200×200), el nodo `[node name="VoxelWorld" type="GridMap"]` que seguía declarado en `Test.tscn` quedó huérfano: ningún script lo referenciaba ya, pero Godot igual llama a `_ready()` de todo nodo cargado en una escena, así que ese nodo disparaba `_generar_terreno()` (~1.3 millones de llamadas a `colocar_bloque()`) cada vez que se abría `Test.tscn`, sin ningún propósito. Se detectó en la revisión de la Tarea 3 (antes de la revisión final del punto anterior) y se eliminó ese nodo (junto con sus `ext_resource` de `VoxelWorld.gd` y `BlockLibrary.res`, ya sin uso) de `Test.tscn`, que hoy solo contiene su nodo raíz `Test` con el script de pruebas. Resultado: `Test.tscn` pasó de tardar ~35 segundos a cargar en menos de 1 segundo, sin cambiar ningún resultado de sus 14 pruebas.

### **3.3 Pruebas**

`GeneradorMundoTest.gd` verifica: determinismo (misma semilla → mismo mapa), rango de alturas (`[ALTURA_MINIMA, ALTURA_MAXIMA]` en un muestreo amplio, incluyendo coordenadas negativas), que semillas distintas produzcan mapas distintos, y la clasificación correcta de capas de subsuelo (`tierra` hasta `GROSOR_TIERRA`, `piedra` en adelante).

**Cómo ejecutarlos:** abrir `godot/project.godot` en Godot 4.7+, abrir `scenes/GeneradorMundoTest.tscn` y presionar **F6**. El panel Output debe mostrar los 4 tests y terminar con "Las 4 pruebas de GeneradorMundo pasaron correctamente".

### **3.4 Criterios de Aceptación Técnicos**

1. `altura_en(x, z)` es determinista: misma semilla y coordenadas siempre devuelven el mismo valor.
2. `altura_en(x, z)` nunca devuelve un valor fuera de `[ALTURA_MINIMA, ALTURA_MAXIMA]`.
3. El mundo generado en `Main.tscn` tiene relieve real (alturas variables), no un piso plano.
4. El jugador aparece de pie sobre el terreno real en el centro del mundo generado, ni flotando ni enterrado, ni en la esquina del mapa (ver 3.2).
5. El terreno generado nunca se marca `colocado_por_jugador` — declarar un edificio nunca puede incluirlo accidentalmente.

### **3.5 Verificación Visual/Interactiva**

Verificado sin errores de carga corriendo `Main.tscn` vía MCP (headless) — el aspecto visual real del relieve (montañas/valles perceptibles, tiempo de carga aceptable en la práctica) queda pendiente de confirmación jugando en el editor real, mismo patrón que HUD/zonificación (ver `PoC_4/`).

### **3.6 Sub-proyecto 2: Cámara Cenital en Órbita + Nivelación de Terreno**

**Corrección de cámara (encontrada jugando en vivo, antes de empezar este sub-proyecto):** `ZonaOverlay.gd` dibujaba cada plano de zona pintada en un `y` fijo (`0.05`), heredado de cuando el mundo era un piso plano — con relieve real, el overlay quedaba enterrado bajo el terreno en casi toda el área. Corregido calculando la altura real de cada celda con `mundo.generador.altura_en(celda.x, celda.y)`.

**Cámara cenital, de ortogonal recta a órbita clásica:** `CamaraCenital.gd` cambió de `PROJECTION_ORTHOGONAL` (mirando derecho hacia abajo, sin poder moverse, centrada en la zona de influencia o el origen) a `PROJECTION_PERSPECTIVE` en órbita alrededor de un punto de mira (`foco`, sobre `y = 0`): `_actualizar_transform()` recalcula la posición/rotación de la cámara a partir de `foco`, un ángulo de órbita (`angulo_orbital`) y una distancia/inclinación fijas (`DISTANCIA_CAMARA = 25.0`, `ANGULO_INCLINACION = 55°`) — la cámara nunca se mueve directamente. `posicionar_sobre(foco_xz)` centra el punto de mira sobre la posición real del jugador al activar el toggle (`Main.gd` le pasa `jugador.position.x/z`). Mientras la cenital está activa, `WASD` desplaza el punto de mira (relativo a la orientación actual, para que "adelante" siempre aleje el punto de mira de la pantalla sin importar el ángulo de órbita) y `Q`/`E` giran la órbita — ambas teclas reutilizan el input de movimiento del jugador, congelado en 1ª persona mientras tanto.

**Nivelación de terreno (`NiveladorTerreno.gd`, lógica pura sin nodos de escena, mismo patrón que `Zonificacion.gd`):**
- `TAMANO_HUELLA := 5`, `LIMITE_PENDIENTE := 2`.
- `verificar_pendiente(esquina)`: revisa cada par de celdas adyacentes dentro de la huella 5×5 que empieza en `esquina` (la esquina de menor X/Z), rechaza si algún desnivel supera `LIMITE_PENDIENTE`.
- `altura_objetivo(esquina)`: la altura máxima dentro de la huella.
- `calcular_relleno(esquina)`: por cada celda de la huella, cuántos bloques de `"tierra"` faltan para llegar a `altura_objetivo` (0 si ya está al máximo — esas celdas no aparecen en el resultado).

**Interacción en `CamaraCenital.gd`:** tecla `B` (solo con la cenital activa) activa el modo nivelación; un `MeshInstance3D` fantasma de 5×5 con `top_level = true` (para fijar su posición global sin heredar la rotación de la cámara) sigue la celda bajo el cursor **como el centro de la huella** (`esquina = centro - Vector2i(MITAD_HUELLA, MITAD_HUELLA)`, `MITAD_HUELLA = 2`), cambiando de verde a rojo según `verificar_pendiente()`. Un clic confirma: si la pendiente es inválida, imprime el rechazo; si es válida, coloca los bloques de `calcular_relleno()` (tipo `"tierra"`, sin marcar `colocado_por_jugador` — igual que el resto del terreno generado) e imprime el total de bloques usados. Sale del modo nivelación tras el intento, sea cual sea el resultado.

**Bug de inferencia de tipo (mismo patrón recurrente del proyecto):** `var valida := nivelador.verificar_pendiente(esquina)` falló al analizar el script — `nivelador` está tipado `RefCounted` (genérico), así que Godot no puede inferir el tipo de retorno de una llamada dinámica sobre él. Corregido con `var valida: bool = ...` (tipo explícito en vez de `:=`).

**Bug real, encontrado jugando en vivo: la celda detectada quedaba muy lejos del cursor.** `_celda_bajo_mouse()` intersecaba el rayo de la cámara con un plano fijo en `y = 0` — válido cuando el mundo era plano, pero con relieve real (alturas de 0 a 15) y la cámara en ángulo oblicuo, un rayo que visualmente toca el terreno a media altura sigue viajando mucho más lejos horizontalmente antes de llegar a `y = 0`, así que tanto el pintado de zonas como la huella fantasma de nivelación aparecían desplazados del cursor (más desplazados cuanto más alto el terreno bajo el cursor). Corregido con un raycast físico real (`PhysicsRayQueryParameters3D` + `direct_space_state.intersect_ray()`) contra la colisión del terreno — la misma técnica que ya usa `Player._celda_impactada()` para minar/colocar bloques, incluyendo el desplazamiento hacia adentro de la cara golpeada según la normal del impacto. Si el rayo no golpea nada (apunta al cielo o fuera del mundo generado), cae de vuelta a la intersección con el plano `y = 0` como aproximación.

**Segundo bug real, encontrado en la prueba siguiente: overlays ocultos por el propio relieve.** Con el raycast corregido, el usuario reportó dos síntomas relacionados: (1) la huella fantasma a veces desaparecía detrás de bloques cercanos en vez de estar siempre visible, y (2) una zona pintada haciendo clic en dos esquinas de referencia no cubría visualmente todo el rectángulo esperado, con un borde en escalera que coincidía con los propios escalones del relieve. Causa: ambos overlays son planos traslúcidos apoyados justo sobre la superficie; con la cámara en ángulo oblicuo, un plano en una celda baja queda física y visualmente detrás de un bloque más alto en una celda vecina, ocultándolo desde ese ángulo (oclusión por geometría, no un error en qué celdas se pintaron — `Zonificacion.pintar_zona()` sigue pintando el rectángulo completo, solo que parte de él no se veía). Corregido de dos formas:
1. **`ZonaOverlay.gd`** y **la huella fantasma** ahora usan `material.no_depth_test = true` — el overlay se dibuja siempre por encima de lo que haya delante en el buffer de profundidad, sin importar el relieve u otros bloques cercanos.
2. **La huella fantasma dejó de ser un solo plano grande** a la altura máxima de la huella — ahora es una cuadrícula de `TAMANO_HUELLA × TAMANO_HUELLA` mini-planos (25 para esta PoC), cada uno siguiendo la altura real de **su propia** celda (`mundo.generador.altura_en(x, z)`, ver siguiente bug), igual que `ZonaOverlay`. Los 25 planos se crean una sola vez en `_ready()` y solo se reposicionan/recolorean cada fotograma (no se recrean), para no generar basura de nodos mientras el modo nivelación está activo.

**Tercer bug real, más grave: los overlays y la nivelación usaban la altura ORIGINAL, no la real.** Tras corregir la oclusión, el usuario reportó tres síntomas que resultaron tener la misma causa: una zona pintada no cubría el área esperada, la huella de un edificio ya declarado se veía irregular en vez de plana, y la huella de nivelación mostraba "bloques fantasma" que subían un nivel donde el terreno real es plano. Causa raíz: tanto `ZonaOverlay.gd` como `NiveladorTerreno.gd` (vía `CamaraCenital.gd`) consultaban `GeneradorMundo.altura_en()` — el ruido **original**, que nunca se actualiza cuando el jugador mina, construye o nivela. En cualquier celda ya modificada, esa altura no corresponde a ningún bloque real del `GridMap`. Esto no era solo un problema visual: `NiveladorTerreno` también usaba esa altura para calcular pendiente y relleno, así que una segunda nivelación (o nivelar cerca de una construcción) daba resultados incorrectos, no solo mal dibujados.

**Corrección:** nuevo método `VoxelWorld.altura_en(x, z) -> int` que busca la celda sólida más alta REAL en esa columna del `GridMap` (rango de búsqueda generoso, `ALTURA_BUSQUEDA_MAX = 50` a `ALTURA_BUSQUEDA_MIN = -30`, con `generador.altura_en()` como respaldo si no encuentra nada — no debería alcanzarse nunca en el mundo generado). `ZonaOverlay.gd`, `CamaraCenital.gd` (huella fantasma y cálculo de relleno) y `Main.gd` (spawn) pasaron de `mundo.generador.altura_en(...)` a `mundo.altura_en(...)`. `NiveladorTerreno.gd` no necesitó cambios de lógica: como solo llama a `.altura_en(x, z)` por *duck typing* sobre lo que se le pase en `_init()`, ahora se le pasa `VoxelWorld` (`mundo`) directamente en vez de `mundo.generador` — su parámetro se generalizó de `RefCounted` a `Object` porque `VoxelWorld` es un `Node` (extiende `GridMap`), no un `RefCounted`.

### **3.7 Pruebas del Sub-proyecto 2**

`NiveladorTerrenoTest.gd` usa generadores de altura **falsos y deterministas** (no `GeneradorMundo` real, que usa ruido y no permite construir pendientes exactas) para verificar: una pendiente suave (1 celda de desnivel) se acepta; una pendiente pronunciada (3 celdas de desnivel) se rechaza; un terreno plano no necesita relleno; y el cálculo de relleno es exacto sobre una rampa de altura conocida (huella 5×5 con `altura_en(x,z) = z`, total esperado de 50 bloques — verificado por cálculo manual, no solo por la corrida del programa).

**Cómo ejecutarlos:** abrir `scenes/NiveladorTerrenoTest.tscn` en Godot 4.7+ y presionar **F6**. El panel Output debe mostrar los 4 tests y terminar con "Las 4 pruebas de NiveladorTerreno pasaron correctamente".

---

## **Próximos Pasos de esta PoC**

> 1. ~~Mundo Procedural Finito (relieve real, determinista, sin streaming).~~ **Completado:** `GeneradorMundo.gd` + integración en `VoxelWorld.gd` — ver 2.1-3.1. **Pendiente:** confirmar visualmente el relieve y el tiempo de carga real jugando en el editor (ver 3.5); escalar `PROFUNDIDAD_SUBSUELO` hacia los ~300 bloques finales del GDD (optimización futura).
> 2. ~~Nivelación de Terreno en Emplazamientos con Relieve (GDD Sección 5).~~ **Completado, con alcance reducido:** modo de nivelación en la cámara cenital (tecla `B`, huella fija 5×5, límite de pendiente, relleno de tierra) — ver 3.6/3.7. **Pendiente:** conectar la nivelación al emplazamiento real de una construcción completa cuando esa mecánica exista (hoy es una huella fija activada manualmente); costo de recursos por la tierra de relleno (hoy gratuito, como el resto del juego); confirmar visualmente el recuadro fantasma y el resultado del relleno jugando en el editor real.
> 3. **Puestos de Recolección + previsualización en HUD** (GDD Sección 3): nueva categoría de edificio construible (categoría "Recolección" de la Sección 3.1), con área de acción por tipo y previsualización en vivo al emplazar.

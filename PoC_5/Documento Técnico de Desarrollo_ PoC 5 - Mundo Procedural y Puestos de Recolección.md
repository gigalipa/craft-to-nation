# **Documento Técnico de Desarrollo: PoC 5 - Mundo Procedural y Puestos de Recolección**

**Identificador del Módulo:** POC-05-MUNDO-PROCEDURAL

**Motor:** Godot Engine 4.7 (GDScript), sobre el proyecto compartido `godot/` (ver convención de carpetas en el GDD, Sección 11).

**Dependencias de Diseño:** GDD Sección 11 ("Estilo Gráfico y Estrategia de Assets", bullet "Mundo Procedural Finito"), Sección 5 ("Nivelación de Terreno en Emplazamientos con Relieve"), Sección 3 ("Área de Acción de los Puestos de Recolección"), Sección 3.1 (categoría "Recolección" de la taxonomía de edificios).

**Dependencia Técnica:** Extiende `VoxelWorld.gd` (de `PoC_3`/`PoC_4`, ahora en `godot/`), reemplazando su piso plano placeholder por terreno real generado por ruido.

**✅ Verificado con Godot 4.7 (Steam) vía MCP:** `scenes/GeneradorMundoTest.tscn` corre y los 4 tests de `GeneradorMundoTest.gd` (determinismo, rango de alturas, semillas distintas, capas de subsuelo) pasan sin errores de `assert()`. `scenes/Main.tscn` carga en ~6 segundos sin errores nuevos con el mundo de 200×200 celdas generado por `GeneradorMundo` (relieve real en vez del piso plano de 11×11 anterior) y el jugador apareciendo sobre la altura real del terreno en el **centro** del mundo generado (`(ANCHO_MUNDO/2, LARGO_MUNDO/2)`, no en la esquina `(0,0)`). `Test.tscn` (14 tests), `CiudadTest.tscn` (7 tests) y `ZonificacionTest.tscn` (8 tests) siguen pasando sin cambios; `Test.tscn` en particular carga en menos de 1 segundo, tras una corrección de revisión que eliminó un nodo `VoxelWorld` huérfano en la escena (ver 2.1 y 3.2).

Esta PoC cubre el **primer sub-proyecto de 3** de la Fase 3 del roadmap (GDD Sección 11 v3.15): Mundo Procedural Finito. Nivelación de Terreno sobre Relieve y Puestos de Recolección quedan para sub-proyectos posteriores (ambos dependen de este).

---

## **FASE 1: IDEACIÓN**

### **1.1 Alcance y Objetivos de esta Pieza**

* **Mundo con relieve real:** reemplazar el piso plano de `VoxelWorld._generar_piso_inicial()` (11×11 celdas de `"piso"` en `y = -1`) por un mundo de 200×200 celdas con altura variable, generado una única vez al arrancar la escena — sin streaming ni chunks dinámicos (decisión ya tomada en el GDD).
* **Determinismo:** el relieve depende únicamente de una semilla — misma semilla, mismo mundo, siempre. Relevante a futuro para el balance multijugador (GDD Sección 10).
* **Bloques de subsuelo:** dos tipos nuevos, `"tierra"` (capa superior del subsuelo) y `"piedra"` (el resto), agregados a la `MeshLibrary` existente con el mismo patrón de color plano que los demás bloques.

### **1.2 Fuera de Alcance**

* **Profundidad real de ~300 bloques:** esta pieza usa `PROFUNDIDAD_SUBSUELO = 8` (reducido desde 32 tras la revisión final — ver 3.2) — escalar a la cifra final del GDD es optimización futura (200×200×300 ≈ 12 millones de celdas sería demasiado lento de generar de una sola vez sin más trabajo de rendimiento).
* **Biomas/variantes de superficie** (pasto, arena, nieve): evaluar cuando se aborde el sub-proyecto de Puestos de Recolección, si hace falta distinguir tipos de terreno para determinar qué se puede recolectar dónde.
* **Cuevas/cavidades subterráneas:** GDD Sección 8 ("Túneles y Cavernas"), Visión a futuro — depende de la Fase 6 (Combate) del roadmap.
* **Nivelación de terreno al construir sobre relieve** (GDD Sección 5): siguiente sub-proyecto de esta misma Fase — usará `GeneradorMundo.altura_en()`, pero no se implementa en esta pieza.
* **Puestos de Recolección + previsualización en HUD** (GDD Sección 3): tercer sub-proyecto de esta Fase, depende de esta pieza.
* **Semilla aleatoria real / selección de semilla al iniciar partida:** esta pieza usa una constante fija (`SEMILLA_MUNDO = 12345`) para desarrollo determinista.

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

---

## **Próximos Pasos de esta PoC**

> 1. ~~Mundo Procedural Finito (relieve real, determinista, sin streaming).~~ **Completado:** `GeneradorMundo.gd` + integración en `VoxelWorld.gd` — ver 2.1-3.1. **Pendiente:** confirmar visualmente el relieve y el tiempo de carga real jugando en el editor (ver 3.5); escalar `PROFUNDIDAD_SUBSUELO` hacia los ~300 bloques finales del GDD (optimización futura).
> 2. **Nivelación de Terreno en Emplazamientos con Relieve** (GDD Sección 5): nivelar un edificio al punto más alto de su huella, rellenar con tierra las celdas más bajas, y rechazar emplazamientos con pendiente excesiva — usa `GeneradorMundo.altura_en()`.
> 3. **Puestos de Recolección + previsualización en HUD** (GDD Sección 3): nueva categoría de edificio construible (categoría "Recolección" de la Sección 3.1), con área de acción por tipo y previsualización en vivo al emplazar.

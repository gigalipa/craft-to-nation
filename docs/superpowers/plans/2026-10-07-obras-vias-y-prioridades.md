# Obras por Colonos: Tendido de Vías y Prioridades Configurables Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transformar el tendido de vías en una obra progresiva ejecutada por colonos y el avatar, incorporar el selector de prioridad individual en edificios con jerarquía general de asignación en `Obras.gd`, implementar la herramienta unificada de demolición (tecla 3 en cenital) con trazado guiado en naranja para vías (preservando bloques de nivelación), y la herramienta de interacción con vías en 1ra persona (tecla `V`).

**Architecture:**
- **Coordinador central (`Obras.gd`):** Gestiona prioridades individuales de edificios (Alta/Normal/Baja), cola de obras viales (`obras_vias`) y demoliciones viales (`demoliciones_vias`), jerarquía estricta de asignación y fusión de tramos viales contiguos.
- **Planificación de Vías (`ConstructorVias.gd`):** Desglosa trazados en listas secuenciales de pasos atómicos (nivelar columna, colocar cuña, registrar en `Vias.gd`) y ejecución paso a paso.
- **Demolición Guiada de Vías (`CamaraCenital.gd`):** La herramienta de demolición (tecla 3) detecta edificios o vías; sobre vías busca la ruta existente con overlay naranja, confirmando con doble clic y cancelando con clic derecho.
- **Cuadrilla y Movimiento (`Colonos.gd`):** Obreros y técnicos libres toman tareas viales (hasta 4 obreros por obra vial en paralelo) y ejecutan pasos respetando prioridades.
- **Intervención en 1ra persona (`Player.gd`):** Tecla `V` activa el modo exclusivo de vías (clic izq construye, clic der desmantela).

**Tech Stack:** Godot 4.7 GDScript, test runner `tools/run-godot-tests.ps1`.

**Spec:** `docs/superpowers/specs/2026-10-07-obras-vias-y-prioridades-design.md`

---

## Global Constraints

- Tabulaciones en todo GDScript (exigido por Godot).
- Español en comentarios, mensajes y nombres (convención del proyecto).
- `Vector2i(x, z)` para columnas del grid en planta.
- Mantener las 26 escenas de prueba limpias en `tools/run-godot-tests.ps1` con 0 errores.
- La demolición de vías retira el registro en `Vias.gd` y las cuñas físicas, pero **NUNCA modifica ni destruye los bloques de nivelación (tierra/piedra)**.
- Desempate de obras de igual prioridad por orden de ID más antiguo.

---

## File Structure

**Nuevos:**
- `godot/scripts/ViaObraOverlay.gd` — Renderizado de contorno perimetral (wireframe en suelo) para celdas de vía en proceso de construcción.
- `godot/scripts/ViaDemolicionOverlay.gd` — Renderizado de overlay naranja translúcido para el trazado guiado de demolición de vías.

**Modificados:**
- `godot/scripts/Obras.gd` — Prioridades de edificios (Alta/Normal/Baja), registro de obras viales y demoliciones viales, jerarquía general de despacho y fusión de obras viales contiguas.
- `godot/scripts/PanelEdificio.gd` — Selector UI de prioridad de obra (`Alta`, `Normal`, `Baja`).
- `godot/scripts/ConstructorVias.gd` — `planificar_construccion()` y `ejecutar_paso()` para ejecución incremental de vías.
- `godot/scripts/Vias.gd` — Métodos auxiliares para grafo de vías y desmantelamiento limpio de soportes y cuñas sin tocar bloques de soporte.
- `godot/scripts/Colonos.gd` — Manejo de tareas de vías (`via_construir` y `via_demoler`) con hasta 4 obreros por obra en paralelo.
- `godot/scripts/CamaraCenital.gd` — Trazado cenital crea obra vial en lugar de construcción instantánea; herramienta demoler (tecla 3) contextual para vías con previsualización guiada naranja.
- `godot/scripts/Player.gd` — Modo vías en 1ra persona (`V` toggle) para construir/demoler celdas viales a pie.
- `godot/scripts/PanelContextual.gd` / `godot/scripts/HUD.gd` — Tarjeta contextual del modo vías en 1ra persona y modo demoler vía en cenital.
- `godot/scenes/Main.tscn` — Integración de `ViaObraOverlay` y `ViaDemolicionOverlay`.
- Pruebas: `godot/scripts/ObrasTest.gd`, `godot/scripts/HUDTest.gd`, `godot/scripts/ViasTest.gd`, `godot/scripts/ColonosTest.gd`, `godot/scripts/CamaraCenitalModosTest.gd`.

---

## Implementation Tasks

### Task 1: Prioridades de Obras en `Obras.gd` y `PanelEdificio.gd`

**Files:**
- Modify: `godot/scripts/Obras.gd`
- Modify: `godot/scripts/PanelEdificio.gd`
- Modify: `godot/scripts/ObrasTest.gd`
- Modify: `godot/scripts/HUDTest.gd`

**Step-by-step:**
- [ ] **Step 1: Escribir pruebas unitarias de prioridades en `ObrasTest.gd`**
  - Probar `fijar_prioridad(id, valor)` y `prioridad_de(id)` (Alta=2, Normal=1, Baja=0, default=1).
  - Probar que `siguiente_tarea()` ofrece edificios de prioridad Alta antes que Normal, y Normal antes que Baja.
  - Probar que ante igual prioridad desempata por ID menor (antigüedad de emplazamiento).
- [ ] **Step 2: Implementar lógica de prioridades en `Obras.gd`**
  - Añadir `prioridades: Dictionary = {}` (`id -> int`).
  - Constantes `PRIORIDAD_ALTA = 2`, `PRIORIDAD_NORMAL = 1`, `PRIORIDAD_BAJA = 0`.
  - Métodos `fijar_prioridad(id: int, p: int)` y `prioridad_de(id: int) -> int`.
  - En `olvidar(id)`: limpiar `prioridades.erase(id)`.
  - En `siguiente_tarea()`: agrupar y ordenar según jerarquía:
    1. Construcción Alta (2)
    2. Construcción Normal (1)
    3. Demoliciones
    4. Vías (preparado para Task 2)
    5. Construcción Baja (0)
- [ ] **Step 3: Añadir selector de prioridad en `PanelEdificio.gd`**
  - Añadir control en el panel (botón cíclico o selector `[Prioridad: Normal]`).
  - Al pulsar, cicla `Normal -> Alta -> Baja -> Normal` y llama a `Obras.fijar_prioridad(id_edificio, nueva_p)`.
  - Actualizar visualización en `_actualizar()`.
- [ ] **Step 4: Pruebas unitarias de UI en `HUDTest.gd`**
  - Verificar que el botón de prioridad en `PanelEdificio` refleja y conmuta los estados correctamente.
- [ ] **Step 5: Ejecutar pruebas y verificar paso limpio**
  - Correr `ObrasTest.tscn` y `HUDTest.tscn`.

---

### Task 2: Planificación Incremental y Obra de Vías en `ConstructorVias.gd` y `Obras.gd`

**Files:**
- Modify: `godot/scripts/ConstructorVias.gd`
- Modify: `godot/scripts/Obras.gd`
- Modify: `godot/scripts/ViasTest.gd`
- Modify: `godot/scripts/ObrasTest.gd`

**Step-by-step:**
- [ ] **Step 1: Escribir pruebas en `ViasTest.gd` y `ObrasTest.gd` para planificación y ejecución incremental**
  - Probar `ConstructorVias.planificar(mundo, vertices, choca)` devolviendo lista de pasos detallados (nivelación y cuñas).
  - Probar `ConstructorVias.ejecutar_paso(mundo, paso)` completando una celda y devolviendo su celda de soporte.
  - Probar en `Obras.gd`: `crear_obra_via(plan)` genera un `id_via`.
  - Probar fusión de tramos: crear una obra de vía que comparte vértices con otra incompleta las une bajo el mismo `id_via`.
- [ ] **Step 2: Implementar desglose en `ConstructorVias.gd`**
  - Extraer de `construir()` la lógica en `planificar(mundo, vertices, choca) -> Dictionary`.
  - Estructurar cada paso: `{ "tipo": "nivelar"|"cuna", "columna": Vector2i, "y": int, "cuna_tipo": String, "direccion_alta": int, "notch": Dictionary }`.
  - Implementar `ejecutar_paso(mundo, paso) -> Vector3i` que ejecuta la nivelación o coloca la cuña y devuelve la celda de soporte.
- [ ] **Step 3: Implementar gestión de obras de vías en `Obras.gd`**
  - Estructuras: `obras_vias: Dictionary = {}` (`id_via -> Dictionary` con `vertices`, `pasos_pendientes`, `pasos_completados`, `celdas_soporte`, `notches`).
  - `crear_obra_via(plan: Dictionary) -> int`: detecta conexión con obra existente incompleta con `buscar_obra_via_conectada(vertices)`. Si existe, une pasos y vértices; si no, asigna nuevo ID.
  - `trabajar_via(id_via: int) -> Dictionary`: toma el siguiente paso pendiente, llama a `ConstructorVias.ejecutar_paso`, registra la celda de soporte en `Vias.gd` y actualiza progreso. Al terminar el último paso, emite fin de obra y limpia.
  - Métodos `huella_via(id_via: int) -> Array`, `celdas_pendientes_via(id_via: int) -> Array`.
- [ ] **Step 4: Ejecutar pruebas y verificar**
  - Correr `ViasTest.tscn` y `ObrasTest.tscn`.

---

### Task 3: Overlays Visuales: Contorno Guía de Obras y Demolición Guiada Naranja

**Files:**
- Create: `godot/scripts/ViaObraOverlay.gd`
- Create: `godot/scripts/ViaDemolicionOverlay.gd`
- Modify: `godot/scenes/Main.tscn`
- Modify: `godot/scripts/ViasTest.gd`

**Step-by-step:**
- [ ] **Step 1: Crear `ViaObraOverlay.gd`**
  - Nodo que dibuja el contorno (alambre/wireframe) en el suelo de las columnas y celdas de vías con obra pendiente.
  - Se conecta a señales de `Obras.gd` (`obra_via_creada`, `obra_via_paso`, `obra_via_completada`).
  - Utiliza `ImmediateMesh` o `MeshInstance3D` con líneas para renderizar los bordes perimetrales sin rellenar el interior.
- [ ] **Step 2: Crear `ViaDemolicionOverlay.gd`**
  - Nodo que dibuja un plano translúcido color naranja (`Color(1.0, 0.5, 0.0, 0.45)`) sobre las celdas de vía seleccionadas para demolición.
  - Métodos `mostrar_tramo(celdas: Array[Vector3i])` y `limpiar()`.
- [ ] **Step 3: Instanciar en `Main.tscn`**
  - Integrar ambos overlays como hijos de `Main` (junto a `ViaPreviewOverlay` y `MarcasDemolicionOverlay`).
- [ ] **Step 4: Verificar visualización en pruebas**
  - Añadir pruebas unitarias de actualización de overlays en `ViasTest.gd`.

---

### Task 4: Colonos Trabajando en Obras de Vía

**Files:**
- Modify: `godot/scripts/Colonos.gd`
- Modify: `godot/scripts/ColonosTest.gd`

**Step-by-step:**
- [ ] **Step 1: Escribir pruebas en `ColonosTest.gd`**
  - Verificar que un colono libre toma tarea `"via_construir"`.
  - Verificar que hasta 4 colonos pueden estar asignados a la misma obra de vía en paralelo.
  - Verificar que un colono camina junto al paso de la vía, ejecuta `Obras.trabajar_via` y avanza.
  - Verificar que un colono prefiere edificios Alta/Normal antes que vías, pero vías antes que edificios Baja.
- [ ] **Step 2: Integrar tareas de vías en `Colonos.gd`**
  - En `_decidir_ocioso()`: admitir `tarea["tipo"] == "via_construir"`.
  - En `_trabajar_en_obra()`: bifurcar ejecución si `tarea["tipo"] == "via_construir"`. El colono se desplaza junto a la celda del paso pendiente (`_ir_junto_a`) y llama a `Obras.trabajar_via(id)`.
  - Actualizar `obreros_en(id)` para incluir obreros en vías.
- [ ] **Step 3: Ejecutar pruebas y verificar**
  - Correr `ColonosTest.tscn`.

---

### Task 5: Herramienta de Demolición Contextual y Guiada de Vías (Tecla 3 Cenital)

**Files:**
- Modify: `godot/scripts/Vias.gd`
- Modify: `godot/scripts/Obras.gd`
- Modify: `godot/scripts/CamaraCenital.gd`
- Modify: `godot/scripts/CamaraCenitalModosTest.gd`
- Modify: `godot/scripts/ViasTest.gd`

**Step-by-step:**
- [ ] **Step 1: Escribir pruebas de búsqueda de camino de demolición y desmantelamiento limpio**
  - En `Vias.gd`: método `buscar_camino_en_red(inicio: Vector2i, fin: Vector2i) -> Array[Vector2i]` que recorre solo celdas con vía existente.
  - En `Obras.gd`: método `demoler_paso_via(id_demolicion)` que retira cuña y soporte en `Vias.gd` sin minar ni modificar el bloque base de nivelación.
- [ ] **Step 2: Implementar lógica en `Vias.gd` y `Obras.gd`**
  - `Vias.buscar_camino_en_red()`: A* sobre celdas contiguas con `Vias.es_via()`.
  - `Obras.crear_demolicion_via(celdas: Array[Vector3i]) -> int`.
  - `Obras.trabajar_demoler_via(id_demolicion: int)`: retira la celda de soporte de `Vias.gd` y cuñas físicas del `GridMap`, pero preserva bloques de tierra/piedra nivelados.
- [ ] **Step 3: Integrar en `CamaraCenital.gd` en modo demoler (tecla 3)**
  - Al hacer clic sobre una vía en `modo_demoler`:
    - Iniciar trazado de demolición de vía (`_demoliendo_via = true`).
    - Al mover el cursor, calcular ruta guiada sobre la red vial con `Vias.buscar_camino_en_red()` y mostrar en `ViaDemolicionOverlay` (naranja).
    - Clics sucesivos fijan nodos de ruta para seleccionar ramas en cruces.
    - Doble clic: confirma y genera orden en `Obras.crear_demolicion_via()`.
    - Clic derecho: cancela la selección de demolición.
- [ ] **Step 4: Pruebas y verificación**
  - Correr `CamaraCenitalModosTest.tscn` y `ViasTest.tscn`.

---

### Task 6: Trazado Cenital que Emplaza Obras de Vía

**Files:**
- Modify: `godot/scripts/CamaraCenital.gd`
- Modify: `godot/scripts/CamaraCenitalModosTest.gd`

**Step-by-step:**
- [ ] **Step 1: Actualizar `_confirmar_trazo_via()` en `CamaraCenital.gd`**
  - En lugar de llamar a `ConstructorVias.construir` directo, llamar a `ConstructorVias.planificar(mundo, vertices, choca)`.
  - Si es válido, pasar el plan a `Obras.crear_obra_via(plan)`.
  - Notificar al jugador: "Obra de vía emplazada: esperando cuadrilla." (o fusionada si conecta).
- [ ] **Step 2: Probar en `CamaraCenitalModosTest.gd`**
  - Comprobar que confirmar vía crea una obra pendiente y no coloca la vía instantáneamente en `Vias.gd`.

---

### Task 7: Intervención Manual en 1ra Persona (Modo Vías con Tecla `V`)

**Files:**
- Modify: `godot/scripts/Player.gd`
- Modify: `godot/scripts/PanelContextual.gd`
- Modify: `godot/scripts/HUD.gd`
- Modify: `godot/scripts/HUDTest.gd`

**Step-by-step:**
- [ ] **Step 1: Escribir pruebas unitarias en `HUDTest.gd` para modo vías en 1ra persona**
  - Probar alternancia de `modo_vias` con tecla `V`.
  - Probar tarjeta contextual para el modo vías (Clic izquierdo: Construir, Clic derecho: Demoler, V: Salir).
- [ ] **Step 2: Implementar modo vías en `Player.gd`**
  - Variable `modo_vias: bool = false`.
  - En `_input()`: capturar tecla `V` en 1ra persona para alternar `modo_vias`.
  - Cuando `modo_vias == true`: bloquear interacción con otros bloques normales.
  - Al hacer clic izquierdo apuntando a celda de obra vial: llamar a `Obras.trabajar_via(id_via)` y `Obras.reclamar(id_via)`.
  - Al hacer clic derecho apuntando a celda de demolición de vía: llamar a `Obras.trabajar_demoler_via(id_demolicion)`.
- [ ] **Step 3: Actualizar `PanelContextual.gd`**
  - Añadir tarjeta contextual para el modo de interacción con vías en 1ra persona.
- [ ] **Step 4: Ejecutar pruebas y verificar**
  - Correr `HUDTest.tscn`.

---

### Task 8: Verificación Global, Documentación y Suite de Pruebas

**Files:**
- Modify: `docs/Pendientes y próximos pasos.md`
- Modify: `Documento de Diseño de Juego (GDD)_ Craft to Nation.md`
- Modify: `README.md`

**Step-by-step:**
- [ ] **Step 1: Ejecutar la suite completa de 26 escenas**
  - `pwsh -File tools/run-godot-tests.ps1` -> Todas las escenas pasando con 0 errores.
- [ ] **Step 2: Actualizar documentación**
  - `docs/Pendientes y próximos pasos.md`: marcar Paso 8 como completado y avanzar la ruta a Paso 9 (bombas extractoras).
  - GDD: sincronizar a v3.53 detallando obras de vías, prioridades configurables, demolición de vías y modo vías en 1ra persona.
  - `README.md`: actualizar versión de GDD y conteo de pruebas.

# Plan de Implementación: Etapa 9.1 - Subsuelo, Pozos de Líquidos y Bloques de Puertos

> **Contexto:** Craft to Nation - Paso 9 (Fluidos, Extracción y Red de Tuberías)  
> **Rama de trabajo:** `feature/subsuelo-bloques`  
> **Directorio worktree:** `.worktrees/subsuelo-bloques`  
> **Especificación:** [`docs/superpowers/specs/2026-10-08-subsuelo-pozos-y-bloques-design.md`](file:///c:/Users/peraz/Projects/Misc/CityCraft/docs/superpowers/specs/2026-10-08-subsuelo-pozos-y-bloques-design.md)

---

## Estructura de Archivos a Modificar / Crear

- **`godot/scripts/GeneradorMundo.gd`**:
  - Incorporar generadores de ruido 3D (`_ruido_pozos`) y 2D/3D regional (`_ruido_tipo_pozo`).
  - Actualizar `tipo_en_profundidad()` para colocar bolsas líquidas de `"agua"` y `"crudo"` en profundidad $\ge 4$.
  - Métodos `es_pozo_en()` y `tipo_pozo_en()`.
- **`godot/scripts/GeneradorMundoTest.gd`**:
  - Pruebas unitarias de generación de pozos, profundidad mínima y exclusión mutua estricta agua vs. crudo.
- **`godot/scripts/VoxelWorld.gd`**:
  - Registro de `"crudo"` en `TIPOS_TRANSLUCIDOS`, `TIPOS_LIQUIDOS` y shapes sin colisión sólida.
  - Escurrimiento adaptado para crudo (menor alcance y mayor retardo).
  - Definición y registro de los 6 bloques de puertos (`puerto_*_in/out`) con métodos estáticos de consulta.
- **`godot/scripts/TranslucidosRenderer.gd`**:
  - Material `MATERIAL_CRUDO` (negro petróleo translúcido con brillo especular) y culling de caras internas para `"crudo"`.
- **`godot/scripts/TranslucidosRendererTest.gd`**:
  - Pruebas unitarias de renderizado y culling de `"crudo"`.
- **`godot/scripts/Player.gd`**:
  - Detección de inmersión en crudo, resistencia viscosa horizontal, flotabilidad vertical y consumo de oxígeno.
- **`godot/scripts/PlayerNatacionTest.gd`**:
  - Pruebas unitarias de inmersión y factores físicos en `"crudo"`.

---

## Tareas de Implementación

### Tarea 1: Generación de pozos de agua y crudo en el subsuelo
**Objetivo:** Permitir que `GeneradorMundo` genere depósitos naturales 3D de agua y crudo por debajo de la superficie, sin mezclar ambos fluidos en un mismo pozo.

- [ ] **1.1 Escribir pruebas unitarias en `GeneradorMundoTest.gd`:**
  - `TEST: pozos subterráneos de agua y crudo aparecen a profundidad >= PROFUNDIDAD_POZOS`: verificar que celdas de agua y crudo existen en el subsuelo.
  - `TEST: exclusión mutua de pozos`: para todas las celdas líquidas subterráneas conectadas, verificar que ninguna bolsa contiene simultáneamente agua y crudo.
- [ ] **1.2 Ejecutar `GeneradorMundoTest.tscn` para confirmar que las pruebas fallan (TDD).**
- [ ] **1.3 Implementar en `GeneradorMundo.gd`:**
  - Constantes `PROFUNDIDAD_POZOS := 4`, `UMBRAL_POZO := 0.48`.
  - Inicializar `_ruido_pozos` (`FastNoiseLite`, 3D Perlin, freq 0.04, semilla + 10).
  - Inicializar `_ruido_tipo_pozo` (`FastNoiseLite`, 2D Perlin, freq 0.015, semilla + 11).
  - En `tipo_en_profundidad(x, y, z, prof)`: evaluar si `prof >= PROFUNDIDAD_POZOS` y `_ruido_pozos.get_noise_3d(x, y, z) > UMBRAL_POZO`. Si califica, retornar `"crudo"` si `_ruido_tipo_pozo.get_noise_2d(x, z) > 0.0` sino `"agua"`.
  - Exponer `es_pozo_en(x, y, z)` y `tipo_pozo_en(x, y, z)`.
- [ ] **1.4 Ejecutar `GeneradorMundoTest.tscn` y verificar que pase.**

---

### Tarea 2: Bloque `crudo` y renderizado translúcido
**Objetivo:** Permitir que el mundo trate al `"crudo"` como líquido translúcido sin colisión física sólida y con renderizado óptimo de culling.

- [ ] **2.1 Escribir pruebas en `TranslucidosRendererTest.gd`:**
  - Verificar que `"crudo"` es reconocido como translúcido y genera mallas con `MATERIAL_CRUDO`.
  - Verificar culling de caras internas entre dos celdas contiguas de `"crudo"`.
- [ ] **2.2 Implementar en `VoxelWorld.gd`:**
  - Agregar `"crudo"` a `TIPOS_TRANSLUCIDOS`.
  - En `_indexar_biblioteca()`: asegurar que el bloque `"crudo"` tenga `mesh_library.set_item_shapes(id, [])` para no tener colisión sólida.
  - En la simulación de fluidos/escurrimiento: contemplar viscosidad de crudo (máx 3 celdas horizontales).
- [ ] **2.3 Implementar en `TranslucidosRenderer.gd`:**
  - Crear `MATERIAL_CRUDO` (albedo oscuro `Color(0.06, 0.05, 0.04, 0.94)`, `roughness = 0.1`, `specular = 0.8`).
  - Mapear `"crudo"` a `MATERIAL_CRUDO` y aplicar la misma lógica de culling que el agua.
- [ ] **2.4 Ejecutar `TranslucidosRendererTest.tscn` y verificar que pase.**

---

### Tarea 3: Físicas de viscosidad e inmersión en crudo para el avatar
**Objetivo:** Permitir que el avatar reaccione de forma realista al entrar a un bloque de crudo (mayor resistencia, menor gravedad, consumo de oxígeno).

- [ ] **3.1 Escribir pruebas en `PlayerNatacionTest.gd`:**
  - Verificar que `_profundidad_liquido_en()` o función de inmersión detecta crudo.
  - Verificar factores de velocidad y flotabilidad en crudo vs. agua.
- [ ] **3.2 Implementar en `Player.gd`:**
  - Métodos `_en_liquido()`, `_en_crudo()`, `_cabeza_sumergida()`.
  - En `_physics_process()`: si está en crudo, aplicar multiplicador de velocidad horizontal `0.5` y límite vertical viscoso.
  - Asegurar que `_cabeza_sumergida()` consuma oxígeno tanto en agua como en crudo.
- [ ] **3.3 Ejecutar `PlayerNatacionTest.tscn` y `PlayerOxigenoTest.tscn`.**

---

### Tarea 4: Bloques de puertos de conexión
**Objetivo:** Definir y registrar los 6 bloques de puertos funcionales en `VoxelWorld.gd`.

- [ ] **4.1 Implementar registro y helpers en `VoxelWorld.gd`:**
  - Constantes `TIPOS_PUERTO = ["puerto_agua_in", "puerto_agua_out", "puerto_crudo_in", "puerto_crudo_out", "puerto_combustible_in", "puerto_combustible_out"]`.
  - Registro dinámico en `_indexar_biblioteca()` con `BoxMesh` y colores distintivos (Azul para agua, Ámbar para crudo, Naranja para combustible) si faltan en la biblioteca.
  - Métodos estáticos:
    - `es_puerto(tipo: String) -> bool`
    - `recurso_de_puerto(tipo: String) -> String`
    - `direccion_de_puerto(tipo: String) -> String`
- [ ] **4.2 Escribir prueba unitaria en `ConstruccionTest.gd` o escena pertinente:**
  - Validar clasificación correcta de los 6 tipos de puertos.

---

### Tarea 5: Verificación de la suite completa y documentación
**Objetivo:** Asegurar que toda la suite de 26 escenas pase sin regresiones en el worktree.

- [ ] **5.1 Ejecutar `tools/run-godot-tests.ps1` en `.worktrees/subsuelo-bloques`.**
- [ ] **5.2 Revisar `git status` y verificar que no haya archivos huérfanos.**

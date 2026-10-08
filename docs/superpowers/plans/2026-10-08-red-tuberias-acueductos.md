# Red de Tuberías y Acueductos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar la infraestructura completa de canalizaciones elevadas (acueductos y tuberías) con columnas de soporte, pasos a desnivel, puertos de conexión, red de distribución compartida entre almacenes, y simulación de flujo y derrames visuales en `VoxelWorld`.

**Architecture:** Módulo singleton `Canalizaciones.gd` gestiona la topología de red, columnas automáticas y conectividad a puertos de edificios. Los ductos y columnas se materializan como bloques reales en `VoxelWorld`. La simulación económica en `Economia.gd` transporta instantáneamente fluidos o activa derrames vertiendo bloques reales de fluido (`agua`, `crudo`, `combustible`) en extremos desconectados. La interfaz se expande con la categoría 6 ("Ductos") en `BarraModos.gd` y trazado elevado en `CamaraCenital.gd`.

**Tech Stack:** Godot 4.x, GDScript, GridMap/VoxelWorld, TranslucidosRenderer.

**Spec:** `docs/superpowers/specs/2026-10-08-red-tuberias-acueductos-design.md`

## Global Constraints

- Altura estándar de canalización: $Y = Y_{suelo} + 4$ (3 bloques de aire de despeje peatonal por debajo).
- Columnas de soporte cada 5 bloques horizontales (4 bloques de vano libre entre pilares), en esquinas de 90° y en extremos abiertos.
- En cambios de pendiente, las columnas mantienen su espaciado horizontal de 4 bloques de vano y el ducto une diagonalmente las cimas de ambas columnas.
- Pasos a desnivel: si un ducto cruza otro existente a la misma cota, se sobre-eleva 1 bloque ($Y = Y_{suelo} + 5$) en la intersección.
- Acueducto: piedra y madera; transporta solo agua y combustible.
- Tubería: acero; transporta agua, crudo y combustible.
- Almacenes (`almacen`): distribución compartida instantánea para todos los almacenes del mapa; el núcleo urbano (`id_nucleo`) no almacena líquidos.
- Derrames: producen un bloque físico de fluido (`agua`, `crudo`, `combustible`) en el extremo desconectado y escurren en cascada.
- Menú Construir: Categoría 6 ("Ductos"), opción 1 Acueducto (`1-6-1`), opción 2 Tubería (`1-6-2`).

## Review Focus

- Un acueducto intentando transportar o conectarse a un puerto de `crudo` debe ser rechazado sin colocar bloques.
- Un ducto cruzando otro existente a la misma cota debe quedar a $Y+5$ sin reemplazar ni desconectar el ducto existente.
- Un productor bombeando a un ducto sin salida debe verter un bloque de fluido en el extremo y mostrar estado `Derrame` en el puerto.
- El fluido depositado en un almacén en $(X_1, Z_1)$ debe poder ser extraído inmediatamente por un consumidor conectado a un almacén en $(X_2, Z_2)$.
- Los colonos y vías terrestres deben poder circular libremente bajo los vanos de 4 celdas entre columnas.

---

### Task 1: Bloque `combustible` y Renderizado de Fluidos Translúcidos

**Files:**
- Modify: `godot/scripts/VoxelWorld.gd:175-220, 660-690, 870-940`
- Modify: `godot/scripts/TranslucidosRenderer.gd:20-80`
- Test: `godot/scripts/TranslucidosRendererTest.gd`

**Interfaces:**
- Consumes: `VoxelWorld.TIPOS_TRANSLUCIDOS`, `VoxelWorld.TIPOS_LIQUIDOS`.
- Produces: Bloque `"combustible"` registrado como fluido translúcido ámbar con propagación por escurrimiento igual a `agua` y `crudo`.

- [ ] **Step 1: Write the failing test**

Añadir en `godot/scripts/TranslucidosRendererTest.gd` pruebas para el registro, material ámbar y escurrimiento del bloque `"combustible"`.

```gdscript
func test_bloque_combustible_es_translucido_y_liquido() -> void:
	assert_true(VoxelWorld.TIPOS_TRANSLUCIDOS.has("combustible"), "combustible debe ser traslucido")
	assert_true(VoxelWorld.TIPOS_LIQUIDOS.has("combustible"), "combustible debe ser liquido")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tools/run-godot-tests.ps1`
Expected: FAIL con `combustible debe ser traslucido`.

- [ ] **Step 3: Write minimal implementation**

En `VoxelWorld.gd`:
1. Agregar `"combustible"` a `TIPOS_TRANSLUCIDOS` y `TIPOS_LIQUIDOS`.
2. En `_indexar_biblioteca()`, registrar dinámicamente el ítem `"combustible"` con malla nula y colisión vacía en GridMap.
3. En `_escurrir_agua_desde()` y minar/colocar, extender la propagación a fluidos de `TIPOS_LIQUIDOS` (agua, crudo, combustible).
En `TranslucidosRenderer.gd`:
1. Indexar material ámbar para `"combustible"` (color ámbar `Color(1.0, 0.6, 0.1, 0.7)` con shader o material translúcido).

- [ ] **Step 4: Run test to verify it passes**

Run: `tools/run-godot-tests.ps1`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/VoxelWorld.gd godot/scripts/TranslucidosRenderer.gd godot/scripts/TranslucidosRendererTest.gd
git commit -m "feat: add combustible as translucent fluid block with cascade flow"
```

---

### Task 2: Autoload `Canalizaciones.gd` y Topología de Red

**Files:**
- Create: `godot/scripts/Canalizaciones.gd`
- Create: `godot/scenes/CanalizacionesTest.tscn`
- Create: `godot/scripts/CanalizacionesTest.gd`
- Modify: `godot/project.godot` (registrar autoload Canalizaciones)

**Interfaces:**
- Consumes: `VoxelWorld` (`colocar_bloque`, `obtener_tipo`, `altura_en`).
- Produces: `Canalizaciones.trazar_tramo(tipo, puntos_3d, mundo) -> Dictionary`, `Canalizaciones.generar_geometria_tramo(tipo, puntos_control, mundo) -> Dictionary` (celdas de ducto, columnas cada 5 vanos, esquinas, pendientes diagonales, cruces a desnivel $Y+5$).

- [ ] **Step 1: Write the failing test**

Crear `godot/scripts/CanalizacionesTest.gd` con casos que validen:
1. Catálogo de canalizaciones (`acueducto` vs `tuberia` y fluidos permitidos).
2. Cálculo de columnas: cada 5 bloques (vano libre de 4), esquinas de 90° y extremos.
3. Cruce a desnivel: detección de intersección con canalización existente y elevación a $Y+5$.
4. Pendientes: trazado diagonal entre cimas de columnas separadas por 4 bloques de vano.

- [ ] **Step 2: Run test to verify it fails**

Run: `tools/run-godot-tests.ps1`
Expected: FAIL porque `Canalizaciones.gd` no existe.

- [ ] **Step 3: Write minimal implementation**

Implementar `Canalizaciones.gd`:
- `TIPOS = { "acueducto": { ... }, "tuberia": { ... } }`
- `calcular_geometria_tramo(...)`
- `registrar_tramo(...)`
- `obtener_red_de_celda(...)`
- Autoload en `godot/project.godot`.

- [ ] **Step 4: Run test to verify it passes**

Run: `tools/run-godot-tests.ps1`
Expected: PASS en `CanalizacionesTest.tscn`.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Canalizaciones.gd godot/scripts/CanalizacionesTest.gd godot/scenes/CanalizacionesTest.tscn godot/project.godot
git commit -m "feat: implement Canalizaciones autoload and geometry generation"
```

---

### Task 3: Conexión con Puertos y Validación de Despeje

**Files:**
- Modify: `godot/scripts/VoxelWorld.gd:475-535`
- Modify: `godot/scripts/Canalizaciones.gd`
- Test: `godot/scripts/CanalizacionesTest.gd`
- Test: `godot/scripts/BlueprintValidatorTest.gd`

**Interfaces:**
- Consumes: `VoxelWorld.calcular_despeje()`, `VoxelWorld.despeje_bloqueado()`, `VoxelWorld.es_puerto()`, `VoxelWorld.recurso_de_puerto()`.
- Produces: Permiso para que celdas de ducto compatibles ocupen la celda de despeje exterior del puerto, y detección de conexión puerto-red en `Canalizaciones`.

- [ ] **Step 1: Write the failing test**

En `CanalizacionesTest.gd`:
1. Probar que una tubería de acero en la celda exterior de `puerto_crudo_out` es aceptada.
2. Probar que un acueducto en la celda exterior de `puerto_crudo_out` es rechazado por incompatibilidad.
3. Probar que conectar una línea entre `puerto_agua_out` y `puerto_crudo_in` es rechazado.

- [ ] **Step 2: Run test to verify it fails**

Run: `tools/run-godot-tests.ps1`
Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

En `VoxelWorld.gd`:
- En `despeje_bloqueado()`: si la celda está ocupada por un bloque `acueducto` o `tuberia`, verificar compatibilidad con el recurso del puerto. Si es compatible, devolver `false` (no bloquea el despeje).
En `Canalizaciones.gd`:
- Implementar `conectar_puerto(celda_puerto, celda_ducto)` con verificación de recurso y dirección.

- [ ] **Step 4: Run test to verify it passes**

Run: `tools/run-godot-tests.ps1`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/VoxelWorld.gd godot/scripts/Canalizaciones.gd godot/scripts/CanalizacionesTest.gd
git commit -m "feat: enable duct connection to building ports in exterior clearance cells"
```

---

### Task 4: Simulación de Flujo Instantáneo, Red de Almacenes y Derrames

**Files:**
- Modify: `godot/scripts/Economia.gd:800-950`
- Modify: `godot/scripts/Canalizaciones.gd`
- Test: `godot/scripts/CanalizacionesTest.gd`
- Test: `godot/scripts/EconomiaTest.gd`

**Interfaces:**
- Consumes: `Economia._avanzar_produccion()`, `Economia.almacen_puesto()`, `VoxelWorld.colocar_bloque()`.
- Produces: Transferencia de fluidos por red, depósito en pool compartido de `almacen`, y generación de derrames (`colocar_bloque("agua"/"crudo"/"combustible")`) en extremos abiertos.

- [ ] **Step 1: Write the failing test**

En `CanalizacionesTest.gd` y `EconomiaTest.gd`:
1. Probar que `estacion_bombeo` bombea agua a través de un acueducto hacia un `almacen` y el stock de agua aumenta en la ciudad.
2. Probar que un segundo `almacen` distante entrega agua a una `central_termoelectrica` sin tubería física entre los dos almacenes.
3. Probar que bombear a una tubería abierta genera un derrame: coloca un bloque de fluido en el extremo y marca `derrame = true`.

- [ ] **Step 2: Run test to verify it fails**

Run: `tools/run-godot-tests.ps1`
Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

En `Canalizaciones.gd`:
- `simular_flujo(origen_puerto, recurso, cantidad, mundo)`:
  - Si hay camino a consumidor: transfiere al consumidor.
  - Si hay camino a `almacen`: transfiere al pool global de fluidos de la ciudad (`Economia.reserva_fluidos`).
  - Si no hay destino: vierte líquido en el extremo abierto (`mundo.colocar_bloque(celda_derrame, recurso, true)`) y emite `derrame_detectado`.
En `Economia.gd`:
- Conectar ciclo de producción de bombas y extractores a `Canalizaciones.simular_flujo`.
- Gestionar entrega desde almacenes compartidos hacia consumidores conectados.

- [ ] **Step 4: Run test to verify it passes**

Run: `tools/run-godot-tests.ps1`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Economia.gd godot/scripts/Canalizaciones.gd godot/scripts/CanalizacionesTest.gd godot/scripts/EconomiaTest.gd
git commit -m "feat: implement fluid flow simulation, shared warehouses and spills"
```

---

### Task 5: Herramienta de Trazado de Ductos en UI (`BarraModos` y `CamaraCenital`)

**Files:**
- Modify: `godot/scripts/BarraModos.gd:50-105`
- Modify: `godot/scripts/CamaraCenital.gd:1600-2400`
- Test: `godot/scripts/HUDTest.gd`
- Test: `godot/scripts/CamaraCenitalModosTest.gd`

**Interfaces:**
- Consumes: `BarraModos` categoría 6 `ductos`, atajos `1-6-1` y `1-6-2`.
- Produces: Modo `modo_trazar_ducto` con interactividad de clic, previsualización 3D a $Y_{suelo}+4$, cálculo de materiales en HUD y confirmación/cancelación.

- [ ] **Step 1: Write the failing test**

En `HUDTest.gd` y `CamaraCenitalModosTest.gd`:
1. Probar que presionar `6` abre la categoría "Ductos".
2. Probar que seleccionar `1-6-1` activa modo trazar Acueducto y `1-6-2` Tubería.
3. Probar que el HUD muestra la ficha técnica con costo de materiales.

- [ ] **Step 2: Run test to verify it fails**

Run: `tools/run-godot-tests.ps1`
Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

En `BarraModos.gd`:
- Agregar `["ductos", "Ductos", "6"]` a `CATEGORIAS`.
- Agregar `"ductos": [ ["acueducto", "Acueducto", "1"], ["tuberia", "Tubería", "2"] ]` a `CONSTRUCCIONES_POR_CATEGORIA`.
En `CamaraCenital.gd`:
- Manejar entrada a `_alternar_modo_trazar_ducto(tipo)`.
- Previsualizar tramo elevado a $Y+4$ con columnas y ficha en HUD.
- Al confirmar (doble clic o clic en destino): cobrar materiales en `Ciudad.almacen` y llamar a `Canalizaciones.construir_tramo()`.

- [ ] **Step 4: Run test to verify it passes**

Run: `tools/run-godot-tests.ps1`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/BarraModos.gd godot/scripts/CamaraCenital.gd godot/scripts/HUDTest.gd godot/scripts/CamaraCenitalModosTest.gd
git commit -m "feat: add duct tracing tool in build menu 6-1 and 6-2 with live preview"
```

---

### Task 6: Estado de Puertos en `PanelPuesto` y Verificación Final de la Suite

**Files:**
- Modify: `godot/scripts/PanelPuesto.gd`
- Test: `godot/scripts/HUDTest.gd`
- Test: `tools/run-godot-tests.ps1` (suite completa)

**Interfaces:**
- Consumes: `Canalizaciones.estado_de_puerto(celda) -> Dictionary` (`"conectado"`, `"desconectado"`, `"derrame"`).
- Produces: Indicador visual en `PanelPuesto` para cada puerto del edificio seleccionado.

- [ ] **Step 1: Write the failing test**

En `HUDTest.gd`:
Probar que al abrir `PanelPuesto` de un puesto con puertos, se listan sus puertos con sus estados respectivos (verde/gris/rojo).

- [ ] **Step 2: Run test to verify it fails**

Run: `tools/run-godot-tests.ps1`
Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

En `PanelPuesto.gd`:
Consultar `Canalizaciones.estado_de_puerto(celda_puerto)` y renderizar las etiquetas correspondientes con colores representativos.

- [ ] **Step 4: Run full test suite to verify everything passes**

Run: `tools/run-godot-tests.ps1`
Expected: ALL test scenes PASS with 0 errors.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/PanelPuesto.gd godot/scripts/HUDTest.gd
git commit -m "feat: display fluid port status in PanelPuesto and verify full test suite"
```

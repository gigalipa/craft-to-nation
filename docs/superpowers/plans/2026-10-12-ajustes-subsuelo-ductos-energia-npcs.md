# Plan de Implementación: Ajustes de Subsuelo, Fluidos, Canalizaciones, Balance Energético y Pathfinding

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Implementar los ajustes de físicas de fluidos, cruces a desnivel y extensión de ductos, logística de carbón para centrales eléctricas, partición de almacén en refinerías, modal interactivo de energía y pathfinding ponderado por tipo de vía.

**Architecture:** Modificaciones incrementales y modulares sobre los autoloads y controladores existentes (`Player.gd`, `VoxelWorld.gd`, `Canalizaciones.gd`, `CamaraCenital.gd`, `Economia.gd`, `Colonos.gd`, `BarraSuperior.gd`, `HUD.gd`, `VentanaEnergia.gd`, `Vias.gd`, `BuscadorRutas.gd`), apoyadas en suites de tests automatizados unitarios y de integración para cada componente.

**Tech Stack:** Godot Engine 4 (GDScript), GridMap, StaticBody3D / SurfaceTool, A* (AStar3D / custom pathfinding), HUD en CanvasLayer / Control.

**Spec:** [`docs/superpowers/specs/2026-10-12-ajustes-subsuelo-ductos-energia-npcs-design.md`](file:///c:/Users/peraz/Projects/Misc/CityCraft/docs/superpowers/specs/2026-10-12-ajustes-subsuelo-ductos-energia-npcs-design.md)

## Global Constraints
- Rama de trabajo exclusiva: `feature/subsuelo-bloques` en `.worktrees/subsuelo-bloques`.
- Toda prueba se ejecuta vía `powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1` y debe mantener las 28 suites de pruebas 100% en verde.
- No agregar dependencias externas ni librerías adicionales.
- Respetar los estilos visuales de `TemaHUD` para todas las ventanas y modales.
- Preservar la arquitectura modular de 4 piezas de ductos recientemente implementada.

## Review Focus
1. **Drenado de fluidos sobre fuentes naturales vs derrames:** Colocar un bloque sólido destruye el líquido en esa celda sin corromper el GridMap ni dejar colisiones fantasma.
2. **Inundación al minar bloques colindantes a agua:** Al retirar un bloque que toca agua en laterales o arriba, la celda se llena de agua sin provocar cascadas infinitas o desbordes no deseados.
3. **Cruce a desnivel a $Y_{suelo}+6$:** Los tramos inclinados ascienden 2 cotas limpiamente y la celda vertical intermedia $Y_{suelo}+5$ queda vacía de aire sin solapar con el ducto inferior a $Y_{suelo}+4$.
4. **Topología multi-entrada / salida única:** Una red puede recibir fluidos de múltiples extractores, pero el flujo debe dirigirse hacia un único puerto receptor de destino sin bucles de derrame falsos.
5. **Pathfinding y pendientes moderadas:** El coste de terreno natural (8) vs vía (3) debe guiar a los colonos por la vía sin que un escalón de 1 bloque los obligue a dar rodeos absurdos.

---

### Task 1: Físicas y Fluidos - Viscosidad de Crudo y Spreading Multi-Líquido

**Files:**
- Modify: `godot/scripts/Player.gd:15-35, 140-165`
- Modify: `godot/scripts/VoxelWorld.gd:180-220`
- Test: `godot/scripts/PlayerNatacionTest.gd`
- Test: `godot/scripts/TranslucidosRendererTest.gd`

**Interfaces:**
- Consumes: `Player.FACTOR_VISCOSIDAD_CRUDO`, `VoxelWorld.TIPOS_LIQUIDOS`.
- Produces: `Player.FACTOR_VISCOSIDAD_CRUDO = 0.20`, impulso de salto al 20%, y propagación horizontal diferenciada (agua 7, combustible 5, crudo 3).

- [x] **Step 1: Escribir test fallido para viscosidad de crudo y alcances de spreading**
  En `PlayerNatacionTest.gd`, verificar que `Player.FACTOR_VISCOSIDAD_CRUDO == 0.20` y que el impulso de salto sea `VELOCIDAD_SALTO * 0.20`.
  En `TranslucidosRendererTest.gd`, verificar los alcances máximos por tipo de líquido.

- [x] **Step 2: Ejecutar test para comprobar fallo**
  Run: `powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1`
  Expected: FAIL con `assert(FACTOR_VISCOSIDAD_CRUDO == 0.20)`

- [x] **Step 3: Implementar código mínimo en `Player.gd` y `VoxelWorld.gd`**
  En `Player.gd`:
  - Modificar `const FACTOR_VISCOSIDAD_CRUDO := 0.20`.
  - En `_physics_process()`, cuando está en crudo, multiplicar la velocidad de salto por `FACTOR_VISCOSIDAD_CRUDO`.
  En `VoxelWorld.gd`:
  - Generalizar `_procesar_frente_escurrimiento()` usando `ALCANCE_FLUJO_AGUA = 7`, `ALCANCE_FLUJO_COMBUSTIBLE = 5`, `ALCANCE_FLUJO_CRUDO = 3`.

- [x] **Step 4: Ejecutar test para verificar que pase**
  Run: `powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1`
  Expected: PASS

- [x] **Step 5: Commit**
  ```bash
  git add godot/scripts/Player.gd godot/scripts/VoxelWorld.gd godot/scripts/PlayerNatacionTest.gd godot/scripts/TranslucidosRendererTest.gd
  git commit -m "feat(fluidos): viscosidad densa de crudo y spreading diferenciado por liquido"
  ```

---

### Task 2: Drenado por Bloque Sólido e Inundación al Minar (Minecraft-style)

**Files:**
- Modify: `godot/scripts/VoxelWorld.gd:470-520, 960-1010`
- Test: `godot/scripts/TranslucidosRendererTest.gd`

**Interfaces:**
- Consumes: `VoxelWorld.colocar_bloque()`, `VoxelWorld.minar_bloque()`.
- Produces: Desalojo inmediato de líquidos al colocar sólidos e inundación de agua al retirar sólidos que tocan agua.

- [x] **Step 1: Escribir test fallido para desalojo e inundación**
  En `TranslucidosRendererTest.gd`, añadir pruebas donde:
  1. Se coloca un bloque de piedra sobre una celda con crudo o agua; el líquido desaparece y queda piedra.
  2. Se mina un bloque de piedra que tiene agua en un lateral o encima; la celda se convierte inmediatamente en agua.

- [x] **Step 2: Ejecutar test para comprobar fallo**
  Run: `powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1`
  Expected: FAIL (bloque no se coloca sobre líquido o celda queda vacía en vez de agua).

- [x] **Step 3: Implementar desalojo e inundación en `VoxelWorld.gd`**
  - En `colocar_bloque()`: si la celda contenía líquido (`TIPOS_LIQUIDOS.has(tipo_anterior)`) y se coloca un bloque no líquido, reemplazar la celda, destruir el líquido y emitir `bloque_translucido_cambiado.emit(celda)`.
  - En `minar_bloque()` / `_retirar_bloque()`: al vaciar una celda, revisar vecinos laterales y superior; si alguno es `"agua"`, colocar `"agua"` en la celda vaciada.

- [x] **Step 4: Ejecutar test para verificar que pase**
  Run: `powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1`
  Expected: PASS

- [x] **Step 5: Commit**
  ```bash
  git add godot/scripts/VoxelWorld.gd godot/scripts/TranslucidosRendererTest.gd
  git commit -m "feat(terreno): desalojo de liquidos por bloques solidos e inundacion estilo minecraft"
  ```

---

### Task 3: Ficha Técnica Legible, Texturizado UV y Demolición Limpia de Ductos

**Files:**
- Modify: `godot/scripts/Canalizaciones.gd:210-240, 800-870`
- Test: `godot/scripts/CanalizacionesTest.gd`

**Interfaces:**
- Consumes: `Canalizaciones.ficha_tecnica()`, `Canalizaciones.quitar_celdas()`.
- Produces: `nombre_recurso_legible()`, UVs longitudinales repetidos y remoción completa en GridMap / colisionadores.

- [x] **Step 1: Escribir test fallido en `CanalizacionesTest.gd`**
  - Probar que `ficha_tecnica()` devuelva `"Bloque de acero"` en vez de `"bloque_acero"`.
  - Probar que `quitar_celdas()` vacíe la celda física del GridMap (`INVALID_CELL_ITEM`) y elimine los nodos `StaticBody3D` (`DuctoTramo`).

- [x] **Step 2: Ejecutar test para comprobar fallo**
  Run: `powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1`
  Expected: FAIL

- [x] **Step 3: Implementar cambios en `Canalizaciones.gd`**
  - Agregar `static func nombre_recurso_legible(clave: String) -> String`.
  - Ajustar formato de texto en `ficha_tecnica()`.
  - En `construir_tramo()`, calcular `uv.x` escalado por `len_total`.
  - En `quitar_celdas()`, llamar a `mundo.set_cell_item(c, GridMap.INVALID_CELL_ITEM)`, limpiar `celdas_pagadas`, `colocado_por_jugador`, `celda_sobre_techo` y destruir nodos en `nodos_diagonales[id]`.

- [x] **Step 4: Ejecutar test para verificar que pase**
  Run: `powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1`
  Expected: PASS

- [x] **Step 5: Commit**
  ```bash
  git add godot/scripts/Canalizaciones.gd godot/scripts/CanalizacionesTest.gd
  git commit -m "feat(canalizaciones): formato legible en ficha tecnica, UV repetido y demolicion limpia"
  ```

---

### Task 4: Cruces a Desnivel a $Y_{suelo}+6$ y Extensión de Red Multi-Entrada

**Files:**
- Modify: `godot/scripts/Canalizaciones.gd:520-640`
- Modify: `godot/scripts/CamaraCenital.gd:2200-2350`
- Test: `godot/scripts/CanalizacionesTest.gd`

**Interfaces:**
- Consumes: `Canalizaciones.calcular_geometria_tramo()`, `Canalizaciones.construir_tramo()`, `CamaraCenital._iniciar_trazo_ducto()`.
- Produces: Cruces con doble columna a $Y=5$ y ducto a $Y=6$ con despeje de aire a $Y=5$. Soporte de multi-entrada y extensión de red existente.

- [x] **Step 1: Escribir test fallido para cruces a $Y=6$ y extensión de red**
  En `CanalizacionesTest.gd`:
  - Test de cruce a desnivel: ducto elevado a $Y=6$, dos columnas en adyacentes a $Y=5$, celda central $Y=5$ vacía.
  - Test de extensión: extender red existente mantiene `id_red` y cancela derrame activo al llegar a un puerto receptor.
  - Test de topología multi-entrada: dos extractores vierten a una misma tubería que llega a un único almacén.

- [x] **Step 2: Ejecutar test para comprobar fallo**
  Run: `powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1`
  Expected: FAIL

- [x] **Step 3: Implementar cruces a $Y=6$ y extensión en `Canalizaciones.gd` y `CamaraCenital.gd`**
  - En `calcular_geometria_tramo()`: al detectar cruce sobre ducto existente a $Y_{suelo}+4$, generar columnas en $idx - 1$ e $idx + 1$ hasta $Y_{suelo}+5$, colocar bloques de ducto a $Y_{suelo}+6$, y dejar $Y_{suelo}+5$ libre.
  - En `CamaraCenital.gd`: al hacer clic sobre una columna/ducto de una red existente, vincular `_red_origen_extension`.
  - En `Canalizaciones.gd`: permitir múltiples entradas hacia una única salida en `destinos_de_puerto_salida()`.

- [x] **Step 4: Ejecutar test para verificar que pase**
  Run: `powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1`
  Expected: PASS

- [x] **Step 5: Commit**
  ```bash
  git add godot/scripts/Canalizaciones.gd godot/scripts/CamaraCenital.gd godot/scripts/CanalizacionesTest.gd
  git commit -m "feat(canalizaciones): cruces sobre-elevados a Y+6 y extension de red multi-entrada"
  ```

---

### Task 5: Logística de Carbón para Central Termoeléctrica y Partición de Refinería

**Files:**
- Modify: `godot/scripts/Colonos.gd:400-470`
- Modify: `godot/scripts/Economia.gd:220-270`
- Modify: `godot/scripts/CadenaMinerales.gd:150-180`
- Test: `godot/scripts/EconomiaTest.gd`
- Test: `godot/scripts/CadenaMineralesTest.gd`

**Interfaces:**
- Consumes: `Colonos._decidir_trabajo()`, `Economia.inventario_puestos`, `CadenaMinerales.refineria_petrolera`.
- Produces: Acarreo de 150 carbón a la central (reserva 500), y partición 400 crudo / 600 combustible en refinería.

- [x] **Step 1: Escribir test fallido para acarreo de carbón y partición de refinería**
  En `EconomiaTest.gd`: verificar que un colono acarreador cargue 150 de carbón hacia la central si stock < 500.
  En `CadenaMineralesTest.gd`: verificar que la refinería no admita más de 400 unidades de crudo en su almacén de 1000.

- [x] **Step 2: Ejecutar test para comprobar fallo**
  Run: `powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1`
  Expected: FAIL

- [x] **Step 3: Implementar lógica de acarreo y límites de refinería**
  - En `Colonos.gd`: si el puesto es `central_termoelectrica` y modo es `"carbon"`, buscar carbón en almacén más cercano y transportarlo a la central si `stock < 500`.
  - En `CadenaMinerales.gd` / `Economia.gd`: restringir stock de insumo crudo a máximo 400 en `refineria_petrolera`.

- [x] **Step 4: Ejecutar test para verificar que pase**
  Run: `powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1`
  Expected: PASS

- [x] **Step 5: Commit**
  ```bash
  git add godot/scripts/Colonos.gd godot/scripts/Economia.gd godot/scripts/CadenaMinerales.gd godot/scripts/EconomiaTest.gd godot/scripts/CadenaMineralesTest.gd
  git commit -m "feat(economia): acarreo de carbon a termoeléctrica y particion 400/600 en refineria"
  ```

---

### Task 6: Botón "Energía" en Topbar y `VentanaEnergia` Modal Interactiva

**Files:**
- Modify: `godot/scripts/BarraSuperior.gd:40-80`
- Modify: `godot/scripts/HUD.gd:180-230`
- Create: `godot/scripts/VentanaEnergia.gd`
- Test: `godot/scripts/HUDTest.gd`

**Interfaces:**
- Consumes: `Energia.capacidad_total`, `Energia.demanda_total`, `BarraSuperior.dato_pedido`.
- Produces: `VentanaEnergia` modal con métricas, lista de generadores y consumidores, y navegación de cámara al hacer clic.

- [x] **Step 1: Escribir test fallido en `HUDTest.gd`**
  Probar que hacer clic en el botón de energía de la barra superior abra `VentanaEnergia` y que contenga los datos globales de energía.

- [x] **Step 2: Ejecutar test para comprobar fallo**
  Run: `powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1`
  Expected: FAIL

- [x] **Step 3: Crear `VentanaEnergia.gd` y conectar botón en `BarraSuperior.gd` y `HUD.gd`**
  - En `BarraSuperior.gd`: convertir el label `energia` en `Button` que emite `dato_pedido("energia")`.
  - Crear `VentanaEnergia.gd`: ventana modal centrada con `TemaHUD`, cerrable con `X`, `Esc` y `E`. Muestra balance global, generadores y consumidores.
  - Al presionar un generador/consumidor, mover la cámara a su posición y abrir su panel respectivo.
  - En `HUD.gd`: instanciar y controlar visibilidad de `VentanaEnergia`.

- [x] **Step 4: Ejecutar test para verificar que pase**
  Run: `powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1`
  Expected: PASS

- [x] **Step 5: Commit**
  ```bash
  git add godot/scripts/BarraSuperior.gd godot/scripts/HUD.gd godot/scripts/VentanaEnergia.gd godot/scripts/HUDTest.gd
  git commit -m "feat(ui): boton de energia en topbar y ventana modal interactiva de energia"
  ```

---

### Task 7: Preferencia de Vías en Pathfinding con Catálogo y Desnivel Moderado

**Files:**
- Modify: `godot/scripts/Vias.gd:20-60`
- Modify: `godot/scripts/BuscadorRutas.gd:80-120`
- Test: `godot/scripts/BuscadorRutasTest.gd`

**Interfaces:**
- Consumes: `Vias.coste_paso_en()`, `BuscadorRutas.buscar_ruta()`.
- Produces: Coste de paso 3 en tierra pisada vs 8 en terreno natural, penalización +1 por bloque de altura.

- [x] **Step 1: Escribir test fallido en `BuscadorRutasTest.gd`**
  Crear un escenario donde un camino directo por campo traviesa compite con un camino ligeramente más largo por vía de tierra pisada; verificar que el A* elija el camino por la vía.

- [x] **Step 2: Ejecutar test para comprobar fallo**
  Run: `powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1`
  Expected: FAIL

- [x] **Step 3: Implementar ponderación en `Vias.gd` y `BuscadorRutas.gd`**
  - En `Vias.gd`: definir `COSTE_TERRENO_NATURAL = 8`, `coste_ruta = 3` para `tierra_pisada`, y helper `coste_paso_en(soporte)`.
  - En `BuscadorRutas.gd`: calcular coste vecino como `_costo[actual] + coste_superficie + absi(vecino.y - actual.y)`.

- [x] **Step 4: Ejecutar test para verificar que pase**
  Run: `powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1`
  Expected: PASS

- [x] **Step 5: Commit**
  ```bash
  git add godot/scripts/Vias.gd godot/scripts/BuscadorRutas.gd godot/scripts/BuscadorRutasTest.gd
  git commit -m "feat(pathfinding): preferencia de vias de tierra pisada con desnivel moderado"
  ```

---

## 4. Validación Final

Una vez completadas las 7 tareas:
- Ejecutar la suite completa de 28 pruebas: `powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1`.
- Confirmar que el 100% de las suites sigan en verde (0 fallos).

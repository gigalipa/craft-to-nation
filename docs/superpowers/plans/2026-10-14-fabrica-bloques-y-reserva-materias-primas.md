# Fábrica de Bloques y Reserva de Materias Primas Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar el edificio industrial "Fábrica de bloques" (`fabrica_bloques`) que multiplica `piedra` en `bloques_piedra` para la construcción, e integrar el sistema de control de reserva mínima de materia prima en refinerías (`reserva_insumo`) para evitar el agotamiento de insumos cívicos esenciales.

**Architecture:** La Fábrica de bloques se modela como una refinería de `CadenaMinerales` y `PlantillasPuesto` (5x6, `bloque_piedra`) que procesa `1 piedra -> 3 bloques_piedra`. `Ciudad.gd` consume prioritariamente `bloques_piedra` al pagar costes de `piedra`. `Economia.gd` incorpora `reserva_insumo` por puesto refinería, limitando el retiro de insumos por acarreadores en `insumos_a_cargar()`. `BarraModos.gd` y `PanelPuesto.gd` proveen la interfaz en el menú Industrial y el selector cíclico `[0, 50, 100, 250, 500]`.

**Tech Stack:** Godot Engine 4.7.2 (GDScript), headless test runner.

**Spec:** `docs/superpowers/specs/2026-10-14-fabrica-bloques-y-reserva-materias-primas-design.md`

## Global Constraints

- Todas las 28 escenas de prueba existentes deben mantenerse en verde sin regresiones.
- La ejecución en headless se realiza mediante: `powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot scenes/<TestScene>.tscn"`.
- Los archivos deben mantener tipado estático estricto de GDScript (`Vector2i`, `Vector3i`, `Dictionary`, `float`, etc.).
- Sin dependencias externas ni código no solicitado (Ponytail mode: minimal diffs, boring over clever).

## Execution Lines & Dependency Matrix

Analizando la intersección de archivos y estado compartido:

- **Línea A (Recetas, Plantilla y Recursos - Secuencial, 1 agente):**
  - **Tareas:** Task 1 $\to$ Task 2.
  - **Archivos:** `godot/scripts/PlantillasPuesto.gd`, `godot/scripts/CadenaMinerales.gd`, `godot/scripts/Ciudad.gd`, `godot/scripts/PlantillasPuestoTest.gd`, `godot/scripts/CadenaMineralesTest.gd`, `godot/scripts/CiudadTest.gd`.
  - **Modelo recomendado:** `Model: 'pro'` / Claude Sonnet 5.5 (Medium/High).
  - **Comprobación local:** `PlantillasPuestoTest.tscn`, `CadenaMineralesTest.tscn`, `CiudadTest.tscn`.

- **Línea B (Logística y Reserva de Insumos - Independiente en Paralelo):**
  - **Tareas:** Task 3.
  - **Archivos:** `godot/scripts/Economia.gd`, `godot/scripts/EconomiaTest.gd`.
  - **Modelo recomendado:** `Model: 'pro'` / Claude Sonnet 5.5 (Medium).
  - **Comprobación local:** `EconomiaTest.tscn`.

- **Línea C (HUD, Menú y Controles en Paneles - Independiente en Paralelo):**
  - **Tareas:** Task 4.
  - **Archivos:** `godot/scripts/BarraModos.gd`, `godot/scripts/PanelPuesto.gd`, `godot/scripts/HUDTest.gd`, `godot/scripts/PuestosPrevisualizacionTest.gd`.
  - **Modelo recomendado:** `Model: 'flash'` / Gemini 3.8 Flash (Low/Medium - ahorro de cuota).
  - **Comprobación local:** `HUDTest.tscn`, `PuestosPrevisualizacionTest.tscn`.

- **Global Integration Test:** `powershell -File tools/run-godot-tests.ps1` (ejecutado por el orquestador principal al finalizar las 3 líneas).

## Review Focus

1. `Ciudad.consumir_costo("piedra", monto)` con `bloques_piedra` parciales: verificar que descuenta primero todos los bloques y el remanente exacto de piedra cruda.
2. `insumos_a_cargar()` con stock central menor o igual a `reserva_insumo`: verificar que devuelve 0 para ese insumo, evitando que el acarreador viaje o retire insumos.
3. Compatibilidad de `fabrica_bloques` con `Economia.es_refineria()` y asignación de personal obrero/técnico.
4. Renderizado y navegación en `BarraModos.gd`: tecla de atajo en menú industrial y miniatura 3D sin acumulación de SubViewports.
5. Emisión de partículas de humo/polvo en chimenea de `fabrica_bloques` en `HumoRefinerias.gd`.

---

## Task Structure

### Task 1: Plantilla y Receta de Fábrica de Bloques

**Files:**
- Modify: `godot/scripts/PlantillasPuesto.gd:50-130`
- Modify: `godot/scripts/CadenaMinerales.gd:10-40`
- Modify: `godot/scripts/PlantillasPuestoTest.gd`
- Modify: `godot/scripts/CadenaMineralesTest.gd`

**Interfaces:**
- Produces: `PlantillasPuesto.PLANTILLAS["fabrica_bloques"]`, `CadenaMinerales.RECETAS["fabrica_bloques"]`, `CadenaMinerales.REFINERIAS["fabrica_bloques"]`.

- [ ] **Step 1: Escribir tests que fallen para la plantilla y receta**
  En `PlantillasPuestoTest.gd`, verificar que `PlantillasPuesto.dimensiones("fabrica_bloques") == Vector2i(5, 6)`, tiene material base `"bloque_piedra"`, entrada `e`, salida `s`, baúl `B` y chimenea en `Vector2i(2, 3)`.
  En `CadenaMineralesTest.gd`, verificar que `RECETAS["fabrica_bloques"]` tiene entrada `piedra: 1`, salida `bloques_piedra: 3`, tasa `0.5`, y `REFINERIAS["fabrica_bloques"] == "fabrica_bloques"`.

- [ ] **Step 2: Ejecutar tests y confirmar fallo**
  Run: `powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot scenes/PlantillasPuestoTest.tscn"`
  Run: `powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot scenes/CadenaMineralesTest.tscn"`

- [ ] **Step 3: Implementar plantilla y receta**
  En `PlantillasPuesto.gd`:
  - En `MATERIAL_BASE_POR_TIPO`: `"fabrica_bloques": "bloque_piedra"`.
  - En `PLANTILLAS`: agregar entrada `"fabrica_bloques"` con huella 5x6 (losa, puerta entrada `e/E`, salida `s/S`, baúl `B`, ventanas `V` y chimenea `Vector2i(2, 3)`).
  En `CadenaMinerales.gd`:
  - En `RECETAS`: agregar `"fabrica_bloques": {"entradas": {"piedra": 1}, "tipo_salida": "bloques_piedra", "cantidad_salida": 3, "tasa_base": 0.5, "energia_por_lote": 0}`.
  - En `REFINERIAS`: agregar `"fabrica_bloques": "fabrica_bloques"`.

- [ ] **Step 4: Ejecutar tests y confirmar que pasan**
  Run: `powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot scenes/PlantillasPuestoTest.tscn"`
  Run: `powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot scenes/CadenaMineralesTest.tscn"`

---

### Task 2: Recurso "bloques_piedra" y Pago Prioritario en Ciudad

**Files:**
- Modify: `godot/scripts/Ciudad.gd:230-280, 390-410`
- Modify: `godot/scripts/CiudadTest.gd`

**Interfaces:**
- Consumes: `"bloques_piedra"` de Task 1.
- Produces: `Ciudad.almacen["bloques_piedra"]`, `Ciudad.consumir_costo()` pagando `piedra` primero con `bloques_piedra`.

- [ ] **Step 1: Escribir tests que fallen en CiudadTest.gd**
  Verificar que `Ciudad.almacen` contiene `"bloques_piedra"`, que `almacen_general()` suma `piedra` y `bloques_piedra`, y que al solicitar pagar `piedra: 10` teniendo 6 `bloques_piedra` y 10 `piedra`, se descuentan los 6 `bloques_piedra` y 4 de `piedra`.

- [ ] **Step 2: Ejecutar test y confirmar fallo**
  Run: `powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot scenes/CiudadTest.tscn"`

- [ ] **Step 3: Implementar soporte de bloques_piedra en Ciudad.gd**
  En `Ciudad.gd`:
  - En `almacen`: `"bloques_piedra": Recurso.new("Bloques de piedra", 0, LIMITE_BASE)`.
  - En `consumir_costo()`: añadir lógica para `recurso == "piedra"` similar a `"madera"` / `"tablas"`:
    ```gdscript
    var bloques: Recurso = almacen["bloques_piedra"]
    if bloques.cantidad + piedra.cantidad < monto:
        return {}
    var de_bloques: float = minf(bloques.cantidad, monto)
    var de_piedra: float = monto - de_bloques
    bloques.cantidad -= de_bloques
    piedra.cantidad -= de_piedra
    if de_bloques > 0.0:
        desglose["bloques_piedra"] = de_bloques
    if de_piedra > 0.0:
        desglose["piedra"] = de_piedra
    ```
  - En `almacen_general()`: si `recurso == "piedra"` y tiene `"bloques_piedra"`, sumar su cantidad.

- [ ] **Step 4: Ejecutar test y confirmar que pasa**
  Run: `powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot scenes/CiudadTest.tscn"`

---

### Task 3: Modelo y Lógica de Reserva de Insumos en Economia

**Files:**
- Modify: `godot/scripts/Economia.gd:310-330, 1050-1090`
- Modify: `godot/scripts/EconomiaTest.gd`

**Interfaces:**
- Produces: `Economia.obtener_reserva_insumo(esquina)`, `Economia.establecer_reserva_insumo(esquina, valor)`, `Economia.ciclar_reserva_insumo(esquina)`.

- [ ] **Step 1: Escribir tests que fallen en EconomiaTest.gd**
  Test para refinería (ej. siderúrgica con insumo hierro, o aserradero con madera, o fabrica_bloques con piedra):
  - Verificar que `obtener_reserva_insumo()` devuelve 0.0 por defecto.
  - Verificar que `ciclar_reserva_insumo()` conmuta `0 -> 50 -> 100 -> 250 -> 500 -> 0`.
  - Con stock de hierro en ciudad = 80 y reserva = 100: verificar que `insumos_a_cargar()` devuelve `{}` (no extrae nada).
  - Con stock de hierro en ciudad = 150 y reserva = 100: verificar que `insumos_a_cargar()` extrae como máximo 50 (150 - 100).

- [ ] **Step 2: Ejecutar test y confirmar fallo**
  Run: `powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot scenes/EconomiaTest.tscn"`

- [ ] **Step 3: Implementar reserva_insumo en Economia.gd**
  En `Economia.gd`:
  - Constante: `const VALORES_RESERVA_INSUMO: Array[float] = [0.0, 50.0, 100.0, 250.0, 500.0]`
  - Al registrar puesto de tipo refinería en `registrar_puesto()`: inicializar `p["reserva_insumo"] = 0.0`.
  - Helpers:
    - `func obtener_reserva_insumo(esquina: Vector2i) -> float`
    - `func establecer_reserva_insumo(esquina: Vector2i, valor: float) -> void`
    - `func ciclar_reserva_insumo(esquina: Vector2i) -> float`
  - En `insumos_a_cargar(esquina: Vector2i)`:
    Calcular el stock disponible para refinar restando la reserva configurada:
    ```gdscript
    var reserva: float = p.get("reserva_insumo", 0.0)
    var stock_disponible: float = maxf(0.0, ciudad.almacen[recurso].cantidad - reserva)
    var cantidad: float = minf(minf(CAPACIDAD_CARGA * parte, espacio), stock_disponible)
    ```

- [ ] **Step 4: Ejecutar test y confirmar que pasa**
  Run: `powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot scenes/EconomiaTest.tscn"`

---

### Task 4: UI Menú Industrial, Previsualización y Control en PanelPuesto

**Files:**
- Modify: `godot/scripts/BarraModos.gd:80-120`
- Modify: `godot/scripts/PanelPuesto.gd:20-60, 120-200`
- Modify: `godot/scripts/HumoRefinerias.gd:60`
- Modify: `godot/scripts/HUDTest.gd`
- Modify: `godot/scripts/PuestosPrevisualizacionTest.gd`

**Interfaces:**
- Consumes: `PlantillasPuesto.PLANTILLAS["fabrica_bloques"]`, `Economia.ciclar_reserva_insumo()`.
- Produces: Botón `fabrica_bloques` en submenú Industrial, botón cíclico de reserva en `PanelPuesto`.

- [ ] **Step 1: Escribir tests que fallen en HUDTest.gd y PuestosPrevisualizacionTest.gd**
  En `HUDTest.gd`: verificar que el menú Industrial incluye `fabrica_bloques`, y que al inspeccionar una refinería en `PanelPuesto`, existe el botón `btn_reserva_insumo` que muestra el valor de reserva y reacciona al clic.
  En `PuestosPrevisualizacionTest.gd`: verificar que `_evaluar_puesto` evalúa y previsualiza `fabrica_bloques` correctamente.

- [ ] **Step 2: Ejecutar tests y confirmar fallo**
  Run: `powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot scenes/HUDTest.tscn"`
  Run: `powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot scenes/PuestosPrevisualizacionTest.tscn"`

- [ ] **Step 3: Implementar adición a BarraModos y control en PanelPuesto**
  En `BarraModos.gd`:
  - En `SUBMENUS["industrial"]`: agregar `["fabrica_bloques", "Fábrica de bloques", "4"]` y reenumerar del 1 al 9.
  - En `TIPOS_CON_MINIATURA`: agregar `"fabrica_bloques"`.
  En `HumoRefinerias.gd`:
  - Incluir `"fabrica_bloques"` para emitir humo/polvo en su chimenea.
  En `PanelPuesto.gd`:
  - Si `Economia.es_refineria(_esquina_activa)`:
    - Crear fila con Label `"Reserva en almacén:"` y Button `btn_reserva`.
    - Al presionar, llamar a `Economia.ciclar_reserva_insumo(_esquina_activa)` y actualizar el texto del botón `"[ %d ]" % int(reserva)`.

- [ ] **Step 4: Ejecutar tests y confirmar que pasan**
  Run: `powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot scenes/HUDTest.tscn"`
  Run: `powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot scenes/PuestosPrevisualizacionTest.tscn"`

---

## Plan Self-Review Checklist

- [x] **Spec coverage:** ¿Cubre la Fábrica de bloques, receta, integración de `bloques_piedra` en `Ciudad.consumir_costo()`, modelo de reserva en `Economia.gd` y controles visuales en `BarraModos.gd` / `PanelPuesto.gd`? Sí, abarcado en Tasks 1-4.
- [x] **Placeholder scan:** Sin TBDs ni funciones vacías.
- [x] **Type consistency:** Métodos y tipos consistentes (`reserva_insumo` como `float`, `bloques_piedra` como `Recurso`).
- [x] **Review Focus:** Casos de pago mixto en Ciudad y protección contra desabastecimiento cubiertos.

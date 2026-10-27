# Plan de Implementación: Red Logística, Unidades de Transporte y Edificio de Fabricación Evolutivo

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar el sistema de logística avanzada y progresión de transporte de *Craft to Nation*: catálogo de unidades de acarreo (carretas, carros de caballos, camiones diésel, drones autónomos y trolebuses), edificio evolutivo `taller_transporte`, dinámica de arrastre lento por falta de insumos operativos, y restricción de circulación vial para vehículos pesados.

**Architecture:**
1. **Catálogo y Parque Móvil (`ajustes.gd`, `Ciudad.gd`):** Definición de las 6 unidades de transporte con sus capacidades ($150\text{ u} \to 1.800\text{ u}$), velocidades, consumos, eras mínimas, ciencias teóricas requeridas y costos en recursos reales (incluyendo `tierra` como vidrio/ventanas para camiones y trolebuses). La ciudad gestiona el inventario de vehículos disponibles y asignados (`parque_transporte_disponible` y `parque_transporte_asignado`).
2. **Dinámica de Movimiento y Acarreo (`Colonos.gd`, `Economia.gd`):** Los acarreadores toman la capacidad y velocidad de su vehículo asignado. Se descuentan insumos por segundo de viaje; si se agotan, entran en estado `RALENTIZADO` ($1.2\text{ m/s}$) sin perder la carga. Los drones operan con 0 tripulantes humanos.
3. **Restricción Vial (`BuscadorRutas.gd`):** Para vehículos con `exige_via = true`, las celdas sin carretera afirmada continua son intransitables.
4. **Edificio Evolutivo (`taller_transporte`):** Puesto industrial en Zona Industrial que evoluciona orgánicamente con el avance de Era de la ciudad y las tecnologías teóricas descubiertas (`Ciudad.ciencias_teoricas_descubiertas`), sin botones de mejora manuales de puestos periféricos.
5. **Interfaz de Usuario (`PanelPuesto.gd`, `BarraModos.gd`):** Selector de transporte en puestos periféricos y panel de fabricación en el `taller_transporte` con catálogo desbloqueado dinámicamente.

**Tech Stack:** Godot 4.3 (GDScript), A* Pathfinding (`BuscadorRutas.gd`), TemaHUD.

**Spec:** `docs/superpowers/specs/2026-10-26-logistica-unidades-transporte-spec.md`

---

## Global Constraints

- **Centralización:** Constantes numéricas en `godot/scripts/ajustes.gd` y textos visibles en `godot/scripts/strings.gd`.
- **Integridad de Inventario:** Armonizado con recursos reales del juego (`madera`, `tablas`, `hierro`, `acero`, `tierra` como base de vidrios/ventanas, `combustible`, `cobre`, `tierras_raras`, `comida`).
- **Resiliencia Operativa:** Sin roturas ni destrucción de unidades; el desabastecimiento provoca arrastre lento ($1.2\text{ m/s}$) temporal.
- **Autonomía de Drones:** El Dron de Carga no demanda ni consume tripulación humana (`cantidad_tripulacion = 0`), alimentándose exclusivamente de la red eléctrica ($3\text{ kW}$).
- **Evolución Orgánica:** El `taller_transporte` evoluciona sin menús de subida de nivel de puestos periféricos; su nombre y recetas disponibles se derivan reactivamente de `Ciudad.era_actual` y `Ciudad.ciencias_teoricas_descubiertas`.
- **Suite de Pruebas:** Las 28 suites de pruebas del proyecto (`tools/run-godot-tests.ps1`) deben mantenerse al 100% en verde tras cada tarea.

---

## Execution Lines & Dependency Matrix

- **Línea A (Catálogo & Parque Móvil):** Task 1 (Files: `ajustes.gd`, `strings.gd`, `Ciudad.gd`) — Local Test: `CiudadTest.tscn`.
- **Línea B (Acarreo, Insumos y Arrastre Lento):** Task 2 (Files: `Colonos.gd`, `Economia.gd`) — Local Test: `ColonosTest.tscn`, `EconomiaTest.tscn`.
- **Línea C (Restricción Vial en Pathfinding):** Task 3 (Files: `BuscadorRutas.gd`, `Colonos.gd`) — Local Test: `BuscadorRutasTest.tscn`.
- **Línea D (Edificio Evolutivo `taller_transporte`):** Task 4 (Files: `PlantillasPuesto.gd`, `BarraModos.gd`, `Recoleccion.gd`, `Economia.gd`) — Local Test: `PlantillasPuestoTest.tscn`, `EconomiaTest.tscn`.
- **Línea E (Cola de Ensamblaje y Asignación):** Task 5 (Files: `Economia.gd`, `Ciudad.gd`, `Colonos.gd`) — Local Test: `EconomiaTest.tscn`.
- **Línea F (Interfaz de Usuario):** Task 6 (Files: `PanelPuesto.gd`) — Local Test: `HUDTest.tscn`.
- **Global Integration Test:** `powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1`

---

## Review Focus

1. **Capacidad de Almacén vs Cargas Masivas (1800 u):** Al llegar un camión diésel de 1800 u a un almacén con solo 200 u de espacio libre, debe ingresar 200 u y retener el excedente en el vehículo sin perder recursos ni provocar desbordamiento.
2. **Oscilación y Agotamiento de Insumos:** Cuando el combustible o forraje llega exactamente a 0.0, la velocidad debe fijarse limpiamente en $1.2\text{ m/s}$ sin división por cero ni saltos erráticos.
3. **Demolición de Vía bajo un Vehículo Pesado en Tránsito:** Si una sección de carretera es demolida mientras un camión pesado la transita, la unidad debe cambiar a modo de arrastre lento o replanificar sin provocar cuelgues en el motor de búsqueda.
4. **Censo Laboral de Drones (0 Humanos):** Asignar y desasignar drones autónomos no debe restar ni sumar trabajadores al censo demográfico de obreros de la ciudad.
5. **Retorno de Vehículos al Demoler Puestos:** Si un puesto periférico con camiones o carretas asignadas es demolido, todos los vehículos deben volver inmediatamente a `Ciudad.parque_transporte_disponible`.

---

## Tareas de Implementación

### Task 1: Catálogo de Unidades y Parque Móvil de Transporte en `ajustes.gd`, `strings.gd` y `Ciudad.gd`

**Files:**
- Modify: `godot/scripts/ajustes.gd`
- Modify: `godot/scripts/strings.gd`
- Modify: `godot/scripts/Ciudad.gd`
- Test: `godot/scripts/CiudadTest.gd`

**Interfaces:**
- Produces: `Ajustes.TRANSPORTE_VELOCIDAD_RALENTIZADA_SIN_INSUMO` ($1.2$), `Ajustes.TRANSPORTE_CATALOGO_UNIDADES`.
- Produces: `Ciudad.parque_transporte_disponible: Dictionary`, `Ciudad.parque_transporte_asignado: Dictionary`.
- Produces: `Ciudad.registrar_vehiculo_disponible(tipo: String, cantidad: int = 1) -> void`.
- Produces: `Ciudad.retirar_vehiculo_disponible(tipo: String, cantidad: int = 1) -> bool`.
- Produces: `Strings.TRANSPORTE_NOMBRES`, `Strings.TRANSPORTE_ESTADOS`.

- [ ] **Step 1: Write failing test in `CiudadTest.gd` for transport constants and fleet pool**

```gdscript
	print("\n=== TEST 40: Catálogo de Transporte y Parque Móvil ===")
	assert(Ajustes.TRANSPORTE_VELOCIDAD_RALENTIZADA_SIN_INSUMO == 1.2)
	assert(Ajustes.TRANSPORTE_CATALOGO_UNIDADES.has("camion_diesel"))
	assert(Ajustes.TRANSPORTE_CATALOGO_UNIDADES["camion_diesel"]["capacidad"] == 1800.0)
	assert(Ajustes.TRANSPORTE_CATALOGO_UNIDADES["dron_carga"]["cantidad_tripulacion"] == 0)

	var ciu40: Node = CiudadScript.new()
	assert(ciu40.parque_transporte_disponible.get("camion_diesel", -1) == 0)
	ciu40.registrar_vehiculo_disponible("camion_diesel", 2)
	assert(ciu40.parque_transporte_disponible["camion_diesel"] == 2)
	assert(ciu40.retirar_vehiculo_disponible("camion_diesel", 1))
	assert(ciu40.parque_transporte_disponible["camion_diesel"] == 1)
```

- [ ] **Step 2: Run test to verify failure**

```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/CiudadTest.tscn"
```
Expected: FAIL (`TRANSPORTE_CATALOGO_UNIDADES` not found).

- [ ] **Step 3: Implement transport catalog and city fleet pool**

In `godot/scripts/ajustes.gd`:
- Define `TRANSPORTE_VELOCIDAD_RALENTIZADA_SIN_INSUMO = 1.2`.
- Define `TRANSPORTE_CATALOGO_UNIDADES` with all 6 units from spec Section 2.
In `godot/scripts/strings.gd`:
- Define localized vehicle names and UI messages.
In `godot/scripts/Ciudad.gd`:
- Declare `parque_transporte_disponible` and `parque_transporte_asignado`.
- Implement `registrar_vehiculo_disponible` and `retirar_vehiculo_disponible`.

- [ ] **Step 4: Run test to verify pass**

```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/CiudadTest.tscn"
```
Expected: PASS.

- [ ] **Step 5: Run full test suite**

```powershell
powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1
```
Expected: 28/28 OK.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/ajustes.gd godot/scripts/strings.gd godot/scripts/Ciudad.gd godot/scripts/CiudadTest.gd
git commit -m "feat(transporte): catalogo de unidades de transporte y gestion de parque movil"
```

---

### Task 2: Capacidad de Carga Dinámica, Insumos y Arrastre Lento en `Colonos.gd` y `Economia.gd`

**Files:**
- Modify: `godot/scripts/Colonos.gd`
- Modify: `godot/scripts/Economia.gd`
- Test: `godot/scripts/ColonosTest.gd`
- Test: `godot/scripts/EconomiaTest.gd`

**Interfaces:**
- Updates: `Colonos.gd` determines hauler vehicle type from its assigned post (`puesto.get("tipo_transporte", "acarreador_pie")`).
- Updates: `Colonos._completar_paso` applies vehicle speed, surface modifiers, and switches to `1.2 m/s` when required input (fuel/food/energy) is missing.
- Updates: `Economia.recoger`, `recoger_producto`, `cargar_carbon_*` accept dynamic capacity up to $1.800\text{ u}$.
- Updates: Autonomous drones (`dron_carga`) operate with 0 human crew and demand energy without altering worker census.

- [ ] **Step 1: Write failing tests for hauler capacities and slow drag without inputs**

In `godot/scripts/ColonosTest.gd`:
```gdscript
	print("\n=== TEST 27: Acarreadores con Vehículos y Modo Arrastre Lento ===")
	# Asignar un puesto con camion_diesel (capacidad 1800)
	var esq_puesto := Vector2i(30, 30)
	colonos_test.economia.registrar_puesto(esq_puesto, "siderurgica", 5, 5, {})
	colonos_test.economia.puestos[esq_puesto]["tipo_transporte"] = "camion_diesel"
	var col_id: int = colonos_test.agregar_colono("obrero", Vector3i(30, 1, 30))
	colonos_test.colonos[col_id]["trabajo"] = {"puesto": esq_puesto, "rol": "acarreador"}

	var cap_efectiva: float = colonos_test.capacidad_transporte_colono(col_id)
	assert(is_equal_approx(cap_efectiva, 1800.0))

	# Review Focus 2: Sin combustible, la velocidad cae a 1.2 m/s
	colonos_test.ciudad.almacen["combustible"].cantidad = 0.0
	var vel_ralentizada: float = colonos_test.velocidad_efectiva_colono(col_id)
	assert(is_equal_approx(vel_ralentizada, 1.2))

	# Con combustible disponible, recupera velocidad base (6.5 m/s)
	colonos_test.ciudad.almacen["combustible"].cantidad = 100.0
	var vel_normal: float = colonos_test.velocidad_efectiva_colono(col_id)
	assert(vel_normal >= 6.5)
```

In `godot/scripts/EconomiaTest.gd`:
```gdscript
	print("\n=== TEST 48: Recogida de Carga Masiva con Camión Diésel ===")
	var e48: Node = EconomiaScript.new()
	var esq48 := Vector2i(5, 5)
	e48.registrar_puesto(esq48, "siderurgica", 5, 5, {})
	e48.puestos[esq48]["almacen"]["acero"] = 2500.0
	var carga48: Dictionary = e48.recoger(esq48, 1800.0)
	assert(is_equal_approx(carga48["acero"], 1800.0))
	assert(is_equal_approx(e48.puestos[esq48]["almacen"]["acero"], 700.0))
```

- [ ] **Step 2: Run test to verify failure**

```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/ColonosTest.tscn"
```
Expected: FAIL.

- [ ] **Step 3: Implement dynamic hauling, input checks, and drag speed**

In `godot/scripts/Colonos.gd`:
- Implement `tipo_transporte_de_colono(colono_id: int) -> String`.
- Implement `capacidad_transporte_colono(colono_id: int) -> float`: looks up capacity in `Ajustes.TRANSPORTE_CATALOGO_UNIDADES`.
- In hauler pickup logic, replace hardcoded `economia.CAPACIDAD_CARGA` with `capacidad_transporte_colono(c["id"])`.
- Implement `velocidad_efectiva_colono(colono_id: int) -> float`:
  - Checks if unit requires input (`insumo_tipo`).
  - If required input is missing (warehouse has 0 or energy deficit), returns `Ajustes.TRANSPORTE_VELOCIDAD_RALENTIZADA_SIN_INSUMO` ($1.2$).
  - Otherwise returns `velocidad_base` adjusted by road surface and off-road penalty (`penalizacion_tierra`).
- In `_completar_paso()`, use `velocidad_efectiva_colono(c["id"])`.
- When unit is traveling with input consumption, deduct quota from city warehouse or local storage.
In `godot/scripts/Economia.gd`:
- Support dynamic capacity arguments across all `recoger`, `recoger_producto`, and `cargar_carbon_*` methods.

- [ ] **Step 4: Run test to verify pass**

```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/ColonosTest.tscn"
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/EconomiaTest.tscn"
```
Expected: PASS.

- [ ] **Step 5: Run full test suite**

```powershell
powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1
```
Expected: 28/28 OK.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/Colonos.gd godot/scripts/Economia.gd godot/scripts/ColonosTest.gd godot/scripts/EconomiaTest.gd
git commit -m "feat(transporte): capacidad de carga dinamica, consumo de insumos y arrastre lento"
```

---

### Task 3: Restricción Vial en Pathfinding para Vehículos Pesados en `BuscadorRutas.gd`

**Files:**
- Modify: `godot/scripts/BuscadorRutas.gd`
- Modify: `godot/scripts/Colonos.gd`
- Test: `godot/scripts/BuscadorRutasTest.gd`

**Interfaces:**
- Produces: `BuscadorRutas.es_transitable_para_vehiculo(celda: Vector3i, tipo_transporte: String) -> bool`.
- Enforces: If `Ajustes.TRANSPORTE_CATALOGO_UNIDADES[tipo]["exige_via"] == true`, cells without `Vias.es_via(soporte)` return false / non-traversable.

- [ ] **Step 1: Write failing test in `BuscadorRutasTest.gd` for heavy vehicle road restriction**

```gdscript
	print("\n=== TEST: Restricción de Carretera para Camiones Pesados ===")
	# Celda sobre terreno natural sin vía afirmada
	var celda_tierra := Vector3i(15, 1, 15)
	# Un colono a pie puede transitar sobre tierra
	assert(buscador.es_transitable(celda_tierra))
	# Un camión diésel no puede transitar sobre tierra sin vía
	assert(not buscador.es_transitable_para_transporte(celda_tierra, "camion_diesel"))

	# Si se coloca vía afirmada en el soporte
	vias_test.registrar_via(Vector3i(15, 0, 15), "tierra_pisada")
	assert(buscador.es_transitable_para_transporte(celda_tierra, "camion_diesel"))
```

- [ ] **Step 2: Run test to verify failure**

```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/BuscadorRutasTest.tscn"
```
Expected: FAIL (`es_transitable_para_transporte` not defined).

- [ ] **Step 3: Implement road requirement check in `BuscadorRutas.gd`**

In `godot/scripts/BuscadorRutas.gd`:
- Implement `es_transitable_para_transporte(celda: Vector3i, tipo_transporte: String, ignorar: Dictionary = {}) -> bool`:
  - If not `es_transitable(celda, ignorar)`: returns false.
  - If `tipo_transporte == ""` or not `Ajustes.TRANSPORTE_CATALOGO_UNIDADES.has(tipo_transporte)`: returns true.
  - If `Ajustes.TRANSPORTE_CATALOGO_UNIDADES[tipo_transporte].get("exige_via", false)`:
    - Checks `soporte = celda + Vector3i(0, -1, 0)`.
    - If `Vias == null or not Vias.es_via(soporte)`: returns false.
  - Returns true.
- In `_BusquedaAStar`:
  - Allow passing an optional `tipo_transporte` to filter neighbor traversal using `es_transitable_para_transporte`.
- In `Colonos.gd`:
  - When initiating a route for an acarreador with a vehicle, pass its transport type to pathfinding.

- [ ] **Step 4: Run test to verify pass**

```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/BuscadorRutasTest.tscn"
```
Expected: PASS.

- [ ] **Step 5: Run full test suite**

```powershell
powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1
```
Expected: 28/28 OK.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/BuscadorRutas.gd godot/scripts/Colonos.gd godot/scripts/BuscadorRutasTest.gd
git commit -m "feat(rutas): restriccion estricta de red vial para camiones pesados y trolebuses"
```

---

### Task 4: Edificio Evolutivo `taller_transporte` y Progresión por Era y Tecnologías

**Files:**
- Modify: `godot/scripts/Recoleccion.gd`
- Modify: `godot/scripts/PlantillasPuesto.gd`
- Modify: `godot/scripts/BarraModos.gd`
- Modify: `godot/scripts/CamaraCenital.gd`
- Modify: `godot/scripts/Economia.gd`
- Test: `godot/scripts/PlantillasPuestoTest.gd`
- Test: `godot/scripts/EconomiaTest.gd`

**Interfaces:**
- Produces: Registration of `"taller_transporte"` across building catalogs.
- Produces: `Economia.obtener_nombre_evolutivo_taller(esquina: Vector2i) -> String`.
- Produces: `Economia.vehiculos_fabricables_en_taller(esquina: Vector2i) -> Array[String]`.
- Enforces:
  - Evoluciona automáticamente según `Ciudad.era_actual` y `Ciudad.ciencias_teoricas_descubiertas` (sin niveles manuales ni cobro de mejoras de puesto).
  - Era 2 Base: *Taller de Carretas* (`carreta_mano`).
  - Era 2 + `traccion_animal_engranajes`: *Establo de Transporte* (`carreta_mano`, `carro_caballos` si hay granja animal activa).
  - Era 3+ (o con tecnologías avanzadas): *Taller de Maquinaria y Transporte* (`camion_diesel` si tiene `quimica_hidrocarburos`, `trolebus_solar` si tiene `redes_electricas_bobinado`, `dron_carga` si tiene `automatizacion_cibernetica`).

- [x] **Step 1: Write failing test in `EconomiaTest.gd` and `PlantillasPuestoTest.gd`**

In `godot/scripts/EconomiaTest.gd`:
```gdscript
	print("\n=== TEST 49: Edificio Evolutivo Taller de Transporte ===")
	var e49: Node = EconomiaScript.new()
	var c49: Node = CiudadScript.new()
	e49.ciudad = c49
	c49.era_actual = 2
	var esq_taller := Vector2i(50, 50)
	e49.registrar_puesto(esq_taller, "taller_transporte", 5, 5, {})
	assert(e49.obtener_nombre_evolutivo_taller(esq_taller) == "Taller de Carretas")
	assert(e49.vehiculos_fabricables_en_taller(esq_taller) == ["carreta_mano"])

	# Simular investigación de tracción animal y granja animal activa
	c49.ciencias_teoricas_descubiertas.append("traccion_animal_engranajes")
	e49.registrar_puesto(Vector2i(20, 20), "granjas_animales", 5, 5, {})
	assert(e49.obtener_nombre_evolutivo_taller(esq_taller) == "Establo de Transporte")
	assert(e49.vehiculos_fabricables_en_taller(esq_taller).has("carro_caballos"))

	# Avanzar a Era 3 y química de hidrocarburos
	c49.era_actual = 3
	c49.ciencias_teoricas_descubiertas.append("quimica_hidrocarburos")
	assert(e49.obtener_nombre_evolutivo_taller(esq_taller) == "Taller de Maquinaria y Transporte")
	assert(e49.vehiculos_fabricables_en_taller(esq_taller).has("camion_diesel"))
```

- [x] **Step 2: Run test to verify failure**

```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/EconomiaTest.tscn"
```
Expected: FAIL.

- [x] **Step 3: Implement `taller_transporte` building and dynamic era/tech evolution**

- In `godot/scripts/Recoleccion.gd`:
  - Add `"taller_transporte"` to `TIPOS_PUESTO_TRABAJO`.
- In `godot/scripts/PlantillasPuesto.gd`:
  - Add footprint (5x5) and layers for `"taller_transporte"`.
- In `godot/scripts/BarraModos.gd` & `CamaraCenital.gd`:
  - Register `"taller_transporte"` under industrial buildings.
- In `godot/scripts/Economia.gd`:
  - When `tipo == "taller_transporte"`, initialize `p["cola_fabricacion"] = []`.
  - Implement `obtener_nombre_evolutivo_taller(esquina: Vector2i) -> String`:
    - Checks `ciudad.era_actual` and `ciudad.ciencias_teoricas_descubiertas`.
    - Returns localized title ("Taller de Carretas", "Establo de Transporte", "Taller de Maquinaria y Transporte").
  - Implement `vehiculos_fabricables_en_taller(esquina: Vector2i) -> Array[String]`:
    - Filters units in `Ajustes.TRANSPORTE_CATALOGO_UNIDADES` where `ciudad.era_actual >= era_minima`, `tech_requerida == ""` or in `ciudad.ciencias_teoricas_descubiertas`, and if `req_puesto` is present, verifies that an active post of that type exists in `puestos`.

- [x] **Step 4: Run test to verify pass**

```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/EconomiaTest.tscn"
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/PlantillasPuestoTest.tscn"
```
Expected: PASS.

- [x] **Step 5: Run full test suite**

```powershell
powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1
```
Expected: 28/28 OK.

- [x] **Step 6: Commit**

```bash
git add godot/scripts/Recoleccion.gd godot/scripts/PlantillasPuesto.gd godot/scripts/BarraModos.gd godot/scripts/CamaraCenital.gd godot/scripts/Economia.gd godot/scripts/EconomiaTest.gd
git commit -m "feat(transporte): edificio evolutivo taller_transporte y progresion por niveles"
```

---

### Task 5: Cola de Ensamblaje de Vehículos y Despliegue en Puestos

**Files:**
- Modify: `godot/scripts/Economia.gd`
- Modify: `godot/scripts/Colonos.gd`
- Modify: `godot/scripts/PanelPuesto.gd`
- Test: `godot/scripts/EconomiaTest.gd`

**Interfaces:**
- Produces: `Economia.ordenar_fabricacion_vehiculo(esquina: Vector2i, tipo_vehiculo: String) -> bool`.
- Produces: `Economia.asignar_tipo_transporte_puesto(esquina: Vector2i, tipo_vehiculo: String) -> bool`.
- Enforces:
  - Dron Autónomo does not assign workers from census (`cantidad_tripulacion == 0`).
  - Demolishing a post returns its assigned vehicle to `Ciudad.parque_transporte_disponible` (Review Focus 5).
  - Validates road path connectivity before deploying a heavy truck (`exige_via`).

- [ ] **Step 1: Write failing test in `EconomiaTest.gd` for vehicle assembly and deployment**

```gdscript
	print("\n=== TEST 50: Fabricación de Vehículos y Asignación de Rutas ===")
	# Ordenar fabricación de carreta_mano en taller
	c49.almacen["madera"].cantidad = 100.0
	c49.almacen["hierro"].cantidad = 50.0
	assert(e49.ordenar_fabricacion_vehiculo(esq_taller, "carreta_mano"))
	# Simular avance de fabricación
	e49.completar_fabricacion_en_taller(esq_taller)
	assert(c49.parque_transporte_disponible["carreta_mano"] == 1)

	# Desplegar en aserradero
	var esq_aser := Vector2i(60, 60)
	e49.registrar_puesto(esq_aser, "aserradero", 5, 5, {})
	assert(e49.asignar_tipo_transporte_puesto(esq_aser, "carreta_mano"))
	assert(c49.parque_transporte_disponible["carreta_mano"] == 0)
	assert(c49.parque_transporte_asignado["carreta_mano"] == 1)
	assert(e49.puestos[esq_aser]["tipo_transporte"] == "carreta_mano")

	# Review Focus 5: Demoler el aserradero retorna la carreta al parque disponible
	e49.quitar_puesto(esq_aser)
	assert(c49.parque_transporte_disponible["carreta_mano"] == 1)
	assert(c49.parque_transporte_asignado["carreta_mano"] == 0)
```

- [ ] **Step 2: Run test to verify failure**

```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/EconomiaTest.tscn"
```
Expected: FAIL.

- [ ] **Step 3: Implement vehicle fabrication and deployment**

In `godot/scripts/Economia.gd`:
- Implement `ordenar_fabricacion_vehiculo(esquina: Vector2i, tipo_vehiculo: String) -> bool`:
  - Validates vehicle is unlocked in `vehiculos_fabricables_en_taller(esquina)`.
  - Deducts materials via `ciudad.consumir_costos()`.
  - Adds to `p["cola_fabricacion"]`.
- In `_tick_taller_transporte()`, advance assembly progress.
- Implement `completar_fabricacion_en_taller(esquina: Vector2i) -> void`:
  - Increments `ciudad.parque_transporte_disponible[tipo_vehiculo] += 1`.
- Implement `asignar_tipo_transporte_puesto(esquina: Vector2i, tipo_vehiculo: String) -> bool`:
  - Validates availability in `ciudad.parque_transporte_disponible`.
  - If `Ajustes.TRANSPORTE_CATALOGO_UNIDADES[tipo_vehiculo]["exige_via"]`: validates that a continuous road path exists between post and warehouse/core.
  - Updates post `p["tipo_transporte"]`.
  - Updates fleet pools.
  - Reconciles hauler crew in `colonos` (if `cantidad_tripulacion == 0`, frees human hauler).
- In `quitar_puesto(esquina)`:
  - If post has an assigned vehicle != `"acarreador_pie"`, returns vehicle to `ciudad.parque_transporte_disponible`.

- [ ] **Step 4: Run test to verify pass**

```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/EconomiaTest.tscn"
```
Expected: PASS.

- [ ] **Step 5: Run full test suite**

```powershell
powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1
```
Expected: 28/28 OK.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/Economia.gd godot/scripts/Colonos.gd godot/scripts/EconomiaTest.gd
git commit -m "feat(transporte): cola de fabricacion en taller y asignacion de vehiculos en puestos"
```

---

### Task 6: Integración en Interfaz de Usuario (`PanelPuesto.gd`)

**Files:**
- Modify: `godot/scripts/PanelPuesto.gd`
- Test: `godot/scripts/HUDTest.gd`

**Interfaces:**
- Produces:
  - In `taller_transporte`: Header con nombre evolutivo reactivo (*Taller de Carretas*, *Establo de Transporte*, *Taller de Maquinaria y Transporte*), lista de vehículos desbloqueados por Era y Tecnologías con costos de fabricación en recursos reales (`madera`, `hierro`, `tablas`, `tierra`, `acero`, `combustible`, etc.), botones de ensamblaje y barra de progreso.
  - In peripheral resource posts (Siderúrgica, Aserradero, Minas, Sembríos, etc.): Sección para asignación de unidad de transporte, mostrando el vehículo actual, velocidad, capacidad y selector de transportes disponibles en el parque de la ciudad.

- [ ] **Step 1: Write failing test in `HUDTest.gd` for transport UI controls**

```gdscript
	print("\n=== TEST: Controles de Transporte en PanelPuesto ===")
	var panel_p := PanelPuestoScript.new()
	add_child(panel_p)
	assert(panel_p._caja_transporte_puesto != null)
	assert(panel_p._caja_taller_transporte != null)
```

- [ ] **Step 2: Run test to verify failure**

```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/HUDTest.tscn"
```
Expected: FAIL.

- [ ] **Step 3: Implement transport UI in `PanelPuesto.gd`**

In `godot/scripts/PanelPuesto.gd`:
- Pre-instantiate in `_ready()` (following the zero-frame-recreation pattern established in Task 6):
  - `_caja_transporte_puesto`: container with label and buttons to select transport unit.
  - `_caja_taller_transporte`: container with workshop tier label, upgrade button, vehicle build buttons, and assembly progress bar.
- In `_actualizar()`:
  - For `taller_transporte`: update tier name, upgrade button cost/disabled state, and assembly progress.
  - For posts with haulers: update current transport unit name, capacity badge, and available vehicle count from `Ciudad.parque_transporte_disponible`.

- [ ] **Step 4: Run test to verify pass**

```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/HUDTest.tscn"
```
Expected: PASS.

- [ ] **Step 5: Run full test suite**

```powershell
powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1
```
Expected: All 28 test suites pass without regression.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/PanelPuesto.gd godot/scripts/HUDTest.gd
git commit -m "feat(ui): selector de transporte en puestos y controles de fabricacion en taller_transporte"
```

---

## Verificación Final del Branch

1. Ejecutar el runner de pruebas completo:
   `powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1`
2. Solicitar revisión de código integral con `superpowers:requesting-code-review`.
3. Notificar al usuario el cumplimiento exitoso de todas las metas del plan.

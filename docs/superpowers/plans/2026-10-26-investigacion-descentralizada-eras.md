# Plan de Implementación: Investigación Descentralizada, Pacing de Eras y Reconversión Doctrinal

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar el sistema de evolución orgánica de civilización mediante el Índice de Desarrollo Urbano ($IDU$), la investigación tecnológica en dos capas (Ciencia Básica centralizada y Aplicaciones Prácticas in-situ con Investigadores Itinerantes), la Balanza Doctrinal tripartita ($D / C / S$) y la Reconversión Industrial de instalaciones.

**Architecture:** 
1. **Pacing Orgánico ($IDU$):** Cálculo horario ponderado de sofisticación de infraestructura ($S$), cualificación laboral ($Q$) y masa crítica de conocimiento ($K$), transicionando automáticamente entre Eras 1 a 4.
2. **Capa 1 (Ciencia Básica):** Puntos de investigación teórica generados en la Universidad según investigadores, moral y energía para desbloquear tecnologías teóricas.
3. **Capa 2 (Aplicaciones Prácticas):** Proyectos in-situ en edificios/puestos que despachan comisiones científicas itinerantes (1 a 3 investigadores según la Era) transitando físicamente por la red vial.
4. **Balanza Doctrinal y Reconversión:** Vector de identidad $\vec{B} = \{D, C, S\}$ dinámico, con reglas de exclusión mutua y reconversión de mejoras al $50\%$ de costo de mejora + $25\%$ del costo base a $1.5\times$ de tiempo y $25\%$ de producción.

**Tech Stack:** Godot 4.3 (GDScript), A* Pathfinding (`BuscadorRutas.gd`), TemaHUD.

**Spec:** `docs/superpowers/specs/2026-10-26-investigacion-descentralizada-eras-spec.md`

---

## Global Constraints

- **Centralización:** Todas las constantes numéricas en `godot/scripts/ajustes.gd` y todas las cadenas/textos visibles en `godot/scripts/strings.gd`.
- **Evolución Orgánica:** La transición de Era (1 a 4) ocurre exclusivamente por cruce del umbral de $IDU$, sin botón de avance manual.
- **Compatibilidad con Sistemas Previos:** `Ciudad.nivel_investigado` y `Ciudad.nivel` se sincronizan con `era_actual` para no romper desbloqueos de blueprints, pisos residenciales o industrias avanzadas.
- **Movilidad Vial:** Los investigadores itinerantes usan el coste de paso real de `Vias.coste_paso_en` (3 en vía afirmada vs 8 en campo natural) para reflejar las ventajas de la red de transporte.
- **Integridad de Pruebas:** Las 28 suites de pruebas del proyecto (`tools/run-godot-tests.ps1`) deben mantenerse al 100% en verde tras cada tarea.

---

## Execution Lines & Dependency Matrix

- **Línea A (Modelo & Balance Central):** Task 1 -> Task 2 -> Task 3 (Files: `ajustes.gd`, `strings.gd`, `Ciudad.gd`, `Economia.gd`) — Local Test: `CiudadTest.tscn`, `EconomiaTest.tscn`.
- **Línea B (Comisiones Científicas & Movilidad):** Task 4 (Files: `Colonos.gd`, `BuscadorRutas.gd`) — Local Test: `ColonosTest.tscn`.
- **Línea C (Aplicaciones Prácticas & Reconversión):** Task 5 (Files: `Economia.gd`, `Ciudad.gd`) — Local Test: `EconomiaTest.tscn`, `CiudadTest.tscn`.
- **Línea D (Interfaces de Usuario & HUD):** Task 6 (Files: `BarraSuperior.gd`, `PanelPuesto.gd`, `PanelEdificio.gd`, `TemaHUD.gd`) — Local Test: `HUDTest.tscn`.
- **Global Integration Test:** `powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1`

---

## Review Focus

1. **División por cero en censo o infraestructura vacía:** Si una ciudad tiene 0 habitantes o 0 edificios al inicio, $Q_{\text{laboral}}$ y $S_{\text{edificios}}$ deben retornar de forma segura 1.0 sin provocar `NaN` ni errores.
2. **Sincronización de comisiones de múltiples investigadores:** En Eras 3 y 4 (comisiones de 2 y 3 investigadores), el temporizador de desarrollo in-situ no debe arrancar hasta que el último investigador llegue a la casilla del edificio.
3. **Pérdida de investigadores itinerantes en trayecto:** Si un investigador de la comisión muere o queda bloqueado en ruta, el proyecto debe registrar la baja y permitir el reemplazo sin quedar en deadlock permanente.
4. **Consistencia matemática de la Balanza Doctrinal en reconversión:** Al reconvertir sucesivamente un edificio, los puntos de la doctrina previa deben restarse exactamente y los nuevos sumarse sin permitir puntos negativos o derivas residuales.
5. **Retrocompatibilidad con candados de nivel:** Las consultas existentes a `Ciudad.nivel_investigado` o `Ciudad.nivel` deben reflejar la Era alcanzada, manteniendo el acceso a refinerías, centrales y pisos de edificios.

---

## Tareas de Implementación

### Task 1: Constantes de Balance, Catálogos Doctrinales y Fórmulas IDU en `ajustes.gd` y `strings.gd`

**Files:**
- Modify: `godot/scripts/ajustes.gd`
- Modify: `godot/scripts/strings.gd`
- Test: `godot/scripts/CiudadTest.gd`

**Interfaces:**
- Produces: `Ajustes.IDU_PESO_EDIFICIOS`, `Ajustes.IDU_PESO_LABORAL`, `Ajustes.IDU_PESO_CIENCIA`, `Ajustes.IDU_UMBRAL_ERA_2`, `Ajustes.IDU_UMBRAL_ERA_3`, `Ajustes.IDU_UMBRAL_ERA_4`.
- Produces: `Ajustes.CIENCIAS_TEORICAS_CATALOGO`, `Ajustes.MEJORAS_PRACTICAS_CATALOGO`.
- Produces: `Ajustes.RECONVERSION_FACTOR_MATERIALES_MEJORA` (0.50), `Ajustes.RECONVERSION_FACTOR_COSTO_EDIFICIO` (0.25), `Ajustes.RECONVERSION_FACTOR_TIEMPO` (1.5), `Ajustes.RECONVERSION_PRODUCCION_PENALIZADA` (0.25).
- Produces: `Strings.ERA_NOMBRES`, `Strings.DOCTRINA_NOMBRES`, cadenas de reconversión y proyectos.

- [ ] **Step 1: Write failing test in `CiudadTest.gd` for balance constants and catalogs**

```gdscript
	print("\n=== TEST 37: Constantes de Pacing de Eras y Catálogos Doctrinales ===")
	assert(Ajustes.IDU_UMBRAL_ERA_2 == 1.50)
	assert(Ajustes.IDU_UMBRAL_ERA_3 == 2.50)
	assert(Ajustes.IDU_UMBRAL_ERA_4 == 3.50)
	assert(Ajustes.CIENCIAS_TEORICAS_CATALOGO.has("metalurgia_hornos"))
	assert(Ajustes.CIENCIAS_TEORICAS_CATALOGO["metalurgia_hornos"]["costo_puntos"] == 100)
	assert(Ajustes.CIENCIAS_TEORICAS_CATALOGO["automatizacion_cibernetica"]["doctrina"] == "cyberpunk")
	assert(Ajustes.RECONVERSION_FACTOR_MATERIALES_MEJORA == 0.50)
	assert(Ajustes.RECONVERSION_PRODUCCION_PENALIZADA == 0.25)
```

- [ ] **Step 2: Run test to verify failure**

```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/CiudadTest.tscn"
```
Expected: FAIL (Identifier not found in `Ajustes`).

- [ ] **Step 3: Implement constants and strings**

In `godot/scripts/ajustes.gd`:
- Add IDU weights and era thresholds:
  ```gdscript
  static var IDU_PESO_EDIFICIOS: float = 0.40
  static var IDU_PESO_LABORAL: float = 0.35
  static var IDU_PESO_CIENCIA: float = 0.25
  static var IDU_UMBRAL_ERA_2: float = 1.50
  static var IDU_UMBRAL_ERA_3: float = 2.50
  static var IDU_UMBRAL_ERA_4: float = 3.50
  ```
- Add `CIENCIAS_TEORICAS_CATALOGO` per spec Section 3.2.
- Add `MEJORAS_PRACTICAS_CATALOGO` with era requirements, commission sizes (1 in Era 2, 2 in Era 3, 3 in Era 4), doctrine points, costs, and exclusions.
- Add reconversion parameters per spec Section 6.1.
- In `godot/scripts/strings.gd`, define names for eras, doctrines, and button labels.

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
git add godot/scripts/ajustes.gd godot/scripts/strings.gd godot/scripts/CiudadTest.gd
git commit -m "feat(eras): constantes de balance de pacing idu, catalogos teoricos y doctrina"
```

---

### Task 2: Cálculo del IDU, Transición Orgánica de Eras y Balanza Doctrinal en `Ciudad.gd`

**Files:**
- Modify: `godot/scripts/Ciudad.gd`
- Test: `godot/scripts/CiudadTest.gd`

**Interfaces:**
- Produces: `Ciudad.era_actual: int` (1 a 4), `Ciudad.calcular_idu() -> float`, `Ciudad.calcular_sofisticacion_edificios() -> float`, `Ciudad.calcular_cualificacion_laboral() -> float`, `Ciudad.calcular_masa_critica_ciencia() -> float`.
- Produces: `Ciudad.balanza_doctrinal: Dictionary`, `Ciudad.calcular_porcentajes_doctrinales() -> Dictionary`, `Ciudad.agregar_puntos_doctrina(doctrina: String, puntos: float)`.
- Updates: `Ciudad.simular_tick()` automatically checks and updates `era_actual` based on IDU without manual button, synchronizing `nivel_investigado = max(nivel_investigado, era_actual)`.

- [ ] **Step 1: Write failing tests in `CiudadTest.gd` for IDU calculation, organic transition, and doctrine balance**

```gdscript
	print("\n=== TEST 38: Pacing Orgánico IDU y Balanza Doctrinal ===")
	var ciu38: Node = CiudadScript.new()
	# Review Focus 1: Censo y edificios vacíos deben dar IDU base 1.0 sin división por cero
	assert(is_equal_approx(ciu38.calcular_cualificacion_laboral(), 1.0))
	assert(is_equal_approx(ciu38.calcular_sofisticacion_edificios(), 1.0))
	assert(ciu38.era_actual == 1)

	# Simular condiciones de transición a Era 2: S=1.8, Q=1.6, K=1.2
	# IDU = 0.40*1.8 + 0.35*1.6 + 0.25*1.2 = 0.72 + 0.56 + 0.30 = 1.58 (>= 1.50)
	ciu38.establecer_metricas_idu_override(1.8, 1.6, 1.2)
	assert(ciu38.calcular_idu() >= 1.50)
	ciu38.actualizar_pacing_era()
	assert(ciu38.era_actual == 2)
	assert(ciu38.nivel_investigado >= 2)

	# Balanza Doctrinal
	ciu38.agregar_puntos_doctrina("dieselpunk", 60.0)
	ciu38.agregar_puntos_doctrina("solarpunk", 20.0)
	ciu38.agregar_puntos_doctrina("cyberpunk", 20.0)
	var bal := ciu38.calcular_porcentajes_doctrinales()
	assert(is_equal_approx(bal["dieselpunk"], 60.0))
	assert(bal["dominante"] == "dieselpunk")
	assert(bal["nivel"] == 2)
```

- [ ] **Step 2: Run test to verify failure**

```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/CiudadTest.tscn"
```
Expected: FAIL (`calcular_idu` not defined).

- [ ] **Step 3: Implement IDU and doctrine balance in `Ciudad.gd`**

- In `Ciudad.gd`:
  - Define `var era_actual: int = 1`.
  - Define `var balanza_doctrinal: Dictionary = {"dieselpunk": 0.0, "cyberpunk": 0.0, "solarpunk": 0.0}`.
  - Implement `calcular_sofisticacion_edificios() -> float`:
    - Counts Tipo 1 (default 1.0), Tipo 2 (2.0), Tipo 3 (3.0), Tipo 4 (4.0).
    - If total == 0, returns 1.0. Clamped to [1.0, 4.0].
  - Implement `calcular_cualificacion_laboral() -> float`:
    - Uses demografia weights: obreros * 1.0 + tecnicos * 2.0 + especialistas * 3.0 + investigadores * 3.5.
    - If censo == 0, returns 1.0. Clamped to [1.0, 4.0].
  - Implement `calcular_masa_critica_ciencia() -> float`:
    - Ratio of discovered basic & applied techs / available techs in current era. $K = 1.0 + 3.0 \times \text{ratio}$.
  - Implement `calcular_idu() -> float`:
    - $(0.40 \times S) + (0.35 \times Q) + (0.25 \times K)$.
  - Implement `actualizar_pacing_era() -> void`:
    - Checks thresholds: Era 4 (>= 3.50), Era 3 (>= 2.50), Era 2 (>= 1.50).
    - Updates `era_actual = maxi(era_actual, nueva_era)`.
    - Sincroniza `nivel_investigado = maxi(nivel_investigado, era_actual)`.
  - Implement `calcular_porcentajes_doctrinales() -> Dictionary` and `agregar_puntos_doctrina(doctrina, delta)`.
  - Call `actualizar_pacing_era()` inside `simular_tick()`.

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
git add godot/scripts/Ciudad.gd godot/scripts/CiudadTest.gd
git commit -m "feat(eras): calculo de idu, evolucion organica de eras y balanza doctrinal"
```

---

### Task 3: Capa 1: Ciencia Teórica en la Universidad y Generación de `puntos_ciencia`

**Files:**
- Modify: `godot/scripts/Ciudad.gd`
- Modify: `godot/scripts/Economia.gd`
- Test: `godot/scripts/CiudadTest.gd`
- Test: `godot/scripts/EconomiaTest.gd`

**Interfaces:**
- Produces: `Ciudad.puntos_ciencia: float`, `Ciudad.ciencias_teoricas_descubiertas: Array[String]`, `Ciudad.ciencia_teorica_activa: String`.
- Produces: `Economia.generar_puntos_ciencia(horas: float, investigadores_activos: int, moral: float, energizada: bool) -> float`.
- Produces: `Ciudad.iniciar_ciencia_teorica(id_ciencia: String) -> bool`, `Ciudad.esta_ciencia_descubierta(id_ciencia: String) -> bool`.

- [ ] **Step 1: Write failing tests for theoretical science generation and discovery**

In `godot/scripts/CiudadTest.gd`:
```gdscript
	print("\n=== TEST 39: Generación de Ciencia Teórica en Universidad ===")
	var ciu39: Node = CiudadScript.new()
	ciu39.moral = 50.0  # X_moral = 1.0
	assert(ciu39.iniciar_ciencia_teorica("metalurgia_hornos"))
	assert(ciu39.ciencia_teorica_activa == "metalurgia_hornos")

	# Generar puntos: 10 investigadores * 1.0h * 1.0 moral * 1.0 energia = 10 puntos
	ciu39.almacen["hierro"].agregar(100.0)
	ciu39.almacen["madera"].agregar(200.0)
	ciu39.acumular_ciencia_teorica(100.0)  # Completa los 100 puntos de metalurgia_hornos
	assert(ciu39.esta_ciencia_descubierta("metalurgia_hornos"))
	assert(ciu39.ciencia_teorica_activa == "")
```

In `godot/scripts/EconomiaTest.gd`:
```gdscript
	print("\n=== TEST 46: Generación horaria de puntos de ciencia ===")
	var e46: Node = EconomiaScript.new()
	var delta_pts := e46.calcular_delta_puntos_ciencia(4, 1.0, true) # 4 inv, 1.0 moral, con energia
	assert(is_equal_approx(delta_pts, 4.0))
```

- [ ] **Step 2: Run test to verify failure**

```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/CiudadTest.tscn"
```
Expected: FAIL.

- [ ] **Step 3: Implement theoretical science mechanics**

- In `godot/scripts/Ciudad.gd`:
  - Declare `puntos_ciencia: float = 0.0`, `ciencias_teoricas_descubiertas: Array[String] = []`, `progreso_ciencia_teorica: Dictionary = {}`, `ciencia_teorica_activa: String = ""`.
  - Implement `iniciar_ciencia_teorica(id_ciencia: String) -> bool`:
    - Validates prerequisites (`prerrequisito` discovered in `ciencias_teoricas_descubiertas`).
    - Validates era availability.
  - Implement `acumular_ciencia_teorica(pts: float) -> bool`:
    - Deducts required resource costs (`costo_recursos`) upon reaching point goal.
    - Adds to `ciencias_teoricas_descubiertas`.
    - If discovered tech has a doctrine flag (Era 4), adds $+25$ doctrine points.
- In `godot/scripts/Economia.gd`:
  - Implement `calcular_delta_puntos_ciencia(investigadores: int, mult_moral: float, energizada: bool) -> float`:
    - Returns `investigadores * 1.0 * mult_moral * (1.0 if energizada else 0.5)`.
  - In `_tick_universidad()`, accumulate points to `ciudad`.

- [ ] **Step 4: Run test to verify pass**

```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/CiudadTest.tscn"
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
git add godot/scripts/Ciudad.gd godot/scripts/Economia.gd godot/scripts/CiudadTest.gd godot/scripts/EconomiaTest.gd
git commit -m "feat(ciencia): capa 1 de investigacion teorica en universidad y generacion de puntos"
```

---

### Task 4: Investigador Itinerante, Despacho de Comisiones y Pathfinding Vial en `Colonos.gd`

**Files:**
- Modify: `godot/scripts/Colonos.gd`
- Modify: `godot/scripts/BuscadorRutas.gd`
- Test: `godot/scripts/ColonosTest.gd`

**Interfaces:**
- Produces: `Colonos.despachar_comision_cientifica(destino: Vector3i, edificio_id: String, num_investigadores: int, id_proyecto: String) -> Array[int]`.
- Produces: `Colonos.comision_esta_completa_en_destino(id_proyecto: String, destino: Vector3i) -> bool`.
- Handles: Task state `investigador_itinerante`, movement via road networks prioritizing affirmed roads (`Vias.coste_paso_en`), and casualty handling.

- [ ] **Step 1: Write failing tests in `ColonosTest.gd` for commission dispatch and arrival synchronization**

```gdscript
	print("\n=== TEST 26: Despacho de Comisiones Científicas e Investigador Itinerante ===")
	# Verificar que una comisión de Era 3 pide exactamente 2 investigadores
	var ids_comision: Array[int] = colonos_test.despachar_comision_cientifica(destino_obra, "refineria_1", 2, "proyecto_diesel")
	assert(ids_comision.size() == 2)
	assert(colonos_test.colonos[ids_comision[0]]["tarea"].get("tipo") == "investigador_itinerante")

	# Review Focus 2: No debe considerarse completa hasta que ambos hayan llegado
	colonos_test.colonos[ids_comision[0]]["celda"] = destino_obra
	assert(not colonos_test.comision_esta_completa_en_destino("proyecto_diesel", destino_obra))
	colonos_test.colonos[ids_comision[1]]["celda"] = destino_obra
	assert(colonos_test.comision_esta_completa_en_destino("proyecto_diesel", destino_obra))
```

- [ ] **Step 2: Run test to verify failure**

```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/ColonosTest.tscn"
```
Expected: FAIL.

- [ ] **Step 3: Implement commission dispatch and itinerant travel in `Colonos.gd`**

- In `godot/scripts/Colonos.gd`:
  - Manage active commissions dictionary: `var comisiones_activas: Dictionary = {} # id_proyecto -> {destino, requeridos, miembros: Array[int]}`.
  - Implement `despachar_comision_cientifica`:
    - Selects available researchers (`_ids_sin_puesto("investigador")`).
    - Assigns task `{"tipo": "investigador_itinerante", "proyecto": id_proyecto, "destino": destino}`.
    - Initiates route search towards `destino`.
  - In `_avanzar_colono`:
    - Handle `investigador_itinerante`: upon arriving at `destino`, mark member as arrived.
  - Implement `comision_esta_completa_en_destino(id_proyecto, destino) -> bool`:
    - Checks that all members of the commission are alive and present at `destino`.
  - Handle casualty/block (Review Focus 3):
    - If a member dies or is revoked, remove from `comisiones_activas[id_proyecto]["miembros"]` and allow dispatching a replacement.
  - Implement `liberar_comision(id_proyecto) -> void`:
    - Clears tasks and frees researchers back to idle or home post.

- [ ] **Step 4: Run test to verify pass**

```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/ColonosTest.tscn"
```
Expected: PASS.

- [ ] **Step 5: Run full test suite**

```powershell
powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1
```
Expected: 28/28 OK.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/Colonos.gd godot/scripts/BuscadorRutas.gd godot/scripts/ColonosTest.gd
git commit -m "feat(colonos): investigadores itinerantes, despacho de comisiones y sincronizacion in-situ"
```

---

### Task 5: Capa 2: Aplicaciones Prácticas y Mecánica de Reconversión Industrial en `Economia.gd` y `Ciudad.gd`

**Files:**
- Modify: `godot/scripts/Economia.gd`
- Modify: `godot/scripts/Ciudad.gd`
- Test: `godot/scripts/EconomiaTest.gd`
- Test: `godot/scripts/CiudadTest.gd`

**Interfaces:**
- Produces: `Economia.iniciar_mejora_practica(esquina: Vector2i, id_mejora: String) -> bool`.
- Produces: `Economia.iniciar_reconversion_industrial(esquina: Vector2i, nueva_mejora: String) -> bool`.
- Enforces:
  - Mutual exclusion (`excluye`).
  - Commission arrival requirement (`ESPERANDO_PERSONAL` -> `EN_EJECUCION`).
  - Reconversion fee ($50\%$ materials + $25\%$ base building cost) and penalty ($25\%$ production rate during reconversion).
  - Doctrine balance subtraction of previous upgrade and addition of new upgrade upon completion.

- [ ] **Step 1: Write failing tests for practical application and industrial reconversion**

In `godot/scripts/EconomiaTest.gd`:
```gdscript
	print("\n=== TEST 47: Capa 2 - Aplicación Práctica y Reconversión Doctrinal ===")
	var e47: Node = EconomiaScript.new()
	var c47: Node = CiudadScript.new()
	e47.ciudad = c47
	# Registrar central termoeléctrica
	var esq_termo := Vector2i(10, 10)
	e47.registrar_puesto(esq_termo, "central_termoelectrica", 5, 5, {})
	c47.ciencias_teoricas_descubiertas.append("quimica_hidrocarburos")
	c47.ciencias_teoricas_descubiertas.append("biotecnologia_fototermia")

	# Instalar mejora dieselpunk
	assert(e47.iniciar_mejora_practica(esq_termo, "caldera_diesel"))
	assert(e47.puestos[esq_termo]["proyecto_mejora"]["estado"] == "ESPERANDO_PERSONAL")
	# Simular llegada y finalización
	e47.completar_mejora_en_puesto(esq_termo)
	assert(e47.puestos[esq_termo]["mejoras"].has("caldera_diesel"))
	assert(c47.balanza_doctrinal["dieselpunk"] >= 15.0)

	# Reconversión a Solarpunk
	assert(e47.iniciar_reconversion_industrial(esq_termo, "ciclo_solarpunk"))
	assert(e47.puestos[esq_termo]["estado_operativo"] == "RECONVERSION")
	# Producción penalizada al 25% durante reconversión
	assert(is_equal_approx(e47.multiplicador_operativo_puesto(esq_termo), 0.25))

	# Completar reconversión (Review Focus 4: Puntos dieselpunk eliminados, solarpunk sumados)
	e47.completar_mejora_en_puesto(esq_termo)
	assert(not e47.puestos[esq_termo]["mejoras"].has("caldera_diesel"))
	assert(e47.puestos[esq_termo]["mejoras"].has("ciclo_solarpunk"))
	assert(c47.balanza_doctrinal["dieselpunk"] == 0.0)
	assert(c47.balanza_doctrinal["solarpunk"] >= 15.0)
```

- [ ] **Step 2: Run test to verify failure**

```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/EconomiaTest.tscn"
```
Expected: FAIL.

- [ ] **Step 3: Implement practical improvements and industrial reconversion**

- In `godot/scripts/Economia.gd`:
  - Add to post schema: `"mejoras": []`, `"proyecto_mejora": {}`, `"estado_operativo": "normal"`.
  - Implement `iniciar_mejora_practica(esquina, id_mejora)`:
    - Verifies theoretical prerequisite in `ciudad.ciencias_teoricas_descubiertas`.
    - Checks exclusion list (`excluye`).
    - Charges materials.
    - Triggers `Colonos.despachar_comision_cientifica(...)`.
    - Sets project state `ESPERANDO_PERSONAL`.
  - Implement `iniciar_reconversion_industrial(esquina, nueva_mejora)`:
    - Calculates reform fee: $50\%$ new materials + $25\%$ base building cost.
    - Sets `estado_operativo = "RECONVERSION"`.
    - Dispatches scientific commission.
  - In `_tick_puestos()`:
    - When project is `EN_EJECUCION`, advance development hours.
    - If post is in `RECONVERSION`, scale production by $0.25$.
  - Implement `completar_mejora_en_puesto(esquina)`:
    - If it was a reconversion, deduct previous upgrade doctrine points from `ciudad`.
    - Add new upgrade doctrine points to `ciudad`.
    - Replace improvement in `"mejoras"`.
    - Reset `estado_operativo = "normal"`.
    - Free scientific commission.

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
git add godot/scripts/Economia.gd godot/scripts/Ciudad.gd godot/scripts/EconomiaTest.gd
git commit -m "feat(industria): aplicaciones practicas in-situ y reconversion industrial sin demolicion"
```

---

### Task 6: Integración en Interfaz de Usuario (HUD, BarraSuperior, PanelPuesto y PanelEdificio)

**Files:**
- Modify: `godot/scripts/BarraSuperior.gd`
- Modify: `godot/scripts/PanelPuesto.gd`
- Modify: `godot/scripts/PanelEdificio.gd`
- Modify: `godot/scripts/TemaHUD.gd`
- Test: `godot/scripts/HUDTest.gd`

**Interfaces:**
- Produces:
  - `BarraSuperior.gd`: Widget de Era actual (ej. "Era 2") e IDU (ej. "IDU 1.85") con tooltip de desglose $S, Q, K$; indicador de balanza doctrinal ($D / C / S$).
  - `PanelPuesto.gd`: Visualización de Capa 1 en Universidad (catálogo teórico con prerrequisitos y generación de puntos); visualización de Capa 2 en industrias (mejoras prácticas disponibles, estado de comisión en camino, botón de reconversión).
  - `PanelEdificio.gd`: Mejoras y reconversión en edificios residenciales y Núcleo Urbano.

- [ ] **Step 1: Write failing tests in `HUDTest.gd` for Era/IDU display and research/reconversion panels**

```gdscript
	print("\n=== TEST: Widget de Era e IDU en BarraSuperior ===")
	assert(barra._lbl_era != null)
	assert(barra._lbl_idu != null)

	print("\n=== TEST: Controles de Capa 1 en PanelPuesto (Universidad) ===")
	var panel_p := PanelPuestoScript.new()
	add_child(panel_p)
	# Verificar que el panel de universidad expone lista de ciencias teóricas
	assert(panel_p._caja_ciencias_teoricas != null)
```

- [ ] **Step 2: Run test to verify failure**

```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/HUDTest.tscn"
```
Expected: FAIL.

- [ ] **Step 3: Implement HUD and UI widgets**

- In `godot/scripts/BarraSuperior.gd`:
  - Add `_lbl_era` and `_lbl_idu` labels next to population/moral.
  - In `actualizar()`, display current Era name and formatted IDU.
  - Set tooltip with breakdown: `IDU: %.2f\n  - Sofisticación (S): %.2f\n  - Cualificación (Q): %.2f\n  - Ciencia (K): %.2f`.
  - Add doctrine mini-badge showing percentages if total doctrine points > 0.
- In `godot/scripts/PanelPuesto.gd`:
  - In Universidad: render the theoretical science catalog with prerequisites, current research progress bar, and point accumulation rate.
  - In workplaces (Termoeléctrica, Siderúrgica, etc.): render available practical upgrades, active project state (`ESPERANDO_PERSONAL (1/2)`, `EN_EJECUCION`), and button for *"Iniciar Reconversión Industrial"*.
- In `godot/scripts/PanelEdificio.gd`:
  - Render core / building practical upgrades and reconversion button where applicable.

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
git add godot/scripts/BarraSuperior.gd godot/scripts/PanelPuesto.gd godot/scripts/PanelEdificio.gd godot/scripts/TemaHUD.gd godot/scripts/HUDTest.gd
git commit -m "feat(ui): indicadores de era e idu en barra superior y paneles de investigacion y reconversion"
```

---

## Verificación Final del Branch

1. Ejecutar el runner de pruebas completo:
   `powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1`
2. Solicitar revisión de código integral con `superpowers:requesting-code-review`.
3. Notificar al usuario el cumplimiento exitoso de todas las metas del plan.

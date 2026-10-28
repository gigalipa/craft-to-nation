# Balance de Economía de Alimentos, Metabolismo y Demografía Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the food economy balance, metabolic rates, stratified food consumption cascade, monoculture penalty, agricultural productivity floor (75%), dynamic military upkeep (garrison vs. deployed), and the strict rationing civic decree.

**Architecture:** Extend `ajustes.gd` with balanced metabolic consumption rates and civic constants. Augment `Ciudad.gd` with a stratified food sub-inventory (6 categories consumed from fresh to non-perishable), monoculture time-tracking with 15-day (360h) grace, food productivity floor shielding ($X_{\text{alimentos}} \ge 0.75$) connected to `Economia.gd`, dynamic military upkeep dependent on `Zonificacion.dentro_de_influencia()` connected to `Colonos.gd`, and civic decree toggling in `PanelEdificio.gd` and `VentanaAlmacen.gd`.

**Tech Stack:** Godot 4.x / GDScript, Godot Headless CLI, PowerShell test runner.

**Spec:** [`docs/superpowers/specs/2026-10-26-balance-alimentos-demografia-spec.md`](docs/superpowers/specs/2026-10-26-balance-alimentos-demografia-spec.md)

---

## Global Constraints

- Preserve unified `comida` in the HUD, top bar, and main warehouse; internal stratification exists within `sub_almacen_comida`.
- Order of food consumption is strictly: `pesca` -> `recoleccion_caza` -> `sembradios` -> `granjas_animales` -> `hidroponia` -> `sintetico`.
- Biological baseline for research/citizen metabolism: minimum 2.0 u/h per person (`investigador` is not cheaper to feed than `obrero`).
- Monoculture penalty: grace of 360 game hours (15 days). Once exceeded with only 1 active category, apply -0.2/h moral penalty until variety > 1.
- Agricultural productivity floor: $X_{\text{alimentos}} \ge 0.75$, even at moral 0.0.
- Strict rationing decree: -35% food consumption, moral capped at 35.0 max while active.
- All 28 test suites in `tools/run-godot-tests.ps1` must pass without regressions.

---

## Execution Lines & Dependency Matrix

- **Line A (Core Simulation & Balance):** Task 1 (`ajustes.gd` & baseline updates) -> Task 2 (`Ciudad.gd` sub-inventory & stratified consumption) -> Task 3 (`Ciudad.gd` monoculture grace & diet variety scale).
  - Local Test: `powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/CiudadTest.tscn"`
- **Line B (Productivity & Economy):** Task 4 (`Ciudad.gd` agricultural productivity floor & `Economia.gd` food rate shielding).
  - Local Test: `powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/EconomiaTest.tscn"`
- **Line C (Military Deployment & Colonos):** Task 5 (`Colonos.gd` deployed count & `Ciudad.gd` military consumption).
  - Local Test: `powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/ColonosTest.tscn"`
- **Line D (Civic Decrees & UI):** Task 6 (Rationing decree in `Ciudad.gd`, `PanelEdificio.gd` Urban Core toggle, `VentanaMoral.gd`, `VentanaAlmacen.gd`).
  - Local Test: `powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/HUDTest.tscn"`
- **Global Integration Test:** `powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1` (all 28 suites).

---

## Review Focus

1. **Famine zeroing sub-inventory:** When famine strikes (`almacen["comida"].cantidad <= 0.0`), all 6 categories in `sub_almacen_comida` must be cleared to 0.0 so no ghost stocks remain. Pin in Task 2.
2. **Monoculture timer reset:** Adding a second food source after 400h of monoculture must instantly reset `horas_monocultivo_continuo` to 0, granting a full new 360h grace period. Pin in Task 3.
3. **Fallback category for untyped food deliveries:** Deliveries without an explicit category (e.g. debug stock, baul transfers, legacy tests) must safely default to `"recoleccion_caza"`. Pin in Task 2.
4. **Immediate moral clamp on rationing decree activation:** Activating the decree while city moral is high (e.g. 75.0) must clamp moral to $\le 35.0$ on the very next tick. Pin in Task 6.
5. **Military deployment when no core is declared:** If `Zonificacion.nucleo_declarado` is false, `dentro_de_influencia()` returns false; military units must count as deployed without errors or crashes. Pin in Task 5.

---

### Task 1: Actualización de Tasas Demográficas y Constantes de Balance

**Files:**
- Modify: `godot/scripts/ajustes.gd:360-460`
- Modify: `godot/scripts/CiudadTest.gd:155-170`

**Interfaces:**
- Produces: `Ajustes.CIUDAD_TIPOS_POBLACION`, `Ajustes.MILITAR_CONSUMO_COMIDA_DESPLEGADO`, `Ajustes.MILITAR_CONSUMO_COMBUSTIBLE_DESPLEGADO`, `Ajustes.CIUDAD_ORDEN_CONSUMO_COMIDA`, `Ajustes.CIUDAD_GRACIA_MONOCULTIVO_HORAS`, `Ajustes.CIUDAD_PENALIZACION_MONOCULTIVO_MORAL`, `Ajustes.CIUDAD_BONO_DIETA_2_3_FUENTES`, `Ajustes.CIUDAD_BONO_DIETA_4_5_FUENTES`, `Ajustes.CIUDAD_BONO_DIETA_6_FUENTES`, `Ajustes.PRODUCTIVIDAD_SUELO_ALIMENTOS`, `Ajustes.RACIONAMIENTO_REDUCCION_CONSUMO`, `Ajustes.RACIONAMIENTO_TECHO_MORAL`.

- [ ] **Step 1: Write failing test in CiudadTest.gd for biological baseline & demographic balance**

Add a test in `godot/scripts/CiudadTest.gd` checking the new demographic rates:
```gdscript
	print("\n=== TEST 31: Suelo biológico de consumo y balance metabólico ===")
	assert(Ajustes.CIUDAD_TIPOS_POBLACION["investigador"]["comida"] == 2.0, "investigador debe consumir 2.0 comida/h")
	assert(Ajustes.CIUDAD_TIPOS_POBLACION["ciudadano"]["x_cama"] == 4, "ciudadano x_cama debe ser 4")
	assert(Ajustes.CIUDAD_TIPOS_POBLACION["obrero"]["comida"] == 4.0, "obrero debe consumir 4.0 comida/h")
	assert(Ajustes.CIUDAD_TIPOS_POBLACION["tecnico"]["energia"] == 0.5, "tecnico debe consumir 0.5 energia/h")
	assert(Ajustes.CIUDAD_TIPOS_POBLACION["especialista"]["combustible"] == 1.0, "especialista debe consumir 1.0 combustible/h")
	assert(Ajustes.CIUDAD_TIPOS_POBLACION["militar"]["comida"] == 3.0, "militar base debe consumir 3.0 comida/h")
```
Also update `TEST 13` in `CiudadTest.gd`: since `ciudadano.x_cama` changes from 5 to 4 (each takes 0.25 beds instead of 0.20), in 4 beds with 1 obrero (1.0), 1 tecnico (1.0) and 1.33 militar, remaining bed space is 0.666; with 0.25 per ciudadano, only 2 fit (0.5 beds) instead of 3 (0.75 beds):
```gdscript
	assert(orden_test.demografia["desempleado"] == 0, "los desempleados se desahucian primero")
	assert(orden_test.demografia["ciudadano"] == 2, "luego los ciudadanos con x_cama 4, solo los necesarios")
	assert(orden_test.desahuciados == 10)
```

- [ ] **Step 2: Run test to verify failure**

Run:
```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/CiudadTest.tscn"
```
Expected: FAIL with assertion failed on `Ajustes.CIUDAD_TIPOS_POBLACION["investigador"]["comida"] == 2.0`.

- [ ] **Step 3: Update `godot/scripts/ajustes.gd`**

Update `CIUDAD_TIPOS_POBLACION` and add the balance constants:
```gdscript
static var CIUDAD_TIPOS_POBLACION: Dictionary = {
	"ciudadano": {"comida": 2.0, "combustible": 0.0, "energia": 0.0, "x_cama": 4},
	"desempleado": {"comida": 3.0, "combustible": 0.0, "energia": 0.0, "x_cama": 4},
	"obrero": {"comida": 4.0, "combustible": 0.0, "energia": 0.0, "x_cama": 4},
	"tecnico": {"comida": 3.0, "combustible": 0.0, "energia": 0.5, "x_cama": 3},
	"especialista": {"comida": 2.0, "combustible": 1.0, "energia": 1.0, "x_cama": 2},
	"investigador": {"comida": 2.0, "combustible": 0.0, "energia": 2.0, "x_cama": 1},
	"militar": {"comida": 3.0, "combustible": 1.0, "energia": 0.0, "x_cama": 3},
}

## Gasto adicional para militares desplegados en el exterior
static var MILITAR_CONSUMO_COMIDA_DESPLEGADO: float = 5.0
static var MILITAR_CONSUMO_COMBUSTIBLE_DESPLEGADO: float = 2.0

## Orden de consumo de sub-categorías de comida (fresco a no perecedero)
static var CIUDAD_ORDEN_CONSUMO_COMIDA: Array = [
	"pesca",
	"recoleccion_caza",
	"sembradios",
	"granjas_animales",
	"hidroponia",
	"sintetico",
]

## Monocultivo y variedad dietética
static var CIUDAD_GRACIA_MONOCULTIVO_HORAS: int = 360
static var CIUDAD_PENALIZACION_MONOCULTIVO_MORAL: float = -0.2
static var CIUDAD_BONO_DIETA_2_3_FUENTES: float = 0.3
static var CIUDAD_BONO_DIETA_4_5_FUENTES: float = 1.0
static var CIUDAD_BONO_DIETA_6_FUENTES: float = 2.0

## Suelo mínimo de productividad para comida
static var PRODUCTIVIDAD_SUELO_ALIMENTOS: float = 0.75

## Decreto de Racionamiento Estricto
static var RACIONAMIENTO_REDUCCION_CONSUMO: float = 0.35
static var RACIONAMIENTO_TECHO_MORAL: float = 35.0
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/CiudadTest.tscn"
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/ajustes.gd godot/scripts/CiudadTest.gd
git commit -m "feat(balance): actualizar tasas de consumo demografico y constantes de balance alimentario"
```

---

### Task 2: Sub-inventario de Comida y Cascada Estratificada de Consumo

**Files:**
- Modify: `godot/scripts/Ciudad.gd:170-260, 1010-1040`
- Modify: `godot/scripts/Economia.gd:805-820`
- Modify: `godot/scripts/Colonos.gd:1250-1265`
- Test: `godot/scripts/CiudadTest.gd`

**Interfaces:**
- Consumes: `Ajustes.CIUDAD_ORDEN_CONSUMO_COMIDA`, `Ajustes.CIUDAD_COMIDA_INICIAL`
- Produces: `Ciudad.sub_almacen_comida: Dictionary`, `Ciudad.ingresar_comida_estratificada(cantidad, categoria)`, `Ciudad._descontar_comida_estratificada(cantidad_requerida) -> bool`, `Economia.entregar(carga, origen_categoria)`

- [ ] **Step 1: Write failing test in CiudadTest.gd for food sub-inventory and consumption cascade**

Add in `godot/scripts/CiudadTest.gd`:
```gdscript
	print("\n=== TEST 32: Cascada de Consumo Estratificada de Comida ===")
	var ciu32: Node = CiudadScript.new()
	ciu32.sub_almacen_comida = {
		"pesca": 20.0,
		"recoleccion_caza": 30.0,
		"sembradios": 50.0,
		"granjas_animales": 0.0,
		"hidroponia": 0.0,
		"sintetico": 0.0,
	}
	ciu32.almacen["comida"].cantidad = 100.0
	# Consumir 35 unidades: agota pesca (20), toma 15 de recoleccion_caza (quedan 15), sembradios intacto (50)
	var exito_32: bool = ciu32._descontar_comida_estratificada(35.0)
	assert(exito_32, "consumo estratificado debe ser exitoso")
	assert(is_equal_approx(ciu32.sub_almacen_comida["pesca"], 0.0), "pesca debe agotarse primero")
	assert(is_equal_approx(ciu32.sub_almacen_comida["recoleccion_caza"], 15.0), "recoleccion_caza debe quedar en 15.0")
	assert(is_equal_approx(ciu32.sub_almacen_comida["sembradios"], 50.0), "sembradios no debe tocarse")
	assert(is_equal_approx(ciu32.almacen["comida"].cantidad, 65.0), "stock unificado debe reflejar 65.0")

	# Review Focus 1: Si hay hambruna total, sub_almacen_comida se resetea a cero
	ciu32._descontar_comida_estratificada(100.0) # excede 65.0
	for cat in ciu32.sub_almacen_comida:
		assert(ciu32.sub_almacen_comida[cat] == 0.0, "hambruna debe limpiar sub_almacen_comida")

	# Review Focus 3: Ingreso sin categoría o categoría desconocida va a recoleccion_caza
	ciu32.ingresar_comida_estratificada(10.0, "desconocida")
	assert(is_equal_approx(ciu32.sub_almacen_comida["recoleccion_caza"], 10.0))
```

- [ ] **Step 2: Run test to verify failure**

Run:
```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/CiudadTest.tscn"
```
Expected: FAIL (`_descontar_comida_estratificada` not defined).

- [ ] **Step 3: Implement sub-inventory and cascade in `Ciudad.gd` and delivery hooks**

In `godot/scripts/Ciudad.gd`:
```gdscript
var sub_almacen_comida: Dictionary = {
	"pesca": 0.0,
	"recoleccion_caza": 0.0,
	"sembradios": 0.0,
	"granjas_animales": 0.0,
	"hidroponia": 0.0,
	"sintetico": 0.0,
}
```
In `Ciudad._init()`:
```gdscript
	sub_almacen_comida["recoleccion_caza"] = COMIDA_INICIAL * 0.5
	sub_almacen_comida["pesca"] = COMIDA_INICIAL * 0.5
```
Add methods:
```gdscript
func ingresar_comida_estratificada(cantidad: float, categoria: String = "recoleccion_caza") -> void:
	if cantidad <= 0.0:
		return
	var cat: String = categoria if sub_almacen_comida.has(categoria) else "recoleccion_caza"
	sub_almacen_comida[cat] = sub_almacen_comida.get(cat, 0.0) + cantidad


func _descontar_comida_estratificada(cantidad_requerida: float) -> bool:
	var restante := cantidad_requerida
	for cat in Ajustes.CIUDAD_ORDEN_CONSUMO_COMIDA:
		var disponible: float = sub_almacen_comida.get(cat, 0.0)
		if disponible <= 0.0:
			continue
		var tomar: float = minf(disponible, restante)
		sub_almacen_comida[cat] -= tomar
		restante -= tomar
		if restante <= 1e-5:
			break

	var exito: bool = (almacen["comida"] as Recurso).consumir(cantidad_requerida)
	if not exito:
		for cat in sub_almacen_comida:
			sub_almacen_comida[cat] = 0.0
	return exito
```
In `Ciudad.simular_tick()`, replace `(almacen["comida"] as Recurso).consumir(gasto_total)` with:
```gdscript
	var exito_comida: bool = _descontar_comida_estratificada(gasto_total)
```
In `godot/scripts/Economia.gd`, update `entregar(carga: Dictionary, origen_categoria: String = "")`:
```gdscript
func entregar(carga: Dictionary, origen_categoria: String = "") -> void:
	for recurso in carga:
		if ciudad != null and ciudad.almacen.has(recurso):
			ciudad.almacen[recurso].agregar(carga[recurso])
			if recurso == "comida" and ciudad.has_method("ingresar_comida_estratificada"):
				ciudad.ingresar_comida_estratificada(carga[recurso], origen_categoria)
```
Add helper in `Economia.gd`:
```gdscript
func categoria_comida_de_puesto(esquina: Vector2i) -> String:
	if not puestos.has(esquina):
		return "recoleccion_caza"
	var t: String = puestos[esquina].get("tipo", "")
	match t:
		"pesca_frutos_mar": return "pesca"
		"caza_recoleccion": return "recoleccion_caza"
		"sembradios": return "sembradios"
		"granjas_animales": return "granjas_animales"
		"hidroponia": return "hidroponia"
		"sintetico": return "sintetico"
		_: return "recoleccion_caza"
```
In `godot/scripts/Colonos.gd:1255-1260`:
```gdscript
	var huella_nucleo: Array = zona.huella_del_nucleo()
	if _junto_a(c["celda"], huella_nucleo):
		var esq: Vector2i = c.get("trabajo", {}).get("puesto", Recoleccion.SIN_PUESTO)
		var cat_comida: String = economia.categoria_comida_de_puesto(esq)
		economia.entregar(c["carga"], cat_comida)
		c["carga"] = {}
		return true
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/CiudadTest.tscn"
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Ciudad.gd godot/scripts/Economia.gd godot/scripts/Colonos.gd godot/scripts/CiudadTest.gd
git commit -m "feat(economia): sub-almacen de comida y consumo estratificado por perecibilidad"
```

---

### Task 3: Monocultivo (Gracia 360h) y Escala de Bonificaciones de Dieta

**Files:**
- Modify: `godot/scripts/Ciudad.gd:580-600, 1120-1145`
- Modify: `godot/scripts/VentanaMoral.gd:340-350`
- Test: `godot/scripts/CiudadTest.gd`

**Interfaces:**
- Consumes: `sub_almacen_comida`, `Ajustes.CIUDAD_GRACIA_MONOCULTIVO_HORAS`, `Ajustes.CIUDAD_PENALIZACION_MONOCULTIVO_MORAL`, `Ajustes.CIUDAD_BONO_DIETA_2_3_FUENTES`, `Ajustes.CIUDAD_BONO_DIETA_4_5_FUENTES`, `Ajustes.CIUDAD_BONO_DIETA_6_FUENTES`
- Produces: `Ciudad.horas_monocultivo_continuo: int`, `Ciudad.fuentes_comida_en_reserva() -> int`, `Ciudad.delta_dieta_actual() -> float`

- [ ] **Step 1: Write failing test in CiudadTest.gd for monoculture grace and diet scale**

Add in `godot/scripts/CiudadTest.gd`:
```gdscript
	print("\n=== TEST 33: Gracia de Monocultivo (360h) y Escala de Dieta ===")
	var ciu33: Node = CiudadScript.new()
	ciu33.migracion_activa = false
	ciu33.demografia["obrero"] = 1
	ciu33.registrar_edificio_residencial(1, [2, 2])
	ciu33.sub_almacen_comida = {"recoleccion_caza": 10000.0, "pesca": 0.0, "sembradios": 0.0, "granjas_animales": 0.0, "hidroponia": 0.0, "sintetico": 0.0}
	ciu33.almacen["comida"].cantidad = 10000.0

	# 360 horas de monocultivo dentro de la gracia
	for h in range(360):
		ciu33.simular_tick(0.0)
	assert(ciu33.horas_monocultivo_continuo == 360, "debe acumular 360 horas de monocultivo")
	assert(ciu33.delta_dieta_actual() == 0.0, "dentro de la gracia de 360h no hay penalización")

	# Hora 361: se activa la penalización de monocultivo (-0.2/h)
	ciu33.simular_tick(0.0)
	assert(ciu33.horas_monocultivo_continuo == 361)
	assert(is_equal_approx(ciu33.delta_dieta_actual(), -0.2), "a partir de 361h aplica penalización de -0.2")

	# Review Focus 2: Agregar una 2da fuente resetea el contador y da bono de +0.3
	ciu33.sub_almacen_comida["pesca"] = 50.0
	ciu33.simular_tick(0.0)
	assert(ciu33.horas_monocultivo_continuo == 0, "segunda fuente resetea contador de monocultivo")
	assert(is_equal_approx(ciu33.delta_dieta_actual(), 0.3), "2 fuentes otorgan bono +0.3/h")
```

- [ ] **Step 2: Run test to verify failure**

Run:
```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/CiudadTest.tscn"
```
Expected: FAIL (`delta_dieta_actual` or `horas_monocultivo_continuo` not defined).

- [ ] **Step 3: Implement monoculture tracking and diet scale in `Ciudad.gd` and `VentanaMoral.gd`**

In `godot/scripts/Ciudad.gd`:
```gdscript
var horas_monocultivo_continuo: int = 0

func fuentes_comida_en_reserva() -> int:
	var c := 0
	for cat in sub_almacen_comida:
		if sub_almacen_comida[cat] > 0.0:
			c += 1
	return c


func delta_dieta_actual() -> float:
	var activas: int = fuentes_comida_en_reserva()
	if activas == 0:
		return 0.0
	if activas == 1:
		if horas_monocultivo_continuo > Ajustes.CIUDAD_GRACIA_MONOCULTIVO_HORAS:
			return Ajustes.CIUDAD_PENALIZACION_MONOCULTIVO_MORAL
		return 0.0
	if activas <= 3:
		return Ajustes.CIUDAD_BONO_DIETA_2_3_FUENTES
	if activas <= 5:
		return Ajustes.CIUDAD_BONO_DIETA_4_5_FUENTES
	return Ajustes.CIUDAD_BONO_DIETA_6_FUENTES
```
In `actualizar_bono_variedad()`:
```gdscript
func actualizar_bono_variedad() -> void:
	var activas: int = fuentes_comida_en_reserva()
	if activas == 1:
		horas_monocultivo_continuo += 1
	elif activas > 1:
		horas_monocultivo_continuo = 0
```
In `simular_tick()`:
Replace `var delta_dieta: float = ...` with:
```gdscript
	var delta_dieta: float = delta_dieta_actual()
```
In `godot/scripts/VentanaMoral.gd:340-348`:
```gdscript
	var activas_dieta: int = Ciudad.fuentes_comida_en_reserva() if ("fuentes_comida_en_reserva" in Ciudad) else 0
	var delta_d: float = Ciudad.delta_dieta_actual() if ("delta_dieta_actual" in Ciudad) else 0.0
	var tasa_dieta_dia: float = delta_d * 24.0
	if activas_dieta == 1 and Ciudad.horas_monocultivo_continuo > Ajustes.CIUDAD_GRACIA_MONOCULTIVO_HORAS:
		_lbl_factor_dieta.text = "  Variedad (Monocultivo crítico): %+.2f/día" % tasa_dieta_dia
	else:
		_lbl_factor_dieta.text = "  Variedad de alimentos (%d/6 grupos): %+.2f/día" % [activas_dieta, tasa_dieta_dia]
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/CiudadTest.tscn"
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Ciudad.gd godot/scripts/VentanaMoral.gd godot/scripts/CiudadTest.gd
git commit -m "feat(moral): regla de monocultivo con gracia de 360h y bonificaciones escalonadas de dieta"
```

---

### Task 4: Suelo de Productividad Agraria ($X_{\text{alimentos}} \ge 0.75$)

**Files:**
- Modify: `godot/scripts/Ciudad.gd:485-488`
- Modify: `godot/scripts/Economia.gd:445-467`
- Test: `godot/scripts/CiudadTest.gd`
- Test: `godot/scripts/EconomiaTest.gd`

**Interfaces:**
- Consumes: `Ajustes.PRODUCTIVIDAD_SUELO_ALIMENTOS`, `Ajustes.CIUDAD_PRODUCTIVIDAD_BASE`, `Ajustes.CIUDAD_PRODUCTIVIDAD_EXPONENCIAL_BASE`, `Ajustes.CIUDAD_PRODUCTIVIDAD_DIVISOR_MORAL`
- Produces: `Ciudad.calcular_multiplicador_productividad(p_moral, es_recurso_alimento) -> float`, `Economia.produccion_por_hora(esquina)` with food rate shielding.

- [ ] **Step 1: Write failing tests in CiudadTest.gd and EconomiaTest.gd**

In `godot/scripts/CiudadTest.gd`:
```gdscript
	print("\n=== TEST 34: Suelo de Productividad Agraria ===")
	assert(is_equal_approx(CiudadScript.calcular_multiplicador_productividad(0.0, false), 0.5), "moral 0 general debe ser 0.5")
	assert(is_equal_approx(CiudadScript.calcular_multiplicador_productividad(0.0, true), 0.75), "moral 0 alimento debe tener suelo de 0.75")
	assert(is_equal_approx(CiudadScript.calcular_multiplicador_productividad(50.0, true), 1.0), "moral 50 alimento rinde 1.0")
	assert(is_equal_approx(CiudadScript.calcular_multiplicador_productividad(100.0, true), 2.0), "moral 100 alimento rinde 2.0")
```
In `godot/scripts/EconomiaTest.gd`:
```gdscript
	print("\n=== TEST 44: Productividad protegida para puestos de comida a moral cero ===")
	var c_m0: Node = CiudadScript.new()
	c_m0.moral = 0.0
	var e_m0: Node = _nueva(c_m0)
	# Maderero (no alimento): rinde a 0.5x
	var prod_mad: Dictionary = e_m0.produccion_por_hora(ESQ)
	assert(is_equal_approx(prod_mad["madera"], 3.0 * 0.5), "maderero a moral 0 rinde a 0.5x")
	# Puesto de caza (alimento): rinde a 0.75x mínimo
	e_m0.registrar_puesto(Vector2i(60, 60), "caza_recoleccion", 4, 4, {"caza": 4.0})
	e_m0.asignar(Vector2i(60, 60), "recolector", 1)
	e_m0.marcar_presente(1, true)
	var prod_caza: Dictionary = e_m0.produccion_por_hora(Vector2i(60, 60))
	assert(is_equal_approx(prod_caza["comida"], 4.0 * 0.75), "puesto de comida a moral 0 rinde al 0.75x")
```

- [ ] **Step 2: Run tests to verify failure**

Run:
```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/CiudadTest.tscn"
```
Expected: FAIL (`calcular_multiplicador_productividad` takes only 1 arg or doesn't clamp to 0.75).

- [ ] **Step 3: Implement productivity floor in `Ciudad.gd` and `Economia.gd`**

In `godot/scripts/Ciudad.gd:485`:
```gdscript
static func calcular_multiplicador_productividad(p_moral: float, es_recurso_alimento: bool = false) -> float:
	var x: float = PRODUCTIVIDAD_BASE * pow(PRODUCTIVIDAD_EXPONENCIAL_BASE, clampf(p_moral, 0.0, 100.0) / PRODUCTIVIDAD_DIVISOR_MORAL)
	if es_recurso_alimento:
		return maxf(Ajustes.PRODUCTIVIDAD_SUELO_ALIMENTOS, x)
	return x
```
In `godot/scripts/Economia.gd: produccion_por_hora(esquina)`:
```gdscript
	var p: Dictionary = puestos[esquina]
	var presentes: int = p["presentes"].size()
	var multiplicador: float = Recoleccion.multiplicador_de_nivel(p["tipo"], p["nivel"])
	for clave in p["tasas"]:
		var recurso: String = RECURSO_DE_TASA.get(clave, clave)
		var es_alimento: bool = (recurso == "comida")
		var factor_moral: float = 1.0
		if ciudad != null and ciudad.has_method("calcular_multiplicador_productividad"):
			factor_moral = ciudad.calcular_multiplicador_productividad(ciudad.moral, es_alimento)
		resultado[recurso] = resultado.get(recurso, 0.0) + p["tasas"][clave] * presentes * multiplicador * factor_moral
	return resultado
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/EconomiaTest.tscn"
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/CiudadTest.tscn"
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Ciudad.gd godot/scripts/Economia.gd godot/scripts/CiudadTest.gd godot/scripts/EconomiaTest.gd
git commit -m "feat(economia): suelo de productividad del 75% para alimentos y recoleccion"
```

---

### Task 5: Consumo Dinámico Militar (Guarnición vs. Despliegue Exterior)

**Files:**
- Modify: `godot/scripts/Colonos.gd:1450-1480`
- Modify: `godot/scripts/Ciudad.gd:1015-1035`
- Test: `godot/scripts/ColonosTest.gd`
- Test: `godot/scripts/CiudadTest.gd`

**Interfaces:**
- Consumes: `Zonificacion.dentro_de_influencia(celda2d)`, `Ajustes.MILITAR_CONSUMO_COMIDA_DESPLEGADO`, `Ajustes.MILITAR_CONSUMO_COMBUSTIBLE_DESPLEGADO`
- Produces: `Colonos.contar_militares_desplegados(zonif) -> int`, `Ciudad.conteo_militares_desplegados() -> int`

- [ ] **Step 1: Write failing test in ColonosTest.gd and CiudadTest.gd**

In `godot/scripts/ColonosTest.gd`:
```gdscript
	print("\n=== TEST 25: Conteo de Militares Desplegados fuera de Influencia ===")
	var col_m := ColonosScript.new()
	col_m.colonos[1] = {"id": 1, "tipo": "militar", "celda": Vector3i(10, 1, 10)}
	col_m.colonos[2] = {"id": 2, "tipo": "militar", "celda": Vector3i(200, 1, 200)}
	col_m.colonos[3] = {"id": 3, "tipo": "obrero", "celda": Vector3i(300, 1, 300)}
	var zonif_falsa = RefCounted.new()
	zonif_falsa.set_script(load("res://scripts/Zonificacion.gd"))
	zonif_falsa.nucleo_declarado = true
	zonif_falsa._caja_nucleo = {"min": Vector2i(0, 0), "max": Vector2i(20, 20)}
	assert(col_m.contar_militares_desplegados(zonif_falsa) == 1, "colono 2 esta fuera de influencia")

	# Review Focus 5: Si no hay nucleo declarado, todos los militares cuentan como desplegados
	zonif_falsa.nucleo_declarado = false
	assert(col_m.contar_militares_desplegados(zonif_falsa) == 2, "sin nucleo todos estan desplegados")
```
In `godot/scripts/CiudadTest.gd`:
```gdscript
	print("\n=== TEST 35: Gasto de Comida de Militares en Guarnición vs Desplegados ===")
	var ciu35: Node = CiudadScript.new()
	ciu35.migracion_activa = false
	ciu35.registrar_edificio_residencial(1, [2, 2])
	ciu35.demografia["militar"] = 2
	ciu35.almacen["comida"].cantidad = 5000.0
	# Sin militares desplegados: 2 militares * 3.0 = 6.0
	ciu35.militares_desplegados_override = 0
	var res_guarnicion = ciu35.simular_tick(0.0)
	assert(is_equal_approx(res_guarnicion["gasto_comida"], 6.0))
	# Con 1 militar desplegado: 1 * 3.0 (guarnición) + 1 * 5.0 (desplegado) = 8.0
	ciu35.militares_desplegados_override = 1
	var res_desplegado = ciu35.simular_tick(0.0)
	assert(is_equal_approx(res_desplegado["gasto_comida"], 8.0))
```

- [ ] **Step 2: Run tests to verify failure**

Run:
```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/ColonosTest.tscn"
```
Expected: FAIL (`contar_militares_desplegados` not defined).

- [ ] **Step 3: Implement military tracking and consumption**

In `godot/scripts/Colonos.gd`:
```gdscript
func contar_militares_desplegados(zonif: Object = null) -> int:
	var z: Object = zonif if zonif != null else (zonificacion if zonificacion != null else (get_node_or_null("/root/Zonificacion") as Object))
	if z == null:
		return 0
	var desplegados := 0
	for c in colonos.values():
		if c.get("tipo", "") == "militar":
			var celda2d := Vector2i(c["celda"].x, c["celda"].z)
			if not z.dentro_de_influencia(celda2d):
				desplegados += 1
	return desplegados
```
In `godot/scripts/Ciudad.gd`:
```gdscript
var militares_desplegados_override: int = -1

func conteo_militares_desplegados() -> int:
	if militares_desplegados_override >= 0:
		return min(militares_desplegados_override, demografia.get("militar", 0))
	var col = get_node_or_null("/root/Colonos")
	if col != null and col.has_method("contar_militares_desplegados"):
		return min(col.contar_militares_desplegados(), demografia.get("militar", 0))
	return 0
```
In `Ciudad.simular_tick()`:
```gdscript
	var gasto_poblacion := 0.0
	for tipo in demografia:
		gasto_poblacion += demografia[tipo] * TIPOS_POBLACION[tipo]["comida"]
	gasto_poblacion += sin_techo * TIPOS_POBLACION["desempleado"]["comida"]
	var des: int = conteo_militares_desplegados()
	if des > 0:
		gasto_poblacion += des * (Ajustes.MILITAR_CONSUMO_COMIDA_DESPLEGADO - TIPOS_POBLACION["militar"]["comida"])
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/ColonosTest.tscn"
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/CiudadTest.tscn"
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Colonos.gd godot/scripts/Ciudad.gd godot/scripts/ColonosTest.gd godot/scripts/CiudadTest.gd
git commit -m "feat(demografia): consumo dinamico militar segun area de influencia"
```

---

### Task 6: Decreto de Racionamiento Estricto e Integración en HUD/UI

**Files:**
- Modify: `godot/scripts/Ciudad.gd:1010-1045, 1140-1150`
- Modify: `godot/scripts/PanelEdificio.gd:470-500`
- Modify: `godot/scripts/VentanaAlmacen.gd:90-105`
- Modify: `godot/scripts/strings.gd:330-360`
- Test: `godot/scripts/CiudadTest.gd`
- Test: `godot/scripts/HUDTest.gd`

**Interfaces:**
- Consumes: `Ajustes.RACIONAMIENTO_REDUCCION_CONSUMO`, `Ajustes.RACIONAMIENTO_TECHO_MORAL`
- Produces: `Ciudad.decreto_racionamiento_activo: bool`, `Ciudad.alternar_decreto_racionamiento() -> bool`, `PanelEdificio._btn_racionamiento`, `VentanaAlmacen` tooltip/breakdown of food categories.

- [ ] **Step 1: Write failing test in CiudadTest.gd and HUDTest.gd for rationing decree**

In `godot/scripts/CiudadTest.gd`:
```gdscript
	print("\n=== TEST 36: Decreto Cívico de Racionamiento Estricto ===")
	var ciu36: Node = CiudadScript.new()
	ciu36.migracion_activa = false
	ciu36.registrar_edificio_residencial(1, [2, 2])
	ciu36.demografia["obrero"] = 10  # 10 * 4.0 = 40.0 comida base
	ciu36.moral = 80.0
	ciu36.almacen["comida"].cantidad = 5000.0

	ciu36.alternar_decreto_racionamiento()
	assert(ciu36.decreto_racionamiento_activo, "decreto debe estar activo")

	var res36 = ciu36.simular_tick(0.0)
	# Reducción del 35%: 40.0 * (1.0 - 0.35) = 26.0
	assert(is_equal_approx(res36["gasto_comida"], 26.0), "consumo debe reducirse un 35%")
	# Review Focus 4: Moral limitada estrictamente a 35.0 máximo
	assert(ciu36.moral <= 35.0, "moral bajo racionamiento no puede exceder 35.0")
```
In `godot/scripts/HUDTest.gd`:
```gdscript
	print("\n=== TEST: Boton de Racionamiento en PanelEdificio del Núcleo ===")
	var panel_ed := PanelEdificioScript.new()
	add_child(panel_ed)
	assert(panel_ed._btn_racionamiento != null)
```

- [ ] **Step 2: Run test to verify failure**

Run:
```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/CiudadTest.tscn"
```
Expected: FAIL (`alternar_decreto_racionamiento` not defined).

- [ ] **Step 3: Implement decree in `Ciudad.gd`, `PanelEdificio.gd`, `VentanaAlmacen.gd`, `strings.gd`**

In `godot/scripts/strings.gd`:
```gdscript
static var PANEL_EDIFICIO_RACIONAMIENTO_INACTIVO: String = "Racionamiento: Inactivo"
static var PANEL_EDIFICIO_RACIONAMIENTO_ACTIVO: String = "Racionamiento: Activo (-35% comida, moral máx. 35)"
static var PANEL_EDIFICIO_RACIONAMIENTO_TOOLTIP: String = "Reduce el consumo de comida un 35% a costa de fijar el límite superior de moral en 35."
```
In `godot/scripts/Ciudad.gd`:
```gdscript
var decreto_racionamiento_activo: bool = false

func alternar_decreto_racionamiento() -> bool:
	decreto_racionamiento_activo = not decreto_racionamiento_activo
	return decreto_racionamiento_activo
```
In `Ciudad.simular_tick()`:
```gdscript
	if decreto_racionamiento_activo:
		gasto_total *= (1.0 - Ajustes.RACIONAMIENTO_REDUCCION_CONSUMO)
```
And right after moral clamp:
```gdscript
	moral = clampf(moral + tasa_cambio_moral / 24.0, 0.0, 100.0)
	if decreto_racionamiento_activo:
		moral = minf(moral, Ajustes.RACIONAMIENTO_TECHO_MORAL)
```
In `godot/scripts/PanelEdificio.gd`:
Declare `_btn_racionamiento := Button.new()`.
In `_ready()`: add to buttons container and connect pressed to toggle `ciudad.alternar_decreto_racionamiento()`.
In `_actualizar()`:
```gdscript
	if es_nucleo and estado == "completo":
		_btn_racionamiento.visible = true
		if ciudad != null and ciudad.get("decreto_racionamiento_activo"):
			_btn_racionamiento.text = Strings.PANEL_EDIFICIO_RACIONAMIENTO_ACTIVO
		else:
			_btn_racionamiento.text = Strings.PANEL_EDIFICIO_RACIONAMIENTO_INACTIVO
		_btn_racionamiento.tooltip_text = Strings.PANEL_EDIFICIO_RACIONAMIENTO_TOOLTIP
	else:
		_btn_racionamiento.visible = false
```
In `godot/scripts/VentanaAlmacen.gd`:
When `clave == "comida"` and `Ciudad.has_method("fuentes_comida_en_reserva")`:
Add descriptive tooltip or sub-text detailing the 6 categories:
```gdscript
		if clave == "comida" and "sub_almacen_comida" in Ciudad:
			var partes_c: Array[String] = []
			for sub_cat in Ajustes.CIUDAD_ORDEN_CONSUMO_COMIDA:
				var cant_sc: float = Ciudad.sub_almacen_comida.get(sub_cat, 0.0)
				if cant_sc > 0.0:
					partes_c.append("%s: %.0f" % [sub_cat.capitalize(), cant_sc])
			if not partes_c.is_empty():
				etiqueta.tooltip_text = "Reservas por fuente:\n  " + "\n  ".join(partes_c)
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```powershell
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/CiudadTest.tscn"
powershell -Command "& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --fixed-fps 60 --quit-after 600 scenes/HUDTest.tscn"
```
Expected: PASS.

- [ ] **Step 5: Run full test suite**

Run:
```powershell
powershell -ExecutionPolicy Bypass -File tools/run-godot-tests.ps1
```
Expected: All 28 test suites pass.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/Ciudad.gd godot/scripts/PanelEdificio.gd godot/scripts/VentanaAlmacen.gd godot/scripts/strings.gd godot/scripts/CiudadTest.gd godot/scripts/HUDTest.gd
git commit -m "feat(civico): decreto de racionamiento estricto e integracion en panel de nucleo y almacen"
```

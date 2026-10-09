# Puestos Extractores y Modificación de Refinerías (Etapa 9.2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar los puestos de bombeo de agua superficial (`estacion_bombeo`) y extracción subterránea (`centro_extraccion` con tubería de hierro dinámica y agotamiento de crudo), el edificio de almacenamiento (`almacen` con 6 puertos de líquidos), la supresión total de acarreo de líquidos y el selector de combustible de la central termoeléctrica.

**Architecture:** Se definen las plantillas 3D de los nuevos puestos y se actualizan las de refinerías con caracteres mapeados a los 6 bloques de puertos en `PlantillasPuesto.gd`. En `CamaraCenital.gd` se valida la profundidad $\ge 2$ para la estación de bombeo y se escanea el pozo subterráneo para el centro de extracción, sumando el costo dinámico de `estructura_hierro` según la profundidad del pozo. En `Economia.gd` se prohíbe el acarreo de recursos líquidos, se restringen los roles a técnicos en los puestos de líquidos, y se añade el selector de combustible a la central termoeléctrica. En `VoxelWorld.gd` se coloca físicamente la tubería de hierro y se consumen los bloques de crudo del pozo en tiempo real durante la extracción.

**Tech Stack:** Godot 4 (GDScript), VoxelWorld (GridMap/MeshLibrary), Perlin 3D noise (GeneradorMundo), UI HUD (Control/Panel).

**Spec:** `docs/superpowers/specs/2026-10-08-puestos-extractores-y-refinerias-design.md`

## Global Constraints
- Trabajar en el worktree aislado `.worktrees/subsuelo-bloques` sobre la rama `feature/subsuelo-bloques`.
- No alterar ni romper los tests existentes de las 26 escenas de pruebas.
- Mantener las reglas de Ponytail: código minimalista, sin abstracciones no solicitadas, pruebas autocontenidas mediante aserciones claras.
- Prohibición absoluta de acarreo para `agua`, `crudo` y `combustible`.

## Review Focus
1. Una estación de bombeo colocada sobre agua con solo 1 bloque de profundidad debe ser rechazada.
2. Un centro de extracción colocado sin pozo subterráneo bajo su columna central debe ser rechazado.
3. El costo y reembolso de los bloques `estructura_hierro` de la tubería de perforación deben ser exactamente iguales a la profundidad $H$.
4. El agotamiento de crudo debe retirar bloques reales de crudo en `VoxelWorld` de arriba hacia abajo ($Y$ mayor a menor) sin tocar bloques de roca o tierra.
5. Cambiar el combustible en la central termoeléctrica a combustible líquido o crudo debe desalojar/liberar a los acarreadores y anular solicitudes de carbón.

---

### Task 1: Plantillas de Puestos y Mapeo de Puertos (`PlantillasPuesto.gd`)

**Files:**
- Modify: `godot/scripts/PlantillasPuesto.gd`
- Modify: `godot/scripts/PlantillasPuestoTest.gd`

- [ ] **Step 1: Escribir prueba fallida en `PlantillasPuestoTest.gd`**
  - Añadir pruebas que verifiquen:
    - Que `BLOQUES` contiene los caracteres `'1'` a `'6'` mapeados a los 6 tipos de puertos.
    - Que las plantillas `estacion_bombeo`, `centro_extraccion` y `almacen` existen y tienen las dimensiones correctas (4x6, 5x5, 5x5).
    - Que `almacen` contiene los 6 puertos en sus paredes exteriores y sus 2 puertas frontales.
    - Que `refineria_petrolera`, `productor_combustible` y `central_termoelectrica` tienen sus puertos correspondientes en su matriz de celdas.
- [ ] **Step 2: Ejecutar prueba para confirmar fallo**
  - Ejecutar escena `PlantillasPuestoTest.tscn` en Godot headless.
- [ ] **Step 3: Implementar cambios en `PlantillasPuesto.gd`**
  - Añadir mapeos de puertos `'1'` a `'6'` en `BLOQUES`.
  - Añadir materiales correspondientes en `MATERIAL` (`"estacion_bombeo": "bloque_madera"`, `"centro_extraccion": "estructura_hierro"`, `"almacen": "bloque_piedra"`).
  - Definir las capas 3D de `estacion_bombeo`, `centro_extraccion`, `almacen`.
  - Actualizar capas de `refineria_petrolera`, `productor_combustible`, `central_termoelectrica` con sus puertos.
- [ ] **Step 4: Ejecutar prueba y verificar éxito**
  - Ejecutar `PlantillasPuestoTest.tscn` y asegurar que pasa con 0 errores.

---

### Task 2: Supresión de Acarreo de Líquidos y Flujos Laborales (`Economia.gd`)

**Files:**
- Modify: `godot/scripts/Economia.gd`
- Modify: `godot/scripts/EconomiaTest.gd`

- [ ] **Step 1: Escribir prueba fallida en `EconomiaTest.gd`**
  - Comprobar que `insumos_a_cargar()` nunca devuelve recursos líquidos (`agua`, `crudo`, `combustible`).
  - Comprobar que `recoger()` y `recoger_producto()` no entregan líquidos a acarreadores.
  - Comprobar que `roles_de()` para `estacion_bombeo`, `centro_extraccion` y `refineria_petrolera` devuelve solo `["tecnico"]`.
  - Comprobar que `central_termoelectrica` con combustible `"carbon"` admite acarreadores, pero con `"combustible"` o `"crudo"` no admite acarreadores.
  - Comprobar que el puesto `almacen` transfiere ingresos líquidos a `Ciudad.almacen`.
- [ ] **Step 2: Ejecutar prueba para confirmar fallo**
  - Ejecutar escena `EconomiaTest.tscn`.
- [ ] **Step 3: Implementar supresión y roles en `Economia.gd`**
  - Definir `const RECURSOS_LIQUIDOS: Array[String] = ["agua", "crudo", "combustible"]`.
  - Filtrar recursos líquidos en `insumos_a_cargar()`, `cargar_insumo()`, `recoger()`, `recoger_producto()`.
  - Configurar roles y cupos de los nuevos puestos y refinerías.
  - Implementar propiedad y método `cambiar_combustible_central(esquina: Vector2i, combustible: String)` con liberación automática de acarreadores si no es carbón.
- [ ] **Step 4: Ejecutar prueba y verificar éxito**
  - Ejecutar `EconomiaTest.tscn` y confirmar paso limpio.

---

### Task 3: Detección, Perforación Dinámica y Previsualización (`CamaraCenital.gd`)

**Files:**
- Modify: `godot/scripts/CamaraCenital.gd`
- Modify: `godot/scripts/PuestosPrevisualizacionTest.gd`

- [ ] **Step 1: Escribir prueba fallida en `PuestosPrevisualizacionTest.gd`**
  - Probar validación de `estacion_bombeo`: rechazar si profundidad de agua $< 2$, aceptar si profundidad $\ge 2$.
  - Probar validación de `centro_extraccion`: rechazar si no hay pozo bajo la columna de perforación, aceptar y calcular $H$ bloques de hierro si hay pozo.
- [ ] **Step 2: Ejecutar prueba para confirmar fallo**
  - Ejecutar escena `PuestosPrevisualizacionTest.tscn`.
- [ ] **Step 3: Implementar validaciones en `CamaraCenital.gd` y categorías en `BarraModos.gd`**
  - En `CamaraCenital.gd`:
    - Añadir `estacion_bombeo` y `centro_extraccion` a `PUESTOS_PERIFERICO`.
    - Añadir `almacen` a `PUESTOS_INDUSTRIAL`, validando que se emplace dentro de la zona de influencia y sobre zona industrial (`fabricacion_militar`).
    - Validar `estacion_bombeo` (con regla de profundidad mínima de 2 bloques en agua bajo el muelle).
    - Validar `centro_extraccion` (escaneo de columna central hacia el subsuelo, cálculo de $H = Y_{sup} - Y_{fondo}$, adición dinámica de costo de $H \times \text{estructura\_hierro}$ y guardado de metadatos de perforación).
  - En `BarraModos.gd`:
    - Registrar `estacion_bombeo` (5) y `centro_extraccion` (6) en `CONSTRUCCIONES_POR_CATEGORIA["periferico"]`.
    - Registrar `almacen` (8) en `CONSTRUCCIONES_POR_CATEGORIA["industrial"]`.
- [ ] **Step 4: Ejecutar prueba y verificar éxito**
  - Ejecutar `PuestosPrevisualizacionTest.tscn` y verificar que pasa sin errores.

---

### Task 4: Colocación de Tubería, Extracción y Agotamiento de Crudo (`VoxelWorld.gd` & `Recoleccion.gd`)

**Files:**
- Modify: `godot/scripts/VoxelWorld.gd`
- Modify: `godot/scripts/Recoleccion.gd`
- Modify: `godot/scripts/ExtraccionTest.gd`

- [ ] **Step 1: Escribir prueba fallida en `ExtraccionTest.gd`**
  - Comprobar que al completar la obra de un `centro_extraccion`, se coloca la columna de `estructura_hierro` en el mundo desde la superficie hasta el fondo del pozo.
  - Comprobar que al deconstruir el `centro_extraccion`, se retiran los bloques de `estructura_hierro` y se reembolsan a `Ciudad.almacen`.
  - Comprobar que la extracción de crudo en `Recoleccion.gd` / `Economia.gd` elimina bloques reales de crudo de mayor $Y$ a menor $Y$ y decrementa el stock disponible del pozo.
  - Comprobar que al agotarse el pozo de crudo, el puesto se marca como agotado.
  - Comprobar que los pozos de agua no se agotan.
- [ ] **Step 2: Ejecutar prueba para confirmar fallo**
  - Ejecutar escena `ExtraccionTest.tscn`.
- [ ] **Step 3: Implementar tubería y agotamiento de crudo**
  - En `VoxelWorld.gd`: método `colocar_tuberia_extraccion(columna: Vector2i, y_sup: int, y_fondo: int) -> int` y `retirar_tuberia_extraccion(columna: Vector2i, y_sup: int, y_fondo: int) -> int`.
  - En `Recoleccion.gd`: método `siguiente_bloque_crudo_pozo(mundo: Object, columna_pozo: Vector2i, y_max: int, y_min: int) -> Vector3i` y `consumir_bloque_crudo()`.
  - Conectar el consumo de bloques de crudo con el ciclo de producción en `Economia.gd`.
- [ ] **Step 4: Ejecutar prueba y verificar éxito**
  - Ejecutar `ExtraccionTest.tscn` y asegurar que pasa sin errores.

---

### Task 5: Interfaz de Usuario y Paneles de Interacción (`PanelPuesto.gd` & `HUD.gd`)

**Files:**
- Modify: `godot/scripts/PanelPuesto.gd`
- Modify: `godot/scripts/HUD.gd`
- Modify: `godot/scripts/HUDTest.gd`

- [ ] **Step 1: Escribir prueba fallida en `HUDTest.gd`**
  - Probar que `PanelPuesto` renderiza la sección de puertos para edificios con puertos.
  - Probar que `PanelPuesto` para `central_termoelectrica` contiene los botones selectores de combustible (`Carbón`, `Combustible`, `Crudo`).
  - Probar que `PanelPuesto` para `centro_extraccion` muestra el recurso extraído y, si es crudo, la cantidad restante.
- [ ] **Step 2: Ejecutar prueba para confirmar fallo**
  - Ejecutar `HUDTest.tscn`.
- [ ] **Step 3: Implementar UI en `PanelPuesto.gd` y `HUD.gd`**
  - Añadir widgets para mostrar puertos del puesto/edificio.
  - Añadir selector interactivo de combustible para la central termoeléctrica conectado a `Economia.cambiar_combustible_central()`.
  - Añadir etiqueta de crudo restante para el centro de extracción.
- [ ] **Step 4: Ejecutar prueba y verificar éxito**
  - Ejecutar `HUDTest.tscn` y comprobar que pasa limpio.

---

### Task 6: Verificación de Suite Completa

**Files:**
- Todas las escenas de prueba del proyecto

- [ ] **Step 1: Ejecutar la suite completa de 26 escenas**
  - Ejecutar `pwsh -File tools/run-godot-tests.ps1 -ProjectPath .worktrees/subsuelo-bloques/godot`.
- [ ] **Step 2: Confirmar 0 errores y 0 regresiones**
  - Asegurar que todas las 26 escenas completan con estado `OK`.
- [ ] **Step 3: Revisión de git diff y estado**
  - Ejecutar `git status` y `git diff` para garantizar un árbol de trabajo limpio.

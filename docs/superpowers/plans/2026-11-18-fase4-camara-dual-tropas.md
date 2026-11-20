# Fase 4: Cámara Dual, Cuartel y Comando Híbrido (PoC 7) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar el subsistema militar y de comando dual de la Fase 4: edificio Cuartel `9×7×8` de 2 pisos con vivienda militar independiente, selección universal y panel de unidad en cámara cenital, órdenes tácticas (incluyendo `K` para atacar), modos de primera persona (`T` Construcción, `R` Batalla, `F` Comandante con clic izq./der. diferenciado y subgrupos `Shift + N`) y visuales procedurales.

**Architecture:** La lógica de vivienda militar (`Ciudad.gd`), entrenamiento por cohortes (`Recoleccion.gd`, `Economia.gd`), salud, posturas, órdenes y selección persistente (`Colonos.gd`) permanece 100 % desacoplada y testeable en modo headless. La capa visual e interactiva (`ColonosRenderer.gd`, `CamaraCenital.gd`, `Player.gd`, `HUD.gd`, `Hotbar.gd`, `PanelUnidad.gd`) consume señales y APIs puras de los autoloads.

**Tech Stack:** Godot 4.7 (GDScript), pruebas headless vía `tools/run-godot-tests.ps1`.

**Spec:** [`spec_fase4_camara_dual_tropas.md`](file:///C:/Users/peraz/.gemini/antigravity/brain/cfb4640e-bfaa-457c-a8c1-8af6ce7d574c/spec_fase4_camara_dual_tropas.md)

## Global Constraints

- **Vivienda militar:** `militar` ocupa `1/4` de cama (`x_cama = 4`) exclusivamente en **Cuarteles** (4 camas por cuartel = 16 militares); no consume camas residenciales.
- **Plantilla Cuartel:** `9×7×8` (+ losa base = 9 capas) fiel a `arte/dae/cuartel.dae` en `bloque_madera` + `bloque_piedra` + `vidrio` + `puerta` + 4 `cama` en el 2º piso. Ubicado en Zona B (`industrial_militar`).
- **Comportamiento post-graduación:** Los militares no merodean; quedan en guardia cerca de su cuartel salvo orden activa o postura defensiva ante enemigo (Fase 6).
- **Modos 1ª Persona:** `T` = Construcción, `R` = Batalla (armas + crosshair), `F` = Comandante (hotbar 1–6 con clic izq./der. diferenciado + subgrupos `Shift + N` a la izquierda).
- **Sin Pausa Táctica ni IA enemiga:** Diferidos explícitamente a Fase 6.
- **Regresión cero:** Las 36 escenas existentes + la nueva escena de prueba deben pasar al 100 % en `tools/run-godot-tests.ps1`.
- **i18n:** Todos los textos nuevos deben registrarse en ES y EN en `godot/scripts/strings.gd`.

## Execution Lines & Dependency Matrix

- **Line A (Core Simulación & Cuartel):** Task 1 -> Task 2 -> Task 3
  - Files: `ajustes.gd`, `strings.gd`, `Ciudad.gd`, `PlantillasPuesto.gd`, `Recoleccion.gd`, `Economia.gd`, `FinalizacionObras.gd`, `BarraModos.gd`, `IconosHUD.gd`, `Colonos.gd`, `GestorPartida.gd`
  - Local Tests: `CiudadTest.tscn`, `PlantillasPuestoTest.tscn`, `EconomiaTest.tscn`, `ColonosTest.tscn`, `GestorPartidaTest.tscn`
- **Line B (Interacción Cenital & UI de Unidad — tras Line A):** Task 4
  - Files: `PanelUnidad.gd` (nuevo), `HUD.gd`, `CamaraCenital.gd`
  - Local Tests: `CamaraCenitalModosTest.tscn`, `HUDTest.tscn`
- **Line C (Modos 1ª Persona & Visuales 3D — tras Task 3, en paralelo o tras Task 4):** Task 5 -> Task 6
  - Files: `Player.gd`, `Hotbar.gd`, `HUD.gd`, `ColonosRenderer.gd`, `PlayerCombateComandanteTest.gd/.tscn`
  - Local Tests: `PlayerCombateComandanteTest.tscn`
- **Global Integration Test:** `powershell -ExecutionPolicy Bypass -File tools\run-godot-tests.ps1` (37 escenas al 100 % en verde) + `graphify update .`.

## Review Focus

1. **Demolición de cuartel con soldados activos:** Si se demuele un cuartel y `demografia["militar"] > capacidad_militares`, no deben quedar militares huérfanos con capacidad negativa ni corromper `vivienda_ocupada`; el exceso se licencia a `desempleado` (si hay camas residenciales) o `sin_techo`.
2. **Selección mixta al alternar cámara (`C`):** Si en cenital se seleccionó un civil (obrero/técnico) y se pulsa `C` para ir a 1ª persona, la selección civil debe limpiarse (no intentar dar órdenes militares a un civil); si se seleccionaron militares, deben conservarse intactos.
3. **Muerte o retirada de unidad seleccionada / objetivo:** Si una unidad muere por fuego amigo (`K` + clic der. o Modo Batalla `R`), debe purgarse inmediatamente de `unidades_seleccionadas` y de las órdenes `"atacar"` / `"seguir"` que la referencien, sin errores de diccionario nulo.
4. **Clic derecho de "Moverse" (1 solo soldado) en Modo Comandante (`F`):** Si el grupo tiene `N` soldados y el jugador usa clic derecho en orden `4 (Moverse)`, exactamente 1 soldado recibe la orden de moverse y los otros `N - 1` conservan intactas sus órdenes previas (patrulla, seguimiento, guardia, etc.).
5. **Restauración limpia al cambiar a cenital o pulsar `T`/`Esc`:** Al pasar a cámara cenital (`C`) desde Modo Batalla (`R`) o Modo Comandante (`F`), `Player.salir_de_todas_las_herramientas()` debe restaurar la retícula estándar, la hotbar de bloques y limpiar estados temporales de ataque/orden.

---

### Task 1: Vivienda Militar en `Ciudad.gd` y Constantes/Strings de Fase 4

**Files:**
- Modify: `godot/scripts/ajustes.gd` (actualizar `CIUDAD_TIPOS_POBLACION["militar"]["x_cama"] = 4`, añadir `RECOLECCION_ESCUELAS["cuartel"]`, constantes de salud, daño, alcances y armamento base)
- Modify: `godot/scripts/strings.gd` (claves ES/EN para cuartel, rangos, posturas, órdenes, modos 1ª persona y panel de unidad)
- Modify: `godot/scripts/Ciudad.gd` (excluir `militar` de `vivienda_ocupada`, añadir `cuarteles_registrados`, `registrar_cuartel()`, `retirar_cuartel()`, `capacidad_camas_cuartel`, `capacidad_militares`, `plazas_militares_libres`, licenciamiento al retirar cuartel, y serialización en `exportar_estado()`/`importar_estado()`)
- Test: `godot/scripts/CiudadTest.gd`

**Interfaces:**
- Produces:
  - `Ciudad.registrar_cuartel(id: int, camas: int = 4) -> void`
  - `Ciudad.retirar_cuartel(id: int) -> void`
  - `Ciudad.capacidad_camas_cuartel: int`
  - `Ciudad.capacidad_militares: int`
  - `Ciudad.plazas_militares_libres: int`
  - `Ajustes.SALUD_CIVIL`, `Ajustes.SALUD_MILITAR`, `Ajustes.MILITAR_ALCANCE_ATAQUE`, `Ajustes.MILITAR_DANO_ATAQUE`, `Ajustes.MILITAR_COOLDOWN_ATAQUE`, `Ajustes.ARMAS_AVATAR`

- [ ] **Step 1:** Escribir test en `CiudadTest.gd` verificando: `militar` tiene `x_cama = 4`, no consume `vivienda_ocupada` residencial, `registrar_cuartel(id, 4)` habilita 16 plazas (`plazas_militares_libres`), y `retirar_cuartel(id)` licencia el exceso a `desempleado`/`sin_techo` (Review Focus #1).
- [ ] **Step 2:** Ejecutar `CiudadTest.tscn` headless y confirmar que falla antes de implementar.
- [ ] **Step 3:** Actualizar `ajustes.gd` (`x_cama = 4`, `RECOLECCION_ESCUELAS["cuartel"]`, constantes de salud/combate/armas), `strings.gd` (ES/EN) y `Ciudad.gd` (vivienda militar + persistencia).
- [ ] **Step 4:** Ejecutar `CiudadTest.tscn` y verificar que todas las pruebas pasan en verde.
- [ ] **Step 5:** Commit de Task 1.

---

### Task 2: Plantilla `cuartel` 9×7×8, Cohorte 4→4 y Registro en Zona B

**Files:**
- Modify: `godot/scripts/PlantillasPuesto.gd` (añadir `"P": "bloque_piedra"`, `"W": "bloque_madera"`, `"C": "cama"` a `BLOQUES`; añadir plantilla `"cuartel"` de `9×7×8` + losa base fiel a `arte/dae/cuartel.dae` con puerta frontal en `z = 0`, escalera interior y 4 camas en 2º piso)
- Modify: `godot/scripts/Recoleccion.gd` (incluir `"cuartel"` en `TIPOS_PUESTO_TRABAJO`, cupo 4, `es_cuartel()`)
- Modify: `godot/scripts/Economia.gd` (validar `Ciudad.plazas_militares_libres` al asignar reclutas en cuartel y emitir `cohorte_graduada` con 4→4)
- Modify: `godot/scripts/FinalizacionObras.gd` (al completar un `cuartel`, llamar `Ciudad.registrar_cuartel(id_edificio, 4)`; al demolerlo, `Ciudad.retirar_cuartel(id_edificio)`)
- Modify: `godot/scripts/BarraModos.gd` y `godot/scripts/IconosHUD.gd` (añadir botón `cuartel` en categoría Industrial / Zona B con ícono)
- Test: `godot/scripts/PlantillasPuestoTest.gd`, `godot/scripts/EconomiaTest.gd`

**Interfaces:**
- Consumes: `Ciudad.registrar_cuartel`, `Ciudad.retirar_cuartel`, `Ciudad.plazas_militares_libres`, `Ajustes.RECOLECCION_ESCUELAS["cuartel"]`.
- Produces: Plantilla `"cuartel"` en `PlantillasPuesto.PLANTILLAS`, puesto `"cuartel"` en `Economia`/`Recoleccion` y entrada de construcción en `BarraModos`.

- [ ] **Step 1:** Escribir tests en `PlantillasPuestoTest.gd` (dimensiones `9×7`, 9 capas, presencia de `bloque_madera`, `bloque_piedra`, `vidrio`, `puerta_inferior`, y 4 `cama` en 2º piso) y en `EconomiaTest.gd` (cohorte de cuartel 4 reclutas → 4 militares sin pérdida, bloqueo si no hay plazas militares libres).
- [ ] **Step 2:** Ejecutar `PlantillasPuestoTest.tscn` y `EconomiaTest.tscn` para confirmar fallo inicial.
- [ ] **Step 3:** Implementar la plantilla en `PlantillasPuesto.gd`, soporte en `Recoleccion.gd`, `Economia.gd`, `FinalizacionObras.gd`, `BarraModos.gd` e `IconosHUD.gd`.
- [ ] **Step 4:** Ejecutar `PlantillasPuestoTest.tscn`, `EconomiaTest.tscn`, `ObrasTest.tscn` y `HUDTest.tscn` hasta pasar en verde.
- [ ] **Step 5:** Commit de Task 2.

---

### Task 3: Salud, Posturas, Órdenes Militares, Selección Persistente y Persistencia (`Colonos.gd`)

**Files:**
- Modify: `godot/scripts/Colonos.gd` (campos `salud`, `salud_max`, `rango`, `cuartel_origen`, `postura`, `orden_militar`; `unidades_seleccionadas`, `subgrupo_activo`, señal `seleccion_unidades_cambiada`; API de selección, filtrado por subgrupo, formación en espiral, emisión de las 6 órdenes, `mover_uno`, resolución de ataque/daño/baja, guardia post-graduación sin merodear, y serialización en `exportar_estado()`/`importar_estado()`)
- Test: `godot/scripts/ColonosTest.gd`, `godot/scripts/GestorPartidaTest.gd`

**Interfaces:**
- Consumes: `Ciudad.plazas_militares_libres`, `BuscadorRutas`, `Ajustes.SALUD_*` / `MILITAR_*`.
- Produces:
  - `Colonos.unidades_seleccionadas: Array[int]`
  - `Colonos.subgrupo_activo: String`
  - `signal seleccion_unidades_cambiada(ids: Array[int])`
  - `Colonos.seleccionar_unidades(ids: Array[int], anadir: bool = false) -> void`
  - `Colonos.limpiar_seleccion() -> void`
  - `Colonos.limpiar_seleccion_civil() -> void`
  - `Colonos.militares_seleccionados(aplicar_subgrupo: bool = true) -> Array[int]`
  - `Colonos.grupos_militares_seleccionados() -> Array[Dictionary]`
  - `Colonos.establecer_subgrupo_activo(rango: String) -> void`
  - `Colonos.establecer_postura_seleccion(postura: String) -> void`
  - `Colonos.ordenar_mover(celda: Vector3i, solo_uno: bool = false) -> void`
  - `Colonos.ordenar_patrullar(celda: Vector3i, reiniciar: bool = false) -> void`
  - `Colonos.ordenar_atacar(objetivo_tipo: String, objetivo_id: int, celda: Vector3i) -> void`
  - `Colonos.ordenar_proteger(celda: Vector3i, edificio_id: int = -1) -> void`
  - `Colonos.ordenar_seguir(objetivo_tipo: String, objetivo_id: int = -1) -> void`
  - `Colonos.ordenar_mantener() -> void`
  - `Colonos.aplicar_dano_unidad(id: int, dano: float) -> bool`

- [ ] **Step 1:** Escribir tests en `ColonosTest.gd` cubriendo: graduación en cuartel 4→4 (quedan en guardia cerca del cuartel sin merodear), selección y subgrupos, formación en espiral sin solapamiento, `ordenar_mover` (todos y `solo_uno = true`, Review Focus #4), `ordenar_patrullar` (añadir y reiniciar), `ordenar_seguir` (`avatar`), `ordenar_mantener`, `ordenar_atacar` con reducción de `salud` y baja limpia de `unidades_seleccionadas` (Review Focus #3), y posturas. Añadir verificación de persistencia en `GestorPartidaTest.gd`.
- [ ] **Step 2:** Ejecutar `ColonosTest.tscn` y `GestorPartidaTest.tscn` para confirmar fallo inicial.
- [ ] **Step 3:** Implementar toda la lógica en `Colonos.gd` (incluyendo la graduación 4→4 cuando `esquina` es `cuartel`).
- [ ] **Step 4:** Ejecutar `ColonosTest.tscn` y `GestorPartidaTest.tscn` hasta pasar en verde.
- [ ] **Step 5:** Commit de Task 3.

---

### Task 4: Selección Universal, Panel de Unidad y Órdenes en Cámara Cenital

**Files:**
- Create: `godot/scripts/PanelUnidad.gd` (panel de inspección para civil — tipo, salud, trabajo y edificio — o militar/grupo — rango, salud, botones de postura `Pasivo`/`Defensivo`/`Agresivo` y botones de comando `Mover`/`Atacar`/`Proteger`/`Patrullar`/`Mantener`)
- Modify: `godot/scripts/HUD.gd` (instanciar y exponer `abrir_panel_unidad()`, `cerrar_panel_unidad()`, overlay de recuadro de selección 2D `actualizar_recuadro_seleccion(rect, visible)`)
- Modify: `godot/scripts/CamaraCenital.gd` (en Modo Ver: arrastre izquierdo > 8 px selecciona militares dentro del `Rect2` con soporte `Shift`; clic simple raycast capa 2 unidad primero, luego capa 1 edificio; clic derecho `mover`, `Shift + clic der.` `patrullar`, `K + clic der.` `atacar` unidad/edificio incluso propios, `H` `mantener`, `Esc` cancela `K`/deselecciona)
- Modify: `godot/scripts/ColonosRenderer.gd` (asignar `set_meta("colono_id", id)` en cada `AnimatableBody3D` para identificar la unidad impactada por raycast en capa 2)
- Test: `godot/scripts/CamaraCenitalModosTest.gd`, `godot/scripts/HUDTest.gd`

**Interfaces:**
- Consumes: API completa de selección y órdenes de `Colonos.gd`.
- Produces: `PanelUnidad.gd`, `HUD.actualizar_recuadro_seleccion()`, `HUD.abrir_panel_unidad()`, modo `K` de ataque en `CamaraCenital.gd`.

- [ ] **Step 1:** Escribir tests en `CamaraCenitalModosTest.gd` (selección por recuadro 2D, clic en unidad vs edificio, secuencia `K` + clic derecho sobre unidad/edificio, `Esc` deselecciona) y en `HUDTest.gd` (`PanelUnidad` mostrando datos de civil vs controles de militar).
- [ ] **Step 2:** Ejecutar `CamaraCenitalModosTest.tscn` y `HUDTest.tscn` para confirmar fallo inicial.
- [ ] **Step 3:** Crear `PanelUnidad.gd` e integrar en `HUD.gd`, `CamaraCenital.gd` y `ColonosRenderer.gd` (`colono_id` meta).
- [ ] **Step 4:** Ejecutar `CamaraCenitalModosTest.tscn` y `HUDTest.tscn` hasta pasar en verde.
- [ ] **Step 5:** Commit de Task 4.

---

### Task 5: Modos de 1ª Persona (`T` Construcción, `R` Batalla, `F` Comandante) y Subgrupos Mixtos

**Files:**
- Modify: `godot/scripts/Hotbar.gd` (soportar configuración temporal de ranuras personalizadas para Modo Batalla — armas — y Modo Comandante — órdenes `1–6` — sin perder la hotbar de bloques)
- Modify: `godot/scripts/HUD.gd` (crosshair de combate en Modo Batalla, panel lateral izquierdo de grupos mixtos en 1ª persona con `Shift + 1..9`, y limpieza de selección civil al pasar a 1ª persona — Review Focus #2)
- Modify: `godot/scripts/Player.gd` (estado `modo_primera_persona`: `T` Construcción, `R` Batalla, `F` Comandante; raycast táctico `60 m`; ataque cuerpo a cuerpo y distancia en Modo Batalla; matriz completa de Clic Izquierdo vs Clic Derecho para las 6 órdenes en Modo Comandante; `Shift + 1..9` / `Shift + 0` para subgrupos; saneamiento en `salir_de_todas_las_herramientas()` — Review Focus #5)
- Create: `godot/scripts/PlayerCombateComandanteTest.gd` y `godot/scenes/PlayerCombateComandanteTest.tscn`
- Modify: `tools/run-godot-tests.ps1` (verificar detección automática de la escena nº 37)

**Interfaces:**
- Consumes: API de selección, subgrupos y órdenes de `Colonos.gd`, `Ajustes.ARMAS_AVATAR`.
- Produces: `Player.modo_primera_persona`, `Player.establecer_modo_primera_persona(modo: String)`, `HUD.set_crosshair_combate(activo: bool)`, `HUD.actualizar_panel_grupos_tropas()`.

- [ ] **Step 1:** Crear `PlayerCombateComandanteTest.tscn/.gd` probando: transiciones `R` → `F` → `T` → `salir_de_todas_las_herramientas()`, ataque cuerpo a cuerpo/distancia con daño a unidad, las 6 órdenes con clic izquierdo vs clic derecho (incluyendo mover 1 solo soldado y reiniciar patrulla), y filtrado por subgrupo `Shift + 1`.
- [ ] **Step 2:** Ejecutar `PlayerCombateComandanteTest.tscn` para confirmar fallo inicial.
- [ ] **Step 3:** Implementar los modos en `Player.gd`, `Hotbar.gd` y `HUD.gd`.
- [ ] **Step 4:** Ejecutar `PlayerCombateComandanteTest.tscn`, `PlayerNatacionTest.tscn` y `HUDTest.tscn` hasta pasar en verde.
- [ ] **Step 5:** Commit de Task 5.

---

### Task 6: Visuales Procedurales de Tropas, Marcadores Tácticos y Verificación Global

**Files:**
- Modify: `godot/scripts/ColonosRenderer.gd` (geometría procedural de casco/visera y escudo para `militar`, aro de selección en el suelo dorado/celeste, marcador temporal de orden en el suelo y línea/postes sutiles para waypoints de patrulla de tropas seleccionadas)
- Test: Suite completa `tools/run-godot-tests.ps1`

**Interfaces:**
- Consumes: `Colonos.unidades_seleccionadas`, `Colonos.colonos[id]["orden_militar"]`, `Colonos.seleccion_unidades_cambiada`.

- [ ] **Step 1:** Implementar casco/escudo procedural para `militar`, aro de selección y marcadores de destino/patrulla en `ColonosRenderer.gd`.
- [ ] **Step 2:** Ejecutar la suite completa `powershell -ExecutionPolicy Bypass -File tools\run-godot-tests.ps1` y confirmar **37 de 37 escenas al 100 % en verde**.
- [ ] **Step 3:** Ejecutar `graphify update .` para mantener el grafo sincronizado.
- [ ] **Step 4:** Commit de Task 6.

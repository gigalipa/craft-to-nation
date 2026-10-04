# Plan de Implementación: Observaciones de Jugabilidad, Construcción, Edificios y Navegación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar las mejoras de jugabilidad, balance de recursos, cadena de educación e investigación, memoria de 5 blueprints, tope de cuadrillas, panel residencial con traslado de núcleo urbano y paginación de menús.

**Architecture:** Extender modularmente los scripts existentes (`Ciudad`, `Obras`, `Colonos`, `PanelEdificio`, `Blueprints`, `NiveladorTerreno`, `BarraModos`, `ZonaOverlay`) sin añadir nuevos autoloads ni abstracciones intermedias innecesarias.

**Tech Stack:** Godot 4.3+, GDScript, suite de pruebas automatizadas `tools/run-godot-tests.ps1`.

**Spec:** `docs/superpowers/specs/2026-10-04-observaciones-jugabilidad-construccion-design.md`

## Global Constraints

- Seguir la regla Ponytail: diffs mínimos, stdlib/helpers existentes, sin abstracciones especulativas.
- No tocar la rama `main`; todos los cambios permanecen en la rama actual `codex/formacion-investigacion-energia`.
- Todas las 26 escenas de pruebas deben mantenerse en verde sin excepciones.

## Review Focus

1. **Reembolso de tablas:** Si un bloque de madera se pagó con tablas, minarlo no debe devolver madera cruda multiplicada.
2. **Desahucio de núcleo:** Al trasladar el núcleo a un edificio con menos camas, el desahucio debe respetar estrictamente el orden: `desempleado > obrero > tecnico > especialista > investigador > militar`.
3. **Cancelación en gracia (5 h):** Cancelar una demolición o mudanza durante el período de 5 h debe restaurar el estado y remover el overlay naranja limpiamente.
4. **Paginación en límite:** Presionar `Z` en la página 1 debe retroceder de submenú; presionar `X` en la última página no debe desbordar.
5. **Alineación de puertas:** Dos edificios enfrentados deben compartir la misma cota $Y$ sin romper la validación de pendiente o acceso a la puerta.

---

### Task 1: Consumo de Tablas/Madera y Reembolsos Simétricos

**Files:**
- Modify: `godot/scripts/VoxelWorld.gd`
- Modify: `godot/scripts/Ciudad.gd`
- Test: `godot/scripts/CiudadTest.gd`
- Test: `godot/scripts/ExtraccionTest.gd`

**Interfaces:**
- `Ciudad.consumir_costo(recurso, monto) -> bool`: descuenta primero de `tablas` y luego de `madera`.
- `VoxelWorld._reembolsar_si_corresponde(celda, tipo)`: devuelve el recurso efectivamente pagado (registrado en `celdas_pagadas[celda]`).

- [ ] **Step 1: Escribir pruebas para preferencia de tablas y reembolso exacto**
En `CiudadTest.gd`, verificar que `consumir_costo("madera", 5.0)` agota 5 tablas si hay 5 disponibles y deja intacta la madera cruda. En `ExtraccionTest.gd`, verificar que si una celda se pagó con tablas, minar esa celda reembolsa tablas.

- [ ] **Step 2: Ejecutar pruebas y confirmar fallo/comportamiento esperado**
Ejecutar: `powershell -ExecutionPolicy Bypass -File .\tools\run-godot-tests.ps1`

- [ ] **Step 3: Implementar registro de recurso pagado en VoxelWorld**
Guardar en `celdas_pagadas[celda]` el recurso cobrado (p. ej. `"tablas"` o `"madera"`) para devolver exactamente ese recurso al minar.

- [ ] **Step 4: Ejecutar pruebas y verificar éxito**
Ejecutar: `powershell -ExecutionPolicy Bypass -File .\tools\run-godot-tests.ps1`

- [ ] **Step 5: Commit**
`git commit -m "feat: prioriza tablas en bloques de madera con reembolso simetrico"`

---

### Task 2: Notificación Descriptiva y Selector de Especialistas en Nivel 1

**Files:**
- Modify: `godot/scripts/FinalizacionObras.gd`
- Modify: `godot/scripts/PanelPuesto.gd`
- Test: `godot/scripts/HUDTest.gd`

**Interfaces:**
- `FinalizacionObras.gd`: emite `"Edificio construido: %s." % nombre` al completar un puesto/industria.
- `PanelPuesto.gd`: `fila["fila"].visible = oficios.has(rol)` (la fila de especialista no se oculta si `libres == 0`).

- [ ] **Step 1: Escribir aserciones de notificación y visibilidad de especialista**
En `HUDTest.gd`, verificar que en un puesto con niveles (`mina`, `caza_recoleccion`, `maderero`, `pesca_frutos_mar`) la fila de `especialista` es visible aun con 0 especialistas y nivel 1.

- [ ] **Step 2: Ejecutar pruebas y confirmar fallo**
Ejecutar: `powershell -ExecutionPolicy Bypass -File .\tools\run-godot-tests.ps1`

- [ ] **Step 3: Ajustar FinalizacionObras y PanelPuesto**
Modificar el retorno de `FinalizacionObras.gd` para usar el nombre amigable del edificio.
Eliminar la condición `(rol != "especialista" or libres > 0 or empleados > 0)` en `PanelPuesto.gd:146` para que siempre se muestre la fila de especialistas si el puesto tiene niveles.

- [ ] **Step 4: Ejecutar pruebas y verificar éxito**
Ejecutar: `powershell -ExecutionPolicy Bypass -File .\tools\run-godot-tests.ps1`

- [ ] **Step 5: Commit**
`git commit -m "feat: notifica nombre de edificio y muestra selector de especialistas en nivel 1"`

---

### Task 3: Cadena de Desbloqueo de Educación e Investigadores Blancos

**Files:**
- Modify: `godot/scripts/CamaraCenital.gd`
- Modify: `godot/scripts/ColonosRenderer.gd`
- Modify: `godot/scripts/Economia.gd`
- Modify: `godot/scripts/Colonos.gd`
- Test: `godot/scripts/PuestosPrevisualizacionTest.gd`
- Test: `godot/scripts/EconomiaTest.gd`
- Test: `godot/scripts/ColonosTest.gd`

**Interfaces:**
- `CamaraCenital._evaluar_puesto()`:
  - `escuela_especialistas` requiere $\ge 1$ `escuela_tecnica` construida.
  - `universidad` requiere $\ge 1$ `escuela_especialistas` construida.
- `ColonosRenderer.COLORES_TIPO["investigador"] = Color(0.95, 0.95, 0.95)` (blanco).
- `Economia.simular_hora()`: no despide investigadores al completar un nivel de investigación.

- [ ] **Step 1: Escribir pruebas para requisitos encadenados y persistencia de investigadores**
En `PuestosPrevisualizacionTest.gd`, verificar rechazo de escuela de especialistas sin escuela técnica y de universidad sin escuela de especialistas.
En `EconomiaTest.gd`, verificar que al completar investigación los investigadores siguen asignados a la universidad.

- [ ] **Step 2: Ejecutar pruebas y confirmar fallo**
Ejecutar: `powershell -ExecutionPolicy Bypass -File .\tools\run-godot-tests.ps1`

- [ ] **Step 3: Implementar requisitos encadenados y color blanco de investigador**
Actualizar `CamaraCenital.gd`, cambiar color a blanco en `ColonosRenderer.gd` y remover la desasignación automática en `Economia.gd`.

- [ ] **Step 4: Ejecutar pruebas y verificar éxito**
Ejecutar: `powershell -ExecutionPolicy Bypass -File .\tools\run-godot-tests.ps1`

- [ ] **Step 5: Commit**
`git commit -m "feat: encadena requisitos de investigacion y preserva investigadores"`

---

### Task 4: Tope de Cuadrilla (Máx 4) y Espera de 5 Horas en Demolición

**Files:**
- Modify: `godot/scripts/Obras.gd`
- Modify: `godot/scripts/MarcasDemolicionOverlay.gd`
- Modify: `godot/scripts/PanelEdificio.gd`
- Modify: `godot/scripts/PanelPuesto.gd`
- Test: `godot/scripts/ObrasTest.gd`
- Test: `godot/scripts/ColonosTest.gd`

**Interfaces:**
- `Obras.siguiente_tarea()`: descarta obras donde `colonos.obreros_en(id) >= 4`.
- `Obras.programar_demolicion(id, horas=5)`: estado de espera con cuenta regresiva.
- `MarcasDemolicionOverlay.gd`: dibuja tinte naranja (`Color(1.0, 0.6, 0.1, 0.35)`) durante la espera y rojo (`Color(1.0, 0.1, 0.1, 0.45)`) al estar marcada para obra.

- [ ] **Step 1: Escribir pruebas de tope de 4 colonos y espera de demolición**
En `ObrasTest.gd`, verificar que una obra con 4 obreros asignados no se ofrece a un 5.º colono.
Verificar que la demolición programada dura 5 horas de juego y puede cancelarse.

- [ ] **Step 2: Ejecutar pruebas y confirmar fallo**
Ejecutar: `powershell -ExecutionPolicy Bypass -File .\tools\run-godot-tests.ps1`

- [ ] **Step 3: Implementar tope y temporizador de demolición**
Implementar límite en `Obras.siguiente_tarea`, contador horario en `Obras.simular_hora()`, overlay naranja en `MarcasDemolicionOverlay.gd` y diálogo/botón de cancelación en `PanelEdificio.gd`/`PanelPuesto.gd`.

- [ ] **Step 4: Ejecutar pruebas y verificar éxito**
Ejecutar: `powershell -ExecutionPolicy Bypass -File .\tools\run-godot-tests.ps1`

- [ ] **Step 5: Commit**
`git commit -m "feat: limita cuadrilla a 4 obreros y programa demolicion con espera"`

---

### Task 5: Ventana de Edificios Residenciales y Traslado de Núcleo Urbano

**Files:**
- Modify: `godot/scripts/PanelEdificio.gd`
- Modify: `godot/scripts/Ciudad.gd`
- Modify: `godot/scripts/Zonificacion.gd`
- Modify: `godot/scripts/VoxelWorld.gd`
- Test: `godot/scripts/HUDTest.gd`
- Test: `godot/scripts/CiudadTest.gd`

**Interfaces:**
- `PanelEdificio.gd`:
  - Muestra título "Edificio residencial" o "Núcleo urbano".
  - Muestra Camas, Baúles, Residentes por oficio.
  - Oculta botón "Demoler" si es núcleo urbano.
  - Ofrece botón "Asignar como núcleo urbano" con diálogo modal de advertencia y espera de 5 h.
- `Ciudad.reasignar_nucleo(nuevo_id)`:
  - Reasigna el núcleo, calcula camas y aplica desahucio priorizado general: `desempleado > obrero > tecnico > especialista > investigador > militar`.
  - Actualiza ancla de influencia en `Zonificacion`.

- [ ] **Step 1: Escribir pruebas para reasignación de núcleo y desahucio ordenado**
En `CiudadTest.gd`, simular mudanza de núcleo a un edificio más pequeño y verificar que el desahucio afecta a desempleados/obreros antes que a especialistas o investigadores.

- [ ] **Step 2: Ejecutar pruebas y confirmar fallo**
Ejecutar: `powershell -ExecutionPolicy Bypass -File .\tools\run-godot-tests.ps1`

- [ ] **Step 3: Implementar reasignación de núcleo y datos en PanelEdificio**
Implementar `Ciudad.reasignar_nucleo`, vincular con `Zonificacion` y actualizar `PanelEdificio.gd` con la ventana modal y tiempos de gracia.

- [ ] **Step 4: Ejecutar pruebas y verificar éxito**
Ejecutar: `powershell -ExecutionPolicy Bypass -File .\tools\run-godot-tests.ps1`

- [ ] **Step 5: Commit**
`git commit -m "feat: amplia panel residencial y permite trasladar nucleo urbano"`

---

### Task 6: Memoria de 5 Blueprints Residenciales (1-1-1 a 1-1-5)

**Files:**
- Modify: `godot/scripts/Blueprints.gd`
- Modify: `godot/scripts/BarraModos.gd`
- Modify: `godot/scripts/CamaraCenital.gd`
- Test: `godot/scripts/BlueprintsTest.gd`
- Test: `godot/scripts/HUDTest.gd`

**Interfaces:**
- `Blueprints.guardar_residencial(blueprint)`: inserta al inicio de una lista de hasta 5 elementos; descarta el 6.º.
- `Blueprints.obtener_residenciales() -> Array[Dictionary]`.
- `BarraModos.gd`: `Construir > Residencial` lista los hasta 5 blueprints con miniaturas y numeración `1` a `5`.

- [ ] **Step 1: Escribir pruebas de memoria FIFO de 5 blueprints**
En `BlueprintsTest.gd`, declarar 6 blueprints y verificar que los primeros 5 se conservan en orden inverso y el más antiguo se descarta.
En `HUDTest.gd`, verificar que `BarraModos` genera botones para los blueprints guardados.

- [ ] **Step 2: Ejecutar pruebas y confirmar fallo**
Ejecutar: `powershell -ExecutionPolicy Bypass -File .\tools\run-godot-tests.ps1`

- [ ] **Step 3: Implementar cola de blueprints y submenú residencial**
Actualizar `Blueprints.gd` y `BarraModos.gd` para soportar selección de blueprints residenciales indexados.

- [ ] **Step 4: Ejecutar pruebas y verificar éxito**
Ejecutar: `powershell -ExecutionPolicy Bypass -File .\tools\run-godot-tests.ps1`

- [ ] **Step 5: Commit**
`git commit -m "feat: almacena hasta 5 blueprints residenciales con miniaturas"`

---

### Task 7: Nivelación con Puertas Enfrentadas

**Files:**
- Modify: `godot/scripts/NiveladorTerreno.gd`
- Modify: `godot/scripts/CamaraCenital.gd`
- Test: `godot/scripts/NiveladorTerrenoTest.gd`

**Interfaces:**
- `NiveladorTerreno.calcular_base_y()`: detecta si la columna frontal de una puerta coincide con el despeje/frente de una puerta existente y toma su cota $Y$.

- [ ] **Step 1: Escribir prueba de alineación de puertas enfrentadas**
En `NiveladorTerrenoTest.gd`, simular una puerta existente en altura $Y=10$ con frente en $(5, 5)$, y un nuevo blueprint cuya puerta tiene frente en $(5, 5)$; verificar que `base_y` iguala la altura de la puerta existente.

- [ ] **Step 2: Ejecutar prueba y confirmar fallo**
Ejecutar: `powershell -ExecutionPolicy Bypass -File .\tools\run-godot-tests.ps1`

- [ ] **Step 3: Implementar detección de puerta enfrentada en calcular_base_y**
Consultar el mapa de puertas/edificios existentes en el mundo y ajustar `suelo_frente` a la cota de la puerta enfrentada.

- [ ] **Step 4: Ejecutar prueba y verificar éxito**
Ejecutar: `powershell -ExecutionPolicy Bypass -File .\tools\run-godot-tests.ps1`

- [ ] **Step 5: Commit**
`git commit -m "feat: alinea cota Y de blueprints ante puertas enfrentadas"`

---

### Task 8: Paginación de Menús (Máx 10 Ítems) y Visibilidad de Zonas

**Files:**
- Modify: `godot/scripts/BarraModos.gd`
- Modify: `godot/scripts/CamaraCenital.gd`
- Modify: `godot/scripts/ZonaOverlay.gd`
- Test: `godot/scripts/CamaraCenitalModosTest.gd`
- Test: `godot/scripts/HUDTest.gd`

**Interfaces:**
- `BarraModos.gd`: soporte de paginación (páginas de 10 ítems, teclas 1–9 y 0, flechas, teclas Z y X).
- `ZonaOverlay.set_zonas_visibles(visible: bool)`: oculta planos de zonas específicas en vista libre, periféricos y vías.

- [ ] **Step 1: Escribir pruebas de paginación y visibilidad de zonas**
En `CamaraCenitalModosTest.gd`, verificar que `Z` en página 1 regresa de submenú, y en página 2 regresa a página 1.
En `HUDTest.gd`, verificar que `set_zonas_visibles(false)` oculta las zonas coloreadas dejando visible el área de influencia.

- [ ] **Step 2: Ejecutar pruebas y confirmar fallo**
Ejecutar: `powershell -ExecutionPolicy Bypass -File .\tools\run-godot-tests.ps1`

- [ ] **Step 3: Implementar paginación y visibilidad condicional**
Actualizar `BarraModos.gd`, enrutamiento de teclas en `CamaraCenital.gd` y visibilidad en `ZonaOverlay.gd`.

- [ ] **Step 4: Ejecutar pruebas y verificar éxito**
Ejecutar: `powershell -ExecutionPolicy Bypass -File .\tools\run-godot-tests.ps1`

- [ ] **Step 5: Commit**
`git commit -m "feat: pagina menus con teclas ZX y condiciona visibilidad de zonas"`

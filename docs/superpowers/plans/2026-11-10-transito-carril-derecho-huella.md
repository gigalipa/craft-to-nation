# Plan de Implementación: Tránsito por el Carril Derecho en Vías (Regla del Borde Derecho según Huella)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hacer que los transportistas en vías circulen de manera determinista por el carril derecho exterior según su sentido de marcha y huella física, eliminando bloqueos y encuentros frontales en caminos de doble vía.

**Architecture:** Modulación de costes orientada en el algoritmo de búsqueda de rutas A* ([`BuscadorRutas.gd`](file:///c:/Users/peraz/Projects/Misc/CityCraft/godot/scripts/BuscadorRutas.gd)) apoyada en una función geométrica de borde derecho en [`Vias.gd`](file:///c:/Users/peraz/Projects/Misc/CityCraft/godot/scripts/Vias.gd) ($\vec{r} = (-d_z, d_x)$) y el catálogo de huellas por unidad en [`ajustes.gd`](file:///c:/Users/peraz/Projects/Misc/CityCraft/godot/scripts/ajustes.gd).

**Tech Stack:** Godot 4.x / GDScript, A* Pathfinding (`BuscadorRutas`), GridMap VoxelWorld, Test Runner PowerShell (`tools/run-godot-tests.ps1`).

**Spec:** [`spec_transito_carril_derecho_huella.md`](file:///c:/Users/peraz/.gemini/antigravity/brain/cfb4640e-bfaa-457c-a8c1-8af6ce7d574c/spec_transito_carril_derecho_huella.md)

---

## Global Constraints

- Vías de tierra pisada tienen ancho fijo de 2 bloques (`ancho: 2`), lo que proporciona exactamente dos carriles paralelos.
- Fuera de las vías (terreno natural, edificios), la regla del carril derecho no aplica y se toma el camino euclidiano/Manhattan directo.
- La penalización por circular en contravía/carril izquierdo en vía debe mantener el coste total por debajo del coste de terreno natural (`coste_base_via (3) + penalizacion (4) = 7 < coste_terreno (8)`), para permitir esquivas si el carril derecho está cerrado.
- Toda prueba nueva debe agregarse a la suite existente y las 36 escenas de prueba deben pasar sin regresiones.

---

## Execution Lines & Dependency Matrix

- **Line A (Configuración y Catálogo):** Task 1 ([`ajustes.gd`](file:///c:/Users/peraz/Projects/Misc/CityCraft/godot/scripts/ajustes.gd), [`ConfiguracionTest.gd`](file:///c:/Users/peraz/Projects/Misc/CityCraft/godot/scripts/ConfiguracionTest.gd)).
- **Line B (Geometría Vial):** Task 2 ([`Vias.gd`](file:///c:/Users/peraz/Projects/Misc/CityCraft/godot/scripts/Vias.gd), [`ViasTest.gd`](file:///c:/Users/peraz/Projects/Misc/CityCraft/godot/scripts/ViasTest.gd)).
- **Line C (Pathfinding A* y Tránsito):** Task 3 ([`BuscadorRutas.gd`](file:///c:/Users/peraz/Projects/Misc/CityCraft/godot/scripts/BuscadorRutas.gd), [`BuscadorRutasTest.gd`](file:///c:/Users/peraz/Projects/Misc/CityCraft/godot/scripts/BuscadorRutasTest.gd), [`Colonos.gd`](file:///c:/Users/peraz/Projects/Misc/CityCraft/godot/scripts/Colonos.gd)).
- **Line D (Integración y Release):** Task 4 (Verificación completa con `tools/run-godot-tests.ps1`, `graphify update .` y exportación `tools/export_windows.ps1`).

---

## Review Focus

1. **Simetría perfecta en vías N-S y E-O**: Un colono hacia el Norte debe ir por el carril Este; un colono hacia el Sur por el carril Oeste; un colono hacia el Este por el carril Sur; un colono hacia el Oeste por el carril Norte.
2. **Curvas y diagonales de vía**: El vector ortogonal derecho $\vec{r} = (-d_z, d_x)$ debe mantenerse coherente en pasos diagonales sin desbordar el array de vecinos.
3. **Esquiva y fallback si el carril derecho está bloqueado**: Si el carril derecho tiene un obstáculo o construcción, A* debe poder usar el carril izquierdo (coste 7) en lugar de dar un rodeo inmenso por tierra virgen (coste 8).
4. **Huellas multi-bloque futuras (camión 2×3)**: Las funciones deben aceptar `ancho_unidad` o `huella` sin asumir que todas las unidades son 1×1.
5. **Rendimiento de A\***: El cálculo del borde derecho no debe realizar consultas pesadas ni instanciar objetos temporales en el hot-loop de expansión de nodos.

---

## Task 1: Catálogo de Huellas y Penalización de Carril en `ajustes.gd`

**Files to modify:**
- [`godot/scripts/ajustes.gd`](file:///c:/Users/peraz/Projects/Misc/CityCraft/godot/scripts/ajustes.gd)
- [`godot/scripts/ConfiguracionTest.gd`](file:///c:/Users/peraz/Projects/Misc/CityCraft/godot/scripts/ConfiguracionTest.gd)

- [ ] **Step 1.1**: Escribir prueba unitaria en `ConfiguracionTest.gd` verificando que cada unidad de transporte tenga asignada su `huella: Vector2i` válida (ancho >= 1, largo >= 1) y que `VIAS_PENALIZACION_CARRIL_IZQUIERDO` esté configurada.
- [ ] **Step 1.2**: Ejecutar `ConfiguracionTest.tscn` y confirmar que falla.
- [ ] **Step 1.3**: Agregar la constante `VIAS_PENALIZACION_CARRIL_IZQUIERDO: int = 4` a `ajustes.gd`.
- [ ] **Step 1.4**: Agregar la propiedad `"huella": Vector2i(...)` a cada vehículo en `Ajustes.TRANSPORTE_CATALOGO_UNIDADES`:
  - `acarreador_pie`: `Vector2i(1, 1)`
  - `carreta_mano`: `Vector2i(1, 1)`
  - `carro_caballos`: `Vector2i(1, 2)`
  - `camion_diesel`: `Vector2i(2, 3)`
  - `dron_carga`: `Vector2i(1, 1)`
  - `trolebus_solar`: `Vector2i(2, 4)`
- [ ] **Step 1.5**: Reejecutar `ConfiguracionTest.tscn` y confirmar que pasa.

---

## Task 2: Detección de Borde Derecho de Vía en `Vias.gd`

**Files to modify:**
- [`godot/scripts/Vias.gd`](file:///c:/Users/peraz/Projects/Misc/CityCraft/godot/scripts/Vias.gd)
- [`godot/scripts/ViasTest.gd`](file:///c:/Users/peraz/Projects/Misc/CityCraft/godot/scripts/ViasTest.gd)

- [ ] **Step 2.1**: Escribir prueba unitaria en `ViasTest.gd` (ej. `TEST 40: Vias.es_borde_derecho()`) probando:
  - Vía N-S en $X \in \{0, 1\}$: dirección $(0, -1)$ da borde derecho en $X=1$ y no en $X=0$.
  - Vía N-S en $X \in \{0, 1\}$: dirección $(0, 1)$ da borde derecho en $X=0$ y no en $X=1$.
  - Vía E-O en $Z \in \{0, 1\}$: dirección $(1, 0)$ da borde derecho en $Z=1$ y no en $Z=0$.
  - Vía E-O en $Z \in \{0, 1\}$: dirección $(-1, 0)$ da borde derecho en $Z=0$ y no en $Z=1$.
- [ ] **Step 2.2**: Ejecutar `ViasTest.tscn` y verificar que falla por ausencia del método `es_borde_derecho()`.
- [ ] **Step 2.3**: Implementar en `Vias.gd`:
  ```gdscript
  func es_borde_derecho(soporte: Vector3i, direccion: Vector2i, ancho_unidad: int = 1) -> bool:
      if direccion == Vector2i.ZERO:
          return true
      var r := Vector2i(-direccion.y, direccion.x)
      var extremo_der := Vector2i(soporte.x, soporte.z) + (ancho_unidad - 1) * r
      var exterior_der := extremo_der + r
      return hay_via_en_columna(extremo_der) and not hay_via_en_columna(exterior_der)
  ```
- [ ] **Step 2.4**: Reejecutar `ViasTest.tscn` y verificar que la prueba pasa exitosamente.

---

## Task 3: Modulación de Costes A* en `BuscadorRutas.gd` y Propagación en `Colonos.gd`

**Files to modify:**
- [`godot/scripts/BuscadorRutas.gd`](file:///c:/Users/peraz/Projects/Misc/CityCraft/godot/scripts/BuscadorRutas.gd)
- [`godot/scripts/BuscadorRutasTest.gd`](file:///c:/Users/peraz/Projects/Misc/CityCraft/godot/scripts/BuscadorRutasTest.gd)
- [`godot/scripts/Colonos.gd`](file:///c:/Users/peraz/Projects/Misc/CityCraft/godot/scripts/Colonos.gd)

- [ ] **Step 3.1**: Escribir prueba de integración en `BuscadorRutasTest.gd`:
  - Registrar un tramo recto de vía de 2 bloques de ancho y 20 celdas de largo (ej. $X \in \{10, 11\}$, $Z \in [0, 20]$).
  - Buscar ruta A* de $(10, 1, 0)$ a $(10, 1, 20)$ (hacia el Sur).
  - Buscar ruta A* de $(11, 1, 20)$ a $(11, 1, 0)$ (hacia el Norte).
  - Verificar que la ruta Sur utiliza la columna $X=10$ (borde derecho) y la ruta Norte utiliza la columna $X=11$ (borde derecho).
  - Comprobar que ambas rutas tienen 0 celdas compartidas (separación total de carriles).
- [ ] **Step 3.2**: Ejecutar `BuscadorRutasTest.tscn` y confirmar que falla.
- [ ] **Step 3.3**: En `BuscadorRutas.gd` (`Busqueda._init`), almacenar `_ancho_unidad`:
  ```gdscript
  var datos_t: Dictionary = Ajustes.TRANSPORTE_CATALOGO_UNIDADES.get(_tipo_transporte, {})
  var huella: Vector2i = datos_t.get("huella", Vector2i(1, 1))
  _ancho_unidad = huella.x
  ```
- [ ] **Step 3.4**: En `BuscadorRutas.gd` (`Busqueda.avanzar`), calcular la modulación de costes en vía:
  ```gdscript
  var soporte: Vector3i = vecino - ARRIBA
  var coste_superficie: int = 1
  if Vias != null and Vias.es_via(soporte):
      var base_via: int = Vias.coste_paso_en(soporte)
      var dir_paso := Vector2i(vecino.x - actual.x, vecino.z - actual.z)
      if Vias.es_borde_derecho(soporte, dir_paso, _ancho_unidad):
          coste_superficie = base_via
      else:
          coste_superficie = base_via + Ajustes.VIAS_PENALIZACION_CARRIL_IZQUIERDO
  else:
      coste_superficie = Vias.coste_paso_en(soporte) if Vias != null else 1
  ```
- [ ] **Step 3.5**: En `Colonos.gd` (`_opciones_ruta`), asegurar que `tipo_transporte` se incluya en el diccionario `opciones`:
  ```gdscript
  opciones["tipo_transporte"] = tipo_transporte_de_colono(c["id"])
  ```
- [ ] **Step 3.6**: Reejecutar `BuscadorRutasTest.tscn` y verificar que la prueba de carriles opuestos pasa.

---

## Task 4: Verificación Integral, Grafo y Release

**Files to modify / run:**
- Suite de pruebas: `tools/run-godot-tests.ps1`
- Grafo: `graphify update .`
- Exportación: `tools/export_windows.ps1`

- [ ] **Step 4.1**: Ejecutar la suite completa de 36 escenas de prueba mediante `tools/run-godot-tests.ps1` y confirmar 100% de éxito.
- [ ] **Step 4.2**: Ejecutar `graphify update .` para sincronizar el grafo de conocimiento.
- [ ] **Step 4.3**: Exportar el paquete Windows `CraftToNation_v0.5.4_Windows.zip` mediante `tools/export_windows.ps1 -Version "v0.5.4"`.

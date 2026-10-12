# Especificación Técnica: Ajustes de Subsuelo, Fluidos, Canalizaciones, Balance Energético y Pathfinding

**Fecha:** 2026-10-12  
**Autor:** Antigravity / Pair Programming  
**Estado:** Aprobado para Planificación e Implementación  
**Rama objetivo:** `feature/subsuelo-bloques` (worktree `.worktrees/subsuelo-bloques`)  
**Contexto del Proyecto:** Craft to Nation - Fase 3 / Hito 9 (Fluidos, Extracción, Ductos, Balance Energético y Tráfico)

---

## 1. Resumen Ejecutivo

Este documento define la especificación técnica definitiva para implementar las mejoras y correcciones consolidadas en `docs/Propuesta_Ajustes_Subsuelo_Ductos_y_NPCs.md`, integrando las respuestas y decisiones de diseño acordadas:

1. **Físicas y Drenado de Fluidos:** Aumento de viscosidad del crudo en el avatar (`Player.gd`), propagación (*spreading*) diferenciada para agua (7), combustible (5) y crudo (3) (`VoxelWorld.gd`), desalojo y destrucción inmediata de líquidos al colocar bloques sólidos, e inundación de agua al minar bloques con agua adyacente o superior (mecánica Minecraft).
2. **Presentación Visual y Geometría de Ductos:** Textos legibles en fichas técnicas (`Canalizaciones.gd`), texturizado UV longitudinal en tramos y consolidación de la arquitectura modular de 4 piezas (bloques de columna, bloques extremos, bloques de ducto lineal/quiebre y tramos de centro a centro).
3. **Cruces a Desnivel de Ductos:** Paso sobre-elevado a $Y_{suelo} + 6$ con dos columnas de soporte a $Y_{suelo} + 5$ en las celdas adyacentes anterior y posterior, bloque de ducto en la celda de intersección a $Y_{suelo} + 6$ y celda intermedia $Y_{suelo} + 5$ como aire libre de despeje.
4. **Ciclo de Vida de Ductos:** Extensión y ramificación de redes desde columnas o extremos existentes, topología con soporte para múltiples entradas y una única salida de red, cancelación de derrames al completar conexiones a puertos receptores y demolición limpia integral (bloques en GridMap, colisionadores 3D y liberación del despeje de puertos).
5. **Logística y Balance Industrial:** Ciclo de acarreo de carbón (150 unidades por viaje) para la Central Termoeléctrica con capacidad local de 500 unidades cuando opera en modo carbón, y partición estricta de almacén en la Refinería Petrolera (400 crudo / 600 combustible de 1000 totales).
6. **Interfaz de Energía:** Botón interactivo "Energía" en la barra superior que despliega la ventana modal centrada `VentanaEnergia`, con balances globales y listas interactivas de generadores y consumidores que mueven la cámara y abren el panel del edificio al hacer clic.
7. **Preferencia de Vías en NPCs:** Ponderación en `BuscadorRutas` basada en un coste por tipo de vía (`coste_ruta` en `Vias.TIPOS`, tierra pisada = 3) frente al terreno natural (8), manteniendo penalización moderada por desnivel (+1 por bloque de altura).

---

## 2. Especificación Detallada por Módulo

### Módulo 1: Físicas de Fluidos y Terreno

#### 1.1 Viscosidad del Crudo en Avatar (`Player.gd`)
* **Archivo:** `godot/scripts/Player.gd`
* **Constantes:**
  * Reducir `FACTOR_VISCOSIDAD_CRUDO` de `0.5` a `0.20`.
* **Comportamiento en `_physics_process()`:**
  * Al estar sumergido en crudo (`inmerso_en_crudo`):
    * Velocidad de movimiento horizontal reducida al 20% de la velocidad base.
    * Impulso vertical de salto atenuado a `VELOCIDAD_SALTO * 0.20` (salir del líquido exige esfuerzo constante).
    * Velocidad terminal de caída amortiguada para transmitir densidad física viscosa.

#### 1.2 Spreading (Escurrimiento) de Crudo y Combustible (`VoxelWorld.gd`)
* **Archivo:** `godot/scripts/VoxelWorld.gd`
* **Lógica:**
  * Generalizar `_procesar_frente_escurrimiento()` para procesar cualquier fluido perteneciente a `TIPOS_LIQUIDOS` (`"agua"`, `"crudo"`, `"combustible"`).
  * Parámetros de alcance horizontal máximo:
    * `const ALCANCE_FLUJO_AGUA := 7`
    * `const ALCANCE_FLUJO_COMBUSTIBLE := 5`
    * `const ALCANCE_FLUJO_CRUDO := 3`
  * Propagar en los laterales colocando el mismo tipo de líquido del bloque de origen (`_colocar_liquido_flujo(lateral, nivel + 1, tipo_liquido)`).

#### 1.3 Drenado / Desalojo al Colocar Bloques Sólidos (`VoxelWorld.gd`)
* **Archivo:** `godot/scripts/VoxelWorld.gd`
* **Lógica en `colocar_bloque(celda, tipo, por_jugador)`:**
  * Modificar la validación que rechaza colocar bloques sobre celdas ocupadas: si la celda tiene un líquido (`TIPOS_LIQUIDOS.has(tipo_anterior)`) y el nuevo bloque no es un líquido:
    * Se permite la colocación (el bloque sólido desaloja el líquido).
    * El líquido se destruye inmediatamente (sin devolución de recursos).
    * Se limpia el registro de flujo/nivel del líquido en esa celda y se emite `bloque_translucido_cambiado.emit(celda)`.

#### 1.4 Inundación al Minar Celdas con Agua Adyacente (`VoxelWorld.gd`)
* **Archivo:** `godot/scripts/VoxelWorld.gd`
* **Lógica en `minar_bloque(celda)`:**
  * Al retirar un bloque sólido, comprobar si alguna celda vecina en horizontal (norte, sur, este u oeste) o la celda superior directa contiene agua (`"agua"`):
    * Si al menos un vecino lateral o el vecino superior es agua, la celda recién vaciada se convierte automáticamente en bloque de agua (`"agua"`).
    * Se registra en el sistema de translúcidos y se emite la actualización visual correspondiente.

---

### Módulo 2: Canalizaciones (Geometría, Cruces y Ciclo de Vida)

#### 2.1 Formato Legible en Ficha Técnica (`Canalizaciones.gd`)
* **Archivo:** `godot/scripts/Canalizaciones.gd`
* **Helper:**
  ```gdscript
  static func nombre_recurso_legible(clave: String) -> String:
      var nombres := {
          "bloque_acero": "Bloque de acero",
          "estructura_hierro": "Estructura de hierro",
          "bloque_piedra": "Bloque de piedra",
          "bloque_madera": "Bloque de madera",
      }
      return nombres.get(clave, clave.replace("_", " ").capitalize())
  ```
* En `ficha_tecnica(tipo, celdas_ducto, celdas_columna)`:
  * Formatear los costos totales con nombres en lenguaje natural: `"%d %s"`.
  * Formatear los costos unitarios por metro: `"%d %s/m"`.

#### 2.2 Texturizado UV en Tramos (`Canalizaciones.gd`)
* **Archivo:** `godot/scripts/Canalizaciones.gd`
* Al generar la malla con `SurfaceTool` en `construir_tramo()`:
  * Las coordenadas UV se calculan de forma longitudinal respecto a la longitud física del tramo `len_total`, mapeando `uv.x` de `0.0` a `len_total` para que las texturas no se estiren en vanos largos.

#### 2.3 Cruces a Desnivel de Ductos con Doble Columna (`Canalizaciones.gd`)
* **Archivo:** `godot/scripts/Canalizaciones.gd`
* **Geometría del Cruce:**
  * Al detectar que la ruta intersecta una canalización existente a cota estándar $Y_{inf} = Y_{suelo} + 4$ en $(X_c, Z_c)$:
    1. **Columnas de sobre-elevación:** En las celdas adyacentes anterior $(X_c - dx, Z_c - dz)$ y posterior $(X_c + dx, Z_c + dz)$, se generan dos columnas de soporte independientes que van desde $Y_{suelo} + 1$ hasta $Y_{suelo} + 5$.
    2. **Cabezales de ducto en columnas:** En la cima de ambas columnas ($Y = Y_{suelo} + 6$) se coloca un bloque de ducto (`lineal`).
    3. **Bloque en la intersección:** En la celda central $(X_c, Y_{suelo} + 6, Z_c)$ se coloca un bloque de ducto (`lineal`).
    4. **Despeje vertical:** La celda $(X_c, Y_{suelo} + 5, Z_c)$ permanece como aire vacío (1 bloque libre de separación entre ductos).
    5. **Tramos continuos:**
       * El ducto asciende desde la columna previa normal ($Y_{suelo} + 4$) hacia la columna de cruce ($Y_{suelo} + 6$) mediante un tramo inclinado de 2 bloques de desnivel.
       * Los bloques de $Y_{suelo} + 6$ se unen mediante tramos horizontales a cota 6.
       * Luego desciende simétricamente hacia la columna siguiente a $Y_{suelo} + 4$.

#### 2.4 Extensión de Redes y Topología Multi-Entrada (`CamaraCenital.gd` & `Canalizaciones.gd`)
* **Archivos:** `godot/scripts/CamaraCenital.gd` y `godot/scripts/Canalizaciones.gd`
* **Detección de Extensión:**
  * Al iniciar un trazo de ducto en modo cenital, si la posición de inicio corresponde a una celda del gridmap (en la columna vertical $X, Z$) ocupada por una columna o bloque de ducto de una red existente del mismo tipo (`acueducto` con `acueducto`, `tuberia` con `tuberia`):
    * Se verifica compatibilidad de fluido (debe coincidir el recurso o estar indefinido).
    * Se marca `_red_origen_extension = id_red`.
* **Fusión y Topología:**
  * Al confirmar el trazado, se incorporan las nuevas celdas, columnas y tramos a `id_red`.
  * **Regla topológica:** Cada red admite **múltiples entradas** (ej. dos puestos de extracción vertiendo a la misma tubería) y **una sola salida** (puerto de entrada en almacén/refinería/central).
  * Si la red tenía un derrame activo en su extremo previo y la extensión se conecta a un puerto receptor válido, el estado pasa a `"conectado"` y se elimina el derrame de `derrames_activos`.

#### 2.5 Demolición Limpia Integral (`Canalizaciones.gd`)
* **Archivo:** `godot/scripts/Canalizaciones.gd`
* **Comportamiento en `quitar_celdas(celdas, mundo)`:**
  * Retirar forzadamente los bloques de ducto y columna del GridMap con `mundo.set_cell_item(c, GridMap.INVALID_CELL_ITEM)`.
  * Borrar de `mundo.celdas_pagadas`, `mundo.colocado_por_jugador` y `mundo.celda_sobre_techo`.
  * Destruir de inmediato (`queue_free()`) todos los nodos `StaticBody3D` (`DuctoTramo`) de la red afectada.
  * Dejar vacía la celda adyacente a puertos para que `buscar_puerto_adyacente()` permita conectar nuevos ductos sin residuos invisibles.

---

### Módulo 3: Balance Industrial, Logística y Energía

#### 3.1 Acarreo de Carbón para la Central Termoeléctrica (`Colonos.gd` & `Economia.gd`)
* **Archivos:** `godot/scripts/Colonos.gd` y `godot/scripts/Economia.gd`
* **Almacén Local de la Central:**
  * Capacidad máxima: **500 unidades de carbón**.
* **Rutina de Trabajo del Colono en modo `"carbon"`:**
  * Si `almacen["carbon"] < 500`:
    * Fase 1: El colono viaja al núcleo urbano o almacén más cercano con carbón disponible y carga **150 unidades** (`CAPACIDAD_CARGA`).
    * Fase 2: Viaja a la celda de servicio/puerta de la central.
    * Fase 3: Si hay al menos 150 unidades de espacio disponible (`500 - stock >= 150`), entrega la carga completa. Si no, espera en la central hasta que el consumo libere el espacio.
    * Fase 4: Reinicia el ciclo si el stock sigue por debajo de 500.
  * Si la central opera en modo `"combustible"` o `"crudo"`, no admite acarreadores (se abastece 100% por ductos).

#### 3.2 Partición de Capacidad en Refinería Petrolera (`CadenaMinerales.gd` & `Economia.gd`)
* **Archivos:** `godot/scripts/CadenaMinerales.gd` y `godot/scripts/Economia.gd`
* **Límites de Almacén:**
  * Capacidad total del almacén: 1000 unidades.
  * **Capacidad máxima de crudo (insumo):** **400 unidades (40%)**.
  * **Capacidad máxima de combustible (producto):** **600 unidades (60%)**.
  * En `Canalizaciones` / `Economia`: La inyección de crudo por tubería se detiene cuando `almacen.get("crudo", 0) >= 400`.

#### 3.3 Botón "Energía" y `VentanaEnergia` Modal (`BarraSuperior.gd`, `HUD.gd`, `VentanaEnergia.gd`)
* **Archivos:** `godot/scripts/BarraSuperior.gd`, `godot/scripts/HUD.gd` y nuevo `godot/scripts/VentanaEnergia.gd`.
* **Componentes:**
  * **`BarraSuperior.gd`:** Convertir `energia` en `Button` interactivo (estilo coherente con los otros botones de datos del HUD), emitiendo `dato_pedido("energia")`.
  * **`VentanaEnergia.gd` (Modal Centrado):**
    * Ventana modal centrada con estilo `TemaHUD`, cerrable con botón `X`, tecla `Esc` o `E`.
    * **Resumen Superior:**
      * Capacidad total generada (kW / MW).
      * Demanda total de la ciudad.
      * Porcentaje de cobertura y balance neto (superávit / déficit).
    * **Lista de Generadores:**
      * Nombre de cada Central Termoeléctrica, combustible activo (`carbón`, `combustible`, `crudo`), generación entregada y stock local.
    * **Lista de Consumidores:**
      * Edificios industriales, refinerías, universidades y talleres con su demanda individual y estado (`Conectado`, `Sin suministro`).
    * **Navegación Interactiva:**
      * Al hacer clic en cualquier edificio de las listas, la ventana se cierra, la cámara se traslada a la posición del edificio y se abre su panel de interacción.

---

### Módulo 4: Preferencia de Vías en Pathfinding de NPCs

#### 4.1 Catálogo de Costes en `Vias.gd`
* **Archivo:** `godot/scripts/Vias.gd`
* Constante: `const COSTE_TERRENO_NATURAL := 8`.
* En `Vias.TIPOS`: añadir `"coste_ruta": 3` a `"tierra_pisada"`.
* Helper:
  ```gdscript
  func coste_paso_en(soporte: Vector3i) -> int:
      if not es_via(soporte):
          return COSTE_TERRENO_NATURAL
      var tipo_via: String = tipo_en(soporte)
      return TIPOS.get(tipo_via, {}).get("coste_ruta", 4)
  ```

#### 4.2 Ponderación Moderada en A* (`BuscadorRutas.gd`)
* **Archivo:** `godot/scripts/BuscadorRutas.gd`
* Cálculo de coste para vecinos transitables:
  ```gdscript
  var soporte := vecino - ARRIBA
  var coste_superficie: int = Vias.coste_paso_en(soporte) if Vias != null else 1
  var nuevo_costo: int = _costo[actual] + coste_superficie + absi(vecino.y - actual.y)
  ```
* El colono prefiere viajar por vías de tierra pisada (coste 3) en vez de campo traviesa (coste 8), sorteando desniveles con penalización moderada (+1 por escalón de 1 bloque).

---

## 3. Plan de Pruebas Automatizadas

Cada módulo incluirá aserciones dedicadas para garantizar cero regresiones en la suite completa de 28 pruebas (`tools/run-godot-tests.ps1`):

1. **`PlayerNatacionTest.gd`:** Comprobar `FACTOR_VISCOSIDAD_CRUDO == 0.20` y reducción de impulso de salto a 0.20 en crudo.
2. **`CanalizacionesTest.gd`:**
   * Test de texto legible en `ficha_tecnica` (sin guiones bajos y con unidades).
   * Test de cruce a desnivel: verificar 2 columnas de soporte en adyacentes a $Y_{suelo}+5$, cota de ducto $Y_{suelo}+6$ y despeje de aire a $Y_{suelo}+5$.
   * Test de extensión de red: verificar que conectar un tramo a una red desconectada o en derrame asocia el mismo `id_red` y cancela el derrame.
   * Test de demolición limpia: verificar que la celda exterior del puerto quede vacía (`""`) y sin colisionadores.
3. **`TranslucidosRendererTest.gd` / `VoxelWorldTest`:**
   * Colocar bloque sólido sobre crudo o agua y verificar desalojo y destrucción del líquido.
   * Minar bloque adyacente a agua y verificar que se convierte en agua.
   * Escurrimiento de crudo limitado a 3 celdas horizontales.
4. **`EconomiaTest.gd` / `CadenaMineralesTest.gd`:**
   * Acarreo de 150 unidades de carbón a la central termoeléctrica hasta alcanzar 500 unidades.
   * Límite de 400 unidades de crudo en la refinería petrolera.
5. **`BuscadorRutasTest.gd`:**
   * Ruta que elige vía de tierra pisada frente a atajo por terreno natural.
6. **`HUDTest.gd`:**
   * Clic en botón "Energía" abre `VentanaEnergia` modal.

# Propuesta de Implementación: Ajustes de Subsuelo, Ductos, Energía y Pathfinding de NPCs

**Fecha:** 2026-10-12  
**Autor:** Antigravity / Pair Programming  
**Estado:** Propuesto (Listo para implementación)  
**Rama objetivo:** `feature/subsuelo-bloques` (worktree `.worktrees/subsuelo-bloques`)  
**Contexto del Proyecto:** Craft to Nation - Fase 3 / Hito 9 (Fluidos, Extracción, Ductos, Balance Energético y Tráfico)

---

## 1. Visión General

Este documento consolida las especificaciones técnicas y soluciones de arquitectura para resolver las observaciones del juego en vivo en el sistema de fluidos, trazado de ductos, gestión energética y navegación de los colonos:

1. **Físicas y Drenado de Fluidos:** Aumento de viscosidad del crudo, habilitación de spreading (escurrimiento) para líquidos no acuosos y capacidad de drenar/secar fluidos colocando bloques sólidos.
2. **Presentación Visual y Geometría de Ductos:** Textos legibles en fichas técnicas, inversión correcta de normales para evitar texturas invertidas y eliminación de z-fighting en vigas continuas.
3. **Cruces a Desnivel de Ductos:** Reemplazo del solapamiento directo por un paso sobre-elevado a 6 bloques de altura con dos columnas de soporte independientes y 1 bloque libre de aire intermedio.
4. **Ciclo de Vida de Ductos:** Extensión/reconstrucción de ductos incompletos o en derrame desde columnas existentes, y eliminación limpia de bloques y cuerpos colisionadores al demoler (evitando bloques "fantasma" en puertos).
5. **Logística y Balance Industrial:** Rutina de acarreo de carbón para Centrales Termoeléctricas y partición de capacidad en la Refinería Petrolera (40% crudo / 60% combustible).
6. **Interfaz de Energía:** Conversión de la etiqueta "Energía" de la barra superior en botón interactivo que despliega `VentanaEnergia` con balances y lista de consumidores/generadores.
7. **Preferencia de Vías en NPCs:** Ponderación en `BuscadorRutas` basada en un coste por tipo de vía (`coste_ruta` en `Vias.TIPOS`), frente al terreno natural, manteniendo desniveles moderados.

---

## 2. Detalle de Implementación por Módulo

### 2.1 Mayor Viscosidad en el Crudo (`Player.gd`)
- **Archivo:** `godot/scripts/Player.gd`
- **Cambios:**
  - Reducir `FACTOR_VISCOSIDAD_CRUDO` de `0.5` a `0.20`.
  - En `_physics_process()`:
    - Reducir el impulso de salto dentro del crudo a `VELOCIDAD_SALTO * 0.20` para que salir del líquido requiera esfuerzo.
    - Mantener la velocidad de caída amortiguada para sensación de inmersión densa.

---

### 2.2 Formato de Etiquetas en Ficha Técnica de Ductos (`Canalizaciones.gd`)
- **Archivo:** `godot/scripts/Canalizaciones.gd`
- **Cambios en `ficha_tecnica(tipo, celdas_ducto, celdas_columna)`:**
  - Crear helper de traducción de claves internas a nombres en lenguaje natural:
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
  - Formatear tanto el costo total dinámico como el costo unitario por metro (`"%d %s"` y `"%d %s/m"`).

---

### 2.3 Corrección de Normales, Texturas y Z-Fighting (`Canalizaciones.gd`)
- **Archivo:** `godot/scripts/Canalizaciones.gd`
- **Cambios en generación de malla de `construir_tramo()`:**
  1. **Orientación de Normales:** Invertir el orden de los vértices de las caras laterales y tapas para que el producto cruz `(q[1] - q[0]).cross(q[2] - q[0])` apunte estrictamente hacia el exterior (normales exteriores coherentes con el renderizador de Godot).
  2. **Eliminación de Z-Fighting:**
     - En lugar de extruir entre los centros de celda `c_a` y `c_b` solapando los cubos de nodo, extruir la viga entre las **caras exteriores** de los bloques de columna:
       `c_a_ext = c_a + u * 0.5` y `c_b_ext = c_b - u * 0.5`.
     - Opcionalmente aplicar un retranqueo transversal leve de grosor (sección de `0.96 x 0.96` en lugar de `1.0 x 1.0`), garantizando que la viga entre limpia y no compita coplanarmente con ninguna cara de bloque cúbico.
     - Asignar mapeo UV en repetición longitudinal (`uv.x = 0..len_total`) para evitar estiramientos de textura.

---

### 2.4 Cruces a Desnivel de Ductos con Doble Columna (`Canalizaciones.gd`)
- **Archivo:** `godot/scripts/Canalizaciones.gd`
- **Lógica de Cruce:**
  - Al detectar que la ruta pasa por una celda $(X_c, Z_c)$ con ducto preexistente a cota estándar $Y_{inf} = Y_{suelo} + 4$:
    1. **Columnas de Sobre-elevación:** En las celdas inmediatamente adyacentes anterior $(X_c - dx, Z_c - dz)$ y posterior $(X_c + dx, Z_c + dz)$, se generan **dos columnas nuevas de soporte**.
    2. **Altura de Columnas:** Las columnas suben desde $Y_{suelo} + 1$ hasta $Y_{suelo} + 5$ (5 bloques verticales de columna, altura total de 6 bloques).
    3. **Cota de Ducto Superior:** En las columnas y en la celda de intersección, la cota del ducto se fija en **$Y_{sup} = Y_{suelo} + 6$**.
    4. **Despeje de Aire:** Entre el ducto inferior ($Y = Y_{suelo} + 4$) y el superior ($Y = Y_{suelo} + 6$) queda una celda completa vacía de aire ($Y = Y_{suelo} + 5$).
    5. **Aislamiento Total:** Las líneas no se tocan ni comparten bloques físicos ni registros lógicos. Demoler la inferior o la superior no altera en absoluto la estructura de la otra.

---

### 2.5 Spreading (Escurrimiento) de Crudo y Combustible (`VoxelWorld.gd`)
- **Archivo:** `godot/scripts/VoxelWorld.gd`
- **Cambios en `_procesar_frente_escurrimiento()`:**
  - Reemplazar la guardia exclusiva de agua `obtener_tipo(origen) != "agua"` por:
    ```gdscript
    var tipo_liquido: String = obtener_tipo(origen)
    if not TIPOS_LIQUIDOS.has(tipo_liquido):
        return true
    ```
  - Generalizar la propagación para colocar el mismo tipo de líquido del origen (`_colocar_liquido_flujo(lateral, nivel + 1, tipo_liquido)`).
  - Parámetros por fluido:
    - **Agua:** alcance horizontal de 7 celdas, avance estándar.
    - **Crudo:** alcance horizontal de 3 celdas, avance más espaciado por viscosidad.
    - **Combustible:** alcance horizontal de 5 celdas.

---

### 2.6 Drenado de Fluidos al Colocar Bloques Sólidos (`VoxelWorld.gd`)
- **Archivo:** `godot/scripts/VoxelWorld.gd`
- **Cambios en `colocar_bloque(celda, tipo, por_jugador)`:**
  - Modificar la validación de reemplazo:
    ```gdscript
    if actual != GridMap.INVALID_CELL_ITEM and not TIPOS_LIQUIDOS.has(tipo_anterior):
        return false
    ```
  - Si `TIPOS_LIQUIDOS.has(tipo_anterior)` y `not TIPOS_LIQUIDOS.has(tipo)`:
    - El bloque sólido desaloja y elimina de inmediato el líquido de la celda.
    - Limpiar registros de flujo/nivel y emitir `bloque_translucido_cambiado.emit(celda)`.
    - Encolar secado/reajuste de celdas vecinas de líquido.

---

### 2.7 Reconstrucción y Extensión de Ductos Incompletos o en Derrame (`CamaraCenital.gd` & `Canalizaciones.gd`)
- **Archivos:** `godot/scripts/CamaraCenital.gd` y `godot/scripts/Canalizaciones.gd`
- **Mecánica:**
  1. **Inicio de trazo sobre red existente:**
     - Al hacer clic con la herramienta de ducto activa (`_tipo_ducto_activo`), si la celda apuntada corresponde a una columna o extremo de una red existente del mismo tipo cuyo estado sea `"desconectado"` o `"derrame"`:
     - Se registra `_red_origen_extension = id_red`.
  2. **Confirmación y Unión:**
     - Al confirmar el nuevo tramo, en lugar de crear un ID de red nuevo, se agregan las celdas, columnas y tramos a `_red_origen_extension`.
     - Si la extensión finaliza en un puerto receptor válido:
       - La red pasa a `"conectado"`.
       - Si había un derrame activo en la celda anterior, se elimina de `derrames_activos` y se detiene el vertido.
     - Si la extensión vuelve a terminar en un extremo abierto, el derrame activo se traslada a la nueva celda terminal.

---

### 2.8 Limpieza Integral de Bloques y Cuerpos al Demoler Ductos (`Canalizaciones.gd`)
- **Archivo:** `godot/scripts/Canalizaciones.gd`
- **Cambios en `quitar_celdas(celdas, mundo)`:**
  1. **Remoción Forzada en GridMap:**
     - No depender de `mundo.minar_bloque(celda)` (que puede abortar por guardas estructurales).
     - Usar `mundo.set_cell_item(celda, GridMap.INVALID_CELL_ITEM)`.
     - Limpiar explícitamente `mundo.celdas_pagadas.erase(celda)`, `mundo.colocado_por_jugador.erase(celda)` y `mundo.celda_sobre_techo.erase(celda + Vector3i(0, 1, 0))`.
  2. **Destrucción Inmediata de Mallas y Cuerpos:**
     - Iterar sobre `nodos_diagonales[id_red]` y ejecutar `nodo.queue_free()` de inmediato sobre todos los `StaticBody3D` (`DuctoTramo`).
  3. **Despeje de Puertos:**
     - Asegurar que la celda exterior del puerto quede vacía (`""`), permitiendo que el raycast y `buscar_puerto_adyacente()` reconozcan de nuevo el bloque de puerto sin interferencia de restos anteriores.

---

### 2.9 Acarreo de Carbón para la Central Termoeléctrica (`Colonos.gd` & `Economia.gd`)
- **Archivos:** `godot/scripts/Colonos.gd` y `godot/scripts/Economia.gd`
- **Lógica:**
  - En `Colonos._decidir_trabajo(c)`:
    - Comprobar si el puesto es `central_termoelectrica`:
      - Si `puesto.get("combustible_activo", "carbon") == "carbon"`:
        - El acarreador ejecuta el ciclo de suministro entrante (análogo a insumos de refinería):
          1. Fase `"cargar"`: viajar al núcleo urbano o almacén más cercano con carbón disponible y cargar hasta `CAPACIDAD_CARGA`.
          2. Fase `"entrada"`: viajar a la celda de servicio/puerta de la central y descargar el carbón en el almacén local del puesto.
      - Si el modo es `"combustible"` o `"crudo"`:
        - La central no admite acarreadores (se abastece 100% por ductos).

---

### 2.10 Partición de Capacidad en Refinería Petrolera (`CadenaMinerales.gd` & `Economia.gd`)
- **Archivos:** `godot/scripts/CadenaMinerales.gd` y `godot/scripts/Economia.gd`
- **Límites de Almacén:**
  - Capacidad total de la refinería: 1000 unidades.
  - Para `tipo == "refineria_petrolera"`:
    - **Capacidad Máxima de Crudo (Insumo):** **400 unidades (40%)**.
    - **Capacidad Máxima de Combustible (Producto):** **600 unidades (60%)**.
  - En `Canalizaciones` / `Economia`: la inyección por ducto de crudo se detiene si `almacen["crudo"] >= 400`.
  - Garantiza que la acumulación de insumo jamás agote el espacio requerido para la producción de combustible.

---

### 2.11 Botón "Energía" en Topbar y VentanaEnergia (`BarraSuperior.gd` & `HUD.gd`)
- **Archivos:** `godot/scripts/BarraSuperior.gd`, `godot/scripts/HUD.gd` y nuevo `godot/scripts/VentanaEnergia.gd`.
- **Componentes:**
  1. **`BarraSuperior.gd`:** Convertir `var energia` de `Label` a `Button`, aplicando estilo coherente con `almacen_total` y emitiendo `dato_pedido("energia")`.
  2. **`VentanaEnergia.gd`:**
     - Ventana centrada o lateral con estilo `TemaHUD`, cerrable con `E`, `Esc` o botón `X`.
     - **Encabezado Global:** Capacidad total generada, energía entregada, demanda total de la ciudad y porcentaje de déficit/superávit.
     - **Sección Generadores:** Lista de Centrales Termoeléctricas con su combustible activo, generación entregada y reservas locales.
     - **Sección Consumidores:** Lista de edificios industriales, refinerías y universidades que demandan energía, indicando estado de conexión (`Conectado`, `Sin conexión`, `Déficit`).

---

### 2.12 Preferencia de Vías en Pathfinding con Catálogo y Desniveles Moderados (`Vias.gd` & `BuscadorRutas.gd`)
- **Archivos:** `godot/scripts/Vias.gd` y `godot/scripts/BuscadorRutas.gd`
- **Diseño Paramétrico:**
  1. **Catálogo de Vías (`Vias.gd`):**
     - Añadir constante `const COSTE_TERRENO_NATURAL := 8`.
     - Añadir `coste_ruta` a cada tipo de vía en `Vias.TIPOS`:
       ```gdscript
       "tierra_pisada": {
           "nombre": "Vía de tierra pisada",
           "coste_ruta": 3,
           # ...
       }
       ```
     - Helper:
       ```gdscript
       func coste_paso_en(soporte: Vector3i) -> int:
           if not es_via(soporte):
               return COSTE_TERRENO_NATURAL
           var tipo_via: String = tipo_en(soporte)
           return TIPOS.get(tipo_via, {}).get("coste_ruta", 4)
       ```
  2. **Cálculo de Paso en A\* (`BuscadorRutas.gd`):**
     - Al evaluar el coste de un vecino transitable:
       ```gdscript
       var soporte := vecino - ARRIBA
       var coste_superficie: int = Vias.coste_paso_en(soporte) if Vias != null else 1
       var nuevo_costo: int = _costo[actual] + coste_superficie + absi(vecino.y - actual.y)
       ```
     - **Desniveles moderados:** Se conserva únicamente `+ absi(vecino.y - actual.y)` sin multiplicador exagerado (+1 por escalón de 1 bloque).
     - **Comportamiento resultante:**
       - El colono prioriza la vía de tierra pisada (coste 3) sobre el terreno natural (coste 8).
       - Preparado para futuras vías (Calzada coste 2, Carretera coste 1).
       - Si el destino no toca la vía, el colono viaja por la vía hasta el punto más próximo y solo realiza el tramo final sobre el terreno natural.

---

## 3. Plan de Pruebas y Validación Automatizada

Para asegurar cero regresiones en la suite de 28 escenas existentes (`tools/run-godot-tests.ps1`), se añadirán aserciones dedicadas:

1. **`PlayerNatacionTest.gd` / `PlayerOxigenoTest.gd`:**
   - Verificar que `FACTOR_VISCOSIDAD_CRUDO == 0.20` y comprobar la velocidad reducida en crudo.
2. **`CanalizacionesTest.gd`:**
   - Test de formato legible en `ficha_tecnica` (sin guiones bajos).
   - Test de cruce a desnivel: verificar que se generen 2 columnas de soporte a $Y=6$ con vano libre de aire intermedio a $Y=5$.
   - Test de demolición limpia: verificar que la celda exterior del puerto quede vacía (`""`) sin residuos físicos.
   - Test de extensión de red: verificar que conectar un tramo a una red en derrame limpie el derrame.
3. **`VoxelWorldTest.tscn` / `TranslucidosRendererTest.gd`:**
   - Colocar bloque sólido sobre crudo y verificar que el crudo sea reemplazado y drenado.
   - Verificar que el crudo de derrame escurra con límite de 3 celdas horizontales.
4. **`EconomiaTest.gd`:**
   - Verificar el ciclo de acarreo de carbón hacia la central termoeléctrica.
   - Verificar que la refinería petrolera rechace entrada de crudo por encima de 400 unidades.
5. **`BuscadorRutasTest.gd`:**
   - Comparar ruta directa por campo vs ruta por vía: verificar que el camino elegido siga la vía de tierra pisada.
6. **`HUDTest.gd`:**
   - Verificar que el botón de Energía en la barra superior emita `dato_pedido("energia")` y abra `VentanaEnergia`.

# Especificación de Diseño: Observaciones de Jugabilidad, Construcción, Edificios y Navegación

**Fecha:** 2026-10-04  
**Rama:** `codex/formacion-investigacion-energia`  
**Estado:** Propuesto (Pendiente de aprobación de spec)  

---

## 1. Contexto y Objetivos

A partir de pruebas en vivo del ciclo completo de colonos, formación e investigación, se identificaron áreas de mejora en la experiencia de juego, usabilidad del HUD, consistencia visual, jerarquía de construcción y reglas de gestión urbana.

Esta especificación cubre 9 subsistemas concretos sin añadir abstracciones innecesarias (principio Ponytail: diff mínimo, reutilización de helpers y estructuras existentes):
1. **Notificaciones de finalización de obras:** Mensaje con el nombre descriptivo del edificio.
2. **Preferencia de consumo de recursos en bloques de madera:** Prioridad estricta de `tablas` sobre `madera` cruda al pagar y colocar bloques de madera.
3. **Visibilidad del selector de Especialistas:** Mostrar la fila de especialistas en todos los edificios con niveles desde Nivel 1.
4. **Memoria de blueprints residenciales:** Historial de hasta 5 blueprints declarados (`1-1-1` al `1-1-5`) con sus miniaturas.
5. **Tope de cuadrilla en obras:** Límite estricto de máximo 4 colonos trabajando simultáneamente en una obra.
6. **Cadena de requisitos de educación e investigación:**
   - Escuela técnica $\rightarrow$ desbloquea Escuela de especialistas.
   - Escuela de especialistas $\rightarrow$ desbloquea Universidad.
   - Investigadores en la universidad: colonos especialistas con cuerpo blanco (`Color(0.95, 0.95, 0.95)`) que permanecen empleados al concluir cada proyecto de investigación.
7. **Nivelación con puertas enfrentadas:** Si una puerta de un blueprint nuevo se ubica frente al despeje de una puerta existente, igualar la cota $Y$ base a dicha puerta.
8. **Paginación y navegación de menús:** Máximo 10 ítems por página (teclas `1`–`9`, `0`), navegación con flechas y teclas `Z` (anterior/atrás) y `X` (siguiente).
9. **Gestión de Edificios Residenciales y Traslado de Núcleo Urbano:**
   - Panel de información de edificios residenciales con detalle de camas, baúles y residentes por oficio.
   - Traslado de núcleo urbano con diálogo modal de advertencia, tiempo de espera de 5 horas de juego y desahucio ordenado ante déficit de camas (`desempleados > obreros > técnicos > especialistas > investigadores > militares`).
   - Demolición con diálogo de confirmación, tiempo de espera de 5 horas con overlay naranja (cambia a rojo al iniciar obra) y cancelación de demolición.
   - Visibilidad condicional de zonas residenciales e industriales en la cámara cenital.

---

## 2. Especificación Detallada por Subsistema

### 2.1. Notificación de Edificio Construido
- **Ubicación:** `FinalizacionObras.gd`.
- **Comportamiento:**
  - Al completar un puesto o industria, en vez de emitir el texto estático `"Puesto construido."`, emitirá:
    `"Edificio construido: %s." % nombre_edificio`
  - El nombre se obtiene a través del mapa de nombres de `PanelPuesto.NOMBRES_PUESTO` o del tipo de puesto.
  - Para residenciales o núcleo urbano, mantiene `"Núcleo urbano declarado."` o `"Edificio construido: Edificio residencial."`.

### 2.2. Consumo de Bloques de Madera: Tablas vs. Madera
- **Regla:** 1 `bloque_madera` equivale a 5 unidades de recurso.
- **Preferencia:** Se descuenta primero del stock de `tablas` (hasta agotar lo disponible); el remanente se descuenta de `madera` cruda.
- **Rendimiento:** 1 tronco de árbol talado otorga 10 unidades de madera cruda (2 bloques de madera directos). Al procesarse en el aserradero (1 madera $\rightarrow$ 3 tablas), otorga 30 tablas, lo que rinde para 6 bloques de madera.
- **Implementación:**
  - En `Ciudad.consumir_costo("madera", monto)`: ya implementa la preferencia de tablas sobre madera.
  - En `NiveladorTerreno.COSTO_POR_CELDA["bloque_madera"]`: el recurso requerido se mantiene como `"madera"`, asegurando que `Ciudad.consumir_costo` gestione la deducción con prioridad de tablas.
  - En `VoxelWorld._bloqueado_por_falta_de()` y `VoxelWorld._reembolsar_si_corresponde()`: registrar si el cobro fue de tablas o madera para que el reembolso por minar o desarmar devuelva fielmente lo cobrado sin duplicar troncos.

### 2.3. Selector de Especialistas en Edificios de Nivel 1
- **Ubicación:** `PanelPuesto.gd`.
- **Comportamiento:**
  - En edificios que tienen progresión de niveles (`con_niveles`), la fila de `especialista` se mantiene **siempre visible**, independientemente de si hay especialistas libres o empleados en el puesto.
  - Si no hay especialistas libres, mostrará `(0 libres)` y el botón `+` estará deshabilitado.

### 2.4. Memoria de Blueprints Residenciales (FIFO de 5 elementos)
- **Ubicación:** `Blueprints.gd`, `BarraModos.gd`, `CamaraCenital.gd`.
- **Estructura:**
  - `_residenciales: Array[Dictionary] = []` (máximo 5 elementos).
  - Al invocar `Blueprints.guardar(bp)` para la zona `residencial_investigacion`:
    - Se inserta al frente: `_residenciales.push_front(bp)`.
    - Si `_residenciales.size() > 5`, se descarta el último: `_residenciales.pop_back()`.
- **Menú Cenital:**
  - `Construir` (1) $\rightarrow$ `Residencial` (1) despliega los blueprints guardados como botones `1` a `5` (o `1-1-1` a `1-1-5`).
  - Cada botón muestra la miniatura isométrica correspondiente y su numeración.

### 2.5. Tope de Cuadrilla en Obras (Máximo 4 Trabajadores)
- **Ubicación:** `Obras.gd`, `Colonos.gd`.
- **Comportamiento:**
  - Ninguna obra (de construcción o demolición) puede tener más de 4 colonos asignados en paralelo.
  - En `Obras.siguiente_tarea(desde, id_colono)`: una obra se excluye como candidata si `colonos.obreros_en(id) >= 4`.

### 2.6. Cadena de Desbloqueo e Investigadores
- **Ubicación:** `CamaraCenital.gd`, `Colonos.gd`, `ColonosRenderer.gd`, `Economia.gd`.
- **Requisitos de Construcción:**
  - `escuela_tecnica`: sin requisitos previos dentro de la zona residencial de influencia.
  - `escuela_especialistas`: requiere que haya al menos 1 `escuela_tecnica` construida en la ciudad.
  - `universidad`: requiere que haya al menos 1 `escuela_especialistas` construida en la ciudad.
  - `refineria_petrolera`, `productor_combustible`, `central_termoelectrica`: requieren haber investigado *Metalurgia Aplicada* (Nivel 2).
- **Investigadores:**
  - Color de la cápsula física: blanco puro `Color(0.95, 0.95, 0.95)`.
  - Contratación: La universidad contrata especialistas libres y los convierte en oficio `investigador`.
  - Persistencia de empleo: Al culminar un proyecto de investigación en `Economia.simular_hora()`, los investigadores **permanecen asignados y contratados** en la universidad (no se liberan ni despiden).

### 2.7. Nivelación con Puertas Enfrentadas
- **Ubicación:** `NiveladorTerreno.gd`, `CamaraCenital.gd`.
- **Comportamiento:**
  - Al calcular `calcular_base_y` para un blueprint nuevo, se evalúan las columnas de frente de sus puertas.
  - Si una columna de frente coincide con el frente o despeje reservado de una puerta de un edificio ya construido (o colocado), el nuevo edificio adopta como base la cota $Y$ que hace que su puerta quede a la misma altura que la puerta existente enfrentada.

### 2.8. Paginación y Navegación de Menús (Máximo 10 Ítems)
- **Ubicación:** `BarraModos.gd`, `CamaraCenital.gd`.
- **Reglas:**
  - Ningún panel de categoría excede 10 ítems (índices `1`, `2`, `3`, `4`, `5`, `6`, `7`, `8`, `9`, `0`).
  - Si una categoría contiene más de 10 opciones, se divide en páginas (e.g. pág. 1: ítems 1–10, pág. 2: ítems 11–20).
  - Controles de navegación:
    - Botones visuales $\leftarrow$ y $\rightarrow$.
    - Tecla `X`: página siguiente.
    - Tecla `Z`: página anterior. Si se está en la página 1, `Z` regresa al submenú anterior (y desde una categoría de Construir regresa al menú raíz de la barra de modos).

### 2.9. Panel de Edificios Residenciales y Traslado de Núcleo Urbano
- **Ventana de Información (`PanelEdificio.gd`):**
  - Título: `"Edificio residencial"` para viviendas comunes; `"Núcleo urbano"` para el núcleo actual.
  - Detalle:
    - `Camas: X`
    - `Baúles: Y`
    - `Residentes: [desglose por oficio]` (e.g. `2 obreros, 1 técnico`).
  - Botón `"Demoler"`: oculto si el edificio es el núcleo urbano.
  - Botón `"Asignar como núcleo urbano"`: visible en residenciales construidos (que no sean el núcleo actual).
- **Demolición Programada:**
  - Al pulsar `"Demoler"`, se muestra una ventana de confirmación modal.
  - Al confirmar, entra en estado de **espera de 5 horas de juego**:
    - El edificio se resalta con overlay **naranja**.
    - El panel muestra el tiempo restante y el botón cambia a `"Cancelar demolición"`.
    - Si el jugador cancela, vuelve a estado normal y el overlay se retira.
    - Cumplidas las 5 horas, el edificio se marca formalmente para demolición por los obreros y el overlay cambia a **rojo**.
- **Traslado de Núcleo Urbano:**
  - Al pulsar `"Asignar como núcleo urbano"`, se abre una ventana modal de advertencia que informa:
    - El tiempo de mudanza (5 horas de juego).
    - El cálculo de camas: si el nuevo núcleo deja al núcleo anterior con menos camas de las necesarias para reubicar a sus residentes, advierte de desahucio.
  - Al confirmar:
    - Entra en espera de 5 horas (cancelable con `"Cancelar mudanza"`).
    - Al cumplirse las 5 horas:
      1. El nuevo edificio se registra como núcleo urbano; el anterior pasa a ser residencial normal.
      2. Los residentes se reubican.
      3. Si hay déficit de camas general en la ciudad, se desahucian ciudadanos generales en el orden:
         $$\text{desempleado} \rightarrow \text{obrero} \rightarrow \text{tecnico} \rightarrow \text{especialista} \rightarrow \text{investigador} \rightarrow \text{militar}$$
      4. Se recalcula el área de influencia en `Zonificacion`.
- **Visibilidad de Zonas en Vista Cenital (`ZonaOverlay.gd`):**
  - Las capas de zonas pintadas (Residencial e Industrial) **solo** son visibles cuando:
    - Está activo el modo `Zonas` (herramienta de zonificación).
    - Se está colocando un blueprint residencial (`modo_colocar_blueprint`).
    - Se está colocando una industria o edificio de investigación (`modo_colocar_puesto` en categorías `industrial` o `investigacion`).
  - En vista libre (`Ver`), puestos periféricos y trazado de vías: las zonas pintadas permanecen ocultas y solo se visualiza el tinte translúcido del área de influencia.

---

## 3. Estrategia de Pruebas Automatizadas

1. **`EconomiaTest.gd` / `CiudadTest.gd`:**
   - Consumo de 5 tablas por bloque de madera antes de tocar madera.
   - Reembolso simétrico exacto.
   - Permanencia de investigadores tras investigar Metalurgia Aplicada.
2. **`ColonosTest.gd` / `ObrasTest.gd`:**
   - Asignación de hasta 4 colonos por obra; el 5.º colono busca otra tarea o deambula.
   - Cancelación de demolición durante las 5 horas de gracia.
   - Transición de overlay naranja $\rightarrow$ rojo al vencer las 5 horas.
   - Mudanza de núcleo urbano y orden estricto de desahucio ante déficit.
3. **`BlueprintsTest.gd` / `HUDTest.gd`:**
   - Historial FIFO de 5 blueprints residenciales; descarte del 6.º.
   - Paginación en `BarraModos` con teclas `1`–`9`, `0`, `Z` y `X`.
   - Fila de especialistas visible en nivel 1.
4. **`NiveladorTerrenoTest.gd`:**
   - Alineación de cota $Y$ ante puertas enfrentadas.

# Fichas de Consumo y Producción Consolidadas (Craft to Nation)

Este documento representa la **fuente única de verdad consolidada y auditada** para el balance del juego *Craft to Nation*, cruzando el Documento de Diseño de Juego (GDD), las fichas históricas (`docs/Fichas_Consumo_Produccion.md`) y el código implementado en el motor (`godot/scripts/`). Sirve como especificación para la wiki oficial del juego (`website/wiki/`), sus calculadoras interactivas y futuras extensiones de balance.

---

## 1. Parámetros de Referencia Estándar (Wiki & Macro-Ciclo)

Para propósitos de diseño general, calculadoras interactivas de la wiki (`ProductionCalculator.vue`) y balance macroscópico, se define un ciclo base estandarizado:

| Parámetro / Recurso | Valor Consolidado | Unidad / Contexto |
| :--- | :--- | :--- |
| **Ciclo_Segundos** | 60 | Segundos reales por ciclo estándar de cálculo |
| **Comida** | 1 | Consumo básico por colono por ciclo estándar |
| **Agua** | 1 | Consumo básico por colono por ciclo estándar |
| **Madera** | 2 | Rendimiento base de recolección por leñador por ciclo |
| **Piedra** | 2 | Rendimiento base de recolección por cantero por ciclo |
| **Almacenamiento Inicial** | 100 | Capacidad inicial por recurso básico en el inventario/almacén |

> [!NOTE]
> Estos ratios corresponden a la escala simplificada para cálculo de supervivencia básica de colonias a escala de 1 minuto (60 segundos). A nivel de simulación interna en Godot, el motor ejecuta ticks discretos de 2.0 segundos equivalentes a 1 hora de tiempo de juego.

---

## 2. Auditoría Técnica de Simulación en Motor Godot

### 2.1 Tiempo y Ticks (`Ciudad.gd`)
- **Duración de un Tick (`SEGUNDOS_POR_TICK`):** 2.0 segundos reales = 1 hora de juego.
- **Relación de tiempo:** 1 Ciclo estándar (60s) = 30 ticks de simulación (30 horas de juego).
- **Almacenamiento central (`Ciudad.almacen`):**
  - Límite base general (`LIMITE_BASE`): 500 unidades por recurso.
  - Límite base comida (`LIMITE_BASE_COMIDA`): 5000 unidades.
  - Comida inicial (`COMIDA_INICIAL`): 5000 unidades (el stock comienza lleno).
  - Madera inicial: 200 unidades.
  - Factor de declaración de núcleo (`FACTOR_NUCLEO`): ×2 al declarar el núcleo urbano.
  - Bono por baúl residencial colocado (`BONO_BAUL`): +100 capacidad (+400 en comida).

---

### 2.2 Fichas Demográficas y Consumo por Tipo de Población

Fuente: `Ciudad.TIPOS_POBLACION` (implementado en `Ciudad.gd` a partir de `docs/Recursos.xlsx`).

| Unidad | Comida (unid/h) | Combustible (unid/h) | Energía (unid/h) | "x Cama" (Capacidad) |
| :--- | :--- | :--- | :--- | :--- |
| **Ciudadano** | 2 | 0 | 0 | 5 |
| **Desempleado** | 3 | 0 | 0 | 4 |
| **Obrero** | 5 | 0 | 0 | 4 |
| **Técnico** | 3 | 0 | 0 | 3 |
| **Especialista** | 2 | 0 | 1 | 2 |
| **Investigador** | 1 | 0 | 2 | 1 |
| **Militar** | 4 | 2 | 0 | 3 |

**Reglas de consumo y penalización:**
- **Inanición:** Si el stock de comida no cubre `gasto_total`, ocurre una baja de población de hasta el 25% del censo total por tick (`bajas_inanicion = max(1, int(censo_total * 0.25))`), priorizando el orden: `militar -> obrero -> tecnico -> especialista -> investigador -> desempleado -> ciudadano`.
- **Período de elecciones:** Durante un cambio de gobierno o elecciones, el consumo de comida aumenta en un +10% temporal.
- **Agua:** El sistema de fluidos por tuberías y acueductos (`Canalizaciones.gd`) abastece agua como insumo industrial y reserva básica; el consumo metabólico universal de agua líquida se integra alineado a 1 unidad por ciclo en la capa macro de supervivencia.

---

### 2.3 Puestos Periféricos y Recolección de Crudos (`Recoleccion.gd`)

| Puesto | Recurso Obtenido | Tasa Base (unid/trabajador/h) | Personal Máx. | Almacén Local | Huella / Radio |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Maderero** | Madera (Tronco) | 5.0 | 5 | 1000 | 3×4 / Radio 12 |
| **Mina — Piedra** | Piedra | 5.0 | 5 | 1000 | 5×5 / Radio 6 (prof. 8-24) |
| **Mina — Hierro** | Hierro | 5.0 | 5 | 1000 | 5×5 / Radio 6 |
| **Mina — Cobre** | Cobre | 5.0 | 5 | 1000 | 5×5 / Radio 6 |
| **Mina — Carbón** | Carbón | 5.0 | 5 | 1000 | 5×5 / Radio 6 |
| **Mina — Tierras Raras**| Tierras Raras | 5.0 | 5 | 1000 | 5×5 / Radio 6 |
| **Mina — Tierra** | Tierra | 1.0 | 5 | 1000 | 5×5 / Radio 6 |
| **Caza y Recolección** | Comida (Caza + Frutos) | 17.0 (Caza) + 10.0 (Frutos) | 7 | 1000 | 4×4 / Radio 12 |
| **Pesca y Frutos Mar** | Comida (Pesca + Algas) | 17.0 (Pesca) + 3.0 (Algas) | 7 | 1000 | 4×6 / Radio 25 |
| **Estación de Bombeo** | Agua | 2.0 (bombeo superficial continuo)| 3 | 1000 | Red de acueductos |
| **Centro Extracción** | Crudo | 2.0 (bombeo subterráneo continuo) | 3 | 1000 | Red de tuberías |

**Fórmulas dinámicas:**
- **Madera:** `Tasa = 5.0 * densidad_madera_area * multiplicador_nivel`. Umbral de agotamiento: `< 0.5 madera/h`.
- **Caza y Frutos:** `Tasa = (17.0 * densidad_fauna) + (10.0 * densidad_frutal)`. Promedio en terreno natural: ~12.2 comida/h por recolector.
- **Pesca y Algas:** Ponderada por profundidad (`0.5` en aguas someras a `1.5` en profundas) y escala de masa de agua (`celdas / 450`, rango `[0.4, 1.5]`). Promedio mundial: ~8.6 comida/h.

---

### 2.4 Bloques Minables vs Bloques Colocables

Fuente: `Recoleccion.RENDIMIENTO_POR_BLOQUE` y `NiveladorTerreno.COSTO_POR_CELDA`.

| Material | Rendimiento al Extraer (Bloque Natural) | Bloque Colocable | Costo de Colocación (Stock Central) |
| :--- | :--- | :--- | :--- |
| **Tierra** | 1 unidad Tierra | `tierra` / `tierra_compactada` | 1 Tierra |
| **Piedra** | 10 unidades Piedra | `bloque_piedra` | 5 Piedra (o 1 bloque procesado) |
| **Hierro** | 10 unidades Hierro | `estructura_hierro` | 5 Hierro |
| **Madera** | 10 unidades Madera / celda tronco | `bloque_madera` | 5 Madera (o 1 tabla procesada) |
| **Acero** | (No se mina; se refina) | `bloque_acero` | 3 Acero |
| **Vidrio** | (No se mina; se fabrica) | `vidrio` | 1 Tierra |

---

### 2.5 Industrias y Cadenas de Refinamiento (`CadenaMinerales.gd`)

Todas las refinerías operan con cupo de 4 trabajadores (técnicos/especialistas) y capacidad local de 1000 unidades:

| Edificio / Receta | Insumos Requeridos | Producto | Tasa Base (lotes/trabajador/h) | Energía por Lote |
| :--- | :--- | :--- | :--- | :--- |
| **Siderúrgica** | 3 Hierro + 4 Carbón | 2 Acero | 2.0 | 0 |
| **Refinería Tierras Raras**| 3 Tierras Raras | 1 Mineral Refinado | 0.5 | 0 |
| **Aserradero** | 1 Madera | 3 Tablas | 0.5 | 0 |
| **Fábrica de Bloques** | 1 Piedra | 3 Bloques de Piedra | 0.5 | 0 |
| **Carbonera** | 3 Madera | 1 Carbón | 2.0 | 0 |
| **Refinería Petrolera** | 2 Crudo | 1 Combustible | 1.0 | 1 |
| **Productor Combustible** | 3 Carbón + 1 Agua | 2 Combustible | 1.0 | 1 |
| **Central Termoeléctrica**| 1 Carbón, Crudo o Combustible | 20 Energía | Quema dinámica según demanda | N/A |

---

### 2.6 Logística y Acarreo (`Economia.gd`, `Colonos.gd`)
- **Velocidad de Colono:** 2.5 celdas/segundo (5.0 celdas por hora de juego).
- **Capacidad de Carga de Acarreador:** 150 unidades por viaje.
- **Carga Mínima de Refinería:** 10 unidades (evita viajes innecesarios).
- **Jerarquía de Transporte en Rutas Estrechas:** `Comida > Combustible > Crudo > Acero > Mineral Refinado > Hierro > Cobre > Carbón > Tierras Raras > Tablas > Madera > Piedra > Tierra > Agua`.

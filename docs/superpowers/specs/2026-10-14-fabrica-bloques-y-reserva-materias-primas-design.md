# Especificación de Diseño: Fábrica de Bloques y Reserva de Materias Primas en Refinerías

**Fecha:** 2026-10-14  
**Estado:** Propuesta de Diseño  
**Área:** Economía, Industria, HUD y Logística de Producción (Fase 3 - PoC 5)

---

## 1. Visión y Objetivos

1. **Fábrica de Bloques (`fabrica_bloques`):**
   * Incorporar el edificio industrial análogo y simétrico al Aserradero (`aserradero`) para el procesamiento de piedra.
   * Multiplicar el rendimiento de la piedra cruda extraída de las minas mediante la producción de `bloques_piedra` (1 piedra $\to$ 3 bloques de piedra).
   * Integrar `bloques_piedra` en la lógica de construcción de `Ciudad.gd`: cualquier coste que demande `piedra` (muros de `bloque_piedra`, nivelaciones, cimientos) se cobrará prioritariamente descontando `bloques_piedra` procesados antes de agotar la `piedra` cruda.

2. **Control de Reserva de Materia Prima en Refinerías (Esquema A):**
   * Resolver el problema de sobre-refinado donde las industrias consumen el 100% de la materia prima del almacén central, impidiendo al jugador construir bloques estructurales (`estructura_hierro`, bloques de madera, etc.).
   * Añadir un selector de **Reserva Mínima en Ciudad** en el panel de refinerías (`PanelPuesto` / `PanelEdificio`).
   * Configurable por edificio o por tipo de insumo entre valores predefinidos: `[0, 50, 100, 250, 500]`.
   * Los acarreadores solo retiran insumos del almacén central si el stock disponible supera la reserva configurada (`stock_central - pedido > reserva_minima`).

---

## 2. Especificación Técnica de la Fábrica de Bloques

### 2.1. Catálogo y Menú de Construcción
* **Identificador interno:** `"fabrica_bloques"`
* **Nombre legible:** `"Fábrica de bloques"`
* **Categoría:** `"industrial"` en `BarraModos.gd`.
* **Ubicación en menú:** Posición 4 dentro del menú Industrial (después de Aserradero), reasignando teclas numéricas del 1 al 9:
  1. Siderúrgica
  2. Tierras raras
  3. Aserradero
  4. **Fábrica de bloques**
  5. Carbonera
  6. Refinería petrolera
  7. Productor combustible
  8. Central termoeléctrica
  9. Almacén
* **Miniatura 3D:** Se añade a `TIPOS_CON_MINIATURA` en `BarraModos.gd` para renderizar la previsualización isométrica en vivo.

### 2.2. Arquitectura y Plantilla (`PlantillasPuesto.gd`)
* **Material principal de muros:** `"bloque_piedra"`
* **Dimensiones de huella:** 5 celdas de ancho por 6 celdas de largo (5x6).
* **Distribución de celdas:**
  * Losa de cimentación y muros perimetrales en `bloque_piedra`.
  * **Entrada de servicio (z = 0):** Puerta de entrada para acarreadores de piedra cruda (`e` / `E`).
  * **Salida de producto (z = 5):** Puerta de salida para acarreadores de bloques terminados (`s` / `S`).
  * **Depósito local:** Baúl interior (`B`) que almacena el insumo (`piedra`) y el producto procesado (`bloques_piedra`).
  * **Ventanas (`V`):** Iluminación lateral en los laterales largos.
  * **Techo y chimenea:** Techo de losa con chimenea de trituración/cantería en el techo (`chimenea = Vector2i(2, 3)`), emitiendo partículas de polvo/humo de cantería mediante `HumoRefinerias.gd`.

### 2.3. Receta Industrial (`CadenaMinerales.gd`)
* **Registro en `RECETAS`:**
  ```gdscript
  "fabrica_bloques": {
      "entradas": {"piedra": 1},
      "tipo_salida": "bloques_piedra",
      "cantidad_salida": 3,
      "tasa_base": 0.5,
      "energia_por_lote": 0
  }
  ```
* **Registro en `REFINERIAS`:**
  ```gdscript
  "fabrica_bloques": "fabrica_bloques"
  ```
* **Capacidad y personal:**
  * Máximo 4 trabajadores (técnicos/obreros).
  * Capacidad de almacén local compartida de 1000 unidades.

### 2.4. Integración en `Ciudad.gd` (Almacén y Consumo)
* **Nuevo recurso cívico:**
  * Registrado en `Ciudad.almacen`: `"bloques_piedra": Recurso.new("Bloques de piedra", 0, LIMITE_BASE)`.
* **Lógica de pago en `Ciudad.consumir_costo()`:**
  * Para cualquier coste en `"piedra"`:
    1. Se calcula la cantidad disponible en `almacen["bloques_piedra"]`.
    2. Se cobra primero con `bloques_piedra`.
    3. Si el coste no se cubre totalmente, el resto se cobra de `piedra` cruda.
    4. El desglose devuelto refleja con precisión cuánto se descontó de cada recurso.
* **Cálculo de disponibilidad en `Ciudad.almacen_general()`:**
  * Al consultar la disponibilidad de `"piedra"`, la cantidad total reportada incluye tanto `almacen["piedra"]` como `almacen["bloques_piedra"]`.

---

## 3. Especificación del Control de Reservas de Materia Prima (Esquema A)

### 3.1. Estado y Modelo de Datos (`Economia.gd`)
* Cada refinería registrada en `puestos[esquina]` almacenará un nuevo campo:
  * `"reserva_insumo": float` (por defecto `0.0`).
* **Valores admitidos:** `[0, 50, 100, 250, 500]`.
* **Métodos en `Economia.gd`:**
  * `func obtener_reserva_insumo(esquina: Vector2i) -> float`
  * `func establecer_reserva_insumo(esquina: Vector2i, valor: float) -> void`
  * `func ciclar_reserva_insumo(esquina: Vector2i) -> float`

### 3.2. Lógica de Despacho de Insumos (`Economia.insumos_a_cargar()`)
* Al calcular los insumos que un acarreador puede retirar del almacén central para una refinería:
  ```gdscript
  var stock_central: float = ciudad.almacen[recurso].cantidad
  var reserva: float = p.get("reserva_insumo", 0.0)
  var disponible_para_refinar: float = maxf(0.0, stock_central - reserva)
  var cantidad: float = minf(minf(CAPACIDAD_CARGA * parte, espacio), disponible_para_refinar)
  ```
* Si el stock central de la materia prima es menor o igual a la reserva configurada, `disponible_para_refinar` es `0.0`, por lo que el acarreador no extrae material del almacén central y la materia prima queda intacta para obras y construcciones del jugador.

### 3.3. Refinerías Afectadas
Este control aplica automáticamente a todas las refinerías que consumen insumos sólidos del stock central:
1. **Siderúrgica:** Reserva de `hierro` (para proteger `estructura_hierro`).
2. **Aserradero:** Reserva de `madera` (para proteger `bloque_madera`).
3. **Fábrica de bloques:** Reserva de `piedra` (para proteger `bloque_piedra` y nivelaciones).
4. **Carbonera:** Reserva de `madera`.
5. **Refinería de tierras raras:** Reserva de `tierras_raras`.

### 3.4. Interfaz Gráfica (`PanelPuesto.gd` / `PanelEdificio.gd`)
* Para cualquier edificio que sea refinería (`Economia.es_refineria(esquina)`):
  * Se añade una fila de control visual:
    * Etiqueta: `"Reserva en ciudad:"`
    * Botón cíclico estilizado con TemaHUD: `"[ 0 ]"` $\to$ `"[ 50 ]"` $\to$ `"[ 100 ]"` $\to$ `"[ 250 ]"` $\to$ `"[ 500 ]"`.
    * Texto explicativo o tooltip: *"Garantiza que el almacén central no baje de esta cantidad por refinado."*

---

## 4. Plan de Pruebas y Validación (QA)

1. **`PlantillasPuestoTest.gd`:**
   * Verificar dimensiones 5x6 de `fabrica_bloques`.
   * Verificar presencia de puerta de entrada, salida, baúl local y chimenea.
2. **`CadenaMineralesTest.gd`:**
   * Verificar receta `fabrica_bloques` (1 piedra $\to$ 3 bloques_piedra).
   * Verificar procesamiento de ticks y tasas horarias.
3. **`EconomiaTest.gd`:**
   * Verificar que `es_refineria()` reconoce `fabrica_bloques`.
   * Verificar configuración de `reserva_insumo`.
   * Verificar que `insumos_a_cargar()` no retira piedra/hierro/madera si el stock central está por debajo del umbral de reserva.
4. **`CiudadTest.gd`:**
   * Verificar que `consumir_costo()` para `piedra` gasta primero `bloques_piedra` y luego `piedra`.
   * Verificar que `almacen_general()` totaliza ambos recursos.
5. **`HUDTest.gd`:**
   * Verificar que el botón de `fabrica_bloques` existe en el submenú Industrial con miniatura activa.
   * Verificar que el panel de refinería permite alternar la reserva de insumo.
6. **Comprobación Global:**
   * Ejecutar la suite completa de 28+ escenas de prueba mediante `tools/run-godot-tests.ps1`.

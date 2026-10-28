# Especificación Técnica: Balance de Economía de Alimentos, Metabolismo y Demografía

**Estado:** Aprobado para implementación  
**Fecha:** 2026-10-26  
**Módulos Afectados:** `godot/scripts/ajustes.gd`, `godot/scripts/Ciudad.gd`, `godot/scripts/Economia.gd`, `godot/scripts/PanelEdificio.gd`, `godot/scripts/UI/VentanaAlmacen.gd`.

---

## 1. Resumen de Cambios

Este documento formaliza las directrices de balance y diseño de sistemas acordadas para la economía alimentaria, el consumo metabólico y la estabilización demográfica de *Craft to Nation*:

1. **Ajuste de tasas de consumo metabólico:** Se fija un suelo biológico de $2\text{ u/h}$ para evitar que los investigadores sean más baratos de alimentar que la mano de obra obrera. Se establece un consumo diferenciado para unidades militares (3 u/h en acantonamiento / guarnición dentro del área de influencia; 5 u/h desplegadas en campaña exterior).
2. **Sub-inventario de Comida Unificada:** El HUD y la UI externa continúan mostrando un recurso unificado `comida`. Internamente, el stock se distribuye en 6 categorías con una canalización estricta de consumo en orden de perecibilidad (de frescos a no perecederos).
3. **Peligro de Monocultivo y Escala de Dieta:** Tolerancia de gracia de 15 días (360 horas de juego) para dietas de 1 sola fuente; superado este periodo, penalización de $-0.2\text{ puntos/h}$ a la moral. Escala de bonificaciones crecientes para dietas mixtas (hasta $+2.0\text{ puntos/h}$ con 6 fuentes).
4. **Mecanismos Anti-Espiral de la Muerte:**
   - Suelo de productividad agraria blindado al $75\%$ ($X \ge 0.75$).
   - Decreto cívico de *"Racionamiento Estricto"* activable en el Núcleo Urbano (reducción de consumo del $-35\%$, moral máxima limitada a 35).

---

## 2. Modificaciones en `godot/scripts/ajustes.gd`

### 2.1 Tasas de Población y Metabolismo (`CIUDAD_TIPOS_POBLACION`)

Actualizar el diccionario `CIUDAD_TIPOS_POBLACION`:

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
```

### 2.2 Nuevas Constantes de Balance

Añadir en la sección de simulación de ciudad / demografía:

```gdscript
## Gasto adicional de comida para militares en operaciones exteriores (fuera de zona de influencia)
static var MILITAR_CONSUMO_COMIDA_DESPLEGADO: float = 5.0
static var MILITAR_CONSUMO_COMBUSTIBLE_DESPLEGADO: float = 2.0

## Orden de consumo de sub-categorías de comida (de más fresco a no perecedero)
static var CIUDAD_ORDEN_CONSUMO_COMIDA: Array[String] = [
	"pesca",             # 1. Pescado y mariscos frescos
	"recoleccion_caza",  # 2. Caza y frutos silvestres frescos
	"sembradios",        # 3. Cereales y cultivos
	"granjas_animales",  # 4. Carne y lácteos de establo
	"hidroponia",        # 5. Raciones hidropónicas protegidas
	"sintetico",         # 6. Alimento sintético / reserva de emergencia
]

## Ventana de gracia para dieta de una sola fuente (15 días de juego a 24 horas = 360 horas)
static var CIUDAD_GRACIA_MONOCULTIVO_HORAS: int = 360
static var CIUDAD_PENALIZACION_MONOCULTIVO_MORAL: float = -0.2  # Tasa horaria de moral

## Bonificaciones de moral según variedad dietética activa (categorías con stock > 0 en las últimas 24h)
static var CIUDAD_BONO_DIETA_2_3_FUENTES: float = 0.3    # +0.3/h
static var CIUDAD_BONO_DIETA_4_5_FUENTES: float = 1.0    # +1.0/h
static var CIUDAD_BONO_DIETA_6_FUENTES: float = 2.0      # +2.0/h

## Suelo mínimo de productividad para puestos y edificios de extracción/producción de comida
static var PRODUCTIVIDAD_SUELO_ALIMENTOS: float = 0.75

## Decreto de Racionamiento Estricto
static var RACIONAMIENTO_REDUCCION_CONSUMO: float = 0.35  # -35% de comida
static var RACIONAMIENTO_TECHO_MORAL: float = 35.0        # Límite superior de moral mientras esté activo
```

---

## 3. Modificaciones en `godot/scripts/Ciudad.gd`

### 3.1 Estructura del Sub-inventario de Comida

El recurso `comida` en el diccionario `almacen` (`almacen["comida"]`) mantiene su API pública de `Recurso` (`cantidad`, `limite`, etc.), pero incorpora un desglose interno:

```gdscript
## Sub-inventario interno de reservas alimentarias
var sub_almacen_comida: Dictionary = {
	"pesca": 0.0,
	"recoleccion_caza": 0.0,
	"sembradios": 0.0,
	"granjas_animales": 0.0,
	"hidroponia": 0.0,
	"sintetico": 0.0,
}

## Historial de horas acumuladas con monocultivo (1 sola fuente)
var horas_monocultivo_continuo: int = 0

## Estado del decreto cívico de racionamiento
var decreto_racionamiento_activo: bool = false
```

#### Reglas de sincronización:
- Al recibir entregas de un acarreador o producción directa de un puesto/edificio, la cantidad se añade tanto a `sub_almacen_comida[categoria]` como al acumulador principal `almacen["comida"].cantidad`.
- Al inicio de una partida nueva (`CIUDAD_COMIDA_INICIAL`), se inicializa equitativamente entre las fuentes de Era 1 (p. ej., 2500 en `recoleccion_caza` y 2500 en `pesca`) o 100% en `recoleccion_caza`.

### 3.2 Cascada de Consumo en `simular_tick()`

Al calcular `gasto_total`:
1. Si `decreto_racionamiento_activo == true`:
   $$gasto\_total = gasto\_total \times (1.0 - Ajustes.RACIONAMIENTO\_REDUCCION\_CONSUMO)$$
2. El descuento del stock se realiza iterando sobre `Ajustes.CIUDAD_ORDEN_CONSUMO_COMIDA`:

```gdscript
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
	
	# Reflejar en el Recurso general
	var exito: bool = (almacen["comida"] as Recurso).consumir(cantidad_requerida)
	return exito
```

### 3.3 Regla de Monocultivo y Moral por Dieta

En `actualizar_bono_variedad()`:
- Contar cuántas categorías en `sub_almacen_comida` tienen stock $> 0$.
- **Si activas == 1:**
  - `horas_monocultivo_continuo += 1`
  - Si `horas_monocultivo_continuo > Ajustes.CIUDAD_GRACIA_MONOCULTIVO_HORAS`:
    - Aplicar tasa horaria `delta_escasez += Ajustes.CIUDAD_PENALIZACION_MONOCULTIVO_MORAL` ($-0.2$/h).
- **Si activas > 1:**
  - `horas_monocultivo_continuo = 0` (resetea el contador de monotonía).
  - Si `activas in [2, 3]`: delta positivo de $+0.3$/h.
  - Si `activas in [4, 5]`: delta positivo de $+1.0$/h.
  - Si `activas == 6`: delta positivo de $+2.0$/h ("Banquete de la Civilización").

### 3.4 Suelo de Productividad Agraria ($X_{\text{alimentos}}$)

En `Ciudad.calcular_multiplicador_productividad()`:

```gdscript
static func calcular_multiplicador_productividad(p_moral: float, es_recurso_alimento: bool = false) -> float:
	var x: float = Ajustes.CIUDAD_PRODUCTIVIDAD_BASE * pow(
		Ajustes.CIUDAD_PRODUCTIVIDAD_EXPONENCIAL_BASE,
		clampf(p_moral, 0.0, 100.0) / Ajustes.CIUDAD_PRODUCTIVIDAD_DIVISOR_MORAL
	)
	if es_recurso_alimento:
		return maxf(Ajustes.PRODUCTIVIDAD_SUELO_ALIMENTOS, x)
	return x
```

Cuando los puestos de recolección (`caza_recoleccion`, `pesca_frutos_mar`) o las futuras granjas evalúen su producción horaria, pasarán `es_recurso_alimento = true`, blindando su tasa al $75\%$ mínimo.

### 3.5 Límite de Moral bajo Decreto de Racionamiento

En la fase final de cálculo de moral en `simular_tick()`:
```gdscript
if decreto_racionamiento_activo:
	moral = minf(moral, Ajustes.RACIONAMIENTO_TECHO_MORAL)
```

---

## 4. Consumo Dinámico Militar (`Colonos.gd` / `Ciudad.gd`)

Al sumar el consumo militar en `simular_tick()`:
- Diferenciar militares según su posición espacial frente al área de influencia (`Zonificacion.dentro_de_influencia(posicion)`):
  - **En guarnición (interior):** $3.0\text{ comida/h} + 1.0\text{ combustible/h}$.
  - **Desplegados (exterior):** $5.0\text{ comida/h} + 2.0\text{ combustible/h}$.

---

## 5. Criterios de Aceptación y Pruebas Unitarias

1. **Prueba de Suelo Biológico:** Verificar que un `investigador` consuma $2.0\text{ u/h}$ y no $1.0\text{ u/h}$.
2. **Prueba de Cascada de Consumo:** Con almacén conteniendo $20\text{ pesca}$, $30\text{ caza}$ y $50\text{ sembradios}$, un consumo de $35\text{ u}$ debe dejar $0\text{ pesca}$, $15\text{ caza}$ y $50\text{ sembradios}$.
3. **Prueba de Gracia de Monocultivo:** Durante las primeras 360 horas con solo `recoleccion_caza`, no se aplica penalización de monotonía. A la hora 361, se activa el $-0.2\text{/h}$.
4. **Prueba de Suelo de Productividad:** Con moral $0.0$, un puesto maderero/minero rinde al $50\%$ ($0.5\times$), pero el puesto de caza o pesca rinde al $75\%$ ($0.75\times$).
5. **Prueba de Racionamiento:** Al activar el decreto, el consumo por habitante se reduce un $35\%$ y la moral no supera $35.0$.

# Especificación Técnica Adaptada: Red Logística, Unidades de Transporte y Edificio de Fabricación Evolutivo

**Estado:** Aprobado para implementación  
**Fecha:** 2026-10-26  
**Módulos Afectados:** `godot/scripts/ajustes.gd`, `godot/scripts/strings.gd`, `godot/scripts/Economia.gd`, `godot/scripts/Colonos.gd`, `godot/scripts/BuscadorRutas.gd`, `godot/scripts/Ciudad.gd`, `godot/scripts/PlantillasPuesto.gd`, `godot/scripts/BarraModos.gd`, `godot/scripts/Recoleccion.gd`, `godot/scripts/PanelPuesto.gd`.

---

## 1. Resumen Ejecutivo e Integración con el Ecosistema

Esta especificación formaliza la evolución del sistema de transporte, acarreo y logística de *Craft to Nation*, integrándose limpiamente con la economía de recursos, la infraestructura vial y la investigación tecnológica:

1. **Escalera de Unidades de Transporte:** Progresión de capacidades de carga ($150\text{ u} \to 350\text{ u} \to 750\text{ u} \to 1.800\text{ u}$) con tripulación estándar de **1 obrero** (o **0 obreros** en el caso del Dron Autónomo de Carga).
2. **Edificio de Fabricación Evolutivo (`taller_transporte`):** Un edificio industrial ubicado en la Zona Industrial (Núcleo B) que evoluciona automáticamente según la **era actual** de la ciudad y las **tecnologías investigadas** (sin botones de subida de nivel manual como los puestos periféricos):
   - *Era 2 / Base (Taller de Carretas):* Disponible al construir el taller. Ensambla Carretas de Mano.
   - *Era 2 + Tracción Animal y Engranajes (Establo de Transporte):* Al investigar `traccion_animal_engranajes`, el edificio evoluciona automáticamente para criar y equipar Carros de Tiro con Caballos (requiere al menos una `granjas_animales` activa en la ciudad).
   - *Era 3+ (Taller de Maquinaria y Transporte Pesado):* Al alcanzar la Era 3 (o superior) e investigar las tecnologías correspondientes (`combustion_pesada_blindajes`, `automatizacion_cibernetica`, `redes_electricas_bobinado`), el edificio evoluciona para fabricar Camiones Diésel, Drones Autónomos y Trolebuses.
3. **Mecánica de Insumos y Arrastre Lento (Sin Roturas ni Destrucción):**
   - Las unidades no sufren averías ni requieren mantenimiento de reparación.
   - Si se quedan sin su insumo operativo (forraje/comida, combustible o energía eléctrica), **no se destruyen ni desaparecen**: entran dinámicamente en estado `RALENTIZADO`, moviéndose a velocidad mínima de arrastre ($1.2\text{ m/s}$), penalizando severamente el caudal horario pero sin romper la cadena logística ni bloquear el juego.
   - En cuanto el insumo se repone en el stock central o red eléctrica, la unidad recupera instantáneamente su velocidad normal.
4. **Restricción Estricta de Circulación Vial para Vehículos Pesados:**
   - Los camiones diésel y trolebuses pesados tienen `exige_via = true`: no pueden transitar sobre terreno natural virgen (`coste = 8`).
   - El pathfinding (`BuscadorRutas.gd`) exige una red vial afirmada continua (`Vias.es_via(soporte) == true`). Si no hay conexión continua entre el puesto y el almacén receptor, el sistema notifica el bloqueo.

---

## 2. Catálogo Oficial de Unidades de Transporte (`ajustes.gd`)

Los recursos se alinean 100% con los inventarios reales del juego (`madera`, `tablas`, `hierro`, `acero`, `tierra` —bloque base para vidrios/ventanas—, `combustible`, `cobre`, `tierras_raras`, `comida`):

```gdscript
# ==============================================================================
# LOGÍSTICA Y UNIDADES DE TRANSPORTE
# ==============================================================================
static var TRANSPORTE_VELOCIDAD_RALENTIZADA_SIN_INSUMO: float = 1.2  # m/s de arrastre forzado

static var TRANSPORTE_CATALOGO_UNIDADES: Dictionary = {
	"acarreador_pie": {
		"nombre": "Acarreador a Pie",
		"capacidad": 150.0,
		"velocidad_base": 2.5,
		"tripulacion": "obrero",
		"cantidad_tripulacion": 1,
		"insumo_tipo": "",
		"insumo_consumo_h": 0.0,
		"exige_via": false,
		"penalizacion_tierra": 0.0,
		"era_minima": 1,
		"tech_requerida": "",
		"costo_fabricacion": {},
		"tiempo_fabricacion": 0.0,
	},
	"carreta_mano": {
		"nombre": "Carreta de Mano",
		"capacidad": 350.0,
		"velocidad_base": 3.2,
		"tripulacion": "obrero",
		"cantidad_tripulacion": 1,
		"insumo_tipo": "",
		"insumo_consumo_h": 0.0,
		"exige_via": false,
		"penalizacion_tierra": 0.40, # En terreno natural pierde 40% de velocidad
		"era_minima": 2,
		"tech_requerida": "",
		"costo_fabricacion": {"madera": 40.0, "hierro": 10.0},
		"tiempo_fabricacion": 15.0,
	},
	"carro_caballos": {
		"nombre": "Carro de Tiro (Caballos)",
		"capacidad": 750.0,
		"velocidad_base": 4.5,
		"tripulacion": "obrero",
		"cantidad_tripulacion": 1,
		"insumo_tipo": "comida", # Forraje extraído de comida
		"insumo_consumo_h": 1.0,
		"exige_via": false,
		"penalizacion_tierra": 0.60, # En terreno natural pierde 60% de velocidad
		"req_puesto": "granjas_animales", # Requiere puesto de animales activo
		"era_minima": 2,
		"tech_requerida": "traccion_animal_engranajes",
		"costo_fabricacion": {"tablas": 60.0, "hierro": 25.0, "comida": 30.0},
		"tiempo_fabricacion": 25.0,
	},
	"camion_diesel": {
		"nombre": "Camión Pesado Diésel",
		"capacidad": 1800.0,
		"velocidad_base": 6.5,
		"tripulacion": "obrero",
		"cantidad_tripulacion": 1,
		"insumo_tipo": "combustible",
		"insumo_consumo_h": 2.0,
		"exige_via": true, # Totalmente bloqueado en terreno natural
		"penalizacion_tierra": 1.0,
		"era_minima": 3,
		"tech_requerida": "quimica_hidrocarburos",
		"costo_fabricacion": {"acero": 80.0, "combustible": 50.0, "tierra": 20.0}, # tierra = vidrio/ventanas
		"tiempo_fabricacion": 40.0,
	},
	"dron_carga": {
		"nombre": "Dron Autónomo de Carga",
		"capacidad": 400.0,
		"velocidad_base": 8.0,
		"tripulacion": "", # 0 Humanos: no ocupa censo
		"cantidad_tripulacion": 0,
		"insumo_tipo": "energia",
		"insumo_consumo_h": 3.0, # 3 kW continuos
		"exige_via": false, # Tránsito aéreo
		"penalizacion_tierra": 0.0,
		"era_minima": 4,
		"tech_requerida": "automatizacion_cibernetica",
		"costo_fabricacion": {"acero": 30.0, "tierras_raras": 20.0, "cobre": 40.0},
		"tiempo_fabricacion": 30.0,
	},
	"trolebus_solar": {
		"nombre": "Trolebús Eléctrico Bio-Vía",
		"capacidad": 900.0,
		"velocidad_base": 5.0,
		"tripulacion": "obrero",
		"cantidad_tripulacion": 1,
		"insumo_tipo": "energia",
		"insumo_consumo_h": 1.5, # 1.5 kW continuos
		"exige_via": true,
		"penalizacion_tierra": 1.0,
		"era_minima": 3,
		"tech_requerida": "redes_electricas_bobinado",
		"costo_fabricacion": {"tablas": 50.0, "acero": 40.0, "cobre": 30.0, "tierra": 15.0}, # tierra = vidrio/ventanas
		"tiempo_fabricacion": 35.0,
	},
}
```

---

## 3. Edificio de Fabricación Evolutivo: `taller_transporte`

1. **Categoría y Emplazamiento:** Se emplaza en Zona Industrial mediante la barra de modos (`BarraModos.gd`), con plantilla 5x5 (`PlantillasPuesto.gd`). Costo de construcción base: `{"madera": 100, "piedra": 100}` (disponible desde Era 2).
2. **Evolución por Era y Tecnologías Investigadas:**
   A diferencia de los puestos periféricos que se suben de nivel manualmente por botón pagando mejoras, el `taller_transporte` es un **edificio evolutivo** cuyo estado y catálogo disponible se actualizan de forma automática en tiempo real en función del progreso de la ciudad:
   - **Taller de Carretas (Era 2 / Inicial):** Desbloqueado por defecto al construirlo en Era 2. Produce Carretas de Mano.
   - **Establo de Transporte (Era 2 + `traccion_animal_engranajes`):** Al investigar la ciencia teórica `traccion_animal_engranajes`, el taller evoluciona automáticamente a Establo de Transporte, permitiendo ensamblar Carros de Tiro con Caballos (si hay al menos una `granjas_animales` activa en la ciudad).
   - **Taller de Maquinaria y Transporte (Era 3+):** Al alcanzar la Era 3 o superior, el edificio evoluciona su denominación a Taller de Maquinaria. El catálogo de fabricación se habilita según las ciencias teóricas descubiertas:
     - `quimica_hidrocarburos` (Era 3) $\to$ Camión Pesado Diésel.
     - `redes_electricas_bobinado` (Era 3) $\to$ Trolebús Eléctrico Bio-Vía.
     - `automatizacion_cibernetica` (Era 4) $\to$ Dron Autónomo de Carga.
3. **Cola de Fabricación:**
   - El jugador selecciona qué vehículo fabricar en `PanelPuesto.gd` entre los que estén actualmente desbloqueados por Era y Tecnologías.
   - Se descuentan los recursos del almacén central.
   - Se asignan obreros del taller al montaje. Al completarse el tiempo de ensamble, el vehículo entra al **Parque Móvil de la Ciudad** (`Ciudad.parque_transporte_disponible[tipo] += 1`).

---

## 4. Despliegue en Puestos y Dinámica de Acarreo

### 4.1 Asignación en Puestos Periféricos
- En `PanelPuesto.gd` (para puestos que cuenten con acarreadores), el jugador puede alternar el tipo de transporte asignado a la ruta.
- Al seleccionar un vehículo del parque disponible:
  - Se deduce `1` unidad de `Ciudad.parque_transporte_disponible[tipo]` y se suma a `Ciudad.parque_transporte_asignado[tipo]`.
  - Si el vehículo requiere tripulación (`cantidad_tripulacion > 0`), se asigna un obrero como conductor.
  - Si el vehículo es un **Dron Autónomo**, `cantidad_tripulacion == 0`: el acarreo funciona de forma totalmente desatendida sin ocupar obreros en el censo.
- Al desasignar o demoler el puesto, el vehículo retorna inmediatamente a `parque_transporte_disponible`.

### 4.2 Dinámica de Insumos y Arrastre Lento
Durante el desplazamiento (`_completar_paso` en `Colonos.gd`):
1. **Verificación de Insumo:**
   - *Sin insumo requerido (`""`):* Velocidad normal base $\times$ modificadores viales.
   - *Comida / Forraje:* Si `Ciudad.almacen["comida"].cantidad > 0`, descuenta `insumo_consumo_h / 3600.0` por segundo de marcha. Si no hay comida, entra en arrastre lento.
   - *Combustible:* Si `Ciudad.almacen["combustible"].cantidad > 0`, descuenta cuota por segundo. Si se agota, entra en arrastre lento.
   - *Energía:* Si la red eléctrica de la ciudad tiene déficit (`deficit == true`), entra en arrastre lento.
2. **Velocidad Efectiva:**
   - Si tiene insumo disponible:
     $$V_{\text{efectiva}} = V_{\text{base}} \times (1.0 - \text{penalizacion\_tierra}) \quad \text{si no está en vía}$$
     $$V_{\text{efectiva}} = V_{\text{base}} \times \text{Vias.bono\_en(soporte)} \quad \text{si transita sobre vía}$$
   - Si no tiene insumo:
     $$V_{\text{efectiva}} = \text{TRANSPORTE\_VELOCIDAD\_RALENTIZADA\_SIN\_INSUMO} = 1.2\text{ m/s}$$
3. **Caudal de Carga:**
   - El acarreador recoge hasta la capacidad de su vehículo (`Ajustes.TRANSPORTE_CATALOGO_UNIDADES[tipo]["capacidad"]`), multiplicando el caudal hasta $12\times$ respecto al acarreo a pie básico ($150\text{ u} \to 1.800\text{ u}$).

### 4.3 Restricción Vial en `BuscadorRutas.gd`
- Si la unidad tiene `exige_via == true` (Camiones Diésel y Trolebuses):
  - Cualquier celda de soporte donde `not Vias.es_via(soporte)` se considera no transitable (`es_transitable == false`).
  - Si no existe un trazado continuo de vías afirmadas entre el puesto y el almacén, el pathfinding falla limpiamente y emite aviso al jugador impidiendo la asignación hasta que se complete la carretera.

---

## 5. Criterios de Aceptación y Pruebas Automatizadas

1. **Prueba de Catálogo y Parámetros:** Validar capacidades ($150, 350, 750, 1800, 400, 900$), tripulaciones e insumos en `Ajustes`.
2. **Prueba de Capacidad de Acarreo:** Asignar un camión diésel a un puesto y comprobar que recoja y entregue $1.800\text{ u}$ en un solo viaje.
3. **Prueba de Modo Lento sin Insumo:** Simular un camión diésel sin combustible en el almacén; comprobar que su velocidad baje a $1.2\text{ m/s}$ manteniendo su carga intacta, y que recupere $6.5\text{ m/s}$ al ingresar combustible.
4. **Prueba de Restricción Vial:** Verificar que un camión diésel no pueda trazar ruta sobre terreno virgen sin carretera afirmada continua.
5. **Prueba de Dron Autónomo:** Fabricar y desplegar un dron de carga; comprobar que la cuadrilla de obreros asignada sea $0$ y que opere a $8.0\text{ m/s}$ demandando $3\text{ kW}$ de energía.
6. **Prueba de Evolución del Taller por Era y Tecnologías:** Verificar que el `taller_transporte` desbloquee secuencialmente `carro_caballos` al investigar `traccion_animal_engranajes`, y `camion_diesel`, `trolebus_solar` y `dron_carga` al avanzar a Era 3/4 e investigar sus ciencias teóricas correspondientes, actualizando el título del edificio sin cobro de reformas manuales.

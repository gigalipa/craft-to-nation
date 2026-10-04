# Formación avanzada, investigación y energía — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILLS: Use `ponytail:ponytail` in **full** mode throughout, plus `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to execute task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar la escuela de especialistas, universidad/investigación, combustible y energía con el menor cambio que reutilice correctamente los sistemas actuales.

**Architecture:** Extender `Recoleccion`, `Economia`, `Ciudad` y `CadenaMinerales` en vez de crear gestores paralelos. Añadir solo `Energia.gd`, como helper puro sin autoload ni estado, para calcular conectividad y reparto; `Economia.simular_hora()` lo llama antes de procesar escuelas, universidad y recetas.

**Tech Stack:** Godot 4.7, GDScript, autoloads existentes, `GridMap`/`MeshLibrary`, escenas de prueba existentes y PowerShell.

**Spec:** `docs/superpowers/specs/2026-10-04-formacion-investigacion-energia-design.md`

## Global Constraints

- Antes de cada tarea, aplicar la escalera Ponytail: necesidad → reutilización existente → API nativa → mínimo código nuevo.
- No crear `CadenaProduccion`, `Investigacion`, un coordinador de ticks, interfaces, fábricas, registros genéricos ni nuevas escenas de prueba.
- El único archivo lógico nuevo permitido es `godot/scripts/Energia.gd`; si una tarea parece exigir otro, detenerse y demostrar por qué los scripts existentes no sirven.
- Mantener las 26 escenas actuales: `CiudadTest` cubre recursos/investigación, `EconomiaTest` producción/energía, `ColonosTest` oficios, `ViasTest` transmisión, `PlantillasPuestoTest` edificios/costos, `PuestosPrevisualizacionTest` colocación y `HUDTest` presentación.
- No añadir dependencias ni preparar cintas, tuberías, ferrocarriles, prioridades energéticas configurables o consumo universal de Era 3.
- Energía es flujo horario no almacenable; nunca entra en `Ciudad.almacen` ni en cargas de colonos.
- `agua`, `crudo` y `combustible` sí son recursos almacenables con límite base 500 e inicio cero; las bombas físicas quedan fuera.
- Las escuelas y universidad no tienen almacén ni acarreadores. Las tres industrias reutilizan puestos, presencia, almacén local y acarreo existentes.
- El costo real de cada edificio es la suma de sus bloques; no añadir un cobro plano paralelo.
- Conservar español, tabulaciones GDScript y los números de la spec. No reformatear archivos completos.
- Crear `codex/formacion-investigacion-energia` desde `main`; jamás incluir cambios locales del usuario bajo `arte/`, `.tmp` o `.uid` no relacionados.

## Ponytail Decisions

| Necesidad | Solución mínima | Se omite deliberadamente |
|---|---|---|
| Más recetas | Ampliar `CadenaMinerales.RECETAS`/`REFINERIAS` | Renombrar el script, fachada de compatibilidad, catálogo nuevo |
| Investigación física | Pasar horas desde `Economia` a `Ciudad.actualizar_investigacion(horas)` | Autoload `Investigacion`, selector y cola; solo hay una ruta lineal |
| Energía | Un helper puro llamado una vez por hora | Autoload con registros/señales/caché |
| Transmisión | Flood-fill XZ de las vías al inicio de cada hora | Grafo persistente e invalidación incremental; mundo actual 200×200 |
| Pruebas | Añadir casos a escenas existentes | Tres escenas y fixtures nuevos |
| Escuela avanzada | Segunda entrada en `Recoleccion.ESCUELAS` | Jerarquía/clases de escuelas |
| Industrias | Reutilizar `Economia.puestos` y acarreo | Sistema industrial paralelo |

Los recortes con techo conocido llevan comentario `# ponytail:` solo donde exista un límite real: flood-fill horario y ruta lineal de investigación.

## Review Focus

- Pago de investigación: si falta hierro o madera al completar, ningún recurso disminuye y el progreso no se pierde (Task 2, `CiudadTest`).
- Cohortes: la escuela técnica conserva 4→3/24 h mientras la avanzada hace 3→2/48 h y ambas conservan vivienda (Task 1, `EconomiaTest`/`ColonosTest`).
- Receta bajo dos límites: déficit energético y almacén casi lleno deben limitar el mismo lote sin consumir insumo de más (Task 3, `EconomiaTest`).
- Red: cortar el único tramo desconecta; una rampa con otra Y sigue conectada por su columna XZ (Task 4, `ViasTest`).
- Central: con exceso de capacidad solo quema lo entregado, y con demanda cero no quema nada (Task 4, `EconomiaTest`).

## File Map

**Create**

- `godot/scripts/Energia.gd`: cálculo puro de conectividad, demanda, capacidad, reparto y plan de quema.

**Modify**

- `godot/scripts/Recoleccion.gd`: escuela avanzada, universidad y fichas de cupo/capacidad.
- `godot/scripts/Economia.gd`: ciclo horario único, formación, investigadores, industrias y llamada al helper energético.
- `godot/scripts/Ciudad.gd`: recursos fluidos, cobro atómico, horas-investigador e instalaciones físicas.
- `godot/scripts/CadenaMinerales.gd`: dos recetas energizadas y tres tipos industriales nuevos.
- `godot/scripts/Colonos.gd`: selección de técnicos/especialistas libres y graduación genérica.
- `godot/scripts/Vias.gd`: copia de columnas XZ para el cálculo puro.
- `godot/scripts/PlantillasPuesto.gd`: cinco plantillas usando bloques existentes.
- `godot/scripts/CamaraCenital.gd`, `BarraModos.gd`, `HUD.gd`, `BarraSuperior.gd`, `PanelPuesto.gd`, `VentanaAlmacen.gd`, `FinalizacionObras.gd`, `HumoRefinerias.gd`: colocación, desbloqueos, presentación y ciclo de vida.
- Pruebas existentes y documentación indicada en Task 7.

---

### Task 1: Generalizar la escuela existente para formar especialistas

**Files:**
- Modify: `godot/scripts/Recoleccion.gd:36-40,173-197`
- Modify: `godot/scripts/Economia.gd:43-53,115-131,533-549`
- Modify: `godot/scripts/Colonos.gd`
- Modify: `godot/scripts/PlantillasPuesto.gd`
- Modify: `godot/scripts/BarraModos.gd:61-87`
- Modify: `godot/scripts/PanelPuesto.gd`
- Test: `godot/scripts/EconomiaTest.gd`, `ColonosTest.gd`, `PlantillasPuestoTest.gd`, `PuestosPrevisualizacionTest.gd`, `HUDTest.gd`

**Interfaces:**
- Consumes: `Ciudad.TIPOS_POBLACION`, rol existente `aprendiz`, señal `cohorte_graduada` y bloques `mesa_estudio`.
- Produces: `Recoleccion.ESCUELAS[tipo] = {origen, destino, horas}` para ambas escuelas.

- [ ] **Step 1: Crear la rama y comprobar el alcance local**

```powershell
git switch -c codex/formacion-investigacion-energia
git status --short
```

Expected: rama nueva; los archivos locales de `arte/`, `.tmp` y `.uid` siguen sin stage.

- [ ] **Step 2: Escribir primero las aserciones de formación**

Agregar casos exactos:

```gdscript
assert(Recoleccion.cupo_de("escuela_especialistas") == 3)
assert(Recoleccion.ESCUELAS["escuela_tecnica"]["horas"] == 24)
assert(Recoleccion.ESCUELAS["escuela_especialistas"]["horas"] == 48)
```

En la prueba integrada: tres técnicos presentes durante 47 horas no gradúan; la hora 48 produce dos especialistas, retira un id y deja `vivienda_ocupada` igual. Despedir uno antes de completar reinicia a 0. Repetir una aserción de regresión 4 obreros→3 técnicos a 24 h.

- [ ] **Step 3: Ejecutar las escenas afectadas y confirmar fallo**

```powershell
& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --quit-after 600 scenes/EconomiaTest.tscn
& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --quit-after 600 scenes/ColonosTest.tscn
```

Expected: FAIL por tipo/duración inexistentes.

- [ ] **Step 4: Hacer declarativa la duración sin crear clases**

```gdscript
const ESCUELAS := {
	"escuela_tecnica": {"origen": "obrero", "destino": "tecnico", "horas": 24},
	"escuela_especialistas": {"origen": "tecnico", "destino": "especialista", "horas": 48},
}
```

En `_formar`, leer `ficha["horas"]`; en contratación y graduación leer origen/destino y cantidades `x_cama`. Ordenar ids y convertir los primeros `x_cama[destino]`; retirar el resto. No añadir otra señal ni otro método de graduación.

- [ ] **Step 5: Añadir edificio y UI reutilizando la escuela técnica**

La nueva plantilla lleva una puerta, tres mesas existentes, sin baúl; zona residencial/investigación y bloqueo `Ciudad.nivel_investigado < 2`. El panel obtiene nombres, cupo y horas de la ficha, sin ramas de texto específicas por escuela.

- [ ] **Step 6: Verificar y commit**

```powershell
tools/run-godot-tests.ps1
git add godot/scripts/Recoleccion.gd godot/scripts/Economia.gd godot/scripts/Colonos.gd godot/scripts/PlantillasPuesto.gd godot/scripts/BarraModos.gd godot/scripts/PanelPuesto.gd godot/scripts/EconomiaTest.gd godot/scripts/ColonosTest.gd godot/scripts/PlantillasPuestoTest.gd godot/scripts/PuestosPrevisualizacionTest.gd godot/scripts/HUDTest.gd
git commit -m "feat: forma especialistas reutilizando las escuelas"
```

---

### Task 2: Conectar universidades físicas con la investigación existente

**Files:**
- Modify: `godot/scripts/Ciudad.gd:65-69,167-172,316-332,467-519`
- Modify: `godot/scripts/Recoleccion.gd`
- Modify: `godot/scripts/Economia.gd`
- Modify: `godot/scripts/Colonos.gd`
- Modify: `godot/scripts/PlantillasPuesto.gd`
- Modify: `godot/scripts/BarraModos.gd`
- Modify: `godot/scripts/PanelPuesto.gd`
- Modify: `godot/scripts/FinalizacionObras.gd`
- Test: `godot/scripts/CiudadTest.gd`, `EconomiaTest.gd`, `ColonosTest.gd`, `HUDTest.gd`

**Interfaces:**
- Produces: `Ciudad.actualizar_investigacion(horas: float) -> bool`, `puede_pagar(costos)`, `consumir_costos(costos)` y registro idempotente de instalaciones.
- Consumes later: `Economia.simular_hora()` agrega investigadores presentes y llama una vez a Ciudad.

- [ ] **Step 1: Escribir pruebas fallidas del pago y progreso**

Cubrir: 0 horas no avanza; dos investigadores aportan 2 h; potencial insuficiente pausa; nivel 2 acepta técnicos; nivel 3 solo especialistas; recursos insuficientes al umbral no cobran parcialmente; al reponerlos completa una vez. Para atomicidad:

```gdscript
var hierro_antes: float = ciudad.almacen["hierro"].cantidad
var madera_antes: float = ciudad.almacen["madera"].cantidad
assert(not ciudad.consumir_costos({"hierro": hierro_antes + 1, "madera": 1}))
assert(ciudad.almacen["hierro"].cantidad == hierro_antes)
assert(ciudad.almacen["madera"].cantidad == madera_antes)
```

- [ ] **Step 2: Sustituir el contador demográfico por horas explícitas**

```gdscript
func actualizar_investigacion(horas: float) -> bool:
	var siguiente := nivel_investigado + 1
	# conservar umbral de potencial y COSTOS_INVESTIGACION
	# acumular hasta el umbral; cobrar todo o nada; devolver true solo al completar
```

Quitar la llamada automática sin argumentos de `Ciudad.simular_tick`. Mantener `COSTOS_INVESTIGACION` y los campos actuales; no crear estado o catálogo duplicado.

- [ ] **Step 3: Añadir universidad como puesto mínimo**

`universidad` tiene cupo 3, capacidad 0, sin depósito y rol `investigador`. `Economia` suma solo presentes: técnicos o especialistas para nivel 2; especialistas para nivel 3. Varias universidades suman en una variable local y llaman una vez a `Ciudad.actualizar_investigacion(total)`.

- [ ] **Step 4: Sincronizar sofisticación con edificios reales**

Guardar `id_edificio -> 2|3` en `Ciudad`; alta idempotente al completar y baja al iniciar demolición. Tipo 2: siderúrgica, tierras raras, aserradero, carbonera. Tipo 3: petróleo, productor, central. No crear un registro separado.

- [ ] **Step 5: Añadir plantilla y panel sin selector**

Universidad disponible desde nivel 1, zona residencial/investigación, tres mesas y sin baúl. El panel muestra automáticamente nombre, costos, progreso y oficio requerido del siguiente nivel. No añadir botones de selección/cancelación porque la ruta es lineal.

- [ ] **Step 6: Verificar y commit**

```powershell
tools/run-godot-tests.ps1
git add godot/scripts/Ciudad.gd godot/scripts/Recoleccion.gd godot/scripts/Economia.gd godot/scripts/Colonos.gd godot/scripts/PlantillasPuesto.gd godot/scripts/BarraModos.gd godot/scripts/PanelPuesto.gd godot/scripts/FinalizacionObras.gd godot/scripts/CiudadTest.gd godot/scripts/EconomiaTest.gd godot/scripts/ColonosTest.gd godot/scripts/HUDTest.gd
git commit -m "feat: investiga niveles desde universidades reales"
```

---

### Task 3: Extender recursos y recetas sin crear otro catálogo

**Files:**
- Modify: `godot/scripts/Ciudad.gd:199-217`
- Modify: `godot/scripts/CadenaMinerales.gd:8-73`
- Modify: `godot/scripts/Recoleccion.gd:173-197`
- Modify: `godot/scripts/Economia.gd:507-682`
- Test: `godot/scripts/CiudadTest.gd`, `EconomiaTest.gd`

**Interfaces:**
- Produces: recursos `agua`, `crudo`, `combustible`; recetas `petroleo` y `combustible_sintetico`; `CadenaMinerales.procesar_receta(..., factor_energia, capacidad)`.
- Preserves: valores y resultados de las cuatro recetas sólidas.

- [ ] **Step 1: Escribir pruebas de recursos y recetas**

```gdscript
assert(ciudad.almacen["agua"].cantidad == 0.0)
assert(ciudad.almacen["crudo"].limite == Ciudad.LIMITE_BASE)
assert(ciudad.almacen["combustible"].cantidad == 0.0)
```

Probar por un trabajador/hora: `2 crudo + 1 E → 1 combustible`; `3 carbón + 1 agua + 1 E → 2 combustible`; factor energético 0 y 0,4; salida casi llena. Confirmar que el diccionario de entrada no se muta y que las recetas sólidas conservan sus tasas.

- [ ] **Step 2: Ejecutar y confirmar fallo**

```powershell
& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --quit-after 600 scenes/CiudadTest.tscn
& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path godot --quit-after 600 scenes/CadenaMineralesTest.tscn
```

- [ ] **Step 3: Ampliar el diccionario actual**

Añadir `energia_por_lote` con valor 0 a recetas existentes y 1 a las dos nuevas. Añadir tipos:

```gdscript
"refineria_petrolera": "petroleo",
"productor_combustible": "combustible_sintetico",
```

Cambiar el helper de proceso existente, no duplicarlo. El límite de lotes es el mínimo de personal×tasa×delta, cada entrada disponible, energía disponible y espacio para salida neta.

- [ ] **Step 4: Reutilizar el acarreo multientrada**

La lógica actual de `entradas_de` e `insumos_a_cargar` ya itera diccionarios: verificarla con carbón+agua y corregir solo el cálculo que falle. Energía nunca aparece en `entradas`, por lo que no requiere excepción de acarreo.

- [ ] **Step 5: Verificar y commit**

```powershell
tools/run-godot-tests.ps1
git add godot/scripts/Ciudad.gd godot/scripts/CadenaMinerales.gd godot/scripts/Recoleccion.gd godot/scripts/Economia.gd godot/scripts/CiudadTest.gd godot/scripts/CadenaMineralesTest.gd godot/scripts/EconomiaTest.gd
git commit -m "feat: añade agua crudo y recetas de combustible"
```

---

### Task 4: Calcular transmisión y déficit con un helper puro

**Files:**
- Create: `godot/scripts/Energia.gd`
- Modify: `godot/scripts/Vias.gd:27-99`
- Modify: `godot/scripts/Economia.gd`
- Test: `godot/scripts/ViasTest.gd`, `EconomiaTest.gd`

**Interfaces:**
- Consumes: `Economia.puestos`, `Zonificacion.dentro_de_influencia(Vector2i)` y `Vias.columnas()`.
- Produces: `Energia.calcular(puestos, zonificacion, vias) -> Dictionary` con `factores`, `resumen` y `quema`.

- [ ] **Step 1: Escribir pruebas de topología en `ViasTest`**

Probar edificio dentro de influencia; fuera sin vía; componente ortogonal conectado; diagonal aislada; edificio a Manhattan 1; rampa con Y diferente; corte y restauración del único tramo.

- [ ] **Step 2: Escribir pruebas de balance en `EconomiaTest`**

Probar demanda 0/capacidad 60 ⇒ quema 0; demanda 15/capacidad 60 ⇒ quema 0,75; demanda 50/capacidad 20 ⇒ factor 0,4 para todos; desconectado ⇒ factor 0; dos centrales reparten quema proporcionalmente; prioridad combustible→crudo→carbón.

- [ ] **Step 3: Ejecutar ambas escenas y confirmar fallo**

- [ ] **Step 4: Exponer solo las columnas necesarias**

```gdscript
func columnas() -> Array[Vector2i]:
	return _columnas.keys()
```

No exponer el diccionario mutable ni agregar señales/cachés.

- [ ] **Step 5: Implementar un cálculo sin estado**

```gdscript
extends RefCounted

static func calcular(puestos: Dictionary, zonificacion: Object, vias: Object) -> Dictionary:
	# devuelve {"factores": {esquina: float}, "resumen": {...}, "quema": {esquina: {recurso: float}}}
```

Hacer un flood-fill XZ por hora desde columnas de vía que toquen influencia. Comentario requerido: `# ponytail: recalcular toda la red es suficiente para 200×200; cachear solo si un perfil muestra costo.` No preparar otros medios de transporte.

- [ ] **Step 6: Integrar al inicio de `Economia.simular_hora`**

Calcular una vez; aplicar `quema` a almacenes de centrales; pasar cada factor a refinerías y universidad. La central obtiene capacidad `min(trabajadores_presentes, combustible_total) × 20` y almacén máximo 300. La energía no se almacena.

- [ ] **Step 7: Verificar y commit**

```powershell
tools/run-godot-tests.ps1
git add godot/scripts/Energia.gd godot/scripts/Vias.gd godot/scripts/Economia.gd godot/scripts/ViasTest.gd godot/scripts/EconomiaTest.gd
git commit -m "feat: calcula transmision y deficit energetico"
```

---

### Task 5: Añadir las tres industrias como puestos existentes

**Files:**
- Modify: `godot/scripts/PlantillasPuesto.gd`
- Modify: `godot/scripts/Recoleccion.gd`
- Modify: `godot/scripts/Economia.gd`
- Modify: `godot/scripts/Colonos.gd`
- Modify: `godot/scripts/CamaraCenital.gd`
- Modify: `godot/scripts/BarraModos.gd`
- Modify: `godot/scripts/HumoRefinerias.gd`
- Modify: `godot/scripts/FinalizacionObras.gd`
- Test: `godot/scripts/PlantillasPuestoTest.gd`, `EconomiaTest.gd`, `ColonosTest.gd`, `PuestosPrevisualizacionTest.gd`

**Interfaces:**
- Consumes: recetas de Task 3 y `Energia.calcular` de Task 4.
- Produces: edificios jugables `refineria_petrolera`, `productor_combustible`, `central_termoelectrica`.

- [ ] **Step 1: Escribir aserciones integradas antes de plantillas**

Verificar cupos 4/4/3, capacidades 1000/1000/300, técnicos y especialistas admitidos, desempleados rechazados, acarreo de entradas/salida, desbloqueo en nivel 2 y baja/alta idempotente de sofisticación.

- [ ] **Step 2: Añadir plantillas con bloques ya existentes**

Cada industria tiene entrada, salida, baúl y chimenea. Ajustar la cantidad de bloques para que `NiveladorTerreno.resumen_costos` iguale exactamente la fila de la spec; añadir esa comparación a `PlantillasPuestoTest`. No crear bloques funcionales nuevos.

- [ ] **Step 3: Extender las ramas genéricas actuales**

Refinería y productor entran en `CadenaMinerales.REFINERIAS`, por lo que deben recorrer el flujo existente. La central usa el mismo registro/almacén/acarreadores, pero no `_refinar`; `Energia.calcular` lee sus presentes e insumos.

- [ ] **Step 4: Añadir colocación mínima**

Tres botones en Industrial, miniaturas, zona industrial, influencia y mensaje `Requiere Metalurgia Aplicada`. Reutilizar humo; solo variar color/material mediante los diccionarios existentes.

- [ ] **Step 5: Verificar y commit**

```powershell
tools/run-godot-tests.ps1
git add godot/scripts/PlantillasPuesto.gd godot/scripts/Recoleccion.gd godot/scripts/Economia.gd godot/scripts/Colonos.gd godot/scripts/CamaraCenital.gd godot/scripts/BarraModos.gd godot/scripts/HumoRefinerias.gd godot/scripts/FinalizacionObras.gd godot/scripts/PlantillasPuestoTest.gd godot/scripts/EconomiaTest.gd godot/scripts/ColonosTest.gd godot/scripts/PuestosPrevisualizacionTest.gd
git commit -m "feat: construye industrias de combustible y energia"
```

---

### Task 6: Mostrar investigación y energía sin lógica de UI paralela

**Files:**
- Modify: `godot/scripts/BarraSuperior.gd`
- Modify: `godot/scripts/HUD.gd`
- Modify: `godot/scripts/PanelPuesto.gd`
- Modify: `godot/scripts/VentanaAlmacen.gd`
- Test: `godot/scripts/HUDTest.gd`

**Interfaces:**
- Consumes: `Economia.balance_energia`, `Economia.factor_energia_de(esquina)`, estado de investigación de `Ciudad` y fichas existentes.
- Produces: solo presentación; no muta energía ni investigación.

- [ ] **Step 1: Escribir aserciones de texto/estado**

Cubrir nombres Agua/Crudo/Combustible; barra `Energía: 30/50 E/h`; color rojo con factor <1; `Sin conexión`, `Sin generación`, `Déficit 60 %`, `Con energía`, `Sin demanda`; panel de central con capacidad/uso/combustible; universidad con siguiente investigación/progreso/costos.

- [ ] **Step 2: Exponer dos lecturas simples desde Economía**

```gdscript
var balance_energia: Dictionary = {"demanda": 0.0, "capacidad": 0.0, "entregada": 0.0}

func factor_energia_de(esquina: Vector2i) -> float:
	return _factores_energia.get(esquina, 0.0)
```

No exponer `Energia.gd` al HUD ni recalcular nada desde controles.

- [ ] **Step 3: Reutilizar componentes visuales**

Agregar una etiqueta a `BarraSuperior` y líneas condicionales a `PanelPuesto`; no crear ventana energética ni panel universitario separado. `VentanaAlmacen` obtiene automáticamente los tres recursos del diccionario; solo agregar nombres si los necesita.

- [ ] **Step 4: Verificar y commit**

```powershell
tools/run-godot-tests.ps1
git add godot/scripts/BarraSuperior.gd godot/scripts/HUD.gd godot/scripts/PanelPuesto.gd godot/scripts/VentanaAlmacen.gd godot/scripts/HUDTest.gd godot/scripts/Economia.gd
git commit -m "feat: muestra investigacion y balance energetico"
```

---

### Task 7: Sincronizar documentación y cerrar con verificación completa

**Files:**
- Modify: `Documento de Diseño de Juego (GDD)_ Craft to Nation.md`
- Modify: `README.md`
- Modify: `docs/Pendientes y próximos pasos.md`
- Modify: `docs/Fichas_Consumo_Produccion.md`
- Modify: `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Catálogo de Recursos y Cadenas de Producción.md`
- Modify: `docs/ideas-backlog.md`
- Review: todos los archivos versionados desde `main`.

**Interfaces:**
- Documents: exactamente el comportamiento entregado; bombas siguen pendientes.

- [ ] **Step 1: Actualizar fichas y estado**

Marcar implementados escuela, universidad, refinería, productor, central y energía. Registrar cifras de la spec y la simplificación Ponytail: investigación lineal automática y red recalculada por hora. Dejar explícitos bombas de agua/crudo, consumo universal de Era 3, vías por colonos, tope/prioridades de obra y balance jugando.

- [ ] **Step 2: Buscar contradicciones**

```powershell
rg -n "por definir|sin diseñar|no implementada" docs/Fichas_Consumo_Produccion.md docs/ideas-backlog.md 'Documento de Diseño de Juego (GDD)_ Craft to Nation.md' README.md
rg -n "refineria_petrolera|productor_combustible|central_termoelectrica|escuela_especialistas|universidad" godot/scripts docs 'Documento de Diseño de Juego (GDD)_ Craft to Nation.md'
```

Expected: ningún estado pendiente permanece para estos seis sistemas; bombas y alcance futuro sí permanecen.

- [ ] **Step 3: Ejecutar verificación automática**

```powershell
tools/run-godot-tests.ps1
git diff --check
git status --short
```

Expected: `Las 26 escenas de prueba pasaron sin errores.`; ningún archivo local ajeno está staged.

- [ ] **Step 4: Hacer una pasada manual mínima**

En `Main.tscn`: completar Metalurgia con universidad, formar especialistas, producir combustible con ambas recetas, observar déficit al reducir generación y confirmar que demanda cero no quema combustible. La conexión exterior por vía queda cubierta automáticamente; no construir una bomba provisional solo para demostrarla.

- [ ] **Step 5: Commit documental**

```powershell
git add 'Documento de Diseño de Juego (GDD)_ Craft to Nation.md' README.md 'docs/Pendientes y próximos pasos.md' docs/Fichas_Consumo_Produccion.md 'PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Catálogo de Recursos y Cadenas de Producción.md' docs/ideas-backlog.md
git commit -m "docs: cierra formacion investigacion y energia de fase 3"
```

- [ ] **Step 6: Revisar el rango y corregir solo defectos demostrados**

```powershell
git diff --stat main...HEAD
git diff --check main...HEAD
git log --oneline main..HEAD
tools/run-godot-tests.ps1
```

No refactorizar por estética al final. Si hay una corrección, stagear solo sus rutas explícitas y crear `fix: corrige integracion de investigacion y energia`.

## Self-review

- Cobertura: Task 1 escuela; Task 2 universidad/investigación; Task 3 recursos/recetas; Tasks 4–5 central/transmisión/déficit/edificios; Task 6 UI; Task 7 documentación y aceptación.
- Archivos nuevos: uno (`Energia.gd`) frente a nueve del plan anterior; escenas nuevas: cero; autoloads nuevos: cero.
- Tipos consistentes: puestos se identifican por `Vector2i esquina`, igual que `Economia`; instalaciones físicas usan `id_edificio`, igual que `FinalizacionObras`.
- La ruta lineal de investigación y el flood-fill horario tienen techo conocido y comentario `ponytail:`; se amplían solo cuando exista más de una investigación elegible o un perfil demuestre costo.
- Ninguna abstracción existe para un único consumidor y ningún sistema futuro condiciona la entrega actual.

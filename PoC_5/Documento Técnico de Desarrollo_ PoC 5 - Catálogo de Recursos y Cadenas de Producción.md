# **Documento Técnico de Desarrollo: PoC 5 - Catálogo de Recursos y Cadenas de Producción**

**Identificador del Módulo:** POC-05-CADENA-MINERALES

**Motor:** Godot Engine 4.7 (GDScript), sobre el proyecto compartido `godot/` (ver convención de carpetas en el GDD, Sección 11).

**Dependencias de Diseño:** GDD Sección 4 ("Catálogo de Recursos y Cadenas de Producción", primer bullet sobre minas), Sección 11 (Fase 3, entrada de PoC 5).

**Dependencia Técnica:** Reutiliza `Recoleccion.TIPOS_MINERALES` (autoload de PoC 6) como catálogo de minerales crudos — no lo redefine.

Spec de este sub-proyecto: `docs/superpowers/specs/2026-09-14-cadena-minerales-design.md`.

Esta PoC cubre, por ahora, el **primer sub-proyecto de 4** de la Fase 3 del roadmap (GDD Sección 11): la cadena de **minerales**. Madera (aserradero/carbonera), fluidos (agua/crudo/combustible) y energía quedan fuera de alcance — ver "Próximos Pasos".

---

## **FASE 1: IDEACIÓN**

### **1.1 Alcance y Objetivos de esta Pieza**

* **Solo minerales por ahora:** de los 4 grupos de la Sección 4 del GDD (minerales, madera, fluidos, energía), este sub-proyecto cubre únicamente el primero — los demás se abordarán en sub-proyectos separados de esta misma PoC 5.
* **Dos recetas placeholder:** `2 hierro → 1 acero` (refinería de hierro) y `3 tierras_raras → 1 mineral_refinado` (refinería de tierras raras) — números redondos simples, sin balance real todavía, mismo espíritu que el aserradero ya documentado en el GDD (`1 madera → 3 tablas`, sub-proyecto de madera, todavía no implementado). `tierra`, `piedra` y `cobre` se mantienen como recursos directos, sin receta — igual que ya lo describe el GDD. `carbon` ya forma parte del catálogo de minerales (`Recoleccion.TIPOS_MINERALES` desde PoC 6), pero este sub-proyecto no le agrega ninguna receta: sus consumidores (carbonera, productor de combustible) son sub-proyectos futuros.
* **Solo lógica pura + escena de demostración, sin refinerías colocables todavía:** mismo patrón que `Ciudad.gd`/`Zonificacion.gd`/`Recoleccion.gd` — un autoload nuevo con las recetas y el cálculo de balance, verificado con una escena de pruebas automatizadas y una escena de demostración interactiva simple para "jugar" con los números de balance en vivo. Construir refinerías reales como puestos periféricos colocables en el mundo es un sub-proyecto/PoC posterior.
* **Corrección de una contradicción real del GDD:** la Sección 4 afirmaba, en el mismo párrafo, que "el carbón alimenta la carbonera" (carbón como insumo) y, en el bullet siguiente, que "la carbonera diversifica madera en carbón" (carbón como producto, insumo = madera) — dos afirmaciones incompatibles sobre el mismo edificio. El usuario confirmó que la segunda es la correcta: la carbonera consume madera y produce carbón; la primera frase era un error de redacción del GDD. Corregido como parte de esta pieza (ver "Decisiones").

### **1.2 Fuera de Alcance**

* **Madera (aserradero/carbonera), fluidos (agua/crudo/combustible) y energía:** los otros 3 grupos de la Sección 4 del GDD — sub-proyectos futuros de esta misma PoC 5, cada uno con su propio spec.
* **Refinerías reales colocables en el mundo** (huella, validación de colocación, bloque marcador en la `MeshLibrary`, radio de acción, ficha de HUD) — sub-proyecto/PoC posterior, una vez que el balance de recetas esté probado aquí.
* **Integración con el almacén real de `Ciudad.gd`/inventario del jugador:** la escena de demostración usa un almacén simulado propio, aislado — no toca ningún estado real del juego.
* **`PERSONAL_MAXIMO_*` como límite aplicado:** son valores de referencia, igual que `Recoleccion.PERSONAL_MAXIMO` en los puestos periféricos — ningún código de este sub-proyecto rechaza ni recorta el número de trabajadores contra ese límite.
* **Costo de construcción, producción real por tick en el juego real, niveles 2/3 de refinería:** mismo alcance reducido que el resto del proyecto.
* **Recetas alternativas o múltiples por edificio:** ya resuelto por el propio diseño — `RECETAS` se indexa 1:1 por tipo de entrada, consistente con "ningún edificio soporta más de una receta" (GDD Sección 4).

---

## **FASE 2: PLANEACIÓN**

### **2.1 Arquitectura**

```
godot/
  scenes/
    CadenaMineralesTest.tscn    # Nueva escena de pruebas (sin gameplay)
    CadenaMineralesDemo.tscn    # Nueva escena de demostración interactiva (standalone)
  scripts/
    CadenaMinerales.gd          # Nuevo: autoload de recetas y balance, sin nodos de escena
    CadenaMineralesTest.gd      # Nuevo: 8 pruebas aisladas
    CadenaMineralesDemo.gd      # Nuevo: demo controlada por teclado, almacén/trabajadores locales
  project.godot                 # + autoload "CadenaMinerales"
```

### **2.2 Decisión: Lógica Pura, Reutilizando el Catálogo Existente**

`CadenaMinerales.gd` sigue el mismo patrón ya establecido por `Recoleccion.gd`/`Zonificacion.gd`/`Ciudad.gd`: un autoload `extends Node`, sin `class_name` (evita el bug de caché de clases globales de Godot ya documentado en `Recoleccion.gd`), estado y lógica pura, sin dependencia de ningún nodo de escena. En vez de redefinir la lista de minerales crudos, reutiliza `Recoleccion.TIPOS_MINERALES` (tierra, piedra, hierro, cobre, carbon, tierras_raras) — el catálogo de la Sección 4 del GDD ya vive en un solo lugar.

---

## **FASE 3: DESARROLLO**

### **3.1 `CadenaMinerales.gd`**

El archivo completo vive en `godot/scripts/CadenaMinerales.gd` (70 líneas). La receta se indexa por tipo de entrada, no por nombre de edificio — consistente con que cada refinería tiene una única receta fija:

```gdscript
const RECETAS: Dictionary = {
	"hierro": {"tipo_salida": "acero", "cantidad_entrada": 2, "cantidad_salida": 1, "tasa_base": 2.0},
	"tierras_raras": {"tipo_salida": "mineral_refinado", "cantidad_entrada": 3, "cantidad_salida": 1, "tasa_base": 2.0},
}
```

`procesar_tick(delta, almacen, trabajadores) -> Dictionary` recorre `RECETAS`; por cada tipo con al menos 1 trabajador asignado, calcula la demanda teórica (`cantidad_entrada * num_trabajadores * tasa_base * delta`), la recorta al mínimo entre esa demanda y lo disponible en `almacen`, y produce la proporción exacta correspondiente al consumo real (no a la demanda teórica). Nunca muta el `Dictionary` recibido — trabaja sobre `almacen.duplicate()` y devuelve el resultado, pensado tanto para pruebas deterministas con un diccionario de usar y tirar como para una futura integración con el almacén real de `Ciudad`/`Recoleccion` sin riesgo de corromperlo a mitad de cálculo. Cualquier tipo sin receta (p. ej. `cobre`) se copia sin cambios.

`tasas_refinado(trabajadores) -> Dictionary` calcula el consumo/producción por hora de cada receta activa, mismo patrón informativo que `Recoleccion.tasas_recoleccion()`/`tasas_caza_recoleccion()`: una receta sin trabajadores asignados **no aparece** como clave en el resultado (en vez de aparecer con valores en `0.0`), para que un futuro consumidor tipo HUD pueda usar `tasas.has(tipo)` para decidir si mostrar la ficha de esa refinería.

Además del catálogo de recetas, el archivo define constantes placeholder `COSTO_CONSTRUCCION_*`/`PERSONAL_MAXIMO_*` (informativo, no aplicado)/`CAPACIDAD_ALMACENAMIENTO_*` para ambas refinerías, mismo formato que `Recoleccion.COSTO_CONSTRUCCION` en los puestos periféricos existentes.

Registrado como autoload en `godot/project.godot`, en el mismo bloque `[autoload]` donde ya están `Ciudad`/`Zonificacion`/`Recoleccion`/`Construccion`.

### **3.2 Pruebas — `CadenaMineralesTest.gd`**

8 pruebas en `godot/scripts/CadenaMineralesTest.gd` (mismo patrón que `RecoleccionTest.gd`/`NiveladorTerrenoTest.gd`: escena `Node` raíz, `_ready()` llama `ejecutar_pruebas()`, cada caso termina en `assert()`): ambas recetas procesadas a la vez sin interferir entre sí; sin trabajadores el almacén no cambia; insumo insuficiente consume solo lo disponible y produce la proporción real (no la demanda teórica); `procesar_tick()` no muta el `Dictionary` recibido; un mineral sin receta (cobre) pasa sin cambios; `tasas_refinado()` calcula consumo/producción exactos por hora; una receta sin trabajadores queda ausente del resultado de `tasas_refinado()` (no en `0.0`); y determinismo — mismos argumentos, mismo resultado, en ambas funciones.

### **3.3 Escena de Demostración — `CadenaMineralesDemo.gd`/`.tscn`**

Escena standalone, no integrada con `Main.tscn` ni con el estado real del juego — mantiene su propio `almacen`/`trabajadores` locales, caja de arena aislada para probar los números de `RECETAS`. Controlada por teclado, mismo patrón que los modos de `CamaraCenital.gd`: teclas `1`-`6` agregan 10 unidades del mineral correspondiente (mismo orden que `Recoleccion.TIPOS_MINERALES`; agregar carbón demuestra visualmente que se acumula sin ninguna receta que lo consuma todavía); `Q`/`W` y `A`/`S` ajustan trabajadores de la refinería de hierro y de tierras raras respectivamente (mínimo 0); `Espacio` avanza un tick de `1.0` hora vía `CadenaMinerales.procesar_tick()`; un `Label` muestra en todo momento las cantidades del almacén (solo tipos con cantidad > 0) y las tasas activas de `tasas_refinado()`.

---

## **Verificado**

**Vía MCP headless (Godot 4.7.2.stable.steam):**

* `CadenaMineralesTest.tscn`: las 8 pruebas descritas en 3.2 pasan sin errores de `assert()`, terminando en `"=== Las 8 pruebas de CadenaMinerales pasaron correctamente ==="`.
* `Main.tscn`: carga sin errores nuevos con el autoload `CadenaMinerales` inicializado (solo las 6 advertencias preexistentes de `invalid UID`, sin relación con esta pieza).
* `CadenaMineralesDemo.tscn`: corre y `_ready()` se ejecuta limpiamente (sin errores de parseo ni excepciones en tiempo de ejecución) — `_actualizar_texto()` completa y muestra el estado inicial de la demo. La interacción por teclado en sí (agregar minerales, asignar trabajadores, avanzar ticks) no es verificable en modo headless — ver "Verificación manual final" más abajo.

**Pendiente de confirmación jugando en el editor real:** que los controles de teclado de `CadenaMineralesDemo.tscn` (`1`-`6`, `Q`/`W`, `A`/`S`, `Espacio`) reflejen en pantalla los números esperados de consumo/producción por hora y la evolución del almacén tick a tick — no es necesario para confirmar la aritmética en sí, ya cubierta por las 8 pruebas automatizadas.

---

## **Próximos Pasos**

* **Madera** (aserradero/carbonera) — sub-proyecto futuro de esta misma PoC 5; incluye implementar la carbonera real (madera → carbón) que motivó la corrección del GDD en esta pieza.
* **Fluidos** (agua/crudo/combustible: bombas de extracción, refinería de crudo, productor de combustible) — sub-proyecto futuro de esta misma PoC 5.
* **Energía** (generadores, transmisión sin red dedicada) — sub-proyecto futuro de esta misma PoC 5.
* **Refinerías reales colocables en el mundo** (huella, validación de colocación, bloque marcador en la `MeshLibrary`, radio de acción, ficha de HUD) — PoC/sub-proyecto posterior, una vez probado el balance de recetas con la escena de demostración de esta pieza.
* **Integración con el almacén real de `Ciudad`/`Recoleccion`** — hoy `procesar_tick()` opera sobre un `Dictionary` de usar y tirar; conectarlo al inventario real del jugador queda para cuando existan refinerías colocables.

# **Documento Técnico de Desarrollo: PoC 5 - Fase 2A - Puestos, Producción y Acarreo**

**Identificador del Módulo:** POC-05-ECONOMIA-2A

**Motor:** Godot Engine 4.7 (GDScript), sobre el proyecto compartido `godot/` (ver convención de carpetas en el GDD, Sección 11).

**Dependencias de Diseño:** GDD Sección 3 ("Área de Acción de los Puestos de Recolección" y su bullet "Producción y Acarreo"), Sección 4 ("Catálogo de Recursos y Cadenas de Producción"), Sección 6 (comida y población), Sección 11 (Fase 3).

**Dependencias Técnicas:** autoloads `Ciudad` (stock central, demografía, ticks), `Recoleccion` (puestos, tasas, cupos y capacidades), `Zonificacion` (huella del núcleo urbano) y `Colonos` (movimiento a pie con `BuscadorRutas`). Datos de balance en `docs/Recursos.xlsx` (hojas `Puestos`, `Economia` y `Niveles`) y `docs/Fichas_Consumo_Produccion.md`.

Spec de esta fase: `docs/superpowers/specs/2026-09-21-economia-puestos-produccion-acarreo-design.md`. Plan: `docs/superpowers/plans/2026-09-21-economia-puestos-produccion-acarreo.md`.

Esta fase es la rebanada **2A** del sub-proyecto 2 ("núcleo de economía") de la lógica de recursos. No modifica el documento del catálogo de recursos (`PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Catálogo de Recursos y Cadenas de Producción.md`), que sigue siendo el de la cadena de minerales.

---

## **FASE 1: IDEACIÓN**

### **1.1 Objetivo**

Convertir los cuatro puestos de recolección existentes (mina, caza/recolección, maderero, pesca/frutos del mar), que hasta ahora solo eran marcadores colocables, en fuentes reales de recursos: el jugador asigna colonos a un puesto desde un panel, los recolectores producen en el almacén local del puesto, los acarreadores caminan cargando hasta el núcleo urbano y el stock central de la ciudad crece. Incluye la comida, así que por primera vez la ciudad puede sostenerse sola.

Decisiones confirmadas con el usuario (2026-09-21): asignación manual desde la cenital; los colonos se mueven físicamente (los recolectores producen solo mientras están presentes en el puesto); un puesto nuevo empieza con 0 trabajadores; cupos por puesto maderero 5, caza/recolección 7, pesca 7 y mina 5; el núcleo urbano es el único almacén central.

### **1.2 Fuera de Alcance / Siguiente**

- **2B — extracción física y agotamiento:** los colonos retiran bloques reales (minas, canteras) y talan árboles; la comida se recalcula según el entorno; el bosque puede agotarse. Hoy las tasas se fijan al colocar el puesto y no se recalculan.
- **2C — transformación:** aserradero, carbonera, siderúrgica y refinería de tierras raras (recetas de `CadenaMinerales`), luego fluidos y energía.
- Moral y nivel del puesto (subirán la eficiencia con el mismo personal) y drones o unidades de transporte de la automatización futura.
- Carretas y carreteras (sub-proyecto 6), almacenes dedicados, costo de construcción de los puestos y obreros NPC que construyen (sub-proyecto 3), agua, petróleo, combustible y energía.
- Representación visual de la carga que lleva un acarreador (se añade cuando el arte lo pida).

---

## **FASE 2: PLANEACIÓN**

### **2.1 Arquitectura**

- **`Economia.gd` (autoload nuevo, lógica pura, mismo patrón que `Ciudad`/`Zonificacion`/`Recoleccion`).** Estado por puesto indexado por la esquina de su huella: tipo, huella, cupo, capacidad del almacén local, tasas, recolectores, acarreadores, recolectores presentes y almacén local. Escucha `Ciudad.tick_simulado` (1 tick = 1 hora de juego) y produce. API: `registrar_puesto(esquina, tipo, ancho, alto, tasas)`, `quitar_puesto`, `asignar`, `liberar`, `ultimo_de`, `marcar_presente`, `trabajadores_de`, `produccion_por_hora`, `almacen_local`, `cupo_libre`, `huella_de`, `recoger`, `entregar` y la señal `puesto_quitado`. `ciudad` es inyectable para probar sin escena.
- **`Colonos.gd`.** Cada colono gana `trabajo` (`{puesto, rol}`), `carga` y `fase`. `contratar(esquina, rol)` toma al desempleado de id menor, lo pasa a `obrero` (`Ciudad.reasignar_tipo`) y lo asigna en `Economia`; `despedir` libera al último contratado con ese rol. Un colono con trabajo deja de deambular; la evacuación de obras conserva su prioridad. El recolector camina a una celda transitable junto a la huella del puesto y avisa `Economia.marcar_presente`. El acarreador cicla puesto (`recoger`) → núcleo (`entregar`) → puesto; sin carga disponible espera 1 s y reintenta. Al retirarse un colono trabajador (hambruna, desahucio) se libera antes de borrarlo, y `Economia.puesto_quitado` devuelve a `desempleado` a los trabajadores de un puesto deconstruido.
- **`PanelPuesto.gd` (nodo nuevo en `HUDLayer`).** Título del puesto, `Recolectores [-] n [+]`, `Acarreadores [-] n [+]` (el total no pasa del cupo; `[+]` se desactiva sin desempleados libres), desempleados libres, almacén local, producción por hora y distancia al núcleo. Solo muestra y reenvía clics a `Colonos`.
- **`Ciudad.gd`.** `almacen` pasa de 3 a 8 recursos (los cinco nuevos empiezan en 0); `reasignar_tipo(de, a)` mueve un habitante entre tipos sin desajustar `demografia`; `Recurso.tasa_neta` se mide entre cierres de tick consecutivos para incluir lo que entregan los acarreadores entre ticks.
- **`Recoleccion.gd`.** `TASAS_BASE_MINERAL` y las constantes `TASA_BASE_*_POR_CIUDADANO` con las tasas del Excel; cupos `PERSONAL_MAXIMO*` 5/7/7/5; `cupo_de`, `capacidad_almacen_de`, `esquina_de_puesto_en(celda)` y `SIN_PUESTO`, `TIPOS_PUESTO_TRABAJO`.
- **`Zonificacion.gd`.** `huella_del_nucleo()` (celdas del núcleo urbano) para calcular dónde entrega el acarreador y la distancia del panel.
- **`CamaraCenital.gd`.** Al colocar un puesto llama a `Economia.registrar_puesto` con las tasas de su ficha; un clic izquierdo sin un rectángulo de zona a medias sobre la huella de un puesto abre el panel, y cualquier otro clic lo cierra y funciona como siempre. `Player.gd` llama a `Economia.quitar_puesto` al deconstruir por completo un puesto.
- **`HUD.gd`.** La lista permanente de control de recursos muestra los 8 recursos (cantidad, límite y tasa por tick) y reemplaza las dos líneas separadas de comida y "recurso crítico"; aloja el panel del puesto.

### **2.2 Constantes y placeholders**

| Constante | Valor | Origen |
|---|---|---|
| Cupo maderero / caza-recolección / pesca / mina | 5 / 7 / 7 / 5 | Decisión del usuario; `Recoleccion.PERSONAL_MAXIMO*` |
| Almacén local por puesto | 1000 (total entre recursos) | Placeholder; `Recoleccion.CAPACIDAD_ALMACENAMIENTO*` |
| `Economia.CAPACIDAD_CARGA` | 150 unidades por viaje | Placeholder (perilla principal); balance de comida del 2026-09-21 |
| Tasa mineral por trabajador y hora | tierra 1; piedra, hierro, cobre, carbón y tierras raras 5 | Excel, `Recoleccion.TASAS_BASE_MINERAL` |
| Madera | 5 | Excel, `TASA_BASE_MADERERO_POR_CIUDADANO` |
| Caza | 14 | Decisión del usuario, 2026-09-21 (el primer balance del día dejó 10; reemplaza el venado 15 del Excel, que sigue en la hoja `Relacion`); `TASA_BASE_CAZA_POR_CIUDADANO` |
| Frutos | 8 | Partía de la columna "Árbol (obj)" del Excel (Comida 5, interpretada como frutos); cambiado a 8 por decisión del usuario, 2026-09-21; `TASA_BASE_FRUTOS_POR_CIUDADANO` |
| Pesca | 12 | Balance del 2026-09-21; `TASA_BASE_PESCA_POR_CIUDADANO` |
| Algas | 3 | Balance del 2026-09-21; `TASA_BASE_ALGAS_POR_CIUDADANO` (la densidad de algas depende de la profundidad, así que el promedio de 0,5 es aproximado) |
| Stock central: límite | 1000 por recurso; comida 10000 | Placeholder; `Ciudad.almacen` |
| Stock inicial | comida 10000, madera 200, hierro 50, resto 0 | `Ciudad.almacen` |
| Duración de un tick | 2 s reales = 1 hora de juego | `Ciudad.SEGUNDOS_POR_TICK` |
| Velocidad de un colono | 2,5 celdas/s (5 por hora de juego) | `Colonos.VELOCIDAD_COLONO` |
| Consumo de un obrero | 5 comida/h (un desempleado consume 3) | `Ciudad.TIPOS_POBLACION` |

La tasa de un recurso es la tasa base del Excel multiplicada por su fracción (mineral) o densidad (madera, fauna, frutal, peces, algas) en el área de acción, por trabajador presente y hora. Un recolector de caza/recolección o de pesca produce ambas señales a la vez y se suman en `comida` (`Economia.RECURSO_DE_TASA`).

---

## **FASE 3: DESARROLLO**

### **3.1 Reglas**

- **Producción.** Solo produce un recolector presente en el puesto. Cada tick suma `tasa × 1 h` al almacén local; si el total local superara la capacidad (1000), entra solo lo que cabe, en proporción entre recursos, y el exceso se pierde: un almacén lleno es la señal al jugador de que falta acarreo.
- **`recoger(esquina, capacidad)`.** Devuelve y descuenta del almacén local hasta `capacidad` unidades, repartidas en el orden de los recursos del almacén, solo si el total local ya alcanza la capacidad (carga completa) o si el puesto no tiene recolectores presentes y aún queda algo. En otro caso devuelve `{}`: ningún resto queda atascado y no se hacen viajes de una sola unidad mientras se sigue produciendo.
- **`entregar(carga)`.** Suma cada recurso al stock central (`Ciudad.almacen[r].agregar`); lo que no cabe por stock lleno se pierde.
- **Deconstruir un puesto.** El almacén local se pierde y sus trabajadores vuelven a `desempleado`; el panel se cierra si estaba abierto sobre ese puesto.
- **Contratar.** Falla si no hay desempleado libre, si el puesto no existe o si el cupo está lleno.

### **3.2 Balance esperado**

Un tick son 2 s reales y un colono camina 2,5 celdas/s, es decir 5 celdas por hora de juego. Meta de diseño (2026-09-21): cada recolector de comida debe aportar al menos 7,5 unidades/h: 5 para sí mismo (consume 5/h como obrero) + 2,5 que sostienen a medio acarreador. Con un puesto a unas 20 celdas del núcleo el viaje redondo dura unas 9 h, así que con carga 150 un acarreador mueve unas 16 unidades/h, es decir 1 acarreador por cada 2 recolectores. Tres obreros (2 recolectores + 1 acarreador) se sostienen solos; con el 4.º recolector sobran 2,5/h para el avatar (5/h a nivel 1). Un puesto más lejano rinde menos, porque el acarreador tarda más en cada viaje (a 40 celdas, 16 h de viaje redondo, mueve unas 9 unidades/h); ese coste da el incentivo para las carreteras y carretas futuras. Medido en el mundo real (semilla 12345, rejilla de 540 centros de tierra y 52 de agua): la densidad media de fauna es 0,45 y la de frutal 0,46. Con caza 10 y frutos 5, caza + frutos daba 6,83/h por recolector (p10 5,34, p90 7,95) frente a 8,56/h de la pesca (p10 8,07, p90 9,07), es decir, no cumplía la meta y cazar salía peor que pescar; por eso el usuario subió caza a 14 y frutos 8 (2026-09-21), lo que da ~10,0/h (14 × 0,45 + 8 × 0,46), con margen sobre la meta y por encima de la pesca (~8,6/h). Con menos densidad (poca fauna, algas escasas por profundidad) o un puesto más lejano puede no cumplirse. Pendiente: verificar jugando que 2 recolectores + 1 acarreador se sostienen. La perilla es `CAPACIDAD_CARGA`; los cupos son la otra.

### **3.3 Pruebas**

`EconomiaTest` (nueva, con una `Ciudad` falsa): registrar y quitar puesto, producción solo con recolectores presentes, tope y pérdida del exceso, cupo por tipo, `liberar` y `quitar_puesto`, `recoger` (carga completa, sin recolectores presentes, almacén vacío, sin descontar de más), `entregar` con stock casi lleno, caza más frutos sumados en comida. Ampliadas: `RecoleccionTest` (tasas del Excel, `esquina_de_puesto_en`), `CiudadTest` (8 recursos, `reasignar_tipo`, `tasa_neta` entre cierres), `ZonificacionTest` (`huella_del_nucleo`) y `ColonosTest` (contratar/despedir, recolector presente, ciclo del acarreador, retirar un trabajador, evacuación de obras con prioridad sobre el trabajo). Ejecución obligatoria (CLAUDE.md): `godot/scenes/Test.tscn` más las escenas afectadas.

### **3.4 Verificación manual pendiente (en el editor con Godot 4.7)**

1. Colocar cada uno de los 4 puestos (M, H, L, F) y hacer clic sobre él en la cenital abre el panel; un clic sobre otro sitio lo cierra y no rompe el pintado de zonas.
2. Con desempleados libres, `+` en Recolectores y Acarreadores los pone a caminar al puesto y a producir.
3. El almacén local sube, el acarreador lleva la carga al núcleo y el stock central sube en la lista del HUD.
4. El stock de comida sostiene a la población con un puesto de caza/recolección o pesca atendido.
5. `-` despide y el cupo se libera.
6. Deconstruir un puesto por completo devuelve a sus trabajadores a desempleados y cierra el panel.

### **3.5 Supuestos que el usuario puede corregir**

- Tasa de frutos: partía de la columna `Árbol (obj)` del Excel (Comida 5), interpretada como frutos; el usuario la cambió a 8/h (2026-09-21) junto con la caza a 14/h.
- Capacidad de carga de 150 unidades por viaje.
- Un recolector de caza/recolección o de pesca produce las dos señales a la vez, sumadas en comida.
- La producción usa las tasas tomadas al colocar el puesto (no se recalculan mientras no haya agotamiento; eso es la 2B).

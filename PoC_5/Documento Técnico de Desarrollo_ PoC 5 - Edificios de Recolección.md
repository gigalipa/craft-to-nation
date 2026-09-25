# **Documento Técnico de Desarrollo: PoC 5 - Edificios de Recolección (plantillas)**

**Identificador del Módulo:** POC-05-ECONOMIA-EDIFICIOS

**Motor:** Godot Engine 4.7 (GDScript), sobre el proyecto compartido `godot/` (ver convención de carpetas en el GDD, Sección 11).

**Dependencias de Diseño:** GDD Sección 3 ("Área de Acción de los Puestos de Recolección" y su bullet "Producción y Acarreo") y Sección 5 (edificios de bloques, puertas y baúles).

**Dependencias Técnicas:** autoloads `Economia` (puestos, trabajadores, almacén local), `Recoleccion` (huellas y registro de puestos) y `Colonos` (movimiento a pie); `VoxelWorld` (edificios completos, deconstrucción por bloques) y `CamaraCenital` (colocación). Fases previas: 2A (`PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Fase 2A - Puestos, Producción y Acarreo.md`) y 2B (`PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Fase 2B - Extracción Física y Agotamiento.md`).

Spec de esta fase: `docs/superpowers/specs/2026-09-24-edificios-recoleccion-plantillas-design.md`. Plan: `docs/superpowers/plans/2026-09-24-edificios-recoleccion-plantillas.md`.

---

## **FASE 1: IDEACIÓN**

### **1.1 Objetivo**

Que un puesto de recolección deje de ser un slab de bloques marcador y pase a ser un **edificio de bloques con forma propia, puerta de servicio y depósito físico**, que se desactiva al empezar a deconstruirse (igual que un residencial) y que despide a sus recolectores cuando se agota.

Decisiones confirmadas con el usuario (2026-09-24):
- Plantillas **prediseñadas**, una por tipo de puesto, colocadas al instante y sin costo (la construcción con costo y obreros NPC es el punto 6 del roadmap).
- Elementos funcionales: forma propia por tipo, puerta de servicio, depósito físico y deconstruible por bloques.
- El arte lo hará el usuario en SketchUp; un conversor offline de `.obj` (paso aparte) generará el mismo formato de datos que las plantillas provisionales escritas a mano aquí.
- Un puesto se **desactiva** en cuanto empieza a deconstruirse, como los residenciales.
- Un puesto **agotado** despide a sus recolectores y conserva a sus acarreadores hasta que se vacía su almacén local.

### **1.2 Fuera de Alcance / Siguiente**

- **Puertas interactivas:** hoy las puertas son bloques sólidos para el avatar (los colonos las ignoran en su búsqueda de rutas). Para que el avatar entre a un puesto y llegue a su baúl hace falta una puerta que se abra y sea transitable solo abierta (estado, colisión, tecla de interacción, migración de los residenciales). Es el siguiente sub-proyecto; hasta entonces el depósito físico no es alcanzable por el avatar, aunque el puesto funciona por completo con colonos.
- Costo de construcción y obreros NPC (punto 6 del roadmap), conversor `.obj`, HUD por modos y edificios de transformación (2C).

---

## **FASE 2: PLANEACIÓN**

### **2.1 Arquitectura**

- **`PlantillasPuesto.gd` (sin autoload ni `class_name`, se carga con `preload`).** Datos y funciones estáticas: por tipo, capas de bloques en texto (de abajo hacia arriba; la capa 0 va en `objetivo + 1`), con un carácter por bloque (`#` pared, `V` ventana, `B` baúl, `d`/`D` puerta inferior/superior, `.` vacío). API: `dimensiones`, `altura`, `huella`, `celdas`, `en_mundo`, `celda_de_servicio`, `celda_deposito`, `indice_extremo_agua` (pesca).
- **Colocación (`CamaraCenital._procesar_clic_puesto`).** Nivelado, drenaje, pilotes y relleno no cambian; en vez del bloque marcador se estampa la plantilla girada y se registra con `VoxelWorld.registrar_edificio_completo(celdas, {"puesto": esquina})`, así el puesto tiene orden y progreso de bloques y se deconstruye igual que un residencial. La rotación (`Ctrl` + rueda) pasa de intercambiar ancho/alto a un contador de 4 giros (`_giros_puesto`).
- **`Economia.gd`.** Cada puesto gana `activo`, `agotado`, `servicio` (celda X,Z frente a la puerta) y `deposito` (celda del baúl); nuevas `desactivar_puesto`, `reactivar_puesto`, `servicio_de`, `puesto_con_deposito`, `retirar_deposito` y la señal `trabajadores_liberados(ids)`.
- **`Colonos.gd`.** **Los colonos entran al edificio por la puerta** (la ruta de `BuscadorRutas` ya trataba las puertas como libres). Prefieren las celdas libres del piso interior (`suelo`: la altura de la capa 0 de la plantilla; primero las más alejadas de la puerta, para llenar el edificio desde el fondo sin taponar la entrada) y, si no caben, esperan en una **zona de servicio** fuera (celdas transitables a distancia de Chebyshev ≤ `RADIO_SERVICIO` = 2 de la celda frente a la puerta, sin contar esa celda ni la huella): una sola celda no basta, porque `ocupadas` no admite dos colonos en la misma celda y un puesto tiene hasta 7 trabajadores. Se llena desde el fondo (primero las celdas más alejadas de la puerta) y **la celda pegada a la puerta por dentro (el vestíbulo) no se ocupa** salvo que sea el único sitio libre: si los primeros en llegar se colocaran delante, sellarían la entrada desde dentro. Quien espera fuera reintenta entrar cada pocos segundos, para ocupar un sitio que se libere. Estar «en el puesto» es estar en el piso interior (ni en la puerta ni en el vestíbulo) o en la zona. Un puesto sin plantilla conserva el anillo junto a la huella. Un acarreador liberado con carga (`retirar_al_entregar`) termina el viaje y entrega antes de quedar desempleado.
- **Rendimiento del pathfinding (freeze).** Una búsqueda A* que falla (destino inalcanzable, o una puerta de 1 celda atascada por otros colonos) recorre todo el mundo hasta el tope de 20 000 nodos y cuesta ~0,5 s de golpe; con varios colonos reintentando se sentía como un freeze cada pocos segundos (medido con 24 colonos en 4 puestos: fotogramas de hasta 3,5 s). Correcciones: `BuscadorRutas.buscar_ruta_a_alguna()` (UNA búsqueda hacia el grupo de destinos más cercano alcanzable en vez de una por celda), `BuscadorRutas.Busqueda` (búsqueda **por partes**: `iniciar_busqueda_a_alguna()` + `avanzar(nodos)`), un presupuesto de `Colonos.NODOS_POR_FRAME` = 300 nodos (~7 ms) repartido entre todos los colonos en cada `avanzar()` para ir a un puesto o deambular, el tope local `TOPE_NODOS_DESTINO` = 2500 en `_esquivar`, `_replanificar` y la evacuación, y `_entrada_practicable()` (no se busca ruta al interior si desde la celda frente a la puerta no se puede pasar a ella). Tras el cambio el peor fotograma medido bajó a 45 ms y ya no hay búsquedas lentas fallidas.
- **`Player.gd` y `PanelPuesto.gd`.** El primer bloque que se quita de un puesto lo desactiva; al eliminarlo del todo se usa la esquina de su metadata (no la esquina mínima de las celdas); al volver a completarlo se reactiva. `E` apuntando al baúl pasa al inventario lo que quepa del almacén local. El panel indica «(inactivo)» o «(agotado)» y deshabilita los `[+]` correspondientes.

### **2.2 Constantes y convenciones**

| Constante | Valor | Origen |
|---|---|---|
| Huellas base (ancho × alto) | mina 5×5, caza/recolección 4×4, maderero 3×4, pesca 4×6 | `Recoleccion.ANCHO_HUELLA_*`/`ALTO_HUELLA_*` |
| Puerta de la plantilla base | fila `z = 0`, mira a −Z; `puerta_inferior` en la capa 0 y `puerta_superior` en la capa 1 | `PlantillasPuesto.gd` |
| Giro horario de 90° | `(x, z) → (alto − 1 − z, x)` | misma fórmula que `CamaraCenital._rotar_blueprint` |
| `RADIO_SERVICIO` | 2 | `Colonos.gd` |
| Recálculo de tasas (agotamiento) | cada `TICKS_RECALCULO` = 6 h de juego | `Economia.gd` |

---

## **FASE 3: DESARROLLO**

### **3.1 Reglas**

- **Colocación.** Se rechaza (con mensaje, antes de tocar el mundo) si las celdas de la plantilla no están libres (se comprueban hasta `altura de la plantilla + NiveladorTerreno.LIMITE_PENDIENTE` sobre la superficie), o si la **fachada** (las 2 columnas delante de TODO el lado de la puerta, igual que en los edificios declarados) tiene una pendiente excesiva, choca con madera, estructuras u otro puesto, o si la plantilla no respeta el **despeje** de puertas y ventanas (`VoxelWorld.verificar_despejes`, con la fachada como terreno a nivelar) o invade el despeje que otro edificio ya tiene reservado. Al confirmar, la fachada se **nivela a la altura del piso de la puerta** (se cava lo que sobresale y se rellena de tierra lo que falta, sin agua; una vía que la cruce se levanta y se vuelve a colocar a ese nivel) y el edificio reserva su despeje. En la pesca, si el extremo de agua detectado no coincide con el de la plantilla girada, se gira 180° para que el edificio caiga del lado de tierra.
- **Desactivar.** Al pasar el edificio de «completo» a «incompleto» (primer bloque quitado, siempre el baúl) el puesto queda `activo = false`: libera a todos sus trabajadores, deja de producir y no admite contratar. Conserva su almacén local hasta que se elimina del todo. Idempotente.
- **Reactivar.** Al volver a completarse la obra queda `activo = true`, sin trabajadores, y recalcula sus tasas (puede quedar agotado).
- **Agotamiento.** Un puesto con todas las tasas en 0 tras `recalcular_tasas` (solo puestos con `entorno` y `mundo`) está `agotado`: se liberan todos los recolectores y no se contratan más; los acarreadores se conservan mientras quede algo en el almacén local y se liberan en cuanto se vacía (comprobado cada hora en `simular_hora`, no dentro de `recoger`). Un acarreador que ya lleva carga entrega antes de quedar libre, aunque el puesto desaparezca entretanto. El puesto no se elimina; si su tasa vuelve a ser positiva deja de estar agotado y se contrata a mano.
- **Depósito.** `retirar_deposito` pasa al stock central solo lo que quepa (`Ciudad.almacen[r].agregar`) y deja el resto en el puesto.

### **3.2 Pruebas**

`PlantillasPuestoTest` (nueva, 8 pruebas: huellas, puerta y baúl, 4 giros, celda de servicio, `en_mundo`, extremo de agua de la pesca por giro, bloques existentes en la biblioteca y el ciclo real estampar → deconstruir → volver a completar sobre un `VoxelWorld`), `EconomiaTest` (17 → 21: activo/agotado, desactivar/reactivar, depósito con el stock casi lleno, agotamiento) y `ColonosTest` (26 → 29: zona de servicio, acarreador con carga liberado). Ejecución obligatoria (CLAUDE.md): `godot/scenes/Test.tscn` más las escenas afectadas.

### **3.3 Verificación manual pendiente (en el editor con Godot 4.7)**

Comprobado ya con un conductor headless sobre `Main.tscn` (colocación real de mina, caza/recolección, maderero y pesca, incluido el caso con giro extra; primer paso de deconstrucción → inactivo y trabajadores libres; eliminación completa; re-completar → reactivado). Falta verlo jugando:

1. Colocar cada puesto (`M`, `H`, `L`, `F`): se ve la plantilla con su puerta; `Ctrl` + rueda gira la puerta a los 4 lados; la colocación se rechaza si la puerta da a agua, acantilado u otro puesto.
2. Contratar recolectores y acarreadores: se reparten por la zona junto a la puerta, producen y acarrean.
3. `E` sobre el baúl del puesto (requiere poder llegar al baúl: depende de las puertas interactivas).
4. Deconstruir (`G`): el panel dice «(inactivo)»; al terminar, el puesto desaparece; al volver a completar la obra se reactiva.
5. Agotar el área (talar el bosque de un maderero o minar la veta de una mina): tras el siguiente recálculo el panel dice «(agotado)», los recolectores quedan libres y, al vaciarse el almacén, los acarreadores también.

### **3.4 Supuestos que el usuario puede corregir**

- El almacén local se conserva mientras el puesto está desactivado (se pierde al eliminarlo).
- `RADIO_SERVICIO` = 2.
- Las plantillas actuales son provisionales (una cabaña por tipo) y deben cumplir dos invariantes que comprueba `PlantillasPuestoTest`: detrás de la puerta hay una celda libre (un baúl ahí bloqueaba la entrada de la pesca) y todo el interior libre es alcanzable desde ella. Sus interiores son pequeños (maderero: 1 celda libre; caza: 3; mina: 8), así que con muchos trabajadores el resto espera fuera; los interiores que diseñe el usuario en SketchUp darán más sitio.
- `Colonos.NODOS_POR_FRAME` es una perilla: un valor más alto encuentra rutas antes pero puede notarse en el fotograma; uno más bajo reparte más la búsqueda (los colonos tardan algo más en ponerse en marcha).
- Limitación conocida: si el terreno frente a la puerta es un saliente diminuto (p. ej. un risco justo detrás), no hay dónde esperar fuera y un recolector sobrante puede quedar en el umbral sin trabajar hasta que se libere un sitio.
- Con el follaje de las columnas de la huella se elimina también el de hasta `LIMITE_PENDIENTE` bloques por encima de la altura de la plantilla (efecto colateral de reutilizar `verificar_huella_libre` con una altura mayor).

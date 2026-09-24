# **Documento Técnico de Desarrollo: PoC 5 - Fase 2B - Extracción Física y Agotamiento**

**Identificador del Módulo:** POC-05-ECONOMIA-2B

**Motor:** Godot Engine 4.7 (GDScript), sobre el proyecto compartido `godot/` (ver convención de carpetas en el GDD, Sección 11).

**Dependencias de Diseño:** GDD Sección 3 ("Área de Acción de los Puestos de Recolección" y su bullet "Producción y Acarreo"), Sección 4 ("Catálogo de Recursos y Cadenas de Producción"), Sección 11 (Fase 1 y Fase 3). Fase previa: `PoC_5/Documento Técnico de Desarrollo_ PoC 5 - Fase 2A - Puestos, Producción y Acarreo.md`.

**Dependencias Técnicas:** autoloads `Ciudad` (stock central = inventario del avatar, topes, `horas_juego`), `Recoleccion` (rendimiento, tiempos, selección de bloques, entorno y tasas), `Economia` (puestos, extracción, recálculo), `Zonificacion` (núcleo urbano) y `VoxelWorld` (retiro de bloques, árboles, frutos). Datos de balance en `docs/Recursos.xlsx` (hojas `Relacion`, `Extraccion` y `Economia`).

Spec de esta fase: `docs/superpowers/specs/2026-09-24-extraccion-fisica-agotamiento-design.md`. Plan: `docs/superpowers/plans/2026-09-24-extraccion-fisica-agotamiento.md`.

Esta fase es la rebanada **2B** del sub-proyecto 2 ("núcleo de economía"). No mezcla PoC: extiende la economía de la 2A sin tocar el documento del catálogo de recursos.

---

## **FASE 1: IDEACIÓN**

### **1.1 Objetivo**

Que los puestos consuman de verdad el mundo (las minas retiran bloques, los madereros talan árboles), que las tasas de todos los puestos se recalculen según lo que queda en su área, y que el avatar tenga recolección propia (minado, tala y frutos con tiempo e indicador de avance) sobre un inventario limitado que arranca la partida.

Decisiones confirmadas con el usuario (2026-09-24):

- Consumo abstracto por tick: cada unidad producida se descuenta de un bloque en curso del entorno.
- Rendimiento 10/1/2 y tres capas: bloque de extracción → unidad de recurso → bloque de construcción (el cobro de construcción queda fuera). Sólidos y tronco rinden 10, tierra 1, agua y petróleo 2 (reservado).
- La mina extrae solo desde `GROSOR_TIERRA - 2` bajo la superficie natural (profundidad 2 en adelante), para no dejar terreno flotando.
- Caza/recolección escala con los árboles vivos y no los consume; la pesca se recalcula con el mapa de agua generado (no con el agua real).
- Minado con tiempo por bloque y barra de avance (reinicio al soltar o cambiar de bloque).
- Inventario 500 por recurso y 5000 de comida, que se duplica al declarar el núcleo y suma +100 (comida +400) por baúl de un edificio residencial posterior al núcleo.
- El núcleo urbano no es habitable (no registra camas); los colonos llegan con el siguiente edificio residencial.
- Los frutos son la única comida manual del avatar por ahora.

### **1.2 Fuera de Alcance**

- Bomba extractora y petróleo (sub-proyecto de fluidos): solo queda la regla.
- Cobro de construcción en unidades de recurso y consumo de tierra 1-1-1 al construir.
- Herramientas del avatar (el multiplicador de herramienta queda fijo en 1).
- Caza y pesca manual del avatar.
- Conectar el indicador de avance con la construcción por fantasmas.
- Animación del colono junto al bloque que se agota y arte del indicador (barra plana en el HUD).

---

## **FASE 2: PLANEACIÓN**

### **2.1 Arquitectura**

| Archivo | Responsabilidad en 2B |
|---|---|
| `godot/scripts/GeneradorArbol.gd` | Consultas del registro de árboles (salud, radio, más cercano). |
| `godot/scripts/Recoleccion.gd` | Rendimiento, tiempos, selección de bloque de mina, entorno y tasas de un puesto. |
| `godot/scripts/Economia.gd` | Extracción por hora, bloque en curso, recálculo periódico. |
| `godot/scripts/Ciudad.gd` | Topes, ampliación, baúles, `horas_juego`, corrección de `agregar`. |
| `godot/scripts/VoxelWorld.gd` | `altura_natural_en`, `es_minable`, extracción del avatar, frutos. |
| `godot/scripts/ProgresoAccion.gd` (nuevo) | Avance de una acción con reinicio, puro. |
| `godot/scripts/ExtraccionTest.gd` + `godot/scenes/ExtraccionTest.tscn` (nuevos) | Pruebas de `ProgresoAccion`, tiempos, extracción del avatar y frutos. |
| `godot/scripts/HUD.gd` | Barra de progreso. |
| `godot/scripts/Player.gd` | Minado/tala/frutos por tiempo, núcleo sin camas. |
| `godot/scripts/BlueprintValidator.gd` | `contar_baules()`. |
| `godot/scripts/CamaraCenital.gd`, `Main.gd` | Usan `Recoleccion.entorno_de_puesto`/`tasas_de_entorno`; inyectan el mundo en `Economia`. |

### **2.2 Constantes y placeholders**

| Constante | Valor | Origen |
|---|---|---|
| `Recoleccion.RENDIMIENTO_POR_BLOQUE` | tierra 1; piedra, hierro, cobre, carbón, tierras raras y madera (por celda de tronco) 10 | Decisión del usuario, 2026-09-24; hojas `Relacion` y `Extraccion` |
| `Recoleccion.PROFUNDIDAD_MINIMA_EXTRACCION` | `GROSOR_TIERRA - 2` = 2 | Decisión del usuario, 2026-09-24 |
| `Economia.TICKS_RECALCULO` | 6 (horas de juego) | Placeholder |
| `Ciudad.LIMITE_BASE` / `LIMITE_BASE_COMIDA` | 500 / 5000 | Decisión del usuario, 2026-09-24 |
| `Ciudad.FACTOR_NUCLEO` | ×2 | Decisión del usuario, 2026-09-24 |
| `Ciudad.BONO_BAUL` / `BONO_BAUL_COMIDA` | +100 / +400 por baúl | Decisión del usuario, 2026-09-24 |
| `Ciudad.COMIDA_INICIAL` | 1500 (300 ticks de un avatar sin producción) | Placeholder; principal perilla del arranque |
| `Recoleccion.TIEMPO_MINADO` | tierra 0,4 s; piedra y carbón 1,2 s; hierro y cobre 1,6 s; tierras raras 2,4 s | Placeholder |
| `Recoleccion.TIEMPO_MINADO_DEFECTO` | 0,6 s (bloques del jugador) | Placeholder |
| `Recoleccion.MULTIPLICADOR_HERRAMIENTA` | 1,0 (sin herramientas) | Reservado |
| `Recoleccion.TIEMPO_TALA_POR_SALUD` | 1 s por punto de salud (celda de tronco) | Placeholder |
| `Recoleccion.TIEMPO_RECOLECCION_FRUTOS` | 2 s | Placeholder |
| `Recoleccion.COMIDA_POR_RECOLECCION` | 60 a densidad frutal 1,0 | Placeholder |
| `Recoleccion.HORAS_REBROTE_FRUTOS` | 24 horas de juego | Placeholder |

---

## **FASE 3: DESARROLLO**

### **3.1 Reglas**

- **Extracción por hora.** La producción sigue como en 2A (recolectores presentes × tasa). Cada puesto que consume (`Economia.TIPOS_QUE_CONSUMEN`: mina y maderero) guarda por recurso un **bloque en curso** `{celda, restante}`; las unidades producidas se restan de `restante` y, al llegar a 0, el bloque se retira del mundo y se elige el siguiente (un tick puede agotar varios). Sin material en el área la producción se acota a lo disponible (llega a 0). Los bloques puestos por el jugador o de edificios nunca cuentan.
- **Mina.** Solo minerales de su elipsoide, desde la profundidad 2; primero el bloque más cercano al centro y, a igual distancia, el menos profundo.
- **Maderero.** Tala árboles enteros dentro de su radio (12) con `GeneradorArbol.danar`; cada punto de salud rinde 10 de madera y al agotarse cae el árbol.
- **Caza/recolección y pesca.** No consumen bloques: la caza/recolección multiplica su tasa por `árboles vivos / árboles al colocar` (tope 1); la pesca se recalcula con el mapa de agua generado (`celdas_agua_conectadas()` sobre el generador, no sobre los vóxeles reales) y su escala por tamaño; por tanto drenar o conectar agua todavía no cambia su tasa (ver supuestos pendientes).
- **Recálculo.** Cada `TICKS_RECALCULO` = 6 horas de juego `Economia` recalcula las tasas de cada puesto con `Recoleccion.entorno_de_puesto` y `tasas_de_entorno` (lógica trasladada desde `CamaraCenital`, que ahora usa las mismas funciones al previsualizar y colocar). `Economia.mundo` es inyectable.
- **Avatar.** Minado con tiempo (`TIEMPO_MINADO[tipo] × MULTIPLICADOR_HERRAMIENTA`, reinicio al soltar o cambiar de bloque), tala por salud (el daño se conserva) y frutos con rebrote; todo con una barra de avance en el HUD (`ProgresoAccion`), que también usa la deconstrucción. Los bloques puestos por el jugador no rinden recursos.
- **Inventario y núcleo.** El inventario es `Ciudad.almacen`. Límite = `base × factor_núcleo + baúles × bono`. `Ciudad.ampliar_almacen()` (idempotente) se llama al declarar el núcleo. Los baúles se cuentan al completar un edificio residencial y se restan al deconstruirlo; los del núcleo no suman. Si el límite baja, el stock excedente se conserva pero no entra nada nuevo. El primer edificio declarado es el núcleo y no registra camas; el siguiente residencial trae los primeros colonos.

### **3.2 Pruebas**

`EconomiaTest` (consumo, agotamiento, recálculo de mina y de caza/recolección; carga parcial de un puesto agotado; bloque en curso reemplazado por uno del jugador), `RecoleccionTest` (rendimiento, selección de mina, maderero sin árboles con tasa 0), `CiudadTest` (topes, `ampliar_almacen()`, baúles), `GeneradorArbolTest` (consultas del registro de árboles), `BlueprintValidatorTest` (`contar_baules()`) y `ExtraccionTest` (nueva: `ProgresoAccion`, tiempos, extracción del avatar, frutos y `altura_natural_en()` bajo un río). Sin prueba automática: el recálculo de la pesca y la regla de núcleo sin camas (vive en `Player._completar_construccion`), que solo se verifican a mano. Ejecución obligatoria (CLAUDE.md): `godot/scenes/Test.tscn` más las escenas afectadas (`ColonosTest`, `ConstruccionTest`, `ZonificacionTest`) y `Main.tscn` sin errores de script. Resultado del cierre de la fase (2026-09-24, Godot 4.7 headless): todas las escenas pasan.

### **3.3 Verificación manual (pendiente para el usuario, en el editor con Godot 4.7)**

Nadie ha ejecutado todavía estas comprobaciones en el editor; **quedan pendientes** y no se da ninguna por superada:

1. Mantener clic izquierdo sobre tierra/piedra: la barra verde sube, al llenarse el bloque desaparece, la consola imprime `Recolectado: {...}` y la lista de recursos del HUD sube.
2. Empezar a minar y apuntar a otro bloque (o soltar el clic): la barra se reinicia.
3. Mantener clic sobre un árbol: la barra naranja muestra la salud restante y baja cada segundo; al soltar y volver, el daño se conserva; el árbol cae entero al llegar a 0 y la madera sube.
4. Mantener `E` sobre un árbol: la barra sube y suma comida; repetirlo enseguida en el mismo árbol no da nada (rebrote de 24 h).
5. `G` (deconstrucción) sobre un edificio: la barra naranja se vacía con el contador de "sostener".

**Supuestos y pendientes conocidos.**

- La pesca se recalcula contra el mapa de agua generado, no contra los vóxeles reales. Que su tasa siga el agua real (drenar o conectar) queda pendiente y necesita su propio diseño: la plataforma y los pilotes del propio puesto están sobre su extremo de agua y un lector ingenuo de vóxeles podría dejar la tasa en 0.
6. Mirar agua o el cielo con el clic mantenido: no pasa nada ni hay errores en consola.
7. Colocar un maderero y una mina, asignarles recolectores y ver bajar la tasa en el panel al talar o agotar el área.
8. Jugada completa desde la partida vacía hasta la llegada de los primeros colonos con el segundo edificio residencial (núcleo primero, sin colonos; topes 500/5000 que se duplican al declararlo; baúles que amplían el tope).

### **3.4 Supuestos que el usuario puede corregir**

- Rendimiento 10 para todos los sólidos (y el tronco por celda), tierra 1.
- Los tiempos de minado, tala y frutos, `COMIDA_INICIAL` = 1500, `COMIDA_POR_RECOLECCION`, `HORAS_REBROTE_FRUTOS` y `TICKS_RECALCULO` son placeholders de balance.
- El avatar rinde más rápido que un recolector (perilla de balance).

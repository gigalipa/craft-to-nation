# Guía de Primeros Pasos

![Del primer refugio a la metrópolis industrial](/assets/citycraft-hero.webp)

Bienvenido a **Craft to Nation**, un simulador híbrido donde la supervivencia visceral en primera persona se fusiona con la planificación urbana (*City Builder*), la logística industrial y la estrategia en tiempo real. Tu aventura comienza como un pionero solitario en un mundo de vóxeles procedural de **200×200 celdas** (altura máxima `y = 130` con 24 capas de subsuelo hasta la roca madre), con el objetivo de fundar una metrópolis autosuficiente.

---

## 1. Controles y Navegación Dual (Micro ↔ Macro)

El juego permite alternar en cualquier momento entre tu avatar físico en primera persona y la cámara táctica cenital mediante un vuelo de cámara continuo de `0,6 s`:

### Controles Globales
- <kbd>C</kbd>: **Alternar entre Primera Persona y Cámara Cenital (*City Builder*)**.
- <kbd>M</kbd>: Abrir / cerrar la ventana analítica de **Moral Ciudadana** (`VentanaMoral`).
- <kbd>Esc</kbd>: Cerrar ventanas modales activas, salir del modo activo de vías/deconstrucción (en 1ra persona), volver al modo neutro **Ver** (en cámara cenital) o liberar el cursor del ratón.

### Controles en Primera Persona (Modo Pionero)
- <kbd>W</kbd> <kbd>A</kbd> <kbd>S</kbd> <kbd>D</kbd>: Desplazamiento físico del avatar (con empuje horizontal de corriente en ríos y bases de cascadas).
- <kbd>Espacio</kbd> / <kbd>Ctrl</kbd>: Saltar en tierra / En líquidos profundos (`>= 2` bloques de profundidad; en `1` bloque de agua el avatar camina normalmente), **nadar hacia arriba (<kbd>Espacio</kbd>)** o **sumergirse hacia abajo (<kbd>Ctrl</kbd>)**. Al sumergir la cabeza se activa `PanelOxigeno` (`10,0 s` de autonomía, recuperándose al doble de velocidad al salir a la superficie).
- <kbd>Clic Izquierdo</kbd> (mantener): Talar árboles (`herr_hacha.svg`, `1,0 s` por punto de salud del tronco), minar terreno o vetas minerales con barra de progreso e icono contextual (`herr_pala.svg` en tierra `0,4 s`; `herr_pico.svg` en piedra/carbón `1,2 s`, hierro/cobre `1,6 s`, tierras raras `2,4 s`), o deconstruir paso a paso si el modo <kbd>G</kbd> está activo.
- <kbd>Clic Derecho</kbd>: Colocar el bloque seleccionado de la barra rápida (`1`–`0`), abastecer una obra fantasma apuntando a sus bloques o muros exteriores, o **drenar/secar celdas inundadas** de `agua` o `crudo` colocando un bloque sólido directamente sobre el líquido.
- <kbd>1</kbd> – <kbd>9</kbd>, <kbd>0</kbd> / <kbd>Rueda del Ratón</kbd>: Seleccionar bloque en la barra rápida (`tierra`, `adobe`, `bloque_madera`, `bloque_piedra`, `estructura_hierro`, `vidrio`, `puerta`, `cama`, `baul`, `bloque_acero`).
- <kbd>E</kbd>:
  - **Pulsar:** Abrir o cerrar puertas mirando hacia ellas, o abrir el baúl local de un puesto periférico activo (`VentanaBaul`, ventana compacta de `320×260` con transferencia `-`, `+` y `"Extraer todo"`).
  - **Mantener pulsado (`2,0 s`) apuntando a un árbol:** **Recolectar frutos silvestres** (`herr_cesta.svg`, otorga **60 unidades de comida** sin talar el árbol; los frutos rebrotan tras `24 horas` de juego).
- <kbd>G</kbd>: Activar / desactivar el **modo de deconstrucción manual a pie** (<kbd>Clic Izquierdo</kbd> desmonta bloque a bloque; <kbd>Clic Derecho</kbd> marca o desmarca para demolición).
- <kbd>V</kbd>: Activar / desactivar el **modo de interacción de vías a pie**: una vez activo, <kbd>Clic Izquierdo</kbd> construye de golpe una sección completa de carretera pendiente de `2×2`, y <kbd>Clic Derecho</kbd> demuele al instante una sección de vía de `2×2` ya construida (pulsa <kbd>V</kbd> o <kbd>Esc</kbd> para salir del modo).
- <kbd>B</kbd>: **Declarar edificio terminado** apuntando a su puerta exterior en planta baja.
- <kbd>Shift</kbd> + <kbd>B</kbd>: **Iniciar remodelación no destructiva** apuntando a la puerta exterior de un edificio ya declarado (lo abre a edición libre sin perder su registro ni demolerlo).
- <kbd>L</kbd>: Encender / apagar la **lámpara omnidireccional del avatar** (`PanelLampara`):
  - **Modo Lámpara Térmica (`LÁMPARA TÉRMICA🟡`):** Cuando la ciudad aún no genera electricidad (`0 E/h`), consume suministros del almacén central por jerarquía: **Combustible** (`10 h/u`, alcance 14 m) → **Carbón** (`6 h/u`, alcance 10 m) → **Madera** (`5 h/u`, alcance 7 m).
  - **Modo Lámpara Eléctrica (`LÁMPARA ELÉCTRICA🟡`):** Cuando la ciudad cuenta con generación eléctrica activa (`> 0 E/h`), opera con una **batería de 72 h** (luz blanca de 18 m sin gastar combustibles); fuera de la Zona de Influencia se descarga a razón de `-1 h` por hora de juego y al volver a la ciudad se recarga rápidamente a **`+7,2 h` por hora de juego**.

![Construcción manual del primer refugio en primera persona](/assets/fp-building.webp)

### Controles en Cámara Cenital (Gestión Urbana y Menú Numérico Jerárquico)
- <kbd>W</kbd> <kbd>A</kbd> <kbd>S</kbd> <kbd>D</kbd>: Desplazar horizontalmente el foco de la cámara por el plano X/Z.
- <kbd>Q</kbd> / <kbd>E</kbd>: **Rotación orbital** alrededor del punto focal hacia la izquierda (<kbd>Q</kbd>) o derecha (<kbd>E</kbd>).
- <kbd>Ctrl</kbd> + <kbd>W</kbd> / <kbd>S</kbd>: **Inclinación (*Pitch*):** Ajustar el ángulo de inclinación vertical de la cámara (`15°` a `85°`).
- <kbd>Shift</kbd> + <kbd>W</kbd> / <kbd>S</kbd>: **Elevación vertical:** Subir (<kbd>Shift</kbd>+<kbd>W</kbd>) o bajar (<kbd>Shift</kbd>+<kbd>S</kbd>) directamente la cota de altura del punto focal (`foco.y`).
- <kbd>Rueda del Ratón</kbd>: Zoom oblicuo respecto al punto focal.
- <kbd>Ctrl</kbd> + <kbd>Rueda del Ratón</kbd>: **Rotar 90°** la vista previa y miniatura 3D de un *blueprint* o plantilla antes de colocarlo.
- **Navegación por Teclas Numéricas (<kbd>1</kbd> – <kbd>9</kbd>) y Submenús (<kbd>Z</kbd> / <kbd>X</kbd> / <kbd>Esc</kbd>):**
  Las teclas numéricas permiten navegar jerárquicamente por los niveles del menú inferior (`BarraModos.gd`) seleccionando la opción correspondiente al nivel actual:
  - <kbd>1</kbd> **Menú Construir:**
    - `1` **Residencial:** Ranuras `1` a `5` para tus diseños guardados (`Residencia [camas]x[baúles]`).
    - `2` **Periférico:** `1` Caza, `2` Madera, `3` Mina, `4` Pesca, `5` Estación de bombeo, `6` Centro de extracción.
    - `3` **Industrial:** `1` Siderúrgica, `2` Tierras raras, `3` Aserradero, `4` Fábrica de bloques, `5` Carbonera, `6` Refinería petrolera, `7` Productor combustible, `8` Central termoeléctrica, `9` Almacén.
    - `4` **Investigación:** `1` Escuela técnica, `2` Escuela de especialistas, `3` Universidad.
    - `5` **Vías:** `1` Trazar vía *(en cámara cenital, el trazado de carreteras se activa desde este menú `1 -> 5 -> 1`)*.
    - `6` **Ductos:** `1` Acueducto, `2` Tubería.
  - <kbd>2</kbd> **Menú Zonificar:** `1` Zona Residencial, `2` Zona Industrial, `3` Borrar zona.
  - <kbd>3</kbd> **Modo Demoler Unificado:** Marca edificios en rojo con un clic o traza demoliciones viales guiadas en naranja (doble clic) siguiendo las curvas de la carretera mediante Dijkstra.
  - <kbd>Z</kbd> / <kbd>X</kbd>: **Retroceder un nivel en el menú** o ir a la página anterior (<kbd>Z</kbd>) / Avanzar a la **siguiente página** (<kbd>X</kbd>) cuando una categoría supera los 9 elementos.
- **Acciones del Ratón en Cámara Cenital:**
  - <kbd>Clic Izquierdo</kbd>: Fijar esquina de zona, vía o ducto; colocar estructura; o inspeccionar edificio/puesto/canalización en modo **Ver** (<kbd>Esc</kbd>).
  - <kbd>Doble Clic Izquierdo</kbd>: Confirmar el trazado de una carretera (`1 -> 5 -> 1`), una demolición vial guiada (`3`) o un tramo de canalización elevada (`1 -> 6`).
  - <kbd>Clic Derecho</kbd>: Cancelar limpiamente el tramo en curso o salir del modo de colocación sin dejar bloques fantasma.

---

## 2. Fase 1: Génesis y Supervivencia Básica

1. **Recolección de Frutos Silvestres (<kbd>E</kbd> sostenido):** Acércate a un árbol frutal y mantén presionada la tecla <kbd>E</kbd> durante `2,0 s` para cosechar **60 unidades de comida** sin talar el árbol (`HORAS_REBROTE_FRUTOS = 24`). El avatar consume **5 u/h** de comida en Nivel Urbano 1 (`4 u/h` en Nivel 2 y `3 u/h` en Nivel 3).
2. **Tala y Minería Manual (<kbd>Clic Izquierdo</kbd> sostenido):** Cada bloque de tronco talado rinde **10 unidades de madera**, cada bloque de piedra o mineral rinde **10 unidades**, y cada bloque de tierra rinde **1 unidad**.
3. **Drenaje Manual de Líquidos (<kbd>Clic Derecho</kbd>):** Si necesitas cruzar o secar charcos de `agua` o derrames de `crudo`, selecciona un bloque sólido en el *hotbar* y haz <kbd>Clic Derecho</kbd> sobre el líquido para reemplazarlo instantáneamente.

---

## 3. Fundación del Núcleo Urbano y Ciclo Residencial

```
[Construcción manual de casa de hasta 2 pisos con puerta en planta baja, ventana, camas y baúl]
       ↓ (Apuntar a la puerta exterior y pulsar B)
[Declaración del 1er Edificio = NÚCLEO URBANO + Guardado de Blueprint "Residencia [camas]x[baúles]"]
       ↓ (Cámara Cenital [C]: Pintar Zona Residencial [2 -> 1] y colocar 1ra Residencia [1 -> 1])
[1ra Residencia Habitable nace con "Colonizable: SÍ" → Llegada de Inmigrantes]
       ↓ (2da Residencia en adelante nace con "Colonizable: NO (apertura en 24 h)")
[Buffer protegido para reubicar residentes sin generar "Sin techo" al remodelar con Shift + B]
```

### Reglas Clave del Ciclo Residencial (Verificadas en Vivo)
- **El 1er Edificio funda el Núcleo Urbano:** Tu primera estructura cerrada declarada con <kbd>B</kbd> se convierte siempre en el **Núcleo Urbano** (duplica la capacidad base del almacén central a `1.000 u` general / `10.000 u` comida, proyecta la **Zona de Influencia** de radio `30` y guarda automáticamente el diseño en el catálogo como `Residencia [camas]x[baúles]`). La planta alta **no requiere puerta exterior**.
- **1ra Residencia Habitable (`Colonizable: SÍ`):** Al colocar ese *blueprint* (`1 -> 1`) dentro de la Zona Residencial (`2 -> 1`) y construirlo, nace con **`Colonizable: SÍ (inmigración activa)`**, atrayendo a tus primeros colonos.
- **2da Residencia en adelante (`Colonizable: NO 24h`):** A partir de la segunda vivienda, los colonos obreros/desempleados acuden solos a construirla y el edificio nace como **buffer protegido** (`Colonizable: NO (apertura en 24 h)`). Si inicias una remodelación (<kbd>Shift</kbd> + <kbd>B</kbd>) en tu primera casa habitada mientras la segunda tiene camas buffer libres, los residentes se mudan automáticamente a la segunda casa generando **0 colonos sin techo**.
- **Casas Adosadas y Reubicación del Núcleo Urbano (5 h):** Puedes construir casas pared con pared (el algoritmo *flood-fill* se detiene en los muros vecinos sin fusionarlas) y puedes trasladar la sede del Núcleo Urbano a otra residencia desde su ficha (`[Asignar como núcleo urbano]`) tras un período de transición de **5 horas**.

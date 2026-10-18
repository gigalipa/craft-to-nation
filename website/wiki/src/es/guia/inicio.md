# Guía de Primeros Pasos

![Del primer refugio a la metrópolis industrial](/assets/citycraft-hero.webp)

Bienvenido a **Craft to Nation**, un simulador híbrido donde la supervivencia visceral en primera persona se fusiona con la planificación urbana (*City Builder*), la logística industrial y la estrategia en tiempo real. Tu aventura comienza como un pionero solitario en un mundo de vóxeles procedural de **200×200 celdas** (altura máxima `y = 130` con 24 capas de subsuelo hasta la roca madre), con el objetivo de fundar una metrópolis autosuficiente.

---

## 1. Controles y Navegación Dual (Micro ↔ Macro)

El juego permite alternar en cualquier momento entre tu avatar físico en primera persona y la cámara táctica cenital mediante un vuelo de cámara continuo de `0,6 s`:

### Controles Globales
- <kbd>C</kbd>: **Alternar entre Primera Persona y Cámara Cenital (*City Builder*)**.
- <kbd>M</kbd>: Abrir / cerrar el **Panel de Moral Cívica** (`VentanaMoral`).
- <kbd>Esc</kbd>: Liberar o capturar el cursor del ratón / cerrar paneles modales activos.

### Controles en Primera Persona (Modo Pionero)
- <kbd>W</kbd> <kbd>A</kbd> <kbd>S</kbd> <kbd>D</kbd>: Desplazamiento físico del avatar (con empuje de corriente al cruzar ríos).
- <kbd>Espacio</kbd>: Saltar en tierra / **Nadar hacia arriba** en ríos, lagos o mares (barra de oxígeno de `10,0 s` al sumergir la cabeza).
- <kbd>Ctrl</kbd>: **Sumergirse / Nadar hacia abajo** en el agua.
- <kbd>Clic Izquierdo</kbd> (mantener): Minar bloques con grietas progresivas (`0,4 s` tierra, `1,2 s` piedra/carbón, `1,6 s` hierro/cobre, `2,4 s` tierras raras), talar árboles (`1,0 s` por punto de salud del tronco) o recolectar frutos silvestres (`2,0 s` para obtener `60 u` de comida sin destruir el árbol).
- <kbd>Clic Derecho</kbd>: Colocar el bloque seleccionado de la barra rápida (*hotbar*).
- <kbd>1</kbd> – <kbd>0</kbd> / <kbd>Rueda del Ratón</kbd>: Seleccionar bloque en la barra rápida (`tierra`, `adobe`, `bloque_madera`, `bloque_piedra`, `estructura_hierro`, `vidrio`, `puerta`, `cama`, `baul`, `bloque_acero`).
- <kbd>E</kbd>: Abrir o cerrar puertas mirando hacia ellas, o abrir la ficha de un baúl residencial (`VentanaBaul`).
- <kbd>B</kbd>: **Declarar edificio** (apuntando a la puerta principal de una estructura hermética cerrada).
- <kbd>Shift</kbd> + <kbd>B</kbd>: **Remodelación no destructiva** (apuntando a la puerta principal de un edificio ya declarado para abrirlo temporalmente a edición manual sin demolerlo).
- <kbd>V</kbd>: Construir manualmente un tramo de carretera pendiente o demoler una vía existente apuntando al suelo.
- <kbd>L</kbd>: Encender / apagar la **linterna frontal de minero** (`SpotLight3D`) para trabajar de noche o en cuevas profundas.

![Construcción manual del primer refugio en primera persona](/assets/fp-building.webp)

### Controles en Cámara Cenital (Modo City Builder)
- <kbd>W</kbd> <kbd>A</kbd> <kbd>S</kbd> <kbd>D</kbd>: Desplazar el foco de la cámara por el plano horizontal.
- <kbd>Q</kbd> / <kbd>E</kbd>: Orbitar la cámara en sentido horario / antihorario.
- <kbd>Ctrl</kbd> + <kbd>W</kbd> / <kbd>S</kbd>: Ajustar la inclinación vertical (*pitch*) de la cámara (`15°` a `85°`).
- <kbd>Shift</kbd> + <kbd>W</kbd> / <kbd>S</kbd>: Elevar o descender la cota vertical del foco (`foco.y`) para inspeccionar minas o rascacielos.
- <kbd>Rueda del Ratón</kbd>: Zoom (*acercar / alejar*).
- <kbd>Ctrl</kbd> + <kbd>Rueda del Ratón</kbd>: **Rotar 90°** la plantilla o *blueprint* antes de colocarlo.
- <kbd>1</kbd> / <kbd>2</kbd> / <kbd>3</kbd>: Alternar modos en la barra inferior (**1: Construir**, **2: Zonificar A/B**, **3: Demoler**).
- <kbd>V</kbd>: Activar la herramienta de trazado de **Vías** (`ConstructorVias`) o demolición guiada de tramos viales (cuando el modo Demoler está activo).

---

## 2. Fase 1: Génesis y Supervivencia Básica

Al aparecer en el mundo, tu primera prioridad es asegurar tu subsistencia calórica y reunir materiales para tu primer refugio:

1. **Recolección de Frutos Silvestres:** Acércate a árboles con follaje frutal y mantén <kbd>Clic Izquierdo</kbd> durante `2,0 s` mirando la copa o el tronco sin talarlo. Obtendrás hasta **60 unidades de comida** (`COMIDA_POR_RECOLECCION = 60.0`), y el árbol volverá a dar frutos tras `24 horas` de juego (`48 s` reales). El avatar consume **5 u/h** de comida en Nivel Urbano 1 (`4 u/h` en Nivel 2 y `3 u/h` en Nivel 3).
2. **Tala Manual de Madera:** Mantén presionado <kbd>Clic Izquierdo</kbd> sobre el tronco hasta agotar su salud (`1,0 s` por bloque de altura del tronco). Al caer, cada bloque de tronco rinde **10 unidades de madera**.
3. **Extracción de Tierra y Piedra:** Mina bloques de tierra (`1 u` por bloque) y afloramientos de piedra (`10 u` por bloque).
4. **Reserva Inicial del Asentamiento:** El inventario colectivo arranca con **5,000 unidades de comida** y **200 unidades de madera**, con un tope base de `500 u` por recurso general y `5,000 u` para comida antes de declarar el Núcleo Urbano.

---

## 3. Fundación del Asentamiento y el Núcleo Urbano

Para transformar tu campamento en una ciudad organizada, debes construir y declarar el **Núcleo Urbano**:

```
[Campamento Pionero] 
       ↓ (Construcción de refugio hermético con puerta en planta baja)
[Declaración con tecla B sobre la puerta principal] 
       ↓ (Elección como Núcleo Urbano)
[Desbloqueo de Área de Influencia (Radio 30 celdas) + Almacén ×2]
       ↓ (Zonificación A/B y construcción de la primera vivienda con camas)
[Inmigración Continua de Colonos]
```

### Paso 1: Construcción del Refugio Hermético
Edifica una estructura cerrada con muros de material estructural (`adobe`, `bloque_madera`, `bloque_piedra`, `estructura_hierro`, `vidrio` o `bloque_acero`; la `tierra` natural no cuenta como pared válida), techo completo, altura interior libre mínima de **3 bloques** y **una única puerta exterior en la planta baja**.

### Paso 2: Declaración del Núcleo Urbano (<kbd>B</kbd>)
Apunta a la puerta principal en primera persona y presiona <kbd>B</kbd>. Cuando el validador volumétrico (`ValidadorEdificios`) confirme la hermeticidad:
- El primer edificio declarado en la partida se convierte automáticamente en tu **Núcleo Urbano** (o puedes elegir entre *Residencial*, *Almacén* o *Núcleo Urbano* si ya posees uno).
- Se proyecta el **Área de Influencia Territorial** (radio de **30 celdas**, huella de `61×61` celdas centrada en el edificio).
- El **Almacén Central** duplica su capacidad máxima (**×2**, pasando a **1,000 u** por recurso general y **10,000 u** de comida).

> [!TIP] Remodelación No Destructiva (`Shift + B`)
> Si deseas ampliar tu edificio más adelante o añadirle nuevos pisos, apunta a su puerta principal y presiona <kbd>Shift</kbd> + <kbd>B</kbd>. El edificio entrará en modo remodelación conservando a sus residentes en un *buffer* de espera mientras modificas los muros y vuelves a declararlo con <kbd>B</kbd>.

---

## 4. Zonificación y los Primeros Habitantes

Con el Núcleo Urbano activo, presiona <kbd>C</kbd> para pasar a la **Cámara Cenital** y organizar tu territorio:

- **Zona A (Residencial, Cívica y Académica):** Donde se ubican viviendas, almacenes dedicados (`3,000 u`), escuelas técnicas/especialistas y universidades.
- **Zona B (Industrial):** Polígono reservado para aserraderos, fábricas de bloques, carboneras, siderúrgicas, refinerías y centrales termoeléctricas.
- **Periferia Silvestre:** Espacio exterior donde se emplazan puestos madereros, minas, cabañas de caza/recolección, muelles de pesca, estaciones de bombeo de agua y centros de extracción petrolera.

### Colonizabilidad y Buffers de 24 Horas
- **Primera Vivienda:** Tu primer edificio residencial con camas libres nace con **`Colonizable: ACTIVO`**, atrayendo inmigrantes de inmediato si la moral supera `20`.
- **Viviendas Posteriores (Buffer de 24h):** Del segundo edificio residencial en adelante, nacen por defecto como *buffers* protegidos (**`Colonizable: INACTIVO`** con cuenta regresiva automática de `24 horas` de juego o activación manual en su ficha) para que puedas reubicar colonos durante remodelaciones antes de abrir las camas a nuevos inmigrantes externos.


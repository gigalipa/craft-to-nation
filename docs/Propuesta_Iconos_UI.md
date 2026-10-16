# Propuesta de Iconografía Completa para la Interfaz de Usuario (UI / HUD)

Este documento detalla todos los elementos de la interfaz de **Craft to Nation** donde se propone incorporar o actualizar íconos e imágenes, manteniendo la identidad visual del HUD (estética verde oscuro `#0D211A`, bordes dorados `#C79E40` y tipografía clara `#F2EBD1`).

> **Instrucciones de uso:** Revisa cada fila. En la tercera columna (**Aprobación / Propuesta del Usuario**) puedes escribir **"Aprobado"** (o **"OK"**) si estás de acuerdo con la sugerencia, o describir el cambio que prefieras.

---

## 1. Catálogo Transversal de Recursos (15 Recursos)

*Estos íconos se reutilizarán de forma consistente en la Barra Superior, Ventana de Almacén, Ventana de Baúl (`Icono_<recurso>`), Panel de Puesto, Panel de Edificio (materiales faltantes), Panel Contextual (costos de construcción) y Diálogos de Investigación.*

| Ubicación / Elemento en la UI | Sugerencia de Ícono / Imagen | Aprobación / Propuesta del Usuario |
| :--- | :--- | :--- |
| **Recurso: `comida` (Comida)** | Cesta de mimbre con pan, manzana y pieza de carne asada (o muslo de carne junto a una espiga de trigo) en tonos cálidos. | Me gusta el ícono de un mulso de carne junto a una espiga de trigo, es más icónico y fácil de discernir en tamaños pequeños. |
| **Recurso: `madera` (Madera bruta)** | Dos o tres troncos de árbol cilíndricos apilados con corteza marrón y anillos visibles en el corte frontal. | Aprobado |
| **Recurso: `tablas` (Tablas procesadas)** | Conjunto de tablones rectangulares de madera cepillada y clara, apilados en diagonal con veta limpia. | Aprobado |
| **Recurso: `tierra` (Tierra)** | Montículo de tierra suelta marrón oscuro con pequeños terrones en la base. | Aprobado |
| **Recurso: `piedra` (Piedra bruta)** | Roca gris irregular y angulosa con un par de fragmentos menores alrededor. | Aprobado |
| **Recurso: `bloques_piedra` (Bloques de piedra)** | Ladrillos o sillares de piedra gris tallados de forma cúbica y apilados con juntas definidas. | Aprobado |
| **Recurso: `hierro` (Mineral de hierro)** | Roca oscura de mena con vetas metálicas grisáceas/rojizas brillantes incrustadas. | Prefiero una pila de tres lingotes de color gris oscuro y metalizado con marcas de óxido. |
| **Recurso: `cobre` (Mineral de cobre)** | Roca de mena con incrustaciones metálicas de color cobrizo anaranjado y pequeños toques de pátina turquesa. | Prefiero una pila de tres lingotes de color cobrizo metalizado. |
| **Recurso: `carbon` (Carbón)** | Fragmentos de mineral negro brillante y facetado (estilo hulla/antracita). | Aprobado |
| **Recurso: `tierras_raras` (Tierras raras)** | Drusa o racimo de cristales minerales luminosos en tonos violeta/cian emergiendo de una base rocosa. | Aprobado |
| **Recurso: `acero` (Acero)** | Par de lingotes metálicos pulidos de color gris azulado con reflejo especular (o viga perfilada en "I"). | Me parecen bien los lingotes. |
| **Recurso: `mineral_refinado` (Mineral refinado)** | Gema o prisma hexagonal pulido y brillante de alta pureza en tono turquesa/esmeralda con destello energético. | Aprobado |
| **Recurso: `agua` (Agua)** | Gota de agua cristalina en azul claro con un pequeño reflejo blanco curvo. | Aprobado |
| **Recurso: `crudo` (Petróleo crudo)** | Barril metálico oscuro con una gota espesa negra cayendo por el borde (o gota viscosa negra brillante). | Preferiría un barril metálico oscuro con una gota de petróleo crudo. |
| **Recurso: `combustible` (Combustible)** | Bidón o jerrycan industrial de color rojo/ámbar con símbolo de llama o gota inflamable. | Aprobado |

---

## 2. Catálogo Transversal de Demografía y Oficios

*Estos íconos se emplearán en `VentanaPoblacion.gd`, en las filas de contratación de `PanelPuesto.gd`, en los residentes de `PanelEdificio.gd` y en las alertas migratorias de `VentanaMoral.gd`.*

| Ubicación / Elemento en la UI | Sugerencia de Ícono / Imagen | Aprobación / Propuesta del Usuario |
| :--- | :--- | :--- |
| **Población general / Censo total** | Silueta doble o triple de bustos humanos en color crema/dorado. | Me gusta la silueta triple. |
| **Rol: `ciudadano` (Ciudadanos)** | Busto de colono con vestimenta civil sencilla. | Considerando que será un ícono pequeño, prefiero que sea una silueta simple de una persona, sin detalles de ropa. |
| **Rol: `desempleado` (Desempleados / Libres)** | Busto de colono con brazos cruzados o junto a un pequeño reloj de espera / manos abiertas disponible. | Me gusta el busto/silueta de una persona, similar a la de ciudadano, pero con los brazos cruzados. |
| **Rol: `obrero` / `recolector` (Obreros)** | Busto de trabajador con casco de obra o pañuelo y un pico/martillo apoyado al hombro. | Me gusta el busto/silueta de una persona, similar a la de ciudadano, pero con un casco de obra. |
| **Rol: `tecnico` (Técnicos)** | Busto con gafas protectoras industriales y una llave inglesa o engranaje pequeño. | Me gusta el busto/silueta de una persona, similar a la de ciudadano, pero con gafas protectoras industriales y un engranaje pequeño. |
| **Rol: `especialista` (Especialistas)** | Busto con indumentaria técnica avanzada y un calibre de precisión o estrella de rango dorado. | Me gusta el busto/silueta de una persona, similar a la de ciudadano, pero con un calibre de precisión (la estrella no porque la relaciono más con el ámbito militar). |
| **Rol: `investigador` (Investigadores)** | Busto con gafas de lectura / bata y un matraz de laboratorio o libro abierto. | Me gusta el busto/silueta de una persona, similar a la de ciudadano, pero con birrete y un libro abierto. |
| **Rol: `militar` (Militares)** | Busto con casco táctico/militar junto a un escudo o espada cruzada. | Me gusta el busto/silueta de una persona, similar a la de ciudadano, pero con un escudo y espada cruzada. |
| **Rol: `aprendiz` (Aprendices en escuelas)** | Busto joven con un libro abierto y una pequeña flecha ascendente de progreso. | Me gusta el busto/silueta de una persona, similar a la de ciudadano, pero con un libro abierto y una pequeña flecha ascendente de progreso. |
| **Rol: `acarreador` (Acarreadores)** | Figura o busto cargando una caja de madera / fardo sobre los hombros. | Preferiría un busto/silueta de una persona, similar a la de ciudadano, pero con una caja de madera. |
| **Estado: `sin_techo` (Ciudadanos sin techo)** | Silueta de casa con una línea diagonal de tachado o techo quebrado en tono ámbar/rojo de alerta. | Siguiendo el estilo de los demás, esta sería la misma silueta del desempleado pero con una casita tachada. |

---

## 3. Barra Superior de Estado (`BarraSuperior.gd`)

*Visible permanentemente en la parte superior de la pantalla en ambas cámaras.*

| Ubicación / Elemento en la UI | Sugerencia de Ícono / Imagen | Aprobación / Propuesta del Usuario |
| :--- | :--- | :--- |
| **Botón / Indicador `Población` (`censo/camas (desempleados)`)** | Ícono de silueta de grupo de personas antes de la cifra del censo + ícono pequeño de cama junto a la capacidad + ícono de desempleado entre paréntesis. | Aprobado. El ícono de la silueta de grupo sería el mismo que el del censo en el panel de población (3 personas). |
| **Botón `Moral` — Estado Crítico (`< 20%`)** | Rostro estilizado (vectorial dorado/rojo coherente con el HUD en vez de emoji de sistema) con ceño fruncido extremo y expresión de furia/rebelión (sustituyendo a `😡`). | Aprobado |
| **Botón `Moral` — Estado Bajo (`20% - 35%`)** | Rostro estilizado en tono ámbar con comisuras hacia abajo y expresión de descontento/abatimiento (sustituyendo a `🙁`). | Aprobado |
| **Botón `Moral` — Estado Neutro (`35% - 65%`)** | Rostro estilizado en tono crema con expresión serena y boca horizontal (sustituyendo a `😐`). | Aprobado |
| **Botón `Moral` — Estado Alto (`>= 65%`)** | Rostro estilizado en tono verde claro/dorado con sonrisa entusiasta (sustituyendo a `🙂`). | Aprobado |
| **Botón `Almacén`** | Ícono de edificio de almacén o par de cajas de madera apiladas a la izquierda del texto `"Almacén"`. | Aprobado el ícono de las cajas apiladas. |
| **Indicador `Comida`** | Ícono del recurso `comida` (cesta/alimento) sustituyendo o precediendo la palabra `"Comida:"`. | Aprobado sustituyendo la palabra, seguido del valor y la flecha verde ascendente para indicar tasa positiva o roja descendente para tasa negativa, o guión gris para tasa neutra o cero. |
| **Botón `Energía`** | Ícono de rayo eléctrico dorado/amarillo (`⚡` estilizado, basado en `arte/dae/energy_icon.dae`) a la izquierda de las cifras de energía. | Aprobado sustituyendo la palabra por el ícono dorado/amarillo cuando se esté produciendo energía, el ícono gris cuando no y el rojo cuando se está consumiendo más energía de la que se produce. Como la energía no es un recurso que se almacena, sino que se produce una cantidad y se consume constantemente, no mostrará flechas ni tasa, sino que solo mostrará el valor disponible y el ícono del color correspondiente. |
| **Indicador `Recurso Crítico`** | Triángulo de advertencia ámbar/rojo + el **ícono dinámico del recurso** que se encuentre en estado crítico en ese momento (ej. ícono de hierro o carbón junto a su tasa). | Aprobado. |
| **Indicador `Era` (`Era 1 · Prehistórica`, etc.)** | Reloj de arena antiguo o emblema de época (fogata/piedra tallada para Era 1; columna clásica para Era 2; engranaje de vapor para Era 3). | Aprobado. Aún no desarrollamos las mecánicas de las eras, pero me parece bien ir adelantando. |
| **Indicador `Nivel Urbano` (`Nivel 1..3`)** | Corona cívica o silueta evolutiva de asentamiento (1 choza para Nivel 1, casas de piedra para Nivel 2, torres/metrópolis para Nivel 3). | Pienso que lo mejor para indicar el nivel sería poner números romanos (en imagen, no en texto) y podemos usar el mismo "ícono" de número romano para el nivel correspondiente de los edificios (en lugar de indicarlo con texto). |

---

## 4. Barra de Modos y Submenús de Vista Cenital (`BarraModos.gd`)

*Ubicada en la esquina inferior izquierda en vista cenital (`_crear_boton` ya cuenta con soporte técnico para `TextureRect` de 24×24 px).*

| Ubicación / Elemento en la UI | Sugerencia de Ícono / Imagen | Aprobación / Propuesta del Usuario |
| :--- | :--- | :--- |
| **Modo Principal: `Ver` (`Esc`)** | Ojo estilizado o cursor de flecha de selección e inspección en tono dorado/crema. | Me parece que el cursor de flecha de selección es el más apropiado. |
| **Modo Principal: `Construir` (`1`)** | Martillo y paleta de albañil (o martillo cruzado con llave/plano de construcción). | Me gusta la idea del martillo y la paleta de albañil. |
| **Modo Principal: `Zonificar` (`2`)** | Cuadrícula de terreno en perspectiva isométrica dividida en sectores de color con banderín de demarcación. | Aprobado, sin el banderín, solo la división en sectores de colores. |
| **Modo Principal: `Demoler` (`3`)** | Mazo pesado de demolición golpeando bloques (o bola de demolición / pico rompiendo ladrillos). | Me gusta el mazo pesado de demolición. |
| **Categoría Construir: `Residencial` (`1`)** | Casa acogedora con techo a dos aguas y chimenea. | Aprobado. |
| **Categoría Construir: `Periférico` (`2`)** | Pico minero cruzado con un hacha leñadora y una hoja/árbol (representando extracción en la naturaleza). | Aprobado. |
| **Categoría Construir: `Industrial` (`3`)** | Fábrica con techo dentado, dos chimeneas humeantes y un engranaje central. | Aprobado. |
| **Categoría Construir: `Investigación` (`4`)** | Birrete académico o microscopio junto a un libro abierto y átomo/engranaje. | Me gusta el microscopio con el libro. |
| **Categoría Construir: `Vías` (`5`)** | Camino empedrado o sendero que se proyecta en perspectiva hacia el horizonte. | Cuadrícula de terreno en vista isométrica, con un tramo de carretera atravesándolo de un borde al borde opuesto. |
| **Categoría Construir: `Ductos` (`6`)** | Tramo de tubería cilíndrica con bridas de unión, válvula superior y una gota de fluido. | Aprobado. |
| **Botón de Construcción: `Trazar vía` (bajo Vías)** | Actualmente es solo texto (no tiene miniatura 3D): agregar un ícono de 40×40 px mostrando un tramo de camino de tierra pisada con bordes e intersección. | Una miniatura 3D compuesta por una sección de terreno de 4x4 con un camino de tierra atravesándolo de un borde al borde opuesto (usando el overlay con la textura correspondiente, este mismo tipo de miniatura se podrá usar para los otros tipos de vía que se desarrollen más adelante). |
| **Botón de Construcción: `Acueducto` (bajo Ductos)** | Actualmente es solo texto: agregar un ícono de 40×40 px mostrando una estructura elevada de piedra/madera con canal de agua azul superior. | Una miniatura 3D de un bloque de acueducto, usando la misma textura que se usa en el juego. |
| **Botón de Construcción: `Tubería` (bajo Ductos)** | Actualmente es solo texto: agregar un ícono de 40×40 px mostrando un conducto metálico elevado sobre pilares de hierro con codo a 90°. | Una miniatura 3D de un bloque de tubería, usando la misma textura que se usa en el juego. |
| **Botones de los 19 Edificios con Miniatura 3D (`TIPOS_CON_MINIATURA`)** | *Sugerencia:* Mantener la miniatura 3D isométrica en vivo actual y añadir en la esquina superior derecha del botón un pequeño ícono de 14×14 px del recurso principal que produce o función que cumple (p. ej. tronco en Maderero, lingote en Siderúrgica, rayo en Termoeléctrica). | Me gusta la idea, pero con íconos de 18x18 px, además, en la esquina superior izquierda del botón podemos incluir una lista de íconos en vertical que indicará cuáles recursos serán necesarios para su construcción, en el el centro de la parte superior aparecerá un ícono de energía si el edificio la requiere. |
| **Botones de Paginación (`← (Z)` y `→ (X)`)** | Flechas direccionales vectoriales limpias a izquierda y derecha acompañadas del badge de tecla `Z` y `X`. | Aprobado. |
| **Submenú Zonificar: `Zona Residencial` (`1`)** | Cuadrícula verde/azul con una pequeña silueta de casa en el centro. | Aprobado. |
| **Submenú Zonificar: `Zona Industrial` (`2`)** | Cuadrícula ámbar/naranja con un pequeño engranaje o chimenea en el centro. | Aprobado. |
| **Submenú Zonificar: `Borrar` (`3`)** | Cuadrícula punteada con una goma de borrar o aspa (`✕`) limpiando el área. | Me gusta la cuadrícula punteada con un aspa. |

---

## 5. Hotbar e Indicadores de Primera Persona (`Hotbar.gd`, `PanelLampara.gd`, `HUD.gd`)

*Elementos visibles cuando el jugador controla al avatar en primera persona.*

| Ubicación / Elemento en la UI | Sugerencia de Ícono / Imagen | Aprobación / Propuesta del Usuario |
| :--- | :--- | :--- |
| **Casillas de la Hotbar (`1` a `0`: Tierra, Adobe, Madera, Piedra, Estructura, Acero, Vidrio, Puerta, Cama, Baúl)** | *Sugerencia:* Mantener el render 3D en vivo de `MiniaturaRenderer` para los bloques, ya que refleja fielmente los materiales del mundo, pero mejorar el contraste de `Vidrio` (añadiendo marco/brillo diagonal) y `Puerta` (añadiendo picaporte o bisagra visual). | Aprobado. |
| **`PanelLampara` — Lámpara Eléctrica (Encendida / Apagada)** | Ícono de linterna minera frontal o bombilla: iluminada con haz dorado cuando está encendida, y en gris apagado cuando está inactiva (sustituyendo los círculos `🟡` / `⚫`). | Adelante con el ícono de bombilla. |
| **`PanelLampara` — Lámpara Térmica (Encendida / Apagada)** | Ícono de farol de mano clásico con llama interna: brillante en naranja/ámbar cuando está encendida, y apagado en gris cuando está inactiva. | Adelante con el ícono de farol de mano. |
| **`PanelLampara` — Indicador de Batería / Combustible** | Ícono de batería con niveles de carga (y un pequeño rayo si está recargando) para el modo eléctrico; ícono de reloj de arena + ícono del recurso consumido (`carbón`, `combustible` o `crudo`) para el modo térmico. | Ícono de batería para la lámpara eléctrica y una barra de progreso que se vacíe o llene según el nivel de la batería (sustituyendo el texto del porcentaje). Para la lámpara térmica, un reloj de arena junto al tiempo restante en texto y el recurso consumido en icono (no mostrará la cantidad de recurso disponible). |
| **`_panel_oxigeno` — Indicador de Oxígeno (`Oxígeno: -X%`)** | Ícono de pulmones o conjunto de burbujas de aire ascendentes en azul cian (cambiando a rojo parpadeante cuando baja del 30%). | Aprobado el ícono de las burbujas. |
| **Mira central y Barra de Progreso de Acción (`_barra_progreso`)** | Mostrar un pequeño ícono contextual de 20×20 px a la izquierda de la barra de progreso según la acción en curso: **Pico** (minar piedra/mineral), **Pala** (cavar tierra), **Hacha** (talar árbol), **Mano/Cesta** (recolectar frutos), **Mazo** (deconstruir bloque), **Llana/Pala** (construir/demoler vía). | Adelante con el ícono de herramienta contextual. |

---

## 6. Panel Contextual Inferior (`PanelContextual.gd`)

*Tarjeta informativa central que muestra costos, estadísticas e instrucciones de control tanto en 1ª persona como en cámara cenital.*

| Ubicación / Elemento en la UI | Sugerencia de Ícono / Imagen | Aprobación / Propuesta del Usuario |
| :--- | :--- | :--- |
| **Instrucciones de Ratón (`click_izq.svg`, `click_der.svg`, `scroll.svg`)** | Ya existen y funcionan mediante BBCode `[img]`. *Sugerencia:* Añadir un ícono `mouse_move.svg` (ratón con flechas laterales) para la instrucción `(mover) RECORRER VÍA`. | Aprobado. |
| **Instrucciones de Teclado (`[Esc]`, `[E]`, `[G]`, `[V]`, `[B]`, `[Ctrl]`, `[Shift]`)** | Reemplazar los corchetes de texto plano por un estilo o ícono de **tecla física (keycap)** con borde dorado suave y letra centrada. | Aprobado. |
| **Línea de `Costo` y `Materiales de construcción`** | Antepone el **ícono de 16×16 px de cada material** antes de su cantidad y nombre (p. ej. `[🪨] 20 piedra · [🪵] 15 madera`). | Aprobado. |
| **Conteo de `Camas` y `Baúles` (previsualización de Blueprint)** | Ícono de **cama** (`🛏️` estilizado) junto al número de camas e ícono de **baúl** (`🧰`/`📦` estilizado) junto al número de baúles. | Aprobado. |
| **Estado de Validez (`Ubicación válida` / `Ubicación no válida`)** | Ícono de **check verde (`✔`)** dentro de un círculo para ubicación válida, e ícono de **cruz roja (`✖`)** o prohibido para ubicación no válida. | Aprobado. (Debe indicarse en texto el motivo por el cual no es válida la ubicación). |
| **Ficha Técnica de Vías (`Vias.ficha_tecnica`)** | Pequeños íconos de 14×14 px por línea: **Bota con alas / velocímetro** para Velocidad (`+35%`), **Rayo** para Transmisión de energía, y **Rueda / Carreta** para Tránsito vehicular. | Aprobado. |
| **Ficha Técnica de Canalizaciones (`Canalizaciones.ficha_tecnica`)** | Pequeños íconos de 14×14 px por línea: **Gota/Barril** para Fluidos admitidos, **Flecha vertical doble** para Despeje de altura (`3 bloques`), y **Pilar/Columna** para Frecuencia de soporte (`cada 5 bloques`). | Aprobado. |

---

## 7. Ventanas de Información Global (Vista Cenital)

### 7.1 Ventana de Población (`VentanaPoblacion.gd`)

| Ubicación / Elemento en la UI | Sugerencia de Ícono / Imagen | Aprobación / Propuesta del Usuario |
| :--- | :--- | :--- |
| **Encabezado `POBLACIÓN`** | Ícono de grupo de ciudadanos a la izquierda del título dorado. | Aprobado. |
| **Botón de cerrar (`X`)** | Ícono de cruz (`✕`) estilizada en dorado/crema (aplicable de manera uniforme al botón de cierre de todas las ventanas). | Aprobado. |
| **Fila `Población total`** | Ícono de censo (silueta de personas). | Aprobado. |
| **Fila `Camas construidas`** | Ícono de cama individual. | Aprobado. |
| **Fila `Sin techo: X`** | Ícono de alerta de casa tachada en color ámbar/rojo. | Aprobado. Este mismo ícono se utilizará en versión miniatura (colocado delante de la silueta de persona) para el ícono de "Estado: sin_techo" de la sección 2. |
| **Filas de desglose por oficio (`Ciudadanos`, `Obreros`, `Técnicos`, etc.)** | El ícono correspondiente a cada oficio (Sección 2) al inicio de la fila, más un pequeño punto verde para `empleados` y gris/ámbar para `desempleados`. | Aprobado. |
| **Botón `Ocupaciones`** | Ícono de maletín de herramientas o edificio con engranaje a la izquierda del texto `"Ocupaciones"`. | Aprobado el edificio con engranaje. |

### 7.2 Ventana de Ocupaciones (`VentanaOcupaciones.gd`)

| Ubicación / Elemento en la UI | Sugerencia de Ícono / Imagen | Aprobación / Propuesta del Usuario |
| :--- | :--- | :--- |
| **Encabezado `OCUPACIONES`** | Ícono de maletín/herramientas junto al título. | |
| **Cabeceras de Categoría (`Recolección`, `Industria`, `Investigación`, `Energía`)** | Flecha de despliegue vectorial (`▼` / `▶`) + el ícono de la categoría (Pico/Hacha para Recolección, Engranaje/Fábrica para Industria, Matraz/Libro para Investigación, Rayo para Energía). | Aprobado. |
| **Filas de cada puesto de trabajo** | Mini-ícono del puesto a la izquierda, ícono de trabajador junto al ratio `empleados/cupo` y un **icono de estado** a la derecha: círculo verde (activo), pausa gris (inactivo) o símbolo de pico roto / exclamación roja (agotado). | Aprobado, el ícono de estado a la derecha debe ser un ícono circular simple (8x8 px) de color verde (activo), gris (inactivo) o rojo (agotado). Incluye un ícono de ojo para indicar que al hacer clic enfoca la cámara en el puesto de trabajo correspondiente. |

### 7.3 Ventana de Almacén (`VentanaAlmacen.gd`)

| Ubicación / Elemento en la UI | Sugerencia de Ícono / Imagen | Aprobación / Propuesta del Usuario |
| :--- | :--- | :--- |
| **Encabezado `ALMACÉN`** | Ícono de cajas apiladas / bodega junto al título. | Aprobado las cajas apiladas. |
| **Filas de inventario (15 recursos)** | El **ícono de 20×20 px del recurso** (Sección 1) al inicio de cada fila + flecha diagonal ascendente verde (`↗`) si la tasa es positiva, guion neutro si es `0.0/h`, o flecha descendente roja (`↘`) si la tasa es negativa. | Aprobado. |

### 7.4 Ventana de Red Eléctrica (`VentanaEnergia.gd`)

| Ubicación / Elemento en la UI | Sugerencia de Ícono / Imagen | Aprobación / Propuesta del Usuario |
| :--- | :--- | :--- |
| **Encabezado `RED ELÉCTRICA`** | Ícono de rayo eléctrico o torre de alta tensión junto al título. | Aprobado. |
| **Indicadores de Balance Global (`Capacidad`, `Demanda`, `Balance neto`, `Cobertura`)** | Ícono de **Generador/Turbina** para Capacidad; **Bombilla/Enchufe** para Demanda; **Balanza energética (`±`)** para Balance neto; y **Escudo/Medidor circular** para Cobertura `%`. | Aprobado, cambiando el ícono de "Generador/Turbina" por una representación estilizada de una central termoeléctrica. |
| **Filas de `GENERADORES` (Centrales termoeléctricas)** | Ícono de la Central Termoeléctrica + **ícono del combustible activo** (`carbón`, `combustible` o `crudo`) + ícono de rayo junto a los `kW` generados + pequeño ícono de mira/ojo indicando que al hacer clic enfoca la cámara. | Aprobado, con el ícono de ojo. |
| **Filas de `CONSUMIDORES` (Refinerías, Universidad)** | Ícono del edificio consumidor + ícono de enchufe verde para `"Conectado"` o enchufe desconectado rojo para `"Sin conexión"`. | Aprobado. |

### 7.5 Ventana de Moral y Cohesión Social (`VentanaMoral.gd`)

| Ubicación / Elemento en la UI | Sugerencia de Ícono / Imagen | Aprobación / Propuesta del Usuario |
| :--- | :--- | :--- |
| **Encabezado `MORAL Y COHESIÓN SOCIAL`** | Ícono de corazón cívico o estandarte/laurel dorado junto al título. | Aprobado el corazón cívico. |
| **Indicador Principal de Moral** | Versión grande (32×32 px) del rostro de estado anímico actual (Crítica, Baja, Neutra, Alta). | Aprobado. |
| **Indicador `Tendencia` (`+X.XX / hora`)** | Flecha de tendencia ascendente verde, estable horizontal o descendente roja. | Aprobado, aunque cambiando la "estable horizontal" por un guión gris, para mantener la coherencia con los otro íconos indicadores de tasas. |
| **Indicador `Productividad laboral` (`X.XXx`)** | Ícono de engranaje con martillo y flecha de impulso. | Aprobado. |
| **Indicador `Migración`** | Ícono de colono con maleta entrando hacia la ciudad (verde, cuando `Moral >= 20`) o ícono de alerta con graduado/científico saliendo de la ciudad (rojo, cuando hay `Éxodo de cerebros < 20`). | Usa los íconos de la sección 2. En caso de migración positiva, un ícono de ciudadano con una flecha verde entrando a la ciudad. En caso de migración negativa, un ícono de investigador con una flecha roja saliendo de la ciudad. |
| **Factor 1: `Tendencia natural al equilibrio (50%)`** | Ícono de balanza simétrica en equilibrio. | Aprobado. |
| **Factor 2: `Variedad de alimentos (X/6 grupos)`** | Ícono de plato con cubiertos y múltiples alimentos variados (cereales, carne, pescado, fruta). | Utiliza el mismo ícono del recurso "comida". |
| **Factor 3: `Abundancia y reservas`** | Ícono de cornucopia / almacén lleno (si es estable o superávit) o plato vacío con alerta (si hay déficit o hambruna). | Utiliza una cornucopia rebosante para superávit y la misma cornucopia vacía para déficit o hambruna. |
| **Factor 4: `Ciudadanos sin techo`** | Ícono de casa sin techo / persona bajo la lluvia. | Usa el mismo ícono de "Sin Techo" de la sección 7.1. |
| **Factor 5: `Peligrosidad 7 días (bajas/robos)`** | Ícono de escudo agrietado con dos espadas o calavera de bandido. | Aprobado el ícono del escudo agrietado, pero sin espadas. |

---

## 8. Paneles de Interacción con Edificios, Puestos, Baúles y Ductos

### 8.1 Ventana de Baúl (`VentanaBaul.gd` — 1ª Persona)

| Ubicación / Elemento en la UI | Sugerencia de Ícono / Imagen | Aprobación / Propuesta del Usuario |
| :--- | :--- | :--- |
| **Encabezado `BAÚL`** | Ícono de cofre/baúl de madera con herrajes de hierro junto al título. | Aprobado. |
| **Filas de recursos (`Icono_<recurso>`)** | Activar el `TextureRect` de 20×20 px que ya existe preparado en el código asignándole el ícono correspondiente del catálogo de recursos (Sección 1). | Aprobado. |
| **Botones `-` y `+`** | Íconos vectoriales limpios de resta (`−`) y suma (`+`). | Aprobado. Considera usar los mísmos íconos de resta y suma para la asignación/remoción de personal en los paneles de edificios con puestos de trabajo. |
| **Botón `Extraer todo`** | Ícono de baúl con una flecha saliendo hacia la mochila/inventario del jugador. | Propongo usar simplemente el ícono de baúl con una flecha apuntando hacia afuera. |

### 8.2 Panel de Edificio u Obra (`PanelEdificio.gd` — Vista Cenital)

| Ubicación / Elemento en la UI | Sugerencia de Ícono / Imagen | Aprobación / Propuesta del Usuario |
| :--- | :--- | :--- |
| **Encabezado (`Núcleo urbano`, `Edificio residencial`, etc.)** | Ícono distintivo de corona/ayuntamiento para el Núcleo Urbano; ícono de casa para Residencial; ícono de andamio/grúa si está en construcción. | Aprobado el ícono de ayuntamiento para el Núcleo Urbano y el de casa para los edificios residenciales. Para las obras en construcción usa el ícono del martillo y la paleta de albañil de la sección 4. |
| **Indicadores `Camas` y `Baúles`** | Ícono de cama e ícono de baúl respectivamente. | Aprobado. |
| **Indicador `Residentes`** | Íconos pequeños de los tipos de colonos que habitan el edificio junto a su cantidad. | Aprobado. |
| **Indicador `Colonizable` y Botón `Permitir/Pausar colonización`** | Ícono de puerta abierta con flecha verde de entrada (cuando está activo) o puerta con candado/escudo temporal y reloj de arena (cuando es buffer protegido). | Aprobado el ícono de puerta abierta con flecha de entrada cuando está activo, puerta cerrada con candado cuando está protegido y puerta con reloj de arena cuando está pasando el tiempo para activarse. |
| **Indicador `Estado` y `Salud (%)`** | Ícono de martillo (en construcción), mazo (en demolición) o check (completo); e ícono de **corazón / escudo estructural** para el porcentaje de Salud. | Aprobado, pero con el ícono de martillo y paleta de albañil mientras está en construcción, el mazo para demolición, y un ícono de corazón para la salud. |
| **Indicador `Obreros` (en obra)** | Ícono de obrero con casco junto a la cantidad asignada. | Usar el mismo ícono de obrero de la sección 2. |
| **Indicador `Faltan: [materiales]`** | Íconos de los recursos faltantes junto a las cantidades requeridas y disponibles. | Usar los mismos íconos de recursos de la sección 1. |
| **Botón `Iniciar remodelación`** | Ícono de plano arquitectónico con lápiz y regla (o llave inglesa con martillo). | Aprobado, usando un ícono de llave inglesa con martillo. |
| **Botón `Pausar / Reanudar` (obra)** | Ícono de doble barra de pausa (`⏸`) o triángulo de reproducción (`▶`). | Aprobado. |
| **Botón `Prioridad: Normal / Alta / Baja`** | Ícono de bandera o chevrones de nivel: `▲▲` en dorado/rojo para Alta, `▬` en crema para Normal, `▼▼` en gris/azul para Baja. | Prefiero chevrones pero usando cantidades por nivel de prioridad: Baja `▲` azul, Normal `▲▲` verde, Alta `▲▲▲` dorado/amarillo. |
| **Botón `Demoler / Cancelar demolición`** | Ícono de mazo de demolición (o flecha de deshacer `↩` para cancelar demolición). | Aprobado. |
| **Botón `Asignar como núcleo urbano`** | Ícono de estrella cívica o edificio con bandera principal. | Usar el mismo ícono de "ayuntamiento" que se usa para el núcleo urbano en el panel del núcleo urbano, con una flecha verde apuntando hacia el ícono. |

### 8.3 Panel de Puesto, Industria y Universidad (`PanelPuesto.gd` — Vista Cenital)

| Ubicación / Elemento en la UI | Sugerencia de Ícono / Imagen | Aprobación / Propuesta del Usuario |
| :--- | :--- | :--- |
| **Encabezado del Puesto + Nivel** | Ícono representativo del edificio + estrellas o galones (`★`, `★★`, `★★★`) para representar visualmente el Nivel 1, 2 o 3 del puesto. | No usar estrellas, usaría números romanos como lo había sugerido en "Indicador Nivel Urbano" de la sección 3. |
| **Filas de Contratación (`Obreros`, `Técnicos`, `Especialistas`, `Aprendices`, `Investigadores`, `Acarreadores`)** | Antepone el **ícono del oficio** (Sección 2) a la izquierda del nombre de cada fila. | Aprobado. |
| **Selector de Combustible en Central Termoeléctrica (`[Carbón]`, `[Combustible]`, `[Crudo]`)** | Incluir dentro de cada botón el ícono de 16×16 px del recurso (`carbon`, `combustible`, `crudo`). | Aprobado. |
| **Indicador `Almacén local` y `Producción`** | Ícono de caja/depósito para Almacén local, e ícono de engranaje/flecha de salida para Producción, mostrando el ícono de cada recurso producido junto a su tasa `/h`. | Aprobado. |
| **Control `Reserva central:` (`0 / 50 / 100 / 250 / 500 u`)** | Ícono de candado o escudo de reserva junto al ícono del insumo protegido en el almacén central. | Aprobado. |
| **Indicador `Crudo restante en pozo` / `Pozo de agua`** | Ícono de barril de petróleo con medidor de nivel (para pozo de crudo) o gota de agua con símbolo de infinito `∞` (para pozo de agua). | Aprobado. |
| **Indicador `Energía` del edificio** | Ícono de rayo verde (con energía), rayo ámbar parpadeante (déficit) o enchufe desconectado rojo (sin conexión). | Utiliza el enchufe verde (Sección 7.4) para indicar que está recibiendo energía, rayo gris (Sección 3) para indicar que está conectado pero no recibe energía (déficit), y el enchufe rojo (Sección 7.4) para indicar que no está conectado a la red eléctrica. |
| **Sección Universidad — Botones de Tecnologías (`Metalurgia Aplicada`, `Automatización Industrial`)** | Ícono de **Yunque y crisol de fundición** para *Metalurgia Aplicada*; ícono de **Brazo robótico / engranajes eléctricos** para *Automatización Industrial*. Sustituir `✓`, `🔒`, `⏳` de texto por íconos vectoriales de Check verde, Candado dorado y Reloj de arena animado. | Usar un Yunque para metalurgia y un brazo robótico para automatización. Usar el check verde, candado dorado y reloj de arena animado. |
| **Sección Universidad — Controles `Pausar/Reanudar` y `Cancelar`** | Ícono de pausa/play (`⏸`/`▶`) en el botón Pausar, e ícono de cancelar/reembolso (`✕` / `↩`) en el botón Cancelar. | Aprobado. |
| **Sección `Conexiones` (Puertos de fluidos)** | Ícono de tubería en el botón desplegable `Conexiones`; íconos de `Agua`, `Crudo` y `Combustible` en cada sub-bloque; ícono de flecha entrante (`⇥`) para Entrada y flecha saliente (`⇤`) para Salida; e indicadores luminosos tipo LED industrial (verde = conectado, gris = desconectado, rojo con gota = derrame) en lugar de emojis `🟢`/`⚪`/`🔴`. | Aprobado. |
| **Indicador `Distancia al núcleo`** | Ícono de brújula o marcador de mapa con línea punteada (`📍↔🏛️`). | Me gusta el ícono de la brújula. Considera agregar la distancia al núcleo también en la ventana de información durante el emplazamiento. |

### 8.4 Panel de Canalización (`PanelCanalizacion.gd` — Vista Cenital)

| Ubicación / Elemento en la UI | Sugerencia de Ícono / Imagen | Aprobación / Propuesta del Usuario |
| :--- | :--- | :--- |
| **Encabezado (`Tubería #X` / `Acueducto #X`)** | Ícono de tubería metálica o acueducto de arcos junto al título. | Usar la miniatura correspondiente. |
| **Indicador `Recurso`** | Sustituir los emojis `💧`, `🛢️`, `⛽`, `⚪` por los íconos oficiales del catálogo de recursos (`agua`, `crudo`, `combustible`) y un ícono de tubería vacía para `"Sin fluido asignado"`. | Aprobado. |
| **Indicador `Longitud` (`X celdas, Y columnas`)** | Ícono de regla de medición horizontal junto a las celdas de ducto e ícono de columna vertical junto al conteo de pilares. | Aprobado. |
| **Indicador `Estado` de la red** | Ícono de válvula con check verde (`Conexión cerrada`), tubería abierta en ámbar (`Extremo sin conectar`) o tubería rota con chorro rojo (`Derrame activo`, sustituyendo `⚠️`). | Pienso que es mejor que en este panel haya una interfaz gráfica más ronocible, sería una línea con 3 partes: Estado de entrada: indica si el ducto está conectado a un edificio de entrada. Ícono de recurso: Muestra el recurso que está siendo transportado por ese ducto. Estado de salida: Indica si el ducto está conectado a un edificio de salida. Los "Estados" muestran un ícono verde (conectado), gris (sin conectar) o rojo (derrame) iguales a los usados en la sección 8.3. Por ejemplo: [Estado de entrada]-⇥[ícono de recurso]-⇥[Estado de salida] |
| **Botón `Demoler canalización`** | Ícono de llave de tubo / mazo desmontando una sección de tubería. | Para mantener coherencia usa el ícono del mazo. |

---

## 9. Notificaciones Emergentes y Diálogos de Confirmación

| Ubicación / Elemento en la UI | Sugerencia de Ícono / Imagen | Aprobación / Propuesta del Usuario |
| :--- | :--- | :--- |
| **Tarjetas de `PanelNotificaciones.gd` (Esquina superior derecha)** | Añadir un ícono lateral de 24×24 px a la izquierda del texto según el tipo de evento:<br>1. **Construcción / Obra finalizada:** Martillo con check verde.<br>2. **Demográfico (Nuevo colono / Éxodo):** Silueta de colono con `+` o `-`.<br>3. **Investigación completada:** Matraz / bombilla dorada.<br>4. **Rechazo / Acción inválida:** Escudo o triángulo de aviso ámbar.<br>5. **Peligro / Derrame / Hambruna:** Alerta roja intensa. | Aprobado. |
| **Diálogos Modales de Confirmación (`ConfirmationDialog` en `PanelEdificio`, `PanelPuesto`, `PanelCanalizacion`)** | Ícono de check (`✔`) en el botón de confirmación (`Confirmar` / `Investigar`) e ícono de cancelar (`✕`) en el botón `Cancelar`. En diálogos con advertencia de desahucio o costos, mostrar los íconos de cama/sin techo o de los recursos requeridos. | Aprobado. |

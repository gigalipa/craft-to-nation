# Especificación de Diseño: Iconografía Integral de la Interfaz (UI / HUD)

**Fecha:** 2026-10-16
**Fuente de verdad:** `docs/Propuesta_Iconos_UI.md` (revisado y aprobado por el usuario)

---

## 1. Dirección Artística y Técnica

1. **Formato de Íconos 2D:**
   - Archivos vectoriales **SVG** almacenados en `godot/assets/icons/`.
   - **Estilo Pixel-Art Vectorial:** Diseñados sobre retículas discretas (16×16, 20×20, 24×24 o 32×32 bloques lógicos) con `shape-rendering="crispEdges"`, integrándose de forma orgánica con la estética voxel del mundo 3D y la paleta del HUD (`TemaHUD.gd`: fondo verde oscuro `#0D211A`, marco dorado `#C79E40`, texto crema `#F2EBD1`, verde válido `#73E673`, rojo alerta `#FF5959`, ámbar `#FFA633`).
2. **Miniaturas 3D en Vivo (`MiniaturaRenderer.gd`):**
   - Se mantienen los renders 3D en vivo para las casillas de la Hotbar y los 19 edificios de construcción.
   - Se agregan renders 3D en vivo para:
     - **`Trazar vía`:** Sección de terreno de 4×4 con un camino de tierra pisada atravesándolo de un borde al opuesto.
     - **`Acueducto`:** Bloque de acueducto con su malla y textura del juego.
     - **`Tubería`:** Bloque de tubería con su malla y textura del juego.
   - Se mejora el contraste en la Hotbar para **`Vidrio`** (añadiendo marco/brillo diagonal) y **`Puerta`** (añadiendo picaporte/bisagra visual).
3. **Módulo Central (`godot/scripts/IconosHUD.gd`):**
   - Provee acceso cacheado a todas las texturas SVG (`icono(clave: String) -> Texture2D`), generación de etiquetas BBCode (`bbcode_icono(clave: String, tamano: int)`) y helpers de composición UI para botones, encabezados y filas de datos.

---

## 2. Desglose de Decisiones Aprobadas por Sección

### Sección 1: Catálogo de 15 Recursos
- `comida`: Muslo de carne junto a una espiga de trigo.
- `madera`: Troncos cilíndricos apilados con corteza marrón y anillos visibles.
- `tablas`: Tablones rectangulares de madera clara apilados en diagonal.
- `tierra`: Montículo de tierra marrón oscuro con terrones.
- `piedra`: Roca gris irregular angulosa con fragmentos.
- `bloques_piedra`: Sillares/ladrillos de piedra gris tallados y apilados.
- `hierro`: Pila de tres lingotes color gris oscuro metalizado con marcas de óxido.
- `cobre`: Pila de tres lingotes color cobrizo metalizado.
- `carbon`: Fragmentos de mineral negro brillante y facetado.
- `tierras_raras`: Drusa de cristales luminosos violeta/cian sobre base rocosa.
- `acero`: Par de lingotes metálicos pulidos color gris azulado.
- `mineral_refinado`: Prisma hexagonal pulido y brillante color turquesa/esmeralda.
- `agua`: Gota de agua cristalina azul claro con reflejo blanco.
- `crudo`: Barril metálico oscuro con una gota de petróleo crudo negro.
- `combustible`: Bidón/jerrycan rojo/ámbar con símbolo de llama.

### Sección 2: Demografía y Oficios (Siluetas Unificadas)
- `censo`: Silueta triple de personas.
- `ciudadano`: Silueta simple de una persona, sin detalles de ropa.
- `desempleado`: Misma silueta base pero con los brazos cruzados.
- `obrero` / `recolector`: Misma silueta base con casco de obra.
- `tecnico`: Misma silueta base con gafas protectoras industriales y un engranaje pequeño.
- `especialista`: Misma silueta base con un calibre de precisión.
- `investigador`: Misma silueta base con birrete y libro abierto.
- `militar`: Misma silueta base con escudo y espada cruzada.
- `aprendiz`: Misma silueta base con libro abierto y pequeña flecha ascendente.
- `acarreador`: Misma silueta base con una caja de madera.
- `sin_techo`: Misma silueta del desempleado con el ícono miniatura de casita tachada delante.

### Sección 3: Barra Superior (`BarraSuperior.gd`)
- **Población:** Ícono de silueta triple (`censo`) antes de la cifra + ícono de cama junto a la capacidad + ícono de desempleado entre paréntesis.
- **Moral:** 4 rostros pixel-art (`moral_critica`, `moral_baja`, `moral_neutra`, `moral_alta`).
- **Almacén:** Ícono de cajas apiladas a la izquierda de `"Almacén"`.
- **Comida:** Sustituye la palabra `"Comida:"` por el ícono de `comida`, seguido de `cantidad/límite` y el ícono de tendencia (`↗` verde si tasa > 0, `↘` roja si tasa < 0, `—` gris si tasa == 0).
- **Energía:** Sustituye la palabra `"Energía:"` por el ícono de rayo: **dorado/amarillo** cuando se produce energía suficiente, **gris** cuando no hay producción/demanda (0), y **rojo** cuando la demanda supera la producción (déficit). Muestra únicamente el valor disponible (`entregada/demanda`) sin flechas ni tasa por hora.
- **Recurso Crítico:** Triángulo de advertencia ámbar/rojo + ícono dinámico del recurso crítico activo + tasa.
- **Era:** Emblema de época junto al texto de la Era.
- **Nivel Urbano:** Imagen de números romanos (`I`, `II`, `III`) en lugar de texto `"Nivel X"`.

### Sección 4: Barra de Modos y Submenús (`BarraModos.gd`)
- **Modos Principales:** `Ver` (cursor de flecha de selección), `Construir` (martillo y paleta de albañil), `Zonificar` (cuadrícula isométrica dividida en sectores de color, sin banderín), `Demoler` (mazo pesado de demolición).
- **Categorías de Construir:** `Residencial` (casa con chimenea), `Periférico` (pico, hacha y hoja), `Industrial` (fábrica con chimeneas y engranaje), `Investigación` (microscopio con libro), `Vías` (cuadrícula isométrica con carretera de borde a borde), `Ductos` (tubería con bridas, válvula y gota).
- **Botones de Construcción (Edificios, Vías y Ductos):**
  - Tamaño ampliado a ~`104×76 px`.
  - Miniaturas 3D para los 19 edificios + nuevas miniaturas 3D para `Trazar vía` (terreno 4×4 con vía), `Acueducto` (bloque de acueducto) y `Tubería` (bloque de tubería).
  - **Esquina superior izquierda:** Lista vertical de íconos de `14×14 px` indicando los recursos necesarios para su construcción.
  - **Centro superior:** Ícono de energía (`14×14 px`) si el edificio requiere energía eléctrica para operar.
  - **Esquina superior derecha:** Ícono de `18×18 px` del recurso principal que produce o la función que cumple.
- **Zonas:** `Zona Residencial` (cuadrícula verde/azul con casa), `Zona Industrial` (cuadrícula ámbar con engranaje), `Borrar` (cuadrícula punteada con aspa `✕`).

### Sección 5: Hotbar e Indicadores de 1ª Persona
- **Hotbar:** Contraste mejorado en `vidrio` y `puerta`.
- **`PanelLampara.gd`:**
  - Modo eléctrico: ícono de bombilla (encendida dorada / apagada gris) + ícono de batería + `ProgressBar` que se llena o vacía según el nivel de batería (reemplazando el texto de `%`) + horas restantes.
  - Modo térmico: ícono de farol de mano (encendido con llama / apagado gris) + ícono de reloj de arena + tiempo restante en texto + ícono del recurso consumido (sin mostrar cantidad numérica del recurso).
- **Oxígeno:** Ícono de burbujas ascendentes junto al porcentaje.
- **Progreso bajo la mira (`_barra_progreso`):** Ícono de herramienta contextual de `20×20 px` a la izquierda de la barra (pico, pala, hacha, cesta, mazo, herramienta de vías).

### Sección 6: Panel Contextual (`PanelContextual.gd`)
- Ícono `mouse_move.svg` para `(mover)`.
- Estilo/ícono de tecla física (**keycap**) para `[Esc]`, `[E]`, `[G]`, `[V]`, `[B]`, `[Ctrl]`, `[Shift]`.
- Íconos de `16×16 px` para cada material en `Costo` y `Materiales de construcción`.
- Íconos de `cama` y `baul` en previsualización de blueprint residencial.
- **Distancia al núcleo** con ícono de brújula mostrada también durante el emplazamiento en cámara cenital.
- **Estado de validez:** Ícono `✔` verde (`Ubicación válida`) o `✖` rojo (`Ubicación no válida: <motivo específico>`).
- **Fichas técnicas:** Íconos de `14×14 px` en `Vias.ficha_tecnica` (velocidad, energía, tránsito) y `Canalizaciones.ficha_tecnica` (fluidos, despeje, columnas).

### Secciones 7, 8 y 9: Ventanas Globales, Paneles de Interacción y Notificaciones
- **`VentanaPoblacion.gd`:** Encabezado con grupo de personas, botón `✕`, íconos de censo, cama, casita tachada en `Sin techo`, íconos de cada oficio con punto verde (empleados) y gris/ámbar (desempleados), botón `Ocupaciones` con ícono de edificio con engranaje.
- **`VentanaOcupaciones.gd`:** Encabezado con edificio con engranaje, cabeceras con flecha `▼`/`▶` + ícono de categoría, filas de puestos con mini-ícono del puesto, ícono de trabajador, punto circular `8×8 px` (verde activo, gris inactivo, rojo agotado) e ícono de ojo para enfocar cámara.
- **`VentanaAlmacen.gd`:** Encabezado con cajas apiladas, filas con ícono de `20×20 px` del recurso y flecha de tasa (`↗` verde, `—` gris, `↘` roja).
- **`VentanaEnergia.gd`:** Encabezado con rayo, balance con íconos (central termoeléctrica estilizada para Capacidad, bombilla/enchufe para Demanda, balanza `±` para Balance, escudo para Cobertura), generadores con ícono de central + combustible activo + rayo + ojo de enfoque, consumidores con ícono del edificio + enchufe verde (`Conectado`) o enchufe rojo (`Sin conexión`).
- **`VentanaMoral.gd`:** Encabezado con corazón cívico, rostro `32×32 px`, tendencia con `↗` verde / `—` gris / `↘` roja, productividad con engranaje+martillo, migración con ciudadano+flecha verde (`>=20`) o investigador+flecha roja (`<20`), y los 5 factores (balanza, ícono de `comida`, cornucopia llena/vacía, casita tachada de `sin_techo`, escudo agrietado sin espadas).
- **`VentanaBaul.gd`:** Encabezado con baúl, `Icono_<recurso>` activado (`20×20 px`), botones `-`/`+` vectoriales, `Extraer todo` con baúl y flecha hacia afuera.
- **`PanelEdificio.gd`:** Ayuntamiento (Núcleo), casa (Residencial) o martillo+paleta (Obra); camas, baúles, residentes con íconos; colonizable con puerta abierta+flecha (activo), puerta+candado (protegido) o puerta+reloj (en cuenta regresiva); estado (martillo+paleta / mazo / check) y salud (corazón); obreros y materiales faltantes con íconos; botones con íconos (llave+martillo en remodelar, pausa/play, prioridad con chevrones `▲` azul / `▲▲` verde / `▲▲▲` dorado, mazo/deshacer en demoler, ayuntamiento+flecha verde en asignar núcleo).
- **`PanelPuesto.gd`:** Encabezado con ícono del puesto + nivel en números romanos (`I`, `II`, `III`); filas de contratación con ícono de oficio y botones `-`/`+`; selector de combustible con íconos; almacén y producción con íconos; reserva central con candado+recurso; pozo de crudo/agua con ícono; energía con enchufe verde / rayo gris / enchufe rojo; universidad con yunque (`Metalurgia Aplicada`), brazo robótico (`Automatización Industrial`), check verde, candado dorado, reloj de arena, pausa/play y cancelar; conexiones con tubería, íconos de fluido, flechas `⇥`/`⇤` y LEDs; distancia al núcleo con brújula.
- **`PanelCanalizacion.gd`:** Encabezado con miniatura 3D de tubería/acueducto; longitud con regla y columna; esquema gráfico `[Estado de entrada]-⇥[Ícono de recurso]-⇥[Estado de salida]` (con conteo si hay múltiples entradas) + lista de edificios conectados; botón demoler con mazo.
- **`PanelNotificaciones.gd` y `ConfirmationDialog`:** Ícono de `24×24 px` por categoría de notificación, e íconos `✔` / `✕` en los botones de confirmación/cancelación de los diálogos modales.

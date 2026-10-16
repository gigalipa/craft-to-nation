# Plan de Implementación: Iconografía Integral de la Interfaz (UI / HUD)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Incorporar iconografía pixel-art vectorial (`godot/assets/icons/*.svg`) y miniaturas 3D en vivo (`MiniaturaRenderer.gd`) en toda la interfaz del juego (recursos, demografía, barra superior, barra de modos y construcción con insignias de 3 esquinas, hotbar e indicadores de 1ª persona, panel contextual con motivo de ubicación inválida y distancia al núcleo, las 5 ventanas globales y los 5 paneles de interacción + notificaciones), manteniendo el 100% de la suite de 28 pruebas automatizadas en verde.

**Architecture:**
- **Catálogo central (`godot/scripts/IconosHUD.gd`):** Script `RefCounted` con carga perezosa cacheada de texturas SVG (`icono(clave: String) -> Texture2D`), generación de etiquetas BBCode (`bbcode_icono(clave: String, tamano: int = 16) -> String`), mapeos de recursos/oficios/edificios/categorías/tecnologías/estados y helpers de UI (`crear_tex_rect`, `configurar_boton_icono`).
- **Generación determinista de activos SVG (`tools/generate_ui_icons.py`):** Script Python que genera todos los archivos `.svg` en `godot/assets/icons/` sobre retícula pixel-art (`shape-rendering="crispEdges"`), garantizando consistencia de siluetas (misma base para todos los oficios) y paleta (`TemaHUD.gd`).
- **Compatibilidad de tests (`HUDTest.gd`, `PlayerLamparaTest.gd`, `CamaraCenitalModosTest.gd`):** Se preservan o amplían los métodos estáticos y nodos consultados por los tests, añadiendo verificaciones específicas para el catálogo de íconos y los nuevos componentes visuales.

**Tech Stack:** Godot 4.6 (GDScript), SVG (`shape-rendering="crispEdges"`), SubViewport 3D (`MiniaturaRenderer.gd`), Python 3 (generador de SVGs).

---

## Estructura de Líneas de Ejecución (Secuencial)

1. **Línea A — Activos SVG Pixel-Art y Catálogo Central (`IconosHUD.gd`)**
   - Generación de todos los íconos `.svg` en `godot/assets/icons/` (recursos, demografía con silueta unificada, barra superior, modos, herramientas, estados, factores de moral, energía, tecnologías, navegación).
   - Creación de `godot/scripts/IconosHUD.gd` con caché de texturas, helpers BBCode y mapeos semánticos.
2. **Línea B — Barra Superior, Barra de Modos (Miniaturas 3D + Insignias) y 1ª Persona (`BarraSuperior.gd`, `BarraModos.gd`, `MiniaturaRenderer.gd`, `Hotbar.gd`, `PanelLampara.gd`, `HUD.gd`, `Player.gd`)**
   - `BarraSuperior.gd`: íconos en Población (`censo`, `cama`, `desempleado`), Moral (4 rostros pixel-art), Almacén, Comida (ícono + flecha tasa), Energía (rayo dorado/gris/rojo + `entregada/demanda` sin flechas ni tasa), Recurso Crítico, Era y Nivel Urbano en números romanos (`I`, `II`, `III`).
   - `MiniaturaRenderer.gd` y `Hotbar.gd`: miniaturas 3D en vivo para `Trazar vía` (terreno 4×4 con vía), `Acueducto` y `Tubería`; mejora de contraste en `vidrio` y `puerta`.
   - `BarraModos.gd`: íconos en modos principales, categorías, zonas y botones de construcción ampliados (~`104×76 px`) con insignias en 3 esquinas (recursos requeridos a la izquierda, energía al centro, recurso/función producida a la derecha).
   - `PanelLampara.gd`, `HUD.gd` y `Player.gd`: `ProgressBar` e íconos en lámpara eléctrica/térmica, ícono de oxígeno y herramienta contextual junto a `_barra_progreso`.
3. **Línea C — Panel Contextual, Emplazamiento Cenital y 5 Ventanas Globales (`PanelContextual.gd`, `CamaraCenital.gd`, `Vias.gd`, `Canalizaciones.gd`, `VentanaPoblacion.gd`, `VentanaOcupaciones.gd`, `VentanaAlmacen.gd`, `VentanaEnergia.gd`, `VentanaMoral.gd`)**
   - `PanelContextual.gd` + `CamaraCenital.gd` + `Vias.gd` + `Canalizaciones.gd`: `mouse_move.svg`, estilo keycap, íconos de materiales/camas/baúles, distancia al núcleo con brújula durante emplazamiento y motivo explícito cuando la ubicación es inválida (`✖ Ubicación no válida: <motivo>`).
   - `VentanaPoblacion.gd`, `VentanaOcupaciones.gd`, `VentanaAlmacen.gd`, `VentanaEnergia.gd`, `VentanaMoral.gd`: encabezados con ícono, filas con íconos de oficios/recursos/edificios/estados/factores y botones de enfoque con ojo.
4. **Línea D — Paneles de Interacción, Notificaciones, Diálogos, Tests y Documentación (`VentanaBaul.gd`, `PanelEdificio.gd`, `PanelPuesto.gd`, `PanelCanalizacion.gd`, `PanelNotificaciones.gd`, `TemaHUD.gd`, `HUDTest.gd`, `docs/*`)**
   - `VentanaBaul.gd`, `PanelEdificio.gd`, `PanelPuesto.gd`, `PanelCanalizacion.gd` (con esquema `[Estado de entrada]-⇥[Ícono de recurso]-⇥[Estado de salida]`), `PanelNotificaciones.gd` y `TemaHUD.gd`.
   - Actualización de `HUDTest.gd` y ejecución completa de `tools/run-godot-tests.ps1` (28/28 escenas).
   - Actualización de documentación (`GDD`, `README.md`, `Pendientes y próximos pasos.md`, `Verificaciones_en_vivo.md`, `Live_Verifications.md`).

---

### Task 1 (Línea A): Generación de SVGs Pixel-Art y `IconosHUD.gd`

**Files:**
- Create: `tools/generate_ui_icons.py`
- Create: `godot/assets/icons/*.svg` (~85 íconos pixel-art en retícula 16×16 / 24×24 con `shape-rendering="crispEdges"`)
- Create: `godot/scripts/IconosHUD.gd`

- [ ] **Step 1: Crear y ejecutar `tools/generate_ui_icons.py`** para generar todos los archivos `.svg` aprobados en `docs/Propuesta_Iconos_UI.md` dentro de `godot/assets/icons/` (preservando `click_izq.svg`, `click_der.svg` y `scroll.svg`).
- [ ] **Step 2: Implementar `godot/scripts/IconosHUD.gd`** con:
  - Diccionario de rutas y caché de `Texture2D`.
  - `static func icono(clave: String) -> Texture2D`
  - `static func ruta_icono(clave: String) -> String`
  - `static func bbcode_icono(clave: String, tamano: int = 16) -> String`
  - Mapeos: `icono_recurso(recurso)`, `icono_oficio(oficio)`, `icono_edificio(id_edificio)`, `icono_herramienta(accion)`, `icono_nivel_romano(nivel)`, `icono_flecha_tasa(tasa)`.
- [ ] **Step 3: Importar activos en Godot headless y verificar carga sin errores.**

---

### Task 2 (Línea B): Barra Superior, Barra de Modos, Miniaturas 3D y 1ª Persona

**Files:**
- Modify: `godot/scripts/MiniaturaRenderer.gd`
- Modify: `godot/scripts/Hotbar.gd`
- Modify: `godot/scripts/BarraSuperior.gd`
- Modify: `godot/scripts/BarraModos.gd`
- Modify: `godot/scripts/PanelLampara.gd`
- Modify: `godot/scripts/HUD.gd`
- Modify: `godot/scripts/Player.gd`

- [ ] **Step 1: Ampliar `MiniaturaRenderer.gd` y `Hotbar.gd`**
  - Añadir `generar_miniatura_via()`, `generar_miniatura_acueducto()` y `generar_miniatura_tuberia()` en `MiniaturaRenderer.gd`.
  - Mejorar contraste de `vidrio` (marco más visible y reflejo diagonal) y `puerta` (picaporte dorado y bisagras oscuras) en la miniatura de bloque.
- [ ] **Step 2: Actualizar `BarraSuperior.gd`**
  - Incorporar íconos en los botones/etiquetas de `poblacion` (`censo`, `cama`, `desempleado`), `moral` (`moral_critica` / `moral_baja` / `moral_neutra` / `moral_alta`), `almacen` (`almacen`), `comida` (ícono `comida` reemplazando `"Comida:"` + `cantidad/límite` + flecha de tendencia), `energia` (ícono `energia_dorado` / `energia_gris` / `energia_rojo` reemplazando `"Energía:"` + `entregada/demanda` sin flechas ni tasa), `critico` (advertencia + ícono del recurso crítico), `era` (`era`) y `nivel` (`romano_1` / `romano_2` / `romano_3`).
- [ ] **Step 3: Actualizar `BarraModos.gd`**
  - Añadir íconos a botones principales (`Ver`, `Construir`, `Zonificar`, `Demoler`), categorías (`Residencial`, `Periférico`, `Industrial`, `Investigación`, `Vías`, `Ductos`) y zonas (`Zona Residencial`, `Zona Industrial`, `Borrar`).
  - Ampliar botones de construcción a `104×76 px`, asignar miniaturas 3D a `Trazar vía`, `Acueducto` y `Tubería`, y superponer las insignias en las 3 esquinas:
    - Superior izquierda: lista vertical de íconos `14×14 px` de recursos de construcción.
    - Superior centro: ícono de energía `14×14 px` si el edificio/vía consume energía.
    - Superior derecha: ícono `18×18 px` del recurso producido o función principal.
- [ ] **Step 4: Actualizar `PanelLampara.gd`, `HUD.gd` y `Player.gd`**
  - En `PanelLampara.gd`: añadir ícono de bombilla/farol, ícono de batería + `ProgressBar` en modo eléctrico (reemplazando el `%` en texto) + horas restantes, e ícono de reloj de arena + tiempo restante + ícono del recurso en modo térmico (sin cantidad numérica del recurso).
  - En `HUD.gd` y `Player.gd`: añadir ícono de burbujas en `_label_oxigeno` e ícono de herramienta contextual (`20×20 px`) a la izquierda de `_barra_progreso`.

---

### Task 3 (Línea C): Panel Contextual, Emplazamiento y 5 Ventanas Globales

**Files:**
- Modify: `godot/scripts/PanelContextual.gd`
- Modify: `godot/scripts/CamaraCenital.gd`
- Modify: `godot/scripts/Vias.gd`
- Modify: `godot/scripts/Canalizaciones.gd`
- Modify: `godot/scripts/VentanaPoblacion.gd`
- Modify: `godot/scripts/VentanaOcupaciones.gd`
- Modify: `godot/scripts/VentanaAlmacen.gd`
- Modify: `godot/scripts/VentanaEnergia.gd`
- Modify: `godot/scripts/VentanaMoral.gd`

- [ ] **Step 1: Actualizar `PanelContextual.gd`, `CamaraCenital.gd`, `Vias.gd` y `Canalizaciones.gd`**
  - Añadir `mouse_move.svg` para `(mover)` y formato keycap para teclas (`[Esc]`, `[E]`, etc.).
  - En emplazamiento cenital (`CamaraCenital.gd` + `PanelContextual.gd`): mostrar distancia al núcleo con ícono de brújula, íconos de materiales/camas/baúles, y estado de validez con `✔ Ubicación válida` o `✖ Ubicación no válida: <motivo específico>` (terreno ocupado, fuera de rango del núcleo, pendiente/desnivel inválido, requiere ribera/yacimiento, etc.).
  - Incluir íconos en `Vias.ficha_tecnica()` y `Canalizaciones.ficha_tecnica()`.
- [ ] **Step 2: Actualizar las 5 ventanas globales (`VentanaPoblacion.gd`, `VentanaOcupaciones.gd`, `VentanaAlmacen.gd`, `VentanaEnergia.gd`, `VentanaMoral.gd`)**
  - `VentanaPoblacion.gd`: ícono en título, botón `✕`, íconos de `censo`, `cama`, `sin_techo` y cada oficio con indicador empleado/desempleado, e ícono en botón `Ocupaciones`.
  - `VentanaOcupaciones.gd`: ícono en título, flechas `▼`/`▶` + ícono de categoría, filas con mini-ícono del puesto, ícono de trabajador, punto de estado (`8×8 px` verde/gris/rojo) e ícono de ojo en botón de enfoque.
  - `VentanaAlmacen.gd`: ícono en título, ícono `20×20 px` de cada uno de los 15 recursos y flecha de tasa (`↗` verde, `—` gris, `↘` roja).
  - `VentanaEnergia.gd`: ícono en título, íconos en resumen de balance (central termoeléctrica, demanda, balanza, escudo de cobertura), generadores con ícono + combustible + rayo + ojo, y consumidores con ícono del edificio + enchufe verde/rojo + ojo.
  - `VentanaMoral.gd`: ícono de corazón cívico en título, rostro `32×32 px` según moral, flecha de tendencia, productividad con engranaje+martillo, migración (`ciudadano`+flecha verde vs `investigador`+flecha roja) e íconos de los 5 factores (balanza, `comida`, cornucopia llena/vacía, casita tachada `sin_techo`, escudo agrietado sin espadas).

---

### Task 4 (Línea D): Paneles de Interacción, Notificaciones, Tests y Documentación

**Files:**
- Modify: `godot/scripts/VentanaBaul.gd`
- Modify: `godot/scripts/PanelEdificio.gd`
- Modify: `godot/scripts/PanelPuesto.gd`
- Modify: `godot/scripts/PanelCanalizacion.gd`
- Modify: `godot/scripts/PanelNotificaciones.gd`
- Modify: `godot/scripts/TemaHUD.gd`
- Modify: `godot/scripts/HUDTest.gd`
- Modify: `godot/scripts/PlayerLamparaTest.gd`
- Modify: `docs/Documento de diseño del juego (GDD) - Proyecto Ciudad-Estado.md`
- Modify: `README.md`
- Modify: `docs/Pendientes y próximos pasos.md`
- Modify: `docs/Verificaciones_en_vivo.md`
- Modify: `docs/Live_Verifications.md`

- [ ] **Step 1: Actualizar `VentanaBaul.gd`, `PanelEdificio.gd`, `PanelPuesto.gd`, `PanelCanalizacion.gd`, `PanelNotificaciones.gd` y `TemaHUD.gd`**
  - `VentanaBaul.gd`: activar `Icono_<recurso>` (`20×20 px`) con la textura de `IconosHUD`, ícono de baúl en encabezado, `-`/`+` e ícono en `Extraer todo`.
  - `PanelEdificio.gd`: íconos de encabezado (Ayuntamiento / Residencial / En construcción), camas, baúles, residentes, los 3 estados de colonizable (puerta abierta+flecha, puerta+candado, puerta+reloj), estado/salud, obreros, materiales e íconos en botones de acción (remodelar, pausar/reanudar, prioridad con chevrones `▲`/`▲▲`/`▲▲▲`, demoler/cancelar, asignar núcleo urbano).
  - `PanelPuesto.gd`: ícono del edificio + nivel en números romanos (`I`, `II`, `III`), oficios en contratación, selector de combustible con íconos, almacén/producción/reserva/pozo con íconos, estado energético (enchufe verde / rayo gris / enchufe rojo), tecnologías de universidad (yunque y brazo robótico + estados), conexiones hidráulicas y distancia al núcleo con brújula.
  - `PanelCanalizacion.gd`: miniatura 3D de tubería/acueducto en título, regla y columna en longitud, esquema gráfico `[Estado de entrada]-⇥[Ícono de recurso]-⇥[Estado de salida]` (con conteo si hay múltiples entradas) + lista de edificios conectados, e ícono de mazo en demoler.
  - `PanelNotificaciones.gd` y `TemaHUD.gd`: ícono `24×24 px` por categoría de notificación e íconos `✔` / `✕` en diálogos de confirmación.
- [ ] **Step 2: Actualizar `HUDTest.gd` y `PlayerLamparaTest.gd` y ejecutar `tools/run-godot-tests.ps1`**
  - Verificar que las 28 escenas de test pasen al 100%.
- [ ] **Step 3: Actualizar documentación del proyecto** (`GDD`, `README.md`, `Pendientes y próximos pasos.md`, `Verificaciones_en_vivo.md`, `Live_Verifications.md`).

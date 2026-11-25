---
title: "Hoja de Ruta y Estado del Desarrollo (GDD v3.64)"
description: "Estado técnico del desarrollo de Craft to Nation: fases 0 a 7, progreso detallado de la Fase 3 (Industria y Recursos) e hitos verificados."
---

# Hoja de Ruta (Roadmap) y Estado del Desarrollo (GDD v3.64)

![Vista táctica de defensa y expansión urbana](/assets/comparison-aerial.webp)

La evolución técnica de **Craft to Nation** sigue el plan de 7 fases definido en la **Sección 11 del GDD v3.64** y el protocolo de verificación en vivo ([`docs/Live_Verifications.md`](https://github.com/gigalipa/craft-to-nation)), sustentado en **39 escenas de prueba automatizadas al 100 % en verde**.

---

## 1. Resumen de las 7 Fases del Proyecto

```
[Fase 0: Lógica Pura (PoC 1 & PoC 2)] ──────────────────────────────────> COMPLETADA ✅
[Fase 1: Prototipo Visual 1ra Persona y Validación de Volumen (PoC 3)] ─> VERIFICADA ✅
[Fase 2: Ciudad, Demografía, Zonificación y Colonos NPC (PoC 4 & 8)] ───> COMPLETA ✅
[Fase 3: Mundo 200×200, Industrias, Fluidos, Moral, HUD y Audio SFX] ──> COMPLETADA ✅
[Fase 4: Cámara Dual, Cuartel Militar y Comando Híbrido (PoC 7)] ───────> COMPLETADA ✅
[Fase 5: Logística Avanzada, Carretas, Ferrocarril y Puentes (PoC 8–10)]> SIGUIENTE HITO ⏳
[Fase 6: Combate, Asedios, IA Enemiga y Sucesión de Avatar] ────────────> PLANIFICADA ⏳
[Fase 7: Multijugador LAN y Soberanía Portátil de Núcleos] ─────────────> HORIZONTE FUTURO 🚀
```

---

## 2. Hitos Completados (Fases 0 a 3 — GDD v3.64)

### Fase 0 y Fase 1: Motor Vóxel, Avatar en Primera Persona y Validación Volumétrica
- [x] Mundo procedural finito de **200×200 celdas** (`GeneradorMundo.gd`) con altura máxima `y = 130`, **24 capas de subsuelo** hasta la roca madre (`bedrock`), 2 picos montañosos, ríos con corriente y cascadas, lagos y mares.
- [x] Avatar en primera persona (`Player.gd`) con minado por barra de progreso e icono contextual (`herr_pala`, `herr_pico`, `herr_hacha`), recolección de frutos silvestres manteniendo <kbd>E</kbd> (`60 u` en `2,0 s`), natación en líquidos profundos (`>= 2` bloques) con barra de oxígeno (`10,0 s`), drenaje de líquidos con bloques sólidos (<kbd>Clic Derecho</kbd>), modo de deconstrucción a pie (<kbd>G</kbd>) y lámpara omnidireccional (<kbd>L</kbd>) en modo **Térmico** (`Combustible 10h`, `Carbón 6h`, `Madera 5h`) y **Eléctrico** (`Batería 72h` con recarga `+7,2 h/tick`).
- [x] Reconocimiento volumétrico de edificios herméticos (`BlueprintValidator.gd`), puertas 3D con pomo de bronce y bisagras, declaración (<kbd>B</kbd>) y remodelación no destructiva (<kbd>Shift</kbd> + <kbd>B</kbd>).

### Fase 2: Fundación Cívica, Cámara Cenital y Demografía
- [x] Cámara cenital táctica (`CamaraCenital.gd`) con vuelo suave de transición (`0,6 s` con <kbd>C</kbd>), menú numérico jerárquico (`1` Construir, `2` Zonificar, `3` Demoler) con navegación y paginación <kbd>Z</kbd> / <kbd>X</kbd>, rotación `Ctrl + Rueda` y hasta 5 *blueprints* residenciales.
- [x] Ciclo residencial completo: 1er edificio funda el **Núcleo Urbano**, 1ra Residencia nace con `Colonizable: SÍ`, 2da Residencia en adelante nace como buffer `Colonizable: NO (24 h)`, casas adosadas pared con pared y reubicación del Núcleo Urbano (`5 h`).
- [x] Cadena académica estricta en Zona Residencial (`1 -> 4 -> 1..3`): `Escuela técnica` (`24 h` → 3 Técnicos) → `Escuela de especialistas` (`48 h` → 2 Especialistas) → `Universidad` interactiva con inicio manual, pausa y cancelación con reembolso del 100 %.

### Fase 3: Industrias, Fluidos, Moral Dinámica, Iconografía HUD, IDU, Vidriera, Transporte y Audio SFX (v3.56 – v3.61)
- [x] **Puestos Periféricos (`1 -> 2 -> 1..6`):** Caza, Maderero, Mina (prof. 8/16/24), Pesca, Estación de Bombeo (`>= 2` bloques de agua) y Centro de Extracción (columna física de perforación) con insignias romanas `I–III`, regla del rango mínimo de trabajadores y ventana `VentanaBaul` (<kbd>E</kbd>).
- [x] **Red Vial (`1 -> 5 -> 1`), Modo a Pie (<kbd>V</kbd>) y Demolición Guiada (<kbd>3</kbd>):** Construcción progresiva por colonos (`ViaObraOverlay`), intervención a pie en secciones `2×2` (<kbd>V</kbd>), demolición guiada en naranja alrededor de esquinas de 90° mediante Dijkstra (<kbd>3</kbd>) y jerarquía global de 5 niveles de prioridad de obra.
- [x] **Instalaciones Industriales y Energéticas (`1 -> 3 -> 1..10`):** Siderúrgica, Tierras Raras, Aserradero, Fábrica de Bloques, **Vidriera** (`1-3-5`, `5×6` adobe: `1 Tierra + 1 Carbón → 3 Vidrio`), Carbonera (`1-3-6`), Refinería Petrolera (`1-3-7`, `400/600`), Productor de Combustible (`1-3-8`), Central Termoeléctrica (`1-3-9`, selector `[Carbón]`/`[Combustible]`/`[Crudo]`), Taller de Transporte y Almacén Industrial (`6` puertos de fluidos en `Y = 4`), con selector de **`Reserva central:` porcentual (`0% / 10% / 20% / 30% / 40% / 50%`)** mediante botones subir/bajar (`▲`/`▼`).
- [x] **Canalizaciones Elevadas (`1 -> 6 -> 1..2`):** Acueductos y tuberías en `Y + 4` (pilares cada 5 bloques), cruces a desnivel entre dos conductos en **`Y + 6`** (`1` bloque de aire libre en `Y + 5`), derrames físicos (`🔴 Derrame`) con viscosidad `0,20` y reconexión desde columna.
- [x] **Moral Dinámica y `VentanaEnergia` con Teletransporte de Cámara:** Tasa diaria (`/día`), 3 regímenes migratorios escalonados (`<= 20%` éxodo, `20–50%` con camas, `> 50%` masiva), `VentanaMoral` compactada con estado de migración bajo productividad laboral, y vuelo suave (`Tween`) al hacer clic sobre edificios en `VentanaEnergia`.
- [x] **Iconografía Vectorial HUD y Miniaturas 3D (v3.57):** Más de **90 iconos SVG pixel-art** (`IconosHUD.gd`, incluyendo `vidrio.svg`, `romano_1.svg`–`romano_4.svg`, `btn_subir.svg`, `btn_bajar.svg`), miniaturas 3D en vivo (`MiniaturaRenderer.gd`) y botones de `104×76 px` con insignias en 3 esquinas.
- [x] **Arquitectura de Centralización y Textos Reactivos (v3.58):** Desacoplamiento de constantes y parámetros en `ajustes.gd` con soporte para manipulación en caliente y personalización por partida («Nueva partida»), catálogo multi-idioma en `strings.gd` con getters estáticos reactivos, y calibración de la tabla de migración escalonada (9 tramos, boost 2.5× por 30 días y fuga de cerebros).
- [x] **Evolución de Eras, IDU (`I`–`IV`), Investigación en 2 Capas, Transporte y Ventanas `1/20` (v3.61):** Indicador superior de nombre + ícono de Era e ícono romano del IDU redondeado (`I`–`IV`) con ventana tooltip bajo la barra de estado al hacer hover; investigación descentralizada en 2 capas (Universidad Teórica + Aplicaciones Prácticas con **Investigador Itinerante**); Taller de Transporte con 6 unidades móviles (`acarreador_pie`, `carreta_mano`, `carro_caballos`, `camion_diesel`, `trolebus_solar`, `dron_carga`, exigencia de vía y cabinas con `vidrio`); bloques de ventana (`TranslucidosRenderer.gd`) rediseñados como paneles transparentes de `1/20` (`0,05 m`) en 3 variantes (`ventana` recta a media profundidad orientada al avatar, `ventana_esquina` en L y `ventana_techo` al ras de la cara superior `Y ∈ [0,95, 1,0]` al mirar arriba/abajo) que consumen preferentemente `1 Vidrio` (o `3 Tierra`); `VentanaAlmacen` con desplegables jerárquicos y botón `[Expandir todo]`/`[Contraer todo]`; y `PanelEdificio` con flechas de prioridad (`▲`/`▼`), transición automática de panel al completar el 100 % y drenaje automático de agua interior.
- [x] **Saneamiento de Herramientas de 1ª Persona al Alternar Cámaras (2026-10-28):** Desactivación incondicional de herramientas en 1ª persona (`Player.salir_de_todas_las_herramientas()`) al pasar a cámara cenital (`Main._alternar_camara_cenital()`), reseteando `modo_deconstruccion`, `modo_vias` y estados temporales de minado y colocación. Las 35 escenas de prueba de Godot se mantienen al 100% en verde.
- [x] **Infraestructura Comunitaria, CI/CD y Subtítulos Modernos en Remotion (2026-10-31):** Adopción del Código de Conducta (`CODE_OF_CONDUCT.md`), workflows de GitHub Actions (`.github/workflows/ci.yml` para validación de Python, TypeScript y auditoría de higiene), plantillas de incidencias y pull requests, configuración de Dependabot; y modernización del renderizado de subtítulos en Remotion (`VerticalShort.tsx`) a cápsulas de alto contraste (blanco bold 58px sobre cápsula negra obsidiana). Las 28 suites de prueba permanecen al 100% en verde.
- [x] **Resolución Integral de Incidencias de QA y Pulido de Simulación (2026-11-03):** Persistencia y rotación de orientaciones 3D en blueprints (`BlueprintValidator.gd`, `VoxelWorld.gd`) para ventanas de techo y bloques orientables, tramos de migración acelerados para moral sobresaliente (≤ 75 → +5,0, ≤ 90 → +7,0, ≤ 100 → +10,0 colonos/mes), reasignación inmediata de cuadrillas por prioridad de obras, confirmación temporal en demoliciones de vías/edificios y saneamiento de estados demográficos al desahuciar. Las 28 suites de prueba permanecen al 100% en verde.
- [x] **Motor de Audio Espacial, Catálogo Integral de SFX y Exportación Windows (2026-11-06 — v3.60):** Integración del autoload singleton `Sonidos.gd` con pools circulares de 16 reproductores 2D y 16 reproductores 3D con atenuación inversa hasta 35m y pitch modulation de ±5%; catálogo de 102 efectos de sonido en 8 familias funcionales (`locomocion`, `herramientas`, `mobiliario`, `colonos`, `industrias`, `fluidos`, `urbanismo`, `ui`); pipeline de exportación standalone de Windows (`tools/export_windows.ps1` con icono oficial `godot/icon.png`); y suite de pruebas unitarias `SonidosTest.tscn`. Las 35 escenas de prueba de Godot se mantienen al 100% en verde.
- [x] **Menú de Inicio, Guardado Atómico de Partidas, Menú de Pausa (F11), BGM y Configuración Persistente (2026-11-07 — v3.61):** Escena principal de inicio `MenuInicio.tscn` con fondo dinámico tipo slideshow (`SlideshowFondo.gd`) y música de menú (`The_Architect_s_Decree`), singleton autoload `GestorPartida.gd` para serialización y carga atómica en `user://saves/` con ranura de guardado rápido (`quicksave.json`) y metadatos, menú de pausa contextual en juego `MenuPausa.gd` con tecla <kbd>F11</kbd> y ajuste en caliente, singleton `Configuracion.gd` con persistencia de preferencias (SFX, BGM, sensibilidad, FOV, idioma) en `user://configuracion.json`, pantalla de carga `PantallaCarga.gd` y suite de pruebas unitarias extendida a 35 escenas limpias al 100% en verde.
- [x] **Sistema Dinámico de Localización Multilingüe (ES/EN) y Reactividad de Traducción (2026-11-09 — v3.61):** Integración completa del catálogo de traducción al inglés `_DATOS_EN` en `strings.gd`, resolución de claves y cadenas estáticas con fallback dinámico a español mediante `Strings.t(clave, default)`, conmutación de idioma en caliente vía `Strings.actualizar_idioma("es"|"en")` vinculado reactivamente a `Configuracion.establecer_idioma()`, actualización sincronizada de nombres de recursos en el almacén central de `Ciudad`, alias en inglés para el catálogo vectorial de `IconosHUD.gd` (`wood`, `food`, `census`), actualización bilingüe de textos en `BarraSuperior.gd`, `Hotbar.gd`, `PantallaCarga.gd`, `MenuInicio.gd`, `MenuPausa.gd` y `PanelConfiguracionAjustes.gd`, y cobertura de pruebas automatizadas en `ConfiguracionTest.gd`. Las 35 escenas de prueba se ejecutan al 100% en verde.
- [x] **Tránsito por Carril Derecho en Vías según Huella, Video Intro Cinemático, Perfiles de Recursos y Suite de 36 Escenas (2026-11-10 — v3.61):** Regla geométrica de borde derecho `r = (-dz, dx)` en vías (`Vias.es_borde_derecho()`) y penalización de carril izquierdo en A* (`VIAS_PENALIZACION_CARRIL_IZQUIERDO = 4` en `BuscadorRutas.gd`) que asigna carriles independientes según sentido de marcha y huella física (`Vector2i` en `TRANSPORTE_CATALOGO_UNIDADES`), eliminando colisiones frontales y permitiendo esquivas si el carril derecho se bloquea; escena cinemática de arranque `VideoIntro.tscn` con reproducción de logo animado, salto con tecla/clic y paso a `MenuInicio.tscn`; selector y perfiles de recursos iniciales (`supervivencia`, `bajos`, `medios`, `altos`) por categorías en `Configuracion.gd` y `ajustes.gd`; y suite ampliada a 36 escenas de prueba automatizadas con `VideoIntroTest.tscn` ejecutándose al 100% en verde.


---


### Fase 4: Cámara Dual, Cuartel Militar, Selección Táctica Universal, Modos T/R/F y Comando Híbrido (v3.64)
- [x] **Edificio Militar Cuartel (`9×7×8`, Zona B, tecla `7`) y Cohorte Militar 4→4:** Estructura de 2 pisos con piedra, madera, vidrio y 4 camas que recluta atómicamente 16 soldados (4 por cama) en `Economia.gd`/`Recoleccion.gd` sin restar camas ni colonos a la vivienda civil.
- [x] **Vivienda Militar Acuartelada (`x_cama = 4`):** Gestión segregada de vivienda militar en `Ciudad.gd` y `ajustes.gd` con censo militar propio para evitar desahucios civiles.
- [x] **Selección Universal en Cámara Cenital (`CamaraCenital.gd`):** Recuadro de arrastre 2D con selección individual o grupal tanto de soldados como de colonos, filtrado cívico/militar y memoria de selección persistente entre cámaras.
- [x] **Panel de Unidad y Órdenes Tácticas (`PanelUnidad.gd` y `Colonos.gd`):** Inspección de salud, oficio y posturas (`Pasivo`, `Defensivo`, `Agresivo`). Emisión de órdenes (`Moverse`, `Atacar` con <kbd>K</kbd>, `Defender`, `Patrullar`, `Mantener` con <kbd>H</kbd>) con clic derecho y waypoints con <kbd>Shift</kbd>.
- [x] **Modos Especializados de Primera Persona (`Player.gd`):** Modo Construcción (<kbd>T</kbd>), Modo Batalla (<kbd>R</kbd> con espada, arco y retícula crosshair) y Modo Comandante (<kbd>F</kbd> con hotbar 1–6 de órdenes y subgrupos tácticos <kbd>Shift</kbd> + <kbd>1..9</kbd>).
- [x] **Visuales Procedurales de Tropas (`ColonosRenderer.gd`):** Cascos, escudos, aros de selección en base y waypoints tácticos.
- [x] **Selector Persistente de Modo Pantalla (`Configuracion.gd`):** Modo pantalla completa y modo ventana (1280×720) persistente en `user://configuracion.json`.
- [x] **Suite Automatizada Extendida a 37 Escenas:** Nueva suite `PlayerCombateComandanteTest.tscn` elevando la cobertura a 39 escenas automatizadas ejecutándose al 100% en verde.
- [x] **Director de Música Adaptativa Contextual (OST de 16 pistas), Hardening de Guardado/Carga y Botón «¿Cómo jugar?» (2026-11-20 a 2026-11-22 — v3.64):** Director musical reactivo en `Sonidos.gd` sobre 16 pistas OST (`menu`, `exploration`, `building`, `industry`, `battle`) con crossfade de doble reproductor (`3,0 s` ambiental / `0,8 s` combate), histéresis (`4,0 s` / `15,0 s`), shuffle bag y `Menu & Loading Theme` unificado en menú y carga (`PantallaCarga.gd`); hardening de serialización/parseo de `Vector2i`/`Vector3i` y reconstrucción visual `ColonosRenderer.reconstruir()` en `GestorPartida.gd`/`Colonos.gd`/`Economia.gd`/`VoxelWorld.gd`; botón «¿Cómo jugar?» a la Wiki oficial en `MenuInicio.gd`, logging persistente (`user://logs/craft_to_nation.log`) y viewport `1920×1080` con override `1280×720`.
- [x] **Avatar 3D Riggeado, Personajes Modulares 3D y Bloqueo Cenital en Riesgo (2026-11-23 a 2026-11-25 — v3.64):** Reemplazo de la cápsula del jugador por `avatar.glb` (`SkeletonProfileHumanoid`, `BoneAttachment3D` en manos y `SkeletonModifier3D` para 1ª persona) con 47 animaciones en `AvatarAnimador.gd`; arquitectura *drop-in* plug-and-play (`CatalogoPersonajes.gd` + `PersonajeModular.gd` en `ColonosRenderer.gd`) con 2 capas (atuendo + equipamiento rígido), 4 tonos de piel (`mat_piel`), color de equipo (`mat_color_equipo`) y sucesión filtrada por género con seguro anti-bloqueo en `Ciudad.suceder_avatar()`; bloqueo de cámara cenital ante daño (`5,0 s`), natación profunda (`>= 2` bloques) o caída (`Player.motivo_bloqueo_cenital()`); pipeline 3D en `tools/3d_pipeline/`; y suite ampliada a 39 escenas en verde (`AvatarAnimadorTest.tscn` y `PersonajeModularTest.tscn`).

---

## 3. Próximas Fases (Fases 5 a 7)

| Fase | Enfoque del Hito | Sistemas Clave |
| :--- | :--- | :--- |
| **Fase 5 (PoC 8–10)** | **Logística Avanzada y Sistema de Puentes** | Carretas de carga terrestre, puentes modulares sobre ríos/cañones y líneas ferroviarias. |
| **Fase 6** | **Combate, Asedios, IA y Sucesión de Avatar** | Campamentos enemigos procedurales, incursiones a puestos periféricos, murallas y sucesión del avatar tras baja (`K` o ahogamiento). |
| **Fase 7** | **Multijugador LAN y Núcleos Portátiles** | Exportación del Núcleo Urbano y catálogo de *blueprints* hacia partidas multijugador competitivas y cooperativas. |

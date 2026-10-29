---
title: "Arquitectura Técnica en Godot & PoCs"
description: "Arquitectura técnica en Godot: autoloads de Ciudad y Avatar, GridMap 3D, generador procedural de terreno, físicas de fluidos y 28 suites de pruebas automatizadas."
---

# Arquitectura Técnica en Godot 4.7 & PoCs

![Interfaz de construcción en primera persona y mundo vóxel](/assets/hud-primera-persona-construccion.png)

El desarrollo de **Craft to Nation** está construido en **Godot 4.7** (`GDScript`), empleando una arquitectura desacoplada donde la lógica pura de simulación (`RefCounted` y `Autoloads` sin `class_name` global para evitar colisiones de caché) avanza en ticks deterministas independientes de los cuadros por segundo (*framerate*).

---

## 1. Arquitectura Temporal y Bucle de Simulación

El motor divide su ejecución en dos capas temporales simultáneas:

```
[Render, Físicas del Avatar y Agentes NPC] ──> 60 / 120 FPS continuos (_process / _physics_process)
                                                        │
[Bucle Macro de Simulación (Ciudad/Economia)] ──> Tick discreto: 2,0 segundos reales = 1 hora de juego
                                                  • Consumo metabólico de colonos y avatar
                                                  • Extracción física de bloques en puestos
                                                  • Procesamiento de lotes en refinerías y energía
                                                  • Conducción de fluidos y nivelación por gravedad
                                                  • Cálculo de moral diaria (/24.0) y migración mensual
```

### El Sistema de Ticks (`Ciudad.gd` y `Economia.gd`)
- **Duración del Tick (`SEGUNDOS_POR_TICK`):** **2,0 segundos** de tiempo real equivalen exactamente a **1 hora** de tiempo simulado dentro del juego (`24 ticks = 1 día = 48 s reales`; `720 ticks = 1 mes = 24 min reales`).
- **Relación con el Ciclo Estándar de Balance:** **1 ciclo estándar (`60 s` reales)** equivale a **30 horas de juego**.
- **Mundo Vóxel Finito (`200×200` celdas):** Generado por `GeneradorMundo.gd` sobre un `GridMap` tridimensional con altura máxima `y = 130`, **24 capas de subsuelo** hasta la roca madre (`bedrock`) indestructible, 2 picos montañosos, 6 minerales, yacimientos profundos de crudo, ríos con corriente y cascadas, lagos y mares.

---

## 2. Mapa de Scripts y Autoloads Reales (`godot/scripts/`)

### Autoloads de Estado y Simulación
- **`Ciudad.gd`:** Censo demográfico (`TIPOS_POBLACION`), almacén central (`Ciudad.almacen`) con las 6 categorías de comida y el recurso procesado `vidrio`, niveles urbanos y de desarrollo `I–IV` (`NIVELES_VIVIENDA`, balanza de 3 pilares **D/C/S** e indicador `IDU`), investigación descentralizada en 2 capas (Universidad Teórica + Aplicaciones Prácticas), parque móvil de transporte (`PARQUE_TRANSPORTE_TIPOS`), curva continua de productividad y migración mensual escalonada (`calcular_tasa_migracion_mensual`).
- **`Economia.gd`:** Orquestador del tick económico horario, reservas porcentuales de materia prima (`[0, 10, 20, 30, 40, 50] %`), despacho de acarreadores y unidades móviles del Taller de Transporte, gestión del **Investigador Itinerante**, balance eléctrico en `kW / MW` y ciclos de formación en escuelas.
- **`Recoleccion.gd`:** Registro espacial de puestos periféricos, cálculo de tasas ambientales cada `6 h`, niveles de puesto `I–III`, regresión de nivel y agotamiento físico de bloques/árboles.
- **`CadenaMinerales.gd`:** Catálogo de las 8 recetas de refinado industrial (`siderurgica`, `refineria_tierras_raras`, `aserradero`, `fabrica_bloques`, `vidriera`, `carbonera`, `refineria_petrolera`, `productor_combustible`).
- **`Canalizaciones.gd` y `VoxelWorld.gd`:** Topología de redes de acueductos y tuberías aéreas en **`Y + 4`** (con cruces elevados en **`Y + 6`**), puertos de conexión en capa 4, detección de derrames y propagación y físicas de líquidos por gravedad y viscosidad en `VoxelWorld.gd` (drenables al colocar un bloque sólido encima o automáticamente en el interior de un edificio al finalizar su construcción).
- **`Zonificacion.gd`:** Delimitación de los polígonos de **Zona A** y **Zona B** dentro del radio de influencia (`30` celdas) del Núcleo Urbano.

### Subsistemas Espaciales, Agentes, Configuración e Interfaz HUD (v3.57 – v3.59)
- **`Ajustes.gd` y `Strings.gd`:** Centralización de balance y textos dinámicos. `Ajustes.gd` almacena todas las constantes numéricas, configuraciones de velocidad, demografía, moral y parámetros de simulación preparados para personalización en caliente («Nueva partida» y opciones globales). `Strings.gd` provee catálogo multi-idioma (`Ajustes.idioma`) y getters estáticos reactivos que inyectan los valores en vivo sin reiniciar escenas ni recargar scripts.
- **`VoxelWorld.gd`, `GeneradorMundo.gd` y `TranslucidosRenderer.gd`:** Gestión del `GridMap` 3D, colocación/extracción de bloques, agua estilo *Minecraft* y renderizado de bloques de ventana (`vidrio`) como paneles transparentes de `1/20` (`0,05 m`) en 3 variantes geométricas (`ventana` recta a media profundidad orientada hacia el avatar, `ventana_esquina` en L rotada 90° en Y, y `ventana_techo` horizontal al ras de la cara superior `Y ∈ [0,95, 1,0]` al colocar mirando hacia arriba o hacia abajo).
- **`BlueprintValidator.gd` y `PlantillasPuesto.gd`:** Reconocimiento volumétrico por *flood-fill* de edificios herméticos, validación de despeje de puertas/camas y plantillas predefinidas con rotación de `90°` (incluyendo `vidriera` `5×6` en adobe y `taller_transporte`).
- **`Obras.gd`, `ConstructorVias.gd` y `NiveladorTerreno.gd`:** Gestión de obras de construcción/demolición con hasta `4` obreros por obra, prioridades (`Alta`, `Normal`, `Baja`) ajustables con botones subir/bajar (`▲`/`▼`), drenaje automático de agua interior al completar el 100 % y tendido de carreteras con rampas.
- **`Colonos.gd` y `BuscadorRutas.gd`:** Máquina de estados finitos (FSM) de los agentes NPC y *pathfinding* A* ponderado (costo `3` en vía vs. `8` en terreno natural) con jerarquía de cesión de paso lateral y soporte para unidades móviles de transporte (incluyendo restricción `exige_via = true` y arrastre lento a `1,2 m/s`).
- **`IconosHUD.gd` y `MiniaturaRenderer.gd`:** Catálogo centralizado de **más de 95 iconos SVG pixel-art** (`godot/assets/icons/*.svg`, incluyendo `vidrio.svg`, `romano_1.svg`–`romano_4.svg`, `btn_subir.svg` y `btn_bajar.svg`) y generador de miniaturas 3D en vivo para `BarraSuperior.gd` (con nombre + ícono de Era e ícono romano de IDU con ventana tooltip en la esquina superior derecha), `BarraModos.gd` (`104×76 px`), `VentanaMoral.gd`, `VentanaEnergia.gd` (con salto de cámara a generadores/consumidores), `VentanaAlmacen.gd` (materias primas A–Z con desplegables jerárquicos y botón `[Expandir todo]`/`[Contraer todo]`), `VentanaBaul.gd`, `VentanaPoblacion.gd`, `VentanaOcupaciones.gd`, `PanelPuesto.gd`, `PanelEdificio.gd` (con transición automática al panel del edificio terminado) y `PanelCanalizacion.gd`.

---

## 3. Activos 3D y Suite de 28 Escenas de Prueba (`godot/scenes/*Test.tscn`)

El proyecto integra paquetes de modelos 3D *low-poly* bajo licencia **CC0**:
- **KayKit Block Bits & Medieval Hexagon Pack:** Bloques de terreno, recursos y estructuras.
- **Quaternius Modular Men:** Modelos articulados de colonos y trabajadores.
- **Poly Haven:** Texturas ambientales y materiales.

> [!IMPORTANT] Verificación Automatizada (28 Escenas al 100 % en Verde)
> Cada sistema cuenta con su propia escena de prueba ejecutable en modo *headless* (`CiudadTest.tscn`, `RecoleccionTest.tscn`, `CadenaMineralesTest.tscn`, `CanalizacionesTest.tscn`, `FluidosTest.tscn`, `ConstructorViasTest.tscn`, `ObrasPrioridadTest.tscn`, `DemolicionEdificiosTest.tscn`, `PlayerNatacionTest.tscn`, `PuestosNivelesTest.tscn`, `UI Mejoras Visuales (IconosHUD)`, entre otras), sumando **28 suites completas en verde**.

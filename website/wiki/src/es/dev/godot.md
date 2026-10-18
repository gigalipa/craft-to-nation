# Arquitectura Técnica en Godot 4.6 & PoCs

![Interfaz de construcción en primera persona y mundo vóxel](/assets/hud-primera-persona-construccion.png)

El desarrollo de **Craft to Nation** está construido en **Godot 4.6** (`GDScript`), empleando una arquitectura desacoplada donde la lógica pura de simulación (`RefCounted` y `Autoloads` sin `class_name` global para evitar colisiones de caché) avanza en ticks deterministas independientes de los cuadros por segundo (*framerate*).

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
- **`Ciudad.gd`:** Censo demográfico (`TIPOS_POBLACION`), almacén central (`Ciudad.almacen`), niveles urbanos `1–3` (`NIVELES_VIVIENDA`), investigación universitaria, curva continua de productividad y migración mensual escalonada (`calcular_tasa_migracion_mensual`).
- **`Economia.gd`:** Orquestador del tick económico horario, reservas de materia prima (`[0, 50, 100, 250, 500] u`), despacho de acarreadores, balance eléctrico en `kW / MW` y ciclos de formación en escuelas.
- **`Recoleccion.gd`:** Registro espacial de puestos periféricos, cálculo de tasas ambientales cada `6 h`, niveles de puesto `I–III`, regresión de nivel y agotamiento físico de bloques/árboles.
- **`CadenaMinerales.gd`:** Catálogo de las 7 recetas de refinado industrial (`siderurgica`, `refineria_tierras_raras`, `aserradero`, `fabrica_bloques`, `carbonera`, `refineria_petrolera`, `productor_combustible`).
- **`Canalizaciones.gd` y `Fluidos.gd`:** Topología de redes de acueductos y tuberías en `Y + 6`, puertos de conexión en capa 4, detección de derrames y propagación de líquidos por gravedad y viscosidad.
- **`Zonificacion.gd`:** Delimitación de los polígonos de **Zona A** y **Zona B** dentro del radio de influencia (`30` celdas) del Núcleo Urbano.

### Subsistemas Espaciales, Agentes e Interfaz HUD (v3.57)
- **`VoxelWorld.gd` y `GeneradorMundo.gd`:** Gestión del `GridMap` 3D, colocación/extracción de bloques, iluminación diurna/nocturna (`CicloDiaNoche.gd`) y agua estilo *Minecraft*.
- **`ValidadorEdificios.gd` y `PlantillasPuesto.gd`:** Reconocimiento volumétrico por *flood-fill* de edificios herméticos, validación de despeje de puertas/camas y plantillas predefinidas con rotación de `90°`.
- **`Obras.gd`, `ConstructorVias.gd` y `NiveladorTerreno.gd`:** Gestión de obras de construcción/demolición con hasta `4` obreros por obra, prioridades (`Alta`, `Normal`, `Baja`) y tendido de carreteras con rampas.
- **`Colonos.gd` y `BuscadorRutas.gd`:** Máquina de estados finitos (FSM) de los agentes NPC y *pathfinding* A* ponderado (costo `3` en vía vs. `8` en terreno natural) con jerarquía de cesión de paso lateral.
- **`IconosHUD.gd` y `MiniaturaRenderer.gd`:** Catálogo centralizado de **más de 90 iconos SVG pixel-art** (`godot/assets/icons/*.svg`) y generador de miniaturas 3D en vivo para `BarraSuperior.gd`, `BarraModos.gd` (`104×76 px`), `VentanaMoral.gd`, `VentanaEnergia.gd`, `VentanaAlmacen.gd`, `VentanaPoblacion.gd`, `VentanaOcupaciones.gd`, `PanelPuesto.gd`, `PanelEdificio.gd` y `PanelCanalizacion.gd`.

---

## 3. Activos 3D y Suite de 28 Escenas de Prueba (`godot/scenes/*Test.tscn`)

El proyecto integra paquetes de modelos 3D *low-poly* bajo licencia **CC0**:
- **KayKit Block Bits & Medieval Hexagon Pack:** Bloques de terreno, recursos y estructuras.
- **Quaternius Modular Men:** Modelos articulados de colonos y trabajadores.
- **Poly Haven:** Texturas ambientales y materiales.

> [!IMPORTANT] Verificación Automatizada (28 Escenas al 100 % en Verde)
> Cada sistema cuenta con su propia escena de prueba ejecutable en modo *headless* (`CiudadTest.tscn`, `RecoleccionTest.tscn`, `CadenaMineralesTest.tscn`, `CanalizacionesTest.tscn`, `FluidosTest.tscn`, `ConstructorViasTest.tscn`, `ObrasPrioridadTest.tscn`, `DemolicionEdificiosTest.tscn`, `PlayerNatacionTest.tscn`, `PuestosNivelesTest.tscn`, `UI Mejoras Visuales (IconosHUD)`, entre otras), sumando **28 suites completas en verde**.

# Arquitectura Técnica en Godot 4 & PoCs

El desarrollo de *Craft to Nation* se construye sobre **Godot 4**, aprovechando su sistema de nodos por composición, el motor de sombreado moderno y un bucle de simulación por ticks discretos desacoplado de la tasa de cuadros por segundo (*framerate*).

---

## 1. Arquitectura del Motor y Bucle de Simulación

El juego divide su ejecución en dos capas temporales:

```
[Render & Físicas del Avatar]  ──>  60 / 120 FPS continuos (_process / _physics_process)
                                            │
[Bucle Macro de Simulación]   ──>  Tick discreto: 2.0 segundos reales = 1 hora de juego
                                    • Consumo metabólico de colonos
                                    • Extracción de puestos periféricos
                                    • Refinamiento en industrias
                                    • Flujo de fluidos en ductos
                                    • Cálculo de moral y productividad
```

### El Sistema de Ticks (`Ciudad.gd` y `Economia.gd`)
- **Duración del Tick (`SEGUNDOS_POR_TICK`):** $2.0$ segundos de tiempo real equivalen exactamente a $1$ hora de tiempo simulado dentro del juego.
- **Relación con el Ciclo Estándar:** $1$ ciclo de balance estándar ($60$ segundos reales) equivale a $30$ ticks de simulación ($30$ horas de juego).
- **Consumo y Producción Atómica:** Cada 2 segundos, el despachador central evalúa el gasto de alimentos, los insumos de combustible y la recolección horaria de cada puesto activo, actualizando los registros de almacenamiento en memoria sin bloquear el hilo principal de renderizado.

---

## 2. Mapa de Escenas y Scripts Principales

El proyecto se estructura en módulos desacoplados bajo `godot/`:

### Escenas Principales (`godot/scenes/`)
- `Main.tscn`: Escena maestra que ensambla el mundo procedural (`VoxelWorld`), el avatar del jugador (`Player`), la cámara cenital (`CamaraCenital`), el gestor de simulación (`Ciudad`) y la interfaz (`HUD`).
- `Player.tscn`: Controlador de avatar en primera persona con mecánicas de salto, agachado, natación con barra de oxígeno, linterna de minero (`L`) y colisiones físicas continuas.
- `CamaraCenitalModosTest.tscn`: Cámara táctica ortogonal/perspectiva para planificación urbana, trazado de carreteras y previsualización de blueprints.
- `Test.tscn`: Suite central de integración automatizada.

### Scripts y Autoloads Centrales (`godot/scripts/`)
- `Ciudad.gd`: Núcleo cívico, censo demográfico, almacenamiento municipal (`Ciudad.almacen`), factor de núcleo e inmigración.
- `Economia.gd`: Gestión de balances económicos, reservas de materias primas y jerarquía logística.
- `Recoleccion.gd`: Lógica de puestos periféricos, tasas de extracción ambiental y agotamiento de recursos.
- `CadenaMinerales.gd`: Recetas industriales para aserraderos, siderúrgicas, carboneras y refinerías.
- `Canalizaciones.gd`: Topología de acueductos y tuberías, redes de fluidos, puertos de conexión y detección de derrames.
- `Colonos.gd`: Pathfinding cívico, asignación de camas, oficios, acarreo terrestre y estados de ánimo.
- `BlueprintValidator.gd`: Validación volumétrica de edificios herméticos, despeje de camas y orientación de puertas.

---

## 3. Estado de las Pruebas de Concepto (PoC)

El desarrollo técnico se valida de forma incremental mediante **Pruebas de Concepto (PoC)** ejecutables:

| PoC / Fase | Título y Enfoque | Componentes Clave | Estado Actual |
| :--- | :--- | :--- | :--- |
| **PoC 1** | **Mundo Vóxel y Generación Procedural** | `VoxelWorld.gd`, `GeneradorMundo.gd` | ✅ Completado |
| **PoC 2** | **Avatar 1ra Persona, Físicas y Subsuelo** | `Player.gd`, natación, linterna | ✅ Completado |
| **PoC 3** | **Validación Volumétrica de Blueprints** | `BlueprintValidator.gd`, habitaciones | ✅ Completado |
| **PoC 4** | **Cámara Cenital y Zonificación A/B** | `CamaraCenital.gd`, `Zonificacion.gd` | ✅ Completado |
| **PoC 5** | **Puestos de Extracción, Nivelación y Acarreo**| `Recoleccion.gd`, `PlantillasPuesto.gd` | ✅ Completado |
| **PoC 6** | **Fluidos, Subsuelo Profundo y Canalizaciones**| `Canalizaciones.gd`, pozos de crudo | ✅ Completado |
| **PoC 7** | **Cámara Dual y Selección de Tropas** | Controlador táctico RTS de escuadrones | 🟡 En diseño |
| **PoC 8-10**| **Carretas Terrestres, Puentes y Redes Férreas**| Vehículos con ruedas y vías avanzadas | 🟡 Planificado |

---

## 4. Garantía de Calidad y Suite de Pruebas

El repositorio mantiene una estricta política de estabilidad donde cada modificación al balance o a los sistemas de simulación se verifica mediante pruebas automatizadas:

> [!IMPORTANT] Cobertura de Pruebas
> El proyecto cuenta con **28 escenas de prueba independientes al 100% en verde**, abarcando desde la mecánica de fluidos y pathfinding ponderado en carreteras hasta la formación de técnicos y la curva continua de moral cívica.

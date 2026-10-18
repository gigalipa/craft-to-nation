# Godot 4.6 Technical Architecture & Simulation Engine

![First-person construction HUD and voxel environment](/assets/hud-primera-persona-construccion.png)

**Craft to Nation** is engineered in **Godot 4.6** (`GDScript`), combining pure simulation state managers (`RefCounted` modules and `Autoloads` without global `class_name` pollution) with a deterministic discrete tick loop decoupled from the rendering framerate.

---

## 1. Discrete Time & Simulation Architecture

```
  ┌─────────────────────────────────────────────────────────────────────┐
  │                         TIME ARCHITECTURE                           │
  ├─────────────────────────────────────────────────────────────────────┤
  │ • Real Time per Tick:     2.0 seconds (SEGUNDOS_POR_TICK)           │
  │ • In-Game Time per Tick:  1.0 in-game hour (24 ticks = 1 day = 48s) │
  │ • Simulation Month:       720 ticks = 30 days = 24 real minutes     │
  │ • Standard Wiki Cycle:    60 real seconds = 30 in-game hours        │
  │ • Voxel World Dimensions: 200×200 cells, max height Y=130, 24 depth │
  └─────────────────────────────────────────────────────────────────────┘
```

- **Hourly State Updates (`2.0s`):** Every 2.0 real seconds, `Ciudad.gd` and `Economia.gd` execute an atomic hourly tick: metabolic food consumption, physical block extraction in outposts, refinery batch processing, fluid conduction, power grid `kW / MW` balance, daily morale fraction (`tasa_cambio_moral / 24.0`), and stepped monthly migration.
- **Continuous Physics (`_physics_process`):** First-person avatar movement, river current drift, underwater swimming (`10s` oxygen bar), and NPC A* navigation run smoothly at full framerate.

---

## 2. Core Scripts & Autoloads (`godot/scripts/`)

### Simulation State Autoloads
- **`Ciudad.gd`:** Master colony state: demographic census (`TIPOS_POBLACION`), Central Stockpile (`Ciudad.almacen`), Urban Levels `1–3` (`NIVELES_VIVIENDA`), university tech tree, continuous productivity curve, and the 9-tier stepped monthly migration table (`calcular_tasa_migracion_mensual`).
- **`Economia.gd`:** Hourly economic dispatcher, raw material reserve quotas (`[0, 50, 100, 250, 500] u`), hauler task scheduling, electrical grid balance (`kW / MW`), and school training cohorts.
- **`Recoleccion.gd`:** Spatial registry of peripheral outposts, 6-hour environmental yield scans, outpost levels `I–III`, automatic level regression, and physical block/tree depletion.
- **`CadenaMinerales.gd`:** Defines all 7 industrial refinement recipes (`siderurgica`, `refineria_tierras_raras`, `aserradero`, `fabrica_bloques`, `carbonera`, `refineria_petrolera`, `productor_combustible`).
- **`Canalizaciones.gd` & `Fluidos.gd`:** Elevated **`Y + 4`** modular fluid pipelines (with **`Y + 6`** conduit-over-conduit crossings), layer-4 fluid ports, rupture spill detection, and gravity/viscosity liquid spreading (drainable by placing a solid block over the liquid cell).
- **`Zonificacion.gd`:** Manages **Zone A** and **Zone B** polygons inside the Urban Core's `30-cell` Area of Influence.

### Voxel World, Agents & HUD Iconography (v3.57)
- **`VoxelWorld.gd` & `GeneradorMundo.gd`:** Manages the **200×200** 3D `GridMap` (`y = 130` max height, 24 subsurface layers down to unmineable `bedrock`, 2 mountain peaks, 6 minerals, deep oil reservoirs, rivers with waterfalls, lakes, and seas) plus day/night lighting (`CicloDiaNoche.gd`).
- **`ValidadorEdificios.gd` & `PlantillasPuesto.gd`:** Flood-fill airtight room detection, doorway/bed clearance audits, and rotatable (`90°`) facility templates.
- **`Obras.gd`, `ConstructorVias.gd` & `NiveladorTerreno.gd`:** Construction and demolition jobsite management (up to `4` builders per site, `2 blocks/s` speed), work priorities (`High`, `Normal`, `Low`) with a 5-tier work dispatch hierarchy, and road laying with automatic ramps.
- **`Colonos.gd` & `BuscadorRutas.gd`:** NPC agent finite state machine (FSM) and weighted A* pathfinding (cost `3` on packed dirt roads vs. cost `8` on natural terrain) with lateral yield priorities.
- **`IconosHUD.gd` & `MiniaturaRenderer.gd`:** Centralized catalog of **90+ crisp pixel-art SVG icons** (`godot/assets/icons/*.svg`) and live 3D thumbnail renderer powering `BarraSuperior.gd`, `BarraModos.gd` (`104×76 px` build buttons), `VentanaMoral.gd`, `VentanaEnergia.gd` (with one-click camera jump to generators/consumers), `VentanaAlmacen.gd`, `VentanaBaul.gd`, `VentanaPoblacion.gd`, `VentanaOcupaciones.gd`, `PanelPuesto.gd`, `PanelEdificio.gd`, and `PanelCanalizacion.gd`.

---

## 3. CC0 3D Asset Packs & 28 Automated Test Scenes (`godot/scenes/*Test.tscn`)

The project integrates CC0 low-poly 3D asset packs:
- **KayKit Block Bits & Medieval Hexagon Pack:** Voxel terrain blocks, props, and structural elements.
- **Quaternius Modular Men:** Articulated colonist and worker character meshes.
- **Poly Haven:** Environmental materials and textures.

> [!IMPORTANT] 28 Automated Test Scenes (100% Green)
> Every subsystem is verified by dedicated headless test scenes (`CiudadTest.tscn`, `RecoleccionTest.tscn`, `CadenaMineralesTest.tscn`, `CanalizacionesTest.tscn`, `FluidosTest.tscn`, `ConstructorViasTest.tscn`, `ObrasPrioridadTest.tscn`, `DemolicionEdificiosTest.tscn`, `PlayerNatacionTest.tscn`, `PuestosNivelesTest.tscn`, etc.), maintaining **28 complete test suites passing 100% in green**.

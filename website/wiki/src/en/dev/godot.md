# Godot 4 Technical Architecture & Simulation Engine

*Craft to Nation* is engineered in **Godot 4.x**, leveraging custom GDScript simulation managers, deterministic tick systems, and a hybrid voxel-tile environment to achieve high performance under hundreds of active autonomous agents.

---

## 1. Discrete Time & Simulation Ticks

The simulation operates on a deterministic tick frequency decoupled from the rendering framerate:

```
  ┌─────────────────────────────────────────────────────────────┐
  │                    TIME ARCHITECTURE                        │
  ├─────────────────────────────────────────────────────────────┤
  │ • Real Time per Tick:     2.0 seconds (SEGUNDOS_POR_TICK)   │
  │ • In-Game Time per Tick:  1.0 in-game hour                  │
  │ • Macro-Cycle (Wiki):     60 seconds real time              │
  │ • Equivalence:            1 Macro-Cycle = 30 Game Hours     │
  └─────────────────────────────────────────────────────────────┘
```

- **Hourly State Updates:** Every 2.0 real seconds, `Ciudad.gd` triggers an hourly simulation tick across the colony. Metabolic hunger is consumed, production batches advance, outposts accumulate raw goods, and dynamic morale is recalculated.
- **Micro-Steps:** Agent movement, pathfinding interpolation, and voxel particle physics update on the standard `_physics_process(delta)` loop, ensuring fluid first-person gameplay and smooth NPC ambulation.

---

## 2. Core Architecture & Primary Simulation Scripts

The game's simulation logic is organized into specialized domain managers:

### `Ciudad.gd` (Central Settlement & Civic Registry)
- Maintains the master state of the colony: total census, active careers, housing registries, and civic influence borders.
- Manages the **Central Stockpile** (`Ciudad.almacen`):
  - Base capacity: 500 per resource, 5,000 for food (`LIMITE_BASE`, `LIMITE_BASE_COMIDA`).
  - Core declaration multiplier (`FACTOR_NUCLEO = 2.0`).
  - Residential chest capacity expansion (`BONO_BAUL = 100`).
- Executes hourly starvation checks and demographic mortality routines.

### `Colonos.gd` & `AgenteColono.gd` (Agent FSM & Navigation)
- Implements a multi-state finite state machine (FSM) for each NPC: `IDLE`, `WALKING_TO_WORK`, `GATHERING`, `HAULING`, `SLEEPING`, `HOMELESS`.
- Governs individual career ranks (Citizen, Unemployed, Worker, Technician, Specialist, Researcher, Military) and educational promotion.
- Executes A* navigation across weighted voxel surfaces (dirt roads vs. rough wilderness).

### `Recoleccion.gd` (Peripheral Outposts & Depletion)
- Handles harvest yields for lumber camps, mines, foraging lodges, and fishing docks.
- Performs an environmental scan every 6 in-game hours, dynamically adjusting outpost extraction rates based on remaining trees, ore blocks, or connected water surface area.

### `CadenaMinerales.gd` & `Economia.gd` (Refining & Logistics)
- Coordinates industrial recipe batching in sawmills, block factories, steel mills, and petroleum refineries.
- Regulates hauler dispatching, minimum delivery batching (10 units), and warehouse distribution quotas.

### `Canalizaciones.gd` (Fluid Physics & Modular Pipelines)
- Simulates elevated pressurized fluid conduits for fresh water, crude oil, and refined fuel.
- Manages hydrostatic spreading, spill calculations, and port-to-port connections.

### `VoxelWorld.gd` (Voxel Grid & Structural Validation)
- Handles 3D voxel chunk loading, block modification, terrain leveling, and raycasting.
- Executes flood-fill room detection, ceiling clearance validation, and structural integrity verification.

---

## 3. Proof of Concept (PoC) Progression & Verification

The codebase has evolved through rigorous, test-driven developmental phases:

```
  PoC 1 ──► PoC 2 ──► PoC 3 ──► PoC 4 ──► PoC 5 ──► PoC 6 (Current)
 (Voxel    (Shelter   (Civic     (Blueprints (Outposts  (Fluids, Power,
  Basics)   Enclosure) Core)      & Jobsites) & Hauling) Dynamic Morale)
```

- **PoC 1 — Voxel Substrate & First-Person Survival:** Basic block mining, tool durability, player inventory, and natural terrain generation.
- **PoC 2 — Structural Enclosure & Habitability:** Raycast flood-fill room recognition, airtight perimeter testing, and bed clearances.
- **PoC 3 — The Urban Core & Influence Radius:** Core declaration, camera switching, immigration spawning, and early demography.
- **PoC 4 — Parameterized Blueprints & Construction Crews:** Blueprint capture, ghost placement preview, and auto-assigned construction crews.
- **PoC 5 — Peripheral Outposts & Land Hauling:** Lumber camps, mines, fishing docks, local outpost storage buffers, and dedicated carrier haulers.
- **PoC 6 — Industrial Chains, Fluid Pipelines & Dynamic Morale:** Multi-tier refining, elevated pipelines, electricity distribution grids, and psychological morale modulation (v3.56).

### Test Suite Status:
- **28 automated test scenes** passing **100% in green**.
- Over **560 discrete unit and integration test blocks** verified before every milestone commit.

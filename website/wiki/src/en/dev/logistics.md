---
title: "Logistics, Road Networks & Elevated Conduits"
description: "Technical breakdown of multi-level logistics: aerial conduit network at Y+6, prioritized dirt roads laid by colonist crews, and fluid spreading."
---

# Logistics, Road Networks & Elevated Conduits

![Strategic view of the industrial city connected by roads and conduits](/assets/citycraft-world.webp)

In **Craft to Nation**, every unit of timber, ore, or liquid physically traverses the `200×200` voxel world. The logistics architecture is divided into two complementary layers: **Road Networks & Solid Land Haulage** (`ConstructorVias.gd`, `BuscadorRutas.gd`, `Colonos.gd`) and **Elevated Fluid Conduits** (`Canalizaciones.gd` and physics in `VoxelWorld.gd`).

---

## 1. Overhead Road Tracing (`1 -> 5 -> 1`), On-Foot Road Mode (`V`) & Guided Demolition (`3`)

```
[Peripheral Outpost / Mine] ──(Local Buffer: 1,000 u)──> [Hauler (150 u)] ──> [Central Stockpile / Refinery]
```

### Overhead Road Tracing (`1 -> 5 -> 1`)
- In overhead view (<kbd>C</kbd>), the road-laying tool is accessed through the numeric menu: **<kbd>1</kbd> (Build) → <kbd>5</kbd> (Roads) → <kbd>1</kbd> (Trace Road)**. *(The `V` key is not used in the overhead camera).*
- The contextual card displays vector SVG icons for **`[Left Click] SET POINT`**, **`[Double Left Click (x2)] CONFIRM`**, **`[Right Click] CANCEL`**, and **`[Esc] EXIT`**, alongside `Velocidad: +35%` and live stone/dirt grading costs.
- Confirming with a **double left-click** places the yellow perimeter outline (`ViaObraOverlay`), and up to **4 free laborers** walk over to build the road consecutively from one end to the other. Tracing a new contiguous road segment while construction is active automatically merges it into the same work order.

### First-Person On-Foot Road Mode (<kbd>V</kbd> Key)
- In first-person mode, pressing <kbd>V</kbd> **toggles on-foot road interaction mode**:
  - **Build `2×2` Section (<kbd>Left Click</kbd>):** Aiming at a pending road section (with yellow wireframe) and left-clicking completes the **entire `2×2` section** at once (all 4 road-width cells or ramp wedges).
  - **Demolish `2×2` Section (<kbd>Right Click</kbd>):** Aiming at an already built road section and right-clicking instantly removes the entire `2×2` section and its wedges.
  - Press <kbd>V</kbd> or <kbd>Esc</kbd> to exit road mode.

### Overhead Guided Road Demolition (Mode <kbd>3</kbd>)
- In overhead view, press **<kbd>3</kbd> (Demolish)**, left-click at one end of a road (including around 90° "L"-shaped corners), and move the cursor to the other end:
- The translucent orange preview (`ViaDemolicionOverlay`) follows the road network via **Dijkstra** covering the **full 2-lane width (`2×2` section)** around the outer corner without cutting diagonally. Confirming with a **double left-click** marks a persistent orange outline on the ground for colonists to dismantle section by section.

### Physical Carrier Specs, Mobile Fleet & Weighted A* Navigation (`BuscadorRutas.gd`)
- **Base Ambulation Speed (On-Foot Hauler):** **2.5 cells / second** (`5.0 cells/h` in-game time), with a **+35% speed bonus** on packed-dirt roads.
- **Base Payload Capacity:** **150 units** per trip (**10-unit** minimum batch, strictly respecting the `0% / 10% / 20% / 30% / 40% / 50%` percentage central reserve quota).
- **Weighted A* Traversal Cost:** Packed-dirt roads have a step cost of **3** compared to **8** on natural terrain.

### Transport Workshop & Mobile Haulage Fleet (`Ciudad.PARQUE_TRANSPORTE_TIPOS`)
Built on the Industrial Zone, the **Transport Workshop (`taller_transporte`)** manufactures and dispatches 6 mobile haulage unit types:

| Haulage Unit | Payload | Base Speed | Road Required | Operating Upkeep | Manufacturing Cost |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`acarreador_pie`** *(On-foot hauler)* | `150 u` | `2.5 m/s` | No | — | Base colonist assignment |
| **`carreta_mano`** *(Handcart)* | `300 u` | `2.2 m/s` | No | — | `20 Planks + 5 Iron` |
| **`carro_caballos`** *(Horse wagon)* | `600 u` | `4.0 m/s` | No | `2 Food/h` | `40 Planks + 15 Iron` |
| **`camion_diesel`** *(Diesel truck)* | `1,800 u` | `6.5 m/s` | **Yes (`exige_via`)** | `2 Fuel/h` | `30 Steel + 20 Iron + 10 Copper + 6 Glass` |
| **`trolebus_solar`** *(Solar trolleybus)* | `900 u` | `5.0 m/s` | **Yes (`exige_via`)** | `1 Energy/h` | `15 Steel + 20 Copper + 5 Ref. Min. + 4 Glass` |
| **`dron_carga`** *(Cargo drone)* | `600 u` | `7.5 m/s` *(direct flight)* | No | `2 Energy/h` | `20 Steel + 25 Copper + 15 Ref. Min.` |

- **Exclusive Glass Requirement for Vehicle Cabins:** Motorized units with cab windshields (`camion_diesel` and `trolebus_solar`) exclusively require refined **`Glass` (`vidrio`)** produced at the Glassworks (`1-3-5`); raw `Earth` (`tierra`) cannot substitute for glass in vehicles.
- **Slow-Crawl Fallback on Supply Depletion (`1.2 m/s`):** If an active vehicle runs out of its operating upkeep (`food`, `fuel`, or `energy`) mid-route, it drops into an emergency slow crawl at **`1.2 m/s`** while preserving **100% of its cargo** until delivery.

---

## 2. Single-Cell Corridor Traffic Priority Hierarchy

In narrow 1-cell passages, head-on encounters between two colonists are resolved without deadlock via cargo priority:

```text
Food > Fuel > Crude Oil > Steel > Refined Minerals
     > Iron > Copper > Coal > Rare Earths
     > Glass > Planks > Stone Blocks > Wood > Stone > Earth > Water
```

The unloaded or lower-priority colonist steps aside into a lateral cell to yield right-of-way.

---

## 3. Elevated Conduits (`1 -> 6 -> 1..2`), Grade-Separated Crossings & Spills

In overhead view, fluid conduits are traced via **<kbd>1</kbd> (Build) → <kbd>6</kbd> (Conduits)**:

| Menu Path | Conduit Type | Permitted Fluids | Human-Readable Cost Labels per Cell |
| :--- | :--- | :--- | :--- |
| **`1-6-1`** | **Aqueduct (`Acueducto`)** | <ResourceBadge name="Water" /> <ResourceBadge name="Fuel" /> | `1 Bloque de piedra` + `1 Tabla` (or `Bloque de madera`) |
| **`1-6-2`** | **Pipeline (`Tubería`)** | <ResourceBadge name="Water" /> <ResourceBadge name="Crude Oil" /> <ResourceBadge name="Fuel" /> | `1 Bloque de acero` + `1 Estructura de hierro` |

### Standard Height (`Y + 4`), Pillars Every 5 Blocks & Conduit-Over-Conduit Crossings (`Y + 6`)
- **Standard Conduit Height (`Y = Y_ground + 4`):** Conduits are built elevated, leaving **3 blocks of vertical clearance beneath the beam** so the avatar, colonists, and packed-dirt roads (`1 -> 5 -> 1`) pass underneath completely unobstructed. Support columns are placed every **5 blocks** (`0, 5, 10...`, leaving 4 cells of clear span between pillars) and at every 90° corner.
- **Grade-Separated Crossings Between Two Conduits (`Y = Y_ground + 6`):** When tracing a Pipeline or Aqueduct perpendicularly across an existing conduit at `Y + 4`, **two 6-block-high columns (`Y = Y_ground + 5`)** are automatically erected on the two cells immediately adjacent to the intersection, and the upper span crosses at **`Y = Y_ground + 6`**, leaving **1 full block of clear air (`Y = Y_ground + 5`)** between the lower and upper conduits without mixing fluids.

### Physical Spills (`🔴 Derrame`), `0.20` Crude Viscosity & Column Reconnection
- **Open-End Spills:** Confirming an active conduit with its far end unconnected in mid-air switches its state to **`🔴 Derrame`** on the next hourly tick, spawning a physical liquid block that falls to the ground and spreads by gravity (`crudo` spreads up to 3 horizontal cells with a heavy **`0.20` viscosity factor**—five times denser than dry land—and can be drained in 1st person by right-clicking with a solid block).
- **Reconnecting from a Column:** Left-clicking directly on the **last column** of a spilling (`🔴 Derrame`) or disconnected (`⚪ Desconectado`) conduit with the conduit tool (`1 -> 6 -> 1..2`) lets you extend and connect it to a building input port; the segments merge, the network seals in the **`🟢 Conectado`** state, and the active spill stops immediately.

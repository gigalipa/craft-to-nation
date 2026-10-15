# Logistics, Land Haulage & Pipeline Networks

Logistical balance is the cornerstone of *Craft to Nation*. Unlike abstracted resource pools in conventional city builders, every unit of ore, timber, and liquid must physically travel across the game world. Logistical networks are separated into two distinct physical tiers: **Solid Land Haulage** and **Pressurized Fluid Distribution**.

---

## 1. Land Haulage & Colonist Navigation Specs

Bulk solids (stone, lumber, iron, coal, grains) are transported between peripheral outposts, industrial smelters, and civic storage by human haulers and freight convoys.

```
       [ Extraction Outpost ]
                 │
                 ▼  (Front Service Cell)
         [ Loaded Hauler ]
                 │
                 │  Speed: 2.5 cells/sec | Capacity: 150 units
                 │  Road Cost: 3 vs Wilderness Cost: 8
                 ▼
         [ Urban Core / Storage ]
```

### Physical Carrier Specifications:
- **Colonist Ambulation Speed:** **2.5 cells / second** real time (equivalent to 5.0 cells per in-game simulation hour).
- **Hauler Load Capacity:** **150 units** per carrier trip.
- **Minimum Batch Threshold:** **10 units**. Haulers will not initiate a logistics run to a refinery or warehouse until at least 10 units of an input material have accumulated, preventing inefficient single-item trips.
- **Exterior Service Cell Interaction:** Carriers pick up goods exclusively from the exterior service tile directly in front of an outpost's front door. Carriers never enter the structure's interior, ensuring working gatherers are never trapped or obstructed.

### Weighted Pathfinding & Road Efficiency:
The navigation engine uses weighted A* grid pathfinding where traversal costs reflect road surface quality:
- **Rough Wilderness / Natural Ground:** Traversal cost = **8**.
- **Packed Dirt Road:** Traversal cost = **3**.
- **Paved Cobblestone / Asphalt Highway:** Traversal cost = **1 to 2** (up to +60% movement speed bonus).

Because natural ground costs nearly triple that of a packed dirt path, carriers and pedestrians automatically seek out and adhere to designated road networks even if the detour is slightly longer.

### Single-Cell Corridor Traffic Priority Hierarchy:
When two carriers meet head-to-head on a narrow 1-cell mountain pass or bridge, deadlock is averted by an automated yield hierarchy:

$$\begin{aligned}
\text{Food} &\gt \text{Fuel} \gt \text{Crude Oil} \gt \text{Steel} \gt \text{Refined Minerals} \gt \text{Iron} \\
&\gt \text{Copper} \gt \text{Coal} \gt \text{Rare Earths} \gt \text{Planks} \gt \text{Wood} \gt \text{Stone} \gt \text{Dirt} \gt \text{Water}
\end{aligned}$$

- **Tiebreakers:** If carrying identical goods, the carrier with the greater payload has right-of-way; if still tied, carrier ID is used.
- **Status Hierarchy:** Loaded Carriers $\gt$ Empty Returning Carriers $\gt$ Employed Workers $\gt$ Idle Colonists.
- **Lateral Evasion:** The yielding agent temporarily steps sideways into an adjacent open cell to allow the higher-priority courier to pass unimpeded.

---

## 2. Pressurized Fluid Distribution Pipelines

Fluids (fresh water, crude oil, and refined hydrocarbon fuel) cannot be efficiently moved in bags or hand barrows. Instead, they require elevated pipe ducting (`Canalizaciones.gd`).

### Modular 4-Piece Pipe Assembly:
Elevated pipelines are constructed using four modular components:
1. **Vertical Structural Columns:** Ground-anchored support pylons that elevate pipelines to the standard clearance height.
2. **Linear & Corner Headers:** Directional conduit junctions supporting $90^\circ$ turns, T-junctions, and multi-inlet convergence.
3. **Inclinable Continuous Spans:** Dynamic variable-length pipe spans with central pivots to traverse gentle slopes and terrain depressions.
4. **Terminal Port Couplers:** Flanged interface blocks that dock directly onto pumping stations, storage tanks, and refinery intake manifolds.

```
                  [ Linear Header ] ═════════ [ Spanning Conduit ]
                          ║                              ║
                  [ Support Column ]             [ Support Column ]
             ═════════════╩══════════════════════════════╩═════════════
             ▲ Ground Level (Y)                  Clearance: Y+5 to Y+6
```

### Grade-Separated Crossings:
- **Standard Pipeline Elevation:** Elevated conduits run at ground level **$Y + 6$**.
- **Unimpeded Ground Clearance:** Provides a clear **$Y + 5$** clearance underneath, allowing pedestrian colonists, heavy cargo wagons, and future military vehicles to navigate freely beneath the pipe infrastructure without obstruction.

### Pumping Rates & Fluid Dynamics:
- **Base Extraction Throughput:** **2.0 fluid units / hour** continuous pumping rate for both surface water stations and deep subterranean oil rigs.
- **Topological Integrity:** Multi-inlet to single-outlet topology ensures steady downstream line pressure.
- **Fluid Viscosity & Physical Properties:**
  - **Fresh Water:** Viscosity 1.0, horizontal spread radius = 7 cells.
  - **Refined Fuel:** Viscosity 1.2, horizontal spread radius = 5 cells.
  - **Crude Oil:** Dense viscosity factor = 0.20 (dampened velocity and jump suppression), horizontal spread radius = 3 cells.
- **Dynamic Spill Containment:** Ruptured or uncoupled pipe segments generate active fluid spills onto terrain. Successfully connecting terminal couplers instantly seals the line and stops leakage.

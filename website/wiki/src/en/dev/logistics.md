# Logistics, Road Networks & Fluid Pipelines

![Strategic view of the industrial city connected by roads and conduits](/assets/citycraft-world.webp)

In **Craft to Nation**, every unit of timber, ore, or liquid physically traverses the `200×200` voxel world. The logistics architecture is divided into two complementary layers: **Road Networks & Solid Land Haulage** (`ConstructorVias.gd`, `BuscadorRutas.gd`, `Colonos.gd`) and **Elevated Pressurized Fluid Pipelines** (`Canalizaciones.gd`, `Fluidos.gd`).

---

## 1. Road Laying Crews, Weighted Pathfinding & Land Haulage

```
[Peripheral Outpost / Mine] ──(Local Buffer: 1,000 u)──> [Hauler (150 u)] ──> [Central Stockpile / Refinery]
```

### Road Construction & Guided Demolition (`ConstructorVias.gd` / `Obras.gd`)
- **Overhead Road Tool (<kbd>V</kbd>):** Trace straight or L-shaped packed dirt road segments with automatic ramp generation across gentle slopes and live 3D thumbnail previews in `BarraModos.gd`.
- **Colonist Road Crews & Priorities:** Traced road segments register as construction worksites where available laborers build them according to their assigned priority (**High `▲▲▲`**, **Normal `▲▲`**, **Low `▲`**). You can also manually build or demolish road cells in first-person mode by aiming at the ground and pressing <kbd>V</kbd>, or use guided road network demolition in overhead Demolish mode (<kbd>3</kbd> + <kbd>V</kbd>).

### Physical Carrier Specs & Weighted A* Navigation (`BuscadorRutas.gd`)
- **Base Ambulation Speed:** **2.5 cells / second** (`5.0 cells/h` in-game time).
- **Road Speed Bonus:** Packed dirt roads grant a **+35% movement speed bonus** to both NPC colonists and the player avatar.
- **Payload Capacity:** **150 units** per trip (with a **10-unit minimum batch threshold** and strict enforcement of `[0, 50, 100, 250, 500] u` raw material reserve quotas).
- **Weighted A* Traversal Cost:** Packed dirt roads have a step cost of **3** compared to **8** on natural terrain, ensuring haulers naturally follow established road arteries.

---

## 2. Single-Cell Corridor Traffic Priority Hierarchy

When two colonists meet head-to-head in a narrow 1-cell pass, deadlocks are prevented by an automated yield hierarchy based on cargo criticality:

```text
Food > Fuel > Crude Oil > Steel > Refined Minerals
     > Iron > Copper > Coal > Rare Earths
     > Planks > Wood > Stone > Earth > Water
```

- **Tiebreakers:** If carrying identical resources, right-of-way goes to the larger payload, then task status (`Loaded Hauler > Returning Empty Hauler > Commuting Worker > Idle Colonist`), then lowest entity ID. The yielding colonist steps laterally into an adjacent cell to clear the corridor.
- **Exterior Service Cells:** Haulers pick up and deliver goods strictly from the exterior tile facing the entrance (`e`) or exit (`s`) door without entering building interiors.

---

## 3. Elevated Fluid Distribution Pipelines (`Canalizaciones.gd`)

To transport **Water**, **Crude Oil**, and **Fuel** continuously without manual haulers, the colony uses a modular 4-piece conduit system (vertical support columns, straight/corner headers, inclinable spans, and terminal port couplers):

| Conduit Type | Permitted Fluids | Construction Cost per Cell |
| :--- | :--- | :--- |
| **Aqueduct** | <ResourceBadge name="Water" /> <ResourceBadge name="Fuel" /> | `1 Stone Block` + `1 Wood Block` |
| **Industrial Pipeline** | <ResourceBadge name="Water" /> <ResourceBadge name="Crude Oil" /> <ResourceBadge name="Fuel" /> | `1 Steel Block` + `1 Iron Frame` |

### Grade-Separated Crossings (`Y + 6`) & HUD Flow Diagnostics
- **Elevation & Clearance:** Conduits dock with **layer-4 fluid ports** on buildings and rise to **`Y_ground + 6`** over road crossings, preserving an unobstructed **`Y + 5` vertical clearance** underneath with support pylons every **5 cells** (`INTERVALO_COLUMNAS = 5`).
- **Throughput & Viscosity Spills:** Each active line conducts **2.0 fluid units/h**. Uncoupled open pipe ends emit `derrame_detectado`, spilling liquid across the terrain according to physical viscosity (`Water`: spread 7; `Fuel`: spread 5; `Crude Oil`: spread 3 with `0.20` viscosity).
- **Pipeline Diagnostic Panel (`PanelCanalizacion.gd`):** Clicking any conduit segment in overhead view displays a visual flow badge **`[Inlet Status] -⇥ [Resource Icon] -⇥ [Outlet Status]`** to immediately verify port coupling and active flow.

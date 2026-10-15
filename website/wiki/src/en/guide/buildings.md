# Buildings, Shelters & Infrastructure

In *Craft to Nation*, architectural construction is not purely aesthetic—it is a functional simulation system. Every structure must obey strict physical rules regarding airtightness, access clearances, spatial zoning, and logistical throughput.

---

## 1. Shelters & Residential Dwellings

Residential housing fulfills two critical societal functions: it houses your population and expands the capacity of your Central Stockpile.

### Structural Requirements for Valid Habitability:
1. **Structural Walls & Enclosure:** The building perimeter must be built from recognized structural materials (`stone_block`, `wood_block`, masonry). Natural terrain (such as loose earth) does not satisfy the structural engine check.
2. **Solid Roof:** Every interior room volume must be fully sealed with roof slabs.
3. **Ground-Level Exterior Door:** The main entry door must be placed on the first floor ($Y_{ground}$) and maintain an unobstructed 2-cell front clearance (`despeje frontal`). Multi-story residential buildings do not require upper-floor exterior doors.
4. **Bed Clearances:** Each placed bed must have unhindered lateral and ceiling headroom. Beds cannot be blocked by walls or adjacent chests.

### Population Density per Bed ("x Bed" Capacity)
Depending on social class and educational hierarchy, beds support varying numbers of residents sharing rotating shift sleeping quarters:

| Social Class / Role | Residents per Bed | Housing Luxury Required |
| :--- | :--- | :--- |
| **Citizen (Ciudadano)** | **5** colonists / bed | Standard communal shelter |
| **Unemployed (Desempleado)** | **4** colonists / bed | Standard communal shelter |
| **Worker (Obrero)** | **4** colonists / bed | Basic laborer barracks |
| **Technician (Técnico)** | **3** colonists / bed | Specialized technical housing |
| **Military (Militar)** | **3** colonists / bed | Fortified military barracks |
| **Specialist (Especialista)** | **2** colonists / bed | Quality residential flats |
| **Researcher (Investigador)** | **1** colonist / bed | Private quarters / Academy dorms |

### Residential Storage Expansion (`BONO_BAUL`)
Every storage chest placed inside an approved residential home expands the settlement's master inventory:
- **+100 units** to general resource capacity (wood, stone, metals).
- **+400 units** to central food storage capacity.

---

## 2. Peripheral Extraction Outposts

Extraction posts are placed in the **Periphery** (outside the civic Area of Influence) directly atop or adjacent to natural resource deposits.

```
┌────────────────────────────────────────────────────────┐
│               PERIPHERAL OUTPOST PROFILE               │
│                                                        │
│  [Footprint & Radius]         [Workforce & Storage]    │
│  • Lumberjack: 3×4 / R:12     • Crew Limit: 5 or 7     │
│  • Stone Mine: 5×5 / R:6      • Local Storage: 1,000   │
│  • Hunter: 4×4 / R:12         • Hauler Service Cell:   │
│  • Fishing: 4×6 / R:25          Exterior Front Step    │
└────────────────────────────────────────────────────────┘
```

| Outpost Type | Footprint | Operating Radius | Max Crew | Local Storage | Target Resources |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Lumberjack Post** | 3×4 cells | 12 cells radius | 5 workers | 1,000 units | Raw Timber & Saplings |
| **Stone & Mineral Mine** | 5×5 cells | 6 cells (depth 8–24) | 5 workers | 1,000 units | Stone, Iron, Coal, Copper |
| **Hunting & Foraging** | 4×4 cells | 12 cells radius | 7 workers | 1,000 units | Game Meat & Wild Berries |
| **Fishing Dock** | 4×6 cells | 25 cells radius | 7 workers | 1,000 units | Fish & Coastal Algae |
| **Pumping Station** | 3×3 cells | Pipeline network | 3 technicians | 1,000 fluid | Fresh Water |
| **Subsurface Rig** | 4×4 cells | Pipeline network | 3 technicians | 1,000 fluid | Deep Crude Oil |

### Unique Building Rules:
- **Fishing Dock Footprint:** The 4×6 rectangle must span land and water: the **dock end** must project onto real navigable water, while the **building end** must rest on firm soil for land hauler access.
- **Tree Collisions:** A lumberjack post cannot be placed where its foundation structural blocks directly intersect a solid tree trunk (`wood`). It can, however, replace foliage blocks automatically.
- **Service Cell Access:** Haulers collect finished goods directly from the exterior service tile facing the front door. Haulers never enter the interior, preventing movement deadlocks with active workers.

---

## 3. Central Stockpile & Inventory Architecture

The **Central Stockpile** is located at the Urban Core. It aggregates all delivered materials and provides resources for colony construction:

```
                  ┌──────────────────────────────┐
                  │    CENTRAL STOCKPILE METRICS │
                  ├──────────────────────────────┤
                  │ Base Capacity:   500 / item  │
                  │ Base Food:       5,000 food  │
                  │ Initial Food:    5,000 food  │
                  │ Initial Wood:    200 wood    │
                  │ Core Factor:     ×2 Multiplier│
                  │ Post-Core Cap:   1,000 / item│
                  │ Post-Core Food:  10,000 food │
                  └──────────────────────────────┘
```

- **Stockpile Capping:** When the Central Stockpile reaches maximum capacity for a resource, haulers cannot drop off cargo. They wait at the service door or reroute to secondary warehouse bins.
- **Deconstruction Recovery:** Deconstructing any approved structure reclaims 100% of stored materials and returns structural blocks to the colony inventory.

---

## 4. Construction Dynamics & Blueprints

- **Jobsite Crew Cap:** A construction site allows a maximum of **4 active builders** (`tope de cuadrilla`) simultaneously to avoid pathfinding congestion.
- **Auto-Assignment:** Idle laborers and unassigned technicians automatically volunteer for active blueprints in their district.
- **Remodeling Without Demolition:** Players can modify existing declared buildings in first-person mode by aiming at the door and pressing `Shift + B`. The volume and bed assignments recalculate dynamically without demolishing walls.

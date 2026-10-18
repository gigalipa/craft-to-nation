# Resource Economy, Industries & Power Grid

![First-person industrial complex and resource processing](/assets/fp-industry.webp)

In **Craft to Nation**, raw materials, dynamic fluids, electrical power, and manufactured goods form a tightly coupled physical economy. Every resource features its own crisp pixel-art SVG icon (`IconosHUD.gd`), physical storage limits, strategic reserve quotas, and extraction formulas verified in the simulation engine.

---

## 1. Complete Resource Catalog (Raw & Manufactured)

| Resource | Category | Primary Source | Extraction / Processing Method |
| :--- | :--- | :--- | :--- |
| <ResourceBadge name="Water" category="Essential" /> | Vital / Fluid | Rivers, lakes, seas, aquifers | Pumping Station (`estacion_bombeo`), Extraction Rig & Aqueducts |
| <ResourceBadge name="Food" category="Essential" /> | Vital / Metabolic | Wild fauna, fruit trees, fish shoals | Manual foraging (`60 u`), Hunting/Foraging Post & Fishing Dock |
| <ResourceBadge name="Wood" category="Basic" /> | Construction / Input | Procedural forests | Manual felling (`10 u/trunk cell`) or Lumberjack Post (`maderero`) |
| <ResourceBadge name="Planks" category="Processed" /> | Efficient Timber | Sawmill (`aserradero`) | `1 Wood` → `3 Planks` (3× efficiency when building wooden structures) |
| <ResourceBadge name="Stone" category="Basic" /> | Construction / Input | Surface & subsurface strata | Manual mining (`10 u/block`) or Mine (`mina`) |
| <ResourceBadge name="Stone Blocks" category="Processed" /> | Efficient Masonry | Block Factory (`fabrica_bloques`) | `1 Stone` → `3 Stone Blocks` (3× efficiency when building masonry) |
| <ResourceBadge name="Earth" category="Basic" /> | Leveling / Adobe / Glass | Surface soil (`GROSOR_TIERRA`) | Manual digging (`1 u/block`) or Mine |
| <ResourceBadge name="Iron" category="Mineral" /> | Metallurgy / Framing | Mid veins (`depth 8–16`) | Level II+ Mine (`10 u/block`) |
| <ResourceBadge name="Copper" category="Mineral" /> | Wiring / Electronics | Mid veins (`depth 8–16`) | Level II+ Mine (`10 u/block`) |
| <ResourceBadge name="Coal" category="Energy" /> | Smelting / Thermal Power | Subsurface seams or Charcoal Kiln | Mine (`10 u/block`) or Charcoal Kiln (`3 Wood` → `1 Coal`) |
| <ResourceBadge name="Rare Earths" category="Advanced" /> | High-Tech Industry | Deep strata (`depth 16–24`) | Level III Mine (`10 u/block`) |
| <ResourceBadge name="Refined Minerals" category="Advanced" /> | Advanced Components | Rare Earth Refinery | `3 Rare Earths` → `1 Refined Mineral` |
| <ResourceBadge name="Steel" category="Alloy" /> | High-Rises / Fortifications | Steel Mill (`siderurgica`) | `3 Iron + 4 Coal` → `2 Steel` |
| <ResourceBadge name="Crude Oil" category="Fluid" /> | Petrochemicals / Power | Deep oil reservoirs (3 layers above bedrock) | Subsurface Extraction Rig (`centro_extraccion`) & pipelines |
| <ResourceBadge name="Fuel" category="Fluid" /> | Liquid Hydrocarbon | Oil Refinery / Synthetic Fuel Producer | `2 Crude Oil` → `1 Fuel` or `3 Coal + 1 Water` → `2 Fuel` |
| <ResourceBadge name="Energy" category="Power Grid" /> | Industrial Power | Thermoelectric Power Plant | Continuous grid generation (`kW` / `MW`), up to `20 E/h` per plant |

---

## 2. Peripheral Extraction Outposts & Level Multipliers

Extraction rates represent hourly output per worker at neutral morale (`Morale = 50`, `1.0×` multiplier) and recalculate every `6 in-game hours` based on physical blocks remaining in the operating radius:

| Peripheral Outpost | Output Resource | Base Rate (u/worker/h) | Max Crew | Local Storage | Footprint & Range |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Lumberjack Post** (`maderero`) | <ResourceBadge name="Wood" /> | **5.0** × density × level | 5 workers | 1,000 u | `3×4` cells / Radius 12 |
| **Mine** (`mina`) | <ResourceBadge name="Stone" /> <ResourceBadge name="Iron" /> <ResourceBadge name="Copper" /> <ResourceBadge name="Coal" /> <ResourceBadge name="Rare Earths" /> <ResourceBadge name="Earth" /> | **5.0** minerals / **1.0** earth (× vein fraction) | 5 workers | 1,000 u | `5×5` cells / Radius 6 / Depth **8 / 16 / 24** (Levels I–III) |
| **Hunting & Foraging** (`caza_recoleccion`) | <ResourceBadge name="Food" /> | **17.0** game + **10.0** fruit (`~12.2 u/h` avg) | 7 workers | 1,000 u | `4×4` cells / Radius 12 |
| **Fishing Dock** (`pesca_frutos_mar`) | <ResourceBadge name="Food" /> | **17.0** fish + **3.0** algae (`~8.6 u/h` avg) | 7 workers | 1,000 u | `4×6` cells (dock over water) / Radius 25 |
| **Pumping Station** (`estacion_bombeo`) | <ResourceBadge name="Water" /> | **2.0** u/h per operator | 3 technicians | 500 u | `4×6` cells (water dock + layer-4 fluid port) |
| **Extraction Center** (`centro_extraccion`) | <ResourceBadge name="Crude Oil" /> / <ResourceBadge name="Water" /> | **2.0** u/h per operator | 3 technicians | 500 u | `5×5` cells (vertical drill below center `(2,2)`) |

> [!NOTE] Outpost Levels (I, II, III), Physical Depletion & Fluid Physics
> - For **Lumberjack**, **Hunting/Foraging**, and **Fishing** posts, upgrading levels multiplies gathering speed directly: **Level I = `1.0×`**, **Level II = `1.5×`**, **Level III = `2.0×`**. A Lumberjack Post is flagged as **Depleted** when output falls below `0.5 wood/h` per gatherer.
> - For **Mines**, upgrading levels expands **vertical excavation depth**: **Level I = `8` layers** (stone & shallow coal), **Level II = `16` layers** (reaches iron & copper veins), **Level III = `24` layers** (reaches deep rare earths). Every mined block yields **10 units** (`1 u` for earth) and is physically removed from the underground grid while preserving the top `2` subsurface layers so surface terrain never collapses.
> - **Subsurface Fluid Physics:** As water or crude oil blocks are pumped out, remaining liquid settles downward and laterally by gravity (spread range `7` in rivers, `5` in lakes, and `3` for crude oil with `0.20` viscosity).

---

## 3. Natural Block Yields, Placement Costs & Reserve Quotas

When placing blocks manually or building blueprints, `Ciudad.consumir_costo()` automatically prioritizes processed materials (**Planks** and **Stone Blocks**) before consuming raw wood or stone:

| Placeable Block | Stockpile Resource | Cost per Block | Processed Material Efficiency |
| :--- | :--- | :--- | :--- |
| **`tierra`** | <ResourceBadge name="Earth" /> | `1 Earth` | — |
| **`adobe`** | <ResourceBadge name="Earth" /> | `5 Earth` | — |
| **`vidrio`** | <ResourceBadge name="Earth" /> | `1 Earth` | — |
| **`bloque_madera`** | <ResourceBadge name="Planks" /> or <ResourceBadge name="Wood" /> | `1 Plank` (or `5 Wood`) | **1 Wood → 3 Planks** (15× raw timber building efficiency) |
| **`puerta` / `cama` / `baul`** | <ResourceBadge name="Planks" /> or <ResourceBadge name="Wood" /> | `1 Plank` (or `5 Wood`) per cell | Door = 2 vertical cells; Bed = 2 horizontal cells; Chest = 1 cell |
| **`bloque_piedra`** | <ResourceBadge name="Stone Blocks" /> or <ResourceBadge name="Stone" /> | `1 Stone Block` (or `5 Stone`) | **1 Stone → 3 Stone Blocks** (15× raw stone building efficiency) |
| **`estructura_hierro`** | <ResourceBadge name="Iron" /> | `5 Iron` | — |
| **`bloque_acero`** | <ResourceBadge name="Steel" /> | `3 Steel` | — |

### Raw Material Reserve Quotas (`[0, 50, 100, 250, 500] u`)
To prevent the **Sawmill**, **Charcoal Kiln**, or **Block Factory** from draining all raw wood or stone needed for direct construction, you can set a **minimum reserve quota** (`0`, `50`, `100`, `250`, or `500 u`) in the **Stockpile Window** (`VentanaAlmacen`) or facility panel. Haulers will only supply factories with surplus above the protected threshold.

---

## 4. The 8 Industrial & Power Facilities (Zone B)

All refineries feature a **1,000-unit local storage buffer** (`300 u` in the Thermoelectric Plant) and a maximum crew of **4 workers** (**Technicians** in Type-2 plants; **Specialists** in Type-3 plants):

| Industrial Facility | Tier / Crew | Footprint | Batch Recipe (Inputs → Output) | Batches/h per Worker | Power Consumption / Generation |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Sawmill** (`aserradero`) | Type 2 (4 Technicians) | `5×6` | `1 Wood` → `3 Planks` | `0.5 batches/h` (`1.5 planks/h`) | `0 E` |
| **Block Factory** (`fabrica_bloques`) | Type 2 (4 Technicians) | `5×6` | `1 Stone` → `3 Stone Blocks` | `0.5 batches/h` (`1.5 blocks/h`) | `0 E` |
| **Charcoal Kiln** (`carbonera`) | Type 2 (4 Technicians) | `5×5` | `3 Wood` → `1 Coal` | `2.0 batches/h` (`2.0 coal/h`) | `0 E` |
| **Steel Mill** (`siderurgica`) | Type 2 (4 Technicians) | `5×5` | `3 Iron + 4 Coal` → `2 Steel` | `2.0 batches/h` (`4.0 steel/h`) | `0 E` |
| **Rare Earth Refinery** (`refineria_tierras_raras`) | Type 3 (4 Specialists) | `5×5` | `3 Rare Earths` → `1 Refined Mineral` | `0.5 batches/h` (`0.5 ref/h`) | `0 E` |
| **Petroleum Refinery** (`refineria_petrolera`) | Type 3 (4 Specialists) | `5×5` | `2 Crude Oil` → `1 Fuel` | `1.0 batch/h` (`1.0 fuel/h`) | Uses **1 E/batch** (Local split cap: `400 Crude / 600 Fuel`) |
| **Fuel Producer** (`productor_combustible`) | Type 3 (4 Specialists) | `5×5` | `3 Coal + 1 Water` → `2 Fuel` | `1.0 batch/h` (`2.0 fuel/h`) | Uses **1 E/batch** |
| **Thermoelectric Plant** (`central_termoelectrica`) | Type 3 (4 Specialists) | `5×5` | Burns `Fuel` (`1:1`), `Crude` (`1.5:1`), or `Coal` (`2:1`) | Up to `5.0 E/h` per specialist | Generates up to **20 E/h** (protects `500 Coal` reserve in Central Stockpile) |

> [!IMPORTANT] Electrical Grid in kW / MW & Tri-Color HUD Indicator
> The top bar (`BarraSuperior.gd`) displays real-time electrical balance formatted in **kW / MW** alongside an interactive lightning bolt icon:
> - **Gold:** Power surplus or balanced active generation (`factor_energia = 1.0`).
> - **Gray:** Zero electrical demand and zero generation.
> - **Red:** Power deficit (`factor_energia = generated / demanded`), scaling down production across all energy-dependent refineries proportionally. Clicking the lightning bolt opens the **Energy Window** (`VentanaEnergia`) with a per-building breakdown.


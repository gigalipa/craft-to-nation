# Resource Economy, Industries & Power Grid

![First-person industrial complex and resource processing](/assets/fp-industry.webp)

In **Craft to Nation**, raw materials, dynamic fluids, electrical power, and manufactured goods form a tightly coupled physical economy. Every resource features its own crisp pixel-art SVG icon (`IconosHUD.gd`), strict alphabetical A–Z sorting in `VentanaAlmacen`, configurable central reserve quotas, and extraction formulas verified in the simulation engine.

---

## 1. Complete Resource Catalog (Raw & Manufactured)

| Resource | Category | Primary Source | Extraction / Processing Method |
| :--- | :--- | :--- | :--- |
| <ResourceBadge name="Steel" category="Alloy" /> | High-Rises / Pipelines | Steelworks (`1 -> 3 -> 1`) | `3 Iron + 4 Coal` → `2 Steel` |
| <ResourceBadge name="Water" category="Essential" /> | Vital / Fluid | Rivers, lakes, seas, aquifers | Pumping Station (`1 -> 2 -> 5`), Extraction Center & Aqueducts |
| <ResourceBadge name="Stone Blocks" category="Processed" /> | Efficient Masonry | Block Factory (`1 -> 3 -> 4`) | `1 Stone` → `3 Stone Blocks` (consumed first when building with stone) |
| <ResourceBadge name="Coal" category="Energy" /> | Smelting / Thermal Power | Subsurface seams or Charcoal Kiln | Mine (`10 u/block`) or Charcoal Kiln (`1 -> 3 -> 5`: `3 Wood` → `1 Coal`) |
| <ResourceBadge name="Copper" category="Mineral" /> | Wiring / Electronics | Mid veins (`depth 8–16`) | Level II+ Mine (`10 u/block`) |
| <ResourceBadge name="Fuel" category="Fluid" /> | Liquid Hydrocarbon | Oil Refinery / Fuel Producer | `2 Crude Oil` → `1 Fuel` or `3 Coal + 1 Water` → `2 Fuel` |
| <ResourceBadge name="Food" category="Essential" /> | Vital / Metabolic | Wild fauna, fruit trees, fish shoals | Manual harvesting with <kbd>E</kbd> (`60 u`), Hunting Post & Fishing Dock |
| <ResourceBadge name="Crude Oil" category="Fluid" /> | Petrochemicals / Power | Deep reservoirs (`depth >= 4`) | Extraction Center (`1 -> 2 -> 6`) with physical iron drill column |
| <ResourceBadge name="Iron" category="Mineral" /> | Metallurgy / Framing | Mid veins (`depth 8–16`) | Level II+ Mine (`10 u/block`) |
| <ResourceBadge name="Wood" category="Basic" /> | Construction / Input | Procedural forests | Manual felling with <kbd>Left Click</kbd> (`10 u/cell`) or Lumber Camp (`1 -> 2 -> 2`) |
| <ResourceBadge name="Refined Minerals" category="Advanced" /> | Advanced Components | Rare Earth Refinery (`1 -> 3 -> 2`) | `3 Rare Earths` → `1 Refined Mineral` |
| <ResourceBadge name="Stone" category="Basic" /> | Construction / Input | Surface & subsurface strata | Manual mining (`10 u/block`) or Mine (`1 -> 2 -> 3`) |
| <ResourceBadge name="Planks" category="Processed" /> | Efficient Timber | Sawmill (`1 -> 3 -> 3`) | `1 Wood` → `3 Planks` (consumed first when building with wood) |
| <ResourceBadge name="Earth" category="Basic" /> | Leveling / Adobe / Glass | Surface soil (`GROSOR_TIERRA`) | Manual digging (`1 u/block`) or Mine |
| <ResourceBadge name="Rare Earths" category="Advanced" /> | High-Tech Industry | Deep strata (`depth 16–24`) | Level III Mine (`10 u/block`) |
| <ResourceBadge name="Energy" category="Power Grid" /> | Industrial Power | Thermal Power Plant (`1 -> 3 -> 8`) | Continuous grid generation (`kW`), up to `20 E/h` per plant |

---

## 2. Peripheral Extraction Outposts (`1 -> 2 -> 1..6`)

All peripheral outposts must be placed **outside the Urban Core's Zone of Influence**:

| Menu Path | Peripheral Outpost | Output Resource | Base Rate (u/worker/h) | Crew | Local Storage | Footprint & Placement Rules |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`1-2-1`** | **Hunting & Foraging** (`caza_recoleccion`) | <ResourceBadge name="Food" /> | **17.0** game + **10.0** fruit (`~12.2 u/h` avg) | Up to 7 laborers | 1,000 u | `4×4` cells / Radius 12 |
| **`1-2-2`** | **Lumber Camp** (`maderero`) | <ResourceBadge name="Wood" /> | **5.0** × density × level | Up to 5 laborers | 1,000 u | `3×4` cells / Radius 12 |
| **`1-2-3`** | **Mine** (`mina`) | <ResourceBadge name="Stone" /> <ResourceBadge name="Iron" /> <ResourceBadge name="Copper" /> <ResourceBadge name="Coal" /> <ResourceBadge name="Rare Earths" /> <ResourceBadge name="Earth" /> | **5.0** minerals / **1.0** earth (× vein fraction) | Up to 5 miners | 1,000 u | `5×5` cells / Radius 6 / Depth **8 / 16 / 24** |
| **`1-2-4`** | **Fishing Dock** (`pesca_frutos_mar`) | <ResourceBadge name="Food" /> | **17.0** fish + **3.0** algae (`~8.6 u/h` avg) | Up to 7 laborers | 1,000 u | `4×6` cells (half land / half water) / Radius 25 |
| **`1-2-5`** | **Pumping Station** (`estacion_bombeo`) | <ResourceBadge name="Water" /> | **2.0** u/h per technician | 3 technicians (0 haulers) | 500 u | `4×6` cells (requires **`>= 2` blocks of water depth** under pier; `puerto_agua_out` at `Y + 4`) |
| **`1-2-6`** | **Extraction Center** (`centro_extraccion`) | <ResourceBadge name="Crude Oil" /> / <ResourceBadge name="Water" /> | **2.0** u/h per technician | 3 technicians (0 haulers) | 500 u | `5×5` cells over underground pool (adds dynamic `estructura_hierro` cost by depth and builds physical drill column) |

> [!NOTE] Outpost Levels (I, II, III) & Minimum Worker Rank Rule
> - In **Lumber**, **Hunting**, and **Fishing** posts, upgrading levels multiplies speed (**Level I = `1.0×`**, **Level II = `1.5×`**, **Level III = `2.0×`**). In **Mines**, it expands excavation depth (**8 / 16 / 24 layers**).
> - **Minimum Worker Rank Rule:** An outpost's active level equals the **lowest rank among its assigned gatherers**. If a Level II Mine (staffed by 1 Technician) also hires 1 Laborer (`Obrero`), the outpost allows hiring them and cleanly downgrades to **Level I** until all assigned gatherers are at least Technicians.

---

## 3. Construction Costs & Central Reserve Control (`0 / 50 / 100 / 250 / 500 u`)

When placing blocks by hand or supplying construction sites, `Ciudad.gd` **deducts processed materials first** (`Planks` and `Stone Blocks`) before spending raw wood or stone, and sums both stocks when reporting total availability:

| Placeable Block | Stockpile Resource | Cost per Block | Processed Material Efficiency |
| :--- | :--- | :--- | :--- |
| **`tierra` / `vidrio`** | <ResourceBadge name="Earth" /> | `1 Earth` | — |
| **`adobe`** | <ResourceBadge name="Earth" /> | `5 Earth` | — |
| **`bloque_madera` / `puerta` / `cama` / `baul`** | <ResourceBadge name="Planks" /> or <ResourceBadge name="Wood" /> | `1 Plank` (or `5 Wood`) per cell | **1 Wood → 3 Planks** (15× raw timber building efficiency) |
| **`bloque_piedra`** | <ResourceBadge name="Stone Blocks" /> or <ResourceBadge name="Stone" /> | `1 Stone Block` (or `5 Stone`) | **1 Stone → 3 Stone Blocks** (15× raw stone building efficiency) |
| **`estructura_hierro`** | <ResourceBadge name="Iron" /> | `5 Iron` | — |
| **`bloque_acero`** | <ResourceBadge name="Steel" /> | `3 Steel` | — |

### Central Reserve Selector in Refineries & Power Plants
In the `PanelPuesto` of every refinery and thermal power plant, below the production line appears the **`Reserva central:`** row with a button that cycles through **`Sin reserva (0 u)` → `50 u` → `100 u` → `250 u` → `500 u`**. Facility haulers only withdraw surplus above the configured reserve (`stock_central - reserva`), protecting your raw construction stock against over-refining.

---

## 4. Industrial & Power Facilities (`1 -> 3 -> 1..9` on Industrial Zone)

All refineries require **Technicians (`Técnicos`)** graduated from the Technical School (`1 -> 4 -> 1`) to operate. Facilities `6`, `7`, and `8` unlock upon completing **Applied Metallurgy** (`Metalurgia Aplicada`) at the University (`1 -> 4 -> 3`):

| Menu Path | Industrial Facility | Footprint | Crew | Batch Recipe (Inputs → Output) | Batches/h per Worker | Power / Ports |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`1-3-1`** | **Steelworks** (`siderurgica`) | `5×5` | 4 Technicians + Haulers | `3 Iron + 4 Coal` → `2 Steel` | `2.0 batches/h` (`4.0 steel/h`) | `0 E` |
| **`1-3-2`** | **Rare Earth Refinery** (`refineria_tierras_raras`) | `5×5` | 4 Technicians + Haulers | `3 Rare Earths` → `1 Refined Mineral` | `0.5 batches/h` (`0.5 ref/h`) | `0 E` |
| **`1-3-3`** | **Sawmill** (`aserradero`) | `5×6` | 4 Technicians + Haulers | `1 Wood` → `3 Planks` | `0.5 batches/h` (`1.5 planks/h`) | `0 E` |
| **`1-3-4`** | **Block Factory** (`fabrica_bloques`) | `5×6` | 4 Technicians + Haulers | `1 Stone` → `3 Stone Blocks` | `0.5 batches/h` (`1.5 blocks/h`) | `0 E` |
| **`1-3-5`** | **Charcoal Kiln** (`carbonera`) | `5×5` | 4 Technicians + Haulers | `3 Wood` → `1 Coal` | `2.0 batches/h` (`2.0 coal/h`) | `0 E` |
| **`1-3-6`** | **Oil Refinery** (`refineria_petrolera`) | `5×5` | 4 Technicians (0 haulers: pipeline fed) | `2 Crude Oil` → `1 Fuel` | `1.0 batch/h` (`1.0 fuel/h`) | Uses **1 E/batch** (Local split cap: `400 Crude / 600 Fuel`) |
| **`1-3-7`** | **Fuel Producer** (`productor_combustible`) | `5×5` | 4 Technicians + Haulers (haul solid `coal` only) | `3 Coal + 1 Water` → `2 Fuel` | `1.0 batch/h` (`2.0 fuel/h`) | Uses **1 E/batch** (`puerto_agua_in` + `puerto_combustible_out`) |
| **`1-3-8`** | **Thermal Power Plant** (`central_termoelectrica`) | `5×5` | 4 Technicians (+ Haulers in `[Carbón]` mode) | Selector: `[Carbón]` (`2:1`), `[Crudo]` (`1.5:1`), or `[Combustible]` (`1:1`) | Up to `5.0 E/h` per technician | Generates up to **20 E/h** (switching to `[Combustible]` or `[Crudo]` releases haulers and feeds via pipeline ports) |
| **`1-3-9`** | **Warehouse** (`almacen`) | `5×5` | 0 workers | **6 fluid ports at `Y=4`** (3 left inputs / 3 right outputs: `agua`, `crudo`, `combustible`) | Shares global fluid pool (`1,000 u/warehouse`) + `+3,000 u` solids | `0 E` |

> [!IMPORTANT] Energy Window (`VentanaEnergia`) & Camera Teleportation
> Clicking the **Energía** button on the topbar (`energia_dorado.svg`, `energia_gris.svg`, or `energia_rojo.svg` with live `kW` readings) opens **`VentanaEnergia`**, displaying total generated capacity, delivered energy, total city demand, and the lists of **Generating Sources** and **Consumer Buildings**. Left-clicking any building in the list **flies the Overhead Camera smoothly (`Tween`) to center directly over that building's coordinates** and opens its side panel for immediate inspection.

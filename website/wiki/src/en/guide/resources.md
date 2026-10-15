# Resource Economy & Production

In *Craft to Nation*, raw materials dictate your settlement's technological expansion and survival. Resource management is governed by realistic extraction ratios, physical transportation constraints, and dynamic environmental depletion.

---

## 1. Core Survival & Construction Resources

The colony relies on four foundational primary resources:

### Water (Agua)
- **Primary Source:** Surface Pumping Stations (`estacion_bombeo`) on rivers, lakes, and oceans; or deep aquifer wells.
- **Base Rate:** **2.0 fluid units/hour** continuous pumping rate per station.
- **Role:** Direct colonist hydration, industrial coolant for power plants, and primary catalyst in chemical fuel production.

### Food (Comida)
- **Primary Sources:** Hunting & Foraging Posts on land; Fishing Docks over connected water bodies.
- **Base Rate:** 
  - **Hunting & Foraging:** 17.0/h (game fauna) + 10.0/h (berries/fruit), averaging **~12.2 food/h** per active gatherer in temperate zones.
  - **Fishing & Sea Harvesting:** 17.0/h (fish) + 3.0/h (algae), averaging **~8.6 food/h** per fisherman.
- **Role:** Metabolic fuel for colonists. Caloric consumption varies heavily based on assigned profession (1.0 to 5.0 food/h).

### Wood (Madera)
- **Primary Source:** Lumberjack Outpost (`puesto_maderero`).
- **Base Rate:** **5.0 units/worker/hour** base extraction rate.
- **Dynamic Formula:** $\text{Hourly Rate} = 5.0 \times \text{Forest Density} \times \text{Level Multiplier}$. Depletion threshold triggers when yield drops below $0.5\text{ wood/h}$.
- **Role:** Fundamental structural framing, starter tool shafts, charcoal production, and processed timber planks.

### Stone (Piedra)
- **Primary Source:** Surface & Subsurface Stone Mines (`mina_piedra`).
- **Base Rate:** **5.0 units/worker/hour** base extraction rate.
- **Role:** Heavy masonry, paved roads, defensive ramparts, and advanced machinery housing.

---

## 2. Mineral & Energy Commodities

As your industrial sector matures, secondary raw materials become mandatory:

| Mineral / Resource | Base Rate (units/worker/h) | Mining Depth | Primary Applications |
| :--- | :--- | :--- | :--- |
| **Earth (Tierra)** | 1.0 | Surface ($Y \ge 0$) | Terrain leveling, glass manufacturing, soil embankments. |
| **Iron (Hierro)** | 5.0 | Mid depth ($Y -8$ to $-16$) | Iron structural beams, steel alloying, tools, heavy armaments. |
| **Copper (Cobre)** | 5.0 | Mid depth ($Y -8$ to $-16$) | Electrical wiring, power distribution grids, mechanical switches. |
| **Coal (Carbón)** | 5.0 | Shallow & deep seams | Thermal power plant fuel, metallurgical coke for blast furnaces. |
| **Rare Earths (Tierras Raras)**| 5.0 | Deep strata ($Y \le -16$) | High-tier electronics, telecommunication relays, computing cores. |
| **Crude Oil (Crudo)** | 2.0 fluid/h | Deep subsurface wells | Chemical refining, liquid hydrocarbon fuel, industrial plastics. |

---

## 3. Natural Yield vs. Placement Costs

In *Craft to Nation*, mining a natural voxel block yields dense raw bulk materials. Placing structural blocks draws from your centralized inventory:

| Material | Natural Block Yield (Extraction) | Structural Placement Item | Placement Cost (Stockpile) |
| :--- | :--- | :--- | :--- |
| **Earth** | 1 Earth unit | `tierra` / `tierra_compactada` | 1 Earth |
| **Stone** | 10 Stone units | `bloque_piedra` | 5 Stone (or 1 Processed Block) |
| **Iron** | 10 Iron units | `estructura_hierro` | 5 Iron |
| **Wood** | 10 Wood units / trunk cell | `bloque_madera` | 5 Wood (or 1 Processed Plank) |
| **Steel** | *Refined only (not mined)* | `bloque_acero` | 3 Steel |
| **Glass** | *Manufactured only* | `vidrio` | 1 Earth |

---

## 4. Industrial Processing & Refining Chains

Raw inputs extracted at peripheral outposts must be processed within **Zone B (Industrial District)** to produce construction-grade components:

```
[ Raw Wood (1) ] ─────► [ Sawmill ] ────────────► [ Planks (3) ]
[ Raw Stone (1) ] ────► [ Block Factory ] ──────► [ Stone Blocks (3) ]
[ Iron (3) + Coal (4) ] ─► [ Steel Mill ] ──────► [ Steel (2) ]
[ Crude Oil (2) ] ────► [ Petroleum Refinery ] ─► [ Fuel (1) ]
[ Coal (3) + Water (1) ] ─► [ Fuel Producer ] ────► [ Fuel (2) ]
```

### Key Refinery Specifications:
- **Sawmill (Aserradero):** Consumes 1 Wood $\rightarrow$ Produces 3 Planks. Rate: 0.5 batches/worker/h. Max crew: 4.
- **Block Factory (Fábrica de Bloques):** Consumes 1 Stone $\rightarrow$ Produces 3 Stone Blocks. Rate: 0.5 batches/worker/h. Max crew: 4.
- **Steel Mill (Siderúrgica):** Consumes 3 Iron + 4 Coal $\rightarrow$ Produces 2 Steel. Rate: 2.0 batches/worker/h. Max crew: 4.
- **Charcoal Kiln (Carbonera):** Consumes 3 Wood $\rightarrow$ Produces 1 Coal. Rate: 2.0 batches/worker/h. Max crew: 4.
- **Petroleum Refinery:** Consumes 2 Crude Oil $\rightarrow$ Produces 1 Fuel. Rate: 1.0 batch/worker/h. Energy cost: 1 unit/batch.

---

## 5. Storage Hierarchy & Capacity Limitations

Bottlenecks occur when resources cannot be moved quickly enough from extraction outposts into central storage:

```
  ┌────────────────────────────────┐
  │   Extraction Outpost Buffer    │
  │     Cap: 1,000 units total     │
  └───────────────┬────────────────┘
                  │
                  ▼ (Haulers: 150 units/trip)
  ┌────────────────────────────────┐
  │   Central Stockpile (Core)     │
  │     Base: 1,000 gen / 10k food │
  │     (+100/+400 per chest)      │
  └────────────────────────────────┘
```

1. **Local Outpost Buffers (1,000 units):** Every mine, lumberjack post, or hunter lodge has an integrated local chest holding up to 1,000 units of extracted bulk items. Once this buffer reaches 1,000, workers immediately halt extraction until haulers pick up batches.
2. **Central Stockpile (Núcleo Urbano):**
   - 500 base per raw commodity (expanded to **1,000 units** upon Urban Core declaration).
   - 5,000 base food storage (expanded to **10,000 units** upon Core declaration).
   - Expands dynamically with **+100 general capacity** and **+400 food capacity** for every residential chest placed inside recognized civic dwellings.
3. **Dedicated Warehouses:** Specialized storage depots can be established in the Industrial District to store surplus iron, steel, and manufactured parts.

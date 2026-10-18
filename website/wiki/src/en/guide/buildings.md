# Buildings, Urban Levels & Storage Infrastructure

![Overhead tactical camera and district planning](/assets/hud-camara-cenital.png)

In **Craft to Nation**, architectural construction is a physical simulation system. Every structure obeys volumetric validation rules (`ValidadorEdificios.gd`), bed density ratios (`x_cama`), floor/bed caps dictated by the settlement's **Urban Level**, and configurable construction priorities.

---

## 1. Territorial Building Classification

Structures are organized into three mutually exclusive territorial zones across the `200×200` voxel world:

| District | Building Category | Engine Types | Placement Rule |
| :--- | :--- | :--- | :--- |
| **Zone A (Residential, Civic & Academic)** | Housing, Warehouses, Schools, University | Residential (`blueprint`), `almacen` (`5×5`, `+3,000 u`), `escuela_tecnica`, `escuela_especialistas`, `universidad` | Inside the Urban Core's Area of Influence (`Radius 30`, `61×61` cells) |
| **Zone B (Industrial & Power)** | Type-2 & Type-3 Refineries, Power Plant | `aserradero`, `fabrica_bloques`, `carbonera`, `siderurgica`, `refineria_tierras_raras`, `refineria_petrolera`, `productor_combustible`, `central_termoelectrica` | Contiguous Zone B polygon inside the Area of Influence |
| **Wild Periphery** | Extraction & Fluid Pumping Posts | `maderero` (`3×4`), `mina` (`5×5`), `caza_recoleccion` (`4×4`), `pesca_frutos_mar` (`4×6`), `estacion_bombeo` (`4×6`), `centro_extraccion` (`5×5`) | Outside Zones A/B, placed directly on forests, mineral veins, coastlines, or oil wells |

---

## 2. Urban Levels (1 to 3), Housing Limits & University Research

As you upgrade your city's structural materials (block sophistication index) and complete technologies at the **University** (`universidad`, `5×5` stone building, up to 3 researchers generating `1.0 researcher_hour/h` each), your city advances in **Urban Level**, unlocking taller residential buildings and reducing the pioneer avatar's hourly food consumption:

| Urban Level | Stage Name | Max Floors per House | Max Beds per Floor | Max Beds per Building | Avatar Food Rate | Unlock Requirements (`Ciudad.gd`) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Level 1** | Rudimentary Settlement | **2 floors** | **2 beds/floor** | **4 beds** | `5.0 food/h` | Default starting tier |
| **Level 2** | Productive Settlement | **4 floors** | **4 beds/floor** | **16 beds** | `4.0 food/h` | Avg. sophistication `>= 1.7` + min `3` Type-2 plants + **Applied Metallurgy** (`300 Iron`, `200 Wood`, `20 res_h`) |
| **Level 3** | Technified Metropolis | **8 floors** | **4 beds/floor** | **32 beds** | `3.0 food/h` (`2.0` in town hall) | Avg. sophistication `>= 2.5` + min `3` Type-3 plants + **Industrial Automation** (`800 Iron`, `100 Wood`, `50 res_h`) |

### Population Density per Bed (`x_cama`) & Training Schools (`Zone A`)
| Social Class / Role | Residents per Bed (`x_cama`) | Training / Origin |
| :--- | :--- | :--- |
| **Citizen (`ciudadano`)** | **5** colonists / bed | Base gatherer / hauler |
| **Unemployed (`desempleado`)** | **4** colonists / bed | Idle pool awaiting assignment |
| **Worker (`obrero`)** | **4** colonists / bed | Extraction & construction workforce |
| **Technician (`tecnico`)** | **3** colonists / bed | **Technical School** (`escuela_tecnica`, `5×5` adobe, **24h** training: 1 bed of 4 Workers → 1 bed of 3 Technicians) |
| **Military (`militar`)** | **3** colonists / bed | Garrison defense |
| **Specialist (`especialista`)** | **2** colonists / bed | **Specialist School** (`escuela_especialistas`, `5×5` stone, **48h** training: 1 bed of 3 Technicians → 1 bed of 2 Specialists) |
| **Researcher (`investigador`)** | **1** colonist / bed | University faculty |

---

## 3. Peripheral Outpost Levels (`I`, `II`, `III`) & Level Regression

The four classic extraction posts (`mina`, `maderero`, `caza_recoleccion`, `pesca_frutos_mar`) display their level in Roman numerals (**`I`**, **`II`**, **`III`**) along with a compass distance indicator to the Urban Core (`🧭 Distancia al núcleo: X celdas`) inside `PanelPuesto.gd`:

| Outpost Level | Workforce Requirement | Effect on Lumberjack / Hunting / Fishing | Effect on Mine (`5×5`) |
| :--- | :--- | :--- | :--- |
| **Level I** | Workers (`obrero`) | Base speed **`1.0×`** | Excavates down to **8 layers** deep (stone & shallow coal) |
| **Level II** | Requires at least **1 Technician** (post-*Applied Metallurgy*) | Improved speed **`1.5×`** | Excavates down to **16 layers** deep (reaches iron & copper veins) |
| **Level III** | Requires at least **1 Specialist** (post-*Industrial Automation*) | Advanced speed **`2.0×`** | Excavates down to **24 layers** deep (reaches rare earths) |

> [!WARNING] Automatic Level Regression
> If you unassign the last Specialist from a **Level III** outpost, the outpost automatically regresses to **Level II** (or to **Level I** if no Technicians remain assigned either).

---

## 4. Storage Hierarchy & Dedicated Warehouses

```
[Outpost Buffer (1,000 u) / Pumping Rig (500 u) / Refinery (1,000 u)]
                                  ↓
           [Civic Haulers (150 u/trip) or Fluid Pipeline Grid]
                                  ↓
                     [Central Stockpile (Ciudad.almacen)]
                       • Base General: 500 u (×2 = 1,000 u with Urban Core)
                       • Base Food: 5,000 u (×2 = 10,000 u with Urban Core)
                       • Residential Chest Bonus: +100 u general / +400 u food
                       • Dedicated Warehouse Bonus (5×5 in Zone A): +3,000 u
```

- **Residential Chests (`BONO_BAUL`):** Every chest placed inside a validated house adds **+100 u** to general capacity and **+400 u** to food capacity. Inspect chests in first-person mode with <kbd>E</kbd> (`VentanaBaul`).
- **Dedicated Warehouse (`almacen`):** A `5×5` stone building placed in **Zone A** (`240 wood + 160 stone` equivalent). Adds **+3,000 units** of general storage capacity, features **2 front doors** (input/output), and provides **6 fluid ports** on layer 4 to interface directly with aqueducts and pipelines.

---

## 5. Construction Crews, Priorities & Non-Destructive Remodeling

- **Worksite Crew Cap (`Obras.gd`):** Every construction, level upgrade, or demolition site accepts up to **4 simultaneous builders** (`MAX_CONSTRUCTORES_POR_OBRA = 4`), placing or removing blocks at `2 blocks/s` per worker.
- **Work Priority Selector (`High`, `Normal`, `Low`):** Both building worksites and pending road segments (`ConstructorVias.gd`) allow toggling priority between **High (`▲▲▲`)**, **Normal (`▲▲`)**, and **Low (`▲`)** so available laborers tackle critical infrastructure first.
- **Non-Destructive Remodeling (<kbd>Shift</kbd> + <kbd>B</kbd>):** Aim at the main door of any declared building in first-person mode and press <kbd>Shift</kbd> + <kbd>B</kbd> to reopen it for manual block editing while keeping its residents in a protected buffer until you re-declare it with <kbd>B</kbd>.


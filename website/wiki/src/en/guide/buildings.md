# Buildings, Urban Levels & Storage Infrastructure

![Overhead tactical camera and district planning](/assets/hud-camara-cenital.png)

In **Craft to Nation**, architectural construction is a physical simulation system. Every structure obeys volumetric validation rules (`ValidadorEdificios.gd`), bed density ratios (`x_cama`), floor/bed caps dictated by the settlement's **Urban Level**, a strict academic unlock chain, and a 5-tier construction priority dispatch hierarchy.

---

## 1. Territorial Building Classification & Menu Paths (`1 -> 1..4`)

Structures are organized into three mutually exclusive territorial zones across the `200×200` voxel world:

| District (`Zone Menu`) | Building Category (`Build Menu`) | Engine Facilities | Placement Rule |
| :--- | :--- | :--- | :--- |
| **Residential Zone (`2 -> 1`)** | **Residential (`1 -> 1`)** & **Research (`1 -> 4`)** | Saved Houses (`Residencia [beds]x[chests]`, slots `1`–`5`), `escuela_tecnica` (`1-4-1`), `escuela_especialistas` (`1-4-2`), `universidad` (`1-4-3`) | Inside the Urban Core's Area of Influence (`Radius 30`, `61×61` cells) |
| **Industrial Zone (`2 -> 2`)** | **Industrial (`1 -> 3`)** | `siderurgica` (`1`), `refineria_tierras_raras` (`2`), `aserradero` (`3`), `fabrica_bloques` (`4`), `carbonera` (`5`), `refineria_petrolera` (`6`), `productor_combustible` (`7`), `central_termoelectrica` (`8`), **`almacen` (`9`)** | Painted Industrial sector inside the Area of Influence |
| **Wild Periphery** | **Peripheral (`1 -> 2`)** | `caza_recoleccion` (`1`), `maderero` (`2`), `mina` (`3`), `pesca_frutos_mar` (`4`), `estacion_bombeo` (`5`), `centro_extraccion` (`6`) | **Outside the Area of Influence** (footprint turns red if hovered inside the city perimeter) |

---

## 2. Urban Levels (1 to 3) & Strict Academic Unlock Chain

| Urban Level | Stage Name | Max Floors per House | Max Beds per Floor | Max Beds per Building | Avatar Food Rate | Unlock Requirements (`Ciudad.gd`) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Level 1** | Rudimentary Settlement | **2 floors** | **2 beds/floor** | **4 beds** | `5.0 food/h` | Default starting tier |
| **Level 2** | Productive Settlement | **4 floors** | **4 beds/floor** | **16 beds** | `4.0 food/h` | Avg. sophistication `>= 1.7` + min `3` Type-2 plants + **Applied Metallurgy** (`300 Iron`, `200 Wood`, `20 res_h`) |
| **Level 3** | Technified Metropolis | **8 floors** | **4 beds/floor** | **32 beds** | `3.0 food/h` (`2.0` in town hall) | Avg. sophistication `>= 2.5` + min `3` Type-3 plants + **Industrial Automation** (`800 Iron`, `100 Wood`, `50 res_h`) |

### Strict Educational & Research Unlock Order (`Residential Zone: 1 -> 4 -> 1..3`)
1. **Technical School (`1 -> 4 -> 1`, `5×5` adobe):** Requires hiring the full quota of **4 Apprentices** (drawn from `Laborers`/`Unemployed`). Once all 4 are physically present at their study desks, progress advances `1 h` per tick (dismissing an apprentice before completion resets progress to `0`). After **24 hours**, the cohort graduates into **3 free Technicians (`Técnicos`)** (occupying 1 shared bed).
2. **Specialist School (`1 -> 4 -> 2`, `5×5` stone):** Requires at least **1 built Technical School**. Trains a full cohort of **3 Apprentice Technicians** for **48 hours** and graduates **2 free Specialists (`Especialistas`)** (3 technicians = 2 specialists = 1 bed).
3. **Interactive University (`1 -> 4 -> 3`, `5×5` stone):** Requires at least **1 built Specialist School**. Hires up to **3 free Specialists**, who transition into **Researchers (`investigador`)**:
   - **Manual Start:** Does not start automatically; click **`[Iniciar Investigación]`** and confirm the upfront resource payment in the modal dialog (`300 Iron + 200 Wood` for *Applied Metallurgy*).
   - **Pause & 100%-Refund Cancellation:** Supports **`[Pausar]`** / **`[Reanudar]`** at any time, or **`[Cancelar]`** which **refunds 100% of the paid iron and wood** back to the central warehouse.
   - Completing `20 researcher-hours` of **Applied Metallurgy** (`Metalurgia Aplicada`) unlocks the **Oil Refinery (`1-3-6`)**, **Fuel Producer (`1-3-7`)**, and **Thermal Power Plant (`1-3-8`)**.

---

## 3. Peripheral Outposts, Roman Badges (`I`, `II`, `III`) & Outpost Chests (`VentanaBaul`)

- **Clean Header & Roman Numeral Badge:** In `PanelPuesto.gd`, outpost level is represented by a Roman numeral vector badge (`romano_1.svg`, `romano_2.svg`, `romano_3.svg`) next to the building icon, and the `"Producción:"` row displays each resource's `16px` vector SVG icon alongside its hourly rate.
- **Minimum Worker Rank Rule:** Hiring 1 Technician in a Mine upgrades it to **Level II**; also hiring 1 Laborer (`Obrero`) in that same Mine is permitted and **cleanly downgrades the outpost to Level I** (the lowest rank among its assigned workers).
- **1st-Person Outpost Chest Interaction (`VentanaBaul` — <kbd>E</kbd> Key):** Walking inside an active peripheral outpost in 1st person and pressing <kbd>E</kbd> on its interior chest opens the centered **`VentanaBaul` (`320×260`)** modal, allowing you to transfer units between the outpost's local buffer and the central warehouse using **`-`**, **`+`**, or **`"Extraer todo"`** (and close immediately with <kbd>E</kbd> or <kbd>Esc</kbd>).

---

## 4. Storage Hierarchy & the Industrial Warehouse (`1 -> 3 -> 9`)

- **Central Stockpile (`Ciudad.almacen`):** Starts with a base cap of `500 u` general / `5,000 u` food, which **doubles (`×2`)** upon declaring the Urban Core (`1,000 u` / `10,000 u`). Every chest placed inside residential houses adds **`+100 u` general** and **`+400 u` food**.
- **Industrial Warehouse (`1 -> 3 -> 9` on Industrial Zone):** A `5×5` stone building that adds **`+3,000 u`** of solid storage capacity and features **6 exterior fluid ports at elevation `Y = 4`** (left wall with 3 inputs and right wall with 3 outputs for `agua`, `crudo`, and `combustible`). In `PanelPuesto`, the 6 ports are grouped by resource into collapsible dropdowns (`⚪ Desconectado`, `🟢 Conectado`, or `🔴 Derrame`), sharing an **instantaneous global fluid pool (`1,000 u` per warehouse)**.

---

## 5. Construction Priorities (`PanelEdificio`) & Dispatch Hierarchy

Selecting any building under construction in View mode (`Esc`) displays the **`[Prioridad: Normal]`** button, which cycles through **`Normal` → `Alta` (High) → `Baja` (Low) → `Normal`**. Free laborers (up to **4 builders per site**) are dispatched strictly following this 5-tier global order:

1. **High Priority Construction** (`Prioridad Alta ▲▲▲`)
2. **Normal Priority Construction** (`Prioridad Normal ▲▲`)
3. **Building and Road Demolitions** (Mode `3`)
4. **Road Laying** (`1 -> 5 -> 1`)
5. **Low Priority Construction** (`Prioridad Baja ▲`)

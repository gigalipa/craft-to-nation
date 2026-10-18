# Beginner's Survival & Settlement Guide

![From pioneer shelter to industrial metropolis](/assets/citycraft-hero.webp)

Welcome to the official beginner's guide for **Craft to Nation**.

In *Craft to Nation*, you begin your journey as an isolated pioneer in a finite, procedurally generated **200×200 voxel world** (max height `y = 130`, with 24 subsurface layers down to unmineable bedrock, two mountain peaks, rivers with active water currents and waterfalls, lakes, and seas). Through manual harvesting, structural engineering, district zoning, and automated logistics, you will transform a fragile campsite into a thriving industrial city.

---

## 1. Dual Controls & Hierarchical Menu Navigation (Micro ↔ Macro)

The game lets you switch seamlessly between your physical avatar in First-Person and the Overhead Tactical Camera via a smooth `0.6s` animated camera flight:

### Global Shortcuts
- <kbd>C</kbd>: **Toggle between First-Person Mode and Overhead Tactical Camera (*City Builder*)**.
- <kbd>M</kbd>: Open / close the analytical **Citizen Morale Window** (`VentanaMoral`).
- <kbd>Esc</kbd>: Close active modal windows, exit active road/deconstruction mode (in 1st person), return to neutral **View** mode (in overhead camera), or release the mouse cursor.

### First-Person Controls (Pioneer Mode)
- <kbd>W</kbd> <kbd>A</kbd> <kbd>S</kbd> <kbd>D</kbd>: Move avatar (with horizontal current push in rivers and at the base of waterfalls).
- <kbd>Space</kbd> / <kbd>Ctrl</kbd>: Jump on land / In deep liquids (`>= 2` blocks deep; in `1`-block shallow water the avatar walks normally), **swim up (<kbd>Space</kbd>)** or **dive down (<kbd>Ctrl</kbd>)**. Submerging your head displays `PanelOxigeno` (`10.0s` autonomy, recovering twice as fast upon surfacing).
- <kbd>Left Click</kbd> (hold): Chop trees (`herr_hacha.svg`, `1.0s` per trunk health point), mine terrain or mineral veins with a progress bar and contextual tool icon (`herr_pala.svg` on dirt `0.4s`; `herr_pico.svg` on stone/coal `1.2s`, iron/copper `1.6s`, rare earths `2.4s`), or dismantle blocks step-by-step if <kbd>G</kbd> deconstruction mode is active.
- <kbd>Right Click</kbd>: Place the block selected in the hotbar (`1`–`0`), supply a targeted ghost construction site by aiming at its ghost blocks or exterior wall, or **drain/dry flooded cells** (`agua` or `crudo`) by placing a solid block directly into the liquid.
- <kbd>1</kbd> – <kbd>9</kbd>, <kbd>0</kbd> / <kbd>Mouse Wheel</kbd>: Select block type in the 10-slot hotbar (`tierra`, `adobe`, `bloque_madera`, `bloque_piedra`, `estructura_hierro`, `vidrio`, `puerta`, `cama`, `baul`, `bloque_acero`).
- <kbd>E</kbd>:
  - **Press:** Open/close doors, or open an active peripheral outpost's chest (`VentanaBaul`, centered `320×260` window with `-`, `+`, and `"Extraer todo"`).
  - **Hold (`2.0s`) on a tree:** **Harvest wild fruit** (`herr_cesta.svg`, yields **60 food units** without chopping down the tree; fruit regrows after `24 in-game hours`).
- <kbd>G</kbd>: Toggle manual on-foot **deconstruction mode** (<kbd>Left Click</kbd> dismantles step-by-step; <kbd>Right Click</kbd> marks/unmarks for demolition).
- <kbd>V</kbd>: Toggle on-foot **road interaction mode**: once active, <kbd>Left Click</kbd> completes an entire `2×2` pending road section at once, and <kbd>Right Click</kbd> instantly demolishes a built `2×2` road section (press <kbd>V</kbd> or <kbd>Esc</kbd> to exit road mode).
- <kbd>B</kbd>: **Declare finished structure** while aiming at its ground-floor exterior entrance door.
- <kbd>Shift</kbd> + <kbd>B</kbd>: **Start non-destructive remodeling** while aiming at the exterior door of an already declared building (reopens it for free editing without losing its status).
- <kbd>L</kbd>: Toggle the avatar's **omnidirectional lantern** (`PanelLampara`) on/off:
  - **Thermal Lantern Mode (`LÁMPARA TÉRMICA🟡`):** When city grid power is `0 E/h`, burns central warehouse supplies in strict priority: **Fuel** (`10 h/u`, 14m range) → **Coal** (`6 h/u`, 10m range) → **Wood** (`5 h/u`, 7m range).
  - **Electric Lantern Mode (`LÁMPARA ELÉCTRICA🟡`):** Once the city generates electricity (`> 0 E/h`), runs on a **72 h battery** (18m bright white light, zero fuel burned); outside the Zone of Influence it discharges at `-1 h` per game hour and recharges rapidly at **`+7.2 h` per game hour** upon returning inside the Zone of Influence.

![First-person shelter construction](/assets/fp-building.webp)

### Overhead Camera Controls (Urban Management & Hierarchical Numeric Menu)
- <kbd>W</kbd> <kbd>A</kbd> <kbd>S</kbd> <kbd>D</kbd>: Horizontal camera panning across the X/Z plane.
- <kbd>Q</kbd> / <kbd>E</kbd>: **Orbital rotation** around the focal point to the left (<kbd>Q</kbd>) or right (<kbd>E</kbd>).
- <kbd>Ctrl</kbd> + <kbd>W</kbd> / <kbd>S</kbd>: **Pitch / Tilt:** Adjust the vertical tilt angle of the camera (`15°` to `85°`).
- <kbd>Shift</kbd> + <kbd>W</kbd> / <kbd>S</kbd>: **Vertical Elevation:** Raise (<kbd>Shift</kbd>+<kbd>W</kbd>) or lower (<kbd>Shift</kbd>+<kbd>S</kbd>) the focal point elevation (`foco.y`) directly.
- <kbd>Mouse Wheel</kbd>: Oblique zoom in / out relative to the focal point.
- <kbd>Ctrl</kbd> + <kbd>Mouse Wheel</kbd>: **Rotate blueprint preview or outpost template in 90° steps**.
- **Hierarchical Numeric Menu Navigation (<kbd>1</kbd> – <kbd>9</kbd>) & Pagination (<kbd>Z</kbd> / <kbd>X</kbd> / <kbd>Esc</kbd>):**
  Number keys navigate hierarchically through the bottom menu (`BarraModos.gd`) by selecting the option corresponding to the current menu depth:
  - <kbd>1</kbd> **Build Menu (`Construir`):**
    - `1` **Residential (`Residencial`):** Slots `1`–`5` for saved blueprints (`Residencia [beds]x[chests]`).
    - `2` **Peripheral (`Periférico`):** `1` Hunting, `2` Lumber, `3` Mine, `4` Fishing, `5` Pumping Station, `6` Extraction Center.
    - `3` **Industrial (`Industrial`):** `1` Steelworks, `2` Rare Earths, `3` Sawmill, `4` Block Factory, `5` Charcoal Kiln, `6` Oil Refinery, `7` Fuel Producer, `8` Thermal Power Plant, `9` Warehouse (`Almacén`).
    - `4` **Research (`Investigación`):** `1` Technical School, `2` Specialist School, `3` University.
    - `5` **Roads (`Vías`):** `1` Trace Road *(in overhead view, road tracing is accessed via `1 -> 5 -> 1`, not the `V` key)*.
    - `6` **Conduits (`Ductos`):** `1` Aqueduct, `2` Pipeline.
  - <kbd>2</kbd> **Zone Menu (`Zonificar`):** `1` Residential Zone, `2` Industrial Zone, `3` Clear Zone.
  - <kbd>3</kbd> **Unified Demolish Mode (`Demoler`):** Left-click buildings to toggle red demolition marks, or trace guided orange road demolitions (double left-click) around 90° corners via Dijkstra.
  - <kbd>Z</kbd> / <kbd>X</kbd>: **Go back one submenu level** or previous page (<kbd>Z</kbd>) / Advance to the **next page** (<kbd>X</kbd>) in menus with more than 9 items.
- **Overhead Mouse Actions:**
  - <kbd>Left Click</kbd>: Set zone/road/conduit corner, place structure, or inspect a building/outpost/conduit in **View** mode (<kbd>Esc</kbd>).
  - <kbd>Double Left Click</kbd>: Confirm road layout (`1 -> 5 -> 1`), guided road demolition (`3`), or elevated conduit path (`1 -> 6`).
  - <kbd>Right Click</kbd>: Cleanly cancel the segment in progress or exit placement mode.

---

## 2. Founding the Urban Core & Residential Lifecycle

```
[Hand-build a 1- or 2-story sealed house with ground door, window, beds & chest]
       ↓ (Aim at ground-floor exterior door and press B)
[1st Declared Building = URBAN CORE + Auto-saves Blueprint "Residencia [beds]x[chests]"]
       ↓ (Overhead Camera [C]: Paint Residential Zone [2 -> 1] & place 1st Residence [1 -> 1])
[1st Habitable Residence spawns with "Colonizable: SÍ" → First Immigrants Arrive]
       ↓ (2nd Residence onward spawns as "Colonizable: NO (24h buffer)")
[Protected buffer relocates residents with 0 homeless during Shift + B remodeling]
```

### Key Residential & Civic Rules
- **The Very First Building Founds the Urban Core:** Declaring your first sealed structure with <kbd>B</kbd> establishes the **Urban Core** (doubling base Central Stockpile caps to `1,000 u` general / `10,000 u` food, projecting the `30-cell` **Zone of Influence**, and saving the design as `Residencia [beds]x[chests]`). Upper floors **do not require exterior doors**.
- **1st Habitable Residence (`Colonizable: SÍ`):** Placing your saved blueprint (`1 -> 1`) on the Residential Zone (`2 -> 1`) and completing it spawns the first habitable house with active immigration (`Colonizable: SÍ`).
- **2nd Residence Onward (`24h Buffer`):** Subsequent residences are automatically built by your unemployed/laborer colonists and spawn with **`Colonizable: NO (apertura en 24 h)`**. Remodeling (<kbd>Shift</kbd> + <kbd>B</kbd>) an occupied house while a buffer house has free beds automatically relocates its residents with **0 homeless colonists**.
- **Row Houses & Core Relocation (`5h`):** Houses can be built wall-to-wall without merging, and you can relocate the Urban Core headquarters to another finished residence (`[Asignar como núcleo urbano]`) with a **5-hour** transition period.

# Beginner's Survival & Settlement Guide

![From pioneer shelter to industrial metropolis](/assets/citycraft-hero.webp)

Welcome to the official beginner's guide for **Craft to Nation**.

In *Craft to Nation*, you begin your journey as an isolated pioneer in a finite, procedurally generated **200×200 voxel world** (max height `y = 130`, with 24 subsurface layers down to unmineable bedrock, two mountain peaks, rivers with active water currents and waterfalls, lakes, and seas). Through manual harvesting, structural engineering, district zoning, and automated logistics, you will transform a fragile campsite into a thriving industrial city.

---

## 1. Dual Controls & Navigation (Micro ↔ Macro)

The game lets you switch seamlessly between your physical avatar in First-Person and the Overhead Tactical Camera via a smooth `0.6s` animated camera flight:

### Global Shortcuts
- <kbd>C</kbd>: **Toggle between First-Person Mode and Overhead Tactical Camera (*City Builder*)**.
- <kbd>M</kbd>: Open / close the **Civic Morale Window** (`VentanaMoral`).
- <kbd>Esc</kbd>: Release / capture mouse cursor or close active modal windows.

### First-Person Controls (Pioneer Mode)
- <kbd>W</kbd> <kbd>A</kbd> <kbd>S</kbd> <kbd>D</kbd>: Move avatar (affected by water current drift when crossing rivers).
- <kbd>Space</kbd>: Jump on land / **Swim upwards** in rivers, lakes, or seas (`10.0s` oxygen bar when head is submerged).
- <kbd>Ctrl</kbd>: **Dive / Swim downwards** underwater.
- <kbd>Left Click</kbd> (hold): Mine blocks with progressive crack overlays (`0.4s` dirt, `1.2s` stone/coal, `1.6s` iron/copper, `2.4s` rare earths), fell trees (`1.0s` per trunk health point), or forage fruit (`2.0s` to harvest `60 u` food without destroying the tree).
- <kbd>Right Click</kbd>: Place the currently selected block from the hotbar.
- <kbd>1</kbd> – <kbd>0</kbd> / <kbd>Mouse Wheel</kbd>: Select block in the 10-slot hotbar (`tierra`, `adobe`, `bloque_madera`, `bloque_piedra`, `estructura_hierro`, `vidrio`, `puerta`, `cama`, `baul`, `bloque_acero`).
- <kbd>E</kbd>: Open/close doors or inspect a residential chest (`VentanaBaul`).
- <kbd>B</kbd>: **Declare Building** (pointing at the ground-floor main entrance door of a sealed structure).
- <kbd>Shift</kbd> + <kbd>B</kbd>: **Non-Destructive Remodeling** (pointing at the main door of an already declared building to temporarily reopen it for manual block editing while preserving its residents in a waiting buffer).
- <kbd>V</kbd>: Manually build a pending road worksite or demolish an existing road cell under your crosshair.
- <kbd>L</kbd>: Toggle the **miner headlamp** (`SpotLight3D`) for night construction or deep underground mining.

![First-person shelter construction](/assets/fp-building.webp)

### Overhead Camera Controls (City Builder Mode)
- <kbd>W</kbd> <kbd>A</kbd> <kbd>S</kbd> <kbd>D</kbd>: Pan camera focus across the horizontal plane.
- <kbd>Q</kbd> / <kbd>E</kbd>: Orbit camera clockwise / counter-clockwise.
- <kbd>Ctrl</kbd> + <kbd>W</kbd> / <kbd>S</kbd>: Adjust vertical camera pitch (`15°` to `85°`).
- <kbd>Shift</kbd> + <kbd>W</kbd> / <kbd>S</kbd>: Raise or lower vertical focus elevation (`foco.y`) to inspect deep mines or multi-story towers.
- <kbd>Mouse Wheel</kbd>: Zoom in / out.
- <kbd>Ctrl</kbd> + <kbd>Mouse Wheel</kbd>: **Rotate blueprint / outpost footprint 90°** before placement.
- <kbd>1</kbd> / <kbd>2</kbd> / <kbd>3</kbd>: Select bottom Mode Bar tools (**1: Build**, **2: Zone A/B**, **3: Demolish**).
- <kbd>V</kbd>: Activate the **Road Laying Tool** (`ConstructorVias`) or guided road network demolition when Demolish mode is active.

---

## 2. Genesis: The First Steps & Constructing an Airtight Shelter

1. **Forage Immediate Sustenance:** Hold <kbd>Left Click</kbd> for `2.0s` on a fruit-bearing tree to gather **60 food units** without cutting it down (regrows after `24 in-game hours`). The pioneer avatar consumes **5.0 food/h** at Urban Level 1 (`4.0/h` at Level 2, `3.0/h` at Level 3).
2. **Harvest Basic Timber & Stone:** Each felled trunk block yields **10 wood units**, and each mined stone block yields **10 stone units**.
3. **Erect an Airtight Shelter:**
   - **Structural Materials Only:** Walls must use structural blocks (`adobe`, `bloque_madera`, `bloque_piedra`, `estructura_hierro`, `vidrio`, or `bloque_acero`). Natural `tierra` (dirt) does **not** count as a valid structural wall.
   - **Airtight Enclosure:** Sealed perimeter walls, complete roof slab, minimum **3-block interior ceiling height**, and **exactly one exterior entrance door on the ground floor**.

---

## 3. Declaring the Urban Core & Remodeling

Once your inaugural shelter is sealed, designate it as the **Urban Core** (*Núcleo Urbano*):

1. Point your crosshair at the shelter's main entrance door and press <kbd>B</kbd>.
2. The volumetric validator (`ValidadorEdificios`) evaluates internal volume, checks airtightness, and verifies clear exterior/interior doorway cells.
3. The very first building declared in a match automatically becomes your **Urban Core** (subsequent declarations let you choose between *Residential*, *Warehouse*, or *Urban Core* relocation).

### What Declaring the Urban Core Unlocks:
- **Area of Influence:** Projects a `30-cell` radius (`61×61` footprint) centered on the Core where Zone A and Zone B districts can be painted.
- **Central Stockpile Multiplier (`×2.0`):** Doubles base storage capacity from `500 general / 5,000 food` to **1,000 general / 10,000 food**.
- **Non-Destructive Remodeling (<kbd>Shift</kbd> + <kbd>B</kbd>):** Pointing at a declared building's door and pressing <kbd>Shift</kbd> + <kbd>B</kbd> temporarily unlocks it for structural expansion without evicting its inhabitants into homelessness.

---

## 4. The Central Stockpile Mechanics

All goods transported from remote outposts and domestic workshops converge into the **Central Stockpile** (*Ciudad.almacen*):

| Storage Metric | Value | Behavioral Description |
| :--- | :--- | :--- |
| **Initial Food Stock** | 5,000 units | Starts completely filled to sustain the pioneer and early arrivals. |
| **Initial Wood Stock** | 200 units | Starter building material for initial shelters and work posts. |
| **Standard Resource Base Cap** | 500 units | Base threshold per non-food resource (`LIMITE_BASE`). |
| **Food Storage Base Cap** | 5,000 units | Dedicated food silo threshold (`LIMITE_BASE_COMIDA`). |
| **Core Declaration Multiplier** | **×2.0** (`FACTOR_NUCLEO`) | Declaring the Core doubles capacity to **1,000 general / 10,000 food**. |
| **Residential Chest Bonus** | **+100 gen / +400 food** | Each chest (`BONO_BAUL`) placed inside residences expands total capacity. |
| **Dedicated Warehouse (`almacen`)** | **+3,000 units** | Constructed in Zone A (`8×8` footprint, `240 wood + 160 stone`). |

---

## 5. Attracting Colonists & 24h Colonizability Buffers

The Urban Core itself is an administrative structure. To attract and house colonists:

1. **First Residential Building (`Colonizable: ACTIVE`):** Your first declared house with beds in Zone A starts with colonization enabled immediately, attracting immigrants as soon as civic morale exceeds `20`.
2. **Subsequent Residential Buildings (24h Buffer):** From the second residential building onward, newly declared houses start with **`Colonizable: INACTIVE`** for a `24-hour` in-game countdown (which can be toggled manually at any time in `PanelEdificio`). This protects open beds so existing citizens can relocate smoothly during house remodeling before external immigrants fill them.
3. **Homelessness Grace Period (`72h`):** Any colonist without a bed enters the **Homeless** (`sin_techo`) state (`3.0 food/h`) with a **72-hour grace period** before emigrating (`-10` morale penalty per exiled colonist).


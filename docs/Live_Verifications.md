# Live Verification Script (Live QA Script) — Craft to Nation

This document is the comprehensive step-by-step manual testing script to verify live, directly inside the running game (**F5** in Godot), that all mechanics—avatar controls, urban foundation, demographics, morale, road network, educational chain, industry, fluids, elevated conduits, and the electrical grid—operate smoothly and without errors.

The script is designed following **strictly the chronological order and real gameplay prerequisites**: no test requires buildings, professions, technologies, or world states that have not been unlocked or built in previous steps.

---

## 0. Preparation, Initial State, and Global Controls

### Starting the Environment and Initial Conditions
1. Open the project in Godot and press **F5** (or run the main scene `Main.tscn`).
2. Verify that the avatar spawns in 1st person and that the HUD topbar is visible.
3. **Initial Test Inventory (`Player.gd`):** When starting in test mode, the central warehouse is pre-stocked with **1,000 units of every resource** and **5,000 units of food**, allowing you to test structure placement without spending hours chopping trees or mining.
4. **Initial Colony State (`Ciudad.gd`):**
   - **Urban Core (`Núcleo Urbano`):** Not declared yet (no Zone of Influence exists and no immigrants arrive until the first building is declared in Block 2).
   - **Tech Level:** `nivel_investigado = 1` (petrochemical and thermoelectric industries require researching *Applied Metallurgy* / *Metalurgia Aplicada* in Block 5).
   - **Grid Power:** `0 E/h` (until a Thermal Power Plant is built and supplied in Block 7).
   - **Citizen Morale:** Starts at `🙂 75%` (*Pioneer Optimism* / *Optimismo pionero*).

### Key Keyboard Shortcuts

#### First Person (Avatar)
| Key / Action | Function |
| :--- | :--- |
| **C** | Toggle between **1st-Person Camera** and **Overhead Camera** (with animated transition). |
| **W, A, S, D** | Avatar movement. |
| **Space / Ctrl** | Jump on land / Swim up (**Space**) or down (**Ctrl**) in deep liquids ($\ge 2$ blocks). |
| **Left Click** | Chop trees, mine terrain/veins (with progress bar), or deconstruct if **G** mode is active. |
| **Right Click** | Place the block selected in the hotbar (`1`–`0`) or supply a targeted ghost construction site. |
| **1 – 9, 0** | Select block type in the hotbar (`tierra`, `adobe`, `bloque_madera`, `bloque_piedra`, `estructura_hierro`, `vidrio`, `puerta`, `cama`, `baul`, `bloque_acero`). |
| **L** | **Toggle avatar omnidirectional lantern on / off** (`PanelLampara`). |
| **E** | Press: open/close doors or open an active outpost's chest (`VentanaBaul`). Hold on tree: harvest fruit. |
| **G** | Toggle manual on-foot deconstruction mode (left click dismantles step by step; right click marks/unmarks for demolition). |
| **V** | Toggle on-foot road interaction mode (left click builds a 2×2 section; right click demolishes a 2×2 section). |
| **B / Shift + B** | Declare finished structure (**B**) / Start remodeling (**Shift + B**) while aiming at its exterior door. |
| **M** | Open / close the **Citizen Morale** analytical window (`VentanaMoral`). |
| **Esc** | Close active modal window, exit road/deconstruction mode, or release the mouse cursor. |

#### Overhead Camera (Urban Management)
| Key / Action | Function |
| :--- | :--- |
| **W, A, S, D** | Horizontal camera panning across the X/Z plane. |
| **Q / E** | **Orbital Rotation:** Rotate the view around the focal point to the left (**Q**) or right (**E**). |
| **Mouse Wheel (Scroll)** | **Zoom:** Zoom in or out obliquely relative to the focal point. |
| **Ctrl + W / Ctrl + S** | **Pitch / Tilt:** Adjust the vertical tilt angle of the camera. |
| **Shift + W / Shift + S** | **Vertical Elevation:** Raise (**Shift+W**) or lower (**Shift+S**) the focal point elevation directly. |
| **1** | **Build** Menu (`1`: Residential, `2`: Peripheral, `3`: Industrial, `4`: Research, `5`: Roads, `6`: Conduits). |
| **2** | **Zone** Menu (`1`: Residential Zone, `2`: Industrial Zone, `3`: Clear Zone). |
| **3** | Unified **Demolish** Mode (red mark on buildings and orange guided demolition on roads). |
| **Z / X** | Go back a submenu (**Z**) / Next page (**X**) in numeric menus with more than 9 items. |
| **M** | Open / close the **Citizen Morale** analytical window (`VentanaMoral`). |
| **Ctrl + Scroll** | Rotate blueprint preview or outpost template in 90° steps. |
| **Left Click** | Set zone/road/conduit corner, place structure, or inspect building/outpost/conduit in View mode. |
| **Double Left Click** | Confirm road layout, road demolition, or elevated conduit path. |
| **Right Click** | Cancel segment in progress / cancel placement mode. |
| **Esc** | Return to neutral **View** mode or close open panels. |

---

## Block 1: Initial 1st-Person Exploration, Water, Oxygen, and Thermal Lantern

> **Starting Condition:** Right after launching the scene (`F5`), before founding the city. Tests on-foot avatar physics, surface river/lake interactions, draining liquids with solid blocks, and the initial thermal mode of the lantern. *(Note: Physics on `crudo` [crude oil] are verified in **Block 6.7** after extracting subterranean oil, since natural oil pools lie at depth $\ge 4$ underground).*

### 1.1 Movement, Tree Chopping, Mining, and Block Placement on Foot
- [ ] **Action:** Move with **W, A, S, D** and jump with **Space**. Aim at a tree or the ground while holding **Left Click**, and place blocks from the hotbar (`1`–`0`) with **Right Click**.
- [ ] **Expected Result:**
  - The green highlight (`CaraApuntada`) marks the block face under the crosshair.
  - Chopping or mining displays the circular/linear progress bar and extracted resources are added to the warehouse.
  - Placing a block inside the 2 cells occupied by the avatar's own body is prevented.

### 1.2 Swimming in Water, Currents, Oxygen, and Draining with Solid Blocks
- [ ] **Action (Swimming and Current):** Walk into a river, waterfall, or lake with $\ge 2$ blocks of `agua` (water) depth.
- [ ] **Expected Result:**
  - In 1-block-deep water the avatar walks normally; upon entering $\ge 2$ blocks of depth, smooth camera bobbing and vertical swimming activate (**Space** swims up, **Ctrl** swims down).
  - In rivers and at the base of waterfalls, horizontal current push is felt added to the player's movement.
- [ ] **Action (Oxygen Consumption):** Submerge the avatar's head completely underwater (`Ctrl`).
- [ ] **Expected Result:**
  - `PanelOxigeno` appears and the oxygen bar depletes progressively (10 s of autonomy) and recovers twice as fast upon surfacing.
- [ ] **Action (Draining / Drying with Solid Blocks):** Aim at a cell flooded with `agua` with a solid block selected in the hotbar (e.g., `tierra` or `bloque_piedra`) and **Right Click**.
- [ ] **Expected Result:**
  - The solid block **immediately overwrites and displaces the liquid**, leaving the cell dry and occupied by the solid block without rejecting placement.

### 1.3 Omnidirectional Lantern in Initial Thermal Mode (`L`) and Oxygen Stacking
- [ ] **Action:** In 1st person (with no Thermal Power Plant built on the map yet), press **`L`**.
- [ ] **Expected Result:**
  - The avatar's omnidirectional light turns on.
  - Because the city currently produces `0 E/h`, `PanelLampara` opens directly in **`LÁMPARA TÉRMICA🟡`** (Thermal Lantern) mode.
  - It burns supplies from the central warehouse following the hierarchy configured in `Player.gd`:
    1. **Fuel (`Combustible`):** `10 h / unit` (bright warm light, 14 m range).
    2. **Coal (`Carbón`):** `6 h / unit` (amber light, 10 m range).
    3. **Wood (`Madera`):** `5 h / unit` (dim orange light, 7 m range).
  - The panel displays `Tiempo restante: X h | Y Combustible` (deducting 1 unit from the warehouse every 10 game hours).
- [ ] **Action (Stacked Oxygen Window):** With the lantern turned on and `PanelLampara` visible, submerge the avatar's head underwater.
- [ ] **Expected Result:**
  - The `PanelOxigeno` window appears **stacked vertically right below** `PanelLampara`, without overlapping or obscuring the center crosshair.
- [ ] **Action:** Press **`L`** again to turn off the lantern (the indicator switches to `⚫` and the panel hides). *(The **`LÁMPARA ELÉCTRICA🟡`** mode with a 72 h battery will be tested in **Block 7.3**, once electrical generation exists in the city).*

---

## Block 2: Founding the Urban Core, Zoning, and Residential Lifecycle

> **Mechanics & Logical Order:** The **very first building** declared with `B` always founds the **Urban Core (`Núcleo Urbano`)** (establishing the Zone of Influence and saving the first blueprint, though it does not house colonists). Next, you paint the **Residential Zone (`2 -> 1`)**, build the **1st Habitable Residence** (which triggers immigration with `Colonizable: SÍ`), test the `"Sin techo"` (Homeless) state by remodeling it, and then build the **2nd Residence** (which spawns as a `Colonizable: NO 24h` buffer and allows relocating residents without leaving anyone homeless).

### 2.1 Hand-Building a 2-Story House and Declaring the Urban Core (`B`)
- [ ] **Action:** In 1st person, manually build a closed **2-story** structure using blocks from the hotbar (respecting Level 1 limits: max 2 floors and max 2 beds per floor):
  - **Ground Floor (Level 0):** Closed walls, **1 exterior door** (`7`), at least **1 glass window** (`6`), **1 or 2 beds** (`8`), and **1 chest** (`9`).
  - **Upper Floor (Level 1):** Closed walls, roof, walkable interior staircase from the ground floor, windows, and up to 2 beds, **with no exterior door**.
- [ ] **Action (3D Aesthetic Verification):** Closely inspect the placed wooden door and glass windows:
  - Verify that the wooden door features visible three-dimensional relief: a **brass door handle** (`Color(0.85, 0.7, 0.2)`) and **two dark metallic hinges** (`Color(0.15, 0.15, 0.15)`) on its side frame.
  - Verify that glass window blocks are rendered as **thin $1/20$-thickness ($0.05$ m) transparent panels** (`ventana` straight at mid-depth facing the avatar with only front and back faces, `ventana_esquina` L-shaped corner rotated 90° on Y when connecting at a corner, and `ventana_techo` ceiling panel flush with the top face $Y \in [0.95, 1.0]$ when placed looking up or down).
- [ ] **Action:** Step outside, aim at the ground-floor door, and press **`B`**.
- [ ] **Expected Result:**
  - The structure validates and declares successfully (and automatically drains any water blocks trapped inside its interior air volume): **it does not require an exterior door on the upper floor**.
  - Notification: **`"Núcleo urbano declarado."`** (*Urban core declared.*)
  - The building is registered as the **Urban Core** (doubling base central warehouse caps and establishing the **Zone of Influence** around headquarters).
  - The design is automatically saved to the blueprint catalog under the name **`Residencia [beds]x[chests]`**.

### 2.2 Urban Core Remodeling Exception (`Shift + B`)
- [ ] **Action:** Aim at the door of the newly declared Urban Core and press **`Shift + B`** (or select it in overhead view and click `[Iniciar remodelación]`).
- [ ] **Expected Result:**
  - Notification: *"Remodelación iniciada para el núcleo urbano: ahora en edición libre."*
  - Blocks become unprotected so you can expand or modify walls without losing its status as headquarters.
- [ ] **Action:** Aim at its door again and press **`B`** to redeclare the Urban Core.

### 2.3 Residential Zoning (`2 -> 1`) and Placing the 1st Habitable Residence (`1 -> 1`)
- [ ] **Action (Paint Residential Zone):** Press **`C`** to switch to the Overhead Camera. Press **`2`** (Zone) $\to$ **`1`** (Residential Zone) and left-click twice on flat terrain **inside the Zone of Influence** to paint a residential sector.
- [ ] **Expected Result:**
  - The Residential Zone rectangle is drawn. Pressing **`Esc`** to exit Zoning mode cleanly hides the colored rectangles.
- [ ] **Action (Place Blueprint with 3D Thumbnail):** In overhead view, press **`1`** (Build) $\to$ **`1`** (Residential).
- [ ] **Expected Result:**
  - The button displays the name `Residencia [beds]x[chests]` along with its live-generated **isometric 3D thumbnail** (up to 5 blueprint slots are supported).
  - Upon selecting it (`1`), the contextual card displays the vector icons `[Ctrl] [Scroll Icon] ROTAR` and `[Left Click Icon] COLOCAR`.
  - Rotating with **`Ctrl + Mouse Wheel`** rotates both the 3D ghost footprint and the thumbnail in 90° steps.
- [ ] **Action (Build the 1st Residence):** Left-click on the painted **Residential Zone** to place the ghost building. Return to 1st person (**`C`**) and hold **Right Click** aiming at the ghost blocks (and then any exterior wall) until construction reaches 100%.

### 2.4 1st Habitable Residence: `Colonizable: SÍ` and Arrival of the First Colonists
- [ ] **Action:** Switch to overhead view (**`C`**), ensure View mode (**`Esc`**), and left-click on the newly finished residence (not the Urban Core).
- [ ] **Expected Result:**
  - `PanelEdificio` indicates: **`Colonizable: SÍ (inmigración activa)`** and displays the **`[Pausar colonización]`** button with the open-door vector icon (`puerta_abierta.svg`).
  - As hourly ticks advance (every 2 s), colonists (`desempleado`) start immigrating and walking toward their new home until its bed capacity is filled (4 unemployed/laborers per bed).
  - With initial morale around 75% (*Pioneer Optimism* / *Optimismo pionero*), the colony operates under **Massive Immigration (`moral > 50%`)**, routing arriving colonists directly to available beds.
  - The panel breaks down how many residents of each category live in the building.

### 2.5 Remodeling the Only Populated Residence: "Homeless" (`Sin techo`) State and Reabsorption
- [ ] **Condition:** Wait until the 1st Habitable Residence has colonists living in it (while **no other house** with free beds exists in the colony yet).
- [ ] **Action:** In overhead view, select that residence and click **`[Iniciar remodelación]`** (or press **`Shift + B`** in 1st person aiming at its door).
- [ ] **Expected Result:**
  - In overhead view, a **modal dialog styled with `TemaHUD`** appears warning how many residents will be left **homeless (`sin techo`)** due to a lack of alternative beds.
  - Upon confirming, the building enters free-edit mode and the evicted residents appear in the **Population (`Población`)** window as **`"Sin techo: X"`**.
  - While homeless, they consume food at the unemployed rate, do not work on construction sites or outposts, and penalize morale by `-0.05/h`.
- [ ] **Action (Immediate Reabsorption):** In 1st person, aim at the house door and press **`B`** to redeclare it.
- [ ] **Expected Result:**
  - The `"Sin techo"` colonists are **instantly reabsorbed** into the newly declared beds (`Sin techo: 0`) and resume normal activity.

### 2.6 2nd Residence Onward: 24 h Buffer (`Colonizable: NO`), Colonist Construction, and Relocation
- [ ] **Action:** In overhead view (`1 -> 1`), place a **2nd Residence** on the Residential Zone.
- [ ] **Expected Result (Autonomous Construction by Colonists):**
  - Because there are now unemployed/laborer colonists in the city, **colonists automatically walk to the ghost construction site** and build it block by block until completion without player intervention.
- [ ] **Action:** Once the 2nd Residence is finished, select it in View mode (`Esc`).
- [ ] **Expected Result (Housing Buffer):**
  - It spawns with the state **`Colonizable: NO (apertura en 24 h)`** and the **`[Permitir colonización]`** button.
  - Its beds are protected as a buffer for internal relocations (they do not attract new external immigrants until the 24 h countdown reaches 0 or the player opens it manually).
  - Clicking **`[Permitir colonización]`** switches it immediately to `Colonizable: SÍ (inmigración activa)`; clicking **`[Pausar colonización]`** returns it to `Colonizable: NO (buffer protegido)`. Leave it set to `NO` with free beds.
- [ ] **Action (Automatic Relocation on Remodel):** Start remodeling (`Shift + B` or overhead view) on the **1st Populated Residence** while the 2nd Residence has free buffer beds.
- [ ] **Expected Result:**
  - The residents of the 1st Residence **automatically move into the free beds of the 2nd Residence**, generating **`0 homeless colonists` (`Sin techo: 0`)**. Redeclare the 1st Residence with **`B`**.

### 2.7 Row Houses (Wall-to-Wall) and Urban Core Relocation
- [ ] **Action (Row Houses):** In 1st person, build two small houses sharing a wall **wall-to-wall** on the Residential Zone and declare both with **`B`** (Building A and Building B).
  - Start remodeling only Building A (`Shift + B`): verify that Building B remains intact and protected against mining.
  - Modify a block in A and redeclare it with **`B`**: verify that the *flood-fill* algorithm stops at the already registered blocks of B and cleanly declares A without merging or absorbing B.
- [ ] **Action (Relocating Urban Core Headquarters):** In overhead View mode (`Esc`), select a finished secondary residence and click **`[Asignar como núcleo urbano]`**.
- [ ] **Expected Result:**
  - A modal dialog (`TemaHUD`) opens warning of the **5-hour** grace period (and reporting if there will be a bed deficit during the transition).
  - Upon confirming, after 5 hourly ticks the Urban Core and its Zone of Influence relocate to the new headquarters without resource loss, and the former core becomes a regular habitable residential building.

---

## Block 3: Road Infrastructure, Construction Priorities, and Traffic

> **Prerequisite Condition:** The colony now has the Urban Core, multiple residences, and free laborer colonists to execute roadworks, demolitions, and constructions with varying priorities.

### 3.1 Overhead Road Tool & SVG Iconography (`1` -> `5` -> `1`)
- [ ] **Action:** In overhead view (**`C`**), press **`1`** (Build) $\to$ **`5`** (Roads) $\to$ **`1`** (Trace Road).
- [ ] **Expected Result:**
  - The contextual card displays SVG vector icons:
    - `[Left Click Icon] FIJAR PUNTO` (Set Point)
    - `[Double Left Click Icon (x2)] CONFIRMAR` (Confirm)
    - `[Right Click Icon] CANCELAR` (Cancel)
    - `[Esc] SALIR` (Exit)
  - Dynamic spec sheet showing `Velocidad: +35%` and stone/dirt costs calculated live according to layout length and grading.
- [ ] **Clean Cancellation:** Left-click once on the ground, move the cursor to preview a segment, and **Right Click**: the segment in progress cancels immediately without leaving ghost tiles behind.

### 3.2 Shared Leveling Between Facing Doors
- [ ] **Action:** Place a building across from another with their doors facing each other 2–3 cells apart on uneven terrain, or trace a street between both facades.
- [ ] **Expected Result:**
  - The terrain between facing doors levels to a shared elevation, preventing steep steps from blocking doorway access.

### 3.3 Progressive Road Laying by Colonists (`ViaObraOverlay`) and Segment Merging
- [ ] **Action:** Trace a multi-cell road and confirm with a **double left click**.
- [ ] **Expected Result:**
  - The **yellow perimeter outline** appears on the ground (`ViaObraOverlay`).
  - Up to **4 free laborers** walk to the roadwork site and build **consecutively from one end to the other** (grading, filling, or placing road slabs and ramp wedges).
  - As each cell is completed, the yellow outline progressively recedes.
- [ ] **Segment Merging:** While the roadwork is still under construction, trace and confirm a new contiguous road segment: it merges automatically into the same active work order under the same crew of up to 4 laborers.

### 3.4 Manual On-Foot Road Intervention in 1st Person (`V` Key)
- [ ] **Action:** Trace another road in overhead view, switch to 1st person (**`C`**), and press **`V`** to activate on-foot road mode.
- [ ] **Build 2×2 Section (Left Click):** Aim at a pending road section (with yellow wireframe) and left-click:
  - Completes the **entire 2×2 section** at once (all 4 road-width cells or wedges) without spamming individual cell notifications.
- [ ] **Demolish 2×2 Section (Right Click):** Aim at an already built road section and right-click:
  - Instantly removes the entire 2×2 section along with its wedges.
- [ ] Press **`V`** or **`Esc`** to exit road mode.

### 3.5 Unified Overhead Demolition Tool (`3` Key)
- [ ] **Building Demolition:** In overhead view, press **`3`** (Demolish) and left-click on a secondary building: toggles its red demolition mark so colonists dismantle it.
- [ ] **Guided Road Demolition Around 90° Corners:** Trace and complete an "L"-shaped road (with a 90° corner). Activate mode **`3`**, left-click at one end of the road, and move the cursor to the other end around the corner:
  - The **translucent orange preview** (`ViaDemolicionOverlay`) follows the road network via Dijkstra covering the **full 2-lane width (2×2 section)** around the outer corner without cutting diagonally.
- [ ] **Confirmation and Persistent Orange Outline:** **Double left-click** to confirm demolition of the road segment:
  - The road remains marked with a **persistent orange outline** on the ground.
  - Colonists walk over to demolish the road, and the orange outline disappears section by section until demolition is complete.

### 3.6 Configurable Construction Priorities (`PanelEdificio`) and Dispatch Hierarchy
- [ ] **Action:** In overhead view, start a residential building construction, mark another for demolition, and leave a road segment under construction. Select the building under construction in View mode (`Esc`).
- [ ] **Expected Result:**
  - `PanelEdificio` displays the priority row with its icon (`prio_alta.svg`, `prio_normal.svg`, `prio_baja.svg`), the label **`Prioridad: Normal`**, and two arrow buttons: **`btn_subir.svg` (`▲`, increase priority)** and **`btn_bajar.svg` (`▼`, decrease priority)**. When construction reaches 100%, the window automatically transitions to the building panel (`PanelPuesto` or `PanelEdificio`) and drains interior water blocks.
  - Successive clicks cycle the value: **`Normal`** $\to$ **`Alta`** (High) $\to$ **`Baja`** (Low) $\to$ **`Normal`**.
  - Verify that free colonists are dispatched strictly following the global priority order:
    1. *High Priority Construction (`Prioridad Alta`)*
    2. *Normal Priority Construction (`Prioridad Normal`)*
    3. *Building and Road Demolitions*
    4. *Road Laying*
    5. *Low Priority Construction (`Prioridad Baja`)*

---

## Block 4: Civic Oversight, Dynamic Morale, and Peripheral Gathering Outposts

> **Prerequisite Condition:** With the city founded and roads laid out, you audit the global HUD panels (Warehouse, Population, Occupations, and Morale) and build the first **Level 1 Peripheral Outposts** outside the Zone of Influence (which operate directly with Laborers and unlock outpost chests for the first time to test `VentanaBaul` and road hauling routes).

### 4.1 Topbar, Alphabetical Warehouse (A-Z), Population, and Occupations
- [ ] **Topbar:** Verify the counters for **Food (`Comida`)**, **Energy (`Energía`)**, **Critical Resource (`Recurso Crítico`)**, **Population (`Población`)**, **Morale (`Moral`)**, the **Era indicator** (Era name + icon), and on the far right the **IDU Level Roman numeral icon (`romano_1.svg`..`romano_4.svg`)** which opens the **IDU breakdown window** attached to the top-right corner below the status bar on mouse hover.
- [ ] **Warehouse Window (`Almacén`):** Click the **Almacén** button:
  - Raw materials are listed alphabetically from **A to Z** (`Agua`, `Carbón`, `Cobre`, `Comida`, `Crudo`, `Hierro`, `Madera`, `Piedra`, `Tierra`, `Tierras raras`) with collapsible dropdowns (`▶`/`▼`) revealing their refined/processed derivatives (`Combustible`, `Acero`, `Tablas` & `Carbón`, `Bloques de piedra`, **`Vidrio`**, `Mineral refinado`) and the 6 food categories under `Comida`, plus the **`[Expandir todo]` / `[Contraer todo]`** button in the top header between `"ALMACÉN"` and the `X` close button.
- [ ] **Population and Occupations Windows:** Click **Población**:
  - Displays the unified row: **`Obreros: Total · X empleados · Y desempleados`** (plus rows for Technicians, Specialists, Researchers, Military, and Homeless if applicable).
  - Click the **Ocupaciones** button inside Population: displays the 4 collapsible categories (`▼ Recolección`, `▼ Industria`, `▼ Investigación`, `▼ Energía`) that collapse (`▶`) or expand (`▼`) on click, listing outposts from newest to oldest.

### 4.2 Dynamic Citizen Morale System (`VentanaMoral` — `M` Key)
- [ ] **Action:** Observe the morale button on the topbar (defaulting around `🙂 75%` at start) and click it or press **`M`**.
- [ ] **Expected Result:**
  - The centered modal window **`VentanaMoral`** styled with `TemaHUD` opens.
  - Displays **Current Mood (`Estado Anímico Actual`)** (with visual thresholds: `😡` <20%, `🙁` 20–35%, `😐` 35–65%, `🙂` $\ge$65%), **Projected Daily Rate** (`Tendencia: %+.2f / día` with vector arrows `tasa_arriba.svg`, `tasa_abajo.svg`, or `tasa_neutra.svg`), continuous **Labor Productivity Multiplier** ($X = 0.5 \times 2^{(Y/50)}$, where 50% = `1.00x`, 75% $\approx$ `1.41x`, 100% = `2.00x`), and the **Migration Flow** state.
  - **Three Staggered Monthly Migration Tiers:**
    1. **`Moral <= 20%` (Despair):** Displays `Migración: ⚠ Éxodo de cerebros (X/mes)` in red (`TemaHUD.INVALIDO`) alongside `investigador.svg`. Active brain drain expelling highest-skilled citizens first.
    2. **`20% < Moral <= 50%` (Immigration with Beds):** Displays `Migración: Inmigración con camas (X/mes)` in soft green (`Color(0.85, 0.95, 0.6)`) alongside `ciudadano.svg`. **Immigrants only arrive if free beds exist in declared housing**; never overflows into homeless ("Sin techo") even if an Urban Core is founded.
    3. **`Moral > 50%` (Massive Immigration):** Displays `Migración: Inmigración masiva (X/mes)` in bright green (`Color(0.6, 1.0, 0.6)`) with `ciudadano.svg`. Attracts a steady stream of immigrants; if all beds are full but an Urban Core exists, overflows into the streets as "Sin techo".
  - Details the analytical breakdown of factors expressed per day (`/día`):
    1. *Inertia toward neutrality (50%): `• Tendencia natural al equilibrio (50%): %+.2f/día`*
    2. *Food diet variety: `• Variedad de alimentos (X/6 grupos): %+.2f/día`*
    3. *Resource abundance & reserves: `• Abundancia y reservas: Estable` (or `Déficit de comida (-0.6/día)`, `Hambruna crítica (-3.0/día)`)*
    4. *Homeless drain: `• Ciudadanos sin techo (X en la calle): %+.2f/día` (-0.05/day per homeless colonist)*
    5. *Rolling 7-day (168 h) hazard buffer: `• Peligrosidad 7 días (bajas/robos): %+.2f/día`*
  - Verify that during hourly simulation ticks (`Ciudad.gd`), morale changes by adding `tasa_cambio_moral / 24.0` per tick.
  - Closes cleanly via the `X` button, **`M`** key, or **`Esc`**.

### 4.3 Peripheral Gathering Outposts (`1 -> 2 -> 1..4`: Hunting, Lumber, Mine, Fishing)
- [ ] **Zone of Influence Exclusion Rule:** In overhead view, press **`1`** (Build) $\to$ **`2`** (Peripheral) and select **Mine (`3`)**, **Lumber (`2`)**, or **Hunting (`1`)**.
  - Move the cursor **inside** the city's Zone of Influence: the footprint appears **red (invalid)** because peripheral outposts must be placed outside the urban core.
  - Move the cursor **outside** the Zone of Influence (over forest for Hunting/Lumber, solid ground for Mine, or half-water / half-land shoreline for Fishing `4`): the footprint turns **gold (valid)** surrounded by the **blue circular halo** of its operating radius.
- [ ] **Construction and Operation with Laborers:** Place a **Mine (`1-2-3`)** and a **Lumber Camp (`1-2-2`)** outside the Zone of Influence and let colonists complete construction.
  - Left-click on the finished outpost in View mode (`Esc`) to open `PanelPuesto`.
  - **Header and Level Verification without Redundancy:**
    - The outpost title displays only its name and status (`"Mina"` or `"Mina (inactivo)"`), **without repeating the redundant string** `", nivel X"`.
    - Outpost level is cleanly represented by the Roman numeral vector badge (`romano_1.svg`) next to the building icon (`mina.svg`).
  - **Staffing Assignment Buttons Without Text Overlap:**
    - The `+` and `-` buttons for hiring and dismissing workers (`Recolectores`, `Acarreadores`) exhibit centered vector SVG icons (`btn_mas.svg`, `btn_menos.svg`) cleanly, without duplicate `+` or `-` text overlapping the icon.
  - **Dynamic Production Row with Vector Icons:**
    - Verify that the production row shows the `"Producción:"` prefix followed by each resource's **16px vector SVG icon** (`IconosHUD.crear_rect(rec, 16)`) and formatted rate (`"%.1f Recurso/h"`), or the label `"ninguna"` if no gatherers are present.
  - Hire **Gatherers (`Recolectores`)** (draws from Laborers/Unemployed) and **Haulers (`Acarreadores`)** using the `+` button:
    - Verify that once gatherers arrive inside the outpost (`presentes`), the outpost extracts physical ore/wood from the environment (the mine excavates its quarry in strips and the lumber camp chops actual trees).
    - Verify that **haulers** pick up cargo from the front exterior `servicio` cell (in front of the door) and carry it to the central warehouse without getting stuck inside the building.

### 4.4 Road Preference in Pathfinding (`BuscadorRutas`) and Traffic Priority
- [ ] **Action:** Trace a **packed-dirt road (`1 -> 5 -> 1`)** connecting the Urban Core to the vicinity of the peripheral Mine or Lumber Camp (routing around a patch of open terrain).
- [ ] **Expected Result (A* Preference):**
  - Observing haulers and workers traveling between the city and the outpost shows they **prefer walking along the packed-dirt road** (`coste_ruta = 3`) rather than cutting across natural terrain (`COSTE_TERRENO_NATURAL = 8`).
  - If the outpost door does not directly touch the road, the colonist travels along the road to the closest possible point and only steps onto natural terrain for the final few blocks.
- [ ] **Right-of-Way Priority in Bottlenecks:** In a narrow 1-cell passage, when two colonists meet head-on, the colonist carrying higher-priority cargo (`food > fuel > crude oil > steel...`) maintains their route while the unloaded or lower-priority colonist steps aside to a lateral cell to yield right-of-way.

### 4.5 1st-Person Interaction with an Outpost Chest (`VentanaBaul` — `E` Key)
- [ ] **Prerequisite Met:** You now have at least one finished, active peripheral outpost with its own storage chest.
- [ ] **Action:** Switch to 1st person (**`C`**), walk to the Mine or Lumber Camp, open its door with **`E`**, aim the crosshair at the **interior chest**, and press **`E`**.
- [ ] **Expected Result:**
  - The **`VentanaBaul`** window opens centered on screen with compact dimensions (`320x260`) and a vertical scrollbar.
  - The mouse cursor is freed to transfer units between the outpost's local deposit and the central warehouse using **`-`**, **`+`**, or **`"Extraer todo"`** (*Extract all*).
- [ ] **Quick Close:** Press **`E`** (or **`Esc`**) again $\to$ the window closes immediately and 1st-person camera control is restored right away.

---

## Block 5: Educational Chain, Tier 1 Industry, Reserves, and Research

> **Strict Code Unlock Order (`CamaraCenital.gd` and `Economia.gd`):**
> 1. All refineries (`Siderúrgica`, `Aserradero`, `Fábrica de bloques`, `Carbonera`, `Tierras raras`) require **Technicians (`Técnicos`)** to produce $\to$ first you must build the **Technical School (`1-4-1`)** and graduate Technicians.
> 2. The **Specialist School (`1-4-2`)** requires at least **1 built Technical School** and graduates Specialists from Technicians.
> 3. The **University (`1-4-3`)** requires at least **1 built Specialist School** and employs Specialists as Researchers.
> 4. The `Oil Refinery`, `Fuel Producer`, and `Thermal Power Plant` remain locked until the University completes **Applied Metallurgy (`Metalurgia Aplicada`)** research (`Ciudad.nivel_investigado >= 2`).

### 5.1 Technical School (`1 -> 4 -> 1`), Graduating Technicians, and Outpost Levels
- [ ] **Action (Construction):** In overhead view, ensure there is free space in the **Residential Zone (`2 -> 1`)** inside the Zone of Influence. Press **`1` (Build) -> `4` (Research) -> `1` (Technical School / `Escuela técnica`)** and place it on the Residential Zone.
- [ ] **Action (Cohort Training):** Once the Technical School is built, select it in View mode (`Esc`) and hire the full quota of **4 Apprentices (`Aprendices`)** (draws 4 laborers/unemployed).
- [ ] **Expected Result:**
  - Once all 4 apprentices are **present** inside the school at their study desks, progress advances by 1 hour per tick (if one is dismissed before completion, progress resets to 0).
  - Upon completing **24 hours**, the cohort graduates and converts the 4 laborers into **3 free Technicians (`Técnicos`)** (occupying the exact same 1 housing bed).
- [ ] **Testing Level Upgrade and Downgrade in Mine/Lumber Camp:**
  - Open `PanelPuesto` for the peripheral Mine, dismiss the laborer gatherers, and hire **1 Technician**: the outpost upgrades to **Level 2** (larger radius, depth 16, and higher extraction multiplier).
  - Also hire **1 Gatherer (`Obrero`)** in that same Mine: verify that the outpost **allows hiring them and cleanly downgrades to Level 1** (the minimum rank among its workers) without locking up.

### 5.2 Industrial Zoning (`2 -> 2`), Block Factory (`1 -> 3 -> 4`), and Tier 1 Refineries
- [ ] **Action (Paint Industrial Zone):** In overhead view, press **`2` (Zone) -> `2` (Industrial Zone)** and paint an industrial sector **inside the Zone of Influence** of the city. Exit with `Esc`.
- [ ] **Action (Build Block Factory and Steelworks):** Press **`1` (Build) -> `3` (Industrial)**:
  - Verify that the Industrial submenu lists 9 facilities (with `Z`/`X` pagination if applicable): `1: Siderúrgica`, `2: Tierras raras`, `3: Aserradero`, `4: Fábrica de bloques`, `5: Carbonera`, `6: Refinería petrolera`, `7: Productor combustible`, `8: Central termoeléctrica`, `9: Almacén`.
  - Select **`4` (`Fábrica de bloques` / Block Factory)**: verify its isometric 3D thumbnail and place its **5×6 cell** footprint on the Industrial Zone. Also place a **Steelworks (`1 -> 3 -> 1`)** and a **Sawmill (`1 -> 3 -> 3`)**.
- [ ] **Expected Result in the Block Factory (`1 -> 3 -> 4`):**
  - Built with `bloque_piedra` walls, front service input door ($Z=0$) for raw stone, rear output door ($Z=5$) for processed blocks, and interior chest.
  - In its `PanelPuesto`, hire **Technicians** (graduated in 5.1) and **Haulers (`Obreros`)**.
  - During production: the roof chimney (`Vector2i(2, 3)`) emits live smoke and masonry dust (`HumoRefinerias`), converting every **1 unit of raw `piedra` into 3 units of `bloques_piedra`** ($\times 3$ yield).
- [ ] **Civic Consumption Priority of `bloques_piedra` in Construction:**
  - With `bloques_piedra` delivered to the central warehouse, place stone blocks by hand or start a construction order requiring stone:
  - Verify in the **Warehouse (`Almacén`)** window that `Ciudad.gd` **deducts processed `bloques_piedra` first** before spending raw `piedra`, and that total stone availability sums both stocks.

### 5.3 Raw Material Central Reserve Control in Refineries (`0 / 50 / 100 / 250 / 500 u`)
- [ ] **Action:** In View mode (`Esc`), open `PanelPuesto` for the **Block Factory**, **Steelworks**, or **Sawmill**.
- [ ] **Expected Result:**
  - Below the production line appears the **`Reserva central:`** row with a selector button styled with `TemaHUD`.
- [ ] **Action (Cycle Thresholds):** Click the reserve button repeatedly.
- [ ] **Expected Result:**
  - The button text cycles in order:
    `Sin reserva (0 u)` $\to$ `50 u` $\to$ `100 u` $\to$ `250 u` $\to$ `500 u` $\to$ `Sin reserva (0 u)`.
- [ ] **Action (Over-Refining Protection):** Set the reserve to a threshold (e.g., `500 u`) and observe the refinery's haulers when the central warehouse stock is at or below that threshold:
  - Haulers only withdraw surplus above the reserve (`stock_central - reserva`). If central stock is $\le$ the configured reserve, they stop withdrawing inputs so the player is never left without iron, wood, or stone for construction.

### 5.4 Specialist School (`1 -> 4 -> 2`) and Graduating Specialists
- [ ] **Action:** In overhead view, press **`1` (Build) -> `4` (Research) -> `2` (Specialist School / `Escuela de especialistas`)** and place it on the **Residential Zone** inside the Zone of Influence. *(Because you built the Technical School in 5.1, the prerequisite is met).*
- [ ] **Action:** Once construction finishes, open its `PanelPuesto` and hire the full quota of **3 Apprentices** (draws 3 free Technicians; if your Technicians are busy in refineries, temporarily dismiss 3 with `-` or graduate another cohort at the Technical School).
- [ ] **Expected Result:**
  - With all 3 apprentice technicians present, after **48 hours** of study the cohort graduates into **2 free Specialists (`Especialistas`)** (3 technicians = 2 specialists = 1 bed).

### 5.5 Interactive University (`1 -> 4 -> 3`) and Researching "Applied Metallurgy"
- [ ] **Action (Construction):** In overhead view, press **`1` (Build) -> `4` (Research) -> `3` (University / `Universidad`)** and place it on the **Residential Zone** inside the Zone of Influence. *(Meets the prerequisite of having at least 1 Specialist School built).*
- [ ] **Action (Hiring and Manual Start):** Once the University is built, select it in View mode (`Esc`):
  - Verify that it **does not start any research automatically** and displays the **`[Iniciar Investigación]`** button.
  - Click `+` on the **Researchers (`Investigadores`)** row to hire the **free Specialists** (graduated in 5.4), who transition to the `investigador` profession.
  - Click **`[Iniciar Investigación]`**: the modal dialog (`TemaHUD`) opens for **`Investigar: Metalurgia Aplicada`** showing `Costo: 300 hierro, 200 madera` and the `Tiempo estimado` based on the number of assigned researchers (goal: `20 researcher-hours`). Confirm.
- [ ] **Action (Acceleration, Pause, and Full-Refund Cancellation):**
  - **Acceleration:** Assign a second researcher and verify that progress speed doubles and estimated hours are cut in half.
  - **Pause / Resume:** Click **`[Pausar]`** $\to$ status shows `(Pausado)`, progress freezes, and the button changes to **`[Reanudar]`**. Click **`[Reanudar]`**.
  - **Cancel with 100% Refund:** Click **`[Cancelar]`** and confirm in the modal dialog $\to$ research cancels, progress resets to 0%, and **all 300 iron and 200 wood are refunded in full** to the central warehouse.
- [ ] **Action (Complete "Applied Metallurgy"):** Click **`[Iniciar Investigación]`** again, confirm, and let the researchers reach **100% (20 researcher-hours)**.
- [ ] **Expected Result:**
  - Tech completion notification: **`Metalurgia Aplicada`** (`Ciudad.nivel_investigado = 2`).
  - The **Oil Refinery (`6`)**, **Fuel Producer (`7`)**, and **Thermal Power Plant (`8`)** are now unlocked in the Industrial menu (`1 -> 3`).

---

## Block 6: Fluid Extraction, Petrochemical Industry, and Elevated Conduits

> **Prerequisite Condition Met:** You now have **Technicians** (Block 5.1) to operate fluid extractors and refineries, and you have completed **Applied Metallurgy** (Block 5.5) to build the Oil Refinery and Fuel Producer.

### 6.1 Water Pumping Station (`1 -> 2 -> 5` — Peripheral)
- [ ] **Shallow Water Rejection Test:** In overhead view, select **`1` -> `2` -> `5` (`Estación de bombeo`)** and try to place it on a shoreline with only 1 block of water depth: placement is rejected with the warning *"requiere al menos 2 bloques de profundidad de agua bajo su muelle"*.
- [ ] **Valid Placement in Deep Water ($\ge 2$ blocks):** Place it **outside the Zone of Influence** with its pier over water $\ge 2$ blocks deep and its platform on solid land (using `Ctrl + Scroll` to orient it).
- [ ] **Expected Result:**
  - Once built, it features the **`puerto_agua_out`** port block on its landward wall at elevated height ($Y = Y_{base} + 4$).
  - In its `PanelPuesto`, it only accepts the **`Técnicos`** role (0 haulers, since fluids travel exclusively via conduits) and shows the collapsible dropdown for its output port (`⚪ Desconectado`). Hire at least 1 Technician.

### 6.2 Underground Extraction Center (`1 -> 2 -> 6` — Peripheral)
- [ ] **No-Deposit Test:** Select **`1` -> `2` -> `6` (`Centro de extracción`)** and move the cursor over regular terrain without a reservoir: the footprint appears red and the card states *"No se detecta depósito subterráneo de agua o crudo"*.
- [ ] **Subterranean Pool Detection and Drill Column:** Move the cursor **outside the Zone of Influence** across the map until the footprint turns **gold** over an underground `crudo` (or `agua`) pool.
  - Verify that the spec sheet dynamically adds the **`Estructura de hierro`** (`estructura_hierro`) cost proportional to the underground pool's depth.
  - Left-click to place it and let construction finish.
- [ ] **Expected Result:**
  - Upon completion, the vertical `estructura_hierro` drill column is physically generated beneath the building all the way down to the reservoir floor.
  - Selecting it in View mode (`Esc`) shows **`Crudo restante en pozo: X bloques`** (or `Pozo de agua (inagotable)`), an output port at elevation $Y=4$, and accepts only **Technicians**. Hire at least 1 Technician.

### 6.3 Fluid Warehouse (`1 -> 3 -> 9`), Oil Refinery (`1 -> 3 -> 6`), and Fuel Producer (`1 -> 3 -> 7`)
- [ ] **Warehouse (`1 -> 3 -> 9`):** In overhead view, place a **Warehouse (`Almacén`)** (5×5 stone building) on the **Industrial Zone (`2 -> 2`)**.
  - Once finished, verify that it has **6 exterior ports** at elevation $Y=4$: left wall with 3 inputs (`agua`, `crudo`, `combustible`) and right wall with 3 outputs (`agua`, `crudo`, `combustible`).
  - In `PanelPuesto`, the 6 ports appear grouped into **collapsible dropdowns by resource** with `⚪ Desconectado`, `🟢 Conectado`, or `🔴 Derrame` indicators. All warehouses share an instantaneous global fluid pool (1,000 u per warehouse).
- [ ] **Oil Refinery (`1 -> 3 -> 6`):** Place it on the **Industrial Zone** (unlocked by *Applied Metallurgy*).
  - Features `puerto_crudo_in` (left) and `puerto_combustible_out` (right), with no fluid haulers. Hire **Technicians**.
- [ ] **Fuel Producer (`1 -> 3 -> 7`):** Place it on the **Industrial Zone**.
  - Features `puerto_agua_in` and `puerto_combustible_out`. Accepts **Technicians** and **Haulers** (its haulers only carry solid `carbón` from the central warehouse, respecting the configured `Reserva central:`).

### 6.4 Tracing Elevated Conduits (`1 -> 6 -> 1` Aqueduct / `1 -> 6 -> 2` Pipeline)
- [ ] **Spec Sheet with Readable Labels:** In overhead view, press **`1` (Build) -> `6` (Conduits / `Ductos`)** and choose **`1` (`Acueducto`)** or **`2` (`Tubería`)**:
  - Verify that the contextual card displays human-readable names in Spanish (e.g., `1 Bloque de piedra`, `1 Bloque de acero`, `1 Estructura de hierro`), **never** raw code keys like `bloque_acero`.
- [ ] **Elevated Height ($Y_{ground} + 4$), Columns Every 5 Blocks, and Z-Fighting-Free Meshes:**
  - Trace an "L"-shaped segment of at least 11 blocks by left-clicking at the start, left-clicking at the 90° corner, and **double left-clicking** at the end:
  - The conduit is built elevated, leaving **3 blocks of vertical clearance beneath the beam** ($Y = Y_{ground} + 4$).
  - Support columns are placed every **5 blocks** (at 0, 5, 10..., leaving 4 cells of clear span between pillars) and always at every 90° corner.
  - Conduit textures are properly oriented and the junction between horizontal beams and column-top blocks exhibits **no flickering or *z-fighting***.
- [ ] **Free Underpass for Colonists and Ground Roads:**
  - Walk the avatar in 1st person underneath the conduit spans: passage is completely unobstructed.
  - In overhead view, activate the road tool (**`1 -> 5 -> 1`**) and trace a packed-dirt road crossing **underneath** the elevated conduit span: the road builds cleanly without colliding with the conduit.

### 6.5 Grade-Separated Crossings Between Two Conduits (Double Column at $Y=6$ & Clear Air at $Y=5$)
- [ ] **Action:** Have a built Aqueduct (e.g., running North-South at $Y = Y_{ground} + 4$) and trace a **Pipeline** (`1 -> 6 -> 2`) crossing it perpendicularly (East-West).
- [ ] **Expected Result:**
  - On the two cells immediately adjacent to the crossing point, **two new 6-block-high columns** ($Y = Y_{ground} + 5$) with their conduit block on top are automatically erected.
  - The upper span crosses at **$Y = Y_{ground} + 6$**, leaving **1 full block of clear air** ($Y = Y_{ground} + 5$) between the lower and upper conduits.
  - Both conduits remain physically separate: their fluids do not mix and demolishing one does not break the other.

### 6.6 Port Connections, 400/600 Refinery Split, Inspection (`PanelCanalizacion`), and Clean Demolition
- [ ] **Aqueduct Connection (Pumping Station $\to$ Warehouse):**
  - With **`1 -> 6 -> 1` (`Acueducto`)**, left-click on the exterior cell in front of the Pumping Station's `puerto_agua_out` (the first block snaps to elevation $Y=4$ with no column underneath) and route it to the cell in front of the Warehouse's `puerto_agua_in` (input 1), confirming with a **double left click**.
  - In `PanelPuesto` of both buildings, the ports switch to **`🟢 Conectado`** and extracted water flows hourly into the global fluid pool without using haulers.
- [ ] **Pipeline Connection and 400/600 Cap in the Oil Refinery:**
  - With **`1 -> 6 -> 2` (`Tubería`)**, connect the Crude Oil Extraction Center's `puerto_crudo_out` to the Oil Refinery's `puerto_crudo_in`, and connect the Refinery's `puerto_combustible_out` to the Warehouse's fuel input port.
  - Verify in the Oil Refinery's `PanelPuesto` that:
    - Crude oil in the underground pool decreases block by block (`Crudo restante en pozo: X bloques`).
    - Local crude oil storage inside the Refinery **never exceeds 400 units (40%)**, always reserving **600 units (60%)** of free capacity so fuel production is never deadlocked by overfilling.
- [ ] **Inspection (`PanelCanalizacion`) and Ghost-Free Demolition:**
  - In overhead View mode (`Esc`), left-click on any block of a conduit: **`PanelCanalizacion`** opens showing Type, Transported Resource, Length, Connected Buildings, and State (`🟢 Conectado`).
  - Click **`[Demoler canalización]`** and confirm: the entire conduit is removed, refunding its materials, and the cell in front of the building port is left **completely clean (no ghost endpoint blocks)**, allowing you to reconnect a new conduit to that exact same port immediately.

### 6.7 Physical Crude Oil Spill, 1st-Person Viscosity/Draining Physics, and Column Reconnection
- [ ] **Trigger an Open-Ended Spill:**
  - With **`1 -> 6 -> 2` (`Tubería`)**, start a pipeline at the Crude Oil Extraction Center's `puerto_crudo_out` (with at least 1 Technician working), extend it 6–8 cells onto open ground, and confirm with a **double left click leaving the far end unconnected in mid-air**.
- [ ] **Expected Result (Spill and Spreading):**
  - On the next hourly tick, the conduit and port state changes to **`🔴 Derrame`** (Spill) and the HUD emits an alert.
  - At the open mouth of the disconnected end, a physical **`crudo`** block spawns, falls to the ground, and **activates viscous *spreading* physics** (slowly spreading up to 3 horizontal cells by gravity).
- [ ] **1st-Person Test: Heavy Crude Oil Viscosity (0.20) and Draining with Solid Blocks:**
  - Press **`C`** to drop into 1st person and walk into the newly spilled **`crudo`** blocks:
    - Verify that the crude oil block is dark, oily, translucent, and permeable.
    - Upon entering the crude oil, the avatar's horizontal speed, jump, and fall are drastically slowed (**viscosity factor `0.20`**, five times denser than dry land and noticeably heavier than water).
  - Select a solid block in the hotbar (e.g., `tierra` with key `1`), aim at a spilled `crudo` block on the ground, and **Right Click**:
    - Verify that the solid block **instantly replaces and drains the crude oil block**, allowing you to manually "dry up" any oil spill.
- [ ] **Rebuilding / Extending from a Spilling or Disconnected Column:**
  - Return to overhead view (**`C`**), activate **`1 -> 6 -> 2` (`Tubería`)**, and left-click directly on the **last column** of the pipeline that is in the `🔴 Derrame` (or `⚪ Desconectado`) state.
  - Continue the layout from that column to the cell in front of the Oil Refinery's (or Warehouse's) `puerto_crudo_in` and confirm with a **double left click**.
  - **Expected Result:** The new segments merge into the existing pipeline, the network seals in the **`🟢 Conectado`** state, and the active spill stops and clears immediately.

---

## Block 7: Thermoelectric Generation, `VentanaEnergia`, Electric Lantern, and Demographic Stress

> **Closing the Test Cycle:** With the petrochemical network operational and *Applied Metallurgy* researched, you erect the **Thermal Power Plant** to electrify the colony, audit the interactive **`VentanaEnergia`** modal, verify the avatar lantern switching to **`LÁMPARA ELÉCTRICA🟡`** (with its 72 h battery), and close the session with extreme demographic stress tests.

### 7.1 Thermal Power Plant (`1 -> 3 -> 8`): Fuel Selector, Reserve, and Coal Hauling
- [ ] **Construction:** In overhead view, press **`1` (Build) -> `3` (Industrial) -> `8` (`Central termoeléctrica`)** and place it on the **Industrial Zone** inside the Zone of Influence.
- [ ] **Operation in Coal Mode (Solid Hauling):**
  - Once built, open its `PanelPuesto` in View mode (`Esc`).
  - Verify the three fuel selector buttons: **`[Carbón]`** (active by default), **`[Combustible]`**, and **`[Crudo]`**, as well as the **`Reserva central:`** row.
  - Hire **Technicians** and **Haulers (`Obreros`)**:
    - Verify that haulers fetch `carbón` from the Urban Core or central warehouses (respecting the `Reserva central:` threshold) and unload it at the power plant (local capacity up to 500 u).
    - With technicians present and coal in its local deposit, the plant begins generating electrical energy for the city and its chimney emits smoke.
- [ ] **Operation in Crude Oil / Fuel Modes (Via Pipeline):**
  - Click **`[Combustible]`** or **`[Crudo]`**: verify that the power plant automatically releases its haulers (hiding the hauler row) and switches to feeding exclusively through its lateral pipeline ports (`puerto_combustible_in` or `puerto_crudo_in`). Leave it supplied and generating power.

### 7.2 Topbar "Energía" Button, `VentanaEnergia` Modal, and Camera Teleportation
- [ ] **Action:** On the HUD topbar, hover over the **Energy (`Energía`)** indicator and left-click.
- [ ] **Expected Result:**
  - The indicator acts as an **interactive button** (sharing the same visual style as `Almacén`, `Población`, and `Moral`) and opens the centered modal window **`VentanaEnergia`** (`TemaHUD`).
- [ ] **Global Summary and Lists in `VentanaEnergia`:**
  - **Balance Header:** Displays **Total Generated Capacity** (E/h), **Delivered Energy** (E/h), **Total City Demand** (E/h), and **Balance** (`Superávit (100%)` in green or `Déficit (-X%)` in red when consumer demand exceeds generation).
  - **Generating Sources Section:** Lists each Thermal Power Plant indicating its active fuel (`Carbón`, `Combustible`, or `Crudo`), remaining units in its local deposit, and contributed E/h.
  - **Consumer Buildings Section:** Lists each building demanding electricity (Oil Refinery, Fuel Producer, etc.), its status (`Conectado`, `Sin conexión`, `Déficit`), and its individual consumption in E/h.
- [ ] **Camera Teleportation on Click:**
  - Left-click on any of the buildings listed in `VentanaEnergia` (generator or consumer):
  - The Overhead Camera **flies with a smooth transition (`Tween`) to center directly over that building's exact coordinates** and opens its side panel for instant inspection or supply.

### 7.3 Switching the Avatar Lantern to `LÁMPARA ELÉCTRICA🟡` and Battery Cycle (72 h)
- [ ] **Prerequisite Met:** The Thermal Power Plant is active and delivering power to the city grid (`capacidad > 0`).
- [ ] **Action (Electric Ignition in City):** Switch to 1st person (**`C`**) while **inside the Zone of Influence** of the colony and press **`L`** to turn on the lantern.
- [ ] **Expected Result:**
  - Because the city now generates electrical power, the lantern turns on in **`LÁMPARA ELÉCTRICA🟡`** (Electric Lantern) mode (bright white light, 18 m range, without burning solid or liquid fuels from the warehouse).
  - `PanelLampara` displays the title **`LÁMPARA ELÉCTRICA🟡`** and the status **`Batería: 100% | 72 h`**.
- [ ] **Action (Discharge Outside the Zone of Influence):** Walk with the lantern on **outside the Zone of Influence** of the city and wait several hourly ticks (2 s per hour):
  - `PanelLampara` switches to displaying progressive battery discharge: **`Batería: -X% | Y h`** (deducting 1 h of battery per game hour outside coverage).
  - *(If the battery reaches `0 h` while outside the Zone of Influence, it automatically switches to `LÁMPARA TÉRMICA🟡`, burning fuel/coal/wood from the inventory).*
- [ ] **Action (Automatic Recharge Upon Returning to the City):** Step back inside the **Zone of Influence** of the electrified city:
  - The lantern stays in (or immediately switches back to) **`LÁMPARA ELÉCTRICA🟡`** and rapidly recharges its battery at **`+7.2 h` per game hour** (`Batería: +X% | Y h`) until reaching `100% | 72 h` again.

### 7.4 Demographic Stress Tests and Succession (End of Session)
> *(Note: Run these checks at the very end of the test session, as they alter the population or force emergency colony states).*

- [ ] **Unemployment (240 h) and Homelessness (72 h) Tolerance:**
  - Verify that colonists who remain in the `"Sin techo"` state for more than **72 hours (3 days)** emigrate from the colony, penalizing morale by `-10` points.
  - Verify that colonists who remain `"desempleado"` for **240 continuous hours (10 days)** without being hired peacefully emigrate, incrementing the evicted/emigrated counter.
- [ ] **Famine (0 Food) and Critical Morale Exodus (<=20%):**
  - If `comida` stock drops to `0`, each hour of starvation causes population casualties following `ORDEN_BAJAS_HAMBRUNA` (`militar > obrero > tecnico > especialista > investigador > desempleado`) and penalizes morale at **`-3.0 / day`** (`Hambruna crítica (-3.0/día)`, deducting `3.0 / 24` per tick).
  - When morale falls below or equal to **20% (`😡`)**, migration flow reverses into a staggered **brain drain exodus** (`Migración: ⚠ Éxodo de cerebros (X/mes)`), triggering a flight of talent that expels the most qualified colonists first following `ORDEN_EXODO_MORAL` (`investigador > especialista > tecnico > militar > obrero > desempleado`).
- [ ] **Avatar Succession (`K` Key or Drowning):**
  - Press the debug key **`K`** in 1st person (or deplete the oxygen bar to 0 underwater): `Ciudad.suceder_avatar()` executes (if military personnel exist, it applies succession with a 5 h electoral penalty and respawns at the origin `(0, 1, 0)` with full oxygen).

---

## Block 8: Live Verification of Complete Iconography and 3D Thumbnails (HUD / UI)

### 8.1 Topbar and Vector SVG Iconography
- [ ] **Action:** Inspect the topbar in 1st person and overhead mode.
- [ ] **Expected Result:**
  - Demographics displays the demographic group icon (`censo.svg`).
  - Morale displays the active emotional face icon based on its current value (`moral_alta.svg` 🙂, `moral_neutra.svg` 😐, `moral_baja.svg` 🙁, `moral_critica.svg` 😡).
  - Warehouse button shows the chest icon (`almacen.svg`).
  - Food displays the wheat sack icon (`comida.svg`) and hourly trend arrow (`tasa_arriba.svg`, `tasa_neutra.svg`, or `tasa_abajo.svg`).
  - Power button displays the tri-color dynamic lightning bolt (`energia_dorado.svg` in surplus, `energia_gris.svg` at neutral 0 demand, `energia_rojo.svg` in deficit) alongside live kW measurements (e.g. `12 kW / 8 kW`).
  - Urban level displays the Roman numeral badge (`romano_1.svg`, `romano_2.svg`, etc.).

### 8.2 Build Mode Buttons with 3-Corner Badges & Live 3D Thumbnails
- [ ] **Action:** Switch to overhead camera (`C`) and press `1` (Build) $\to$ check submenus `1` through `6`.
- [ ] **Expected Result:**
  - Building buttons are enlarged (104×76 px) and display the 3-corner badge overlay:
    1. **Top-Left Corner:** Vertical stack of icons (14×14 px) for construction resource inputs.
    2. **Top-Center:** Golden power bolt (14×14 px) if the structure requires electricity to function.
    3. **Top-Right Corner:** Representative icon (18×18 px) of the primary product or civic function.
  - Under Roads category (`5`), button displays live 3D thumbnail with gravel ballast and wooden ties.
  - Under Conduits category (`6`), Aqueduct button shows stone flume on pillars, and Pipeline button shows metallic cylindrical pipe with elbow.
  - In 1st-person hotbar, glass blocks and door blocks show wooden contrast framing for clear visibility against backgrounds.

### 8.3 1st-Person HUD Indicators and Contextual Mining Tool
- [ ] **Action:** Switch to 1st person (`C`). Turn on lantern (`L`), submerge underwater, and mine stone/dirt/trees holding left click.
- [ ] **Expected Result:**
  - Lantern panel displays the lamp icon alongside a green/gold styled `ProgressBar` with percentage battery.
  - When swimming underwater, oxygen display shows cyan bubble row depleting over time.
  - Mining stone displays the progress bar alongside the pickaxe icon (`herr_pico.svg`); shoveling dirt displays the shovel icon (`herr_pala.svg`); chopping trees displays the axe icon (`herr_hacha.svg`).

### 8.4 Global Windows, Outpost Panels, and Modal Dialogs
- [ ] **Action:** Open Population (`P`), Warehouse (`A`), Occupations, Energy (`E`), and Morale (`M`).
- [ ] **Expected Result:**
  - All window headers display their thematic icon and `✕` close button.
  - In `VentanaAlmacen`, each resource has its 20×20 px icon beside the name.
  - In `VentanaPoblacion` and `VentanaOcupaciones`, each profession and category displays its representative icon.
  - In `VentanaMoral`, central gauge displays 32×32 px emotional mood face, and factors show balance, food, cornucopia, and shield icons.
  - In `VentanaBaul`, resources display icons and extraction buttons display `btn_menos`, `btn_mas`, and `extraer_todo`.
  - In `PanelEdificio` and `PanelPuesto`, colonization shows lock/clock/door icons, pause/play shows button icons, priority displays Roman/arrow badges, schools and outposts show Roman numeral level badges (`romano_1..3.svg`), staffing `+`/`-` buttons display clean centered icons without overlapping text, and the production line renders the 16px vector SVG resource icon.
  - Modal confirmation dialogs feature OK button with green `check.svg` and Cancel with red `cruz.svg`.

---

## Quick Summary and Sign-Off Table

| Block | Verified Feature (in logical gameplay order) | Status (OK / Fail) | Tester Notes |
| :--- | :--- | :---: | :--- |
| **1.1** | 1st-person movement, face highlight, chopping/mining with progress bar, and block placement | | |
| **1.2** | Swimming in water ($\ge 2$ blocks), currents, oxygen bar, and draining with solid blocks | | |
| **1.3** | Lantern in initial Thermal mode (`L`: fuel 10h, coal 6h, wood 5h) and stacked oxygen window | | |
| **2.1** | 1st Building with `B`: 3D doors (brass handle & hinges), crisp windows, founds **Urban Core** & saves blueprint | | |
| **2.2** | Urban Core remodeling (`Shift+B`) in free-edit mode without losing headquarters status | | |
| **2.3** | Painting Residential Zone (`2-1`), 3D blueprint thumbnail (`1-1`), `Ctrl+Scroll` rotation, and on-foot supplying | | |
| **2.4** | 1st Habitable Residence spawns with `Colonizable: SÍ` & massive immigration (initial morale >50%) | | |
| **2.5** | Remodeling the only populated residence creates `"Sin techo"` colonists and redeclaring with `B` reabsorbs them | | |
| **2.6** | 2nd Residence built by colonists spawns as a buffer (`Colonizable: NO 24h`) and relocates residents with 0 homeless | | |
| **2.7** | Row houses (flood-fill stops at neighbor wall) and Urban Core relocation (5 h grace period) | | |
| **3.1** | Overhead road tool (`1-5-1`) with SVG icons, spec sheet (`+35%`), and clean right-click cancellation | | |
| **3.2** | Shared leveling and clearance between facing doors across a street | | |
| **3.3** | Progressive road laying by colonists (consecutive yellow `ViaObraOverlay`) and segment merging | | |
| **3.4** | Manual on-foot road intervention (`V`): build (left click) and demolish (right click) 2×2 sections | | |
| **3.5** | Unified overhead demolition (`3`): buildings and roads with Dijkstra around 90° corners & orange outline | | |
| **3.6** | Construction priorities (`Normal`/`Alta`/`Baja` in `PanelEdificio`) and strict dispatch hierarchy | | |
| **4.1** | Responsive topbar (`"tierras raras"`), alphabetical Warehouse A-Z (`"Bloques de piedra"`), Population & Occupations (▼/▶) | | |
| **4.2** | Dynamic morale: rate in `/día`, 3 migration tiers (<=20 exodus, 20-50 with beds, >50 massive) & factors in `VentanaMoral` | | |
| **4.3** | Peripheral outposts (`1-2-1..4`): `PanelPuesto` clean title, Roman badges, clean +/- buttons & production row with SVG icons | | |
| **4.4** | Road preference in pathfinding (`BuscadorRutas`: road cost 3 vs terrain 8) and loaded right-of-way priority | | |
| **4.5** | 1st-person interaction with active outpost chest (`VentanaBaul` via `E`: centered `320x260`, scroll, and quick close) | | |
| **5.1** | Technical School (`1-4-1` on Residential Zone): 4-apprentice cohort (24 h) graduates **3 Technicians** & mine levels | | |
| **5.2** | Industrial Zone (`2-2`) & Block Factory (`1-3-4`): 5×6 footprint, chimney smoke, 1:3 recipe & civic stone priority | | |
| **5.3** | Central reserve control (`0/50/100/250/500 u`) in refineries: protects central stock against over-refining | | |
| **5.4** | Specialist School (`1-4-2`): requires Technical School and graduates **2 Specialists** after 48 h | | |
| **5.5** | University (`1-4-3`): requires Specialist School, manual start, pause, 100%-refund cancel & **Applied Metallurgy** | | |
| **6.1** | Pumping Station (`1-2-5`): $\ge 2$-block water depth check, pier, `puerto_agua_out`, and Technician operation | | |
| **6.2** | Extraction Center (`1-2-6`): underground pool detection, dynamic iron drill column, and crude oil depletion | | |
| **6.3** | Fluid Warehouse (`1-3-9`, 6 ports in dropdowns), Oil Refinery (`1-3-6`), and Fuel Producer (`1-3-7`) | | |
| **6.4** | Elevated conduits (`1-6-1`/`1-6-2`): readable labels, $Y+4$ height, road/colonist underpass & columns every 5 blocks | | |
| **6.5** | Grade-separated conduit crossings: double lateral column at $Y=6$ with 1 clear air block ($Y=5$) between conduits | | |
| **6.6** | Port connections, 400/600 Oil Refinery split, `PanelCanalizacion` inspection, and ghost-free demolition | | |
| **6.7** | Open-end physical spill (`🔴 Derrame`), 1st-person 0.20 viscosity & solid-block draining of `crudo`, and column reconnection | | |
| **7.1** | Thermal Power Plant (`1-3-8`): `Carbón`/`Combustible`/`Crudo` selector, central reserve, and coal hauling | | |
| **7.2** | Topbar "Energía" button and `VentanaEnergia`: global balance, generators, consumers, and camera teleportation | | |
| **7.3** | Lantern switching to `LÁMPARA ELÉCTRICA🟡` (72 h battery on grid, discharge outside influence & `+7.2 h/tick` recharge) | | |
| **7.4** | Final demographic stress: homeless (72 h) / unemployed (240 h) emigration, famine (-3.0/day), exodus (<=20%) & succession (`K`) | | |
| **8.1** | Topbar: censo icon, 4 mood face icons, warehouse icon, food trend arrow, and tri-color power bolt with kW | | |
| **8.2** | Build Menu (104×76 px): 3-corner badges (inputs, power, output) and 3D thumbnails (roads, aqueducts, pipes) | | |
| **8.3** | 1st-person HUD: lantern ProgressBar, oxygen bubble row, contextual tool icon beside mining progress | | |
| **8.4** | Global & interaction windows: icons in warehouse/chest, professions in population, `PanelPuesto` Roman badges & prod. SVG | | |
| **8.5** | Modal dialogs and controls: confirmation `check`/`cruz`, building door status icons, golden keycaps | | |

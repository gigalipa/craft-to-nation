# Live QA Script — Craft to Nation

This document is the comprehensive, step-by-step manual testing script designed to verify live inside the running game (**F5** in Godot) that all features, fluid mechanics, elevated conduit routing, energy grid management, colonist behaviors, and balance systems operate properly without errors.

The guide is structured in a **chronological and logical gameplay sequence**: starting with first-person avatar mechanics at spawn, progressing through town foundation, road network, municipal logistics, heavy industry, and elevated conduit networks, up to colony-wide electrical grid supervision.

---

## 0. Setup and Global Controls

### Launching the Environment
1. Open the project in Godot and press **F5** (or run the main scene `Main.tscn`).
2. Verify that the avatar spawns in the world and that the top HUD bar is visible.

### Key Keybindings

#### First-Person (Avatar)
| Key / Action | Function |
| :--- | :--- |
| **C** | Toggle between **1st-person** and **Top-down Camera** (with flight and animated camera transition). |
| **W, A, S, D** | Avatar movement. |
| **Space** | Jump / Swim upwards in liquids. |
| **L** | **Toggle omnidirectional lantern** on/off. |
| **E** | Interact (open/close doors and chests) / Close active modal windows. |
| **G** | Toggle on-foot deconstruction / manual demolition mode. |
| **V** | Toggle on-foot road interaction mode: Left Click builds section, Right Click demolishes section. |
| **B / Shift + B** | Declare building structure (**B**) / Initiate remodel (**Shift + B**) while aiming at the door. |
| **Esc** | Close active popup, exit road mode, or exit deconstruction mode. |

#### Top-Down Camera (City Management)
| Key / Action | Function |
| :--- | :--- |
| **W, A, S, D** | Horizontal camera panning across the X/Z plane. |
| **Q / E** | **Orbital rotation:** Rotate view 45° to the left (**Q**) or right (**E**). |
| **Mouse Wheel (Scroll)** | **Zoom:** Move closer or farther obliquely relative to the focal point. |
| **Ctrl + W / Ctrl + S** | **Pitch:** Adjust vertical tilt angle of the camera. |
| **Shift + W / Shift + S** | **Vertical Elevation:** Raise (**Shift+W**) or lower (**Shift+S**) camera elevation directly. |
| **1** | **Build** menu (1: Residential, 2: Outposts/Peripheral, 3: Industrial, 4: Research, 5: Roads, 6: Conduits). |
| **2** | **Zoning** menu (1: Residential/Zone A, 2: Industrial/Zone B, 3: Clear Zone). |
| **3** | Unified **Demolish** mode (buildings and road segments with guided preview). |
| **Z / X** | Back to previous submenu (**Z**) / Next page (**X**) in numeric menus. |
| **Ctrl + Scroll** | Rotate blueprint or building preview (90° increments during placement). |
| **Left Click** | Place path waypoint, place structure, or inspect building/conduit. |
| **Double Left Click** | Confirm road or conduit layout. |
| **Right Click** | Cancel accumulated segment / cancel placement mode. |
| **Esc** | Return to neutral "Inspect/View" mode or close open windows. |


---

## Block 1: Fluid Physics, Avatar, and On-Foot Tools (1st Person)

> **Implemented mechanics:** Viscous crude oil physics (0.20), liquid immersion, oxygen consumption, solid block displacement/draining, omnidirectional lantern with electric/thermal hierarchy, and centered storage chest UI.

### 1.1 Immersion and Viscosity in Crude Oil and Liquids
- [ ] **Action:** Walk or navigate towards a natural or spilled `crudo` (crude oil) block.
- [ ] **Expected result:**
  - The crude oil block is translucent dark oily amber and has **no solid collision** (permeable).
  - Upon entering the oil, avatar horizontal movement is significantly slowed (viscosity factor **0.20**; noticeably denser and heavier than water).
  - Jumping inside crude oil is damp and heavy, with a slow sinking rate.
- [ ] **Action (Oxygen depletion):** Submerge the avatar's head completely in crude oil or water.
- [ ] **Expected result:**
  - The oxygen gauge starts depleting.

### 1.2 Draining and Drying Liquids by Placing Solid Blocks
- [ ] **Action:** Aim at a cell flooded with liquid (`crudo`, `agua`, or `combustible`) holding a solid block in hand (dirt, wood, stone, etc.) and right-click to place it.
- [ ] **Expected result:**
  - The solid block **immediately overwrites and displaces the liquid**.
  - Placement is not rejected: the liquid cell is dried/drained, and the solid block is placed in the world.

### 1.3 Player Omnidirectional Lantern (Key `L`) and PanelLampara
- [ ] **Action:** In 1st-person view, press the **`L`** key.
- [ ] **Expected result:**
  - An omnidirectional light source illuminates around the avatar.
  - The HUD displays the **`PanelLampara`** window:
    - While within colony power grid coverage: displays title **`LÁMPARA ELÉCTRICA🟡`** and battery status `Batería: 100% | 72 h` (or recharging `+X% | Y h`).
- [ ] **Discharge and thermal fallback:** Walk outside colony electrical grid coverage with the lantern turned on:
  - As game hours elapse, battery discharges progressively (`-X% | Y h`).
  - Upon battery depletion (0 h), the lantern automatically switches to **`LÁMPARA TÉRMICA🟡`**, drawing fuel from colony central stocks in priority order:
    1. *Fuel* (24 h / unit).
    2. *Coal* (6 h / unit).
    3. *Wood* (2 h / unit).
  - The panel displays: `Tiempo restante: X h | Y [Recurso]`.
- [ ] **Automatic recharge:** Return to the electrified colony zone: the lantern instantly switches back to Electric mode and recharges up to 72 h.
- [ ] **Turn off:** Press **`L`** again: the light turns off and the indicator displays the black circle `⚫`.

### 1.4 Stacked Oxygen Window
- [ ] **Action:** Submerge the avatar's head in water or crude oil while the lantern panel is open.
- [ ] **Expected result:**
  - The `PanelOxigeno` window is displayed **stacked vertically right below** the lantern panel without overlapping or obstructing the crosshair.

### 1.5 Chest Interaction and Quick Close (`VentanaBaul`)
- [ ] **Action:** Walk up to an outpost chest, aim at it, and press **E**.
- [ ] **Expected result:**
  - `VentanaBaul` opens cleanly centered on screen with a compact footprint (`320x260`).
  - Resource list includes a vertical scrollbar when holding multiple item types.
  - Mouse cursor is freed to transfer items using `-`, `+`, or `"Extraer todo"` (Extract all).
- [ ] **Action:** Press **E** again (or press **Escape**).
- [ ] **Expected result:**
  - The chest window closes immediately, and camera control is restored without delay.


---

## Block 2: Town Foundation, Housing, and Residential Lifecycle

> **Implemented mechanics:** Ground-floor required door rule, automatic blueprints with 3D isometric thumbnails, remodeling (`Shift+B` and top-down), eviction/relocation handling, party-wall buildings, immigration buffer (24h), and urban core relocation.

### 2.1 Construction and Declaration of 1st Residence (Ground Floor and Upper Floors)
- [ ] **Action:** Manually erect a 2-story house:
  - **Ground floor (Level 0):** Enclosed, with 1 exterior door, 1 window, beds, and a chest.
  - **Upper floor (Level 1):** Enclosed with walls, ceiling, access staircase, and windows, **with zero exterior doors**.
- [ ] **Action:** Aim at the main ground-floor door and press **B** to declare.
- [ ] **Expected result:**
  - Building is declared successfully: exterior doors are not required on upper floors.
  - Automatically generates a blueprint named: `Residencia [beds]x[chests]`.

### 2.2 Blueprints and Isometric Thumbnails in Top-Down Menu
- [ ] **Action:** Switch to top-down view (**C**), press **1** (Build) -> **1** (Residential).
- [ ] **Expected result:**
  - Up to 5 blueprints are listed with 3D isometric preview thumbnails.
  - When selecting one to place, the contextual card shows: `[Ctrl] [Scroll Icon] ROTATE` and `[Left Click Icon] PLACE`.
  - Rotating via Ctrl+Scroll turns the preview in 90° increments.

### 2.3 1st Residence: Automatically Colonizable
- [ ] **Action:** In top-down inspect mode (`Esc`), left-click the first completed residence.
- [ ] **Expected result:**
  - `PanelEdificio` shows: `Colonizable: SÍ (inmigración activa)` (Colonizable: YES) and button `[Pausar colonización]` (Pause colonization).
  - Accurate breakdown of residents by category respecting bed capacity.

### 2.4 Remodeling in 1st Person (`Shift + B`) and Top-Down Mode
- [ ] **Action in 1st person:** Walk to the door of the residence, aim at it, and press **`Shift + B`**.
- [ ] **Expected result:**
  - Notification: *"Remodelación iniciada para el edificio X: ahora en edición libre."* (Remodeling started: now in free edit mode).
  - Blocks are freed from building protection: can be mined, walls expanded, or beds added.
  - Residents are automatically relocated to available spare beds across the colony.
- [ ] **Action in top-down view:** Select an occupied residential building and click **`[Iniciar remodelación]`** (Start remodel).
  - Modal confirmation displays relocation breakdown and warns if colonists will become homeless.
  - Upon confirmation, the building enters free edit mode.

### 2.5 "Homeless" Colonists and Automatic Reabsorption
- [ ] **Action:** Initiate remodeling on the only occupied residence when no other beds exist in the colony.
- [ ] **Expected result:**
  - The **Población** (Population) window displays: `"Sin techo: X"` (Homeless: X).
  - Homeless consume food at unemployed rates and do not take workstation jobs.
- [ ] **Action:** Redeclare the residence (pressing **B** at the door) or build and declare a new one.
- [ ] **Expected result:**
  - Homeless colonists are immediately reabsorbed into available beds and resume normal status.

### 2.6 Wall-to-Wall Attached Buildings (Party Walls)
- [ ] **Action:** Build two adjoining houses sharing a party wall and declare both (Building A and Building B).
- [ ] **Action:** Start remodel on Building A only.
- [ ] **Expected result:**
  - Building A enters free edit mode; Building B remains intact and protected.
- [ ] **Action:** Edit Building A and redeclare it with **B**.
- [ ] **Expected result:**
  - The flood-fill algorithm halts cleanly at Building B's wall boundary: declares A cleanly without absorbing B.

### 2.7 2nd Residence Onwards: Housing Buffers and Manual Control
- [ ] **Action:** Build and declare a second residence in the colony.
- [ ] **Expected result:**
  - Spawns as `Colonizable: NO (apertura en 24 h)` (Colonizable: NO, unlocks in 24h) and button `[Permitir colonización]` (Allow colonization).
  - Its beds serve as relocation buffers for existing citizens, but do not attract external immigrants.
  - Each game hour decreases the timer until opening automatically at 24h.
- [ ] **Action:** Click `[Permitir colonización]`.
  - Immediately switches to `Colonizable: SÍ (inmigración activa)`.
- [ ] **Action:** Click `[Pausar colonización]`.
  - Reverts to `Colonizable: NO (buffer protegido)`.

### 2.8 Urban Core (Town Hall) Exception and Relocation
- [ ] **Action:** Initiate remodel on the Urban Core (`Shift + B` or in top-down).
- [ ] **Expected result:**
  - Enters free edit mode **without evicting citizens or creating homeless colonists** (organic expansion).
- [ ] **Action:** Select a completed secondary residence and click *"Asignar como núcleo urbano"* (Assign as urban core).
- [ ] **Expected result:**
  - Confirmation modal appears with a 5-hour grace period.
  - Urban Core and its influence radius relocate to the new headquarters without resource loss.


---

## Block 3: Road Infrastructure, Traffic, and Colonist Navigation

> **Implemented mechanics:** Dynamic road stats card, SVG vector iconography, right-click clean cancellation, progressive construction by road crews, manual 1st-person interaction via V key, Dijkstra-guided demolition around 90° corners, and road preference weighting in BuscadorRutas.

### 3.1 Top-Down Road Placement Tool and SVG Iconography (`1` -> `5` -> `1`)
- [ ] **Action:** In top-down view (**C**), press **1** (Build) -> **5** (Roads) -> **1** (Lay Road).
- [ ] **Expected result:**
  - Contextual card displays real vector icons:
    - `[Left Click Icon] PLACE POINT`
    - `[Double Left Click Icon] CONFIRM`
    - `[Right Click Icon] CANCEL`
    - `[Esc] EXIT`
  - Dynamic technical card showing `Speed: +35%` and live resource costs.
- [ ] **Clean cancellation:** Left-click on ground to place anchor, move mouse, then press **Right Click**:
  - The segment cancels immediately without leaving phantom tiles.

### 3.2 Shared Grading and Leveling Between Facing Doors
- [ ] **Action:** Place a road or position a building opposite another with doors 2–3 blocks apart on uneven sloped ground.
- [ ] **Expected result:**
  - Terrain between both facing doorways grades to a shared uniform elevation without steep drop-offs or inaccessible steps.

### 3.3 Progressive Road Laying by Colonists (`ViaObraOverlay`)
- [ ] **Action:** Trace a road and confirm with **double left click**.
- [ ] **Expected result:**
  - Construction site is delineated by a **yellow perimeter outline** on the ground (`ViaObraOverlay`).
  - Up to 4 available laborers arrive to work.
  - **Consecutive construction:** Advances from one end to the other, completing each cell (leveling, filling, or ramps) in continuous order.
  - As cells complete, the yellow outline recedes until the project is finished.
- [ ] **Road merging:** Trace an adjacent road segment connected to an active roadwork:
  - Automatically merges into the existing job under the same 4-laborer crew.

### 3.4 Manual On-Foot Road Interaction in 1st Person (Key `V`)
- [ ] **Action:** In 1st person, press **`V`** to toggle road tool mode.
- [ ] **Build (Left Click):** Aim at a yellow wireframe road section and left-click:
  - Instantly builds the **entire 2x2 section**, placing road slabs/wedges without spamming notifications.
- [ ] **Demolish (Right Click):** Aim at a completed road section and right-click:
  - Instantly removes the entire 2x2 section and any road ramps.
- [ ] Press **`V`** or **Esc** to exit road mode.

### 3.5 Unified Top-Down Demolition Tool (Key `3`)
- [ ] **Building Demolition:** Press **`3`** and click a building: toggles its red demolition marker.
- [ ] **Guided Road Demolition:** In mode **`3`**, click a built road tile:
  - Move cursor along the road path: a **translucent orange preview** appears (`ViaDemolicionOverlay`).
  - **90° Corners:** Preview covers the full double-lane width (4 cells wide) and faithfully hugs outer corner contours without diagonal shortcuts.
- [ ] **Confirmation:** **Double left-click** on the preview:
  - Sets a **persistent orange wireframe outline** on the ground.
  - Colonists arrive to demolish, and the orange outline recedes tile by tile as work progresses.

### 3.6 Road Preference in Colonist Pathfinding (`BuscadorRutas`)
- [ ] **Test conditions:** Have a colonist at point A and assign a distant destination B, with a dirt road connecting both sectors while detouring around open wilderness.
- [ ] **Expected result:**
  - The colonist **prefers walking along the dirt road** (traversal cost 3) over cutting straight through rough open terrain (traversal cost 8).
  - If the destination does not touch the road, the colonist stays on the road until the closest possible point, only walking on natural ground for the final stretch.

### 3.7 Traffic Priority and Right-of-Way in Narrow Paths
- [ ] **Action:** Observe colonists crossing head-on on a single-tile narrow trail.
- [ ] **Expected result:**
  - The colonist carrying high-priority cargo (food, fuel, etc.) has right-of-way.
  - The empty or unassigned colonist steps aside to a lateral tile to let them pass.


---

## Block 4: Civic Management, Logistics, and Construction Governance

> **Implemented mechanics:** Responsive top bar, alphabetical storage sorting, collapsible occupations tree, unified labor pool, immediate assignment, job priorities (Normal/High/Low), peripheral outposts, and selective starvation casualties.

### 4.1 Topbar and Alphabetical Warehouse
- [ ] **Action:** Examine the top bar:
  - Key counters: Food, Energy, and Critical Resource (rare minerals formatted as `"tierras raras"` / rare earths).
- [ ] **Action:** Click the **Almacén** (Warehouse) button:
  - Resource inventory is strictly sorted **A to Z**.
  - Verify the presence of the new resource `"Bloques de piedra"` (`bloques_piedra` / Stone blocks), produced by crushing stone in the block factory.

### 4.2 Occupations Window and Unified Population View
- [ ] **Action:** Open Population and navigate to **Ocupaciones** (Occupations):
  - 4 collapsible categories: `▼ Recolección` (Gathering), `▼ Industria` (Industry), `▼ Investigación` (Research), `▼ Energía` (Energy).
  - Clicking a header collapses (`▶`) or expands (`▼`) the category. Buildings listed from newest to oldest.
- [ ] **Population Window:** Displays the unified status line: `Obreros: Total · X empleados · Y desempleados` (Laborers: Total · X employed · Y unemployed).

### 4.3 Menu Pagination via `Z` and `X` Keys and Clean Zone Overlay Hiding
- [ ] **Pagination:** In any top-down submenu with more than 10 entries, press **X** to page forward and **Z** to page back or exit.
- [ ] **Zoning:** Upon exiting Zoning mode (`2`), colored zone rectangles cleanly hide.

### 4.4 Modals and Dialog Boxes with TemaHUD
- [ ] **Action:** Trigger a confirmation dialog (confirm demolition or urban core relocation).
- [ ] **Expected result:** Modal window styled with dark translucent background and clean HUD borders (no default gray engine windows).

### 4.5 Configurable Construction Priorities (`PanelEdificio`)
- [ ] **Action:** In top-down view, select a building under construction.
- [ ] **Expected result:** Button **`[Prioridad: Normal]`** (Priority: Normal) is displayed.
- [ ] **Cycle:** Successive clicks cycle: `Normal` -> `Alta` (High) -> `Baja` (Low) -> `Normal`.
- [ ] **Strict colonist dispatch hierarchy:**
  1. *High Priority Construction*
  2. *Normal Priority Construction*
  3. *Demolitions*
  4. *Road Laying*
  5. *Low Priority Construction*

### 4.6 Gathering Outposts (Mine, Lumber, Hunting) and Hauling
- [ ] **Doorway hauling:** Haulers pick up crates at the front `servicio` (service) cell without freezing inside the building.
- [ ] **Tier fallback:** Outposts staffed with general laborers instead of specialized technicians downgrade production output to baseline tier without stalling.

### 4.7 Selective Famine Casualties
- [ ] **Critical starvation scenario (0 food):** If famine triggers colonist deaths, eviction/loss affects **specialists and researchers** before touching the core manual laborer base.

### 4.8 Dynamic Morale, Continuous Productivity, and Demographic Exodus
- [ ] **Action:** Observe the morale indicator on the top bar.
- [ ] **Expected result:** Displays an interactive styled button showing mood and percentage (starts with pioneering optimism at `🙂 75%`). Icon reacts dynamically: `😡` (<20%), `🙁` (20-35%), `😐` (35-65%), and `🙂` (>=65%).
- [ ] **Action:** Click the morale button or press key **`M`**.
- [ ] **Expected result:**
  - Opens the centered modal window `VentanaMoral`.
  - Displays current emotional status, projected hourly rate ($\Delta M$/h), active continuous productivity multiplier ($X = 0.5 \times 2^{(Y/50)}$), and migration rate.
  - Full analytical factor breakdown: baseline inertia, food variety, resource shortages, homelessness drag, and 7-day danger buffer.
  - Closes cleanly with X, `Esc`, or `M`.
- [ ] **Action (Demographic Exoduses and Tolerance):**
  - Overflow homeless population: verify -0.05/h morale penalty per homeless colonist, and 72h (3 days) tolerance before emigration.
  - Idle unemployed colonists: verify peaceful exodus after 10 continuous days (240 hours) without job assignment.
  - Induce critical morale (<20%): verify migration inverts to active exodus with hierarchical brain drain (`investigador` > `especialista` > `tecnico` > `militar` > `obrero`).

---

## Block 5: Fluid Extraction and Industrial Balancing

> **Implemented mechanics:** Pumping station (water depth >= 2), Extraction Center (deposit scanning, iron drill column, remaining crude reserves), block factory (5x6 footprint, stone masonry chimney, 1 stone -> 3 blocks recipe and civic consumption priority in construction), raw material reserve control in refineries and thermal power plant ([0, 50, 100, 250, 500] u), shared fluid warehouse (6 ports), oil refinery storage caps (400 crude / 600 fuel), thermal power plant with fuel selector and coal hauling, and interactive research university.

### 5.1 Pumping Station (`1` -> `2` -> `5`)
- [ ] **Shallow water test:** Attempt placement in 1-block deep water: rejected with message *"requiere al menos 2 bloques de profundidad de agua bajo su muelle"* (requires at least 2 water blocks under pier).
- [ ] **Deep water test ($\ge 2$ blocks):** Place with pier over deep water and shore foundation on land:
  - Placement succeeds.
  - Land-facing wall features **`puerto_agua_out`** port at elevation $Y=4$. Extracts infinite water when staffed with technicians.

### 5.2 Underground Extraction Center (`1` -> `2` -> `6`)
- [ ] **No deposit test:** Hover over ground with no underground deposit: rejected with *"No se detecta depósito subterráneo de agua o crudo"* (No underground water or crude oil deposit detected).
- [ ] **Deposit detected test:** Hover over a subterranean crude or water reservoir:
  - Valid footprint. Technical card adds dynamic cost in `estructura_hierro` based on drill depth to reservoir.
- [ ] **Information panel:** Click Extraction Center in inspect mode (`Esc`):
  - Displays: `Crudo restante en pozo: X bloques` (Crude remaining in well: X blocks) or `Pozo de agua (inagotable)` (Water well: infinite).
  - During operation, physically depletes underground oil blocks one by one in real time.

### 5.3 Block Factory and Stone Processing (`1` -> `3` -> `4`)
- [ ] **Action (Construction):** In top-down view, press **1** (Build) -> **3** (Industrial) -> **4** (Block Factory).
- [ ] **Expected result:**
  - Displays the 5x6 footprint with 3D isometric preview thumbnail on the mode bar.
  - Structure features `bloque_piedra` walls, front service entrance door (z=0) for raw stone, and rear product exit door (z=5) for finished blocks.
  - On the roof (`Vector2i(2, 3)`), the masonry chimney emits smoke and stone dust particles in real time via `HumoRefinerias`.
- [ ] **Action (Production and Yield):** Assign laborers or technicians and supply raw stone.
- [ ] **Expected result:**
  - Each batch consumes **1 unit of raw stone** and produces **3 units of `bloques_piedra`** (3x mineral yield multiplier for quarry masonry).
  - Local storage buffer with shared capacity of up to 1000 units.
- [ ] **Action (Civic Consumption Priority in Construction):** Initiate a construction site requiring stone (foundations, `bloque_piedra` walls, grading):
- [ ] **Expected result:**
  - `Ciudad.gd` preferentially deducts available `bloques_piedra` stock before consuming raw `piedra` from the general warehouse.
  - Total reported stone availability in the general warehouse displays the combined sum of processed blocks and raw stone.

### 5.4 Raw Material Reserve Control in Refineries and Thermal Power Plant
- [ ] **Action:** Select any refinery (Steel Mill, Sawmill, Block Factory, Charcoal Kiln, Rare Earths Refinery) or the Thermal Power Plant in inspect mode (`Esc`).
- [ ] **Expected result:**
  - `PanelPuesto` displays the **`Reserva central:`** (Central Reserve) row with the interactive reserve toggle button.
- [ ] **Action (Cycle values):** Successively click the reserve button.
- [ ] **Expected result:**
  - The button cycles through the predefined thresholds:
    `Sin reserva (0 u)` $\to$ `50 u` $\to$ `100 u` $\to$ `250 u` $\to$ `500 u` $\to$ `Sin reserva (0 u)`.
- [ ] **Action (Protection against Over-refining):** Configure a reserve of `100 u` on a refinery whose input raw material has 120 units in the central warehouse.
- [ ] **Expected result:**
  - Haulers withdraw a maximum of 20 units from the central warehouse to feed the refinery.
  - As soon as central stock drops to 100 units (or below), haulers immediately halt raw material withdrawals, keeping the base material reserve intact for player manual building and construction projects.

### 5.5 Fluid Storage Outpost (`1` -> `3` -> `9`)
- [ ] **Construction:** Build an `almacen` (5x5 stone warehouse).
- [ ] **Exterior ports:**
  - Left wall: inputs `1` (water), `3` (crude), `5` (fuel).
  - Right wall: outputs `2` (water), `4` (crudo), `6` (fuel).
- [ ] **Dropdowns in PanelPuesto:** When selected, ports are organized into **collapsible dropdowns by resource** (Water, Crude, Fuel) with status badges (`⚪`, `🟢`, `🔴`). All fluid warehouses share an instantaneous global fluid balance.

### 5.6 Oil Refinery: Partitioned Stock Limits (400 Crude / 600 Fuel)
- [ ] **Construction:** Build a `refineria_petrolera`.
- [ ] **Ports:** Features `puerto_crudo_in` and `puerto_combustible_out` (0 fluid haulers needed).
- [ ] **Capacity partition:** Supply crude via pipeline:
  - Local crude inventory caps at a **maximum of 400 units (40%)**.
  - Halts crude intake once reached, strictly preserving **600 free slots (60%)** for refined fuel production.

### 5.7 Fuel Synthesizer
- [ ] **Construction:** Build a `productor_combustible`.
- [ ] **Ports and logistics:** Features `puerto_agua_in` and `puerto_combustible_out`. Its haulers transport solid coal only.

### 5.8 Thermal Power Plant: Fuel Selector, Central Reserve, and Coal Hauling
- [ ] **Selector:** In `PanelPuesto`, interact with buttons **`[Carbón]`** (Coal), **`[Combustible]`** (Fuel), and **`[Crudo]`** (Crude).
- [ ] **Central reserve:** Configure the city reserve threshold for coal using the `Reserva central:` button to safeguard fuel for the player avatar lantern or secondary producers.
- [ ] **Hauling in Coal mode:** When set to `Carbón` and assigned haulers:
  - Haulers collect coal from the urban core or warehouses and deliver it directly to the power plant furnace as long as the central reserve threshold is respected.
- [ ] **Crude / Fuel modes:** These modes disable haulers (exclusively supplied via pipeline ports).

### 5.9 Interactive University: Start, Acceleration, Pause, and Cancellation with Refund
- [ ] **Manual start:** Click University in inspect mode: shows **`[Iniciar Investigación]`** (Start Research) button (does not auto-start).
  - Clicking opens modal showing iron and wood research costs.
- [ ] **Acceleration:** Assigning additional active researchers accelerates cohort progress.
- [ ] **Pause / Resume:** `[Pausar]` freezes research progress and toggles to `[Reanudar]`.
- [ ] **Cancel with full refund:** Click `[Cancelar]`: confirmation dialog **refunds 100% of invested resources**.


---

## Block 6: Elevated Conduit Network (Aqueducts and Pipelines)

> **Implemented mechanics:** Menu 1-6 with localized names, Y+4 clearance allowing colonist and road passage underneath, pillars every 5 blocks, grade-separated crossings via double pillars at Y+6 with 1-block air gap, z-fighting free continuous meshes, building port auto-connection, extension from disconnected/spilling conduits, clean demolition without phantom blocks, and physical fluid spreading spills.

### 6.1 Tool Activation and Human-Readable Stats Card (`1` -> `6`)
- [ ] **Action:** In top-down view, press **1** (Build) -> **6** (Conduits) or click the HUD button.
- [ ] **Select:** Choose **1** (**Acueducto** / Aqueduct) or **2** (**Tubería** / Pipeline).
- [ ] **Stats card:** Card shows human-readable material labels (e.g., `1 Bloque de acero` / Steel Block, `1 Estructura de hierro` / Iron Frame, never raw keys like `bloque_acero`).

### 6.2 Elevated Clearance ($Y_{ground}+4$) and Ground Traffic Circulation
- [ ] **Placement:** Left-click start point, drag several blocks, and confirm with double left click.
- [ ] **Result:** Conduit is elevated with 3 blocks of clearance above the ground ($Y = Y_{ground} + 4$).
- [ ] **Foot traffic:** Walk avatar underneath: underpass is completely unobstructed.
- [ ] **Surface road passage:** Select road tool (`1-5-1`) and route a ground road crossing underneath the elevated conduit:
  - Road builds cleanly straight through without collision or elevation conflicts.

### 6.3 Support Pillars Every 5 Blocks, Corners, and Z-Fighting Free Mesh
- [ ] **4-span pillars:** Lay a straight conduit $\ge 11$ blocks long:
  - Places vertical pillar columns at block 0, block 5, and block 10 (leaving exactly 4 open cells between pillars).
- [ ] **90° Corners:** Lay an "L" shaped route: corner vertex automatically places a required support column and an oriented corner block.
- [ ] **Mesh rendering quality:**
  - Conduit texture renders properly oriented and illuminated (normals face outward).
  - Intersection between horizontal beams and pillar cap blocks exhibits no coplanar z-fighting or face flickering.

### 6.4 Grade-Separated Pipeline Crossings (Double Pillar at $Y=6$ with Air Gap)
- [ ] **Action:** Have an existing conduit line A (e.g., North-South Aqueduct at $Y = Y_{ground} + 4$).
- [ ] **Action:** Route a new conduit line B (e.g., East-West Pipeline) crossing perpendicularly over A.
- [ ] **Expected result:**
  - On the cells immediately before and after the intersection, **two new 6-block-tall support pillars** are erected (reaching $Y = Y_{ground} + 5$).
  - The upper conduit crosses horizontally at **$Y = Y_{ground} + 6$**.
  - Exactly **1 full block of open air** is preserved between lower and upper conduits ($Y = Y_{ground} + 5$).
  - Both conduit lines remain physically isolated and do not collide.

### 6.5 Building Port Connections
- [ ] **Action:** Start routing by clicking on the cell facing an output port (e.g., Pumping Station).
  - First cell matches port height with no pillar beneath; first pillar is placed 5 blocks away.
- [ ] **Action:** Route to the input port of a refinery or warehouse and confirm:
  - Network seals and both ports become connected to the physical conduit system.

### 6.6 Top-Down Conduit Inspection (`PanelCanalizacion`) and Clean Demolition
- [ ] **Inspect:** In inspect mode (`Esc`), click any block along the conduit:
  - `PanelCanalizacion` opens showing: Type, Resource, Length, Connected Buildings, and Network Status.
- [ ] **Demolition:** Click *"Demoler canalización"* (Demolish conduit) and confirm:
  - Conduit is removed and materials are refunded.
  - **No phantom blocks:** The space facing the building port is completely freed; subsequent routings towards that port recognize it cleanly.

### 6.7 Reconstruction and Extension from Disconnected or Spilling Pillars
- [ ] **Action:** Have an incomplete or severed pipeline in `Desconectado` (Disconnected) or `Derrame` (Spill) state.
- [ ] **Action:** Select the pipeline tool and click on an existing pillar belonging to that network.
- [ ] **Expected result:**
  - The new segment connects seamlessly into the existing pipeline system.
- [ ] **Action:** Route the open end to a compatible recipient building port and confirm:
  - Network seals, port switches to **`🟢 Conectado`**, and active spills are cleared immediately.

### 6.8 Flow Simulation and Physical Liquid Spill Mechanics
- [ ] **Connected flow:** Water pumped from Pumping Station connected to Warehouse:
  - Water automatically deposits into Warehouse inventory every hour without haulers.
- [ ] **Open-ended spill:** Connect an extractor to a pipeline ending in open air without a recipient port:
  - On the next hourly tick, port transitions to **`🔴 Derrame`** (Spill) and HUD fires an alert.
  - At the open conduit end, a physical fluid block (`agua` or `crudo`) spawns, falls, and **spreads across the ground** (crude oil spreads viscously up to 3 horizontal tiles).


---

## Block 7: Energy Grid Balance and Supervision (`VentanaEnergia`)

> **Implemented mechanics:** Interactive "Energía" button on BarraSuperior, energy balance modal `VentanaEnergia` displaying generation capacity, delivered power, demand, power plant fuel reserves breakdown, consumer breakdown, and camera teleportation on click.

### 7.1 Interactive "Energía" Button on Top Bar
- [ ] **Action:** On the top HUD bar, hover over the **Energía** text.
- [ ] **Expected result:**
  - Element is an **interactive clickable button** (styled identically to `Almacén` and `Población`).
- [ ] **Action:** Click the Energía button.
- [ ] **Expected result:**
  - The modal window **`VentanaEnergia`** opens, styled with `TemaHUD`.

### 7.2 Colony Power Grid Overview
- [ ] **Action:** Observe the header of `VentanaEnergia`.
- [ ] **Expected result:**
  - Clear system metrics:
    - **Total Capacity Generated:** (E/h).
    - **Delivered Energy:** (E/h).
    - **Colony Demand:** (E/h).
    - **Balance:** `Surplus (100%)` or `Deficit (-X%)` highlighted in red if demand exceeds capacity.

### 7.3 Generation Sources and Fuel Breakdown
- [ ] **Action:** Review the **Fuentes Generadoras** (Generation Sources) section:
  - Lists each Thermal Power Plant in the colony displaying:
    - Active fuel type (`Carbón`, `Combustible`, or `Crudo`).
    - Remaining local fuel reserves in its storage tank.
    - Capacity contributed to the grid.

### 7.4 Consumer Breakdown and Demand
- [ ] **Action:** Review the **Edificios Consumidores** (Consumers) section:
  - Lists each industrial plant, refinery, or university requiring power.
  - Connection status (`Conectado`, `Sin conexión`, `Déficit`).
  - Individual demand in E/h and received power.

### 7.5 Camera Teleport on Building Click
- [ ] **Action:** Left-click on any building entry in the list (generator or consumer).
- [ ] **Expected result:**
  - Top-down camera smoothly flies and centers over that building's map coordinates, allowing immediate inspection and maintenance.


---

## Summary and Quick Approval Table

| Block | Feature Verified | Status (Pass / Fail) | Tester Notes |
| :--- | :--- | :---: | :--- |
| **1.1** | Viscous crude oil physics (0.20), immersion, and oxygen depletion | | |
| **1.2** | Draining and drying liquids by placing solid blocks | | |
| **1.3** | Omnidirectional lantern with `L` key, PanelLampara, electric/thermal fallback, and recharge | | |
| **1.4** | Stacked oxygen window beneath lantern while submerged | | |
| **1.5** | VentanaBaul centered UI (`320x260`), scrolling, and quick close via `E` / `Esc` | | |
| **2.1** | Required exterior door only on ground floor (Level 1 requires no exterior door) | | |
| **2.2** | Automatic blueprint naming `Residencia [camas]x[baules]` with 5 3D isometric slots | | |
| **2.3** | 1st Residence spawns as `Colonizable: SÍ` with accurate bed capacity | | |
| **2.4** | Remodeling via `Shift+B` on door and top-down panel (free editing and relocation) | | |
| **2.5** | "Homeless" status and automatic reabsorption upon adding beds | | |
| **2.6** | Attached party-wall buildings: flood-fill halts cleanly at neighbor's wall | | |
| **2.7** | 2nd Residence onwards as housing buffers (`Colonizable: NO 24h`) with manual override | | |
| **2.8** | Urban Core remodeling without eviction and core relocation (5h grace period) | | |
| **3.1** | Top-down road tool with SVG icons, live technical card, and clean right-click cancellation | | |
| **3.2** | Shared grading and leveling between facing doors across a street | | |
| **3.3** | Progressive road laying by colonists (yellow consecutive `ViaObraOverlay`) | | |
| **3.4** | Manual on-foot road interaction in 1st person (`V`): 2x2 section build/demolish | | |
| **3.5** | Unified top-down demolition (`3`): Dijkstra around 90° corners and persistent orange outline | | |
| **3.6** | Road preference in pathfinding (`BuscadorRutas`: road cost 3 vs wilderness 8) | | |
| **3.7** | Right-of-way and passing priority in narrow 1-tile paths | | |
| **4.1** | Responsive topbar (minerals as "rare earths") and alphabetical warehouse (A-Z) | | |
| **4.2** | Collapsible Occupations window (▼/▶) and unified population status line | | |
| **4.3** | Menu pagination with `Z`/`X` and clean zone overlay hiding | | |
| **4.4** | Modals and dialog boxes integrated with `TemaHUD` | | |
| **4.5** | Construction priorities (`PanelEdificio` Normal/High/Low) and dispatch hierarchy | | |
| **4.6** | Gathering outposts: doorway hauling on front cell and production tier fallback | | |
| **4.7** | Selective famine: specialists and researchers perish before manual laborers | | |
| **4.8** | Dynamic morale: 4 emoji mood button, `VentanaMoral` modal, 72h homeless tolerance & unemployment exodus | | |
| **5.1** | Pumping station: water depth $\ge 2$ validation, pier, and `puerto_agua_out` | | |
| **5.2** | Extraction center: subterranean deposit detection, iron drill column, and reserve depletion | | |
| **5.3** | Block factory (`1-3-4`): 5x6 footprint, chimney, 1:3 recipe, and construction priority | | |
| **5.4** | Central reserve control (`0/50/100/250/500 u`): protection against over-refining | | |
| **5.5** | Fluid storage outpost (`1-3-9`, 5x5 with 6 ports grouped in collapsible dropdowns) | | |
| **5.6** | Oil refinery: pipe ports without hauling and partitioned stock (400 crude / 600 fuel) | | |
| **5.7** | Fuel synthesizer: fluid ports and exclusive coal hauling | | |
| **5.8** | Thermal power plant: fuel selector, central reserve, and inbound coal hauling | | |
| **5.9** | Interactive university: manual start, acceleration, pause, and cancellation with refund | | |
| **6.1** | Conduit tool (`1-6-1` / `1-6-2`) with human-readable material names and dynamic costs | | |
| **6.2** | Elevated clearance $Y_{ground}+4$ with unobstructed colonist and road passage underneath | | |
| **6.3** | Support pillars every 5 blocks (4-span), corner blocks, and z-fighting free mesh | | |
| **6.4** | Grade-separated pipeline crossings: double pillar at $Y=6$ with open air gap | | |
| **6.5** | Automatic connection to building ports at $Y=4$ | | |
| **6.6** | `PanelCanalizacion` and clean demolition without phantom blocks at ports | | |
| **6.7** | Reconstruction and extension from pillars in Disconnected or Spill state | | |
| **6.8** | Flow simulation and physical liquid spill mechanics with active spreading | | |
| **7.1** | Interactive "Energía" button on top HUD bar | | |
| **7.2** | `VentanaEnergia`: global grid balance (Capacity, Delivered, Demand, Deficit) | | |
| **7.3** | Generation sources breakdown (Thermal power plants and fuel reserves) | | |
| **7.4** | Consumer breakdown (connection status and individual power demand) | | |
| **7.5** | Smooth camera teleportation when clicking any building in the list | | |

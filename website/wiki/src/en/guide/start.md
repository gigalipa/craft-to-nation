# Beginner's Survival & Settlement Guide

Welcome to the official beginner's guide for **Craft to Nation**.

In *Craft to Nation*, you begin your journey as an isolated pioneer in a procedurally generated wilderness. Through manual harvesting, structural engineering, district zoning, and automated logistics, you will transform a fragile campsite into a thriving industrial city.

This guide walks you through your first hours: surviving in first-person mode, declaring your **Urban Core**, managing the **Central Stockpile**, and organizing your initial workforce.

---

## 1. Genesis: The First Steps (First-Person Phase)

When you spawn into the world, you operate in visceral **First-Person Survival Mode**. Your initial priorities are shelter and caloric stability:

1. **Forage Immediate Sustenance:** Wild berry bushes and small game are vital. The pioneer avatar consumes calories at a standard rate of 5.0 food units per hour of continuous physical work.
2. **Harvest Basic Timber:** Target mature trees to gather initial wood blocks. Each trunk yields logs and construction wood.
3. **Craft Primitive Tools:** Fabricate basic mining picks and axes to drastically reduce manual block-breaking duration.
4. **Scout Settlement Ground:** Look for level terrain with immediate access to:
   - Fresh water (rivers, lakes, or coastlines for future pumping docks).
   - Abundant forest cover for lumber.
   - Exposed surface rock or mineral outcroppings for stone and iron.

---

## 2. Constructing Your First Airtight Shelter

Before founding your settlement, you must erect an enclosed shelter that satisfies the game engine's strict structural rules:

- **Structural Materials Only:** Walls must be built using structural blocks (`stone_block`, `wood_block`, or standard structural masonry). Natural unrefined ground (e.g. `dirt`) does **not** qualify as a structural wall.
- **Airtight Enclosure:** The room must be completely sealed on all four sides with a complete roof slab.
- **Valid Ground-Level Access:** The primary entrance door must be placed on the ground floor ($Y_{ground}$) with an unblocked 2-cell clearance facing outwards. Upper floors do not require exterior doors.
- **Interior Height & Bed Clearance:** Ensure interior ceilings are at least 3 blocks high. Each bed placed inside must maintain clear vertical and lateral access cells.

---

## 3. Declaring the Urban Core & Influence Area

Once your inaugural shelter is sealed, designate it as the **Urban Core** (*Núcleo Urbano*):

1. Point your crosshair at the shelter's main entrance door and trigger the building declaration mode (`Shift + B` or via the construction HUD).
2. The engine evaluates the internal volume, validates access pathfinding, and verifies structural integrity.
3. Upon approval, select **"Declare Urban Core"**.

### What Declaring the Urban Core Unlocks:
- **Area of Influence:** A circular civic radius projects outwards from the Core. Urban zoning (residential, commercial, and research facilities) can only be zoned within this protective perimeter.
- **City Builder Tactical Camera:** Press the camera toggle key (`C` or Middle Mouse Click) to switch seamlessly into the top-down isometric view for macro planning.
- **Central Stockpile Initialization:** The Urban Core acts as your colony's primary centralized depository.

---

## 4. The Central Stockpile Mechanics

All goods transported from remote outposts and domestic workshops converge into the **Central Stockpile** (*Ciudad.almacen*). Understanding its parameters is essential to prevent inventory waste:

| Storage Metric | Value | Behavioral Description |
| :--- | :--- | :--- |
| **Initial Food Stock** | 5,000 units | Starts completely filled to sustain the pioneer and early arrivals. |
| **Initial Wood Stock** | 200 units | Starter building material for initial shelters and basic fences. |
| **Standard Resource Base Cap** | 500 units | Base threshold per non-food resource (`LIMITE_BASE`). |
| **Food Storage Base Cap** | 5,000 units | Dedicated food silo threshold (`LIMITE_BASE_COMIDA`). |
| **Core Declaration Multiplier** | **×2.0** (`FACTOR_NUCLEO`) | Declaring the Core doubles capacity to **1,000 general / 10,000 food**. |
| **Residential Chest Bonus** | **+100 gen / +400 food** | Each chest (`BONO_BAUL`) placed inside residences expands total capacity. |

> [!WARNING]
> Stockpile caps are rigid. If haulers bring resources to a full Central Stockpile, incoming shipments cannot be unloaded and workers will pause deliveries. Regularly expand residential chest capacity or invest in secondary warehouse facilities.

---

## 5. Attracting Colonists & Initial Priority Allocation

The Urban Core itself is a strictly administrative structure without residential beds. To attract and house your first colonists:

### Step 1: Construct the First Residential Building
Erect a designated residential dwelling inside the Area of Influence containing at least 2 to 4 beds. The moment this house is declared and approved:
- Immigration activates automatically.
- New settlers arrive through the civic perimeter and claim unoccupied beds.

### Step 2: Allocate Roles (Gatherers vs. Haulers)
Open the settlement demographic panel or click on individual work outposts in the tactical camera view:
- **Foragers & Hunters:** Station 2–3 colonists at a Hunting & Foraging Post to secure ongoing caloric inflow.
- **Lumberjacks:** Assign 2 colonists to a Lumberjack Outpost to sustain continuous timber for construction.
- **Haulers (Carriers):** Essential! Remote outposts only store up to 1,000 units locally. Without assigned haulers (each carrying 150 units per journey), extraction posts quickly cap out and halt production.

```
       [ Extraction Outpost ]
         (Local Cap: 1,000)
                 │
                 │ ◄── Haulers (150 units/trip, speed: 2.5 cells/s)
                 ▼
       [ The Urban Core ]
         (Central Stockpile: 1,000 cap / 10,000 food)
```

### Step 3: Manage Bed Clearance and Homelessness
- Every colonist without a registered bed enters the **Homeless** state.
- Homeless settlers consume 3.0 food units per hour (identical to unemployed workers) and cannot be assigned to specialized crafting.
- You have a **72-hour grace period** to build additional residential beds before homeless settlers leave the colony in exile, inflicting a harsh **-10 civic morale penalty**.

---

## 6. Early-Game Checklist

- [ ] Clear terrain and collect 50+ raw wood blocks.
- [ ] Build a sealed 5×5 shelter with structural walls and ground door.
- [ ] Declare the shelter as the **Urban Core** to establish the Area of Influence.
- [ ] Switch to the top-down tactical camera and survey surrounding mineral deposits.
- [ ] Build a 2-bed residential house to trigger the first immigration wave.
- [ ] Emplace a Lumberjack Outpost near dense timber and assign 1 gatherer + 1 hauler.
- [ ] Emplace a Hunter-Gatherer Outpost near fauna/fruit and assign 1 gatherer + 1 hauler.
- [ ] Monitor the food balance in the top HUD to maintain positive net caloric intake.

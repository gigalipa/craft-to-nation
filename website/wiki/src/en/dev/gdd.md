# Game Design Document (GDD v3.57)

**Slogan:** *From first block to living nation.*  
**Campaign Motto:** *Survive. Craft. Automate. Lead.*  
**Genre:** Hybrid City Builder, First-Person Survival, Real-Time Strategy (RTS), Factory Management & Logistics.  
**Key Inspirations:** *SimCity*, *Age of Empires*, *Minecraft*, *Mindustry*.

---

## 1. Executive Summary & Core Design Pillars

*Craft to Nation* is an ambitious hybrid simulation and strategy game that bridges the visceral immersion of first-person survival sandboxes with the macroscopic vision of classic urban city builders and real-time strategy games. 

The player begins as an isolated pioneer in a procedurally generated, voxel-based wilderness. Through manual harvesting, architectural design, territorial district zoning, and the orchestration of complex logistical networks, the player elevates a fragile survival camp into an automated industrial metropolis capable of waging territorial campaigns.

### The Five Foundational Pillars:

```
  ┌────────────────────────────────────────────────────────┐
  │                 THE FIVE CORE PILLARS                  │
  ├────────────────────────┬───────────────────────────────┤
  │ 1. Perspective Duality │ First-person visceral action  │
  │    (Micro vs. Macro)   │ meets overhead tactical RTS.  │
  ├────────────────────────┼───────────────────────────────┤
  │ 2. Modularity &        │ Player-designed voxel rooms   │
  │    Blueprints          │ validated as functional units.│
  ├────────────────────────┼───────────────────────────────┤
  │ 3. Strategic Zoning &  │ Strict tripartite districts:  │
  │    Logistics Networks  │ Civic, Industrial, Periphery. │
  ├────────────────────────┼───────────────────────────────┤
  │ 4. Organic Demography  │ Differentiated metabolic fuel,│
  │    & Dynamic Morale    │ career tiers, dynamic morale. │
  ├────────────────────────┼───────────────────────────────┤
  │ 5. Portable            │ Exporting sovereign urban     │
  │    Sovereignty         │ cores into multiplayer arenas.│
  └────────────────────────┴───────────────────────────────┘
```

1. **Perspective Duality (Micro vs. Macro):** Players can seamlessly transition at any moment between first-person manual intervention (building walls, swinging picks, leading defenses) and the overhead tactical camera (allocating workforce, tracing highways, inspecting production metrics).
2. **Modular Blueprints & Automated Construction:** Players bypass repetitive block-by-block grinding by capturing custom-built houses, factories, and fortifications as parameterized blueprints that can be placed instantly and built by NPC work crews.
3. **Strategic Zoning & Tripartite Logistics:** Strict functional separation ensures natural city aesthetics and tactical vulnerabilities. Civic residences, heavy smelters, and wilderness extraction outposts require robust transport networks.
4. **Organic Economy & Demographics:** Population is not an abstract percentage. Each citizen is a physically simulated agent with caloric demands, vocational qualifications, housing dependencies, and psychological morale.
5. **Portable Sovereignty in Competitive Multiplayer:** The central Urban Core and validated blueprints can be packaged and deployed into procedural multiplayer worlds, ensuring rigorous balance without unearned late-game advantages.

---

## 2. The Four Gameplay Loop Phases

Gameplay unfolds across four interconnected technological and societal phases:

### Phase 1: Genesis & Survival (First-Person Immersion)
- The pioneer avatar spawns in a raw wilderness biome.
- Basic survival mechanics: gathering wild flora, hunting small game, chopping timber, mining stone outcroppings.
- Structural construction of the first airtight shelter and fabrication of starter tools.

### Phase 2: Settlement & Urban Foundation
- Enclosure and validation of the shelter as the **Urban Core**.
- Projection of the **Area of Influence** and activation of the overhead City Builder camera.
- Construction of dedicated residential barracks to trigger the first immigration waves.

### Phase 3: Zoning, Logistics & Industrialization
- Delimitation of **Zone A (Civic/Research)** and **Zone B (Industrial/Military)**.
- Establishing remote extraction outposts across the wilderness for coal, iron, copper, rare earths, and crude oil.
- Constructing transport arteries: packed dirt roads, paved stone highways, freight railways, and elevated modular fluid pipelines.
- Establishing advanced multi-stage refining chains (blast furnaces, chemical synthesizers, thermal power generation).

### Phase 4: Military Expansion & Sovereign Multiplayer
- Mass production of mechanized arms, artillery, and ammunition.
- Training specialized combat divisions and constructing defensive bastions.
- Leading sieges against rival factions and competing in persistent multiplayer arenas.

---

## 3. Tripartite Territorial Districts

To balance urban growth and prevent sprawling monolithic bases, the game enforces three strict territorial zones:

| District / Zone | Spatial Boundary | Permitted Structures | Restrictions & Strategic Philosophy |
| :--- | :--- | :--- | :--- |
| **Zone A: Civic & Research** | Contiguous civic perimeter around the Urban Core. | Residences, community halls, public squares, academies, universities, research laboratories. | **Zero heavy industry allowed.** Concentrates civil population, guarantees physical security, and streamlines food rationing. |
| **Zone B: Industrial & Military** | Contiguous industrial zone adjacent to Zone A or fortified as an annex. | Blast furnaces, steel mills, petroleum refineries, assembly plants, barracks, arsenals, armories. | **Zero residential dwellings permitted.** Focuses pollution, noise, heavy power draw, and logistics infrastructure. |
| **The Periphery (Extraction)** | Outside the civic Area of Influence, atop raw resource deposits. | Open-cast mines, logging camps, hunting lodges, fishing docks, oil pumps, forward watchtowers. | **No permanent houses or manufacturing plants.** Requires dedicated freight haulers, roadways, or pipelines to deliver goods to the city. |

---

## 4. Architectural Structural Recognition

A unique strength of *Craft to Nation*'s engine is dynamic building validation:

- **Structural vs. Terrain Materials:** Only blocks classified as structural (`wood_block`, `stone_block`, reinforced concrete, structural glass) register as valid building envelopes. Plain dirt or natural clay cannot be exploited as cheap structural walls.
- **Raycast Volume & Pathfinding Audits:** The engine floods the internal air volume to confirm airtight seal, measures ceiling clearances, and performs an A* pathfinding trace from the exterior entrance to every interior bed and workbench.
- **Non-Destructive Remodeling:** Players can modify existing buildings without bulldozing them. Aiming at the primary entrance and pressing `Shift + B` allows manual editing while temporarily suspending resident allocation.

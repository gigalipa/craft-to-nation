# Development Roadmap & Milestone Progress

This roadmap outlines the past, current, and upcoming development milestones for **Craft to Nation**, tracing its evolution from foundational proof-of-concept sandboxes to a full-featured strategy and simulation experience.

---

## 1. Milestone Status Overview

```
  Phase 1: Genesis & Survival            [████████████████████] 100% (Completed)
  Phase 2: Settlement & Urban Core       [████████████████████] 100% (Completed)
  Phase 3: Zoning, Logistics & Industry  [██████████████████░░]  92% (Active Finalization)
  Phase 4: Warfare & Multiplayer         [████░░░░░░░░░░░░░░░░]  20% (Architectural Design)
```

---

## 2. Detailed Phase Breakdown

### Phase 1: Genesis & Survival (Completed)
- [x] Voxel world generation with procedural biomes, heightmaps, and natural foliage.
- [x] First-person pioneer avatar controls, camera raycasting, and block interaction.
- [x] Manual resource extraction (mining stone/ores, chopping trees, foraging berries).
- [x] Primitive tool crafting system (durability, harvest speed modifiers).
- [x] Basic survival HUD (hunger bar, health, stamina, quick-inventory belt).

### Phase 2: Settlement & Urban Foundation (Completed)
- [x] Structural volume evaluation algorithm for airtight rooms and ceiling heights.
- [x] Urban Core (`Núcleo Urbano`) declaration mechanics via entrance doors (`Shift + B`).
- [x] Projection of the civic **Area of Influence** radius around the Core.
- [x] Seamless perspective toggle to overhead tactical City Builder camera (`C` key).
- [x] Bed allocation system and basic civilian immigration waves.
- [x] Parameterized blueprint capture, ghost preview, and auto-assigned construction crews.

### Phase 3: Zoning, Logistics & Industrialization (Current Phase — 92% Complete)
- [x] **Tripartite District Zoning:** Strict separation between Zone A (Civic/Research), Zone B (Industrial/Military), and the Periphery.
- [x] **Peripheral Extraction Outposts:** Lumberjack camps, stone/mineral mines, hunting lodges, and fishing docks with dynamic resource depletion.
- [x] **Solid Land Haulage:** Carrier haulers (150 capacity, 2.5 cells/s speed), weighted road pathfinding (cost 8 wilderness vs cost 3 packed dirt), and single-cell priority yield rules.
- [x] **Industrial Refining Chains:** Sawmills, block factories, charcoal kilns, steel blast furnaces, and petroleum refineries.
- [x] **Vocational Education & Demographics:** Technical School, Specialist Academy, and University vocational promotions.
- [x] **Pressurized Fluid Distribution:** Modular 4-piece elevated pipeline system at `Y + 6` (`Y + 5` ground clearance), viscosity physics, and pumping stations.
- [x] **Dynamic Morale System (GDD v3.56):** 0–100 psychological morale score modulating productivity (`X = 0.5 × 2^(Y / 50)`), starvation casualties, and brain drain exodus.
- [x] **Automated Test Coverage:** 28 complete test scenes running 100% in green (>560 test assertions).
- [ ] *In Progress:* Automated road laying by colonist road crews.
- [ ] *In Progress:* Universal Era 3 electrical grid connections for civil residences.

### Phase 4: Military Expansion & Competitive Multiplayer (Upcoming)
- [ ] **Defensive Fortifications:** Modular stone ramparts, crenelated battlements, arrow slits, and automated ballista turrets.
- [ ] **Military Divisions & Barracks:** Training militia infantry, crossbowmen, cavalry scouts, and siege sappers.
- [ ] **Siege Mechanics:** Trebuchets, battering rams, dynamic structural collapse physics under explosive impact.
- [ ] **Bandit Camps & AI Raids:** Wandering brigands and AI warlord strongholds threatening peripheral outposts.
- [ ] **Portable Sovereign Cores:** Serialization pipeline allowing players to export their Urban Core and blueprints into procedural competitive multiplayer servers.
- [ ] **Multiplayer Matchmaking & Territorial Warfare:** Real-time cooperative settlement building and competitive nation-versus-nation skirmishes.

---

## 3. Version History & Milestone Tracking

| Version | Milestone Focus | Status | Test Scene Suite |
| :--- | :--- | :--- | :--- |
| **v3.47** | Bed clearance validation and notification decoupling | Released | 25 scenes / 463 tests |
| **v3.49** | Outpost workforce levels 1–3, technical schools | Released | 26 scenes / 523 tests |
| **v3.50** | Fluid pipelines, thermal power plants, traffic priorities | Released | 26 scenes / 554 tests |
| **v3.52** | Non-destructive remodeling (`Shift+B`), homeless status | Released | 26 scenes / 562 tests |
| **v3.54** | Elevated pipeline modularity (`Y + 6`), oil viscosity | Released | 28 scenes / 100% green |
| **v3.56** | Dynamic Morale System, productivity curve, brain drain | **Current Baseline** | 28 scenes / 100% green |
| **v4.00** | Full Military Logistics & First Multiplayer Alpha | In Development | Target: Q4 2026 |

# Development Roadmap & Milestone Progress (GDD v3.57)

![Tactical aerial view of city defense and expansion](/assets/comparison-aerial.webp)

This roadmap tracks the past, current, and upcoming development milestones for **Craft to Nation** across the 7 official phases defined in **Section 11 of GDD v3.57**, backed by **28 automated test scenes running 100% in green**.

---

## 1. Seven-Phase Project Overview

```
  Phase 0: Pure Simulation Logic (PoC 1 & 2)         [████████████████████] 100% (Completed)
  Phase 1: 1st-Person Voxel & Volume Audit (PoC 3)   [████████████████████] 100% (Verified)
  Phase 2: City, Demography, Zoning & NPCs (PoC 4/8) [████████████████████] 100% (Completed)
  Phase 3: 200×200 World, Industry, Fluids, HUD v3.57[███████████████████░]  98% (Final Polish)
  Phase 4: Dual Combat Camera & Squad RTS (PoC 7)    [████░░░░░░░░░░░░░░░░]  Planned
  Phase 5: Advanced Logistics & Bridges (PoC 8–10)   [██░░░░░░░░░░░░░░░░░░]  Planned
  Phase 6: Warfare, Sieges, AI & Avatar Succession   [██░░░░░░░░░░░░░░░░░░]  Planned
  Phase 7: LAN Multiplayer & Portable Urban Cores    [█░░░░░░░░░░░░░░░░░░░]  Future Horizon
```

---

## 2. Completed Milestones (Phases 0 to 3 — GDD v3.57)

### Phase 0 & Phase 1: Voxel Substrate, First-Person Avatar & Volumetric Validation
- [x] Finite procedural **200×200 voxel world** (`GeneradorMundo.gd`) with max height `y = 130`, **24 subsurface layers** down to unmineable `bedrock`, 2 mountain peaks, rivers with water currents and waterfalls, lakes, and seas.
- [x] First-person pioneer avatar (`Player.gd`) with progressive crack block mining, non-destructive fruit foraging (`60 u` in `2.0s`), swimming with `10.0s` oxygen bar, and miner headlamp (<kbd>L</kbd>).
- [x] Flood-fill airtight room recognition (`ValidadorEdificios.gd`), building declaration (<kbd>B</kbd>), and non-destructive remodeling (<kbd>Shift</kbd> + <kbd>B</kbd>).

### Phase 2: Urban Foundation, Overhead Camera & Demographics
- [x] Tactical overhead camera (`CamaraCenital.gd`) with smooth `0.6s` animated camera flight (<kbd>C</kbd>), `90°` template rotation (`Ctrl + Wheel`), and up to 5 persistent blueprints.
- [x] Tripartite **Zone A** and **Zone B** district painting inside the Urban Core's `30-cell` Area of Influence (`Zonificacion.gd`).
- [x] Urban Levels `1–3` (`2×2`, `4×4`, and `8×4` floors/beds), `24h` colonizability buffers, cohort training schools (`escuela_tecnica`, `escuela_especialistas`), and `universidad`.

### Phase 3: Industries, Fluids, Dynamic Morale & HUD Iconography (v3.56 – v3.57)
- [x] **Peripheral Outposts with Levels `I–III` & Physical Depletion:** `maderero`, `mina` (depths 8/16/24), `caza_recoleccion`, `pesca_frutos_mar`, `estacion_bombeo`, and `centro_extraccion` with automatic level regression.
- [x] **Colonist Road-Laying Crews (`ConstructorVias.gd`):** Packed dirt roads (`+35%` speed bonus, A* step cost `3` vs `8`), built by colonist work crews with configurable priorities (**High `▲▲▲`**, **Normal `▲▲`**, **Low `▲`**) and guided road network demolition.
- [x] **All 8 Industrial & Power Facilities:** `aserradero`, `fabrica_bloques`, `carbonera`, `siderurgica`, `refineria_tierras_raras`, `refineria_petrolera` (400/600 split cap), `productor_combustible`, and `central_termoelectrica` (`20 E/h`, `500 Coal` strategic reserve).
- [x] **Raw Material Reserve Quotas (`[0, 50, 100, 250, 500] u`):** Configurable raw wood and stone reserve thresholds in `VentanaAlmacen.gd` and factories.
- [x] **Elevated Modular Fluid Pipelines (`Y + 6`):** Aqueducts and industrial pipelines with `Y + 5` ground clearance, viscosity spill physics, and `PanelCanalizacion.gd` flow diagnostics.
- [x] **Dynamic Morale & Stepped Monthly Migration (`Ciudad.gd`):** Continuous productivity curve (`0.5 × 2^(Morale / 50)`), daily morale rate applied hourly (`/ 24.0`), and the 9-tier stepped monthly migration table (`-5` to `+5 colonists/month`).
- [x] **Vector HUD Iconography & Live 3D Thumbnails (v3.57):** **90+ crisp pixel-art SVG icons** (`IconosHUD.gd`), live 3D thumbnails (`MiniaturaRenderer.gd`), `104×76 px` build buttons (`BarraModos.gd`), and `kW / MW` tri-color power indicator (`BarraSuperior.gd`).

---

## 3. Remaining Tasks for Phase 3 Sign-Off

1. **Long-Session Live Balance Pass:** Extended playtesting of Urban Level 1 → 2 → 3 progression pacing under the stepped monthly migration table.
2. **Universal Era 3 Civil Power Consumption:** Extending electrical grid demand to advanced civil buildings upon reaching Era 3.

---

## 4. Upcoming Phases (Phases 4 to 7)

| Phase / Version | Milestone Focus | Key Systems |
| :--- | :--- | :--- |
| **Phase 4 (PoC 7)** | **Dual Camera & Squad RTS Selection** | Box-selection and tactical squad orders (`militar`) from overhead view seamlessly paired with 1st-person combat. |
| **Phase 5 (PoC 8–10)** | **Advanced Logistics & Bridge Engineering** | High-capacity land wagons, modular bridges over rivers/canyons, and freight railway networks. |
| **Phase 6** | **Warfare, Sieges, AI & Avatar Succession** | Procedural AI bandit camps, outpost raids, defensive walls/turrets, and avatar succession upon death (`K` test hook active). |
| **Phase 7** | **LAN Multiplayer & Portable Urban Cores** | Exporting the validated Urban Core and blueprints into competitive and cooperative LAN/dedicated multiplayer worlds. |

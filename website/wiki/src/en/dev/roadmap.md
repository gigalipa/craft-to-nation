---
title: "Development Roadmap & Milestone Progress (GDD v3.59)"
description: "Current development status and technical roadmap: Phases 0 through 7, active Phase 3 industrial milestones, and upcoming dual camera tactical warfare."
---

# Development Roadmap & Milestone Progress (GDD v3.59)

![Tactical aerial view of city defense and expansion](/assets/comparison-aerial.webp)

This roadmap tracks the past, current, and upcoming development milestones for **Craft to Nation** across the 7 official phases defined in **Section 11 of GDD v3.59** and the live QA verification protocol (`docs/Live_Verifications.md`), backed by **28 automated test scenes running 100% in green**.

---

## 1. Seven-Phase Project Overview

```
  Phase 0: Pure Simulation Logic (PoC 1 & 2)         [████████████████████] 100% (Completed)
  Phase 1: 1st-Person Voxel & Volume Audit (PoC 3)   [████████████████████] 100% (Verified)
  Phase 2: City, Demography, Zoning & NPCs (PoC 4/8) [████████████████████] 100% (Completed)
  Phase 3: 200×200 World, Industry, Fluids, HUD v3.58[███████████████████░]  98% (Final Polish)
  Phase 4: Dual Combat Camera & Squad RTS (PoC 7)    [████░░░░░░░░░░░░░░░░]  Planned
  Phase 5: Advanced Logistics & Bridges (PoC 8–10)   [██░░░░░░░░░░░░░░░░░░]  Planned
  Phase 6: Warfare, Sieges, AI & Avatar Succession   [██░░░░░░░░░░░░░░░░░░]  Planned
  Phase 7: LAN Multiplayer & Portable Urban Cores    [█░░░░░░░░░░░░░░░░░░░]  Future Horizon
```

---

## 2. Completed Milestones (Phases 0 to 3 — GDD v3.59)

### Phase 0 & Phase 1: Voxel Substrate, First-Person Avatar & Volumetric Validation
- [x] Finite procedural **200×200 voxel world** (`GeneradorMundo.gd`) with max height `y = 130`, **24 subsurface layers** down to unmineable `bedrock`, 2 mountain peaks, rivers with water currents and waterfalls, lakes, and seas.
- [x] First-person pioneer avatar (`Player.gd`) with progress-bar mining and contextual tool icons (`herr_pala`, `herr_pico`, `herr_hacha`), non-destructive fruit harvesting by holding <kbd>E</kbd> (`60 u` in `2.0s`), deep-liquid swimming (`>= 2` blocks) with `10.0s` oxygen bar, solid-block liquid draining (<kbd>Right Click</kbd>), on-foot deconstruction mode (<kbd>G</kbd>), and omnidirectional lantern (<kbd>L</kbd>) with **Thermal** (`Fuel 10h`, `Coal 6h`, `Wood 5h`) and **Electric** (`72h` battery with `+7.2h/tick` recharge) modes.
- [x] Flood-fill airtight room recognition (`ValidadorEdificios.gd`), 3D doors with brass handle and hinges, building declaration (<kbd>B</kbd>), and non-destructive remodeling (<kbd>Shift</kbd> + <kbd>B</kbd>).

### Phase 2: Urban Foundation, Overhead Camera & Demographics
- [x] Tactical overhead camera (`CamaraCenital.gd`) with smooth `0.6s` animated transition (<kbd>C</kbd>), hierarchical numeric menu (`1` Build, `2` Zone, `3` Demolish) with <kbd>Z</kbd> / <kbd>X</kbd> submenu navigation and pagination, `Ctrl + Scroll` rotation, and up to 5 residential blueprint slots.
- [x] Complete residential lifecycle: 1st declared building founds the **Urban Core**, 1st Habitable Residence spawns with `Colonizable: SÍ`, 2nd Residence onward spawns as a `24h` protected buffer (`Colonizable: NO`), wall-to-wall row houses, and Urban Core relocation (`5h`).
- [x] Strict academic unlock chain on the Residential Zone (`1 -> 4 -> 1..3`): `Technical School` (`24h` → 3 Technicians) → `Specialist School` (`48h` → 2 Specialists) → interactive `University` with manual start, pause, and 100%-refund cancellation.

### Phase 3: Industries, Fluids, Dynamic Morale, HUD Iconography, IDU, Glassworks & Transport (v3.56 – v3.59)
- [x] **Peripheral Outposts (`1 -> 2 -> 1..6`):** Hunting, Lumber, Mine (depths 8/16/24), Fishing, Pumping Station (`>= 2` water depth), and Extraction Center (physical iron drill column) with Roman badges `I–III`, minimum worker rank downgrade rule, and 1st-person chest window `VentanaBaul` (<kbd>E</kbd>).
- [x] **Road Network (`1 -> 5 -> 1`), On-Foot Mode (<kbd>V</kbd>) & Guided Demolition (<kbd>3</kbd>):** Progressive colonist road laying (`ViaObraOverlay`), on-foot `2×2` road build/demolish mode (<kbd>V</kbd>), guided orange Dijkstra demolition around 90° corners (<kbd>3</kbd>), and the 5-tier global construction priority dispatch hierarchy.
- [x] **Industrial & Power Facilities (`1 -> 3 -> 1..10`):** Steelworks, Rare Earths, Sawmill, Block Factory, **Glassworks (`Vidriera`, `1-3-5`, `5×6` adobe: `1 Earth + 1 Coal → 3 Glass`)**, Charcoal Kiln (`1-3-6`), Oil Refinery (`1-3-7`, `400/600` split), Fuel Producer (`1-3-8`), Thermal Power Plant (`1-3-9`, `[Carbón]`/`[Combustible]`/`[Crudo]` selector), Transport Workshop, and Industrial Warehouse (`6` fluid ports at `Y = 4`), with percentage-based **`Reserva central:` (`0% / 10% / 20% / 30% / 40% / 50%`)** via `▲`/`▼` buttons.
- [x] **Elevated Conduits (`1 -> 6 -> 1..2`):** Aqueducts and pipelines at `Y + 4` (pillars every 5 blocks), grade-separated crossings between two conduits at **`Y + 6`** (`1` block of clear air at `Y + 5`), open-end physical spills (`🔴 Derrame`) with `0.20` crude viscosity, and column reconnection.
- [x] **Dynamic Morale & `VentanaEnergia` Camera Teleportation:** Daily rate (`/día`), 3 staggered migration regimes (`<= 20%` exodus, `20–50%` with beds, `> 50%` massive), compact `VentanaMoral` with migration status beneath labor productivity, and smooth camera flight (`Tween`) when clicking any building listed in `VentanaEnergia`.
- [x] **Vector HUD Iconography & Live 3D Thumbnails (v3.57):** **95+ crisp pixel-art SVG icons** (`IconosHUD.gd`, including `vidrio.svg`, `romano_1.svg`–`romano_4.svg`, `btn_subir.svg`, `btn_bajar.svg`), live 3D thumbnails (`MiniaturaRenderer.gd`), and `104×76 px` build buttons with 3-corner overlays.
- [x] **Centralized Settings & Reactive Strings Architecture (v3.58):** Full numerical constant decoupling in `ajustes.gd` enabling runtime tweaking and modular "New Game" presets, reactive multi-language strings in `strings.gd`, and exact stepped migration calibration (9 tiers, 2.5× boost for 30 days, and critical brain drain).
- [x] **Era Progression, IDU (`I`–`IV`), Two-Layer Research, Transport & `1/20` Window Panels (v3.59):** Topbar Era name + icon and right-side Roman numeral IDU badge (`I`–`IV`) with top-right hover tooltip; two-layer decentralized research (Theoretical University + Practical Applications with **Itinerant Researcher**); Transport Workshop with 6 mobile haulage units (`acarreador_pie`, `carreta_mano`, `carro_caballos`, `camion_diesel`, `trolebus_solar`, `dron_carga`, road constraints, and exclusive `vidrio` cabins); `1/20`-thick (`0.05m`) window panels (`TranslucidosRenderer.gd`) in 3 geometric variants (`ventana` straight mid-depth facing the avatar, `ventana_esquina` L-corner, and `ventana_techo` flush against the top face `Y ∈ [0.95, 1.0]` when looking up/down) consuming `1 Glass` first (or `3 Earth`); `VentanaAlmacen` hierarchical dropdowns + `[Expand All]`/`[Collapse All]` button; and `PanelEdificio` with `▲`/`▼` priority buttons, automatic completion transition, and interior water drainage.

---

## 3. Upcoming Phases (Phases 4 to 7)

| Phase / Version | Milestone Focus | Key Systems |
| :--- | :--- | :--- |
| **Phase 4 (PoC 7)** | **Dual Camera & Squad RTS Selection** | Box-selection and tactical squad orders (`militar`) from overhead view seamlessly paired with 1st-person combat. |
| **Phase 5 (PoC 8–10)** | **Advanced Logistics & Bridge Engineering** | High-capacity land wagons, modular bridges over rivers/canyons, and freight railway networks. |
| **Phase 6** | **Warfare, Sieges, AI & Avatar Succession** | Procedural AI bandit camps, outpost raids, defensive walls/turrets, and avatar succession upon death (`K` key or drowning). |
| **Phase 7** | **LAN Multiplayer & Portable Urban Cores** | Exporting the validated Urban Core and blueprints into competitive and cooperative LAN/dedicated multiplayer worlds. |

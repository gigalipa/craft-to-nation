---
title: "Development Roadmap & Milestone Progress (GDD v3.62)"
description: "Current development status and technical roadmap: Phases 0 through 7, active Phase 3 industrial milestones, and upcoming dual camera tactical warfare."
---

# Development Roadmap & Milestone Progress (GDD v3.62)

![Tactical aerial view of city defense and expansion](/assets/comparison-aerial.webp)

This roadmap tracks the past, current, and upcoming development milestones for **Craft to Nation** across the 7 official phases defined in **Section 11 of GDD v3.62** and the live QA verification protocol (`docs/Live_Verifications.md`), backed by **37 automated test scenes running 100% in green**.

---

## 1. Seven-Phase Project Overview

```
  Phase 0: Pure Simulation Logic (PoC 1 & 2)         [████████████████████] 100% (Completed)
  Phase 1: 1st-Person Voxel & Volume Audit (PoC 3)   [████████████████████] 100% (Verified)
  Phase 2: City, Demography, Zoning & NPCs (PoC 4/8) [████████████████████] 100% (Completed)
  Phase 3: 200×200 World, Industry, Fluids, HUD & SFX v3.62 [████████████████████] 100% (Completed)
  Phase 4: Dual Camera, Barracks & Hybrid RTS (PoC 7) [████████████████████] 100% (Completed)
  Phase 5: Advanced Logistics & Bridges (PoC 8–10)   [██░░░░░░░░░░░░░░░░░░]  Next Milestone
  Phase 6: Warfare, Sieges, AI & Avatar Succession   [██░░░░░░░░░░░░░░░░░░]  Planned
  Phase 7: LAN Multiplayer & Portable Urban Cores    [█░░░░░░░░░░░░░░░░░░░]  Future Horizon
```

---

## 2. Completed Milestones (Phases 0 to 3 — GDD v3.62)

### Phase 0 & Phase 1: Voxel Substrate, First-Person Avatar & Volumetric Validation
- [x] Finite procedural **200×200 voxel world** (`GeneradorMundo.gd`) with max height `y = 130`, **24 subsurface layers** down to unmineable `bedrock`, 2 mountain peaks, rivers with water currents and waterfalls, lakes, and seas.
- [x] First-person pioneer avatar (`Player.gd`) with progress-bar mining and contextual tool icons (`herr_pala`, `herr_pico`, `herr_hacha`), non-destructive fruit harvesting by holding <kbd>E</kbd> (`60 u` in `2.0s`), deep-liquid swimming (`>= 2` blocks) with `10.0s` oxygen bar, solid-block liquid draining (<kbd>Right Click</kbd>), on-foot deconstruction mode (<kbd>G</kbd>), and omnidirectional lantern (<kbd>L</kbd>) with **Thermal** (`Fuel 10h`, `Coal 6h`, `Wood 5h`) and **Electric** (`72h` battery with `+7.2h/tick` recharge) modes.
- [x] Flood-fill airtight room recognition (`BlueprintValidator.gd`), 3D doors with brass handle and hinges, building declaration (<kbd>B</kbd>), and non-destructive remodeling (<kbd>Shift</kbd> + <kbd>B</kbd>).

### Phase 2: Urban Foundation, Overhead Camera & Demographics
- [x] Tactical overhead camera (`CamaraCenital.gd`) with smooth `0.6s` animated transition (<kbd>C</kbd>), hierarchical numeric menu (`1` Build, `2` Zone, `3` Demolish) with <kbd>Z</kbd> / <kbd>X</kbd> submenu navigation and pagination, `Ctrl + Scroll` rotation, and up to 5 residential blueprint slots.
- [x] Complete residential lifecycle: 1st declared building founds the **Urban Core**, 1st Habitable Residence spawns with `Colonizable: SÍ`, 2nd Residence onward spawns as a `24h` protected buffer (`Colonizable: NO`), wall-to-wall row houses, and Urban Core relocation (`5h`).
- [x] Strict academic unlock chain on the Residential Zone (`1 -> 4 -> 1..3`): `Technical School` (`24h` → 3 Technicians) → `Specialist School` (`48h` → 2 Specialists) → interactive `University` with manual start, pause, and 100%-refund cancellation.

### Phase 3: Industries, Fluids, Dynamic Morale, HUD Iconography, IDU, Glassworks, Transport & Audio SFX (v3.56 – v3.61)
- [x] **Peripheral Outposts (`1 -> 2 -> 1..6`):** Hunting, Lumber, Mine (depths 8/16/24), Fishing, Pumping Station (`>= 2` water depth), and Extraction Center (physical iron drill column) with Roman badges `I–III`, minimum worker rank downgrade rule, and 1st-person chest window `VentanaBaul` (<kbd>E</kbd>).
- [x] **Road Network (`1 -> 5 -> 1`), On-Foot Mode (<kbd>V</kbd>) & Guided Demolition (<kbd>3</kbd>):** Progressive colonist road laying (`ViaObraOverlay`), on-foot `2×2` road build/demolish mode (<kbd>V</kbd>), guided orange Dijkstra demolition around 90° corners (<kbd>3</kbd>), and the 5-tier global construction priority dispatch hierarchy.
- [x] **Industrial & Power Facilities (`1 -> 3 -> 1..10`):** Steelworks, Rare Earths, Sawmill, Block Factory, **Glassworks (`Vidriera`, `1-3-5`, `5×6` adobe: `1 Earth + 1 Coal → 3 Glass`)**, Charcoal Kiln (`1-3-6`), Oil Refinery (`1-3-7`, `400/600` split), Fuel Producer (`1-3-8`), Thermal Power Plant (`1-3-9`, `[Carbón]`/`[Combustible]`/`[Crudo]` selector), Transport Workshop, and Industrial Warehouse (`6` fluid ports at `Y = 4`), with percentage-based **`Reserva central:` (`0% / 10% / 20% / 30% / 40% / 50%`)** via `▲`/`▼` buttons.
- [x] **Elevated Conduits (`1 -> 6 -> 1..2`):** Aqueducts and pipelines at `Y + 4` (pillars every 5 blocks), grade-separated crossings between two conduits at **`Y + 6`** (`1` block of clear air at `Y + 5`), open-end physical spills (`🔴 Derrame`) with `0.20` crude viscosity, and column reconnection.
- [x] **Dynamic Morale & `VentanaEnergia` Camera Teleportation:** Daily rate (`/día`), 3 staggered migration regimes (`<= 20%` exodus, `20–50%` with beds, `> 50%` massive), compact `VentanaMoral` with migration status beneath labor productivity, and smooth camera flight (`Tween`) when clicking any building listed in `VentanaEnergia`.
- [x] **Vector HUD Iconography & Live 3D Thumbnails (v3.57):** **95+ crisp pixel-art SVG icons** (`IconosHUD.gd`, including `vidrio.svg`, `romano_1.svg`–`romano_4.svg`, `btn_subir.svg`, `btn_bajar.svg`), live 3D thumbnails (`MiniaturaRenderer.gd`), and `104×76 px` build buttons with 3-corner overlays.
- [x] **Centralized Settings & Reactive Strings Architecture (v3.58):** Full numerical constant decoupling in `ajustes.gd` enabling runtime tweaking and modular "New Game" presets, reactive multi-language strings in `strings.gd`, and exact stepped migration calibration (9 tiers, 2.5× boost for 30 days, and critical brain drain).
- [x] **Era Progression, IDU (`I`–`IV`), Two-Layer Research, Transport & `1/20` Window Panels (v3.61):** Topbar Era name + icon and right-side Roman numeral IDU badge (`I`–`IV`) with top-right hover tooltip; two-layer decentralized research (Theoretical University + Practical Applications with **Itinerant Researcher**); Transport Workshop with 6 mobile haulage units (`acarreador_pie`, `carreta_mano`, `carro_caballos`, `camion_diesel`, `trolebus_solar`, `dron_carga`, road constraints, and exclusive `vidrio` cabins); `1/20`-thick (`0.05m`) window panels (`TranslucidosRenderer.gd`) in 3 geometric variants (`ventana` straight mid-depth facing the avatar, `ventana_esquina` L-corner, and `ventana_techo` flush against the top face `Y ∈ [0.95, 1.0]` when looking up/down) consuming `1 Glass` first (or `3 Earth`); `VentanaAlmacen` hierarchical dropdowns + `[Expand All]`/`[Collapse All]` button; and `PanelEdificio` with `▲`/`▼` priority buttons, automatic completion transition, and interior water drainage.
- [x] **1st-Person Tool State Reset on Camera Toggle (2026-10-28):** Unconditional deactivation of 1st-person tools (`Player.salir_de_todas_las_herramientas()`) when transitioning to the overhead camera (`Main._alternar_camara_cenital()`), resetting `modo_deconstruccion`, `modo_vias` and transient placement/mining states. All 28 automated Godot test suites remain at 100% green.
- [x] **Community Infrastructure, CI/CD & Modern Remotion Captions (2026-10-31):** Community Code of Conduct adoption (`CODE_OF_CONDUCT.md`), GitHub Actions CI workflows (`.github/workflows/ci.yml` verifying Python syntax, TypeScript strict typing, and security scanning), official issue/PR templates, and Dependabot integration; alongside high-contrast caption styling in Remotion (`VerticalShort.tsx`, pure white 58px bold over obsidian pill). All 28 test suites remain 100% green.
- [x] **Comprehensive QA Issue Resolution & Simulation Polish (2026-11-03):** 3D block orientations in blueprints (`BlueprintValidator.gd`, `VoxelWorld.gd`) for roof windows and oriented blocks, accelerated migration tiers for outstanding morale (≤ 75 → +5.0, ≤ 90 → +7.0, ≤ 100 → +10.0 colonists/month), immediate work crew reassignment on priority change, confirmation countdown for road/building demolitions, and demographic state reconciliation. All 28 test suites remain 100% green.
- [x] **Spatial Audio Engine, 102 SFX Catalog & Windows Standalone Export (2026-11-06 — v3.60):** Master audio autoload `Sonidos.gd` managing circular pools of 16 2D and 16 3D players with inverse-distance spatial falloff (up to 35m) and pitch modulation (±5%); full catalog of 102 OGG sounds across 8 functional domains (`locomocion`, `herramientas`, `mobiliario`, `colonos`, `industrias`, `fluidos`, `urbanismo`, `ui`); Windows standalone export pipeline (`tools/export_windows.ps1` with official `godot/icon.png`); and automated unit test suite `SonidosTest.tscn`. All 35 test suites remain at 100% green.
- [x] **Main Menu, Atomic Save/Load System, In-Game Pause (F11), Persistent Configuration & Loading Screen (2026-11-07 — v3.61):** Main startup scene `MenuInicio.tscn` with animated slideshow backdrop (`SlideshowFondo.gd`) and looping menu BGM (`The_Architect_s_Decree`), `GestorPartida.gd` atomic saves in `user://saves/` with quicksave slot and save metadata, in-game pause menu `MenuPausa.gd` with <kbd>F11</kbd> runtime tweaks, client preference persistence in `user://configuracion.json` via `Configuracion.gd`, and loading screen `PantallaCarga.gd`. All 35 automated Godot test suites remain at 100% green.
- [x] **Dynamic Multi-Language Localization System (ES/EN) & Reactive Translation (2026-11-09 — v3.61):** Full implementation of English translation catalog `_DATOS_EN` in `strings.gd`, dynamic string resolution with automatic Spanish fallback via `Strings.t(clave, default)`, runtime hot-switching via `Strings.actualizar_idioma("es"|"en")` reactively tied to `Configuracion.establecer_idioma()`, live synchronization of central warehouse resource labels in `Ciudad`, English aliases in `IconosHUD.gd` (`wood`, `food`, `census`), bilingual text updates across `BarraSuperior.gd`, `Hotbar.gd`, `PantallaCarga.gd`, `MenuInicio.gd`, `MenuPausa.gd`, and `PanelConfiguracionAjustes.gd`, and automated test coverage in `ConfiguracionTest.gd`. All 35 automated Godot test suites remain at 100% green.
- [x] **Right-Lane Traffic Transit on Roads by Vehicle Footprint, Cinematic Video Intro, Starting Resource Profiles & 36 Test Suites (2026-11-10 — v3.61):** Geometric right-edge road detection $\vec{r} = (-d_z, d_x)$ via `Vias.es_borde_derecho()` paired with directional left-lane cost penalization in A* (`VIAS_PENALIZACION_CARRIL_IZQUIERDO = 4` in `BuscadorRutas.gd`) ensuring distinct non-colliding lanes based on heading direction and vehicle footprint (`Vector2i` in `TRANSPORTE_CATALOGO_UNIDADES`) with clean detour fallback; cinematic startup splash `VideoIntro.tscn` with animated logo playback, instant key/click skip, and handoff to `MenuInicio.tscn`; categorized starting resource profiles (`supervivencia`, `bajos`, `medios`, `altos`) in `Configuracion.gd` and `ajustes.gd`; and automated test suite expanded to 37 clean scenes with `VideoIntroTest.tscn` running 100% green.


---


### Phase 4: Dual Combat Camera, Military Barracks, Universal RTS Selection & Hybrid Command (v3.62)
- [x] **Military Barracks Building (`9×7×8`, Zone B, key `7`) & 4→4 Cohort:** 2-story building with stone, wood, glass, door, and 4 beds that atomically recruits 16 soldiers (4 per bed) in `Economia.gd`/`Recoleccion.gd` without displacing civilian housing.
- [x] **Barracked Military Housing (`x_cama = 4`):** Segregated military housing calculation in `Ciudad.gd` and `ajustes.gd` preventing civilian evictions.
- [x] **Universal Overhead Camera Selection (`CamaraCenital.gd`):** 2D drag-selection box supporting individual and group selection of soldiers and civilians, with persistent selection across camera switches (<kbd>C</kbd>).
- [x] **Unit Inspection Panel & Tactical Orders (`PanelUnidad.gd` & `Colonos.gd`):** Health, occupation, and stance inspection (`Pasivo`, `Defensivo`, `Agresivo`). Order dispatch (`Moverse`, `Atacar` with <kbd>K</kbd>, `Defender`, `Patrullar`, `Mantener` with <kbd>H</kbd>) via right-click and waypoints via <kbd>Shift</kbd>.
- [x] **Specialized 1st-Person Avatar Modes (`Player.gd`):** Construction Mode (<kbd>T</kbd>), Battle Mode (<kbd>R</kbd> with sword, bow, and crosshair reticle), and Commander Mode (<kbd>F</kbd> with 1–6 tactical order hotbar and <kbd>Shift</kbd> + <kbd>1..9</kbd> squad assignment).
- [x] **Procedural Troop Visuals (`ColonosRenderer.gd`):** Procedural helmets, shields, base selection rings, and tactical waypoints.
- [x] **Persistent Window/Fullscreen Mode (`Configuracion.gd`):** Fullscreen vs windowed (1280×720) toggle saved in `user://configuracion.json`.
- [x] **Automated Test Suite Expanded to 37 Scenes:** New test suite `PlayerCombateComandanteTest.tscn` bringing total coverage to 37 scenes running 100% green.

---

## 3. Upcoming Phases (Phases 5 to 7)

| Phase / Version | Milestone Focus | Key Systems |
| :--- | :--- | :--- |
| **Phase 5 (PoC 8–10)** | **Advanced Logistics & Bridge Engineering** | High-capacity land wagons, modular bridges over rivers/canyons, and freight railway networks. |
| **Phase 6** | **Warfare, Sieges, AI & Avatar Succession** | Procedural AI bandit camps, outpost raids, defensive walls/turrets, and avatar succession upon death (`K` key or drowning). |
| **Phase 7** | **LAN Multiplayer & Portable Urban Cores** | Exporting the validated Urban Core and blueprints into competitive and cooperative LAN/dedicated multiplayer worlds. |

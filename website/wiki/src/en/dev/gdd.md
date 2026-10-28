---
title: "Game Design Document (GDD v3.59)"
description: "Technical Game Design Document (GDD v3.59) for Craft to Nation: hybrid voxel survival, organic city planning, hourly simulation tick, centralized settings, Glassworks, IDU I-IV, and finite world economics."
---

# Game Design Document (GDD v3.59)

**Slogan:** *From first block to living nation.*  
**Campaign Motto:** *Survive. Craft. Automate. Lead.*  
**Genre:** Hybrid City Builder, First-Person Survival, Real-Time Strategy (RTS), Factory Management & Logistics.  
**Key Inspirations:** *SimCity*, *Age of Empires*, *Minecraft*, *Mindustry*.

![Evolution across technological eras in Craft to Nation](/assets/concept-era-evolution.webp)

---

## 1. Executive Summary & Technological Era Framework

**Craft to Nation** bridges the visceral immersion of first-person voxel survival sandboxes with the macroscopic vision of urban city builders and real-time strategy games inside a finite, procedurally generated **200×200 voxel world**.

### The Five Technological Eras & Ideological Branching
1. **Era 1 — Prehistoric (Genesis):** Manual foraging, timber felling, compacted earth, adobe, and raw wood shelters.
2. **Era 2 — Ancient Age (Urban Foundation):** Cut stone masonry, aqueducts, packed dirt roads, sawmills, and charcoal kilns.
3. **Era 3 — Industrial Revolution & Steampunk:** Steel metallurgy, iron framing, deep oil drilling, pressurized fluid pipelines, and thermoelectric power grids (`kW / MW`).
4. **Eras 4 & 5 — Ideological Tech Branching (Future Horizon):**
   - **Dieselpunk Branch:** Heavy hydrocarbon supremacy, mechanized siege armor, and massive steel fortifications.
   - **Cyberpunk Branch:** Intensive rare-earth refining, high-density vertical arcologies, and automated cybernetic grids.
   - **Solarpunk Branch:** Ecological synthesis, high-efficiency clean power, and symbiotic urban-biome architecture.

---

## 2. The Five Core Design Pillars

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

1. **Perspective Duality (Micro vs. Macro):** Switch at any time (key <kbd>C</kbd>, `0.6s` animated camera flight) between first-person manual action and the overhead tactical camera.
2. **Modular Blueprints & Automated Construction:** Capture custom-built houses and warehouses (<kbd>B</kbd> to declare, <kbd>Shift</kbd> + <kbd>B</kbd> for non-destructive remodeling) as up to 5 persistent blueprints erected automatically by NPC work crews.
3. **Strategic Zoning & Tripartite Logistics:** Strict separation between **Zone A (Civic/Academic)**, **Zone B (Industrial/Storage/Power)**, and the **Periphery (Extraction/Pumping)** connected by packed dirt roads and elevated **`Y + 4`** fluid pipelines (rising to **`Y + 6`** for conduit-over-conduit crossings).
4. **Organic Economy & Demographics:** Every citizen consumes food according to their profession (`1.0` to `5.0 food/h`), occupies real beds (`x_cama`), advances through cohort schools, and responds to dynamic civic morale (`0` to `100`).
5. **Portable Sovereignty in Competitive Multiplayer:** Export your validated Urban Core and blueprint catalog into procedural multiplayer worlds.

![Planetary network and portable urban sovereignty](/assets/concept-planet-network.webp)

---

## 3. Key Innovations Consolidated in GDD v3.57 – v3.59

- **Vector HUD Iconography (`IconosHUD.gd`) & Live 3D Thumbnails (`MiniaturaRenderer.gd`):** Centralized catalog of **95+ crisp pixel-art SVG icons** (`shape-rendering="crispEdges"`, including `vidrio.svg`, `romano_1.svg`–`romano_4.svg`, `btn_subir.svg`, and `btn_bajar.svg`), enlarged `104×76 px` build buttons with 3-corner overlays (input stack top-left, electric bolt top-center, output badge top-right), and real-time 3D thumbnails.
- **Electrical Grid in kW / MW (`BarraSuperior.gd`, `VentanaEnergia.gd`):** Interactive tri-color lightning bolt indicator (gold = surplus, gray = zero demand, red = deficit) with a per-building power breakdown window.
- **Daily Morale Rate & Stepped Monthly Migration (`Ciudad.gd`):** Daily morale rate applied in hourly fractions (`tasa_cambio_moral / 24.0`), `VentanaMoral` with migration status positioned directly below labor productivity, and a **9-tier stepped monthly migration table** (`-5` to `+5 colonists/month`), restricting immigration to open beds when `Morale <= 50` and overflowing into `sin_techo` when `Morale > 50`.
- **Centralized Runtime Settings & Reactive Strings (`ajustes.gd` & `strings.gd`):** Full decoupling of balance parameters, economic values, demography, and construction costs in `ajustes.gd` enabling runtime hot-reloading and modular "New Game" presets. Synchronized with `strings.gd` for native multi-language catalogs (`Ajustes.idioma`) and static reactive getters that evaluate active values on the fly without reloading scripts.
- **Era Progression, IDU (`I`–`IV`) & Two-Layer Decentralized Tech Tree (v3.59):** Topbar Era name + icon indicator and right-side Roman numeral **IDU** badge (`I`–`IV`) with a top-right hover tooltip window breaking down Demographic (`D`), Scientific (`C`), and Material Sophistication (`S`) pillars. Two-layer research splits **Theoretical Science** (University) from **Practical Applications** initiated at target buildings via a physical **Itinerant Researcher (`Investigador Itinerante`)**.
- **Glassworks Refinery (`Vidriera`), Glass (`Vidrio`), Transport Workshop & `1/20` Window Panels (v3.59):** New `5×6` adobe **Glassworks (`1-3-5`)** refining `1 Earth + 1 Coal → 3 Glass`; **Transport Workshop** assembling 6 haulage unit types (`acarreador_pie`, `carreta_mano`, `carro_caballos`, `camion_diesel`, `trolebus_solar`, `dron_carga`, with road requirements and exclusive `vidrio` windshields); `1/20`-thick (`0.05m`) window panels (`TranslucidosRenderer.gd`) in 3 geometric variants (`ventana` straight mid-depth facing the avatar, `ventana_esquina` L-corner, and `ventana_techo` flush against the top face `Y ∈ [0.95, 1.0]` when looking up/down) consuming `1 Glass` first (or `3 Earth`); `VentanaAlmacen` with A–Z raw material dropdowns (`▶`/`▼`) for refined goods and 6 food categories plus an `[Expand All]`/`[Collapse All]` button; percentage-based `Reserva central:` (`0%–50%`); and `PanelEdificio` with `▲`/`▼` priority buttons, automatic panel transition at 100%, and interior water drainage.
- **Automated Verification Suite:** **28 independent test scenes** running **100% in green**.

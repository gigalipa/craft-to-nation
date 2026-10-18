# Colonist Management & Demographics

Colonists are the heartbeat of **Craft to Nation**. Unlike generic city builder workers, your settlers possess physical metabolism, vocational ranks, housing requirements, and a dynamic psychological morale system that directly modulates economic output and monthly migration.

---

## 1. Sustenance Needs & Metabolic Consumption

Every colonist consumes sustenance each simulation tick. In Godot 4.6, the simulation advances in discrete hourly ticks (`SEGUNDOS_POR_TICK = 2.0s` real time = 1 in-game hour). At the macro level, a standard survival cycle is defined as 60 seconds (30 simulation hours).

### Consumption by Population Tier (`Ciudad.TIPOS_POBLACION`):

| Population Tier | Food (units/h) | Fuel (units/h) | Energy (units/h) | Capacity (`x_cama`) | Primary Responsibilities |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Citizen (`ciudadano`)** | 2.0 | 0.0 | 0.0 | 5 / bed | Base gatherer and civic hauler |
| **Unemployed (`desempleado`)** | 3.0 | 0.0 | 0.0 | 4 / bed | Reserve labor pool, construction worksites, hauling |
| **Worker (`obrero`)** | 5.0 | 0.0 | 0.0 | 4 / bed | Heavy mining, logging, hunting, fishing, and construction |
| **Technician (`tecnico`)** | 3.0 | 0.0 | 0.0 | 3 / bed | Type-2 refineries, pumping stations, Level II outposts |
| **Specialist (`especialista`)**| 2.0 | 0.0 | 1.0 | 2 / bed | Type-3 refineries, thermoelectric plants, Level III outposts |
| **Researcher (`investigador`)**| 1.0 | 0.0 | 2.0 | 1 / bed | University science (`1.0 researcher_hour/h`), tech tree unlocks |
| **Military (`militar`)** | 4.0 | 2.0 | 0.0 | 3 / bed | Garrison patrol, combat defense, expeditionary sieges |

> [!NOTE]
> Physical workers consume more calories (`5.0 food/h`) due to heavy manual labor, whereas intellectual researchers consume fewer calories (`1.0 food/h`) but require electrified quarters (`2.0 energy/h`).

---

## 2. Interactive Colony Production & Consumption Calculator

Estimate your colony's hourly and cyclic food and water requirements based on your current population:

<ClientOnly>
  <ProductionCalculator />
</ClientOnly>

---

## 3. Dynamic Morale System (GDD v3.57)

Colony productivity and migration are driven by the settlement's **Dynamic Morale** score (`0.0` to `100.0`, accessible from the top bar or by pressing <kbd>M</kbd> to open `VentanaMoral.gd`):

```
    Morale Score       Productivity Multiplier        Colony Psychological State
   ───────────────────────────────────────────────────────────────────────────────
       100.0                     2.0×               🙂 Euphoric / Peak Productivity
        75.0                     1.41×              🙂 Pioneer Optimism (Starter Baseline)
        50.0                     1.0×               😐 Neutral Equilibrium
        25.0                     0.71×              🙁 Depressed / Slow Operations
         0.0                     0.5×               😡 Mutinous / Severe Brain Drain
```

### The Productivity Curve Formula (`Ciudad.calcular_multiplicador_productividad()`):
```text
Productivity Multiplier (X) = 0.5 × 2^(Morale / 50)
```

### Daily Morale Rate Applied Hourly (`tasa_cambio_moral / 24.0`):
In `Ciudad.gd`, active modifiers sum into a **daily morale change rate** (`ΔM / day`), which is applied in increments of `ΔM / 24.0` every hourly tick (`2.0s` real time):
- **Resource Surplus:** `+0.4 / day` when basic supplies exceed 50% storage capacity.
- **Diet Diversity:** Up to `+0.5 / day` when providing multiple food sources.
- **Supply Shortages:** `-0.6 / day` when food reserves drop below 20%; up to `-1.5 / day` for power grid deficits.
- **Active Famine:** `-3.0 / day` whenever food reserves hit `0`.
- **Homelessness:** `-0.05 / day` per homeless colonist on the streets.
- **Natural Inertia:** Converges toward neutral `50.0` with a `0.02` inertia factor.
- **Danger Memory Buffer:** Rolling `168-hour` (`7 in-game days`) memory buffer tracking casualties and raids.

### Stepped Monthly Migration Table (`Ciudad.calcular_tasa_migracion_mensual()`)
One simulation month equals `720 in-game hours` (`30 days × 24h`). The migration accumulator adds or subtracts hourly fractions according to the current morale bracket:

| Morale Bracket | Monthly Rate (`colonists / month`) | Migration Behavior in `Ciudad.gd` |
| :--- | :--- | :--- |
| **`0.0 – 5.0`** | **-5.0 / month** | **Severe Exodus** (hierarchical brain drain) |
| **`5.0 – 10.0`** | **-3.0 / month** | **High Exodus** |
| **`10.0 – 15.0`** | **-2.0 / month** | **Moderate Exodus** |
| **`15.0 – 20.0`** | **-1.0 / month** | **Mild Exodus** |
| **`20.0 – 25.0`** | **+1.0 / month** | **Cautious Immigration** (*only enters if free colonizable beds exist*) |
| **`25.0 – 35.0`** | **+2.0 / month** | **Moderate Immigration** (*only enters if free colonizable beds exist*) |
| **`35.0 – 50.0`** | **+3.0 / month** | **Steady Immigration** (*only enters if free colonizable beds exist; never creates homeless*) |
| **`50.0 – 75.0`** | **+3.0 / month** | **Mass Immigration** (*fills open beds and overflows into `sin_techo` if Urban Core exists*) |
| **`75.0 – 100.0`** | **+5.0 / month** | **Migration Boom** (*fills open beds and overflows into `sin_techo` if Urban Core exists*) |

---

## 4. Starvation, Homelessness & Population Crisis

### Starvation Casualties (`bajas_inanicion`)
If the central food stock hits `0`:
1. The engine calculates starvation casualties: `Casualties = max(1, floor(Total Population × 0.25))`.
2. Up to **25% of the total colony census** can perish per simulation tick (`2.0s`).
3. Casualties occur in strict demographic order:
   ```text
   Military → Worker → Technician → Specialist → Researcher → Unemployed → Citizen
   ```

### Homelessness (`sin_techo`) & Brain Drain
- **72-Hour Homeless Grace Period:** Colonists without beds consume `3.0 food/h`. If residential beds are not provided within **72 in-game hours (3 days)**, homeless settlers emigrate in exile, inflicting a direct **-10 civic morale penalty**.
- **Long-Term Unemployment (`240h`):** Unemployed settlers wait up to **240 in-game hours (10 days)**. If no workplace, school, or construction site is assigned, they leave the colony.
- **Brain Drain Exodus (`Morale <= 20`):** When morale falls to `20.0` or below, the most educated colonists abandon the city first:
  ```text
  Researcher → Specialist → Technician → Military → Worker → Unemployed → Citizen
  ```

---

## 5. Cohort Education & University Research (`Zone A`)

1. **Technical School (`escuela_tecnica`, `5×5` adobe):** Trains a cohort of **4 Workers** (1 shared bed) for **24 in-game hours** and graduates **3 Technicians** (occupying 1 technician bed; the 4th member departs to preserve housing equilibrium).
2. **Specialist School (`escuela_especialistas`, `5×5` stone):** Trains a cohort of **3 Technicians** (1 bed) for **48 in-game hours** and graduates **2 Specialists** (1 bed).
3. **University (`universidad`, `5×5` stone):** Employs up to **3 Researchers** (`1.0 researcher_hour/h` each) to unlock **Applied Metallurgy** (`20 res_h`, `300 Iron`, `200 Wood`) and **Industrial Automation** (`50 res_h`, `800 Iron`, `100 Wood`).

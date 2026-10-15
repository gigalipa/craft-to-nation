# Colonist Management & Demographics

Colonists are the heartbeat of *Craft to Nation*. Unlike generic city builder workers, your settlers possess physical metabolism, vocational ranks, housing requirements, and a dynamic psychological morale system that directly modulates economic output.

---

## 1. Sustenance Needs & Metabolic Consumption

Every colonist consumes sustenance each simulation tick. In Godot 4, the simulation advances in discrete hourly ticks (`SEGUNDOS_POR_TICK = 2.0s` real time = 1 in-game hour). At the macro level, a standard survival cycle is defined as 60 seconds (30 simulation hours).

### Consumption by Population Tier:
Sustenance rates are defined in `Ciudad.TIPOS_POBLACION`:

| Population Tier | Food (units/h) | Fuel (units/h) | Energy (units/h) | Capacity ("x Bed") | Primary Responsibilities |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Citizen (Ciudadano)** | 2.0 | 0.0 | 0.0 | 5 / bed | Domestic tasks, civic morale, reproduction |
| **Unemployed (Desempleado)** | 3.0 | 0.0 | 0.0 | 4 / bed | General reserve labor, blueprints, hauling |
| **Worker (Obrero)** | 5.0 | 0.0 | 0.0 | 4 / bed | Heavy mining, logging, physical construction |
| **Technician (Técnico)** | 3.0 | 0.0 | 0.0 | 3 / bed | Machine operation, sawmills, foundries |
| **Specialist (Especialista)**| 2.0 | 0.0 | 1.0 | 2 / bed | High-precision chemistry, electronics |
| **Researcher (Investigador)**| 1.0 | 0.0 | 2.0 | 1 / bed | University science, technological breakthroughs |
| **Military (Militar)** | 4.0 | 2.0 | 0.0 | 3 / bed | Garrison patrol, combat defense, expeditionary sieges |

> [!NOTE]
> Physical workers consume more calories (5.0 food/h) due to heavy manual labor, whereas intellectual researchers consume fewer calories (1.0 food/h) but require electrified research facilities (2.0 energy/h).

---

## 2. Interactive Colony Production & Consumption Calculator

Estimate your colony's hourly and cyclic food and water requirements based on your current population:

<ClientOnly>
  <ProductionCalculator />
</ClientOnly>

---

## 3. Dynamic Morale System (GDD v3.56)

Colony productivity is not constant—it is scaled continuously by the settlement's **Dynamic Morale** score (ranging from 0.0 to 100.0).

```
   Morale Score       Productivity Multiplier        Colony Psychological State
  ───────────────────────────────────────────────────────────────────────────────
      100.0                     2.0×               🙂 Euphoric / Peak Productivity
       75.0                     1.41×              🙂 Pioneer Optimism (Starter Baseline)
       50.0                     1.0×               😐 Neutral Equilibrium
       25.0                     0.71×              🙁 Depressed / Slow Operations
        0.0                     0.5×               😡 Mutinous / Severe Brain Drain
```

### The Productivity Curve Formula:
$$\text{Productivity Multiplier } (X) = 0.5 \times 2^{\left(\frac{Y}{50}\right)}$$
*Where $Y$ is the current settlement morale.*

### Hourly Morale Modifiers ($\Delta M$):
- **Resource Surplus:** $+0.4\text{ / hour}$ when basic supplies exceed 50% storage capacity.
- **Diet Diversity:** Up to $+0.5\text{ / hour}$ when providing multiple food groups (game meat, berries, fish, algae, bread).
- **Supply Shortages:** $-0.6\text{ / hour}$ for food deficits; up to $-1.5\text{ / hour}$ for continuous energy grid blackouts.
- **Active Famine:** Severe penalty of $-3.0\text{ / hour}$ whenever food reserves reach zero.
- **Homelessness:** $-0.05\text{ / hour}$ per homeless colonist on the streets.
- **Danger Memory Buffer:** Rolling 168-hour (7 in-game days) memory buffer tracking bandit raids and casualties.

---

## 4. Starvation, Homelessness & Population Crisis

When governance falters, the colony suffers cascading demographic penalties:

### Starvation Casualties (`bajas_inanicion`)
If the central food stock is exhausted:
1. The engine calculates starvation casualties: $\text{Casualties} = \max\left(1, \lfloor \text{Total Population} \times 0.25 \rfloor\right)$.
2. Up to **25% of the total colony census** can perish in a single simulation tick.
3. Casualties occur in strict demographic order:
   $$\text{Military} \longrightarrow \text{Worker} \longrightarrow \text{Technician} \longrightarrow \text{Specialist} \longrightarrow \text{Researcher} \longrightarrow \text{Unemployed} \longrightarrow \text{Citizen}$$

### Homelessness & Brain Drain
- **72-Hour Homeless Grace Period:** Colonists without beds enter the homeless state. If new residential beds are not validated within 72 in-game hours, homeless settlers emigrate into exile, inflicting a permanent **-10 civic morale penalty**.
- **Long-term Unemployment:** Unemployed settlers wait up to 10 days (240 game hours). If no workplace or construction site is assigned, they abandon the colony.
- **Brain Drain Exodus (Morale < 20):** If settlement morale falls below 20.0, an intellectual exodus begins. The most educated colonists abandon the city first:
  $$\text{Researchers} \longrightarrow \text{Specialists} \longrightarrow \text{Technicians} \longrightarrow \text{Military} \longrightarrow \text{Workers}$$

---

## 5. Educational Advancement & Vocational Promotion

Settlers can advance through educational institutions placed in **Zone A (Civic & Research District)**:

1. **Laborer to Technician:** Workers and unemployed citizens study at the **Technical School** to become certified technicians capable of operating refineries and mechanical sawmills.
2. **Technician to Specialist:** Technicians attend the **Specialist Academy** to master high-tier metallurgy and electronics assembly.
3. **Specialist to Researcher:** Advanced intellectuals enter the **University** to conduct research projects, unlocking industrial automation and long-distance electrical transmission.

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useData } from 'vitepress'

const { lang } = useData()
const colonistCount = ref(10)
const showAdvanced = ref(false)

const i18n = {
  es: {
    title: 'Calculadora de Supervivencia y Consumo',
    subtitle: 'Basada en las Fichas Consolidadas de Balance (Ciclo de 60s)',
    presets: 'Presets:',
    popLabel: 'Población total de colonos:',
    colonists: 'colonos',
    foodName: 'Consumo de Comida',
    waterName: 'Consumo de Agua',
    perCycle: 'u / ciclo',
    perRealHour: 'u / hora real',
    huntingName: 'Puestos de Caza',
    waterStationName: 'Estaciones de Agua',
    minimum: 'mínimo',
    huntingSub: 'Hasta 7 trabajadores c/u',
    waterStationSub: 'Hasta 3 operarios c/u',
    autonomyLabel: 'Autonomía con reserva inicial',
    autonomyFood: '(5,000 u comida):',
    minutes: 'minutos',
    hours: 'horas',
    warningTitle: 'Riesgo de Inanición:',
    warningBody: 'Si el almacén de comida llega a 0, hasta un 25% de la colonia perecerá por tick (cada 2 segundos), afectando primero a militares, obreros y técnicos.',
    hideTech: '▼ Ocultar ratios técnicos de simulación',
    showTech: '▶ Ver ratios técnicos en motor Godot',
    colRole: 'Rol Demográfico',
    colFood: 'Comida (u/h juego)',
    colFuel: 'Combustible (u/h)',
    colEnergy: 'Energía (u/h)',
    roles: ['Ciudadano', 'Desempleado', 'Obrero', 'Técnico', 'Especialista', 'Investigador', 'Militar'],
    footnote: '* 1 hora de juego equivale a 1 tick de simulación (2.0 segundos reales). 1 ciclo estándar (60s) = 30 horas de juego.'
  },
  en: {
    title: 'Survival & Consumption Calculator',
    subtitle: 'Based on the Consolidated Balance Sheets (60s Cycle)',
    presets: 'Presets:',
    popLabel: 'Total colonist population:',
    colonists: 'colonists',
    foodName: 'Food Consumption',
    waterName: 'Water Consumption',
    perCycle: 'u / cycle',
    perRealHour: 'u / real hour',
    huntingName: 'Hunting Posts',
    waterStationName: 'Water Stations',
    minimum: 'minimum',
    huntingSub: 'Up to 7 workers each',
    waterStationSub: 'Up to 3 operators each',
    autonomyLabel: 'Initial stockpile autonomy',
    autonomyFood: '(5,000 u food):',
    minutes: 'minutes',
    hours: 'hours',
    warningTitle: 'Starvation Risk:',
    warningBody: 'If the food stockpile hits 0, up to 25% of the colony perishes per tick (every 2 seconds), striking military, workers, and technicians first.',
    hideTech: '▼ Hide technical simulation ratios',
    showTech: '▶ View technical ratios in Godot engine',
    colRole: 'Demographic Role',
    colFood: 'Food (u/game hr)',
    colFuel: 'Fuel (u/hr)',
    colEnergy: 'Energy (u/hr)',
    roles: ['Citizen', 'Unemployed', 'Worker', 'Technician', 'Specialist', 'Researcher', 'Military'],
    footnote: '* 1 in-game hour equals 1 simulation tick (2.0 real seconds). 1 standard cycle (60s) = 30 in-game hours.'
  },
  fr: {
    title: 'Calculateur de Survie et Consommation',
    subtitle: 'Basé sur les Fiches d’Équilibrage Consolidées (Cycle de 60s)',
    presets: 'Préréglages :',
    popLabel: 'Population totale de colons :',
    colonists: 'colons',
    foodName: 'Consommation de Nourriture',
    waterName: 'Consommation d’Eau',
    perCycle: 'u / cycle',
    perRealHour: 'u / heure réelle',
    huntingName: 'Postes de Chasse',
    waterStationName: 'Stations d’Eau',
    minimum: 'minimum',
    huntingSub: 'Jusqu’à 7 travailleurs chacun',
    waterStationSub: 'Jusqu’à 3 opérateurs chacun',
    autonomyLabel: 'Autonomie avec réserve initiale',
    autonomyFood: '(5 000 u nourriture) :',
    minutes: 'minutes',
    hours: 'heures',
    warningTitle: 'Risque de Famine :',
    warningBody: 'Si la réserve de nourriture atteint 0, jusqu’à 25% de la colonie périt par tick (toutes les 2 secondes), touchant d’abord les militaires, ouvriers et techniciens.',
    hideTech: '▼ Masquer les ratios techniques de simulation',
    showTech: '▶ Voir les ratios techniques du moteur Godot',
    colRole: 'Rôle Démographique',
    colFood: 'Nourriture (u/h jeu)',
    colFuel: 'Carburant (u/h)',
    colEnergy: 'Énergie (u/h)',
    roles: ['Citoyen', 'Sans emploi', 'Ouvrier', 'Technicien', 'Spécialiste', 'Chercheur', 'Militaire'],
    footnote: '* 1 heure de jeu équivaut à 1 tick de simulation (2,0 secondes réelles). 1 cycle standard (60s) = 30 heures de jeu.'
  }
}

const t = computed(() => {
  const l = (lang.value || 'es').toLowerCase()
  if (l.startsWith('en')) return i18n.en
  if (l.startsWith('fr')) return i18n.fr
  return i18n.es
})

// Parámetros auditados (docs/Fichas_Consumo_Produccion_Consolidada.md)
const CICLO_SEGUNDOS = 60
const COMIDA_POR_COLONO_CICLO = 1
const AGUA_POR_COLONO_CICLO = 1
const STOCK_INICIAL_COMIDA = 5000
const CAPACIDAD_PUESTO_CAZA = 15 // Colonos abastecidos por puesto de caza con dotación completa
const CAPACIDAD_ESTACION_AGUA = 25 // Colonos abastecidos por estación de bombeo activa

// Cálculos macro por ciclo estándar (60s)
const consumoComidaCiclo = computed(() => colonistCount.value * COMIDA_POR_COLONO_CICLO)
const consumoAguaCiclo = computed(() => colonistCount.value * AGUA_POR_COLONO_CICLO)

const consumoComidaMinuto = computed(() => consumoComidaCiclo.value)
const consumoAguaMinuto = computed(() => consumoAguaCiclo.value)

const consumoComidaHoraReal = computed(() => consumoComidaCiclo.value * 60)
const consumoAguaHoraReal = computed(() => consumoAguaCiclo.value * 60)

// Puestos recomendados
const puestosCazaRecomendados = computed(() => Math.max(1, Math.ceil(colonistCount.value / CAPACIDAD_PUESTO_CAZA)))
const estacionesAguaRecomendadas = computed(() => Math.max(1, Math.ceil(colonistCount.value / CAPACIDAD_ESTACION_AGUA)))

// Autonomía con stock inicial
const minutosAutonomia = computed(() => {
  if (colonistCount.value <= 0) return 0
  return Math.round(STOCK_INICIAL_COMIDA / colonistCount.value)
})

const horasAutonomia = computed(() => (minutosAutonomia.value / 60).toFixed(1))

const setPreset = (val: number) => {
  colonistCount.value = val
}
</script>

<template>
  <div class="calc-container">
    <div class="calc-header">
      <div class="calc-title">
        <span class="icon">⚖️</span>
        <div>
          <h3>{{ t.title }}</h3>
          <p class="subtitle">{{ t.subtitle }}</p>
        </div>
      </div>
      <div class="calc-presets">
        <span class="preset-label">{{ t.presets }}</span>
        <button type="button" @click="setPreset(5)" :class="{ active: colonistCount === 5 }">5</button>
        <button type="button" @click="setPreset(10)" :class="{ active: colonistCount === 10 }">10</button>
        <button type="button" @click="setPreset(25)" :class="{ active: colonistCount === 25 }">25</button>
        <button type="button" @click="setPreset(50)" :class="{ active: colonistCount === 50 }">50</button>
        <button type="button" @click="setPreset(100)" :class="{ active: colonistCount === 100 }">100</button>
      </div>
    </div>

    <!-- Control de Colonos -->
    <div class="calc-control">
      <div class="control-label">
        <label for="colonist-input">{{ t.popLabel }}</label>
        <span class="count-badge">{{ colonistCount }} {{ t.colonists }}</span>
      </div>
      <div class="input-row">
        <input
          id="colonist-slider"
          type="range"
          min="1"
          max="200"
          v-model.number="colonistCount"
          class="range-slider"
        />
        <input
          id="colonist-input"
          type="number"
          min="1"
          max="1000"
          v-model.number="colonistCount"
          class="number-input"
        />
      </div>
    </div>

    <!-- Rejilla de Métricas Principales -->
    <div class="metrics-grid">
      <div class="metric-card food">
        <div class="card-icon">🍖</div>
        <div class="card-content">
          <div class="metric-name">{{ t.foodName }}</div>
          <div class="metric-value">{{ consumoComidaCiclo }} <span class="unit">{{ t.perCycle }}</span></div>
          <div class="metric-sub">{{ consumoComidaHoraReal }} {{ t.perRealHour }}</div>
        </div>
      </div>

      <div class="metric-card water">
        <div class="card-icon">💧</div>
        <div class="card-content">
          <div class="metric-name">{{ t.waterName }}</div>
          <div class="metric-value">{{ consumoAguaCiclo }} <span class="unit">{{ t.perCycle }}</span></div>
          <div class="metric-sub">{{ consumoAguaHoraReal }} {{ t.perRealHour }}</div>
        </div>
      </div>

      <div class="metric-card gathering">
        <div class="card-icon">🏹</div>
        <div class="card-content">
          <div class="metric-name">{{ t.huntingName }}</div>
          <div class="metric-value">{{ puestosCazaRecomendados }} <span class="unit">{{ t.minimum }}</span></div>
          <div class="metric-sub">{{ t.huntingSub }}</div>
        </div>
      </div>

      <div class="metric-card pumps">
        <div class="card-icon">🚰</div>
        <div class="card-content">
          <div class="metric-name">{{ t.waterStationName }}</div>
          <div class="metric-value">{{ estacionesAguaRecomendadas }} <span class="unit">{{ t.minimum }}</span></div>
          <div class="metric-sub">{{ t.waterStationSub }}</div>
        </div>
      </div>
    </div>

    <!-- Autonomía Inicial -->
    <div class="stock-info">
      <div class="info-row">
        <span>⏱️ <strong>{{ t.autonomyLabel }}</strong> {{ t.autonomyFood }}</span>
        <span class="highlight">~{{ minutosAutonomia }} {{ t.minutes }} (~{{ horasAutonomia }} {{ t.hours }})</span>
      </div>
      <p class="warning-text">
        ⚠️ <strong>{{ t.warningTitle }}</strong> {{ t.warningBody }}
      </p>
    </div>

    <!-- Toggle Desglose Técnico -->
    <div class="advanced-section">
      <button type="button" class="toggle-btn" @click="showAdvanced = !showAdvanced">
        {{ showAdvanced ? t.hideTech : t.showTech }}
      </button>

      <div v-if="showAdvanced" class="advanced-content">
        <table class="tech-table">
          <thead>
            <tr>
              <th>{{ t.colRole }}</th>
              <th>{{ t.colFood }}</th>
              <th>{{ t.colFuel }}</th>
              <th>{{ t.colEnergy }}</th>
            </tr>
          </thead>
          <tbody>
            <tr><td>{{ t.roles[0] }}</td><td>2</td><td>0</td><td>0</td></tr>
            <tr><td>{{ t.roles[1] }}</td><td>3</td><td>0</td><td>0</td></tr>
            <tr><td>{{ t.roles[2] }}</td><td>5</td><td>0</td><td>0</td></tr>
            <tr><td>{{ t.roles[3] }}</td><td>3</td><td>0</td><td>0</td></tr>
            <tr><td>{{ t.roles[4] }}</td><td>2</td><td>0</td><td>1</td></tr>
            <tr><td>{{ t.roles[5] }}</td><td>1</td><td>0</td><td>2</td></tr>
            <tr><td>{{ t.roles[6] }}</td><td>4</td><td>2</td><td>0</td></tr>
          </tbody>
        </table>
        <small class="footnote">{{ t.footnote }}</small>
      </div>
    </div>
  </div>
</template>

<style scoped>
.calc-container {
  background: var(--vp-c-bg-soft, #f8fafc);
  border: 1px solid var(--vp-c-divider, #e2e8f0);
  border-radius: 12px;
  padding: 1.5rem;
  margin: 1.5rem 0;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.08);
}

.calc-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  flex-wrap: wrap;
  gap: 1rem;
  margin-bottom: 1.25rem;
}

.calc-title {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.calc-title .icon {
  font-size: 2rem;
}

.calc-title h3 {
  margin: 0;
  font-size: 1.15rem;
  font-weight: 700;
  color: var(--vp-c-text-1, #0f172a);
}

.subtitle {
  margin: 0;
  font-size: 0.82rem;
  color: var(--vp-c-text-2, #475569);
}

.calc-presets {
  display: flex;
  align-items: center;
  gap: 0.4rem;
}

.preset-label {
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--vp-c-text-2, #475569);
}

.calc-presets button {
  background: var(--vp-c-bg-elv, #ffffff);
  border: 1px solid var(--vp-c-border, #cbd5e1);
  color: var(--vp-c-text-1, #0f172a);
  padding: 0.2rem 0.55rem;
  border-radius: 6px;
  font-size: 0.8rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.15s ease;
}

.calc-presets button:hover,
.calc-presets button.active {
  background: var(--vp-button-brand-bg, #3e63dd);
  color: var(--vp-button-brand-text, #ffffff);
  border-color: var(--vp-button-brand-bg, #3e63dd);
}

.calc-control {
  background: var(--vp-c-bg, #ffffff);
  border: 1px solid var(--vp-c-divider, #e2e8f0);
  border-radius: 8px;
  padding: 1rem;
  margin-bottom: 1.25rem;
}

.control-label {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-weight: 600;
  font-size: 0.95rem;
  color: var(--vp-c-text-1, #0f172a);
  margin-bottom: 0.6rem;
}

.count-badge {
  background: var(--vp-c-brand-soft, rgba(100, 108, 255, 0.16));
  color: var(--vp-c-brand-1, #3451b2);
  border: 1px solid var(--vp-c-brand-1, #3451b2);
  padding: 0.15rem 0.65rem;
  border-radius: 9999px;
  font-size: 0.85rem;
  font-weight: 700;
}

.input-row {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.range-slider {
  flex: 1;
  cursor: pointer;
  accent-color: var(--vp-c-brand-1, #3b82f6);
}

.number-input {
  width: 90px;
  padding: 0.4rem 0.6rem;
  border: 1px solid var(--vp-c-border, #cbd5e1);
  border-radius: 6px;
  font-size: 1rem;
  font-weight: 600;
  text-align: center;
  background: var(--vp-c-bg-alt, #f6f6f7);
  color: var(--vp-c-text-1, #0f172a);
}

.metrics-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 1rem;
  margin-bottom: 1.25rem;
}

.metric-card {
  display: flex;
  align-items: center;
  gap: 0.85rem;
  background: var(--vp-c-bg, #ffffff);
  border: 1px solid var(--vp-c-divider, #e2e8f0);
  border-radius: 8px;
  padding: 1rem;
}

.metric-card.food { border-left: 4px solid #eab308; }
.metric-card.water { border-left: 4px solid #38bdf8; }
.metric-card.gathering { border-left: 4px solid #22c55e; }
.metric-card.pumps { border-left: 4px solid #06b6d4; }

.card-icon {
  font-size: 1.8rem;
}

.metric-name {
  font-size: 0.78rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: var(--vp-c-text-2, #475569);
}

.metric-value {
  font-size: 1.35rem;
  font-weight: 800;
  color: var(--vp-c-text-1, #0f172a);
  line-height: 1.2;
}

.metric-value .unit {
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--vp-c-text-2, #475569);
}

.metric-sub {
  font-size: 0.75rem;
  color: var(--vp-c-text-2, #475569);
  margin-top: 0.2rem;
}

.stock-info {
  background: var(--vp-c-warning-soft, rgba(234, 179, 8, 0.14));
  border: 1px solid rgba(234, 179, 8, 0.4);
  border-radius: 8px;
  padding: 0.9rem 1.1rem;
  margin-bottom: 1rem;
}

.info-row {
  display: flex;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 0.5rem;
  font-size: 0.9rem;
  color: var(--vp-c-text-1, #0f172a);
}

.highlight {
  font-weight: 700;
  color: var(--vp-c-warning-1, #915930);
}

.warning-text {
  margin: 0.5rem 0 0 0;
  font-size: 0.82rem;
  line-height: 1.45;
  color: var(--vp-c-text-1, #1e293b);
}

.advanced-section {
  border-top: 1px dashed var(--vp-c-border, #cbd5e1);
  padding-top: 0.85rem;
}

.toggle-btn {
  background: transparent;
  border: none;
  font-size: 0.85rem;
  font-weight: 600;
  color: var(--vp-c-brand-1, #3451b2);
  cursor: pointer;
  padding: 0;
}

.toggle-btn:hover {
  text-decoration: underline;
}

.advanced-content {
  margin-top: 0.75rem;
}

.tech-table {
  width: 100%;
  font-size: 0.82rem;
  border-collapse: collapse;
}

.tech-table th,
.tech-table td {
  padding: 0.45rem 0.65rem;
  border: 1px solid var(--vp-c-divider, #e2e8f0);
  color: var(--vp-c-text-1, #0f172a);
  text-align: left;
}

.tech-table th {
  background: var(--vp-c-default-soft, rgba(142, 150, 170, 0.14));
  font-weight: 700;
}

.footnote {
  display: block;
  margin-top: 0.45rem;
  color: var(--vp-c-text-2, #475569);
  font-size: 0.76rem;
}
</style>

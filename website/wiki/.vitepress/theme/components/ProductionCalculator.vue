<script setup lang="ts">
import { ref, computed } from 'vue'

const colonistCount = ref(10)
const showAdvanced = ref(false)

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
          <h3>Calculadora de Supervivencia y Consumo</h3>
          <p class="subtitle">Basada en las Fichas Consolidadas de Balance (Ciclo de 60s)</p>
        </div>
      </div>
      <div class="calc-presets">
        <span class="preset-label">Presets:</span>
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
        <label for="colonist-input">Población total de colonos:</label>
        <span class="count-badge">{{ colonistCount }} colonos</span>
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
          <div class="metric-name">Consumo de Comida</div>
          <div class="metric-value">{{ consumoComidaCiclo }} <span class="unit">u / ciclo</span></div>
          <div class="metric-sub">{{ consumoComidaHoraReal }} u / hora real</div>
        </div>
      </div>

      <div class="metric-card water">
        <div class="card-icon">💧</div>
        <div class="card-content">
          <div class="metric-name">Consumo de Agua</div>
          <div class="metric-value">{{ consumoAguaCiclo }} <span class="unit">u / ciclo</span></div>
          <div class="metric-sub">{{ consumoAguaHoraReal }} u / hora real</div>
        </div>
      </div>

      <div class="metric-card gathering">
        <div class="card-icon">🏹</div>
        <div class="card-content">
          <div class="metric-name">Puestos de Caza</div>
          <div class="metric-value">{{ puestosCazaRecomendados }} <span class="unit">mínimo</span></div>
          <div class="metric-sub">Hasta 7 trabajadores c/u</div>
        </div>
      </div>

      <div class="metric-card pumps">
        <div class="card-icon">🚰</div>
        <div class="card-content">
          <div class="metric-name">Estaciones de Agua</div>
          <div class="metric-value">{{ estacionesAguaRecomendadas }} <span class="unit">mínimo</span></div>
          <div class="metric-sub">Hasta 3 operarios c/u</div>
        </div>
      </div>
    </div>

    <!-- Autonomía Inicial -->
    <div class="stock-info">
      <div class="info-row">
        <span>⏱️ <strong>Autonomía con reserva inicial</strong> (5,000 u comida):</span>
        <span class="highlight">~{{ minutosAutonomia }} minutos (~{{ horasAutonomia }} horas)</span>
      </div>
      <p class="warning-text">
        ⚠️ <strong>Riesgo de Inanición:</strong> Si el almacén de comida llega a 0, hasta un 25% de la colonia perecerá por tick (cada 2 segundos), afectando primero a militares, obreros y técnicos.
      </p>
    </div>

    <!-- Toggle Desglose Técnico -->
    <div class="advanced-section">
      <button type="button" class="toggle-btn" @click="showAdvanced = !showAdvanced">
        {{ showAdvanced ? '▼ Ocultar ratios técnicos de simulación' : '▶ Ver ratios técnicos en motor Godot' }}
      </button>

      <div v-if="showAdvanced" class="advanced-content">
        <table class="tech-table">
          <thead>
            <tr>
              <th>Rol Demográfico</th>
              <th>Comida (u/h juego)</th>
              <th>Combustible (u/h)</th>
              <th>Energía (u/h)</th>
            </tr>
          </thead>
          <tbody>
            <tr><td>Ciudadano</td><td>2</td><td>0</td><td>0</td></tr>
            <tr><td>Desempleado</td><td>3</td><td>0</td><td>0</td></tr>
            <tr><td>Obrero</td><td>5</td><td>0</td><td>0</td></tr>
            <tr><td>Técnico</td><td>3</td><td>0</td><td>0</td></tr>
            <tr><td>Especialista</td><td>2</td><td>0</td><td>1</td></tr>
            <tr><td>Investigador</td><td>1</td><td>0</td><td>2</td></tr>
            <tr><td>Militar</td><td>4</td><td>2</td><td>0</td></tr>
          </tbody>
        </table>
        <small class="footnote">* 1 hora de juego equivale a 1 tick de simulación (2.0 segundos reales). 1 ciclo estándar (60s) = 30 horas de juego.</small>
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
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);
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
  color: var(--vp-c-text-2, #64748b);
}

.calc-presets {
  display: flex;
  align-items: center;
  gap: 0.4rem;
}

.preset-label {
  font-size: 0.8rem;
  color: var(--vp-c-text-2, #64748b);
}

.calc-presets button {
  background: var(--vp-c-bg-mute, #e2e8f0);
  border: 1px solid var(--vp-c-divider, #cbd5e1);
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
  background: var(--vp-c-brand, #3b82f6);
  color: #ffffff;
  border-color: var(--vp-c-brand, #3b82f6);
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
  margin-bottom: 0.6rem;
}

.count-badge {
  background: var(--vp-c-brand-soft, #eff6ff);
  color: var(--vp-c-brand, #2563eb);
  padding: 0.15rem 0.6rem;
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
  accent-color: var(--vp-c-brand, #3b82f6);
}

.number-input {
  width: 90px;
  padding: 0.4rem 0.6rem;
  border: 1px solid var(--vp-c-divider, #cbd5e1);
  border-radius: 6px;
  font-size: 1rem;
  font-weight: 600;
  text-align: center;
  background: var(--vp-c-bg, #ffffff);
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
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: var(--vp-c-text-2, #64748b);
}

.metric-value {
  font-size: 1.35rem;
  font-weight: 800;
  color: var(--vp-c-text-1, #0f172a);
  line-height: 1.2;
}

.metric-value .unit {
  font-size: 0.75rem;
  font-weight: 500;
  color: var(--vp-c-text-2, #64748b);
}

.metric-sub {
  font-size: 0.72rem;
  color: var(--vp-c-text-3, #94a3b8);
  margin-top: 0.2rem;
}

.stock-info {
  background: rgba(245, 158, 11, 0.08);
  border: 1px solid rgba(245, 158, 11, 0.3);
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
  color: #d97706;
}

.warning-text {
  margin: 0.5rem 0 0 0;
  font-size: 0.8rem;
  line-height: 1.4;
  color: var(--vp-c-text-2, #475569);
}

.advanced-section {
  border-top: 1px dashed var(--vp-c-divider, #cbd5e1);
  padding-top: 0.85rem;
}

.toggle-btn {
  background: transparent;
  border: none;
  font-size: 0.85rem;
  font-weight: 600;
  color: var(--vp-c-brand, #2563eb);
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
  padding: 0.4rem 0.6rem;
  border: 1px solid var(--vp-c-divider, #e2e8f0);
  text-align: left;
}

.tech-table th {
  background: var(--vp-c-bg-mute, #f1f5f9);
  font-weight: 600;
}

.footnote {
  display: block;
  margin-top: 0.4rem;
  color: var(--vp-c-text-3, #94a3b8);
  font-size: 0.75rem;
}
</style>

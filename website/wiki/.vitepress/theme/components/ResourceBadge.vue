<script setup lang="ts">
import { computed } from 'vue'
import { withBase } from 'vitepress'

const props = defineProps<{
  name: string
  category?: string
  color?: string
  icon?: string
}>()

interface BadgePalette {
  lightBg: string
  lightText: string
  lightBorder: string
  darkBg: string
  darkText: string
  darkBorder: string
  icon: string
  svg?: string
}

const palettes: Record<string, BadgePalette> = {
  agua: {
    lightBg: 'rgba(2, 132, 199, 0.12)', lightText: '#0369a1', lightBorder: '#0284c7',
    darkBg: 'rgba(56, 189, 248, 0.16)', darkText: '#7dd3fc', darkBorder: '#38bdf8',
    icon: '💧', svg: '/icons/agua.svg'
  },
  comida: {
    lightBg: 'rgba(202, 138, 4, 0.14)', lightText: '#854d0e', lightBorder: '#ca8a04',
    darkBg: 'rgba(234, 179, 8, 0.16)', darkText: '#fde047', darkBorder: '#eab308',
    icon: '🍖', svg: '/icons/comida.svg'
  },
  madera: {
    lightBg: 'rgba(180, 83, 9, 0.13)', lightText: '#78350f', lightBorder: '#b45309',
    darkBg: 'rgba(245, 158, 11, 0.16)', darkText: '#fcd34d', darkBorder: '#f59e0b',
    icon: '🪵', svg: '/icons/madera.svg'
  },
  tablas: {
    lightBg: 'rgba(180, 83, 9, 0.13)', lightText: '#78350f', lightBorder: '#b45309',
    darkBg: 'rgba(245, 158, 11, 0.16)', darkText: '#fcd34d', darkBorder: '#f59e0b',
    icon: '🪚', svg: '/icons/tablas.svg'
  },
  piedra: {
    lightBg: 'rgba(71, 85, 105, 0.13)', lightText: '#1e293b', lightBorder: '#64748b',
    darkBg: 'rgba(148, 163, 184, 0.18)', darkText: '#e2e8f0', darkBorder: '#94a3b8',
    icon: '🪨', svg: '/icons/piedra.svg'
  },
  'bloques de piedra': {
    lightBg: 'rgba(71, 85, 105, 0.13)', lightText: '#1e293b', lightBorder: '#64748b',
    darkBg: 'rgba(148, 163, 184, 0.18)', darkText: '#e2e8f0', darkBorder: '#94a3b8',
    icon: '🧱', svg: '/icons/bloques_piedra.svg'
  },
  hierro: {
    lightBg: 'rgba(51, 65, 85, 0.14)', lightText: '#0f172a', lightBorder: '#475569',
    darkBg: 'rgba(148, 163, 184, 0.22)', darkText: '#f1f5f9', darkBorder: '#94a3b8',
    icon: '⛏️', svg: '/icons/hierro.svg'
  },
  cobre: {
    lightBg: 'rgba(234, 88, 12, 0.13)', lightText: '#9a3412', lightBorder: '#ea580c',
    darkBg: 'rgba(249, 115, 22, 0.18)', darkText: '#fdba74', darkBorder: '#fb923c',
    icon: '🥉', svg: '/icons/cobre.svg'
  },
  carbón: {
    lightBg: 'rgba(55, 65, 81, 0.15)', lightText: '#111827', lightBorder: '#4b5563',
    darkBg: 'rgba(156, 163, 175, 0.20)', darkText: '#f3f4f6', darkBorder: '#9ca3af',
    icon: '⬛', svg: '/icons/carbon.svg'
  },
  crudo: {
    lightBg: 'rgba(30, 41, 59, 0.15)', lightText: '#0f172a', lightBorder: '#334155',
    darkBg: 'rgba(100, 116, 139, 0.26)', darkText: '#f8fafc', darkBorder: '#94a3b8',
    icon: '🛢️', svg: '/icons/crudo.svg'
  },
  combustible: {
    lightBg: 'rgba(220, 38, 38, 0.12)', lightText: '#991b1b', lightBorder: '#dc2626',
    darkBg: 'rgba(239, 68, 68, 0.18)', darkText: '#fca5a5', darkBorder: '#f87171',
    icon: '⛽', svg: '/icons/combustible.svg'
  },
  acero: {
    lightBg: 'rgba(79, 70, 229, 0.12)', lightText: '#3730a3', lightBorder: '#4f46e5',
    darkBg: 'rgba(99, 102, 241, 0.20)', darkText: '#c7d2fe', darkBorder: '#818cf8',
    icon: '🛡️', svg: '/icons/acero.svg'
  },
  energía: {
    lightBg: 'rgba(217, 119, 6, 0.14)', lightText: '#92400e', lightBorder: '#d97706',
    darkBg: 'rgba(245, 158, 11, 0.18)', darkText: '#fde68a', darkBorder: '#fbbf24',
    icon: '⚡', svg: '/icons/energia.svg'
  },
  tierra: {
    lightBg: 'rgba(161, 98, 7, 0.14)', lightText: '#713f12', lightBorder: '#a16207',
    darkBg: 'rgba(202, 138, 4, 0.18)', darkText: '#fef08a', darkBorder: '#eab308',
    icon: '🌱', svg: '/icons/tierra.svg'
  },
  'tierras raras': {
    lightBg: 'rgba(147, 51, 234, 0.12)', lightText: '#581c87', lightBorder: '#9333ea',
    darkBg: 'rgba(168, 85, 247, 0.20)', darkText: '#e9d5ff', darkBorder: '#c084fc',
    icon: '💎', svg: '/icons/tierras_raras.svg'
  },
  'mineral refinado': {
    lightBg: 'rgba(147, 51, 234, 0.12)', lightText: '#581c87', lightBorder: '#9333ea',
    darkBg: 'rgba(168, 85, 247, 0.20)', darkText: '#e9d5ff', darkBorder: '#c084fc',
    icon: '🔮', svg: '/icons/mineral_refinado.svg'
  },
  vidrio: {
    lightBg: 'rgba(6, 182, 212, 0.12)', lightText: '#0e7490', lightBorder: '#06b6d4',
    darkBg: 'rgba(6, 182, 212, 0.20)', darkText: '#a5f3fc', darkBorder: '#22d3ee',
    icon: '🪟', svg: '/icons/vidrio.svg'
  }
}

const aliases: Record<string, string> = {
  glass: 'vidrio',
  carbon: 'carbón',
  energia: 'energía',
  water: 'agua',
  food: 'comida',
  wood: 'madera',
  planks: 'tablas',
  stone: 'piedra',
  'stone blocks': 'bloques de piedra',
  bloques_piedra: 'bloques de piedra',
  iron: 'hierro',
  copper: 'cobre',
  coal: 'carbón',
  'crude oil': 'crudo',
  oil: 'crudo',
  fuel: 'combustible',
  steel: 'acero',
  energy: 'energía',
  earth: 'tierra',
  dirt: 'tierra',
  'rare earths': 'tierras raras',
  tierras_raras: 'tierras raras',
  'refined minerals': 'mineral refinado',
  'refined mineral': 'mineral refinado',
  mineral_refinado: 'mineral refinado'
}

const key = computed(() => {
  const raw = (props.name || '').trim().toLowerCase()
  return aliases[raw] || raw
})

const style = computed<BadgePalette>(() => {
  const match = palettes[key.value]
  if (match) return match
  return {
    lightBg: 'var(--vp-c-default-soft)',
    lightText: 'var(--vp-c-text-1)',
    lightBorder: 'var(--vp-c-border)',
    darkBg: 'var(--vp-c-default-soft)',
    darkText: 'var(--vp-c-text-1)',
    darkBorder: 'var(--vp-c-border)',
    icon: props.icon || '📦'
  }
})
</script>

<template>
  <span
    class="resource-badge"
    :style="{
      '--badge-bg-light': color ? `${color}1f` : style.lightBg,
      '--badge-text-light': color || style.lightText,
      '--badge-border-light': color || style.lightBorder,
      '--badge-bg-dark': color ? `${color}33` : style.darkBg,
      '--badge-text-dark': color || style.darkText,
      '--badge-border-dark': color || style.darkBorder
    }"
  >
    <img
      v-if="style.svg && !icon"
      :src="withBase(style.svg)"
      :alt="name"
      class="badge-svg"
    />
    <span v-else class="badge-icon">{{ icon || style.icon }}</span>
    <span class="badge-name">{{ name }}</span>
    <span v-if="category" class="badge-category">{{ category }}</span>
  </span>
</template>

<style scoped>
.resource-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.15rem 0.55rem;
  margin: 0 0.2rem;
  border-radius: 9999px;
  border: 1px solid var(--badge-border-light);
  background-color: var(--badge-bg-light);
  color: var(--badge-text-light);
  font-size: 0.85em;
  font-weight: 600;
  line-height: 1.4;
  vertical-align: middle;
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}

:global(.dark) .resource-badge {
  background-color: var(--badge-bg-dark);
  color: var(--badge-text-dark);
  border-color: var(--badge-border-dark);
}

.resource-badge:hover {
  transform: translateY(-1px);
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.12);
}

.badge-svg {
  width: 15px;
  height: 15px;
  image-rendering: pixelated;
  flex-shrink: 0;
}

.badge-icon {
  font-size: 0.95em;
}

.badge-name {
  white-space: nowrap;
}

.badge-category {
  font-size: 0.75em;
  font-weight: 700;
  padding: 0.05rem 0.35rem;
  border-radius: 4px;
  background: rgba(0, 0, 0, 0.07);
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

:global(.dark) .badge-category {
  background: rgba(255, 255, 255, 0.12);
}
</style>

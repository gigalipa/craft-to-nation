<script setup lang="ts">
import { computed } from 'vue'

const props = defineProps<{
  name: string
  category?: string
  color?: string
  icon?: string
}>()

const defaultStyles: Record<string, { bg: string; text: string; border: string; icon: string }> = {
  agua: { bg: 'rgba(56, 189, 248, 0.15)', text: '#0284c7', border: '#38bdf8', icon: '💧' },
  comida: { bg: 'rgba(234, 179, 8, 0.15)', text: '#ca8a04', border: '#eab308', icon: '🍖' },
  madera: { bg: 'rgba(180, 83, 9, 0.15)', text: '#b45309', border: '#d97706', icon: '🪵' },
  piedra: { bg: 'rgba(100, 116, 139, 0.15)', text: '#475569', border: '#94a3b8', icon: '🪨' },
  hierro: { bg: 'rgba(148, 163, 184, 0.2)', text: '#334155', border: '#64748b', icon: '⛏️' },
  cobre: { bg: 'rgba(249, 115, 22, 0.15)', text: '#c2410c', border: '#f97316', icon: '🥉' },
  carbón: { bg: 'rgba(75, 85, 99, 0.2)', text: '#374151', border: '#4b5563', icon: '⬛' },
  carbon: { bg: 'rgba(75, 85, 99, 0.2)', text: '#374151', border: '#4b5563', icon: '⬛' },
  crudo: { bg: 'rgba(30, 41, 59, 0.25)', text: '#0f172a', border: '#334155', icon: '🛢️' },
  combustible: { bg: 'rgba(239, 68, 68, 0.15)', text: '#dc2626', border: '#ef4444', icon: '⛽' },
  acero: { bg: 'rgba(99, 102, 241, 0.15)', text: '#4f46e5', border: '#6366f1', icon: '🛡️' },
  energía: { bg: 'rgba(245, 158, 11, 0.15)', text: '#d97706', border: '#f59e0b', icon: '⚡' },
  energia: { bg: 'rgba(245, 158, 11, 0.15)', text: '#d97706', border: '#f59e0b', icon: '⚡' },
  tierra: { bg: 'rgba(161, 98, 7, 0.15)', text: '#854d0e', border: '#a16207', icon: '🌱' },
  'tierras raras': { bg: 'rgba(168, 85, 247, 0.15)', text: '#7e22ce', border: '#a855f7', icon: '💎' }
}

const key = computed(() => (props.name || '').trim().toLowerCase())
const style = computed(() => {
  const match = defaultStyles[key.value]
  if (match) return match
  return {
    bg: 'var(--vp-c-bg-mute, #f1f5f9)',
    text: 'var(--vp-c-text-1, #0f172a)',
    border: 'var(--vp-c-divider, #cbd5e1)',
    icon: props.icon || '📦'
  }
})
</script>

<template>
  <span
    class="resource-badge"
    :style="{
      backgroundColor: color ? `${color}22` : style.bg,
      borderColor: color || style.border,
      color: color || style.text
    }"
  >
    <span class="badge-icon">{{ icon || style.icon }}</span>
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
  border: 1px solid;
  font-size: 0.85em;
  font-weight: 600;
  line-height: 1.4;
  vertical-align: middle;
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}
.resource-badge:hover {
  transform: translateY(-1px);
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.08);
}
.badge-icon {
  font-size: 0.95em;
}
.badge-name {
  white-space: nowrap;
}
.badge-category {
  font-size: 0.75em;
  opacity: 0.85;
  padding: 0.05rem 0.35rem;
  border-radius: 4px;
  background: rgba(0, 0, 0, 0.08);
  text-transform: uppercase;
  letter-spacing: 0.04em;
}
</style>

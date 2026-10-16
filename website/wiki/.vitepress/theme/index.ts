import DefaultTheme from 'vitepress/theme'
import type { Theme } from 'vitepress'
import './custom.css'
import ResourceBadge from './components/ResourceBadge.vue'
import ProductionCalculator from './components/ProductionCalculator.vue'

export default {
  extends: DefaultTheme,
  enhanceApp({ app }) {
    app.component('ResourceBadge', ResourceBadge)
    app.component('ProductionCalculator', ProductionCalculator)
  }
} satisfies Theme

import { defineConfig } from 'vitepress'

export default defineConfig({
  title: "Craft to Nation Wiki",
  description: "Wiki oficial y documentación de Craft to Nation",
  base: '/wiki/',
  srcDir: 'src',
  outDir: './dist',
  cleanUrls: true,
  checkDeadLinks: true,
  head: [
    ['link', { rel: 'icon', type: 'image/png', href: '/wiki/assets/favicon-32.png' }]
  ],

  themeConfig: {
    logo: '/assets/craft-to-nation-mark.png',
    i18nRouting: false,
    search: {
      provider: 'local'
    }
  },

  locales: {
    root: {
      label: 'Español',
      lang: 'es-ES',
      themeConfig: {
        nav: [
          { text: 'Guía del Jugador', link: '/es/guia/inicio', activeMatch: '/es/guia/' },
          { text: 'Desarrollo & GDD', link: '/es/dev/gdd', activeMatch: '/es/dev/' },
          { text: 'Sitio Principal', link: 'https://crafttonation.netlify.app/', target: '_self', noIcon: true }
        ],
        sidebarMenuLabel: 'Menú',
        returnToTopLabel: 'Volver arriba',
        darkModeSwitchLabel: 'Apariencia',
        lightModeSwitchTitle: 'Cambiar a modo claro',
        darkModeSwitchTitle: 'Cambiar a modo oscuro',
        outline: {
          label: 'En esta página'
        },
        docFooter: {
          prev: 'Página anterior',
          next: 'Página siguiente'
        },
        sidebar: {
          '/es/guia/': [
            {
              text: 'Primeros Pasos',
              items: [
                { text: 'Introducción', link: '/es/guia/inicio' },
                { text: 'Recursos Básicos', link: '/es/guia/recursos' },
                { text: 'Edificios y Almacenes', link: '/es/guia/edificios' },
                { text: 'Gestión de Colonos', link: '/es/guia/colonos' }
              ]
            }
          ],
          '/es/dev/': [
            {
              text: 'Documentación Técnica',
              items: [
                { text: 'Pilares del GDD', link: '/es/dev/gdd' },
                { text: 'Arquitectura Godot & PoCs', link: '/es/dev/godot' },
                { text: 'Logística y Ductos', link: '/es/dev/logistica' },
                { text: 'Roadmap de Desarrollo', link: '/es/dev/roadmap' }
              ]
            }
          ]
        }
      }
    },
    en: {
      label: 'English',
      lang: 'en-US',
      link: '/en/',
      themeConfig: {
        nav: [
          { text: 'Player Guide', link: '/en/guide/start', activeMatch: '/en/guide/' },
          { text: 'GDD & Development', link: '/en/dev/gdd', activeMatch: '/en/dev/' },
          { text: 'Main Site', link: 'https://crafttonation.netlify.app/', target: '_self', noIcon: true }
        ],
        sidebar: {
          '/en/guide/': [
            {
              text: 'Getting Started',
              items: [
                { text: 'Introduction', link: '/en/guide/start' },
                { text: 'Basic Resources', link: '/en/guide/resources' },
                { text: 'Buildings & Storage', link: '/en/guide/buildings' },
                { text: 'Colonist Management', link: '/en/guide/colonists' }
              ]
            }
          ],
          '/en/dev/': [
            {
              text: 'Technical Design',
              items: [
                { text: 'GDD Core Pillars', link: '/en/dev/gdd' },
                { text: 'Godot Architecture', link: '/en/dev/godot' },
                { text: 'Logistics & Ducts', link: '/en/dev/logistics' },
                { text: 'Development Roadmap', link: '/en/dev/roadmap' }
              ]
            }
          ]
        }
      }
    },
    fr: {
      label: 'Français',
      lang: 'fr-FR',
      link: '/fr/',
      themeConfig: {
        nav: [
          { text: 'Accueil Wiki', link: '/fr/' },
          { text: 'Guide (EN)', link: '/en/guide/start' },
          { text: 'GDD & Dev (EN)', link: '/en/dev/gdd' },
          { text: 'Site Principal', link: 'https://crafttonation.netlify.app/', target: '_self', noIcon: true }
        ],
        sidebarMenuLabel: 'Menu',
        returnToTopLabel: 'Retour en haut',
        darkModeSwitchLabel: 'Apparence',
        outline: {
          label: 'Sur cette page'
        },
        docFooter: {
          prev: 'Page précédente',
          next: 'Page suivante'
        }
      }
    }
  }
})

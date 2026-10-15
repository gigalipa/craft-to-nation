import { defineConfig } from 'vitepress'

export default defineConfig({
  title: "Craft to Nation Wiki",
  description: "Wiki oficial y documentación de Craft to Nation",
  base: '/wiki/',
  srcDir: 'src',
  outDir: './dist',
  cleanUrls: true,
  checkDeadLinks: true,

  locales: {
    root: {
      label: 'Español',
      lang: 'es-ES',
      themeConfig: {
        nav: [
          { text: 'Guía del Jugador', link: '/es/guia/inicio' },
          { text: 'Desarrollo & GDD', link: '/es/dev/gdd' },
          { text: 'Juego Principal', link: '/' }
        ],
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
          { text: 'Player Guide', link: '/en/guide/start' },
          { text: 'GDD & Development', link: '/en/dev/gdd' },
          { text: 'Main Website', link: '/' }
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
          { text: 'Accueil Wiki', link: '/fr/' }
        ]
      }
    }
  }
})

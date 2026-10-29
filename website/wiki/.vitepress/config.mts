import { defineConfig } from 'vitepress'

export default defineConfig({
  title: "Craft to Nation Wiki",
  description: "Wiki oficial y documentación de Craft to Nation",
  base: '/wiki/',
  srcDir: 'src',
  outDir: './dist',
  cleanUrls: true,
  checkDeadLinks: true,
  sitemap: {
    hostname: 'https://crafttonation.netlify.app',
    transformItems(items) {
      return items.map((item) => ({
        ...item,
        url: `wiki/${item.url.replace(/^\//, '')}`
      }))
    }
  },
  head: [
    ['link', { rel: 'icon', type: 'image/png', href: '/wiki/assets/favicon-32.png' }],
    ['meta', { name: 'google-site-verification', content: '32314MEFrp3A3-KL8ZCys7EaSrTp3MSi_YeRkKXCOjU' }]
  ],

  transformHead({ pageData }) {
    const cleanPath = pageData.relativePath
      .replace(/(?:^|\/)index\.md$/, '/')
      .replace(/\.md$/, '')
      .replace(/^\//, '')
    const canonicalUrl = `https://crafttonation.netlify.app/wiki/${cleanPath}`
    const pageTitle = pageData.title ? `${pageData.title} | Craft to Nation Wiki` : 'Craft to Nation Wiki'
    const pageDescription = pageData.description || 'Wiki oficial y documentación de Craft to Nation'
    const isEn = pageData.relativePath.startsWith('en/')
    const isFr = pageData.relativePath.startsWith('fr/')
    const lang = isEn ? 'en-US' : isFr ? 'fr-FR' : 'es-ES'
    const ogLocale = isEn ? 'en_US' : isFr ? 'fr_FR' : 'es_ES'

    return [
      ['link', { rel: 'canonical', href: canonicalUrl }],
      ['meta', { property: 'og:title', content: pageTitle }],
      ['meta', { property: 'og:description', content: pageDescription }],
      ['meta', { property: 'og:type', content: 'article' }],
      ['meta', { property: 'og:url', content: canonicalUrl }],
      ['meta', { property: 'og:image', content: 'https://crafttonation.netlify.app/assets/citycraft-world.webp' }],
      ['meta', { property: 'og:site_name', content: 'Craft to Nation Wiki' }],
      ['meta', { property: 'og:locale', content: ogLocale }],
      ['meta', { name: 'twitter:card', content: 'summary_large_image' }],
      ['meta', { name: 'twitter:title', content: pageTitle }],
      ['meta', { name: 'twitter:description', content: pageDescription }],
      ['meta', { name: 'twitter:image', content: 'https://crafttonation.netlify.app/assets/citycraft-world.webp' }],
      ['meta', { name: 'twitter:site', content: '@crafttonation' }],
      [
        'script',
        { type: 'application/ld+json' },
        JSON.stringify({
          '@context': 'https://schema.org',
          '@type': 'TechArticle',
          headline: pageData.title || 'Craft to Nation Wiki',
          description: pageDescription,
          inLanguage: lang,
          mainEntityOfPage: canonicalUrl,
          publisher: {
            '@type': 'Organization',
            name: 'Craft to Nation',
            url: 'https://crafttonation.netlify.app/'
          }
        })
      ]
    ]
  },

  themeConfig: {
    logo: '/assets/craft-to-nation-mark.png',
    i18nRouting: true,
    search: {
      provider: 'local'
    }
  },

  locales: {
    root: {
      label: 'Español',
      lang: 'es-ES',
      link: '/es/',
      themeConfig: {
        nav: [
          { text: 'Guía del Jugador', link: '/es/guide/start', activeMatch: '/es/guide/' },
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
        footer: {
          message: 'Publicado bajo licencias MIT (código) y CC BY 4.0 (documentación).',
          copyright: 'Craft to Nation · <a href="/privacy.html" target="_self">Privacidad</a> · <a href="/terms.html" target="_self">Términos</a> · <a href="/.well-known/security.txt" target="_self">Seguridad</a>'
        },
        sidebar: {
          '/es/guide/': [
            {
              text: 'Primeros Pasos',
              items: [
                { text: 'Introducción', link: '/es/guide/start' },
                { text: 'Recursos Básicos', link: '/es/guide/resources' },
                { text: 'Edificios y Almacenes', link: '/es/guide/buildings' },
                { text: 'Gestión de Colonos', link: '/es/guide/colonists' }
              ]
            }
          ],
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
                { text: 'Logística y Ductos', link: '/es/dev/logistics' },
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
        footer: {
          message: 'Released under MIT (code) and CC BY 4.0 (documentation) licenses.',
          copyright: 'Craft to Nation · <a href="/privacy.html" target="_self">Privacy</a> · <a href="/terms.html" target="_self">Terms</a> · <a href="/.well-known/security.txt" target="_self">Security</a>'
        },
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
          { text: 'Guide du Joueur', link: '/fr/guide/start', activeMatch: '/fr/guide/' },
          { text: 'GDD & Dév', link: '/fr/dev/gdd', activeMatch: '/fr/dev/' },
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
        },
        footer: {
          message: 'Publié sous licences MIT (code) et CC BY 4.0 (documentation).',
          copyright: 'Craft to Nation · <a href="/privacy.html" target="_self">Confidentialité</a> · <a href="/terms.html" target="_self">Conditions</a> · <a href="/.well-known/security.txt" target="_self">Sécurité</a>'
        },
        sidebar: {
          '/fr/guide/': [
            {
              text: 'Guide du Joueur',
              items: [
                { text: 'Premiers Pas & Survie', link: '/fr/guide/start' },
                { text: 'Ressources de Base & Industries', link: '/fr/guide/resources' },
                { text: 'Bâtiments & Stockage', link: '/fr/guide/buildings' },
                { text: 'Gestion des Colons & Démographie', link: '/fr/guide/colonists' }
              ]
            }
          ],
          '/fr/dev/': [
            {
              text: 'Conception Technique',
              items: [
                { text: 'Piliers du GDD v3.59', link: '/fr/dev/gdd' },
                { text: 'Architecture Godot 4.7', link: '/fr/dev/godot' },
                { text: 'Logistique, Voirie & Conduits', link: '/fr/dev/logistics' },
                { text: 'Feuille de Route (Roadmap)', link: '/fr/dev/roadmap' }
              ]
            }
          ]
        }
      }
    }
  }
})

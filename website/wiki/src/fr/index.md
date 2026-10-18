---
layout: home

hero:
  name: "Craft to Nation"
  text: "Portail Officiel & Wiki"
  tagline: "Du premier bloc à une nation vivante. Guide de colonisation, gestion urbaine et documentation technique (GDD v3.57)."
  image:
    src: /assets/craft-to-nation-logo.png
    alt: Craft to Nation Logo
  actions:
    - theme: brand
      text: Guide en Anglais (EN)
      link: /en/guide/start
    - theme: alt
      text: Guide en Espagnol (ES)
      link: /es/guia/inicio
    - theme: alt
      text: Site Principal
      link: https://crafttonation.netlify.app/
      target: _self

features:
  - title: Survie & Construction Voxel
    details: Fondez votre premier abri hermétique en vue à la première personne, basculez en vue tactique aérienne (touche C), déclarez votre Noyau Urbain et maîtrisez les ressources de base.
    link: /en/guide/start
    linkText: Découvrir le Guide (EN)
  - title: Logistique & Économie Industrielle
    details: 8 chaînes de raffinage, postes d'extraction de niveau I à III, oléoducs surélevés et réseau de transport terrestre pour alimenter vos usines et centrales électriques.
    link: /en/guide/resources
    linkText: Économie des Ressources (EN)
  - title: Démographie & Moral Dynamique
    details: Gérez l'alimentation de vos colons selon leur métier, prévenez les crises et exploitez la courbe de productivité et de migration mensuelle par paliers basée sur le moral.
    link: /en/guide/colonists
    linkText: Gestion des Colons (EN)
  - title: Architecture Moteur Godot 4.6
    details: Conception technique, simulation déterministe à ticks horaires (2,0s = 1h), iconographie vectorielle HUD SVG et 28 scènes de tests automatisés.
    link: /en/dev/godot
    linkText: Architecture Godot (EN)
---

# Bienvenue sur le Wiki Officiel de Craft to Nation

![De l'abri du pionnier à la métropole industrielle](/assets/citycraft-hero.webp)

**Craft to Nation** est un jeu hybride novateur mêlant survie immersive à la première personne, simulation de construction de ville (*City Builder*), gestion logistique industrielle et stratégie militaire en temps réel (*RTS*) sur un monde voxel procédural de **200×200 cellules**.

---

## Les Cinq Piliers du Jeu

1. **Dualité de Perspective (Micro vs. Macro) :** Passez instantanément (touche `C` avec vol de caméra fluide de `0,6 s`) de l'action viscérale à la première personne (abattre des arbres, miner de la pierre, défendre les remparts) à la vue tactique aérienne pour planifier votre urbanisme et tracer vos routes (`V`).
2. **Modularité et Blueprints :** Créez librement vos maisons, entrepôts et usines. Dès que le moteur valide leur étanchéité et leurs accès (touche `B` sur la porte d'entrée, `Maj + B` pour remodeler), enregistrez-les sous forme de plans paramétriques (*blueprints*) constructibles automatiquement par vos équipes d'ouvriers.
3. **Zonage Stratégique Tripartite :** Séparez nettement la **Zone A (Résidentielle & Recherche)**, la **Zone B (Industrielle & Militaire)** et les **Postes Périphériques d'Extraction** pour assurer l'efficacité logistique et la sécurité de vos citoyens.
4. **Économie Organique & Moral Dynamique :** Chaque citoyen consomme des vivres selon sa profession (d'ouvrier carrier à chercheur universitaire) et participe à un modèle psychologique de moral (0 à 100) qui module directement la productivité (`0 %` à `120 %`) et les flux migratoires mensuels (`-5` à `+5` colons/mois).
5. **Souveraineté Portable en Multijoueur :** Exportez votre Noyau Urbain (*Urban Core*) et vos plans de construction éprouvés vers des serveurs multijoueurs compétitifs générés procéduralement.

---

## Documentation et Versions Linguistiques

La documentation complète et le manuel de référence sont disponibles dans les sections suivantes :

- 🇬🇧 **Version Anglaise (Complète) :**
  - [Guide du Débutant : Premiers Pas et Survie](/en/guide/start)
  - [Économie des Ressources et Extraction](/en/guide/resources)
  - [Bâtiments, Abris et Stock Central](/en/guide/buildings)
  - [Gestion des Colons et Calculateur de Production](/en/guide/colonists)
  - [GDD v3.57 : Piliers et Philosophie de Conception](/en/dev/gdd)
  - [Architecture Technique sous Godot 4.6](/en/dev/godot)
  - [Logistique Terrestre et Réseaux de Canalisations](/en/dev/logistics)
  - [Feuille de Route du Développement (Roadmap)](/en/dev/roadmap)

- 🇪🇸 **Version Espagnole (Complète) :**
  - [Guía del Jugador](/es/guia/inicio)
  - [Documentación Técnica y GDD v3.57](/es/dev/gdd)

> [!NOTE]
> La traduction intégrale des articles en langue française est actuellement en cours de développement. Les liens ci-dessus vous permettent d'accéder à l'ensemble des données techniques et des guides de jeu à jour.


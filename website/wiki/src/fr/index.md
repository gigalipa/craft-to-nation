---
layout: home
title: "Wiki Officiel Craft to Nation (Français)"
description: "Documentation officielle, guide du joueur et architecture technique pour le jeu de survie et gestion de colonie Craft to Nation."

hero:
  name: "Craft to Nation"
  text: "Portail Officiel & Wiki"
  tagline: "Du premier bloc à une nation vivante. Guide de colonisation, gestion urbaine et documentation technique (GDD v3.59)."
  image:
    src: /assets/craft-to-nation-logo.png
    alt: Craft to Nation Logo
  actions:
    - theme: brand
      text: Guide du Joueur
      link: /fr/guide/start
    - theme: alt
      text: Développement & GDD v3.59
      link: /fr/dev/gdd
    - theme: alt
      text: Site Principal
      link: https://crafttonation.netlify.app/
      target: _self

features:
  - title: Survie & Construction Voxel
    details: Fondez votre premier abri hermétique en vue à la première personne, basculez en vue tactique aérienne (touche C), déclarez votre Noyau Urbain et maîtrisez les ressources de base.
    link: /fr/guide/start
    linkText: Découvrir le Guide
  - title: Logistique & Économie Industrielle
    details: 9 chaînes de raffinage, postes d'extraction de niveau I à III, oléoducs surélevés et réseau de transport terrestre pour alimenter vos usines et centrales électriques.
    link: /fr/guide/resources
    linkText: Économie des Ressources
  - title: Démographie & Moral Dynamique
    details: Gérez l'alimentation de vos colons selon leur métier, prévenez les crises et exploitez la courbe de productivité et de migration mensuelle par paliers basée sur le moral.
    link: /fr/guide/colonists
    linkText: Gestion des Colons
  - title: Architecture Moteur Godot 4.7
    details: Conception technique, simulation déterministe à ticks horaires (2,0s = 1h), iconographie vectorielle HUD SVG et 28 scènes de tests automatisés.
    link: /fr/dev/godot
    linkText: Architecture Godot
---

# Bienvenue sur le Wiki Officiel de Craft to Nation

![De l'abri du pionnier à la métropole industrielle](/assets/citycraft-hero.webp)

**Craft to Nation** est un jeu hybride novateur mêlant survie immersive à la première personne, simulation de construction de ville (*City Builder*), gestion logistique industrielle et stratégie militaire en temps réel (*RTS*) sur un monde voxel procédural de **200×200 cellules**.

---

## Les Cinq Piliers du Jeu

1. **Dualité de Perspective (Micro vs. Macro) :** Passez instantanément (touche `C` avec vol de caméra fluide de `0,6 s`) de l'action viscérale à la première personne (abattre des arbres, miner de la pierre, activer le mode route à pied `V`) à la vue tactique aérienne pour planifier votre urbanisme via le menu numérique hiérarchique (`1` Construire, `2` Zonage, `3` Démolir, `Z`/`X` navigation).
2. **Modularité et Blueprints :** Créez librement vos maisons, entrepôts et usines. Dès que le moteur valide leur étanchéité et leurs accès (touche `B` sur la porte d'entrée, `Maj + B` pour remodeler), enregistrez-les sous forme de plans paramétriques (*blueprints*) constructibles automatiquement par vos équipes d'ouvriers.
3. **Zonage Stratégique Tripartite :** Séparez nettement la **Zone A (Résidentielle & Recherche)**, la **Zone B (Industrielle & Militaire)** et les **Postes Périphériques d'Extraction** pour assurer l'efficacité logistique et la sécurité de vos citoyens.
4. **Économie Organique & Moral Dynamique :** Chaque citoyen consomme des vivres selon sa profession (d'ouvrier carrier à chercheur universitaire) et participe à un modèle psychologique de moral (0 à 100) qui module directement la productivité (`0,5×` à `2,0×`) et les flux migratoires mensuels (`-5` à `+5` colons/mois).
5. **Souveraineté Portable en Multijoueur :** Exportez votre Noyau Urbain (*Urban Core*) et vos plans de construction éprouvés vers des serveurs multijoueurs compétitifs générés procéduralement.

---

## Sommaire de la Documentation en Français

- 📖 **Guide du Joueur :**
  - [Premiers Pas & Survie](/fr/guide/start)
  - [Économie des Ressources & Industries](/fr/guide/resources)
  - [Bâtiments, Niveaux Urbains & Stockage](/fr/guide/buildings)
  - [Gestion des Colons & Démographie](/fr/guide/colonists)

- ⚙️ **Conception Technique & Développement :**
  - [GDD v3.59 : Piliers & Philosophie](/fr/dev/gdd)
  - [Architecture Technique sous Godot 4.7](/fr/dev/godot)
  - [Logistique, Voirie & Conduits Surélevés](/fr/dev/logistics)
  - [Feuille de Route du Développement (Roadmap)](/fr/dev/roadmap)

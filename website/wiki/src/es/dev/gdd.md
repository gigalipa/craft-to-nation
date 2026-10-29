---
title: "Pilares de Diseño y GDD (v3.59)"
description: "Documento de Diseño de Juego (GDD v3.59) de Craft to Nation: visión de supervivencia híbrida, city building orgánico, evolución de eras por IDU, investigación en 2 capas, logística de transporte, refinería Vidriera y paneles de ventana."
---

# Pilares de Diseño y GDD (v3.59)

El **Documento de Diseño de Juego (GDD)** de **Craft to Nation** establece las directrices conceptuales, sistémicas y matemáticas que rigen el proyecto. Esta página resume los pilares centrales, el marco evolutivo de eras tecnológicas, el ciclo de juego (*game loop*) y las especificaciones vigentes de la versión **v3.59**.

---

## 1. Visión, Eslogan y Marco de Eras Tecnológicas

> **Eslogan Oficial:** *From first block to living nation.* / *Del primer bloque a una nación viva.*  
> **Frase de Campaña:** *Survive. Craft. Automate. Lead.*  
> **Género Híbrido:** City Builder, Supervivencia en Primera Persona, Estrategia en Tiempo Real (RTS), Gestión y Logística de Fábricas.  
> **Inspiraciones Clave:** *SimCity, Age of Empires, Minecraft, Mindustry.*

![Evolución a través de las eras tecnológicas en Craft to Nation](/assets/concept-era-evolution.webp)

### Las Cinco Eras Tecnológicas y su Ramificación Ideológica
La civilización progresa desde la supervivencia primitiva hasta un horizonte tecnológico bifurcado según las decisiones industriales y energéticas del jugador:
1. **Era 1 — Prehistoria (Génesis):** Supervivencia manual, recolección de frutos, tierra compactada, adobe y madera en bruto.
2. **Era 2 — Edad Antigua (Fundación Urbana):** Mampostería en piedra, acueductos, caminos de tierra pisada, aserraderos y carboneras.
3. **Era 3 — Revolución Industrial y Steampunk:** Siderurgia de acero, estructuras de hierro, perforación petrolífera, redes de tuberías presurizadas y generación termoeléctrica (`kW / MW`).
4. **Eras 4 y 5 — Bifurcación Tecnológica (Horizonte Futuro):**
   - **Rama Dieselpunk:** Hegemonía de hidrocarburos pesados, blindados de asedio y fortificaciones de acero masivo.
   - **Rama Cyberpunk:** Explotación intensiva de tierras raras, minerales refinados, automatización cibernética y redes de alta densidad.
   - **Rama Solarpunk:** Integración ecológica, energías limpias de alta eficiencia y armonía entre bioma y metrópolis.

---

## 2. Los Cinco Pilares Fundamentales

```
┌────────────────────────────────────────────────────────────────────────┐
│                      PILARES DE DISEÑO DE CTN                          │
├───────────────────┬───────────────────┬────────────────────────────────┤
│ 1. Dualidad       │ 2. Modularidad    │ 3. Zonificación                │
│    Micro / Macro  │    Blueprints     │    y Logística                 │
│ (1ra Pers. vs     │ (Plantillas       │ (Zonas A/B, redes              │
│  Cámara Cenital)  │  validadas)       │  viales y ductos)              │
├───────────────────┴───────────────────┴────────────────────────────────┤
│ 4. Economía Orgánica y Demográfica   │ 5. Soberanía Portátil en MP    │
│    (Moral continua, metabolismo)     │    (Núcleos balanceados)       │
└──────────────────────────────────────┴────────────────────────────────┘
```

1. **Dualidad de Perspectiva (Micro vs. Macro):** Alternancia en tiempo real (tecla <kbd>C</kbd>, vuelo de `0,6 s`) entre la acción visceral en primera persona (minería, construcción manual, defensa directa) y la vista aérea táctica (planificación urbana, asignación de cuadrillas, trazado de vías).
2. **Modularidad y Automatización por Plantillas (*Blueprints*):** El jugador diseña libremente sus edificios; `BlueprintValidator.gd` verifica su hermeticidad y accesos (<kbd>B</kbd> para declarar, <kbd>Shift</kbd> + <kbd>B</kbd> para remodelar sin demoler), permitiendo guardar hasta 5 diseños persistentes construibles por cuadrillas de colonos.
3. **Zonificación Estratégica y Logística Integral:** Separación estricta entre **Zona A** (residencial, cívica y académica), **Zona B** (industrial, logística y energética) y **Periferia** (extracción y bombeo) conectadas por caminos de tierra pisada y canalizaciones aéreas en **`Y + 4`** (con pasos elevados en **`Y + 6`** al cruzar otro conducto).
4. **Economía Orgánica y Demográfica:** Cada colono consume nutrientes según la exigencia de su rol (`1` a `5 comida/h`), ocupa camas reales según su estrato (`x_cama`), asciende en escuelas de cohorte y responde a la moral cívica (`0` a `100`).
5. **Soberanía Portátil y Núcleos Balanceados en Multijugador:** Exportación del Núcleo Urbano y catálogo de *blueprints* hacia mundos multijugador competitivos.

![Red planetaria y soberanía portátil de núcleos urbanos](/assets/concept-planet-network.webp)

---

## 3. Novedades Consolidadas en GDD v3.57 – v3.59

- **Iconografía Vectorial HUD (`IconosHUD.gd`) y Miniaturas 3D (`MiniaturaRenderer.gd`):** Catálogo centralizado de **más de 90 iconos SVG pixel-art** (`shape-rendering="crispEdges"`), botones de construcción ampliados a `104×76 px` con insignias en 3 esquinas (insumos a la izquierda, rayo eléctrico al centro, producto a la derecha) y miniaturas 3D renderizadas en vivo.
- **Red Eléctrica en kW / MW (`BarraSuperior.gd`, `VentanaEnergia.gd`):** Indicador interactivo de rayo tricolor (dorado = superávit, gris = sin demanda, rojo = déficit) con desglose detallado de generación y consumo por instalación.
- **Moral Diaria y Migración Mensual Escalonada (`Ciudad.gd`):** Tasa de cambio diaria aplicada por fracción horaria (`tasa_cambio_moral / 24,0`) y tabla escalonada de migración mensual de **9 tramos** (`-5` a `+5 colonos/mes`), donde la inmigración entre `Moral 20` y `50` exige camas libres y por encima de `50` rebalsa hacia `sin_techo`.
- **Centralización Integral de Ajustes y Textos Reactivos (`ajustes.gd` y `strings.gd`):** Desacoplamiento total de números mágicos y constantes de balance económico, demográfico, de moral y construcción en `godot/scripts/ajustes.gd`, admitiendo manipulación en caliente para perfiles por partida («Nueva partida») y opciones globales. En paralelo, `godot/scripts/strings.gd` centraliza textos con soporte multi-idioma nativo (`Ajustes.idioma`) y getters estáticos reactivos que leen variables de `Ajustes.*` en tiempo de ejecución.
- **Calibración de la Curva de Migración Mensual Escalonada (`Ajustes.CIUDAD_TRAMOS_MIGRACION`):** Tabla de 9 tramos con ajuste del tramo de moral 75 a `+3.0/mes`, impulso de inmigración (*boost*) multiplicador `2.5×` durante 30 días simulados y fuga de cerebros jerárquica en moral crítica (`< 20`).
- **16 Correcciones de QA y Validación en Vivo:** Bloqueo de auto-colocación en la celda del propio avatar, prevención de clics sostenidos encadenados tras finalizar una construcción, correcciones de botones HUD (formato MW, icono de moral) y eliminación de advertencias `SHADOWED_GLOBAL_IDENTIFIER` en Godot.
- **Evolución Orgánica de Eras (IDU I–IV), Balanza de Doctrinas e Investigación Descentralizada en 2 Capas (v3.59):** El progreso tecnológico avanza orgánicamente mediante el **Índice de Desarrollo Urbano (IDU)** (`Sofisticación` + `Cualificación` + `Conocimiento`). En la barra superior se muestran el nombre e ícono de la Era junto a la insignia en número romano del IDU (`romano_1.svg`..`romano_4.svg`), que al hacer hover despliega una ventana tooltip adherida a la esquina superior derecha. La **Capa 1 (Ciencia Teórica)** se investiga en la Universidad y habilita la **Capa 2 (Aplicaciones Prácticas)** en cada edificio o en el Núcleo Urbano, ejecutadas físicamente por un **Investigador Itinerante**.
- **Logística de Unidades de Transporte, Nueva Refinería «Vidriera» (`vidrio`) y Paneles de Ventana 1/20 (v3.59):** Se incorpora el **Taller de Transporte (`taller_transporte`)** con 6 unidades móviles (`acarreador_pie`, `carreta_mano`, `carro_caballos`, `camion_diesel`, `dron_carga`, `trolebus_solar`), restricción vial estricta y arrastre lento (`1,2 m/s`). La nueva refinería **Vidriera (`1-3-5`)** produce **`Vidrio`** (`1 Tierra + 1 Carbón → 3 Vidrio`), consumido de forma exclusiva en cabinas de vehículos y de forma prioritaria en bloques de ventana (`1 Vidrio` o `3 Tierra`). Los bloques de ventana pasan a ser **paneles transparentes de 1/20 de espesor (0,05 m)** en tres variantes automáticas: `ventana` recta a media profundidad orientada al avatar, `ventana_esquina` en L rotada 90° en Y, y `ventana_techo` al colocar mirando arriba/abajo (al ras de la cara superior Y ∈ [0,95, 1,0]).
- **Almacén Jerárquico, Reservas Porcentuales y Mejoras de Construcción (v3.59):** `VentanaAlmacen.gd` agrupa materias primas A–Z con desplegables para sus productos refinados y las 6 categorías de comida, más botón *"Expandir todo / Contraer todo"*; reservas centrales porcentuales (`0%..50%`) y prioridades de obra con botones subir/bajar (`btn_subir.svg`/`btn_bajar.svg`); transición automática de ventana al terminar obras; y **drenaje automático de agua interior** al completar construcciones.
- **Cobertura de Verificación Continua:** **28 escenas de prueba automatizadas** pasando al **100 % en verde**.

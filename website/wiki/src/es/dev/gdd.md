# Pilares de Diseño y GDD (v3.57)

El **Documento de Diseño de Juego (GDD)** de **Craft to Nation** establece las directrices conceptuales, sistémicas y matemáticas que rigen el proyecto. Esta página resume los pilares centrales, el marco evolutivo de eras tecnológicas, el ciclo de juego (*game loop*) y las especificaciones vigentes de la versión **v3.57**.

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
2. **Modularidad y Automatización por Plantillas (*Blueprints*):** El jugador diseña libremente sus edificios; `ValidadorEdificios.gd` verifica su hermeticidad y accesos (<kbd>B</kbd> para declarar, <kbd>Shift</kbd> + <kbd>B</kbd> para remodelar sin demoler), permitiendo guardar hasta 5 diseños persistentes construibles por cuadrillas de colonos.
3. **Zonificación Estratégica y Logística Integral:** Separación estricta entre **Zona A** (residencial, cívica y académica), **Zona B** (industrial y energética) y **Periferia** (extracción y bombeo) conectadas por caminos de tierra pisada y canalizaciones aéreas en `Y + 6`.
4. **Economía Orgánica y Demográfica:** Cada colono consume nutrientes según la exigencia de su rol (`1` a `5 comida/h`), ocupa camas reales según su estrato (`x_cama`), asciende en escuelas de cohorte y responde a la moral cívica (`0` a `100`).
5. **Soberanía Portátil y Núcleos Balanceados en Multijugador:** Exportación del Núcleo Urbano y catálogo de *blueprints* hacia mundos multijugador competitivos.

![Red planetaria y soberanía portátil de núcleos urbanos](/assets/concept-planet-network.webp)

---

## 3. Novedades Consolidadas en GDD v3.56 – v3.57

- **Iconografía Vectorial HUD (`IconosHUD.gd`) y Miniaturas 3D (`MiniaturaRenderer.gd`):** Catálogo centralizado de **más de 90 iconos SVG pixel-art** (`shape-rendering="crispEdges"`), botones de construcción ampliados a `104×76 px` con insignias en 3 esquinas (insumos a la izquierda, rayo eléctrico al centro, producto a la derecha) y miniaturas 3D renderizadas en vivo.
- **Red Eléctrica en kW / MW (`BarraSuperior.gd`, `VentanaEnergia.gd`):** Indicador interactivo de rayo tricolor (dorado = superávit, gris = sin demanda, rojo = déficit) con desglose detallado de generación y consumo por instalación.
- **Moral Diaria y Migración Mensual Escalonada (`Ciudad.gd`):** Tasa de cambio diaria aplicada por fracción horaria (`tasa_cambio_moral / 24,0`) y tabla escalonada de migración mensual de **9 tramos** (`-5` a `+5 colonos/mes`), donde la inmigración entre `Moral 20` y `50` exige camas libres y por encima de `50` rebalsa hacia `sin_techo`.
- **Cobertura de Verificación Continua:** **28 escenas de prueba automatizadas** pasando al **100 % en verde**.

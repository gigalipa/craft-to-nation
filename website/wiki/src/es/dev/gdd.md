# Pilares de Diseño y GDD (v3.57)

El **Documento de Diseño de Juego (GDD)** de *Craft to Nation* establece las directrices conceptuales, sistémicas y matemáticas que rigen el proyecto. Esta página resume los pilares centrales, el ciclo de juego (*game loop*) y las especificaciones vigentes de la versión **v3.57**.

---

## 1. Visión y Eslogan

> **Eslogan Oficial:** *From first block to living nation.* / *Del primer bloque a una nación viva.*  
> **Frase de Campaña:** *Survive. Craft. Automate. Lead.*  
> **Género Híbrido:** City Builder, Supervivencia en Primera Persona, Estrategia en Tiempo Real (RTS), Gestión y Logística de Fábricas.  
> **Inspiraciones Clave:** *SimCity, Age of Empires, Minecraft, Mindustry.*

*Craft to Nation* fusiona la inmersión íntima y visceral de la supervivencia en primera persona con la visión estratégica de un simulador urbano a escala continental. El jugador evoluciona desde un avatar solitario que recolecta madera y bayas a mano hasta el líder de un imperio industrial automatizado y fortificado.

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

1. **Dualidad de Perspectiva (Micro vs. Macro):** Capacidad de alternar fluidamente y en tiempo real entre la acción visceral en primera persona (intervención manual, minería, combate codo a codo) y la vista aérea táctica (planificación urbana, emisión de órdenes colectivas, tendido de carreteras).
2. **Modularidad y Automatización por Plantillas (Blueprints):** Superación del desgaste repetitivo de la colocación bloque a bloque. El jugador diseña sus propios edificios libremente; el motor valida su hermeticidad y accesos, permitiendo guardarlos como plantillas reutilizables que los colonos construyen autónomamente.
3. **Zonificación Estratégica y Logística Integral:** Estructuración del territorio en zonas residenciales/científicas (Zona A), polígonos industriales/militares (Zona B) y puestos remotos periféricos conectados mediante vías de tierra pisada, canalizaciones aéreas y tuberías de subsuelo.
4. **Economía Orgánica y Demográfica:** La población civil no es un número abstracto: cada colono consume nutrientes según la exigencia física de su rol, vive en una residencia real y modula su productividad de acuerdo con su moral.
5. **Soberanía Portátil y Núcleos Balanceados en Multijugador:** Los jugadores pueden transportar su núcleo urbano central y catálogo de blueprints a mundos procedurales multijugador competitivos, donde los trofeos ganados en combate potencian la moral ciudadana en su mundo de origen.

---

## 3. Fases de Progresión y Game Loop

El progreso de la civilización avanza a través de cuatro fases orgánicas interconectadas:

### Fase 1: Génesis y Supervivencia (1ra Persona)
El avatar aparece en un bioma procedural virgen. Debe recolectar alimentos silvestres para saciar su gasto calórico basal (5 u/h), talar madera, picar piedra superficial y construir su primer refugio hermético. Al formalizar este edificio como **Núcleo Urbano**, se activa el radio de influencia cívica y se duplica la capacidad del inventario central.

### Fase 2: Asentamiento y Fundación Urbana
Se habilita la cámara cenital libre (*Modo City Builder*). Al construir el primer edificio residencial con camas habitables, comienzan a llegar los primeros colonos inmigrantes. El jugador asigna oficios primarios y organiza los primeros servicios cívicos.

### Fase 3: Zonificación, Logística e Industrialización
Delimitación de distritos especializados dentro del área de influencia:
- **Zona A:** Residencias, escuelas técnicas y universidades.
- **Zona B:** Siderúrgicas, fábricas de bloques, refinerías de crudo y centrales termoeléctricas.
- **Periferia:** Puestos remotos de extracción conectadas por acarreadores terrestres y redes de acueductos y tuberías.

### Fase 4: Expansión Bélica y Multijugador
Manufactura en serie de pertrechos militares, reclutamiento en cuarteles, asedio a fortalezas enemigas de la IA y batallas multijugador.

---

## 4. Innovaciones Sistémicas de la Versión v3.56

La actualización **v3.56** consolida mecánicas cívicas clave antes del despliegue de la Fase 4:

- **Sistema de Moral Dinámica Continua [0 a 100]:** La moral parte en 75.0 (optimismo pionero) y converge hacia 50.0 con inercia horaria (`0.02`). Se modula por superávit (+0.4/h), diversidad de dieta (+0.5/h), hambruna (-3.0/h) y hacinamiento (-0.05/h por sin techo).
- **Ley de Productividad Continua:** Curva exponencial `X = 0.5 × 2^(Y / 50)` donde la moral ajusta directamente las tasas de extracción y refinamiento entre **0.5×** y **2.0×**.
- **Ventana de Tolerancia Cívica:** Ampliación a 72 horas (3 días) antes de que un colono sin techo abandone la ciudad al exilio. Los desempleados disponen de 10 días (240 horas) para encontrar oficio.
- **Estado Técnico de Verificación:** Cobertura de pruebas automatizadas al **100% en verde en 28 escenas de prueba independientes**.

---
title: "Gestión Demográfica y Colonos"
description: "Sistema de moral dinámica [0-100], productividad laboral continua X=0.5*2^(Y/50), asignación de oficios, buffers de vivienda y prevención de fuga de cerebros."
---

# Gestión Demográfica y Colonos

En *Craft to Nation*, los colonos no son meros autómatas decorativos: constituyen la fuerza viva, productiva y cívica de tu nación. Cada habitante posee necesidades biológicas, una especialización laboral, un estado de alojamiento y un nivel de moral que influye de forma directa en su productividad.

---

## 1. Calculadora de Consumo y Producción

Utiliza la siguiente herramienta interactiva para estimar la demanda metabólica de tu colonia por ciclo estándar y los puestos mínimos de recolección necesarios para evitar crisis alimentarias:

<ClientOnly>
  <ProductionCalculator />
</ClientOnly>

---

## 2. Tipos de Población y Especialización Laboral

La demografía de la colonia se organiza en una jerarquía de oficios. Los colonos adquieren formación técnica mediante edificios educativos especializados en la **Zona A**:

| Tipo de Población | Gasto Comida (u/h) | Gasto Combustible (u/h) | Gasto Energía (u/h) | Capacidad x Cama | Rol Principal en la Colonia |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Ciudadano** | 2 | 0 | 0 | 5 | Población civil base, dinamiza la vida comunitaria y actividades comerciales. |
| **Desempleado** | 3 | 0 | 0 | 4 | Reserva de mano de obra. Asiste en acarreo ligero y obras de construcción. |
| **Obrero** | 5 | 0 | 0 | 4 | Trabajo físico pesado en puestos de tala, canteras y minería básica. |
| **Técnico** | 3 | 0 | 0 | 3 | Operador de industrias de Zona B (`1 → 3`), estaciones de bombeo, centros de extracción y puestos de Nivel II. |
| **Especialista** | 2 | 0 | 1 | 2 | Requisito para elevar puestos periféricos a Nivel III y dotar de Investigadores a la Universidad. |
| **Investigador** | 1 | 0 | 2 | 1 | Generación de puntos de ciencia y patentes en la Universidad (`1,0 h_inv/h`). |
| **Militar** | 4 | 2 | 0 | 3 | Defensa de guarnición, patrullaje de fronteras y asedio en Fase 4. |

### Cadenas de Promoción, Orden de Desbloqueo y Gestión (`Ciudad.gd` / `VentanaPoblacion.gd` / `VentanaOcupaciones.gd`)
1. **Inmigrantes / Ciudadanos Libres:** Llegan atraídos por la moral de la ciudad y la disponibilidad de camas libres en la Zona A.
2. **Orden Estricto de Desbloqueo Académico (`1 → 4`):** Las instituciones de investigación se habilitan secuencialmente: construir la **Escuela Técnica** desbloquea la **Escuela de Especialistas**, y completar esta última desbloquea la **Universidad**.
3. **Escuela Técnica (`escuela_tecnica`):** Entrena una cohorte de **4 Obreros** (1 cama) durante **24 horas de juego** para graduar **3 Técnicos** (1 cama), habilitando la operación de industrias de Zona B, estaciones de bombeo/extracción y mejoras de puestos a Nivel II.
4. **Escuela de Especialistas (`escuela_especialistas`):** Entrena una cohorte de **3 Técnicos** (1 cama) durante **48 horas de juego** para graduar **2 Especialistas** (1 cama), habilitando puestos periféricos de Nivel III y la dotación académica de la Universidad.
5. **Cancelación de Cursos con Reembolso del 100 %:** En el panel contextual de las escuelas (<kbd>E</kbd> en 1.ª persona o clic izquierdo en vista cenital), puedes cancelar un curso en marcha antes de su graduación, reembolsando el **100 % de los recursos y alumnos** al almacén y censo municipal.
6. **Universidad e Investigación en 2 Capas (`universidad`):** Emplea hasta **3 Investigadores** (`1,0 hora_investigador/h` cada uno) para desarrollar ciencia teórica en la Universidad (**Capa 1**) y enviar un **Investigador Itinerante** que camina físicamente hasta los edificios productivos o el Núcleo Urbano para completar las aplicaciones prácticas *in situ* (**Capa 2**).
7. **Ventanas de Población (<kbd>P</kbd>) y Ocupaciones (<kbd>O</kbd>):** Permiten asignar o retirar trabajadores con controles `[-]` / `[+]` organizados en categorías desplegables (`▼ Recolección`, `▼ Industria`, `▼ Investigación`, `▼ Energía`).

---

## 3. Sistema de Moral Dinámica (GDD v3.59)

El estado anímico colectivo de la colonia se cuantifica en una escala continua de **0 a 100 puntos** (consultable en la barra superior o presionando <kbd>M</kbd> para abrir `VentanaMoral.gd`, donde el estado de migración se muestra directamente en la línea inferior bajo la productividad laboral):
- **Inicio de Partida:** La colonia inicia con una moral de **75,0** (bono pionero de optimismo).
- **Inercia Natural:** La moral converge progresivamente hacia el punto neutro de **50,0** con un factor de inercia de **0,02**.
- **Aplicación Diaria (`tasa_cambio_moral / 24.0`):** En `Ciudad.gd`, la suma neta de modificadores conforma la **tasa de cambio diaria** (`ΔM / día`), que se aplica en fracciones de `ΔM / 24,0` en cada tick horario (`2,0 s` reales).

### Factores de Modificación Diaria (`tasa_cambio_moral`)
- **Superávit de Bienes y Alimentos:** `+0,4` puntos / día (cuando los recursos superan el 50 % de capacidad).
- **Diversidad de Dieta (6 Categorías de Comida):** Hasta `+0,5` puntos / día según la variedad de categorías alimentarias disponibles en el almacén (`Frutos silvestres`, `Carne de caza`, `Pescado y algas`, `Cultivos agrícolas`, `Panadería y granos`, `Conservas industriales`).
- **Escasez Alimentaria:** `-0,6` puntos / día cuando el stock cae por debajo del umbral de seguridad (`< 20 %`).
- **Hambruna Crítica:** `-3,0` puntos / día cuando el almacén de comida se vacía por completo (`0 u`).
- **Déficit Energético:** Hasta `-1,5` puntos / día proporcional al déficit de la red eléctrica.
- **Colonos Sin Techo:** `-0,05` puntos / día por cada colono que pernocte a la intemperie.
- **Memoria de Peligro:** Buffer rodante de `168 horas` (`7 días` de juego) que penaliza muertes e incursiones recientes.

---

## 4. Productividad Continua y Tabla de Migración Mensual Escalonada

La moral modula la productividad laboral según la curva exponencial continua (`Ciudad.calcular_multiplicador_productividad()`):

```text
Productividad = 0.5 × 2^(Moral / 50)
```
- **Moral = 0:** Rendimiento mínimo al **0,5×** (`😡` Crítica, `< 20 %`).
- **Moral = 20 – 35:** Rendimiento reducido (`🙁` Baja, `20 % – 35 %`).
- **Moral = 50 (Neutro):** Rendimiento estándar al **1,0×** (`😐` Neutra, `35 % – 65 %`).
- **Moral = 100 (Euforia):** Rendimiento duplicado al **2,0×** (`🙂` Alta, `>= 65 %`).

### Regímenes y Tramos Escalonados de Migración Mensual (`Ciudad.calcular_tasa_migracion_mensual()`)
Un mes de simulación equivale a `720 horas` de juego (`30 días × 24 h`). En `VentanaMoral.gd` (<kbd>M</kbd>) se sintetizan tres regímenes migratorios principales (**`<= 20 %` `⚠ Éxodo de cerebros`**, **`20 % – 50 %` `Inmigración con camas`** y **`> 50 %` `Inmigración masiva`**), desglosados internamente en 9 tramos escalonados:

| Tramo de Moral | Tasa Mensual (`colonos / mes`) | Régimen Migratorio en `Ciudad.gd` |
| :--- | :--- | :--- |
| **`0,0 – 5,0`** | **-5,0 / mes** | **Éxodo severo** (fuga jerárquica de cerebros) |
| **`5,0 – 10,0`** | **-3,0 / mes** | **Éxodo alto** |
| **`10,0 – 15,0`** | **-2,0 / mes** | **Éxodo moderado** |
| **`15,0 – 20,0`** | **-1,0 / mes** | **Éxodo leve** |
| **`20,0 – 25,0`** | **+1,0 / mes** | **Inmigración prudente** (*solo ingresa si existen camas colonizables libres*) |
| **`25,0 – 35,0`** | **+2,0 / mes** | **Inmigración moderada** (*solo ingresa si existen camas colonizables libres*) |
| **`35,0 – 50,0`** | **+3,0 / mes** | **Inmigración sostenida** (*solo ingresa si existen camas colonizables libres; no genera sin techo*) |
| **`50,0 – 75,0`** | **+3,0 / mes** | **Inmigración masiva** (*llena camas libres y rebalsa como `sin_techo` si existe Núcleo Urbano*) |
| **`75,0 – 100,0`** | **+5,0 / mes** | **Auge migratorio** (*llena camas libres y rebalsa como `sin_techo` si existe Núcleo Urbano*) |

---

## 5. Inanición, Colonos Sin Techo y Éxodo Poblacional

### Colonos Sin Techo (`sin_techo`)
Cuando la moral supera `50,0` y la inmigración rebalsa las camas disponibles (o si un edificio es demolido), los colonos sin cama entran al estado **Sin Techo**. Consumen `3,0 comida/h`, no pueden ocupar puestos especializados y disponen de una **tolerancia máxima de 72 horas de juego (3 días)** antes de emigrar definitivamente, aplicando una penalización directa de **-10 puntos de moral**.

### Desempleo Prolongado (`240 h`)
Los colonos en estado **Desempleado** (`desempleado`) esperan hasta **240 horas de juego (10 días)**. Si no consiguen empleo ni son asignados a obras o escuelas en ese plazo, emigran de la ciudad.

### Crisis de Inanición
Si el stock municipal de comida llega a `0`, ocurre una mortandad por hambre de hasta el **25 % de la población total por cada tick de simulación (`2,0 s`)**, siguiendo la jerarquía de vulnerabilidad física:

```text
Militar → Obrero → Técnico → Especialista → Investigador → Desempleado → Ciudadano
```

### Éxodo y Fuga de Cerebros (`Moral <= 20`)
Cuando la moral cae a `20,0` o menos, el acumulador migratorio se vuelve negativo y los colonos más cualificados abandonan primero la ciudad:

```text
Investigador → Especialista → Técnico → Militar → Obrero → Desempleado → Ciudadano
```


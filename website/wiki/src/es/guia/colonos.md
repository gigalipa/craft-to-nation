# Gestión Demográfica y Colonos

En *Craft to Nation*, los colonos no son meros autómatas decorativos: constituyen la fuerza viva, productiva y cívica de tu nación. Cada habitante posee necesidades biológicas, una especialización laboral, un estado de alojamiento y un nivel de moral que influye de forma directa en su productividad.

---

## 1. Calculadora de Consumo y Producción

Utiliza la siguiente herramienta interactiva para estimar la demanda metabólica de tu colonia por ciclo estándar y los puestos mínimos de recolección necesarios para evitar crisis alimentarias:

<ProductionCalculator />

---

## 2. Tipos de Población y Especialización Laboral

La demografía de la colonia se organiza en una jerarquía de oficios. Los colonos adquieren formación técnica mediante edificios educativos especializados en la **Zona A**:

| Tipo de Población | Gasto Comida (u/h) | Gasto Combustible (u/h) | Gasto Energía (u/h) | Capacidad x Cama | Rol Principal en la Colonia |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Ciudadano** | 2 | 0 | 0 | 5 | Población civil base, dinamiza la vida comunitaria y actividades comerciales. |
| **Desempleado** | 3 | 0 | 0 | 4 | Reserva de mano de obra. Asiste en acarreo ligero y obras de construcción. |
| **Obrero** | 5 | 0 | 0 | 4 | Trabajo físico pesado en puestos de tala, canteras y minería básica. |
| **Técnico** | 3 | 0 | 0 | 3 | Operador de refinerías intermedias (siderúrgicas, aserraderos mecánicos). |
| **Especialista** | 2 | 0 | 1 | 2 | Manejo de petroquímica, reactores térmicos y circuitos avanzados. |
| **Investigador** | 1 | 0 | 2 | 1 | Generación de puntos de ciencia y patentes en la Universidad. |
| **Militar** | 4 | 2 | 0 | 3 | Defensa de guarnición, patrullaje de fronteras y asedio en Fase 4. |

### Cadenas de Promoción y Capacitación
1. **Inmigrantes / Ciudadanos Libres:** Llegan atraídos por la disponibilidad de viviendas y camas libres en la Zona A.
2. **Escuela Técnica:** Capacita a obreros con experiencia para transformarlos en **Técnicos**, habilitando el funcionamiento de industrias Tipo 2.
3. **Escuela de Especialistas:** Instruye a técnicos en procesos petroquímicos complejos y manejo de fluidos industriales.
4. **Universidad:** Centro de investigación superior donde los **Investigadores** desbloquean tecnologías del árbol científico (Metalurgia Aplicada, Automatización Industrial).

---

## 3. Sistema de Moral Dinámica (GDD v3.56)

El estado anímico colectivo de la colonia se cuantifica en una escala continua de **0 a 100 puntos**:
- **Inicio de Partida:** La colonia inicia con una moral de **75.0** (bono pionero de optimismo).
- **Inercia Natural:** La moral converge progresivamente hacia el punto neutro de **50.0** con un factor de inercia de $0.02$.

### Factores de Modificación Horaria ($\Delta M$)
- **Superávit de Bienes y Alimentos:** $+0.4$ puntos / hora.
- **Diversidad de Dieta:** Hasta $+0.5$ puntos / hora al combinar caza, pesca, frutos silvestres y productos procesados.
- **Escasez Alimentaria:** $-0.6$ puntos / hora.
- **Hambruna Crítica:** $-3.0$ puntos / hora cuando el almacén de comida se vacía por completo.
- **Déficit Energético:** Hasta $-1.5$ puntos / hora si los generadores eléctricos no cubren la demanda.
- **Colonos Sin Techo:** $-0.05$ puntos / hora por cada colono que pernocte a la intemperie.

---

## 4. Productividad Continua y Ley de Rendimiento

A diferencia de modelos escalonados rígidos, en *Craft to Nation* la moral modula la productividad laboral según una curva matemática exponencial continua:

$$\text{Productividad} = 0.5 \times 2^{\left(\frac{\text{Moral}}{50}\right)}$$

- Con **Moral = 0**: Los trabajadores rinden a un **$0.5\times$** (la mitad de su tasa base).
- Con **Moral = 50** (Neutro): Rendimiento normal al **$1.0\times$**.
- Con **Moral = 100** (Euforia cívica): Rendimiento duplicado al **$2.0\times$**.

---

## 5. Inanición, Colonos Sin Techo y Éxodo Poblacional

El descuido en la planificación urbana desencadena consecuencias severas:

### Colonos Sin Techo
Cuando la inmigración supera la cantidad de camas construidas, los recién llegados adquieren el estado "Sin Techo". Consumen alimento al ritmo de un desempleado, no pueden asumir puestos laborales fijos y disponen de una **tolerancia máxima de 72 horas de juego (3 días)** antes de marcharse al exilio, penalizando la moral de la ciudad en $-10$ puntos.

### Crisis de Inanición
Si el stock municipal de comida se agota, ocurre una mortandad por hambre de hasta el **25% de la población total por cada tick de simulación (2 segundos)**. La pérdida de vidas sigue una jerarquía estricta de mayor a menor vulnerabilidad física:
$$\text{Militar} \longrightarrow \text{Obrero} \longrightarrow \text{Técnico} \longrightarrow \text{Especialista} \longrightarrow \text{Investigador} \longrightarrow \text{Desempleado} \longrightarrow \text{Ciudadano}$$

### Éxodo y Fuga de Cerebros
Si la moral desciende por debajo del umbral crítico de **20 puntos**, se desata una fuga de cerebros jerárquica: los investigadores y especialistas serán los primeros en abandonar la ciudad, seguidos por técnicos y obreros cualificados.

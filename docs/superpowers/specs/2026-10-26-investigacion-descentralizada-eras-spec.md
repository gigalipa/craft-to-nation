# Especificación Técnica: Investigación Descentralizada, Pacing de Eras y Reconversión Doctrinal

**Estado:** Aprobado para implementación  
**Fecha:** 2026-10-26  
**Módulos Afectados:** `godot/scripts/ajustes.gd`, `godot/scripts/Ciudad.gd`, `godot/scripts/Colonos.gd`, `godot/scripts/BuscadorRutas.gd`, `godot/scripts/PanelPuesto.gd`, `godot/scripts/PanelEdificio.gd`, `godot/scripts/UI/TemaHUD.gd`.

---

## 1. Resumen Ejecutivo y Filosofía del Sistema

Este documento formaliza la arquitectura de avance tecnológico y especialización cultural para *Craft to Nation*:

1. **Evolución Orgánica sin Botón de Avance:** Las Eras (1 a 4) transicionan automáticamente cuando el **Índice de Desarrollo Urbano ($IDU$)** cruza los umbrales establecidos, combinando sofisticación de edificios, cualificación laboral y masa crítica de conocimientos.
2. **Investigación en Dos Capas:**
   - **Capa 1 (Ciencia Básica):** Teórica, neutral y centralizada en la **Universidad**. Genera puntos de investigación teórica que desbloquean ramas conceptuales.
   - **Capa 2 (Aplicaciones Prácticas):** Se contrata in-situ en el edificio diana (fábricas, puestos, redes de transporte o Núcleo Urbano). Emplea la mecánica del **Investigador Itinerante**, quien se desplaza físicamente por la red vial.
3. **Comisiones Científicas Escalonadas:**
   - *Era 2:* 1 Investigador Itinerante por proyecto.
   - *Era 3:* 2 Investigadores Itinerantes simultáneos.
   - *Era 4:* Comisión de 3 Investigadores Itinerantes simultáneos.
4. **Reconversión Industrial sin Demolición:** Permite sustituir una mejora de una doctrina (ej. *Dieselpunk*) por otra (*Solarpunk*) pagando una tasa de reforma y despachando una comisión de reconversión in-situ.
5. **Balanza Doctrinal Tripartita ($D / C / S$):** El vector de identidad de la nación se actualiza dinámicamente según las aplicaciones prácticas instaladas, leyes vigentes y edificios activos.

---

## 2. Pacing y Fórmula del Índice de Desarrollo Urbano ($IDU$)

El avance de Era ocurre de forma emergente evaluando la siguiente función cada tick horario:

$$IDU = (0.40 \times S_{\text{edificios}}) + (0.35 \times Q_{\text{laboral}}) + (0.25 \times K_{\text{ciencia}})$$

Donde:
- **$S_{\text{edificios}}$ (Sofisticación de Infraestructura):** Escala de $[1.0, 4.0]$. Evalúa el ratio ponderado de instalaciones Tipo 1, Tipo 2, Tipo 3 y Tipo 4 activas.
- **$Q_{\text{laboral}}$ (Cualificación del Censo):**
  $$Q = \frac{\text{Obreros}\times 1.0 + \text{Técnicos}\times 2.0 + \text{Especialistas}\times 3.0 + \text{Investigadores}\times 3.5}{\text{Censo Total}}$$
  *(Normalizado sobre escala 1.0 a 4.0).*
- **$K_{\text{ciencia}}$ (Masa Crítica de Conocimiento):**
  $$K = 1.0 + \left(3.0 \times \frac{\text{Tecnologías Básicas y Aplicadas Descubiertas}}{\text{Total Tecnologías Disponibles de la Era}}\right)$$

### 2.1 Umbrales de Transición de Era

```gdscript
static var IDU_UMBRAL_ERA_2: float = 1.50   # Manufactura Temprana
static var IDU_UMBRAL_ERA_3: float = 2.50   # Industrialización Plena
static var IDU_UMBRAL_ERA_4: float = 3.50   # Doctrina Cúspide
```

---

## 3. Capa 1: Ciencia Básica en la Universidad

### 3.1 Mecánica de Generación de Conocimiento
- Los colonos asignados a la Universidad con rol `investigador` acumulan **Puntos de Investigación Teórica** (`puntos_ciencia`) por hora:
  $$\Delta_{\text{ciencia}} = \text{Investigadores Activos} \times 1.0 \times X_{\text{moral}} \times \text{Cobertura Eléctrica}$$
- Cada tecnología teórica tiene un costo fijo en `puntos_ciencia` y recursos de laboratorio (papel/tablas, instrumental de hierro/cobre).

### 3.2 Catálogo de Ciencias Básicas por Era

| Era | Tecnología Teórica | Coste en Puntos | Prerrequisito | Habilita en Capa 2 |
| :---: | :--- | :---: | :--- | :--- |
| **Era 2** | **Metalurgia de Hornos** | 100 pts | Era 1 | Inyección forzada en Siderúrgica, herramientas de acero. |
| **Era 2** | **Hidráulica de Canales** | 120 pts | Era 1 | Acueductos de piedra, bombas de pozo, riego en granjas. |
| **Era 2** | **Tracción Animal y Engranajes** | 150 pts | Granjas Ganaderas | Carretas y carruajes tirados por caballos, molinos. |
| **Era 3** | **Termodinámica y Vapor** | 300 pts | Metalurgia | Motores de vapor, calderas de alta presión, locomotoras. |
| **Era 3** | **Redes Eléctricas y Bobinado** | 350 pts | Hidráulica | Distribución eléctrica por vías, dinamos, hidroeléctricas. |
| **Era 3** | **Química de Hidrocarburos** | 400 pts | Termodinámica | Refinación de crudo fraccionado, sintéticos plásticos. |
| **Era 4** | **Automatización y Cibernética** | 800 pts | Redes Eléctricas | Control por relés, drones de carga, torretas automáticas (+Cyberpunk). |
| **Era 4** | **Combustión Pesada y Blindajes** | 800 pts | Química | Motores diésel de pistón masivo, tanques, artillería (+Dieselpunk). |
| **Era 4** | **Biotecnología y Fototermia** | 800 pts | Hidráulica / Química | Torres solares concentradoras, micorrizas agrícolas (+Solarpunk). |

---

## 4. Capa 2: Aplicaciones Prácticas y el Investigador Itinerante

### 4.1 Requisitos de Comisión Científica por Era
Cuando el jugador ordena una mejora práctica en un edificio:
- **Era 2:** Requiere **1 Investigador Itinerante**.
- **Era 3:** Requiere **2 Investigadores Itinerantes**.
- **Era 4:** Requiere **3 Investigadores Itinerantes** (Comisión Científica Plenaria).

### 4.2 Ciclo de Vida del Investigador Itinerante (`Colonos.gd` / `BuscadorRutas.gd`)

```
[Selección en Edificio] ──> [Reserva de Investigadores en Universidad más cercana]
                                                   │
                                                   ▼
                                     [Cambio a 'investigador_itinerante']
                                                   │
                                                   ▼
                                     [Desplazamiento por Red Vial (A*)]
                                 (Aprovecha bonos de velocidad: +35% / +60%)
                                                   │
                                                   ▼
                                     [Llegada de la Comisión Completa]
                                                   │
                                                   ▼
                                     [Ejecución in-situ del Proyecto]
                                   (Horas de desarrollo + consumo local)
                                                   │
                                                   ▼
                                     [Instalación Exitosa de la Mejora]
                                    (Se actualiza la Balanza D / C / S)
                                                   │
                                                   ▼
                                     [Retorno a pie a la Universidad]
```

#### Reglas de Desplazamiento:
1. El proyecto en el edificio receptor permanece en estado `ESPERANDO_PERSONAL` hasta que el último miembro de la comisión llegue a la casilla de servicio del edificio.
2. Los investigadores itinerantes usan el coste de paso ponderado estándar (3 en vía afirmada, 8 en campo traviesa). El trazado de carreteras pavimentadas reduce drásticamente el tiempo de inicio de proyectos.
3. Si un investigador itinerante muere en el trayecto (ataque de bandidos o fauna), el proyecto queda bloqueado hasta que la Universidad despache un reemplazo.

---

## 5. La Balanza Doctrinal ($D / C / S$) y Reglas de Exclusión

El perfil ideológico de la civilización se almacena como un vector de 3 componentes en `Ciudad.gd`:
$$\vec{B} = \{ \text{dieselpunk}: D, \; \text{cyberpunk}: C, \; \text{solarpunk}: S \}$$

### 5.1 Asignación de Pesos
Cada elemento en el mundo aporta puntos doctrinales a la balanza:
- **Mejoras Prácticas en Edificios:** $+10$ a $+20$ pts a la doctrina de la mejora.
- **Edificios Exclusivos:** $+15$ pts (ej. Central Térmica Diésel $+15 D$; Microrreactor Modular $+15 C$; Planta Geotérmica $+15 S$).
- **Leyes en el Núcleo Urbano:** $+25$ pts mientras la ley esté promulgada.

El porcentaje relativo se calcula normalizando sobre el total de puntos acumulados:
$$D\% = \frac{D}{D + C + S} \times 100\%$$

### 5.2 Umbrales de Efecto
- **$D\%, C\%, S\% < 40\%$:** *Doctrina Polivalente.* Sin sesgo.
- **$\ge 40\%$ en una rama:** *Inclinación Notable (Nivel 1).* Activa bonificaciones pasivas de rama.
- **$\ge 60\%$ en una rama:** *Doctrina Dominante (Nivel 2).* Desbloquea blueprints y unidades cúspide de Era 4 de esa rama, y condiciona la atmósfera/estética visual.

---

## 6. Mecánica de Reconversión Industrial

Para cambiar la especialización doctrinal de un edificio sin demolerlo:

### 6.1 Parámetros de la Reconversión
1. **Acción del Jugador:** En el panel del edificio, seleccionar *"Iniciar Reconversión Industrial"*.
2. **Tasa de Reforma:** Costo del $50\%$ de los materiales de la nueva mejora + $25\%$ del costo del edificio base.
3. **Comisión de Reconversión:**
   - Despacho obligatorio de la comisión científica correspondiente a la era del edificio.
   - Tiempo de ejecución in-situ: $1.5\times$ el tiempo de una mejora normal (incluye desmantelamiento técnico previo).
4. **Estado Operativo:** Durante el proceso, el edificio entra en estado `RECONVERSION` (produce al $25\%$ de su tasa base y cesa sus efectos doctrinales previos).
5. **Cierre de la Reconversión:**
   - Se restan los puntos de la doctrina anterior en la balanza global.
   - Se suman los puntos de la nueva doctrina.
   - El edificio reanuda su operación con los nuevos parámetros y consumos.

---

## 7. Criterios de Aceptación y Pruebas Unitarias

1. **Prueba de Pacing $IDU$:** Simular una ciudad con $S=1.8$, $Q=1.6$ y $K=1.2$. Verificar que el $IDU$ resultante active la transición a Era 2 automáticamente.
2. **Prueba de Despacho de Comisiones:** En Era 3, ordenar una mejora en la refinería petrolera; comprobar que salgan exactamente 2 investigadores de la Universidad y que el temporizador de obra no arranque hasta que ambos estén en la celda del edificio.
3. **Prueba de Bonificación Vial:** Medir el tiempo de llegada de un investigador por vía afirmada vs. terreno natural; verificar la reducción del tiempo en concordancia con el coste de paso de `BuscadorRutas.gd`.
4. **Prueba de Reconversión:** Reconvertir una central termoeléctrica con mejora Dieselpunk ($+15 D$) a Solarpunk ($+15 S$); verificar que el vector doctrinal de la ciudad descuente los $15 D$ y sume los $15 S$.
5. **Prueba de Exclusión en Edificios:** Verificar que instalar una mejora con flag `excluye: ["caldera_diesel", "ciclo_solarpunk"]` bloquee las opciones incompatibles en el panel del edificio.

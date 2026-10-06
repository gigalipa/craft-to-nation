# Propuesta de Diseño Técnico: Remodelación de Edificaciones y Sistema de Colonizabilidad

**Fecha:** 2026-10-06  
**Objetivo:** Permitir la modificación ("remodelación") de edificios previamente declarados sin necesidad de demolerlos en su totalidad, gestionando la reubicación cívica, el estado temporal de "sin techo" y el control de "colonizabilidad" mediante buffers y contadores de 24 horas del juego.

---

## 1. Mecánica de Remodelación ("Desdeclaración" / Edición)

### 1.1 Concepto y Objetivo
Actualmente, los edificios declarados protegen sus bloques de ser minados o alterados directamente (`registrar_edificio()` / inmunidad al minado). Para modificar una estructura existente, el jugador debía deconstruir el edificio completo.
La **Remodelación** convierte un edificio registrado nuevamente en un conjunto de bloques libres ordinarios, permitiendo al jugador minar, añadir y reconfigurar la estructura a voluntad antes de volver a validarla con la herramienta de declaración.

### 1.2 Métodos de Activación
- **En Vista Cenital:** A través del panel de interacción del edificio (`PanelEdificio`), mediante un botón explícito: **`[Iniciar Remodelación]`**.
- **En 1ª Persona:** Apuntando a la puerta principal del edificio registrado y pulsando la combinación de teclas **`Shift + B`** (simetría directa: `B` declara, `Shift + B` desdeclara).
- *(A futuro)*: Existirá una herramienta dedicada en la barra de herramientas cuando se introduzca el set de herramientas de recolección y construcción.

### 1.3 Excepción: El Núcleo Urbano
- El **Núcleo Urbano** no es un edificio habitable (no posee residentes ni camas asignadas).
- Por ende, **no requiere ningún proceso de reasignación poblacional** al ser remodelado.
- Su estructura debe permitir el crecimiento orgánico continuo para albergar pedestales, trofeos y expansiones cívicas.
- Al activar su remodelación, pasa inmediatamente al estado de edición libre sin penalizaciones demográficas.

### 1.4 Impacto en Residentes y Reubicación de Población (Opción A)
Al iniciar la remodelación de un edificio residencial con residentes asignados:
1. **Reubicación Automática Prioritaria (Camas Libres en Cualquier Edificio):**
   - El sistema busca camas libres en **cualquier otro edificio residencial válido**, **independientemente de su estado de "Colonizabilidad"**.
   - Los edificios en estado `Colonizable: NO` funcionan precisamente como **buffers habitables para ciudadanos ya existentes**, protegiendo la capacidad cívica sin verse invadidos por inmigración foránea.
   - Los residentes se transfieren automáticamente a esas camas disponibles.
2. **Estado "Sin Techo" (Exceso de Población):**
   - Si no hay suficientes camas libres en toda la ciudad (sumando edificios colonizables y buffers), los ciudadanos restantes pasan al estado temporal **"Sin Techo"**.
   - **Reglas del colono "Sin Techo":**
     - **Consumo:** Consumen comida con la misma tasa que un colono *desempleado* (3 unidades/tick o su equivalente de balance).
     - **Productividad:** **No pueden trabajar** en ninguna ocupación o puesto mientras carezcan de vivienda.
     - **Contador de Exilio / Migración (24h de juego):** Poseen un temporizador individual o grupal de **24 horas de tiempo de simulación**. Si trascurrido ese lapso no han sido reubicados en una cama válida, abandonan la ciudad (migración/pérdida de población) con una penalización temporal en la moral cívica.

---

## 2. Sistema de Colonizabilidad (Edificios Buffer)

### 2.1 Propósito y Diferenciación Clave
El estado de **"Colonizabilidad" controla exclusivamente el flujo de INMIGRACIÓN externa de nuevos colonos**, no el acceso de los ciudadanos locales:
- **`Colonizable: NO` (Modo Buffer):** Las camas de este edificio están **completamente disponibles para albergar a ciudadanos locales existentes** (reubicaciones por remodelación de otros edificios, traslados de núcleo o futuros eventos bélicos donde los edificios dañados dejen de ser habitables). Sin embargo, **ningún colono nuevo migrará a la ciudad para ocupar estas camas**.
- **`Colonizable: SÍ`:** El edificio se abre al flujo demográfico global: si hay camas libres, la ciudad puede atraer y recibir **nuevos colonos inmigrantes**.
- **Utilidad Estratégica:** Permite al jugador planificar crecimiento controlado, crear edificios de amortiguación ("buffers") ante remodelaciones, reasignaciones del Núcleo Urbano o contingencias militares futuras, evitando saturar la ciudad de nuevas bocas de forma involuntaria.

### 2.2 Reglas de Colonización
1. **Primer Edificio Residencial:**
   - Se registra automáticamente con el estado **`Colonizable: ACTIVO`** (no requiere contador ni activación manual) para permitir el inicio fluido de la colonia y la llegada de los primeros habitantes.
2. **Edificios Residenciales Posteriores (2 en adelante):**
   - Se registran inicialmente con el estado **`Colonizable: INACTIVO`** (modo Buffer protegido contra inmigración).
   - Inician automáticamente una cuenta regresiva de **24 horas de tiempo de simulación** del juego.
   - Al expirar las 24 horas, el edificio transiciona de forma automática a `Colonizable: ACTIVO` (abriendo sus camas a nuevos colonos si aún no fueron ocupadas por ciudadanos locales).
3. **Control Manual en Ventana de Interacción:**
   - En la ventana del edificio (`PanelEdificio`), se expone:
     - **Estado de Colonización:** `[Colonizable: SÍ / NO]`
     - **Temporizador:** `Tiempo restante para apertura automática: XX:XX h` (visible mientras esté inactivo).
     - **Acción Manual:** Botón **`[Permitir Colonización]`** / **`[Pausar Colonización]`** que permite al jugador activar o pausar la llegada de nuevos colonos inmediatamente, saltándose o congelando el contador.

---

## 3. Flujo Completo del Jugador (Caso de Uso Típico)

```
[Paso 1] El jugador construye un nuevo edificio residencial (Edificio B).
         -> Estado inicial de B: "Colonizable: NO" (Buffer).
         -> No llegan nuevos colonos a ocupar B, pero sus camas están listas para la ciudad.
[Paso 2] El jugador apunta a la puerta principal del Edificio A (antiguo) y pulsa Shift+B (o "Iniciar Remodelación" en cenital).
         -> Edificio A se des-registra; sus bloques quedan liberados.
         -> Los residentes de A se mudan AUTOMÁTICAMENTE a las camas libres de B (pese a que B no sea colonizable por inmigrantes).
         -> Si la suma total de camas en la colonia no alcanzara, el excedente pasa a "Sin Techo" con un contador de 24h.
[Paso 3] El jugador mina paredes, agrega pisos, coloca ventanas y modifica el Edificio A libremente.
[Paso 4] El jugador usa la herramienta "Declarar Edificio" sobre A.
         -> El edificio supera la validación y vuelve a estar registrado.
         -> A nace inicialmente como "Colonizable: NO" (con contador 24h), y sus camas vuelven a estar disponibles para ciudadanos.
```

---

## 4. Requisitos de Implementación Técnica (Para el Agente de Desarrollo)

### 4.1 Backend / Dominio
- **`Ciudad.gd`:**
  - Estructura de datos para rastrear `sin_techo` (con `tiempo_sin_techo_acumulado` en ticks de simulación).
  - Tasa de consumo de `sin_techo` equiparada a `desempleado`.
  - Inhibición de asignación laboral a colonos `sin_techo`.
  - Exilio por migración al superar las 24h del juego en `_avanzar_tick()`.
  - Propiedad `colonizable: bool` y `tiempo_apertura_colonizacion: float` en el registro de cada edificio residencial.
- **`VoxelWorld.gd`:**
  - Método `desdeclarar_edificio(id_edificio: int)`:
    - Remueve la protección de celdas en `inmunidad_minado` / `edificio_por_celda`.
    - Limpia metadatos y listas de ocupación estructural sin destruir los bloques físicos en el GridMap.
- **`Player.gd`:**
  - Captura del atajo `Shift + B` apuntando a la puerta principal de un edificio registrado para invocar `iniciar_remodelacion()` (tal como `B` declara, `Shift + B` "desdeclara").
- **`PanelEdificio.gd` / HUD:**
  - Botón de `[Iniciar Remodelación]`.
  - Indicador de estado de colonizabilidad, temporizador de 24h y botón toggle de `[Permitir Colonización]`.

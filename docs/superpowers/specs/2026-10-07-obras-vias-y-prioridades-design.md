# Obras por Colonos: Tendido de Vías y Prioridades Configurables — Especificación de Diseño

**Fecha:** 2026-10-07  
**Estado:** Propuesta de Diseño para Aprobación  
**Paso del Roadmap:** Paso 8 de `docs/Pendientes y próximos pasos.md` (GDD Sección 4, 5 y 11)

---

## 1. Visión y Objetivos

1. **Tendido de Vías Físico y Asistido por Colonos:** Transformar la colocación instantánea de vías en una obra progresiva. Al confirmar un trazado en la vista cenital, se genera una obra de vía que colonos libres (obreros y técnicos) nivelan, acuñan y consolidan celda a celda.
2. **Sistema de Prioridades de Obras:** Permitir al jugador regular la urgencia de construcción de edificios de forma individual (Alta, Normal, Baja) e integrar una jerarquía general entre construcción de edificios, demolición y tendido vial.
3. **Intervención Manual en 1ª Persona:** Permitir al avatar acelerar la construcción de vías interactuando directamente a pie sobre el trazado fantasma.
4. **Herramienta Unificada de Demolición (Edificios y Vías):** Ampliar la herramienta de demolición cenital (tecla `3`) para detectar tanto edificios como vías. Al hacer clic en una vía, permite recorrerla con un trazado de demolición guiado en color naranja, confirmar con doble clic y retirar la vía preservando los bloques de nivelación.

---

## 2. Jerarquía y Modelo de Prioridades de Obras

### 2.1. Selector de Prioridad Individual en Edificios
- Cada edificio registrado o en construcción incluye en su ventana ([`PanelEdificio.gd`](file:///c:/Users/peraz/Projects/Misc/CityCraft/godot/scripts/PanelEdificio.gd)) un selector de prioridad con tres estados:
  - **Alta** (`prioridad = 2`)
  - **Normal** (`prioridad = 1`, valor predeterminado al emplazar)
  - **Baja** (`prioridad = 0`)
- El valor se almacena en el coordinador central ([`Obras.gd`](file:///c:/Users/peraz/Projects/Misc/CityCraft/godot/scripts/Obras.gd)).

### 2.2. Jerarquía General de Asignación de Colonos
Cuando un colono libre solicita su siguiente tarea (`Obras.siguiente_tarea`), las obras candidatas se evalúan bajo el siguiente orden estricto:

1. **Construcción de Edificios — Prioridad Alta**
2. **Construcción de Edificios — Prioridad Normal**
3. **Demoliciones** (tanto de edificios marcados como de vías marcadas para remoción)
4. **Tendido de Vías** (obras viales pendientes)
5. **Construcción de Edificios — Prioridad Baja**

### 2.3. Criterio de Desempate
Dentro del mismo nivel de la jerarquía anterior, el desempate entre dos obras se realiza por **orden cronológico de emplazamiento** (el ID de obra más antiguo tiene preferencia), garantizando un comportamiento determinista y predecible.

---

## 3. Sistema de Obras de Tendido de Vías

### 3.1. Creación de la Obra de Vía
- En la cámara cenital ([`CamaraCenital.gd`](file:///c:/Users/peraz/Projects/Misc/CityCraft/godot/scripts/CamaraCenital.gd)), al confirmar el trazado con doble clic:
  - Se ejecuta la validación de no colisión con puestos/edificios ([`ConstructorVias.validar_trazo`](file:///c:/Users/peraz/Projects/Misc/CityCraft/godot/scripts/ConstructorVias.gd)).
  - En lugar de ejecutar `ConstructorVias.construir` instantáneamente, se desglosa el trazado en su plan de celdas y cuñas necesarias y se registra como una **Obra de Vía** en `Obras.gd`.
  - La obra contiene la secuencia de celdas a nivelar, cuñas a colocar y soportes a registrar en [`Vias.gd`](file:///c:/Users/peraz/Projects/Misc/CityCraft/godot/scripts/Vias.gd).

### 3.2. Fusión de Tramos Contiguos
- Si el jugador confirma un nuevo tramo de vía que comparte vértices o celdas de conexión con una obra de vía que **aún no ha sido completada**, el nuevo tramo **se fusiona con la obra vial existente**.
- Esto previene la duplicación de cuadrillas en la misma arteria vial y mantiene el límite máximo de **4 obreros asignados para todo el conglomerado de vía contiguo**.

### 3.3. Representación Visual: Overlay de Contorno Guía
- Las celdas de vía en proceso de construcción se visualizan en el suelo mediante un overlay especial de contorno (`ViaObraOverlay.gd` o integrado en `ViaPreviewOverlay.gd`).
- A diferencia de los overlays de zona o demolición (que usan planos translúcidos rellenos), la obra vial dibuja **únicamente los bordes perimetrales de las celdas** (estilo wireframe en el suelo), permitiendo distinguir inmediatamente una vía en construcción de un área zonificada o marcada para demolición.

### 3.4. Cuadrilla y Avance Celda a Celda
- Hasta **4 obreros** pueden trabajar en simultáneo en una misma obra de vía.
- Los obreros pueden actuar en paralelo sobre distintas celdas del tramo.
- En cada paso de trabajo:
  1. El colono camina hacia la celda de acceso contigua a la sección pendiente.
  2. Espera el tiempo de ejecución del paso (según el tipo de suelo / colocación).
  3. Ejecuta la nivelación de la columna (tala de árbol si procede, relleno con tierra si hace falta, o cavado).
  4. Si corresponde a una rampa/desnivel, coloca la cuña física (`cuna_recta`, `cuna_esquina`, etc.).
  5. Registra la celda de soporte en `Vias.gd` con sus notches correspondientes.
  6. Al completarse la última celda, la obra de vía finaliza y se retira el overlay guía.

---

## 4. Intervención Manual en 1ª Persona: Modo de Interacción con Vías

- **Activación por Tecla `V` (toggle):** Al igual que la herramienta de deconstrucción (`G`), pulsar la tecla `V` en primera persona activa o desactiva la **herramienta de interacción con vías**.
- **Exclusividad de interacción:** Mientras el modo de vías esté activo (`V`), el avatar **no puede interactuar con bloques comunes** (no coloca ni mina bloques normales ni abre puertas/baúles con clic), concentrando sus acciones únicamente en la red vial.
- **Acciones contextuales sobre celdas de vía:**
  - **Clic izquierdo:** Avanza y surte la construcción de una celda del trazado fantasma de obra vial apuntada (acelerando el tendido paso a paso como lo hace un colono).
  - **Clic derecho:** Avanza el desmantelamiento/demolición de una celda de vía marcada para remoción apuntada (retirando la cuña/registro de vía).
- **Preferencia del jugador:** Al actuar sobre una celda de vía, `Obras.reclamar(id_via)` reserva temporalmente la obra para evitar colisiones con las decisiones de los colonos.

---

## 5. Herramienta Unificada de Demolición (Edificios y Vías)

### 5.1. Activación y Detección Contextual
- La herramienta «Demoler» de la barra cenital (tecla rápida `3`) opera de forma contextual según lo que el jugador apunte con el cursor del ratón:
  - **Sobre un edificio/puesto:** Alterna la marca de demolición del edificio (comportamiento existente, tinte rojo).
  - **Sobre una vía existente:** Inicia el modo de **Demolición de Vía**.

### 5.2. Modo de Demolición de Vías
1. **Inicio de Selección:** Al hacer clic izquierdo sobre una celda con vía construida, se fija el punto inicial de demolición.
2. **Previsualización Naranja Guiada:** Al mover el ratón, el sistema busca el camino sobre la red de vías existentes entre el último punto fijado y la celda apuntada, mostrando un **overlay translúcido color naranja** que resalta exactamente el tramo de vía a retirar.
3. **Manejo de Bifurcaciones y Cruces:** En una intersección o cruce vial, el jugador hace clic izquierdo en la rama que desea seguir para guiar la ruta de demolición.
4. **Confirmación y Cancelación:**
   - **Doble clic izquierdo:** Confirma el tramo naranja y genera una orden de **Demolición de Vía**.
   - **Clic derecho:** Cancela la selección actual y limpia el trazado naranja.

### 5.3. Ejecución de la Demolición por Colonos
- La demolición de vías entra en la cola de demoliciones de `Obras.gd`.
- Los colonos acuden al tramo para desmantelarlo:
  - Se retiran las celdas de soporte registradas en `Vias.gd`.
  - Se retiran las cuñas colocadas en los desniveles.
  - **Regla fundamental:** Los bloques físicos colocados durante la nivelación original (tierra o piedra) **no se tocan ni se destruyen**, quedando el terreno consolidado.

---

## 6. Criterios de Aceptación y Pruebas

1. **Prioridades de Obras:**
   - Pruebas unitarias que verifiquen que una obra con prioridad `Alta` se asigna antes que una con prioridad `Normal`, y esta antes que el tendido de vías o una obra `Baja`.
   - Desempate correcto por ID más antiguo cuando comparten prioridad.
2. **Trazado y Fusión de Vías:**
   - Verificar que al trazar vía no se crea de inmediato en `Vias.gd`, sino que queda registrada como obra pendiente.
   - Verificar que al trazar una vía contigua a una incompleta se unifican bajo la misma obra con tope de 4 obreros.
3. **Demolición Guiada de Vías:**
   - Verificar el trazado guiado por caminos existentes sobre la red vial con confirmación por doble clic y cancelación por clic derecho.
   - Comprobar que desmantelar la vía elimina la cuña y el registro en `Vias.gd` sin alterar los bloques de terreno nivelado.
4. **No Regresiones:**
   - Todas las 26 escenas de prueba (`tools/run-godot-tests.ps1`) pasan limpiamente con 0 errores.

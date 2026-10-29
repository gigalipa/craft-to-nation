---
title: "Logística, Red Vial y Canalizaciones Elevadas"
description: "Mecánicas de transporte y logística: red modular de canalizaciones aéreas a Y+6, tendido de vías por colonos con prioridades y transmisión de fluidos y energía."
---

# Logística, Red Vial y Canalizaciones Elevadas

![Vista estratégica de la red logística, carreteras y acueductos](/assets/citycraft-world.webp)

En **Craft to Nation**, cada unidad de madera, mineral o fluido debe desplazarse físicamente a través del mundo de `200×200` celdas. La infraestructura logística se divide en dos capas complementarias: **Red Vial y Acarreo Terrestre** (`ConstructorVias.gd`, `BuscadorRutas.gd`, `Colonos.gd`) y **Redes Aéreas de Canalización de Fluidos** (`Canalizaciones.gd` y físicas en `VoxelWorld.gd`).

---

## 1. Trazado de Vías (`1 -> 5 -> 1`), Intervención a Pie (`V`) y Demolición Guiada (`3`)

```
[Puesto Periférico / Mina] ──(Almacén Local: 1.000 u)──> [Acarreador (150 u)] ──> [Almacén Central / Refinería]
```

### Trazado de Carreteras en Cámara Cenital (`1 -> 5 -> 1`)
- En la vista cenital (<kbd>C</kbd>), el modo de trazado de vías se selecciona desde el menú numérico: **<kbd>1</kbd> (Construir) → <kbd>5</kbd> (Vías) → <kbd>1</kbd> (Trazar vía)**. *(En cámara cenital no se utiliza la tecla `V`).*
- La ficha contextual muestra los iconos vectoriales **`[Clic Izq] FIJAR PUNTO`**, **`[Doble Clic Izq (x2)] CONFIRMAR`**, **`[Clic Der] CANCELAR`** y **`[Esc] SALIR`**, junto con el bono de `Velocidad: +35%` y el costo dinámico en piedra/tierra.
- Al confirmar con **doble clic izquierdo**, aparece el contorno perimetral amarillo (`ViaObraOverlay`) y hasta **4 obreros libres** acuden a construir la vía consecutivamente de extremo a extremo. Si trazas un nuevo tramo contiguo mientras la obra sigue activa, se fusiona automáticamente en la misma orden de trabajo.

### Modo de Interacción de Vías a Pie en 1ra Persona (Tecla <kbd>V</kbd>)
- En primera persona, pulsar <kbd>V</kbd> **activa el modo de construcción/demolición de vías a pie**:
  - **Construir sección `2×2` (<kbd>Clic Izquierdo</kbd>):** Apuntando a una sección de vía pendiente (con contorno amarillo), completa de golpe toda la **sección de `2×2` celdas** (las 4 celdas de ancho vial o cuñas de rampa).
  - **Demoler sección `2×2` (<kbd>Clic Derecho</kbd>):** Apuntando a una sección de carretera ya construida, elimina al instante toda la sección de `2×2` junto con sus cuñas.
  - Pulsa <kbd>V</kbd> o <kbd>Esc</kbd> para salir del modo de vías.

### Demolición Vial Guiada en Cámara Cenital (Modo <kbd>3</kbd>)
- En cámara cenital, activa el modo unificado **<kbd>3</kbd> (Demoler)**, haz clic izquierdo en un extremo de una carretera (incluso en forma de "L" con esquina de 90°) y mueve el cursor hasta el otro extremo:
- La vista previa naranja translúcida (`ViaDemolicionOverlay`) sigue la red vial mediante **Dijkstra** cubriendo el **ancho completo de 2 carriles (`2×2`)** alrededor de la esquina exterior sin cortar en diagonal. Al confirmar con **doble clic izquierdo**, queda marcado el contorno naranja persistente para que los colonos desmonten la vía tramo por tramo.

### Parámetros del Acarreador, Parque Móvil y Pathfinding Ponderado (`BuscadorRutas.gd`)
- **Velocidad Base del Acarreador a Pie:** **2,5 celdas / segundo** (`5,0 celdas/h` de juego), con **+35 % de velocidad** sobre carreteras.
- **Capacidad de Carga Base:** **150 unidades** por viaje (lote mínimo de **10 u**, respetando siempre la `Reserva central:` porcentual de `0% / 10% / 20% / 30% / 40% / 50%`).
- **Coste A* Ponderado:** Coste de paso **3** en vía de tierra pisada frente a coste **8** en terreno natural.

### Taller de Transporte y Unidades Móviles de Acarreo (`Ciudad.PARQUE_TRANSPORTE_TIPOS`)
En el **Taller de Transporte** de la Zona Industrial se fabrican y asignan unidades logísticas que multiplican la capacidad y velocidad de acarreo:

| Unidad de Transporte | Capacidad | Velocidad Base | Exige Vía | Insumo Operativo | Costo de Fabricación |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`acarreador_pie`** *(A pie)* | `150 u` | `2,5 m/s` | No | — | Dotación base de colonos |
| **`carreta_mano`** *(Carreta de mano)* | `300 u` | `2,2 m/s` | No | — | `20 Tablas + 5 Hierro` |
| **`carro_caballos`** *(Carro de caballos)* | `600 u` | `4,0 m/s` | No | `2 Comida/h` | `40 Tablas + 15 Hierro` |
| **`camion_diesel`** *(Camión diésel)* | `1.800 u` | `6,5 m/s` | **Sí (`exige_via`)** | `2 Combustible/h` | `30 Acero + 20 Hierro + 10 Cobre + 6 Vidrio` |
| **`trolebus_solar`** *(Trolebús solar)* | `900 u` | `5,0 m/s` | **Sí (`exige_via`)** | `1 Energía/h` | `15 Acero + 20 Cobre + 5 Min. Refinado + 4 Vidrio` |
| **`dron_carga`** *(Dron de carga)* | `600 u` | `7,5 m/s` *(vuelo directo)* | No | `2 Energía/h` | `20 Acero + 25 Cobre + 15 Min. Refinado` |

- **Uso Exclusivo de Vidrio en Cabinas:** Las unidades motorizadas con parabrisas (`camion_diesel` y `trolebus_solar`) exigen exclusivamente el recurso refinado **`vidrio`** (producido en la Vidriera `1-3-5`), sin admitir `tierra` como sustituto.
- **Arrastre Lento por Falta de Insumo (`1,2 m/s`):** Si un vehículo en ruta se queda sin su insumo operativo (`comida`, `combustible` o `energía`), entra en modo de arrastre de emergencia a **`1,2 m/s`**, conservando el **100 % de su mercancía** hasta completar la entrega.

---

## 2. Jerarquía de Cesión de Paso en Pasillos de 1 Celda

En pasos estrechos de 1 sola celda, cuando dos colonos se encuentran de frente, el motor evita bloqueos aplicando la siguiente jerarquía de prioridad por carga:

```text
Comida > Combustible > Crudo > Acero > Mineral Refinado
       > Hierro > Cobre > Carbón > Tierras Raras
       > Vidrio > Tablas > Bloques de Piedra > Madera > Piedra > Tierra > Agua
```

El colono sin carga o con menor prioridad se aparta temporalmente a una celda lateral para ceder el paso.

---

## 3. Canalizaciones Elevadas (`1 -> 6 -> 1..2`), Cruces a Desnivel y Derrames

En cámara cenital, las redes de fluidos se trazan desde **<kbd>1</kbd> (Construir) → <kbd>6</kbd> (Ductos)**:

| Menú | Tipo de Ducto | Fluidos Permitidos | Etiquetas Legibles de Costo por Celda |
| :--- | :--- | :--- | :--- |
| **`1-6-1`** | **Acueducto** | <ResourceBadge name="Agua" /> <ResourceBadge name="Combustible" /> | `1 Bloque de piedra` + `1 Tabla` (o `Bloque de madera`) |
| **`1-6-2`** | **Tubería** | <ResourceBadge name="Agua" /> <ResourceBadge name="Crudo" /> <ResourceBadge name="Combustible" /> | `1 Bloque de acero` + `1 Estructura de hierro` |

### Altura Estándar (`Y + 4`), Pilares cada 5 Bloques y Cruces entre Dos Ductos (`Y + 6`)
- **Altura Estándar (`Y = Y_suelo + 4`):** Los conductos se construyen elevados dejando **3 bloques libres de paso vertical** bajo la viga para que el avatar, los colonos y las carreteras terrestres (`1 -> 5 -> 1`) pasen por debajo sin obstrucción. Los pilares de soporte se colocan cada **5 bloques** (`0, 5, 10...`, dejando 4 celdas libres entre columnas) y siempre en cada esquina de 90°.
- **Cruces a Desnivel entre Dos Conductos (`Y = Y_suelo + 6`):** Cuando trazas una Tubería o Acueducto cruzando perpendicularmente otro conducto ya construido en `Y + 4`, en las dos celdas inmediatamente adyacentes al cruce se erigen automáticamente **dos columnas dobles de 6 bloques de altura (`Y = Y_suelo + 5`)** y el tramo superior cruza a **`Y = Y_suelo + 6`**, dejando **1 bloque completo de aire libre (`Y = Y_suelo + 5`)** entre ambos conductos sin mezclar sus fluidos.

### Derrames Físicos (`🔴 Derrame`), Viscosidad `0,20` y Reconexión desde Columna
- **Derrame en Extremo Abierto:** Si un conducto conectado a un extractor activo se confirma con doble clic dejando su extremo final sin acoplar en el aire, en el siguiente tick horario cambia a **`🔴 Derrame`**, generando un bloque físico de fluido que cae al suelo y se propaga por gravedad (`crudo` hasta 3 celdas horizontales con **factor de viscosidad `0,20`**, cinco veces más denso que tierra firme; se puede secar en 1ra persona colocando un bloque sólido con <kbd>Clic Derecho</kbd>).
- **Reconexión Directa:** Haciendo clic izquierdo con la herramienta de ductos (`1 -> 6 -> 1..2`) directamente sobre la **última columna** de un tramo en estado `🔴 Derrame` o `⚪ Desconectado`, puedes continuar el trazado hasta un puerto de entrada; el tramo se fusiona, sella la red en **`🟢 Conectado`** y detiene el derrame de inmediato.

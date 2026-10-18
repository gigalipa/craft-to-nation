# Logística, Red Vial y Canalizaciones

![Vista estratégica de la red logística, carreteras y acueductos](/assets/citycraft-world.webp)

En **Craft to Nation**, cada unidad de madera, mineral o fluido debe desplazarse físicamente a través del mundo de `200×200` celdas. La infraestructura logística se divide en dos capas complementarias: **Red Vial y Acarreo Terrestre** (`ConstructorVias.gd`, `BuscadorRutas.gd`, `Colonos.gd`) y **Redes Aéreas de Canalización de Fluidos** (`Canalizaciones.gd`, `Fluidos.gd`).

---

## 1. Trazado de Vías, Cuadrillas Viales y Acarreo Terrestre

```
[Puesto Periférico / Mina] ──(Almacén Local: 1.000 u)──> [Acarreador (150 u)] ──> [Almacén Central / Refinería]
```

### Construcción y Demolición de Vías (`ConstructorVias.gd` / `Obras.gd`)
- **Trazado en Cámara Cenital (<kbd>V</kbd>):** Permite trazar tramos rectos o en L de carreteras de tierra pisada con generación automática de rampas en desniveles suaves y vista previa con miniatura 3D en `BarraModos.gd`.
- **Ejecución por Colonos y Prioridades:** Los tramos trazados se registran como obras viales donde los obreros libres acuden a construirlos según la prioridad asignada (**Alta `▲▲▲`**, **Normal `▲▲`**, **Baja `▲`**). También puedes construirlos o demolerlos manualmente en primera persona apuntando al suelo y pulsando <kbd>V</kbd>, o mediante la demolición guiada de redes viales en modo Demoler (<kbd>3</kbd> + <kbd>V</kbd>).

### Parámetros Físicos del Acarreador y Pathfinding Ponderado (`BuscadorRutas.gd`)
- **Velocidad Base:** **2,5 celdas / segundo** (`5,0 celdas/h` de juego).
- **Bono por Carretera:** Las vías de tierra pisada otorgan un **+35 % de velocidad** tanto a colonos como al avatar del jugador.
- **Capacidad de Carga por Viaje:** **150 unidades** (con umbral mínimo de lote de **10 unidades** y respeto estricto de las cuotas de reserva `[0, 50, 100, 250, 500] u`).
- **Coste A* Ponderado:** Coste de paso **3** en vía de tierra pisada frente a coste **8** en terreno natural, haciendo que los acarreadores sigan las arterias viales de forma natural.

---

## 2. Jerarquía de Cesión de Paso en Pasillos de 1 Celda

Cuando dos colonos se encuentran de frente en un paso estrecho de 1 sola celda, el motor evita bloqueos mutuos (*deadlocks*) aplicando una jerarquía estricta de prioridad por recurso transportado:

```text
Comida > Combustible > Crudo > Acero > Mineral Refinado
       > Hierro > Cobre > Carbón > Tierras Raras
       > Tablas > Madera > Piedra > Tierra > Agua
```

- **Desempate:** Si ambos transportan el mismo recurso, tiene prioridad quien lleve mayor cantidad; si persiste el empate, quien tenga mayor rango de tarea (`Acarreador cargado > Acarreador vacío > Trabajador en ruta > Colono libre`) o menor ID. El agente que cede da un paso lateral temporal para despejar la vía.
- **Celda de Servicio Exterior:** Los acarreadores recogen y entregan cargas desde la celda exterior frente a la puerta de entrada (`e`) o salida (`s`), sin invadir el interior de los puestos.

---

## 3. Red Aérea de Canalizaciones y Fluidos (`Canalizaciones.gd`)

Para transportar **Agua**, **Crudo** y **Combustible** sin requerir acarreadores a pie, la colonia emplea redes modulares de 4 piezas (columnas verticales, cabezales rectos/esquina, tramos continuos inclinables y acoples terminales a puerto):

| Tipo de Ducto | Fluidos Permitidos | Coste Constructivo por Celda |
| :--- | :--- | :--- |
| **Acueducto** | <ResourceBadge name="Agua" /> <ResourceBadge name="Combustible" /> | `1 Bloque de Piedra` + `1 Bloque de Madera` |
| **Tubería Industrial** | <ResourceBadge name="Agua" /> <ResourceBadge name="Crudo" /> <ResourceBadge name="Combustible" /> | `1 Bloque de Acero` + `1 Estructura de Hierro` |

### Geometría, Cruces a Desnivel (`Y + 6`) y Diagnóstico en HUD
- **Cota Estándar y Cruces Viales:** Los ductos conectan con los puertos de líquido en la **capa 4** de las instalaciones y se elevan a **`Y_suelo + 6`** en los cruces sobre carreteras, dejando un **gálibo libre de `Y + 5`** para el paso despejado de peatones y vehículos, con pilares de soporte cada **5 celdas** (`INTERVALO_COLUMNAS = 5`).
- **Tasa de Conducción y Derrames:** Cada conexión activa conduce **2,0 u/h**. Si un tramo queda abierto sin acople terminal, emite `derrame_detectado` y vierte fluido al terreno según su viscosidad (`Agua`: radio 7; `Combustible`: radio 5; `Crudo`: radio 3 con viscosidad `0,20`).
- **Panel de Canalización (`PanelCanalizacion.gd`):** Al seleccionar cualquier tramo en cámara cenital, el HUD muestra el indicador visual de flujo **`[Estado entrada] -⇥ [Icono Recurso] -⇥ [Estado salida]`** para diagnosticar al instante si los extremos están acoplados, activos o bloqueados.

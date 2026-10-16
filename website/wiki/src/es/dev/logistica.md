# Logística, Ductos y Transporte

En *Craft to Nation*, la extracción masiva de recursos resulta inútil sin una infraestructura de transporte que distribuya materias primas y bienes manufacturados de manera eficiente. El sistema combina **acarreo terrestre humano** con **redes aéreas y subterráneas de fluidos**.

---

## 1. Especificaciones de Acarreo Terrestre

El acarreo cívico a pie es el método primordial de transporte para materiales sólidos y lotes iniciales de suministros:

```
[Puesto Periférico / Mina] ──(Almacén Local: 1000 u)──> [Acarreador (150 u)] ──> [Almacén Central / Refinería]
```

### Parámetros Físicos del Acarreador
- **Velocidad de Desplazamiento Base:** **2.5** celdas / segundo (equivalente a **5.0** celdas por hora de tiempo de juego).
- **Capacidad de Carga Máxima:** **150 unidades** por viaje.
- **Umbral de Carga Mínima:** **10 unidades** (impide que los colonos realicen trayectos largos con cargamentos testimoniales).
- **Bono por Red Vial:** Las carreteras y caminos de tierra pisada otorgan un **bono de velocidad del +35%** tanto a colonos como al avatar del jugador.

### Pathfinding Ponderado y Preferencia por Carreteras
El algoritmo de búsqueda de rutas (`BuscadorRutas.gd`) evalúa los costes de paso del terreno para dirigir a las caravanas por vías optimizadas:
- **Coste de paso en Terreno Natural:** Coste **8**.
- **Coste de paso en Vía de Tierra Pisada:** Coste **3**.
Esta diferencia de costes garantiza que los acarreadores prefieran transitar por calles pavimentadas antes que atravesar desniveles abruptos o maleza salvaje.

---

## 2. Jerarquía de Paso en Rutas Estrechas

En desfiladeros o calles de 1 sola celda donde dos colonos caminan en direcciones opuestas, el motor aplica una estricta jerarquía logística para resolver desatascos cediendo el paso lateral:

```text
Comida > Combustible > Crudo > Acero > Mineral Refinado
       > Hierro > Cobre > Carbón > Tierras Raras
       > Tablas > Madera > Piedra > Tierra > Agua
```

- **Regla de Desempate:** Si ambos transportistas acarrean el mismo recurso, cede el paso quien cargue menor cantidad o posea menor identificador de entidad.
- **Punto de Recogida Limpio:** Los acarreadores interactúan con los puestos periféricos exclusivamente en la celda de servicio frontal, sin invadir el interior del edificio ni colisionar con los operarios de recolección.

---

## 3. Red Aérea de Canalizaciones y Fluidos (`Canalizaciones.gd`)

Para fluidos a gran escala (agua dulce, petróleo crudo y combustible refinado), la colonia emplea ductos aéreos modulares de 4 piezas que no interfieren con el tráfico terrestre.

### Catálogo de Ductos
| Tipo de Ducto | Fluidos Permitidos | Bloques Constructivos | Coste de Fabricación |
| :--- | :--- | :--- | :--- |
| **Acueducto** | Agua dulce, Combustible | Canal de piedra con artesa de madera | 1 Bloque Piedra + 1 Bloque Madera |
| **Tubería de Presión** | Agua dulce, Crudo, Combustible | Cilindro de acero sobre viga estructural | 1 Bloque Acero + 1 Estructura Hierro |

### Geometría y Galibo de Paso
- **Altura Relativa de Ductos:** Se elevan a una cota estándar de `Y_suelo + 4` bloques.
- **Cruce a Desnivel:** Los cruces viales y pasos vehiculares se emplazan en `Y_suelo + 6`, garantizando un **vano libre de paso de `Y + 5`** para que carros y tropas pasen por debajo sin obstrucción.
- **Pilares Estructurales:** Se erigen automáticamente columnas de soporte cada **5** celdas longitudinales (`INTERVALO_COLUMNAS = 5`).

### Dinámica de Flujo y Derrames
- **Tasa de Conducción Base:** **2.0 unidades de fluido / hora** por conexión activa.
- **Topología de Red:** Estructura multi-entrada (varias estaciones de bombeo convergiendo) hacia salida única o depósito industrial.
- **Detección de Derrames:** Si un ducto se corta o deconstruye dejando un extremo abierto al aire, el autoload emite `derrame_detectado`, provocando inundaciones superficiales con viscosidad diferencial:
  - *Agua:* Expansión horizontal rápida (radio 7 celdas).
  - *Combustible:* Expansión intermedia (radio 5 celdas).
  - *Crudo:* Expansión lenta y densa (radio 3 celdas, viscosidad 0.20).

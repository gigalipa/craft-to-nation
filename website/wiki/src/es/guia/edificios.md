# Edificios, Puestos y Almacenamiento

En *Craft to Nation*, las estructuras no son simples elementos decorativos; constituyen el corazón funcional de la civilización. Cada edificación se rige por leyes de física estructural, validación volumétrica interior y reglas estrictas de zonificación territorial.

---

## 1. Clasificación Territorial de Edificios

El sistema clasifica las construcciones en tres zonas excluyentes para asegurar el equilibrio cívico e industrial:

| Distrito | Categoría de Edificio | Ejemplos Comunes | Regla de Emplazamiento |
| :--- | :--- | :--- | :--- |
| **Zona A (Residencial)** | Viviendas, Centros Cívicos, Academias | Residencias de colonos, Escuela Técnica, Universidad | Únicamente dentro del radio de influencia del Núcleo Urbano |
| **Zona B (Industrial)** | Refinerías, Fundiciones, Centrales | Siderúrgica, Aserradero, Refinería de Petróleo, Termoeléctrica | Polígono continuo delimitado contiguo al Núcleo A |
| **Periferia Silvestre** | Puestos de Extracción Remota | Puesto Maderero, Minas de Subsuelo, Muelle de Pesca | En biomas abiertos sobre depósitos naturales de recursos |

---

## 2. Puestos de Recolección Periféricos

Los puestos de recolección son instalaciones de campo diseñadas para la extracción intensiva de materias primas. Todos los puestos periféricos incorporan un **almacén local dedicado con capacidad fija de 1,000 unidades**:

### Puesto Maderero
- **Huella de Construcción:** 3×4 celdas.
- **Radio Operativo:** 12 celdas a la redonda.
- **Capacidad Laboral:** Hasta 5 leñadores + cuadrilla de acarreadores.
- **Mecánica:** Los leñadores talan árboles reales en su radio. Al completarse la tala de un árbol, el tronco se convierte en unidades de madera en el almacén local.

### Minas de Extracción (Piedra, Hierro, Carbón, Tierras Raras)
- **Huella de Construcción:** 5×5 celdas.
- **Profundidad de Operación:** Escalonada en 3 niveles de desarrollo (8, 16 y 24 bloques subterráneos).
- **Capacidad Laboral:** Hasta 5 mineros.
- **Regla Estructural Crucial:** La mina nunca extrae los bloques de la superficie para evitar que el edificio quede flotando en el aire. Excava exclusivamente pozos verticales y galerías en el subsuelo.

### Puestos de Caza y Pesca
- **Caza y Recolección:** Huella de 4×4 celdas, radio de 12 celdas. Dotación máxima de 7 recolectores. Combina caza de fauna (17.0 u/h) con recolección de frutos (10.0 u/h).
- **Muelle de Pesca:** Huella de 4×6 celdas, radio acuático de hasta 25 celdas. Requiere estar emplazado con su frente de servicio sobre agua profunda.

---

## 3. Jerarquía y Capacidad de Almacenamiento

El flujo de materiales se divide en dos niveles de almacenamiento:

```
[Extracción en Puesto / Producción en Refinería]
                     ↓
        (Almacén Local: 1,000 u)
                     ↓
         [Acarreadores Cívicos (150 u/viaje)]
                     ↓
        (Almacén Central Municipal)
          - Stock Base: 500 u / recurso
          - Comida Base: 5,000 u
          - Factor Núcleo: ×2 al declarar
          - Bono Baúl Residencial: +100 u (+400 comida)
```

### El Almacén Central Municipal (`Ciudad.almacen`)
Es el inventario consolidado accesible por la administración de la ciudad y el avatar:
- **Límite Base General:** 500 unidades por cada tipo de recurso mineral o manufacturado.
- **Límite Base de Alimentos:** 5,000 unidades (la partida inicia con el stock de comida lleno).
- **Factor de Núcleo Urbano (×2):** Al oficializar el primer edificio hermético como núcleo urbano, la capacidad base de todos los recursos se duplica inmediatamente.
- **Expansión por Baúles Residenciales:** Por cada baúl colocado en viviendas habitables validadas, la capacidad global del almacén central se incrementa en **+100 unidades** para recursos generales y **+400 unidades** adicionales para comida.

### El Almacén Local de Puestos e Industrias (1,000 Unidades)
Cada puesto de recolección o refinería acumula su producción en un depósito local de hasta **1,000 unidades**. Una vez lleno, la producción se detiene por saturación física a menos que:
1. Un acarreador retire lotes de transporte (mínimo de 10 unidades por lote).
2. Se construya una conexión automatizada mediante cintas o canalizaciones aéreas.

---

## 4. Reglas de Validación Arquitectónica y Blueprints

Para que una estructura manual sea reconocida como un edificio válido por el motor de simulación, debe cumplir los siguientes requisitos:

1. **Hermeticidad y Volumen Interior:** Todas las paredes perimetrales y techos deben estar cerrados sin fugas de aire o huecos en las esquinas.
2. **Acceso a Nivel de Suelo:** La puerta principal debe estar colocada a la misma cota del terreno o carretera exterior para permitir el paso de los colonos.
3. **Flexibilidad en Plantas Superiores:** Solo el primer piso requiere puerta exterior obligatoria; los pisos superiores pueden conectarse internamente mediante escaleras o rampas sin exigir puertas exteriores adicionales.
4. **Despeje de Camas y Aberturas:** Las camas requieren un espacio libre contiguo para que los colonos puedan acostarse y levantarse. Las puertas y ventanas deben contar con un área de despeje libre que no invada estructuras colindantes.

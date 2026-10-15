# Recursos y Materias Primas

La economía de *Craft to Nation* se fundamenta en un ecosistema orgánico de recursos naturales, insumos energéticos y bienes manufacturados. Cada recurso cuenta con características físicas particulares, requerimientos logísticos de transporte y tasas de extracción auditadas en el motor de simulación.

---

## 1. Catálogo de Recursos Primarios

A continuación se detallan los recursos fundamentales de extracción natural, clasificados por categoría:

| Recurso | Categoría | Fuente Principal | Método de Extracción |
| :--- | :--- | :--- | :--- |
| <ResourceBadge name="Agua" category="Vital" /> | Vital / Industrial | Lagos y ríos superficiales | Estación de bombeo y acueductos |
| <ResourceBadge name="Comida" category="Vital" /> | Vital / Metabólico | Fauna silvestre, bayas y cardúmenes | Puestos de caza, recolección y pesca |
| <ResourceBadge name="Madera" category="Básico" /> | Construcción / Combustible | Bosques de coníferas y frondosas | Puesto maderero (tala en superficie) |
| <ResourceBadge name="Piedra" category="Básico" /> | Construcción / Estructuras | Afloramientos y canteras rocosas | Mina de superficie y subsuelo |
| <ResourceBadge name="Hierro" category="Mineral" /> | Metalurgia / Maquinaria | Vetas subterráneas (prof. 8–24 m) | Mina especializada con pozos |
| <ResourceBadge name="Cobre" category="Mineral" /> | Conducción / Tecnología | Vetas subterráneas intermedias | Mina especializada |
| <ResourceBadge name="Carbón" category="Energético" /> | Combustible / Siderurgia | Depósitos sedimentarios profundos | Mina de carbón o carboneras |
| <ResourceBadge name="Crudo" category="Energético" /> | Petroquímica / Fluidos | Pozos petrolíferos del subsuelo | Centro de extracción y tuberías |
| <ResourceBadge name="Tierras Raras" category="Avanzado" /> | Electrónica / Aleaciones | Yacimientos tectónicos profundos | Mina profunda de alta tecnología |
| <ResourceBadge name="Tierra" category="Básico" /> | Terraformación / Nivelado | Capa superficial del bioma | Palas manuales y nivelación de suelo |

---

## 2. Tasas Base de Extracción en Puestos Periféricos

Las tasas de extracción representan el rendimiento horario por trabajador asignado bajo condiciones normales de moral neutra (Moral = 50.0). Las tasas se recalculan dinámicamente cada 6 horas de juego según la densidad de recursos en el radio de operación:

| Puesto de Recolección | Recurso Obtenido | Tasa Base (unid/trabajador/h) | Personal Máx. | Radio de Cobertura |
| :--- | :--- | :--- | :--- | :--- |
| **Puesto Maderero** | <ResourceBadge name="Madera" /> | **5.0** (Troncos) | 5 leñadores | 3×4 huella / Radio 12 celdas |
| **Mina de Cantera** | <ResourceBadge name="Piedra" /> | **5.0** (Piedra) | 5 mineros | 5×5 huella / Prof. 8–24 celdas |
| **Mina de Hierro** | <ResourceBadge name="Hierro" /> | **5.0** (Hierro) | 5 mineros | 5×5 huella / Subsuelo |
| **Mina de Carbón** | <ResourceBadge name="Carbón" /> | **5.0** (Carbón) | 5 mineros | 5×5 huella / Subsuelo |
| **Caza y Recolección** | <ResourceBadge name="Comida" /> | **17.0** (Caza) + **10.0** (Frutos) | 7 recolectores | 4×4 huella / Radio 12 celdas |
| **Pesca y Frutos del Mar** | <ResourceBadge name="Comida" /> | **17.0** (Pesca) + **3.0** (Algas) | 7 pescadores | 4×6 huella / Radio 25 celdas |
| **Estación de Bombeo** | <ResourceBadge name="Agua" /> | **2.0** (Flujo continuo) | 3 operarios | Red de acueductos |
| **Centro de Extracción** | <ResourceBadge name="Crudo" /> | **2.0** (Bombeo profundo) | 3 operarios | Red de tuberías |

> [!NOTE] Fórmulas de Rendimiento Ambiental
> - **Madera:** La tasa horaria efectiva es `5.0 × densidad_forestal × multiplicador_nivel`. Si la densidad cae por debajo de 0.5 madera/h, el puesto se considera temporalmente agotado.
> - **Caza y Frutos:** Promedio en bioma virgen: `~12.2 comida/h por recolector`.
> - **Pesca:** El rendimiento escala con la profundidad del agua (0.5 en aguas someras hasta 1.5 en fosas marinas) y el tamaño del lago o mar (`celdas / 450`, rango `[0.4, 1.5]`), promediando `~8.6 comida/h`.

---

## 3. Bloques Naturales vs Bloques Estructurales

Cuando minas o extraes material directamente del terreno procedural, obtienes unidades crudas para el inventario. Para edificar construcciones permanentes, se consumen recursos del almacén central según los siguientes costes:

| Material | Rendimiento al Extraer (Bloque Natural) | Bloque Estructural Colocable | Coste de Colocación en Almacén |
| :--- | :--- | :--- | :--- |
| **Tierra Natural** | 1 unidad <ResourceBadge name="Tierra" /> | `tierra_compactada` | 1 Tierra |
| **Roca de Piedra** | 10 unidades <ResourceBadge name="Piedra" /> | `bloque_piedra` | 5 Piedra (o 1 bloque procesado) |
| **Veta de Hierro** | 10 unidades <ResourceBadge name="Hierro" /> | `estructura_hierro` | 5 Hierro |
| **Tronco de Árbol** | 10 unidades <ResourceBadge name="Madera" /> por celda | `bloque_madera` | 5 Madera (o 1 tabla procesada) |
| **Arena de Sílice** | 1 unidad Arena | `vidrio` | 1 Arena / Tierra tratada |
| **Lingote de Acero** | *No se extrae en la naturaleza* | `bloque_acero` | 3 Acero refinado |

---

## 4. Cadenas de Procesamiento Secundario

Las materias primas crudas se transportan hacia la **Zona B (Industrial)** para manufacturar materiales avanzados:

```
[Madera Cruda] --------> (Aserradero) -----------> [3 Tablas de Madera]
[Madera Cruda] --------> (Carbonera) ------------> [1 Carbón Vegetal]
[Hierro] + [Carbón] ---> (Siderúrgica) ----------> [2 Lingotes de Acero]
[Piedra Cruda] --------> (Fábrica de Bloques) ---> [3 Bloques de Sillería]
[Crudo Subterráneo] ---> (Refinería Petrolera) --> [1 Combustible Sintético]
```

Estas transformaciones son vitales para alimentar la red de investigación tecnológica, abastecer la central termoeléctrica y construir infraestructuras de transporte ferroviario y defensivo.

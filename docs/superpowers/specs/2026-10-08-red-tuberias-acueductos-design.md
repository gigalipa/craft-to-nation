# Especificación de Diseño: Red de Tuberías y Acueductos (Etapa 9.3)

**Fecha:** 2026-10-08  
**Estado:** Propuesto / En revisión  
**Alcance:** Paso 9 - Etapa 9.3: Red de tuberías y acueductos, elevación, columnas de soporte, pasos a desnivel, topología de red, red compartida de almacenes, simulación de transporte de fluidos y derrames.

---

## 1. Visión General y Objetivos

Con la culminación de las etapas 9.1 (subsuelo, pozos y bloques) y 9.2 (puestos de bombeo, centro de extracción, almacenes y adaptación de refinerías con puertos a cota 4), esta etapa implementa la infraestructura física y lógica para conectar los edificios mediante canalizaciones elevadas.

### Objetivos Clave:
1. **Canalizaciones Físicas Elevadas:**
   - Dos tipos: **Acueductos** (piedra y madera; agua y combustible) y **Tuberías** (acero; agua, crudo y combustible).
   - Bloques reales colocados en `VoxelWorld`.
   - Altura estándar: **3 bloques de despeje vertical** sobre el terreno natural ($Y = Y_{suelo} + 4$).
   - Libre tránsito para colonos y vías bajo la canalización ($Y = Y_{suelo} + 1, 2, 3$).
2. **Columnas de Soporte Estructurales:**
   - Se erigen automáticamente desde el suelo ($Y_{suelo}+1$ hasta $Y_{suelo}+3$) cada 5 bloques horizontales (4 bloques de vano libre entre pilares), en las esquinas (quiebres de 90°) y en extremos abiertos.
   - En cambios de pendiente del terreno, las columnas mantienen su espaciado horizontal de 4 bloques de vano, y el tramo superior de tubería/acueducto desciende o asciende en diagonal uniendo las cimas de las columnas adyacentes sin pilares intermedios adicionales.
   - Materiales: columnas de `bloque_piedra` para acueductos y `estructura_hierro` para tuberías.
3. **Pasos a Desnivel en Cruces:**
   - Si una línea en trazado se cruza con otra línea existente a la misma cota $Y$, la nueva línea se sobre-eleva automáticamente 1 bloque ($Y = Y_{suelo} + 5$) en la celda de intersección para pasar por encima limpiamente.
4. **Herramienta de Trazado en UI:**
   - Menú Construir -> Categoría **6: Ductos**:
     - Opción 1: **Acueducto** (`1-6-1`).
     - Opción 2: **Tubería** (`1-6-2`).
   - Clic para fijar origen/esquinas, previsualización interactiva con cálculo de costes, doble clic o clic en puerto de destino para confirmar.
5. **Topología de Red, Almacenes Compartidos y Transporte:**
   - Conexión a puertos de edificios a $Y = 4$ ocupando la celda de despeje exterior.
   - Validación de recurso único por línea y compatibilidad de puertos.
   - Depósito en `almacen`: todos los almacenes comparten un depósito global de fluidos instantáneo. El núcleo urbano no almacena líquidos.
6. **Mecánica y Visual de Derrames (Spills/Leaks):**
   - Si un productor activo bombea fluido hacia una línea que termina en extremo abierto, rota o sin receptor válido, ocurre un derrame.
   - En el punto de fuga se engendra un bloque del fluido correspondiente (`agua`, `crudo`, o el nuevo bloque translúcido ámbar `combustible`), el cual escurre con la física habitual de fluidos.
   - Alerta en HUD y estado `Derrame` (en rojo) en el `PanelPuesto`.

---

## 2. Catálogo de Bloques y Red

### 2.1 Bloques en `VoxelWorld`
- **Acueducto (`acueducto`):**
  - Malla: Bloque rectangular de canalización con textura o material de piedra/madera. Registrado dinámicamente en `_indexar_biblioteca()` si no está en la biblioteca base.
  - Bloque sólido, no pisable por colonos (`celda_sobre_techo`).
- **Tubería (`tuberia`):**
  - Malla: Bloque cilíndrico o cúbico metálico de acero.
  - Bloque sólido, no pisable por colonos.
- **Columnas de soporte:**
  - Acueducto: `bloque_piedra` (existente en el juego).
  - Tubería: `estructura_hierro` (existente en el juego).
- **Fluido Combustible (`combustible`):**
  - Bloque fluido translúcido (se agrega a `TIPOS_TRANSLUCIDOS` y `TIPOS_LIQUIDOS` en `VoxelWorld.gd`).
  - Material: Ámbar translúcido (StandardMaterial3D con albedo color ámbar, transparencia alpha/depth pre-pass similar a agua y crudo).
  - Se integra en `TranslucidosRenderer.gd` y `_escurrir_agua_desde` / propagación de fluidos en cascada.

### 2.2 Autoload `Canalizaciones.gd`
- Módulo singleton de estado puro para la topología de ductos.
- Registra:
  - `redes`: Lista o diccionario de redes conectadas.
  - `celda_a_red`: `Vector3i` -> `id_red`.
  - `puertos_conectados`: `Vector3i` (puerto) -> `id_red`.
  - `tipo_por_celda`: `Vector3i` -> `"acueducto"` | `"tuberia"`.
  - `recurso_por_red`: `id_red` -> `"agua"` | `"crudo"` | `"combustible"` | `""`.
  - `columnas`: `Dictionary` (`Vector3i` -> `id_red` o `true`).
  - `derrames_activos`: `Dictionary` (`Vector3i` -> `String` recurso).

---

## 3. Geometría, Columnas y Cruces a Desnivel

### 3.1 Cota Base y Despeje
- En cualquier celda $(X, Z)$ con nivel de suelo $Y_{suelo} = mundo.altura\_en(X, Z)$:
  - Altura del ducto: $Y_{ducto} = Y_{suelo} + 4$.
  - Celdas de despeje inferior: $Y \in [Y_{suelo}+1, Y_{suelo}+3]$ quedan vacías de obstáculos (aire).
  - Los colonos y caminos terrestres circulan libremente por debajo.
  - La celda superior $Y_{ducto}+1$ se registra como no pisable (`celda_sobre_techo`).

### 3.2 Reglas de Generación de Columnas
- Las columnas se erigen desde $Y_{suelo}+1$ hasta $Y_{ducto}-1$ (bloques verticales).
- **Frecuencia:** Cada 5 celdas a lo largo de un tramo recto horizontal (índice 0, 5, 10... dejando vanos de 4 celdas libres entre pilares).
- **Esquinas:** Todo quiebre de 90° horizontal genera obligatoriamente una columna en la esquina.
- **Extremos:** Si el inicio o fin del tramo no colinda directamente con un puerto o pared de edificio, se coloca una columna de soporte en el extremo.
- **Cambios de Cota del Terreno (Pendientes):**
  - No se insertan columnas intermedias adicionales.
  - Entre la cima de una columna a $(X_1, Z_1)$ con altura $Y_1 = H_1 + 4$ y la cima de la columna siguiente a $(X_2, Z_2)$ con altura $Y_2 = H_2 + 4$ (separadas por 4 celdas horizontales de vano), los bloques de canalización se generan en diagonal/escalón uniendo ambas cimas.

### 3.3 Cruces a Desnivel (Sobre-elevación Automática)
- Durante el trazado de un ducto, si la ruta pasa por una celda $(X, Y, Z)$ que ya contiene un bloque de canalización:
  - En la celda de cruce, la cota asciende a $Y + 1 = Y_{suelo} + 5$.
  - En las celdas inmediatamente anterior y posterior al cruce, se colocan transiciones para subir y bajar suavemente el nivel.
  - La línea existente a $Y_{suelo} + 4$ y la nueva a $Y_{suelo} + 5$ permanecen totalmente aisladas físicamente.

---

## 4. Conexión con Puertos y Validación

### 4.1 Despeje de Puertos
- En `VoxelWorld.gd`: `calcular_despeje()` reserva 1 celda exterior frente a cada puerto de edificio a $Y = 4$.
- `despeje_bloqueado()` se amplía para permitir que un bloque de `acueducto` o `tuberia` ocupe la celda de despeje de un puerto, siempre que:
  - Para `acueducto`: el puerto sea de `"agua"` o `"combustible"`.
  - Para `tuberia`: el puerto sea de `"agua"`, `"crudo"` o `"combustible"`.
  - Si no coincide (o si el puerto es de `"crudo"` y el ducto es un acueducto), se rechaza.

### 4.2 Restricción de Un Solo Fluido por Línea
- Una línea continua de canalización solo puede transportar un fluido específico.
- Si una red se conecta a un puerto de salida de `"crudo"`, toda la red queda asignada a `"crudo"`. Si el trazado intenta conectarla a un puerto de entrada de `"agua"`, la validación falla con error: `"No se pueden conectar puertos de fluidos diferentes."`

---

## 5. Simulación de Flujo y Derrames

### 5.1 Transporte Instantáneo
- En cada ciclo económico de `Economia.gd` (`_avanzar_produccion()`):
  - Para cada edificio con producción de líquido:
    - Se evalúa si su puerto de salida tiene una red conectada en `Canalizaciones`.
    - La red busca si tiene al menos un receptor válido alcanzable:
      - Puerto de entrada del mismo recurso en un edificio consumidor activo (ej. `refineria_petrolera`, `productor_combustible`, `central_termoelectrica`).
      - Puerto de entrada de un `almacen`.
    - Si existe receptor válido: el fluido se transfiere instantáneamente.

### 5.2 Almacén Compartido
- Cuando el fluido entra a un `almacen`:
  - Se suma a `Economia.reserva_fluidos` (o stock de fluidos de la ciudad).
  - Cualquier otro `almacen` en el mapa tiene acceso inmediato a ese inventario para abastecer a consumidores conectados a sus puertos de salida.
  - El núcleo tradicional (`id_nucleo`) no almacena fluidos.

### 5.3 Derrames (Spills)
- Si un productor bombea líquido hacia una red que:
  - Termina en un extremo abierto sin puerto.
  - No tiene consumidores con capacidad disponible ni almacenes conectados.
- **Efectos:**
  1. El recurso bombeado se pierde ese ciclo.
  2. En la celda inmediata adyacente al extremo abierto del ducto, se genera un bloque del líquido (`agua`, `crudo` o `combustible`).
  3. El bloque fluido escurre inmediatamente usando la propagación de fluidos en cascada de `VoxelWorld.gd`.
  4. El estado del puerto y la red se marca con `derrame = true`.
  5. Se emite notificación al HUD y `PanelPuesto` muestra el puerto en rojo con advertencia de derrame.

---

## 6. Interfaz de Usuario y Controles

### 6.1 Barra de Modos (`BarraModos.gd`)
- Se añade la categoría **6: Ductos**:
  - `CATEGORIAS.append(["ductos", "Ductos", "6"])`
  - Submenú:
    - `["acueducto", "Acueducto", "1"]` -> Atajo `1-6-1`.
    - `["tuberia", "Tubería", "2"]` -> Atajo `1-6-2`.

### 6.2 Interacción en `CamaraCenital.gd`
- Modo `modo_trazar_ducto`:
  - Clic izquierdo: fija origen o punto de inflexión.
  - Mover mouse: previsualiza ducto elevado a $Y+4$, columnas y pasos a desnivel.
  - HUD contextual: longitud, columnas, coste de materiales.
  - Doble clic o clic en puerto de destino: confirma el trazado, cobra materiales y coloca los bloques en `VoxelWorld`.
  - Clic derecho o Esc: cancela el trazado.

### 6.3 Panel de Edificio (`PanelPuesto.gd`)
- Lista los puertos con indicadores de color y estado:
  - Verde: `Conectado` (flujo activo).
  - Gris: `Desconectado` (sin canalización).
  - Rojo parpadeante/destacado: `Derrame` (pérdida activa de recurso).

---

## 7. Estrategia de Pruebas (TDD)

1. `CanalizacionesTest.gd`:
   - Registro de acueductos y tuberías, columnas automáticas cada 5 bloques y esquinas.
   - Conexión a puertos y compatibilidad de recursos.
   - Cruces a desnivel (+1 altura en intersección).
   - Detección de derrames en extremos abiertos y vertido de bloques de fluido (`agua`, `crudo`, `combustible`).
   - Red de almacenes compartida.
2. `TranslucidosRendererTest.gd` y `VoxelWorldTest.gd`:
   - Bloque `combustible` como fluido translúcido ámbar.
   - Escurrimiento en cascada de derrames de combustible y crudo.
3. `HUDTest.gd` y `BarraModosTest.gd`:
   - Menú 6-1 y 6-2 para Acueductos y Tuberías.
   - Visualización de estado de puertos en `PanelPuesto`.

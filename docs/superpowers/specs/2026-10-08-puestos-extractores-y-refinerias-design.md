# Diseño: Puestos Extractores y Modificación de Edificios de Refinerías (Etapa 9.2)

Fecha: 2026-10-08  
Rama objetivo: `feature/subsuelo-bloques` (worktree `.worktrees/subsuelo-bloques`)  
Hito: Paso 9 — Funcionamiento de líquidos y puestos de bombeo (Etapa 9.2)

---

## 1. Contexto y Objetivos

La Etapa 9.1 introdujo la generación procedimental de pozos subterráneos de agua y crudo, el bloque fluido translúcido `crudo` con física y viscosidad, y los 6 bloques de puertos de conexión (`puerto_*_in/out`).

La **Etapa 9.2** implementa:
1. **Estación de bombeo (`estacion_bombeo`)**: puesto para extracción de agua superficial sobre pilotes en agua con profundidad $\ge 2$ bloques.
2. **Centro de extracción (`centro_extraccion`)**: puesto para extracción subterránea con columna de perforación de `estructura_hierro` hasta el fondo del pozo, costo dinámico, y agotamiento real de bloques de crudo (el agua es inagotable).
3. **Puesto Almacén (`almacen`)**: plantilla de almacenamiento 5x5 con baúl interior y los 6 puertos de líquidos en sus paredes exteriores, con disponibilidad líquida global instantánea entre almacenes (el Núcleo Urbano no almacena líquidos).
4. **Modificación de edificios industriales**:
   - Supresión total de acarreo de recursos líquidos (`agua`, `crudo`, `combustible`).
   - `refineria_petrolera`: puertos `puerto_crudo_in` y `puerto_combustible_out`, 100% operada por técnicos sin acarreadores.
   - `productor_combustible`: puertos `puerto_agua_in` y `puerto_combustible_out`, acarreadores únicamente para el insumo sólido (`carbon`).
   - `central_termoelectrica`: puertos `puerto_combustible_in` y `puerto_crudo_in`, con selector de combustible en su interfaz (`Carbón`, `Combustible`, `Crudo`). Permite acarreadores solo en modo `Carbón`.
5. **Interfaz de interacción**:
   - Visualización de puertos y estado de conexión en ventanas de puestos y refinerías.
   - Indicador de crudo restante en el pozo del Centro de Extracción.
   - Selector de combustible en la Central Termoeléctrica.

---

## 2. Plantillas y Puertos (`PlantillasPuesto.gd`)

### 2.1 Mapeo de caracteres para bloques de puerto
En `PlantillasPuesto.BLOQUES`:
- `"1"`: `"puerto_agua_in"`
- `"2"`: `"puerto_agua_out"`
- `"3"`: `"puerto_crudo_in"`
- `"4"`: `"puerto_crudo_out"`
- `"5"`: `"puerto_combustible_in"`
- `"6"`: `"puerto_combustible_out"`

### 2.2 Nuevas Plantillas
- **`estacion_bombeo`**: 4x6 (madera/piedra), losa en tierra en filas 0-3 y muelle sobre agua en filas 4-5.
  - Carácter `"2"` (`puerto_agua_out`) en una de sus paredes exteriores sobre tierra.
  - Puerta `"d"` en fachada z=0. Baúl `"B"` interior.
  - `"agua_ref"` en Vector2i(0, 5) para orientación hacia el agua.
- **`centro_extraccion`**: 5x5 (`estructura_hierro`).
  - Puerta `"d"` en z=0. Baúl `"B"` interior.
  - Celda central (x=2, z=2) reservada como punto de perforación (`"perforacion": Vector2i(2, 2)`).
  - En paredes exteriores: `"2"` (`puerto_agua_out`) y `"4"` (`puerto_crudo_out`).
- **`almacen`**: 5x5 (`bloque_piedra`), losa en fila 0 y muros en filas 1-2:
  - Cara frontal (z = 0): 2 puertas (entrada `"e"` y salida `"s"`), ej. `"#e#s#"`.
  - Cara posterior (z = 4): ventana centrada (`"V"`), ej. `"##V##"`.
  - Cara lateral izquierda (x = 0): los 3 puertos de entrada juntos (`"1"` agua, `"3"` crudo, `"5"` combustible).
  - Cara lateral derecha (x = 4): los 3 puertos de salida juntos (`"2"` agua, `"4"` crudo, `"6"` combustible).
  - Interior: baúl central o lateral (`"B"`). Techo en capa superior.

### 2.3 Modificación de Plantillas Existentes
- **`refineria_petrolera`**:
  - Reemplazar puerta de servicio de entrada `"e"` por `"3"` (`puerto_crudo_in`) y puerta de salida `"s"` por `"6"` (`puerto_combustible_out`). Añadir puerta de personal `"d"`.
- **`productor_combustible`**:
  - Conservar `"e"` para acarreo de carbón. En pared lateral añadir `"1"` (`puerto_agua_in`). En salida reemplazar `"s"` por `"6"` (`puerto_combustible_out`).
- **`central_termoelectrica`**:
  - Conservar `"e"` para acarreo de carbón. En paredes laterales añadir `"5"` (`puerto_combustible_in`) y `"3"` (`puerto_crudo_in`).

---

## 3. Emplazamiento y Perforación Dinámica (`CamaraCenital.gd`)

### 3.1 `estacion_bombeo`: Validación de agua superficial
- Al emplazar, se valida que el extremo de agua caiga en agua abierta.
- **Profundidad mínima:** Para cada columna del muelle en agua, se verifica que `mundo.altura_en(x, z) - fondo_roca >= 2` (al menos 2 bloques de profundidad de agua). Si no cumple, rechaza con aviso: *"La estación de bombeo requiere al menos 2 bloques de profundidad de agua bajo su muelle."*

### 3.2 `centro_extraccion`: Detección de pozo y costo dinámico
- Al mover la previsualización:
  - Se toma la celda de perforación en coordenadas del mundo: `columna_centro = esquina + local_perforacion`.
  - Se escanea verticalmente hacia abajo buscando pozo (`generador.es_pozo_en(x, y, z)` o bloques de agua/crudo subterráneos en `mundo`).
  - Si no se detecta ningún pozo, la previsualización es inválida (*"No se detecta depósito subterráneo de agua o crudo"*).
  - Si se detecta pozo:
    - Se determina el punto más alto del pozo $Y_{tope}$ y el fondo del pozo $Y_{fondo}$.
    - La columna de perforación se extiende desde $Y_{superficie}$ hasta $Y_{fondo}$.
    - Longitud $H = Y_{superficie} - Y_{fondo}$.
    - **Costo dinámico:** Se suma $H \times \text{estructura\_hierro}$ a los costos requeridos del edificio.
    - Se guardan los metadatos de perforación: `{"perforacion": columna_centro, "y_superficie": Y_sup, "y_fondo": Y_fondo, "tipo_pozo": tipo_pozo, "bloques_hierro": H}`.

### 3.3 Construcción y Deconstrucción de la Tubería
- **Al completar la construcción del centro de extracción:**
  - En la columna de perforación, desde $Y_{superficie}-1$ hacia abajo hasta $Y_{fondo}$:
    - Si el bloque es roca/tierra, se mina/reemplaza.
    - Si el bloque es líquido (agua o crudo), se drena/reemplaza.
    - Se coloca un bloque `estructura_hierro`.
- **Al deconstruir el centro:**
  - Los $H$ bloques de `estructura_hierro` de la tubería se retiran y se reembolsan íntegramente al inventario/almacén (`Ciudad.almacen["estructura_hierro"].agregar(H)`).

---

## 4. Dinámica de Extracción y Agotamiento de Crudo (`Recoleccion.gd` & `Economia.gd`)

### 4.1 Tipos y Tasas de Extracción
- `estacion_bombeo`: Tasa continua de agua (`tasa_agua = 2.0` por técnico presente). Inagotable.
- `centro_extraccion`:
  - Si extrae agua: tasa continua de agua. Inagotable.
  - Si extrae crudo: tasa continua de crudo.
    - **Agotamiento real:** Con cada ciclo de producción, se busca el bloque de `crudo` conectado de mayor $Y$ en el pozo y se reemplaza por `aire` (o se drena).
    - Se decrementa el contador de crudo restante del pozo.
    - Cuando no quedan bloques de crudo conectados, el pozo se declara agotado (`p["agotado"] = true`) y la tasa cae a 0.

---

## 5. Modificación del Flujo Industrial y Acarreo (`Economia.gd`)

### 5.1 Restricción de Acarreo de Líquidos
- Constante: `RECURSOS_LIQUIDOS = ["agua", "crudo", "combustible"]`.
- En `insumos_a_cargar(esquina)`: nunca incluye ningún recurso líquido.
- En `recoger(esquina)` / `recoger_producto(esquina)`: nunca entrega ningún recurso líquido a acarreadores.

### 5.2 Roles y Cupos
- `estacion_bombeo` y `centro_extraccion`:
  - `cupo = 3`.
  - `roles_de(esquina)`: `["tecnico"]` (mínimo 1 técnico para producir). Sin acarreadores.
- `refineria_petrolera`:
  - `roles_de(esquina)`: `["tecnico"]`. Sin acarreadores.
- `productor_combustible`:
  - `roles_de(esquina)`: `["tecnico", "acarreador"]`. Acarreador solo transporta carbón.
- `central_termoelectrica`:
  - Se añade propiedad al puesto: `combustible_activo` (`"carbon"` por defecto, seleccionable entre `"carbon"`, `"combustible"`, `"crudo"`).
  - Si `combustible_activo == "carbon"`: `roles_de` incluye `acarreador`.
  - Si `combustible_activo != "carbon"`: `roles_de` no incluye `acarreador` (solo `tecnico`). Los acarreadores asignados previamente se liberan automáticamente al cambiar de modo.

### 5.3 Edificio Almacén y Líquidos Globales
- **Categoría y Zonificación:**
  - El puesto `almacen` se clasifica en `PUESTOS_INDUSTRIAL` (menú Construir > Industrial, tecla 8).
  - Como edificio urbano industrial, **debe construirse dentro de la zona de influencia y estrictamente sobre Zona Industrial pintada (`fabricacion_militar`)**. No es un puesto periférico.
- **Líquidos globales:**
  - Todo ingreso de líquidos a un puesto `almacen` se transfiere inmediatamente a `Ciudad.almacen` (disponibilidad líquida global entre almacenes).
  - El Núcleo Urbano no almacena líquidos (`Ciudad.almacen` central actúa como la red de almacenes; el Núcleo como edificio físico no tiene puertos).

---

## 6. Interfaz de Usuario y Ventanas de Interacción (`HUD.gd` / `PanelPuesto.gd`)

1. **Estado de Puertos:**
   - En puestos extractores, refinerías, almacenes y central termoeléctrica, mostrar lista de puertos del edificio, recurso correspondiente, dirección (`IN`/`OUT`) y estado (p. ej., *"Desconectado"* en 9.2, preparado para la red de tuberías de 9.3).
2. **Centro de Extracción:**
   - Mostrar recurso extraído (`Agua` o `Crudo`). Si es crudo, mostrar barra/contador: *"Crudo restante en el pozo: X bloques"*.
3. **Central Termoeléctrica:**
   - Selector interactivo de combustible con 3 opciones: `[Carbón]` (acarreo habilitado), `[Combustible]` (puerto IN), `[Crudo]` (puerto IN).

---

## 7. Plan de Verificación y Pruebas

- Pruebas unitarias en `PlantillasPuestoTest.gd`:
  - Dimensiones, puertos y celdas de `estacion_bombeo`, `centro_extraccion`, `almacen`.
  - Verificación de puertos en `refineria_petrolera`, `productor_combustible`, `central_termoelectrica`.
- Pruebas de economía y acarreo en `EconomiaTest.gd`:
  - No acarreo de líquidos en refinerías y central termoeléctrica.
  - Selección de combustible en central termoeléctrica y conmutación de acarreadores.
  - Centro de extracción y estación de bombeo: personal técnico sin acarreadores.
- Pruebas de extracción y agotamiento en `ExtraccionTest.gd`:
  - Cálculo dinámico de altura y costo de columna de `estructura_hierro`.
  - Consumo y desaparición de bloques de crudo del pozo de arriba hacia abajo.
  - Deconstrucción y reembolso de bloques de hierro.
  - Validación de profundidad $\ge 2$ para estación de bombeo.

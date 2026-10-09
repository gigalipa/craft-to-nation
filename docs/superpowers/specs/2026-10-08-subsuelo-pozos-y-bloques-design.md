# Especificación de Diseño: Etapa 9.1 - Subsuelo, Pozos de Líquidos y Bloques de Puertos

**Fecha:** 2026-10-08  
**Autor:** Antigravity / Pair Programming  
**Estado:** Propuesto (Pendiente de Aprobación)  
**Contexto del Proyecto:** Craft to Nation - Paso 9 (Fluidos, Extracción y Red de Tuberías)

---

## 1. Visión General y Objetivos

La **Etapa 9.1** sienta las bases de mundo, bloques y física para el sistema de fluidos naturales y transporte por tuberías. En el juego existen tres líquidos: **agua**, **crudo** y **combustible**. En la naturaleza solo existen agua y crudo:
- El agua superficial ya existe (mares, lagos y ríos).
- Los mundos pueden carecer de agua superficial, por lo que el agua también debe existir en el subsuelo.
- El crudo existe exclusivamente en el subsuelo en depósitos naturales (pozos).
- Para la posterior colocación de tuberías e industrias (Etapas 9.2 y 9.3), se requieren bloques de interfaz ("puertos") normalizados en el catálogo de bloques.

### Objetivos Principales
1. **Generación de Pozos Subterráneos en `GeneradorMundo.gd`:** Generación de depósitos 3D de celdas líquidas (`agua` y `crudo`) en el subsuelo por debajo de la capa vegetal, garantizando de forma estricta que **ningún pozo mezcle agua y crudo**.
2. **Bloque `crudo` y Física de Fluidos:** Integración del bloque `crudo` en `VoxelWorld.gd` y `TranslucidosRenderer.gd` (no sólido, translúcido oscuro con culling de caras internas), físicas de inmersión y viscosidad en `Player.gd` y reglas de escurrimiento reducido.
3. **Bloques de Puertos de Conexión:** Registro formal de 6 bloques funcionales de puertos en `VoxelWorld.gd` (`puerto_agua_in`, `puerto_agua_out`, `puerto_crudo_in`, `puerto_crudo_out`, `puerto_combustible_in`, `puerto_combustible_out`) con apariencia distintiva y funciones de consulta para su uso posterior en plantillas de edificios y tuberías.

---

## 2. Especificación Detallada por Componente

### 2.1 Generador de Mundo (`GeneradorMundo.gd`)

#### Parámetros y Ruido 3D
- **Profundidad Mínima:** Los pozos solo se generan a partir de `PROFUNDIDAD_POZOS = 4` bloques bajo la superficie, garantizando que nunca rompan la capa de tierra fértil o el relieve visible al caminar.
- **Ruido 3D de Bolsas (`_ruido_pozos`):** Generador `FastNoiseLite` 3D (Perlin, baja frecuencia `0.04`, semilla `semilla + 10`) con umbral `UMBRAL_POZO = 0.50` para delimitar bolsas cavernosas compactas y continuas.
- **Exclusión Mutua Estricta (`_ruido_tipo_pozo`):**
  - Un generador de ruido 2D/3D de muy baja frecuencia (`frequency = 0.01`, semilla `semilla + 11`).
  - Para cada celda que califique como pozo (`ruido_pozos > UMBRAL_POZO`):
    - Si `_ruido_tipo_pozo.get_noise_2d(x, z) > 0.0`: el pozo entero en esa cuenca regional es **`crudo`**.
    - Si `_ruido_tipo_pozo.get_noise_2d(x, z) <= 0.0`: el pozo entero es **`agua`**.
  - Dado que la frecuencia regional de tipo es mucho menor que la escala de las bolsas individuales, cada pozo conectado queda asignado 100% a un único líquido.

#### Flujo en `tipo_en_profundidad(x, y, z, profundidad)`
```text
1. Si profundidad < GROSOR_TIERRA (1 bloque):
   -> "tierra"
2. Si profundidad >= PROFUNDIDAD_POZOS:
   -> Evaluar _ruido_pozos.get_noise_3d(x, y, z)
   -> Si supera UMBRAL_POZO:
        retornar "crudo" si _ruido_tipo_pozo > 0 else "agua"
3. Si no es pozo, continuar con la jerarquía existente de minerales:
   -> tierras_raras, hierro, cobre, carbon, piedra
```

---

### 2.2 Bloque `crudo` y Renderizado (`VoxelWorld.gd` y `TranslucidosRenderer.gd`)

#### Registro en `VoxelWorld.gd`
- Se incorpora `"crudo"` a la lista `TIPOS_TRANSLUCIDOS` y a `TIPOS_LIQUIDOS`.
- En `_indexar_biblioteca()`:
  - Si `"crudo"` está registrado en la biblioteca o se añade dinámicamente, se le desactiva colisión sólida en el GridMap (`set_item_shapes([], id)`), permitiendo atravesarlo exactamente igual que el agua.
- **Escurrimiento de Crudo:**
  - El crudo tiene viscosidad superior:
    - Longitud máxima de escurrimiento horizontal: 3 celdas (frente a 7 del agua).
    - Intervalo de caída/propagación: el doble de tiempo que el agua para reflejar densidad.

#### Renderizado en `TranslucidosRenderer.gd`
- Se crea `MATERIAL_CRUDO`:
  - `albedo_color = Color(0.06, 0.05, 0.04, 0.94)` (negro petróleo con leve tono ambarino muy oscuro).
  - `roughness = 0.1` y `specular = 0.8` para brillo superficial aceitoso.
  - `transparency = BaseMaterial3D.TRANSPARENCY_ALPHA`.
  - `render_priority = 2`.
- Culling de caras internas: dos celdas contiguas de `crudo` no dibujan su cara compartida.
- La cara superior dibuja la superficie líquida.

---

### 2.3 Física e Inmersión del Avatar (`Player.gd`)

- **Detección de Inmersión:**
  - `_profundidad_liquido_en()` generaliza la consulta para evaluar tanto `"agua"` como `"crudo"`.
  - Se distingue `en_crudo` vs. `en_agua`.
- **Física Viscosa en Crudo:**
  - **Velocidad Horizontal:** multiplicador `0.5` sobre la velocidad normal (mayor resistencia que el agua, que usa `0.75`).
  - **Gravedad y Caída:** la velocidad vertical terminal se limita a un valor más lento (`-1.5` m/s frente a `-3.0` m/s en agua), simulando alta flotabilidad/densidad viscosa.
  - **Oxígeno y Ahogamiento:** si `_cabeza_sumergida()` detecta `crudo`, el consumo de oxígeno se activa con la misma tasa de supervivencia que en agua.

---

### 2.4 Bloques de Puertos de Conexión

Se formalizan 6 tipos de bloques en `VoxelWorld.gd` con sus identificadores textuales estándar:
1. `puerto_agua_in`: Puerto de entrada para acueductos/tuberías de agua.
2. `puerto_agua_out`: Puerto de salida de agua.
3. `puerto_crudo_in`: Puerto de entrada para tuberías de crudo.
4. `puerto_crudo_out`: Puerto de salida de crudo.
5. `puerto_combustible_in`: Puerto de entrada para acueductos/tuberías de combustible.
6. `puerto_combustible_out`: Puerto de salida de combustible.

#### Representación Visual
- Si no existen mallas dedicadas en `BlockLibrary.res`, `VoxelWorld` los inicializa dinámicamente con `BoxMesh` y materiales con codificación visual estándar:
  - Cuerpo del bloque: metálico/industrial oscuro (`Color(0.25, 0.25, 0.28)`).
  - Color temático por líquido:
    - Agua: Azul cian (`Color(0.15, 0.60, 0.95)`).
    - Crudo: Ámbar / Oro viejo oscuro (`Color(0.85, 0.65, 0.15)`).
    - Combustible: Naranja rojizo (`Color(0.95, 0.35, 0.10)`).
  - Entrada (`_in`): tono más claro / brillante en el borde.
  - Salida (`_out`): tono más oscuro / saturado.

#### Métodos de Consulta en `VoxelWorld.gd`
- `static func es_puerto(tipo: String) -> bool`
- `static func recurso_de_puerto(tipo: String) -> String` (`"agua"`, `"crudo"`, `"combustible"`)
- `static func direccion_de_puerto(tipo: String) -> String` (`"in"`, `"out"`)

---

## 3. Plan de Verificación y Pruebas

1. **`GeneradorMundoTest.gd`:**
   - Test de generación de pozos de agua y crudo por debajo de `PROFUNDIDAD_POZOS`.
   - Test de exclusión mutua: confirmar que en un muestreo exhaustivo del mapa ninguna celda adyacente líquida combina agua y crudo dentro del mismo pozo.
2. **`TranslucidosRendererTest.gd`:**
   - Test de renderizado de `crudo` con culling de caras internas.
3. **`PlayerNatacionTest.gd`:**
   - Test de físicas de viscosidad y velocidad en `crudo`.
4. **`VoxelWorld` / Test Unitario:**
   - Test de identificación de puertos (`es_puerto`, `recurso_de_puerto`, `direccion_de_puerto`).
5. **Verificación Global:**
   - Ejecución de `tools/run-godot-tests.ps1` asegurando que las 26 escenas pasen con 0 errores.

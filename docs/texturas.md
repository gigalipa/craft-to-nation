# Catálogo de Texturas del Mundo — Craft to Nation

Lista completa de las texturas necesarias para el mundo vóxel de *Craft to Nation*, relevada contra `godot/scenes/BlockLibrarySource.tscn`, `godot/scripts/VoxelWorld.gd`, `godot/scripts/TranslucidosRenderer.gd`, `godot/scripts/ViasRenderer.gd`, `godot/scripts/Puertas.gd`, `godot/scripts/Ciudad.gd` y `godot/scripts/Hotbar.gd`.

Actualmente el proyecto solo cuenta con `godot/assets/tex_ventana.png` (`godot/assets/mat_ventana.tres`); el resto del mundo utiliza colores sólidos (`albedo_color`).

---

## 1. Bloques Estructurales con Variantes por Recurso de Origen

En `Ciudad.gd` y `Hotbar.gd`, la construcción consume primero el recurso procesado (`tablas`, `bloques_piedra`, `vidrio`) y recurre al recurso bruto (`madera`, `piedra`, `3 × tierra`) cuando no hay procesado. Para diferenciar visualmente el material usado se requieren **6 texturas**:

| Bloque en código | Recurso consumido | Textura sugerida | Aspecto visual recomendado |
| :--- | :--- | :--- | :--- |
| `bloque_madera` | `tablas` | `tex_bloque_madera_tablas.png` | **Tablones cepillados y ensamblados**, vetas uniformes, juntas rectas y tono miel claro (`#bf8c4d`). |
| `bloque_madera` | `madera` | `tex_bloque_madera_cruda.png` | **Troncos rústicos / leños desbastados** apilados con uniones irregulares y tono más oscuro (`#73471f`). |
| `bloque_piedra` | `bloques_piedra` | `tex_bloque_piedra_tallada.png` | **Sillería o ladrillos de piedra cortada** con mortero limpio y aristas regulares. |
| `bloque_piedra` | `piedra` | `tex_bloque_piedra_rustica.png` | **Mampostería de piedra bruta / canto rodado** irregular y sin labrar. |
| `vidrio` | `vidrio` | `tex_ventana_vidrio.png` | **Panel de cristal transparente** (1/20 de espesor en `TranslucidosRenderer.gd`) con marco fino, brillo limpio y alta transparencia (reemplaza/mejora `tex_ventana.png`). |
| `vidrio` | `tierra` (×3) | `tex_ventana_tierra.png` | **Celosía primitiva / marco de barro o madera rústica** con abertura semitraslúcida opaca (pergamino/mica o barro horneado), claramente más rústica y menos luminosa que el vidrio. |

> **Nota de implementación:** actualmente solo existe un ítem `bloque_madera`, un `bloque_piedra` y un `vidrio`. Al incorporar estas texturas, habrá que registrar las variantes visuales en `BlockLibrarySource.tscn` / `VoxelWorld.gd` y `TranslucidosRenderer.gd` utilizando el desglose que devuelve `Ciudad.consumir_costo_con_detalle()`.

---

## 2. Bloques Estructurales Restantes

| Bloque en código | Referencia | Textura(s) sugerida(s) | Descripción |
| :--- | :--- | :--- | :--- |
| `adobe` (`tierra_compactada` en `.tscn`) | `BlockLibrarySource.tscn` | `tex_adobe.png` | Tierra compactada / ladrillo de barro secado al sol con textura terrosa cálida. |
| `estructura_hierro` | `BlockLibrarySource.tscn` | `tex_estructura_hierro.png` | Vigas o celosía metálica de hierro remachado (forjado oscuro). |
| `bloque_acero` | `BlockLibrarySource.tscn` | `tex_bloque_acero.png` | Planchas industriales de acero pulido/cepillado con juntas y remaches. |

---

## 3. Terreno Natural, Subsuelo y Vegetación

| Bloque en código | Caras necesarias | Textura(s) sugerida(s) | Descripción |
| :--- | :--- | :--- | :--- |
| `hierba` | **3** (arriba, lado, abajo) | `tex_hierba_top.png`, `tex_hierba_side.png` *(abajo reutiliza `tex_tierra.png`)* | Césped natural arriba; franja de césped cayendo sobre tierra en los lados. |
| `tierra` | 1 (todas) | `tex_tierra.png` | Tierra orgánica granular del subsuelo superficial. |
| `piedra` | 1 (todas) | `tex_piedra.png` | Roca natural gris del subsuelo (sin cortes de ladrillo). |
| `bedrock` | 1 (todas) | `tex_bedrock.png` | Roca madre muy oscura, densa e irregular (inminable). |
| `hierro` | 1 (todas) | `tex_mena_hierro.png` | Roca base con vetas óxido/cobrizas de mineral de hierro. |
| `carbon` | 1 (todas) | `tex_mena_carbon.png` | Roca base con vetas negras brillantes de carbón. |
| `cobre` | 1 (todas) | `tex_mena_cobre.png` | Roca base con vetas verde-turquesa / cobrizas. |
| `tierras_raras` | 1 (todas) | `tex_mena_tierras_raras.png` | Roca oscura con vetas cristalinas púrpura/turquesa. |
| `madera` (árbol) | **2** (lado, top/bottom) | `tex_tronco_corteza.png`, `tex_tronco_anillos.png` | Corteza natural vertical en los lados; anillos de madera cortada arriba/abajo. |
| `follaje` | 1 (todas) | `tex_follaje.png` | Hojas densas de copa de árbol (opaca o con recorte alpha `ALPHA_SCISSOR`). |

---

## 4. Vías y Cuñas de Tierra Pisada

En `ViasRenderer.gd` y las 7 cuñas de `BlockLibrarySource.tscn` (`cuna_recta`, `cuna_esquina`, `cuna_diag_bajo`, `cuna_diag_arriba`, `cuna_diag_lat_izq`, `cuna_diag_lat_der`, `diag_lat`):

| Material / Bloque | Textura sugerida | Descripción |
| :--- | :--- | :--- |
| `mat_tierra_pisada.tres` + 7 cuñas | `tex_tierra_pisada.png` | Camino de tierra apisonada/compactada con huellas sutiles de tránsito (tiling limpio para tramos rectos y diagonales). |

---

## 5. Puertas y Mobiliario Interior

| Elemento en código | Caras / piezas | Textura(s) sugerida(s) | Descripción |
| :--- | :--- | :--- | :--- |
| `puerta_inferior` / `puerta_superior` (`Puertas.gd`) | Lámina `1×2×0.1` + herrajes | `tex_puerta_madera.png` *(opcional: `tex_metal_herraje.png` para bisagras/picaporte)* | Hoja de puerta de madera con listones verticales/travesaño. |
| `cama_cabecera` + `cama_pies` | 2 bloques (cabecera / pies) | `tex_cama_cabecera.png`, `tex_cama_pies.png` | Madera + almohada en cabecera; manta/colcha doblada en pies. |
| `baul` | Frente, lados, tapa | `tex_baul_frente.png`, `tex_baul_lado.png`, `tex_baul_top.png` *(o 1 textura atlas/única)* | Cofre de madera con refuerzos metálicos y cerradura frontal. |
| `mesa_estudio` | Tapa superior + patas/lados | `tex_mesa_estudio_top.png`, `tex_mesa_estudio_lado.png` | Escritorio de madera con pergaminos/planos/libros dibujados arriba. |

---

## 6. Fluidos (`TranslucidosRenderer.gd`)

| Fluido en código | Material actual | Textura sugerida | Descripción |
| :--- | :--- | :--- | :--- |
| `agua` | `mat_agua.tres` | `tex_agua.png` *(+ opcional `tex_agua_normal.png`)* | Superficie azul translúcida con ondas suaves tileables (lagos, ríos y cascadas). |
| `crudo` | `_crear_material_crudo()` | `tex_crudo.png` | Líquido viscoso negro/marrón muy oscuro casi opaco con brillo aceitoso. |
| `combustible` | `_crear_material_combustible()` | `tex_combustible.png` | Líquido ámbar/dorado translúcido refinado. |

---

## 7. Canalizaciones y Puertos de Fluidos (`VoxelWorld.gd` / `Canalizaciones.gd`)

Definidos dinámicamente en `VoxelWorld.gd`:

| Elemento en código | Cantidad | Textura(s) sugerida(s) | Descripción |
| :--- | :--- | :--- | :--- |
| `acueducto`, `acueducto_lineal`, `acueducto_quiebre` | 1 compartida | `tex_ducto_acueducto.png` | Canal abierto/cerrado de piedra tallada y madera. |
| `tuberia`, `tuberia_lineal`, `tuberia_quiebre` | 1 compartida | `tex_ducto_tuberia.png` | Tubería industrial de acero con bridas/anillos de unión. |
| `puerto_agua_in` / `puerto_agua_out` | 2 | `tex_puerto_agua_in.png`, `tex_puerto_agua_out.png` | Caja técnica con boca azul y símbolo/flecha de entrada vs. salida. |
| `puerto_crudo_in` / `puerto_crudo_out` | 2 | `tex_puerto_crudo_in.png`, `tex_puerto_crudo_out.png` | Caja técnica con boca marrón/negra y símbolo de entrada vs. salida. |
| `puerto_combustible_in` / `puerto_combustible_out` | 2 | `tex_puerto_combustible_in.png`, `tex_puerto_combustible_out.png` | Caja técnica con boca ámbar y símbolo de entrada vs. salida. |

---

## 8. Bloques Legacy y Overlays (Opcionales)

- **Bloques legacy en `BlockLibrarySource.tscn`:** `mina`, `puesto_caza`, `puesto_madero`, `puesto_pesca` (y `pared`, `piso`). Hoy existen solo como bloques de compatibilidad; no requieren textura prioritaria salvo que se decida mantenerlos estilizados.
- **Fantasma de obra (`fantasma`):** conviene mantenerlo sin textura (color translúcido `#99d9ff59`) o con un patrón muy sutil de plano/cuadrícula (`tex_fantasma.png`) para distinguirlo claramente de los bloques construidos.

---

## 9. Resumen Numérico y Especificación Técnica Recomendada

- **Total aproximado:** **38 texturas Albedo** (40 incluyendo `tex_fantasma.png` y `tex_metal_herraje.png`; más mapas opcionales `normal` / `roughness` para relieve PBR en piedra, agua y metales).
- **Formato:** `.png` sin pérdidas, **seamless (tileables)** en todas las caras continuas.
- **Resolución recomendada:** `64×64` o `128×128` px para estilo voxel/pixel-art nítido (`FILTER_NEAREST`), o `256×256` / `512×512` px para acabado pictórico/estilizado (`FILTER_LINEAR_WITH_MIPMAPS`).
- **Carpeta sugerida:** `godot/assets/texturas/bloques/`.

# Diseño: PoC 5, sub-proyecto 2C (parte 1) — Costo de colocación y bloques estructurales reales

Ver punto 4 de `docs/Pendientes y próximos pasos.md` ("PoC 5, sub-proyecto 2C — transformación"). Esta pieza cubre solo la mitad de "costo de colocación + reembolso"; las refinerías reales colocables (aserradero, carbonera, siderúrgica, refinería de tierras raras) quedan como una segunda pieza separada, con su propio spec.

Decisiones confirmadas con el usuario (2026-09-29), en orden de aparición durante el brainstorming.

## 1. Alcance

**Dentro:**
- Renombrar el bloque natural de superficie `piso` → `hierba` (sigue sin ser estructural, sigue rindiendo `tierra` al minarlo).
- Nuevo bloque natural `tierra`: el jugador lo coloca a mano para nivelar/rellenar terreno (mismo uso que ya tenía el relleno de blueprints, ahora con tipo propio en vez de reutilizar `piso`).
- Reemplazar el único material estructural placeholder (`pared`) por materiales reales, ya con mesh en `arte/dae/bloques.dae`: `tierra_compactada`, `bloque_madera`, `bloque_piedra`, `estructura_hierro`.
- Renombrar `ventana` → `vidrio` (mismo comportamiento translúcido; ahora es un material real con costo).
- Costo en recurso crudo al colocar cualquiera de estos bloques desde la hotbar del avatar (clic derecho, `Player._colocar()`), descontado del almacén central (`Ciudad.almacen`, el mismo stock que llena la extracción).
- Reembolso simétrico: volver a minar un bloque que el jugador colocó devuelve exactamente lo que costó colocarlo (ya decidido el principio general el 2026-09-28; aquí se implementa con costos reales).
- Las 4 plantillas de puesto (`PlantillasPuesto.gd`) dejan de usar `pared` genérico y pasan a un material fijo coherente con la era prehistórica: mina → `tierra_compactada`, maderero → `bloque_madera`, caza y recolección → `bloque_madera`, pesca y frutos del mar → `bloque_piedra`.
- Generalizar el código que hoy compara contra el literal `"pared"` (`VoxelWorld.TIPOS_ESTRUCTURA`, `BlueprintValidator.TIPOS_CELDA_SOLIDA`/`TIPOS_ESTRUCTURALES`/`TIPOS_RELLENO_GENERICO` y su lógica de fusión de capas) para que acepte cualquiera de los 4 materiales de muro como intercambiables entre sí, igual que hoy solo aceptaba `pared`.
- Hotbar: mostrar la cantidad de bloques que el jugador todavía puede colocar de cada tipo (stock del recurso ÷ costo por bloque), reutilizando el campo `cantidad` que `Hotbar.gd` ya tiene (hoy oculto).

**Fuera (documentado, no se construye aquí):**
- `bloque_acero`: no tiene fuente real de `acero` todavía (`CadenaMinerales` solo opera en su demo aislada, no llega al almacén real de `Ciudad`) — queda pendiente hasta que exista la refinería real (segunda pieza de 2C).
- Selector de material para los blueprints de puestos: cada tipo de puesto queda con material fijo; elegir material por blueprint es un problema aparte, para cuando el arte defina las plantillas reales.
- Refinerías reales colocables (aserradero, carbonera, siderúrgica, refinería de tierras raras): segunda pieza de 2C, spec propio.
- Costo de colocación cobrado a los colonos/NPCs construyendo (depende del acarreo asistido por NPCs, punto 6 de Pendientes, todavía no implementado).
- Un edificio residencial ya declarado (construido bloque a bloque por el jugador a mano) no necesita ningún cambio de "selección de material": cada celda ya es el material real que el jugador puso al colocarla; declarar/registrar el edificio no toca su material.

## 2. Costos (recurso crudo : bloque colocado)

| Bloque | Costo | Reembolso al re-minar |
|---|---|---|
| `tierra` (natural) | 1 tierra | 1 tierra |
| `tierra_compactada` | 1 tierra | 1 tierra |
| `bloque_madera` | 5 madera | 5 madera |
| `bloque_piedra` | 5 piedra | 5 piedra |
| `estructura_hierro` | 5 hierro | 5 hierro |
| `vidrio` | 1 tierra | 1 tierra |
| `puerta` | 2 madera (ya documentado, "Ficha de Fábrica") | 2 madera |
| `cama` | 2 madera (ya documentado) | 2 madera |
| `baúl` | 1 madera (ya documentado) | 1 madera |

Una tabla nueva de datos puros (p.ej. `COSTO_COLOCACION: Dictionary` tipo -> {"recurso": String, "cantidad": int}) es la única fuente de verdad; la usan tanto el cobro al colocar como el reembolso al minar, para que nunca diverjan.

Colocar se rechaza con la misma notificación que ya usa `_avisar_colocacion_rechazada()` si `Ciudad.almacen[recurso]` no tiene suficiente (`Recurso.consumir()` ya hace la comprobación atómica: si devuelve `false`, no se cobra nada y no se coloca el bloque).

## 3. Bloques y renombres en el mundo

- `VoxelWorld.TIPOS_ESTRUCTURA` cambia de `["pared", ...]` a `["tierra_compactada", "bloque_madera", "bloque_piedra", "estructura_hierro", "puerta_inferior", "puerta_superior", "vidrio", "cama_cabecera", "cama_pies", "baul"]`.
- `VoxelWorld.MATERIAL_REAL` cambia su entrada de `"piso": "tierra"` a `"hierba": "tierra"` (mismo propósito: la extracción de `hierba` rinde `tierra`).
- El mesh de `pared` deja de usarse para colocar (el modelo `bloques.dae` ya trae los 6 mesh reales: `tierra`, `hierba`, `tierra_compactada`, `madera`→`bloque_madera`, `piedra`→`bloque_piedra`, `hierro_colocado`→`estructura_hierro`, `vidrio`; `acero` queda sin usar hasta la pieza de refinerías). Actualizar la `MeshLibrary` del proyecto para incluir los ítems nuevos con esos nombres exactos (mismo mecanismo que ya usa `_indexar_biblioteca()`, indexado por nombre).
- `Player.tipos_disponibles` pasa de `["pared", "puerta", "ventana", "piso", "cama", "baul"]` a `["tierra", "tierra_compactada", "bloque_madera", "bloque_piedra", "estructura_hierro", "vidrio", "puerta", "cama", "baul"]` (9 casillas, teclas 1-9). `Hotbar.NOMBRES` se actualiza con las etiquetas correspondientes.

## 4. Generalización de "pared" a familia de materiales

Tanto `VoxelWorld` como `BlueprintValidator` tienen lógica que hoy compara contra el literal `"pared"` asumiendo que es el único material de muro. Se generaliza a una constante compartida de "materiales de muro genéricos" (`tierra_compactada`, `bloque_madera`, `bloque_piedra`, `estructura_hierro`):

- `BlueprintValidator.TIPOS_CELDA_SOLIDA`/`TIPOS_ESTRUCTURALES`: pasan de `["pared", "puerta", "ventana"]` a incluir los 4 materiales de muro + `puerta` + `vidrio`.
- `BlueprintValidator.TIPOS_RELLENO_GENERICO`: pasa de `["pared"]` a los 4 materiales de muro (cualquiera de ellos, heredado de la plantilla de suelo/techo, sigue siendo "relleno genérico" que un material de muro real de otra capa puede sobrescribir).
- El chequeo de esquina (línea ~107, hoy `tipo != "pared"`) pasa a `not TIPOS_MURO_GENERICO.has(tipo)`.
- `estructura_a_blueprint()`: el remapeo de `puerta_superior` sigue igual (tapa el muro); la fusión de capas (línea ~664, hoy `tipo_capa != "pared"`) pasa a `not TIPOS_MURO_GENERICO.has(tipo_capa)` — dos materiales de muro distintos en la misma celda entre capas siguen sin competir entre sí (gana el último, igual que hoy dos "pared" no competían), solo un tipo especial (puerta/vidrio/cama/baúl) sigue ganando siempre.

Esto preserva el comportamiento actual (un solo material intercambiable) pero ya no asume que ese material se llama `"pared"`.

## 5. Plantillas de puesto (`PlantillasPuesto.gd`)

`BLOQUES["#"]` hoy mapea siempre a `"pared"`. Cada entrada de `PLANTILLAS` gana una clave `"material"` con el material fijo de ese puesto (`tierra_compactada`/`bloque_madera`/`bloque_piedra`); `celdas()` sustituye `"#"` por `PLANTILLAS[tipo]["material"]` en vez de usar el mapeo fijo de `BLOQUES`. `V`→`vidrio` (antes `ventana`) y `B`→`baul`, `d`/`D`→`puerta_inferior`/`puerta_superior` no cambian.

| Puesto | Material |
|---|---|
| Mina | `tierra_compactada` |
| Maderero | `bloque_madera` |
| Caza y recolección | `bloque_madera` |
| Pesca y frutos del mar | `bloque_piedra` |

## 6. Cobro y reembolso (`Player.gd`, `VoxelWorld.gd`)

- `Player._colocar()`: antes de `colocar_bloque`/`colocar_puerta`/`colocar_cama`, busca el tipo en `COSTO_COLOCACION`; si existe, llama a `Ciudad.almacen[recurso].consumir(cantidad)`. Si devuelve `false` (o el recurso no existe todavía en el almacén), rechaza la colocación con `_avisar_colocacion_rechazada("No hay suficiente %s para colocar: %s" % [recurso, tipo])` y no llama a `colocar_bloque`. Si devuelve `true` pero `colocar_bloque` igual falla (sitio ocupado, ver línea 804), se reembolsa de inmediato (`Ciudad.almacen[recurso].agregar(cantidad)`) para no perder el recurso.
- `VoxelWorld._retirar_bloque()`: si `colocado_por_jugador.has(celda)` y el tipo de esa celda está en `COSTO_COLOCACION`, reembolsa a `Ciudad.almacen[recurso]` antes de borrar la celda (necesita acceso a `Ciudad`, igual que ya lo tiene `Recoleccion`/`Economia` por inyección; `VoxelWorld` puede emitir una señal `bloque_reembolsado(recurso, cantidad)` que `Ciudad`/`Player` conecte, para no acoplar `VoxelWorld` directamente al autoload `Ciudad` — mismo patrón que `bloque_translucido_cambiado`/`puerta_cambiada`).
- La extracción de terreno NATURAL (`hierba`, minerales, árboles) no pasa por esta tabla: sigue rindiendo por `Recoleccion.RENDIMIENTO_POR_BLOQUE` como hoy, sin relación con `COSTO_COLOCACION`.

## 7. HUD (`Hotbar.gd`)

`Hotbar.set_cantidad(indice, cantidad)` ya existe y ya se usa por casilla; solo falta que algo la llame. `Player`/`HUD` recalculan, cada vez que cambia el almacén (mismo tick que ya refresca la ventana de Almacén) o al cambiar de tipo seleccionado, `floor(Ciudad.almacen[recurso].cantidad / costo)` para cada casilla con costo definido. `puerta`/`cama`/`baúl` ya tienen costo fijo en madera (ficha de fábrica), así que también muestran cantidad.

## 8. Pruebas

- `BlueprintValidatorTest`: casos que hoy usan `"pared"` a mano deben poder usar cualquiera de los 4 materiales de muro indistintamente (agregar un caso que mezcle dos materiales de muro en dos capas de la misma celda, para confirmar que no compiten entre sí).
- `RecoleccionTest`/`PuestosPrevisualizacionTest`: actualizar las plantillas esperadas de cada puesto a su nuevo material fijo.
- Nueva prueba (`VoxelWorldTest` o similar): colocar un bloque con costo, verificar que descuenta del almacén; colocar sin stock suficiente, verificar que rechaza y no descuenta; volver a minar un bloque colocado, verificar que reembolsa exactamente lo cobrado; minar terreno natural (`hierba`) no reembolsa ni consulta `COSTO_COLOCACION`.
- Verificación manual (Godot 4.7): colocar cada uno de los 9 tipos de la hotbar con stock suficiente e insuficiente, confirmar la cantidad mostrada en cada casilla, colocar y re-minar un `bloque_piedra` y confirmar que el almacén vuelve al valor original, declarar una mina/maderero/caza/pesca nuevos y confirmar el material de sus muros.

## 9. Documentación

Actualizar `docs/Fichas_Consumo_Produccion.md`: la sección "Extracción" pasa de "por definir"/"propuesta, sin cobrar" a "Implementado" con los costos de la tabla de la Sección 2 de este documento, y la nota de "Pendientes" sobre el reembolso de madera se marca resuelta. Actualizar `docs/Pendientes y próximos pasos.md` (punto 4) cuando esta pieza quede hecha, dejando la parte de refinerías reales como pendiente separado.

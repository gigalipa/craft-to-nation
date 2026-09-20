# Nivelación del Frente y Overlays de Previsualización — Diseño

## Contexto

`2026-09-20-puertas-a-nivel-de-suelo-design.md` deja la puerta a ras del
suelo natural delante de ella, pero solo **valida** el frente: las celdas
reservadas (`VoxelWorld.calcular_despeje()`) deben estar vacías, y el terreno
natural que las ocupa rechaza el emplazamiento. La carretera que se conecte a
la puerta necesita ese frente **plano y a nivel**, y el jugador no tiene forma
de ver de antemano qué espacio se reserva ni qué terreno se va a tocar.

Pedido del usuario, dos cambios para dar la función por completada:

1. La construcción implica **nivelar todas las celdas del frente** del
   edificio (donde están la o las puertas). Decisión confirmada: **toda la
   fachada** (no solo el ancho de la puerta): todas las columnas delante del
   lado del edificio que tiene puerta.
2. Pintar un **overlay de las celdas reservadas** delante de puertas y
   ventanas y un **overlay de la región que será nivelada**, para ver
   fácilmente dónde se puede colocar un edificio y qué terreno se afecta.

## Alcance

Dentro: fachada y su nivel, excavación/relleno de la fachada en la misma cola
de preparación, ajuste de `verificar_despejes`, validación de pendiente sobre
huella + fachada, overlays en la previsualización del blueprint, pruebas,
documentación.

Fuera: nivelar el frente de las ventanas (siguen reservando 1 celda libre, sin
nivelar), restaurar terreno al deconstruir (igual que hoy con excavación y
relleno), un tope global de profundidad de excavación, sugerir o ajustar
automáticamente la posición del edificio, inventario real (el resumen de
materiales sigue siendo solo visual), puestos periféricos.

## Diseño

### 1. Fachada y su nivel (`NiveladorTerreno.gd`, lógica pura)

- **Fachada:** para cada `puerta_inferior` y cada dirección externa `d` (vecino
  cardinal en XZ fuera de la huella, el mismo criterio que
  `calcular_despeje()` y `calcular_base_y()`), la fachada de `d` son las 2
  columnas `c+d` y `c+2d` delante de **todas** las columnas `c` de la huella
  cuyo vecino `c+d` cae fuera de la huella (todo el lado que mira hacia `d`;
  en una huella en L sigue el contorno real). Las columnas que ya son de la
  huella se omiten.
- **Nivel `G`:** el suelo natural delante de la puerta que ya calcula
  `calcular_base_y()` (`altura_en(frente)`). Toda la fachada de `d` se lleva a
  `G`: se **cava** todo bloque por encima de `G` y se **rellena** de tierra
  hasta `G` (la superficie caminable queda en `G`, a ras de la puerta).
- **`calcular_base_y()` devuelve además** `"fachada": Dictionary` (columna
  mundial `Vector2i` → `G`). Si dos puertas de la misma dirección piden `G`
  distintos, o una columna cae en dos fachadas con `G` distintos, el resultado
  es inválido con el motivo ya existente `"puertas"`.
- **Nivelación de la fachada:** nueva
  `calcular_nivelacion_fachada(fachada) -> {"excavacion": Array[Vector3i],
  "relleno": Dictionary}` (excavación ordenada de arriba hacia abajo como
  `calcular_excavacion()`; relleno `Vector2i` → cantidad).
- **Pendiente:** la validación con `LIMITE_PENDIENTE = 2` pasa a cubrir la
  **unión** de huella y fachada (`verificar_pendiente()` ya acepta cualquier
  conjunto de columnas), no solo la huella.

### 2. Despeje sobre terreno a nivelar (`VoxelWorld.gd`)

`verificar_despejes(celdas_mundo, terreno_a_nivelar := {})`: una celda de
despeje ocupada **deja de rechazar** si su columna está en `terreno_a_nivelar`
(la fachada, columna → `G`), la celda queda por encima de `G` y es **terreno
natural** (`es_terreno_natural(celda)`: no vacía y ni árbol, ni estructura, ni
`fantasma`, ni `agua`, ni parte de un edificio). Árboles, estructuras y otros
edificios siguen rechazando. Con el argumento omitido el comportamiento es el
actual (lo usa `Player._declarar_edificio()`). Una ventana de otro lado del
edificio, fuera de una fachada con puerta, conserva la regla de 1 celda libre.

### 3. Emplazamiento (`CamaraCenital.gd`, clic y previsualización)

- **Validaciones, en este orden y todas antes de mutar el mundo:** `base_y` y
  fachada (`_base_y_blueprint()`), pendiente sobre huella + fachada, huella
  libre (la huella como hoy; las columnas de la fachada con altura 2, la altura de la
  puerta), choque con puestos sobre la unión, despejes con `terreno_a_nivelar`.
- **Al confirmar:** follaje de la fachada se elimina y el agua de sus columnas
  se drena como en la huella; después las celdas de excavación y relleno de la
  fachada se suman a la **misma cola de preparación** (excavación primero,
  relleno después, ver el spec de puertas a nivel de suelo). El resumen de
  materiales las incluye. `metadata` guarda además `"fachada"`.

### 4. Overlays de previsualización (`NivelacionOverlay.gd`, nodo nuevo)

`Node3D` hijo de `CamaraCenital` (mismo patrón de cajas/planos `top_level`
que la huella del blueprint), con `mostrar(reservadas, region)` y `ocultar()`.
Solo visible en modo colocar-blueprint (`B`); se recalcula cuando cambia la
esquina o la rotación (mismo criterio de caché que el resumen de materiales),
**también cuando la colocación es inválida**, para ver qué la bloquea.

- **Celdas reservadas** (`calcular_despeje()` de puertas y ventanas, ya a
  `base_y`): una caja translúcida por celda 3D. Cian `Color(0.2, 0.9, 1.0,
  0.35)`; en rojo `Color(1.0, 0.2, 0.2, 0.5)` las **bloqueadas** (árbol,
  estructura u otro edificio; el terreno natural a nivelar no bloquea).
- **Región nivelada** (huella + fachada): un plano por columna a ras del
  terreno actual (`altura_en(x, z, true)` + el mismo offset de los planos de
  puesto), tintado por acción: naranja `Color(1.0, 0.5, 0.1, 0.35)` donde se
  cava, azul `Color(0.2, 0.5, 1.0, 0.35)` donde se rellena, verde tenue
  `Color(0.3, 1.0, 0.4, 0.25)` donde el terreno ya está a nivel.
- Los colores son constantes en `NivelacionOverlay.gd`.

## Pruebas

Automáticas, `NiveladorTerrenoTest.tscn` (generadores de altura falsos): fachada
de un lado; fachada en huella en L; `G` desde el suelo frontal; conflicto de
`G` entre dos puertas de la misma dirección; excavación y relleno de la
fachada; pendiente sobre la unión rechaza donde la huella sola pasaba.
`BlueprintValidatorTest.tscn` (`Test.tscn`): `verificar_despejes` acepta terreno
natural sobre `G` en una columna de la fachada y sigue rechazando árbol,
estructura y terreno fuera de la fachada; sin el argumento nuevo no cambia nada.

Manual (el dibujo y el flujo): emplazar en plano y en ladera; overlays cian,
rojo, naranja, azul y verde según lo esperado; al confirmar y surtir, la
fachada queda plana a ras de la puerta; rechazos con mensaje cuando hay un
árbol en el frente o las puertas piden niveles distintos.

Verificación: `Test.tscn`, `NiveladorTerrenoTest.tscn` y arranque de
`Main.tscn` sin errores nuevos.

## Documentación

GDD §5 ("Nivel de Puerta y Excavación"): la fachada del lado de la puerta
también se nivela. Doc técnico de PoC 6: la decisión funcional y los overlays.

## Riesgos conocidos

- Con toda la fachada, más emplazamientos se rechazan o piden mucha
  excavación; los overlays existen justamente para verlo antes de colocar.
- Sin tope global de profundidad: una fachada larga sobre una ladera cruzada
  puede pedir mucha excavación, igual que la huella hoy.
- Recalcular overlays y nivelación por movimiento del cursor cuesta lecturas de
  `altura_en()`; se mitiga con el caché por esquina.

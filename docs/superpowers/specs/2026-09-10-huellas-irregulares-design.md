# Huellas Irregulares — Diseño

## Contexto

Hoy el pipeline de edificios (declaración manual, blueprints, y las
funciones de validación de colocación que blueprints comparte con los
puestos periféricos) asume en varios puntos que la huella de un edificio es
un rectángulo sólido (`ancho × profundidad`), aunque `VoxelWorld.
detectar_estructura()` y la validación de perímetro (`BlueprintValidator.
validar_cerramiento()`) ya soportan formas irregulares (un edificio en L,
por ejemplo) para las paredes/puertas/ventanas. Los puntos que SÍ asumen
rectángulo son:

1. `BlueprintValidator._es_losa_completa()`/`_es_losa_parcial()`: exigen
   que TODA la caja delimitadora (`x_max × z_max`) tenga suelo/techo sólido
   en cada columna — para un edificio en L, las columnas del "hueco" de la L
   nunca tienen bloque (no son parte del edificio), así que la losa nunca
   se reconoce como completa y la construcción se rechaza con "falta un
   suelo/techo sólido", aunque esté perfectamente cerrada.
2. `NiveladorTerreno.verificar_pendiente()/altura_objetivo()/
   calcular_relleno()`, `VoxelWorld.verificar_huella_libre()`,
   `CamaraCenital._huella_choca_con_otro_puesto()`/
   `_huella_tiene_esquina_en_tierra()`: todas iteran sobre el rectángulo
   `ancho × alto` completo — al colocar una COPIA de un blueprint en L en
   otro sitio, exigen que el hueco de la L también esté libre/nivelado/en
   tierra firme, aunque ningún bloque real vaya a ocupar esa zona.

Este spec cierra ambos frentes: reconocer/declarar un edificio de huella
irregular (punto 1), y colocar copias de su blueprint en otro sitio
respetando su forma real, no su caja delimitadora (punto 2).

## Objetivo

- Un edificio de huella irregular (p. ej. en L) se puede **declarar**
  (`Player._declarar_edificio()`) sin que las reglas de suelo/techo lo
  rechacen por columnas que no le pertenecen.
- Una copia de su blueprint se puede **colocar** en otro sitio (tecla `B`)
  validando/aplicando únicamente sobre sus columnas reales: colisión con
  otro puesto/construcción, esquina en tierra firme, zona permitida,
  pendiente, relleno de nivelación y drenaje de agua — el hueco de la L
  nunca se exige libre, nivelado, drenado ni en la zona correcta.

## Fuera de alcance

- Los puestos periféricos (mina, caza/recolección) siguen siendo
  rectángulos fijos — no ganan huella irregular. Las funciones que
  comparten con blueprints se generalizan para aceptar cualquier forma,
  pero los puestos les siguen pasando un rectángulo (vía un helper nuevo).
- La validación de zona de influencia de los puestos (`Zonificacion.
  dentro_de_influencia(centro)`, solo la celda central) sigue siendo
  puntual — pendiente ya documentado aparte, sin relación con la forma de
  la huella.
- Rotación de blueprints irregulares (la rotación en general sigue sin
  implementarse, "sin rotar por ahora" ya decidido en el spec de
  blueprints).
- Huecos internos (patios interiores) — una huella irregular es cualquier
  forma ortogonal conexa, pero no se contempla un anillo con un agujero en
  medio (no surge de `detectar_estructura()` en la práctica: requeriría un
  edificio con un patio central sin techo ni piso en ningún nivel).
- Un edificio irregular ya terminado sigue registrando su HUELLA COMPLETA
  DELIMITADORA (no sus columnas reales) en `Recoleccion.puestos` (ver
  `Player._completar_construccion()` -> `Recoleccion.colocar_puesto(...,
  metadata["ancho"], metadata["profundidad"])`) — el hueco de una L ya
  construida queda "ocupado" para siempre a efectos de choque con un
  futuro puesto o blueprint, aunque ahí no haya nada real. Falla de forma
  conservadora (nunca permite un solape ilegal, solo es más estricto de lo
  necesario) — pendiente de una futura generalización de `Recoleccion.gd`
  para registrar columnas reales en vez de un rectángulo, fuera de las 4
  tareas de este plan.

## Diseño

### 1. `BlueprintValidator.gd`: huella real en vez de caja delimitadora

Se calcula una vez, en `estructura_a_blueprint()`, la **huella real**: la
unión de columnas `(x,z)` normalizadas que aparecen en CUALQUIER capa del
edificio (a partir de `celdas_relevantes`, antes de agruparlas por capa de
Y). Se representa como `Dictionary` de clave `"x,z"` (mismo formato que ya
usa `capa.get("x,z")`) para reutilizar `_parsear_celda()`.

`_es_losa_completa(capa: Dictionary, huella_real: Dictionary) -> bool`:
recorre `huella_real` en vez de `range(x_max+1) × range(z_max+1)`; para
cada columna de la huella real, exige que `capa` tenga un tipo estructural
ahí. Columnas fuera de la huella real ya no se consultan.

`_es_losa_parcial(capa: Dictionary, huella_real: Dictionary) -> bool`:
"columna interior" pasa de "no está en el anillo perimetral de la caja"
(`range(1, x_max) × range(1, z_max)`) a "sus 4 vecinos ortogonales
(`VECINOS_ORTOGONALES`) también pertenecen a la huella real" — mismo
criterio que ya usa `validar_cerramiento()` para decidir qué celda es
borde. Si ninguna columna de la huella real es interior (edificio
demasiado angosto en cualquier forma), se cae a exigir losa completa, igual
que antes.

`estructura_a_blueprint()` gana un campo nuevo en el dict devuelto:
`"huella_relativa": Array[Vector2i]` — las columnas de la huella real,
normalizadas al mismo origen que `celdas_3d`/`ancho`/`profundidad`, listas
para que el resto del pipeline las reutilice sin recalcularlas.

### 2. `NiveladorTerreno.gd`: columnas explícitas en vez de ancho×alto

`verificar_pendiente()`, `altura_objetivo()`, `calcular_relleno()` cambian
su firma de `(esquina: Vector2i, ancho: int, alto: int)` a `(esquina:
Vector2i, columnas: Array[Vector2i])` — `columnas` son offsets relativos a
`esquina`. Ya no tienen valores por defecto (`TAMANO_HUELLA`): todo llamador
pasa explícitamente su lista de columnas — el modo de nivelación manual
standalone que usaba el valor por defecto ya no existe (reemplazado por
blueprints, ver spec de blueprints).

`verificar_pendiente()` deja de comparar contra CUALQUIER vecino
ortogonal dentro del rectángulo: compara solo entre dos columnas que
AMBAS estén en `columnas` (mismo patrón que `validar_cerramiento()`) — así
un desnivel fuera de la huella real (el hueco de una L) nunca invalida la
colocación. `altura_objetivo()`/`calcular_relleno()` simplemente iteran
`columnas` en vez del rectángulo.

### 3. `VoxelWorld.verificar_huella_libre()`: mismo cambio

Firma pasa de `(esquina, ancho, alto, altura)` a `(esquina, columnas,
altura)`. Cuerpo sin cambios salvo la fuente de las columnas a iterar.

### 4. `CamaraCenital.gd`: columnas en vez de ancho×alto, y helper de rectángulo

- `_huella_choca_con_otro_puesto(esquina, columnas)`: itera `columnas` en
  vez del rectángulo.
- `_huella_tiene_esquina_en_tierra()` se renombra a
  `_huella_tiene_columna_en_tierra(esquina, columnas) -> bool`: en vez de
  revisar solo las 4 esquinas del rectángulo, revisa TODAS las columnas de
  `columnas` y basta con que una esté en tierra firme — generalización
  natural (para una forma irregular, las "esquinas" de la caja delimitadora
  pueden no ser parte real del edificio). Para un rectángulo (puestos), esto
  es un superconjunto estrictamente más permisivo que el chequeo anterior
  (antes 4 celdas, ahora todas) — nunca rechaza un caso que antes aceptaba.
- Nuevo helper `_columnas_rectangulo(ancho: int, alto: int) -> Array[Vector2i]`
  (offsets `Vector2i(dx, dz)` para `dx in range(ancho), dz in range(alto)`)
  — lo usan los puestos (`_actualizar_previsualizacion_puesto()`,
  `_procesar_clic_puesto()`) para seguir pasando su rectángulo fijo a las
  funciones ya generalizadas, sin duplicar la lógica de generación.
- Los sitios de blueprint (`_actualizar_previsualizacion_blueprint()`,
  `_procesar_clic_blueprint()`) usan `_blueprint_activo["huella_relativa"]`
  directamente en vez de un rectángulo.
- **Zona del blueprint**: `Zonificacion.consultar_zona(centro) ==
  zona_permitida` (una sola celda) pasa a exigir que TODAS las columnas de
  `huella_relativa` (proyectadas a mundo: `esquina + rel`) tengan
  `consultar_zona(...) == zona_permitida`. Esto es un cierre deliberado del
  pendiente ya documentado "la validación de zona sigue siendo puntual" —
  pero SOLO para blueprints; la zona de influencia de los puestos
  (`dentro_de_influencia`, chequeo distinto) no se toca.
- **Drenaje de agua y relleno de nivelación** en `_procesar_clic_blueprint()`:
  los bucles `for dx in range(ancho): for dz in range(alto)` pasan a iterar
  `huella_relativa` — el hueco de una L nunca se drena ni se nivela.

### Resumen de firmas que cambian

| Función | Antes | Después |
|---|---|---|
| `NiveladorTerreno.verificar_pendiente` | `(esquina, ancho=T, alto=T)` | `(esquina, columnas)` |
| `NiveladorTerreno.altura_objetivo` | `(esquina, ancho=T, alto=T)` | `(esquina, columnas)` |
| `NiveladorTerreno.calcular_relleno` | `(esquina, ancho=T, alto=T)` | `(esquina, columnas)` |
| `VoxelWorld.verificar_huella_libre` | `(esquina, ancho, alto, altura=1)` | `(esquina, columnas, altura=1)` |
| `CamaraCenital._huella_choca_con_otro_puesto` | `(esquina, ancho, alto)` | `(esquina, columnas)` |
| `CamaraCenital._huella_tiene_esquina_en_tierra` | `(esquina, ancho, alto)` | renombrada `_huella_tiene_columna_en_tierra(esquina, columnas)` |

`columnas: Array[Vector2i]` es siempre offsets relativos a `esquina`
(o a `(esquina.x, esquina.y)` según el sistema de coordenadas ya en uso en
cada función).

## Pruebas

**`BlueprintValidatorTest.gd`**: nuevo caso (TEST 21) con una estructura en
L real (celdas físicas de `detectar_estructura()`, no un blueprint hecho a
mano) — confirma que `estructura_a_blueprint()` + `validar_blueprint()`
aceptan la L (losas completas/parciales correctas pese a la forma), y que
`huella_relativa` contiene exactamente las columnas reales de la L (ni más
ni menos que la caja delimitadora).

**`NiveladorTerrenoTest.gd`**: se reescriben los tests existentes que
pasaban `ancho, alto` para pasar en su lugar una lista de columnas
(rectángulo generado inline en el propio test, sin depender de un helper
compartido con `CamaraCenital.gd`). Nuevo caso: una lista de columnas en
forma de L con un "acantilado" (desnivel mayor a `LIMITE_PENDIENTE`) SOLO
en la columna del hueco (fuera de la lista) — `verificar_pendiente()` debe
seguir devolviendo `true`, porque esa columna nunca se compara. Otro caso:
`calcular_relleno()`/`altura_objetivo()` sobre esa misma L solo consideran
las columnas listadas.

**`VoxelWorld` (vía `BlueprintValidatorTest.gd`, mismo patrón que TEST
16/19/20)**: actualizar las llamadas existentes a `verificar_huella_libre()`
para pasar una lista de columnas en vez de `ancho, alto` — mismos casos que
hoy, sin necesidad de un caso nuevo (la generalización es transparente para
un rectángulo).

## Verificación de integración

Manual en el editor (sin test automatizado para `CamaraCenital.gd`/
`Player.gd`):

1. Declarar un edificio en L (bloque por bloque) — debe aceptarse.
2. Activar el modo de colocación de blueprint (`B`) sobre ese blueprint en
   L — la previsualización 3D debe mostrar exactamente la forma en L (ya
   lo hace, sin cambios en esta parte), y debe poder confirmarse sobre un
   sitio donde el hueco de la L caería sobre agua/un árbol/fuera de la
   zona — la colocación debe aceptarse porque esa columna no es parte real
   del edificio.
3. Confirmar que los puestos (mina, caza/recolección) siguen
   comportándose exactamente igual que antes (rectángulos fijos, mismas
   validaciones).

# Huellas Irregulares Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Un edificio de huella irregular (p. ej. en L) se puede declarar sin que las reglas de suelo/techo lo rechacen por columnas que no le pertenecen, y una copia de su blueprint se puede colocar en otro sitio validando/aplicando únicamente sobre sus columnas reales (colisión, esquina en tierra, zona, pendiente, relleno, drenaje).

**Architecture:** Varias funciones que hoy asumen un rectángulo (`ancho × alto`) cambian a recibir una lista explícita de columnas (`Array[Vector2i]`, offsets relativos a una esquina). Un rectángulo pasa a ser solo el caso particular de generar esa lista con un helper; una huella irregular pasa su propia lista, calculada una vez en `BlueprintValidator.estructura_a_blueprint()` y guardada como `blueprint["huella_relativa"]`.

**Tech Stack:** Godot 4.7 GDScript.

**Spec:** `docs/superpowers/specs/2026-09-10-huellas-irregulares-design.md`

## Global Constraints

- `columnas: Array[Vector2i]` es siempre offsets relativos a una "esquina" — nunca coordenadas absolutas.
- Los puestos periféricos (mina, caza/recolección) NO ganan huella irregular — siguen siendo rectángulos fijos, generados con el nuevo helper `_columnas_rectangulo()`.
- La validación de zona de influencia de los puestos (`Zonificacion.dentro_de_influencia`) NO se toca — sigue siendo puntual (solo la celda central), es un pendiente aparte.
- Ningún valor por defecto de `ancho`/`alto` sobrevive en `NiveladorTerreno` — todo llamador pasa `columnas` explícitas.
- Verificación: ejecutar `godot/scenes/Test.tscn`, `godot/scenes/NiveladorTerrenoTest.tscn` (todas las aserciones deben pasar) y `godot/scenes/Main.tscn` (sin errores nuevos más allá de las 2 advertencias conocidas de colisión de nombre de clase).

---

### Task 1: `BlueprintValidator.gd` — huella real en vez de caja delimitadora

**Files:**
- Modify: `godot/scripts/BlueprintValidator.gd`
- Modify: `godot/scripts/BlueprintValidatorTest.gd`

**Interfaces:**
- Produces: `estructura_a_blueprint()` gana el campo `"huella_relativa": Array[Vector2i]` en el dict devuelto. Consumido por Task 4 (`CamaraCenital.gd`, vía `_blueprint_activo["huella_relativa"]`).

- [ ] **Step 1: Reemplazar `_es_losa_completa()` por la versión basada en huella real**

En `godot/scripts/BlueprintValidator.gd`, localiza:

```gdscript
## Una capa de Y es una "losa completa" (suelo base o techo exterior) si
## TODAS las celdas de su huella x/z (según el rango global del edificio)
## están presentes y son de un tipo ESTRUCTURAL (pared/puerta/ventana/piso).
## Se exige solo para la losa más baja (cimiento) y la más alta (techo
## exterior) del edificio completo — nunca deben tener huecos.
static func _es_losa_completa(capa: Dictionary, x_max: int, z_max: int) -> bool:
	for lx in range(x_max + 1):
		for lz in range(z_max + 1):
			var tipo = capa.get("%d,%d" % [lx, lz])
			if tipo == null or not TIPOS_ESTRUCTURALES.has(tipo):
				return false
	return true
```

Reemplaza por:

```gdscript
## Una capa de Y es una "losa completa" (suelo base o techo exterior) si
## TODAS las columnas de la huella real (ver estructura_a_blueprint(), NO
## la caja delimitadora completa — un edificio en L no llena su caja) están
## presentes y son de un tipo ESTRUCTURAL (pared/puerta/ventana/piso). Se
## exige solo para la losa más baja (cimiento) y la más alta (techo
## exterior) del edificio completo — nunca deben tener huecos.
static func _es_losa_completa(capa: Dictionary, huella_real: Dictionary) -> bool:
	for clave in huella_real:
		var tipo = capa.get(clave)
		if tipo == null or not TIPOS_ESTRUCTURALES.has(tipo):
			return false
	return true
```

- [ ] **Step 2: Reemplazar `_es_losa_parcial()` por la versión basada en huella real**

Localiza:

```gdscript
## Una capa de Y es una "losa parcial" (borde entre dos historias, puede
## tener un hueco de escalera) si más de la mitad de sus celdas INTERIORES
## (excluyendo el anillo de paredes perimetrales, que está presente tanto en
## una losa como en una capa de pared normal) son de tipo estructural. Una
## capa de pared normal tiene el interior mayormente vacío (aire transitable,
## a lo sumo con mobiliario disperso: cama, baúl, que NO cuentan como
## estructurales), mientras que una losa de piso con hueco de escalera solo
## tiene un hueco pequeño en, por lo demás, una superficie sólida.
## Caso límite: si el edificio no tiene ninguna celda interior (huella
## demasiado angosta), no hay forma de distinguir por interior — se cae a
## exigir la losa completa.
static func _es_losa_parcial(capa: Dictionary, x_max: int, z_max: int) -> bool:
	if x_max < 2 or z_max < 2:
		return _es_losa_completa(capa, x_max, z_max)
	var total_interior := 0
	var total_estructural := 0
	for lx in range(1, x_max):
		for lz in range(1, z_max):
			total_interior += 1
			var tipo = capa.get("%d,%d" % [lx, lz])
			if tipo != null and TIPOS_ESTRUCTURALES.has(tipo):
				total_estructural += 1
	return float(total_estructural) / float(total_interior) > 0.5
```

Reemplaza por (agrega también el helper `_es_columna_interior` justo antes):

```gdscript
## Una columna de la huella real es "interior" si sus 4 vecinos ortogonales
## (VECINOS_ORTOGONALES) también pertenecen a la huella real — mismo
## criterio que ya usa validar_cerramiento() para decidir qué celda es
## borde. Generaliza "no está en el anillo perimetral de la caja
## delimitadora" (válido solo para un rectángulo) a cualquier forma.
static func _es_columna_interior(pos: Vector2i, huella_real: Dictionary) -> bool:
	for delta in VECINOS_ORTOGONALES:
		var vecino: Vector2i = pos + delta
		if not huella_real.has("%d,%d" % [vecino.x, vecino.y]):
			return false
	return true


## Una capa de Y es una "losa parcial" (borde entre dos historias, puede
## tener un hueco de escalera) si más de la mitad de sus columnas
## INTERIORES de la huella real (ver _es_columna_interior(), generaliza
## "excluyendo el anillo perimetral de la caja delimitadora" a cualquier
## forma) son de tipo estructural. Una capa de pared normal tiene el
## interior mayormente vacío (aire transitable, a lo sumo con mobiliario
## disperso: cama, baúl, que NO cuentan como estructurales), mientras que
## una losa de piso con hueco de escalera solo tiene un hueco pequeño en,
## por lo demás, una superficie sólida.
## Caso límite: si la huella real no tiene ninguna columna interior (huella
## demasiado angosta, en cualquier forma), no hay forma de distinguir por
## interior — se cae a exigir la losa completa.
static func _es_losa_parcial(capa: Dictionary, huella_real: Dictionary) -> bool:
	var interiores: Array = []
	for clave in huella_real:
		if _es_columna_interior(_parsear_celda(clave), huella_real):
			interiores.append(clave)
	if interiores.is_empty():
		return _es_losa_completa(capa, huella_real)
	var total_estructural := 0
	for clave in interiores:
		var tipo = capa.get(clave)
		if tipo != null and TIPOS_ESTRUCTURALES.has(tipo):
			total_estructural += 1
	return float(total_estructural) / float(interiores.size()) > 0.5
```

- [ ] **Step 3: Calcular `huella_real` en `estructura_a_blueprint()` y actualizar sus 3 llamadas**

Localiza (el bucle que construye `celdas_por_capa`):

```gdscript
	var celdas_por_capa: Dictionary = {}  # int (capa de Y) -> Dictionary ("x,z" -> tipo)
	for pos in celdas_relevantes.keys():
		var capa: int = pos.y - y_min
		var clave := "%d,%d" % [pos.x - x_min, pos.z - z_min]
		var tipo: String = celdas_relevantes[pos]
		if tipo == "puerta_inferior":
			tipo = "puerta"
		if not celdas_por_capa.has(capa):
			celdas_por_capa[capa] = {}
		celdas_por_capa[capa][clave] = tipo
```

Reemplaza por (agrega `huella_real`, poblada en la misma pasada):

```gdscript
	var celdas_por_capa: Dictionary = {}  # int (capa de Y) -> Dictionary ("x,z" -> tipo)
	var huella_real: Dictionary = {}  # "x,z" -> true, unión de columnas del edificio en cualquier capa
	for pos in celdas_relevantes.keys():
		var capa: int = pos.y - y_min
		var clave := "%d,%d" % [pos.x - x_min, pos.z - z_min]
		var tipo: String = celdas_relevantes[pos]
		if tipo == "puerta_inferior":
			tipo = "puerta"
		if not celdas_por_capa.has(capa):
			celdas_por_capa[capa] = {}
		celdas_por_capa[capa][clave] = tipo
		huella_real[clave] = true
```

Localiza (el bucle que clasifica cada capa como losa):

```gdscript
	var indices_capa: Array = celdas_por_capa.keys()
	indices_capa.sort()
	var es_losa: Dictionary = {}  # int -> bool ("losa parcial": límite entre historias)
	for capa in indices_capa:
		es_losa[capa] = _es_losa_parcial(celdas_por_capa[capa], x_max, z_max)
```

Reemplaza la última línea por:

```gdscript
		es_losa[capa] = _es_losa_parcial(celdas_por_capa[capa], huella_real)
```

Localiza (dentro del bucle de bandas):

```gdscript
		var suelo_ok: bool = hay_losa_bajo and (
			not es_piso_mas_bajo or _es_losa_completa(celdas_por_capa[capa_bajo_banda], x_max, z_max)
		)
		var techo_ok: bool = hay_losa_sobre and (
			not es_piso_mas_alto or _es_losa_completa(celdas_por_capa[capa_sobre_banda], x_max, z_max)
		)
```

Reemplaza por:

```gdscript
		var suelo_ok: bool = hay_losa_bajo and (
			not es_piso_mas_bajo or _es_losa_completa(celdas_por_capa[capa_bajo_banda], huella_real)
		)
		var techo_ok: bool = hay_losa_sobre and (
			not es_piso_mas_alto or _es_losa_completa(celdas_por_capa[capa_sobre_banda], huella_real)
		)
```

- [ ] **Step 4: Agregar `huella_relativa` al dict devuelto**

Localiza:

```gdscript
	return {
		"nombre": "Estructura_Detectada",
		"tipo": "residencial",
		"zona_permitida": "residencial_investigacion",
		"pisos": pisos,
		"celdas_3d": celdas_3d,
		"ancho": x_max + 1,       # x_max ya es (máximo - x_min), ver arriba
		"profundidad": z_max + 1,
	}
```

Reemplaza por:

```gdscript
	var huella_relativa: Array[Vector2i] = []
	for clave in huella_real:
		huella_relativa.append(_parsear_celda(clave))

	return {
		"nombre": "Estructura_Detectada",
		"tipo": "residencial",
		"zona_permitida": "residencial_investigacion",
		"pisos": pisos,
		"celdas_3d": celdas_3d,
		"ancho": x_max + 1,       # x_max ya es (máximo - x_min), ver arriba
		"profundidad": z_max + 1,
		"huella_relativa": huella_relativa,
	}
```

- [ ] **Step 5: Actualizar el comentario de cabecera y agregar TEST 21 en `BlueprintValidatorTest.gd`**

Localiza (cerca de la línea 30-33):

```gdscript
## que registrar_edificio() vuelve inmunes al minado las celdas, tanto en
## fantasmas como en bloques reales (20, ver VoxelWorld.registrar_edificio()/
## minar_bloque()).
## Correr esta escena (Test.tscn) con F6 en el editor de Godot y revisar el
## panel "Output": debe imprimir los 20 tests y no debe lanzar ningún error
## de assert().
```

Reemplaza por:

```gdscript
## que registrar_edificio() vuelve inmunes al minado las celdas, tanto en
## fantasmas como en bloques reales (20, ver VoxelWorld.registrar_edificio()/
## minar_bloque()), y que estructura_a_blueprint() reconoce una huella
## irregular (un edificio en L) sin exigir que su caja delimitadora
## completa tenga suelo/techo, y calcula "huella_relativa" con solo las
## columnas reales (21, ver BlueprintValidator._es_losa_completa()/
## _es_losa_parcial()).
## Correr esta escena (Test.tscn) con F6 en el editor de Godot y revisar el
## panel "Output": debe imprimir los 21 tests y no debe lanzar ningún error
## de assert().
```

Localiza la línea final del archivo (justo antes del `print("\n=== Las 20 pruebas...")`, que es la última prueba: TEST 20, "registrar_edificio() vuelve inmune al minado"). Inserta el siguiente bloque INMEDIATAMENTE DESPUÉS de la última línea de TEST 20 (el `print("OK: minar_bloque() ignora...")`) y ANTES del `print("\n=== Las 20 pruebas de BlueprintValidator pasaron correctamente ===")` final:

```gdscript
	print("\n=== TEST 21: estructura_a_blueprint() reconoce una huella en L ===")
	# Construye "celdas" (Vector3i -> tipo físico) a mano, sin pasar por
	# VoxelWorld: un edificio en L (cuadrado de 5x5 menos un cuadrado de 2x2
	# en una esquina, 21 columnas reales en vez de las 25 de la caja
	# delimitadora). Antes del fix, _es_losa_completa()/_es_losa_parcial()
	# exigían las 25 columnas completas y esta construcción se rechazaba con
	# "falta un suelo/techo sólido" pese a estar perfectamente cerrada.
	var interiores_l: Array[Vector2i] = [
		Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
		Vector2i(1, 2), Vector2i(2, 2), Vector2i(1, 3),
	]
	var notch_l: Array[Vector2i] = [Vector2i(3, 3), Vector2i(3, 4), Vector2i(4, 3), Vector2i(4, 4)]

	var celdas_l: Dictionary = {}
	for x in range(5):
		for z in range(5):
			if notch_l.has(Vector2i(x, z)):
				continue
			celdas_l[Vector3i(x, 0, z)] = "pared"  # suelo
			celdas_l[Vector3i(x, 4, z)] = "pared"  # techo
	for y in range(1, 4):
		for x in range(5):
			for z in range(5):
				var col := Vector2i(x, z)
				if notch_l.has(col) or interiores_l.has(col):
					continue
				if x == 1 and z == 0:
					continue  # puerta principal, se coloca aparte
				if x == 0 and z == 2 and y == 2:
					continue  # ventana, se coloca aparte
				celdas_l[Vector3i(x, y, z)] = "pared"
	celdas_l[Vector3i(1, 1, 0)] = "puerta_inferior"
	celdas_l[Vector3i(1, 2, 0)] = "puerta_superior"
	celdas_l[Vector3i(1, 3, 0)] = "pared"  # pared sobre la puerta
	celdas_l[Vector3i(0, 2, 2)] = "ventana"
	celdas_l[Vector3i(1, 1, 1)] = "cama_cabecera"
	celdas_l[Vector3i(2, 1, 1)] = "cama_pies"
	celdas_l[Vector3i(2, 1, 2)] = "baul"

	var blueprint_l := BlueprintValidator.estructura_a_blueprint(celdas_l)
	print("Columnas de la huella real: ", blueprint_l["huella_relativa"].size(), " (esperadas: 21, no 25 = 5x5 completo)")
	assert(blueprint_l["huella_relativa"].size() == 21)
	assert(blueprint_l["ancho"] == 5)
	assert(blueprint_l["profundidad"] == 5)
	for celda_notch in notch_l:
		assert(not blueprint_l["huella_relativa"].has(celda_notch), "El hueco de la L no debe aparecer en huella_relativa")

	var resultado_l: Dictionary = BlueprintValidator.validar_blueprint(blueprint_l)
	print("Válido: ", resultado_l["valido"], " | Errores: ", resultado_l["errores"])
	assert(resultado_l["valido"])
	assert(resultado_l["errores"].is_empty())
	print("OK: estructura_a_blueprint() reconoce la huella en L y validar_blueprint() la acepta.")
```

Actualiza el `print` final del archivo de `"=== Las 20 pruebas..."` a `"=== Las 21 pruebas de BlueprintValidator pasaron correctamente ==="`.

- [ ] **Step 6: Ejecutar `Test.tscn` y verificar las 21 pruebas**

Ejecuta `godot/scenes/Test.tscn` (headless o en el editor) y confirma la salida `"=== Las 21 pruebas de BlueprintValidator pasaron correctamente ==="` sin ningún `assert` fallido, y sin errores nuevos más allá de la advertencia conocida de colisión de nombre de clase `BlueprintValidator`. Si TEST 21 falla por una regla de validación inesperada (perímetro/esquina/losa), usa el mensaje de error impreso (`resultado_l["errores"]`) para ajustar qué celdas de `celdas_l` necesitan ser "pared" en vez de estar vacías, o viceversa — la geometría de la L está descrita en el comentario del test (5x5 menos esquina 3x3-4x4, columnas interiores listadas explícitamente).

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/BlueprintValidator.gd godot/scripts/BlueprintValidatorTest.gd
git commit -m "feat: reconocer huellas irregulares en estructura_a_blueprint()"
```

---

### Task 2: `NiveladorTerreno.gd` — columnas explícitas en vez de ancho×alto

**Files:**
- Modify: `godot/scripts/NiveladorTerreno.gd`
- Modify: `godot/scripts/NiveladorTerrenoTest.gd`

**Interfaces:**
- Consumes: nada de Task 1.
- Produces: `verificar_pendiente(esquina, columnas)`, `altura_objetivo(esquina, columnas)`, `calcular_relleno(esquina, columnas)` — firma nueva, consumida por Task 4 (`CamaraCenital.gd`).

Este task es independiente de la Task 1 (puede ejecutarse en cualquier orden respecto a ella; el plan las numera así por claridad, no por dependencia).

- [ ] **Step 1: Reescribir `NiveladorTerreno.gd` completo**

Reemplaza TODO el contenido de `godot/scripts/NiveladorTerreno.gd` por:

```gdscript
extends RefCounted

## Lógica pura de nivelación de terreno (ver GDD Sección 5, "Nivelación de
## Terreno en Emplazamientos con Relieve") — sin nodos de escena, mismo
## patrón que Zonificacion.gd/Ciudad.gd. Calcula si una huella (cualquier
## conjunto de columnas, no necesariamente un rectángulo — ver
## docs/superpowers/specs/2026-09-10-huellas-irregulares-design.md) respeta
## el límite de pendiente, y cuántos bloques de "tierra" hacen falta para
## nivelarla a su punto más alto.
##
## No depende de una clase concreta: solo llama a .altura_en(x, z) por duck
## typing sobre lo que se le pase en _init(). En el juego real se le pasa
## VoxelWorld (VoxelWorld.altura_en(), que refleja el relieve REAL —
## minado/construcción/nivelaciones ya hechas), no GeneradorMundo
## directamente (su altura_en() es el ruido original, nunca se actualiza).
## Las pruebas (NiveladorTerrenoTest.gd) le pasan generadores falsos con
## pendientes exactas y controladas, ya que GeneradorMundo real usa ruido.

const LIMITE_PENDIENTE := 2

## Sin tipo estático: puede ser un RefCounted (GeneradorMundo, los
## generadores falsos de las pruebas) o un Node (VoxelWorld real, que
## extiende GridMap) — lo único que importa es que tenga altura_en(x, z).
var _generador: Object


func _init(fuente_de_altura: Object) -> void:
	_generador = fuente_de_altura


## Revisa cada par de columnas horizontal/verticalmente adyacentes DENTRO de
## "columnas" (offsets Vector2i relativos a "esquina") — rechaza si algún
## desnivel entre dos columnas AMBAS presentes en la lista supera
## LIMITE_PENDIENTE. Una columna vecina que no esté en "columnas" (el hueco
## de una huella irregular, p. ej. un edificio en L) nunca se compara —
## mismo criterio que ya usa BlueprintValidator.validar_cerramiento() para
## decidir qué vecino cuenta. Un rectángulo es solo el caso particular de
## pasar todas las columnas de range(ancho) x range(alto) (ver
## CamaraCenital._columnas_rectangulo()).
func verificar_pendiente(esquina: Vector2i, columnas: Array[Vector2i]) -> bool:
	var presentes: Dictionary = {}
	for rel in columnas:
		presentes[rel] = true
	for rel in columnas:
		var x: int = esquina.x + rel.x
		var z: int = esquina.y + rel.y
		var altura: int = _generador.altura_en(x, z)
		if presentes.has(rel + Vector2i(1, 0)):
			if abs(altura - _generador.altura_en(x + 1, z)) > LIMITE_PENDIENTE:
				return false
		if presentes.has(rel + Vector2i(0, 1)):
			if abs(altura - _generador.altura_en(x, z + 1)) > LIMITE_PENDIENTE:
				return false
	return true


## Altura máxima entre las columnas de "columnas" — a esta altura se nivela
## todo. Público porque también lo usa CamaraCenital.gd para posicionar el
## recuadro fantasma de previsualización.
func altura_objetivo(esquina: Vector2i, columnas: Array[Vector2i]) -> int:
	var maximo: int = _generador.altura_en(esquina.x, esquina.y)
	for rel in columnas:
		maximo = max(maximo, _generador.altura_en(esquina.x + rel.x, esquina.y + rel.y))
	return maximo


## Cuántos bloques de "tierra" hacen falta en cada columna de "columnas"
## para llegar a la altura máxima de esa huella. Solo incluye columnas que
## realmente necesitan relleno (columnas ya a la altura máxima no aparecen).
func calcular_relleno(esquina: Vector2i, columnas: Array[Vector2i]) -> Dictionary:
	var objetivo: int = altura_objetivo(esquina, columnas)
	var relleno: Dictionary = {}  # Vector2i -> int
	for rel in columnas:
		var x: int = esquina.x + rel.x
		var z: int = esquina.y + rel.y
		var faltante: int = objetivo - _generador.altura_en(x, z)
		if faltante > 0:
			relleno[Vector2i(x, z)] = faltante
	return relleno
```

- [ ] **Step 2: Reescribir `NiveladorTerrenoTest.gd` completo**

Reemplaza TODO el contenido de `godot/scripts/NiveladorTerrenoTest.gd` por:

```gdscript
extends Node

## Pruebas aisladas de NiveladorTerreno.gd (mismo patrón que
## ZonificacionTest.gd). Corre esta escena (NiveladorTerrenoTest.tscn) con
## F6 y revisa el panel "Output": debe imprimir las 7 pruebas y no debe
## lanzar ningún error de assert(). Usa un generador de alturas falso y
## determinista (no GeneradorMundo real, que usa ruido) para poder construir
## pendientes exactas y verificar el cálculo de relleno con precisión.
##
## verificar_pendiente()/altura_objetivo()/calcular_relleno() reciben
## "columnas": Array[Vector2i] de offsets relativos a "esquina" (ver
## docs/superpowers/specs/2026-09-10-huellas-irregulares-design.md) — un
## rectángulo es solo un caso particular (todas las columnas de
## range(ancho) x range(alto)), generado aquí mismo con _rectangulo() sin
## depender de ningún helper compartido con CamaraCenital.gd.

const NiveladorTerreno = preload("res://scripts/NiveladorTerreno.gd")


## Generador falso: la altura crece 1 celda por cada paso en Z (pendiente de
## 1, dentro del límite de 2) y es constante en X.
class GeneradorRampaSuave:
	func altura_en(_x: int, z: int) -> int:
		return z


## Generador falso: la altura crece 3 celdas por cada paso en Z (pendiente
## de 3, fuera del límite de 2).
class GeneradorRampaPronunciada:
	func altura_en(_x: int, z: int) -> int:
		return z * 3


## Generador falso: altura constante (terreno plano, sin pendiente).
class GeneradorPlano:
	func altura_en(_x: int, _z: int) -> int:
		return 5


## Generador falso: altura constante (3) salvo en (2, 2), un "acantilado"
## (altura 100) — usado para probar que una columna FUERA de la lista de
## columnas de la huella nunca se compara, sin importar cuán extremo sea su
## desnivel real (ver TEST 6/7).
class GeneradorConAcantilado:
	func altura_en(x: int, z: int) -> int:
		if x == 2 and z == 2:
			return 100
		return 3


func _rectangulo(ancho: int, alto: int) -> Array[Vector2i]:
	var columnas: Array[Vector2i] = []
	for x in range(ancho):
		for z in range(alto):
			columnas.append(Vector2i(x, z))
	return columnas


func _ready() -> void:
	ejecutar_pruebas()


func ejecutar_pruebas() -> void:
	print("=== TEST 1: Pendiente suave (1 por celda) se acepta ===")
	var nivelador_suave: RefCounted = NiveladorTerreno.new(GeneradorRampaSuave.new())
	assert(nivelador_suave.verificar_pendiente(Vector2i(0, 0), _rectangulo(5, 5)))

	print("\n=== TEST 2: Pendiente pronunciada (3 por celda) se rechaza ===")
	var nivelador_pronunciado: RefCounted = NiveladorTerreno.new(GeneradorRampaPronunciada.new())
	assert(not nivelador_pronunciado.verificar_pendiente(Vector2i(0, 0), _rectangulo(5, 5)))

	print("\n=== TEST 3: Terreno plano no necesita relleno ===")
	var nivelador_plano: RefCounted = NiveladorTerreno.new(GeneradorPlano.new())
	assert(nivelador_plano.verificar_pendiente(Vector2i(0, 0), _rectangulo(5, 5)))
	var relleno_plano: Dictionary = nivelador_plano.calcular_relleno(Vector2i(0, 0), _rectangulo(5, 5))
	print("Relleno en terreno plano: ", relleno_plano.size(), " celdas (esperadas: 0)")
	assert(relleno_plano.is_empty())

	print("\n=== TEST 4: Relleno correcto sobre una rampa suave (huella 5x5) ===")
	# Huella de (0,0) a (4,4): altura_en(x,z) = z, así que la fila z=4 es la
	# más alta (altura 4) y las demás necesitan relleno hasta llegar a 4:
	# z=0 -> 4 de relleno (x5 celdas), z=1 -> 3, z=2 -> 2, z=3 -> 1, z=4 -> 0.
	# Total: (4+3+2+1+0) * 5 = 50.
	var relleno_rampa: Dictionary = nivelador_suave.calcular_relleno(Vector2i(0, 0), _rectangulo(5, 5))
	var total_relleno := 0
	for cantidad in relleno_rampa.values():
		total_relleno += cantidad
	print("Total de bloques de relleno: ", total_relleno, " (esperados: 50)")
	assert(total_relleno == 50)
	assert(relleno_rampa[Vector2i(0, 0)] == 4)
	assert(not relleno_rampa.has(Vector2i(0, 4)))  # ya está a la altura máxima

	print("\n=== TEST 5: verificar_pendiente() con columnas no cuadradas (huella 4x3) ===")
	# Rampa suave: altura_en(x,z) = z. Huella ancho=4, alto=3 desde (0,0): z
	# va de 0 a 2 (pendiente de 1 por celda, dentro del límite de 2) -> válida.
	assert(nivelador_suave.verificar_pendiente(Vector2i(0, 0), _rectangulo(4, 3)))
	# Rampa pronunciada (altura_en = z*3): cualquier huella con alto>=2 sigue
	# rechazándose.
	assert(not nivelador_pronunciado.verificar_pendiente(Vector2i(0, 0), _rectangulo(4, 3)))

	print("\n=== TEST 6: verificar_pendiente() con huella irregular ignora columnas fuera de la lista ===")
	# Huella en L (cuadrado 3x3 menos la esquina (2,2)): 8 columnas en vez de
	# las 9 del rectángulo completo. El generador pone un "acantilado"
	# (altura 100 vs. 3 en el resto) exactamente en (2,2), la columna
	# EXCLUIDA — verificar_pendiente() nunca la compara, así que la huella en
	# L sigue siendo válida pese al desnivel extremo que tendría si se
	# incluyera esa columna.
	var nivelador_acantilado: RefCounted = NiveladorTerreno.new(GeneradorConAcantilado.new())
	var columnas_l: Array[Vector2i] = _rectangulo(3, 3)
	columnas_l.erase(Vector2i(2, 2))
	assert(columnas_l.size() == 8)
	assert(nivelador_acantilado.verificar_pendiente(Vector2i(0, 0), columnas_l))
	# Control: el mismo generador, mismo origen, pero con el rectángulo
	# COMPLETO (incluyendo (2,2)) sí debe rechazarse — confirma que la
	# exclusión de (2,2) es la que hace la diferencia, no un fallo silencioso
	# del generador o de la huella.
	assert(not nivelador_acantilado.verificar_pendiente(Vector2i(0, 0), _rectangulo(3, 3)))

	print("\n=== TEST 7: altura_objetivo()/calcular_relleno() con huella irregular ignoran el acantilado ===")
	assert(nivelador_acantilado.altura_objetivo(Vector2i(0, 0), columnas_l) == 3)
	var relleno_l: Dictionary = nivelador_acantilado.calcular_relleno(Vector2i(0, 0), columnas_l)
	print("Relleno de la huella en L (acantilado excluido): ", relleno_l.size(), " celdas (esperadas: 0)")
	assert(relleno_l.is_empty())

	print("\n=== Las 7 pruebas de NiveladorTerreno pasaron correctamente ===")
```

- [ ] **Step 3: Ejecutar `NiveladorTerrenoTest.tscn` y verificar las 7 pruebas**

Ejecuta `godot/scenes/NiveladorTerrenoTest.tscn` (headless o en el editor) y confirma la salida `"=== Las 7 pruebas de NiveladorTerreno pasaron correctamente ==="` sin ningún `assert` fallido y sin errores/advertencias nuevos.

- [ ] **Step 4: Commit**

```bash
git add godot/scripts/NiveladorTerreno.gd godot/scripts/NiveladorTerrenoTest.gd
git commit -m "feat: NiveladorTerreno recibe columnas explícitas en vez de ancho x alto"
```

---

### Task 3: `VoxelWorld.verificar_huella_libre()` — columnas explícitas

**Files:**
- Modify: `godot/scripts/VoxelWorld.gd`
- Modify: `godot/scripts/BlueprintValidatorTest.gd`

**Interfaces:**
- Consumes: nada de Task 1/2.
- Produces: `verificar_huella_libre(esquina, columnas, altura=1)` — firma nueva, consumida por Task 4 (`CamaraCenital.gd`).

Este task es independiente de la Task 1 y la Task 2 (toca un archivo de test compartido con Task 1, `BlueprintValidatorTest.gd`, pero en una sección distinta — ejecútalo después de la Task 1 para evitar conflictos de fusión en ese archivo).

- [ ] **Step 1: Reemplazar `verificar_huella_libre()` en `VoxelWorld.gd`**

Localiza:

```gdscript
## Revisa cada columna (x, z) de la huella ancho×alto con esquina "esquina".
## altura_en() no salta bloques estructurales (solo TIPOS_ARBOL y "fantasma"),
## así que un muro colocado sobre "piso" se convierte en la propia superficie
## que altura_en() devuelve — por eso el chequeo de estructura se hace SOBRE
## esa superficie (altura_en(x,z)), no una celda encima. "madera"/"follaje",
## en cambio, sí se buscan por ENCIMA de la superficie, porque altura_en()
## salta los árboles al calcularla y por lo tanto la superficie real queda
## justo debajo del árbol.
## "altura" (por defecto 1) es cuántos niveles Y por encima de la superficie
## se revisan en busca de madera/follaje — de superficie+1 a superficie+altura
## inclusive. El valor por defecto basta para los puestos POR AHORA (en esta
## PoC son un marcador de un solo bloque, alcance reducido — en el diseño
## real son construcciones como cualquier otra, con su propia altura, que
## podría variar incluso por era tecnológica, ver GDD Sección 7); cuando un
## puesto deje de ser un marcador de 1 bloque, deberá pasar su altura real
## igual que ya hace un blueprint de varios pisos, para que un tronco o
## pared que sobresalga por encima de superficie+1 también se detecte.
## "madera" o cualquier bloque estructural invalida la huella completa;
## "follaje" se acumula en follaje_a_eliminar (en cualquiera de los niveles
## revisados) sin invalidar (se borra al confirmar la colocación — ver GDD
## Sección 3, "Emplazamiento Dentro de un Bosque"). Usada por la validación
## de choques de los puestos periféricos y blueprints (CamaraCenital.gd) —
## no conoce Recoleccion.puestos, solo bloques reales.
func verificar_huella_libre(esquina: Vector2i, ancho: int, alto: int, altura: int = 1) -> Dictionary:
	var valida := true
	var follaje_a_eliminar: Array[Vector3i] = []
	for x in range(esquina.x, esquina.x + ancho):
		for z in range(esquina.y, esquina.y + alto):
			var superficie: int = altura_en(x, z)
			if es_celda_estructural(Vector3i(x, superficie, z)):
				valida = false
				continue
			for dy in range(1, altura + 1):
				var celda := Vector3i(x, superficie + dy, z)
				var tipo: String = obtener_tipo(celda)
				if tipo == "madera":
					valida = false
				elif tipo == "follaje":
					follaje_a_eliminar.append(celda)
	return {"valida": valida, "follaje_a_eliminar": follaje_a_eliminar}
```

Reemplaza por:

```gdscript
## Revisa cada columna de "columnas" (offsets Vector2i relativos a
## "esquina" — ver docs/superpowers/specs/2026-09-10-huellas-irregulares-design.md;
## un rectángulo es solo el caso particular de pasar range(ancho) x
## range(alto), ver CamaraCenital._columnas_rectangulo()).
## altura_en() no salta bloques estructurales (solo TIPOS_ARBOL y "fantasma"),
## así que un muro colocado sobre "piso" se convierte en la propia superficie
## que altura_en() devuelve — por eso el chequeo de estructura se hace SOBRE
## esa superficie (altura_en(x,z)), no una celda encima. "madera"/"follaje",
## en cambio, sí se buscan por ENCIMA de la superficie, porque altura_en()
## salta los árboles al calcularla y por lo tanto la superficie real queda
## justo debajo del árbol.
## "altura" (por defecto 1) es cuántos niveles Y por encima de la superficie
## se revisan en busca de madera/follaje — de superficie+1 a superficie+altura
## inclusive. El valor por defecto basta para los puestos POR AHORA (en esta
## PoC son un marcador de un solo bloque, alcance reducido — en el diseño
## real son construcciones como cualquier otra, con su propia altura, que
## podría variar incluso por era tecnológica, ver GDD Sección 7); cuando un
## puesto deje de ser un marcador de 1 bloque, deberá pasar su altura real
## igual que ya hace un blueprint de varios pisos, para que un tronco o
## pared que sobresalga por encima de superficie+1 también se detecte.
## "madera" o cualquier bloque estructural invalida la huella completa;
## "follaje" se acumula en follaje_a_eliminar (en cualquiera de los niveles
## revisados) sin invalidar (se borra al confirmar la colocación — ver GDD
## Sección 3, "Emplazamiento Dentro de un Bosque"). Usada por la validación
## de choques de los puestos periféricos y blueprints (CamaraCenital.gd) —
## no conoce Recoleccion.puestos, solo bloques reales.
func verificar_huella_libre(esquina: Vector2i, columnas: Array[Vector2i], altura: int = 1) -> Dictionary:
	var valida := true
	var follaje_a_eliminar: Array[Vector3i] = []
	for rel in columnas:
		var x: int = esquina.x + rel.x
		var z: int = esquina.y + rel.y
		var superficie: int = altura_en(x, z)
		if es_celda_estructural(Vector3i(x, superficie, z)):
			valida = false
			continue
		for dy in range(1, altura + 1):
			var celda := Vector3i(x, superficie + dy, z)
			var tipo: String = obtener_tipo(celda)
			if tipo == "madera":
				valida = false
			elif tipo == "follaje":
				follaje_a_eliminar.append(celda)
	return {"valida": valida, "follaje_a_eliminar": follaje_a_eliminar}
```

- [ ] **Step 2: Actualizar las llamadas existentes en `BlueprintValidatorTest.gd` (TEST 16 y TEST 19)**

Agrega esta función helper en `godot/scripts/BlueprintValidatorTest.gd` (al mismo nivel que las demás funciones del archivo, por ejemplo justo antes de `func ejecutar_pruebas()`):

```gdscript
func _rectangulo(ancho: int, alto: int) -> Array[Vector2i]:
	var columnas: Array[Vector2i] = []
	for x in range(ancho):
		for z in range(alto):
			columnas.append(Vector2i(x, z))
	return columnas
```

En TEST 16, localiza estas 4 llamadas:

```gdscript
	var resultado_madera: Dictionary = mundo.verificar_huella_libre(Vector2i(OX7, OX7), 4, 4)
```
```gdscript
	var resultado_follaje: Dictionary = mundo.verificar_huella_libre(Vector2i(base_b, OX7), 4, 4)
```
```gdscript
	var resultado_estructura: Dictionary = mundo.verificar_huella_libre(Vector2i(base_c, OX7), 4, 4)
```
```gdscript
	var resultado_libre: Dictionary = mundo.verificar_huella_libre(Vector2i(base_d, OX7), 4, 4)
```

Reemplaza cada una (mismo texto, cambiando solo los dos últimos argumentos por `_rectangulo(4, 4)`):

```gdscript
	var resultado_madera: Dictionary = mundo.verificar_huella_libre(Vector2i(OX7, OX7), _rectangulo(4, 4))
```
```gdscript
	var resultado_follaje: Dictionary = mundo.verificar_huella_libre(Vector2i(base_b, OX7), _rectangulo(4, 4))
```
```gdscript
	var resultado_estructura: Dictionary = mundo.verificar_huella_libre(Vector2i(base_c, OX7), _rectangulo(4, 4))
```
```gdscript
	var resultado_libre: Dictionary = mundo.verificar_huella_libre(Vector2i(base_d, OX7), _rectangulo(4, 4))
```

En TEST 19, localiza:

```gdscript
	var resultado_baja: Dictionary = mundo.verificar_huella_libre(Vector2i(OX9, OX9), 2, 2)
	assert(resultado_baja["valida"])  # altura por defecto (1): no llega al madera en y=2
	var resultado_alta: Dictionary = mundo.verificar_huella_libre(Vector2i(OX9, OX9), 2, 2, 2)
```

Reemplaza por:

```gdscript
	var resultado_baja: Dictionary = mundo.verificar_huella_libre(Vector2i(OX9, OX9), _rectangulo(2, 2))
	assert(resultado_baja["valida"])  # altura por defecto (1): no llega al madera en y=2
	var resultado_alta: Dictionary = mundo.verificar_huella_libre(Vector2i(OX9, OX9), _rectangulo(2, 2), 2)
```

- [ ] **Step 3: Ejecutar `Test.tscn` y verificar que las pruebas siguen pasando**

Ejecuta `godot/scenes/Test.tscn` y confirma que todas las pruebas (21, tras la Task 1) siguen pasando sin ningún `assert` fallido y sin errores nuevos.

- [ ] **Step 4: Commit**

```bash
git add godot/scripts/VoxelWorld.gd godot/scripts/BlueprintValidatorTest.gd
git commit -m "feat: verificar_huella_libre() recibe columnas explícitas en vez de ancho x alto"
```

---

### Task 4: `CamaraCenital.gd` — integrar columnas explícitas y huella real del blueprint

**Files:**
- Modify: `godot/scripts/CamaraCenital.gd`

**Interfaces:**
- Consumes: `NiveladorTerreno.verificar_pendiente/altura_objetivo/calcular_relleno(esquina, columnas)` (Task 2), `VoxelWorld.verificar_huella_libre(esquina, columnas, altura=1)` (Task 3), `blueprint["huella_relativa"]: Array[Vector2i]` (Task 1).

Este task depende de que las Tasks 1, 2 y 3 ya estén completas (usa las 3 firmas nuevas).

- [ ] **Step 1: Agregar el helper `_columnas_rectangulo()` y renombrar/generalizar `_huella_tiene_esquina_en_tierra()`**

Localiza:

```gdscript
## true si la huella (esquina, ancho x alto) tiene AL MENOS una esquina en
## tierra firme (no sobre agua) — evita construir puestos enteramente
## flotando en medio de un lago. Basta con revisar las 4 esquinas reales de
## la huella, no la huella completa: alcanza con una esquina firme para
## anclar la construcción, y el resto del agua bajo la huella se drena al
## confirmar (ver VoxelWorld.drenar_agua()).
func _huella_tiene_esquina_en_tierra(esquina: Vector2i, ancho: int, alto: int) -> bool:
	var esquinas := [
		esquina,
		Vector2i(esquina.x + ancho - 1, esquina.y),
		Vector2i(esquina.x, esquina.y + alto - 1),
		Vector2i(esquina.x + ancho - 1, esquina.y + alto - 1),
	]
	for e in esquinas:
		if mundo.obtener_tipo(Vector3i(e.x, mundo.altura_en(e.x, e.y), e.y)) != "agua":
			return true
	return false
```

Reemplaza por:

```gdscript
## Genera las columnas Vector2i(dx, dz) de un rectángulo ancho x alto
## (offsets relativos a una esquina) — usada por los puestos periféricos
## (mina, caza/recolección), que siguen siendo rectángulos fijos, para
## seguir pasando su huella a las funciones ya generalizadas a "columnas"
## (ver docs/superpowers/specs/2026-09-10-huellas-irregulares-design.md).
## Los blueprints, en cambio, usan directamente blueprint["huella_relativa"].
func _columnas_rectangulo(ancho: int, alto: int) -> Array[Vector2i]:
	var columnas: Array[Vector2i] = []
	for dx in range(ancho):
		for dz in range(alto):
			columnas.append(Vector2i(dx, dz))
	return columnas


## true si AL MENOS una columna real de la huella (esquina + columnas)
## está en tierra firme (no sobre agua) — evita construir puestos o
## blueprints enteramente flotando en medio de un lago. Basta con una
## columna firme para anclar la construcción, y el resto del agua bajo la
## huella se drena al confirmar (ver VoxelWorld.drenar_agua()). Antes solo
## revisaba las 4 esquinas del rectángulo delimitador — para una huella
## irregular (un edificio en L) esas esquinas pueden no ser parte real del
## edificio, así que ahora revisa TODAS las columnas reales (ver
## docs/superpowers/specs/2026-09-10-huellas-irregulares-design.md); para
## un rectángulo esto es un superconjunto estrictamente más permisivo que
## antes (4 columnas -> todas), nunca rechaza un caso que antes aceptaba.
func _huella_tiene_columna_en_tierra(esquina: Vector2i, columnas: Array[Vector2i]) -> bool:
	for rel in columnas:
		var x: int = esquina.x + rel.x
		var z: int = esquina.y + rel.y
		if mundo.obtener_tipo(Vector3i(x, mundo.altura_en(x, z), z)) != "agua":
			return true
	return false


## true si TODAS las columnas reales de la huella (esquina + columnas)
## caen dentro de una zona pintada que coincida con "zona_permitida".
## Antes solo se revisaba la celda central bajo el mouse — generalización
## necesaria para una huella irregular (un edificio en L no debe poder
## "asomar" su hueco a una zona distinta), y de paso cierra el pendiente ya
## documentado de que la validación de zona era puntual, solo para
## blueprints; la zona de influencia de los puestos (chequeo distinto,
## Zonificacion.dentro_de_influencia) no se toca.
func _huella_en_zona_correcta(esquina: Vector2i, columnas: Array[Vector2i], zona_permitida: String) -> bool:
	for rel in columnas:
		var xz := Vector2i(esquina.x + rel.x, esquina.y + rel.y)
		if Zonificacion.consultar_zona(xz) != zona_permitida:
			return false
	return true
```

- [ ] **Step 2: Generalizar `_huella_choca_con_otro_puesto()`**

Localiza:

```gdscript
## true si algún punto de la huella (esquina, ancho x alto) cae dentro de
## un puesto ya colocado (Recoleccion.puestos, cualquier tipo — mina, caza/
## recolección, o "blueprint") o de una construcción fantasma activa (una
## celda todavía en curso de ser surtida, ver Construccion.gd) — recorre la
## huella completa, no basta revisar solo las esquinas, sería incorrecto
## para un rectángulo genérico. Antes tomaba solo "esquina" y leía
## _ancho_puesto_activo/_alto_puesto_activo — ahora recibe ancho/alto
## explícitos para poder reutilizarse también desde el modo de colocación
## de blueprint (Task 7), que tiene su propio ancho/alto.
func _huella_choca_con_otro_puesto(esquina: Vector2i, ancho: int, alto: int) -> bool:
	for dx in range(ancho):
		for dz in range(alto):
			var xz := Vector2i(esquina.x + dx, esquina.y + dz)
			if Recoleccion.celda_dentro_de_algun_puesto(xz):
				return true
			var celda_superficie := Vector3i(xz.x, mundo.altura_en(xz.x, xz.y) + 1, xz.y)
			if Construccion.construccion_de(celda_superficie) != -1:
				return true
	return false
```

Reemplaza por:

```gdscript
## true si alguna columna real de la huella (esquina + columnas) cae dentro
## de un puesto ya colocado (Recoleccion.puestos, cualquier tipo — mina,
## caza/recolección, o "blueprint") o de una construcción fantasma activa
## (una celda todavía en curso de ser surtida, ver Construccion.gd).
## "columnas" son offsets relativos a "esquina" (ver
## docs/superpowers/specs/2026-09-10-huellas-irregulares-design.md) — un
## rectángulo es solo el caso particular de pasar
## _columnas_rectangulo(ancho, alto); una huella irregular (un edificio en
## L) pasa sus columnas reales, así que el hueco de la L nunca exige estar
## libre.
func _huella_choca_con_otro_puesto(esquina: Vector2i, columnas: Array[Vector2i]) -> bool:
	for rel in columnas:
		var xz := Vector2i(esquina.x + rel.x, esquina.y + rel.y)
		if Recoleccion.celda_dentro_de_algun_puesto(xz):
			return true
		var celda_superficie := Vector3i(xz.x, mundo.altura_en(xz.x, xz.y) + 1, xz.y)
		if Construccion.construccion_de(celda_superficie) != -1:
			return true
	return false
```

- [ ] **Step 3: Actualizar `_actualizar_previsualizacion_puesto()`**

Localiza:

```gdscript
func _actualizar_previsualizacion_puesto() -> void:
	var centro := _celda_bajo_mouse(get_viewport().get_mouse_position())
	@warning_ignore("integer_division")
	var esquina := centro - Vector2i(_ancho_puesto_activo / 2, _alto_puesto_activo / 2)

	var fuera_de_influencia: bool = not Zonificacion.dentro_de_influencia(centro)
	var relieve_valido: bool = nivelador_puesto.verificar_pendiente(esquina, _ancho_puesto_activo, _alto_puesto_activo)
	var resultado_huella: Dictionary = mundo.verificar_huella_libre(esquina, _ancho_puesto_activo, _alto_puesto_activo)
	var valida: bool = fuera_de_influencia and relieve_valido and resultado_huella["valida"] \
			and not _huella_choca_con_otro_puesto(esquina, _ancho_puesto_activo, _alto_puesto_activo) \
			and _huella_tiene_esquina_en_tierra(esquina, _ancho_puesto_activo, _alto_puesto_activo)
	var color: Color = COLOR_PUESTO_VALIDO if valida else COLOR_PUESTO_INVALIDO
```

Reemplaza por:

```gdscript
func _actualizar_previsualizacion_puesto() -> void:
	var centro := _celda_bajo_mouse(get_viewport().get_mouse_position())
	@warning_ignore("integer_division")
	var esquina := centro - Vector2i(_ancho_puesto_activo / 2, _alto_puesto_activo / 2)
	var columnas := _columnas_rectangulo(_ancho_puesto_activo, _alto_puesto_activo)

	var fuera_de_influencia: bool = not Zonificacion.dentro_de_influencia(centro)
	var relieve_valido: bool = nivelador_puesto.verificar_pendiente(esquina, columnas)
	var resultado_huella: Dictionary = mundo.verificar_huella_libre(esquina, columnas)
	var valida: bool = fuera_de_influencia and relieve_valido and resultado_huella["valida"] \
			and not _huella_choca_con_otro_puesto(esquina, columnas) \
			and _huella_tiene_columna_en_tierra(esquina, columnas)
	var color: Color = COLOR_PUESTO_VALIDO if valida else COLOR_PUESTO_INVALIDO
```

El resto de la función (el bucle que posiciona `_huella_puesto` y la sección de HUD/área de acción) NO cambia.

- [ ] **Step 4: Actualizar `_procesar_clic_puesto()`**

Localiza:

```gdscript
func _procesar_clic_puesto(posicion_pantalla: Vector2) -> void:
	var centro := _celda_bajo_mouse(posicion_pantalla)
	@warning_ignore("integer_division")
	var esquina := centro - Vector2i(_ancho_puesto_activo / 2, _alto_puesto_activo / 2)

	if Zonificacion.dentro_de_influencia(centro):
		print("No se puede colocar un puesto dentro de la zona de influencia.")
		return
	if not nivelador_puesto.verificar_pendiente(esquina, _ancho_puesto_activo, _alto_puesto_activo):
		print("Colocación rechazada: la pendiente de esta huella supera el límite permitido.")
		return
	var resultado_huella: Dictionary = mundo.verificar_huella_libre(esquina, _ancho_puesto_activo, _alto_puesto_activo)
	if not resultado_huella["valida"]:
		print("Colocación rechazada: la huella choca con un recurso de madera o una estructura existente.")
		return
	if _huella_choca_con_otro_puesto(esquina, _ancho_puesto_activo, _alto_puesto_activo):
		print("Colocación rechazada: la huella choca con un puesto ya colocado.")
		return
	if not _huella_tiene_esquina_en_tierra(esquina, _ancho_puesto_activo, _alto_puesto_activo):
		print("Colocación rechazada: la huella necesita al menos una esquina sobre tierra firme.")
		return
```

Reemplaza por:

```gdscript
func _procesar_clic_puesto(posicion_pantalla: Vector2) -> void:
	var centro := _celda_bajo_mouse(posicion_pantalla)
	@warning_ignore("integer_division")
	var esquina := centro - Vector2i(_ancho_puesto_activo / 2, _alto_puesto_activo / 2)
	var columnas := _columnas_rectangulo(_ancho_puesto_activo, _alto_puesto_activo)

	if Zonificacion.dentro_de_influencia(centro):
		print("No se puede colocar un puesto dentro de la zona de influencia.")
		return
	if not nivelador_puesto.verificar_pendiente(esquina, columnas):
		print("Colocación rechazada: la pendiente de esta huella supera el límite permitido.")
		return
	var resultado_huella: Dictionary = mundo.verificar_huella_libre(esquina, columnas)
	if not resultado_huella["valida"]:
		print("Colocación rechazada: la huella choca con un recurso de madera o una estructura existente.")
		return
	if _huella_choca_con_otro_puesto(esquina, columnas):
		print("Colocación rechazada: la huella choca con un puesto ya colocado.")
		return
	if not _huella_tiene_columna_en_tierra(esquina, columnas):
		print("Colocación rechazada: la huella necesita al menos una esquina sobre tierra firme.")
		return
```

Más abajo, en la misma función, localiza:

```gdscript
	var objetivo: int = nivelador_puesto.altura_objetivo(esquina, _ancho_puesto_activo, _alto_puesto_activo)
	var relleno: Dictionary = nivelador_puesto.calcular_relleno(esquina, _ancho_puesto_activo, _alto_puesto_activo)
```

Reemplaza por:

```gdscript
	var objetivo: int = nivelador_puesto.altura_objetivo(esquina, columnas)
	var relleno: Dictionary = nivelador_puesto.calcular_relleno(esquina, columnas)
```

El resto de la función (drenaje de agua, colocación de relleno, marcador del puesto, `Recoleccion.colocar_puesto()`) sigue usando `range(_ancho_puesto_activo)`/`range(_alto_puesto_activo)` SIN cambios — los puestos son siempre rectángulos, así que su drenaje/relleno/marcador no necesita restringirse a una lista de columnas distinta del rectángulo completo.

- [ ] **Step 5: Actualizar `_actualizar_previsualizacion_blueprint()`**

Localiza:

```gdscript
func _actualizar_previsualizacion_blueprint() -> void:
	var centro := _celda_bajo_mouse(get_viewport().get_mouse_position())
	var ancho: int = _blueprint_activo["ancho"]
	var alto: int = _blueprint_activo["profundidad"]
	@warning_ignore("integer_division")
	var esquina := centro - Vector2i(ancho / 2, alto / 2)

	var zona_correcta: bool = Zonificacion.consultar_zona(centro) == _blueprint_activo["zona_permitida"]
	var relieve_valido: bool = nivelador_puesto.verificar_pendiente(esquina, ancho, alto)
	var altura_blueprint: int = _altura_blueprint(_blueprint_activo)
	var resultado_huella: Dictionary = mundo.verificar_huella_libre(esquina, ancho, alto, altura_blueprint)
	var valida: bool = zona_correcta and relieve_valido and resultado_huella["valida"] \
			and not _huella_choca_con_otro_puesto(esquina, ancho, alto) \
			and _huella_tiene_esquina_en_tierra(esquina, ancho, alto)
	var color: Color = COLOR_PUESTO_VALIDO if valida else COLOR_PUESTO_INVALIDO

	var objetivo: int = nivelador_puesto.altura_objetivo(esquina, ancho, alto)
```

Reemplaza por:

```gdscript
func _actualizar_previsualizacion_blueprint() -> void:
	var centro := _celda_bajo_mouse(get_viewport().get_mouse_position())
	var ancho: int = _blueprint_activo["ancho"]
	var alto: int = _blueprint_activo["profundidad"]
	@warning_ignore("integer_division")
	var esquina := centro - Vector2i(ancho / 2, alto / 2)
	var columnas: Array[Vector2i] = _blueprint_activo["huella_relativa"]

	var zona_correcta: bool = _huella_en_zona_correcta(esquina, columnas, _blueprint_activo["zona_permitida"])
	var relieve_valido: bool = nivelador_puesto.verificar_pendiente(esquina, columnas)
	var altura_blueprint: int = _altura_blueprint(_blueprint_activo)
	var resultado_huella: Dictionary = mundo.verificar_huella_libre(esquina, columnas, altura_blueprint)
	var valida: bool = zona_correcta and relieve_valido and resultado_huella["valida"] \
			and not _huella_choca_con_otro_puesto(esquina, columnas) \
			and _huella_tiene_columna_en_tierra(esquina, columnas)
	var color: Color = COLOR_PUESTO_VALIDO if valida else COLOR_PUESTO_INVALIDO

	var objetivo: int = nivelador_puesto.altura_objetivo(esquina, columnas)
```

El resto de la función (el bucle que posiciona `_huella_blueprint` según `_offsets_huella_blueprint`) NO cambia.

- [ ] **Step 6: Actualizar `_procesar_clic_blueprint()`**

Localiza:

```gdscript
func _procesar_clic_blueprint(posicion_pantalla: Vector2) -> void:
	var centro := _celda_bajo_mouse(posicion_pantalla)
	var ancho: int = _blueprint_activo["ancho"]
	var alto: int = _blueprint_activo["profundidad"]
	@warning_ignore("integer_division")
	var esquina := centro - Vector2i(ancho / 2, alto / 2)

	if Zonificacion.consultar_zona(centro) != _blueprint_activo["zona_permitida"]:
		print("Colocación rechazada: esta zona no acepta este blueprint.")
		return
	if not nivelador_puesto.verificar_pendiente(esquina, ancho, alto):
		print("Colocación rechazada: la pendiente de esta huella supera el límite permitido.")
		return
	var altura_blueprint: int = _altura_blueprint(_blueprint_activo)
	var resultado_huella: Dictionary = mundo.verificar_huella_libre(esquina, ancho, alto, altura_blueprint)
	if not resultado_huella["valida"]:
		print("Colocación rechazada: la huella choca con un recurso de madera o una estructura existente.")
		return
	if _huella_choca_con_otro_puesto(esquina, ancho, alto):
		print("Colocación rechazada: la huella choca con un puesto o construcción ya colocada.")
		return
	if not _huella_tiene_esquina_en_tierra(esquina, ancho, alto):
		print("Colocación rechazada: la huella necesita al menos una esquina sobre tierra firme.")
		return

	for celda_follaje in resultado_huella["follaje_a_eliminar"]:
		mundo.eliminar_follaje(celda_follaje)

	var total_drenado := 0
	for dx in range(ancho):
		for dz in range(alto):
			total_drenado += mundo.drenar_agua(esquina.x + dx, esquina.y + dz)
	if total_drenado > 0:
		print("Agua drenada bajo la construcción: ", total_drenado, " bloques reemplazados por tierra.")

	var objetivo: int = nivelador_puesto.altura_objetivo(esquina, ancho, alto)
	var relleno: Dictionary = nivelador_puesto.calcular_relleno(esquina, ancho, alto)
```

Reemplaza por:

```gdscript
func _procesar_clic_blueprint(posicion_pantalla: Vector2) -> void:
	var centro := _celda_bajo_mouse(posicion_pantalla)
	var ancho: int = _blueprint_activo["ancho"]
	var alto: int = _blueprint_activo["profundidad"]
	@warning_ignore("integer_division")
	var esquina := centro - Vector2i(ancho / 2, alto / 2)
	var columnas: Array[Vector2i] = _blueprint_activo["huella_relativa"]

	if not _huella_en_zona_correcta(esquina, columnas, _blueprint_activo["zona_permitida"]):
		print("Colocación rechazada: esta zona no acepta este blueprint.")
		return
	if not nivelador_puesto.verificar_pendiente(esquina, columnas):
		print("Colocación rechazada: la pendiente de esta huella supera el límite permitido.")
		return
	var altura_blueprint: int = _altura_blueprint(_blueprint_activo)
	var resultado_huella: Dictionary = mundo.verificar_huella_libre(esquina, columnas, altura_blueprint)
	if not resultado_huella["valida"]:
		print("Colocación rechazada: la huella choca con un recurso de madera o una estructura existente.")
		return
	if _huella_choca_con_otro_puesto(esquina, columnas):
		print("Colocación rechazada: la huella choca con un puesto o construcción ya colocada.")
		return
	if not _huella_tiene_columna_en_tierra(esquina, columnas):
		print("Colocación rechazada: la huella necesita al menos una esquina sobre tierra firme.")
		return

	for celda_follaje in resultado_huella["follaje_a_eliminar"]:
		mundo.eliminar_follaje(celda_follaje)

	var total_drenado := 0
	for rel in columnas:
		total_drenado += mundo.drenar_agua(esquina.x + rel.x, esquina.y + rel.y)
	if total_drenado > 0:
		print("Agua drenada bajo la construcción: ", total_drenado, " bloques reemplazados por tierra.")

	var objetivo: int = nivelador_puesto.altura_objetivo(esquina, columnas)
	var relleno: Dictionary = nivelador_puesto.calcular_relleno(esquina, columnas)
```

El resto de la función (relleno_orden, celdas_mundo, orden, tipos, huella_xz local, metadata, `mundo.iniciar_construccion_fantasma()`) NO cambia.

- [ ] **Step 7: Ejecutar `Test.tscn` y `Main.tscn`**

Ejecuta `godot/scenes/Test.tscn` (deben seguir pasando las 21 pruebas) y `godot/scenes/Main.tscn` (sin errores nuevos más allá de las 2 advertencias conocidas de colisión de nombre de clase). `CamaraCenital.gd` no tiene pruebas automatizadas propias (lógica de input/cámara), así que esta verificación headless solo confirma ausencia de errores de parseo/ejecución — la confirmación funcional real (colocar un puesto, colocar un blueprint, incluido uno de huella irregular) queda para que el usuario la pruebe jugando en vivo en el editor, mismo patrón que el resto de cambios a este archivo en esta sesión.

- [ ] **Step 8: Commit**

```bash
git add godot/scripts/CamaraCenital.gd
git commit -m "feat: puestos y blueprints usan columnas explícitas; blueprints validan/aplican solo sobre su huella real"
```

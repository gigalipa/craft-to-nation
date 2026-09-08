# Puestos de Recolección (Minas) — Diseño

**Alcance:** PoC 5, sub-proyecto 3 (Fase 3 del roadmap, GDD Sección 11 v3.20). Cubre GDD Sección 3 ("Área de Acción de los Puestos de Recolección") y Sección 3.1 (categoría "Recolección") **solo para minas** — madereros, puestos de caza y de recolección vegetal quedan pendientes hasta que exista generación de vegetación/fauna/agua real (sub-proyecto 4, sin diseño todavía).

**Repo:** `C:\Users\peraz\Projects\Misc\CityCraft`, proyecto Godot 4.7 compartido en `godot/`.

## Decisiones de alcance confirmadas con el usuario

- Solo minas en este sub-proyecto (no madereros/caza/vegetal).
- El hierro se genera con ruido 3D real (vetas/grumos deformes), no valores fijos ni mock.
- `PROFUNDIDAD_SUBSUELO` sube de 8 a 24 para dar espacio real a la variación de profundidad.
- Solo nivel 1 de mina (sin niveles 2/3 todavía — esperan el sistema de "Mejoramiento de edificios" del GDD Sección 3.1, ya marcado como diseño futuro).
- Sin producción real por tick: este sub-proyecto es colocación + previsualización únicamente, coherente con su nombre en el roadmap ("Puestos de Recolección + previsualización en HUD").
- Colocación gratuita (igual que la nivelación de terreno) — el juego no tiene inventario de recursos todavía.
- Colocación vía un nuevo modo en la cámara cenital (mismo patrón que nivelación/zonificación), no un menú de construcción (no existe todavía).

## 1. Vetas de hierro (`GeneradorMundo.gd`)

**Generación:** un segundo `FastNoiseLite` (`_ruido_mineral`), inicializado en `_init()` con una semilla derivada de `SEMILLA_MUNDO` (p. ej. `semilla + 1`, para que siga siendo determinista con una sola semilla de entrada) y `noise_type = TYPE_PERLIN`, `frequency` baja (p. ej. `0.05`, más baja que la de altura para producir grumos/vetas grandes en vez de ruido puntual disperso).

**Regla de sustitución:** cualquier celda que `tipo_en_profundidad()` clasificaría como `"piedra"` (`profundidad_bajo_superficie >= GROSOR_TIERRA`) se convierte en `"hierro"` si `_ruido_mineral.get_noise_3d(x, y, z) > UMBRAL_HIERRO` (constante nueva, calibrar para que el hierro sea claramente minoritario frente a la piedra — punto de partida `0.55`, en el rango `[-1, 1]` de `get_noise_3d()`). El hierro **nunca** aparece en la capa de tierra (`profundidad_bajo_superficie < GROSOR_TIERRA`), sin importar el ruido.

**Cambio de firma:** `tipo_en_profundidad(profundidad_bajo_superficie: int) -> String` pasa a `tipo_en_profundidad(x: int, y: int, z: int, profundidad_bajo_superficie: int) -> String` — necesita las coordenadas absolutas para muestrear el ruido 3D (antes solo dependía de la profundidad relativa). Único llamador: `VoxelWorld._generar_terreno()`, que ya tiene `x`, `z` y calcula `y = altura - profundidad` — se actualiza ese único call site.

**`PROFUNDIDAD_SUBSUELO`:** sube de 8 a 24 en `VoxelWorld.gd`. Impacto esperado en tiempo de carga: proporcional (8→24 es 3x las celdas de subsuelo por columna) — verificar en vivo con `mcp__godot__run_project` que `Main.tscn` sigue cargando en un tiempo razonable (referencia: 8 cargaba en ~6s; si 24 se acerca a los ~35s que tenía el valor original de 32, evaluar con el usuario si hace falta ajustar).

**Bloque nuevo:** `"hierro"` en la `MeshLibrary` (`BlockLibrarySource.tscn` → `assets/BlockLibrary.res`), mismo patrón placeholder de color plano que `"tierra"`/`"piedra"` (un color distintivo, p. ej. marrón-rojizo/óxido).

## 2. Datos y colocación de la mina

**Nuevo autoload `Recoleccion.gd`** (mismo patrón que `Zonificacion.gd`/`Ciudad.gd`: estado puro, sin nodos de escena, sin `class_name`):

```gdscript
extends Node

const RADIO_AREA_MINA := 6      # radio horizontal de la semiesfera de acción
const PROFUNDIDAD_MINA_NIVEL_1 := 8   # alcance vertical hacia abajo (nivel 1)
const TASA_BASE_POR_CIUDADANO := 2.0  # recursos/hora a concentración 100%

# GDD Sección 3, ejemplo "mina manual, Tipo 1" — informativo, no se cobra.
const COSTO_CONSTRUCCION := {"tierra": 10, "madera": 10, "piedra": 5}
const PERSONAL_MAXIMO := 3
const CAPACIDAD_ALMACENAMIENTO := 100

var puestos: Dictionary = {}  # Vector2i (celda de superficie) -> {"nivel": int}


func colocar_mina(celda: Vector2i) -> void:
	puestos[celda] = {"nivel": 1}


## Cuenta los tipos reales dentro de la semiesfera (radio RADIO_AREA_MINA,
## hacia abajo PROFUNDIDAD_MINA_NIVEL_1) centrada en (centro_xz, altura_superficie).
## mundo: VoxelWorld (duck typing sobre obtener_tipo(), mismo patrón que
## NiveladorTerreno con altura_en()).
func detectar_recursos(mundo: Object, centro_xz: Vector2i, altura_superficie: int) -> Dictionary:
	var conteo: Dictionary = {}  # String (tipo) -> int
	for dx in range(-RADIO_AREA_MINA, RADIO_AREA_MINA + 1):
		for dz in range(-RADIO_AREA_MINA, RADIO_AREA_MINA + 1):
			for dy in range(0, PROFUNDIDAD_MINA_NIVEL_1 + 1):
				var offset := Vector3(dx, -dy, dz)
				if offset.length() > RADIO_AREA_MINA:
					continue
				var celda := Vector3i(centro_xz.x + dx, altura_superficie - dy, centro_xz.y + dz)
				var tipo: String = mundo.obtener_tipo(celda)
				if tipo != "":
					conteo[tipo] = conteo.get(tipo, 0) + 1
	return conteo


## Tasa de recolección prevista por ciudadano y tipo de recurso, a partir
## del conteo de detectar_recursos() — ver Sección 3 de la spec.
func tasas_recoleccion(conteo: Dictionary) -> Dictionary:
	var total := 0
	for tipo in conteo:
		total += conteo[tipo]
	if total == 0:
		return {}
	var tasas: Dictionary = {}
	for tipo in conteo:
		tasas[tipo] = (float(conteo[tipo]) / float(total)) * TASA_BASE_POR_CIUDADANO
	return tasas
```

**Colocación en `CamaraCenital.gd`:** nueva tecla `M` (solo con la cenital activa, mismo patrón que `B` para nivelación) activa `modo_colocar_mina`. Mientras está activo:
- Cada fotograma, `_celda_bajo_mouse()` (ya existente) determina la celda de superficie bajo el cursor.
- Un disco traslúcido (radio `Recoleccion.RADIO_AREA_MINA`, siguiendo la altura real de cada celda — mismo patrón de plano-por-celda que `ZonaOverlay`/la huella de nivelación) se dibuja sobre el terreno como vista previa del área de acción horizontal (la semiesfera es 3D, pero para la previsualización basta mostrar su proyección en planta, igual que la huella de nivelación no intenta mostrar profundidad).
- El color del disco indica si la colocación es válida ahí: verde si la celda está fuera de la zona de influencia (`not Zonificacion.dentro_de_influencia(celda)`), rojo si está dentro (inválido).
- `Recoleccion.detectar_recursos()` se recalcula cada fotograma con la celda actual y alimenta la ficha del HUD (ver Sección 3).
- Un clic, si la celda es válida: `Recoleccion.colocar_mina(celda)`, coloca el bloque marcador `"mina"` en la superficie (`mundo.colocar_bloque(Vector3i(celda.x, altura, celda.y), "mina")`, **sin** `colocado_por_jugador` — no debe participar en el flood-fill de "declarar edificio"), sale del modo.

**Bloque nuevo:** `"mina"` en la `MeshLibrary`, mismo patrón placeholder.

**Sin validación de solapamiento entre minas** — fuera de alcance para esta pieza.

## 3. Ficha en vivo en el HUD

**`HUD.gd`:** nueva sección (oculta por defecto) en `HUDLayer/HUD`, con:
- Costo de construcción, personal máximo y capacidad de almacenamiento — **valores fijos** de `Recoleccion.COSTO_CONSTRUCCION`/`PERSONAL_MAXIMO`/`CAPACIDAD_ALMACENAMIENTO`, mostrados una vez al activar el modo (no cambian por posición).
- Recolección prevista por ciudadano y tipo de recurso — **recalculada en vivo**, una línea por tipo detectado (p. ej. "2.0 tierra/h", "1.3 piedra/h", "0.7 hierro/h"), a partir de `Recoleccion.tasas_recoleccion()`.

**Nuevas funciones públicas:**
```gdscript
func mostrar_ficha_mina() -> void  # crea/muestra el contenedor, con los valores fijos
func actualizar_tasas_mina(tasas: Dictionary) -> void  # reescribe solo las líneas de tasa
func ocultar_ficha_mina() -> void
```

`CamaraCenital.gd` llama `mostrar_ficha_mina()` al activar `modo_colocar_mina`, `actualizar_tasas_mina()` cada fotograma junto al resto de la previsualización, y `ocultar_ficha_mina()` al confirmar la colocación o cancelar el modo (mismo patrón que `_mostrar_huella_fantasma()`).

## Pruebas

- `RecoleccionTest.gd` (nueva escena `RecoleccionTest.tscn`, mismo patrón que `NiveladorTerrenoTest.gd`): `detectar_recursos()` sobre un `VoxelWorld` de prueba con tipos conocidos colocados a mano (sin generación real, para conteos exactos); `tasas_recoleccion()` con conteos conocidos verifica la proporción exacta; caso borde de área totalmente vacía (sin bloques detectados) devuelve `{}` sin dividir por cero.
- `GeneradorMundoTest.gd` (existente, se amplía): un test nuevo verifica que `tipo_en_profundidad()` nunca devuelve `"hierro"` para `profundidad_bajo_superficie < GROSOR_TIERRA` en un muestreo amplio de coordenadas, y que con un umbral forzado a `-2.0` (siempre supera el umbral) toda celda de piedra se vuelve hierro — confirma que la sustitución ocurre donde debe.
- Verificación manual en el editor (como el resto de esta PoC): colocar una mina, confirmar visualmente que el disco de previsualización sigue el relieve y cambia de color dentro/fuera de la zona de influencia, y que la ficha del HUD se actualiza al mover el cursor.

## Fuera de alcance (explícito)

- Madereros, puestos de caza y de recolección vegetal (dependen de vegetación/fauna/agua real — sub-proyecto 4).
- Niveles 2/3 de mina (dependen del sistema de "Mejoramiento de edificios", GDD Sección 3.1, diseño futuro).
- Producción real por tick / inventario de recursos / cobro del costo de construcción.
- Validación de solapamiento entre puestos.
- Escalar `PROFUNDIDAD_SUBSUELO` hasta los ~300 bloques finales del GDD (ya anotado como optimización futura en `PoC_5/`).

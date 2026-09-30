# Diseño: previsualización isométrica de construcciones en el HUD cenital

Trabajo de UX/UI intercalado antes de la parte 2 del punto 4 de `docs/Pendientes y próximos pasos.md` (refinerías reales), decisión del usuario (2026-09-30).

Decisiones confirmadas con el usuario (2026-09-30), en orden de aparición durante el brainstorming.

## 1. Alcance

**Dentro:**
- Miniatura isométrica (render 3D real, no un dibujo aparte) de cada una de las 5 opciones del submenú Construir (Residencial + Mina/Caza/Madera/Pesca), junto al texto existente de cada botón (no lo reemplaza).
- La miniatura usa la malla y el material reales de cada bloque (mismo principio que `Hotbar.gd`: si cambia el arte, el ícono lo refleja solo).
- Las 5 miniaturas rotan juntas en incrementos de 90° cuando el jugador gira con Ctrl+rueda (en modo colocar puesto o modo colocar blueprint), aunque solo una construcción esté activa en el mapa.
- Espacio fijo por miniatura: no cambia con el tamaño real de la huella (mina 5×5 vs. maderero 3×3); la miniatura se ajusta (letterbox) a ese espacio.
- Botón "Residencial" atenuado (`modulate` reducido) cuando no hay ningún blueprint declarado (`Blueprints.obtener("residencial_investigacion")` vacío); sigue siendo clickeable y dispara la misma notificación de "declara un edificio primero" que ya existe.
- Tecla `B` (y clic en el botón principal "Construir") pasan a abrir/cerrar solo el submenú Construir (toggle), sin activar automáticamente la colocación del blueprint residencial. Elegir una opción dentro del menú (clic en cualquiera de los 5 botones) sigue activando esa colocación exactamente como hoy.
- Placeholder de ícono (campo opcional, sin arte real todavía) en los botones de la barra principal (Ver/Construir/Zonas/Vías) y de la subbarra de Zonas (Zona A/Zona B/Borrar).

**Fuera (documentado, no se construye aquí):**
- Arte/íconos reales para los modos Ver/Construir/Zonas/Vías y para Zona A/Zona B/Borrar: solo se deja el espacio y el mecanismo (`icono` opcional), igual que ya quedó pendiente para la hotbar de bloques sueltos.
- Selector de material para los blueprints de puestos (ya documentado como fuera de alcance en `2026-09-29-costo-colocacion-bloques-design.md`): la miniatura de cada puesto usa el material fijo actual de `PlantillasPuesto.MATERIAL`.
- Miniaturas de zonas o vías (Zona A/B, Borrar, trazado de vías): no son "construcciones" con volumen 3D, quedan con su apariencia de texto actual.
- Cambiar qué botones existen en el menú Construir o su distribución general (columnas, orden): solo cambia el contenido visual de cada botón y el tamaño del panel.

## 2. Renderizador de miniaturas compartido

`Hotbar.gd` ya tiene toda la lógica necesaria (`_malla_de_item()`, `_piezas_de_icono()`, `_renderizar_icono()`): arma piezas `[malla, posición relativa, material o null]`, las monta en un `SubViewport` aislado (`own_world_3d`) con una cámara ortográfica diagonal, y devuelve la textura. Se extrae a un nuevo archivo sin estado `MiniaturaRenderer.gd` (funciones estáticas + una copia propia de `MeshLibrary` igual a la que ya usa `Hotbar`, mismo motivo: `CACHE_MODE_IGNORE` para no heredar mutaciones de `VoxelWorld._indexar_biblioteca()`):

- `malla_de_item(nombre_item: String) -> Mesh` — reemplaza a `Hotbar._malla_de_item()`.
- `renderizar(piezas: Array, direccion_camara: Vector3, update_mode: int) -> Texture2D` — reemplaza a `Hotbar._renderizar_icono()`, con la dirección de cámara parametrizada (Hotbar sigue usando su diagonal `(1,1,1)` actual; el menú Construir usa `(1, 1, -1)`, ver Sección 4) y el modo de actualización parametrizado (Hotbar sigue usando `UPDATE_ONCE`; el menú Construir también usa `UPDATE_ONCE` pero fuerza un nuevo frame en cada rotación, ver Sección 5).

`Hotbar.gd` pasa a llamar a `MiniaturaRenderer` en vez de tener su propia copia; `_piezas_de_icono()` (con sus casos especiales de vidrio/puerta/cama) se queda en `Hotbar.gd` tal cual, porque es específica de las casillas sueltas de bloque, no de construcciones completas.

## 3. Conversión de cada opción a piezas

Nueva función `_piezas_de_construccion(tipo: String, giros: int) -> Array` en `BarraModos.gd`, que arma el diccionario `Vector3i -> tipo_bloque` según la opción y lo convierte a piezas `[malla, posición, null]` (sin materiales especiales: todas las celdas de una construcción tienen malla real en `BlockLibrary`, a diferencia de vidrio/puerta sueltos en la hotbar):

- **Residencial:** `Blueprints.obtener("residencial_investigacion")["celdas_3d"]`, rotado `giros` veces con la misma rotación 90° que usa `CamaraCenital._rotar_blueprint()` (se extrae esa rotación a una función pura `BlueprintValidator.rotar_celdas_3d(celdas_3d: Dictionary) -> Dictionary` reutilizable desde ambos sitios, en vez de mutar el estado de colocación solo para previsualizar). Si `Blueprints.obtener(...)` está vacío, no hay piezas (miniatura en blanco).
- **Mina/Caza/Madera/Pesca:** `PlantillasPuesto.celdas(tipo, giros)` directo — ya da el diccionario con la rotación aplicada, sin reimplementar nada.

Para cada celda del diccionario resultante: `malla = MiniaturaRenderer.malla_de_item(NOMBRE_FISICO_BIBLIOTECA.get(tipo_bloque, tipo_bloque))` (mismo mapeo `adobe` → `tierra_compactada` que ya existe en `Hotbar.gd`, movido a `MiniaturaRenderer` porque ahora lo usan dos sitios). Celdas sin malla real (`vidrio`, `puerta_inferior`/`puerta_superior`) se saltan en esta primera versión — son un detalle menor dentro de una vista general del edificio, no bloquean la miniatura del resto.

## 4. Cámara: esquina superior-derecha de la fachada frontal

Las plantillas (`PlantillasPuesto.gd`) y los blueprints tienen su puerta/frente mirando a −Z. "Esquina superior-derecha de la fachada frontal" es la dirección de cámara `Vector3(1, 1, -1)` (derecha, arriba, hacia el frente) en vez de la diagonal simétrica `(1, 1, 1)` que ya usa `Hotbar._renderizar_icono()` para bloques sueltos (sin frente definido). Mismo encuadre ortográfico automático por AABB combinado que ya calcula `_renderizar_icono()` (radio = eje más largo × 0.85), sin cambios ahí.

## 5. Rotación en vivo

`BarraModos.gd` gana un estado `_giros_menu := 0` (0-3) y un método `set_giros(giros: int)`, que solo re-renderiza las 5 miniaturas (`MiniaturaRenderer.renderizar()` con `update_mode = UPDATE_ONCE`, que fuerza un nuevo frame porque cambian las piezas/posiciones del `SubViewport`, no porque quede en modo continuo). `HUD.gd` expone `set_giros_construccion(giros: int)` que delega a `_barra_modos.set_giros(giros)`.

`CamaraCenital.gd` llama a `hud.set_giros_construccion(giros)`:
- En `_rotar_huella_puesto()`, con `_giros_puesto` ya incrementado.
- En `_rotar_blueprint()`, con un contador nuevo `_giros_blueprint := 0` (hoy esa función rota las celdas directamente sin llevar contador — se le agrega uno solo para esto, incrementado mod 4 igual que `_giros_puesto`).

Si ninguna construcción está activa (menú recién abierto, nada seleccionado), `_giros_menu` se reinicia a 0 al entrar al modo "construir" (`_alternar_modo_menu_construir()`, ver Sección 6).

## 6. Tecla B / menú Construir desacoplado de la colocación

Nuevo estado `_menu_construir_abierto := false` (true mientras el submenú está visible, con o sin una opción activa — a diferencia de `modo_colocar_blueprint`/`modo_colocar_puesto`, que solo son true cuando hay una construcción concreta en colocación) y nueva función en `CamaraCenital.gd`:

```
func _alternar_modo_menu_construir() -> void:
	if _menu_construir_abierto or modo_colocar_blueprint or modo_colocar_puesto:
		_salir_de_modo_menu_construir()
		return
	_salir_de_modo_zonificar()
	if modo_trazar_via:
		_salir_de_modo_trazar_via()
	_menu_construir_abierto = true
	_giros_menu = 0
	hud.set_giros_construccion(0)
	hud.set_modo("construir", "")


func _salir_de_modo_menu_construir() -> void:
	if modo_colocar_blueprint:
		_salir_de_modo_colocar_blueprint()
	if modo_colocar_puesto:
		_salir_de_modo_colocar_puesto()
	_menu_construir_abierto = false
	hud.set_modo("")
```

`_salir_de_modo_colocar_blueprint()`/`_salir_de_modo_colocar_puesto()` ya limpian el fantasma, overlays y `hud.set_modo("")` cuando "estaba" activo — llamarlas primero y dejar el `hud.set_modo("")` final de `_salir_de_modo_menu_construir()` cubre también el caso de menú abierto sin nada activo, sin duplicar lógica de limpieza.

Sustituye a `_alternar_modo_colocar_blueprint()` como handler de:
- `KEY_B` en `_unhandled_input()` (línea 1278).
- `_on_modo_pedido("construir")` (línea 1373, clic en el botón principal "Construir" de `BarraModos`).

`_alternar_modo_colocar_blueprint()` se sigue usando, sin cambios de comportamiento, como handler de `_on_construccion_pedida("residencial")` (clic en el botón "Residencial" del submenú) — ahí es donde de verdad activa la colocación, y ahí es donde ya notifica si no hay blueprint declarado.

Segunda pulsación de `B` con el menú ya abierto (con o sin una opción activa) cierra todo el sistema de construcción y vuelve a "Ver", igual que hoy hace `KEY_Z`/`KEY_V` con sus propios modos — no reactiva Residencial como atajo.

## 7. Botón "Residencial" atenuado

`BarraModos._refrescar()` consulta `Blueprints.obtener("residencial_investigacion").is_empty()` cada vez que refresca (mismo momento que ya resalta el botón activo) y aplica `modulate = Color(1,1,1,0.4)` (mismo patrón que otros estados atenuados del HUD) al botón "Residencial" si está vacío, `Color.WHITE` si no. El clic sigue llamando a `construccion_pedida.emit("residencial")` sin condición: el rechazo real sigue viviendo en `_alternar_modo_colocar_blueprint()`.

## 8. Layout de tamaño fijo

Los 5 botones del submenú Construir (`_crear_boton()` con tamaño `Vector2(88, 36)`) pasan a `Vector2(88, 64)`: una caja de miniatura de 40×40 arriba, texto+tecla abajo (mismo patrón de columna que usa `Hotbar.gd` con su `TextureRect` + `Label`). La miniatura usa `TextureRect.EXPAND_IGNORE_SIZE` + `STRETCH_KEEP_ASPECT_CENTERED`, igual que en `Hotbar.gd`, así que una huella de 5×5 y una de 3×3 ocupan el mismo espacio de 40×40 sin deformarse.

## 9. Placeholders de ícono (barras Modos y Zonas)

`MODOS` y `ZONAS` en `BarraModos.gd` ganan un 4º elemento opcional `icono` (hoy siempre `""`/ausente — ningún dato real todavía). `_crear_boton()` gana un parámetro opcional `icono: Texture2D = null`: si no es null, antepone un `TextureRect` de 24×24 al texto (mismo patrón columna-simple); si es null (todos los casos hoy), el botón se ve exactamente igual que ahora. Esto deja el mecanismo listo para cuando exista arte, sin dibujar ningún ícono placeholder visible todavía (no hay ninguna imagen de relleno que mostrar sin arte real).

## 10. Pruebas

Nuevo `MiniaturaMenuTest.tscn`/`MiniaturaMenuTest.gd` (además de correr `Test.tscn`):
- `MiniaturaRenderer.malla_de_item()` devuelve una malla no nula para un tipo de bloque real, y `null` para un tipo sin malla (vidrio).
- `MiniaturaRenderer.renderizar()` con una pieza simple devuelve una `Texture2D` no nula.
- `BlueprintValidator.rotar_celdas_3d()` aplicada 4 veces devuelve el diccionario original (mismo caso que ya cubre `PlantillasPuestoTest` para `PlantillasPuesto.celdas(tipo, 4) == celdas(tipo, 0)`).
- `_alternar_modo_menu_construir()` dejar `_modo == "construir"` con `_blueprint_activo` vacío y `modo_colocar_puesto == false` (no activa colocación al solo abrir el menú).
- Con `Blueprints` vacío, el botón "Residencial" queda con `modulate.a < 1.0`; tras `Blueprints.guardar(...)`, vuelve a `modulate.a == 1.0`.

Verificación manual (Godot 4.7): abrir Construir con `B` sin blueprint declarado (el menú se abre, Residencial atenuado), declarar un edificio y confirmar que Residencial deja de estar atenuado, colocar cada puesto y girar con Ctrl+rueda confirmando que las 5 miniaturas giran juntas, cambiar de puesto activo y confirmar que la miniatura correspondiente sigue mostrando su huella real aunque cambie de 5×5 a 3×3, pulsar `B` dos veces seguidas y confirmar que cierra el menú sin activar Residencial.

## 11. Documentación

Actualizar `docs/Pendientes y próximos pasos.md`: agregar esta entrega a la ruta (antes de la parte 2 del punto 4), marcarla hecha cuando se verifique en vivo.

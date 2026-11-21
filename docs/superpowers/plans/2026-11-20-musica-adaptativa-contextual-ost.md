# Sistema de Música Adaptativa Contextual (OST por Estado de Juego) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar la playlist lineal fija de 3 pistas en `Sonidos.gd` por un Director de Música Adaptativa Contextual con las 17 pistas etiquetadas de `arte/ost/` y `godot/assets/musica/`, crossfade con doble reproductor, histéresis anti-rebote, *shuffle bag* sin repeticiones consecutivas e integración reactiva con `Main.gd`, `Colonos.gd`, `Player.gd` y `HUD.gd`.

**Architecture:** `Sonidos.gd` centraliza el catálogo de pistas clasificadas por etiqueta `(menu|exploration|building|industry|battle)`, un doble `AudioStreamPlayer` (`_player_musica` activo + `_player_musica_secundario` saliente, intercambiables en cada crossfade para conservar compatibilidad con `ConfiguracionTest.gd`), una máquina de estados con prioridad estricta + histéresis ambiental y una bolsa barajada por contexto. `Main.gd` evalúa el estado del mundo cada `Ajustes.MUSICA_INTERVALO_EVALUACION_S` (`1.0 s`) y delega en `Sonidos.evaluar_contexto_musical()`, mientras `Colonos.gd` y `Player.gd` disparan `Sonidos.notificar_evento_combate()` en tiempo real.

**Tech Stack:** Godot 4.7.2 (GDScript), `AudioStreamPlayer`, `AudioStreamMP3`, `Tween`, `ffmpeg` (`libmp3lame -q:a 2`), PowerShell + Godot headless test runner (`tools/run-godot-tests.ps1`).

**Spec:** [docs/superpowers/specs/2026-11-20-musica-adaptativa-contextual-ost-design.md](file:///c:/Users/peraz/Projects/Misc/CityCraft/docs/superpowers/specs/2026-11-20-musica-adaptativa-contextual-ost-design.md)

## Global Constraints

- Godot 4 no importa `.m4a` (AAC) nativamente: los 4 `.m4a` de `arte/ost/` deben convertirse a `.mp3` con `ffmpeg -c:a libmp3lame -q:a 2` y copiarse a `godot/assets/musica/` junto a los 12 `.mp3` de `arte/ost/`, conservando `The_Architect_s_Decree (menu).mp3` (total exacto: **17 pistas**).
- Limpieza obligatoria de duplicados: eliminar los 9 archivos antiguos `*(loop).mp3` y sus `.mp3.import` en `godot/assets/musica/` (todos tienen su reemplazo etiquetado en `arte/ost/`).
- Respetar el nombre exacto con doble espacio de `Seamless_loop  (building).mp3` tal como existe en `arte/ost/`.
- Importar todos los `.mp3` nuevos en Godot (`--headless --path godot --import --quit`) para generar los `.mp3.import` correspondientes.
- Mantener compatibilidad total con las llamadas existentes (`Sonidos.reproducir_musica_menu()`, `Sonidos.reproducir_musica_juego()`, `Sonidos.detener_musica()`, `Sonidos.actualizar_volumen_musica()`, `Sonidos._player_musica` siempre apuntando al reproductor activo con `process_mode = Node.PROCESS_MODE_ALWAYS`).
- Parámetros exactos en `godot/scripts/ajustes.gd`: `MUSICA_CROSSFADE_AMBIENTAL_S = 3.0`, `MUSICA_CROSSFADE_BATALLA_S = 0.8`, `MUSICA_HISTERESIS_AMBIENTAL_S = 4.0`, `MUSICA_PERMANENCIA_MINIMA_PISTA_S = 15.0`, `MUSICA_COOLDOWN_BATALLA_S = 15.0`, `MUSICA_RADIO_DETECCION_INDUSTRIA = 12.0`, `MUSICA_INTERVALO_EVALUACION_S = 1.0`.
- En Windows, ejecutar escenas de prueba headless siempre esperando finalización con `Start-Process ... -Wait -PassThru` y validando log / exit code `0`, o vía `pwsh -File tools/run-godot-tests.ps1`.

## Execution Lines & Dependency Matrix

Todas las tareas comparten el contrato de `Sonidos.gd`, `ajustes.gd` y `SonidosTest.gd`, por lo que forman una única línea secuencial:

- **Line A (Secuencial):** Task 1 (Assets + `ajustes.gd`) -> Task 2 (Director Musical en `Sonidos.gd` + pruebas unitarias) -> Task 3 (Integración en `Main.gd`, `Colonos.gd`, `Player.gd`, `HUD.gd` + pruebas de integración)
  - Files: `godot/assets/musica/*`, `godot/scripts/ajustes.gd`, `godot/scripts/Sonidos.gd`, `godot/scripts/SonidosTest.gd`, `godot/scripts/Main.gd`, `godot/scripts/Colonos.gd`, `godot/scripts/Player.gd`, `godot/scripts/HUD.gd`
  - Local Test: `SonidosTest.tscn` y `ConfiguracionTest.tscn`
- **Global Integration Test:** `pwsh -File tools/run-godot-tests.ps1` (las 37 escenas de prueba deben pasar sin errores).

## Review Focus

1. **Ajuste de volumen o silencio en medio de un crossfade activo:** Si el usuario silencia la música (`actualizar_volumen_musica(0.0)`) o cambia el volumen mientras un `Tween` de crossfade está en curso, el `Tween` antiguo no debe volver a subir el volumen del reproductor silenciado; debe cancelarse/actualizarse ambos reproductores inmediatamente. (Cubierto en Task 2, `test_volumen_y_silencio_durante_crossfade`).
2. **Re-disparo rápido de combate o cambios de estado durante un crossfade:** Llamar a `notificar_evento_combate()` varias veces seguidas mientras ya está en `"battle"` solo debe reiniciar el cooldown de `15 s` sin reiniciar ni cortar la pista actual; y si cambia de contexto en mitad de un crossfade previo, el tween anterior debe matarse limpiamente antes de crear el nuevo. (Cubierto en Task 2, `test_combate_continuo_no_reinicia_pista`).
3. **Finalización natural de pista vs. histéresis de permanencia mínima:** Si la pista ambiental actual termina naturalmente (`finished`) antes de `15 s` y hay un candidato ambiental esperando histéresis (o ya cumplió los `4 s`), la transición no debe quedar bloqueada esperando permanencia mínima; y si no hay cambio de contexto, debe avanzar a la siguiente pista del mismo contexto en el *shuffle bag*. (Cubierto en Task 2, `test_histeresis_y_fin_de_pista`).
4. **Contexto inválido, vacío o con una sola pista:** Llamar `establecer_contexto_musica("inexistente")` o consultar `extraer_contexto_musical("pista_sin_tag.mp3")` no debe producir errores ni detener la música actual; y un contexto con 1 sola pista (si ocurriera en el futuro) debe poder repetirla sin bucle infinito al rebarajar. (Cubierto en Task 2, `test_tolerancia_contextos_invalidos_y_un_elemento`).
5. **Salida al menú principal tras combate activo:** Si el jugador sale a `MenuInicio` mientras el cooldown de `"battle"` aún estaba activo (`> 0`), `reproducir_musica_menu()` debe cancelar el estado/cooldown de batalla y cambiar inmediatamente a `"menu"` sin regresar a `"battle"` después. (Cubierto en Task 2, `test_menu_limpia_estado_combate`).

---

## File Structure

| Archivo | Acción | Responsabilidad |
| :--- | :--- | :--- |
| `godot/assets/musica/*.mp3` + `.import` | Crear / Eliminar | 17 pistas MP3 etiquetadas por contexto (`menu`, `exploration`, `building`, `industry`, `battle`) importadas en Godot; eliminación de los 9 duplicados `(loop).mp3`. |
| `godot/scripts/ajustes.gd` | Modificar | Agregar bloque de 7 constantes `MUSICA_*` al final del archivo. |
| `godot/scripts/Sonidos.gd` | Modificar | Implementar el Director de Música Adaptativa: catálogo por contexto, `extraer_contexto_musical()`, doble reproductor + crossfade con `Tween`, *shuffle bag*, máquina de estados con prioridad/histéresis/cooldown y API pública retrocompatible. |
| `godot/scripts/Colonos.gd` | Modificar | Notificar `Sonidos.notificar_evento_combate()` en `aplicar_dano_unidad()` y `aplicar_dano_edificio()`. |
| `godot/scripts/Player.gd` | Modificar | Registrar marca de tiempo de construcción/deconstrucción reciente (`construccion_reciente_activa()`) y notificar `Sonidos.notificar_evento_combate()` en ataques del avatar. |
| `godot/scripts/HUD.gd` | Modificar | Exponer helpers de solo lectura `panel_industrial_o_energia_abierto(tipos_industriales)` y `modo_construccion_cenital_activo()`. |
| `godot/scripts/Main.gd` | Modificar | Evaluar el contexto musical cada `Ajustes.MUSICA_INTERVALO_EVALUACION_S` en `_process()` consultando foco de cámara, `Ciudad`, `Zonificacion`, `Economia.puestos`, `HUD` y `Player`. |
| `godot/scripts/SonidosTest.gd` | Modificar | Ampliar la suite con pruebas de carga de las 17 pistas, clasificación, prioridad, histéresis, shuffle bag, edge cases de Review Focus e integración de detección industrial/combate. |

---

### Task 1: Preparación de Assets OST (`.m4a → .mp3`, limpieza de `(loop).mp3`, `--import`) y Constantes en `ajustes.gd`

**Files:**
- Modify: `godot/assets/musica/` (agregar 16 pistas desde `arte/ost/`, eliminar 9 duplicados `(loop).mp3` + `.import`, importar en Godot)
- Modify: `godot/scripts/ajustes.gd:1001-1014`
- Test: `godot/scripts/SonidosTest.gd`

**Interfaces:**
- Consumes: archivos fuente en `arte/ost/` y `ffmpeg` instalado en PATH.
- Produces:
  - 17 archivos `.mp3` + `.mp3.import` en `godot/assets/musica/` (2 `menu`, 2 `exploration`, 4 `building`, 6 `industry`, 3 `battle`).
  - Constantes estáticas en `godot/scripts/ajustes.gd`: `MUSICA_CROSSFADE_AMBIENTAL_S`, `MUSICA_CROSSFADE_BATALLA_S`, `MUSICA_HISTERESIS_AMBIENTAL_S`, `MUSICA_PERMANENCIA_MINIMA_PISTA_S`, `MUSICA_COOLDOWN_BATALLA_S`, `MUSICA_RADIO_DETECCION_INDUSTRIA`, `MUSICA_INTERVALO_EVALUACION_S`.

- [ ] **Step 1: Escribir prueba fallida en `godot/scripts/SonidosTest.gd` para verificar los 17 archivos OST y las 7 constantes en `ajustes.gd`**

Al inicio de `godot/scripts/SonidosTest.gd`, añadir `const Ajustes = preload("res://scripts/ajustes.gd")`, llamar `test_assets_y_constantes_musica()` desde `ejecutar_pruebas()`, y añadir la función:

```gdscript
func test_assets_y_constantes_musica() -> void:
	assert(is_equal_approx(Ajustes.MUSICA_CROSSFADE_AMBIENTAL_S, 3.0), "MUSICA_CROSSFADE_AMBIENTAL_S debe ser 3.0")
	assert(is_equal_approx(Ajustes.MUSICA_CROSSFADE_BATALLA_S, 0.8), "MUSICA_CROSSFADE_BATALLA_S debe ser 0.8")
	assert(is_equal_approx(Ajustes.MUSICA_HISTERESIS_AMBIENTAL_S, 4.0), "MUSICA_HISTERESIS_AMBIENTAL_S debe ser 4.0")
	assert(is_equal_approx(Ajustes.MUSICA_PERMANENCIA_MINIMA_PISTA_S, 15.0), "MUSICA_PERMANENCIA_MINIMA_PISTA_S debe ser 15.0")
	assert(is_equal_approx(Ajustes.MUSICA_COOLDOWN_BATALLA_S, 15.0), "MUSICA_COOLDOWN_BATALLA_S debe ser 15.0")
	assert(is_equal_approx(Ajustes.MUSICA_RADIO_DETECCION_INDUSTRIA, 12.0), "MUSICA_RADIO_DETECCION_INDUSTRIA debe ser 12.0")
	assert(is_equal_approx(Ajustes.MUSICA_INTERVALO_EVALUACION_S, 1.0), "MUSICA_INTERVALO_EVALUACION_S debe ser 1.0")

	var pistas_esperadas: Array[String] = [
		"Menu & Loading Theme (menu).mp3",
		"The_Architect_s_Decree (menu).mp3",
		"Untamed Horizons (exploration).mp3",
		"Wilderness & Discovery (exploration).mp3",
		"Cozy_colony (building).mp3",
		"Foundations & Frameworks (building).mp3",
		"Frontier Blueprint (building).mp3",
		"Seamless_loop  (building).mp3",
		"Automated Pulse (industry).mp3",
		"Clockwork_logistics (industry).mp3",
		"Clockwork_logistics_2 (industry).mp3",
		"Glitch_drift (industry).mp3",
		"Glitch_drift_2 (industry).mp3",
		"Morning_at_the_Steel_Spire (industry).mp3",
		"Hard_stop (battle).mp3",
		"Hard_stop_2 (battle).mp3",
		"Siege Protocols (battle).mp3",
	]
	for nombre in pistas_esperadas:
		var ruta := "res://assets/musica/" + nombre
		assert(FileAccess.file_exists(ruta), "Debe existir la pista OST: %s" % ruta)
		var stream := Sonidos.cargar_stream_musica(ruta, false)
		assert(stream != null and stream.get_length() > 0.0, "La pista OST debe cargar con duración > 0: %s" % ruta)
	assert(not FileAccess.file_exists("res://assets/musica/Cozy_colony (loop).mp3"), "No deben quedar duplicados (loop).mp3 antiguos.")
	print("OK: 17 pistas OST y 7 constantes en Ajustes verificadas.")
```

- [ ] **Step 2: Ejecutar `SonidosTest.tscn` para confirmar que falla antes de preparar assets y constantes**

Run (PowerShell):
```powershell
$godot = "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
$log = Join-Path $env:TEMP "godot_SonidosTest.log"
Remove-Item $log -ErrorAction SilentlyContinue
$p = Start-Process -FilePath $godot -ArgumentList @("--headless","--path","godot","--log-file",$log,"--fixed-fps","60","--quit-after","600","scenes/SonidosTest.tscn") -Wait -PassThru -WindowStyle Hidden
Get-Content $log
```
Expected: FAIL porque `Ajustes.MUSICA_CROSSFADE_AMBIENTAL_S` no existe todavía y las pistas convertidas aún no están en `godot/assets/musica/`.

- [ ] **Step 3: Convertir los 4 `.m4a` a `.mp3`, copiar los 12 `.mp3` desde `arte/ost/`, eliminar los 9 duplicados `(loop).mp3` e importar en Godot**

Run (PowerShell):
```powershell
$src = "arte\ost"
$dst = "godot\assets\musica"

# 1. Convertir los 4 .m4a a .mp3 con calidad VBR 2
Get-ChildItem -Path $src -Filter "*.m4a" | ForEach-Object {
    $out = Join-Path $dst ($_.BaseName + ".mp3")
    ffmpeg -y -v error -i $_.FullName -c:a libmp3lame -q:a 2 $out
    if ($LASTEXITCODE -ne 0) { throw "Error convirtiendo $($_.Name)" }
}

# 2. Copiar los 12 .mp3 etiquetados
Get-ChildItem -Path $src -Filter "*.mp3" | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination (Join-Path $dst $_.Name) -Force
}

# 3. Eliminar los 9 duplicados antiguos *(loop).mp3 y sus .import
Get-ChildItem -Path $dst -Filter "*(loop).mp3*" | Remove-Item -Force

# 4. Importar en Godot para generar los .mp3.import
$godot = "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
$imp = Start-Process -FilePath $godot -ArgumentList @("--headless","--path","godot","--import","--quit") -Wait -PassThru -WindowStyle Hidden
Write-Host "Import exit: $($imp.ExitCode)"
(Get-ChildItem -Path $dst -Filter "*.mp3").Count
```
Expected: `Import exit: 0` y conteo de `.mp3` igual a `17`.

- [ ] **Step 4: Agregar las 7 constantes `MUSICA_*` al final de `godot/scripts/ajustes.gd`**

Al final de `godot/scripts/ajustes.gd` (después de `ARMAS_AVATAR`), añadir:

```gdscript
# ==============================================================================
# MÚSICA ADAPTATIVA CONTEXTUAL (Sonidos)
# ==============================================================================
static var MUSICA_CROSSFADE_AMBIENTAL_S: float = 3.0
static var MUSICA_CROSSFADE_BATALLA_S: float = 0.8
static var MUSICA_HISTERESIS_AMBIENTAL_S: float = 4.0
static var MUSICA_PERMANENCIA_MINIMA_PISTA_S: float = 15.0
static var MUSICA_COOLDOWN_BATALLA_S: float = 15.0
static var MUSICA_RADIO_DETECCION_INDUSTRIA: float = 12.0
static var MUSICA_INTERVALO_EVALUACION_S: float = 1.0
```

- [ ] **Step 5: Ejecutar `SonidosTest.tscn` para confirmar que Task 1 pasa**

Run (PowerShell):
```powershell
$godot = "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
$log = Join-Path $env:TEMP "godot_SonidosTest.log"
Remove-Item $log -ErrorAction SilentlyContinue
$p = Start-Process -FilePath $godot -ArgumentList @("--headless","--path","godot","--log-file",$log,"--fixed-fps","60","--quit-after","600","scenes/SonidosTest.tscn") -Wait -PassThru -WindowStyle Hidden
Get-Content $log
```
Expected: PASS (`OK: 17 pistas OST y 7 constantes en Ajustes verificadas.` y `Todas las pruebas pasaron correctamente.`).

- [ ] **Step 6: Commit**

```bash
git add godot/assets/musica/ godot/scripts/ajustes.gd godot/scripts/SonidosTest.gd
git commit -m "feat(audio): importar las 17 pistas OST por contexto y añadir constantes de música adaptativa"
```

---

### Task 2: Director de Música Adaptativa en `godot/scripts/Sonidos.gd` (Catálogo, Shuffle Bag, Crossfade, Histéresis y Máquina de Estados)

**Files:**
- Modify: `godot/scripts/Sonidos.gd:1-196, 272-282`
- Test: `godot/scripts/SonidosTest.gd`

**Interfaces:**
- Consumes: `Ajustes.MUSICA_*` (de Task 1) y las 17 pistas en `res://assets/musica/`.
- Produces (API pública en `Sonidos`):
  - `const CONTEXTOS_MUSICA_VALIDOS: Array[String] = ["menu", "exploration", "building", "industry", "battle"]`
  - `const CATALOGO_MUSICA_POR_CONTEXTO: Dictionary` (respaldo estático para exportación PCK)
  - `static func extraer_contexto_musical(nombre_archivo: String) -> String`
  - `func obtener_pistas_contexto(contexto: String) -> Array[String]`
  - `func obtener_siguiente_pista_contexto(contexto: String) -> String`
  - `func establecer_contexto_musica(nuevo_contexto: String, forzar_inmediato: bool = false) -> void`
  - `func evaluar_contexto_musical(estado_juego: Dictionary, delta: float) -> String`
  - `func notificar_evento_combate() -> void`
  - `func obtener_contexto_musica_actual() -> String`
  - `func reiniciar_director_musica() -> void`
  - Retrocompatibles: `reproducir_musica_menu()`, `reproducir_musica_juego()`, `detener_musica()`, `actualizar_volumen_musica(lineal: float)` y `Sonidos._player_musica` siempre apuntando al reproductor activo.

- [ ] **Step 1: Escribir pruebas unitarias fallidas en `godot/scripts/SonidosTest.gd`**

Añadir llamadas en `ejecutar_pruebas()` y las funciones de prueba siguientes en `godot/scripts/SonidosTest.gd`:

```gdscript
func test_clasificacion_y_catalogo_contextos() -> void:
	assert(Sonidos.extraer_contexto_musical("Menu & Loading Theme (menu).mp3") == "menu")
	assert(Sonidos.extraer_contexto_musical("Untamed Horizons (exploration).mp3") == "exploration")
	assert(Sonidos.extraer_contexto_musical("Seamless_loop  (building).mp3") == "building")
	assert(Sonidos.extraer_contexto_musical("Automated Pulse (industry).mp3") == "industry")
	assert(Sonidos.extraer_contexto_musical("Siege Protocols (battle).mp3") == "battle")
	assert(Sonidos.extraer_contexto_musical("archivo_sin_etiqueta.mp3") == "")
	assert(Sonidos.extraer_contexto_musical("tema_raro (desconocido).mp3") == "")

	assert(Sonidos.obtener_pistas_contexto("menu").size() == 2, "menu debe tener 2 pistas")
	assert(Sonidos.obtener_pistas_contexto("exploration").size() == 2, "exploration debe tener 2 pistas")
	assert(Sonidos.obtener_pistas_contexto("building").size() == 4, "building debe tener 4 pistas")
	assert(Sonidos.obtener_pistas_contexto("industry").size() == 6, "industry debe tener 6 pistas")
	assert(Sonidos.obtener_pistas_contexto("battle").size() == 3, "battle debe tener 3 pistas")
	print("OK: Clasificación y catálogo por los 5 contextos verificados.")


func test_shuffle_bag_sin_repeticion_consecutiva() -> void:
	Sonidos.reiniciar_director_musica()
	for ctx in ["menu", "exploration", "building", "industry", "battle"]:
		var previa := ""
		for i in range(10):
			var pista := Sonidos.obtener_siguiente_pista_contexto(ctx)
			assert(pista != "", "Debe entregar una pista válida para %s" % ctx)
			assert(pista != previa, "Shuffle bag no debe repetir consecutivamente en %s (iter %d: %s)" % [ctx, i, pista])
			previa = pista
	print("OK: Shuffle bag sin repetición consecutiva verificado.")


func test_prioridad_maquina_estados_y_cooldown_batalla() -> void:
	Sonidos.reiniciar_director_musica()
	Sonidos.actualizar_volumen_musica(0.8)

	# Sin núcleo ni influencia -> exploration
	var c1 := Sonidos.evaluar_contexto_musical({
		"tiene_nucleo": false,
		"en_influencia": false,
		"modo_construccion_activo": false,
		"construccion_reciente": false,
		"en_industria": false,
		"panel_industria_abierto": false,
		"en_combate": false,
	}, 1.0)
	assert(c1 == "exploration", "Sin núcleo ni influencia debe ser exploration, obtuvo: %s" % c1)

	# Dentro de influencia -> building (tras cumplir permanencia mínima + histéresis)
	Sonidos._tiempo_en_pista_actual_s = Ajustes.MUSICA_PERMANENCIA_MINIMA_PISTA_S
	Sonidos.evaluar_contexto_musical({"tiene_nucleo": true, "en_influencia": true}, 2.0)
	assert(Sonidos.obtener_contexto_musica_actual() == "exploration", "2.0s no debe bastar para vencer histéresis de 4.0s")
	Sonidos.evaluar_contexto_musical({"tiene_nucleo": true, "en_influencia": true}, 2.5)
	assert(Sonidos.obtener_contexto_musica_actual() == "building", "4.5s continuos debe transicionar a building")

	# Industria prevalece sobre building
	Sonidos._tiempo_en_pista_actual_s = Ajustes.MUSICA_PERMANENCIA_MINIMA_PISTA_S
	Sonidos.evaluar_contexto_musical({"tiene_nucleo": true, "en_influencia": true, "en_industria": true}, 4.5)
	assert(Sonidos.obtener_contexto_musica_actual() == "industry", "industry debe prevalecer sobre building")

	# Evento de combate -> pasa INMEDIATAMENTE a battle ignorando histéresis/permanencia
	Sonidos._tiempo_en_pista_actual_s = 0.0
	Sonidos.notificar_evento_combate()
	assert(Sonidos.obtener_contexto_musica_actual() == "battle", "notificar_evento_combate debe activar battle inmediatamente")

	# Mientras dure el cooldown (15 s), permanece en battle
	Sonidos.evaluar_contexto_musical({"tiene_nucleo": true, "en_influencia": true, "en_industria": false}, 10.0)
	assert(Sonidos.obtener_contexto_musica_actual() == "battle", "Debe mantenerse en battle durante el cooldown")

	# Al expirar cooldown, regresa al estado ambiental correspondiente
	Sonidos.evaluar_contexto_musical({"tiene_nucleo": true, "en_influencia": true, "en_industria": false}, 6.0)
	assert(Sonidos.obtener_contexto_musica_actual() == "building", "Al expirar cooldown de batalla debe regresar a building")
	Sonidos.detener_musica()
	print("OK: Prioridad de máquina de estados y cooldown de batalla verificados.")


func test_histeresis_y_fin_de_pista() -> void:
	Sonidos.reiniciar_director_musica()
	Sonidos.actualizar_volumen_musica(0.8)
	Sonidos.establecer_contexto_musica("building", true)
	Sonidos._tiempo_en_pista_actual_s = Ajustes.MUSICA_PERMANENCIA_MINIMA_PISTA_S

	# 2.0 s en industry y regresa a building -> nunca cambia
	Sonidos.evaluar_contexto_musical({"tiene_nucleo": true, "en_influencia": true, "en_industria": true}, 2.0)
	assert(Sonidos.obtener_contexto_musica_actual() == "building", "No debe cambiar tras solo 2.0 s")
	Sonidos.evaluar_contexto_musical({"tiene_nucleo": true, "en_influencia": true, "en_industria": false}, 1.0)
	assert(Sonidos.obtener_contexto_musica_actual() == "building", "Al volver a building el candidato industry se reinicia")

	# 4.5 s continuos con permanencia cumplida -> cambia a industry
	Sonidos.evaluar_contexto_musical({"tiene_nucleo": true, "en_influencia": true, "en_industria": true}, 4.5)
	assert(Sonidos.obtener_contexto_musica_actual() == "industry", "4.5 s continuos con permanencia cumplida debe pasar a industry")

	# Si la pista actual ya terminó (no está sonando), no exige 15s de permanencia
	Sonidos._tiempo_en_pista_actual_s = 1.0
	Sonidos._player_musica.stop()
	Sonidos.evaluar_contexto_musical({"tiene_nucleo": true, "en_influencia": true, "en_industria": false}, 4.5)
	assert(Sonidos.obtener_contexto_musica_actual() == "building", "Si la pista ya terminó, la histéresis de 4.5s permite cambiar sin esperar 15s")
	Sonidos.detener_musica()
	print("OK: Histéresis anti-rebote y fin de pista verificados.")


func test_volumen_y_silencio_durante_crossfade() -> void:
	Sonidos.reiniciar_director_musica()
	Sonidos.actualizar_volumen_musica(0.8)
	Sonidos.establecer_contexto_musica("building", true)
	Sonidos.establecer_contexto_musica("industry", false)
	# Silenciar en medio del crossfade
	Sonidos.actualizar_volumen_musica(0.0)
	assert(not Sonidos.musica_habilitada, "La música debe quedar deshabilitada")
	assert(Sonidos._player_musica.volume_db <= -79.0, "El reproductor activo debe silenciarse de inmediato")
	assert(Sonidos._player_musica_secundario.volume_db <= -79.0, "El reproductor saliente debe silenciarse de inmediato")
	Sonidos.actualizar_volumen_musica(0.75)
	Sonidos.detener_musica()
	print("OK: Silencio y volumen durante crossfade verificados.")


func test_combate_continuo_no_reinicia_pista() -> void:
	Sonidos.reiniciar_director_musica()
	Sonidos.actualizar_volumen_musica(0.8)
	Sonidos.notificar_evento_combate()
	var stream_inicial := Sonidos._player_musica.stream
	Sonidos.evaluar_contexto_musical({"tiene_nucleo": true, "en_influencia": true}, 5.0)
	Sonidos.notificar_evento_combate()
	assert(Sonidos._player_musica.stream == stream_inicial, "Re-notificar combate en battle no debe reiniciar ni cambiar la pista actual")
	assert(is_equal_approx(Sonidos._cooldown_batalla_restante_s, Ajustes.MUSICA_COOLDOWN_BATALLA_S), "El cooldown debe reiniciarse a 15s")
	Sonidos.detener_musica()
	print("OK: Re-notificación de combate mantiene pista actual y reinicia cooldown.")


func test_tolerancia_contextos_invalidos_y_un_elemento() -> void:
	Sonidos.reiniciar_director_musica()
	Sonidos.actualizar_volumen_musica(0.8)
	Sonidos.establecer_contexto_musica("building", true)
	Sonidos.establecer_contexto_musica("contexto_inexistente", true)
	assert(Sonidos.obtener_contexto_musica_actual() == "building", "Contexto inválido debe ignorarse sin alterar el estado actual")

	# Simular contexto de 1 sola pista en el shuffle bag
	var respaldo: Array[String] = Sonidos._pistas_por_contexto["menu"].duplicate()
	Sonidos._pistas_por_contexto["menu"] = [respaldo[0]]
	Sonidos._colas_contexto["menu"] = []
	var p1 := Sonidos.obtener_siguiente_pista_contexto("menu")
	var p2 := Sonidos.obtener_siguiente_pista_contexto("menu")
	assert(p1 == respaldo[0] and p2 == respaldo[0], "Contexto de 1 pista debe devolver esa pista sin bloquearse")
	Sonidos._pistas_por_contexto["menu"] = respaldo
	Sonidos._colas_contexto["menu"] = []
	Sonidos.detener_musica()
	print("OK: Tolerancia a contextos inválidos y pool de 1 pista verificada.")


func test_menu_limpia_estado_combate() -> void:
	Sonidos.reiniciar_director_musica()
	Sonidos.actualizar_volumen_musica(0.8)
	Sonidos.notificar_evento_combate()
	assert(Sonidos.obtener_contexto_musica_actual() == "battle")
	Sonidos.reproducir_musica_menu()
	assert(Sonidos.obtener_contexto_musica_actual() == "menu", "reproducir_musica_menu debe pasar inmediatamente a menu")
	assert(Sonidos._cooldown_batalla_restante_s <= 0.0, "Volver al menú debe limpiar cooldown de batalla")
	Sonidos.detener_musica()
	print("OK: Transición a menú limpia estado de combate.")
```

- [ ] **Step 2: Ejecutar `SonidosTest.tscn` para confirmar que falla antes de implementar `Sonidos.gd`**

Run (PowerShell):
```powershell
$godot = "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
$log = Join-Path $env:TEMP "godot_SonidosTest.log"
Remove-Item $log -ErrorAction SilentlyContinue
$p = Start-Process -FilePath $godot -ArgumentList @("--headless","--path","godot","--log-file",$log,"--fixed-fps","60","--quit-after","600","scenes/SonidosTest.tscn") -Wait -PassThru -WindowStyle Hidden
Get-Content $log
```
Expected: FAIL porque `extraer_contexto_musical`, `establecer_contexto_musica`, etc. aún no existen en `Sonidos.gd`.

- [ ] **Step 3: Implementar el Director de Música Adaptativa en `godot/scripts/Sonidos.gd`**

En `godot/scripts/Sonidos.gd`:
1. Añadir `const Ajustes = preload("res://scripts/ajustes.gd")` y constantes del catálogo:
```gdscript
const RUTA_MUSICA := "res://assets/musica/"
const CONTEXTOS_MUSICA_VALIDOS: Array[String] = ["menu", "exploration", "building", "industry", "battle"]
const CATALOGO_MUSICA_POR_CONTEXTO: Dictionary = {
	"menu": [
		"res://assets/musica/Menu & Loading Theme (menu).mp3",
		"res://assets/musica/The_Architect_s_Decree (menu).mp3",
	],
	"exploration": [
		"res://assets/musica/Untamed Horizons (exploration).mp3",
		"res://assets/musica/Wilderness & Discovery (exploration).mp3",
	],
	"building": [
		"res://assets/musica/Cozy_colony (building).mp3",
		"res://assets/musica/Foundations & Frameworks (building).mp3",
		"res://assets/musica/Frontier Blueprint (building).mp3",
		"res://assets/musica/Seamless_loop  (building).mp3",
	],
	"industry": [
		"res://assets/musica/Automated Pulse (industry).mp3",
		"res://assets/musica/Clockwork_logistics (industry).mp3",
		"res://assets/musica/Clockwork_logistics_2 (industry).mp3",
		"res://assets/musica/Glitch_drift (industry).mp3",
		"res://assets/musica/Glitch_drift_2 (industry).mp3",
		"res://assets/musica/Morning_at_the_Steel_Spire (industry).mp3",
	],
	"battle": [
		"res://assets/musica/Hard_stop (battle).mp3",
		"res://assets/musica/Hard_stop_2 (battle).mp3",
		"res://assets/musica/Siege Protocols (battle).mp3",
	],
}
```
2. Reemplazar variables de playlist lineal por estado del director:
```gdscript
var musica_habilitada: bool = true
var volumen_musica_db: float = 0.0
var _player_musica: AudioStreamPlayer = null
var _player_musica_secundario: AudioStreamPlayer = null
var _tween_musica: Tween = null
var _en_musica_juego: bool = false
var _contexto_musica_actual: String = ""
var _contexto_candidato: String = ""
var _tiempo_candidato_s: float = 0.0
var _tiempo_en_pista_actual_s: float = 0.0
var _cooldown_batalla_restante_s: float = 0.0
var _pistas_por_contexto: Dictionary = {}
var _colas_contexto: Dictionary = {}
var _ultima_pista_contexto: Dictionary = {}
```
3. En `_ready()`: llamar `_inicializar_catalogo_musica()` tras `_inicializar_pools()`.
4. En `_inicializar_pools()`: crear `_player_musica` y `_player_musica_secundario` (ambos `process_mode = Node.PROCESS_MODE_ALWAYS`, `bus = "Master"`), conectando `finished` de ambos mediante `_on_player_musica_terminado.bind(player)` (solo avanza cuando el que terminó es `_player_musica`).
5. Implementar los métodos del director:
```gdscript
static func extraer_contexto_musical(nombre_archivo: String) -> String:
	var base := nombre_archivo.get_file().get_basename().strip_edges()
	var idx_abre := base.rfind("(")
	var idx_cierra := base.rfind(")")
	if idx_abre == -1 or idx_cierra <= idx_abre:
		return ""
	var etiqueta := base.substr(idx_abre + 1, idx_cierra - idx_abre - 1).strip_edges().to_lower()
	return etiqueta if CONTEXTOS_MUSICA_VALIDOS.has(etiqueta) else ""


func _inicializar_catalogo_musica() -> void:
	_pistas_por_contexto.clear()
	for ctx in CONTEXTOS_MUSICA_VALIDOS:
		_pistas_por_contexto[ctx] = [] as Array[String]
		_colas_contexto[ctx] = [] as Array[String]
		_ultima_pista_contexto[ctx] = ""

	var dir := DirAccess.open(RUTA_MUSICA)
	if dir != null:
		dir.list_dir_begin()
		var nombre := dir.get_next()
		while nombre != "":
			if not dir.current_is_dir():
				var limpio := nombre.trim_suffix(".import")
				if limpio.to_lower().ends_with(".mp3"):
					var ctx := extraer_contexto_musical(limpio)
					if ctx != "":
						var ruta_completa := RUTA_MUSICA + limpio
						var lista: Array[String] = _pistas_por_contexto[ctx]
						if not lista.has(ruta_completa):
							lista.append(ruta_completa)
			nombre = dir.get_next()
		dir.list_dir_end()

	# Respaldo estático para builds exportadas / asegurar catálogo completo
	for ctx in CONTEXTOS_MUSICA_VALIDOS:
		var lista: Array[String] = _pistas_por_contexto[ctx]
		if lista.is_empty() and CATALOGO_MUSICA_POR_CONTEXTO.has(ctx):
			for ruta in CATALOGO_MUSICA_POR_CONTEXTO[ctx]:
				lista.append(str(ruta))
		lista.sort()


func obtener_pistas_contexto(contexto: String) -> Array[String]:
	if not _pistas_por_contexto.has(contexto):
		return []
	return (_pistas_por_contexto[contexto] as Array[String]).duplicate()


func obtener_siguiente_pista_contexto(contexto: String) -> String:
	if not _pistas_por_contexto.has(contexto):
		return ""
	var disponibles: Array[String] = _pistas_por_contexto[contexto]
	if disponibles.is_empty():
		return ""
	if disponibles.size() == 1:
		_ultima_pista_contexto[contexto] = disponibles[0]
		return disponibles[0]

	var cola: Array[String] = _colas_contexto[contexto]
	if cola.is_empty():
		cola = disponibles.duplicate()
		# Fisher-Yates con _rng
		for i in range(cola.size() - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var tmp := cola[i]
			cola[i] = cola[j]
			cola[j] = tmp
		var ultima: String = str(_ultima_pista_contexto.get(contexto, ""))
		if ultima != "" and cola[0] == ultima:
			var ult_idx := cola.size() - 1
			var tmp2 := cola[0]
			cola[0] = cola[ult_idx]
			cola[ult_idx] = tmp2
		_colas_contexto[contexto] = cola

	var elegida: String = cola.pop_front()
	_ultima_pista_contexto[contexto] = elegida
	return elegida


func _cancelar_tween_musica() -> void:
	if _tween_musica != null and is_instance_valid(_tween_musica):
		_tween_musica.kill()
	_tween_musica = null


func actualizar_volumen_musica(lineal: float) -> void:
	musica_habilitada = lineal > 0.001
	if musica_habilitada:
		volumen_musica_db = linear_to_db(clampf(lineal, 0.0001, 1.0))
	else:
		volumen_musica_db = -80.0
		_cancelar_tween_musica()
	if _player_musica != null:
		_player_musica.volume_db = volumen_musica_db
	if _player_musica_secundario != null:
		if not musica_habilitada:
			_player_musica_secundario.volume_db = -80.0
			if _player_musica_secundario.playing:
				_player_musica_secundario.stop()
		else:
			_player_musica_secundario.volume_db = minf(_player_musica_secundario.volume_db, volumen_musica_db)


func _transicionar_a_pista(ruta: String, duracion_fade: float) -> void:
	if not musica_habilitada or _player_musica == null or ruta == "":
		return
	var stream := cargar_stream_musica(ruta, false)
	if stream == null:
		return

	_cancelar_tween_musica()
	_tiempo_en_pista_actual_s = 0.0

	var habia_audio := _player_musica.playing and duracion_fade > 0.0 and _player_musica_secundario != null
	if not habia_audio:
		if _player_musica_secundario != null and _player_musica_secundario.playing:
			_player_musica_secundario.stop()
		_player_musica.stream = stream
		_player_musica.volume_db = volumen_musica_db
		_player_musica.play()
		return

	# Intercambiar canales para que _player_musica siga siendo siempre el canal activo entrante
	var saliente := _player_musica
	var entrante := _player_musica_secundario
	_player_musica = entrante
	_player_musica_secundario = saliente

	entrante.stop()
	entrante.stream = stream
	entrante.volume_db = minf(-40.0, volumen_musica_db)
	entrante.play()

	_tween_musica = create_tween()
	_tween_musica.set_parallel(true)
	_tween_musica.tween_property(saliente, "volume_db", -60.0, duracion_fade)
	_tween_musica.tween_property(entrante, "volume_db", volumen_musica_db, duracion_fade)
	_tween_musica.chain().tween_callback(func() -> void:
		if is_instance_valid(saliente) and saliente == _player_musica_secundario:
			saliente.stop()
	)


func establecer_contexto_musica(nuevo_contexto: String, forzar_inmediato: bool = false) -> void:
	if not CONTEXTOS_MUSICA_VALIDOS.has(nuevo_contexto):
		return
	if nuevo_contexto == "menu":
		_en_musica_juego = false
		_cooldown_batalla_restante_s = 0.0
	else:
		_en_musica_juego = true

	if _contexto_musica_actual == nuevo_contexto and _player_musica != null and _player_musica.playing:
		return

	var previo := _contexto_musica_actual
	_contexto_musica_actual = nuevo_contexto
	_contexto_candidato = ""
	_tiempo_candidato_s = 0.0

	var pista := obtener_siguiente_pista_contexto(nuevo_contexto)
	if pista == "":
		return

	var fade := 0.0
	if not forzar_inmediato and previo != "" and _player_musica != null and _player_musica.playing:
		fade = Ajustes.MUSICA_CROSSFADE_BATALLA_S if nuevo_contexto == "battle" else Ajustes.MUSICA_CROSSFADE_AMBIENTAL_S
	_transicionar_a_pista(pista, fade)


func notificar_evento_combate() -> void:
	_cooldown_batalla_restante_s = Ajustes.MUSICA_COOLDOWN_BATALLA_S
	if _contexto_musica_actual != "battle":
		establecer_contexto_musica("battle", false)


func obtener_contexto_musica_actual() -> String:
	return _contexto_musica_actual


func evaluar_contexto_musical(estado_juego: Dictionary, delta: float) -> String:
	var dt := maxf(0.0, delta)
	if _player_musica != null and _player_musica.playing:
		_tiempo_en_pista_actual_s += dt
	if _cooldown_batalla_restante_s > 0.0:
		_cooldown_batalla_restante_s = maxf(0.0, _cooldown_batalla_restante_s - dt)

	if bool(estado_juego.get("en_combate", false)):
		_cooldown_batalla_restante_s = Ajustes.MUSICA_COOLDOWN_BATALLA_S

	var deseado := _determinar_contexto_deseado(estado_juego)
	if _contexto_musica_actual == "" or _contexto_musica_actual == "menu":
		establecer_contexto_musica(deseado, _contexto_musica_actual == "")
		return _contexto_musica_actual

	if deseado == "battle":
		if _contexto_musica_actual != "battle":
			establecer_contexto_musica("battle", false)
		return _contexto_musica_actual

	if _contexto_musica_actual == "battle":
		# El cooldown ya expiró porque deseado != "battle": transicionar al estado ambiental
		establecer_contexto_musica(deseado, false)
		return _contexto_musica_actual

	# Ambos estados son ambientales (exploration / building / industry): aplicar histéresis + permanencia mínima
	if deseado == _contexto_musica_actual:
		_contexto_candidato = ""
		_tiempo_candidato_s = 0.0
		return _contexto_musica_actual

	if deseado == _contexto_candidato:
		_tiempo_candidato_s += dt
	else:
		_contexto_candidato = deseado
		_tiempo_candidato_s = dt

	var pista_terminada := (_player_musica == null or not _player_musica.playing)
	var cumple_histeresis := _tiempo_candidato_s >= Ajustes.MUSICA_HISTERESIS_AMBIENTAL_S
	var cumple_permanencia := pista_terminada or _tiempo_en_pista_actual_s >= Ajustes.MUSICA_PERMANENCIA_MINIMA_PISTA_S
	if cumple_histeresis and cumple_permanencia:
		establecer_contexto_musica(deseado, false)

	return _contexto_musica_actual


func _determinar_contexto_deseado(estado_juego: Dictionary) -> String:
	if _cooldown_batalla_restante_s > 0.0 or bool(estado_juego.get("en_combate", false)):
		return "battle"
	if bool(estado_juego.get("en_industria", false)) or bool(estado_juego.get("panel_industria_abierto", false)):
		return "industry"
	var modo_construccion := bool(estado_juego.get("modo_construccion_activo", false))
	var construccion_reciente := bool(estado_juego.get("construccion_reciente", false))
	var tiene_nucleo := bool(estado_juego.get("tiene_nucleo", false))
	var en_influencia := bool(estado_juego.get("en_influencia", false))
	if modo_construccion or construccion_reciente or (tiene_nucleo and en_influencia):
		return "building"
	return "exploration"


func reiniciar_director_musica() -> void:
	detener_musica()
	_contexto_musica_actual = ""
	_contexto_candidato = ""
	_tiempo_candidato_s = 0.0
	_tiempo_en_pista_actual_s = 0.0
	_cooldown_batalla_restante_s = 0.0
	for ctx in CONTEXTOS_MUSICA_VALIDOS:
		_colas_contexto[ctx] = [] as Array[String]
		_ultima_pista_contexto[ctx] = ""


func reproducir_musica_menu() -> void:
	establecer_contexto_musica("menu", false)


func reproducir_musica_juego() -> void:
	var ctx_inicial := "exploration"
	if Ciudad != null and "id_nucleo" in Ciudad and Ciudad.id_nucleo != -1:
		ctx_inicial = "building"
	establecer_contexto_musica(ctx_inicial, false)


func detener_musica() -> void:
	_en_musica_juego = false
	_cancelar_tween_musica()
	if _player_musica != null and _player_musica.playing:
		_player_musica.stop()
	if _player_musica_secundario != null and _player_musica_secundario.playing:
		_player_musica_secundario.stop()


func _on_player_musica_terminado(player: AudioStreamPlayer) -> void:
	if player != _player_musica or not musica_habilitada:
		return
	if _contexto_musica_actual != "":
		var siguiente := obtener_siguiente_pista_contexto(_contexto_musica_actual)
		if siguiente != "":
			_transicionar_a_pista(siguiente, 0.0)
```
Y en `detener_todo()`, reemplazar el `if _player_musica != null` por `detener_musica()`.

- [ ] **Step 4: Ejecutar `SonidosTest.tscn` y `ConfiguracionTest.tscn` para confirmar que pasan**

Run (PowerShell):
```powershell
$godot = "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
foreach ($t in @("SonidosTest.tscn", "ConfiguracionTest.tscn")) {
    $log = Join-Path $env:TEMP ("godot_" + $t + ".log")
    Remove-Item $log -ErrorAction SilentlyContinue
    $p = Start-Process -FilePath $godot -ArgumentList @("--headless","--path","godot","--log-file",$log,"--fixed-fps","60","--quit-after","600","scenes/$t") -Wait -PassThru -WindowStyle Hidden
    Write-Host "=== $t (exit $($p.ExitCode)) ==="
    Get-Content $log
}
```
Expected: Ambas escenas salen con `exit 0` y 0 errores.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/Sonidos.gd godot/scripts/SonidosTest.gd
git commit -m "feat(audio): implementar director de música adaptativa con crossfade, histéresis y shuffle bag"
```

---

### Task 3: Integración en `Main.gd`, `Colonos.gd`, `Player.gd` y `HUD.gd` + Verificación Global

**Files:**
- Modify: `godot/scripts/Colonos.gd:2459-2488`
- Modify: `godot/scripts/Player.gd:122-127, 1170-1185, 1410-1422, 1480-1525`
- Modify: `godot/scripts/HUD.gd:650-668`
- Modify: `godot/scripts/Main.gd:20-35, 60-68`
- Test: `godot/scripts/SonidosTest.gd`

**Interfaces:**
- Consumes:
  - `Sonidos.evaluar_contexto_musical(estado_juego: Dictionary, delta: float) -> String`
  - `Sonidos.notificar_evento_combate() -> void`
  - `Ajustes.MUSICA_RADIO_DETECCION_INDUSTRIA`, `Ajustes.MUSICA_INTERVALO_EVALUACION_S`
  - `Zonificacion.zonas`, `Zonificacion.dentro_de_influencia(celda: Vector2i)`
  - `Economia.puestos`, `Ciudad.id_nucleo`, `CamaraCenital.foco`
- Produces:
  - `Player.construccion_reciente_activa(ventana_s: float = 10.0) -> bool`
  - `HUD.panel_industrial_o_energia_abierto(tipos_industriales: Array) -> bool`
  - `HUD.modo_construccion_cenital_activo() -> bool`
  - `Main.const TIPOS_PUESTOS_INDUSTRIALES: Array[String]` y `Main.construir_estado_musical() -> Dictionary`

- [ ] **Step 1: Escribir pruebas de integración fallidas en `godot/scripts/SonidosTest.gd`**

Añadir en `godot/scripts/SonidosTest.gd` la prueba `test_integracion_combate_y_construccion()` (y llamarla desde `ejecutar_pruebas()`):

```gdscript
func test_integracion_combate_y_construccion() -> void:
	Sonidos.reiniciar_director_musica()
	Sonidos.actualizar_volumen_musica(0.8)
	Sonidos.establecer_contexto_musica("building", true)

	# Al aplicar daño a una unidad en Colonos, debe notificar combate inmediatamente
	var id_u: int = Colonos.agregar_colono("obrero", Vector3i(2, 1, 2), -1)
	Colonos.aplicar_dano_unidad(id_u, 10.0)
	assert(Sonidos.obtener_contexto_musica_actual() == "battle", "Colonos.aplicar_dano_unidad debe disparar contexto battle")

	# Limpiar colono de prueba
	var cel: Vector3i = Colonos.colonos[id_u]["celda"]
	Colonos.ocupadas.erase(cel)
	Colonos.colonos.erase(id_u)

	# Verificar helper de Player para actividad de construcción reciente
	var player_script = preload("res://scripts/Player.gd")
	var p = player_script.new()
	assert(not p.construccion_reciente_activa(10.0), "Sin actividad reciente debe devolver false")
	p.registrar_actividad_construccion()
	assert(p.construccion_reciente_activa(10.0), "Tras registrar actividad de construcción debe devolver true")
	p.free()

	Sonidos.detener_musica()
	print("OK: Integración de combate (Colonos) y construcción reciente (Player) verificada.")
```

- [ ] **Step 2: Ejecutar `SonidosTest.tscn` para confirmar que falla antes de cablear `Colonos.gd` y `Player.gd`**

Run (PowerShell):
```powershell
$godot = "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
$log = Join-Path $env:TEMP "godot_SonidosTest.log"
Remove-Item $log -ErrorAction SilentlyContinue
$p = Start-Process -FilePath $godot -ArgumentList @("--headless","--path","godot","--log-file",$log,"--fixed-fps","60","--quit-after","600","scenes/SonidosTest.tscn") -Wait -PassThru -WindowStyle Hidden
Get-Content $log
```
Expected: FAIL porque `Colonos.aplicar_dano_unidad` aún no llama a `Sonidos.notificar_evento_combate()` y `Player.construccion_reciente_activa` no existe.

- [ ] **Step 3: Cablear eventos de combate en `godot/scripts/Colonos.gd` y construcción/combate en `godot/scripts/Player.gd`**

1. En `godot/scripts/Colonos.gd`:
   - Dentro de `aplicar_dano_unidad(id: int, dano: float)` (después de actualizar `c["salud"] = nueva_salud`):
     ```gdscript
     if Sonidos != null and Sonidos.has_method("notificar_evento_combate"):
         Sonidos.notificar_evento_combate()
     ```
   - Dentro de `aplicar_dano_edificio(id_ed: int, dano: float, celda: Vector3i = INVALIDA)` (después de `edificio_danado.emit(...)`):
     ```gdscript
     if Sonidos != null and Sonidos.has_method("notificar_evento_combate"):
         Sonidos.notificar_evento_combate()
     ```

2. En `godot/scripts/Player.gd`:
   - Añadir campo junto a `modo_primera_persona`:
     ```gdscript
     var _ultimo_ms_construccion: int = -100000
     ```
   - Añadir helpers:
     ```gdscript
     func registrar_actividad_construccion() -> void:
         _ultimo_ms_construccion = Time.get_ticks_msec()

     func construccion_reciente_activa(ventana_s: float = 10.0) -> bool:
         if _ultimo_ms_construccion < 0:
             return false
         return float(Time.get_ticks_msec() - _ultimo_ms_construccion) / 1000.0 <= ventana_s
     ```
   - Llamar `registrar_actividad_construccion()` cuando `_procesar_deconstruccion()` completa un paso válido (justo después de `FinalizacionObras.al_deconstruir(mundo, resultado)`), cuando `_colocar()` surte un paso de obra o coloca un bloque con éxito (`if colocado: registrar_actividad_construccion()`).
   - En `ejecutar_ataque_en_objetivo()` cuando retorna `true`, invocar también `if Sonidos != null and Sonidos.has_method("notificar_evento_combate"): Sonidos.notificar_evento_combate()`.

- [ ] **Step 4: Agregar helpers de consulta en `godot/scripts/HUD.gd` y el evaluador periódico en `godot/scripts/Main.gd`**

1. En `godot/scripts/HUD.gd`:
   ```gdscript
   func modo_construccion_cenital_activo() -> bool:
       if _barra_modos == null or not _barra_modos.visible:
           return false
       return _barra_modos._modo != ""

   func panel_industrial_o_energia_abierto(tipos_industriales: Array) -> bool:
       if _ventana_energia != null and _ventana_energia.visible:
           return true
       if _panel_puesto != null and _panel_puesto.visible and Economia != null:
           var p: Dictionary = Economia.puestos.get(_panel_puesto.esquina, {})
           if tipos_industriales.has(str(p.get("tipo", ""))):
               return true
       return false
   ```

2. En `godot/scripts/Main.gd`:
   - Agregar constante con los 14 tipos industriales de la spec y acumulador:
     ```gdscript
     const TIPOS_PUESTOS_INDUSTRIALES: Array[String] = [
         "mina", "pozo_agua", "extractor_crudo", "aserradero", "carbonera",
         "fabrica_bloques", "siderurgica", "refineria_cobre", "refineria_tierras_raras",
         "refineria_petrolera", "productor_combustible", "planta_concreto",
         "fabrica_componentes", "central_termoelectrica",
     ]
     var _acumulador_eval_musica: float = 0.0
     ```
   - Agregar `_process(delta: float)` y `construir_estado_musical() -> Dictionary`:
     ```gdscript
     func _process(delta: float) -> void:
         if get_tree().paused:
             return
         _acumulador_eval_musica += delta
         if _acumulador_eval_musica < Ajustes.MUSICA_INTERVALO_EVALUACION_S:
             return
         var dt := _acumulador_eval_musica
         _acumulador_eval_musica = 0.0
         if Sonidos != null and Sonidos.has_method("evaluar_contexto_musical"):
             Sonidos.evaluar_contexto_musical(construir_estado_musical(), dt)


     func construir_estado_musical() -> Dictionary:
         var punto_foco: Vector3 = camara_cenital.foco if cenital_activa else jugador.global_position
         var pos_2d := Vector2(punto_foco.x, punto_foco.z)
         var celda_foco := Vector2i(int(floor(punto_foco.x)), int(floor(punto_foco.z)))
         var radio := Ajustes.MUSICA_RADIO_DETECCION_INDUSTRIA
         var radio_sq := radio * radio

         var en_industria := false
         if Zonificacion != null:
             if str(Zonificacion.zonas.get(celda_foco, "")) == "fabricacion_militar":
                 en_industria = true
             else:
                 for c_zona in Zonificacion.zonas:
                     if Zonificacion.zonas[c_zona] == "fabricacion_militar":
                         var dz := Vector2(c_zona.x, c_zona.y) - pos_2d
                         if dz.length_squared() <= radio_sq:
                             en_industria = true
                             break

         if not en_industria and Economia != null:
             for esquina in Economia.puestos:
                 var p: Dictionary = Economia.puestos[esquina]
                 if TIPOS_PUESTOS_INDUSTRIALES.has(str(p.get("tipo", ""))):
                     var centro := Vector2(esquina.x + float(p.get("ancho", 1)) * 0.5, esquina.y + float(p.get("alto", 1)) * 0.5)
                     if pos_2d.distance_squared_to(centro) <= radio_sq:
                         en_industria = true
                         break

         var tiene_nucleo := Ciudad != null and Ciudad.id_nucleo != -1
         var en_influencia := tiene_nucleo and Zonificacion != null and Zonificacion.dentro_de_influencia(celda_foco)
         var modo_constr := hud != null and hud.has_method("modo_construccion_cenital_activo") and hud.modo_construccion_cenital_activo()
         var panel_ind := hud != null and hud.has_method("panel_industrial_o_energia_abierto") and hud.panel_industrial_o_energia_abierto(TIPOS_PUESTOS_INDUSTRIALES)
         var constr_reciente := (not cenital_activa) and jugador != null and jugador.construccion_reciente_activa(10.0)

         return {
             "tiene_nucleo": tiene_nucleo,
             "en_influencia": en_influencia,
             "modo_construccion_activo": modo_constr,
             "construccion_reciente": constr_reciente,
             "en_industria": en_industria,
             "panel_industria_abierto": panel_ind,
             "en_combate": false,
         }
     ```
   - Nota: en `Main._ready()`, mantener `Sonidos.reproducir_musica_juego()` y realizar una primera evaluación inmediata tras cargar partida si procede (`Sonidos.evaluar_contexto_musical(construir_estado_musical(), 0.0)`).

- [ ] **Step 5: Ejecutar pruebas locales y la suite completa de 37 escenas**

Run (PowerShell):
```powershell
pwsh -File tools/run-godot-tests.ps1
```
Expected: `Las 37 escenas de prueba pasaron sin errores.` (exit code `0`).

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/Colonos.gd godot/scripts/Player.gd godot/scripts/HUD.gd godot/scripts/Main.gd godot/scripts/SonidosTest.gd
git commit -m "feat(audio): integrar director de música adaptativa con Main, Colonos, Player y HUD"
```

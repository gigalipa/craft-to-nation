# Lote inicial de personajes 3D Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar cuerpos base M/F, obreros M/F, cuatro props y una biblioteca de ocho animaciones, integrados con selección por oficio, canasta dinámica y minería aleatoria.

**Architecture:** La geometría se produce mediante turnarounds aprobados, Hunyuan3D/UniRig en Modal y postproceso determinista en Blender. Godot conserva la arquitectura modular actual: Capa 1 por rango, props rígidos por `BoneAttachment3D` y una biblioteca compartida; `CatalogoPersonajes` resuelve pools y equipo, mientras `PersonajeModular` reproduce y encadena clips.

**Tech Stack:** Godot 4/GDScript, Blender 5.3 headless/Python `bpy`, Mixamo FBX/GLB, Modal `crafttonation`, imagegen, glTF 2.0.

**Spec:** `docs/superpowers/specs/2026-11-25-lote-inicial-personajes-3d-design.md`

## Global Constraints

- Trabajar sobre `main`, preservando y excluyendo de todos los commits los cambios ajenos en `docs/llms-full.txt` y `website/index.html`.
- La T-Pose estricta reemplaza el A-Pose predeterminado para este proyecto.
- Mostrar y obtener aprobación explícita de los cuatro turnarounds humanos antes de ejecutar Modal; repetir la compuerta con los cuatro props.
- No ejecutar Hunyuan3D ni UniRig localmente en la RTX 3050 de 4 GB; usar `modal run -e crafttonation`.
- Usar `C:\Program Files\Blender Foundation\Blender 5.3\blender.exe` en modo headless.
- Humanoides: `3.000–6.000` triángulos, objetivo máximo `5.500`, textura `1024`, altura `1,80 m`, pies en `Z=0`, `lipsync` 18 y slots `Head`, `Chest`, `RightHand`, `LeftHand`.
- Props: `300–1.500` triángulos, objetivo `1.000`, textura máxima `512`, sin rig.
- Mantener intermedios y previews en `scratch/3d_jobs/`; no versionar `scratch/`.
- Nombres canónicos exactos: `Idle`, `Walking`, `Hauler_Box_Idle`, `Hauler_Carry`, `Fishing_Cast`, `Mining_Dig`, `Heavy_Swing`, `Work_Table`.
- Aplicar ponytail: preferir la modificación mínima completa, reutilizar helpers existentes y registrar como `shortcut:` cualquier deuda aceptada conscientemente.
- Aplicar TDD a cambios de Python/GDScript y hacer un commit focalizado al final de cada tarea aceptada.

## Review Focus

- Un GLB con varias acciones debe seleccionar por nombre exacto y fallar claramente si la acción no existe; lo cubre la Tarea 3.
- Si falta un clip canónico, el personaje debe caer en `Idle` sin detener actualizaciones; lo cubre la Tarea 7.
- La canasta debe cambiar de manos a espalda al comenzar movimiento/carga y volver a manos al esperar vacío; lo cubre la Tarea 6.
- La minería debe permitir repetir el mismo clip y no imponer alternancia; lo cubre la Tarea 7.
- `desempleado` debe usar la base sin chaleco y `obrero` el atuendo con chaleco, mientras otros rangos conservan fallback base; lo cubren las Tareas 2 y 8.

---

### Task 1: Configuración T-Pose y turnarounds humanos

**Files:**
- Modify: `.agents/skills/craft-character-3d/SKILL.md`
- Modify: `docs/superpowers/specs/2026-11-25-lote-inicial-personajes-3d-design.md`
- Create (ignored): `scratch/3d_jobs/{cuerpo_m,cuerpo_f,obrero_m,obrero_f}/turnaround.png`
- Create (ignored): `scratch/3d_jobs/{cuerpo_m,cuerpo_f,obrero_m,obrero_f}/views/{front,side,back}.png`

**Interfaces:**
- Consumes: spec aprobada y Plantilla A del agente.
- Produces: Plantilla A en T-Pose y doce vistas aprobadas para Modal.

- [ ] **Step 1: Escribir la comprobación textual que debe fallar**

Run: `rg -n "strict symmetrical A-pose|arms straight at 45|manos abiertas/relajadas en A-Pose" .agents/skills/craft-character-3d/SKILL.md`

Expected: encuentra las reglas antiguas.

- [ ] **Step 2: Cambiar únicamente las reglas humanoides del agente a T-Pose**

Exigir brazos horizontales a 90°, palmas hacia abajo y manos vacías; mantener intacto el retargeting que ya compensa diferencias de rest pose.

- [ ] **Step 3: Verificar la configuración**

Run: `rg -n "strict symmetrical A-pose|arms straight at 45|manos abiertas/relajadas en A-Pose" .agents/skills/craft-character-3d/SKILL.md`

Expected: sin coincidencias. Run: `rg -n "T-Pose|T-pose" .agents/skills/craft-character-3d/SKILL.md` y confirmar la plantilla y separación Capa 1/Capa 2.

- [ ] **Step 4: Generar cuatro turnarounds con imagegen**

Usar prompts independientes: base M y F con camisa beige sin chaleco; obrero M y F con la misma familia visual y chaleco verde bosque oscuro. Todos sin casco, gafas, herramientas ni canasta, con `mat_color_equipo` representado como brazalete/ribete blanco grisáceo.

- [ ] **Step 5: Recortar cada turnaround**

Run por asset: `python tools/3d_pipeline/split_turnaround.py --input "scratch/3d_jobs/<asset>/turnaround.png" --output-dir "scratch/3d_jobs/<asset>/views" --order front,side,back --size 1024`

Expected: tres PNG cuadrados alineados por asset.

- [ ] **Step 6: Mostrar los cuatro turnarounds y pausar por aprobación explícita**

No ejecutar Modal en esta tarea hasta obtenerla.

- [ ] **Step 7: Commit de configuración y documentos**

```bash
git add .agents/skills/craft-character-3d/SKILL.md docs/superpowers/specs/2026-11-25-lote-inicial-personajes-3d-design.md docs/superpowers/plans/2026-11-26-lote-inicial-personajes-3d.md
git commit -m "docs: define T-pose character asset pipeline"
```

### Task 2: Generar e integrar cuerpos base y obreros

**Files:**
- Create: `godot/assets/personajes/base/cuerpo_m.glb`
- Create: `godot/assets/personajes/base/cuerpo_f.glb`
- Create: `godot/assets/personajes/atuendos/obrero_m.glb`
- Create: `godot/assets/personajes/atuendos/obrero_f.glb`
- Create: correspondientes `*.glb.import` al importar en Godot

**Interfaces:**
- Consumes: vistas aprobadas de la Tarea 1.
- Produces: cuatro escenas glTF con esqueleto humanoide y materiales de identidad.

- [ ] **Step 1: Ejecutar Modal por cada humanoide**

Run: `modal run -e crafttonation tools/3d_pipeline/modal_hunyuan_rig.py --front "scratch/3d_jobs/<asset>/views/front.png" --side "scratch/3d_jobs/<asset>/views/side.png" --back "scratch/3d_jobs/<asset>/views/back.png" --target-faces 15000 --output "scratch/3d_jobs/<asset>/<asset>_raw_rigged.glb"`

Expected: cuatro GLB riggeados; si un job falla, reintentar solo ese asset.

- [ ] **Step 2: Postprocesar a Godot**

Usar `blender_godot_prepare.py` con `--height 1.80 --max-tex 1024 --force-decimate 5500 --head-protect-fraction 0.22`, escribiendo bases en `base/` y obreros en `atuendos/`.

- [ ] **Step 3: Añadir lipsync y normalizar materiales**

Ejecutar `blender_arkit_blendshapes.py --preset lipsync` por asset. Renombrar piel expuesta a `mat_piel` y el brazalete/ribete a `mat_color_equipo` con `blender_character_edit.py` si la inspección no los detecta.

- [ ] **Step 4: Inspeccionar y renderizar previews**

Ejecutar `blender_character_edit.py --inspect --render-preview` por asset. Expected: `3.000–6.000` tris, `1,80 m`, cuatro slots modulares verdaderos, ambos materiales y 18 shape keys.

- [ ] **Step 5: Verificar visualmente base frente a obrero**

Expected: M/F base sin chaleco; M/F obrero con chaleco verde oscuro; sin props horneados; sin deformaciones visibles en T-Pose.

- [ ] **Step 6: Importar en Godot y ejecutar prueba focalizada**

Run: Godot headless sobre `scenes/PersonajeModularTest.tscn`.

Expected: PASS y `obrero_m/f` resuelto como `atuendo`; `desempleado` y rangos sin atuendo resueltos como `base`.

- [ ] **Step 7: Commit**

```bash
git add godot/assets/personajes/base godot/assets/personajes/atuendos godot/scripts/PersonajeModularTest.gd
git commit -m "feat: add base and worker character models"
```

### Task 3: Retargeting de acciones seleccionadas desde GLB

**Files:**
- Modify: `tools/3d_pipeline/blender_retarget_mixamo.py`
- Create: `tools/3d_pipeline/blender_retarget_mixamo_test.py`

**Interfaces:**
- Consumes: `--add "Clip=ruta[::AccionFuente][|inicio:fin|velocidad]"`.
- Produces: `_parse_add_spec(spec: str) -> dict`, `_import_source(path: Path, source_action: str | None) -> tuple[Object, Action]` y el comportamiento FBX previo sin cambios.

- [ ] **Step 1: Escribir prueba Blender que falla**

Cubrir: parseo FBX legado; parseo GLB con acción; selección de las dos acciones reales del GLB; error que enumera acciones disponibles cuando se pide una inexistente.

- [ ] **Step 2: Ejecutar la prueba y confirmar fallo**

Run: `& "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe" --background --python tools/3d_pipeline/blender_retarget_mixamo_test.py`

Expected: FAIL porque la gramática `::AccionFuente` todavía no existe.

- [ ] **Step 3: Implementar importación por sufijo y selección exacta**

Para `.fbx`, conservar `bpy.ops.import_scene.fbx`; para `.glb`, usar `bpy.ops.import_scene.gltf`, localizar la acción exacta y asignarla al armature fuente antes de retargetear. No seleccionar por orden.

- [ ] **Step 4: Ejecutar la prueba**

Expected: PASS para FBX legado, ambas acciones GLB y error explícito.

- [ ] **Step 5: Smoke test real sobre copia del avatar**

Retargetear ambas acciones GLB a `scratch/3d_jobs/animation_smoke.glb`, inspeccionar que los clips destino se llamen `Hauler_Carry` y `Work_Table`.

- [ ] **Step 6: Commit**

```bash
git add tools/3d_pipeline/blender_retarget_mixamo.py tools/3d_pipeline/blender_retarget_mixamo_test.py
git commit -m "feat: retarget named animations from GLB"
```

### Task 4: Construir la biblioteca compartida de ocho clips

**Files:**
- Create: `godot/assets/personajes/animaciones/humanoide_base.glb`
- Create: `godot/assets/personajes/animaciones/humanoide_base.glb.import`

**Interfaces:**
- Consumes: avatar con `Idle`/`Walking`, cuatro FBX verificados y dos acciones GLB seleccionadas por la Tarea 3.
- Produces: una `AnimationLibrary` con los ocho nombres canónicos exactos.

- [ ] **Step 1: Crear una copia de trabajo del rig del avatar**

Copiar a `scratch/3d_jobs/humanoide_base/humanoide_base_work.glb`; nunca modificar `avatar/avatar.glb` durante la construcción.

- [ ] **Step 2: Retargetear los seis clips nuevos**

Usar `blender_retarget_mixamo.py` y los nombres canónicos. Para el GLB, seleccionar exactamente `A person carries a heavy backpack and wa (dfd307) (in place)` y `A person is standing while chopping and  (f7d778)`.

- [ ] **Step 3: Conservar `Idle` y `Walking`, retirar clips ajenos y exportar**

Expected: exactamente ocho animaciones y ninguna dependencia de nombres internos de las fuentes.

- [ ] **Step 4: Inspeccionar y renderizar muestras**

Renderizar poses representativas de los seis clips nuevos y revisar manos, hombros, pies y root motion. `Walking` y `Hauler_Carry` deben quedar in-place.

- [ ] **Step 5: Validar en base M/F y obrero M/F**

Expected: la misma biblioteca reproduce en los cuatro rigs sin deformación severa; si uno no comparte bind pose, retargetear únicamente ese rig como corrección localizada.

- [ ] **Step 6: Importar en Godot y comprobar nombres**

Run: Godot headless sobre `scenes/PersonajeModularTest.tscn` después de añadir una aserción que compare el conjunto de ocho nombres.

- [ ] **Step 7: Commit**

```bash
git add godot/assets/personajes/animaciones godot/scripts/PersonajeModularTest.gd
git commit -m "feat: add shared worker animation library"
```

### Task 5: Generar e integrar cuatro props

**Files:**
- Create: `godot/assets/personajes/equipamiento/{martillo,pico,hacha,canasta_acarreo}.glb`
- Create: correspondientes `*.glb.import`
- Create (ignored): turnarounds, vistas y previews bajo `scratch/3d_jobs/<pieza>/`

**Interfaces:**
- Consumes: Plantilla B y tamaños/slots de la spec.
- Produces: cuatro mallas rígidas sin rig listas para `BoneAttachment3D`.

- [ ] **Step 1: Generar, recortar y mostrar los cuatro turnarounds**

Usar una llamada imagegen independiente por prop. Ejecutar `split_turnaround.py` y pausar por la segunda aprobación visual obligatoria antes de Modal.

- [ ] **Step 2: Ejecutar Modal sin rig**

Usar `modal_hunyuan_rig.py --target-faces 1500 --skip-rig` por pieza.

- [ ] **Step 3: Preparar props en Blender**

Usar `blender_prop_prepare.py --target-tris 1000 --max-tex 512` con tamaños: martillo `0.45`, pico `0.68`, hacha `0.65`, canasta `0.45`. Pivote de herramientas en agarre y canasta en el centro geométrico.

- [ ] **Step 4: Inspeccionar previews**

Expected: sin armature/animaciones, `300–1.500` tris, escala correcta, silueta limpia y ninguna mano/persona horneada.

- [ ] **Step 5: Importar y ejecutar prueba focalizada**

Run: Godot headless sobre `scenes/PersonajeModularTest.tscn`.

Expected: las cuatro rutas se cargan y se instancian en sus slots.

- [ ] **Step 6: Commit**

```bash
git add godot/assets/personajes/equipamiento godot/scripts/PersonajeModularTest.gd
git commit -m "feat: add initial character equipment props"
```

### Task 6: Resolver animaciones por oficio y posición de canasta

**Files:**
- Modify: `godot/scripts/CatalogoPersonajes.gd`
- Modify: `godot/scripts/PersonajeModular.gd`
- Modify: `godot/scripts/PersonajeModularTest.gd`

**Interfaces:**
- Produces: `CatalogoPersonajes.resolver_animaciones(colono: Dictionary, tipo_puesto: String) -> Array[String]`.
- Produces: `CatalogoPersonajes.ajuste_equipamiento(pieza_id: String, slot: String) -> Transform3D`.
- Preserves: `resolver_equipamiento(...) -> Dictionary` con valores `slot -> pieza_id`.

- [ ] **Step 1: Escribir pruebas de tabla que fallen**

Assert exacto para acarreador cargado/moviéndose, caminante común, acarreador quieto/vacío, mina, pesca, maderero, caza/recolección, cada tipo industrial, construcción y fallback. Assert de canasta: quieto/vacío usa `RightHand`; cualquier desplazamiento o carga usa `Chest`.

- [ ] **Step 2: Ejecutar prueba focalizada y confirmar fallo**

Run: Godot headless sobre `scenes/PersonajeModularTest.tscn`.

Expected: FAIL por funciones/comportamientos ausentes.

- [ ] **Step 3: Implementar las tablas mínimas en `CatalogoPersonajes`**

Mina devuelve `['Mining_Dig', 'Heavy_Swing']`; los demás casos un pool unitario. Separar `maderero` de `aserradero`: el primero usa `Heavy_Swing`, el segundo `Work_Table`.

- [ ] **Step 4: Aplicar offset por pieza/slot al instanciar Capa 2**

En `_actualizar_capa2`, aplicar el `Transform3D` después de añadir la pieza. Ajustar visualmente `RightHand` para agarre a dos manos y `Chest` para espalda; no duplicar el GLB.

- [ ] **Step 5: Ejecutar prueba focalizada**

Expected: PASS, incluidas transiciones de canasta y lista industrial completa.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/CatalogoPersonajes.gd godot/scripts/PersonajeModular.gd godot/scripts/PersonajeModularTest.gd
git commit -m "feat: map worker states to animations and gear"
```

### Task 7: Reproducción y encadenamiento aleatorio

**Files:**
- Modify: `godot/scripts/PersonajeModular.gd`
- Modify: `godot/scripts/PersonajeModularTest.gd`

**Interfaces:**
- Consumes: `CatalogoPersonajes.resolver_animaciones(...)` de la Tarea 6.
- Produces: `PersonajeModular.animacion_actual() -> String` para observabilidad/pruebas.
- Produces: `PersonajeModular.elegir_animacion(pool: Array[String], indice: int) -> String` como selección pura; runtime aporta `RandomNumberGenerator.randi_range`.

- [ ] **Step 1: Escribir pruebas que fallen**

Cubrir loop solo para `Idle`, `Walking`, `Hauler_Box_Idle`, `Hauler_Carry`, `Fishing_Cast` y `Work_Table`; `Mining_Dig`/`Heavy_Swing` no-loop; mismo índice dos veces permite repetir clip; `animation_finished` vuelve a sortear mina; maderero/construcción repiten `Heavy_Swing`; clip ausente cae en `Idle`.

- [ ] **Step 2: Ejecutar prueba focalizada y confirmar fallo**

Expected: FAIL con el controlador actual de tres clips.

- [ ] **Step 3: Implementar pool, RNG y señal de finalización**

Sembrar una vez con `colono.id`; no resembrar cada frame. Mantener dirty-checking: no reiniciar el mismo loop mientras está reproduciéndose.

- [ ] **Step 4: Implementar fallback seguro**

Filtrar del pool los clips ausentes; usar `Idle` si existe y, si tampoco existe, retornar sin error.

- [ ] **Step 5: Ejecutar prueba focalizada**

Expected: PASS y la prueba de repetición demuestra que no hay alternancia forzada.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/PersonajeModular.gd godot/scripts/PersonajeModularTest.gd
git commit -m "feat: play contextual worker animation sequences"
```

### Task 8: Integración visual, regresión y entrega

**Files:**
- Modify only if defects are found: assets/scripts owned by Tasks 2–7
- Update: `README.md` and/or `docs/Pendientes y próximos pasos.md` only where the repository tracks completed asset work

**Interfaces:**
- Consumes: todos los entregables anteriores.
- Produces: lote validado y documentado sobre `main`.

- [ ] **Step 1: Ejecutar pruebas focalizadas**

Run: `PersonajeModularTest.tscn`, `AvatarAnimadorTest.tscn` y `ColonosTest.tscn` headless.

Expected: PASS sin `SCRIPT ERROR`, `ERROR`, `Parse Error` ni assertions.

- [ ] **Step 2: Ejecutar la suite completa**

Run: `pwsh -File tools/run-godot-tests.ps1`

Expected: todas las escenas listadas por el runner pasan.

- [ ] **Step 3: Realizar QA visual en juego**

Comprobar M/F desempleado y obrero, cuatro tonos de piel, seis equipos, canasta manos/espalda, pesca, mina con repeticiones, maderero, caza/recolección, industria y construcción. Capturar evidencia en `scratch/3d_jobs/integration/`.

- [ ] **Step 4: Corregir solo defectos observados y repetir su prueba propietaria**

No ampliar a otros atuendos, props, LOD o MultiMesh.

- [ ] **Step 5: Actualizar documentación de estado**

Marcar únicamente entregables realmente verificados; no declarar completo un asset que dependa de una aprobación pendiente.

- [ ] **Step 6: Commit final de integración**

```bash
git add README.md "docs/Pendientes y próximos pasos.md"
git commit -m "docs: record initial character asset integration"
```

- [ ] **Step 7: Verificar árbol y commits antes de push**

Run: `git status --short --branch` y `git log --oneline origin/main..HEAD`.

Expected: solo permanecen los cambios ajenos preexistentes; los commits del lote están listos para revisión/push.

# Lote inicial de personajes 3D — Diseño

**Fecha:** 2026-11-25
**Proyecto:** Craft to Nation
**Agente/pipeline:** `ctn-img-2-character` + `.agents/skills/craft-character-3d/SKILL.md`

## Intención

Reemplazar las cápsulas de todos los colonos por humanoides coherentes con el avatar actual usando un lote pequeño que aproveche la arquitectura modular ya implementada. Los cuerpos base representan al desempleado con camisa beige y funcionan como fallback temporal; el obrero empleado añade un chaleco verde oscuro mediante un atuendo deformable. Cuatro props y una biblioteca de animaciones por oficio distinguen construcción, acarreo, minería, pesca, madera, recolección e industria.

## Entregables

```text
godot/assets/personajes/
├── base/
│   ├── cuerpo_m.glb
│   └── cuerpo_f.glb
├── atuendos/
│   ├── obrero_m.glb
│   └── obrero_f.glb
├── animaciones/
│   └── humanoide_base.glb
└── equipamiento/
    ├── martillo.glb
    ├── pico.glb
    ├── hacha.glb
    └── canasta_acarreo.glb
```

También se conservan en `scratch/3d_jobs/<asset>/` los turnarounds, vistas recortadas, GLB intermedios, inspecciones y previews para iteración; `scratch/` no se versiona.

## Enfoques considerados

1. **Cuerpos base + atuendo obrero + animaciones + cuatro props — elegido y ampliado.** Cambia visualmente a toda la población y diferencia desempleados de empleados manuales con nueve assets. Requiere una extensión acotada de GDScript para elegir clips por oficio y cambiar la canasta entre manos y espalda.
2. **Obrero masculino/femenino completo.** Mayor detalle para un oficio, pero los demás rangos continuarían como cápsulas.
3. **Catálogo completo de 31 assets.** Acabado final, pero multiplica generaciones, aprobaciones y correcciones antes de validar el estilo.

## Dirección visual común

- Estilo low-mid poly estilizado, formas limpias y materiales PBR pintados a mano, coherente con el avatar masculino actual.
- Proporciones ligeramente heroicas pero funcionales: cabeza moderadamente grande, manos legibles desde la cámara cenital, botas y silueta claras.
- Sin transparencias, capas largas, faldones entre las piernas ni piezas delgadas que Hunyuan pueda fusionar.
- Paleta inicial: verde bosque oscuro para el chaleco del obrero, cuero marrón, beige cálido para la camisa base y metal gris apagado; evita neón y superficies excesivamente metálicas.
- Los cuatro tonos de piel no se hornean como variantes: el material expuesto se llama `mat_piel` y Godot aplica el tono.
- Un ribete/brazalete blanco grisáceo usa `mat_color_equipo`, para que Godot aplique el color de facción.
- Cada turnaround humanoide: frente, perfil izquierdo y espalda ortográficos, **T-Pose estricta**, brazos horizontales a 90°, palmas hacia abajo, misma escala y línea de suelo, fondo blanco puro sin sombras ni texto. Esta decisión del proyecto reemplaza el A-Pose predeterminado del agente y alinea la pose de reposo con los archivos Mixamo descargados.

## Cuerpos base

### `base/cuerpo_m.glb`

- Humano masculino adulto, 1,80 m, constitución atlética media sin musculatura extrema.
- Cabello corto oscuro, rostro amistoso y neutro, sin barba prominente.
- Ropa base visible y apropiada como fallback: camisa beige de manga corta, pantalón carbón, cinturón de cuero sin bolsas y botas marrones.
- Acento de equipo: brazalete liso blanco grisáceo en brazo izquierdo.
- Sin gafas, casco, mochila, canasta, arma, herramienta ni objetos colgantes.
- Manos abiertas, dedos juntos y brazos horizontales en T-Pose.

### `base/cuerpo_f.glb`

- Humana adulta, 1,80 m para compartir locomoción/espacios del juego, constitución atlética media, marcada silueta femenina (no voluptuosa).
- Cabello oscuro recogido en moño bajo o coleta corta compacta, sin mechones largos sueltos.
- La misma familia de ropa y materiales del cuerpo masculino: camisa beige, pantalón carbón y botas marrones; corte diferenciado sin falda.
- Acento de equipo: brazalete liso blanco grisáceo en brazo izquierdo.
- Sin gafas, casco, mochila, canasta, arma, herramienta ni objetos colgantes.
- Manos abiertas y silueta limpia en T-Pose.

### Requisitos técnicos de ambos cuerpos

- `3.000–6.000` triángulos; objetivo Blender `5.500` máximo.
- Textura `1024×1024` mientras se valida el estilo; reducir a `512×512` solo si la comparación en juego no pierde lectura.
- Altura normalizada `1,80 m`, pies en `Z=0`.
- `SkeletonProfileHumanoid` con `Head`, `Chest` o equivalente, `RightHand` y `LeftHand`.
- Materiales `mat_piel` y `mat_color_equipo` detectables por `CatalogoPersonajes.gd`.
- Preset `lipsync` de 18 blendshapes después de aprobar geometría y rig.
- Sin clips completos embebidos: `PersonajeModular` usa la biblioteca compartida.

## Atuendo de empleado manual

### `atuendos/obrero_m.glb` y `atuendos/obrero_f.glb`

- Repiten cuerpo, camisa beige, pantalón y botas de sus respectivas bases, y añaden un chaleco verde bosque oscuro corto y ceñido.
- El chaleco no forma parte de `cuerpo_m.glb` ni `cuerpo_f.glb`: un desempleado debe verse únicamente con la camisa beige.
- Se implementa como parte deformable de la Capa 1 de `obrero`, no como prop rígido `Chest`; así acompaña el torso y los hombros durante pesca, carga y golpes sin separarse ni atravesar el cuerpo.
- En el modelo de datos actual, los desempleados contratados como recolectores o acarreadores pasan a `tipo = "obrero"`, por lo que estos dos archivos cubren a los empleados manuales. Técnicos, especialistas, investigadores y militares conservarán el fallback base hasta recibir sus atuendos específicos.
- Conservan los mismos requisitos técnicos, rig, materiales de identidad, altura y T-Pose de los cuerpos base.

## Biblioteca `animaciones/humanoide_base.glb`

- Se deriva localmente del `avatar/avatar.glb` existente; no usa Modal ni genera geometría nueva.
- Usa el mismo perfil humanoide. La malla puede ser mínima porque el archivo funciona como biblioteca de animaciones.
- Se valida primero sobre ambos cuerpos base y ambos obreros; solo se retargetea por separado si el bind pose impide compartir correctamente hombros, manos o pies.
- Los nombres internos de las fuentes se normalizan al exportar. Godot solo depende de los nombres canónicos de la tabla siguiente.

| Clip canónico | Fuente | Uso | Repetición |
|---|---|---|---|
| `Idle` | biblioteca existente del avatar | desempleado o trabajador sin una acción específica | loop |
| `Walking` | biblioteca existente del avatar | desplazamiento común sin carga | loop, in-place |
| `Hauler_Box_Idle` | `arte/animations/work/Box Idle.fbx` | acarreador quieto esperando recursos, canasta en las manos | loop |
| `Hauler_Carry` | acción interna `A person carries a heavy backpack... (in place)` de `carrying and working on a table.glb` | acarreador en movimiento o con carga, canasta en la espalda | loop, in-place |
| `Fishing_Cast` | `arte/animations/work/Fishing Cast.fbx` | recolector en `pesca_frutos_mar` | loop tras validar que el empalme no salta |
| `Mining_Dig` | `arte/animations/work/Digging.fbx` | recolector en `mina` | no-loop; el selector decide el siguiente clip |
| `Heavy_Swing` | `arte/animations/Heavy Weapon Swing.fbx` | mina, maderero y construcción | no-loop; se vuelve a elegir al terminar |
| `Work_Table` | acción interna `A person is standing while chopping...` de `carrying and working on a table.glb` | caza/recolección e industria | loop |

Los cuatro FBX fueron verificados como Mixamo de 65 huesos a 30 fps. El GLB fue verificado con un rig Mixamo reducido de 22 huesos, dos acciones de 95,2 frames a 24 fps y nombres de hueso compatibles con el mapeo existente. El importador/retargeter deberá aceptar una acción concreta desde GLB además de FBX para no depender del orden de las pistas.

### Selección de animación en ejecución

La selección recibe `colono` y `tipo_puesto`, y respeta esta prioridad:

1. Cualquier colono con rol `acarreador` usa exclusivamente animaciones de acarreo, sin importar el edificio: si está en movimiento o tiene `carga` no vacía usa `Hauler_Carry`; si está quieto y vacío usa `Hauler_Box_Idle`.
2. Cualquier otro colono en movimiento: `Walking`.
3. Mina: elegir aleatoriamente `Mining_Dig` o `Heavy_Swing` cada vez que termina el clip. La elección es independiente, por lo que puede repetirse el mismo clip varias veces seguidas.
4. Pesca: `Fishing_Cast`.
5. Maderero: `Heavy_Swing`.
6. Caza/recolección: `Work_Table`.
7. Edificios industriales —`aserradero`, `siderurgica`, `refineria_tierras_raras`, `fabrica_bloques`, `vidriera`, `carbonera`, `refineria_petrolera`, `productor_combustible`, `central_termoelectrica`, `estacion_bombeo` y `taller_transporte`—: `Work_Table`.
8. Tarea de construcción: `Heavy_Swing` con martillo.
9. Cualquier caso no cubierto o clip ausente: `Idle`.

`Mining_Dig` y `Heavy_Swing` no se marcan como loops lineales. `PersonajeModular` escucha el fin del clip: en mina vuelve a sortear entre ambos; en maderero o construcción repite `Heavy_Swing`. El generador aleatorio se inicializa una vez por personaje para evitar una alternancia accidental y permitir pruebas reproducibles.

## Props rígidos Capa 2

Todos son mallas estáticas sin rig, con textura `512×512`, entre `300–1.500` triángulos y sin manos/personajes en el turnaround.

### `martillo.glb`

- Martillo de obra robusto, mango de madera oscura y cabeza rectangular de acero mate con pequeñas bandas de latón.
- Longitud final `0,45 m`; slot `RightHand`; pivote centrado en el punto de agarre.

### `pico.glb`

- Pico minero industrial temprano, mango de madera reforzado y cabeza de acero simétrica ligeramente gastada.
- Longitud final `0,68 m`; slot `RightHand`; pivote en el agarre inferior útil para `Mining_Dig` y `Heavy_Swing`.

### `hacha.glb`

- Hacha de trabajo de una mano, mango de madera y hoja ancha de acero oscuro, sin aspecto de arma fantástica.
- Longitud final `0,65 m`; slot `RightHand`; pivote en el agarre.

### `canasta_acarreo.glb`

- Canasta compacta de mimbre oscuro con marco de madera y dos correas de cuero, espalda plana para no atravesar el torso.
- Tamaño final `0,45 m`; un único asset se usa con dos ajustes registrados en el catálogo: `RightHand` durante `Hauler_Box_Idle`, orientado para que ambas manos rodeen las asas, y `Chest` durante transporte o desplazamiento, apoyado en la espalda.
- El pivote se mantiene en el centro de la canasta; los offsets por slot se aplican en Godot, evitando duplicar la geometría como dos GLB.
- Sin contenido fijo para que sirva con cualquier recurso; no necesita `mat_color_equipo`.

## Flujo de producción y compuertas

1. Actualizar la configuración del agente del proyecto para que la Plantilla A y las validaciones exijan T-Pose.
2. Generar juntos los turnarounds de `cuerpo_m` y `cuerpo_f` con la Plantilla A, sin chaleco.
3. Generar `obrero_m` y `obrero_f` con el mismo cuerpo y el chaleco verde oscuro.
4. Recortar a `front/side/back` mediante `split_turnaround.py`.
5. Mostrar los cuatro turnarounds humanos y pedir aprobación explícita.
6. Solo tras aprobación: ejecutar Hunyuan3D-2mv + UniRig en Modal y postprocesar en Blender.
7. Inspeccionar triángulos, altura, huesos, materiales y preview; corregir localmente antes de regenerar.
8. Extender el retargeter para seleccionar acciones desde GLB; crear `humanoide_base.glb` y validar los ocho clips sobre M/F y obrero M/F.
9. Generar los cuatro turnarounds de props con la Plantilla B y pedir una segunda aprobación visual.
10. Solo tras aprobación: Modal `--skip-rig`, `blender_prop_prepare.py`, previews e integración drop-in.
11. Añadir el selector de animación por oficio, la repetición aleatoria de mina y los dos offsets de canasta con pruebas focalizadas.
12. Ejecutar `PersonajeModularTest.tscn`, `AvatarAnimadorTest.tscn`, `ColonosTest.tscn` y finalmente la suite completa. Las pruebas del catálogo viven actualmente en `PersonajeModularTest.gd`.

## Criterios de aceptación

- Todos los colonos muestran cuerpo humanoide M/F mediante fallback base; el desempleado no lleva chaleco y el `obrero` empleado sí.
- Los cuatro tonos de piel y seis colores de equipo cambian en tiempo real sin materiales rotos.
- Los ocho clips canónicos se importan con sus nombres exactos y cada oficio selecciona el esperado.
- Idle, caminar, carga, pesca, trabajo de mesa, excavación y golpe no deforman hombros, codos, manos, rodillas ni pies de forma visible.
- En mina, una secuencia suficientemente larga puede contener `Mining_Dig, Mining_Dig` o `Heavy_Swing, Heavy_Swing`; no hay alternancia forzada.
- La canasta aparece en manos al esperar recursos y en la espalda al transportarlos; los demás props aparecen en el slot correcto, sin atravesar de forma severa cuerpo o suelo.
- Cada cuerpo respeta altura, triángulos, slots, materiales y blendshapes definidos.
- La suite completa de escenas de prueba sigue pasando.

## Fuera de alcance

- Avatar femenino, reparación ARKit/materiales del avatar masculino, los otros atuendos por rango y los otros nueve props.
- LOD, `MultiMesh`, variantes de cabello/rostro y personalización corporal.
- Animaciones todavía no suministradas para agricultura, escuelas, investigación, ejército o desempleo más allá de `Idle`/`Walking`.

## Riesgos y respuesta mínima

- Si Hunyuan fusiona manos/ropa: corregir primero el turnaround; no reparar topología compleja a mano salvo un defecto localizado.
- Si M/F no comparten bien animaciones: retargetear los clips al segundo rig; no crear otro sistema de animación.
- Si `Digging` no alinea las manos con el pico, ajustar el grip/offset primero; añadir una pala solo mediante una decisión de diseño posterior.
- Si el empalme de `Fishing_Cast` produce un salto visible, reproducirlo como clip no-loop con una pausa corta antes de reiniciarlo.
- Si 1024 px no mejora la lectura cenital: reducir a 512 px en Blender para ahorrar memoria.

# blender_godot_prepare.py

> 24 nodes · cohesion 0.16

## Key Concepts

- **blender_godot_prepare.py** (23 connections) — `tools/3d_pipeline/blender_godot_prepare.py`
- **prepare_scene()** (13 connections) — `tools/3d_pipeline/blender_godot_prepare.py`
- **Object** (8 connections)
- **_apply_head_protected_decimate()** (6 connections) — `tools/3d_pipeline/blender_godot_prepare.py`
- **map_humanoid_bones()** (5 connections) — `tools/3d_pipeline/blender_godot_prepare.py`
- **_world_mesh_bbox()** (5 connections) — `tools/3d_pipeline/blender_godot_prepare.py`
- **count_triangles()** (4 connections) — `tools/3d_pipeline/blender_godot_prepare.py`
- **_fix_rigid_head_weights()** (4 connections) — `tools/3d_pipeline/blender_godot_prepare.py`
- **main()** (4 connections) — `tools/3d_pipeline/blender_godot_prepare.py`
- **_parse_args()** (4 connections) — `tools/3d_pipeline/blender_godot_prepare.py`
- **_weld_and_smooth_meshes()** (4 connections) — `tools/3d_pipeline/blender_godot_prepare.py`
- **_fix_default_pbr()** (3 connections) — `tools/3d_pipeline/blender_godot_prepare.py`
- **_norm_key()** (3 connections) — `tools/3d_pipeline/blender_godot_prepare.py`
- **_real_meshes()** (3 connections) — `tools/3d_pipeline/blender_godot_prepare.py`
- **_real_roots()** (3 connections) — `tools/3d_pipeline/blender_godot_prepare.py`
- **resize_textures()** (2 connections) — `tools/3d_pipeline/blender_godot_prepare.py`
- **Namespace** (1 connections)
- **Vector** (1 connections)
- **Post-procesado headless en Blender para preparar personajes riggeados (.glb)…** (1 connections) — `tools/3d_pipeline/blender_godot_prepare.py`
- **Renombra huesos al estandar Godot 4 SkeletonProfileHumanoid.** (1 connections) — `tools/3d_pipeline/blender_godot_prepare.py`
- **Suelda triangulos desconectados (conservando UVs), limpia normales planas y…** (1 connections) — `tools/3d_pipeline/blender_godot_prepare.py`
- **Decima priorizando la cabeza/cara: protege los vertices superiores con un…** (1 connections) — `tools/3d_pipeline/blender_godot_prepare.py`
- **Asigna peso rigido 1.0 al hueso Head para vertices del craneo/rostro…** (1 connections) — `tools/3d_pipeline/blender_godot_prepare.py`
- **Corrige metallic=1.0 heredado de Hunyuan3D-Paint para acabado PBR natural en…** (1 connections) — `tools/3d_pipeline/blender_godot_prepare.py`

## Relationships

- [VentanaBaul.gd](VentanaBaul.gd.md) (6 shared connections)
- [argparse](argparse.md) (2 shared connections)
- [blender_character_edit.py](blender_character_edit.py.md) (2 shared connections)
- [blender_retarget_mixamo_test.py](blender_retarget_mixamo_test.py.md) (1 shared connections)
- [blender_arkit_blendshapes.py](blender_arkit_blendshapes.py.md) (1 shared connections)

## Source Files

- `tools/3d_pipeline/blender_godot_prepare.py`

## Audit Trail

- EXTRACTED: 57 (100%)
- INFERRED: 0 (0%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [index](index.md) to navigate.*
"""Prepara props rigidos de Capa 2 (sin esqueleto ni animaciones) en Blender 5.3
headless para `godot/assets/personajes/equipamiento/<pieza>.glb` (Craft to Nation).

Uso por CLI:
    blender --background --python tools/3d_pipeline/blender_prop_prepare.py -- \
        --input scratch/3d_jobs/pico/pico_raw.glb \
        --output godot/assets/personajes/equipamiento/pico.glb \
        --slot RightHand \
        --size 0.65 \
        --target-tris 1000 \
        --max-tex 512 \
        --render-preview scratch/3d_jobs/pico/preview.png
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Euler, Vector

SLOT_DEFAULT_SIZE: dict[str, float] = {
    "RightHand": 0.65,
    "LeftHand": 0.65,
    "Head": 0.26,
    "Chest": 0.42,
    "none": 0.50,
}


def _real_meshes() -> list[bpy.types.Object]:
    return [
        o
        for o in bpy.context.scene.objects
        if o.type == "MESH" and not any("glTF_not_exported" in c.name for c in o.users_collection)
    ]


def _world_bbox(meshes: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    min_v = Vector((float("inf"), float("inf"), float("inf")))
    max_v = Vector((float("-inf"), float("-inf"), float("-inf")))
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in meshes:
        eval_obj = obj.evaluated_get(depsgraph)
        mesh = eval_obj.to_mesh()
        try:
            mat = eval_obj.matrix_world
            for v in mesh.vertices:
                co = mat @ v.co
                min_v.x = min(min_v.x, co.x)
                min_v.y = min(min_v.y, co.y)
                min_v.z = min(min_v.z, co.z)
                max_v.x = max(max_v.x, co.x)
                max_v.y = max(max_v.y, co.y)
                max_v.z = max(max_v.z, co.z)
        finally:
            eval_obj.to_mesh_clear()
    return min_v, max_v


def _count_triangles(meshes: list[bpy.types.Object]) -> int:
    total = 0
    for obj in meshes:
        obj.data.calc_loop_triangles()
        total += len(obj.data.loop_triangles)
    return total


def _strip_armatures(meshes: list[bpy.types.Object]) -> int:
    """Desvincula mallas de cualquier Armature conservando su transformacion mundial y elimina los huesos."""
    for obj in meshes:
        world_mat = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = world_mat
        for mod in list(obj.modifiers):
            if mod.type == "ARMATURE":
                obj.modifiers.remove(mod)

    armatures = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    removed = len(armatures)
    for arm in armatures:
        bpy.data.objects.remove(arm, do_unlink=True)
    for arm_data in list(bpy.data.armatures):
        if arm_data.users == 0:
            bpy.data.armatures.remove(arm_data)
    return removed


def _weld_and_fix_pbr(meshes: list[bpy.types.Object]) -> None:
    for obj in meshes:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.remove_doubles(threshold=1e-5)
        bpy.ops.object.mode_set(mode="OBJECT")
        if obj.data.has_custom_normals:
            bpy.ops.mesh.customdata_custom_splitnormals_clear()
        for poly in obj.data.polygons:
            poly.use_smooth = True

    for mat in bpy.data.materials:
        if not mat.node_tree:
            continue
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if not bsdf:
            continue
        if bsdf.inputs["Metallic"].default_value >= 0.95:
            bsdf.inputs["Metallic"].default_value = 0.15
        if bsdf.inputs["Roughness"].default_value >= 0.88:
            bsdf.inputs["Roughness"].default_value = 0.72


def _resize_textures(max_tex: int) -> list[dict]:
    report: list[dict] = []
    for img in bpy.data.images:
        w, h = img.size[0], img.size[1]
        if w == 0 or h == 0:
            continue
        if max(w, h) > max_tex:
            scale = max_tex / float(max(w, h))
            nw = max(1, int(round(w * scale)))
            nh = max(1, int(round(h * scale)))
            img.scale(nw, nh)
            img.pack()
            report.append({"name": img.name, "from": [w, h], "to": [nw, nh]})
        else:
            report.append({"name": img.name, "size": [w, h]})
    return report


def _render_preview(out_png: Path, meshes: list[bpy.types.Object]) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = 640
    scene.render.resolution_y = 640
    scene.render.film_transparent = False
    scene.world = scene.world or bpy.data.worlds.new("PropPreviewWorld")
    scene.world.color = (0.92, 0.92, 0.92)
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"

    min_v, max_v = _world_bbox(meshes)
    center = (min_v + max_v) * 0.5
    max_dim = max((max_v - min_v).x, (max_v - min_v).y, (max_v - min_v).z, 0.1)

    cam_data = bpy.data.cameras.new("PropPreviewCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = max_dim * 1.35
    cam_obj = bpy.data.objects.new("PropPreviewCam", cam_data)
    scene.collection.objects.link(cam_obj)
    cam_obj.location = (center.x + max_dim * 1.4, center.y - max_dim * 1.8, center.z + max_dim * 0.9)
    direction = (center - cam_obj.location).normalized()
    cam_obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam_obj

    out_png.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(out_png)
    bpy.ops.render.render(write_still=True)


def prepare_prop(
    slot: str = "RightHand",
    size: float = 0.0,
    target_tris: int = 1000,
    max_tex: int = 512,
    rotate_xyz: tuple[float, float, float] = (0.0, 0.0, 0.0),
    pivot_offset: tuple[float, float, float] = (0.0, 0.0, 0.0),
    rename_materials: list[str] | None = None,
) -> dict:
    meshes = _real_meshes()
    if not meshes:
        raise RuntimeError("No se encontraron mallas en el archivo de entrada.")

    armatures_removed = _strip_armatures(meshes)
    tris_before = _count_triangles(meshes)

    _weld_and_fix_pbr(meshes)

    if target_tris > 0 and tris_before > target_tris:
        ratio = max(0.05, min(1.0, target_tris / float(tris_before)))
        for obj in meshes:
            mod = obj.modifiers.new(name="CTN_PropDecimate", type="DECIMATE")
            mod.decimate_type = "COLLAPSE"
            mod.ratio = ratio
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.modifier_apply(modifier=mod.name)
            for poly in obj.data.polygons:
                poly.use_smooth = True

    textures_report = _resize_textures(max_tex)

    # Desemparentar de cualquier Empty intermedio manteniendo transforms en mundo
    for obj in meshes:
        wm = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = wm

    # Eliminar objetos vacios sobrantes (empties heredados de glTF)
    for obj in list(bpy.context.scene.objects):
        if obj not in meshes and obj.type != "CAMERA" and obj.type != "LIGHT":
            if not any("glTF_not_exported" in c.name for c in obj.users_collection):
                bpy.data.objects.remove(obj, do_unlink=True)

    # Rotacion previa al calculo de escala y pivote
    rx, ry, rz = (math.radians(a) for a in rotate_xyz)
    if abs(rx) > 1e-5 or abs(ry) > 1e-5 or abs(rz) > 1e-5:
        rot_mat = Euler((rx, ry, rz), "XYZ").to_matrix().to_4x4()
        for obj in meshes:
            obj.matrix_world = rot_mat @ obj.matrix_world
        bpy.context.view_layer.update()

    # Escalado uniforme al tamano objetivo del slot
    target_size = size if size > 0.0 else SLOT_DEFAULT_SIZE.get(slot, 0.50)
    min_v, max_v = _world_bbox(meshes)
    dims = max_v - min_v
    cur_max = max(dims.x, dims.y, dims.z, 1e-5)
    scale_factor = target_size / cur_max
    for obj in meshes:
        obj.scale = (obj.scale.x * scale_factor, obj.scale.y * scale_factor, obj.scale.z * scale_factor)
        obj.location = (obj.location.x * scale_factor, obj.location.y * scale_factor, obj.location.z * scale_factor)
    bpy.context.view_layer.update()

    # Alineacion de pivote al origen (0,0,0) segun slot de BoneAttachment3D
    min_v, max_v = _world_bbox(meshes)
    cx = (min_v.x + max_v.x) * 0.5
    cy = (min_v.y + max_v.y) * 0.5
    cz = (min_v.z + max_v.z) * 0.5
    h = max_v.z - min_v.z

    if slot in ("RightHand", "LeftHand"):
        shift = Vector((-cx, -cy, -(min_v.z + 0.20 * h)))
    elif slot == "Head":
        shift = Vector((-cx, -cy, -(min_v.z + 0.35 * h)))
    elif slot == "Chest":
        shift = Vector((-cx, -min_v.y, -cz))
    else:
        shift = Vector((-cx, -cy, -min_v.z))

    shift += Vector(pivot_offset)
    for obj in meshes:
        obj.location += shift
    bpy.context.view_layer.update()

    # Aplicar rotacion, escala y ubicacion para entregar transform limpio unitario con pivote en (0,0,0)
    for obj in meshes:
        if obj.data.users > 1:
            obj.data = obj.data.copy()
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # Renombrado opcional de materiales (ej. Material_0=mat_color_equipo)
    if rename_materials:
        for pair in rename_materials:
            if "=" not in pair:
                continue
            old_m, new_m = pair.split("=", 1)
            mat = bpy.data.materials.get(old_m.strip())
            if mat is not None:
                mat.name = new_m.strip()

    min_final, max_final = _world_bbox(meshes)
    dims_final = max_final - min_final
    mat_names = [m.name for m in bpy.data.materials]
    return {
        "slot": slot,
        "armatures_removed": armatures_removed,
        "triangles_before": tris_before,
        "triangles_after": _count_triangles(meshes),
        "dimensions_m": [round(dims_final.x, 4), round(dims_final.y, 4), round(dims_final.z, 4)],
        "bbox_min": [round(min_final.x, 4), round(min_final.y, 4), round(min_final.z, 4)],
        "bbox_max": [round(max_final.x, 4), round(max_final.y, 4), round(max_final.z, 4)],
        "materials": mat_names,
        "has_mat_color_equipo": any(
            n.strip().lower().startswith(("mat_color_equipo", "team_color")) for n in mat_names
        ),
        "textures": textures_report,
    }


def _parse_vec3(spec: str) -> tuple[float, float, float]:
    parts = [float(p.strip()) for p in spec.split(",")]
    if len(parts) != 3:
        raise ValueError(f"Se esperaban 3 valores separados por coma, recibido: {spec}")
    return parts[0], parts[1], parts[2]


def _parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    p = argparse.ArgumentParser(description="Prepara un prop rigido Capa 2 (.glb) para Godot 4.")
    p.add_argument("--input", "-i", required=True, type=Path, help="Ruta al .glb crudo de entrada.")
    p.add_argument("--output", "-o", required=True, type=Path, help="Ruta al .glb final en equipamiento/.")
    p.add_argument(
        "--slot",
        choices=["RightHand", "LeftHand", "Head", "Chest", "none"],
        default="RightHand",
        help="Slot de BoneAttachment3D en Godot 4 (define pivote y tamano por defecto).",
    )
    p.add_argument("--size", type=float, default=0.0, help="Dimension maxima en metros (0 = default del slot).")
    p.add_argument("--target-tris", type=int, default=1000, help="Maximo de triangulos (0 = sin decimate).")
    p.add_argument("--max-tex", type=int, default=512, help="Resolucion maxima de textura (256 o 512).")
    p.add_argument("--rotate-xyz", type=str, default="0,0,0", help="Rotacion Euler XYZ en grados (rx,ry,rz).")
    p.add_argument("--pivot-offset", type=str, default="0,0,0", help="Ajuste fino de pivote en metros (dx,dy,dz).")
    p.add_argument(
        "--rename-material",
        action="append",
        default=[],
        help="Renombra material: Viejo=Nuevo (ej. Material_0=mat_color_equipo).",
    )
    p.add_argument("--render-preview", type=Path, help="Guarda render ortografico 3/4 PNG del prop.")
    return p.parse_args(argv)


def main() -> None:
    args = _parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(args.input))

    summary = prepare_prop(
        slot=args.slot,
        size=args.size,
        target_tris=args.target_tris,
        max_tex=args.max_tex,
        rotate_xyz=_parse_vec3(args.rotate_xyz),
        pivot_offset=_parse_vec3(args.pivot_offset),
        rename_materials=args.rename_material,
    )

    if args.render_preview:
        meshes = _real_meshes()
        if meshes:
            _render_preview(args.render_preview, meshes)
            summary["preview"] = str(args.render_preview)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(args.output),
        export_format="GLB",
        export_yup=True,
        export_skins=False,
        export_animations=False,
        export_materials="EXPORT",
    )
    summary["output"] = str(args.output)
    print("CTN_PROP_SUMMARY=" + json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()

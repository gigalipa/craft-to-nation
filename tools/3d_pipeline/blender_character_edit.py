"""Herramienta headless en Blender para inspeccionar, corregir, modificar y mejorar
modelos 3D (.glb) ya creados para Craft to Nation.

Permite al agente `ctn-img-2-character` atender instrucciones iterativas del usuario
sin necesidad de regenerar desde cero en Modal cuando la correccion es local:
  - Inspeccionar metricas (triangulos, dimensiones, huesos, materiales, texturas).
  - Ajustar altura, proporciones XYZ y orientacion (ej. rotar 180 grados).
  - Modificar materiales PBR (roughness, metallic, tinte de color de clase).
  - Redimensionar texturas (512/1024) o aplicar decimate controlado.
  - Renombrar huesos puntuales o ajustar angulos de pose (A-Pose / T-Pose).
  - Renderizar una vista previa ortografica (frontal/lateral/espalda) en PNG.

Uso:
    blender --background --python tools/3d_pipeline/blender_character_edit.py -- \
        --input godot/assets/personajes/obrero/obrero.glb --inspect
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Euler, Vector


def _hex_to_rgb(hex_color: str) -> tuple[float, float, float]:
    h = hex_color.strip().lstrip("#")
    if len(h) != 6:
        raise ValueError(f"Color hex invalido: {hex_color}")
    return tuple(int(h[i : i + 2], 16) / 255.0 for i in (0, 2, 4))  # type: ignore[return-value]


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


def _real_meshes() -> list[bpy.types.Object]:
    return [
        o
        for o in bpy.context.scene.objects
        if o.type == "MESH" and not any("glTF_not_exported" in c.name for c in o.users_collection)
    ]


def _real_roots() -> list[bpy.types.Object]:
    return [
        o
        for o in bpy.context.scene.objects
        if o.parent is None and not any("glTF_not_exported" in c.name for c in o.users_collection)
    ]


def inspect_scene() -> dict:
    meshes = _real_meshes()
    armatures = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    tris = 0
    for m in meshes:
        m.data.calc_loop_triangles()
        tris += len(m.data.loop_triangles)
    min_v, max_v = _world_bbox(meshes) if meshes else (Vector(), Vector())
    dims = max_v - min_v

    materials = []
    for mat in bpy.data.materials:
        info = {"name": mat.name}
        if mat.node_tree:
            bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
            if bsdf:
                info["roughness"] = round(float(bsdf.inputs["Roughness"].default_value), 3)
                info["metallic"] = round(float(bsdf.inputs["Metallic"].default_value), 3)
        materials.append(info)

    textures = [
        {"name": img.name, "size": [img.size[0], img.size[1]]}
        for img in bpy.data.images
        if img.size[0] > 0 and img.size[1] > 0
    ]
    bones = [b.name for b in armatures[0].data.bones] if armatures else []

    shape_keys: list[str] = []
    for m in meshes:
        if m.data.shape_keys is not None:
            shape_keys.extend([kb.name for kb in m.data.shape_keys.key_blocks])

    animations: list[dict] = []
    for owner in list(armatures) + [m.data.shape_keys for m in meshes if m.data.shape_keys is not None]:
        ad = getattr(owner, "animation_data", None)
        if not ad:
            continue
        for track in ad.nla_tracks:
            for strip in track.strips:
                animations.append(
                    {
                        "name": strip.name or track.name,
                        "track": track.name,
                        "frame_start": int(round(strip.frame_start)),
                        "frame_end": int(round(strip.frame_end)),
                    }
                )
        if ad.action is not None:
            r0, r1 = ad.action.frame_range
            animations.append(
                {
                    "name": ad.action.name,
                    "track": "(active)",
                    "frame_start": int(round(r0)),
                    "frame_end": int(round(r1)),
                }
            )

    bones_set = set(bones)
    modular_slots = {
        "Head": "Head" in bones_set,
        "Neck": "Neck" in bones_set,
        "Chest": any(b in bones_set for b in ("Chest", "UpperChest", "Spine")),
        "RightHand": "RightHand" in bones_set,
        "LeftHand": "LeftHand" in bones_set,
    }
    piel_slots = [m["name"] for m in materials if m["name"].strip().lower().startswith(("mat_piel", "skin"))]
    equipo_slots = [
        m["name"] for m in materials if m["name"].strip().lower().startswith(("mat_color_equipo", "team_color"))
    ]
    identity_materials = {
        "has_mat_piel": len(piel_slots) > 0,
        "has_mat_color_equipo": len(equipo_slots) > 0,
        "piel_slots": piel_slots,
        "equipo_slots": equipo_slots,
    }

    return {
        "meshes": [m.name for m in meshes],
        "triangles": tris,
        "dimensions_m": [round(dims.x, 4), round(dims.y, 4), round(dims.z, 4)],
        "bbox_min": [round(min_v.x, 4), round(min_v.y, 4), round(min_v.z, 4)],
        "bbox_max": [round(max_v.x, 4), round(max_v.y, 4), round(max_v.z, 4)],
        "bones_count": len(bones),
        "bones": bones,
        "modular_slots": modular_slots,
        "identity_materials": identity_materials,
        "shape_keys_count": len(shape_keys),
        "shape_keys": shape_keys,
        "animations": animations,
        "materials": materials,
        "textures": textures,
    }


def _apply_material_edits(roughness: float | None, metallic: float | None, tint: str | None, tint_strength: float) -> None:
    rgb = _hex_to_rgb(tint) if tint else None
    for mat in bpy.data.materials:
        if not mat.node_tree:
            continue
        nt = mat.node_tree
        bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if not bsdf:
            continue
        if roughness is not None:
            bsdf.inputs["Roughness"].default_value = max(0.0, min(1.0, roughness))
        if metallic is not None:
            bsdf.inputs["Metallic"].default_value = max(0.0, min(1.0, metallic))
        if rgb is not None:
            base_in = bsdf.inputs["Base Color"]
            if base_in.is_linked:
                orig_socket = base_in.links[0].from_socket
                mix = nt.nodes.new("ShaderNodeMix")
                mix.data_type = "RGBA"
                mix.blend_type = "MULTIPLY"
                mix.inputs["Factor"].default_value = max(0.0, min(1.0, tint_strength))
                mix.inputs[7].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
                nt.links.new(orig_socket, mix.inputs[6])
                nt.links.new(mix.outputs[2], base_in)
            else:
                c = base_in.default_value
                t = max(0.0, min(1.0, tint_strength))
                base_in.default_value = (
                    c[0] * (1 - t) + rgb[0] * t,
                    c[1] * (1 - t) + rgb[1] * t,
                    c[2] * (1 - t) + rgb[2] * t,
                    1.0,
                )


def _render_preview(out_png: Path, meshes: list[bpy.types.Object]) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.film_transparent = False
    scene.world = scene.world or bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.92, 0.92, 0.92)
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"

    min_v, max_v = _world_bbox(meshes)
    center = (min_v + max_v) * 0.5
    height = max(max_v.z - min_v.z, 0.5)

    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = height * 1.25
    cam_obj = bpy.data.objects.new("PreviewCam", cam_data)
    scene.collection.objects.link(cam_obj)
    cam_obj.location = (center.x, center.y - height * 2.0, center.z)
    cam_obj.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    scene.camera = cam_obj

    out_png.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(out_png)
    bpy.ops.render.render(write_still=True)


def _parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    p = argparse.ArgumentParser(description="Inspecciona o edita un personaje .glb en Blender headless.")
    p.add_argument("--input", "-i", required=True, type=Path, help="Archivo .glb de entrada.")
    p.add_argument("--output", "-o", type=Path, help="Archivo .glb de salida (default: sobrescribe --input si hay cambios).")
    p.add_argument("--inspect", action="store_true", help="Solo inspecciona y devuelve JSON sin exportar.")
    p.add_argument("--height", type=float, help="Nueva altura total en metros.")
    p.add_argument("--scale-xyz", type=str, help="Escala proporcional X,Y,Z (ej. 1.05,1.05,1.0).")
    p.add_argument("--rotate-z", type=float, default=0.0, help="Rotacion en Z en grados (ej. 180).")
    p.add_argument("--recenter-feet", action="store_true", help="Recoloca el origen (0,0,0) entre los pies.")
    p.add_argument("--max-tex", type=int, help="Redimensiona texturas a un maximo de N px.")
    p.add_argument("--roughness", type=float, help="Ajusta Roughness PBR (0.0 - 1.0).")
    p.add_argument("--metallic", type=float, help="Ajusta Metallic PBR (0.0 - 1.0).")
    p.add_argument("--tint", type=str, help="Aplica tinte hex sobre Base Color (ej. #cc8533).")
    p.add_argument("--tint-strength", type=float, default=0.35, help="Intensidad del tinte (0.0 - 1.0).")
    p.add_argument("--rename-bone", action="append", default=[], help="Renombra hueso: Viejo=Nuevo (repetible).")
    p.add_argument(
        "--rename-material",
        action="append",
        default=[],
        help="Renombra material: Viejo=Nuevo (ej. Material_0=mat_color_equipo).",
    )
    p.add_argument("--pose-adjust", action="append", default=[], help="Rota hueso en grados: Nombre:rx,ry,rz (repetible).")
    p.add_argument("--decimate-ratio", type=float, help="Aplica Decimate controlado (ej. 0.7).")
    p.add_argument("--shading", choices=["smooth", "flat"], help="Cambia el sombreado de las mallas.")
    p.add_argument("--render-preview", type=Path, help="Guarda render ortografico frontal PNG para revision.")
    return p.parse_args(argv)


def main() -> None:
    args = _parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(args.input))

    meshes = _real_meshes()
    armatures = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    roots = _real_roots()

    if args.inspect:
        if args.render_preview and meshes:
            _render_preview(args.render_preview, meshes)
        print("CTN_INSPECT=" + json.dumps(inspect_scene(), ensure_ascii=False))
        return

    if args.scale_xyz:
        sx, sy, sz = (float(v) for v in args.scale_xyz.split(","))
        for r in roots:
            r.scale = (r.scale.x * sx, r.scale.y * sy, r.scale.z * sz)
        bpy.context.view_layer.update()

    if args.height and meshes:
        min_v, max_v = _world_bbox(meshes)
        cur_h = max(max_v.z - min_v.z, 1e-5)
        f = args.height / cur_h
        for r in roots:
            r.scale = (r.scale.x * f, r.scale.y * f, r.scale.z * f)
        bpy.context.view_layer.update()

    if abs(args.rotate_z) > 1e-4:
        for r in roots:
            r.rotation_euler.z += math.radians(args.rotate_z)
        bpy.context.view_layer.update()

    if (args.recenter_feet or args.height or args.scale_xyz or abs(args.rotate_z) > 1e-4) and meshes:
        min_v, max_v = _world_bbox(meshes)
        offset = Vector((-(min_v.x + max_v.x) * 0.5, -(min_v.y + max_v.y) * 0.5, -min_v.z))
        for r in roots:
            r.location += offset
        bpy.context.view_layer.update()

    if args.max_tex:
        for img in bpy.data.images:
            w, h = img.size[0], img.size[1]
            if max(w, h) > args.max_tex:
                s = args.max_tex / float(max(w, h))
                img.scale(max(1, int(round(w * s))), max(1, int(round(h * s))))
                img.pack()

    if args.roughness is not None or args.metallic is not None or args.tint:
        _apply_material_edits(args.roughness, args.metallic, args.tint, args.tint_strength)

    if args.shading:
        for obj in meshes:
            for poly in obj.data.polygons:
                poly.use_smooth = args.shading == "smooth"

    if args.decimate_ratio:
        for obj in meshes:
            mod = obj.modifiers.new(name="CTN_EditDecimate", type="DECIMATE")
            mod.ratio = max(0.05, min(1.0, args.decimate_ratio))
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.modifier_apply(modifier=mod.name)

    if armatures and args.rename_bone:
        bones = armatures[0].data.bones
        for pair in args.rename_bone:
            old, new = pair.split("=", 1)
            if old in bones:
                bones[old].name = new

    if args.rename_material:
        for pair in args.rename_material:
            if "=" not in pair:
                continue
            old_m, new_m = pair.split("=", 1)
            mat = bpy.data.materials.get(old_m.strip())
            if mat is not None:
                mat.name = new_m.strip()

    if armatures and args.pose_adjust:
        arm = armatures[0]
        bpy.context.view_layer.objects.active = arm
        bpy.ops.object.mode_set(mode="POSE")
        for spec in args.pose_adjust:
            bname, angles = spec.split(":", 1)
            rx, ry, rz = (math.radians(float(a)) for a in angles.split(","))
            pbone = arm.pose.bones.get(bname)
            if pbone:
                pbone.rotation_mode = "XYZ"
                pbone.rotation_euler = Euler(
                    (pbone.rotation_euler.x + rx, pbone.rotation_euler.y + ry, pbone.rotation_euler.z + rz),
                    "XYZ",
                )
        bpy.ops.object.mode_set(mode="OBJECT")

    if args.render_preview and meshes:
        _render_preview(args.render_preview, meshes)

    out_path = args.output or args.input
    out_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(out_path),
        export_format="GLB",
        export_yup=True,
        export_skins=True,
        export_materials="EXPORT",
        export_animations=True,
        export_animation_mode="NLA_TRACKS",
        export_nla_strips=True,
        export_morph=True,
        export_morph_normal=True,
        export_morph_animation=True,
    )
    info = inspect_scene()
    info["output"] = str(out_path)
    print("CTN_EDIT_SUMMARY=" + json.dumps(info, ensure_ascii=False))


if __name__ == "__main__":
    main()

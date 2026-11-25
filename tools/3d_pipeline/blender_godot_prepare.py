"""Post-procesado headless en Blender para preparar personajes riggeados (.glb)
para Godot 4 (Craft to Nation).

Uso por CLI:
    blender --background --python tools/3d_pipeline/blender_godot_prepare.py -- \
        --input scratch/personaje_raw_rigged.glb \
        --output godot/assets/personajes/obrero/obrero.glb \
        --height 1.80 \
        --max-tex 1024

Tambien puede importarse desde Blender MCP llamando a `prepare_scene(...)`.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path

import bpy
from mathutils import Vector

# Mapeo de nombres frecuentes (Mixamo, UniRig, VRM, Rigify, genericos)
# al estandar SkeletonProfileHumanoid de Godot 4.
HUMANOID_SYNONYMS: dict[str, tuple[str, ...]] = {
    "Root": ("root", "armature", "skeleton"),
    "Hips": ("hips", "pelvis", "hip", "mixamorig:hips", "j_bip_c_hips", "bip01_pelvis"),
    "Spine": ("spine", "spine0", "spine_0", "spine_01", "mixamorig:spine", "j_bip_c_spine"),
    "Chest": ("chest", "spine1", "spine_1", "spine_02", "mixamorig:spine1", "j_bip_c_chest"),
    "UpperChest": ("upperchest", "upper_chest", "spine2", "spine_2", "spine_03", "mixamorig:spine2", "j_bip_c_upperchest"),
    "Neck": ("neck", "neck_01", "mixamorig:neck", "j_bip_c_neck"),
    "Head": ("head", "mixamorig:head", "j_bip_c_head"),
    "LeftShoulder": ("leftshoulder", "left_shoulder", "shoulder_l", "clavicle_l", "l_clavicle", "mixamorig:leftshoulder"),
    "LeftUpperArm": ("leftupperarm", "left_upper_arm", "leftarm", "upperarm_l", "upper_arm_l", "arm_l", "l_upperarm", "mixamorig:leftarm"),
    "LeftLowerArm": ("leftlowerarm", "left_lower_arm", "leftforearm", "lowerarm_l", "forearm_l", "l_forearm", "mixamorig:leftforearm"),
    "LeftHand": ("lefthand", "left_hand", "hand_l", "wrist_l", "l_hand", "mixamorig:lefthand"),
    "RightShoulder": ("rightshoulder", "right_shoulder", "shoulder_r", "clavicle_r", "r_clavicle", "mixamorig:rightshoulder"),
    "RightUpperArm": ("rightupperarm", "right_upper_arm", "rightarm", "upperarm_r", "upper_arm_r", "arm_r", "r_upperarm", "mixamorig:rightarm"),
    "RightLowerArm": ("rightlowerarm", "right_lower_arm", "rightforearm", "lowerarm_r", "forearm_r", "r_forearm", "mixamorig:rightforearm"),
    "RightHand": ("righthand", "right_hand", "hand_r", "wrist_r", "r_hand", "mixamorig:righthand"),
    "LeftUpperLeg": ("leftupperleg", "left_upper_leg", "leftupleg", "thigh_l", "upperleg_l", "l_thigh", "mixamorig:leftupleg"),
    "LeftLowerLeg": ("leftlowerleg", "left_lower_leg", "leftleg", "calf_l", "shin_l", "lowerleg_l", "l_calf", "mixamorig:leftleg"),
    "LeftFoot": ("leftfoot", "left_foot", "foot_l", "ankle_l", "l_foot", "mixamorig:leftfoot"),
    "LeftToes": ("lefttoes", "left_toes", "lefttoebase", "toe_l", "toes_l", "mixamorig:lefttoebase"),
    "RightUpperLeg": ("rightupperleg", "right_upper_leg", "rightupleg", "thigh_r", "upperleg_r", "r_thigh", "mixamorig:rightupleg"),
    "RightLowerLeg": ("rightlowerleg", "right_lower_leg", "rightleg", "calf_r", "shin_r", "lowerleg_r", "r_calf", "mixamorig:rightleg"),
    "RightFoot": ("rightfoot", "right_foot", "foot_r", "ankle_r", "r_foot", "mixamorig:rightfoot"),
    "RightToes": ("righttoes", "right_toes", "righttoebase", "toe_r", "toes_r", "mixamorig:righttoebase"),
}


def _norm_key(name: str) -> str:
    return re.sub(r"[^a-z0-9:_]", "", name.lower())


def _world_mesh_bbox(meshes: list[bpy.types.Object]) -> tuple[Vector, Vector]:
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


def count_triangles(meshes: list[bpy.types.Object]) -> int:
    total = 0
    for obj in meshes:
        mesh = obj.data
        mesh.calc_loop_triangles()
        total += len(mesh.loop_triangles)
    return total


def resize_textures(max_tex: int) -> list[dict]:
    report = []
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


def map_humanoid_bones(armature_obj: bpy.types.Object) -> dict[str, str]:
    """Renombra huesos al estandar Godot 4 SkeletonProfileHumanoid."""
    lookup: dict[str, str] = {}
    for canonical, aliases in HUMANOID_SYNONYMS.items():
        lookup[_norm_key(canonical)] = canonical
        for a in aliases:
            lookup[_norm_key(a)] = canonical

    mapped: dict[str, str] = {}
    used_targets: set[str] = set()
    bones = armature_obj.data.bones

    # Pasada 1: coincidencia directa por diccionario de sinonimos
    for bone in bones:
        k = _norm_key(bone.name)
        target = lookup.get(k)
        if not target and ":" in k:
            target = lookup.get(k.split(":", 1)[1])
        if target and target not in used_targets:
            old = bone.name
            bone.name = target
            mapped[old] = target
            used_targets.add(target)

    # Pasada 2: heuristica espacial si el rig trae nombres genericos (ej. bone_0, joint_1)
    if "Hips" not in used_targets and len(bones) >= 10:
        roots = [b for b in bones if b.parent is None]
        if roots:
            hips = roots[0]
            # Si el root tiene un solo hijo que se ramifica (pelvis), usarlo como Hips
            if len(hips.children) == 1 and len(hips.children[0].children) >= 2:
                old_root = hips.name
                hips.name = "Root"
                mapped[old_root] = "Root"
                used_targets.add("Root")
                hips = hips.children[0]
            old_hips = hips.name
            hips.name = "Hips"
            mapped[old_hips] = "Hips"
            used_targets.add("Hips")

            # Clasificar cadenas hijas de Hips por posicion X/Z (piernas bajan, columna sube)
            for child in hips.children:
                if child.head_local.z < hips.head_local.z:
                    side = "Left" if child.head_local.x > 0 else "Right"
                    chain_names = [f"{side}UpperLeg", f"{side}LowerLeg", f"{side}Foot", f"{side}Toes"]
                    curr = child
                    for cname in chain_names:
                        if curr is None or cname in used_targets:
                            break
                        old = curr.name
                        curr.name = cname
                        mapped[old] = cname
                        used_targets.add(cname)
                        curr = curr.children[0] if curr.children else None
                else:
                    # Columna vertebral ascendente hasta el nodo que ramifica en hombros + cuello
                    spine_chain = []
                    curr = child
                    while curr is not None:
                        spine_chain.append(curr)
                        if len(curr.children) >= 3:
                            break
                        curr = curr.children[0] if len(curr.children) == 1 else None

                    spine_names = ["Spine", "Chest", "UpperChest"]
                    if len(spine_chain) == 1:
                        assigned = ["Spine"]
                    elif len(spine_chain) == 2:
                        assigned = ["Spine", "UpperChest"]
                    else:
                        assigned = spine_names[: len(spine_chain)]

                    for b, cname in zip(spine_chain, assigned):
                        if cname not in used_targets:
                            old = b.name
                            b.name = cname
                            mapped[old] = cname
                            used_targets.add(cname)

                    top_torso = spine_chain[-1] if spine_chain else None
                    if top_torso and top_torso.children:
                        for branch in top_torso.children:
                            if abs(branch.head_local.x) < 0.04:
                                neck_names = ["Neck", "Head"]
                                cur_n = branch
                                for cname in neck_names:
                                    if cur_n is None or cname in used_targets:
                                        break
                                    old = cur_n.name
                                    cur_n.name = cname
                                    mapped[old] = cname
                                    used_targets.add(cname)
                                    cur_n = cur_n.children[0] if cur_n.children else None
                            else:
                                side = "Left" if branch.head_local.x > 0 else "Right"
                                arm_names = [f"{side}Shoulder", f"{side}UpperArm", f"{side}LowerArm", f"{side}Hand"]
                                cur_a = branch
                                for cname in arm_names:
                                    if cur_a is None or cname in used_targets:
                                        break
                                    old = cur_a.name
                                    cur_a.name = cname
                                    mapped[old] = cname
                                    used_targets.add(cname)
                                    cur_a = cur_a.children[0] if cur_a.children else None

    return mapped


def _weld_and_smooth_meshes(meshes: list[bpy.types.Object]) -> None:
    """Suelda triangulos desconectados (conservando UVs), limpia normales planas y suaviza."""
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


def _apply_head_protected_decimate(
    meshes: list[bpy.types.Object],
    target_faces: int,
    head_fraction: float = 0.22,
) -> dict:
    """Decima priorizando la cabeza/cara: protege los vertices superiores con un Vertex Group."""
    tris_before = count_triangles(meshes)
    if target_faces <= 0 or tris_before <= target_faces:
        return {"applied": False, "head_triangles": 0}

    min_v, max_v = _world_mesh_bbox(meshes)
    height = max(max_v.z - min_v.z, 1e-5)
    z_full = max_v.z - height * head_fraction
    z_fade = z_full - height * 0.05

    ratio = max(0.05, min(1.0, target_faces / float(tris_before)))
    head_tris_after = 0

    for obj in meshes:
        vg = obj.vertex_groups.new(name="CTN_HeadProtect")
        mat = obj.matrix_world
        for v in obj.data.vertices:
            wz = (mat @ v.co).z
            if wz >= z_full:
                vg.add([v.index], 1.0, "REPLACE")
            elif wz > z_fade:
                t = (wz - z_fade) / max(z_full - z_fade, 1e-5)
                vg.add([v.index], t, "REPLACE")

        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj

        mod = obj.modifiers.new(name="CTN_HeadProtectDecimate", type="DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = ratio
        mod.vertex_group = vg.name
        mod.invert_vertex_group = True
        mod.vertex_group_factor = 1.0
        bpy.ops.object.modifier_move_to_index(modifier=mod.name, index=0)
        bpy.ops.object.modifier_apply(modifier=mod.name)

        vg_ref = obj.vertex_groups.get("CTN_HeadProtect")
        if vg_ref is not None:
            obj.vertex_groups.remove(vg_ref)

        obj.data.calc_loop_triangles()
        for tri in obj.data.loop_triangles:
            cz = (mat @ tri.center).z
            if cz >= z_full:
                head_tris_after += 1

    return {"applied": True, "head_triangles": head_tris_after, "head_fraction": head_fraction}


def _fix_rigid_head_weights(meshes: list[bpy.types.Object], arm: bpy.types.Object) -> int:
    """Asigna peso rigido 1.0 al hueso Head para vertices del craneo/rostro (incluyendo
    la barbilla que sobresale hacia -Y por debajo del pivote de Head) y evita estiramientos."""
    head_bone = arm.data.bones.get("Head")
    neck_bone = arm.data.bones.get("Neck")
    if not head_bone:
        return 0
    head_w = arm.matrix_world @ head_bone.head_local
    neck_w = (arm.matrix_world @ neck_bone.head_local) if neck_bone else (head_w - Vector((0.0, 0.0, 0.06)))
    z_head = head_w.z
    z_chin_min = neck_w.z + (z_head - neck_w.z) * 0.20
    y_chin_front = neck_w.y - 0.03

    fixed = 0
    for obj in meshes:
        vg_head = obj.vertex_groups.get("Head")
        if vg_head is None:
            continue
        other_vgs = [vg for vg in obj.vertex_groups if vg.name != "Head"]
        mat = obj.matrix_world
        for v in obj.data.vertices:
            wco = mat @ v.co
            is_head = wco.z >= z_head or (wco.z >= z_chin_min and wco.y <= y_chin_front)
            if is_head:
                for vg in other_vgs:
                    vg.remove([v.index])
                vg_head.add([v.index], 1.0, "REPLACE")
                fixed += 1
    return fixed


def _fix_default_pbr() -> None:
    """Corrige metallic=1.0 heredado de Hunyuan3D-Paint para acabado PBR natural en Godot."""
    for mat in bpy.data.materials:
        if not mat.node_tree:
            continue
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if not bsdf:
            continue
        if bsdf.inputs["Metallic"].default_value >= 0.95:
            bsdf.inputs["Metallic"].default_value = 0.05
        if bsdf.inputs["Roughness"].default_value >= 0.88:
            bsdf.inputs["Roughness"].default_value = 0.78


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


def prepare_scene(
    target_height: float = 1.80,
    max_tex: int = 1024,
    rotate_z_deg: float = 0.0,
    force_decimate: int = 0,
    head_protect_fraction: float = 0.22,
) -> dict:
    meshes = _real_meshes()
    armatures = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    if not meshes:
        raise RuntimeError("No se encontraron mallas en la escena.")

    tris_before = count_triangles(meshes)

    # Soldar vertices duplicados por isla UV, limpiar normales planas y suavizar
    _weld_and_smooth_meshes(meshes)

    # Decimacion con proteccion facial/cabeza (excepcion de detalle en rostro)
    head_decimate_info = {"applied": False, "head_triangles": 0}
    if force_decimate > 0 and tris_before > force_decimate:
        head_decimate_info = _apply_head_protected_decimate(
            meshes,
            target_faces=force_decimate,
            head_fraction=head_protect_fraction,
        )
        # Re-suavizar tras decimate
        for obj in meshes:
            for poly in obj.data.polygons:
                poly.use_smooth = True

    _fix_default_pbr()

    # Normalizar escala y origen (0, 0, 0) en los pies
    roots = _real_roots()
    min_v, max_v = _world_mesh_bbox(meshes)
    current_height = max(max_v.z - min_v.z, 1e-5)
    scale_factor = target_height / current_height

    for r in roots:
        r.scale = (r.scale.x * scale_factor, r.scale.y * scale_factor, r.scale.z * scale_factor)
        if abs(rotate_z_deg) > 1e-4:
            r.rotation_euler.z += math.radians(rotate_z_deg)
    bpy.context.view_layer.update()

    min_v, max_v = _world_mesh_bbox(meshes)
    offset = Vector((-(min_v.x + max_v.x) * 0.5, -(min_v.y + max_v.y) * 0.5, -min_v.z))
    for r in roots:
        r.location += offset
    bpy.context.view_layer.update()

    # Redimensionar texturas al presupuesto de Craft to Nation
    textures_report = resize_textures(max_tex)

    # Renombrar huesos a Godot 4 SkeletonProfileHumanoid y rigidizar pesos de rostro/craneo
    mapped_bones: dict[str, str] = {}
    bones_count = 0
    if armatures:
        arm = armatures[0]
        bones_count = len(arm.data.bones)
        mapped_bones = map_humanoid_bones(arm)
        _fix_rigid_head_weights(meshes, arm)

    min_final, max_final = _world_mesh_bbox(meshes)
    return {
        "triangles_before": tris_before,
        "triangles_after": count_triangles(meshes),
        "head_decimate": head_decimate_info,
        "height_m": round(max_final.z - min_final.z, 4),
        "origin_min_z": round(min_final.z, 4),
        "bones_count": bones_count,
        "mapped_bones_count": len(mapped_bones),
        "mapped_bones": mapped_bones,
        "textures": textures_report,
    }


def _parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description="Prepara un personaje .glb para Godot 4 (Craft to Nation).")
    parser.add_argument("--input", "-i", required=True, type=Path, help="Ruta al .glb riggeado de entrada.")
    parser.add_argument("--output", "-o", required=True, type=Path, help="Ruta al .glb final para Godot 4.")
    parser.add_argument("--height", type=float, default=1.80, help="Altura objetivo en metros (default: 1.80).")
    parser.add_argument("--max-tex", type=int, default=1024, help="Resolucion maxima de textura (512 o 1024).")
    parser.add_argument("--rotate-z", type=float, default=0.0, help="Rotacion adicional en Z (grados).")
    parser.add_argument(
        "--force-decimate",
        type=int,
        default=0,
        help="Reduce a N triangulos protegiendo la cabeza/cara (0 = desactivado).",
    )
    parser.add_argument(
        "--head-protect-fraction",
        type=float,
        default=0.22,
        help="Fraccion superior de altura protegida para detalle facial (default: 0.22).",
    )
    return parser.parse_args(argv)


def main() -> None:
    args = _parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(args.input))

    summary = prepare_scene(
        target_height=args.height,
        max_tex=args.max_tex,
        rotate_z_deg=args.rotate_z,
        force_decimate=args.force_decimate,
        head_protect_fraction=args.head_protect_fraction,
    )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(args.output),
        export_format="GLB",
        export_yup=True,
        export_skins=True,
        export_materials="EXPORT",
    )
    summary["output"] = str(args.output)
    print("CTN_PREPARE_SUMMARY=" + json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()

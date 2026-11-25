"""Transfiere animaciones corporales de Mixamo (.fbx) al esqueleto humanoide de un
personaje (.glb) en Blender 5.3 headless (o desde Blender MCP), empaquetando
cada clip como un NLA track nombrado listo para AnimationPlayer en Godot 4.

Uso por CLI:
    blender --background --python tools/3d_pipeline/blender_mixamo_retarget.py -- \
        --input godot/assets/personajes/obrero/obrero.glb \
        --fbx tools/3d_pipeline/mixamo_library/Idle.fbx \
        --fbx tools/3d_pipeline/mixamo_library/Walking.fbx \
        --in-place \
        --output godot/assets/personajes/obrero/obrero.glb
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

# Mapeo canonico de nombres Mixamo (sin prefijo mixamorig:) -> Godot SkeletonProfileHumanoid
MIXAMO_TO_HUMANOID: dict[str, tuple[str, ...]] = {
    "hips": ("Hips", "Root"),
    "spine": ("Spine",),
    "spine1": ("Chest", "Spine"),
    "spine2": ("UpperChest", "Chest"),
    "neck": ("Neck",),
    "head": ("Head",),
    "leftshoulder": ("LeftShoulder",),
    "leftarm": ("LeftUpperArm",),
    "leftforearm": ("LeftLowerArm",),
    "lefthand": ("LeftHand",),
    "rightshoulder": ("RightShoulder",),
    "rightarm": ("RightUpperArm",),
    "rightforearm": ("RightLowerArm",),
    "righthand": ("RightHand",),
    "leftupleg": ("LeftUpperLeg",),
    "leftleg": ("LeftLowerLeg",),
    "leftfoot": ("LeftFoot",),
    "lefttoebase": ("LeftToes",),
    "rightupleg": ("RightUpperLeg",),
    "rightleg": ("RightLowerLeg",),
    "rightfoot": ("RightFoot",),
    "righttoebase": ("RightToes",),
    # Sinonimos directos por si el FBX ya viene con nombres Godot
    "leftupperarm": ("LeftUpperArm",),
    "leftlowerarm": ("LeftLowerArm",),
    "rightupperarm": ("RightUpperArm",),
    "rightlowerarm": ("RightLowerArm",),
    "leftupperleg": ("LeftUpperLeg",),
    "leftlowerleg": ("LeftLowerLeg",),
    "lefttoes": ("LeftToes",),
    "rightupperleg": ("RightUpperLeg",),
    "rightlowerleg": ("RightLowerLeg",),
    "righttoes": ("RightToes",),
    "chest": ("Chest",),
    "upperchest": ("UpperChest",),
}


def _strip_mixamo_prefix(name: str) -> str:
    cleaned = re.sub(r"^mixamorig\d*[:_]?", "", name, flags=re.IGNORECASE)
    return re.sub(r"[^a-z0-9]", "", cleaned.lower())


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


def _collect_animations(arm: bpy.types.Object | None) -> list[dict]:
    anims: list[dict] = []
    if arm and arm.animation_data:
        for track in arm.animation_data.nla_tracks:
            for strip in track.strips:
                anims.append(
                    {
                        "name": strip.name or track.name,
                        "track": track.name,
                        "frame_start": int(round(strip.frame_start)),
                        "frame_end": int(round(strip.frame_end)),
                    }
                )
        if arm.animation_data.action and not anims:
            r0, r1 = arm.animation_data.action.frame_range
            anims.append(
                {
                    "name": arm.animation_data.action.name,
                    "track": "(active)",
                    "frame_start": int(round(r0)),
                    "frame_end": int(round(r1)),
                }
            )
    return anims


def _build_bone_map(src_arm: bpy.types.Object, tgt_arm: bpy.types.Object) -> dict[str, str]:
    tgt_by_norm = {_strip_mixamo_prefix(b.name): b.name for b in tgt_arm.data.bones}
    tgt_exact = {b.name for b in tgt_arm.data.bones}
    mapping: dict[str, str] = {}
    used_tgt: set[str] = set()

    for sb in src_arm.data.bones:
        key = _strip_mixamo_prefix(sb.name)
        chosen: str | None = None
        for cand in MIXAMO_TO_HUMANOID.get(key, ()):
            if cand in tgt_exact and cand not in used_tgt:
                chosen = cand
                break
        if chosen is None and key in tgt_by_norm and tgt_by_norm[key] not in used_tgt:
            chosen = tgt_by_norm[key]
        if chosen is not None:
            mapping[sb.name] = chosen
            used_tgt.add(chosen)
    return mapping


def _bone_depth(bone: bpy.types.Bone) -> int:
    d = 0
    cur = bone.parent
    while cur is not None:
        d += 1
        cur = cur.parent
    return d


def _get_source_action(src_arm: bpy.types.Object) -> bpy.types.Action | None:
    ad = src_arm.animation_data
    if not ad:
        return None
    if ad.action is not None:
        if hasattr(ad, "action_slot") and ad.action_slot is None and len(ad.action.slots) > 0:
            ad.action_slot = ad.action.slots[0]
        return ad.action
    for track in ad.nla_tracks:
        for strip in track.strips:
            if strip.action is not None:
                return strip.action
    return None


def retarget_fbx_to_armature(
    tgt_arm: bpy.types.Object,
    fbx_path: Path,
    clip_name: str | None = None,
    in_place: bool = False,
    frame_step: int = 1,
) -> dict:
    """Importa un .fbx de Mixamo, transfiere su animacion al target armature como NLA track y limpia el FBX."""
    scene = bpy.context.scene
    pre_objects = set(bpy.data.objects)
    pre_actions = set(bpy.data.actions)
    pre_armatures = set(bpy.data.armatures)
    pre_meshes = set(bpy.data.meshes)

    bpy.ops.import_scene.fbx(filepath=str(fbx_path), automatic_bone_orientation=False)
    new_objects = [o for o in bpy.data.objects if o not in pre_objects]
    src_arms = [o for o in new_objects if o.type == "ARMATURE"]
    if not src_arms:
        raise RuntimeError(f"No se encontro ningun Armature en el FBX: {fbx_path}")
    src_arm = src_arms[0]

    src_action = _get_source_action(src_arm)
    if src_action is None:
        raise RuntimeError(f"El FBX no contiene animacion legible: {fbx_path}")

    f_start = max(int(round(src_action.frame_range[0])), 1)
    f_end = max(int(round(src_action.frame_range[1])), f_start)
    final_name = clip_name or re.sub(r"[^A-Za-z0-9_\- ]", "_", fbx_path.stem).strip() or "MixamoClip"

    bone_map = _build_bone_map(src_arm, tgt_arm)
    if not bone_map:
        raise RuntimeError(f"No hubo coincidencia de huesos entre {fbx_path.name} y {tgt_arm.name}.")

    # Desactivar temporalmente pistas NLA previas para leer poses puras
    tgt_ad = tgt_arm.animation_data_create()
    prev_action = tgt_ad.action
    prev_slot = getattr(tgt_ad, "action_slot", None)
    prev_mutes = [(t, t.mute) for t in tgt_ad.nla_tracks]
    for t, _ in prev_mutes:
        t.mute = True
    tgt_ad.action = None

    # Asegurar quaternion en huesos destino y limpiar poses residuales
    for pb in tgt_arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)
    bpy.context.view_layer.update()

    # Orientaciones rest en mundo
    src_rest_world = {
        sb: (src_arm.matrix_world @ src_arm.data.bones[sb].matrix_local).to_3x3().normalized()
        for sb in bone_map
    }
    tgt_rest_world = {
        tb: (tgt_arm.matrix_world @ tgt_arm.data.bones[tb].matrix_local).to_3x3().normalized()
        for tb in bone_map.values()
    }

    # Identificar par de Hips para escalar traslacion raiz
    src_hips = next((sb for sb, tb in bone_map.items() if tb in ("Hips", "Root")), None)
    tgt_hips = bone_map.get(src_hips) if src_hips else None
    if src_hips and tgt_hips:
        src_hips_rest_pos = src_arm.matrix_world @ src_arm.data.bones[src_hips].head_local
        tgt_hips_rest_pos = tgt_arm.matrix_world @ tgt_arm.data.bones[tgt_hips].head_local
        hips_scale = tgt_hips_rest_pos.z / max(src_hips_rest_pos.z, 1e-4)
    else:
        src_hips_rest_pos = Vector()
        tgt_hips_rest_pos = Vector()
        hips_scale = 1.0

    # Ordenar huesos destino de raiz a hojas
    ordered_pairs = sorted(
        bone_map.items(),
        key=lambda pair: _bone_depth(tgt_arm.data.bones[pair[1]]),
    )

    # Crear Action con Slot (obligatorio en Blender 5.3)
    new_act = bpy.data.actions.new(name=final_name)
    slot = new_act.slots.new(id_type="OBJECT", name=tgt_arm.name)
    tgt_ad.action = new_act
    tgt_ad.action_slot = slot

    tgt_arm_inv_rot = tgt_arm.matrix_world.to_3x3().inverted()
    tgt_arm_inv = tgt_arm.matrix_world.inverted()

    step = max(1, int(frame_step))
    frames = list(range(f_start, f_end + 1, step))
    if frames[-1] != f_end:
        frames.append(f_end)

    for f in frames:
        scene.frame_set(f)
        bpy.context.view_layer.update()

        for sb, tb in ordered_pairs:
            src_pb = src_arm.pose.bones[sb]
            tgt_pb = tgt_arm.pose.bones[tb]
            tgt_bone = tgt_pb.bone

            r_src_pose = (src_arm.matrix_world @ src_pb.matrix).to_3x3().normalized()
            r_delta = r_src_pose @ src_rest_world[sb].inverted()
            r_tgt_world = r_delta @ tgt_rest_world[tb]
            m_arm_rot = (tgt_arm_inv_rot @ r_tgt_world).to_4x4()

            if tb == tgt_hips and src_hips:
                p_src_pose = (src_arm.matrix_world @ src_pb.matrix).to_translation()
                delta_world = (p_src_pose - src_hips_rest_pos) * hips_scale
                if in_place:
                    delta_world.x = 0.0
                    delta_world.y = 0.0
                desired_arm_pos = tgt_arm_inv @ (tgt_hips_rest_pos + delta_world)
                m_arm = Matrix.Translation(desired_arm_pos) @ m_arm_rot
            else:
                m_arm = Matrix.Translation(tgt_pb.matrix.to_translation()) @ m_arm_rot

            if tgt_bone.parent is not None:
                parent_pb = tgt_arm.pose.bones[tgt_bone.parent.name]
                rest_rel = tgt_bone.parent.matrix_local.inverted() @ tgt_bone.matrix_local
                basis = (parent_pb.matrix @ rest_rel).inverted() @ m_arm
            else:
                basis = tgt_bone.matrix_local.inverted() @ m_arm

            tgt_pb.rotation_quaternion = basis.to_quaternion().normalized()
            if tb == tgt_hips:
                tgt_pb.location = basis.to_translation()
                tgt_pb.keyframe_insert(data_path="location", frame=f)
            else:
                tgt_pb.location = (0.0, 0.0, 0.0)
            tgt_pb.keyframe_insert(data_path="rotation_quaternion", frame=f)
            bpy.context.view_layer.update()

    # Empujar la accion como NLA Track independiente para exportacion multi-clip glTF
    # Remover pista previa con el mismo nombre si ya existia
    existing_track = tgt_ad.nla_tracks.get(final_name)
    if existing_track is not None:
        tgt_ad.nla_tracks.remove(existing_track)

    track = tgt_ad.nla_tracks.new()
    track.name = final_name
    strip = track.strips.new(final_name, f_start, new_act)
    if hasattr(strip, "action_slot"):
        strip.action_slot = slot
    track.mute = False

    # Restaurar NLA tracks previas y dejar sin accion activa para evitar colisiones
    for t, was_muted in prev_mutes:
        if t.name in tgt_ad.nla_tracks:
            t.mute = was_muted
    tgt_ad.action = prev_action if prev_action and prev_action != new_act else None
    if tgt_ad.action and prev_slot and hasattr(tgt_ad, "action_slot"):
        tgt_ad.action_slot = prev_slot

    for pb in tgt_arm.pose.bones:
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)

    # Limpiar objetos y datos creados por la importacion del FBX
    for obj in new_objects:
        if obj.name in bpy.data.objects:
            bpy.data.objects.remove(obj, do_unlink=True)
    for arm_data in list(bpy.data.armatures):
        if arm_data not in pre_armatures and arm_data.users == 0:
            bpy.data.armatures.remove(arm_data)
    for mesh_data in list(bpy.data.meshes):
        if mesh_data not in pre_meshes and mesh_data.users == 0:
            bpy.data.meshes.remove(mesh_data)
    for act_data in list(bpy.data.actions):
        if act_data not in pre_actions and act_data != new_act and act_data.users == 0:
            bpy.data.actions.remove(act_data)

    return {
        "name": final_name,
        "source_fbx": str(fbx_path),
        "frame_start": f_start,
        "frame_end": f_end,
        "frames_baked": len(frames),
        "in_place": in_place,
        "mapped_bones_count": len(bone_map),
        "mapped_bones": bone_map,
    }


def _render_pose_preview(
    tgt_arm: bpy.types.Object,
    out_png: Path,
    anim_name: str | None,
    frame: int | None,
) -> None:
    scene = bpy.context.scene
    ad = tgt_arm.animation_data
    saved_mutes = []
    target_frame = frame

    if ad and ad.nla_tracks:
        saved_mutes = [(t, t.mute) for t in ad.nla_tracks]
        chosen_track = ad.nla_tracks.get(anim_name) if anim_name else ad.nla_tracks[-1]
        for t, _ in saved_mutes:
            t.mute = t != chosen_track
        if chosen_track and chosen_track.strips and target_frame is None:
            s = chosen_track.strips[0]
            target_frame = int(round((s.frame_start + s.frame_end) * 0.5))

    if target_frame is not None:
        scene.frame_set(target_frame)
    bpy.context.view_layer.update()

    meshes = _real_meshes()
    min_v, max_v = _world_bbox(meshes)
    center = (min_v + max_v) * 0.5
    height = max(max_v.z - min_v.z, 0.5)

    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.film_transparent = False
    scene.world = scene.world or bpy.data.worlds.new("PosePreviewWorld")
    scene.world.color = (0.92, 0.92, 0.92)
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"

    cam_data = bpy.data.cameras.new("PosePreviewCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = max(height, max_v.x - min_v.x) * 1.25
    cam_obj = bpy.data.objects.new("PosePreviewCam", cam_data)
    scene.collection.objects.link(cam_obj)
    # Vista 3/4 frontal ligera para apreciar profundidad de pose corporal
    cam_obj.location = (center.x + height * 0.85, center.y - height * 2.1, center.z + height * 0.12)
    direction = (center - cam_obj.location).normalized()
    cam_obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam_obj

    out_png.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(out_png)
    bpy.ops.render.render(write_still=True)

    for t, was_muted in saved_mutes:
        t.mute = was_muted


def _parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    p = argparse.ArgumentParser(description="Transfiere animaciones Mixamo (.fbx) a un personaje .glb.")
    p.add_argument("--input", "-i", required=True, type=Path, help="Personaje .glb destino.")
    p.add_argument("--output", "-o", type=Path, help="Archivo .glb de salida (default: sobrescribe --input).")
    p.add_argument("--fbx", action="append", default=[], type=Path, help="Ruta a un clip .fbx de Mixamo (repetible).")
    p.add_argument("--fbx-dir", type=Path, help="Carpeta con clips .fbx de Mixamo para importar en lote.")
    p.add_argument("--clip-name", type=str, help="Nombre personalizado (solo si se pasa un unico --fbx).")
    p.add_argument("--in-place", action="store_true", help="Fija desplazamiento horizontal X/Y de Hips (walk/run).")
    p.add_argument("--frame-step", type=int, default=1, help="Paso de muestreo de frames (default: 1).")
    p.add_argument("--replace-animations", action="store_true", help="Elimina animaciones previas antes de transferir.")
    p.add_argument("--list-animations", action="store_true", help="Lista animaciones existentes en --input y sale.")
    p.add_argument("--render-pose-preview", type=Path, help="Renderiza PNG de vista previa de la pose animada.")
    p.add_argument("--preview-anim", type=str, help="Nombre del clip a previsualizar.")
    p.add_argument("--preview-frame", type=int, help="Frame especifico para el preview.")
    return p.parse_args(argv)


def main() -> None:
    args = _parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(args.input))

    armatures = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    if not armatures:
        raise RuntimeError(f"El archivo {args.input} no contiene un Armature.")
    tgt_arm = armatures[0]

    if args.list_animations:
        print("CTN_ANIMATIONS=" + json.dumps(_collect_animations(tgt_arm), ensure_ascii=False))
        return

    fbx_files: list[Path] = list(args.fbx)
    if args.fbx_dir:
        fbx_files.extend(sorted(args.fbx_dir.glob("*.fbx")))
    if not fbx_files and not args.render_pose_preview:
        raise SystemExit("Debes especificar al menos --fbx, --fbx-dir, --list-animations o --render-pose-preview.")

    if args.replace_animations and tgt_arm.animation_data:
        for t in list(tgt_arm.animation_data.nla_tracks):
            tgt_arm.animation_data.nla_tracks.remove(t)
        tgt_arm.animation_data.action = None

    clips_summary: list[dict] = []
    for idx, fbx_path in enumerate(fbx_files):
        cname = args.clip_name if (args.clip_name and len(fbx_files) == 1 and idx == 0) else None
        res = retarget_fbx_to_armature(
            tgt_arm=tgt_arm,
            fbx_path=fbx_path,
            clip_name=cname,
            in_place=args.in_place,
            frame_step=args.frame_step,
        )
        clips_summary.append(res)

    if args.render_pose_preview:
        _render_pose_preview(
            tgt_arm=tgt_arm,
            out_png=args.render_pose_preview,
            anim_name=args.preview_anim or (clips_summary[-1]["name"] if clips_summary else None),
            frame=args.preview_frame,
        )

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

    meshes = _real_meshes()
    sk_count = sum(
        len(m.data.shape_keys.key_blocks) for m in meshes if m.data.shape_keys is not None
    )
    summary = {
        "clips_added": clips_summary,
        "total_animations": _collect_animations(tgt_arm),
        "shape_keys_count": sk_count,
        "output": str(out_path),
    }
    print("CTN_MIXAMO_SUMMARY=" + json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()

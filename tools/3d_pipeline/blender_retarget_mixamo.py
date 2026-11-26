"""Retargeting headless en Blender de animaciones Mixamo (.fbx) hacia personajes
riggeados (.glb con SkeletonProfileHumanoid) de Craft to Nation.

Compensa diferencias de pose de reposo entre Mixamo y UniRig/Godot usando
alineacion de direcciones en espacio mundo, escala el desplazamiento de Hips
proporcionalmente a la altura de cadera del personaje y conserva animaciones previas
en NLA tracks para exportacion limpia a Godot 4 (.glb).

Uso:
    blender --background --python tools/3d_pipeline/blender_retarget_mixamo.py -- \
        --character godot/assets/personajes/avatar/avatar.glb \
        --animation arte/animations/Walking.fbx \
        --name Walking \
        --output godot/assets/personajes/avatar/avatar.glb \
        --render-frames scratch/3d_jobs/avatar/walk_preview.png
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Quaternion, Vector

# Orden jerarquico top-down: Mixamo -> Godot SkeletonProfileHumanoid
MIXAMO_TO_HUMANOID: list[tuple[str, str, bool]] = [
    # (mixamo_suffix, godot_bone, align_rest_direction)
    ("Hips", "Hips", False),
    ("Spine", "Spine", False),
    ("Spine1", "Chest", False),
    ("Spine2", "UpperChest", False),
    ("Neck", "Neck", False),
    ("Head", "Head", False),
    ("LeftShoulder", "LeftShoulder", True),
    ("LeftArm", "LeftUpperArm", True),
    ("LeftForeArm", "LeftLowerArm", True),
    ("LeftHand", "LeftHand", True),
    ("RightShoulder", "RightShoulder", True),
    ("RightArm", "RightUpperArm", True),
    ("RightForeArm", "RightLowerArm", True),
    ("RightHand", "RightHand", True),
    ("LeftUpLeg", "LeftUpperLeg", True),
    ("LeftLeg", "LeftLowerLeg", True),
    ("LeftFoot", "LeftFoot", False),
    ("LeftToeBase", "LeftToes", False),
    ("RightUpLeg", "RightUpperLeg", True),
    ("RightLeg", "RightLowerLeg", True),
    ("RightFoot", "RightFoot", False),
    ("RightToeBase", "RightToes", False),
]


def _find_mixamo_bone(arm: bpy.types.Object, suffix: str) -> str | None:
    target_low = suffix.lower()
    for b in arm.data.bones:
        clean = b.name.split(":", 1)[-1].lower()
        if clean.startswith("mixamorig"):
            clean = clean[len("mixamorig") :].lstrip(":_|.- ")
        if clean == target_low:
            return b.name
    return None


def _world_bone_rot(arm: bpy.types.Object, bone_matrix: Matrix) -> Matrix:
    return (arm.matrix_world @ bone_matrix).to_3x3().normalized()


def _world_bone_dir(arm: bpy.types.Object, head_local: Vector, tail_local: Vector) -> Vector:
    v = (arm.matrix_world @ tail_local) - (arm.matrix_world @ head_local)
    return v.normalized() if v.length > 1e-6 else Vector((0.0, 0.0, 1.0))


def _calculate_hip_scale(dst_arm: bpy.types.Object, src_arm: bpy.types.Object) -> float:
    """Escala traslación de cadera sin asumir cuál eje representa la altura."""
    src_hips_name = _find_mixamo_bone(src_arm, "Hips")
    src_foot_name = _find_mixamo_bone(src_arm, "LeftFoot")
    if src_hips_name and src_foot_name and "Hips" in dst_arm.data.bones and "LeftFoot" in dst_arm.data.bones:
        src_hips = src_arm.matrix_world @ src_arm.data.bones[src_hips_name].head_local
        src_foot = src_arm.matrix_world @ src_arm.data.bones[src_foot_name].head_local
        dst_hips = dst_arm.matrix_world @ dst_arm.data.bones["Hips"].head_local
        dst_foot = dst_arm.matrix_world @ dst_arm.data.bones["LeftFoot"].head_local
        source_leg = (src_hips - src_foot).length
        if source_leg > 1e-4:
            return (dst_hips - dst_foot).length / source_leg

    src_hips = src_arm.matrix_world @ src_arm.data.bones[src_hips_name].head_local
    dst_hips = dst_arm.matrix_world @ dst_arm.data.bones["Hips"].head_local
    return abs(dst_hips.z) / max(abs(src_hips.z), 1e-4)


def _calculate_root_correction(src_arm: bpy.types.Object, frame: int) -> Matrix:
    """Retira offsets grandes y constantes de coordenadas embebidos en Hips."""
    hips_name = _find_mixamo_bone(src_arm, "Hips")
    if not hips_name:
        return Matrix.Identity(3)
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    rest_rotation = _world_bone_rot(src_arm, src_arm.data.bones[hips_name].matrix_local)
    pose_rotation = _world_bone_rot(src_arm, src_arm.pose.bones[hips_name].matrix)
    root_delta = pose_rotation @ rest_rotation.inverted()
    if root_delta.to_quaternion().angle > math.radians(45.0):
        return root_delta.inverted()
    return Matrix.Identity(3)


def _normalize_source_up(armature: bpy.types.Object) -> None:
    """Alinea el eje vertical del rig fuente con +Z sin alterar su pose local."""
    hips_name = _find_mixamo_bone(armature, "Hips")
    head_name = _find_mixamo_bone(armature, "Head")
    if not hips_name or not head_name:
        return
    hips = armature.matrix_world @ armature.data.bones[hips_name].head_local
    head = armature.matrix_world @ armature.data.bones[head_name].head_local
    up = (head - hips).normalized()
    target_up = Vector((0.0, 0.0, 1.0))
    if up.dot(target_up) < 0.999:
        correction = up.rotation_difference(target_up).to_matrix().to_4x4()
        armature.matrix_world = correction @ armature.matrix_world


def _real_meshes(exclude: set[bpy.types.Object]) -> list[bpy.types.Object]:
    return [
        o
        for o in bpy.context.scene.objects
        if o.type == "MESH"
        and o not in exclude
        and not any("glTF_not_exported" in c.name for c in o.users_collection)
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


def retarget_mixamo(
    dst_arm: bpy.types.Object,
    src_arm: bpy.types.Object,
    anim_name: str,
    in_place: bool = True,
    trim_start: int | None = None,
    trim_end: int | None = None,
    speed: float = 1.0,
) -> dict:
    src_act = src_arm.animation_data.action if src_arm.animation_data else None
    if not src_act:
        raise RuntimeError("El archivo FBX de Mixamo no contiene ninguna animacion (Action).")

    raw_start = int(round(src_act.frame_range[0]))
    raw_end = int(round(src_act.frame_range[1]))
    s_start = max(raw_start, trim_start) if trim_start is not None else raw_start
    s_end = min(raw_end, trim_end) if trim_end is not None else raw_end
    speed = max(0.1, float(speed))
    src_span = max(1, s_end - s_start)
    out_span = max(1, int(round(src_span / speed)))
    f_start = 1
    f_end = 1 + out_span

    scene = bpy.context.scene
    scene.frame_start = f_start
    scene.frame_end = f_end

    # Resolver pares de huesos validos
    pairs: list[tuple[str, str, bool]] = []
    for mx_suffix, gd_name, align_dir in MIXAMO_TO_HUMANOID:
        mx_name = _find_mixamo_bone(src_arm, mx_suffix)
        if mx_name and gd_name in dst_arm.data.bones:
            pairs.append((mx_name, gd_name, align_dir))

    if not pairs:
        raise RuntimeError("No se encontraron huesos coincidentes entre Mixamo y el personaje.")

    # Precomputar matrices de reposo en mundo y offsets T-Pose -> A-Pose
    src_rest_rot: dict[str, Matrix] = {}
    dst_rest_rot: dict[str, Matrix] = {}
    rest_align_rot: dict[str, Matrix] = {}

    for mx_name, gd_name, align_dir in pairs:
        sb = src_arm.data.bones[mx_name]
        db = dst_arm.data.bones[gd_name]
        src_rest_rot[mx_name] = _world_bone_rot(src_arm, sb.matrix_local)
        dst_rest_rot[gd_name] = _world_bone_rot(dst_arm, db.matrix_local)
        if align_dir:
            s_dir = _world_bone_dir(src_arm, sb.head_local, sb.tail_local)
            d_dir = _world_bone_dir(dst_arm, db.head_local, db.tail_local)
            rest_align_rot[gd_name] = d_dir.rotation_difference(s_dir).to_matrix()
        else:
            rest_align_rot[gd_name] = Matrix.Identity(3)

    # Relacion de altura de caderas para escalar movimiento vertical/lateral de Hips
    src_hips_name = pairs[0][0]
    dst_hips_name = pairs[0][1]
    src_hips_rest_w = src_arm.matrix_world @ src_arm.data.bones[src_hips_name].head_local
    dst_hips_rest_w = dst_arm.matrix_world @ dst_arm.data.bones[dst_hips_name].head_local
    hip_scale = _calculate_hip_scale(dst_arm, src_arm)
    root_correction = _calculate_root_correction(src_arm, s_start)

    # Preparar Action destino y preservar existentes en NLA
    if not dst_arm.animation_data:
        dst_arm.animation_data_create()
    # Si habia una accion activa sin NLA track, empujarla a NLA para no perderla
    if dst_arm.animation_data.action:
        prev_act = dst_arm.animation_data.action
        has_track = any(
            strip.action == prev_act
            for tr in dst_arm.animation_data.nla_tracks
            for strip in tr.strips
        )
        if not has_track:
            tr = dst_arm.animation_data.nla_tracks.new()
            tr.name = prev_act.name
            tr.strips.new(prev_act.name, int(prev_act.frame_range[0]), prev_act)

    # Reemplazar si ya existia una animacion con el mismo nombre
    for tr in list(dst_arm.animation_data.nla_tracks):
        if tr.name == anim_name:
            dst_arm.animation_data.nla_tracks.remove(tr)
    if anim_name in bpy.data.actions:
        bpy.data.actions.remove(bpy.data.actions[anim_name])

    new_act = bpy.data.actions.new(name=anim_name)
    new_act.use_fake_user = True
    dst_arm.animation_data.action = new_act

    for pb in dst_arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.location = (0.0, 0.0, 0.0)
        pb.rotation_quaternion = Quaternion((1.0, 0.0, 0.0, 0.0))
        pb.scale = (1.0, 1.0, 1.0)

    arm_world_rot_inv = dst_arm.matrix_world.to_3x3().normalized().inverted()

    for out_idx, frame in enumerate(range(f_start, f_end + 1)):
        src_t = s_start + (out_idx / float(out_span)) * src_span
        src_f = int(math.floor(src_t))
        src_sub = src_t - src_f
        scene.frame_set(src_f, subframe=src_sub)
        bpy.context.view_layer.update()

        # 1. Traslacion de Hips (en espacio local del hueso Hips)
        src_hips_pb = src_arm.pose.bones[src_hips_name]
        dst_hips_pb = dst_arm.pose.bones[dst_hips_name]
        src_hips_cur_w = src_arm.matrix_world @ src_hips_pb.head
        delta_w = (src_hips_cur_w - src_hips_rest_w) * hip_scale
        if in_place:
            delta_w.x = 0.0
            delta_w.y = 0.0
        # Convertir desplazamiento mundo al espacio local del hueso Hips
        hips_world_mat = dst_arm.matrix_world @ dst_arm.data.bones[dst_hips_name].matrix_local
        dst_hips_pb.location = hips_world_mat.to_3x3().inverted() @ delta_w
        dst_hips_pb.keyframe_insert(data_path="location", frame=frame)

        # 2. Rotaciones top-down por hueso mapeado
        computed_world_rot: dict[str, Matrix] = {}
        for mx_name, gd_name, _ in pairs:
            src_pb = src_arm.pose.bones[mx_name]
            dst_pb = dst_arm.pose.bones[gd_name]
            dst_bone = dst_arm.data.bones[gd_name]

            src_pose_w = _world_bone_rot(src_arm, src_pb.matrix)
            delta_rot_w = src_pose_w @ src_rest_rot[mx_name].inverted()
            delta_rot_w = root_correction @ delta_rot_w
            target_w = delta_rot_w @ rest_align_rot[gd_name] @ dst_rest_rot[gd_name]
            computed_world_rot[gd_name] = target_w

            # Matriz de reposo local relativa al padre en espacio mundo
            if dst_bone.parent is not None:
                p_name = dst_bone.parent.name
                if p_name in computed_world_rot:
                    parent_cur_w = computed_world_rot[p_name]
                else:
                    parent_cur_w = _world_bone_rot(dst_arm, dst_arm.pose.bones[p_name].matrix)
                parent_rest_w = _world_bone_rot(dst_arm, dst_bone.parent.matrix_local)
                rest_rel = parent_rest_w.inverted() @ dst_rest_rot[gd_name]
                expected_no_local_w = parent_cur_w @ rest_rel
            else:
                expected_no_local_w = dst_rest_rot[gd_name]

            local_rot_mat = expected_no_local_w.inverted() @ target_w
            q = local_rot_mat.to_quaternion().normalized()
            # Evitar saltos de signo de cuaternion (q vs -q) entre frames consecutivos
            if frame > f_start and dst_pb.rotation_quaternion.dot(q) < 0.0:
                q = -q
            dst_pb.rotation_quaternion = q
            dst_pb.keyframe_insert(data_path="rotation_quaternion", frame=frame)

    # Empujar a NLA track con el nombre exacto de la animacion para Godot 4
    track = dst_arm.animation_data.nla_tracks.new()
    track.name = anim_name
    strip = track.strips.new(anim_name, f_start, new_act)
    strip.name = anim_name
    dst_arm.animation_data.action = new_act

    return {
        "animation_name": anim_name,
        "frames": [f_start, f_end],
        "fps": scene.render.fps,
        "in_place": in_place,
        "mapped_bones": len(pairs),
        "hip_scale": round(hip_scale, 4),
    }


def _render_frame_grid(
    out_png: Path,
    meshes: list[bpy.types.Object],
    frames: list[int],
) -> None:
    """Renderiza una vista 3/4 de un frame clave para verificacion visual."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.film_transparent = False
    scene.world = scene.world or bpy.data.worlds.new("WalkPreviewWorld")
    scene.world.color = (0.92, 0.92, 0.92)
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"

    scene.frame_set(frames[0])
    bpy.context.view_layer.update()
    min_v, max_v = _world_bbox(meshes)
    center = (min_v + max_v) * 0.5
    height = max(max_v.z - min_v.z, 0.5)

    cam_data = bpy.data.cameras.new("WalkPreviewCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = height * 1.35
    cam_obj = bpy.data.objects.new("WalkPreviewCam", cam_data)
    scene.collection.objects.link(cam_obj)
    # Vista 3/4 frontal-izquierda para apreciar zancada y braceo
    angle = math.radians(38.0)
    dist = height * 2.2
    cam_obj.location = (
        center.x - math.sin(angle) * dist,
        center.y - math.cos(angle) * dist,
        center.z,
    )
    direction = center - cam_obj.location
    cam_obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam_obj

    out_png.parent.mkdir(parents=True, exist_ok=True)
    for idx, f in enumerate(frames):
        scene.frame_set(f)
        bpy.context.view_layer.update()
        target = out_png if len(frames) == 1 else out_png.with_stem(f"{out_png.stem}_f{f:02d}")
        scene.render.filepath = str(target)
        bpy.ops.render.render(write_still=True)

    bpy.data.objects.remove(cam_obj, do_unlink=True)
    bpy.data.cameras.remove(cam_data, do_unlink=True)


def _parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    p = argparse.ArgumentParser(description="Retarget de animaciones Mixamo FBX/GLB a personaje GLB.")
    p.add_argument("--character", "-c", required=True, type=Path, help="Ruta al .glb del personaje.")
    p.add_argument("--animation", "-a", type=Path, help="Ruta a un unico .fbx de Mixamo.")
    p.add_argument("--name", "-n", type=str, help="Nombre de la animacion (para --animation).")
    p.add_argument(
        "--add",
        action="append",
        default=[],
        help="Nombre=ruta[::AccionFuente][|inicio:fin|velocidad] para retarget en lote (repetible).",
    )
    p.add_argument("--output", "-o", type=Path, help="Ruta de salida .glb (default: sobrescribe --character).")
    p.add_argument("--keep-root-motion", action="store_true", help="Conserva traslacion XY de Hips (por defecto es In-Place).")
    p.add_argument("--render-frames", type=Path, help="Renderiza frames clave en vista 3/4 para QA visual.")
    p.add_argument(
        "--render-samples",
        type=Path,
        help="Carpeta donde renderizar 1 frame medio por cada animacion solicitada en --sample-names.",
    )
    p.add_argument("--sample-names", type=str, default="", help="Lista separada por comas de animaciones a previsualizar.")
    return p.parse_args(argv)


def _parse_add_spec(spec: str) -> dict:
    """Convierte la gramática estable de --add en un trabajo de retarget."""
    if "=" not in spec:
        raise ValueError(
            "--add debe tener formato "
            f"Nombre=ruta[::AccionFuente][|inicio:fin|velocidad], recibido: {spec}"
        )
    name, rest = spec.split("=", 1)
    parts = [part.strip() for part in rest.split("|")]
    source = parts[0]
    source_action = None
    if "::" in source:
        source, source_action = source.rsplit("::", 1)
        source_action = source_action.strip() or None

    trim_start, trim_end, speed = None, None, 1.0
    if len(parts) >= 2 and ":" in parts[1]:
        start, end = parts[1].split(":", 1)
        trim_start = int(start) if start.strip() else None
        trim_end = int(end) if end.strip() else None
    if len(parts) >= 3 and parts[2]:
        speed = float(parts[2])

    name = name.strip()
    source = source.strip()
    if not name or not source:
        raise ValueError(f"Nombre y ruta son obligatorios en --add: {spec}")
    return {
        "name": name,
        "path": Path(source),
        "source_action": source_action,
        "trim_start": trim_start,
        "trim_end": trim_end,
        "speed": speed,
    }


def _import_source(
    path: Path,
    source_action: str | None = None,
) -> tuple[bpy.types.Object, bpy.types.Action]:
    """Importa FBX/GLB y deja la acción solicitada activa en su armature."""
    before_objects = set(bpy.context.scene.objects)
    before_actions = set(bpy.data.actions)
    suffix = path.suffix.lower()
    if suffix == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(path))
    elif suffix in {".glb", ".gltf"}:
        bpy.ops.import_scene.gltf(filepath=str(path))
    else:
        raise RuntimeError(f"Formato de animación no soportado '{suffix}' en {path}")

    imported_objects = set(bpy.context.scene.objects) - before_objects
    armatures = [obj for obj in imported_objects if obj.type == "ARMATURE"]
    if not armatures:
        raise RuntimeError(f"No se encontro Armature en {path}")
    armature = armatures[0]
    _normalize_source_up(armature)
    imported_actions = list(set(bpy.data.actions) - before_actions)
    available = sorted(action.name for action in imported_actions)

    action = None
    if source_action:
        action = next((item for item in imported_actions if item.name == source_action), None)
        if action is None:
            choices = ", ".join(available) if available else "(ninguna)"
            raise RuntimeError(
                f"No existe la acción '{source_action}' en {path}. "
                f"Acciones disponibles: {choices}"
            )
    elif armature.animation_data is not None:
        action = armature.animation_data.action
    if action is None and len(imported_actions) == 1:
        action = imported_actions[0]
    if action is None:
        choices = ", ".join(available) if available else "(ninguna)"
        raise RuntimeError(
            f"No se pudo determinar la acción fuente en {path}. "
            f"Acciones disponibles: {choices}"
        )

    if armature.animation_data is None:
        armature.animation_data_create()
    armature.animation_data.action = action
    return armature, action


def _import_and_retarget_one(
    dst_arm: bpy.types.Object,
    source_path: Path,
    anim_name: str,
    in_place: bool,
    source_action: str | None = None,
    trim_start: int | None = None,
    trim_end: int | None = None,
    speed: float = 1.0,
) -> dict:
    before_objs = set(bpy.context.scene.objects)
    before_acts = set(bpy.data.actions)
    src_arm, _ = _import_source(source_path, source_action)
    source_objs = set(bpy.context.scene.objects) - before_objs

    summary = retarget_mixamo(
        dst_arm=dst_arm,
        src_arm=src_arm,
        anim_name=anim_name,
        in_place=in_place,
        trim_start=trim_start,
        trim_end=trim_end,
        speed=speed,
    )

    # Eliminar objetos y acciones temporales de Mixamo
    for obj in list(source_objs):
        bpy.data.objects.remove(obj, do_unlink=True)
    for act in list(set(bpy.data.actions) - before_acts):
        if act.name != anim_name:
            bpy.data.actions.remove(act, do_unlink=True)
    return summary


def main() -> None:
    args = _parse_args()
    jobs: list[dict] = []
    if args.animation:
        jobs.append({
            "name": args.name or args.animation.stem,
            "path": args.animation,
            "source_action": None,
            "trim_start": None,
            "trim_end": None,
            "speed": 1.0,
        })
    for spec in args.add:
        jobs.append(_parse_add_spec(spec))
    if not jobs:
        raise SystemExit("Debes especificar --animation o al menos un --add Nombre=ruta.fbx.")

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(args.character))
    dst_arms = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    if not dst_arms:
        raise RuntimeError(f"No se encontro Armature en {args.character}")
    dst_arm = dst_arms[0]

    results: list[dict] = []
    for job in jobs:
        res = _import_and_retarget_one(
            dst_arm=dst_arm,
            source_path=job["path"],
            anim_name=job["name"],
            in_place=not args.keep_root_motion,
            source_action=job["source_action"],
            trim_start=job["trim_start"],
            trim_end=job["trim_end"],
            speed=job["speed"],
        )
        results.append(res)

    # Limpiar posibles acciones huerfanas de Mixamo
    keep_names = {tr.name for tr in dst_arm.animation_data.nla_tracks} if dst_arm.animation_data else set()
    for act in list(bpy.data.actions):
        if "mixamo.com" in act.name.lower() and act.name not in keep_names:
            bpy.data.actions.remove(act, do_unlink=True)
    if dst_arm.animation_data:
        for tr in list(dst_arm.animation_data.nla_tracks):
            if "mixamo.com" in tr.name.lower():
                dst_arm.animation_data.nla_tracks.remove(tr)

    # Previews opcionales
    meshes = _real_meshes(exclude=set())
    if args.render_frames and results:
        last = results[-1]
        dst_arm.animation_data.action = bpy.data.actions.get(last["animation_name"])
        f0, f1 = last["frames"]
        _render_frame_grid(args.render_frames, meshes, [f0 + (f1 - f0) // 4, (f0 + f1) // 2])

    if args.render_samples:
        wanted = {s.strip() for s in args.sample_names.split(",") if s.strip()}
        for res in results:
            nm = res["animation_name"]
            if wanted and nm not in wanted:
                continue
            dst_arm.animation_data.action = bpy.data.actions.get(nm)
            f0, f1 = res["frames"]
            mid = (f0 + f1) // 2
            _render_frame_grid(args.render_samples / f"sample_{nm}.png", meshes, [mid])

    # Dejar action=None para que glTF exporte limpiamente cada NLA track sin duplicar
    if dst_arm.animation_data:
        dst_arm.animation_data.action = None
    bpy.context.scene.frame_set(1)

    out_path = args.output or args.character
    out_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(out_path),
        export_format="GLB",
        export_yup=True,
        export_skins=True,
        export_animations=True,
        export_nla_strips=True,
        export_nla_strips_merged_animation_name="",
        export_morph=True,
        export_morph_normal=True,
        export_morph_animation=True,
        export_materials="EXPORT",
    )

    out_summary = {
        "output": str(out_path),
        "processed_count": len(results),
        "all_animations": [tr.name for tr in dst_arm.animation_data.nla_tracks],
        "details": results,
    }
    print("CTN_RETARGET_SUMMARY=" + json.dumps(out_summary, ensure_ascii=False))


if __name__ == "__main__":
    main()

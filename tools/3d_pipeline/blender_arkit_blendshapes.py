"""Genera shape keys (blendshapes compatibles con Apple ARKit y Lip-Sync) sobre
la cabeza de un personaje (.glb) en Blender 5.3 headless para Godot 4.

ponytail: aproximacion geometrica basada en landmarks proporcionales de cabeza
sobre malla unica de Hunyuan3D (sin topologia facial separada). Para primeros
planos de heroes o cinematicas se recomienda refinar los shape keys esculpiendo
en vivo con Blender MCP (`blender-mcp`).

Uso por CLI:
    blender --background --python tools/3d_pipeline/blender_arkit_blendshapes.py -- \
        --input godot/assets/personajes/avatar/avatar.glb \
        --output godot/assets/personajes/avatar/avatar.glb \
        --preset arkit52 \
        --render-expression-sheet scratch/face_sheet.png
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

# 52 blendshapes estandar de Apple ARKit (nombres exactos para retargeting/lip-sync)
ARKIT_52: tuple[str, ...] = (
    # Ojos (14)
    "eyeBlinkLeft",
    "eyeLookDownLeft",
    "eyeLookInLeft",
    "eyeLookOutLeft",
    "eyeLookUpLeft",
    "eyeSquintLeft",
    "eyeWideLeft",
    "eyeBlinkRight",
    "eyeLookDownRight",
    "eyeLookInRight",
    "eyeLookOutRight",
    "eyeLookUpRight",
    "eyeSquintRight",
    "eyeWideRight",
    # Mandibula (4)
    "jawForward",
    "jawLeft",
    "jawRight",
    "jawOpen",
    # Boca y Labios (23)
    "mouthClose",
    "mouthFunnel",
    "mouthPucker",
    "mouthLeft",
    "mouthRight",
    "mouthSmileLeft",
    "mouthSmileRight",
    "mouthFrownLeft",
    "mouthFrownRight",
    "mouthDimpleLeft",
    "mouthDimpleRight",
    "mouthStretchLeft",
    "mouthStretchRight",
    "mouthRollLower",
    "mouthRollUpper",
    "mouthShrugLower",
    "mouthShrugUpper",
    "mouthPressLeft",
    "mouthPressRight",
    "mouthLowerDownLeft",
    "mouthLowerDownRight",
    "mouthUpperUpLeft",
    "mouthUpperUpRight",
    # Cejas (5)
    "browDownLeft",
    "browDownRight",
    "browInnerUp",
    "browOuterUpLeft",
    "browOuterUpRight",
    # Mejillas (3)
    "cheekPuff",
    "cheekSquintLeft",
    "cheekSquintRight",
    # Nariz (2)
    "noseSneerLeft",
    "noseSneerRight",
    # Lengua (1)
    "tongueOut",
)

# Preset ligero de 18 shape keys para colonos/unidades estandar
LIPSYNC_18: tuple[str, ...] = (
    "jawOpen",
    "mouthClose",
    "mouthFunnel",
    "mouthPucker",
    "mouthSmileLeft",
    "mouthSmileRight",
    "mouthFrownLeft",
    "mouthFrownRight",
    "mouthLowerDownLeft",
    "mouthLowerDownRight",
    "mouthUpperUpLeft",
    "mouthUpperUpRight",
    "eyeBlinkLeft",
    "eyeBlinkRight",
    "browInnerUp",
    "browDownLeft",
    "browDownRight",
    "cheekPuff",
)


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


def _gauss(du: float, dv: float, ru: float, rv: float) -> float:
    return math.exp(-((du / max(ru, 1e-4)) ** 2 + (dv / max(rv, 1e-4)) ** 2))


def _compute_head_bounds(
    mesh_obj: bpy.types.Object,
    arm: bpy.types.Object | None,
    face_dir: str,
) -> dict:
    min_v, max_v = _world_bbox([mesh_obj])
    total_h = max(max_v.z - min_v.z, 0.2)

    z_min = max_v.z - total_h * 0.19
    if arm is not None:
        head_bone = arm.data.bones.get("Head") or arm.data.bones.get("head")
        if head_bone is not None:
            z_min = (arm.matrix_world @ head_bone.head_local).z - 0.015

    z_max = max_v.z
    head_h = max(z_max - z_min, 0.08)
    mat = mesh_obj.matrix_world

    # Tomar muestra superior de la cabeza (excluye cuello/hombros) para medir ancho y frente reales
    upper_z0 = z_min + head_h * 0.18
    upper_z1 = z_max - head_h * 0.05
    sample_pts = [
        mat @ v.co
        for v in mesh_obj.data.vertices
        if upper_z0 <= (mat @ v.co).z <= upper_z1
    ]
    if not sample_pts:
        sample_pts = [mat @ v.co for v in mesh_obj.data.vertices if (mat @ v.co).z >= z_min]
    if not sample_pts:
        raise RuntimeError("No se encontraron vertices en la region de la cabeza.")

    xs = [p.x for p in sample_pts]
    ys = [p.y for p in sample_pts]
    center_x = 0.5 * (min(xs) + max(xs))
    hw = max(0.5 * (max(xs) - min(xs)), head_h * 0.35)
    if face_dir == "-Y":
        front_y = min(ys)
        back_y = max(ys)
    else:
        front_y = max(ys)
        back_y = min(ys)
    depth = max(abs(back_y - front_y), head_h * 0.45)

    return {
        "z_min": z_min,
        "z_max": z_max,
        "head_h": head_h,
        "center_x": center_x,
        "hw": hw,
        "front_y": front_y,
        "depth": depth,
        "face_dir": face_dir,
    }


def _displacement_for_shape(
    shape_name: str,
    u: float,
    v: float,
    front_sign: float,
    left_sign: float,
    mouth_v: float,
    eye_v: float,
    brow_v: float,
) -> tuple[float, float, float]:
    """Devuelve desplazamiento normalizado (dx, dy, dz) respecto a head_h para un vertice facial."""
    # Convencion: du_left > 0 en el lado izquierdo del personaje
    du_left = u * left_sign
    eye_u = 0.22
    brow_u = 0.22
    mouth_half_u = 0.18
    nose_v = (mouth_v + eye_v) * 0.5

    dx = 0.0
    dy = 0.0  # positivo = hacia adelante (se multiplica por front_sign)
    dz = 0.0

    # --- MANDIBULA ---
    if shape_name == "jawOpen":
        if v <= mouth_v + 0.025:
            w = _gauss(u, v - (mouth_v - 0.07), 0.28, 0.11)
            dz = -0.11 * w
            dy = -0.02 * w
    elif shape_name == "jawForward":
        if v <= mouth_v + 0.02:
            w = _gauss(u, v - (mouth_v - 0.07), 0.26, 0.10)
            dy = 0.045 * w
    elif shape_name == "jawLeft":
        if v <= mouth_v + 0.02:
            w = _gauss(u, v - (mouth_v - 0.07), 0.26, 0.10)
            dx = 0.040 * left_sign * w
    elif shape_name == "jawRight":
        if v <= mouth_v + 0.02:
            w = _gauss(u, v - (mouth_v - 0.07), 0.26, 0.10)
            dx = -0.040 * left_sign * w

    # --- BOCA Y LIP-SYNC ---
    elif shape_name == "mouthClose":
        w_low = _gauss(u, v - (mouth_v - 0.03), 0.20, 0.05)
        w_up = _gauss(u, v - (mouth_v + 0.03), 0.20, 0.05)
        dz = 0.040 * w_low - 0.022 * w_up
        dy = 0.012 * (w_low + w_up)
    elif shape_name in ("mouthFunnel", "mouthPucker"):
        w = _gauss(u, v - mouth_v, 0.22, 0.07)
        pull = 0.042 if shape_name == "mouthPucker" else 0.030
        dx = -u * pull * 2.0 * w
        dy = (0.052 if shape_name == "mouthPucker" else 0.040) * w
        if shape_name == "mouthFunnel":
            dz = (0.028 if v > mouth_v else -0.038) * w
    elif shape_name in ("mouthLeft", "mouthRight"):
        sign = left_sign if shape_name == "mouthLeft" else -left_sign
        w = _gauss(u, v - mouth_v, 0.22, 0.065)
        dx = 0.048 * sign * w
    elif shape_name in ("mouthSmileLeft", "mouthSmileRight"):
        s = 1.0 if shape_name.endswith("Left") else -1.0
        w = _gauss(du_left - s * mouth_half_u, v - mouth_v, 0.14, 0.055)
        dx = s * left_sign * 0.040 * w
        dz = 0.045 * w
        dy = -0.018 * w
    elif shape_name in ("mouthFrownLeft", "mouthFrownRight"):
        s = 1.0 if shape_name.endswith("Left") else -1.0
        w = _gauss(du_left - s * mouth_half_u, v - mouth_v, 0.14, 0.055)
        dx = -s * left_sign * 0.015 * w
        dz = -0.045 * w
    elif shape_name in ("mouthDimpleLeft", "mouthDimpleRight"):
        s = 1.0 if shape_name.endswith("Left") else -1.0
        w = _gauss(du_left - s * (mouth_half_u + 0.04), v - mouth_v, 0.12, 0.06)
        dx = s * left_sign * 0.025 * w
        dy = -0.028 * w
    elif shape_name in ("mouthStretchLeft", "mouthStretchRight"):
        s = 1.0 if shape_name.endswith("Left") else -1.0
        w = _gauss(du_left - s * mouth_half_u, v - mouth_v, 0.16, 0.06)
        dx = s * left_sign * 0.048 * w
        dz = -0.012 * w
    elif shape_name in ("mouthRollLower", "mouthRollUpper"):
        is_low = shape_name.endswith("Lower")
        target_v = mouth_v - 0.025 if is_low else mouth_v + 0.025
        w = _gauss(u, v - target_v, 0.20, 0.045)
        dy = -0.036 * w
        dz = (0.022 if is_low else -0.022) * w
    elif shape_name in ("mouthShrugLower", "mouthShrugUpper"):
        is_low = shape_name.endswith("Lower")
        target_v = mouth_v - 0.03 if is_low else mouth_v + 0.03
        w = _gauss(u, v - target_v, 0.20, 0.05)
        dz = 0.036 * w
        dy = 0.022 * w
    elif shape_name in ("mouthPressLeft", "mouthPressRight"):
        s = 1.0 if shape_name.endswith("Left") else -1.0
        w = _gauss(du_left - s * 0.10, v - mouth_v, 0.14, 0.05)
        dy = -0.022 * w
        dz = (-0.018 if v > mouth_v else 0.018) * w
    elif shape_name in ("mouthLowerDownLeft", "mouthLowerDownRight"):
        s = 1.0 if shape_name.endswith("Left") else -1.0
        w = _gauss(du_left - s * 0.10, v - (mouth_v - 0.03), 0.14, 0.05)
        dz = -0.048 * w
        dy = 0.015 * w
    elif shape_name in ("mouthUpperUpLeft", "mouthUpperUpRight"):
        s = 1.0 if shape_name.endswith("Left") else -1.0
        w = _gauss(du_left - s * 0.10, v - (mouth_v + 0.03), 0.14, 0.05)
        dz = 0.045 * w
        dy = 0.015 * w

    # --- OJOS ---
    elif shape_name in ("eyeBlinkLeft", "eyeBlinkRight"):
        s = 1.0 if shape_name.endswith("Left") else -1.0
        w_up = _gauss(du_left - s * eye_u, v - (eye_v + 0.025), 0.13, 0.045)
        w_lo = _gauss(du_left - s * eye_u, v - (eye_v - 0.020), 0.13, 0.040)
        dz = -0.045 * w_up + 0.018 * w_lo
        dy = 0.014 * (w_up + w_lo)
    elif shape_name in ("eyeWideLeft", "eyeWideRight"):
        s = 1.0 if shape_name.endswith("Left") else -1.0
        w_up = _gauss(du_left - s * eye_u, v - (eye_v + 0.025), 0.14, 0.045)
        w_lo = _gauss(du_left - s * eye_u, v - (eye_v - 0.025), 0.13, 0.045)
        dz = 0.038 * w_up - 0.020 * w_lo
    elif shape_name in ("eyeSquintLeft", "eyeSquintRight"):
        s = 1.0 if shape_name.endswith("Left") else -1.0
        w = _gauss(du_left - s * eye_u, v - (eye_v - 0.028), 0.14, 0.05)
        dz = 0.030 * w
        dy = 0.012 * w
    elif shape_name.startswith("eyeLook"):
        s = 1.0 if shape_name.endswith("Left") else -1.0
        w = _gauss(du_left - s * eye_u, v - eye_v, 0.10, 0.045)
        if "Up" in shape_name:
            dz = 0.020 * w
        elif "Down" in shape_name:
            dz = -0.020 * w
        elif "In" in shape_name:
            dx = -s * left_sign * 0.022 * w
        elif "Out" in shape_name:
            dx = s * left_sign * 0.022 * w

    # --- CEJAS ---
    elif shape_name == "browInnerUp":
        w = _gauss(u, v - brow_v, 0.15, 0.055)
        dz = 0.048 * w
    elif shape_name in ("browDownLeft", "browDownRight"):
        s = 1.0 if shape_name.endswith("Left") else -1.0
        w = _gauss(du_left - s * brow_u, v - brow_v, 0.16, 0.055)
        dz = -0.042 * w
        dx = -s * left_sign * 0.014 * w
    elif shape_name in ("browOuterUpLeft", "browOuterUpRight"):
        s = 1.0 if shape_name.endswith("Left") else -1.0
        w = _gauss(du_left - s * (brow_u + 0.08), v - brow_v, 0.14, 0.055)
        dz = 0.045 * w

    # --- MEJILLAS, NARIZ Y LENGUA ---
    elif shape_name == "cheekPuff":
        wl = _gauss(du_left - 0.36, v - (mouth_v + 0.06), 0.18, 0.13)
        wr = _gauss(du_left + 0.36, v - (mouth_v + 0.06), 0.18, 0.13)
        dx = left_sign * (0.065 * wl - 0.065 * wr)
        dy = 0.045 * (wl + wr)
    elif shape_name in ("cheekSquintLeft", "cheekSquintRight"):
        s = 1.0 if shape_name.endswith("Left") else -1.0
        w = _gauss(du_left - s * 0.28, v - (eye_v - 0.10), 0.16, 0.10)
        dz = 0.040 * w
        dy = 0.020 * w
    elif shape_name in ("noseSneerLeft", "noseSneerRight"):
        s = 1.0 if shape_name.endswith("Left") else -1.0
        w = _gauss(du_left - s * 0.12, v - nose_v, 0.12, 0.08)
        dz = 0.036 * w
    elif shape_name == "tongueOut":
        w = _gauss(u, v - (mouth_v - 0.02), 0.12, 0.07)
        dy = 0.070 * w
        dz = -0.025 * w

    return dx, dy * front_sign, dz


def apply_arkit_blendshapes(
    mesh_obj: bpy.types.Object,
    arm: bpy.types.Object | None,
    preset: str = "arkit52",
    face_dir: str = "-Y",
    intensity: float = 1.0,
    mouth_v: float = 0.18,
    eye_v: float = 0.41,
    brow_v: float = 0.49,
) -> dict:
    shapes = ARKIT_52 if preset == "arkit52" else LIPSYNC_18
    bounds = _compute_head_bounds(mesh_obj, arm, face_dir)

    z_min = bounds["z_min"]
    head_h = bounds["head_h"]
    center_x = bounds["center_x"]
    hw = bounds["hw"]
    front_y = bounds["front_y"]
    depth = bounds["depth"]
    front_sign = -1.0 if face_dir == "-Y" else 1.0
    left_sign = 1.0 if face_dir == "-Y" else -1.0

    # Asegurar Basis shape key
    if mesh_obj.data.shape_keys is None:
        mesh_obj.shape_key_add(name="Basis", from_mix=False)

    basis_kb = mesh_obj.data.shape_keys.key_blocks[0]
    world_mat = mesh_obj.matrix_world
    inv_rot = world_mat.inverted().to_3x3()

    # Pre-cachear solo vertices dentro de la region frontal de la cabeza
    head_candidates: list[tuple[int, float, float, float, Vector]] = []
    for idx, v in enumerate(basis_kb.data):
        wco = world_mat @ v.co
        if wco.z < z_min:
            continue
        dist_from_front = (wco.y - front_y) if face_dir == "-Y" else (front_y - wco.y)
        depth_ratio = dist_from_front / depth
        if depth_ratio > 0.55:
            continue
        front_w = max(0.0, 1.0 - depth_ratio / 0.55) ** 1.5
        if front_w <= 0.01:
            continue
        u = (wco.x - center_x) / hw
        vn = (wco.z - z_min) / head_h
        head_candidates.append((idx, u, vn, front_w, v.co.copy()))

    sample_check = {"jawOpen": 0, "mouthSmileLeft": 0, "eyeBlinkLeft": 0, "browInnerUp": 0}
    amp = intensity * head_h

    for sname in shapes:
        existing = mesh_obj.data.shape_keys.key_blocks.get(sname)
        if existing is not None:
            mesh_obj.shape_key_remove(existing)
        kb = mesh_obj.shape_key_add(name=sname, from_mix=False)
        kb.value = 0.0

        affected = 0
        for idx, u, vn, front_w, base_local in head_candidates:
            dx, dy, dz = _displacement_for_shape(
                sname, u, vn, front_sign, left_sign, mouth_v, eye_v, brow_v
            )
            if abs(dx) > 1e-5 or abs(dy) > 1e-5 or abs(dz) > 1e-5:
                world_delta = Vector((dx, dy, dz)) * (amp * front_w)
                local_delta = inv_rot @ world_delta
                kb.data[idx].co = base_local + local_delta
                if world_delta.length > 0.0005:
                    affected += 1
        if sname in sample_check:
            sample_check[sname] = affected

    # Asegurar todos los valores en 0.0 para exportar en reposo
    for kb in mesh_obj.data.shape_keys.key_blocks:
        kb.value = 0.0

    return {
        "preset": preset,
        "mesh": mesh_obj.name,
        "shape_keys_count": len(mesh_obj.data.shape_keys.key_blocks),
        "shape_keys": [kb.name for kb in mesh_obj.data.shape_keys.key_blocks],
        "affected_vertices_sample": sample_check,
        "head_bounds": {k: (round(v, 4) if isinstance(v, float) else v) for k, v in bounds.items()},
    }


def _add_facial_demo_clips(mesh_obj: bpy.types.Object) -> list[str]:
    """Crea clips NLA demostrativos sobre las Shape Keys (Face_Blink, Face_Talk_Demo, Face_Smile)."""
    sk = mesh_obj.data.shape_keys
    if sk is None:
        return []
    ad = sk.animation_data_create()
    added: list[str] = []

    clips_spec = {
        "Face_Blink": [
            (1, {"eyeBlinkLeft": 0.0, "eyeBlinkRight": 0.0}),
            (5, {"eyeBlinkLeft": 1.0, "eyeBlinkRight": 1.0}),
            (10, {"eyeBlinkLeft": 0.0, "eyeBlinkRight": 0.0}),
        ],
        "Face_Talk_Demo": [
            (1, {"jawOpen": 0.0, "mouthFunnel": 0.0, "mouthPucker": 0.0}),
            (6, {"jawOpen": 0.75, "mouthFunnel": 0.35, "mouthPucker": 0.0}),
            (12, {"jawOpen": 0.20, "mouthFunnel": 0.0, "mouthPucker": 0.8}),
            (18, {"jawOpen": 0.85, "mouthFunnel": 0.2, "mouthPucker": 0.0}),
            (24, {"jawOpen": 0.0, "mouthFunnel": 0.0, "mouthPucker": 0.0}),
        ],
        "Face_Smile": [
            (1, {"mouthSmileLeft": 0.0, "mouthSmileRight": 0.0, "cheekSquintLeft": 0.0, "cheekSquintRight": 0.0}),
            (10, {"mouthSmileLeft": 0.9, "mouthSmileRight": 0.9, "cheekSquintLeft": 0.4, "cheekSquintRight": 0.4}),
            (20, {"mouthSmileLeft": 0.0, "mouthSmileRight": 0.0, "cheekSquintLeft": 0.0, "cheekSquintRight": 0.0}),
        ],
    }

    for clip_name, keyframes in clips_spec.items():
        act = bpy.data.actions.new(name=clip_name)
        slot = act.slots.new(id_type="KEY", name=sk.name)
        ad.action = act
        ad.action_slot = slot
        for frame, values in keyframes:
            for kname, val in values.items():
                kb = sk.key_blocks.get(kname)
                if kb is not None:
                    kb.value = val
                    kb.keyframe_insert(data_path="value", frame=frame)
        existing = ad.nla_tracks.get(clip_name)
        if existing is not None:
            ad.nla_tracks.remove(existing)
        track = ad.nla_tracks.new()
        track.name = clip_name
        strip = track.strips.new(clip_name, keyframes[0][0], act)
        if hasattr(strip, "action_slot"):
            strip.action_slot = slot
        track.mute = False
        ad.action = None
        added.append(clip_name)

    for kb in sk.key_blocks:
        kb.value = 0.0
    return added


def _render_expression_sheet(
    mesh_obj: bpy.types.Object,
    arm: bpy.types.Object | None,
    face_dir: str,
    out_png: Path,
) -> None:
    """Renderiza una cuadricula 2x2 de primer plano facial: Neutral, jawOpen, Smile, Blink+Frown."""
    bounds = _compute_head_bounds(mesh_obj, arm, face_dir)
    center_z = 0.5 * (bounds["z_min"] + bounds["z_max"])
    head_h = bounds["head_h"]
    front_sign = -1.0 if face_dir == "-Y" else 1.0

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    tile_size = 384
    scene.render.resolution_x = tile_size
    scene.render.resolution_y = tile_size
    scene.render.film_transparent = False
    scene.world = scene.world or bpy.data.worlds.new("FaceSheetWorld")
    scene.world.color = (0.92, 0.92, 0.92)
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"

    cam_data = bpy.data.cameras.new("FaceSheetCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = head_h * 1.35
    cam_obj = bpy.data.objects.new("FaceSheetCam", cam_data)
    scene.collection.objects.link(cam_obj)
    cam_obj.location = (bounds["center_x"], bounds["front_y"] + front_sign * head_h * 2.5, center_z)
    target = Vector((bounds["center_x"], bounds["front_y"], center_z))
    cam_obj.rotation_euler = (target - cam_obj.location).normalized().to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam_obj

    sk = mesh_obj.data.shape_keys
    poses = [
        ("neutral", {}),
        ("jawOpen", {"jawOpen": 1.0}),
        ("smile", {"mouthSmileLeft": 1.0, "mouthSmileRight": 1.0}),
        ("blink_brow", {"eyeBlinkLeft": 1.0, "eyeBlinkRight": 1.0, "browDownLeft": 1.0, "browDownRight": 1.0}),
    ]

    out_png.parent.mkdir(parents=True, exist_ok=True)
    tile_arrays: list[np.ndarray] = []
    temp_files: list[Path] = []

    for label, weights in poses:
        if sk:
            for kb in sk.key_blocks:
                kb.value = 0.0
            for k, w in weights.items():
                kb = sk.key_blocks.get(k)
                if kb is not None:
                    kb.value = w
        bpy.context.view_layer.update()
        tmp_tile = out_png.parent / f"_tmp_face_{label}.png"
        temp_files.append(tmp_tile)
        scene.render.filepath = str(tmp_tile)
        bpy.ops.render.render(write_still=True)

        img = bpy.data.images.load(str(tmp_tile))
        arr = np.array(img.pixels[:], dtype=np.float32).reshape((tile_size, tile_size, 4))
        tile_arrays.append(arr)
        bpy.data.images.remove(img)

    if sk:
        for kb in sk.key_blocks:
            kb.value = 0.0

    # Componer 2x2 usando coordenadas de pixel de Blender (origen abajo-izquierda)
    grid = np.zeros((tile_size * 2, tile_size * 2, 4), dtype=np.float32)
    grid[tile_size : tile_size * 2, 0:tile_size] = tile_arrays[0]          # arriba-izq: Neutral
    grid[tile_size : tile_size * 2, tile_size : tile_size * 2] = tile_arrays[1]  # arriba-der: jawOpen
    grid[0:tile_size, 0:tile_size] = tile_arrays[2]                        # abajo-izq: Smile
    grid[0:tile_size, tile_size : tile_size * 2] = tile_arrays[3]          # abajo-der: Blink+Brow

    out_img = bpy.data.images.new("FaceExpressionSheet", width=tile_size * 2, height=tile_size * 2, alpha=True)
    out_img.pixels.foreach_set(grid.ravel())
    out_img.filepath_raw = str(out_png)
    out_img.file_format = "PNG"
    out_img.save()
    bpy.data.images.remove(out_img)

    for tf in temp_files:
        if tf.exists():
            tf.unlink()


def _parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    p = argparse.ArgumentParser(description="Añade blendshapes ARKit / Lip-Sync a un personaje .glb.")
    p.add_argument("--input", "-i", required=True, type=Path, help="Archivo .glb de entrada.")
    p.add_argument("--output", "-o", type=Path, help="Archivo .glb de salida (default: sobrescribe --input).")
    p.add_argument("--preset", choices=["arkit52", "lipsync"], default="arkit52", help="Preset de blendshapes.")
    p.add_argument("--face-dir", choices=["-Y", "+Y"], default="-Y", help="Eje frontal del rostro (default: -Y).")
    p.add_argument("--intensity", type=float, default=1.0, help="Multiplicador de amplitud (default: 1.0).")
    p.add_argument("--mouth-v", type=float, default=0.18, help="Altura relativa de la boca (0..1).")
    p.add_argument("--eye-v", type=float, default=0.41, help="Altura relativa de los ojos (0..1).")
    p.add_argument("--brow-v", type=float, default=0.49, help="Altura relativa de las cejas (0..1).")
    p.add_argument("--add-demo-clips", action="store_true", help="Añade pistas NLA demo (Face_Blink, Face_Talk_Demo, Face_Smile).")
    p.add_argument("--render-expression-sheet", type=Path, help="Guarda PNG 2x2 de expresiones faciales.")
    return p.parse_args(argv)


def main() -> None:
    args = _parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(args.input))

    meshes = _real_meshes()
    armatures = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    if not meshes:
        raise RuntimeError(f"No se encontraron mallas en {args.input}")

    arm = armatures[0] if armatures else None
    # Elegir malla principal con mayor altura (o mayor numero de vertices)
    primary_mesh = max(meshes, key=lambda m: len(m.data.vertices))

    summary = apply_arkit_blendshapes(
        mesh_obj=primary_mesh,
        arm=arm,
        preset=args.preset,
        face_dir=args.face_dir,
        intensity=args.intensity,
        mouth_v=args.mouth_v,
        eye_v=args.eye_v,
        brow_v=args.brow_v,
    )

    if args.add_demo_clips:
        summary["demo_clips"] = _add_facial_demo_clips(primary_mesh)

    if args.render_expression_sheet:
        _render_expression_sheet(
            mesh_obj=primary_mesh,
            arm=arm,
            face_dir=args.face_dir,
            out_png=args.render_expression_sheet,
        )
        summary["expression_sheet"] = str(args.render_expression_sheet)

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
    summary["output"] = str(out_path)
    print("CTN_ARKIT_SUMMARY=" + json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()

"""Pruebas focales Blender para fuentes FBX y GLB del retargeter."""

from __future__ import annotations

import importlib.util
import math
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tools" / "3d_pipeline" / "blender_retarget_mixamo.py"
SOURCE_GLB = ROOT / "arte" / "animations" / "work" / "carrying and working on a table.glb"
AVATAR_GLB = ROOT / "godot" / "assets" / "personajes" / "avatar" / "avatar.glb"
CARRY_ACTION = "A person carries a heavy backpack and wa (dfd307) (in place)"
WORK_ACTION = "A person is standing while chopping and  (f7d778)"


def _load_module():
    spec = importlib.util.spec_from_file_location("blender_retarget_mixamo", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def _test_parse(module) -> None:
    legacy = module._parse_add_spec("Walking=C:/animations/Walking.fbx|3:42|1.25")
    assert legacy == {
        "name": "Walking",
        "path": Path("C:/animations/Walking.fbx"),
        "source_action": None,
        "trim_start": 3,
        "trim_end": 42,
        "speed": 1.25,
    }

    glb = module._parse_add_spec(f"Hauler_Carry={SOURCE_GLB}::{CARRY_ACTION}|10:|0.8")
    assert glb["name"] == "Hauler_Carry"
    assert glb["path"] == SOURCE_GLB
    assert glb["source_action"] == CARRY_ACTION
    assert glb["trim_start"] == 10
    assert glb["trim_end"] is None
    assert glb["speed"] == 0.8


def _test_real_glb_actions(module) -> None:
    assert SOURCE_GLB.is_file(), SOURCE_GLB
    for action_name in (CARRY_ACTION, WORK_ACTION):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        armature, action = module._import_source(SOURCE_GLB, action_name)
        assert armature.type == "ARMATURE"
        assert action.name == action_name
        assert armature.animation_data is not None
        assert armature.animation_data.action == action
        assert module._find_mixamo_bone(armature, "Hips") == "mixamorigHips"
        hips = armature.data.bones["mixamorigHips"]
        head = armature.data.bones["mixamorigHead"]
        up = ((armature.matrix_world @ head.head_local) - (armature.matrix_world @ hips.head_local)).normalized()
        assert up.z > 0.95, tuple(up)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    try:
        module._import_source(SOURCE_GLB, "Accion inexistente")
    except RuntimeError as exc:
        message = str(exc)
        assert "Accion inexistente" in message
        assert CARRY_ACTION in message
        assert WORK_ACTION in message
    else:
        raise AssertionError("Una acción GLB inexistente debe producir RuntimeError")


def _test_axis_independent_rig_scale(module) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(AVATAR_GLB))
    destination = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
    source, _ = module._import_source(SOURCE_GLB, CARRY_ACTION)
    scale = module._calculate_hip_scale(destination, source)
    assert 0.5 < scale < 2.0, scale
    correction = module._calculate_root_correction(source, 1)
    assert correction.to_quaternion().angle > math.radians(45.0)


def _test_glb_retarget_stays_upright(module) -> None:
    for action_name in (CARRY_ACTION, WORK_ACTION):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(AVATAR_GLB))
        destination = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
        source, _ = module._import_source(SOURCE_GLB, action_name)
        result = module.retarget_mixamo(destination, source, "UprightTest", in_place=True)
        mid = sum(result["frames"]) // 2
        bpy.context.scene.frame_set(mid)
        bpy.context.view_layer.update()
        hips = destination.matrix_world @ destination.pose.bones["Hips"].head
        head = destination.matrix_world @ destination.pose.bones["Head"].head
        up = (head - hips).normalized()
        assert up.z > 0.9, f"{action_name}: personaje tumbado, up={tuple(up)}"


def main() -> None:
    module = _load_module()
    _test_parse(module)
    _test_real_glb_actions(module)
    _test_axis_independent_rig_scale(module)
    _test_glb_retarget_stays_upright(module)
    print("BLENDER_RETARGET_MIXAMO_TEST_OK")


if __name__ == "__main__":
    main()
